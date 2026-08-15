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

# The finished 3D Models option must ship real geometry. The atlas is fallback
# only and cannot satisfy these gates.
$liveDir=Join-Path $StageRoot 'Assets\Models\Live'
if(-not(Test-Path -LiteralPath $liveDir -PathType Container)){throw 'Staged candidate is missing Assets\Models\Live.'}
$frameNames=@($map.atlas.frames.PSObject.Properties|ForEach-Object{[string]$_.Name}|Sort-Object)
if($frameNames.Count -ne 50){throw "Model map exposes $($frameNames.Count) frames instead of 50."}
$stagedGlbs=@(Get-ChildItem -LiteralPath $liveDir -Filter '*.glb' -File)
if($stagedGlbs.Count -ne 50){throw "Staged candidate contains $($stagedGlbs.Count) live GLBs instead of 50."}
foreach($frame in $frameNames){
    $path=Join-Path $liveDir ($frame+'.glb')
    if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "Staged live GLB missing for map frame: $frame"}
    $bytes=[IO.File]::ReadAllBytes($path)
    if($bytes.Length -lt 256 -or $bytes[0]-ne0x67 -or $bytes[1]-ne0x6c -or $bytes[2]-ne0x54 -or $bytes[3]-ne0x46){throw "Staged live GLB header invalid: $frame"}
}

Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Xaml,System.Web.Extensions
Add-Type -Path (Join-Path $StageRoot 'HuymaierLiveModel3D.dll')
foreach($frame in $frameNames){
    $view=New-Object HuymaierConsole.Modeling.LiveModelView -ArgumentList (Join-Path $liveDir ($frame+'.glb'))
    if($null -eq $view){throw "Staged live Viewport3D could not instantiate: $frame"}
    $yaw=[double]$view.Yaw;$zoom=[double]$view.ZoomDistance
    $view.Rotate(2,1);$view.Zoom(.1);$view.SetScalePercent(120)
    if([math]::Abs([double]$view.Yaw-$yaw)-lt .5 -or [math]::Abs([double]$view.ZoomDistance-$zoom)-lt .05){throw "Staged live model interaction failed: $frame"}
}

$validation=Get-Content -Raw -LiteralPath $ValidationPath -Encoding UTF8|ConvertFrom-Json
foreach($gate in @('platformModelSettingGate','platformModelPersistenceGate','platformModelScaleGate','platformModelMapCoverageGate','platformModelWorkerX64Gate','platformModelLiveViewport3DGate','platformModelViewerControlGate','platformModelAtlasFallbackGate','platformModelBuiltInGlbCountGate','platformModelBuiltInGlbLoadGate','platformModelBuiltInInteractiveGate')){$validation|Add-Member -NotePropertyName $gate -NotePropertyValue 'success' -Force}
$validation|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $ValidationPath -Encoding UTF8
foreach($gate in @('platformModelSettingGate','platformModelPersistenceGate','platformModelScaleGate','platformModelMapCoverageGate','platformModelWorkerX64Gate','platformModelLiveViewport3DGate','platformModelViewerControlGate','platformModelAtlasFallbackGate','platformModelBuiltInGlbCountGate','platformModelBuiltInGlbLoadGate','platformModelBuiltInInteractiveGate')){Write-Host ($gate+': success')}
