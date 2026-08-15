Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$generator=Join-Path $root 'Native\HuymaierBuiltInModelGenerator.cs'
$worker=Join-Path $root 'Native\HuymaierModelPreviewWorker.cs'
$aliases=Join-Path $root 'Native\HuymaierModelPreviewWpfAliases.cs'
$liveControl=Join-Path $root 'Native\HuymaierLiveModelControl.cs'
$platformOptimizer=Join-Path $root '.build\Optimize-Platform3DModels.ps1'
$builtInOptimizer=Join-Path $root '.build\Optimize-BuiltInLiveModels.ps1'
$releaseWrapper=Join-Path $root '.build\Build-HuymaierReleaseCandidate.ps1'
foreach($p in @($generator,$worker,$aliases,$liveControl,$platformOptimizer,$builtInOptimizer,$releaseWrapper)){if(-not(Test-Path -LiteralPath $p -PathType Leaf)){throw "Built-in live model source missing: $p"}}
$tokens=$null;$errors=$null;[void][Management.Automation.Language.Parser]::ParseFile($builtInOptimizer,[ref]$tokens,[ref]$errors);if(@($errors).Count){throw "Built-in live-model optimizer failed PS5.1 parse: $(@($errors|ForEach-Object{$_.Message}) -join '; ')"}
$generatorText=Get-Content -Raw -LiteralPath $generator -Encoding UTF8
foreach($needle in @('HUYMAIER_BUILTIN_LIVE_GLB_GENERATOR_V1','private static readonly string[] Frames','nintendo-gamecube','playstation-5','xbox-360','WriteGlb','glTF 2.0 binary geometry')){if(-not $generatorText.Contains($needle)){throw "Built-in model generator contract missing: $needle"}}
$optimizerText=Get-Content -Raw -LiteralPath $builtInOptimizer -Encoding UTF8
foreach($needle in @('HUYMAIER_BUILTIN_LIVE_GLB_STAGE_V1','HuymaierBuiltInModelGenerator.cs','Assets\Models\Live','builtInFrames','exactly 50 GLB')){if(-not $optimizerText.Contains($needle)){throw "Built-in live-model staging contract missing: $needle"}}
$wrapperText=Get-Content -Raw -LiteralPath $releaseWrapper -Encoding UTF8
foreach($needle in @('Optimize-BuiltInLiveModels.ps1','HuymaierBuiltInModelGenerator.cs','HuymaierLivePlatformModels.ps1','HuymaierLiveModelControl.cs','& $builtInModelsOptimizer -CoreBuilderPath $coreBuilder')){if(-not $wrapperText.Contains($needle)){throw "Release wrapper does not stage built-in live models: $needle"}}

Add-Type -AssemblyName PresentationFramework,System.Xaml,System.Web.Extensions
$csc=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe';if(-not(Test-Path -LiteralPath $csc -PathType Leaf)){throw 'Framework64 csc.exe was not found.'}
$tempRoot=$(if($env:RUNNER_TEMP){$env:RUNNER_TEMP}else{[IO.Path]::GetTempPath()});$temp=Join-Path $tempRoot ('hc-built-in-live-'+[guid]::NewGuid().ToString('N'));New-Item -ItemType Directory -Force -Path $temp|Out-Null
try{
    $generatorExe=Join-Path $temp 'HuymaierBuiltInModelGenerator.exe'
    & $csc '/noconfig' '/nologo' '/target:exe' '/platform:x64' '/optimize+' ('/out:'+$generatorExe) $generator
    if($LASTEXITCODE -ne 0 -or -not(Test-Path -LiteralPath $generatorExe -PathType Leaf)){throw 'Built-in live-model generator x64 compilation failed.'}
    $liveDir=Join-Path $temp 'Live';New-Item -ItemType Directory -Force -Path $liveDir|Out-Null
    $proc=Start-Process -FilePath $generatorExe -ArgumentList ('--output "'+$liveDir+'"') -Wait -PassThru -NoNewWindow
    if($proc.ExitCode -ne 0){throw "Built-in live-model generator failed with exit code $($proc.ExitCode)."}
    $glbs=@(Get-ChildItem -LiteralPath $liveDir -Filter '*.glb' -File|Sort-Object Name)
    if($glbs.Count -ne 50){throw "Built-in live-model generator created $($glbs.Count) GLBs instead of 50."}
    $expected=@('amazon','arcade','atari-2600','atari-lynx','battlenet','ea','epic-games','finalburn-neo','game-gear','gog','jaguar','neo-geo-pocket-color','neo-geo','nintendo-3ds','nintendo-64','nintendo-ds','nintendo-dsi','nintendo-entertainment-system','nintendo-game-boy-advance','nintendo-game-boy-color','nintendo-game-boy','nintendo-gamecube','nintendo-switch','nintendo-wii-u','nintendo-wii','playstation-2','playstation-3','playstation-4','playstation-5','primehack','rockstar','sega-32x','sega-cd','sega-dreamcast','sega-genesis','sega-logo','sega-master-system','sega-mega-drive','sega-saturn','sony-playstation-portable','sony-playstation-vita','sony-playstation','steam','super-nintendo-entertainment-system','turbografx-16','ubisoft','xbox-360','xbox-one','xbox-pc','xbox')
    foreach($frame in $expected){$path=Join-Path $liveDir ($frame+'.glb');if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "Generated live model missing: $frame"};$bytes=[IO.File]::ReadAllBytes($path);if($bytes.Length -lt 256 -or $bytes[0]-ne0x67 -or $bytes[1]-ne0x6c -or $bytes[2]-ne0x54 -or $bytes[3]-ne0x46){throw "Generated live model has invalid GLB header: $frame"}}

    $refs=@([Uri].Assembly.Location,[Linq.Enumerable].Assembly.Location,[Web.Script.Serialization.JavaScriptSerializer].Assembly.Location,[Windows.DependencyObject].Assembly.Location,[Windows.Media.Visual].Assembly.Location,[Windows.Window].Assembly.Location,[System.Xaml.XamlReader].Assembly.Location)|Select-Object -Unique
    $dll=Join-Path $temp 'HuymaierLiveModel3D.dll';$args=@('/noconfig','/nologo','/target:library','/platform:x64','/optimize+',('/out:'+$dll));foreach($r in $refs){$args+=('/reference:'+$r)};$args+=@($worker,$aliases,$liveControl);& $csc @args
    if($LASTEXITCODE -ne 0 -or -not(Test-Path -LiteralPath $dll -PathType Leaf)){throw 'Live platform-model x64 DLL compile failed during built-in set validation.'}
    Add-Type -Path $dll
    foreach($frame in $expected){
        $view=New-Object HuymaierConsole.Modeling.LiveModelView -ArgumentList (Join-Path $liveDir ($frame+'.glb'))
        if($null -eq $view){throw "Live Viewport3D failed to instantiate: $frame"}
        $yaw=[double]$view.Yaw;$zoom=[double]$view.ZoomDistance;$view.Rotate(3,2);$view.Zoom(.1)
        if([math]::Abs([double]$view.Yaw-$yaw)-lt .5 -or [math]::Abs([double]$view.ZoomDistance-$zoom)-lt .05){throw "Live model interaction failed: $frame"}
    }

    $core=Join-Path $temp 'HuymaierConsole.ps1';$bootstrap=Join-Path $temp 'HuymaierBootstrap.ps1';$installer=Join-Path $temp 'Install-HuymaierConsole.ps1';$builder=Join-Path $temp 'Build-HuymaierReleaseCandidate.Core.ps1'
    Copy-Item (Join-Path $root 'HuymaierConsole.ps1') $core;Copy-Item (Join-Path $root 'HuymaierBootstrap.ps1') $bootstrap;Copy-Item (Join-Path $root 'Install-HuymaierConsole.ps1') $installer;Copy-Item (Join-Path $root '.build\Build-HuymaierReleaseCandidate.Core.ps1') $builder
    & $platformOptimizer -CorePath $core -BootstrapPath $bootstrap -InstallerScriptPath $installer -CoreBuilderPath $builder
    & $builtInOptimizer -CoreBuilderPath $builder
    $builderText=Get-Content -Raw -LiteralPath $builder -Encoding UTF8
    foreach($needle in @('HUYMAIER_BUILTIN_LIVE_GLB_STAGE_V1','HuymaierBuiltInModelGenerator.cs','Assets\Models\Live','builtInFrames','built-in live-model generator compilation failed')){if(-not $builderText.Contains($needle)){throw "Transformed builder missing built-in GLB staging: $needle"}}
    $tokens=$null;$errors=$null;[void][Management.Automation.Language.Parser]::ParseFile($builder,[ref]$tokens,[ref]$errors);if(@($errors).Count){throw "Transformed builder failed PS5.1 parse after built-in model staging: $(@($errors|ForEach-Object{$_.Message}) -join '; ')"}
}finally{Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue}

$sources=@(Get-Content (Join-Path $root '.source\source-files.txt') -Encoding UTF8)
if($sources -notcontains 'Native/HuymaierBuiltInModelGenerator.cs'){throw 'Release source list is missing the built-in live-model generator.'}
Write-Host 'platformModelBuiltInGlbCountGate: success'
Write-Host 'platformModelBuiltInGlbLoadGate: success'
Write-Host 'platformModelBuiltInInteractiveGate: success'
Write-Host 'platformModelBuiltInReleaseStageGate: success'
