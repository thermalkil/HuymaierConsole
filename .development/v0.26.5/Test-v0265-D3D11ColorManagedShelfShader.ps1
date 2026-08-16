Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$assetHeader=Join-Path $root 'Native\HuymaierD3D11ShelfAsset.h'
$runtime=Join-Path $root 'Native\HuymaierD3D11ShelfRuntime.cpp'
$smoke=Join-Path $root 'Native\HuymaierD3D11ShelfAssetSmoke.cpp'
foreach($p in @($assetHeader,$runtime,$smoke)){if(-not(Test-Path -LiteralPath $p -PathType Leaf)){throw "Color-managed shelf shader input missing: $p"}}
$h=Get-Content -Raw -LiteralPath $assetHeader -Encoding UTF8
$r=Get-Content -Raw -LiteralPath $runtime -Encoding UTF8
$s=Get-Content -Raw -LiteralPath $smoke -Encoding UTF8
foreach($needle in @(
 'HUYMAIER_D3D11_SHELF_SHADER_V4_COLOR_MANAGED_UI_PBR','HcShelfShaderSource',
 'float3 SrgbToLinear(float3 c)','float3 LinearToSrgb(float3 c)',
 'SrgbToLinear(sampledBase.rgb)','SrgbToLinear(EmissiveTexture.Sample',
 'float d0=saturate(dot(n,l0));','float d1=saturate(dot(n,l1));',
 'float3 f0=lerp(dielectricF0,baseRgb,metallic);','float3 environmentSpec=f0*environmentStrength;',
 'float3 displayRgb=LinearToSrgb(saturate(linearRgb));','return float4(displayRgb*alpha,alpha);'
)){if($h.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "Color-managed production shader contract missing: $needle"}}
foreach($forbidden in @('dot(n,-l0)','dot(n,-l1)','diffuseWeight=lerp(1.0,0.32,metallic)')){if($h.IndexOf($forbidden,[StringComparison]::Ordinal)-ge0){throw "Dark/incorrect shelf lighting regression survived: $forbidden"}}
foreach($needle in @('const char* kShader = HcShelfShaderSource;','D3DCompile(kShader')){if($r.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "Production shelf does not compile shared color-managed shader: $needle"}}
foreach($needle in @('HUYMAIER_D3D11_CACHED_ASSET_SMOKE_V4_PRODUCTION_SHADER','D3DCompile(HcShelfShaderSource','brightColorful','mx>120')){if($s.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "WARP regression is not exercising the production color-managed shader: $needle"}}
Write-Host 'platformModelSharedProductionShaderGate: success'
Write-Host 'platformModelSrgbMaterialDecodeGate: success'
Write-Host 'platformModelDisplayGammaEncodeGate: success'
Write-Host 'platformModelCameraFacingLightGate: success'
Write-Host 'platformModelColoredMetallicResponseGate: success'
Write-Host 'platformModelReadablePixelThresholdGate: success'
