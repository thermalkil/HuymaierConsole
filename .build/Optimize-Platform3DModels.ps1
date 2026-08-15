param(
    [Parameter(Mandatory=$true)][string]$CorePath,
    [Parameter(Mandatory=$true)][string]$BootstrapPath,
    [Parameter(Mandatory=$true)][string]$InstallerScriptPath,
    [Parameter(Mandatory=$true)][string]$CoreBuilderPath
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
foreach($path in @($CorePath,$BootstrapPath,$InstallerScriptPath,$CoreBuilderPath)){if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "Platform-model transform input missing: $path"}}

$core=Get-Content -Raw -LiteralPath $CorePath -Encoding UTF8
if($core -notmatch 'HUYMAIER_PLATFORM_3D_MODELS_RUNTIME_V1'){
    $pathNeedle='$script:CustomizationModulePath = Join-Path $script:BaseDir ''HuymaierCustomization.ps1'''
    if(-not $core.Contains($pathNeedle)){throw 'Platform models could not find customization module path.'}
    $core=$core.Replace($pathNeedle,$pathNeedle+"`r`n`$script:PlatformModelsModulePath = Join-Path `$script:BaseDir 'HuymaierPlatformModels.ps1'")
    $loadNeedle=@'
if (Test-Path -LiteralPath $script:CustomizationModulePath) {
    try { . $script:CustomizationModulePath }
    catch { Write-Log "Customization module load failed: $($_.Exception.Message)" 'ERROR' }
}
'@
    if(-not $core.Contains($loadNeedle)){throw 'Platform models could not find customization module load block.'}
    $loadBlock=@'
if (Test-Path -LiteralPath $script:CustomizationModulePath) {
    try { . $script:CustomizationModulePath }
    catch { Write-Log "Customization module load failed: $($_.Exception.Message)" 'ERROR' }
}

# HUYMAIER_PLATFORM_3D_MODELS_RUNTIME_V1
if (Test-Path -LiteralPath $script:PlatformModelsModulePath) {
    try { . $script:PlatformModelsModulePath }
    catch { Write-Log "Platform 3D model module load failed: $($_.Exception.Message)" 'ERROR' }
}
'@
    $core=$core.Replace($loadNeedle,$loadBlock)
    Set-Content -LiteralPath $CorePath -Value $core -Encoding UTF8
}

$bootstrap=Get-Content -Raw -LiteralPath $BootstrapPath -Encoding UTF8
if($bootstrap -notmatch 'HUYMAIER_PLATFORM_3D_MODELS_PREFLIGHT_V1'){
    $pathNeedle='$unifiedCursorPath=Join-Path $baseDir ''HuymaierUnifiedCursor.ps1'''
    if(-not $bootstrap.Contains($pathNeedle)){throw 'Platform models require unified-cursor bootstrap preflight first.'}
    $bootstrap=$bootstrap.Replace($pathNeedle,$pathNeedle+"`r`n# HUYMAIER_PLATFORM_3D_MODELS_PREFLIGHT_V1`r`n`$platformModelsPath=Join-Path `$baseDir 'HuymaierPlatformModels.ps1'")
    $entryNeedle="        [pscustomobject]@{Path=`$unifiedCursorPath;Label='Unified cursor runtime'},"
    if(-not $bootstrap.Contains($entryNeedle)){throw 'Platform models could not find unified cursor preflight entry.'}
    $bootstrap=$bootstrap.Replace($entryNeedle,$entryNeedle+"`r`n        [pscustomobject]@{Path=`$platformModelsPath;Label='Platform 3D model runtime'},")
    Set-Content -LiteralPath $BootstrapPath -Value $bootstrap -Encoding UTF8
}

$installer=Get-Content -Raw -LiteralPath $InstallerScriptPath -Encoding UTF8
if($installer -notmatch 'HUYMAIER_PLATFORM_3D_MODELS_INSTALLER_CACHE_V1'){
    $entryNeedle="            'HuymaierUnifiedCursor.ps1',"
    if(-not $installer.Contains($entryNeedle)){throw 'Platform models could not find unified cursor installer-cache entry.'}
    $installer=$installer.Replace($entryNeedle,$entryNeedle+"`r`n            # HUYMAIER_PLATFORM_3D_MODELS_INSTALLER_CACHE_V1`r`n            'HuymaierPlatformModels.ps1',")
    Set-Content -LiteralPath $InstallerScriptPath -Value $installer -Encoding UTF8
}

$builder=Get-Content -Raw -LiteralPath $CoreBuilderPath -Encoding UTF8
if($builder -notmatch 'HUYMAIER_PLATFORM_3D_MODEL_WORKER_BUILD_V1'){
    $compileNeedle=@'
& $csc @unifiedArgs
if($LASTEXITCODE -ne 0 -or -not(Test-Path $unifiedCursorExe)){throw 'x64 HuymaierUnifiedCursorHost.exe compilation failed.'}
'@
    if(-not $builder.Contains($compileNeedle)){throw 'Platform models require unified cursor worker compile block first.'}
    $compileBlock=@'
& $csc @unifiedArgs
if($LASTEXITCODE -ne 0 -or -not(Test-Path $unifiedCursorExe)){throw 'x64 HuymaierUnifiedCursorHost.exe compilation failed.'}

# HUYMAIER_PLATFORM_3D_MODEL_WORKER_BUILD_V1
$modelPreviewSource=Join-Path $stage 'Native\HuymaierModelPreviewWorker.cs'
$modelPreviewAliases=Join-Path $stage 'Native\HuymaierModelPreviewWpfAliases.cs'
$modelPreviewExe=Join-Path $stage 'HuymaierModelPreviewWorker.exe'
foreach($modelSource in @($modelPreviewSource,$modelPreviewAliases)){if(-not(Test-Path -LiteralPath $modelSource -PathType Leaf)){throw "Platform model preview worker source missing: $modelSource"}}
$modelFramework=[Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()
$modelRefs=@([Uri].Assembly.Location,[Linq.Enumerable].Assembly.Location,[Web.Script.Serialization.JavaScriptSerializer].Assembly.Location,[Windows.DependencyObject].Assembly.Location,[Windows.Media.Visual].Assembly.Location,[Windows.Window].Assembly.Location,(Join-Path $modelFramework 'System.Xaml.dll'))|Select-Object -Unique
$modelArgs=@('/noconfig','/nologo','/target:winexe','/platform:x64','/optimize+',('/out:'+$modelPreviewExe),('/win32icon:'+(Join-Path $stage 'HuymaierConsole.ico')))
foreach($r in $modelRefs){if(-not(Test-Path -LiteralPath $r -PathType Leaf)){throw "Platform-model compiler reference missing: $r"};$modelArgs+=('/reference:'+$r)}
$modelArgs+=@($modelPreviewSource,$modelPreviewAliases)
& $csc @modelArgs
if($LASTEXITCODE -ne 0 -or -not(Test-Path $modelPreviewExe)){throw 'x64 HuymaierModelPreviewWorker.exe compilation failed.'}
'@
    $builder=$builder.Replace($compileNeedle,$compileBlock)
    $requiredNeedle="'HuymaierGameInputBridge.dll','HuymaierConsole.exe','HuymaierStreamingCursorHost.exe','HuymaierUnifiedCursorHost.exe','Restore-HuymaierWindowsSettings.ps1'"
    if(-not $builder.Contains($requiredNeedle)){throw 'Platform models could not find transformed production payload list.'}
    $builder=$builder.Replace($requiredNeedle,"'HuymaierGameInputBridge.dll','HuymaierConsole.exe','HuymaierStreamingCursorHost.exe','HuymaierUnifiedCursorHost.exe','HuymaierModelPreviewWorker.exe','Restore-HuymaierWindowsSettings.ps1'")
    $archNeedle=@'
$unifiedHeaders=(& $dumpbin /nologo /headers $unifiedCursorExe) -join "`n";if($unifiedHeaders -notmatch '(?i)machine \(x64\)|8664 machine'){throw 'HuymaierUnifiedCursorHost.exe is not x64.'}
'@
    if(-not $builder.Contains($archNeedle)){throw 'Platform models could not find unified host architecture gate.'}
    $archBlock=@'
$unifiedHeaders=(& $dumpbin /nologo /headers $unifiedCursorExe) -join "`n";if($unifiedHeaders -notmatch '(?i)machine \(x64\)|8664 machine'){throw 'HuymaierUnifiedCursorHost.exe is not x64.'}
$modelHeaders=(& $dumpbin /nologo /headers $modelPreviewExe) -join "`n";if($modelHeaders -notmatch '(?i)machine \(x64\)|8664 machine'){throw 'HuymaierModelPreviewWorker.exe is not x64.'}
'@
    $builder=$builder.Replace($archNeedle,$archBlock)
    Set-Content -LiteralPath $CoreBuilderPath -Value $builder -Encoding UTF8
}
