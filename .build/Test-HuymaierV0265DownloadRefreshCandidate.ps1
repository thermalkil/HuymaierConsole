param(
    [Parameter(Mandatory=$true)][string]$StageRoot,
    [Parameter(Mandatory=$true)][string]$ValidationPath
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$consolePath=Join-Path $StageRoot 'HuymaierConsole.ps1'
if(-not(Test-Path -LiteralPath $consolePath -PathType Leaf)){throw 'Staged HuymaierConsole.ps1 is missing.'}
$tokens=$null;$errors=$null
[void][Management.Automation.Language.Parser]::ParseFile($consolePath,[ref]$tokens,[ref]$errors)
if($errors.Count){throw ('Staged download refresh PowerShell parse failed: '+(($errors|ForEach-Object{$_.Message}) -join '; '))}
$text=Get-Content -Raw -LiteralPath $consolePath -Encoding UTF8
function Need([string]$Needle){if($text.IndexOf($Needle,[StringComparison]::Ordinal) -lt 0){throw "Staged download refresh invariant missing: $Needle"}}
foreach($required in @(
    'HUYMAIER_DOWNLOAD_LIBRARY_REFRESH_POLICY_V1',
    'Request-HcDeferredLibraryRefresh',
    'Invoke-HcDeferredLibraryRefresh',
    'Test-HcSuccessfulTransferTerminal',
    'Aggregate transfer telemetry does not invalidate the Games library.',
    'storefront-install-complete',
    "Request-HcDeferredLibraryRefresh ('provider-'+`$provider+'-'+`$mode+'-complete') 850",
    '$script:HcDeferredProviderCatalogDirty=$true',
    "Request-HcDeferredLibraryRefresh 'provider-catalog-changed' 850"
)){Need $required}
if($text.IndexOf("if(`$lower.EndsWith('provider-transfers.json')){Add-HcRuntimeDirtyPath `$script:ProviderStatePath}",[StringComparison]::Ordinal) -ge 0){throw 'Staged provider aggregate telemetry still invalidates provider state on every progress write.'}

$storeStart=$text.IndexOf('            if ((Test-HcRuntimePathDirty $script:StorefrontStatePath)',[StringComparison]::Ordinal)
$providerStart=$text.IndexOf('            if ((Test-HcRuntimePathDirty $script:ProviderStatePath)',[StringComparison]::Ordinal)
$catalogStart=$text.IndexOf('            if ((Test-HcRuntimePathDirty $script:ProviderCatalogPath)',[StringComparison]::Ordinal)
$updateStart=$text.IndexOf('            if ((Test-HcRuntimePathDirty $script:UpdateStatePath)',[StringComparison]::Ordinal)
if($storeStart -lt 0 -or $providerStart -le $storeStart -or $catalogStart -le $providerStart -or $updateStart -le $catalogStart){throw 'Staged transfer observer scopes could not be isolated.'}
$store=$text.Substring($storeStart,$providerStart-$storeStart)
$provider=$text.Substring($providerStart,$catalogStart-$providerStart)
$catalog=$text.Substring($catalogStart,$updateStart-$catalogStart)

$storeBusyStart=$store.IndexOf('if($transferBusy){',[StringComparison]::Ordinal)
$storeTerminal=$store.IndexOf('}elseif(Test-HcInstallOrUpdateMode $script:StorefrontState){',[StringComparison]::Ordinal)
if($storeBusyStart -lt 0 -or $storeTerminal -le $storeBusyStart){throw 'Staged storefront busy/terminal policy missing.'}
$storeBusy=$store.Substring($storeBusyStart,$storeTerminal-$storeBusyStart)
if($storeBusy.IndexOf('$script:SelectedTab -eq 1',[StringComparison]::Ordinal) -ge 0){throw 'Active storefront progress can still refresh Games.'}
if($storeBusy.IndexOf('$script:SelectedTab -eq 4',[StringComparison]::Ordinal) -lt 0){throw 'Active storefront progress no longer updates Downloads in place.'}

$providerBusyStart=$provider.IndexOf('if($transferBusy){',[StringComparison]::Ordinal)
$providerTerminal=$provider.IndexOf("}elseif(`$mode -in @('Install','Update')){",[StringComparison]::Ordinal)
if($providerBusyStart -lt 0 -or $providerTerminal -le $providerBusyStart){throw 'Staged provider busy/terminal policy missing.'}
$providerBusy=$provider.Substring($providerBusyStart,$providerTerminal-$providerBusyStart)
if($providerBusy.IndexOf('$script:SelectedTab -eq 1',[StringComparison]::Ordinal) -ge 0){throw 'Active provider progress can still refresh Games.'}
if($providerBusy.IndexOf('$script:SelectedTab -eq 4',[StringComparison]::Ordinal) -lt 0){throw 'Active provider progress no longer updates Downloads in place.'}
if($providerBusy.IndexOf('Clear-HcGameDataCache',[StringComparison]::Ordinal) -ge 0){throw 'Active provider progress can still invalidate the library cache.'}

if($catalog.IndexOf('$script:HcDeferredProviderCatalogDirty=$true',[StringComparison]::Ordinal) -lt 0){throw 'Staged provider catalog changes are not deferred.'}
if($catalog.IndexOf('try{Clear-HcGameDataCache -DropPersistent}catch{}',[StringComparison]::Ordinal) -ge 0){throw 'Staged provider catalog still clears the library immediately.'}
if($catalog.IndexOf('if($script:SelectedTab -eq 1){Render-Page}',[StringComparison]::Ordinal) -ge 0){throw 'Staged provider catalog still immediately rebuilds Games.'}

$validation=Get-Content -Raw -LiteralPath $ValidationPath -Encoding UTF8|ConvertFrom-Json
$validation|Add-Member -NotePropertyName activeDownloadLibraryStabilityGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName completionOnlyLibraryRefreshGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName inPlaceDownloadTelemetryGate -NotePropertyValue 'success' -Force
$validation|ConvertTo-Json -Depth 20|Set-Content -LiteralPath $ValidationPath -Encoding UTF8
Write-Host 'Staged v0.26.5 active-download library stability and completion-only refresh gates passed.'
