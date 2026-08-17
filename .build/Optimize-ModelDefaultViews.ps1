param(
    [Parameter(Mandatory=$true)][string]$CorePath,
    [Parameter(Mandatory=$true)][string]$BootstrapPath,
    [Parameter(Mandatory=$true)][string]$InstallerScriptPath,
    [Parameter(Mandatory=$true)][string]$NativeRuntimePath
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
foreach($path in @($CorePath,$BootstrapPath,$InstallerScriptPath,$NativeRuntimePath)){
    if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "Model-default transform input missing: $path"}
}
$repoRoot=Split-Path -Parent $PSScriptRoot
$modelDefaultsPath=Join-Path $repoRoot 'HuymaierModelDefaults.ps1'
if(-not(Test-Path -LiteralPath $modelDefaultsPath -PathType Leaf)){throw "Model-default runtime missing: $modelDefaultsPath"}

$core=Get-Content -Raw -LiteralPath $CorePath -Encoding UTF8
if($core -notmatch 'HUYMAIER_V0304_MODEL_DEFAULT_CONFIG_V1'){
    $defaultAnchor='        RecompGames = @()'
    if(-not$core.Contains($defaultAnchor)){throw 'Model-default config requires manual Recomps config transform first.'}
    $core=$core.Replace($defaultAnchor,$defaultAnchor+"`r`n        # HUYMAIER_V0304_MODEL_DEFAULT_CONFIG_V1`r`n        PlatformModelDefaultViews = @()")

    $loadAnchor="'PlatformBackgroundsEnabled','FavoriteGames','RecompGames')) {"
    if(-not$core.Contains($loadAnchor)){throw 'Model-default config could not find transformed load whitelist.'}
    $core=$core.Replace($loadAnchor,"'PlatformBackgroundsEnabled','FavoriteGames','RecompGames','PlatformModelDefaultViews')) {")

    $arrayAnchor="'ProviderInstallRoots','FavoriteGames','RecompGames')) {"
    if(-not$core.Contains($arrayAnchor)){throw 'Model-default config could not find transformed stable-array whitelist.'}
    $core=$core.Replace($arrayAnchor,"'ProviderInstallRoots','FavoriteGames','RecompGames','PlatformModelDefaultViews')) {")
}
if($core -notmatch 'HUYMAIER_V0304_MODEL_DEFAULT_RUNTIME_LOAD_V1'){
    $pathAnchor='$script:ManualRecompsFinalModulePath = Join-Path $script:BaseDir ''HuymaierRecompsFinal.ps1'''
    if(-not$core.Contains($pathAnchor)){throw 'Model-default runtime requires final Recomps module path first.'}
    $core=$core.Replace($pathAnchor,$pathAnchor+"`r`n`$script:ModelDefaultsModulePath = Join-Path `$script:BaseDir 'HuymaierModelDefaults.ps1'")

    $loadAnchor=@'
if (Test-Path -LiteralPath $script:ManualRecompsFinalModulePath) {
    try { . $script:ManualRecompsFinalModulePath }
    catch { Write-Log "Final manual Recomps ownership load failed: $($_.Exception.Message)" 'ERROR' }
}
'@
    if(-not$core.Contains($loadAnchor)){throw 'Model-default runtime could not find final Recomps load block.'}
    $loadBlock=$loadAnchor+@'

# HUYMAIER_V0304_MODEL_DEFAULT_RUNTIME_LOAD_V1
# Final viewer/shelf orientation wrapper. It loads after GPU shelves and provider
# ownership wrappers so model editing cannot disturb platform routing.
if (Test-Path -LiteralPath $script:ModelDefaultsModulePath) {
    try { . $script:ModelDefaultsModulePath }
    catch { Write-Log "3D model default-orientation module load failed: $($_.Exception.Message)" 'ERROR' }
}
'@
    $core=$core.Replace($loadAnchor,$loadBlock)
}
Set-Content -LiteralPath $CorePath -Value $core -Encoding UTF8

$bootstrap=Get-Content -Raw -LiteralPath $BootstrapPath -Encoding UTF8
if($bootstrap -notmatch 'HUYMAIER_V0304_MODEL_DEFAULT_PREFLIGHT_V1'){
    $pathAnchor='$finalRecompsPath=Join-Path $baseDir ''HuymaierRecompsFinal.ps1'''
    if(-not$bootstrap.Contains($pathAnchor)){throw 'Model-default preflight requires final Recomps path first.'}
    $bootstrap=$bootstrap.Replace($pathAnchor,$pathAnchor+"`r`n# HUYMAIER_V0304_MODEL_DEFAULT_PREFLIGHT_V1`r`n`$modelDefaultsPath=Join-Path `$baseDir 'HuymaierModelDefaults.ps1'")
    $entryAnchor="        [pscustomobject]@{Path=`$finalRecompsPath;Label='Manual Recomps final ownership runtime'},"
    if(-not$bootstrap.Contains($entryAnchor)){throw 'Model-default preflight could not find final Recomps entry.'}
    $bootstrap=$bootstrap.Replace($entryAnchor,$entryAnchor+"`r`n        [pscustomobject]@{Path=`$modelDefaultsPath;Label='3D model default-orientation editor runtime'},")
}
Set-Content -LiteralPath $BootstrapPath -Value $bootstrap -Encoding UTF8

$installer=Get-Content -Raw -LiteralPath $InstallerScriptPath -Encoding UTF8
if($installer -notmatch 'HUYMAIER_V0304_MODEL_DEFAULT_INSTALLER_CACHE_V1'){
    $entryAnchor="            'HuymaierRecompsFinal.ps1',"
    if(-not$installer.Contains($entryAnchor)){throw 'Model-default installer cache requires final Recomps entry.'}
    $installer=$installer.Replace($entryAnchor,$entryAnchor+"`r`n            # HUYMAIER_V0304_MODEL_DEFAULT_INSTALLER_CACHE_V1`r`n            'HuymaierModelDefaults.ps1',")
}
Set-Content -LiteralPath $InstallerScriptPath -Value $installer -Encoding UTF8

$native=Get-Content -Raw -LiteralPath $NativeRuntimePath -Encoding UTF8
if($native -notmatch 'HUYMAIER_V0304_MODEL_DEFAULT_ORIENTATION_V1'){
    $old='        const float yaw=24.0f+(item.spin?phase*16.0f:0.0f)+static_cast<float>((item.id*11)%360)+item.yawOffset;'
    $new="        // HUYMAIER_V0304_MODEL_DEFAULT_ORIENTATION_V1`r`n        // Per-model saved yaw must mean the same thing in the shelf and full viewer.`r`n        // Do not add an action-index-derived rotation; shelf ordering is not model orientation.`r`n        const float yaw=24.0f+(item.spin?phase*16.0f:0.0f)+item.yawOffset;"
    if(-not$native.Contains($old)){throw 'Model-default native yaw anchor is missing.'}
    $native=$native.Replace($old,$new)
}
Set-Content -LiteralPath $NativeRuntimePath -Value $native -Encoding UTF8

Write-Host 'Applied v0.30.4 per-model default orientation editor and stable shelf/viewer yaw semantics.'
