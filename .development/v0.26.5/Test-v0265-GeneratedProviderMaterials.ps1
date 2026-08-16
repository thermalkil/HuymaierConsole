Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$generator=Join-Path $root 'Native\HuymaierBuiltInModelGenerator.cs'
$loader=Join-Path $root 'Native\HuymaierModelPreviewWorker.cs'
$aliases=Join-Path $root 'Native\HuymaierModelPreviewWpfAliases.cs'
$compiler=Join-Path $root 'Native\HuymaierGpuShelfAssetCompiler.cs'
$assetH=Join-Path $root 'Native\HuymaierD3D11ShelfAsset.h'
$assetCpp=Join-Path $root 'Native\HuymaierD3D11ShelfAsset.cpp'
$smokeCpp=Join-Path $root 'Native\HuymaierD3D11ShelfAssetSmoke.cpp'
foreach($p in @($generator,$loader,$aliases,$compiler,$assetH,$assetCpp,$smokeCpp)){if(-not(Test-Path -LiteralPath $p -PathType Leaf)){throw "Generated-provider material source missing: $p"}}

Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Xaml,System.Web.Extensions
$csc=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if(-not(Test-Path -LiteralPath $csc -PathType Leaf)){throw 'Framework64 csc.exe missing.'}
$temp=Join-Path $(if($env:RUNNER_TEMP){$env:RUNNER_TEMP}else{[IO.Path]::GetTempPath()}) ('hc-generated-materials-'+[guid]::NewGuid().ToString('N'));New-Item -ItemType Directory -Force -Path $temp|Out-Null

function Read-GlbJson([string]$Path){
    $fs=[IO.File]::OpenRead($Path);$br=New-Object IO.BinaryReader($fs)
    try{
        if([Text.Encoding]::ASCII.GetString($br.ReadBytes(4))-ne'glTF'){throw "Invalid GLB: $Path"}
        if($br.ReadUInt32()-ne2){throw "Non-v2 GLB: $Path"};[void]$br.ReadUInt32()
        while($fs.Position+8-le$fs.Length){$len=$br.ReadUInt32();$type=$br.ReadUInt32();$data=$br.ReadBytes([int]$len);if($type-eq0x4E4F534A){return ([Text.Encoding]::UTF8.GetString($data).Trim([char]0,[char]32,[char]9,[char]13,[char]10)|ConvertFrom-Json)}}
        throw "GLB JSON chunk missing: $Path"
    }finally{$br.Dispose();$fs.Dispose()}
}

try{
    $genExe=Join-Path $temp 'HuymaierBuiltInModelGenerator.exe'
    & $csc /noconfig /nologo /target:exe /platform:x64 /optimize+ ('/out:'+$genExe) $generator
    if($LASTEXITCODE-ne0-or-not(Test-Path $genExe)){throw 'Built-in model generator failed compilation.'}
    $models=Join-Path $temp 'models';New-Item -ItemType Directory -Force -Path $models|Out-Null
    & $genExe --output $models
    if($LASTEXITCODE-ne0){throw 'Built-in model generator execution failed.'}
    $glbs=@(Get-ChildItem -LiteralPath $models -Filter '*.glb' -File|Sort-Object Name)
    if($glbs.Count-ne50){throw "Expected 50 generated GLBs, found $($glbs.Count)."}

    $materialCount=0
    foreach($file in $glbs){
        $json=Read-GlbJson $file.FullName
        if(@($json.nodes).Count-lt1){throw "$($file.Name) has no root node."}
        $rotation=@($json.nodes[0].rotation)
        if($rotation.Count-ne4-or[math]::Abs([double]$rotation[0])-gt.0001-or[math]::Abs([double]$rotation[1]-1)-gt.0001-or[math]::Abs([double]$rotation[2])-gt.0001-or[math]::Abs([double]$rotation[3])-gt.0001){throw "$($file.Name) does not face the default shelf camera through the audited 180-degree Y root rotation."}
        foreach($material in @($json.materials)){
            $materialCount++
            $alpha=[string]$material.alphaMode;if([string]::IsNullOrWhiteSpace($alpha)){$alpha='OPAQUE'}
            if($alpha-ne'OPAQUE'){throw "$($file.Name) generated material unexpectedly uses alphaMode=$alpha."}
            $factor=@($material.pbrMetallicRoughness.baseColorFactor)
            if($factor.Count-ne4){throw "$($file.Name) generated material has no RGBA baseColorFactor."}
            if([math]::Abs([double]$factor[3]-1)-gt.0001){throw "$($file.Name) generated material is unexpectedly translucent (alpha=$($factor[3]))."}
        }
    }
    if($materialCount-lt50){throw 'Generated material audit found too few material records.'}
    Write-Host "platformModelGeneratedAllOpaqueGate: success ($materialCount materials)"
    Write-Host 'platformModelGeneratedFrontOrientationGate: success'

    $gog=Join-Path $models 'gog.glb';$gogJson=Read-GlbJson $gog
    $purple=@($gogJson.materials|Where-Object{
        $f=@($_.pbrMetallicRoughness.baseColorFactor)
        $f.Count-eq4 -and [math]::Abs([double]$f[0]-.43)-lt.02 -and [math]::Abs([double]$f[1]-.14)-lt.02 -and [math]::Abs([double]$f[2]-.70)-lt.02
    })
    if($purple.Count-lt1){throw 'Generated GOG GLB lost its authored purple material.'}
    Write-Host 'platformModelGeneratedGogPurpleGlbGate: success'

    $framework=[Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory();$compilerDll=Join-Path $temp 'HuymaierGpuAssetCompiler.dll'
    $refs=@([Uri].Assembly.Location,[Linq.Enumerable].Assembly.Location,[Web.Script.Serialization.JavaScriptSerializer].Assembly.Location,[ComponentModel.ISupportInitialize].Assembly.Location,[Windows.DependencyObject].Assembly.Location,[Windows.Media.Visual].Assembly.Location,[Windows.Window].Assembly.Location,(Join-Path $framework 'System.Xaml.dll'))|Select-Object -Unique
    $args=@('/noconfig','/nologo','/target:library','/platform:x64','/optimize+',('/out:'+$compilerDll));foreach($r in $refs){$args+=('/reference:'+$r)};$args+=@($loader,$aliases,$compiler);&$csc @args
    if($LASTEXITCODE-ne0-or-not(Test-Path $compilerDll)){throw 'HC3D v3 compiler failed for generated-provider test.'};Add-Type -Path $compilerDll
    $cache=Join-Path $temp 'gog.hc3d';[HuymaierConsole.Modeling.GpuShelfAssetCompiler]::Compile($gog,$cache,512)

    $br=New-Object IO.BinaryReader([IO.File]::OpenRead($cache))
    try{
        if((-join$br.ReadChars(4))-ne'HC3D'-or$br.ReadInt32()-ne3){throw 'Generated GOG did not compile to HC3D v3.'}
        [void]$br.ReadInt64();[void]$br.ReadInt64();[void]$br.ReadInt32();$vc=$br.ReadInt32();$ic=$br.ReadInt32();$dc=$br.ReadInt32();$imageCount=$br.ReadInt32();for($i=0;$i-lt6;$i++){[void]$br.ReadSingle()}
        $br.BaseStream.Position+=($vc*80)+($ic*4)
        $foundPurple=$false
        for($d=0;$d-lt$dc;$d++){
            [void]$br.ReadInt32();[void]$br.ReadInt32();for($i=0;$i-lt5;$i++){[void]$br.ReadInt32()}
            $r=$br.ReadSingle();$g=$br.ReadSingle();$b=$br.ReadSingle();$a=$br.ReadSingle()
            for($i=0;$i-lt3;$i++){[void]$br.ReadSingle()};[void]$br.ReadSingle()
            for($i=0;$i-lt6;$i++){[void]$br.ReadSingle()};for($i=0;$i-lt10;$i++){[void]$br.ReadInt32()};$mode=$br.ReadInt32();[void]$br.ReadSingle();[void]$br.ReadInt32()
            if([math]::Abs($r-.43)-lt.02-and[math]::Abs($g-.14)-lt.02-and[math]::Abs($b-.70)-lt.02-and[math]::Abs($a-1)-lt.001-and$mode-eq0){$foundPurple=$true}
        }
        if(-not$foundPurple){throw 'GOG purple baseColorFactor did not survive into an OPAQUE HC3D v3 draw batch.'}
    }finally{$br.Dispose()}
    Write-Host 'platformModelGeneratedGogPurpleHc3dGate: success'

    $vswhere=Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe';$vs=(& $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath|Select-Object -First 1);if(-not$vs){throw 'MSVC x64 tools unavailable.'};$vcvars=Join-Path $vs 'VC\Auxiliary\Build\vcvars64.bat'
    $smokeDll=Join-Path $temp 'HuymaierD3D11CachedSmoke.dll';$cmd=Join-Path $temp 'build.cmd';$nativeDir=Join-Path $root 'Native'
    @"
@echo off
call "$vcvars" >nul
if errorlevel 1 exit /b %errorlevel%
cl.exe /nologo /LD /O2 /EHsc /std:c++17 /MD /I"$nativeDir" "$assetCpp" "$smokeCpp" /link /OUT:"$smokeDll" d3d11.lib d3dcompiler.lib dxgi.lib user32.lib ole32.lib
exit /b %errorlevel%
"@|Set-Content -LiteralPath $cmd -Encoding ASCII
    &cmd.exe /d /c ('"'+$cmd+'"');if($LASTEXITCODE-ne0-or-not(Test-Path $smokeDll)){throw 'Generated GOG WARP smoke build failed.'}
    Add-Type -TypeDefinition @'
using System;using System.Runtime.InteropServices;
public static class HcGeneratedMaterialProbe {
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode)] public static extern bool SetDllDirectory(string path);
 [DllImport("HuymaierD3D11CachedSmoke.dll",CharSet=CharSet.Unicode,CallingConvention=CallingConvention.Cdecl)] public static extern int HC_D3D11CachedAssetSmokeTest(string path);
}
'@
    [void][HcGeneratedMaterialProbe]::SetDllDirectory($temp)
    $result=[HcGeneratedMaterialProbe]::HC_D3D11CachedAssetSmokeTest($cache)
    if($result-ne1){throw "Generated GOG HC3D v3 WARP render failed with code $result"}
    Write-Host 'platformModelGeneratedGogPurpleWarpPixelGate: success'
}finally{Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue}
