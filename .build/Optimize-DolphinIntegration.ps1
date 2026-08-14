param(
    [Parameter(Mandatory=$true)][string]$ConsolePlatformsPath
)

Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
if(-not(Test-Path -LiteralPath $ConsolePlatformsPath -PathType Leaf)){throw "Dolphin integration source missing: $ConsolePlatformsPath"}
$text=Get-Content -Raw -LiteralPath $ConsolePlatformsPath -Encoding UTF8
if($text -match 'HUYMAIER_DOLPHIN_INTEGRATION_V1'){return}
if($text -notmatch 'HUYMAIER_NINTENDO_DISPLAY_NAME_V1'){throw 'Dolphin integration must run after Nintendo display-name transformation.'}

$wiiClassOld=@'
    internal sealed class WiiSaveEntry
    {
        internal string Name;
        internal string TitleId;
        internal string Path;
        internal long Size;
        internal DateTime Modified;
    }
'@
$wiiClassNew=@'
    internal sealed class WiiSaveEntry
    {
        internal string Name;
        internal string TitleId;
        internal string GameCode;
        internal string Path;
        internal string Cover;
        internal string Description;
        internal long Size;
        internal DateTime Modified;
    }
'@
if(-not $text.Contains($wiiClassOld)){throw 'Dolphin integration could not find WiiSaveEntry class.'}
$text=$text.Replace($wiiClassOld,$wiiClassNew)

$coverNeedle='        private string FindCover(string gamePath)'
if(-not $text.Contains($coverNeedle)){throw 'Dolphin integration could not find FindCover insertion point.'}
$coverHelpers=@'
        // HUYMAIER_DOLPHIN_INTEGRATION_V1
        private static void AddDolphinRoot(List<string> roots, string value)
        {
            if (String.IsNullOrWhiteSpace(value)) return;
            try
            {
                string candidate = value;
                if (File.Exists(candidate)) candidate = Path.GetDirectoryName(candidate);
                if (!Directory.Exists(candidate)) return;
                string leaf = Path.GetFileName(candidate.TrimEnd(Path.DirectorySeparatorChar));
                if (leaf.Equals("Wii", StringComparison.OrdinalIgnoreCase) || leaf.Equals("GC", StringComparison.OrdinalIgnoreCase) || leaf.Equals("Config", StringComparison.OrdinalIgnoreCase) || leaf.Equals("Cache", StringComparison.OrdinalIgnoreCase))
                {
                    DirectoryInfo parent = Directory.GetParent(candidate);
                    if (parent != null && Directory.Exists(parent.FullName)) candidate = parent.FullName;
                }
                if (!roots.Contains(candidate, StringComparer.OrdinalIgnoreCase)) roots.Add(candidate);
            }
            catch { }
        }

        private List<string> GetDolphinUserRoots()
        {
            List<string> roots = new List<string>();
            AddDolphinRoot(roots, settings.emulatorDataPath);
            List<string> exeRoots = new List<string>();
            foreach (string executable in new string[] { settings.emulatorPath, settings.fallbackEmulatorPath })
            {
                try
                {
                    if (String.IsNullOrWhiteSpace(executable) || !File.Exists(executable)) continue;
                    string exeRoot = Path.GetDirectoryName(executable);
                    if (!exeRoots.Contains(exeRoot, StringComparer.OrdinalIgnoreCase)) exeRoots.Add(exeRoot);
                    if (File.Exists(Path.Combine(exeRoot, "portable.txt"))) AddDolphinRoot(roots, Path.Combine(exeRoot, "User"));
                }
                catch { }
            }
            try
            {
                using (Microsoft.Win32.RegistryKey key = Microsoft.Win32.Registry.CurrentUser.OpenSubKey(@"Software\Dolphin Emulator"))
                {
                    if (key != null)
                    {
                        object custom = key.GetValue("UserConfigPath");
                        if (custom != null) AddDolphinRoot(roots, Convert.ToString(custom, CultureInfo.InvariantCulture));
                        bool local = false;
                        object localValue = key.GetValue("LocalUserConfig");
                        if (localValue != null) { try { local = Convert.ToInt32(localValue, CultureInfo.InvariantCulture) != 0; } catch { } }
                        if (local) foreach (string exeRoot in exeRoots) AddDolphinRoot(roots, Path.Combine(exeRoot, "User"));
                    }
                }
            }
            catch { }
            try { AddDolphinRoot(roots, Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments), "Dolphin Emulator")); } catch { }
            try { AddDolphinRoot(roots, Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "Dolphin Emulator")); } catch { }
            foreach (string exeRoot in exeRoots) AddDolphinRoot(roots, Path.Combine(exeRoot, "User"));
            return roots;
        }

        private static string FindNintendoIdInText(string value)
        {
            if (String.IsNullOrWhiteSpace(value)) return String.Empty;
            System.Text.RegularExpressions.Match match = System.Text.RegularExpressions.Regex.Match(value, @"(?i)(?<![A-Z0-9])([A-Z0-9]{6})(?![A-Z0-9])");
            return match.Success ? match.Groups[1].Value.ToUpperInvariant() : String.Empty;
        }

        private static string ReadNintendoGameId(string path)
        {
            try
            {
                string id = FindNintendoIdInText(Path.GetFileNameWithoutExtension(path));
                if (!String.IsNullOrWhiteSpace(id)) return id;
                DirectoryInfo parent = Directory.GetParent(path);
                if (parent != null) { id = FindNintendoIdInText(parent.Name); if (!String.IsNullOrWhiteSpace(id)) return id; }
                string extension = Path.GetExtension(path) ?? String.Empty;
                using (FileStream stream = File.Open(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete))
                {
                    if (extension.Equals(".iso", StringComparison.OrdinalIgnoreCase) || extension.Equals(".gcm", StringComparison.OrdinalIgnoreCase))
                    {
                        if (stream.Length < 6) return String.Empty;
                        byte[] raw = new byte[6]; if (stream.Read(raw, 0, raw.Length) != raw.Length) return String.Empty;
                        string gameId = Encoding.ASCII.GetString(raw).Trim(); return LooksLikeNintendoDiscId(gameId) ? gameId.ToUpperInvariant() : String.Empty;
                    }
                    if (extension.Equals(".wbfs", StringComparison.OrdinalIgnoreCase) && stream.Length >= 32)
                    {
                        byte[] header = new byte[12]; if (stream.Read(header, 0, header.Length) != header.Length) return String.Empty;
                        if (header[0] != (byte)'W' || header[1] != (byte)'B' || header[2] != (byte)'F' || header[3] != (byte)'S') return String.Empty;
                        int shift = header[9]; if (shift < 15 || shift > 31) return String.Empty;
                        long sectorSize = 1L << shift;
                        for (int i = 0; i < 512 && stream.Position < stream.Length; i++)
                        {
                            int sector = stream.ReadByte(); if (sector <= 0) continue;
                            long offset = (long)sector * sectorSize; if (offset < 0 || offset + 6 > stream.Length) continue;
                            stream.Position = offset; byte[] raw = new byte[6]; if (stream.Read(raw, 0, raw.Length) != raw.Length) continue;
                            string gameId = Encoding.ASCII.GetString(raw).Trim(); if (LooksLikeNintendoDiscId(gameId)) return gameId.ToUpperInvariant();
                        }
                    }
                }
            }
            catch { }
            return String.Empty;
        }

        private string FindDolphinArtwork(string gamePath, string title)
        {
            if (!definition.Shell.Equals("Wii", StringComparison.OrdinalIgnoreCase) && !definition.Shell.Equals("GameCube", StringComparison.OrdinalIgnoreCase)) return String.Empty;
            try
            {
                string folder = Path.GetDirectoryName(gamePath);
                string stem = Path.GetFileNameWithoutExtension(gamePath);
                foreach (string local in new string[] { Path.Combine(folder, stem + ".cover.png"), Path.Combine(folder, "cover.png") }) if (File.Exists(local)) return local;
            }
            catch { }
            string gameId = ReadNintendoGameId(gamePath);
            if (String.IsNullOrWhiteSpace(gameId)) return String.Empty;
            foreach (string root in GetDolphinUserRoots())
            {
                foreach (string candidate in new string[] { Path.Combine(root, "GameCovers", gameId + ".png"), Path.Combine(root, "Cache", "GameCovers", gameId + ".png") })
                {
                    try { if (File.Exists(candidate)) return candidate; } catch { }
                }
            }
            return String.Empty;
        }

        private string FindDolphinArtworkBySaveCode(string code)
        {
            if (String.IsNullOrWhiteSpace(code)) return String.Empty;
            string prefix = code.ToUpperInvariant();
            foreach (string root in GetDolphinUserRoots())
            {
                foreach (string folder in new string[] { Path.Combine(root, "GameCovers"), Path.Combine(root, "Cache", "GameCovers") })
                {
                    if (!Directory.Exists(folder)) continue;
                    try
                    {
                        string match = Directory.EnumerateFiles(folder, prefix + "*.png", SearchOption.TopDirectoryOnly).FirstOrDefault();
                        if (!String.IsNullOrWhiteSpace(match)) return match;
                    }
                    catch { }
                }
            }
            return String.Empty;
        }

'@
$text=$text.Replace($coverNeedle,$coverHelpers+$coverNeedle)
$findCoverOld=@'
        private string FindCover(string gamePath)
        {
            string title=CleanName(Path.GetFileNameWithoutExtension(gamePath));
            string emulator=FindEmulatorArtwork(gamePath,title);if(!String.IsNullOrWhiteSpace(emulator))return emulator;
'@
$findCoverNew=@'
        private string FindCover(string gamePath)
        {
            string title=CleanName(Path.GetFileNameWithoutExtension(gamePath));
            string dolphin=FindDolphinArtwork(gamePath,title);if(!String.IsNullOrWhiteSpace(dolphin))return dolphin;
            string emulator=FindEmulatorArtwork(gamePath,title);if(!String.IsNullOrWhiteSpace(emulator))return emulator;
'@
if(-not $text.Contains($findCoverOld)){throw 'Dolphin integration could not patch FindCover precedence.'}
$text=$text.Replace($findCoverOld,$findCoverNew)

$renderStart=$text.IndexOf('        private void RenderWiiDataManagement(List<string> roots)',[StringComparison]::Ordinal)
$renderEnd=$text.IndexOf('        private static ushort ReadBe16', $renderStart,[StringComparison]::Ordinal)
if($renderStart -lt 0 -or $renderEnd -lt 0){throw 'Dolphin integration could not locate Wii data-management block.'}
$newRender=@'
        private static string ReadUtf16BeFixed(byte[] data, int offset, int charCount)
        {
            try
            {
                if (data == null || offset < 0 || charCount <= 0 || offset + charCount * 2 > data.Length) return String.Empty;
                StringBuilder builder = new StringBuilder();
                for (int i = 0; i < charCount; i++)
                {
                    ushort value = (ushort)((data[offset + i * 2] << 8) | data[offset + i * 2 + 1]);
                    if (value == 0) break;
                    if (value >= 0x20 && value != 0xFFFF) builder.Append((char)value);
                }
                return builder.ToString().Trim();
            }
            catch { return String.Empty; }
        }

        private static string[] ReadWiiSaveBannerMetadata(string dataPath)
        {
            string[] result = new string[] { String.Empty, String.Empty };
            try
            {
                string path = Path.Combine(dataPath, "banner.bin");
                if (!File.Exists(path)) return result;
                byte[] data = File.ReadAllBytes(path);
                if (data.Length < 0xA0 || data[0] != (byte)'W' || data[1] != (byte)'I' || data[2] != (byte)'B' || data[3] != (byte)'N') return result;
                result[0] = ReadUtf16BeFixed(data, 0x20, 32);
                result[1] = ReadUtf16BeFixed(data, 0x60, 32);
            }
            catch { }
            return result;
        }

        private ConsolePlatformGame FindWiiLibraryGame(string saveCode)
        {
            if (String.IsNullOrWhiteSpace(saveCode)) return null;
            string prefix = saveCode.ToUpperInvariant();
            foreach (ConsolePlatformGame game in games)
            {
                string gameId = ReadNintendoGameId(game.Path);
                if (!String.IsNullOrWhiteSpace(gameId) && gameId.StartsWith(prefix, StringComparison.OrdinalIgnoreCase)) return game;
            }
            return null;
        }

        private Button CreateWiiSaveCard(WiiSaveEntry save, Action invoke)
        {
            Button button = new Button { Width = 350, Height = 156, Margin = new Thickness(10), Padding = new Thickness(10), Background = Brushes.White, BorderBrush = new SolidColorBrush(Color.FromRgb(112, 197, 221)), BorderThickness = new Thickness(3), RenderTransformOrigin = new Point(0.5, 0.5) };
            Grid grid = new Grid(); grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(118) }); grid.ColumnDefinitions.Add(new ColumnDefinition());
            Border art = new Border { Width = 104, Height = 104, CornerRadius = new CornerRadius(12), Margin = new Thickness(2), Background = new SolidColorBrush(Color.FromRgb(225, 241, 246)), BorderBrush = new SolidColorBrush(Color.FromRgb(166, 214, 227)), BorderThickness = new Thickness(1), VerticalAlignment = VerticalAlignment.Center };
            if (!String.IsNullOrWhiteSpace(save.Cover) && File.Exists(save.Cover)) { try { art.Child = new Image { Source = LoadBitmap(save.Cover), Stretch = Stretch.UniformToFill }; } catch { } }
            if (art.Child == null) art.Child = new TextBlock { Text = String.IsNullOrWhiteSpace(save.GameCode) ? "Wii" : save.GameCode, FontSize = 19, FontWeight = FontWeights.Bold, Foreground = new SolidColorBrush(Color.FromRgb(56, 149, 184)), HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center, TextAlignment = TextAlignment.Center };
            grid.Children.Add(art);
            StackPanel info = new StackPanel { Margin = new Thickness(10, 8, 4, 4), VerticalAlignment = VerticalAlignment.Center }; Grid.SetColumn(info, 1);
            info.Children.Add(new TextBlock { Text = save.Name, FontSize = 17, FontWeight = FontWeights.Bold, Foreground = new SolidColorBrush(Color.FromRgb(55, 72, 80)), TextWrapping = TextWrapping.Wrap, MaxHeight = 45 });
            if (!String.IsNullOrWhiteSpace(save.Description)) info.Children.Add(new TextBlock { Text = save.Description, FontSize = 10, Foreground = new SolidColorBrush(Color.FromRgb(96, 112, 119)), TextTrimming = TextTrimming.CharacterEllipsis, Margin = new Thickness(0, 3, 0, 0) });
            info.Children.Add(new TextBlock { Text = (String.IsNullOrWhiteSpace(save.GameCode) ? save.TitleId : save.GameCode + "  •  " + save.TitleId) + "  •  " + FormatBytes(save.Size), FontSize = 10, Foreground = new SolidColorBrush(Color.FromRgb(70, 151, 178)), Margin = new Thickness(0, 5, 0, 0), TextTrimming = TextTrimming.CharacterEllipsis });
            info.Children.Add(new TextBlock { Text = "Modified " + save.Modified.ToString("g", CultureInfo.CurrentCulture) + "  •  A  Back Up", FontSize = 9, Foreground = new SolidColorBrush(Color.FromRgb(113, 125, 130)), Margin = new Thickness(0, 4, 0, 0) });
            grid.Children.Add(info); button.Content = grid; button.Click += delegate { invoke(); }; return button;
        }

        private void RenderWiiDataManagement(List<string> roots)
        {
            titleText.Text = "Save Data"; subtitleText.Text = "Wii System Memory  •  game-by-game save manager";
            List<WiiSaveEntry> saves = ScanWiiSaves(roots);
            long totalSize = 0; foreach (WiiSaveEntry entry in saves) totalSize += Math.Max(0, entry.Size);
            Grid body = new Grid { Margin = new Thickness(54, 6, 54, 24) }; body.RowDefinitions.Add(new RowDefinition { Height = new GridLength(72) }); body.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) }); contentHost.Children.Add(body);
            Border heading = new Border { Background = new SolidColorBrush(Color.FromRgb(241, 247, 249)), BorderBrush = new SolidColorBrush(Color.FromRgb(96, 194, 220)), BorderThickness = new Thickness(2), CornerRadius = new CornerRadius(18), Padding = new Thickness(20, 10, 20, 10), Child = new TextBlock { Text = saves.Count.ToString(CultureInfo.InvariantCulture) + " saved title(s)  •  " + FormatBytes(totalSize) + " used", FontSize = 21, Foreground = new SolidColorBrush(Color.FromRgb(72, 91, 98)), HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center } }; body.Children.Add(heading);
            WrapPanel cards = new WrapPanel { HorizontalAlignment = HorizontalAlignment.Center, Margin = new Thickness(0, 12, 0, 0) };
            foreach (WiiSaveEntry save in saves)
            {
                WiiSaveEntry captured = save; Button tile = CreateWiiSaveCard(save, delegate { BackupNativeSavePath(captured.Path, "Wii-" + captured.TitleId); }); cards.Children.Add(tile); actions.Add(new ConsolePlatformAction { Button = tile, Invoke = delegate { BackupNativeSavePath(captured.Path, "Wii-" + captured.TitleId); }, Name = save.Name });
            }
            if (saves.Count == 0) cards.Children.Add(new Border { Width = 350, Height = 156, Margin = new Thickness(12), Background = Brushes.White, BorderBrush = new SolidColorBrush(Color.FromRgb(135, 203, 221)), BorderThickness = new Thickness(3), Child = new TextBlock { Text = "No Wii save data detected", FontSize = 18, Foreground = new SolidColorBrush(Color.FromRgb(82, 101, 109)), HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center } });
            Button backupAll = CreateChannelTile("Back Up All", "Create a recoverable copy of Wii system-memory saves", BackupSaves); cards.Children.Add(backupAll); actions.Add(new ConsolePlatformAction { Button = backupAll, Invoke = BackupSaves, Name = "Back Up All" });
            ScrollViewer scroller = new ScrollViewer { VerticalScrollBarVisibility = ScrollBarVisibility.Hidden, HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled, Content = cards }; Grid.SetRow(scroller, 1); body.Children.Add(scroller);
        }

'@
$text=$text.Substring(0,$renderStart)+$newRender+$text.Substring($renderEnd)

$scanStart=$text.IndexOf('        private List<WiiSaveEntry> ScanWiiSaves(List<string> roots)',[StringComparison]::Ordinal)
$scanEnd=$text.IndexOf('        private static string DecodeWiiTitleCode', $scanStart,[StringComparison]::Ordinal)
if($scanStart -lt 0 -or $scanEnd -lt 0){throw 'Dolphin integration could not locate Wii save scanner.'}
$newScan=@'
        private List<WiiSaveEntry> ScanWiiSaves(List<string> roots)
        {
            List<WiiSaveEntry> result = new List<WiiSaveEntry>();
            HashSet<string> seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (string rootPath in roots)
            {
                string titleRoot = Path.Combine(rootPath, "title");
                if (!Directory.Exists(titleRoot)) continue;
                string[] highDirs; try { highDirs = Directory.GetDirectories(titleRoot); } catch { continue; }
                foreach (string high in highDirs)
                {
                    string[] lowDirs; try { lowDirs = Directory.GetDirectories(high); } catch { continue; }
                    foreach (string low in lowDirs)
                    {
                        string data = Path.Combine(low, "data"); if (!Directory.Exists(data) || !seen.Add(data)) continue;
                        long size = GetPathSize(data); if (size <= 0) continue;
                        string lowName = Path.GetFileName(low); string titleId = (Path.GetFileName(high) + lowName).ToUpperInvariant();
                        string code = DecodeWiiTitleCode(lowName).ToUpperInvariant();
                        string[] banner = ReadWiiSaveBannerMetadata(data);
                        ConsolePlatformGame game = FindWiiLibraryGame(code);
                        string display = !String.IsNullOrWhiteSpace(banner[0]) ? banner[0] : (game != null && !String.IsNullOrWhiteSpace(game.Name) ? game.Name : (String.IsNullOrWhiteSpace(code) ? "Wii Save " + lowName.ToUpperInvariant() : "Wii Save (" + code + ")"));
                        string cover = game != null && !String.IsNullOrWhiteSpace(game.Cover) && File.Exists(game.Cover) ? game.Cover : FindDolphinArtworkBySaveCode(code);
                        DateTime modified = Directory.GetLastWriteTime(data);
                        result.Add(new WiiSaveEntry { Name = display, TitleId = titleId, GameCode = code, Path = data, Cover = cover, Description = banner[1], Size = size, Modified = modified });
                    }
                }
            }
            return result.OrderBy(delegate(WiiSaveEntry entry) { return entry.Name; }, StringComparer.CurrentCultureIgnoreCase).ToList();
        }

'@
$text=$text.Substring(0,$scanStart)+$newScan+$text.Substring($scanEnd)
Set-Content -LiteralPath $ConsolePlatformsPath -Value $text -Encoding UTF8
