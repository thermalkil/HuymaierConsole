param()
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
# HUYMAIER_V0308_INSTALLER_VERSION_TRANSFORM_V1
$root=Split-Path -Parent $PSScriptRoot
function Read-Normalized([string]$Path){return ([IO.File]::ReadAllText($Path,[Text.Encoding]::UTF8).Replace("`r`n","`n"))}
function Write-Normalized([string]$Path,[string]$Text){[IO.File]::WriteAllText($Path,$Text.Replace("`n","`r`n"),(New-Object Text.UTF8Encoding($true)))}
function Replace-Required([string]$Text,[string]$Old,[string]$New,[string]$Label){if(-not $Text.Contains($Old)){throw "v0.30.8 installer transform anchor missing: $Label"};return $Text.Replace($Old,$New)}
$lf="`n"
$installerPath=Join-Path $root 'Install-HuymaierConsole.ps1'
$installer=Read-Normalized $installerPath
$installer=Replace-Required $installer "[string]`$Version='0.30.7'" "[string]`$Version='0.30.8'" 'installer cache version default'
$installer=Replace-Required $installer "-Version '0.30.7'" "-Version '0.30.8'" 'installer cache seed version'
if($installer -notmatch 'HUYMAIER_V0308_ARTWORK_INSTALLER_CACHE_V1'){
    $anchor="            'HuymaierArtworkWorker.ps1',"
    $insert=@($anchor,"            # HUYMAIER_V0308_ARTWORK_INSTALLER_CACHE_V1","            'HuymaierArtworkSources.ps1',","            'HuymaierArtworkManagement.ps1',") -join $lf
    $installer=Replace-Required $installer $anchor $insert 'installer artwork preflight cache entries'
}
Write-Normalized $installerPath $installer
$corePath=Join-Path $root 'HuymaierInstallerCore.ps1'
$core=Read-Normalized $corePath
$core=Replace-Required $core "`$script:InstallVersion='0.30.7'" "`$script:InstallVersion='0.30.8'" 'installer core version'
if($core -notmatch 'HUYMAIER_V0308_ARTWORK_INSTALLER_REQUIRED_V1'){
    $anchor="        'HuymaierBootstrap.ps1','HuymaierConsole.ps1','HuymaierGameBar.ps1',"
    $insert="        'HuymaierBootstrap.ps1','HuymaierConsole.ps1','HuymaierArtworkSources.ps1','HuymaierArtworkManagement.ps1','HuymaierGameBar.ps1', # HUYMAIER_V0308_ARTWORK_INSTALLER_REQUIRED_V1"
    $core=Replace-Required $core $anchor $insert 'installer required artwork modules'
}
Write-Normalized $corePath $core
Write-Host 'Applied Huymaier Console v0.30.8 installer version/artwork preflight transform.'
