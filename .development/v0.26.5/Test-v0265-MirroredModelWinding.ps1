Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$loader=Join-Path $root 'Native\HuymaierModelPreviewWorker.cs'
$aliases=Join-Path $root 'Native\HuymaierModelPreviewWpfAliases.cs'
$compiler=Join-Path $root 'Native\HuymaierGpuShelfAssetCompiler.cs'
foreach($p in @($loader,$aliases,$compiler)){if(-not(Test-Path -LiteralPath $p -PathType Leaf)){throw "Mirrored-winding source missing: $p"}}
$text=Get-Content -Raw -LiteralPath $compiler -Encoding UTF8
foreach($n in @('CacheVersion = 2','Determinant3x3','bool mirrored','ix[i + 2]','ix[i + 1]')){if($text.IndexOf($n,[StringComparison]::Ordinal)-lt0){throw "Mirrored-winding compiler contract missing: $n"}}

Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Xaml,System.Web.Extensions
$csc=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if(-not(Test-Path -LiteralPath $csc -PathType Leaf)){throw 'Framework64 csc.exe missing.'}
$temp=Join-Path $(if($env:RUNNER_TEMP){$env:RUNNER_TEMP}else{[IO.Path]::GetTempPath()}) ('hc-mirror-winding-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $temp|Out-Null
try{
    $framework=[Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()
    $dll=Join-Path $temp 'HuymaierGpuAssetCompiler.dll'
    $refs=@([Uri].Assembly.Location,[Linq.Enumerable].Assembly.Location,[Web.Script.Serialization.JavaScriptSerializer].Assembly.Location,[ComponentModel.ISupportInitialize].Assembly.Location,[Windows.DependencyObject].Assembly.Location,[Windows.Media.Visual].Assembly.Location,[Windows.Window].Assembly.Location,(Join-Path $framework 'System.Xaml.dll'))|Select-Object -Unique
    $args=@('/noconfig','/nologo','/target:library','/platform:x64','/optimize+',('/out:'+$dll));foreach($r in $refs){$args+=('/reference:'+$r)};$args+=@($loader,$aliases,$compiler)
    & $csc @args
    if($LASTEXITCODE-ne0-or-not(Test-Path -LiteralPath $dll -PathType Leaf)){throw 'Mirrored-winding compiler build failed.'}
    Add-Type -Path $dll

    $glb=Join-Path $temp 'mirrored.glb';$cache=Join-Path $temp 'mirrored.hc3d'
    $ms=New-Object IO.MemoryStream;$bw=New-Object IO.BinaryWriter($ms)
    try{
        foreach($f in @([single]-1,[single]-1,[single]0,[single]1,[single]-1,[single]0,[single]0,[single]1,[single]0)){$bw.Write($f)}
        foreach($i in 0..2){$bw.Write([single]0);$bw.Write([single]0);$bw.Write([single]1)}
        foreach($ix in @([uint16]0,[uint16]1,[uint16]2)){$bw.Write($ix)}
        while(($ms.Position%4)-ne0){$bw.Write([byte]0)};$bw.Flush();$bin=[byte[]]$ms.ToArray()
    }finally{$bw.Dispose();$ms.Dispose()}
    $json="{`"asset`":{`"version`":`"2.0`"},`"scene`":0,`"scenes`":[{`"nodes`":[0]}],`"nodes`":[{`"mesh`":0,`"scale`":[-1,1,1]}],`"meshes`":[{`"primitives`":[{`"attributes`":{`"POSITION`":0,`"NORMAL`":1},`"indices`":2,`"material`":0,`"mode`":4}]}],`"materials`":[{`"doubleSided`":false,`"pbrMetallicRoughness`":{`"baseColorFactor`":[1,1,1,1]}}],`"buffers`":[{`"byteLength`":$($bin.Length)}],`"bufferViews`":[{`"buffer`":0,`"byteOffset`":0,`"byteLength`":36},{`"buffer`":0,`"byteOffset`":36,`"byteLength`":36},{`"buffer`":0,`"byteOffset`":72,`"byteLength`":6}],`"accessors`":[{`"bufferView`":0,`"componentType`":5126,`"count`":3,`"type`":`"VEC3`"},{`"bufferView`":1,`"componentType`":5126,`"count`":3,`"type`":`"VEC3`"},{`"bufferView`":2,`"componentType`":5123,`"count`":3,`"type`":`"SCALAR`"}]}"
    $jb=[Text.Encoding]::UTF8.GetBytes($json);$pad=(4-($jb.Length%4))%4;$jc=New-Object byte[]($jb.Length+$pad);[Array]::Copy($jb,$jc,$jb.Length);for($i=$jb.Length;$i-lt$jc.Length;$i++){$jc[$i]=0x20};$total=12+8+$jc.Length+8+$bin.Length
    $fs=[IO.File]::Create($glb);$out=New-Object IO.BinaryWriter($fs);try{$out.Write([byte[]](0x67,0x6C,0x54,0x46));$out.Write([uint32]2);$out.Write([uint32]$total);$out.Write([uint32]$jc.Length);$out.Write([uint32]0x4E4F534A);$out.Write($jc);$out.Write([uint32]$bin.Length);$out.Write([uint32]0x004E4942);$out.Write($bin)}finally{$out.Dispose();$fs.Dispose()}

    [HuymaierConsole.Modeling.GpuShelfAssetCompiler]::Compile($glb,$cache,128)
    $br=New-Object IO.BinaryReader([IO.File]::OpenRead($cache));try{
        if((-join$br.ReadChars(4))-ne'HC3D'){throw 'Mirrored cache magic is invalid.'};if($br.ReadInt32()-ne2){throw 'Mirrored cache is not HC3D v2.'}
        [void]$br.ReadInt64();[void]$br.ReadInt64();[void]$br.ReadInt32();$vc=$br.ReadInt32();$ic=$br.ReadInt32();[void]$br.ReadInt32();[void]$br.ReadInt32();for($i=0;$i-lt6;$i++){[void]$br.ReadSingle()}
        if($vc-ne3-or$ic-ne3){throw "Unexpected mirrored probe counts v=$vc i=$ic"}
        $br.BaseStream.Position+=($vc*40)
        $i0=$br.ReadUInt32();$i1=$br.ReadUInt32();$i2=$br.ReadUInt32()
        if($i0-ne0-or$i1-ne2-or$i2-ne1){throw "Negative-determinant triangle winding was not repaired: $i0,$i1,$i2"}
    }finally{$br.Dispose()}
    Write-Host 'platformModelMirroredNodeDetectionGate: success'
    Write-Host 'platformModelMirroredTriangleWindingGate: success'
    Write-Host 'platformModelHc3dV2CacheGate: success'
}finally{Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue}
