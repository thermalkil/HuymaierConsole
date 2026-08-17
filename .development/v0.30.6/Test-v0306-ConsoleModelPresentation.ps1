Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$module=Join-Path $root 'HuymaierConsoleModelPresentation.ps1'
$defaults=Join-Path $root 'HuymaierModelDefaults.ps1'
$host=Join-Path $root 'Native\HuymaierD3D11ShelfHost.cs'
$runtime=Join-Path $root 'Native\HuymaierD3D11ShelfRuntime.cpp'
$asset=Join-Path $root 'Native\HuymaierD3D11ShelfAsset.h'
$transform=Join-Path $root '.build\Optimize-ConsoleModelPresentation.ps1'
foreach($p in @($module,$defaults,$host,$runtime,$asset,$transform)){if(-not(Test-Path -LiteralPath $p -PathType Leaf)){throw "v0.30.6 presentation test source missing: $p"}}

$tokens=$null;$errors=$null
[void][Management.Automation.Language.Parser]::ParseFile($module,[ref]$tokens,[ref]$errors)
if($errors.Count){$errors|ForEach-Object{Write-Host ("presentation module parse: "+$_.Message)};throw 'Console model presentation module failed Windows PowerShell 5.1 parse.'}
$tokens=$null;$errors=$null
[void][Management.Automation.Language.Parser]::ParseFile($transform,[ref]$tokens,[ref]$errors)
if($errors.Count){$errors|ForEach-Object{Write-Host ("presentation transform parse: "+$_.Message)};throw 'Console model presentation transform failed Windows PowerShell 5.1 parse.'}
Write-Host 'consoleModelPresentationPs51ParseGate: success'

$moduleText=Get-Content -Raw -LiteralPath $module -Encoding UTF8
foreach($needle in @(
    'HUYMAIER_V0306_CONSOLE_MODEL_PRESENTATION_EDITOR_V1',
    "@('Yaw','Pitch','Roll','Scale','Position X','Position Y','Mirror X','Mirror Y','Mirror Z','Faces','Lighting','Fan motion')",
    'ScalePercent',
    'OffsetX',
    'OffsetY',
    'MirrorX',
    'MirrorY',
    'MirrorZ',
    'FaceMode',
    'LightPercent',
    'FanPercent',
    "'Lighting'",
    "'Faces'",
    'SetItemPresentation',
    "[string]::Equals([string]`$Group.Key,'Consoles'",
    'Providers are intentionally neutral',
    'Providers are intentionally immutable from Edit Model.'
)){
    if($moduleText.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "Console model presentation contract missing: $needle"}
}
Write-Host 'consoleModelPresentationFullControlGate: success'
Write-Host 'consoleModelPresentationProviderIsolationGate: success'

foreach($needle in @('Normalize-HcModelScalePercent','Normalize-HcModelOffset','Normalize-HcModelLightPercent','Normalize-HcModelFanPercent','30.0','300.0','20.0','200.0')){
    $combined=(Get-Content -Raw -LiteralPath $defaults -Encoding UTF8)+$moduleText
    if($combined.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "Console model presentation range contract missing: $needle"}
}
Write-Host 'consoleModelPresentationRangeGate: success'

$defaultsText=Get-Content -Raw -LiteralPath $defaults -Encoding UTF8
if($defaultsText.IndexOf('HUYMAIER_V0306_CONSOLE_MODEL_PRESENTATION_LOAD_V1',[StringComparison]::Ordinal)-lt0){throw 'Presentation runtime loader was not applied to HuymaierModelDefaults.ps1.'}
$hostText=Get-Content -Raw -LiteralPath $host -Encoding UTF8
$runtimeText=Get-Content -Raw -LiteralPath $runtime -Encoding UTF8
$assetText=Get-Content -Raw -LiteralPath $asset -Encoding UTF8
foreach($needle in @('HUYMAIER_V0306_CONSOLE_PRESENTATION_NATIVE_BRIDGE_V1','HC_GPU_SetShelfItemPresentation','SetItemPresentation(int id','LightScale','FanScale','FaceMode')){if($hostText.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "Managed presentation bridge missing: $needle"}}
foreach($needle in @('HUYMAIER_V0306_CONSOLE_PRESENTATION_NATIVE_V1','rasterizerSingleSidedMirrored','mirrorParity','reverseFaces','item.lightScale','item.fanScale','item.offsetX*.012f','item.faceMode==2','HC_GPU_SetShelfItemPresentation')){if($runtimeText.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "Native presentation runtime missing: $needle"}}
foreach($needle in @('HUYMAIER_V0306_PRESENTATION_TANGENT_FACE_PARITY_V1','presentationTangentParity','MaterialParams.z<-.5')){if($assetText.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "Presentation shader parity contract missing: $needle"}}
Write-Host 'consoleModelPresentationNativeBridgeGate: success'
Write-Host 'consoleModelPresentationMirrorCullGate: success'
Write-Host 'consoleModelPresentationLightingGate: success'
Write-Host 'consoleModelPresentationFaceModeGate: success'
Write-Host 'consoleModelPresentationTangentParityGate: success'
