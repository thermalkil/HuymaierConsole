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
    'HUYMAIER_UNIFIED_CURSOR_RUNTIME_V1',
    "`$script:UnifiedCursorModulePath = Join-Path `$script:BaseDir 'HuymaierUnifiedCursor.ps1'",
    'Unified cursor module load failed'
)
$bootstrap=Require-Text 'HuymaierBootstrap.ps1' @(
    'HUYMAIER_STREAMING_CONTROLLER_PREFLIGHT_V1','HuymaierStreamingController.ps1','Streaming controller runtime',
    'HUYMAIER_UNIFIED_CURSOR_PREFLIGHT_V1','HuymaierUnifiedCursor.ps1','Unified cursor runtime'
)
$installer=Require-Text 'Install-HuymaierConsole.ps1' @(
    'HUYMAIER_STREAMING_CONTROLLER_INSTALLER_CACHE_V1','HuymaierStreamingController.ps1',
    'HUYMAIER_UNIFIED_CURSOR_INSTALLER_CACHE_V1','HuymaierUnifiedCursor.ps1'
)
$runtime=Require-Text 'HuymaierStreamingController.ps1' @(
    'ControllerCursorSpeed','controller-cursor-speed-slider','Convert-HcCursorAxis','Update-HcSmoothBrowserPointer','Move-HcBrowserVirtualCursorDelta','Scroll-HcBrowserVirtualCursorDelta',
    'Set-HcBrowserAnalogDrive','Stop-HcBrowserAnalogDrive','requestAnimationFrame(tick)','__hcCursorDriveState','__hcCursorDrive=(x,y,speed)','magnitude=[math]::Sqrt',
    '1500.0','Right Stick Scroll','Start-HcNativeStreamingApp','HuymaierStreamingCursorHost.exe','Get-HcAppxArtworkCandidate','favicon.ico','ControllerMouseEnabled','FullscreenPresentation',
    'Native app mode uses the installed Windows streaming app directly; WebView is not involved.'
)
$unified=Require-Text 'HuymaierUnifiedCursor.ps1' @(
    'Set-HcUnifiedCursorContext','browser-web','browser-toolbar','Start-HcUnifiedShellCursorHost','Start-HcUnifiedStreamingCursorHost',
    'function Show-HcBrowserVirtualCursor','function Move-HcBrowserVirtualCursor','function Update-HcSmoothBrowserPointer','Hide-HcBrowserJsCursorNow',
    'NATIVE CURSOR','HuymaierUnifiedCursorHost.exe','--mode shell','--mode streaming','function Start-HcNativeStreamingApp'
)
$managed=Require-Text 'Native\HuymaierConsole.GameInput.cs' @(
    'public const string Version = "0.26.5";','public const string Architecture = "x64";','HuymaierPointerState','HuymaierPointerInput','HC_ReadGamepadPointerState','ReadPointerState'
)
$bridge=Require-Text 'Native\HuymaierGameInputBridge.cpp' @(
    'HC_ReadGamepadPointerState','GetCurrentReading(GameInputKindGamepad','leftThumbstickX','rightThumbstickY','GameInputGamepadA','GameInputGamepadX',
    'GameInputEnableBackgroundInput','GameInputEnableBackgroundGuideButton','GameInputEnableBackgroundShareButton',
    'HuymaierConsole.PointerStateV1','TryReadSharedPointerState','OpenFileMappingW','GetTickCount64','if (TryReadSharedPointerState',
    'kSharedGuideBit','ConsumeSharedGuideEdge','g_sharedGuideDown','g_lastGuideDeliveredAt','HC_ConsumeGuidePress','now - previous < 300'
)
$nativeInput=Require-Text 'HuymaierNativeInput.cs' @(
    'HUYMAIER_SONY_POINTER_SHARED_STATE_V1','MemoryMappedFile.CreateOrOpen','Local\\HuymaierConsole.PointerStateV1',
    'PublishPointerState(productId, lx, ly, rx, ry, buttons1, buttons2, buttons3)','byte rx = report[stateBase + 2]','byte ry = report[stateBase + 3]',
    'NormalizePointerAxis(ly, true)','BuildPointerButtons(buttons1, buttons2, buttons3)','pointerButtons |= 0x0100','GetTickCount64()'
)
$overlay=Require-Text 'Native\HuymaierConsole.SystemOverlay.cs' @(
    'HUYMAIER_EXTERNAL_GAMEBAR_OWNER_V1','GWLP_HWNDPARENT','SetWindowLongPtr64','AttachExternalOwner(handle, targetWindow)','SetWindowOwner','DetachExternalOwner','externalOwnerWindow','HWND_TOPMOST'
)
$hostText=Require-Text 'Native\HuymaierStreamingCursorHost.cs' @(
    'HC_ReadGamepadPointerState','WS_POPUP','SetWindowPos','MonitorFromWindow','ApplyDeadzoneCurve','1500.0','LeftClick','ShowOnScreenKeyboard','MOUSEEVENTF_WHEEL',
    'TextInputHost','parentProcessId','IsPointerForegroundAllowed','RestoreWindow','launchBounds','SetCursorPos((int)Math.Round(cursorX)','Math.Sqrt(rawX * rawX + rawY * rawY)','magnitude > 0.14'
)
$unifiedHost=Require-Text 'Native\HuymaierUnifiedCursorHost.cs' @(
    'SetSystemCursor','SPI_SETCURSORS','OCR_NORMAL','OCR_HAND','OCR_IBEAM','CreateGoldCursor','SystemParametersInfo',
    'HC_ReadGamepadPointerState','Math.Sqrt(rawX * rawX + rawY * rawY)','1500.0','mode == "shell"','mode == "streaming"',
    'GetAncestor','GWL_EXSTYLE','WS_EX_WINDOWEDGE','DwmSetWindowAttribute','DWMWA_NCRENDERING_POLICY','VK_F11','VK_LWIN','VK_SHIFT','VK_RETURN',
    'SWP_FRAMECHANGED','ApplyFullscreen','TryNativeFullscreenShortcut'
)
$nintendo=Require-Text 'Native\HuymaierConsole.ConsolePlatforms.cs' @(
    'HUYMAIER_WII_ARTWORK_ALIAS_V1','string legacyKey=CleanName(Path.GetFileNameWithoutExtension(game.Path))','string cover=FindDolphinArtwork(game.Path,artworkTitle)','FindEmulatorArtwork(game.Path,artworkTitle)'
)

foreach($scriptFile in @('HuymaierConsole.ps1','HuymaierBootstrap.ps1','Install-HuymaierConsole.ps1','HuymaierStreamingController.ps1','HuymaierUnifiedCursor.ps1')){Assert-Ps51Parse $scriptFile}
Assert-X64Pe 'HuymaierStreamingCursorHost.exe'
Assert-X64Pe 'HuymaierUnifiedCursorHost.exe'
Assert-X64Pe 'HuymaierConsole.exe'
Require-File 'HuymaierGameInputBridge.dll'|Out-Null

# Explicitly reject cursor and overlay failure modes reported from prior RCs.
if($hostText.IndexOf('if (NativeMethods.GetCursorPos(out point))',[StringComparison]::Ordinal) -ge 0){throw 'Staged legacy native streaming cursor still inherits Huymaier''s parked physical pointer.'}
if($hostText.IndexOf('double moveX = ApplyDeadzoneCurve(lx);',[StringComparison]::Ordinal) -ge 0){throw 'Staged legacy native streaming movement still shapes X/Y independently.'}
if($unifiedHost.IndexOf('CursorOverlay',[StringComparison]::Ordinal) -ge 0){throw 'Staged unified cursor still draws a second overlay instead of replacing the Windows cursor.'}
if($unified.IndexOf('Move-HcBrowserVirtualCursorDelta ($x*',[StringComparison]::Ordinal) -ge 0){throw 'Staged unified Web pointer still contains JavaScript delta movement.'}
if($overlay.IndexOf('DisposeTaskPreviews(); telemetryTimer.Stop();`r`n            try { Hide();',[StringComparison]::Ordinal) -ge 0){throw 'Staged external Game Bar still hides without detaching the native app owner.'}

if($unified.IndexOf("Start-Process -FilePath `$script:HcUnifiedCursorHostPath",[StringComparison]::Ordinal) -lt 0){throw 'Staged native streaming/Web runtime does not start the unified native cursor host.'}
if($unified.IndexOf("Set-HcUnifiedCursorContext 'browser-web'",[StringComparison]::Ordinal) -lt 0){throw 'Staged Web browser does not route into native browser-web cursor mode.'}
if($unifiedHost.IndexOf('style &= ~(NativeMethods.WS_CAPTION',[StringComparison]::Ordinal) -lt 0 -or $unifiedHost.IndexOf('exStyle &= ~(NativeMethods.WS_EX_DLGMODALFRAME',[StringComparison]::Ordinal) -lt 0){throw 'Staged native streaming fullscreen does not strip standard/non-client window chrome.'}

# The Wii cover fix is intentionally separate from the pretty display name.
$refreshStart=$nintendo.IndexOf('private void QueueConsoleArtworkRefresh()',[StringComparison]::Ordinal)
$refreshEnd=$nintendo.IndexOf('private void LaunchGame(',[math]::Max(0,$refreshStart),[StringComparison]::Ordinal)
if($refreshStart -lt 0 -or $refreshEnd -le $refreshStart){throw 'Staged Wii artwork alias gate could not isolate QueueConsoleArtworkRefresh.'}
$refreshScope=$nintendo.Substring($refreshStart,$refreshEnd-$refreshStart)
foreach($required in @('HUYMAIER_WII_ARTWORK_ALIAS_V1','string legacyKey=CleanName(Path.GetFileNameWithoutExtension(game.Path))','string artworkTitle=game.Name','FindDolphinArtwork(game.Path,artworkTitle)','FindEmulatorArtwork(game.Path,artworkTitle)')){
    if($refreshScope.IndexOf($required,[StringComparison]::Ordinal) -lt 0){throw "Staged QueueConsoleArtworkRefresh is missing Wii artwork alias invariant: $required"}
}
$oldRefresh='string cover=FindEmulatorArtwork(game.Path,game.Name);if(String.IsNullOrWhiteSpace(cover))cover=TryDownloadConsoleCover(game);'
if($refreshScope.IndexOf($oldRefresh,[StringComparison]::Ordinal) -ge 0){throw 'Staged QueueConsoleArtworkRefresh still uses the pretty display name as the Wii/GameCube artwork key.'}

$validation=Get-Content -Raw -LiteralPath $ValidationPath -Encoding UTF8|ConvertFrom-Json
$validation|Add-Member -NotePropertyName smoothBrowserCursorGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName browserRafCursorGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName unifiedSystemCursorGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName nativeWebPointerGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName cursorSpeedSettingGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName nativeStreamingControllerGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName nativeStreamingBackgroundInputGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName sonyHidPointerBackendGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName sonyHidGuideGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName externalNativeGameBarGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName nativeStreamingFullscreenGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName nativeStreamingChromeSuppressionGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName streamingAppArtworkGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName wiiArtworkAliasGate -NotePropertyValue 'success' -Force
$validation|ConvertTo-Json -Depth 20|Set-Content -LiteralPath $ValidationPath -Encoding UTF8

Write-Host 'Staged v0.26.5 unified system cursor, native Web pointer, Sony HID pointer/Guide, external Game Bar, stronger native fullscreen and Wii artwork-alias gates passed.'
