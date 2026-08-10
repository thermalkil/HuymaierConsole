from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
path=ROOT/'Native'/'HuymaierConsole.ConsolePlatforms.cs'
text=path.read_text(encoding='utf-8-sig')

old='''        private void RenderWave1Storage()
        {
            titleText.Text=definition.Shell=="Dreamcast"?"File":(definition.Shell=="Saturn"?"Memory Manager":"Saved Data");subtitleText.Text="Native storage view for "+definition.DisplayName;StackPanel panel=new StackPanel{Margin=new Thickness(36,8,36,24)};contentHost.Children.Add(new ScrollViewer{VerticalScrollBarVisibility=ScrollBarVisibility.Hidden,Content=panel});List<string> roots=FindSaveRoots();if(roots.Count==0)AddRoundedStorage(panel,"No saved data detected","Configure the emulator data path in system settings",definition.Accent,delegate{dashboardSubpage="settings";selected=0;RenderPage();});else foreach(string rootPath in roots)AddRoundedStorage(panel,Path.GetFileName(rootPath.TrimEnd(Path.DirectorySeparatorChar)),rootPath,definition.Accent,delegate{BackupSaves();});
        }
'''
new='''        private void RenderWave1Storage()
        {
            if (definition.Shell == "PSP") { RenderPspSavedDataUtility(); return; }
            if (definition.Shell == "Dreamcast") { RenderDreamcastVmuManager(); return; }
            if (definition.Shell == "Saturn") { RenderSaturnMemoryManager(); return; }
            if (definition.Shell == "NDS") { RenderDsSavedData(false); return; }
            if (definition.Shell == "DSI") { RenderDsSavedData(true); return; }
            if (definition.Shell == "3DS") { Render3dsDataManagement(); return; }
            titleText.Text="Saved Data"; subtitleText.Text="Native storage view for "+definition.DisplayName;
            StackPanel panel=new StackPanel{Margin=new Thickness(36,8,36,24)};contentHost.Children.Add(new ScrollViewer{VerticalScrollBarVisibility=ScrollBarVisibility.Hidden,Content=panel});
            List<string> roots=FindSaveRoots();if(roots.Count==0)AddRoundedStorage(panel,"No saved data detected","Configure the emulator data path in system settings",definition.Accent,delegate{dashboardSubpage="settings";selected=0;RenderPage();});else foreach(string rootPath in roots){string captured=rootPath;AddRoundedStorage(panel,Path.GetFileName(rootPath.TrimEnd(Path.DirectorySeparatorChar)),rootPath,definition.Accent,delegate{BackupNativeSavePath(captured,definition.Id+"-SavedData");});}
        }
'''
if old not in text:
    if 'private void RenderPspSavedDataUtility()' in text:
        print('Wave 1 native storage UI already materialized')
        raise SystemExit(0)
    raise SystemExit('RenderWave1Storage replacement anchor missing')
text=text.replace(old,new,1)

methods=r'''
        private List<string> GetUniqueExistingPaths(IEnumerable<string> paths)
        {
            List<string> result = new List<string>();
            foreach (string value in paths ?? Enumerable.Empty<string>())
            {
                if (String.IsNullOrWhiteSpace(value)) continue;
                string pathValue = value;
                try { pathValue = Path.GetFullPath(Environment.ExpandEnvironmentVariables(value)); } catch { }
                if ((!File.Exists(pathValue) && !Directory.Exists(pathValue)) || result.Contains(pathValue, StringComparer.OrdinalIgnoreCase)) continue;
                result.Add(pathValue);
            }
            return result;
        }

        private static DateTime GetPathModifiedUtcSafe(string pathValue)
        {
            try { return File.Exists(pathValue) ? File.GetLastWriteTime(pathValue) : Directory.GetLastWriteTime(pathValue); } catch { return DateTime.MinValue; }
        }

        private static string ReadPspSfoString(string sfoPath, string wantedKey)
        {
            if (String.IsNullOrWhiteSpace(sfoPath) || !File.Exists(sfoPath) || String.IsNullOrWhiteSpace(wantedKey)) return String.Empty;
            try
            {
                byte[] data = File.ReadAllBytes(sfoPath); if (data.Length < 20) return String.Empty;
                Func<int, ushort> u16 = delegate(int offset) { return (ushort)(data[offset] | (data[offset + 1] << 8)); };
                Func<int, uint> u32 = delegate(int offset) { return (uint)(data[offset] | (data[offset + 1] << 8) | (data[offset + 2] << 16) | (data[offset + 3] << 24)); };
                if (u32(0) != 0x46535000) return String.Empty;
                int keyTable = (int)u32(8); int valueTable = (int)u32(12); int count = (int)u32(16);
                if (keyTable < 20 || valueTable < keyTable || count < 0 || count > 512) return String.Empty;
                for (int i = 0; i < count; i++)
                {
                    int entry = 20 + i * 16; if (entry + 16 > data.Length) break;
                    int keyOffset = keyTable + u16(entry); int length = (int)u32(entry + 4); int valueOffset = valueTable + (int)u32(entry + 12);
                    if (keyOffset < 0 || keyOffset >= data.Length || valueOffset < 0 || valueOffset >= data.Length) continue;
                    int keyEnd = keyOffset; while (keyEnd < data.Length && data[keyEnd] != 0) keyEnd++;
                    string key = Encoding.UTF8.GetString(data, keyOffset, Math.Max(0, keyEnd - keyOffset));
                    if (!String.Equals(key, wantedKey, StringComparison.Ordinal)) continue;
                    int available = Math.Min(Math.Max(0, length), data.Length - valueOffset); if (available <= 0) return String.Empty;
                    int end = valueOffset; int limit = valueOffset + available; while (end < limit && data[end] != 0) end++;
                    return Encoding.UTF8.GetString(data, valueOffset, Math.Max(0, end - valueOffset)).Trim();
                }
            }
            catch { }
            return String.Empty;
        }

        private Button CreatePspSaveTile(string title, string subtitle, string iconPath, string detail, Action invoke)
        {
            Button button = new Button { Width = 245, Height = 150, Margin = new Thickness(9), Padding = new Thickness(0), Background = new SolidColorBrush(Color.FromArgb(86, 255, 255, 255)), BorderBrush = new SolidColorBrush(Color.FromArgb(170, 145, 218, 255)), BorderThickness = new Thickness(2), RenderTransformOrigin = new Point(0.5, 0.5) };
            Grid layout = new Grid(); layout.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(96) }); layout.ColumnDefinitions.Add(new ColumnDefinition());
            Border imageFrame = new Border { Width = 82, Height = 82, Margin = new Thickness(9), CornerRadius = new CornerRadius(6), Background = new SolidColorBrush(Color.FromArgb(70, 0, 20, 50)), VerticalAlignment = VerticalAlignment.Top };
            if (!String.IsNullOrWhiteSpace(iconPath) && File.Exists(iconPath)) { try { imageFrame.Child = new Image { Source = LoadBitmap(iconPath), Stretch = Stretch.UniformToFill }; } catch { } }
            if (imageFrame.Child == null) imageFrame.Child = new TextBlock { Text = "SAVE", FontSize = 15, FontWeight = FontWeights.Bold, Foreground = Brushes.White, HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center };
            layout.Children.Add(imageFrame);
            StackPanel info = new StackPanel { Margin = new Thickness(8, 12, 10, 8) }; Grid.SetColumn(info, 1);
            info.Children.Add(new TextBlock { Text = title, FontSize = 15, FontWeight = FontWeights.SemiBold, Foreground = Brushes.White, TextWrapping = TextWrapping.Wrap, MaxHeight = 42 });
            if (!String.IsNullOrWhiteSpace(subtitle)) info.Children.Add(new TextBlock { Text = subtitle, FontSize = 10, Foreground = new SolidColorBrush(Color.FromArgb(205, 255, 255, 255)), TextTrimming = TextTrimming.CharacterEllipsis, Margin = new Thickness(0, 4, 0, 0) });
            info.Children.Add(new TextBlock { Text = detail, FontSize = 9, Foreground = new SolidColorBrush(Color.FromArgb(165, 255, 255, 255)), TextWrapping = TextWrapping.Wrap, Margin = new Thickness(0, 4, 0, 0) });
            layout.Children.Add(info); button.Content = layout; button.Click += delegate { invoke(); }; return button;
        }

        private void RenderPspSavedDataUtility()
        {
            titleText.Text = "Saved Data Utility"; subtitleText.Text = "Memory Stick™  •  PSP saved data"; columns = 3;
            ScrollViewer scroll = new ScrollViewer { VerticalScrollBarVisibility = ScrollBarVisibility.Hidden, HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled }; WrapPanel panel = new WrapPanel { Margin = new Thickness(28, 5, 28, 24) }; scroll.Content = panel; contentHost.Children.Add(scroll);
            List<string> roots = FindSaveRoots(); List<string> saveFolders = new List<string>();
            foreach (string rootPath in roots)
            {
                string candidate = rootPath;
                if (!String.Equals(Path.GetFileName(candidate.TrimEnd(Path.DirectorySeparatorChar)), "SAVEDATA", StringComparison.OrdinalIgnoreCase))
                {
                    string nested = Path.Combine(candidate, "PSP", "SAVEDATA"); if (Directory.Exists(nested)) candidate = nested;
                }
                if (!Directory.Exists(candidate)) continue;
                try { foreach (string dir in Directory.GetDirectories(candidate)) if (!saveFolders.Contains(dir, StringComparer.OrdinalIgnoreCase)) saveFolders.Add(dir); } catch { }
            }
            saveFolders = saveFolders.OrderBy(delegate(string p) { return GetPathModifiedUtcSafe(p); }).Reverse().ToList();
            foreach (string savePath in saveFolders.Take(300))
            {
                string captured = savePath; string id = Path.GetFileName(savePath); string title = ReadPspSfoString(Path.Combine(savePath, "PARAM.SFO"), "TITLE"); string savedTitle = ReadPspSfoString(Path.Combine(savePath, "PARAM.SFO"), "SAVEDATA_TITLE");
                if (String.IsNullOrWhiteSpace(title)) title = id; string detail = FormatBytes(GetPathSize(savePath)) + "  •  " + GetPathModifiedUtcSafe(savePath).ToString("g", CultureInfo.CurrentCulture);
                Button tile = CreatePspSaveTile(title, savedTitle, Path.Combine(savePath, "ICON0.PNG"), detail, delegate { BackupNativeSavePath(captured, "PSP-" + Path.GetFileName(captured)); });
                panel.Children.Add(tile); actions.Add(new ConsolePlatformAction { Button = tile, Name = title, Invoke = delegate { BackupNativeSavePath(captured, "PSP-" + Path.GetFileName(captured)); } });
            }
            if (saveFolders.Count == 0) AddRoundedStorage(panel, "No Saved Data", "PPSSPP Memory Stick / PSP / SAVEDATA was not found. Set the PPSSPP data path in System Settings.", definition.Accent, delegate { dashboardSubpage = "settings"; selected = 0; RenderPage(); });
            else AddRoundedStorage(panel, "Back Up All Saved Data", saveFolders.Count.ToString(CultureInfo.InvariantCulture) + " save folder(s)", definition.Accent, BackupSaves);
        }

        private List<string> FindDreamcastVmuImages()
        {
            List<string> found = new List<string>();
            foreach (string rootPath in FindSaveRoots())
            {
                if (!Directory.Exists(rootPath)) continue;
                try
                {
                    foreach (string file in Directory.EnumerateFiles(rootPath, "vmu_save_*.bin", SearchOption.AllDirectories).Take(64)) if (!found.Contains(file, StringComparer.OrdinalIgnoreCase)) found.Add(file);
                }
                catch { }
            }
            return found.OrderBy(delegate(string pathValue) { return Path.GetFileName(pathValue); }, StringComparer.OrdinalIgnoreCase).ToList();
        }

        private Button CreateDreamcastVmuCard(string pathValue, Action invoke)
        {
            string name = Path.GetFileNameWithoutExtension(pathValue); string slot = name.StartsWith("vmu_save_", StringComparison.OrdinalIgnoreCase) ? name.Substring("vmu_save_".Length).ToUpperInvariant() : name.ToUpperInvariant();
            Button button = new Button { Width = 220, Height = 260, Margin = new Thickness(18), Padding = new Thickness(8), Background = Brushes.Transparent, BorderThickness = new Thickness(0), RenderTransformOrigin = new Point(0.5, 0.5) };
            Grid shell = new Grid { Background = Brushes.Transparent }; Border body = new Border { Width = 174, Height = 218, CornerRadius = new CornerRadius(18, 18, 30, 30), Background = new LinearGradientBrush(Color.FromRgb(239, 242, 244), Color.FromRgb(183, 195, 203), 90), BorderBrush = new SolidColorBrush(Color.FromRgb(93, 120, 138)), BorderThickness = new Thickness(3), HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Top };
            StackPanel stack = new StackPanel { Margin = new Thickness(14) }; stack.Children.Add(new TextBlock { Text = "VISUAL MEMORY", FontSize = 9, FontWeight = FontWeights.Bold, Foreground = new SolidColorBrush(Color.FromRgb(64, 83, 94)), HorizontalAlignment = HorizontalAlignment.Center });
            Border screen = new Border { Width = 112, Height = 72, Margin = new Thickness(0, 12, 0, 8), Background = new SolidColorBrush(Color.FromRgb(121, 153, 145)), BorderBrush = new SolidColorBrush(Color.FromRgb(44, 63, 61)), BorderThickness = new Thickness(5), Child = new TextBlock { Text = slot, FontFamily = new FontFamily("Consolas"), FontSize = 28, FontWeight = FontWeights.Bold, Foreground = new SolidColorBrush(Color.FromRgb(24, 47, 41)), HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center } }; stack.Children.Add(screen);
            stack.Children.Add(new TextBlock { Text = FormatBytes(GetPathSize(pathValue)), FontSize = 11, Foreground = new SolidColorBrush(Color.FromRgb(64, 83, 94)), HorizontalAlignment = HorizontalAlignment.Center }); stack.Children.Add(new TextBlock { Text = GetPathModifiedUtcSafe(pathValue).ToString("g", CultureInfo.CurrentCulture), FontSize = 9, Foreground = new SolidColorBrush(Color.FromRgb(83, 101, 112)), HorizontalAlignment = HorizontalAlignment.Center, Margin = new Thickness(0, 3, 0, 0) });
            body.Child = stack; shell.Children.Add(body); TextBlock hint = new TextBlock { Text = "A  Back Up VMU", FontSize = 10, Foreground = new SolidColorBrush(Color.FromRgb(55, 72, 86)), HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Bottom }; shell.Children.Add(hint); button.Content = shell; button.Click += delegate { invoke(); }; return button;
        }

        private void RenderDreamcastVmuManager()
        {
            titleText.Text = "File"; subtitleText.Text = "Visual Memory Unit manager"; columns = 4;
            ScrollViewer scroll = new ScrollViewer { VerticalScrollBarVisibility = ScrollBarVisibility.Hidden, HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled }; WrapPanel panel = new WrapPanel { Margin = new Thickness(45, 8, 45, 24) }; scroll.Content = panel; contentHost.Children.Add(scroll);
            List<string> vmus = FindDreamcastVmuImages(); foreach (string pathValue in vmus) { string captured = pathValue; Button card = CreateDreamcastVmuCard(pathValue, delegate { BackupNativeSavePath(captured, "Dreamcast-" + Path.GetFileNameWithoutExtension(captured)); }); panel.Children.Add(card); actions.Add(new ConsolePlatformAction { Button = card, Name = Path.GetFileNameWithoutExtension(pathValue), Invoke = delegate { BackupNativeSavePath(captured, "Dreamcast-" + Path.GetFileNameWithoutExtension(captured)); } }); }
            if (vmus.Count == 0) AddRoundedStorage(panel, "No VMUs Detected", "Flycast VMU images (vmu_save_*.bin) were not found. Set the Flycast data path in Settings or run a Dreamcast game once.", Color.FromRgb(74,190,148), delegate { dashboardSubpage = "settings"; selected = 0; RenderPage(); });
            else AddRoundedStorage(panel, "Back Up All VMUs", vmus.Count.ToString(CultureInfo.InvariantCulture) + " VMU image(s)", Color.FromRgb(74,190,148), BackupSaves);
        }

        private void RenderSaturnMemoryManager()
        {
            titleText.Text = "Memory Manager"; subtitleText.Text = "Internal backup memory and cartridge save files"; columns = 2;
            StackPanel panel = new StackPanel { Margin = new Thickness(100, 8, 100, 28) }; contentHost.Children.Add(new ScrollViewer { VerticalScrollBarVisibility = ScrollBarVisibility.Hidden, Content = panel });
            List<string> saves = new List<string>(); foreach (string rootPath in FindSaveRoots()) { if (!Directory.Exists(rootPath)) continue; try { foreach (string file in Directory.EnumerateFiles(rootPath, "*", SearchOption.TopDirectoryOnly)) { string ext = Path.GetExtension(file).ToLowerInvariant(); if (ext == ".bkr" || ext == ".bcr" || ext == ".sav" || ext == ".srm" || ext == ".nv" || ext == ".ram") if (!saves.Contains(file, StringComparer.OrdinalIgnoreCase)) saves.Add(file); } } catch { } }
            saves = saves.OrderBy(delegate(string pathValue) { return Path.GetFileName(pathValue); }, StringComparer.OrdinalIgnoreCase).ToList();
            foreach (string file in saves) { string captured = file; string ext = Path.GetExtension(file).TrimStart('.').ToUpperInvariant(); string title = Path.GetFileNameWithoutExtension(file); string detail = ext + " BACKUP MEMORY  •  " + FormatBytes(GetPathSize(file)) + "  •  " + GetPathModifiedUtcSafe(file).ToString("g", CultureInfo.CurrentCulture); AddRoundedStorage(panel, title, detail, Color.FromRgb(239,67,129), delegate { BackupNativeSavePath(captured, "Saturn-" + Path.GetFileNameWithoutExtension(captured)); }); }
            if (saves.Count == 0) AddRoundedStorage(panel, "No Backup Memory Found", "Mednafen's sav directory has no Saturn nonvolatile save files yet. Configure Mednafen and start a game once.", Color.FromRgb(239,67,129), delegate { dashboardSubpage = "settings"; selected = 0; RenderPage(); });
            else AddRoundedStorage(panel, "Back Up All Memory", saves.Count.ToString(CultureInfo.InvariantCulture) + " nonvolatile file(s)", Color.FromRgb(34,162,225), BackupSaves);
        }

        private List<KeyValuePair<ConsolePlatformGame, string>> FindDsSidecarSaves()
        {
            List<KeyValuePair<ConsolePlatformGame, string>> result = new List<KeyValuePair<ConsolePlatformGame, string>>(); HashSet<string> seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (ConsolePlatformGame game in games)
            {
                if (game == null || String.IsNullOrWhiteSpace(game.Path)) continue;
                foreach (string ext in new string[] { ".sav", ".dsv" })
                {
                    string candidate; try { candidate = Path.ChangeExtension(game.Path, ext); } catch { continue; }
                    if (File.Exists(candidate) && seen.Add(candidate)) { result.Add(new KeyValuePair<ConsolePlatformGame, string>(game, candidate)); break; }
                }
            }
            foreach (string rootPath in FindSaveRoots())
            {
                if (!Directory.Exists(rootPath)) continue;
                try { foreach (string file in Directory.EnumerateFiles(rootPath, "*.sav", SearchOption.TopDirectoryOnly).Take(500)) if (seen.Add(file)) result.Add(new KeyValuePair<ConsolePlatformGame, string>(null, file)); } catch { }
            }
            return result.OrderBy(delegate(KeyValuePair<ConsolePlatformGame,string> pair) { return pair.Key == null ? Path.GetFileNameWithoutExtension(pair.Value) : pair.Key.Name; }, StringComparer.OrdinalIgnoreCase).ToList();
        }

        private void RenderDsSavedData(bool dsi)
        {
            titleText.Text = dsi ? "Data Management" : "Saved Data"; subtitleText.Text = dsi ? "Nintendo DSi system memory and DS software saves" : "Nintendo DS game-card save data"; columns = 2;
            Grid body = new Grid { Margin = new Thickness(90, 4, 90, 22) }; body.RowDefinitions.Add(new RowDefinition { Height = new GridLength(dsi ? 120 : 84) }); body.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) }); contentHost.Children.Add(body);
            Border header = new Border { CornerRadius = new CornerRadius(12), Background = new SolidColorBrush(dsi ? Color.FromRgb(232,247,252) : Color.FromRgb(228,239,247)), BorderBrush = new SolidColorBrush(dsi ? Color.FromRgb(67,181,222) : Color.FromRgb(70,145,202)), BorderThickness = new Thickness(2), Padding = new Thickness(18) };
            header.Child = new TextBlock { Text = dsi ? "SYSTEM MEMORY\nManage locally emulated DSi data without exposing dead DSi Shop services." : "GAME CARD SAVE MEMORY\nSaved data remains paired with its DS software image.", FontSize = 15, Foreground = new SolidColorBrush(Color.FromRgb(61,84,99)), TextAlignment = TextAlignment.Center, HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center }; body.Children.Add(header);
            StackPanel list = new StackPanel { Margin = new Thickness(0, 10, 0, 0) }; ScrollViewer scroll = new ScrollViewer { VerticalScrollBarVisibility = ScrollBarVisibility.Hidden, Content = list }; Grid.SetRow(scroll, 1); body.Children.Add(scroll);
            List<KeyValuePair<ConsolePlatformGame,string>> saves = FindDsSidecarSaves(); foreach (KeyValuePair<ConsolePlatformGame,string> pair in saves) { string captured = pair.Value; string name = pair.Key == null ? Path.GetFileNameWithoutExtension(pair.Value) : pair.Key.Name; AddRoundedStorage(list, name, FormatBytes(GetPathSize(pair.Value)) + "  •  " + Path.GetFileName(pair.Value) + "  •  " + GetPathModifiedUtcSafe(pair.Value).ToString("g", CultureInfo.CurrentCulture), dsi ? Color.FromRgb(67,181,222) : Color.FromRgb(70,145,202), delegate { BackupNativeSavePath(captured, (dsi ? "DSi-" : "DS-") + Path.GetFileNameWithoutExtension(captured)); }); }
            if (dsi) { foreach (string rootPath in FindSaveRoots().Where(delegate(string p) { return p.IndexOf("NAND", StringComparison.OrdinalIgnoreCase) >= 0; })) { string captured = rootPath; AddRoundedStorage(list, "Nintendo DSi System Memory", FormatBytes(GetPathSize(rootPath)) + "  •  NAND data", Color.FromRgb(239,157,56), delegate { BackupNativeSavePath(captured, "DSi-SystemMemory"); }); } }
            if (saves.Count == 0 && (!dsi || !FindSaveRoots().Any(delegate(string p) { return p.IndexOf("NAND", StringComparison.OrdinalIgnoreCase) >= 0; }))) AddRoundedStorage(list, "No Saved Data Detected", "Choose the melonDS data path or launch software once to create save data.", dsi ? Color.FromRgb(67,181,222) : Color.FromRgb(70,145,202), delegate { dashboardSubpage = "settings"; selected = 0; RenderPage(); });
        }

        private void Render3dsDataManagement()
        {
            titleText.Text = "Data Management"; subtitleText.Text = "Nintendo 3DS emulated system storage"; columns = 2;
            Grid body = new Grid { Margin = new Thickness(75, 0, 75, 20) }; body.RowDefinitions.Add(new RowDefinition { Height = new GridLength(145) }); body.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) }); contentHost.Children.Add(body);
            Border top = new Border { Margin = new Thickness(80, 0, 80, 10), CornerRadius = new CornerRadius(12), Background = new LinearGradientBrush(Color.FromRgb(239,243,246), Color.FromRgb(211,220,227), 90), BorderBrush = new SolidColorBrush(Color.FromRgb(164,177,187)), BorderThickness = new Thickness(2) };
            top.Child = new TextBlock { Text = "DATA MANAGEMENT", FontSize = 25, FontWeight = FontWeights.Light, Foreground = new SolidColorBrush(Color.FromRgb(66,80,91)), HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center }; body.Children.Add(top);
            UniformGrid cards = new UniformGrid { Columns = 2, Rows = 2, Margin = new Thickness(40, 5, 40, 0) }; Grid.SetRow(cards, 1); body.Children.Add(cards);
            List<string> roots = FindSaveRoots(); List<string> sdmc = roots.Where(delegate(string p) { return String.Equals(Path.GetFileName(p.TrimEnd(Path.DirectorySeparatorChar)), "sdmc", StringComparison.OrdinalIgnoreCase); }).ToList(); List<string> nand = roots.Where(delegate(string p) { return p.IndexOf("nand", StringComparison.OrdinalIgnoreCase) >= 0; }).ToList();
            Action backupSd = delegate { foreach (string value in sdmc) BackupNativeSavePath(value, "3DS-SDMC"); }; Action backupNand = delegate { foreach (string value in nand) BackupNativeSavePath(value, "3DS-NAND"); };
            Button sd = CreateWave1Tile("SD Card", sdmc.Count == 0 ? "Not detected" : FormatBytes(sdmc.Sum(delegate(string p) { return GetPathSize(p); })), "SD", new SolidColorBrush(Color.FromRgb(91,168,219)), Brushes.White, backupSd, 330, 150); AddWave1Action(cards, sd, "SD Card", backupSd, null);
            Button system = CreateWave1Tile("System Memory", nand.Count == 0 ? "Not detected" : FormatBytes(nand.Sum(delegate(string p) { return GetPathSize(p); })), "▣", new SolidColorBrush(Color.FromRgb(239,157,56)), Brushes.White, backupNand, 330, 150); AddWave1Action(cards, system, "System Memory", backupNand, null);
            Action refresh = delegate { RenderPage(); }; Button refreshButton = CreateWave1Tile("Refresh Data", "Rescan Azahar storage", "↻", new SolidColorBrush(Color.FromRgb(91,101,111)), Brushes.White, refresh, 330, 150); AddWave1Action(cards, refreshButton, "Refresh Data", refresh, null);
            Action settingsAction = delegate { dashboardSubpage = "settings"; selected = 0; RenderPage(); }; Button settingsButton = CreateWave1Tile("Storage Settings", "Azahar data path", "⚙", new SolidColorBrush(Color.FromRgb(103,146,106)), Brushes.White, settingsAction, 330, 150); AddWave1Action(cards, settingsButton, "Storage Settings", settingsAction, null);
        }

'''
anchor='        private void RenderWave1Music()\n'
if text.count(anchor)!=1: raise SystemExit('Wave 1 storage helper insertion anchor missing')
text=text.replace(anchor,methods+anchor,1)
path.write_text(text,encoding='utf-8')
print('materialized Wave 1 native storage managers')
