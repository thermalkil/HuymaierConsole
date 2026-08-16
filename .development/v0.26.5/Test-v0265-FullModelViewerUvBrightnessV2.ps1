Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$source=Join-Path $PSScriptRoot 'Test-v0265-FullModelViewerUvBrightness.ps1'
$raw=([IO.File]::ReadAllText($source)).Replace("`r`n","`n")
$old=@'
function New-QuadPng {
    $w=2;$h=2;$stride=8;$pixels=New-Object byte[] 16
    # BGRA: top-left red, top-right green, bottom-left blue, bottom-right yellow.
    $colors=@(@(12,12,110,255),@(12,110,12,255),@(110,12,12,255),@(12,100,100,255))
    for($i=0;$i-lt4;$i++){$o=$i*4;$pixels[$o]=[byte]$colors[$i][0];$pixels[$o+1]=[byte]$colors[$i][1];$pixels[$o+2]=[byte]$colors[$i][2];$pixels[$o+3]=255}
    $bmp=[Windows.Media.Imaging.BitmapSource]::Create($w,$h,96,96,[Windows.Media.PixelFormats]::Bgra32,$null,$pixels,$stride);$enc=New-Object Windows.Media.Imaging.PngBitmapEncoder;$enc.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bmp));$ms=New-Object IO.MemoryStream;try{$enc.Save($ms);return ,([byte[]]$ms.ToArray())}finally{$ms.Dispose()}
}
'@
$new=@'
function New-QuadPng {
    $w=8;$h=8;$stride=$w*4;$pixels=New-Object byte[] ($stride*$h)
    # Four solid 4x4 regions leave ample room away from bilinear boundaries.
    for($y=0;$y-lt$h;$y++){
        for($x=0;$x-lt$w;$x++){
            if($y-lt4-and$x-lt4){$b=2;$g=2;$r=40}
            elseif($y-lt4){$b=2;$g=40;$r=2}
            elseif($x-lt4){$b=40;$g=2;$r=2}
            else{$b=2;$g=35;$r=35}
            $o=$y*$stride+$x*4;$pixels[$o]=[byte]$b;$pixels[$o+1]=[byte]$g;$pixels[$o+2]=[byte]$r;$pixels[$o+3]=255
        }
    }
    $bmp=[Windows.Media.Imaging.BitmapSource]::Create($w,$h,96,96,[Windows.Media.PixelFormats]::Bgra32,$null,$pixels,$stride);$enc=New-Object Windows.Media.Imaging.PngBitmapEncoder;$enc.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bmp));$ms=New-Object IO.MemoryStream;try{$enc.Save($ms);return ,([byte[]]$ms.ToArray())}finally{$ms.Dispose()}
}
'@
if(-not$raw.Contains($old)){throw 'Viewer V2 texture-generator anchor missing.'}
$raw=$raw.Replace($old,$new)
$old=@'
    $render=Render-View $view
    Assert-Color (Sample $render 115 115) 'R';Assert-Color (Sample $render 205 115) 'G';Assert-Color (Sample $render 115 205) 'B';Assert-Color (Sample $render 205 205) 'Y'
'@
$new=@'
    $render=Render-View $view
    $tl=Sample $render 115 115;$tr=Sample $render 205 115;$bl=Sample $render 115 205;$br=Sample $render 205 205
    Write-Host ("fullViewerUvSamples TL=R{0:N1}/G{1:N1}/B{2:N1} TR=R{3:N1}/G{4:N1}/B{5:N1} BL=R{6:N1}/G{7:N1}/B{8:N1} BR=R{9:N1}/G{10:N1}/B{11:N1}" -f $tl.R,$tl.G,$tl.B,$tr.R,$tr.G,$tr.B,$bl.R,$bl.G,$bl.B,$br.R,$br.G,$br.B)
    Assert-Color $tl 'R';Assert-Color $tr 'G';Assert-Color $bl 'B';Assert-Color $br 'Y'
'@
if(-not$raw.Contains($old)){throw 'Viewer V2 sample anchor missing.'}
$raw=$raw.Replace($old,$new)
$temp=Join-Path $env:TEMP ('hc-full-viewer-v2-'+[guid]::NewGuid().ToString('N')+'.ps1')
try{[IO.File]::WriteAllText($temp,$raw,(New-Object Text.UTF8Encoding($false)));& $temp}finally{Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue}
