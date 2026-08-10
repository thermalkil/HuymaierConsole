from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

def read(rel):
    return (ROOT / rel).read_text(encoding="utf-8-sig")

def write(rel, text):
    (ROOT / rel).write_text(text, encoding="utf-8")

def replace_once(rel, old, new):
    text = read(rel)
    if old not in text:
        raise RuntimeError(f"Expected RC3 block not found in {rel}: {old[:120]!r}")
    if text.count(old) != 1:
        raise RuntimeError(f"Expected one RC3 block in {rel}, found {text.count(old)}")
    write(rel, text.replace(old, new, 1))

replace_once("Native/HuymaierConsole.ConsolePlatforms.cs",
'''        public string dashboardStyle { get; set; }
        public bool fullscreen { get; set; }

        public ConsolePlatformSettings()
        {
            schemaVersion = 6;''',
'''        public string dashboardStyle { get; set; }
        public bool fullscreen { get; set; }
        public double gameCubeScale { get; set; }

        public ConsolePlatformSettings()
        {
            schemaVersion = 7;''')

replace_once("Native/HuymaierConsole.ConsolePlatforms.cs",
'''            dashboardStyle = String.Empty;
            fullscreen = true;
        }''',
'''            dashboardStyle = String.Empty;
            fullscreen = true;
            gameCubeScale = 0.66;
        }''')

replace_once("Native/HuymaierConsole.ConsolePlatforms.cs",
'''            result.soundVolume = Clamp(result.soundVolume);
            result.schemaVersion = 6;''',
'''            result.soundVolume = Clamp(result.soundVolume);
            if (loadedSchema < 7 || Double.IsNaN(result.gameCubeScale) || result.gameCubeScale < 0.45 || result.gameCubeScale > 1.05) result.gameCubeScale = 0.66;
            result.gameCubeScale = Math.Max(0.50, Math.Min(1.00, result.gameCubeScale));
            result.schemaVersion = 7;''')

replace_once("Native/HuymaierConsole.ConsolePlatforms.cs",
'''    internal sealed class XboxSaveEntry
    {
        internal string Name;
        internal string TitleId;
        internal string Path;
        internal bool IsDirectory;
        internal long Size;
        internal DateTime Modified;
    }

    internal sealed class XboxXdbfEntry''',
'''    internal sealed class XboxSaveEntry
    {
        internal string Name;
        internal string TitleId;
        internal string Path;
        internal bool IsDirectory;
        internal long Size;
        internal DateTime Modified;
    }

    internal sealed class GameCubeSaveEntry
    {
        internal string Name;
        internal string GameCode;
        internal int Blocks;
        internal DateTime Modified;
        internal string CardPath;
    }

    internal sealed class GameCubeMemoryCardInfo
    {
        internal string Slot;
        internal string Path;
        internal int TotalBlocks;
        internal int FreeBlocks;
        internal List<GameCubeSaveEntry> Saves = new List<GameCubeSaveEntry>();
    }

    internal sealed class WiiSaveEntry
    {
        internal string Name;
        internal string TitleId;
        internal string Path;
        internal long Size;
        internal DateTime Modified;
    }

    internal sealed class XboxXdbfEntry''')

replace_once("Native/HuymaierConsole.ConsolePlatforms.cs",
'''            if (definition.Shell == "GameCube") helpText = "D-Pad  Menu     A  Select     B  Back     OPTIONS  Alternate emulator     GUIDE  Game Bar";
            else if (definition.Shell == "Wii") helpText = "D-Pad  Point / Navigate     A  Select     B  Back     GUIDE  Game Bar";''',
'''            if (definition.Shell == "GameCube") helpText = "D-Pad  Menu     LB / RB  Letter     A  Select     B  Back     GUIDE  Game Bar";
            else if (definition.Shell == "Wii") helpText = "D-Pad  Navigate     LB / RB  Letter     A  Select     B  Back     GUIDE  Game Bar";''')

replace_once("Native/HuymaierConsole.ConsolePlatforms.cs",
'''            // Shoulder buttons are never section/page selectors in Huymaier native
            // console surfaces. Keep them unbound here so controller behavior stays
            // consistent with the main console and the PlayStation interfaces.
            if (command == XmbInputCommand.LeftShoulder || command == XmbInputCommand.RightShoulder) return;''',
'''            // Shoulder buttons never change console sections/pages.  The only native-console
            // exception is a deliberate large-library accelerator requested for N64/GameCube/Wii:
            // LB/RB jumps to the previous/next populated first-letter group.
            if (command == XmbInputCommand.LeftShoulder || command == XmbInputCommand.RightShoulder)
            {
                if (TryProcessLibraryLetterJump(command)) return;
                return;
            }''')

replace_once("Native/HuymaierConsole.ConsolePlatforms.cs",
'''                        n64LibraryIndex = Math.Max(0, Math.Min(games.Count - 1, n64LibraryIndex + delta));
                        selected = n64LibraryIndex;
                        PlayEffect("Navigate.wav"); RenderPage();''',
'''                        n64LibraryIndex = Math.Max(0, Math.Min(games.Count - 1, n64LibraryIndex + delta));
                        PlayEffect("Navigate.wav"); RenderPage();''')

replace_once("Native/HuymaierConsole.ConsolePlatforms.cs",
'''            if (definition.Shell == "N64" && IsRootConsoleSurface()) { RenderN64GamePakLauncher(); UpdateActionVisuals(); return; }''',
'''            if (definition.Shell == "N64" && IsRootConsoleSurface()) { RenderN64GamePakLauncher(); return; }''')

replace_once("Native/HuymaierConsole.ConsolePlatforms.cs",
'''                if (command == XmbInputCommand.Left && selected % 4 == 0 && wiiMenuPage > 0) { wiiMenuPage--; selected = 0; PlayEffect("Tab.wav"); RenderPage(); return; }
                if (command == XmbInputCommand.Right && selected % 4 == 3 && wiiMenuPage < 3) { wiiMenuPage++; selected = 0; PlayEffect("Tab.wav"); RenderPage(); return; }''',
'''                int lastWiiPage = Math.Max(0, GetWiiMenuPageCount() - 1);
                if (command == XmbInputCommand.Left && selected % 4 == 0 && wiiMenuPage > 0) { wiiMenuPage--; selected = 0; PlayEffect("Tab.wav"); RenderPage(); return; }
                if (command == XmbInputCommand.Right && selected % 4 == 3 && wiiMenuPage < lastWiiPage) { wiiMenuPage++; selected = 0; PlayEffect("Tab.wav"); RenderPage(); return; }''')

replace_once("Native/HuymaierConsole.ConsolePlatforms.cs",
'''        private void RenderInlineSettings()
        {
            contentHost.Children.Clear(); actions.Clear(); RenderSettings(); UpdateActionVisuals();
        }

        private int FindFirstGameIndex(char letter)
        {
            for (int i = 0; i < games.Count; i++)
            {
                char first = String.IsNullOrWhiteSpace(games[i].Name) ? '#' : Char.ToUpperInvariant(games[i].Name[0]);
                if (letter == '#' ? !Char.IsLetter(first) : first == letter) return i;
            }
            return 0;
        }''',
'''        private void RenderInlineSettings()
        {
            contentHost.Children.Clear(); actions.Clear(); RenderSettings(); UpdateActionVisuals();
        }

        private static char GetLibraryInitial(ConsolePlatformGame game)
        {
            if (game == null || String.IsNullOrWhiteSpace(game.Name)) return '#';
            char value = Char.ToUpperInvariant(game.Name.Trim()[0]);
            return Char.IsLetter(value) ? value : '#';
        }

        private List<char> GetAvailableLibraryLetters()
        {
            List<char> result = new List<char>();
            foreach (char letter in "#ABCDEFGHIJKLMNOPQRSTUVWXYZ")
            {
                if (games.Any(delegate(ConsolePlatformGame game) { return GetLibraryInitial(game) == letter; })) result.Add(letter);
            }
            return result;
        }

        private int FindFirstGameIndex(char letter)
        {
            for (int i = 0; i < games.Count; i++) if (GetLibraryInitial(games[i]) == letter) return i;
            return 0;
        }

        private int GetWiiMenuPageCount() { return Math.Max(1, (games.Count + 11) / 12); }

        private bool TryProcessLibraryLetterJump(XmbInputCommand command)
        {
            if (games == null || games.Count == 0) return false;
            bool n64 = definition.Shell == "N64" && IsRootConsoleSurface() && n64Zone == 0;
            bool gameCube = definition.Shell == "GameCube" && !IsRootConsoleSurface() && page == 0;
            bool wii = definition.Shell == "Wii" && IsRootConsoleSurface();
            if (!n64 && !gameCube && !wii) return false;

            int currentIndex = n64 ? n64LibraryIndex : (gameCube ? Math.Max(0, Math.Min(games.Count - 1, selected)) : Math.Max(0, Math.Min(games.Count - 1, wiiMenuPage * 12 + Math.Min(selected, 11))));
            List<char> letters = GetAvailableLibraryLetters();
            if (letters.Count == 0) return false;
            char current = GetLibraryInitial(games[currentIndex]);
            int letterIndex = letters.IndexOf(current);
            if (letterIndex < 0) letterIndex = 0;
            int delta = command == XmbInputCommand.LeftShoulder ? -1 : 1;
            letterIndex = (letterIndex + delta + letters.Count) % letters.Count;
            int target = FindFirstGameIndex(letters[letterIndex]);

            if (n64) n64LibraryIndex = target;
            else if (gameCube) selected = target;
            else
            {
                wiiMenuPage = target / 12;
                selected = target % 12;
            }
            PlayEffect("Tab.wav");
            RenderPage();
            return true;
        }

        private Border BuildLibraryAlphabetRail(int currentGameIndex, bool light)
        {
            StackPanel lettersPanel = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center };
            char current = games.Count == 0 ? '#' : GetLibraryInitial(games[Math.Max(0, Math.Min(games.Count - 1, currentGameIndex))]);
            foreach (char letter in "#ABCDEFGHIJKLMNOPQRSTUVWXYZ")
            {
                bool available = games.Any(delegate(ConsolePlatformGame game) { return GetLibraryInitial(game) == letter; });
                TextBlock text = new TextBlock
                {
                    Text = letter.ToString(),
                    FontSize = letter == current ? 16 : 11,
                    FontWeight = letter == current ? FontWeights.Bold : FontWeights.Normal,
                    Foreground = new SolidColorBrush(letter == current ? (light ? Color.FromRgb(30, 155, 197) : definition.Accent) : (available ? (light ? Color.FromRgb(91, 108, 114) : Color.FromRgb(205, 205, 214)) : (light ? Color.FromRgb(188, 198, 202) : Color.FromRgb(82, 82, 92)))),
                    Margin = new Thickness(5, 0, 5, 0),
                    VerticalAlignment = VerticalAlignment.Center
                };
                lettersPanel.Children.Add(text);
            }
            return new Border { Height = 32, HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Top, Padding = new Thickness(12, 4, 12, 4), CornerRadius = new CornerRadius(12), Background = new SolidColorBrush(light ? Color.FromArgb(225, 248, 251, 252) : Color.FromArgb(160, 12, 12, 18)), Child = lettersPanel };
        }''')

replace_once("Native/HuymaierConsole.ConsolePlatforms.cs",
'''            redBand.Child=carousel; Grid.SetRow(redBand,1); body.Children.Add(redBand);''',
'''            Grid redContent = new Grid(); redContent.RowDefinitions.Add(new RowDefinition { Height = new GridLength(36) }); redContent.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
            Border n64Letters = BuildLibraryAlphabetRail(n64LibraryIndex, false); redContent.Children.Add(n64Letters); Grid.SetRow(carousel, 1); redContent.Children.Add(carousel);
            redBand.Child=redContent; Grid.SetRow(redBand,1); body.Children.Add(redBand);''')

replace_once("Native/HuymaierConsole.ConsolePlatforms.cs",
'''            RotateTransform3D rotate = new RotateTransform3D(rotation);
            models.Transform=rotate;''',
'''            RotateTransform3D rotate = new RotateTransform3D(rotation);
            Transform3DGroup cubeTransforms = new Transform3DGroup();
            cubeTransforms.Children.Add(new ScaleTransform3D(settings.gameCubeScale, settings.gameCubeScale, settings.gameCubeScale));
            cubeTransforms.Children.Add(rotate);
            models.Transform=cubeTransforms;''')

replace_once("Native/HuymaierConsole.ConsolePlatforms.cs",
'''            titleText.Text = "Game Play"; subtitleText.Text = games.Count == 0 ? "No Game Disc / library title detected" : "Select a Game Disc image • A opens / launches";
            ScrollViewer scroll = new ScrollViewer { VerticalScrollBarVisibility = ScrollBarVisibility.Hidden, HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled }; WrapPanel wrap = new WrapPanel { HorizontalAlignment = HorizontalAlignment.Center, Margin = new Thickness(20) }; scroll.Content = wrap; contentHost.Children.Add(scroll);''',
'''            titleText.Text = "Game Play"; subtitleText.Text = games.Count == 0 ? "No Game Disc / library title detected" : "Select a Game Disc image • LB / RB jumps by first letter";
            Grid gamePlayBody = new Grid(); gamePlayBody.RowDefinitions.Add(new RowDefinition { Height = new GridLength(38) }); gamePlayBody.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) }); contentHost.Children.Add(gamePlayBody);
            Border gcLetters = BuildLibraryAlphabetRail(Math.Max(0, Math.Min(games.Count - 1, selected)), false); gamePlayBody.Children.Add(gcLetters);
            ScrollViewer scroll = new ScrollViewer { VerticalScrollBarVisibility = ScrollBarVisibility.Hidden, HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled }; WrapPanel wrap = new WrapPanel { HorizontalAlignment = HorizontalAlignment.Center, Margin = new Thickness(20) }; scroll.Content = wrap; Grid.SetRow(scroll, 1); gamePlayBody.Children.Add(scroll);''')

replace_once("Native/HuymaierConsole.ConsolePlatforms.cs",
'''        private void RenderGameCubeOptions(){titleText.Text="Options";subtitleText.Text="System / Sound / Emulator";Border cubePanel=new Border{Margin=new Thickness(110,12,110,26),CornerRadius=new CornerRadius(46),Background=new LinearGradientBrush(Color.FromArgb(180,38,28,84),Color.FromArgb(160,73,56,142),45),BorderBrush=new SolidColorBrush(Color.FromRgb(155,137,245)),BorderThickness=new Thickness(5),Padding=new Thickness(18)};StackPanel p=new StackPanel();cubePanel.Child=new ScrollViewer{VerticalScrollBarVisibility=ScrollBarVisibility.Hidden,Content=p};contentHost.Children.Add(cubePanel);AddCorePlatformActions(p,CreateGameCubeSettingsRow);}''',
'''        private void RenderGameCubeOptions(){titleText.Text="Options";subtitleText.Text="Nintendo GameCube IPL options";Border cubePanel=new Border{Margin=new Thickness(110,12,110,26),CornerRadius=new CornerRadius(46),Background=new LinearGradientBrush(Color.FromArgb(180,38,28,84),Color.FromArgb(160,73,56,142),45),BorderBrush=new SolidColorBrush(Color.FromRgb(155,137,245)),BorderThickness=new Thickness(5),Padding=new Thickness(18)};StackPanel p=new StackPanel();cubePanel.Child=new ScrollViewer{VerticalScrollBarVisibility=ScrollBarVisibility.Hidden,Content=p};contentHost.Children.Add(cubePanel);Button scale=CreateGameCubeSettingsRow("Cube Size",Math.Round(settings.gameCubeScale*100).ToString(CultureInfo.InvariantCulture)+"%  •  A cycles size",CycleGameCubeScale);p.Children.Add(scale);actions.Add(new ConsolePlatformAction{Button=scale,Invoke=CycleGameCubeScale,Name="Cube Size"});AddCorePlatformActions(p,CreateGameCubeSettingsRow);}''')

replace_once("Native/HuymaierConsole.ConsolePlatforms.cs",
'''        private void CycleSoundVolume()
        {''',
'''        private void CycleGameCubeScale()
        {
            double[] levels = new double[] { 0.52, 0.60, 0.66, 0.74, 0.82, 0.90 };
            int index = 0; double best = Double.MaxValue;
            for (int i = 0; i < levels.Length; i++) { double delta = Math.Abs(levels[i] - settings.gameCubeScale); if (delta < best) { best = delta; index = i; } }
            settings.gameCubeScale = levels[(index + 1) % levels.Length];
            settings.Save(settingsPath);
            ShowNotice("Cube size " + Math.Round(settings.gameCubeScale * 100).ToString(CultureInfo.InvariantCulture) + "%");
            RenderPage();
        }

        private void CycleSoundVolume()
        {''')

old_wii_bottom = '''            Grid bottom=new Grid{Margin=new Thickness(4,0,4,0)};bottom.ColumnDefinitions.Add(new ColumnDefinition{Width=new GridLength(330)});bottom.ColumnDefinitions.Add(new ColumnDefinition{Width=new GridLength(1,GridUnitType.Star)});bottom.ColumnDefinitions.Add(new ColumnDefinition{Width=new GridLength(220)});
            StackPanel left=new StackPanel{Orientation=Orientation.Horizontal,HorizontalAlignment=HorizontalAlignment.Left,VerticalAlignment=VerticalAlignment.Center};Button wii=CreateWiiRoundButton("Wii","Options",delegate{dashboardSubpage="wii-options";selected=0;RenderPage();});wii.Width=148;Button data=CreateWiiRoundButton("SD","Data",delegate{dashboardSubpage="wii-data";selected=0;RenderPage();});data.Width=148;left.Children.Add(wii);left.Children.Add(data);bottom.Children.Add(left);
            StackPanel clock=new StackPanel{HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center};clock.Children.Add(new TextBlock{Text=DateTime.Now.ToString("h:mm tt",CultureInfo.CurrentCulture),FontSize=25,Foreground=new SolidColorBrush(Color.FromRgb(87,99,104)),HorizontalAlignment=HorizontalAlignment.Center});clock.Children.Add(new TextBlock{Text=DateTime.Now.ToString("ddd M/d",CultureInfo.CurrentCulture)+"   "+(wiiMenuPage+1).ToString(CultureInfo.InvariantCulture)+"/4",FontSize=12,Foreground=new SolidColorBrush(Color.FromRgb(123,134,139)),HorizontalAlignment=HorizontalAlignment.Center});Grid.SetColumn(clock,1);bottom.Children.Add(clock);
            Button settingsButton=CreateWiiRoundButton("⚙","Settings",delegate{dashboardSubpage="wii-settings";selected=0;RenderPage();});settingsButton.Width=194;Grid.SetColumn(settingsButton,2);bottom.Children.Add(settingsButton);Grid.SetRow(bottom,1);body.Children.Add(bottom);
            actions.Add(new ConsolePlatformAction{Button=wii,Invoke=delegate{dashboardSubpage="wii-options";selected=0;RenderPage();},Name="Wii Options"});actions.Add(new ConsolePlatformAction{Button=data,Invoke=delegate{dashboardSubpage="wii-data";selected=0;RenderPage();},Name="Data Management"});actions.Add(new ConsolePlatformAction{Button=settingsButton,Invoke=delegate{dashboardSubpage="wii-settings";selected=0;RenderPage();},Name="Wii Settings"});
            selected=Math.Max(0,Math.Min(actions.Count-1,selected));'''
new_wii_bottom = '''            Grid bottom=new Grid{Margin=new Thickness(4,0,4,0)};bottom.ColumnDefinitions.Add(new ColumnDefinition{Width=new GridLength(220)});bottom.ColumnDefinitions.Add(new ColumnDefinition{Width=new GridLength(1,GridUnitType.Star)});bottom.ColumnDefinitions.Add(new ColumnDefinition{Width=new GridLength(220)});
            Button wii=CreateWiiRoundButton("Wii","",delegate{dashboardSubpage="wii-options";selected=0;RenderPage();});wii.Width=148;wii.HorizontalAlignment=HorizontalAlignment.Left;bottom.Children.Add(wii);
            StackPanel clock=new StackPanel{HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center};clock.Children.Add(new TextBlock{Text=DateTime.Now.ToString("h:mm tt",CultureInfo.CurrentCulture),FontSize=25,Foreground=new SolidColorBrush(Color.FromRgb(87,99,104)),HorizontalAlignment=HorizontalAlignment.Center});clock.Children.Add(new TextBlock{Text=DateTime.Now.ToString("ddd M/d",CultureInfo.CurrentCulture)+"   "+(wiiMenuPage+1).ToString(CultureInfo.InvariantCulture)+"/"+GetWiiMenuPageCount().ToString(CultureInfo.InvariantCulture),FontSize=12,Foreground=new SolidColorBrush(Color.FromRgb(123,134,139)),HorizontalAlignment=HorizontalAlignment.Center});Grid.SetColumn(clock,1);bottom.Children.Add(clock);
            Button data=CreateWiiRoundButton("✉","Save Data",delegate{dashboardSubpage="wii-data";selected=0;RenderPage();});data.Width=148;data.HorizontalAlignment=HorizontalAlignment.Right;Grid.SetColumn(data,2);bottom.Children.Add(data);Grid.SetRow(bottom,1);body.Children.Add(bottom);
            actions.Add(new ConsolePlatformAction{Button=wii,Invoke=delegate{dashboardSubpage="wii-options";selected=0;RenderPage();},Name="Wii Options"});actions.Add(new ConsolePlatformAction{Button=data,Invoke=delegate{dashboardSubpage="wii-data";selected=0;RenderPage();},Name="Save Data"});
            selected=Math.Max(0,Math.Min(actions.Count-1,selected));'''
replace_once("Native/HuymaierConsole.ConsolePlatforms.cs", old_wii_bottom, new_wii_bottom)

replace_once("Native/HuymaierConsole.ConsolePlatforms.cs",
'''Button tile=CreateWiiChannelTile(game,slot==0,delegate{shellSelectedGame=captured;dashboardSubpage="wii-start";selected=0;RenderPage();});''',
'''Button tile=CreateWiiChannelTile(game,false,delegate{shellSelectedGame=captured;dashboardSubpage="wii-start";selected=0;RenderPage();});''')

replace_once("Native/HuymaierConsole.ConsolePlatforms.cs",
'''            UniformGrid channels=new UniformGrid{Columns=4,Rows=3,Margin=new Thickness(6,0,6,10)};body.Children.Add(channels);''',
'''            Grid menuArea=new Grid();menuArea.RowDefinitions.Add(new RowDefinition{Height=new GridLength(34)});menuArea.RowDefinitions.Add(new RowDefinition{Height=new GridLength(1,GridUnitType.Star)});body.Children.Add(menuArea);
            Border wiiLetters=BuildLibraryAlphabetRail(Math.Max(0,Math.Min(games.Count-1,wiiMenuPage*12+Math.Min(selected,11))),true);menuArea.Children.Add(wiiLetters);
            UniformGrid channels=new UniformGrid{Columns=4,Rows=3,Margin=new Thickness(6,0,6,10)};Grid.SetRow(channels,1);menuArea.Children.Add(channels);''')

replace_once("Native/HuymaierConsole.ConsolePlatforms.cs",
'''Button data=CreateWiiOptionPanel("▣","Data Management","Save Data / SD Card",delegate{dashboardSubpage="wii-data";selected=0;RenderPage();});''',
'''Button data=CreateWiiOptionPanel("▣","Data Management","Save Data",delegate{dashboardSubpage="wii-data";selected=0;RenderPage();});''')

replace_once("Native/HuymaierConsole.ConsolePlatforms.cs",
'''            if (definition.Shell == "GameCube" || definition.Shell == "Wii")
            {
                string dolphinData = settings.emulatorDataPath;
                AddExisting(roots, Path.Combine(dolphinData, "GC"));
                AddExisting(roots, Path.Combine(dolphinData, "Wii"));
                AddExisting(roots, Path.Combine(exeRoot, "User", "GC"));
                AddExisting(roots, Path.Combine(exeRoot, "User", "Wii"));
            }''',
'''            if (definition.Shell == "GameCube")
            {
                string dolphinData = settings.emulatorDataPath;
                AddExisting(roots, Path.Combine(dolphinData, "GC"));
                AddExisting(roots, Path.Combine(exeRoot, "User", "GC"));
            }
            else if (definition.Shell == "Wii")
            {
                string dolphinData = settings.emulatorDataPath;
                AddExisting(roots, Path.Combine(dolphinData, "Wii"));
                AddExisting(roots, Path.Combine(exeRoot, "User", "Wii"));
            }''')

old_storage = r'''        private void RenderGameCubeMemoryCards(List<string> roots)
        {
            titleText.Text = "Memory Card"; subtitleText.Text = "Slot A and Slot B";
            Grid body = new Grid { Margin = new Thickness(26, 6, 26, 20) }; body.ColumnDefinitions.Add(new ColumnDefinition()); body.ColumnDefinitions.Add(new ColumnDefinition()); contentHost.Children.Add(body);
            for (int i = 0; i < 2; i++)
            {
                string path = i < roots.Count ? roots[i] : String.Empty; Border slot = new Border { Margin = new Thickness(18), CornerRadius = new CornerRadius(32), Background = new SolidColorBrush(Color.FromArgb(225, 47, 34, 101)), BorderBrush = new SolidColorBrush(i == 0 ? Color.FromRgb(110, 224, 255) : Color.FromRgb(255, 172, 89)), BorderThickness = new Thickness(4), Padding = new Thickness(26) };
                StackPanel panel = new StackPanel(); panel.Children.Add(new TextBlock { Text = "MEMORY CARD SLOT " + (i == 0 ? "A" : "B"), FontSize = 25, FontWeight = FontWeights.Bold, Foreground = Brushes.White, HorizontalAlignment = HorizontalAlignment.Center });
                panel.Children.Add(new Border { Width = 180, Height = 112, Margin = new Thickness(0, 30, 0, 24), CornerRadius = new CornerRadius(18), Background = new SolidColorBrush(Color.FromRgb(52, 53, 62)), BorderBrush = new SolidColorBrush(Color.FromRgb(169, 166, 184)), BorderThickness = new Thickness(3), Child = new TextBlock { Text = String.IsNullOrWhiteSpace(path) ? "EMPTY" : "CARD", FontSize = 28, Foreground = Brushes.White, HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center } });
                string captured = path; Button open = CreateShellAction(String.IsNullOrWhiteSpace(path) ? "No card detected" : "Open Card", String.IsNullOrWhiteSpace(path) ? "Configure Dolphin memory cards" : path, delegate { if (!String.IsNullOrWhiteSpace(captured)) Process.Start("explorer.exe", "\"" + captured + "\""); }, Color.FromRgb(91, 70, 176)); panel.Children.Add(open); actions.Add(new ConsolePlatformAction { Button = open, Invoke = delegate { if (!String.IsNullOrWhiteSpace(captured)) Process.Start("explorer.exe", "\"" + captured + "\""); }, Name = "Slot" }); slot.Child = panel; Grid.SetColumn(slot, i); body.Children.Add(slot);
            }
            AddFloatingBackup(body, BackupSaves);
        }

        private void RenderWiiDataManagement(List<string> roots)
        {
            titleText.Text = "Save Data"; subtitleText.Text = "Wii Console and SD Card";
            StackPanel panel = new StackPanel { Margin = new Thickness(26, 4, 26, 20) }; contentHost.Children.Add(new ScrollViewer { VerticalScrollBarVisibility = ScrollBarVisibility.Hidden, Content = panel });
            Grid tabs = new Grid { Height = 64, Margin = new Thickness(0, 0, 0, 20) }; tabs.ColumnDefinitions.Add(new ColumnDefinition()); tabs.ColumnDefinitions.Add(new ColumnDefinition());
            tabs.Children.Add(CreateWiiTab("Wii", true)); Button sd = CreateWiiTab("SD Card", false); Grid.SetColumn(sd, 1); tabs.Children.Add(sd); panel.Children.Add(tabs);
            WrapPanel channels = new WrapPanel(); panel.Children.Add(channels);
            foreach (string rootPath in roots) { string captured = rootPath; Button tile = CreateChannelTile(Path.GetFileName(rootPath.TrimEnd(Path.DirectorySeparatorChar)), captured, delegate { Process.Start("explorer.exe", "\"" + captured + "\""); }); channels.Children.Add(tile); actions.Add(new ConsolePlatformAction { Button = tile, Invoke = delegate { Process.Start("explorer.exe", "\"" + captured + "\""); }, Name = captured }); }
            Button backup = CreateChannelTile("Back Up", "Copy save data", BackupSaves); channels.Children.Add(backup); actions.Add(new ConsolePlatformAction { Button = backup, Invoke = BackupSaves, Name = "Back Up" });
        }'''
new_storage = r'''        private void RenderGameCubeMemoryCards(List<string> roots)
        {
            titleText.Text = "Memory Card"; subtitleText.Text = "Native Slot A / Slot B save browser";
            List<GameCubeMemoryCardInfo> cards = ScanGameCubeMemoryCards(roots);
            Grid body = new Grid { Margin = new Thickness(30, 6, 30, 20) }; body.ColumnDefinitions.Add(new ColumnDefinition()); body.ColumnDefinitions.Add(new ColumnDefinition()); contentHost.Children.Add(body);
            for (int slotIndex = 0; slotIndex < 2; slotIndex++)
            {
                GameCubeMemoryCardInfo card = slotIndex < cards.Count ? cards[slotIndex] : null;
                Color accent = slotIndex == 0 ? Color.FromRgb(101, 217, 255) : Color.FromRgb(121, 255, 172);
                Border slot = new Border { Margin = new Thickness(14), CornerRadius = new CornerRadius(38), Background = new SolidColorBrush(Color.FromArgb(220, 35, 27, 82)), BorderBrush = new SolidColorBrush(accent), BorderThickness = new Thickness(4), Padding = new Thickness(20) };
                Grid panel = new Grid(); panel.RowDefinitions.Add(new RowDefinition { Height = new GridLength(78) }); panel.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) }); panel.RowDefinitions.Add(new RowDefinition { Height = new GridLength(74) });
                StackPanel heading = new StackPanel { HorizontalAlignment = HorizontalAlignment.Center }; heading.Children.Add(new TextBlock { Text = "MEMORY CARD  " + (slotIndex == 0 ? "A" : "B"), FontSize = 24, FontWeight = FontWeights.Bold, Foreground = Brushes.White, HorizontalAlignment = HorizontalAlignment.Center }); heading.Children.Add(new TextBlock { Text = card == null ? "No card detected" : card.Saves.Count.ToString(CultureInfo.InvariantCulture) + " save(s)  •  " + Math.Max(0, card.TotalBlocks - card.FreeBlocks).ToString(CultureInfo.InvariantCulture) + " / " + card.TotalBlocks.ToString(CultureInfo.InvariantCulture) + " blocks", FontSize = 12, Foreground = new SolidColorBrush(Color.FromRgb(207, 202, 232)), HorizontalAlignment = HorizontalAlignment.Center }); panel.Children.Add(heading);
                WrapPanel saveGrid = new WrapPanel { HorizontalAlignment = HorizontalAlignment.Center };
                if (card != null)
                {
                    foreach (GameCubeSaveEntry save in card.Saves.Take(18))
                    {
                        GameCubeSaveEntry capturedSave = save;
                        Button saveTile = CreateGameCubeNativeSaveTile(save, accent, delegate { ShowNotice(capturedSave.Name + "  •  " + capturedSave.GameCode + "  •  " + capturedSave.Blocks.ToString(CultureInfo.InvariantCulture) + " blocks"); });
                        saveGrid.Children.Add(saveTile); actions.Add(new ConsolePlatformAction { Button = saveTile, Invoke = delegate { ShowNotice(capturedSave.Name + "  •  " + capturedSave.GameCode + "  •  " + capturedSave.Blocks.ToString(CultureInfo.InvariantCulture) + " blocks"); }, Name = save.Name });
                    }
                }
                if (saveGrid.Children.Count == 0) saveGrid.Children.Add(new TextBlock { Text = "EMPTY", FontSize = 34, Foreground = new SolidColorBrush(Color.FromArgb(180, 255, 255, 255)), Margin = new Thickness(20), HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center });
                ScrollViewer scroller = new ScrollViewer { VerticalScrollBarVisibility = ScrollBarVisibility.Hidden, Content = saveGrid }; Grid.SetRow(scroller, 1); panel.Children.Add(scroller);
                GameCubeMemoryCardInfo capturedCard = card; Button backup = CreateShellAction("BACK UP CARD " + (slotIndex == 0 ? "A" : "B"), card == null ? "No card detected" : Path.GetFileName(card.Path), delegate { if (capturedCard != null) BackupNativeSavePath(capturedCard.Path, "GameCube-Card-" + capturedCard.Slot); }, Color.FromRgb(78, 59, 151)); backup.Margin = new Thickness(30, 8, 30, 0); Grid.SetRow(backup, 2); panel.Children.Add(backup); actions.Add(new ConsolePlatformAction { Button = backup, Invoke = delegate { if (capturedCard != null) BackupNativeSavePath(capturedCard.Path, "GameCube-Card-" + capturedCard.Slot); }, Name = "Back Up Card " + (slotIndex == 0 ? "A" : "B") });
                slot.Child = panel; Grid.SetColumn(slot, slotIndex); body.Children.Add(slot);
            }
        }

        private Button CreateGameCubeNativeSaveTile(GameCubeSaveEntry save, Color accent, Action invoke)
        {
            Button button = new Button { Width = 190, Height = 108, Margin = new Thickness(7), Padding = new Thickness(10), Background = new SolidColorBrush(Color.FromRgb(42, 38, 67)), BorderBrush = new SolidColorBrush(accent), BorderThickness = new Thickness(2), RenderTransformOrigin = new Point(0.5, 0.5) };
            Grid grid = new Grid(); grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(48) }); grid.ColumnDefinitions.Add(new ColumnDefinition());
            Border icon = new Border { Width = 40, Height = 40, CornerRadius = new CornerRadius(8), Background = new SolidColorBrush(accent), VerticalAlignment = VerticalAlignment.Center, Child = new TextBlock { Text = save.GameCode.Length > 0 ? save.GameCode.Substring(0, 1) : "G", FontSize = 20, FontWeight = FontWeights.Bold, Foreground = Brushes.White, HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center } }; grid.Children.Add(icon);
            StackPanel text = new StackPanel { Margin = new Thickness(8, 0, 0, 0), VerticalAlignment = VerticalAlignment.Center }; text.Children.Add(new TextBlock { Text = save.Name, FontSize = 12, FontWeight = FontWeights.Bold, Foreground = Brushes.White, TextTrimming = TextTrimming.CharacterEllipsis }); text.Children.Add(new TextBlock { Text = save.GameCode + "  •  " + save.Blocks.ToString(CultureInfo.InvariantCulture) + " blocks", FontSize = 9, Foreground = new SolidColorBrush(Color.FromRgb(204, 198, 226)) }); Grid.SetColumn(text, 1); grid.Children.Add(text); button.Content = grid; button.Click += delegate { invoke(); }; return button;
        }

        private void RenderWiiDataManagement(List<string> roots)
        {
            titleText.Text = "Save Data"; subtitleText.Text = "System Memory";
            List<WiiSaveEntry> saves = ScanWiiSaves(roots);
            Grid body = new Grid { Margin = new Thickness(54, 6, 54, 24) }; body.RowDefinitions.Add(new RowDefinition { Height = new GridLength(68) }); body.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) }); contentHost.Children.Add(body);
            Border heading = new Border { Background = new SolidColorBrush(Color.FromRgb(241, 247, 249)), BorderBrush = new SolidColorBrush(Color.FromRgb(96, 194, 220)), BorderThickness = new Thickness(2), CornerRadius = new CornerRadius(18), Padding = new Thickness(20, 10, 20, 10), Child = new TextBlock { Text = saves.Count.ToString(CultureInfo.InvariantCulture) + " saved title(s)", FontSize = 22, Foreground = new SolidColorBrush(Color.FromRgb(72, 91, 98)), HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center } }; body.Children.Add(heading);
            WrapPanel channels = new WrapPanel { HorizontalAlignment = HorizontalAlignment.Center, Margin = new Thickness(0, 14, 0, 0) };
            foreach (WiiSaveEntry save in saves)
            {
                WiiSaveEntry captured = save; Button tile = CreateChannelTile(save.Name, save.TitleId + "  •  " + FormatBytes(save.Size), delegate { BackupNativeSavePath(captured.Path, "Wii-" + captured.TitleId); }); channels.Children.Add(tile); actions.Add(new ConsolePlatformAction { Button = tile, Invoke = delegate { BackupNativeSavePath(captured.Path, "Wii-" + captured.TitleId); }, Name = save.Name });
            }
            if (saves.Count == 0) channels.Children.Add(new Border { Width = 300, Height = 150, Margin = new Thickness(12), Background = Brushes.White, BorderBrush = new SolidColorBrush(Color.FromRgb(135, 203, 221)), BorderThickness = new Thickness(3), Child = new TextBlock { Text = "No save data detected", FontSize = 18, Foreground = new SolidColorBrush(Color.FromRgb(82, 101, 109)), HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center } });
            Button backupAll = CreateChannelTile("Back Up All", "Create a recoverable Huymaier copy", BackupSaves); channels.Children.Add(backupAll); actions.Add(new ConsolePlatformAction { Button = backupAll, Invoke = BackupSaves, Name = "Back Up All" });
            ScrollViewer scroller = new ScrollViewer { VerticalScrollBarVisibility = ScrollBarVisibility.Hidden, Content = channels }; Grid.SetRow(scroller, 1); body.Children.Add(scroller);
        }

        private static ushort ReadBe16(byte[] data, int offset) { return (ushort)((data[offset] << 8) | data[offset + 1]); }
        private static short ReadBeS16(byte[] data, int offset) { return unchecked((short)ReadBe16(data, offset)); }
        private static uint ReadBe32(byte[] data, int offset) { return ((uint)data[offset] << 24) | ((uint)data[offset + 1] << 16) | ((uint)data[offset + 2] << 8) | data[offset + 3]; }

        private List<GameCubeMemoryCardInfo> ScanGameCubeMemoryCards(List<string> roots)
        {
            List<GameCubeMemoryCardInfo> cards = new List<GameCubeMemoryCardInfo>();
            List<string> candidates = new List<string>();
            foreach (string rootPath in roots)
            {
                try { foreach (string file in Directory.EnumerateFiles(rootPath, "*.raw", SearchOption.AllDirectories).Take(12)) if (!candidates.Contains(file, StringComparer.OrdinalIgnoreCase)) candidates.Add(file); } catch { }
            }
            candidates = candidates.OrderBy(delegate(string path) { return Path.GetFileName(path); }, StringComparer.CurrentCultureIgnoreCase).ToList();
            for (int i = 0; i < candidates.Count && cards.Count < 2; i++)
            {
                GameCubeMemoryCardInfo card = ParseGameCubeRawCard(candidates[i], cards.Count == 0 ? "A" : "B");
                if (card != null) cards.Add(card);
            }
            return cards;
        }

        private GameCubeMemoryCardInfo ParseGameCubeRawCard(string path, string slot)
        {
            try
            {
                const int blockSize = 0x2000;
                FileInfo info = new FileInfo(path);
                if (!info.Exists || info.Length < blockSize * 6 || info.Length % blockSize != 0) return null;
                byte[] metadata = new byte[blockSize * 5];
                using (FileStream stream = File.Open(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))
                {
                    if (stream.Read(metadata, 0, metadata.Length) != metadata.Length) return null;
                }
                int dir0 = blockSize, dir1 = blockSize * 2, bat0 = blockSize * 3, bat1 = blockSize * 4;
                int activeDir = ReadBeS16(metadata, dir0 + 0x1FFA) >= ReadBeS16(metadata, dir1 + 0x1FFA) ? dir0 : dir1;
                int activeBat = ReadBeS16(metadata, bat0 + 0x0004) >= ReadBeS16(metadata, bat1 + 0x0004) ? bat0 : bat1;
                GameCubeMemoryCardInfo card = new GameCubeMemoryCardInfo { Slot = slot, Path = path, TotalBlocks = (int)(info.Length / blockSize), FreeBlocks = ReadBe16(metadata, activeBat + 0x0006) };
                for (int index = 0; index < 127; index++)
                {
                    int entry = activeDir + index * 0x40;
                    if (metadata[entry] == 0xFF && metadata[entry + 1] == 0xFF && metadata[entry + 2] == 0xFF && metadata[entry + 3] == 0xFF) continue;
                    string gameCode = Encoding.ASCII.GetString(metadata, entry, 4).Trim('\0', ' ', '\u00ff');
                    int nameLength = 0; while (nameLength < 0x20 && metadata[entry + 0x08 + nameLength] != 0 && metadata[entry + 0x08 + nameLength] != 0xFF) nameLength++;
                    string fileName = nameLength > 0 ? Encoding.ASCII.GetString(metadata, entry + 0x08, nameLength).Trim() : gameCode;
                    uint seconds = ReadBe32(metadata, entry + 0x28);
                    DateTime modified = new DateTime(2000, 1, 1, 0, 0, 0, DateTimeKind.Local).AddSeconds(Math.Min(seconds, 3155760000U));
                    card.Saves.Add(new GameCubeSaveEntry { Name = String.IsNullOrWhiteSpace(fileName) ? gameCode : fileName, GameCode = gameCode, Blocks = ReadBe16(metadata, entry + 0x38), Modified = modified, CardPath = path });
                }
                return card;
            }
            catch (Exception ex) { WritePlatformLog("GameCube memory-card parser skipped " + path + ": " + ex.Message, "WARN"); return null; }
        }

        private List<WiiSaveEntry> ScanWiiSaves(List<string> roots)
        {
            List<WiiSaveEntry> result = new List<WiiSaveEntry>();
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
                        string data = Path.Combine(low, "data"); if (!Directory.Exists(data)) continue;
                        long size = GetPathSize(data); if (size <= 0) continue;
                        string lowName = Path.GetFileName(low); string titleId = Path.GetFileName(high) + lowName;
                        string code = DecodeWiiTitleCode(lowName); string display = String.IsNullOrWhiteSpace(code) ? "Save " + lowName.ToUpperInvariant() : "Save " + code;
                        DateTime modified = Directory.GetLastWriteTime(data);
                        result.Add(new WiiSaveEntry { Name = display, TitleId = titleId.ToUpperInvariant(), Path = data, Size = size, Modified = modified });
                    }
                }
            }
            return result.OrderBy(delegate(WiiSaveEntry entry) { return entry.Name; }, StringComparer.CurrentCultureIgnoreCase).ToList();
        }

        private static string DecodeWiiTitleCode(string lowHex)
        {
            try
            {
                if (String.IsNullOrWhiteSpace(lowHex) || lowHex.Length != 8) return String.Empty;
                byte[] raw = new byte[4];
                for (int i = 0; i < 4; i++) raw[i] = Convert.ToByte(lowHex.Substring(i * 2, 2), 16);
                string code = Encoding.ASCII.GetString(raw);
                return code.All(delegate(char c) { return c >= 0x20 && c <= 0x7E; }) ? code : String.Empty;
            }
            catch { return String.Empty; }
        }

        private void BackupNativeSavePath(string source, string label)
        {
            if (String.IsNullOrWhiteSpace(source) || (!File.Exists(source) && !Directory.Exists(source))) { ShowNotice("Save data is not available"); return; }
            try
            {
                string targetRoot = Path.Combine(dataRoot, "Backups", "Native", DateTime.Now.ToString("yyyyMMdd-HHmmss-fff", CultureInfo.InvariantCulture));
                Directory.CreateDirectory(targetRoot);
                string safe = Sanitize(label);
                if (File.Exists(source)) File.Copy(source, Path.Combine(targetRoot, safe + Path.GetExtension(source)), true);
                else CopyDirectory(source, Path.Combine(targetRoot, safe), 20000);
                ShowNotice("Save data backed up safely");
            }
            catch (Exception ex) { ShowNotice("Backup failed: " + ex.Message); }
        }'''
replace_once("Native/HuymaierConsole.ConsolePlatforms.cs", old_storage, new_storage)

replace_once("Native/HuymaierConsole.ConsolePlatforms.cs",
'''                if (!String.IsNullOrWhiteSpace(dashboardSubpage))
                {
                    if (dashboardSubpage == "wii-start") { dashboardSubpage = String.Empty; shellSelectedGame = null; selected = 0; RenderPage(); return; }
                    dashboardSubpage = String.Empty; selectedXboxSave = null; shellSelectedGame = null; selected = 0; chromeNavigationActive = definition.Shell == "Xbox" || (definition.Shell == "Xbox360" && IsMetro()); RenderPage(); return;
                }''',
'''                if (!String.IsNullOrWhiteSpace(dashboardSubpage))
                {
                    if (dashboardSubpage == "wii-start") { dashboardSubpage = String.Empty; shellSelectedGame = null; selected = 0; RenderPage(); return; }
                    if (dashboardSubpage == "wii-data" || dashboardSubpage == "wii-settings") { dashboardSubpage = "wii-options"; selected = 0; RenderPage(); return; }
                    if (dashboardSubpage == "wii-options") { dashboardSubpage = String.Empty; selected = 0; RenderPage(); return; }
                    dashboardSubpage = String.Empty; selectedXboxSave = null; shellSelectedGame = null; selected = 0; chromeNavigationActive = definition.Shell == "Xbox" || (definition.Shell == "Xbox360" && IsMetro()); RenderPage(); return;
                }''')

replace_once("HuymaierEmulatorPlatforms.ps1",
'''        $output=@(& $installer -PlatformId $id -DestinationRoot $root -ConsoleRoot $script:BaseDir)
        if($LASTEXITCODE -ne 0){throw "Installer exited with code $LASTEXITCODE."}''',
'''        $output=@()
        try{$output=@(& $installer -PlatformId $id -DestinationRoot $root -ConsoleRoot $script:BaseDir)}catch{throw}
        if(-not $?){throw 'The emulator installer script did not complete successfully.'}''')

replace_once("HuymaierConsole.ps1",
'''        OnlineArtworkEnabled = $true
        PlatformBackgroundsEnabled = $true''',
'''        OnlineArtworkEnabled = $true
        SteamGridDbApiKey = ''
        PlatformBackgroundsEnabled = $true''')

replace_once("HuymaierConsole.ps1",
'''LibrarySchemaVersion','KeyboardTheme','ShowFpsCounter','OnlineArtworkEnabled','PlatformBackgroundsEnabled','FavoriteGames')) {''',
'''LibrarySchemaVersion','KeyboardTheme','ShowFpsCounter','OnlineArtworkEnabled','SteamGridDbApiKey','PlatformBackgroundsEnabled','FavoriteGames')) {''')

replace_once("HuymaierArtworkWorker.ps1",
'''function Try-GogCatalogArt{''',
r'''function Get-SteamGridDbKey{
    try{
        $value=[string](Get-Prop $config 'SteamGridDbApiKey' '')
        if(-not [string]::IsNullOrWhiteSpace($value)){return $value.Trim()}
    }catch{}
    try{
        $envKey=[string]$env:HUYMAIER_STEAMGRIDDB_API_KEY
        if(-not [string]::IsNullOrWhiteSpace($envKey)){return $envKey.Trim()}
    }catch{}
    return ''
}

function Get-SteamAppId{
    param($Game)
    $id=[string](Get-Prop $Game 'Id' '')
    $providerId=[string](Get-Prop $Game 'ProviderGameId' '')
    $launch=[string](Get-Prop $Game 'LaunchTarget' '')
    if($id -match '(?i)^Steam:(\d+)$'){return $matches[1]}
    if(([string](Get-Prop $Game 'Source' '')) -match '(?i)^steam$' -and $providerId -match '^\d+$'){return $providerId}
    if($launch -match '(?i)rungameid/(\d+)'){return $matches[1]}
    return ''
}

function Try-SteamGridDbArt{
    param($Game,[string]$Target)
    $key=Get-SteamGridDbKey
    if(-not $key){return ''}
    $headers=@{'Authorization'=('Bearer '+$key);'User-Agent'='HuymaierConsole/0.26.3';'Accept'='application/json'}
    $appId=Get-SteamAppId $Game
    $gridResponse=$null
    try{
        if($appId){
            $gridResponse=Invoke-RestMethod -Uri ("https://www.steamgriddb.com/api/v2/grids/steam/"+$appId+"?dimensions=600x900,342x482,660x930&nsfw=false&humor=false") -Headers $headers -TimeoutSec 15
        }else{
            $name=[string](Get-Prop $Game 'Name' '')
            if(-not $name){return ''}
            $best=$null;$bestScore=0.0
            foreach($variant in @(Get-NameVariants $name)){
                $search=Invoke-RestMethod -Uri ("https://www.steamgriddb.com/api/v2/search/autocomplete/"+[uri]::EscapeDataString($variant)) -Headers $headers -TimeoutSec 15
                foreach($candidate in @(Get-Prop $search 'data' @())){
                    $score=Get-NameScore $name ([string](Get-Prop $candidate 'name' ''))
                    if($score -gt $bestScore){$bestScore=$score;$best=$candidate}
                }
                if($bestScore -ge .94){break}
            }
            if($null -eq $best -or $bestScore -lt .52){return ''}
            $sgdbId=[string](Get-Prop $best 'id' '')
            if(-not $sgdbId){return ''}
            $gridResponse=Invoke-RestMethod -Uri ("https://www.steamgriddb.com/api/v2/grids/game/"+$sgdbId+"?dimensions=600x900,342x482,660x930&nsfw=false&humor=false") -Headers $headers -TimeoutSec 15
        }
        $ranked=@(Get-Prop $gridResponse 'data' @())|Sort-Object @{Expression={ [double](Get-Prop $_ 'score' (Get-Prop $_ 'upvotes' 0)) };Descending=$true}
        foreach($grid in $ranked){
            $url=[string](Get-Prop $grid 'url' '')
            if(-not $url){continue}
            $width=[int](Get-Prop $grid 'width' 0);$height=[int](Get-Prop $grid 'height' 0)
            if($width -gt 0 -and $height -gt 0 -and $height -lt $width){continue}
            $found=Download-Art $url $Target
            if($found){return $found}
        }
    }catch{}
    return ''
}

function Try-GogCatalogArt{''')

replace_once("HuymaierArtworkWorker.ps1",
'''        if(-not $found){$found=Try-LibretroArt $game $target}
        if(-not $found -and $source -match '(?i)gog|pc|windows|custom|generic'){ $found=Try-GogCatalogArt $game $target }
        if(-not $found){$found=Try-SteamEquivalentArt $game $target}
        if(-not $found){$found=Try-WikipediaArt $game $target}''',
'''        if(-not $found){$found=Try-LibretroArt $game $target}
        if(-not $found -and $source -match '(?i)^steam$'){$found=Try-SteamEquivalentArt $game $target}
        if(-not $found -and $source -match '(?i)steam|epic|gog|amazon|ea|ubisoft|battlenet|battle\\.net|rockstar|xbox|pc|windows|custom|generic'){ $found=Try-SteamGridDbArt $game $target }
        if(-not $found -and $source -match '(?i)gog|pc|windows|custom|generic'){ $found=Try-GogCatalogArt $game $target }
        if(-not $found){$found=Try-SteamEquivalentArt $game $target}
        if(-not $found){$found=Try-WikipediaArt $game $target}''')

replace_once("manifest.json", '"build": "native-console-fidelity-rc3"', '"build": "native-console-fidelity-rc4"')

print("RC4 user-feedback patch applied successfully.")
