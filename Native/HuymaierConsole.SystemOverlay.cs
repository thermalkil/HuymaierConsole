using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Threading;
using Drawing = System.Drawing;
using Forms = System.Windows.Forms;
using HuymaierConsole.Native;

namespace HuymaierConsole.NativeApp
{
    internal sealed class SystemWindowEntry
    {
        internal IntPtr Handle;
        internal string Title;
        internal string ProcessName;
        internal int ProcessId;
    }

    public static class HuymaierForegroundOwnership
    {
        [DllImport("user32.dll")] private static extern IntPtr GetForegroundWindow();
        [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);

        public static int ForegroundProcessId
        {
            get
            {
                try
                {
                    IntPtr foreground = GetForegroundWindow();
                    if (foreground == IntPtr.Zero) return 0;
                    uint processId;
                    GetWindowThreadProcessId(foreground, out processId);
                    return (int)processId;
                }
                catch { return 0; }
            }
        }

        public static bool IsCurrentProcessForeground()
        {
            int foregroundPid = ForegroundProcessId;
            return foregroundPid > 0 && foregroundPid == Process.GetCurrentProcess().Id;
        }
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
        [DllImport("user32.dll")] internal static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
        [DllImport("user32.dll", EntryPoint = "GetWindowLongPtrW")] private static extern IntPtr GetWindowLongPtr64(IntPtr hWnd, int index);
        [DllImport("user32.dll", EntryPoint = "GetWindowLongW")] private static extern int GetWindowLong32(IntPtr hWnd, int index);
        [DllImport("user32.dll")] private static extern IntPtr GetWindow(IntPtr hWnd, uint command);
        [DllImport("user32.dll")] internal static extern IntPtr GetForegroundWindow();
        [DllImport("user32.dll")] internal static extern bool SetForegroundWindow(IntPtr hWnd);
        [DllImport("user32.dll")] internal static extern bool ShowWindow(IntPtr hWnd, int command);
        [DllImport("user32.dll")] private static extern bool IsIconic(IntPtr hWnd);
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

        internal static string GetTitle(IntPtr hWnd)
        {
            try
            {
                int length = GetWindowTextLength(hWnd);
                if (length <= 0 || length > 8192) return String.Empty;
                StringBuilder buffer = new StringBuilder(length + 1);
                GetWindowText(hWnd, buffer, buffer.Capacity);
                return buffer.ToString().Trim();
            }
            catch { return String.Empty; }
        }

        internal static int GetProcessId(IntPtr hWnd)
        {
            try { uint pid; GetWindowThreadProcessId(hWnd, out pid); return (int)pid; }
            catch { return 0; }
        }

        internal static List<SystemWindowEntry> GetTaskWindows(IntPtr overlayHandle, IntPtr preferredWindow)
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
                    string title = GetTitle(hWnd);
                    if (String.IsNullOrWhiteSpace(title)) return true;
                    int pid = GetProcessId(hWnd);
                    if (pid <= 0 || pid == selfPid) return true;
                    string processName = String.Empty;
                    try { processName = Process.GetProcessById(pid).ProcessName; } catch { }
                    result.Add(new SystemWindowEntry { Handle = hWnd, Title = title, ProcessName = processName, ProcessId = pid });
                    seen.Add(hWnd);
                }
                catch { }
                return true;
            }, IntPtr.Zero);

            result.Sort(delegate(SystemWindowEntry a, SystemWindowEntry b)
            {
                if (a.Handle == preferredWindow && b.Handle != preferredWindow) return -1;
                if (b.Handle == preferredWindow && a.Handle != preferredWindow) return 1;
                return String.Compare(a.Title, b.Title, StringComparison.CurrentCultureIgnoreCase);
            });
            return result;
        }

        internal static void Activate(IntPtr hWnd)
        {
            if (hWnd == IntPtr.Zero) return;
            // Never restore a maximized/fullscreen game to its normal windowed size.
            // SW_RESTORE is needed only for an actually minimized task.
            try { if (IsIconic(hWnd)) ShowWindow(hWnd, SW_RESTORE); } catch { }
            try { SetForegroundWindow(hWnd); } catch { }
        }

        internal static void Close(IntPtr hWnd)
        {
            if (hWnd == IntPtr.Zero) return;
            try { PostMessage(hWnd, WM_CLOSE, IntPtr.Zero, IntPtr.Zero); } catch { }
        }
    }

    internal static class DwmTaskPreviewHost
    {
        private const uint DWM_TNP_RECTDESTINATION = 0x00000001;
        private const uint DWM_TNP_OPACITY = 0x00000004;
        private const uint DWM_TNP_VISIBLE = 0x00000008;
        private const uint DWM_TNP_SOURCECLIENTAREAONLY = 0x00000010;

        [StructLayout(LayoutKind.Sequential)]
        private struct RECT { public int left, top, right, bottom; }

        [StructLayout(LayoutKind.Sequential)]
        private struct POINT { public int x, y; }

        [StructLayout(LayoutKind.Sequential)]
        private struct DWM_THUMBNAIL_PROPERTIES
        {
            public uint dwFlags;
            public RECT rcDestination;
            public RECT rcSource;
            public byte opacity;
            [MarshalAs(UnmanagedType.Bool)] public bool fVisible;
            [MarshalAs(UnmanagedType.Bool)] public bool fSourceClientAreaOnly;
        }

        [DllImport("dwmapi.dll")] private static extern int DwmRegisterThumbnail(IntPtr destination, IntPtr source, out IntPtr thumbnail);
        [DllImport("dwmapi.dll")] private static extern int DwmUnregisterThumbnail(IntPtr thumbnail);
        [DllImport("dwmapi.dll")] private static extern int DwmUpdateThumbnailProperties(IntPtr thumbnail, ref DWM_THUMBNAIL_PROPERTIES properties);
        [DllImport("user32.dll")] private static extern bool ClientToScreen(IntPtr hWnd, ref POINT point);

        internal sealed class Preview : IDisposable
        {
            private IntPtr thumbnail;
            internal Preview(IntPtr handle) { thumbnail = handle; }
            public void Dispose() { if (thumbnail != IntPtr.Zero) { try { DwmUnregisterThumbnail(thumbnail); } catch { } thumbnail = IntPtr.Zero; } }
        }

        internal static Preview Attach(Window destinationWindow, IntPtr sourceWindow, FrameworkElement destinationElement)
        {
            if (destinationWindow == null || sourceWindow == IntPtr.Zero || destinationElement == null || !destinationElement.IsVisible)
                return null;
            try
            {
                IntPtr destination = new WindowInteropHelper(destinationWindow).Handle;
                if (destination == IntPtr.Zero) return null;
                IntPtr thumbnail;
                if (DwmRegisterThumbnail(destination, sourceWindow, out thumbnail) != 0 || thumbnail == IntPtr.Zero) return null;

                System.Windows.Point screenPoint = destinationElement.PointToScreen(new System.Windows.Point(0, 0));
                POINT clientOrigin = new POINT();
                if (!ClientToScreen(destination, ref clientOrigin)) { DwmUnregisterThumbnail(thumbnail); return null; }
                int left = (int)Math.Round(screenPoint.X) - clientOrigin.x;
                int top = (int)Math.Round(screenPoint.Y) - clientOrigin.y;
                int width = Math.Max(1, (int)Math.Round(destinationElement.ActualWidth));
                int height = Math.Max(1, (int)Math.Round(destinationElement.ActualHeight));

                DWM_THUMBNAIL_PROPERTIES properties = new DWM_THUMBNAIL_PROPERTIES();
                properties.dwFlags = DWM_TNP_RECTDESTINATION | DWM_TNP_OPACITY | DWM_TNP_VISIBLE | DWM_TNP_SOURCECLIENTAREAONLY;
                properties.rcDestination = new RECT { left = left, top = top, right = left + width, bottom = top + height };
                properties.opacity = 255;
                properties.fVisible = true;
                properties.fSourceClientAreaOnly = false;
                if (DwmUpdateThumbnailProperties(thumbnail, ref properties) != 0) { DwmUnregisterThumbnail(thumbnail); return null; }
                return new Preview(thumbnail);
            }
            catch { return null; }
        }
    }

    internal sealed class GameBarPerformanceSnapshot
    {
        internal double CpuPercent;
        internal double GpuPercent;
        internal bool HasGpu;
        internal double MemoryPercent;
        internal long UsedMemoryMb;
        internal long TotalMemoryMb;
        internal string ProcessName;
        internal long ProcessWorkingSetMb;
    }

    internal static class GameBarPerformanceMonitor
    {
        [StructLayout(LayoutKind.Sequential)]
        private struct FILETIME { public uint LowDateTime; public uint HighDateTime; }
        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
        private class MEMORYSTATUSEX
        {
            public uint dwLength = (uint)Marshal.SizeOf(typeof(MEMORYSTATUSEX));
            public uint dwMemoryLoad;
            public ulong ullTotalPhys;
            public ulong ullAvailPhys;
            public ulong ullTotalPageFile;
            public ulong ullAvailPageFile;
            public ulong ullTotalVirtual;
            public ulong ullAvailVirtual;
            public ulong ullAvailExtendedVirtual;
        }

        [DllImport("kernel32.dll")] private static extern bool GetSystemTimes(out FILETIME idle, out FILETIME kernel, out FILETIME user);
        [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)] private static extern bool GlobalMemoryStatusEx([In, Out] MEMORYSTATUSEX buffer);
        private static ulong lastIdle, lastKernel, lastUser;
        private static readonly object Sync = new object();
        private static readonly List<PerformanceCounter> gpuCounters = new List<PerformanceCounter>();
        private static bool gpuInitialized;

        private static ulong ToUInt64(FILETIME value) { return ((ulong)value.HighDateTime << 32) | value.LowDateTime; }

        private static double GetCpuPercent()
        {
            lock (Sync)
            {
                FILETIME idleFt, kernelFt, userFt;
                if (!GetSystemTimes(out idleFt, out kernelFt, out userFt)) return 0;
                ulong idle = ToUInt64(idleFt), kernel = ToUInt64(kernelFt), user = ToUInt64(userFt);
                if (lastKernel == 0 && lastUser == 0) { lastIdle = idle; lastKernel = kernel; lastUser = user; return 0; }
                ulong idleDelta = idle - lastIdle;
                ulong kernelDelta = kernel - lastKernel;
                ulong userDelta = user - lastUser;
                ulong total = kernelDelta + userDelta;
                lastIdle = idle; lastKernel = kernel; lastUser = user;
                if (total == 0) return 0;
                return Math.Max(0, Math.Min(100, (1.0 - ((double)idleDelta / total)) * 100.0));
            }
        }

        private static double GetGpuPercent(out bool available)
        {
            available = false;
            try
            {
                lock (Sync)
                {
                    if (!gpuInitialized)
                    {
                        gpuInitialized = true;
                        PerformanceCounterCategory category = new PerformanceCounterCategory("GPU Engine");
                        foreach (string instance in category.GetInstanceNames())
                        {
                            if (instance.IndexOf("engtype_3D", StringComparison.OrdinalIgnoreCase) < 0) continue;
                            try { gpuCounters.Add(new PerformanceCounter("GPU Engine", "Utilization Percentage", instance, true)); } catch { }
                        }
                        foreach (PerformanceCounter counter in gpuCounters) { try { counter.NextValue(); } catch { } }
                    }
                    if (gpuCounters.Count == 0) return 0;
                    double total = 0;
                    int good = 0;
                    foreach (PerformanceCounter counter in gpuCounters)
                    {
                        try { total += Math.Max(0, counter.NextValue()); good++; } catch { }
                    }
                    available = good > 0;
                    return Math.Max(0, Math.Min(100, total));
                }
            }
            catch { available = false; return 0; }
        }

        internal static GameBarPerformanceSnapshot Read(IntPtr targetWindow)
        {
            GameBarPerformanceSnapshot result = new GameBarPerformanceSnapshot();
            result.CpuPercent = GetCpuPercent();
            MEMORYSTATUSEX memory = new MEMORYSTATUSEX();
            if (GlobalMemoryStatusEx(memory))
            {
                result.TotalMemoryMb = (long)(memory.ullTotalPhys / (1024UL * 1024UL));
                result.UsedMemoryMb = (long)((memory.ullTotalPhys - memory.ullAvailPhys) / (1024UL * 1024UL));
                result.MemoryPercent = memory.dwMemoryLoad;
            }
            result.GpuPercent = GetGpuPercent(out result.HasGpu);
            int pid = SystemWindowCatalog.GetProcessId(targetWindow);
            if (pid > 0)
            {
                try
                {
                    Process process = Process.GetProcessById(pid);
                    result.ProcessName = process.ProcessName;
                    result.ProcessWorkingSetMb = process.WorkingSet64 / (1024L * 1024L);
                }
                catch { }
            }
            if (String.IsNullOrWhiteSpace(result.ProcessName)) result.ProcessName = "Current app";
            return result;
        }
    }

    internal sealed class ControllerStatusEntry
    {
        internal string Name;
        internal string Detail;
    }

    internal static class GameBarControllerCatalog
    {
        [StructLayout(LayoutKind.Sequential)]
        private struct XINPUT_GAMEPAD { public ushort wButtons; public byte bLeftTrigger; public byte bRightTrigger; public short sThumbLX; public short sThumbLY; public short sThumbRX; public short sThumbRY; }
        [StructLayout(LayoutKind.Sequential)]
        private struct XINPUT_STATE { public uint dwPacketNumber; public XINPUT_GAMEPAD Gamepad; }
        [StructLayout(LayoutKind.Sequential)]
        private struct XINPUT_BATTERY_INFORMATION { public byte BatteryType; public byte BatteryLevel; }
        [DllImport("xinput1_4.dll", EntryPoint = "XInputGetState")] private static extern uint XInputGetState14(uint index, out XINPUT_STATE state);
        [DllImport("xinput9_1_0.dll", EntryPoint = "XInputGetState")] private static extern uint XInputGetState910(uint index, out XINPUT_STATE state);
        [DllImport("xinput1_4.dll", EntryPoint = "XInputGetBatteryInformation")] private static extern uint XInputGetBatteryInformation14(uint index, byte deviceType, out XINPUT_BATTERY_INFORMATION battery);

        private static bool TryGetState(uint index, out XINPUT_STATE state)
        {
            try { return XInputGetState14(index, out state) == 0; }
            catch { try { return XInputGetState910(index, out state) == 0; } catch { state = new XINPUT_STATE(); return false; } }
        }

        private static string GetBattery(uint index)
        {
            try
            {
                XINPUT_BATTERY_INFORMATION battery;
                if (XInputGetBatteryInformation14(index, 0, out battery) != 0) return "Battery unavailable";
                if (battery.BatteryType == 0x01) return "Wired";
                string level = battery.BatteryLevel == 0 ? "Empty" : battery.BatteryLevel == 1 ? "Low" : battery.BatteryLevel == 2 ? "Medium" : "Full";
                return level + " battery";
            }
            catch { return "Battery unavailable"; }
        }

        internal static List<ControllerStatusEntry> GetEntries()
        {
            List<ControllerStatusEntry> result = new List<ControllerStatusEntry>();
            for (uint i = 0; i < 4; i++)
            {
                XINPUT_STATE state;
                if (!TryGetState(i, out state)) continue;
                result.Add(new ControllerStatusEntry { Name = "Xbox / XInput Controller " + (i + 1).ToString(), Detail = GetBattery(i) });
            }

            try
            {
                Type rawType = Type.GetType("HuymaierConsole.Native.RawHidController");
                if (rawType != null)
                {
                    MethodInfo method = rawType.GetMethod("GetSnapshots", BindingFlags.Public | BindingFlags.Static);
                    Array snapshots = method == null ? null : method.Invoke(null, null) as Array;
                    if (snapshots != null)
                    {
                        foreach (object snapshot in snapshots)
                        {
                            if (snapshot == null) continue;
                            Type t = snapshot.GetType();
                            string name = Convert.ToString(t.GetProperty("Name").GetValue(snapshot, null));
                            string connection = Convert.ToString(t.GetProperty("Connection").GetValue(snapshot, null));
                            if (String.IsNullOrWhiteSpace(name)) name = "PlayStation Controller";
                            result.Add(new ControllerStatusEntry { Name = name, Detail = String.IsNullOrWhiteSpace(connection) ? "Sony HID" : connection });
                        }
                    }
                }
            }
            catch { }

            if (result.Count == 0)
                result.Add(new ControllerStatusEntry { Name = "No controller detected", Detail = "Press a button or reconnect a controller." });
            return result;
        }
    }

    internal static class GameBarCaptureService
    {
        internal static string CaptureDirectory
        {
            get
            {
                string root = Environment.GetFolderPath(Environment.SpecialFolder.MyPictures);
                if (String.IsNullOrWhiteSpace(root)) root = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
                return Path.Combine(root, "Huymaier Console", "Captures");
            }
        }

        internal static string CaptureMonitor(IntPtr targetWindow)
        {
            Forms.Screen screen = targetWindow != IntPtr.Zero ? Forms.Screen.FromHandle(targetWindow) : Forms.Screen.PrimaryScreen;
            Drawing.Rectangle bounds = screen.Bounds;
            Directory.CreateDirectory(CaptureDirectory);
            string path = Path.Combine(CaptureDirectory, "HuymaierCapture-" + DateTime.Now.ToString("yyyyMMdd-HHmmss-fff") + ".png");
            using (Drawing.Bitmap bitmap = new Drawing.Bitmap(bounds.Width, bounds.Height, Drawing.Imaging.PixelFormat.Format32bppArgb))
            using (Drawing.Graphics graphics = Drawing.Graphics.FromImage(bitmap))
            {
                graphics.CopyFromScreen(bounds.Left, bounds.Top, 0, 0, bounds.Size, Drawing.CopyPixelOperation.SourceCopy);
                bitmap.Save(path, Drawing.Imaging.ImageFormat.Png);
            }
            return path;
        }

        internal static void OpenCaptureDirectory()
        {
            Directory.CreateDirectory(CaptureDirectory);
            Process.Start(new ProcessStartInfo("explorer.exe", "\"" + CaptureDirectory + "\"") { UseShellExecute = true });
        }
    }

    public static class HuymaierGameBarHost
    {
        private static Window consoleWindow;
        private static HuymaierGameBarWindow gameBar;
        private static int scalePercent = 100;
        public static bool IsVisible { get { return gameBar != null && gameBar.IsVisible; } }
        public static void Initialize(Window mainConsoleWindow) { consoleWindow = mainConsoleWindow; }
        public static void SetScalePercent(int value) { scalePercent = Math.Max(70, Math.Min(140, value)); if (gameBar != null) gameBar.SetScalePercent(scalePercent); }
        public static void Show() { if (consoleWindow == null) return; if (gameBar == null) gameBar = new HuymaierGameBarWindow(consoleWindow); gameBar.SetScalePercent(scalePercent); gameBar.ShowForForegroundWindow(); }
        public static void Hide() { if (gameBar != null) gameBar.HideBar(); }
        public static void Toggle() { if (IsVisible) Hide(); else Show(); }
        public static void ProcessCommand(string command) { if (gameBar == null || !gameBar.IsVisible || String.IsNullOrWhiteSpace(command)) return; gameBar.ProcessControllerCommand(command); }
    }

    internal sealed class HuymaierGameBarWindow : Window
    {
        private const int PageHome = 0;
        private const int PageSwitcher = 1;
        private const int PageAudio = 2;
        private const int PageCapture = 3;
        private const int PagePerformance = 4;
        private const int PageControllers = 5;
        private const int PageCount = 6;

        private readonly Window consoleWindow;
        private readonly Grid root;
        private readonly TextBlock contextText;
        private readonly TextBlock tabsText;
        private readonly TextBlock pageText;
        private readonly ScrollViewer scroller;
        private readonly StackPanel itemPanel;
        private readonly TextBlock footerText;
        private readonly TextBlock statusText;
        private readonly List<Border> itemCards;
        private readonly List<SystemWindowEntry> taskWindows;
        private readonly List<FrameworkElement> taskPreviewTargets;
        private readonly List<DwmTaskPreviewHost.Preview> taskPreviews;
        private readonly DispatcherTimer telemetryTimer;
        private AudioEndpointInfo[] audioEndpoints;
        private IntPtr targetWindow;
        private int page;
        private int selected;
        private bool closeConfirmation;
        private string lastStatus;
        private int scalePercent;

        internal HuymaierGameBarWindow(Window mainConsoleWindow)
        {
            consoleWindow = mainConsoleWindow;
            itemCards = new List<Border>();
            taskWindows = new List<SystemWindowEntry>();
            taskPreviewTargets = new List<FrameworkElement>();
            taskPreviews = new List<DwmTaskPreviewHost.Preview>();
            audioEndpoints = new AudioEndpointInfo[0];
            lastStatus = String.Empty;
            scalePercent = 100;

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
            // This is a compact Game Bar, not a fullscreen takeover. The window itself
            // is positioned over only the lower-center portion of the target monitor.
            root.Background = Brushes.Transparent;
            Border card = new Border();
            card.HorizontalAlignment = HorizontalAlignment.Stretch;
            card.VerticalAlignment = VerticalAlignment.Stretch;
            card.Background = new SolidColorBrush(Color.FromArgb(246, 8, 12, 18));
            card.BorderBrush = new SolidColorBrush(Color.FromRgb(69, 81, 99));
            card.BorderThickness = new Thickness(1.5);
            card.CornerRadius = new CornerRadius(20);
            card.Padding = new Thickness(22, 16, 22, 14);

            Grid layout = new Grid();
            layout.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            layout.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            layout.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            layout.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
            layout.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            layout.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });

            StackPanel header = new StackPanel(); header.Orientation = Orientation.Horizontal;
            TextBlock brand = new TextBlock(); brand.Text = "HUYMAIER GAME BAR"; brand.FontSize = 18; brand.FontWeight = FontWeights.Bold; brand.Foreground = new SolidColorBrush(Color.FromRgb(231, 196, 94)); header.Children.Add(brand);
            contextText = new TextBlock(); contextText.Margin = new Thickness(14, 3, 0, 0); contextText.FontSize = 11; contextText.Foreground = new SolidColorBrush(Color.FromRgb(164, 177, 196)); header.Children.Add(contextText);
            Grid.SetRow(header, 0); layout.Children.Add(header);

            tabsText = new TextBlock(); tabsText.Margin = new Thickness(0, 8, 0, 0); tabsText.FontSize = 10; tabsText.FontWeight = FontWeights.SemiBold; tabsText.Foreground = new SolidColorBrush(Color.FromRgb(135, 151, 174)); Grid.SetRow(tabsText, 1); layout.Children.Add(tabsText);
            pageText = new TextBlock(); pageText.Margin = new Thickness(0, 5, 0, 7); pageText.FontSize = 20; pageText.FontWeight = FontWeights.SemiBold; Grid.SetRow(pageText, 2); layout.Children.Add(pageText);

            scroller = new ScrollViewer(); scroller.VerticalScrollBarVisibility = ScrollBarVisibility.Hidden; scroller.HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled; itemPanel = new StackPanel(); scroller.Content = itemPanel; Grid.SetRow(scroller, 3); layout.Children.Add(scroller);
            statusText = new TextBlock(); statusText.Margin = new Thickness(0, 5, 0, 0); statusText.FontSize = 10; statusText.Foreground = new SolidColorBrush(Color.FromRgb(231, 196, 94)); statusText.TextWrapping = TextWrapping.Wrap; Grid.SetRow(statusText, 4); layout.Children.Add(statusText);
            footerText = new TextBlock(); footerText.Margin = new Thickness(0, 5, 0, 0); footerText.FontSize = 10; footerText.Foreground = new SolidColorBrush(Color.FromRgb(155, 168, 188)); Grid.SetRow(footerText, 5); layout.Children.Add(footerText);
            card.Child = layout; root.Children.Add(card); Content = root;

            PreviewKeyDown += delegate(object sender, System.Windows.Input.KeyEventArgs e) { if (e.Key == System.Windows.Input.Key.Escape) { HideBar(); e.Handled = true; } };
            Deactivated += delegate { if (IsVisible) Topmost = true; };
            Closed += delegate { DisposeTaskPreviews(); telemetryTimer.Stop(); };

            telemetryTimer = new DispatcherTimer();
            telemetryTimer.Interval = TimeSpan.FromMilliseconds(850);
            telemetryTimer.Tick += delegate { if (IsVisible && (page == PagePerformance || page == PageControllers)) Refresh(); };
        }

        internal void ShowForForegroundWindow()
        {
            IntPtr foreground = SystemWindowCatalog.GetForegroundWindow();
            IntPtr overlayHandle = IntPtr.Zero; try { overlayHandle = new WindowInteropHelper(this).Handle; } catch { }
            IntPtr consoleHandle = IntPtr.Zero; try { consoleHandle = new WindowInteropHelper(consoleWindow).Handle; } catch { }
            if (foreground != IntPtr.Zero && foreground != overlayHandle && foreground != consoleHandle) targetWindow = foreground;
            PositionOnTargetMonitor(targetWindow);
            page = PageHome; selected = 0; closeConfirmation = false; lastStatus = String.Empty; Refresh();
            if (!IsVisible) Show();
            WindowState = WindowState.Normal; Activate(); Focus(); telemetryTimer.Start();
        }

        internal void SetScalePercent(int value)
        {
            scalePercent = Math.Max(70, Math.Min(140, value));
            if (IsVisible) PositionOnTargetMonitor(targetWindow);
        }

        private Rect GetLogicalMonitorBounds(Forms.Screen screen)
        {
            Drawing.Rectangle bounds = screen == null ? Forms.Screen.PrimaryScreen.Bounds : screen.Bounds;
            try
            {
                IntPtr handle = new WindowInteropHelper(this).EnsureHandle();
                HwndSource source = HwndSource.FromHwnd(handle);
                if (source != null && source.CompositionTarget != null)
                {
                    Matrix fromDevice = source.CompositionTarget.TransformFromDevice;
                    Point topLeft = fromDevice.Transform(new Point(bounds.Left, bounds.Top));
                    Point bottomRight = fromDevice.Transform(new Point(bounds.Right, bounds.Bottom));
                    return new Rect(topLeft, bottomRight);
                }
            }
            catch { }
            return new Rect(bounds.Left, bounds.Top, bounds.Width, bounds.Height);
        }

        private void PositionOnTargetMonitor(IntPtr target)
        {
            try
            {
                Forms.Screen screen = target != IntPtr.Zero ? Forms.Screen.FromHandle(target) : Forms.Screen.PrimaryScreen;
                Rect bounds = GetLogicalMonitorBounds(screen);
                double factor = scalePercent / 100.0;
                double width = Math.Max(760.0, Math.Min(bounds.Width * 0.92, bounds.Width * 0.70 * factor));
                double height = Math.Max(220.0, Math.Min(bounds.Height * 0.50, bounds.Height * 0.24 * factor));
                Width = width;
                Height = height;
                Left = bounds.Left + ((bounds.Width - width) / 2.0);
                Top = bounds.Top + ((bounds.Height - height) / 2.0);
            }
            catch
            {
                double factor = scalePercent / 100.0;
                double width = Math.Max(760.0, Math.Min(SystemParameters.PrimaryScreenWidth * 0.92, SystemParameters.PrimaryScreenWidth * 0.70 * factor));
                double height = Math.Max(220.0, Math.Min(SystemParameters.PrimaryScreenHeight * 0.50, SystemParameters.PrimaryScreenHeight * 0.24 * factor));
                Width = width; Height = height;
                Left = SystemParameters.VirtualScreenLeft + ((SystemParameters.PrimaryScreenWidth - width) / 2.0);
                Top = SystemParameters.VirtualScreenTop + ((SystemParameters.PrimaryScreenHeight - height) / 2.0);
            }
        }

        internal void HideBar()
        {
            DisposeTaskPreviews(); telemetryTimer.Stop();
            try { Hide(); } catch { }
            if (targetWindow != IntPtr.Zero) SystemWindowCatalog.Activate(targetWindow);
        }

        private void DisposeTaskPreviews()
        {
            foreach (DwmTaskPreviewHost.Preview preview in taskPreviews) { if (preview != null) preview.Dispose(); }
            taskPreviews.Clear(); taskPreviewTargets.Clear();
        }

        private string PageName(int value)
        {
            switch (value) { case PageSwitcher: return "SWITCH APPS"; case PageAudio: return "AUDIO"; case PageCapture: return "CAPTURE"; case PagePerformance: return "PERFORMANCE"; case PageControllers: return "CONTROLLERS"; default: return "HOME"; }
        }

        private void RefreshTabs()
        {
            string[] names = { "HOME", "SWITCH APPS", "AUDIO", "CAPTURE", "PERFORMANCE", "CONTROLLERS" };
            StringBuilder builder = new StringBuilder();
            for (int i = 0; i < names.Length; i++) { if (i > 0) builder.Append("     "); builder.Append(i == page ? "[ " + names[i] + " ]" : names[i]); }
            tabsText.Text = builder.ToString();
        }

        private void Refresh()
        {
            DisposeTaskPreviews();
            itemPanel.Children.Clear(); itemCards.Clear();
            bool horizontalRail = page == PageHome || page == PageSwitcher;
            itemPanel.Orientation = horizontalRail ? Orientation.Horizontal : Orientation.Vertical;
            scroller.HorizontalScrollBarVisibility = horizontalRail ? ScrollBarVisibility.Hidden : ScrollBarVisibility.Disabled;
            scroller.VerticalScrollBarVisibility = horizontalRail ? ScrollBarVisibility.Disabled : ScrollBarVisibility.Hidden;
            contextText.Text = GetTargetTitle(); RefreshTabs(); statusText.Text = lastStatus ?? String.Empty;
            if (page == PageHome) BuildHome();
            else if (page == PageSwitcher) BuildSwitcher();
            else if (page == PageAudio) BuildAudio();
            else if (page == PageCapture) BuildCapture();
            else if (page == PagePerformance) BuildPerformance();
            else BuildControllers();
            UpdateSelection();
            if (page == PageSwitcher) Dispatcher.BeginInvoke(DispatcherPriority.Loaded, new Action(AttachTaskPreviews));
        }

        private string GetTargetTitle()
        {
            string title = SystemWindowCatalog.GetTitle(targetWindow);
            return String.IsNullOrWhiteSpace(title) ? "External game / app" : title;
        }

        private void BuildHome()
        {
            pageText.Text = "Game Bar";
            AddItem("Resume", "Return to the current game or app.");
            AddItem("Switch Apps", "Native controller task switcher with live desktop previews.");
            AddItem("Audio", "Master volume, mute, and output-device selection.");
            AddItem("Capture", "Take a screenshot or open the Huymaier captures folder.");
            AddItem("Performance", "Live CPU, GPU, memory, and current-app usage.");
            AddItem("Controllers", "Connected controller and battery/connection status.");
            AddItem("Return to Huymaier Console", "Bring the fullscreen Console back to the foreground.");
            AddItem("Close Current App", closeConfirmation ? "Press A again to confirm a normal close request." : "Request a normal close of the current game or app.");
            footerText.Text = closeConfirmation ? "A  Confirm Close     B  Cancel     GUIDE  Resume" : "A  Select     B / GUIDE  Resume     LB / RB  Pages";
        }

        private void BuildSwitcher()
        {
            pageText.Text = "Switch Apps";
            taskWindows.Clear();
            IntPtr overlayHandle = IntPtr.Zero; try { overlayHandle = new WindowInteropHelper(this).Handle; } catch { }
            taskWindows.AddRange(SystemWindowCatalog.GetTaskWindows(overlayHandle, targetWindow));
            if (taskWindows.Count == 0) { AddItem("No other apps", "No switchable desktop windows are currently available."); selected = 0; }
            else
            {
                if (selected >= taskWindows.Count) selected = taskWindows.Count - 1;
                for (int i = 0; i < taskWindows.Count; i++) AddTaskItem(taskWindows[i]);
            }
            footerText.Text = taskWindows.Count > 0 ? "A  Switch     X / Square  Close     B  Home     GUIDE  Resume     LB / RB  Pages" : "B  Home     GUIDE  Resume     LB / RB  Pages";
        }

        private void BuildAudio()
        {
            pageText.Text = "Audio";
            int volume = 0; bool muted = false;
            try { volume = (int)Math.Round(AudioBridge.GetMasterVolume() * 100.0); muted = AudioBridge.GetMute(); } catch { }
            try { audioEndpoints = AudioBridge.GetRenderEndpoints(); } catch { audioEndpoints = new AudioEndpointInfo[0]; }
            string output = "No active output";
            for (int i = 0; i < audioEndpoints.Length; i++) if (audioEndpoints[i].IsDefault) { output = audioEndpoints[i].Name; break; }
            AddItem("Master Volume", volume.ToString() + "% — use Left / Right to adjust");
            AddItem("Mute", muted ? "Muted — press A to unmute" : "On — press A to mute");
            AddItem("Output Device", output + " — press A to choose next output");
            footerText.Text = "A  Toggle / Change     Left / Right  Volume     B  Home     GUIDE  Resume     LB / RB  Pages";
        }

        private void BuildCapture()
        {
            pageText.Text = "Capture";
            AddItem("Take Screenshot", "Captures the current display without leaving the game running.");
            AddItem("Open Captures Folder", GameBarCaptureService.CaptureDirectory);
            footerText.Text = "A  Select     B  Home     GUIDE  Resume     LB / RB  Pages";
        }

        private void BuildPerformance()
        {
            pageText.Text = "Performance";
            GameBarPerformanceSnapshot perf = GameBarPerformanceMonitor.Read(targetWindow);
            AddInfoItem("CPU", perf.CpuPercent.ToString("0") + "% system utilization");
            AddInfoItem("GPU", perf.HasGpu ? perf.GpuPercent.ToString("0") + "% 3D engine utilization" : "GPU utilization counter unavailable");
            AddInfoItem("Memory", String.Format("{0:0}% — {1:N0} MB of {2:N0} MB used", perf.MemoryPercent, perf.UsedMemoryMb, perf.TotalMemoryMb));
            AddInfoItem(perf.ProcessName, String.Format("{0:N0} MB working set", perf.ProcessWorkingSetMb));
            footerText.Text = "B  Home     GUIDE  Resume     LB / RB  Pages";
        }

        private void BuildControllers()
        {
            pageText.Text = "Controllers";
            List<ControllerStatusEntry> controllers = GameBarControllerCatalog.GetEntries();
            for (int i = 0; i < controllers.Count; i++) AddInfoItem(controllers[i].Name, controllers[i].Detail);
            AddInfoItem("System Guide routing", HuymaierSystemButtonBridge.IsAvailable ? "Microsoft GameInput system-button bridge active" : "GameInput unavailable — Raw HID/XInput fallback active");
            footerText.Text = "B  Home     GUIDE  Resume     LB / RB  Pages";
        }

        private void AddItem(string title, string detail) { AddStandardItem(title, detail, true); }
        private void AddInfoItem(string title, string detail) { AddStandardItem(title, detail, false); }

        private void AddStandardItem(string title, string detail, bool selectable)
        {
            bool compactRail = page == PageHome;
            Border border = new Border();
            border.Height = compactRail ? 86 : 56;
            border.Width = compactRail ? 158 : Double.NaN;
            border.Margin = compactRail ? new Thickness(0, 0, 9, 0) : new Thickness(0, 0, 0, 6);
            border.Padding = compactRail ? new Thickness(12, 9, 12, 8) : new Thickness(14, 7, 14, 7);
            border.CornerRadius = new CornerRadius(11); border.BorderThickness = new Thickness(1); border.Tag = selectable;
            StackPanel stack = new StackPanel();
            TextBlock titleText = new TextBlock(); titleText.Text = title; titleText.FontSize = compactRail ? 14 : 15; titleText.FontWeight = FontWeights.SemiBold; titleText.TextWrapping = TextWrapping.Wrap;
            TextBlock detailText = new TextBlock(); detailText.Text = detail; detailText.FontSize = compactRail ? 9 : 10; detailText.Foreground = new SolidColorBrush(Color.FromRgb(153, 168, 190)); detailText.Margin = new Thickness(0, 3, 0, 0); detailText.TextTrimming = TextTrimming.CharacterEllipsis; detailText.MaxHeight = compactRail ? 28 : 20;
            stack.Children.Add(titleText); stack.Children.Add(detailText); border.Child = stack; itemPanel.Children.Add(border); itemCards.Add(border);
        }

        private void AddTaskItem(SystemWindowEntry entry)
        {
            // Preview cards must stay fully inside the compact bar; the horizontal
            // ScrollViewer handles additional tasks instead of letting cards overflow.
            Border border = new Border(); border.Width = 214; border.Height = 112; border.Margin = new Thickness(0, 0, 9, 0); border.Padding = new Thickness(7); border.CornerRadius = new CornerRadius(11); border.BorderThickness = new Thickness(1); border.Tag = true;
            Grid grid = new Grid(); grid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(66) }); grid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(21) }); grid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(14) });
            Border previewTarget = new Border(); previewTarget.Background = new SolidColorBrush(Color.FromRgb(3, 6, 10)); previewTarget.CornerRadius = new CornerRadius(7); previewTarget.ClipToBounds = true; Grid.SetRow(previewTarget, 0); grid.Children.Add(previewTarget);
            TextBlock title = new TextBlock(); title.Text = entry.Title; title.FontSize = 11; title.FontWeight = FontWeights.SemiBold; title.Margin = new Thickness(2, 3, 2, 0); title.TextTrimming = TextTrimming.CharacterEllipsis; Grid.SetRow(title, 1); grid.Children.Add(title);
            TextBlock process = new TextBlock(); process.Text = String.IsNullOrWhiteSpace(entry.ProcessName) ? "Desktop app" : entry.ProcessName; process.FontSize = 9; process.Foreground = new SolidColorBrush(Color.FromRgb(153, 168, 190)); process.Margin = new Thickness(2, 1, 2, 0); process.TextTrimming = TextTrimming.CharacterEllipsis; Grid.SetRow(process, 2); grid.Children.Add(process);
            border.Child = grid; itemPanel.Children.Add(border); itemCards.Add(border); taskPreviewTargets.Add(previewTarget);
        }

        private void AttachTaskPreviews()
        {
            DisposeTaskPreviewsOnly();
            int count = Math.Min(taskWindows.Count, taskPreviewTargets.Count);
            for (int i = 0; i < count; i++)
            {
                DwmTaskPreviewHost.Preview preview = DwmTaskPreviewHost.Attach(this, taskWindows[i].Handle, taskPreviewTargets[i]);
                if (preview != null) taskPreviews.Add(preview);
            }
        }

        private void DisposeTaskPreviewsOnly()
        {
            foreach (DwmTaskPreviewHost.Preview preview in taskPreviews) if (preview != null) preview.Dispose();
            taskPreviews.Clear();
        }

        private bool IsSelectable(int index)
        {
            if (index < 0 || index >= itemCards.Count) return false;
            try { return itemCards[index].Tag is bool && (bool)itemCards[index].Tag; } catch { return false; }
        }

        private void UpdateSelection()
        {
            if (itemCards.Count == 0) return;
            if (selected < 0) selected = 0; if (selected >= itemCards.Count) selected = itemCards.Count - 1;
            bool anySelectable = false; for (int i = 0; i < itemCards.Count; i++) if (IsSelectable(i)) { anySelectable = true; break; }
            if (anySelectable && !IsSelectable(selected)) { for (int i = 0; i < itemCards.Count; i++) if (IsSelectable(i)) { selected = i; break; } }
            for (int i = 0; i < itemCards.Count; i++)
            {
                Border card = itemCards[i]; bool active = anySelectable && i == selected;
                card.Background = new SolidColorBrush(active ? Color.FromRgb(229, 199, 104) : Color.FromArgb(230, 17, 25, 38));
                card.BorderBrush = new SolidColorBrush(active ? Color.FromRgb(255, 240, 160) : Color.FromRgb(57, 71, 91));
                DependencyObject child = card.Child; TextBlock title = null;
                StackPanel stack = child as StackPanel; if (stack != null && stack.Children.Count > 0) title = stack.Children[0] as TextBlock;
                Grid grid = child as Grid; if (grid != null && grid.Children.Count > 1) title = grid.Children[1] as TextBlock;
                if (title != null) title.Foreground = new SolidColorBrush(active ? Color.FromRgb(15, 20, 28) : Colors.White);
            }
            if (anySelectable) { try { itemCards[selected].BringIntoView(); } catch { } }
        }

        internal void ProcessControllerCommand(string command)
        {
            if (String.IsNullOrWhiteSpace(command)) return;
            if (command == "Guide") { HideBar(); return; }
            if (command == "Back")
            {
                if (closeConfirmation) { closeConfirmation = false; lastStatus = String.Empty; Refresh(); return; }
                if (page != PageHome) { page = PageHome; selected = 0; lastStatus = String.Empty; Refresh(); }
                else HideBar();
                return;
            }
            if (command == "LeftShoulder") { ChangePage(-1); return; }
            if (command == "RightShoulder") { ChangePage(1); return; }
            bool horizontalRail = page == PageHome || page == PageSwitcher;
            if (command == "Left")
            {
                if (page == PageAudio && selected == 0) { AdjustVolume(-5); return; }
                if (horizontalRail) { Move(-1); return; }
            }
            if (command == "Right")
            {
                if (page == PageAudio && selected == 0) { AdjustVolume(5); return; }
                if (horizontalRail) { Move(1); return; }
            }
            // Home and Switch Apps are horizontal rails. Vertical pages keep Up/Down.
            if (command == "Up") { if (!horizontalRail) Move(-1); return; }
            if (command == "Down") { if (!horizontalRail) Move(1); return; }
            if (command == "Secondary") { if (page == PageSwitcher) RequestCloseSelectedTask(); return; }
            if (command == "Confirm") { InvokeSelected(); return; }
        }

        private void ChangePage(int delta)
        {
            closeConfirmation = false; lastStatus = String.Empty;
            page = (page + delta + PageCount) % PageCount; selected = 0; Refresh();
        }

        private void Move(int delta)
        {
            int count = itemCards.Count; if (count <= 0) return;
            int start = selected;
            do { selected = (selected + delta + count) % count; if (IsSelectable(selected)) break; } while (selected != start);
            UpdateSelection();
        }

        private void InvokeSelected()
        {
            if (page == PagePerformance || page == PageControllers) return;
            if (page == PageSwitcher)
            {
                if (taskWindows.Count == 0 || selected < 0 || selected >= taskWindows.Count) return;
                IntPtr hWnd = taskWindows[selected].Handle; DisposeTaskPreviews(); telemetryTimer.Stop(); try { Hide(); } catch { } SystemWindowCatalog.Activate(hWnd); targetWindow = hWnd; return;
            }
            if (page == PageAudio) { InvokeAudioSelected(); return; }
            if (page == PageCapture) { InvokeCaptureSelected(); return; }

            switch (selected)
            {
                case 0: HideBar(); break;
                case 1: page = PageSwitcher; selected = 0; Refresh(); break;
                case 2: page = PageAudio; selected = 0; Refresh(); break;
                case 3: page = PageCapture; selected = 0; Refresh(); break;
                case 4: page = PagePerformance; selected = 0; Refresh(); break;
                case 5: page = PageControllers; selected = 0; Refresh(); break;
                case 6: ReturnToConsole(); break;
                case 7:
                    if (!closeConfirmation) { closeConfirmation = true; lastStatus = "Close confirmation armed for " + GetTargetTitle() + "."; Refresh(); }
                    else { if (targetWindow != IntPtr.Zero) SystemWindowCatalog.Close(targetWindow); try { Hide(); } catch { } }
                    break;
            }
        }

        private void InvokeAudioSelected()
        {
            if (selected == 0) { AdjustVolume(5); return; }
            if (selected == 1) { try { AudioBridge.SetMute(!AudioBridge.GetMute()); lastStatus = AudioBridge.GetMute() ? "Audio muted." : "Audio unmuted."; } catch { lastStatus = "Audio mute could not be changed."; } Refresh(); return; }
            if (selected == 2)
            {
                try
                {
                    audioEndpoints = AudioBridge.GetRenderEndpoints();
                    if (audioEndpoints.Length == 0) { lastStatus = "No active audio output was found."; Refresh(); return; }
                    int current = -1; for (int i = 0; i < audioEndpoints.Length; i++) if (audioEndpoints[i].IsDefault) { current = i; break; }
                    int next = (current + 1 + audioEndpoints.Length) % audioEndpoints.Length;
                    bool changed = AudioBridge.SetDefaultEndpoint(audioEndpoints[next].Id);
                    lastStatus = changed ? "Audio output changed to " + audioEndpoints[next].Name + "." : "Windows did not accept the audio-output change.";
                }
                catch { lastStatus = "Audio output could not be changed."; }
                Refresh();
            }
        }

        private void AdjustVolume(int delta)
        {
            try
            {
                float current = AudioBridge.GetMasterVolume();
                float next = Math.Max(0f, Math.Min(1f, current + (delta / 100f)));
                AudioBridge.SetMasterVolume(next); lastStatus = "Volume " + ((int)Math.Round(next * 100)).ToString() + "%";
            }
            catch { lastStatus = "Master volume could not be changed."; }
            Refresh();
        }

        private void InvokeCaptureSelected()
        {
            if (selected == 1) { try { GameBarCaptureService.OpenCaptureDirectory(); lastStatus = String.Empty; } catch { lastStatus = "Captures folder could not be opened."; } return; }
            if (selected != 0) return;
            IntPtr captureTarget = targetWindow;
            DisposeTaskPreviews(); telemetryTimer.Stop();
            try { Hide(); } catch { }
            Task.Factory.StartNew(delegate
            {
                Thread.Sleep(180);
                try { return GameBarCaptureService.CaptureMonitor(captureTarget); }
                catch { return String.Empty; }
            }).ContinueWith(delegate(Task<string> task)
            {
                string path = task.Result;
                Dispatcher.BeginInvoke(new Action(delegate
                {
                    lastStatus = String.IsNullOrWhiteSpace(path) ? "Screenshot capture failed." : "Screenshot saved: " + path;
                    if (captureTarget != IntPtr.Zero) SystemWindowCatalog.Activate(captureTarget);
                }));
            });
        }

        private void RequestCloseSelectedTask()
        {
            if (taskWindows.Count == 0 || selected < 0 || selected >= taskWindows.Count) return;
            SystemWindowEntry entry = taskWindows[selected];
            SystemWindowCatalog.Close(entry.Handle);
            lastStatus = "Close requested for " + entry.Title + ".";
            Refresh();
        }

        private void ReturnToConsole()
        {
            DisposeTaskPreviews(); telemetryTimer.Stop(); try { Hide(); } catch { }
            if (consoleWindow != null)
            {
                consoleWindow.Dispatcher.BeginInvoke(new Action(delegate
                {
                    try
                    {
                        if (consoleWindow.WindowState == WindowState.Minimized) consoleWindow.WindowState = WindowState.Maximized;
                        // Flush external-overlay edges before Console resumes ownership.
                        try { NativeConsoleNavigation.Reset(); } catch { }
                        consoleWindow.Show(); consoleWindow.Activate(); consoleWindow.Topmost = true; consoleWindow.Topmost = false; consoleWindow.Focus();
                    }
                    catch { }
                }));
            }
        }
    }
}
