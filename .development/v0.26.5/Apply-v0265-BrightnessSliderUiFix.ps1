Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$path=Join-Path $root 'HuymaierUser3DModels.ps1'
$text=[IO.File]::ReadAllText($path).Replace("`r`n","`n")
$utf8=New-Object Text.UTF8Encoding($false)

$scaleAction="[void]`$result.Add((New-SliderAction 'platform-model-scale-slider' '3D shelf model size' ([int]`$script:Config.PlatformModelScale) 'Adjust rotation-safe camera framing for the compact 3D shelf models. Models remain inside their viewports while rotating.' 50 200));"
$brightnessAction="[void]`$result.Add((New-SliderAction 'platform-model-brightness-slider' '3D model brightness' ([int]`$script:Config.PlatformModelBrightness) 'Adjust lighting for both the Games 3D shelves and the full-screen model viewer.' 50 250));"
if(-not$text.Contains($brightnessAction)){
    if(-not$text.Contains($scaleAction)){throw 'Brightness slider insertion anchor missing.'}
    $text=$text.Replace($scaleAction,$scaleAction+$brightnessAction)
}

$invokeAnchor="'platform-model-scale-slider'{[void](Adjust-SelectedSlider 5);return}"
$invokeBrightness="'platform-model-brightness-slider'{[void](Adjust-SelectedSlider 5);return}"
if(-not$text.Contains($invokeBrightness)){
    if(-not$text.Contains($invokeAnchor)){throw 'Brightness slider Invoke-Action anchor missing.'}
    $text=$text.Replace($invokeAnchor,$invokeAnchor+$invokeBrightness)
}

if($text.IndexOf("'3D model brightness'",[StringComparison]::Ordinal)-lt0){throw 'Brightness slider label was not materialized.'}
if($text.IndexOf("'platform-model-brightness-slider'{[void](Adjust-SelectedSlider 5);return}",[StringComparison]::Ordinal)-lt0){throw 'Brightness slider action routing was not materialized.'}
[IO.File]::WriteAllText($path,$text,$utf8)
Write-Host 'platformModelBrightnessSliderUiGate: success'
