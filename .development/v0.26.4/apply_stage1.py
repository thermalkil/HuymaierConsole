from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[2]


def replace_once(path: Path, old: str, new: str, label: str):
    text = path.read_text(encoding='utf-8-sig')
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly one match, found {count}')
    path.write_text(text.replace(old, new, 1), encoding='utf-8')


console = ROOT / 'HuymaierConsole.ps1'

replace_once(
    console,
    "        'fse-home-settings' { $script:SubPage='FSEHome';$script:SelectedAction=0;Render-Page }",
    "        'fse-home-settings' { $script:SubPage='FSEHome';$script:SelectedAction=0;Render-Page }\n        'artwork-settings' { $script:SubPage='Artwork';$script:SelectedAction=0;Render-Page }",
    'artwork settings action routing'
)

artwork_block = r'''            if($script:SubPage -eq 'Artwork'){
                $sgdbState=if([string]::IsNullOrWhiteSpace([string]$script:Config.SteamGridDbApiKey)){'NOT CONFIGURED'}else{'CONFIGURED'}
                return [pscustomobject]@{
                    Title='Artwork & Metadata'
                    Subtitle='Box art sources and metadata matching for every storefront and console library.'
                    Hero='ARTWORK SOURCES'
                    HeroText="SteamGridDB: $sgdbState`nSteam games use their Steam AppID; other Windows storefronts use normalized title matching.`nLocal storefront/emulator artwork remains preferred before online fallbacks."
                    Actions=@(
                        (New-Action 'steamgriddb-key' $(if([string]::IsNullOrWhiteSpace([string]$script:Config.SteamGridDbApiKey)){'SteamGridDB API key: Add personal key'}else{'SteamGridDB API key: Configured'}) 'Opens the Huymaier native keyboard. Your personal key is stored locally in Huymaier Console config and is used only for SteamGridDB API requests.'),
                        (New-Action 'online-artwork-toggle' $(if($script:Config.OnlineArtworkEnabled){'Online box art: On'}else{'Online box art: Off'}) 'Steam local/CDN and provider artwork are tried first; SteamGridDB is an optional cross-storefront fallback.'),
                        (New-Action 'artwork-refresh' 'Refresh missing box art' 'Rescans entries that still do not have usable artwork.'),
                        (New-Action 'platform-background-toggle' $(if($script:Config.PlatformBackgroundsEnabled){'Platform backgrounds: On'}else{'Platform backgrounds: Off'})),
                        (New-Action 'subpage-back' 'Back to Settings')
                    )
                }
            }
'''
marker = "            $browserLabel=if($script:Config.BrowserName){$script:Config.BrowserName}else{'No browser detected'}"
text = console.read_text(encoding='utf-8-sig')
if artwork_block.strip() not in text:
    if text.count(marker) != 1:
        raise SystemExit('Artwork subpage insertion marker not unique')
    text = text.replace(marker, artwork_block + marker, 1)
    console.write_text(text, encoding='utf-8')

old = "Actions=@((New-Action 'fse-home-settings' 'Xbox Mode / FSE Home' 'Choose Huymaier Console alongside Xbox on supported Windows 11 builds.'),(New-Action 'open-display-panel' 'Display & HDR')"
new = "Actions=@((New-Action 'fse-home-settings' 'Xbox Mode / FSE Home' 'Choose Huymaier Console alongside Xbox on supported Windows 11 builds.'),(New-Action 'artwork-settings' 'Artwork & Metadata' 'SteamGridDB key, provider artwork, online artwork, cache refresh and platform backgrounds.'),(New-Action 'open-display-panel' 'Display & HDR')"
replace_once(console, old, new, 'root settings artwork entry')

manifest_path = ROOT / 'manifest.json'
manifest = json.loads(manifest_path.read_text(encoding='utf-8-sig'))
manifest['build'] = 'platform-expansion-stage1'
manifest['description'] = 'v0.26.4 development branch stage 1: exposes Artwork & Metadata prominently and begins the researched full-platform native console expansion from the successful v0.26.3 RC4 source.'
features = list(manifest.get('features', []))
feature = 'adds a prominent Settings > Artwork & Metadata surface for SteamGridDB, provider artwork, online artwork refresh and platform backgrounds'
if feature not in features:
    features.append(feature)
manifest['features'] = features
manifest_path.write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')

print('v0.26.4 stage 1 materialized')
