from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

def read(rel):
    return (ROOT / rel).read_text(encoding="utf-8-sig")

def write(rel, text):
    (ROOT / rel).write_text(text, encoding="utf-8")

def replace_once(rel, old, new):
    text = read(rel)
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"Expected exactly one block in {rel}, found {count}: {old[:140]!r}")
    write(rel, text.replace(old, new, 1))

# Tighten the read-only GameCube card parser before the Windows compile gate.
replace_once(
    "Native/HuymaierConsole.ConsolePlatforms.cs",
    'GameCubeMemoryCardInfo card = new GameCubeMemoryCardInfo { Slot = slot, Path = path, TotalBlocks = (int)(info.Length / blockSize), FreeBlocks = ReadBe16(metadata, activeBat + 0x0006) };',
    'GameCubeMemoryCardInfo card = new GameCubeMemoryCardInfo { Slot = slot, Path = path, TotalBlocks = Math.Max(0, (int)(info.Length / blockSize) - 5), FreeBlocks = ReadBe16(metadata, activeBat + 0x0006) };'
)
replace_once(
    "Native/HuymaierConsole.ConsolePlatforms.cs",
    'DateTime modified = new DateTime(2000, 1, 1, 0, 0, 0, DateTimeKind.Local).AddSeconds(Math.Min(seconds, 3155760000U));',
    'double safeSeconds = Math.Min((double)seconds, 3155760000.0); DateTime modified = new DateTime(2000, 1, 1, 0, 0, 0, DateTimeKind.Local).AddSeconds(safeSeconds);'
)

# Keep SteamGridDB calls API-only and broad: request all grids, then filter portrait
# candidates locally so an API-side dimension syntax change cannot blank the library.
replace_once(
    "HuymaierArtworkWorker.ps1",
    '("https://www.steamgriddb.com/api/v2/grids/steam/"+$appId+"?dimensions=600x900,342x482,660x930&nsfw=false&humor=false")',
    '("https://www.steamgriddb.com/api/v2/grids/steam/"+$appId+"?nsfw=false&humor=false")'
)
replace_once(
    "HuymaierArtworkWorker.ps1",
    '("https://www.steamgriddb.com/api/v2/grids/game/"+$sgdbId+"?dimensions=600x900,342x482,660x930&nsfw=false&humor=false")',
    '("https://www.steamgriddb.com/api/v2/grids/game/"+$sgdbId+"?nsfw=false&humor=false")'
)

# Expose the optional personal SteamGridDB key through Huymaier's controller-first
# native keyboard. It is masked onscreen and never hard-coded into the repository.
replace_once(
    "HuymaierStorefronts.ps1",
    "$script:KeyboardSecure=([string]$Mode -eq 'BrowserInputSecure')",
    "$script:KeyboardSecure=([string]$Mode -in @('BrowserInputSecure','SteamGridDbApiKey'))"
)
replace_once(
    "HuymaierStorefronts.ps1",
    "        'CreateFolder' {\n            if([string]::IsNullOrWhiteSpace($Value)){return}",
    "        'SteamGridDbApiKey' {\n            $key=([string]$Value).Trim()\n            $script:Config.SteamGridDbApiKey=$key\n            Save-Config\n            Set-ConsoleNotice $(if($key){'SteamGridDB artwork key saved. Refresh missing box art to use it.'}else{'SteamGridDB artwork key cleared.'}) 'INFO'\n            Render-Page\n        }\n        'CreateFolder' {\n            if([string]::IsNullOrWhiteSpace($Value)){return}"
)
replace_once(
    "HuymaierConsole.ps1",
    "        'online-artwork-toggle' { $script:Config.OnlineArtworkEnabled=-not [bool]$script:Config.OnlineArtworkEnabled;Save-Config;Render-Page }",
    "        'steamgriddb-key' { Show-NativeKeyboard -Title 'SteamGridDB artwork key' -InitialText ([string]$script:Config.SteamGridDbApiKey) -Mode 'SteamGridDbApiKey' -Context $null }\n        'online-artwork-toggle' { $script:Config.OnlineArtworkEnabled=-not [bool]$script:Config.OnlineArtworkEnabled;Save-Config;Render-Page }"
)
replace_once(
    "HuymaierConsole.ps1",
    "(New-Action 'online-artwork-toggle' $(if($script:Config.OnlineArtworkEnabled){'Online box art: On'}else{'Online box art: Off'})),(New-Action 'artwork-refresh' 'Refresh missing box art')",
    "(New-Action 'steamgriddb-key' $(if([string]::IsNullOrWhiteSpace([string]$script:Config.SteamGridDbApiKey)){'SteamGridDB artwork key: Not configured'}else{'SteamGridDB artwork key: Configured'}) 'Optional personal SteamGridDB API key. Steam uses AppID matching; other PC storefronts use title matching.'),(New-Action 'online-artwork-toggle' $(if($script:Config.OnlineArtworkEnabled){'Online box art: On'}else{'Online box art: Off'})),(New-Action 'artwork-refresh' 'Refresh missing box art')"
)

# Update the release-shaped manifest to describe this exact RC4 test source.
manifest = read("manifest.json")
manifest = manifest.replace('"build": "native-console-fidelity-rc4"', '"build": "native-console-fidelity-rc4-final"', 1)
manifest = manifest.replace(
    '"keeps LB/RB out of normal page and selection navigation on the redesigned non-PlayStation native console interfaces"',
    '"keeps LB/RB out of ordinary page and selection navigation while using LB/RB only as a first-letter library accelerator on N64, GameCube, and Wii"',
    1,
)
manifest = manifest.replace(
    '"description": "v0.26.3 RC3 is the authentic-console, emulator-integration, navigation, and artwork pass built from the published v0.26.2 baseline. PS1/PS2/PS3 presentation remains frozen; their emulator/data/library path choices now hand off to Huymaier Console native picker."',
    '"description": "v0.26.3 RC4 incorporates real-machine RC3 feedback: adjustable GameCube cube scale, native GameCube/Wii save presentation, Nintendo library alphabet jumps, repaired emulator installation routing, and optional SteamGridDB artwork matching. PS1/PS2/PS3 presentation remains frozen."',
    1,
)
write("manifest.json", manifest)

print("RC4 final compile/settings pass applied successfully.")
