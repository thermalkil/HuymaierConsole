Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$baseModule=Join-Path $root 'HuymaierPlatformModels.ps1'
$liveModule=Join-Path $root 'HuymaierLivePlatformModels.ps1'
$userModule=Join-Path $root 'HuymaierUser3DModels.ps1'
$modelLoader=Join-Path $root 'Native\HuymaierModelPreviewWorker.cs'
$modelAliases=Join-Path $root 'Native\HuymaierModelPreviewWpfAliases.cs'
$liveControl=Join-Path $root 'Native\HuymaierLiveModelControl.cs'
$optimizer=Join-Path $root '.build\Optimize-Platform3DModels.ps1'
$pruneOptimizer=Join-Path $root '.build\Optimize-Retired3DPayloadPrune.ps1'
$modelMap=Join-Path $root 'Assets\Models\model-map.json'
foreach($p in @($baseModule,$liveModule,$userModule,$modelLoader,$modelAliases,$liveControl,$optimizer,$pruneOptimizer,$modelMap)){if(-not(Test-Path -LiteralPath $p -PathType Leaf)){throw "Platform-model source is missing: $p"}}

foreach($ps in @($baseModule,$liveModule,$userModule,$optimizer,$pruneOptimizer)){
    $tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseFile($ps,[ref]$tokens,[ref]$errors)
    if(@($errors).Count){throw "$ps failed Windows PowerShell 5.1 parse: $(@($errors|ForEach-Object{$_.Message}) -join '; ')"}
    if($ps -in @($baseModule,$liveModule,$userModule)){foreach($variable in @($ast.FindAll({param($node)$node -is [Management.Automation.Language.VariableExpressionAst]},$true))){if([string]::Equals([string]$variable.VariablePath.UserPath,'Host',[StringComparison]::OrdinalIgnoreCase)){throw "Active platform presentation runtime references reserved `$Host: $ps line $($variable.Extent.StartLineNumber)"}}}
}

$baseText=Get-Content -Raw $baseModule -Encoding UTF8
foreach($needle in @('HUYMAIER_PLATFORM_PRESENTATION_BASE_V2','HcModelsBaseNewPlatformCard','HcModelsBaseGetPageDefinition','HcModelsBaseInvokeAction','HcModelsBaseAddPlatformRail','Initialize-HcPlatformModelConfig','Get-HcPlatformVisualStyle','PlatformIconScale','PlatformModelScale')){if(-not$baseText.Contains($needle)){throw "Platform presentation base contract missing: $needle"}}
foreach($forbidden in @('HuymaierModelPreviewWorker.exe','Request-HcModelPreview','function New-PlatformCard','function Add-PlatformRail','function Get-PageDefinition','function Invoke-Action')){if($baseText.Contains($forbidden)){throw "Platform presentation base still owns retired rendering/settings behavior: $forbidden"}}

$liveText=Get-Content -Raw $liveModule -Encoding UTF8
foreach($needle in @('HUYMAIER_LIVE_PLATFORM_3D_HELPERS_V2','HuymaierLiveModel3D.dll','Initialize-HcLiveModelAssembly','New-HcLiveModelView','Get-HcPlatformVisualHost','Open-HcPlatformModelViewer','Close-HcPlatformModelViewer','function Invoke-SecondaryAction','function Apply-ControllerNavigation','LB / RB  Zoom')){if(-not$liveText.Contains($needle)){throw "Live platform helper contract missing: $needle"}}
foreach($forbidden in @('function New-PlatformCard','function Add-PlatformRail','function Get-PageDefinition','function Invoke-Action','function Adjust-SelectedSlider','Set-HcAtlasFallbackVisual','HuymaierPlatformAtlas')){if($liveText.Contains($forbidden)){throw "Live helper module still owns retired card/settings/atlas behavior: $forbidden"}}

$controlText=Get-Content -Raw $liveControl -Encoding UTF8
foreach($needle in @('public sealed class LiveModelView','Viewport3D','SetScalePercent','Rotate(double yawDelta','Zoom(double delta)','ResetView','CardMode','GeometryCount','VertexCount')){if(-not$controlText.Contains($needle)){throw "Live Viewport3D control contract missing: $needle"}}

$map=Get-Content -Raw $modelMap -Encoding UTF8|ConvertFrom-Json
if([int]$map.schemaVersion-ne2){throw '3D model map schema version must remain 2.'}
if($null-eq$map.sourceModels){throw '3D model map no longer contains original source-model provenance.'}
$keys=@{};foreach($p in @($map.models.PSObject.Properties)){$keys[[string]$p.Name.ToLowerInvariant()]=[string]$p.Value}
foreach($provider in @('Steam','Epic','GOG','EA','Ubisoft','Xbox App','Battle.net','Rockstar','Amazon Games')){if(-not$keys.ContainsKey($provider.ToLowerInvariant())){throw "3D model map is missing provider alias: $provider"}}
$registry=Get-Content -Raw (Join-Path $root 'EmulatorPlatforms\platform-registry.json') -Encoding UTF8|ConvertFrom-Json
foreach($platform in @($registry.platforms|Where-Object{[bool]$_.enabled})){$covered=$false;foreach($alias in @([string]$platform.name,[string]$platform.displayName,[string]$platform.menuName,[string]$platform.id)+@($platform.aliases)){if($alias-and$keys.ContainsKey(([string]$alias).ToLowerInvariant())){$covered=$true;break}};if(-not$covered){throw "3D model map has no alias for enabled platform $([string]$platform.id) / $([string]$platform.name)"}}
foreach($source in @('Steam','Epic Games','PS1','PS2','PS3','GameCube','Wii','Switch','Original Xbox','Xbox 360')){if($null-eq$map.sourceModels.PSObject.Properties[$source]){throw "Supplied live-model provenance is missing: $source"}}

Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Xaml,System.Web.Extensions
$csc=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe';if(-not(Test-Path $csc)){throw 'Framework64 csc.exe was not found.'}
$tempRoot=$(if($env:RUNNER_TEMP){$env:RUNNER_TEMP}else{[IO.Path]::GetTempPath()});$temp=Join-Path $tempRoot ('hc-platform-clean-'+[guid]::NewGuid().ToString('N'));New-Item -ItemType Directory -Force -Path $temp|Out-Null
try{
    $refs=@([Uri].Assembly.Location,[Linq.Enumerable].Assembly.Location,[Web.Script.Serialization.JavaScriptSerializer].Assembly.Location,[Windows.DependencyObject].Assembly.Location,[Windows.Media.Visual].Assembly.Location,[Windows.Window].Assembly.Location,[System.Xaml.XamlReader].Assembly.Location)|Select-Object -Unique
    $dll=Join-Path $temp 'HuymaierLiveModel3D.dll';$args=@('/noconfig','/nologo','/target:library','/platform:x64','/optimize+',('/out:'+$dll));foreach($r in $refs){$args+=('/reference:'+$r)};$args+=@($modelLoader,$modelAliases,$liveControl);& $csc @args
    if($LASTEXITCODE-ne0-or-not(Test-Path $dll)){throw 'Live platform-model x64 DLL compile failed.'}
    $bytes=[IO.File]::ReadAllBytes($dll);$pe=[BitConverter]::ToInt32($bytes,0x3C);$machine=[BitConverter]::ToUInt16($bytes,$pe+4);if($machine-ne0x8664){throw 'HuymaierLiveModel3D.dll is not x64.'}

    $core=Join-Path $temp 'HuymaierConsole.ps1';$bootstrap=Join-Path $temp 'HuymaierBootstrap.ps1';$installer=Join-Path $temp 'Install-HuymaierConsole.ps1';$builder=Join-Path $temp 'Build-HuymaierReleaseCandidate.Core.ps1'
    Copy-Item (Join-Path $root 'HuymaierConsole.ps1') $core;Copy-Item (Join-Path $root 'HuymaierBootstrap.ps1') $bootstrap;Copy-Item (Join-Path $root 'Install-HuymaierConsole.ps1') $installer;Copy-Item (Join-Path $root '.build\Build-HuymaierReleaseCandidate.Core.ps1') $builder
    & $optimizer -CorePath $core -BootstrapPath $bootstrap -InstallerScriptPath $installer -CoreBuilderPath $builder
    & $pruneOptimizer -CoreBuilderPath $builder
    foreach($ps in @($core,$bootstrap,$installer,$builder)){$tokens=$null;$errors=$null;[void][Management.Automation.Language.Parser]::ParseFile($ps,[ref]$tokens,[ref]$errors);if(@($errors).Count){throw "Transformed platform-model file failed parse: $ps :: $(@($errors|ForEach-Object{$_.Message}) -join '; ')"}}
    $coreText=Get-Content -Raw $core;$bootstrapText=Get-Content -Raw $bootstrap;$installerText=Get-Content -Raw $installer;$builderText=Get-Content -Raw $builder
    foreach($needle in @('HUYMAIER_PLATFORM_3D_MODELS_RUNTIME_V2','HUYMAIER_PLATFORM_3D_CONFIG_V2',"PlatformVisualStyle = 'Icons'",'PlatformIconScale = 100','PlatformModelScale = 100',"'PlatformVisualStyle','PlatformIconScale','PlatformModelScale'",'HuymaierPlatformModels.ps1','HuymaierLivePlatformModels.ps1')){if(-not$coreText.Contains($needle)){throw "Transformed core clean platform contract missing: $needle"}}
    foreach($needle in @('HUYMAIER_PLATFORM_3D_LIVE_PREFLIGHT_V2','HuymaierPlatformModels.ps1','HuymaierLivePlatformModels.ps1')){if(-not$bootstrapText.Contains($needle)){throw "Bootstrap clean live-model contract missing: $needle"}}
    if($bootstrapText.Contains('HuymaierPlatformAtlas.ps1')){throw 'Bootstrap still preflights retired atlas runtime.'}
    foreach($needle in @('HUYMAIER_PLATFORM_3D_LIVE_INSTALLER_CACHE_V2','HuymaierPlatformModels.ps1','HuymaierLivePlatformModels.ps1','HuymaierLiveModel3D.dll')){if(-not$installerText.Contains($needle)){throw "Installer clean live-model contract missing: $needle"}}
    if($installerText.Contains('HuymaierPlatformAtlas.ps1')){throw 'Installer cache still includes retired atlas runtime.'}
    foreach($needle in @('HUYMAIER_PLATFORM_LIVE_MODEL_DLL_BUILD_V3','/target:library','HuymaierLiveModel3D.dll','HuymaierLiveModelControl.cs','HUYMAIER_RETIRED_3D_PAYLOAD_PRUNE_V1','HuymaierPlatformAtlas.ps1','HuymaierModelPreviewWorker.exe','Native\HuymaierBuiltInModelGenerator.cs','Assets\Models\platform-models.png','Assets\Models\Live')){if(-not$builderText.Contains($needle)){throw "Clean staged builder contract missing: $needle"}}
    foreach($forbidden in @('HUYMAIER_PLATFORM_3D_ATLAS_PAYLOAD_V1','platform-model-atlas.part01.b64','x64 HuymaierModelPreviewWorker.exe compilation failed.')){if($builderText.Contains($forbidden)){throw "Retired atlas/preview-worker build path survived transform: $forbidden"}}
}finally{Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue}

Write-Host 'platformModelSettingGate: success'
Write-Host 'platformModelPersistenceGate: success'
Write-Host 'platformModelScaleGate: success'
Write-Host 'platformModelMapCoverageGate: success'
Write-Host 'platformModelPresentationBaseGate: success'
Write-Host 'platformModelHelperOnlyGate: success'
Write-Host 'platformModelLiveViewport3DGate: success'
Write-Host 'platformModelViewerControlGate: success'
Write-Host 'platformModelLiveDllX64Gate: success'
Write-Host 'platformModelRetiredAtlasGate: success'
Write-Host 'platformModelRetiredPreviewWorkerGate: success'
Write-Host 'platformModelRetiredPayloadPruneGate: success'
