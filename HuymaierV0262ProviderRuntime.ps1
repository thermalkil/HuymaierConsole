# Huymaier Console v0.26.2 provider-progress bridge.
# Loaded after HuymaierV0262Runtime.ps1. Telemetry sidecars never replace the
# authoritative provider-state.json; they are merged only when rendering.

$script:HcProviderProgressStatePath=Join-Path $script:DataDir 'provider-progress.json'
$script:HcV0262ProviderBaseUpdateActiveDownloadVisuals=${function:Update-HcActiveDownloadVisuals}

function Start-HcProviderProgressMonitor {
    param([string]$Provider,[string]$GameName,[string]$InstallPath,[int]$WorkerPid)
    if($WorkerPid -le 0 -or $Provider -notin @('GOG','Amazon') -or -not(Test-Path -LiteralPath $script:HcProviderProgressWorkerPath -PathType Leaf)){return}
    $watch=Get-HcProviderMonitorPath $Provider $GameName $InstallPath
    $args=@(
        '-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',('"'+$script:HcProviderProgressWorkerPath+'"'),
        '-Provider',$Provider,
        '-StatePath',('"'+$script:ProviderStatePath+'"'),
        '-ProgressPath',('"'+$script:HcProviderProgressStatePath+'"'),
        '-WatchPath',('"'+([string]$watch).Replace('"','')+'"'),
        '-WorkerPid',$WorkerPid
    )
    try{Remove-Item -LiteralPath $script:HcProviderProgressStatePath -Force -ErrorAction SilentlyContinue;Start-Process "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList $args -WindowStyle Hidden|Out-Null}catch{}
}

function Get-HcProviderProgressOverlay {
    param($Active)
    if($null -eq $Active -or -not(Test-Path -LiteralPath $script:HcProviderProgressStatePath -PathType Leaf)){return $null}
    try{
        $progress=Get-Content -Raw -LiteralPath $script:HcProviderProgressStatePath|ConvertFrom-Json
        if(-not [bool](Get-EntryProperty $progress 'Busy' $false)){return $null}
        $updated=[datetime](Get-EntryProperty $progress 'Updated' ([datetime]::MinValue).ToString('o'));if(([datetime]::UtcNow-$updated.ToUniversalTime()).TotalSeconds -gt 8){return $null}
        $provider=[string](Get-EntryProperty $Active 'Provider' '');$gameId=[string](Get-EntryProperty $Active 'GameId' '');$workerPid=[int](Get-EntryProperty $Active 'WorkerPid' 0)
        if(-not [string]::Equals([string](Get-EntryProperty $progress 'Provider' ''),$provider,[StringComparison]::OrdinalIgnoreCase)){return $null}
        $progressGameId=[string](Get-EntryProperty $progress 'GameId' '');if($gameId -and $progressGameId -and -not [string]::Equals($progressGameId,$gameId,[StringComparison]::OrdinalIgnoreCase)){return $null}
        $progressPid=[int](Get-EntryProperty $progress 'WorkerPid' 0);if($workerPid -gt 0 -and $progressPid -gt 0 -and $workerPid -ne $progressPid){return $null}
        return $progress
    }catch{return $null}
}
function Merge-HcProviderProgressForDisplay {
    param($Active)
    $overlay=Get-HcProviderProgressOverlay $Active
    if($null -eq $overlay){return $Active}
    $copy=[ordered]@{}
    foreach($p in $Active.PSObject.Properties){$copy[$p.Name]=$p.Value}
    $activity=[int64](Get-EntryProperty $overlay 'ActivityBytes' 0);$rate=[double](Get-EntryProperty $overlay 'ActivityBytesPerSec' 0)
    if($activity -gt 0){$copy['DownloadedBytes']=$activity}
    if($rate -ge 0){$copy['DownloadSpeedBytesPerSec']=$rate}
    $copy['Progress']=-1
    $message=[string](Get-EntryProperty $overlay 'Message' 'Provider install activity detected.')
    if($message){$copy['Message']=$message}
    return [pscustomobject]$copy
}
function Update-HcActiveDownloadVisuals {
    param($Active)
    $display=Merge-HcProviderProgressForDisplay $Active
    $ok=[bool](& $script:HcV0262ProviderBaseUpdateActiveDownloadVisuals $display)
    if($ok -and $null -ne $script:HcDownloadProgressBar){
        $progress=[int](Get-EntryProperty $display 'Progress' -1);$busy=[bool](Get-EntryProperty $display 'Busy' $false)
        $script:HcDownloadProgressBar.IsIndeterminate=($busy -and $progress -lt 0)
        if($script:HcDownloadProgressBar.IsIndeterminate -and $null -ne $script:HcDownloadStatsText){
            $activity=[int64](Get-EntryProperty $display 'DownloadedBytes' 0);$rate=[double](Get-EntryProperty $display 'DownloadSpeedBytesPerSec' 0)
            $pieces=New-Object System.Collections.ArrayList
            if($activity -gt 0){[void]$pieces.Add(('Observed writes: '+(Format-HcTransferBytes $activity)))}
            if($rate -gt 0){[void]$pieces.Add((Format-HcTransferRate $rate))}
            if($pieces.Count -eq 0){[void]$pieces.Add('Waiting for provider activity')}
            $script:HcDownloadStatsText.Text=($pieces -join '  •  ')
        }
    }
    return $ok
}

$script:HcV0262HardeningPath=Join-Path $script:BaseDir 'HuymaierV0262Hardening.ps1'
if(Test-Path -LiteralPath $script:HcV0262HardeningPath -PathType Leaf){. $script:HcV0262HardeningPath}
$script:HcSteamOwnershipRuntimePath=Join-Path $script:BaseDir 'HuymaierSteamOwnershipRuntime.ps1'
if(Test-Path -LiteralPath $script:HcSteamOwnershipRuntimePath -PathType Leaf){. $script:HcSteamOwnershipRuntimePath}
