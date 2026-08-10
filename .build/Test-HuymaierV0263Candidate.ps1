param(
    [Parameter(Mandatory=$true)][string]$StageRoot,
    [Parameter(Mandatory=$true)][string]$ValidationPath
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'

function Require-Text {
    param([string]$Path,[string[]]$Needles,[string]$Label)
    if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){throw "$Label is missing: $Path"}
    $text=Get-Content -Raw -LiteralPath $Path -Encoding UTF8
    foreach($needle in $Needles){if($text -notmatch [regex]::Escape($needle)){throw "$Label invariant is missing: $needle"}}
    return $text
}

$manifest=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'manifest.json') -Encoding UTF8|ConvertFrom-Json
if([string]$manifest.version -ne '0.26.3'){throw 'Packaged manifest is not v0.26.3.'}
if([string]$manifest.baseVersion -ne '0.26.2'){throw 'v0.26.3 does not identify v0.26.2 as its stable base.'}
if([string]$manifest.builtFrom -ne 'HC262.zip'){throw 'v0.26.3 is not staged from HC262.zip.'}

[void](Require-Text (Join-Path $StageRoot 'HuymaierConsole.ps1') @("`$script:AppVersion = '0.26.3'") 'Main shell')
[void](Require-Text (Join-Path $StageRoot 'HuymaierBootstrap.ps1') @("`$script:ExpectedConsoleVersion='0.26.3'") 'Bootstrap')
[void](Require-Text (Join-Path $StageRoot 'HuymaierInstallerCore.ps1') @("`$script:InstallVersion='0.26.3'") 'Installer core')
[void](Require-Text (Join-Path $StageRoot 'Native\HuymaierConsole.GameInput.cs') @('public const string Version = "0.26.3";','public const string Architecture = "x64";') 'Native build stamp')
[void](Require-Text (Join-Path $StageRoot 'Native\HuymaierConsole.NativeApp.cs') @('return "0.26.3";') 'Native bridge')
[void](Require-Text (Join-Path $StageRoot 'FSEPackage\AppxManifest.xml') @('Version="0.26.3.0"','ProcessorArchitecture="x64"') 'FSE package manifest')

$console=Require-Text (Join-Path $StageRoot 'Native\HuymaierConsole.ConsolePlatforms.cs') @(
    'RenderN64GamePakLauncher','RenderGameCubeHub','RenderGameCubeCalendar',
    'RenderWiiMenuAuthentic','RenderWiiChannelStart','RenderWiiUMenuAuthentic',
    'RenderSwitchHomeAuthentic','RenderSwitchAllSoftware','RenderXboxRoot',
    'ProcessMetroNavigationCommand','ProcessGameCubeHubCommand','ProcessSwitchHomeCommand',
    'if (command == XmbInputCommand.LeftShoulder || command == XmbInputCommand.RightShoulder) return;',
    'int totalPages = 4;','Disc Channel','Wii Message Board','GameShare','Virtual Game Card','play game'
) 'Native console fidelity renderer'
if($console -match [regex]::Escape('LB / RB')){throw 'Native console UI still advertises LB/RB navigation.'}
if($console -match 'LeftShoulder[^\r\n]{0,120}SwitchPage' -or $console -match 'RightShoulder[^\r\n]{0,120}SwitchPage'){
    throw 'Shoulder buttons still change native console page/selection state.'
}

# PS1/PS2/PS3 are frozen for this pass. NativeApp contains PS2/PS3 host classes,
# so allow only the shared NativeBridge version stamp to differ from v0.26.2.
$forbidden=@(git diff --name-only v0.26.2 -- 'Native/HuymaierConsole.Ps1.cs' 'EmulatorPlatforms/PS1' 'EmulatorPlatforms/PS2' 'EmulatorPlatforms/PS3')
if($forbidden.Count){throw ('Frozen PlayStation implementation changed: '+($forbidden -join ', '))}
$baseNative=((& git show 'v0.26.2:Native/HuymaierConsole.NativeApp.cs') -join "`n").TrimEnd()
$currentNative=([IO.File]::ReadAllText((Join-Path $StageRoot 'Native\HuymaierConsole.NativeApp.cs'),[Text.Encoding]::UTF8) -replace "`r`n","`n").TrimStart([char]0xFEFF).TrimEnd()
$currentNative=$currentNative.Replace('public string Version { get { return "0.26.3"; } }','public string Version { get { return "0.26.2"; } }')
if($currentNative -ne $baseNative){throw 'NativeApp changed beyond the shared v0.26.3 version stamp; PS2/PS3 freeze cannot be proven.'}

# Keep every v0.26.2 feature gate release-blocking. Run its exact test against a
# temporary compatibility mirror whose version-only fields are normalized back
# to the values expected by the historical test; production bytes remain v0.26.3.
$compat=Join-Path $env:RUNNER_TEMP ('hc-v0262-compat-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $compat|Out-Null
try {
    Copy-Item -LiteralPath (Join-Path $StageRoot '*') -Destination $compat -Recurse -Force
    $compatManifestPath=Join-Path $compat 'manifest.json'
    $compatManifest=Get-Content -Raw -LiteralPath $compatManifestPath -Encoding UTF8|ConvertFrom-Json
    $compatManifest.version='0.26.2';$compatManifest.baseVersion='0.26.1'
    $compatManifest|ConvertTo-Json -Depth 20|Set-Content -LiteralPath $compatManifestPath -Encoding UTF8
    $replacements=@(
        @('HuymaierConsole.ps1',"`$script:AppVersion = '0.26.3'","`$script:AppVersion = '0.26.2'"),
        @('HuymaierBootstrap.ps1',"`$script:ExpectedConsoleVersion='0.26.3'","`$script:ExpectedConsoleVersion='0.26.2'"),
        @('HuymaierInstallerCore.ps1',"`$script:InstallVersion='0.26.3'","`$script:InstallVersion='0.26.2'"),
        @('Native\HuymaierConsole.GameInput.cs','public const string Version = "0.26.3";','public const string Version = "0.26.2";'),
        @('Native\HuymaierConsole.NativeApp.cs','return "0.26.3";','return "0.26.2";'),
        @('FSEPackage\AppxManifest.xml','Version="0.26.3.0"','Version="0.26.2.0"')
    )
    foreach($entry in $replacements){
        $path=Join-Path $compat $entry[0];$text=Get-Content -Raw -LiteralPath $path -Encoding UTF8
        if($text -notmatch [regex]::Escape($entry[1])){throw "Compatibility normalization source missing: $($entry[1])"}
        $text=$text.Replace($entry[1],$entry[2]);Set-Content -LiteralPath $path -Value $text -Encoding UTF8 -NoNewline
    }
    & (Join-Path $PSScriptRoot 'Test-HuymaierV0262Candidate.ps1') -StageRoot $compat -ValidationPath $ValidationPath
} finally {
    Remove-Item -LiteralPath $compat -Recurse -Force -ErrorAction SilentlyContinue
}

$validation=Get-Content -Raw -LiteralPath $ValidationPath -Encoding UTF8|ConvertFrom-Json
$validation|Add-Member -NotePropertyName nativeConsoleFidelityGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName noBumperConsoleNavigationGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName frozenPlayStationInterfacesGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName inheritedV0262RegressionGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName version0263ConsistencyGate -NotePropertyValue 'success' -Force
$validation|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $ValidationPath -Encoding UTF8
Write-Host 'v0.26.3 console-fidelity and inherited v0.26.2 release gates passed.'
