Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$defaults=Join-Path $root 'HuymaierModelDefaults.ps1'
$hostPath=Join-Path $root 'Native\HuymaierD3D11ShelfHost.cs'
$nativePath=Join-Path $root 'Native\HuymaierD3D11ShelfRuntime.cpp'
foreach($p in @($defaults,$hostPath,$nativePath)){if(-not(Test-Path -LiteralPath $p -PathType Leaf)){throw "v0.30.6 scale test source missing: $p"}}

$text=Get-Content -Raw -LiteralPath $defaults -Encoding UTF8
foreach($needle in @(
    'HUYMAIER_V0306_CONSOLE_MODEL_SCALE_EDITOR_V1',
    'Normalize-HcModelScalePercent',
    'Max(30.0,[math]::Min(300.0',
    "Get-EntryProperty `$entry 'ScalePercent' 100",
    'LB / RB Scale ',
    'Is-NewButtonPress $Mask 1024',
    'Is-NewButtonPress $Mask 2048',
    "[string]::Equals([string]`$Group.Key,'Consoles'",
    '$itemScale=$baseScale*([double]$view.ScalePercent/100.0)'
)){
    if($text.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "v0.30.6 console-model scale contract missing: $needle"}
}
if($text.IndexOf("if(`$isConsoleGroup -and `$Group.Surface.PSObject.Methods['SetItem'])",[StringComparison]::Ordinal)-lt0){throw 'Console-only shelf scaling guard is missing.'}
Write-Host 'consoleModelScalePersistenceGate: success'
Write-Host 'consoleModelScale30To300Gate: success'
Write-Host 'consoleModelScaleTenPercentStepGate: success'
Write-Host 'consoleModelScaleControllerGate: success'
Write-Host 'consoleModelScaleProviderIsolationGate: success'

& (Join-Path $root '.build\Optimize-ConsoleModelScale.ps1')
$hostText=Get-Content -Raw -LiteralPath $hostPath -Encoding UTF8
$nativeText=Get-Content -Raw -LiteralPath $nativePath -Encoding UTF8
foreach($needle in @('HUYMAIER_V0306_CONSOLE_MODEL_SCALE_CAPACITY_V1','Math.Max(.12f, Math.Min(2.50f, (float)scale))')){if($hostText.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "Managed scale capacity missing: $needle"}}
foreach($needle in @('HUYMAIER_V0306_CONSOLE_MODEL_SCALE_CAPACITY_V1','std::max(.12f,std::min(2.50f,item.modelScale))')){if($nativeText.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "Native scale capacity missing: $needle"}}
Write-Host 'consoleModelScaleManagedCapacityGate: success'
Write-Host 'consoleModelScaleNativeCapacityGate: success'

$tokens=$null;$errors=$null
[void][Management.Automation.Language.Parser]::ParseFile($defaults,[ref]$tokens,[ref]$errors)
if($errors.Count){$errors|ForEach-Object{Write-Host $_.Message};throw 'HuymaierModelDefaults.ps1 failed Windows PowerShell 5.1 parse after v0.30.6 scale edit.'}
Write-Host 'consoleModelScalePs51ParseGate: success'
