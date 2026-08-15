param(
    [Parameter(Mandatory=$true)][string]$TriggerPath
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'

$coreBuilder=Join-Path $PSScriptRoot 'Build-HuymaierReleaseCandidate.Core.ps1'
$versionStamper=Join-Path $PSScriptRoot 'Set-HuymaierCandidateVersion.ps1'
$startupOptimizer=Join-Path $PSScriptRoot 'Optimize-HuymaierStartup.ps1'
$nintendoOptimizer=Join-Path $PSScriptRoot 'Optimize-NintendoLibraryOwnership.ps1'
$nintendoNameOptimizer=Join-Path $PSScriptRoot 'Optimize-NintendoDisplayNames.ps1'
$dolphinOptimizer=Join-Path $PSScriptRoot 'Optimize-DolphinIntegration.ps1'
$wiiArtworkAliasOptimizer=Join-Path $PSScriptRoot 'Optimize-WiiArtworkAliases.ps1'
$gameCubeHubOptimizer=Join-Path $PSScriptRoot 'Optimize-GameCubeHubNavigation.ps1'
$appLibraryOptimizer=Join-Path $PSScriptRoot 'Optimize-AppLibrary.ps1'
$streamingControllerOptimizer=Join-Path $PSScriptRoot 'Optimize-StreamingController.ps1'
$unifiedCursorOptimizer=Join-Path $PSScriptRoot 'Optimize-UnifiedCursor.ps1'
$platformModelsOptimizer=Join-Path $PSScriptRoot 'Optimize-Platform3DModels.ps1'
$user3DModelsOptimizer=Join-Path $PSScriptRoot 'Optimize-User3DModels.ps1'
$sonyPointerOptimizer=Join-Path $PSScriptRoot 'Optimize-SonyPointerSharedState.ps1'
$externalGameBarOptimizer=Join-Path $PSScriptRoot 'Optimize-ExternalGameBarOverlay.ps1'
$providerOptimizer=Join-Path $PSScriptRoot 'Optimize-ProviderDownloads.ps1'
$epicWatchOptimizer=Join-Path $PSScriptRoot 'Optimize-EpicTelemetryWatch.ps1'
$epicCoordinatorOptimizer=Join-Path $PSScriptRoot 'Optimize-ProviderCoordinatorEpicActivation.ps1'
$providerConcurrencyOptimizer=Join-Path $PSScriptRoot 'Optimize-ProviderConcurrency.ps1'
$providerPreflightOptimizer=Join-Path $PSScriptRoot 'Optimize-ProviderConcurrencyPreflight.ps1'
$runtimeHitchOptimizer=Join-Path $PSScriptRoot 'Optimize-RuntimeHitching.ps1'
$concurrentDownloadRefreshOptimizer=Join-Path $PSScriptRoot 'Optimize-ConcurrentDownloadRefresh.ps1'
$downloadLibraryRefreshOptimizer=Join-Path $PSScriptRoot 'Optimize-DownloadLibraryRefreshPolicy.ps1'
$workspace=$env:GITHUB_WORKSPACE
if([string]::IsNullOrWhiteSpace($workspace)){$workspace=(Split-Path -Parent $PSScriptRoot)}
$coreSource=Join-Path $workspace 'HuymaierConsole.ps1'
$bootstrapSource=Join-Path $workspace 'HuymaierBootstrap.ps1'
$installerCoreSource=Join-Path $workspace 'HuymaierInstallerCore.ps1'
$installerScriptSource=Join-Path $workspace 'Install-HuymaierConsole.ps1'
$manifestSource=Join-Path $workspace 'manifest.json'
$appxManifestSource=Join-Path $workspace 'FSEPackage\AppxManifest.xml'
$nativeGameInputSource=Join-Path $workspace 'Native\HuymaierConsole.GameInput.cs'
$nativeConsoleSource=Join-Path $workspace 'Native\HuymaierConsole.ConsolePlatforms.cs'
$nativeSystemOverlaySource=Join-Path $workspace 'Native\HuymaierConsole.SystemOverlay.cs'
$nativeInputSource=Join-Path $workspace 'HuymaierNativeInput.cs'
$providerModuleSource=Join-Path $workspace 'HuymaierGameProviders.ps1'
$providerWorkerSource=Join-Path $workspace 'HuymaierGameProviderWorker.ps1'
$progressWorkerSource=Join-Path $workspace 'HuymaierProviderProgressWorker.ps1'
$coordinatorSource=Join-Path $workspace 'HuymaierProviderTelemetryCoordinator.ps1'
$shellRedesignSource=Join-Path $workspace 'HuymaierShellRedesign.ps1'
$browserSource=Join-Path $workspace 'HuymaierWebBrowser.ps1'
$providerConcurrencySource=Join-Path $workspace 'HuymaierProviderConcurrency.ps1'
$providerConcurrencyUiSource=Join-Path $workspace 'HuymaierProviderConcurrencyUi.ps1'
$providerTransferCoordinatorSource=Join-Path $workspace 'HuymaierProviderTransferCoordinator.ps1'
$appLibrarySource=Join-Path $workspace 'HuymaierAppLibrary.ps1'
$appInstallWorkerSource=Join-Path $workspace 'HuymaierAppInstallWorker.ps1'
$streamingControllerSource=Join-Path $workspace 'HuymaierStreamingController.ps1'
$unifiedCursorSource=Join-Path $workspace 'HuymaierUnifiedCursor.ps1'
$platformModelsSource=Join-Path $workspace 'HuymaierPlatformModels.ps1'
$platformAtlasSource=Join-Path $workspace 'HuymaierPlatformAtlas.ps1'
$livePlatformModelsSource=Join-Path $workspace 'HuymaierLivePlatformModels.ps1'
$user3DModelsSource=Join-Path $workspace 'HuymaierUser3DModels.ps1'
$modelPreviewSource=Join-Path $workspace 'Native\HuymaierModelPreviewWorker.cs'
$modelPreviewAliasesSource=Join-Path $workspace 'Native\HuymaierModelPreviewWpfAliases.cs'
$liveModelControlSource=Join-Path $workspace 'Native\HuymaierLiveModelControl.cs'
$modelMapSource=Join-Path $workspace 'Assets\Models\model-map.json'
$modelAtlasParts=@(1..4|ForEach-Object{Join-Path $workspace ('.development\v0.26.5\platform-model-atlas.part{0:D2}.b64' -f $_)})
$streamingCursorSource=Join-Path $workspace 'Native\HuymaierStreamingCursorHost.cs'
$unifiedCursorHostSource=Join-Path $workspace 'Native\HuymaierUnifiedCursorHost.cs'

$requiredFiles=@(
    $coreBuilder,$versionStamper,$startupOptimizer,$nintendoOptimizer,$nintendoNameOptimizer,$dolphinOptimizer,$wiiArtworkAliasOptimizer,$gameCubeHubOptimizer,$appLibraryOptimizer,$streamingControllerOptimizer,$unifiedCursorOptimizer,$platformModelsOptimizer,$user3DModelsOptimizer,$sonyPointerOptimizer,$externalGameBarOptimizer,$providerOptimizer,$epicWatchOptimizer,$epicCoordinatorOptimizer,$providerConcurrencyOptimizer,$providerPreflightOptimizer,$runtimeHitchOptimizer,$concurrentDownloadRefreshOptimizer,$downloadLibraryRefreshOptimizer,
    $coreSource,$bootstrapSource,$installerCoreSource,$installerScriptSource,$manifestSource,$appxManifestSource,$nativeGameInputSource,$nativeConsoleSource,$nativeSystemOverlaySource,$nativeInputSource,$providerModuleSource,$providerWorkerSource,$progressWorkerSource,$coordinatorSource,$shellRedesignSource,$browserSource,
    $providerConcurrencySource,$providerConcurrencyUiSource,$providerTransferCoordinatorSource,$appLibrarySource,$appInstallWorkerSource,$streamingControllerSource,$unifiedCursorSource,$platformModelsSource,$platformAtlasSource,$livePlatformModelsSource,$user3DModelsSource,$modelPreviewSource,$modelPreviewAliasesSource,$liveModelControlSource,$modelMapSource,$streamingCursorSource,$unifiedCursorHostSource
)+$modelAtlasParts
foreach($required in $requiredFiles){if(-not(Test-Path -LiteralPath $required -PathType Leaf)){throw "Candidate optimization wrapper is missing required file: $required"}}

$originals=@{}
foreach($path in @($coreBuilder,$coreSource,$bootstrapSource,$installerCoreSource,$installerScriptSource,$manifestSource,$appxManifestSource,$nativeGameInputSource,$nativeConsoleSource,$nativeSystemOverlaySource,$nativeInputSource,$providerModuleSource,$providerWorkerSource,$progressWorkerSource,$coordinatorSource,$shellRedesignSource,$browserSource)){$originals[$path]=[IO.File]::ReadAllBytes($path)}
try{
    & $versionStamper -TriggerPath $TriggerPath -CorePath $coreSource -BootstrapPath $bootstrapSource -InstallerCorePath $installerCoreSource -InstallerScriptPath $installerScriptSource -ManifestPath $manifestSource -AppxManifestPath $appxManifestSource -NativeGameInputPath $nativeGameInputSource
    & $providerPreflightOptimizer -BootstrapPath $bootstrapSource -InstallerScriptPath $installerScriptSource
    & $appLibraryOptimizer -CorePath $coreSource -BootstrapPath $bootstrapSource -InstallerScriptPath $installerScriptSource
    & $streamingControllerOptimizer -CorePath $coreSource -BootstrapPath $bootstrapSource -InstallerScriptPath $installerScriptSource -CoreBuilderPath $coreBuilder
    & $unifiedCursorOptimizer -CorePath $coreSource -BootstrapPath $bootstrapSource -InstallerScriptPath $installerScriptSource -CoreBuilderPath $coreBuilder
    & $platformModelsOptimizer -CorePath $coreSource -BootstrapPath $bootstrapSource -InstallerScriptPath $installerScriptSource -CoreBuilderPath $coreBuilder
    & $user3DModelsOptimizer -CorePath $coreSource -BootstrapPath $bootstrapSource -InstallerScriptPath $installerScriptSource
    & $sonyPointerOptimizer -NativeInputPath $nativeInputSource
    & $externalGameBarOptimizer -SystemOverlayPath $nativeSystemOverlaySource
    & $startupOptimizer -CorePath $coreSource
    & $nintendoOptimizer -NativePath $nativeConsoleSource
    & $nintendoNameOptimizer -ConsolePlatformsPath $nativeConsoleSource
    & $dolphinOptimizer -ConsolePlatformsPath $nativeConsoleSource
    & $wiiArtworkAliasOptimizer -ConsolePlatformsPath $nativeConsoleSource
    & $gameCubeHubOptimizer -ConsolePlatformsPath $nativeConsoleSource
    & $providerOptimizer -ProviderModulePath $providerModuleSource -ProviderWorkerPath $providerWorkerSource -ProgressWorkerPath $progressWorkerSource -CoordinatorPath $coordinatorSource
    & $epicWatchOptimizer -BootstrapPath $bootstrapSource
    & $epicCoordinatorOptimizer -CoordinatorPath $coordinatorSource
    & $providerConcurrencyOptimizer -ProviderModulePath $providerModuleSource -ProviderWorkerPath $providerWorkerSource -ProgressWorkerPath $progressWorkerSource -BootstrapPath $bootstrapSource -ShellRedesignPath $shellRedesignSource
    # HUYMAIER_BROWSER_NATIVE_CURSOR_ONLY_V1
    # Do not run Optimize-ControllerBrowserCursor.ps1. That retired transform
    # appends the legacy hc-virtual-cursor DOM pointer and conflicts with the
    # unified native system cursor.
    & $runtimeHitchOptimizer -ConsolePath $coreSource
    & $concurrentDownloadRefreshOptimizer -ConsolePath $coreSource
    & $downloadLibraryRefreshOptimizer -ConsolePath $coreSource
    & $coreBuilder -TriggerPath $TriggerPath
}finally{
    foreach($path in $originals.Keys){[IO.File]::WriteAllBytes([string]$path,[byte[]]$originals[$path])}
}