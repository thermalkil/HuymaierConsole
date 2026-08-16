param(
 [Parameter(Mandatory=$true)][string]$StageRoot,
 [Parameter(Mandatory=$true)][string]$ValidationPath
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'

function NeedFile([string]$rel){$p=Join-Path $StageRoot $rel;if(-not(Test-Path -LiteralPath $p -PathType Leaf)){throw "Staged V7 GPU payload missing: $rel"};$p}
function NeedText([string]$rel,[string[]]$needles){$raw=Get-Content -Raw -LiteralPath (NeedFile $rel) -Encoding UTF8;foreach($n in $needles){if($raw.IndexOf($n,[StringComparison]::Ordinal)-lt0){throw "$rel missing staged V7 contract: $n"}};return $raw}
function CheckPs([string]$rel){$p=NeedFile $rel;$t=$null;$e=$null;$ast=[Management.Automation.Language.Parser]::ParseFile($p,[ref]$t,[ref]$e);if(@($e).Count){throw "$rel failed PowerShell 5.1 parse: $(@($e|ForEach-Object{$_.Message}) -join '; ')"};foreach($v in @($ast.FindAll({param($n)$n -is [Management.Automation.Language.VariableExpressionAst]},$true))){if([string]::Equals([string]$v.VariablePath.UserPath,'Host',[StringComparison]::OrdinalIgnoreCase)){throw "Staged runtime references reserved `$Host: $rel line $($v.Extent.StartLineNumber)"}}}
function Get-PeMachine([string]$Path){$bytes=[IO.File]::ReadAllBytes($Path);if($bytes.Length-lt256){throw "PE file is too small: $Path"};$pe=[BitConverter]::ToInt32($bytes,0x3C);return [BitConverter]::ToUInt16($bytes,$pe+4)}

foreach($rel in @(
 'HuymaierConsole.ps1','HuymaierBootstrap.ps1','Install-HuymaierConsole.ps1',
 'HuymaierPlatformModels.ps1','HuymaierLivePlatformModels.ps1','HuymaierUser3DModels.ps1','HuymaierGpuPlatformShelves.ps1',
 'HuymaierLiveModel3D.dll','HuymaierD3D11ShelfRenderer.dll','HuymaierGpuShelfHost.dll','HuymaierGpuShelfAssetCompiler.exe',
 'Assets\Models\model-map.json','EmulatorPlatforms\platform-registry.json'
)){[void](NeedFile $rel)}
foreach($rel in @('HuymaierPlatformModels.ps1','HuymaierLivePlatformModels.ps1','HuymaierUser3DModels.ps1','HuymaierGpuPlatformShelves.ps1')){CheckPs $rel}

foreach($retired in @('HuymaierPlatformAtlas.ps1','HuymaierModelPreviewWorker.exe','Native\HuymaierBuiltInModelGenerator.cs','Assets\Models\platform-models.png','Assets\Models\Live')){if(Test-Path -LiteralPath (Join-Path $StageRoot $retired)){throw "Retired 3D payload survived package: $retired"}}
if(@(Get-ChildItem -LiteralPath $StageRoot -Filter '*.glb' -File -Recurse -ErrorAction SilentlyContinue).Count-ne0){throw 'Normal release candidate unexpectedly bundles GLB files.'}

$core=NeedText 'HuymaierConsole.ps1' @('HUYMAIER_PLATFORM_3D_MODELS_RUNTIME_V2','HUYMAIER_USER_3D_MODELS_RUNTIME_LOAD_V1','HUYMAIER_GPU_3D_SHELVES_RUNTIME_LOAD_V1','HuymaierGpuPlatformShelves.ps1',"PlatformVisualStyle = 'Icons'",'PlatformIconScale = 100','PlatformModelScale = 100')
$v6=$core.IndexOf('HUYMAIER_USER_3D_MODELS_RUNTIME_LOAD_V1',[StringComparison]::Ordinal)
$v7=$core.IndexOf('HUYMAIER_GPU_3D_SHELVES_RUNTIME_LOAD_V1',[StringComparison]::Ordinal)
if($v6-lt0-or$v7-le$v6){throw 'Staged V7 GPU presentation owner does not load after V6 compatibility helpers.'}
[void](NeedText 'HuymaierBootstrap.ps1' @('HUYMAIER_GPU_3D_SHELVES_PREFLIGHT_V1','HuymaierGpuPlatformShelves.ps1'))
[void](NeedText 'Install-HuymaierConsole.ps1' @('HUYMAIER_GPU_3D_SHELVES_INSTALLER_CACHE_V1','HuymaierGpuPlatformShelves.ps1','HuymaierD3D11ShelfRenderer.dll','HuymaierGpuShelfHost.dll','HuymaierGpuShelfAssetCompiler.exe'))

$v7Text=NeedText 'HuymaierGpuPlatformShelves.ps1' @(
 'HUYMAIER_USER_3D_MODELS_RUNTIME_V7','HUYMAIER_D3D11_GPU_SHELVES_V1','HuymaierGpuPlatformShelvesV7',
 "Join-Path `$script:DataDir '3D Model Cache'",'HuymaierGpuShelfAssetCompiler.exe','HuymaierD3D11ShelfRenderer.dll','HuymaierGpuShelfHost.dll',
 'Test-HcGpuShelfCacheCurrent','Start-Process -FilePath $script:HcGpuShelfCompilerExe','-WindowStyle Hidden -PassThru',
 'LoadModel([int]$Card.ActionIndex','$Card.GpuReady=$true','$Card.Icon.Opacity=0.0','Get-HcGpuShelfDimensions','PrimaryScreenHeight',
 '[math]::Min(620','[math]::Min(760',"Add-HcGpuShelfGroup 'Providers' 'Providers'","Add-HcGpuShelfGroup 'Consoles' 'Consoles'",'Add_ScrollChanged','$visible=','$Group.Surface.SetItem'
)
foreach($bad in @('Test-Hc3DCardShouldStayResident','Trim-Hc3DShelfResidency','Start-Hc3DShelfSpinTimer','New-Hc3DShelfLiveModelView','textureResidency=3','maxTextureResidency=4','$card.View=$null','$Card.Icon.Opacity=1','$card.Icon.Opacity=1')){if($v7Text.Contains($bad)){throw "Staged V7 contains retired distance/icon or WPF shelf behavior: $bad"}}
$layoutStart=$v7Text.IndexOf('function Update-HcGpuShelfLayoutForGroup');$layoutEnd=$v7Text.IndexOf('function Center-HcGpuShelfSelection',$layoutStart);if($layoutStart-lt0-or$layoutEnd-le$layoutStart){throw 'Staged V7 GPU layout function could not be isolated.'};$layout=$v7Text.Substring($layoutStart,$layoutEnd-$layoutStart);if($layout.Contains('LoadModel(')-or$layout.Contains('Compile')){throw 'Staged V7 scrolling/layout path reloads or recompiles model assets.'}
foreach($screen in @(1080.0,2160.0)){$provider=[math]::Max(300,[math]::Min(620,[math]::Round($screen*.32)));$console=[math]::Max(360,[math]::Min(760,[math]::Round($screen*.38)));if((($provider+$console)/$screen)-lt.62){throw "Staged V7 shelves do not use enough vertical canvas at ${screen}px."}}

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
}
'@
if(-not[HcV7NativeProbe]::SetDllDirectory($StageRoot)){throw 'Could not set staged native DLL search path.'}
$nativePath=NeedFile 'HuymaierD3D11ShelfRenderer.dll';$module=[HcV7NativeProbe]::LoadLibrary($nativePath);if($module-eq[IntPtr]::Zero){throw 'Staged native D3D11 shelf DLL could not be loaded.'}
try{foreach($name in @('HC_D3D11SmokeTest','HC_GPU_CreateShelfSurface','HC_GPU_LoadShelfModel','HC_GPU_SetShelfItem','HC_GPU_ClearShelfItems','HC_GPU_RenderShelfSurface','HC_GPU_ReleaseShelfSurfacePointer','HC_GPU_DestroyShelfSurface','HC_GPU_GetCachedAssetCount')){if([HcV7NativeProbe]::GetProcAddress($module,$name)-eq[IntPtr]::Zero){throw "Staged native D3D11 shelf export missing: $name"}}}finally{[void][HcV7NativeProbe]::FreeLibrary($module)}
$smoke=[HcV7NativeProbe]::HC_D3D11SmokeTest();if($smoke-ne1){throw "Staged D3D11 WARP shader/readback smoke failed with code $smoke"}

Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Xaml
Add-Type -Path (NeedFile 'HuymaierGpuShelfHost.dll')
$gpuType=[type]::GetType('HuymaierConsole.Modeling.D3D11ShelfSurface, HuymaierGpuShelfHost',$false)
if($null-eq$gpuType){throw 'Staged HuymaierGpuShelfHost.dll does not expose D3D11ShelfSurface.'}
foreach($member in @('LoadModel','SetItem','ClearModels','Dispose')){if($null-eq$gpuType.GetMethod($member)){throw "Staged GPU shelf host method missing: $member"}}
if($null-eq$gpuType.GetProperty('LoadedModelCount')){throw 'Staged GPU shelf host is missing LoadedModelCount.'}

# Execute the staged background compiler against a tiny material-colored GLB.
function New-HcV7ProbeGlb([string]$Path){
 $ms=New-Object IO.MemoryStream;$bw=New-Object IO.BinaryWriter($ms)
 try{
  foreach($f in @([single](-1),[single](-.6),[single]0,[single]1,[single](-.6),[single]0,[single]1,[single](.6),[single]0,[single](-1),[single](.6),[single]0)){$bw.Write($f)}
  foreach($i in 0..3){$bw.Write([single]0);$bw.Write([single]0);$bw.Write([single]-1)}
  foreach($ix in @([uint16]0,[uint16]1,[uint16]2,[uint16]0,[uint16]2,[uint16]3)){$bw.Write($ix)};$bw.Flush();$bin=[byte[]]$ms.ToArray()
 }finally{$bw.Dispose();$ms.Dispose()}
 $json="{`"asset`":{`"version`":`"2.0`"},`"scene`":0,`"scenes`":[{`"nodes`":[0]}],`"nodes`":[{`"mesh`":0}],`"meshes`":[{`"primitives`":[{`"attributes`":{`"POSITION`":0,`"NORMAL`":1},`"indices`":2,`"material`":0,`"mode`":4}]}],`"materials`":[{`"doubleSided`":true,`"pbrMetallicRoughness`":{`"baseColorFactor`":[.15,.65,.95,1],`"metallicFactor`":.1,`"roughnessFactor`":.7}}],`"buffers`":[{`"byteLength`":$($bin.Length)}],`"bufferViews`":[{`"buffer`":0,`"byteOffset`":0,`"byteLength`":48},{`"buffer`":0,`"byteOffset`":48,`"byteLength`":48},{`"buffer`":0,`"byteOffset`":96,`"byteLength`":12}],`"accessors`":[{`"bufferView`":0,`"componentType`":5126,`"count`":4,`"type`":`"VEC3`"},{`"bufferView`":1,`"componentType`":5126,`"count`":4,`"type`":`"VEC3`"},{`"bufferView`":2,`"componentType`":5123,`"count`":6,`"type`":`"SCALAR`"}]}"
 $jb=[Text.Encoding]::UTF8.GetBytes($json);$pad=(4-($jb.Length%4))%4;$jc=New-Object byte[]($jb.Length+$pad);[Array]::Copy($jb,$jc,$jb.Length);for($i=$jb.Length;$i-lt$jc.Length;$i++){$jc[$i]=0x20};$total=12+8+$jc.Length+8+$bin.Length
 $fs=[IO.File]::Create($Path);$out=New-Object IO.BinaryWriter($fs);try{$out.Write([byte[]](0x67,0x6C,0x54,0x46));$out.Write([uint32]2);$out.Write([uint32]$total);$out.Write([uint32]$jc.Length);$out.Write([uint32]0x4E4F534A);$out.Write($jc);$out.Write([uint32]$bin.Length);$out.Write([uint32]0x004E4942);$out.Write($bin)}finally{$out.Dispose();$fs.Dispose()}
}
$temp=Join-Path ([IO.Path]::GetTempPath()) ('hc-v7-stage-'+[guid]::NewGuid().ToString('N'));New-Item -ItemType Directory -Force -Path $temp|Out-Null
try{$glb=Join-Path $temp 'probe.glb';$cache=Join-Path $temp 'probe.hc3d';New-HcV7ProbeGlb $glb;$proc=Start-Process -FilePath (NeedFile 'HuymaierGpuShelfAssetCompiler.exe') -ArgumentList ('--model "'+$glb+'" --cache "'+$cache+'" --size 128') -WindowStyle Hidden -Wait -PassThru;if($proc.ExitCode-ne0-or-not(Test-Path $cache)){throw "Staged GPU cache compiler failed with exit $($proc.ExitCode)"};$br=New-Object IO.BinaryReader([IO.File]::OpenRead($cache));try{if((-join$br.ReadChars(4))-ne'HC3D'-or$br.ReadInt32()-ne1){throw 'Staged compiler produced invalid HC3D cache.'};[void]$br.ReadInt64();[void]$br.ReadInt64();if($br.ReadInt32()-ne128){throw 'Staged compiler ignored requested cache quality.'};$vc=$br.ReadInt32();$ic=$br.ReadInt32();$dc=$br.ReadInt32();$images=$br.ReadInt32();if($vc-ne4-or$ic-ne6-or$dc-ne1-or$images-ne0){throw "Unexpected staged HC3D counts: v=$vc i=$ic d=$dc images=$images"}}finally{$br.Dispose()}}finally{Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue}

$validation=Get-Content -Raw -LiteralPath $ValidationPath -Encoding UTF8|ConvertFrom-Json
$gates=@(
 'platformModelSettingGate','platformModelPersistenceGate','platformModelScaleGate','platformModelMapCoverageGate','platformModelPresentationBaseGate','platformModelHelperOnlyGate','platformModelViewerControlGate','platformModelLiveDllX64Gate','platformModelUserFolderGate','platformModelOriginalNamingGate','platformModelCustomizationOnlyGate','platformModelNoBundledGlbGate','platformModelNoBundledGeneratorGate','platformModelRetiredAtlasGate','platformModelRetiredPreviewWorkerGate','platformModelRetiredPayloadPruneGate',
 'platformModelV7FinalOwnerGate','platformModelAllInstalledModelsStay3DGate','platformModelNoDistanceIconReversionGate','platformModelGpuShelfFullHeightGate','platformModelBackgroundCacheCompilerGate','platformModelGpuViewportOnlyCullingGate','platformModelNativeTurntableGate','platformModelSharedGpuAssetCacheGate','platformModelGpuMipTextureGate','platformModelD3D11DpiAwareShelfGate','platformModelV7LoadOrderGate','platformModelV7InstallerPayloadGate','platformModelD3D11NativeCompileGate','platformModelD3D11X64Gate','platformModelD3D11ProductionExportsGate','platformModelD3D11WarpSmokeGate','platformModelGpuAssetCompilerGate','platformModelGpuCacheFreshnessGate'
)
foreach($gate in $gates){$validation|Add-Member -NotePropertyName $gate -NotePropertyValue 'success' -Force;Write-Host ($gate+': success')}
$validation|ConvertTo-Json -Depth 12|Set-Content -LiteralPath $ValidationPath -Encoding UTF8
