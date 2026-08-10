from pathlib import Path
import json

ROOT=Path(__file__).resolve().parents[2]
platforms={
 'AtariLynx':dict(id='atarilynx',display='Atari Lynx',backend='Mednafen',fallback='ares',adapter='mednafen',interface='Atari Lynx handheld interface',ext=['.lnx','.lyx','.o','.zip'],style='Lynx Handheld'),
 'NeoGeo':dict(id='neogeo',display='Neo Geo',backend='FinalBurn Neo',fallback='MAME',adapter='fbneo',interface='Neo Geo AES/MVS cartridge-system interface',ext=['.zip','.7z','.neo'],style='Neo Geo AES'),
 'NGPC':dict(id='ngpc',display='Neo Geo Pocket Color',backend='Mednafen',fallback='ares',adapter='mednafen',interface='Neo Geo Pocket Color handheld interface',ext=['.ngc','.ngp','.npc','.zip'],style='NGPC Handheld'),
 'Jaguar':dict(id='jaguar',display='Atari Jaguar',backend='BigPEmu',fallback='Virtual Jaguar libretro',adapter='bigpemu',interface='Atari Jaguar console and keypad-controller interface',ext=['.j64','.jag','.rom','.bin','.abs','.cof','.zip'],style='Jaguar Console'),
 'PrimeHack':dict(id='primehack',display='Metroid PrimeHack',backend='PrimeHack',fallback='Dolphin',adapter='primehack',interface='Prime-series visor HUD interface for PrimeHack',ext=['.iso','.rvz','.wbfs','.gcm','.ciso'],style='Prime Visor')
}

def defaults(style):
 return {'schemaVersion':7,'emulatorPath':'','fallbackEmulatorPath':'','emulatorDataPath':'','gameFolders':[],'startupEnabled':True,'startupVolume':1.0,'ambienceEnabled':False,'ambiencePath':'','ambienceVolume':0.55,'soundVolume':1.0,'dashboardStyle':style,'fullscreen':True}
for folder,p in platforms.items():
 d=ROOT/'EmulatorPlatforms'/folder;d.mkdir(parents=True,exist_ok=True)
 definition={'id':p['id'],'displayName':p['display'],'primaryBackend':p['backend'],'fallbackBackend':p['fallback'],'adapter':p['adapter'],'interface':p['interface'],'version':'0.26.4-dev','enabled':False,'gameExtensions':p['ext'],'dashboardStyle':p['style']}
 (d/'platform.json').write_text(json.dumps(definition,indent=2)+'\n',encoding='utf-8');(d/'settings.default.json').write_text(json.dumps(defaults(p['style']),indent=2)+'\n',encoding='utf-8')

cs=ROOT/'Native'/'HuymaierConsole.ConsolePlatforms.cs';text=cs.read_text(encoding='utf-8-sig')
if 'else if (key == "ATARILYNX")' not in text:
 anchor='''            else if (key == "ATARI2600")
            {
'''
 defs=r'''            else if (key == "ATARILYNX")
            {
                d.DisplayName="Atari Lynx";d.Subtitle="HANDHELD COLOR ENTERTAINMENT SYSTEM";d.Shell="AtariLynx";d.PrimaryBackend="Mednafen";d.FallbackBackend="ares";d.PrimaryExecutableNames=new string[]{"mednafen.exe"};d.FallbackExecutableNames=new string[]{"ares.exe"};d.GameExtensions=new string[]{".lnx",".lyx",".o",".zip"};d.ColorA=Color.FromRgb(22,23,24);d.ColorB=Color.FromRgb(4,5,6);d.Accent=Color.FromRgb(226,82,44);
            }
            else if (key == "NEOGEO")
            {
                d.DisplayName="Neo Geo";d.Subtitle="ADVANCED ENTERTAINMENT SYSTEM";d.Shell="NeoGeo";d.PrimaryBackend="FinalBurn Neo";d.FallbackBackend="MAME";d.PrimaryExecutableNames=new string[]{"fbneo.exe","FinalBurnNeo.exe"};d.FallbackExecutableNames=new string[]{"mame.exe"};d.GameExtensions=new string[]{".zip",".7z",".neo"};d.ColorA=Color.FromRgb(14,15,16);d.ColorB=Color.FromRgb(3,4,5);d.Accent=Color.FromRgb(215,31,39);
            }
            else if (key == "NGPC")
            {
                d.DisplayName="Neo Geo Pocket Color";d.Subtitle="COLOR";d.Shell="NGPC";d.PrimaryBackend="Mednafen";d.FallbackBackend="ares";d.PrimaryExecutableNames=new string[]{"mednafen.exe"};d.FallbackExecutableNames=new string[]{"ares.exe"};d.GameExtensions=new string[]{".ngc",".ngp",".npc",".zip"};d.ColorA=Color.FromRgb(84,87,89);d.ColorB=Color.FromRgb(29,31,32);d.Accent=Color.FromRgb(78,183,182);
            }
            else if (key == "JAGUAR")
            {
                d.DisplayName="Atari Jaguar";d.Subtitle="64-BIT INTERACTIVE MULTIMEDIA SYSTEM";d.Shell="Jaguar";d.PrimaryBackend="BigPEmu";d.FallbackBackend="Virtual Jaguar libretro";d.PrimaryExecutableNames=new string[]{"BigPEmu.exe","bigpemu.exe"};d.FallbackExecutableNames=new string[]{"retroarch.exe"};d.GameExtensions=new string[]{".j64",".jag",".rom",".bin",".abs",".cof",".zip"};d.ColorA=Color.FromRgb(17,18,19);d.ColorB=Color.FromRgb(4,5,5);d.Accent=Color.FromRgb(209,35,42);
            }
            else if (key == "PRIMEHACK")
            {
                d.DisplayName="Metroid PrimeHack";d.Subtitle="PRIME VISOR";d.Shell="PrimeHack";d.PrimaryBackend="PrimeHack";d.FallbackBackend="Dolphin";d.PrimaryExecutableNames=new string[]{"PrimeHack.exe","DolphinQt2.exe","Dolphin.exe"};d.FallbackExecutableNames=new string[]{"Dolphin.exe","DolphinQt2.exe"};d.GameExtensions=new string[]{".iso",".rvz",".wbfs",".gcm",".ciso"};d.ColorA=Color.FromRgb(5,29,31);d.ColorB=Color.FromRgb(2,7,9);d.Accent=Color.FromRgb(63,225,211);
            }
'''
 if text.count(anchor)!=1:raise SystemExit('Wave3 definition anchor missing')
 text=text.replace(anchor,defs+anchor,1)

if 'if (IsWave3Shell()) { if (IsRootConsoleSurface()) RenderWave3Root();' not in text:
 anchor='            if (IsWave2Shell()) { if (IsRootConsoleSurface()) RenderWave2Root(); else RenderWave2Subpage(); UpdateActionVisuals(); return; }\n'
 if text.count(anchor)!=1:raise SystemExit('Wave3 render dispatch anchor missing')
 text=text.replace(anchor,anchor+'            if (IsWave3Shell()) { if (IsRootConsoleSurface()) RenderWave3Root(); else RenderWave3Subpage(); UpdateActionVisuals(); return; }\n',1)
 anchor2='            if (IsWave2Shell()) { RenderWave2Root(); return; }\n'
 if text.count(anchor2)!=1:raise SystemExit('Wave3 RenderGames guard anchor missing')
 text=text.replace(anchor2,anchor2+'            if (IsWave3Shell()) { RenderWave3Root(); return; }\n',1)

methods=r'''
        private bool IsWave3Shell()
        {
            return definition.Shell == "AtariLynx" || definition.Shell == "NeoGeo" || definition.Shell == "NGPC" || definition.Shell == "Jaguar" || definition.Shell == "PrimeHack";
        }

        private void RenderWave3Root()
        {
            if (definition.Shell == "AtariLynx") { RenderAtariLynxHandheld(); return; }
            if (definition.Shell == "NeoGeo") { RenderNeoGeoDeck(); return; }
            if (definition.Shell == "NGPC") { RenderNgpcHandheld(); return; }
            if (definition.Shell == "Jaguar") { RenderJaguarDeck(); return; }
            RenderPrimeHackVisor();
        }

        private void RenderWave3Subpage()
        {
            if (dashboardSubpage == "library") { RenderWave1Library(); return; }
            if (dashboardSubpage == "settings" || dashboardSubpage == "backend-settings" || dashboardSubpage == "backend-settings-list" || dashboardSubpage == "backend-setting-detail") { RenderWave1Subpage(); return; }
            if (dashboardSubpage == "saves") { RenderWave1Storage(); return; }
            RenderWave1Settings();
        }

        private void RenderAtariLynxHandheld()
        {
            titleText.Text=String.Empty;subtitleText.Text=String.Empty;columns=5;Grid body=new Grid{Margin=new Thickness(35,5,35,18)};body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(330)});body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(1,GridUnitType.Star)});contentHost.Children.Add(body);
            Border unit=new Border{CornerRadius=new CornerRadius(55),Background=new LinearGradientBrush(Color.FromRgb(40,41,42),Color.FromRgb(6,7,8),90),BorderBrush=new SolidColorBrush(Color.FromRgb(72,73,74)),BorderThickness=new Thickness(5),Padding=new Thickness(28),Margin=new Thickness(75,0,75,12)};Grid h=new Grid();h.ColumnDefinitions.Add(new ColumnDefinition{Width=new GridLength(185)});h.ColumnDefinitions.Add(new ColumnDefinition());h.ColumnDefinitions.Add(new ColumnDefinition{Width=new GridLength(185)});h.Children.Add(new TextBlock{Text="✚",FontSize=68,Foreground=new SolidColorBrush(Color.FromRgb(85,87,88)),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center});Border screen=new Border{CornerRadius=new CornerRadius(5),Background=new SolidColorBrush(Color.FromRgb(34,45,42)),BorderBrush=new SolidColorBrush(Color.FromRgb(7,8,9)),BorderThickness=new Thickness(14),Margin=new Thickness(8),Child=new TextBlock{Text="LYNX",FontSize=34,FontWeight=FontWeights.Bold,Foreground=new SolidColorBrush(Color.FromRgb(226,82,44)),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center}};Grid.SetColumn(screen,1);h.Children.Add(screen);TextBlock ab=new TextBlock{Text="A      B",FontSize=30,Foreground=new SolidColorBrush(Color.FromRgb(226,82,44)),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center};Grid.SetColumn(ab,2);h.Children.Add(ab);unit.Child=h;body.Children.Add(unit);WrapPanel cards=new WrapPanel();ScrollViewer sc=new ScrollViewer{VerticalScrollBarVisibility=ScrollBarVisibility.Hidden,Content=cards};Grid.SetRow(sc,1);body.Children.Add(sc);foreach(ConsolePlatformGame game in games)AddHardwareGame(cards,game,Color.FromRgb(226,82,44),126,158,"LYNX");AddHardwareUtility(cards,"System",definition.PrimaryBackend,"⚙",Color.FromRgb(226,82,44),delegate{OpenWave1Subpage("settings");},140,158);
        }

        private void RenderNeoGeoDeck()
        {
            titleText.Text=String.Empty;subtitleText.Text=String.Empty;columns=6;Grid body=new Grid{Margin=new Thickness(50,0,50,18)};body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(190)});body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(1,GridUnitType.Star)});contentHost.Children.Add(body);Border deck=new Border{CornerRadius=new CornerRadius(14),Background=new LinearGradientBrush(Color.FromRgb(29,30,31),Color.FromRgb(3,4,5),90),BorderBrush=new SolidColorBrush(Color.FromRgb(87,88,89)),BorderThickness=new Thickness(4),Padding=new Thickness(22),Margin=new Thickness(135,0,135,10)};Grid g=new Grid();g.Children.Add(new Border{Width=380,Height=64,Background=new SolidColorBrush(Color.FromRgb(5,6,7)),BorderBrush=new SolidColorBrush(Color.FromRgb(215,31,39)),BorderThickness=new Thickness(0,5,0,0),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center});g.Children.Add(new TextBlock{Text="NEO•GEO\nADVANCED ENTERTAINMENT SYSTEM",FontSize=21,FontWeight=FontWeights.Bold,Foreground=Brushes.White,HorizontalAlignment=HorizontalAlignment.Left,VerticalAlignment=VerticalAlignment.Center,Margin=new Thickness(35,0,0,0),TextAlignment=TextAlignment.Center});g.Children.Add(new TextBlock{Text="MAX 330 MEGA\nPRO-GEAR SPEC",FontSize=9,Foreground=new SolidColorBrush(Color.FromRgb(215,31,39)),HorizontalAlignment=HorizontalAlignment.Right,VerticalAlignment=VerticalAlignment.Center,Margin=new Thickness(0,0,35,0),TextAlignment=TextAlignment.Center});deck.Child=g;body.Children.Add(deck);WrapPanel cards=new WrapPanel();ScrollViewer scroll=new ScrollViewer{VerticalScrollBarVisibility=ScrollBarVisibility.Hidden,Content=cards};Grid.SetRow(scroll,1);body.Children.Add(scroll);foreach(ConsolePlatformGame game in games)AddHardwareGame(cards,game,Color.FromRgb(215,31,39),126,158,"NEO GEO");AddHardwareUtility(cards,"Memory Card","saved data","▣",Color.FromRgb(215,31,39),delegate{OpenWave1Subpage("saves");},140,158);AddHardwareUtility(cards,"System",definition.PrimaryBackend,"⚙",Color.FromRgb(122,25,30),delegate{OpenWave1Subpage("settings");},140,158);
        }

        private void RenderNgpcHandheld()
        {
            titleText.Text=String.Empty;subtitleText.Text=String.Empty;columns=5;Grid body=new Grid{Margin=new Thickness(40,5,40,18)};body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(335)});body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(1,GridUnitType.Star)});contentHost.Children.Add(body);Border handheld=new Border{Width=620,CornerRadius=new CornerRadius(70),HorizontalAlignment=HorizontalAlignment.Center,Background=new LinearGradientBrush(Color.FromRgb(89,93,95),Color.FromRgb(35,38,39),90),BorderBrush=new SolidColorBrush(Color.FromRgb(117,121,122)),BorderThickness=new Thickness(4),Padding=new Thickness(30)};Grid h=new Grid();h.ColumnDefinitions.Add(new ColumnDefinition{Width=new GridLength(160)});h.ColumnDefinitions.Add(new ColumnDefinition());h.ColumnDefinitions.Add(new ColumnDefinition{Width=new GridLength(160)});Border stick=new Border{Width=74,Height=74,CornerRadius=new CornerRadius(37),Background=new RadialGradientBrush(Color.FromRgb(88,91,92),Color.FromRgb(21,23,24)),BorderBrush=new SolidColorBrush(Color.FromRgb(135,138,139)),BorderThickness=new Thickness(3),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center,Child=new TextBlock{Text="●",FontSize=34,Foreground=new SolidColorBrush(Color.FromRgb(32,34,35)),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center}};h.Children.Add(stick);Border screen=new Border{Background=new SolidColorBrush(Color.FromRgb(45,61,54)),BorderBrush=new SolidColorBrush(Color.FromRgb(12,14,15)),BorderThickness=new Thickness(12),CornerRadius=new CornerRadius(8),Child=new TextBlock{Text="NEO GEO\nPOCKET COLOR",FontSize=22,FontWeight=FontWeights.SemiBold,Foreground=new SolidColorBrush(Color.FromRgb(78,183,182)),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center,TextAlignment=TextAlignment.Center}};Grid.SetColumn(screen,1);h.Children.Add(screen);TextBlock ab=new TextBlock{Text="A    B",FontSize=28,Foreground=new SolidColorBrush(Color.FromRgb(78,183,182)),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center};Grid.SetColumn(ab,2);h.Children.Add(ab);handheld.Child=h;body.Children.Add(handheld);WrapPanel cards=new WrapPanel();ScrollViewer scroll=new ScrollViewer{VerticalScrollBarVisibility=ScrollBarVisibility.Hidden,Content=cards};Grid.SetRow(scroll,1);body.Children.Add(scroll);foreach(ConsolePlatformGame game in games)AddHardwareGame(cards,game,Color.FromRgb(78,183,182),126,158,"NGPC");AddHardwareUtility(cards,"System",definition.PrimaryBackend,"⚙",Color.FromRgb(78,183,182),delegate{OpenWave1Subpage("settings");},140,158);
        }

        private void RenderJaguarDeck()
        {
            titleText.Text=String.Empty;subtitleText.Text=String.Empty;columns=6;Grid body=new Grid{Margin=new Thickness(45,0,45,18)};body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(220)});body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(1,GridUnitType.Star)});contentHost.Children.Add(body);Border deck=new Border{CornerRadius=new CornerRadius(80,80,18,18),Background=new LinearGradientBrush(Color.FromRgb(38,39,40),Color.FromRgb(4,5,6),90),BorderBrush=new SolidColorBrush(Color.FromRgb(73,74,75)),BorderThickness=new Thickness(5),Padding=new Thickness(22),Margin=new Thickness(150,0,150,10)};Grid g=new Grid();g.Children.Add(new Border{Width=330,Height=52,CornerRadius=new CornerRadius(8),Background=new SolidColorBrush(Color.FromRgb(9,10,11)),BorderBrush=new SolidColorBrush(Color.FromRgb(209,35,42)),BorderThickness=new Thickness(3),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center});g.Children.Add(new TextBlock{Text="JAGUAR",FontSize=32,FontWeight=FontWeights.Black,Foreground=new SolidColorBrush(Color.FromRgb(209,35,42)),HorizontalAlignment=HorizontalAlignment.Left,VerticalAlignment=VerticalAlignment.Center,Margin=new Thickness(38,0,0,0)});g.Children.Add(new TextBlock{Text="64\nBIT",FontSize=21,FontWeight=FontWeights.Bold,Foreground=Brushes.White,HorizontalAlignment=HorizontalAlignment.Right,VerticalAlignment=VerticalAlignment.Center,Margin=new Thickness(0,0,42,0),TextAlignment=TextAlignment.Center});deck.Child=g;body.Children.Add(deck);WrapPanel cards=new WrapPanel();ScrollViewer scroll=new ScrollViewer{VerticalScrollBarVisibility=ScrollBarVisibility.Hidden,Content=cards};Grid.SetRow(scroll,1);body.Children.Add(scroll);foreach(ConsolePlatformGame game in games)AddHardwareGame(cards,game,Color.FromRgb(209,35,42),126,158,"JAGUAR");AddHardwareUtility(cards,"Keypad & Input","Jaguar controller mappings","#",Color.FromRgb(209,35,42),delegate{OpenWave1Subpage("settings");},140,158);AddHardwareUtility(cards,"System",definition.PrimaryBackend,"⚙",Color.FromRgb(128,27,32),delegate{OpenWave1Subpage("settings");},140,158);
        }

        private void RenderPrimeHackVisor()
        {
            titleText.Text=String.Empty;subtitleText.Text=String.Empty;columns=5;Grid body=new Grid{Margin=new Thickness(34,10,34,18)};contentHost.Children.Add(body);Border visor=new Border{CornerRadius=new CornerRadius(90,90,45,45),BorderBrush=new SolidColorBrush(Color.FromArgb(220,63,225,211)),BorderThickness=new Thickness(4),Background=new RadialGradientBrush(Color.FromArgb(115,15,91,91),Color.FromArgb(245,1,9,12)),Padding=new Thickness(58)};Grid inner=new Grid();inner.RowDefinitions.Add(new RowDefinition{Height=new GridLength(65)});inner.RowDefinitions.Add(new RowDefinition{Height=new GridLength(1,GridUnitType.Star)});inner.Children.Add(new TextBlock{Text="PRIME VISOR  //  PRIMEHACK",FontFamily=new FontFamily("Consolas"),FontSize=21,FontWeight=FontWeights.SemiBold,Foreground=new SolidColorBrush(Color.FromRgb(111,255,233)),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center});WrapPanel cards=new WrapPanel{HorizontalAlignment=HorizontalAlignment.Center};ScrollViewer scroll=new ScrollViewer{VerticalScrollBarVisibility=ScrollBarVisibility.Hidden,Content=cards};Grid.SetRow(scroll,1);inner.Children.Add(scroll);foreach(ConsolePlatformGame game in games)AddHardwareGame(cards,game,Color.FromRgb(63,225,211),150,190,"PRIME");AddHardwareUtility(cards,"PrimeHack Controls","mouse-look, camera, reticle and visor controls","⊕",Color.FromRgb(29,151,148),delegate{OpenWave1Subpage("settings");},170,190);AddHardwareUtility(cards,"System",definition.PrimaryBackend,"⚙",Color.FromRgb(23,105,107),delegate{OpenWave1Subpage("settings");},150,190);visor.Child=inner;body.Children.Add(visor);
        }

'''
if 'private bool IsWave3Shell()' not in text:
 anchor='        private bool IsWave2Shell()\n'
 if text.count(anchor)!=1:raise SystemExit('Wave3 methods insertion anchor missing')
 text=text.replace(anchor,methods+anchor,1)
cs.write_text(text,encoding='utf-8')
print('staged Wave 3 specialty native platform surfaces')
