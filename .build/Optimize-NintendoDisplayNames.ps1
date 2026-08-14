param(
    [Parameter(Mandatory=$true)][string]$ConsolePlatformsPath
)

Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
if(-not(Test-Path -LiteralPath $ConsolePlatformsPath -PathType Leaf)){throw "Console platform source missing: $ConsolePlatformsPath"}
$text=Get-Content -Raw -LiteralPath $ConsolePlatformsPath -Encoding UTF8
if($text -match 'HUYMAIER_NINTENDO_DISPLAY_NAME_V1'){return}

$needle='        private void QueueLibraryRefresh()'
if(-not $text.Contains($needle)){throw 'Nintendo display-name transform could not find QueueLibraryRefresh insertion point.'}
$helper=@'
        // HUYMAIER_NINTENDO_DISPLAY_NAME_V1
        private static bool LooksLikeNintendoDiscId(string value)
        {
            return !string.IsNullOrWhiteSpace(value) && System.Text.RegularExpressions.Regex.IsMatch(value.Trim(), "^[A-Za-z0-9]{6}$");
        }

        private static string CleanNintendoContainerName(string value)
        {
            if (string.IsNullOrWhiteSpace(value)) return string.Empty;
            string cleaned = System.Text.RegularExpressions.Regex.Replace(value.Trim(), @"\s*[\[\(][A-Za-z0-9]{6}[\]\)]\s*$", string.Empty).Trim();
            return cleaned;
        }

        private static string ReadNintendoAsciiTitle(Stream stream, long discOffset)
        {
            try
            {
                if (stream == null || !stream.CanRead || discOffset < 0 || stream.Length < discOffset + 0x80) return string.Empty;
                stream.Position = discOffset + 0x20;
                byte[] titleBytes = new byte[0x60];
                int read = stream.Read(titleBytes, 0, titleBytes.Length);
                if (read <= 0) return string.Empty;
                string title = Encoding.ASCII.GetString(titleBytes, 0, read).Trim('\0', ' ', '\t', '\r', '\n');
                title = System.Text.RegularExpressions.Regex.Replace(title, @"[\x00-\x1F\x7F]+", " ");
                title = System.Text.RegularExpressions.Regex.Replace(title, @"\s{2,}", " ").Trim();
                if (title.Length < 2 || LooksLikeNintendoDiscId(title)) return string.Empty;
                return title;
            }
            catch { return string.Empty; }
        }

        private static string ReadNintendoDiscTitle(string path)
        {
            try
            {
                string extension = Path.GetExtension(path) ?? string.Empty;
                using (FileStream stream = File.Open(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete))
                {
                    if (extension.Equals(".iso", StringComparison.OrdinalIgnoreCase) || extension.Equals(".gcm", StringComparison.OrdinalIgnoreCase))
                        return ReadNintendoAsciiTitle(stream, 0);

                    if (extension.Equals(".wbfs", StringComparison.OrdinalIgnoreCase) && stream.Length >= 32)
                    {
                        byte[] header = new byte[12];
                        if (stream.Read(header, 0, header.Length) != header.Length) return string.Empty;
                        if (header[0] != (byte)'W' || header[1] != (byte)'B' || header[2] != (byte)'F' || header[3] != (byte)'S') return string.Empty;
                        int wbfsSectorShift = header[9];
                        if (wbfsSectorShift < 15 || wbfsSectorShift > 31) return string.Empty;
                        long wbfsSectorSize = 1L << wbfsSectorShift;
                        // The WBFS disc table begins at byte 12.  The entry stores
                        // the WBFS-sector index containing the Wii disc header.
                        for (int i = 0; i < 512 && stream.Position < stream.Length; i++)
                        {
                            int sectorIndex = stream.ReadByte();
                            if (sectorIndex <= 0) continue;
                            long discOffset = (long)sectorIndex * wbfsSectorSize;
                            string title = ReadNintendoAsciiTitle(stream, discOffset);
                            if (!string.IsNullOrWhiteSpace(title)) return title;
                        }
                    }
                }
            }
            catch { }
            return string.Empty;
        }

        private string ResolveLibraryDisplayName(string path)
        {
            string fileName = CleanName(Path.GetFileNameWithoutExtension(path));
            bool nintendoDisc = definition.Shell.Equals("Wii", StringComparison.OrdinalIgnoreCase) ||
                                definition.Shell.Equals("GameCube", StringComparison.OrdinalIgnoreCase);
            if (!nintendoDisc || !LooksLikeNintendoDiscId(fileName)) return fileName;

            try
            {
                DirectoryInfo parent = Directory.GetParent(path);
                if (parent != null)
                {
                    string folderName = CleanNintendoContainerName(parent.Name);
                    if (!string.IsNullOrWhiteSpace(folderName) && !LooksLikeNintendoDiscId(folderName) &&
                        !folderName.Equals("Wii", StringComparison.OrdinalIgnoreCase) &&
                        !folderName.Equals("GameCube", StringComparison.OrdinalIgnoreCase) &&
                        !folderName.Equals("ROMs", StringComparison.OrdinalIgnoreCase))
                        return CleanName(folderName);
                }
            }
            catch { }

            string embedded = ReadNintendoDiscTitle(path);
            if (!string.IsNullOrWhiteSpace(embedded)) return embedded;

            string platform = definition.Shell.Equals("GameCube", StringComparison.OrdinalIgnoreCase) ? "GameCube" : "Wii";
            return platform + " Game (" + fileName + ")";
        }

'@
$text=$text.Replace($needle,$helper+$needle)
$old='Name = CleanName(Path.GetFileNameWithoutExtension(path)),'
$count=([regex]::Matches($text,[regex]::Escape($old))).Count
if($count -lt 2){throw "Nintendo display-name transform expected both library scanners; found $count title assignments."}
$text=$text.Replace($old,'Name = ResolveLibraryDisplayName(path),')
Set-Content -LiteralPath $ConsolePlatformsPath -Value $text -Encoding UTF8
