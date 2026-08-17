Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$module=Join-Path $root 'HuymaierConsoleModelPresentation.ps1'
$hostPath=Join-Path $root 'Native\HuymaierD3D11ShelfHost.cs'
$runtimePath=Join-Path $root 'Native\HuymaierD3D11ShelfRuntime.cpp'
$assetPath=Join-Path $root 'Native\HuymaierD3D11ShelfAsset.h'
foreach($p in @($module,$hostPath,$runtimePath,$assetPath)){if(-not(Test-Path -LiteralPath $p -PathType Leaf)){throw "v0.30.7 studio-light test source missing: $p"}}

$moduleText=Get-Content -Raw -LiteralPath $module -Encoding UTF8
foreach($needle in @(
    'HUYMAIER_V0307_CONSOLE_STUDIO_LIGHT_V1',
    "'Key light','Light azimuth','Light elevation','Light temp','Ambient','Specular'",
    'Normalize-HcModelKeyLightPercent',
    'Normalize-HcModelLightAzimuth',
    'Normalize-HcModelLightElevation',
    'Normalize-HcModelLightTemperature',
    'Normalize-HcModelAmbientPercent',
    'Normalize-HcModelSpecularPercent',
    "Get-EntryProperty `$entry 'KeyLightPercent' 100",
    "Get-EntryProperty `$entry 'LightTemperature' 6500",
    'KeyLightPercent=(Normalize-HcModelKeyLightPercent $KeyLightPercent)',
    'LightTemperature=(Normalize-HcModelLightTemperature $LightTemperature)',
    "`$Surface.PSObject.Methods['SetItemStudioLight']",
    'SetItemStudioLight($Id,[double]$View.KeyLightPercent/100.0',
    "'Light azimuth'{`$script:HcModelEditorLightAzimuth=Normalize-HcModelLightAzimuth",
    "'Light temp'{`$script:HcModelEditorLightTemperature=Normalize-HcModelLightTemperature"
)){
    if($moduleText.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "v0.30.7 console studio-light module contract missing: $needle"}
}
Write-Host 'consoleStudioLightEditorGate: success'

# Ranges are intentionally bounded and controller-friendly.
foreach($needle in @(
    'Max(0.0,[math]::Min(200.0,$Value))/10.0',
    'Max(-80.0,[math]::Min(80.0,$Value))/5.0',
    'Max(2500.0,[math]::Min(9000.0,$Value))/500.0',
    '+5*$Delta',
    '+500*$Delta'
)){
    if($moduleText.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "v0.30.7 studio-light range/step contract missing: $needle"}
}
Write-Host 'consoleStudioLightRangeGate: success'

# Provider/storefront models must stay neutral and never receive the console-only
# studio-light call through their normal shelf/viewer path.
$providerNeutral="if(-not(Test-HcConsoleModelPresentationEditable `$Platform)){`$scalePercent=100;`$roll=0;`$offsetX=0;`$offsetY=0;`$mirrorX=`$false;`$mirrorY=`$false;`$mirrorZ=`$false;`$faceMode='Normal';`$light=100;`$keyLight=100;`$lightAzimuth=-36;`$lightElevation=43;`$lightTemperature=6500;`$ambient=100;`$specular=100;`$fan=100}"
if($moduleText.IndexOf($providerNeutral,[StringComparison]::Ordinal)-lt0){throw 'v0.30.7 provider-neutral model view contract missing.'}
if(([regex]::Matches($moduleText,[regex]::Escape("SetItemStudioLight(`$Id"))).Count-ne1){throw 'v0.30.7 SetItemStudioLight must have exactly one PowerShell call site.'}
Write-Host 'consoleStudioLightProviderIsolationGate: success'

$hostText=Get-Content -Raw -LiteralPath $hostPath -Encoding UTF8
foreach($needle in @(
    'HUYMAIER_V0307_CONSOLE_STUDIO_LIGHT_NATIVE_BRIDGE_V1',
    'HC_GPU_SetShelfItemStudioLight',
    'public bool StudioLightOverride = false;',
    'bool studioOk = !state.StudioLightOverride ||',
    'public bool SetItemStudioLight(int id, double keyLightScale, double azimuth, double elevation, double temperatureKelvin, double ambientScale, double specularScale)',
    'state.StudioLightOverride = true;'
)){
    if($hostText.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "v0.30.7 managed native-light bridge missing: $needle"}
}
Write-Host 'consoleStudioLightManagedBridgeGate: success'

$runtimeText=Get-Content -Raw -LiteralPath $runtimePath -Encoding UTF8
foreach($needle in @(
    'HUYMAIER_V0307_CONSOLE_STUDIO_LIGHT_NATIVE_V1',
    'struct StudioConstants',
    'ComPtr<ID3D11Buffer> studioConstants;',
    'bool studioLightOverride = false;',
    'HcTemperatureToLinearRgb',
    'studio.directionIntensity=XMFLOAT4(-0.45f,0.72f,-0.62f,1.0f)',
    'studio.extra=XMFLOAT4(1,0,0,0)',
    'PSSetConstantBuffers(1,1,&scb)',
    'HC_GPU_SetShelfItemStudioLight',
    'i.studioLightOverride=true;'
)){
    if($runtimeText.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "v0.30.7 native studio-light contract missing: $needle"}
}
Write-Host 'consoleStudioLightNativeBridgeGate: success'

$assetText=Get-Content -Raw -LiteralPath $assetPath -Encoding UTF8
foreach($needle in @(
    'HUYMAIER_V0307_CONSOLE_STUDIO_LIGHT_SHADER_V1',
    'cbuffer StudioLightConstants : register(b1)',
    'bool customStudioLight=StudioLightExtra.w>0.5;',
    'customStudioLight?normalize(StudioLightDirectionIntensity.xyz):normalize(float3(-0.45,0.72,-0.62))',
    'float3 diffuseLight=0.42*ambientScale.xxx+d0*0.30*keyIntensity*keyColor+d1*0.12;',
    'float3 environmentSpec=f0*environmentStrength*specularScale;'
)){
    if($assetText.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "v0.30.7 studio-light shader contract missing: $needle"}
}
# The fallback branch must preserve the exact old white showroom light. This is
# how top provider models remain visually identical even though the shader gains
# an optional second constant buffer.
if($assetText.IndexOf('float keyIntensity=customStudioLight?max(0.0,StudioLightDirectionIntensity.w):1.0;',[StringComparison]::Ordinal)-lt0 -or
   $assetText.IndexOf('float3 keyColor=customStudioLight?max(StudioLightColorAmbient.rgb,0.0):float3(1,1,1);',[StringComparison]::Ordinal)-lt0 -or
   $assetText.IndexOf('float ambientScale=customStudioLight?max(0.0,StudioLightColorAmbient.w):1.0;',[StringComparison]::Ordinal)-lt0 -or
   $assetText.IndexOf('float specularScale=customStudioLight?max(0.0,StudioLightExtra.x):1.0;',[StringComparison]::Ordinal)-lt0){throw 'v0.30.7 legacy provider-light fallback is incomplete.'}
Write-Host 'consoleStudioLightLegacyFallbackGate: success'

# This feature deliberately avoids shadow maps / extra render passes.
foreach($forbidden in @('D3D11_BIND_DEPTH_STENCIL|D3D11_BIND_SHADER_RESOURCE','Texture2D Shadow','SamplerComparisonState','shadowMap','DrawShadow')){
    if($runtimeText.IndexOf($forbidden,[StringComparison]::OrdinalIgnoreCase)-ge0 -or $assetText.IndexOf($forbidden,[StringComparison]::OrdinalIgnoreCase)-ge0){throw "v0.30.7 studio light unexpectedly introduced shadow path: $forbidden"}
}
Write-Host 'consoleStudioLightNoShadowCostGate: success'

$tokens=$null;$errors=$null
[void][Management.Automation.Language.Parser]::ParseFile($module,[ref]$tokens,[ref]$errors)
if($errors.Count){$errors|ForEach-Object{Write-Host $_.Message};throw 'HuymaierConsoleModelPresentation.ps1 failed Windows PowerShell 5.1 parse after v0.30.7 studio-light transform.'}
Write-Host 'consoleStudioLightPs51ParseGate: success'
