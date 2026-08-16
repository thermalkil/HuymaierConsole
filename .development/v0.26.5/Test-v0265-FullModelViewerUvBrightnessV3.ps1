Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$source=Join-Path $PSScriptRoot 'Test-v0265-FullModelViewerUvBrightness.ps1'
$raw=([IO.File]::ReadAllText($source)).Replace("`r`n","`n")
$newFunction=@'
function New-QuadPng {
    $w=8;$h=8;$stride=$w*4;$pixels=New-Object byte[] ($stride*$h)
    # Four solid 4x4 regions: TL red, TR green, BL blue, BR yellow.
    # Samples are deliberately away from the center seam so bilinear filtering
    # cannot make the orientation assertion ambiguous.
    for($y=0;$y-lt$h;$y++){
        for($x=0;$x-lt$w;$x++){
            if($y-lt4-and$x-lt4){$b=2;$g=2;$r=220}
            elseif($y-lt4){$b=2;$g=220;$r=2}
            elseif($x-lt4){$b=220;$g=2;$r=2}
            else{$b=2;$g=205;$r=205}
            $o=$y*$stride+$x*4
            $pixels[$o]=[byte]$b;$pixels[$o+1]=[byte]$g;$pixels[$o+2]=[byte]$r;$pixels[$o+3]=255
        }
    }
    $bmp=[Windows.Media.Imaging.BitmapSource]::Create($w,$h,96,96,[Windows.Media.PixelFormats]::Bgra32,$null,$pixels,$stride)
    $enc=New-Object Windows.Media.Imaging.PngBitmapEncoder
    $enc.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bmp))
    $ms=New-Object IO.MemoryStream
    try{$enc.Save($ms);return ,([byte[]]$ms.ToArray())}finally{$ms.Dispose()}
}
'@
$newFunction=$newFunction.Replace("`r`n","`n")
$rx=New-Object Text.RegularExpressions.Regex('(?s)function New-QuadPng \{.*?\n\}\n(?=function New-UvProbeGlb)')
if(-not$rx.IsMatch($raw)){throw 'Viewer V3 texture-generator regex did not match.'}
$raw=$rx.Replace($raw,[Text.RegularExpressions.MatchEvaluator]{param($m)$newFunction},1)
# Add sample diagnostics without changing the original assertions.
$needle="    `$render=Render-View `$view`n    Assert-Color (Sample `$render 115 115) 'R';Assert-Color (Sample `$render 205 115) 'G';Assert-Color (Sample `$render 115 205) 'B';Assert-Color (Sample `$render 205 205) 'Y'"
if($raw.Contains($needle)){
    $replacement=@'
    $render=Render-View $view
    $tl=Sample $render 115 115;$tr=Sample $render 205 115;$bl=Sample $render 115 205;$br=Sample $render 205 205
    Write-Host ("fullViewerUvSamples TL=R{0:N1}/G{1:N1}/B{2:N1} TR=R{3:N1}/G{4:N1}/B{5:N1} BL=R{6:N1}/G{7:N1}/B{8:N1} BR=R{9:N1}/G{10:N1}/B{11:N1}" -f $tl.R,$tl.G,$tl.B,$tr.R,$tr.G,$tr.B,$bl.R,$bl.G,$bl.B,$br.R,$br.G,$br.B)
    Assert-Color $tl 'R';Assert-Color $tr 'G';Assert-Color $bl 'B';Assert-Color $br 'Y'
'@
    $raw=$raw.Replace($needle,$replacement.Replace("`r`n","`n"))
}
$temp=Join-Path $env:TEMP ('hc-full-viewer-v3-'+[guid]::NewGuid().ToString('N')+'.ps1')
try{[IO.File]::WriteAllText($temp,$raw,(New-Object Text.UTF8Encoding($false)));& $temp}finally{Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue}
