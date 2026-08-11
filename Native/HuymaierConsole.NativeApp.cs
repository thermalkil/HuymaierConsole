using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Xml;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Web.Script.Serialization;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using Microsoft.Win32;
using Forms = System.Windows.Forms;
using Huymaier.EmulatorPlatforms;

namespace HuymaierConsole.NativeApp
{

    internal static class HuymaierNativePickerRequest
    {
        internal static void Request(Window owner, string platformId, string displayName, string action, string primaryBackend, string startPath)
        {
            try
            {
                string requestPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                    "Huymaier Console", "EmulatorPlatforms", "picker-request.json");
                Directory.CreateDirectory(Path.GetDirectoryName(requestPath));
                Dictionary<string, object> request = new Dictionary<string, object>();
                request["platformId"] = platformId ?? String.Empty;
                request["displayName"] = displayName ?? platformId ?? "Console";
                request["action"] = action ?? String.Empty;
                request["primaryBackend"] = primaryBackend ?? String.Empty;
                request["startPath"] = String.IsNullOrWhiteSpace(startPath) ? Environment.GetFolderPath(Environment.SpecialFolder.UserProfile) : startPath;
                request["requestedAtUtc"] = DateTime.UtcNow.ToString("o", CultureInfo.InvariantCulture);
                File.WriteAllText(requestPath, new JavaScriptSerializer().Serialize(request), Encoding.UTF8);
                if (owner != null) owner.Close();
            }
            catch (Exception ex)
            {
                try { MessageBox.Show("Huymaier Console could not open its native file browser.\n\n" + ex.Message,
                    "Huymaier Console", MessageBoxButton.OK, MessageBoxImage.Error); } catch { }
            }
        }
    }


    // v0.26.4 COMPLETE_BACKEND_SETTINGS_WINDOW_BEGIN
    internal sealed class NativeBackendSettingItem
    {
        internal string Identity = String.Empty;
        internal string Category = String.Empty;
        internal string DisplayName = String.Empty;
        internal string Value = String.Empty;
        internal string FilePath = String.Empty;
        internal string Section = String.Empty;
        internal string Key = String.Empty;
        internal string Format = String.Empty;
    }

    internal sealed class NativeBackendValueKeyboardWindow : Window
    {
        private readonly string platformId;
        private readonly Color accent;
        private readonly TextBox valueBox;
        private readonly StackPanel keyRows;
        private readonly List<List<Button>> buttons;
        private readonly System.Windows.Threading.DispatcherTimer inputTimer;
        private readonly string[][] keyLayout;
        private int rowIndex;
        private int columnIndex;
        private bool lowerCase;
        internal bool Accepted { get; private set; }
        internal string Result { get { return valueBox.Text; } }

        internal NativeBackendValueKeyboardWindow(Window owner, string platform, string title, string current, Color themeAccent)
        {
            platformId = platform ?? String.Empty;
            accent = themeAccent;
            Owner = owner;
            WindowStyle = WindowStyle.None;
            ResizeMode = ResizeMode.NoResize;
            WindowState = WindowState.Maximized;
            ShowInTaskbar = false;
            Background = BuildBackground();
            Foreground = Brushes.White;
            Title = title ?? "Edit Value";
            buttons = new List<List<Button>>();
            keyLayout = new string[][] {
                new string[]{"1","2","3","4","5","6","7","8","9","0","-","_"},
                new string[]{"Q","W","E","R","T","Y","U","I","O","P"},
                new string[]{"A","S","D","F","G","H","J","K","L","@"},
                new string[]{"Z","X","C","V","B","N","M",".",",","/","\\",":"},
                new string[]{";","'","\"","(",")","[","]","{","}","=","+","#"},
                new string[]{"CASE","SPACE","BKSP","CLEAR","OK","CANCEL"}
            };
            lowerCase = true;
            rowIndex = 0; columnIndex = 0;

            Grid root = new Grid { Margin = new Thickness(76, 46, 76, 46) };
            root.RowDefinitions.Add(new RowDefinition { Height = new GridLength(92) });
            root.RowDefinitions.Add(new RowDefinition { Height = new GridLength(112) });
            root.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
            root.RowDefinitions.Add(new RowDefinition { Height = new GridLength(54) });

            StackPanel heading = new StackPanel { VerticalAlignment = VerticalAlignment.Center };
            heading.Children.Add(new TextBlock { Text = title ?? "Edit Setting", FontSize = 30, FontWeight = FontWeights.SemiBold, Foreground = Brushes.White });
            heading.Children.Add(new TextBlock { Text = "Controller-native value editor", FontSize = 14, Foreground = new SolidColorBrush(Color.FromArgb(210, 220, 228, 244)), Margin = new Thickness(0, 5, 0, 0) });
            root.Children.Add(heading);

            valueBox = new TextBox { Text = current ?? String.Empty, FontSize = 24, Padding = new Thickness(18, 13, 18, 13), Margin = new Thickness(0, 12, 0, 14), Foreground = Brushes.White, Background = new SolidColorBrush(Color.FromArgb(215, 10, 13, 25)), BorderBrush = new SolidColorBrush(accent), BorderThickness = new Thickness(2), CaretBrush = Brushes.White, VerticalContentAlignment = VerticalAlignment.Center };
            Grid.SetRow(valueBox, 1); root.Children.Add(valueBox);

            keyRows = new StackPanel { VerticalAlignment = VerticalAlignment.Center };
            Grid.SetRow(keyRows, 2); root.Children.Add(keyRows);
            BuildKeys();

            TextBlock footer = new TextBlock { Text = "D-Pad  Move     A / CROSS  Enter     X / SQUARE  Backspace     Y / TRIANGLE  Case     B / CIRCLE  Cancel", FontSize = 14, Foreground = new SolidColorBrush(Color.FromArgb(220, 230, 235, 248)), VerticalAlignment = VerticalAlignment.Center, HorizontalAlignment = HorizontalAlignment.Center };
            Grid.SetRow(footer, 3); root.Children.Add(footer);
            Content = root;

            PreviewKeyDown += OnKeyDown;
            PreviewTextInput += OnTextInput;
            Loaded += delegate { NativeConsoleNavigation.Reset(); Focus(); UpdateSelection(); };
            Closed += delegate { try { inputTimer.Stop(); NativeConsoleNavigation.Reset(); } catch { } };
            inputTimer = new System.Windows.Threading.DispatcherTimer(System.Windows.Threading.DispatcherPriority.Input);
            inputTimer.Interval = TimeSpan.FromMilliseconds(16);
            inputTimer.Tick += delegate { PollController(); };
            inputTimer.Start();
        }

        private Brush BuildBackground()
        {
            if (String.Equals(platformId, "PS1", StringComparison.OrdinalIgnoreCase)) return new LinearGradientBrush(Color.FromRgb(3, 5, 15), Color.FromRgb(12, 22, 59), 90);
            if (String.Equals(platformId, "PS2", StringComparison.OrdinalIgnoreCase)) return new LinearGradientBrush(Color.FromRgb(3, 18, 45), Color.FromRgb(12, 83, 132), 35);
            return new LinearGradientBrush(Color.FromRgb(4, 35, 76), Color.FromRgb(23, 100, 167), 90);
        }

        private void BuildKeys()
        {
            keyRows.Children.Clear(); buttons.Clear();
            for (int r = 0; r < keyLayout.Length; r++)
            {
                System.Windows.Controls.Primitives.UniformGrid grid = new System.Windows.Controls.Primitives.UniformGrid { Columns = keyLayout[r].Length, Margin = new Thickness(0, 5, 0, 5) };
                List<Button> row = new List<Button>();
                for (int c = 0; c < keyLayout[r].Length; c++)
                {
                    string token = keyLayout[r][c];
                    string shown = token;
                    if (token.Length == 1 && Char.IsLetter(token[0])) shown = lowerCase ? token.ToLowerInvariant() : token;
                    if (token == "CASE") shown = lowerCase ? "ABC" : "abc";
                    Button button = new Button { Content = shown, Height = r == keyLayout.Length - 1 ? 60 : 54, Margin = new Thickness(4), FontSize = token.Length > 1 ? 15 : 20, FontWeight = FontWeights.SemiBold, Foreground = Brushes.White, Background = new SolidColorBrush(Color.FromArgb(195, 18, 25, 48)), BorderBrush = new SolidColorBrush(Color.FromArgb(115, accent.R, accent.G, accent.B)), BorderThickness = new Thickness(1), RenderTransformOrigin = new Point(0.5, 0.5) };
                    int rr = r, cc = c; button.Click += delegate { rowIndex = rr; columnIndex = cc; InvokeToken(keyLayout[rr][cc]); };
                    grid.Children.Add(button); row.Add(button);
                }
                buttons.Add(row); keyRows.Children.Add(grid);
            }
            UpdateSelection();
        }

        private void InvokeToken(string token)
        {
            if (token == "CASE") { lowerCase = !lowerCase; BuildKeys(); return; }
            if (token == "SPACE") { valueBox.Text += " "; valueBox.CaretIndex = valueBox.Text.Length; return; }
            if (token == "BKSP") { Backspace(); return; }
            if (token == "CLEAR") { valueBox.Clear(); return; }
            if (token == "OK") { Accepted = true; Close(); return; }
            if (token == "CANCEL") { Accepted = false; Close(); return; }
            string value = token;
            if (token.Length == 1 && Char.IsLetter(token[0]) && lowerCase) value = token.ToLowerInvariant();
            valueBox.Text += value; valueBox.CaretIndex = valueBox.Text.Length;
        }

        private void Backspace()
        {
            if (valueBox.Text.Length == 0) return;
            valueBox.Text = valueBox.Text.Substring(0, valueBox.Text.Length - 1); valueBox.CaretIndex = valueBox.Text.Length;
        }

        private void MoveHorizontal(int delta)
        {
            if (buttons.Count == 0) return;
            int count = buttons[rowIndex].Count; columnIndex = (columnIndex + delta + count) % count; UpdateSelection();
        }
        private void MoveVertical(int delta)
        {
            if (buttons.Count == 0) return;
            rowIndex = Math.Max(0, Math.Min(buttons.Count - 1, rowIndex + delta)); columnIndex = Math.Min(columnIndex, buttons[rowIndex].Count - 1); UpdateSelection();
        }
        private void UpdateSelection()
        {
            for (int r = 0; r < buttons.Count; r++) for (int c = 0; c < buttons[r].Count; c++)
            {
                bool active = r == rowIndex && c == columnIndex; Button b = buttons[r][c];
                b.Background = new SolidColorBrush(active ? Color.FromArgb(245, accent.R, accent.G, accent.B) : Color.FromArgb(195, 18, 25, 48));
                b.BorderBrush = active ? Brushes.White : new SolidColorBrush(Color.FromArgb(115, accent.R, accent.G, accent.B));
                b.BorderThickness = new Thickness(active ? 3 : 1);
                b.RenderTransform = active ? new ScaleTransform(1.04, 1.04) : Transform.Identity;
            }
        }
        private void PollController()
        {
            if (!IsActive) return; NativeNavigationCommand command = NativeConsoleNavigation.Poll(); if (command == null || String.IsNullOrWhiteSpace(command.Command)) return;
            if (command.Command == "Guide") { HuymaierGameBarHost.Toggle(); return; }
            if (command.Command == "Left") MoveHorizontal(-1); else if (command.Command == "Right") MoveHorizontal(1); else if (command.Command == "Up") MoveVertical(-1); else if (command.Command == "Down") MoveVertical(1); else if (command.Command == "Confirm") InvokeToken(keyLayout[rowIndex][columnIndex]); else if (command.Command == "Back") { Accepted = false; Close(); } else if (command.Command == "Secondary") Backspace(); else if (command.Command == "Tertiary") { lowerCase = !lowerCase; BuildKeys(); }
        }
        private void OnKeyDown(object sender, KeyEventArgs e)
        {
            if (e.Key == Key.Left) { MoveHorizontal(-1); e.Handled = true; } else if (e.Key == Key.Right) { MoveHorizontal(1); e.Handled = true; } else if (e.Key == Key.Up) { MoveVertical(-1); e.Handled = true; } else if (e.Key == Key.Down) { MoveVertical(1); e.Handled = true; } else if (e.Key == Key.Enter) { InvokeToken(keyLayout[rowIndex][columnIndex]); e.Handled = true; } else if (e.Key == Key.Escape) { Accepted = false; Close(); e.Handled = true; } else if (e.Key == Key.Back) { Backspace(); e.Handled = true; }
        }
        private void OnTextInput(object sender, TextCompositionEventArgs e)
        {
            if (String.IsNullOrEmpty(e.Text)) return; foreach (char ch in e.Text) if (!Char.IsControl(ch)) valueBox.Text += ch; valueBox.CaretIndex = valueBox.Text.Length; e.Handled = true;
        }
    }

    internal sealed class NativeBackendSettingsWindow : Window
    {
        private readonly string consoleRoot;
        private readonly string platformId;
        private readonly string platformDisplayName;
        private readonly string backend;
        private readonly string platformSettingsPath;
        private readonly Color accent;
        private readonly Grid contentHost;
        private readonly TextBlock headingText;
        private readonly TextBlock detailText;
        private readonly TextBlock noticeText;
        private readonly StackPanel listPanel;
        private readonly ScrollViewer scroll;
        private readonly List<Button> rows;
        private readonly System.Windows.Threading.DispatcherTimer inputTimer;
        private List<NativeBackendSettingItem> settings;
        private List<string> categories;
        private List<NativeBackendSettingItem> visibleSettings;
        private int layer;
        private int selected;
        private string activeCategory;
        private string notice;

        internal static void Show(Window owner, string consoleRoot, string platformId, string displayName, string backend, string platformSettingsPath)
        {
            try
            {
                NativeBackendSettingsWindow window = new NativeBackendSettingsWindow(owner, consoleRoot, platformId, displayName, backend, platformSettingsPath);
                window.ShowDialog();
            }
            catch (Exception ex)
            {
                try { MessageBox.Show("Huymaier Console could not open the complete emulator settings.\n\n" + ex.Message, displayName ?? "Emulator Settings", MessageBoxButton.OK, MessageBoxImage.Error); } catch { }
            }
            finally { try { NativeConsoleNavigation.Reset(); NativeWindowActivation.Restore(owner); } catch { } }
        }

        private NativeBackendSettingsWindow(Window owner, string rootPath, string id, string display, string backendName, string settingsPath)
        {
            Owner = owner; consoleRoot = rootPath ?? String.Empty; platformId = id ?? String.Empty; platformDisplayName = display ?? id ?? "Console"; backend = backendName ?? "Emulator"; platformSettingsPath = settingsPath ?? String.Empty;
            accent = GetAccent(platformId); rows = new List<Button>(); settings = new List<NativeBackendSettingItem>(); categories = new List<string>(); visibleSettings = new List<NativeBackendSettingItem>(); activeCategory = String.Empty; layer = 0; selected = 0; notice = String.Empty;
            WindowStyle = WindowStyle.None; ResizeMode = ResizeMode.NoResize; WindowState = WindowState.Maximized; ShowInTaskbar = false; Background = BuildBackground(platformId); Foreground = Brushes.White; Title = backend + " Settings";

            Grid root = new Grid { Margin = new Thickness(62, 34, 62, 30) }; root.RowDefinitions.Add(new RowDefinition { Height = new GridLength(112) }); root.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) }); root.RowDefinitions.Add(new RowDefinition { Height = new GridLength(54) });
            StackPanel header = new StackPanel { VerticalAlignment = VerticalAlignment.Center }; headingText = new TextBlock { FontSize = 32, FontWeight = FontWeights.SemiBold, Foreground = Brushes.White }; detailText = new TextBlock { FontSize = 14, Foreground = new SolidColorBrush(Color.FromArgb(215, 219, 230, 246)), Margin = new Thickness(0, 6, 0, 0), TextTrimming = TextTrimming.CharacterEllipsis }; header.Children.Add(headingText); header.Children.Add(detailText); root.Children.Add(header);
            contentHost = new Grid(); Grid.SetRow(contentHost, 1); root.Children.Add(contentHost); listPanel = new StackPanel { Margin = new Thickness(8, 4, 8, 20) }; scroll = new ScrollViewer { VerticalScrollBarVisibility = ScrollBarVisibility.Hidden, HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled, Content = listPanel }; contentHost.Children.Add(scroll);
            Grid footer = new Grid(); footer.ColumnDefinitions.Add(new ColumnDefinition()); footer.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto }); TextBlock controls = new TextBlock { Text = "D-Pad  Navigate     A / CROSS  Select / Edit     B / CIRCLE  Back", FontSize = 14, Foreground = new SolidColorBrush(Color.FromArgb(220, 230, 236, 248)), VerticalAlignment = VerticalAlignment.Center }; footer.Children.Add(controls); noticeText = new TextBlock { FontSize = 14, Foreground = new SolidColorBrush(Color.FromRgb(255, 226, 86)), VerticalAlignment = VerticalAlignment.Center, HorizontalAlignment = HorizontalAlignment.Right, MaxWidth = 600, TextTrimming = TextTrimming.CharacterEllipsis }; Grid.SetColumn(noticeText, 1); footer.Children.Add(noticeText); Grid.SetRow(footer, 2); root.Children.Add(footer); Content = root;

            PreviewKeyDown += OnKeyDown; Loaded += delegate { NativeConsoleNavigation.Reset(); LoadInventory(null); Render(); }; Closed += delegate { try { inputTimer.Stop(); NativeConsoleNavigation.Reset(); } catch { } };
            inputTimer = new System.Windows.Threading.DispatcherTimer(System.Windows.Threading.DispatcherPriority.Input); inputTimer.Interval = TimeSpan.FromMilliseconds(16); inputTimer.Tick += delegate { PollController(); }; inputTimer.Start();
        }

        private static Color GetAccent(string id)
        {
            if (String.Equals(id, "PS1", StringComparison.OrdinalIgnoreCase)) return Color.FromRgb(52, 105, 225);
            if (String.Equals(id, "PS2", StringComparison.OrdinalIgnoreCase)) return Color.FromRgb(27, 159, 231);
            return Color.FromRgb(94, 184, 255);
        }
        private static Brush BuildBackground(string id)
        {
            if (String.Equals(id, "PS1", StringComparison.OrdinalIgnoreCase)) return new LinearGradientBrush(Color.FromRgb(1, 3, 10), Color.FromRgb(9, 22, 58), 90);
            if (String.Equals(id, "PS2", StringComparison.OrdinalIgnoreCase)) return new LinearGradientBrush(Color.FromRgb(3, 17, 39), Color.FromRgb(8, 79, 132), 45);
            return new LinearGradientBrush(Color.FromRgb(7, 41, 84), Color.FromRgb(28, 113, 182), 90);
        }
        private static string GetString(IDictionary<string, object> map, string key)
        {
            if (map == null || !map.ContainsKey(key) || map[key] == null) return String.Empty; return Convert.ToString(map[key], CultureInfo.InvariantCulture) ?? String.Empty;
        }
        private string RuntimeDirectory
        {
            get { string path = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Huymaier Console", "EmulatorPlatforms", platformId.ToUpperInvariant()); Directory.CreateDirectory(path); return path; }
        }
        private string WorkerPath { get { return Path.Combine(consoleRoot, "HuymaierEmulatorSettingsWorker.ps1"); } }
        private static string QuoteArgument(string value) { return "\"" + (value ?? String.Empty).Replace("\"", "\\\"") + "\""; }

        private string RunWorker(string mode, string editRequestPath)
        {
            if (!File.Exists(WorkerPath)) throw new FileNotFoundException("The Huymaier emulator-settings worker is missing.", WorkerPath);
            string output = Path.Combine(RuntimeDirectory, "backend-settings-runtime-" + Guid.NewGuid().ToString("N") + ".json");
            string powershell = Path.Combine(Environment.SystemDirectory, "WindowsPowerShell", "v1.0", "powershell.exe"); if (!File.Exists(powershell)) powershell = "powershell.exe";
            ProcessStartInfo psi = new ProcessStartInfo(); psi.FileName = powershell; psi.UseShellExecute = false; psi.CreateNoWindow = true; psi.RedirectStandardOutput = true; psi.RedirectStandardError = true;
            StringBuilder args = new StringBuilder(); args.Append("-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File ").Append(QuoteArgument(WorkerPath)).Append(" -Mode ").Append(QuoteArgument(mode)).Append(" -PlatformId ").Append(QuoteArgument(platformId)).Append(" -ConsoleRoot ").Append(QuoteArgument(consoleRoot)).Append(" -PlatformSettingsPath ").Append(QuoteArgument(platformSettingsPath)).Append(" -OutputPath ").Append(QuoteArgument(output));
            if (!String.IsNullOrWhiteSpace(editRequestPath)) args.Append(" -EditRequestPath ").Append(QuoteArgument(editRequestPath)); psi.Arguments = args.ToString();
            using (Process process = Process.Start(psi))
            {
                if (process == null) throw new InvalidOperationException("Windows PowerShell could not be started."); string stdout = process.StandardOutput.ReadToEnd(); string stderr = process.StandardError.ReadToEnd(); if (!process.WaitForExit(25000)) { try { process.Kill(); } catch { } throw new TimeoutException("The emulator settings worker did not finish in time."); }
                if (process.ExitCode != 0) throw new InvalidOperationException(String.IsNullOrWhiteSpace(stderr) ? (String.IsNullOrWhiteSpace(stdout) ? "The emulator settings worker failed." : stdout.Trim()) : stderr.Trim());
            }
            if (!File.Exists(output)) throw new FileNotFoundException("The emulator settings worker did not return an inventory.", output); return output;
        }

        private void LoadInventory(string keepIdentity)
        {
            string output = null; try { output = RunWorker("Inventory", null); ParseInventory(output); if (!String.IsNullOrWhiteSpace(keepIdentity)) SelectIdentity(keepIdentity); notice = settings.Count.ToString(CultureInfo.InvariantCulture) + " backend settings discovered"; } catch (Exception ex) { settings.Clear(); categories.Clear(); notice = ex.Message; } finally { try { if (!String.IsNullOrWhiteSpace(output) && File.Exists(output)) File.Delete(output); } catch { } }
        }
        private void ParseInventory(string path)
        {
            settings.Clear(); categories.Clear(); JavaScriptSerializer serializer = new JavaScriptSerializer(); object parsed = serializer.DeserializeObject(File.ReadAllText(path, Encoding.UTF8)); IDictionary<string, object> root = parsed as IDictionary<string, object>; if (root == null) return; object rawSettings; if (!root.TryGetValue("settings", out rawSettings) || rawSettings == null) return; IEnumerable<object> array = rawSettings as IEnumerable<object>; if (array == null) return;
            foreach (object raw in array)
            {
                IDictionary<string, object> map = raw as IDictionary<string, object>; if (map == null) continue; NativeBackendSettingItem item = new NativeBackendSettingItem(); item.Identity = GetString(map, "Identity"); item.Category = GetString(map, "Category"); item.DisplayName = GetString(map, "DisplayName"); item.Value = GetString(map, "Value"); item.FilePath = GetString(map, "FilePath"); item.Section = GetString(map, "Section"); item.Key = GetString(map, "Key"); item.Format = GetString(map, "Format"); if (String.IsNullOrWhiteSpace(item.DisplayName)) item.DisplayName = item.Key; if (String.IsNullOrWhiteSpace(item.Category)) item.Category = "Other"; settings.Add(item);
            }
            string[] canonical = new string[]{"Graphics","Audio","Input","System","Paths & Storage","Network","Enhancements & Advanced","Other"}; categories.Add("All Settings"); foreach (string name in canonical) if (settings.Any(delegate(NativeBackendSettingItem value){return String.Equals(value.Category,name,StringComparison.OrdinalIgnoreCase);})) categories.Add(name); foreach (string extra in settings.Select(delegate(NativeBackendSettingItem value){return value.Category;}).Distinct(StringComparer.OrdinalIgnoreCase).OrderBy(delegate(string value){return value;},StringComparer.CurrentCultureIgnoreCase)) if (!categories.Contains(extra,StringComparer.OrdinalIgnoreCase)) categories.Add(extra);
        }
        private void SelectIdentity(string identity)
        {
            if (layer != 1 || String.IsNullOrWhiteSpace(identity)) return; for (int i = 0; i < visibleSettings.Count; i++) if (String.Equals(visibleSettings[i].Identity, identity, StringComparison.Ordinal)) { selected = i; return; }
        }

        private void Render()
        {
            listPanel.Children.Clear(); rows.Clear(); noticeText.Text = notice ?? String.Empty;
            if (layer == 0) RenderCategories(); else RenderSettingsList(); UpdateSelection();
        }
        private void RenderCategories()
        {
            headingText.Text = platformDisplayName + "  •  " + backend + " Settings"; detailText.Text = "Complete installed-backend configuration — Huymaier preserves settings it does not own";
            if (categories.Count == 0) { AddRow("No backend settings found", "Set the emulator/data path, launch the emulator once, then reopen this page.", delegate { }); return; }
            for (int i = 0; i < categories.Count; i++)
            {
                string category = categories[i]; int count = String.Equals(category,"All Settings",StringComparison.OrdinalIgnoreCase) ? settings.Count : settings.Count(delegate(NativeBackendSettingItem value){return String.Equals(value.Category,category,StringComparison.OrdinalIgnoreCase);}); string captured = category; AddRow(category, count.ToString(CultureInfo.InvariantCulture) + " setting(s)", delegate { activeCategory = captured; layer = 1; selected = 0; Render(); });
            }
        }
        private void RenderSettingsList()
        {
            visibleSettings = String.Equals(activeCategory,"All Settings",StringComparison.OrdinalIgnoreCase) ? settings.OrderBy(delegate(NativeBackendSettingItem value){return value.DisplayName;},StringComparer.CurrentCultureIgnoreCase).ToList() : settings.Where(delegate(NativeBackendSettingItem value){return String.Equals(value.Category,activeCategory,StringComparison.OrdinalIgnoreCase);}).OrderBy(delegate(NativeBackendSettingItem value){return value.DisplayName;},StringComparer.CurrentCultureIgnoreCase).ToList();
            headingText.Text = backend + "  •  " + activeCategory; detailText.Text = visibleSettings.Count.ToString(CultureInfo.InvariantCulture) + " setting(s) — A edits; boolean values toggle directly";
            for (int i = 0; i < visibleSettings.Count; i++) { NativeBackendSettingItem item = visibleSettings[i]; NativeBackendSettingItem captured = item; string source = Path.GetFileName(item.FilePath); string detail = item.Value + (String.IsNullOrWhiteSpace(source) ? String.Empty : "    •    " + source); AddRow(item.DisplayName, detail, delegate { EditSetting(captured); }); }
            if (visibleSettings.Count == 0) AddRow("No settings in this category", "B / CIRCLE returns to categories", delegate { });
        }
        private void AddRow(string title, string detail, Action invoke)
        {
            Button button = new Button { MinHeight = 78, Margin = new Thickness(0, 0, 0, 8), Padding = new Thickness(18, 10, 18, 10), HorizontalContentAlignment = HorizontalAlignment.Stretch, Background = new SolidColorBrush(Color.FromArgb(188, 12, 18, 34)), BorderBrush = new SolidColorBrush(Color.FromArgb(100, accent.R, accent.G, accent.B)), BorderThickness = new Thickness(1), RenderTransformOrigin = new Point(0.5, 0.5) }; Grid grid = new Grid(); grid.RowDefinitions.Add(new RowDefinition()); grid.RowDefinitions.Add(new RowDefinition()); TextBlock name = new TextBlock { Text = title, FontSize = 20, FontWeight = FontWeights.SemiBold, Foreground = Brushes.White, TextTrimming = TextTrimming.CharacterEllipsis }; TextBlock value = new TextBlock { Text = detail ?? String.Empty, FontSize = 12, Foreground = new SolidColorBrush(Color.FromArgb(215, 198, 211, 232)), TextTrimming = TextTrimming.CharacterEllipsis, Margin = new Thickness(0, 5, 0, 0) }; Grid.SetRow(value,1);grid.Children.Add(name);grid.Children.Add(value);button.Content=grid;int index=rows.Count;button.Click+=delegate{selected=index;invoke();};rows.Add(button);listPanel.Children.Add(button);
        }
        private void UpdateSelection()
        {
            if (rows.Count == 0) return; selected = Math.Max(0, Math.Min(rows.Count - 1, selected)); for (int i = 0; i < rows.Count; i++) { bool active = i == selected; Button b = rows[i]; b.Background = new SolidColorBrush(active ? Color.FromArgb(238, accent.R, accent.G, accent.B) : Color.FromArgb(188, 12, 18, 34)); b.BorderBrush = active ? Brushes.White : new SolidColorBrush(Color.FromArgb(100, accent.R, accent.G, accent.B)); b.BorderThickness = new Thickness(active ? 3 : 1); b.RenderTransform = active ? new ScaleTransform(1.015,1.015) : Transform.Identity; } rows[selected].BringIntoView(); if (layer == 1 && selected < visibleSettings.Count) { NativeBackendSettingItem item = visibleSettings[selected]; detailText.Text = item.DisplayName + "    •    " + item.Format.ToUpperInvariant() + "    •    " + item.FilePath; } noticeText.Text = notice ?? String.Empty;
        }
        private static bool TryToggleValue(string current, out string next)
        {
            next = String.Empty; string value = (current ?? String.Empty).Trim(); string lower = value.ToLowerInvariant(); if (lower == "true") { next = value == "True" ? "False" : "false"; return true; } if (lower == "false") { next = value == "False" ? "True" : "true"; return true; } if (lower == "yes") { next = "no"; return true; } if (lower == "no") { next = "yes"; return true; } if (lower == "on") { next = "off"; return true; } if (lower == "off") { next = "on"; return true; } if (lower == "enabled") { next = "disabled"; return true; } if (lower == "disabled") { next = "enabled"; return true; } if (value == "1") { next = "0"; return true; } if (value == "0") { next = "1"; return true; } return false;
        }
        private void EditSetting(NativeBackendSettingItem item)
        {
            if (item == null || String.IsNullOrWhiteSpace(item.Identity)) return; string next; if (!TryToggleValue(item.Value, out next)) { NativeBackendValueKeyboardWindow keyboard = new NativeBackendValueKeyboardWindow(this, platformId, item.DisplayName, item.Value, accent); keyboard.ShowDialog(); if (!keyboard.Accepted) { NativeConsoleNavigation.Reset(); return; } next = keyboard.Result; }
            ApplySetting(item, next);
        }
        private void ApplySetting(NativeBackendSettingItem item, string next)
        {
            string request = Path.Combine(RuntimeDirectory, "backend-settings-edit-" + Guid.NewGuid().ToString("N") + ".json"); string output = null; try { Dictionary<string,object> edit = new Dictionary<string,object>(); edit["identity"] = item.Identity; edit["value"] = next ?? String.Empty; File.WriteAllText(request, new JavaScriptSerializer().Serialize(edit), Encoding.UTF8); output = RunWorker("Set", request); string keep = item.Identity; ParseInventory(output); visibleSettings = String.Equals(activeCategory,"All Settings",StringComparison.OrdinalIgnoreCase) ? settings.OrderBy(delegate(NativeBackendSettingItem value){return value.DisplayName;},StringComparer.CurrentCultureIgnoreCase).ToList() : settings.Where(delegate(NativeBackendSettingItem value){return String.Equals(value.Category,activeCategory,StringComparison.OrdinalIgnoreCase);}).OrderBy(delegate(NativeBackendSettingItem value){return value.DisplayName;},StringComparer.CurrentCultureIgnoreCase).ToList(); for (int i=0;i<visibleSettings.Count;i++) if (String.Equals(visibleSettings[i].Identity,keep,StringComparison.Ordinal)){selected=i;break;} notice = item.DisplayName + " saved — original config backed up"; Render(); } catch (Exception ex) { notice = "Setting could not be saved: " + ex.Message; noticeText.Text = notice; } finally { try { if (File.Exists(request)) File.Delete(request); } catch {} try { if (!String.IsNullOrWhiteSpace(output) && File.Exists(output)) File.Delete(output); } catch {} NativeConsoleNavigation.Reset(); }
        }
        private void Move(int delta)
        {
            if (rows.Count == 0) return; selected = Math.Max(0, Math.Min(rows.Count - 1, selected + delta)); UpdateSelection();
        }
        private void Confirm()
        {
            if (selected < 0 || selected >= rows.Count) return; rows[selected].RaiseEvent(new RoutedEventArgs(Button.ClickEvent));
        }
        private void BackOneLayer()
        {
            if (layer == 1) { layer = 0; selected = Math.Max(0,categories.FindIndex(delegate(string value){return String.Equals(value,activeCategory,StringComparison.OrdinalIgnoreCase);})); activeCategory=String.Empty; Render(); } else Close();
        }
        private void PollController()
        {
            if (!IsActive) return; NativeNavigationCommand command = NativeConsoleNavigation.Poll(); if (command == null || String.IsNullOrWhiteSpace(command.Command)) return; if (command.Command == "Guide") { HuymaierGameBarHost.Toggle(); return; } if (command.Command == "Up") Move(-1); else if (command.Command == "Down") Move(1); else if (command.Command == "Confirm") Confirm(); else if (command.Command == "Back") BackOneLayer(); else if (command.Command == "Secondary" && layer == 1 && selected < visibleSettings.Count) { string next; if (TryToggleValue(visibleSettings[selected].Value,out next)) ApplySetting(visibleSettings[selected],next); }
        }
        private void OnKeyDown(object sender, KeyEventArgs e)
        {
            if (e.Key == Key.Up) { Move(-1); e.Handled=true; } else if (e.Key == Key.Down) { Move(1); e.Handled=true; } else if (e.Key == Key.Enter) { Confirm(); e.Handled=true; } else if (e.Key == Key.Escape || e.Key == Key.Back) { BackOneLayer(); e.Handled=true; }
        }
    }
    // v0.26.4 COMPLETE_BACKEND_SETTINGS_WINDOW_END

    public static class Program
    {
        [DllImport("user32.dll")]
        private static extern bool SetProcessDPIAware();

        [STAThread]
        public static int Main(string[] args)
        {
            try { SetProcessDPIAware(); } catch { }
            try { Environment.SetEnvironmentVariable("PSExecutionPolicyPreference", "Bypass", EnvironmentVariableTarget.Process); } catch { }
            string baseDirectory = AppDomain.CurrentDomain.BaseDirectory;
            AppDomain.CurrentDomain.UnhandledException += delegate(object sender, UnhandledExceptionEventArgs e)
            {
                try { TryWriteHostLog(baseDirectory, "Unhandled AppDomain exception (terminating=" + e.IsTerminating + "): " + (e.ExceptionObject == null ? "<null>" : e.ExceptionObject.ToString())); } catch { }
            };
            System.Threading.Tasks.TaskScheduler.UnobservedTaskException += delegate(object sender, System.Threading.Tasks.UnobservedTaskExceptionEventArgs e)
            {
                try { TryWriteHostLog(baseDirectory, "Unobserved task exception: " + e.Exception); e.SetObserved(); } catch { }
            };
            string bootstrap = Path.Combine(baseDirectory, "HuymaierBootstrap.ps1");
            if (!File.Exists(bootstrap))
            {
                MessageBox.Show("HuymaierBootstrap.ps1 is missing from:\n\n" + baseDirectory,
                    "Huymaier Console", MessageBoxButton.OK, MessageBoxImage.Error);
                return 2;
            }

            try
            {
                InitialSessionState state = InitialSessionState.CreateDefault();
                try
                {
                    System.Reflection.PropertyInfo executionPolicy = typeof(InitialSessionState).GetProperty("ExecutionPolicy");
                    if (executionPolicy != null && executionPolicy.CanWrite)
                    {
                        object bypass = Enum.Parse(executionPolicy.PropertyType, "Bypass", true);
                        executionPolicy.SetValue(state, bypass, null);
                    }
                }
                catch { }
                using (Runspace runspace = RunspaceFactory.CreateRunspace(state))
                {
                    runspace.ApartmentState = ApartmentState.STA;
                    runspace.ThreadOptions = PSThreadOptions.UseCurrentThread;
                    runspace.Open();
                    // Publish a concrete bridge object into the hosted runspace. PowerShell's
                    // type-name resolver does not reliably discover classes compiled into the
                    // entry executable, even though the assembly is already loaded. Passing an
                    // object avoids a second process, Add-Type, or reflection-only UI launch.
                    runspace.SessionStateProxy.SetVariable("HuymaierNativeBridge", new NativeBridge());
                    runspace.SessionStateProxy.SetVariable("HuymaierBaseDirectory", baseDirectory);
                    using (PowerShell shell = PowerShell.Create())
                    {
                        shell.Runspace = runspace;
                        shell.AddCommand("Set-Location").AddParameter("LiteralPath", baseDirectory);
                        shell.AddStatement();
                        shell.AddCommand(bootstrap);
                        if (ContainsArgument(args, "--windowed")) shell.AddParameter("Windowed", true);
                        shell.Invoke();
                        if (shell.HadErrors)
                        {
                            StringBuilder errors = new StringBuilder();
                            foreach (ErrorRecord error in shell.Streams.Error)
                            {
                                if (errors.Length > 0) errors.AppendLine();
                                errors.Append(error.ToString());
                            }
                            if (errors.Length > 0)
                            {
                                MessageBox.Show(errors.ToString(), "Huymaier Console",
                                    MessageBoxButton.OK, MessageBoxImage.Error);
                                return 3;
                            }
                        }
                    }
                }
                return 0;
            }
            catch (Exception ex)
            {
                TryWriteHostLog(baseDirectory, ex.ToString());
                MessageBox.Show("Huymaier Console could not start.\n\n" + ex.Message,
                    "Huymaier Console", MessageBoxButton.OK, MessageBoxImage.Error);
                return 1;
            }
        }

        private static bool ContainsArgument(string[] args, string value)
        {
            if (args == null) return false;
            foreach (string arg in args)
            {
                if (String.Equals(arg, value, StringComparison.OrdinalIgnoreCase)) return true;
            }
            return false;
        }

        private static void TryWriteHostLog(string baseDirectory, string message)
        {
            try
            {
                string root = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                    "Huymaier Console", "Logs");
                Directory.CreateDirectory(root);
                File.AppendAllText(Path.Combine(root, DateTime.Now.ToString("yyyy-MM-dd") + ".log"),
                    DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fff") + " [FATAL] Native host: " + message + Environment.NewLine,
                    Encoding.UTF8);
            }
            catch { }
        }
    }

    public static class NativeQuickAccessRequest
    {
        private static int pending;
        public static void Request() { Interlocked.Exchange(ref pending, 1); }
        public static bool Consume() { return Interlocked.Exchange(ref pending, 0) != 0; }
    }

    public static class NativeWindowActivation
    {
        [DllImport("user32.dll")]
        private static extern bool SetForegroundWindow(IntPtr hWnd);
        [DllImport("user32.dll")]
        private static extern bool BringWindowToTop(IntPtr hWnd);
        [DllImport("user32.dll")]
        private static extern IntPtr SetActiveWindow(IntPtr hWnd);
        [DllImport("user32.dll")]
        private static extern bool ShowWindow(IntPtr hWnd, int command);

        public static void Restore(Window window)
        {
            if (window == null) return;
            Action activate = delegate
            {
                try
                {
                    if (!window.IsLoaded) return;
                    window.Show();
                    bool maximize = window.WindowState == WindowState.Maximized;
                    if (window.WindowState == WindowState.Minimized) window.WindowState = WindowState.Normal;
                    IntPtr handle = new WindowInteropHelper(window).Handle;
                    if (handle != IntPtr.Zero)
                    {
                        // SW_RESTORE silently drops a borderless maximized window back to a
                        // normal desktop window. Preserve true fullscreen on emulator return.
                        ShowWindow(handle, maximize ? 3 : 9);
                        if (maximize) window.WindowState = WindowState.Maximized;
                        BringWindowToTop(handle);
                        SetForegroundWindow(handle);
                        SetActiveWindow(handle);
                    }
                    window.Activate();
                    window.Focus();
                    IInputElement target = window.Content as IInputElement;
                    if (target != null) Keyboard.Focus(target);
                }
                catch { }
            };
            try
            {
                if (window.Dispatcher.CheckAccess()) activate();
                else window.Dispatcher.BeginInvoke(activate);
                System.Windows.Threading.DispatcherTimer retry = new System.Windows.Threading.DispatcherTimer(
                    System.Windows.Threading.DispatcherPriority.Input, window.Dispatcher);
                retry.Interval = TimeSpan.FromMilliseconds(180);
                retry.Tick += delegate
                {
                    retry.Stop();
                    activate();
                };
                retry.Start();
            }
            catch { }
        }
    }

    public sealed class NativeBridge
    {
        public string Version { get { return "0.26.3"; } }

        public bool ConsumeQuickAccessRequest() { return NativeQuickAccessRequest.Consume(); }

        public void ShowPs3Xmb(string platformRoot, string consoleRoot)
        {
            ShowPs3Xmb(platformRoot, consoleRoot, null);
        }

        public void ShowPs3Xmb(string platformRoot, string consoleRoot, Window owner)
        {
            try
            {
                Ps3XmbWindow window = new Ps3XmbWindow(platformRoot, consoleRoot);
                if (owner != null && owner.IsLoaded)
                {
                    window.Owner = owner;
                    window.WindowStartupLocation = WindowStartupLocation.CenterOwner;
                }
                window.ShowDialog();
            }
            catch (Exception ex)
            {
                TryWriteBridgeLog(ex.ToString());
                try
                {
                    MessageBox.Show("The PS3 interface closed unexpectedly and Huymaier Console recovered.\n\n" + ex.Message,
                        "Huymaier Console", MessageBoxButton.OK, MessageBoxImage.Error);
                }
                catch { }
            }
            finally
            {
                // Raw Input registration is process-global for a usage page. The
                // modal XMB temporarily becomes the target, so restore the main
                // Console HWND after it closes or Bluetooth Sony input can appear
                // dead until the application is restarted.
                try
                {
                    if (owner != null && owner.IsLoaded)
                    {
                        IntPtr handle = new WindowInteropHelper(owner).Handle;
                        if (handle != IntPtr.Zero) HuymaierConsole.Native.RawHidController.Register(handle);
                    }
                    NativeConsoleNavigation.Reset();
                    NativeWindowActivation.Restore(owner);
                }
                catch { }
            }
        }

        public void ShowPs1Classic(string platformRoot, string consoleRoot)
        {
            ShowPs1Classic(platformRoot, consoleRoot, null);
        }

        public void ShowPs1Classic(string platformRoot, string consoleRoot, Window owner)
        {
            try
            {
                Ps1ClassicWindow window = new Ps1ClassicWindow(platformRoot, consoleRoot);
                if (owner != null && owner.IsLoaded)
                {
                    window.Owner = owner;
                    window.WindowStartupLocation = WindowStartupLocation.CenterOwner;
                }
                window.ShowDialog();
            }
            catch (Exception ex)
            {
                TryWriteBridgeLog("PS1: " + ex.ToString());
                try
                {
                    MessageBox.Show("The PlayStation interface closed unexpectedly and Huymaier Console recovered.\n\n" + ex.Message,
                        "Huymaier Console", MessageBoxButton.OK, MessageBoxImage.Error);
                }
                catch { }
            }
            finally
            {
                try
                {
                    if (owner != null && owner.IsLoaded)
                    {
                        IntPtr handle = new WindowInteropHelper(owner).Handle;
                        if (handle != IntPtr.Zero) HuymaierConsole.Native.RawHidController.Register(handle);
                    }
                    NativeConsoleNavigation.Reset();
                    NativeWindowActivation.Restore(owner);
                }
                catch { }
            }
        }

        public void ShowPs2Bbn(string platformRoot, string consoleRoot)
        {
            ShowPs2Bbn(platformRoot, consoleRoot, null);
        }

        public void ShowPs2Bbn(string platformRoot, string consoleRoot, Window owner)
        {
            try
            {
                Ps2BbnWindow window = new Ps2BbnWindow(platformRoot, consoleRoot);
                if (owner != null && owner.IsLoaded)
                {
                    window.Owner = owner;
                    window.WindowStartupLocation = WindowStartupLocation.CenterOwner;
                }
                window.ShowDialog();
            }
            catch (Exception ex)
            {
                TryWriteBridgeLog("PS2: " + ex.ToString());
                try
                {
                    MessageBox.Show("The PlayStation 2 interface closed unexpectedly and Huymaier Console recovered.\n\n" + ex.Message,
                        "Huymaier Console", MessageBoxButton.OK, MessageBoxImage.Error);
                }
                catch { }
            }
            finally
            {
                try
                {
                    if (owner != null && owner.IsLoaded)
                    {
                        IntPtr handle = new WindowInteropHelper(owner).Handle;
                        if (handle != IntPtr.Zero) HuymaierConsole.Native.RawHidController.Register(handle);
                    }
                    NativeConsoleNavigation.Reset();
                    NativeWindowActivation.Restore(owner);
                }
                catch { }
            }
        }

        public void ShowConsolePlatform(string platformRoot, string consoleRoot, string platformId)
        {
            ShowConsolePlatform(platformRoot, consoleRoot, platformId, null);
        }

        public void ShowConsolePlatform(string platformRoot, string consoleRoot, string platformId, Window owner)
        {
            try
            {
                ConsolePlatformWindow window = new ConsolePlatformWindow(platformRoot, consoleRoot, platformId);
                if (owner != null && owner.IsLoaded)
                {
                    window.Owner = owner;
                    window.WindowStartupLocation = WindowStartupLocation.CenterOwner;
                }
                window.ShowDialog();
            }
            catch (Exception ex)
            {
                TryWriteBridgeLog((platformId ?? "Console") + ": " + ex.ToString());
                try
                {
                    MessageBox.Show((platformId ?? "Console") + " closed unexpectedly and Huymaier Console recovered.\n\n" + ex.Message,
                        "Huymaier Console", MessageBoxButton.OK, MessageBoxImage.Error);
                }
                catch { }
            }
            finally
            {
                try
                {
                    if (owner != null && owner.IsLoaded)
                    {
                        IntPtr handle = new WindowInteropHelper(owner).Handle;
                        if (handle != IntPtr.Zero) HuymaierConsole.Native.RawHidController.Register(handle);
                    }
                    NativeConsoleNavigation.Reset();
                    NativeWindowActivation.Restore(owner);
                }
                catch { }
            }
        }

        private static void TryWriteBridgeLog(string message)
        {
            try
            {
                string platform = "PS3";
                if (!String.IsNullOrWhiteSpace(message))
                {
                    int colon = message.IndexOf(':');
                    if (colon > 0 && colon < 40)
                    {
                        string candidate = message.Substring(0, colon).Trim();
                        if (!String.IsNullOrWhiteSpace(candidate)) platform = candidate;
                    }
                }
                foreach (char invalid in Path.GetInvalidFileNameChars()) platform = platform.Replace(invalid, '_');
                string root = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                    "Huymaier Console", "EmulatorPlatforms", platform.ToUpperInvariant());
                Directory.CreateDirectory(root);
                string logName = platform.ToLowerInvariant().Replace(" ", "-") + "-native.log";
                File.AppendAllText(Path.Combine(root, logName),
                    DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fff") + " [ERROR] Native bridge: " + message + Environment.NewLine,
                    Encoding.UTF8);
            }
            catch { }
        }
    }

    public sealed class Ps3XmbWindow : Window
    {
        private readonly string platformRoot;
        private readonly string consoleRoot;
        private readonly string appDataRoot;
        private readonly string settingsPath;
        private readonly string themeRoot;
        private readonly string cacheRoot;
        private readonly string logPath;
        private readonly XmbSurface surface;
        private readonly System.Windows.Threading.DispatcherTimer inputTimer;
        private readonly System.Windows.Threading.DispatcherTimer idleTimer;
        private readonly System.Windows.Threading.DispatcherTimer healthTimer;
        private readonly XmbInputRouter input;
        private readonly XmbAudio audio;
        private readonly XmbTheme theme;
        private readonly ConsoleStartupVideoOverlay startupVideoOverlay;
        private Ps3Settings settings;
        private List<XmbCategory> categories;
        private readonly Stack<XmbMenuContext> menuStack;
        private int categoryIndex;
        private int selectedIndex;
        private double visualCategory;
        private double visualItem;
        private DateTime selectedAtUtc;
        private DateTime noticeUntilUtc;
        private string noticeText;
        private bool inputSuspended;
        private bool mouseHidden;
        private Point lastMousePoint;
        private HwndSource hwndSource;
        private HwndSourceHook rawHook;
        private readonly Dictionary<string, BitmapSource> imageCache;
        private Process activeEmulatorProcess;
        private DateTime emulatorLaunchUtc;
        private string activeBootTarget;
        private bool renderingAttached;
        private bool closing;
        private bool closeRequested;
        private bool softMemoryMode;
        private bool hardMemoryTriggered;
        private bool scanRunning;
        private int scanGeneration;
        private long lastRenderTimestamp;
        private DateTime inputGuardUntilUtc;
        private readonly Rpcs3YamlAdapter configAdapter;
        private List<Ps3Game> currentGames;
        private List<TrophySet> trophySets;
        private List<string> photoFiles;
        private int photoViewerIndex;
        private bool photoViewerActive;
        private int auxiliaryGeneration;

        public Ps3XmbWindow(string platformRoot, string consoleRoot)
        {
            this.platformRoot = String.IsNullOrWhiteSpace(platformRoot) ? AppDomain.CurrentDomain.BaseDirectory : platformRoot;
            this.consoleRoot = String.IsNullOrWhiteSpace(consoleRoot) ? AppDomain.CurrentDomain.BaseDirectory : consoleRoot;
            appDataRoot = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "Huymaier Console", "EmulatorPlatforms", "PS3");
            settingsPath = Path.Combine(appDataRoot, "settings.json");
            themeRoot = Path.Combine(appDataRoot, "Themes");
            cacheRoot = Path.Combine(appDataRoot, "Cache");
            logPath = Path.Combine(appDataRoot, "ps3-native-xmb.log");
            Directory.CreateDirectory(appDataRoot);
            Directory.CreateDirectory(themeRoot);
            Directory.CreateDirectory(cacheRoot);

            settings = Ps3Settings.Load(settingsPath, Path.Combine(this.platformRoot, "settings.default.json"));
            configAdapter = new Rpcs3YamlAdapter(delegate { return GetRpcs3DataRoot(); }, WriteLog);
            currentGames = new List<Ps3Game>();
            trophySets = new List<TrophySet>();
            photoFiles = new List<string>();
            photoViewerIndex = -1;
            imageCache = new Dictionary<string, BitmapSource>(StringComparer.OrdinalIgnoreCase);
            menuStack = new Stack<XmbMenuContext>();
            categories = new List<XmbCategory>();
            categoryIndex = 6;
            selectedIndex = 0;
            visualCategory = categoryIndex;
            visualItem = selectedIndex;
            selectedAtUtc = DateTime.UtcNow;
            noticeText = String.Empty;
            noticeUntilUtc = DateTime.MinValue;

            Title = "PlayStation 3";
            WindowStyle = WindowStyle.None;
            ResizeMode = ResizeMode.NoResize;
            WindowState = settings.fullscreen ? WindowState.Maximized : WindowState.Normal;
            Width = 1280;
            Height = 720;
            MinWidth = 960;
            MinHeight = 540;
            Background = Brushes.Black;
            ShowInTaskbar = false;
            SnapsToDevicePixels = true;
            Focusable = true;

            theme = new XmbTheme(this);
            audio = new XmbAudio(this);
            input = new XmbInputRouter();
            surface = new XmbSurface(this);
            Grid ps3Root = new Grid();
            ps3Root.Children.Add(surface);
            startupVideoOverlay = new ConsoleStartupVideoOverlay();
            ps3Root.Children.Add(startupVideoOverlay);
            Content = ps3Root;

            BuildMenus();
            RestoreLastPosition();
            theme.Refresh();
            audio.Refresh();
            BeginLibraryScan(false);

            inputGuardUntilUtc = DateTime.UtcNow.AddMilliseconds(450);

            inputTimer = new System.Windows.Threading.DispatcherTimer(System.Windows.Threading.DispatcherPriority.Input);
            inputTimer.Interval = TimeSpan.FromMilliseconds(8);
            inputTimer.Tick += InputTimerTick;

            idleTimer = new System.Windows.Threading.DispatcherTimer(System.Windows.Threading.DispatcherPriority.Background);
            idleTimer.Interval = TimeSpan.FromMilliseconds(500);
            idleTimer.Tick += IdleTimerTick;

            healthTimer = new System.Windows.Threading.DispatcherTimer(System.Windows.Threading.DispatcherPriority.Background);
            healthTimer.Interval = TimeSpan.FromSeconds(2);
            healthTimer.Tick += HealthTimerTick;

            // Contain XMB dispatcher faults inside the native platform view. A bad
            // metadata file, theme resource, or late background callback must return
            // to Huymaier Console instead of terminating the shared process.
            Dispatcher.UnhandledException += DispatcherUnhandledException;
            SourceInitialized += WindowSourceInitialized;
            Loaded += WindowLoaded;
            Activated += WindowActivated;
            Deactivated += WindowDeactivated;
            Closing += WindowClosing;
            Closed += WindowClosed;
            PreviewKeyDown += WindowPreviewKeyDown;
            MouseMove += WindowMouseMove;
            PreviewMouseDown += WindowPreviewMouseDown;
        }

        internal Ps3Settings Settings { get { return settings; } }
        internal XmbTheme Theme { get { return theme; } }
        internal string GetIncludedMusicPath(string fileName)
        {
            return Path.Combine(platformRoot, "Assets", "Audio", fileName ?? String.Empty);
        }
        internal int CategoryIndex { get { return categoryIndex; } }
        internal int SelectedIndex { get { return selectedIndex; } }
        internal double VisualCategory { get { return visualCategory; } }
        internal double VisualItem { get { return visualItem; } }
        internal bool InSubmenu { get { return menuStack.Count > 0; } }
        internal DateTime SelectedAtUtc { get { return selectedAtUtc; } }
        internal string NoticeText { get { return DateTime.UtcNow < noticeUntilUtc ? noticeText : String.Empty; } }
        internal bool PhotoViewerActive { get { return photoViewerActive && photoViewerIndex >= 0 && photoViewerIndex < photoFiles.Count; } }
        internal string CurrentPhotoPath { get { return PhotoViewerActive ? photoFiles[photoViewerIndex] : String.Empty; } }
        internal string PhotoViewerCaption { get { return PhotoViewerActive ? Path.GetFileName(photoFiles[photoViewerIndex]) + "   " + (photoViewerIndex + 1).ToString(CultureInfo.InvariantCulture) + " / " + photoFiles.Count.ToString(CultureInfo.InvariantCulture) : String.Empty; } }
        internal List<XmbCategory> Categories { get { return categories; } }
        internal List<XmbItem> CurrentItems
        {
            get
            {
                if (menuStack.Count > 0) return menuStack.Peek().Items;
                if (categoryIndex < 0 || categoryIndex >= categories.Count) return new List<XmbItem>();
                return categories[categoryIndex].Items;
            }
        }
        internal string CurrentMenuTitle
        {
            get
            {
                if (menuStack.Count > 0) return menuStack.Peek().Title;
                if (categoryIndex >= 0 && categoryIndex < categories.Count) return categories[categoryIndex].Title;
                return String.Empty;
            }
        }
        internal XmbItem CurrentItem
        {
            get
            {
                List<XmbItem> items = CurrentItems;
                if (items.Count == 0) return null;
                int index = Math.Max(0, Math.Min(items.Count - 1, selectedIndex));
                return items[index];
            }
        }

        private void WindowLoaded(object sender, RoutedEventArgs e)
        {
            Focus();
            Keyboard.Focus(surface);
            inputTimer.Start();
            idleTimer.Start();
            healthTimer.Start();
            AttachRendering();
            HideMouse();
            BeginAuxiliaryDataScan();
            string startupVideo = Path.Combine(platformRoot, "Assets", "Startup.mp4");
            if (settings.startupVideoEnabled)
            {
                audio.PauseMusic();
                startupVideoOverlay.Play(startupVideo, 1.0, delegate { if (!inputSuspended && IsActive) audio.ResumeMusic(); });
            }
        }

        private void WindowActivated(object sender, EventArgs e)
        {
            input.Reset();
            inputGuardUntilUtc = DateTime.UtcNow.AddMilliseconds(300);
            lastRenderTimestamp = 0;
            if (!inputSuspended && !startupVideoOverlay.IsActive) audio.ResumeMusic();
            surface.InvalidateVisual();
        }

        private void WindowDeactivated(object sender, EventArgs e)
        {
            input.Reset();
            audio.PauseMusic();
        }

        private void WindowSourceInitialized(object sender, EventArgs e)
        {
            try
            {
                WindowInteropHelper helper = new WindowInteropHelper(this);
                hwndSource = HwndSource.FromHwnd(helper.Handle);
                rawHook = new HwndSourceHook(RawInputHook);
                if (hwndSource != null) hwndSource.AddHook(rawHook);
                HuymaierConsole.Native.RawHidController.Register(helper.Handle);
            }
            catch (Exception ex)
            {
                WriteLog("Raw HID initialization failed: " + ex.Message, "WARN");
            }
        }

        private IntPtr RawInputHook(IntPtr hwnd, int message, IntPtr wParam, IntPtr lParam, ref bool handled)
        {
            if (message == 0x00FF)
            {
                try { HuymaierConsole.Native.RawHidController.ProcessInput(lParam); } catch { }
                handled = false;
            }
            else if (message == 0x00FE)
            {
                try
                {
                    HuymaierConsole.Native.RawHidController.ProcessDeviceChange(wParam, lParam);
                    NativeConsoleNavigation.NotifyDeviceChange();
                    inputGuardUntilUtc = DateTime.UtcNow.AddMilliseconds(750);
                }
                catch { }
                handled = false;
            }
            return IntPtr.Zero;
        }

        private void WindowClosing(object sender, System.ComponentModel.CancelEventArgs e)
        {
            if (closing) return;
            closing = true;
            closeRequested = true;
            inputSuspended = true;
            scanGeneration++;
            auxiliaryGeneration++;
            scanRunning = false;
            try { inputTimer.Stop(); } catch { }
            try { idleTimer.Stop(); } catch { }
            try { healthTimer.Stop(); } catch { }
            try { DetachRendering(); } catch { }
            try
            {
                if (activeEmulatorProcess != null)
                {
                    activeEmulatorProcess.Exited -= EmulatorExited;
                    activeEmulatorProcess.Dispose();
                    activeEmulatorProcess = null;
                }
            }
            catch { }
            try { input.Reset(); } catch { }
            try { ShowMouse(); } catch { }
            try { SavePosition(); }
            catch (Exception ex) { WriteLog("PS3 position save during close failed: " + ex.Message, "WARN"); }
        }

        private void WindowClosed(object sender, EventArgs e)
        {
            try { Dispatcher.UnhandledException -= DispatcherUnhandledException; } catch { }
            try { startupVideoOverlay.Stop(); } catch { }
            try { audio.Dispose(); } catch { }
            try
            {
                if (hwndSource != null && rawHook != null) hwndSource.RemoveHook(rawHook);
            }
            catch { }
            hwndSource = null;
            rawHook = null;
            try { imageCache.Clear(); } catch { }
        }


        private void DispatcherUnhandledException(object sender, System.Windows.Threading.DispatcherUnhandledExceptionEventArgs e)
        {
            try { WriteLog("PS3 XMB dispatcher recovered from an unhandled error: " + e.Exception, "ERROR"); } catch { }
            // This handler is attached only while the modal XMB is alive. Mark the
            // fault handled so one malformed title/theme cannot take down the full
            // Huymaier Console process. Close the XMB safely if shutdown has begun;
            // otherwise keep the interface alive and surface a concise notice.
            e.Handled = true;
            if (closing || closeRequested)
            {
                try { RequestClose(); } catch { }
                return;
            }
            try { ShowNotice("The PS3 interface recovered from an internal error. Details were written to the PS3 log."); } catch { }
        }

        private void RequestClose()
        {
            if (closing || closeRequested) return;
            closeRequested = true;
            inputSuspended = true;
            try { input.Reset(); } catch { }
            try
            {
                Dispatcher.BeginInvoke(System.Windows.Threading.DispatcherPriority.Background,
                    new Action(delegate
                    {
                        if (!closing) Close();
                    }));
            }
            catch
            {
                try { Close(); } catch { }
            }
        }

        private void SafeBeginUi(Action action, string context)
        {
            if (action == null || closing || Dispatcher.HasShutdownStarted || Dispatcher.HasShutdownFinished) return;
            try
            {
                Dispatcher.BeginInvoke(new Action(delegate
                {
                    if (closing) return;
                    try { action(); }
                    catch (Exception ex)
                    {
                        WriteLog(context + " UI callback recovered from an error: " + ex, "ERROR");
                        ShowNotice("The PS3 interface recovered from an internal error. Details were written to the PS3 log.");
                    }
                }));
            }
            catch (Exception ex) { WriteLog(context + " UI callback was cancelled safely: " + ex.Message, "WARN"); }
        }

        private void InputTimerTick(object sender, EventArgs e)
        {
            if (closing || inputSuspended || !IsActive || DateTime.UtcNow < inputGuardUntilUtc) return;
            XmbInputCommand command = input.Poll();
            if (command == XmbInputCommand.None) return;
            if (command == XmbInputCommand.Menu) { NativeQuickAccessRequest.Request(); RequestClose(); return; }
            if (startupVideoOverlay.IsActive)
            {
                if (command == XmbInputCommand.Confirm || command == XmbInputCommand.Back) startupVideoOverlay.Skip();
                return;
            }
            HideMouse();
            HandleInput(command);
            surface.InvalidateVisual();
        }

        private void AttachRendering()
        {
            if (renderingAttached) return;
            CompositionTarget.Rendering += CompositionRendering;
            renderingAttached = true;
            lastRenderTimestamp = 0;
        }

        private void DetachRendering()
        {
            if (!renderingAttached) return;
            CompositionTarget.Rendering -= CompositionRendering;
            renderingAttached = false;
        }

        private void CompositionRendering(object sender, EventArgs e)
        {
            if (closing || inputSuspended || !IsVisible || !IsActive || WindowState == WindowState.Minimized) return;
            long now = Stopwatch.GetTimestamp();
            if (lastRenderTimestamp == 0)
            {
                lastRenderTimestamp = now;
                return;
            }
            double deltaSeconds = (now - lastRenderTimestamp) / (double)Stopwatch.Frequency;
            lastRenderTimestamp = now;
            if (deltaSeconds <= 0.0) return;
            deltaSeconds = Math.Min(0.10, deltaSeconds);

            double factorCategory = settings.hideMouseWhenControllerActive ? 1.0 - Math.Exp(-13.5 * deltaSeconds) : 1.0 - Math.Exp(-12.0 * deltaSeconds);
            double factorItem = 1.0 - Math.Exp(-15.0 * deltaSeconds);
            visualCategory += (categoryIndex - visualCategory) * factorCategory;
            visualItem += (selectedIndex - visualItem) * factorItem;
            if (Math.Abs(categoryIndex - visualCategory) < 0.001) visualCategory = categoryIndex;
            if (Math.Abs(selectedIndex - visualItem) < 0.001) visualItem = selectedIndex;

            surface.AdvanceFrame(deltaSeconds, softMemoryMode);
            if (!softMemoryMode || Math.Abs(categoryIndex - visualCategory) >= 0.001 || Math.Abs(selectedIndex - visualItem) >= 0.001 || DateTime.UtcNow < noticeUntilUtc)
                surface.InvalidateVisual();
        }

        private void IdleTimerTick(object sender, EventArgs e)
        {
            if (closing || !IsVisible || !IsActive || WindowState == WindowState.Minimized) return;
            surface.InvalidateVisual();
        }

        private void HealthTimerTick(object sender, EventArgs e)
        {
            if (closing) return;
            try
            {
                long megabytes = Process.GetCurrentProcess().WorkingSet64 / (1024 * 1024);
                if (megabytes > 1024 && !softMemoryMode)
                {
                    softMemoryMode = true;
                    imageCache.Clear();
                    ShowNotice("Memory guard reduced XMB animation and cleared artwork cache");
                    WriteLog("Memory guard enabled at " + megabytes + " MB.", "WARN");
                }
                if (megabytes > 1536 && !hardMemoryTriggered)
                {
                    hardMemoryTriggered = true;
                    WriteLog("Memory guard closing XMB at " + megabytes + " MB.", "ERROR");
                    MessageBox.Show("The PS3 interface exceeded its safety memory limit and will return to Huymaier Console instead of exhausting Windows memory.",
                        "Huymaier Console Memory Guard", MessageBoxButton.OK, MessageBoxImage.Error);
                    RequestClose();
                }
            }
            catch { }
        }

        private void HandleInput(XmbInputCommand command)
        {
            if (PhotoViewerActive)
            {
                if (command == XmbInputCommand.Left || command == XmbInputCommand.LeftShoulder) MovePhoto(-1);
                else if (command == XmbInputCommand.Right || command == XmbInputCommand.RightShoulder) MovePhoto(1);
                else if (command == XmbInputCommand.Back || command == XmbInputCommand.Confirm) ClosePhotoViewer();
                return;
            }
            switch (command)
            {
                case XmbInputCommand.Left: MoveHorizontal(-1); break;
                case XmbInputCommand.Right: MoveHorizontal(1); break;
                case XmbInputCommand.Up: MoveVertical(-1); break;
                case XmbInputCommand.Down: MoveVertical(1); break;
                case XmbInputCommand.Confirm: InvokeSelected(); break;
                case XmbInputCommand.Back: NavigateBack(); break;
                case XmbInputCommand.LeftShoulder: MoveHorizontal(-1); break;
                case XmbInputCommand.RightShoulder: MoveHorizontal(1); break;
                case XmbInputCommand.Menu: NativeQuickAccessRequest.Request(); RequestClose(); break;
            }
        }

        private void WindowPreviewKeyDown(object sender, KeyEventArgs e)
        {
            XmbInputCommand command = XmbInputCommand.None;
            if (e.Key == Key.Left) command = XmbInputCommand.Left;
            else if (e.Key == Key.Right) command = XmbInputCommand.Right;
            else if (e.Key == Key.Up) command = XmbInputCommand.Up;
            else if (e.Key == Key.Down) command = XmbInputCommand.Down;
            else if (e.Key == Key.Enter || e.Key == Key.Space) command = XmbInputCommand.Confirm;
            else if (e.Key == Key.Escape || e.Key == Key.Back) command = XmbInputCommand.Back;
            if (command != XmbInputCommand.None)
            {
                e.Handled = true;
                if (startupVideoOverlay.IsActive)
                {
                    if (command == XmbInputCommand.Confirm || command == XmbInputCommand.Back) startupVideoOverlay.Skip();
                    return;
                }
                HandleInput(command);
            }
        }

        private void WindowMouseMove(object sender, MouseEventArgs e)
        {
            Point current = e.GetPosition(this);
            if (Math.Abs(current.X - lastMousePoint.X) > 2 || Math.Abs(current.Y - lastMousePoint.Y) > 2)
            {
                lastMousePoint = current;
                ShowMouse();
            }
        }

        private void WindowPreviewMouseDown(object sender, MouseButtonEventArgs e)
        {
            ShowMouse();
            Point position = e.GetPosition(surface);
            int hit = surface.HitTestItem(position);
            if (hit >= 0 && hit < CurrentItems.Count)
            {
                if (hit == selectedIndex) InvokeSelected();
                else
                {
                    selectedIndex = hit;
                    visualItem = selectedIndex;
                    SelectionChanged();
                    audio.Play("move");
                }
                e.Handled = true;
            }
        }

        private void HideMouse()
        {
            if (mouseHidden || !settings.hideMouseWhenControllerActive) return;
            Mouse.OverrideCursor = Cursors.None;
            mouseHidden = true;
        }

        private void ShowMouse()
        {
            if (!mouseHidden) return;
            Mouse.OverrideCursor = null;
            mouseHidden = false;
        }

        private void MoveHorizontal(int delta)
        {
            if (menuStack.Count > 0)
            {
                if (delta < 0) NavigateBack();
                else
                {
                    XmbItem current = CurrentItem;
                    if (current != null && current.Children != null && current.Children.Count > 0) InvokeSelected();
                }
                return;
            }
            int next = Math.Max(0, Math.Min(categories.Count - 1, categoryIndex + delta));
            if (next == categoryIndex) return;
            SaveCurrentCategoryIndex();
            categoryIndex = next;
            selectedIndex = categories[categoryIndex].SelectedIndex;
            visualItem = selectedIndex;
            SelectionChanged();
            audio.Play("category");
            settings.lastCategory = categories[categoryIndex].Id;
            settings.Save(settingsPath);
        }

        private void MoveVertical(int delta)
        {
            List<XmbItem> items = CurrentItems;
            if (items.Count == 0) return;
            int next = Math.Max(0, Math.Min(items.Count - 1, selectedIndex + delta));
            if (next == selectedIndex) return;
            selectedIndex = next;
            SelectionChanged();
            audio.Play("move");
            if (menuStack.Count == 0) SaveCurrentCategoryIndex();
        }

        private void SelectionChanged()
        {
            selectedAtUtc = DateTime.UtcNow;
            surface.InvalidateVisual();
        }

        private void SaveCurrentCategoryIndex()
        {
            if (categoryIndex >= 0 && categoryIndex < categories.Count)
                categories[categoryIndex].SelectedIndex = selectedIndex;
        }

        private void InvokeSelected()
        {
            XmbItem item = CurrentItem;
            if (item == null) return;
            audio.Play("confirm");
            if (item.Children != null && item.Children.Count > 0)
            {
                menuStack.Push(new XmbMenuContext(item.Title, item.Children, selectedIndex));
                selectedIndex = 0;
                visualItem = 0;
                SelectionChanged();
                return;
            }
            if (item.Game != null)
            {
                LaunchGame(item.Game);
                return;
            }
            InvokeAction(item.Action, item);
        }

        private void NavigateBack()
        {
            audio.Play("cancel");
            if (menuStack.Count > 0)
            {
                XmbMenuContext context = menuStack.Pop();
                selectedIndex = context.ParentSelection;
                visualItem = selectedIndex;
                SelectionChanged();
                return;
            }
            // Match the real XMB: Circle at the root does not close the shell.
            // Returning to Huymaier Console is an explicit Users > Turn Off System action.
            ShowNotice("Use Users > Turn Off System to return to Huymaier Console");
        }

        private void InvokeAction(string action, XmbItem item)
        {
            if (String.IsNullOrWhiteSpace(action)) return;
            if (action.StartsWith("Cfg|", StringComparison.Ordinal))
            {
                CycleConfiguration(action, item);
                RefreshDynamicSubtitles();
                surface.InvalidateVisual();
                return;
            }
            if (action.StartsWith("ViewPhoto|", StringComparison.Ordinal))
            {
                OpenPhotoViewer(DecodeActionValue(action.Substring(10)));
                return;
            }
            if (action.StartsWith("TrophyInfo|", StringComparison.Ordinal))
            {
                ShowNotice(item == null ? "Trophy" : item.Subtitle);
                return;
            }
            if (action.StartsWith("RemoveLibrary|", StringComparison.Ordinal))
            {
                RemoveLibraryFolder(DecodeActionValue(action.Substring(14)));
                return;
            }
            if (action.StartsWith("SaveBackup|", StringComparison.Ordinal))
            {
                BackupSave(DecodeActionValue(action.Substring(11)));
                return;
            }
            if (action.StartsWith("SaveExport|", StringComparison.Ordinal))
            {
                ExportSave(DecodeActionValue(action.Substring(11)));
                return;
            }
            if (action.StartsWith("SaveTrash|", StringComparison.Ordinal))
            {
                TrashSave(DecodeActionValue(action.Substring(10)));
                return;
            }
            if (action.StartsWith("SaveOpen|", StringComparison.Ordinal))
            {
                OpenFolderPath(DecodeActionValue(action.Substring(9)));
                return;
            }
            if (action.StartsWith("SaveRestore|", StringComparison.Ordinal))
            {
                RestoreSave(DecodeActionValue(action.Substring(12)));
                return;
            }
            if (action.StartsWith("ApplyFirmwareTheme|", StringComparison.Ordinal))
            {
                ApplyFirmwareTheme(DecodeActionValue(action.Substring(19)));
                return;
            }
            if (action.StartsWith("ApplyInstalledTheme|", StringComparison.Ordinal))
            {
                ApplyInstalledTheme(DecodeActionValue(action.Substring(20)));
                return;
            }
            if (action.StartsWith("SelectRpcs3User|", StringComparison.Ordinal))
            {
                SelectRpcs3User(action.Substring(16));
                return;
            }
            switch (action)
            {
                case "Exit": RequestClose(); break;
                case "ChooseRpcs3": ChooseExistingRpcs3(); break;
                case "InstallRpcs3": InstallManagedRpcs3(); break;
                case "ChangeDataPath": ChooseRpcs3DataPath(); break;
                case "RescanRpcs3": RescanRpcs3Configuration(); break;
                case "InstallFirmware": InstallFirmware(); break;
                case "AddLibrary": AddLibraryFolder(); break;
                case "Rescan": BeginLibraryScan(true); break;
                case "FullRpcs3Settings": OpenFullRpcs3Settings(); break;
                case "OpenRpcs3": OpenRpcs3Ui(); break;
                case "OpenGameData": OpenDataFolder("dev_hdd0\\game"); break;
                case "OpenSaves": OpenSaveManager(); break;
                case "RefreshSaves": RefreshSaveManager(); break;
                case "OpenSaveBackups": OpenSaveBackups(); break;
                case "OpenTrophies": FocusTrophyCollection(); break;
                case "RefreshTrophies": BeginAuxiliaryDataScan(); ShowNotice("Refreshing trophies and screenshots..."); break;
                case "AssetFirmware": SetAssetSource("Firmware Assets"); break;
                case "AssetHuymaier": SetAssetSource("Huymaier Default"); break;
                case "AssetInstalledTheme": SetAssetSource("Installed .p3t Theme"); break;
                case "AssetCustom": ChooseCustomAssetFolder(); break;
                case "RefreshFirmwareAssets": RefreshFirmwareAssetCache(); break;
                case "RefreshFirmwareThemes": UpdateFirmwareThemesMenu(); ShowNotice("Firmware theme list refreshed"); break;
                case "RefreshInstalledThemes": UpdateInstalledThemesMenu(); ShowNotice("Installed theme list refreshed"); break;
                case "RefreshRpcs3Users": UpdateUsersMenu(); ShowNotice("RPCS3 user list refreshed"); break;
                case "ChooseScreenshotFolder": ChooseScreenshotFolder(); break;
                case "RefreshPhotos": BeginAuxiliaryDataScan(); ShowNotice("Refreshing screenshots..."); break;
                case "InstallPackage": InstallPackage(); break;
                case "ClearCaches": ClearRpcs3Caches(); break;
                case "OpenLogs": OpenDataFolder("cache"); break;
                case "ImportTheme": ImportTheme(); break;
                case "OriginalTheme": RestoreOriginalTheme(); break;
                case "CycleXmbColorMode": CycleXmbColorMode(); break;
                case "ChooseXmbCustomColor": ChooseXmbCustomColor(); break;
                case "ChooseBackground": ChooseBackground(); break;
                case "ChooseMusic": ChooseMusic(); break;
                case "RestoreIncludedMusic": RestoreIncludedMusic(); break;
                case "ToggleMusic": ToggleMusic(); break;
                case "MusicVolume": CycleMusicVolume(); break;
                case "ToggleSounds": ToggleSounds(); break;
                case "SoundVolume": CycleSoundVolume(); break;
                case "ChooseMoveSound": ChooseSound("move"); break;
                case "ChooseConfirmSound": ChooseSound("confirm"); break;
                case "ChooseCancelSound": ChooseSound("cancel"); break;
                case "Placeholder": ShowNotice(item == null ? "Not available yet" : item.Title); break;
                default: ShowNotice(action); break;
            }
            RefreshDynamicSubtitles();
            surface.InvalidateVisual();
        }

        private void RefreshDynamicSubtitles()
        {
            foreach (XmbCategory category in categories)
                RefreshDynamicSubtitles(category.Items);
        }

        private void RefreshDynamicSubtitles(List<XmbItem> items)
        {
            if (items == null) return;
            foreach (XmbItem item in items)
            {
                switch (item.Action)
                {
                    case "ChooseRpcs3": item.Subtitle = GetRpcs3StatusText(); break;
                    case "InstallRpcs3": item.Subtitle = GetManagedInstallText(); break;
                    case "ChangeDataPath": item.Subtitle = GetRpcs3DataRootDisplay(); break;
                    case "InstallFirmware": item.Subtitle = GetFirmwareStatusText(); break;
                    case "AddLibrary": item.Subtitle = GetLibrarySummary(); break;
                    case "LibraryFoldersRoot": item.Subtitle = GetLibrarySummary(); break;
                    case "ChooseBackground": item.Subtitle = GetBackgroundText(); break;
                    case "CycleXmbColorMode": item.Subtitle = GetXmbColorModeText(); break;
                    case "ChooseXmbCustomColor": item.Subtitle = settings.xmbCustomColor; break;
                    case "ChooseMusic": item.Subtitle = GetMusicText(); break;
                    case "ToggleMusic": item.Subtitle = settings.musicEnabled ? "On" : "Off"; break;
                    case "MusicVolume": item.Subtitle = FormatPercent(settings.musicVolume); break;
                    case "ToggleSounds": item.Subtitle = settings.soundEnabled ? "On" : "Off"; break;
                    case "SoundVolume": item.Subtitle = FormatPercent(settings.soundVolume); break;
                    case "ChooseMoveSound": item.Subtitle = GetSoundText(settings.sounds.move); break;
                    case "ChooseConfirmSound": item.Subtitle = GetSoundText(settings.sounds.confirm); break;
                    case "ChooseCancelSound": item.Subtitle = GetSoundText(settings.sounds.cancel); break;
                    case "OriginalTheme": item.Subtitle = String.Equals(item.Title, "Theme", StringComparison.OrdinalIgnoreCase) ? settings.theme : "Restore firmware-derived XMB assets"; break;
                    case "AssetFirmware": item.Subtitle = settings.xmbAssetSource == "Firmware Assets" ? "Selected" : GetFirmwareAssetCacheStatus(); break;
                    case "AssetHuymaier": item.Subtitle = settings.xmbAssetSource == "Huymaier Default" ? "Selected" : "Built-in recovery appearance"; break;
                    case "AssetInstalledTheme": item.Subtitle = settings.xmbAssetSource == "Installed .p3t Theme" ? "Selected: " + settings.theme : settings.theme; break;
                    case "AssetCustom": item.Subtitle = settings.xmbAssetSource == "Custom Folder" ? settings.customAssetFolder : "Choose an extracted asset folder"; break;
                    case "FirmwareThemesRoot": item.Subtitle = GetFirmwareThemeSummary(); break;
                    case "InstalledThemesRoot": item.Subtitle = GetInstalledThemeSummary(); break;
                    case "ChooseScreenshotFolder": item.Subtitle = GetScreenshotFolder(); break;
                }
                if (item.Children != null) RefreshDynamicSubtitles(item.Children);
            }
        }

        private void BuildMenus()
        {
            categories = new List<XmbCategory>();

            XmbCategory users = new XmbCategory("Users", "Users");
            users.Items.AddRange(BuildUserMenuItems());
            categories.Add(users);

            XmbCategory settingsCategory = new XmbCategory("Settings", "Settings");
            settingsCategory.Items.Add(new XmbItem("System Update", "RPCS3 installation and PS3 system software", null,
                new List<XmbItem> {
                    new XmbItem("Use / Change Existing Installation", GetRpcs3StatusText(), "ChooseRpcs3"),
                    new XmbItem("Install / Update RPCS3", GetManagedInstallText(), "InstallRpcs3"),
                    new XmbItem("RPCS3 Data Location", GetRpcs3DataRootDisplay(), "ChangeDataPath"),
                    new XmbItem("Re-scan RPCS3 Configuration", "Detect native data and refresh the library", "RescanRpcs3"),
                    new XmbItem("Install PS3 System Software", GetFirmwareStatusText(), "InstallFirmware")
                }));
            settingsCategory.Items.Add(new XmbItem("CPU Settings", "Native RPCS3 CPU configuration", null, BuildCpuSettings(false, String.Empty)));
            settingsCategory.Items.Add(new XmbItem("GPU Settings", "Native RPCS3 graphics and display configuration", null, BuildGpuSettings(false, String.Empty)));
            settingsCategory.Items.Add(new XmbItem("Audio Settings", "Native RPCS3 audio configuration", null, BuildAudioSettings(false, String.Empty)));
            settingsCategory.Items.Add(new XmbItem("Controller Settings", "Native RPCS3 input configuration", null, BuildInputSettings(false, String.Empty)));
            settingsCategory.Items.Add(new XmbItem("Network Settings", "Native RPCS3 network configuration", null, BuildNetworkSettings(false, String.Empty)));
            settingsCategory.Items.Add(new XmbItem("System Settings", "Native RPCS3 language and system configuration", null, BuildSystemSettings(false, String.Empty)));
            settingsCategory.Items.Add(new XmbItem("Game Settings", "Libraries, packages, patches and per-game configuration", null,
                new List<XmbItem> {
                    new XmbItem("Game Library Folders", GetLibrarySummary(), "LibraryFoldersRoot", BuildLibraryFolderSettings()),
                    new XmbItem("Re-scan PlayStation 3 Games", "Refresh the native XMB library", "Rescan"),
                    new XmbItem("Install Packages / Updates", "Install a PKG through the selected RPCS3 backend", "InstallPackage"),
                    new XmbItem("Per-Game Settings", "Select a game after the library scan completes", "PerGameSettingsRoot", BuildPerGameSettings()),
                    new XmbItem("Saved Data Utility Settings", "Manage RPCS3 saves without opening the desktop UI", "OpenSaves"),
                    new XmbItem("Clear Shader / PPU / SPU Caches", "Remove rebuildable RPCS3 caches", "ClearCaches")
                }));
            settingsCategory.Items.Add(new XmbItem("Theme Settings", "Choose assets used only by the Huymaier XMB", null,
                new List<XmbItem> {
                    new XmbItem("Asset Source", settings.xmbAssetSource, null, new List<XmbItem> {
                        new XmbItem("Firmware Assets", GetFirmwareAssetCacheStatus(), "AssetFirmware"),
                        new XmbItem("Huymaier Default", "Built-in recovery appearance", "AssetHuymaier"),
                        new XmbItem("Custom Folder", settings.customAssetFolder, "AssetCustom")
                    }),
                    new XmbItem("Refresh Firmware Asset Cache", "Extract compatible presentation resources from the selected RPCS3 dev_flash", "RefreshFirmwareAssets"),
                    new XmbItem("Installed Themes", GetInstalledThemeSummary(), "InstalledThemesRoot", BuildInstalledThemeSettings()),
                    new XmbItem("Firmware Themes", GetFirmwareThemeSummary(), "FirmwareThemesRoot", BuildFirmwareThemeSettings()),
                    new XmbItem("Install .p3t Theme", "Import a PlayStation 3 theme", "ImportTheme"),
                    new XmbItem("Background Color Mode", GetXmbColorModeText(), "CycleXmbColorMode"),
                    new XmbItem("Custom Background Color", settings.xmbCustomColor, "ChooseXmbCustomColor"),
                    new XmbItem("Background", GetBackgroundText(), "ChooseBackground"),
                    new XmbItem("Restore Firmware Appearance", "Select Firmware Assets and clear overrides", "OriginalTheme")
                }));
            settingsCategory.Items.Add(new XmbItem("Music Settings", "Background music and XMB sound effects", null,
                new List<XmbItem> {
                    new XmbItem("Background Music", GetMusicText(), "ChooseMusic"),
                    new XmbItem("Use Included Home Menu Audio", "Intro transitions into a seamless ambient loop", "RestoreIncludedMusic"),
                    new XmbItem("Music Playback", settings.musicEnabled ? "On" : "Off", "ToggleMusic"),
                    new XmbItem("Music Volume", FormatPercent(settings.musicVolume), "MusicVolume"),
                    new XmbItem("Key Tone", settings.soundEnabled ? "On" : "Off", "ToggleSounds"),
                    new XmbItem("Key Tone Volume", FormatPercent(settings.soundVolume), "SoundVolume"),
                    new XmbItem("Cursor Sound", GetSoundText(settings.sounds.move), "ChooseMoveSound"),
                    new XmbItem("Enter Sound", GetSoundText(settings.sounds.confirm), "ChooseConfirmSound"),
                    new XmbItem("Cancel Sound", GetSoundText(settings.sounds.cancel), "ChooseCancelSound")
                }));
            settingsCategory.Items.Add(new XmbItem("Advanced / Troubleshooting", "Desktop UI is not required for normal operation", null,
                new List<XmbItem> {
                    new XmbItem("All RPCS3 Settings", "Every setting discovered from global and per-game RPCS3 configuration", "FullRpcs3Settings"),
                    new XmbItem("Open RPCS3 Desktop UI", "Advanced troubleshooting only", "OpenRpcs3"),
                    new XmbItem("Open RPCS3 Data Folder", GetRpcs3DataRootDisplay(), "OpenGameData")
                }));
            categories.Add(settingsCategory);

            XmbCategory photo = new XmbCategory("Photo", "Photo");
            photo.Items.Add(new XmbItem("RPCS3 Screenshots", "Loading screenshots...", "RefreshPhotos"));
            photo.Items.Add(new XmbItem("Screenshot Folder", GetScreenshotFolder(), "ChooseScreenshotFolder"));
            categories.Add(photo);

            XmbCategory music = new XmbCategory("Music", "Music");
            music.Items.Add(new XmbItem("Music", GetMusicText(), "ChooseMusic"));
            categories.Add(music);

            XmbCategory video = new XmbCategory("Video", "Video");
            video.Items.Add(new XmbItem("Video", "No video folders configured", "Placeholder"));
            categories.Add(video);

            XmbCategory tv = new XmbCategory("TV", "TV/Video Services");
            tv.Items.Add(new XmbItem("My Channels", "No services configured", "Placeholder"));
            categories.Add(tv);

            XmbCategory game = new XmbCategory("Game", "Game");
            game.Items.Add(new XmbItem("Game Data Utility", GetRpcs3DataRootDisplay(), "OpenGameData"));
            game.Items.Add(new XmbItem("Saved Data Utility (PS3)", "Back up, export, restore or remove saved data", "OpenSaves"));
            game.Items.Add(new XmbItem("Trophy Collection", "Loading RPCS3 trophy data...", "OpenTrophies"));
            categories.Add(game);

            XmbCategory network = new XmbCategory("Network", "Network");
            network.Items.Add(new XmbItem("Internet Connection", configAdapter.GetValue(false, String.Empty, "Net", "Network Status", "Connected"), MakeConfigAction(false, String.Empty, "Net", "Network Status", new string[] { "Disconnected", "Connected" })));
            categories.Add(network);

            XmbCategory psn = new XmbCategory("PSN", "PlayStation Network");
            psn.Items.Add(new XmbItem("Network Status", configAdapter.GetValue(false, String.Empty, "Net", "PSN Status", "RPCN"), MakeConfigAction(false, String.Empty, "Net", "PSN Status", new string[] { "Disconnected", "RPCN", "PSN" })));
            categories.Add(psn);

            XmbCategory friends = new XmbCategory("Friends", "Friends");
            friends.Items.Add(new XmbItem("Players Met", "No local entries", "Placeholder"));
            categories.Add(friends);
        }

        private List<XmbItem> BuildCpuSettings(bool perGame, string titleId)
        {
            return new List<XmbItem> {
                ConfigItem("PPU Decoder", perGame, titleId, "Core", "PPU Decoder", new string[] { "LLVM Recompiler", "Interpreter (static)", "Interpreter (dynamic)" }, "LLVM Recompiler"),
                ConfigItem("SPU Decoder", perGame, titleId, "Core", "SPU Decoder", new string[] { "LLVM Recompiler", "ASMJIT Recompiler", "Interpreter (static)", "Interpreter (dynamic)" }, "LLVM Recompiler"),
                ConfigItem("SPU Block Size", perGame, titleId, "Core", "SPU Block Size", new string[] { "Safe", "Mega", "Giga" }, "Safe"),
                ConfigItem("Preferred SPU Threads", perGame, titleId, "Core", "Preferred SPU Threads", new string[] { "Auto", "1", "2", "3", "4", "5", "6" }, "Auto"),
                ConfigItem("SPU Loop Detection", perGame, titleId, "Core", "Enable SPU loop detection", new string[] { "true", "false" }, "true")
            };
        }

        private List<XmbItem> BuildGpuSettings(bool perGame, string titleId)
        {
            return new List<XmbItem> {
                ConfigItem("Renderer", perGame, titleId, "Video", "Renderer", new string[] { "Vulkan", "OpenGL", "Null" }, "Vulkan"),
                ConfigItem("Resolution", perGame, titleId, "Video", "Resolution", new string[] { "1280x720", "1920x1080", "3840x2160" }, "1280x720"),
                ConfigItem("Aspect Ratio", perGame, titleId, "Video", "Aspect ratio", new string[] { "16:9", "4:3", "Auto" }, "16:9"),
                ConfigItem("Frame Limit", perGame, titleId, "Video", "Framelimit", new string[] { "Auto", "Off", "30", "60", "120" }, "Auto"),
                ConfigItem("Resolution Scale", perGame, titleId, "Video", "Resolution Scale", new string[] { "50", "75", "100", "150", "200", "300" }, "100"),
                ConfigItem("VSync", perGame, titleId, "Video", "VSync", new string[] { "false", "true" }, "false"),
                ConfigItem("Anisotropic Filter", perGame, titleId, "Video", "Anisotropic Filter Override", new string[] { "Automatic", "2", "4", "8", "16" }, "Automatic")
            };
        }

        private List<XmbItem> BuildAudioSettings(bool perGame, string titleId)
        {
            return new List<XmbItem> {
                ConfigItem("Audio Renderer", perGame, titleId, "Audio", "Renderer", new string[] { "Cubeb", "XAudio2", "OpenAL", "Null" }, "Cubeb"),
                ConfigItem("Master Volume", perGame, titleId, "Audio", "Master Volume", new string[] { "20", "40", "60", "80", "100" }, "100"),
                ConfigItem("Audio Buffering", perGame, titleId, "Audio", "Enable Buffering", new string[] { "true", "false" }, "true"),
                ConfigItem("Time Stretching", perGame, titleId, "Audio", "Enable Time Stretching", new string[] { "false", "true" }, "false"),
                ConfigItem("Music Handler", perGame, titleId, "Audio", "Music Handler", new string[] { "Qt", "Null" }, "Qt")
            };
        }

        private List<XmbItem> BuildInputSettings(bool perGame, string titleId)
        {
            return new List<XmbItem> {
                ConfigItem("Pad Handler", perGame, titleId, "Input/Output", "Pad Handler", new string[] { "DualSense", "XInput", "SDL", "Keyboard", "Null" }, "DualSense"),
                ConfigItem("Keyboard Handler", perGame, titleId, "Input/Output", "Keyboard", new string[] { "Basic", "Null" }, "Basic"),
                ConfigItem("Mouse Handler", perGame, titleId, "Input/Output", "Mouse", new string[] { "Basic", "Null" }, "Basic")
            };
        }

        private List<XmbItem> BuildNetworkSettings(bool perGame, string titleId)
        {
            return new List<XmbItem> {
                ConfigItem("Network Status", perGame, titleId, "Net", "Network Status", new string[] { "Disconnected", "Connected" }, "Connected"),
                ConfigItem("PSN Status", perGame, titleId, "Net", "PSN Status", new string[] { "Disconnected", "RPCN", "PSN" }, "RPCN")
            };
        }

        private List<XmbItem> BuildSystemSettings(bool perGame, string titleId)
        {
            return new List<XmbItem> {
                ConfigItem("Console Language", perGame, titleId, "System", "Language", new string[] { "English (US)", "English (UK)", "French", "German", "Spanish", "Italian", "Japanese" }, "English (US)"),
                ConfigItem("Enter Button Assignment", perGame, titleId, "System", "Enter button assignment", new string[] { "Cross", "Circle" }, "Cross")
            };
        }

        private XmbItem ConfigItem(string title, bool perGame, string titleId, string section, string key, string[] options, string defaultValue)
        {
            string value = configAdapter.GetValue(perGame, titleId, section, key, defaultValue);
            return new XmbItem(title, value, MakeConfigAction(perGame, titleId, section, key, options));
        }

        private string MakeConfigAction(bool perGame, string titleId, string section, string key, string[] options)
        {
            return "Cfg|" + (perGame ? "G" : "A") + "|" + EncodeActionValue(titleId) + "|" + EncodeActionValue(section) + "|" + EncodeActionValue(key) + "|" + EncodeActionValue(String.Join("\u001f", options));
        }

        private void CycleConfiguration(string action, XmbItem item)
        {
            try
            {
                string[] parts = action.Split('|');
                if (parts.Length != 6) throw new InvalidDataException("Invalid configuration action.");
                bool perGame = parts[1] == "G";
                string titleId = DecodeActionValue(parts[2]);
                string section = DecodeActionValue(parts[3]);
                string key = DecodeActionValue(parts[4]);
                string[] options = DecodeActionValue(parts[5]).Split(new char[] { '\u001f' }, StringSplitOptions.RemoveEmptyEntries);
                if (options.Length == 0) return;
                string current = configAdapter.GetValue(perGame, titleId, section, key, options[0]);
                int index = Array.FindIndex(options, delegate(string value) { return String.Equals(value, current, StringComparison.OrdinalIgnoreCase); });
                string next = options[(index + 1 + options.Length) % options.Length];
                configAdapter.SetValue(perGame, titleId, section, key, next);
                if (item != null) item.Subtitle = next;
                ShowNotice((perGame ? titleId + ": " : String.Empty) + item.Title + " — " + next);
            }
            catch (Exception ex)
            {
                WriteLog("RPCS3 configuration update failed: " + ex, "ERROR");
                ShowNotice("Setting could not be saved: " + ex.Message);
            }
        }

        private void OpenSaveManager()
        {
            menuStack.Push(new XmbMenuContext("Saved Data Utility (PS3)", BuildSaveMenu(), selectedIndex));
            selectedIndex = 0;
            visualItem = 0;
            SelectionChanged();
        }

        private void RefreshSaveManager()
        {
            int parent = selectedIndex;
            if (menuStack.Count > 0) parent = menuStack.Pop().ParentSelection;
            menuStack.Push(new XmbMenuContext("Saved Data Utility (PS3)", BuildSaveMenu(), parent));
            selectedIndex = 0;
            visualItem = 0;
            SelectionChanged();
            ShowNotice("Saved data refreshed");
        }

        private void OpenSaveBackups()
        {
            menuStack.Push(new XmbMenuContext("Save Backups", BuildBackupMenu(), selectedIndex));
            selectedIndex = 0;
            visualItem = 0;
            SelectionChanged();
        }

        private List<XmbItem> BuildSaveMenu()
        {
            List<XmbItem> items = new List<XmbItem>();
            items.Add(new XmbItem("Refresh Saved Data", "Re-read saves for " + GetActiveRpcs3UserDisplayName(), "RefreshSaves"));
            items.Add(new XmbItem("Save Backups", GetSaveBackupRoot(), "OpenSaveBackups"));
            foreach (Ps3SaveEntry save in ScanSaves())
            {
                string value = EncodeActionValue(save.Path);
                items.Add(new XmbItem(save.Title, save.Subtitle, null, new List<XmbItem> {
                    new XmbItem("Back Up", "Create a timestamped Huymaier backup", "SaveBackup|" + value),
                    new XmbItem("Export Copy", "Copy this save to another folder", "SaveExport|" + value),
                    new XmbItem("Open Save Folder", save.Path, "SaveOpen|" + value),
                    new XmbItem("Move to Save Trash", "Recoverable removal; no immediate permanent deletion", "SaveTrash|" + value)
                }));
            }
            if (items.Count == 2) items.Add(new XmbItem("No saved data found", GetRpcs3DataRootDisplay(), "Placeholder"));
            return items;
        }

        private List<XmbItem> BuildBackupMenu()
        {
            List<XmbItem> items = new List<XmbItem>();
            string root = GetSaveBackupRoot();
            Directory.CreateDirectory(root);
            string[] folders;
            try { folders = Directory.GetDirectories(root); } catch { folders = new string[0]; }
            Array.Sort(folders, StringComparer.OrdinalIgnoreCase);
            Array.Reverse(folders);
            foreach (string folder in folders.Take(200))
            {
                string value = EncodeActionValue(folder);
                items.Add(new XmbItem(Path.GetFileName(folder), DescribeFolder(folder), null, new List<XmbItem> {
                    new XmbItem("Restore Backup", ReadOriginalSavePath(folder), "SaveRestore|" + value),
                    new XmbItem("Open Backup Folder", folder, "SaveOpen|" + value)
                }));
            }
            if (items.Count == 0) items.Add(new XmbItem("No backups yet", root, "Placeholder"));
            return items;
        }

        private List<Ps3SaveEntry> ScanSaves()
        {
            List<Ps3SaveEntry> result = new List<Ps3SaveEntry>();
            string activeUserId = GetActiveRpcs3UserId();
            Ps3UserProfile activeProfile = GetRpcs3Users().FirstOrDefault(delegate(Ps3UserProfile value) { return String.Equals(value.Id, activeUserId, StringComparison.Ordinal); });
            string user = activeProfile == null ? String.Empty : activeProfile.Path;
            if (String.IsNullOrWhiteSpace(user) || !Directory.Exists(user)) return result;
            string savedata = Path.Combine(user, "savedata");
            if (!Directory.Exists(savedata)) return result;
            string[] folders;
            try { folders = Directory.GetDirectories(savedata); } catch { return result; }
            Ps3UserProfile profile = GetRpcs3Users().FirstOrDefault(delegate(Ps3UserProfile value) { return String.Equals(value.Id, activeUserId, StringComparison.Ordinal); });
            string profileLabel = profile == null ? "User " + activeUserId : profile.Name + " (" + activeUserId + ")";
            foreach (string folder in folders.Take(500))
            {
                try
                {
                    if ((File.GetAttributes(folder) & FileAttributes.ReparsePoint) != 0) continue;
                    Dictionary<string, object> values = File.Exists(Path.Combine(folder, "PARAM.SFO"))
                        ? ParamSfo.Read(Path.Combine(folder, "PARAM.SFO"))
                        : new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);
                    string title = ReadSfoValue(values, "TITLE");
                    if (String.IsNullOrWhiteSpace(title)) title = ReadSfoValue(values, "SAVEDATA_TITLE");
                    if (String.IsNullOrWhiteSpace(title)) title = Path.GetFileName(folder);
                    string detail = ReadSfoValue(values, "SUB_TITLE");
                    if (String.IsNullOrWhiteSpace(detail)) detail = ReadSfoValue(values, "DETAIL");
                    string subtitle = profileLabel + " • " + DescribeFolder(folder);
                    if (!String.IsNullOrWhiteSpace(detail)) subtitle = detail.Replace("\r", " ").Replace("\n", " ") + " • " + subtitle;
                    result.Add(new Ps3SaveEntry { Path = folder, Title = title, Subtitle = subtitle });
                }
                catch (Exception ex) { WriteLog("Saved-data entry skipped: " + ex.Message, "WARN"); }
            }
            result.Sort(delegate(Ps3SaveEntry left, Ps3SaveEntry right) { return StringComparer.OrdinalIgnoreCase.Compare(left.Title, right.Title); });
            return result;
        }

        private static string ReadSfoValue(Dictionary<string, object> values, string key)
        {
            object value;
            return values != null && values.TryGetValue(key, out value) && value != null
                ? Convert.ToString(value, CultureInfo.InvariantCulture) : String.Empty;
        }

        private string GetSaveBackupRoot() { return Path.Combine(appDataRoot, "SaveBackups"); }
        private string GetSaveTrashRoot() { return Path.Combine(appDataRoot, "SaveTrash"); }

        private void BackupSave(string source)
        {
            try
            {
                if (!Directory.Exists(source)) throw new DirectoryNotFoundException("The save is no longer available.");
                string target = Path.Combine(GetSaveBackupRoot(), DateTime.Now.ToString("yyyyMMdd-HHmmss-fff") + "-" + SafeName(Path.GetFileName(source)));
                CopyTree(source, target, String.Empty);
                Dictionary<string, object> info = new Dictionary<string, object>();
                info["originalPath"] = source;
                info["createdUtc"] = DateTime.UtcNow.ToString("o", CultureInfo.InvariantCulture);
                File.WriteAllText(Path.Combine(target, "backup-info.json"), new JavaScriptSerializer().Serialize(info), new UTF8Encoding(false));
                ShowNotice("Save backed up");
            }
            catch (Exception ex) { WriteLog("Save backup failed: " + ex, "ERROR"); ShowNotice("Save backup failed: " + ex.Message); }
        }

        private void ExportSave(string source)
        {
            try
            {
                using (Forms.FolderBrowserDialog dialog = new Forms.FolderBrowserDialog())
                {
                    dialog.Description = "Choose a destination for the exported PS3 save.";
                    if (dialog.ShowDialog() != Forms.DialogResult.OK) return;
                    string target = Path.Combine(dialog.SelectedPath, Path.GetFileName(source));
                    if (Directory.Exists(target)) target += "-" + DateTime.Now.ToString("yyyyMMdd-HHmmss");
                    CopyTree(source, target, String.Empty);
                    ShowNotice("Save exported");
                }
            }
            catch (Exception ex) { WriteLog("Save export failed: " + ex, "ERROR"); ShowNotice("Save export failed: " + ex.Message); }
        }

        private void TrashSave(string source)
        {
            try
            {
                if (!Directory.Exists(source)) return;
                if (MessageBox.Show("Move this save to Huymaier Save Trash?\n\n" + source, "Saved Data Utility", MessageBoxButton.YesNo, MessageBoxImage.Warning) != MessageBoxResult.Yes) return;
                Directory.CreateDirectory(GetSaveTrashRoot());
                MoveTree(source, Path.Combine(GetSaveTrashRoot(), DateTime.Now.ToString("yyyyMMdd-HHmmss-fff") + "-" + SafeName(Path.GetFileName(source))));
                RefreshSaveManager();
                ShowNotice("Save moved to Save Trash");
            }
            catch (Exception ex) { WriteLog("Save removal failed: " + ex, "ERROR"); ShowNotice("Save removal failed: " + ex.Message); }
        }

        private void RestoreSave(string backup)
        {
            try
            {
                string target = ReadOriginalSavePath(backup);
                if (String.IsNullOrWhiteSpace(target)) throw new InvalidDataException("This backup does not contain its original RPCS3 save path.");
                if (MessageBox.Show("Restore this backup to:\n\n" + target + "\n\nAn existing save will first be moved to Save Trash.", "Restore Saved Data", MessageBoxButton.YesNo, MessageBoxImage.Question) != MessageBoxResult.Yes) return;
                if (Directory.Exists(target))
                {
                    Directory.CreateDirectory(GetSaveTrashRoot());
                    MoveTree(target, Path.Combine(GetSaveTrashRoot(), DateTime.Now.ToString("yyyyMMdd-HHmmss-fff") + "-pre-restore-" + SafeName(Path.GetFileName(target))));
                }
                CopyTree(backup, target, "backup-info.json");
                ShowNotice("Save restored");
            }
            catch (Exception ex) { WriteLog("Save restore failed: " + ex, "ERROR"); ShowNotice("Save restore failed: " + ex.Message); }
        }

        private void OpenFolderPath(string path)
        {
            try { Process.Start(new ProcessStartInfo { FileName = "explorer.exe", Arguments = "\"" + path + "\"", UseShellExecute = true }); }
            catch (Exception ex) { ShowNotice("Folder could not be opened: " + ex.Message); }
        }

        private static void CopyTree(string source, string target, string skipFile)
        {
            Directory.CreateDirectory(target);
            Queue<string> pending = new Queue<string>();
            pending.Enqueue(source);
            int fileCount = 0;
            long byteCount = 0;
            while (pending.Count > 0)
            {
                string current = pending.Dequeue();
                string relative = current.Length == source.Length ? String.Empty : current.Substring(source.Length).TrimStart(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
                string destination = String.IsNullOrEmpty(relative) ? target : Path.Combine(target, relative);
                Directory.CreateDirectory(destination);
                foreach (string file in Directory.GetFiles(current))
                {
                    if (!String.IsNullOrWhiteSpace(skipFile) && String.Equals(Path.GetFileName(file), skipFile, StringComparison.OrdinalIgnoreCase)) continue;
                    FileInfo info = new FileInfo(file);
                    if (++fileCount > 200000 || (byteCount += Math.Max(0L, info.Length)) > 32L * 1024L * 1024L * 1024L) throw new IOException("The save operation exceeded its safety limit.");
                    File.Copy(file, Path.Combine(destination, Path.GetFileName(file)), true);
                }
                foreach (string folder in Directory.GetDirectories(current))
                {
                    if ((File.GetAttributes(folder) & FileAttributes.ReparsePoint) == 0) pending.Enqueue(folder);
                }
            }
        }

        private static void MoveTree(string source, string target)
        {
            Directory.CreateDirectory(Path.GetDirectoryName(target));
            try { Directory.Move(source, target); }
            catch (IOException) { CopyTree(source, target, String.Empty); Directory.Delete(source, true); }
        }

        private static string ReadOriginalSavePath(string backup)
        {
            try
            {
                string file = Path.Combine(backup, "backup-info.json");
                if (!File.Exists(file)) return String.Empty;
                Dictionary<string, object> data = new JavaScriptSerializer().Deserialize<Dictionary<string, object>>(File.ReadAllText(file));
                object value;
                return data != null && data.TryGetValue("originalPath", out value) && value != null ? Convert.ToString(value, CultureInfo.InvariantCulture) : String.Empty;
            }
            catch { return String.Empty; }
        }

        private static string SafeName(string value)
        {
            if (String.IsNullOrWhiteSpace(value)) return "save";
            foreach (char invalid in Path.GetInvalidFileNameChars()) value = value.Replace(invalid, '_');
            return value;
        }

        private static string DescribeFolder(string path)
        {
            try
            {
                long bytes = 0;
                int files = 0;
                foreach (string file in Directory.EnumerateFiles(path, "*", SearchOption.AllDirectories).Take(200000))
                {
                    files++;
                    try { bytes += new FileInfo(file).Length; } catch { }
                }
                string size = bytes >= 1073741824L ? (bytes / 1073741824d).ToString("0.00", CultureInfo.InvariantCulture) + " GB" :
                    bytes >= 1048576L ? (bytes / 1048576d).ToString("0.0", CultureInfo.InvariantCulture) + " MB" :
                    (bytes / 1024d).ToString("0", CultureInfo.InvariantCulture) + " KB";
                return size + " • " + files.ToString(CultureInfo.InvariantCulture) + " files • " + Directory.GetLastWriteTime(path).ToString("g", CultureInfo.CurrentCulture);
            }
            catch { return path; }
        }

        private List<XmbItem> BuildUserMenuItems()
        {
            List<XmbItem> result = new List<XmbItem>();
            List<Ps3UserProfile> profiles = GetRpcs3Users();
            string active = GetActiveRpcs3UserId();
            foreach (Ps3UserProfile profile in profiles)
            {
                bool selected = String.Equals(profile.Id, active, StringComparison.Ordinal);
                result.Add(new XmbItem(profile.Name,
                    selected ? "Active User • RPCS3 " + profile.Id : "RPCS3 User " + profile.Id,
                    "SelectRpcs3User|" + profile.Id));
            }
            if (profiles.Count == 0)
                result.Add(new XmbItem("No RPCS3 users found", "Create a user in RPCS3 or install firmware, then refresh.", "RefreshRpcs3Users"));
            result.Add(new XmbItem("Saved Data Utility", "Manage saves for " + GetActiveRpcs3UserDisplayName(), "OpenSaves"));
            result.Add(new XmbItem("Refresh Users", "Re-scan dev_hdd0/home for RPCS3 profiles", "RefreshRpcs3Users"));
            result.Add(new XmbItem("Turn Off System", "Return to Huymaier Console", "Exit"));
            return result;
        }

        private List<Ps3UserProfile> GetRpcs3Users()
        {
            List<Ps3UserProfile> result = new List<Ps3UserProfile>();
            HashSet<string> seen = new HashSet<string>(StringComparer.Ordinal);
            foreach (string home in GetRpcs3UserHomeRoots())
            {
                if (!Directory.Exists(home)) continue;
                string[] directories;
                try { directories = Directory.GetDirectories(home); } catch { continue; }
                foreach (string directory in directories)
                {
                    string id = Path.GetFileName(directory) ?? String.Empty;
                    ulong numeric;
                    if (id.Length != 8 || !id.All(Char.IsDigit) || !UInt64.TryParse(id, NumberStyles.None, CultureInfo.InvariantCulture, out numeric) || numeric == 0 || !seen.Add(id)) continue;
                    string usernameFile = Path.Combine(directory, "localusername");
                    string name = String.Empty;
                    try
                    {
                        if (File.Exists(usernameFile)) name = File.ReadAllText(usernameFile, Encoding.UTF8).Trim().Trim('\0');
                    }
                    catch { }
                    if (String.IsNullOrWhiteSpace(name)) name = "User " + id;
                    result.Add(new Ps3UserProfile { Id = id, Name = name, Path = directory });
                }
            }
            result.Sort(delegate(Ps3UserProfile left, Ps3UserProfile right)
            {
                ulong a, b;
                if (UInt64.TryParse(left.Id, NumberStyles.None, CultureInfo.InvariantCulture, out a) && UInt64.TryParse(right.Id, NumberStyles.None, CultureInfo.InvariantCulture, out b)) return a.CompareTo(b);
                return StringComparer.CurrentCultureIgnoreCase.Compare(left.Name, right.Name);
            });
            return result;
        }

        private List<string> GetRpcs3UserHomeRoots()
        {
            List<string> homes = new List<string>();
            Action<string> addRoot = delegate(string root)
            {
                if (String.IsNullOrWhiteSpace(root)) return;
                try
                {
                    string full = Path.GetFullPath(root);
                    string leaf = Path.GetFileName(full);
                    string home = String.Equals(leaf, "home", StringComparison.OrdinalIgnoreCase)
                        ? full
                        : (String.Equals(leaf, "dev_hdd0", StringComparison.OrdinalIgnoreCase) ? Path.Combine(full, "home") : Path.Combine(full, "dev_hdd0", "home"));
                    if (Directory.Exists(home) && !homes.Contains(home, StringComparer.OrdinalIgnoreCase)) homes.Add(home);
                }
                catch { }
            };

            // Portable RPCS3 installs keep dev_hdd0 beside rpcs3.exe.  Scan that
            // location explicitly even when a stale/alternate data-root setting exists.
            string executable = GetRpcs3Executable();
            if (!String.IsNullOrWhiteSpace(executable) && File.Exists(executable)) addRoot(Path.GetDirectoryName(executable));
            addRoot(settings.rpcs3DataPath);
            addRoot(GetRpcs3DataRoot());
            addRoot(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "rpcs3"));
            addRoot(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "rpcs3"));
            return homes;
        }

        private string GetActiveRpcs3UserId()
        {
            List<Ps3UserProfile> profiles = GetRpcs3Users();
            if (profiles.Any(delegate(Ps3UserProfile value) { return String.Equals(value.Id, settings.activeUserId, StringComparison.Ordinal); })) return settings.activeUserId;
            if (profiles.Count > 0) return profiles[0].Id;
            return "00000001";
        }

        private string GetActiveRpcs3UserDisplayName()
        {
            string id = GetActiveRpcs3UserId();
            Ps3UserProfile profile = GetRpcs3Users().FirstOrDefault(delegate(Ps3UserProfile value) { return String.Equals(value.Id, id, StringComparison.Ordinal); });
            return profile == null ? "RPCS3 User " + id : profile.Name + " (" + id + ")";
        }

        private string GetRpcs3DataRootForActiveUser()
        {
            string id = GetActiveRpcs3UserId();
            Ps3UserProfile profile = GetRpcs3Users().FirstOrDefault(delegate(Ps3UserProfile value) { return String.Equals(value.Id, id, StringComparison.Ordinal); });
            if (profile != null && !String.IsNullOrWhiteSpace(profile.Path))
            {
                try
                {
                    DirectoryInfo user = new DirectoryInfo(profile.Path);
                    DirectoryInfo home = user.Parent;
                    DirectoryInfo hdd = home == null ? null : home.Parent;
                    DirectoryInfo root = hdd == null ? null : hdd.Parent;
                    if (root != null && Directory.Exists(Path.Combine(root.FullName, "dev_hdd0"))) return root.FullName;
                }
                catch { }
            }
            return GetRpcs3DataRoot();
        }

        private void SelectRpcs3User(string userId)
        {
            Ps3UserProfile profile = GetRpcs3Users().FirstOrDefault(delegate(Ps3UserProfile value) { return String.Equals(value.Id, userId, StringComparison.Ordinal); });
            if (profile == null)
            {
                ShowNotice("That RPCS3 user is no longer available");
                UpdateUsersMenu();
                return;
            }
            settings.activeUserId = profile.Id;
            settings.Save(settingsPath);
            UpdateUsersMenu();
            BeginAuxiliaryDataScan();
            ShowNotice("Active user: " + profile.Name);
        }

        private void UpdateUsersMenu()
        {
            XmbCategory users = categories.FirstOrDefault(delegate(XmbCategory value) { return String.Equals(value.Id, "Users", StringComparison.OrdinalIgnoreCase); });
            if (users == null) return;
            users.Items.Clear();
            users.Items.AddRange(BuildUserMenuItems());
            surface.InvalidateVisual();
        }

        private List<string> GetInstalledThemeDirectories()
        {
            List<string> result = new List<string>();
            if (!Directory.Exists(themeRoot)) return result;
            string[] directories;
            try { directories = Directory.GetDirectories(themeRoot); } catch { return result; }
            foreach (string directory in directories)
            {
                string name = Path.GetFileName(directory) ?? String.Empty;
                if (String.Equals(name, "FirmwareThemes", StringComparison.OrdinalIgnoreCase) ||
                    String.Equals(name, "FirmwareAssets", StringComparison.OrdinalIgnoreCase) ||
                    String.Equals(name, "CustomAssets", StringComparison.OrdinalIgnoreCase)) continue;
                if (File.Exists(Path.Combine(directory, "theme-manifest.json"))) result.Add(Path.GetFullPath(directory));
            }
            result.Sort(delegate(string left, string right) { return StringComparer.CurrentCultureIgnoreCase.Compare(GetInstalledThemeDisplayName(left), GetInstalledThemeDisplayName(right)); });
            return result;
        }

        private string GetInstalledThemeDisplayName(string directory)
        {
            try
            {
                string manifest = Path.Combine(directory, "theme-manifest.json");
                if (File.Exists(manifest))
                {
                    Dictionary<string, object> data = new JavaScriptSerializer().Deserialize<Dictionary<string, object>>(File.ReadAllText(manifest, Encoding.UTF8));
                    object value;
                    if (data != null && data.TryGetValue("Name", out value) && value != null && !String.IsNullOrWhiteSpace(Convert.ToString(value, CultureInfo.CurrentCulture)))
                        return Convert.ToString(value, CultureInfo.CurrentCulture).Trim();
                }
            }
            catch { }
            string name = Path.GetFileName(directory) ?? "Installed Theme";
            int separator = name.LastIndexOf('-');
            if (separator > 0 && name.Length - separator == 15) name = name.Substring(0, separator);
            return name.Replace('_', ' ').Trim();
        }

        private List<XmbItem> BuildInstalledThemeSettings()
        {
            List<XmbItem> result = new List<XmbItem>();
            List<string> themes = GetInstalledThemeDirectories();
            foreach (string directory in themes)
            {
                string display = GetInstalledThemeDisplayName(directory);
                bool selected = String.Equals(settings.xmbAssetSource, "Installed .p3t Theme", StringComparison.OrdinalIgnoreCase) &&
                    String.Equals(NormalizePath(settings.themeDirectory), NormalizePath(directory), StringComparison.OrdinalIgnoreCase);
                result.Add(new XmbItem(display, selected ? "Selected" : "Installed .p3t theme", "ApplyInstalledTheme|" + EncodeActionValue(directory)));
            }
            if (themes.Count == 0) result.Add(new XmbItem("No installed themes", "Use Install .p3t Theme to add one.", "ImportTheme"));
            result.Add(new XmbItem("Refresh Installed Theme List", "Re-scan installed Huymaier XMB themes", "RefreshInstalledThemes"));
            return result;
        }

        private string GetInstalledThemeSummary()
        {
            List<string> themes = GetInstalledThemeDirectories();
            if (String.Equals(settings.xmbAssetSource, "Installed .p3t Theme", StringComparison.OrdinalIgnoreCase) && !String.IsNullOrWhiteSpace(settings.theme))
                return "Selected: " + settings.theme + " • " + themes.Count.ToString(CultureInfo.InvariantCulture) + " installed";
            return themes.Count == 1 ? "1 installed theme" : themes.Count.ToString(CultureInfo.InvariantCulture) + " installed themes";
        }

        private void UpdateInstalledThemesMenu()
        {
            XmbItem root = FindItemByAction("InstalledThemesRoot");
            if (root == null) return;
            root.Children = BuildInstalledThemeSettings();
            root.Subtitle = GetInstalledThemeSummary();
            RefreshDynamicSubtitles();
            surface.InvalidateVisual();
        }

        private void ApplyInstalledTheme(string directory)
        {
            string normalized = NormalizePath(directory);
            string allowedRoot = NormalizePath(themeRoot);
            if (String.IsNullOrWhiteSpace(normalized) || String.IsNullOrWhiteSpace(allowedRoot) ||
                !normalized.StartsWith(allowedRoot + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase) ||
                !Directory.Exists(normalized) || !File.Exists(Path.Combine(normalized, "theme-manifest.json")))
            {
                ShowNotice("The selected installed theme is no longer available");
                UpdateInstalledThemesMenu();
                return;
            }
            string display = GetInstalledThemeDisplayName(normalized);
            settings.theme = display;
            settings.themeDirectory = normalized;
            settings.xmbAssetSource = "Installed .p3t Theme";
            settings.firmwareThemeFile = String.Empty;
            settings.firmwareThemeName = String.Empty;
            settings.backgroundImage = String.Empty;
            RestoreAppearanceColorPreference();
            settings.Save(settingsPath);
            theme.Refresh();
            audio.Refresh();
            UpdateInstalledThemesMenu();
            UpdateFirmwareThemesMenu();
            ShowNotice("Theme applied: " + display);
        }

        private List<XmbItem> BuildFirmwareThemeSettings()
        {
            List<XmbItem> result = new List<XmbItem>();
            bool originalSelected = String.Equals(settings.xmbAssetSource, "Firmware Assets", StringComparison.OrdinalIgnoreCase);
            result.Add(new XmbItem("Original PS3 (Firmware Default)",
                originalSelected ? "Selected — stock time/month color field and firmware presentation assets" : "Use the stock firmware presentation",
                "OriginalTheme"));

            List<string> themes = GetFirmwareThemeFiles();
            foreach (string path in themes)
            {
                string display = GetFirmwareThemeDisplayName(path);
                bool selected = String.Equals(settings.xmbAssetSource, "Firmware Theme", StringComparison.OrdinalIgnoreCase) &&
                    String.Equals(NormalizePath(settings.firmwareThemeFile), NormalizePath(path), StringComparison.OrdinalIgnoreCase);
                result.Add(new XmbItem(display,
                    selected ? "Selected — " + Path.GetFileName(path) : Path.GetFileName(path),
                    "ApplyFirmwareTheme|" + EncodeActionValue(path)));
            }
            if (themes.Count == 0)
                result.Add(new XmbItem("No firmware themes found",
                    "Install PS3 system software in the selected RPCS3 data location, then refresh this list.",
                    "RefreshFirmwareThemes"));
            result.Add(new XmbItem("Refresh Firmware Theme List", "Re-scan dev_flash for bundled .p3t themes", "RefreshFirmwareThemes"));
            return result;
        }

        private void UpdateFirmwareThemesMenu()
        {
            XmbItem root = FindItemByAction("FirmwareThemesRoot");
            if (root == null) return;
            List<XmbItem> updated = BuildFirmwareThemeSettings();
            if (root.Children == null) root.Children = updated;
            else
            {
                root.Children.Clear();
                root.Children.AddRange(updated);
            }
            root.Subtitle = GetFirmwareThemeSummary();
            RefreshDynamicSubtitles();
            surface.InvalidateVisual();
        }

        private List<string> GetFirmwareThemeFiles()
        {
            List<string> result = new List<string>();
            string dataRoot = GetRpcs3DataRoot();
            if (String.IsNullOrWhiteSpace(dataRoot)) return result;
            string themeRootPath = Path.Combine(dataRoot, "dev_flash", "vsh", "resource", "theme");
            if (!Directory.Exists(themeRootPath)) return result;
            try
            {
                foreach (string file in Directory.GetFiles(themeRootPath, "*.p3t", SearchOption.TopDirectoryOnly))
                {
                    if (!File.Exists(file)) continue;
                    string baseName = Path.GetFileNameWithoutExtension(file);
                    if (String.Equals(baseName, "original", StringComparison.OrdinalIgnoreCase) ||
                        String.Equals(baseName, "default", StringComparison.OrdinalIgnoreCase)) continue;
                    result.Add(Path.GetFullPath(file));
                }
            }
            catch (Exception ex) { WriteLog("Firmware theme scan failed: " + ex.Message, "WARN"); }
            result.Sort(delegate(string left, string right)
            {
                return StringComparer.CurrentCultureIgnoreCase.Compare(GetFirmwareThemeDisplayName(left), GetFirmwareThemeDisplayName(right));
            });
            return result;
        }

        private string GetFirmwareThemeSummary()
        {
            List<string> themes = GetFirmwareThemeFiles();
            if (String.Equals(settings.xmbAssetSource, "Firmware Theme", StringComparison.OrdinalIgnoreCase) &&
                !String.IsNullOrWhiteSpace(settings.firmwareThemeName))
                return "Selected: " + settings.firmwareThemeName + " • " + themes.Count.ToString(CultureInfo.InvariantCulture) + " available";
            return themes.Count == 1 ? "1 bundled firmware theme" : themes.Count.ToString(CultureInfo.InvariantCulture) + " bundled firmware themes";
        }

        private static string GetFirmwareThemeDisplayName(string path)
        {
            string name = Path.GetFileNameWithoutExtension(path) ?? String.Empty;
            int number;
            if (Int32.TryParse(name, NumberStyles.Integer, CultureInfo.InvariantCulture, out number))
                return "Firmware Theme " + number.ToString("00", CultureInfo.InvariantCulture);
            if (String.Equals(name, "original", StringComparison.OrdinalIgnoreCase) ||
                String.Equals(name, "default", StringComparison.OrdinalIgnoreCase))
                return "Original PS3 (Firmware Default)";
            name = name.Replace('_', ' ').Replace('-', ' ').Trim();
            return String.IsNullOrWhiteSpace(name) ? "Firmware Theme" : CultureInfo.CurrentCulture.TextInfo.ToTitleCase(name);
        }

        private void ApplyFirmwareTheme(string sourcePath)
        {
            string normalized = NormalizePath(sourcePath);
            if (String.IsNullOrWhiteSpace(normalized) || !File.Exists(normalized) ||
                !String.Equals(Path.GetExtension(normalized), ".p3t", StringComparison.OrdinalIgnoreCase))
            {
                ShowNotice("The selected firmware theme is no longer available");
                UpdateFirmwareThemesMenu();
                return;
            }

            string selectedDataRoot = GetRpcs3DataRoot();
            if (String.IsNullOrWhiteSpace(selectedDataRoot))
            {
                ShowNotice("The selected RPCS3 data location is unavailable");
                return;
            }
            string allowedRoot = NormalizePath(Path.Combine(selectedDataRoot, "dev_flash", "vsh", "resource", "theme"));
            if (String.IsNullOrWhiteSpace(allowedRoot) ||
                !(String.Equals(normalized, allowedRoot, StringComparison.OrdinalIgnoreCase) ||
                  normalized.StartsWith(allowedRoot + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase)))
            {
                ShowNotice("Only themes from the selected RPCS3 firmware can be applied here");
                return;
            }

            string displayName = GetFirmwareThemeDisplayName(normalized);
            string cacheDirectory = Path.Combine(themeRoot, "FirmwareThemes",
                MakeSafeFileName(Path.GetFileNameWithoutExtension(normalized)) + "-" + StablePathHash(normalized));
            inputSuspended = true;
            ShowNotice("Applying " + displayName + "...");
            ThreadPool.QueueUserWorkItem(delegate
            {
                string error = String.Empty;
                try
                {
                    FileInfo info = new FileInfo(normalized);
                    string stamp = info.Length.ToString(CultureInfo.InvariantCulture) + "|" +
                        info.LastWriteTimeUtc.Ticks.ToString(CultureInfo.InvariantCulture);
                    string stampPath = Path.Combine(cacheDirectory, "source-stamp.txt");
                    string currentStamp = File.Exists(stampPath) ? File.ReadAllText(stampPath).Trim() : String.Empty;
                    if (!File.Exists(Path.Combine(cacheDirectory, "theme-manifest.json")) ||
                        !String.Equals(stamp, currentStamp, StringComparison.Ordinal))
                    {
                        if (Directory.Exists(cacheDirectory)) Directory.Delete(cacheDirectory, true);
                        Directory.CreateDirectory(cacheDirectory);
                        P3TImporter.Import(normalized, cacheDirectory);
                        File.WriteAllText(stampPath, stamp, Encoding.UTF8);
                    }
                }
                catch (Exception ex)
                {
                    error = ex.Message;
                    WriteLog("Firmware theme import failed: " + ex, "ERROR");
                }
                SafeBeginUi(delegate
                {
                    inputSuspended = false;
                    inputGuardUntilUtc = DateTime.UtcNow.AddMilliseconds(350);
                    if (!String.IsNullOrWhiteSpace(error))
                    {
                        ShowNotice("Firmware theme could not be applied: " + error);
                        return;
                    }
                    settings.firmwareThemeFile = normalized;
                    settings.firmwareThemeName = displayName;
                    settings.theme = displayName;
                    settings.themeDirectory = cacheDirectory;
                    settings.xmbAssetSource = "Firmware Theme";
                    settings.backgroundImage = String.Empty;
                    RestoreAppearanceColorPreference();
                    settings.Save(settingsPath);
                    theme.Refresh();
                    audio.Refresh();
                    UpdateFirmwareThemesMenu();
                    ShowNotice("Theme applied: " + displayName);
                }, "Firmware theme apply");
            });
        }

        private static string NormalizePath(string path)
        {
            if (String.IsNullOrWhiteSpace(path)) return String.Empty;
            try { return Path.GetFullPath(Environment.ExpandEnvironmentVariables(path.Trim())).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar); }
            catch { return path.Trim().TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar); }
        }

        private static string StablePathHash(string path)
        {
            unchecked
            {
                uint hash = 2166136261;
                string value = (path ?? String.Empty).ToUpperInvariant();
                foreach (char c in value) { hash ^= c; hash *= 16777619; }
                return hash.ToString("X8", CultureInfo.InvariantCulture);
            }
        }

        private List<XmbItem> BuildLibraryFolderSettings()
        {
            List<XmbItem> result = new List<XmbItem>();
            result.Add(new XmbItem("Add Game Library Folder", "Add another extracted PlayStation 3 game location", "AddLibrary"));
            foreach (string root in settings.libraryRoots)
            {
                string normalized = NormalizeLibraryRoot(root);
                if (String.IsNullOrWhiteSpace(normalized)) continue;
                string label = Path.GetFileName(normalized.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar));
                if (String.IsNullOrWhiteSpace(label)) label = normalized;
                result.Add(new XmbItem(label, normalized, null, new List<XmbItem> {
                    new XmbItem("Remove from XMB", "Stops scanning this folder. No game files will be deleted.",
                        "RemoveLibrary|" + EncodeActionValue(normalized))
                }));
            }
            if (settings.libraryRoots.Count == 0)
                result.Add(new XmbItem("No additional folders", "RPCS3's registered library is still scanned automatically", "Placeholder"));
            return result;
        }

        private void UpdateLibraryFolderSettingsMenu()
        {
            XmbItem root = FindItemByAction("LibraryFoldersRoot");
            if (root == null) return;
            List<XmbItem> updated = BuildLibraryFolderSettings();
            if (root.Children == null) root.Children = updated;
            else
            {
                root.Children.Clear();
                root.Children.AddRange(updated);
            }
            root.Subtitle = GetLibrarySummary();
        }

        private List<XmbItem> BuildPerGameSettings()
        {
            List<XmbItem> result = new List<XmbItem>();
            foreach (Ps3Game game in currentGames.Take(80))
            {
                List<XmbItem> children = new List<XmbItem>();
                children.Add(new XmbItem("CPU", "Per-game CPU overrides", null, BuildCpuSettings(true, game.TitleId)));
                children.Add(new XmbItem("GPU", "Per-game graphics overrides", null, BuildGpuSettings(true, game.TitleId)));
                children.Add(new XmbItem("Audio", "Per-game audio overrides", null, BuildAudioSettings(true, game.TitleId)));
                children.Add(new XmbItem("Controller", "Per-game input overrides", null, BuildInputSettings(true, game.TitleId)));
                result.Add(new XmbItem(game.Title, game.TitleId, null, children));
            }
            if (result.Count == 0) result.Add(new XmbItem("No games available", "Run a PlayStation 3 library scan first", "Rescan"));
            return result;
        }

        private void UpdatePerGameSettingsMenu()
        {
            XmbItem root = FindItemByAction("PerGameSettingsRoot");
            if (root != null)
            {
                root.Children = BuildPerGameSettings();
                root.Subtitle = currentGames.Count == 1 ? "1 game" : currentGames.Count.ToString(CultureInfo.InvariantCulture) + " games";
            }
        }

        private XmbItem FindItemByAction(string action)
        {
            foreach (XmbCategory category in categories)
            {
                XmbItem found = FindItemByAction(category.Items, action);
                if (found != null) return found;
            }
            return null;
        }

        private XmbItem FindItemByAction(List<XmbItem> items, string action)
        {
            if (items == null) return null;
            foreach (XmbItem item in items)
            {
                if (String.Equals(item.Action, action, StringComparison.Ordinal)) return item;
                XmbItem found = FindItemByAction(item.Children, action);
                if (found != null) return found;
            }
            return null;
        }

        private void BeginAuxiliaryDataScan()
        {
            if (closing) return;
            int generation = ++auxiliaryGeneration;
            Ps3Settings snapshot = settings;
            ThreadPool.QueueUserWorkItem(delegate
            {
                List<TrophySet> trophies = new List<TrophySet>();
                List<string> photos = new List<string>();
                try
                {
                    string root = GetRpcs3DataRootForActiveUser();
                    trophies = TrophyScanner.Scan(root, GetActiveRpcs3UserId(), WriteLog);
                    photos = PhotoScanner.Scan(GetScreenshotFolder());
                }
                catch (Exception ex) { WriteLog("Auxiliary PS3 data scan failed: " + ex, "WARN"); }
                try
                {
                    Dispatcher.BeginInvoke(new Action(delegate
                    {
                        if (closing || generation != auxiliaryGeneration) return;
                        trophySets = trophies;
                        photoFiles = photos;
                        UpdateTrophyMenus();
                        UpdatePhotoMenus();
                        surface.InvalidateVisual();
                    }));
                }
                catch { }
            });
        }

        private void UpdateTrophyMenus()
        {
            XmbItem root = FindItemByAction("OpenTrophies");
            if (root == null) return;
            List<XmbItem> sets = new List<XmbItem>();
            foreach (TrophySet set in trophySets)
            {
                List<XmbItem> trophies = new List<XmbItem>();
                foreach (TrophyEntry trophy in set.Trophies)
                {
                    string status = trophy.Unlocked ? trophy.Grade + "  Earned" + (String.IsNullOrWhiteSpace(trophy.Timestamp) ? String.Empty : "  " + trophy.Timestamp) : trophy.Grade + "  Locked";
                    XmbItem item = new XmbItem(trophy.Hidden && !trophy.Unlocked ? "Hidden Trophy" : trophy.Name, status + " — " + trophy.Description, "TrophyInfo|" + EncodeActionValue(trophy.Name));
                    item.IconPath = trophy.IconPath;
                    trophies.Add(item);
                }
                string progress = set.Total == 0 ? "No trophies" : set.Unlocked.ToString(CultureInfo.InvariantCulture) + "/" + set.Total.ToString(CultureInfo.InvariantCulture) + "  " + set.Percent.ToString(CultureInfo.InvariantCulture) + "%";
                XmbItem game = new XmbItem(set.Name, progress, null, trophies);
                game.IconPath = set.IconPath;
                sets.Add(game);
            }
            if (sets.Count == 0) sets.Add(new XmbItem("No Trophy Data", "No RPCS3 trophy folders were found for the active user data", "RefreshTrophies"));
            root.Children = sets;
            root.Subtitle = trophySets.Count == 1 ? "1 game" : trophySets.Count.ToString(CultureInfo.InvariantCulture) + " games";
        }

        private void FocusTrophyCollection()
        {
            XmbItem root = FindItemByAction("OpenTrophies");
            if (root != null && root.Children != null && root.Children.Count > 0)
            {
                menuStack.Push(new XmbMenuContext(root.Title, root.Children, selectedIndex));
                selectedIndex = 0;
                visualItem = 0;
                SelectionChanged();
            }
            else ShowNotice("Trophy data is still loading");
        }

        private void UpdatePhotoMenus()
        {
            XmbCategory category = categories.FirstOrDefault(delegate(XmbCategory value) { return value.Id == "Photo"; });
            if (category == null) return;
            category.Items.Clear();
            category.Items.Add(new XmbItem("Screenshot Folder", GetScreenshotFolder(), "ChooseScreenshotFolder"));
            category.Items.Add(new XmbItem("Refresh", photoFiles.Count.ToString(CultureInfo.InvariantCulture) + " screenshots", "RefreshPhotos"));
            foreach (string path in photoFiles.Take(250))
            {
                FileInfo info = new FileInfo(path);
                XmbItem item = new XmbItem(Path.GetFileNameWithoutExtension(path), info.Exists ? info.LastWriteTime.ToString("g", CultureInfo.CurrentCulture) : String.Empty, "ViewPhoto|" + EncodeActionValue(path));
                item.IconPath = path;
                item.HeroPath = path;
                category.Items.Add(item);
            }
            if (photoFiles.Count == 0) category.Items.Add(new XmbItem("No Screenshots", "RPCS3 screenshots will appear here", "RefreshPhotos"));
        }

        private void OpenPhotoViewer(string path)
        {
            int index = photoFiles.FindIndex(delegate(string value) { return String.Equals(value, path, StringComparison.OrdinalIgnoreCase); });
            if (index < 0 || !File.Exists(path)) { ShowNotice("Screenshot is no longer available"); return; }
            photoViewerIndex = index;
            photoViewerActive = true;
            surface.InvalidateVisual();
        }

        private void MovePhoto(int delta)
        {
            if (photoFiles.Count == 0) return;
            photoViewerIndex = (photoViewerIndex + delta + photoFiles.Count) % photoFiles.Count;
            audio.Play("move");
            surface.InvalidateVisual();
        }

        private void ClosePhotoViewer()
        {
            photoViewerActive = false;
            photoViewerIndex = -1;
            audio.Play("cancel");
            surface.InvalidateVisual();
        }

        private string GetScreenshotFolder()
        {
            return PhotoScanner.ResolveFolder(settings, GetRpcs3DataRoot(), GetRpcs3Executable());
        }

        private void ChooseScreenshotFolder()
        {
            Forms.FolderBrowserDialog dialog = new Forms.FolderBrowserDialog();
            dialog.Description = "Choose the folder used by the XMB Photo category";
            dialog.SelectedPath = GetScreenshotFolder();
            if (dialog.ShowDialog() != Forms.DialogResult.OK) return;
            settings.screenshotFolder = Path.GetFullPath(dialog.SelectedPath);
            settings.Save(settingsPath);
            BeginAuxiliaryDataScan();
        }

        private void SetAssetSource(string source)
        {
            if (source == "Installed .p3t Theme" && String.IsNullOrWhiteSpace(settings.themeDirectory))
            {
                ShowNotice("Install a .p3t theme first");
                return;
            }
            settings.xmbAssetSource = source;
            settings.backgroundImage = String.Empty;
            RestoreAppearanceColorPreference();
            settings.Save(settingsPath);
            theme.Refresh();
            audio.Refresh();
            ShowNotice("XMB asset source: " + source);
        }

        private void ChooseCustomAssetFolder()
        {
            Forms.FolderBrowserDialog dialog = new Forms.FolderBrowserDialog();
            dialog.Description = "Choose a folder containing XMB-compatible PNG/JPG/GIM and WAV/VAG assets";
            if (!String.IsNullOrWhiteSpace(settings.customAssetFolder)) dialog.SelectedPath = settings.customAssetFolder;
            if (dialog.ShowDialog() != Forms.DialogResult.OK) return;
            settings.customAssetFolder = Path.GetFullPath(dialog.SelectedPath);
            try
            {
                FirmwareAssetExtractor.Extract(settings.customAssetFolder, Path.Combine(themeRoot, "CustomAssets"), WriteLog);
                settings.xmbAssetSource = "Custom Folder";
                RestoreAppearanceColorPreference();
                settings.Save(settingsPath);
                theme.Refresh();
                audio.Refresh();
                ShowNotice("Custom XMB assets cached");
            }
            catch (Exception ex) { ShowNotice("Custom assets could not be loaded: " + ex.Message); }
        }

        private string GetFirmwareAssetCacheStatus()
        {
            string manifest = Path.Combine(themeRoot, "FirmwareAssets", "theme-manifest.json");
            return File.Exists(manifest) ? "Cached from selected RPCS3 firmware" : "Not cached — select Refresh Firmware Asset Cache";
        }

        private void RefreshFirmwareAssetCache()
        {
            string root = GetRpcs3DataRoot();
            string devFlash = String.IsNullOrWhiteSpace(root) ? String.Empty : Path.Combine(root, "dev_flash");
            if (!Directory.Exists(devFlash)) { ShowNotice("The selected RPCS3 firmware dev_flash folder was not found"); return; }
            inputSuspended = true;
            ShowNotice("Caching compatible firmware presentation assets...");
            ThreadPool.QueueUserWorkItem(delegate
            {
                string error = String.Empty;
                try { FirmwareAssetExtractor.Extract(devFlash, Path.Combine(themeRoot, "FirmwareAssets"), WriteLog); }
                catch (Exception ex) { error = ex.Message; WriteLog("Firmware asset extraction failed: " + ex, "ERROR"); }
                SafeBeginUi(delegate
                {
                    inputSuspended = false;
                    inputGuardUntilUtc = DateTime.UtcNow.AddMilliseconds(350);
                    if (!String.IsNullOrWhiteSpace(error)) { ShowNotice("Firmware assets could not be cached: " + error); return; }
                    settings.xmbAssetSource = "Firmware Assets";
                    RestoreAppearanceColorPreference();
                    settings.Save(settingsPath);
                    theme.Refresh();
                    audio.Refresh();
                    UpdateFirmwareThemesMenu();
                    ShowNotice("Firmware XMB assets cached. Bundled firmware themes are available under Theme Settings.");
                }, "Firmware asset cache");
            });
        }

        private void InstallPackage()
        {
            string executable = GetRpcs3Executable();
            if (String.IsNullOrWhiteSpace(executable)) { ShowNotice("Select RPCS3 first"); return; }
            OpenFileDialog dialog = new OpenFileDialog();
            dialog.Title = "Install a PlayStation 3 package or update";
            dialog.Filter = "PlayStation 3 package (*.pkg)|*.pkg|All files (*.*)|*.*";
            if (dialog.ShowDialog(this) != true) return;
            try
            {
                ProcessStartInfo info = new ProcessStartInfo(executable, "--installpkg \"" + dialog.FileName + "\"");
                info.WorkingDirectory = Path.GetDirectoryName(executable);
                info.UseShellExecute = false;
                Process.Start(info);
                ShowNotice("Package installation sent to RPCS3");
            }
            catch (Exception ex) { ShowNotice("Package could not be installed: " + ex.Message); }
        }

        private void ClearRpcs3Caches()
        {
            string root = GetRpcs3DataRoot();
            if (String.IsNullOrWhiteSpace(root)) { ShowNotice("RPCS3 data location is not configured"); return; }
            string[] paths = new string[] { Path.Combine(root, "cache"), Path.Combine(root, "cache", "shaderlog") };
            int removed = 0;
            foreach (string path in paths)
            {
                try { if (Directory.Exists(path)) { Directory.Delete(path, true); removed++; } } catch (Exception ex) { WriteLog("Cache removal failed: " + ex.Message, "WARN"); }
            }
            ShowNotice(removed == 0 ? "No rebuildable caches were found" : "RPCS3 caches cleared");
        }

        private static string EncodeActionValue(string value)
        {
            return Convert.ToBase64String(Encoding.UTF8.GetBytes(value ?? String.Empty));
        }

        private static string DecodeActionValue(string value)
        {
            try { return Encoding.UTF8.GetString(Convert.FromBase64String(value)); } catch { return String.Empty; }
        }

        private void RestoreLastPosition()
        {
            if (!String.IsNullOrWhiteSpace(settings.lastCategory))
            {
                for (int i = 0; i < categories.Count; i++)
                {
                    if (String.Equals(categories[i].Id, settings.lastCategory, StringComparison.OrdinalIgnoreCase))
                    {
                        categoryIndex = i;
                        break;
                    }
                }
            }
            selectedIndex = categories[categoryIndex].SelectedIndex;
            visualCategory = categoryIndex;
            visualItem = selectedIndex;
        }

        private void SavePosition()
        {
            if (categoryIndex >= 0 && categoryIndex < categories.Count)
                settings.lastCategory = categories[categoryIndex].Id;
            XmbItem item = CurrentItem;
            if (item != null && item.Game != null) settings.lastSelection = item.Game.TitleId;
            settings.Save(settingsPath);
        }

        private void BeginLibraryScan(bool showNotice)
        {
            if (closing) return;
            if (scanRunning)
            {
                if (showNotice) ShowNotice("A PlayStation 3 library scan is already running");
                return;
            }
            scanRunning = true;
            int generation = ++scanGeneration;
            if (showNotice) ShowNotice("Scanning for PlayStation 3 games...");
            ThreadPool.QueueUserWorkItem(delegate
            {
                List<Ps3Game> games = new List<Ps3Game>();
                string scanError = String.Empty;
                try { games = Ps3LibraryScanner.Scan(settings, WriteLog); }
                catch (Exception ex) { scanError = ex.Message; WriteLog("PS3 library scan failed: " + ex, "ERROR"); }
                WriteLibrarySummary(games, scanError);
                try
                {
                    Dispatcher.BeginInvoke(new Action(delegate
                    {
                        if (closing || generation != scanGeneration) return;
                        scanRunning = false;
                        if (!String.IsNullOrWhiteSpace(scanError))
                        {
                            ShowNotice("PS3 library scan failed: " + scanError);
                            return;
                        }
                        ApplyGames(games);
                        ShowNotice(games.Count == 1 ? "1 PlayStation 3 game found" : games.Count + " PlayStation 3 games found");
                    }));
                }
                catch { }
            });
        }

        private void WriteLibrarySummary(List<Ps3Game> games, string error)
        {
            string temp = String.Empty;
            try
            {
                string path = Path.Combine(appDataRoot, "library-summary.json");
                temp = path + "." + Process.GetCurrentProcess().Id.ToString(CultureInfo.InvariantCulture) + ".tmp";
                JavaScriptSerializer serializer = new JavaScriptSerializer();
                Dictionary<string, object> summary = new Dictionary<string, object>();
                List<Dictionary<string, object>> entries = new List<Dictionary<string, object>>();
                foreach (Ps3Game game in games ?? new List<Ps3Game>())
                {
                    Dictionary<string, object> entry = new Dictionary<string, object>();
                    entry["Title"] = game.Title ?? String.Empty;
                    entry["TitleId"] = game.TitleId ?? String.Empty;
                    entry["Source"] = game.Source ?? String.Empty;
                    entry["RootPath"] = game.RootPath ?? String.Empty;
                    entry["Category"] = game.Category ?? String.Empty;
                    entry["Available"] = (!String.IsNullOrWhiteSpace(game.RootPath) &&
                        (Directory.Exists(game.RootPath) || File.Exists(game.RootPath))) ||
                        (!String.IsNullOrWhiteSpace(game.EbootPath) && File.Exists(game.EbootPath));
                    entry["ActivatedC00"] = game.UsesActivatedC00;
                    entries.Add(entry);
                }
                summary["Count"] = entries.Count;
                summary["DataRoot"] = Ps3PathResolver.FindDataRoot(settings.rpcs3Path, settings.rpcs3DataPath);
                summary["UpdatedAt"] = DateTime.Now.ToString("o", CultureInfo.InvariantCulture);
                summary["Error"] = error ?? String.Empty;
                summary["Games"] = entries;
                File.WriteAllText(temp, serializer.Serialize(summary), Encoding.UTF8);
                if (File.Exists(path)) File.Delete(path);
                File.Move(temp, path);
            }
            catch
            {
                try { if (!String.IsNullOrWhiteSpace(temp) && File.Exists(temp)) File.Delete(temp); } catch { }
            }
        }

        private void ApplyGames(List<Ps3Game> games)
        {
            currentGames = games == null ? new List<Ps3Game>() : games;
            UpdatePerGameSettingsMenu();
            XmbCategory gameCategory = categories.FirstOrDefault(delegate(XmbCategory category) { return category.Id == "Game"; });
            if (gameCategory == null) return;
            while (gameCategory.Items.Count > 3) gameCategory.Items.RemoveAt(gameCategory.Items.Count - 1);
            foreach (Ps3Game game in games)
            {
                XmbItem item = new XmbItem(game.Title, game.TitleId + (String.IsNullOrWhiteSpace(game.Version) ? String.Empty : "  " + game.Version), null);
                item.Game = game;
                item.IconPath = game.IconPath;
                item.HeroPath = game.HeroPath;
                gameCategory.Items.Add(item);
            }
            if (gameCategory.Items.Count == 3)
                gameCategory.Items.Add(new XmbItem("PlayStation 3", "No games found. Add a library folder in Settings.", "AddLibrary"));
            if (categoryIndex == categories.IndexOf(gameCategory))
            {
                selectedIndex = Math.Max(0, Math.Min(selectedIndex, gameCategory.Items.Count - 1));
                visualItem = selectedIndex;
            }
            if (!String.IsNullOrWhiteSpace(settings.lastSelection))
            {
                for (int i = 0; i < gameCategory.Items.Count; i++)
                {
                    if (gameCategory.Items[i].Game != null && String.Equals(gameCategory.Items[i].Game.TitleId,
                        settings.lastSelection, StringComparison.OrdinalIgnoreCase))
                    {
                        gameCategory.SelectedIndex = i;
                        if (categoryIndex == categories.IndexOf(gameCategory))
                        {
                            selectedIndex = i;
                            visualItem = i;
                        }
                        break;
                    }
                }
            }
            surface.InvalidateVisual();
        }

        private void ChooseExistingRpcs3()
        {
            string start = settings.rpcs3Path;
            try { if (File.Exists(start)) start = Path.GetDirectoryName(start); } catch { }
            HuymaierNativePickerRequest.Request(this, "PS3", "PlayStation 3", "PrimaryEmulator", "RPCS3", start);
        }

        private void InstallManagedRpcs3()
        {
            HuymaierNativePickerRequest.Request(this, "PS3", "PlayStation 3", "InstallPrimaryEmulator", "RPCS3", settings.managedInstallFolder);
        }

        private void RescanRpcs3Configuration()
        {
            string executable = GetRpcs3Executable();
            if (String.IsNullOrWhiteSpace(executable))
            {
                ShowNotice("Select or install RPCS3 first");
                return;
            }
            settings.rpcs3DataPath = Ps3PathResolver.FindDataRoot(executable, String.Empty);
            settings.Save(settingsPath);
            theme.Refresh();
            audio.Refresh();
            UpdateFirmwareThemesMenu();
            RefreshDynamicSubtitles();
            BeginLibraryScan(true);
            ShowNotice("RPCS3 configuration re-scanned");
        }

        private void OpenFullRpcs3Settings()
        {
            NativeBackendSettingsWindow.Show(this, consoleRoot, "PS3", "PlayStation 3", "RPCS3", settingsPath);
            NativeConsoleNavigation.Reset();
            RefreshDynamicSubtitles();
        }

        private void ChooseRpcs3DataPath()
        {
            HuymaierNativePickerRequest.Request(this, "PS3", "PlayStation 3", "DataRoot", "RPCS3", GetRpcs3DataRoot());
        }

        private void InstallFirmware()
        {
            string executable = GetRpcs3Executable();
            if (String.IsNullOrWhiteSpace(executable))
            {
                ShowNotice("Select or install RPCS3 first");
                return;
            }
            OpenFileDialog dialog = new OpenFileDialog();
            dialog.Title = "Select your legally obtained PS3 system software";
            dialog.Filter = "PS3 system software (PS3UPDAT.PUP)|PS3UPDAT.PUP;*.PUP|PUP files (*.pup)|*.pup";
            if (dialog.ShowDialog(this) != true) return;
            string pup = dialog.FileName;
            inputSuspended = true;
            audio.PauseMusic();
            ShowNotice("Installing PS3 system software...");
            ThreadPool.QueueUserWorkItem(delegate
            {
                string error = String.Empty;
                try
                {
                    ProcessStartInfo info = new ProcessStartInfo();
                    info.FileName = executable;
                    info.Arguments = "--headless --installfw \"" + pup + "\"";
                    info.WorkingDirectory = Path.GetDirectoryName(executable);
                    info.UseShellExecute = false;
                    info.CreateNoWindow = true;
                    using (Process process = Process.Start(info))
                    {
                        if (process == null) throw new InvalidOperationException("RPCS3 did not start.");
                        process.WaitForExit();
                        if (process.ExitCode != 0) throw new InvalidOperationException("RPCS3 firmware installer exited with code " + process.ExitCode + ".");
                    }
                }
                catch (Exception ex) { error = ex.Message; WriteLog("Firmware install failed: " + ex, "ERROR"); }
                SafeBeginUi(delegate
                {
                    inputSuspended = false;
                    theme.Refresh();
                    audio.Refresh();
                    UpdateFirmwareThemesMenu();
                    RefreshDynamicSubtitles();
                    audio.ResumeMusic();
                    ShowNotice(String.IsNullOrWhiteSpace(error) ? "PS3 system software installed" : "Firmware installation failed: " + error);
                }, "PS3 firmware install");
            });
        }

        private void AddLibraryFolder()
        {
            HuymaierNativePickerRequest.Request(this, "PS3", "PlayStation 3", "GameFolder", "RPCS3", GetRpcs3DataRoot());
        }

        private void RemoveLibraryFolder(string path)
        {
            string selected = NormalizeLibraryRoot(path);
            if (String.IsNullOrWhiteSpace(selected)) return;
            int removed = settings.libraryRoots.RemoveAll(delegate(string value)
            {
                return String.Equals(NormalizeLibraryRoot(value), selected, StringComparison.OrdinalIgnoreCase);
            });
            if (removed == 0)
            {
                ShowNotice("That library folder is no longer registered");
                return;
            }
            settings.Save(settingsPath);
            UpdateLibraryFolderSettingsMenu();
            RefreshDynamicSubtitles();
            if (menuStack.Count > 0)
            {
                XmbMenuContext removedFolderContext = menuStack.Pop();
                int itemCount = CurrentItems.Count;
                selectedIndex = itemCount == 0 ? 0 : Math.Max(0, Math.Min(removedFolderContext.ParentSelection, itemCount - 1));
                visualItem = selectedIndex;
                SelectionChanged();
            }
            ShowNotice("Library folder removed from XMB. Game files were not deleted.");
            BeginLibraryScan(false);
        }

        private static string NormalizeLibraryRoot(string path)
        {
            if (String.IsNullOrWhiteSpace(path)) return String.Empty;
            try
            {
                return Path.GetFullPath(Environment.ExpandEnvironmentVariables(path.Trim()))
                    .TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
            }
            catch
            {
                return path.Trim().TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
            }
        }

        private static bool LibraryRootsOverlap(string left, string right)
        {
            if (String.IsNullOrWhiteSpace(left) || String.IsNullOrWhiteSpace(right)) return false;
            if (String.Equals(left, right, StringComparison.OrdinalIgnoreCase)) return true;
            string leftPrefix = left + Path.DirectorySeparatorChar;
            string rightPrefix = right + Path.DirectorySeparatorChar;
            return left.StartsWith(rightPrefix, StringComparison.OrdinalIgnoreCase) ||
                right.StartsWith(leftPrefix, StringComparison.OrdinalIgnoreCase);
        }

        private void OpenRpcs3Ui()
        {
            string executable = GetRpcs3Executable();
            if (String.IsNullOrWhiteSpace(executable))
            {
                ShowNotice("Select or install RPCS3 first");
                return;
            }
            try
            {
                ProcessStartInfo info = new ProcessStartInfo(executable);
                info.WorkingDirectory = Path.GetDirectoryName(executable);
                info.Arguments = "--user-id " + QuoteWindowsArgument(GetActiveRpcs3UserId());
                info.UseShellExecute = true;
                Process.Start(info);
            }
            catch (Exception ex) { ShowNotice("RPCS3 could not open: " + ex.Message); }
        }

        private void OpenDataFolder(string relative)
        {
            string root = GetRpcs3DataRoot();
            if (String.IsNullOrWhiteSpace(root))
            {
                ShowNotice("RPCS3 data location is not configured");
                return;
            }
            string path = Path.Combine(root, relative);
            Directory.CreateDirectory(path);
            try { Process.Start("explorer.exe", "\"" + path + "\""); }
            catch (Exception ex) { ShowNotice(ex.Message); }
        }

        private void ImportTheme()
        {
            OpenFileDialog dialog = new OpenFileDialog();
            dialog.Title = "Install a PlayStation 3 theme";
            dialog.Filter = "PlayStation 3 themes (*.p3t)|*.p3t|All files (*.*)|*.*";
            if (dialog.ShowDialog(this) != true) return;
            try
            {
                string name = MakeSafeFileName(Path.GetFileNameWithoutExtension(dialog.FileName));
                string destination = Path.Combine(themeRoot, name + "-" + DateTime.Now.ToString("yyyyMMddHHmmss"));
                Directory.CreateDirectory(destination);
                P3TImporter.Import(dialog.FileName, destination);
                settings.theme = Path.GetFileNameWithoutExtension(dialog.FileName);
                settings.themeDirectory = destination;
                settings.xmbAssetSource = "Installed .p3t Theme";
                settings.backgroundImage = String.Empty;
                RestoreAppearanceColorPreference();
                settings.Save(settingsPath);
                theme.Refresh();
                audio.Refresh();
                UpdateInstalledThemesMenu();
                UpdateFirmwareThemesMenu();
                ShowNotice("Theme installed and selected: " + settings.theme);
            }
            catch (Exception ex)
            {
                WriteLog("Theme import failed: " + ex, "ERROR");
                ShowNotice("Theme could not be installed: " + ex.Message);
            }
        }

        private void RestoreOriginalTheme()
        {
            settings.theme = "Original PS3 (Firmware Default)";
            settings.xmbAssetSource = "Firmware Assets";
            settings.firmwareThemeFile = String.Empty;
            settings.firmwareThemeName = String.Empty;
            settings.themeDirectory = String.Empty;
            settings.backgroundImage = String.Empty;
            RestoreAppearanceColorPreference();
            settings.Save(settingsPath);
            theme.Refresh();
            audio.Refresh();
            UpdateFirmwareThemesMenu();
            ShowNotice(theme.HasFirmwareTheme ? "Original PS3 theme restored" : "Original-wave fallback active until firmware assets are available");
        }

        private string GetAppearancePreferenceKey()
        {
            string key = (settings.xmbAssetSource ?? "Firmware Assets") + "|" +
                (settings.themeDirectory ?? String.Empty) + "|" + (settings.theme ?? String.Empty) + "|" +
                (settings.firmwareThemeFile ?? String.Empty);
            return Convert.ToBase64String(Encoding.UTF8.GetBytes(key));
        }

        private void SaveAppearanceColorPreference()
        {
            if (settings.themeColorPreferences == null)
                settings.themeColorPreferences = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            settings.themeColorPreferences[GetAppearancePreferenceKey()] =
                (settings.xmbColorMode ?? "Automatic") + "|" + (settings.xmbCustomColor ?? "#315F8A");
        }

        private void RestoreAppearanceColorPreference()
        {
            if (settings.themeColorPreferences == null) return;
            string value;
            if (!settings.themeColorPreferences.TryGetValue(GetAppearancePreferenceKey(), out value) ||
                String.IsNullOrWhiteSpace(value)) return;
            string[] parts = value.Split('|');
            if (parts.Length > 0 && !String.IsNullOrWhiteSpace(parts[0])) settings.xmbColorMode = parts[0];
            if (parts.Length > 1 && !String.IsNullOrWhiteSpace(parts[1])) settings.xmbCustomColor = parts[1];
        }

        private string GetXmbColorModeText()
        {
            string mode = settings.xmbColorMode ?? "Automatic";
            if (String.Equals(mode, "Automatic", StringComparison.OrdinalIgnoreCase))
                return "Automatic — original month and time cycle";
            if (String.Equals(mode, "Custom", StringComparison.OrdinalIgnoreCase))
                return "Custom — " + settings.xmbCustomColor;
            return "Theme Controlled";
        }

        private void CycleXmbColorMode()
        {
            string mode = settings.xmbColorMode ?? "Automatic";
            if (String.Equals(mode, "Automatic", StringComparison.OrdinalIgnoreCase)) mode = "Custom";
            else if (String.Equals(mode, "Custom", StringComparison.OrdinalIgnoreCase)) mode = "Theme";
            else mode = "Automatic";
            settings.xmbColorMode = mode;
            SaveAppearanceColorPreference();
            settings.Save(settingsPath);
            theme.Refresh();
            surface.InvalidateVisual();
            ShowNotice(GetXmbColorModeText());
        }

        private void ChooseXmbCustomColor()
        {
            Forms.ColorDialog dialog = new Forms.ColorDialog();
            dialog.FullOpen = true;
            Color current;
            if (TryParseThemeColor(settings.xmbCustomColor, out current))
                dialog.Color = System.Drawing.Color.FromArgb(current.R, current.G, current.B);
            if (dialog.ShowDialog() != Forms.DialogResult.OK) return;
            settings.xmbCustomColor = String.Format(CultureInfo.InvariantCulture, "#{0:X2}{1:X2}{2:X2}",
                dialog.Color.R, dialog.Color.G, dialog.Color.B);
            settings.xmbColorMode = "Custom";
            SaveAppearanceColorPreference();
            settings.Save(settingsPath);
            theme.Refresh();
            surface.InvalidateVisual();
            ShowNotice("XMB color: " + settings.xmbCustomColor);
        }

        internal static bool TryParseThemeColor(string value, out Color color)
        {
            color = Color.FromRgb(49, 95, 138);
            if (String.IsNullOrWhiteSpace(value)) return false;
            string colorText = value.Trim().TrimStart('#');
            if (colorText.Length != 6) return false;
            int parsed;
            if (!Int32.TryParse(colorText, NumberStyles.HexNumber, CultureInfo.InvariantCulture, out parsed)) return false;
            color = Color.FromRgb((byte)((parsed >> 16) & 0xff), (byte)((parsed >> 8) & 0xff), (byte)(parsed & 0xff));
            return true;
        }

        private void ChooseBackground()
        {
            OpenFileDialog dialog = new OpenFileDialog();
            dialog.Title = "Choose an XMB background";
            dialog.Filter = "Images (*.jpg;*.jpeg;*.png;*.bmp)|*.jpg;*.jpeg;*.png;*.bmp|All files (*.*)|*.*";
            if (dialog.ShowDialog(this) != true) return;
            settings.backgroundImage = dialog.FileName;
            settings.Save(settingsPath);
            theme.Refresh();
            ShowNotice("Background changed");
        }

        private void ChooseMusic()
        {
            OpenFileDialog dialog = new OpenFileDialog();
            dialog.Title = "Choose XMB background music";
            dialog.Filter = "Audio (*.mp3;*.wav;*.wma;*.m4a)|*.mp3;*.wav;*.wma;*.m4a|All files (*.*)|*.*";
            if (dialog.ShowDialog(this) != true) return;
            settings.backgroundMusic = dialog.FileName;
            settings.musicEnabled = true;
            settings.Save(settingsPath);
            audio.Refresh();
            ShowNotice("Background music changed");
        }

        private void RestoreIncludedMusic()
        {
            settings.backgroundMusic = String.Empty;
            settings.musicEnabled = true;
            settings.musicLoop = true;
            settings.Save(settingsPath);
            audio.Refresh();
            ShowNotice("Included Home Menu intro and ambient loop restored");
        }

        private void ToggleMusic()
        {
            settings.musicEnabled = !settings.musicEnabled;
            settings.Save(settingsPath);
            audio.Refresh();
            ShowNotice("Background music " + (settings.musicEnabled ? "on" : "off"));
        }

        private void CycleMusicVolume()
        {
            settings.musicVolume = CycleVolume(settings.musicVolume);
            settings.Save(settingsPath);
            audio.Refresh();
            ShowNotice("Music volume " + FormatPercent(settings.musicVolume));
        }

        private void ToggleSounds()
        {
            settings.soundEnabled = !settings.soundEnabled;
            settings.Save(settingsPath);
            ShowNotice("Key tone " + (settings.soundEnabled ? "on" : "off"));
        }

        private void CycleSoundVolume()
        {
            settings.soundVolume = CycleVolume(settings.soundVolume);
            settings.Save(settingsPath);
            audio.Refresh();
            audio.Play("confirm");
            ShowNotice("Key tone volume " + FormatPercent(settings.soundVolume));
        }

        private void ChooseSound(string name)
        {
            OpenFileDialog dialog = new OpenFileDialog();
            dialog.Title = "Choose the " + name + " sound";
            dialog.Filter = "Audio (*.wav;*.mp3;*.wma)|*.wav;*.mp3;*.wma|All files (*.*)|*.*";
            if (dialog.ShowDialog(this) != true) return;
            if (name == "move") settings.sounds.move = dialog.FileName;
            else if (name == "confirm") settings.sounds.confirm = dialog.FileName;
            else if (name == "cancel") settings.sounds.cancel = dialog.FileName;
            settings.Save(settingsPath);
            audio.Refresh();
            audio.Play(name);
            ShowNotice("Sound changed");
        }

        private void LaunchGame(Ps3Game game)
        {
            string executable = GetRpcs3Executable();
            if (String.IsNullOrWhiteSpace(executable))
            {
                ShowNotice("Select or install RPCS3 in Settings first");
                return;
            }
            if (IsRpcs3AlreadyRunning(executable))
            {
                ShowNotice("Close the existing RPCS3 window before starting a game from the XMB");
                WriteLog("Game launch blocked because the selected RPCS3 installation is already running.", "WARN");
                return;
            }

            string target = ResolveRpcs3BootTarget(game);
            bool titleIdTarget = target.StartsWith("%RPCS3_GAMEID%:", StringComparison.OrdinalIgnoreCase);
            if (String.IsNullOrWhiteSpace(target) || (!titleIdTarget && !File.Exists(target) && !Directory.Exists(target)))
            {
                ShowNotice("Game files are no longer available");
                return;
            }
            settings.lastSelection = game.TitleId;
            settings.Save(settingsPath);
            audio.Play("launch");
            audio.PauseMusic();
            inputSuspended = true;
            Hide();
            try
            {
                ProcessStartInfo info = new ProcessStartInfo();
                info.FileName = executable;
                info.Arguments = "--no-gui --game-screen 0 --user-id " + QuoteWindowsArgument(GetActiveRpcs3UserId()) + " " + QuoteWindowsArgument(target);
                info.WorkingDirectory = Path.GetDirectoryName(executable);
                info.UseShellExecute = false;
                info.CreateNoWindow = true;
                activeBootTarget = target;
                emulatorLaunchUtc = DateTime.UtcNow;
                WriteLog("Launching RPCS3: " + executable + " " + info.Arguments, "INFO");
                activeEmulatorProcess = Process.Start(info);
                if (activeEmulatorProcess == null) throw new InvalidOperationException("RPCS3 did not start.");
                activeEmulatorProcess.EnableRaisingEvents = true;
                activeEmulatorProcess.Exited += EmulatorExited;
            }
            catch (Exception ex)
            {
                WriteLog("RPCS3 game launch failed for " + game.TitleId + ": " + ex, "ERROR");
                inputSuspended = false;
                Show();
                NativeWindowActivation.Restore(this);
                audio.ResumeMusic();
                ShowNotice("Game could not start: " + ex.Message);
            }
        }

        private void EmulatorExited(object sender, EventArgs e)
        {
            int exitCode = Int32.MinValue;
            try { if (sender is Process) exitCode = ((Process)sender).ExitCode; } catch { }
            double runSeconds = emulatorLaunchUtc == DateTime.MinValue ? 0 : (DateTime.UtcNow - emulatorLaunchUtc).TotalSeconds;
            WriteLog("RPCS3 exited after " + runSeconds.ToString("0.0", CultureInfo.InvariantCulture) +
                " second(s), code " + (exitCode == Int32.MinValue ? "unknown" : exitCode.ToString(CultureInfo.InvariantCulture)) +
                ", target " + (activeBootTarget ?? String.Empty), runSeconds < 5 ? "WARN" : "INFO");
            SafeBeginUi(delegate
            {
                try
                {
                    if (activeEmulatorProcess != null)
                    {
                        activeEmulatorProcess.Exited -= EmulatorExited;
                        activeEmulatorProcess.Dispose();
                        activeEmulatorProcess = null;
                    }
                }
                catch { activeEmulatorProcess = null; }
                inputSuspended = false;
                input.Reset();
                inputGuardUntilUtc = DateTime.UtcNow.AddMilliseconds(500);
                Show();
                WindowState = settings.fullscreen ? WindowState.Maximized : WindowState.Normal;
                NativeWindowActivation.Restore(this);
                audio.Play("return");
                audio.ResumeMusic();
                ShowNotice(runSeconds < 5 ? "RPCS3 closed before the game finished booting" : "Returned to the XMB");
            }, "RPCS3 process return");
        }

        private string ResolveRpcs3BootTarget(Ps3Game game)
        {
            if (game == null) return String.Empty;
            string dataRoot = GetRpcs3DataRoot();
            string installedRoot = String.IsNullOrWhiteSpace(dataRoot)
                ? String.Empty
                : Path.Combine(dataRoot, "dev_hdd0", "game");
            if (!String.IsNullOrWhiteSpace(game.TitleId) &&
                (!String.IsNullOrWhiteSpace(game.Source) && game.Source.IndexOf("RPCS3 Installed", StringComparison.OrdinalIgnoreCase) >= 0 ||
                 IsPathInside(game.RootPath, installedRoot)))
                return "%RPCS3_GAMEID%:" + game.TitleId.Trim();

            if (!String.IsNullOrWhiteSpace(game.EbootPath) && File.Exists(game.EbootPath))
                return Path.GetFullPath(game.EbootPath);
            if (!String.IsNullOrWhiteSpace(game.RootPath) &&
                (Directory.Exists(game.RootPath) || File.Exists(game.RootPath)))
                return Path.GetFullPath(game.RootPath);
            return String.Empty;
        }

        private static bool IsPathInside(string path, string root)
        {
            if (String.IsNullOrWhiteSpace(path) || String.IsNullOrWhiteSpace(root)) return false;
            try
            {
                string fullPath = Path.GetFullPath(path).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar) + Path.DirectorySeparatorChar;
                string fullRoot = Path.GetFullPath(root).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar) + Path.DirectorySeparatorChar;
                return fullPath.StartsWith(fullRoot, StringComparison.OrdinalIgnoreCase);
            }
            catch { return false; }
        }

        private static string QuoteWindowsArgument(string value)
        {
            if (value == null) return "\"\"";
            if (value.Length > 0 && value.IndexOfAny(new char[] { ' ', '\t', '\n', '\v', '"' }) < 0) return value;
            StringBuilder builder = new StringBuilder(value.Length + 8);
            builder.Append('"');
            int backslashes = 0;
            foreach (char character in value)
            {
                if (character == '\\')
                {
                    backslashes++;
                    continue;
                }
                if (character == '"')
                {
                    builder.Append('\\', (backslashes * 2) + 1);
                    builder.Append('"');
                    backslashes = 0;
                    continue;
                }
                if (backslashes > 0)
                {
                    builder.Append('\\', backslashes);
                    backslashes = 0;
                }
                builder.Append(character);
            }
            if (backslashes > 0) builder.Append('\\', backslashes * 2);
            builder.Append('"');
            return builder.ToString();
        }

        private static bool IsRpcs3AlreadyRunning(string executable)
        {
            string processName = Path.GetFileNameWithoutExtension(executable);
            if (String.IsNullOrWhiteSpace(processName)) return false;
            Process[] processes;
            try { processes = Process.GetProcessesByName(processName); }
            catch { return false; }
            foreach (Process process in processes)
            {
                try
                {
                    if (process.Id == Process.GetCurrentProcess().Id) continue;
                    string runningPath = process.MainModule == null ? String.Empty : process.MainModule.FileName;
                    if (String.IsNullOrWhiteSpace(runningPath) ||
                        String.Equals(Path.GetFullPath(runningPath), Path.GetFullPath(executable), StringComparison.OrdinalIgnoreCase))
                        return true;
                }
                catch
                {
                    // A matching process whose path cannot be queried is still
                    // treated as RPCS3 to avoid forwarding into an unmonitorable GUI.
                    return true;
                }
                finally { try { process.Dispose(); } catch { } }
            }
            return false;
        }

        private string GetRpcs3Executable()
        {
            if (!String.IsNullOrWhiteSpace(settings.rpcs3Path) && File.Exists(settings.rpcs3Path))
                return Path.GetFullPath(settings.rpcs3Path);
            return String.Empty;
        }

        internal string GetRpcs3DataRoot()
        {
            return Ps3PathResolver.FindDataRoot(GetRpcs3Executable(), settings.rpcs3DataPath);
        }

        internal string GetFirmwareThemeFile()
        {
            string root = GetRpcs3DataRoot();
            if (String.IsNullOrWhiteSpace(root)) return String.Empty;
            // The numbered firmware .p3t files are optional art themes, not the
            // stock XMB presentation. Never treat 01.p3t as the firmware default.
            string[] candidates = new string[] {
                Path.Combine(root, "dev_flash", "vsh", "resource", "theme", "original.p3t"),
                Path.Combine(root, "dev_flash", "vsh", "resource", "theme", "default.p3t")
            };
            foreach (string candidate in candidates) if (File.Exists(candidate)) return candidate;
            return String.Empty;
        }

        internal string GetFirmwareFontDirectory()
        {
            string root = GetRpcs3DataRoot();
            if (String.IsNullOrWhiteSpace(root)) return String.Empty;
            string directory = Path.Combine(root, "dev_flash", "data", "font");
            return Directory.Exists(directory) ? directory : String.Empty;
        }

        internal string ThemeCacheRoot { get { return themeRoot; } }
        internal string CacheRoot { get { return cacheRoot; } }

        internal BitmapSource LoadImage(string path)
        {
            if (String.IsNullOrWhiteSpace(path) || !File.Exists(path)) return null;
            BitmapSource cached;
            if (imageCache.TryGetValue(path, out cached)) return cached;
            try
            {
                BitmapImage image = new BitmapImage();
                image.BeginInit();
                image.CacheOption = BitmapCacheOption.OnLoad;
                image.CreateOptions = BitmapCreateOptions.IgnoreColorProfile;
                image.DecodePixelWidth = 1280;
                image.UriSource = new Uri(path, UriKind.Absolute);
                image.EndInit();
                image.Freeze();
                if (imageCache.Count >= 64) imageCache.Clear();
                imageCache[path] = image;
                return image;
            }
            catch { return null; }
        }

        internal void ShowNotice(string text)
        {
            noticeText = text == null ? String.Empty : text;
            noticeUntilUtc = DateTime.UtcNow.AddSeconds(3.2);
            surface.InvalidateVisual();
        }

        internal void WriteLog(string message, string level)
        {
            try
            {
                string line = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fff") + " [" + level + "] " + message + Environment.NewLine;
                File.AppendAllText(logPath, line, Encoding.UTF8);
                if (String.Equals(level, "ERROR", StringComparison.OrdinalIgnoreCase) || String.Equals(level, "WARN", StringComparison.OrdinalIgnoreCase))
                {
                    string generalRoot = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Huymaier Console", "Logs");
                    Directory.CreateDirectory(generalRoot);
                    File.AppendAllText(Path.Combine(generalRoot, DateTime.Now.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture) + ".log"),
                        DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fff", CultureInfo.InvariantCulture) + " [" + level + "] PS3 XMB: " + message + Environment.NewLine, Encoding.UTF8);
                }
            }
            catch { }
        }

        private string GetRpcs3StatusText()
        {
            return String.IsNullOrWhiteSpace(GetRpcs3Executable()) ? "Not configured" : GetRpcs3Executable();
        }

        private string GetManagedInstallText()
        {
            return String.IsNullOrWhiteSpace(settings.managedInstallFolder) ? "Choose an installation folder" : settings.managedInstallFolder;
        }

        private string GetRpcs3DataRootDisplay()
        {
            string root = GetRpcs3DataRoot();
            return String.IsNullOrWhiteSpace(root) ? "Automatic detection" : root;
        }

        private string GetFirmwareStatusText()
        {
            string root = GetRpcs3DataRoot();
            if (String.IsNullOrWhiteSpace(root)) return "RPCS3 is not configured";
            string marker = Path.Combine(root, "dev_flash", "vsh", "module", "vsh.self");
            return File.Exists(marker) ? "Installed" : "Required";
        }

        private string GetLibrarySummary()
        {
            return settings.libraryRoots.Count == 0 ? "No additional folders" : settings.libraryRoots.Count + " folder(s)";
        }

        private string GetBackgroundText()
        {
            return String.IsNullOrWhiteSpace(settings.backgroundImage) ? "Theme background" : Path.GetFileName(settings.backgroundImage);
        }

        private string GetMusicText()
        {
            return String.IsNullOrWhiteSpace(settings.backgroundMusic)
                ? "Included Home Menu → Ambient Loop"
                : Path.GetFileName(settings.backgroundMusic);
        }

        private static string GetSoundText(string value)
        {
            return String.IsNullOrWhiteSpace(value) ? "Theme default" : Path.GetFileName(value);
        }

        private static double CycleVolume(double value)
        {
            double next = Math.Round(value + 0.1, 2);
            if (next > 1.001) next = 0;
            return next;
        }

        private static string FormatPercent(double value)
        {
            return Math.Round(Math.Max(0, Math.Min(1, value)) * 100).ToString(CultureInfo.InvariantCulture) + "%";
        }

        private static string MakeSafeFileName(string value)
        {
            if (String.IsNullOrWhiteSpace(value)) return "Theme";
            foreach (char character in Path.GetInvalidFileNameChars()) value = value.Replace(character, '_');
            return value.Trim();
        }
    }

    internal sealed class XmbSurface : FrameworkElement
    {
        private readonly Ps3XmbWindow owner;
        private double phase;
        private readonly Dictionary<int, Rect> itemRects;

        public XmbSurface(Ps3XmbWindow owner)
        {
            this.owner = owner;
            Focusable = true;
            ClipToBounds = true;
            itemRects = new Dictionary<int, Rect>();
        }

        internal void AdvanceFrame(double deltaSeconds, bool reduced)
        {
            if (reduced) return;
            phase += Math.Max(0.0, Math.Min(0.05, deltaSeconds)) * 0.72;
            if (phase > Math.PI * 200.0) phase = 0.0;
        }

        internal int HitTestItem(Point position)
        {
            foreach (KeyValuePair<int, Rect> pair in itemRects)
            {
                if (pair.Value.Contains(position)) return pair.Key;
            }
            return -1;
        }

        protected override void OnRender(DrawingContext drawingContext)
        {
            base.OnRender(drawingContext);
            double width = ActualWidth;
            double height = ActualHeight;
            if (width < 1 || height < 1) return;
            itemRects.Clear();
            if (owner.PhotoViewerActive)
            {
                DrawPhotoViewer(drawingContext, width, height);
                return;
            }
            DrawBackground(drawingContext, width, height);
            DrawHeader(drawingContext, width, height);
            DrawCategories(drawingContext, width, height);
            DrawItems(drawingContext, width, height);
            DrawFooter(drawingContext, width, height);
            DrawNotice(drawingContext, width, height);
        }

        private void DrawPhotoViewer(DrawingContext dc, double width, double height)
        {
            dc.DrawRectangle(Brushes.Black, null, new Rect(0, 0, width, height));
            BitmapSource image = owner.LoadImage(owner.CurrentPhotoPath);
            if (image != null)
            {
                double ratio = Math.Min((width * 0.92) / image.PixelWidth, (height * 0.82) / image.PixelHeight);
                double drawWidth = image.PixelWidth * ratio;
                double drawHeight = image.PixelHeight * ratio;
                dc.DrawImage(image, new Rect((width - drawWidth) / 2, (height - drawHeight) / 2 - height * 0.025, drawWidth, drawHeight));
            }
            FormattedText caption = MakeText(owner.PhotoViewerCaption, owner.Theme.Typeface, Math.Max(15, height * 0.024), Brushes.White, FontWeights.Normal);
            dc.DrawText(caption, new Point((width - caption.Width) / 2, height * 0.92));
            FormattedText help = MakeText("L1/R1 or Left/Right: Browse     Circle/B: Return", owner.Theme.Typeface, Math.Max(13, height * 0.020), new SolidColorBrush(Color.FromArgb(210, 255, 255, 255)), FontWeights.Normal);
            dc.DrawText(help, new Point((width - help.Width) / 2, height * 0.955));
        }

        private void DrawBackground(DrawingContext dc, double width, double height)
        {
            BitmapSource background = owner.Theme.Background;
            if (background != null)
            {
                DrawImageFill(dc, background, new Rect(0, 0, width, height), 0.92);
                dc.DrawRectangle(new SolidColorBrush(Color.FromArgb(54, 0, 0, 0)), null, new Rect(0, 0, width, height));
            }
            else
            {
                Color baseColor = owner.Theme.MonthlyColor;
                LinearGradientBrush gradient = new LinearGradientBrush();
                gradient.StartPoint = new Point(0, 0);
                gradient.EndPoint = new Point(1, 1);
                gradient.GradientStops.Add(new GradientStop(ChangeBrightness(baseColor, -0.30), 0));
                gradient.GradientStops.Add(new GradientStop(baseColor, 0.50));
                gradient.GradientStops.Add(new GradientStop(ChangeBrightness(baseColor, -0.42), 1));
                dc.DrawRectangle(gradient, null, new Rect(0, 0, width, height));
            }

            DrawWave(dc, width, height, height * 0.62, phase, 34, 0.12);
            DrawWave(dc, width, height, height * 0.66, phase + 1.8, 48, 0.08);
            DrawWave(dc, width, height, height * 0.58, phase + 3.1, 22, 0.06);

            XmbItem current = owner.CurrentItem;
            if (current != null && !String.IsNullOrWhiteSpace(current.HeroPath))
            {
                double delay = (DateTime.UtcNow - owner.SelectedAtUtc).TotalMilliseconds;
                if (delay > 450)
                {
                    double opacity = Math.Min(0.58, (delay - 450) / 700.0 * 0.58);
                    BitmapSource hero = owner.LoadImage(current.HeroPath);
                    if (hero != null)
                    {
                        DrawImageFill(dc, hero, new Rect(0, 0, width, height), opacity);
                        dc.DrawRectangle(new LinearGradientBrush(Color.FromArgb(188, 0, 0, 0), Color.FromArgb(32, 0, 0, 0), 0),
                            null, new Rect(0, 0, width, height));
                    }
                }
            }
        }

        private void DrawWave(DrawingContext dc, double width, double height, double centerY, double offset, double amplitude, double opacity)
        {
            StreamGeometry geometry = new StreamGeometry();
            using (StreamGeometryContext context = geometry.Open())
            {
                double y0 = centerY + Math.Sin(offset) * amplitude;
                context.BeginFigure(new Point(-80, y0), false, false);
                for (int segment = 0; segment < 5; segment++)
                {
                    double x1 = width * (segment + 0.20) / 4.0;
                    double x2 = width * (segment + 0.65) / 4.0;
                    double x3 = width * (segment + 1.00) / 4.0;
                    double y1 = centerY + Math.Sin(offset + segment * 1.1 + 0.7) * amplitude;
                    double y2 = centerY + Math.Sin(offset + segment * 1.1 + 1.5) * amplitude;
                    double y3 = centerY + Math.Sin(offset + (segment + 1) * 1.1) * amplitude;
                    context.BezierTo(new Point(x1, y1), new Point(x2, y2), new Point(x3, y3), true, false);
                }
            }
            geometry.Freeze();
            Pen pen = new Pen(new SolidColorBrush(Color.FromArgb((byte)(255 * opacity), 255, 255, 255)), Math.Max(1.2, height / 500.0));
            pen.Freeze();
            dc.DrawGeometry(null, pen, geometry);
        }

        private void DrawHeader(DrawingContext dc, double width, double height)
        {
            Typeface typeface = owner.Theme.Typeface;
            string clock = DateTime.Now.ToString("ddd M/d  h:mm tt", CultureInfo.CurrentCulture);
            FormattedText clockText = MakeText(clock, typeface, Math.Max(15, height * 0.025), Brushes.White, FontWeights.Normal);
            dc.DrawText(clockText, new Point(width - clockText.Width - width * 0.035, height * 0.035));
        }

        private void DrawCategories(DrawingContext dc, double width, double height)
        {
            List<XmbCategory> categories = owner.Categories;
            if (categories == null || categories.Count == 0) return;
            double focusX = width * 0.190;
            double y = height * 0.220;
            double spacing = Math.Max(82, Math.Min(118, width * 0.085));
            double baseSize = Math.Max(34, Math.Min(56, height * 0.073));
            double alphaMultiplier = owner.InSubmenu ? 0.42 : 1.0;

            for (int index = 0; index < categories.Count; index++)
            {
                double distance = index - owner.VisualCategory;
                if (Math.Abs(distance) > 5.2) continue;
                double x = focusX + distance * spacing;
                bool selected = index == owner.CategoryIndex;
                double scale = selected ? 1.18 : 0.78;
                double opacity = Math.Max(0.15, 1.0 - Math.Abs(distance) * 0.13) * alphaMultiplier;
                string iconPath = owner.Theme.GetCategoryIcon(categories[index].Id);
                BitmapSource image = owner.LoadImage(iconPath);
                Rect iconRect = new Rect(x - baseSize * scale / 2, y - baseSize * scale / 2, baseSize * scale, baseSize * scale);
                if (image != null) dc.PushOpacity(opacity);
                if (image != null) dc.DrawImage(image, iconRect);
                else DrawFallbackCategoryIcon(dc, categories[index].Id, iconRect, opacity);
                if (image != null) dc.Pop();

                if (selected && !owner.InSubmenu)
                {
                    FormattedText label = MakeText(categories[index].Title, owner.Theme.Typeface,
                        Math.Max(17, height * 0.028), Brushes.White, FontWeights.Normal);
                    dc.DrawText(label, new Point(x - label.Width / 2, y + baseSize * 0.78));
                }
            }
        }

        private void DrawItems(DrawingContext dc, double width, double height)
        {
            List<XmbItem> items = owner.CurrentItems;
            if (items == null || items.Count == 0) return;
            double focusX = width * 0.190;
            double focusY = height * 0.445;
            double spacing = Math.Max(54, Math.Min(78, height * 0.090));
            double iconSize = Math.Max(36, Math.Min(58, height * 0.071));
            Typeface typeface = owner.Theme.Typeface;

            if (owner.InSubmenu)
            {
                FormattedText parentTitle = MakeText(owner.CurrentMenuTitle, typeface, Math.Max(18, height * 0.030), Brushes.White, FontWeights.Normal);
                dc.DrawText(parentTitle, new Point(focusX - iconSize * 0.10, height * 0.292));
            }

            for (int index = 0; index < items.Count; index++)
            {
                double distance = index - owner.VisualItem;
                if (Math.Abs(distance) > 5.2) continue;
                double y = focusY + distance * spacing;
                bool selected = index == owner.SelectedIndex;
                double scale = selected ? 1.17 : 0.73;
                double opacity = selected ? 1.0 : Math.Max(0.18, 0.67 - Math.Abs(distance) * 0.08);
                Rect iconRect = new Rect(focusX - iconSize * scale / 2, y - iconSize * scale / 2,
                    iconSize * scale, iconSize * scale);
                string iconPath = !String.IsNullOrWhiteSpace(items[index].IconPath) ? items[index].IconPath : owner.Theme.GetItemIcon(items[index]);
                BitmapSource icon = owner.LoadImage(iconPath);
                if (icon != null)
                {
                    dc.PushOpacity(opacity);
                    dc.DrawImage(icon, iconRect);
                    dc.Pop();
                }
                else DrawFallbackItemIcon(dc, items[index], iconRect, opacity, selected);

                double textX = focusX + iconSize * 0.78;
                double titleSize = selected ? Math.Max(20, height * 0.033) : Math.Max(15, height * 0.024);
                Brush titleBrush = new SolidColorBrush(Color.FromArgb((byte)(255 * opacity), 255, 255, 255));
                FormattedText title = MakeText(items[index].Title, typeface, titleSize, titleBrush, FontWeights.Normal);
                dc.DrawText(title, new Point(textX, y - title.Height * 0.55));

                if (selected && !String.IsNullOrWhiteSpace(items[index].Subtitle))
                {
                    FormattedText subtitle = MakeText(items[index].Subtitle, typeface, Math.Max(13, height * 0.020),
                        new SolidColorBrush(Color.FromArgb(210, 235, 235, 235)), FontWeights.Normal);
                    subtitle.MaxTextWidth = Math.Max(260, width - textX - width * 0.08);
                    subtitle.Trimming = TextTrimming.CharacterEllipsis;
                    dc.DrawText(subtitle, new Point(textX, y + title.Height * 0.45));
                }
                itemRects[index] = new Rect(focusX - iconSize, y - spacing * 0.44, width - focusX - width * 0.06, spacing * 0.88);
            }
        }

        private void DrawFooter(DrawingContext dc, double width, double height)
        {
            Typeface typeface = owner.Theme.Typeface;
            FormattedText hints = MakeText("× Enter     ○ Back", typeface, Math.Max(14, height * 0.021),
                new SolidColorBrush(Color.FromArgb(225, 255, 255, 255)), FontWeights.Normal);
            dc.DrawText(hints, new Point(width - hints.Width - width * 0.035, height - hints.Height - height * 0.035));
        }

        private void DrawNotice(DrawingContext dc, double width, double height)
        {
            string notice = owner.NoticeText;
            if (String.IsNullOrWhiteSpace(notice)) return;
            FormattedText text = MakeText(notice, owner.Theme.Typeface, Math.Max(15, height * 0.023), Brushes.White, FontWeights.Normal);
            double paddingX = 22;
            double paddingY = 12;
            Rect rect = new Rect(width - text.Width - paddingX * 2 - width * 0.035, height * 0.105,
                text.Width + paddingX * 2, text.Height + paddingY * 2);
            dc.DrawRoundedRectangle(new SolidColorBrush(Color.FromArgb(185, 0, 0, 0)),
                new Pen(new SolidColorBrush(Color.FromArgb(80, 255, 255, 255)), 1), rect, 4, 4);
            dc.DrawText(text, new Point(rect.X + paddingX, rect.Y + paddingY));
        }

        private static void DrawFallbackCategoryIcon(DrawingContext dc, string id, Rect rect, double opacity)
        {
            Brush stroke = new SolidColorBrush(Color.FromArgb((byte)(255 * opacity), 255, 255, 255));
            Pen pen = new Pen(stroke, Math.Max(1.6, rect.Width / 28));
            dc.DrawEllipse(null, pen, new Point(rect.X + rect.Width / 2, rect.Y + rect.Height / 2), rect.Width * 0.36, rect.Height * 0.36);
            string letter = String.IsNullOrWhiteSpace(id) ? "•" : id.Substring(0, 1).ToUpperInvariant();
            FormattedText text = MakeText(letter, new Typeface("Segoe UI"), rect.Height * 0.34, stroke, FontWeights.Light);
            dc.DrawText(text, new Point(rect.X + (rect.Width - text.Width) / 2, rect.Y + (rect.Height - text.Height) / 2));
        }

        private static void DrawFallbackItemIcon(DrawingContext dc, XmbItem item, Rect rect, double opacity, bool selected)
        {
            Brush stroke = new SolidColorBrush(Color.FromArgb((byte)(255 * opacity), 255, 255, 255));
            Pen pen = new Pen(stroke, Math.Max(1.3, rect.Width / 32));
            if (item != null && item.Game != null)
            {
                dc.DrawRoundedRectangle(new SolidColorBrush(Color.FromArgb((byte)(70 * opacity), 255, 255, 255)), pen, rect, 4, 4);
                FormattedText text = MakeText("PS3", new Typeface("Segoe UI"), rect.Height * 0.23, stroke, FontWeights.SemiBold);
                dc.DrawText(text, new Point(rect.X + (rect.Width - text.Width) / 2, rect.Y + (rect.Height - text.Height) / 2));
            }
            else
            {
                dc.DrawEllipse(new SolidColorBrush(Color.FromArgb((byte)(32 * opacity), 255, 255, 255)), pen,
                    new Point(rect.X + rect.Width / 2, rect.Y + rect.Height / 2), rect.Width * 0.34, rect.Height * 0.34);
            }
        }

        private static FormattedText MakeText(string text, Typeface typeface, double size, Brush brush, FontWeight weight)
        {
            Typeface finalTypeface = new Typeface(typeface.FontFamily, typeface.Style, weight, typeface.Stretch);
            return new FormattedText(text == null ? String.Empty : text, CultureInfo.CurrentUICulture,
                FlowDirection.LeftToRight, finalTypeface, size, brush);
        }

        private static void DrawImageFill(DrawingContext dc, ImageSource source, Rect bounds, double opacity)
        {
            if (source == null || source.Width <= 0 || source.Height <= 0) return;
            double sourceRatio = source.Width / source.Height;
            double targetRatio = bounds.Width / bounds.Height;
            Rect destination;
            if (sourceRatio > targetRatio)
            {
                double width = bounds.Height * sourceRatio;
                destination = new Rect(bounds.X - (width - bounds.Width) / 2, bounds.Y, width, bounds.Height);
            }
            else
            {
                double height = bounds.Width / sourceRatio;
                destination = new Rect(bounds.X, bounds.Y - (height - bounds.Height) / 2, bounds.Width, height);
            }
            dc.PushClip(new RectangleGeometry(bounds));
            dc.PushOpacity(opacity);
            dc.DrawImage(source, destination);
            dc.Pop();
            dc.Pop();
        }

        private static Color ChangeBrightness(Color color, double amount)
        {
            int red = (int)Math.Round(color.R + 255 * amount);
            int green = (int)Math.Round(color.G + 255 * amount);
            int blue = (int)Math.Round(color.B + 255 * amount);
            return Color.FromRgb((byte)Math.Max(0, Math.Min(255, red)),
                (byte)Math.Max(0, Math.Min(255, green)),
                (byte)Math.Max(0, Math.Min(255, blue)));
        }
    }

    internal sealed class XmbTheme
    {
        private readonly Ps3XmbWindow owner;
        private P3TImportResult manifest;
        private readonly Dictionary<string, string> categoryIcons;
        private readonly Dictionary<string, string> actionIcons;
        private BitmapSource background;
        private Typeface typeface;
        private bool hasFirmwareTheme;

        internal XmbTheme(Ps3XmbWindow owner)
        {
            this.owner = owner;
            categoryIcons = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            actionIcons = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            typeface = new Typeface("Segoe UI");
        }

        internal BitmapSource Background { get { return background; } }
        internal Typeface Typeface { get { return typeface; } }
        internal bool HasFirmwareTheme { get { return hasFirmwareTheme; } }
        internal Color MonthlyColor
        {
            get
            {
                string mode = owner.Settings.xmbColorMode ?? "Automatic";
                Color selected;
                if (String.Equals(mode, "Custom", StringComparison.OrdinalIgnoreCase) &&
                    Ps3XmbWindow.TryParseThemeColor(owner.Settings.xmbCustomColor, out selected))
                    return selected;
                if (String.Equals(mode, "Theme", StringComparison.OrdinalIgnoreCase))
                {
                    string themeColor = FindThemeColor();
                    if (Ps3XmbWindow.TryParseThemeColor(themeColor, out selected)) return selected;
                }
                Color[] colors = new Color[] {
                    Color.FromRgb(72, 84, 96), Color.FromRgb(91, 78, 103), Color.FromRgb(72, 84, 115),
                    Color.FromRgb(49, 94, 116), Color.FromRgb(48, 108, 101), Color.FromRgb(71, 117, 88),
                    Color.FromRgb(124, 112, 68), Color.FromRgb(115, 91, 73), Color.FromRgb(92, 79, 106),
                    Color.FromRgb(73, 88, 107), Color.FromRgb(67, 97, 102), Color.FromRgb(73, 82, 98)
                };
                DateTime now = DateTime.Now;
                int monthIndex = Math.Max(0, Math.Min(11, now.Month - 1));
                int nextMonth = (monthIndex + 1) % 12;
                double dayFraction = ((now.Day - 1) + now.TimeOfDay.TotalDays) /
                    Math.Max(1.0, DateTime.DaysInMonth(now.Year, now.Month));
                double seasonalBlend = dayFraction * dayFraction * (3.0 - (2.0 * dayFraction));
                Color seasonal = Blend(colors[monthIndex], colors[nextMonth], seasonalBlend);

                // The stock XMB changes tone with the clock as well as the month.
                // Keep the transition continuous so the background never jumps at
                // an hour or month boundary.
                double hour = now.TimeOfDay.TotalHours;
                double daylight = (Math.Cos(((hour - 14.0) / 24.0) * Math.PI * 2.0) + 1.0) * 0.5;
                double brightness = -0.18 + (daylight * 0.25);
                Color lit = AdjustBrightness(seasonal, brightness);
                double nightAmount = Math.Max(0.0, (0.44 - daylight) / 0.44) * 0.22;
                return Blend(lit, Color.FromRgb(34, 43, 69), nightAmount);
            }
        }

        private string FindThemeColor()
        {
            string[] roots = new string[] {
                owner.Settings.themeDirectory,
                owner.Settings.customAssetFolder,
                Path.Combine(owner.ThemeCacheRoot, "FirmwareAssets"),
                Path.Combine(owner.ThemeCacheRoot, "CustomAssets")
            };
            foreach (string root in roots)
            {
                if (String.IsNullOrWhiteSpace(root) || !Directory.Exists(root)) continue;
                foreach (string name in new string[] { "theme-color.txt", "color.txt", "accent.txt" })
                {
                    string path = Path.Combine(root, name);
                    try
                    {
                        if (File.Exists(path)) return File.ReadAllText(path).Trim();
                    }
                    catch { }
                }
            }
            return owner.Settings.xmbCustomColor;
        }

        private static Color Blend(Color left, Color right, double amount)
        {
            amount = Math.Max(0.0, Math.Min(1.0, amount));
            return Color.FromRgb(
                (byte)Math.Round(left.R + ((right.R - left.R) * amount)),
                (byte)Math.Round(left.G + ((right.G - left.G) * amount)),
                (byte)Math.Round(left.B + ((right.B - left.B) * amount)));
        }

        private static Color AdjustBrightness(Color color, double amount)
        {
            double scale = amount >= 0.0 ? 1.0 : 1.0 + amount;
            double addition = amount >= 0.0 ? 255.0 * amount : 0.0;
            return Color.FromRgb(
                (byte)Math.Max(0, Math.Min(255, Math.Round((color.R * scale) + addition))),
                (byte)Math.Max(0, Math.Min(255, Math.Round((color.G * scale) + addition))),
                (byte)Math.Max(0, Math.Min(255, Math.Round((color.B * scale) + addition))));
        }

        internal void Refresh()
        {
            manifest = null;
            categoryIcons.Clear();
            actionIcons.Clear();
            background = null;
            hasFirmwareTheme = false;
            typeface = new Typeface("Segoe UI");

            string directory = String.Empty;
            string source = owner.Settings.xmbAssetSource ?? "Firmware Assets";
            if (String.Equals(source, "Firmware Assets", StringComparison.OrdinalIgnoreCase))
            {
                directory = Path.Combine(owner.ThemeCacheRoot, "FirmwareAssets");
                if (!File.Exists(Path.Combine(directory, "theme-manifest.json"))) directory = String.Empty;
                hasFirmwareTheme = !String.IsNullOrWhiteSpace(directory);
            }
            else if (String.Equals(source, "Firmware Theme", StringComparison.OrdinalIgnoreCase))
            {
                directory = owner.Settings.themeDirectory;
                if (!File.Exists(Path.Combine(directory ?? String.Empty, "theme-manifest.json"))) directory = String.Empty;
                hasFirmwareTheme = !String.IsNullOrWhiteSpace(directory);
            }
            else if (String.Equals(source, "Installed .p3t Theme", StringComparison.OrdinalIgnoreCase)) directory = owner.Settings.themeDirectory;
            else if (String.Equals(source, "Custom Folder", StringComparison.OrdinalIgnoreCase))
            {
                directory = Path.Combine(owner.ThemeCacheRoot, "CustomAssets");
                if (!File.Exists(Path.Combine(directory, "theme-manifest.json"))) directory = String.Empty;
            }
            // Huymaier Default intentionally leaves the manifest empty and uses the safe wave/icon fallbacks.
            LoadManifest(directory);
            LoadFont();

            string backgroundPath = owner.Settings.backgroundImage;
            // Firmware Assets supplies the original icons/fonts/sounds while the
            // stock time-and-month color field remains active. Static backgrounds
            // are applied only for an explicitly installed/custom theme or a
            // user-selected background image.
            bool allowManifestBackground = !String.Equals(source, "Firmware Assets", StringComparison.OrdinalIgnoreCase);
            if (allowManifestBackground && String.IsNullOrWhiteSpace(backgroundPath) && manifest != null && manifest.Backgrounds != null && manifest.Backgrounds.Count > 0)
                backgroundPath = manifest.Backgrounds[0];
            background = owner.LoadImage(backgroundPath);
            MapIcons();
        }

        private string EnsureFirmwareTheme()
        {
            string destination = Path.Combine(owner.ThemeCacheRoot, "FirmwareOriginal");
            string source = owner.GetFirmwareThemeFile();
            if (String.IsNullOrWhiteSpace(source) || !File.Exists(source))
            {
                // Remove the v0.23.0 cache if it was generated from 01.p3t,
                // which is an optional art theme rather than the stock XMB.
                try { if (Directory.Exists(destination)) Directory.Delete(destination, true); } catch { }
                return String.Empty;
            }
            string manifestPath = Path.Combine(destination, "theme-manifest.json");
            string stampPath = Path.Combine(destination, "source-stamp.txt");
            FileInfo info = new FileInfo(source);
            string stamp = info.Length.ToString(CultureInfo.InvariantCulture) + "|" + info.LastWriteTimeUtc.Ticks.ToString(CultureInfo.InvariantCulture);
            string oldStamp = File.Exists(stampPath) ? File.ReadAllText(stampPath).Trim() : String.Empty;
            if (!File.Exists(manifestPath) || !String.Equals(stamp, oldStamp, StringComparison.Ordinal))
            {
                try
                {
                    if (Directory.Exists(destination)) Directory.Delete(destination, true);
                    Directory.CreateDirectory(destination);
                    P3TImporter.Import(source, destination);
                    File.WriteAllText(stampPath, stamp, Encoding.UTF8);
                }
                catch (Exception ex)
                {
                    owner.WriteLog("Original firmware theme import failed: " + ex, "WARN");
                    return String.Empty;
                }
            }
            hasFirmwareTheme = File.Exists(manifestPath);
            return hasFirmwareTheme ? destination : String.Empty;
        }

        private void LoadManifest(string directory)
        {
            if (String.IsNullOrWhiteSpace(directory)) return;
            string path = Path.Combine(directory, "theme-manifest.json");
            if (!File.Exists(path)) return;
            try
            {
                JavaScriptSerializer serializer = new JavaScriptSerializer();
                manifest = serializer.Deserialize<P3TImportResult>(File.ReadAllText(path, Encoding.UTF8));
            }
            catch (Exception ex) { owner.WriteLog("Theme manifest load failed: " + ex.Message, "WARN"); }
        }

        private void LoadFont()
        {
            if (!String.Equals(owner.Settings.xmbAssetSource, "Firmware Assets", StringComparison.OrdinalIgnoreCase) &&
                !String.Equals(owner.Settings.xmbAssetSource, "Firmware Theme", StringComparison.OrdinalIgnoreCase)) return;
            string directory = owner.GetFirmwareFontDirectory();
            if (String.IsNullOrWhiteSpace(directory)) return;
            try
            {
                Uri uri = new Uri(directory + Path.DirectorySeparatorChar, UriKind.Absolute);
                Collection<FontFamily> families = new Collection<FontFamily>();
                foreach (FontFamily family in Fonts.GetFontFamilies(uri)) families.Add(family);
                if (families.Count > 0) typeface = new Typeface(families[0], FontStyles.Normal, FontWeights.Normal, FontStretches.Normal);
            }
            catch { }
        }

        private void MapIcons()
        {
            if (manifest == null || manifest.Icons == null) return;
            foreach (KeyValuePair<string, string> pair in manifest.Icons)
            {
                string key = pair.Key.ToLowerInvariant();
                if (!categoryIcons.ContainsKey("Users") && (key.Contains("user") || key.Contains("login"))) categoryIcons["Users"] = pair.Value;
                if (!categoryIcons.ContainsKey("Settings") && (key.Contains("setting") || key.Contains("sysconf"))) categoryIcons["Settings"] = pair.Value;
                if (!categoryIcons.ContainsKey("Photo") && (key.Contains("photo") || key.Contains("picture"))) categoryIcons["Photo"] = pair.Value;
                if (!categoryIcons.ContainsKey("Music") && (key.Contains("music") || key.Contains("audio"))) categoryIcons["Music"] = pair.Value;
                if (!categoryIcons.ContainsKey("Video") && (key.Contains("video") || key.Contains("movie"))) categoryIcons["Video"] = pair.Value;
                if (!categoryIcons.ContainsKey("TV") && (key.Contains("tv") || key.Contains("channel"))) categoryIcons["TV"] = pair.Value;
                if (!categoryIcons.ContainsKey("Game") && (key.Contains("game") || key.Contains("disc"))) categoryIcons["Game"] = pair.Value;
                if (!categoryIcons.ContainsKey("Network") && (key.Contains("network") || key.Contains("browser"))) categoryIcons["Network"] = pair.Value;
                if (!categoryIcons.ContainsKey("PSN") && (key.Contains("psn") || key.Contains("playstation_network") || key.Contains("store"))) categoryIcons["PSN"] = pair.Value;
                if (!categoryIcons.ContainsKey("Friends") && (key.Contains("friend") || key.Contains("message"))) categoryIcons["Friends"] = pair.Value;
            }
        }

        internal string GetCategoryIcon(string id)
        {
            string value;
            return categoryIcons.TryGetValue(id, out value) ? value : String.Empty;
        }

        internal string GetItemIcon(XmbItem item)
        {
            if (item == null) return String.Empty;
            string key = item.Action == null ? String.Empty : item.Action;
            string value;
            if (actionIcons.TryGetValue(key, out value)) return value;
            if (manifest == null || manifest.Icons == null) return String.Empty;
            string[] terms;
            switch (key)
            {
                case "InstallFirmware": terms = new string[] { "update", "firmware" }; break;
                case "ChooseRpcs3": terms = new string[] { "application", "setting" }; break;
                case "InstallRpcs3": terms = new string[] { "download", "update" }; break;
                case "AddLibrary": terms = new string[] { "folder", "storage" }; break;
                case "Rescan": terms = new string[] { "search", "refresh" }; break;
                case "ImportTheme":
                case "OriginalTheme": terms = new string[] { "theme", "appearance" }; break;
                case "ChooseMusic": terms = new string[] { "music", "audio" }; break;
                default: terms = new string[] { "setting", "tool" }; break;
            }
            foreach (string term in terms)
            {
                foreach (KeyValuePair<string, string> pair in manifest.Icons)
                {
                    if (pair.Key.IndexOf(term, StringComparison.OrdinalIgnoreCase) >= 0)
                    {
                        actionIcons[key] = pair.Value;
                        return pair.Value;
                    }
                }
            }
            return String.Empty;
        }

        internal string FindSound(string name)
        {
            if (manifest == null || manifest.Sounds == null) return String.Empty;
            string[] terms;
            if (name == "move" || name == "category") terms = new string[] { "cursor", "move", "left", "right" };
            else if (name == "confirm") terms = new string[] { "decide", "confirm", "enter" };
            else if (name == "cancel") terms = new string[] { "cancel", "back" };
            else if (name == "notification") terms = new string[] { "notification", "trophy" };
            else terms = new string[] { name };
            foreach (string term in terms)
            {
                foreach (KeyValuePair<string, string> pair in manifest.Sounds)
                    if (pair.Key.IndexOf(term, StringComparison.OrdinalIgnoreCase) >= 0) return pair.Value;
            }
            return String.Empty;
        }
    }

    internal sealed class XmbAudio : IDisposable
    {
        private readonly Ps3XmbWindow owner;
        private readonly MediaPlayer intro;
        private readonly MediaPlayer music;
        private readonly MediaPlayer effect;
        private readonly Dictionary<string, string> effectPaths;
        private readonly System.Windows.Threading.DispatcherTimer fadeTimer;
        private DateTime fadeStartedUtc;
        private double fadeTargetVolume;
        private bool introActive;
        private bool usingIncludedLoop;
        private bool disposed;

        internal XmbAudio(Ps3XmbWindow owner)
        {
            this.owner = owner;
            intro = new MediaPlayer();
            music = new MediaPlayer();
            effect = new MediaPlayer();
            effectPaths = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            intro.MediaEnded += IntroEnded;
            intro.MediaFailed += delegate { IntroEnded(null, EventArgs.Empty); };
            music.MediaEnded += MusicEnded;
            fadeTimer = new System.Windows.Threading.DispatcherTimer(
                System.Windows.Threading.DispatcherPriority.Background, owner.Dispatcher);
            fadeTimer.Interval = TimeSpan.FromMilliseconds(40);
            fadeTimer.Tick += FadeTick;
        }

        internal void Refresh()
        {
            effectPaths.Clear();
            SetEffect("move", owner.Settings.sounds.move);
            SetEffect("confirm", owner.Settings.sounds.confirm);
            SetEffect("cancel", owner.Settings.sounds.cancel);
            SetEffect("category", owner.Settings.sounds.category);
            SetEffect("launch", owner.Settings.sounds.launch);
            SetEffect("return", owner.Settings.sounds.returnSound);
            StopMusicPlayers();
            if (!owner.Settings.musicEnabled) return;
            try
            {
                if (!String.IsNullOrWhiteSpace(owner.Settings.backgroundMusic) && File.Exists(owner.Settings.backgroundMusic))
                {
                    usingIncludedLoop = false;
                    introActive = false;
                    music.Open(new Uri(owner.Settings.backgroundMusic, UriKind.Absolute));
                    music.Volume = Clamp(owner.Settings.musicVolume);
                    music.Play();
                    return;
                }

                // v0.25.0: the supplied PS3 startup video owns startup audio.
                // Begin the normal XMB ambience directly after the video rather than
                // layering the legacy PS3HomeIntro clip over it.
                string loopPath = owner.GetIncludedMusicPath("PS3HomeAmbienceLoop.mp3");
                usingIncludedLoop = File.Exists(loopPath);
                introActive = false;
                PlayIncludedLoop(false);
            }
            catch { PlayIncludedLoop(false); }
        }

        private void StopMusicPlayers()
        {
            fadeTimer.Stop();
            introActive = false;
            usingIncludedLoop = false;
            try { intro.Stop(); intro.Close(); } catch { }
            try { music.Stop(); music.Close(); } catch { }
        }

        private void SetEffect(string name, string path)
        {
            if (String.IsNullOrWhiteSpace(path) || !File.Exists(path)) path = owner.Theme.FindSound(name);
            if (!String.IsNullOrWhiteSpace(path) && File.Exists(path)) effectPaths[name] = path;
        }

        internal void Play(string name)
        {
            if (disposed || !owner.Settings.soundEnabled) return;
            string path;
            if (!effectPaths.TryGetValue(name, out path) || !File.Exists(path)) return;
            try
            {
                effect.Stop();
                effect.Close();
                effect.Open(new Uri(path, UriKind.Absolute));
                effect.Volume = Clamp(owner.Settings.soundVolume);
                effect.Play();
            }
            catch { }
        }

        internal void PauseMusic()
        {
            try { if (introActive) intro.Pause(); else music.Pause(); } catch { }
        }

        internal void ResumeMusic()
        {
            try
            {
                if (!owner.Settings.musicEnabled) return;
                if (introActive) intro.Play(); else music.Play();
            }
            catch { }
        }

        private void IntroEnded(object sender, EventArgs e)
        {
            try { intro.Stop(); intro.Close(); } catch { }
            introActive = false;
            PlayIncludedLoop(true);
        }

        private void PlayIncludedLoop(bool fadeIn)
        {
            if (disposed || !owner.Settings.musicEnabled) return;
            string path = owner.GetIncludedMusicPath("PS3HomeAmbienceLoop.mp3");
            if (!File.Exists(path)) return;
            try
            {
                music.Stop();
                music.Close();
                music.Open(new Uri(path, UriKind.Absolute));
                fadeTargetVolume = Clamp(owner.Settings.musicVolume);
                music.Volume = fadeIn ? 0.0 : fadeTargetVolume;
                music.Play();
                usingIncludedLoop = true;
                if (fadeIn)
                {
                    fadeStartedUtc = DateTime.UtcNow;
                    fadeTimer.Start();
                }
            }
            catch { }
        }

        private void FadeTick(object sender, EventArgs e)
        {
            double progress = Math.Max(0.0, Math.Min(1.0, (DateTime.UtcNow - fadeStartedUtc).TotalSeconds / 2.8));
            double smooth = progress * progress * (3.0 - 2.0 * progress);
            try { music.Volume = fadeTargetVolume * smooth; } catch { }
            if (progress >= 1.0) fadeTimer.Stop();
        }

        private void MusicEnded(object sender, EventArgs e)
        {
            if (!usingIncludedLoop && !owner.Settings.musicLoop) return;
            try { music.Position = TimeSpan.Zero; music.Play(); } catch { }
        }

        public void Dispose()
        {
            if (disposed) return;
            disposed = true;
            fadeTimer.Stop();
            try { intro.Stop(); intro.Close(); } catch { }
            try { music.Stop(); music.Close(); } catch { }
            try { effect.Stop(); effect.Close(); } catch { }
        }

        private static double Clamp(double value) { return Math.Max(0, Math.Min(1, value)); }
    }

    internal enum XmbInputCommand
    {
        None, Left, Right, Up, Down, Confirm, Back, Secondary, Tertiary, Guide, Menu, View, Options, LeftShoulder, RightShoulder
    }

    internal sealed class XmbInputRouter
    {
        private readonly Dictionary<InputSourceIdentity, int> neutralFrames;
        private readonly List<InputCandidate> candidates;
        private readonly HuymaierConsole.Native.HidNavigationSnapshot[] sonySnapshots;
        private readonly XInputNavigationSnapshot[] xinputSnapshots;
        private InputSourceIdentity activeSource;
        private bool hasActiveSource;
        private int lastButtons;
        private string lastDirection;
        private DateTime nextRepeatUtc;

        internal XmbInputRouter()
        {
            neutralFrames = new Dictionary<InputSourceIdentity, int>();
            candidates = new List<InputCandidate>(12);
            sonySnapshots = new HuymaierConsole.Native.HidNavigationSnapshot[8];
            xinputSnapshots = new XInputNavigationSnapshot[4];
            XInputBridge.EnsureStarted();
            activeSource = new InputSourceIdentity();
            hasActiveSource = false;
            ResetEdges();
        }

        internal string ActiveSourceKey
        {
            get
            {
                if (!hasActiveSource) return String.Empty;
                return activeSource.Type == 0
                    ? "sony:" + activeSource.Id.ToString(CultureInfo.InvariantCulture)
                    : "xinput:" + activeSource.Id.ToString(CultureInfo.InvariantCulture);
            }
        }

        internal void Reset()
        {
            activeSource = new InputSourceIdentity();
            hasActiveSource = false;
            neutralFrames.Clear();
            ResetEdges();
        }

        internal void ResetEdges()
        {
            lastButtons = 0;
            lastDirection = String.Empty;
            nextRepeatUtc = DateTime.MinValue;
        }

        internal XmbInputCommand Poll()
        {
            // The process-wide Game Bar is modal. Native console surfaces must
            // not react to the same D-pad/face/shoulder press underneath it.
            if (HuymaierGameBarHost.BlocksNativeNavigation)
            {
                hasActiveSource = false;
                ResetEdges();
                return XmbInputCommand.None;
            }
            GetCandidates();
            DateTime now = DateTime.UtcNow;
            foreach (InputCandidate candidate in candidates)
            {
                int count;
                neutralFrames.TryGetValue(candidate.Source, out count);
                if (candidate.Neutral) neutralFrames[candidate.Source] = Math.Min(12, count + 1);
                else if (!candidate.Activity) neutralFrames[candidate.Source] = count;
            }

            InputCandidate active = new InputCandidate();
            bool foundActive = false;
            if (hasActiveSource)
            {
                for (int index = 0; index < candidates.Count; index++)
                {
                    if (!candidates[index].Source.Equals(activeSource)) continue;
                    active = candidates[index];
                    foundActive = true;
                    break;
                }
            }

            if (!foundActive)
            {
                hasActiveSource = false;
                ResetEdges();
                if (ChooseNewSource(out active))
                {
                    activeSource = active.Source;
                    hasActiveSource = true;
                }
                else return XmbInputCommand.None;
            }

            // Keep ownership with the same physical source until it disconnects.
            // A DualSense can also appear through Steam Input/XInput; switching
            // between those duplicate paths while idle makes navigation feel uneven.
            int newButtons = active.Buttons & ~lastButtons;
            lastButtons = active.Buttons;
            if ((newButtons & 1) != 0) return XmbInputCommand.Confirm;
            if ((newButtons & 2) != 0) return XmbInputCommand.Back;
            if ((newButtons & 64) != 0) return XmbInputCommand.Secondary;
            if ((newButtons & 128) != 0) return XmbInputCommand.Tertiary;
            if ((newButtons & 4) != 0) return XmbInputCommand.Guide;
            if ((newButtons & 32) != 0) return XmbInputCommand.Menu;
            if ((newButtons & 256) != 0) return XmbInputCommand.View;
            if ((newButtons & 8) != 0) return XmbInputCommand.LeftShoulder;
            if ((newButtons & 16) != 0) return XmbInputCommand.RightShoulder;

            string direction = active.Direction == null ? String.Empty : active.Direction;
            if (String.IsNullOrWhiteSpace(direction))
            {
                lastDirection = String.Empty;
                nextRepeatUtc = DateTime.MinValue;
                return XmbInputCommand.None;
            }
            if (!String.Equals(direction, lastDirection, StringComparison.Ordinal))
            {
                lastDirection = direction;
                nextRepeatUtc = now.AddMilliseconds(250);
                return ParseDirection(direction);
            }
            if (now >= nextRepeatUtc)
            {
                nextRepeatUtc = now.AddMilliseconds(75);
                return ParseDirection(direction);
            }
            return XmbInputCommand.None;
        }

        private bool ChooseNewSource(out InputCandidate selected)
        {
            selected = new InputCandidate();
            int bestPriority = Int32.MaxValue;
            bool found = false;
            for (int index = 0; index < candidates.Count; index++)
            {
                InputCandidate candidate = candidates[index];
                int neutral;
                neutralFrames.TryGetValue(candidate.Source, out neutral);
                if (!candidate.Activity || candidate.Priority >= bestPriority) continue;
                if (candidate.Source.Type == 1 && candidate.Buttons == 0 && neutral < 1) continue;
                selected = candidate;
                bestPriority = candidate.Priority;
                found = true;
            }
            return found;
        }

        private static XmbInputCommand ParseDirection(string direction)
        {
            if (direction == "Left") return XmbInputCommand.Left;
            if (direction == "Right") return XmbInputCommand.Right;
            if (direction == "Up") return XmbInputCommand.Up;
            if (direction == "Down") return XmbInputCommand.Down;
            return XmbInputCommand.None;
        }

        private void GetCandidates()
        {
            candidates.Clear();
            bool systemGuideOwned = HuymaierSystemButtonBridge.IsAvailable;
            try
            {
                int count = HuymaierConsole.Native.RawHidController.CopyNavigationSnapshots(sonySnapshots);
                for (int snapshotIndex = 0; snapshotIndex < count; snapshotIndex++)
                {
                    HuymaierConsole.Native.HidNavigationSnapshot snapshot = sonySnapshots[snapshotIndex];
                    if ((DateTime.UtcNow - snapshot.LastSeenUtc).TotalSeconds > 3) continue;
                    int buttons = 0;
                    if ((snapshot.Mask & 4) != 0) buttons |= 1;
                    if ((snapshot.Mask & 8) != 0) buttons |= 2;
                    // Raw HID distinguishes Options (mask 1) from PS/Guide (mask 2).
                    // PS/Guide globally requests Huymaier Quick Access; Options stays local.
                    if ((snapshot.Mask & 2) != 0 && !systemGuideOwned) buttons |= 4;
                    if ((snapshot.Mask & 1) != 0) buttons |= 32;
                    if ((snapshot.Mask & 16) != 0) buttons |= 64;
                    if ((snapshot.Mask & 32) != 0) buttons |= 128;
                    if ((snapshot.Mask & 1024) != 0) buttons |= 8;
                    if ((snapshot.Mask & 2048) != 0) buttons |= 16;
                    string direction = snapshot.Direction == null ? String.Empty : snapshot.Direction;
                    candidates.Add(new InputCandidate(new InputSourceIdentity(0, snapshot.DeviceHandle), 1, buttons, direction,
                        buttons != 0 || !String.IsNullOrWhiteSpace(direction), buttons == 0 && String.IsNullOrWhiteSpace(direction)));
                }
            }
            catch { }

            int xinputCount = XInputBridge.CopyNavigationSnapshots(xinputSnapshots);
            for (int index = 0; index < xinputCount; index++)
            {
                XInputNavigationSnapshot snapshot = xinputSnapshots[index];
                if (!snapshot.Connected) continue;
                int candidateButtons = snapshot.Buttons;
                if (systemGuideOwned) candidateButtons &= ~4;
                bool activity = candidateButtons != 0 || !String.IsNullOrWhiteSpace(snapshot.Direction);
                candidates.Add(new InputCandidate(new InputSourceIdentity(1, snapshot.Index), 0,
                    candidateButtons, snapshot.Direction, activity, !activity));
            }

            // Generic DirectInput navigation is intentionally disabled. Gaming mice and
            // duplicate virtual HID devices can expose permanently tilted joystick axes.
        }
    }

    public sealed class NativeNavigationCommand
    {
        public string Command { get; set; }
        public string Family { get; set; }
        public string Name { get; set; }
        public bool Active { get; set; }

        public NativeNavigationCommand()
        {
            Command = String.Empty;
            Family = "Keyboard";
            Name = "Keyboard / Mouse";
        }
    }

    public static class NativeConsoleNavigation
    {
        private static readonly object Sync = new object();
        private static XmbInputRouter router = new XmbInputRouter();
        private static DateTime deviceChangeQuietUntilUtc = DateTime.MinValue;
        private static bool deviceChangeResetPending;

        public static NativeNavigationCommand Poll()
        {
            lock (Sync)
            {
                if (HuymaierGameBarHost.BlocksNativeNavigation)
                    return new NativeNavigationCommand();
                DateTime now = DateTime.UtcNow;
                if (now < deviceChangeQuietUntilUtc)
                    return new NativeNavigationCommand();
                if (deviceChangeResetPending)
                {
                    router = new XmbInputRouter();
                    deviceChangeResetPending = false;
                }
                if (HuymaierSystemButtonBridge.ConsumeGuidePress())
                {
                    string systemSource = router.ActiveSourceKey ?? String.Empty;
                    return new NativeNavigationCommand {
                        Command = "Guide",
                        Active = true,
                        Family = systemSource.StartsWith("sony:", StringComparison.OrdinalIgnoreCase) ? "PlayStation" : "Xbox",
                        Name = systemSource.StartsWith("sony:", StringComparison.OrdinalIgnoreCase) ? "PlayStation Guide Button" : "Xbox Guide Button"
                    };
                }
                XmbInputCommand command = router.Poll();
                string source = router.ActiveSourceKey == null ? String.Empty : router.ActiveSourceKey;
                NativeNavigationCommand result = new NativeNavigationCommand();
                result.Command = command == XmbInputCommand.None ? String.Empty : command.ToString();
                result.Active = !String.IsNullOrWhiteSpace(source);
                if (source.StartsWith("sony:", StringComparison.OrdinalIgnoreCase))
                {
                    result.Family = "PlayStation";
                    result.Name = "DualSense / DualShock Controller";
                }
                else if (source.StartsWith("xinput:", StringComparison.OrdinalIgnoreCase))
                {
                    result.Family = "Xbox";
                    result.Name = "XInput Controller";
                }
                else if (source.StartsWith("legacy:", StringComparison.OrdinalIgnoreCase))
                {
                    result.Family = "Gamepad";
                    result.Name = "DirectInput Controller";
                }
                return result;
            }
        }

        public static bool ConsumeGuideOnly()
        {
            lock (Sync)
            {
                DateTime now = DateTime.UtcNow;
                if (now < deviceChangeQuietUntilUtc) return false;

                // Primary low-level system-button backend.
                if (HuymaierSystemButtonBridge.ConsumeGuidePress()) return true;

                // Compatibility fallbacks are deliberately Guide-only. They do
                // not call router.Poll() and therefore cannot clear or steal any
                // D-pad/A/B/shoulder/direction edge from the foreground owner.
                if (XInputBridge.ConsumeGuideEdge()) return true;
                try
                {
                    if (HuymaierConsole.Native.RawHidController.ConsumeGuideEdge()) return true;
                }
                catch { }
                return false;
            }
        }

        public static void NotifyDeviceChange()
        {
            lock (Sync)
            {
                // Windows emits a burst of arrival/removal notifications for one
                // physical hot-plug.  Quiesce input first and rebuild once after
                // the burst instead of replacing a router while it is polling.
                deviceChangeQuietUntilUtc = DateTime.UtcNow.AddMilliseconds(750);
                deviceChangeResetPending = true;
            }
        }

        public static void Reset()
        {
            lock (Sync)
            {
                router = new XmbInputRouter();
                deviceChangeResetPending = false;
                deviceChangeQuietUntilUtc = DateTime.UtcNow.AddMilliseconds(300);
            }
        }

        public static void Shutdown()
        {
            lock (Sync)
            {
                router.Reset();
                HuymaierSystemButtonBridge.Shutdown();
            }
        }
    }

    internal struct InputSourceIdentity : IEquatable<InputSourceIdentity>
    {
        internal readonly int Type;
        internal readonly long Id;

        internal InputSourceIdentity(int type, long id)
        {
            Type = type;
            Id = id;
        }

        public bool Equals(InputSourceIdentity other) { return Type == other.Type && Id == other.Id; }
        public override bool Equals(object value) { return value is InputSourceIdentity && Equals((InputSourceIdentity)value); }
        public override int GetHashCode() { unchecked { return (Type * 397) ^ Id.GetHashCode(); } }
    }

    internal struct InputCandidate
    {
        internal readonly InputSourceIdentity Source;
        internal readonly int Priority;
        internal readonly int Buttons;
        internal readonly string Direction;
        internal readonly bool Activity;
        internal readonly bool Neutral;

        internal InputCandidate(InputSourceIdentity source, int priority, int buttons, string direction, bool activity, bool neutral)
        {
            Source = source;
            Priority = priority;
            Buttons = buttons;
            Direction = direction;
            Activity = activity;
            Neutral = neutral;
        }
    }

    [StructLayout(LayoutKind.Sequential)]
    internal struct XInputGamepad
    {
        internal ushort Buttons;
        internal byte LeftTrigger;
        internal byte RightTrigger;
        internal short LeftThumbX;
        internal short LeftThumbY;
        internal short RightThumbX;
        internal short RightThumbY;
    }

    [StructLayout(LayoutKind.Sequential)]
    internal struct XInputState
    {
        internal uint PacketNumber;
        internal XInputGamepad Gamepad;
    }

    internal struct XInputNavigationSnapshot
    {
        internal int Index;
        internal int Buttons;
        internal string Direction;
        internal bool Connected;
    }

    internal static class XInputBridge
    {
        private sealed class Sample
        {
            internal bool Connected;
            internal int CurrentButtons;
            internal int PendingButtons;
            internal string CurrentDirection = String.Empty;
            internal string PendingDirection = String.Empty;
        }

        [DllImport("xinput1_4.dll", EntryPoint = "XInputGetState")]
        private static extern uint XInputGetState14(uint userIndex, out XInputState state);
        [DllImport("xinput9_1_0.dll", EntryPoint = "XInputGetState")]
        private static extern uint XInputGetState910(uint userIndex, out XInputState state);

        private static readonly object Sync = new object();
        private static readonly Sample[] Samples = new Sample[] { new Sample(), new Sample(), new Sample(), new Sample() };
        private static bool started;

        internal static void EnsureStarted()
        {
            lock (Sync)
            {
                if (started) return;
                started = true;
                Thread thread = new Thread(SampleLoop);
                thread.IsBackground = true;
                thread.Name = "Huymaier XInput Sampler";
                thread.Start();
            }
        }

        internal static bool ConsumeGuideEdge()
        {
            EnsureStarted();
            lock (Sync)
            {
                for (int index = 0; index < Samples.Length; index++)
                {
                    Sample sample = Samples[index];
                    if (!sample.Connected || (sample.PendingButtons & 4) == 0) continue;
                    sample.PendingButtons &= ~4;
                    return true;
                }
                return false;
            }
        }

        internal static int CopyNavigationSnapshots(XInputNavigationSnapshot[] destination)
        {
            if (destination == null || destination.Length == 0) return 0;
            EnsureStarted();
            lock (Sync)
            {
                int count = Math.Min(destination.Length, Samples.Length);
                for (int index = 0; index < count; index++)
                {
                    Sample sample = Samples[index];
                    destination[index] = new XInputNavigationSnapshot {
                        Index = index,
                        Connected = sample.Connected,
                        Buttons = sample.CurrentButtons | sample.PendingButtons,
                        Direction = !String.IsNullOrWhiteSpace(sample.PendingDirection) ? sample.PendingDirection : sample.CurrentDirection
                    };
                    sample.PendingButtons = 0;
                    sample.PendingDirection = String.Empty;
                }
                return count;
            }
        }

        private static void SampleLoop()
        {
            while (true)
            {
                for (int index = 0; index < Samples.Length; index++)
                {
                    XInputState state;
                    bool connected = TryGetStateDirect(index, out state);
                    int buttons = 0;
                    string direction = String.Empty;
                    if (connected)
                    {
                        ushort mask = state.Gamepad.Buttons;
                        if ((mask & 0x1000) != 0) buttons |= 1;
                        if ((mask & 0x2000) != 0) buttons |= 2;
                        // Guide is distinct from Start/Menu and Back/View. GameInput owns the
                        // primary system-button path; 0x0400 remains compatibility fallback only.
                        if ((mask & 0x0400) != 0) buttons |= 4;
                        if ((mask & 0x0010) != 0) buttons |= 32;
                        if ((mask & 0x0020) != 0) buttons |= 256;
                        if ((mask & 0x4000) != 0) buttons |= 64;
                        if ((mask & 0x8000) != 0) buttons |= 128;
                        if ((mask & 0x0100) != 0) buttons |= 8;
                        if ((mask & 0x0200) != 0) buttons |= 16;
                        if ((mask & 0x0004) != 0 || state.Gamepad.LeftThumbX < -15000) direction = "Left";
                        else if ((mask & 0x0008) != 0 || state.Gamepad.LeftThumbX > 15000) direction = "Right";
                        else if ((mask & 0x0001) != 0 || state.Gamepad.LeftThumbY > 15000) direction = "Up";
                        else if ((mask & 0x0002) != 0 || state.Gamepad.LeftThumbY < -15000) direction = "Down";
                    }
                    lock (Sync)
                    {
                        Sample sample = Samples[index];
                        if (!connected)
                        {
                            sample.Connected = false;
                            sample.CurrentButtons = 0;
                            sample.PendingButtons = 0;
                            sample.CurrentDirection = String.Empty;
                            sample.PendingDirection = String.Empty;
                            continue;
                        }
                        sample.Connected = true;
                        sample.PendingButtons |= buttons & ~sample.CurrentButtons;
                        if (!String.IsNullOrWhiteSpace(direction) && !String.Equals(direction, sample.CurrentDirection, StringComparison.Ordinal) && String.IsNullOrWhiteSpace(sample.PendingDirection))
                            sample.PendingDirection = direction;
                        sample.CurrentButtons = buttons;
                        sample.CurrentDirection = direction;
                    }
                }
                Thread.Sleep(4);
            }
        }

        private static bool TryGetStateDirect(int index, out XInputState state)
        {
            state = new XInputState();
            try { return XInputGetState14((uint)index, out state) == 0; }
            catch (DllNotFoundException)
            {
                try { return XInputGetState910((uint)index, out state) == 0; } catch { return false; }
            }
            catch (EntryPointNotFoundException)
            {
                try { return XInputGetState910((uint)index, out state) == 0; } catch { return false; }
            }
            catch { return false; }
        }
    }

    internal sealed class XmbCategory
    {
        internal string Id;
        internal string Title;
        internal List<XmbItem> Items;
        internal int SelectedIndex;

        internal XmbCategory(string id, string title)
        {
            Id = id;
            Title = title;
            Items = new List<XmbItem>();
            SelectedIndex = 0;
        }
    }

    internal sealed class XmbItem
    {
        internal string Title;
        internal string Subtitle;
        internal string Action;
        internal string IconPath;
        internal string HeroPath;
        internal List<XmbItem> Children;
        internal Ps3Game Game;

        internal XmbItem(string title, string subtitle, string action)
        {
            Title = title;
            Subtitle = subtitle;
            Action = action;
            IconPath = String.Empty;
            HeroPath = String.Empty;
        }

        internal XmbItem(string title, string subtitle, string action, List<XmbItem> children)
            : this(title, subtitle, action)
        {
            Children = children;
        }
    }

    internal sealed class XmbMenuContext
    {
        internal readonly string Title;
        internal readonly List<XmbItem> Items;
        internal readonly int ParentSelection;

        internal XmbMenuContext(string title, List<XmbItem> items, int parentSelection)
        {
            Title = title;
            Items = items;
            ParentSelection = parentSelection;
        }
    }

    internal sealed class Rpcs3YamlAdapter
    {
        private readonly Func<string> dataRootProvider;
        private readonly Action<string, string> log;
        private readonly object sync = new object();

        internal Rpcs3YamlAdapter(Func<string> dataRootProvider, Action<string, string> log)
        {
            this.dataRootProvider = dataRootProvider;
            this.log = log;
        }

        internal string GetValue(bool perGame, string titleId, string section, string key, string defaultValue)
        {
            try
            {
                string path = GetPath(perGame, titleId);
                if (!File.Exists(path)) return defaultValue;
                string currentSection = String.Empty;
                foreach (string raw in File.ReadAllLines(path, Encoding.UTF8))
                {
                    string line = raw.TrimEnd();
                    if (line.Length == 0 || line.TrimStart().StartsWith("#", StringComparison.Ordinal)) continue;
                    int indent = raw.Length - raw.TrimStart().Length;
                    if (indent == 0 && line.EndsWith(":", StringComparison.Ordinal)) { currentSection = line.Substring(0, line.Length - 1).Trim(); continue; }
                    if (indent > 0 && String.Equals(currentSection, section, StringComparison.OrdinalIgnoreCase))
                    {
                        int colon = line.IndexOf(':');
                        if (colon > 0 && String.Equals(line.Substring(0, colon).Trim(), key, StringComparison.OrdinalIgnoreCase))
                            return Unquote(line.Substring(colon + 1).Trim());
                    }
                }
            }
            catch { }
            return defaultValue;
        }

        internal void SetValue(bool perGame, string titleId, string section, string key, string value)
        {
            lock (sync)
            {
                string path = GetPath(perGame, titleId);
                Directory.CreateDirectory(Path.GetDirectoryName(path));
                List<string> lines = File.Exists(path) ? File.ReadAllLines(path, Encoding.UTF8).ToList() : new List<string>();
                Backup(path);
                int sectionStart = -1, sectionEnd = lines.Count, keyIndex = -1;
                for (int i = 0; i < lines.Count; i++)
                {
                    string trimmed = lines[i].Trim();
                    int indent = lines[i].Length - lines[i].TrimStart().Length;
                    if (indent == 0 && trimmed.EndsWith(":", StringComparison.Ordinal))
                    {
                        if (sectionStart >= 0) { sectionEnd = i; break; }
                        if (String.Equals(trimmed.Substring(0, trimmed.Length - 1), section, StringComparison.OrdinalIgnoreCase)) sectionStart = i;
                    }
                }
                if (sectionStart >= 0)
                {
                    for (int i = sectionStart + 1; i < sectionEnd; i++)
                    {
                        string trimmed = lines[i].Trim();
                        int colon = trimmed.IndexOf(':');
                        if (colon > 0 && String.Equals(trimmed.Substring(0, colon).Trim(), key, StringComparison.OrdinalIgnoreCase)) { keyIndex = i; break; }
                    }
                }
                string yamlValue = QuoteIfNeeded(value);
                if (sectionStart < 0)
                {
                    if (lines.Count > 0 && lines[lines.Count - 1].Length > 0) lines.Add(String.Empty);
                    lines.Add(section + ":");
                    lines.Add("  " + key + ": " + yamlValue);
                }
                else if (keyIndex >= 0) lines[keyIndex] = "  " + key + ": " + yamlValue;
                else lines.Insert(sectionEnd, "  " + key + ": " + yamlValue);
                string temp = path + ".huymaier.tmp";
                File.WriteAllLines(temp, lines.ToArray(), new UTF8Encoding(false));
                if (File.Exists(path)) File.Delete(path);
                File.Move(temp, path);
                if (log != null) log("RPCS3 setting updated: " + (perGame ? titleId + " / " : String.Empty) + section + " / " + key + " = " + value, "INFO");
            }
        }

        private string GetPath(bool perGame, string titleId)
        {
            string root = dataRootProvider == null ? String.Empty : dataRootProvider();
            if (String.IsNullOrWhiteSpace(root)) throw new InvalidOperationException("RPCS3 data location is not configured.");
            if (!perGame) return Path.Combine(root, "config.yml");
            if (String.IsNullOrWhiteSpace(titleId)) throw new InvalidOperationException("A title ID is required for per-game settings.");
            return Path.Combine(root, "custom_configs", "config_" + titleId + ".yml");
        }

        private void Backup(string path)
        {
            if (!File.Exists(path)) return;
            string root = Path.Combine(Path.GetDirectoryName(path), ".huymaier-backups");
            Directory.CreateDirectory(root);
            string target = Path.Combine(root, Path.GetFileName(path) + "." + DateTime.Now.ToString("yyyyMMdd-HHmmss-fff") + ".bak");
            File.Copy(path, target, true);
        }

        private static string Unquote(string value)
        {
            if (value.Length >= 2 && ((value[0] == '"' && value[value.Length - 1] == '"') || (value[0] == '\'' && value[value.Length - 1] == '\''))) return value.Substring(1, value.Length - 2);
            return value;
        }

        private static string QuoteIfNeeded(string value)
        {
            if (value == null) return "\"\"";
            if (value == "true" || value == "false") return value;
            int numeric;
            if (Int32.TryParse(value, NumberStyles.Integer, CultureInfo.InvariantCulture, out numeric)) return value;
            if (value.IndexOf(':') >= 0 || value.IndexOf('#') >= 0 || value.IndexOf(' ') >= 0) return "\"" + value.Replace("\\", "\\\\").Replace("\"", "\\\"") + "\"";
            return value;
        }
    }

    internal sealed class TrophySet
    {
        internal string Name = String.Empty;
        internal string IconPath = String.Empty;
        internal List<TrophyEntry> Trophies = new List<TrophyEntry>();
        internal int Total { get { return Trophies.Count; } }
        internal int Unlocked { get { return Trophies.Count(delegate(TrophyEntry value) { return value.Unlocked; }); } }
        internal int Percent { get { return Total == 0 ? 0 : (int)Math.Round(Unlocked * 100.0 / Total); } }
    }

    internal sealed class TrophyEntry
    {
        internal int Id;
        internal string Name = String.Empty;
        internal string Description = String.Empty;
        internal string Grade = "Bronze";
        internal string IconPath = String.Empty;
        internal bool Hidden;
        internal bool Unlocked;
        internal string Timestamp = String.Empty;
    }

    internal static class TrophyScanner
    {
        internal static List<TrophySet> Scan(string dataRoot, string activeUserId, Action<string, string> log)
        {
            List<TrophySet> result = new List<TrophySet>();
            if (String.IsNullOrWhiteSpace(dataRoot)) return result;
            string home = Path.Combine(dataRoot, "dev_hdd0", "home");
            if (!Directory.Exists(home)) return result;
            string user = Path.Combine(home, String.IsNullOrWhiteSpace(activeUserId) ? "00000001" : activeUserId);
            if (!Directory.Exists(user)) return result;
            int folders = 0;
            string trophyRoot = Path.Combine(user, "trophy");
            foreach (string folder in SafeDirectories(trophyRoot))
            {
                if (++folders > 512) return result;
                string config = Path.Combine(folder, "TROPCONF.SFM");
                if (!File.Exists(config)) continue;
                try
                {
                    TrophySet set = ParseSet(folder, config);
                    if (set.Trophies.Count > 0) result.Add(set);
                }
                catch (Exception ex) { if (log != null) log("Trophy set skipped: " + folder + " — " + ex.Message, "WARN"); }
            }
            return result.OrderBy(delegate(TrophySet value) { return value.Name; }, StringComparer.CurrentCultureIgnoreCase).ToList();
        }

        private static TrophySet ParseSet(string folder, string config)
        {
            XmlDocument document = new XmlDocument();
            document.Load(config);
            TrophySet set = new TrophySet();
            XmlNode title = document.SelectSingleNode("//*[local-name()='title-name']");
            set.Name = title == null ? Path.GetFileName(folder) : title.InnerText.Trim();
            string gameIcon = Path.Combine(folder, "ICON0.PNG");
            set.IconPath = File.Exists(gameIcon) ? gameIcon : String.Empty;
            Dictionary<int, DateTime> unlocked = TropUsrReader.Read(Path.Combine(folder, "TROPUSR.DAT"));
            XmlNodeList nodes = document.SelectNodes("//*[local-name()='trophy']");
            foreach (XmlNode node in nodes)
            {
                TrophyEntry entry = new TrophyEntry();
                entry.Id = ParseInt(Attribute(node, "id"), set.Trophies.Count);
                entry.Hidden = Attribute(node, "hidden") == "yes" || Attribute(node, "hidden") == "1";
                string type = Attribute(node, "ttype").ToUpperInvariant();
                entry.Grade = type == "P" ? "Platinum" : type == "G" ? "Gold" : type == "S" ? "Silver" : "Bronze";
                XmlNode name = node.SelectSingleNode("./*[local-name()='name']");
                XmlNode detail = node.SelectSingleNode("./*[local-name()='detail']");
                entry.Name = name == null ? "Trophy " + entry.Id.ToString(CultureInfo.InvariantCulture) : name.InnerText.Trim();
                entry.Description = detail == null ? String.Empty : detail.InnerText.Trim();
                string icon = Path.Combine(folder, "TROP" + entry.Id.ToString("000", CultureInfo.InvariantCulture) + ".PNG");
                entry.IconPath = File.Exists(icon) ? icon : String.Empty;
                DateTime when;
                entry.Unlocked = unlocked.TryGetValue(entry.Id, out when);
                if (entry.Unlocked && when.Year > 2000) entry.Timestamp = when.ToString("g", CultureInfo.CurrentCulture);
                set.Trophies.Add(entry);
            }
            return set;
        }

        private static string Attribute(XmlNode node, string name)
        {
            if (node == null || node.Attributes == null || node.Attributes[name] == null) return String.Empty;
            return node.Attributes[name].Value ?? String.Empty;
        }

        private static int ParseInt(string value, int fallback)
        {
            int parsed;
            return Int32.TryParse(value, NumberStyles.Integer, CultureInfo.InvariantCulture, out parsed) ? parsed : fallback;
        }

        private static IEnumerable<string> SafeDirectories(string path)
        {
            try { return Directory.Exists(path) ? Directory.EnumerateDirectories(path).Take(1024).ToArray() : new string[0]; }
            catch { return new string[0]; }
        }
    }

    internal static class TropUsrReader
    {
        internal static Dictionary<int, DateTime> Read(string path)
        {
            Dictionary<int, DateTime> result = new Dictionary<int, DateTime>();
            if (!File.Exists(path)) return result;
            byte[] data;
            try { data = File.ReadAllBytes(path); } catch { return result; }
            if (data.Length < 64) return result;
            int records = (int)ReadU32(data, 8);
            if (records < 1 || records > 128) return result;
            int tableOffset = 48;
            long timeOffset = -1;
            for (int i = 0; i < records; i++)
            {
                int p = tableOffset + i * 32;
                if (p + 24 > data.Length) break;
                uint id = ReadU32(data, p);
                long offset = (long)ReadU64(data, p + 16);
                if (id == 6 && offset >= 0 && offset < data.Length) { timeOffset = offset; break; }
            }
            if (timeOffset < 0) return result;
            for (int p = (int)timeOffset; p + 48 <= data.Length && result.Count < 512; p += 112)
            {
                int id = (int)ReadU32(data, p + 16);
                uint flag = ReadU32(data, p + 20);
                ulong microseconds = ReadU64(data, p + 32);
                if (id < 0 || id > 4096) break;
                if (flag != 0)
                {
                    try
                    {
                        long ticks = checked((long)microseconds * 10L);
                        DateTime time = new DateTime(ticks, DateTimeKind.Utc).ToLocalTime();
                        result[id] = time;
                    }
                    catch { result[id] = DateTime.MinValue; }
                }
            }
            return result;
        }

        private static uint ReadU32(byte[] data, int p)
        {
            if (p < 0 || p + 4 > data.Length) return 0;
            return ((uint)data[p] << 24) | ((uint)data[p + 1] << 16) | ((uint)data[p + 2] << 8) | data[p + 3];
        }

        private static ulong ReadU64(byte[] data, int p)
        {
            return ((ulong)ReadU32(data, p) << 32) | ReadU32(data, p + 4);
        }
    }

    internal static class PhotoScanner
    {
        internal static string ResolveFolder(Ps3Settings settings, string dataRoot, string executable)
        {
            if (settings != null && !String.IsNullOrWhiteSpace(settings.screenshotFolder)) return settings.screenshotFolder;
            List<string> candidates = new List<string>();
            if (!String.IsNullOrWhiteSpace(dataRoot)) candidates.Add(Path.Combine(dataRoot, "screenshots"));
            if (!String.IsNullOrWhiteSpace(executable)) candidates.Add(Path.Combine(Path.GetDirectoryName(executable), "screenshots"));
            candidates.Add(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "rpcs3", "screenshots"));
            candidates.Add(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "rpcs3", "screenshots"));
            foreach (string candidate in candidates) if (Directory.Exists(candidate)) return candidate;
            return candidates.Count > 0 ? candidates[0] : String.Empty;
        }

        internal static List<string> Scan(string folder)
        {
            if (String.IsNullOrWhiteSpace(folder) || !Directory.Exists(folder)) return new List<string>();
            HashSet<string> extensions = new HashSet<string>(new string[] { ".png", ".jpg", ".jpeg", ".bmp" }, StringComparer.OrdinalIgnoreCase);
            try
            {
                return Directory.EnumerateFiles(folder, "*.*", SearchOption.AllDirectories)
                    .Where(delegate(string path) { return extensions.Contains(Path.GetExtension(path)); })
                    .Take(1000)
                    .OrderByDescending(delegate(string path) { try { return File.GetLastWriteTimeUtc(path); } catch { return DateTime.MinValue; } })
                    .ToList();
            }
            catch { return new List<string>(); }
        }
    }

    internal static class FirmwareAssetExtractor
    {
        internal static P3TImportResult Extract(string sourceRoot, string destination, Action<string, string> log)
        {
            if (!Directory.Exists(sourceRoot)) throw new DirectoryNotFoundException(sourceRoot);
            if (Directory.Exists(destination)) Directory.Delete(destination, true);
            Directory.CreateDirectory(destination);
            string imageDir = Path.Combine(destination, "Images");
            string soundDir = Path.Combine(destination, "Sounds");
            Directory.CreateDirectory(imageDir);
            Directory.CreateDirectory(soundDir);
            P3TImportResult result = new P3TImportResult();
            result.Name = Path.GetFileName(sourceRoot);
            result.Source = sourceRoot;
            result.OutputDirectory = destination;
            int visited = 0, images = 0, sounds = 0;
            foreach (string path in SafeFiles(sourceRoot))
            {
                if (++visited > 30000 || images >= 80 && sounds >= 24) break;
                string extension = Path.GetExtension(path).ToLowerInvariant();
                string safe = MakeSafe(Path.GetFileNameWithoutExtension(path));
                try
                {
                    if (images < 80 && (extension == ".png" || extension == ".jpg" || extension == ".jpeg" || extension == ".bmp"))
                    {
                        string target = Path.Combine(imageDir, safe + extension);
                        File.Copy(path, target, true);
                        result.Icons[safe] = target;
                        if (safe.IndexOf("back", StringComparison.OrdinalIgnoreCase) >= 0 || safe.IndexOf("wall", StringComparison.OrdinalIgnoreCase) >= 0) result.Backgrounds.Add(target);
                        images++;
                    }
                    else if (images < 80 && extension == ".gim")
                    {
                        string target = Path.Combine(imageDir, safe + ".png");
                        if (P3TImporter.ConvertGimFile(path, target)) { result.Icons[safe] = target; images++; }
                    }
                    else if (sounds < 24 && (extension == ".wav" || extension == ".mp3" || extension == ".wma"))
                    {
                        string target = Path.Combine(soundDir, safe + extension);
                        File.Copy(path, target, true);
                        result.Sounds[safe] = target;
                        sounds++;
                    }
                    else if (sounds < 24 && extension == ".vag")
                    {
                        string target = Path.Combine(soundDir, safe + ".wav");
                        if (P3TImporter.ConvertVagFile(path, target)) { result.Sounds[safe] = target; sounds++; }
                    }
                }
                catch { }
            }
            if (result.Backgrounds.Count == 0)
            {
                string first = result.Icons.Values.FirstOrDefault(delegate(string path) { return new FileInfo(path).Length > 250000; });
                if (!String.IsNullOrWhiteSpace(first)) result.Backgrounds.Add(first);
            }
            result.Warnings.Add("RCO and RAF containers are preserved by RPCS3 but are not decoded by this cache pass; unsupported resources use Huymaier fallbacks.");
            JavaScriptSerializer serializer = new JavaScriptSerializer();
            File.WriteAllText(Path.Combine(destination, "theme-manifest.json"), serializer.Serialize(result), Encoding.UTF8);
            File.WriteAllText(Path.Combine(destination, "compatibility.txt"), String.Join(Environment.NewLine, result.Warnings.ToArray()), Encoding.UTF8);
            if (log != null) log("XMB asset cache created from " + sourceRoot + ": " + images + " images, " + sounds + " sounds.", "INFO");
            return result;
        }

        private static IEnumerable<string> SafeFiles(string root)
        {
            Stack<string> stack = new Stack<string>();
            stack.Push(root);
            int dirs = 0;
            while (stack.Count > 0 && dirs++ < 4096)
            {
                string current = stack.Pop();
                string[] files = new string[0], directories = new string[0];
                try { files = Directory.GetFiles(current); directories = Directory.GetDirectories(current); } catch { }
                foreach (string file in files) yield return file;
                foreach (string directory in directories)
                {
                    try { if ((new DirectoryInfo(directory).Attributes & FileAttributes.ReparsePoint) == 0) stack.Push(directory); } catch { }
                }
            }
        }

        private static string MakeSafe(string value)
        {
            foreach (char c in Path.GetInvalidFileNameChars()) value = value.Replace(c, '_');
            return String.IsNullOrWhiteSpace(value) ? "asset" : value;
        }
    }

    public sealed class Ps3Settings
    {
        public int schemaVersion { get; set; }
        public string installationMode { get; set; }
        public string rpcs3Path { get; set; }
        public string rpcs3DataPath { get; set; }
        public string managedInstallFolder { get; set; }
        public string activeUserId { get; set; }
        public List<string> libraryRoots { get; set; }
        public bool scanRpcs3InstalledGames { get; set; }
        public string theme { get; set; }
        public string themeDirectory { get; set; }
        public string xmbAssetSource { get; set; }
        public string firmwareThemeFile { get; set; }
        public string firmwareThemeName { get; set; }
        public string customAssetFolder { get; set; }
        public string screenshotFolder { get; set; }
        public string backgroundImage { get; set; }
        public string xmbColorMode { get; set; }
        public string xmbCustomColor { get; set; }
        public Dictionary<string, string> themeColorPreferences { get; set; }
        public string backgroundMusic { get; set; }
        public bool musicEnabled { get; set; }
        public double musicVolume { get; set; }
        public bool musicLoop { get; set; }
        public bool soundEnabled { get; set; }
        public double soundVolume { get; set; }
        public Ps3SoundSettings sounds { get; set; }
        public string lastCategory { get; set; }
        public string lastSelection { get; set; }
        public bool fullscreen { get; set; }
        public bool showClock { get; set; }
        public bool hideMouseWhenControllerActive { get; set; }
        public bool startupVideoEnabled { get; set; }

        public Ps3Settings()
        {
            schemaVersion = 10;
            installationMode = String.Empty;
            rpcs3Path = String.Empty;
            rpcs3DataPath = String.Empty;
            managedInstallFolder = String.Empty;
            activeUserId = "00000001";
            libraryRoots = new List<string>();
            scanRpcs3InstalledGames = true;
            theme = "Original PS3 (Firmware Default)";
            themeDirectory = String.Empty;
            xmbAssetSource = "Firmware Assets";
            firmwareThemeFile = String.Empty;
            firmwareThemeName = String.Empty;
            customAssetFolder = String.Empty;
            screenshotFolder = String.Empty;
            backgroundImage = String.Empty;
            xmbColorMode = "Automatic";
            xmbCustomColor = "#315F8A";
            themeColorPreferences = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            backgroundMusic = String.Empty;
            musicEnabled = true;
            musicVolume = 0.3;
            musicLoop = true;
            soundEnabled = true;
            soundVolume = 1.0;
            sounds = new Ps3SoundSettings();
            lastCategory = "Game";
            lastSelection = String.Empty;
            fullscreen = true;
            showClock = true;
            hideMouseWhenControllerActive = true;
            startupVideoEnabled = true;
        }

        public static Ps3Settings Load(string userPath, string defaultPath)
        {
            JavaScriptSerializer serializer = new JavaScriptSerializer();
            Ps3Settings settings = new Ps3Settings();
            try
            {
                if (File.Exists(defaultPath)) settings = serializer.Deserialize<Ps3Settings>(File.ReadAllText(defaultPath, Encoding.UTF8));
            }
            catch { settings = new Ps3Settings(); }
            try
            {
                if (File.Exists(userPath)) settings = serializer.Deserialize<Ps3Settings>(File.ReadAllText(userPath, Encoding.UTF8));
            }
            catch { }
            int loadedSchema = settings == null ? 0 : settings.schemaVersion;
            if (settings == null) settings = new Ps3Settings();
            settings.Normalize();
            if (loadedSchema < 9 && Math.Abs(settings.soundVolume - 0.75) < 0.001)
            {
                // v0.25.0: raise the legacy XMB key-tone default so navigation
                // remains audible at living-room volume. Preserve custom values.
                settings.soundVolume = 1.0;
            }
            if (loadedSchema < 5)
            {
                // One-time migration: v0.23.2 could mistake the firmware's
                // numbered art theme for the stock XMB. Restore the firmware
                // default while preserving emulator paths, libraries and audio.
                settings.theme = "Original PS3 (Firmware Default)";
                settings.themeDirectory = String.Empty;
                settings.xmbAssetSource = "Firmware Assets";
                settings.firmwareThemeFile = String.Empty;
                settings.firmwareThemeName = String.Empty;
                settings.backgroundImage = String.Empty;
            }
            settings.Save(userPath);
            return settings;
        }

        public void Save(string path)
        {
            string temp = String.Empty;
            try
            {
                Normalize();
                JavaScriptSerializer serializer = new JavaScriptSerializer();
                string directory = Path.GetDirectoryName(path);
                if (!String.IsNullOrWhiteSpace(directory)) Directory.CreateDirectory(directory);
                temp = path + "." + Process.GetCurrentProcess().Id.ToString(CultureInfo.InvariantCulture) + ".tmp";
                File.WriteAllText(temp, serializer.Serialize(this), Encoding.UTF8);
                if (File.Exists(path))
                {
                    string backup = path + ".bak";
                    try { File.Replace(temp, path, backup, true); }
                    catch
                    {
                        File.Delete(path);
                        File.Move(temp, path);
                    }
                }
                else File.Move(temp, path);
            }
            catch
            {
                try { if (!String.IsNullOrWhiteSpace(temp) && File.Exists(temp)) File.Delete(temp); } catch { }
            }
        }

        private void Normalize()
        {
            schemaVersion = 10;
            if (installationMode == null) installationMode = String.Empty;
            if (rpcs3Path == null) rpcs3Path = String.Empty;
            if (rpcs3DataPath == null) rpcs3DataPath = String.Empty;
            if (managedInstallFolder == null) managedInstallFolder = String.Empty;
            if (String.IsNullOrWhiteSpace(activeUserId) || activeUserId.Length != 8 || !activeUserId.All(Char.IsDigit)) activeUserId = "00000001";
            if (libraryRoots == null) libraryRoots = new List<string>();
            List<string> normalizedRoots = new List<string>();
            foreach (string root in libraryRoots)
            {
                if (String.IsNullOrWhiteSpace(root)) continue;
                string normalized;
                try { normalized = Path.GetFullPath(Environment.ExpandEnvironmentVariables(root.Trim())).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar); }
                catch { normalized = root.Trim().TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar); }
                if (String.IsNullOrWhiteSpace(normalized)) continue;
                bool covered = normalizedRoots.Any(delegate(string existing)
                {
                    if (String.Equals(existing, normalized, StringComparison.OrdinalIgnoreCase)) return true;
                    string existingPrefix = existing + Path.DirectorySeparatorChar;
                    string normalizedPrefix = normalized + Path.DirectorySeparatorChar;
                    return existing.StartsWith(normalizedPrefix, StringComparison.OrdinalIgnoreCase) ||
                        normalized.StartsWith(existingPrefix, StringComparison.OrdinalIgnoreCase);
                });
                if (!covered) normalizedRoots.Add(normalized);
            }
            libraryRoots = normalizedRoots;
            if (theme == null) theme = "Original PS3 (Firmware Default)";
            if (themeDirectory == null) themeDirectory = String.Empty;
            if (xmbAssetSource == null) xmbAssetSource = "Firmware Assets";
            if (firmwareThemeFile == null) firmwareThemeFile = String.Empty;
            if (firmwareThemeName == null) firmwareThemeName = String.Empty;
            if (customAssetFolder == null) customAssetFolder = String.Empty;
            if (screenshotFolder == null) screenshotFolder = String.Empty;
            if (backgroundImage == null) backgroundImage = String.Empty;
            if (xmbColorMode == null) xmbColorMode = "Automatic";
            if (xmbCustomColor == null) xmbCustomColor = "#315F8A";
            if (themeColorPreferences == null) themeColorPreferences = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            if (backgroundMusic == null) backgroundMusic = String.Empty;
            if (sounds == null) sounds = new Ps3SoundSettings();
            sounds.Normalize();
            if (lastCategory == null) lastCategory = "Game";
            if (lastSelection == null) lastSelection = String.Empty;
            musicVolume = Math.Max(0, Math.Min(1, musicVolume));
            soundVolume = Math.Max(0, Math.Min(1, soundVolume));
        }
    }

    public sealed class Ps3SoundSettings
    {
        public string move { get; set; }
        public string confirm { get; set; }
        public string cancel { get; set; }
        public string category { get; set; }
        public string notification { get; set; }
        public string launch { get; set; }
        public string returnSound { get; set; }

        public Ps3SoundSettings() { Normalize(); }
        public void Normalize()
        {
            if (move == null) move = String.Empty;
            if (confirm == null) confirm = String.Empty;
            if (cancel == null) cancel = String.Empty;
            if (category == null) category = String.Empty;
            if (notification == null) notification = String.Empty;
            if (launch == null) launch = String.Empty;
            if (returnSound == null) returnSound = String.Empty;
        }
    }

    internal sealed class Ps3Game
    {
        internal string Title;
        internal string TitleId;
        internal string Version;
        internal string RootPath;
        internal string EbootPath;
        internal string IconPath;
        internal string HeroPath;
        internal string Source;
        internal string Category;
        internal int Bootable;
        internal int Priority;
        internal bool UsesActivatedC00;
    }

    internal static class Ps3LibraryScanner
    {
        internal static List<Ps3Game> Scan(Ps3Settings settings, Action<string, string> log)
        {
            Dictionary<string, Ps3Game> games = new Dictionary<string, Ps3Game>(StringComparer.OrdinalIgnoreCase);
            HashSet<string> scannedRoots = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            string executable = settings.rpcs3Path;
            string dataRoot = Ps3PathResolver.FindDataRoot(executable, settings.rpcs3DataPath);
            int discoveredFromGamesYml = 0;
            int discoveredFromInstalled = 0;
            int discoveredFromLibraries = 0;

            if (!String.IsNullOrWhiteSpace(dataRoot))
            {
                string gamesYml = Path.Combine(dataRoot, "games.yml");
                discoveredFromGamesYml += ScanGamesYml(gamesYml, dataRoot, games, scannedRoots, log);

                if (settings.scanRpcs3InstalledGames)
                {
                    discoveredFromInstalled += ScanDirectChildren(Path.Combine(dataRoot, "dev_hdd0", "game"),
                        "RPCS3 Installed", 90, dataRoot, games, scannedRoots, log);
                    discoveredFromInstalled += ScanDirectChildren(Path.Combine(dataRoot, "dev_hdd0", "disc"),
                        "RPCS3 Disc", 88, dataRoot, games, scannedRoots, log);
                    discoveredFromInstalled += ScanRoot(Path.Combine(dataRoot, "games"), 4,
                        "RPCS3 Games Folder", 86, dataRoot, games, scannedRoots, log);
                }
            }

            if (!String.IsNullOrWhiteSpace(executable))
            {
                string executableDirectory = Path.GetDirectoryName(executable);
                if (!String.IsNullOrWhiteSpace(executableDirectory))
                {
                    string executableGames = Path.Combine(executableDirectory, "games");
                    if (String.IsNullOrWhiteSpace(dataRoot) || !PathsEqual(executableGames, Path.Combine(dataRoot, "games")))
                    {
                        discoveredFromInstalled += ScanRoot(executableGames, 4,
                            "RPCS3 Games Folder", 85, dataRoot, games, scannedRoots, log);
                    }
                    if (String.IsNullOrWhiteSpace(dataRoot) || !PathsEqual(executableDirectory, dataRoot))
                    {
                        discoveredFromGamesYml += ScanGamesYml(Path.Combine(executableDirectory, "games.yml"),
                            dataRoot, games, scannedRoots, log);
                    }
                }
            }

            foreach (string root in settings.libraryRoots)
            {
                discoveredFromLibraries += ScanRoot(root, 7, "Library", 70, dataRoot, games, scannedRoots, log);
            }

            List<Ps3Game> result = CollapseEquivalentPaths(games.Values.ToList(), log);
            result.Sort(delegate(Ps3Game left, Ps3Game right)
            {
                return StringComparer.CurrentCultureIgnoreCase.Compare(left.Title, right.Title);
            });
            if (log != null)
            {
                log("PS3 library reconciliation found " + result.Count.ToString(CultureInfo.InvariantCulture) +
                    " unique title(s): games.yml=" + discoveredFromGamesYml.ToString(CultureInfo.InvariantCulture) +
                    ", installed=" + discoveredFromInstalled.ToString(CultureInfo.InvariantCulture) +
                    ", additional libraries=" + discoveredFromLibraries.ToString(CultureInfo.InvariantCulture) + ".", "INFO");
                foreach (Ps3Game game in result)
                {
                    log("PS3 title: " + (game.TitleId ?? String.Empty) + " | " + (game.Title ?? String.Empty) +
                        " | " + (game.Source ?? String.Empty) + " | " + (game.RootPath ?? String.Empty), "INFO");
                }
            }
            return result;
        }

        private static int ScanGamesYml(string path, string dataRoot, Dictionary<string, Ps3Game> games,
            HashSet<string> scannedRoots, Action<string, string> log)
        {
            if (String.IsNullOrWhiteSpace(path) || !File.Exists(path)) return 0;
            int accepted = 0;
            string baseDirectory = Path.GetDirectoryName(path);
            string[] lines;
            try { lines = File.ReadAllLines(path); }
            catch (Exception ex)
            {
                if (log != null) log("Could not read RPCS3 games.yml: " + ex.Message, "WARN");
                return 0;
            }

            foreach (string rawLine in lines)
            {
                string line = rawLine == null ? String.Empty : rawLine.Trim();
                if (line.Length == 0 || line.StartsWith("#", StringComparison.Ordinal) ||
                    line.StartsWith("%", StringComparison.Ordinal) || line == "---" || line == "...") continue;
                int separator = FindYamlSeparator(line);
                if (separator <= 0 || separator >= line.Length - 1) continue;

                string left = UnquoteYaml(line.Substring(0, separator).Trim());
                string right = UnquoteYaml(RemoveYamlComment(line.Substring(separator + 1).Trim()));
                string serial;
                string registeredPath;

                // RPCS3 has used serial:path, while hand-edited and older files can be
                // encountered as path:serial. Accept either orientation instead of silently
                // losing the entry (drive-letter colons are protected by FindYamlSeparator).
                if (LooksLikePath(left) && !LooksLikePath(right))
                {
                    registeredPath = left;
                    serial = right;
                }
                else
                {
                    serial = left;
                    registeredPath = right;
                }
                if (String.IsNullOrWhiteSpace(serial) || String.IsNullOrWhiteSpace(registeredPath)) continue;
                serial = NormalizeTitleId(serial);
                if (String.IsNullOrWhiteSpace(serial)) continue;

                registeredPath = Environment.ExpandEnvironmentVariables(registeredPath);
                if (!Path.IsPathRooted(registeredPath) && !String.IsNullOrWhiteSpace(baseDirectory))
                    registeredPath = Path.Combine(baseDirectory, registeredPath);
                try { registeredPath = Path.GetFullPath(registeredPath); } catch { }

                bool explicitC00 = EndsWithDirectory(registeredPath, "C00");
                registeredPath = NormalizeRegisteredPath(registeredPath);
                List<Ps3Game> entries = CreateGamesFromRegisteredPath(registeredPath, serial, dataRoot, explicitC00, log);
                if (entries.Count == 0)
                {
                    bool registeredTargetAvailable = File.Exists(registeredPath) || Directory.Exists(registeredPath);
                    entries.Add(new Ps3Game {
                        Title = serial,
                        TitleId = serial,
                        Version = String.Empty,
                        RootPath = registeredPath,
                        EbootPath = String.Empty,
                        IconPath = String.Empty,
                        HeroPath = String.Empty,
                        Source = "RPCS3 Game List",
                        Category = String.Empty,
                        Bootable = registeredTargetAvailable ? 1 : 0,
                        Priority = 100,
                        UsesActivatedC00 = explicitC00
                    });
                    if (!registeredTargetAvailable && log != null)
                        log("RPCS3 registered title " + serial + " is unavailable at " + registeredPath +
                            "; keeping it visible so Huymaier matches the RPCS3 game list.", "WARN");
                }

                foreach (Ps3Game game in entries)
                {
                    game.Priority = Math.Max(game.Priority, 100);
                    game.Source = "RPCS3 Game List";
                    if (LooksLikeTitleId(serial)) game.TitleId = serial;
                    else if (String.IsNullOrWhiteSpace(game.TitleId)) game.TitleId = serial;
                    if (MergeGame(games, game)) accepted++;
                }
                MarkScanned(scannedRoots, registeredPath);
            }
            return accepted;
        }

        private static List<Ps3Game> CreateGamesFromRegisteredPath(string path, string serial, string dataRoot,
            bool explicitC00, Action<string, string> log)
        {
            List<Ps3Game> result = new List<Ps3Game>();
            if (String.IsNullOrWhiteSpace(path)) return result;
            if (File.Exists(path))
            {
                result.Add(new Ps3Game {
                    Title = serial,
                    TitleId = serial,
                    Version = String.Empty,
                    RootPath = path,
                    EbootPath = String.Empty,
                    IconPath = String.Empty,
                    HeroPath = String.Empty,
                    Source = "RPCS3 Game List",
                    Category = String.Empty,
                    Bootable = 1,
                    Priority = 100,
                    UsesActivatedC00 = false
                });
                return result;
            }
            if (!Directory.Exists(path)) return result;

            string normalizedPath = path.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
            string directSfo = Path.Combine(normalizedPath, "PARAM.SFO");
            string ps3GameSfo = Path.Combine(normalizedPath, "PS3_GAME", "PARAM.SFO");
            if (File.Exists(directSfo))
            {
                Ps3Game direct = CreateGame(directSfo, "RPCS3 Game List", serial, 100, dataRoot, explicitC00);
                if (direct != null) result.Add(direct);
                return result;
            }
            if (File.Exists(ps3GameSfo))
            {
                Ps3Game disc = CreateGame(ps3GameSfo, "RPCS3 Game List", serial, 100, dataRoot, explicitC00);
                if (disc != null) result.Add(disc);
                return result;
            }
            string c00Sfo = Path.Combine(normalizedPath, "C00", "PARAM.SFO");
            if (File.Exists(c00Sfo))
            {
                Ps3Game c00 = CreateGame(c00Sfo, "RPCS3 Game List", serial, 100, dataRoot, true);
                if (c00 != null) result.Add(c00);
                return result;
            }
            if (File.Exists(Path.Combine(normalizedPath, "PS3_DISC.SFB")))
            {
                string[] directories;
                try { directories = Directory.GetDirectories(normalizedPath); }
                catch { directories = new string[0]; }
                foreach (string directory in directories)
                {
                    string name = Path.GetFileName(directory);
                    if (!String.Equals(name, "PS3_GAME", StringComparison.OrdinalIgnoreCase) && !IsPs3MultiGameDirectory(name)) continue;
                    string sfo = Path.Combine(directory, "PARAM.SFO");
                    if (!File.Exists(sfo)) continue;
                    Ps3Game game = CreateGame(sfo, "RPCS3 Game List", serial, 100, dataRoot, explicitC00);
                    if (game != null) result.Add(game);
                }
            }
            return result;
        }

        private static int ScanDirectChildren(string root, string source, int priority, string dataRoot,
            Dictionary<string, Ps3Game> games, HashSet<string> scannedRoots, Action<string, string> log)
        {
            if (String.IsNullOrWhiteSpace(root) || !Directory.Exists(root)) return 0;
            int accepted = 0;
            string[] directories;
            try { directories = Directory.GetDirectories(root); }
            catch { return 0; }
            foreach (string directory in directories)
            {
                if (IsScanned(scannedRoots, directory)) continue;
                string sfo = Path.Combine(directory, "PARAM.SFO");
                if (!File.Exists(sfo) && File.Exists(Path.Combine(directory, "PS3_GAME", "PARAM.SFO")))
                    sfo = Path.Combine(directory, "PS3_GAME", "PARAM.SFO");
                if (!File.Exists(sfo))
                {
                    string c00Sfo = Path.Combine(directory, "C00", "PARAM.SFO");
                    if (File.Exists(c00Sfo)) sfo = c00Sfo;
                }
                if (!File.Exists(sfo)) continue;
                try
                {
                    Ps3Game game = CreateGame(sfo, source, String.Empty, priority, dataRoot, false);
                    if (game != null && MergeGame(games, game)) accepted++;
                }
                catch (Exception ex)
                {
                    if (log != null) log("SFO scan failed for " + sfo + ": " + ex.Message, "WARN");
                }
                MarkScanned(scannedRoots, directory);
            }
            return accepted;
        }

        private static int ScanRoot(string root, int maxDepth, string source, int priority, string dataRoot,
            Dictionary<string, Ps3Game> games, HashSet<string> scannedRoots, Action<string, string> log)
        {
            if (String.IsNullOrWhiteSpace(root) || !Directory.Exists(root) || IsScanned(scannedRoots, root)) return 0;
            int accepted = 0;
            foreach (string sfo in EnumerateFiles(root, "PARAM.SFO", maxDepth))
            {
                try
                {
                    Ps3Game game = CreateGame(sfo, source, String.Empty, priority, dataRoot, false);
                    if (game == null || String.IsNullOrWhiteSpace(game.TitleId)) continue;
                    if (MergeGame(games, game)) accepted++;
                }
                catch (Exception ex)
                {
                    if (log != null) log("SFO scan failed for " + sfo + ": " + ex.Message, "WARN");
                }
            }
            MarkScanned(scannedRoots, root);
            return accepted;
        }

        private static IEnumerable<string> EnumerateFiles(string root, string fileName, int maxDepth)
        {
            Queue<DirectoryDepth> queue = new Queue<DirectoryDepth>();
            HashSet<string> visited = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            queue.Enqueue(new DirectoryDepth(root, 0));
            int examined = 0;
            while (queue.Count > 0 && examined < 25000)
            {
                DirectoryDepth current = queue.Dequeue();
                string full;
                try { full = Path.GetFullPath(current.Path); } catch { full = current.Path; }
                if (!visited.Add(full)) continue;
                examined++;
                string candidate = Path.Combine(current.Path, fileName);
                if (File.Exists(candidate)) yield return candidate;
                if (current.Depth >= maxDepth) continue;
                string[] directories;
                try { directories = Directory.GetDirectories(current.Path); }
                catch { continue; }
                foreach (string directory in directories)
                {
                    try
                    {
                        FileAttributes attributes = File.GetAttributes(directory);
                        if ((attributes & FileAttributes.ReparsePoint) != 0) continue;
                    }
                    catch { }
                    queue.Enqueue(new DirectoryDepth(directory, current.Depth + 1));
                }
            }
        }

        private static Ps3Game CreateGame(string sfoPath, string source, string forcedTitleId, int priority,
            string dataRoot, bool preferC00)
        {
            Dictionary<string, object> originalValues = ParamSfo.Read(sfoPath);
            if (originalValues.Count == 0) return null;

            string originalContentRoot = Path.GetDirectoryName(sfoPath);
            string gameRoot = originalContentRoot;
            if (String.Equals(Path.GetFileName(originalContentRoot), "PS3_GAME", StringComparison.OrdinalIgnoreCase))
                gameRoot = Directory.GetParent(originalContentRoot).FullName;
            else if (String.Equals(Path.GetFileName(originalContentRoot), "C00", StringComparison.OrdinalIgnoreCase))
                gameRoot = Directory.GetParent(originalContentRoot).FullName;

            // RPCS3 itself strips a trailing C00 registration and scans the parent game.
            // Keep the parent SFO/boot target authoritative and use C00 only as an
            // activated metadata overlay. This prevents trial/full pairs from vanishing
            // or launching a non-existent C00 EBOOT.
            string baseContentRoot = originalContentRoot;
            Dictionary<string, object> baseValues = originalValues;
            if (String.Equals(Path.GetFileName(originalContentRoot), "C00", StringComparison.OrdinalIgnoreCase))
            {
                string parentSfo = Path.Combine(gameRoot, "PARAM.SFO");
                if (File.Exists(parentSfo))
                {
                    Dictionary<string, object> parentValues = ParamSfo.Read(parentSfo);
                    if (parentValues.Count > 0)
                    {
                        baseValues = parentValues;
                        baseContentRoot = gameRoot;
                    }
                }
            }

            string baseTitleId = GetString(baseValues, "TITLE_ID");
            string titleId = LooksLikeTitleId(forcedTitleId) ? forcedTitleId : baseTitleId;
            if (String.IsNullOrWhiteSpace(titleId)) titleId = GetString(originalValues, "TITLE_ID");
            string contentId = GetString(baseValues, "CONTENT_ID");
            if (String.IsNullOrWhiteSpace(contentId)) contentId = GetString(originalValues, "CONTENT_ID");

            string c00Root = Path.Combine(gameRoot, "C00");
            string c00Sfo = Path.Combine(c00Root, "PARAM.SFO");
            Dictionary<string, object> c00Values = File.Exists(c00Sfo)
                ? ParamSfo.Read(c00Sfo)
                : new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);
            string c00TitleId = GetString(c00Values, "TITLE_ID");
            string c00ContentId = GetString(c00Values, "CONTENT_ID");
            bool activatedC00 = preferC00 ||
                String.Equals(Path.GetFileName(originalContentRoot), "C00", StringComparison.OrdinalIgnoreCase) ||
                (c00Values.Count > 0 &&
                    (HasActivationLicense(dataRoot, titleId, contentId, gameRoot) ||
                     HasActivationLicense(dataRoot, c00TitleId, c00ContentId, gameRoot)));

            Dictionary<string, object> displayValues = baseValues;
            string displayRoot = baseContentRoot;
            if (activatedC00 && c00Values.Count > 0)
            {
                displayValues = c00Values;
                displayRoot = c00Root;
            }

            string baseTitle = GetString(baseValues, "TITLE");
            string overlayTitle = GetString(displayValues, "TITLE");
            string title = ChooseDisplayTitle(baseTitle, overlayTitle);
            if (String.IsNullOrWhiteSpace(title)) title = Path.GetFileName(gameRoot);
            if (String.IsNullOrWhiteSpace(titleId)) titleId = Path.GetFileName(gameRoot);

            string category = GetString(baseValues, "CATEGORY");
            if (String.IsNullOrWhiteSpace(category)) category = GetString(displayValues, "CATEGORY");
            int bootable = GetInt(baseValues, "BOOTABLE", GetInt(displayValues, "BOOTABLE", 0));

            string baseIcon = Path.Combine(baseContentRoot, "ICON0.PNG");
            string overlayIcon = Path.Combine(displayRoot, "ICON0.PNG");
            string baseHero = Path.Combine(baseContentRoot, "PIC1.PNG");
            string overlayHero = Path.Combine(displayRoot, "PIC1.PNG");
            string baseEboot = Path.Combine(baseContentRoot, "USRDIR", "EBOOT.BIN");
            string c00Eboot = Path.Combine(c00Root, "USRDIR", "EBOOT.BIN");
            string eboot = File.Exists(baseEboot) ? baseEboot : (File.Exists(c00Eboot) ? c00Eboot : String.Empty);
            bool explicitEntry = source.IndexOf("RPCS3 Game List", StringComparison.OrdinalIgnoreCase) >= 0;

            // Registered games are authoritative. Folder fallback may see game updates,
            // DLC and installed game-data SFOs, so exclude only known data-only categories.
            if (!explicitEntry && IsNonGameCategory(category)) return null;
            // User-added folders are supplemental. Only accept an extracted title when
            // it has an actual boot executable; broad parent folders otherwise expose
            // updates, DLC and game-data PARAM.SFO files as duplicate games. RPCS3's
            // own games.yml remains authoritative and is never subject to this rule.
            if (String.Equals(source, "Library", StringComparison.OrdinalIgnoreCase) &&
                String.IsNullOrWhiteSpace(eboot)) return null;
            // Do not require BOOTABLE for RPCS3-registered entries. RPCS3 can resolve
            // registered/disc layouts whose executable is not directly visible here.

            return new Ps3Game {
                Title = title,
                TitleId = titleId,
                Version = FirstNonEmpty(GetString(displayValues, "APP_VER"), GetString(baseValues, "APP_VER")),
                RootPath = gameRoot,
                EbootPath = eboot,
                IconPath = File.Exists(overlayIcon) ? overlayIcon : (File.Exists(baseIcon) ? baseIcon : String.Empty),
                HeroPath = File.Exists(overlayHero) ? overlayHero : (File.Exists(baseHero) ? baseHero : String.Empty),
                Source = source,
                Category = category,
                Bootable = bootable,
                Priority = priority,
                UsesActivatedC00 = activatedC00
            };
        }

        private static bool HasActivationLicense(string dataRoot, string titleId, string contentId, string gameRoot)
        {
            List<DirectoryDepth> locations = new List<DirectoryDepth>();
            if (!String.IsNullOrWhiteSpace(dataRoot))
            {
                locations.Add(new DirectoryDepth(Path.Combine(dataRoot, "dev_hdd0", "exdata"), 1));
                string home = Path.Combine(dataRoot, "dev_hdd0", "home");
                if (Directory.Exists(home))
                {
                    try
                    {
                        foreach (string user in Directory.GetDirectories(home))
                            locations.Add(new DirectoryDepth(Path.Combine(user, "exdata"), 2));
                    }
                    catch { }
                }
            }
            if (!String.IsNullOrWhiteSpace(gameRoot))
            {
                // Some C00 unlocks place LIC.EDAT below USRDIR/LICDIR rather than
                // directly in the game root, so search the game tree with a strict
                // depth/directory bound instead of checking only four folders.
                locations.Add(new DirectoryDepth(gameRoot, 4));
            }

            string normalizedContentId = NormalizeLicenseName(contentId);
            string normalizedTitleId = NormalizeLicenseName(titleId);
            foreach (DirectoryDepth location in locations)
            {
                if (String.IsNullOrWhiteSpace(location.Path) || !Directory.Exists(location.Path)) continue;
                foreach (string file in EnumerateLicenseFiles(location.Path, location.Depth))
                {
                    string extension = Path.GetExtension(file);
                    if (!String.Equals(extension, ".rap", StringComparison.OrdinalIgnoreCase) &&
                        !String.Equals(extension, ".edat", StringComparison.OrdinalIgnoreCase) &&
                        !String.Equals(extension, ".rif", StringComparison.OrdinalIgnoreCase)) continue;

                    string fileName = Path.GetFileName(file);
                    string normalizedName = NormalizeLicenseName(Path.GetFileNameWithoutExtension(file));
                    if (!String.IsNullOrWhiteSpace(gameRoot) &&
                        file.StartsWith(gameRoot, StringComparison.OrdinalIgnoreCase) &&
                        String.Equals(fileName, "LIC.EDAT", StringComparison.OrdinalIgnoreCase)) return true;
                    if (!String.IsNullOrWhiteSpace(normalizedTitleId) && normalizedName.IndexOf(normalizedTitleId, StringComparison.OrdinalIgnoreCase) >= 0) return true;
                    if (!String.IsNullOrWhiteSpace(normalizedContentId) && normalizedName.IndexOf(normalizedContentId, StringComparison.OrdinalIgnoreCase) >= 0) return true;
                }
            }
            return false;
        }

        private static IEnumerable<string> EnumerateLicenseFiles(string root, int maxDepth)
        {
            Queue<DirectoryDepth> queue = new Queue<DirectoryDepth>();
            HashSet<string> visited = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            queue.Enqueue(new DirectoryDepth(root, 0));
            int examined = 0;
            while (queue.Count > 0 && examined < 2048)
            {
                DirectoryDepth current = queue.Dequeue();
                string full;
                try { full = Path.GetFullPath(current.Path); } catch { full = current.Path; }
                if (!visited.Add(full)) continue;
                examined++;
                string[] files;
                try { files = Directory.GetFiles(current.Path); }
                catch { files = new string[0]; }
                foreach (string file in files) yield return file;
                if (current.Depth >= maxDepth) continue;
                string[] directories;
                try { directories = Directory.GetDirectories(current.Path); }
                catch { continue; }
                foreach (string directory in directories)
                {
                    try
                    {
                        if ((File.GetAttributes(directory) & FileAttributes.ReparsePoint) != 0) continue;
                    }
                    catch { }
                    queue.Enqueue(new DirectoryDepth(directory, current.Depth + 1));
                }
            }
        }

        private static string NormalizeLicenseName(string value)
        {
            if (String.IsNullOrWhiteSpace(value)) return String.Empty;
            StringBuilder builder = new StringBuilder(value.Length);
            foreach (char character in value)
            {
                if (Char.IsLetterOrDigit(character)) builder.Append(Char.ToUpperInvariant(character));
            }
            return builder.ToString();
        }

        private static bool MergeGame(Dictionary<string, Ps3Game> games, Ps3Game candidate)
        {
            if (candidate == null || String.IsNullOrWhiteSpace(candidate.TitleId)) return false;
            candidate.TitleId = NormalizeTitleId(candidate.TitleId);
            if (String.IsNullOrWhiteSpace(candidate.TitleId)) return false;
            string key = candidate.TitleId;
            Ps3Game existing;
            if (!games.TryGetValue(key, out existing))
            {
                games[key] = candidate;
                return true;
            }
            Ps3Game merged = MergeCandidates(existing, candidate);
            bool replaced = Object.ReferenceEquals(merged, candidate);
            games[key] = merged;
            return replaced;
        }

        private static Ps3Game MergeCandidates(Ps3Game existing, Ps3Game candidate)
        {
            if (existing == null) return candidate;
            if (candidate == null) return existing;
            bool replace = candidate.Priority > existing.Priority ||
                (candidate.Priority == existing.Priority && candidate.UsesActivatedC00 && !existing.UsesActivatedC00) ||
                (candidate.Priority == existing.Priority && String.IsNullOrWhiteSpace(existing.EbootPath) && !String.IsNullOrWhiteSpace(candidate.EbootPath));
            Ps3Game primary = replace ? candidate : existing;
            Ps3Game secondary = replace ? existing : candidate;
            if (String.IsNullOrWhiteSpace(primary.Title) ||
                String.Equals(primary.Title, primary.TitleId, StringComparison.OrdinalIgnoreCase) &&
                    !String.IsNullOrWhiteSpace(secondary.Title) && !String.Equals(secondary.Title, secondary.TitleId, StringComparison.OrdinalIgnoreCase) ||
                IsTrialLabel(primary.Title) && !IsTrialLabel(secondary.Title)) primary.Title = secondary.Title;
            if (String.IsNullOrWhiteSpace(primary.Version)) primary.Version = secondary.Version;
            if (String.IsNullOrWhiteSpace(primary.RootPath)) primary.RootPath = secondary.RootPath;
            if (String.IsNullOrWhiteSpace(primary.EbootPath)) primary.EbootPath = secondary.EbootPath;
            if (String.IsNullOrWhiteSpace(primary.IconPath)) primary.IconPath = secondary.IconPath;
            if (String.IsNullOrWhiteSpace(primary.HeroPath)) primary.HeroPath = secondary.HeroPath;
            if (String.IsNullOrWhiteSpace(primary.Category)) primary.Category = secondary.Category;
            primary.UsesActivatedC00 = primary.UsesActivatedC00 || secondary.UsesActivatedC00;
            return primary;
        }

        private static List<Ps3Game> CollapseEquivalentPaths(List<Ps3Game> input, Action<string, string> log)
        {
            Dictionary<string, Ps3Game> byIdentity = new Dictionary<string, Ps3Game>(StringComparer.OrdinalIgnoreCase);
            List<Ps3Game> withoutIdentity = new List<Ps3Game>();
            int collapsed = 0;
            foreach (Ps3Game game in input ?? new List<Ps3Game>())
            {
                string identity = CanonicalGameIdentity(game);
                if (String.IsNullOrWhiteSpace(identity))
                {
                    withoutIdentity.Add(game);
                    continue;
                }
                Ps3Game existing;
                if (!byIdentity.TryGetValue(identity, out existing))
                {
                    byIdentity[identity] = game;
                    continue;
                }
                byIdentity[identity] = MergeCandidates(existing, game);
                collapsed++;
            }
            List<Ps3Game> result = byIdentity.Values.ToList();
            result.AddRange(withoutIdentity);
            if (collapsed > 0 && log != null)
                log("Collapsed " + collapsed.ToString(CultureInfo.InvariantCulture) +
                    " duplicate PS3 path registration(s).", "INFO");
            return result;
        }

        private static string CanonicalGameIdentity(Ps3Game game)
        {
            if (game == null) return String.Empty;
            string path = !String.IsNullOrWhiteSpace(game.EbootPath) ? game.EbootPath : game.RootPath;
            if (String.IsNullOrWhiteSpace(path)) return String.Empty;
            try
            {
                path = Path.GetFullPath(path).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
            }
            catch { path = path.Trim().TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar); }
            if (EndsWithDirectory(path, "C00") || EndsWithDirectory(path, "PS3_GAME"))
            {
                try { path = Directory.GetParent(path).FullName; } catch { }
            }
            return path;
        }

        private static string NormalizeTitleId(string value)
        {
            return String.IsNullOrWhiteSpace(value) ? String.Empty : value.Trim().ToUpperInvariant();
        }

        private static bool IsTrialLabel(string title)
        {
            if (String.IsNullOrWhiteSpace(title)) return false;
            return title.IndexOf("demo", StringComparison.OrdinalIgnoreCase) >= 0 ||
                title.IndexOf("trial", StringComparison.OrdinalIgnoreCase) >= 0;
        }

        private static string NormalizeRegisteredPath(string path)
        {
            if (String.IsNullOrWhiteSpace(path)) return String.Empty;
            string normalized = path.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
            if (EndsWithDirectory(normalized, "C00"))
            {
                try { normalized = Directory.GetParent(normalized).FullName; }
                catch { }
            }
            return normalized;
        }

        private static bool LooksLikePath(string value)
        {
            if (String.IsNullOrWhiteSpace(value)) return false;
            value = Environment.ExpandEnvironmentVariables(value.Trim());
            return Path.IsPathRooted(value) || value.IndexOf('\\') >= 0 || value.IndexOf('/') >= 0 ||
                value.EndsWith(".iso", StringComparison.OrdinalIgnoreCase) ||
                value.EndsWith(".bin", StringComparison.OrdinalIgnoreCase) ||
                value.EndsWith(".self", StringComparison.OrdinalIgnoreCase);
        }

        private static bool LooksLikeTitleId(string value)
        {
            if (String.IsNullOrWhiteSpace(value)) return false;
            value = value.Trim();
            if (value.Length < 4 || value.Length > 16 || LooksLikePath(value)) return false;
            bool hasLetter = false;
            bool hasDigit = false;
            foreach (char character in value)
            {
                if (Char.IsLetter(character)) hasLetter = true;
                else if (Char.IsDigit(character)) hasDigit = true;
                else if (character != '-' && character != '_') return false;
            }
            return hasLetter && hasDigit;
        }

        private static string ChooseDisplayTitle(string baseTitle, string overlayTitle)
        {
            if (String.IsNullOrWhiteSpace(baseTitle)) return overlayTitle;
            if (String.IsNullOrWhiteSpace(overlayTitle)) return baseTitle;
            if (IsTrialLabel(baseTitle) && !IsTrialLabel(overlayTitle)) return overlayTitle;
            if (!IsTrialLabel(baseTitle) && IsTrialLabel(overlayTitle)) return baseTitle;
            return overlayTitle;
        }

        private static string FirstNonEmpty(string first, string second)
        {
            return !String.IsNullOrWhiteSpace(first) ? first : (second ?? String.Empty);
        }

        private static bool IsNonGameCategory(string category)
        {
            if (String.IsNullOrWhiteSpace(category)) return false;
            string value = category.Trim().ToUpperInvariant();
            // Data, update, add-on, save-data and media categories should merge into
            // their base title (or remain hidden), never become separate XMB games.
            return value == "GD" || value == "SD" || value == "AC" || value == "AS" ||
                value == "AT" || value == "AV" || value == "BV" || value == "MS" ||
                value == "WT" || value == "DP";
        }

        private static int FindYamlSeparator(string line)
        {
            bool single = false;
            bool quoted = false;
            for (int i = 0; i < line.Length; i++)
            {
                char value = line[i];
                if (value == '\'' && !quoted) single = !single;
                else if (value == '"' && !single && (i == 0 || line[i - 1] != '\\')) quoted = !quoted;
                else if (value == ':' && !single && !quoted) return i;
            }
            return -1;
        }

        private static string RemoveYamlComment(string value)
        {
            bool single = false;
            bool quoted = false;
            for (int i = 0; i < value.Length; i++)
            {
                char current = value[i];
                if (current == '\'' && !quoted) single = !single;
                else if (current == '"' && !single && (i == 0 || value[i - 1] != '\\')) quoted = !quoted;
                else if (current == '#' && !single && !quoted && (i == 0 || Char.IsWhiteSpace(value[i - 1])))
                    return value.Substring(0, i).TrimEnd();
            }
            return value;
        }

        private static string UnquoteYaml(string value)
        {
            if (String.IsNullOrWhiteSpace(value)) return String.Empty;
            value = value.Trim();
            if (value.Length >= 2 && value[0] == '\'' && value[value.Length - 1] == '\'')
                return value.Substring(1, value.Length - 2).Replace("''", "'");
            if (value.Length >= 2 && value[0] == '"' && value[value.Length - 1] == '"')
            {
                string inner = value.Substring(1, value.Length - 2);
                return inner.Replace("\\\"", "\"").Replace("\\\\", "\\");
            }
            return value;
        }

        private static bool IsPs3MultiGameDirectory(string name)
        {
            if (String.IsNullOrWhiteSpace(name) || name.Length != 7 || !name.StartsWith("PS3_GM", StringComparison.OrdinalIgnoreCase)) return false;
            return Char.IsDigit(name[5]) && Char.IsDigit(name[6]);
        }

        private static bool EndsWithDirectory(string path, string directory)
        {
            if (String.IsNullOrWhiteSpace(path)) return false;
            return String.Equals(Path.GetFileName(path.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar)),
                directory, StringComparison.OrdinalIgnoreCase);
        }

        private static bool PathsEqual(string left, string right)
        {
            if (String.IsNullOrWhiteSpace(left) || String.IsNullOrWhiteSpace(right)) return false;
            try
            {
                return String.Equals(Path.GetFullPath(left).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar),
                    Path.GetFullPath(right).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar),
                    StringComparison.OrdinalIgnoreCase);
            }
            catch { return String.Equals(left, right, StringComparison.OrdinalIgnoreCase); }
        }

        private static bool IsScanned(HashSet<string> scannedRoots, string path)
        {
            if (scannedRoots == null || String.IsNullOrWhiteSpace(path)) return false;
            try { return scannedRoots.Contains(Path.GetFullPath(path)); }
            catch { return scannedRoots.Contains(path); }
        }

        private static void MarkScanned(HashSet<string> scannedRoots, string path)
        {
            if (scannedRoots == null || String.IsNullOrWhiteSpace(path)) return;
            try { scannedRoots.Add(Path.GetFullPath(path)); }
            catch { scannedRoots.Add(path); }
        }

        private static string GetString(Dictionary<string, object> values, string key)
        {
            object value;
            return values.TryGetValue(key, out value) && value != null ? Convert.ToString(value, CultureInfo.InvariantCulture) : String.Empty;
        }

        private static int GetInt(Dictionary<string, object> values, string key, int fallback)
        {
            object value;
            if (!values.TryGetValue(key, out value) || value == null) return fallback;
            try { return Convert.ToInt32(value, CultureInfo.InvariantCulture); }
            catch
            {
                int parsed;
                return Int32.TryParse(Convert.ToString(value, CultureInfo.InvariantCulture), NumberStyles.Integer,
                    CultureInfo.InvariantCulture, out parsed) ? parsed : fallback;
            }
        }

        private sealed class DirectoryDepth
        {
            internal readonly string Path;
            internal readonly int Depth;
            internal DirectoryDepth(string path, int depth) { Path = path; Depth = depth; }
        }
    }

    internal sealed class Ps3UserProfile
    {
        internal string Id = String.Empty;
        internal string Name = String.Empty;
        internal string Path = String.Empty;
    }

    internal sealed class Ps3SaveEntry
    {
        internal string Path = String.Empty;
        internal string Title = String.Empty;
        internal string Subtitle = String.Empty;
    }

    internal static class ParamSfo
    {
        internal static Dictionary<string, object> Read(string path)
        {
            Dictionary<string, object> result = new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);
            byte[] bytes = File.ReadAllBytes(path);
            if (bytes.Length < 20 || bytes[0] != 0 || bytes[1] != 0x50 || bytes[2] != 0x53 || bytes[3] != 0x46) return result;
            uint keyTable = BitConverter.ToUInt32(bytes, 8);
            uint dataTable = BitConverter.ToUInt32(bytes, 12);
            uint count = BitConverter.ToUInt32(bytes, 16);
            for (uint index = 0; index < count; index++)
            {
                int entry = 20 + (int)index * 16;
                if (entry + 16 > bytes.Length) break;
                ushort keyOffset = BitConverter.ToUInt16(bytes, entry);
                ushort format = BitConverter.ToUInt16(bytes, entry + 2);
                uint length = BitConverter.ToUInt32(bytes, entry + 4);
                uint dataOffset = BitConverter.ToUInt32(bytes, entry + 12);
                int keyPosition = (int)keyTable + keyOffset;
                if (keyPosition < 0 || keyPosition >= bytes.Length) continue;
                int keyEnd = keyPosition;
                while (keyEnd < bytes.Length && bytes[keyEnd] != 0) keyEnd++;
                string key = Encoding.UTF8.GetString(bytes, keyPosition, keyEnd - keyPosition);
                int dataPosition = (int)dataTable + (int)dataOffset;
                if (dataPosition < 0 || dataPosition >= bytes.Length) continue;
                if (format == 0x0404 || format == 0x0204)
                {
                    int safeLength = Math.Min((int)length, bytes.Length - dataPosition);
                    result[key] = Encoding.UTF8.GetString(bytes, dataPosition, safeLength).TrimEnd('\0');
                }
                else if (format == 0x0402 && dataPosition + 4 <= bytes.Length)
                    result[key] = BitConverter.ToUInt32(bytes, dataPosition);
            }
            return result;
        }
    }

    internal static class Ps3PathResolver
    {
        internal static string FindDataRoot(string executable, string configured)
        {
            List<string> candidates = new List<string>();
            if (!String.IsNullOrWhiteSpace(configured)) candidates.Add(configured);
            if (!String.IsNullOrWhiteSpace(executable) && File.Exists(executable)) candidates.Add(Path.GetDirectoryName(executable));
            candidates.Add(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "rpcs3"));
            candidates.Add(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "rpcs3"));
            foreach (string candidate in candidates)
            {
                if (String.IsNullOrWhiteSpace(candidate) || !Directory.Exists(candidate)) continue;
                if (Directory.Exists(Path.Combine(candidate, "dev_hdd0")) || Directory.Exists(Path.Combine(candidate, "dev_flash")) ||
                    File.Exists(Path.Combine(candidate, "config.yml")) || Directory.Exists(Path.Combine(candidate, "GuiConfigs")))
                    return Path.GetFullPath(candidate);
            }
            if (!String.IsNullOrWhiteSpace(executable) && File.Exists(executable)) return Path.GetDirectoryName(executable);
            return String.Empty;
        }
    }

    public sealed class Ps2BbnWindow : Window
    {
        private readonly string platformRoot;
        private readonly string consoleRoot;
        private readonly string appDataRoot;
        private readonly string settingsPath;
        private readonly string logPath;
        private readonly string libraryCachePath;
        private readonly BbnSurface surface;
        private readonly System.Windows.Threading.DispatcherTimer inputTimer;
        private readonly System.Windows.Threading.DispatcherTimer healthTimer;
        private readonly XmbInputRouter input;
        private Ps2Settings settings;
        private List<BbnChannel> channels;
        private readonly Stack<BbnMenuContext> menuStack;
        private List<Ps2Game> games;
        private int channelIndex;
        private int selectedIndex;
        private double visualChannel;
        private double visualItem;
        private DateTime lastFrameUtc;
        private DateTime noticeUntilUtc;
        private string noticeText;
        private bool inputSuspended;
        private bool closing;
        private bool scanRunning;
        private bool renderingAttached;
        private Process activeEmulatorProcess;
        private List<string> photoFiles;
        private bool photoViewerActive;
        private int photoViewerIndex;
        private HwndSource hwndSource;
        private HwndSourceHook rawHook;
        private readonly Dictionary<string, BitmapSource> imageCache;
        private readonly MediaPlayer mediaPlayer;
        private readonly MediaPlayer backgroundMusicPlayer;
        private readonly MediaPlayer interfaceSoundPlayer;
        private readonly MediaPlayer startupAudioPlayer;
        private readonly MediaPlayer gameBootAudioPlayer;
        private readonly ConsoleStartupVideoOverlay startupVideoOverlay;
        private Ps2Game pendingLaunchGame;
        private bool mediaPlaying;
        private bool backgroundMusicPlaying;
        private bool gameLetterFocus;
        private int gameLetterIndex;
        private bool videoViewerActive;
        private string videoCaption;
        private bool topMenuActive;
        private List<Ps2SaveVisual> saveVisuals;
        private DateTime inputDeviceGuardUntilUtc;
        private DateTime bootSequenceStartedUtc;
        private bool bootSequenceActive;
        private bool bootSequenceWaitsForAudio;
        private double bootSequenceDurationSeconds;

        internal Ps2Settings Settings { get { return settings; } }
        internal IList<BbnChannel> Channels { get { return channels; } }
        internal bool TopMenuActive { get { return topMenuActive; } }
        internal bool BootSequenceActive { get { return bootSequenceActive; } }
        internal double BootSequenceProgress
        {
            get
            {
                if (!bootSequenceActive) return 1.0;
                double duration = Math.Max(1.0, bootSequenceDurationSeconds);
                return Math.Max(0.0, Math.Min(1.0, (DateTime.UtcNow - bootSequenceStartedUtc).TotalSeconds / duration));
            }
        }
        internal bool MemoryBrowserActive
        {
            get
            {
                if (topMenuActive) return false;
                if (menuStack.Count > 0 && menuStack.Peek().MemoryBrowser) return true;
                return channels != null && channelIndex >= 0 && channelIndex < channels.Count &&
                    String.Equals(channels[channelIndex].Id, "MemoryCards", StringComparison.OrdinalIgnoreCase);
            }
        }
        internal IList<Ps2SaveVisual> SaveVisuals { get { return saveVisuals; } }
        internal string CurrentSectionTitle
        {
            get
            {
                if (menuStack.Count > 0) return menuStack.Peek().Title;
                if (channels != null && channelIndex >= 0 && channelIndex < channels.Count)
                    return channels[channelIndex].Title;
                return "Top Menu";
            }
        }
        internal int ChannelIndex { get { return channelIndex; } }
        internal int SelectedIndex { get { return selectedIndex; } }
        internal double VisualChannel { get { return visualChannel; } }
        internal double VisualItem { get { return visualItem; } }
        internal string NoticeText { get { return DateTime.UtcNow < noticeUntilUtc ? noticeText : String.Empty; } }
        internal bool PhotoViewerActive { get { return photoViewerActive; } }
        internal bool VideoViewerActive { get { return videoViewerActive; } }
        internal bool GameLetterFocus { get { return gameLetterFocus; } }
        internal int GameLetterIndex { get { return gameLetterIndex; } }
        internal string GameLetters { get { return "#ABCDEFGHIJKLMNOPQRSTUVWXYZ"; } }
        internal bool HasGamesForLetter(int index)
        {
            if (index < 0 || index >= GameLetters.Length) return false;
            char bucket = GameLetters[index];
            return games != null && games.Any(delegate(Ps2Game game) { return GetGameBucket(game == null ? String.Empty : game.Title) == bucket; });
        }
        internal bool MemoryCardContentActive
        {
            get { return menuStack.Count > 0 && menuStack.Peek().MemoryCardContent; }
        }
        internal bool MemoryOptionsActive
        {
            get { return menuStack.Count > 0 && menuStack.Peek().MemoryOptions; }
        }
        internal string CurrentMemoryCardFreeText
        {
            get { return menuStack.Count > 0 ? menuStack.Peek().MemoryCardFreeText ?? String.Empty : String.Empty; }
        }
        internal MediaPlayer VideoPlayer { get { return mediaPlayer; } }
        internal string VideoCaption { get { return videoCaption ?? String.Empty; } }
        internal string CurrentPhotoPath
        {
            get
            {
                return photoFiles != null && photoViewerIndex >= 0 && photoViewerIndex < photoFiles.Count
                    ? photoFiles[photoViewerIndex] : String.Empty;
            }
        }
        internal string CurrentPhotoCaption
        {
            get
            {
                string path = CurrentPhotoPath;
                return String.IsNullOrWhiteSpace(path) ? String.Empty : Path.GetFileName(path);
            }
        }
        internal BbnItem CurrentItem
        {
            get
            {
                List<BbnItem> items = CurrentItems;
                return selectedIndex >= 0 && selectedIndex < items.Count ? items[selectedIndex] : null;
            }
        }
        internal List<BbnItem> CurrentItems
        {
            get
            {
                if (topMenuActive) return new List<BbnItem>();
                if (menuStack.Count > 0) return menuStack.Peek().Items;
                if (channels == null || channelIndex < 0 || channelIndex >= channels.Count) return new List<BbnItem>();
                return channels[channelIndex].Items;
            }
        }

        public Ps2BbnWindow(string platformRoot, string consoleRoot)
        {
            this.platformRoot = platformRoot;
            this.consoleRoot = consoleRoot;
            appDataRoot = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "Huymaier Console", "EmulatorPlatforms", "PS2");
            Directory.CreateDirectory(appDataRoot);
            settingsPath = Path.Combine(appDataRoot, "settings.json");
            logPath = Path.Combine(appDataRoot, "ps2-native.log");
            libraryCachePath = Path.Combine(appDataRoot, "library-cache.json");
            string defaultSettings = Path.Combine(platformRoot, "settings.default.json");
            settings = Ps2Settings.Load(settingsPath, defaultSettings);
            games = new List<Ps2Game>();
            photoFiles = new List<string>();
            menuStack = new Stack<BbnMenuContext>();
            imageCache = new Dictionary<string, BitmapSource>(StringComparer.OrdinalIgnoreCase);
            saveVisuals = new List<Ps2SaveVisual>();
            topMenuActive = true;
            input = new XmbInputRouter();
            mediaPlayer = new MediaPlayer();
            backgroundMusicPlayer = new MediaPlayer();
            interfaceSoundPlayer = new MediaPlayer();
            startupAudioPlayer = new MediaPlayer();
            gameBootAudioPlayer = new MediaPlayer();
            backgroundMusicPlayer.MediaEnded += delegate
            {
                if (!settings.ps2BackgroundMusicEnabled || String.IsNullOrWhiteSpace(settings.ps2BackgroundMusicPath)) return;
                try { backgroundMusicPlayer.Position = TimeSpan.Zero; backgroundMusicPlayer.Play(); backgroundMusicPlaying = true; } catch { }
            };
            startupAudioPlayer.MediaOpened += StartupAudioOpened;
            startupAudioPlayer.MediaEnded += StartupAudioEnded;
            startupAudioPlayer.MediaFailed += delegate { StartupAudioEnded(null, EventArgs.Empty); };
            gameBootAudioPlayer.MediaEnded += GameBootAudioEnded;
            gameBootAudioPlayer.MediaFailed += delegate { GameBootAudioEnded(null, EventArgs.Empty); };

            Title = "PlayStation 2";
            WindowStyle = WindowStyle.None;
            ResizeMode = ResizeMode.NoResize;
            WindowState = settings.fullscreen ? WindowState.Maximized : WindowState.Normal;
            Background = Brushes.Black;
            ShowInTaskbar = false;
            Topmost = false;

            surface = new BbnSurface(this);
            Grid ps2Root = new Grid();
            ps2Root.Children.Add(surface);
            startupVideoOverlay = new ConsoleStartupVideoOverlay();
            ps2Root.Children.Add(startupVideoOverlay);
            Content = ps2Root;

            inputTimer = new System.Windows.Threading.DispatcherTimer(
                System.Windows.Threading.DispatcherPriority.Input, Dispatcher);
            inputTimer.Interval = TimeSpan.FromMilliseconds(10);
            inputTimer.Tick += InputTick;

            healthTimer = new System.Windows.Threading.DispatcherTimer(
                System.Windows.Threading.DispatcherPriority.Background, Dispatcher);
            healthTimer.Interval = TimeSpan.FromSeconds(2);
            healthTimer.Tick += HealthTick;

            Loaded += WindowLoaded;
            Closed += WindowClosed;
            PreviewKeyDown += KeyDownHandler;
            PreviewMouseMove += MouseMoveHandler;
            mediaPlayer.MediaEnded += delegate
            {
                try { mediaPlayer.Stop(); } catch { }
                mediaPlaying = false;
                videoViewerActive = false;
                videoCaption = String.Empty;
                surface.InvalidateVisual();
            };
            BuildChannels();
            LoadCachedLibrary();
            if (games.Count > 0) RebuildGameItems();
            RefreshSaveVisuals();
        }

        private void WindowLoaded(object sender, RoutedEventArgs e)
        {
            try
            {
                hwndSource = PresentationSource.FromVisual(this) as HwndSource;
                if (hwndSource != null)
                {
                    rawHook = RawInputHook;
                    hwndSource.AddHook(rawHook);
                    HuymaierConsole.Native.RawHidController.Register(hwndSource.Handle);
                }
            }
            catch (Exception ex) { WriteLog("Raw HID registration failed: " + ex.Message, "WARN"); }
            lastFrameUtc = DateTime.UtcNow;
            AttachRendering();
            inputTimer.Start();
            healthTimer.Start();
            StartPs2StartupVideo();
            BeginScan(false);
            BeginPhotoScan();
        }

        private void WindowClosed(object sender, EventArgs e)
        {
            closing = true;
            inputTimer.Stop();
            healthTimer.Stop();
            DetachRendering();
            try { mediaPlayer.Stop(); mediaPlayer.Close(); } catch { }
            try { backgroundMusicPlayer.Stop(); backgroundMusicPlayer.Close(); } catch { }
            try { interfaceSoundPlayer.Stop(); interfaceSoundPlayer.Close(); } catch { }
            try { startupAudioPlayer.Stop(); startupAudioPlayer.Close(); } catch { }
            try { gameBootAudioPlayer.Stop(); gameBootAudioPlayer.Close(); } catch { }
            try { startupVideoOverlay.Stop(); } catch { }
            try { if (activeEmulatorProcess != null && activeEmulatorProcess.HasExited) activeEmulatorProcess.Dispose(); } catch { }
            try
            {
                if (hwndSource != null && rawHook != null) hwndSource.RemoveHook(rawHook);
            }
            catch { }
            settings.lastChannel = channels != null && channelIndex >= 0 && channelIndex < channels.Count
                ? channels[channelIndex].Id : "GameCollection";
            settings.Save(settingsPath);
            NativeWindowActivation.Restore(Owner);
        }

        private IntPtr RawInputHook(IntPtr hwnd, int msg, IntPtr wParam, IntPtr lParam, ref bool handled)
        {
            if (msg == 0x00FF)
            {
                try { HuymaierConsole.Native.RawHidController.ProcessInput(lParam); } catch { }
                handled = false;
            }
            else if (msg == 0x00FE)
            {
                try
                {
                    HuymaierConsole.Native.RawHidController.ProcessDeviceChange(wParam, lParam);
                    NativeConsoleNavigation.NotifyDeviceChange();
                    inputDeviceGuardUntilUtc = DateTime.UtcNow.AddMilliseconds(750);
                }
                catch { }
                handled = false;
            }
            return IntPtr.Zero;
        }

        private void AttachRendering()
        {
            if (renderingAttached) return;
            CompositionTarget.Rendering += RenderFrame;
            renderingAttached = true;
        }

        private void DetachRendering()
        {
            if (!renderingAttached) return;
            CompositionTarget.Rendering -= RenderFrame;
            renderingAttached = false;
        }

        private void RenderFrame(object sender, EventArgs e)
        {
            DateTime now = DateTime.UtcNow;
            double elapsed = Math.Max(0.001, Math.Min(0.08, (now - lastFrameUtc).TotalSeconds));
            lastFrameUtc = now;
            visualChannel += (channelIndex - visualChannel) * Math.Min(1.0, elapsed * 11.0);
            visualItem += (selectedIndex - visualItem) * Math.Min(1.0, elapsed * 13.0);
            surface.Advance(elapsed);
            if (bootSequenceActive && !bootSequenceWaitsForAudio && BootSequenceProgress >= 1.0)
                CompleteBootSequence(false);
            surface.InvalidateVisual();
        }

        private void InputTick(object sender, EventArgs e)
        {
            if (closing || inputSuspended || !IsActive || DateTime.UtcNow < inputDeviceGuardUntilUtc) return;
            XmbInputCommand command = input.Poll();
            if (command == XmbInputCommand.None) return;
            ProcessCommand(command);
        }

        private void ProcessCommand(XmbInputCommand command)
        {
            if (command == XmbInputCommand.Menu) { NativeQuickAccessRequest.Request(); try { Close(); } catch { } return; }
            if (startupVideoOverlay.IsActive)
            {
                if (command == XmbInputCommand.Confirm || command == XmbInputCommand.Back) startupVideoOverlay.Skip();
                return;
            }
            if (bootSequenceActive)
            {
                if (command == XmbInputCommand.Confirm) SkipBootSequence();
                return;
            }
            PlayCommandSound(command);
            if (videoViewerActive)
            {
                if (command == XmbInputCommand.Back)
                {
                    try { mediaPlayer.Stop(); } catch { }
                    mediaPlaying = false;
                    videoViewerActive = false;
                    videoCaption = String.Empty;
                    surface.InvalidateVisual();
                }
                else if (command == XmbInputCommand.Confirm)
                {
                    try
                    {
                        if (mediaPlaying) { mediaPlayer.Pause(); mediaPlaying = false; }
                        else { mediaPlayer.Play(); mediaPlaying = true; }
                    }
                    catch { }
                }
                return;
            }
            if (photoViewerActive)
            {
                if (command == XmbInputCommand.Back) { ClosePhotoViewer(); return; }
                if (command == XmbInputCommand.Left || command == XmbInputCommand.LeftShoulder) { MovePhoto(-1); return; }
                if (command == XmbInputCommand.Right || command == XmbInputCommand.RightShoulder) { MovePhoto(1); return; }
                return;
            }

            if (topMenuActive)
            {
                switch (command)
                {
                    case XmbInputCommand.Up:
                    case XmbInputCommand.Left:
                    case XmbInputCommand.LeftShoulder:
                        MoveChannel(-1);
                        break;
                    case XmbInputCommand.Down:
                    case XmbInputCommand.Right:
                    case XmbInputCommand.RightShoulder:
                        MoveChannel(1);
                        break;
                    case XmbInputCommand.Confirm:
                        EnterChannel();
                        break;
                    case XmbInputCommand.Back:
                        Close();
                        break;
                    case XmbInputCommand.Menu:
                        ShowNotice("PlayStation 2");
                        break;
                }
                return;
            }

            bool gameCollection = menuStack.Count == 0 && channels != null &&
                channelIndex >= 0 && channelIndex < channels.Count &&
                channels[channelIndex].Id == "GameCollection";
            bool memoryBrowser = MemoryBrowserActive;
            bool memoryOptions = MemoryOptionsActive;

            if (gameCollection)
            {
                if (gameLetterFocus)
                {
                    switch (command)
                    {
                        case XmbInputCommand.Up: MoveGameLetter(-1); break;
                        case XmbInputCommand.Down: MoveGameLetter(1); break;
                        case XmbInputCommand.Left:
                        case XmbInputCommand.Right:
                        case XmbInputCommand.Back:
                            gameLetterFocus = false;
                            surface.InvalidateVisual();
                            break;
                        case XmbInputCommand.Confirm:
                            JumpToGameLetter(gameLetterIndex, true);
                            break;
                        case XmbInputCommand.Menu:
                            gameLetterFocus = false;
                            menuStack.Clear();
                            topMenuActive = true;
                            visualChannel = channelIndex;
                            surface.InvalidateVisual();
                            break;
                    }
                    return;
                }
                switch (command)
                {
                    case XmbInputCommand.Left: MoveVertical(-1); SyncGameLetterToSelection(); break;
                    case XmbInputCommand.Right: MoveVertical(1); SyncGameLetterToSelection(); break;
                    case XmbInputCommand.Up:
                        gameLetterFocus = true;
                        SyncGameLetterToSelection();
                        surface.InvalidateVisual();
                        break;
                    case XmbInputCommand.Down:
                        break;
                    case XmbInputCommand.Confirm:
                        InvokeSelected();
                        break;
                    case XmbInputCommand.Back: NavigateBack(); break;
                    case XmbInputCommand.LeftShoulder: JumpToAdjacentGameLetter(-1); break;
                    case XmbInputCommand.RightShoulder: JumpToAdjacentGameLetter(1); break;
                    case XmbInputCommand.Menu:
                        menuStack.Clear();
                        topMenuActive = true;
                        visualChannel = channelIndex;
                        surface.InvalidateVisual();
                        break;
                }
                return;
            }

            if (command == XmbInputCommand.Options && memoryBrowser && !memoryOptions)
            {
                OpenMemoryOptions();
                return;
            }

            switch (command)
            {
                case XmbInputCommand.Left:
                    if (memoryBrowser) MoveVertical(-1);
                    else NavigateBack();
                    break;
                case XmbInputCommand.Right:
                    if (memoryBrowser) MoveVertical(1);
                    else if (CurrentItem != null && CurrentItem.Children != null && CurrentItem.Children.Count > 0) InvokeSelected();
                    break;
                case XmbInputCommand.Up: MoveVertical(memoryOptions ? -1 : memoryBrowser ? -4 : -1); break;
                case XmbInputCommand.Down: MoveVertical(memoryOptions ? 1 : memoryBrowser ? 4 : 1); break;
                case XmbInputCommand.Confirm: InvokeSelected(); break;
                case XmbInputCommand.Back: NavigateBack(); break;
                case XmbInputCommand.LeftShoulder: MoveVertical(memoryBrowser ? -8 : -1); break;
                case XmbInputCommand.RightShoulder: MoveVertical(memoryBrowser ? 8 : 1); break;
                case XmbInputCommand.Menu:
                    menuStack.Clear();
                    topMenuActive = true;
                    visualChannel = channelIndex;
                    surface.InvalidateVisual();
                    break;
            }
        }


        private void KeyDownHandler(object sender, KeyEventArgs e)
        {
            if (e.Key == Key.Left) { ProcessCommand(XmbInputCommand.Left); e.Handled = true; }
            else if (e.Key == Key.Right) { ProcessCommand(XmbInputCommand.Right); e.Handled = true; }
            else if (e.Key == Key.Up) { ProcessCommand(XmbInputCommand.Up); e.Handled = true; }
            else if (e.Key == Key.Down) { ProcessCommand(XmbInputCommand.Down); e.Handled = true; }
            else if (e.Key == Key.Enter) { ProcessCommand(XmbInputCommand.Confirm); e.Handled = true; }
            else if (e.Key == Key.T) { ProcessCommand(XmbInputCommand.Options); e.Handled = true; }
            else if (e.Key == Key.Escape || e.Key == Key.Back) { ProcessCommand(XmbInputCommand.Back); e.Handled = true; }
        }

        private void MouseMoveHandler(object sender, MouseEventArgs e)
        {
            try { Forms.Cursor.Show(); } catch { }
        }

        private void HealthTick(object sender, EventArgs e)
        {
            if (closing) return;
            try
            {
                long working = Process.GetCurrentProcess().WorkingSet64;
                if (working > 1400L * 1024L * 1024L)
                {
                    WriteLog("PS2 interface safety memory limit reached: " + working, "ERROR");
                    ShowNotice("Memory safety limit reached. Returning to Huymaier Console.");
                    Dispatcher.BeginInvoke(new Action(Close));
                }
            }
            catch { }
        }

        private void BuildChannels()
        {
            channels = new List<BbnChannel>();
            BbnChannel gameCollection = new BbnChannel("GameCollection", "Game Channel", "Your PlayStation 2 library");
            gameCollection.Items.Add(new BbnItem("Scanning games...", "Select PCSX2 or add a game folder in Settings", "Rescan"));
            channels.Add(gameCollection);

            BbnChannel browser = new BbnChannel("Browser", "Browser", "Games, memory cards and system storage");
            browser.Items.Add(new BbnItem("PlayStation 2 Games", "Browse installed games", "FocusGames"));
            browser.Items.Add(new BbnItem("Memory Card 1", GetMemoryCardSummary(), "OpenMemoryCards"));
            browser.Items.Add(new BbnItem("Memory Card 2", GetMemoryCardSummary(), "OpenMemoryCards"));
            channels.Add(browser);

            BbnChannel memory = new BbnChannel("MemoryCards", "Memory Cards", "Manage cards and saved data");
            memory.Items = BuildMemoryCardItems();
            channels.Add(memory);

            BbnChannel photo = new BbnChannel("Photos", "Photo Channel", "PCSX2 screenshots");
            photo.Items.Add(new BbnItem("Screenshots", "Loading...", "RefreshPhotos"));
            photo.Items.Add(new BbnItem("Screenshot Folder", GetScreenshotFolder(), "ChooseScreenshotFolder"));
            channels.Add(photo);

            BbnChannel music = new BbnChannel("Music", "Music Channel", "Play music from a selected folder");
            music.Items = BuildMediaItems(true);
            channels.Add(music);

            BbnChannel movie = new BbnChannel("Movies", "Movie Channel", "Browse videos from a selected folder");
            movie.Items = BuildMediaItems(false);
            channels.Add(movie);

            BbnChannel settingsChannel = new BbnChannel("Settings", "System Settings", "PCSX2 and PlayStation 2 settings");
            settingsChannel.Items = BuildSettingsItems();
            channels.Add(settingsChannel);

            BbnChannel power = new BbnChannel("Power", "Return", "Return to Huymaier Console");
            power.Items.Add(new BbnItem("Return to Huymaier Console", "Close the PlayStation 2 interface", "Exit"));
            channels.Add(power);

            channelIndex = Math.Max(0, channels.FindIndex(delegate(BbnChannel c)
            {
                return String.Equals(c.Id, settings.lastChannel, StringComparison.OrdinalIgnoreCase);
            }));
            selectedIndex = 0;
            visualChannel = channelIndex;
            visualItem = selectedIndex;
        }

        private List<BbnItem> BuildSettingsItems()
        {
            List<BbnItem> result = new List<BbnItem>();
            result.Add(new BbnItem("PCSX2 Installation", GetPcsx2Status(), null, new List<BbnItem> {
                new BbnItem("Use / Change Existing Installation", GetPcsx2Status(), "ChoosePcsx2"),
                new BbnItem("Install / Update PCSX2", GetManagedStatus(), "InstallPcsx2"),
                new BbnItem("PCSX2 Data Location", GetDataRoot(), "ChooseDataRoot"),
                new BbnItem("Re-scan PCSX2 Configuration", "Refresh folders, BIOS and library", "RescanConfiguration")
            }));
            result.Add(new BbnItem("Full PCSX2 Settings", "Every setting discovered from the installed PCSX2 configuration", "FullPcsx2Settings"));
            result.Add(new BbnItem("BIOS", GetBiosStatus(), "ChooseBios"));
            result.Add(new BbnItem("Game Library Folders", GetLibrarySummary(), null, BuildLibraryFolderItems()));
            result.Add(new BbnItem("Emulation Settings", "CPU, boot and patch behavior", null, BuildEmulationSettings(false, String.Empty)));
            result.Add(new BbnItem("Graphics Settings", "Renderer, resolution and aspect ratio", null, BuildGraphicsSettings(false, String.Empty)));
            result.Add(new BbnItem("PlayStation 2 Interface Audio", GetInterfaceAudioSummary(), null, BuildInterfaceAudioItems()));
            result.Add(new BbnItem("PCSX2 Big Picture Launch", "Always enabled — pause menu, save states, load states and exit", null));
            result.Add(new BbnItem("Audio Settings", "Backend, latency and synchronization", null, BuildAudioSettings(false, String.Empty)));
            result.Add(new BbnItem("Controller Settings", "Native PCSX2 pad settings", null, BuildControllerSettings(false, String.Empty)));
            result.Add(new BbnItem("Network Settings", "DEV9 Ethernet configuration", null, BuildNetworkSettings(false, String.Empty)));
            result.Add(new BbnItem("Per-Game Settings", "Select a game to edit native overrides", null, BuildPerGameItems()));
            result.Add(new BbnItem("Memory Card & Save Management", GetMemoryCardSummary(), "OpenMemoryCards"));
            result.Add(new BbnItem("Patches / Cheats / Widescreen", "Manage native PCSX2 folders and toggles", null, new List<BbnItem> {
                P2ConfigItem("Enable Patches", false, String.Empty, "EmuCore", "EnablePatches", new string[] { "true", "false" }, "true"),
                P2ConfigItem("Enable Cheats", false, String.Empty, "EmuCore", "EnableCheats", new string[] { "false", "true" }, "false"),
                P2ConfigItem("Enable Widescreen Patches", false, String.Empty, "EmuCore", "EnableWideScreenPatches", new string[] { "true", "false" }, "true"),
                P2ConfigItem("Enable No-Interlacing Patches", false, String.Empty, "EmuCore", "EnableNoInterlacingPatches", new string[] { "true", "false" }, "true"),
                new BbnItem("Open Cheats Folder", ResolveConfiguredFolder("Cheats", "cheats"), "OpenFolder|Cheats"),
                new BbnItem("Open Widescreen Folder", ResolveConfiguredFolder("CheatsWS", "cheats_ws"), "OpenFolder|CheatsWS"),
                new BbnItem("Open Patches Folder", ResolveConfiguredFolder("Patches", "patches"), "OpenFolder|Patches")
            }));
            result.Add(new BbnItem("Texture Replacements", ResolveConfiguredFolder("Textures", "textures"), null, new List<BbnItem> {
                P2ConfigItem("Load Texture Replacements", false, String.Empty, "EmuCore/GS", "LoadTextureReplacements", new string[] { "false", "true" }, "false"),
                P2ConfigItem("Async Texture Loading", false, String.Empty, "EmuCore/GS", "LoadTextureReplacementsAsync", new string[] { "true", "false" }, "true"),
                new BbnItem("Open Texture Folder", ResolveConfiguredFolder("Textures", "textures"), "OpenFolder|Textures")
            }));
            result.Add(new BbnItem("Interface Assets", GetAssetText(), null, new List<BbnItem> {
                new BbnItem("PlayStation 2 Default", "Built-in PlayStation 2 broadband-style interface", "AssetDefault"),
                new BbnItem("Use Local PlayStation 2 Asset Folder", settings.customAssetFolder, "ChooseAssets"),
                new BbnItem("Clear Custom Assets", "Return to the Huymaier PlayStation 2 appearance", "ClearAssets")
            }));
            result.Add(new BbnItem("Photos / Media Folders", "Configure PS2 channels", null, new List<BbnItem> {
                new BbnItem("Screenshot Folder", GetScreenshotFolder(), "ChooseScreenshotFolder"),
                new BbnItem("Music Folder", settings.musicFolder, "ChooseMusicFolder"),
                new BbnItem("Movie Folder", settings.movieFolder, "ChooseMovieFolder")
            }));
            result.Add(new BbnItem("Maintenance", "Caches, logs and advanced tools", null, new List<BbnItem> {
                new BbnItem("Clear Rebuildable Cache", ResolveConfiguredFolder("Cache", "cache"), "ClearCache"),
                new BbnItem("Open Logs", ResolveConfiguredFolder("Logs", "logs"), "OpenFolder|Logs"),
                new BbnItem("Open PCSX2 Desktop UI", "Advanced troubleshooting only", "OpenPcsx2")
            }));
            return result;
        }

        private List<BbnItem> BuildInterfaceAudioItems()
        {
            return new List<BbnItem> {
                new BbnItem("Original PS2 Startup Video", settings.ps2StartupVideoEnabled ? "Enabled" : "Disabled", "TogglePs2StartupVideo"),
                new BbnItem("Menu Ambience", settings.ps2BackgroundMusicEnabled ? "Enabled" : "Disabled", "TogglePs2Bgm"),
                new BbnItem("Import Menu Ambience", GetImportedAudioName(settings.ps2BackgroundMusicPath), "ImportPs2Bgm"),
                new BbnItem("Menu Music Volume", settings.ps2BackgroundMusicVolume + "%", "CyclePs2BgmVolume"),
                new BbnItem("Game Selection Boot Sound", settings.ps2GameBootSoundEnabled ? "Enabled" : "Disabled", "TogglePs2GameBoot"),
                new BbnItem("Import Game Boot Sound", GetImportedAudioName(settings.ps2GameBootSoundPath), "ImportPs2GameBoot"),
                new BbnItem("Interface Sound Effects", settings.ps2SoundEffectsEnabled ? "Enabled" : "Disabled", "TogglePs2Sfx"),
                new BbnItem("Import Navigation Sound", GetImportedAudioName(settings.ps2NavigateSoundPath), "ImportPs2Navigate"),
                new BbnItem("Import Confirm Sound", GetImportedAudioName(settings.ps2ConfirmSoundPath), "ImportPs2Confirm"),
                new BbnItem("Import Back Sound", GetImportedAudioName(settings.ps2BackSoundPath), "ImportPs2Back"),
                new BbnItem("Navigation / Sound Effects Volume", settings.ps2SoundEffectsVolume + "%", "CyclePs2SfxVolume"),
                new BbnItem("Clear Game Boot Audio", "Keep menu ambience and key tones", "ClearPs2BootAudio"),
                new BbnItem("Restore Default Key Tones", "Use the built-in Navigate, Confirm and Back sounds", "RestorePs2Sfx")
            };
        }

        private string GetInterfaceAudioSummary()
        {
            string startup = settings.ps2StartupVideoEnabled ? "startup video enabled" : "startup video disabled";
            string ambience = settings.ps2BackgroundMusicEnabled && !String.IsNullOrWhiteSpace(settings.ps2BackgroundMusicPath)
                ? "menu ambience ready" : "no ambience";
            string gameBoot = settings.ps2GameBootSoundEnabled && !String.IsNullOrWhiteSpace(settings.ps2GameBootSoundPath)
                ? "game boot ready" : "no game boot";
            return startup + " • " + ambience + " • " + gameBoot;
        }

        private static string GetImportedAudioName(string path)
        {
            return String.IsNullOrWhiteSpace(path) || !File.Exists(path) ? "Use Import to choose an audio file" : Path.GetFileName(path);
        }

        private void ChooseInterfaceAudio(string kind)
        {
            OpenFileDialog dialog = new OpenFileDialog();
            dialog.Title = kind == "startup" ? "Import PlayStation 2 Startup Audio" :
                kind == "bgm" ? "Import PlayStation 2 Menu Ambience" :
                kind == "gameboot" ? "Import PlayStation 2 Game Selection Boot Sound" :
                "Import PlayStation 2 Interface Sound";
            dialog.Filter = "Audio files (*.wav;*.mp3;*.wma;*.m4a)|*.wav;*.mp3;*.wma;*.m4a|All files (*.*)|*.*";
            if (dialog.ShowDialog(this) != true) return;
            try
            {
                string folder = Path.Combine(appDataRoot, "InterfaceAudio");
                Directory.CreateDirectory(folder);
                string baseName = kind == "startup" ? "startup" : kind == "bgm" ? "menu-ambience" : kind == "gameboot" ? "game-boot" : kind;
                string destination = Path.Combine(folder, baseName + Path.GetExtension(dialog.FileName).ToLowerInvariant());
                foreach (string old in Directory.EnumerateFiles(folder, baseName + ".*"))
                    try { File.Delete(old); } catch { }
                File.Copy(dialog.FileName, destination, true);
                if (kind == "startup") settings.ps2StartupSoundPath = destination;
                else if (kind == "bgm") settings.ps2BackgroundMusicPath = destination;
                else if (kind == "gameboot") settings.ps2GameBootSoundPath = destination;
                else if (kind == "navigate") settings.ps2NavigateSoundPath = destination;
                else if (kind == "confirm") settings.ps2ConfirmSoundPath = destination;
                else if (kind == "back") settings.ps2BackSoundPath = destination;
                settings.Save(settingsPath);
                if (kind == "bgm") StartBackgroundMusic();
                RefreshSettingsChannel();
                ShowNotice("Imported " + Path.GetFileName(dialog.FileName));
            }
            catch (Exception ex) { ShowNotice("Audio import failed: " + ex.Message); }
        }

        private void CycleInterfaceVolume(bool background)
        {
            int[] values = new int[] { 0, 25, 50, 75, 100 };
            int current = background ? settings.ps2BackgroundMusicVolume : settings.ps2SoundEffectsVolume;
            int index = Array.FindIndex(values, delegate(int value) { return value == current; });
            int next = values[(index + 1 + values.Length) % values.Length];
            if (background)
            {
                settings.ps2BackgroundMusicVolume = next;
                try { backgroundMusicPlayer.Volume = next / 100.0; } catch { }
            }
            else settings.ps2SoundEffectsVolume = next;
            settings.Save(settingsPath);
            RefreshSettingsChannel();
            ShowNotice((background ? "Background music" : "Sound effects") + " volume — " + next + "%");
        }

        private void StartPs2StartupVideo()
        {
            bootSequenceActive = false;
            bootSequenceWaitsForAudio = false;
            try { startupAudioPlayer.Stop(); startupAudioPlayer.Close(); } catch { }
            try { backgroundMusicPlayer.Stop(); backgroundMusicPlayer.Close(); backgroundMusicPlaying = false; } catch { }
            string video = Path.Combine(platformRoot, "Assets", "Startup.mp4");
            if (settings.ps2StartupVideoEnabled) startupVideoOverlay.Play(video, 1.0, StartBackgroundMusic);
            else StartBackgroundMusic();
        }

        private void BeginBootSequence()
        {
            if (!settings.ps2BootAnimationEnabled)
            {
                bootSequenceActive = false;
                bootSequenceWaitsForAudio = false;
                return;
            }
            bootSequenceStartedUtc = DateTime.UtcNow;
            bootSequenceDurationSeconds = 9.25;
            bootSequenceActive = true;
            bootSequenceWaitsForAudio = false;
            surface.InvalidateVisual();
        }

        private void StartPs2AudioSequence()
        {
            BeginBootSequence();
            try
            {
                startupAudioPlayer.Stop();
                startupAudioPlayer.Close();
                if (settings.ps2StartupSoundEnabled && !String.IsNullOrWhiteSpace(settings.ps2StartupSoundPath) && File.Exists(settings.ps2StartupSoundPath))
                {
                    try { backgroundMusicPlayer.Stop(); backgroundMusicPlayer.Close(); } catch { }
                    backgroundMusicPlaying = false;
                    bootSequenceWaitsForAudio = bootSequenceActive;
                    startupAudioPlayer.Open(new Uri(settings.ps2StartupSoundPath));
                    startupAudioPlayer.Volume = Math.Max(0, Math.Min(100, settings.ps2SoundEffectsVolume)) / 100.0;
                    startupAudioPlayer.Play();
                    return;
                }
            }
            catch (Exception ex) { WriteLog("PS2 startup audio failed: " + ex.Message, "WARN"); }
            if (!bootSequenceActive) StartBackgroundMusic();
        }

        private void StartupAudioOpened(object sender, EventArgs e)
        {
            try
            {
                if (startupAudioPlayer.NaturalDuration.HasTimeSpan)
                {
                    double seconds = startupAudioPlayer.NaturalDuration.TimeSpan.TotalSeconds;
                    if (seconds >= 2.0 && seconds <= 30.0) bootSequenceDurationSeconds = seconds;
                }
            }
            catch { }
        }

        private void StartupAudioEnded(object sender, EventArgs e)
        {
            try { startupAudioPlayer.Stop(); startupAudioPlayer.Close(); } catch { }
            CompleteBootSequence(true);
        }

        private void CompleteBootSequence(bool startMusic)
        {
            if (!bootSequenceActive && !bootSequenceWaitsForAudio)
            {
                if (startMusic) StartBackgroundMusic();
                return;
            }
            bootSequenceActive = false;
            bootSequenceWaitsForAudio = false;
            surface.InvalidateVisual();
            if (startMusic || !backgroundMusicPlaying) StartBackgroundMusic();
        }

        private void SkipBootSequence()
        {
            try { startupAudioPlayer.Stop(); startupAudioPlayer.Close(); } catch { }
            CompleteBootSequence(true);
        }

        private void BeginGameLaunch(Ps2Game game)
        {
            if (game == null) return;
            string path = settings.ps2GameBootSoundPath;
            if (!settings.ps2GameBootSoundEnabled || String.IsNullOrWhiteSpace(path) || !File.Exists(path))
            {
                LaunchGame(game);
                return;
            }
            try
            {
                pendingLaunchGame = game;
                inputSuspended = true;
                try { backgroundMusicPlayer.Pause(); } catch { }
                gameBootAudioPlayer.Stop();
                gameBootAudioPlayer.Close();
                gameBootAudioPlayer.Open(new Uri(path));
                gameBootAudioPlayer.Volume = Math.Max(0, Math.Min(100, settings.ps2SoundEffectsVolume)) / 100.0;
                gameBootAudioPlayer.Play();
                ShowNotice("Starting " + game.Title + "...");
            }
            catch (Exception ex)
            {
                WriteLog("PS2 game boot sound failed: " + ex.Message, "WARN");
                pendingLaunchGame = null;
                inputSuspended = false;
                LaunchGame(game);
            }
        }

        private void GameBootAudioEnded(object sender, EventArgs e)
        {
            Ps2Game game = pendingLaunchGame;
            pendingLaunchGame = null;
            try { gameBootAudioPlayer.Stop(); gameBootAudioPlayer.Close(); } catch { }
            inputSuspended = false;
            if (game != null) LaunchGame(game);
        }

        private void StartBackgroundMusic()
        {
            try
            {
                backgroundMusicPlayer.Stop();
                backgroundMusicPlayer.Close();
                backgroundMusicPlaying = false;
                if (!settings.ps2BackgroundMusicEnabled || String.IsNullOrWhiteSpace(settings.ps2BackgroundMusicPath) || !File.Exists(settings.ps2BackgroundMusicPath)) return;
                backgroundMusicPlayer.Open(new Uri(settings.ps2BackgroundMusicPath));
                backgroundMusicPlayer.Volume = Math.Max(0, Math.Min(100, settings.ps2BackgroundMusicVolume)) / 100.0;
                backgroundMusicPlayer.Play();
                backgroundMusicPlaying = true;
            }
            catch (Exception ex) { WriteLog("PS2 background music failed: " + ex.Message, "WARN"); }
        }

        private void PlayCommandSound(XmbInputCommand command)
        {
            if (!settings.ps2SoundEffectsEnabled) return;
            string path = String.Empty;
            if (command == XmbInputCommand.Confirm) path = ResolveInterfaceSound(settings.ps2ConfirmSoundPath, "Confirm.wav");
            else if (command == XmbInputCommand.Back) path = ResolveInterfaceSound(settings.ps2BackSoundPath, "Back.wav");
            else if (command == XmbInputCommand.Left || command == XmbInputCommand.Right || command == XmbInputCommand.Up || command == XmbInputCommand.Down || command == XmbInputCommand.LeftShoulder || command == XmbInputCommand.RightShoulder || command == XmbInputCommand.Options)
                path = ResolveInterfaceSound(settings.ps2NavigateSoundPath, "Navigate.wav");
            if (String.IsNullOrWhiteSpace(path) || !File.Exists(path)) return;
            try
            {
                interfaceSoundPlayer.Stop();
                interfaceSoundPlayer.Close();
                interfaceSoundPlayer.Open(new Uri(path));
                interfaceSoundPlayer.Volume = Math.Max(0, Math.Min(100, settings.ps2SoundEffectsVolume)) / 100.0;
                interfaceSoundPlayer.Play();
            }
            catch { }
        }

        private string ResolveInterfaceSound(string custom, string fallbackName)
        {
            if (!String.IsNullOrWhiteSpace(custom) && File.Exists(custom)) return custom;
            return Path.Combine(consoleRoot, "Assets", fallbackName);
        }

        private List<BbnItem> BuildEmulationSettings(bool perGame, string serial)
        {
            return new List<BbnItem> {
                P2ConfigItem("Fast Boot", perGame, serial, "EmuCore", "EnableFastBoot", new string[] { "true", "false" }, "true"),
                P2ConfigItem("EE Cycle Rate", perGame, serial, "EmuCore/Speedhacks", "EECycleRate", new string[] { "0", "-1", "1", "2", "3" }, "0"),
                P2ConfigItem("EE Cycle Skip", perGame, serial, "EmuCore/Speedhacks", "EECycleSkip", new string[] { "0", "1", "2", "3" }, "0"),
                P2ConfigItem("MTVU", perGame, serial, "EmuCore/Speedhacks", "vuThread", new string[] { "true", "false" }, "true"),
                P2ConfigItem("Save State on Shutdown", perGame, serial, "EmuCore", "SaveStateOnShutdown", new string[] { "false", "true" }, "false")
            };
        }

        private List<BbnItem> BuildGraphicsSettings(bool perGame, string serial)
        {
            return new List<BbnItem> {
                P2ConfigItem("Renderer", perGame, serial, "EmuCore/GS", "Renderer", new string[] { "-1", "12", "13", "14", "15" }, "-1"),
                P2ConfigItem("Internal Resolution", perGame, serial, "EmuCore/GS", "upscale_multiplier", new string[] { "1", "2", "3", "4", "5", "6", "8" }, "3"),
                P2ConfigItem("Aspect Ratio", perGame, serial, "EmuCore/GS", "AspectRatio", new string[] { "Auto 4:3/3:2", "4:3", "16:9", "Stretch" }, "Auto 4:3/3:2"),
                P2ConfigItem("VSync", perGame, serial, "EmuCore/GS", "VsyncEnable", new string[] { "0", "1", "2" }, "0"),
                P2ConfigItem("Sync to Host Refresh", perGame, serial, "EmuCore/GS", "SyncToHostRefreshRate", new string[] { "false", "true" }, "false"),
                P2ConfigItem("Anisotropic Filtering", perGame, serial, "EmuCore/GS", "MaxAnisotropy", new string[] { "0", "2", "4", "8", "16" }, "0")
            };
        }

        private List<BbnItem> BuildAudioSettings(bool perGame, string serial)
        {
            return new List<BbnItem> {
                P2ConfigItem("Audio Backend", perGame, serial, "SPU2/Output", "OutputModule", new string[] { "cubeb", "SDL", "Null" }, "cubeb"),
                P2ConfigItem("Latency", perGame, serial, "SPU2/Output", "Latency", new string[] { "20", "40", "60", "80", "100" }, "60"),
                P2ConfigItem("Synchronization", perGame, serial, "SPU2/Output", "SynchMode", new string[] { "0", "1", "2" }, "0"),
                P2ConfigItem("Master Volume", perGame, serial, "SPU2/Mixing", "FinalVolume", new string[] { "25", "50", "75", "100" }, "100")
            };
        }

        private List<BbnItem> BuildControllerSettings(bool perGame, string serial)
        {
            List<BbnItem> result = new List<BbnItem> {
                P2ConfigItem("Controller Port 1", perGame, serial, "Pad1", "Type", new string[] { "DualShock2", "None" }, "DualShock2"),
                P2ConfigItem("Controller Port 2", perGame, serial, "Pad2", "Type", new string[] { "None", "DualShock2" }, "None"),
                P2ConfigItem("Button Deadzone", perGame, serial, "Pad1", "ButtonDeadzone", new string[] { "0", "0.05", "0.10", "0.15" }, "0"),
                P2ConfigItem("Analog Scale", perGame, serial, "Pad1", "AxisScale", new string[] { "1.00", "1.20", "1.33", "1.50" }, "1.33")
            };
            if (!perGame)
            {
                result.Add(new BbnItem("Automatic Map Xbox / XInput", "Map XInput controller 1 to DualShock 2 Port 1", "MapPadXInput"));
                result.Add(new BbnItem("Automatic Map DualSense / DualShock", "Use PCSX2 SDL mapping and enhanced Sony mode", "MapPadSDL"));
                result.Add(new BbnItem("Current Port 1 Bindings", "Review the native PCSX2 bindings", null, BuildBindingItems("Pad1")));
                result.Add(new BbnItem("Clear Port 1 Bindings", "Remove mapped buttons but keep the DualShock 2 device", "ClearPad1"));
                result.Add(new BbnItem("Open Input Profiles", ResolveConfiguredFolder("InputProfiles", "inputprofiles"), "OpenFolder|InputProfiles"));
            }
            return result;
        }

        private List<BbnItem> BuildBindingItems(string section)
        {
            List<BbnItem> result = new List<BbnItem>();
            SimpleIniFile ini = GetIni(false, String.Empty);
            foreach (string key in PadBindingKeys)
            {
                string value = ini.Get(section, key, String.Empty);
                result.Add(new BbnItem(key, String.IsNullOrWhiteSpace(value) ? "Not mapped" : value, null));
            }
            return result;
        }

        private List<BbnItem> BuildNetworkSettings(bool perGame, string serial)
        {
            return new List<BbnItem> {
                P2ConfigItem("Ethernet", perGame, serial, "DEV9/Eth", "EthEnable", new string[] { "false", "true" }, "false"),
                P2ConfigItem("DHCP Intercept", perGame, serial, "DEV9/Eth", "InterceptDHCP", new string[] { "true", "false" }, "true"),
                P2ConfigItem("HDD Emulation", perGame, serial, "DEV9/Hdd", "HddEnable", new string[] { "false", "true" }, "false")
            };
        }

        private BbnItem P2ConfigItem(string title, bool perGame, string serial, string section, string key, string[] options, string fallback)
        {
            string current = GetConfigValue(perGame, serial, section, key, fallback);
            string action = "P2Cfg|" + (perGame ? "G" : "A") + "|" + Encode(serial) + "|" +
                Encode(section) + "|" + Encode(key) + "|" + Encode(String.Join("\u001f", options));
            return new BbnItem(title, FormatPcsx2Option(section, key, current), action);
        }

        private static string FormatPcsx2Option(string section, string key, string value)
        {
            string raw = value ?? String.Empty;
            if (String.Equals(raw, "true", StringComparison.OrdinalIgnoreCase)) return "Enabled";
            if (String.Equals(raw, "false", StringComparison.OrdinalIgnoreCase)) return "Disabled";
            if (String.Equals(key, "Renderer", StringComparison.OrdinalIgnoreCase))
            {
                if (raw == "-1") return "Automatic";
                if (raw == "12") return "Direct3D 11";
                if (raw == "13") return "Direct3D 12";
                if (raw == "14") return "OpenGL";
                if (raw == "15") return "Vulkan";
            }
            if (String.Equals(key, "upscale_multiplier", StringComparison.OrdinalIgnoreCase))
                return raw == "1" ? "Native (1×)" : raw + "× Native";
            if (String.Equals(key, "VsyncEnable", StringComparison.OrdinalIgnoreCase))
                return raw == "0" ? "Off" : raw == "1" ? "On" : "Adaptive";
            if (String.Equals(key, "EECycleRate", StringComparison.OrdinalIgnoreCase))
            {
                if (raw == "-1") return "Underclock";
                if (raw == "0") return "Normal (100%)";
                return "Overclock Level " + raw;
            }
            if (String.Equals(key, "EECycleSkip", StringComparison.OrdinalIgnoreCase))
            {
                if (raw == "0") return "Disabled";
                if (raw == "1") return "Mild";
                if (raw == "2") return "Moderate";
                return "Maximum";
            }
            if (String.Equals(key, "MaxAnisotropy", StringComparison.OrdinalIgnoreCase))
                return raw == "0" ? "Off" : raw + "×";
            if (String.Equals(key, "Latency", StringComparison.OrdinalIgnoreCase)) return raw + " ms";
            if (String.Equals(key, "SynchMode", StringComparison.OrdinalIgnoreCase))
                return raw == "0" ? "TimeStretch" : raw == "1" ? "Asynchronous Mix" : "No Synchronization";
            if (String.Equals(key, "FinalVolume", StringComparison.OrdinalIgnoreCase)) return raw + "%";
            if (String.Equals(key, "OutputModule", StringComparison.OrdinalIgnoreCase))
                return raw.Equals("Null", StringComparison.OrdinalIgnoreCase) ? "No Audio" : raw.Equals("cubeb", StringComparison.OrdinalIgnoreCase) ? "Cubeb" : raw;
            if (String.Equals(key, "ButtonDeadzone", StringComparison.OrdinalIgnoreCase))
            {
                double number; if (Double.TryParse(raw, NumberStyles.Float, CultureInfo.InvariantCulture, out number)) return (number * 100.0).ToString("0", CultureInfo.InvariantCulture) + "%";
            }
            if (String.Equals(key, "AxisScale", StringComparison.OrdinalIgnoreCase))
            {
                double number; if (Double.TryParse(raw, NumberStyles.Float, CultureInfo.InvariantCulture, out number)) return (number * 100.0).ToString("0", CultureInfo.InvariantCulture) + "%";
            }
            if (String.Equals(key, "Type", StringComparison.OrdinalIgnoreCase))
                return raw.Equals("DualShock2", StringComparison.OrdinalIgnoreCase) ? "DualShock 2" : raw;
            return raw;
        }

        private List<BbnItem> BuildPerGameItems()
        {
            List<BbnItem> result = new List<BbnItem>();
            foreach (Ps2Game game in games)
            {
                string serial = String.IsNullOrWhiteSpace(game.Serial) ? MakeSafeName(Path.GetFileNameWithoutExtension(game.Path)) : game.Serial;
                result.Add(new BbnItem(game.Title, serial, null, new List<BbnItem> {
                    new BbnItem("Emulation", "Native PCSX2 override", null, BuildEmulationSettings(true, serial)),
                    new BbnItem("Graphics", "Native PCSX2 override", null, BuildGraphicsSettings(true, serial)),
                    new BbnItem("Audio", "Native PCSX2 override", null, BuildAudioSettings(true, serial)),
                    new BbnItem("Controller", "Native PCSX2 override", null, BuildControllerSettings(true, serial)),
                    new BbnItem("Network", "Native PCSX2 override", null, BuildNetworkSettings(true, serial))
                }));
            }
            if (result.Count == 0) result.Add(new BbnItem("No games available", "Run a library scan first", "Rescan"));
            return result;
        }

        private List<BbnItem> BuildLibraryFolderItems()
        {
            List<BbnItem> result = new List<BbnItem>();
            result.Add(new BbnItem("Add Game Library Folder", "Add ISO, CHD, CSO, BIN or ELF games", "AddLibrary"));
            foreach (string path in settings.libraryRoots)
            {
                result.Add(new BbnItem(Path.GetFileName(path), path, null, new List<BbnItem> {
                    new BbnItem("Remove from PlayStation 2", "Unregister only; files are not deleted", "RemoveLibrary|" + Encode(path)),
                    new BbnItem("Open Folder", path, "OpenPath|" + Encode(path))
                }));
            }
            return result;
        }

        private void RefreshSaveVisuals()
        {
            try
            {
                saveVisuals = Ps2SaveVisualScanner.Scan(GetMemoryCardFolder());
                WriteLog("PS2 saved-data background loaded " + saveVisuals.Count + " data shape(s).", "INFO");
                if (surface != null) surface.InvalidateVisual();
            }
            catch (Exception ex)
            {
                saveVisuals = new List<Ps2SaveVisual>();
                WriteLog("PS2 saved-data background scan failed: " + ex.Message, "WARN");
            }
        }

        private List<BbnItem> BuildMemoryCardItems()
        {
            List<BbnItem> result = new List<BbnItem>();
            foreach (Ps2MemoryCard card in ScanMemoryCards())
            {
                string encoded = Encode(card.Path);
                string slotText = GetMemoryCardSlotText(card.Path);
                BbnItem item = new BbnItem(card.Name, card.Subtitle + slotText, "OpenCard|" + encoded);
                item.MemoryCardPath = card.Path;
                item.Children = BuildMemoryCardOptions(card.Path);
                result.Add(item);
            }
            result.Add(new BbnItem("Create 8 MB Memory Card", "Creates an unformatted card PCSX2 can initialize", "CreateMemoryCard"));
            result.Add(new BbnItem("Refresh Memory Cards", GetMemoryCardFolder(), "RefreshMemoryCards"));
            result.Add(new BbnItem("Backups", GetMemoryBackupRoot(), "OpenPath|" + Encode(GetMemoryBackupRoot())));
            return result;
        }

        private List<BbnItem> BuildMemoryCardOptions(string cardPath)
        {
            string encoded = Encode(cardPath);
            List<BbnItem> actions = new List<BbnItem> {
                new BbnItem("Browse Saved Data", "Open this memory card in the Huymaier PS2 Browser", "OpenCard|" + encoded),
                new BbnItem("Use in Slot 1", "Select this card for PS2 memory-card slot 1", "CardSlot1|" + encoded),
                new BbnItem("Use in Slot 2", "Select this card for PS2 memory-card slot 2", "CardSlot2|" + encoded),
                new BbnItem("Back Up", "Create a timestamped Huymaier backup", "CardBackup|" + encoded),
                new BbnItem("Export Copy", "Copy this memory card to another folder", "CardExport|" + encoded),
                new BbnItem("Open Location", cardPath, "OpenPath|" + encoded),
                new BbnItem("Move to Save Trash", "Recoverable removal; game files are untouched", "CardTrash|" + encoded)
            };
            return actions;
        }

        private List<BbnItem> BuildMemoryCardSaveItems(string cardPath, out string freeText)
        {
            freeText = String.Empty;
            if (Directory.Exists(cardPath))
            {
                freeText = "Folder Memory Card";
                return BuildFolderCardSaveItems(cardPath);
            }
            List<Ps2CardSaveEntry> entries;
            long freeBytes;
            string error;
            if (Ps2MemoryCardImageReader.TryRead(cardPath, out entries, out freeBytes, out error))
            {
                freeText = FormatBytes(freeBytes) + " free";
                List<BbnItem> result = new List<BbnItem>();
                foreach (Ps2CardSaveEntry entry in entries)
                {
                    string subtitle = FormatBytes(entry.SizeBytes) + " • " + entry.FileCount + " file" + (entry.FileCount == 1 ? String.Empty : "s");
                    if (entry.Modified != DateTime.MinValue) subtitle += " • " + entry.Modified.ToString("g");
                    BbnItem item = new BbnItem(String.IsNullOrWhiteSpace(entry.Title) ? entry.DirectoryName : entry.Title,
                        subtitle, null, BuildRawSaveOptions(cardPath, entry));
                    item.SaveEntry = entry;
                    item.MemoryCardPath = cardPath;
                    item.SaveIcon = entry.IconModel;
                    result.Add(item);
                }
                if (result.Count == 0) result.Add(new BbnItem("No saved data found", Path.GetFileName(cardPath), null));
                return result;
            }
            freeText = "Could not read card";
            return new List<BbnItem> { new BbnItem("Memory card could not be read", error, null) };
        }

        private List<BbnItem> BuildRawSaveOptions(string cardPath, Ps2CardSaveEntry entry)
        {
            return BuildNativeSaveOptions(cardPath, entry, String.Empty);
        }

        private List<BbnItem> BuildNativeSaveOptions(string cardPath, Ps2CardSaveEntry entry, string folderSavePath)
        {
            string card = Encode(cardPath);
            string directory = Encode(entry == null ? String.Empty : entry.DirectoryName);
            List<BbnItem> copyTargets = new List<BbnItem>();
            foreach (Ps2MemoryCard target in ScanMemoryCards())
            {
                if (String.Equals(Path.GetFullPath(target.Path), Path.GetFullPath(cardPath), StringComparison.OrdinalIgnoreCase)) continue;
                copyTargets.Add(new BbnItem("Copy to " + target.Name,
                    Directory.Exists(target.Path) ? "Editable folder memory card" : "Will create an editable folder-card mirror safely",
                    "SaveCopyNative|" + card + "|" + directory + "|" + Encode(target.Path)));
            }
            if (copyTargets.Count == 0) copyTargets.Add(new BbnItem("No other memory card found", "Create or add another card first", null));
            List<BbnItem> result = new List<BbnItem> {
                new BbnItem("Saved Data Details", entry == null ? String.Empty : entry.DetailText, null),
                new BbnItem("Copy to Another Memory Card", "Choose a destination card", null, copyTargets),
                new BbnItem("Back Up Saved Data", "Create a timestamped backup", "SaveBackupNative|" + card + "|" + directory),
                new BbnItem("Export Saved Data", "Copy this save to a folder you choose", "SaveExportNative|" + card + "|" + directory),
                new BbnItem("Delete Saved Data", "Move this save to recoverable Save Trash", "SaveDeleteNative|" + card + "|" + directory)
            };
            if (!String.IsNullOrWhiteSpace(folderSavePath))
                result.Insert(4, new BbnItem("Open Save Folder", folderSavePath, "OpenPath|" + Encode(folderSavePath)));
            return result;
        }

        private List<BbnItem> BuildMediaItems(bool music)
        {
            string folder = music ? settings.musicFolder : settings.movieFolder;
            List<BbnItem> result = new List<BbnItem>();
            result.Add(new BbnItem(music ? "Choose Music Folder" : "Choose Movie Folder",
                String.IsNullOrWhiteSpace(folder) ? "Not configured" : folder, music ? "ChooseMusicFolder" : "ChooseMovieFolder"));
            if (String.IsNullOrWhiteSpace(folder) || !Directory.Exists(folder)) return result;
            HashSet<string> extensions = music
                ? new HashSet<string>(new string[] { ".mp3", ".wav", ".wma", ".m4a", ".flac", ".ogg" }, StringComparer.OrdinalIgnoreCase)
                : new HashSet<string>(new string[] { ".mp4", ".m4v", ".mkv", ".avi", ".wmv", ".mov", ".mpeg", ".mpg" }, StringComparer.OrdinalIgnoreCase);
            try
            {
                foreach (string file in Directory.EnumerateFiles(folder, "*.*", SearchOption.AllDirectories)
                    .Where(delegate(string path) { return extensions.Contains(Path.GetExtension(path)); }).Take(256))
                    result.Add(new BbnItem(Path.GetFileNameWithoutExtension(file), file,
                        (music ? "PlayMusic|" : "PlayMovie|") + Encode(file)));
            }
            catch { }
            return result;
        }

        private void MoveChannel(int delta)
        {
            if (channels == null || channels.Count == 0) return;
            channelIndex = Math.Max(0, Math.Min(channels.Count - 1, channelIndex + delta));
            settings.lastChannel = channels[channelIndex].Id;
            settings.Save(settingsPath);
        }

        private void EnterChannel()
        {
            if (channels == null || channels.Count == 0 || channelIndex < 0 || channelIndex >= channels.Count) return;
            topMenuActive = false;
            menuStack.Clear();
            selectedIndex = Math.Max(0, Math.Min(channels[channelIndex].Items.Count - 1, channels[channelIndex].SelectedIndex));
            visualItem = selectedIndex;
            gameLetterFocus = false;
            if (channels[channelIndex].Id == "GameCollection") SyncGameLetterToSelection();
            surface.InvalidateVisual();
        }

        private void MoveVertical(int delta)
        {
            List<BbnItem> items = CurrentItems;
            if (items.Count == 0) return;
            selectedIndex = Math.Max(0, Math.Min(items.Count - 1, selectedIndex + delta));
        }

        private void InvokeSelected()
        {
            BbnItem item = CurrentItem;
            if (item == null) return;
            if (item.Game != null) { BeginGameLaunch(item.Game); return; }
            if (!String.IsNullOrWhiteSpace(item.Action) && item.Action.StartsWith("OpenCard|", StringComparison.Ordinal))
            {
                InvokeAction(item.Action, item);
                return;
            }
            if (item.Children != null && item.Children.Count > 0)
            {
                bool memoryOptions = MemoryBrowserActive;
                string cardPath = menuStack.Count > 0 ? menuStack.Peek().MemoryCardPath : item.MemoryCardPath;
                string freeText = menuStack.Count > 0 ? menuStack.Peek().MemoryCardFreeText : String.Empty;
                menuStack.Push(new BbnMenuContext(item.Title, item.Children, selectedIndex, MemoryBrowserActive,
                    false, cardPath, freeText, memoryOptions));
                selectedIndex = 0;
                visualItem = 0;
                return;
            }
            InvokeAction(item.Action, item);
        }

        private void NavigateBack()
        {
            if (menuStack.Count > 0)
            {
                BbnMenuContext context = menuStack.Pop();
                selectedIndex = context.ParentSelection;
                visualItem = selectedIndex;
                return;
            }
            if (!topMenuActive)
            {
                if (channels != null && channelIndex >= 0 && channelIndex < channels.Count)
                    channels[channelIndex].SelectedIndex = selectedIndex;
                topMenuActive = true;
                visualChannel = channelIndex;
                surface.InvalidateVisual();
                return;
            }
            Close();
        }

        private void InvokeAction(string action, BbnItem item)
        {
            if (String.IsNullOrWhiteSpace(action)) return;
            if (action.StartsWith("P2Cfg|", StringComparison.Ordinal)) { CycleConfig(action, item); return; }
            if (action.StartsWith("RemoveLibrary|", StringComparison.Ordinal)) { RemoveLibrary(Decode(action.Substring(14))); return; }
            if (action.StartsWith("OpenPath|", StringComparison.Ordinal)) { OpenPath(Decode(action.Substring(9))); return; }
            if (action.StartsWith("OpenFolder|", StringComparison.Ordinal)) { OpenConfiguredFolder(action.Substring(11)); return; }
            if (action.StartsWith("CardBackup|", StringComparison.Ordinal)) { BackupCard(Decode(action.Substring(11))); return; }
            if (action.StartsWith("CardExport|", StringComparison.Ordinal)) { ExportCard(Decode(action.Substring(11))); return; }
            if (action.StartsWith("CardTrash|", StringComparison.Ordinal)) { TrashCard(Decode(action.Substring(10))); return; }
            if (action.StartsWith("OpenCard|", StringComparison.Ordinal)) { OpenMemoryCard(Decode(action.Substring(9))); return; }
            if (action.StartsWith("RawSaveExport|", StringComparison.Ordinal)) { ExportRawSave(action.Substring(14)); return; }
            if (action.StartsWith("SaveCopyNative|", StringComparison.Ordinal)) { CopyNativeSave(action.Substring(15)); return; }
            if (action.StartsWith("SaveBackupNative|", StringComparison.Ordinal)) { BackupNativeSave(action.Substring(17)); return; }
            if (action.StartsWith("SaveExportNative|", StringComparison.Ordinal)) { ExportNativeSave(action.Substring(17)); return; }
            if (action.StartsWith("SaveDeleteNative|", StringComparison.Ordinal)) { DeleteNativeSave(action.Substring(17)); return; }
            if (action.StartsWith("ViewPhoto|", StringComparison.Ordinal)) { OpenPhotoViewer(Decode(action.Substring(10))); return; }
            if (action.StartsWith("PlayMusic|", StringComparison.Ordinal)) { PlayMedia(Decode(action.Substring(10)), false); return; }
            if (action.StartsWith("PlayMovie|", StringComparison.Ordinal)) { PlayMedia(Decode(action.Substring(10)), true); return; }
            if (action.StartsWith("CardSlot1|", StringComparison.Ordinal)) { AssignMemoryCard(1, Decode(action.Substring(10))); return; }
            if (action.StartsWith("CardSlot2|", StringComparison.Ordinal)) { AssignMemoryCard(2, Decode(action.Substring(10))); return; }
            if (action.StartsWith("SaveBackup2|", StringComparison.Ordinal)) { BackupSave(Decode(action.Substring(12))); return; }
            if (action.StartsWith("SaveExport2|", StringComparison.Ordinal)) { ExportSave(Decode(action.Substring(12))); return; }
            if (action.StartsWith("SaveTrash2|", StringComparison.Ordinal)) { TrashSave(Decode(action.Substring(11))); return; }
            switch (action)
            {
                case "Exit": Close(); break;
                case "ChoosePcsx2": ChoosePcsx2(); break;
                case "FullPcsx2Settings": OpenFullPcsx2Settings(); break;
                case "InstallPcsx2": InstallPcsx2(); break;
                case "ChooseDataRoot": ChooseDataRoot(); break;
                case "RescanConfiguration": RescanConfiguration(); break;
                case "ChooseBios": ChooseBios(); break;
                case "AddLibrary": AddLibrary(); break;
                case "Rescan": BeginScan(true); break;
                case "FocusGames": channelIndex = 0; selectedIndex = 0; visualItem = 0; menuStack.Clear(); break;
                case "OpenMemoryCards": OpenMemoryCards(); break;
                case "RefreshMemoryCards": RefreshMemoryCards(); break;
                case "CreateMemoryCard": CreateMemoryCard(); break;
                case "ChooseScreenshotFolder": ChooseScreenshotFolder(); break;
                case "RefreshPhotos": BeginPhotoScan(); break;
                case "ChooseMusicFolder": ChooseMediaFolder(true); break;
                case "ChooseMovieFolder": ChooseMediaFolder(false); break;
                case "ChooseAssets": ChooseAssetFolder(); break;
                case "AssetDefault":
                case "ClearAssets": settings.customAssetFolder = String.Empty; settings.Save(settingsPath); imageCache.Clear(); ShowNotice("PlayStation 2 default appearance restored"); break;
                case "ClearCache": ClearCache(); break;
                case "MapPadXInput": ApplyControllerPreset(false); break;
                case "MapPadSDL": ApplyControllerPreset(true); break;
                case "ClearPad1": ClearControllerMappings("Pad1"); break;
                case "OpenPcsx2": OpenPcsx2(); break;
                case "TogglePcsx2Overlay": settings.pcsx2OverlayEnabled = !settings.pcsx2OverlayEnabled; settings.Save(settingsPath); RefreshSettingsChannel(); ShowNotice("PCSX2 overlay " + (settings.pcsx2OverlayEnabled ? "enabled" : "disabled")); break;
                case "TogglePs2StartupVideo": settings.ps2StartupVideoEnabled = !settings.ps2StartupVideoEnabled; settings.Save(settingsPath); RefreshSettingsChannel(); ShowNotice("PS2 startup video " + (settings.ps2StartupVideoEnabled ? "enabled" : "disabled")); break;
                case "TogglePs2Bgm": settings.ps2BackgroundMusicEnabled = !settings.ps2BackgroundMusicEnabled; settings.Save(settingsPath); StartBackgroundMusic(); RefreshSettingsChannel(); break;
                case "ImportPs2Bgm": ChooseInterfaceAudio("bgm"); break;
                case "TogglePs2GameBoot": settings.ps2GameBootSoundEnabled = !settings.ps2GameBootSoundEnabled; settings.Save(settingsPath); RefreshSettingsChannel(); break;
                case "ImportPs2GameBoot": ChooseInterfaceAudio("gameboot"); break;
                case "ClearPs2Bgm": settings.ps2BackgroundMusicPath = String.Empty; settings.Save(settingsPath); StartBackgroundMusic(); RefreshSettingsChannel(); break;
                case "CyclePs2BgmVolume": CycleInterfaceVolume(true); break;
                case "TogglePs2Sfx": settings.ps2SoundEffectsEnabled = !settings.ps2SoundEffectsEnabled; settings.Save(settingsPath); RefreshSettingsChannel(); break;
                case "ImportPs2Navigate": ChooseInterfaceAudio("navigate"); break;
                case "ImportPs2Confirm": ChooseInterfaceAudio("confirm"); break;
                case "ImportPs2Back": ChooseInterfaceAudio("back"); break;
                case "CyclePs2SfxVolume": CycleInterfaceVolume(false); break;
                case "ClearPs2BootAudio": settings.ps2GameBootSoundPath = String.Empty; settings.Save(settingsPath); RefreshSettingsChannel(); ShowNotice("Game boot audio cleared"); break;
                case "RestorePs2Sfx": settings.ps2NavigateSoundPath = String.Empty; settings.ps2ConfirmSoundPath = String.Empty; settings.ps2BackSoundPath = String.Empty; settings.Save(settingsPath); RefreshSettingsChannel(); ShowNotice("Default interface sounds restored"); break;
            }
        }

        private static readonly string[] PadBindingKeys = new string[] {
            "Up", "Right", "Down", "Left", "Triangle", "Circle", "Cross", "Square", "Select", "Start",
            "L1", "L2", "R1", "R2", "L3", "R3", "LUp", "LRight", "LDown", "LLeft",
            "RUp", "RRight", "RDown", "RLeft", "LargeMotor", "SmallMotor", "Analog"
        };

        private void ApplyControllerPreset(bool sdl)
        {
            try
            {
                SimpleIniFile ini = GetIni(false, String.Empty);
                ini.Set("InputSources", "SDL", sdl ? "true" : "false");
                ini.Set("InputSources", "XInput", sdl ? "false" : "true");
                ini.Set("InputSources", "DInput", "false");
                ini.Set("InputSources", "SDLControllerEnhancedMode", sdl ? "true" : "false");
                ini.Set("Pad1", "Type", "DualShock2");
                Dictionary<string, string> bindings = GetStandardPadBindings(sdl ? "SDL-0" : "XInput-0");
                foreach (KeyValuePair<string, string> pair in bindings) ini.Set("Pad1", pair.Key, pair.Value);
                RefreshSettingsChannel();
                ShowNotice(sdl ? "DualSense / DualShock SDL mapping applied" : "Xbox / XInput mapping applied");
            }
            catch (Exception ex) { ShowNotice("Controller mapping failed: " + ex.Message); }
        }

        private void ClearControllerMappings(string section)
        {
            try
            {
                SimpleIniFile ini = GetIni(false, String.Empty);
                foreach (string key in PadBindingKeys) ini.Set(section, key, String.Empty);
                RefreshSettingsChannel();
                ShowNotice("Controller Port 1 mappings cleared");
            }
            catch (Exception ex) { ShowNotice("Controller mappings could not be cleared: " + ex.Message); }
        }

        private static Dictionary<string, string> GetStandardPadBindings(string source)
        {
            return new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase) {
                { "Up", source + "/DPadUp" }, { "Right", source + "/DPadRight" },
                { "Down", source + "/DPadDown" }, { "Left", source + "/DPadLeft" },
                { "Triangle", source + "/Y" }, { "Circle", source + "/B" },
                { "Cross", source + "/A" }, { "Square", source + "/X" },
                { "Select", source + "/Back" }, { "Start", source + "/Start" },
                { "L1", source + "/LeftShoulder" }, { "L2", source + "/+LeftTrigger" },
                { "R1", source + "/RightShoulder" }, { "R2", source + "/+RightTrigger" },
                { "L3", source + "/LeftStick" }, { "R3", source + "/RightStick" },
                { "LUp", source + "/-LeftY" }, { "LRight", source + "/+LeftX" },
                { "LDown", source + "/+LeftY" }, { "LLeft", source + "/-LeftX" },
                { "RUp", source + "/-RightY" }, { "RRight", source + "/+RightX" },
                { "RDown", source + "/+RightY" }, { "RLeft", source + "/-RightX" },
                { "LargeMotor", source + "/LargeMotor" }, { "SmallMotor", source + "/SmallMotor" },
                { "Analog", source + "/Guide" }
            };
        }

        private void CycleConfig(string action, BbnItem item)
        {
            try
            {
                string[] parts = action.Split('|');
                if (parts.Length != 6) return;
                bool perGame = parts[1] == "G";
                string serial = Decode(parts[2]);
                string section = Decode(parts[3]);
                string key = Decode(parts[4]);
                string[] options = Decode(parts[5]).Split(new char[] { '\u001f' }, StringSplitOptions.RemoveEmptyEntries);
                if (options.Length == 0) return;
                string current = GetConfigValue(perGame, serial, section, key, options[0]);
                int index = Array.FindIndex(options, delegate(string value) { return String.Equals(value, current, StringComparison.OrdinalIgnoreCase); });
                string next = options[(index + 1 + options.Length) % options.Length];
                GetIni(perGame, serial).Set(section, key, next);
                string display = FormatPcsx2Option(section, key, next);
                item.Subtitle = display;
                ShowNotice(item.Title + " — " + display);
            }
            catch (Exception ex)
            {
                WriteLog("PCSX2 setting update failed: " + ex, "ERROR");
                ShowNotice("Setting could not be saved: " + ex.Message);
            }
        }

        private string GetConfigValue(bool perGame, string serial, string section, string key, string fallback)
        {
            try { return GetIni(perGame, serial).Get(section, key, fallback); }
            catch { return fallback; }
        }

        private SimpleIniFile GetIni(bool perGame, string serial)
        {
            string root = GetDataRoot();
            string path;
            if (perGame)
            {
                string folder = Path.Combine(root, "gamesettings");
                Directory.CreateDirectory(folder);
                path = Path.Combine(folder, MakeSafeName(serial) + ".ini");
            }
            else path = Pcsx2PathResolver.FindIniPath(root);
            return new SimpleIniFile(path, Path.Combine(appDataRoot, "ConfigBackups"));
        }


        private void LoadCachedLibrary()
        {
            if (!File.Exists(libraryCachePath)) return;
            try
            {
                JavaScriptSerializer serializer = new JavaScriptSerializer();
                serializer.MaxJsonLength = Int32.MaxValue;
                List<Dictionary<string, string>> rows = serializer.Deserialize<List<Dictionary<string, string>>>(
                    File.ReadAllText(libraryCachePath, Encoding.UTF8));
                if (rows == null) return;
                List<Ps2Game> cached = new List<Ps2Game>();
                foreach (Dictionary<string, string> row in rows.Take(20000))
                {
                    string path = ReadCacheValue(row, "Path");
                    if (String.IsNullOrWhiteSpace(path) || !File.Exists(path)) continue;
                    cached.Add(new Ps2Game {
                        Title = ReadCacheValue(row, "Title"),
                        Serial = ReadCacheValue(row, "Serial"),
                        Path = path,
                        CoverPath = ReadCacheValue(row, "CoverPath")
                    });
                }
                games = cached;
                if (games.Count > 0)
                    WriteLog("Loaded " + games.Count + " cached PlayStation 2 game(s) before background refresh.", "INFO");
            }
            catch (Exception ex)
            {
                WriteLog("PS2 library cache could not be loaded: " + ex.Message, "WARN");
            }
        }

        private void SaveCachedLibrary()
        {
            try
            {
                List<Dictionary<string, string>> rows = new List<Dictionary<string, string>>();
                foreach (Ps2Game game in games.Take(20000))
                {
                    rows.Add(new Dictionary<string, string> {
                        { "Title", game.Title ?? String.Empty },
                        { "Serial", game.Serial ?? String.Empty },
                        { "Path", game.Path ?? String.Empty },
                        { "CoverPath", game.CoverPath ?? String.Empty }
                    });
                }
                JavaScriptSerializer serializer = new JavaScriptSerializer();
                serializer.MaxJsonLength = Int32.MaxValue;
                File.WriteAllText(libraryCachePath, serializer.Serialize(rows), Encoding.UTF8);
            }
            catch (Exception ex)
            {
                WriteLog("PS2 library cache could not be saved: " + ex.Message, "WARN");
            }
        }

        private static string ReadCacheValue(Dictionary<string, string> row, string key)
        {
            if (row == null) return String.Empty;
            string value;
            return row.TryGetValue(key, out value) ? value ?? String.Empty : String.Empty;
        }

        private void BeginScan(bool showNotice)
        {
            if (scanRunning) { if (showNotice) ShowNotice("A PlayStation 2 scan is already running"); return; }
            scanRunning = true;
            if (showNotice) ShowNotice("Scanning PlayStation 2 games...");
            Ps2Settings snapshot = settings.Clone();
            ThreadPool.QueueUserWorkItem(delegate
            {
                List<Ps2Game> scanned = new List<Ps2Game>();
                string error = String.Empty;
                try { scanned = Ps2LibraryScanner.Scan(snapshot, GetDataRoot(), WriteLog); }
                catch (Exception ex) { error = ex.Message; WriteLog("PS2 library scan failed: " + ex, "ERROR"); }
                Dispatcher.BeginInvoke(new Action(delegate
                {
                    scanRunning = false;
                    if (closing) return;
                    if (!String.IsNullOrWhiteSpace(error)) ShowNotice("Game scan failed: " + error);
                    games = scanned;
                    RebuildGameItems();
                    SaveCachedLibrary();
                    WriteLibrarySummary();
                    if (showNotice) ShowNotice(games.Count + " PlayStation 2 game" + (games.Count == 1 ? "" : "s") + " found");
                }));
            });
        }

        private static char GetGameBucket(string title)
        {
            string value = (title ?? String.Empty).Trim();
            if (value.Length == 0) return '#';
            char first = Char.ToUpperInvariant(value[0]);
            return first >= 'A' && first <= 'Z' ? first : '#';
        }

        private void SyncGameLetterToSelection()
        {
            BbnItem current = CurrentItem;
            char bucket = current != null && current.Game != null ? GetGameBucket(current.Game.Title) : '#';
            gameLetterIndex = Math.Max(0, GameLetters.IndexOf(bucket));
        }

        private void MoveGameLetter(int delta)
        {
            gameLetterIndex = Math.Max(0, Math.Min(GameLetters.Length - 1, gameLetterIndex + delta));
            surface.InvalidateVisual();
        }

        private void JumpToGameLetter(int index, bool leaveFocus)
        {
            if (index < 0 || index >= GameLetters.Length) return;
            char bucket = GameLetters[index];
            int target = CurrentItems.FindIndex(delegate(BbnItem item)
            {
                return item != null && item.Game != null && GetGameBucket(item.Game.Title) == bucket;
            });
            if (target < 0)
            {
                ShowNotice("No games under " + bucket);
                return;
            }
            selectedIndex = target;
            visualItem = target;
            gameLetterIndex = index;
            if (leaveFocus) gameLetterFocus = false;
            surface.InvalidateVisual();
        }

        private void JumpToAdjacentGameLetter(int delta)
        {
            SyncGameLetterToSelection();
            int index = gameLetterIndex;
            for (int attempt = 0; attempt < GameLetters.Length; attempt++)
            {
                index += delta;
                if (index < 0 || index >= GameLetters.Length) return;
                if (!HasGamesForLetter(index)) continue;
                JumpToGameLetter(index, true);
                return;
            }
        }

        private void RebuildGameItems()
        {
            BbnChannel channel = channels.FirstOrDefault(delegate(BbnChannel c) { return c.Id == "GameCollection"; });
            if (channel == null) return;
            channel.Items.Clear();
            games = games.OrderBy(delegate(Ps2Game game) { return GetGameBucket(game == null ? String.Empty : game.Title) == '#' ? 0 : 1; })
                .ThenBy(delegate(Ps2Game game) { return game == null ? String.Empty : game.Title; }, StringComparer.CurrentCultureIgnoreCase).ToList();
            foreach (Ps2Game game in games)
                channel.Items.Add(new BbnItem(game.Title, String.IsNullOrWhiteSpace(game.Serial) ? Path.GetFileName(game.Path) : game.Serial, null, null, game));
            if (channel.Items.Count == 0)
                channel.Items.Add(new BbnItem("No PlayStation 2 games found", "Add a library folder in Settings", "AddLibrary"));
            selectedIndex = Math.Max(0, Math.Min(selectedIndex, channel.Items.Count - 1));
            SyncGameLetterToSelection();
            BbnChannel browser = channels.FirstOrDefault(delegate(BbnChannel c) { return c.Id == "Browser"; });
            if (browser != null && browser.Items.Count > 0)
                browser.Items[0].Subtitle = games.Count + " game" + (games.Count == 1 ? "" : "s");
            RefreshSettingsChannel();
        }

        private void RefreshSettingsChannel()
        {
            BbnChannel settingsChannel = channels.FirstOrDefault(delegate(BbnChannel c) { return c.Id == "Settings"; });
            if (settingsChannel != null) settingsChannel.Items = BuildSettingsItems();
            BbnChannel memory = channels.FirstOrDefault(delegate(BbnChannel c) { return c.Id == "MemoryCards"; });
            if (memory != null) memory.Items = BuildMemoryCardItems();
        }

        private void WriteLibrarySummary()
        {
            try
            {
                JavaScriptSerializer serializer = new JavaScriptSerializer();
                File.WriteAllText(Path.Combine(appDataRoot, "library-summary.json"), serializer.Serialize(new Dictionary<string, object> {
                    { "Count", games.Count }, { "UpdatedAt", DateTime.Now.ToString("o") }, { "Error", String.Empty }
                }), Encoding.UTF8);
            }
            catch { }
        }

        private void ReturnToPs2MainMenu()
        {
            menuStack.Clear();
            gameLetterFocus = false;
            topMenuActive = true;
            int gameChannel = channels == null ? -1 : channels.FindIndex(delegate(BbnChannel channel)
            {
                return String.Equals(channel.Id, "GameCollection", StringComparison.OrdinalIgnoreCase);
            });
            if (gameChannel >= 0) channelIndex = gameChannel;
            selectedIndex = 0;
            visualChannel = channelIndex;
            visualItem = 0;
            try
            {
                if (channels != null && channelIndex >= 0 && channelIndex < channels.Count)
                {
                    settings.lastChannel = channels[channelIndex].Id;
                    settings.Save(settingsPath);
                }
            }
            catch { }
            if (surface != null) surface.InvalidateVisual();
        }

        private void LaunchGame(Ps2Game game)
        {
            string executable = GetPcsx2Executable();
            if (String.IsNullOrWhiteSpace(executable) || !File.Exists(executable))
            {
                ShowNotice("Select a PCSX2 installation first");
                return;
            }
            if (game == null || String.IsNullOrWhiteSpace(game.Path) || !File.Exists(game.Path))
            {
                ShowNotice("Game file is unavailable: " + (game == null ? String.Empty : game.Path));
                return;
            }
            try
            {
                ProcessStartInfo info = new ProcessStartInfo();
                info.FileName = executable;
                info.WorkingDirectory = Path.GetDirectoryName(executable);
                info.UseShellExecute = false;
                info.CreateNoWindow = true;
                info.Arguments = BuildPcsx2GameArguments(game.Path);

                DateTime launchedUtc = DateTime.UtcNow;
                Process process = Process.Start(info);
                if (process == null) throw new InvalidOperationException("Windows did not return a PCSX2 process.");
                activeEmulatorProcess = process;
                inputSuspended = true;
                try { mediaPlayer.Pause(); } catch { }
                try { backgroundMusicPlayer.Pause(); } catch { }
                WriteLog("Launched PCSX2: " + info.FileName + " " + info.Arguments, "INFO");
                Hide();
                ThreadPool.QueueUserWorkItem(delegate
                {
                    string waitError = String.Empty;
                    int exitCode = Int32.MinValue;
                    try
                    {
                        process.WaitForExit();
                        exitCode = process.ExitCode;
                    }
                    catch (Exception ex) { waitError = ex.Message; }
                    TimeSpan runtime = DateTime.UtcNow - launchedUtc;
                    Dispatcher.BeginInvoke(new Action(delegate
                    {
                        if (closing) return;
                        ReturnToPs2MainMenu();
                        Show();
                        WindowStyle = WindowStyle.None;
                        ResizeMode = ResizeMode.NoResize;
                        WindowState = settings.fullscreen ? WindowState.Maximized : WindowState.Normal;
                        NativeWindowActivation.Restore(this);
                        input.Reset();
                        inputSuspended = false;
                        try { mediaPlayer.Play(); } catch { }
                        if (backgroundMusicPlaying) try { backgroundMusicPlayer.Play(); } catch { }
                        RefreshSaveVisuals();
                        if (!String.IsNullOrWhiteSpace(waitError))
                            ShowNotice("PCSX2 return error: " + waitError);
                        else if (runtime.TotalSeconds < 8.0 && exitCode != 0)
                            ShowNotice("PCSX2 exited immediately with code " + exitCode + ". Check the PS2 diagnostics log.");
                        else
                            ShowNotice("Returned from " + game.Title);
                    }));
                });
            }
            catch (Exception ex)
            {
                inputSuspended = false;
                NativeWindowActivation.Restore(this);
                try { mediaPlayer.Play(); } catch { }
                if (backgroundMusicPlaying) try { backgroundMusicPlayer.Play(); } catch { }
                WriteLog("PCSX2 launch failed: " + ex, "ERROR");
                ShowNotice("Game could not start: " + ex.Message);
            }
        }

        private static string BuildPcsx2GameArguments(string gamePath)
        {
            return "-batch -bigpicture -fullscreen -- " + Quote(gamePath);
        }

        private void OpenFullPcsx2Settings()
        {
            NativeBackendSettingsWindow.Show(this, consoleRoot, "PS2", "PlayStation 2", "PCSX2", settingsPath);
            NativeConsoleNavigation.Reset();
            RefreshSettingsChannel();
        }

        private void ChoosePcsx2()
        {
            string start = settings.pcsx2Path;
            try { if (File.Exists(start)) start = Path.GetDirectoryName(start); } catch { }
            HuymaierNativePickerRequest.Request(this, "PS2", "PlayStation 2", "PrimaryEmulator", "PCSX2", start);
        }

        private void InstallPcsx2()
        {
            HuymaierNativePickerRequest.Request(this, "PS2", "PlayStation 2", "InstallPrimaryEmulator", "PCSX2", settings.managedInstallFolder);
        }

        private void ChooseDataRoot()
        {
            HuymaierNativePickerRequest.Request(this, "PS2", "PlayStation 2", "DataRoot", "PCSX2", GetDataRoot());
        }

        private void RescanConfiguration()
        {
            settings.pcsx2DataPath = Pcsx2PathResolver.FindDataRoot(GetPcsx2Executable(), settings.pcsx2DataPath);
            ImportConfiguredLibraryRoots();
            settings.Save(settingsPath);
            BuildChannels();
            RefreshSaveVisuals();
            BeginScan(true);
            BeginPhotoScan();
        }

        private void ImportConfiguredLibraryRoots()
        {
            string iniPath = Pcsx2PathResolver.FindIniPath(GetDataRoot());
            SimpleIniFile ini = new SimpleIniFile(iniPath, Path.Combine(appDataRoot, "ConfigBackups"));
            string paths = ini.Get("GameList", "RecursivePaths", String.Empty);
            foreach (string path in SplitPaths(paths))
            {
                string expanded = ResolveRelative(path, GetDataRoot());
                if (Directory.Exists(expanded) && !settings.libraryRoots.Any(delegate(string existing)
                    { return String.Equals(existing, expanded, StringComparison.OrdinalIgnoreCase); }))
                    settings.libraryRoots.Add(expanded);
            }
            settings.Normalize();
        }

        private void AddLibrary()
        {
            HuymaierNativePickerRequest.Request(this, "PS2", "PlayStation 2", "GameFolder", "PCSX2", GetDataRoot());
        }

        private void RemoveLibrary(string path)
        {
            settings.libraryRoots = settings.libraryRoots.Where(delegate(string existing)
            {
                return !String.Equals(existing, path, StringComparison.OrdinalIgnoreCase);
            }).ToList();
            settings.Save(settingsPath);
            BuildChannels();
            BeginScan(true);
            ShowNotice("Library folder removed. No game files were deleted.");
        }

        private void ChooseBios()
        {
            string biosFolder = ResolveConfiguredFolder("Bios", "bios");
            Directory.CreateDirectory(biosFolder);
            OpenFileDialog dialog = new OpenFileDialog();
            dialog.Title = "Choose a legally obtained PlayStation 2 BIOS";
            dialog.InitialDirectory = biosFolder;
            dialog.Filter = "BIOS files (*.bin;*.rom;*.erom)|*.bin;*.rom;*.erom|All files (*.*)|*.*";
            if (dialog.ShowDialog(this) != true) return;
            string target = dialog.FileName;
            SimpleIniFile ini = GetIni(false, String.Empty);
            ini.Set("Filenames", "BIOS", Path.GetFileName(target));
            settings.biosPath = target;
            settings.Save(settingsPath);
            BuildChannels();
            ShowNotice("BIOS selected: " + Path.GetFileName(target));
        }

        private string GetBiosStatus()
        {
            string folder = ResolveConfiguredFolder("Bios", "bios");
            string selected = GetIni(false, String.Empty).Get("Filenames", "BIOS", String.Empty);
            if (!String.IsNullOrWhiteSpace(selected))
            {
                string path = Path.IsPathRooted(selected) ? selected : Path.Combine(folder, selected);
                if (File.Exists(path)) return Path.GetFileName(path);
            }
            if (!String.IsNullOrWhiteSpace(settings.biosPath) && File.Exists(settings.biosPath)) return Path.GetFileName(settings.biosPath);
            try
            {
                string first = Directory.EnumerateFiles(folder, "*.*").FirstOrDefault(delegate(string path)
                {
                    string ext = Path.GetExtension(path);
                    return ext.Equals(".bin", StringComparison.OrdinalIgnoreCase) ||
                        ext.Equals(".rom", StringComparison.OrdinalIgnoreCase);
                });
                if (!String.IsNullOrWhiteSpace(first)) return Path.GetFileName(first) + " — detected";
            }
            catch { }
            return "Not configured";
        }

        private List<BbnItem> BuildFolderCardSaveItems(string cardPath)
        {
            List<BbnItem> result = new List<BbnItem>();
            try
            {
                foreach (string save in Directory.EnumerateDirectories(cardPath).Take(512).OrderBy(delegate(string path) { return Path.GetFileName(path); }, StringComparer.CurrentCultureIgnoreCase))
                {
                    string encoded = Encode(save);
                    string directoryName = Path.GetFileName(save);
                    string title = Ps2SaveTitleReader.ReadFolderTitle(save);
                    if (String.IsNullOrWhiteSpace(title)) title = directoryName;
                    long size = DirectorySize(save);
                    int files = 0;
                    try { files = Directory.EnumerateFiles(save, "*", SearchOption.AllDirectories).Count(); } catch { }
                    DateTime modified;
                    try { modified = Directory.GetLastWriteTime(save); } catch { modified = DateTime.MinValue; }
                    Ps2CardSaveEntry entry = new Ps2CardSaveEntry {
                        DirectoryName = directoryName, Title = title, SizeBytes = size, FileCount = files,
                        Modified = modified, DetailText = directoryName + " • Folder Memory Card"
                    };
                    entry.IconModel = Ps2SaveTitleReader.ReadFolderIconModel(save);
                    BbnItem item = new BbnItem(title, FormatBytes(size) + " • " + files + " file" + (files == 1 ? String.Empty : "s") +
                        (modified == DateTime.MinValue ? String.Empty : " • " + modified.ToString("g")), null,
                        BuildNativeSaveOptions(cardPath, entry, save));
                    item.SaveEntry = entry;
                    item.MemoryCardPath = cardPath;
                    item.SaveIcon = entry.IconModel;
                    result.Add(item);
                }
            }
            catch { }
            if (result.Count == 0) result.Add(new BbnItem("No saved data found", cardPath, null));
            return result;
        }


        private void OpenMemoryCard(string cardPath)
        {
            string freeText;
            List<BbnItem> saves = BuildMemoryCardSaveItems(cardPath, out freeText);
            menuStack.Push(new BbnMenuContext(Path.GetFileName(cardPath), saves, selectedIndex, true, true, cardPath, freeText));
            selectedIndex = 0;
            visualItem = 0;
            surface.InvalidateVisual();
        }

        private void OpenMemoryOptions()
        {
            BbnItem item = CurrentItem;
            if (item == null) return;
            List<BbnItem> options = item.Children;
            if ((options == null || options.Count == 0) && MemoryCardContentActive && menuStack.Count > 0)
                options = BuildMemoryCardOptions(menuStack.Peek().MemoryCardPath);
            if (options == null || options.Count == 0) { ShowNotice("No options are available for this item"); return; }
            string cardPath = menuStack.Count > 0 ? menuStack.Peek().MemoryCardPath : item.MemoryCardPath;
            string freeText = menuStack.Count > 0 ? menuStack.Peek().MemoryCardFreeText : String.Empty;
            menuStack.Push(new BbnMenuContext(item.Title + " Options", options, selectedIndex, true,
                false, cardPath, freeText, true));
            selectedIndex = 0;
            visualItem = 0;
        }

        private void CopyNativeSave(string payload)
        {
            string[] parts = payload.Split('|');
            if (parts.Length != 3) return;
            string sourceCard = Decode(parts[0]);
            string directoryName = Decode(parts[1]);
            string targetCard = Decode(parts[2]);
            string temporary = String.Empty;
            try
            {
                string sourceSave;
                if (Directory.Exists(sourceCard)) sourceSave = Path.Combine(sourceCard, directoryName);
                else
                {
                    temporary = Path.Combine(appDataRoot, "NativeSaveWork", Guid.NewGuid().ToString("N"), MakeSafeName(directoryName));
                    string error;
                    if (!Ps2MemoryCardImageReader.ExportSave(sourceCard, directoryName, temporary, out error))
                        throw new InvalidOperationException(error);
                    sourceSave = temporary;
                }
                if (!Directory.Exists(sourceSave)) throw new DirectoryNotFoundException("The selected saved data is unavailable.");
                string editableTarget = EnsureEditableFolderCard(targetCard);
                string destination = MakeUniqueDirectory(Path.Combine(editableTarget, directoryName));
                CopyPath(sourceSave, destination);
                RefreshMemoryCards();
                OpenMemoryCard(editableTarget);
                ShowNotice("Saved data copied to " + Path.GetFileName(editableTarget));
            }
            catch (Exception ex) { ShowNotice("Saved data could not be copied: " + ex.Message); }
            finally
            {
                try { if (!String.IsNullOrWhiteSpace(temporary)) Directory.Delete(Path.GetDirectoryName(temporary), true); } catch { }
            }
        }

        private void BackupNativeSave(string payload)
        {
            string[] parts = payload.Split('|');
            if (parts.Length != 2) return;
            string cardPath = Decode(parts[0]);
            string directoryName = Decode(parts[1]);
            try
            {
                string destination = Path.Combine(appDataRoot, "SaveBackups",
                    MakeSafeName(directoryName) + "-" + DateTime.Now.ToString("yyyyMMdd-HHmmss"));
                Directory.CreateDirectory(Path.GetDirectoryName(destination));
                if (Directory.Exists(cardPath)) CopyPath(Path.Combine(cardPath, directoryName), destination);
                else
                {
                    string error;
                    if (!Ps2MemoryCardImageReader.ExportSave(cardPath, directoryName, destination, out error))
                        throw new InvalidOperationException(error);
                }
                ShowNotice("Saved data backed up");
            }
            catch (Exception ex) { ShowNotice("Save backup failed: " + ex.Message); }
        }

        private void ExportNativeSave(string payload)
        {
            string[] parts = payload.Split('|');
            if (parts.Length != 2) return;
            string cardPath = Decode(parts[0]);
            string directoryName = Decode(parts[1]);
            Forms.FolderBrowserDialog dialog = new Forms.FolderBrowserDialog();
            dialog.Description = "Choose a destination for the saved-data export";
            if (dialog.ShowDialog() != Forms.DialogResult.OK) return;
            try
            {
                string destination = MakeUniqueDirectory(Path.Combine(dialog.SelectedPath, MakeSafeName(directoryName)));
                if (Directory.Exists(cardPath)) CopyPath(Path.Combine(cardPath, directoryName), destination);
                else
                {
                    string error;
                    if (!Ps2MemoryCardImageReader.ExportSave(cardPath, directoryName, destination, out error))
                        throw new InvalidOperationException(error);
                }
                ShowNotice("Saved data exported");
            }
            catch (Exception ex) { ShowNotice("Save export failed: " + ex.Message); }
        }

        private void DeleteNativeSave(string payload)
        {
            string[] parts = payload.Split('|');
            if (parts.Length != 2) return;
            string cardPath = Decode(parts[0]);
            string directoryName = Decode(parts[1]);
            try
            {
                string editableCard = Directory.Exists(cardPath) ? cardPath : EnsureEditableFolderCard(cardPath);
                string source = Path.Combine(editableCard, directoryName);
                if (!Directory.Exists(source)) throw new DirectoryNotFoundException("The selected saved data is unavailable.");
                string trash = Path.Combine(appDataRoot, "SaveTrash", DateTime.Now.ToString("yyyyMMdd-HHmmss") + "-" + MakeSafeName(directoryName));
                Directory.CreateDirectory(Path.GetDirectoryName(trash));
                Directory.Move(source, trash);
                RefreshMemoryCards();
                OpenMemoryCard(editableCard);
                ShowNotice("Saved data moved to recoverable Save Trash");
            }
            catch (Exception ex) { ShowNotice("Saved data could not be deleted: " + ex.Message); }
        }

        private string EnsureEditableFolderCard(string cardPath)
        {
            if (Directory.Exists(cardPath)) return cardPath;
            if (!File.Exists(cardPath)) throw new FileNotFoundException("Memory card is unavailable", cardPath);
            string root = GetMemoryCardFolder();
            Directory.CreateDirectory(root);
            string destination = Path.Combine(root, MakeSafeName(Path.GetFileNameWithoutExtension(cardPath)) + "-Huymaier-Editable");
            if (!Directory.Exists(destination))
            {
                string backupRoot = GetMemoryBackupRoot();
                Directory.CreateDirectory(backupRoot);
                File.Copy(cardPath, Path.Combine(backupRoot, Path.GetFileName(cardPath) + "-before-edit-" + DateTime.Now.ToString("yyyyMMdd-HHmmss")), false);
                Directory.CreateDirectory(destination);
                List<Ps2CardSaveEntry> entries;
                long freeBytes;
                string error;
                if (!Ps2MemoryCardImageReader.TryRead(cardPath, out entries, out freeBytes, out error))
                    throw new InvalidOperationException(error);
                foreach (Ps2CardSaveEntry entry in entries)
                {
                    string exportError;
                    string saveDestination = Path.Combine(destination, MakeSafeName(entry.DirectoryName));
                    if (!Ps2MemoryCardImageReader.ExportSave(cardPath, entry.DirectoryName, saveDestination, out exportError))
                        throw new InvalidOperationException(exportError);
                }
                string slots = GetMemoryCardSlotText(cardPath);
                if (slots.IndexOf("Slot 1", StringComparison.OrdinalIgnoreCase) >= 0) AssignMemoryCard(1, destination);
                if (slots.IndexOf("Slot 2", StringComparison.OrdinalIgnoreCase) >= 0) AssignMemoryCard(2, destination);
                WriteLog("Converted raw PS2 card to safe editable folder-card mirror: " + cardPath + " -> " + destination, "INFO");
            }
            return destination;
        }

        private static string MakeUniqueDirectory(string desired)
        {
            if (!Directory.Exists(desired) && !File.Exists(desired)) return desired;
            for (int index = 2; index < 1000; index++)
            {
                string candidate = desired + " (" + index + ")";
                if (!Directory.Exists(candidate) && !File.Exists(candidate)) return candidate;
            }
            return desired + "-" + Guid.NewGuid().ToString("N");
        }

        private void ExportRawSave(string payload)
        {
            string[] parts = payload.Split('|');
            if (parts.Length != 2) return;
            string cardPath = Decode(parts[0]);
            string directoryName = Decode(parts[1]);
            Forms.FolderBrowserDialog dialog = new Forms.FolderBrowserDialog();
            dialog.Description = "Choose a destination for the extracted saved data";
            if (dialog.ShowDialog() != Forms.DialogResult.OK) return;
            try
            {
                string destination = Path.Combine(dialog.SelectedPath, MakeSafeName(directoryName));
                string error;
                if (!Ps2MemoryCardImageReader.ExportSave(cardPath, directoryName, destination, out error))
                    throw new InvalidOperationException(error);
                ShowNotice("Saved data exported to " + destination);
            }
            catch (Exception ex) { ShowNotice("Saved data export failed: " + ex.Message); }
        }

        private void OpenMemoryCards()
        {
            menuStack.Push(new BbnMenuContext("Memory Cards", BuildMemoryCardItems(), selectedIndex, true));
            selectedIndex = 0;
            visualItem = 0;
        }

        private void RefreshMemoryCards()
        {
            RefreshSaveVisuals();
            menuStack.Clear();
            channelIndex = Math.Max(0, channels.FindIndex(delegate(BbnChannel channel) { return channel.Id == "MemoryCards"; }));
            if (channelIndex < 0) channelIndex = 0;
            topMenuActive = false;
            selectedIndex = 0;
            visualItem = 0;
            RefreshSettingsChannel();
            surface.InvalidateVisual();
            ShowNotice("Memory cards refreshed");
        }


        private List<Ps2MemoryCard> ScanMemoryCards()
        {
            List<Ps2MemoryCard> result = new List<Ps2MemoryCard>();
            string folder = GetMemoryCardFolder();
            if (!Directory.Exists(folder)) return result;
            try
            {
                foreach (string path in Directory.EnumerateFileSystemEntries(folder).Take(128))
                {
                    Ps2MemoryCard card = new Ps2MemoryCard();
                    card.Path = path;
                    card.Name = Path.GetFileName(path);
                    if (Directory.Exists(path))
                    {
                        long size = DirectorySize(path);
                        card.Subtitle = "Folder memory card • " + FormatBytes(size);
                    }
                    else
                    {
                        FileInfo info = new FileInfo(path);
                        card.Subtitle = FormatBytes(info.Length) + " • " + info.LastWriteTime.ToString("g");
                    }
                    result.Add(card);
                }
            }
            catch { }
            return result.OrderBy(delegate(Ps2MemoryCard card) { return card.Name; }, StringComparer.CurrentCultureIgnoreCase).ToList();
        }

        private void CreateMemoryCard()
        {
            string folder = GetMemoryCardFolder();
            Directory.CreateDirectory(folder);
            string path = Path.Combine(folder, "Huymaier-" + DateTime.Now.ToString("yyyyMMdd-HHmmss") + ".ps2");
            try
            {
                byte[] block = Enumerable.Repeat((byte)0xff, 1024 * 1024).ToArray();
                using (FileStream stream = File.Create(path))
                    for (int i = 0; i < 8; i++) stream.Write(block, 0, block.Length);
                RefreshSettingsChannel();
                ShowNotice("8 MB memory card created. PCSX2 can format it when selected.");
            }
            catch (Exception ex) { ShowNotice("Memory card could not be created: " + ex.Message); }
        }

        private string GetMemoryCardSlotText(string path)
        {
            try
            {
                string name = Path.GetFileName(path);
                SimpleIniFile ini = GetIni(false, String.Empty);
                List<string> slots = new List<string>();
                if (String.Equals(ini.Get("MemoryCards", "Slot1_Filename", String.Empty), name, StringComparison.OrdinalIgnoreCase)) slots.Add("Slot 1");
                if (String.Equals(ini.Get("MemoryCards", "Slot2_Filename", String.Empty), name, StringComparison.OrdinalIgnoreCase)) slots.Add("Slot 2");
                return slots.Count > 0 ? " • " + String.Join(" / ", slots.ToArray()) : String.Empty;
            }
            catch { return String.Empty; }
        }

        private void AssignMemoryCard(int slot, string path)
        {
            if (slot < 1 || slot > 2 || (!File.Exists(path) && !Directory.Exists(path))) return;
            try
            {
                SimpleIniFile ini = GetIni(false, String.Empty);
                ini.Set("MemoryCards", "Slot" + slot + "_Enable", "true");
                ini.Set("MemoryCards", "Slot" + slot + "_Filename", Path.GetFileName(path));
                RefreshMemoryCards();
                ShowNotice(Path.GetFileName(path) + " selected for Slot " + slot);
            }
            catch (Exception ex) { ShowNotice("Memory card could not be selected: " + ex.Message); }
        }

        private void BackupSave(string path)
        {
            try
            {
                string root = Path.Combine(appDataRoot, "SaveBackups");
                Directory.CreateDirectory(root);
                string destination = Path.Combine(root, MakeSafeName(Path.GetFileName(path)) + "-" + DateTime.Now.ToString("yyyyMMdd-HHmmss"));
                CopyPath(path, destination);
                ShowNotice("Saved data backed up");
            }
            catch (Exception ex) { ShowNotice("Save backup failed: " + ex.Message); }
        }

        private void ExportSave(string path)
        {
            Forms.FolderBrowserDialog dialog = new Forms.FolderBrowserDialog();
            dialog.Description = "Choose a destination for the saved-data export";
            if (dialog.ShowDialog() != Forms.DialogResult.OK) return;
            try { CopyPath(path, Path.Combine(dialog.SelectedPath, Path.GetFileName(path))); ShowNotice("Saved data exported"); }
            catch (Exception ex) { ShowNotice("Save export failed: " + ex.Message); }
        }

        private void TrashSave(string path)
        {
            try
            {
                string trash = Path.Combine(appDataRoot, "SaveTrash", DateTime.Now.ToString("yyyyMMdd-HHmmss") + "-" + MakeSafeName(Path.GetFileName(path)));
                Directory.CreateDirectory(Path.GetDirectoryName(trash));
                Directory.Move(path, trash);
                menuStack.Clear();
                RefreshSettingsChannel();
                channelIndex = Math.Max(0, channels.FindIndex(delegate(BbnChannel channel) { return channel.Id == "MemoryCards"; }));
                selectedIndex = 0;
                visualItem = 0;
                ShowNotice("Saved data moved to Save Trash");
            }
            catch (Exception ex) { ShowNotice("Saved data could not be moved: " + ex.Message); }
        }

        private void BackupCard(string path)
        {
            try
            {
                string root = GetMemoryBackupRoot();
                Directory.CreateDirectory(root);
                string destination = Path.Combine(root, MakeSafeName(Path.GetFileName(path)) + "-" + DateTime.Now.ToString("yyyyMMdd-HHmmss"));
                CopyPath(path, destination);
                ShowNotice("Memory card backed up");
            }
            catch (Exception ex) { ShowNotice("Backup failed: " + ex.Message); }
        }

        private void ExportCard(string path)
        {
            Forms.FolderBrowserDialog dialog = new Forms.FolderBrowserDialog();
            dialog.Description = "Choose a destination for the memory-card export";
            if (dialog.ShowDialog() != Forms.DialogResult.OK) return;
            try
            {
                string destination = Path.Combine(dialog.SelectedPath, Path.GetFileName(path));
                CopyPath(path, destination);
                ShowNotice("Memory card exported");
            }
            catch (Exception ex) { ShowNotice("Export failed: " + ex.Message); }
        }

        private void TrashCard(string path)
        {
            try
            {
                string trash = Path.Combine(appDataRoot, "SaveTrash", DateTime.Now.ToString("yyyyMMdd-HHmmss") + "-" + MakeSafeName(Path.GetFileName(path)));
                Directory.CreateDirectory(Path.GetDirectoryName(trash));
                if (Directory.Exists(path)) Directory.Move(path, trash); else File.Move(path, trash);
                RefreshSettingsChannel();
                if (menuStack.Count > 0) { menuStack.Pop(); OpenMemoryCards(); }
                ShowNotice("Memory card moved to Save Trash");
            }
            catch (Exception ex) { ShowNotice("Memory card could not be moved: " + ex.Message); }
        }

        private void BeginPhotoScan()
        {
            string folder = GetScreenshotFolder();
            ThreadPool.QueueUserWorkItem(delegate
            {
                List<string> files = new List<string>();
                if (Directory.Exists(folder))
                {
                    try
                    {
                        files = Directory.EnumerateFiles(folder, "*.*", SearchOption.AllDirectories)
                            .Where(delegate(string path)
                            {
                                string extension = Path.GetExtension(path);
                                return extension.Equals(".png", StringComparison.OrdinalIgnoreCase) ||
                                    extension.Equals(".jpg", StringComparison.OrdinalIgnoreCase) ||
                                    extension.Equals(".jpeg", StringComparison.OrdinalIgnoreCase) ||
                                    extension.Equals(".bmp", StringComparison.OrdinalIgnoreCase);
                            }).Take(1000).OrderByDescending(delegate(string path)
                            {
                                try { return File.GetLastWriteTimeUtc(path); } catch { return DateTime.MinValue; }
                            }).ToList();
                    }
                    catch { }
                }
                Dispatcher.BeginInvoke(new Action(delegate
                {
                    photoFiles = files;
                    BbnChannel channel = channels.FirstOrDefault(delegate(BbnChannel c) { return c.Id == "Photos"; });
                    if (channel == null) return;
                    channel.Items.Clear();
                    channel.Items.Add(new BbnItem("Screenshot Folder", folder, "ChooseScreenshotFolder"));
                    channel.Items.Add(new BbnItem("Refresh Screenshots", files.Count + " image" + (files.Count == 1 ? "" : "s"), "RefreshPhotos"));
                    foreach (string file in files.Take(200))
                        channel.Items.Add(new BbnItem(Path.GetFileNameWithoutExtension(file), File.GetLastWriteTime(file).ToString("g"),
                            "ViewPhoto|" + Encode(file)));
                }));
            });
        }

        private void OpenPhotoViewer(string path)
        {
            int index = photoFiles.FindIndex(delegate(string file) { return String.Equals(file, path, StringComparison.OrdinalIgnoreCase); });
            if (index < 0) return;
            photoViewerIndex = index;
            photoViewerActive = true;
        }

        private void MovePhoto(int delta)
        {
            if (photoFiles.Count == 0) return;
            photoViewerIndex = (photoViewerIndex + delta + photoFiles.Count) % photoFiles.Count;
        }

        private void ClosePhotoViewer()
        {
            photoViewerActive = false;
            photoViewerIndex = -1;
        }

        private void ChooseScreenshotFolder()
        {
            Forms.FolderBrowserDialog dialog = new Forms.FolderBrowserDialog();
            dialog.Description = "Choose the PCSX2 screenshot folder";
            dialog.SelectedPath = GetScreenshotFolder();
            if (dialog.ShowDialog() != Forms.DialogResult.OK) return;
            settings.screenshotFolder = Path.GetFullPath(dialog.SelectedPath);
            settings.Save(settingsPath);
            BuildChannels();
            BeginPhotoScan();
        }

        private void ChooseMediaFolder(bool music)
        {
            Forms.FolderBrowserDialog dialog = new Forms.FolderBrowserDialog();
            dialog.Description = music ? "Choose a music folder" : "Choose a movie folder";
            string current = music ? settings.musicFolder : settings.movieFolder;
            if (!String.IsNullOrWhiteSpace(current)) dialog.SelectedPath = current;
            if (dialog.ShowDialog() != Forms.DialogResult.OK) return;
            if (music) settings.musicFolder = Path.GetFullPath(dialog.SelectedPath);
            else settings.movieFolder = Path.GetFullPath(dialog.SelectedPath);
            settings.Save(settingsPath);
            BuildChannels();
        }

        private void PlayMedia(string path, bool video)
        {
            if (!File.Exists(path)) return;
            try
            {
                mediaPlayer.Stop();
                mediaPlayer.Close();
                mediaPlayer.Open(new Uri(path));
                mediaPlayer.Play();
                mediaPlaying = true;
                videoViewerActive = video;
                videoCaption = video ? Path.GetFileNameWithoutExtension(path) : String.Empty;
                if (video) surface.InvalidateVisual();
                ShowNotice((video ? "Playing movie: " : "Playing ") + Path.GetFileNameWithoutExtension(path));
            }
            catch (Exception ex)
            {
                videoViewerActive = false;
                mediaPlaying = false;
                videoCaption = String.Empty;
                ShowNotice("Media could not be played: " + ex.Message);
            }
        }

        private void ChooseAssetFolder()
        {
            Forms.FolderBrowserDialog dialog = new Forms.FolderBrowserDialog();
            dialog.Description = "Choose a local PlayStation 2 interface asset folder";
            if (!String.IsNullOrWhiteSpace(settings.customAssetFolder)) dialog.SelectedPath = settings.customAssetFolder;
            if (dialog.ShowDialog() != Forms.DialogResult.OK) return;
            settings.customAssetFolder = Path.GetFullPath(dialog.SelectedPath);
            settings.Save(settingsPath);
            imageCache.Clear();
            BuildChannels();
            ShowNotice("Local PlayStation 2 assets selected");
        }

        private void ClearCache()
        {
            string folder = ResolveConfiguredFolder("Cache", "cache");
            if (!Directory.Exists(folder)) { ShowNotice("Cache folder is empty"); return; }
            try
            {
                foreach (string path in Directory.EnumerateFileSystemEntries(folder).Take(10000))
                {
                    try { if (Directory.Exists(path)) Directory.Delete(path, true); else File.Delete(path); } catch { }
                }
                ShowNotice("Rebuildable PCSX2 cache cleared");
            }
            catch (Exception ex) { ShowNotice("Cache could not be cleared: " + ex.Message); }
        }

        private void OpenPcsx2()
        {
            string executable = GetPcsx2Executable();
            if (String.IsNullOrWhiteSpace(executable)) { ShowNotice("Select PCSX2 first"); return; }
            try
            {
                ProcessStartInfo info = new ProcessStartInfo(executable);
                info.WorkingDirectory = Path.GetDirectoryName(executable);
                info.Arguments = String.Empty;
                Process.Start(info);
            }
            catch (Exception ex) { ShowNotice(ex.Message); }
        }

        private void OpenConfiguredFolder(string key)
        {
            OpenPath(ResolveConfiguredFolder(key, key.ToLowerInvariant()));
        }

        private void OpenPath(string path)
        {
            if (String.IsNullOrWhiteSpace(path)) return;
            try
            {
                if (!File.Exists(path) && !Directory.Exists(path)) Directory.CreateDirectory(path);
                Process.Start("explorer.exe", "/select," + Quote(path));
            }
            catch
            {
                try { Process.Start("explorer.exe", Quote(path)); } catch { }
            }
        }

        private string GetPcsx2Executable()
        {
            if (!String.IsNullOrWhiteSpace(settings.pcsx2Path) && File.Exists(settings.pcsx2Path)) return settings.pcsx2Path;
            string detected = Pcsx2PathResolver.FindExecutable(settings.managedInstallFolder);
            if (!String.IsNullOrWhiteSpace(detected)) return detected;
            return String.Empty;
        }

        private string GetDataRoot()
        {
            return Pcsx2PathResolver.FindDataRoot(GetPcsx2Executable(), settings.pcsx2DataPath);
        }

        private string GetPcsx2Status()
        {
            string executable = GetPcsx2Executable();
            return String.IsNullOrWhiteSpace(executable) ? "Not configured" : executable;
        }

        private string GetManagedStatus()
        {
            return String.IsNullOrWhiteSpace(settings.managedInstallFolder)
                ? "Choose an external installation folder" : settings.managedInstallFolder;
        }

        private string GetLibrarySummary()
        {
            return settings.libraryRoots.Count + " folder" + (settings.libraryRoots.Count == 1 ? "" : "s") +
                " • " + games.Count + " game" + (games.Count == 1 ? "" : "s");
        }

        private string GetMemoryCardFolder()
        {
            return ResolveConfiguredFolder("MemoryCards", "memcards");
        }

        private string GetMemoryCardSummary()
        {
            return ScanMemoryCards().Count + " card" + (ScanMemoryCards().Count == 1 ? "" : "s");
        }

        private string GetMemoryBackupRoot()
        {
            return Path.Combine(appDataRoot, "MemoryCardBackups");
        }

        private string GetScreenshotFolder()
        {
            if (!String.IsNullOrWhiteSpace(settings.screenshotFolder)) return settings.screenshotFolder;
            return ResolveConfiguredFolder("Snapshots", "snaps");
        }

        private string GetAssetText()
        {
            return String.IsNullOrWhiteSpace(settings.customAssetFolder) ? "PlayStation 2 Default" : settings.customAssetFolder;
        }

        private string ResolveConfiguredFolder(string key, string fallback)
        {
            string root = GetDataRoot();
            string value = GetIni(false, String.Empty).Get("Folders", key, fallback);
            return ResolveRelative(value, root);
        }

        private BitmapSource LoadImage(string path)
        {
            if (String.IsNullOrWhiteSpace(path) || !File.Exists(path)) return null;
            BitmapSource cached;
            if (imageCache.TryGetValue(path, out cached)) return cached;
            try
            {
                BitmapImage image = new BitmapImage();
                image.BeginInit();
                image.CacheOption = BitmapCacheOption.OnLoad;
                image.DecodePixelWidth = 900;
                image.UriSource = new Uri(path, UriKind.Absolute);
                image.EndInit();
                image.Freeze();
                if (imageCache.Count > 96) imageCache.Clear();
                imageCache[path] = image;
                return image;
            }
            catch { return null; }
        }

        internal BitmapSource LoadCover(Ps2Game game)
        {
            if (game == null) return null;
            return LoadImage(game.CoverPath);
        }

        internal BitmapSource LoadCustomAsset(string name)
        {
            if (String.IsNullOrWhiteSpace(settings.customAssetFolder) || !Directory.Exists(settings.customAssetFolder)) return null;
            foreach (string extension in new string[] { ".png", ".jpg", ".jpeg", ".bmp" })
            {
                string path = Path.Combine(settings.customAssetFolder, name + extension);
                BitmapSource image = LoadImage(path);
                if (image != null) return image;
            }
            return null;
        }

        private void ShowNotice(string text)
        {
            noticeText = text ?? String.Empty;
            noticeUntilUtc = DateTime.UtcNow.AddSeconds(3.2);
            surface.InvalidateVisual();
        }

        internal void WriteLog(string message, string level)
        {
            try
            {
                Directory.CreateDirectory(Path.GetDirectoryName(logPath));
                File.AppendAllText(logPath, DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fff") +
                    " [" + level + "] " + message + Environment.NewLine, Encoding.UTF8);
            }
            catch { }
        }

        private static string Quote(string value)
        {
            return "\"" + (value ?? String.Empty).Replace("\"", "\\\"") + "\"";
        }

        private static string Encode(string value)
        {
            return Convert.ToBase64String(Encoding.UTF8.GetBytes(value ?? String.Empty));
        }

        private static string Decode(string value)
        {
            try { return Encoding.UTF8.GetString(Convert.FromBase64String(value)); }
            catch { return String.Empty; }
        }

        private static string MakeSafeName(string value)
        {
            if (String.IsNullOrWhiteSpace(value)) return "item";
            foreach (char c in Path.GetInvalidFileNameChars()) value = value.Replace(c, '_');
            return value;
        }

        private static string ResolveRelative(string value, string root)
        {
            if (String.IsNullOrWhiteSpace(value)) return Path.Combine(root ?? String.Empty, String.Empty);
            string expanded = Environment.ExpandEnvironmentVariables(value.Trim());
            if (Path.IsPathRooted(expanded)) return Path.GetFullPath(expanded);
            return Path.GetFullPath(Path.Combine(root ?? String.Empty, expanded));
        }

        private static IEnumerable<string> SplitPaths(string value)
        {
            if (String.IsNullOrWhiteSpace(value)) yield break;
            foreach (string item in value.Split(new char[] { '|', ';', '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries))
                if (!String.IsNullOrWhiteSpace(item)) yield return item.Trim();
        }

        private static void CopyPath(string source, string destination)
        {
            if (Directory.Exists(source))
            {
                Directory.CreateDirectory(destination);
                foreach (string directory in Directory.EnumerateDirectories(source, "*", SearchOption.AllDirectories))
                    Directory.CreateDirectory(directory.Replace(source, destination));
                foreach (string file in Directory.EnumerateFiles(source, "*", SearchOption.AllDirectories))
                {
                    string target = file.Replace(source, destination);
                    Directory.CreateDirectory(Path.GetDirectoryName(target));
                    File.Copy(file, target, true);
                }
            }
            else
            {
                Directory.CreateDirectory(Path.GetDirectoryName(destination));
                File.Copy(source, destination, true);
            }
        }

        private static long DirectorySize(string path)
        {
            try { return Directory.EnumerateFiles(path, "*", SearchOption.AllDirectories).Take(10000).Sum(delegate(string file) { try { return new FileInfo(file).Length; } catch { return 0L; } }); }
            catch { return 0L; }
        }

        private static string FormatBytes(long bytes)
        {
            if (bytes >= 1024L * 1024L * 1024L) return (bytes / (1024.0 * 1024.0 * 1024.0)).ToString("0.0") + " GB";
            if (bytes >= 1024L * 1024L) return (bytes / (1024.0 * 1024.0)).ToString("0.0") + " MB";
            if (bytes >= 1024L) return (bytes / 1024.0).ToString("0.0") + " KB";
            return bytes + " B";
        }
    }

    internal sealed class Ps2PillarVisual
    {
        internal int Seed;
        internal double Angle;
        internal double Ring;
        internal double Length;
        internal double Width;
        internal double Freshness;
    }

    internal sealed class BbnSurface : FrameworkElement
    {
        private readonly Ps2BbnWindow owner;
        private double phase;
        private readonly Typeface heading;
        private readonly Typeface body;

        internal BbnSurface(Ps2BbnWindow owner)
        {
            this.owner = owner;
            heading = new Typeface(new FontFamily("Segoe UI"), FontStyles.Normal, FontWeights.Light, FontStretches.Normal);
            body = new Typeface(new FontFamily("Segoe UI"), FontStyles.Normal, FontWeights.Normal, FontStretches.Normal);
            Focusable = false;
        }

        internal void Advance(double elapsed) { phase += elapsed * 0.34; }

        protected override void OnRender(DrawingContext dc)
        {
            base.OnRender(dc);
            double width = ActualWidth;
            double height = ActualHeight;
            if (width <= 0 || height <= 0) return;
            if (owner.BootSequenceActive) { DrawBootSequence(dc, width, height); return; }
            if (owner.VideoViewerActive) { DrawVideoViewer(dc, width, height); return; }
            if (owner.PhotoViewerActive) { DrawPhotoViewer(dc, width, height); return; }
            if (owner.MemoryBrowserActive)
            {
                DrawMemoryBrowser(dc, width, height);
                DrawNotice(dc, width, height);
                return;
            }

            DrawBackground(dc, width, height);
            DrawHeader(dc, width, height);
            if (owner.TopMenuActive)
                DrawTopMenu(dc, width, height);
            else if (owner.Channels.Count > 0 && owner.ChannelIndex >= 0 && owner.ChannelIndex < owner.Channels.Count &&
                owner.Channels[owner.ChannelIndex].Id == "GameCollection" &&
                owner.CurrentItems.Any(delegate(BbnItem item) { return item.Game != null; }))
                DrawGameCollection(dc, width, height);
            else
                DrawList(dc, width, height);
            DrawHelp(dc, width, height);
            DrawNotice(dc, width, height);
        }

        private void DrawBackground(DrawingContext dc, double width, double height)
        {
            BitmapSource custom = owner.LoadCustomAsset("background");
            if (custom != null)
            {
                DrawImageFill(dc, custom, new Rect(0, 0, width, height), 0.94);
                dc.DrawRectangle(new SolidColorBrush(Color.FromArgb(78, 0, 0, 0)), null, new Rect(0, 0, width, height));
            }
            else
            {
                LinearGradientBrush background = new LinearGradientBrush();
                background.StartPoint = new Point(0, 0);
                background.EndPoint = new Point(1, 1);
                background.GradientStops.Add(new GradientStop(Color.FromRgb(0, 0, 3), 0));
                background.GradientStops.Add(new GradientStop(Color.FromRgb(2, 7, 23), 0.45));
                background.GradientStops.Add(new GradientStop(Color.FromRgb(0, 2, 9), 1));
                dc.DrawRectangle(background, null, new Rect(0, 0, width, height));

                RadialGradientBrush blueFog = new RadialGradientBrush();
                blueFog.GradientOrigin = new Point(0.45, 0.48);
                blueFog.Center = new Point(0.45, 0.48);
                blueFog.RadiusX = 0.62;
                blueFog.RadiusY = 0.78;
                blueFog.GradientStops.Add(new GradientStop(Color.FromArgb(108, 18, 69, 151), 0));
                blueFog.GradientStops.Add(new GradientStop(Color.FromArgb(54, 7, 34, 94), 0.42));
                blueFog.GradientStops.Add(new GradientStop(Color.FromArgb(0, 0, 0, 0), 1));
                dc.DrawRectangle(blueFog, null, new Rect(0, 0, width, height));

                DrawStars(dc, width, height);
            }
            if (owner.TopMenuActive) DrawSavedDataGeometry(dc, width, height);
        }

        private void DrawStars(DrawingContext dc, double width, double height)
        {
            for (int index = 0; index < 92; index++)
            {
                double x = Unit(index * 7919 + 17) * width;
                double y = Unit(index * 3571 + 101) * height;
                double pulse = 0.45 + 0.55 * Math.Sin(phase * 0.75 + index * 1.71);
                byte alpha = (byte)(18 + Math.Max(0.0, pulse) * 68);
                double radius = 0.35 + Unit(index * 1237 + 7) * 1.15;
                dc.DrawEllipse(new SolidColorBrush(Color.FromArgb(alpha, 160, 210, 255)), null,
                    new Point(x, y), radius, radius);
            }
        }

        private void DrawSavedDataGeometry(DrawingContext dc, double width, double height)
        {
            DrawShaderSkyline(dc, width, height, false, 1.0);
        }

        private void DrawBootSequence(DrawingContext dc, double width, double height)
        {
            dc.DrawRectangle(Brushes.Black, null, new Rect(0, 0, width, height));
            double progress = owner.BootSequenceProgress;
            RadialGradientBrush deepBlue = new RadialGradientBrush();
            deepBlue.Center = new Point(0.50, 0.48);
            deepBlue.GradientOrigin = new Point(0.50, 0.50);
            deepBlue.RadiusX = 0.75;
            deepBlue.RadiusY = 0.75;
            deepBlue.GradientStops.Add(new GradientStop(Color.FromArgb(165, 22, 35, 104), 0));
            deepBlue.GradientStops.Add(new GradientStop(Color.FromArgb(70, 3, 8, 42), 0.55));
            deepBlue.GradientStops.Add(new GradientStop(Colors.Black, 1));
            dc.DrawRectangle(deepBlue, null, new Rect(0, 0, width, height));
            DrawShaderSkyline(dc, width, height, true, progress);
            if (progress > 0.73)
            {
                double fade = Math.Min(1.0, (progress - 0.73) / 0.18);
                FormattedText brand = Text("PlayStation 2", heading, Math.Max(26, height * 0.052),
                    new SolidColorBrush(Color.FromArgb((byte)(fade * 235), 229, 236, 255)), FontWeights.Light);
                dc.DrawText(brand, new Point((width - brand.Width) * 0.5, height * 0.72));
            }
            FormattedText skip = Text("X  Skip", body, Math.Max(12, height * 0.017),
                new SolidColorBrush(Color.FromArgb(155, 220, 228, 247)), FontWeights.Normal);
            dc.DrawText(skip, new Point(width - skip.Width - width * 0.055, height * 0.92));
        }

        private void DrawShaderSkyline(DrawingContext dc, double width, double height, bool boot, double progress)
        {
            IList<Ps2SaveVisual> visuals = owner.SaveVisuals;
            int visualCount = visuals == null ? 0 : visuals.Count;
            int count = boot ? 132 : Math.Max(9, Math.Min(26, visualCount > 0 ? visualCount : 16));
            Point center = boot ? new Point(width * 0.50, height * 0.47) : new Point(width * 0.755, height * 0.49);
            double sceneRadius = boot ? Math.Max(width, height) * (0.77 + progress * 0.16) : width * 0.21;

            RadialGradientBrush fog = new RadialGradientBrush();
            fog.Center = new Point(0.5, 0.5);
            fog.GradientOrigin = new Point(0.5, 0.5);
            fog.RadiusX = 0.5;
            fog.RadiusY = 0.5;
            fog.GradientStops.Add(new GradientStop(Color.FromArgb(boot ? (byte)105 : (byte)60, 82, 105, 255), 0));
            fog.GradientStops.Add(new GradientStop(Color.FromArgb(boot ? (byte)36 : (byte)18, 34, 59, 180), 0.58));
            fog.GradientStops.Add(new GradientStop(Color.FromArgb(0, 0, 0, 0), 1));
            dc.DrawEllipse(fog, null, center, boot ? width * 0.52 : width * 0.17, boot ? height * 0.55 : height * 0.23);

            List<Ps2PillarVisual> pillars = new List<Ps2PillarVisual>();
            for (int index = 0; index < count; index++)
            {
                Ps2SaveVisual save = visualCount > 0 ? visuals[index % visualCount] : null;
                int seed = (save == null ? 1009 + index * 7919 : save.Seed) ^ (index * 3571);
                double angle = Unit(seed + 13) * Math.PI * 2.0 + (boot ? progress * 0.34 : phase * 0.035);
                double ring = boot ? 0.19 + Unit(seed + 31) * 0.82 : 0.22 + Unit(seed + 31) * 0.72;
                double weight = save == null ? Unit(seed + 47) : save.Weight;
                double freshness = save == null ? Unit(seed + 71) : save.Freshness;
                pillars.Add(new Ps2PillarVisual {
                    Seed = seed, Angle = angle, Ring = ring,
                    Length = (boot ? height * (0.11 + weight * 0.48) : height * (0.045 + weight * 0.13)),
                    Width = (boot ? height * (0.014 + Unit(seed + 89) * 0.032) : height * (0.009 + Unit(seed + 89) * 0.014)),
                    Freshness = freshness
                });
            }
            pillars.Sort(delegate(Ps2PillarVisual a, Ps2PillarVisual b) { return b.Ring.CompareTo(a.Ring); });

            foreach (Ps2PillarVisual pillar in pillars)
            {
                double dx = Math.Cos(pillar.Angle);
                double dy = Math.Sin(pillar.Angle);
                if (!boot)
                {
                    dx *= 0.74;
                    dy *= 0.48;
                }
                double travel = boot ? (progress * 0.19 + phase * 0.008) : phase * 0.004;
                double ring = pillar.Ring + travel;
                ring -= Math.Floor(ring);
                ring = 0.16 + ring * 0.84;
                Point inner = new Point(center.X + dx * sceneRadius * ring * 0.43,
                    center.Y + dy * sceneRadius * ring * 0.35);
                double perspective = 0.58 + ring * 0.92;
                double length = pillar.Length * perspective;
                Point outer = new Point(inner.X + dx * length, inner.Y + dy * length);
                double px = -dy, py = dx;
                double half = pillar.Width * perspective;
                double taper = half * 0.56;
                Point[] front = new Point[] {
                    new Point(inner.X + px * taper, inner.Y + py * taper),
                    new Point(inner.X - px * taper, inner.Y - py * taper),
                    new Point(outer.X - px * half, outer.Y - py * half),
                    new Point(outer.X + px * half, outer.Y + py * half)
                };
                byte a = (byte)Math.Max(45, Math.Min(205, (boot ? 78 : 48) + pillar.Freshness * (boot ? 112 : 72) + ring * 22));
                byte r = (byte)(83 + Unit(pillar.Seed + 101) * 40);
                byte g = (byte)(101 + Unit(pillar.Seed + 107) * 48);
                byte b = (byte)(205 + Unit(pillar.Seed + 109) * 50);
                LinearGradientBrush face = new LinearGradientBrush(
                    Color.FromArgb((byte)Math.Min(230, a + 18), r, g, b),
                    Color.FromArgb((byte)Math.Max(24, a - 38), (byte)(r * 0.45), (byte)(g * 0.48), (byte)(b * 0.65)),
                    new Point(0, 0), new Point(1, 1));
                DrawPolygon(dc, front, face, null);
                Point[] side = new Point[] {
                    front[0], front[3],
                    new Point(front[3].X + half * 0.30, front[3].Y - half * 0.18),
                    new Point(front[0].X + taper * 0.30, front[0].Y - taper * 0.18)
                };
                DrawPolygon(dc, side, new SolidColorBrush(Color.FromArgb((byte)Math.Max(18, a - 24), 48, 62, 150)), null);
                Pen highlight = new Pen(new SolidColorBrush(Color.FromArgb((byte)Math.Min(150, (int)a), 158, 187, 255)), boot ? 0.75 : 0.55);
                dc.DrawLine(highlight, front[0], front[3]);
            }

            int streakCount = boot ? 7 : 2;
            for (int i = 0; i < streakCount; i++)
            {
                int seed = 4409 + i * 1931;
                double angle = Unit(seed) * Math.PI * 2.0 + phase * (0.35 + i * 0.025);
                double radius = sceneRadius * (0.20 + Unit(seed + 1) * 0.72);
                Point p0 = new Point(center.X + Math.Cos(angle) * radius * 0.38, center.Y + Math.Sin(angle) * radius * 0.28);
                Point p1 = new Point(p0.X + Math.Cos(angle + 0.45) * (boot ? width * 0.08 : width * 0.025),
                    p0.Y + Math.Sin(angle + 0.45) * (boot ? height * 0.08 : height * 0.025));
                Color color = i % 3 == 0 ? Color.FromRgb(255, 31, 103) : i % 3 == 1 ? Color.FromRgb(56, 255, 105) : Color.FromRgb(234, 33, 255);
                dc.DrawLine(new Pen(new SolidColorBrush(Color.FromArgb(34, color.R, color.G, color.B)), boot ? 8 : 4), p0, p1);
                dc.DrawLine(new Pen(new SolidColorBrush(Color.FromArgb(190, color.R, color.G, color.B)), boot ? 1.8 : 1.0), p0, p1);
            }
        }

        private static void DrawPolygon(DrawingContext dc, Point[] points, Brush fill, Pen outline)
        {
            if (points == null || points.Length < 3) return;
            StreamGeometry geometry = new StreamGeometry();
            using (StreamGeometryContext context = geometry.Open())
            {
                context.BeginFigure(points[0], true, true);
                for (int index = 1; index < points.Length; index++)
                    context.LineTo(points[index], true, false);
            }
            geometry.Freeze();
            dc.DrawGeometry(fill, outline, geometry);
        }

        private void DrawHeader(DrawingContext dc, double width, double height)
        {
            BitmapSource customLogo = owner.LoadCustomAsset("logo");
            if (customLogo != null)
            {
                double logoHeight = height * 0.044;
                double logoWidth = logoHeight * customLogo.PixelWidth / Math.Max(1.0, customLogo.PixelHeight);
                dc.DrawImage(customLogo, new Rect(width * 0.046, height * 0.037, logoWidth, logoHeight));
            }
            FormattedText brand = Text("PlayStation 2", heading, Math.Max(22, height * 0.036),
                new SolidColorBrush(Color.FromArgb(240, 244, 247, 252)), FontWeights.Light);
            dc.DrawText(brand, new Point(width * (customLogo != null ? 0.092 : 0.046), height * 0.040));
            Pen divider = new Pen(new SolidColorBrush(Color.FromArgb(92, 93, 111, 166)), 1);
            dc.DrawLine(divider, new Point(width * 0.035, height * 0.105),
                new Point(width * 0.965, height * 0.105));
        }

        private void DrawTopMenu(DrawingContext dc, double width, double height)
        {
            double left = width * 0.105;
            double firstY = height * 0.265;
            double step = height * 0.055;
            for (int index = 0; index < owner.Channels.Count; index++)
            {
                double offset = index - owner.VisualChannel;
                double y = firstY + offset * step;
                if (y < height * 0.17 || y > height * 0.83) continue;
                bool selected = Math.Abs(offset) < 0.48;
                double distance = Math.Abs(offset);
                byte alpha = (byte)(Math.Max(0.24, 1.0 - distance * 0.13) * 255);
                Brush brush = new SolidColorBrush(Color.FromArgb(alpha,
                    selected ? (byte)191 : (byte)55,
                    selected ? (byte)246 : (byte)187,
                    selected ? (byte)255 : (byte)244));
                FormattedText item = Text(owner.Channels[index].Title, body,
                    Math.Max(17, height * (selected ? 0.030 : 0.026)), brush,
                    selected ? FontWeights.SemiBold : FontWeights.Normal);
                Point point = new Point(left + (selected ? width * 0.012 : 0), y);
                if (selected)
                {
                    RadialGradientBrush glow = new RadialGradientBrush(
                        Color.FromArgb(72, 55, 184, 255), Color.FromArgb(0, 20, 88, 194));
                    dc.DrawEllipse(glow, null,
                        new Point(point.X + item.Width * 0.48, point.Y + item.Height * 0.58),
                        item.Width * 0.78 + width * 0.022, item.Height * 1.26);
                }
                dc.DrawText(item, point);
            }
        }


        private void DrawGameCollection(DrawingContext dc, double width, double height)
        {
            List<BbnItem> items = owner.CurrentItems;
            FormattedText headingText = Text("Game Channel", body, Math.Max(22, height * 0.034),
                new SolidColorBrush(Color.FromRgb(226, 231, 76)), FontWeights.SemiBold);
            dc.DrawText(headingText, new Point(width * 0.075, height * 0.165));

            DrawGameAlphabet(dc, width, height);

            BbnItem current = owner.CurrentItem;
            if (current != null)
            {
                FormattedText title = Text(current.Title, body, Math.Max(20, height * 0.031),
                    new SolidColorBrush(Color.FromRgb(176, 236, 255)), FontWeights.SemiBold);
                title.MaxTextWidth = width * 0.39;
                dc.DrawText(title, new Point(width * 0.515, height * 0.215));
            }

            Point selectedCenter = new Point(width * 0.755, height * 0.515);
            RadialGradientBrush selectedFog = new RadialGradientBrush();
            selectedFog.GradientStops.Add(new GradientStop(Color.FromArgb(80, 38, 174, 255), 0));
            selectedFog.GradientStops.Add(new GradientStop(Color.FromArgb(22, 16, 82, 178), 0.52));
            selectedFog.GradientStops.Add(new GradientStop(Color.FromArgb(0, 0, 0, 0), 1));
            dc.DrawEllipse(selectedFog, null, selectedCenter, width * 0.19, height * 0.30);

            List<int> drawOrder = Enumerable.Range(0, items.Count)
                .Where(delegate(int index) { return Math.Abs(index - owner.VisualItem) <= 4.5; })
                .OrderByDescending(delegate(int index) { return Math.Abs(index - owner.VisualItem); })
                .ToList();
            foreach (int index in drawOrder)
            {
                double offset = index - owner.VisualItem;
                bool selected = Math.Abs(offset) < 0.50;
                double distance = Math.Abs(offset);
                double coverHeight;
                double centerX;
                double centerY;
                double opacity;
                if (selected)
                {
                    coverHeight = height * 0.455;
                    centerX = width * 0.755;
                    centerY = height * 0.535;
                    opacity = 1.0;
                }
                else if (offset < 0)
                {
                    coverHeight = height * Math.Max(0.155, 0.305 - distance * 0.036);
                    centerX = width * (0.635 - distance * 0.095);
                    centerY = height * (0.535 + distance * 0.018);
                    opacity = Math.Max(0.32, 0.82 - distance * 0.14);
                }
                else
                {
                    coverHeight = height * Math.Max(0.145, 0.255 - distance * 0.032);
                    centerX = width * (0.855 + (distance - 1.0) * 0.035);
                    centerY = height * (0.545 + distance * 0.016);
                    opacity = Math.Max(0.25, 0.64 - distance * 0.12);
                }
                double coverWidth = coverHeight * 0.705;
                Rect bounds = new Rect(centerX - coverWidth / 2, centerY - coverHeight / 2, coverWidth, coverHeight);
                dc.DrawRectangle(new SolidColorBrush(Color.FromArgb(selected ? (byte)128 : (byte)62, 0, 0, 0)),
                    null, new Rect(bounds.X + 7, bounds.Y + 10, bounds.Width, bounds.Height));
                BitmapSource cover = owner.LoadCover(items[index].Game);
                if (cover != null)
                    DrawImageFill(dc, cover, bounds, opacity);
                else
                {
                    LinearGradientBrush placeholder = new LinearGradientBrush(
                        Color.FromArgb(230, 12, 39, 84), Color.FromArgb(235, 2, 7, 22), 45);
                    dc.DrawRectangle(placeholder, null, bounds);
                    FormattedText ps2 = Text("PS2", heading, coverHeight * 0.15,
                        new SolidColorBrush(Color.FromArgb(210, 198, 229, 255)), FontWeights.Light);
                    dc.DrawText(ps2, new Point(bounds.X + (bounds.Width - ps2.Width) / 2,
                        bounds.Y + bounds.Height * 0.39));
                }
                Pen border = new Pen(new SolidColorBrush(selected
                    ? Color.FromArgb(235, 182, 243, 255)
                    : Color.FromArgb(90, 83, 151, 205)), selected ? 2.0 : 0.8);
                dc.DrawRectangle(null, border, bounds);
            }

            if (current != null)
            {
                string detail = current.Game != null && !String.IsNullOrWhiteSpace(current.Game.Serial)
                    ? current.Game.Serial : current.Subtitle;
                FormattedText subtitle = Text(detail, body, Math.Max(11, height * 0.016),
                    new SolidColorBrush(Color.FromArgb(180, 168, 205, 232)), FontWeights.Normal);
                dc.DrawText(subtitle, new Point(width * 0.515, height * 0.267));
            }
            FormattedText count = Text((owner.SelectedIndex + 1) + "/" + Math.Max(1, items.Count),
                body, Math.Max(11, height * 0.015),
                new SolidColorBrush(Color.FromArgb(170, 178, 211, 235)), FontWeights.Normal);
            dc.DrawText(count, new Point(width * 0.895, height * 0.183));
        }

        private void DrawGameAlphabet(DrawingContext dc, double width, double height)
        {
            string letters = owner.GameLetters;
            double x = width * 0.054;
            double startY = height * 0.205;
            double step = height * 0.0231;
            for (int index = 0; index < letters.Length; index++)
            {
                bool available = owner.HasGamesForLetter(index);
                bool current = index == owner.GameLetterIndex;
                bool focused = owner.GameLetterFocus && current;
                Color color = focused ? Color.FromRgb(235, 238, 82) :
                    current ? Color.FromRgb(183, 244, 255) :
                    available ? Color.FromArgb(185, 83, 184, 232) : Color.FromArgb(70, 74, 90, 115);
                FormattedText text = Text(letters[index].ToString(), body,
                    Math.Max(11, height * (focused ? 0.019 : 0.016)), new SolidColorBrush(color),
                    focused ? FontWeights.SemiBold : FontWeights.Normal);
                Point point = new Point(x, startY + index * step);
                if (focused)
                {
                    RadialGradientBrush glow = new RadialGradientBrush(
                        Color.FromArgb(92, 70, 193, 255), Color.FromArgb(0, 12, 75, 160));
                    dc.DrawEllipse(glow, null, new Point(point.X + text.Width * 0.5, point.Y + text.Height * 0.55),
                        width * 0.018, height * 0.018);
                }
                dc.DrawText(text, point);
            }
        }


        private void DrawMemoryBrowser(DrawingContext dc, double width, double height)
        {
            LinearGradientBrush background = new LinearGradientBrush();
            background.StartPoint = new Point(0, 0);
            background.EndPoint = new Point(1, 1);
            background.GradientStops.Add(new GradientStop(Color.FromRgb(183, 183, 190), 0));
            background.GradientStops.Add(new GradientStop(Color.FromRgb(129, 130, 140), 0.55));
            background.GradientStops.Add(new GradientStop(Color.FromRgb(92, 94, 105), 1));
            dc.DrawRectangle(background, null, new Rect(0, 0, width, height));
            for (int line = 0; line < 22; line++)
            {
                double x = width * line / 21.0;
                dc.DrawLine(new Pen(new SolidColorBrush(Color.FromArgb(15, 255, 255, 255)), 1),
                    new Point(x, 0), new Point(x + width * 0.06, height));
            }

            FormattedText browser = Text("Browser", body, Math.Max(25, height * 0.042),
                new SolidColorBrush(Color.FromRgb(232, 225, 65)), FontWeights.SemiBold);
            dc.DrawText(browser, new Point(width * 0.045, height * 0.060));
            FormattedText section = Text(owner.CurrentSectionTitle, body, Math.Max(14, height * 0.021),
                new SolidColorBrush(Color.FromArgb(220, 245, 245, 248)), FontWeights.Normal);
            dc.DrawText(section, new Point(width * 0.047, height * 0.126));
            if (owner.MemoryCardContentActive && !String.IsNullOrWhiteSpace(owner.CurrentMemoryCardFreeText))
            {
                FormattedText free = Text(owner.CurrentMemoryCardFreeText, body, Math.Max(12, height * 0.018),
                    new SolidColorBrush(Color.FromArgb(230, 248, 248, 250)), FontWeights.Normal);
                dc.DrawText(free, new Point(width * 0.047, height * 0.172));
            }
            if (owner.MemoryOptionsActive)
            {
                DrawMemoryOptions(dc, width, height);
                return;
            }

            List<BbnItem> items = owner.CurrentItems;
            int pageSize = 8;
            int pageStart = items.Count == 0 ? 0 : (owner.SelectedIndex / pageSize) * pageSize;
            int pageEnd = Math.Min(items.Count, pageStart + pageSize);
            for (int index = pageStart; index < pageEnd; index++)
            {
                int local = index - pageStart;
                int column = local % 4;
                int row = local / 4;
                double x = width * (0.125 + column * 0.125);
                double y = height * (0.32 + row * 0.245);
                bool selected = index == owner.SelectedIndex;
                double scale = selected ? 1.13 : 1.0;
                DrawMemoryItemIcon(dc, items[index], new Point(x, y), height * 0.095 * scale, selected, index);
            }

            BbnItem current = owner.CurrentItem;
            if (current != null)
            {
                FormattedText title = Text(current.Title, body, Math.Max(23, height * 0.037),
                    new SolidColorBrush(Color.FromArgb(245, 250, 250, 252)), FontWeights.Normal);
                title.MaxTextWidth = width * 0.38;
                dc.DrawText(title, new Point(width * 0.585, height * 0.455));
                FormattedText detail = Text(current.Subtitle, body, Math.Max(12, height * 0.018),
                    new SolidColorBrush(Color.FromArgb(215, 232, 232, 238)), FontWeights.Normal);
                detail.MaxTextWidth = width * 0.36;
                dc.DrawText(detail, new Point(width * 0.588, height * 0.525));
            }

            FormattedText count = Text(items.Count + " item" + (items.Count == 1 ? String.Empty : "s"), body,
                Math.Max(11, height * 0.016), new SolidColorBrush(Color.FromArgb(210, 245, 245, 248)), FontWeights.Normal);
            dc.DrawText(count, new Point(width * 0.047, owner.MemoryCardContentActive ? height * 0.205 : height * 0.178));
            FormattedText page = Text(items.Count == 0 ? "0/0" : (owner.SelectedIndex + 1) + "/" + items.Count,
                body, Math.Max(11, height * 0.016), new SolidColorBrush(Color.FromArgb(205, 240, 240, 244)), FontWeights.Normal);
            dc.DrawText(page, new Point(width * 0.90, height * 0.082));

            dc.DrawLine(new Pen(new SolidColorBrush(Color.FromArgb(100, 240, 240, 245)), 1),
                new Point(width * 0.035, height * 0.865), new Point(width * 0.965, height * 0.865));
            FormattedText help = Text("✕  Enter          ○  Back          △  Options", body,
                Math.Max(13, height * 0.019), new SolidColorBrush(Color.FromArgb(235, 248, 248, 250)), FontWeights.Normal);
            dc.DrawText(help, new Point(width * 0.055, height * 0.905));
        }

        private void DrawMemoryOptions(DrawingContext dc, double width, double height)
        {
            List<BbnItem> items = owner.CurrentItems;
            double left = width * 0.105;
            double firstY = height * 0.245;
            double step = height * 0.061;
            for (int index = 0; index < items.Count; index++)
            {
                double offset = index - owner.VisualItem;
                if (Math.Abs(offset) > 5.5) continue;
                bool selected = Math.Abs(offset) < 0.48;
                double y = firstY + offset * step;
                Brush brush = new SolidColorBrush(selected ? Color.FromRgb(245, 232, 70) : Color.FromArgb(230, 248, 248, 250));
                FormattedText label = Text(items[index].Title, body, Math.Max(17, height * (selected ? 0.030 : 0.025)),
                    brush, selected ? FontWeights.SemiBold : FontWeights.Normal);
                Point position = new Point(left + (selected ? width * 0.012 : 0), y);
                if (selected)
                {
                    RadialGradientBrush glow = new RadialGradientBrush(Color.FromArgb(70, 76, 161, 255), Color.FromArgb(0, 20, 76, 160));
                    dc.DrawEllipse(glow, null, new Point(position.X + label.Width * 0.5, position.Y + label.Height * 0.56),
                        label.Width * 0.78 + width * 0.018, label.Height * 1.20);
                }
                dc.DrawText(label, position);
            }
            BbnItem current = owner.CurrentItem;
            if (current != null)
            {
                FormattedText detail = Text(current.Subtitle, body, Math.Max(13, height * 0.020),
                    new SolidColorBrush(Color.FromArgb(235, 248, 248, 250)), FontWeights.Normal);
                detail.MaxTextWidth = width * 0.34;
                dc.DrawText(detail, new Point(width * 0.59, height * 0.43));
            }
            dc.DrawLine(new Pen(new SolidColorBrush(Color.FromArgb(100, 240, 240, 245)), 1),
                new Point(width * 0.035, height * 0.865), new Point(width * 0.965, height * 0.865));
            FormattedText help = Text("✕  Select          ○  Back", body, Math.Max(13, height * 0.019),
                new SolidColorBrush(Color.FromArgb(235, 248, 248, 250)), FontWeights.Normal);
            dc.DrawText(help, new Point(width * 0.055, height * 0.905));
        }

        private void DrawMemoryItemIcon(DrawingContext dc, BbnItem item, Point center, double size,
            bool selected, int index)
        {
            string title = item == null ? String.Empty : item.Title ?? String.Empty;
            string subtitle = item == null ? String.Empty : item.Subtitle ?? String.Empty;
            bool card = title.EndsWith(".ps2", StringComparison.OrdinalIgnoreCase) ||
                title.EndsWith(".mcd", StringComparison.OrdinalIgnoreCase) ||
                title.EndsWith(".mc2", StringComparison.OrdinalIgnoreCase) ||
                subtitle.IndexOf("memory card", StringComparison.OrdinalIgnoreCase) >= 0 ||
                subtitle.IndexOf("Slot 1", StringComparison.OrdinalIgnoreCase) >= 0 ||
                subtitle.IndexOf("Slot 2", StringComparison.OrdinalIgnoreCase) >= 0;
            if (card)
                DrawMemoryCardShape(dc, center, size, selected);
            else if (item != null && item.SaveIcon != null)
                DrawAnimatedSaveIcon(dc, item.SaveIcon, center, size, selected);
            else
                DrawSaveIcon(dc, center, size, selected, StableVisualSeed(title + "#" + index));

            if (selected)
            {
                Pen corner = new Pen(new SolidColorBrush(Color.FromArgb(235, 248, 239, 90)), 2.0);
                double r = size * 0.72;
                double c = size * 0.18;
                dc.DrawLine(corner, new Point(center.X - r, center.Y - r), new Point(center.X - r + c, center.Y - r));
                dc.DrawLine(corner, new Point(center.X - r, center.Y - r), new Point(center.X - r, center.Y - r + c));
                dc.DrawLine(corner, new Point(center.X + r, center.Y + r), new Point(center.X + r - c, center.Y + r));
                dc.DrawLine(corner, new Point(center.X + r, center.Y + r), new Point(center.X + r, center.Y + r - c));
            }
        }

        private void DrawMemoryCardShape(DrawingContext dc, Point center, double size, bool selected)
        {
            double w = size * 1.12;
            double h = size * 1.18;
            Point[] outline = new Point[] {
                new Point(center.X - w * 0.50, center.Y - h * 0.42),
                new Point(center.X - w * 0.28, center.Y - h * 0.58),
                new Point(center.X + w * 0.30, center.Y - h * 0.58),
                new Point(center.X + w * 0.50, center.Y - h * 0.39),
                new Point(center.X + w * 0.50, center.Y + h * 0.48),
                new Point(center.X - w * 0.50, center.Y + h * 0.48)
            };
            Brush fill = new SolidColorBrush(selected ? Color.FromRgb(50, 53, 67) : Color.FromRgb(61, 64, 77));
            Pen edge = new Pen(new SolidColorBrush(Color.FromArgb(220, 220, 222, 230)), selected ? 2.0 : 1.1);
            DrawPolygon(dc, outline, fill, edge);
            Rect label = new Rect(center.X - w * 0.34, center.Y - h * 0.18, w * 0.68, h * 0.42);
            dc.DrawRectangle(new LinearGradientBrush(Color.FromRgb(205, 207, 212), Color.FromRgb(145, 148, 157), 90),
                new Pen(new SolidColorBrush(Color.FromArgb(160, 245, 245, 248)), 0.7), label);
            FormattedText ps2 = Text("PlayStation 2", body, Math.Max(7, size * 0.12),
                new SolidColorBrush(Color.FromRgb(32, 38, 72)), FontWeights.SemiBold);
            dc.DrawText(ps2, new Point(label.X + (label.Width - ps2.Width) / 2, label.Y + label.Height * 0.18));
            for (int pin = 0; pin < 5; pin++)
            {
                double x = center.X - w * 0.28 + pin * w * 0.14;
                dc.DrawRectangle(new SolidColorBrush(Color.FromRgb(194, 173, 84)), null,
                    new Rect(x, center.Y - h * 0.52, w * 0.07, h * 0.08));
            }
        }

        private void DrawAnimatedSaveIcon(DrawingContext dc, Ps2IconModel model, Point center, double size, bool selected)
        {
            if (model == null || model.Shapes == null || model.Shapes.Length == 0 || model.VertexCount < 3) return;
            double animation = phase * 3.6;
            int firstShape = ((int)Math.Floor(animation)) % model.Shapes.Length;
            if (firstShape < 0) firstShape += model.Shapes.Length;
            int secondShape = (firstShape + 1) % model.Shapes.Length;
            double blend = animation - Math.Floor(animation);
            // PS2 memory-card icon models are authored facing -Z. The browser camera views from +Z,
            // so add a 180-degree base rotation and retain only the subtle idle yaw.
            double yaw = Math.PI + Math.Sin(phase * 0.72) * 0.20;
            double cos = Math.Cos(yaw);
            double sin = Math.Sin(yaw);
            Ps2IconPoint[] points = new Ps2IconPoint[model.VertexCount];
            double minX = Double.MaxValue, maxX = Double.MinValue, minY = Double.MaxValue, maxY = Double.MinValue;
            for (int index = 0; index < model.VertexCount; index++)
            {
                Ps2IconPoint a = model.Shapes[firstShape][index];
                Ps2IconPoint b = model.Shapes[secondShape][index];
                double x = a.X + (b.X - a.X) * blend;
                double y = a.Y + (b.Y - a.Y) * blend;
                double z = a.Z + (b.Z - a.Z) * blend;
                double rx = x * cos + z * sin;
                double rz = -x * sin + z * cos;
                points[index] = new Ps2IconPoint(rx, y, rz);
                minX = Math.Min(minX, rx); maxX = Math.Max(maxX, rx);
                minY = Math.Min(minY, y); maxY = Math.Max(maxY, y);
            }
            double extent = Math.Max(0.001, Math.Max(maxX - minX, maxY - minY));
            double scale = size * 1.18 / extent;
            double midX = (minX + maxX) * 0.5;
            double midY = (minY + maxY) * 0.5;
            double bob = Math.Sin(phase * 2.1) * size * 0.022;
            if (selected)
            {
                RadialGradientBrush glow = new RadialGradientBrush(Color.FromArgb(88, 91, 197, 255), Color.FromArgb(0, 39, 105, 190));
                dc.DrawEllipse(glow, null, new Point(center.X, center.Y + bob), size * 0.86, size * 0.86);
            }
            List<Ps2IconTriangleRender> triangles = new List<Ps2IconTriangleRender>();
            int triangleCount = Math.Min(model.VertexCount / 3, 1600);
            for (int triangle = 0; triangle < triangleCount; triangle++)
            {
                int i0 = triangle * 3;
                Ps2IconPoint p0 = points[i0]; Ps2IconPoint p1 = points[i0 + 1]; Ps2IconPoint p2 = points[i0 + 2];
                Point[] polygon = new Point[3];
                Ps2IconPoint[] source = new Ps2IconPoint[] { p0, p1, p2 };
                for (int corner = 0; corner < 3; corner++)
                {
                    Ps2IconPoint p = source[corner];
                    double perspective = 1.0 / Math.Max(0.62, 1.72 - p.Z * 0.18);
                    // PS2 icon coordinates use a different handedness from WPF.
                    // Negating X and restoring positive Y makes the local save model
                    // front-facing and upright instead of mirrored and upside-down.
                    polygon[corner] = new Point(center.X - (p.X - midX) * scale * perspective,
                        center.Y + bob + (p.Y - midY) * scale * perspective);
                }
                double ux = p1.X - p0.X, uy = p1.Y - p0.Y, uz = p1.Z - p0.Z;
                double vx = p2.X - p0.X, vy = p2.Y - p0.Y, vz = p2.Z - p0.Z;
                double nx = uy * vz - uz * vy, ny = uz * vx - ux * vz, nz = ux * vy - uy * vx;
                double normalLength = Math.Max(0.0001, Math.Sqrt(nx * nx + ny * ny + nz * nz));
                double light = Math.Max(0.30, Math.Min(1.0, 0.48 + (-nx * 0.25 - ny * 0.55 + nz * 0.78) / normalLength * 0.52));
                Color baseColor = model.SampleTriangleColor(i0, i0 + 1, i0 + 2);
                Color fillColor = Color.FromArgb(baseColor.A,
                    (byte)Math.Max(0, Math.Min(255, baseColor.R * light)),
                    (byte)Math.Max(0, Math.Min(255, baseColor.G * light)),
                    (byte)Math.Max(0, Math.Min(255, baseColor.B * light)));
                Point[] texturePoints = null;
                if (model.TextureBitmap != null && model.Uvs != null && model.Uvs.Length > i0 + 2)
                {
                    texturePoints = new Point[3];
                    int[] indices = new int[] { i0, i0 + 1, i0 + 2 };
                    for (int corner = 0; corner < 3; corner++)
                    {
                        Ps2IconUv uv = model.Uvs[indices[corner]];
                        double u = uv.U - Math.Floor(uv.U);
                        double v = uv.V - Math.Floor(uv.V);
                        texturePoints[corner] = new Point(u * (model.TextureBitmap.PixelWidth - 1),
                            v * (model.TextureBitmap.PixelHeight - 1));
                    }
                }
                double alpha = (model.Colors[i0].A + model.Colors[i0 + 1].A + model.Colors[i0 + 2].A) / (3.0 * 255.0);
                triangles.Add(new Ps2IconTriangleRender {
                    Points = polygon,
                    TexturePoints = texturePoints,
                    Texture = model.TextureBitmap,
                    Depth = (p0.Z + p1.Z + p2.Z) / 3.0,
                    Opacity = Math.Max(0.12, Math.Min(1.0, alpha)),
                    Shade = light,
                    Fill = fillColor
                });
            }
            triangles.Sort(delegate(Ps2IconTriangleRender a, Ps2IconTriangleRender b) { return a.Depth.CompareTo(b.Depth); });
            foreach (Ps2IconTriangleRender triangle in triangles)
            {
                bool textured = triangle.Texture != null && triangle.TexturePoints != null &&
                    DrawTexturedTriangle(dc, triangle.Texture, triangle.TexturePoints, triangle.Points, triangle.Opacity);
                if (!textured)
                    DrawPolygon(dc, triangle.Points, new SolidColorBrush(triangle.Fill), null);
                else if (triangle.Shade < 0.985)
                {
                    StreamGeometry shadeGeometry = CreateTriangleGeometry(triangle.Points);
                    dc.PushClip(shadeGeometry);
                    byte shadeAlpha = (byte)Math.Max(0, Math.Min(150, (1.0 - triangle.Shade) * 165.0));
                    dc.DrawRectangle(new SolidColorBrush(Color.FromArgb(shadeAlpha, 0, 0, 0)), null,
                        new Rect(0, 0, ActualWidth, ActualHeight));
                    dc.Pop();
                }
            }
        }

        private static StreamGeometry CreateTriangleGeometry(Point[] points)
        {
            StreamGeometry geometry = new StreamGeometry();
            using (StreamGeometryContext context = geometry.Open())
            {
                context.BeginFigure(points[0], true, true);
                context.LineTo(points[1], true, false);
                context.LineTo(points[2], true, false);
            }
            geometry.Freeze();
            return geometry;
        }

        private static bool DrawTexturedTriangle(DrawingContext dc, BitmapSource texture,
            Point[] source, Point[] destination, double opacity)
        {
            if (dc == null || texture == null || source == null || destination == null ||
                source.Length < 3 || destination.Length < 3) return false;
            double sx1 = source[1].X - source[0].X;
            double sy1 = source[1].Y - source[0].Y;
            double sx2 = source[2].X - source[0].X;
            double sy2 = source[2].Y - source[0].Y;
            double determinant = sx1 * sy2 - sx2 * sy1;
            if (Math.Abs(determinant) < 0.00001) return false;
            double dx1 = destination[1].X - destination[0].X;
            double dy1 = destination[1].Y - destination[0].Y;
            double dx2 = destination[2].X - destination[0].X;
            double dy2 = destination[2].Y - destination[0].Y;
            double m11 = (dx1 * sy2 - dx2 * sy1) / determinant;
            double m21 = (dx2 * sx1 - dx1 * sx2) / determinant;
            double m12 = (dy1 * sy2 - dy2 * sy1) / determinant;
            double m22 = (dy2 * sx1 - dy1 * sx2) / determinant;
            double offsetX = destination[0].X - m11 * source[0].X - m21 * source[0].Y;
            double offsetY = destination[0].Y - m12 * source[0].X - m22 * source[0].Y;
            Matrix matrix = new Matrix(m11, m12, m21, m22, offsetX, offsetY);
            StreamGeometry clip = CreateTriangleGeometry(destination);
            dc.PushClip(clip);
            dc.PushOpacity(Math.Max(0.0, Math.Min(1.0, opacity)));
            dc.PushTransform(new MatrixTransform(matrix));
            dc.DrawImage(texture, new Rect(0, 0, texture.PixelWidth, texture.PixelHeight));
            dc.Pop();
            dc.Pop();
            dc.Pop();
            return true;
        }

        private void DrawSaveIcon(DrawingContext dc, Point center, double size, bool selected, int seed)
        {
            byte r = (byte)(90 + Math.Abs(seed % 95));
            byte g = (byte)(95 + Math.Abs((seed / 17) % 110));
            byte b = (byte)(100 + Math.Abs((seed / 37) % 120));
            double tilt = -10 + Math.Abs(seed % 21) + Math.Sin(phase * 3.1 + seed * 0.01) * 7.0;
            double bob = Math.Sin(phase * 4.4 + seed * 0.03) * size * 0.05;
            center = new Point(center.X, center.Y + bob);
            dc.PushTransform(new RotateTransform(tilt, center.X, center.Y));
            RadialGradientBrush glow = new RadialGradientBrush(
                Color.FromArgb(selected ? (byte)120 : (byte)60, r, g, b), Color.FromArgb(0, r, g, b));
            dc.DrawEllipse(glow, null, center, size * 0.82, size * 0.82);
            Rect front = new Rect(center.X - size * 0.39, center.Y - size * 0.39, size * 0.78, size * 0.78);
            dc.DrawRoundedRectangle(new SolidColorBrush(Color.FromArgb(225, r, g, b)),
                new Pen(new SolidColorBrush(Color.FromArgb(220, 245, 245, 250)), selected ? 1.8 : 0.9),
                front, size * 0.13, size * 0.13);
            dc.DrawLine(new Pen(new SolidColorBrush(Color.FromArgb(150, 255, 255, 255)), 1),
                new Point(front.X + size * 0.14, front.Y + size * 0.21),
                new Point(front.Right - size * 0.14, front.Bottom - size * 0.18));
            dc.Pop();
        }

        private static int StableVisualSeed(string value)
        {
            unchecked
            {
                int hash = 17;
                foreach (char c in value ?? String.Empty) hash = hash * 31 + Char.ToUpperInvariant(c);
                return hash & 0x7fffffff;
            }
        }

        private void DrawList(DrawingContext dc, double width, double height)
        {
            List<BbnItem> items = owner.CurrentItems;
            FormattedText headingText = Text(owner.CurrentSectionTitle, body, Math.Max(22, height * 0.036),
                new SolidColorBrush(Color.FromRgb(226, 231, 76)), FontWeights.SemiBold);
            DrawGlowText(dc, headingText, new Point(width * 0.085, height * 0.17),
                Color.FromArgb(100, 220, 232, 72), 3.0);

            double left = width * 0.105;
            double centerY = height * 0.48;
            double step = height * 0.058;
            for (int index = 0; index < items.Count; index++)
            {
                double offset = index - owner.VisualItem;
                if (Math.Abs(offset) > 5.4) continue;
                double y = centerY + offset * step;
                bool selected = Math.Abs(offset) < 0.48;
                double opacity = Math.Max(0.18, 1.0 - Math.Abs(offset) * 0.14);
                Brush brush = new SolidColorBrush(Color.FromArgb((byte)(opacity * 255),
                    selected ? (byte)186 : (byte)63,
                    selected ? (byte)242 : (byte)187,
                    selected ? (byte)255 : (byte)244));
                FormattedText item = Text(items[index].Title, body,
                    Math.Max(16, height * (selected ? 0.029 : 0.024)), brush,
                    selected ? FontWeights.SemiBold : FontWeights.Normal);
                Point point = new Point(left + (selected ? width * 0.012 : 0), y);
                if (selected)
                {
                    RadialGradientBrush glow = new RadialGradientBrush(
                        Color.FromArgb(86, 53, 190, 255), Color.FromArgb(0, 18, 92, 175));
                    dc.DrawEllipse(glow, null, new Point(point.X + item.Width * 0.48, point.Y + item.Height * 0.56),
                        item.Width * 0.82 + width * 0.018, item.Height * 1.35);
                    DrawGlowText(dc, item, point, Color.FromArgb(145, 55, 204, 255), 2.0);
                }
                else dc.DrawText(item, point);

                if (selected && items[index].Children != null && items[index].Children.Count > 0)
                {
                    FormattedText arrow = Text("›", heading, Math.Max(20, height * 0.035),
                        new SolidColorBrush(Color.FromArgb(220, 184, 241, 255)), FontWeights.Light);
                    dc.DrawText(arrow, new Point(left + width * 0.46, point.Y - height * 0.004));
                }
            }

            BbnItem current = owner.CurrentItem;
            if (current != null && !String.IsNullOrWhiteSpace(current.Subtitle))
            {
                FormattedText subtitle = Text(current.Subtitle, body, Math.Max(12, height * 0.017),
                    new SolidColorBrush(Color.FromArgb(185, 169, 204, 231)), FontWeights.Normal);
                dc.DrawText(subtitle, new Point(left + width * 0.36, centerY + height * 0.010));
            }
        }

        private void DrawHelp(DrawingContext dc, double width, double height)
        {
            Pen divider = new Pen(new SolidColorBrush(Color.FromArgb(85, 85, 105, 157)), 1);
            dc.DrawLine(divider, new Point(width * 0.035, height * 0.885),
                new Point(width * 0.965, height * 0.885));

            string text;
            if (owner.TopMenuActive)
                text = "✕  Enter                                      ○  Return";
            else if (owner.Channels.Count > 0 && owner.ChannelIndex >= 0 && owner.ChannelIndex < owner.Channels.Count &&
                owner.Channels[owner.ChannelIndex].Id == "GameCollection")
                text = owner.GameLetterFocus
                    ? "▲  ▼  Select Letter          ✕  Jump          ▶  Games"
                    : "◀  ▶  Select Game          ▲  A–Z          L1 / R1  Letter          ✕  Start          ○  Return";
            else
                text = "▲  ▼  Select          ✕  Enter          ○  Return";
            FormattedText help = Text(text, body, Math.Max(12, height * 0.017),
                new SolidColorBrush(Color.FromArgb(205, 220, 225, 235)), FontWeights.Normal);
            dc.DrawText(help, new Point(width - help.Width - width * 0.075, height * 0.915));
        }

        private void DrawNotice(DrawingContext dc, double width, double height)
        {
            string notice = owner.NoticeText;
            if (String.IsNullOrWhiteSpace(notice)) return;
            FormattedText text = Text(notice, body, Math.Max(14, height * 0.020),
                new SolidColorBrush(Color.FromArgb(245, 228, 243, 255)), FontWeights.Normal);
            Rect panel = new Rect((width - text.Width) / 2 - 22, height * 0.81, text.Width + 44, text.Height + 16);
            dc.DrawRectangle(new SolidColorBrush(Color.FromArgb(198, 0, 5, 18)),
                new Pen(new SolidColorBrush(Color.FromArgb(140, 93, 197, 246)), 1), panel);
            dc.DrawText(text, new Point(panel.X + 22, panel.Y + 7));
        }

        private void DrawVideoViewer(DrawingContext dc, double width, double height)
        {
            dc.DrawRectangle(Brushes.Black, null, new Rect(0, 0, width, height));
            Rect videoBounds = new Rect(width * 0.035, height * 0.045, width * 0.93, height * 0.84);
            try { dc.DrawVideo(owner.VideoPlayer, videoBounds); } catch { }
            FormattedText caption = Text(owner.VideoCaption, body, Math.Max(15, height * 0.022), Brushes.White, FontWeights.Normal);
            dc.DrawText(caption, new Point((width - caption.Width) / 2, height * 0.91));
            FormattedText help = Text("✕  Pause / Resume          ○  Return", body, Math.Max(12, height * 0.017),
                new SolidColorBrush(Color.FromArgb(205, 220, 235, 245)), FontWeights.Normal);
            dc.DrawText(help, new Point((width - help.Width) / 2, height * 0.95));
        }

        private void DrawPhotoViewer(DrawingContext dc, double width, double height)
        {
            dc.DrawRectangle(Brushes.Black, null, new Rect(0, 0, width, height));
            BitmapSource image = null;
            try
            {
                string path = owner.CurrentPhotoPath;
                if (!String.IsNullOrWhiteSpace(path))
                {
                    BitmapImage bitmap = new BitmapImage();
                    bitmap.BeginInit();
                    bitmap.CacheOption = BitmapCacheOption.OnLoad;
                    bitmap.DecodePixelWidth = 1600;
                    bitmap.UriSource = new Uri(path);
                    bitmap.EndInit();
                    bitmap.Freeze();
                    image = bitmap;
                }
            }
            catch { }
            if (image != null)
            {
                double ratio = Math.Min((width * 0.94) / image.PixelWidth, (height * 0.84) / image.PixelHeight);
                double w = image.PixelWidth * ratio;
                double h = image.PixelHeight * ratio;
                dc.DrawImage(image, new Rect((width - w) / 2, (height - h) / 2 - height * 0.02, w, h));
            }
            FormattedText caption = Text(owner.CurrentPhotoCaption, body, Math.Max(15, height * 0.022), Brushes.White, FontWeights.Normal);
            dc.DrawText(caption, new Point((width - caption.Width) / 2, height * 0.93));
        }

        private static void DrawGlowText(DrawingContext dc, FormattedText text, Point point, Color glowColor, double radius)
        {
            dc.DrawText(text, point);
        }

        private static FormattedText Text(string value, Typeface typeface, double size, Brush brush, FontWeight weight)
        {
            Typeface actual = new Typeface(typeface.FontFamily, typeface.Style, weight, typeface.Stretch);
            return new FormattedText(value ?? String.Empty, CultureInfo.CurrentCulture, FlowDirection.LeftToRight,
                actual, size, brush);
        }

        private static double Unit(int seed)
        {
            unchecked
            {
                uint value = (uint)seed;
                value ^= value >> 16;
                value *= 0x7feb352d;
                value ^= value >> 15;
                value *= 0x846ca68b;
                value ^= value >> 16;
                return (value & 0x00ffffff) / 16777215.0;
            }
        }

        private static void DrawImageFill(DrawingContext dc, BitmapSource source, Rect bounds, double opacity)
        {
            if (source == null) return;
            double sourceRatio = source.PixelWidth / (double)Math.Max(1, source.PixelHeight);
            double targetRatio = bounds.Width / Math.Max(1.0, bounds.Height);
            Rect destination;
            if (sourceRatio > targetRatio)
            {
                double imageWidth = bounds.Height * sourceRatio;
                destination = new Rect(bounds.X - (imageWidth - bounds.Width) / 2, bounds.Y, imageWidth, bounds.Height);
            }
            else
            {
                double imageHeight = bounds.Width / sourceRatio;
                destination = new Rect(bounds.X, bounds.Y - (imageHeight - bounds.Height) / 2, bounds.Width, imageHeight);
            }
            dc.PushClip(new RectangleGeometry(bounds));
            dc.PushOpacity(opacity);
            dc.DrawImage(source, destination);
            dc.Pop();
            dc.Pop();
        }
    }

    public sealed class Ps2Settings
    {
        public int schemaVersion { get; set; }
        public string installationMode { get; set; }
        public string pcsx2Path { get; set; }
        public string pcsx2DataPath { get; set; }
        public string managedInstallFolder { get; set; }
        public List<string> libraryRoots { get; set; }
        public string biosPath { get; set; }
        public string screenshotFolder { get; set; }
        public string musicFolder { get; set; }
        public string movieFolder { get; set; }
        public string customAssetFolder { get; set; }
        public bool pcsx2OverlayEnabled { get; set; }
        public bool ps2BootAnimationEnabled { get; set; }
        public bool ps2StartupVideoEnabled { get; set; }
        public bool ps2StartupSoundEnabled { get; set; }
        public string ps2StartupSoundPath { get; set; }
        public bool ps2BackgroundMusicEnabled { get; set; }
        public string ps2BackgroundMusicPath { get; set; }
        public bool ps2GameBootSoundEnabled { get; set; }
        public string ps2GameBootSoundPath { get; set; }
        public int ps2BackgroundMusicVolume { get; set; }
        public bool ps2SoundEffectsEnabled { get; set; }
        public string ps2NavigateSoundPath { get; set; }
        public string ps2ConfirmSoundPath { get; set; }
        public string ps2BackSoundPath { get; set; }
        public int ps2SoundEffectsVolume { get; set; }
        public string lastChannel { get; set; }
        public bool fullscreen { get; set; }

        public Ps2Settings()
        {
            schemaVersion = 5;
            installationMode = String.Empty;
            pcsx2Path = String.Empty;
            pcsx2DataPath = String.Empty;
            managedInstallFolder = String.Empty;
            libraryRoots = new List<string>();
            biosPath = String.Empty;
            screenshotFolder = String.Empty;
            musicFolder = String.Empty;
            movieFolder = String.Empty;
            customAssetFolder = String.Empty;
            pcsx2OverlayEnabled = true;
            ps2BootAnimationEnabled = false;
            ps2StartupVideoEnabled = true;
            ps2StartupSoundEnabled = false;
            ps2StartupSoundPath = String.Empty;
            ps2BackgroundMusicEnabled = true;
            ps2BackgroundMusicPath = String.Empty;
            ps2GameBootSoundEnabled = true;
            ps2GameBootSoundPath = String.Empty;
            ps2BackgroundMusicVolume = 70;
            ps2SoundEffectsEnabled = true;
            ps2NavigateSoundPath = String.Empty;
            ps2ConfirmSoundPath = String.Empty;
            ps2BackSoundPath = String.Empty;
            ps2SoundEffectsVolume = 100;
            lastChannel = "GameCollection";
            fullscreen = true;
        }

        public static Ps2Settings Load(string userPath, string defaultPath)
        {
            JavaScriptSerializer serializer = new JavaScriptSerializer();
            Ps2Settings settings = new Ps2Settings();
            try { if (File.Exists(defaultPath)) settings = serializer.Deserialize<Ps2Settings>(File.ReadAllText(defaultPath, Encoding.UTF8)); } catch { }
            try { if (File.Exists(userPath)) settings = serializer.Deserialize<Ps2Settings>(File.ReadAllText(userPath, Encoding.UTF8)); } catch { }
            if (settings == null) settings = new Ps2Settings();
            settings.Normalize();
            settings.Save(userPath);
            return settings;
        }

        public Ps2Settings Clone()
        {
            JavaScriptSerializer serializer = new JavaScriptSerializer();
            return serializer.Deserialize<Ps2Settings>(serializer.Serialize(this));
        }

        public void Save(string path)
        {
            try
            {
                Normalize();
                Directory.CreateDirectory(Path.GetDirectoryName(path));
                string temp = path + "." + Process.GetCurrentProcess().Id + ".tmp";
                File.WriteAllText(temp, new JavaScriptSerializer().Serialize(this), Encoding.UTF8);
                if (File.Exists(path))
                {
                    try { File.Replace(temp, path, path + ".bak", true); }
                    catch { File.Delete(path); File.Move(temp, path); }
                }
                else File.Move(temp, path);
            }
            catch { }
        }

        public void Normalize()
        {
            int loadedSchema = schemaVersion;
            schemaVersion = 5;
            if (installationMode == null) installationMode = String.Empty;
            if (pcsx2Path == null) pcsx2Path = String.Empty;
            if (pcsx2DataPath == null) pcsx2DataPath = String.Empty;
            if (managedInstallFolder == null) managedInstallFolder = String.Empty;
            if (libraryRoots == null) libraryRoots = new List<string>();
            List<string> normalized = new List<string>();
            foreach (string root in libraryRoots)
            {
                if (String.IsNullOrWhiteSpace(root)) continue;
                string full;
                try { full = Path.GetFullPath(Environment.ExpandEnvironmentVariables(root.Trim())).TrimEnd(Path.DirectorySeparatorChar); }
                catch { full = root.Trim().TrimEnd(Path.DirectorySeparatorChar); }
                if (!normalized.Any(delegate(string existing) { return String.Equals(existing, full, StringComparison.OrdinalIgnoreCase); }))
                    normalized.Add(full);
            }
            libraryRoots = normalized;
            if (biosPath == null) biosPath = String.Empty;
            if (screenshotFolder == null) screenshotFolder = String.Empty;
            if (musicFolder == null) musicFolder = String.Empty;
            if (movieFolder == null) movieFolder = String.Empty;
            if (customAssetFolder == null) customAssetFolder = String.Empty;
            if (ps2StartupSoundPath == null) ps2StartupSoundPath = String.Empty;
            if (ps2BackgroundMusicPath == null) ps2BackgroundMusicPath = String.Empty;
            if (ps2GameBootSoundPath == null) ps2GameBootSoundPath = String.Empty;
            if (ps2NavigateSoundPath == null) ps2NavigateSoundPath = String.Empty;
            if (ps2ConfirmSoundPath == null) ps2ConfirmSoundPath = String.Empty;
            if (ps2BackSoundPath == null) ps2BackSoundPath = String.Empty;
            ps2BackgroundMusicVolume = Math.Max(0, Math.Min(100, ps2BackgroundMusicVolume));
            ps2SoundEffectsVolume = Math.Max(0, Math.Min(100, ps2SoundEffectsVolume));
            if (loadedSchema < 2)
            {
                pcsx2OverlayEnabled = true;
                ps2BackgroundMusicEnabled = true;
                ps2SoundEffectsEnabled = true;
                if (ps2BackgroundMusicVolume == 0) ps2BackgroundMusicVolume = 50;
                if (ps2SoundEffectsVolume == 0) ps2SoundEffectsVolume = 75;
            }
            if (loadedSchema < 3) ps2GameBootSoundEnabled = true;
            if (loadedSchema < 5)
            {
                ps2StartupVideoEnabled = true;
                ps2BootAnimationEnabled = false;
                ps2StartupSoundEnabled = false;
                if (ps2BackgroundMusicVolume == 50) ps2BackgroundMusicVolume = 70;
                if (ps2SoundEffectsVolume == 75) ps2SoundEffectsVolume = 100;
            }
            pcsx2OverlayEnabled = true;
            schemaVersion = 5;
            if (lastChannel == null) lastChannel = "GameCollection";
        }
    }

    internal sealed class BbnChannel
    {
        internal string Id;
        internal string Title;
        internal string Subtitle;
        internal List<BbnItem> Items;
        internal int SelectedIndex;
        internal BbnChannel(string id, string title, string subtitle)
        {
            Id = id; Title = title; Subtitle = subtitle; Items = new List<BbnItem>(); SelectedIndex = 0;
        }
    }

    internal sealed class BbnItem
    {
        internal string Title;
        internal string Subtitle;
        internal string Action;
        internal List<BbnItem> Children;
        internal Ps2Game Game;
        internal string MemoryCardPath;
        internal Ps2CardSaveEntry SaveEntry;
        internal Ps2IconModel SaveIcon;
        internal BbnItem(string title, string subtitle, string action)
            : this(title, subtitle, action, null, null) { }
        internal BbnItem(string title, string subtitle, string action, List<BbnItem> children)
            : this(title, subtitle, action, children, null) { }
        internal BbnItem(string title, string subtitle, string action, List<BbnItem> children, Ps2Game game)
        {
            Title = title; Subtitle = subtitle; Action = action; Children = children; Game = game;
            MemoryCardPath = String.Empty; SaveEntry = null; SaveIcon = null;
        }
    }

    internal sealed class BbnMenuContext
    {
        internal string Title;
        internal List<BbnItem> Items;
        internal int ParentSelection;
        internal bool MemoryBrowser;
        internal bool MemoryCardContent;
        internal string MemoryCardPath;
        internal string MemoryCardFreeText;
        internal bool MemoryOptions;
        internal BbnMenuContext(string title, List<BbnItem> items, int parentSelection)
            : this(title, items, parentSelection, false, false, String.Empty, String.Empty, false) { }
        internal BbnMenuContext(string title, List<BbnItem> items, int parentSelection, bool memoryBrowser)
            : this(title, items, parentSelection, memoryBrowser, false, String.Empty, String.Empty, false) { }
        internal BbnMenuContext(string title, List<BbnItem> items, int parentSelection, bool memoryBrowser, bool memoryCardContent, string memoryCardPath, string memoryCardFreeText)
            : this(title, items, parentSelection, memoryBrowser, memoryCardContent, memoryCardPath, memoryCardFreeText, false) { }
        internal BbnMenuContext(string title, List<BbnItem> items, int parentSelection, bool memoryBrowser, bool memoryCardContent, string memoryCardPath, string memoryCardFreeText, bool memoryOptions)
        {
            Title = title;
            Items = items ?? new List<BbnItem>();
            ParentSelection = parentSelection;
            MemoryBrowser = memoryBrowser;
            MemoryCardContent = memoryCardContent;
            MemoryCardPath = memoryCardPath ?? String.Empty;
            MemoryCardFreeText = memoryCardFreeText ?? String.Empty;
            MemoryOptions = memoryOptions;
        }
    }

    internal sealed class Ps2Game
    {
        internal string Title = String.Empty;
        internal string Serial = String.Empty;
        internal string Path = String.Empty;
        internal string CoverPath = String.Empty;
    }

    internal sealed class Ps2MemoryCard
    {
        internal string Name = String.Empty;
        internal string Path = String.Empty;
        internal string Subtitle = String.Empty;
    }

    internal sealed class Ps2CardSaveEntry
    {
        internal string DirectoryName = String.Empty;
        internal string Title = String.Empty;
        internal long SizeBytes;
        internal int FileCount;
        internal DateTime Modified = DateTime.MinValue;
        internal string DetailText = String.Empty;
        internal Ps2IconModel IconModel;
    }

    internal static class Ps2SaveTitleReader
    {
        internal static string ReadFolderTitle(string folder)
        {
            try
            {
                string path = Directory.EnumerateFiles(folder, "icon.sys", SearchOption.TopDirectoryOnly).FirstOrDefault();
                if (String.IsNullOrWhiteSpace(path)) return String.Empty;
                return ReadIconTitle(File.ReadAllBytes(path));
            }
            catch { return String.Empty; }
        }

        internal static Ps2IconModel ReadFolderIconModel(string folder)
        {
            try
            {
                string systemPath = Directory.EnumerateFiles(folder, "icon.sys", SearchOption.TopDirectoryOnly).FirstOrDefault();
                if (String.IsNullOrWhiteSpace(systemPath)) return null;
                byte[] system = File.ReadAllBytes(systemPath);
                string fileName = ReadIconFileName(system, 0x104);
                if (String.IsNullOrWhiteSpace(fileName)) return null;
                string modelPath = Path.Combine(folder, fileName);
                if (!File.Exists(modelPath)) return null;
                return Ps2IconModel.Parse(File.ReadAllBytes(modelPath));
            }
            catch { return null; }
        }

        internal static string ReadIconFileName(byte[] bytes, int offset)
        {
            if (bytes == null || offset < 0 || offset >= bytes.Length) return String.Empty;
            int length = Math.Min(64, bytes.Length - offset);
            int zero = Array.IndexOf(bytes, (byte)0, offset, length);
            if (zero < 0) zero = offset + length;
            try { return Encoding.ASCII.GetString(bytes, offset, Math.Max(0, zero - offset)).Trim(); }
            catch { return String.Empty; }
        }

        internal static string ReadIconTitle(byte[] bytes)
        {
            if (bytes == null || bytes.Length < 0x104) return String.Empty;
            if (Encoding.ASCII.GetString(bytes, 0, 4) != "PS2D") return String.Empty;
            try
            {
                int length = Math.Min(68, bytes.Length - 0xC0);
                int zero = Array.IndexOf(bytes, (byte)0, 0xC0, length);
                if (zero < 0) zero = 0xC0 + length;
                byte[] title = new byte[Math.Max(0, zero - 0xC0)];
                Buffer.BlockCopy(bytes, 0xC0, title, 0, title.Length);
                string value = Encoding.GetEncoding(932).GetString(title).Replace('\0', ' ').Trim();
                return String.Join(" ", value.Split(new char[] { '\r', '\n', '\t' }, StringSplitOptions.RemoveEmptyEntries)).Trim();
            }
            catch { return String.Empty; }
        }
    }

    internal static class Ps2MemoryCardImageReader
    {
        private const ushort Exists = 0x8000;
        private const ushort FileMode = 0x0010;
        private const ushort DirectoryMode = 0x0020;

        internal static bool TryRead(string path, out List<Ps2CardSaveEntry> saves, out long freeBytes, out string error)
        {
            saves = new List<Ps2CardSaveEntry>();
            freeBytes = 0;
            error = String.Empty;
            try
            {
                using (Ps2CardImage image = new Ps2CardImage(path))
                {
                    List<Ps2CardDirectoryEntry> root = image.ReadDirectory(image.RootDirectoryCluster, 2048);
                    foreach (Ps2CardDirectoryEntry entry in root)
                    {
                        if (!entry.Exists || !entry.IsDirectory || entry.Name == "." || entry.Name == ".." || String.IsNullOrWhiteSpace(entry.Name)) continue;
                        List<Ps2CardDirectoryEntry> children = image.ReadDirectory(entry.Cluster, Math.Max(2, entry.Length));
                        long size = 0;
                        int files = 0;
                        DateTime modified = entry.Modified;
                        byte[] icon = null;
                        Dictionary<string, Ps2CardDirectoryEntry> filesByName = new Dictionary<string, Ps2CardDirectoryEntry>(StringComparer.OrdinalIgnoreCase);
                        foreach (Ps2CardDirectoryEntry child in children)
                        {
                            if (!child.Exists || child.Name == "." || child.Name == "..") continue;
                            if (child.IsFile)
                            {
                                size += child.Length;
                                files++;
                                filesByName[child.Name] = child;
                                if (child.Name.Equals("icon.sys", StringComparison.OrdinalIgnoreCase))
                                    icon = image.ReadFile(child.Cluster, child.Length);
                            }
                        }
                        string title = Ps2SaveTitleReader.ReadIconTitle(icon);
                        Ps2IconModel iconModel = null;
                        string iconFileName = Ps2SaveTitleReader.ReadIconFileName(icon, 0x104);
                        Ps2CardDirectoryEntry iconEntry;
                        if (!String.IsNullOrWhiteSpace(iconFileName) && filesByName.TryGetValue(iconFileName, out iconEntry))
                            iconModel = Ps2IconModel.Parse(image.ReadFile(iconEntry.Cluster, iconEntry.Length));
                        Ps2CardSaveEntry save = new Ps2CardSaveEntry {
                            DirectoryName = entry.Name,
                            Title = String.IsNullOrWhiteSpace(title) ? entry.Name : title,
                            SizeBytes = size,
                            FileCount = files,
                            Modified = modified,
                            DetailText = entry.Name + " • File Memory Card",
                            IconModel = iconModel
                        };
                        saves.Add(save);
                    }
                    freeBytes = image.GetFreeBytes();
                }
                saves = saves.OrderBy(delegate(Ps2CardSaveEntry save) { return save.Title; }, StringComparer.CurrentCultureIgnoreCase).ToList();
                return true;
            }
            catch (Exception ex) { error = ex.Message; return false; }
        }

        internal static bool ExportSave(string cardPath, string directoryName, string destination, out string error)
        {
            error = String.Empty;
            try
            {
                using (Ps2CardImage image = new Ps2CardImage(cardPath))
                {
                    Ps2CardDirectoryEntry save = image.ReadDirectory(image.RootDirectoryCluster, 2048)
                        .FirstOrDefault(delegate(Ps2CardDirectoryEntry entry)
                        {
                            return entry.Exists && entry.IsDirectory && String.Equals(entry.Name, directoryName, StringComparison.Ordinal);
                        });
                    if (save == null) throw new InvalidOperationException("The selected save no longer exists on the card.");
                    Directory.CreateDirectory(destination);
                    foreach (Ps2CardDirectoryEntry child in image.ReadDirectory(save.Cluster, Math.Max(2, save.Length)))
                    {
                        if (!child.Exists || !child.IsFile || child.Name == "." || child.Name == "..") continue;
                        string safe = MakeSafeFileName(child.Name);
                        File.WriteAllBytes(Path.Combine(destination, safe), image.ReadFile(child.Cluster, child.Length));
                    }
                    File.WriteAllText(Path.Combine(destination, "HUYMAIER-SAVE-INFO.txt"),
                        "Directory: " + directoryName + Environment.NewLine +
                        "Source card: " + cardPath + Environment.NewLine +
                        "Exported: " + DateTime.Now.ToString("o") + Environment.NewLine,
                        Encoding.UTF8);
                }
                return true;
            }
            catch (Exception ex) { error = ex.Message; return false; }
        }

        private static string MakeSafeFileName(string name)
        {
            string value = name ?? "file";
            foreach (char invalid in Path.GetInvalidFileNameChars()) value = value.Replace(invalid, '_');
            return String.IsNullOrWhiteSpace(value) ? "file" : value;
        }

        private sealed class Ps2CardImage : IDisposable
        {
            private readonly FileStream stream;
            private readonly int pageLength;
            private readonly int pagesPerCluster;
            private readonly int pageStride;
            private readonly int clusterSize;
            private readonly uint clustersPerCard;
            private readonly uint allocationOffset;
            private readonly uint allocationEnd;
            private readonly uint[] ifcList;
            private readonly Dictionary<uint, byte[]> clusterCache;
            private readonly Dictionary<uint, uint> fatCache;
            internal uint RootDirectoryCluster { get; private set; }

            internal Ps2CardImage(string path)
            {
                if (String.IsNullOrWhiteSpace(path) || !File.Exists(path)) throw new FileNotFoundException("Memory card not found", path);
                stream = System.IO.File.Open(path, System.IO.FileMode.Open, System.IO.FileAccess.Read, System.IO.FileShare.ReadWrite);
                byte[] super = new byte[512];
                if (stream.Read(super, 0, super.Length) != super.Length) throw new InvalidDataException("Memory card is too small.");
                if (Encoding.ASCII.GetString(super, 0, 27) != "Sony PS2 Memory Card Format")
                    throw new InvalidDataException("This card is unformatted or is not a supported PS2 file memory card.");
                pageLength = ReadU16(super, 0x28);
                pagesPerCluster = ReadU16(super, 0x2A);
                clustersPerCard = ReadU32(super, 0x30);
                allocationOffset = ReadU32(super, 0x34);
                allocationEnd = ReadU32(super, 0x38);
                RootDirectoryCluster = ReadU32(super, 0x3C);
                if (pageLength <= 0 || pagesPerCluster <= 0 || clustersPerCard == 0) throw new InvalidDataException("Invalid memory-card geometry.");
                long pages = (long)clustersPerCard * pagesPerCluster;
                long plainLength = pages * pageLength;
                long eccLength = pages * (pageLength + 16L);
                pageStride = Math.Abs(stream.Length - eccLength) < Math.Abs(stream.Length - plainLength) ? pageLength + 16 : pageLength;
                clusterSize = pageLength * pagesPerCluster;
                ifcList = new uint[32];
                for (int index = 0; index < ifcList.Length; index++) ifcList[index] = ReadU32(super, 0x50 + index * 4);
                clusterCache = new Dictionary<uint, byte[]>();
                fatCache = new Dictionary<uint, uint>();
            }

            public void Dispose() { stream.Dispose(); }

            internal List<Ps2CardDirectoryEntry> ReadDirectory(uint relativeCluster, int expectedEntries)
            {
                List<Ps2CardDirectoryEntry> result = new List<Ps2CardDirectoryEntry>();
                List<uint> chain = FollowChain(relativeCluster, Math.Max(2, expectedEntries / Math.Max(1, clusterSize / 512) + 4));
                int limit = Math.Min(Math.Max(2, expectedEntries), 4096);
                foreach (uint cluster in chain)
                {
                    byte[] data = ReadClusterAbsolute(allocationOffset + cluster);
                    for (int offset = 0; offset + 512 <= data.Length && result.Count < limit; offset += 512)
                        result.Add(ParseDirectoryEntry(data, offset));
                    if (result.Count >= limit) break;
                }
                if (result.Count > 0 && result[0].Length > 0 && result[0].Length < result.Count)
                    result = result.Take(result[0].Length).ToList();
                return result;
            }

            internal byte[] ReadFile(uint relativeCluster, int length)
            {
                if (length <= 0 || relativeCluster == 0xFFFFFFFF) return new byte[0];
                MemoryStream output = new MemoryStream(length);
                foreach (uint cluster in FollowChain(relativeCluster, Math.Max(1, (length + clusterSize - 1) / clusterSize + 2)))
                {
                    byte[] data = ReadClusterAbsolute(allocationOffset + cluster);
                    int remaining = length - (int)output.Length;
                    if (remaining <= 0) break;
                    output.Write(data, 0, Math.Min(remaining, data.Length));
                }
                return output.ToArray();
            }

            internal long GetFreeBytes()
            {
                long free = 0;
                uint end = allocationEnd > 0 && allocationEnd < clustersPerCard ? allocationEnd : clustersPerCard - allocationOffset;
                for (uint index = 0; index < end; index++)
                {
                    uint value = ReadFat(index);
                    if ((value & 0x80000000U) == 0) free++;
                }
                return free * clusterSize;
            }

            private List<uint> FollowChain(uint start, int maxClusters)
            {
                List<uint> result = new List<uint>();
                HashSet<uint> seen = new HashSet<uint>();
                uint current = start;
                for (int count = 0; count < Math.Min(16384, Math.Max(1, maxClusters)); count++)
                {
                    if (current == 0xFFFFFFFF || current >= clustersPerCard || !seen.Add(current)) break;
                    result.Add(current);
                    uint fat = ReadFat(current);
                    if (fat == 0xFFFFFFFF) break;
                    if ((fat & 0x80000000U) == 0) break;
                    current = fat & 0x7FFFFFFFU;
                }
                return result;
            }

            private uint ReadFat(uint relativeIndex)
            {
                uint cached;
                if (fatCache.TryGetValue(relativeIndex, out cached)) return cached;
                int entriesPerCluster = clusterSize / 4;
                uint indirectIndex = relativeIndex / (uint)entriesPerCluster;
                int fatOffset = (int)(relativeIndex % (uint)entriesPerCluster);
                int doubleIndex = (int)(indirectIndex / (uint)entriesPerCluster);
                int indirectOffset = (int)(indirectIndex % (uint)entriesPerCluster);
                if (doubleIndex < 0 || doubleIndex >= ifcList.Length || ifcList[doubleIndex] == 0xFFFFFFFF)
                    return 0;
                byte[] indirect = ReadClusterAbsolute(ifcList[doubleIndex]);
                uint fatCluster = ReadU32(indirect, indirectOffset * 4);
                if (fatCluster == 0xFFFFFFFF) return 0;
                byte[] fat = ReadClusterAbsolute(fatCluster);
                uint value = ReadU32(fat, fatOffset * 4);
                fatCache[relativeIndex] = value;
                return value;
            }

            private byte[] ReadClusterAbsolute(uint absoluteCluster)
            {
                byte[] cached;
                if (clusterCache.TryGetValue(absoluteCluster, out cached)) return cached;
                byte[] result = new byte[clusterSize];
                for (int page = 0; page < pagesPerCluster; page++)
                {
                    long physicalPage = (long)absoluteCluster * pagesPerCluster + page;
                    stream.Position = physicalPage * pageStride;
                    int target = page * pageLength;
                    int read = 0;
                    while (read < pageLength)
                    {
                        int amount = stream.Read(result, target + read, pageLength - read);
                        if (amount <= 0) throw new EndOfStreamException("Unexpected end of memory-card image.");
                        read += amount;
                    }
                }
                clusterCache[absoluteCluster] = result;
                return result;
            }

            private static Ps2CardDirectoryEntry ParseDirectoryEntry(byte[] data, int offset)
            {
                ushort mode = ReadU16(data, offset);
                int length = unchecked((int)ReadU32(data, offset + 4));
                uint cluster = ReadU32(data, offset + 0x10);
                DateTime modified = ReadTime(data, offset + 0x18);
                int nameLength = 0;
                while (nameLength < 32 && data[offset + 0x40 + nameLength] != 0) nameLength++;
                string name;
                try { name = Encoding.GetEncoding(932).GetString(data, offset + 0x40, nameLength); }
                catch { name = Encoding.ASCII.GetString(data, offset + 0x40, nameLength); }
                return new Ps2CardDirectoryEntry {
                    Mode = mode, Length = Math.Max(0, length), Cluster = cluster, Modified = modified,
                    Name = name.Trim()
                };
            }

            private static DateTime ReadTime(byte[] data, int offset)
            {
                try
                {
                    int second = data[offset + 1];
                    int minute = data[offset + 2];
                    int hour = data[offset + 3];
                    int day = data[offset + 4];
                    int month = data[offset + 5];
                    int year = ReadU16(data, offset + 6);
                    if (year < 1990 || year > 2200 || month < 1 || month > 12 || day < 1 || day > DateTime.DaysInMonth(year, month)) return DateTime.MinValue;
                    return new DateTime(year, month, day, Math.Min(23, hour), Math.Min(59, minute), Math.Min(59, second), DateTimeKind.Unspecified);
                }
                catch { return DateTime.MinValue; }
            }
        }

        private sealed class Ps2CardDirectoryEntry
        {
            internal ushort Mode;
            internal int Length;
            internal uint Cluster;
            internal DateTime Modified;
            internal string Name;
            internal bool Exists { get { return (Mode & Ps2MemoryCardImageReader.Exists) != 0; } }
            internal bool IsFile { get { return (Mode & Ps2MemoryCardImageReader.FileMode) != 0; } }
            internal bool IsDirectory { get { return (Mode & Ps2MemoryCardImageReader.DirectoryMode) != 0; } }
        }

        private static ushort ReadU16(byte[] data, int offset)
        {
            return (ushort)(data[offset] | (data[offset + 1] << 8));
        }

        private static uint ReadU32(byte[] data, int offset)
        {
            return (uint)(data[offset] | (data[offset + 1] << 8) | (data[offset + 2] << 16) | (data[offset + 3] << 24));
        }
    }

    internal sealed class Ps2IconModel
    {
        internal Ps2IconPoint[][] Shapes;
        internal Color[] Colors;
        internal Ps2IconUv[] Uvs;
        internal Color[] Texture;
        internal BitmapSource TextureBitmap;
        internal int VertexCount;

        internal Color SampleTriangleColor(int i0, int i1, int i2)
        {
            Color vertex = Average(Colors[i0], Colors[i1], Colors[i2]);
            if (Texture == null || Texture.Length != 128 * 128 || Uvs == null) return vertex;
            double u = (Uvs[i0].U + Uvs[i1].U + Uvs[i2].U) / 3.0;
            double v = (Uvs[i0].V + Uvs[i1].V + Uvs[i2].V) / 3.0;
            u -= Math.Floor(u); v -= Math.Floor(v);
            int x = Math.Max(0, Math.Min(127, (int)Math.Round(u * 127.0)));
            int y = Math.Max(0, Math.Min(127, (int)Math.Round(v * 127.0)));
            Color texture = Texture[y * 128 + x];
            return Color.FromArgb((byte)Math.Max(30, Math.Min(255, texture.A * vertex.A / 255)),
                (byte)(texture.R * vertex.R / 255), (byte)(texture.G * vertex.G / 255), (byte)(texture.B * vertex.B / 255));
        }

        private static Color Average(Color a, Color b, Color c)
        {
            return Color.FromArgb((byte)Math.Max(30, (a.A + b.A + c.A) / 3),
                (byte)((a.R + b.R + c.R) / 3), (byte)((a.G + b.G + c.G) / 3), (byte)((a.B + b.B + c.B) / 3));
        }

        internal static Ps2IconModel Parse(byte[] bytes)
        {
            try
            {
                if (bytes == null || bytes.Length < 20) return null;
                int shapeCount = unchecked((int)ReadU32(bytes, 4));
                uint textureType = ReadU32(bytes, 8);
                int vertexCount = unchecked((int)ReadU32(bytes, 16));
                if (shapeCount < 1 || shapeCount > 32 || vertexCount < 3 || vertexCount > 4096) return null;
                int stride = checked(shapeCount * 8 + 16);
                int vertexEnd = checked(20 + vertexCount * stride);
                if (vertexEnd > bytes.Length) return null;
                Ps2IconModel model = new Ps2IconModel();
                model.VertexCount = vertexCount;
                model.Shapes = new Ps2IconPoint[shapeCount][];
                for (int shape = 0; shape < shapeCount; shape++) model.Shapes[shape] = new Ps2IconPoint[vertexCount];
                model.Colors = new Color[vertexCount];
                model.Uvs = new Ps2IconUv[vertexCount];
                for (int vertex = 0; vertex < vertexCount; vertex++)
                {
                    int baseOffset = 20 + vertex * stride;
                    for (int shape = 0; shape < shapeCount; shape++)
                    {
                        int offset = baseOffset + shape * 8;
                        model.Shapes[shape][vertex] = new Ps2IconPoint(
                            ReadS16(bytes, offset) / 4096.0,
                            ReadS16(bytes, offset + 2) / 4096.0,
                            ReadS16(bytes, offset + 4) / 4096.0);
                    }
                    int uvOffset = baseOffset + shapeCount * 8 + 8;
                    model.Uvs[vertex] = new Ps2IconUv(ReadS16(bytes, uvOffset) / 4096.0, ReadS16(bytes, uvOffset + 2) / 4096.0);
                    int colorOffset = baseOffset + shapeCount * 8 + 12;
                    int rawAlpha = bytes[colorOffset + 3];
                    byte alpha = (byte)(rawAlpha == 0 ? 255 : Math.Min(255, rawAlpha * 2));
                    model.Colors[vertex] = Color.FromArgb(alpha, bytes[colorOffset], bytes[colorOffset + 1], bytes[colorOffset + 2]);
                }

                int textureOffset = FindTextureOffset(bytes, vertexEnd);
                byte[] textureBytes = TryReadTexture(bytes, textureOffset, textureType);
                if (textureBytes != null && textureBytes.Length >= 32768)
                {
                    model.Texture = new Color[128 * 128];
                    for (int pixel = 0; pixel < model.Texture.Length; pixel++)
                    {
                        ushort value = ReadU16(textureBytes, pixel * 2);
                        byte r = (byte)((value & 0x1f) * 255 / 31);
                        byte g = (byte)(((value >> 5) & 0x1f) * 255 / 31);
                        byte b = (byte)(((value >> 10) & 0x1f) * 255 / 31);
                        // The high bit is unused by the icon texture; transparency comes
                        // from the per-vertex RGBA stream.
                        model.Texture[pixel] = Color.FromArgb(255, r, g, b);
                    }
                    model.BuildTextureBitmap();
                }
                return model;
            }
            catch { return null; }
        }

        private void BuildTextureBitmap()
        {
            if (Texture == null || Texture.Length != 128 * 128) return;
            byte[] pixels = new byte[128 * 128 * 4];
            for (int index = 0; index < Texture.Length; index++)
            {
                Color color = Texture[index];
                int offset = index * 4;
                pixels[offset] = color.B;
                pixels[offset + 1] = color.G;
                pixels[offset + 2] = color.R;
                pixels[offset + 3] = color.A;
            }
            BitmapSource bitmap = BitmapSource.Create(128, 128, 96, 96, PixelFormats.Bgra32,
                null, pixels, 128 * 4);
            bitmap.Freeze();
            TextureBitmap = bitmap;
        }

        private static byte[] TryReadTexture(byte[] data, int textureOffset, uint textureType)
        {
            if (data == null || textureOffset < 0 || textureOffset >= data.Length) return null;
            List<int> candidates = new List<int>();
            bool compressed = (textureType & 0x8) != 0;
            int tail = data.Length - 32768;
            // An uncompressed icon normally ends with exactly 32768 texture bytes;
            // prefer that boundary so alignment padding cannot shift the image.
            if (!compressed && tail >= textureOffset) candidates.Add(tail);
            candidates.Add(textureOffset);
            int aligned4 = (textureOffset + 3) & ~3;
            int aligned16 = (textureOffset + 15) & ~15;
            if (!candidates.Contains(aligned4)) candidates.Add(aligned4);
            if (!candidates.Contains(aligned16)) candidates.Add(aligned16);
            foreach (int candidate in candidates)
            {
                if (candidate < 0 || candidate >= data.Length) continue;
                byte[] result = null;
                if (compressed)
                {
                    result = DecodeRleTexture(data, candidate);
                }
                else if (candidate + 32768 <= data.Length)
                {
                    result = new byte[32768];
                    Buffer.BlockCopy(data, candidate, result, 0, result.Length);
                }
                // Some valid icons omit or misuse the compression flag. Only attempt
                // RLE as the fallback when a complete raw image was unavailable.
                if (result == null) result = DecodeRleTexture(data, candidate);
                if (result != null && result.Length >= 32768) return result;
            }
            return null;
        }

        private static int FindTextureOffset(byte[] data, int offset)
        {
            if (offset + 20 > data.Length) return offset;
            try
            {
                int frameCount = unchecked((int)ReadU32(data, offset + 16));
                if (frameCount < 0 || frameCount > 4096) return offset;
                int cursor = offset + 20;
                for (int frame = 0; frame < frameCount; frame++)
                {
                    if (cursor + 16 > data.Length) return -1;
                    int keys = unchecked((int)ReadU32(data, cursor + 4));
                    if (keys < 0 || keys > 4096) return -1;
                    cursor = checked(cursor + 16 + keys * 8);
                    if (cursor > data.Length) return -1;
                }
                return cursor;
            }
            catch { return -1; }
        }

        private static byte[] DecodeRleTexture(byte[] data, int offset)
        {
            try
            {
                if (offset + 4 > data.Length) return null;
                int compressedSize = unchecked((int)ReadU32(data, offset));
                int cursor = offset + 4;
                int end = compressedSize > 0 && cursor + compressedSize <= data.Length ? cursor + compressedSize : data.Length;
                List<byte> output = new List<byte>(32768);
                while (cursor + 2 <= end && output.Count < 32768)
                {
                    ushort code = ReadU16(data, cursor); cursor += 2;
                    if (code >= 0xFF00)
                    {
                        int count = 0x10000 - code;
                        int bytes = Math.Min(count * 2, Math.Min(end - cursor, 32768 - output.Count));
                        for (int i = 0; i < bytes; i++) output.Add(data[cursor + i]);
                        cursor += bytes;
                    }
                    else
                    {
                        if (cursor + 2 > end) break;
                        byte lo = data[cursor++], hi = data[cursor++];
                        int count = Math.Min((int)code, (32768 - output.Count) / 2);
                        for (int i = 0; i < count; i++) { output.Add(lo); output.Add(hi); }
                    }
                }
                return output.Count >= 32768 ? output.Take(32768).ToArray() : null;
            }
            catch { return null; }
        }

        private static short ReadS16(byte[] data, int offset) { return unchecked((short)(data[offset] | (data[offset + 1] << 8))); }
        private static ushort ReadU16(byte[] data, int offset) { return (ushort)(data[offset] | (data[offset + 1] << 8)); }
        private static uint ReadU32(byte[] data, int offset) { return (uint)(data[offset] | (data[offset + 1] << 8) | (data[offset + 2] << 16) | (data[offset + 3] << 24)); }
    }

    internal struct Ps2IconUv
    {
        internal double U;
        internal double V;
        internal Ps2IconUv(double u, double v) { U = u; V = v; }
    }

    internal sealed class Ps2IconTriangleRender
    {
        internal Point[] Points;
        internal Point[] TexturePoints;
        internal BitmapSource Texture;
        internal double Depth;
        internal double Opacity;
        internal double Shade;
        internal Color Fill;
    }

    internal struct Ps2IconPoint
    {
        internal double X;
        internal double Y;
        internal double Z;
        internal Ps2IconPoint(double x, double y, double z) { X = x; Y = y; Z = z; }
    }

    internal sealed class Ps2SaveVisual
    {
        internal int Seed;
        internal double Weight;
        internal double Freshness;
        internal string Label = String.Empty;
    }

    internal static class Ps2SaveVisualScanner
    {
        internal static List<Ps2SaveVisual> Scan(string memoryCardRoot)
        {
            List<Ps2SaveVisual> result = new List<Ps2SaveVisual>();
            if (String.IsNullOrWhiteSpace(memoryCardRoot) || !Directory.Exists(memoryCardRoot)) return result;
            try
            {
                foreach (string entry in Directory.EnumerateFileSystemEntries(memoryCardRoot).Take(128))
                {
                    if (Directory.Exists(entry)) AddFolderCard(result, entry);
                    else if (File.Exists(entry)) AddRawCard(result, entry);
                    if (result.Count >= 64) break;
                }
            }
            catch { }
            return result.OrderBy(delegate(Ps2SaveVisual item) { return item.Seed; }).Take(48).ToList();
        }

        private static void AddFolderCard(List<Ps2SaveVisual> target, string cardPath)
        {
            int before = target.Count;
            try
            {
                foreach (string save in Directory.EnumerateDirectories(cardPath).Take(48))
                {
                    long size = DirectorySize(save);
                    DateTime modified;
                    try { modified = Directory.GetLastWriteTimeUtc(save); } catch { modified = DateTime.MinValue; }
                    target.Add(new Ps2SaveVisual {
                        Seed = StableHash(save),
                        Weight = Clamp(0.18 + Math.Log(1.0 + Math.Max(0L, size) / 8192.0, 2.0) / 8.0, 0.18, 1.0),
                        Freshness = Freshness(modified),
                        Label = Path.GetFileName(save)
                    });
                    if (target.Count >= 64) break;
                }
            }
            catch { }
            if (target.Count == before)
            {
                long size = DirectorySize(cardPath);
                if (size > 0)
                {
                    target.Add(new Ps2SaveVisual {
                        Seed = StableHash(cardPath),
                        Weight = Clamp(0.15 + Math.Log(1.0 + size / 8192.0, 2.0) / 9.0, 0.15, 0.72),
                        Freshness = Freshness(Directory.GetLastWriteTimeUtc(cardPath)),
                        Label = Path.GetFileName(cardPath)
                    });
                }
            }
        }

        private static void AddRawCard(List<Ps2SaveVisual> target, string path)
        {
            string extension = Path.GetExtension(path);
            if (!extension.Equals(".ps2", StringComparison.OrdinalIgnoreCase) &&
                !extension.Equals(".mcd", StringComparison.OrdinalIgnoreCase) &&
                !extension.Equals(".mc2", StringComparison.OrdinalIgnoreCase) &&
                !extension.Equals(".bin", StringComparison.OrdinalIgnoreCase)) return;
            try
            {
                FileInfo info = new FileInfo(path);
                if (info.Length <= 0) return;
                const int chunkSize = 32768;
                const int sampleCount = 72;
                byte[] buffer = new byte[chunkSize];
                int added = 0;
                using (FileStream stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))
                {
                    long start = Math.Min(131072L, Math.Max(0L, stream.Length / 32L));
                    long span = Math.Max(1L, stream.Length - start - chunkSize);
                    for (int sample = 0; sample < sampleCount && added < 24; sample++)
                    {
                        long position = start + (long)(span * (sample / (double)Math.Max(1, sampleCount - 1)));
                        stream.Position = Math.Max(0L, Math.Min(position, Math.Max(0L, stream.Length - chunkSize)));
                        int read = stream.Read(buffer, 0, buffer.Length);
                        if (read <= 0) continue;
                        int tested = 0;
                        int active = 0;
                        for (int index = 0; index < read; index += 32)
                        {
                            tested++;
                            if (buffer[index] != 0xff) active++;
                        }
                        double ratio = tested > 0 ? active / (double)tested : 0.0;
                        if (ratio < 0.025) continue;
                        target.Add(new Ps2SaveVisual {
                            Seed = StableHash(path + "#" + sample),
                            Weight = Clamp(0.16 + ratio * 1.55, 0.16, 1.0),
                            Freshness = Freshness(info.LastWriteTimeUtc),
                            Label = Path.GetFileNameWithoutExtension(path)
                        });
                        added++;
                    }
                }
                if (added == 0 && info.LastWriteTimeUtc > DateTime.UtcNow.AddYears(-20))
                {
                    target.Add(new Ps2SaveVisual {
                        Seed = StableHash(path),
                        Weight = 0.14,
                        Freshness = Freshness(info.LastWriteTimeUtc),
                        Label = Path.GetFileNameWithoutExtension(path)
                    });
                }
            }
            catch { }
        }

        private static long DirectorySize(string path)
        {
            try
            {
                return Directory.EnumerateFiles(path, "*", SearchOption.AllDirectories).Take(4096)
                    .Sum(delegate(string file) { try { return new FileInfo(file).Length; } catch { return 0L; } });
            }
            catch { return 0L; }
        }

        private static double Freshness(DateTime modifiedUtc)
        {
            if (modifiedUtc == DateTime.MinValue) return 0.25;
            double days = Math.Max(0.0, (DateTime.UtcNow - modifiedUtc).TotalDays);
            return Clamp(1.0 - Math.Log(1.0 + days, 10.0) / 3.0, 0.12, 1.0);
        }

        private static int StableHash(string value)
        {
            unchecked
            {
                uint hash = 2166136261;
                foreach (char c in value ?? String.Empty)
                {
                    hash ^= Char.ToUpperInvariant(c);
                    hash *= 16777619;
                }
                return (int)(hash & 0x7fffffff);
            }
        }

        private static double Clamp(double value, double minimum, double maximum)
        {
            return Math.Max(minimum, Math.Min(maximum, value));
        }
    }

    internal static class Ps2LibraryScanner
    {
        private static readonly HashSet<string> Extensions = new HashSet<string>(
            new string[] { ".iso", ".bin", ".chd", ".cso", ".gz", ".elf", ".img", ".mdf", ".nrg" },
            StringComparer.OrdinalIgnoreCase);
        private static readonly System.Text.RegularExpressions.Regex SerialPattern =
            new System.Text.RegularExpressions.Regex(@"(?i)\b([A-Z]{4})[-_ ]?(\d{3})[._-]?(\d{2})\b",
                System.Text.RegularExpressions.RegexOptions.Compiled);

        internal static List<Ps2Game> Scan(Ps2Settings settings, string dataRoot, Action<string, string> log)
        {
            Dictionary<string, Ps2Game> unique = new Dictionary<string, Ps2Game>(StringComparer.OrdinalIgnoreCase);
            List<string> roots = new List<string>(settings.libraryRoots ?? new List<string>());
            string iniPath = Pcsx2PathResolver.FindIniPath(dataRoot);
            SimpleIniFile ini = new SimpleIniFile(iniPath, Path.Combine(dataRoot, ".huymaier-backups"));
            string configured = ini.Get("GameList", "RecursivePaths", String.Empty);
            foreach (string raw in configured.Split(new char[] { '|', ';', '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries))
            {
                string path;
                try { path = Path.IsPathRooted(raw.Trim()) ? Path.GetFullPath(raw.Trim()) : Path.GetFullPath(Path.Combine(dataRoot, raw.Trim())); }
                catch { continue; }
                if (!roots.Any(delegate(string existing) { return String.Equals(existing, path, StringComparison.OrdinalIgnoreCase); }))
                    roots.Add(path);
            }

            roots = NormalizeRoots(roots);
            int visitedFiles = 0;
            int visitedDirectories = 0;
            foreach (string root in roots)
            {
                if (String.IsNullOrWhiteSpace(root) || !Directory.Exists(root)) continue;
                Queue<DirectoryDepth> pending = new Queue<DirectoryDepth>();
                pending.Enqueue(new DirectoryDepth(root, 0));
                while (pending.Count > 0 && visitedFiles < 25000 && visitedDirectories < 12000 && unique.Count < 5000)
                {
                    DirectoryDepth current = pending.Dequeue();
                    visitedDirectories++;
                    IEnumerable<string> files;
                    try { files = Directory.EnumerateFiles(current.Path); }
                    catch { files = Enumerable.Empty<string>(); }
                    foreach (string path in files)
                    {
                        if (++visitedFiles > 25000 || unique.Count >= 5000) break;
                        if (!Extensions.Contains(Path.GetExtension(path))) continue;
                        string canonical;
                        try { canonical = Path.GetFullPath(path); } catch { canonical = path; }
                        Ps2Game game = new Ps2Game();
                        game.Path = canonical;
                        game.Title = CleanTitle(Path.GetFileNameWithoutExtension(path));
                        game.Serial = ExtractSerial(Path.GetFileName(path));
                        if (String.IsNullOrWhiteSpace(game.Serial)) game.Serial = ExtractSerialFromDisc(path);
                        game.CoverPath = FindCover(settings, dataRoot, game);
                        string key = !String.IsNullOrWhiteSpace(game.Serial) ? "serial:" + game.Serial : "path:" + canonical;
                        Ps2Game existing;
                        if (unique.TryGetValue(key, out existing))
                        {
                            if (String.IsNullOrWhiteSpace(existing.CoverPath) && !String.IsNullOrWhiteSpace(game.CoverPath)) existing.CoverPath = game.CoverPath;
                            continue;
                        }
                        unique[key] = game;
                    }
                    if (current.Depth >= 8) continue;
                    IEnumerable<string> directories;
                    try { directories = Directory.EnumerateDirectories(current.Path); }
                    catch { directories = Enumerable.Empty<string>(); }
                    foreach (string directory in directories)
                    {
                        try
                        {
                            FileAttributes attributes = File.GetAttributes(directory);
                            if ((attributes & FileAttributes.ReparsePoint) != 0) continue;
                            pending.Enqueue(new DirectoryDepth(directory, current.Depth + 1));
                        }
                        catch { }
                    }
                }
            }
            List<Ps2Game> result = unique.Values.OrderBy(delegate(Ps2Game game) { return game.Title; },
                StringComparer.CurrentCultureIgnoreCase).ToList();
            if (log != null) log("PCSX2 library scan found " + result.Count + " game(s) from " + roots.Count + " root(s).", "INFO");
            return result;
        }

        private static List<string> NormalizeRoots(IEnumerable<string> input)
        {
            List<string> result = new List<string>();
            foreach (string raw in input ?? Enumerable.Empty<string>())
            {
                if (String.IsNullOrWhiteSpace(raw)) continue;
                string full;
                try { full = Path.GetFullPath(raw).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar); }
                catch { continue; }
                if (!Directory.Exists(full)) continue;
                if (result.Any(delegate(string existing)
                {
                    return String.Equals(existing, full, StringComparison.OrdinalIgnoreCase) ||
                        full.StartsWith(existing + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase);
                })) continue;
                result.RemoveAll(delegate(string existing)
                {
                    return existing.StartsWith(full + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase);
                });
                result.Add(full);
            }
            return result;
        }

        private sealed class DirectoryDepth
        {
            internal readonly string Path;
            internal readonly int Depth;
            internal DirectoryDepth(string path, int depth) { Path = path; Depth = depth; }
        }

        private static string ExtractSerial(string value)
        {
            System.Text.RegularExpressions.Match match = SerialPattern.Match(value ?? String.Empty);
            if (!match.Success) return String.Empty;
            return match.Groups[1].Value.ToUpperInvariant() + "-" + match.Groups[2].Value + match.Groups[3].Value;
        }

        private static string CleanTitle(string value)
        {
            if (String.IsNullOrWhiteSpace(value)) return "PlayStation 2 Game";
            string title = System.Text.RegularExpressions.Regex.Replace(value, @"[\._]+", " ");
            title = System.Text.RegularExpressions.Regex.Replace(title, @"(?i)\b(SLUS|SCUS|SLES|SCES|SLPM|SLPS|SCPS|SCAJ|SCKA)[-_ ]?\d{3}[._-]?\d{2}\b", "");
            title = System.Text.RegularExpressions.Regex.Replace(title, @"\s+", " ").Trim(' ', '-', '_', '.');
            return String.IsNullOrWhiteSpace(title) ? value : title;
        }

        private static string ExtractSerialFromDisc(string path)
        {
            string extension = Path.GetExtension(path);
            if (!extension.Equals(".iso", StringComparison.OrdinalIgnoreCase) &&
                !extension.Equals(".bin", StringComparison.OrdinalIgnoreCase) &&
                !extension.Equals(".img", StringComparison.OrdinalIgnoreCase) &&
                !extension.Equals(".mdf", StringComparison.OrdinalIgnoreCase) &&
                !extension.Equals(".nrg", StringComparison.OrdinalIgnoreCase)) return String.Empty;
            try
            {
                const int maximum = 4 * 1024 * 1024;
                byte[] buffer = new byte[maximum];
                int read;
                using (FileStream stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))
                    read = stream.Read(buffer, 0, buffer.Length);
                if (read <= 0) return String.Empty;
                string header = Encoding.ASCII.GetString(buffer, 0, read);
                return ExtractSerial(header);
            }
            catch { return String.Empty; }
        }

        private static string FindCover(Ps2Settings settings, string dataRoot, Ps2Game game)
        {
            List<string> folders = BuildCoverFolders(settings, dataRoot);
            if (folders.Count == 0) return String.Empty;
            List<string> bases = new List<string>();
            if (!String.IsNullOrWhiteSpace(game.Serial))
            {
                string serial = game.Serial.ToUpperInvariant();
                bases.Add(serial);
                if (serial.Length >= 9)
                {
                    bases.Add(serial.Substring(0, 4) + "_" + serial.Substring(5, 3) + "." + serial.Substring(8, 2));
                    bases.Add(serial.Substring(0, 4) + "-" + serial.Substring(5, 3) + "." + serial.Substring(8, 2));
                    bases.Add(serial.Replace("-", String.Empty));
                }
            }
            bases.Add(Path.GetFileNameWithoutExtension(game.Path));
            bases.Add(game.Title);
            string[] extensions = new string[] { ".jpg", ".jpeg", ".png", ".bmp", ".webp" };
            foreach (string folder in folders)
            {
                foreach (string name in bases.Where(delegate(string item) { return !String.IsNullOrWhiteSpace(item); }).Distinct(StringComparer.OrdinalIgnoreCase))
                {
                    foreach (string extension in extensions)
                    {
                        string candidate = Path.Combine(folder, name + extension);
                        if (File.Exists(candidate)) return candidate;
                    }
                }
            }

            string serialKey = NormalizeCoverKey(game.Serial);
            string fileKey = NormalizeCoverKey(Path.GetFileNameWithoutExtension(game.Path));
            string titleKey = NormalizeCoverKey(game.Title);
            foreach (string folder in folders)
            {
                try
                {
                    foreach (string path in Directory.EnumerateFiles(folder).Take(12000))
                    {
                        string extension = Path.GetExtension(path);
                        if (!extensions.Contains(extension, StringComparer.OrdinalIgnoreCase)) continue;
                        string key = NormalizeCoverKey(Path.GetFileNameWithoutExtension(path));
                        if ((!String.IsNullOrWhiteSpace(serialKey) && key.IndexOf(serialKey, StringComparison.OrdinalIgnoreCase) >= 0) ||
                            (!String.IsNullOrWhiteSpace(fileKey) && String.Equals(key, fileKey, StringComparison.OrdinalIgnoreCase)) ||
                            (!String.IsNullOrWhiteSpace(titleKey) && String.Equals(key, titleKey, StringComparison.OrdinalIgnoreCase)))
                            return path;
                    }
                }
                catch { }
            }
            return String.Empty;
        }

        private static List<string> BuildCoverFolders(Ps2Settings settings, string dataRoot)
        {
            List<string> result = new List<string>();
            AddCoverFolder(result, dataRoot);
            if (settings != null)
            {
                AddCoverFolder(result, settings.pcsx2DataPath);
                if (!String.IsNullOrWhiteSpace(settings.pcsx2Path) && File.Exists(settings.pcsx2Path))
                    AddCoverFolder(result, Path.GetDirectoryName(settings.pcsx2Path));
                AddCoverFolder(result, settings.managedInstallFolder);
            }
            AddCoverFolder(result, Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments), "PCSX2"));
            AddCoverFolder(result, Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "PCSX2"));
            AddCoverFolder(result, Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "PCSX2"));
            return result;
        }

        private static void AddCoverFolder(List<string> target, string root)
        {
            if (String.IsNullOrWhiteSpace(root)) return;
            string folder;
            try
            {
                string full = Path.GetFullPath(root);
                folder = String.Equals(Path.GetFileName(full), "covers", StringComparison.OrdinalIgnoreCase)
                    ? full : Path.Combine(full, "covers");
            }
            catch { return; }
            if (!Directory.Exists(folder)) return;
            if (!target.Any(delegate(string existing) { return String.Equals(existing, folder, StringComparison.OrdinalIgnoreCase); }))
                target.Add(folder);
        }

        private static string NormalizeCoverKey(string value)
        {
            if (String.IsNullOrWhiteSpace(value)) return String.Empty;
            StringBuilder builder = new StringBuilder();
            foreach (char c in value)
                if (Char.IsLetterOrDigit(c)) builder.Append(Char.ToUpperInvariant(c));
            return builder.ToString();
        }
    }

    internal static class Pcsx2PathResolver
    {
        internal static string FindExecutable(string root)
        {
            if (String.IsNullOrWhiteSpace(root) || !Directory.Exists(root)) return String.Empty;
            try
            {
                string[] priorities = new string[] { "pcsx2-qt.exe", "pcsx2-qtx64-avx2.exe", "pcsx2-qtx64.exe", "pcsx2.exe" };
                foreach (string name in priorities)
                {
                    string direct = Path.Combine(root, name);
                    if (File.Exists(direct)) return direct;
                }
                return Directory.EnumerateFiles(root, "pcsx2*.exe", SearchOption.AllDirectories).FirstOrDefault() ?? String.Empty;
            }
            catch { return String.Empty; }
        }

        internal static string FindDataRoot(string executable, string configured)
        {
            List<string> candidates = new List<string>();
            if (!String.IsNullOrWhiteSpace(configured)) candidates.Add(configured);
            if (!String.IsNullOrWhiteSpace(executable) && File.Exists(executable))
            {
                string directory = Path.GetDirectoryName(executable);
                if (File.Exists(Path.Combine(directory, "portable.ini")) || Directory.Exists(Path.Combine(directory, "inis")))
                    candidates.Add(directory);
            }
            candidates.Add(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments), "PCSX2"));
            candidates.Add(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "PCSX2"));
            candidates.Add(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "PCSX2"));
            foreach (string candidate in candidates)
            {
                if (String.IsNullOrWhiteSpace(candidate) || !Directory.Exists(candidate)) continue;
                if (Directory.Exists(Path.Combine(candidate, "inis")) || Directory.Exists(Path.Combine(candidate, "memcards")) ||
                    Directory.Exists(Path.Combine(candidate, "bios")) || File.Exists(Path.Combine(candidate, "PCSX2.ini")))
                    return Path.GetFullPath(candidate);
            }
            if (!String.IsNullOrWhiteSpace(configured)) return configured;
            return candidates.FirstOrDefault() ?? String.Empty;
        }

        internal static string FindIniPath(string dataRoot)
        {
            string nested = Path.Combine(dataRoot ?? String.Empty, "inis", "PCSX2.ini");
            if (File.Exists(nested) || Directory.Exists(Path.GetDirectoryName(nested))) return nested;
            return Path.Combine(dataRoot ?? String.Empty, "PCSX2.ini");
        }
    }

    internal sealed class SimpleIniFile
    {
        private readonly string path;
        private readonly string backupRoot;
        internal SimpleIniFile(string path, string backupRoot) { this.path = path; this.backupRoot = backupRoot; }

        internal string Get(string section, string key, string fallback)
        {
            if (!File.Exists(path)) return fallback;
            string current = String.Empty;
            foreach (string raw in File.ReadAllLines(path))
            {
                string line = raw.Trim();
                if (line.StartsWith("[") && line.EndsWith("]")) current = line.Substring(1, line.Length - 2);
                else if (String.Equals(current, section, StringComparison.OrdinalIgnoreCase))
                {
                    int equals = line.IndexOf('=');
                    if (equals <= 0) continue;
                    if (String.Equals(line.Substring(0, equals).Trim(), key, StringComparison.OrdinalIgnoreCase))
                        return line.Substring(equals + 1).Trim();
                }
            }
            return fallback;
        }

        internal void Set(string section, string key, string value)
        {
            List<string> lines = File.Exists(path) ? File.ReadAllLines(path).ToList() : new List<string>();
            string current = String.Empty;
            int sectionStart = -1;
            int insertAt = lines.Count;
            bool updated = false;
            for (int index = 0; index < lines.Count; index++)
            {
                string line = lines[index].Trim();
                if (line.StartsWith("[") && line.EndsWith("]"))
                {
                    string next = line.Substring(1, line.Length - 2);
                    if (String.Equals(current, section, StringComparison.OrdinalIgnoreCase) && sectionStart >= 0 && insertAt == lines.Count)
                        insertAt = index;
                    current = next;
                    if (String.Equals(current, section, StringComparison.OrdinalIgnoreCase))
                    {
                        sectionStart = index;
                        insertAt = index + 1;
                    }
                }
                else if (String.Equals(current, section, StringComparison.OrdinalIgnoreCase))
                {
                    int equals = line.IndexOf('=');
                    if (equals > 0 && String.Equals(line.Substring(0, equals).Trim(), key, StringComparison.OrdinalIgnoreCase))
                    {
                        lines[index] = key + " = " + value;
                        updated = true;
                        break;
                    }
                    insertAt = index + 1;
                }
            }
            if (!updated)
            {
                if (sectionStart < 0)
                {
                    if (lines.Count > 0 && !String.IsNullOrWhiteSpace(lines[lines.Count - 1])) lines.Add(String.Empty);
                    lines.Add("[" + section + "]");
                    lines.Add(key + " = " + value);
                }
                else lines.Insert(Math.Max(sectionStart + 1, insertAt), key + " = " + value);
            }
            Directory.CreateDirectory(Path.GetDirectoryName(path));
            if (File.Exists(path))
            {
                Directory.CreateDirectory(backupRoot);
                string backup = Path.Combine(backupRoot, Path.GetFileName(path) + "-" + DateTime.Now.ToString("yyyyMMdd-HHmmss") + ".bak");
                File.Copy(path, backup, true);
            }
            string temp = path + ".huymaier.tmp";
            File.WriteAllLines(temp, lines.ToArray(), new UTF8Encoding(false));
            if (File.Exists(path)) File.Delete(path);
            File.Move(temp, path);
        }
    }

}
