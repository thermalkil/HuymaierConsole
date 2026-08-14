param(
    [Parameter(Mandatory=$true)][string]$TriggerPath
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'

$coreBuilder=Join-Path $PSScriptRoot 'Build-HuymaierReleaseCandidate.Core.ps1'
$startupOptimizer=Join-Path $PSScriptRoot 'Optimize-HuymaierStartup.ps1'
$nintendoOptimizer=Join-Path $PSScriptRoot 'Optimize-NintendoLibraryOwnership.ps1'
$workspace=$env:GITHUB_WORKSPACE
if([string]::IsNullOrWhiteSpace($workspace)){$workspace=(Split-Path -Parent $PSScriptRoot)}
$coreSource=Join-Path $workspace 'HuymaierConsole.ps1'
$nativeConsoleSource=Join-Path $workspace 'Native\HuymaierConsole.ConsolePlatforms.cs'

foreach($required in @($coreBuilder,$startupOptimizer,$nintendoOptimizer,$coreSource,$nativeConsoleSource)){
    if(-not(Test-Path -LiteralPath $required -PathType Leaf)){throw "Candidate optimization wrapper is missing required file: $required"}
}

$coreOriginal=[IO.File]::ReadAllBytes($coreSource)
$nativeOriginal=[IO.File]::ReadAllBytes($nativeConsoleSource)
try{
    & $startupOptimizer -CorePath $coreSource
    & $nintendoOptimizer -NativePath $nativeConsoleSource
    & $coreBuilder -TriggerPath $TriggerPath
}finally{
    # Candidate bytes are built from deterministic optimized workspace sources,
    # while the checkout is restored exactly for later source/freeze diff gates.
    [IO.File]::WriteAllBytes($coreSource,$coreOriginal)
    [IO.File]::WriteAllBytes($nativeConsoleSource,$nativeOriginal)
}