param(
    [Parameter(Mandatory=$true)][string]$TriggerPath,
    [Parameter(Mandatory=$true)][string]$CorePath,
    [Parameter(Mandatory=$true)][string]$BootstrapPath,
    [Parameter(Mandatory=$true)][string]$InstallerCorePath,
    [Parameter(Mandatory=$true)][string]$InstallerScriptPath,
    [Parameter(Mandatory=$true)][string]$ManifestPath,
    [Parameter(Mandatory=$true)][string]$AppxManifestPath,
    [Parameter(Mandatory=$true)][string]$NativeGameInputPath
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'

$trigger=Get-Content -Raw -LiteralPath $TriggerPath -Encoding UTF8|ConvertFrom-Json
$version=[string]$trigger.version
if([string]::IsNullOrWhiteSpace($version)){throw 'Candidate version stamping requires trigger.version.'}
if($version -ne '0.26.5'){throw "This v0.26.5 stamping transform refuses unexpected version '$version'."}

function Replace-ExactlyOnce([string]$Path,[string]$Old,[string]$New,[string]$Label){
    $text=[IO.File]::ReadAllText($Path,[Text.Encoding]::UTF8)
    if(([regex]::Matches($text,[regex]::Escape($Old))).Count -ne 1){throw "Expected exactly one $Label marker before candidate stamping."}
    $text=$text.Replace($Old,$New)
    [IO.File]::WriteAllText($Path,$text,(New-Object Text.UTF8Encoding($false)))
}

Replace-ExactlyOnce $CorePath "`$script:AppVersion = '0.26.4'" "`$script:AppVersion = '$version'" 'v0.26.4 AppVersion'
Replace-ExactlyOnce $BootstrapPath "`$script:ExpectedConsoleVersion='0.26.4'" "`$script:ExpectedConsoleVersion='$version'" 'v0.26.4 bootstrap expected-version'
Replace-ExactlyOnce $InstallerCorePath "`$script:InstallVersion='0.26.4'" "`$script:InstallVersion='$version'" 'v0.26.4 installer version'
Replace-ExactlyOnce $NativeGameInputPath 'public const string Version = "0.26.4";' ('public const string Version = "'+$version+'";') 'v0.26.4 native build stamp'
Replace-ExactlyOnce $InstallerScriptPath "param([string]`$InstallRoot,[string]`$Version='0.26.4')" "param([string]`$InstallRoot,[string]`$Version='$version')" 'v0.26.4 startup-cache default version'
Replace-ExactlyOnce $InstallerScriptPath "-Version '0.26.4'" "-Version '$version'" 'v0.26.4 startup-cache seed version'

$manifest=Get-Content -Raw -LiteralPath $ManifestPath -Encoding UTF8|ConvertFrom-Json
if([string]$manifest.version -ne '0.26.4'){throw "Expected source manifest version 0.26.4 before candidate stamping, found $($manifest.version)."}
$manifest.version=$version
$manifest.baseVersion='0.26.4'
$manifest.build='performance-downloads-stabilization-rc1'
$manifest.description='v0.26.5 RC1 improves Xbox-home startup and native-console return responsiveness, fixes Wii/GameCube ownership and Wii title resolution, adds a controller-first virtual browser cursor with reliable text entry, and supports concurrent provider downloads with per-transfer speed and derived ETA while preserving the validated v0.26.4 platform expansion and frozen PS1/PS2/PS3 presentation.'
$features=New-Object System.Collections.ArrayList
foreach($feature in @($manifest.features)){[void]$features.Add([string]$feature)}
foreach($feature in @(
    'reduces Xbox-home startup latency with cached unchanged-script preflight, lazy WebView2 construction, embedded native-helper reuse, and first-frame deferral of nonessential animation/FPS/audio services',
    'restores controller responsiveness before background polling, animation and FPS work when returning from native console interfaces',
    'removes platform-card process-launch bursts and replaces repeated one-second state-file polling with event-driven dirty-state observation plus staggered console-count refreshes',
    'normalizes Epic, GOG and Amazon transfer presentation into explicit Downloading and Installing phases with speed and native-or-derived ETA',
    'supports multiple simultaneous direct-provider Install/Update transfers with isolated state, output telemetry, per-transfer cards, and locked shared catalog/install metadata updates',
    'derives fallback ETA from known or estimated total size and smoothed observed throughput when a provider does not expose ETA, using Calculating ETA only while insufficient data exists',
    'adds a visible console-style browser cursor with controller pointer movement, direct A/Cross clicking, and X/Square native-keyboard text entry including Google search fields',
    'separates Wii and GameCube library ownership through scoped roots, sibling-console rejection and raw disc-header classification in both background and visible native scans',
    'resolves bare Wii/GameCube disc IDs into descriptive folder or embedded ISO/WBFS titles and never presents a six-character disc ID as the final friendly title',
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

Write-Host "Stamped shell, bootstrap, installer core/cache, native build stamp, manifest and AppX as Huymaier Console v$version / performance-downloads-stabilization-rc1."