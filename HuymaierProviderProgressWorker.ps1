param(
    [Parameter(Mandatory=$true)][ValidateSet('Epic','GOG','Amazon')][string]$Provider,
    # HUYMAIER_PROVIDER_PROGRESS_TRANSFER_ID_V1
    [string]$TransferId='',
    [Parameter(Mandatory=$true)][string]$StatePath,
    [Parameter(Mandatory=$true)][string]$ProgressPath,
    [string]$WatchPath='',
    [Parameter(Mandatory=$true)][int]$WorkerPid,
    [string]$TelemetryHelperPath='',
    [int64]$ExpectedDownloadBytes=0,
    [int64]$ExpectedInstallBytes=0
)

Set-StrictMode -Version 2.0
$ErrorActionPreference='SilentlyContinue'
if($TelemetryHelperPath -and (Test-Path -LiteralPath $TelemetryHelperPath -PathType Leaf)){try{. $TelemetryHelperPath}catch{}}

$started=[DateTime]::UtcNow
$lastSample=$started
$lastBytes=[int64]0
$observedBytes=[int64]0
$phaseBaselineBytes=[int64]0
$smoothedRate=[double]0
$gameId='';$gameName='';$mode='Install';$phase='Downloading';$lastPhase='Downloading'
$tempCutoff=$started.AddSeconds(-4)
$script:ObservedFileLengths=@{}
$script:WriteWatcher=$null
$script:WriteWatcherSource='Huymaier.ProviderWrites.'+$PID

function Get-Prop {param($Object,[string]$Name,$Default=$null);if($null -eq $Object){return $Default};try{$p=$Object.PSObject.Properties[$Name];if($null -ne $p -and $null -ne $p.Value){return $p.Value}}catch{};return $Default}
function Read-State {if(-not(Test-Path -LiteralPath $StatePath -PathType Leaf)){return $null};try{return Get-Content -Raw -LiteralPath $StatePath|ConvertFrom-Json}catch{return $null}}
function Write-AtomicJson {param($Value);try{$tmp="$ProgressPath.$PID.tmp";$parent=Split-Path -Parent $ProgressPath;if($parent){New-Item -ItemType Directory -Force -Path $parent|Out-Null};$Value|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $tmp -Encoding UTF8;Move-Item -LiteralPath $tmp -Destination $ProgressPath -Force}catch{}}
function Test-WorkerAlive {try{$p=Get-Process -Id $WorkerPid -ErrorAction Stop;return -not $p.HasExited}catch{return $false}}
function Format-ByteText {
    param([int64]$Bytes)
    if(Get-Command Format-HcTelemetryBytes -ErrorAction SilentlyContinue){return Format-HcTelemetryBytes $Bytes}
    if($Bytes -ge 1GB){return ('{0:N2} GB' -f ($Bytes/1GB))};if($Bytes -ge 1MB){return ('{0:N1} MB' -f ($Bytes/1MB))};return ('{0:N0} KB' -f ($Bytes/1KB))
}
function Format-SpeedText {
    param([double]$BytesPerSecond)
    if(Get-Command Format-HcTelemetrySpeed -ErrorAction SilentlyContinue){return Format-HcTelemetrySpeed $BytesPerSecond}
    if($BytesPerSecond -le 0){return 'Measuring speed…'};if($BytesPerSecond -ge 1MB){return ('{0:N1} MB/s' -f ($BytesPerSecond/1MB))};return ('{0:N0} KB/s' -f ($BytesPerSecond/1KB))
}
function Format-EtaText {
    param([int64]$Seconds)
    if(Get-Command Format-HcTelemetryEta -ErrorAction SilentlyContinue){return Format-HcTelemetryEta $Seconds}
    if($Seconds -lt 0){return 'Calculating ETA…'};$span=[TimeSpan]::FromSeconds($Seconds);if($span.TotalHours -ge 1){return ('ETA {0}:{1:00}:{2:00}' -f [int]$span.TotalHours,$span.Minutes,$span.Seconds)};return ('ETA {0}:{1:00}' -f [int]$span.TotalMinutes,$span.Seconds)
}
function Get-SmoothedRate {
    param([double]$Previous,[double]$Instant)
    if(Get-Command Get-HcSmoothedTelemetryRate -ErrorAction SilentlyContinue){return [double](Get-HcSmoothedTelemetryRate $Previous $Instant 0.24)}
    if($Instant -le 0){return [math]::Max(0,$Previous*0.85)};if($Previous -le 0){return $Instant};return (($Previous*0.76)+($Instant*0.24))
}
function Get-Eta {
    param([int64]$Current,[int64]$Total,[double]$Rate,[int]$Progress=-1)
    if(Get-Command Get-HcTelemetryEtaSeconds -ErrorAction SilentlyContinue){return [int64](Get-HcTelemetryEtaSeconds $Current $Total $Rate $Progress ([math]::Max(0,([DateTime]::UtcNow-$started).TotalSeconds)))}
    if($Total -gt 0 -and $Rate -gt 1){return [int64][math]::Ceiling([math]::Max(0,$Total-$Current)/$Rate)};return [int64]-1
}
function Get-ExistingWatchRoot {
    param([string]$Path)
    if([string]::IsNullOrWhiteSpace($Path)){return ''}
    $candidate=$Path
    while($candidate){
        if(Test-Path -LiteralPath $candidate -PathType Container){return $candidate}
        try{$parent=Split-Path -Parent $candidate}catch{$parent=''}
        if(-not $parent -or [string]::Equals($parent,$candidate,[StringComparison]::OrdinalIgnoreCase)){break}
        $candidate=$parent
    }
    return ''
}
function Start-WriteObservation {
    if($null -ne $script:WriteWatcher){return $true}
    $root=Get-ExistingWatchRoot $WatchPath
    if(-not $root){return $false}
    try{
        $watcher=New-Object IO.FileSystemWatcher $root,'*'
        $watcher.IncludeSubdirectories=$true
        $watcher.NotifyFilter=[IO.NotifyFilters]::FileName -bor [IO.NotifyFilters]::Size -bor [IO.NotifyFilters]::LastWrite
        $watcher.InternalBufferSize=32768
        [void](Register-ObjectEvent -InputObject $watcher -EventName Changed -SourceIdentifier ($script:WriteWatcherSource+'.Changed'))
        [void](Register-ObjectEvent -InputObject $watcher -EventName Created -SourceIdentifier ($script:WriteWatcherSource+'.Created'))
        [void](Register-ObjectEvent -InputObject $watcher -EventName Renamed -SourceIdentifier ($script:WriteWatcherSource+'.Renamed'))
        $watcher.EnableRaisingEvents=$true
        $script:WriteWatcher=$watcher
        return $true
    }catch{return $false}
}
function Stop-WriteObservation {
    try{if($null -ne $script:WriteWatcher){$script:WriteWatcher.EnableRaisingEvents=$false}}catch{}
    foreach($suffix in @('Changed','Created','Renamed')){
        $id=$script:WriteWatcherSource+'.'+$suffix
        try{Unregister-Event -SourceIdentifier $id -ErrorAction SilentlyContinue}catch{}
        try{Get-Event -SourceIdentifier $id -ErrorAction SilentlyContinue|Remove-Event -ErrorAction SilentlyContinue}catch{}
    }
    try{if($null -ne $script:WriteWatcher){$script:WriteWatcher.Dispose()}}catch{}
    $script:WriteWatcher=$null
}
function Update-ObservedWriteBytes {
    [int64]$added=0
    foreach($suffix in @('Changed','Created','Renamed')){
        $id=$script:WriteWatcherSource+'.'+$suffix
        $events=@(Get-Event -SourceIdentifier $id -ErrorAction SilentlyContinue)
        foreach($evt in $events){
            try{
                $full=[string]$evt.SourceEventArgs.FullPath
                if($full -and (Test-Path -LiteralPath $full -PathType Leaf)){
                    $length=[int64](Get-Item -LiteralPath $full -ErrorAction Stop).Length
                    $key=$full.ToLowerInvariant();$before=[int64]0
                    if($script:ObservedFileLengths.ContainsKey($key)){$before=[int64]$script:ObservedFileLengths[$key]}
                    if($length -gt $before){$added+=($length-$before)}
                    $script:ObservedFileLengths[$key]=$length
                }
            }catch{}
            try{Remove-Event -EventIdentifier $evt.EventIdentifier -ErrorAction SilentlyContinue}catch{}
        }
    }
    return $added
}
function Read-ProviderOutputTail {
    $parts=New-Object System.Collections.ArrayList
    try{
        $capturePattern=if($TransferId){'^huymaier-provider-(out|err)-'+[regex]::Escape($TransferId)+'\.txt$'}else{'^huymaier-provider-(out|err)-.*\.txt$'}
        $files=Get-ChildItem -LiteralPath $env:TEMP -File -ErrorAction SilentlyContinue|Where-Object{$_.Name -match $capturePattern -and $_.LastWriteTimeUtc -ge $tempCutoff}|Sort-Object LastWriteTimeUtc -Descending|Select-Object -First 6
        foreach($file in @($files)){
            try{$lines=@(Get-Content -LiteralPath $file.FullName -Tail 100 -ErrorAction SilentlyContinue);if($lines.Count -gt 0){[void]$parts.Add(($lines -join "`n"))}}catch{}
        }
    }catch{}
    return ([string]::Join("`n",[object[]]$parts.ToArray()))
}
function Get-ParsedOutputTelemetry {
    param([string]$Text)
    if(Get-Command Get-HcProviderOutputTelemetry -ErrorAction SilentlyContinue){try{return Get-HcProviderOutputTelemetry $Text $phase}catch{}}
    return [pscustomobject]@{Phase=$phase;Progress=-1;CurrentBytes=0;TotalBytes=0;InstallSizeBytes=0;SpeedBytesPerSec=0;EtaSeconds=-1;HasNativeProgress=$false;HasNativeSpeed=$false;HasNativeEta=$false}
}
function Write-Progress {
    param([bool]$Busy,[string]$Phase,[int]$Progress,[int64]$Current,[int64]$Total,[int64]$InstallTotal,[double]$Rate,[int64]$Eta,[string]$Message,[string]$Source)
    Write-AtomicJson ([pscustomobject]@{
        Busy=$Busy;Provider=$Provider;Mode=$mode;Phase=$Phase;GameId=$gameId;GameName=$gameName;WorkerPid=$WorkerPid;
        WatchPath=$WatchPath;Progress=$Progress;CurrentBytes=[int64]$Current;TotalBytes=[int64]$Total;InstallSizeBytes=[int64]$InstallTotal;
        SpeedBytesPerSec=[double]$Rate;EtaSeconds=[int64]$Eta;Message=$Message;TelemetryKind=$Source;
        StartedAt=$started.ToString('o');Updated=[DateTime]::UtcNow.ToString('o')
    })
}

try{
    $initial=Read-State
    if($null -ne $initial){$gameId=[string](Get-Prop $initial 'GameId' '');$gameName=[string](Get-Prop $initial 'GameName' '');$mode=[string](Get-Prop $initial 'Mode' 'Install')}
    [void](Start-WriteObservation)
    Write-Progress $true 'Downloading' -1 0 $ExpectedDownloadBytes $ExpectedInstallBytes 0 -1 'Preparing download telemetry…' 'Fallback monitor'
    while(Test-WorkerAlive){
        $state=Read-State
        if($null -ne $state){
            $statePid=[int](Get-Prop $state 'WorkerPid' 0)
            if(-not [bool](Get-Prop $state 'Busy' $false)){break}
            if($statePid -gt 0 -and $statePid -ne $WorkerPid){break}
            $gameId=[string](Get-Prop $state 'GameId' $gameId);$gameName=[string](Get-Prop $state 'GameName' $gameName);$mode=[string](Get-Prop $state 'Mode' $mode)
        }
        if($null -eq $script:WriteWatcher){[void](Start-WriteObservation)}
        $observedBytes+=[int64](Update-ObservedWriteBytes)

        $output=Read-ProviderOutputTail
        $native=Get-ParsedOutputTelemetry $output
        $parsedPhase=[string](Get-Prop $native 'Phase' $phase)
        if($parsedPhase -in @('Downloading','Installing')){$phase=$parsedPhase}

        $nativeCurrent=[int64](Get-Prop $native 'CurrentBytes' 0)
        $nativeDownloadTotal=[int64](Get-Prop $native 'TotalBytes' 0)
        $nativeInstallTotal=[int64](Get-Prop $native 'InstallSizeBytes' 0)
        $downloadTotal=if($nativeDownloadTotal -gt 0){$nativeDownloadTotal}else{$ExpectedDownloadBytes}
        $installTotal=if($nativeInstallTotal -gt 0){$nativeInstallTotal}else{$ExpectedInstallBytes}
        if($phase -eq 'Downloading' -and $downloadTotal -gt 0 -and $nativeCurrent -le 0 -and $observedBytes -ge [int64]($downloadTotal*0.97)){$phase='Installing'}

        if($phase -ne $lastPhase){
            $phaseBaselineBytes=$observedBytes
            $lastBytes=$observedBytes
            $smoothedRate=0
            $lastSample=[DateTime]::UtcNow
            $lastPhase=$phase
        }
        [int64]$phaseObserved=[math]::Max([int64]0,$observedBytes-$phaseBaselineBytes)
        $now=[DateTime]::UtcNow;$seconds=[math]::Max(.15,($now-$lastSample).TotalSeconds);$delta=[math]::Max([int64]0,$observedBytes-$lastBytes);$instant=$delta/$seconds
        $smoothedRate=Get-SmoothedRate $smoothedRate $instant
        $lastBytes=$observedBytes;$lastSample=$now

        $installNativeCurrent=($phase -eq 'Installing' -and $nativeInstallTotal -gt 0 -and $nativeCurrent -gt 0)
        $current=if($phase -eq 'Installing'){if($installNativeCurrent){$nativeCurrent}else{$phaseObserved}}else{if($nativeCurrent -gt 0){$nativeCurrent}else{$observedBytes}}
        $total=if($phase -eq 'Installing'){$installTotal}else{$downloadTotal}
        $nativeRate=[double](Get-Prop $native 'SpeedBytesPerSec' 0)
        $rate=if($phase -eq 'Downloading' -and $nativeRate -gt 0){$nativeRate}else{$smoothedRate}
        $progress=[int](Get-Prop $native 'Progress' -1)
        if($phase -eq 'Installing' -and -not $installNativeCurrent){$progress=-1}
        if($progress -lt 0 -and $total -gt 0){$progress=[int][math]::Min(99,[math]::Round(($current/[double]$total)*100))}
        $nativeEta=[int64](Get-Prop $native 'EtaSeconds' -1)
        $useNativeEta=($phase -eq 'Downloading' -and $nativeEta -ge 0) -or ($phase -eq 'Installing' -and $nativeInstallTotal -gt 0 -and $nativeEta -ge 0)
        $eta=if($useNativeEta){$nativeEta}else{Get-Eta $current $total $rate $progress}
        $hasNative=[bool](Get-Prop $native 'HasNativeProgress' $false) -or [bool](Get-Prop $native 'HasNativeSpeed' $false) -or [bool](Get-Prop $native 'HasNativeEta' $false)
        $source=if($hasNative){'Backend output + incremental fallback'}else{'Incremental destination writes'}
        $amount=if($total -gt 0){(Format-ByteText $current)+' / '+(Format-ByteText $total)}elseif($current -gt 0){Format-ByteText $current}else{'Measuring activity…'}
        $message="$phase  •  $amount  •  $(Format-SpeedText $rate)  •  $(Format-EtaText $eta)"
        Write-Progress $true $phase $progress $current $downloadTotal $installTotal $rate $eta $message $source
        Start-Sleep -Milliseconds 750
    }
}finally{
    Stop-WriteObservation
    Write-Progress $false $phase -1 ([math]::Max([int64]0,$observedBytes-$phaseBaselineBytes)) $ExpectedDownloadBytes $ExpectedInstallBytes 0 -1 'Provider telemetry monitor stopped.' 'Fallback monitor'
}
