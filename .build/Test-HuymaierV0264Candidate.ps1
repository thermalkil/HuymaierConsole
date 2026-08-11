param(
    [Parameter(Mandatory=$true)][string]$StageRoot,
    [Parameter(Mandatory=$true)][string]$ValidationPath
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'

# Reuse the complete reviewed v0.26.3 RC4 + inherited v0.26.2 regression suite,
# changing only the candidate version/build identity. The runtime copy also
# adapts the immutable RC3 core that the RC4 test reconstructs with git show.
$runtime=Join-Path $PSScriptRoot 'Test-HuymaierV0264Inherited.runtime.ps1'
try {
    $text=Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot 'Test-HuymaierV0263Candidate.ps1') -Encoding UTF8
    if([string]::IsNullOrWhiteSpace($text) -or $text -notmatch 'rc4UserFeedbackGate'){throw 'Could not load the reviewed v0.26.3 RC4 regression suite.'}
    $text=$text.Replace('native-console-fidelity-rc4-final','platform-expansion-rc1')
    $needle='$text=$text.Replace(''native-console-fidelity-rc3'',''platform-expansion-rc1'')'
    $replacement=$needle+"`r`n            `$text=`$text.Replace('0.26.3','0.26.4')"
    if($text -notmatch [regex]::Escape($needle)){throw 'Could not locate inherited RC3 build-identity adaptation hook.'}
    $text=$text.Replace($needle,$replacement)
    $text=$text.Replace('Final v0.26.3 validation record','Final v0.26.4 validation record')
    [IO.File]::WriteAllText($runtime,$text+"`n",(New-Object Text.UTF8Encoding($true)))
    & $runtime -StageRoot $StageRoot -ValidationPath $ValidationPath
} finally {
    Remove-Item -LiteralPath $runtime -Force -ErrorAction SilentlyContinue
}

function Require-Text([string]$Relative,[string[]]$Needles){
    $path=Join-Path $StageRoot $Relative
    if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "v0.26.4 required file missing: $Relative"}
    $raw=Get-Content -Raw -LiteralPath $path -Encoding UTF8
    foreach($needle in $Needles){if($raw -notmatch [regex]::Escape($needle)){throw "$Relative missing v0.26.4 invariant: $needle"}}
    return $raw
}

$manifest=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'manifest.json') -Encoding UTF8|ConvertFrom-Json
if([string]$manifest.version -ne '0.26.4'){throw 'Candidate manifest is not v0.26.4.'}
if([string]$manifest.build -ne 'platform-expansion-rc1'){throw 'Candidate manifest is not platform-expansion-rc1.'}
if([string]$manifest.builtFrom -ne 'HC262.zip'){throw 'v0.26.4 candidate did not preserve the published HC262.zip package baseline.'}

$registry=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'EmulatorPlatforms\platform-registry.json') -Encoding UTF8|ConvertFrom-Json
foreach($id in @('ps4','vita','arcade')){
    $entry=@($registry.platforms|Where-Object{$_.id -eq $id})
    if($entry.Count -ne 1 -or -not[bool]$entry[0].enabled){throw "$id is not enabled exactly once in the v0.26.4 candidate."}
    foreach($cap in @('latest-emulator-install','native-full-emulator-settings','native-save-management')){if(@($entry[0].capabilities)-notcontains$cap){throw "$id candidate registry missing capability: $cap"}}
}
foreach($folder in @('FinalBurnNeo','NeoGeo','Jaguar')){
    $platform=Get-Content -Raw -LiteralPath (Join-Path $StageRoot "EmulatorPlatforms\$folder\platform.json") -Encoding UTF8|ConvertFrom-Json
    if([bool]$platform.enabled){throw "$folder must remain staged/disabled in v0.26.4 RC1."}
}
foreach($id in @('finalburnneo','neogeo','jaguar')){
    $entry=@($registry.platforms|Where-Object{$_.id -eq $id})
    if($entry.Count -gt 1){throw "$id registry entry is duplicated."}
    if($entry.Count -eq 1 -and [bool]$entry[0].enabled){throw "$id registry entry must remain disabled."}
}

$installer=Require-Text 'HuymaierEmulatorInstaller.ps1' @(
    "Get-GithubReleaseAsset 'mamedev/mame'",
    "'windows-latest.zip'",
    "'PS4'",
    "'VITA'",
    "'ARCADE'"
)
if($installer -match 'Get-GithubLatestAssets'){throw 'Stale undefined MAME GitHub asset helper survived into the candidate.'}
if($installer -match "'VITA'.{0,600}windows-arm64-latest"){throw 'Vita3K x64 resolver can select the ARM64 package.'}

$native=Require-Text 'Native\HuymaierConsole.ConsolePlatforms.cs' @(
    'RenderPs4DynamicMenu',
    'RenderVitaLiveArea',
    'RefreshModernPlayStationLibrary(showNotice)',
    'shad.Append("-g ")',
    '"-r " + QuoteProcessArgument(titleId)',
    'RenderArcadeOperatorSettings',
    'RenderArcadeStorage',
    'BuildMameOverrideArguments',
    '-rompath'
)
if($native -match 'LeftShoulder[^\r\n]{0,200}SwitchPage' -or $native -match 'RightShoulder[^\r\n]{0,200}SwitchPage'){
    throw 'LB/RB shoulder buttons switch ordinary native platform pages in v0.26.4.'
}

$ps4=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'EmulatorPlatforms\PS4\platform.json') -Encoding UTF8|ConvertFrom-Json
$vita=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'EmulatorPlatforms\Vita\platform.json') -Encoding UTF8|ConvertFrom-Json
$arcade=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'EmulatorPlatforms\Arcade\platform.json') -Encoding UTF8|ConvertFrom-Json
if(-[bool]$ps4.enabled -or [string]$ps4.primaryBackend -ne 'shadPS4' -or -not[string]::IsNullOrWhiteSpace([string]$ps4.fallbackBackend)){throw 'PS4 production backend contract is invalid.'}
if(-[bool]$vita.enabled -or [string]$vita.primaryBackend -ne 'Vita3K' -or -not[string]::IsNullOrWhiteSpace([string]$vita.fallbackBackend)){throw 'Vita production backend contract is invalid.'}
if(-[bool]$arcade.enabled -or [string]$arcade.primaryBackend -ne 'MAME' -or -not[string]::IsNullOrWhiteSpace([string]$arcade.fallbackBackend)){throw 'Arcade production backend contract is not MAME-only.'}

$core=Require-Text 'HuymaierConsole.ps1' @("`$script:AppVersion = '0.26.4'")
$bootstrap=Require-Text 'HuymaierBootstrap.ps1' @("`$script:ExpectedConsoleVersion='0.26.4'")
$installCore=Require-Text 'HuymaierInstallerCore.ps1' @("`$script:InstallVersion='0.26.4'")
$appx=Require-Text 'FSEPackage\AppxManifest.xml' @('Version="0.26.4.0"')

$validation=Get-Content -Raw -LiteralPath $ValidationPath -Encoding UTF8|ConvertFrom-Json
$validation|Add-Member -NotePropertyName v0264PlatformExpansionGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName modernPlayStationGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName mameArcadeGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName stagedLateBackendSafetyGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName version0264ConsistencyGate -NotePropertyValue 'success' -Force
$validation|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $ValidationPath -Encoding UTF8
Write-Host 'v0.26.4 platform expansion, modern PlayStation, MAME Arcade, staged-backend safety, and inherited RC4/v0.26.2 regression gates passed.'
