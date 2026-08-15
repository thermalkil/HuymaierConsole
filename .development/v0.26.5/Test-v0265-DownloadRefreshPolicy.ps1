Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$temp=Join-Path $env:TEMP ('hc-v0265-download-refresh-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $temp|Out-Null
function Assert-Contains([string]$Text,[string]$Needle,[string]$Message){if($Text.IndexOf($Needle,[StringComparison]::Ordinal) -lt 0){throw $Message}}
function Assert-NotContains([string]$Text,[string]$Needle,[string]$Message){if($Text.IndexOf($Needle,[StringComparison]::Ordinal) -ge 0){throw $Message}}
function Assert-Ps51Parse([string]$Path){$tokens=$null;$errors=$null;[void][Management.Automation.Language.Parser]::ParseFile($Path,[ref]$tokens,[ref]$errors);if($errors.Count){throw (($errors|ForEach-Object{"line $($_.Extent.StartLineNumber): $($_.Message)"}) -join '; ')}}
try{
    $console=Join-Path $temp 'HuymaierConsole.ps1'
    Copy-Item (Join-Path $repo 'HuymaierConsole.ps1') $console -Force
    & (Join-Path $repo '.build\Optimize-RuntimeHitching.ps1') -ConsolePath $console
    & (Join-Path $repo '.build\Optimize-ConcurrentDownloadRefresh.ps1') -ConsolePath $console
    & (Join-Path $repo '.build\Optimize-DownloadLibraryRefreshPolicy.ps1') -ConsolePath $console
    Assert-Ps51Parse $console
    Assert-Ps51Parse (Join-Path $repo '.build\Optimize-DownloadLibraryRefreshPolicy.ps1')
    $text=Get-Content -Raw $console -Encoding UTF8
    foreach($required in @(
        'HUYMAIER_DOWNLOAD_LIBRARY_REFRESH_POLICY_V1',
        'Request-HcDeferredLibraryRefresh',
        'Invoke-HcDeferredLibraryRefresh',
        'Test-HcSuccessfulTransferTerminal',
        'storefront-install-complete',
        "('provider-'+`$provider+'-'+`$mode+'-complete')",
        '$script:HcDeferredProviderCatalogDirty=$true',
        "Request-HcDeferredLibraryRefresh 'provider-catalog-changed' 850",
        'Aggregate transfer telemetry does not invalidate the Games library.'
    )){Assert-Contains $text $required "Transformed download refresh policy is missing $required"}

    Assert-NotContains $text "if(`$lower.EndsWith('provider-transfers.json')){Add-HcRuntimeDirtyPath `$script:ProviderStatePath}" 'provider-transfers telemetry still forces provider-state dirty.'

    $storeStart=$text.IndexOf('            if ((Test-HcRuntimePathDirty $script:StorefrontStatePath)',[StringComparison]::Ordinal)
    $providerStart=$text.IndexOf('            if ((Test-HcRuntimePathDirty $script:ProviderStatePath)',[StringComparison]::Ordinal)
    $catalogStart=$text.IndexOf('            if ((Test-HcRuntimePathDirty $script:ProviderCatalogPath)',[StringComparison]::Ordinal)
    $updateStart=$text.IndexOf('            if ((Test-HcRuntimePathDirty $script:UpdateStatePath)',[StringComparison]::Ordinal)
    if($storeStart -lt 0 -or $providerStart -le $storeStart -or $catalogStart -le $providerStart -or $updateStart -le $catalogStart){throw 'Could not isolate transformed transfer observers.'}
    $store=$text.Substring($storeStart,$providerStart-$storeStart)
    $provider=$text.Substring($providerStart,$catalogStart-$providerStart)
    $catalog=$text.Substring($catalogStart,$updateStart-$catalogStart)

    $storeBusyStart=$store.IndexOf('if($transferBusy){',[StringComparison]::Ordinal)
    $storeTerminal=$store.IndexOf('}elseif(Test-HcInstallOrUpdateMode $script:StorefrontState){',[StringComparison]::Ordinal)
    if($storeBusyStart -lt 0 -or $storeTerminal -le $storeBusyStart){throw 'Storefront busy/terminal branches are missing.'}
    $storeBusy=$store.Substring($storeBusyStart,$storeTerminal-$storeBusyStart)
    Assert-Contains $storeBusy '$script:SelectedTab -eq 4' 'Storefront progress no longer updates Downloads in place.'
    Assert-NotContains $storeBusy '$script:SelectedTab -eq 1' 'Storefront progress still rebuilds Games.'

    $providerBusyStart=$provider.IndexOf('if($transferBusy){',[StringComparison]::Ordinal)
    $providerTerminal=$provider.IndexOf("}elseif(`$mode -in @('Install','Update')){",[StringComparison]::Ordinal)
    if($providerBusyStart -lt 0 -or $providerTerminal -le $providerBusyStart){throw 'Provider busy/terminal branches are missing.'}
    $providerBusy=$provider.Substring($providerBusyStart,$providerTerminal-$providerBusyStart)
    Assert-Contains $providerBusy '$script:SelectedTab -eq 4' 'Provider progress no longer updates Downloads in place.'
    Assert-NotContains $providerBusy '$script:SelectedTab -eq 1' 'Provider progress still rebuilds Games.'
    Assert-NotContains $providerBusy 'Clear-HcGameDataCache' 'Provider progress still invalidates the game-data cache.'

    Assert-Contains $catalog '$script:HcDeferredProviderCatalogDirty=$true' 'Provider catalog mutation is not deferred.'
    Assert-NotContains $catalog 'try{Clear-HcGameDataCache -DropPersistent}catch{}' 'Provider catalog still clears the library cache immediately.'
    Assert-NotContains $catalog 'if($script:SelectedTab -eq 1){Render-Page}' 'Provider catalog still immediately rebuilds Games.'

    $helperStart=$text.IndexOf('# HUYMAIER_DOWNLOAD_LIBRARY_REFRESH_POLICY_V1',[StringComparison]::Ordinal)
    $timerStart=$text.IndexOf('    $systemTimer = New-Object System.Windows.Threading.DispatcherTimer',[StringComparison]::Ordinal)
    $helperScope=$text.Substring($helperStart,$timerStart-$helperStart)
    Assert-Contains $helperScope 'if($script:SelectedTab -eq 1)' 'Deferred completion path does not refresh Games.'
    Assert-Contains $helperScope 'Clear-HcGameDataCache -DropPersistent' 'Deferred completion path does not apply the provider catalog cache mutation.'

    Write-Host 'v0.26.5 active-download library stability and one-shot completion refresh gates passed.'
}finally{Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue}
