Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'

$repo=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$temp=Join-Path $env:TEMP ('hc-v0265-stabilization-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $temp|Out-Null

function Copy-TestFile([string]$Relative){
    $source=Join-Path $repo $Relative
    if(-not(Test-Path -LiteralPath $source -PathType Leaf)){throw "Required stabilization source is missing: $Relative"}
    $target=Join-Path $temp ([IO.Path]::GetFileName($Relative))
    Copy-Item -LiteralPath $source -Destination $target -Force
    return $target
}
function Assert-Contains([string]$Text,[string]$Needle,[string]$Message){if($Text.IndexOf($Needle,[StringComparison]::Ordinal) -lt 0){throw $Message}}
function Assert-NotContains([string]$Text,[string]$Needle,[string]$Message){if($Text.IndexOf($Needle,[StringComparison]::Ordinal) -ge 0){throw $Message}}
function Assert-Ps51Parse([string]$Path){
    $tokens=$null;$errors=$null
    [void][Management.Automation.Language.Parser]::ParseFile($Path,[ref]$tokens,[ref]$errors)
    if($errors.Count -gt 0){$detail=($errors|ForEach-Object{"line $($_.Extent.StartLineNumber): $($_.Message)"}) -join '; ';throw "PowerShell 5.1 parse failed for $([IO.Path]::GetFileName($Path)): $detail"}
}

try{
    $core=Copy-TestFile 'HuymaierConsole.ps1'
    $bootstrap=Copy-TestFile 'HuymaierBootstrap.ps1'
    $installer=Copy-TestFile 'Install-HuymaierConsole.ps1'
    $native=Copy-TestFile 'Native\HuymaierConsole.ConsolePlatforms.cs'
    $provider=Copy-TestFile 'HuymaierGameProviders.ps1'
    $providerWorker=Copy-TestFile 'HuymaierGameProviderWorker.ps1'
    $progressWorker=Copy-TestFile 'HuymaierProviderProgressWorker.ps1'
    $telemetryCoordinator=Copy-TestFile 'HuymaierProviderTelemetryCoordinator.ps1'
    $shell=Copy-TestFile 'HuymaierShellRedesign.ps1'
    $browser=Copy-TestFile 'HuymaierWebBrowser.ps1'

    & (Join-Path $repo '.build\Optimize-ProviderConcurrencyPreflight.ps1') -BootstrapPath $bootstrap -InstallerScriptPath $installer
    & (Join-Path $repo '.build\Optimize-HuymaierStartup.ps1') -CorePath $core
    & (Join-Path $repo '.build\Optimize-NintendoLibraryOwnership.ps1') -NativePath $native
    & (Join-Path $repo '.build\Optimize-NintendoDisplayNames.ps1') -ConsolePlatformsPath $native
    & (Join-Path $repo '.build\Optimize-ProviderDownloads.ps1') -ProviderModulePath $provider -ProviderWorkerPath $providerWorker -ProgressWorkerPath $progressWorker -CoordinatorPath $telemetryCoordinator
    & (Join-Path $repo '.build\Optimize-EpicTelemetryWatch.ps1') -BootstrapPath $bootstrap
    & (Join-Path $repo '.build\Optimize-ProviderCoordinatorEpicActivation.ps1') -CoordinatorPath $telemetryCoordinator
    & (Join-Path $repo '.build\Optimize-ProviderConcurrency.ps1') -ProviderModulePath $provider -ProviderWorkerPath $providerWorker -ProgressWorkerPath $progressWorker -BootstrapPath $bootstrap -ShellRedesignPath $shell
    & (Join-Path $repo '.build\Optimize-ControllerBrowserCursor.ps1') -BrowserPath $browser
    & (Join-Path $repo '.build\Optimize-RuntimeHitching.ps1') -ConsolePath $core

    foreach($path in @($core,$bootstrap,$installer,$provider,$providerWorker,$progressWorker,$telemetryCoordinator,$shell,$browser)) { Assert-Ps51Parse $path }
    foreach($path in @(
        (Join-Path $repo 'HuymaierProviderConcurrency.ps1'),
        (Join-Path $repo 'HuymaierProviderConcurrencyUi.ps1'),
        (Join-Path $repo 'HuymaierProviderTransferCoordinator.ps1'),
        (Join-Path $repo '.build\Optimize-ControllerBrowserCursor.ps1'),
        (Join-Path $repo '.build\Optimize-NintendoDisplayNames.ps1'),
        (Join-Path $repo '.build\Optimize-ProviderConcurrency.ps1'),
        (Join-Path $repo '.build\Optimize-ProviderConcurrencyPreflight.ps1'),
        (Join-Path $repo '.build\Optimize-RuntimeHitching.ps1')
    )) { Assert-Ps51Parse $path }

    $browserText=Get-Content -Raw -LiteralPath $browser -Encoding UTF8
    foreach($required in @('HUYMAIER_BROWSER_VIRTUAL_CURSOR_V1','hc-virtual-cursor','elementFromPoint','__hcCursorClick','__hcCursorInput','__hcCursorSetValue','Open-HcBrowserCursorKeyboard','BrowserInputSecure','Show-HcBrowserAddressKeyboard')){Assert-Contains $browserText $required "Browser cursor transform is missing $required."}
    Assert-Contains $browserText 'Open-HcBrowserCursorKeyboard $true $false' 'A/Cross does not use the pointer click/text-entry path.'
    Assert-Contains $browserText 'Open-HcBrowserCursorKeyboard $false $true' 'X/Square does not have address fallback after pointer text-entry lookup.'

    $nativeText=Get-Content -Raw -LiteralPath $native -Encoding UTF8
    foreach($required in @('HUYMAIER_NINTENDO_DISPLAY_NAME_V1','ResolveLibraryDisplayName','ReadNintendoDiscTitle','extension.Equals(".wbfs"','ReadNintendoAsciiTitle','Wii Game (','GameCube')){Assert-Contains $nativeText $required "Nintendo title transform is missing $required."}
    $oldTitle='Name = CleanName(Path.GetFileNameWithoutExtension(path)),'
    Assert-NotContains $nativeText $oldTitle 'A visible native scanner still exposes bare file/disc IDs as titles.'
    $resolvedCount=([regex]::Matches($nativeText,[regex]::Escape('Name = ResolveLibraryDisplayName(path),'))).Count
    if($resolvedCount -lt 2){throw "Expected both visible/native scanner title assignments to use ResolveLibraryDisplayName; found $resolvedCount."}

    # Validate the raw title offsets used by the transformed C# against synthetic
    # ISO and WBFS headers. This guards the exact values without needing a ROM.
    $iso=New-Object byte[] 256
    [Text.Encoding]::ASCII.GetBytes('R22E01').CopyTo($iso,0)
    $iso[0x18]=0x5D;$iso[0x19]=0x1C;$iso[0x1A]=0x9E;$iso[0x1B]=0xA3
    [Text.Encoding]::ASCII.GetBytes('Synthetic Wii Title').CopyTo($iso,0x20)
    $isoTitle=[Text.Encoding]::ASCII.GetString($iso,0x20,0x60).Trim([char]0,' ')
    if($isoTitle -ne 'Synthetic Wii Title'){throw "Synthetic ISO title offset failed: '$isoTitle'"}
    $wbfsSectorShift=20;$wbfsSectorSize=1 -shl $wbfsSectorShift
    $wbfs=New-Object byte[] ($wbfsSectorSize+256)
    [Text.Encoding]::ASCII.GetBytes('WBFS').CopyTo($wbfs,0);$wbfs[9]=[byte]$wbfsSectorShift;$wbfs[12]=1
    [Text.Encoding]::ASCII.GetBytes('R23E52').CopyTo($wbfs,$wbfsSectorSize)
    [Text.Encoding]::ASCII.GetBytes('Synthetic WBFS Title').CopyTo($wbfs,$wbfsSectorSize+0x20)
    $wbfsTitle=[Text.Encoding]::ASCII.GetString($wbfs,$wbfsSectorSize+0x20,0x60).Trim([char]0,' ')
    if($wbfsTitle -ne 'Synthetic WBFS Title'){throw "Synthetic WBFS title offset failed: '$wbfsTitle'"}

    $providerText=Get-Content -Raw -LiteralPath $provider -Encoding UTF8
    $workerText=Get-Content -Raw -LiteralPath $providerWorker -Encoding UTF8
    $progressText=Get-Content -Raw -LiteralPath $progressWorker -Encoding UTF8
    $shellText=Get-Content -Raw -LiteralPath $shell -Encoding UTF8
    $bootstrapText=Get-Content -Raw -LiteralPath $bootstrap -Encoding UTF8
    $installerText=Get-Content -Raw -LiteralPath $installer -Encoding UTF8
    foreach($required in @('HUYMAIER_PROVIDER_CONCURRENCY_V1','HuymaierProviderConcurrency.ps1')){Assert-Contains $providerText $required "Provider module is missing concurrency marker $required."}
    foreach($required in @('HUYMAIER_PROVIDER_TRANSFER_STATE_V1','TransferId=$script:TransferId','Local\HuymaierConsole.ProviderSharedState','huymaier-provider-out-"+$captureId')){Assert-Contains $workerText $required "Provider worker concurrency transform is missing $required."}
    foreach($required in @('HUYMAIER_PROVIDER_PROGRESS_TRANSFER_ID_V1','[string]$TransferId','[regex]::Escape($TransferId)')){Assert-Contains $progressText $required "Progress worker is missing per-transfer isolation marker $required."}
    foreach($required in @('HUYMAIER_PROVIDER_CONCURRENCY_UI_V1','HuymaierProviderConcurrencyUi.ps1')){Assert-Contains $shellText $required "Shell is missing concurrent Downloads UI marker $required."}
    Assert-Contains $bootstrapText 'HUYMAIER_CONCURRENT_PROVIDER_COORDINATOR_V1' 'Legacy single-state telemetry watcher was not disabled for concurrent transfers.'
    Assert-NotContains $bootstrapText "    Start-ProviderTelemetryWatch`r`n" 'Legacy single-state provider telemetry watcher still starts at runtime.'
    foreach($required in @('HuymaierProviderConcurrency.ps1','HuymaierProviderConcurrencyUi.ps1','HuymaierProviderTransferCoordinator.ps1')){Assert-Contains $bootstrapText $required "Bootstrap preflight is missing $required.";Assert-Contains $installerText $required "Installer preflight cache is missing $required."}

    $concurrencyText=Get-Content -Raw (Join-Path $repo 'HuymaierProviderConcurrency.ps1') -Encoding UTF8
    $concurrencyUiText=Get-Content -Raw (Join-Path $repo 'HuymaierProviderConcurrencyUi.ps1') -Encoding UTF8
    $transferCoordinatorText=Get-Content -Raw (Join-Path $repo 'HuymaierProviderTransferCoordinator.ps1') -Encoding UTF8
    foreach($required in @("$Mode -notin @('Install','Update')",'transfer-$transferId.json','Get-GameProviderActiveTransfers','Get-HcProviderTransferEtaText','Calculating ETA…')){Assert-Contains $concurrencyText $required "Concurrent provider layer is missing $required."}
    foreach($required in @('Get-HcActiveDownloadStates','Add-HcActiveDownloadCard','foreach($state in $active)','Update-HcActiveDownloadVisuals','Update-HcDownloadHistory')){Assert-Contains $concurrencyUiText $required "Concurrent Downloads UI is missing $required."}
    foreach($required in @('ExpectedDownloadBytes','Estimated total size + observed throughput','Get-HcSmoothedTelemetryRate','provider-transfers.json','TelemetryToken')){
        if($required -eq 'Get-HcSmoothedTelemetryRate'){Assert-Contains (Get-Content -Raw (Join-Path $repo 'HuymaierProviderTelemetry.ps1') -Encoding UTF8) $required 'Smoothed throughput helper is missing.'}
        elseif($required -eq 'TelemetryToken'){}else{Assert-Contains $transferCoordinatorText $required "Transfer coordinator is missing $required."}
    }

    $coreText=Get-Content -Raw -LiteralPath $core -Encoding UTF8
    foreach($required in @('HUYMAIER_RUNTIME_HITCH_GUARD_V1','FileSystemWatcher','Update-HcRuntimeStateEvents','Invoke-HcIncrementalConsoleCountRefresh','HcDownloadHistoryDirty','Stop-HcRuntimeStateWatcher')){Assert-Contains $coreText $required "Runtime hitch guard is missing $required."}
    $countStart=$coreText.IndexOf('function Get-PlatformCountSummary {',[StringComparison]::Ordinal)
    $countEnd=$coreText.IndexOf('function New-PlatformCard {',[StringComparison]::Ordinal)
    if($countStart -lt 0 -or $countEnd -le $countStart){throw 'Could not inspect transformed platform-count renderer.'}
    $countSegment=$coreText.Substring($countStart,$countEnd-$countStart)
    foreach($forbidden in @('Start-Ps1LibrarySummaryScan','Start-Ps2LibrarySummaryScan','Start-Ps3LibrarySummaryScan','Start-NativeConsoleLibrarySummaryScan $id')){Assert-NotContains $countSegment $forbidden "Platform-card rendering still starts a worker: $forbidden"}
    Assert-NotContains $coreText 'Start-Ps1LibrarySummaryScan;Start-Ps2LibrarySummaryScan;Start-Ps3LibrarySummaryScan' 'The old simultaneous console-summary worker burst survived the hitch transform.'

    $sources=@(Get-Content -LiteralPath (Join-Path $repo '.source\source-files.txt') -Encoding UTF8)
    foreach($required in @('HuymaierProviderConcurrency.ps1','HuymaierProviderConcurrencyUi.ps1','HuymaierProviderTransferCoordinator.ps1')){if($sources -notcontains $required){throw "Release source list is missing $required."}}

    Write-Host 'v0.26.5 stabilization transform gate passed: browser cursor, Nintendo titles, concurrent provider transfers/ETA, and runtime hitch guards.'
}finally{
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
