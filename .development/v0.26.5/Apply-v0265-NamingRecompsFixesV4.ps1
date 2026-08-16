Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
& (Join-Path $PSScriptRoot 'Apply-v0265-NamingRecompsFixesV3.ps1')
$path=Join-Path $root 'HuymaierGameProviders.ps1'
$text=([IO.File]::ReadAllText($path)).Replace("`r`n","`n")
$marker='# HUYMAIER_RECOMPS_CONTROL_RAIL_END_V1'
if(-not$text.Contains($marker)){
    $anchor="    `$choices+=,[pscustomobject]@{Id='provider-back';Glyph='BACK';Title='Platform Menu';Subtitle='Return to Home and Library choices.'}`n"
    if(-not$text.Contains($anchor)){throw 'Recomps control-rail closing anchor missing.'}
    $replacement="    $marker`n    }`n"+$anchor
    $text=$text.Replace($anchor,$replacement)
    [IO.File]::WriteAllText($path,$text,(New-Object Text.UTF8Encoding($false)))
}
Write-Host 'recompsControlRailBraceGate: success'
