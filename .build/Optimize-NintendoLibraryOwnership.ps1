param(
    [Parameter(Mandatory=$true)][string]$NativePath
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'

if(-not(Test-Path -LiteralPath $NativePath -PathType Leaf)){throw "Nintendo library optimizer could not find $NativePath"}
$text=[IO.File]::ReadAllText($NativePath,[Text.Encoding]::UTF8)

$old=@'
        private void RefreshLibrary(bool showNotice)
        {
            if (definition.Shell == "PS4" || definition.Shell == "Vita") { RefreshModernPlayStationLibrary(showNotice); return; }
            List<ConsolePlatformGame> found = new List<ConsolePlatformGame>();
            HashSet<string> seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (string folder in settings.gameFolders.ToArray())
            {
                if (!Directory.Exists(folder)) continue;
                try
                {
                    foreach (string path in Directory.EnumerateFiles(folder, "*.*", SearchOption.AllDirectories))
                    {
                        string extension = Path.GetExtension(path);
                        if (!definition.GameExtensions.Contains(extension, StringComparer.OrdinalIgnoreCase)) continue;
                        if (!seen.Add(path)) continue;
                        found.Add(new ConsolePlatformGame { Name = CleanName(Path.GetFileNameWithoutExtension(path)), Path = path, Cover = FindCover(path) });
                    }
                }
                catch { }
            }
            games = found.OrderBy(delegate(ConsolePlatformGame g) { return g.Name; }, StringComparer.CurrentCultureIgnoreCase).ToList();
            SaveCachedGames();
            selected = 0;
            if (showNotice) ShowNotice("Library refreshed — " + games.Count.ToString(CultureInfo.InvariantCulture) + " games");
            RenderPage();
            QueueConsoleArtworkRefresh();
        }
'@

$new=@'
        private bool IsNintendoLibraryOwnedPath(string path)
        {
            if (definition.Shell != "Wii" && definition.Shell != "GameCube") return true;
            if (String.IsNullOrWhiteSpace(path)) return false;
            try
            {
                string full = Path.GetFullPath(path);
                string[] segments = full.Split(new char[] { Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar }, StringSplitOptions.RemoveEmptyEntries);
                foreach (string raw in segments)
                {
                    string segment = (raw ?? String.Empty).Trim();
                    if (definition.Shell == "Wii" &&
                        (String.Equals(segment, "GameCube", StringComparison.OrdinalIgnoreCase) ||
                         String.Equals(segment, "Nintendo GameCube", StringComparison.OrdinalIgnoreCase) ||
                         String.Equals(segment, "GCN", StringComparison.OrdinalIgnoreCase))) return false;
                    if (definition.Shell == "GameCube" &&
                        (String.Equals(segment, "Wii", StringComparison.OrdinalIgnoreCase) ||
                         String.Equals(segment, "Nintendo Wii", StringComparison.OrdinalIgnoreCase))) return false;
                }

                string extension = Path.GetExtension(full);
                if (!String.Equals(extension, ".iso", StringComparison.OrdinalIgnoreCase)) return true;
                return IsNintendoRawDiscForCurrentShell(full);
            }
            catch { return false; }
        }

        private bool IsNintendoRawDiscForCurrentShell(string path)
        {
            if (definition.Shell != "Wii" && definition.Shell != "GameCube") return true;
            try
            {
                using (FileStream stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete))
                {
                    if (stream.Length < 0x20) return false;
                    byte[] header = new byte[0x20];
                    int offset = 0;
                    while (offset < header.Length)
                    {
                        int read = stream.Read(header, offset, header.Length - offset);
                        if (read <= 0) break;
                        offset += read;
                    }
                    if (offset < header.Length) return false;
                    bool wii = header[0x18] == 0x5D && header[0x19] == 0x1C && header[0x1A] == 0x9E && header[0x1B] == 0xA3;
                    bool gameCube = header[0x1C] == 0xC2 && header[0x1D] == 0x33 && header[0x1E] == 0x9F && header[0x1F] == 0x3D;
                    return definition.Shell == "Wii" ? wii : gameCube;
                }
            }
            catch { return false; }
        }

        private void RefreshLibrary(bool showNotice)
        {
            if (definition.Shell == "PS4" || definition.Shell == "Vita") { RefreshModernPlayStationLibrary(showNotice); return; }
            List<ConsolePlatformGame> found = new List<ConsolePlatformGame>();
            HashSet<string> seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (string folder in settings.gameFolders.ToArray())
            {
                if (!Directory.Exists(folder)) continue;
                try
                {
                    foreach (string path in Directory.EnumerateFiles(folder, "*.*", SearchOption.AllDirectories))
                    {
                        string extension = Path.GetExtension(path);
                        if (!definition.GameExtensions.Contains(extension, StringComparer.OrdinalIgnoreCase)) continue;
                        if (!IsNintendoLibraryOwnedPath(path)) continue;
                        if (!seen.Add(path)) continue;
                        found.Add(new ConsolePlatformGame { Name = CleanName(Path.GetFileNameWithoutExtension(path)), Path = path, Cover = FindCover(path) });
                    }
                }
                catch { }
            }
            games = found.OrderBy(delegate(ConsolePlatformGame g) { return g.Name; }, StringComparer.CurrentCultureIgnoreCase).ToList();
            SaveCachedGames();
            selected = 0;
            if (showNotice) ShowNotice("Library refreshed — " + games.Count.ToString(CultureInfo.InvariantCulture) + " games");
            RenderPage();
            QueueConsoleArtworkRefresh();
        }
'@

$first=$text.IndexOf($old,[StringComparison]::Ordinal)
if($first -lt 0){throw 'Nintendo library optimizer could not find the expected RefreshLibrary block.'}
if($text.IndexOf($old,$first+$old.Length,[StringComparison]::Ordinal) -ge 0){throw 'Nintendo library optimizer found duplicate RefreshLibrary blocks.'}
$text=$text.Substring(0,$first)+$new+$text.Substring($first+$old.Length)
$bom=New-Object Text.UTF8Encoding($true)
[IO.File]::WriteAllText($NativePath,$text,$bom)
Write-Host 'Applied Wii/GameCube native visible-library ownership filtering.'