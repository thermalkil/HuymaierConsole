from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[2]
native=ROOT/'Native'/'HuymaierConsole.NativeApp.cs'
text=native.read_text(encoding='utf-8-sig')

window_code=r'''
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
                UniformGrid grid = new UniformGrid { Columns = keyLayout[r].Length, Margin = new Thickness(0, 5, 0, 5) };
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
            if (!IsActive) return; NativeNavigationCommand command = NativeConsoleNavigation.Poll(); if (command == null || String.IsNullOrWhiteSpace(command.Command)) return; if (command.Command == "Up") Move(-1); else if (command.Command == "Down") Move(1); else if (command.Command == "Confirm") Confirm(); else if (command.Command == "Back") BackOneLayer(); else if (command.Command == "Secondary" && layer == 1 && selected < visibleSettings.Count) { string next; if (TryToggleValue(visibleSettings[selected].Value,out next)) ApplySetting(visibleSettings[selected],next); }
        }
        private void OnKeyDown(object sender, KeyEventArgs e)
        {
            if (e.Key == Key.Up) { Move(-1); e.Handled=true; } else if (e.Key == Key.Down) { Move(1); e.Handled=true; } else if (e.Key == Key.Enter) { Confirm(); e.Handled=true; } else if (e.Key == Key.Escape || e.Key == Key.Back) { BackOneLayer(); e.Handled=true; }
        }
    }
    // v0.26.4 COMPLETE_BACKEND_SETTINGS_WINDOW_END

'''
if 'COMPLETE_BACKEND_SETTINGS_WINDOW_BEGIN' not in text:
    anchor='    public static class Program\n'
    if text.count(anchor)!=1: raise SystemExit('Native backend settings window insertion anchor missing')
    text=text.replace(anchor,window_code+anchor,1)
native.write_text(text,encoding='utf-8-sig')

# PS1: add one functional settings action and a tiny delegate method. The
# surrounding PlayStation presentation remains byte-for-byte unchanged after
# stripping these explicitly marked regions.
ps1=ROOT/'Native'/'HuymaierConsole.Ps1.cs';p=ps1.read_text(encoding='utf-8-sig')
if 'PS1_FULL_BACKEND_SETTINGS_ACTION_BEGIN' not in p:
    anchor='            AddActionButton(panel, "Install / Update DuckStation", "Install the latest supported DuckStation release through Huymaier Console", delegate { InstallManagedDuckStation(); });\n'
    if p.count(anchor)!=1: raise SystemExit('PS1 DuckStation action anchor missing')
    inject=anchor+'            // v0.26.4 PS1_FULL_BACKEND_SETTINGS_ACTION_BEGIN\n            AddActionButton(panel, "Full DuckStation Settings", "Every setting discovered from the installed DuckStation configuration", OpenFullDuckStationSettings);\n            // v0.26.4 PS1_FULL_BACKEND_SETTINGS_ACTION_END\n'
    p=p.replace(anchor,inject,1)
if 'PS1_FULL_BACKEND_SETTINGS_METHOD_BEGIN' not in p:
    anchor='        private void InstallManagedDuckStation()\n'
    if p.count(anchor)!=1: raise SystemExit('PS1 full settings method insertion anchor missing')
    method='''        // v0.26.4 PS1_FULL_BACKEND_SETTINGS_METHOD_BEGIN\n        private void OpenFullDuckStationSettings()\n        {\n            NativeBackendSettingsWindow.Show(this, consoleRoot, "PS1", "PlayStation", "DuckStation", settingsPath);\n            NativeConsoleNavigation.Reset();\n            RenderSettings();\n        }\n        // v0.26.4 PS1_FULL_BACKEND_SETTINGS_METHOD_END\n\n'''
    p=p.replace(anchor,method+anchor,1)
ps1.write_text(p,encoding='utf-8-sig')

# PS2 BBN: one item plus one action case/method.
text=native.read_text(encoding='utf-8-sig')
if 'Full PCSX2 Settings' not in text:
    anchor='''            result.Add(new BbnItem("BIOS", GetBiosStatus(), "ChooseBios"));\n'''
    if text.count(anchor)!=1: raise SystemExit('PS2 settings item anchor missing')
    text=text.replace(anchor,'            result.Add(new BbnItem("Full PCSX2 Settings", "Every setting discovered from the installed PCSX2 configuration", "FullPcsx2Settings"));\n'+anchor,1)
if 'case "FullPcsx2Settings"' not in text:
    anchor='                case "ChoosePcsx2": ChoosePcsx2(); break;\n'
    if text.count(anchor)!=1: raise SystemExit('PS2 action case anchor missing')
    text=text.replace(anchor,anchor+'                case "FullPcsx2Settings": OpenFullPcsx2Settings(); break;\n',1)
if 'private void OpenFullPcsx2Settings()' not in text:
    anchor='        private void ChoosePcsx2()\n'
    if text.count(anchor)!=1: raise SystemExit('PS2 method anchor missing')
    method='''        private void OpenFullPcsx2Settings()\n        {\n            NativeBackendSettingsWindow.Show(this, consoleRoot, "PS2", "PlayStation 2", "PCSX2", settingsPath);\n            NativeConsoleNavigation.Reset();\n            RefreshSettingsChannel();\n        }\n\n'''
    text=text.replace(anchor,method+anchor,1)

# PS3 XMB: retain curated CPU/GPU/etc. settings and add an exhaustive raw view
# under Advanced/Troubleshooting for unknown/new RPCS3 options.
if 'All RPCS3 Settings' not in text:
    anchor='                    new XmbItem("Open RPCS3 Desktop UI", "Advanced troubleshooting only", "OpenRpcs3"),\n'
    if text.count(anchor)!=1: raise SystemExit('PS3 advanced settings anchor missing')
    text=text.replace(anchor,'                    new XmbItem("All RPCS3 Settings", "Every setting discovered from global and per-game RPCS3 configuration", "FullRpcs3Settings"),\n'+anchor,1)
if 'case "FullRpcs3Settings"' not in text:
    anchor='                case "OpenRpcs3": OpenRpcs3Ui(); break;\n'
    if text.count(anchor)!=1: raise SystemExit('PS3 action case anchor missing')
    text=text.replace(anchor,'                case "FullRpcs3Settings": OpenFullRpcs3Settings(); break;\n'+anchor,1)
if 'private void OpenFullRpcs3Settings()' not in text:
    # Place beside RPCS3 data-path action to keep integration localized.
    anchor='        private void ChooseRpcs3DataPath()\n'
    if text.count(anchor)!=1: raise SystemExit('PS3 method anchor missing')
    method='''        private void OpenFullRpcs3Settings()\n        {\n            NativeBackendSettingsWindow.Show(this, consoleRoot, "PS3", "PlayStation 3", "RPCS3", settingsPath);\n            NativeConsoleNavigation.Reset();\n            RefreshDynamicSubtitles();\n        }\n\n'''
    text=text.replace(anchor,method+anchor,1)
native.write_text(text,encoding='utf-8-sig')
print('materialized controller-native complete backend settings UI for PS1, PS2 and PS3')
