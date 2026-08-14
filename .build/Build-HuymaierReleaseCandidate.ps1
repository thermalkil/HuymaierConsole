param(
    [Parameter(Mandatory=$true)][string]$TriggerPath
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'

$coreBuilder=Join-Path $PSScriptRoot 'Build-HuymaierReleaseCandidate.Core.ps1'
$versionStamper=Join-Path $PSScriptRoot 'Set-HuymaierCandidateVersion.ps1'
$startupOptimizer=Join-Path $PSScriptRoot 'Optimize-HuymaierStartup.ps1'
$nintendoOptimizer=Join-Path $PSScriptRoot 'Optimize-NintendoLibraryOwnership.ps1'
$providerOptimizer=Join-Path $PSScriptRoot 'Optimize-ProviderDownloads.ps1'
$epicWatchOptimizer=Join-Path $PSScriptRoot 'Optimize-EpicTelemetryWatch.ps1'
$epicCoordinatorOptimizer=Join-Path $PSScriptRoot 'Optimize-ProviderCoordinatorEpicActivation.ps1'
$workspace=$env:GITHUB_WORKSPACE
if([string]::IsNullOrWhiteSpace($workspace)){$workspace=(Split-Path -Parent $PSScriptRoot)}
$coreSource=Join-Path $workspace 'HuymaierConsole.ps1'
$manifestSource=Join-Path $workspace 'manifest.json'
$appxManifestSource=Join-Path $workspace 'FSEPackage\AppxManifest.xml'
$bootstrapSource=Join-Path $workspace 'HuymaierBootstrap.ps1'
$nativeConsoleSource=Join-Path $workspace 'Native\HuymaierConsole.ConsolePlatforms.cs'
$providerModuleSource=Join-Path $workspace 'HuymaierGameProviders.ps1'
$providerWorkerSource=Join-Path $workspace 'HuymaierGameProviderWorker.ps1'
$progressWorkerSource=Join-Path $workspace 'HuymaierProviderProgressWorker.ps1'
$coordinatorSource=Join-Path $workspace 'HuymaierProviderTelemetryCoordinator.ps1'

$requiredFiles=@(
    $coreBuilder,$versionStamper,$startupOptimizer,$nintendoOptimizer,$providerOptimizer,$epicWatchOptimizer,$epicCoordinatorOptimizer,
    $coreSource,$manifestSource,$appxManifestSource,$bootstrapSource,$nativeConsoleSource,$providerModuleSource,$providerWorkerSource,$progressWorkerSource,$coordinatorSource
)
foreach($required in $requiredFiles){if(-not(Test-Path -LiteralPath $required -PathType Leaf)){throw "Candidate optimization wrapper is missing required file: $required"}}

$originals=@{}
foreach($path in @($coreSource,$manifestSource,$appxManifestSource,$bootstrapSource,$nativeConsoleSource,$providerModuleSource,$providerWorkerSource,$progressWorkerSource,$coordinatorSource)){$originals[$path]=[IO.File]::ReadAllBytes($path)}
try{
    & $versionStamper -TriggerPath $TriggerPath -CorePath $coreSource -ManifestPath $manifestSource -AppxManifestPath $appxManifestSource
    & $startupOptimizer -CorePath $coreSource
    & $nintendoOptimizer -NativePath $nativeConsoleSource
    & $providerOptimizer -ProviderModulePath $providerModuleSource -ProviderWorkerPath $providerWorkerSource -ProgressWorkerPath $progressWorkerSource -CoordinatorPath $coordinatorSource
    & $epicWatchOptimizer -BootstrapPath $bootstrapSource
    & $epicCoordinatorOptimizer -CoordinatorPath $coordinatorSource
    & $coreBuilder -TriggerPath $TriggerPath
}finally{
    # Candidate bytes are built from deterministic optimized/stamped workspace sources,
    # while the checkout is restored exactly for later source/freeze diff gates.
    foreach($path in $originals.Keys){[IO.File]::WriteAllBytes([string]$path,[byte[]]$originals[$path])}
}
