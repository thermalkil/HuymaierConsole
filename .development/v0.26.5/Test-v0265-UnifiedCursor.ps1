Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$temp=Join-Path $env:TEMP ('hc-v0265-unifiedcursor-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $temp|Out-Null
function Copy-TestFile([string]$Relative){$src=Join-Path $repo $Relative;if(-not(Test-Path -LiteralPath $src -PathType Leaf)){throw "Missing source: $Relative"};$dst=Join-Path $temp ([IO.Path]::GetFileName($Relative));Copy-Item $src $dst -Force;return $dst}
function Assert-Contains([string]$Text,[string]$Needle,[string]$Message){if($Text.IndexOf($Needle,[StringComparison]::Ordinal) -lt 0){throw $Message}}
function Assert-Ps51Parse([string]$Path){$tokens=$null;$errors=$null;[void][Management.Automation.Language.Parser]::ParseFile($Path,[ref]$tokens,[ref]$errors);if($errors.Count){throw (($errors|ForEach-Object{"$($_.Extent.StartLineNumber): $($_.Message)"}) -join '; ')}}
function Assert-X64Pe([string]$Path){$bytes=[IO.File]::ReadAllBytes($Path);$pe=[BitConverter]::ToInt32($bytes,0x3c);$machine=[BitConverter]::ToUInt16($bytes,$pe+4);if($machine -ne 0x8664){throw ("Not x64: 0x{0:X4}" -f $machine)}}
try{
    $core=Copy-TestFile 'HuymaierConsole.ps1'
    $bootstrap=Copy-TestFile 'HuymaierBootstrap.ps1'
    $installer=Copy-TestFile 'Install-HuymaierConsole.ps1'
    $builder=Copy-TestFile '.build\Build-HuymaierReleaseCandidate.Core.ps1'
    & (Join-Path $repo '.build\Optimize-ProviderConcurrencyPreflight.ps1') -BootstrapPath $bootstrap -InstallerScriptPath $installer
    & (Join-Path $repo '.build\Optimize-AppLibrary.ps1') -CorePath $core -BootstrapPath $bootstrap -InstallerScriptPath $installer
    & (Join-Path $repo '.build\Optimize-StreamingController.ps1') -CorePath $core -BootstrapPath $bootstrap -InstallerScriptPath $installer -CoreBuilderPath $builder
    & (Join-Path $repo '.build\Optimize-UnifiedCursor.ps1') -CorePath $core -BootstrapPath $bootstrap -InstallerScriptPath $installer -CoreBuilderPath $builder
    foreach($path in @($core,$bootstrap,$installer,$builder,(Join-Path $repo 'HuymaierUnifiedCursor.ps1'),(Join-Path $repo '.build\Optimize-UnifiedCursor.ps1'))){Assert-Ps51Parse $path}
    $coreText=Get-Content -Raw $core -Encoding UTF8
    $bootstrapText=Get-Content -Raw $bootstrap -Encoding UTF8
    $installerText=Get-Content -Raw $installer -Encoding UTF8
    $builderText=Get-Content -Raw $builder -Encoding UTF8
    $runtime=Get-Content -Raw (Join-Path $repo 'HuymaierUnifiedCursor.ps1') -Encoding UTF8
    $hostText=Get-Content -Raw (Join-Path $repo 'Native\HuymaierUnifiedCursorHost.cs') -Encoding UTF8
    foreach($required in @('HUYMAIER_UNIFIED_CURSOR_RUNTIME_V1','HuymaierUnifiedCursor.ps1')){Assert-Contains $coreText $required "Core unified cursor loader missing $required"}
    foreach($required in @('HUYMAIER_UNIFIED_CURSOR_PREFLIGHT_V1','HuymaierUnifiedCursor.ps1','Unified cursor runtime')){Assert-Contains $bootstrapText $required "Bootstrap unified cursor preflight missing $required"}
    foreach($required in @('HUYMAIER_UNIFIED_CURSOR_INSTALLER_CACHE_V1','HuymaierUnifiedCursor.ps1')){Assert-Contains $installerText $required "Installer unified cursor cache missing $required"}
    foreach($required in @('HUYMAIER_UNIFIED_CURSOR_HOST_BUILD_V1','HuymaierUnifiedCursorHost.cs','HuymaierUnifiedCursorHost.exe','HuymaierUnifiedCursorHost.exe is not x64')){Assert-Contains $builderText $required "Builder unified cursor contract missing $required"}
    foreach($required in @('Set-HcUnifiedCursorContext','browser-web','browser-toolbar','Start-HcUnifiedShellCursorHost','Start-HcUnifiedStreamingCursorHost','function Show-HcBrowserVirtualCursor','function Move-HcBrowserVirtualCursor','function Update-HcSmoothBrowserPointer','NATIVE CURSOR','Start-HcNativeStreamingApp','--mode streaming','--mode shell')){Assert-Contains $runtime $required "Unified cursor runtime missing $required"}
    foreach($required in @('SetSystemCursor','SPI_SETCURSORS','OCR_NORMAL','OCR_HAND','OCR_IBEAM','CreateGoldCursor','SystemParametersInfo','HC_ReadGamepadPointerState','Math.Sqrt(rawX * rawX + rawY * rawY)','1500.0','mode == "shell"','mode == "streaming"','GetAncestor','GWL_EXSTYLE','WS_EX_WINDOWEDGE','DwmSetWindowAttribute','DWMWA_NCRENDERING_POLICY','VK_F11','VK_LWIN','VK_SHIFT','VK_RETURN','SWP_FRAMECHANGED','ApplyFullscreen','TryNativeFullscreenShortcut')){Assert-Contains $hostText $required "Unified native host missing $required"}
    if($hostText.IndexOf('CursorOverlay',[StringComparison]::Ordinal) -ge 0){throw 'Unified cursor host must use the actual system cursor, not a second overlay cursor.'}
    if($runtime.IndexOf('Move-HcBrowserVirtualCursorDelta ($x*',[StringComparison]::Ordinal) -ge 0){throw 'Unified browser still contains a JS movement path.'}
    Add-Type -AssemblyName System.Windows.Forms,System.Drawing
    $csc=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
    if(-not(Test-Path $csc)){throw 'Framework64 csc missing'}
    $out=Join-Path $temp 'HuymaierUnifiedCursorHost.exe'
    $args=@('/noconfig','/nologo','/target:winexe','/platform:x64','/optimize+',('/out:'+$out),('/reference:'+([Uri].Assembly.Location)),('/reference:'+([Windows.Forms.Form].Assembly.Location)),('/reference:'+([Drawing.Bitmap].Assembly.Location)),(Join-Path $repo 'Native\HuymaierUnifiedCursorHost.cs'))
    & $csc @args
    if($LASTEXITCODE -ne 0 -or -not(Test-Path $out)){throw 'Unified cursor host x64 compilation failed'}
    Assert-X64Pe $out
    $sources=@(Get-Content (Join-Path $repo '.source\source-files.txt') -Encoding UTF8)
    foreach($required in @('HuymaierUnifiedCursor.ps1','Native/HuymaierUnifiedCursorHost.cs')){if($sources -notcontains $required){throw "Release source list missing $required"}}
    Write-Host 'v0.26.5 unified system cursor, native Web pointer and strengthened streaming fullscreen gates passed.'
}finally{Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue}
