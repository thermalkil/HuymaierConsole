Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$compiler=Join-Path $root 'Native\HuymaierGpuShelfAssetCompiler.cs'
$loader=Join-Path $root 'Native\HuymaierModelPreviewWorker.cs'
$aliases=Join-Path $root 'Native\HuymaierModelPreviewWpfAliases.cs'
$runtime=Join-Path $root 'HuymaierGpuPlatformShelves.ps1'
foreach($p in @($compiler,$loader,$aliases,$runtime)){if(-not(Test-Path -LiteralPath $p -PathType Leaf)){throw "v0.30.5 winding test source missing: $p"}}

$text=Get-Content -Raw -LiteralPath $compiler -Encoding UTF8
foreach($needle in @('HUYMAIER_V0305_ADAPTIVE_WINDING_V1','ShouldFlipWinding','bool flipWinding=ShouldFlipWinding(vertices,baseVertex,ix,mirrored)','if(mirrored)tw=-tw;')){
    if($text.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "v0.30.5 adaptive-winding contract missing: $needle"}
}
$runtimeText=Get-Content -Raw -LiteralPath $runtime -Encoding UTF8
if($runtimeText.IndexOf("`$name+'.winding-v2.hc3d'",[StringComparison]::Ordinal)-lt0){throw 'v0.30.5 corrected cache namespace is missing.'}
Write-Host 'modelAdaptiveWindingSourceGate: success'
Write-Host 'modelAdaptiveWindingCacheNamespaceGate: success'

Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Xaml,System.Web.Extensions
$csc=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if(-not(Test-Path -LiteralPath $csc -PathType Leaf)){throw 'Framework64 csc.exe missing.'}
$temp=Join-Path $(if($env:RUNNER_TEMP){$env:RUNNER_TEMP}else{[IO.Path]::GetTempPath()}) ('hc-v0305-winding-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $temp|Out-Null

function New-HcWindingProbeGlb {
    param([Parameter(Mandatory=$true)][string]$Path,[Parameter(Mandatory=$true)][uint16[]]$TriangleIndices)
    $ms=New-Object IO.MemoryStream;$bw=New-Object IO.BinaryWriter($ms)
    try{
        foreach($f in @([single]-1,[single]-1,[single]0,[single]1,[single]-1,[single]0,[single]0,[single]1,[single]0)){$bw.Write($f)}
        foreach($i in 0..2){$bw.Write([single]0);$bw.Write([single]0);$bw.Write([single]1)}
        foreach($ix in $TriangleIndices){$bw.Write([uint16]$ix)}
        while(($ms.Position%4)-ne0){$bw.Write([byte]0)}
        $bw.Flush();$bin=[byte[]]$ms.ToArray()
    }finally{$bw.Dispose();$ms.Dispose()}
    $json="{`"asset`":{`"version`":`"2.0`"},`"scene`":0,`"scenes`":[{`"nodes`":[0]}],`"nodes`":[{`"mesh`":0,`"scale`":[-1,1,1]}],`"meshes`":[{`"primitives`":[{`"attributes`":{`"POSITION`":0,`"NORMAL`":1},`"indices`":2,`"material`":0,`"mode`":4}]}],`"materials`":[{`"doubleSided`":false,`"pbrMetallicRoughness`":{`"baseColorFactor`":[1,1,1,1]}}],`"buffers`":[{`"byteLength`":$($bin.Length)}],`"bufferViews`":[{`"buffer`":0,`"byteOffset`":0,`"byteLength`":36},{`"buffer`":0,`"byteOffset`":36,`"byteLength`":36},{`"buffer`":0,`"byteOffset`":72,`"byteLength`":6}],`"accessors`":[{`"bufferView`":0,`"componentType`":5126,`"count`":3,`"type`":`"VEC3`"},{`"bufferView`":1,`"componentType`":5126,`"count`":3,`"type`":`"VEC3`"},{`"bufferView`":2,`"componentType`":5123,`"count`":3,`"type`":`"SCALAR`"}]}"
    $jb=[Text.Encoding]::UTF8.GetBytes($json);$pad=(4-($jb.Length%4))%4;$jc=New-Object byte[]($jb.Length+$pad);[Array]::Copy($jb,$jc,$jb.Length);for($i=$jb.Length;$i-lt$jc.Length;$i++){$jc[$i]=0x20}
    $total=12+8+$jc.Length+8+$bin.Length
    $fs=[IO.File]::Create($Path);$out=New-Object IO.BinaryWriter($fs)
    try{$out.Write([byte[]](0x67,0x6C,0x54,0x46));$out.Write([uint32]2);$out.Write([uint32]$total);$out.Write([uint32]$jc.Length);$out.Write([uint32]0x4E4F534A);$out.Write($jc);$out.Write([uint32]$bin.Length);$out.Write([uint32]0x004E4942);$out.Write($bin)}finally{$out.Dispose();$fs.Dispose()}
}

function Get-HcCompiledTriangle {
    param([Parameter(Mandatory=$true)][string]$CachePath)
    $br=New-Object IO.BinaryReader([IO.File]::OpenRead($CachePath))
    try{
        if((-join$br.ReadChars(4))-ne'HC3D'){throw 'Compiled winding probe cache magic is invalid.'}
        $version=$br.ReadInt32();if($version-ne3-and$version-ne4){throw "Unexpected HC3D cache version $version"}
        [void]$br.ReadInt64();[void]$br.ReadInt64();[void]$br.ReadInt32();$vc=$br.ReadInt32();$ic=$br.ReadInt32();[void]$br.ReadInt32();[void]$br.ReadInt32();for($i=0;$i-lt6;$i++){[void]$br.ReadSingle()}
        if($vc-ne3-or$ic-ne3){throw "Unexpected winding probe counts v=$vc i=$ic"}
        $stride=$(if($version-eq4){96}else{80});$br.BaseStream.Position+=($vc*$stride)
        return @($br.ReadUInt32(),$br.ReadUInt32(),$br.ReadUInt32())
    }finally{$br.Dispose()}
}

try{
    $framework=[Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory();$dll=Join-Path $temp 'HuymaierGpuAssetCompiler.dll'
    $refs=@([Uri].Assembly.Location,[Linq.Enumerable].Assembly.Location,[Web.Script.Serialization.JavaScriptSerializer].Assembly.Location,[ComponentModel.ISupportInitialize].Assembly.Location,[Windows.DependencyObject].Assembly.Location,[Windows.Media.Visual].Assembly.Location,[Windows.Window].Assembly.Location,(Join-Path $framework 'System.Xaml.dll'))|Select-Object -Unique
    $args=@('/noconfig','/nologo','/target:library','/platform:x64','/optimize+',('/out:'+$dll));foreach($r in $refs){$args+=('/reference:'+$r)};$args+=@($loader,$aliases,$compiler)
    & $csc @args
    if($LASTEXITCODE-ne0-or-not(Test-Path -LiteralPath $dll -PathType Leaf)){throw 'v0.30.5 adaptive-winding compiler build failed.'}
    Add-Type -Path $dll

    $canonicalGlb=Join-Path $temp 'negative-det-canonical.glb';$canonicalCache=Join-Path $temp 'negative-det-canonical.hc3d'
    New-HcWindingProbeGlb -Path $canonicalGlb -TriangleIndices @([uint16]0,[uint16]1,[uint16]2)
    [HuymaierConsole.Modeling.GpuShelfAssetCompiler]::Compile($canonicalGlb,$canonicalCache,128)
    $canonical=@(Get-HcCompiledTriangle $canonicalCache)
    if(($canonical -join ',')-ne'0,2,1'){throw "Ordinary negative-determinant winding was not repaired: $($canonical -join ',')"}

    # Mirrors the real failure mode: authored local winding is already reversed on
    # a negative-determinant mesh copy. The world transform repairs orientation by
    # itself, so a determinant-only second swap would turn the mesh inside-out.
    $premirroredGlb=Join-Path $temp 'negative-det-premirrored.glb';$premirroredCache=Join-Path $temp 'negative-det-premirrored.hc3d'
    New-HcWindingProbeGlb -Path $premirroredGlb -TriangleIndices @([uint16]0,[uint16]2,[uint16]1)
    [HuymaierConsole.Modeling.GpuShelfAssetCompiler]::Compile($premirroredGlb,$premirroredCache,128)
    $premirrored=@(Get-HcCompiledTriangle $premirroredCache)
    if(($premirrored -join ',')-ne'0,2,1'){throw "Pre-mirrored negative-determinant winding was double-corrected: $($premirrored -join ',')"}

    Write-Host 'modelNegativeDeterminantRepairGate: success'
    Write-Host 'modelPreMirroredNoDoubleFlipGate: success'
    Write-Host 'modelTangentReflectionPreservedGate: success'
}finally{Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue}
