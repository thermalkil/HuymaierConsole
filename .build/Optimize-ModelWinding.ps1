param()
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$compiler=Join-Path $root 'Native\HuymaierGpuShelfAssetCompiler.cs'
$runtime=Join-Path $root 'HuymaierGpuPlatformShelves.ps1'
foreach($p in @($compiler,$runtime)){if(-not(Test-Path -LiteralPath $p -PathType Leaf)){throw "v0.30.5 model-winding source missing: $p"}}

# HUYMAIER_V0305_ADAPTIVE_WINDING_TRANSFORM_V1
# Negative-determinant node transforms are not sufficient to decide whether a
# triangle must be reversed. Some authored GLBs already carry reversed local
# winding on mirrored mesh copies. Blindly swapping every negative-determinant
# primitive double-corrects those meshes and makes large model sections render
# inside-out. Compare transformed triangle winding against transformed authored
# normals first; use determinant sign only when the primitive has no reliable
# normal evidence.
$text=Get-Content -Raw -LiteralPath $compiler -Encoding UTF8
if($text -notmatch 'HUYMAIER_V0305_ADAPTIVE_WINDING_V1'){
    $anchor=@'
        private static double ArrDouble(object[] a, int i, double fallback)
'@
    if(-not$text.Contains($anchor)){throw 'v0.30.5 adaptive-winding helper anchor is missing.'}
    $helper=@'
        // HUYMAIER_V0305_ADAPTIVE_WINDING_V1
        private static bool ShouldFlipWinding(List<Vertex> vertices, int baseVertex, int[] ix, bool fallbackMirrored)
        {
            if (vertices == null || ix == null || ix.Length < 3) return fallbackMirrored;
            int triangleCount = ix.Length / 3;
            int step = Math.Max(1, triangleCount / 64);
            int positive = 0, negative = 0, sampled = 0;
            for (int tri = 0; tri < triangleCount && sampled < 64; tri += step)
            {
                int offset = tri * 3;
                int ia = ix[offset], ib = ix[offset + 1], ic = ix[offset + 2];
                if (ia < 0 || ib < 0 || ic < 0 ||
                    baseVertex + ia >= vertices.Count || baseVertex + ib >= vertices.Count || baseVertex + ic >= vertices.Count) continue;
                Vertex a = vertices[baseVertex + ia], b = vertices[baseVertex + ib], c = vertices[baseVertex + ic];
                double ux = b.Px - a.Px, uy = b.Py - a.Py, uz = b.Pz - a.Pz;
                double vx = c.Px - a.Px, vy = c.Py - a.Py, vz = c.Pz - a.Pz;
                double gx = uy * vz - uz * vy, gy = uz * vx - ux * vz, gz = ux * vy - uy * vx;
                double nx = a.Nx + b.Nx + c.Nx, ny = a.Ny + b.Ny + c.Ny, nz = a.Nz + b.Nz + c.Nz;
                double gl2 = gx * gx + gy * gy + gz * gz, nl2 = nx * nx + ny * ny + nz * nz;
                if (gl2 < 1e-18 || nl2 < 1e-18) continue;
                double agreement = (gx * nx + gy * ny + gz * nz) / Math.Sqrt(gl2 * nl2);
                if (agreement > 0.05) positive++;
                else if (agreement < -0.05) negative++;
                sampled++;
            }
            if (positive + negative > 0 && positive != negative) return negative > positive;
            return fallbackMirrored;
        }

'@
    $text=$text.Replace($anchor,$helper+$anchor)

    $old='                    if(mirrored){for(int i=0;i+2<ix.Length;i+=3){indices.Add((uint)(baseVertex+ix[i]));indices.Add((uint)(baseVertex+ix[i+2]));indices.Add((uint)(baseVertex+ix[i+1]));}}'+[Environment]::NewLine+'                    else{for(int i=0;i<ix.Length;i++)indices.Add((uint)(baseVertex+ix[i]));}'
    $new='                    bool flipWinding=ShouldFlipWinding(vertices,baseVertex,ix,mirrored);'+[Environment]::NewLine+'                    if(flipWinding){for(int i=0;i+2<ix.Length;i+=3){indices.Add((uint)(baseVertex+ix[i]));indices.Add((uint)(baseVertex+ix[i+2]));indices.Add((uint)(baseVertex+ix[i+1]));}}'+[Environment]::NewLine+'                    else{for(int i=0;i<ix.Length;i++)indices.Add((uint)(baseVertex+ix[i]));}'
    if(-not$text.Contains($old)){throw 'v0.30.5 adaptive-winding index anchor is missing.'}
    $text=$text.Replace($old,$new)
    Set-Content -LiteralPath $compiler -Value $text -Encoding UTF8
}

# Give the corrected compiler a new cache namespace so all existing HC3D v4
# files rebuild automatically without deleting the user's model folder or asking
# for manual cache cleanup. The binary layout remains HC3D v4; only the cache key
# changes because compiled winding semantics changed.
$runtimeText=Get-Content -Raw -LiteralPath $runtime -Encoding UTF8
$oldCache="return (Join-Path `$script:HcGpuShelfCacheDir (`$name+'.hc3d'))"
$newCache="return (Join-Path `$script:HcGpuShelfCacheDir (`$name+'.winding-v2.hc3d'))"
if($runtimeText.Contains($newCache)){}
elseif($runtimeText.Contains($oldCache)){$runtimeText=$runtimeText.Replace($oldCache,$newCache);Set-Content -LiteralPath $runtime -Value $runtimeText -Encoding UTF8}
else{throw 'v0.30.5 cache-namespace anchor is missing.'}

Write-Host 'Applied v0.30.5 adaptive transformed-normal winding repair and cache namespace refresh.'
