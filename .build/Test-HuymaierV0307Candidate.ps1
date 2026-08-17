param(
    [Parameter(Mandatory=$true)][string]$StageRoot,
    [Parameter(Mandatory=$true)][string]$ValidationPath
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
if(-not(Test-Path -LiteralPath $StageRoot -PathType Container)){throw "v0.30.7 stage root missing: $StageRoot"}
if(-not(Test-Path -LiteralPath $ValidationPath -PathType Leaf)){throw "v0.30.7 validation record missing: $ValidationPath"}
$validation=Get-Content -Raw -LiteralPath $ValidationPath -Encoding UTF8|ConvertFrom-Json
if([string]$validation.version -ne '0.30.7'){throw "Expected validation version 0.30.7, found $($validation.version)."}
if([string]$validation.asset -ne 'HC0307.zip'){throw "Expected HC0307.zip, found $($validation.asset)."}
$manifest=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'manifest.json') -Encoding UTF8|ConvertFrom-Json
if([string]$manifest.version -ne '0.30.7' -or [string]$manifest.baseVersion -ne '0.30.6'){throw 'v0.30.7 manifest identity/base release is wrong.'}
$appx=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'FSEPackage\AppxManifest.xml') -Encoding UTF8
if($appx -notmatch 'Version="0\.30\.7\.0"'){throw 'v0.30.7 AppX identity is missing.'}
Write-Host 'v0307VersionIdentityGate: success'

$module=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'HuymaierConsoleModelPresentation.ps1') -Encoding UTF8
foreach($needle in @(
    'HUYMAIER_V0307_CONSOLE_STUDIO_LIGHT_V1',
    "'Key light','Light azimuth','Light elevation','Light temp','Ambient','Specular'",
    'KeyLightPercent=[int]$keyLight',
    'LightTemperature=[int]$lightTemperature',
    "SetItemStudioLight(`$Id,[double]`$View.KeyLightPercent/100.0",
    "'Light azimuth'{`$script:HcModelEditorLightAzimuth=Normalize-HcModelLightAzimuth",
    "'Light temp'{`$script:HcModelEditorLightTemperature=Normalize-HcModelLightTemperature"
)){
    if($module.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "Staged v0.30.7 studio-light editor contract missing: $needle"}
}
Write-Host 'v0307ConsoleStudioLightEditorStageGate: success'

$hostSource=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'Native\HuymaierD3D11ShelfHost.cs') -Encoding UTF8
foreach($needle in @('HUYMAIER_V0307_CONSOLE_STUDIO_LIGHT_NATIVE_BRIDGE_V1','HC_GPU_SetShelfItemStudioLight','StudioLightOverride = false','!state.StudioLightOverride ||','public bool SetItemStudioLight')){
    if($hostSource.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "Staged v0.30.7 managed studio-light bridge missing: $needle"}
}
$runtimeSource=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'Native\HuymaierD3D11ShelfRuntime.cpp') -Encoding UTF8
foreach($needle in @('HUYMAIER_V0307_CONSOLE_STUDIO_LIGHT_NATIVE_V1','struct StudioConstants','studioLightOverride = false','HcTemperatureToLinearRgb','PSSetConstantBuffers(1,1,&scb)','HC_GPU_SetShelfItemStudioLight')){
    if($runtimeSource.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "Staged v0.30.7 native studio-light contract missing: $needle"}
}
$assetSource=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'Native\HuymaierD3D11ShelfAsset.h') -Encoding UTF8
foreach($needle in @('HUYMAIER_V0307_CONSOLE_STUDIO_LIGHT_SHADER_V1','cbuffer StudioLightConstants : register(b1)','StudioLightExtra.w>0.5','normalize(float3(-0.45,0.72,-0.62))','float3(1,1,1)','specularScale')){
    if($assetSource.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "Staged v0.30.7 studio-light shader/fallback missing: $needle"}
}
Write-Host 'v0307ConsoleStudioLightNativeStageGate: success'
Write-Host 'v0307ProviderLegacyLightingFallbackStageGate: success'

# Carry-forward: the complete console editor and FSE updater must remain present.
foreach($needle in @('HUYMAIER_V0306_CONSOLE_MODEL_PRESENTATION_EDITOR_V1','Mirror X','Faces','ScalePercent','FanPercent')){if($module.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "v0.30.6 console editor carry-forward missing: $needle"}}
$updater=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'HuymaierSelfUpdater.ps1') -Encoding UTF8
foreach($needle in @("GetEnvironmentVariable('HUYMAIER_FSE_HOST')",'HuymaierConsoleFseUpdate.lock','Windows FSE host owns post-update relaunch.')){if($updater.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "v0.30.3 FSE updater carry-forward missing: $needle"}}
Write-Host 'v0307ConsolePresentationCarryForwardGate: success'
Write-Host 'v0307FseUpdaterCarryForwardGate: success'

# The feature must stay lightweight: no shadow texture or shadow pass is staged.
foreach($forbidden in @('Texture2D Shadow','SamplerComparisonState','shadowMap','DrawShadow')){
    if($assetSource.IndexOf($forbidden,[StringComparison]::OrdinalIgnoreCase)-ge0 -or $runtimeSource.IndexOf($forbidden,[StringComparison]::OrdinalIgnoreCase)-ge0){throw "v0.30.7 staged package unexpectedly contains shadow path: $forbidden"}
}
Write-Host 'v0307NoShadowRenderPassStageGate: success'
