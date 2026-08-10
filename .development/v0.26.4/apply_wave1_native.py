from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
path=ROOT/'Native'/'HuymaierConsole.ConsolePlatforms.cs'
text=path.read_text(encoding='utf-8-sig')

def once(old,new,label):
    global text
    count=text.count(old)
    if count!=1:
        raise SystemExit(f'{label}: expected one match, found {count}')
    text=text.replace(old,new,1)

# State for PSP XMB and shared Wave-1 native surfaces.
once(
    '        private int gameCubePreviousPage;\n',
    '        private int gameCubePreviousPage;\n        private int pspCategoryIndex;\n        private int pspItemIndex;\n',
    'wave1 state fields'
)
once(
    '            gameCubePreviousPage = -1;\n',
    '            gameCubePreviousPage = -1;\n            pspCategoryIndex = 0;\n            pspItemIndex = 0;\n',
    'wave1 state initialization'
)

# Native definitions. Unknown ids must never silently become Xbox 360.
anchor='''            else if (key == "XBOX")
            {
                d.DisplayName = "Xbox"; d.Subtitle = "Original Xbox Dashboard"; d.Shell = "Xbox";
                d.PrimaryBackend = "xemu"; d.FallbackBackend = "Cxbx-Reloaded";
                d.PrimaryExecutableNames = new string[] { "xemu.exe" };
                d.FallbackExecutableNames = new string[] { "cxbxr-ldr.exe", "Cxbx.exe" };
                d.GameExtensions = new string[] { ".iso", ".xiso", ".xbe" };
                d.ColorA = Color.FromRgb(2, 10, 2); d.ColorB = Color.FromRgb(18, 63, 8); d.Accent = Color.FromRgb(96, 197, 24);
            }
            else
            {
'''
replacement='''            else if (key == "3DS")
            {
                d.DisplayName = "Nintendo 3DS"; d.Subtitle = "HOME Menu"; d.Shell = "3DS";
                d.PrimaryBackend = "Azahar"; d.FallbackBackend = "Azahar Nightly";
                d.PrimaryExecutableNames = new string[] { "azahar.exe", "Azahar.exe" };
                d.FallbackExecutableNames = new string[] { "azahar.exe", "Azahar.exe" };
                d.GameExtensions = new string[] { ".3ds", ".cci", ".cxi", ".app", ".zcci", ".zcxi" };
                d.ColorA = Color.FromRgb(228, 232, 237); d.ColorB = Color.FromRgb(249, 250, 251); d.Accent = Color.FromRgb(72, 148, 203);
            }
            else if (key == "NDS")
            {
                d.DisplayName = "Nintendo DS"; d.Subtitle = "DS Menu"; d.Shell = "NDS";
                d.PrimaryBackend = "melonDS"; d.FallbackBackend = "melonDS Development";
                d.PrimaryExecutableNames = new string[] { "melonDS.exe" }; d.FallbackExecutableNames = new string[] { "melonDS.exe" };
                d.GameExtensions = new string[] { ".nds", ".srl", ".zip" };
                d.ColorA = Color.FromRgb(233, 241, 248); d.ColorB = Color.FromRgb(250, 252, 254); d.Accent = Color.FromRgb(70, 145, 202);
            }
            else if (key == "DSI")
            {
                d.DisplayName = "Nintendo DSi"; d.Subtitle = "DSi Menu"; d.Shell = "DSI";
                d.PrimaryBackend = "melonDS"; d.FallbackBackend = "melonDS Development";
                d.PrimaryExecutableNames = new string[] { "melonDS.exe" }; d.FallbackExecutableNames = new string[] { "melonDS.exe" };
                d.GameExtensions = new string[] { ".nds", ".srl", ".app" };
                d.ColorA = Color.FromRgb(243, 245, 247); d.ColorB = Color.FromRgb(255, 255, 255); d.Accent = Color.FromRgb(67, 181, 222);
            }
            else if (key == "DREAMCAST")
            {
                d.DisplayName = "Sega Dreamcast"; d.Subtitle = "Dreamcast Main Menu"; d.Shell = "Dreamcast";
                d.PrimaryBackend = "Flycast"; d.FallbackBackend = "Flycast Development";
                d.PrimaryExecutableNames = new string[] { "flycast.exe", "Flycast.exe" }; d.FallbackExecutableNames = new string[] { "flycast.exe", "Flycast.exe" };
                d.GameExtensions = new string[] { ".gdi", ".cdi", ".chd", ".cue" };
                d.ColorA = Color.FromRgb(190, 220, 246); d.ColorB = Color.FromRgb(58, 124, 195); d.Accent = Color.FromRgb(240, 104, 45);
            }
            else if (key == "SATURN")
            {
                d.DisplayName = "Sega Saturn"; d.Subtitle = "Saturn System"; d.Shell = "Saturn";
                d.PrimaryBackend = "Mednafen"; d.FallbackBackend = "Kronos";
                d.PrimaryExecutableNames = new string[] { "mednafen.exe" }; d.FallbackExecutableNames = new string[] { "kronos.exe", "Kronos.exe" };
                d.GameExtensions = new string[] { ".cue", ".chd", ".ccd", ".mds", ".iso" };
                d.ColorA = Color.FromRgb(7, 21, 65); d.ColorB = Color.FromRgb(15, 102, 159); d.Accent = Color.FromRgb(249, 64, 120);
            }
            else if (key == "PSP")
            {
                d.DisplayName = "PlayStation Portable"; d.Subtitle = "XMB"; d.Shell = "PSP";
                d.PrimaryBackend = "PPSSPP"; d.FallbackBackend = "PPSSPP Development";
                d.PrimaryExecutableNames = new string[] { "PPSSPPWindows64.exe", "PPSSPPWindows.exe", "PPSSPPQt.exe" };
                d.FallbackExecutableNames = new string[] { "PPSSPPWindows64.exe", "PPSSPPWindows.exe", "PPSSPPQt.exe" };
                d.GameExtensions = new string[] { ".iso", ".cso", ".pbp", ".elf" };
                d.ColorA = Color.FromRgb(20, 91, 166); d.ColorB = Color.FromRgb(1, 28, 79); d.Accent = Color.FromRgb(102, 196, 255);
            }
            else if (key == "XBOX")
            {
                d.DisplayName = "Xbox"; d.Subtitle = "Original Xbox Dashboard"; d.Shell = "Xbox";
                d.PrimaryBackend = "xemu"; d.FallbackBackend = "Cxbx-Reloaded";
                d.PrimaryExecutableNames = new string[] { "xemu.exe" };
                d.FallbackExecutableNames = new string[] { "cxbxr-ldr.exe", "Cxbx.exe" };
                d.GameExtensions = new string[] { ".iso", ".xiso", ".xbe" };
                d.ColorA = Color.FromRgb(2, 10, 2); d.ColorB = Color.FromRgb(18, 63, 8); d.Accent = Color.FromRgb(96, 197, 24);
            }
            else if (key == "XBOX360")
            {
'''
once(anchor,replacement,'wave1 native definitions')

# Light-shell classification and console-specific backgrounds.
once(
    '            return definition.Shell == "Wii" || definition.Shell == "WiiU";\n',
    '            return definition.Shell == "Wii" || definition.Shell == "WiiU" || definition.Shell == "3DS" || definition.Shell == "NDS" || definition.Shell == "DSI" || definition.Shell == "Dreamcast";\n',
    'wave1 light shell classification'
)
once(
    '''            if (definition.Shell == "Switch")
            {
                LinearGradientBrush s = new LinearGradientBrush(Color.FromRgb(43, 44, 48), Color.FromRgb(66, 67, 72), 90);
                return s;
            }
            LinearGradientBrush brush = new LinearGradientBrush();
''',
    '''            if (definition.Shell == "Switch")
            {
                LinearGradientBrush s = new LinearGradientBrush(Color.FromRgb(43, 44, 48), Color.FromRgb(66, 67, 72), 90);
                return s;
            }
            if (definition.Shell == "PSP")
            {
                LinearGradientBrush psp = new LinearGradientBrush(); psp.StartPoint = new Point(0,0); psp.EndPoint = new Point(1,1);
                psp.GradientStops.Add(new GradientStop(Color.FromRgb(17,116,205),0)); psp.GradientStops.Add(new GradientStop(Color.FromRgb(2,48,119),0.58)); psp.GradientStops.Add(new GradientStop(Color.FromRgb(0,15,56),1)); return psp;
            }
            if (definition.Shell == "Saturn")
            {
                RadialGradientBrush saturn = new RadialGradientBrush(); saturn.Center = new Point(0.5,0.48); saturn.GradientOrigin = new Point(0.5,0.48);
                saturn.GradientStops.Add(new GradientStop(Color.FromRgb(31,126,178),0)); saturn.GradientStops.Add(new GradientStop(Color.FromRgb(7,35,89),0.55)); saturn.GradientStops.Add(new GradientStop(Color.FromRgb(2,8,29),1)); return saturn;
            }
            LinearGradientBrush brush = new LinearGradientBrush();
''',
    'wave1 backgrounds'
)

# PSP has XMB-local navigation. All other Wave-1 home surfaces can use action-grid navigation.
once(
    '            if (definition.Shell == "N64" && IsRootConsoleSurface()) { ProcessN64MenuCommand(command); return; }\n',
    '            if (definition.Shell == "N64" && IsRootConsoleSurface()) { ProcessN64MenuCommand(command); return; }\n            if (definition.Shell == "PSP" && IsRootConsoleSurface()) { ProcessPspXmbCommand(command); return; }\n',
    'psp xmb command dispatch'
)

# Wave-1 page dispatch occurs before the generic catch-all.
once(
    '            if (definition.Shell == "N64" && IsRootConsoleSurface()) { RenderN64GamePakLauncher(); return; }\n',
    '''            if (definition.Shell == "N64" && IsRootConsoleSurface()) { RenderN64GamePakLauncher(); return; }
            if (definition.Shell == "3DS") { if (IsRootConsoleSurface()) Render3dsHome(); else RenderWave1Subpage(); UpdateActionVisuals(); return; }
            if (definition.Shell == "NDS") { if (IsRootConsoleSurface()) RenderDsMenu(); else RenderWave1Subpage(); UpdateActionVisuals(); return; }
            if (definition.Shell == "DSI") { if (IsRootConsoleSurface()) RenderDsiMenu(); else RenderWave1Subpage(); UpdateActionVisuals(); return; }
            if (definition.Shell == "Dreamcast") { if (IsRootConsoleSurface()) RenderDreamcastMenu(); else RenderWave1Subpage(); UpdateActionVisuals(); return; }
            if (definition.Shell == "Saturn") { if (IsRootConsoleSurface()) RenderSaturnMenu(); else RenderWave1Subpage(); UpdateActionVisuals(); return; }
            if (definition.Shell == "PSP") { if (IsRootConsoleSurface()) RenderPspXmb(); else RenderWave1Subpage(); UpdateActionVisuals(); return; }
''',
    'wave1 render dispatch'
)

# Do not let generic RenderGames erase the native shells if called by a local action.
once(
    '            if (definition.Shell == "Switch") { RenderSwitchHomeAuthentic(); return; }\n',
    '''            if (definition.Shell == "Switch") { RenderSwitchHomeAuthentic(); return; }
            if (definition.Shell == "3DS") { Render3dsHome(); return; }
            if (definition.Shell == "NDS") { RenderDsMenu(); return; }
            if (definition.Shell == "DSI") { RenderDsiMenu(); return; }
            if (definition.Shell == "Dreamcast") { RenderDreamcastMenu(); return; }
            if (definition.Shell == "Saturn") { RenderSaturnMenu(); return; }
            if (definition.Shell == "PSP") { RenderPspXmb(); return; }
''',
    'wave1 RenderGames guards'
)

# Platform-specific launch arguments.
once(
    '            if (definition.Shell == "GameCube" || definition.Shell == "Wii") return "-b -e " + quoted;\n',
    '''            if (definition.Shell == "GameCube" || definition.Shell == "Wii") return "-b -e " + quoted;
            if (definition.Shell == "3DS") return quoted;
            if (definition.Shell == "NDS" || definition.Shell == "DSI") return quoted;
            if (definition.Shell == "Dreamcast") return quoted;
            if (definition.Shell == "Saturn") return quoted;
            if (definition.Shell == "PSP") return quoted;
''',
    'wave1 launch arguments'
)

methods=r'''
        private Button CreateWave1Tile(string title, string detail, string glyph, Brush background, Brush foreground, Action invoke, double width, double height)
        {
            Button b = new Button { Width=width, Height=height, Margin=new Thickness(10), Padding=new Thickness(10), Background=background, BorderBrush=new SolidColorBrush(Color.FromArgb(130,255,255,255)), BorderThickness=new Thickness(2), RenderTransformOrigin=new Point(0.5,0.5) };
            StackPanel s = new StackPanel { VerticalAlignment=VerticalAlignment.Center };
            s.Children.Add(new TextBlock { Text=glyph, FontSize=Math.Max(24,height*0.22), FontWeight=FontWeights.Light, Foreground=foreground, HorizontalAlignment=HorizontalAlignment.Center });
            s.Children.Add(new TextBlock { Text=title, FontSize=15, FontWeight=FontWeights.SemiBold, Foreground=foreground, HorizontalAlignment=HorizontalAlignment.Center, TextAlignment=TextAlignment.Center, TextWrapping=TextWrapping.Wrap });
            if(!String.IsNullOrWhiteSpace(detail)) s.Children.Add(new TextBlock { Text=detail, FontSize=10, Foreground=foreground, Opacity=0.75, HorizontalAlignment=HorizontalAlignment.Center, TextAlignment=TextAlignment.Center, TextTrimming=TextTrimming.CharacterEllipsis, MaxWidth=Math.Max(80,width-20) });
            b.Content=s; b.Click+=delegate{invoke();}; return b;
        }

        private void AddWave1Action(Panel panel, Button button, string name, Action invoke, ConsolePlatformGame game)
        {
            panel.Children.Add(button); actions.Add(new ConsolePlatformAction { Button=button, Name=name, Invoke=invoke, Game=game });
        }

        private void OpenWave1Subpage(string name)
        {
            dashboardSubpage=name; selected=0; shellSelectedGame=null; RenderPage();
        }

        private void Render3dsHome()
        {
            titleText.Text=String.Empty; subtitleText.Text=String.Empty; columns=6;
            Grid body=new Grid{Margin=new Thickness(28,0,28,8)}; body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(0.38,GridUnitType.Star)}); body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(0.62,GridUnitType.Star)}); contentHost.Children.Add(body);
            Border top=new Border{CornerRadius=new CornerRadius(12),Margin=new Thickness(90,0,90,8),Background=new LinearGradientBrush(Color.FromRgb(236,240,243),Color.FromRgb(205,215,224),90),BorderBrush=new SolidColorBrush(Color.FromRgb(169,181,191)),BorderThickness=new Thickness(2)};
            Grid topInner=new Grid(); topInner.Children.Add(new TextBlock{Text=DateTime.Now.ToString("h:mm",CultureInfo.CurrentCulture),FontSize=54,FontWeight=FontWeights.Light,Foreground=new SolidColorBrush(Color.FromRgb(71,80,88)),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center,Margin=new Thickness(0,0,0,22)}); topInner.Children.Add(new TextBlock{Text=DateTime.Now.ToString("dddd, MMMM d",CultureInfo.CurrentCulture),FontSize=16,Foreground=new SolidColorBrush(Color.FromRgb(93,106,116)),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Bottom,Margin=new Thickness(0,0,0,24)}); top.Child=topInner; body.Children.Add(top);
            Border bottom=new Border{CornerRadius=new CornerRadius(14),Background=new SolidColorBrush(Color.FromRgb(248,249,250)),BorderBrush=new SolidColorBrush(Color.FromRgb(174,186,194)),BorderThickness=new Thickness(2),Padding=new Thickness(18)}; Grid.SetRow(bottom,1); body.Children.Add(bottom);
            ScrollViewer scroll=new ScrollViewer{VerticalScrollBarVisibility=ScrollBarVisibility.Hidden,HorizontalScrollBarVisibility=ScrollBarVisibility.Disabled}; WrapPanel wrap=new WrapPanel(); scroll.Content=wrap; bottom.Child=scroll;
            int shown=Math.Min(games.Count,18); for(int i=0;i<shown;i++){ConsolePlatformGame game=games[i];ConsolePlatformGame captured=game;Button tile=CreateWave1GameIcon(game,"3DS",Color.FromRgb(72,148,203),145,120,delegate{LaunchGame(captured,false);});AddWave1Action(wrap,tile,game.Name,delegate{LaunchGame(captured,false);},game);}
            Button library=CreateWave1Tile("Software Library",games.Count+" titles","▦",new SolidColorBrush(Color.FromRgb(91,168,219)),Brushes.White,delegate{OpenWave1Subpage("library");},145,120);AddWave1Action(wrap,library,"Software Library",delegate{OpenWave1Subpage("library");},null);
            Button data=CreateWave1Tile("Data Management","saves and installed data","▣",new SolidColorBrush(Color.FromRgb(239,157,56)),Brushes.White,delegate{OpenWave1Subpage("saves");},145,120);AddWave1Action(wrap,data,"Data Management",delegate{OpenWave1Subpage("saves");},null);
            Button system=CreateWave1Tile("System Settings","Azahar + Huymaier","⚙",new SolidColorBrush(Color.FromRgb(91,101,111)),Brushes.White,delegate{OpenWave1Subpage("settings");},145,120);AddWave1Action(wrap,system,"System Settings",delegate{OpenWave1Subpage("settings");},null);
        }

        private Button CreateWave1GameIcon(ConsolePlatformGame game,string fallbackText,Color accent,double width,double height,Action invoke)
        {
            Button b=new Button{Width=width,Height=height,Margin=new Thickness(10),Padding=new Thickness(3),Background=Brushes.White,BorderBrush=new SolidColorBrush(accent),BorderThickness=new Thickness(2),RenderTransformOrigin=new Point(0.5,0.5)};Grid g=new Grid();
            if(!String.IsNullOrWhiteSpace(game.Cover)&&File.Exists(game.Cover)){try{g.Children.Add(new Image{Source=LoadBitmap(game.Cover),Stretch=Stretch.UniformToFill});}catch{}}
            if(g.Children.Count==0)g.Children.Add(new TextBlock{Text=fallbackText,FontSize=22,FontWeight=FontWeights.Bold,Foreground=new SolidColorBrush(accent),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center});
            Border cap=new Border{Height=30,VerticalAlignment=VerticalAlignment.Bottom,Background=new SolidColorBrush(Color.FromArgb(225,250,251,252)),Padding=new Thickness(4)};cap.Child=new TextBlock{Text=game.Name,FontSize=9,Foreground=new SolidColorBrush(Color.FromRgb(50,58,64)),TextTrimming=TextTrimming.CharacterEllipsis,HorizontalAlignment=HorizontalAlignment.Center};g.Children.Add(cap);b.Content=g;b.Click+=delegate{invoke();};return b;
        }

        private void RenderDsMenu()
        {
            titleText.Text=String.Empty;subtitleText.Text=String.Empty;columns=2;Grid body=new Grid{Margin=new Thickness(120,0,120,6)};body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(0.48,GridUnitType.Star)});body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(0.52,GridUnitType.Star)});contentHost.Children.Add(body);
            Border top=new Border{Margin=new Thickness(20,0,20,8),CornerRadius=new CornerRadius(10),Background=Brushes.White,BorderBrush=new SolidColorBrush(Color.FromRgb(158,178,193)),BorderThickness=new Thickness(2)};Grid tg=new Grid();tg.ColumnDefinitions.Add(new ColumnDefinition());tg.ColumnDefinitions.Add(new ColumnDefinition());TextBlock clock=new TextBlock{Text=DateTime.Now.ToString("h:mm tt",CultureInfo.CurrentCulture),FontSize=40,Foreground=new SolidColorBrush(Color.FromRgb(70,85,97)),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center};tg.Children.Add(clock);TextBlock date=new TextBlock{Text=DateTime.Now.ToString("MMM\ndd",CultureInfo.CurrentCulture).ToUpperInvariant(),FontSize=30,TextAlignment=TextAlignment.Center,Foreground=new SolidColorBrush(Color.FromRgb(73,137,190)),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center};Grid.SetColumn(date,1);tg.Children.Add(date);top.Child=tg;body.Children.Add(top);
            UniformGrid menu=new UniformGrid{Columns=2,Rows=2,Margin=new Thickness(20,8,20,0)};Grid.SetRow(menu,1);body.Children.Add(menu);
            Action openLibrary=delegate{OpenWave1Subpage("library");};Action openSaves=delegate{OpenWave1Subpage("saves");};Action openSettings=delegate{OpenWave1Subpage("settings");};Action quickGame=delegate{if(games.Count>0)LaunchGame(games[0],false);else OpenWave1Subpage("settings");};
            Button game=CreateWave1Tile("DS Game Card",games.Count>0?games[0].Name:"No game card library configured","▣",new SolidColorBrush(Color.FromRgb(224,236,245)),new SolidColorBrush(Color.FromRgb(57,81,99)),quickGame,300,115);AddWave1Action(menu,game,"DS Game Card",quickGame,games.Count>0?games[0]:null);
            Button library=CreateWave1Tile("Game Library",games.Count+" titles","▦",new SolidColorBrush(Color.FromRgb(224,236,245)),new SolidColorBrush(Color.FromRgb(57,81,99)),openLibrary,300,115);AddWave1Action(menu,library,"Game Library",openLibrary,null);
            Button saves=CreateWave1Tile("Saved Data","manage DS saves","▤",new SolidColorBrush(Color.FromRgb(224,236,245)),new SolidColorBrush(Color.FromRgb(57,81,99)),openSaves,300,115);AddWave1Action(menu,saves,"Saved Data",openSaves,null);
            Button settingsButton=CreateWave1Tile("Settings","melonDS and system options","⚙",new SolidColorBrush(Color.FromRgb(224,236,245)),new SolidColorBrush(Color.FromRgb(57,81,99)),openSettings,300,115);AddWave1Action(menu,settingsButton,"Settings",openSettings,null);
        }

        private void RenderDsiMenu()
        {
            titleText.Text=String.Empty;subtitleText.Text=String.Empty;columns=5;Grid body=new Grid{Margin=new Thickness(48,0,48,8)};body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(0.39,GridUnitType.Star)});body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(0.61,GridUnitType.Star)});contentHost.Children.Add(body);
            Border top=new Border{Margin=new Thickness(100,0,100,10),CornerRadius=new CornerRadius(12),Background=new LinearGradientBrush(Color.FromRgb(245,246,248),Color.FromRgb(217,225,230),90),BorderBrush=new SolidColorBrush(Color.FromRgb(175,188,196)),BorderThickness=new Thickness(2)};Grid info=new Grid();info.Children.Add(new TextBlock{Text="Nintendo DSi",FontSize=31,FontWeight=FontWeights.Light,Foreground=new SolidColorBrush(Color.FromRgb(80,89,96)),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center});info.Children.Add(new TextBlock{Text=DateTime.Now.ToString("M/d/yyyy   h:mm tt",CultureInfo.CurrentCulture),FontSize=14,Foreground=new SolidColorBrush(Color.FromRgb(93,107,116)),HorizontalAlignment=HorizontalAlignment.Right,VerticalAlignment=VerticalAlignment.Top,Margin=new Thickness(0,16,20,0)});top.Child=info;body.Children.Add(top);
            Border lower=new Border{CornerRadius=new CornerRadius(12),Background=Brushes.White,BorderBrush=new SolidColorBrush(Color.FromRgb(184,194,201)),BorderThickness=new Thickness(2),Padding=new Thickness(18)};Grid.SetRow(lower,1);body.Children.Add(lower);ScrollViewer sc=new ScrollViewer{HorizontalScrollBarVisibility=ScrollBarVisibility.Hidden,VerticalScrollBarVisibility=ScrollBarVisibility.Disabled};StackPanel ribbon=new StackPanel{Orientation=Orientation.Horizontal,VerticalAlignment=VerticalAlignment.Center};sc.Content=ribbon;lower.Child=sc;
            foreach(ConsolePlatformGame game in games.Take(16)){ConsolePlatformGame captured=game;Button tile=CreateWave1GameIcon(game,"DSi",Color.FromRgb(67,181,222),155,155,delegate{LaunchGame(captured,false);});AddWave1Action(ribbon,tile,game.Name,delegate{LaunchGame(captured,false);},game);}
            Action lib=delegate{OpenWave1Subpage("library");};Action saves=delegate{OpenWave1Subpage("saves");};Action set=delegate{OpenWave1Subpage("settings");};
            Button l=CreateWave1Tile("Software",games.Count+" titles","▦",new SolidColorBrush(Color.FromRgb(224,242,249)),new SolidColorBrush(Color.FromRgb(53,105,129)),lib,155,155);AddWave1Action(ribbon,l,"Software",lib,null);
            Button d=CreateWave1Tile("Data Management","saves / NAND data","▤",new SolidColorBrush(Color.FromRgb(224,242,249)),new SolidColorBrush(Color.FromRgb(53,105,129)),saves,155,155);AddWave1Action(ribbon,d,"Data Management",saves,null);
            Button s=CreateWave1Tile("System Settings","melonDS DSi","⚙",new SolidColorBrush(Color.FromRgb(224,242,249)),new SolidColorBrush(Color.FromRgb(53,105,129)),set,155,155);AddWave1Action(ribbon,s,"System Settings",set,null);
        }

        private void RenderDreamcastMenu()
        {
            titleText.Text=String.Empty;subtitleText.Text=String.Empty;columns=2;Grid body=new Grid{Margin=new Thickness(150,18,150,18)};body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(64)});body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(1,GridUnitType.Star)});contentHost.Children.Add(body);
            TextBlock date=new TextBlock{Text=DateTime.Now.ToString("M/d/yyyy  HH:mm",CultureInfo.CurrentCulture),FontSize=19,Foreground=new SolidColorBrush(Color.FromRgb(57,65,73)),HorizontalAlignment=HorizontalAlignment.Right,VerticalAlignment=VerticalAlignment.Center};body.Children.Add(date);
            UniformGrid grid=new UniformGrid{Columns=2,Rows=2};Grid.SetRow(grid,1);body.Children.Add(grid);
            Action play=delegate{OpenWave1Subpage("library");};Action file=delegate{OpenWave1Subpage("saves");};Action music=delegate{OpenWave1Subpage("music");};Action settingsAction=delegate{OpenWave1Subpage("settings");};
            Button p=CreateDreamcastMenuTile("Play",games.Count+" games","◉",Color.FromRgb(230,151,92),play);AddWave1Action(grid,p,"Play",play,null);
            Button f=CreateDreamcastMenuTile("File","VMU / saved data","▯",Color.FromRgb(74,190,148),file);AddWave1Action(grid,f,"File",file,null);
            Button m=CreateDreamcastMenuTile("Music","dashboard audio","♪",Color.FromRgb(67,174,224),music);AddWave1Action(grid,m,"Music",music,null);
            Button s=CreateDreamcastMenuTile("Settings",definition.PrimaryBackend,"◷",Color.FromRgb(222,105,184),settingsAction);AddWave1Action(grid,s,"Settings",settingsAction,null);
        }

        private Button CreateDreamcastMenuTile(string title,string detail,string glyph,Color color,Action invoke)
        {
            Button b=new Button{Margin=new Thickness(24),Background=Brushes.Transparent,BorderThickness=new Thickness(0),RenderTransformOrigin=new Point(0.5,0.5)};StackPanel panel=new StackPanel{VerticalAlignment=VerticalAlignment.Center};Border icon=new Border{Width=150,Height=118,CornerRadius=new CornerRadius(60),Background=new SolidColorBrush(Color.FromArgb(150,color.R,color.G,color.B)),BorderBrush=new SolidColorBrush(color),BorderThickness=new Thickness(5),HorizontalAlignment=HorizontalAlignment.Center,Child=new TextBlock{Text=glyph,FontSize=58,Foreground=Brushes.White,HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center}};panel.Children.Add(icon);Border label=new Border{MinWidth=180,Height=44,CornerRadius=new CornerRadius(22),Background=new SolidColorBrush(color),Margin=new Thickness(0,-4,0,0),HorizontalAlignment=HorizontalAlignment.Center,Child=new TextBlock{Text=title,FontSize=25,Foreground=Brushes.White,HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center}};panel.Children.Add(label);panel.Children.Add(new TextBlock{Text=detail,FontSize=10,Foreground=new SolidColorBrush(Color.FromRgb(55,72,86)),HorizontalAlignment=HorizontalAlignment.Center,Margin=new Thickness(0,5,0,0)});b.Content=panel;b.Click+=delegate{invoke();};return b;
        }

        private void RenderSaturnMenu()
        {
            titleText.Text=String.Empty;subtitleText.Text=String.Empty;columns=2;Grid body=new Grid{Margin=new Thickness(140,24,140,20)};contentHost.Children.Add(body);System.Windows.Shapes.Ellipse orbit=new System.Windows.Shapes.Ellipse{Stroke=new SolidColorBrush(Color.FromArgb(90,92,202,255)),StrokeThickness=5,Margin=new Thickness(50)};body.Children.Add(orbit);UniformGrid grid=new UniformGrid{Columns=2,Rows=2,Margin=new Thickness(90,50,90,50)};body.Children.Add(grid);
            Action app=delegate{OpenWave1Subpage("library");};Action cd=delegate{OpenWave1Subpage("music");};Action memory=delegate{OpenWave1Subpage("saves");};Action settingsAction=delegate{OpenWave1Subpage("settings");};
            Button a=CreateSaturnOrb("Start Application",games.Count+" discs","▶",Color.FromRgb(34,162,225),app);AddWave1Action(grid,a,"Start Application",app,null);
            Button c=CreateSaturnOrb("CD Player","audio controls","♪",Color.FromRgb(89,200,198),cd);AddWave1Action(grid,c,"CD Player",cd,null);
            Button m=CreateSaturnOrb("Memory Manager","backup memory","▣",Color.FromRgb(239,67,129),memory);AddWave1Action(grid,m,"Memory Manager",memory,null);
            Button s=CreateSaturnOrb("System Settings",definition.PrimaryBackend,"⚙",Color.FromRgb(243,169,61),settingsAction);AddWave1Action(grid,s,"System Settings",settingsAction,null);
        }

        private Button CreateSaturnOrb(string title,string detail,string glyph,Color color,Action invoke)
        {
            Button b=new Button{Margin=new Thickness(24),Background=Brushes.Transparent,BorderThickness=new Thickness(0),RenderTransformOrigin=new Point(0.5,0.5)};StackPanel s=new StackPanel{VerticalAlignment=VerticalAlignment.Center};Border orb=new Border{Width=132,Height=132,CornerRadius=new CornerRadius(66),Background=new RadialGradientBrush(Color.FromArgb(245,(byte)Math.Min(255,color.R+30),(byte)Math.Min(255,color.G+30),(byte)Math.Min(255,color.B+30)),Color.FromArgb(225,(byte)(color.R/2),(byte)(color.G/2),(byte)(color.B/2))),BorderBrush=Brushes.White,BorderThickness=new Thickness(2),HorizontalAlignment=HorizontalAlignment.Center,Child=new TextBlock{Text=glyph,FontSize=48,Foreground=Brushes.White,HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center}};s.Children.Add(orb);s.Children.Add(new TextBlock{Text=title,FontSize=18,FontWeight=FontWeights.SemiBold,Foreground=Brushes.White,HorizontalAlignment=HorizontalAlignment.Center,Margin=new Thickness(0,6,0,0)});s.Children.Add(new TextBlock{Text=detail,FontSize=10,Foreground=new SolidColorBrush(Color.FromRgb(188,218,235)),HorizontalAlignment=HorizontalAlignment.Center});b.Content=s;b.Click+=delegate{invoke();};return b;
        }

        private void ProcessPspXmbCommand(XmbInputCommand command)
        {
            string[] categories=new string[]{"Settings","Photo","Music","Video","Game"};
            if(command==XmbInputCommand.Back){PlayEffect("Back.wav");Close();return;}
            if(command==XmbInputCommand.Left||command==XmbInputCommand.Right){int next=Math.Max(0,Math.Min(categories.Length-1,pspCategoryIndex+(command==XmbInputCommand.Left?-1:1)));if(next!=pspCategoryIndex){pspCategoryIndex=next;pspItemIndex=0;PlayEffect("Navigate.wav");RenderPage();}return;}
            List<ConsolePlatformAction> visible=actions;
            if(command==XmbInputCommand.Up||command==XmbInputCommand.Down){int next=Math.Max(0,Math.Min(Math.Max(0,visible.Count-1),pspItemIndex+(command==XmbInputCommand.Up?-1:1)));if(next!=pspItemIndex){pspItemIndex=next;selected=next;PlayEffect("Navigate.wav");UpdateActionVisuals();}return;}
            if(command==XmbInputCommand.Confirm&&visible.Count>0){selected=Math.Max(0,Math.Min(visible.Count-1,pspItemIndex));PlayEffect("Confirm.wav");if(visible[selected].Invoke!=null)visible[selected].Invoke();}
        }

        private void RenderPspXmb()
        {
            titleText.Text=String.Empty;subtitleText.Text=String.Empty;columns=1;string[] cats=new string[]{"Settings","Photo","Music","Video","Game"};string[] glyphs=new string[]{"⚙","▧","♪","▶","◉"};pspCategoryIndex=Math.Max(0,Math.Min(cats.Length-1,pspCategoryIndex));
            Grid body=new Grid{Margin=new Thickness(60,36,60,20)};body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(180)});body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(1,GridUnitType.Star)});contentHost.Children.Add(body);StackPanel categoryRow=new StackPanel{Orientation=Orientation.Horizontal,HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center};body.Children.Add(categoryRow);
            for(int i=0;i<cats.Length;i++){bool active=i==pspCategoryIndex;StackPanel c=new StackPanel{Width=150,Opacity=active?1.0:0.42};c.Children.Add(new TextBlock{Text=glyphs[i],FontSize=active?58:42,Foreground=Brushes.White,HorizontalAlignment=HorizontalAlignment.Center});c.Children.Add(new TextBlock{Text=cats[i],FontSize=active?18:13,FontWeight=active?FontWeights.SemiBold:FontWeights.Normal,Foreground=Brushes.White,HorizontalAlignment=HorizontalAlignment.Center});categoryRow.Children.Add(c);}
            StackPanel list=new StackPanel{Margin=new Thickness(310,8,190,0)};Grid.SetRow(list,1);body.Children.Add(list);
            if(pspCategoryIndex==4){foreach(ConsolePlatformGame game in games){ConsolePlatformGame captured=game;Button b=CreatePspXmbRow(game.Name,"Memory Stick / UMD image",delegate{LaunchGame(captured,false);});list.Children.Add(b);actions.Add(new ConsolePlatformAction{Button=b,Name=game.Name,Game=game,Invoke=delegate{LaunchGame(captured,false);}});}if(games.Count==0)AddPspAction(list,"Game Library","Choose a PSP game folder",delegate{OpenWave1Subpage("settings");});}
            else if(pspCategoryIndex==0){AddPspAction(list,"PPSSPP Settings","Graphics, audio, controls, networking, system and advanced",delegate{OpenWave1Subpage("settings");});AddPspAction(list,"Saved Data Utility","PSP saved data",delegate{OpenWave1Subpage("saves");});AddPspAction(list,"System Information",definition.PrimaryBackend,delegate{OpenWave1Subpage("info");});}
            else if(pspCategoryIndex==1){AddPspAction(list,"Photo","No photo folder configured",delegate{OpenWave1Subpage("media");});}
            else if(pspCategoryIndex==2){AddPspAction(list,"Music",String.IsNullOrWhiteSpace(settings.ambiencePath)?"No music configured":Path.GetFileName(settings.ambiencePath),delegate{OpenWave1Subpage("music");});}
            else if(pspCategoryIndex==3){AddPspAction(list,"Video","No video folder configured",delegate{OpenWave1Subpage("media");});}
            pspItemIndex=Math.Max(0,Math.Min(Math.Max(0,actions.Count-1),pspItemIndex));selected=pspItemIndex;
        }

        private Button CreatePspXmbRow(string title,string detail,Action invoke)
        {
            Button b=new Button{Height=72,Margin=new Thickness(0,3,0,3),Padding=new Thickness(18,5,18,5),HorizontalContentAlignment=HorizontalAlignment.Left,Background=new SolidColorBrush(Color.FromArgb(55,255,255,255)),BorderBrush=new SolidColorBrush(Color.FromArgb(90,255,255,255)),BorderThickness=new Thickness(0,0,0,1),RenderTransformOrigin=new Point(0.5,0.5)};StackPanel s=new StackPanel();s.Children.Add(new TextBlock{Text=title,FontSize=19,Foreground=Brushes.White});s.Children.Add(new TextBlock{Text=detail,FontSize=10,Foreground=new SolidColorBrush(Color.FromArgb(190,255,255,255)),TextTrimming=TextTrimming.CharacterEllipsis});b.Content=s;b.Click+=delegate{invoke();};return b;
        }

        private void AddPspAction(Panel panel,string title,string detail,Action invoke)
        {
            Button b=CreatePspXmbRow(title,detail,invoke);panel.Children.Add(b);actions.Add(new ConsolePlatformAction{Button=b,Name=title,Invoke=invoke});
        }

        private void RenderWave1Subpage()
        {
            if(dashboardSubpage=="library"){RenderWave1Library();return;}
            if(dashboardSubpage=="saves"){RenderWave1Storage();return;}
            if(dashboardSubpage=="music"){RenderWave1Music();return;}
            if(dashboardSubpage=="media"){RenderWave1Media();return;}
            if(dashboardSubpage=="info"){RenderWave1Info();return;}
            RenderWave1Settings();
        }

        private void RenderWave1Library()
        {
            titleText.Text=definition.Shell=="PSP"?"Game":"Software Library";subtitleText.Text=games.Count.ToString(CultureInfo.InvariantCulture)+" titles";columns=6;ScrollViewer scroll=new ScrollViewer{VerticalScrollBarVisibility=ScrollBarVisibility.Hidden,HorizontalScrollBarVisibility=ScrollBarVisibility.Disabled};WrapPanel wrap=new WrapPanel{Margin=new Thickness(12)};scroll.Content=wrap;contentHost.Children.Add(scroll);foreach(ConsolePlatformGame game in games){ConsolePlatformGame captured=game;Button b=CreateGameButton(game,delegate{LaunchGame(captured,false);});wrap.Children.Add(b);actions.Add(new ConsolePlatformAction{Button=b,Invoke=delegate{LaunchGame(captured,false);},Name=game.Name,Game=game});}if(games.Count==0)AddRoundedStorage(wrap,"No software found","Add a game folder from this console's system settings",definition.Accent,delegate{dashboardSubpage="settings";selected=0;RenderPage();});
        }

        private void RenderWave1Storage()
        {
            titleText.Text=definition.Shell=="Dreamcast"?"File":(definition.Shell=="Saturn"?"Memory Manager":"Saved Data");subtitleText.Text="Native storage view for "+definition.DisplayName;StackPanel panel=new StackPanel{Margin=new Thickness(36,8,36,24)};contentHost.Children.Add(new ScrollViewer{VerticalScrollBarVisibility=ScrollBarVisibility.Hidden,Content=panel});List<string> roots=FindSaveRoots();if(roots.Count==0)AddRoundedStorage(panel,"No saved data detected","Configure the emulator data path in system settings",definition.Accent,delegate{dashboardSubpage="settings";selected=0;RenderPage();});else foreach(string rootPath in roots)AddRoundedStorage(panel,Path.GetFileName(rootPath.TrimEnd(Path.DirectorySeparatorChar)),rootPath,definition.Accent,delegate{BackupSaves();});
        }

        private void RenderWave1Music()
        {
            titleText.Text=definition.Shell=="Dreamcast"?"Music":(definition.Shell=="Saturn"?"CD Player":"Music");subtitleText.Text="Local audio controls";WrapPanel panel=new WrapPanel{Margin=new Thickness(36,20,36,20)};contentHost.Children.Add(panel);AddRoundedStorage(panel,"Audio Source",String.IsNullOrWhiteSpace(settings.ambiencePath)?"Choose local audio":Path.GetFileName(settings.ambiencePath),definition.Accent,ChooseAmbience);AddRoundedStorage(panel,settings.ambienceEnabled?"Pause":"Play",Math.Round(settings.ambienceVolume*100).ToString(CultureInfo.InvariantCulture)+"% volume",definition.Accent,delegate{settings.ambienceEnabled=!settings.ambienceEnabled;settings.Save(settingsPath);StartAmbience();RenderPage();});AddRoundedStorage(panel,"Volume",Math.Round(settings.ambienceVolume*100).ToString(CultureInfo.InvariantCulture)+"%",definition.Accent,CycleAmbienceVolume);
        }

        private void RenderWave1Media()
        {
            titleText.Text=pspCategoryIndex==1?"Photo":"Video";subtitleText.Text="Media folders will use the Huymaier file browser";StackPanel panel=new StackPanel{Margin=new Thickness(80,30,80,30)};contentHost.Children.Add(panel);AddRoundedStorage(panel,"Media folder","Not configured in this development scaffold",definition.Accent,delegate{ShowNotice("Media-folder routing is not enabled until the PSP adapter owns the path safely");});
        }

        private void RenderWave1Info()
        {
            titleText.Text="System Information";subtitleText.Text=definition.DisplayName;StackPanel panel=new StackPanel{Margin=new Thickness(80,24,80,24)};contentHost.Children.Add(panel);AddRoundedStorage(panel,"Primary Emulator",DisplayPath(settings.emulatorPath),definition.Accent,ChoosePrimaryEmulator);AddRoundedStorage(panel,"Data Path",DisplayPath(settings.emulatorDataPath),definition.Accent,ChooseEmulatorDataPath);AddRoundedStorage(panel,"Library",games.Count.ToString(CultureInfo.InvariantCulture)+" titles",definition.Accent,delegate{dashboardSubpage="library";selected=0;RenderPage();});
        }

        private void RenderWave1Settings()
        {
            titleText.Text=definition.Shell=="Dreamcast"?"Settings":(definition.Shell=="Saturn"?"System Settings":(definition.Shell=="PSP"?"PPSSPP Settings":"System Settings"));subtitleText.Text=definition.PrimaryBackend+"  •  Huymaier native configuration";StackPanel panel=new StackPanel{Margin=new Thickness(44,6,44,24)};contentHost.Children.Add(new ScrollViewer{VerticalScrollBarVisibility=ScrollBarVisibility.Hidden,Content=panel});
            if(String.IsNullOrWhiteSpace(settings.emulatorPath)||!File.Exists(settings.emulatorPath)){AddRoundedStorage(panel,"Locate Emulator","Point Huymaier Console to "+definition.PrimaryBackend,definition.Accent,ChoosePrimaryEmulator);AddRoundedStorage(panel,"Install Latest Emulator","Resolve the latest supported official release",definition.Accent,InstallPrimaryEmulator);}else AddRoundedStorage(panel,definition.PrimaryBackend,settings.emulatorPath,definition.Accent,ChoosePrimaryEmulator);
            AddRoundedStorage(panel,"Emulator Data",DisplayPath(settings.emulatorDataPath),definition.Accent,ChooseEmulatorDataPath);AddRoundedStorage(panel,"Game Folders",settings.gameFolders.Count.ToString(CultureInfo.InvariantCulture)+" configured",definition.Accent,AddGameFolder);AddRoundedStorage(panel,"Full Emulator Settings","Every discovered backend setting; unknown keys are preserved",definition.Accent,delegate{RequestHuymaierPicker("OpenNativeEmulatorSettings");});AddRoundedStorage(panel,"Refresh Library",games.Count.ToString(CultureInfo.InvariantCulture)+" titles",definition.Accent,delegate{RefreshLibrary(true);});
        }

'''
insert_anchor='        private void RenderXboxRoot()\n'
if methods.strip() not in text:
    if text.count(insert_anchor)!=1:
        raise SystemExit('wave1 method insertion anchor missing')
    text=text.replace(insert_anchor,methods+insert_anchor,1)

path.write_text(text,encoding='utf-8')
print('materialized Wave 1 native console scaffold')
