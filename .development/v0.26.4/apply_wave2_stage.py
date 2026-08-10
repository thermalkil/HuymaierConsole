from pathlib import Path
import json

ROOT=Path(__file__).resolve().parents[2]

platforms={
 'Atari2600':dict(id='atari2600',display='Atari 2600',backend='Stella',fallback='ares',adapter='stella',interface='Atari VCS control-deck and cartridge interface',ext=['.a26','.bin','.rom','.zip'],style='VCS Control Deck'),
 'NES':dict(id='nes',display='Nintendo Entertainment System',backend='Mesen Community Edition',fallback='ares',adapter='mesence',interface='NES control-deck and cartridge interface',ext=['.nes','.fds','.unf','.unif','.zip'],style='NES Control Deck'),
 'SNES':dict(id='snes',display='Super Nintendo Entertainment System',backend='Mesen Community Edition',fallback='ares',adapter='mesence',interface='SNES control-deck and cartridge interface',ext=['.sfc','.smc','.fig','.swc','.zip'],style='SNES Control Deck'),
 'GameBoy':dict(id='gameboy',display='Nintendo Game Boy',backend='SameBoy',fallback='Mesen Community Edition',adapter='sameboy',interface='DMG handheld and cartridge interface',ext=['.gb','.sgb','.zip'],style='DMG-01'),
 'GBC':dict(id='gbc',display='Nintendo Game Boy Color',backend='SameBoy',fallback='Mesen Community Edition',adapter='sameboy',interface='Game Boy Color handheld and cartridge interface',ext=['.gbc','.gb','.zip'],style='CGB'),
 'GBA':dict(id='gba',display='Nintendo Game Boy Advance',backend='mGBA',fallback='Mesen Community Edition',adapter='mgba',interface='Game Boy Advance handheld and cartridge interface',ext=['.gba','.agb','.zip'],style='AGB-001'),
 'Genesis':dict(id='genesis',display='Sega Genesis',backend='ares',fallback='BlastEm',adapter='ares',interface='Genesis / Mega Drive control-deck and cartridge interface',ext=['.md','.gen','.bin','.smd','.zip'],style='Genesis Model 1'),
 'SegaCD':dict(id='segacd',display='Sega CD',backend='ares',fallback='Mednafen',adapter='ares',fallbackAdapter='mednafen',interface='Sega CD BIOS / CD-player inspired disc interface',ext=['.cue','.chd','.iso','.bin'],style='Sega CD Model 1'),
 'Sega32X':dict(id='sega32x',display='Sega 32X',backend='ares',fallback='PicoDrive libretro',adapter='ares',interface='Genesis + 32X tower and cartridge interface',ext=['.32x','.bin','.md','.zip'],style='Genesis + 32X'),
 'GameGear':dict(id='gamegear',display='Sega Game Gear',backend='Mesen Community Edition',fallback='ares',adapter='mesence',interface='Game Gear handheld and cartridge interface',ext=['.gg','.zip'],style='Game Gear'),
 'MasterSystem':dict(id='mastersystem',display='Sega Master System',backend='Mesen Community Edition',fallback='ares',adapter='mesence',interface='Master System control-deck / card / cartridge interface',ext=['.sms','.sg','.zip'],style='Master System'),
 'TurboGrafx16':dict(id='turbografx16',display='TurboGrafx-16',backend='Mednafen',fallback='Mesen Community Edition',adapter='mednafen',fallbackAdapter='mesence',interface='TurboGrafx-16 / PC Engine HuCard and CD interface',ext=['.pce','.sgx','.cue','.chd','.zip'],style='TurboGrafx-16')
}

def defaults(style):
 return {'schemaVersion':7,'emulatorPath':'','fallbackEmulatorPath':'','emulatorDataPath':'','gameFolders':[],'startupEnabled':True,'startupVolume':1.0,'ambienceEnabled':False,'ambiencePath':'','ambienceVolume':0.60,'soundVolume':1.0,'dashboardStyle':style,'fullscreen':True}

for folder,p in platforms.items():
 d=ROOT/'EmulatorPlatforms'/folder;d.mkdir(parents=True,exist_ok=True)
 definition={'id':p['id'],'displayName':p['display'],'primaryBackend':p['backend'],'fallbackBackend':p['fallback'],'adapter':p['adapter'],'interface':p['interface'],'version':'0.26.4-dev','enabled':False,'gameExtensions':p['ext'],'dashboardStyle':p['style']}
 if p.get('fallbackAdapter'):definition['fallbackAdapter']=p['fallbackAdapter']
 (d/'platform.json').write_text(json.dumps(definition,indent=2)+'\n',encoding='utf-8')
 (d/'settings.default.json').write_text(json.dumps(defaults(p['style']),indent=2)+'\n',encoding='utf-8')

cs=ROOT/'Native'/'HuymaierConsole.ConsolePlatforms.cs'
text=cs.read_text(encoding='utf-8-sig')

def once(old,new,label):
 global text
 count=text.count(old)
 if count!=1:raise SystemExit(f'{label}: expected one match, found {count}')
 text=text.replace(old,new,1)

if 'else if (key == "ATARI2600")' not in text:
 anchor='''            else if (key == "3DS")
            {
'''
 defs=r'''            else if (key == "ATARI2600")
            {
                d.DisplayName="Atari 2600";d.Subtitle="Video Computer System";d.Shell="Atari2600";d.PrimaryBackend="Stella";d.FallbackBackend="ares";d.PrimaryExecutableNames=new string[]{"Stella.exe","stella.exe"};d.FallbackExecutableNames=new string[]{"ares.exe"};d.GameExtensions=new string[]{".a26",".bin",".rom",".zip"};d.ColorA=Color.FromRgb(25,21,17);d.ColorB=Color.FromRgb(76,45,24);d.Accent=Color.FromRgb(220,149,57);
            }
            else if (key == "NES")
            {
                d.DisplayName="Nintendo Entertainment System";d.Subtitle="Control Deck";d.Shell="NES";d.PrimaryBackend="Mesen Community Edition";d.FallbackBackend="ares";d.PrimaryExecutableNames=new string[]{"Mesen.exe","Mesen2.exe"};d.FallbackExecutableNames=new string[]{"ares.exe"};d.GameExtensions=new string[]{".nes",".fds",".unf",".unif",".zip"};d.ColorA=Color.FromRgb(205,204,199);d.ColorB=Color.FromRgb(102,103,100);d.Accent=Color.FromRgb(194,35,42);
            }
            else if (key == "SNES")
            {
                d.DisplayName="Super Nintendo Entertainment System";d.Subtitle="Super NES Control Deck";d.Shell="SNES";d.PrimaryBackend="Mesen Community Edition";d.FallbackBackend="ares";d.PrimaryExecutableNames=new string[]{"Mesen.exe","Mesen2.exe"};d.FallbackExecutableNames=new string[]{"ares.exe"};d.GameExtensions=new string[]{".sfc",".smc",".fig",".swc",".zip"};d.ColorA=Color.FromRgb(208,207,205);d.ColorB=Color.FromRgb(116,113,123);d.Accent=Color.FromRgb(103,74,151);
            }
            else if (key == "GAMEBOY")
            {
                d.DisplayName="Nintendo Game Boy";d.Subtitle="DOT MATRIX WITH STEREO SOUND";d.Shell="GameBoy";d.PrimaryBackend="SameBoy";d.FallbackBackend="Mesen Community Edition";d.PrimaryExecutableNames=new string[]{"sameboy.exe","SameBoy.exe"};d.FallbackExecutableNames=new string[]{"Mesen.exe","Mesen2.exe"};d.GameExtensions=new string[]{".gb",".sgb",".zip"};d.ColorA=Color.FromRgb(197,198,189);d.ColorB=Color.FromRgb(145,147,137);d.Accent=Color.FromRgb(117,44,111);
            }
            else if (key == "GBC")
            {
                d.DisplayName="Nintendo Game Boy Color";d.Subtitle="COLOR";d.Shell="GBC";d.PrimaryBackend="SameBoy";d.FallbackBackend="Mesen Community Edition";d.PrimaryExecutableNames=new string[]{"sameboy.exe","SameBoy.exe"};d.FallbackExecutableNames=new string[]{"Mesen.exe","Mesen2.exe"};d.GameExtensions=new string[]{".gbc",".gb",".zip"};d.ColorA=Color.FromRgb(80,36,122);d.ColorB=Color.FromRgb(37,20,66);d.Accent=Color.FromRgb(244,73,142);
            }
            else if (key == "GBA")
            {
                d.DisplayName="Nintendo Game Boy Advance";d.Subtitle="ADVANCE";d.Shell="GBA";d.PrimaryBackend="mGBA";d.FallbackBackend="Mesen Community Edition";d.PrimaryExecutableNames=new string[]{"mGBA.exe","mgba.exe","mGBA-qt.exe"};d.FallbackExecutableNames=new string[]{"Mesen.exe","Mesen2.exe"};d.GameExtensions=new string[]{".gba",".agb",".zip"};d.ColorA=Color.FromRgb(79,55,145);d.ColorB=Color.FromRgb(38,26,83);d.Accent=Color.FromRgb(168,145,255);
            }
            else if (key == "GENESIS")
            {
                d.DisplayName="Sega Genesis";d.Subtitle="16-BIT";d.Shell="Genesis";d.PrimaryBackend="ares";d.FallbackBackend="BlastEm";d.PrimaryExecutableNames=new string[]{"ares.exe"};d.FallbackExecutableNames=new string[]{"blastem.exe","BlastEm.exe"};d.GameExtensions=new string[]{".md",".gen",".bin",".smd",".zip"};d.ColorA=Color.FromRgb(5,7,9);d.ColorB=Color.FromRgb(29,31,34);d.Accent=Color.FromRgb(191,34,45);
            }
            else if (key == "SEGACD")
            {
                d.DisplayName="Sega CD";d.Subtitle="CD-ROM SYSTEM";d.Shell="SegaCD";d.PrimaryBackend="ares";d.FallbackBackend="Mednafen";d.PrimaryExecutableNames=new string[]{"ares.exe"};d.FallbackExecutableNames=new string[]{"mednafen.exe"};d.GameExtensions=new string[]{".cue",".chd",".iso",".bin"};d.ColorA=Color.FromRgb(6,8,11);d.ColorB=Color.FromRgb(31,35,40);d.Accent=Color.FromRgb(80,147,214);
            }
            else if (key == "SEGA32X")
            {
                d.DisplayName="Sega 32X";d.Subtitle="32X";d.Shell="Sega32X";d.PrimaryBackend="ares";d.FallbackBackend="PicoDrive libretro";d.PrimaryExecutableNames=new string[]{"ares.exe"};d.FallbackExecutableNames=new string[]{"retroarch.exe"};d.GameExtensions=new string[]{".32x",".bin",".md",".zip"};d.ColorA=Color.FromRgb(4,5,6);d.ColorB=Color.FromRgb(27,29,31);d.Accent=Color.FromRgb(224,60,48);
            }
            else if (key == "GAMEGEAR")
            {
                d.DisplayName="Sega Game Gear";d.Subtitle="GAME GEAR";d.Shell="GameGear";d.PrimaryBackend="Mesen Community Edition";d.FallbackBackend="ares";d.PrimaryExecutableNames=new string[]{"Mesen.exe","Mesen2.exe"};d.FallbackExecutableNames=new string[]{"ares.exe"};d.GameExtensions=new string[]{".gg",".zip"};d.ColorA=Color.FromRgb(12,14,17);d.ColorB=Color.FromRgb(34,39,45);d.Accent=Color.FromRgb(47,137,205);
            }
            else if (key == "MASTERSYSTEM")
            {
                d.DisplayName="Sega Master System";d.Subtitle="MASTER SYSTEM";d.Shell="MasterSystem";d.PrimaryBackend="Mesen Community Edition";d.FallbackBackend="ares";d.PrimaryExecutableNames=new string[]{"Mesen.exe","Mesen2.exe"};d.FallbackExecutableNames=new string[]{"ares.exe"};d.GameExtensions=new string[]{".sms",".sg",".zip"};d.ColorA=Color.FromRgb(8,9,10);d.ColorB=Color.FromRgb(38,39,40);d.Accent=Color.FromRgb(206,31,39);
            }
            else if (key == "TURBOGRAFX16")
            {
                d.DisplayName="TurboGrafx-16";d.Subtitle="ENTERTAINMENT SUPER SYSTEM";d.Shell="TurboGrafx16";d.PrimaryBackend="Mednafen";d.FallbackBackend="Mesen Community Edition";d.PrimaryExecutableNames=new string[]{"mednafen.exe"};d.FallbackExecutableNames=new string[]{"Mesen.exe","Mesen2.exe"};d.GameExtensions=new string[]{".pce",".sgx",".cue",".chd",".zip"};d.ColorA=Color.FromRgb(224,223,218);d.ColorB=Color.FromRgb(178,177,171);d.Accent=Color.FromRgb(193,34,42);
            }
'''
 if text.count(anchor)!=1:raise SystemExit('Wave2 definitions insertion anchor missing')
 text=text.replace(anchor,defs+anchor,1)

# Dispatch Wave 2 before Wave 1/root generic surfaces.
if 'if (IsWave2Shell()) { if (IsRootConsoleSurface()) RenderWave2Root();' not in text:
 once('            if (definition.Shell == "N64" && IsRootConsoleSurface()) { RenderN64GamePakLauncher(); return; }\n', '            if (definition.Shell == "N64" && IsRootConsoleSurface()) { RenderN64GamePakLauncher(); return; }\n            if (IsWave2Shell()) { if (IsRootConsoleSurface()) RenderWave2Root(); else RenderWave2Subpage(); UpdateActionVisuals(); return; }\n','Wave2 RenderPage dispatch')
 once('            if (definition.Shell == "Switch") { RenderSwitchHomeAuthentic(); return; }\n', '            if (definition.Shell == "Switch") { RenderSwitchHomeAuthentic(); return; }\n            if (IsWave2Shell()) { RenderWave2Root(); return; }\n','Wave2 RenderGames guard')

methods=r'''
        private bool IsWave2Shell()
        {
            return definition.Shell == "Atari2600" || definition.Shell == "NES" || definition.Shell == "SNES" || definition.Shell == "GameBoy" || definition.Shell == "GBC" || definition.Shell == "GBA" || definition.Shell == "Genesis" || definition.Shell == "SegaCD" || definition.Shell == "Sega32X" || definition.Shell == "GameGear" || definition.Shell == "MasterSystem" || definition.Shell == "TurboGrafx16";
        }

        private void RenderWave2Root()
        {
            if (definition.Shell == "Atari2600") { RenderAtari2600Deck(); return; }
            if (definition.Shell == "NES") { RenderNesDeck(); return; }
            if (definition.Shell == "SNES") { RenderSnesDeck(); return; }
            if (definition.Shell == "GameBoy") { RenderGameBoyHandheld(false); return; }
            if (definition.Shell == "GBC") { RenderGameBoyHandheld(true); return; }
            if (definition.Shell == "GBA") { RenderGbaHandheld(); return; }
            if (definition.Shell == "Genesis") { RenderGenesisDeck(false); return; }
            if (definition.Shell == "Sega32X") { RenderGenesisDeck(true); return; }
            if (definition.Shell == "SegaCD") { RenderSegaCdDeck(); return; }
            if (definition.Shell == "GameGear") { RenderGameGearHandheld(); return; }
            if (definition.Shell == "MasterSystem") { RenderMasterSystemDeck(); return; }
            RenderTurboGrafxDeck();
        }

        private void RenderWave2Subpage()
        {
            if (dashboardSubpage == "library") { RenderWave1Library(); return; }
            if (dashboardSubpage == "settings" || dashboardSubpage == "backend-settings" || dashboardSubpage == "backend-settings-list" || dashboardSubpage == "backend-setting-detail") { RenderWave1Subpage(); return; }
            if (dashboardSubpage == "saves") { RenderWave1Storage(); return; }
            if (dashboardSubpage == "music") { RenderWave1Music(); return; }
            RenderWave1Settings();
        }

        private Border CreateHardwareGameCard(ConsolePlatformGame game, Color accent, double width, double height, string mediaLabel, Action invoke)
        {
            Border frame = new Border { Width=width, Height=height, Margin=new Thickness(9), CornerRadius=new CornerRadius(7), Background=new SolidColorBrush(Color.FromRgb(27,29,31)), BorderBrush=new SolidColorBrush(accent), BorderThickness=new Thickness(2) };
            Grid body = new Grid(); body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(1,GridUnitType.Star)}); body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(44)});
            if (!String.IsNullOrWhiteSpace(game.Cover) && File.Exists(game.Cover)) { try { body.Children.Add(new Image{Source=LoadBitmap(game.Cover),Stretch=Stretch.UniformToFill,Margin=new Thickness(5)}); } catch { } }
            if (body.Children.Count==0) body.Children.Add(new TextBlock{Text=mediaLabel,FontSize=22,FontWeight=FontWeights.Bold,Foreground=new SolidColorBrush(accent),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center});
            Border label = new Border{Background=new SolidColorBrush(Color.FromArgb(235,10,11,12)),Padding=new Thickness(6)}; Grid.SetRow(label,1); label.Child=new TextBlock{Text=game.Name,FontSize=10,Foreground=Brushes.White,TextTrimming=TextTrimming.CharacterEllipsis,HorizontalAlignment=HorizontalAlignment.Center};body.Children.Add(label);frame.Child=body;
            Button button=new Button{Width=width+6,Height=height+6,Margin=new Thickness(7),Padding=new Thickness(0),Background=Brushes.Transparent,BorderThickness=new Thickness(0),Content=frame,RenderTransformOrigin=new Point(0.5,0.5)};button.Click+=delegate{invoke();};return new Border{Child=button,Background=Brushes.Transparent};
        }

        private void AddHardwareGame(Panel panel, ConsolePlatformGame game, Color accent, double width, double height, string mediaLabel)
        {
            ConsolePlatformGame captured=game; Border wrapper=CreateHardwareGameCard(game,accent,width,height,mediaLabel,delegate{LaunchGame(captured,false);});panel.Children.Add(wrapper);Button button=wrapper.Child as Button;if(button!=null)actions.Add(new ConsolePlatformAction{Button=button,Name=game.Name,Game=game,Invoke=delegate{LaunchGame(captured,false);}});
        }

        private void AddHardwareUtility(Panel panel,string title,string detail,string glyph,Color accent,Action invoke,double width,double height)
        {
            Button button=CreateWave1Tile(title,detail,glyph,new SolidColorBrush(Color.FromArgb(225,accent.R,accent.G,accent.B)),Brushes.White,invoke,width,height);panel.Children.Add(button);actions.Add(new ConsolePlatformAction{Button=button,Name=title,Invoke=invoke});
        }

        private void RenderAtari2600Deck()
        {
            titleText.Text=String.Empty;subtitleText.Text=String.Empty;columns=5;Grid body=new Grid{Margin=new Thickness(45,5,45,18)};body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(185)});body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(1,GridUnitType.Star)});contentHost.Children.Add(body);
            Border deck=new Border{CornerRadius=new CornerRadius(8),Background=new LinearGradientBrush(Color.FromRgb(60,33,17),Color.FromRgb(126,74,36),0),BorderBrush=new SolidColorBrush(Color.FromRgb(17,16,15)),BorderThickness=new Thickness(8),Padding=new Thickness(20)};Grid d=new Grid();d.ColumnDefinitions.Add(new ColumnDefinition{Width=new GridLength(1,GridUnitType.Star)});d.ColumnDefinitions.Add(new ColumnDefinition{Width=new GridLength(350)});TextBlock brand=new TextBlock{Text="ATARI\nVIDEO COMPUTER SYSTEM",FontSize=22,FontWeight=FontWeights.Light,Foreground=new SolidColorBrush(Color.FromRgb(239,213,170)),VerticalAlignment=VerticalAlignment.Center,Margin=new Thickness(35,0,0,0)};d.Children.Add(brand);StackPanel switches=new StackPanel{Orientation=Orientation.Horizontal,HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center};foreach(string name in new[]{"POWER","TV TYPE","GAME SELECT","GAME RESET"}){StackPanel sw=new StackPanel{Width=76};sw.Children.Add(new Border{Width=12,Height=52,Background=new SolidColorBrush(Color.FromRgb(215,215,207)),BorderBrush=Brushes.Black,BorderThickness=new Thickness(2),HorizontalAlignment=HorizontalAlignment.Center});sw.Children.Add(new TextBlock{Text=name,FontSize=7,Foreground=new SolidColorBrush(Color.FromRgb(238,215,179)),TextAlignment=TextAlignment.Center,HorizontalAlignment=HorizontalAlignment.Center,Margin=new Thickness(0,5,0,0)});switches.Children.Add(sw);}Grid.SetColumn(switches,1);d.Children.Add(switches);deck.Child=d;body.Children.Add(deck);
            ScrollViewer sc=new ScrollViewer{HorizontalScrollBarVisibility=ScrollBarVisibility.Hidden,VerticalScrollBarVisibility=ScrollBarVisibility.Disabled};StackPanel row=new StackPanel{Orientation=Orientation.Horizontal,VerticalAlignment=VerticalAlignment.Center};sc.Content=row;Grid.SetRow(sc,1);body.Children.Add(sc);foreach(ConsolePlatformGame game in games)AddHardwareGame(row,game,Color.FromRgb(220,149,57),136,178,"CARTRIDGE");AddHardwareUtility(row,"Console Setup",definition.PrimaryBackend,"⚙",Color.FromRgb(143,76,34),delegate{OpenWave1Subpage("settings");},150,178);
        }

        private void RenderNesDeck()
        {
            titleText.Text=String.Empty;subtitleText.Text=String.Empty;columns=6;Grid body=new Grid{Margin=new Thickness(55,0,55,16)};body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(155)});body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(1,GridUnitType.Star)});contentHost.Children.Add(body);Border console=new Border{CornerRadius=new CornerRadius(4),Background=new LinearGradientBrush(Color.FromRgb(204,203,198),Color.FromRgb(128,128,125),90),BorderBrush=new SolidColorBrush(Color.FromRgb(54,54,53)),BorderThickness=new Thickness(3),Padding=new Thickness(20)};Grid c=new Grid();c.ColumnDefinitions.Add(new ColumnDefinition());c.ColumnDefinitions.Add(new ColumnDefinition{Width=new GridLength(320)});Border slot=new Border{Height=45,Background=new SolidColorBrush(Color.FromRgb(36,37,37)),BorderBrush=new SolidColorBrush(Color.FromRgb(81,81,79)),BorderThickness=new Thickness(4),VerticalAlignment=VerticalAlignment.Center,Margin=new Thickness(30,0,45,0)};c.Children.Add(slot);StackPanel right=new StackPanel{VerticalAlignment=VerticalAlignment.Center};right.Children.Add(new TextBlock{Text="Nintendo\nENTERTAINMENT SYSTEM",FontSize=20,FontWeight=FontWeights.Bold,Foreground=new SolidColorBrush(Color.FromRgb(186,34,41)),HorizontalAlignment=HorizontalAlignment.Center,TextAlignment=TextAlignment.Center});right.Children.Add(new TextBlock{Text="POWER     RESET",FontSize=9,Foreground=new SolidColorBrush(Color.FromRgb(55,55,54)),HorizontalAlignment=HorizontalAlignment.Center,Margin=new Thickness(0,15,0,0)});Grid.SetColumn(right,1);c.Children.Add(right);console.Child=c;body.Children.Add(console);WrapPanel cards=new WrapPanel{Margin=new Thickness(0,12,0,0)};ScrollViewer scroll=new ScrollViewer{VerticalScrollBarVisibility=ScrollBarVisibility.Hidden,Content=cards};Grid.SetRow(scroll,1);body.Children.Add(scroll);foreach(ConsolePlatformGame game in games)AddHardwareGame(cards,game,Color.FromRgb(194,35,42),132,170,"GAME PAK");AddHardwareUtility(cards,"Control Deck",definition.PrimaryBackend,"⚙",Color.FromRgb(194,35,42),delegate{OpenWave1Subpage("settings");},145,170);
        }

        private void RenderSnesDeck()
        {
            titleText.Text=String.Empty;subtitleText.Text=String.Empty;columns=6;Grid body=new Grid{Margin=new Thickness(55,0,55,16)};body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(160)});body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(1,GridUnitType.Star)});contentHost.Children.Add(body);Border console=new Border{CornerRadius=new CornerRadius(30),Background=new LinearGradientBrush(Color.FromRgb(216,215,212),Color.FromRgb(153,151,154),90),BorderBrush=new SolidColorBrush(Color.FromRgb(98,95,105)),BorderThickness=new Thickness(3),Padding=new Thickness(22)};Grid c=new Grid();Border slot=new Border{Width=420,Height=44,Background=new SolidColorBrush(Color.FromRgb(77,75,84)),BorderBrush=new SolidColorBrush(Color.FromRgb(130,127,137)),BorderThickness=new Thickness(3),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center};c.Children.Add(slot);c.Children.Add(new TextBlock{Text="SUPER NINTENDO\nENTERTAINMENT SYSTEM",FontSize=16,FontWeight=FontWeights.SemiBold,Foreground=new SolidColorBrush(Color.FromRgb(78,75,87)),HorizontalAlignment=HorizontalAlignment.Left,VerticalAlignment=VerticalAlignment.Center,Margin=new Thickness(25,0,0,0),TextAlignment=TextAlignment.Center});c.Children.Add(new TextBlock{Text="●  ●  ●  ●",FontSize=23,Foreground=new SolidColorBrush(Color.FromRgb(103,74,151)),HorizontalAlignment=HorizontalAlignment.Right,VerticalAlignment=VerticalAlignment.Center,Margin=new Thickness(0,0,35,0)});console.Child=c;body.Children.Add(console);WrapPanel cards=new WrapPanel{Margin=new Thickness(0,10,0,0)};ScrollViewer scroll=new ScrollViewer{VerticalScrollBarVisibility=ScrollBarVisibility.Hidden,Content=cards};Grid.SetRow(scroll,1);body.Children.Add(scroll);foreach(ConsolePlatformGame game in games)AddHardwareGame(cards,game,Color.FromRgb(103,74,151),132,170,"GAME PAK");AddHardwareUtility(cards,"Console Setup",definition.PrimaryBackend,"⚙",Color.FromRgb(103,74,151),delegate{OpenWave1Subpage("settings");},145,170);
        }

        private void RenderGameBoyHandheld(bool colorModel)
        {
            titleText.Text=String.Empty;subtitleText.Text=String.Empty;columns=4;Grid body=new Grid{Margin=new Thickness(70,0,70,20)};body.ColumnDefinitions.Add(new ColumnDefinition{Width=new GridLength(410)});body.ColumnDefinitions.Add(new ColumnDefinition());contentHost.Children.Add(body);Color shell=colorModel?Color.FromRgb(86,38,131):Color.FromRgb(190,191,181);Border handheld=new Border{Width=330,Height=520,CornerRadius=new CornerRadius(18,18,55,18),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center,Background=new LinearGradientBrush(shell,Color.FromRgb((byte)Math.Max(0,shell.R-35),(byte)Math.Max(0,shell.G-35),(byte)Math.Max(0,shell.B-35)),90),BorderBrush=new SolidColorBrush(Color.FromRgb(69,69,67)),BorderThickness=new Thickness(3),Padding=new Thickness(25)};StackPanel h=new StackPanel();h.Children.Add(new TextBlock{Text=colorModel?"GAME BOY COLOR":"DOT MATRIX WITH STEREO SOUND",FontSize=colorModel?22:9,FontWeight=FontWeights.SemiBold,Foreground=colorModel?Brushes.White:new SolidColorBrush(Color.FromRgb(56,65,100)),HorizontalAlignment=HorizontalAlignment.Center});Border screen=new Border{Height=230,Margin=new Thickness(0,18,0,20),CornerRadius=new CornerRadius(8),Background=new SolidColorBrush(colorModel?Color.FromRgb(82,91,78):Color.FromRgb(119,137,84)),BorderBrush=new SolidColorBrush(Color.FromRgb(55,55,55)),BorderThickness=new Thickness(12)};ConsolePlatformGame selectedGame=games.Count>0?games[Math.Max(0,Math.Min(games.Count-1,selected))]:null;if(selectedGame!=null&&!String.IsNullOrWhiteSpace(selectedGame.Cover)&&File.Exists(selectedGame.Cover)){try{screen.Child=new Image{Source=LoadBitmap(selectedGame.Cover),Stretch=Stretch.Uniform};}catch{}}if(screen.Child==null)screen.Child=new TextBlock{Text=games.Count+"\nGAMES",FontFamily=new FontFamily("Consolas"),FontSize=28,FontWeight=FontWeights.Bold,Foreground=new SolidColorBrush(Color.FromRgb(30,53,30)),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center,TextAlignment=TextAlignment.Center};h.Children.Add(screen);h.Children.Add(new TextBlock{Text="✚                       A     B",FontSize=25,Foreground=colorModel?Brushes.White:new SolidColorBrush(Color.FromRgb(73,65,88)),HorizontalAlignment=HorizontalAlignment.Center});h.Children.Add(new TextBlock{Text="SELECT     START",FontSize=10,Foreground=colorModel?Brushes.White:new SolidColorBrush(Color.FromRgb(73,65,88)),HorizontalAlignment=HorizontalAlignment.Center,Margin=new Thickness(0,26,0,0)});handheld.Child=h;body.Children.Add(handheld);WrapPanel list=new WrapPanel{Margin=new Thickness(15)};ScrollViewer sc=new ScrollViewer{VerticalScrollBarVisibility=ScrollBarVisibility.Hidden,Content=list};Grid.SetColumn(sc,1);body.Children.Add(sc);Color accent=colorModel?Color.FromRgb(244,73,142):Color.FromRgb(117,44,111);foreach(ConsolePlatformGame game in games)AddHardwareGame(list,game,accent,120,155,"PAK");AddHardwareUtility(list,"System",definition.PrimaryBackend,"⚙",accent,delegate{OpenWave1Subpage("settings");},132,155);
        }

        private void RenderGbaHandheld()
        {
            titleText.Text=String.Empty;subtitleText.Text=String.Empty;columns=5;Grid body=new Grid{Margin=new Thickness(38,8,38,18)};body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(330)});body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(1,GridUnitType.Star)});contentHost.Children.Add(body);Border handheld=new Border{CornerRadius=new CornerRadius(110),Background=new LinearGradientBrush(Color.FromRgb(91,65,159),Color.FromRgb(53,36,103),90),BorderBrush=new SolidColorBrush(Color.FromRgb(33,24,65)),BorderThickness=new Thickness(4),Padding=new Thickness(36),Margin=new Thickness(45,0,45,8)};Grid h=new Grid();h.ColumnDefinitions.Add(new ColumnDefinition{Width=new GridLength(150)});h.ColumnDefinitions.Add(new ColumnDefinition());h.ColumnDefinitions.Add(new ColumnDefinition{Width=new GridLength(150)});h.Children.Add(new TextBlock{Text="✚",FontSize=64,Foreground=new SolidColorBrush(Color.FromRgb(39,31,70)),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center});Border screen=new Border{CornerRadius=new CornerRadius(10),Background=new SolidColorBrush(Color.FromRgb(39,55,58)),BorderBrush=new SolidColorBrush(Color.FromRgb(24,26,33)),BorderThickness=new Thickness(11),Margin=new Thickness(10)};Grid.SetColumn(screen,1);screen.Child=new TextBlock{Text="GAME BOY\nADVANCE",FontSize=26,FontStyle=FontStyles.Italic,Foreground=new SolidColorBrush(Color.FromRgb(169,185,182)),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center,TextAlignment=TextAlignment.Center};h.Children.Add(screen);TextBlock ab=new TextBlock{Text="A    B",FontSize=30,FontWeight=FontWeights.Bold,Foreground=new SolidColorBrush(Color.FromRgb(183,156,241)),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center};Grid.SetColumn(ab,2);h.Children.Add(ab);handheld.Child=h;body.Children.Add(handheld);WrapPanel cards=new WrapPanel;ScrollViewer scroll=new ScrollViewer{VerticalScrollBarVisibility=ScrollBarVisibility.Hidden,Content=cards};Grid.SetRow(scroll,1);body.Children.Add(scroll);foreach(ConsolePlatformGame game in games)AddHardwareGame(cards,game,Color.FromRgb(168,145,255),126,158,"GBA");AddHardwareUtility(cards,"System",definition.PrimaryBackend,"⚙",Color.FromRgb(92,66,157),delegate{OpenWave1Subpage("settings");},140,158);
        }

        private void RenderGenesisDeck(bool thirtyTwoX)
        {
            titleText.Text=String.Empty;subtitleText.Text=String.Empty;columns=6;Grid body=new Grid{Margin=new Thickness(50,0,50,18)};body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(210)});body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(1,GridUnitType.Star)});contentHost.Children.Add(body);Border deck=new Border{CornerRadius=new CornerRadius(105),Background=new RadialGradientBrush(Color.FromRgb(47,49,51),Color.FromRgb(4,5,6)),BorderBrush=new SolidColorBrush(Color.FromRgb(72,74,76)),BorderThickness=new Thickness(5),Margin=new Thickness(160,0,160,10)};Grid g=new Grid();g.Children.Add(new Border{Width=thirtyTwoX?220:330,Height=thirtyTwoX?130:55,CornerRadius=new CornerRadius(thirtyTwoX?18:5),Background=new SolidColorBrush(Color.FromRgb(15,16,17)),BorderBrush=new SolidColorBrush(Color.FromRgb(78,80,82)),BorderThickness=new Thickness(4),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center});g.Children.Add(new TextBlock{Text=thirtyTwoX?"SEGA 32X\n32-BIT ENHANCEMENT":"16-BIT\nSEGA GENESIS",FontSize=thirtyTwoX?22:18,FontWeight=FontWeights.Bold,Foreground=new SolidColorBrush(thirtyTwoX?Color.FromRgb(224,60,48):Color.FromRgb(210,210,211)),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center,TextAlignment=TextAlignment.Center});deck.Child=g;body.Children.Add(deck);WrapPanel cards=new WrapPanel;ScrollViewer scroll=new ScrollViewer{VerticalScrollBarVisibility=ScrollBarVisibility.Hidden,Content=cards};Grid.SetRow(scroll,1);body.Children.Add(scroll);Color accent=thirtyTwoX?Color.FromRgb(224,60,48):Color.FromRgb(191,34,45);foreach(ConsolePlatformGame game in games)AddHardwareGame(cards,game,accent,126,158,thirtyTwoX?"32X":"GENESIS");AddHardwareUtility(cards,"System",definition.PrimaryBackend,"⚙",accent,delegate{OpenWave1Subpage("settings");},140,158);
        }

        private void RenderSegaCdDeck()
        {
            titleText.Text=String.Empty;subtitleText.Text=String.Empty;columns=4;Grid body=new Grid{Margin=new Thickness(65,0,65,18)};body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(250)});body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(1,GridUnitType.Star)});contentHost.Children.Add(body);Border system=new Border{CornerRadius=new CornerRadius(12),Background=new LinearGradientBrush(Color.FromRgb(38,41,45),Color.FromRgb(5,7,9),90),BorderBrush=new SolidColorBrush(Color.FromRgb(76,82,88)),BorderThickness=new Thickness(4),Padding=new Thickness(22),Margin=new Thickness(145,0,145,10)};Grid s=new Grid();System.Windows.Shapes.Ellipse tray=new System.Windows.Shapes.Ellipse{Width=210,Height=210,Fill=new RadialGradientBrush(Color.FromRgb(37,39,42),Color.FromRgb(6,7,8)),Stroke=new SolidColorBrush(Color.FromRgb(100,105,109)),StrokeThickness=4,HorizontalAlignment=HorizontalAlignment.Left};s.Children.Add(tray);TextBlock label=new TextBlock{Text="SEGA CD\nCD-ROM SYSTEM",FontSize=24,FontWeight=FontWeights.Light,Foreground=new SolidColorBrush(Color.FromRgb(157,195,228)),HorizontalAlignment=HorizontalAlignment.Right,VerticalAlignment=VerticalAlignment.Center,Margin=new Thickness(0,0,65,0),TextAlignment=TextAlignment.Center};s.Children.Add(label);system.Child=s;body.Children.Add(system);WrapPanel cards=new WrapPanel;ScrollViewer scroll=new ScrollViewer{VerticalScrollBarVisibility=ScrollBarVisibility.Hidden,Content=cards};Grid.SetRow(scroll,1);body.Children.Add(scroll);foreach(ConsolePlatformGame game in games)AddHardwareGame(cards,game,Color.FromRgb(80,147,214),132,166,"COMPACT DISC");AddHardwareUtility(cards,"CD Player","local disc audio","♪",Color.FromRgb(80,147,214),delegate{OpenWave1Subpage("music");},145,166);AddHardwareUtility(cards,"Backup RAM","saved games","▣",Color.FromRgb(56,112,167),delegate{OpenWave1Subpage("saves");},145,166);AddHardwareUtility(cards,"System",definition.PrimaryBackend,"⚙",Color.FromRgb(45,88,130),delegate{OpenWave1Subpage("settings");},145,166);
        }

        private void RenderGameGearHandheld()
        {
            titleText.Text=String.Empty;subtitleText.Text=String.Empty;columns=5;Grid body=new Grid{Margin=new Thickness(35,5,35,18)};body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(335)});body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(1,GridUnitType.Star)});contentHost.Children.Add(body);Border handheld=new Border{CornerRadius=new CornerRadius(95),Background=new LinearGradientBrush(Color.FromRgb(34,39,45),Color.FromRgb(8,10,12),90),BorderBrush=new SolidColorBrush(Color.FromRgb(58,65,72)),BorderThickness=new Thickness(4),Padding=new Thickness(32),Margin=new Thickness(100,0,100,10)};Grid h=new Grid();h.ColumnDefinitions.Add(new ColumnDefinition{Width=new GridLength(170)});h.ColumnDefinitions.Add(new ColumnDefinition());h.ColumnDefinitions.Add(new ColumnDefinition{Width=new GridLength(170)});h.Children.Add(new TextBlock{Text="✚",FontSize=58,Foreground=new SolidColorBrush(Color.FromRgb(52,60,68)),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center});Border screen=new Border{Background=new SolidColorBrush(Color.FromRgb(29,43,50)),BorderBrush=new SolidColorBrush(Color.FromRgb(5,7,9)),BorderThickness=new Thickness(12),CornerRadius=new CornerRadius(7),Margin=new Thickness(5),Child=new TextBlock{Text="GAME GEAR",FontSize=29,FontWeight=FontWeights.Bold,Foreground=new SolidColorBrush(Color.FromRgb(47,137,205)),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center}};Grid.SetColumn(screen,1);h.Children.Add(screen);TextBlock buttons=new TextBlock{Text="1    2",FontSize=30,Foreground=new SolidColorBrush(Color.FromRgb(198,49,55)),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center};Grid.SetColumn(buttons,2);h.Children.Add(buttons);handheld.Child=h;body.Children.Add(handheld);WrapPanel cards=new WrapPanel;ScrollViewer scroll=new ScrollViewer{VerticalScrollBarVisibility=ScrollBarVisibility.Hidden,Content=cards};Grid.SetRow(scroll,1);body.Children.Add(scroll);foreach(ConsolePlatformGame game in games)AddHardwareGame(cards,game,Color.FromRgb(47,137,205),126,158,"GAME GEAR");AddHardwareUtility(cards,"System",definition.PrimaryBackend,"⚙",Color.FromRgb(47,137,205),delegate{OpenWave1Subpage("settings");},140,158);
        }

        private void RenderMasterSystemDeck()
        {
            titleText.Text=String.Empty;subtitleText.Text=String.Empty;columns=6;Grid body=new Grid{Margin=new Thickness(55,0,55,18)};body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(160)});body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(1,GridUnitType.Star)});contentHost.Children.Add(body);Border deck=new Border{Background=new LinearGradientBrush(Color.FromRgb(44,45,46),Color.FromRgb(7,8,9),90),BorderBrush=new SolidColorBrush(Color.FromRgb(93,94,95)),BorderThickness=new Thickness(3),Padding=new Thickness(24)};Grid g=new Grid();g.Children.Add(new TextBlock{Text="SEGA\nMASTER SYSTEM",FontSize=24,FontWeight=FontWeights.Bold,Foreground=Brushes.White,HorizontalAlignment=HorizontalAlignment.Left,VerticalAlignment=VerticalAlignment.Center,Margin=new Thickness(35,0,0,0),TextAlignment=TextAlignment.Center});g.Children.Add(new Border{Width=400,Height=45,Background=new SolidColorBrush(Color.FromRgb(14,15,16)),BorderBrush=new SolidColorBrush(Color.FromRgb(206,31,39)),BorderThickness=new Thickness(0,5,0,0),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center});g.Children.Add(new TextBlock{Text="POWER  ●     RESET  ○",FontSize=11,Foreground=new SolidColorBrush(Color.FromRgb(206,31,39)),HorizontalAlignment=HorizontalAlignment.Right,VerticalAlignment=VerticalAlignment.Center,Margin=new Thickness(0,0,40,0)});deck.Child=g;body.Children.Add(deck);WrapPanel cards=new WrapPanel{Margin=new Thickness(0,10,0,0)};ScrollViewer scroll=new ScrollViewer{VerticalScrollBarVisibility=ScrollBarVisibility.Hidden,Content=cards};Grid.SetRow(scroll,1);body.Children.Add(scroll);foreach(ConsolePlatformGame game in games)AddHardwareGame(cards,game,Color.FromRgb(206,31,39),126,158,"CARTRIDGE");AddHardwareUtility(cards,"System",definition.PrimaryBackend,"⚙",Color.FromRgb(206,31,39),delegate{OpenWave1Subpage("settings");},140,158);
        }

        private void RenderTurboGrafxDeck()
        {
            titleText.Text=String.Empty;subtitleText.Text=String.Empty;columns=6;Grid body=new Grid{Margin=new Thickness(55,0,55,18)};body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(155)});body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(1,GridUnitType.Star)});contentHost.Children.Add(body);Border deck=new Border{CornerRadius=new CornerRadius(5),Background=new LinearGradientBrush(Color.FromRgb(235,234,230),Color.FromRgb(184,183,178),90),BorderBrush=new SolidColorBrush(Color.FromRgb(103,103,100)),BorderThickness=new Thickness(3),Padding=new Thickness(22)};Grid g=new Grid();g.Children.Add(new TextBlock{Text="TurboGrafx-16\nENTERTAINMENT SUPER SYSTEM",FontSize=21,FontWeight=FontWeights.SemiBold,Foreground=new SolidColorBrush(Color.FromRgb(67,67,65)),HorizontalAlignment=HorizontalAlignment.Left,VerticalAlignment=VerticalAlignment.Center,Margin=new Thickness(35,0,0,0),TextAlignment=TextAlignment.Center});g.Children.Add(new Border{Width=290,Height=12,Background=new SolidColorBrush(Color.FromRgb(55,55,53)),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center});g.Children.Add(new TextBlock{Text="POWER",FontSize=10,Foreground=new SolidColorBrush(Color.FromRgb(193,34,42)),HorizontalAlignment=HorizontalAlignment.Right,VerticalAlignment=VerticalAlignment.Center,Margin=new Thickness(0,0,55,0)});deck.Child=g;body.Children.Add(deck);WrapPanel cards=new WrapPanel{Margin=new Thickness(0,10,0,0)};ScrollViewer scroll=new ScrollViewer{VerticalScrollBarVisibility=ScrollBarVisibility.Hidden,Content=cards};Grid.SetRow(scroll,1);body.Children.Add(scroll);foreach(ConsolePlatformGame game in games)AddHardwareGame(cards,game,Color.FromRgb(193,34,42),126,158,Path.GetExtension(game.Path).Equals(".cue",StringComparison.OrdinalIgnoreCase)||Path.GetExtension(game.Path).Equals(".chd",StringComparison.OrdinalIgnoreCase)?"CD-ROM²":"HUCARD");AddHardwareUtility(cards,"System",definition.PrimaryBackend,"⚙",Color.FromRgb(193,34,42),delegate{OpenWave1Subpage("settings");},140,158);
        }

'''
if 'private bool IsWave2Shell()' not in text:
 anchor='        private void RenderXboxRoot()\n'
 if text.count(anchor)!=1:raise SystemExit('Wave2 methods insertion anchor missing')
 text=text.replace(anchor,methods+anchor,1)

cs.write_text(text,encoding='utf-8')
print('staged Wave 2 platform definitions and native hardware shells')
