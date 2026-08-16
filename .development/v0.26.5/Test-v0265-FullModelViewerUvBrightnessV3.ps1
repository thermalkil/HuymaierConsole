Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$repoRoot=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$source=Join-Path $PSScriptRoot 'Test-v0265-FullModelViewerUvBrightness.ps1'
$raw=([IO.File]::ReadAllText($source)).Replace("`r`n","`n")
$rootLine='$root=(Resolve-Path (Join-Path $PSScriptRoot ''..\..'')).Path'
$escapedRoot=$repoRoot.Replace("'","''")
if(-not$raw.Contains($rootLine)){throw 'Viewer V3 repository-root anchor missing.'}
$raw=$raw.Replace($rootLine,("`$root='"+$escapedRoot+"'"))
$newFunction=@'
function New-QuadPng {
    $w=8;$h=8;$stride=$w*4;$pixels=New-Object byte[] ($stride*$h)
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
$newAssert=@'
function Assert-Color($c,[string]$kind){
    $margin=35.0
    switch($kind){
        'R'{if(-not($c.R-gt$c.G+$margin-and$c.R-gt$c.B+$margin)){throw "Expected red dominance, got R=$($c.R) G=$($c.G) B=$($c.B)"}}
        'G'{if(-not($c.G-gt$c.R+$margin-and$c.G-gt$c.B+$margin)){throw "Expected green dominance, got R=$($c.R) G=$($c.G) B=$($c.B)"}}
        'B'{if(-not($c.B-gt$c.R+$margin-and$c.B-gt$c.G+$margin)){throw "Expected blue dominance, got R=$($c.R) G=$($c.G) B=$($c.B)"}}
        'Y'{if(-not($c.R-gt$c.B+$margin-and$c.G-gt$c.B+$margin)){throw "Expected yellow dominance, got R=$($c.R) G=$($c.G) B=$($c.B)"}}
    }
}
'@
$newAssert=$newAssert.Replace("`r`n","`n")
$assertRx=New-Object Text.RegularExpressions.Regex('(?m)^function Assert-Color\(\$c,\[string\]\$kind\)\{.*\}$')
if(-not$assertRx.IsMatch($raw)){throw 'Viewer V3 color-assertion regex did not match.'}
$raw=$assertRx.Replace($raw,[Text.RegularExpressions.MatchEvaluator]{param($m)$newAssert},1)
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
# The bright UV probe intentionally reaches WPF's output clamp, so raw luma is
# not a meaningful brightness assertion. Inspect the live light objects instead:
# below 100% the key light must dim; above 100% the neutral ambient boost must rise.
$brightnessReplacement=@'
    $flags=[Reflection.BindingFlags]'Instance,NonPublic'
    $brightnessField=$view.GetType().GetField('brightnessLight',$flags)
    $keyField=$view.GetType().GetField('keyLight',$flags)
    if($null-eq$brightnessField-or$null-eq$keyField){throw 'Viewer brightness light fields are unavailable.'}
    $view.SetBrightnessPercent(100);$key100=[int]$keyField.GetValue($view).Color.R;$boost100=[int]$brightnessField.GetValue($view).Color.R
    $view.SetBrightnessPercent(50);$key50=[int]$keyField.GetValue($view).Color.R
    $view.SetBrightnessPercent(200);$boost200=[int]$brightnessField.GetValue($view).Color.R
    if([math]::Abs([double]$view.BrightnessPercent-200.0)-gt0.001){throw 'Viewer brightness property did not retain 200%.'}
    if($key50-ge$key100){throw "Viewer key light did not dim below 100%: 50%=$key50 100%=$key100"}
    if($boost200-le$boost100+40){throw "Viewer neutral brightness boost did not increase above 100%: 100%=$boost100 200%=$boost200"}
    Write-Host ("platformModelFullViewerBrightnessState: key50={0} key100={1} boost100={2} boost200={3}" -f $key50,$key100,$boost100,$boost200)
'@
$brightnessReplacement=$brightnessReplacement.Replace("`r`n","`n")
$brightnessRx=New-Object Text.RegularExpressions.Regex('(?m)^    if\(\$l200-le\$l100\*1\.08\)\{throw .*\}$')
if(-not$brightnessRx.IsMatch($raw)){throw 'Viewer V3 brightness assertion regex did not match.'}
$raw=$brightnessRx.Replace($raw,[Text.RegularExpressions.MatchEvaluator]{param($m)$brightnessReplacement},1)
$temp=Join-Path $env:TEMP ('hc-full-viewer-v3-'+[guid]::NewGuid().ToString('N')+'.ps1')
try{[IO.File]::WriteAllText($temp,$raw,(New-Object Text.UTF8Encoding($false)));& $temp}finally{Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue}
