param(
    [Parameter(Mandatory=$true)][string]$SystemOverlayPath
)

Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
if(-not(Test-Path -LiteralPath $SystemOverlayPath -PathType Leaf)){throw "External Game Bar transform input missing: $SystemOverlayPath"}

$text=Get-Content -Raw -LiteralPath $SystemOverlayPath -Encoding UTF8
if($text -match 'HUYMAIER_EXTERNAL_GAMEBAR_OWNER_V1'){return}

$interopNeedle=@'
        private static readonly IntPtr HWND_TOPMOST = new IntPtr(-1);
        private const uint SWP_NOSIZE = 0x0001;
        private const uint SWP_NOMOVE = 0x0002;
        private const uint SWP_SHOWWINDOW = 0x0040;
        [DllImport("user32.dll", SetLastError = true)] private static extern bool SetWindowPos(IntPtr hWnd, IntPtr insertAfter, int x, int y, int cx, int cy, uint flags);
        [DllImport("user32.dll")] private static extern bool BringWindowToTop(IntPtr hWnd);
        [DllImport("user32.dll")] private static extern bool SetForegroundWindow(IntPtr hWnd);
        [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
        [DllImport("kernel32.dll")] private static extern uint GetCurrentThreadId();
        [DllImport("user32.dll")] private static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool attach);
'@
if(-not $text.Contains($interopNeedle)){throw 'External Game Bar transform could not find overlay Win32 interop block.'}
$interopBlock=@'
        private static readonly IntPtr HWND_TOPMOST = new IntPtr(-1);
        private const uint SWP_NOSIZE = 0x0001;
        private const uint SWP_NOMOVE = 0x0002;
        private const uint SWP_SHOWWINDOW = 0x0040;
        private const int GWLP_HWNDPARENT = -8;
        [DllImport("user32.dll", SetLastError = true)] private static extern bool SetWindowPos(IntPtr hWnd, IntPtr insertAfter, int x, int y, int cx, int cy, uint flags);
        [DllImport("user32.dll")] private static extern bool BringWindowToTop(IntPtr hWnd);
        [DllImport("user32.dll")] private static extern bool SetForegroundWindow(IntPtr hWnd);
        [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
        [DllImport("kernel32.dll")] private static extern uint GetCurrentThreadId();
        [DllImport("user32.dll")] private static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool attach);
        [DllImport("user32.dll", EntryPoint = "SetWindowLongPtrW", SetLastError = true)] private static extern IntPtr SetWindowLongPtr64(IntPtr hWnd, int index, IntPtr newValue);
        [DllImport("user32.dll", EntryPoint = "SetWindowLongW", SetLastError = true)] private static extern int SetWindowLong32(IntPtr hWnd, int index, int newValue);
'@
$text=$text.Replace($interopNeedle,$interopBlock)

$fieldNeedle='        private int scalePercent;'
if(-not $text.Contains($fieldNeedle)){throw 'External Game Bar transform could not find overlay state fields.'}
$fieldBlock=@'
        private int scalePercent;
        // HUYMAIER_EXTERNAL_GAMEBAR_OWNER_V1
        // A native Store/UWP app can own foreground focus without giving an
        // unrelated WPF topmost window reliable z-order. Temporarily make the
        // Game Bar an owned top-level window of the foreground app while visible.
        private IntPtr externalOwnerWindow;
'@
$text=$text.Replace($fieldNeedle,$fieldBlock)

$promoteNeedle=@'
                if (handle != IntPtr.Zero)
                {
                    IntPtr foreground = SystemWindowCatalog.GetForegroundWindow();
                    uint foregroundPid;
'@
if(-not $text.Contains($promoteNeedle)){throw 'External Game Bar transform could not find PromoteOverlayToFront handle block.'}
$promoteBlock=@'
                if (handle != IntPtr.Zero)
                {
                    AttachExternalOwner(handle, targetWindow);
                    IntPtr foreground = SystemWindowCatalog.GetForegroundWindow();
                    uint foregroundPid;
'@
$text=$text.Replace($promoteNeedle,$promoteBlock)

$methodNeedle=@'
        internal void SetScalePercent(int value)
        {
'@
if(-not $text.Contains($methodNeedle)){throw 'External Game Bar transform could not find SetScalePercent boundary.'}
$ownerMethods=@'
        private static IntPtr SetWindowOwner(IntPtr handle, IntPtr owner)
        {
            if (IntPtr.Size == 8) return SetWindowLongPtr64(handle, GWLP_HWNDPARENT, owner);
            int previous = SetWindowLong32(handle, GWLP_HWNDPARENT, owner.ToInt32());
            return new IntPtr(previous);
        }

        private void AttachExternalOwner(IntPtr overlayHandle, IntPtr owner)
        {
            try
            {
                if (overlayHandle == IntPtr.Zero || owner == IntPtr.Zero || owner == overlayHandle) return;
                IntPtr consoleHandle = IntPtr.Zero;
                try { consoleHandle = new WindowInteropHelper(consoleWindow).Handle; } catch { }
                if (owner == consoleHandle) { DetachExternalOwner(); return; }
                if (externalOwnerWindow == owner) return;
                if (externalOwnerWindow != IntPtr.Zero) DetachExternalOwner();
                SetWindowOwner(overlayHandle, owner);
                externalOwnerWindow = owner;
            }
            catch { externalOwnerWindow = IntPtr.Zero; }
        }

        private void DetachExternalOwner()
        {
            if (externalOwnerWindow == IntPtr.Zero) return;
            try
            {
                IntPtr handle = new WindowInteropHelper(this).Handle;
                if (handle != IntPtr.Zero) SetWindowOwner(handle, IntPtr.Zero);
            }
            catch { }
            externalOwnerWindow = IntPtr.Zero;
        }

        internal void SetScalePercent(int value)
        {
'@
$text=$text.Replace($methodNeedle,$ownerMethods)

$hideNeedle=@'
        internal void HideBar()
        {
            DisposeTaskPreviews(); telemetryTimer.Stop();
            try { Hide(); } catch { }
            if (targetWindow != IntPtr.Zero) SystemWindowCatalog.Activate(targetWindow);
        }
'@
if(-not $text.Contains($hideNeedle)){throw 'External Game Bar transform could not find HideBar implementation.'}
$hideBlock=@'
        internal void HideBar()
        {
            DisposeTaskPreviews(); telemetryTimer.Stop();
            DetachExternalOwner();
            try { Hide(); } catch { }
            if (targetWindow != IntPtr.Zero) SystemWindowCatalog.Activate(targetWindow);
        }
'@
$text=$text.Replace($hideNeedle,$hideBlock)

Set-Content -LiteralPath $SystemOverlayPath -Value $text -Encoding UTF8
