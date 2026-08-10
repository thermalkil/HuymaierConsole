from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
path=ROOT/'Native'/'HuymaierConsole.ConsolePlatforms.cs'
text=path.read_text(encoding='utf-8-sig')

# Route Wave 2 subpages through console-hardware-specific settings/storage rather
# than the generic Wave 1 cards.
old='''        private void RenderWave2Subpage()
        {
            if (dashboardSubpage == "library") { RenderWave1Library(); return; }
            if (dashboardSubpage == "settings" || dashboardSubpage == "backend-settings" || dashboardSubpage == "backend-settings-list" || dashboardSubpage == "backend-setting-detail") { RenderWave1Subpage(); return; }
            if (dashboardSubpage == "saves") { RenderWave1Storage(); return; }
            if (dashboardSubpage == "music") { RenderWave1Music(); return; }
            RenderWave1Settings();
        }
'''
new='''        private void RenderWave2Subpage()
        {
            if (dashboardSubpage == "library") { RenderWave1Library(); return; }
            if (dashboardSubpage == "backend-settings" || dashboardSubpage == "backend-settings-list" || dashboardSubpage == "backend-setting-detail") { RenderWave1Subpage(); return; }
            if (dashboardSubpage == "settings") { RenderWave2Settings(); return; }
            if (dashboardSubpage == "saves") { RenderWave2Storage(); return; }
            if (dashboardSubpage == "music") { RenderWave1Music(); return; }
            RenderWave2Settings();
        }
'''
if old in text:text=text.replace(old,new,1)
elif 'private void RenderWave2Settings()' not in text:raise SystemExit('Wave2 subpage routing anchor missing')

# Expand the explicit LB/RB letter-jump exception to the large cartridge/CD
# libraries. It still does not change pages or utility selections.
old='''            bool wii = definition.Shell == "Wii" && IsRootConsoleSurface();
            if (!n64 && !gameCube && !wii) return false;

            int currentIndex = n64 ? n64LibraryIndex : (gameCube ? Math.Max(0, Math.Min(games.Count - 1, selected)) : Math.Max(0, Math.Min(games.Count - 1, wiiMenuPage * 12 + Math.Min(selected, 11))));
'''
new='''            bool wii = definition.Shell == "Wii" && IsRootConsoleSurface();
            bool wave2 = IsWave2Shell() && IsRootConsoleSurface() && selected >= 0 && selected < games.Count;
            if (!n64 && !gameCube && !wii && !wave2) return false;

            int currentIndex = n64 ? n64LibraryIndex : (gameCube ? Math.Max(0, Math.Min(games.Count - 1, selected)) : (wave2 ? Math.Max(0, Math.Min(games.Count - 1, selected)) : Math.Max(0, Math.Min(games.Count - 1, wiiMenuPage * 12 + Math.Min(selected, 11)))));
'''
if old in text:text=text.replace(old,new,1)
elif 'bool wave2 = IsWave2Shell()' not in text:raise SystemExit('Wave2 letter-jump condition anchor missing')

old='''            if (n64) n64LibraryIndex = target;
            else if (gameCube) selected = target;
            else
            {
                wiiMenuPage = target / 12;
                selected = target % 12;
            }
'''
new='''            if (n64) n64LibraryIndex = target;
            else if (gameCube || wave2) selected = target;
            else
            {
                wiiMenuPage = target / 12;
                selected = target % 12;
            }
'''
if old in text:text=text.replace(old,new,1)
elif 'else if (gameCube || wave2) selected = target;' not in text:raise SystemExit('Wave2 letter-jump target anchor missing')

methods=r'''
        private Color GetWave2Accent()
        {
            if (definition.Shell == "Atari2600") return Color.FromRgb(220,149,57);
            if (definition.Shell == "NES") return Color.FromRgb(194,35,42);
            if (definition.Shell == "SNES") return Color.FromRgb(103,74,151);
            if (definition.Shell == "GameBoy") return Color.FromRgb(117,44,111);
            if (definition.Shell == "GBC") return Color.FromRgb(244,73,142);
            if (definition.Shell == "GBA") return Color.FromRgb(168,145,255);
            if (definition.Shell == "Genesis") return Color.FromRgb(191,34,45);
            if (definition.Shell == "SegaCD") return Color.FromRgb(80,147,214);
            if (definition.Shell == "Sega32X") return Color.FromRgb(224,60,48);
            if (definition.Shell == "GameGear") return Color.FromRgb(47,137,205);
            if (definition.Shell == "MasterSystem") return Color.FromRgb(206,31,39);
            return Color.FromRgb(193,34,42);
        }

        private string GetWave2SaveMediaLabel()
        {
            if (definition.Shell == "Atari2600") return "CARTRIDGE NVRAM / SAVEKEY";
            if (definition.Shell == "SegaCD") return "BACKUP RAM";
            if (definition.Shell == "TurboGrafx16") return "HUCARD / CD BACKUP";
            if (definition.Shell == "GameBoy" || definition.Shell == "GBC" || definition.Shell == "GBA" || definition.Shell == "GameGear") return "BATTERY SAVE";
            return "CARTRIDGE SAVE MEMORY";
        }

        private string[] GetWave2SaveExtensions()
        {
            if (definition.Shell == "Atari2600") return new string[] { ".sav", ".dat", ".eep", ".eeprom", ".nv", ".nvram", ".ram" };
            if (definition.Shell == "SegaCD") return new string[] { ".brm", ".bkr", ".bcr", ".sav", ".srm", ".ram" };
            if (definition.Shell == "GameBoy" || definition.Shell == "GBC" || definition.Shell == "GBA") return new string[] { ".sav", ".srm", ".rtc", ".ram" };
            return new string[] { ".sav", ".srm", ".ram", ".brm", ".eep", ".eeprom", ".nv", ".nvram" };
        }

        private List<string> GetWave2SaveSearchRoots()
        {
            List<string> roots = new List<string>();
            Action<string> add = delegate(string value) { if (String.IsNullOrWhiteSpace(value)) return; try { if (File.Exists(value)) value = Path.GetDirectoryName(value); if (Directory.Exists(value) && !roots.Contains(value, StringComparer.OrdinalIgnoreCase)) roots.Add(value); } catch { } };
            add(settings.emulatorDataPath); add(settings.emulatorPath); add(settings.fallbackEmulatorPath);
            string app = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData); string local = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData); string docs = Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments);
            if (definition.PrimaryBackend.IndexOf("Mesen", StringComparison.OrdinalIgnoreCase) >= 0) { add(Path.Combine(app,"Mesen")); add(Path.Combine(app,"Mesen2")); add(Path.Combine(local,"Mesen")); add(Path.Combine(local,"Mesen2")); }
            if (definition.PrimaryBackend.IndexOf("SameBoy", StringComparison.OrdinalIgnoreCase) >= 0) { add(Path.Combine(app,"SameBoy")); add(Path.Combine(local,"SameBoy")); }
            if (definition.PrimaryBackend.IndexOf("mGBA", StringComparison.OrdinalIgnoreCase) >= 0) { add(Path.Combine(app,"mGBA")); add(Path.Combine(local,"mGBA")); }
            if (definition.PrimaryBackend.IndexOf("Stella", StringComparison.OrdinalIgnoreCase) >= 0) add(Path.Combine(app,"Stella"));
            if (definition.PrimaryBackend.IndexOf("ares", StringComparison.OrdinalIgnoreCase) >= 0) { add(Path.Combine(app,"ares")); add(Path.Combine(local,"ares")); }
            if (definition.PrimaryBackend.IndexOf("Mednafen", StringComparison.OrdinalIgnoreCase) >= 0) { add(Path.Combine(docs,"Mednafen")); add(Path.Combine(app,"Mednafen")); }
            List<string> baseRoots = roots.ToList(); foreach (string rootPath in baseRoots) foreach (string name in new string[] { "Save", "Saves", "Battery", "SRAM", "NVRAM", "Backup", "sav" }) { try { add(Path.Combine(rootPath,name)); } catch { } }
            return roots;
        }

        private List<string> FindWave2SaveFiles()
        {
            HashSet<string> found = new HashSet<string>(StringComparer.OrdinalIgnoreCase); string[] extensions = GetWave2SaveExtensions();
            foreach (ConsolePlatformGame game in games)
            {
                if (game == null || String.IsNullOrWhiteSpace(game.Path)) continue;
                string basePath; try { basePath = Path.Combine(Path.GetDirectoryName(game.Path), Path.GetFileNameWithoutExtension(game.Path)); } catch { continue; }
                foreach (string ext in extensions) { string candidate = basePath + ext; if (File.Exists(candidate)) found.Add(candidate); }
            }
            int visited = 0;
            foreach (string rootPath in GetWave2SaveSearchRoots())
            {
                if (!Directory.Exists(rootPath)) continue;
                try
                {
                    foreach (string file in Directory.EnumerateFiles(rootPath,"*",SearchOption.AllDirectories))
                    {
                        if (++visited > 7000) break; string ext = Path.GetExtension(file); if (extensions.Contains(ext,StringComparer.OrdinalIgnoreCase)) found.Add(file);
                    }
                }
                catch { }
                if (visited > 7000) break;
            }
            return found.OrderBy(delegate(string p) { return Path.GetFileName(p); }, StringComparer.CurrentCultureIgnoreCase).ToList();
        }

        private string GetWave2SaveDisplayName(string pathValue)
        {
            string baseName = Path.GetFileNameWithoutExtension(pathValue); string normalized = NormalizeArtworkTitle(baseName); ConsolePlatformGame best = null; double bestScore = 0;
            foreach (ConsolePlatformGame game in games) { string candidate = NormalizeArtworkTitle(game.Name); if (candidate == normalized) return game.Name; double score = candidate.Contains(normalized) || normalized.Contains(candidate) ? 0.8 : 0; if (score > bestScore) { bestScore = score; best = game; } }
            return best != null && bestScore >= 0.8 ? best.Name : baseName;
        }

        private Button CreateWave2SaveChip(string pathValue, Action invoke)
        {
            Color accent = GetWave2Accent(); string title = GetWave2SaveDisplayName(pathValue); string media = GetWave2SaveMediaLabel();
            Button button = new Button { Width=315, Height=126, Margin=new Thickness(9), Padding=new Thickness(0), Background=Brushes.Transparent, BorderThickness=new Thickness(0), RenderTransformOrigin=new Point(0.5,0.5) };
            Border chip = new Border { CornerRadius=new CornerRadius(8), Background=new LinearGradientBrush(Color.FromRgb(30,31,32),Color.FromRgb(8,9,10),90), BorderBrush=new SolidColorBrush(accent), BorderThickness=new Thickness(2), Padding=new Thickness(14) };
            Grid layout = new Grid(); layout.ColumnDefinitions.Add(new ColumnDefinition{Width=new GridLength(76)}); layout.ColumnDefinitions.Add(new ColumnDefinition());
            Border die = new Border { Width=54, Height=72, CornerRadius=new CornerRadius(5), Background=new SolidColorBrush(Color.FromRgb(14,15,16)), BorderBrush=new SolidColorBrush(Color.FromArgb(180,accent.R,accent.G,accent.B)), BorderThickness=new Thickness(2), VerticalAlignment=VerticalAlignment.Center, Child=new TextBlock{Text="SAVE\nRAM",FontSize=10,FontWeight=FontWeights.Bold,Foreground=new SolidColorBrush(accent),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center,TextAlignment=TextAlignment.Center} }; layout.Children.Add(die);
            StackPanel info = new StackPanel { Margin=new Thickness(8,2,0,0) }; Grid.SetColumn(info,1); info.Children.Add(new TextBlock{Text=title,FontSize=15,FontWeight=FontWeights.SemiBold,Foreground=Brushes.White,TextTrimming=TextTrimming.CharacterEllipsis}); info.Children.Add(new TextBlock{Text=media,FontSize=9,Foreground=new SolidColorBrush(accent),Margin=new Thickness(0,3,0,0)}); info.Children.Add(new TextBlock{Text=FormatBytes(GetPathSize(pathValue))+"  •  "+GetPathModifiedUtcSafe(pathValue).ToString("g",CultureInfo.CurrentCulture),FontSize=9,Foreground=new SolidColorBrush(Color.FromArgb(185,255,255,255)),Margin=new Thickness(0,5,0,0)}); info.Children.Add(new TextBlock{Text=Path.GetFileName(pathValue),FontSize=8,Foreground=new SolidColorBrush(Color.FromArgb(135,255,255,255)),TextTrimming=TextTrimming.CharacterEllipsis}); layout.Children.Add(info); chip.Child=layout; button.Content=chip; button.Click+=delegate{invoke();}; return button;
        }

        private void RenderWave2Storage()
        {
            Color accent = GetWave2Accent(); string media = GetWave2SaveMediaLabel(); titleText.Text = definition.Shell == "SegaCD" ? "Backup RAM" : "Saved Data"; subtitleText.Text = media + "  •  " + definition.DisplayName; columns = 3;
            ScrollViewer scroll = new ScrollViewer { VerticalScrollBarVisibility=ScrollBarVisibility.Hidden, HorizontalScrollBarVisibility=ScrollBarVisibility.Disabled }; WrapPanel panel = new WrapPanel { Margin=new Thickness(34,8,34,24) }; scroll.Content=panel; contentHost.Children.Add(scroll);
            List<string> saves = FindWave2SaveFiles(); foreach (string pathValue in saves.Take(600)) { string captured=pathValue; Button chip=CreateWave2SaveChip(pathValue,delegate{BackupNativeSavePath(captured,definition.Id+"-"+Path.GetFileNameWithoutExtension(captured));}); panel.Children.Add(chip); actions.Add(new ConsolePlatformAction{Button=chip,Name=GetWave2SaveDisplayName(pathValue),Invoke=delegate{BackupNativeSavePath(captured,definition.Id+"-"+Path.GetFileNameWithoutExtension(captured));}}); }
            if (saves.Count == 0) AddHardwareUtility(panel,"No Saved Data",definition.PrimaryBackend+" has not produced detected "+media.ToLowerInvariant()+" yet.","▣",accent,delegate{dashboardSubpage="settings";selected=0;RenderPage();},310,126);
            else AddHardwareUtility(panel,"Back Up All",saves.Count.ToString(CultureInfo.InvariantCulture)+" save file(s)","⇧",accent,delegate{foreach(string value in saves)BackupNativeSavePath(value,definition.Id+"-"+Path.GetFileNameWithoutExtension(value));},310,126);
        }

        private void RenderWave2Settings()
        {
            Color accent=GetWave2Accent(); titleText.Text=definition.DisplayName+" System"; subtitleText.Text=definition.PrimaryBackend+"  •  every setting remains inside Huymaier Console"; columns=3;
            Grid body=new Grid{Margin=new Thickness(42,4,42,22)};body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(115)});body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(1,GridUnitType.Star)});contentHost.Children.Add(body);
            Border plaque=new Border{CornerRadius=new CornerRadius(10),Background=new LinearGradientBrush(Color.FromRgb(35,36,38),Color.FromRgb(9,10,11),90),BorderBrush=new SolidColorBrush(accent),BorderThickness=new Thickness(2),Padding=new Thickness(20)};Grid header=new Grid();header.Children.Add(new TextBlock{Text=definition.DisplayName.ToUpperInvariant(),FontSize=24,FontWeight=FontWeights.SemiBold,Foreground=Brushes.White,VerticalAlignment=VerticalAlignment.Center});header.Children.Add(new TextBlock{Text=String.IsNullOrWhiteSpace(settings.emulatorPath)?"EMULATOR NOT ATTACHED":Path.GetFileName(settings.emulatorPath),FontSize=11,Foreground=new SolidColorBrush(accent),HorizontalAlignment=HorizontalAlignment.Right,VerticalAlignment=VerticalAlignment.Center});plaque.Child=header;body.Children.Add(plaque);
            WrapPanel controls=new WrapPanel{Margin=new Thickness(0,12,0,0)};ScrollViewer scroll=new ScrollViewer{VerticalScrollBarVisibility=ScrollBarVisibility.Hidden,Content=controls};Grid.SetRow(scroll,1);body.Children.Add(scroll);
            if(String.IsNullOrWhiteSpace(settings.emulatorPath)||!File.Exists(settings.emulatorPath)){AddHardwareUtility(controls,"Locate Emulator","Point Huymaier Console to "+definition.PrimaryBackend,"⌕",accent,ChoosePrimaryEmulator,300,130);AddHardwareUtility(controls,"Install Latest",definition.PrimaryBackend+" official release","↓",accent,InstallPrimaryEmulator,300,130);}else AddHardwareUtility(controls,definition.PrimaryBackend,settings.emulatorPath,"✓",accent,ChoosePrimaryEmulator,300,130);
            AddHardwareUtility(controls,"Full Emulator Settings","Every discovered setting; unknown keys preserved","⚙",accent,OpenNativeBackendSettings,300,130);AddHardwareUtility(controls,"Emulator Data",DisplayPath(settings.emulatorDataPath),"▣",accent,ChooseEmulatorDataRoot,300,130);AddHardwareUtility(controls,"Game Folders",settings.gameFolders.Count.ToString(CultureInfo.InvariantCulture)+" configured","▦",accent,AddGameFolder,300,130);AddHardwareUtility(controls,"Saved Data",GetWave2SaveMediaLabel(),"◫",accent,delegate{dashboardSubpage="saves";selected=0;RenderPage();},300,130);AddHardwareUtility(controls,"Refresh Library",games.Count.ToString(CultureInfo.InvariantCulture)+" titles","↻",accent,delegate{RefreshLibrary(true);},300,130);
        }

'''
anchor='        private void RenderAtari2600Deck()\n'
if 'private void RenderWave2Settings()' not in text:
    if text.count(anchor)!=1:raise SystemExit('Wave2 storage/settings insertion anchor missing')
    text=text.replace(anchor,methods+anchor,1)
path.write_text(text,encoding='utf-8')
print('materialized Wave 2 native save managers, hardware settings and LB/RB alphabet acceleration')
