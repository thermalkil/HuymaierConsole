param([switch]$Quiet)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'

$root=Join-Path $env:LOCALAPPDATA 'Huymaier Console'
$backupPath=Join-Path $root 'xbox-gamebar-backup.json'
$runOnce='HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce'
$runOnceName='HuymaierConsoleRestoreGameBar'

try{
    if(Test-Path -LiteralPath $backupPath -PathType Leaf){
        $rawBackup=Get-Content -Raw -LiteralPath $backupPath -Encoding UTF8|ConvertFrom-Json
        foreach($backup in @($rawBackup)){
            if($null -eq $backup){continue}
            $path=[string]$backup.Path
            $name=[string]$backup.Name
            if([string]::IsNullOrWhiteSpace($path) -or [string]::IsNullOrWhiteSpace($name)){continue}
            $currentExists=$false
            $current=$null
            try{
                $item=Get-ItemProperty -LiteralPath $path -Name $name -ErrorAction Stop
                if($null -ne $item.PSObject.Properties[$name]){$currentExists=$true;$current=$item.$name}
            }catch{}

            # Restore only while Huymaier's forced zero is still present. A newer
            # user change always wins. This also safely migrates v0.26.0's older
            # four-setting backup format without concatenating registry paths.
            if($currentExists -and [int]$current -eq 0){
                if([bool]$backup.Exists){
                    if(-not(Test-Path -LiteralPath $path)){New-Item -Path $path -Force|Out-Null}
                    Set-ItemProperty -LiteralPath $path -Name $name -Type DWord -Value ([int]$backup.Value) -Force
                }else{
                    Remove-ItemProperty -LiteralPath $path -Name $name -ErrorAction SilentlyContinue
                }
            }
        }
        Remove-Item -LiteralPath $backupPath -Force -ErrorAction SilentlyContinue
    }
    Remove-ItemProperty -LiteralPath $runOnce -Name $runOnceName -ErrorAction SilentlyContinue
}catch{
    if(-not $Quiet){throw}
}
