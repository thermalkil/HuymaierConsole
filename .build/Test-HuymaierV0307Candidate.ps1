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
    'HUYMAIER_V0307_CONSOLE_STUDIO_LIGHT_ADVANCED_V1',
    "'Light brightness','Light azimuth','Light elevation','Light distance','Light aim X','Light aim Y','Cone size','Cone softness','Light falloff','Light temp','Ambient','Specular','Highlight size'",
    'KeyLightPercent=[int]$keyLight',
    'LightDistance=[double]$lightDistance',
    'ConeDegrees=[int]$coneDegrees',
    'HighlightSizePercent=[int]$highlightSize',
    "SetItemStudioLight(`$Id,[double]`$View.KeyLightPercent/100.0",
    '[double]$View.LightDistance,[double]$View.LightAimXPercent/100.0,[double]$View.LightAimYPercent/100.0',
    '[double]$View.ConeDegrees,[double]$View.ConeSoftnessPercent/100.0,[double]$View.FalloffPercent/100.0',
    "'Light distance'{`$script:HcModelEditorLightDistance=Normalize-HcModelLightDistance",
    "'Cone size'{`$script:HcModelEditorConeDegrees=Normalize-HcModelConeDegrees",
    "'Highlight size'{`$script:HcModelEditorHighlightSizePercent=Normalize-HcModelHighlightSizePercent"
)){
    if($module.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "Staged v0.30.7 advanced studio-light editor contract missing: $needle"}
}
foreach($needle in @('Min(400.0,$Value)','Min(500.0,$Value)','Min(20.0,$Value))*4.0','Min(180.0,$Value))/5.0','Min(12000.0,$Value))/100.0','Min(300.0,$Value)','Min(400.0,$Value)','Min(400.0,$Value))/25.0')){
    if($module.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "Staged v0.30.7 advanced light range missing: $needle"}
}
Write-Host 'v0307ConsoleStudioLightAdvancedEditorStageGate: success'

$hostSource=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'Native\HuymaierD3D11ShelfHost.cs') -Encoding UTF8
foreach($needle in @(
    'HUYMAIER_V0307_CONSOLE_STUDIO_LIGHT_ADVANCED_NATIVE_BRIDGE_V1',
    'float distance, float aimX, float aimY, float coneDegrees, float coneSoftness, float falloffScale',
    'float ambientScale, float specularScale, float highlightScale',
    'LightDistance = 8.0f',
    'ConeDegrees = 180.0f',
    'Math.Min(5.0f, (float)keyLightScale)',
    'Math.Min(4.00f, (float)lightScale)'
)){
    if($hostSource.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "Staged v0.30.7 advanced managed studio-light bridge missing: $needle"}
}
$runtimeSource=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'Native\HuymaierD3D11ShelfRuntime.cpp') -Encoding UTF8
foreach($needle in @(
    'HUYMAIER_V0307_CONSOLE_STUDIO_LIGHT_ADVANCED_NATIVE_V1',
    'struct StudioConstants',
    'XMFLOAT4 extra2;',
    'lightDistance = 8.0f',
    'coneDegrees = 180.0f',
    'HcTemperatureToLinearRgb',
    'studio.extra=XMFLOAT4(item.specularScale,item.coneDegrees,item.coneSoftness,1);',
    'studio.extra2=XMFLOAT4(item.falloffScale,item.highlightScale,targetX,targetY);',
    'PSSetConstantBuffers(1,1,&scb)',
    'float distance,float aimX,float aimY,float coneDegrees,float coneSoftness,float falloffScale',
    'std::min(5.0f,keyLightScale)',
    'std::min(4.00f,lightScale)'
)){
    if($runtimeSource.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "Staged v0.30.7 advanced native studio-light contract missing: $needle"}
}
$assetSource=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'Native\HuymaierD3D11ShelfAsset.h') -Encoding UTF8
foreach($needle in @(
    'HUYMAIER_V0307_CONSOLE_STUDIO_LIGHT_ADVANCED_SHADER_V1',
    'cbuffer StudioLightConstants : register(b1)',
    'float4 StudioLightExtra2;',
    'float3 lightPos=StudioLightDirectionIntensity.xyz;',
    'float coneDegrees=clamp(StudioLightExtra.y,5.0,180.0);',
    'smoothstep(outerCos,max(innerCos,outerCos+0.0001),coneDot)',
    'float distanceWeight=1.0/(1.0+falloff*lightDistance*lightDistance*0.06);',
    'float highlightScale=max(0.25,StudioLightExtra2.y);'
)){
    if($assetSource.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "Staged v0.30.7 advanced studio-light shader missing: $needle"}
}
Write-Host 'v0307ConsoleStudioLightAdvancedNativeStageGate: success'

# Providers/storefronts must still execute the original showroom-light branch.
foreach($needle in @(
    'if(!customStudioLight)',
    'float3 l0=normalize(float3(-0.45,0.72,-0.62));',
    'float3 l1=normalize(float3(0.75,0.25,-0.55));',
    'float diffuseLight=0.42+d0*0.30+d1*0.12;',
    'float3 directSpec=f0*(directSpec0*0.18+directSpec1*0.07);',
    'float3 environmentSpec=f0*environmentStrength;'
)){
    if($assetSource.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "Staged provider legacy-light fallback changed/missing: $needle"}
}
Write-Host 'v0307ProviderLegacyLightingFallbackStageGate: success'

# Carry-forward: complete console editor and FSE updater remain present.
foreach($needle in @('HUYMAIER_V0306_CONSOLE_MODEL_PRESENTATION_EDITOR_V1','Mirror X','Faces','ScalePercent','FanPercent')){if($module.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "v0.30.6 console editor carry-forward missing: $needle"}}
$updater=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'HuymaierSelfUpdater.ps1') -Encoding UTF8
foreach($needle in @("GetEnvironmentVariable('HUYMAIER_FSE_HOST')",'HuymaierConsoleFseUpdate.lock','Windows FSE host owns post-update relaunch.')){if($updater.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "v0.30.3 FSE updater carry-forward missing: $needle"}}
Write-Host 'v0307ConsolePresentationCarryForwardGate: success'
Write-Host 'v0307FseUpdaterCarryForwardGate: success'

foreach($forbidden in @('Texture2D Shadow','SamplerComparisonState','shadowMap','DrawShadow')){
    if($assetSource.IndexOf($forbidden,[StringComparison]::OrdinalIgnoreCase)-ge0 -or $runtimeSource.IndexOf($forbidden,[StringComparison]::OrdinalIgnoreCase)-ge0){throw "v0.30.7 staged package unexpectedly contains shadow path: $forbidden"}
}
Write-Host 'v0307NoShadowRenderPassStageGate: success'
