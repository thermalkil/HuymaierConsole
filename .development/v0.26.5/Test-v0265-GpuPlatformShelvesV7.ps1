Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$runtime=Join-Path $root 'HuymaierGpuPlatformShelves.ps1'
$userRuntime=Join-Path $root 'HuymaierUser3DModels.ps1'
$native=Join-Path $root 'Native\HuymaierD3D11ShelfRuntime.cpp'
$asset=Join-Path $root 'Native\HuymaierD3D11ShelfAsset.cpp'
$uvSmoke=Join-Path $root 'Native\HuymaierD3D11UvAddressSmoke.cpp'
$hostSource=Join-Path $root 'Native\HuymaierD3D11ShelfHost.cs'
$compiler=Join-Path $root 'Native\HuymaierGpuShelfAssetCompiler.cs'
$program=Join-Path $root 'Native\HuymaierGpuShelfAssetCompilerProgram.cs'
$platformOptimizer=Join-Path $root '.build\Optimize-Platform3DModels.ps1'
$gpuOptimizer=Join-Path $root '.build\Optimize-GpuPlatformShelves.ps1'
$userOptimizer=Join-Path $root '.build\Optimize-User3DModels.ps1'
$sourceList=Join-Path $root '.source\source-files.txt'
$canonicalTest=Join-Path $root '.development\v0.26.5\Test-v0265-CanonicalRecomps.ps1'
foreach($p in @($runtime,$userRuntime,$native,$asset,$uvSmoke,$hostSource,$compiler,$program,$platformOptimizer,$gpuOptimizer,$userOptimizer,$sourceList,$canonicalTest)){if(-not(Test-Path -LiteralPath $p -PathType Leaf)){throw "V7 GPU shelf source missing: $p"}}

foreach($ps in @($runtime,$platformOptimizer,$gpuOptimizer,$userOptimizer,$canonicalTest)){
    $t=$null;$e=$null;$ast=[Management.Automation.Language.Parser]::ParseFile($ps,[ref]$t,[ref]$e)
    if(@($e).Count){throw "$ps failed Windows PowerShell 5.1 parse: $(@($e|ForEach-Object{$_.Message}) -join '; ')"}
    foreach($v in @($ast.FindAll({param($n)$n -is [Management.Automation.Language.VariableExpressionAst]},$true))){if([string]::Equals([string]$v.VariablePath.UserPath,'Host',[StringComparison]::OrdinalIgnoreCase)){throw "V7 GPU runtime references reserved `$Host: $ps line $($v.Extent.StartLineNumber)"}}
}

$text=Get-Content -Raw -LiteralPath $runtime -Encoding UTF8
function Need([string]$n){if($text.IndexOf($n,[StringComparison]::Ordinal)-lt0){throw "V7 GPU shelf contract missing: $n"}}
function Reject([string]$n){if($text.IndexOf($n,[StringComparison]::Ordinal)-ge0){throw "Retired V6 shelf behavior survived into V7 owner: $n"}}
foreach($n in @(
    'HUYMAIER_USER_3D_MODELS_RUNTIME_V7','HUYMAIER_D3D11_GPU_SHELVES_V1','HuymaierGpuPlatformShelvesV7',
    'HUYMAIER_V0265_CANONICAL_RECOMPS_V1','Get-HcCanonicalPlatformName','Get-HcRecompGames','recomps-root',
    "Join-Path `$script:DataDir '3D Model Cache'",'HuymaierGpuShelfAssetCompiler.exe','HuymaierD3D11ShelfRenderer.dll','HuymaierGpuShelfHost.dll',
    'Test-HcGpuShelfCacheCurrent','Start-HcGpuShelfCompile','Start-Process -FilePath $script:HcGpuShelfCompilerExe','-WindowStyle Hidden -PassThru',
    'D3D11ShelfSurface','LoadModel([int]$Card.ActionIndex','SetItem([int]$card.ActionIndex','$Card.GpuReady=$true','$Card.Icon.Opacity=0.0',
    'Get-HcGpuShelfDimensions','PrimaryScreenHeight','[math]::Min(620','[math]::Min(760','Get-HcGpuCardMetrics',
    "Add-HcGpuShelfGroup 'Providers' 'Providers'","Add-HcGpuShelfGroup 'Consoles' 'Consoles'",'Update-HcGpuShelfLayoutForGroup','Add_ScrollChanged',
    'GPU shelf model ready:','D3D11 GPU dual shelves mounted:'
)){Need $n}
foreach($n in @('Test-Hc3DCardShouldStayResident','Trim-Hc3DShelfResidency','Start-Hc3DShelfSpinTimer','New-Hc3DShelfLiveModelView','textureResidency=3','maxTextureResidency=4','$card.View=$null')){Reject $n}
if($text.Contains('$Card.Icon.Opacity=1')-or$text.Contains('$card.Icon.Opacity=1')){throw 'V7 can restore a successfully GPU-backed model to its icon.'}
$loadStart=$text.IndexOf('function Load-HcGpuShelfCard');$loadEnd=$text.IndexOf('function Start-HcGpuShelfCompilerTimer',$loadStart);$loadBlock=$text.Substring($loadStart,$loadEnd-$loadStart);if(-not$loadBlock.Contains('$Card.Icon.Opacity=0.0')){throw 'V7 successful GPU load does not permanently hide the fallback icon.'}
$layoutStart=$text.IndexOf('function Update-HcGpuShelfLayoutForGroup');$layoutEnd=$text.IndexOf('function Center-HcGpuShelfSelection',$layoutStart);$layout=$text.Substring($layoutStart,$layoutEnd-$layoutStart);foreach($n in @('$visible=','$Group.Surface.SetItem',',$visible)')){if(-not$layout.Contains($n)){throw "V7 viewport-only draw culling missing: $n"}};if($layout.Contains('LoadModel(')-or$layout.Contains('Compile')){throw 'V7 scrolling/layout path reloads or recompiles model assets.'}

foreach($screen in @(1080.0,2160.0)){
    $provider=[math]::Max(300,[math]::Min(620,[math]::Round($screen*.32)))
    $console=[math]::Max(360,[math]::Min(760,[math]::Round($screen*.38)))
    $coverage=($provider+$console)/$screen
    if($coverage-lt.62){throw "V7 shelves use too little vertical screen at ${screen}px: $([math]::Round($coverage*100,1))%"}
}

$nativeText=Get-Content -Raw $native -Encoding UTF8
foreach($n in @('HUYMAIER_D3D11_SHARED_SHELF_RUNTIME_V1','std::unordered_map<std::wstring, std::weak_ptr<Asset>> assets','std::shared_ptr<Asset> asset','HC_GPU_LoadShelfModel','HC_GPU_SetShelfItem','HC_GPU_RenderShelfSurface','phase*16.0f','float2 baseUv = float2(i.uv0.x, 1.0 - i.uv0.y)','float2 emissiveUv = float2(i.uv1.x, 1.0 - i.uv1.y)')){if(-not$nativeText.Contains($n)){throw "Native persistent GPU shelf contract missing: $n"}}
foreach($bad in @('HC_GPU_UnloadShelfModel','erase(id)')){if($nativeText.Contains($bad)){throw "Native shelf exposes distance-style model eviction: $bad"}}
$assetText=Get-Content -Raw $asset -Encoding UTF8;foreach($n in @('D3D11_USAGE_IMMUTABLE','D3D11_RESOURCE_MISC_GENERATE_MIPS','GenerateMips')){if(-not$assetText.Contains($n)){throw "GPU asset upload contract missing: $n"}}
$uvSmokeText=Get-Content -Raw $uvSmoke -Encoding UTF8;foreach($n in @('HC_D3D11UvAddressSmokeTest','D3D11_TEXTURE_ADDRESS_WRAP','D3D11_TEXTURE_ADDRESS_CLAMP','D3D11_TEXTURE_ADDRESS_MIRROR','PixelEquals')){if(-not$uvSmokeText.Contains($n)){throw "GPU UV-addressing smoke contract missing: $n"}}
$hostText=Get-Content -Raw $hostSource -Encoding UTF8;foreach($n in @('HUYMAIER_D3D11_SHELF_HOST_V2','HUYMAIER_D3D11_DPI_AWARE_SHELF_V1','D3DImage','ReplayState','CompositionTarget.Rendering','VisualTreeHelper.GetDpi','dpiScaleX','dpiScaleY','PixelWidthFor','PixelHeightFor','ApplyItemToNative','modelPaths','itemStates')){if(-not$hostText.Contains($n)){throw "Managed GPU shelf host contract missing: $n"}}
$compilerText=Get-Content -Raw $compiler -Encoding UTF8;foreach($n in @('HUYMAIER_GPU_SHELF_ASSET_CACHE_V1','DefaultShelfTextureSize = 512','DecodePixelWidth','DecodePixelHeight','IsCacheCurrent','EnsureCompiled')){if(-not$compilerText.Contains($n)){throw "Persistent HC3D compiler contract missing: $n"}}
$programText=Get-Content -Raw $program -Encoding UTF8;if(-not$programText.Contains('HUYMAIER_GPU_SHELF_COMPILER_PROGRAM_V1')-or-not$programText.Contains('GpuShelfAssetCompiler.EnsureCompiled')){throw 'Background cache compiler program contract is incomplete.'}

$sources=@(Get-Content $sourceList -Encoding UTF8)
foreach($item in @('HuymaierGpuPlatformShelves.ps1','Native/HuymaierD3D11ShelfRenderer.cpp','Native/HuymaierD3D11ShelfRuntime.cpp','Native/HuymaierD3D11ShelfAsset.h','Native/HuymaierD3D11ShelfAsset.cpp','Native/HuymaierD3D11UvAddressSmoke.cpp','Native/HuymaierD3D11ShelfHost.cs','Native/HuymaierGpuShelfAssetCompiler.cs','Native/HuymaierGpuShelfAssetCompilerProgram.cs')){if($sources-notcontains$item){throw "Release source list omits V7 GPU shelf source: $item"}}
$platformOpt=Get-Content -Raw $platformOptimizer -Encoding UTF8;if(-not$platformOpt.Contains('HUYMAIER_D3D11_GPU_SHELF_BUILD_TRANSFORM_V1')-or-not$platformOpt.Contains('Optimize-GpuPlatformShelves.ps1')){throw 'Platform transform does not invoke GPU binary build.'}
$gpuOpt=Get-Content -Raw $gpuOptimizer -Encoding UTF8;foreach($n in @('HUYMAIER_D3D11_GPU_SHELF_BINARY_BUILD_V1','/MT','HuymaierD3D11ShelfRenderer.dll','HuymaierD3D11UvAddressSmoke.cpp','HC_D3D11UvAddressSmokeTest','HuymaierGpuShelfHost.dll','HuymaierGpuShelfAssetCompiler.exe','HC_GPU_CreateShelfSurface')){if(-not$gpuOpt.Contains($n)){throw "GPU release build contract missing: $n"}}
$userOpt=Get-Content -Raw $userOptimizer -Encoding UTF8;foreach($n in @('HUYMAIER_GPU_3D_SHELVES_RUNTIME_LOAD_V1','HuymaierGpuPlatformShelves.ps1','HuymaierD3D11ShelfRenderer.dll','HuymaierGpuShelfHost.dll','HuymaierGpuShelfAssetCompiler.exe')){if(-not$userOpt.Contains($n)){throw "V7 load/installer contract missing: $n"}}

# Prove transformed core load order: compatibility helpers first, V7 final owner second.
$temp=Join-Path $(if($env:RUNNER_TEMP){$env:RUNNER_TEMP}else{[IO.Path]::GetTempPath()}) ('hc-v7-order-'+[guid]::NewGuid().ToString('N'));New-Item -ItemType Directory -Force -Path $temp|Out-Null
try{
    $core=Join-Path $temp 'HuymaierConsole.ps1';$bootstrap=Join-Path $temp 'HuymaierBootstrap.ps1';$installer=Join-Path $temp 'Install-HuymaierConsole.ps1';$builder=Join-Path $temp 'Build-HuymaierReleaseCandidate.Core.ps1'
    Copy-Item (Join-Path $root 'HuymaierConsole.ps1') $core;Copy-Item (Join-Path $root 'HuymaierBootstrap.ps1') $bootstrap;Copy-Item (Join-Path $root 'Install-HuymaierConsole.ps1') $installer;Copy-Item (Join-Path $root '.build\Build-HuymaierReleaseCandidate.Core.ps1') $builder
    & $platformOptimizer -CorePath $core -BootstrapPath $bootstrap -InstallerScriptPath $installer -CoreBuilderPath $builder
    & $userOptimizer -CorePath $core -BootstrapPath $bootstrap -InstallerScriptPath $installer
    $coreText=Get-Content -Raw $core -Encoding UTF8;$v6=$coreText.IndexOf('HUYMAIER_USER_3D_MODELS_RUNTIME_LOAD_V1',[StringComparison]::Ordinal);$v7=$coreText.IndexOf('HUYMAIER_GPU_3D_SHELVES_RUNTIME_LOAD_V1',[StringComparison]::Ordinal)
    if($v6-lt0-or$v7-le$v6){throw 'V7 GPU shelf owner does not load after compatibility helpers.'}
    $installerText=Get-Content -Raw $installer -Encoding UTF8;foreach($n in @('HuymaierGpuPlatformShelves.ps1','HuymaierD3D11ShelfRenderer.dll','HuymaierGpuShelfHost.dll','HuymaierGpuShelfAssetCompiler.exe')){if(-not$installerText.Contains($n)){throw "Transformed installer omits V7 payload: $n"}}
}finally{Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue}

# The candidate exact-source workflow already invokes this V7 gate. Chaining the
# canonical/provider functional test here prevents release validation from ever
# skipping NES/SNES alias resolution or Recomps folder/discovery/launch behavior.
& $canonicalTest

foreach($gate in @('platformModelV7FinalOwnerGate','platformModelAllInstalledModelsStay3DGate','platformModelNoDistanceIconReversionGate','platformModelGpuShelfFullHeightGate','platformModelBackgroundCacheCompilerGate','platformModelGpuViewportOnlyCullingGate','platformModelNativeTurntableGate','platformModelSharedGpuAssetCacheGate','platformModelGpuMipTextureGate','platformModelV7ReleaseSourceGate','platformModelV7LoadOrderGate','platformModelV7InstallerPayloadGate','platformModelD3D11DpiAwareShelfGate','platformModelCanonicalRecompsReleaseGate')){Write-Host ($gate+': success')}
