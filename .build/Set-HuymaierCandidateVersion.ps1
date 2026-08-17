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
if($version -ne '0.30.2'){throw "This v0.30.2 stamping transform refuses unexpected version '$version'."}

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
$manifest.baseVersion='0.30.1'
$manifest.build='console-brightness-rc1'
$manifest.description='v0.30.2 is a deliberately narrow follow-up to v0.30.1. It adds one controller-friendly overall Huymaier Console brightness control from 0 to 200 percent in exact 10 percent steps while preserving the v0.30.1 updater repair, 3D-model brightness range, bounded fan motion, and all validated platform/controller/download behavior.'
$features=New-Object System.Collections.ArrayList
foreach($feature in @($manifest.features)){[void]$features.Add([string]$feature)}
foreach($feature in @(
    'adds a persisted overall Huymaier Console brightness control from 0 to 200 percent in exact 10 percent steps without changing Windows display brightness or external applications',
    'preserves the v0.30.1 self-update bridge so installed v0.30.1 systems recognize v0.30.2 and select HC0302.zip plus its SHA-256 sidecar',
    'preserves the v0.30.1 0-200 percent 3D-model brightness control and bounded fan-style presentation motion',
    'preserves HC3D v4 COLOR_0 vertex colors, balanced material response, controller routing, Quick Access, Downloads, Recomps, GameCube, streaming and installer integrity'
)){
    if($features -notcontains $feature){[void]$features.Add($feature)}
}
$manifest.features=[object[]]$features.ToArray()
$manifest|ConvertTo-Json -Depth 20|Set-Content -LiteralPath $ManifestPath -Encoding UTF8

$appx=[IO.File]::ReadAllText($AppxManifestPath,[Text.Encoding]::UTF8)
$oldAppx='Version="0.26.4.0"'
$newAppx='Version="0.30.2.0"'
if(([regex]::Matches($appx,[regex]::Escape($oldAppx))).Count -ne 1){throw 'Expected exactly one v0.26.4.0 AppX identity before candidate stamping.'}
$appx=$appx.Replace($oldAppx,$newAppx)
[IO.File]::WriteAllText($AppxManifestPath,$appx,(New-Object Text.UTF8Encoding($false)))

Write-Host "Stamped shell, bootstrap, installer core/cache, native build stamp, manifest and AppX as Huymaier Console v$version / console-brightness-rc1."