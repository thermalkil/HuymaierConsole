Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$repoRoot=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$runtime=Join-Path $repoRoot 'HuymaierModelDefaults.ps1'
$optimizer=Join-Path $repoRoot '.build\Optimize-ModelDefaultViews.ps1'
foreach($path in @($runtime,$optimizer)){if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "Missing v0.30.4 source: $path"}}

foreach($path in @($runtime,$optimizer)){
    $tokens=$null;$errors=$null
    [void][Management.Automation.Language.Parser]::ParseFile($path,[ref]$tokens,[ref]$errors)
    if($errors.Count){throw ((@($errors|ForEach-Object{$_.Message})) -join '; ')}
}
$runtimeText=Get-Content -Raw -LiteralPath $runtime -Encoding UTF8
foreach($needle in @(
    'HUYMAIER_V0304_MODEL_DEFAULT_ORIENTATION_EDITOR_V1',
    'PlatformModelDefaultViews',
    'function Enter-HcModelOrientationEditor',
    'function Save-HcModelOrientationEditor',
    'function Reset-HcModelOrientationEditor',
    "Content='EDIT MODEL'",
    'X/Square Edit Model',
    'A/Cross Save Default',
    'Y/Triangle Reset Default',
    'Get-HcModelDefaultViewKey',
    'SetItemView([int]$card.ActionIndex',
    'Is-NewButtonPress $Mask 16',
    'Is-NewButtonPress $Mask 32'
)){
    if(-not$runtimeText.Contains($needle)){throw "Model orientation runtime is missing contract: $needle"}
}
Write-Host 'modelDefaultEditorUiGate: success'
Write-Host 'modelDefaultControllerGate: success'
Write-Host 'modelDefaultShelfApplyGate: success'

$temp=Join-Path $env:TEMP ('hc-v0304-model-defaults-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $temp|Out-Null
try{
    $core=Join-Path $temp 'HuymaierConsole.ps1'
    $bootstrap=Join-Path $temp 'HuymaierBootstrap.ps1'
    $installer=Join-Path $temp 'Install-HuymaierConsole.ps1'
    $native=Join-Path $temp 'HuymaierD3D11ShelfRuntime.cpp'
    @'
function New-DefaultConfig {
    [pscustomobject]@{
        RecompGames = @()
    }
}
foreach ($name in @('PlatformBackgroundsEnabled','FavoriteGames','RecompGames')) {
}
foreach ($collectionName in @('ProviderInstallRoots','FavoriteGames','RecompGames')) {
}
$script:ManualRecompsFinalModulePath = Join-Path $script:BaseDir 'HuymaierRecompsFinal.ps1'
if (Test-Path -LiteralPath $script:ManualRecompsFinalModulePath) {
    try { . $script:ManualRecompsFinalModulePath }
    catch { Write-Log "Final manual Recomps ownership load failed: $($_.Exception.Message)" 'ERROR' }
}
'@|Set-Content -LiteralPath $core -Encoding UTF8
    @'
$finalRecompsPath=Join-Path $baseDir 'HuymaierRecompsFinal.ps1'
        [pscustomobject]@{Path=$finalRecompsPath;Label='Manual Recomps final ownership runtime'},
'@|Set-Content -LiteralPath $bootstrap -Encoding UTF8
    @'
            'HuymaierRecompsFinal.ps1',
'@|Set-Content -LiteralPath $installer -Encoding UTF8
    @'
        const float yaw=24.0f+(item.spin?phase*16.0f:0.0f)+static_cast<float>((item.id*11)%360)+item.yawOffset;
'@|Set-Content -LiteralPath $native -Encoding UTF8

    & $optimizer -CorePath $core -BootstrapPath $bootstrap -InstallerScriptPath $installer -NativeRuntimePath $native
    $coreText=Get-Content -Raw $core;$bootstrapText=Get-Content -Raw $bootstrap;$installerText=Get-Content -Raw $installer;$nativeText=Get-Content -Raw $native
    foreach($needle in @('HUYMAIER_V0304_MODEL_DEFAULT_CONFIG_V1','PlatformModelDefaultViews','HUYMAIER_V0304_MODEL_DEFAULT_RUNTIME_LOAD_V1','HuymaierModelDefaults.ps1')){if(-not$coreText.Contains($needle)){throw "Transformed core missing $needle"}}
    if(-not$bootstrapText.Contains('HUYMAIER_V0304_MODEL_DEFAULT_PREFLIGHT_V1')){throw 'Model-default bootstrap preflight transform missing.'}
    if(-not$installerText.Contains('HUYMAIER_V0304_MODEL_DEFAULT_INSTALLER_CACHE_V1')){throw 'Model-default installer cache transform missing.'}
    if(-not$nativeText.Contains('HUYMAIER_V0304_MODEL_DEFAULT_ORIENTATION_V1')){throw 'Stable model yaw transform missing.'}
    if($nativeText.Contains('static_cast<float>((item.id*11)%360)')){throw 'Action-index-derived model yaw survived v0.30.4 transform.'}
    Write-Host 'modelDefaultPersistenceTransformGate: success'
    Write-Host 'modelDefaultStableYawGate: success'
}
finally{Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue}

Write-Host 'modelDefaultPs51ParseGate: success'
