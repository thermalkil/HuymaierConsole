param(
    [Parameter(Mandatory=$true)][string]$CorePath,
    [Parameter(Mandatory=$true)][string]$BootstrapPath,
    [Parameter(Mandatory=$true)][string]$InstallerScriptPath
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
foreach($path in @($CorePath,$BootstrapPath,$InstallerScriptPath)){if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "User 3D-model transform input missing: $path"}}
$repoRoot=Split-Path -Parent $PSScriptRoot
$userRuntime=Join-Path $repoRoot 'HuymaierUser3DModels.ps1'
if(-not(Test-Path -LiteralPath $userRuntime -PathType Leaf)){throw "User 3D-model runtime missing: $userRuntime"}

$core=Get-Content -Raw -LiteralPath $CorePath -Encoding UTF8
if($core -notmatch 'HUYMAIER_USER_3D_MODELS_RUNTIME_LOAD_V1'){
    $needle='$script:LivePlatformModelsModulePath = Join-Path $script:BaseDir ''HuymaierLivePlatformModels.ps1'''
    if(-not $core.Contains($needle)){throw 'User 3D-model runtime requires live-model module path first.'}
    $core=$core.Replace($needle,$needle+"`r`n`$script:User3DModelsModulePath = Join-Path `$script:BaseDir 'HuymaierUser3DModels.ps1'")
    $load=@'
if (Test-Path -LiteralPath $script:LivePlatformModelsModulePath) {
    try { . $script:LivePlatformModelsModulePath }
    catch { Write-Log "Live platform 3D model module load failed: $($_.Exception.Message)" 'ERROR' }
}
'@
    if(-not $core.Contains($load)){throw 'User 3D-model runtime could not find live-model load block.'}
    $replacement=$load+@'

# HUYMAIER_USER_3D_MODELS_RUNTIME_LOAD_V1
if (Test-Path -LiteralPath $script:User3DModelsModulePath) {
    try { . $script:User3DModelsModulePath }
    catch { Write-Log "User 3D Models module load failed: $($_.Exception.Message)" 'ERROR' }
}
'@
    $core=$core.Replace($load,$replacement)
}
Set-Content -LiteralPath $CorePath -Value $core -Encoding UTF8

$bootstrap=Get-Content -Raw -LiteralPath $BootstrapPath -Encoding UTF8
if($bootstrap -notmatch 'HUYMAIER_USER_3D_MODELS_PREFLIGHT_V1'){
    $needle='$livePlatformModelsPath=Join-Path $baseDir ''HuymaierLivePlatformModels.ps1'''
    if(-not $bootstrap.Contains($needle)){throw 'User 3D-model preflight requires live-model path first.'}
    $bootstrap=$bootstrap.Replace($needle,$needle+"`r`n# HUYMAIER_USER_3D_MODELS_PREFLIGHT_V1`r`n`$user3DModelsPath=Join-Path `$baseDir 'HuymaierUser3DModels.ps1'")
    $entry="        [pscustomobject]@{Path=`$livePlatformModelsPath;Label='Live platform 3D runtime'},"
    if(-not $bootstrap.Contains($entry)){throw 'User 3D-model preflight could not find live-model entry.'}
    $bootstrap=$bootstrap.Replace($entry,$entry+"`r`n        [pscustomobject]@{Path=`$user3DModelsPath;Label='User 3D Models runtime'},")
}
Set-Content -LiteralPath $BootstrapPath -Value $bootstrap -Encoding UTF8

$installer=Get-Content -Raw -LiteralPath $InstallerScriptPath -Encoding UTF8
if($installer -notmatch 'HUYMAIER_USER_3D_MODELS_INSTALLER_CACHE_V1'){
    $needle="            'HuymaierLivePlatformModels.ps1',"
    if(-not $installer.Contains($needle)){throw 'User 3D-model installer cache requires live-model runtime entry.'}
    $installer=$installer.Replace($needle,$needle+"`r`n            # HUYMAIER_USER_3D_MODELS_INSTALLER_CACHE_V1`r`n            'HuymaierUser3DModels.ps1',")
}
Set-Content -LiteralPath $InstallerScriptPath -Value $installer -Encoding UTF8
