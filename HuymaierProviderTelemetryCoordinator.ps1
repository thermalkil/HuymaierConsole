param(
    [Parameter(Mandatory=$true)][int]$ParentPid,
    [Parameter(Mandatory=$true)][string]$BaseDir,
    [Parameter(Mandatory=$true)][string]$DataDir
)

Set-StrictMode -Version 2.0
$ErrorActionPreference='SilentlyContinue'

$providerRoot=Join-Path $DataDir 'GameProviders'
$statePath=Join-Path $providerRoot 'provider-state.json'
$catalogPath=Join-Path $providerRoot 'provider-catalog.json'
$managedPath=Join-Path $providerRoot 'managed-installs.json'
$configPath=Join-Path $DataDir 'config.json'
$progressPath=Join-Path $providerRoot 'provider-progress.json'
$progressWorkerPath=Join-Path $BaseDir 'HuymaierProviderProgressWorker.ps1'
$telemetryHelperPath=Join-Path $BaseDir 'HuymaierProviderTelemetry.ps1'
$progressProcess=$null
$operationKey=''

function Get-Prop {param($Object,[string]$Name,$Default=$null);if($null -eq $Object){return $Default};try{$p=$Object.PSObject.Properties[$Name];if($null -ne $p -and $null -ne $p.Value){return $p.Value}}catch{};return $Default}
function Set-Prop {param($Object,[string]$Name,$Value);try{$p=$Object.PSObject.Properties[$Name];if($null -eq $p){$Object|Add-Member -NotePropertyName $Name -NotePropertyValue $Value -Force}else{$Object.$Name=$Value}}catch{}}
function Read-Json {param([string]$Path);if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){return $null};try{return Get-Content -Raw -LiteralPath $Path -Encoding UTF8|ConvertFrom-Json}catch{return $null}}
function Test-ProcessAlive {param([int]$Id);if($Id -le 0){return $false};try{$p=Get-Process -Id $Id -ErrorAction Stop;return -not $p.HasExited}catch{return $false}}
function Stop-ProgressProcess {try{if($null -ne $script:progressProcess){$script:progressProcess.Refresh();if(-not $script:progressProcess.HasExited){Stop-Process -Id $script:progressProcess.Id -Force -ErrorAction SilentlyContinue}}}catch{};$script:progressProcess=$null}
function Write-AtomicState {
    param($State,[string]$ExpectedUpdated,[string]$ExpectedPhase,[int]$ExpectedWorkerPid)
    try{
        $latest=Read-Json $statePath
        if($null -eq $latest){return $false}
        if(-not [bool](Get-Prop $latest 'Busy' $false)){return $false}
        if([int](Get-Prop $latest 'WorkerPid' 0) -ne $ExpectedWorkerPid){return $false}
        if(-not [string]::Equals([string](Get-Prop $latest 'Updated' ''),$ExpectedUpdated,[StringComparison]::Ordinal)){return $false}
        if(-not [string]::Equals([string](Get-Prop $latest 'Phase' ''),$ExpectedPhase,[StringComparison]::Ordinal)){return $false}
        $tmp="$statePath.telemetry.$PID.tmp"
        $State|ConvertTo-Json -Depth 12|Set-Content -LiteralPath $tmp -Encoding UTF8
        Move-Item -LiteralPath $tmp -Destination $statePath -Force
        return $true
    }catch{return $false}
}
function Get-ConfiguredInstallRoot {
    param([string]$Provider)
    $config=Read-Json $configPath
    foreach($entry in @(Get-Prop $config 'ProviderInstallRoots' @())){
        if([string]::Equals([string](Get-Prop $entry 'Provider' ''),$Provider,[StringComparison]::OrdinalIgnoreCase)){
            $path=[string](Get-Prop $entry 'Path' '')
            if($path){return $path}
        }
    }
    $driveRoot='C:\'
    try{$best=Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue|Where-Object{$_.Root -and $null -ne $_.Free}|Sort-Object Free -Descending|Select-Object -First 1;if($best -and $best.Root){$driveRoot=[string]$best.Root}}catch{}
    return (Join-Path $driveRoot (Join-Path 'Games' $Provider))
}
function Get-ManagedInstallPath {
    param([string]$Provider,[string]$GameId)
    $managed=Read-Json $managedPath
    foreach($item in @($managed)){
        if([string]::Equals([string](Get-Prop $item 'Provider' ''),$Provider,[StringComparison]::OrdinalIgnoreCase) -and [string]::Equals([string](Get-Prop $item 'Id' ''),$GameId,[StringComparison]::OrdinalIgnoreCase)){
            return [string](Get-Prop $item 'Path' '')
        }
    }
    return ''
}
function Get-WatchPath {
    param([string]$Provider,[string]$Mode,[string]$GameId,[string]$GameName)
    $managed=Get-ManagedInstallPath $Provider $GameId
    if($Mode -eq 'Update' -and $managed){return $managed}
    $root=Get-ConfiguredInstallRoot $Provider
    if([string]::Equals($Provider,'GOG',[StringComparison]::OrdinalIgnoreCase) -and $Mode -eq 'Install'){
        $safeName=if($GameName){$GameName -replace '[<>:"/\\|?*]','_'}else{$GameId}
        return Join-Path $root $safeName
    }
    return $root
}
function Get-CatalogGame {
    param([string]$Provider,[string]$GameId)
    $catalog=Read-Json $catalogPath
    foreach($node in @(Get-Prop $catalog 'Providers' @())){
        if(-not [string]::Equals([string](Get-Prop $node 'Id' ''),$Provider,[StringComparison]::OrdinalIgnoreCase)){continue}
        foreach($game in @(Get-Prop $node 'Games' @())){if([string]::Equals([string](Get-Prop $game 'Id' ''),$GameId,[StringComparison]::OrdinalIgnoreCase)){return $game}}
    }
    return $null
}
function Get-ExpectedSizes {
    param($State)
    [int64]$download=[int64](Get-Prop $State 'TotalBytes' 0)
    [int64]$install=[int64](Get-Prop $State 'InstallSizeBytes' 0)
    $game=Get-CatalogGame ([string](Get-Prop $State 'Provider' '')) ([string](Get-Prop $State 'GameId' ''))
    if($null -ne $game){
        if($download -le 0){foreach($name in @('DownloadSizeBytes','TotalBytes')){$candidate=[int64](Get-Prop $game $name 0);if($candidate -gt 0){$download=$candidate;break}}}
        if($install -le 0){foreach($name in @('InstallSizeBytes','InstalledSizeBytes')){$candidate=[int64](Get-Prop $game $name 0);if($candidate -gt 0){$install=$candidate;break}}}
    }
    return [pscustomobject]@{Download=[int64]$download;Install=[int64]$install}
}
function Quote-Arg {param([string]$Value);if($null -eq $Value){return '""'};return '"'+$Value.Replace('"','')+'"'}
function Start-ProgressMonitor {
    param($State)
    if(-not(Test-Path -LiteralPath $progressWorkerPath -PathType Leaf)){return}
    $provider=[string](Get-Prop $State 'Provider' '')
    $mode=[string](Get-Prop $State 'Mode' '')
    $gameId=[string](Get-Prop $State 'GameId' '')
    $gameName=[string](Get-Prop $State 'GameName' '')
    $workerPid=[int](Get-Prop $State 'WorkerPid' 0)
    if($workerPid -le 0){return}
    $watch=Get-WatchPath $provider $mode $gameId $gameName
    $sizes=Get-ExpectedSizes $State
    Remove-Item -LiteralPath $progressPath -Force -ErrorAction SilentlyContinue
    $powershell="$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
    $args=@(
        '-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',(Quote-Arg $progressWorkerPath),
        '-Provider',$provider,'-StatePath',(Quote-Arg $statePath),'-ProgressPath',(Quote-Arg $progressPath),
        '-WatchPath',(Quote-Arg $watch),'-WorkerPid',[string]$workerPid,'-TelemetryHelperPath',(Quote-Arg $telemetryHelperPath),
        '-ExpectedDownloadBytes',[string]$sizes.Download,'-ExpectedInstallBytes',[string]$sizes.Install
    )
    try{
        $p=Start-Process -FilePath $powershell -ArgumentList $args -WindowStyle Hidden -PassThru
        try{$p.PriorityClass='BelowNormal'}catch{}
        $script:progressProcess=$p
    }catch{$script:progressProcess=$null}
}
function Merge-ProgressState {
    $progress=Read-Json $progressPath
    if($null -eq $progress -or -not [bool](Get-Prop $progress 'Busy' $false)){return}
    $state=Read-Json $statePath
    if($null -eq $state -or -not [bool](Get-Prop $state 'Busy' $false)){return}
    $provider=[string](Get-Prop $state 'Provider' '')
    $mode=[string](Get-Prop $state 'Mode' '')
    $phase=[string](Get-Prop $state 'Phase' '')
    $workerPid=[int](Get-Prop $state 'WorkerPid' 0)
    if($provider -notin @('Epic','GOG','Amazon') -or $mode -notin @('Install','Update')){return}
    if($phase -notin @('Install','Update','Downloading','Installing')){return}
    if($workerPid -le 0 -or $workerPid -ne [int](Get-Prop $progress 'WorkerPid' 0)){return}
    if(-not [string]::Equals([string](Get-Prop $progress 'Provider' ''),$provider,[StringComparison]::OrdinalIgnoreCase)){return}
    if(-not [string]::Equals([string](Get-Prop $progress 'GameId' ''),[string](Get-Prop $state 'GameId' ''),[StringComparison]::OrdinalIgnoreCase)){return}
    try{if(([DateTime]::UtcNow-[DateTime]::Parse([string](Get-Prop $progress 'Updated' ''))).TotalSeconds -gt 4){return}}catch{return}

    $expectedUpdated=[string](Get-Prop $state 'Updated' '')
    $expectedPhase=$phase
    $fallbackPhase=[string](Get-Prop $progress 'Phase' 'Downloading')
    if($phase -in @('Install','Update')){Set-Prop $state 'Phase' $fallbackPhase}
    Set-Prop $state 'Message' ([string](Get-Prop $progress 'Message' ("$fallbackPhase $([string](Get-Prop $state 'GameName' 'game'))")))
    $fallbackProgress=[int](Get-Prop $progress 'Progress' -1)
    if($fallbackProgress -ge 0 -and [int](Get-Prop $state 'Progress' -1) -le 5){Set-Prop $state 'Progress' $fallbackProgress}

    [int64]$current=[int64](Get-Prop $progress 'CurrentBytes' 0)
    [int64]$total=[int64](Get-Prop $progress 'TotalBytes' 0)
    [int64]$installTotal=[int64](Get-Prop $progress 'InstallSizeBytes' 0)
    [double]$speed=[double](Get-Prop $progress 'SpeedBytesPerSec' 0)
    [int64]$eta=[int64](Get-Prop $progress 'EtaSeconds' -1)
    if([int64](Get-Prop $state 'DownloadedBytes' 0) -le 0 -and $fallbackPhase -eq 'Downloading'){Set-Prop $state 'DownloadedBytes' $current}
    if([int64](Get-Prop $state 'TotalBytes' 0) -le 0 -and $total -gt 0){Set-Prop $state 'TotalBytes' $total}
    if([int64](Get-Prop $state 'InstallSizeBytes' 0) -le 0 -and $installTotal -gt 0){Set-Prop $state 'InstallSizeBytes' $installTotal}
    if($fallbackPhase -eq 'Installing'){Set-Prop $state 'InstallProcessedBytes' $current}
    if([double](Get-Prop $state 'DownloadSpeedBytesPerSec' 0) -le 0 -and $speed -gt 0){Set-Prop $state 'DownloadSpeedBytesPerSec' $speed}
    Set-Prop $state 'TransferSpeedBytesPerSec' $speed
    if($fallbackPhase -eq 'Installing'){Set-Prop $state 'InstallSpeedBytesPerSec' $speed}
    if([int64](Get-Prop $state 'EtaSeconds' -1) -lt 0 -and $eta -ge 0){Set-Prop $state 'EtaSeconds' $eta}
    Set-Prop $state 'TelemetryUpdated' ([string](Get-Prop $progress 'Updated' ''))
    Set-Prop $state 'TelemetrySource' ([string](Get-Prop $progress 'TelemetryKind' 'Fallback monitor'))
    [void](Write-AtomicState $state $expectedUpdated $expectedPhase $workerPid)
}

try{
    New-Item -ItemType Directory -Force -Path $providerRoot|Out-Null
    while(Test-ProcessAlive $ParentPid){
        $state=Read-Json $statePath
        $active=$false
        if($null -ne $state -and [bool](Get-Prop $state 'Busy' $false)){
            $provider=[string](Get-Prop $state 'Provider' '')
            $mode=[string](Get-Prop $state 'Mode' '')
            $phase=[string](Get-Prop $state 'Phase' '')
            $workerPid=[int](Get-Prop $state 'WorkerPid' 0)
            if($provider -in @('Epic','GOG','Amazon') -and $mode -in @('Install','Update') -and $phase -in @('Install','Update','Downloading','Installing') -and (Test-ProcessAlive $workerPid)){
                $active=$true
                $key="$provider|$mode|$([string](Get-Prop $state 'GameId' ''))|$workerPid"
                if($key -ne $operationKey){Stop-ProgressProcess;$operationKey=$key;Start-ProgressMonitor $state}
                Merge-ProgressState
            }
        }
        if(-not $active -and $operationKey){Stop-ProgressProcess;$operationKey='';Remove-Item -LiteralPath $progressPath -Force -ErrorAction SilentlyContinue}
        Start-Sleep -Milliseconds 650
    }
}finally{
    Stop-ProgressProcess
    Remove-Item -LiteralPath $progressPath -Force -ErrorAction SilentlyContinue
}
