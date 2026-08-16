from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]

def repl(rel, old, new, expected=1):
    p=ROOT/rel
    text=p.read_text(encoding='utf-8-sig')
    n=text.count(old)
    if n!=expected:
        raise RuntimeError(f'{rel}: expected {expected} occurrence(s), got {n}: {old!r}')
    p.write_text(text.replace(old,new),encoding='utf-8')

# Compiler binary-layout probe.
rel=Path('.development/v0.26.5/Test-v0265-GpuShelfAssetCompiler.ps1')
repl(rel,"'HUYMAIER_GPU_SHELF_ASSET_CACHE_V1'","'HUYMAIER_GPU_SHELF_ASSET_CACHE_V3'")
repl(rel,"$version-ne2","$version-ne3")
repl(rel,"($vc*40)+($ic*4)+($dc*92)","($vc*80)+($ic*4)+($dc*136)")
# Require the newly preserved map contracts in the compiler source.
p=ROOT/rel;text=p.read_text(encoding='utf-8')
old="'TEXCOORD_0','EmissiveTexture','LastWriteTimeUtc.Ticks'"
new="'TEXCOORD_0','EmissiveTexture','MetallicRoughnessTexture','NormalTexture','OcclusionTexture','NormalScale','OcclusionStrength','LastWriteTimeUtc.Ticks'"
if text.count(old)!=1: raise RuntimeError('GPU compiler contract list anchor mismatch')
p.write_text(text.replace(old,new,1),encoding='utf-8')

# Mirrored-node cache probe.
rel=Path('.development/v0.26.5/Test-v0265-MirroredModelWinding.ps1')
repl(rel,"'CacheVersion = 2'","'CacheVersion = 3'")
repl(rel,"-ne2){throw 'Mirrored cache is not HC3D v2.'}","-ne3){throw 'Mirrored cache is not HC3D v3.'}")
repl(rel,"($vc*40)","($vc*80)")
repl(rel,"'platformModelHc3dV2CacheGate: success'","'platformModelHc3dV3CacheGate: success'")

# Face/culling source contract follows the new cache.
rel=Path('.development/v0.26.5/Test-v0265-D3D11FaceCulling.ps1')
repl(rel,"'CacheVersion = 2'","'CacheVersion = 3'")

# V7 integration/source gate: no old cache-space V inversion survives.
rel=Path('.development/v0.26.5/Test-v0265-GpuPlatformShelvesV7.ps1')
repl(rel,"'HUYMAIER_D3D11_SHARED_SHELF_RUNTIME_V1'","'HUYMAIER_D3D11_SHARED_SHELF_RUNTIME_V3'")
repl(rel,"'float2 baseUv = float2(i.uv0.x, 1.0 - i.uv0.y)','float2 emissiveUv = float2(i.uv1.x, 1.0 - i.uv1.y)'","'MetallicRoughnessTexture : register(t2)','NormalTexture : register(t3)','OcclusionTexture : register(t4)','SV_IsFrontFace'")
repl(rel,"'version != 2'","'version!=3'")
repl(rel,"'HUYMAIER_GPU_SHELF_ASSET_CACHE_V1','CacheVersion = 2'","'HUYMAIER_GPU_SHELF_ASSET_CACHE_V3','CacheVersion = 3'")
repl(rel,"'platformModelHc3dV2ReleaseGate'","'platformModelHc3dV3ReleaseGate'")

print('hc3dV3LegacyTestMigrationGate: success')
