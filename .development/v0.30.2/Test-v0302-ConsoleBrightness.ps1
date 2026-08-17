Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$customization=Join-Path $root 'HuymaierCustomization.ps1'
if(-not(Test-Path -LiteralPath $customization -PathType Leaf)){throw 'HuymaierCustomization.ps1 is missing.'}
$text=Get-Content -Raw -LiteralPath $customization -Encoding UTF8

foreach($needle in @(
    'HUYMAIER_V0302_CONSOLE_BRIGHTNESS_V1',
    "Add-HcCustomizationConfigProperty 'ConsoleBrightness'",
    "Get-EntryProperty `$script:Config 'ConsoleBrightness' 100",
    "[math]::Max(0,[math]::Min(200",
    "[math]::Round(([int]`$script:Config.ConsoleBrightness)/10.0)*10",
    "New-SliderAction 'console-brightness-slider' 'Huymaier Console brightness'",
    "'Adjust the entire Huymaier Console interface from 0% to 200% in 10% steps.' 0 200",
    "`$direction=`$(if(`$Delta -lt 0){-10}elseif(`$Delta -gt 0){10}else{0})",
    "`$value=[math]::Max(0,[math]::Min(200,`$current+`$direction))",
    'function Apply-HcConsoleBrightness',
    "`$overlay.IsHitTestVisible=`$false",
    '[System.Windows.Controls.Panel]::SetZIndex($overlay,2147483647)',
    "`$script:HcBrightnessOverlay.Background=New-HcSolidBrush '#000000'",
    "`$script:HcBrightnessOverlay.Background=New-HcSolidBrush '#FFFFFF'",
    "`$script:HcBrightnessOverlay.Opacity=[math]::Max(0.0,[math]::Min(0.50,`$alpha))",
    'Apply-HcConsoleBrightness'
)){
    if($text.IndexOf($needle,[StringComparison]::Ordinal) -lt 0){throw "v0.30.2 brightness contract missing: $needle"}
}

# Persistence is intentionally recovered in the customization layer because the
# legacy core config loader only whitelists its older fixed property set.
foreach($needle in @(
    "Test-Path -LiteralPath `$script:ConfigPath -PathType Leaf",
    "Get-Content -Raw -LiteralPath `$script:ConfigPath -Encoding UTF8|ConvertFrom-Json",
    "`$persistedConfig.PSObject.Properties['ConsoleBrightness']",
    "`$persistedBrightness=[int]`$persistedConfig.ConsoleBrightness",
    'Save-Config'
)){
    if($text.IndexOf($needle,[StringComparison]::Ordinal) -lt 0){throw "v0.30.2 brightness persistence contract missing: $needle"}
}

# Guard the requested exact controller interval. The exact direction line above
# proves both -10 and +10 behavior; this guard ensures the generic +/-5 delta is
# never applied directly to this slider.
if($text -match 'console-brightness-slider''[\s\S]{0,900}\$current\+\$Delta'){throw 'Console brightness still applies the generic +/-5 delta directly.'}

$tokens=$null;$errors=$null
[void][Management.Automation.Language.Parser]::ParseFile($customization,[ref]$tokens,[ref]$errors)
if(@($errors).Count){throw 'v0.30.2 transformed customization source failed Windows PowerShell parsing: '+(($errors|ForEach-Object{"line $($_.Extent.StartLineNumber): $($_.Message)"}) -join '; ')}

Write-Host 'consoleBrightness0To200Gate: success'
Write-Host 'consoleBrightnessTenPercentStepGate: success'
Write-Host 'consoleBrightnessPersistenceGate: success'
Write-Host 'consoleBrightnessNonInteractiveOverlayGate: success'