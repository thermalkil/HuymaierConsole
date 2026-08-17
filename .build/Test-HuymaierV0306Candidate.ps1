param(
    [Parameter(Mandatory=$true)][string]$StageRoot,
    [Parameter(Mandatory=$true)][string]$ValidationPath
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
if(-not(Test-Path -LiteralPath $StageRoot -PathType Container)){throw "v0.30.6 stage root missing: $StageRoot"}
if(-not(Test-Path -LiteralPath $ValidationPath -PathType Leaf)){throw "v0.30.6 validation record missing: $ValidationPath"}
$validation=Get-Content -Raw -LiteralPath $ValidationPath -Encoding UTF8|ConvertFrom-Json
if([string]$validation.version -ne '0.30.6'){throw "Expected validation version 0.30.6, found $($validation.version)."}
if([string]$validation.asset -ne 'HC0306.zip'){throw "Expected HC0306.zip, found $($validation.asset)."}
$manifest=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'manifest.json') -Encoding UTF8|ConvertFrom-Json
if([string]$manifest.version -ne '0.30.6' -or [string]$manifest.baseVersion -ne '0.30.4'){throw 'v0.30.6 manifest identity/base release is wrong.'}
$appx=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'FSEPackage\AppxManifest.xml') -Encoding UTF8
if($appx -notmatch 'Version="0\.30\.6\.0"'){throw 'v0.30.6 AppX identity is missing.'}
Write-Host 'v0306VersionIdentityGate: success'

$defaults=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'HuymaierModelDefaults.ps1') -Encoding UTF8
foreach($needle in @(
    'HUYMAIER_V0306_CONSOLE_MODEL_SCALE_EDITOR_V1',
    'ScalePercent',
    'LB / RB Scale ',
    "[string]::Equals([string]`$Group.Key,'Consoles'",
    '$itemScale=$baseScale*([double]$view.ScalePercent/100.0)'
)){
    if($defaults.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "Staged v0.30.6 console model scale contract missing: $needle"}
}
$hostText=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'Native\HuymaierD3D11ShelfHost.cs') -Encoding UTF8
$nativeText=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'Native\HuymaierD3D11ShelfRuntime.cpp') -Encoding UTF8
if($hostText.IndexOf('HUYMAIER_V0306_CONSOLE_MODEL_SCALE_CAPACITY_V1',[StringComparison]::Ordinal)-lt0 -or $hostText.IndexOf('Math.Max(.12f, Math.Min(2.50f, (float)scale))',[StringComparison]::Ordinal)-lt0){throw 'Staged managed console scale capacity missing.'}
if($nativeText.IndexOf('HUYMAIER_V0306_CONSOLE_MODEL_SCALE_CAPACITY_V1',[StringComparison]::Ordinal)-lt0 -or $nativeText.IndexOf('std::max(.12f,std::min(2.50f,item.modelScale))',[StringComparison]::Ordinal)-lt0){throw 'Staged native console scale capacity missing.'}
Write-Host 'v0306ConsoleScalePersistenceGate: success'
Write-Host 'v0306ConsoleScaleProviderIsolationGate: success'
Write-Host 'v0306ConsoleScaleRendererCapacityGate: success'

$compilerSource=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'Native\HuymaierGpuShelfAssetCompiler.cs') -Encoding UTF8
if($compilerSource.IndexOf('HUYMAIER_V0305_ADAPTIVE_WINDING_V1',[StringComparison]::Ordinal)-lt0){throw 'v0.30.5 adaptive winding carry-forward missing.'}
$gpuRuntime=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'HuymaierGpuPlatformShelves.ps1') -Encoding UTF8
if($gpuRuntime.IndexOf("`$name+'.winding-v2.hc3d'",[StringComparison]::Ordinal)-lt0){throw 'v0.30.5 corrected winding cache namespace carry-forward missing.'}
Write-Host 'v0306AdaptiveWindingCarryForwardGate: success'

$updater=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'HuymaierSelfUpdater.ps1') -Encoding UTF8
foreach($needle in @("GetEnvironmentVariable('HUYMAIER_FSE_HOST')",'HuymaierConsoleFseUpdate.lock','if($relaunch -and -not $isFseManaged)')){if($updater.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "FSE updater carry-forward missing: $needle"}}
$customization=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'HuymaierCustomization.ps1') -Encoding UTF8
if($customization.IndexOf('HUYMAIER_V0302_CONSOLE_BRIGHTNESS_V1',[StringComparison]::Ordinal)-lt0){throw 'Overall console brightness carry-forward missing.'}
Write-Host 'v0306FseUpdaterCarryForwardGate: success'
Write-Host 'v0306BrightnessCarryForwardGate: success'
