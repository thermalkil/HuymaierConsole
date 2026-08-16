Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$loader=Join-Path $root 'Native\HuymaierModelPreviewWorker.cs'
$aliases=Join-Path $root 'Native\HuymaierModelPreviewWpfAliases.cs'
$compiler=Join-Path $root 'Native\HuymaierGpuShelfAssetCompiler.cs'
foreach($p in @($loader,$aliases,$compiler)){if(-not(Test-Path -LiteralPath $p -PathType Leaf)){throw "GPU shelf compiler source missing: $p"}}
$compilerText=Get-Content -Raw -LiteralPath $compiler -Encoding UTF8
foreach($n in @('HUYMAIER_GPU_SHELF_ASSET_CACHE_V1','DefaultShelfTextureSize = 512','IsCacheCurrent','EnsureCompiled','DecodePixelWidth','DecodePixelHeight','TEXCOORD_0','EmissiveTexture','LastWriteTimeUtc.Ticks')){if($compilerText.IndexOf($n,[StringComparison]::Ordinal)-lt0){throw "GPU shelf compiler contract missing: $n"}}
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Xaml,System.Web.Extensions
$csc=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe';if(-not(Test-Path $csc)){throw 'Framework64 csc.exe missing.'}
$temp=Join-Path $(if($env:RUNNER_TEMP){$env:RUNNER_TEMP}else{[IO.Path]::GetTempPath()}) ('hc-gpu-cache-'+[guid]::NewGuid().ToString('N'));New-Item -ItemType Directory -Force -Path $temp|Out-Null
function New-LargeCheckerPng{
    $w=1024;$h=512;$stride=$w*4;$pixels=New-Object byte[] ($stride*$h)
    for($y=0;$y-lt$h;$y++){for($x=0;$x-lt$w;$x++){$o=$y*$stride+$x*4;if((($x/128)+($y/128))%2-lt1){$pixels[$o]=32;$pixels[$o+1]=60;$pixels[$o+2]=235}else{$pixels[$o]=220;$pixels[$o+1]=180;$pixels[$o+2]=32};$pixels[$o+3]=255}}
    $bmp=[Windows.Media.Imaging.BitmapSource]::Create($w,$h,96,96,[Windows.Media.PixelFormats]::Bgra32,$null,$pixels,$stride);$enc=New-Object Windows.Media.Imaging.PngBitmapEncoder;$enc.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bmp));$ms=New-Object IO.MemoryStream;try{$enc.Save($ms);return ,([byte[]]$ms.ToArray())}finally{$ms.Dispose()}
}
function New-ProbeGlb([string]$Path){
    $png=New-LargeCheckerPng;$ms=New-Object IO.MemoryStream;$bw=New-Object IO.BinaryWriter($ms)
    try{
        foreach($f in @([single](-1),[single](-.6),[single]0,[single]1,[single](-.6),[single]0,[single]1,[single](.6),[single]0,[single](-1),[single](.6),[single]0)){$bw.Write($f)}
        foreach($i in 0..3){$bw.Write([single]0);$bw.Write([single]0);$bw.Write([single]1)}
        foreach($f in @([single]0,[single]0,[single]1,[single]0,[single]1,[single]1,[single]0,[single]1)){$bw.Write($f)}
        foreach($ix in @([uint16]0,[uint16]1,[uint16]2,[uint16]0,[uint16]2,[uint16]3)){$bw.Write($ix)}
        $img=[int]$ms.Position;$bw.Write($png);while(($ms.Position%4)-ne0){$bw.Write([byte]0)};$bw.Flush();$bin=[byte[]]$ms.ToArray()
    }finally{$bw.Dispose();$ms.Dispose()}
    $json="{`"asset`":{`"version`":`"2.0`"},`"scene`":0,`"scenes`":[{`"nodes`":[0]}],`"nodes`":[{`"mesh`":0,`"translation`":[.25,0,0]}],`"meshes`":[{`"primitives`":[{`"attributes`":{`"POSITION`":0,`"NORMAL`":1,`"TEXCOORD_0`":2},`"indices`":3,`"material`":0,`"mode`":4}]}],`"materials`":[{`"pbrMetallicRoughness`":{`"baseColorTexture`":{`"index`":0},`"metallicFactor`":.2,`"roughnessFactor`":.7}}],`"samplers`":[{`"wrapS`":10497,`"wrapT`":10497}],`"textures`":[{`"sampler`":0,`"source`":0}],`"images`":[{`"bufferView`":4,`"mimeType`":`"image/png`"}],`"buffers`":[{`"byteLength`":$($bin.Length)}],`"bufferViews`":[{`"buffer`":0,`"byteOffset`":0,`"byteLength`":48},{`"buffer`":0,`"byteOffset`":48,`"byteLength`":48},{`"buffer`":0,`"byteOffset`":96,`"byteLength`":32},{`"buffer`":0,`"byteOffset`":128,`"byteLength`":12},{`"buffer`":0,`"byteOffset`":$img,`"byteLength`":$($png.Length)}],`"accessors`":[{`"bufferView`":0,`"componentType`":5126,`"count`":4,`"type`":`"VEC3`"},{`"bufferView`":1,`"componentType`":5126,`"count`":4,`"type`":`"VEC3`"},{`"bufferView`":2,`"componentType`":5126,`"count`":4,`"type`":`"VEC2`"},{`"bufferView`":3,`"componentType`":5123,`"count`":6,`"type`":`"SCALAR`"}]}"
    $jb=[Text.Encoding]::UTF8.GetBytes($json);$pad=(4-($jb.Length%4))%4;$jc=New-Object byte[] ($jb.Length+$pad);[Array]::Copy($jb,$jc,$jb.Length);for($i=$jb.Length;$i-lt$jc.Length;$i++){$jc[$i]=0x20};$total=12+8+$jc.Length+8+$bin.Length
    $fs=[IO.File]::Create($Path);$out=New-Object IO.BinaryWriter($fs);try{$out.Write([byte[]](0x67,0x6C,0x54,0x46));$out.Write([uint32]2);$out.Write([uint32]$total);$out.Write([uint32]$jc.Length);$out.Write([uint32]0x4E4F534A);$out.Write($jc);$out.Write([uint32]$bin.Length);$out.Write([uint32]0x004E4942);$out.Write($bin)}finally{$out.Dispose();$fs.Dispose()}
}
try{
    $framework=[Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory();$dll=Join-Path $temp 'HuymaierGpuAssetCompiler.dll';$refs=@([Uri].Assembly.Location,[Linq.Enumerable].Assembly.Location,[Web.Script.Serialization.JavaScriptSerializer].Assembly.Location,[ComponentModel.ISupportInitialize].Assembly.Location,[Windows.DependencyObject].Assembly.Location,[Windows.Media.Visual].Assembly.Location,[Windows.Window].Assembly.Location,(Join-Path $framework 'System.Xaml.dll'))|Select-Object -Unique;$args=@('/noconfig','/nologo','/target:library','/platform:x64','/optimize+',('/out:'+$dll));foreach($r in $refs){$args+=('/reference:'+$r)};$args+=@($loader,$aliases,$compiler);&$csc @args;if($LASTEXITCODE-ne0-or-not(Test-Path $dll)){throw 'GPU shelf asset compiler managed build failed.'};Add-Type -Path $dll
    $glb=Join-Path $temp 'probe.glb';$cache=Join-Path $temp 'probe.hc3d';New-ProbeGlb $glb
    [HuymaierConsole.Modeling.GpuShelfAssetCompiler]::EnsureCompiled($glb,$cache,512)|Out-Null
    if(-not(Test-Path $cache)){throw 'GPU shelf cache was not created.'};if(-not[HuymaierConsole.Modeling.GpuShelfAssetCompiler]::IsCacheCurrent($glb,$cache,512)){throw 'Fresh GPU shelf cache was not recognized as current.'};if([HuymaierConsole.Modeling.GpuShelfAssetCompiler]::IsCacheCurrent($glb,$cache,256)){throw 'GPU shelf cache incorrectly ignores quality tier.'}
    $br=New-Object IO.BinaryReader([IO.File]::OpenRead($cache));try{$magic=-join$br.ReadChars(4);$version=$br.ReadInt32();$sourceLength=$br.ReadInt64();$ticks=$br.ReadInt64();$quality=$br.ReadInt32();$vc=$br.ReadInt32();$ic=$br.ReadInt32();$dc=$br.ReadInt32();$images=$br.ReadInt32();for($i=0;$i-lt6;$i++){[void]$br.ReadSingle()};if($magic-ne'HC3D'-or$version-ne1-or$quality-ne512){throw 'GPU shelf cache header is invalid.'};if($vc-ne4-or$ic-ne6-or$dc-ne1-or$images-ne1){throw "GPU shelf cache counts unexpected: vertices=$vc indices=$ic draws=$dc images=$images"};$br.BaseStream.Position+=($vc*40)+($ic*4)+($dc*92);$iw=$br.ReadInt32();$ih=$br.ReadInt32();$bytes=$br.ReadInt32();if($iw-ne512-or$ih-ne256){throw "Shelf texture was not downsampled to 512x256 (got ${iw}x${ih})."};if($bytes-ne$iw*$ih*4){throw 'GPU shelf cache texture is not packed BGRA32.'}}finally{$br.Dispose()}
    Write-Host 'platformModelGpuAssetCompilerGate: success';Write-Host 'platformModelGpuCacheFreshnessGate: success';Write-Host 'platformModelGpuTextureDownsampleGate: success';Write-Host 'platformModelGpuCacheGeometryGate: success'
}finally{Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue}
