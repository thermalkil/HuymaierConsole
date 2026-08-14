param(
    [Parameter(Mandatory=$true)][string]$ConsolePlatformsPath
)

Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
if(-not(Test-Path -LiteralPath $ConsolePlatformsPath -PathType Leaf)){throw "Console platform source missing: $ConsolePlatformsPath"}
$text=Get-Content -Raw -LiteralPath $ConsolePlatformsPath -Encoding UTF8
if($text -match 'HUYMAIER_WII_ARTWORK_ALIAS_V1'){return}
if($text -notmatch 'HUYMAIER_DOLPHIN_INTEGRATION_V1'){throw 'Wii artwork-alias transform must run after Dolphin integration.'}

# Display names and artwork keys are intentionally different for Dolphin titles.
# Wii/GameCube cover files are commonly keyed by the six-character disc ID that
# older Huymaier builds exposed as the visible title. Keep the improved display
# title, but derive the artwork key from the ROM path/game ID for every refresh.
$old='foreach(ConsolePlatformGame game in missing){if(closing||generation!=asyncGeneration)break;string cover=FindEmulatorArtwork(game.Path,game.Name);if(String.IsNullOrWhiteSpace(cover))cover=TryDownloadConsoleCover(game);'
$new='foreach(ConsolePlatformGame game in missing){if(closing||generation!=asyncGeneration)break;/* HUYMAIER_WII_ARTWORK_ALIAS_V1 */ string artworkTitle=game.Name;if(definition.Shell.Equals("Wii",StringComparison.OrdinalIgnoreCase)||definition.Shell.Equals("GameCube",StringComparison.OrdinalIgnoreCase)){string legacyKey=CleanName(Path.GetFileNameWithoutExtension(game.Path));if(!String.IsNullOrWhiteSpace(legacyKey))artworkTitle=legacyKey;}string cover=FindDolphinArtwork(game.Path,artworkTitle);if(String.IsNullOrWhiteSpace(cover))cover=FindEmulatorArtwork(game.Path,artworkTitle);if(String.IsNullOrWhiteSpace(cover))cover=TryDownloadConsoleCover(game);'
if(-not $text.Contains($old)){throw 'Wii artwork-alias transform could not find the background artwork refresh loop.'}
$text=$text.Replace($old,$new)
Set-Content -LiteralPath $ConsolePlatformsPath -Value $text -Encoding UTF8
