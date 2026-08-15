param(
    [Parameter(Mandatory=$true)][string]$CoreBuilderPath
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
if(-not(Test-Path -LiteralPath $CoreBuilderPath -PathType Leaf)){throw "Retired-3D prune transform input missing: $CoreBuilderPath"}
$builder=Get-Content -Raw -LiteralPath $CoreBuilderPath -Encoding UTF8
if($builder -notmatch 'HUYMAIER_RETIRED_3D_PAYLOAD_PRUNE_V1'){
    $anchor=@'
    'Native\GuideBridge'
)){Remove-Item -LiteralPath (Join-Path $stage $dead) -Recurse -Force -ErrorAction SilentlyContinue}
'@
    if(-not$builder.Contains($anchor)){throw 'Retired-3D prune could not find inherited payload cleanup list.'}
    $replacement=@'
    'Native\GuideBridge',
    # HUYMAIER_RETIRED_3D_PAYLOAD_PRUNE_V1
    'HuymaierPlatformAtlas.ps1',
    'HuymaierModelPreviewWorker.exe',
    'Native\HuymaierBuiltInModelGenerator.cs',
    'Assets\Models\platform-models.png',
    'Assets\Models\Live'
)){Remove-Item -LiteralPath (Join-Path $stage $dead) -Recurse -Force -ErrorAction SilentlyContinue}
'@
    $builder=$builder.Replace($anchor,$replacement)

    $verifyAnchor=@'
foreach($dead in @('HuymaierGuideInput.cs','HuymaierGuideBridge.dll','HuymaierConsoleUpdate.ps1','HuymaierConsoleApplyUpdate.ps1')){if(Test-Path (Join-Path $stage $dead)){throw "Retired payload survived packaging: $dead"}}
'@
    if(-not$builder.Contains($verifyAnchor)){throw 'Retired-3D prune could not find final retired-payload verification gate.'}
    $verifyReplacement=@'
foreach($dead in @(
    'HuymaierGuideInput.cs','HuymaierGuideBridge.dll','HuymaierConsoleUpdate.ps1','HuymaierConsoleApplyUpdate.ps1',
    'HuymaierPlatformAtlas.ps1','HuymaierModelPreviewWorker.exe','Native\HuymaierBuiltInModelGenerator.cs','Assets\Models\platform-models.png','Assets\Models\Live'
)){if(Test-Path (Join-Path $stage $dead)){throw "Retired payload survived packaging: $dead"}}
'@
    $builder=$builder.Replace($verifyAnchor,$verifyReplacement)
}
Set-Content -LiteralPath $CoreBuilderPath -Value $builder -Encoding UTF8
