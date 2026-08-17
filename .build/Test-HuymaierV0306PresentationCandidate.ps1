param(
    [Parameter(Mandatory=$true)][string]$StageRoot,
    [Parameter(Mandatory=$true)][string]$ValidationPath
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
if(-not(Test-Path -LiteralPath $StageRoot -PathType Container)){throw "v0.30.6 presentation stage root missing: $StageRoot"}
if(-not(Test-Path -LiteralPath $ValidationPath -PathType Leaf)){throw "v0.30.6 presentation validation record missing: $ValidationPath"}
$validation=Get-Content -Raw -LiteralPath $ValidationPath -Encoding UTF8|ConvertFrom-Json
if([string]$validation.version-ne'0.30.6'-or[string]$validation.asset-ne'HC0306.zip'){throw 'Staged presentation candidate identity is wrong.'}

$modulePath=Join-Path $StageRoot 'HuymaierConsoleModelPresentation.ps1'
$defaultsPath=Join-Path $StageRoot 'HuymaierModelDefaults.ps1'
$hostPath=Join-Path $StageRoot 'Native\HuymaierD3D11ShelfHost.cs'
$runtimePath=Join-Path $StageRoot 'Native\HuymaierD3D11ShelfRuntime.cpp'
$assetPath=Join-Path $StageRoot 'Native\HuymaierD3D11ShelfAsset.h'
foreach($p in @($modulePath,$defaultsPath,$hostPath,$runtimePath,$assetPath)){if(-not(Test-Path -LiteralPath $p -PathType Leaf)){throw "Staged presentation payload missing: $p"}}

$module=Get-Content -Raw -LiteralPath $modulePath -Encoding UTF8
$defaults=Get-Content -Raw -LiteralPath $defaultsPath -Encoding UTF8
$host=Get-Content -Raw -LiteralPath $hostPath -Encoding UTF8
$runtime=Get-Content -Raw -LiteralPath $runtimePath -Encoding UTF8
$asset=Get-Content -Raw -LiteralPath $assetPath -Encoding UTF8
foreach($needle in @('HUYMAIER_V0306_CONSOLE_MODEL_PRESENTATION_EDITOR_V1','Mirror X','Mirror Y','Mirror Z','Faces','Lighting','Fan motion','Position X','Position Y','SetItemPresentation',"[string]::Equals([string]`$Group.Key,'Consoles'")){if($module.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "Staged console presentation editor missing: $needle"}}
if($defaults.IndexOf('HUYMAIER_V0306_CONSOLE_MODEL_PRESENTATION_LOAD_V1',[StringComparison]::Ordinal)-lt0){throw 'Staged presentation module loader missing.'}
foreach($needle in @('HUYMAIER_V0306_CONSOLE_PRESENTATION_NATIVE_BRIDGE_V1','HC_GPU_SetShelfItemPresentation','SetItemPresentation(int id')){if($host.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "Staged managed bridge missing: $needle"}}
foreach($needle in @('HUYMAIER_V0306_CONSOLE_PRESENTATION_NATIVE_V1','rasterizerSingleSidedMirrored','mirrorParity','reverseFaces','item.lightScale','item.fanScale','item.faceMode==2','HC_GPU_SetShelfItemPresentation')){if($runtime.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "Staged native presentation contract missing: $needle"}}
foreach($needle in @('HUYMAIER_V0306_PRESENTATION_TANGENT_FACE_PARITY_V1','presentationTangentParity','MaterialParams.z<-.5')){if($asset.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "Staged presentation shader contract missing: $needle"}}

# Provider isolation is structural: only the Consoles shelf gets persisted
# presentation application; storefront defaults are explicitly neutralized.
foreach($needle in @('Providers are intentionally neutral','Providers are intentionally immutable from Edit Model.')){if($module.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "Staged provider-isolation contract missing: $needle"}}
Write-Host 'v0306FullConsolePresentationStageGate: success'
Write-Host 'v0306MirrorAndFaceCorrectionStageGate: success'
Write-Host 'v0306PerConsoleLightingStageGate: success'
Write-Host 'v0306ProviderPresentationIsolationStageGate: success'
