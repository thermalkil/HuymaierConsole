# Huymaier Console v0.26.2 behavioral hardening.
# Loaded after the runtime/provider layers so it can enforce cross-feature rules.

$script:HcV0262HardBaseApplyControllerNavigation=${function:Apply-ControllerNavigation}
$script:HcV0262HardBaseStartSteamWorker=${function:Start-HcSteamWorker}

function Get-HcGamesLayoutColumnCount {
    $max=1
    foreach($row in @($script:HomeRows)){try{if([bool](Get-EntryProperty $row 'Platform' $false)){$max=[math]::Max($max,[int](Get-EntryProperty $row 'Count' 1))}}catch{}}
    return $max
}

function Apply-ControllerNavigation {
    param([int]$Mask,[string]$Direction)
    if($script:HcGamesLayoutEditMode -and $script:HcGamesLayoutGrabbed -and $Direction){
        $delta=0
        switch($Direction){
            'Left' {$delta=-1}
            'Right' {$delta=1}
            'Up' {$delta=-(Get-HcGamesLayoutColumnCount)}
            'Down' {$delta=(Get-HcGamesLayoutColumnCount)}
        }
        if($delta -ne 0){Move-HcGamesLayoutItem $delta;$Direction=''}
    }
    & $script:HcV0262HardBaseApplyControllerNavigation $Mask $Direction
}

function Test-HcAnyProviderOperationActive {
    try{
        if(Get-Command Test-ProviderWorkerProcessActive -ErrorAction SilentlyContinue){if(Test-ProviderWorkerProcessActive){return $true}}
        if(Get-Command Read-GameProviderState -ErrorAction SilentlyContinue){
            $state=Read-GameProviderState
            if($state -and [bool](Get-EntryProperty $state 'Busy' $false)){
                $pid=[int](Get-EntryProperty $state 'WorkerPid' 0)
                if($pid -gt 0){try{Get-Process -Id $pid -ErrorAction Stop|Out-Null;return $true}catch{}}
                # A zero PID is valid briefly while the UI has created the launch
                # marker and the new worker is starting. Treat a fresh marker as busy.
                $updated=[string](Get-EntryProperty $state 'Updated' '')
                if($updated){try{if(((Get-Date)-([datetime]$updated)).TotalSeconds -lt 12){return $true}}catch{}}
            }
        }
    }catch{}
    return $false
}

function Start-HcSteamWorker {
    param([string]$Mode,[string]$GameId='',[string]$GameName='')
    # Automatic refresh requests must never interrupt or compete with a game
    # install/verify/uninstall already owned by another provider.
    if(Test-HcAnyProviderOperationActive){
        if($Mode -ne 'Refresh'){Set-ConsoleNotice 'A provider operation is already running. Wait for it to finish before starting Steam.' 'WARN'}
        return
    }
    & $script:HcV0262HardBaseStartSteamWorker $Mode $GameId $GameName
}
