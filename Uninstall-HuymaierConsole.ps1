Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'

$installRoot=Join-Path $env:LOCALAPPDATA 'Huymaier Console'
$restore=Join-Path $installRoot 'Restore-HuymaierWindowsSettings.ps1'
$packageName='Huymaier.Console.FSE.Home'

try{
    Get-Process -Name HuymaierConsole -ErrorAction SilentlyContinue|Where-Object{$_.Id -ne $PID}|Stop-Process -Force -ErrorAction SilentlyContinue
    if(Test-Path -LiteralPath $restore -PathType Leaf){try{& $restore -Quiet}catch{}}

    foreach($package in @(Get-AppxPackage -Name $packageName -ErrorAction SilentlyContinue)){
        Remove-AppxPackage -Package $package.PackageFullName -ErrorAction Stop
    }
    if(@(Get-AppxPackage -Name $packageName -ErrorAction SilentlyContinue).Count -gt 0){
        throw 'Windows still reports the Huymaier Console gaming Home package as registered. Installed files were preserved to avoid leaving a dangling package registration.'
    }

    Remove-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name HuymaierConsole -ErrorAction SilentlyContinue
    Remove-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce' -Name HuymaierConsoleRestoreGameBar -ErrorAction SilentlyContinue
    Remove-Item (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Huymaier Console.lnk') -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Huymaier Console.lnk') -Force -ErrorAction SilentlyContinue

    if(Test-Path -LiteralPath $installRoot){Remove-Item -LiteralPath $installRoot -Recurse -Force -ErrorAction Stop}
    try{Add-Type -AssemblyName PresentationFramework;[System.Windows.MessageBox]::Show('Huymaier Console was removed and its temporary Windows controller setting was restored.','Huymaier Console','OK','Information')|Out-Null}catch{}
    exit 0
}catch{
    try{Add-Type -AssemblyName PresentationFramework;[System.Windows.MessageBox]::Show("Huymaier Console could not be fully removed.`n`n$($_.Exception.Message)",'Huymaier Console','OK','Error')|Out-Null}catch{}
    exit 1
}
