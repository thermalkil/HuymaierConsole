param(
    [Parameter(Mandatory=$true)][string]$ProviderModulePath,
    [Parameter(Mandatory=$true)][string]$ProviderWorkerPath,
    [Parameter(Mandatory=$true)][string]$ProgressWorkerPath,
    [Parameter(Mandatory=$true)][string]$CoordinatorPath
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'

foreach($path in @($ProviderModulePath,$ProviderWorkerPath,$ProgressWorkerPath,$CoordinatorPath)){if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "Provider download optimizer could not find $path"}}

function Replace-HcExact {
    param([ref]$Text,[string]$Label,[string]$Old,[string]$New)
    $value=[string]$Text.Value
    $first=$value.IndexOf($Old,[StringComparison]::Ordinal)
    if($first -lt 0){throw "Provider download optimizer could not find the expected $Label block."}
    if($value.IndexOf($Old,$first+$Old.Length,[StringComparison]::Ordinal) -ge 0){throw "Provider download optimizer found duplicate $Label blocks."}
    $Text.Value=$value.Substring(0,$first)+$New+$value.Substring($first+$Old.Length)
}
function Write-HcUtf8Bom {param([string]$Path,[string]$Text);$bom=New-Object Text.UTF8Encoding($true);[IO.File]::WriteAllText($Path,$Text,$bom)}

$worker=[IO.File]::ReadAllText($ProviderWorkerPath,[Text.Encoding]::UTF8)
Replace-HcExact ([ref]$worker) 'Legendary telemetry formatters' @'
function Format-ProviderSpeedValue{
    param([double]$BytesPerSecond)
    if($BytesPerSecond -ge 1GB){return ('{0:N2} GB/s' -f ($BytesPerSecond/1GB))}
    if($BytesPerSecond -ge 1MB){return ('{0:N1} MB/s' -f ($BytesPerSecond/1MB))}
    if($BytesPerSecond -ge 1KB){return ('{0:N0} KB/s' -f ($BytesPerSecond/1KB))}
    return ('{0:N0} B/s' -f $BytesPerSecond)
}
function Update-LegendaryTransferTelemetry{
'@ @'
function Format-ProviderSpeedValue{
    param([double]$BytesPerSecond)
    if($BytesPerSecond -ge 1GB){return ('{0:N2} GB/s' -f ($BytesPerSecond/1GB))}
    if($BytesPerSecond -ge 1MB){return ('{0:N1} MB/s' -f ($BytesPerSecond/1MB))}
    if($BytesPerSecond -ge 1KB){return ('{0:N0} KB/s' -f ($BytesPerSecond/1KB))}
    return ('{0:N0} B/s' -f $BytesPerSecond)
}
function Format-ProviderEtaValue{
    param([int64]$Seconds)
    if($Seconds -lt 0){return 'Calculating ETA…'}
    $span=[TimeSpan]::FromSeconds([math]::Max(0,$Seconds))
    if($span.TotalHours -ge 1){return ('ETA {0}:{1:00}:{2:00}' -f [int]$span.TotalHours,$span.Minutes,$span.Seconds)}
    return ('ETA {0}:{1:00}' -f [int]$span.TotalMinutes,$span.Seconds)
}
function Get-LegendaryTransferPhase{
    param([string]$Text)
    if([string]::IsNullOrWhiteSpace($Text)){return 'Downloading'}
    $download=[regex]::Matches($Text,'(?im)\b(downloading|downloaded|download|fetching|transferring)\b')
    $install=[regex]::Matches($Text,'(?im)\b(installing|extracting|unpacking|decompressing|applying|finalizing|finalising|writing files|installing prerequisites)\b')
    $downloadIndex=if($download.Count -gt 0){$download[$download.Count-1].Index}else{-1}
    $installIndex=if($install.Count -gt 0){$install[$install.Count-1].Index}else{-1}
    return $(if($installIndex -gt $downloadIndex){'Installing'}else{'Downloading'})
}
function Update-LegendaryTransferTelemetry{
'@
Replace-HcExact ([ref]$worker) 'Legendary state write' @'
        Write-State $true 'Downloading' "$amount  •  $speed" $(if($progress -ge 0){$progress}else{5}) -Quiet
'@ @'
        $phase=Get-LegendaryTransferPhase $Text
        $visibleEta=if($phase -eq 'Installing'){-1}else{$script:TransferEtaSeconds}
        $etaText=Format-ProviderEtaValue $visibleEta
        Write-State $true $phase "$phase  •  $amount  •  $speed  •  $etaText" $(if($progress -ge 0){$progress}else{5}) -Quiet
'@
Write-HcUtf8Bom $ProviderWorkerPath $worker

$module=[IO.File]::ReadAllText($ProviderModulePath,[Text.Encoding]::UTF8)
$oldDownloadActions=@'
function Get-ProviderDownloadPageActions {
    $state=Read-GameProviderState
    if($null -eq $state){return @()}
    $message=[string](Get-EntryProperty $state 'Message' '')
    if([bool](Get-EntryProperty $state 'Busy' $false)){return @((New-Action 'noop' $message "$([string](Get-EntryProperty $state 'Provider' 'Provider'))  |  $([string](Get-EntryProperty $state 'Phase' 'Working'))"),(New-Action 'provider-cancel' 'Cancel provider operation' 'Stops the background worker. Completed files are retained where supported.'))}
    $providerError=[string](Get-EntryProperty $state 'Error' '')
    if($providerError){
        $failedProvider=[string](Get-EntryProperty $state 'Provider' 'Provider')
        if([string]::Equals($failedProvider,'GOG',[StringComparison]::OrdinalIgnoreCase) -and $providerError -match '(?i)(not compatible|architecture|executable)'){
            return @(
                (New-Action 'provider-setup:GOG' 'Repair GOG backend' 'Replace the incompatible backend with the official Windows x86-64 build.'),
                (New-Action 'noop' 'Previous GOG error' $providerError)
            )
        }
        return @((New-Action 'noop' "${failedProvider}: $([string](Get-EntryProperty $state 'Phase' 'Failed'))" $providerError))
    }
    if($message){return @((New-Action 'noop' $message "$([string](Get-EntryProperty $state 'Provider' 'Provider')) provider"))}
    return @()
}
'@
$newDownloadActions=@'
function Format-ProviderDownloadBytes {
    param([int64]$Bytes)
    if($Bytes -ge 1TB){return ('{0:N2} TB' -f ($Bytes/1TB))};if($Bytes -ge 1GB){return ('{0:N2} GB' -f ($Bytes/1GB))};if($Bytes -ge 1MB){return ('{0:N1} MB' -f ($Bytes/1MB))};if($Bytes -ge 1KB){return ('{0:N0} KB' -f ($Bytes/1KB))};return "$Bytes B"
}
function Format-ProviderDownloadSpeed {
    param([double]$BytesPerSecond)
    if($BytesPerSecond -le 0){return 'Measuring speed…'};if($BytesPerSecond -ge 1GB){return ('{0:N2} GB/s' -f ($BytesPerSecond/1GB))};if($BytesPerSecond -ge 1MB){return ('{0:N1} MB/s' -f ($BytesPerSecond/1MB))};if($BytesPerSecond -ge 1KB){return ('{0:N0} KB/s' -f ($BytesPerSecond/1KB))};return ('{0:N0} B/s' -f $BytesPerSecond)
}
function Format-ProviderDownloadEta {
    param([int64]$Seconds)
    if($Seconds -lt 0){return 'Calculating ETA…'};$span=[TimeSpan]::FromSeconds([math]::Max(0,$Seconds));if($span.TotalHours -ge 1){return ('ETA {0}:{1:00}:{2:00}' -f [int]$span.TotalHours,$span.Minutes,$span.Seconds)};return ('ETA {0}:{1:00}' -f [int]$span.TotalMinutes,$span.Seconds)
}
function Get-ProviderDownloadDisplay {
    param($State)
    $provider=[string](Get-EntryProperty $State 'Provider' 'Provider');$mode=[string](Get-EntryProperty $State 'Mode' '');$phase=[string](Get-EntryProperty $State 'Phase' 'Working')
    if($mode -in @('Install','Update') -and $phase -in @('Starting','Install','Update','Preparing download')){$phase='Downloading'}
    $progress=[int](Get-EntryProperty $State 'Progress' -1);$installing=[string]::Equals($phase,'Installing',[StringComparison]::OrdinalIgnoreCase)
    [int64]$current=if($installing){[int64](Get-EntryProperty $State 'InstallProcessedBytes' 0)}else{[int64](Get-EntryProperty $State 'DownloadedBytes' 0)}
    [int64]$total=if($installing){[int64](Get-EntryProperty $State 'InstallSizeBytes' 0)}else{[int64](Get-EntryProperty $State 'TotalBytes' 0)}
    [double]$speed=if($installing){[double](Get-EntryProperty $State 'InstallSpeedBytesPerSec' (Get-EntryProperty $State 'TransferSpeedBytesPerSec' 0))}else{[double](Get-EntryProperty $State 'DownloadSpeedBytesPerSec' (Get-EntryProperty $State 'TransferSpeedBytesPerSec' 0))}
    [int64]$eta=[int64](Get-EntryProperty $State 'EtaSeconds' -1)
    $amount=if($total -gt 0){"$(Format-ProviderDownloadBytes $current) / $(Format-ProviderDownloadBytes $total)"}elseif($current -gt 0){Format-ProviderDownloadBytes $current}else{'Measuring activity…'}
    $progressText=if($progress -ge 0){"$progress%"}else{'Progress calculating…'}
    $detail="$provider  •  $progressText  •  $amount  •  $(Format-ProviderDownloadSpeed $speed)  •  $(Format-ProviderDownloadEta $eta)"
    return [pscustomobject]@{Phase=$phase;Detail=$detail}
}
function Get-ProviderDownloadPageActions {
    $state=Read-GameProviderState
    if($null -eq $state){return @()}
    $message=[string](Get-EntryProperty $state 'Message' '')
    if([bool](Get-EntryProperty $state 'Busy' $false)){
        $display=Get-ProviderDownloadDisplay $state;$game=[string](Get-EntryProperty $state 'GameName' '')
        $title=if($game){"$([string]$display.Phase): $game"}else{[string]$display.Phase}
        return @((New-Action 'noop' $title ([string]$display.Detail)),(New-Action 'provider-cancel' 'Cancel provider operation' 'Stops the background worker. Completed files are retained where supported.'))
    }
    $providerError=[string](Get-EntryProperty $state 'Error' '')
    if($providerError){
        $failedProvider=[string](Get-EntryProperty $state 'Provider' 'Provider')
        if([string]::Equals($failedProvider,'GOG',[StringComparison]::OrdinalIgnoreCase) -and $providerError -match '(?i)(not compatible|architecture|executable)'){
            return @(
                (New-Action 'provider-setup:GOG' 'Repair GOG backend' 'Replace the incompatible backend with the official Windows x86-64 build.'),
                (New-Action 'noop' 'Previous GOG error' $providerError)
            )
        }
        return @((New-Action 'noop' "${failedProvider}: $([string](Get-EntryProperty $state 'Phase' 'Failed'))" $providerError))
    }
    if($message){return @((New-Action 'noop' $message "$([string](Get-EntryProperty $state 'Provider' 'Provider')) provider"))}
    return @()
}
'@
Replace-HcExact ([ref]$module) 'Downloads provider action formatter' $oldDownloadActions $newDownloadActions
Write-HcUtf8Bom $ProviderModulePath $module

$progress=[IO.File]::ReadAllText($ProgressWorkerPath,[Text.Encoding]::UTF8)
Replace-HcExact ([ref]$progress) 'provider progress ValidateSet' "[Parameter(Mandatory=`$true)][ValidateSet('GOG','Amazon')][string]`$Provider" "[Parameter(Mandatory=`$true)][ValidateSet('Epic','GOG','Amazon')][string]`$Provider"
Write-HcUtf8Bom $ProgressWorkerPath $progress

$coordinator=[IO.File]::ReadAllText($CoordinatorPath,[Text.Encoding]::UTF8)
$oldFilter='$provider -notin @(''GOG'',''Amazon'')'
$newFilter='$provider -notin @(''Epic'',''GOG'',''Amazon'')'
$matches=[regex]::Matches($coordinator,[regex]::Escape($oldFilter))
if($matches.Count -lt 1){throw 'Provider download optimizer could not find a coordinator provider filter.'}
$coordinator=$coordinator.Replace($oldFilter,$newFilter)
Write-HcUtf8Bom $CoordinatorPath $coordinator

Write-Host 'Applied normalized Downloading/Installing speed and ETA presentation for Epic, GOG and Amazon.'