Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$runtime=Join-Path $root 'Native\HuymaierD3D11ShelfRuntime.cpp'
$compiler=Join-Path $root 'Native\HuymaierGpuShelfAssetCompiler.cs'
foreach($p in @($runtime,$compiler)){if(-not(Test-Path -LiteralPath $p -PathType Leaf)){throw "Face-culling source missing: $p"}}
$r=Get-Content -Raw -LiteralPath $runtime -Encoding UTF8
$c=Get-Content -Raw -LiteralPath $compiler -Encoding UTF8
foreach($n in @('D3D11_CULL_BACK','FrontCounterClockwise=TRUE','D3D11_CULL_NONE','rasterizerSingleSided','rasterizerDoubleSided','(d.flags&1)?g_core.rasterizerDoubleSided.Get():g_core.rasterizerSingleSided.Get()')){if($r.IndexOf($n,[StringComparison]::Ordinal)-lt0){throw "Production material face-culling contract missing: $n"}}
foreach($n in @('CacheVersion = 2','Determinant3x3','bool mirrored','ix[i + 2]','ix[i + 1]')){if($c.IndexOf($n,[StringComparison]::Ordinal)-lt0){throw "Mirrored-node winding contract missing: $n"}}
if($r.Contains('rd.CullMode=D3D11_CULL_NONE;rd.DepthClipEnable=TRUE')-and-not$r.Contains('rasterizerSingleSided')){throw 'Production shelf reverted to global no-cull rendering.'}
Write-Host 'platformModelSingleSidedBackFaceCullGate: success'
Write-Host 'platformModelDoubleSidedMaterialGate: success'
Write-Host 'platformModelMirroredNodeFrontFacePreservationGate: success'
