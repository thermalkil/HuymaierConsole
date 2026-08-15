param(
    [Parameter(Mandatory=$true)][string]$StageRoot,
    [Parameter(Mandatory=$true)][string]$ValidationPath
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'

function Require-File([string]$Relative){
    $path=Join-Path $StageRoot $Relative
    if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "Streaming candidate required file missing: $Relative"}
    return $path
}
function Require-Text([string]$Relative,[string[]]$Needles){
    $path=Require-File $Relative
    $raw=Get-Content -Raw -LiteralPath $path -Encoding UTF8
    foreach($needle in $Needles){if($raw.IndexOf($needle,[StringComparison]::Ordinal) -lt 0){throw "$Relative missing streaming invariant: $needle"}}
    return $raw
}
function Assert-Ps51Parse([string]$Relative){
    $path=Require-File $Relative
    $tokens=$null;$errors=$null
    [void][Management.Automation.Language.Parser]::ParseFile($path,[ref]$tokens,[ref]$errors)
    if($errors.Count -gt 0){$detail=($errors|ForEach-Object{"line $($_.Extent.StartLineNumber): $($_.Message)"}) -join '; ';throw "Staged PowerShell 5.1 parse failed for ${Relative}: $detail"}
}
function Assert-X64Pe([string]$Relative){
    $path=Require-File $Relative
    $bytes=[IO.File]::ReadAllBytes($path)
    if($bytes.Length -lt 256){throw "Staged PE is too small: $Relative"}
    $pe=[BitConverter]::ToInt32($bytes,0x3c)
    if($pe -lt 0 -or $pe+6 -ge $bytes.Length){throw "Invalid staged PE header: $Relative"}
    $machine=[BitConverter]::ToUInt16($bytes,$pe+4)
    if($machine -ne 0x8664){throw ("Staged {0} is not x64 (machine=0x{1:X4})." -f $Relative,$machine)}
}

$core=Require-Text 'HuymaierConsole.ps1' @(
    'HUYMAIER_STREAMING_CONTROLLER_RUNTIME_V1',
    "`$script:StreamingControllerModulePath = Join-Path `$script:BaseDir 'HuymaierStreamingController.ps1'",
    'Streaming controller module load failed'
)
$bootstrap=Require-Text 'HuymaierBootstrap.ps1' @(
    'HUYMAIER_STREAMING_CONTROLLER_PREFLIGHT_V1',
    'HuymaierStreamingController.ps1',
    'Streaming controller runtime'
)
$installer=Require-Text 'Install-HuymaierConsole.ps1' @(
    'HUYMAIER_STREAMING_CONTROLLER_INSTALLER_CACHE_V1',
    'HuymaierStreamingController.ps1'
)
$runtime=Require-Text 'HuymaierStreamingController.ps1' @(
    'ControllerCursorSpeed',
    'controller-cursor-speed-slider',
    'Convert-HcCursorAxis',
    'Update-HcSmoothBrowserPointer',
    'Move-HcBrowserVirtualCursorDelta',
    'Scroll-HcBrowserVirtualCursorDelta',
    'Set-HcBrowserAnalogDrive',
    'Stop-HcBrowserAnalogDrive',
    'requestAnimationFrame(tick)',
    '__hcCursorDriveState',
    '__hcCursorDrive=(x,y,speed)',
    'magnitude=[math]::Sqrt',
    '1500.0',
    'Right Stick Scroll',
    'Start-HcNativeStreamingApp',
    'HuymaierStreamingCursorHost.exe',
    'Get-HcAppxArtworkCandidate',
    'favicon.ico',
    'ControllerMouseEnabled',
    'FullscreenPresentation',
    'Native app mode uses the installed Windows streaming app directly; WebView is not involved.'
)
$managed=Require-Text 'Native\HuymaierConsole.GameInput.cs' @(
    'public const string Version = "0.26.5";',
    'public const string Architecture = "x64";',
    'HuymaierPointerState',
    'HuymaierPointerInput',
    'HC_ReadGamepadPointerState',
    'ReadPointerState'
)
$bridge=Require-Text 'Native\HuymaierGameInputBridge.cpp' @(
    'HC_ReadGamepadPointerState',
    'GetCurrentReading(GameInputKindGamepad',
    'leftThumbstickX',
    'rightThumbstickY',
    'GameInputGamepadA',
    'GameInputGamepadX',
    'GameInputEnableBackgroundInput',
    'GameInputEnableBackgroundGuideButton',
    'GameInputEnableBackgroundShareButton'
)
$hostText=Require-Text 'Native\HuymaierStreamingCursorHost.cs' @(
    'HC_ReadGamepadPointerState',
    'WS_POPUP',
    'SetWindowPos',
    'MonitorFromWindow',
    'ApplyDeadzoneCurve',
    '1500.0',
    'LeftClick',
    'ShowOnScreenKeyboard',
    'MOUSEEVENTF_WHEEL',
    'TextInputHost',
    'parentProcessId',
    'IsPointerForegroundAllowed',
    'RestoreWindow',
    'launchBounds',
    'SetCursorPos((int)Math.Round(cursorX)',
    'Math.Sqrt(rawX * rawX + rawY * rawY)',
    'magnitude > 0.14'
)
$nintendo=Require-Text 'Native\HuymaierConsole.ConsolePlatforms.cs' @(
    'HUYMAIER_WII_ARTWORK_ALIAS_V1',
    'string legacyKey=CleanName(Path.GetFileNameWithoutExtension(game.Path))',
    'string cover=FindDolphinArtwork(game.Path,artworkTitle)',
    'FindEmulatorArtwork(game.Path,artworkTitle)'
)

foreach($scriptFile in @('HuymaierConsole.ps1','HuymaierBootstrap.ps1','Install-HuymaierConsole.ps1','HuymaierStreamingController.ps1')){Assert-Ps51Parse $scriptFile}
Assert-X64Pe 'HuymaierStreamingCursorHost.exe'
Assert-X64Pe 'HuymaierConsole.exe'
Require-File 'HuymaierGameInputBridge.dll'|Out-Null

# Explicitly reject the two runtime failures from the prior RC.
if($hostText.IndexOf('if (NativeMethods.GetCursorPos(out point))',[StringComparison]::Ordinal) -ge 0){throw 'Staged native streaming cursor still inherits Huymaier''s parked physical pointer.'}
if($hostText.IndexOf('double moveX = ApplyDeadzoneCurve(lx);',[StringComparison]::Ordinal) -ge 0){throw 'Staged native streaming movement still shapes X/Y independently.'}
if($runtime.IndexOf('Move-HcBrowserVirtualCursorDelta ($x*$maxPixelsPerSecond*$dt)',[StringComparison]::Ordinal) -ge 0){throw 'Staged browser analog cursor still emits per-poll delta scripts instead of RAF drive state.'}

# Confirm the helper is a standalone shipped executable and native streaming does
# not silently route back through WebView when an installed AUMID is available.
if($runtime.IndexOf("if([string]::Equals(`$mode,'Native',[StringComparison]::OrdinalIgnoreCase) -and `$aumid -and `$category -eq 'Streaming')",[StringComparison]::Ordinal) -lt 0){throw 'Staged native Streaming category is not routed through the native cursor host.'}
if($runtime.IndexOf("Start-Process -FilePath `$script:HcStreamingCursorHostPath",[StringComparison]::Ordinal) -lt 0){throw 'Staged streaming runtime does not start the isolated cursor host.'}

# The Wii cover fix is intentionally separate from the pretty display name. Scope
# the negative check to QueueConsoleArtworkRefresh only: other platform code may
# legitimately call FindEmulatorArtwork with game.Name elsewhere in this class.
$refreshStart=$nintendo.IndexOf('private void QueueConsoleArtworkRefresh()',[StringComparison]::Ordinal)
$refreshEnd=$nintendo.IndexOf('private void LaunchGame(',[math]::Max(0,$refreshStart),[StringComparison]::Ordinal)
if($refreshStart -lt 0 -or $refreshEnd -le $refreshStart){throw 'Staged Wii artwork alias gate could not isolate QueueConsoleArtworkRefresh.'}
$refreshScope=$nintendo.Substring($refreshStart,$refreshEnd-$refreshStart)
foreach($required in @(
    'HUYMAIER_WII_ARTWORK_ALIAS_V1',
    'string legacyKey=CleanName(Path.GetFileNameWithoutExtension(game.Path))',
    'string artworkTitle=game.Name',
    'FindDolphinArtwork(game.Path,artworkTitle)',
    'FindEmulatorArtwork(game.Path,artworkTitle)'
)){
    if($refreshScope.IndexOf($required,[StringComparison]::Ordinal) -lt 0){throw "Staged QueueConsoleArtworkRefresh is missing Wii artwork alias invariant: $required"}
}
$oldRefresh='string cover=FindEmulatorArtwork(game.Path,game.Name);if(String.IsNullOrWhiteSpace(cover))cover=TryDownloadConsoleCover(game);'
if($refreshScope.IndexOf($oldRefresh,[StringComparison]::Ordinal) -ge 0){throw 'Staged QueueConsoleArtworkRefresh still uses the pretty display name as the Wii/GameCube artwork key.'}

$validation=Get-Content -Raw -LiteralPath $ValidationPath -Encoding UTF8|ConvertFrom-Json
$validation|Add-Member -NotePropertyName smoothBrowserCursorGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName browserRafCursorGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName cursorSpeedSettingGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName nativeStreamingControllerGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName nativeStreamingBackgroundInputGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName nativeStreamingFullscreenGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName streamingAppArtworkGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName wiiArtworkAliasGate -NotePropertyValue 'success' -Force
$validation|ConvertTo-Json -Depth 20|Set-Content -LiteralPath $ValidationPath -Encoding UTF8

Write-Host 'Staged v0.26.5 RAF browser cursor, cursor speed, native streaming background-input/fullscreen, app artwork and Wii artwork-alias gates passed.'
