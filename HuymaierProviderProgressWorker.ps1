param(
    [Parameter(Mandatory=$true)][ValidateSet('GOG','Amazon')][string]$Provider,
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
$highWater=[int64]0
$smoothedRate=[double]0
$gameId='';$gameName='';$mode='Install';$phase='Downloading'
$tempCutoff=$started.AddSeconds(-4)

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
function Get-ObservedWriteBytes {
    param([string]$Root)
    if([string]::IsNullOrWhiteSpace($Root) -or -not(Test-Path -LiteralPath $Root -PathType Container)){return [int64]0}
    $cutoff=$started.AddSeconds(-3);$sum=[int64]0;$visited=0
    try{
        foreach($path in [IO.Directory]::EnumerateFiles($Root,'*',[IO.SearchOption]::AllDirectories)){
            if(++$visited -gt 50000){break}
            try{$file=New-Object IO.FileInfo($path);if($file.LastWriteTimeUtc -ge $cutoff){$sum+=[int64]$file.Length}}catch{}
        }
    }catch{}
    return $sum
}
function Read-ProviderOutputTail {
    $parts=New-Object System.Collections.ArrayList
    try{
        $files=Get-ChildItem -LiteralPath $env:TEMP -File -ErrorAction SilentlyContinue|Where-Object{$_.Name -match '^huymaier-provider-(out|err)-.*\.txt$' -and $_.LastWriteTimeUtc -ge $tempCutoff}|Sort-Object LastWriteTimeUtc -Descending|Select-Object -First 6
        foreach($file in @($files)){
            try{
                $lines=@(Get-Content -LiteralPath $file.FullName -Tail 100 -ErrorAction SilentlyContinue)
                if($lines.Count -gt 0){[void]$parts.Add(($lines -join "`n"))}
            }catch{}
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
    Write-Progress $true 'Downloading' -1 0 $ExpectedDownloadBytes $ExpectedInstallBytes 0 -1 'Preparing download telemetry…' 'Fallback monitor'
    while(Test-WorkerAlive){
        $state=Read-State
        if($null -ne $state){
            $statePid=[int](Get-Prop $state 'WorkerPid' 0)
            if(-not [bool](Get-Prop $state 'Busy' $false)){break}
            if($statePid -gt 0 -and $statePid -ne $WorkerPid){break}
            $gameId=[string](Get-Prop $state 'GameId' $gameId);$gameName=[string](Get-Prop $state 'GameName' $gameName);$mode=[string](Get-Prop $state 'Mode' $mode)
        }

        $observed=Get-ObservedWriteBytes $WatchPath
        if($observed -gt $highWater){$highWater=$observed}
        $now=[DateTime]::UtcNow;$seconds=[math]::Max(.15,($now-$lastSample).TotalSeconds);$delta=[math]::Max([int64]0,$highWater-$lastBytes);$instant=$delta/$seconds
        $smoothedRate=Get-SmoothedRate $smoothedRate $instant
        $lastBytes=$highWater;$lastSample=$now

        $output=Read-ProviderOutputTail
        $native=Get-ParsedOutputTelemetry $output
        $parsedPhase=[string](Get-Prop $native 'Phase' $phase)
        if($parsedPhase -in @('Downloading','Installing')){$phase=$parsedPhase}

        $nativeCurrent=[int64](Get-Prop $native 'CurrentBytes' 0)
        $nativeDownloadTotal=[int64](Get-Prop $native 'TotalBytes' 0)
        $nativeInstallTotal=[int64](Get-Prop $native 'InstallSizeBytes' 0)
        $downloadTotal=if($nativeDownloadTotal -gt 0){$nativeDownloadTotal}else{$ExpectedDownloadBytes}
        $installTotal=if($nativeInstallTotal -gt 0){$nativeInstallTotal}else{$ExpectedInstallBytes}
        if($phase -eq 'Downloading' -and $downloadTotal -gt 0 -and $nativeCurrent -le 0 -and $highWater -ge [int64]($downloadTotal*0.97)){$phase='Installing'}

        $current=if($nativeCurrent -gt 0){$nativeCurrent}else{$highWater}
        $total=if($phase -eq 'Installing'){$installTotal}else{$downloadTotal}
        $nativeRate=[double](Get-Prop $native 'SpeedBytesPerSec' 0)
        $rate=if($nativeRate -gt 0){$nativeRate}else{$smoothedRate}
        $progress=[int](Get-Prop $native 'Progress' -1)
        if($progress -lt 0 -and $total -gt 0){$progress=[int][math]::Min(99,[math]::Round(($current/[double]$total)*100))}
        $nativeEta=[int64](Get-Prop $native 'EtaSeconds' -1)
        $eta=if($nativeEta -ge 0){$nativeEta}else{Get-Eta $current $total $rate $progress}
        $source=if([bool](Get-Prop $native 'HasNativeProgress' $false) -or [bool](Get-Prop $native 'HasNativeSpeed' $false) -or [bool](Get-Prop $native 'HasNativeEta' $false)){'Backend output + fallback'}else{'Observed destination growth'}
        $amount=if($total -gt 0){(Format-ByteText $current)+' / '+(Format-ByteText $total)}elseif($current -gt 0){Format-ByteText $current}else{'Measuring activity…'}
        $message="$phase  •  $amount  •  $(Format-SpeedText $rate)  •  $(Format-EtaText $eta)"
        Write-Progress $true $phase $progress $current $downloadTotal $installTotal $rate $eta $message $source
        Start-Sleep -Milliseconds 900
    }
}finally{
    Write-Progress $false $phase -1 $highWater $ExpectedDownloadBytes $ExpectedInstallBytes 0 -1 'Provider telemetry monitor stopped.' 'Fallback monitor'
}
