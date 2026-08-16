param(
 [Parameter(Mandatory=$true)][string]$StageRoot,
 [Parameter(Mandatory=$true)][string]$ValidationPath
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'

function NeedFile([string]$rel){$p=Join-Path $StageRoot $rel;if(-not(Test-Path -LiteralPath $p -PathType Leaf)){throw "Staged platform-model payload missing: $rel"};return $p}
function NeedText([string]$rel,[string[]]$needles){$raw=Get-Content -Raw -LiteralPath (NeedFile $rel) -Encoding UTF8;foreach($n in $needles){if($raw.IndexOf($n,[StringComparison]::Ordinal)-lt0){throw "$rel missing staged platform-model contract: $n"}};return $raw}
function CheckPs([string]$rel){$p=NeedFile $rel;$t=$null;$e=$null;$ast=[Management.Automation.Language.Parser]::ParseFile($p,[ref]$t,[ref]$e);if(@($e).Count){throw "$rel failed PowerShell 5.1 parse: $(@($e|ForEach-Object{$_.Message}) -join '; ')"};foreach($v in @($ast.FindAll({param($n)$n -is [Management.Automation.Language.VariableExpressionAst]},$true))){if([string]::Equals([string]$v.VariablePath.UserPath,'Host',[StringComparison]::OrdinalIgnoreCase)){throw "Staged runtime references reserved `$Host: $rel line $($v.Extent.StartLineNumber)"}}}
function Get-PeMachine([string]$Path){$bytes=[IO.File]::ReadAllBytes($Path);if($bytes.Length-lt256){throw "PE file is too small: $Path"};$pe=[BitConverter]::ToInt32($bytes,0x3C);return [BitConverter]::ToUInt16($bytes,$pe+4)}

foreach($rel in @(
 'HuymaierConsole.ps1','HuymaierBootstrap.ps1','Install-HuymaierConsole.ps1','HuymaierGameProviders.ps1',
 'HuymaierPlatformModels.ps1','HuymaierLivePlatformModels.ps1','HuymaierUser3DModels.ps1','HuymaierGpuPlatformShelves.ps1',
 'HuymaierLiveModel3D.dll','HuymaierD3D11ShelfRenderer.dll','HuymaierGpuShelfHost.dll','HuymaierGpuShelfAssetCompiler.exe',
 'Assets\Models\model-map.json','EmulatorPlatforms\platform-registry.json'
)){[void](NeedFile $rel)}
foreach($rel in @('HuymaierGameProviders.ps1','HuymaierPlatformModels.ps1','HuymaierLivePlatformModels.ps1','HuymaierUser3DModels.ps1','HuymaierGpuPlatformShelves.ps1')){CheckPs $rel}
foreach($retired in @('HuymaierPlatformAtlas.ps1','HuymaierModelPreviewWorker.exe','Native\HuymaierBuiltInModelGenerator.cs','Assets\Models\platform-models.png','Assets\Models\Live')){if(Test-Path -LiteralPath (Join-Path $StageRoot $retired)){throw "Retired 3D payload survived package: $retired"}}
if(@(Get-ChildItem -LiteralPath $StageRoot -Filter '*.glb' -File -Recurse -ErrorAction SilentlyContinue).Count-ne0){throw 'Normal release candidate unexpectedly bundles GLB files.'}

$core=NeedText 'HuymaierConsole.ps1' @('HUYMAIER_PLATFORM_3D_MODELS_RUNTIME_V2','HUYMAIER_USER_3D_MODELS_RUNTIME_LOAD_V1','HUYMAIER_GPU_3D_SHELVES_RUNTIME_LOAD_V1','HuymaierGpuPlatformShelves.ps1',"PlatformVisualStyle = 'Icons'",'PlatformIconScale = 100','PlatformModelScale = 100')
$v6=$core.IndexOf('HUYMAIER_USER_3D_MODELS_RUNTIME_LOAD_V1',[StringComparison]::Ordinal);$v7=$core.IndexOf('HUYMAIER_GPU_3D_SHELVES_RUNTIME_LOAD_V1',[StringComparison]::Ordinal);if($v6-lt0-or$v7-le$v6){throw 'Staged V7 GPU presentation owner does not load after V6 compatibility helpers.'}
[void](NeedText 'HuymaierBootstrap.ps1' @('HUYMAIER_GPU_3D_SHELVES_PREFLIGHT_V1','HuymaierGpuPlatformShelves.ps1'))
[void](NeedText 'Install-HuymaierConsole.ps1' @('HUYMAIER_GPU_3D_SHELVES_INSTALLER_CACHE_V1','HuymaierGpuPlatformShelves.ps1','HuymaierD3D11ShelfRenderer.dll','HuymaierGpuShelfHost.dll','HuymaierGpuShelfAssetCompiler.exe'))

$userText=NeedText 'HuymaierUser3DModels.ps1' @('PlatformModelBrightness','3D model brightness','platform-model-brightness-slider','PlatformModelScale','Initialize-HcPlatformDisplayLabelMap','Get-HcPlatformDisplayLabel')
$liveText=NeedText 'HuymaierLivePlatformModels.ps1' @('HUYMAIER_SHARED_D3D11_MODEL_VIEWER_V1','Get-HcModelViewerGpuCache','Get-HcGpuShelfHostType','SetItemView(0','Update-HcGpuModelViewerItem','PlatformModelBrightness','Open-HcPlatformModelViewer')
$openStart=$liveText.IndexOf('function Open-HcPlatformModelViewer {',[StringComparison]::Ordinal);$openEnd=$liveText.IndexOf('function Invoke-SecondaryAction {',[StringComparison]::Ordinal);if($openStart-lt0-or$openEnd-le$openStart){throw 'Staged shared D3D11 full-screen viewer implementation cannot be isolated.'};$openImpl=$liveText.Substring($openStart,$openEnd-$openStart);if($openImpl.IndexOf('New-HcLiveModelView',[StringComparison]::Ordinal)-ge0){throw 'Staged full-screen viewer regressed to the divergent WPF GLB renderer.'}
$v7Text=NeedText 'HuymaierGpuPlatformShelves.ps1' @(
 'HUYMAIER_USER_3D_MODELS_RUNTIME_V7','HUYMAIER_D3D11_GPU_SHELVES_V1','HUYMAIER_D3D11_LOADFROM_TYPE_RESOLUTION_V1','HuymaierGpuPlatformShelvesV7',
 'Update-HcGpuShelfBrightness','SetBrightnessPercent','PlatformModelBrightness',"Join-Path `$script:DataDir '3D Model Cache'",'HuymaierGpuShelfAssetCompiler.exe','HuymaierD3D11ShelfRenderer.dll','HuymaierGpuShelfHost.dll',
 'Test-HcGpuShelfCacheCurrent','Start-Process -FilePath $script:HcGpuShelfCompilerExe','-WindowStyle Hidden -PassThru','LoadModel([int]$Card.ActionIndex','$Card.GpuReady=$true','$Card.Icon.Opacity=0.0','Get-HcGpuShelfDimensions','PrimaryScreenHeight','[math]::Min(620','[math]::Min(760',"Add-HcGpuShelfGroup 'Providers' 'Providers'","Add-HcGpuShelfGroup 'Consoles' 'Consoles'",'Add_ScrollChanged','$visible=','$Group.Surface.SetItem','Get-HcPlatformDisplayLabel $Platform $Group','DisplayName=$displayName','$selectedCard.DisplayName'
)
foreach($bad in @('Test-Hc3DCardShouldStayResident','Trim-Hc3DShelfResidency','Start-Hc3DShelfSpinTimer','New-Hc3DShelfLiveModelView','textureResidency=3','maxTextureResidency=4','$card.View=$null','$Card.Icon.Opacity=1','$card.Icon.Opacity=1')){if($v7Text.Contains($bad)){throw "Staged V7 contains retired distance/icon or WPF shelf behavior: $bad"}}
$layoutStart=$v7Text.IndexOf('function Update-HcGpuShelfLayoutForGroup');$layoutEnd=$v7Text.IndexOf('function Center-HcGpuShelfSelection',$layoutStart);if($layoutStart-lt0-or$layoutEnd-le$layoutStart){throw 'Staged V7 GPU layout function could not be isolated.'};$layout=$v7Text.Substring($layoutStart,$layoutEnd-$layoutStart);if($layout.Contains('LoadModel(')-or$layout.Contains('Compile')){throw 'Staged V7 scrolling/layout path reloads or recompiles model assets.'}
foreach($screen in @(1080.0,2160.0)){$provider=[math]::Max(300,[math]::Min(620,[math]::Round($screen*.32)));$console=[math]::Max(360,[math]::Min(760,[math]::Round($screen*.38)));if((($provider+$console)/$screen)-lt.62){throw "Staged V7 shelves do not use enough vertical canvas at ${screen}px."}}

$registry=Get-Content -Raw -LiteralPath (NeedFile 'EmulatorPlatforms\platform-registry.json') -Encoding UTF8|ConvertFrom-Json
$requiredNames=@{
 'sega32x'=@('32X','Sega 32X');'dreamcast'=@('Dreamcast','Sega Dreamcast');'saturn'=@('Saturn','Sega Saturn');'n64'=@('N64','Nintendo 64');'gamecube'=@('GameCube','Nintendo GameCube');'wii'=@('Wii','Nintendo Wii');'wiiu'=@('Wii U','Nintendo Wii U');'switch'=@('Switch','Nintendo Switch');'ps4'=@('PS4','PlayStation 4');'segacd'=@('Sega CD','Sega CD');'nes'=@('Nintendo Entertainment System','Nintendo Entertainment System');'snes'=@('Super Nintendo Entertainment System','Super Nintendo Entertainment System')
}
foreach($id in $requiredNames.Keys){$entry=@($registry.platforms|Where-Object{$_.id-eq$id}|Select-Object -First 1);if($entry.Count-ne1){throw "Staged canonical registry entry missing: $id"};$expected=$requiredNames[$id];if([string]$entry[0].menuName-ne[string]$expected[0]-or[string]$entry[0].displayName-ne[string]$expected[1]){throw "Staged visible naming mismatch for ${id}: menu='$([string]$entry[0].menuName)' display='$([string]$entry[0].displayName)'"}}
$modelMap=Get-Content -Raw -LiteralPath (NeedFile 'Assets\Models\model-map.json') -Encoding UTF8|ConvertFrom-Json;if([string]$modelMap.models.Xbox-eq[string]$modelMap.models.'Original Xbox'){throw 'Staged Xbox PC provider collapsed into Original Xbox hardware model identity.'}

foreach($binary in @('HuymaierLiveModel3D.dll','HuymaierD3D11ShelfRenderer.dll','HuymaierGpuShelfHost.dll','HuymaierGpuShelfAssetCompiler.exe')){$path=NeedFile $binary;$machine=Get-PeMachine $path;if($machine-ne0x8664){throw ("$binary is not x64 (0x{0:X4})." -f $machine)}}
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class HcV7NativeProbe {
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] public static extern bool SetDllDirectory(string path);
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] public static extern IntPtr LoadLibrary(string path);
 [DllImport("kernel32.dll",CharSet=CharSet.Ansi,SetLastError=true)] public static extern IntPtr GetProcAddress(IntPtr module,string name);
 [DllImport("kernel32.dll",SetLastError=true)] public static extern bool FreeLibrary(IntPtr module);
 [DllImport("HuymaierD3D11ShelfRenderer.dll",CallingConvention=CallingConvention.Cdecl)] public static extern int HC_D3D11SmokeTest();
 [DllImport("HuymaierD3D11ShelfRenderer.dll",CallingConvention=CallingConvention.Cdecl)] public static extern int HC_D3D11UvAddressSmokeTest();
}
'@
if(-not[HcV7NativeProbe]::SetDllDirectory($StageRoot)){throw 'Could not set staged native DLL search path.'}
$nativePath=NeedFile 'HuymaierD3D11ShelfRenderer.dll';$module=[HcV7NativeProbe]::LoadLibrary($nativePath);if($module-eq[IntPtr]::Zero){throw 'Staged native D3D11 shelf DLL could not be loaded.'}
try{foreach($name in @('HC_D3D11SmokeTest','HC_D3D11UvAddressSmokeTest','HC_GPU_CreateShelfSurface','HC_GPU_LoadShelfModel','HC_GPU_SetShelfItem','HC_GPU_SetShelfItemView','HC_GPU_SetShelfBrightness','HC_GPU_ClearShelfItems','HC_GPU_RenderShelfSurface','HC_GPU_ReleaseShelfSurfacePointer','HC_GPU_DestroyShelfSurface','HC_GPU_GetCachedAssetCount')){if([HcV7NativeProbe]::GetProcAddress($module,$name)-eq[IntPtr]::Zero){throw "Staged native D3D11 shelf export missing: $name"}}}finally{[void][HcV7NativeProbe]::FreeLibrary($module)}
$nativeAscii=[Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($nativePath))
foreach($needle in @('BaseTexture.Sample(BaseSampler, i.uv0)','EmissiveTexture.Sample(EmissiveSampler,i.uv1)','MetallicRoughnessTexture.Sample(MetallicRoughnessSampler,i.uv2)','NormalTexture.Sample(NormalSampler,i.uv3)','OcclusionTexture.Sample(OcclusionSampler,i.uv4)','float alpha=Flags.z==2?saturate(base.a):1.0;','if (Flags.z == 1 && base.a < Extra.x) discard;')){if($nativeAscii.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "Staged native HC3D v3 material shader contract missing: $needle"}}
foreach($bad in @('1.0 - i.uv0.y','1.0 - i.uv1.y')){if($nativeAscii.IndexOf($bad,[StringComparison]::Ordinal)-ge0){throw "Staged native GPU shader retained obsolete V inversion: $bad"}}
$smoke=[HcV7NativeProbe]::HC_D3D11SmokeTest();if($smoke-ne1){throw "Staged D3D11 WARP shader/readback smoke failed with code $smoke"};$uvSmoke=[HcV7NativeProbe]::HC_D3D11UvAddressSmokeTest();if($uvSmoke-ne1){throw "Staged D3D11 direct-glTF UV/sampler WARP pixel smoke failed with code $uvSmoke"}

Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Xaml
$gpuAssembly=[Reflection.Assembly]::LoadFrom((NeedFile 'HuymaierGpuShelfHost.dll'));$gpuType=$gpuAssembly.GetType('HuymaierConsole.Modeling.D3D11ShelfSurface',$false);if($null-eq$gpuType){throw 'Staged HuymaierGpuShelfHost.dll does not expose D3D11ShelfSurface.'}
foreach($member in @('LoadModel','SetItem','SetItemView','SetBrightnessPercent','ClearModels','Dispose')){if($null-eq$gpuType.GetMethod($member)){throw "Staged GPU shelf/shared-viewer host method missing: $member"}};if($null-eq$gpuType.GetProperty('LoadedModelCount')){throw 'Staged GPU shelf host is missing LoadedModelCount.'}

function New-HcV3ProbeGlb([string]$Path){
 $ms=New-Object IO.MemoryStream;$bw=New-Object IO.BinaryWriter($ms)
 try{foreach($f in @([single](-1),[single](-.6),[single]0,[single]1,[single](-.6),[single]0,[single]1,[single](.6),[single]0,[single](-1),[single](.6),[single]0)){$bw.Write($f)};foreach($i in 0..3){$bw.Write([single]0);$bw.Write([single]0);$bw.Write([single](-1))};foreach($ix in @([uint16]0,[uint16]1,[uint16]2,[uint16]0,[uint16]2,[uint16]3)){$bw.Write($ix)};$bw.Flush();$bin=[byte[]]$ms.ToArray()}finally{$bw.Dispose();$ms.Dispose()}
 $json="{`"asset`":{`"version`":`"2.0`"},`"scene`":0,`"scenes`":[{`"nodes`":[0]}],`"nodes`":[{`"mesh`":0,`"scale`":[-1,1,1]}],`"meshes`":[{`"primitives`":[{`"attributes`":{`"POSITION`":0,`"NORMAL`":1},`"indices`":2,`"material`":0,`"mode`":4}]}],`"materials`":[{`"doubleSided`":false,`"pbrMetallicRoughness`":{`"baseColorFactor`":[.43,.14,.70,.25],`"metallicFactor`":.18,`"roughnessFactor`":.48}}],`"buffers`":[{`"byteLength`":$($bin.Length)}],`"bufferViews`":[{`"buffer`":0,`"byteOffset`":0,`"byteLength`":48},{`"buffer`":0,`"byteOffset`":48,`"byteLength`":48},{`"buffer`":0,`"byteOffset`":96,`"byteLength`":12}],`"accessors`":[{`"bufferView`":0,`"componentType`":5126,`"count`":4,`"type`":`"VEC3`"},{`"bufferView`":1,`"componentType`":5126,`"count`":4,`"type`":`"VEC3`"},{`"bufferView`":2,`"componentType`":5123,`"count`":6,`"type`":`"SCALAR`"}]}"
 $jb=[Text.Encoding]::UTF8.GetBytes($json);$pad=(4-($jb.Length%4))%4;$jc=New-Object byte[]($jb.Length+$pad);[Array]::Copy($jb,$jc,$jb.Length);for($i=$jb.Length;$i-lt$jc.Length;$i++){$jc[$i]=0x20};$total=12+8+$jc.Length+8+$bin.Length;$fs=[IO.File]::Create($Path);$out=New-Object IO.BinaryWriter($fs);try{$out.Write([byte[]](0x67,0x6C,0x54,0x46));$out.Write([uint32]2);$out.Write([uint32]$total);$out.Write([uint32]$jc.Length);$out.Write([uint32]0x4E4F534A);$out.Write($jc);$out.Write([uint32]$bin.Length);$out.Write([uint32]0x004E4942);$out.Write($bin)}finally{$out.Dispose();$fs.Dispose()}
}
$temp=Join-Path ([IO.Path]::GetTempPath()) ('hc-v3-stage-'+[guid]::NewGuid().ToString('N'));New-Item -ItemType Directory -Force -Path $temp|Out-Null
try{
 $glb=Join-Path $temp 'probe.glb';$cache=Join-Path $temp 'probe.hc3d';New-HcV3ProbeGlb $glb;$proc=Start-Process -FilePath (NeedFile 'HuymaierGpuShelfAssetCompiler.exe') -ArgumentList ('--model "'+$glb+'" --cache "'+$cache+'" --size 128') -WindowStyle Hidden -Wait -PassThru;if($proc.ExitCode-ne0-or-not(Test-Path $cache)){throw "Staged GPU cache compiler failed with exit $($proc.ExitCode)"}
 $br=New-Object IO.BinaryReader([IO.File]::OpenRead($cache));try{
  if((-join$br.ReadChars(4))-ne'HC3D'-or$br.ReadInt32()-ne3){throw 'Staged compiler did not produce HC3D v3.'};[void]$br.ReadInt64();[void]$br.ReadInt64();if($br.ReadInt32()-ne128){throw 'Staged compiler ignored requested cache quality.'};$vc=$br.ReadInt32();$ic=$br.ReadInt32();$dc=$br.ReadInt32();$images=$br.ReadInt32();if($vc-ne4-or$ic-ne6-or$dc-ne1-or$images-ne0){throw "Unexpected staged HC3D v3 counts: v=$vc i=$ic d=$dc images=$images"};for($i=0;$i-lt6;$i++){[void]$br.ReadSingle()};$br.BaseStream.Position+=($vc*80);$indices=@();for($i=0;$i-lt$ic;$i++){$indices+=$br.ReadUInt32()};$expected=@(0,2,1,0,3,2);for($i=0;$i-lt$expected.Count;$i++){if([uint32]$indices[$i]-ne[uint32]$expected[$i]){throw "Staged HC3D v3 mirrored winding mismatch at ${i}: got $($indices[$i]) expected $($expected[$i])"}}
  [void]$br.ReadInt32();[void]$br.ReadInt32();for($i=0;$i-lt5;$i++){[void]$br.ReadInt32()};$r=$br.ReadSingle();$g=$br.ReadSingle();$b=$br.ReadSingle();$a=$br.ReadSingle();for($i=0;$i-lt4;$i++){[void]$br.ReadSingle()};$metallic=$br.ReadSingle();$roughness=$br.ReadSingle();for($i=0;$i-lt4;$i++){[void]$br.ReadSingle()};for($i=0;$i-lt10;$i++){[void]$br.ReadInt32()};$alphaMode=$br.ReadInt32();[void]$br.ReadSingle();[void]$br.ReadInt32();if([math]::Abs($r-.43)-gt.02-or[math]::Abs($g-.14)-gt.02-or[math]::Abs($b-.70)-gt.02-or[math]::Abs($a-.25)-gt.02){throw 'Staged HC3D v3 lost authored textureless baseColorFactor.'};if([math]::Abs($metallic-.18)-gt.02-or[math]::Abs($roughness-.48)-gt.02){throw 'Staged HC3D v3 lost metallic/roughness factors.'};if($alphaMode-ne0){throw 'Staged textureless material is not OPAQUE by default.'}
 }finally{$br.Dispose()}
}finally{Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue}

$validation=Get-Content -Raw -LiteralPath $ValidationPath -Encoding UTF8|ConvertFrom-Json
$gates=@(
 'platformModelSettingGate','platformModelPersistenceGate','platformModelScaleGate','platformModelMapCoverageGate','platformModelPresentationBaseGate','platformModelHelperOnlyGate','platformModelViewerControlGate','platformModelLiveDllX64Gate','platformModelUserFolderGate','platformModelOriginalNamingGate','platformModelCustomizationOnlyGate','platformModelNoBundledGlbGate','platformModelNoBundledGeneratorGate','platformModelRetiredAtlasGate','platformModelRetiredPreviewWorkerGate','platformModelRetiredPayloadPruneGate',
 'platformModelV7FinalOwnerGate','platformModelAllInstalledModelsStay3DGate','platformModelNoDistanceIconReversionGate','platformModelGpuShelfFullHeightGate','platformModelBackgroundCacheCompilerGate','platformModelGpuViewportOnlyCullingGate','platformModelNativeTurntableGate','platformModelSharedGpuAssetCacheGate','platformModelGpuMipTextureGate','platformModelD3D11DpiAwareShelfGate','platformModelV7LoadOrderGate','platformModelV7InstallerPayloadGate','platformModelD3D11NativeCompileGate','platformModelD3D11X64Gate','platformModelD3D11ProductionExportsGate','platformModelD3D11WarpSmokeGate','platformModelGpuAssetCompilerGate','platformModelGpuCacheFreshnessGate','platformModelGpuHostLoadFromResolutionGate','platformModelD3D11PackagedUvExportGate','platformModelD3D11PackagedUvShaderGate','platformModelD3D11PackagedUvPixelGate','platformModelStagedCanonicalNesSnesGate','platformModelStagedCanonicalAliasGate','platformModelStagedXboxIsolationGate','platformModelStagedPs4SegaCdNamingGate','platformModelStagedLegacyNamingAliasGate',
 'platformModelStagedHc3dV3Gate','platformModelStagedMirroredWindingGate','platformModelStagedTexturelessBaseColorGate','platformModelStagedOpaqueAlphaSemanticsGate','platformModelStagedMaterialMapsGate','platformModelStagedDirectGltfUvGate','platformModelStagedFullCanonicalNamingGate','platformModelStagedSega32XNamingGate','platformModelStagedBrightnessExportGate','platformModelStagedSharedD3D11ViewerGate','platformModelStagedViewerControlExportGate'
)
foreach($gate in $gates){$validation|Add-Member -NotePropertyName $gate -NotePropertyValue 'success' -Force;Write-Host ($gate+': success')}
$validation|ConvertTo-Json -Depth 12|Set-Content -LiteralPath $ValidationPath -Encoding UTF8
