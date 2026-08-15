Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$module=Join-Path $root 'HuymaierPlatformModels.ps1'
$atlasModule=Join-Path $root 'HuymaierPlatformAtlas.ps1'
$liveModule=Join-Path $root 'HuymaierLivePlatformModels.ps1'
$worker=Join-Path $root 'Native\HuymaierModelPreviewWorker.cs'
$aliases=Join-Path $root 'Native\HuymaierModelPreviewWpfAliases.cs'
$liveControl=Join-Path $root 'Native\HuymaierLiveModelControl.cs'
$optimizer=Join-Path $root '.build\Optimize-Platform3DModels.ps1'
$modelMap=Join-Path $root 'Assets\Models\model-map.json'
$atlasParts=@(1..4|ForEach-Object{Join-Path $root ('.development\v0.26.5\platform-model-atlas.part{0:D2}.b64' -f $_)})
foreach($p in @($module,$atlasModule,$liveModule,$worker,$aliases,$liveControl,$optimizer,$modelMap)+$atlasParts){if(-not(Test-Path -LiteralPath $p -PathType Leaf)){throw "Platform-model source is missing: $p"}}

foreach($ps in @($module,$atlasModule,$liveModule,$optimizer)){
    $tokens=$null;$errors=$null
    [void][Management.Automation.Language.Parser]::ParseFile($ps,[ref]$tokens,[ref]$errors)
    if(@($errors).Count){throw "$ps failed Windows PowerShell 5.1 parse: $(@($errors|ForEach-Object{$_.Message}) -join '; ')"}
}

$moduleText=Get-Content -Raw -LiteralPath $module -Encoding UTF8
$atlasText=Get-Content -Raw -LiteralPath $atlasModule -Encoding UTF8
$liveText=Get-Content -Raw -LiteralPath $liveModule -Encoding UTF8
$controlText=Get-Content -Raw -LiteralPath $liveControl -Encoding UTF8
foreach($needle in @('PlatformVisualStyle',"@('Icons','3D Models')",'HuymaierModelPreviewWorker.exe','function New-PlatformCard',"'platform-visual-style'",'Request-HcModelPreview')){if(-not $moduleText.Contains($needle)){throw "Platform-model runtime contract missing: $needle"}}
foreach($needle in @('HUYMAIER_PLATFORM_3D_ATLAS_RUNTIME_V1','Get-HcAtlasImageSource','CroppedBitmap','atlas:','function New-PlatformCard')){if(-not $atlasText.Contains($needle)){throw "Platform-model atlas fallback contract missing: $needle"}}
foreach($needle in @('HUYMAIER_LIVE_PLATFORM_3D_RUNTIME_V1','HuymaierLiveModel3D.dll','Resolve-HcLivePlatformModelPath','Get-HcPlatformVisualHost','PlatformIconScale','PlatformModelScale','platform-icon-scale-slider','platform-model-scale-slider','Open-HcPlatformModelViewer','Close-HcPlatformModelViewer','function Invoke-SecondaryAction','function Apply-ControllerNavigation','X/Square View 3D model','LB / RB  Zoom')){if(-not $liveText.Contains($needle)){throw "Live platform-model runtime contract missing: $needle"}}
foreach($needle in @('public sealed class LiveModelView','Viewport3D','GlbLoader.Read','GlbLoader.BuildScene','SetScalePercent','Rotate(double yawDelta','Zoom(double delta)','ResetView')){if(-not $controlText.Contains($needle)){throw "Live Viewport3D control contract missing: $needle"}}
if($liveText.Contains('Abs([double]$child.Width-92')){throw 'Live model card integration must not use the old 92x92 size heuristic.'}
if(($moduleText+$atlasText+$liveText) -match '(?i)Remove-Item.+PS[123]|PlayStationPresentation'){throw 'Platform-model runtime must not mutate frozen PlayStation presentation.'}

$map=Get-Content -Raw -LiteralPath $modelMap -Encoding UTF8|ConvertFrom-Json
if([int]$map.schemaVersion -ne 2){throw '3D model map schema version must be 2.'}
if([string]$map.runtimeFormat -ne 'transparent-png-atlas'){throw '3D model map must preserve the transparent PNG atlas as fallback.'}
if([string]$map.atlas.file -ne 'platform-models.png' -or [int]$map.atlas.cellWidth -ne 128 -or [int]$map.atlas.cellHeight -ne 107 -or [int]$map.atlas.columns -ne 10 -or [int]$map.atlas.rows -ne 5){throw '3D model atlas geometry contract changed unexpectedly.'}
$frames=@{};foreach($p in @($map.atlas.frames.PSObject.Properties)){$frames[[string]$p.Name.ToLowerInvariant()]=[int]$p.Value}
if($frames.Count -ne 50){throw "3D model atlas must expose exactly 50 fallback frames; found $($frames.Count)."}
$keys=@{};foreach($p in @($map.models.PSObject.Properties)){$keys[[string]$p.Name.ToLowerInvariant()]=[string]$p.Value}
foreach($provider in @('Steam','Epic','GOG','EA','Ubisoft','Xbox App','Battle.net','Rockstar','Amazon Games')){if(-not $keys.ContainsKey($provider.ToLowerInvariant())){throw "3D model map is missing provider: $provider"}}
foreach($value in @($keys.Values|Select-Object -Unique)){
    if(-not ([string]$value).StartsWith('atlas:',[StringComparison]::OrdinalIgnoreCase)){throw "Fallback model map must resolve to atlas frames: $value"}
    $frame=([string]$value).Substring(6).ToLowerInvariant();if(-not $frames.ContainsKey($frame)){throw "Model map references missing atlas frame: $frame"}
}
$registry=Get-Content -Raw -LiteralPath (Join-Path $root 'EmulatorPlatforms\platform-registry.json') -Encoding UTF8|ConvertFrom-Json
foreach($platform in @($registry.platforms|Where-Object{[bool]$_.enabled})){
    $covered=$false
    foreach($value in @([string]$platform.name,[string]$platform.displayName,[string]$platform.menuName,[string]$platform.id)+@($platform.aliases)){
        if($value -and $keys.ContainsKey(([string]$value).ToLowerInvariant())){$covered=$true;break}
    }
    if(-not $covered){throw "3D model map has no alias for enabled platform $([string]$platform.id) / $([string]$platform.name)"}
}
foreach($source in @('Steam','Epic Games','PS1','PS2','PS3','GameCube','Wii','Switch','Original Xbox','Xbox 360')){if($null -eq $map.sourceModels.PSObject.Properties[$source]){throw "Supplied live-model provenance is missing: $source"}}

$atlasBase64=($atlasParts|ForEach-Object{(Get-Content -Raw -LiteralPath $_ -Encoding ASCII).Trim()}) -join ''
$atlasBytes=[Convert]::FromBase64String($atlasBase64)
$hasher=[Security.Cryptography.SHA256]::Create();try{$atlasSha=[BitConverter]::ToString($hasher.ComputeHash($atlasBytes)).Replace('-','').ToLowerInvariant()}finally{$hasher.Dispose()}
if($atlasSha -ne 'fb46ad288c506e2c628f4bf06025deb66af17d26b4fff02baa2950de13d7342f'){throw "3D model atlas source hash mismatch: $atlasSha"}
if($atlasBytes[0] -ne 0x89 -or $atlasBytes[1] -ne 0x50 -or $atlasBytes[2] -ne 0x4e -or $atlasBytes[3] -ne 0x47){throw '3D model atlas source is not PNG.'}
Add-Type -AssemblyName PresentationCore,WindowsBase
$memory=New-Object IO.MemoryStream(,$atlasBytes)
try{$decoder=New-Object System.Windows.Media.Imaging.PngBitmapDecoder($memory,[System.Windows.Media.Imaging.BitmapCreateOptions]::PreservePixelFormat,[System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad);$bitmap=$decoder.Frames[0];if($bitmap.PixelWidth -ne 1280 -or $bitmap.PixelHeight -ne 535){throw "3D model atlas dimensions are $($bitmap.PixelWidth)x$($bitmap.PixelHeight), expected 1280x535."}}finally{$memory.Dispose()}

function New-HcTinyGlb {
    param([string]$Path)
    $json='{"asset":{"version":"2.0"},"scene":0,"scenes":[{"nodes":[0]}],"nodes":[{"mesh":0}],"meshes":[{"primitives":[{"attributes":{"POSITION":0},"indices":1,"mode":4,"material":0}]}],"materials":[{"pbrMetallicRoughness":{"baseColorFactor":[0.84,0.55,0.18,1],"metallicFactor":0.15,"roughnessFactor":0.55}}],"buffers":[{"byteLength":44}],"bufferViews":[{"buffer":0,"byteOffset":0,"byteLength":36},{"buffer":0,"byteOffset":36,"byteLength":6}],"accessors":[{"bufferView":0,"componentType":5126,"count":3,"type":"VEC3","min":[-0.8,-0.6,0],"max":[0.8,0.8,0]},{"bufferView":1,"componentType":5123,"count":3,"type":"SCALAR","min":[0],"max":[2]}]}'
    $jsonBytes=[Text.Encoding]::UTF8.GetBytes($json);$jsonPad=(4-($jsonBytes.Length%4))%4;$jsonChunk=New-Object byte[] ($jsonBytes.Length+$jsonPad);[Array]::Copy($jsonBytes,$jsonChunk,$jsonBytes.Length);for($i=$jsonBytes.Length;$i-lt$jsonChunk.Length;$i++){$jsonChunk[$i]=0x20}
    $binStream=New-Object IO.MemoryStream;$bw=New-Object IO.BinaryWriter($binStream);foreach($f in @([single]-0.8,[single]-0.6,[single]0,[single]0.8,[single]-0.6,[single]0,[single]0,[single]0.8,[single]0)){$bw.Write($f)};foreach($ix in @([uint16]0,[uint16]1,[uint16]2)){$bw.Write($ix)};$bw.Write([uint16]0);$bw.Flush();$bin=$binStream.ToArray();$bw.Dispose();$binStream.Dispose()
    $total=12+8+$jsonChunk.Length+8+$bin.Length;$fs=[IO.File]::Create($Path);$out=New-Object IO.BinaryWriter($fs);try{$out.Write([byte[]](0x67,0x6C,0x54,0x46));$out.Write([uint32]2);$out.Write([uint32]$total);$out.Write([uint32]$jsonChunk.Length);$out.Write([uint32]0x4E4F534A);$out.Write($jsonChunk);$out.Write([uint32]$bin.Length);$out.Write([uint32]0x004E4942);$out.Write($bin)}finally{$out.Dispose();$fs.Dispose()}
}

Add-Type -AssemblyName PresentationFramework,System.Xaml,System.Web.Extensions
$csc=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe';if(-not(Test-Path -LiteralPath $csc -PathType Leaf)){throw 'Framework64 csc.exe was not found.'}
$tempRoot=$(if($env:RUNNER_TEMP){$env:RUNNER_TEMP}else{[IO.Path]::GetTempPath()});$temp=Join-Path $tempRoot ('hc-model-test-'+[guid]::NewGuid().ToString('N'));New-Item -ItemType Directory -Force -Path $temp|Out-Null
try{
    $refs=@([Uri].Assembly.Location,[Linq.Enumerable].Assembly.Location,[Web.Script.Serialization.JavaScriptSerializer].Assembly.Location,[Windows.DependencyObject].Assembly.Location,[Windows.Media.Visual].Assembly.Location,[Windows.Window].Assembly.Location,[System.Xaml.XamlReader].Assembly.Location)|Select-Object -Unique
    $exe=Join-Path $temp 'HuymaierModelPreviewWorker.exe';$args=@('/noconfig','/nologo','/target:winexe','/platform:x64','/optimize+',('/out:'+$exe));foreach($r in $refs){$args+=('/reference:'+$r)};$args+=@($worker,$aliases);& $csc @args
    if($LASTEXITCODE -ne 0 -or -not(Test-Path -LiteralPath $exe -PathType Leaf)){throw 'Platform-model preview worker x64 compile failed.'}
    $dll=Join-Path $temp 'HuymaierLiveModel3D.dll';$args=@('/noconfig','/nologo','/target:library','/platform:x64','/optimize+',('/out:'+$dll));foreach($r in $refs){$args+=('/reference:'+$r)};$args+=@($worker,$aliases,$liveControl);& $csc @args
    if($LASTEXITCODE -ne 0 -or -not(Test-Path -LiteralPath $dll -PathType Leaf)){throw 'Live platform-model x64 DLL compile failed.'}
    foreach($binary in @($exe,$dll)){$bytes=[IO.File]::ReadAllBytes($binary);$pe=[BitConverter]::ToInt32($bytes,0x3C);$machine=[BitConverter]::ToUInt16($bytes,$pe+4);if($machine-ne0x8664){throw "Platform-model binary is not x64: $binary"}}
    $tiny=Join-Path $temp 'tiny.glb';$png=Join-Path $temp 'tiny.png';New-HcTinyGlb $tiny
    $proc=Start-Process -FilePath $exe -ArgumentList ('--model "'+$tiny+'" --output "'+$png+'" --size 128 --yaw 24 --pitch -12') -Wait -PassThru
    if($proc.ExitCode -ne 0 -or -not(Test-Path -LiteralPath $png -PathType Leaf)){throw 'Platform-model custom GLB smoke render failed.'}
    Add-Type -Path $dll
    $view=New-Object HuymaierConsole.Modeling.LiveModelView -ArgumentList $tiny
    $startYaw=[double]$view.Yaw;$startZoom=[double]$view.ZoomDistance
    $view.Rotate(18,7);$view.Zoom(0.5);$view.SetScalePercent(135)
    if([math]::Abs([double]$view.Yaw-$startYaw) -lt 1){throw 'Live Viewport3D rotation did not update.'}
    if([math]::Abs([double]$view.ZoomDistance-$startZoom) -lt .1){throw 'Live Viewport3D zoom did not update.'}

    $core=Join-Path $temp 'HuymaierConsole.ps1';$bootstrap=Join-Path $temp 'HuymaierBootstrap.ps1';$installer=Join-Path $temp 'Install-HuymaierConsole.ps1';$builder=Join-Path $temp 'Build-HuymaierReleaseCandidate.Core.ps1'
    Copy-Item (Join-Path $root 'HuymaierConsole.ps1') $core;Copy-Item (Join-Path $root 'HuymaierBootstrap.ps1') $bootstrap;Copy-Item (Join-Path $root 'Install-HuymaierConsole.ps1') $installer;Copy-Item (Join-Path $root '.build\Build-HuymaierReleaseCandidate.Core.ps1') $builder
    & $optimizer -CorePath $core -BootstrapPath $bootstrap -InstallerScriptPath $installer -CoreBuilderPath $builder
    foreach($ps in @($core,$bootstrap,$installer,$builder)){$tokens=$null;$errors=$null;[void][Management.Automation.Language.Parser]::ParseFile($ps,[ref]$tokens,[ref]$errors);if(@($errors).Count){throw "Transformed platform-model file failed parse: $ps :: $(@($errors|ForEach-Object{$_.Message}) -join '; ')"}}
    $coreText=Get-Content -Raw $core;$bootstrapText=Get-Content -Raw $bootstrap;$installerText=Get-Content -Raw $installer;$builderText=Get-Content -Raw $builder
    foreach($needle in @('HUYMAIER_PLATFORM_3D_CONFIG_V2',"PlatformVisualStyle = 'Icons'",'PlatformIconScale = 100','PlatformModelScale = 100',"'PlatformVisualStyle','PlatformIconScale','PlatformModelScale'",'HUYMAIER_PLATFORM_3D_LIVE_RUNTIME_LOAD_V1','HuymaierLivePlatformModels.ps1')){if(-not $coreText.Contains($needle)){throw "Transformed core persistence/live-load contract missing: $needle"}}
    foreach($needle in @('HUYMAIER_PLATFORM_3D_LIVE_PREFLIGHT_V1','HuymaierLivePlatformModels.ps1','HuymaierLiveModel3D.dll')){if(-not $bootstrapText.Contains($needle)){throw "Bootstrap live-model contract missing: $needle"}}
    foreach($needle in @('HUYMAIER_PLATFORM_3D_LIVE_INSTALLER_CACHE_V1','HuymaierLivePlatformModels.ps1','HuymaierLiveModel3D.dll')){if(-not $installerText.Contains($needle)){throw "Installer live-model contract missing: $needle"}}
    foreach($needle in @('HUYMAIER_PLATFORM_3D_MODEL_WORKER_BUILD_V2','HuymaierLiveModelControl.cs','/target:library','HuymaierLiveModel3D.dll','HuymaierLiveModel3D.dll is not x64')){if(-not $builderText.Contains($needle)){throw "Builder live-model contract missing: $needle"}}
}finally{Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue}

$sources=@(Get-Content (Join-Path $root '.source\source-files.txt') -Encoding UTF8)
foreach($required in @('HuymaierLivePlatformModels.ps1','Native/HuymaierLiveModelControl.cs')){if($sources -notcontains $required){throw "Release source list missing $required"}}

Write-Host 'platformModelSettingGate: success'
Write-Host 'platformModelPersistenceGate: success'
Write-Host 'platformModelScaleGate: success'
Write-Host 'platformModelMapCoverageGate: success'
Write-Host 'platformModelAtlasFallbackGate: success'
Write-Host 'platformModelWorkerX64Gate: success'
Write-Host 'platformModelLiveViewport3DGate: success'
Write-Host 'platformModelViewerControlGate: success'
Write-Host 'platformModelGlbRenderSmokeGate: success'
