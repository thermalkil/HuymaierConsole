from pathlib import Path


def read(path):
    return Path(path).read_text(encoding='utf-8-sig')


def write(path, text, bom=False):
    Path(path).write_text(text, encoding='utf-8-sig' if bom else 'utf-8', newline='\n')


def replace_once(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly one match, found {count}')
    return text.replace(old, new, 1)

# ---------------------------------------------------------------------------
# Native controller ownership: while the Huymaier Game Bar is visible, every
# normal Huymaier/native-console router is modal-blocked. The Game Bar receives
# a narrowly scoped bypass only around its own navigation poll.
# ---------------------------------------------------------------------------
p = 'Native/HuymaierConsole.NativeApp.cs'
t = read(p)

old = '''        internal XmbInputCommand Poll()\n        {\n            GetCandidates();\n'''
new = '''        internal XmbInputCommand Poll()\n        {\n            // The process-wide Game Bar is modal. Native console surfaces must\n            // not react to the same D-pad/face/shoulder press underneath it.\n            if (HuymaierGameBarHost.BlocksNativeNavigation)\n            {\n                hasActiveSource = false;\n                ResetEdges();\n                return XmbInputCommand.None;\n            }\n            GetCandidates();\n'''
t = replace_once(t, old, new, 'XmbInputRouter modal ownership gate')

old = '''        public static NativeNavigationCommand Poll()\n        {\n            lock (Sync)\n            {\n                DateTime now = DateTime.UtcNow;\n'''
new = '''        public static NativeNavigationCommand Poll()\n        {\n            lock (Sync)\n            {\n                if (HuymaierGameBarHost.BlocksNativeNavigation)\n                    return new NativeNavigationCommand();\n                DateTime now = DateTime.UtcNow;\n'''
t = replace_once(t, old, new, 'NativeConsoleNavigation modal ownership gate')
write(p, t)

# ---------------------------------------------------------------------------
# Game Bar native window: explicit Win32 topmost/foreground promotion plus one
# dispatcher retry. WPF Topmost alone can leave the overlay behind a fullscreen
# or maximized surface until Alt-Tab. Also expose the Game-Bar-only navigation
# polling bypass used above.
# ---------------------------------------------------------------------------
p = 'Native/HuymaierConsole.SystemOverlay.cs'
t = read(p)

old = '''    public static class HuymaierGameBarHost\n    {\n        private static Window consoleWindow;\n        private static HuymaierGameBarWindow gameBar;\n        private static int scalePercent = 100;\n        public static bool IsVisible { get { return gameBar != null && gameBar.IsVisible; } }\n        public static void Initialize(Window mainConsoleWindow) { consoleWindow = mainConsoleWindow; }\n        public static void SetScalePercent(int value) { scalePercent = Math.Max(70, Math.Min(140, value)); if (gameBar != null) gameBar.SetScalePercent(scalePercent); }\n        public static void Show() { if (consoleWindow == null) return; if (gameBar == null) gameBar = new HuymaierGameBarWindow(consoleWindow); gameBar.SetScalePercent(scalePercent); gameBar.ShowForForegroundWindow(); }\n        public static void Hide() { if (gameBar != null) gameBar.HideBar(); }\n        public static void Toggle() { if (IsVisible) Hide(); else Show(); }\n        public static void ProcessCommand(string command) { if (gameBar == null || !gameBar.IsVisible || String.IsNullOrWhiteSpace(command)) return; gameBar.ProcessControllerCommand(command); }\n    }\n'''
new = '''    public static class HuymaierGameBarHost\n    {\n        private static Window consoleWindow;\n        private static HuymaierGameBarWindow gameBar;\n        private static int scalePercent = 100;\n        [ThreadStatic] private static bool navigationPollBypass;\n        public static bool IsVisible { get { return gameBar != null && gameBar.IsVisible; } }\n        internal static bool BlocksNativeNavigation { get { return IsVisible && !navigationPollBypass; } }\n        public static void Initialize(Window mainConsoleWindow) { consoleWindow = mainConsoleWindow; }\n        public static void SetScalePercent(int value) { scalePercent = Math.Max(70, Math.Min(140, value)); if (gameBar != null) gameBar.SetScalePercent(scalePercent); }\n        public static void Show() { if (consoleWindow == null) return; if (gameBar == null) gameBar = new HuymaierGameBarWindow(consoleWindow); gameBar.SetScalePercent(scalePercent); gameBar.ShowForForegroundWindow(); }\n        public static void Hide() { if (gameBar != null) gameBar.HideBar(); }\n        public static void Toggle() { if (IsVisible) Hide(); else Show(); }\n        public static NativeNavigationCommand PollNavigation()\n        {\n            navigationPollBypass = true;\n            try { return NativeConsoleNavigation.Poll(); }\n            finally { navigationPollBypass = false; }\n        }\n        public static void ProcessCommand(string command) { if (gameBar == null || !gameBar.IsVisible || String.IsNullOrWhiteSpace(command)) return; gameBar.ProcessControllerCommand(command); }\n    }\n'''
t = replace_once(t, old, new, 'Game Bar host modal poll bypass')

old = '''    internal sealed class HuymaierGameBarWindow : Window\n    {\n        private const int PageHome = 0;\n'''
new = '''    internal sealed class HuymaierGameBarWindow : Window\n    {\n        private static readonly IntPtr HWND_TOPMOST = new IntPtr(-1);\n        private const uint SWP_NOSIZE = 0x0001;\n        private const uint SWP_NOMOVE = 0x0002;\n        private const uint SWP_SHOWWINDOW = 0x0040;\n        [DllImport("user32.dll", SetLastError = true)] private static extern bool SetWindowPos(IntPtr hWnd, IntPtr insertAfter, int x, int y, int cx, int cy, uint flags);\n        [DllImport("user32.dll")] private static extern bool BringWindowToTop(IntPtr hWnd);\n        [DllImport("user32.dll")] private static extern bool SetForegroundWindow(IntPtr hWnd);\n\n        private const int PageHome = 0;\n'''
t = replace_once(t, old, new, 'Game Bar Win32 z-order declarations')

old = '''        internal void ShowForForegroundWindow()\n        {\n            IntPtr foreground = SystemWindowCatalog.GetForegroundWindow();\n            IntPtr overlayHandle = IntPtr.Zero; try { overlayHandle = new WindowInteropHelper(this).Handle; } catch { }\n            IntPtr consoleHandle = IntPtr.Zero; try { consoleHandle = new WindowInteropHelper(consoleWindow).Handle; } catch { }\n            if (foreground != IntPtr.Zero && foreground != overlayHandle && foreground != consoleHandle) targetWindow = foreground;\n            PositionOnTargetMonitor(targetWindow);\n            page = PageHome; selected = 0; closeConfirmation = false; lastStatus = String.Empty; Refresh();\n            if (!IsVisible) Show();\n            WindowState = WindowState.Normal; Activate(); Focus(); telemetryTimer.Start();\n        }\n'''
new = '''        internal void ShowForForegroundWindow()\n        {\n            IntPtr foreground = SystemWindowCatalog.GetForegroundWindow();\n            IntPtr overlayHandle = IntPtr.Zero; try { overlayHandle = new WindowInteropHelper(this).Handle; } catch { }\n            IntPtr consoleHandle = IntPtr.Zero; try { consoleHandle = new WindowInteropHelper(consoleWindow).Handle; } catch { }\n            if (foreground != IntPtr.Zero && foreground != overlayHandle && foreground != consoleHandle) targetWindow = foreground;\n            PositionOnTargetMonitor(targetWindow);\n            page = PageHome; selected = 0; closeConfirmation = false; lastStatus = String.Empty; Refresh();\n            if (!IsVisible) Show();\n            WindowState = WindowState.Normal;\n            PromoteOverlayToFront();\n            telemetryTimer.Start();\n\n            // WPF can briefly reinsert a transparent topmost window below the\n            // previous fullscreen/maximized owner during activation. Retry after\n            // the dispatcher completes this show cycle so Alt-Tab is never needed.\n            Dispatcher.BeginInvoke(DispatcherPriority.Input, new Action(delegate\n            {\n                if (IsVisible) PromoteOverlayToFront();\n            }));\n        }\n\n        private void PromoteOverlayToFront()\n        {\n            try\n            {\n                Topmost = true;\n                IntPtr handle = new WindowInteropHelper(this).EnsureHandle();\n                if (handle != IntPtr.Zero)\n                {\n                    SetWindowPos(handle, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_SHOWWINDOW);\n                    BringWindowToTop(handle);\n                    SetForegroundWindow(handle);\n                }\n                Activate();\n                Focus();\n                IInputElement content = Content as IInputElement;\n                if (content != null) Keyboard.Focus(content);\n            }\n            catch { }\n        }\n'''
t = replace_once(t, old, new, 'Game Bar explicit topmost promotion')
write(p, t)

# PowerShell Game Bar uses the host's modal-safe poll instead of directly polling
# the shared router while the overlay is visible.
p = 'HuymaierGameBar.ps1'
t = read(p)
t = replace_once(
    t,
    '$native=[HuymaierConsole.NativeApp.NativeConsoleNavigation]::Poll()',
    '$native=[HuymaierConsole.NativeApp.HuymaierGameBarHost]::PollNavigation()',
    'Game Bar modal-safe navigation poll'
)
write(p, t, bom=True)

# ---------------------------------------------------------------------------
# Native file picker routing: a non-Browse picker must actually enter the File
# Explorer tab while preserving its caller return tab/subpage. Previously it
# could render the underlying Games/provider page immediately, which exactly
# matches the reported "choose library location -> back to Games" behavior.
# ---------------------------------------------------------------------------
p = 'HuymaierConsole.ps1'
t = read(p)
old = '''    } else {\n        $script:SubPage='FilePicker'\n        $script:SelectedAction=0\n        Render-Page\n    }\n}\n'''
new = '''    } else {\n        $script:SelectedTab=6\n        $script:SubPage='FilePicker'\n        $script:SelectedAction=0\n        Render-Page\n        Update-NavVisuals\n    }\n}\n'''
t = replace_once(t, old, new, 'native file picker tab routing')
write(p, t, bom=True)

# ---------------------------------------------------------------------------
# Candidate gates for all three real-machine regressions.
# ---------------------------------------------------------------------------
p = '.build/Test-HuymaierCandidate.ps1'
t = read(p)
anchor = '''    if($coreText -notmatch [regex]::Escape('if($SilentUpdate){return}')){throw 'Installer core does not return through the public wrapper on silent success.'}\n'''
insert = anchor + r'''

    # RC13: Game Bar must raise itself above fullscreen/maximized surfaces, own
    # Huymaier controller navigation modally while visible, and native folder
    # pickers must actually enter the File Explorer surface before returning.
    $overlay=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'Native\\HuymaierConsole.SystemOverlay.cs') -Encoding UTF8
    foreach($required in @('SetWindowPos(handle, HWND_TOPMOST','PromoteOverlayToFront()','BlocksNativeNavigation','PollNavigation()')){if($overlay -notmatch [regex]::Escape($required)){throw "Game Bar z-order/modal ownership invariant is missing: $required"}}
    $nativeApp=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'Native\\HuymaierConsole.NativeApp.cs') -Encoding UTF8
    $modalGateCount=([regex]::Matches($nativeApp,[regex]::Escape('HuymaierGameBarHost.BlocksNativeNavigation'))).Count
    if($modalGateCount -lt 2){throw 'Game Bar modal ownership is not enforced in both native router layers.'}
    if($gameBar -notmatch [regex]::Escape('[HuymaierConsole.NativeApp.HuymaierGameBarHost]::PollNavigation()')){throw 'Visible Game Bar does not use its modal-safe navigation poll.'}
    $shell=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'HuymaierConsole.ps1') -Encoding UTF8
    if($shell -notmatch '(?s)else\s*\{\s*\$script:SelectedTab=6\s*\$script:SubPage=''FilePicker'''){throw 'Native non-Browse file picker does not enter the File Explorer tab.'}
'''
t = replace_once(t, anchor, insert, 'RC13 candidate gates')

validation_anchor = '''    $validation|Add-Member -NotePropertyName installerWrapperExitGate -NotePropertyValue 'success' -Force\n'''
validation_insert = validation_anchor + '''    $validation|Add-Member -NotePropertyName gameBarZOrderGate -NotePropertyValue 'success' -Force\n    $validation|Add-Member -NotePropertyName gameBarModalInputGate -NotePropertyValue 'success' -Force\n    $validation|Add-Member -NotePropertyName nativeFilePickerRoutingGate -NotePropertyValue 'success' -Force\n'''
t = replace_once(t, validation_anchor, validation_insert, 'RC13 validation fields')
write(p, t, bom=True)

print('RC13 Game Bar z-order, modal input ownership, and native file-picker routing fixes applied.')
