Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'

$repo=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$temp=Join-Path $env:TEMP ('hc-v0265-streaming-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $temp|Out-Null

function Copy-TestFile([string]$Relative){
    $source=Join-Path $repo $Relative
    if(-not(Test-Path -LiteralPath $source -PathType Leaf)){throw "Required streaming source is missing: $Relative"}
    $target=Join-Path $temp ([IO.Path]::GetFileName($Relative))
    Copy-Item -LiteralPath $source -Destination $target -Force
    return $target
}
function Assert-Contains([string]$Text,[string]$Needle,[string]$Message){if($Text.IndexOf($Needle,[StringComparison]::Ordinal) -lt 0){throw $Message}}
function Assert-Ps51Parse([string]$Path){
    $tokens=$null;$errors=$null
    [void][Management.Automation.Language.Parser]::ParseFile($Path,[ref]$tokens,[ref]$errors)
    if($errors.Count -gt 0){$detail=($errors|ForEach-Object{"line $($_.Extent.StartLineNumber): $($_.Message)"}) -join '; ';throw "PowerShell 5.1 parse failed for $([IO.Path]::GetFileName($Path)): $detail"}
}
function Assert-X64Pe([string]$Path){
    $bytes=[IO.File]::ReadAllBytes($Path)
    if($bytes.Length -lt 256){throw "PE file is too small: $Path"}
    $pe=[BitConverter]::ToInt32($bytes,0x3c)
    if($pe -lt 0 -or $pe+6 -ge $bytes.Length){throw "Invalid PE offset: $Path"}
    $machine=[BitConverter]::ToUInt16($bytes,$pe+4)
    if($machine -ne 0x8664){throw ("Expected x64 PE machine 0x8664, got 0x{0:X4}: {1}" -f $machine,$Path)}
}

try{
    $core=Copy-TestFile 'HuymaierConsole.ps1'
    $bootstrap=Copy-TestFile 'HuymaierBootstrap.ps1'
    $installer=Copy-TestFile 'Install-HuymaierConsole.ps1'
    $builder=Copy-TestFile '.build\Build-HuymaierReleaseCandidate.Core.ps1'

    & (Join-Path $repo '.build\Optimize-ProviderConcurrencyPreflight.ps1') -BootstrapPath $bootstrap -InstallerScriptPath $installer
    & (Join-Path $repo '.build\Optimize-AppLibrary.ps1') -CorePath $core -BootstrapPath $bootstrap -InstallerScriptPath $installer
    & (Join-Path $repo '.build\Optimize-StreamingController.ps1') -CorePath $core -BootstrapPath $bootstrap -InstallerScriptPath $installer -CoreBuilderPath $builder

    foreach($path in @($core,$bootstrap,$installer,$builder,(Join-Path $repo 'HuymaierStreamingController.ps1'),(Join-Path $repo '.build\Optimize-StreamingController.ps1'))){Assert-Ps51Parse $path}

    $coreText=Get-Content -Raw -LiteralPath $core -Encoding UTF8
    $bootstrapText=Get-Content -Raw -LiteralPath $bootstrap -Encoding UTF8
    $installerText=Get-Content -Raw -LiteralPath $installer -Encoding UTF8
    $builderText=Get-Content -Raw -LiteralPath $builder -Encoding UTF8
    $runtimeText=Get-Content -Raw -LiteralPath (Join-Path $repo 'HuymaierStreamingController.ps1') -Encoding UTF8
    $bridgeText=Get-Content -Raw -LiteralPath (Join-Path $repo 'Native\HuymaierGameInputBridge.cpp') -Encoding UTF8
    $managedText=Get-Content -Raw -LiteralPath (Join-Path $repo 'Native\HuymaierConsole.GameInput.cs') -Encoding UTF8
    $hostText=Get-Content -Raw -LiteralPath (Join-Path $repo 'Native\HuymaierStreamingCursorHost.cs') -Encoding UTF8

    foreach($required in @('HUYMAIER_STREAMING_CONTROLLER_RUNTIME_V1','HuymaierStreamingController.ps1')){Assert-Contains $coreText $required "Main shell is missing streaming-controller loader marker $required."}
    foreach($required in @('HuymaierStreamingController.ps1','Streaming controller runtime')){Assert-Contains $bootstrapText $required "Bootstrap streaming preflight is missing $required."}
    Assert-Contains $installerText 'HuymaierStreamingController.ps1' 'Installer syntax cache does not include streaming controller runtime.'
    foreach($required in @('HUYMAIER_STREAMING_CURSOR_HOST_BUILD_V1','HuymaierStreamingCursorHost.cs','HuymaierStreamingCursorHost.exe','HuymaierStreamingCursorHost.exe is not x64')){Assert-Contains $builderText $required "Release builder streaming host gate is missing $required."}

    foreach($required in @(
        'ControllerCursorSpeed','controller-cursor-speed-slider','Convert-HcCursorAxis','Update-HcSmoothBrowserPointer','Move-HcBrowserVirtualCursorDelta','Scroll-HcBrowserVirtualCursorDelta',
        'Set-HcBrowserAnalogDrive','Stop-HcBrowserAnalogDrive','requestAnimationFrame(tick)','__hcCursorDriveState','__hcCursorDrive=(x,y,speed)','magnitude=[math]::Sqrt',
        '1500.0','Right Stick Scroll','Start-HcNativeStreamingApp','HuymaierStreamingCursorHost.exe','Get-HcAppxArtworkCandidate','favicon.ico','FullscreenPresentation','ControllerMouseEnabled',
        'Native app mode uses the installed Windows streaming app directly; WebView is not involved.'
    )){Assert-Contains $runtimeText $required "Streaming controller runtime is missing $required."}

    foreach($required in @(
        'HC_ReadGamepadPointerState','GetCurrentReading(GameInputKindGamepad','leftThumbstickX','rightThumbstickY','GameInputGamepadA','GameInputGamepadX',
        'GameInputEnableBackgroundInput','GameInputEnableBackgroundGuideButton','GameInputEnableBackgroundShareButton'
    )){Assert-Contains $bridgeText $required "GameInput bridge pointer state/background policy is missing $required."}
    foreach($required in @('HuymaierPointerState','HuymaierPointerInput','HC_ReadGamepadPointerState','ReadPointerState')){Assert-Contains $managedText $required "Managed pointer bridge is missing $required."}
    foreach($required in @(
        'HC_ReadGamepadPointerState','WS_POPUP','SetWindowPos','MonitorFromWindow','ApplyDeadzoneCurve','1500.0','LeftClick','ShowOnScreenKeyboard','MOUSEEVENTF_WHEEL',
        'TextInputHost','parentProcessId','IsPointerForegroundAllowed','RestoreWindow','launchBounds','SetCursorPos((int)Math.Round(cursorX)','Math.Sqrt(rawX * rawX + rawY * rawY)','magnitude > 0.14'
    )){Assert-Contains $hostText $required "Native streaming cursor host is missing $required."}

    # Explicitly reject the two shipped RC failure patterns: inheriting the
    # shell's parked physical cursor and per-axis stick shaping for movement.
    if($hostText.IndexOf('if (NativeMethods.GetCursorPos(out point))',[StringComparison]::Ordinal) -ge 0){throw 'Native streaming cursor still inherits the parked shell pointer at launch.'}
    if($hostText.IndexOf('double moveX = ApplyDeadzoneCurve(lx);',[StringComparison]::Ordinal) -ge 0){throw 'Native streaming movement still uses axis-by-axis deadzone shaping.'}
    if($runtimeText.IndexOf('Move-HcBrowserVirtualCursorDelta ($x*$maxPixelsPerSecond*$dt)',[StringComparison]::Ordinal) -ge 0){throw 'Browser analog cursor still emits per-poll delta scripts instead of RAF drive state.'}

    Add-Type -AssemblyName System.Windows.Forms,System.Drawing
    $csc=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
    if(-not(Test-Path -LiteralPath $csc -PathType Leaf)){throw 'Framework64 csc.exe is missing.'}
    $systemRef=[Uri].Assembly.Location
    $formsRef=[Windows.Forms.Form].Assembly.Location
    $drawingRef=[Drawing.Bitmap].Assembly.Location
    $hostOut=Join-Path $temp 'HuymaierStreamingCursorHost.exe'
    $hostArgs=@('/noconfig','/nologo','/target:winexe','/platform:x64','/optimize+',('/out:'+$hostOut),('/reference:'+$systemRef),('/reference:'+$formsRef),('/reference:'+$drawingRef),(Join-Path $repo 'Native\HuymaierStreamingCursorHost.cs'))
    & $csc @hostArgs
    if($LASTEXITCODE -ne 0 -or -not(Test-Path -LiteralPath $hostOut -PathType Leaf)){throw 'Streaming cursor host x64 compilation failed.'}
    Assert-X64Pe $hostOut

    $managedOut=Join-Path $temp 'HuymaierGameInputManaged.dll'
    $managedArgs=@('/noconfig','/nologo','/target:library','/platform:x64','/optimize+',('/out:'+$managedOut),('/reference:'+$systemRef),(Join-Path $repo 'Native\HuymaierConsole.GameInput.cs'))
    & $csc @managedArgs
    if($LASTEXITCODE -ne 0 -or -not(Test-Path -LiteralPath $managedOut -PathType Leaf)){throw 'Managed GameInput pointer bridge x64 compilation failed.'}
    Assert-X64Pe $managedOut

    $sources=@(Get-Content -LiteralPath (Join-Path $repo '.source\source-files.txt') -Encoding UTF8)
    foreach($required in @('HuymaierStreamingController.ps1','Native/HuymaierStreamingCursorHost.cs')){if($sources -notcontains $required){throw "Release source payload is missing $required"}}

    Write-Host 'v0.26.5 native streaming background input, centered/radial cursor, RAF browser cursor, cursor-speed, fullscreen and app-artwork gates passed.'
}finally{
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
