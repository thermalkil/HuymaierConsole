param(
    [Parameter(Mandatory=$true)][string]$CoreBuilderPath
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
if(-not(Test-Path -LiteralPath $CoreBuilderPath -PathType Leaf)){throw "GPU shelf builder input missing: $CoreBuilderPath"}

# HUYMAIER_HC3D_V4_VERTEX_COLOR_TRANSFORM_V1
# The real provider/model pack uses glTF COLOR_0 on models such as GOG. HC3D v3
# discarded that attribute, leaving the material's default white base color. Apply
# the v4 schema/runtime migration before source validation and before release staging
# so COLOR_0 survives compiler -> cache -> D3D11 input -> production pixel shader.
$repoRoot=Split-Path -Parent $PSScriptRoot
$nl=[Environment]::NewLine
function Replace-HcGpuExact {
    param([Parameter(Mandatory=$true)][string]$Path,[Parameter(Mandatory=$true)][string]$Old,[Parameter(Mandatory=$true)][string]$New,[Parameter(Mandatory=$true)][string]$Label)
    if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){throw "HC3D v4 transform source missing: $Path"}
    $text=Get-Content -Raw -LiteralPath $Path -Encoding UTF8
    if($text.Contains($New)){return}
    if(-not$text.Contains($Old)){throw "HC3D v4 transform anchor missing ($Label): $Path"}
    $text=$text.Replace($Old,$New)
    Set-Content -LiteralPath $Path -Value $text -Encoding UTF8
}

$compilerPath=Join-Path $repoRoot 'Native\HuymaierGpuShelfAssetCompiler.cs'
$assetHeaderPath=Join-Path $repoRoot 'Native\HuymaierD3D11ShelfAsset.h'
$assetCppPath=Join-Path $repoRoot 'Native\HuymaierD3D11ShelfAsset.cpp'
$runtimeCppPath=Join-Path $repoRoot 'Native\HuymaierD3D11ShelfRuntime.cpp'
$assetSmokePath=Join-Path $repoRoot 'Native\HuymaierD3D11ShelfAssetSmoke.cpp'
$gpuRuntimePath=Join-Path $repoRoot 'HuymaierGpuPlatformShelves.ps1'

Replace-HcGpuExact $compilerPath '// HUYMAIER_GPU_SHELF_ASSET_CACHE_V3' '// HUYMAIER_GPU_SHELF_ASSET_CACHE_V4' 'compiler schema marker'
Replace-HcGpuExact $compilerPath 'public const int CacheVersion = 3;' 'public const int CacheVersion = 4;' 'compiler cache version'
Replace-HcGpuExact $compilerPath '// 20 floats / 80 bytes. UVs are already transformed per material map:' '// 24 floats / 96 bytes. UVs are already transformed per material map; COLOR_0 is linear RGBA:' 'compiler vertex stride comment'
Replace-HcGpuExact $compilerPath '            public float U4, V4;' ('            public float U4, V4;'+$nl+'            public float Cr, Cg, Cb, Ca;') 'compiler vertex color fields'
Replace-HcGpuExact $compilerPath 'double[][] tangents=ReadAccessor(doc,JsonUtil.Int(attrs,"TANGENT",-1));' 'double[][] tangents=ReadAccessor(doc,JsonUtil.Int(attrs,"TANGENT",-1)); double[][] colors=ReadAccessor(doc,JsonUtil.Int(attrs,"COLOR_0",-1));' 'compiler COLOR_0 accessor'
Replace-HcGpuExact $compilerPath '                        if(mirrored)tw=-tw;' '                        if(mirrored)tw=-tw;float cr=1,cg=1,cb=1,ca=1;if(colors.Length==pos.Length&&colors[i].Length>=3){cr=(float)Math.Max(0,Math.Min(1,colors[i][0]));cg=(float)Math.Max(0,Math.Min(1,colors[i][1]));cb=(float)Math.Max(0,Math.Min(1,colors[i][2]));ca=colors[i].Length>3?(float)Math.Max(0,Math.Min(1,colors[i][3])):1f;}' 'compiler vertex color decode'
Replace-HcGpuExact $compilerPath 'U4=u4,V4=v4});' 'U4=u4,V4=v4,Cr=cr,Cg=cg,Cb=cb,Ca=ca});' 'compiler vertex color assignment'
Replace-HcGpuExact $compilerPath 'bw.Write(v.U4);bw.Write(v.V4);}' 'bw.Write(v.U4);bw.Write(v.V4);bw.Write(v.Cr);bw.Write(v.Cg);bw.Write(v.Cb);bw.Write(v.Ca);}' 'compiler vertex color serialization'

Replace-HcGpuExact $assetHeaderPath '    static const char* HcShelfShaderSource = R"HLSL('+$nl+'    // HUYMAIER_D3D11_SHELF_SHADER_V5_BALANCED_COLOR_PRESERVING_UI_PBR' ('    static const char* HcShelfShaderSource = R"HLSL('+$nl+'    // HUYMAIER_D3D11_SHELF_SHADER_V6_VERTEX_COLOR_UI_PBR'+$nl+'    // HUYMAIER_D3D11_SHELF_SHADER_V5_BALANCED_COLOR_PRESERVING_UI_PBR') 'shader v6 marker'
Replace-HcGpuExact $assetHeaderPath '        float2 uv4:TEXCOORD4;' ('        float2 uv4:TEXCOORD4;'+$nl+'        float4 color:COLOR0;') 'shader vertex color semantics'
Replace-HcGpuExact $assetHeaderPath '        o.uv0=v.uv0;o.uv1=v.uv1;o.uv2=v.uv2;o.uv3=v.uv3;o.uv4=v.uv4;' '        o.uv0=v.uv0;o.uv1=v.uv1;o.uv2=v.uv2;o.uv3=v.uv3;o.uv4=v.uv4;o.color=v.color;' 'shader vertex color forwarding'
Replace-HcGpuExact $assetHeaderPath '        float3 baseRgb=max(baseTextureLinear*BaseColor.rgb,0.0);' '        float4 vertexColor=saturate(i.color);'+$nl+'        float3 baseRgb=max(baseTextureLinear*BaseColor.rgb*vertexColor.rgb,0.0);' 'shader vertex color base multiplication'
Replace-HcGpuExact $assetHeaderPath '        float baseAlpha=saturate(sampledBase.a*BaseColor.a);' '        float baseAlpha=saturate(sampledBase.a*BaseColor.a*vertexColor.a);' 'shader vertex color alpha multiplication'
Replace-HcGpuExact $assetHeaderPath '    // HUYMAIER_D3D11_GPU_ASSET_V3' '    // HUYMAIER_D3D11_GPU_ASSET_V4' 'native asset schema marker'
Replace-HcGpuExact $assetHeaderPath '        float u4, v4;' ('        float u4, v4;'+$nl+'        float cr, cg, cb, ca;') 'native vertex color fields'

Replace-HcGpuExact $assetCppPath 'if(version!=3||quality<128' 'if(version!=4||quality<128' 'native cache version loader'
$layoutTail='            {"TEXCOORD",4,DXGI_FORMAT_R32G32_FLOAT,0,72,D3D11_INPUT_PER_VERTEX_DATA,0}};'
$layoutV4='            {"TEXCOORD",4,DXGI_FORMAT_R32G32_FLOAT,0,72,D3D11_INPUT_PER_VERTEX_DATA,0},'+$nl+'            {"COLOR",0,DXGI_FORMAT_R32G32B32A32_FLOAT,0,80,D3D11_INPUT_PER_VERTEX_DATA,0}};'
Replace-HcGpuExact $runtimeCppPath $layoutTail $layoutV4 'production D3D11 COLOR0 input layout'
Replace-HcGpuExact $assetSmokePath $layoutTail $layoutV4 'WARP D3D11 COLOR0 input layout'
Replace-HcGpuExact $gpuRuntimePath 'if($reader.ReadInt32()-ne3){return $false}' 'if($reader.ReadInt32()-ne4){return $false}' 'PowerShell HC3D v4 cache validator'

# Update regression gates that intentionally assert the active HC3D schema. These
# files are run after Prepare-v0265-PlatformModelValidation has invoked this transform.
$gpuV7Test=Join-Path $repoRoot '.development\v0.26.5\Test-v0265-GpuPlatformShelvesV7.ps1'
Replace-HcGpuExact $gpuV7Test "'version!=3'" "'version!=4'" 'V7 native cache version gate'
Replace-HcGpuExact $gpuV7Test "'HUYMAIER_GPU_SHELF_ASSET_CACHE_V3','CacheVersion = 3'" "'HUYMAIER_GPU_SHELF_ASSET_CACHE_V4','CacheVersion = 4','COLOR_0','Cr, Cg, Cb, Ca'" 'V7 compiler schema gate'
Replace-HcGpuExact $gpuV7Test 'Persistent HC3D v3' 'Persistent HC3D v4' 'V7 schema diagnostics'

$faceTest=Join-Path $repoRoot '.development\v0.26.5\Test-v0265-D3D11FaceCulling.ps1'
Replace-HcGpuExact $faceTest "'CacheVersion = 3'" "'CacheVersion = 4'" 'face-culling compiler version gate'

$mirrorTest=Join-Path $repoRoot '.development\v0.26.5\Test-v0265-MirroredModelWinding.ps1'
Replace-HcGpuExact $mirrorTest "'CacheVersion = 3'" "'CacheVersion = 4'" 'mirrored compiler version gate'
Replace-HcGpuExact $mirrorTest "if(`$br.ReadInt32()-ne3){throw 'Mirrored cache is not HC3D v3.'}" "if(`$br.ReadInt32()-ne4){throw 'Mirrored cache is not HC3D v4.'}" 'mirrored cache header gate'
Replace-HcGpuExact $mirrorTest '($vc*80)' '($vc*96)' 'mirrored v4 vertex stride'
Replace-HcGpuExact $mirrorTest 'platformModelHc3dV3CacheGate' 'platformModelHc3dV4CacheGate' 'mirrored cache gate name'

$candidateTest=Join-Path $repoRoot '.build\Test-HuymaierV0265PlatformModelsCandidate.ps1'
Replace-HcGpuExact $candidateTest 'New-HcV3ProbeGlb' 'New-HcV4ProbeGlb' 'staged compiler probe name'
Replace-HcGpuExact $candidateTest "'hc-v3-stage-'" "'hc-v4-stage-'" 'staged compiler temp name'
Replace-HcGpuExact $candidateTest "`$br.ReadInt32()-ne3){throw 'Staged compiler did not produce HC3D v3.'}" "`$br.ReadInt32()-ne4){throw 'Staged compiler did not produce HC3D v4.'}" 'staged compiler cache version'
Replace-HcGpuExact $candidateTest '($vc*80)' '($vc*96)' 'staged v4 vertex stride'
Replace-HcGpuExact $candidateTest 'Unexpected staged HC3D v3 counts' 'Unexpected staged HC3D v4 counts' 'staged v4 count diagnostic'
Replace-HcGpuExact $candidateTest 'Staged HC3D v3 mirrored winding mismatch' 'Staged HC3D v4 mirrored winding mismatch' 'staged v4 winding diagnostic'
Replace-HcGpuExact $candidateTest 'Staged HC3D v3 lost authored textureless baseColorFactor.' 'Staged HC3D v4 lost authored textureless baseColorFactor.' 'staged v4 material diagnostic'
Replace-HcGpuExact $candidateTest 'platformModelStagedHc3dV3Gate' 'platformModelStagedHc3dV4Gate' 'staged v4 validation gate'
Replace-HcGpuExact $candidateTest "@('HUYMAIER_D3D11_SHELF_SHADER_V4_COLOR_MANAGED_UI_PBR'" "@('HUYMAIER_D3D11_SHELF_SHADER_V6_VERTEX_COLOR_UI_PBR','HUYMAIER_D3D11_SHELF_SHADER_V4_COLOR_MANAGED_UI_PBR'" 'staged vertex-color shader marker'

$builder=Get-Content -Raw -LiteralPath $CoreBuilderPath -Encoding UTF8
if($builder -notmatch 'HUYMAIER_D3D11_GPU_SHELF_BINARY_BUILD_V1'){
    $anchor="if(`$LASTEXITCODE -ne 0 -or -not(Test-Path `$liveModelDll)){throw 'x64 HuymaierLiveModel3D.dll compilation failed.'}"
    if(-not$builder.Contains($anchor)){throw 'GPU shelf build requires live-model DLL build first.'}
    $block=$anchor+@'

# HUYMAIER_D3D11_GPU_SHELF_BINARY_BUILD_V1
$gpuRendererSource=Join-Path $stage 'Native\HuymaierD3D11ShelfRenderer.cpp'
$gpuRuntimeSource=Join-Path $stage 'Native\HuymaierD3D11ShelfRuntime.cpp'
$gpuAssetSource=Join-Path $stage 'Native\HuymaierD3D11ShelfAsset.cpp'
$gpuAssetHeader=Join-Path $stage 'Native\HuymaierD3D11ShelfAsset.h'
$gpuUvAddressSmokeSource=Join-Path $stage 'Native\HuymaierD3D11UvAddressSmoke.cpp'
$gpuHostSource=Join-Path $stage 'Native\HuymaierD3D11ShelfHost.cs'
$gpuCompilerSource=Join-Path $stage 'Native\HuymaierGpuShelfAssetCompiler.cs'
$gpuCompilerProgramSource=Join-Path $stage 'Native\HuymaierGpuShelfAssetCompilerProgram.cs'
foreach($gpuSource in @($gpuRendererSource,$gpuRuntimeSource,$gpuAssetSource,$gpuAssetHeader,$gpuUvAddressSmokeSource,$gpuHostSource,$gpuCompilerSource,$gpuCompilerProgramSource)){if(-not(Test-Path -LiteralPath $gpuSource -PathType Leaf)){throw "GPU shelf source missing: $gpuSource"}}

$gpuNativeDll=Join-Path $stage 'HuymaierD3D11ShelfRenderer.dll'
$gpuHostDll=Join-Path $stage 'HuymaierGpuShelfHost.dll'
$gpuCompilerExe=Join-Path $stage 'HuymaierGpuShelfAssetCompiler.exe'
$vswhere=Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
if(-not(Test-Path -LiteralPath $vswhere -PathType Leaf)){throw 'GPU shelf native build requires vswhere.exe.'}
$gpuVsInstall=(& $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath | Select-Object -First 1)
if([string]::IsNullOrWhiteSpace([string]$gpuVsInstall)){throw 'GPU shelf native build could not locate Visual C++ x64 tools.'}
$gpuVcvars=Join-Path $gpuVsInstall 'VC\Auxiliary\Build\vcvars64.bat'
if(-not(Test-Path -LiteralPath $gpuVcvars -PathType Leaf)){throw "GPU shelf vcvars64.bat missing: $gpuVcvars"}
$gpuBuildCmd=Join-Path $stage '.build-huymaier-gpu-shelf.cmd'
$gpuBuildText=@"
@echo off
call "$gpuVcvars" >nul
if errorlevel 1 exit /b %errorlevel%
pushd "$stage"
cl.exe /nologo /LD /O2 /EHsc /std:c++17 /MT /DUNICODE /D_UNICODE /I"$stage\Native" "$gpuRendererSource" "$gpuAssetSource" "$gpuRuntimeSource" "$gpuUvAddressSmokeSource" /link /OUT:"$gpuNativeDll" d3d11.lib d3d9.lib d3dcompiler.lib dxgi.lib user32.lib ole32.lib
set HC_GPU_RC=%ERRORLEVEL%
popd
exit /b %HC_GPU_RC%
"@
Set-Content -LiteralPath $gpuBuildCmd -Value $gpuBuildText -Encoding ASCII
& cmd.exe /d /c ('"'+$gpuBuildCmd+'"')
$gpuBuildResult=$LASTEXITCODE
Remove-Item -LiteralPath $gpuBuildCmd -Force -ErrorAction SilentlyContinue
foreach($junk in @('HuymaierD3D11ShelfRenderer.lib','HuymaierD3D11ShelfRenderer.exp','HuymaierD3D11ShelfRenderer.obj','HuymaierD3D11ShelfAsset.obj','HuymaierD3D11ShelfRuntime.obj','HuymaierD3D11UvAddressSmoke.obj')){Remove-Item -LiteralPath (Join-Path $stage $junk) -Force -ErrorAction SilentlyContinue}
if($gpuBuildResult -ne 0 -or -not(Test-Path -LiteralPath $gpuNativeDll -PathType Leaf)){throw 'x64 HuymaierD3D11ShelfRenderer.dll compilation failed.'}

$gpuFramework=[Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()
$gpuRefs=@([Uri].Assembly.Location,[Linq.Enumerable].Assembly.Location,[Web.Script.Serialization.JavaScriptSerializer].Assembly.Location,[ComponentModel.ISupportInitialize].Assembly.Location,[Windows.DependencyObject].Assembly.Location,[Windows.Media.Visual].Assembly.Location,[Windows.Window].Assembly.Location,(Join-Path $gpuFramework 'System.Xaml.dll'))|Select-Object -Unique
$gpuHostArgs=@('/noconfig','/nologo','/target:library','/platform:x64','/optimize+',('/out:'+$gpuHostDll))
foreach($r in $gpuRefs){if(-not(Test-Path -LiteralPath $r -PathType Leaf)){throw "GPU shelf managed reference missing: $r"};$gpuHostArgs+=('/reference:'+$r)}
$gpuHostArgs+=$gpuHostSource
& $csc @gpuHostArgs
if($LASTEXITCODE -ne 0 -or -not(Test-Path -LiteralPath $gpuHostDll -PathType Leaf)){throw 'x64 HuymaierGpuShelfHost.dll compilation failed.'}

$gpuCompilerArgs=@('/noconfig','/nologo','/target:exe','/platform:x64','/optimize+','/main:HuymaierConsole.Modeling.GpuShelfAssetCompilerProgram',('/out:'+$gpuCompilerExe))
foreach($r in $gpuRefs){$gpuCompilerArgs+=('/reference:'+$r)}
$gpuCompilerArgs+=@($modelLoaderSource,$modelAliasesSource,$gpuCompilerSource,$gpuCompilerProgramSource)
& $csc @gpuCompilerArgs
if($LASTEXITCODE -ne 0 -or -not(Test-Path -LiteralPath $gpuCompilerExe -PathType Leaf)){throw 'x64 HuymaierGpuShelfAssetCompiler.exe compilation failed.'}
'@
    $builder=$builder.Replace($anchor,$block)

    $archAnchor=@'
$liveModelHeaders=(& $dumpbin /nologo /headers $liveModelDll) -join "`n";if($liveModelHeaders -notmatch '(?i)machine \(x64\)|8664 machine'){throw 'HuymaierLiveModel3D.dll is not x64.'}
'@
    if(-not$builder.Contains($archAnchor)){throw 'GPU shelf build could not find live-model architecture gate.'}
    $arch=$archAnchor+@'
$gpuNativeHeaders=(& $dumpbin /nologo /headers $gpuNativeDll) -join "`n";if($gpuNativeHeaders -notmatch '(?i)machine \(x64\)|8664 machine'){throw 'HuymaierD3D11ShelfRenderer.dll is not x64.'}
$gpuHostHeaders=(& $dumpbin /nologo /headers $gpuHostDll) -join "`n";if($gpuHostHeaders -notmatch '(?i)machine \(x64\)|8664 machine'){throw 'HuymaierGpuShelfHost.dll is not x64.'}
$gpuCompilerHeaders=(& $dumpbin /nologo /headers $gpuCompilerExe) -join "`n";if($gpuCompilerHeaders -notmatch '(?i)machine \(x64\)|8664 machine'){throw 'HuymaierGpuShelfAssetCompiler.exe is not x64.'}
$gpuExports=(& $dumpbin /nologo /exports $gpuNativeDll) -join "`n"
foreach($gpuExport in @('HC_D3D11UvAddressSmokeTest','HC_GPU_CreateShelfSurface','HC_GPU_LoadShelfModel','HC_GPU_SetShelfItem','HC_GPU_SetShelfItemView','HC_GPU_SetShelfBrightness','HC_GPU_RenderShelfSurface','HC_GPU_GetCachedAssetCount')){if($gpuExports -notmatch [regex]::Escape($gpuExport)){throw "HuymaierD3D11ShelfRenderer.dll missing production export: $gpuExport"}}
'@
    $builder=$builder.Replace($archAnchor,$arch)
}
Set-Content -LiteralPath $CoreBuilderPath -Value $builder -Encoding UTF8
