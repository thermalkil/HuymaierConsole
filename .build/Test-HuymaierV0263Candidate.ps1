param(
    [Parameter(Mandatory=$true)][string]$StageRoot,
    [Parameter(Mandatory=$true)][string]$ValidationPath
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'

# v0.26.3 is staged from the published v0.26.2 runtime/media package. Remove
# package-only historical text that was deliberately deleted from source, then
# reseal and verify the exact ZIP before running the release regression gates.
& (Join-Path $PSScriptRoot 'Clean-HuymaierV0263CandidateText.ps1') -StageRoot $StageRoot -ValidationPath $ValidationPath

# Run the installer/integrity failure-injection suite again after cleanup so the
# package that reaches the user, not merely the pre-clean staging tree, is gated.
& (Join-Path $PSScriptRoot 'Test-HuymaierCandidate.ps1') -StageRoot $StageRoot -ValidationPath $ValidationPath

# Preserve the already-reviewed RC3 fidelity/artwork/emulator regression suite
# exactly as it existed at the immutable RC3 source commit. Materialize that
# historical script beside this wrapper so its $PSScriptRoot dependencies remain
# .build and it can continue to call the inherited v0.26.2 gates unchanged.
$core=Join-Path $PSScriptRoot 'Test-HuymaierV0263CandidateCore.runtime.ps1'
try {
    $text=(& git show '0da9bcdfb34dbc4c59f4a9514bf57e0c595dbf87:.build/Test-HuymaierV0263Candidate.ps1') -join "`n"
    if([string]::IsNullOrWhiteSpace($text) -or $text -notmatch 'nativeConsoleFidelityGate'){
        throw 'Could not materialize the reviewed immutable RC3 regression gate.'
    }
    [IO.File]::WriteAllText($core,$text+"`n",(New-Object Text.UTF8Encoding($true)))
    & $core -StageRoot $StageRoot -ValidationPath $ValidationPath
} finally {
    Remove-Item -LiteralPath $core -Force -ErrorAction SilentlyContinue
}

$validation=Get-Content -Raw -LiteralPath $ValidationPath -Encoding UTF8|ConvertFrom-Json
if([string]$validation.obsoleteTextCleanupGate -ne 'success'){
    throw 'Final v0.26.3 validation record lost the obsolete-text cleanup gate.'
}
Write-Host 'v0.26.3 final cleaned candidate and all inherited regression gates passed.'
