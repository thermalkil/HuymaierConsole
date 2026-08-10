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
# Native foreground ownership: WPF IsActive is not authoritative for a process
# containing owned/native console windows. Use Win32 foreground HWND -> PID.
# ---------------------------------------------------------------------------
p = 'Native/HuymaierConsole.SystemOverlay.cs'
t = read(p)
anchor = '''    internal static class SystemWindowCatalog
    {
'''
insert = '''    public static class HuymaierForegroundOwnership
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

'''
if 'public static class HuymaierForegroundOwnership' not in t:
    t = replace_once(t, anchor, insert + anchor, 'foreground ownership insertion')
write(p, t)

# Public diagnostics facade for the otherwise-internal system-button bridge.
p = 'Native/HuymaierConsole.GameInput.cs'
t = read(p)
anchor = '''    internal static class HuymaierSystemButtonBridge
    {
'''
insert = '''    public static class HuymaierSystemButtonStatus
    {
        public static bool IsAvailable
        {
            get { return HuymaierSystemButtonBridge.IsAvailable; }
        }
    }

'''
if 'public static class HuymaierSystemButtonStatus' not in t:
    t = replace_once(t, anchor, insert + anchor, 'system button diagnostics insertion')
write(p, t)

# ---------------------------------------------------------------------------
# Game Bar/Guide arbiter: hidden overlay consumes ONLY Guide. General navigation
# is polled only while the Game Bar is visibly open. Foreground routing is based
# on actual process ownership rather than WPF IsActive state.
# ---------------------------------------------------------------------------
p = 'HuymaierGameBar.ps1'
t = read(p)
if '$script:HcForegroundMethod=$null' not in t:
    t = replace_once(
        t,
        '$script:HcSystemGuideMethod=$null\n',
        '$script:HcSystemGuideMethod=$null\n$script:HcForegroundMethod=$null\n$script:HcSystemGuideAvailableProperty=$null\n',
        'gamebar reflection fields'
    )

anchor = '''function Invoke-HcInternalGuide {
'''
helpers = r'''function Initialize-HcOwnershipReflection {
    try{
        $nativeVariable=Get-Variable -Name HuymaierNativeBridge -ErrorAction SilentlyContinue
        if($null -eq $nativeVariable -or $null -eq $nativeVariable.Value){return}
        $assembly=$nativeVariable.Value.GetType().Assembly
        $flags=[Reflection.BindingFlags]::Public -bor [Reflection.BindingFlags]::Static
        if($null -eq $script:HcForegroundMethod){
            $foregroundType=$assembly.GetType('HuymaierConsole.NativeApp.HuymaierForegroundOwnership',$false)
            if($null -ne $foregroundType){$script:HcForegroundMethod=$foregroundType.GetMethod('IsCurrentProcessForeground',$flags)}
        }
        if($null -eq $script:HcSystemGuideAvailableProperty){
            $statusType=$assembly.GetType('HuymaierConsole.NativeApp.HuymaierSystemButtonStatus',$false)
            if($null -ne $statusType){$script:HcSystemGuideAvailableProperty=$statusType.GetProperty('IsAvailable',$flags)}
        }
    }catch{}
}

function Test-HcForegroundOwnedByConsole {
    try{
        Initialize-HcOwnershipReflection
        if($null -eq $script:HcForegroundMethod){return $false}
        return [bool]$script:HcForegroundMethod.Invoke($null,$null)
    }catch{return $false}
}

function Test-HcGameInputGuideAvailable {
    try{
        Initialize-HcOwnershipReflection
        if($null -eq $script:HcSystemGuideAvailableProperty){return $false}
        return [bool]$script:HcSystemGuideAvailableProperty.GetValue($null,$null)
    }catch{return $false}
}

'''
if 'function Test-HcForegroundOwnedByConsole' not in t:
    t = replace_once(t, anchor, helpers + anchor, 'gamebar ownership helpers')

old_init = '''        Initialize-HcSystemGuideReflection
        Set-HcXboxGameBarSuppression
'''
new_init = '''        Initialize-HcSystemGuideReflection
        Initialize-HcOwnershipReflection
        $gameInputGuideAvailable=Test-HcGameInputGuideAvailable
        Write-Log ("System Guide backend initialized: GameInput={0}; RawGameControllerFallback=Enabled." -f $gameInputGuideAvailable)
        Set-HcXboxGameBarSuppression
'''
t = replace_once(t, old_init, new_init, 'gamebar guide diagnostics')

start = t.find('        $timer.Add_Tick({')
end = t.find('        })\n        $timer.Start()', start)
if start < 0 or end < 0:
    raise SystemExit('gamebar timer bounds not found')
new_timer = r'''        $timer.Add_Tick({
            try{
                if($null -eq $script:Window){return}

                # The hidden watcher observes only the dedicated system Guide/Home
                # edge. It must never consume D-pad/A/B/shoulder input from the
                # shared navigation router while the overlay is hidden.
                $gameInputGuideEdge=Get-HcGameInputGuideEdge
                $rawGuide=Get-HcRawSystemGuidePressed
                $rawGuideEdge=($rawGuide -and -not $script:HcExternalGuideDown)
                $script:HcExternalGuideDown=$rawGuide
                $guideEdge=$gameInputGuideEdge -or $rawGuideEdge

                $visible=[HuymaierConsole.NativeApp.HuymaierGameBarHost]::IsVisible
                if($visible){
                    # Once visible, the Game Bar owns normal navigation and may
                    # poll the shared controller router for D-pad/A/B/etc.
                    $command=''
                    try{
                        if('HuymaierConsole.NativeApp.NativeConsoleNavigation' -as [type]){
                            $native=[HuymaierConsole.NativeApp.NativeConsoleNavigation]::Poll()
                            $command=[string]$native.Command
                        }
                    }catch{}
                    if($guideEdge){[HuymaierConsole.NativeApp.HuymaierGameBarHost]::ProcessCommand('Guide')}
                    elseif($command){[HuymaierConsole.NativeApp.HuymaierGameBarHost]::ProcessCommand($command)}
                    return
                }

                # Win32 foreground HWND ownership is authoritative. WPF IsActive
                # can be false while an owned/native Huymaier interface is active.
                if(Test-HcForegroundOwnedByConsole){
                    if($guideEdge){Invoke-HcInternalGuide -ActiveWindow (Get-HcActiveConsoleWindow)}
                    return
                }

                # An external process owns foreground focus. Only Guide/Home may
                # wake the Huymaier Game Bar; all other controller input remains
                # entirely with the foreground game/application.
                if($guideEdge){
                    [HuymaierConsole.NativeApp.HuymaierGameBarHost]::Show()
                    Write-Log 'Huymaier Game Bar opened over the foreground game/app.'
                }
            }catch{Write-Log "Huymaier Game Bar/global Guide watcher recovered: $($_.Exception.Message)" 'WARN'}
'''
t = t[:start] + new_timer + t[end:]
write(p, t, bom=True)

# ---------------------------------------------------------------------------
# Xbox storefront vs Original Xbox console: never resolve a Games-platform menu
# selection to an emulator by its internal/backend ID. Menu routing uses only
# menu/display identity and aliases. Internal IDs remain valid for direct calls.
# ---------------------------------------------------------------------------
p = 'HuymaierEmulatorPlatforms.ps1'
t = read(p)
anchor = '''function Test-HcEmulatorPlatform {
    param([string]$Platform)
    return $null -ne (Get-HcEmulatorPlatformEntry $Platform)
}
'''
insert = anchor + r'''
function Get-HcEmulatorPlatformMenuEntry {
    param([string]$Platform)
    if([string]::IsNullOrWhiteSpace($Platform)){return $null}
    foreach($entry in @(Get-HcEmulatorPlatformEntries)){
        foreach($candidate in @(
            [string](Get-EntryProperty $entry 'name' ''),
            [string](Get-EntryProperty $entry 'displayName' ''),
            [string](Get-EntryProperty $entry 'menuName' '')
        )){
            if($candidate -and [string]::Equals($candidate,$Platform,[StringComparison]::OrdinalIgnoreCase)){return $entry}
        }
        foreach($alias in @(Get-EntryProperty $entry 'aliases' @())){
            if([string]::Equals([string]$alias,$Platform,[StringComparison]::OrdinalIgnoreCase)){return $entry}
        }
    }
    return $null
}

function Test-HcEmulatorPlatformMenuName {
    param([string]$Platform)
    return $null -ne (Get-HcEmulatorPlatformMenuEntry $Platform)
}
'''
if 'function Get-HcEmulatorPlatformMenuEntry' not in t:
    t = replace_once(t, anchor, insert, 'emulator strict menu resolver')
old = '''            if(Test-HcEmulatorPlatform $platform){
                $script:SelectedGamePlatform=$platform
'''
new = '''            if(Test-HcEmulatorPlatformMenuName $platform){
                $script:SelectedGamePlatform=$platform
'''
t = replace_once(t, old, new, 'emulator platform-select strict routing')
write(p, t, bom=True)

# ---------------------------------------------------------------------------
# Windows-setting restore migration: accept both v0.26.0's four-entry backup
# array and v0.26.1's single controller-setting backup object.
# ---------------------------------------------------------------------------
p = 'Restore-HuymaierWindowsSettings.ps1'
restore = r'''param([switch]$Quiet)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'

$root=Join-Path $env:LOCALAPPDATA 'Huymaier Console'
$backupPath=Join-Path $root 'xbox-gamebar-backup.json'
$runOnce='HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce'
$runOnceName='HuymaierConsoleRestoreGameBar'

try{
    if(Test-Path -LiteralPath $backupPath -PathType Leaf){
        $rawBackup=Get-Content -Raw -LiteralPath $backupPath -Encoding UTF8|ConvertFrom-Json
        foreach($backup in @($rawBackup)){
            if($null -eq $backup){continue}
            $path=[string]$backup.Path
            $name=[string]$backup.Name
            if([string]::IsNullOrWhiteSpace($path) -or [string]::IsNullOrWhiteSpace($name)){continue}
            $currentExists=$false
            $current=$null
            try{
                $item=Get-ItemProperty -LiteralPath $path -Name $name -ErrorAction Stop
                if($null -ne $item.PSObject.Properties[$name]){$currentExists=$true;$current=$item.$name}
            }catch{}

            # Restore only while Huymaier's forced zero is still present. A newer
            # user change always wins. This also safely migrates v0.26.0's older
            # four-setting backup format without concatenating registry paths.
            if($currentExists -and [int]$current -eq 0){
                if([bool]$backup.Exists){
                    if(-not(Test-Path -LiteralPath $path)){New-Item -Path $path -Force|Out-Null}
                    Set-ItemProperty -LiteralPath $path -Name $name -Type DWord -Value ([int]$backup.Value) -Force
                }else{
                    Remove-ItemProperty -LiteralPath $path -Name $name -ErrorAction SilentlyContinue
                }
            }
        }
        Remove-Item -LiteralPath $backupPath -Force -ErrorAction SilentlyContinue
    }
    Remove-ItemProperty -LiteralPath $runOnce -Name $runOnceName -ErrorAction SilentlyContinue
}catch{
    if(-not $Quiet){throw}
}
'''
write(p, restore, bom=True)

# Candidate gates specifically prevent the RC7 regressions from returning.
p = '.build/Test-HuymaierCandidate.ps1'
t = read(p)
anchor = '''    foreach($dead in @('HuymaierGuideInput.cs','HuymaierGuideBridge.dll','HuymaierConsoleUpdate.ps1','HuymaierConsoleApplyUpdate.ps1')){if(Test-Path -LiteralPath (Join-Path $StageRoot $dead)){throw "Retired payload is still packaged: $dead"}}
'''
insert = anchor + r'''

    # RC8 runtime ownership invariants: hidden Game Bar cannot steal general
    # navigation; Win32 foreground ownership decides internal vs external Guide;
    # Xbox storefront selection cannot be intercepted by the Original Xbox ID.
    $visibleIndex=$gameBar.IndexOf('$visible=[HuymaierConsole.NativeApp.HuymaierGameBarHost]::IsVisible')
    $pollIndex=$gameBar.IndexOf('[HuymaierConsole.NativeApp.NativeConsoleNavigation]::Poll()')
    if($visibleIndex -lt 0 -or $pollIndex -lt 0 -or $pollIndex -lt $visibleIndex){throw 'Game Bar can poll shared navigation before visible-overlay ownership is established.'}
    foreach($required in @('Test-HcForegroundOwnedByConsole','HuymaierForegroundOwnership','System Guide backend initialized')){if($gameBar -notmatch [regex]::Escape($required)){throw "Game Bar foreground/Guide ownership invariant is missing: $required"}}
    $emulator=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'HuymaierEmulatorPlatforms.ps1') -Encoding UTF8
    if($emulator -notmatch [regex]::Escape('Test-HcEmulatorPlatformMenuName $platform')){throw 'Platform selection is not using strict emulator menu identity.'}
    $restore=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'Restore-HuymaierWindowsSettings.ps1') -Encoding UTF8
    if($restore -notmatch [regex]::Escape('foreach($backup in @($rawBackup))')){throw 'Legacy Xbox Game Bar backup-array migration is missing.'}
'''
if 'RC8 runtime ownership invariants' not in t:
    t = replace_once(t, anchor, insert, 'candidate RC8 invariants')
write(p, t, bom=True)

print('RC8 runtime ownership, controller isolation, Xbox identity, and registry migration fixes applied.')
