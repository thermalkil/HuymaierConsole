param(
    [Parameter(Mandatory=$true)][string]$TriggerPath
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'

$coreBuilder=Join-Path $PSScriptRoot 'Build-HuymaierReleaseCandidate.Core.ps1'
$optimizer=Join-Path $PSScriptRoot 'Optimize-HuymaierStartup.ps1'
$workspace=$env:GITHUB_WORKSPACE
if([string]::IsNullOrWhiteSpace($workspace)){$workspace=(Split-Path -Parent $PSScriptRoot)}
$coreSource=Join-Path $workspace 'HuymaierConsole.ps1'

foreach($required in @($coreBuilder,$optimizer,$coreSource)){
    if(-not(Test-Path -LiteralPath $required -PathType Leaf)){throw "Candidate startup wrapper is missing required file: $required"}
}

$original=[IO.File]::ReadAllBytes($coreSource)
try{
    & $optimizer -CorePath $coreSource
    & $coreBuilder -TriggerPath $TriggerPath
}finally{
    # The candidate contains the deterministic optimized runtime, while the
    # checked-out source tree is restored byte-for-byte for later workflow
    # validation/diff gates and for reproducible developer source state.
    [IO.File]::WriteAllBytes($coreSource,$original)
}
