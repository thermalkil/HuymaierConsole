# Huymaier Console GitHub release updater integration.
$script:ConsoleUpdateStatePath = Join-Path $script:DataDir 'console-update-state.json'
$script:ConsoleUpdateState = $null
$script:ConsoleUpdateStateSignature = ''
$script:ConsoleUpdateWorkerPath = Join-Path $script:BaseDir 'HuymaierConsoleUpdateWorker.ps1'

function New-DefaultConsoleUpdateState {
    [pscustomobject]@{
        Phase='Idle'; Message='Check GitHub for a newer Huymaier Console release.'; Busy=$false
        CurrentVersion=$script:AppVersion; LatestVersion=''; UpdateAvailable=$false; ReleaseName=''
        ReleaseNotes=''; PublishedAt=''; AssetName=''; AssetSize=0L; DownloadedBytes=0L; DownloadPercent=0
        Verified=$false; Error=''; Repository='thermalkil/HuymaierConsole'
    }
}
function Read-ConsoleUpdateState {
    if(-not (Test-Path -LiteralPath $script:ConsoleUpdateStatePath)){
        if($null -eq $script:ConsoleUpdateState){$script:ConsoleUpdateState=New-DefaultConsoleUpdateState}; return $script:ConsoleUpdateState
    }
    try{$script:ConsoleUpdateState=Get-Content -Raw -LiteralPath $script:ConsoleUpdateStatePath|ConvertFrom-Json}catch{$script:ConsoleUpdateState=New-DefaultConsoleUpdateState}
    return $script:ConsoleUpdateState
}
function Start-ConsoleUpdateWorker {
    param([ValidateSet('Scan','Install')][string]$Action)
    Read-ConsoleUpdateState|Out-Null
    if($script:ConsoleUpdateState -and [bool](Get-EntryProperty $script:ConsoleUpdateState 'Busy' $false)){return}
    if(-not (Test-Path -LiteralPath $script:ConsoleUpdateWorkerPath)){Set-ConsoleNotice 'Huymaier Console update worker is missing.' 'ERROR';return}
    $args=@('-NoProfile','-ExecutionPolicy','Bypass','-File',$script:ConsoleUpdateWorkerPath,'-Action',$Action,'-StatePath',$script:ConsoleUpdateStatePath,'-CurrentVersion',$script:AppVersion,'-Repository','thermalkil/HuymaierConsole','-InstallRoot',$script:BaseDir)
    try{
        Start-Process -FilePath 'powershell.exe' -ArgumentList $args -WindowStyle Hidden|Out-Null
        $script:ConsoleUpdateState=New-DefaultConsoleUpdateState;$script:ConsoleUpdateState.Phase=if($Action -eq 'Scan'){'Scanning'}else{'Preparing'};$script:ConsoleUpdateState.Message=if($Action -eq 'Scan'){'Checking GitHub Releases...'}else{'Preparing Huymaier Console update...'};$script:ConsoleUpdateState.Busy=$true
        Write-Log "Huymaier Console update worker requested: Action=$Action"
        Render-Page
    }catch{Set-ConsoleNotice "Huymaier Console update could not start: $($_.Exception.Message)" 'ERROR'}
}
function Get-ConsoleUpdateHeroText {
    Read-ConsoleUpdateState|Out-Null;$s=$script:ConsoleUpdateState
    $parts=New-Object System.Collections.Generic.List[string]
    $parts.Add("Installed: v$script:AppVersion")
    $latest=[string](Get-EntryProperty $s 'LatestVersion' '');if($latest){$parts.Add("Latest: v$latest")}
    $m=[string](Get-EntryProperty $s 'Message' '');if($m){$parts.Add($m)}
    return ($parts -join "`n")
}
