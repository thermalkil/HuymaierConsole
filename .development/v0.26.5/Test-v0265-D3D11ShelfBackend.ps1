Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$cpp=Join-Path $root 'Native\HuymaierD3D11ShelfRenderer.cpp'
$assetCpp=Join-Path $root 'Native\HuymaierD3D11ShelfAsset.cpp'
$assetH=Join-Path $root 'Native\HuymaierD3D11ShelfAsset.h'
$runtimeCpp=Join-Path $root 'Native\HuymaierD3D11ShelfRuntime.cpp'
$uvSmokeCpp=Join-Path $root 'Native\HuymaierD3D11UvAddressSmoke.cpp'
$hostSource=Join-Path $root 'Native\HuymaierD3D11ShelfHost.cs'
foreach($p in @($cpp,$assetCpp,$assetH,$runtimeCpp,$uvSmokeCpp,$hostSource)){if(-not(Test-Path -LiteralPath $p -PathType Leaf)){throw "D3D11 shelf source missing: $p"}}
$cppText=Get-Content -Raw -LiteralPath $cpp -Encoding UTF8
$runtimeText=Get-Content -Raw -LiteralPath $runtimeCpp -Encoding UTF8
$assetText=Get-Content -Raw -LiteralPath $assetCpp -Encoding UTF8
$uvSmokeText=Get-Content -Raw -LiteralPath $uvSmokeCpp -Encoding UTF8
$hostText=Get-Content -Raw -LiteralPath $hostSource -Encoding UTF8
foreach($n in @('HC_D3D11SmokeTest','D3D11CreateDevice','Direct3DCreate9Ex','OpenSharedResource','D3D11_CREATE_DEVICE_BGRA_SUPPORT','D3DCompile')){if($cppText.IndexOf($n,[StringComparison]::Ordinal)-lt0){throw "Native D3D11 proof contract missing: $n"}}
foreach($n in @(
    'HUYMAIER_D3D11_SHARED_SHELF_RUNTIME_V3','HC_GPU_CreateShelfSurface','HC_GPU_LoadShelfModel','HC_GPU_SetShelfItem','HC_GPU_SetShelfItemView','HC_GPU_SetShelfBrightness','HC_GPU_RenderShelfSurface','HC_GPU_GetCachedAssetCount',
    'AcquireAssetLocked','GenerateMips','BaseTexture.Sample(BaseSampler, i.uv0)','EmissiveTexture.Sample(EmissiveSampler,i.uv1)','MetallicRoughnessTexture.Sample(MetallicRoughnessSampler,i.uv2)','NormalTexture.Sample(NormalSampler,i.uv3)','OcclusionTexture.Sample(OcclusionSampler,i.uv4)',
    'float alpha=Flags.z==2?saturate(base.a):1.0;','SV_IsFrontFace','D3D11_CULL_BACK','D3D11_CULL_NONE'
)){if(($runtimeText+$assetText).IndexOf($n,[StringComparison]::Ordinal)-lt0){throw "Production D3D11 v3 shelf contract missing: $n"}}
foreach($bad in @('1.0 - i.uv0.y','1.0 - i.uv1.y','version!=2')){if(($runtimeText+$assetText).IndexOf($bad,[StringComparison]::Ordinal)-ge0){throw "Production D3D11 v3 shelf retained obsolete contract: $bad"}}
foreach($n in @('HC_D3D11UvAddressSmokeTest','D3D11_TEXTURE_ADDRESS_WRAP','D3D11_TEXTURE_ADDRESS_CLAMP','D3D11_TEXTURE_ADDRESS_MIRROR','PixelEquals')){if($uvSmokeText.IndexOf($n,[StringComparison]::Ordinal)-lt0){throw "UV-addressing native smoke contract missing: $n"}}
foreach($n in @('HUYMAIER_D3D11_SHELF_HOST_V2','D3DImage','D3DResourceType.IDirect3DSurface9','CompositionTarget.Rendering','HC_GPU_LoadShelfModel','HC_GPU_SetShelfItem','HC_GPU_SetShelfItemView','SetItemView','ReplayState','LoadedModelCount')){if($hostText.IndexOf($n,[StringComparison]::Ordinal)-lt0){throw "Managed D3D11 bridge/shared-viewer contract missing: $n"}}

$tokens=$null;$errors=$null
[void][Management.Automation.Language.Parser]::ParseFile($PSCommandPath,[ref]$tokens,[ref]$errors)
if(@($errors).Count){throw "D3D11 validation script failed PowerShell parse: $(@($errors|ForEach-Object{$_.Message}) -join '; ')"}

$vswhere=Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
if(-not(Test-Path -LiteralPath $vswhere -PathType Leaf)){throw 'vswhere.exe is unavailable on the Windows validation runner.'}
$vsInstall=(& $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath | Select-Object -First 1)
if([string]::IsNullOrWhiteSpace([string]$vsInstall)){throw 'Visual C++ x64 build tools were not found.'}
$vcvars=Join-Path $vsInstall 'VC\Auxiliary\Build\vcvars64.bat'
if(-not(Test-Path -LiteralPath $vcvars -PathType Leaf)){throw "vcvars64.bat missing: $vcvars"}
$tempRoot=$(if($env:RUNNER_TEMP){$env:RUNNER_TEMP}else{[IO.Path]::GetTempPath()})
$temp=Join-Path $tempRoot ('hc-d3d11-shelf-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $temp|Out-Null
try{
    $nativeDll=Join-Path $temp 'HuymaierD3D11ShelfRenderer.dll'
    $cmdFile=Join-Path $temp 'build-native.cmd'
    $nativeDir=Join-Path $root 'Native'
    $cmd=@"
@echo off
call "$vcvars" >nul
if errorlevel 1 exit /b %errorlevel%
cl.exe /nologo /LD /O2 /EHsc /std:c++17 /MD /DUNICODE /D_UNICODE /I"$nativeDir" "$cpp" "$assetCpp" "$runtimeCpp" "$uvSmokeCpp" /link /OUT:"$nativeDll" d3d11.lib d3d9.lib d3dcompiler.lib dxgi.lib user32.lib ole32.lib
exit /b %errorlevel%
"@
    Set-Content -LiteralPath $cmdFile -Value $cmd -Encoding ASCII
    & cmd.exe /d /c ('"'+$cmdFile+'"')
    if($LASTEXITCODE-ne0-or-not(Test-Path -LiteralPath $nativeDll -PathType Leaf)){throw 'Native x64 production D3D11 shelf DLL compilation failed.'}

    $dumpbin=Get-ChildItem -LiteralPath (Join-Path $vsInstall 'VC\Tools\MSVC') -Filter dumpbin.exe -File -Recurse -ErrorAction SilentlyContinue|Where-Object{$_.FullName-match '\\Hostx64\\x64\\dumpbin\.exe$'}|Sort-Object FullName -Descending|Select-Object -First 1
    if(-not$dumpbin){throw 'x64 dumpbin.exe was not found.'}
    $headers=(& $dumpbin.FullName /nologo /headers $nativeDll)-join"`n"
    if($headers-notmatch'(?i)machine \(x64\)|8664 machine'){throw 'HuymaierD3D11ShelfRenderer.dll is not x64.'}
    $exports=(& $dumpbin.FullName /nologo /exports $nativeDll)-join"`n"
    foreach($name in @('HC_D3D11SmokeTest','HC_D3D11UvAddressSmokeTest','HC_GPU_CreateShelfSurface','HC_GPU_LoadShelfModel','HC_GPU_SetShelfItem','HC_GPU_SetShelfItemView','HC_GPU_SetShelfBrightness','HC_GPU_ClearShelfItems','HC_GPU_RenderShelfSurface','HC_GPU_ReleaseShelfSurfacePointer','HC_GPU_DestroyShelfSurface','HC_GPU_GetCachedAssetCount')){if($exports-notmatch[regex]::Escape($name)){throw "Production native shelf DLL export missing: $name"}}

    Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Xaml
    $csc=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
    if(-not(Test-Path -LiteralPath $csc -PathType Leaf)){throw 'Framework64 csc.exe was not found.'}
    $managedDll=Join-Path $temp 'HuymaierD3D11ShelfHost.dll'
    $framework=[Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()
    $refs=@([ComponentModel.ISupportInitialize].Assembly.Location,[Windows.DependencyObject].Assembly.Location,[Windows.Media.Visual].Assembly.Location,[Windows.Window].Assembly.Location,(Join-Path $framework 'System.Xaml.dll'))|Select-Object -Unique
    $args=@('/noconfig','/nologo','/target:library','/platform:x64','/optimize+',('/out:'+$managedDll))
    foreach($r in $refs){$args+=('/reference:'+$r)}
    $args+=$hostSource
    & $csc @args
    if($LASTEXITCODE-ne0-or-not(Test-Path -LiteralPath $managedDll -PathType Leaf)){throw 'Managed D3D11 WPF bridge compilation failed.'}

    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class HcNativeSearchPath {
  [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
  public static extern bool SetDllDirectory(string path);
  [DllImport("HuymaierD3D11ShelfRenderer.dll", CallingConvention=CallingConvention.Cdecl)]
  public static extern int HC_D3D11UvAddressSmokeTest();
}
'@
    if(-not[HcNativeSearchPath]::SetDllDirectory($temp)){throw 'Could not set native DLL search path for D3D11 smoke test.'}
    $gpuAssembly=[Reflection.Assembly]::LoadFrom($managedDll)
    $gpuType=$gpuAssembly.GetType('HuymaierConsole.Modeling.D3D11ShelfSurface',$false)
    if($null-eq$gpuType){throw 'LoadFrom GPU host assembly did not expose D3D11ShelfSurface.'}
    $smokeMethod=$gpuType.GetMethod('RunNativeSmokeTest',[Reflection.BindingFlags]'Public,Static')
    if($null-eq$smokeMethod){throw 'D3D11ShelfSurface.RunNativeSmokeTest was not found through loaded assembly.'}
    $viewMethod=$gpuType.GetMethod('SetItemView',[Reflection.BindingFlags]'Public,Instance')
    if($null-eq$viewMethod){throw 'D3D11ShelfSurface.SetItemView was not found through loaded assembly.'}
    $result=[int]$smokeMethod.Invoke($null,@())
    if([int]$result-ne1){throw "D3D11 shader/render/readback smoke test failed with code $result"}
    $uvResult=[HcNativeSearchPath]::HC_D3D11UvAddressSmokeTest()
    if([int]$uvResult-ne1){throw "D3D11 UV/sampler addressing pixel smoke failed with code $uvResult"}

    Write-Host 'platformModelD3D11NativeCompileGate: success'
    Write-Host 'platformModelD3D11X64Gate: success'
    Write-Host 'platformModelD3D11ShaderGate: success'
    Write-Host 'platformModelD3D11WarpSmokeGate: success'
    Write-Host 'platformModelD3D11PackagedUvExportGate: success'
    Write-Host 'platformModelD3D11PackagedUvPixelGate: success'
    Write-Host 'platformModelD3DImageBridgeV2CompileGate: success'
    Write-Host 'platformModelD3D11ProductionExportsGate: success'
    Write-Host 'platformModelD3D11SharedAssetCacheGate: success'
    Write-Host 'platformModelD3D11SharedViewerControlGate: success'
    Write-Host 'platformModelGpuHostLoadFromResolutionGate: success'
}finally{
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
