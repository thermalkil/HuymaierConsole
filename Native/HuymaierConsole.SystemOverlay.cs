using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using Forms = System.Windows.Forms;

namespace HuymaierConsole.NativeApp
{
    internal sealed class SystemWindowEntry
    {
        internal IntPtr Handle;
        internal string Title;
        internal string ProcessName;
    }

    internal static class SystemWindowCatalog
    {
        private delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
        private const int GWL_EXSTYLE = -20;
        private const long WS_EX_TOOLWINDOW = 0x00000080L;
        private const uint GW_OWNER = 4;
        private const int DWMWA_CLOAKED = 14;
        private const int SW_RESTORE = 9;
        private const uint WM_CLOSE = 0x0010;

        [DllImport("user32.dll")] private static extern bool EnumWindows(EnumWindowsProc callback, IntPtr lParam);
        [DllImport("user32.dll")] private static extern bool IsWindowVisible(IntPtr hWnd);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern int GetWindowTextLength(IntPtr hWnd);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int maxCount);
        [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
        [DllImport("user32.dll", EntryPoint = "GetWindowLongPtrW")] private static extern IntPtr GetWindowLongPtr64(IntPtr hWnd, int index);
        [DllImport("user32.dll", EntryPoint = "GetWindowLongW")] private static extern int GetWindowLong32(IntPtr hWnd, int index);
        [DllImport("user32.dll")] private static extern IntPtr GetWindow(IntPtr hWnd, uint command);
        [DllImport("user32.dll")] internal static extern IntPtr GetForegroundWindow();
        [DllImport("user32.dll")] internal static extern bool SetForegroundWindow(IntPtr hWnd);
        [DllImport("user32.dll")] internal static extern bool ShowWindow(IntPtr hWnd, int command);
        [DllImport("user32.dll")] internal static extern bool PostMessage(IntPtr hWnd, uint message, IntPtr wParam, IntPtr lParam);
        [DllImport("dwmapi.dll")] private static extern int DwmGetWindowAttribute(IntPtr hWnd, int attribute, out int value, int size);

        private static long GetExStyle(IntPtr hWnd)
        {
            if (IntPtr.Size == 8) return GetWindowLongPtr64(hWnd, GWL_EXSTYLE).ToInt64();
            return (long)GetWindowLong32(hWnd, GWL_EXSTYLE);
        }

        private static bool IsCloaked(IntPtr hWnd)
        {
            try
            {
                int value;
                if (DwmGetWindowAttribute(hWnd, DWMWA_CLOAKED, out value, sizeof(int)) == 0)
                    return value != 0;
            }
            catch { }
            return false;
        }

        internal static List<SystemWindowEntry> GetTaskWindows(IntPtr overlayHandle)
        {
            List<SystemWindowEntry> result = new List<SystemWindowEntry>();
            int selfPid = Process.GetCurrentProcess().Id;
            HashSet<IntPtr> seen = new HashSet<IntPtr>();
            EnumWindows(delegate(IntPtr hWnd, IntPtr state)
            {
                try
                {
                    if (hWnd == IntPtr.Zero || hWnd == overlayHandle || !IsWindowVisible(hWnd) || seen.Contains(hWnd))
                        return true;
                    if ((GetExStyle(hWnd) & WS_EX_TOOLWINDOW) != 0) return true;
                    if (GetWindow(hWnd, GW_OWNER) != IntPtr.Zero) return true;
                    if (IsCloaked(hWnd)) return true;
                    int length = GetWindowTextLength(hWnd);
                    if (length <= 0 || length > 8192) return true;
                    StringBuilder titleBuffer = new StringBuilder(length + 1);
                    GetWindowText(hWnd, titleBuffer, titleBuffer.Capacity);
                    string title = titleBuffer.ToString().Trim();
                    if (String.IsNullOrWhiteSpace(title)) return true;
                    uint pid;
                    GetWindowThreadProcessId(hWnd, out pid);
                    if (pid == 0 || pid == (uint)selfPid) return true;
                    string processName = String.Empty;
                    try { processName = Process.GetProcessById((int)pid).ProcessName; } catch { }
                    result.Add(new SystemWindowEntry { Handle = hWnd, Title = title, ProcessName = processName });
                    seen.Add(hWnd);
                }
                catch { }
                return true;
            }, IntPtr.Zero);
            return result;
        }

        internal static void Activate(IntPtr hWnd)
        {
            if (hWnd == IntPtr.Zero) return;
            try { ShowWindow(hWnd, SW_RESTORE); } catch { }
            try { SetForegroundWindow(hWnd); } catch { }
        }

        internal static void Close(IntPtr hWnd)
        {
            if (hWnd == IntPtr.Zero) return;
            try { PostMessage(hWnd, WM_CLOSE, IntPtr.Zero, IntPtr.Zero); } catch { }
        }
    }

    public static class HuymaierGameBarHost
    {
        private static Window consoleWindow;
        private static HuymaierGameBarWindow gameBar;
        public static bool IsVisible { get { return gameBar != null && gameBar.IsVisible; } }
        public static void Initialize(Window mainConsoleWindow) { consoleWindow = mainConsoleWindow; }
        public static void Show() { if (consoleWindow == null) return; if (gameBar == null) gameBar = new HuymaierGameBarWindow(consoleWindow); gameBar.ShowForForegroundWindow(); }
        public static void Hide() { if (gameBar != null) gameBar.HideBar(); }
        public static void Toggle() { if (IsVisible) Hide(); else Show(); }
        public static void ProcessCommand(string command) { if (gameBar == null || !gameBar.IsVisible || String.IsNullOrWhiteSpace(command)) return; gameBar.ProcessControllerCommand(command); }
    }

    internal sealed class HuymaierGameBarWindow : Window
    {
        private readonly Window consoleWindow;
        private readonly Grid root;
        private readonly TextBlock contextText;
        private readonly TextBlock pageText;
        private readonly StackPanel itemPanel;
        private readonly TextBlock footerText;
        private readonly List<Border> itemCards;
        private readonly List<SystemWindowEntry> taskWindows;
        private IntPtr targetWindow;
        private int page;
        private int selected;

        internal HuymaierGameBarWindow(Window mainConsoleWindow)
        {
            consoleWindow = mainConsoleWindow;
            itemCards = new List<Border>();
            taskWindows = new List<SystemWindowEntry>();
            WindowStyle = WindowStyle.None;
            ResizeMode = ResizeMode.NoResize;
            ShowInTaskbar = false;
            Topmost = true;
            AllowsTransparency = true;
            Background = Brushes.Transparent;
            Foreground = Brushes.White;
            FontFamily = new FontFamily("Segoe UI");
            WindowStartupLocation = WindowStartupLocation.Manual;

            root = new Grid();
            root.Background = new SolidColorBrush(Color.FromArgb(190, 0, 0, 0));
            Border card = new Border();
            card.Width = 1120;
            card.MaxHeight = 720;
            card.HorizontalAlignment = HorizontalAlignment.Center;
            card.VerticalAlignment = VerticalAlignment.Center;
            card.Background = new SolidColorBrush(Color.FromArgb(248, 8, 12, 18));
            card.BorderBrush = new SolidColorBrush(Color.FromRgb(69, 81, 99));
            card.BorderThickness = new Thickness(1.5);
            card.CornerRadius = new CornerRadius(22);
            card.Padding = new Thickness(32, 26, 32, 24);

            Grid layout = new Grid();
            layout.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            layout.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            layout.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
            layout.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            StackPanel header = new StackPanel(); header.Orientation = Orientation.Horizontal;
            TextBlock brand = new TextBlock(); brand.Text = "HUYMAIER GAME BAR"; brand.FontSize = 24; brand.FontWeight = FontWeights.Bold; brand.Foreground = new SolidColorBrush(Color.FromRgb(231, 196, 94)); header.Children.Add(brand);
            contextText = new TextBlock(); contextText.Margin = new Thickness(18, 7, 0, 0); contextText.FontSize = 13; contextText.Foreground = new SolidColorBrush(Color.FromRgb(164, 177, 196)); header.Children.Add(contextText);
            Grid.SetRow(header, 0); layout.Children.Add(header);
            pageText = new TextBlock(); pageText.Margin = new Thickness(0, 18, 0, 16); pageText.FontSize = 31; pageText.FontWeight = FontWeights.SemiBold; Grid.SetRow(pageText, 1); layout.Children.Add(pageText);
            ScrollViewer scroller = new ScrollViewer(); scroller.VerticalScrollBarVisibility = ScrollBarVisibility.Hidden; scroller.HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled; itemPanel = new StackPanel(); scroller.Content = itemPanel; Grid.SetRow(scroller, 2); layout.Children.Add(scroller);
            footerText = new TextBlock(); footerText.Margin = new Thickness(0, 18, 0, 0); footerText.FontSize = 13; footerText.Foreground = new SolidColorBrush(Color.FromRgb(155, 168, 188)); Grid.SetRow(footerText, 3); layout.Children.Add(footerText);
            card.Child = layout; root.Children.Add(card); Content = root;
            PreviewKeyDown += delegate(object sender, System.Windows.Input.KeyEventArgs e) { if (e.Key == System.Windows.Input.Key.Escape) { HideBar(); e.Handled = true; } };
            Deactivated += delegate { Topmost = true; };
        }

        internal void ShowForForegroundWindow()
        {
            targetWindow = SystemWindowCatalog.GetForegroundWindow();
            PositionOnTargetMonitor(targetWindow);
            page = 0; selected = 0; Refresh();
            if (!IsVisible) Show();
            WindowState = WindowState.Normal; Activate(); Focus();
        }

        private void PositionOnTargetMonitor(IntPtr target)
        {
            try { Forms.Screen screen = target != IntPtr.Zero ? Forms.Screen.FromHandle(target) : Forms.Screen.PrimaryScreen; System.Drawing.Rectangle bounds = screen.Bounds; Left = bounds.Left; Top = bounds.Top; Width = bounds.Width; Height = bounds.Height; }
            catch { Left = SystemParameters.VirtualScreenLeft; Top = SystemParameters.VirtualScreenTop; Width = SystemParameters.PrimaryScreenWidth; Height = SystemParameters.PrimaryScreenHeight; }
        }

        internal void HideBar() { try { Hide(); } catch { } if (targetWindow != IntPtr.Zero) SystemWindowCatalog.Activate(targetWindow); }
        private void Refresh() { itemPanel.Children.Clear(); itemCards.Clear(); contextText.Text = GetTargetTitle(); if (page == 0) BuildHome(); else BuildSwitcher(); UpdateSelection(); }
        private string GetTargetTitle() { if (targetWindow == IntPtr.Zero) return "External app"; List<SystemWindowEntry> windows = SystemWindowCatalog.GetTaskWindows(IntPtr.Zero); for (int i = 0; i < windows.Count; i++) if (windows[i].Handle == targetWindow) return windows[i].Title; return "External app"; }

        private void BuildHome()
        {
            pageText.Text = "Game Bar";
            AddItem("Resume", "Return to the current game or app.");
            AddItem("Switch Apps", "Open the Huymaier native task switcher.");
            AddItem("Return to Huymaier Console", "Bring the full-screen Console back to the foreground.");
            AddItem("Close Current App", "Request a normal close of the current game or app.");
            footerText.Text = "A  Select     B / GUIDE  Return     RB  Switch Apps";
        }

        private void BuildSwitcher()
        {
            pageText.Text = "Switch Apps";
            taskWindows.Clear();
            IntPtr overlayHandle = IntPtr.Zero; try { overlayHandle = new System.Windows.Interop.WindowInteropHelper(this).Handle; } catch { }
            taskWindows.AddRange(SystemWindowCatalog.GetTaskWindows(overlayHandle));
            if (taskWindows.Count == 0) { AddItem("No other apps", "No switchable desktop windows are currently available."); selected = 0; }
            else { if (selected >= taskWindows.Count) selected = taskWindows.Count - 1; for (int i = 0; i < taskWindows.Count; i++) { SystemWindowEntry entry = taskWindows[i]; AddItem(entry.Title, String.IsNullOrWhiteSpace(entry.ProcessName) ? "Desktop app" : entry.ProcessName); } }
            footerText.Text = "A  Switch     B  Game Bar     GUIDE  Return to game     LB  Game Bar";
        }

        private void AddItem(string title, string detail)
        {
            Border border = new Border(); border.Height = 78; border.Margin = new Thickness(0, 0, 0, 9); border.Padding = new Thickness(18, 10, 18, 10); border.CornerRadius = new CornerRadius(13); border.BorderThickness = new Thickness(1);
            StackPanel stack = new StackPanel();
            TextBlock titleText = new TextBlock(); titleText.Text = title; titleText.FontSize = 19; titleText.FontWeight = FontWeights.SemiBold;
            TextBlock detailText = new TextBlock(); detailText.Text = detail; detailText.FontSize = 12; detailText.Foreground = new SolidColorBrush(Color.FromRgb(153, 168, 190)); detailText.Margin = new Thickness(0, 5, 0, 0);
            stack.Children.Add(titleText); stack.Children.Add(detailText); border.Child = stack; itemPanel.Children.Add(border); itemCards.Add(border);
        }

        private void UpdateSelection()
        {
            if (itemCards.Count == 0) return;
            if (selected < 0) selected = 0; if (selected >= itemCards.Count) selected = itemCards.Count - 1;
            for (int i = 0; i < itemCards.Count; i++) { Border card = itemCards[i]; bool active = i == selected; card.Background = new SolidColorBrush(active ? Color.FromRgb(229, 199, 104) : Color.FromArgb(230, 17, 25, 38)); card.BorderBrush = new SolidColorBrush(active ? Color.FromRgb(255, 240, 160) : Color.FromRgb(57, 71, 91)); StackPanel stack = card.Child as StackPanel; TextBlock title = stack != null && stack.Children.Count > 0 ? stack.Children[0] as TextBlock : null; if (title != null) title.Foreground = new SolidColorBrush(active ? Color.FromRgb(15, 20, 28) : Colors.White); }
            try { itemCards[selected].BringIntoView(); } catch { }
        }

        internal void ProcessControllerCommand(string command)
        {
            if (String.IsNullOrWhiteSpace(command)) return;
            if (command == "Guide") { HideBar(); return; }
            if (command == "Back") { if (page == 1) { page = 0; selected = 0; Refresh(); } else HideBar(); return; }
            if (command == "LeftShoulder") { if (page != 0) { page = 0; selected = 0; Refresh(); } return; }
            if (command == "RightShoulder") { if (page != 1) { page = 1; selected = 0; Refresh(); } return; }
            if (command == "Up") { Move(-1); return; }
            if (command == "Down") { Move(1); return; }
            if (command == "Confirm") { InvokeSelected(); return; }
        }

        private void Move(int delta) { int count = itemCards.Count; if (count <= 0) return; selected = (selected + delta + count) % count; UpdateSelection(); }
        private void InvokeSelected()
        {
            if (page == 1) { if (taskWindows.Count == 0 || selected < 0 || selected >= taskWindows.Count) return; IntPtr hWnd = taskWindows[selected].Handle; try { Hide(); } catch { } SystemWindowCatalog.Activate(hWnd); targetWindow = hWnd; return; }
            switch (selected)
            {
                case 0: HideBar(); break;
                case 1: page = 1; selected = 0; Refresh(); break;
                case 2:
                    try { Hide(); } catch { }
                    if (consoleWindow != null) consoleWindow.Dispatcher.BeginInvoke(new Action(delegate { try { if (consoleWindow.WindowState == WindowState.Minimized) consoleWindow.WindowState = WindowState.Maximized; consoleWindow.Show(); consoleWindow.Activate(); consoleWindow.Topmost = true; consoleWindow.Topmost = false; consoleWindow.Focus(); } catch { } }));
                    break;
                case 3: if (targetWindow != IntPtr.Zero) SystemWindowCatalog.Close(targetWindow); Hide(); break;
            }
        }
    }
}
