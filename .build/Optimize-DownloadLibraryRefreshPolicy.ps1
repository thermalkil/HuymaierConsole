param(
    [Parameter(Mandatory=$true)][string]$ConsolePath
)

Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
if(-not(Test-Path -LiteralPath $ConsolePath -PathType Leaf)){throw "Console source missing: $ConsolePath"}
$text=Get-Content -Raw -LiteralPath $ConsolePath -Encoding UTF8
if($text -match 'HUYMAIER_DOWNLOAD_LIBRARY_REFRESH_POLICY_V1'){return}
if($text -notmatch 'HUYMAIER_RUNTIME_HITCH_GUARD_V1'){throw 'Download refresh policy requires runtime hitch transform first.'}
if($text -notmatch 'HUYMAIER_CONCURRENT_DOWNLOAD_REFRESH_V1'){throw 'Download refresh policy requires concurrent download refresh transform first.'}

# provider-transfers.json changes every telemetry cycle. It must not force the
# legacy provider-state path dirty because provider-state.json already has its
# own watcher event. Forcing it dirty here doubles progress observations and was
# one source of repeated Games-page rebuilds.
$aggregateDirty="                        if(`$lower.EndsWith('provider-transfers.json')){Add-HcRuntimeDirtyPath `$script:ProviderStatePath}"
if($text.Contains($aggregateDirty)){$text=$text.Replace($aggregateDirty,'                        # Aggregate transfer telemetry does not invalidate the Games library.')}
else{throw 'Download refresh policy could not find concurrent aggregate dirty bridge.'}

$timerNeedle='    $systemTimer = New-Object System.Windows.Threading.DispatcherTimer'
if(-not $text.Contains($timerNeedle)){throw 'Download refresh policy could not find system timer.'}
$helper=@'
    # HUYMAIER_DOWNLOAD_LIBRARY_REFRESH_POLICY_V1
    # Transfer progress is not a library mutation. Keep the current Games page
    # fully usable while downloads/installations are active and coalesce the
    # actual library rebuild until a successful terminal install/update event.
    $script:HcDeferredLibraryRefreshAt=[datetime]::MinValue
    $script:HcDeferredLibraryRefreshReason=''
    $script:HcDeferredProviderCatalogDirty=$false

    function Test-HcInstallOrUpdateMode {
        param($State)
        $mode=[string](Get-EntryProperty $State 'Mode' '')
        return ($mode -in @('Install','Update'))
    }
    function Test-HcSuccessfulTransferTerminal {
        param($State)
        if($null -eq $State -or [bool](Get-EntryProperty $State 'Busy' $false)){return $false}
        if(-not(Test-HcInstallOrUpdateMode $State)){return $false}
        if([string](Get-EntryProperty $State 'Error' '')){return $false}
        $phase=[string](Get-EntryProperty $State 'Phase' (Get-EntryProperty $State 'Status' ''))
        $progress=[int](Get-EntryProperty $State 'Progress' -1)
        return ($phase -in @('Complete','Completed','Ready') -or $progress -ge 100)
    }
    function Request-HcDeferredLibraryRefresh {
        param([string]$Reason,[int]$DelayMs=850)
        $script:HcDeferredLibraryRefreshAt=(Get-Date).AddMilliseconds([math]::Max(100,$DelayMs))
        if($Reason){$script:HcDeferredLibraryRefreshReason=$Reason}
    }
    function Invoke-HcDeferredLibraryRefresh {
        if($script:HcDeferredLibraryRefreshAt -eq [datetime]::MinValue -or (Get-Date) -lt $script:HcDeferredLibraryRefreshAt){return}
        $script:HcDeferredLibraryRefreshAt=[datetime]::MinValue
        $reason=$script:HcDeferredLibraryRefreshReason
        $script:HcDeferredLibraryRefreshReason=''
        if($script:HcDeferredProviderCatalogDirty){
            $script:HcDeferredProviderCatalogDirty=$false
            try{Clear-HcGameDataCache -DropPersistent}catch{Write-Log "Deferred provider library cache invalidation failed: $($_.Exception.Message)" 'WARN'}
        }
        if($script:SelectedTab -eq 1){
            try{Render-Page}catch{Write-Log "Deferred library refresh failed ($reason): $($_.Exception.Message)" 'WARN'}
        }
    }

'@
$text=$text.Replace($timerNeedle,$helper+$timerNeedle)

# Invoke the coalesced refresh once per system tick. Runtime-hitch optimization
# already inserted the incremental count refresh at the top of this timer.
$tickNeedle='            Invoke-HcIncrementalConsoleCountRefresh'
if(-not $text.Contains($tickNeedle)){throw 'Download refresh policy could not find optimized system-timer tick.'}
$text=$text.Replace($tickNeedle,$tickNeedle+"`r`n            Invoke-HcDeferredLibraryRefresh")

$storeStart=$text.IndexOf('            if ((Test-HcRuntimePathDirty $script:StorefrontStatePath)',[StringComparison]::Ordinal)
$providerStart=$text.IndexOf('            if ((Test-HcRuntimePathDirty $script:ProviderStatePath)',[StringComparison]::Ordinal)
if($storeStart -lt 0 -or $providerStart -le $storeStart){throw 'Download refresh policy could not isolate storefront/provider observers.'}
$storeBlock=@'
            if ((Test-HcRuntimePathDirty $script:StorefrontStatePath) -and (Test-Path $script:StorefrontStatePath)) {
                $storefrontSignature=(Get-Item -LiteralPath $script:StorefrontStatePath).LastWriteTimeUtc.Ticks.ToString()
                if($storefrontSignature -ne $script:StorefrontStateSignature){
                    $previousStorefrontSignature=[string]$script:StorefrontStateSignature
                    $script:StorefrontStateSignature=$storefrontSignature
                    Read-StorefrontState
                    $script:StorefrontCatalogAt=[datetime]::MinValue
                    $transferBusy=[bool](Get-EntryProperty $script:StorefrontState 'Busy' $false) -and (Test-HcInstallOrUpdateMode $script:StorefrontState)
                    if($transferBusy){
                        # Never rebuild Games for progress. Downloads may update its
                        # existing visual card in place; rebuild Downloads only when
                        # the active-card set itself changed.
                        if($script:SelectedTab -eq 4 -and -not $script:SubPage -and (Get-Command Update-HcActiveDownloadVisuals -ErrorAction SilentlyContinue)){
                            if(-not(Update-HcActiveDownloadVisuals $script:StorefrontState)){Render-Page}
                        }
                    }elseif(Test-HcInstallOrUpdateMode $script:StorefrontState){
                        if($previousStorefrontSignature -and (Test-HcSuccessfulTransferTerminal $script:StorefrontState)){
                            Request-HcDeferredLibraryRefresh 'storefront-install-complete' 850
                        }
                        if($script:SelectedTab -eq 4){Render-Page}
                    }elseif($script:SelectedTab -in @(1,4)){
                        Render-Page
                    }
                }
            }
'@
$text=$text.Substring(0,$storeStart)+$storeBlock+$text.Substring($providerStart)

$providerStart=$text.IndexOf('            if ((Test-HcRuntimePathDirty $script:ProviderStatePath)',[StringComparison]::Ordinal)
$catalogStart=$text.IndexOf('            if ((Test-HcRuntimePathDirty $script:ProviderCatalogPath)',[StringComparison]::Ordinal)
if($providerStart -lt 0 -or $catalogStart -le $providerStart){throw 'Download refresh policy could not isolate provider state/catalog observers.'}
$providerBlock=@'
            if ((Test-HcRuntimePathDirty $script:ProviderStatePath) -and (Test-Path $script:ProviderStatePath)) {
                $providerStateSignature=(Get-Item -LiteralPath $script:ProviderStatePath).LastWriteTimeUtc.Ticks.ToString()
                if($providerStateSignature -ne $script:ProviderStateSignature){
                    $previousProviderStateSignature=[string]$script:ProviderStateSignature
                    $script:ProviderStateSignature=$providerStateSignature
                    $providerState=Read-GameProviderState
                    # Provider refresh is an explicit library mutation. Refresh only that
                    # provider's missing cover art after the provider job completes.
                    try{
                        $mode=[string](Get-EntryProperty $providerState 'Mode' '')
                        $provider=[string](Get-EntryProperty $providerState 'Provider' '')
                        $busy=[bool](Get-EntryProperty $providerState 'Busy' $false)
                        $error=[string](Get-EntryProperty $providerState 'Error' '')
                        $phase=[string](Get-EntryProperty $providerState 'Phase' '')
                        $updated=[string](Get-EntryProperty $providerState 'Updated' (Get-EntryProperty $providerState 'UpdatedAt' ''))
                        $token=$provider+'|'+$mode+'|'+$phase+'|'+$updated
                        if(-not $busy -and -not $error -and [string]::Equals($mode,'Refresh',[StringComparison]::OrdinalIgnoreCase) -and $provider -and $token -ne $script:LastArtworkProviderRefreshToken){
                            $script:LastArtworkProviderRefreshToken=$token
                            Start-OnlineArtworkScan -ResetCursor -Force -Platform $provider
                        }
                    }catch{Write-Log "Provider-refresh artwork trigger failed: $($_.Exception.Message)" 'WARN'}

                    $transferBusy=$busy -and ($mode -in @('Install','Update'))
                    if($transferBusy){
                        # Provider telemetry may arrive several times per second. It is
                        # progress only: do not rebuild Games or destroy selection/scroll.
                        if($script:SelectedTab -eq 4 -and -not $script:SubPage -and (Get-Command Update-HcActiveDownloadVisuals -ErrorAction SilentlyContinue)){
                            if(-not(Update-HcActiveDownloadVisuals $providerState)){Render-Page}
                        }
                    }elseif($mode -in @('Install','Update')){
                        if($previousProviderStateSignature -and (Test-HcSuccessfulTransferTerminal $providerState)){
                            Request-HcDeferredLibraryRefresh ('provider-'+$provider+'-'+$mode+'-complete') 850
                        }
                        if($script:SelectedTab -eq 4){Render-Page}
                    }elseif($script:SelectedTab -in @(1,4)){
                        Render-Page
                    }
                }
            }
'@
$text=$text.Substring(0,$providerStart)+$providerBlock+$text.Substring($catalogStart)

$catalogStart=$text.IndexOf('            if ((Test-HcRuntimePathDirty $script:ProviderCatalogPath)',[StringComparison]::Ordinal)
$updateStart=$text.IndexOf('            if ((Test-HcRuntimePathDirty $script:UpdateStatePath)',[StringComparison]::Ordinal)
if($catalogStart -lt 0 -or $updateStart -le $catalogStart){throw 'Download refresh policy could not isolate provider catalog observer.'}
$catalogBlock=@'
            if ((Test-HcRuntimePathDirty $script:ProviderCatalogPath) -and (Test-Path $script:ProviderCatalogPath)) {
                $providerCatalogSignature=(Get-Item -LiteralPath $script:ProviderCatalogPath).LastWriteTimeUtc.Ticks.ToString()
                if(-not $script:ProviderCatalogSignature){
                    # First observation during startup is cache-only.
                    $script:ProviderCatalogSignature=$providerCatalogSignature
                    Read-GameProviderCatalog|Out-Null
                }elseif($providerCatalogSignature -ne $script:ProviderCatalogSignature){
                    $script:ProviderCatalogSignature=$providerCatalogSignature
                    Read-GameProviderCatalog|Out-Null
                    $script:HcDeferredProviderCatalogDirty=$true
                    $activeProviderTransfers=0
                    try{if(Get-Command Get-GameProviderActiveTransfers -ErrorAction SilentlyContinue){$activeProviderTransfers=@(Get-GameProviderActiveTransfers).Count}}catch{}
                    if($activeProviderTransfers -le 0){
                        # Coalesce the catalog invalidation with a nearby terminal
                        # provider-state event so one install completion = one refresh.
                        Request-HcDeferredLibraryRefresh 'provider-catalog-changed' 850
                    }
                }
            }
'@
$text=$text.Substring(0,$catalogStart)+$catalogBlock+$text.Substring($updateStart)

Set-Content -LiteralPath $ConsolePath -Value $text -Encoding UTF8
