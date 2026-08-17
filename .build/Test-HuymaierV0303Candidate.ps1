param(
    [Parameter(Mandatory=$true)][string]$StageRoot,
    [Parameter(Mandatory=$true)][string]$ValidationPath
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'

if(-not(Test-Path -LiteralPath $StageRoot -PathType Container)){throw "Stage root missing: $StageRoot"}
if(-not(Test-Path -LiteralPath $ValidationPath -PathType Leaf)){throw "Validation record missing: $ValidationPath"}
$validation=Get-Content -Raw -LiteralPath $ValidationPath -Encoding UTF8|ConvertFrom-Json
if([string]$validation.version -ne '0.30.3'){throw "Expected staged version 0.30.3, found $($validation.version)."}
if([string]$validation.asset -ne 'HC0303.zip'){throw "Expected HC0303.zip, found $($validation.asset)."}

$manifest=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'manifest.json') -Encoding UTF8|ConvertFrom-Json
if([string]$manifest.version -ne '0.30.3'){throw 'Staged manifest is not v0.30.3.'}
if([string]$manifest.baseVersion -ne '0.30.2'){throw 'Staged manifest does not identify v0.30.2 as its base release.'}
if([string]$manifest.build -ne 'fse-updater-handoff-rc1'){throw 'Staged manifest build identity is wrong.'}

$core=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'HuymaierConsole.ps1') -Encoding UTF8
if($core.IndexOf("`$script:AppVersion = '0.30.3'",[StringComparison]::Ordinal) -lt 0){throw 'Staged core does not report v0.30.3.'}
$appx=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'FSEPackage\AppxManifest.xml') -Encoding UTF8
if($appx.IndexOf('Version="0.30.3.0"',[StringComparison]::Ordinal) -lt 0){throw 'Staged FSE AppX identity is not 0.30.3.0.'}

$host=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'HuymaierFSEHost.cs') -Encoding UTF8
$updater=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'HuymaierSelfUpdater.ps1') -Encoding UTF8
$shell=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'HuymaierShellRedesign.ps1') -Encoding UTF8
$custom=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'HuymaierCustomization.ps1') -Encoding UTF8
foreach($needle in @('HUYMAIER_FSE_HOST','HuymaierConsoleFseUpdate.lock','WaitForUpdateHandoff')){if($host.IndexOf($needle,[StringComparison]::Ordinal) -lt 0){throw "Staged FSE host contract missing: $needle"}}
foreach($needle in @('[switch]$FseManaged','Windows FSE host owns post-update relaunch.','Remove-Item -LiteralPath $HandoffPath -Force')){if($updater.IndexOf($needle,[StringComparison]::Ordinal) -lt 0){throw "Staged updater contract missing: $needle"}}
foreach($needle in @('HUYMAIER_V0303_FSE_UPDATE_HANDOFF_V1','-FseManaged -HandoffPath','HuymaierConsoleFseUpdate.lock')){if($shell.IndexOf($needle,[StringComparison]::Ordinal) -lt 0){throw "Staged shell handoff contract missing: $needle"}}

# v0.30.3 must carry forward the sole v0.30.2 product feature unchanged.
foreach($needle in @('HUYMAIER_V0302_CONSOLE_BRIGHTNESS_V1',"New-SliderAction 'console-brightness-slider' 'Huymaier Console brightness'","0% to 200% in 10% steps")){if($custom.IndexOf($needle,[StringComparison]::Ordinal) -lt 0){throw "v0.30.2 brightness carry-forward missing: $needle"}}

foreach($required in @('HuymaierConsole.exe','FSEPackage\HuymaierFSEHost.exe','Install-HuymaierConsole.ps1','HuymaierConsoleUpdateWorker.ps1')){if(-not(Test-Path -LiteralPath (Join-Path $StageRoot $required) -PathType Leaf)){throw "Staged runtime missing: $required"}}

Write-Host 'v0303VersionIdentityGate: success'
Write-Host 'v0303FseUpdaterHandoffStageGate: success'
Write-Host 'v0303DesktopUpdaterCarryForwardGate: success'
Write-Host 'v0303ConsoleBrightnessCarryForwardGate: success'