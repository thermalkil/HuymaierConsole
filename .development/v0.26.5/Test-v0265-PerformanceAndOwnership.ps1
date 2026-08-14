param()
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'

$repo=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$core=Join-Path $repo 'HuymaierConsole.ps1'
$native=Join-Path $repo 'Native\HuymaierConsole.ConsolePlatforms.cs'
$bootstrap=Join-Path $repo 'HuymaierBootstrap.ps1'
$installer=Join-Path $repo 'Install-HuymaierConsole.ps1'
$providerModule=Join-Path $repo 'HuymaierGameProviders.ps1'
$providerWorker=Join-Path $repo 'HuymaierGameProviderWorker.ps1'
$progressWorker=Join-Path $repo 'HuymaierProviderProgressWorker.ps1'
$coordinator=Join-Path $repo 'HuymaierProviderTelemetryCoordinator.ps1'
$telemetry=Join-Path $repo 'HuymaierProviderTelemetry.ps1'
$startupOptimizer=Join-Path $repo '.build\Optimize-HuymaierStartup.ps1'
$nintendoOptimizer=Join-Path $repo '.build\Optimize-NintendoLibraryOwnership.ps1'
$providerOptimizer=Join-Path $repo '.build\Optimize-ProviderDownloads.ps1'
$epicWatchOptimizer=Join-Path $repo '.build\Optimize-EpicTelemetryWatch.ps1'
$epicCoordinatorOptimizer=Join-Path $repo '.build\Optimize-ProviderCoordinatorEpicActivation.ps1'

foreach($required in @($core,$native,$bootstrap,$installer,$providerModule,$providerWorker,$progressWorker,$coordinator,$telemetry,$startupOptimizer,$nintendoOptimizer,$providerOptimizer,$epicWatchOptimizer,$epicCoordinatorOptimizer)){
    if(-not(Test-Path -LiteralPath $required -PathType Leaf)){throw "Required v0.26.5 source is missing: $required"}
}

function Assert-PowerShellParse {
    param([string]$Path)
    $tokens=$null;$errors=$null
    [void][Management.Automation.Language.Parser]::ParseFile($Path,[ref]$tokens,[ref]$errors)
    if($errors.Count){$errors|ForEach-Object{Write-Host "$Path line $($_.Extent.StartLineNumber): $($_.Message)"};throw "PowerShell parse failed: $Path"}
}

foreach($ps1 in @($bootstrap,$installer,$providerModule,$providerWorker,$progressWorker,$coordinator,$telemetry,$startupOptimizer,$nintendoOptimizer,$providerOptimizer,$epicWatchOptimizer,$epicCoordinatorOptimizer)){Assert-PowerShellParse $ps1}

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
foreach($marker in @('Calculating ETA','Read-ProviderOutputTail','Start-WriteObservation','Update-ObservedWriteBytes','Incremental destination writes','Installing','Downloading','TelemetryKind')){if($progressText -notmatch [regex]::Escape($marker)){throw "Provider progress invariant missing: $marker"}}
if($progressText -match 'Directory\]::EnumerateFiles|Directory\.EnumerateFiles'){throw 'Provider fallback telemetry must not recursively rescan the install tree.'}
$coordinatorText=Get-Content -Raw -LiteralPath $coordinator -Encoding UTF8
foreach($marker in @("@('GOG','Amazon')","@('Install','Update')",'TelemetrySource','InstallSpeedBytesPerSec','TransferSpeedBytesPerSec')){if($coordinatorText -notmatch [regex]::Escape($marker)){throw "Provider coordinator source invariant missing: $marker"}}

$tempRoot=Join-Path $env:TEMP ('huymaier-v0265-validation-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tempRoot|Out-Null
try{
    $tempCore=Join-Path $tempRoot 'HuymaierConsole.ps1'
    $tempNative=Join-Path $tempRoot 'HuymaierConsole.ConsolePlatforms.cs'
    $tempBootstrap=Join-Path $tempRoot 'HuymaierBootstrap.ps1'
    $tempProviderModule=Join-Path $tempRoot 'HuymaierGameProviders.ps1'
    $tempProviderWorker=Join-Path $tempRoot 'HuymaierGameProviderWorker.ps1'
    $tempProgressWorker=Join-Path $tempRoot 'HuymaierProviderProgressWorker.ps1'
    $tempCoordinator=Join-Path $tempRoot 'HuymaierProviderTelemetryCoordinator.ps1'
    Copy-Item -LiteralPath $core -Destination $tempCore -Force
    Copy-Item -LiteralPath $native -Destination $tempNative -Force
    Copy-Item -LiteralPath $bootstrap -Destination $tempBootstrap -Force
    Copy-Item -LiteralPath $providerModule -Destination $tempProviderModule -Force
    Copy-Item -LiteralPath $providerWorker -Destination $tempProviderWorker -Force
    Copy-Item -LiteralPath $progressWorker -Destination $tempProgressWorker -Force
    Copy-Item -LiteralPath $coordinator -Destination $tempCoordinator -Force

    & $startupOptimizer -CorePath $tempCore
    & $nintendoOptimizer -NativePath $tempNative
    & $providerOptimizer -ProviderModulePath $tempProviderModule -ProviderWorkerPath $tempProviderWorker -ProgressWorkerPath $tempProgressWorker -CoordinatorPath $tempCoordinator
    & $epicWatchOptimizer -BootstrapPath $tempBootstrap
    & $epicCoordinatorOptimizer -CoordinatorPath $tempCoordinator

    foreach($ps1 in @($tempCore,$tempBootstrap,$tempProviderModule,$tempProviderWorker,$tempProgressWorker,$tempCoordinator)){Assert-PowerShellParse $ps1}

    $optimizedCore=Get-Content -Raw -LiteralPath $tempCore -Encoding UTF8
    foreach($marker in @(
        "'HuymaierConsole.Native.DisplayBridge' -as [type]",
        "'HuymaierConsole.Native.AudioBridge' -as [type]",
        "'HuymaierConsole.Native.LegacyJoystick' -as [type]",
        "'HuymaierConsole.Native.FrameRateMonitor' -as [type]",
        '$script:HcStartupStopwatch=[Diagnostics.Stopwatch]::StartNew()',
        '$script:Window.Add_ContentRendered',
        'Startup timing: entering ShowDialog at',
        'Startup timing: first rendered frame at',
        'Startup timing: deferred shell services ready at',
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

    $optimizedProviderWorker=Get-Content -Raw -LiteralPath $tempProviderWorker -Encoding UTF8
    foreach($marker in @('Get-LegendaryTransferPhase','Format-ProviderEtaValue','Installing','Calculating ETA','Write-State $true $phase')){if($optimizedProviderWorker -notmatch [regex]::Escape($marker)){throw "Epic normalized telemetry marker missing: $marker"}}
    $optimizedProviderModule=Get-Content -Raw -LiteralPath $tempProviderModule -Encoding UTF8
    foreach($marker in @('Get-ProviderDownloadDisplay','Format-ProviderDownloadEta','InstallProcessedBytes','InstallSpeedBytesPerSec','Progress calculating…')){if($optimizedProviderModule -notmatch [regex]::Escape($marker)){throw "Downloads presentation marker missing: $marker"}}
    $optimizedProgress=Get-Content -Raw -LiteralPath $tempProgressWorker -Encoding UTF8
    if($optimizedProgress -notmatch [regex]::Escape("ValidateSet('Epic','GOG','Amazon')")){throw 'Fallback progress sampler does not cover Epic, GOG and Amazon.'}
    if($optimizedProgress -match 'Directory\]::EnumerateFiles|Directory\.EnumerateFiles'){throw 'Transformed fallback sampler reintroduced recursive directory scans.'}
    $optimizedCoordinator=Get-Content -Raw -LiteralPath $tempCoordinator -Encoding UTF8
    $allProviderList="@('Epic','GOG','Amazon')"
    if(([regex]::Matches($optimizedCoordinator,[regex]::Escape($allProviderList))).Count -lt 2){throw 'Fallback telemetry coordinator did not expand both guard and activation paths to Epic, GOG and Amazon.'}
    if($optimizedCoordinator -match [regex]::Escape("@('GOG','Amazon')")){throw 'Fallback telemetry coordinator still contains a GOG/Amazon-only activation path.'}
    $optimizedBootstrap=Get-Content -Raw -LiteralPath $tempBootstrap -Encoding UTF8
    if($optimizedBootstrap -notmatch [regex]::Escape($allProviderList)){throw 'Event-driven telemetry watcher does not wake for Epic, GOG and Amazon.'}

    # Confirm PlayStation-specific presentation sources remain outside all v0.26.5 transforms.
    foreach($optimizerPath in @($startupOptimizer,$nintendoOptimizer,$providerOptimizer,$epicWatchOptimizer,$epicCoordinatorOptimizer)){
        $optimizerText=Get-Content -Raw -LiteralPath $optimizerPath -Encoding UTF8
        if($optimizerText -match 'HuymaierConsole\.Ps1\.cs'){throw "v0.26.5 optimizer targets frozen PS1 presentation source: $optimizerPath"}
    }
    $nintendoOptimizerText=Get-Content -Raw -LiteralPath $nintendoOptimizer -Encoding UTF8
    if($nintendoOptimizerText -match 'PS2|PS3'){throw 'Nintendo ownership optimizer must not target PS2/PS3 presentation.'}

    Write-Host 'v0.26.5 startup timing, normalized provider telemetry, complete Epic coordinator activation, incremental transfer observation and Nintendo ownership validation passed.'
}finally{
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
