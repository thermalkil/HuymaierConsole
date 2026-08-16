Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$cpp=Join-Path $root 'Native\HuymaierD3D11ShelfRenderer.cpp'
$hostSource=Join-Path $root 'Native\HuymaierD3D11ShelfHost.cs'
foreach($p in @($cpp,$hostSource)){if(-not(Test-Path -LiteralPath $p -PathType Leaf)){throw "D3D11 shelf source missing: $p"}}
$cppText=Get-Content -Raw -LiteralPath $cpp -Encoding UTF8
$hostText=Get-Content -Raw -LiteralPath $hostSource -Encoding UTF8
foreach($n in @('HC_D3D11SmokeTest','HC_D3D11CreateWpfSurface','D3D11CreateDevice','Direct3DCreate9Ex','OpenSharedResource','D3D11_CREATE_DEVICE_BGRA_SUPPORT','D3DCompile')){if($cppText.IndexOf($n,[StringComparison]::Ordinal)-lt0){throw "Native D3D11 contract missing: $n"}}
foreach($n in @('HUYMAIER_D3D11_SHELF_HOST_V1','D3DImage','D3DResourceType.IDirect3DSurface9','CompositionTarget.Rendering','HC_D3D11RenderWpfSurface')){if($hostText.IndexOf($n,[StringComparison]::Ordinal)-lt0){throw "Managed D3D11 bridge contract missing: $n"}}

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
    $cmd=@"
@echo off
call "$vcvars" >nul
if errorlevel 1 exit /b %errorlevel%
cl.exe /nologo /LD /O2 /EHsc /std:c++17 /MD /DUNICODE /D_UNICODE "$cpp" /link /OUT:"$nativeDll" d3d11.lib d3d9.lib d3dcompiler.lib dxgi.lib user32.lib ole32.lib
exit /b %errorlevel%
"@
    Set-Content -LiteralPath $cmdFile -Value $cmd -Encoding ASCII
    & cmd.exe /d /c ('"'+$cmdFile+'"')
    if($LASTEXITCODE-ne0-or-not(Test-Path -LiteralPath $nativeDll -PathType Leaf)){throw 'Native x64 D3D11 shelf DLL compilation failed.'}

    $dumpbin=Get-ChildItem -LiteralPath (Join-Path $vsInstall 'VC\Tools\MSVC') -Filter dumpbin.exe -File -Recurse -ErrorAction SilentlyContinue|Where-Object{$_.FullName-match '\\Hostx64\\x64\\dumpbin\.exe$'}|Sort-Object FullName -Descending|Select-Object -First 1
    if(-not$dumpbin){throw 'x64 dumpbin.exe was not found.'}
    $headers=(& $dumpbin.FullName /nologo /headers $nativeDll)-join"`n"
    if($headers-notmatch'(?i)machine \(x64\)|8664 machine'){throw 'HuymaierD3D11ShelfRenderer.dll is not x64.'}

    Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Xaml
    $csc=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
    if(-not(Test-Path -LiteralPath $csc -PathType Leaf)){throw 'Framework64 csc.exe was not found.'}
    $managedDll=Join-Path $temp 'HuymaierD3D11ShelfHost.dll'
    $framework=[Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()
    $refs=@([Windows.DependencyObject].Assembly.Location,[Windows.Media.Visual].Assembly.Location,[Windows.Window].Assembly.Location,(Join-Path $framework 'System.Xaml.dll'))|Select-Object -Unique
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
}
'@
    if(-not[HcNativeSearchPath]::SetDllDirectory($temp)){throw 'Could not set native DLL search path for D3D11 smoke test.'}
    Add-Type -Path $managedDll
    $result=[HuymaierConsole.Modeling.D3D11ShelfSurface]::RunNativeSmokeTest()
    if([int]$result-ne1){throw "D3D11 shader/render/readback smoke test failed with code $result"}

    Write-Host 'platformModelD3D11NativeCompileGate: success'
    Write-Host 'platformModelD3D11X64Gate: success'
    Write-Host 'platformModelD3D11ShaderGate: success'
    Write-Host 'platformModelD3D11WarpSmokeGate: success'
    Write-Host 'platformModelD3DImageBridgeCompileGate: success'
}finally{
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
