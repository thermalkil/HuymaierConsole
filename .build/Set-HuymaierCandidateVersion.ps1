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
if($version -ne '0.30.6'){throw "This v0.30.6 stamping transform refuses unexpected version '$version'."}

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
$manifest.baseVersion='0.30.4'
$manifest.build='console-model-transform-scale-rc1'
$manifest.description='v0.30.6 keeps provider/storefront models unchanged while improving console-model correction and adding saved per-console model scale to Edit Model mode.'
$features=New-Object System.Collections.ArrayList
foreach($feature in @($manifest.features)){[void]$features.Add([string]$feature)}
foreach($feature in @(
    'adds saved per-console model scale to Edit Model mode from 30 to 300 percent in 10 percent steps using LB/RB, alongside the existing saved yaw and pitch controls',
    'applies each saved console scale to both the full-screen viewer and console shelf while leaving the top provider/storefront shelf scale path unchanged',
    'carries forward adaptive negative-determinant winding correction for console GLBs and automatically refreshes corrected HC3D winding caches without modifying user source models',
    'retains v0.30.4 saved model orientation, v0.30.3 Windows/Xbox FSE updater handoff, overall console brightness, HC3D v4 COLOR_0 rendering, controller routing, Quick Access, Downloads, Recomps, GameCube, streaming and installer integrity'
)){
    if($features -notcontains $feature){[void]$features.Add($feature)}
}
$manifest.features=[object[]]$features.ToArray()
$manifest|ConvertTo-Json -Depth 20|Set-Content -LiteralPath $ManifestPath -Encoding UTF8

$appx=[IO.File]::ReadAllText($AppxManifestPath,[Text.Encoding]::UTF8)
$oldAppx='Version="0.26.4.0"'
$newAppx='Version="0.30.6.0"'
if(([regex]::Matches($appx,[regex]::Escape($oldAppx))).Count -ne 1){throw 'Expected exactly one v0.26.4.0 AppX identity before candidate stamping.'}
$appx=$appx.Replace($oldAppx,$newAppx)
[IO.File]::WriteAllText($AppxManifestPath,$appx,(New-Object Text.UTF8Encoding($false)))

Write-Host "Stamped shell, bootstrap, installer core/cache, native build stamp, manifest and AppX as Huymaier Console v$version / console-model-transform-scale-rc1."
