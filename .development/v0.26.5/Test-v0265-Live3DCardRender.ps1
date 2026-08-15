Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$worker=Join-Path $root 'Native\HuymaierModelPreviewWorker.cs'
$aliases=Join-Path $root 'Native\HuymaierModelPreviewWpfAliases.cs'
$control=Join-Path $root 'Native\HuymaierLiveModelControl.cs'
foreach($p in @($worker,$aliases,$control)){if(-not(Test-Path -LiteralPath $p -PathType Leaf)){throw "Live 3D render source missing: $p"}}

Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Xaml,System.Web.Extensions
$csc=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if(-not(Test-Path -LiteralPath $csc -PathType Leaf)){throw 'Framework64 csc.exe was not found.'}
$tempRoot=$(if($env:RUNNER_TEMP){$env:RUNNER_TEMP}else{[IO.Path]::GetTempPath()})
$temp=Join-Path $tempRoot ('hc-live3d-visual-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $temp|Out-Null

function New-HcVisualProbeGlb {
    param([string]$Path)
    $json='{"asset":{"version":"2.0"},"scene":0,"scenes":[{"nodes":[0]}],"nodes":[{"children":[1],"matrix":[1,0,0,0,0,1,0,0,0,0,1,0,5,-2,3,1]},{"mesh":0}],"meshes":[{"primitives":[{"attributes":{"POSITION":0,"NORMAL":1},"indices":2,"material":0,"mode":4}]}],"materials":[{"doubleSided":true,"pbrMetallicRoughness":{"baseColorFactor":[0.92,0.58,0.12,1],"metallicFactor":0.12,"roughnessFactor":0.48}}],"buffers":[{"byteLength":80}],"bufferViews":[{"buffer":0,"byteOffset":0,"byteLength":36},{"buffer":0,"byteOffset":36,"byteLength":36},{"buffer":0,"byteOffset":72,"byteLength":6}],"accessors":[{"bufferView":0,"componentType":5126,"count":3,"type":"VEC3","min":[-1,-0.7,0],"max":[1,1,0]},{"bufferView":1,"componentType":5126,"count":3,"type":"VEC3"},{"bufferView":2,"componentType":5123,"count":3,"type":"SCALAR","min":[0],"max":[2]}]}'
    $jsonBytes=[Text.Encoding]::UTF8.GetBytes($json)
    $jsonPad=(4-($jsonBytes.Length%4))%4
    $jsonChunk=New-Object byte[] ($jsonBytes.Length+$jsonPad)
    [Array]::Copy($jsonBytes,$jsonChunk,$jsonBytes.Length)
    for($i=$jsonBytes.Length;$i-lt$jsonChunk.Length;$i++){$jsonChunk[$i]=0x20}
    $binStream=New-Object IO.MemoryStream
    $bw=New-Object IO.BinaryWriter($binStream)
    foreach($f in @([single]-1,[single]-0.7,[single]0,[single]1,[single]-0.7,[single]0,[single]0,[single]1,[single]0)){$bw.Write($f)}
    foreach($f in @([single]0,[single]0,[single]1,[single]0,[single]0,[single]1,[single]0,[single]0,[single]1)){$bw.Write($f)}
    foreach($ix in @([uint16]0,[uint16]1,[uint16]2)){$bw.Write($ix)}
    $bw.Write([uint16]0)
    $bw.Flush();$bin=$binStream.ToArray();$bw.Dispose();$binStream.Dispose()
    $total=12+8+$jsonChunk.Length+8+$bin.Length
    $fs=[IO.File]::Create($Path);$out=New-Object IO.BinaryWriter($fs)
    try{
        $out.Write([byte[]](0x67,0x6C,0x54,0x46));$out.Write([uint32]2);$out.Write([uint32]$total)
        $out.Write([uint32]$jsonChunk.Length);$out.Write([uint32]0x4E4F534A);$out.Write($jsonChunk)
        $out.Write([uint32]$bin.Length);$out.Write([uint32]0x004E4942);$out.Write($bin)
    }finally{$out.Dispose();$fs.Dispose()}
}

function Assert-HcViewHasVisiblePixels {
    param($View,[string]$Label)
    $width=160;$height=120
    $View.Width=$width;$View.Height=$height
    $View.Measure((New-Object Windows.Size($width,$height)))
    $View.Arrange((New-Object Windows.Rect(0,0,$width,$height)))
    $View.UpdateLayout()
    $bitmap=New-Object Windows.Media.Imaging.RenderTargetBitmap($width,$height,96,96,[Windows.Media.PixelFormats]::Pbgra32)
    $bitmap.Render($View)
    $stride=$width*4
    $pixels=New-Object byte[] ($stride*$height)
    $bitmap.CopyPixels($pixels,$stride,0)
    $visible=0
    for($i=3;$i-lt$pixels.Length;$i+=4){if($pixels[$i]-gt12){$visible++}}
    if($visible-lt100){throw "$Label rendered only $visible non-transparent pixels; live 3D visual is effectively blank."}
    Write-Host ($Label+' visiblePixels='+$visible)
}

try{
    $refs=@([Uri].Assembly.Location,[Linq.Enumerable].Assembly.Location,[Web.Script.Serialization.JavaScriptSerializer].Assembly.Location,[Windows.DependencyObject].Assembly.Location,[Windows.Media.Visual].Assembly.Location,[Windows.Window].Assembly.Location,[System.Xaml.XamlReader].Assembly.Location)|Select-Object -Unique
    $dll=Join-Path $temp 'HuymaierLiveModel3D.dll'
    $args=@('/noconfig','/nologo','/target:library','/platform:x64','/optimize+',('/out:'+$dll))
    foreach($r in $refs){$args+=('/reference:'+$r)}
    $args+=@($worker,$aliases,$control)
    & $csc @args
    if($LASTEXITCODE-ne0-or-not(Test-Path -LiteralPath $dll -PathType Leaf)){throw 'Live 3D visual-probe DLL compilation failed.'}
    Add-Type -Path $dll
    $glb=Join-Path $temp 'visual-probe.glb';New-HcVisualProbeGlb $glb

    $card=New-Object HuymaierConsole.Modeling.LiveModelView -ArgumentList @($glb,$true)
    if(-not[bool]$card.CardMode){throw 'Card-mode LiveModelView did not enter lightweight card mode.'}
    if([int]$card.GeometryCount-ne1-or[int]$card.VertexCount-ne3){throw "Card-mode scene counts are unexpected: geometry=$($card.GeometryCount) vertices=$($card.VertexCount)"}
    Assert-HcViewHasVisiblePixels $card 'cardModeLive3D'
    $startYaw=[double]$card.Yaw;$card.Rotate(14,5);$card.Zoom(.25);$card.SetScalePercent(130)
    if([math]::Abs([double]$card.Yaw-$startYaw)-lt1){throw 'Card-mode live model did not rotate.'}
    Assert-HcViewHasVisiblePixels $card 'cardModeLive3DRotated'

    $full=New-Object HuymaierConsole.Modeling.LiveModelView -ArgumentList $glb
    if([bool]$full.CardMode){throw 'Full viewer unexpectedly entered card mode.'}
    Assert-HcViewHasVisiblePixels $full 'fullViewerLive3D'

    Write-Host 'platformModelLiveCardPixelGate: success'
    Write-Host 'platformModelLiveCardGeometryOnlyGate: success'
    Write-Host 'platformModelFullViewerPixelGate: success'
}finally{Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue}
