Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$probe=Join-Path $root 'Native\HuymaierD3D11UvAddressSmoke.cpp'
$runtime=Join-Path $root 'Native\HuymaierD3D11ShelfRuntime.cpp'
foreach($p in @($probe,$runtime)){if(-not(Test-Path -LiteralPath $p -PathType Leaf)){throw "D3D11 UV-addressing source missing: $p"}}

$runtimeText=Get-Content -Raw -LiteralPath $runtime -Encoding UTF8
foreach($contract in @(
    'BaseTexture.Sample(BaseSampler, i.uv0)',
    'EmissiveTexture.Sample(EmissiveSampler,i.uv1)',
    'MetallicRoughnessTexture.Sample(MetallicRoughnessSampler,i.uv2)',
    'NormalTexture.Sample(NormalSampler,i.uv3)',
    'OcclusionTexture.Sample(OcclusionSampler,i.uv4)',
    'D3D11_TEXTURE_ADDRESS_CLAMP',
    'D3D11_TEXTURE_ADDRESS_MIRROR',
    'D3D11_TEXTURE_ADDRESS_WRAP')){
    if($runtimeText.IndexOf($contract,[StringComparison]::Ordinal)-lt0){throw "Production D3D11 UV/sampler contract missing: $contract"}
}

foreach($forbidden in @('1.0 - i.uv0.y','1.0 - i.uv1.y','float2 cachedUv')){
    if($runtimeText.IndexOf($forbidden,[StringComparison]::Ordinal)-ge0){throw "HC3D v3 reintroduced hidden UV inversion: $forbidden"}
}

$vswhere=Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
if(-not(Test-Path -LiteralPath $vswhere -PathType Leaf)){throw 'vswhere.exe unavailable.'}
$vsInstall=(& $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath|Select-Object -First 1)
if([string]::IsNullOrWhiteSpace([string]$vsInstall)){throw 'Visual C++ x64 tools unavailable.'}
$vcvars=Join-Path $vsInstall 'VC\Auxiliary\Build\vcvars64.bat'
$tempRoot=$(if($env:RUNNER_TEMP){$env:RUNNER_TEMP}else{[IO.Path]::GetTempPath()})
$temp=Join-Path $tempRoot ('hc-uv-address-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $temp|Out-Null
try{
    $dll=Join-Path $temp 'HuymaierD3D11UvAddressSmoke.dll'
    $cmd=Join-Path $temp 'build.cmd'
    $body=@"
@echo off
call "$vcvars" >nul
if errorlevel 1 exit /b %errorlevel%
cl.exe /nologo /LD /O2 /EHsc /std:c++17 /MD "$probe" /link /OUT:"$dll" d3d11.lib d3dcompiler.lib dxgi.lib
exit /b %errorlevel%
"@
    Set-Content -LiteralPath $cmd -Value $body -Encoding ASCII
    & cmd.exe /d /c ('"'+$cmd+'"')
    if($LASTEXITCODE-ne0-or-not(Test-Path -LiteralPath $dll -PathType Leaf)){throw 'D3D11 UV-addressing x64 probe build failed.'}
    $bytes=[IO.File]::ReadAllBytes($dll);$pe=[BitConverter]::ToInt32($bytes,0x3C);$machine=[BitConverter]::ToUInt16($bytes,$pe+4)
    if($machine-ne0x8664){throw 'D3D11 UV-addressing probe is not x64.'}
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class HcUvAddressProbe {
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode)] public static extern bool SetDllDirectory(string path);
 [DllImport("HuymaierD3D11UvAddressSmoke.dll",CallingConvention=CallingConvention.Cdecl)] public static extern int HC_D3D11UvAddressSmokeTest();
}
'@
    if(-not[HcUvAddressProbe]::SetDllDirectory($temp)){throw 'Could not set UV-addressing native search path.'}
    $result=[HcUvAddressProbe]::HC_D3D11UvAddressSmokeTest()
    if($result-ne1){throw "D3D11 UV/sampler pixel test failed with code $result"}
    Write-Host 'platformModelUvRepeatPixelGate: success'
    Write-Host 'platformModelUvClampPixelGate: success'
    Write-Host 'platformModelUvMirroredRepeatPixelGate: success'
    Write-Host 'platformModelUvTransformPixelGate: success'
    Write-Host 'platformModelUvHc3dV3DirectGltfGate: success'
}finally{
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
