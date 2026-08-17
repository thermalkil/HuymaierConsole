Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$assetH=Join-Path $root 'Native\HuymaierD3D11ShelfAsset.h'
$assetCpp=Join-Path $root 'Native\HuymaierD3D11ShelfAsset.cpp'
$smokeCpp=Join-Path $root 'Native\HuymaierD3D11ShelfAssetSmoke.cpp'
foreach($p in @($assetH,$assetCpp,$smokeCpp)){if(-not(Test-Path -LiteralPath $p -PathType Leaf)){throw "Cached-model D3D11 source missing: $p"}}
foreach($pair in @(@($assetH,'HUYMAIER_D3D11_GPU_ASSET_V4'),@($assetH,'HUYMAIER_D3D11_SHELF_SHADER_V6_VERTEX_COLOR_UI_PBR'),@($assetH,'float4 color:COLOR0'),@($assetH,'vertexColor.rgb'),@($assetCpp,'version!=4'),@($assetCpp,'GenerateMips'),@($smokeCpp,'HUYMAIER_D3D11_CACHED_ASSET_SMOKE_V3'),@($smokeCpp,'HC_D3D11CachedAssetSmokeTest'),@($smokeCpp,'{"COLOR",0,DXGI_FORMAT_R32G32B32A32_FLOAT,0,80'))){if((Get-Content -Raw -LiteralPath $pair[0] -Encoding UTF8).IndexOf($pair[1],[StringComparison]::Ordinal)-lt0){throw "Cached-model D3D11 v4 contract missing: $($pair[1])"}}

$vswhere=Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
$vsInstall=(& $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath|Select-Object -First 1)
if([string]::IsNullOrWhiteSpace([string]$vsInstall)){throw 'Visual C++ x64 tools unavailable.'}
$vcvars=Join-Path $vsInstall 'VC\Auxiliary\Build\vcvars64.bat'
$temp=Join-Path $(if($env:RUNNER_TEMP){$env:RUNNER_TEMP}else{[IO.Path]::GetTempPath()}) ('hc-cached-gpu-v4-'+[guid]::NewGuid().ToString('N'));New-Item -ItemType Directory -Force -Path $temp|Out-Null

function New-Hc3dV4Probe {
    param([string]$Path,[bool]$Textured=$false,[int]$AlphaMode=0,[single]$BaseAlpha=1.0,[bool]$VertexColorOnly=$false)
    $fs=[IO.File]::Create($Path);$bw=New-Object IO.BinaryWriter($fs)
    try{
        $imageCount=if($Textured){1}else{0}
        $baseImage=if($Textured){0}else{-1}
        $bw.Write([byte[]](0x48,0x43,0x33,0x44));$bw.Write([int32]4);$bw.Write([int64]4096);$bw.Write([int64]638909000000000000);$bw.Write([int32]512)
        $bw.Write([int32]4);$bw.Write([int32]6);$bw.Write([int32]1);$bw.Write([int32]$imageCount)
        foreach($f in @([single]-1,[single]-0.65,[single]0,[single]1,[single]0.65,[single]0)){$bw.Write($f)}
        $verts=@(
            @(-1.0,-0.65,0.0, 0.0,0.0,-1.0, 1.0,0.0,0.0,1.0, 0.0,0.0),
            @( 1.0,-0.65,0.0, 0.0,0.0,-1.0, 1.0,0.0,0.0,1.0, 1.0,0.0),
            @( 1.0, 0.65,0.0, 0.0,0.0,-1.0, 1.0,0.0,0.0,1.0, 1.0,1.0),
            @(-1.0, 0.65,0.0, 0.0,0.0,-1.0, 1.0,0.0,0.0,1.0, 0.0,1.0)
        )
        $vertexColor=$(if($VertexColorOnly){@([single]0.61,[single]0.03,[single]0.86,[single]1)}else{@([single]1,[single]1,[single]1,[single]1)})
        foreach($v in $verts){
            # position3 + normal3 + tangent4 + five UV pairs + COLOR_0 RGBA = 24 floats / 96 bytes.
            foreach($f in $v){$bw.Write([single]$f)}
            $u=[single]$v[10];$vv=[single]$v[11]
            for($set=1;$set-le4;$set++){$bw.Write($u);$bw.Write($vv)}
            foreach($f in $vertexColor){$bw.Write([single]$f)}
        }
        foreach($i in @(0,1,2,0,2,3)){$bw.Write([uint32]$i)}
        $bw.Write([int32]0);$bw.Write([int32]6)
        $bw.Write([int32]$baseImage)
        foreach($image in @(-1,-1,-1,-1)){$bw.Write([int32]$image)}
        if($Textured-or$VertexColorOnly){foreach($f in @([single]1,[single]1,[single]1,$BaseAlpha)){$bw.Write($f)}}else{foreach($f in @([single]0.43,[single]0.14,[single]0.70,$BaseAlpha)){$bw.Write($f)}}
        foreach($f in @([single]0,[single]0,[single]0,[single]1)){$bw.Write($f)}
        foreach($f in @([single]0.18,[single]0.48,[single]1,[single]0,[single]1,[single]1)){$bw.Write($f)}
        for($i=0;$i-lt10;$i++){$bw.Write([int32]10497)}
        $bw.Write([int32]$AlphaMode);$bw.Write([single]0.5);$bw.Write([int32]0)
        if($Textured){
            $w=64;$h=32;$bytes=$w*$h*4;$bw.Write([int32]$w);$bw.Write([int32]$h);$bw.Write([int32]$bytes)
            for($y=0;$y-lt$h;$y++){for($x=0;$x-lt$w;$x++){
                if($x-lt($w/2)){$b=35;$g=42;$r=238}else{$b=228;$g=45;$r=45}
                $bw.Write([byte]$b);$bw.Write([byte]$g);$bw.Write([byte]$r);$bw.Write([byte]255)
            }}
        }
    }finally{$bw.Dispose();$fs.Dispose()}
}

try{
    $opaque=Join-Path $temp 'opaque-purple.hc3d';New-Hc3dV4Probe -Path $opaque -Textured:$false -AlphaMode 0 -BaseAlpha ([single]0.25)
    $mask=Join-Path $temp 'mask-purple.hc3d';New-Hc3dV4Probe -Path $mask -Textured:$false -AlphaMode 1 -BaseAlpha ([single]0.80)
    $textured=Join-Path $temp 'textured.hc3d';New-Hc3dV4Probe -Path $textured -Textured:$true -AlphaMode 0 -BaseAlpha ([single]1)
    # GOG-style regression: material base color is white and all visible hue exists only in COLOR_0.
    $vertexOnly=Join-Path $temp 'vertex-color-purple.hc3d';New-Hc3dV4Probe -Path $vertexOnly -Textured:$false -AlphaMode 0 -BaseAlpha ([single]1) -VertexColorOnly:$true

    $dll=Join-Path $temp 'HuymaierD3D11CachedSmoke.dll';$cmd=Join-Path $temp 'build.cmd';$nativeDir=Join-Path $root 'Native'
    $body=@"
@echo off
call "$vcvars" >nul
if errorlevel 1 exit /b %errorlevel%
cl.exe /nologo /LD /O2 /EHsc /std:c++17 /MD /I"$nativeDir" "$assetCpp" "$smokeCpp" /link /OUT:"$dll" d3d11.lib d3dcompiler.lib dxgi.lib user32.lib ole32.lib
exit /b %errorlevel%
"@
    Set-Content -LiteralPath $cmd -Value $body -Encoding ASCII;&cmd.exe /d /c ('"'+$cmd+'"');if($LASTEXITCODE-ne0-or-not(Test-Path $dll)){throw 'Cached-model D3D11 v4 x64 build failed.'}
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class HcCachedGpuProbeV4 {
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode)] public static extern bool SetDllDirectory(string path);
 [DllImport("HuymaierD3D11CachedSmoke.dll",CharSet=CharSet.Unicode,CallingConvention=CallingConvention.Cdecl)] public static extern int HC_D3D11CachedAssetSmokeTest(string path);
}
'@
    if(-not[HcCachedGpuProbeV4]::SetDllDirectory($temp)){throw 'Could not set cached-model native search path.'}
    foreach($case in @(
        [pscustomobject]@{Name='opaque textureless purple';Path=$opaque},
        [pscustomobject]@{Name='mask textureless purple';Path=$mask},
        [pscustomobject]@{Name='textured base color';Path=$textured},
        [pscustomobject]@{Name='COLOR_0-only purple';Path=$vertexOnly}
    )){
        $result=[HcCachedGpuProbeV4]::HC_D3D11CachedAssetSmokeTest([string]$case.Path)
        if($result-ne1){throw "Cached-model D3D11 v4 $($case.Name) pixel smoke failed with code $result"}
    }
    Write-Host 'platformModelD3D11CachedAssetV4LoadGate: success'
    Write-Host 'platformModelTexturelessBaseColorPixelGate: success'
    Write-Host 'platformModelOpaqueAlphaPixelGate: success'
    Write-Host 'platformModelMaskOpaquePixelGate: success'
    Write-Host 'platformModelD3D11CachedTexturePixelGate: success'
    Write-Host 'platformModelD3D11GpuTextureMipGate: success'
    Write-Host 'platformModelVertexColorPixelGate: success'
}finally{Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue}
