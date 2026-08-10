param(
    [Parameter(Mandatory=$true)][ValidateSet('GOG','Amazon')][string]$Provider,
    [Parameter(Mandatory=$true)][string]$StatePath,
    [Parameter(Mandatory=$true)][string]$ProgressPath,
    [string]$WatchPath='',
    [Parameter(Mandatory=$true)][int]$WorkerPid
)

Set-StrictMode -Version 2.0
$ErrorActionPreference='SilentlyContinue'
$started=[DateTime]::UtcNow
$lastSample=$started
$lastBytes=[int64]0
$highWater=[int64]0
$gameId='';$gameName='';$mode='Install'

function Get-Prop {param($Object,[string]$Name,$Default=$null);if($null -eq $Object){return $Default};try{$p=$Object.PSObject.Properties[$Name];if($null -ne $p -and $null -ne $p.Value){return $p.Value}}catch{};return $Default}
function Read-State {if(-not(Test-Path -LiteralPath $StatePath -PathType Leaf)){return $null};try{return Get-Content -Raw -LiteralPath $StatePath|ConvertFrom-Json}catch{return $null}}
function Write-AtomicJson {param($Value);try{$tmp="$ProgressPath.$PID.tmp";$parent=Split-Path -Parent $ProgressPath;if($parent){New-Item -ItemType Directory -Force -Path $parent|Out-Null};$Value|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $tmp -Encoding UTF8;Move-Item -LiteralPath $tmp -Destination $ProgressPath -Force}catch{}}
function Test-WorkerAlive {try{$p=Get-Process -Id $WorkerPid -ErrorAction Stop;return -not $p.HasExited}catch{return $false}}
function Get-ObservedWriteBytes {
    param([string]$Root)
    if([string]::IsNullOrWhiteSpace($Root) -or -not(Test-Path -LiteralPath $Root -PathType Container)){return [int64]0}
    $cutoff=$started.AddSeconds(-3);$sum=[int64]0
    try{
        foreach($file in Get-ChildItem -LiteralPath $Root -File -Recurse -Force -ErrorAction SilentlyContinue){
            try{if($file.LastWriteTimeUtc -ge $cutoff){$sum+=[int64]$file.Length}}catch{}
        }
    }catch{}
    return $sum
}
function Write-Progress {
    param([bool]$Busy,[int64]$Bytes,[double]$Rate,[string]$Message)
    Write-AtomicJson ([pscustomobject]@{
        Busy=$Busy;Provider=$Provider;Mode=$mode;GameId=$gameId;GameName=$gameName;WorkerPid=$WorkerPid;
        WatchPath=$WatchPath;Progress=-1;ActivityBytes=[int64]$Bytes;ActivityBytesPerSec=[double]$Rate;
        Message=$Message;TelemetryKind='Observed install writes';StartedAt=$started.ToString('o');Updated=[DateTime]::UtcNow.ToString('o')
    })
}

try{
    $initial=Read-State
    if($null -ne $initial){$gameId=[string](Get-Prop $initial 'GameId' '');$gameName=[string](Get-Prop $initial 'GameName' '');$mode=[string](Get-Prop $initial 'Mode' 'Install')}
    Write-Progress $true 0 0 'Waiting for provider file activity.'
    while(Test-WorkerAlive){
        $state=Read-State
        if($null -ne $state){
            $statePid=[int](Get-Prop $state 'WorkerPid' 0)
            if(-not [bool](Get-Prop $state 'Busy' $false)){break}
            # Once the authoritative worker has published its real PID, never
            # attach this sidecar to a later provider task that reused the file.
            if($statePid -gt 0 -and $statePid -ne $WorkerPid){break}
            $gameId=[string](Get-Prop $state 'GameId' $gameId);$gameName=[string](Get-Prop $state 'GameName' $gameName);$mode=[string](Get-Prop $state 'Mode' $mode)
        }
        $observed=Get-ObservedWriteBytes $WatchPath
        if($observed -gt $highWater){$highWater=$observed}
        $now=[DateTime]::UtcNow;$seconds=[math]::Max(.1,($now-$lastSample).TotalSeconds);$delta=[math]::Max([int64]0,$highWater-$lastBytes);$rate=$delta/$seconds
        $lastBytes=$highWater;$lastSample=$now
        $message=$(if($highWater -gt 0){'Provider is writing game data. Exact network percentage is not exposed by this backend.'}else{'Waiting for provider download/install activity.'})
        Write-Progress $true $highWater $rate $message
        Start-Sleep -Milliseconds 1500
    }
}finally{
    # This sidecar never writes provider-state.json, so it cannot overwrite the
    # authoritative worker's Complete/Failed result. Mark it inactive only.
    Write-Progress $false $highWater 0 'Provider telemetry monitor stopped.'
}
