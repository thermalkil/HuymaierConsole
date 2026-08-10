param([switch]$Quiet)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'

$root=Join-Path $env:LOCALAPPDATA 'Huymaier Console'
$backupPath=Join-Path $root 'xbox-gamebar-backup.json'
$runOnce='HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce'
$runOnceName='HuymaierConsoleRestoreGameBar'

try{
    if(Test-Path -LiteralPath $backupPath -PathType Leaf){
        $backup=Get-Content -Raw -LiteralPath $backupPath -Encoding UTF8|ConvertFrom-Json
        $path=[string]$backup.Path
        $name=[string]$backup.Name
        $currentExists=$false
        $current=$null
        try{
            $item=Get-ItemProperty -LiteralPath $path -Name $name -ErrorAction Stop
            if($null -ne $item.PSObject.Properties[$name]){$currentExists=$true;$current=$item.$name}
        }catch{}

        # Huymaier only restores when its forced value is still present. If the
        # user changed this Windows setting while Huymaier was running, the
        # user's newer choice wins and is never overwritten here.
        if($currentExists -and [int]$current -eq 0){
            if([bool]$backup.Exists){
                if(-not(Test-Path -LiteralPath $path)){New-Item -Path $path -Force|Out-Null}
                Set-ItemProperty -LiteralPath $path -Name $name -Type DWord -Value ([int]$backup.Value) -Force
            }else{
                Remove-ItemProperty -LiteralPath $path -Name $name -ErrorAction SilentlyContinue
            }
        }
        Remove-Item -LiteralPath $backupPath -Force -ErrorAction SilentlyContinue
    }
    Remove-ItemProperty -LiteralPath $runOnce -Name $runOnceName -ErrorAction SilentlyContinue
}catch{
    if(-not $Quiet){throw}
}
