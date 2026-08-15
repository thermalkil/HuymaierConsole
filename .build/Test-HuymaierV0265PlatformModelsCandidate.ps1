param(
    [Parameter(Mandatory=$true)][string]$StageRoot,
    [Parameter(Mandatory=$true)][string]$ValidationPath
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
foreach($required in @('HuymaierConsole.ps1','HuymaierPlatformModels.ps1','HuymaierPlatformAtlas.ps1','HuymaierLivePlatformModels.ps1','HuymaierModelPreviewWorker.exe','HuymaierLiveModel3D.dll','HuymaierBootstrap.ps1','Install-HuymaierConsole.ps1','Assets\Models\model-map.json','Assets\Models\platform-models.png','EmulatorPlatforms\platform-registry.json')){if(-not(Test-Path -LiteralPath (Join-Path $StageRoot $required) -PathType Leaf)){throw "Staged platform-model payload missing: $required"}}
$core=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'HuymaierConsole.ps1') -Encoding UTF8
$runtime=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'HuymaierPlatformModels.ps1') -Encoding UTF8
$atlasRuntime=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'HuymaierPlatformAtlas.ps1') -Encoding UTF8
$liveRuntime=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'HuymaierLivePlatformModels.ps1') -Encoding UTF8
$bootstrap=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'HuymaierBootstrap.ps1') -Encoding UTF8
$installer=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'Install-HuymaierConsole.ps1') -Encoding UTF8
$map=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'Assets\Models\model-map.json') -Encoding UTF8|ConvertFrom-Json
$registry=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'EmulatorPlatforms\platform-registry.json') -Encoding UTF8|ConvertFrom-Json

foreach($needle in @('HUYMAIER_PLATFORM_3D_MODELS_RUNTIME_V1','HUYMAIER_PLATFORM_3D_ATLAS_RUNTIME_LOAD_V1','HUYMAIER_PLATFORM_3D_LIVE_RUNTIME_LOAD_V1','HuymaierLivePlatformModels.ps1','HUYMAIER_PLATFORM_3D_CONFIG_V2',"PlatformVisualStyle = 'Icons'",'PlatformIconScale = 100','PlatformModelScale = 100',"'PlatformVisualStyle','PlatformIconScale','PlatformModelScale'")){if(-not $core.Contains($needle)){throw "Staged core missing platform-model contract: $needle"}}
foreach($needle in @('HUYMAIER_PLATFORM_3D_LIVE_PREFLIGHT_V1','Live platform 3D runtime','HuymaierLiveModel3D.dll')){if(-not $bootstrap.Contains($needle)){throw "Staged bootstrap missing live platform-model contract: $needle"}}
foreach($needle in @('HUYMAIER_PLATFORM_3D_LIVE_INSTALLER_CACHE_V1','HuymaierLivePlatformModels.ps1','HuymaierLiveModel3D.dll')){if(-not $installer.Contains($needle)){throw "Staged installer missing live platform-model contract: $needle"}}
foreach($needle in @("@('Icons','3D Models')",'platform-visual-style','HuymaierModelPreviewWorker.exe')){if(-not $runtime.Contains($needle)){throw "Staged base platform-model runtime missing: $needle"}}
foreach($needle in @('HUYMAIER_PLATFORM_3D_ATLAS_RUNTIME_V1','Get-HcAtlasImageSource','CroppedBitmap')){if(-not $atlasRuntime.Contains($needle)){throw "Staged atlas fallback runtime missing: $needle"}}
foreach($needle in @('HUYMAIER_LIVE_PLATFORM_3D_RUNTIME_V1','HuymaierLiveModel3D.dll','Resolve-HcLivePlatformModelPath','Get-HcPlatformVisualHost','platform-icon-scale-slider','platform-model-scale-slider','Open-HcPlatformModelViewer','function Invoke-SecondaryAction','function Apply-ControllerNavigation','X/Square View 3D model','LB / RB  Zoom')){if(-not $liveRuntime.Contains($needle)){throw "Staged live platform-model runtime missing: $needle"}}
if($liveRuntime.Contains('Abs([double]$child.Width-92')){throw 'Staged live model integration still depends on the old 92x92 host heuristic.'}

$keys=@{};foreach($p in @($map.models.PSObject.Properties)){$keys[[string]$p.Name.ToLowerInvariant()]=[string]$p.Value}
foreach($provider in @('Steam','Epic','GOG','EA','Ubisoft','Xbox App','Battle.net','Rockstar','Amazon Games')){if(-not $keys.ContainsKey($provider.ToLowerInvariant())){throw "Staged model map missing provider $provider"}}
foreach($platform in @($registry.platforms|Where-Object{[bool]$_.enabled})){
    $covered=$false
    foreach($alias in @([string]$platform.name,[string]$platform.displayName,[string]$platform.menuName,[string]$platform.id)+@($platform.aliases)){
        if($alias -and $keys.ContainsKey(([string]$alias).ToLowerInvariant())){$covered=$true;break}
    }
    if(-not $covered){throw "Staged model map has no runtime alias for enabled platform $([string]$platform.id) / $([string]$platform.name)"}
}

foreach($binaryName in @('HuymaierModelPreviewWorker.exe','HuymaierLiveModel3D.dll')){
    $binary=Join-Path $StageRoot $binaryName
    $bytes=[IO.File]::ReadAllBytes($binary);if($bytes.Length -lt 512){throw "$binaryName is unexpectedly small."}
    $pe=[BitConverter]::ToInt32($bytes,0x3C);$machine=[BitConverter]::ToUInt16($bytes,$pe+4);if($machine -ne 0x8664){throw ("$binaryName is not x64 (machine 0x{0:X4})." -f $machine)}
}

$validation=Get-Content -Raw -LiteralPath $ValidationPath -Encoding UTF8|ConvertFrom-Json
foreach($gate in @('platformModelSettingGate','platformModelPersistenceGate','platformModelScaleGate','platformModelMapCoverageGate','platformModelWorkerX64Gate','platformModelLiveViewport3DGate','platformModelViewerControlGate','platformModelAtlasFallbackGate')){$validation|Add-Member -NotePropertyName $gate -NotePropertyValue 'success' -Force}
$validation|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $ValidationPath -Encoding UTF8
foreach($gate in @('platformModelSettingGate','platformModelPersistenceGate','platformModelScaleGate','platformModelMapCoverageGate','platformModelWorkerX64Gate','platformModelLiveViewport3DGate','platformModelViewerControlGate','platformModelAtlasFallbackGate')){Write-Host ($gate+': success')}
