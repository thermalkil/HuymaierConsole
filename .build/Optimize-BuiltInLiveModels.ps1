param(
    [Parameter(Mandatory=$true)][string]$CoreBuilderPath
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
if(-not(Test-Path -LiteralPath $CoreBuilderPath -PathType Leaf)){throw "Built-in live-model transform input missing: $CoreBuilderPath"}
$builder=Get-Content -Raw -LiteralPath $CoreBuilderPath -Encoding UTF8
if($builder -match 'HUYMAIER_BUILTIN_LIVE_GLB_STAGE_V1'){return}
$needle=@'
& $csc @liveArgs
if($LASTEXITCODE -ne 0 -or -not(Test-Path $liveModelDll)){throw 'x64 HuymaierLiveModel3D.dll compilation failed.'}
'@
if(-not $builder.Contains($needle)){throw 'Built-in live models require the live Viewport3D compile block first.'}
$replacement=$needle+@'

# HUYMAIER_BUILTIN_LIVE_GLB_STAGE_V1
$builtInModelGeneratorSource=Join-Path $stage 'Native\HuymaierBuiltInModelGenerator.cs'
if(-not(Test-Path -LiteralPath $builtInModelGeneratorSource -PathType Leaf)){throw "Built-in model generator source missing: $builtInModelGeneratorSource"}
$builtInModelGeneratorExe=Join-Path $stage 'HuymaierBuiltInModelGenerator.exe'
$builtInGeneratorArgs=@('/noconfig','/nologo','/target:exe','/platform:x64','/optimize+',('/out:'+$builtInModelGeneratorExe),$builtInModelGeneratorSource)
& $csc @builtInGeneratorArgs
if($LASTEXITCODE -ne 0 -or -not(Test-Path -LiteralPath $builtInModelGeneratorExe -PathType Leaf)){throw 'x64 built-in live-model generator compilation failed.'}
$builtInModelDir=Join-Path $stage 'Assets\Models\Live'
New-Item -ItemType Directory -Force -Path $builtInModelDir|Out-Null
$builtInGeneratorProcess=Start-Process -FilePath $builtInModelGeneratorExe -ArgumentList ('--output "'+$builtInModelDir+'"') -Wait -PassThru -NoNewWindow
if($builtInGeneratorProcess.ExitCode -ne 0){throw "Built-in live-model generator failed with exit code $($builtInGeneratorProcess.ExitCode)."}
$builtInFrames=@('amazon','arcade','atari-2600','atari-lynx','battlenet','ea','epic-games','finalburn-neo','game-gear','gog','jaguar','neo-geo-pocket-color','neo-geo','nintendo-3ds','nintendo-64','nintendo-ds','nintendo-dsi','nintendo-entertainment-system','nintendo-game-boy-advance','nintendo-game-boy-color','nintendo-game-boy','nintendo-gamecube','nintendo-switch','nintendo-wii-u','nintendo-wii','playstation-2','playstation-3','playstation-4','playstation-5','primehack','rockstar','sega-32x','sega-cd','sega-dreamcast','sega-genesis','sega-logo','sega-master-system','sega-mega-drive','sega-saturn','sony-playstation-portable','sony-playstation-vita','sony-playstation','steam','super-nintendo-entertainment-system','turbografx-16','ubisoft','xbox-360','xbox-one','xbox-pc','xbox')
foreach($builtInFrame in $builtInFrames){
    $builtInPath=Join-Path $builtInModelDir ($builtInFrame+'.glb')
    if(-not(Test-Path -LiteralPath $builtInPath -PathType Leaf)){throw "Built-in live GLB missing: $builtInFrame"}
    $builtInBytes=[IO.File]::ReadAllBytes($builtInPath)
    if($builtInBytes.Length -lt 256 -or $builtInBytes[0] -ne 0x67 -or $builtInBytes[1] -ne 0x6c -or $builtInBytes[2] -ne 0x54 -or $builtInBytes[3] -ne 0x46){throw "Built-in live GLB has invalid header: $builtInFrame"}
}
if(@(Get-ChildItem -LiteralPath $builtInModelDir -Filter '*.glb' -File).Count -ne 50){throw 'Built-in live model payload must contain exactly 50 GLB files.'}
Remove-Item -LiteralPath $builtInModelGeneratorExe -Force -ErrorAction SilentlyContinue
'@
$builder=$builder.Replace($needle,$replacement)
Set-Content -LiteralPath $CoreBuilderPath -Value $builder -Encoding UTF8
