param()
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$hostPath=Join-Path $root 'Native\HuymaierD3D11ShelfHost.cs'
$nativePath=Join-Path $root 'Native\HuymaierD3D11ShelfRuntime.cpp'
foreach($p in @($hostPath,$nativePath)){if(-not(Test-Path -LiteralPath $p -PathType Leaf)){throw "v0.30.6 console-scale source missing: $p"}}

# HUYMAIER_V0306_CONSOLE_MODEL_SCALE_CAPACITY_TRANSFORM_V1
# The UI only supplies >legacy scale values for console cards. Provider cards
# continue to send their existing 0.55-0.70 values, so this expands renderer
# capacity without changing provider/storefront presentation.
$hostText=Get-Content -Raw -LiteralPath $hostPath -Encoding UTF8
if($hostText -notmatch 'HUYMAIER_V0306_CONSOLE_MODEL_SCALE_CAPACITY_V1'){
    $marker='    // HUYMAIER_D3D11_DPI_AWARE_SHELF_V1'
    if(-not$hostText.Contains($marker)){throw 'v0.30.6 host scale marker anchor missing.'}
    $hostText=$hostText.Replace($marker,$marker+"`r`n    // HUYMAIER_V0306_CONSOLE_MODEL_SCALE_CAPACITY_V1")
    $old='            state.Scale = Math.Max(.40f, Math.Min(.90f, (float)scale));'
    $new='            state.Scale = Math.Max(.12f, Math.Min(2.50f, (float)scale));'
    if(-not$hostText.Contains($old)){throw 'v0.30.6 managed scale clamp anchor missing.'}
    $hostText=$hostText.Replace($old,$new)
    Set-Content -LiteralPath $hostPath -Value $hostText -Encoding UTF8
}

$nativeText=Get-Content -Raw -LiteralPath $nativePath -Encoding UTF8
if($nativeText -notmatch 'HUYMAIER_V0306_CONSOLE_MODEL_SCALE_CAPACITY_V1'){
    $old='        const float scale=(2.60f/diameter)*std::max(.45f,std::min(.90f,item.modelScale))*(item.selected?1.04f:1.0f);'
    $new="        // HUYMAIER_V0306_CONSOLE_MODEL_SCALE_CAPACITY_V1`r`n        // Console per-model scale may intentionally exceed the legacy shelf range.`r`n        // Providers never request these extended values and retain their exact path.`r`n        const float scale=(2.60f/diameter)*std::max(.12f,std::min(2.50f,item.modelScale))*(item.selected?1.04f:1.0f);"
    if(-not$nativeText.Contains($old)){throw 'v0.30.6 native scale clamp anchor missing.'}
    $nativeText=$nativeText.Replace($old,$new)
    Set-Content -LiteralPath $nativePath -Value $nativeText -Encoding UTF8
}

# HUYMAIER_V0306_RESERVED_HOST_TOOLING_REPAIR_V1
# Windows PowerShell exposes $Host as a read-only automatic variable. The full
# console-presentation editor tooling was authored with a local $host path name;
# normalize that standalone variable before the later transform/test executes.
# This touches developer tooling only, never the installed runtime payload.
foreach($toolPath in @(
    (Join-Path $root '.build\Optimize-ConsoleModelPresentation.ps1'),
    (Join-Path $root '.development\v0.30.6\Test-v0306-ConsoleModelPresentation.ps1')
)){
    if(-not(Test-Path -LiteralPath $toolPath -PathType Leaf)){continue}
    $toolText=Get-Content -Raw -LiteralPath $toolPath -Encoding UTF8
    $repaired=[regex]::Replace($toolText,'(?i)(?<![A-Za-z0-9_])\$host(?![A-Za-z0-9_])','$hostPath')
    if($repaired-ne$toolText){Set-Content -LiteralPath $toolPath -Value $repaired -Encoding UTF8}
}

Write-Host 'Applied v0.30.6 console-only per-model scale renderer capacity (providers unchanged).'
