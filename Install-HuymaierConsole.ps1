param([switch]$SilentUpdate)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'

$core=Join-Path $PSScriptRoot 'HuymaierInstallerCore.ps1'
if(-not(Test-Path -LiteralPath $core -PathType Leaf)){
    try{
        Add-Type -AssemblyName PresentationFramework -ErrorAction SilentlyContinue
        [System.Windows.MessageBox]::Show("Huymaier Console installation cannot start because HuymaierInstallerCore.ps1 is missing.`n`nPackage:`n$PSScriptRoot",'Huymaier Console Installer','OK','Error')|Out-Null
    }catch{}
    exit 1
}

& $core -PackageRoot $PSScriptRoot -SilentUpdate:$SilentUpdate
exit $LASTEXITCODE
