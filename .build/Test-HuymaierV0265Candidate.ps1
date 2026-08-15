param(
    [Parameter(Mandatory=$true)][string]$StageRoot,
    [Parameter(Mandatory=$true)][string]$ValidationPath
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'

function Require-Text([string]$Relative,[string[]]$Needles){
    $path=Join-Path $StageRoot $Relative
    if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "v0.26.5 required file missing: $Relative"}
    $raw=Get-Content -Raw -LiteralPath $path -Encoding UTF8
    foreach($needle in $Needles){if($raw.IndexOf($needle,[StringComparison]::Ordinal) -lt 0){throw "$Relative missing v0.26.5 invariant: $needle"}}
    return $raw
}
function Require-File([string]$Relative){
    $path=Join-Path $StageRoot $Relative
    if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "v0.26.5 required file missing: $Relative"}
    return $path
}
function Assert-Ps51Parse([string]$Relative){
    $path=Require-File $Relative
    $tokens=$null;$errors=$null
    [void][Management.Automation.Language.Parser]::ParseFile($path,[ref]$tokens,[ref]$errors)
    if($errors.Count -gt 0){
        $detail=($errors|ForEach-Object{"line $($_.Extent.StartLineNumber): $($_.Message)"}) -join '; '
        throw "Staged PowerShell 5.1 parse failed for ${Relative}: $detail"
    }
}

$manifest=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'manifest.json') -Encoding UTF8|ConvertFrom-Json
if([string]$manifest.version -ne '0.26.5'){throw 'Candidate manifest is not v0.26.5.'}
if([string]$manifest.baseVersion -ne '0.26.4'){throw 'v0.26.5 candidate does not identify v0.26.4 as its feature base.'}
if([string]$manifest.build -ne 'performance-downloads-stabilization-rc1'){throw 'Candidate manifest is not performance-downloads-stabilization-rc1.'}
if([string]$manifest.builtFrom -ne 'HC262.zip'){throw 'v0.26.5 candidate no longer records the published HC262.zip package staging baseline.'}

$core=Require-Text 'HuymaierConsole.ps1' @(
    "`$script:AppVersion = '0.26.5'",
    'Startup timing: entering ShowDialog at',
    'Startup timing: first rendered frame at',
    'Startup timing: deferred shell services ready at',
    '$script:Window.Add_ContentRendered',
    "'HuymaierConsole.Native.DisplayBridge' -as [type]",
    "'HuymaierConsole.Native.AudioBridge' -as [type]",
    "'HuymaierConsole.Native.LegacyJoystick' -as [type]",
    "'HuymaierConsole.Native.FrameRateMonitor' -as [type]",
    'HUYMAIER_CURATED_APP_LIBRARY_V1',
    'HuymaierAppLibrary.ps1',
    'HUYMAIER_RUNTIME_HITCH_GUARD_V1',
    'FileSystemWatcher',
    'Update-HcRuntimeStateEvents',
    'Invoke-HcIncrementalConsoleCountRefresh',
    'Stop-HcRuntimeStateWatcher',
    'HUYMAIER_CONCURRENT_DOWNLOAD_REFRESH_V1',
    'HUYMAIER_DOWNLOAD_LIBRARY_REFRESH_POLICY_V1',
    'Aggregate transfer telemetry does not invalidate the Games library.',
    'Request-HcDeferredLibraryRefresh',
    'Invoke-HcDeferredLibraryRefresh'
)
$obsoleteAggregateBridge="if(`$lower.EndsWith('provider-transfers.json')){Add-HcRuntimeDirtyPath `$script:ProviderStatePath}"
if($core.IndexOf($obsoleteAggregateBridge,[StringComparison]::Ordinal) -ge 0){throw 'Staged shell still treats provider-transfers telemetry as a Games-library mutation.'}
$countStart=$core.IndexOf('function Get-PlatformCountSummary {',[StringComparison]::Ordinal)
$countEnd=$core.IndexOf('function New-PlatformCard {',[StringComparison]::Ordinal)
if($countStart -lt 0 -or $countEnd -le $countStart){throw 'Staged shell platform-count renderer cannot be inspected.'}
$countSegment=$core.Substring($countStart,$countEnd-$countStart)
foreach($forbidden in @('Start-Ps1LibrarySummaryScan','Start-Ps2LibrarySummaryScan','Start-Ps3LibrarySummaryScan','Start-NativeConsoleLibrarySummaryScan $id')){if($countSegment.IndexOf($forbidden,[StringComparison]::Ordinal) -ge 0){throw "Staged platform-card rendering still starts a summary worker: $forbidden"}}
if($core.IndexOf('Start-Ps1LibrarySummaryScan;Start-Ps2LibrarySummaryScan;Start-Ps3LibrarySummaryScan',[StringComparison]::Ordinal) -ge 0){throw 'Staged shell still contains the simultaneous console-summary worker burst.'}

$bootstrap=Require-Text 'HuymaierBootstrap.ps1' @(
    "`$script:ExpectedConsoleVersion='0.26.5'",
    'startup-preflight-v1.json',
    'Test-PowerShellPreflightCache',
    'HuymaierProviderConcurrency.ps1',
    'HuymaierProviderConcurrencyUi.ps1',
    'HuymaierProviderTransferCoordinator.ps1',
    'HuymaierAppLibrary.ps1',
    'HuymaierAppInstallWorker.ps1',
    'HUYMAIER_CONCURRENT_PROVIDER_COORDINATOR_V1'
)
if($bootstrap.IndexOf("    Start-ProviderTelemetryWatch`r`n",[StringComparison]::Ordinal) -ge 0 -or $bootstrap.IndexOf("    Start-ProviderTelemetryWatch`n",[StringComparison]::Ordinal) -ge 0){throw 'Staged bootstrap still starts the legacy single-state provider telemetry coordinator.'}

$installerCore=Require-Text 'HuymaierInstallerCore.ps1' @("`$script:InstallVersion='0.26.5'")
$installerEntry=Require-Text 'Install-HuymaierConsole.ps1' @(
    'Write-HuymaierStartupPreflightCache',
    "param([string]`$InstallRoot,[string]`$Version='0.26.5')",
    "-Version '0.26.5'",
    "ValidationSource='installer'",
    'HuymaierProviderConcurrency.ps1',
    'HuymaierProviderConcurrencyUi.ps1',
    'HuymaierProviderTransferCoordinator.ps1',
    'HuymaierAppLibrary.ps1',
    'HuymaierAppInstallWorker.ps1'
)
$appx=Require-Text 'FSEPackage\AppxManifest.xml' @('Version="0.26.5.0"')

$browser=Require-Text 'HuymaierWebBrowser.ps1' @(
    "`$script:HcBrowserAuthRequestPath = Join-Path `$script:DataDir 'browser-auth-request.json'",
    "`$script:HcBrowserAuthResultDir = Join-Path `$script:DataDir 'BrowserAuth'",
    "`$script:HcBrowserReadyPath = Join-Path `$script:HcBrowserAuthResultDir 'native-browser.ready.json'",
    "Add-HcBrowserToolbarItem `$address 'Address'",
    "Show-NativeKeyboard -Title 'Search or enter address'",
    "-Mode 'BrowserAddress'",
    "'BrowserInputSecure'",
    'Invoke-HcBrowserControllerType',
    'HUYMAIER_BROWSER_VIRTUAL_CURSOR_V1',
    'hc-virtual-cursor',
    'document.elementFromPoint',
    'window.__hcCursorClick',
    'window.__hcCursorInput',
    'window.__hcCursorSetValue',
    'Open-HcBrowserCursorKeyboard $true $false',
    'Open-HcBrowserCursorKeyboard $false $true',
    "Set-HcBrowserFocusArea 'Toolbar'",
    "Set-HcBrowserFocusArea 'Web'",
    'ConvertTo-HcBrowserDestination'
)
$browserStateIndex=$browser.IndexOf("`$script:HcBrowserAuthRequestPath = Join-Path")
$browserInitIndex=$browser.IndexOf('function Initialize-HuymaierWebBrowser')
$webViewConstructionIndex=$browser.IndexOf('New-Object Microsoft.Web.WebView2.Wpf.WebView2')
if($browserStateIndex -lt 0 -or $browserInitIndex -lt 0 -or $browserStateIndex -gt $browserInitIndex){throw 'Staged browser can read auth state before initialization under StrictMode.'}
if($webViewConstructionIndex -lt $browserInitIndex){throw 'Staged browser constructs WebView2 during module load instead of lazily.'}
if($browser -match 'HcBrowserToolbarButtons\[\$script:HcBrowserToolbarIndex\]\.Tag'){throw 'Staged browser regressed to button-only controller toolbar navigation.'}

$nativeGameInput=Require-Text 'Native\HuymaierConsole.GameInput.cs' @('public static class HuymaierBuildStamp','public const string Version = "0.26.5";','public const string Architecture = "x64";')
$native=Require-Text 'Native\HuymaierConsole.ConsolePlatforms.cs' @(
    'IsNintendoLibraryOwnedPath','IsNintendoRawDiscForCurrentShell','header[0x18] == 0x5D','header[0x1C] == 0xC2','if (!IsNintendoLibraryOwnedPath(path)) continue;',
    'HUYMAIER_NINTENDO_DISPLAY_NAME_V1','ResolveLibraryDisplayName','ReadNintendoDiscTitle','extension.Equals(".wbfs"','ReadNintendoAsciiTitle','LooksLikeNintendoDiscId','return platform + " Game ("',
    'HUYMAIER_DOLPHIN_INTEGRATION_V1','GetDolphinUserRoots','GameCovers','ReadNintendoGameId','FindDolphinArtwork','FindDolphinArtworkBySaveCode',
    'ReadWiiSaveBannerMetadata','CreateWiiSaveCard','GameCode','Description','Modified','FormatBytes(save.Size)'
)
if($native -match 'Name = CleanName\(Path\.GetFileNameWithoutExtension\(path\)\),'){throw 'Staged native scanner can still expose a bare six-character Wii/GameCube disc ID as its display title.'}
if($native -match 'LeftShoulder[^\r\n]{0,200}SwitchPage' -or $native -match 'RightShoulder[^\r\n]{0,200}SwitchPage'){throw 'LB/RB shoulder buttons switch ordinary native platform pages in v0.26.5.'}
$dolphinPos=$native.IndexOf('string dolphin=FindDolphinArtwork(gamePath,title)',[StringComparison]::Ordinal)
$genericPos=$native.IndexOf('string emulator=FindEmulatorArtwork(gamePath,title)',[StringComparison]::Ordinal)
if($dolphinPos -lt 0 -or $genericPos -lt 0 -or $dolphinPos -gt $genericPos){throw 'Staged Wii/GameCube artwork does not prefer Dolphin GameCovers before generic artwork matching.'}

$exePath=Join-Path $StageRoot 'HuymaierConsole.exe'
if(-not(Test-Path -LiteralPath $exePath -PathType Leaf)){throw 'v0.26.5 compiled native host is missing.'}
try{$nativeAssembly=[Reflection.Assembly]::LoadFile([IO.Path]::GetFullPath($exePath))}catch{throw "Could not load compiled HuymaierConsole.exe for build-stamp verification: $($_.Exception.Message)"}
$stampType=$nativeAssembly.GetType('HuymaierConsole.NativeApp.HuymaierBuildStamp',$false)
if($null -eq $stampType){throw 'Compiled HuymaierConsole.exe has no HuymaierBuildStamp type.'}
$flags=[Reflection.BindingFlags]::Public -bor [Reflection.BindingFlags]::Static
$versionField=$stampType.GetField('Version',$flags);$architectureField=$stampType.GetField('Architecture',$flags)
$compiledVersion=if($null -ne $versionField){[string]$versionField.GetValue($null)}else{''};$compiledArchitecture=if($null -ne $architectureField){[string]$architectureField.GetValue($null)}else{''}
if($compiledVersion -ne '0.26.5' -or $compiledArchitecture -ne 'x64'){throw "Compiled native host build stamp mismatch. Native=$compiledVersion/$compiledArchitecture Expected=0.26.5/x64."}
Write-Host "Compiled native host build stamp verified: $compiledVersion/$compiledArchitecture"

$providerModule=Require-Text 'HuymaierGameProviders.ps1' @('Get-ProviderDownloadDisplay','Format-ProviderDownloadEta','InstallProcessedBytes','InstallSpeedBytesPerSec','HUYMAIER_PROVIDER_CONCURRENCY_V1','HuymaierProviderConcurrency.ps1')
$providerWorker=Require-Text 'HuymaierGameProviderWorker.ps1' @('Get-LegendaryTransferPhase','Format-ProviderEtaValue','Installing','Calculating ETA','Write-State $true $phase','HUYMAIER_PROVIDER_TRANSFER_STATE_V1','TransferId=$script:TransferId','Local\HuymaierConsole.ProviderSharedState','huymaier-provider-out-"+$captureId')
$progressWorker=Require-Text 'HuymaierProviderProgressWorker.ps1' @("ValidateSet('Epic','GOG','Amazon')",'Read-ProviderOutputTail','Start-WriteObservation','Update-ObservedWriteBytes','Incremental destination writes','Calculating ETA','HUYMAIER_PROVIDER_PROGRESS_TRANSFER_ID_V1','[string]$TransferId','[regex]::Escape($TransferId)')
if($progressWorker -match 'Directory\]::EnumerateFiles|Directory\.EnumerateFiles'){throw 'Release fallback telemetry reintroduced recursive install-tree rescans.'}
$coordinator=Require-Text 'HuymaierProviderTelemetryCoordinator.ps1' @("@('Epic','GOG','Amazon')","@('Install','Update')",'TelemetrySource','InstallSpeedBytesPerSec','TransferSpeedBytesPerSec')
if($coordinator -match [regex]::Escape("@('GOG','Amazon')")){throw 'Release telemetry coordinator still contains a GOG/Amazon-only activation path.'}
$concurrency=Require-Text 'HuymaierProviderConcurrency.ps1' @('$Mode -notin @(''Install'',''Update'')','ProviderTransferRoot','Get-GameProviderActiveTransfers','Get-HcProviderTransferEtaText','Calculating ETA...','transfer-'+"`$transferId"+'.json')
$concurrencyUi=Require-Text 'HuymaierProviderConcurrencyUi.ps1' @('Get-HcActiveDownloadStates','Add-HcActiveDownloadCard','foreach($state in $active)','Update-HcActiveDownloadVisuals','Update-HcDownloadHistory','Recently Downloaded & Installed')
$transferCoordinator=Require-Text 'HuymaierProviderTransferCoordinator.ps1' @('provider-transfers.json','ExpectedDownloadBytes','ExpectedInstallBytes','Get-ExpectedSizes','Estimated total size + observed throughput','Start-TransferMonitor','Merge-TransferProgress')
$telemetry=Require-Text 'HuymaierProviderTelemetry.ps1' @('Get-HcSmoothedTelemetryRate','Get-HcTelemetryEtaSeconds')

$appLibrary=Require-Text 'HuymaierAppLibrary.ps1' @(
    'function Render-HcAppsRoot','Your curated console app library','apps-store','apps-manage','Remove-HcManagedApp','PreferredLaunchMode','Open-HuymaierBrowser',
    "'Streaming'","'Music'","'Video'","'Utilities'","'Tools'",'Get-HcCuratedAppCatalog','Start-HcNativeCatalogInstall','Get-HcActiveDownloadStates','Update-HcDownloadHistory'
)
$appsStart=$appLibrary.IndexOf('function Render-HcAppsRoot',[StringComparison]::Ordinal);$appsEnd=$appLibrary.IndexOf('$script:HcAppBaseGetPageDefinition',[StringComparison]::Ordinal)
if($appsStart -lt 0 -or $appsEnd -le $appsStart){throw 'Staged curated Apps root cannot be inspected.'}
if($appLibrary.Substring($appsStart,$appsEnd-$appsStart).IndexOf('Get-HcWindowsApps',[StringComparison]::Ordinal) -ge 0){throw 'Staged Apps home still enumerates every Windows Start app.'}
$appWorker=Require-Text 'HuymaierAppInstallWorker.ps1' @('winget','install','--source','msstore','EtaSeconds','Calculating ETA...','StatePath','CatalogId')

foreach($required in @(
    'HuymaierProviderTelemetry.ps1','HuymaierProviderProgressWorker.ps1','HuymaierProviderTelemetryCoordinator.ps1','HuymaierProviderConcurrency.ps1','HuymaierProviderConcurrencyUi.ps1','HuymaierProviderTransferCoordinator.ps1',
    'HuymaierAppLibrary.ps1','HuymaierAppInstallWorker.ps1'
)){Require-File $required|Out-Null}
foreach($scriptFile in @(
    'HuymaierConsole.ps1','HuymaierBootstrap.ps1','Install-HuymaierConsole.ps1','HuymaierGameProviders.ps1','HuymaierGameProviderWorker.ps1','HuymaierProviderProgressWorker.ps1','HuymaierProviderTelemetry.ps1','HuymaierProviderTelemetryCoordinator.ps1',
    'HuymaierProviderConcurrency.ps1','HuymaierProviderConcurrencyUi.ps1','HuymaierProviderTransferCoordinator.ps1','HuymaierShellRedesign.ps1','HuymaierWebBrowser.ps1','HuymaierAppLibrary.ps1','HuymaierAppInstallWorker.ps1'
)){Assert-Ps51Parse $scriptFile}

$realGit=(Get-Command git.exe -ErrorAction Stop).Source
$psChanges=@(& $realGit diff --name-only 91bd40877bd0d5ee5d0f86748a2356a446d75bc6 -- 'EmulatorPlatforms/PS1' 'EmulatorPlatforms/PS2' 'EmulatorPlatforms/PS3' 'Native/HuymaierConsole.Ps1.cs')
if($psChanges.Count){throw ('Frozen PS1/PS2/PS3 presentation source changed in v0.26.5: '+($psChanges -join ', '))}

$validation=Get-Content -Raw -LiteralPath $ValidationPath -Encoding UTF8|ConvertFrom-Json
$validation|Add-Member -NotePropertyName version0265ConsistencyGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName nativeHostBuildStampGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName browserColdStartGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName browserVirtualCursorGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName startupPerformanceGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName runtimeHitchGuardGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName providerTelemetryGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName concurrentProviderTransfersGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName derivedEtaGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName nintendoOwnershipGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName nintendoDisplayNameGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName dolphinArtworkGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName wiiSaveManagerGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName curatedAppsGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName nativeAppInstallGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName controllerAppModeGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName playStationPresentationFreezeGate -NotePropertyValue 'success' -Force
$validation|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $ValidationPath -Encoding UTF8
Write-Host 'v0.26.5 release-shaped native stamp, browser cursor, hitch guard, concurrent transfers/ETA, Dolphin artwork/Wii saves, curated Apps/controller mode and PlayStation freeze gates passed.'
