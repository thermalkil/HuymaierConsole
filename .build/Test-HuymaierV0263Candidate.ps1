param(
    [Parameter(Mandatory=$true)][string]$StageRoot,
    [Parameter(Mandatory=$true)][string]$ValidationPath
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'

function Require-Rc4Text {
    param([string]$Path,[string[]]$Needles,[string]$Label)
    if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){throw "$Label is missing: $Path"}
    $text=Get-Content -Raw -LiteralPath $Path -Encoding UTF8
    foreach($needle in $Needles){if($text -notmatch [regex]::Escape($needle)){throw "$Label invariant is missing: $needle"}}
    return $text
}

# v0.26.3 is staged from the published v0.26.2 runtime/media package. Remove
# package-only historical text that was deliberately deleted from source, then
# reseal and verify the exact ZIP before running the release regression gates.
& (Join-Path $PSScriptRoot 'Clean-HuymaierV0263CandidateText.ps1') -StageRoot $StageRoot -ValidationPath $ValidationPath

# Run the installer/integrity failure-injection suite again after cleanup so the
# package that reaches the user, not merely the pre-clean staging tree, is gated.
& (Join-Path $PSScriptRoot 'Test-HuymaierCandidate.ps1') -StageRoot $StageRoot -ValidationPath $ValidationPath

# Preserve the reviewed RC3 regression suite but adapt only the two assertions
# intentionally changed by RC4: the build marker and the narrowly-scoped
# N64/GameCube/Wii LB/RB first-letter accelerator. All inherited v0.26.2 gates
# and PlayStation freeze checks remain unchanged.
$core=Join-Path $PSScriptRoot 'Test-HuymaierV0263CandidateCore.runtime.ps1'
try {
    $text=(& git show '0da9bcdfb34dbc4c59f4a9514bf57e0c595dbf87:.build/Test-HuymaierV0263Candidate.ps1') -join "`n"
    if([string]::IsNullOrWhiteSpace($text) -or $text -notmatch 'nativeConsoleFidelityGate'){
        throw 'Could not materialize the reviewed immutable RC3 regression gate.'
    }
    $text=$text.Replace('native-console-fidelity-rc3','native-console-fidelity-rc4-final')
    $text=$text.Replace('if (command == XmbInputCommand.LeftShoulder || command == XmbInputCommand.RightShoulder) return;','TryProcessLibraryLetterJump(command)')
    $text=$text.Replace(",'LB / RB'",'')
    [IO.File]::WriteAllText($core,$text+"`n",(New-Object Text.UTF8Encoding($true)))
    & $core -StageRoot $StageRoot -ValidationPath $ValidationPath
} finally {
    Remove-Item -LiteralPath $core -Force -ErrorAction SilentlyContinue
}

$manifest=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'manifest.json') -Encoding UTF8|ConvertFrom-Json
if([string]$manifest.build -ne 'native-console-fidelity-rc4-final'){throw 'Final package is not the RC4 user-feedback build.'}

$consolePath=Join-Path $StageRoot 'Native\HuymaierConsole.ConsolePlatforms.cs'
$console=Require-Rc4Text $consolePath @(
    'schemaVersion = 7;',
    'gameCubeScale = 0.66;',
    'new ScaleTransform3D(settings.gameCubeScale, settings.gameCubeScale, settings.gameCubeScale)',
    'CycleGameCubeScale',
    'TryProcessLibraryLetterJump(command)',
    'BuildLibraryAlphabetRail',
    'GetAvailableLibraryLetters',
    'LB / RB  Letter',
    'ParseGameCubeRawCard',
    'ScanGameCubeMemoryCards',
    'ScanWiiSaves',
    'BackupNativeSavePath',
    'TotalBlocks = Math.Max(0, (int)(info.Length / blockSize) - 5)',
    'double safeSeconds = Math.Min((double)seconds, 3155760000.0)',
    'GetWiiMenuPageCount()'
) 'RC4 Nintendo native renderer'

if($console -match [regex]::Escape('selected = n64LibraryIndex;')){throw 'N64 game cycling still contaminates bottom utility-button selection state.'}
foreach($forbidden in @('Wii Console and SD Card','Save Data / SD Card','CreateWiiRoundButton("SD"','"⚙","Settings"','Configure Dolphin memory cards')){
    if($console -match [regex]::Escape($forbidden)){throw "RC4 Wii/GameCube cleanup invariant failed: $forbidden"}
}
if($console -match 'LeftShoulder[^\r\n]{0,160}SwitchPage' -or $console -match 'RightShoulder[^\r\n]{0,160}SwitchPage'){
    throw 'Shoulder buttons may jump library letters but must never switch native console pages.'
}
foreach($shellName in @('N64','GameCube','Wii')){
    if($console -notmatch [regex]::Escape('definition.Shell == "'+$shellName+'"')){throw "Alphabet-jump shell guard missing: $shellName"}
}

$gcStart=$console.IndexOf('private void RenderGameCubeMemoryCards')
$gcEnd=$console.IndexOf('private void RenderWiiDataManagement',$gcStart)
if($gcStart -lt 0 -or $gcEnd -le $gcStart){throw 'Could not isolate native GameCube memory-card renderer.'}
$gcBlock=$console.Substring($gcStart,$gcEnd-$gcStart)
if($gcBlock -match [regex]::Escape('Process.Start("explorer.exe"')){throw 'GameCube memory-card UI still delegates save browsing to Explorer.'}
$wiiStart=$gcEnd
$wiiEnd=$console.IndexOf('private static ushort ReadBe16',$wiiStart)
if($wiiEnd -le $wiiStart){throw 'Could not isolate native Wii save-data renderer.'}
$wiiBlock=$console.Substring($wiiStart,$wiiEnd-$wiiStart)
if($wiiBlock -match [regex]::Escape('Process.Start("explorer.exe"')){throw 'Wii save-data UI still delegates save browsing to Explorer.'}

$saveRootStart=$console.IndexOf('private List<string> FindSaveRoots()')
$saveRootEnd=$console.IndexOf('private void RenderStorageManager',$saveRootStart)
if($saveRootStart -lt 0 -or $saveRootEnd -le $saveRootStart){throw 'Could not isolate console save-root discovery.'}
$saveRoots=$console.Substring($saveRootStart,$saveRootEnd-$saveRootStart)
if($saveRoots -match [regex]::Escape('definition.Shell == "GameCube" || definition.Shell == "Wii"')){throw 'GameCube and Wii save roots are still cross-wired.'}
foreach($required in @('if (definition.Shell == "GameCube")','else if (definition.Shell == "Wii")','Path.Combine(dolphinData, "GC")','Path.Combine(dolphinData, "Wii")')){
    if($saveRoots -notmatch [regex]::Escape($required)){throw "Strict GameCube/Wii save-root invariant missing: $required"}
}

$emulatorHost=Require-Rc4Text (Join-Path $StageRoot 'HuymaierEmulatorPlatforms.ps1') @(
    'Start-HcEmulatorInstall',
    '$output=@()',
    'if(-not $?){throw ''The emulator installer script did not complete successfully.''}'
) 'RC4 emulator install host'
if($emulatorHost -match [regex]::Escape('if($LASTEXITCODE -ne 0){throw "Installer exited with code $LASTEXITCODE."}')){
    throw 'Emulator installation still depends on a stale native LASTEXITCODE after invoking a PowerShell installer.'
}

$shell=Require-Rc4Text (Join-Path $StageRoot 'HuymaierConsole.ps1') @(
    "SteamGridDbApiKey = ''",
    "'steamgriddb-key'",
    "-Mode 'SteamGridDbApiKey'",
    'SteamGridDB artwork key: Configured',
    'SteamGridDB artwork key: Not configured'
) 'SteamGridDB Huymaier settings integration'
$keyboard=Require-Rc4Text (Join-Path $StageRoot 'HuymaierStorefronts.ps1') @(
    "@('BrowserInputSecure','SteamGridDbApiKey')",
    "'SteamGridDbApiKey' {",
    '$script:Config.SteamGridDbApiKey=$key'
) 'SteamGridDB native keyboard integration'
$artwork=Require-Rc4Text (Join-Path $StageRoot 'HuymaierArtworkWorker.ps1') @(
    'function Try-SteamGridDbArt',
    'function Get-SteamAppId',
    'https://www.steamgriddb.com/api/v2/grids/steam/',
    'https://www.steamgriddb.com/api/v2/search/autocomplete/',
    'https://www.steamgriddb.com/api/v2/grids/game/',
    "'Authorization'= ('Bearer '+$key)"
) 'SteamGridDB artwork worker'
if($artwork -match 'SteamGridDbApiKey\s*=\s*[''"][A-Za-z0-9_-]{20,}[''"]'){throw 'A SteamGridDB API key appears to be hard-coded in production source.'}
$steamOfficial=$artwork.IndexOf("if(-not `$found -and `$source -match '(?i)^steam`$')")
$sgdb=$artwork.IndexOf('Try-SteamGridDbArt $game $target')
if($steamOfficial -lt 0 -or $sgdb -lt 0 -or $steamOfficial -gt $sgdb){throw 'Steam official artwork must be attempted before SteamGridDB.'}

$validation=Get-Content -Raw -LiteralPath $ValidationPath -Encoding UTF8|ConvertFrom-Json
if([string]$validation.obsoleteTextCleanupGate -ne 'success'){
    throw 'Final v0.26.3 validation record lost the obsolete-text cleanup gate.'
}
$validation|Add-Member -NotePropertyName rc4UserFeedbackGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName gameCubeScaleGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName nintendoAlphabetFastJumpGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName nativeNintendoSaveUiGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName emulatorInstallRoutingGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName steamGridDbArtworkGate -NotePropertyValue 'success' -Force
$validation|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $ValidationPath -Encoding UTF8
Write-Host 'v0.26.3 RC4 scale, native-save, alphabet-jump, emulator-install, SteamGridDB, cleanup, and inherited regression gates passed.'
