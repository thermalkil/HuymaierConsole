Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$worker=Join-Path $root 'Native\HuymaierModelPreviewWorker.cs'
$aliases=Join-Path $root 'Native\HuymaierModelPreviewWpfAliases.cs'
$control=Join-Path $root 'Native\HuymaierLiveModelControl.cs'
foreach($p in @($worker,$aliases,$control)){if(-not(Test-Path -LiteralPath $p -PathType Leaf)){throw "Full viewer source missing: $p"}}
$wt=Get-Content -Raw -LiteralPath $worker -Encoding UTF8;$ct=Get-Content -Raw -LiteralPath $control -Encoding UTF8
if($wt.Contains('return new Point(su, 1.0 - sv)')-or$wt.Contains('return new Point(u, 1.0 - v)')){throw 'Full viewer still vertically inverts glTF UVs.'}
foreach($n in @('return new Point(su, sv)','return new Point(u, v)')){if(-not$wt.Contains($n)){throw "Full viewer authored-UV contract missing: $n"}}
foreach($n in @('SetBrightnessPercent','BrightnessPercent','brightnessLight')){if(-not$ct.Contains($n)){throw "Full viewer brightness contract missing: $n"}}

Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Xaml,System.Web.Extensions
$csc=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe';if(-not(Test-Path -LiteralPath $csc -PathType Leaf)){throw 'Framework64 csc.exe missing.'}
$temp=Join-Path $(if($env:RUNNER_TEMP){$env:RUNNER_TEMP}else{[IO.Path]::GetTempPath()}) ('hc-fullviewer-uv-'+[guid]::NewGuid().ToString('N'));New-Item -ItemType Directory -Force -Path $temp|Out-Null
function New-QuadPng {
    $w=2;$h=2;$stride=8;$pixels=New-Object byte[] 16
    # BGRA: top-left red, top-right green, bottom-left blue, bottom-right yellow.
    $colors=@(@(12,12,110,255),@(12,110,12,255),@(110,12,12,255),@(12,100,100,255))
    for($i=0;$i-lt4;$i++){$o=$i*4;$pixels[$o]=[byte]$colors[$i][0];$pixels[$o+1]=[byte]$colors[$i][1];$pixels[$o+2]=[byte]$colors[$i][2];$pixels[$o+3]=255}
    $bmp=[Windows.Media.Imaging.BitmapSource]::Create($w,$h,96,96,[Windows.Media.PixelFormats]::Bgra32,$null,$pixels,$stride);$enc=New-Object Windows.Media.Imaging.PngBitmapEncoder;$enc.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bmp));$ms=New-Object IO.MemoryStream;try{$enc.Save($ms);return ,([byte[]]$ms.ToArray())}finally{$ms.Dispose()}
}
function New-UvProbeGlb([string]$Path){
    $png=New-QuadPng;$ms=New-Object IO.MemoryStream;$bw=New-Object IO.BinaryWriter($ms)
    try{
        foreach($f in @([single]-1,[single]-1,[single]0,[single]1,[single]-1,[single]0,[single]1,[single]1,[single]0,[single]-1,[single]1,[single]0)){$bw.Write($f)}
        foreach($i in 0..3){$bw.Write([single]0);$bw.Write([single]0);$bw.Write([single]1)}
        # glTF UV origin is top-left: geometry bottom-left uses (0,1), etc.
        foreach($f in @([single]0,[single]1,[single]1,[single]1,[single]1,[single]0,[single]0,[single]0)){$bw.Write($f)}
        foreach($ix in @([uint16]0,[uint16]1,[uint16]2,[uint16]0,[uint16]2,[uint16]3)){$bw.Write($ix)}
        $img=[int]$ms.Position;$bw.Write($png);while(($ms.Position%4)-ne0){$bw.Write([byte]0)};$bw.Flush();$bin=[byte[]]$ms.ToArray()
    }finally{$bw.Dispose();$ms.Dispose()}
    $json="{`"asset`":{`"version`":`"2.0`"},`"extensionsUsed`":[`"KHR_materials_unlit`"],`"scene`":0,`"scenes`":[{`"nodes`":[0]}],`"nodes`":[{`"mesh`":0}],`"meshes`":[{`"primitives`":[{`"attributes`":{`"POSITION`":0,`"NORMAL`":1,`"TEXCOORD_0`":2},`"indices`":3,`"material`":0,`"mode`":4}]}],`"materials`":[{`"doubleSided`":true,`"pbrMetallicRoughness`":{`"baseColorTexture`":{`"index`":0},`"roughnessFactor`":1},`"extensions`":{`"KHR_materials_unlit`":{}}}],`"samplers`":[{`"wrapS`":33071,`"wrapT`":33071}],`"textures`":[{`"sampler`":0,`"source`":0}],`"images`":[{`"bufferView`":4,`"mimeType`":`"image/png`"}],`"buffers`":[{`"byteLength`":$($bin.Length)}],`"bufferViews`":[{`"buffer`":0,`"byteOffset`":0,`"byteLength`":48},{`"buffer`":0,`"byteOffset`":48,`"byteLength`":48},{`"buffer`":0,`"byteOffset`":96,`"byteLength`":32},{`"buffer`":0,`"byteOffset`":128,`"byteLength`":12},{`"buffer`":0,`"byteOffset`":$img,`"byteLength`":$($png.Length)}],`"accessors`":[{`"bufferView`":0,`"componentType`":5126,`"count`":4,`"type`":`"VEC3`"},{`"bufferView`":1,`"componentType`":5126,`"count`":4,`"type`":`"VEC3`"},{`"bufferView`":2,`"componentType`":5126,`"count`":4,`"type`":`"VEC2`"},{`"bufferView`":3,`"componentType`":5123,`"count`":6,`"type`":`"SCALAR`"}]}"
    $jb=[Text.Encoding]::UTF8.GetBytes($json);$pad=(4-($jb.Length%4))%4;$jc=New-Object byte[]($jb.Length+$pad);[Array]::Copy($jb,$jc,$jb.Length);for($i=$jb.Length;$i-lt$jc.Length;$i++){$jc[$i]=0x20};$total=12+8+$jc.Length+8+$bin.Length
    $fs=[IO.File]::Create($Path);$out=New-Object IO.BinaryWriter($fs);try{$out.Write([byte[]](0x67,0x6C,0x54,0x46));$out.Write([uint32]2);$out.Write([uint32]$total);$out.Write([uint32]$jc.Length);$out.Write([uint32]0x4E4F534A);$out.Write($jc);$out.Write([uint32]$bin.Length);$out.Write([uint32]0x004E4942);$out.Write($bin)}finally{$out.Dispose();$fs.Dispose()}
}
function Render-View($View){$size=320;$View.Width=$size;$View.Height=$size;$View.Measure((New-Object Windows.Size($size,$size)));$View.Arrange((New-Object Windows.Rect(0,0,$size,$size)));$View.UpdateLayout();$bmp=New-Object Windows.Media.Imaging.RenderTargetBitmap($size,$size,96,96,[Windows.Media.PixelFormats]::Pbgra32);$bmp.Render($View);$stride=$size*4;$pixels=New-Object byte[] ($stride*$size);$bmp.CopyPixels($pixels,$stride,0);[pscustomobject]@{Pixels=$pixels;Size=$size;Stride=$stride}}
function Sample($Render,[int]$cx,[int]$cy){$b=0;$g=0;$r=0;$count=0;for($y=$cy-3;$y-le$cy+3;$y++){for($x=$cx-3;$x-le$cx+3;$x++){$o=$y*$Render.Stride+$x*4;if($Render.Pixels[$o+3]-lt128){continue};$b+=$Render.Pixels[$o];$g+=$Render.Pixels[$o+1];$r+=$Render.Pixels[$o+2];$count++}};if($count-eq0){throw "No visible pixels around $cx,$cy"};[pscustomobject]@{R=$r/$count;G=$g/$count;B=$b/$count}}
function Assert-Color($c,[string]$kind){switch($kind){'R'{if(-not($c.R-gt$c.G*1.5-and$c.R-gt$c.B*1.5)){throw "Expected red, got R=$($c.R) G=$($c.G) B=$($c.B)"}}'G'{if(-not($c.G-gt$c.R*1.5-and$c.G-gt$c.B*1.5)){throw "Expected green, got R=$($c.R) G=$($c.G) B=$($c.B)"}}'B'{if(-not($c.B-gt$c.R*1.5-and$c.B-gt$c.G*1.5)){throw "Expected blue, got R=$($c.R) G=$($c.G) B=$($c.B)"}}'Y'{if(-not($c.R-gt$c.B*1.5-and$c.G-gt$c.B*1.5)){throw "Expected yellow, got R=$($c.R) G=$($c.G) B=$($c.B)"}}}}
function Avg-Luma($Render){[double]$sum=0;$count=0;for($y=0;$y-lt$Render.Size;$y+=2){for($x=0;$x-lt$Render.Size;$x+=2){$o=$y*$Render.Stride+$x*4;if($Render.Pixels[$o+3]-lt128){continue};$sum+=(0.2126*$Render.Pixels[$o+2]+0.7152*$Render.Pixels[$o+1]+0.0722*$Render.Pixels[$o]);$count++}};if($count-lt100){throw 'Viewer brightness probe rendered too few visible pixels.'};$sum/$count}
try{
    $refs=@([Uri].Assembly.Location,[Linq.Enumerable].Assembly.Location,[Web.Script.Serialization.JavaScriptSerializer].Assembly.Location,[Windows.DependencyObject].Assembly.Location,[Windows.Media.Visual].Assembly.Location,[Windows.Window].Assembly.Location,[System.Xaml.XamlReader].Assembly.Location)|Select-Object -Unique
    $dll=Join-Path $temp 'HuymaierLiveModel3D.dll';$args=@('/noconfig','/nologo','/target:library','/platform:x64','/optimize+',('/out:'+$dll));foreach($r in $refs){$args+=('/reference:'+$r)};$args+=@($worker,$aliases,$control);& $csc @args
    if($LASTEXITCODE-ne0-or-not(Test-Path -LiteralPath $dll -PathType Leaf)){throw 'Full viewer probe DLL compilation failed.'};Add-Type -Path $dll
    $glb=Join-Path $temp 'uv-quadrants.glb';New-UvProbeGlb $glb
    $view=New-Object HuymaierConsole.Modeling.LiveModelView -ArgumentList $glb;$view.SetScalePercent(100);$view.Rotate(-[double]$view.Yaw,-[double]$view.Pitch);$view.SetBrightnessPercent(100)
    $render=Render-View $view
    Assert-Color (Sample $render 115 115) 'R';Assert-Color (Sample $render 205 115) 'G';Assert-Color (Sample $render 115 205) 'B';Assert-Color (Sample $render 205 205) 'Y'
    $l100=Avg-Luma $render;$view.SetBrightnessPercent(200);$render2=Render-View $view;$l200=Avg-Luma $render2
    if($l200-le$l100*1.08){throw "Brightness control did not materially brighten the viewer: 100%=$l100 200%=$l200"}
    Write-Host 'platformModelFullViewerUvOrientationGate: success'
    Write-Host 'platformModelFullViewerHorizontalOrientationGate: success'
    Write-Host 'platformModelFullViewerBrightnessGate: success'
    Write-Host ("platformModelFullViewerLuma: 100%={0:N2} 200%={1:N2}" -f $l100,$l200)
}finally{Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue}
