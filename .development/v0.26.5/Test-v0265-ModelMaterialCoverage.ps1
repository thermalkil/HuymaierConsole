Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$auditPath=Join-Path $PSScriptRoot 'model-pack-material-audit.json'
$compilerPath=Join-Path $root 'Native\HuymaierGpuShelfAssetCompiler.cs'
$runtimePath=Join-Path $root 'Native\HuymaierD3D11ShelfRuntime.cpp'
$assetPath=Join-Path $root 'Native\HuymaierD3D11ShelfAsset.cpp'
$previewPath=Join-Path $root 'Native\HuymaierModelPreviewWorker.cs'
$viewerPath=Join-Path $root 'HuymaierLivePlatformModels.ps1'
foreach($p in @($auditPath,$compilerPath,$runtimePath,$assetPath,$previewPath,$viewerPath)){if(-not(Test-Path -LiteralPath $p -PathType Leaf)){throw "Model-material audit input missing: $p"}}
$audit=Get-Content -Raw -LiteralPath $auditPath -Encoding UTF8|ConvertFrom-Json

# Lock the contract to the actual user-supplied archives that were audited.
if([int]$audit.modelCount-ne36){throw "Original model audit count changed: $($audit.modelCount)"}
if([int]$audit.materialCount-ne199){throw "Original material audit count changed: $($audit.materialCount)"}
if([int]$audit.alphaModes.OPAQUE-ne182-or[int]$audit.alphaModes.BLEND-ne17-or[int]$audit.alphaModes.MASK-ne0){throw 'Original alpha-mode coverage no longer matches the audited archives.'}
if([int]$audit.doubleSidedMaterials-ne188){throw 'Original double-sided material count no longer matches the audited archives.'}
if([int]$audit.textureBindings.baseColor-ne95-or[int]$audit.textureBindings.metallicRoughness-ne88-or[int]$audit.textureBindings.normal-ne92-or[int]$audit.textureBindings.occlusion-ne59-or[int]$audit.textureBindings.emissive-ne16){throw 'Original texture-binding counts no longer match the audited archives.'}
if(@($audit.fullyTexturelessModels).Count-ne7){throw 'Original textureless-model audit must contain exactly seven GLBs.'}
foreach($name in @('Playstation 5.glb','Sega Logo.glb','Sega Master System.glb','Sony Playstation Vita.glb','XBOX 360.glb','Xbox One.glb','Xbox.glb')){if(@($audit.fullyTexturelessModels)-notcontains$name){throw "Original textureless-material coverage omitted $name"}}
Write-Host 'platformModelOriginalPackAuditGate: success'

$compiler=Get-Content -Raw -LiteralPath $compilerPath -Encoding UTF8
foreach($needle in @(
    'HUYMAIER_GPU_SHELF_ASSET_CACHE_V3','CacheVersion = 3',
    'MetallicRoughnessTexture','NormalTexture','OcclusionTexture',
    'MetallicRoughnessImage','NormalImage','OcclusionImage',
    'NormalScale','OcclusionStrength','TANGENT','FallbackTangent',
    'TEXCOORD_','KHR_texture_transform','BaseWrapS','MetallicRoughnessWrapS','NormalWrapS','OcclusionWrapS',
    'JsonUtil.Double(pbr, "metallicFactor", 1)','JsonUtil.Double(pbr, "roughnessFactor", 1)',
    'ou = (float)su; ov = (float)sv;'
)){if($compiler.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "HC3D v3 compiler does not cover audited material feature: $needle"}}
foreach($forbidden in @('ov = (float)(1.0 - sv)','ov = (float)(1.0 - v)')){if($compiler.IndexOf($forbidden,[StringComparison]::Ordinal)-ge0){throw "HC3D v3 compiler reintroduced hidden V inversion: $forbidden"}}
Write-Host 'platformModelHc3dV3AllAuditedTextureMapsGate: success'
Write-Host 'platformModelHc3dV3MultiUvTransformGate: success'
Write-Host 'platformModelHc3dV3GltfDefaultsGate: success'

$runtime=Get-Content -Raw -LiteralPath $runtimePath -Encoding UTF8
foreach($needle in @(
    'HUYMAIER_D3D11_SHARED_SHELF_RUNTIME_V3',
    'MetallicRoughnessTexture : register(t2)','NormalTexture : register(t3)','OcclusionTexture : register(t4)',
    'MetallicRoughnessSampler','NormalSampler','OcclusionSampler',
    'SV_IsFrontFace','D3D11_CULL_BACK','D3D11_CULL_NONE',
    'float alpha=Flags.z==2?saturate(base.a):1.0;',
    'if (Flags.z == 1 && base.a < Extra.x) discard;',
    'Maps.x!=0','Maps.y!=0','Maps.z!=0',
    'MaterialParams.x','MaterialParams.y',
    'float4 tex = Flags.x != 0 ? BaseTexture.Sample(BaseSampler, i.uv0) : float4(1,1,1,1);'
)){if($runtime.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "D3D11 material runtime does not cover audited feature: $needle"}}
foreach($forbidden in @('1.0 - i.uv0.y','1.0 - i.uv1.y')){if($runtime.IndexOf($forbidden,[StringComparison]::Ordinal)-ge0){throw "D3D11 v3 shader reintroduced old V inversion: $forbidden"}}
Write-Host 'platformModelD3D11OpaqueBlendSemanticsGate: success'
Write-Host 'platformModelD3D11NormalMrAoGate: success'
Write-Host 'platformModelD3D11DoubleSidedBackNormalGate: success'

$asset=Get-Content -Raw -LiteralPath $assetPath -Encoding UTF8
foreach($needle in @('version!=3','metallicRoughnessImage','normalImage','occlusionImage','normalScale','occlusionStrength','GenerateMips')){if($asset.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "HC3D v3 loader does not preserve audited feature: $needle"}}
Write-Host 'platformModelHc3dV3LoaderCoverageGate: success'

# WPF remains fallback/preview support only. It must at minimum keep texture tint,
# authored solid colors, alpha semantics, glTF defaults and unlit materials.
$preview=Get-Content -Raw -LiteralPath $previewPath -Encoding UTF8
foreach($needle in @('ApplyBaseColor','alphaCutoff','baseBitmap = ApplyBaseColor','new EmissiveMaterial(diffuseBrush)','JsonUtil.Double(pbr, "metallicFactor", 1.0)','JsonUtil.Double(pbr, "roughnessFactor", 1.0)')){if($preview.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "WPF compatibility renderer lost audited material fallback: $needle"}}
Write-Host 'platformModelWpfFallbackMaterialGate: success'

# Full-screen viewer must never create the old divergent WPF model view anymore.
$viewer=Get-Content -Raw -LiteralPath $viewerPath -Encoding UTF8
foreach($needle in @('HUYMAIER_SHARED_D3D11_MODEL_VIEWER_V1','Get-HcModelViewerGpuCache','Get-HcGpuShelfHostType','SetItemView(0')){if($viewer.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "Full-screen viewer is not using the shared D3D11 material path: $needle"}}
$start=$viewer.IndexOf('function Open-HcPlatformModelViewer {',[StringComparison]::Ordinal);$end=$viewer.IndexOf('function Invoke-SecondaryAction {',[StringComparison]::Ordinal)
if($start-lt0-or$end-le$start){throw 'Full-screen viewer implementation cannot be inspected.'}
$open=$viewer.Substring($start,$end-$start)
if($open.IndexOf('New-HcLiveModelView',[StringComparison]::Ordinal)-ge0){throw 'Full-screen viewer regressed to the divergent WPF model renderer.'}
Write-Host 'platformModelShelfViewerMaterialParityGate: success'
