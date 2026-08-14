param(
    [Parameter(Mandatory=$true)][string]$TriggerPath,
    [Parameter(Mandatory=$true)][string]$CorePath,
    [Parameter(Mandatory=$true)][string]$ManifestPath,
    [Parameter(Mandatory=$true)][string]$AppxManifestPath
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'

$trigger=Get-Content -Raw -LiteralPath $TriggerPath -Encoding UTF8|ConvertFrom-Json
$version=[string]$trigger.version
if([string]::IsNullOrWhiteSpace($version)){throw 'Candidate version stamping requires trigger.version.'}
if($version -ne '0.26.5'){throw "This v0.26.5 stamping transform refuses unexpected version '$version'."}

$core=[IO.File]::ReadAllText($CorePath,[Text.Encoding]::UTF8)
$oldCore="$script:AppVersion = '0.26.4'"
$newCore="$script:AppVersion = '$version'"
if(([regex]::Matches($core,[regex]::Escape($oldCore))).Count -ne 1){throw 'Expected exactly one v0.26.4 AppVersion marker before candidate stamping.'}
$core=$core.Replace($oldCore,$newCore)
[IO.File]::WriteAllText($CorePath,$core,(New-Object Text.UTF8Encoding($false)))

$manifest=Get-Content -Raw -LiteralPath $ManifestPath -Encoding UTF8|ConvertFrom-Json
if([string]$manifest.version -ne '0.26.4'){throw "Expected source manifest version 0.26.4 before candidate stamping, found $($manifest.version)."}
$manifest.version=$version
$manifest.baseVersion='0.26.4'
$manifest.build='performance-downloads-rc1'
$manifest.description='v0.26.5 RC1 focuses on Xbox-home startup latency, responsive native-console return, provider-neutral Downloading/Installing progress with truthful ETA fallback, and deterministic Wii/GameCube library ownership while preserving the validated v0.26.4 platform expansion and frozen PS1/PS2/PS3 presentation.'
$features=New-Object System.Collections.ArrayList
foreach($feature in @($manifest.features)){[void]$features.Add([string]$feature)}
foreach($feature in @(
    'reduces Xbox-home startup latency with cached unchanged-script preflight, lazy WebView2 construction, embedded native-helper reuse, and first-frame deferral of nonessential animation/FPS/audio services',
    'restores controller responsiveness before background polling, animation and FPS work when returning from native console interfaces',
    'normalizes Epic, GOG and Amazon transfer presentation into explicit Downloading and Installing phases with speed and ETA when known and Calculating ETA when no truthful denominator exists',
    'uses event-driven low-priority provider fallback telemetry with incremental filesystem change accounting instead of repeated large install-folder rescans',
    'separates Wii and GameCube library ownership through scoped roots, sibling-console rejection and raw disc-header classification in both background and visible native scans',
    'adds startup timing markers for ShowDialog entry, first rendered frame and deferred-service readiness so Xbox-home boot regressions can be measured directly'
)){
    if($features -notcontains $feature){[void]$features.Add($feature)}
}
$manifest.features=[object[]]$features.ToArray()
$manifest|ConvertTo-Json -Depth 20|Set-Content -LiteralPath $ManifestPath -Encoding UTF8

$appx=[IO.File]::ReadAllText($AppxManifestPath,[Text.Encoding]::UTF8)
$oldAppx='Version="0.26.4.0"'
$newAppx='Version="0.26.5.0"'
if(([regex]::Matches($appx,[regex]::Escape($oldAppx))).Count -ne 1){throw 'Expected exactly one v0.26.4.0 AppX identity before candidate stamping.'}
$appx=$appx.Replace($oldAppx,$newAppx)
[IO.File]::WriteAllText($AppxManifestPath,$appx,(New-Object Text.UTF8Encoding($false)))

Write-Host "Stamped release workspace as Huymaier Console v$version / performance-downloads-rc1."
