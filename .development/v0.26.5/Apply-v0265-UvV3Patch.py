from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]

def repl(rel,old,new,count=1):
 p=ROOT/rel;text=p.read_text(encoding='utf-8-sig');n=text.count(old)
 if n!=count: raise RuntimeError(f'{rel}: expected {count}, got {n}: {old[:120]!r}')
 p.write_text(text.replace(old,new,count),encoding='utf-8')

rel=Path('Native/HuymaierD3D11UvAddressSmoke.cpp')
repl(rel,
'''    // HC3D v1 stores V as 1-transformedV. Production sampling must undo that\n    // cache-space convention exactly once. Cached (0.25,0.25) therefore becomes\n    // authored/transformed glTF (0.25,0.75) -> bottom-left blue texel.\n    float2 cachedUv = float2(0.25, 0.25);\n    float2 gltfUv = float2(cachedUv.x, 1.0 - cachedUv.y);\n    return ProbeTexture.SampleLevel(RepeatSampler, gltfUv, 0.0);\n''',
'''    // HC3D v3 stores authored/transformed glTF UVs directly. No hidden V flip\n    // exists in either cache or production shader. (0.25,0.75) therefore samples\n    // the bottom-left blue texel exactly as authored.\n    float2 gltfUv = float2(0.25, 0.75);\n    return ProbeTexture.SampleLevel(RepeatSampler, gltfUv, 0.0);\n''')

rel=Path('.development/v0.26.5/Test-v0265-D3D11UvAddressing.ps1')
p=ROOT/rel;text=p.read_text(encoding='utf-8-sig')
old="""foreach($contract in @(\n    'float2 baseUv = float2(i.uv0.x, 1.0 - i.uv0.y)',\n    'float2 emissiveUv = float2(i.uv1.x, 1.0 - i.uv1.y)',\n    'D3D11_TEXTURE_ADDRESS_CLAMP',\n    'D3D11_TEXTURE_ADDRESS_MIRROR',\n    'D3D11_TEXTURE_ADDRESS_WRAP')){\n"""
new="""foreach($contract in @(\n    'BaseTexture.Sample(BaseSampler, i.uv0)',\n    'EmissiveTexture.Sample(EmissiveSampler,i.uv1)',\n    'MetallicRoughnessTexture.Sample(MetallicRoughnessSampler,i.uv2)',\n    'NormalTexture.Sample(NormalSampler,i.uv3)',\n    'OcclusionTexture.Sample(OcclusionSampler,i.uv4)',\n    'D3D11_TEXTURE_ADDRESS_CLAMP',\n    'D3D11_TEXTURE_ADDRESS_MIRROR',\n    'D3D11_TEXTURE_ADDRESS_WRAP')){\n"""
if text.count(old)!=1: raise RuntimeError('UV production contract block mismatch')
text=text.replace(old,new,1)
insert="""\nforeach($forbidden in @('1.0 - i.uv0.y','1.0 - i.uv1.y','float2 cachedUv')){\n    if($runtimeText.IndexOf($forbidden,[StringComparison]::Ordinal)-ge0){throw \"HC3D v3 reintroduced hidden UV inversion: $forbidden\"}\n}\n"""
needle="""}\n\n$vswhere=Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\\Installer\\vswhere.exe'\n"""
if text.count(needle)!=1: raise RuntimeError('UV forbidden-check insertion anchor mismatch')
text=text.replace(needle,"}\n"+insert+"\n$vswhere=Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\\Installer\\vswhere.exe'\n",1)
text=text.replace("Write-Host 'platformModelUvHc3dConventionGate: success'","Write-Host 'platformModelUvHc3dV3DirectGltfGate: success'",1)
p.write_text(text,encoding='utf-8')
print('uvV3PatchApplied: success')
