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
$liveRuntimePath=Join-Path $repoRoot 'HuymaierLivePlatformModels.ps1'
$liveControlPath=Join-Path $repoRoot 'Native\HuymaierLiveModelControl.cs'
$atlasParts=@(1..4|ForEach-Object{Join-Path $repoRoot ('.development\v0.26.5\platform-model-atlas.part{0:D2}.b64' -f $_)})
foreach($required in @($atlasRuntimePath,$liveRuntimePath,$liveControlPath)){if(-not(Test-Path -LiteralPath $required -PathType Leaf)){throw "Platform-model runtime source missing: $required"}}
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
if($core -notmatch 'HUYMAIER_PLATFORM_3D_LIVE_RUNTIME_LOAD_V1'){
    $needle='$script:PlatformAtlasModulePath = Join-Path $script:BaseDir ''HuymaierPlatformAtlas.ps1'''
    if(-not $core.Contains($needle)){throw 'Live platform models require atlas module path first.'}
    $core=$core.Replace($needle,$needle+"`r`n`$script:LivePlatformModelsModulePath = Join-Path `$script:BaseDir 'HuymaierLivePlatformModels.ps1'")
    $needle=@'
if (Test-Path -LiteralPath $script:PlatformAtlasModulePath) {
    try { . $script:PlatformAtlasModulePath }
    catch { Write-Log "Platform 3D atlas module load failed: $($_.Exception.Message)" 'ERROR' }
}
'@
    if(-not $core.Contains($needle)){throw 'Live platform models could not find atlas runtime load block.'}
    $replacement=$needle+@'

# HUYMAIER_PLATFORM_3D_LIVE_RUNTIME_LOAD_V1
if (Test-Path -LiteralPath $script:LivePlatformModelsModulePath) {
    try { . $script:LivePlatformModelsModulePath }
    catch { Write-Log "Live platform 3D model module load failed: $($_.Exception.Message)" 'ERROR' }
}
'@
    $core=$core.Replace($needle,$replacement)
}
if($core -notmatch 'HUYMAIER_PLATFORM_3D_CONFIG_V2'){
    $needle='        GameBarScale = 100'
    if(-not $core.Contains($needle)){throw 'Platform 3D config could not find GameBarScale default.'}
    $replacement=$needle+@'

        # HUYMAIER_PLATFORM_3D_CONFIG_V2
        PlatformVisualStyle = 'Icons'
        PlatformIconScale = 100
        PlatformModelScale = 100
'@
    $core=$core.Replace($needle,$replacement)
    $needle="'QuickMenuPosition','GameBarScale','ProviderInstallRoots'"
    if(-not $core.Contains($needle)){throw 'Platform 3D config could not find persisted property allow-list anchor.'}
    $core=$core.Replace($needle,"'QuickMenuPosition','GameBarScale','PlatformVisualStyle','PlatformIconScale','PlatformModelScale','ProviderInstallRoots'")
    $needle='    try{$defaults.GameBarScale=[math]::Max(70,[math]::Min(140,[int]$defaults.GameBarScale))}catch{$defaults.GameBarScale=100}'
    if(-not $core.Contains($needle)){throw 'Platform 3D config could not find GameBarScale clamp.'}
    $replacement=$needle+@'

    try{$defaults.PlatformIconScale=[math]::Max(60,[math]::Min(180,[int]$defaults.PlatformIconScale))}catch{$defaults.PlatformIconScale=100}
    try{$defaults.PlatformModelScale=[math]::Max(50,[math]::Min(200,[int]$defaults.PlatformModelScale))}catch{$defaults.PlatformModelScale=100}
    if(@('Icons','3D Models') -notcontains [string]$defaults.PlatformVisualStyle){$defaults.PlatformVisualStyle='Icons'}
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
if($bootstrap -notmatch 'HUYMAIER_PLATFORM_3D_LIVE_PREFLIGHT_V1'){
    $needle='$platformAtlasPath=Join-Path $baseDir ''HuymaierPlatformAtlas.ps1'''
    if(-not $bootstrap.Contains($needle)){throw 'Live platform model preflight requires atlas path first.'}
    $bootstrap=$bootstrap.Replace($needle,$needle+"`r`n# HUYMAIER_PLATFORM_3D_LIVE_PREFLIGHT_V1`r`n`$livePlatformModelsPath=Join-Path `$baseDir 'HuymaierLivePlatformModels.ps1'`r`n`$liveModelDllPath=Join-Path `$baseDir 'HuymaierLiveModel3D.dll'")
    $needle="        [pscustomobject]@{Path=`$platformAtlasPath;Label='Platform 3D atlas runtime'},"
    if(-not $bootstrap.Contains($needle)){throw 'Live platform models could not find atlas preflight entry.'}
    $bootstrap=$bootstrap.Replace($needle,$needle+"`r`n        [pscustomobject]@{Path=`$livePlatformModelsPath;Label='Live platform 3D runtime'},`r`n        [pscustomobject]@{Path=`$liveModelDllPath;Label='Live platform 3D assembly'},")
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
if($installer -notmatch 'HUYMAIER_PLATFORM_3D_LIVE_INSTALLER_CACHE_V1'){
    $needle="            'HuymaierPlatformAtlas.ps1',"
    if(-not $installer.Contains($needle)){throw 'Live platform models could not find atlas installer-cache entry.'}
    $installer=$installer.Replace($needle,$needle+"`r`n            # HUYMAIER_PLATFORM_3D_LIVE_INSTALLER_CACHE_V1`r`n            'HuymaierLivePlatformModels.ps1',`r`n            'HuymaierLiveModel3D.dll',")
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
if($builder -notmatch 'HUYMAIER_PLATFORM_3D_MODEL_WORKER_BUILD_V2'){
    $needle=@'
& $csc @unifiedArgs
if($LASTEXITCODE -ne 0 -or -not(Test-Path $unifiedCursorExe)){throw 'x64 HuymaierUnifiedCursorHost.exe compilation failed.'}
'@
    if(-not $builder.Contains($needle)){throw 'Platform models require unified cursor worker compile block first.'}
    $replacement=$needle+@'

# HUYMAIER_PLATFORM_3D_MODEL_WORKER_BUILD_V2
$modelPreviewSource=Join-Path $stage 'Native\HuymaierModelPreviewWorker.cs'
$modelPreviewAliases=Join-Path $stage 'Native\HuymaierModelPreviewWpfAliases.cs'
$liveModelSource=Join-Path $stage 'Native\HuymaierLiveModelControl.cs'
$modelPreviewExe=Join-Path $stage 'HuymaierModelPreviewWorker.exe'
$liveModelDll=Join-Path $stage 'HuymaierLiveModel3D.dll'
foreach($modelSource in @($modelPreviewSource,$modelPreviewAliases,$liveModelSource)){if(-not(Test-Path -LiteralPath $modelSource -PathType Leaf)){throw "Platform model source missing: $modelSource"}}
$modelFramework=[Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()
$modelRefs=@([Uri].Assembly.Location,[Linq.Enumerable].Assembly.Location,[Web.Script.Serialization.JavaScriptSerializer].Assembly.Location,[Windows.DependencyObject].Assembly.Location,[Windows.Media.Visual].Assembly.Location,[Windows.Window].Assembly.Location,(Join-Path $modelFramework 'System.Xaml.dll'))|Select-Object -Unique
$modelArgs=@('/noconfig','/nologo','/target:winexe','/platform:x64','/optimize+',('/out:'+$modelPreviewExe),('/win32icon:'+(Join-Path $stage 'HuymaierConsole.ico')))
foreach($r in $modelRefs){if(-not(Test-Path -LiteralPath $r -PathType Leaf)){throw "Platform-model compiler reference missing: $r"};$modelArgs+=('/reference:'+$r)}
$modelArgs+=@($modelPreviewSource,$modelPreviewAliases)
& $csc @modelArgs
if($LASTEXITCODE -ne 0 -or -not(Test-Path $modelPreviewExe)){throw 'x64 HuymaierModelPreviewWorker.exe compilation failed.'}
$liveArgs=@('/noconfig','/nologo','/target:library','/platform:x64','/optimize+',('/out:'+$liveModelDll))
foreach($r in $modelRefs){$liveArgs+=('/reference:'+$r)}
$liveArgs+=@($modelPreviewSource,$modelPreviewAliases,$liveModelSource)
& $csc @liveArgs
if($LASTEXITCODE -ne 0 -or -not(Test-Path $liveModelDll)){throw 'x64 HuymaierLiveModel3D.dll compilation failed.'}
'@
    $builder=$builder.Replace($needle,$replacement)
    $needle="'HuymaierGameInputBridge.dll','HuymaierConsole.exe','HuymaierStreamingCursorHost.exe','HuymaierUnifiedCursorHost.exe','Restore-HuymaierWindowsSettings.ps1'"
    if(-not $builder.Contains($needle)){throw 'Platform models could not find transformed production payload list.'}
    $builder=$builder.Replace($needle,"'HuymaierGameInputBridge.dll','HuymaierConsole.exe','HuymaierStreamingCursorHost.exe','HuymaierUnifiedCursorHost.exe','HuymaierModelPreviewWorker.exe','HuymaierLiveModel3D.dll','Restore-HuymaierWindowsSettings.ps1'")
    $needle=@'
$unifiedHeaders=(& $dumpbin /nologo /headers $unifiedCursorExe) -join "`n";if($unifiedHeaders -notmatch '(?i)machine \(x64\)|8664 machine'){throw 'HuymaierUnifiedCursorHost.exe is not x64.'}
'@
    if(-not $builder.Contains($needle)){throw 'Platform models could not find unified host architecture gate.'}
    $replacement=$needle+@'
$modelHeaders=(& $dumpbin /nologo /headers $modelPreviewExe) -join "`n";if($modelHeaders -notmatch '(?i)machine \(x64\)|8664 machine'){throw 'HuymaierModelPreviewWorker.exe is not x64.'}
$liveModelHeaders=(& $dumpbin /nologo /headers $liveModelDll) -join "`n";if($liveModelHeaders -notmatch '(?i)machine \(x64\)|8664 machine'){throw 'HuymaierLiveModel3D.dll is not x64.'}
'@
    $builder=$builder.Replace($needle,$replacement)
}
Set-Content -LiteralPath $CoreBuilderPath -Value $builder -Encoding UTF8