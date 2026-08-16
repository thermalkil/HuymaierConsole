from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
p=ROOT/'.development/v0.26.5/Test-v0265-GpuPlatformShelvesV7.ps1'
text=p.read_text(encoding='utf-8-sig')
old="$compilerText=Get-Content -Raw $compiler -Encoding UTF8;foreach($n in @('HUYMAIER_GPU_SHELF_ASSET_CACHE_V3','CacheVersion = 3','Determinant3x3','bool mirrored','ix[i + 2]','ix[i + 1]','DefaultShelfTextureSize = 512','DecodePixelWidth','DecodePixelHeight','IsCacheCurrent','EnsureCompiled')){if(-not$compilerText.Contains($n)){throw \"Persistent HC3D v2 compiler contract missing: $n\"}}"
new="$compilerText=Get-Content -Raw $compiler -Encoding UTF8;foreach($n in @('HUYMAIER_GPU_SHELF_ASSET_CACHE_V3','CacheVersion = 3','Determinant3x3','bool mirrored','DefaultShelfTextureSize = 512','DecodePixelWidth','DecodePixelHeight','IsCacheCurrent','EnsureCompiled','MetallicRoughnessTexture','NormalTexture','OcclusionTexture')){if(-not$compilerText.Contains($n)){throw \"Persistent HC3D v3 compiler contract missing: $n\"}};$compilerCompact=[regex]::Replace($compilerText,'\\s+','');foreach($n in @('indices.Add((uint)(baseVertex+ix[i]));indices.Add((uint)(baseVertex+ix[i+2]));indices.Add((uint)(baseVertex+ix[i+1]));','if(mirrored)tw=-tw;')){if($compilerCompact.IndexOf($n,[StringComparison]::Ordinal)-lt0){throw \"Persistent HC3D v3 winding contract missing: $n\"}}"
if text.count(old)!=1: raise RuntimeError('V7 compiler assertion block did not match exactly')
text=text.replace(old,new,1)
old="'HC_GPU_LoadShelfModel','HC_GPU_SetShelfItem','HC_GPU_SetShelfBrightness','HC_GPU_RenderShelfSurface','phase*16.0f',"
new="'HC_GPU_LoadShelfModel','HC_GPU_SetShelfItem','HC_GPU_SetShelfItemView','HC_GPU_SetShelfBrightness','HC_GPU_RenderShelfSurface','phase*16.0f',"
if text.count(old)!=1: raise RuntimeError('V7 native export assertion block did not match')
text=text.replace(old,new,1)
old="'HC_GPU_SetShelfBrightness','SetBrightnessPercent'))"
new="'HC_GPU_SetShelfItemView','SetItemView','HC_GPU_SetShelfBrightness','SetBrightnessPercent'))"
if text.count(old)!=1: raise RuntimeError('V7 managed viewer assertion block did not match')
text=text.replace(old,new,1)
old="'HC_D3D11UvAddressSmokeTest','HC_GPU_SetShelfBrightness','HuymaierGpuShelfHost.dll'"
new="'HC_D3D11UvAddressSmokeTest','HC_GPU_SetShelfItemView','HC_GPU_SetShelfBrightness','HuymaierGpuShelfHost.dll'"
if text.count(old)!=1: raise RuntimeError('V7 release build assertion block did not match')
text=text.replace(old,new,1)
p.write_text(text,encoding='utf-8')
print('v7Hc3dV3AssertionCleanupGate: success')
# validation trigger only; remove this helper before final source freeze
