Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$assetH=Join-Path $root 'Native\HuymaierD3D11ShelfAsset.h'
$assetCpp=Join-Path $root 'Native\HuymaierD3D11ShelfAsset.cpp'
$smokeCpp=Join-Path $root 'Native\HuymaierD3D11ShelfAssetSmoke.cpp'
foreach($p in @($assetH,$assetCpp,$smokeCpp)){if(-not(Test-Path -LiteralPath $p -PathType Leaf)){throw "Cached-model D3D11 source missing: $p"}}
foreach($pair in @(@($assetH,'HUYMAIER_D3D11_GPU_ASSET_V1'),@($assetCpp,'GenerateMips'),@($smokeCpp,'HC_D3D11CachedAssetSmokeTest'))){if((Get-Content -Raw -LiteralPath $pair[0] -Encoding UTF8).IndexOf($pair[1],[StringComparison]::Ordinal)-lt0){throw "Cached-model D3D11 contract missing: $($pair[1])"}}

$vswhere=Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
$vsInstall=(& $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath|Select-Object -First 1)
if([string]::IsNullOrWhiteSpace([string]$vsInstall)){throw 'Visual C++ x64 tools unavailable.'}
$vcvars=Join-Path $vsInstall 'VC\Auxiliary\Build\vcvars64.bat'
$temp=Join-Path $(if($env:RUNNER_TEMP){$env:RUNNER_TEMP}else{[IO.Path]::GetTempPath()}) ('hc-cached-gpu-'+[guid]::NewGuid().ToString('N'));New-Item -ItemType Directory -Force -Path $temp|Out-Null
function New-Hc3dProbe([string]$Path){
    $fs=[IO.File]::Create($Path);$bw=New-Object IO.BinaryWriter($fs)
    try{
        $bw.Write([byte[]](0x48,0x43,0x33,0x44));$bw.Write([int32]1);$bw.Write([int64]4096);$bw.Write([int64]638909000000000000);$bw.Write([int32]512)
        $bw.Write([int32]4);$bw.Write([int32]6);$bw.Write([int32]1);$bw.Write([int32]1)
        foreach($f in @([single](-1),[single](-0.65),[single]0,[single]1,[single](0.65),[single]0)){$bw.Write($f)}
        $verts=@(
            @(-1.0,-.65,0.0, 0.0,0.0,-1.0, 0.0,1.0, 0.0,1.0),
            @( 1.0,-.65,0.0, 0.0,0.0,-1.0, 1.0,1.0, 1.0,1.0),
            @( 1.0, .65,0.0, 0.0,0.0,-1.0, 1.0,0.0, 1.0,0.0),
            @(-1.0, .65,0.0, 0.0,0.0,-1.0, 0.0,0.0, 0.0,0.0)
        )
        foreach($v in $verts){foreach($f in $v){$bw.Write([single]$f)}}
        foreach($i in @(0,1,2,0,2,3)){$bw.Write([uint32]$i)}
        $bw.Write([int32]0);$bw.Write([int32]6);$bw.Write([int32]0);$bw.Write([int32]-1)
        foreach($f in @(1,1,1,1, 0,0,0,1, .15,.72,1,0)){$bw.Write([single]$f)}
        foreach($i in @(10497,10497,10497,10497,0)){$bw.Write([int32]$i)};$bw.Write([single](0.5));$bw.Write([int32]1)
        $w=64;$h=32;$bytes=$w*$h*4;$bw.Write([int32]$w);$bw.Write([int32]$h);$bw.Write([int32]$bytes)
        for($y=0;$y-lt$h;$y++){for($x=0;$x-lt$w;$x++){if($x-lt($w/2)){$b=25;$g=48;$r=235}else{$b=225;$g=58;$r=28};$bw.Write([byte]$b);$bw.Write([byte]$g);$bw.Write([byte]$r);$bw.Write([byte]255)}}
    }finally{$bw.Dispose();$fs.Dispose()}
}
try{
    $cache=Join-Path $temp 'probe.hc3d';New-Hc3dProbe $cache
    $dll=Join-Path $temp 'HuymaierD3D11CachedSmoke.dll';$cmd=Join-Path $temp 'build.cmd'
    $nativeDir=Join-Path $root 'Native'
    $body=@"
@echo off
call "$vcvars" >nul
if errorlevel 1 exit /b %errorlevel%
cl.exe /nologo /LD /O2 /EHsc /std:c++17 /MD /I"$nativeDir" "$assetCpp" "$smokeCpp" /link /OUT:"$dll" d3d11.lib d3dcompiler.lib dxgi.lib user32.lib ole32.lib
exit /b %errorlevel%
"@
    Set-Content -LiteralPath $cmd -Value $body -Encoding ASCII;&cmd.exe /d /c ('"'+$cmd+'"');if($LASTEXITCODE-ne0-or-not(Test-Path $dll)){throw 'Cached-model D3D11 x64 build failed.'}
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class HcCachedGpuProbe {
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode)] public static extern bool SetDllDirectory(string path);
 [DllImport("HuymaierD3D11CachedSmoke.dll",CharSet=CharSet.Unicode,CallingConvention=CallingConvention.Cdecl)] public static extern int HC_D3D11CachedAssetSmokeTest(string path);
}
'@
    if(-not[HcCachedGpuProbe]::SetDllDirectory($temp)){throw 'Could not set cached-model native search path.'}
    $result=[HcCachedGpuProbe]::HC_D3D11CachedAssetSmokeTest($cache)
    if($result-ne1){throw "Cached-model D3D11 texture/shader smoke failed with code $result"}
    Write-Host 'platformModelD3D11CachedAssetLoadGate: success'
    Write-Host 'platformModelD3D11GpuBufferGate: success'
    Write-Host 'platformModelD3D11GpuTextureMipGate: success'
    Write-Host 'platformModelD3D11CachedTexturePixelGate: success'
}finally{Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue}
