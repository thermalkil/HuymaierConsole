from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
NATIVE_APP = ROOT / "Native" / "HuymaierConsole.NativeApp.cs"
CONSOLE_PLATFORMS = ROOT / "Native" / "HuymaierConsole.ConsolePlatforms.cs"
SHELL = ROOT / "HuymaierConsole.ps1"
WORKER = ROOT / "HuymaierNativeConsoleLibraryWorker.ps1"


def read(path):
    return path.read_text(encoding="utf-8-sig")


def write(path, text):
    path.write_text(text, encoding="utf-8")


def replace_once(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected one match, found {count}")
    return text.replace(old, new, 1)


# ---------------------------------------------------------------------------
# Shared modal-return path: do not block the shell while a native console closes.
# ---------------------------------------------------------------------------
native = read(NATIVE_APP)
activation_pattern = re.compile(
    r"    public static class NativeWindowActivation\n    \{.*?\n    \}\n\n    public sealed class NativeBridge",
    re.S,
)
match = activation_pattern.search(native)
if not match:
    raise SystemExit("NativeWindowActivation block not found")

activation = r'''    public static class NativeWindowActivation
    {
        [DllImport("user32.dll")]
        private static extern bool SetForegroundWindow(IntPtr hWnd);
        [DllImport("user32.dll")]
        private static extern bool BringWindowToTop(IntPtr hWnd);
        [DllImport("user32.dll")]
        private static extern IntPtr SetActiveWindow(IntPtr hWnd);
        [DllImport("user32.dll")]
        private static extern bool ShowWindow(IntPtr hWnd, int command);

        private static readonly object ModalSync = new object();
        private static bool modalReturnGuardPending;
        private static DateTime modalReturnGuardUntilUtc = DateTime.MinValue;

        // Called before opening a Huymaier-owned modal console.  The owner window's
        // next Activated event is an expected return, not an external-app focus
        // transition, so the PowerShell shell must not impose its normal 350 ms
        // controller guard on that activation.
        public static void PrepareModalReturn(Window window)
        {
            if (window == null) return;
            lock (ModalSync)
            {
                modalReturnGuardPending = true;
                modalReturnGuardUntilUtc = DateTime.UtcNow.AddSeconds(4);
            }
        }

        public static bool ConsumeModalReturnActivationGuard()
        {
            lock (ModalSync)
            {
                if (!modalReturnGuardPending) return false;
                modalReturnGuardPending = false;
                bool valid = DateTime.UtcNow <= modalReturnGuardUntilUtc;
                modalReturnGuardUntilUtc = DateTime.MinValue;
                return valid;
            }
        }

        public static void Restore(Window window)
        {
            QueueRestore(window, false);
        }

        public static void RestoreAfterModal(Window window)
        {
            QueueRestore(window, true);
        }

        private static void QueueRestore(Window window, bool reregisterRawInput)
        {
            if (window == null) return;
            Action restore = delegate
            {
                try
                {
                    if (!window.IsLoaded) return;
                    if (reregisterRawInput)
                    {
                        IntPtr rawHandle = new WindowInteropHelper(window).Handle;
                        if (rawHandle != IntPtr.Zero)
                            HuymaierConsole.Native.RawHidController.Register(rawHandle);
                    }
                    ActivateNow(window);
                    if (window.IsActive) return;

                    // Retry only when Windows did not reactivate the owner naturally.
                    // The old path always forced a second activation 180 ms later,
                    // producing a second focus/layout/input burst on every console exit.
                    System.Windows.Threading.DispatcherTimer retry = new System.Windows.Threading.DispatcherTimer(
                        System.Windows.Threading.DispatcherPriority.ContextIdle, window.Dispatcher);
                    retry.Interval = TimeSpan.FromMilliseconds(120);
                    retry.Tick += delegate
                    {
                        retry.Stop();
                        try { if (window.IsLoaded && !window.IsActive) ActivateNow(window); } catch { }
                    };
                    retry.Start();
                }
                catch { }
            };
            try
            {
                // Never do HWND rebinding / foreground restoration inline with
                // ShowDialog returning. Give the main shell a dispatcher turn first.
                window.Dispatcher.BeginInvoke(
                    System.Windows.Threading.DispatcherPriority.ContextIdle, restore);
            }
            catch { }
        }

        private static void ActivateNow(Window window)
        {
            if (window == null || !window.IsLoaded) return;
            if (!window.IsVisible) window.Show();
            bool maximize = window.WindowState == WindowState.Maximized;

            // Closing a WPF modal normally reactivates its owner automatically.
            // If that already happened, avoid redundant Win32 foreground calls.
            if (!window.IsActive)
            {
                if (window.WindowState == WindowState.Minimized) window.WindowState = WindowState.Normal;
                IntPtr handle = new WindowInteropHelper(window).Handle;
                if (handle != IntPtr.Zero)
                {
                    ShowWindow(handle, maximize ? 3 : 9);
                    if (maximize) window.WindowState = WindowState.Maximized;
                    BringWindowToTop(handle);
                    SetForegroundWindow(handle);
                    SetActiveWindow(handle);
                }
                window.Activate();
            }

            window.Focus();
            IInputElement target = window.Content as IInputElement;
            if (target != null) Keyboard.Focus(target);
        }
    }

    public sealed class NativeBridge'''
native = activation_pattern.sub(activation, native, count=1)

bridge_start = native.index("    public sealed class NativeBridge")
bridge_end = native.index("        private static void TryWriteBridgeLog", bridge_start)
bridge = native[bridge_start:bridge_end]
show_count = bridge.count("                window.ShowDialog();")
if show_count != 4:
    raise SystemExit(f"NativeBridge ShowDialog count changed: {show_count}")
bridge = bridge.replace(
    "                window.ShowDialog();",
    "                NativeWindowActivation.PrepareModalReturn(owner);\n                window.ShowDialog();",
)

old_return = '''                try
                {
                    if (owner != null && owner.IsLoaded)
                    {
                        IntPtr handle = new WindowInteropHelper(owner).Handle;
                        if (handle != IntPtr.Zero) HuymaierConsole.Native.RawHidController.Register(handle);
                    }
                    NativeConsoleNavigation.Reset();
                    NativeWindowActivation.Restore(owner);
                }
                catch { }'''
new_return = '''                try
                {
                    NativeConsoleNavigation.Reset();
                    NativeWindowActivation.RestoreAfterModal(owner);
                }
                catch { }'''
return_count = bridge.count(old_return)
if return_count != 4:
    raise SystemExit(f"NativeBridge modal return block count changed: {return_count}")
bridge = bridge.replace(old_return, new_return)
native = native[:bridge_start] + bridge + native[bridge_end:]
write(NATIVE_APP, native)


# ---------------------------------------------------------------------------
# Main shell activation: expected native-console return must not feel like a
# controller freeze. External focus returns still retain the safety guard.
# ---------------------------------------------------------------------------
shell = read(SHELL)
old_activated = "$script:Window.Add_Activated({$script:LastGamepadMask=0;$script:LastDirection='';$script:NextDirectionAt=[datetime]::MinValue;if((Get-Date) -ge $script:ControllerInputGuardUntil){$script:ControllerInputGuardUntil=(Get-Date).AddMilliseconds(350)};try{if('HuymaierConsole.NativeApp.NativeConsoleNavigation' -as [type]){[HuymaierConsole.NativeApp.NativeConsoleNavigation]::Reset()}}catch{};Update-BackgroundMusic})"
new_activated = r'''$script:Window.Add_Activated({
        $script:LastGamepadMask=0
        $script:LastDirection=''
        $script:NextDirectionAt=[datetime]::MinValue
        $nativeModalReturn=$false
        try{
            if('HuymaierConsole.NativeApp.NativeWindowActivation' -as [type]){
                $nativeModalReturn=[HuymaierConsole.NativeApp.NativeWindowActivation]::ConsumeModalReturnActivationGuard()
            }
        }catch{}
        if(-not $nativeModalReturn -and (Get-Date) -ge $script:ControllerInputGuardUntil){
            $script:ControllerInputGuardUntil=(Get-Date).AddMilliseconds(350)
        }
        try{if('HuymaierConsole.NativeApp.NativeConsoleNavigation' -as [type]){[HuymaierConsole.NativeApp.NativeConsoleNavigation]::Reset()}}catch{}
        Update-BackgroundMusic
    })'''
shell = replace_once(shell, old_activated, new_activated, "main shell Activated handler")
write(SHELL, shell)


# ---------------------------------------------------------------------------
# Generic console close: remove the second parent restore and defer WPF media
# resource teardown until ApplicationIdle so main-shell input gets priority.
# ---------------------------------------------------------------------------
platforms = read(CONSOLE_PLATFORMS)
old_closed = '''        private void OnClosed(object sender, EventArgs e)
        {
            try { Dispatcher.UnhandledException -= DispatcherUnhandledException; } catch { }
            try { inputTimer.Stop(); } catch { }
            try { startupOverlay.Stop(); } catch { }
            try { effectPlayer.Stop(); effectPlayer.Close(); } catch { }
            try { ambiencePlayer.Stop(); ambiencePlayer.Close(); } catch { }
            try { if (source != null && hook != null) source.RemoveHook(hook); } catch { }
            settings.Save(settingsPath);
            NativeWindowActivation.Restore(Owner);
        }'''
new_closed = '''        private void OnClosed(object sender, EventArgs e)
        {
            try { Dispatcher.UnhandledException -= DispatcherUnhandledException; } catch { }
            try { inputTimer.Stop(); } catch { }
            try { if (source != null && hook != null) source.RemoveHook(hook); } catch { }
            try { settings.Save(settingsPath); } catch { }

            // The shared NativeBridge owns parent restoration.  Doing it here as
            // well caused two foreground/layout/input bursts on every exit.  Media
            // Close can also stall WPF, so release those resources only after the
            // main Huymaier shell has had a chance to process its first input.
            try
            {
                Dispatcher.BeginInvoke(System.Windows.Threading.DispatcherPriority.ApplicationIdle,
                    new Action(delegate
                    {
                        try { startupOverlay.Stop(); } catch { }
                        try { effectPlayer.Stop(); effectPlayer.Close(); } catch { }
                        try { ambiencePlayer.Stop(); ambiencePlayer.Close(); } catch { }
                    }));
            }
            catch
            {
                try { startupOverlay.Stop(); } catch { }
                try { effectPlayer.Stop(); effectPlayer.Close(); } catch { }
                try { ambiencePlayer.Stop(); ambiencePlayer.Close(); } catch { }
            }
        }'''
platforms = replace_once(platforms, old_closed, new_closed, "ConsolePlatformWindow OnClosed")


# ---------------------------------------------------------------------------
# Wii/GameCube classification. Shared folders stay supported, but overlapping
# Dolphin formats are owned by the platform metadata in the container/header.
# Dolphin format facts used here:
#   raw disc: Wii magic @0x18, GameCube magic @0x1c
#   GCZ: subtype 0=GC, 1=Wii
#   WIA/RVZ header2 disc_type @0x48: 1=GC, 2=Wii
#   CISO: first logical block begins at 0x8000 when map[0] is present
# ---------------------------------------------------------------------------
dolphin_helper = r'''        // v0.26.4 DOLPHIN_PLATFORM_FILTER_BEGIN
        private bool IsDolphinPlatformGameFile(string path)
        {
            if (definition.Shell != "Wii" && definition.Shell != "GameCube") return true;
            int platform = DetectDolphinDiscPlatform(path);
            return definition.Shell == "Wii" ? platform == 2 : platform == 1;
        }

        private static int DetectDolphinDiscPlatform(string path)
        {
            if (String.IsNullOrWhiteSpace(path) || !File.Exists(path)) return 0;
            string extension = Path.GetExtension(path).ToLowerInvariant();
            try
            {
                using (FileStream stream = new FileStream(path, FileMode.Open, FileAccess.Read,
                    FileShare.ReadWrite | FileShare.Delete))
                {
                    if (extension == ".iso" || extension == ".gcm")
                        return DetectRawNintendoDisc(stream, 0);

                    if (extension == ".rvz" || extension == ".wia")
                    {
                        byte[] header = ReadFileBytes(stream, 0, 0x4c);
                        if (header == null) return 0;
                        bool rvz = header[0] == (byte)'R' && header[1] == (byte)'V' && header[2] == (byte)'Z' && header[3] == 1;
                        bool wia = header[0] == (byte)'W' && header[1] == (byte)'I' && header[2] == (byte)'A' && header[3] == 1;
                        if (!rvz && !wia) return 0;
                        uint discType = ReadUInt32BigEndian(header, 0x48);
                        return discType == 1 ? 1 : (discType == 2 ? 2 : 0);
                    }

                    if (extension == ".gcz")
                    {
                        byte[] header = ReadFileBytes(stream, 0, 8);
                        if (header == null || ReadUInt32LittleEndian(header, 0) != 0xB10BC001U) return 0;
                        uint subtype = ReadUInt32LittleEndian(header, 4);
                        return subtype == 0 ? 1 : (subtype == 1 ? 2 : 0);
                    }

                    if (extension == ".ciso")
                    {
                        byte[] header = ReadFileBytes(stream, 0, 9);
                        if (header == null || header[0] != (byte)'C' || header[1] != (byte)'I' ||
                            header[2] != (byte)'S' || header[3] != (byte)'O' || header[8] != 1) return 0;
                        return DetectRawNintendoDisc(stream, 0x8000);
                    }

                    if (extension == ".wbfs")
                    {
                        byte[] header = ReadFileBytes(stream, 0, 4);
                        return header != null && header[0] == (byte)'W' && header[1] == (byte)'B' &&
                            header[2] == (byte)'F' && header[3] == (byte)'S' ? 2 : 0;
                    }
                }
            }
            catch { }
            return 0;
        }

        private static int DetectRawNintendoDisc(FileStream stream, long baseOffset)
        {
            byte[] header = ReadFileBytes(stream, baseOffset, 0x20);
            if (header == null) return 0;
            if (ReadUInt32BigEndian(header, 0x18) == 0x5D1C9EA3U) return 2;
            if (ReadUInt32BigEndian(header, 0x1c) == 0xC2339F3DU) return 1;
            return 0;
        }

        private static byte[] ReadFileBytes(FileStream stream, long offset, int count)
        {
            if (stream == null || count <= 0 || offset < 0 || stream.Length < offset + count) return null;
            byte[] buffer = new byte[count];
            stream.Seek(offset, SeekOrigin.Begin);
            int read = 0;
            while (read < count)
            {
                int current = stream.Read(buffer, read, count - read);
                if (current <= 0) return null;
                read += current;
            }
            return buffer;
        }

        private static uint ReadUInt32BigEndian(byte[] buffer, int offset)
        {
            return ((uint)buffer[offset] << 24) | ((uint)buffer[offset + 1] << 16) |
                   ((uint)buffer[offset + 2] << 8) | buffer[offset + 3];
        }

        private static uint ReadUInt32LittleEndian(byte[] buffer, int offset)
        {
            return buffer[offset] | ((uint)buffer[offset + 1] << 8) |
                   ((uint)buffer[offset + 2] << 16) | ((uint)buffer[offset + 3] << 24);
        }
        // v0.26.4 DOLPHIN_PLATFORM_FILTER_END

'''
queue_anchor = "        private void QueueLibraryRefresh()\n        {"
if "v0.26.4 DOLPHIN_PLATFORM_FILTER_BEGIN" not in platforms:
    if queue_anchor not in platforms:
        raise SystemExit("QueueLibraryRefresh anchor not found")
    platforms = platforms.replace(queue_anchor, dolphin_helper + queue_anchor, 1)

old_async_filter = "if (!extensions.Contains(extension, StringComparer.OrdinalIgnoreCase) || !seen.Add(path)) continue;"
new_async_filter = "if (!extensions.Contains(extension, StringComparer.OrdinalIgnoreCase) || !IsDolphinPlatformGameFile(path) || !seen.Add(path)) continue;"
platforms = replace_once(platforms, old_async_filter, new_async_filter, "async native library filter")

old_sync_filter = "if (!definition.GameExtensions.Contains(extension, StringComparer.OrdinalIgnoreCase)) continue;\n                        if (!seen.Add(path)) continue;"
new_sync_filter = "if (!definition.GameExtensions.Contains(extension, StringComparer.OrdinalIgnoreCase)) continue;\n                        if (!IsDolphinPlatformGameFile(path)) continue;\n                        if (!seen.Add(path)) continue;"
platforms = replace_once(platforms, old_sync_filter, new_sync_filter, "manual native library filter")

old_cache = "            games = LoadCachedGames();\n            page = GetDefaultPageIndex();"
new_cache = "            games = LoadCachedGames();\n            if (definition.Shell == \"Wii\" || definition.Shell == \"GameCube\")\n                games = games.Where(delegate(ConsolePlatformGame game) { return game != null && IsDolphinPlatformGameFile(game.Path); }).ToList();\n            page = GetDefaultPageIndex();"
platforms = replace_once(platforms, old_cache, new_cache, "cached Dolphin library filter")
write(CONSOLE_PLATFORMS, platforms)


# ---------------------------------------------------------------------------
# Background library-count worker must use the exact same ownership rules.
# ---------------------------------------------------------------------------
worker = read(WORKER)
worker_helper = r'''function Read-HcBytes($Stream,[long]$Offset,[int]$Count){
    if($null -eq $Stream -or $Count -le 0 -or $Offset -lt 0 -or $Stream.Length -lt ($Offset+$Count)){return $null}
    $buffer=New-Object byte[] $Count
    [void]$Stream.Seek($Offset,[IO.SeekOrigin]::Begin)
    $read=0
    while($read -lt $Count){$current=$Stream.Read($buffer,$read,$Count-$read);if($current -le 0){return $null};$read+=$current}
    return ,$buffer
}
function Read-HcUInt32BE($Buffer,[int]$Offset){return [uint32](([uint32]$Buffer[$Offset]-shl 24)-bor([uint32]$Buffer[$Offset+1]-shl 16)-bor([uint32]$Buffer[$Offset+2]-shl 8)-bor[uint32]$Buffer[$Offset+3])}
function Read-HcUInt32LE($Buffer,[int]$Offset){return [uint32](([uint32]$Buffer[$Offset])-bor([uint32]$Buffer[$Offset+1]-shl 8)-bor([uint32]$Buffer[$Offset+2]-shl 16)-bor([uint32]$Buffer[$Offset+3]-shl 24))}
function Get-HcRawNintendoDiscPlatform($Stream,[long]$BaseOffset){
    $header=Read-HcBytes $Stream $BaseOffset 32;if($null -eq $header){return 0}
    if((Read-HcUInt32BE $header 24) -eq [uint32]0x5D1C9EA3){return 2}
    if((Read-HcUInt32BE $header 28) -eq [uint32]0xC2339F3D){return 1}
    return 0
}
function Get-HcDolphinDiscPlatform([string]$Path){
    if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){return 0}
    $extension=[IO.Path]::GetExtension($Path).ToLowerInvariant();$stream=$null
    try{
        $stream=[IO.File]::Open($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
        if($extension -eq '.iso' -or $extension -eq '.gcm'){return (Get-HcRawNintendoDiscPlatform $stream 0)}
        if($extension -eq '.rvz' -or $extension -eq '.wia'){
            $header=Read-HcBytes $stream 0 76;if($null -eq $header){return 0}
            $rvz=($header[0]-eq 82-and$header[1]-eq 86-and$header[2]-eq 90-and$header[3]-eq 1)
            $wia=($header[0]-eq 87-and$header[1]-eq 73-and$header[2]-eq 65-and$header[3]-eq 1)
            if(-not($rvz-or$wia)){return 0};$disc=Read-HcUInt32BE $header 72;if($disc -eq 1){return 1};if($disc -eq 2){return 2};return 0
        }
        if($extension -eq '.gcz'){
            $header=Read-HcBytes $stream 0 8;if($null -eq $header -or (Read-HcUInt32LE $header 0) -ne [uint32]0xB10BC001){return 0}
            $subtype=Read-HcUInt32LE $header 4;if($subtype -eq 0){return 1};if($subtype -eq 1){return 2};return 0
        }
        if($extension -eq '.ciso'){
            $header=Read-HcBytes $stream 0 9;if($null -eq $header -or$header[0]-ne 67-or$header[1]-ne 73-or$header[2]-ne 83-or$header[3]-ne 79-or$header[8]-ne 1){return 0}
            return (Get-HcRawNintendoDiscPlatform $stream 32768)
        }
        if($extension -eq '.wbfs'){
            $header=Read-HcBytes $stream 0 4;if($null -ne $header -and$header[0]-eq 87-and$header[1]-eq 66-and$header[2]-eq 70-and$header[3]-eq 83){return 2};return 0
        }
    }catch{return 0}finally{if($null -ne $stream){try{$stream.Dispose()}catch{}}}
    return 0
}
function Test-HcDolphinPlatformGame([string]$Id,[string]$Path){
    $key=($Id??'').ToUpperInvariant();if($key -ne 'WII' -and $key -ne 'GAMECUBE'){return $true}
    $platform=Get-HcDolphinDiscPlatform $Path
    if($key -eq 'WII'){return $platform -eq 2}
    return $platform -eq 1
}

'''
# PowerShell 5.1 has no null-coalescing operator; keep the helper source PS5-safe.
worker_helper = worker_helper.replace("$key=($Id??'').ToUpperInvariant()", "$key=([string]$Id).ToUpperInvariant()")
worker_anchor = "function Get-Extensions([string]$Id){"
if "function Get-HcDolphinDiscPlatform" not in worker:
    if worker_anchor not in worker:
        raise SystemExit("native console worker extension anchor not found")
    worker = worker.replace(worker_anchor, worker_helper + worker_anchor, 1)

old_worker_filter = "            if($extensions -notcontains $file.Extension.ToLowerInvariant()){continue}\n            try{$key=$file.FullName.ToLowerInvariant()}catch{$key=[string]$file.FullName}"
new_worker_filter = "            if($extensions -notcontains $file.Extension.ToLowerInvariant()){continue}\n            if(-not(Test-HcDolphinPlatformGame $PlatformId $file.FullName)){continue}\n            try{$key=$file.FullName.ToLowerInvariant()}catch{$key=[string]$file.FullName}"
worker = replace_once(worker, old_worker_filter, new_worker_filter, "native console worker platform filter")
write(WORKER, worker)


# Static invariants so the materializer fails loudly if any path drifted.
checks = {
    NATIVE_APP: ["PrepareModalReturn(owner)", "RestoreAfterModal(owner)", "ConsumeModalReturnActivationGuard"],
    CONSOLE_PLATFORMS: ["DOLPHIN_PLATFORM_FILTER_BEGIN", "ApplicationIdle", "IsDolphinPlatformGameFile(path)"],
    SHELL: ["ConsumeModalReturnActivationGuard()"],
    WORKER: ["Get-HcDolphinDiscPlatform", "Test-HcDolphinPlatformGame $PlatformId $file.FullName"],
}
for path, markers in checks.items():
    text = read(path)
    for marker in markers:
        if marker not in text:
            raise SystemExit(f"missing post-test invariant in {path.name}: {marker}")

print("Applied v0.26.4 post-test Wii classification and modal-return responsiveness fixes")
