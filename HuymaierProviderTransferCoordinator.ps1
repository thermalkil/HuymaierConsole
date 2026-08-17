param(
    [Parameter(Mandatory=$true)][int]$ParentPid,
    [Parameter(Mandatory=$true)][string]$BaseDir,
    [Parameter(Mandatory=$true)][string]$DataDir
)

Set-StrictMode -Version 2.0
$ErrorActionPreference='SilentlyContinue'

$providerRoot=Join-Path $DataDir 'GameProviders'
$transferRoot=Join-Path $providerRoot 'Transfers'
$aggregatePath=Join-Path $providerRoot 'provider-transfers.json'
$legacyStatePath=Join-Path $providerRoot 'provider-state.json'
$catalogPath=Join-Path $providerRoot 'provider-catalog.json'
$managedPath=Join-Path $providerRoot 'managed-installs.json'
$configPath=Join-Path $DataDir 'config.json'
$progressWorkerPath=Join-Path $BaseDir 'HuymaierProviderProgressWorker.ps1'
$telemetryHelperPath=Join-Path $BaseDir 'HuymaierProviderTelemetry.ps1'
$script:Monitors=@{}
$script:LastAggregateSignature=''
$script:LastLegacySignature=''

if(Test-Path -LiteralPath $telemetryHelperPath -PathType Leaf){try{. $telemetryHelperPath}catch{}}
New-Item -ItemType Directory -Force -Path $providerRoot,$transferRoot|Out-Null

function Get-Prop {
    param($Object,[string]$Name,$Default=$null)
    if($null -eq $Object){return $Default}
    try{
        $property=$Object.PSObject.Properties[$Name]
        if($null -ne $property -and $null -ne $property.Value){return $property.Value}
    }catch{}
    return $Default
}

function Set-Prop {
    param($Object,[string]$Name,$Value)
    try{
        $property=$Object.PSObject.Properties[$Name]
        if($null -eq $property){$Object|Add-Member -NotePropertyName $Name -NotePropertyValue $Value -Force}
        else{$Object.$Name=$Value}
    }catch{}
}

function Read-Json {
    param([string]$Path)
    if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){return $null}
    try{return Get-Content -Raw -LiteralPath $Path -Encoding UTF8|ConvertFrom-Json}catch{return $null}
}

function Write-AtomicJson {
    param([string]$Path,$Value)
    try{
        $parent=Split-Path -Parent $Path
        if($parent){New-Item -ItemType Directory -Force -Path $parent|Out-Null}
        $tmp=$Path+'.'+$PID+'.tmp'
        $Value|ConvertTo-Json -Depth 20|Set-Content -LiteralPath $tmp -Encoding UTF8
        Move-Item -LiteralPath $tmp -Destination $Path -Force
    }catch{}
}

function Test-ProcessAlive {
    param([int]$ProcessId)
    if($ProcessId -le 0){return $false}
    try{
        $process=Get-Process -Id $ProcessId -ErrorAction Stop
        return (-not $process.HasExited)
    }catch{return $false}
}

function Quote-Arg {
    param([string]$Value)
    if($null -eq $Value){return '""'}
    return '"'+$Value.Replace('"','')+'"'
}

function Get-TransferId {
    param([string]$Path,$State)
    $id=[string](Get-Prop $State 'TransferId' '')
    if($id){return $id}
    $leaf=[IO.Path]::GetFileNameWithoutExtension($Path)
    if($leaf -match '^transfer-(.+)$'){return [string]$matches[1]}
    return $leaf
}

function Convert-SizeTextBytes {
    param([string]$Text)
    if([string]::IsNullOrWhiteSpace($Text)){return [int64]0}
    $match=[regex]::Match($Text,'(?i)([0-9]+(?:\.[0-9]+)?)\s*(B|KB|KiB|MB|MiB|GB|GiB|TB|TiB)')
    if(-not $match.Success){return [int64]0}
    try{
        $value=[double]::Parse($match.Groups[1].Value,[Globalization.CultureInfo]::InvariantCulture)
        $unit=$match.Groups[2].Value
        if(Get-Command Convert-HcTelemetrySizeToBytes -ErrorAction SilentlyContinue){return [int64](Convert-HcTelemetrySizeToBytes $value $unit)}
        switch($unit.ToUpperInvariant()){
            'TB' {return [int64]($value*1TB)}
            'TIB' {return [int64]($value*1TB)}
            'GB' {return [int64]($value*1GB)}
            'GIB' {return [int64]($value*1GB)}
            'MB' {return [int64]($value*1MB)}
            'MIB' {return [int64]($value*1MB)}
            'KB' {return [int64]($value*1KB)}
            'KIB' {return [int64]($value*1KB)}
            default {return [int64]$value}
        }
    }catch{return [int64]0}
}

function Get-CatalogGame {
    param([string]$Provider,[string]$GameId)
    $catalog=Read-Json $catalogPath
    foreach($node in @(Get-Prop $catalog 'Providers' @())){
        if(-not [string]::Equals([string](Get-Prop $node 'Id' ''),$Provider,[StringComparison]::OrdinalIgnoreCase)){continue}
        foreach($game in @(Get-Prop $node 'Games' @())){
            if([string]::Equals([string](Get-Prop $game 'Id' ''),$GameId,[StringComparison]::OrdinalIgnoreCase)){return $game}
        }
    }
    return $null
}

function Get-ExpectedSizes {
    param($State)
    [int64]$download=[int64](Get-Prop $State 'TotalBytes' 0)
    [int64]$install=[int64](Get-Prop $State 'InstallSizeBytes' 0)
    $estimated=$false
    $provider=[string](Get-Prop $State 'Provider' '')
    $gameId=[string](Get-Prop $State 'GameId' '')
    $game=Get-CatalogGame $provider $gameId
    if($null -ne $game){
        if($download -le 0){
            foreach($name in @('DownloadSizeBytes','TotalBytes')){
                $candidate=[int64](Get-Prop $game $name 0)
                if($candidate -gt 0){$download=$candidate;break}
            }
        }
        if($install -le 0){
            foreach($name in @('InstallSizeBytes','InstalledSizeBytes','SizeBytes')){
                $candidate=[int64](Get-Prop $game $name 0)
                if($candidate -gt 0){$install=$candidate;break}
            }
        }
        if($install -le 0){$install=Convert-SizeTextBytes ([string](Get-Prop $game 'SizeText' ''))}
    }
    if($download -le 0 -and $install -gt 0){$download=$install;$estimated=$true}
    if($install -le 0 -and $download -gt 0){$install=$download;$estimated=$true}
    return [pscustomobject]@{Download=[int64]$download;Install=[int64]$install;Estimated=[bool]$estimated}
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
    return (Join-Path 'C:\Games' $Provider)
}

function Get-ManagedInstallPath {
    param([string]$Provider,[string]$GameId)
    foreach($item in @(Read-Json $managedPath)){
        $sameProvider=[string]::Equals([string](Get-Prop $item 'Provider' ''),$Provider,[StringComparison]::OrdinalIgnoreCase)
        $sameGame=[string]::Equals([string](Get-Prop $item 'Id' ''),$GameId,[StringComparison]::OrdinalIgnoreCase)
        if($sameProvider -and $sameGame){return [string](Get-Prop $item 'Path' '')}
    }
    return ''
}

function Get-WatchPath {
    param($State)
    $explicit=[string](Get-Prop $State 'InstallPath' '')
    if($explicit){return $explicit}
    $provider=[string](Get-Prop $State 'Provider' '')
    $gameId=[string](Get-Prop $State 'GameId' '')
    $mode=[string](Get-Prop $State 'Mode' '')
    $managed=Get-ManagedInstallPath $provider $gameId
    if($mode -eq 'Update' -and $managed){return $managed}
    return Get-ConfiguredInstallRoot $provider
}

function Stop-TransferMonitor {
    param([string]$Id)
    if(-not $script:Monitors.ContainsKey($Id)){return}
    $entry=$script:Monitors[$Id]
    try{
        if($entry.Process){
            $entry.Process.Refresh()
            if(-not $entry.Process.HasExited){Stop-Process -Id $entry.Process.Id -Force -ErrorAction SilentlyContinue}
        }
    }catch{}
    try{Remove-Item -LiteralPath ([string]$entry.ProgressPath) -Force -ErrorAction SilentlyContinue}catch{}
    [void]$script:Monitors.Remove($Id)
}

function Start-TransferMonitor {
    param([string]$Id,[string]$StatePath,$State)
    if($script:Monitors.ContainsKey($Id)){return}
    if(-not(Test-Path -LiteralPath $progressWorkerPath -PathType Leaf)){return}
    $workerPid=[int](Get-Prop $State 'WorkerPid' 0)
    if($workerPid -le 0 -or -not(Test-ProcessAlive $workerPid)){return}
    $provider=[string](Get-Prop $State 'Provider' '')
    if($provider -notin @('Epic','GOG','Amazon')){return}
    $sizes=Get-ExpectedSizes $State
    $progressPath=Join-Path $transferRoot ('progress-'+$Id+'.json')
    Remove-Item -LiteralPath $progressPath -Force -ErrorAction SilentlyContinue
    $powershell=$env:SystemRoot+'\System32\WindowsPowerShell\v1.0\powershell.exe'
    $watchPath=Get-WatchPath $State
    $args=@(
        '-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',(Quote-Arg $progressWorkerPath),
        '-Provider',$provider,'-TransferId',$Id,
        '-StatePath',(Quote-Arg $StatePath),'-ProgressPath',(Quote-Arg $progressPath),'-WatchPath',(Quote-Arg $watchPath),
        '-WorkerPid',[string]$workerPid,'-TelemetryHelperPath',(Quote-Arg $telemetryHelperPath),
        '-ExpectedDownloadBytes',[string]$sizes.Download,'-ExpectedInstallBytes',[string]$sizes.Install
    )
    try{
        $process=Start-Process -FilePath $powershell -ArgumentList $args -WindowStyle Hidden -PassThru
        try{$process.PriorityClass='BelowNormal'}catch{}
        $script:Monitors[$Id]=[pscustomobject]@{
            Process=$process
            ProgressPath=$progressPath
            StatePath=$StatePath
            WorkerPid=$workerPid
            Estimated=[bool]$sizes.Estimated
        }
    }catch{}
}

function Merge-TransferProgress {
    param([string]$Id,[string]$StatePath,$State)
    if(-not $script:Monitors.ContainsKey($Id)){return $State}
    $entry=$script:Monitors[$Id]
    $progress=Read-Json ([string]$entry.ProgressPath)
    if($null -eq $progress){return $State}
    if(-not [bool](Get-Prop $progress 'Busy' $false)){return $State}

    $expectedPid=[int](Get-Prop $State 'WorkerPid' 0)
    $expectedUpdated=[string](Get-Prop $State 'Updated' '')
    if([int](Get-Prop $progress 'WorkerPid' 0) -ne $expectedPid){return $State}
    try{
        $progressUpdated=[DateTime]::Parse([string](Get-Prop $progress 'Updated' ''))
        if(([DateTime]::UtcNow-$progressUpdated.ToUniversalTime()).TotalSeconds -gt 4){return $State}
    }catch{return $State}

    $phase=[string](Get-Prop $progress 'Phase' '')
    if(-not $phase){$phase=[string](Get-Prop $State 'Phase' 'Downloading')}
    if($phase -in @('Downloading','Installing')){Set-Prop $State 'Phase' $phase}

    [int64]$current=[int64](Get-Prop $progress 'CurrentBytes' 0)
    [int64]$downloadTotal=[int64](Get-Prop $progress 'TotalBytes' 0)
    [int64]$installTotal=[int64](Get-Prop $progress 'InstallSizeBytes' 0)
    [double]$rate=[double](Get-Prop $progress 'SpeedBytesPerSec' 0)
    [int64]$eta=[int64](Get-Prop $progress 'EtaSeconds' -1)
    [int]$percent=[int](Get-Prop $progress 'Progress' -1)

    if($phase -eq 'Installing'){
        Set-Prop $State 'InstallProcessedBytes' $current
        if($rate -gt 0){Set-Prop $State 'InstallSpeedBytesPerSec' $rate}
    }elseif($current -gt 0){
        Set-Prop $State 'DownloadedBytes' $current
    }
    if($downloadTotal -gt 0){Set-Prop $State 'TotalBytes' $downloadTotal}
    if($installTotal -gt 0){Set-Prop $State 'InstallSizeBytes' $installTotal}
    if($rate -gt 0){
        Set-Prop $State 'TransferSpeedBytesPerSec' $rate
        if($phase -eq 'Downloading'){Set-Prop $State 'DownloadSpeedBytesPerSec' $rate}
    }
    if($eta -ge 0){Set-Prop $State 'EtaSeconds' $eta}
    if($percent -ge 0){Set-Prop $State 'Progress' $percent}
    Set-Prop $State 'TelemetryUpdated' ([string](Get-Prop $progress 'Updated' ''))

    $telemetrySource=[string](Get-Prop $progress 'TelemetryKind' 'Observed throughput')
    if([bool]$entry.Estimated){$telemetrySource='Estimated total size + observed throughput'}
    Set-Prop $State 'TelemetrySource' $telemetrySource
    Set-Prop $State 'EtaEstimated' ([bool]$entry.Estimated)
    $message=[string](Get-Prop $progress 'Message' '')
    if($message){Set-Prop $State 'Message' $message}

    # Provider-native state always wins. Only persist fallback telemetry when the
    # worker PID and Updated token are still exactly the snapshot we measured.
    $latest=Read-Json $StatePath
    if($null -eq $latest){return $State}
    if(-not [bool](Get-Prop $latest 'Busy' $false)){return $latest}
    if([int](Get-Prop $latest 'WorkerPid' 0) -ne $expectedPid){return $latest}
    if(-not [string]::Equals([string](Get-Prop $latest 'Updated' ''),$expectedUpdated,[StringComparison]::Ordinal)){return $latest}
    Write-AtomicJson $StatePath $State
    return $State
}

function Read-TransferStates {
    $items=New-Object System.Collections.ArrayList
    foreach($file in @(Get-ChildItem -LiteralPath $transferRoot -Filter 'transfer-*.json' -File -ErrorAction SilentlyContinue)){
        $state=Read-Json $file.FullName
        if($null -eq $state){continue}
        $id=Get-TransferId $file.FullName $state
        Set-Prop $state 'TransferId' $id
        Set-Prop $state 'StatePath' $file.FullName
        $busy=[bool](Get-Prop $state 'Busy' $false)
        $workerPid=[int](Get-Prop $state 'WorkerPid' 0)
        $mode=[string](Get-Prop $state 'Mode' '')
        if($busy -and $workerPid -gt 0 -and -not(Test-ProcessAlive $workerPid)){
            Set-Prop $state 'Busy' $false
            Set-Prop $state 'Phase' 'Failed'
            Set-Prop $state 'Error' 'Provider worker ended unexpectedly.'
            Set-Prop $state 'Updated' ([DateTime]::UtcNow.ToString('o'))
            Write-AtomicJson $file.FullName $state
            $busy=$false
        }
        if($busy -and $mode -in @('Install','Update')){
            Start-TransferMonitor $id $file.FullName $state
            $state=Merge-TransferProgress $id $file.FullName $state
        }else{
            Stop-TransferMonitor $id
        }
        [void]$items.Add($state)
    }
    return [object[]]$items.ToArray()
}

function Prune-TransferStates {
    param([object[]]$States)
    $cutoff=[DateTime]::UtcNow.AddDays(-7)
    $completed=@($States|Where-Object{-not [bool](Get-Prop $_ 'Busy' $false)}|Sort-Object {try{[datetime]::Parse([string](Get-Prop $_ 'Updated' ''))}catch{[datetime]::MinValue}} -Descending)
    $keep=@{}
    $index=0
    foreach($state in $completed){
        $index++
        $updated=[datetime]::MinValue
        try{$updated=[datetime]::Parse([string](Get-Prop $state 'Updated' ''))}catch{}
        $id=[string](Get-Prop $state 'TransferId' '')
        if($updated -ge $cutoff -and $index -le 100){$keep[$id]=$true}
    }
    foreach($state in $completed){
        $id=[string](Get-Prop $state 'TransferId' '')
        if($id -and -not $keep.ContainsKey($id)){
            try{Remove-Item -LiteralPath ([string](Get-Prop $state 'StatePath' '')) -Force -ErrorAction SilentlyContinue}catch{}
        }
    }
}

function Publish-TransferAggregate {
    param([object[]]$States)
    $ordered=@($States|Sort-Object @{Expression={[bool](Get-Prop $_ 'Busy' $false)};Descending=$true},@{Expression={try{[datetime]::Parse([string](Get-Prop $_ 'Updated' ''))}catch{[datetime]::MinValue}};Descending=$true})
    $signature=ConvertTo-Json -InputObject ([object[]]$ordered) -Depth 16 -Compress
    if($signature -ne $script:LastAggregateSignature){
        $script:LastAggregateSignature=$signature
        Write-AtomicJson $aggregatePath ([pscustomobject]@{Transfers=[object[]]$ordered;Updated=[DateTime]::UtcNow.ToString('o')})
    }

    $active=@($ordered|Where-Object{[bool](Get-Prop $_ 'Busy' $false)})
    if($active.Count -gt 1){
        $latest=$active[0]
        $legacyUpdated=[string](Get-Prop $latest 'TelemetryUpdated' '')
        if(-not $legacyUpdated){$legacyUpdated=[string](Get-Prop $latest 'Updated' '')}
        if(-not $legacyUpdated){$legacyUpdated=[DateTime]::UtcNow.ToString('o')}
        $legacy=[pscustomobject]@{
            Busy=$true
            Provider='Multiple'
            Mode='Install'
            Phase='Downloading'
            Message=([string]$active.Count+' provider downloads/installations are active.')
            Progress=-1
            Error=''
            GameId=''
            GameName=([string]$active.Count+' active downloads')
            WorkerPid=0
            StartedAt=[string](Get-Prop $latest 'StartedAt' '')
            Updated=$legacyUpdated
            ActiveTransferCount=$active.Count
        }
    }elseif($active.Count -eq 1){
        $legacy=$active[0]
    }elseif($ordered.Count -gt 0){
        $legacy=$ordered[0]
    }else{
        $legacy=[pscustomobject]@{
            Busy=$false;Provider='';Mode='';Phase='Ready';Message='Direct game providers are ready.';Progress=-1;Error='';
            GameId='';GameName='';WorkerPid=0;Updated=[DateTime]::UtcNow.ToString('o');ActiveTransferCount=0
        }
    }
    $legacySignature=ConvertTo-Json -InputObject $legacy -Depth 16 -Compress
    if($legacySignature -ne $script:LastLegacySignature){
        $script:LastLegacySignature=$legacySignature
        Write-AtomicJson $legacyStatePath $legacy
    }
}

try{
    while(Test-ProcessAlive $ParentPid){
        $states=@(Read-TransferStates)
        Prune-TransferStates $states
        Publish-TransferAggregate $states
        Start-Sleep -Milliseconds 650
    }
}finally{
    foreach($id in @($script:Monitors.Keys)){Stop-TransferMonitor ([string]$id)}
}
