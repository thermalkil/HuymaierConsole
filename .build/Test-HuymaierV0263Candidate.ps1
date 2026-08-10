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
if([string]$manifest.build -ne 'native-console-fidelity-rc3'){throw 'v0.26.3 candidate is not the RC3 authentic-console integration build.'}

[void](Require-Text (Join-Path $StageRoot 'HuymaierConsole.ps1') @("`$script:AppVersion = '0.26.3'",'Complete-HcEmulatorPlatformPicker') 'Main shell')
[void](Require-Text (Join-Path $StageRoot 'HuymaierBootstrap.ps1') @("`$script:ExpectedConsoleVersion='0.26.3'") 'Bootstrap')
[void](Require-Text (Join-Path $StageRoot 'HuymaierInstallerCore.ps1') @("`$script:InstallVersion='0.26.3'") 'Installer core')
[void](Require-Text (Join-Path $StageRoot 'Native\HuymaierConsole.GameInput.cs') @('public const string Version = "0.26.3";','public const string Architecture = "x64";') 'Native build stamp')
[void](Require-Text (Join-Path $StageRoot 'Native\HuymaierConsole.NativeApp.cs') @('return "0.26.3";','internal static class HuymaierNativePickerRequest') 'Native bridge')
[void](Require-Text (Join-Path $StageRoot 'FSEPackage\AppxManifest.xml') @('Version="0.26.3.0"','ProcessorArchitecture="x64"') 'FSE package manifest')

$console=Require-Text (Join-Path $StageRoot 'Native\HuymaierConsole.ConsolePlatforms.cs') @(
    'RenderN64GamePakLauncher','ProcessN64MenuCommand',
    'RenderGameCubeHub','Viewport3D','QuaternionAnimation','CreateGameCubeFace','RenderGameCubeCalendar',
    'RenderWiiMenuAuthentic','RenderWiiChannelStart','ProcessWiiMenuCommand',
    'RenderWiiUMenuAuthentic','RenderSwitchHomeAuthentic','RenderSwitchAllSoftware','RenderXboxRoot',
    'ProcessMetroNavigationCommand','ProcessGameCubeHubCommand','ProcessSwitchHomeCommand',
    'FindEmulatorArtwork','QueueConsoleArtworkRefresh','TryDownloadConsoleCover',
    'RequestHuymaierPicker','InstallPrimaryEmulator','ExportSave',
    'if (command == XmbInputCommand.LeftShoulder || command == XmbInputCommand.RightShoulder) return;'
) 'Native console fidelity renderer'
foreach($forbidden in @('OpenFileDialog','FolderBrowserDialog','Wii News','Forecast Channel','Nintendo Switch Online','GameShare','Virtual Game Card','Xbox Live','LB / RB')){
    if($console -match [regex]::Escape($forbidden)){throw "Dead/generic native-console surface survived: $forbidden"}
}
if($console -match 'LeftShoulder[^\r\n]{0,120}SwitchPage' -or $console -match 'RightShoulder[^\r\n]{0,120}SwitchPage'){
    throw 'Shoulder buttons still change native console page/selection state.'
}

$emulatorHost=Require-Text (Join-Path $StageRoot 'HuymaierEmulatorPlatforms.ps1') @(
    'Complete-HcEmulatorPlatformPicker','Invoke-HcNativeConsolePickerRequest','Start-HcEmulatorInstall',
    'InstallPrimaryEmulator','ExportSave','picker-request.json'
) 'Emulator picker/install host'
$emulatorInstaller=Require-Text (Join-Path $StageRoot 'HuymaierEmulatorInstaller.ps1') @(
    'Install-Latest-DuckStation.ps1','Install-Latest-PCSX2.ps1','Install-Latest-RPCS3.ps1',
    'Rosalie241/RMG','dolphin-emu.org/download/','cemu-project/Cemu',
    'git.eden-emu.dev/api/v1/repos/eden-emu/eden/releases/latest','xemu-project/xemu','xenia-canary/xenia-canary',
    'dolphin-$version-x64.7z'
) 'Official emulator installer'

$steam=Require-Text (Join-Path $StageRoot 'HuymaierSteamWorker.ps1') @(
    'library_600x900_2x.jpg','cdn.cloudflare.steamstatic.com','New-SteamFallbackArtwork','Artwork\Steam'
) 'Steam artwork repair'
$ownership=Require-Text (Join-Path $StageRoot 'HuymaierSteamOwnership.ps1') @('Get-SteamArtwork $root $id $name') 'Steam owned-library artwork repair'

# PlayStation visual payload directories remain byte-for-byte source-frozen. The
# existing PS1/PS2/PS3 native visual/navigation classes are allowed only the
# requested core path/install handoff so every emulator uses Huymaier's picker.
$forbiddenPs=@(git diff --name-only v0.26.2 -- 'EmulatorPlatforms/PS1' 'EmulatorPlatforms/PS2' 'EmulatorPlatforms/PS3')
if($forbiddenPs.Count){throw ('Frozen PlayStation platform payload changed: '+($forbiddenPs -join ', '))}
$ps1=Require-Text (Join-Path $StageRoot 'Native\HuymaierConsole.Ps1.cs') @(
    'HuymaierNativePickerRequest.Request(this, "PS1", "PlayStation", "PrimaryEmulator"',
    'HuymaierNativePickerRequest.Request(this, "PS1", "PlayStation", "DataRoot"',
    'HuymaierNativePickerRequest.Request(this, "PS1", "PlayStation", "GameFolder"',
    'HuymaierNativePickerRequest.Request(this, "PS1", "PlayStation", "InstallPrimaryEmulator"'
) 'PS1 path-only integration'
$native=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'Native\HuymaierConsole.NativeApp.cs') -Encoding UTF8
foreach($required in @(
    'HuymaierNativePickerRequest.Request(this, "PS2", "PlayStation 2", "PrimaryEmulator"',
    'HuymaierNativePickerRequest.Request(this, "PS2", "PlayStation 2", "DataRoot"',
    'HuymaierNativePickerRequest.Request(this, "PS2", "PlayStation 2", "GameFolder"',
    'HuymaierNativePickerRequest.Request(this, "PS2", "PlayStation 2", "InstallPrimaryEmulator"',
    'HuymaierNativePickerRequest.Request(this, "PS3", "PlayStation 3", "PrimaryEmulator"',
    'HuymaierNativePickerRequest.Request(this, "PS3", "PlayStation 3", "DataRoot"',
    'HuymaierNativePickerRequest.Request(this, "PS3", "PlayStation 3", "GameFolder"',
    'HuymaierNativePickerRequest.Request(this, "PS3", "PlayStation 3", "InstallPrimaryEmulator"'
)){if($native -notmatch [regex]::Escape($required)){throw "PS2/PS3 path-only integration invariant missing: $required"}}

# Keep every v0.26.2 feature gate release-blocking. Run its exact test against a
# temporary compatibility mirror whose version-only fields are normalized back
# to the values expected by the historical test; production bytes remain v0.26.3.
$compat=Join-Path $env:RUNNER_TEMP ('hc-v0262-compat-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $compat|Out-Null
try {
    Copy-Item -Path (Join-Path $StageRoot '*') -Destination $compat -Recurse -Force
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
$validation|Add-Member -NotePropertyName emulatorNativePickerGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName officialEmulatorInstallGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName emulatorFirstConsoleArtworkGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName steamNeverBlankArtworkGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName playStationVisualFreezePathIntegrationGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName inheritedV0262RegressionGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName version0263ConsistencyGate -NotePropertyValue 'success' -Force
$validation|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $ValidationPath -Encoding UTF8
Write-Host 'v0.26.3 authentic-console, emulator-integration, artwork, and inherited v0.26.2 release gates passed.'
