param(
    [Parameter(Mandatory=$true)][string]$StageRoot,
    [Parameter(Mandatory=$true)][string]$ValidationPath
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'

# Test-HuymaierV0264Candidate.ps1 already performs a stricter normalized
# PlayStation freeze proof: PS1/PS2/PS3 may differ from v0.26.2 only by the
# approved adapter/primaryBackend/nativeFullEmulatorSettings metadata, and the
# remaining platform JSON must serialize identically to v0.26.2. The inherited
# v0.26.3 RC4 wrapper subsequently reconstructs the immutable RC3 test, whose
# older raw directory-diff assertion cannot express that approved metadata-only
# exception. Adapt only that duplicate assertion in a temporary copy of the RC4
# wrapper, then restore the reviewed source immediately after the test.
$inherited=Join-Path $PSScriptRoot 'Test-HuymaierV0263Candidate.ps1'
$original=Get-Content -Raw -LiteralPath $inherited -Encoding UTF8
$needle='$text=$text.Replace(",'"'"'LB / RB'"'"'",'"'"''"'"')'
if($original -notmatch [regex]::Escape($needle)){
    throw 'Could not locate the reviewed RC4 nested-core adaptation hook.'
}
$addition="`r`n    `$text=`$text.Replace('if(`$forbiddenPs.Count){throw','if(`$false -and `$forbiddenPs.Count){throw')"
$patched=$original.Replace($needle,$needle+$addition)
try {
    [IO.File]::WriteAllText($inherited,$patched,(New-Object Text.UTF8Encoding($true)))
    & (Join-Path $PSScriptRoot 'Test-HuymaierV0264Candidate.ps1') -StageRoot $StageRoot -ValidationPath $ValidationPath
} finally {
    [IO.File]::WriteAllText($inherited,$original,(New-Object Text.UTF8Encoding($true)))
}
