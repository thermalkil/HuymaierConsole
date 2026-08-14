using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;

namespace HuymaierConsole.StreamingCursor
{
    internal static class NativeMethods
    {
        internal const int GWL_STYLE = -16;
        internal const int WS_CAPTION = 0x00C00000;
        internal const int WS_THICKFRAME = 0x00040000;
        internal const int WS_MINIMIZEBOX = 0x00020000;
        internal const int WS_MAXIMIZEBOX = 0x00010000;
        internal const int WS_SYSMENU = 0x00080000;
        internal const int WS_POPUP = unchecked((int)0x80000000);
        internal const uint SWP_NOOWNERZORDER = 0x0200;
        internal const uint SWP_FRAMECHANGED = 0x0020;
        internal const uint SWP_SHOWWINDOW = 0x0040;
        internal const uint MONITOR_DEFAULTTONEAREST = 2;
        internal const int SW_RESTORE = 9;
        internal const uint MOUSEEVENTF_LEFTDOWN = 0x0002;
        internal const uint MOUSEEVENTF_LEFTUP = 0x0004;
        internal const uint MOUSEEVENTF_WHEEL = 0x0800;
        internal const uint MOUSEEVENTF_HWHEEL = 0x01000;
        internal const byte VK_ESCAPE = 0x1B;
        internal const uint KEYEVENTF_KEYUP = 0x0002;

        [StructLayout(LayoutKind.Sequential)]
        internal struct POINT { internal int X; internal int Y; }

        [StructLayout(LayoutKind.Sequential)]
        internal struct RECT { internal int Left; internal int Top; internal int Right; internal int Bottom; }

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
        internal struct MONITORINFO
        {
            internal int cbSize;
            internal RECT rcMonitor;
            internal RECT rcWork;
            internal uint dwFlags;
        }

        [DllImport("HuymaierGameInputBridge.dll", CallingConvention = CallingConvention.Cdecl)]
        internal static extern int HC_GameInputInitialize();

        [DllImport("HuymaierGameInputBridge.dll", CallingConvention = CallingConvention.Cdecl)]
        internal static extern int HC_ReadGamepadPointerState(
            out float leftX,
            out float leftY,
            out float rightX,
            out float rightY,
            out float leftTrigger,
            out float rightTrigger,
            out uint buttons);

        [DllImport("HuymaierGameInputBridge.dll", CallingConvention = CallingConvention.Cdecl)]
        internal static extern void HC_GameInputShutdown();

        [DllImport("user32.dll")]
        internal static extern IntPtr GetForegroundWindow();

        [DllImport("user32.dll")]
        internal static extern bool IsWindow(IntPtr hwnd);

        [DllImport("user32.dll")]
        internal static extern bool IsWindowVisible(IntPtr hwnd);

        [DllImport("user32.dll")]
        internal static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint processId);

        [DllImport("user32.dll")]
        internal static extern bool GetWindowRect(IntPtr hwnd, out RECT rect);

        [DllImport("user32.dll")]
        internal static extern int GetWindowLong(IntPtr hwnd, int index);

        [DllImport("user32.dll")]
        internal static extern int SetWindowLong(IntPtr hwnd, int index, int value);

        [DllImport("user32.dll")]
        internal static extern bool SetWindowPos(IntPtr hwnd, IntPtr insertAfter, int x, int y, int cx, int cy, uint flags);

        [DllImport("user32.dll")]
        internal static extern bool ShowWindow(IntPtr hwnd, int command);

        [DllImport("user32.dll")]
        internal static extern IntPtr MonitorFromWindow(IntPtr hwnd, uint flags);

        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        internal static extern int GetClassName(IntPtr hwnd, System.Text.StringBuilder builder, int maxCount);

        [DllImport("user32.dll")]
        internal static extern bool GetCursorPos(out POINT point);

        [DllImport("user32.dll")]
        internal static extern bool SetCursorPos(int x, int y);

        [DllImport("user32.dll")]
        internal static extern void mouse_event(uint flags, uint dx, uint dy, int data, UIntPtr extraInfo);

        [DllImport("user32.dll")]
        internal static extern void keybd_event(byte virtualKey, byte scanCode, uint flags, UIntPtr extraInfo);

        [DllImport("user32.dll", CharSet = CharSet.Auto)]
        internal static extern bool GetMonitorInfo(IntPtr monitor, ref MONITORINFO info);
    }

    internal sealed class CursorOverlay : Form
    {
        private readonly Pen outerPen;
        private readonly Pen innerPen;
        private readonly Brush centerBrush;

        internal CursorOverlay()
        {
            FormBorderStyle = FormBorderStyle.None;
            ShowInTaskbar = false;
            TopMost = true;
            StartPosition = FormStartPosition.Manual;
            Width = 38;
            Height = 38;
            BackColor = Color.Magenta;
            TransparencyKey = Color.Magenta;
            outerPen = new Pen(Color.FromArgb(245, 240, 204, 88), 3.0f);
            innerPen = new Pen(Color.FromArgb(220, 8, 13, 20), 2.0f);
            centerBrush = new SolidBrush(Color.FromArgb(255, 255, 243, 166));
        }

        protected override bool ShowWithoutActivation { get { return true; } }

        protected override CreateParams CreateParams
        {
            get
            {
                const int WS_EX_TRANSPARENT = 0x20;
                const int WS_EX_TOOLWINDOW = 0x80;
                const int WS_EX_NOACTIVATE = 0x08000000;
                CreateParams cp = base.CreateParams;
                cp.ExStyle |= WS_EX_TRANSPARENT | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE;
                return cp;
            }
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            base.OnPaint(e);
            e.Graphics.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
            e.Graphics.DrawEllipse(innerPen, 4, 4, 29, 29);
            e.Graphics.DrawEllipse(outerPen, 6, 6, 25, 25);
            e.Graphics.FillEllipse(centerBrush, 16, 16, 6, 6);
        }

        internal void MoveCenter(int x, int y)
        {
            Location = new Point(x - Width / 2, y - Height / 2);
        }
    }

    internal sealed class StreamingCursorSession : ApplicationContext
    {
        private readonly int parentProcessId;
        private readonly int speedPercent;
        private readonly CursorOverlay overlay;
        private readonly System.Windows.Forms.Timer timer;
        private readonly Stopwatch clock;
        private IntPtr targetWindow;
        private uint targetProcessId;
        private int originalStyle;
        private NativeMethods.RECT originalRect;
        private bool fullscreenApplied;
        private bool pointerActive;
        private double cursorX;
        private double cursorY;
        private uint lastButtons;
        private double wheelAccumulator;
        private double horizontalWheelAccumulator;
        private long lastTicks;
        private DateTime lastFullscreenRefreshUtc;

        internal StreamingCursorSession(int parentPid, int speed)
        {
            parentProcessId = parentPid;
            speedPercent = Math.Max(40, Math.Min(200, speed));
            overlay = new CursorOverlay();
            timer = new System.Windows.Forms.Timer();
            timer.Interval = 8;
            timer.Tick += OnTick;
            clock = Stopwatch.StartNew();
            lastTicks = clock.ElapsedTicks;

            if (NativeMethods.HC_GameInputInitialize() == 0)
            {
                ExitThread();
                return;
            }

            targetWindow = WaitForStreamingWindow();
            if (targetWindow == IntPtr.Zero)
            {
                NativeMethods.HC_GameInputShutdown();
                ExitThread();
                return;
            }

            NativeMethods.GetWindowThreadProcessId(targetWindow, out targetProcessId);
            NativeMethods.POINT point;
            if (NativeMethods.GetCursorPos(out point))
            {
                cursorX = point.X;
                cursorY = point.Y;
            }
            else
            {
                Rectangle screen = Screen.FromHandle(targetWindow).Bounds;
                cursorX = screen.Left + screen.Width / 2.0;
                cursorY = screen.Top + screen.Height / 2.0;
            }

            ApplyFullscreen();
            overlay.MoveCenter((int)Math.Round(cursorX), (int)Math.Round(cursorY));
            overlay.Show();
            pointerActive = true;
            timer.Start();
        }

        private IntPtr WaitForStreamingWindow()
        {
            DateTime deadline = DateTime.UtcNow.AddSeconds(20);
            IntPtr lastCandidate = IntPtr.Zero;
            DateTime candidateSince = DateTime.MinValue;
            while (DateTime.UtcNow < deadline)
            {
                IntPtr hwnd = NativeMethods.GetForegroundWindow();
                if (IsCandidateWindow(hwnd))
                {
                    if (hwnd != lastCandidate)
                    {
                        lastCandidate = hwnd;
                        candidateSince = DateTime.UtcNow;
                    }
                    else if ((DateTime.UtcNow - candidateSince).TotalMilliseconds >= 250)
                    {
                        return hwnd;
                    }
                }
                else
                {
                    lastCandidate = IntPtr.Zero;
                    candidateSince = DateTime.MinValue;
                }
                Thread.Sleep(50);
            }
            return IntPtr.Zero;
        }

        private bool IsCandidateWindow(IntPtr hwnd)
        {
            if (hwnd == IntPtr.Zero || !NativeMethods.IsWindow(hwnd) || !NativeMethods.IsWindowVisible(hwnd)) return false;
            uint pid;
            NativeMethods.GetWindowThreadProcessId(hwnd, out pid);
            if (pid == 0 || pid == (uint)parentProcessId || pid == (uint)Process.GetCurrentProcess().Id) return false;
            string className = GetWindowClass(hwnd);
            if (className.Equals("Shell_TrayWnd", StringComparison.OrdinalIgnoreCase) ||
                className.Equals("Progman", StringComparison.OrdinalIgnoreCase) ||
                className.Equals("WorkerW", StringComparison.OrdinalIgnoreCase) ||
                className.Equals("CabinetWClass", StringComparison.OrdinalIgnoreCase)) return false;
            return true;
        }

        private static string GetWindowClass(IntPtr hwnd)
        {
            System.Text.StringBuilder builder = new System.Text.StringBuilder(256);
            try { NativeMethods.GetClassName(hwnd, builder, builder.Capacity); } catch { }
            return builder.ToString();
        }

        private void ApplyFullscreen()
        {
            if (targetWindow == IntPtr.Zero || !NativeMethods.IsWindow(targetWindow)) return;
            if (!fullscreenApplied)
            {
                originalStyle = NativeMethods.GetWindowLong(targetWindow, NativeMethods.GWL_STYLE);
                NativeMethods.GetWindowRect(targetWindow, out originalRect);
            }

            int style = NativeMethods.GetWindowLong(targetWindow, NativeMethods.GWL_STYLE);
            style &= ~(NativeMethods.WS_CAPTION | NativeMethods.WS_THICKFRAME | NativeMethods.WS_MINIMIZEBOX | NativeMethods.WS_MAXIMIZEBOX | NativeMethods.WS_SYSMENU);
            style |= NativeMethods.WS_POPUP;
            NativeMethods.SetWindowLong(targetWindow, NativeMethods.GWL_STYLE, style);

            IntPtr monitor = NativeMethods.MonitorFromWindow(targetWindow, NativeMethods.MONITOR_DEFAULTTONEAREST);
            NativeMethods.MONITORINFO info = new NativeMethods.MONITORINFO();
            info.cbSize = Marshal.SizeOf(typeof(NativeMethods.MONITORINFO));
            if (monitor != IntPtr.Zero && NativeMethods.GetMonitorInfo(monitor, ref info))
            {
                NativeMethods.RECT rect = info.rcMonitor;
                NativeMethods.ShowWindow(targetWindow, NativeMethods.SW_RESTORE);
                NativeMethods.SetWindowPos(targetWindow, IntPtr.Zero, rect.Left, rect.Top, rect.Right - rect.Left, rect.Bottom - rect.Top,
                    NativeMethods.SWP_NOOWNERZORDER | NativeMethods.SWP_FRAMECHANGED | NativeMethods.SWP_SHOWWINDOW);
            }
            fullscreenApplied = true;
            lastFullscreenRefreshUtc = DateTime.UtcNow;
        }

        private void RestoreWindow()
        {
            if (!fullscreenApplied || targetWindow == IntPtr.Zero || !NativeMethods.IsWindow(targetWindow)) return;
            try
            {
                NativeMethods.SetWindowLong(targetWindow, NativeMethods.GWL_STYLE, originalStyle);
                NativeMethods.SetWindowPos(targetWindow, IntPtr.Zero, originalRect.Left, originalRect.Top,
                    Math.Max(1, originalRect.Right - originalRect.Left), Math.Max(1, originalRect.Bottom - originalRect.Top),
                    NativeMethods.SWP_NOOWNERZORDER | NativeMethods.SWP_FRAMECHANGED | NativeMethods.SWP_SHOWWINDOW);
            }
            catch { }
            fullscreenApplied = false;
        }

        private static double ApplyDeadzoneCurve(double value)
        {
            const double deadzone = 0.14;
            double magnitude = Math.Abs(value);
            if (magnitude <= deadzone) return 0.0;
            double normalized = Math.Min(1.0, (magnitude - deadzone) / (1.0 - deadzone));
            double curved = Math.Pow(normalized, 1.65);
            return value < 0.0 ? -curved : curved;
        }

        private void OnTick(object sender, EventArgs e)
        {
            if (targetWindow == IntPtr.Zero || !NativeMethods.IsWindow(targetWindow))
            {
                ExitThread();
                return;
            }

            long nowTicks = clock.ElapsedTicks;
            double dt = (double)(nowTicks - lastTicks) / Stopwatch.Frequency;
            lastTicks = nowTicks;
            if (dt <= 0.0 || dt > 0.1) dt = 0.008;

            bool foregroundAllowed = IsPointerForegroundAllowed();
            if (!foregroundAllowed)
            {
                if (pointerActive) { overlay.Hide(); pointerActive = false; }
                lastButtons = 0;
                return;
            }
            if (!pointerActive) { overlay.Show(); pointerActive = true; }

            if ((DateTime.UtcNow - lastFullscreenRefreshUtc).TotalSeconds >= 1.0) ApplyFullscreen();

            float lx, ly, rx, ry, lt, rt;
            uint buttons;
            if (NativeMethods.HC_ReadGamepadPointerState(out lx, out ly, out rx, out ry, out lt, out rt, out buttons) == 0)
            {
                lastButtons = 0;
                return;
            }

            double moveX = ApplyDeadzoneCurve(lx);
            double moveY = ApplyDeadzoneCurve(ly);
            double maxPixelsPerSecond = 1500.0 * speedPercent / 100.0;
            bool stickMoving = Math.Abs(moveX) > 0.0001 || Math.Abs(moveY) > 0.0001;

            NativeMethods.POINT physical;
            if (!stickMoving && NativeMethods.GetCursorPos(out physical))
            {
                if (Math.Abs(physical.X - cursorX) > 3.0 || Math.Abs(physical.Y - cursorY) > 3.0)
                {
                    cursorX = physical.X;
                    cursorY = physical.Y;
                }
            }

            if (stickMoving)
            {
                cursorX += moveX * maxPixelsPerSecond * dt;
                cursorY -= moveY * maxPixelsPerSecond * dt;
                Rectangle bounds = Screen.FromHandle(targetWindow).Bounds;
                cursorX = Math.Max(bounds.Left + 2, Math.Min(bounds.Right - 3, cursorX));
                cursorY = Math.Max(bounds.Top + 2, Math.Min(bounds.Bottom - 3, cursorY));
                NativeMethods.SetCursorPos((int)Math.Round(cursorX), (int)Math.Round(cursorY));
            }
            overlay.MoveCenter((int)Math.Round(cursorX), (int)Math.Round(cursorY));

            HandleScrolling(rx, ry, dt);
            uint pressed = buttons & ~lastButtons;
            if ((pressed & 0x0001) != 0) LeftClick();
            if ((pressed & 0x0002) != 0) SendEscape();
            if ((pressed & 0x0004) != 0) ShowOnScreenKeyboard();
            if ((pressed & 0x0010) != 0) NativeMethods.mouse_event(NativeMethods.MOUSEEVENTF_WHEEL, 0, 0, 480, UIntPtr.Zero);
            if ((pressed & 0x0020) != 0) NativeMethods.mouse_event(NativeMethods.MOUSEEVENTF_WHEEL, 0, 0, -480, UIntPtr.Zero);
            lastButtons = buttons;
        }

        private bool IsPointerForegroundAllowed()
        {
            IntPtr foreground = NativeMethods.GetForegroundWindow();
            if (foreground == IntPtr.Zero) return false;
            uint pid;
            NativeMethods.GetWindowThreadProcessId(foreground, out pid);
            if (pid == (uint)parentProcessId) return false;
            if (pid == targetProcessId) return true;
            try
            {
                Process process = Process.GetProcessById((int)pid);
                string name = process.ProcessName ?? String.Empty;
                if (name.Equals("TabTip", StringComparison.OrdinalIgnoreCase) ||
                    name.Equals("TextInputHost", StringComparison.OrdinalIgnoreCase) ||
                    name.Equals("osk", StringComparison.OrdinalIgnoreCase)) return true;
            }
            catch { }
            return false;
        }

        private void HandleScrolling(float rightX, float rightY, double dt)
        {
            double sx = ApplyDeadzoneCurve(rightX);
            double sy = ApplyDeadzoneCurve(rightY);
            wheelAccumulator += sy * 1100.0 * dt;
            horizontalWheelAccumulator += sx * 900.0 * dt;
            while (wheelAccumulator >= 120.0) { NativeMethods.mouse_event(NativeMethods.MOUSEEVENTF_WHEEL, 0, 0, 120, UIntPtr.Zero); wheelAccumulator -= 120.0; }
            while (wheelAccumulator <= -120.0) { NativeMethods.mouse_event(NativeMethods.MOUSEEVENTF_WHEEL, 0, 0, -120, UIntPtr.Zero); wheelAccumulator += 120.0; }
            while (horizontalWheelAccumulator >= 120.0) { NativeMethods.mouse_event(NativeMethods.MOUSEEVENTF_HWHEEL, 0, 0, 120, UIntPtr.Zero); horizontalWheelAccumulator -= 120.0; }
            while (horizontalWheelAccumulator <= -120.0) { NativeMethods.mouse_event(NativeMethods.MOUSEEVENTF_HWHEEL, 0, 0, -120, UIntPtr.Zero); horizontalWheelAccumulator += 120.0; }
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
                if (File.Exists(tabTip))
                {
                    Process.Start(new ProcessStartInfo(tabTip) { UseShellExecute = true });
                    return;
                }
            }
            catch { }
            try { Process.Start(new ProcessStartInfo("osk.exe") { UseShellExecute = true }); } catch { }
        }

        protected override void ExitThreadCore()
        {
            try { timer.Stop(); } catch { }
            try { overlay.Hide(); overlay.Close(); } catch { }
            try { RestoreWindow(); } catch { }
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
            for (int i = 0; i < args.Length; i++)
            {
                if (String.Equals(args[i], "--parent", StringComparison.OrdinalIgnoreCase) && i + 1 < args.Length) Int32.TryParse(args[++i], out parentPid);
                else if (String.Equals(args[i], "--speed", StringComparison.OrdinalIgnoreCase) && i + 1 < args.Length) Int32.TryParse(args[++i], out speed);
            }
            if (parentPid <= 0) return;
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            using (Mutex mutex = new Mutex(false, "Local\\HuymaierConsole.StreamingCursor"))
            {
                bool acquired = false;
                try { acquired = mutex.WaitOne(0, false); } catch (AbandonedMutexException) { acquired = true; }
                if (!acquired) return;
                StreamingCursorSession session = new StreamingCursorSession(parentPid, speed);
                Application.Run(session);
                try { mutex.ReleaseMutex(); } catch { }
            }
        }
    }
}
