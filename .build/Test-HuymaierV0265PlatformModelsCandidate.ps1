param(
    [Parameter(Mandatory=$true)][string]$StageRoot,
    [Parameter(Mandatory=$true)][string]$ValidationPath
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
foreach($required in @('HuymaierConsole.ps1','HuymaierPlatformModels.ps1','HuymaierPlatformAtlas.ps1','HuymaierLivePlatformModels.ps1','HuymaierUser3DModels.ps1','HuymaierModelPreviewWorker.exe','HuymaierLiveModel3D.dll','HuymaierBootstrap.ps1','Install-HuymaierConsole.ps1','Assets\Models\model-map.json','Assets\Models\platform-models.png','EmulatorPlatforms\platform-registry.json')){if(-not(Test-Path -LiteralPath (Join-Path $StageRoot $required) -PathType Leaf)){throw "Staged platform-model payload missing: $required"}}
$core=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'HuymaierConsole.ps1') -Encoding UTF8
$runtime=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'HuymaierPlatformModels.ps1') -Encoding UTF8
$atlasRuntime=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'HuymaierPlatformAtlas.ps1') -Encoding UTF8
$liveRuntime=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'HuymaierLivePlatformModels.ps1') -Encoding UTF8
$userRuntime=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'HuymaierUser3DModels.ps1') -Encoding UTF8
$bootstrap=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'HuymaierBootstrap.ps1') -Encoding UTF8
$installer=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'Install-HuymaierConsole.ps1') -Encoding UTF8
$map=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'Assets\Models\model-map.json') -Encoding UTF8|ConvertFrom-Json
$registry=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'EmulatorPlatforms\platform-registry.json') -Encoding UTF8|ConvertFrom-Json

foreach($needle in @('HUYMAIER_PLATFORM_3D_MODELS_RUNTIME_V1','HUYMAIER_PLATFORM_3D_ATLAS_RUNTIME_LOAD_V1','HUYMAIER_PLATFORM_3D_LIVE_RUNTIME_LOAD_V1','HUYMAIER_USER_3D_MODELS_RUNTIME_LOAD_V1','HuymaierUser3DModels.ps1','HUYMAIER_PLATFORM_3D_CONFIG_V2',"PlatformVisualStyle = 'Icons'",'PlatformIconScale = 100','PlatformModelScale = 100',"'PlatformVisualStyle','PlatformIconScale','PlatformModelScale'")){if(-not $core.Contains($needle)){throw "Staged core missing platform-model contract: $needle"}}
foreach($needle in @('HUYMAIER_PLATFORM_3D_LIVE_PREFLIGHT_V1','HUYMAIER_USER_3D_MODELS_PREFLIGHT_V1','HuymaierUser3DModels.ps1','HuymaierLiveModel3D.dll')){if(-not $bootstrap.Contains($needle)){throw "Staged bootstrap missing user/live platform-model contract: $needle"}}
foreach($needle in @('HUYMAIER_PLATFORM_3D_LIVE_INSTALLER_CACHE_V1','HUYMAIER_USER_3D_MODELS_INSTALLER_CACHE_V1','HuymaierUser3DModels.ps1','HuymaierLiveModel3D.dll')){if(-not $installer.Contains($needle)){throw "Staged installer missing user/live platform-model contract: $needle"}}
foreach($needle in @("@('Icons','3D Models')",'platform-visual-style')){if(-not $runtime.Contains($needle)){throw "Staged base platform-model runtime missing: $needle"}}
foreach($needle in @('HUYMAIER_LIVE_PLATFORM_3D_RUNTIME_V1','HuymaierLiveModel3D.dll','Get-HcPlatformVisualHost','Open-HcPlatformModelViewer','function Invoke-SecondaryAction','function Apply-ControllerNavigation','X/Square View 3D model','LB / RB  Zoom')){if(-not $liveRuntime.Contains($needle)){throw "Staged live platform-model runtime missing: $needle"}}
foreach($needle in @('HUYMAIER_USER_3D_MODELS_RUNTIME_V2',"Join-Path `$script:DataDir '3D Models'",'README - Model Names.txt','Get-HcDetectedUser3DModelCount',"`$script:SubPage -ne 'Customization'",'Icon card size','3D model size','3D Models Folder — ','Missing GLBs use the normal icon','Start from the original icon card every time','HcLiveModelCard')){if(-not $userRuntime.Contains($needle)){throw "Staged user 3D Models runtime missing: $needle"}}
if($userRuntime.Contains('Set-HcAtlasFallbackVisual')){throw 'Final user 3D Models layer still references static atlas fallback.'}

$expectedNames=@('Arcade.glb','Atari 2600.glb','Atari Lynx.glb','Epic Games.glb','Neo Geo Pocket Color.glb','Neo Geo.glb','Nintendo 3DS.glb','Nintendo 64.glb','Nintendo DS.glb','Nintendo DSI.glb','Nintendo Entertainment System.glb','Nintendo Game Boy Advance.glb','Nintendo Game Boy Color.glb','Nintendo Game Boy.glb','Nintendo GameCube.glb','Nintendo Switch.glb','Nintendo Wii U.glb','Nintendo Wii.glb','PlayStation 2.glb','PlayStation 3.glb','Playstation 4.glb','Playstation 5.glb','Sega Dreamcast.glb','Sega Genesis.glb','Sega Logo.glb','Sega Master System.glb','Sega Mega Drive.glb','Sega Saturn.glb','Sony Playstation Portable.glb','Sony Playstation Vita.glb','Sony PlayStation.glb','Steam.glb','Super Nintendo Entertainment System.glb','XBOX 360.glb','Xbox One.glb','Xbox.glb')
foreach($name in $expectedNames){if(-not $userRuntime.Contains("'$name'")){throw "Staged user-model filename guide missing: $name"}}
if($expectedNames.Count -ne 36){throw 'Original user-model filename contract must remain 36 names.'}

$keys=@{};foreach($p in @($map.models.PSObject.Properties)){$keys[[string]$p.Name.ToLowerInvariant()]=[string]$p.Value}
foreach($platform in @($registry.platforms|Where-Object{[bool]$_.enabled})){
    $covered=$false
    foreach($alias in @([string]$platform.name,[string]$platform.displayName,[string]$platform.menuName,[string]$platform.id)+@($platform.aliases)){
        if($alias -and $keys.ContainsKey(([string]$alias).ToLowerInvariant())){$covered=$true;break}
    }
    if(-not $covered){throw "Staged model map has no alias for enabled platform $([string]$platform.id) / $([string]$platform.name)"}
}

foreach($binaryName in @('HuymaierModelPreviewWorker.exe','HuymaierLiveModel3D.dll')){
    $binary=Join-Path $StageRoot $binaryName
    $bytes=[IO.File]::ReadAllBytes($binary);if($bytes.Length -lt 512){throw "$binaryName is unexpectedly small."}
    $pe=[BitConverter]::ToInt32($bytes,0x3C);$machine=[BitConverter]::ToUInt16($bytes,$pe+4);if($machine -ne 0x8664){throw ("$binaryName is not x64 (machine 0x{0:X4})." -f $machine)}
}

# Normal releases must no longer bundle the large model pack.
$bundledGlbs=@(Get-ChildItem -LiteralPath (Join-Path $StageRoot 'Assets\Models') -Filter '*.glb' -File -Recurse -ErrorAction SilentlyContinue)
if($bundledGlbs.Count -ne 0){throw "Candidate unexpectedly bundles $($bundledGlbs.Count) GLB file(s). User models must live outside the release payload."}

# Prove the staged DLL still renders real geometry without bundling a model.
function New-HcTinyGlb {
    param([string]$Path)
    $json='{"asset":{"version":"2.0"},"scene":0,"scenes":[{"nodes":[0]}],"nodes":[{"mesh":0}],"meshes":[{"primitives":[{"attributes":{"POSITION":0},"indices":1,"mode":4,"material":0}]}],"materials":[{"pbrMetallicRoughness":{"baseColorFactor":[0.84,0.55,0.18,1],"metallicFactor":0.15,"roughnessFactor":0.55}}],"buffers":[{"byteLength":44}],"bufferViews":[{"buffer":0,"byteOffset":0,"byteLength":36},{"buffer":0,"byteOffset":36,"byteLength":6}],"accessors":[{"bufferView":0,"componentType":5126,"count":3,"type":"VEC3","min":[-0.8,-0.6,0],"max":[0.8,0.8,0]},{"bufferView":1,"componentType":5123,"count":3,"type":"SCALAR","min":[0],"max":[2]}]}'
    $jsonBytes=[Text.Encoding]::UTF8.GetBytes($json);$jsonPad=(4-($jsonBytes.Length%4))%4;$jsonChunk=New-Object byte[] ($jsonBytes.Length+$jsonPad);[Array]::Copy($jsonBytes,$jsonChunk,$jsonBytes.Length);for($i=$jsonBytes.Length;$i-lt$jsonChunk.Length;$i++){$jsonChunk[$i]=0x20}
    $binStream=New-Object IO.MemoryStream;$bw=New-Object IO.BinaryWriter($binStream);foreach($f in @([single]-0.8,[single]-0.6,[single]0,[single]0.8,[single]-0.6,[single]0,[single]0,[single]0.8,[single]0)){$bw.Write($f)};foreach($ix in @([uint16]0,[uint16]1,[uint16]2)){$bw.Write($ix)};$bw.Write([uint16]0);$bw.Flush();$bin=$binStream.ToArray();$bw.Dispose();$binStream.Dispose()
    $total=12+8+$jsonChunk.Length+8+$bin.Length;$fs=[IO.File]::Create($Path);$out=New-Object IO.BinaryWriter($fs);try{$out.Write([byte[]](0x67,0x6C,0x54,0x46));$out.Write([uint32]2);$out.Write([uint32]$total);$out.Write([uint32]$jsonChunk.Length);$out.Write([uint32]0x4E4F534A);$out.Write($jsonChunk);$out.Write([uint32]$bin.Length);$out.Write([uint32]0x004E4942);$out.Write($bin)}finally{$out.Dispose();$fs.Dispose()}
}
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Xaml,System.Web.Extensions
Add-Type -Path (Join-Path $StageRoot 'HuymaierLiveModel3D.dll')
$temp=Join-Path ([IO.Path]::GetTempPath()) ('hc-user-model-'+[guid]::NewGuid().ToString('N')+'.glb')
try{
    New-HcTinyGlb $temp
    $view=New-Object HuymaierConsole.Modeling.LiveModelView -ArgumentList $temp
    $yaw=[double]$view.Yaw;$zoom=[double]$view.ZoomDistance
    $view.Rotate(5,3);$view.Zoom(.2);$view.SetScalePercent(130)
    if([math]::Abs([double]$view.Yaw-$yaw)-lt .5 -or [math]::Abs([double]$view.ZoomDistance-$zoom)-lt .05){throw 'Staged live user-model interaction smoke test failed.'}
}finally{Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue}

$validation=Get-Content -Raw -LiteralPath $ValidationPath -Encoding UTF8|ConvertFrom-Json
foreach($gate in @('platformModelSettingGate','platformModelPersistenceGate','platformModelScaleGate','platformModelMapCoverageGate','platformModelWorkerX64Gate','platformModelLiveViewport3DGate','platformModelViewerControlGate','platformModelUserFolderGate','platformModelOriginalNamingGate','platformModelCustomizationOnlyGate','platformModelIconFallbackOnlyGate','platformModelNoBundledGlbGate')){$validation|Add-Member -NotePropertyName $gate -NotePropertyValue 'success' -Force}
$validation|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $ValidationPath -Encoding UTF8
foreach($gate in @('platformModelSettingGate','platformModelPersistenceGate','platformModelScaleGate','platformModelMapCoverageGate','platformModelWorkerX64Gate','platformModelLiveViewport3DGate','platformModelViewerControlGate','platformModelUserFolderGate','platformModelOriginalNamingGate','platformModelCustomizationOnlyGate','platformModelIconFallbackOnlyGate','platformModelNoBundledGlbGate')){Write-Host ($gate+': success')}
