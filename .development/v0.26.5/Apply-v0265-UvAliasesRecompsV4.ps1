Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
& (Join-Path $PSScriptRoot 'Apply-v0265-UvAliasesRecompsV3.ps1')

$testPath=Join-Path $PSScriptRoot 'Test-v0265-CanonicalRecomps.ps1'
$test=[IO.File]::ReadAllText($testPath).Replace("`r`n","`n")
if(-not $test.Contains('$xboxProviderNeedle=')){
    $pattern='(?m)^\s*if\(\$userModelText -notmatch .+Xbox App.+$'
    $regex=New-Object Text.RegularExpressions.Regex($pattern)
    if(-not $regex.IsMatch($test)){throw 'Canonical/Recomps Xbox provider test anchor missing.'}
    $replacement=@'
$xboxProviderNeedle='''xbox'' {[void]$names.Add(''Xbox App.glb'')'
if($userModelText.IndexOf($xboxProviderNeedle,[StringComparison]::Ordinal)-lt0){throw 'Xbox PC provider no longer prefers Xbox App.glb.'}
'@
    $replacement=$replacement.Replace("`r`n","`n")
    $test=$regex.Replace($test,[Text.RegularExpressions.MatchEvaluator]{param($m) $replacement},1)
    [IO.File]::WriteAllText($testPath,$test,(New-Object Text.UTF8Encoding($false)))
}
Write-Host 'canonicalRecompsTestLiteralSafetyGate: success'
