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
$liveRuntimePath=Join-Path $repoRoot 'HuymaierLivePlatformModels.ps1'
$liveControlPath=Join-Path $repoRoot 'Native\HuymaierLiveModelControl.cs'
$modelLoaderPath=Join-Path $repoRoot 'Native\HuymaierModelPreviewWorker.cs'
$modelAliasesPath=Join-Path $repoRoot 'Native\HuymaierModelPreviewWpfAliases.cs'
foreach($required in @($liveRuntimePath,$liveControlPath,$modelLoaderPath,$modelAliasesPath)){if(-not(Test-Path -LiteralPath $required -PathType Leaf)){throw "Platform-model live source missing: $required"}}

# Runtime ownership is deliberately simple: PlatformModels captures the clean
# pre-3D card/rail contract; LivePlatformModels supplies only GLB/viewer helpers;
# User3DModels (loaded by the next transform) becomes the final presentation owner.
$core=Get-Content -Raw -LiteralPath $CorePath -Encoding UTF8
if($core -notmatch 'HUYMAIER_PLATFORM_3D_MODELS_RUNTIME_V2'){
    $pathAnchor='$script:CustomizationModulePath = Join-Path $script:BaseDir ''HuymaierCustomization.ps1'''
    if(-not$core.Contains($pathAnchor)){throw 'Platform models could not find customization module path.'}
    $paths=$pathAnchor+"`r`n`$script:PlatformModelsModulePath = Join-Path `$script:BaseDir 'HuymaierPlatformModels.ps1'`r`n`$script:LivePlatformModelsModulePath = Join-Path `$script:BaseDir 'HuymaierLivePlatformModels.ps1'"
    $core=$core.Replace($pathAnchor,$paths)

    $loadAnchor=@'
if (Test-Path -LiteralPath $script:CustomizationModulePath) {
    try { . $script:CustomizationModulePath }
    catch { Write-Log "Customization module load failed: $($_.Exception.Message)" 'ERROR' }
}
'@
    if(-not$core.Contains($loadAnchor)){throw 'Platform models could not find customization module load block.'}
    $loadBlock=$loadAnchor+@'

# HUYMAIER_PLATFORM_3D_MODELS_RUNTIME_V2
# Capture the clean shell presentation contract, then load live GLB/viewer helpers.
# No atlas/static-preview runtime participates in active presentation ownership.
if (Test-Path -LiteralPath $script:PlatformModelsModulePath) {
    try { . $script:PlatformModelsModulePath }
    catch { Write-Log "Platform presentation base module load failed: $($_.Exception.Message)" 'ERROR' }
}
if (Test-Path -LiteralPath $script:LivePlatformModelsModulePath) {
    try { . $script:LivePlatformModelsModulePath }
    catch { Write-Log "Live platform 3D helper module load failed: $($_.Exception.Message)" 'ERROR' }
}
'@
    $core=$core.Replace($loadAnchor,$loadBlock)
}
if($core -notmatch 'HUYMAIER_PLATFORM_3D_CONFIG_V2'){
    $needle='        GameBarScale = 100'
    if(-not$core.Contains($needle)){throw 'Platform 3D config could not find GameBarScale default.'}
    $core=$core.Replace($needle,$needle+@'

        # HUYMAIER_PLATFORM_3D_CONFIG_V2
        PlatformVisualStyle = 'Icons'
        PlatformIconScale = 100
        PlatformModelScale = 100
'@)
    $needle="'QuickMenuPosition','GameBarScale','ProviderInstallRoots'"
    if(-not$core.Contains($needle)){throw 'Platform 3D config could not find persisted property allow-list anchor.'}
    $core=$core.Replace($needle,"'QuickMenuPosition','GameBarScale','PlatformVisualStyle','PlatformIconScale','PlatformModelScale','ProviderInstallRoots'")
    $needle='    try{$defaults.GameBarScale=[math]::Max(70,[math]::Min(140,[int]$defaults.GameBarScale))}catch{$defaults.GameBarScale=100}'
    if(-not$core.Contains($needle)){throw 'Platform 3D config could not find GameBarScale clamp.'}
    $core=$core.Replace($needle,$needle+@'

    try{$defaults.PlatformIconScale=[math]::Max(60,[math]::Min(180,[int]$defaults.PlatformIconScale))}catch{$defaults.PlatformIconScale=100}
    try{$defaults.PlatformModelScale=[math]::Max(50,[math]::Min(200,[int]$defaults.PlatformModelScale))}catch{$defaults.PlatformModelScale=100}
    if(@('Icons','3D Models') -notcontains [string]$defaults.PlatformVisualStyle){$defaults.PlatformVisualStyle='Icons'}
'@)
}
Set-Content -LiteralPath $CorePath -Value $core -Encoding UTF8

# Startup syntax preflight only parses PowerShell sources. The DLL is verified by
# package integrity + x64 build gates instead of being fed to the PS parser.
$bootstrap=Get-Content -Raw -LiteralPath $BootstrapPath -Encoding UTF8
if($bootstrap -notmatch 'HUYMAIER_PLATFORM_3D_LIVE_PREFLIGHT_V2'){
    $pathAnchor='$unifiedCursorPath=Join-Path $baseDir ''HuymaierUnifiedCursor.ps1'''
    if(-not$bootstrap.Contains($pathAnchor)){throw 'Platform models require unified-cursor bootstrap preflight first.'}
    $bootstrap=$bootstrap.Replace($pathAnchor,$pathAnchor+"`r`n# HUYMAIER_PLATFORM_3D_LIVE_PREFLIGHT_V2`r`n`$platformModelsPath=Join-Path `$baseDir 'HuymaierPlatformModels.ps1'`r`n`$livePlatformModelsPath=Join-Path `$baseDir 'HuymaierLivePlatformModels.ps1'")
    $entryAnchor="        [pscustomobject]@{Path=`$unifiedCursorPath;Label='Unified cursor runtime'},"
    if(-not$bootstrap.Contains($entryAnchor)){throw 'Platform models could not find unified cursor preflight entry.'}
    $bootstrap=$bootstrap.Replace($entryAnchor,$entryAnchor+"`r`n        [pscustomobject]@{Path=`$platformModelsPath;Label='Platform presentation base runtime'},`r`n        [pscustomobject]@{Path=`$livePlatformModelsPath;Label='Live platform 3D helper runtime'},")
}
Set-Content -LiteralPath $BootstrapPath -Value $bootstrap -Encoding UTF8

$installer=Get-Content -Raw -LiteralPath $InstallerScriptPath -Encoding UTF8
if($installer -notmatch 'HUYMAIER_PLATFORM_3D_LIVE_INSTALLER_CACHE_V2'){
    $entryAnchor="            'HuymaierUnifiedCursor.ps1',"
    if(-not$installer.Contains($entryAnchor)){throw 'Platform models could not find unified cursor installer-cache entry.'}
    $installer=$installer.Replace($entryAnchor,$entryAnchor+"`r`n            # HUYMAIER_PLATFORM_3D_LIVE_INSTALLER_CACHE_V2`r`n            'HuymaierPlatformModels.ps1',`r`n            'HuymaierLivePlatformModels.ps1',`r`n            'HuymaierLiveModel3D.dll',")
}
Set-Content -LiteralPath $InstallerScriptPath -Value $installer -Encoding UTF8

# Build exactly one 3D binary: the x64 live renderer DLL. The old standalone PNG
# preview worker and reconstructed atlas are retired and must not be staged.
$builder=Get-Content -Raw -LiteralPath $CoreBuilderPath -Encoding UTF8
if($builder -notmatch 'HUYMAIER_PLATFORM_LIVE_MODEL_DLL_BUILD_V3'){
    $compileAnchor=@'
& $csc @unifiedArgs
if($LASTEXITCODE -ne 0 -or -not(Test-Path $unifiedCursorExe)){throw 'x64 HuymaierUnifiedCursorHost.exe compilation failed.'}
'@
    if(-not$builder.Contains($compileAnchor)){throw 'Platform models require unified cursor compile block first.'}
    $compileBlock=$compileAnchor+@'

# HUYMAIER_PLATFORM_LIVE_MODEL_DLL_BUILD_V3
$modelLoaderSource=Join-Path $stage 'Native\HuymaierModelPreviewWorker.cs'
$modelAliasesSource=Join-Path $stage 'Native\HuymaierModelPreviewWpfAliases.cs'
$liveModelSource=Join-Path $stage 'Native\HuymaierLiveModelControl.cs'
$liveModelDll=Join-Path $stage 'HuymaierLiveModel3D.dll'
foreach($modelSource in @($modelLoaderSource,$modelAliasesSource,$liveModelSource)){if(-not(Test-Path -LiteralPath $modelSource -PathType Leaf)){throw "Live platform model source missing: $modelSource"}}
$modelFramework=[Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()
$modelRefs=@([Uri].Assembly.Location,[Linq.Enumerable].Assembly.Location,[Web.Script.Serialization.JavaScriptSerializer].Assembly.Location,[Windows.DependencyObject].Assembly.Location,[Windows.Media.Visual].Assembly.Location,[Windows.Window].Assembly.Location,(Join-Path $modelFramework 'System.Xaml.dll'))|Select-Object -Unique
$liveArgs=@('/noconfig','/nologo','/target:library','/platform:x64','/optimize+',('/out:'+$liveModelDll))
foreach($r in $modelRefs){if(-not(Test-Path -LiteralPath $r -PathType Leaf)){throw "Live-model compiler reference missing: $r"};$liveArgs+=('/reference:'+$r)}
$liveArgs+=@($modelLoaderSource,$modelAliasesSource,$liveModelSource)
& $csc @liveArgs
if($LASTEXITCODE -ne 0 -or -not(Test-Path $liveModelDll)){throw 'x64 HuymaierLiveModel3D.dll compilation failed.'}
'@
    $builder=$builder.Replace($compileAnchor,$compileBlock)

    $archAnchor=@'
$unifiedHeaders=(& $dumpbin /nologo /headers $unifiedCursorExe) -join "`n";if($unifiedHeaders -notmatch '(?i)machine \(x64\)|8664 machine'){throw 'HuymaierUnifiedCursorHost.exe is not x64.'}
'@
    if(-not$builder.Contains($archAnchor)){throw 'Platform models could not find unified host architecture gate.'}
    $builder=$builder.Replace($archAnchor,$archAnchor+@'
$liveModelHeaders=(& $dumpbin /nologo /headers $liveModelDll) -join "`n";if($liveModelHeaders -notmatch '(?i)machine \(x64\)|8664 machine'){throw 'HuymaierLiveModel3D.dll is not x64.'}
'@)
}
Set-Content -LiteralPath $CoreBuilderPath -Value $builder -Encoding UTF8
