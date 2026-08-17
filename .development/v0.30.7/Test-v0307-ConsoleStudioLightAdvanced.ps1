Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$module=Join-Path $root 'HuymaierConsoleModelPresentation.ps1'
$hostPath=Join-Path $root 'Native\HuymaierD3D11ShelfHost.cs'
$runtimePath=Join-Path $root 'Native\HuymaierD3D11ShelfRuntime.cpp'
$assetPath=Join-Path $root 'Native\HuymaierD3D11ShelfAsset.h'
foreach($p in @($module,$hostPath,$runtimePath,$assetPath)){if(-not(Test-Path -LiteralPath $p -PathType Leaf)){throw "v0.30.7 advanced-light test source missing: $p"}}

$moduleText=Get-Content -Raw -LiteralPath $module -Encoding UTF8
foreach($needle in @(
    'HUYMAIER_V0307_CONSOLE_STUDIO_LIGHT_ADVANCED_V1',
    "'Light brightness','Light azimuth','Light elevation','Light distance','Light aim X','Light aim Y','Cone size','Cone softness','Light falloff','Light temp','Ambient','Specular','Highlight size'",
    'Normalize-HcModelLightDistance',
    'Normalize-HcModelLightAimPercent',
    'Normalize-HcModelConeDegrees',
    'Normalize-HcModelConeSoftnessPercent',
    'Normalize-HcModelFalloffPercent',
    'Normalize-HcModelHighlightSizePercent',
    "Get-EntryProperty `$entry 'LightDistance' 8.0",
    "Get-EntryProperty `$entry 'ConeDegrees' 180",
    "Get-EntryProperty `$entry 'HighlightSizePercent' 100",
    'LightDistance=(Normalize-HcModelLightDistance $LightDistance)',
    'ConeDegrees=(Normalize-HcModelConeDegrees $ConeDegrees)',
    'HighlightSizePercent=(Normalize-HcModelHighlightSizePercent $HighlightSizePercent)',
    'SetItemStudioLight($Id,[double]$View.KeyLightPercent/100.0',
    '[double]$View.ConeDegrees,[double]$View.ConeSoftnessPercent/100.0,[double]$View.FalloffPercent/100.0',
    "'Light distance'{`$script:HcModelEditorLightDistance=Normalize-HcModelLightDistance",
    "'Cone size'{`$script:HcModelEditorConeDegrees=Normalize-HcModelConeDegrees",
    "'Highlight size'{`$script:HcModelEditorHighlightSizePercent=Normalize-HcModelHighlightSizePercent"
)){
    if($moduleText.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "v0.30.7 advanced console-light editor contract missing: $needle"}
}
Write-Host 'consoleStudioLightAdvancedEditorGate: success'

foreach($needle in @(
    'Max(20.0,[math]::Min(400.0,$Value))/10.0',
    'Max(0.0,[math]::Min(500.0,$Value))/10.0',
    'Max(-89.0,[math]::Min(89.0,$Value))',
    'Max(1.0,[math]::Min(20.0,$Value))*4.0',
    'Max(5.0,[math]::Min(180.0,$Value))/5.0',
    'Max(1800.0,[math]::Min(12000.0,$Value))/100.0',
    'Max(0.0,[math]::Min(300.0,$Value))/10.0',
    'Max(0.0,[math]::Min(400.0,$Value))/10.0',
    'Max(25.0,[math]::Min(400.0,$Value))/25.0',
    '+0.25*$Delta',
    '+1*$Delta',
    '+100*$Delta'
)){
    if($moduleText.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "v0.30.7 advanced light range/step contract missing: $needle"}
}
Write-Host 'consoleStudioLightAdvancedRangeGate: success'

$providerNeutral="if(-not(Test-HcConsoleModelPresentationEditable `$Platform)){`$scalePercent=100;`$roll=0;`$offsetX=0;`$offsetY=0;`$mirrorX=`$false;`$mirrorY=`$false;`$mirrorZ=`$false;`$faceMode='Normal';`$light=100;`$keyLight=100;`$lightAzimuth=-36;`$lightElevation=43;`$lightDistance=8.0;`$lightAimX=0;`$lightAimY=0;`$coneDegrees=180;`$coneSoftness=50;`$falloff=0;`$lightTemperature=6500;`$ambient=100;`$specular=100;`$highlightSize=100;`$fan=100}"
if($moduleText.IndexOf($providerNeutral,[StringComparison]::Ordinal)-lt0){throw 'Advanced studio light provider-neutral contract missing.'}
if(([regex]::Matches($moduleText,[regex]::Escape("SetItemStudioLight(`$Id"))).Count-ne1){throw 'Advanced studio light must retain exactly one console presentation call site.'}
Write-Host 'consoleStudioLightAdvancedProviderIsolationGate: success'

$hostText=Get-Content -Raw -LiteralPath $hostPath -Encoding UTF8
foreach($needle in @(
    'HUYMAIER_V0307_CONSOLE_STUDIO_LIGHT_ADVANCED_NATIVE_BRIDGE_V1',
    'float distance, float aimX, float aimY, float coneDegrees, float coneSoftness, float falloffScale',
    'float ambientScale, float specularScale, float highlightScale',
    'public float LightDistance = 8.0f, LightAimX = 0.0f, LightAimY = 0.0f;',
    'public float ConeDegrees = 180.0f, ConeSoftness = 0.5f, FalloffScale = 0.0f;',
    'Math.Min(5.0f, (float)keyLightScale)',
    'Math.Min(20.0f, (float)distance)',
    'Math.Min(4.0f, (float)specularScale)',
    'Math.Min(4.0f, (float)highlightScale)',
    'Math.Min(4.00f, (float)lightScale)'
)){
    if($hostText.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "v0.30.7 advanced managed light bridge missing: $needle"}
}
Write-Host 'consoleStudioLightAdvancedManagedBridgeGate: success'

$runtimeText=Get-Content -Raw -LiteralPath $runtimePath -Encoding UTF8
foreach($needle in @(
    'HUYMAIER_V0307_CONSOLE_STUDIO_LIGHT_ADVANCED_NATIVE_V1',
    'float lightDistance = 8.0f, lightAimX = 0.0f, lightAimY = 0.0f;',
    'float coneDegrees = 180.0f, coneSoftness = 0.5f, falloffScale = 0.0f;',
    'XMFLOAT4 extra2;',
    'const float targetX=item.offsetX*.012f+item.lightAimX,targetY=-item.offsetY*.012f+item.lightAimY;',
    'studio.extra=XMFLOAT4(item.specularScale,item.coneDegrees,item.coneSoftness,1);',
    'studio.extra2=XMFLOAT4(item.falloffScale,item.highlightScale,targetX,targetY);',
    'float distance,float aimX,float aimY,float coneDegrees,float coneSoftness,float falloffScale',
    'std::min(5.0f,keyLightScale)',
    'std::min(12000.0f,temperatureKelvin)',
    'std::min(4.00f,lightScale)'
)){
    if($runtimeText.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "v0.30.7 advanced native spotlight contract missing: $needle"}
}
Write-Host 'consoleStudioLightAdvancedNativeGate: success'

$assetText=Get-Content -Raw -LiteralPath $assetPath -Encoding UTF8
foreach($needle in @(
    'HUYMAIER_V0307_CONSOLE_STUDIO_LIGHT_ADVANCED_SHADER_V1',
    'float4 StudioLightExtra2;',
    'float3 lightPos=StudioLightDirectionIntensity.xyz;',
    'float3 target=float3(StudioLightExtra2.z,StudioLightExtra2.w,0.0);',
    'float coneDegrees=clamp(StudioLightExtra.y,5.0,180.0);',
    'smoothstep(outerCos,max(innerCos,outerCos+0.0001),coneDot)',
    'float distanceWeight=1.0/(1.0+falloff*lightDistance*lightDistance*0.06);',
    'float highlightScale=max(0.25,StudioLightExtra2.y);',
    'float specPower=max(2.0,lerp(10.0,72.0,1.0-roughness)/highlightScale);'
)){
    if($assetText.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "v0.30.7 advanced spotlight shader contract missing: $needle"}
}
# Provider/storefront models still execute an explicit copy of the legacy showroom
# lighting branch when StudioLightOverride is false.
foreach($needle in @(
    'if(!customStudioLight)',
    'float3 l0=normalize(float3(-0.45,0.72,-0.62));',
    'float3 l1=normalize(float3(0.75,0.25,-0.55));',
    'float diffuseLight=0.42+d0*0.30+d1*0.12;',
    'float3 directSpec=f0*(directSpec0*0.18+directSpec1*0.07);',
    'float3 environmentSpec=f0*environmentStrength;'
)){
    if($assetText.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "v0.30.7 provider legacy-light branch changed/missing: $needle"}
}
Write-Host 'consoleStudioLightAdvancedLegacyProviderGate: success'

foreach($forbidden in @('Texture2D Shadow','SamplerComparisonState','shadowMap','DrawShadow')){
    if($runtimeText.IndexOf($forbidden,[StringComparison]::OrdinalIgnoreCase)-ge0 -or $assetText.IndexOf($forbidden,[StringComparison]::OrdinalIgnoreCase)-ge0){throw "v0.30.7 advanced spotlight unexpectedly introduced a shadow path: $forbidden"}
}
Write-Host 'consoleStudioLightAdvancedNoShadowCostGate: success'

$tokens=$null;$errors=$null
[void][Management.Automation.Language.Parser]::ParseFile($module,[ref]$tokens,[ref]$errors)
if($errors.Count){$errors|ForEach-Object{Write-Host $_.Message};throw 'HuymaierConsoleModelPresentation.ps1 failed PowerShell 5.1 parse after advanced studio-light transform.'}
Write-Host 'consoleStudioLightAdvancedPs51ParseGate: success'
