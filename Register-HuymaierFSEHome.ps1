param([switch]$Remove)

Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$baseDir=Split-Path -Parent $MyInvocation.MyCommand.Path
$packageDir=Join-Path $baseDir 'FSEPackage'
$manifest=Join-Path $packageDir 'AppxManifest.xml'
$hostExe=Join-Path $packageDir 'HuymaierFSEHost.exe'
$packageName='Huymaier.Console.FSE.Home'
$dataDir=Join-Path $env:LOCALAPPDATA 'Huymaier Console'
$logDir=Join-Path $dataDir 'Logs'
New-Item -ItemType Directory -Force -Path $dataDir,$logDir|Out-Null

function Write-FseLog {
    param([string]$Message,[string]$Level='INFO')
    try{"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff') [$Level] FSE Home: $Message"|Add-Content (Join-Path $logDir "$(Get-Date -Format 'yyyy-MM-dd').log") -Encoding UTF8}catch{}
}

try{
    if($Remove){
        $packages=@(Get-AppxPackage -Name $packageName -ErrorAction SilentlyContinue)
        foreach($package in $packages){Remove-AppxPackage -Package $package.PackageFullName -ErrorAction Stop}
        Write-FseLog 'Removed the current-user Windows gaming Home registration.'
        exit 0
    }

    if(-not(Test-Path -LiteralPath $manifest -PathType Leaf)){throw "Missing verified FSE manifest: $manifest"}
    if(-not(Test-Path -LiteralPath $hostExe -PathType Leaf)){throw "Missing CI-built FSE host: $hostExe"}

    # Registration is intentionally current-user and non-elevated. Huymaier
    # Console never enables machine-wide Developer Mode or changes AppModelUnlock
    # policy on the user's behalf.
    foreach($package in @(Get-AppxPackage -Name $packageName -ErrorAction SilentlyContinue)){
        Remove-AppxPackage -Package $package.PackageFullName -ErrorAction Stop
    }

    Add-AppxPackage -Register $manifest -ForceApplicationShutdown -ErrorAction Stop
    $registered=Get-AppxPackage -Name $packageName -ErrorAction SilentlyContinue|Select-Object -First 1
    if($null -eq $registered){throw 'Windows did not return the current-user Huymaier gaming Home package after registration.'}
    Write-FseLog "Registered verified package $($registered.PackageFullName)."
    exit 0
}catch{
    Write-FseLog $_.Exception.ToString() 'ERROR'
    try{
        Add-Type -AssemblyName PresentationFramework -ErrorAction SilentlyContinue
        [System.Windows.MessageBox]::Show("Windows could not register Huymaier Console as the current user's gaming Home app.`n`n$($_.Exception.Message)`n`nHuymaier Console did not change machine-wide Developer Mode settings. If Windows requires Developer Mode for loose-package registration, enable it yourself in Windows Settings and retry.",'Huymaier Console FSE Home','OK','Warning')|Out-Null
    }catch{}
    exit 1
}
