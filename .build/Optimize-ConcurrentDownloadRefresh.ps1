param(
    [Parameter(Mandatory=$true)][string]$ConsolePath
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
if(-not(Test-Path -LiteralPath $ConsolePath -PathType Leaf)){throw "Console source missing: $ConsolePath"}
$text=Get-Content -Raw -LiteralPath $ConsolePath -Encoding UTF8
if($text -match 'HUYMAIER_CONCURRENT_DOWNLOAD_REFRESH_V1'){return}
$needle="                        if(`$lower.EndsWith('provider-state.json') -or `$lower.EndsWith('storefront-state.json') -or `$lower.EndsWith('provider-transfers.json')){`$script:HcDownloadHistoryDirty=`$true}"
if(-not $text.Contains($needle)){throw 'Concurrent download refresh transform requires the runtime hitch watcher marker.'}
$replacement="                        # HUYMAIER_CONCURRENT_DOWNLOAD_REFRESH_V1`r`n                        if(`$lower.EndsWith('provider-transfers.json')){Add-HcRuntimeDirtyPath `$script:ProviderStatePath}`r`n"+$needle
$text=$text.Replace($needle,$replacement)
Set-Content -LiteralPath $ConsolePath -Value $text -Encoding UTF8
