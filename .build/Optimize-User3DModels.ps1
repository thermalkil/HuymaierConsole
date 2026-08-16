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
$gpuRuntime=Join-Path $repoRoot 'HuymaierGpuPlatformShelves.ps1'
foreach($required in @($userRuntime,$gpuRuntime)){if(-not(Test-Path -LiteralPath $required -PathType Leaf)){throw "User/GPU 3D-model runtime missing: $required"}}

$core=Get-Content -Raw -LiteralPath $CorePath -Encoding UTF8
if($core -notmatch 'HUYMAIER_USER_3D_MODELS_RUNTIME_LOAD_V1'){
    $pathNeedle='$script:LivePlatformModelsModulePath = Join-Path $script:BaseDir ''HuymaierLivePlatformModels.ps1'''
    if(-not $core.Contains($pathNeedle)){throw 'User 3D-model runtime requires live-model helper path first.'}
    $core=$core.Replace($pathNeedle,$pathNeedle+"`r`n`$script:User3DModelsModulePath = Join-Path `$script:BaseDir 'HuymaierUser3DModels.ps1'")

    $load=@'
if (Test-Path -LiteralPath $script:LivePlatformModelsModulePath) {
    try { . $script:LivePlatformModelsModulePath }
    catch { Write-Log "Live platform 3D helper module load failed: $($_.Exception.Message)" 'ERROR' }
}
'@
    if(-not $core.Contains($load)){throw 'User 3D-model runtime could not find cleaned live-helper load block.'}
    $replacement=$load+@'

# HUYMAIER_USER_3D_MODELS_RUNTIME_LOAD_V1
# Compatibility presentation/helpers. V7 GPU shelves load immediately after this.
if (Test-Path -LiteralPath $script:User3DModelsModulePath) {
    try { . $script:User3DModelsModulePath }
    catch { Write-Log "User 3D Models compatibility module load failed: $($_.Exception.Message)" 'ERROR' }
}
'@
    $core=$core.Replace($load,$replacement)
}
if($core -notmatch 'HUYMAIER_GPU_3D_SHELVES_RUNTIME_LOAD_V1'){
    $pathNeedle='$script:User3DModelsModulePath = Join-Path $script:BaseDir ''HuymaierUser3DModels.ps1'''
    if(-not$core.Contains($pathNeedle)){throw 'GPU shelf runtime requires user-model compatibility path first.'}
    $core=$core.Replace($pathNeedle,$pathNeedle+"`r`n`$script:GpuPlatformShelvesModulePath = Join-Path `$script:BaseDir 'HuymaierGpuPlatformShelves.ps1'")
    $load=@'
if (Test-Path -LiteralPath $script:User3DModelsModulePath) {
    try { . $script:User3DModelsModulePath }
    catch { Write-Log "User 3D Models compatibility module load failed: $($_.Exception.Message)" 'ERROR' }
}
'@
    if(-not$core.Contains($load)){throw 'GPU shelf runtime could not find user-model compatibility load block.'}
    $replacement=$load+@'

# HUYMAIER_GPU_3D_SHELVES_RUNTIME_LOAD_V1
# Final Games 3D owner: persistent HC3D caches + shared native D3D11 surfaces.
if (Test-Path -LiteralPath $script:GpuPlatformShelvesModulePath) {
    try { . $script:GpuPlatformShelvesModulePath }
    catch { Write-Log "GPU platform shelves module load failed: $($_.Exception.Message)" 'ERROR' }
}
'@
    $core=$core.Replace($load,$replacement)
}
Set-Content -LiteralPath $CorePath -Value $core -Encoding UTF8

$bootstrap=Get-Content -Raw -LiteralPath $BootstrapPath -Encoding UTF8
if($bootstrap -notmatch 'HUYMAIER_USER_3D_MODELS_PREFLIGHT_V1'){
    $needle='$livePlatformModelsPath=Join-Path $baseDir ''HuymaierLivePlatformModels.ps1'''
    if(-not $bootstrap.Contains($needle)){throw 'User 3D-model preflight requires live-model helper path first.'}
    $bootstrap=$bootstrap.Replace($needle,$needle+"`r`n# HUYMAIER_USER_3D_MODELS_PREFLIGHT_V1`r`n`$user3DModelsPath=Join-Path `$baseDir 'HuymaierUser3DModels.ps1'")
    $entry="        [pscustomobject]@{Path=`$livePlatformModelsPath;Label='Live platform 3D helper runtime'},"
    if(-not $bootstrap.Contains($entry)){throw 'User 3D-model preflight could not find cleaned live-helper entry.'}
    $bootstrap=$bootstrap.Replace($entry,$entry+"`r`n        [pscustomobject]@{Path=`$user3DModelsPath;Label='User 3D Models compatibility runtime'},")
}
if($bootstrap -notmatch 'HUYMAIER_GPU_3D_SHELVES_PREFLIGHT_V1'){
    $needle='$user3DModelsPath=Join-Path $baseDir ''HuymaierUser3DModels.ps1'''
    if(-not$bootstrap.Contains($needle)){throw 'GPU shelf preflight requires user-model path first.'}
    $bootstrap=$bootstrap.Replace($needle,$needle+"`r`n# HUYMAIER_GPU_3D_SHELVES_PREFLIGHT_V1`r`n`$gpuPlatformShelvesPath=Join-Path `$baseDir 'HuymaierGpuPlatformShelves.ps1'")
    $entry="        [pscustomobject]@{Path=`$user3DModelsPath;Label='User 3D Models compatibility runtime'},"
    if(-not$bootstrap.Contains($entry)){throw 'GPU shelf preflight could not find user-model entry.'}
    $bootstrap=$bootstrap.Replace($entry,$entry+"`r`n        [pscustomobject]@{Path=`$gpuPlatformShelvesPath;Label='D3D11 GPU platform shelves runtime'},")
}
Set-Content -LiteralPath $BootstrapPath -Value $bootstrap -Encoding UTF8

$installer=Get-Content -Raw -LiteralPath $InstallerScriptPath -Encoding UTF8
if($installer -notmatch 'HUYMAIER_USER_3D_MODELS_INSTALLER_CACHE_V1'){
    $needle="            'HuymaierLivePlatformModels.ps1',"
    if(-not $installer.Contains($needle)){throw 'User 3D-model installer cache requires live-model helper runtime entry.'}
    $installer=$installer.Replace($needle,$needle+"`r`n            # HUYMAIER_USER_3D_MODELS_INSTALLER_CACHE_V1`r`n            'HuymaierUser3DModels.ps1',")
}
if($installer -notmatch 'HUYMAIER_GPU_3D_SHELVES_INSTALLER_CACHE_V1'){
    $needle="            'HuymaierUser3DModels.ps1',"
    if(-not$installer.Contains($needle)){throw 'GPU shelf installer cache requires user-model runtime entry.'}
    $installer=$installer.Replace($needle,$needle+"`r`n            # HUYMAIER_GPU_3D_SHELVES_INSTALLER_CACHE_V1`r`n            'HuymaierGpuPlatformShelves.ps1',`r`n            'HuymaierD3D11ShelfRenderer.dll',
            'HuymaierGpuShelfHost.dll',`r`n            'HuymaierGpuShelfAssetCompiler.exe',")
}
Set-Content -LiteralPath $InstallerScriptPath -Value $installer -Encoding UTF8
