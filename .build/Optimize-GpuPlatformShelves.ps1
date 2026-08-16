param(
    [Parameter(Mandatory=$true)][string]$CoreBuilderPath
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
if(-not(Test-Path -LiteralPath $CoreBuilderPath -PathType Leaf)){throw "GPU shelf builder input missing: $CoreBuilderPath"}

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
$gpuHostSource=Join-Path $stage 'Native\HuymaierD3D11ShelfHost.cs'
$gpuCompilerSource=Join-Path $stage 'Native\HuymaierGpuShelfAssetCompiler.cs'
$gpuCompilerProgramSource=Join-Path $stage 'Native\HuymaierGpuShelfAssetCompilerProgram.cs'
foreach($gpuSource in @($gpuRendererSource,$gpuRuntimeSource,$gpuAssetSource,$gpuAssetHeader,$gpuHostSource,$gpuCompilerSource,$gpuCompilerProgramSource)){if(-not(Test-Path -LiteralPath $gpuSource -PathType Leaf)){throw "GPU shelf source missing: $gpuSource"}}

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
cl.exe /nologo /LD /O2 /EHsc /std:c++17 /MT /DUNICODE /D_UNICODE /I"$stage\Native" "$gpuRendererSource" "$gpuAssetSource" "$gpuRuntimeSource" /link /OUT:"$gpuNativeDll" d3d11.lib d3d9.lib d3dcompiler.lib dxgi.lib user32.lib ole32.lib
set HC_GPU_RC=%ERRORLEVEL%
popd
exit /b %HC_GPU_RC%
"@
Set-Content -LiteralPath $gpuBuildCmd -Value $gpuBuildText -Encoding ASCII
& cmd.exe /d /c ('"'+$gpuBuildCmd+'"')
$gpuBuildResult=$LASTEXITCODE
Remove-Item -LiteralPath $gpuBuildCmd -Force -ErrorAction SilentlyContinue
foreach($junk in @('HuymaierD3D11ShelfRenderer.lib','HuymaierD3D11ShelfRenderer.exp','HuymaierD3D11ShelfRenderer.obj','HuymaierD3D11ShelfAsset.obj','HuymaierD3D11ShelfRuntime.obj')){Remove-Item -LiteralPath (Join-Path $stage $junk) -Force -ErrorAction SilentlyContinue}
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
foreach($gpuExport in @('HC_GPU_CreateShelfSurface','HC_GPU_LoadShelfModel','HC_GPU_SetShelfItem','HC_GPU_RenderShelfSurface','HC_GPU_GetCachedAssetCount')){if($gpuExports -notmatch [regex]::Escape($gpuExport)){throw "HuymaierD3D11ShelfRenderer.dll missing production export: $gpuExport"}}
'@
    $builder=$builder.Replace($archAnchor,$arch)
}
Set-Content -LiteralPath $CoreBuilderPath -Value $builder -Encoding UTF8
