using System;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Windows.Forms;

namespace HuymaierConsole.UnifiedCursor
{
    internal static class NativeMethods
    {
        internal const int GWL_STYLE = -16;
        internal const int GWL_EXSTYLE = -20;
        internal const long WS_CAPTION = 0x00C00000L;
        internal const long WS_THICKFRAME = 0x00040000L;
        internal const long WS_MINIMIZEBOX = 0x00020000L;
        internal const long WS_MAXIMIZEBOX = 0x00010000L;
        internal const long WS_SYSMENU = 0x00080000L;
        internal const long WS_POPUP = 0x80000000L;
        internal const long WS_EX_DLGMODALFRAME = 0x00000001L;
        internal const long WS_EX_WINDOWEDGE = 0x00000100L;
        internal const long WS_EX_CLIENTEDGE = 0x00000200L;
        internal const long WS_EX_STATICEDGE = 0x00020000L;
        internal const uint SWP_NOSENDCHANGING = 0x0400;
        internal const uint SWP_FRAMECHANGED = 0x0020;
        internal const uint SWP_SHOWWINDOW = 0x0040;
        internal const uint MONITOR_DEFAULTTONEAREST = 2;
        internal const uint MOUSEEVENTF_LEFTDOWN = 0x0002;
        internal const uint MOUSEEVENTF_LEFTUP = 0x0004;
        internal const uint MOUSEEVENTF_WHEEL = 0x0800;
        internal const uint MOUSEEVENTF_HWHEEL = 0x01000;
        internal const uint KEYEVENTF_KEYUP = 0x0002;
        internal const byte VK_F11 = 0x7A;
        internal const byte VK_LWIN = 0x5B;
        internal const byte VK_SHIFT = 0x10;
        internal const byte VK_RETURN = 0x0D;
        internal const byte VK_ESCAPE = 0x1B;
        internal const uint SPI_SETCURSORS = 0x0057;
        internal const uint IMAGE_CURSOR = 2;
        internal const uint OCR_NORMAL = 32512;
        internal const uint OCR_IBEAM = 32513;
        internal const uint OCR_HAND = 32649;
        internal const uint OCR_CROSS = 32515;
        internal const uint OCR_SIZEALL = 32646;
        internal const int GA_ROOT = 2;
        internal static readonly IntPtr HWND_TOP = IntPtr.Zero;
        internal const int DWMWA_NCRENDERING_POLICY = 2;
        internal const int DWMWA_WINDOW_CORNER_PREFERENCE = 33;
        internal const int DWMNCRP_DISABLED = 1;
        internal const int DWMNCRP_USEWINDOWSTYLE = 0;
        internal const int DWMWCP_DONOTROUND = 1;

        [StructLayout(LayoutKind.Sequential)] internal struct POINT { internal int X; internal int Y; }
        [StructLayout(LayoutKind.Sequential)] internal struct RECT { internal int Left; internal int Top; internal int Right; internal int Bottom; }
        [StructLayout(LayoutKind.Sequential)] internal struct ICONINFO { [MarshalAs(UnmanagedType.Bool)] internal bool fIcon; internal uint xHotspot; internal uint yHotspot; internal IntPtr hbmMask; internal IntPtr hbmColor; }
        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)] internal struct MONITORINFO { internal int cbSize; internal RECT rcMonitor; internal RECT rcWork; internal uint dwFlags; }

        [DllImport("HuymaierGameInputBridge.dll", CallingConvention = CallingConvention.Cdecl)] internal static extern int HC_GameInputInitialize();
        [DllImport("HuymaierGameInputBridge.dll", CallingConvention = CallingConvention.Cdecl)] internal static extern int HC_ReadGamepadPointerState(out float leftX, out float leftY, out float rightX, out float rightY, out float leftTrigger, out float rightTrigger, out uint buttons);
        [DllImport("HuymaierGameInputBridge.dll", CallingConvention = CallingConvention.Cdecl)] internal static extern void HC_GameInputShutdown();
        [DllImport("user32.dll")] internal static extern IntPtr GetForegroundWindow();
        [DllImport("user32.dll")] internal static extern bool IsWindow(IntPtr hwnd);
        [DllImport("user32.dll")] internal static extern bool IsWindowVisible(IntPtr hwnd);
        [DllImport("user32.dll")] internal static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint processId);
        [DllImport("user32.dll")] internal static extern IntPtr GetAncestor(IntPtr hwnd, uint flags);
        [DllImport("user32.dll")] internal static extern bool GetWindowRect(IntPtr hwnd, out RECT rect);
        [DllImport("user32.dll")] internal static extern IntPtr MonitorFromWindow(IntPtr hwnd, uint flags);
        [DllImport("user32.dll", CharSet = CharSet.Auto)] internal static extern bool GetMonitorInfo(IntPtr monitor, ref MONITORINFO info);
        [DllImport("user32.dll")] internal static extern bool SetWindowPos(IntPtr hwnd, IntPtr insertAfter, int x, int y, int cx, int cy, uint flags);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)] internal static extern int GetClassName(IntPtr hwnd, StringBuilder builder, int maxCount);
        [DllImport("user32.dll", EntryPoint = "GetWindowLongPtrW")] internal static extern IntPtr GetWindowLongPtr64(IntPtr hwnd, int index);
        [DllImport("user32.dll", EntryPoint = "GetWindowLongW")] internal static extern int GetWindowLong32(IntPtr hwnd, int index);
        [DllImport("user32.dll", EntryPoint = "SetWindowLongPtrW")] internal static extern IntPtr SetWindowLongPtr64(IntPtr hwnd, int index, IntPtr value);
        [DllImport("user32.dll", EntryPoint = "SetWindowLongW")] internal static extern int SetWindowLong32(IntPtr hwnd, int index, int value);
        [DllImport("user32.dll")] internal static extern bool GetCursorPos(out POINT point);
        [DllImport("user32.dll")] internal static extern bool SetCursorPos(int x, int y);
        [DllImport("user32.dll")] internal static extern void mouse_event(uint flags, uint dx, uint dy, int data, UIntPtr extraInfo);
        [DllImport("user32.dll")] internal static extern void keybd_event(byte virtualKey, byte scanCode, uint flags, UIntPtr extraInfo);
        [DllImport("user32.dll", SetLastError = true)] internal static extern bool SetSystemCursor(IntPtr cursor, uint id);
        [DllImport("user32.dll", SetLastError = true)] internal static extern bool SystemParametersInfo(uint action, uint param, IntPtr value, uint flags);
        [DllImport("user32.dll")] internal static extern bool GetIconInfo(IntPtr icon, out ICONINFO info);
        [DllImport("user32.dll")] internal static extern IntPtr CreateIconIndirect(ref ICONINFO info);
        [DllImport("user32.dll")] internal static extern bool DestroyIcon(IntPtr icon);
        [DllImport("gdi32.dll")] internal static extern bool DeleteObject(IntPtr obj);
        [DllImport("dwmapi.dll")] internal static extern int DwmSetWindowAttribute(IntPtr hwnd, int attribute, ref int value, int size);

        internal static long GetWindowLongValue(IntPtr hwnd, int index) { return IntPtr.Size == 8 ? GetWindowLongPtr64(hwnd, index).ToInt64() : GetWindowLong32(hwnd, index); }
        internal static void SetWindowLongValue(IntPtr hwnd, int index, long value) { if (IntPtr.Size == 8) SetWindowLongPtr64(hwnd, index, new IntPtr(value)); else SetWindowLong32(hwnd, index, unchecked((int)value)); }
    }

    internal static class GoldSystemCursor
    {
        private static bool applied;
        private static readonly uint[] CursorIds = new uint[] { NativeMethods.OCR_NORMAL, NativeMethods.OCR_HAND, NativeMethods.OCR_IBEAM, NativeMethods.OCR_CROSS, NativeMethods.OCR_SIZEALL };

        private static IntPtr CreateGoldCursor()
        {
            using (Bitmap bitmap = new Bitmap(38, 38, PixelFormat.Format32bppArgb))
            using (Graphics g = Graphics.FromImage(bitmap))
            using (Pen shadow = new Pen(Color.FromArgb(235, 8, 13, 20), 5.0f))
            using (Pen gold = new Pen(Color.FromArgb(255, 240, 204, 88), 3.0f))
            using (Brush center = new SolidBrush(Color.FromArgb(255, 255, 243, 166)))
            {
                g.Clear(Color.Transparent);
                g.SmoothingMode = SmoothingMode.AntiAlias;
                g.DrawEllipse(shadow, 5, 5, 28, 28);
                g.DrawEllipse(gold, 6.5f, 6.5f, 25, 25);
                g.FillEllipse(center, 16, 16, 6, 6);
                IntPtr icon = bitmap.GetHicon();
                NativeMethods.ICONINFO info;
                if (!NativeMethods.GetIconInfo(icon, out info)) { NativeMethods.DestroyIcon(icon); return IntPtr.Zero; }
                info.fIcon = false;
                info.xHotspot = 19;
                info.yHotspot = 19;
                IntPtr cursor = NativeMethods.CreateIconIndirect(ref info);
                if (info.hbmColor != IntPtr.Zero) NativeMethods.DeleteObject(info.hbmColor);
                if (info.hbmMask != IntPtr.Zero) NativeMethods.DeleteObject(info.hbmMask);
                NativeMethods.DestroyIcon(icon);
                return cursor;
            }
        }

        internal static void Apply()
        {
            if (applied) return;
            bool any = false;
            foreach (uint id in CursorIds)
            {
                IntPtr cursor = CreateGoldCursor();
                if (cursor == IntPtr.Zero) continue;
                if (NativeMethods.SetSystemCursor(cursor, id)) any = true;
                else NativeMethods.DestroyIcon(cursor);
            }
            applied = any;
        }

        internal static void Restore()
        {
            if (!applied) return;
            try { NativeMethods.SystemParametersInfo(NativeMethods.SPI_SETCURSORS, 0, IntPtr.Zero, 0); } catch { }
            applied = false;
        }
    }

    internal sealed class CursorSession : ApplicationContext
    {
        private readonly int parentProcessId;
        private readonly string mode;
        private readonly int speedPercent;
        private readonly string stateFile;
        private readonly System.Windows.Forms.Timer timer;
        private readonly Stopwatch clock;
        private IntPtr targetWindow;
        private uint targetProcessId;
        private long originalStyle;
        private long originalExStyle;
        private NativeMethods.RECT originalRect;
        private bool fullscreenApplied;
        private bool nativeFullscreenAttempted;
        private bool cursorOwned;
        private uint lastButtons;
        private long lastTicks;
        private double cursorX;
        private double cursorY;
        private double wheelAccumulator;
        private double horizontalWheelAccumulator;
        private DateTime lastFullscreenRefreshUtc = DateTime.MinValue;
        private DateTime lastContextReadUtc = DateTime.MinValue;
        private string shellContext = "shell";

        internal CursorSession(int parentPid, string requestedMode, int speed, string contextPath)
        {
            parentProcessId = parentPid;
            mode = String.IsNullOrWhiteSpace(requestedMode) ? "shell" : requestedMode.Trim().ToLowerInvariant();
            speedPercent = Math.Max(40, Math.Min(200, speed));
            stateFile = contextPath ?? String.Empty;
            clock = Stopwatch.StartNew();
            lastTicks = clock.ElapsedTicks;
            timer = new System.Windows.Forms.Timer();
            timer.Interval = 8;
            timer.Tick += OnTick;

            try { NativeMethods.SystemParametersInfo(NativeMethods.SPI_SETCURSORS, 0, IntPtr.Zero, 0); } catch { }
            if (NativeMethods.HC_GameInputInitialize() == 0) { ExitThread(); return; }

            if (mode == "streaming")
            {
                targetWindow = WaitForStreamingWindow();
                if (targetWindow == IntPtr.Zero) { ExitThread(); return; }
                targetWindow = RootWindow(targetWindow);
                NativeMethods.GetWindowThreadProcessId(targetWindow, out targetProcessId);
                ApplyFullscreen();
            }

            NativeMethods.POINT point;
            if (NativeMethods.GetCursorPos(out point)) { cursorX = point.X; cursorY = point.Y; }
            timer.Start();
        }

        private static IntPtr RootWindow(IntPtr hwnd)
        {
            if (hwnd == IntPtr.Zero) return IntPtr.Zero;
            IntPtr root = NativeMethods.GetAncestor(hwnd, NativeMethods.GA_ROOT);
            return root == IntPtr.Zero ? hwnd : root;
        }

        private IntPtr WaitForStreamingWindow()
        {
            DateTime deadline = DateTime.UtcNow.AddSeconds(20);
            IntPtr candidate = IntPtr.Zero;
            DateTime stableSince = DateTime.MinValue;
            while (DateTime.UtcNow < deadline)
            {
                if (!ParentAlive()) return IntPtr.Zero;
                IntPtr hwnd = RootWindow(NativeMethods.GetForegroundWindow());
                if (IsExternalCandidate(hwnd))
                {
                    if (candidate != hwnd) { candidate = hwnd; stableSince = DateTime.UtcNow; }
                    else if ((DateTime.UtcNow - stableSince).TotalMilliseconds >= 250) return hwnd;
                }
                else { candidate = IntPtr.Zero; stableSince = DateTime.MinValue; }
                Thread.Sleep(40);
            }
            return IntPtr.Zero;
        }

        private bool IsExternalCandidate(IntPtr hwnd)
        {
            if (hwnd == IntPtr.Zero || !NativeMethods.IsWindow(hwnd) || !NativeMethods.IsWindowVisible(hwnd)) return false;
            uint pid; NativeMethods.GetWindowThreadProcessId(hwnd, out pid);
            if (pid == 0 || pid == (uint)parentProcessId || pid == (uint)Process.GetCurrentProcess().Id) return false;
            string cls = WindowClass(hwnd);
            if (cls.Equals("Shell_TrayWnd", StringComparison.OrdinalIgnoreCase) || cls.Equals("Progman", StringComparison.OrdinalIgnoreCase) || cls.Equals("WorkerW", StringComparison.OrdinalIgnoreCase) || cls.Equals("CabinetWClass", StringComparison.OrdinalIgnoreCase)) return false;
            return true;
        }

        private static string WindowClass(IntPtr hwnd)
        {
            StringBuilder builder = new StringBuilder(256);
            try { NativeMethods.GetClassName(hwnd, builder, builder.Capacity); } catch { }
            return builder.ToString();
        }

        private bool ParentAlive()
        {
            try { Process.GetProcessById(parentProcessId); return true; } catch { return false; }
        }

        private string ReadShellContext()
        {
            if ((DateTime.UtcNow - lastContextReadUtc).TotalMilliseconds < 75) return shellContext;
            lastContextReadUtc = DateTime.UtcNow;
            try
            {
                if (!String.IsNullOrWhiteSpace(stateFile) && File.Exists(stateFile))
                {
                    string value = File.ReadAllText(stateFile).Trim().ToLowerInvariant();
                    if (value == "browser-web" || value == "browser-toolbar" || value == "shell") shellContext = value;
                }
            }
            catch { }
            return shellContext;
        }

        private void TryNativeFullscreenShortcut()
        {
            if (nativeFullscreenAttempted || targetWindow == IntPtr.Zero) return;
            nativeFullscreenAttempted = true;
            string cls = WindowClass(targetWindow);
            bool uwp = cls.IndexOf("ApplicationFrameWindow", StringComparison.OrdinalIgnoreCase) >= 0 || cls.IndexOf("Windows.UI.Core", StringComparison.OrdinalIgnoreCase) >= 0;
            if (uwp)
            {
                NativeMethods.keybd_event(NativeMethods.VK_LWIN, 0, 0, UIntPtr.Zero);
                NativeMethods.keybd_event(NativeMethods.VK_SHIFT, 0, 0, UIntPtr.Zero);
                NativeMethods.keybd_event(NativeMethods.VK_RETURN, 0, 0, UIntPtr.Zero);
                NativeMethods.keybd_event(NativeMethods.VK_RETURN, 0, NativeMethods.KEYEVENTF_KEYUP, UIntPtr.Zero);
                NativeMethods.keybd_event(NativeMethods.VK_SHIFT, 0, NativeMethods.KEYEVENTF_KEYUP, UIntPtr.Zero);
                NativeMethods.keybd_event(NativeMethods.VK_LWIN, 0, NativeMethods.KEYEVENTF_KEYUP, UIntPtr.Zero);
            }
            else
            {
                NativeMethods.keybd_event(NativeMethods.VK_F11, 0, 0, UIntPtr.Zero);
                NativeMethods.keybd_event(NativeMethods.VK_F11, 0, NativeMethods.KEYEVENTF_KEYUP, UIntPtr.Zero);
            }
            Thread.Sleep(180);
        }

        private void ApplyFullscreen()
        {
            if (mode != "streaming" || targetWindow == IntPtr.Zero || !NativeMethods.IsWindow(targetWindow)) return;
            targetWindow = RootWindow(targetWindow);
            TryNativeFullscreenShortcut();
            if (!fullscreenApplied)
            {
                originalStyle = NativeMethods.GetWindowLongValue(targetWindow, NativeMethods.GWL_STYLE);
                originalExStyle = NativeMethods.GetWindowLongValue(targetWindow, NativeMethods.GWL_EXSTYLE);
                NativeMethods.GetWindowRect(targetWindow, out originalRect);
            }

            long style = NativeMethods.GetWindowLongValue(targetWindow, NativeMethods.GWL_STYLE);
            style &= ~(NativeMethods.WS_CAPTION | NativeMethods.WS_THICKFRAME | NativeMethods.WS_MINIMIZEBOX | NativeMethods.WS_MAXIMIZEBOX | NativeMethods.WS_SYSMENU);
            style |= NativeMethods.WS_POPUP;
            NativeMethods.SetWindowLongValue(targetWindow, NativeMethods.GWL_STYLE, style);

            long exStyle = NativeMethods.GetWindowLongValue(targetWindow, NativeMethods.GWL_EXSTYLE);
            exStyle &= ~(NativeMethods.WS_EX_DLGMODALFRAME | NativeMethods.WS_EX_WINDOWEDGE | NativeMethods.WS_EX_CLIENTEDGE | NativeMethods.WS_EX_STATICEDGE);
            NativeMethods.SetWindowLongValue(targetWindow, NativeMethods.GWL_EXSTYLE, exStyle);

            int ncPolicy = NativeMethods.DWMNCRP_DISABLED;
            int corners = NativeMethods.DWMWCP_DONOTROUND;
            try { NativeMethods.DwmSetWindowAttribute(targetWindow, NativeMethods.DWMWA_NCRENDERING_POLICY, ref ncPolicy, sizeof(int)); } catch { }
            try { NativeMethods.DwmSetWindowAttribute(targetWindow, NativeMethods.DWMWA_WINDOW_CORNER_PREFERENCE, ref corners, sizeof(int)); } catch { }

            IntPtr monitor = NativeMethods.MonitorFromWindow(targetWindow, NativeMethods.MONITOR_DEFAULTTONEAREST);
            NativeMethods.MONITORINFO info = new NativeMethods.MONITORINFO();
            info.cbSize = Marshal.SizeOf(typeof(NativeMethods.MONITORINFO));
            if (monitor != IntPtr.Zero && NativeMethods.GetMonitorInfo(monitor, ref info))
            {
                NativeMethods.RECT rect = info.rcMonitor;
                NativeMethods.SetWindowPos(targetWindow, NativeMethods.HWND_TOP, rect.Left, rect.Top, rect.Right - rect.Left, rect.Bottom - rect.Top,
                    NativeMethods.SWP_FRAMECHANGED | NativeMethods.SWP_SHOWWINDOW | NativeMethods.SWP_NOSENDCHANGING);
            }
            fullscreenApplied = true;
            lastFullscreenRefreshUtc = DateTime.UtcNow;
        }

        private void RestoreFullscreen()
        {
            if (!fullscreenApplied || targetWindow == IntPtr.Zero || !NativeMethods.IsWindow(targetWindow)) return;
            try
            {
                int ncPolicy = NativeMethods.DWMNCRP_USEWINDOWSTYLE;
                NativeMethods.DwmSetWindowAttribute(targetWindow, NativeMethods.DWMWA_NCRENDERING_POLICY, ref ncPolicy, sizeof(int));
                NativeMethods.SetWindowLongValue(targetWindow, NativeMethods.GWL_STYLE, originalStyle);
                NativeMethods.SetWindowLongValue(targetWindow, NativeMethods.GWL_EXSTYLE, originalExStyle);
                NativeMethods.SetWindowPos(targetWindow, NativeMethods.HWND_TOP, originalRect.Left, originalRect.Top,
                    Math.Max(1, originalRect.Right - originalRect.Left), Math.Max(1, originalRect.Bottom - originalRect.Top),
                    NativeMethods.SWP_FRAMECHANGED | NativeMethods.SWP_SHOWWINDOW | NativeMethods.SWP_NOSENDCHANGING);
            }
            catch { }
            fullscreenApplied = false;
        }

        private static double CurveAxis(double value)
        {
            const double deadzone = 0.14;
            double magnitude = Math.Abs(value);
            if (magnitude <= deadzone) return 0.0;
            double normalized = Math.Min(1.0, (magnitude - deadzone) / (1.0 - deadzone));
            double curved = Math.Pow(normalized, 1.65);
            return value < 0.0 ? -curved : curved;
        }

        private bool IsKeyboardHost(uint pid)
        {
            try
            {
                string name = Process.GetProcessById((int)pid).ProcessName ?? String.Empty;
                return name.Equals("TabTip", StringComparison.OrdinalIgnoreCase) || name.Equals("TextInputHost", StringComparison.OrdinalIgnoreCase) || name.Equals("osk", StringComparison.OrdinalIgnoreCase);
            }
            catch { return false; }
        }

        private bool DetermineOwnership(out IntPtr activeWindow, out bool controllerPointer)
        {
            activeWindow = RootWindow(NativeMethods.GetForegroundWindow());
            controllerPointer = false;
            if (activeWindow == IntPtr.Zero) return false;
            uint pid; NativeMethods.GetWindowThreadProcessId(activeWindow, out pid);
            if (mode == "shell")
            {
                if (pid != (uint)parentProcessId) return false;
                controllerPointer = ReadShellContext() == "browser-web";
                return true;
            }
            if (mode == "streaming")
            {
                if (pid == targetProcessId) { controllerPointer = true; return true; }
                if (IsKeyboardHost(pid)) { controllerPointer = true; return true; }
                return false;
            }
            return false;
        }

        private void OnTick(object sender, EventArgs e)
        {
            if (!ParentAlive()) { ExitThread(); return; }
            if (mode == "streaming" && (targetWindow == IntPtr.Zero || !NativeMethods.IsWindow(targetWindow))) { ExitThread(); return; }

            long nowTicks = clock.ElapsedTicks;
            double dt = (double)(nowTicks - lastTicks) / Stopwatch.Frequency;
            lastTicks = nowTicks;
            if (dt <= 0.0 || dt > 0.10) dt = 0.008;

            IntPtr activeWindow;
            bool controllerPointer;
            bool owns = DetermineOwnership(out activeWindow, out controllerPointer);
            if (!owns)
            {
                if (cursorOwned) { GoldSystemCursor.Restore(); cursorOwned = false; }
                lastButtons = 0;
                return;
            }
            if (!cursorOwned) { GoldSystemCursor.Apply(); cursorOwned = true; }

            if (mode == "streaming" && (DateTime.UtcNow - lastFullscreenRefreshUtc).TotalMilliseconds >= 750) ApplyFullscreen();

            NativeMethods.POINT current;
            if (NativeMethods.GetCursorPos(out current)) { cursorX = current.X; cursorY = current.Y; }
            if (!controllerPointer) { lastButtons = 0; return; }

            float lx, ly, rx, ry, lt, rt;
            uint buttons;
            if (NativeMethods.HC_ReadGamepadPointerState(out lx, out ly, out rx, out ry, out lt, out rt, out buttons) == 0) { lastButtons = 0; return; }

            double rawX = lx;
            double rawY = ly;
            double magnitude = Math.Sqrt(rawX * rawX + rawY * rawY);
            double moveX = 0.0;
            double moveY = 0.0;
            if (magnitude > 0.14)
            {
                double normalized = Math.Min(1.0, (magnitude - 0.14) / (1.0 - 0.14));
                double curved = Math.Pow(normalized, 1.55);
                moveX = (rawX / magnitude) * curved;
                moveY = (rawY / magnitude) * curved;
            }
            if (Math.Abs(moveX) > 0.0001 || Math.Abs(moveY) > 0.0001)
            {
                double maxPixelsPerSecond = 1500.0 * speedPercent / 100.0;
                cursorX += moveX * maxPixelsPerSecond * dt;
                cursorY -= moveY * maxPixelsPerSecond * dt;
                Rectangle bounds = Screen.FromHandle(activeWindow).Bounds;
                cursorX = Math.Max(bounds.Left + 2, Math.Min(bounds.Right - 3, cursorX));
                cursorY = Math.Max(bounds.Top + 2, Math.Min(bounds.Bottom - 3, cursorY));
                NativeMethods.SetCursorPos((int)Math.Round(cursorX), (int)Math.Round(cursorY));
            }

            double sx = CurveAxis(rx);
            double sy = CurveAxis(ry);
            wheelAccumulator += sy * 1100.0 * dt;
            horizontalWheelAccumulator += sx * 900.0 * dt;
            while (wheelAccumulator >= 120.0) { NativeMethods.mouse_event(NativeMethods.MOUSEEVENTF_WHEEL, 0, 0, 120, UIntPtr.Zero); wheelAccumulator -= 120.0; }
            while (wheelAccumulator <= -120.0) { NativeMethods.mouse_event(NativeMethods.MOUSEEVENTF_WHEEL, 0, 0, -120, UIntPtr.Zero); wheelAccumulator += 120.0; }
            while (horizontalWheelAccumulator >= 120.0) { NativeMethods.mouse_event(NativeMethods.MOUSEEVENTF_HWHEEL, 0, 0, 120, UIntPtr.Zero); horizontalWheelAccumulator -= 120.0; }
            while (horizontalWheelAccumulator <= -120.0) { NativeMethods.mouse_event(NativeMethods.MOUSEEVENTF_HWHEEL, 0, 0, -120, UIntPtr.Zero); horizontalWheelAccumulator += 120.0; }

            uint pressed = buttons & ~lastButtons;
            if ((pressed & 0x0001) != 0) LeftClick();
            if ((pressed & 0x0004) != 0) ShowOnScreenKeyboard();
            if (mode == "streaming")
            {
                if ((pressed & 0x0002) != 0) SendEscape();
                if ((pressed & 0x0010) != 0) NativeMethods.mouse_event(NativeMethods.MOUSEEVENTF_WHEEL, 0, 0, 480, UIntPtr.Zero);
                if ((pressed & 0x0020) != 0) NativeMethods.mouse_event(NativeMethods.MOUSEEVENTF_WHEEL, 0, 0, -480, UIntPtr.Zero);
            }
            lastButtons = buttons;
        }

        private static void LeftClick()
        {
            NativeMethods.mouse_event(NativeMethods.MOUSEEVENTF_LEFTDOWN, 0, 0, 0, UIntPtr.Zero);
            NativeMethods.mouse_event(NativeMethods.MOUSEEVENTF_LEFTUP, 0, 0, 0, UIntPtr.Zero);
        }

        private static void SendEscape()
        {
            NativeMethods.keybd_event(NativeMethods.VK_ESCAPE, 0, 0, UIntPtr.Zero);
            NativeMethods.keybd_event(NativeMethods.VK_ESCAPE, 0, NativeMethods.KEYEVENTF_KEYUP, UIntPtr.Zero);
        }

        private static void ShowOnScreenKeyboard()
        {
            try
            {
                string common = Environment.GetFolderPath(Environment.SpecialFolder.CommonProgramFiles);
                string tabTip = Path.Combine(common, "microsoft shared", "ink", "TabTip.exe");
                if (File.Exists(tabTip)) { Process.Start(new ProcessStartInfo(tabTip) { UseShellExecute = true }); return; }
            }
            catch { }
            try { Process.Start(new ProcessStartInfo("osk.exe") { UseShellExecute = true }); } catch { }
        }

        protected override void ExitThreadCore()
        {
            try { timer.Stop(); } catch { }
            try { if (cursorOwned) GoldSystemCursor.Restore(); } catch { }
            try { RestoreFullscreen(); } catch { }
            try { NativeMethods.HC_GameInputShutdown(); } catch { }
            base.ExitThreadCore();
        }
    }

    internal static class Program
    {
        [STAThread]
        private static void Main(string[] args)
        {
            int parentPid = 0;
            int speed = 100;
            string mode = "shell";
            string stateFile = String.Empty;
            for (int i = 0; i < args.Length; i++)
            {
                if (String.Equals(args[i], "--parent", StringComparison.OrdinalIgnoreCase) && i + 1 < args.Length) Int32.TryParse(args[++i], out parentPid);
                else if (String.Equals(args[i], "--speed", StringComparison.OrdinalIgnoreCase) && i + 1 < args.Length) Int32.TryParse(args[++i], out speed);
                else if (String.Equals(args[i], "--mode", StringComparison.OrdinalIgnoreCase) && i + 1 < args.Length) mode = args[++i];
                else if (String.Equals(args[i], "--state-file", StringComparison.OrdinalIgnoreCase) && i + 1 < args.Length) stateFile = args[++i];
            }
            if (parentPid <= 0) return;
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            string mutexName = String.Equals(mode, "streaming", StringComparison.OrdinalIgnoreCase) ? "Local\\HuymaierConsole.UnifiedCursor.Streaming" : "Local\\HuymaierConsole.UnifiedCursor.Shell";
            using (Mutex mutex = new Mutex(false, mutexName))
            {
                bool acquired = false;
                try { acquired = mutex.WaitOne(0, false); } catch (AbandonedMutexException) { acquired = true; }
                if (!acquired) return;
                CursorSession session = new CursorSession(parentPid, mode, speed, stateFile);
                Application.Run(session);
                try { mutex.ReleaseMutex(); } catch { }
            }
        }
    }
}
