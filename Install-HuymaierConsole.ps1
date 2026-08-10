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

# Seed the process exit state because an interactive successful PowerShell
# script invocation may never create $LASTEXITCODE. The installer core uses
# explicit `exit 1` for a transactional failure, which updates this value; a
# normal interactive success leaves the seeded 0 unchanged.
$global:LASTEXITCODE=0
& $core -PackageRoot $PSScriptRoot -SilentUpdate:$SilentUpdate
exit ([int]$global:LASTEXITCODE)
