param()
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'

$repo=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$core=Join-Path $repo 'HuymaierConsole.ps1'
$native=Join-Path $repo 'Native\HuymaierConsole.ConsolePlatforms.cs'
$startupOptimizer=Join-Path $repo '.build\Optimize-HuymaierStartup.ps1'
$nintendoOptimizer=Join-Path $repo '.build\Optimize-NintendoLibraryOwnership.ps1'
$bootstrap=Join-Path $repo 'HuymaierBootstrap.ps1'
$installer=Join-Path $repo 'Install-HuymaierConsole.ps1'
$progressWorker=Join-Path $repo 'HuymaierProviderProgressWorker.ps1'
$coordinator=Join-Path $repo 'HuymaierProviderTelemetryCoordinator.ps1'
$telemetry=Join-Path $repo 'HuymaierProviderTelemetry.ps1'

foreach($required in @($core,$native,$startupOptimizer,$nintendoOptimizer,$bootstrap,$installer,$progressWorker,$coordinator,$telemetry)){
    if(-not(Test-Path -LiteralPath $required -PathType Leaf)){throw "Required v0.26.5 source is missing: $required"}
}

function Assert-ContainsOnce {
    param([string]$Text,[string]$Value,[string]$Label)
    $first=$Text.IndexOf($Value,[StringComparison]::Ordinal)
    if($first -lt 0){throw "$Label is missing."}
    if($Text.IndexOf($Value,$first+$Value.Length,[StringComparison]::Ordinal) -ge 0){throw "$Label appears more than once."}
}

function Assert-PowerShellParse {
    param([string]$Path)
    $tokens=$null;$errors=$null
    [void][Management.Automation.Language.Parser]::ParseFile($Path,[ref]$tokens,[ref]$errors)
    if($errors.Count){$errors|ForEach-Object{Write-Host "$Path line $($_.Extent.StartLineNumber): $($_.Message)"};throw "PowerShell parse failed: $Path"}
}

foreach($ps1 in @($bootstrap,$installer,$progressWorker,$coordinator,$telemetry,$startupOptimizer,$nintendoOptimizer)){Assert-PowerShellParse $ps1}

$bootstrapText=Get-Content -Raw -LiteralPath $bootstrap -Encoding UTF8
foreach($marker in @(
    'startup-preflight-v1.json',
    'Test-PowerShellPreflightCache',
    'Start-ProviderTelemetryWatch',
    "@('Changed','Created')",
    'no telemetry PowerShell process is started during normal boot'
)){if($bootstrapText -notmatch [regex]::Escape($marker)){throw "Bootstrap performance/telemetry invariant missing: $marker"}}

$installerText=Get-Content -Raw -LiteralPath $installer -Encoding UTF8
foreach($marker in @('Write-HuymaierStartupPreflightCache','ValidationSource=''installer''')){if($installerText -notmatch [regex]::Escape($marker)){throw "Installer startup-cache invariant missing: $marker"}}

$progressText=Get-Content -Raw -LiteralPath $progressWorker -Encoding UTF8
foreach($marker in @('Calculating ETA','Read-ProviderOutputTail','Get-ObservedWriteBytes','Installing','Downloading','TelemetryKind')){if($progressText -notmatch [regex]::Escape($marker)){throw "Provider progress invariant missing: $marker"}}
$coordinatorText=Get-Content -Raw -LiteralPath $coordinator -Encoding UTF8
foreach($marker in @("@('GOG','Amazon')","@('Install','Update')",'TelemetrySource','InstallSpeedBytesPerSec','TransferSpeedBytesPerSec')){if($coordinatorText -notmatch [regex]::Escape($marker)){throw "Provider coordinator invariant missing: $marker"}}

$tempRoot=Join-Path $env:TEMP ('huymaier-v0265-validation-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tempRoot|Out-Null
try{
    $tempCore=Join-Path $tempRoot 'HuymaierConsole.ps1'
    $tempNative=Join-Path $tempRoot 'HuymaierConsole.ConsolePlatforms.cs'
    Copy-Item -LiteralPath $core -Destination $tempCore -Force
    Copy-Item -LiteralPath $native -Destination $tempNative -Force

    & $startupOptimizer -CorePath $tempCore
    & $nintendoOptimizer -NativePath $tempNative
    Assert-PowerShellParse $tempCore

    $optimizedCore=Get-Content -Raw -LiteralPath $tempCore -Encoding UTF8
    foreach($marker in @(
        "'HuymaierConsole.Native.DisplayBridge' -as [type]",
        "'HuymaierConsole.Native.AudioBridge' -as [type]",
        "'HuymaierConsole.Native.LegacyJoystick' -as [type]",
        "'HuymaierConsole.Native.FrameRateMonitor' -as [type]",
        '$script:Window.Add_ContentRendered',
        'Deferred post-first-frame shell services initialized.',
        'FromMilliseconds(1800)'
    )){if($optimizedCore -notmatch [regex]::Escape($marker)){throw "Optimized startup marker missing: $marker"}}
    if($optimizedCore -match [regex]::Escape('FromMilliseconds(700)')){throw 'Optimized runtime still uses the old 700 ms initial-scan delay.'}

    $optimizedNative=Get-Content -Raw -LiteralPath $tempNative -Encoding UTF8
    foreach($marker in @(
        'IsNintendoLibraryOwnedPath',
        'IsNintendoRawDiscForCurrentShell',
        'header[0x18] == 0x5D',
        'header[0x1C] == 0xC2',
        'if (!IsNintendoLibraryOwnedPath(path)) continue;'
    )){if($optimizedNative -notmatch [regex]::Escape($marker)){throw "Nintendo native ownership marker missing: $marker"}}

    # Confirm PlayStation-specific source files are outside both v0.26.5 transforms.
    $startupOptimizerText=Get-Content -Raw -LiteralPath $startupOptimizer -Encoding UTF8
    $nintendoOptimizerText=Get-Content -Raw -LiteralPath $nintendoOptimizer -Encoding UTF8
    if($startupOptimizerText -match 'HuymaierConsole\.Ps1\.cs' -or $nintendoOptimizerText -match 'HuymaierConsole\.Ps1\.cs'){throw 'v0.26.5 optimizers must not target PS1 presentation source.'}
    if($nintendoOptimizerText -match 'PS2|PS3'){throw 'Nintendo ownership optimizer must not target PS2/PS3 presentation.'}

    Write-Host 'v0.26.5 startup, provider telemetry and Nintendo ownership transformation validation passed.'
}finally{
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
