# Concurrent provider transfer layer for Huymaier Console.
# Loaded after HuymaierGameProviders.ps1 so Install/Update can be overridden
# without changing setup/auth/refresh/move/uninstall behavior.

Set-StrictMode -Version 2.0

$script:HcBaseStartGameProviderWorker=${function:Start-GameProviderWorker}
$script:HcBaseStopGameProviderWorker=${function:Stop-GameProviderWorker}
$script:HcBaseReadGameProviderState=${function:Read-GameProviderState}
$script:HcBaseGetProviderDownloadPageActions=${function:Get-ProviderDownloadPageActions}
$script:ProviderTransferRoot=Join-Path $script:ProviderRoot 'Transfers'
$script:ProviderTransferAggregatePath=Join-Path $script:ProviderRoot 'provider-transfers.json'
$script:ProviderTransferCoordinatorPath=Join-Path $script:BaseDir 'HuymaierProviderTransferCoordinator.ps1'
$script:ProviderTransferCoordinatorProcess=$null
$script:ProviderWorkerProcesses=@{}
New-Item -ItemType Directory -Force -Path $script:ProviderTransferRoot|Out-Null

function Read-HcProviderJson {
    param([string]$Path)
    if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){return $null}
    try{return Get-Content -Raw -LiteralPath $Path -Encoding UTF8|ConvertFrom-Json}catch{return $null}
}
function Write-HcProviderJson {
    param([string]$Path,$Value)
    try{$tmp="$Path.ui.$PID.tmp";$Value|ConvertTo-Json -Depth 20|Set-Content -LiteralPath $tmp -Encoding UTF8;Move-Item -LiteralPath $tmp -Destination $Path -Force}catch{}
}
function Test-HcProviderPidAlive {
    param([int]$ProcessId)
    if($ProcessId -le 0){return $false}
    try{$p=Get-Process -Id $ProcessId -ErrorAction Stop;return -not $p.HasExited}catch{return $false}
}
function Get-GameProviderTransfers {
    $aggregate=Read-HcProviderJson $script:ProviderTransferAggregatePath
    $items=New-Object System.Collections.ArrayList
    if($null -ne $aggregate){
        foreach($state in @(Get-EntryProperty $aggregate 'Transfers' @())){if($null -ne $state){[void]$items.Add($state)}}
    }elseif(Test-Path -LiteralPath $script:ProviderTransferRoot -PathType Container){
        foreach($file in @(Get-ChildItem -LiteralPath $script:ProviderTransferRoot -Filter 'transfer-*.json' -File -ErrorAction SilentlyContinue)){
            $state=Read-HcProviderJson $file.FullName
            if($null -ne $state){
                if($null -eq $state.PSObject.Properties['StatePath']){$state|Add-Member -NotePropertyName StatePath -NotePropertyValue $file.FullName -Force}
                [void]$items.Add($state)
            }
        }
    }
    return [object[]]@($items.ToArray()|Sort-Object {try{[datetime]::Parse([string](Get-EntryProperty $_ 'Updated' ''))}catch{[datetime]::MinValue}} -Descending)
}
function Get-GameProviderActiveTransfers {
    $active=New-Object System.Collections.ArrayList
    foreach($state in @(Get-GameProviderTransfers)){
        if(-not [bool](Get-EntryProperty $state 'Busy' $false)){continue}
        $pidValue=[int](Get-EntryProperty $state 'WorkerPid' 0)
        if($pidValue -gt 0 -and -not(Test-HcProviderPidAlive $pidValue)){continue}
        [void]$active.Add($state)
    }
    return [object[]]$active.ToArray()
}
function Read-GameProviderState {
    $active=@(Get-GameProviderActiveTransfers)
    if($active.Count -gt 1){
        $latest=$active[0]
        $latestUpdated=[string](Get-EntryProperty $latest 'TelemetryUpdated' (Get-EntryProperty $latest 'Updated' ''))
        $script:ProviderState=[pscustomobject]@{
            Busy=$true;Provider='Multiple';Mode='Install';Phase='Downloading';
            Message=("{0} downloads/installations are active." -f $active.Count);Progress=-1;Error='';GameId='';
            GameName=("{0} active downloads" -f $active.Count);WorkerPid=0;
            StartedAt=[string](Get-EntryProperty $latest 'StartedAt' '');Updated=$latestUpdated;ActiveTransferCount=$active.Count
        }
        return $script:ProviderState
    }
    if($active.Count -eq 1){$script:ProviderState=$active[0];return $script:ProviderState}
    $transfers=@(Get-GameProviderTransfers)
    if($transfers.Count -gt 0){$script:ProviderState=$transfers[0];return $script:ProviderState}
    return (& $script:HcBaseReadGameProviderState)
}

function Start-HcProviderTransferCoordinator {
    if(-not(Test-Path -LiteralPath $script:ProviderTransferCoordinatorPath -PathType Leaf)){return $false}
    try{
        if($null -ne $script:ProviderTransferCoordinatorProcess){
            $script:ProviderTransferCoordinatorProcess.Refresh()
            if(-not $script:ProviderTransferCoordinatorProcess.HasExited){return $true}
        }
    }catch{}
    try{
        $powershell="$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
        $quote={param([string]$v);'"'+([string]$v).Replace('"','')+'"'}
        $args=@('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',(& $quote $script:ProviderTransferCoordinatorPath),'-ParentPid',[string]$PID,'-BaseDir',(& $quote $script:BaseDir),'-DataDir',(& $quote $script:DataDir))
        $process=Start-Process -FilePath $powershell -ArgumentList $args -WindowStyle Hidden -PassThru
        try{$process.PriorityClass='BelowNormal'}catch{}
        $script:ProviderTransferCoordinatorProcess=$process
        Write-Log 'Concurrent provider transfer coordinator started.'
        return $true
    }catch{
        Write-Log "Provider transfer coordinator could not start: $($_.Exception.Message)" 'WARN'
        return $false
    }
}
function Get-HcProviderTransferWorkerArguments {
    param([string]$Mode,[string]$Provider,[string]$GameId,[string]$GameName,[string]$InstallPath,[string]$StatePath)
    $args=@(
        '-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',('"'+$script:ProviderWorkerPath+'"'),
        '-Mode',$Mode,'-Provider',$Provider,'-DataDir',('"'+$script:DataDir+'"'),'-StatePath',('"'+$StatePath+'"'),
        '-CatalogPath',('"'+$script:ProviderCatalogPath+'"'),'-ToolRoot',('"'+$script:ProviderToolRoot+'"'),'-ArtworkRoot',('"'+$script:ProviderArtworkRoot+'"')
    )
    if($GameId){$args+=@('-GameId',('"'+$GameId.Replace('"','')+'"'))}
    if($GameName){$args+=@('-GameName',('"'+$GameName.Replace('"','')+'"'))}
    if($InstallPath){$args+=@('-InstallPath',('"'+$InstallPath.Replace('"','')+'"'))}
    return $args
}
function Write-HcProviderTransferLaunchState {
    param([string]$StatePath,[string]$TransferId,[bool]$Busy,[string]$Mode,[string]$Provider,[string]$GameId,[string]$GameName,[string]$InstallPath,[string]$Message,[int]$WorkerPid=0,[string]$Error='')
    $state=[pscustomobject]@{
        TransferId=$TransferId;StatePath=$StatePath;Busy=$Busy;Provider=$Provider;Mode=$Mode;
        Phase=$(if($Busy){'Starting'}else{'Failed'});Message=$Message;Progress=$(if($Busy){0}else{-1});Error=$Error;
        GameId=$GameId;GameName=$GameName;InstallPath=$InstallPath;WorkerPid=$WorkerPid;
        StartedAt=(Get-Date).ToString('o');Updated=(Get-Date).ToString('o');DownloadedBytes=[int64]0;TotalBytes=[int64]0;
        InstallSizeBytes=[int64]0;DownloadSpeedBytesPerSec=[double]0;TransferSpeedBytesPerSec=[double]0;EtaSeconds=[int64]-1;EtaEstimated=$false
    }
    Write-HcProviderJson $StatePath $state
    return $state
}
function Test-HcDuplicateProviderTransfer {
    param([string]$Provider,[string]$GameId)
    foreach($state in @(Get-GameProviderActiveTransfers)){
        if([string]::Equals([string](Get-EntryProperty $state 'Provider' ''),$Provider,[StringComparison]::OrdinalIgnoreCase) -and
           [string]::Equals([string](Get-EntryProperty $state 'GameId' ''),$GameId,[StringComparison]::OrdinalIgnoreCase)){return $true}
    }
    return $false
}

function Start-GameProviderWorker {
    param([string]$Mode,[string]$Provider,[string]$GameId='',[string]$GameName='',[string]$InstallPath='',[string]$AuthCode='')
    if($Mode -notin @('Install','Update')){
        & $script:HcBaseStartGameProviderWorker $Mode $Provider $GameId $GameName $InstallPath $AuthCode
        return
    }
    if(-not(Test-Path -LiteralPath $script:ProviderWorkerPath -PathType Leaf)){Set-ConsoleNotice 'The direct-provider worker is missing.' 'ERROR';return}
    if(Test-HcDuplicateProviderTransfer $Provider $GameId){Set-ConsoleNotice "$GameName already has an active $Provider transfer." 'WARN';return}
    if(-not $InstallPath){$InstallPath=Get-ProviderInstallRoot $Provider}
    if(-not(Start-HcProviderTransferCoordinator)){Set-ConsoleNotice 'The provider transfer coordinator could not start.' 'ERROR';return}

    $transferId=[guid]::NewGuid().ToString('N')
    $statePath=Join-Path $script:ProviderTransferRoot ("transfer-$transferId.json")
    [void](Write-HcProviderTransferLaunchState $statePath $transferId $true $Mode $Provider $GameId $GameName $InstallPath "Starting $Provider $Mode..." 0 '')
    try{
        $powershell="$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
        $process=Start-Process -FilePath $powershell -ArgumentList (Get-HcProviderTransferWorkerArguments $Mode $Provider $GameId $GameName $InstallPath $statePath) -WindowStyle Hidden -PassThru
        $script:ProviderWorkerProcesses[$transferId]=$process
        # Do not rewrite the transfer state after process launch: the worker owns
        # this file from here onward. Avoiding a second UI write prevents a race
        # where an early Downloading state could be replaced by Starting again.
        Write-Log "Concurrent provider worker started: $Provider / $Mode / $GameName / $transferId / PID $($process.Id)"
        Set-ConsoleNotice "${Provider}: $GameName added to active downloads." 'INFO'
    }catch{
        [void](Write-HcProviderTransferLaunchState $statePath $transferId $false $Mode $Provider $GameId $GameName $InstallPath "Unable to start $Provider $Mode." 0 $_.Exception.Message)
        Set-ConsoleNotice "Unable to start $Provider provider task: $($_.Exception.Message)" 'ERROR'
    }
}

function Stop-GameProviderWorker {
    $active=@(Get-GameProviderActiveTransfers)
    foreach($state in $active){
        $transferId=[string](Get-EntryProperty $state 'TransferId' '')
        $workerPid=[int](Get-EntryProperty $state 'WorkerPid' 0)
        if($workerPid -gt 0){
            Stop-Process -Id $workerPid -Force -ErrorAction SilentlyContinue
        }elseif($transferId -and $script:ProviderWorkerProcesses.ContainsKey($transferId)){
            try{$process=$script:ProviderWorkerProcesses[$transferId];if($null -ne $process -and -not $process.HasExited){$process.Kill()}}catch{}
        }
        $path=[string](Get-EntryProperty $state 'StatePath' '')
        if(-not $path -and $transferId){$path=Join-Path $script:ProviderTransferRoot ("transfer-$transferId.json")}
        if($path){
            $cancel=[pscustomobject]@{
                TransferId=$transferId;StatePath=$path;Busy=$false;Provider=[string](Get-EntryProperty $state 'Provider' '');
                Mode=[string](Get-EntryProperty $state 'Mode' '');Phase='Cancelled';
                Message='Provider operation cancelled. Partial files may be retained for resume.';Progress=-1;Error='Cancelled by user';
                GameId=[string](Get-EntryProperty $state 'GameId' '');GameName=[string](Get-EntryProperty $state 'GameName' '');
                InstallPath=[string](Get-EntryProperty $state 'InstallPath' '');WorkerPid=0;StartedAt=[string](Get-EntryProperty $state 'StartedAt' '');Updated=(Get-Date).ToString('o')
            }
            Write-HcProviderJson $path $cancel
        }
    }
    if($active.Count -gt 0){
        $notice=if($active.Count -eq 1){'Provider download cancelled. Partial data may be retained for resume.'}else{"$($active.Count) provider downloads cancelled. Partial data may be retained for resume."}
        Set-ConsoleNotice $notice 'WARN'
        return
    }
    & $script:HcBaseStopGameProviderWorker
}

function Get-HcProviderTransferEtaText {
    param($State)
    $eta=[int64](Get-EntryProperty $State 'EtaSeconds' -1)
    $phase=[string](Get-EntryProperty $State 'Phase' 'Downloading')
    if($eta -lt 0){
        $installing=[string]::Equals($phase,'Installing',[StringComparison]::OrdinalIgnoreCase)
        $current=if($installing){[int64](Get-EntryProperty $State 'InstallProcessedBytes' 0)}else{[int64](Get-EntryProperty $State 'DownloadedBytes' 0)}
        $total=if($installing){[int64](Get-EntryProperty $State 'InstallSizeBytes' 0)}else{[int64](Get-EntryProperty $State 'TotalBytes' 0)}
        $speed=if($installing){[double](Get-EntryProperty $State 'InstallSpeedBytesPerSec' (Get-EntryProperty $State 'TransferSpeedBytesPerSec' 0))}else{[double](Get-EntryProperty $State 'DownloadSpeedBytesPerSec' (Get-EntryProperty $State 'TransferSpeedBytesPerSec' 0))}
        if($total -gt 0 -and $speed -gt 1){$eta=[int64][math]::Ceiling([math]::Max(0,$total-$current)/$speed)}
        if($eta -lt 0){
            $progress=[int](Get-EntryProperty $State 'Progress' -1)
            $started=[string](Get-EntryProperty $State 'StartedAt' '')
            if($progress -gt 1 -and $progress -lt 100 -and $started){
                try{
                    $elapsed=((Get-Date)-[datetime]::Parse($started)).TotalSeconds
                    if($elapsed -gt 2){$eta=[int64][math]::Ceiling(($elapsed/$progress)*(100-$progress))}
                }catch{}
            }
        }
    }
    if($eta -lt 0){return 'Calculating ETA…'}
    $span=[TimeSpan]::FromSeconds([math]::Max(0,$eta))
    $prefix=if([bool](Get-EntryProperty $State 'EtaEstimated' $false)){'Approx. '}else{''}
    if($span.TotalHours -ge 1){return ($prefix+('{0}h {1}m remaining' -f [math]::Floor($span.TotalHours),$span.Minutes))}
    if($span.TotalMinutes -ge 1){return ($prefix+('{0} min {1} sec remaining' -f [math]::Floor($span.TotalMinutes),$span.Seconds))}
    return ($prefix+('{0} sec remaining' -f [math]::Max(0,[math]::Ceiling($span.TotalSeconds))))
}
function Get-ProviderDownloadPageActions {
    $active=@(Get-GameProviderActiveTransfers)
    if($active.Count -eq 0){return (& $script:HcBaseGetProviderDownloadPageActions)}
    $actions=New-Object System.Collections.ArrayList
    foreach($state in $active){
        $name=[string](Get-EntryProperty $state 'GameName' 'Game')
        $provider=[string](Get-EntryProperty $state 'Provider' 'Provider')
        $phase=[string](Get-EntryProperty $state 'Phase' 'Downloading')
        $progress=[int](Get-EntryProperty $state 'Progress' -1)
        $desc="$provider  |  $phase"
        if($progress -ge 0){$desc+="  |  $progress%"}
        $desc+="  |  $(Get-HcProviderTransferEtaText $state)"
        [void]$actions.Add((New-Action 'noop' "$phase — $name" $desc))
    }
    $cancelTitle=if($active.Count -eq 1){'Cancel active download'}else{"Cancel all $($active.Count) active downloads"}
    [void]$actions.Add((New-Action 'provider-cancel' $cancelTitle 'Stops active provider workers; partial files are retained where the backend supports resume.'))
    return [object[]]$actions.ToArray()
}
