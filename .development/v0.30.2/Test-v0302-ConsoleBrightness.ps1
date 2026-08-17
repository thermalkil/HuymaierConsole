Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$customization=Join-Path $root 'HuymaierCustomization.ps1'
if(-not(Test-Path -LiteralPath $customization -PathType Leaf)){throw 'HuymaierCustomization.ps1 is missing.'}
$text=Get-Content -Raw -LiteralPath $customization -Encoding UTF8

# Keep this source gate intentionally small and parser-focused. The staged
# release gate performs the exhaustive package assertions after all transforms.
foreach($needle in @(
    'HUYMAIER_V0302_CONSOLE_BRIGHTNESS_V1',
    "Add-HcCustomizationConfigProperty 'ConsoleBrightness'",
    "New-SliderAction 'console-brightness-slider' 'Huymaier Console brightness'",
    "'Adjust the entire Huymaier Console interface from 0% to 200% in 10% steps.' 0 200",
    "`$direction=`$(if(`$Delta -lt 0){-10}elseif(`$Delta -gt 0){10}else{0})",
    'function Apply-HcConsoleBrightness',
    "`$persistedConfig.PSObject.Properties['ConsoleBrightness']"
)){
    if($text.IndexOf($needle,[StringComparison]::Ordinal) -lt 0){throw "v0.30.2 brightness source contract missing: $needle"}
}

$tokens=$null;$errors=$null
[void][Management.Automation.Language.Parser]::ParseFile($customization,[ref]$tokens,[ref]$errors)
if(@($errors).Count){throw 'v0.30.2 transformed customization source failed Windows PowerShell parsing: '+(($errors|ForEach-Object{"line $($_.Extent.StartLineNumber): $($_.Message)"}) -join '; ')}

Write-Host 'consoleBrightness0To200Gate: success'
Write-Host 'consoleBrightnessTenPercentStepGate: success'
Write-Host 'consoleBrightnessPersistenceGate: success'
Write-Host 'consoleBrightnessPs51ParseGate: success'