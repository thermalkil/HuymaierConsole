param(
    [Parameter(Mandatory=$true)][string]$CorePath,
    [Parameter(Mandatory=$true)][string]$BootstrapPath,
    [Parameter(Mandatory=$true)][string]$InstallerScriptPath,
    [Parameter(Mandatory=$true)][string]$CoreBuilderPath
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
foreach($path in @($CorePath,$BootstrapPath,$InstallerScriptPath,$CoreBuilderPath)){if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "Platform-model transform input missing: $path"}}
$repoRoot=Split-Path -Parent $PSScriptRoot
$atlasRuntimePath=Join-Path $repoRoot 'HuymaierPlatformAtlas.ps1'
$atlasParts=@(1..4|ForEach-Object{Join-Path $repoRoot ('.development\v0.26.5\platform-model-atlas.part{0:D2}.b64' -f $_)})
if(-not(Test-Path -LiteralPath $atlasRuntimePath -PathType Leaf)){throw "Platform-model atlas runtime missing: $atlasRuntimePath"}
foreach($part in $atlasParts){if(-not(Test-Path -LiteralPath $part -PathType Leaf)){throw "Platform-model atlas source part missing: $part"}}

$core=Get-Content -Raw -LiteralPath $CorePath -Encoding UTF8
if($core -notmatch 'HUYMAIER_PLATFORM_3D_MODELS_RUNTIME_V1'){
    $needle='$script:CustomizationModulePath = Join-Path $script:BaseDir ''HuymaierCustomization.ps1'''
    if(-not $core.Contains($needle)){throw 'Platform models could not find customization module path.'}
    $core=$core.Replace($needle,$needle+"`r`n`$script:PlatformModelsModulePath = Join-Path `$script:BaseDir 'HuymaierPlatformModels.ps1'")
    $needle=@'
if (Test-Path -LiteralPath $script:CustomizationModulePath) {
    try { . $script:CustomizationModulePath }
    catch { Write-Log "Customization module load failed: $($_.Exception.Message)" 'ERROR' }
}
'@
    if(-not $core.Contains($needle)){throw 'Platform models could not find customization module load block.'}
    $replacement=$needle+@'

# HUYMAIER_PLATFORM_3D_MODELS_RUNTIME_V1
if (Test-Path -LiteralPath $script:PlatformModelsModulePath) {
    try { . $script:PlatformModelsModulePath }
    catch { Write-Log "Platform 3D model module load failed: $($_.Exception.Message)" 'ERROR' }
}
'@
    $core=$core.Replace($needle,$replacement)
}
if($core -notmatch 'HUYMAIER_PLATFORM_3D_ATLAS_RUNTIME_LOAD_V1'){
    $needle='$script:PlatformModelsModulePath = Join-Path $script:BaseDir ''HuymaierPlatformModels.ps1'''
    if(-not $core.Contains($needle)){throw 'Platform atlas requires platform model module path first.'}
    $core=$core.Replace($needle,$needle+"`r`n`$script:PlatformAtlasModulePath = Join-Path `$script:BaseDir 'HuymaierPlatformAtlas.ps1'")
    $needle=@'
if (Test-Path -LiteralPath $script:PlatformModelsModulePath) {
    try { . $script:PlatformModelsModulePath }
    catch { Write-Log "Platform 3D model module load failed: $($_.Exception.Message)" 'ERROR' }
}
'@
    if(-not $core.Contains($needle)){throw 'Platform atlas could not find platform model runtime load block.'}
    $replacement=$needle+@'

# HUYMAIER_PLATFORM_3D_ATLAS_RUNTIME_LOAD_V1
if (Test-Path -LiteralPath $script:PlatformAtlasModulePath) {
    try { . $script:PlatformAtlasModulePath }
    catch { Write-Log "Platform 3D atlas module load failed: $($_.Exception.Message)" 'ERROR' }
}
'@
    $core=$core.Replace($needle,$replacement)
}
Set-Content -LiteralPath $CorePath -Value $core -Encoding UTF8

$bootstrap=Get-Content -Raw -LiteralPath $BootstrapPath -Encoding UTF8
if($bootstrap -notmatch 'HUYMAIER_PLATFORM_3D_MODELS_PREFLIGHT_V1'){
    $needle='$unifiedCursorPath=Join-Path $baseDir ''HuymaierUnifiedCursor.ps1'''
    if(-not $bootstrap.Contains($needle)){throw 'Platform models require unified-cursor bootstrap preflight first.'}
    $bootstrap=$bootstrap.Replace($needle,$needle+"`r`n# HUYMAIER_PLATFORM_3D_MODELS_PREFLIGHT_V1`r`n`$platformModelsPath=Join-Path `$baseDir 'HuymaierPlatformModels.ps1'")
    $needle="        [pscustomobject]@{Path=`$unifiedCursorPath;Label='Unified cursor runtime'},"
    if(-not $bootstrap.Contains($needle)){throw 'Platform models could not find unified cursor preflight entry.'}
    $bootstrap=$bootstrap.Replace($needle,$needle+"`r`n        [pscustomobject]@{Path=`$platformModelsPath;Label='Platform 3D model runtime'},")
}
if($bootstrap -notmatch 'HUYMAIER_PLATFORM_3D_ATLAS_PREFLIGHT_V1'){
    $needle='$platformModelsPath=Join-Path $baseDir ''HuymaierPlatformModels.ps1'''
    if(-not $bootstrap.Contains($needle)){throw 'Platform atlas requires platform model preflight path first.'}
    $bootstrap=$bootstrap.Replace($needle,$needle+"`r`n# HUYMAIER_PLATFORM_3D_ATLAS_PREFLIGHT_V1`r`n`$platformAtlasPath=Join-Path `$baseDir 'HuymaierPlatformAtlas.ps1'")
    $needle="        [pscustomobject]@{Path=`$platformModelsPath;Label='Platform 3D model runtime'},"
    if(-not $bootstrap.Contains($needle)){throw 'Platform atlas could not find platform model preflight entry.'}
    $bootstrap=$bootstrap.Replace($needle,$needle+"`r`n        [pscustomobject]@{Path=`$platformAtlasPath;Label='Platform 3D atlas runtime'},")
}
Set-Content -LiteralPath $BootstrapPath -Value $bootstrap -Encoding UTF8

$installer=Get-Content -Raw -LiteralPath $InstallerScriptPath -Encoding UTF8
if($installer -notmatch 'HUYMAIER_PLATFORM_3D_MODELS_INSTALLER_CACHE_V1'){
    $needle="            'HuymaierUnifiedCursor.ps1',"
    if(-not $installer.Contains($needle)){throw 'Platform models could not find unified cursor installer-cache entry.'}
    $installer=$installer.Replace($needle,$needle+"`r`n            # HUYMAIER_PLATFORM_3D_MODELS_INSTALLER_CACHE_V1`r`n            'HuymaierPlatformModels.ps1',")
}
if($installer -notmatch 'HUYMAIER_PLATFORM_3D_ATLAS_INSTALLER_CACHE_V1'){
    $needle="            'HuymaierPlatformModels.ps1',"
    if(-not $installer.Contains($needle)){throw 'Platform atlas could not find platform model installer-cache entry.'}
    $installer=$installer.Replace($needle,$needle+"`r`n            # HUYMAIER_PLATFORM_3D_ATLAS_INSTALLER_CACHE_V1`r`n            'HuymaierPlatformAtlas.ps1',")
}
Set-Content -LiteralPath $InstallerScriptPath -Value $installer -Encoding UTF8

$builder=Get-Content -Raw -LiteralPath $CoreBuilderPath -Encoding UTF8
if($builder -notmatch 'HUYMAIER_PLATFORM_3D_ATLAS_PAYLOAD_V1'){
    $anchor='# Files inherited from old packages but retired from the active architecture.'
    if(-not $builder.Contains($anchor)){throw 'Platform atlas could not find post-overlay staging anchor.'}
    $payload=@'
# HUYMAIER_PLATFORM_3D_ATLAS_PAYLOAD_V1
$modelAtlasParts=@(
    (Join-Path $workspace '.development\v0.26.5\platform-model-atlas.part01.b64'),
    (Join-Path $workspace '.development\v0.26.5\platform-model-atlas.part02.b64'),
    (Join-Path $workspace '.development\v0.26.5\platform-model-atlas.part03.b64'),
    (Join-Path $workspace '.development\v0.26.5\platform-model-atlas.part04.b64')
)
foreach($modelAtlasPart in $modelAtlasParts){if(-not(Test-Path -LiteralPath $modelAtlasPart -PathType Leaf)){throw "3D model atlas source part missing: $modelAtlasPart"}}
$modelAtlasBase64=($modelAtlasParts|ForEach-Object{(Get-Content -Raw -LiteralPath $_ -Encoding ASCII).Trim()}) -join ''
$modelAtlasBytes=[Convert]::FromBase64String($modelAtlasBase64)
$modelAtlasHasher=[Security.Cryptography.SHA256]::Create()
try{$modelAtlasSha=[BitConverter]::ToString($modelAtlasHasher.ComputeHash($modelAtlasBytes)).Replace('-','').ToLowerInvariant()}finally{$modelAtlasHasher.Dispose()}
if($modelAtlasSha -ne 'fb46ad288c506e2c628f4bf06025deb66af17d26b4fff02baa2950de13d7342f'){throw "3D model atlas SHA mismatch: $modelAtlasSha"}
if($modelAtlasBytes.Length -lt 1024 -or $modelAtlasBytes[0] -ne 0x89 -or $modelAtlasBytes[1] -ne 0x50 -or $modelAtlasBytes[2] -ne 0x4E -or $modelAtlasBytes[3] -ne 0x47){throw '3D model atlas payload is not a valid PNG.'}
$modelAtlasPath=Join-Path $stage 'Assets\Models\platform-models.png'
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $modelAtlasPath)|Out-Null
[IO.File]::WriteAllBytes($modelAtlasPath,$modelAtlasBytes)

'@
    $builder=$builder.Replace($anchor,$payload+$anchor)
}
if($builder -notmatch 'HUYMAIER_PLATFORM_3D_MODEL_WORKER_BUILD_V1'){
    $needle=@'
& $csc @unifiedArgs
if($LASTEXITCODE -ne 0 -or -not(Test-Path $unifiedCursorExe)){throw 'x64 HuymaierUnifiedCursorHost.exe compilation failed.'}
'@
    if(-not $builder.Contains($needle)){throw 'Platform models require unified cursor worker compile block first.'}
    $replacement=$needle+@'

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
    $builder=$builder.Replace($needle,$replacement)
    $needle="'HuymaierGameInputBridge.dll','HuymaierConsole.exe','HuymaierStreamingCursorHost.exe','HuymaierUnifiedCursorHost.exe','Restore-HuymaierWindowsSettings.ps1'"
    if(-not $builder.Contains($needle)){throw 'Platform models could not find transformed production payload list.'}
    $builder=$builder.Replace($needle,"'HuymaierGameInputBridge.dll','HuymaierConsole.exe','HuymaierStreamingCursorHost.exe','HuymaierUnifiedCursorHost.exe','HuymaierModelPreviewWorker.exe','Restore-HuymaierWindowsSettings.ps1'")
    $needle=@'
$unifiedHeaders=(& $dumpbin /nologo /headers $unifiedCursorExe) -join "`n";if($unifiedHeaders -notmatch '(?i)machine \(x64\)|8664 machine'){throw 'HuymaierUnifiedCursorHost.exe is not x64.'}
'@
    if(-not $builder.Contains($needle)){throw 'Platform models could not find unified host architecture gate.'}
    $replacement=$needle+@'
$modelHeaders=(& $dumpbin /nologo /headers $modelPreviewExe) -join "`n";if($modelHeaders -notmatch '(?i)machine \(x64\)|8664 machine'){throw 'HuymaierModelPreviewWorker.exe is not x64.'}
'@
    $builder=$builder.Replace($needle,$replacement)
}
Set-Content -LiteralPath $CoreBuilderPath -Value $builder -Encoding UTF8
