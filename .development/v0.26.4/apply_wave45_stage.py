from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[2]
platforms={
 'Arcade':dict(id='arcade',display='Arcade',backend='MAME',fallback='FinalBurn Neo',adapter='mame',interface='Native arcade-cabinet library and operator interface',ext=['.zip','.7z','.chd'],style='Arcade Cabinet'),
 'FinalBurnNeo':dict(id='finalburnneo',display='Final Burn Neo',backend='FinalBurn Neo',fallback='MAME',adapter='fbneo',interface='Native arcade-board / operator interface',ext=['.zip','.7z','.chd'],style='FBNeo Arcade Board'),
 'PS4':dict(id='ps4',display='PlayStation 4',backend='shadPS4',fallback='shadPS4 Nightly',adapter='shadps4',interface='Native PS4 Dynamic Menu-style interface',ext=['.pkg','.elf','.bin'],style='Dynamic Menu'),
 'Vita':dict(id='vita',display='PlayStation Vita',backend='Vita3K',fallback='Vita3K Development',adapter='vita3k',interface='Native PlayStation Vita LiveArea-style interface',ext=['.vpk','.pkg','.zip'],style='LiveArea')
}
def defaults(style):return {'schemaVersion':7,'emulatorPath':'','fallbackEmulatorPath':'','emulatorDataPath':'','gameFolders':[],'startupEnabled':True,'startupVolume':1.0,'ambienceEnabled':False,'ambiencePath':'','ambienceVolume':0.55,'soundVolume':1.0,'dashboardStyle':style,'fullscreen':True}
for folder,p in platforms.items():
 d=ROOT/'EmulatorPlatforms'/folder;d.mkdir(parents=True,exist_ok=True);definition={'id':p['id'],'displayName':p['display'],'primaryBackend':p['backend'],'fallbackBackend':p['fallback'],'adapter':p['adapter'],'interface':p['interface'],'version':'0.26.4-dev','enabled':False,'gameExtensions':p['ext'],'dashboardStyle':p['style']};(d/'platform.json').write_text(json.dumps(definition,indent=2)+'\n',encoding='utf-8');(d/'settings.default.json').write_text(json.dumps(defaults(p['style']),indent=2)+'\n',encoding='utf-8')

cs=ROOT/'Native'/'HuymaierConsole.ConsolePlatforms.cs';text=cs.read_text(encoding='utf-8-sig')
if 'else if (key == "ARCADE")' not in text:
 anchor='''            else if (key == "ATARILYNX")
            {
'''
 defs=r'''            else if (key == "ARCADE")
            {
                d.DisplayName="Arcade";d.Subtitle="COIN-OPERATED SYSTEM";d.Shell="Arcade";d.PrimaryBackend="MAME";d.FallbackBackend="FinalBurn Neo";d.PrimaryExecutableNames=new string[]{"mame.exe","mame64.exe"};d.FallbackExecutableNames=new string[]{"fbneo.exe","FinalBurnNeo.exe"};d.GameExtensions=new string[]{".zip",".7z",".chd"};d.ColorA=Color.FromRgb(20,10,29);d.ColorB=Color.FromRgb(4,4,7);d.Accent=Color.FromRgb(255,49,171);
            }
            else if (key == "FINALBURNNEO")
            {
                d.DisplayName="Final Burn Neo";d.Subtitle="ARCADE BOARD";d.Shell="FinalBurnNeo";d.PrimaryBackend="FinalBurn Neo";d.FallbackBackend="MAME";d.PrimaryExecutableNames=new string[]{"fbneo.exe","FinalBurnNeo.exe"};d.FallbackExecutableNames=new string[]{"mame.exe","mame64.exe"};d.GameExtensions=new string[]{".zip",".7z",".chd"};d.ColorA=Color.FromRgb(27,23,15);d.ColorB=Color.FromRgb(5,5,4);d.Accent=Color.FromRgb(255,193,37);
            }
            else if (key == "PS4")
            {
                d.DisplayName="PlayStation 4";d.Subtitle="Dynamic Menu";d.Shell="PS4";d.PrimaryBackend="shadPS4";d.FallbackBackend="shadPS4 Nightly";d.PrimaryExecutableNames=new string[]{"shadPS4.exe","shadps4.exe"};d.FallbackExecutableNames=new string[]{"shadPS4.exe","shadps4.exe"};d.GameExtensions=new string[]{".pkg",".elf",".bin"};d.ColorA=Color.FromRgb(0,91,179);d.ColorB=Color.FromRgb(0,29,82);d.Accent=Color.FromRgb(75,173,255);
            }
            else if (key == "VITA")
            {
                d.DisplayName="PlayStation Vita";d.Subtitle="LiveArea";d.Shell="Vita";d.PrimaryBackend="Vita3K";d.FallbackBackend="Vita3K Development";d.PrimaryExecutableNames=new string[]{"Vita3K.exe","vita3k.exe"};d.FallbackExecutableNames=new string[]{"Vita3K.exe","vita3k.exe"};d.GameExtensions=new string[]{".vpk",".pkg",".zip"};d.ColorA=Color.FromRgb(19,112,185);d.ColorB=Color.FromRgb(8,42,97);d.Accent=Color.FromRgb(115,222,255);
            }
'''
 if text.count(anchor)!=1:raise SystemExit('Wave4/5 definition anchor missing')
 text=text.replace(anchor,defs+anchor,1)

if 'if (IsWave45Shell()) { if (IsRootConsoleSurface()) RenderWave45Root();' not in text:
 anchor='            if (IsWave3Shell()) { if (IsRootConsoleSurface()) RenderWave3Root(); else RenderWave3Subpage(); UpdateActionVisuals(); return; }\n'
 if text.count(anchor)!=1:raise SystemExit('Wave4/5 RenderPage dispatch anchor missing')
 text=text.replace(anchor,anchor+'            if (IsWave45Shell()) { if (IsRootConsoleSurface()) RenderWave45Root(); else RenderWave45Subpage(); UpdateActionVisuals(); return; }\n',1)
 anchor2='            if (IsWave3Shell()) { RenderWave3Root(); return; }\n'
 if text.count(anchor2)!=1:raise SystemExit('Wave4/5 RenderGames guard anchor missing')
 text=text.replace(anchor2,anchor2+'            if (IsWave45Shell()) { RenderWave45Root(); return; }\n',1)

methods=r'''
        private bool IsWave45Shell() { return definition.Shell == "Arcade" || definition.Shell == "FinalBurnNeo" || definition.Shell == "PS4" || definition.Shell == "Vita"; }
        private void RenderWave45Root() { if(definition.Shell=="Arcade")RenderArcadeCabinet();else if(definition.Shell=="FinalBurnNeo")RenderFbNeoBoard();else if(definition.Shell=="PS4")RenderPs4DynamicMenu();else RenderVitaLiveArea(); }
        private void RenderWave45Subpage() { if(dashboardSubpage=="library"){RenderWave1Library();return;}if(dashboardSubpage=="settings"||dashboardSubpage=="backend-settings"||dashboardSubpage=="backend-settings-list"||dashboardSubpage=="backend-setting-detail"){RenderWave1Subpage();return;}if(dashboardSubpage=="saves"){RenderWave1Storage();return;}RenderWave1Settings(); }

        private void RenderArcadeCabinet()
        {
            titleText.Text=String.Empty;subtitleText.Text=String.Empty;columns=5;Grid body=new Grid{Margin=new Thickness(24,0,24,16)};body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(112)});body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(1,GridUnitType.Star)});body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(72)});contentHost.Children.Add(body);
            Border marquee=new Border{CornerRadius=new CornerRadius(12,12,3,3),Background=new LinearGradientBrush(Color.FromRgb(255,48,169),Color.FromRgb(77,23,151),0),BorderBrush=new SolidColorBrush(Color.FromRgb(255,208,249)),BorderThickness=new Thickness(4),Margin=new Thickness(120,0,120,8),Child=new TextBlock{Text="HUYMAIER ARCADE",FontSize=34,FontWeight=FontWeights.Black,FontFamily=new FontFamily("Arial Black"),Foreground=Brushes.White,HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center}};body.Children.Add(marquee);
            Border screenFrame=new Border{CornerRadius=new CornerRadius(22),Background=new LinearGradientBrush(Color.FromRgb(38,38,43),Color.FromRgb(4,4,6),90),BorderBrush=new SolidColorBrush(Color.FromRgb(95,95,104)),BorderThickness=new Thickness(8),Padding=new Thickness(18),Margin=new Thickness(55,0,55,0)};WrapPanel cards=new WrapPanel{HorizontalAlignment=HorizontalAlignment.Center};ScrollViewer scroll=new ScrollViewer{VerticalScrollBarVisibility=ScrollBarVisibility.Hidden,Content=cards};screenFrame.Child=scroll;Grid.SetRow(screenFrame,1);body.Children.Add(screenFrame);foreach(ConsolePlatformGame game in games)AddHardwareGame(cards,game,Color.FromRgb(255,49,171),142,184,"ARCADE");AddHardwareUtility(cards,"Operator Menu","MAME settings and DIP switches","SERVICE",Color.FromRgb(170,35,120),delegate{OpenWave1Subpage("settings");},160,184);
            Grid panel=new Grid{Background=new SolidColorBrush(Color.FromRgb(22,22,24)),Margin=new Thickness(95,4,95,0)};panel.ColumnDefinitions.Add(new ColumnDefinition());panel.ColumnDefinitions.Add(new ColumnDefinition());panel.Children.Add(new TextBlock{Text="●  1 PLAYER    ●  2 PLAYER",FontSize=15,Foreground=new SolidColorBrush(Color.FromRgb(232,232,235)),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center});TextBlock coin=new TextBlock{Text="COIN  00   •   CREDIT",FontFamily=new FontFamily("Consolas"),FontSize=14,Foreground=new SolidColorBrush(Color.FromRgb(255,205,75)),HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center};Grid.SetColumn(coin,1);panel.Children.Add(coin);Grid.SetRow(panel,2);body.Children.Add(panel);
        }

        private void RenderFbNeoBoard()
        {
            titleText.Text=String.Empty;subtitleText.Text=String.Empty;columns=6;Grid body=new Grid{Margin=new Thickness(35,0,35,18)};body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(135)});body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(1,GridUnitType.Star)});contentHost.Children.Add(body);
            Border board=new Border{CornerRadius=new CornerRadius(8),Background=new LinearGradientBrush(Color.FromRgb(46,42,25),Color.FromRgb(9,9,7),90),BorderBrush=new SolidColorBrush(Color.FromRgb(255,193,37)),BorderThickness=new Thickness(3),Padding=new Thickness(20),Margin=new Thickness(110,0,110,8)};Grid pcb=new Grid();pcb.Children.Add(new TextBlock{Text="FINALBURN NEO\nARCADE SYSTEM BOARD",FontSize=24,FontWeight=FontWeights.SemiBold,Foreground=new SolidColorBrush(Color.FromRgb(255,220,101)),HorizontalAlignment=HorizontalAlignment.Left,VerticalAlignment=VerticalAlignment.Center,Margin=new Thickness(35,0,0,0),TextAlignment=TextAlignment.Center});pcb.Children.Add(new TextBlock{Text="TEST   SERVICE   DIP SWITCH",FontFamily=new FontFamily("Consolas"),FontSize=12,Foreground=new SolidColorBrush(Color.FromRgb(202,183,113)),HorizontalAlignment=HorizontalAlignment.Right,VerticalAlignment=VerticalAlignment.Center,Margin=new Thickness(0,0,38,0)});board.Child=pcb;body.Children.Add(board);WrapPanel cards=new WrapPanel;ScrollViewer scroll=new ScrollViewer{VerticalScrollBarVisibility=ScrollBarVisibility.Hidden,Content=cards};Grid.SetRow(scroll,1);body.Children.Add(scroll);foreach(ConsolePlatformGame game in games)AddHardwareGame(cards,game,Color.FromRgb(255,193,37),132,170,"ROM SET");AddHardwareUtility(cards,"Operator / DIP","FBNeo board options","DIP",Color.FromRgb(185,136,26),delegate{OpenWave1Subpage("settings");},150,170);
        }

        private void RenderPs4DynamicMenu()
        {
            titleText.Text=String.Empty;subtitleText.Text=String.Empty;columns=1;Grid body=new Grid{Margin=new Thickness(55,15,55,20)};body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(84)});body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(1,GridUnitType.Star)});contentHost.Children.Add(body);StackPanel functions=new StackPanel{Orientation=Orientation.Horizontal,HorizontalAlignment=HorizontalAlignment.Right};foreach(string glyph in new[]{"☺","▣","◉","⚙","◷"})functions.Children.Add(new TextBlock{Text=glyph,FontSize=25,Foreground=Brushes.White,Margin=new Thickness(18,0,18,0),VerticalAlignment=VerticalAlignment.Center});body.Children.Add(functions);StackPanel row=new StackPanel{Orientation=Orientation.Horizontal,VerticalAlignment=VerticalAlignment.Center};ScrollViewer scroll=new ScrollViewer{HorizontalScrollBarVisibility=ScrollBarVisibility.Hidden,VerticalScrollBarVisibility=ScrollBarVisibility.Disabled,Content=row};Grid.SetRow(scroll,1);body.Children.Add(scroll);foreach(ConsolePlatformGame game in games){ConsolePlatformGame captured=game;Button tile=CreateWave1GameIcon(game,"PS4",Color.FromRgb(75,173,255),220,290,delegate{LaunchGame(captured,false);});row.Children.Add(tile);actions.Add(new ConsolePlatformAction{Button=tile,Name=game.Name,Game=game,Invoke=delegate{LaunchGame(captured,false);}});}AddHardwareUtility(row,"Library",games.Count+" titles","▦",Color.FromRgb(31,124,207),delegate{OpenWave1Subpage("library");},180,290);AddHardwareUtility(row,"Settings",definition.PrimaryBackend,"⚙",Color.FromRgb(20,99,181),delegate{OpenWave1Subpage("settings");},180,290);
        }

        private void RenderVitaLiveArea()
        {
            titleText.Text=String.Empty;subtitleText.Text=String.Empty;columns=5;Grid body=new Grid{Margin=new Thickness(45,5,45,18)};body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(72)});body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(1,GridUnitType.Star)});contentHost.Children.Add(body);TextBlock status=new TextBlock{Text=DateTime.Now.ToString("HH:mm",CultureInfo.CurrentCulture)+"     HUYMAIER VITA",FontSize=17,Foreground=Brushes.White,HorizontalAlignment=HorizontalAlignment.Right,VerticalAlignment=VerticalAlignment.Center};body.Children.Add(status);WrapPanel bubbles=new WrapPanel{HorizontalAlignment=HorizontalAlignment.Center,Margin=new Thickness(15)};ScrollViewer scroll=new ScrollViewer{VerticalScrollBarVisibility=ScrollBarVisibility.Hidden,Content=bubbles};Grid.SetRow(scroll,1);body.Children.Add(scroll);int index=0;foreach(ConsolePlatformGame game in games){ConsolePlatformGame captured=game;Color accent=Color.FromRgb((byte)(80+(index*37)%150),(byte)(125+(index*53)%110),(byte)(165+(index*31)%90));Button bubble=new Button{Width=175,Height=175,Margin=new Thickness(16),Padding=new Thickness(8),Background=new RadialGradientBrush(Color.FromArgb(230,(byte)Math.Min(255,accent.R+40),(byte)Math.Min(255,accent.G+40),(byte)Math.Min(255,accent.B+40)),accent),BorderBrush=new SolidColorBrush(Color.FromArgb(210,255,255,255)),BorderThickness=new Thickness(3),RenderTransformOrigin=new Point(0.5,0.5)};bubble.Template=null;Grid icon=new Grid;if(!String.IsNullOrWhiteSpace(game.Cover)&&File.Exists(game.Cover)){try{icon.Children.Add(new Image{Source=LoadBitmap(game.Cover),Stretch=Stretch.UniformToFill});}catch{}}icon.Children.Add(new TextBlock{Text=game.Name,FontSize=12,FontWeight=FontWeights.SemiBold,Foreground=Brushes.White,HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Bottom,Margin=new Thickness(8),TextAlignment=TextAlignment.Center,TextWrapping=TextWrapping.Wrap});bubble.Content=icon;bubble.Click+=delegate{LaunchGame(captured,false);};bubbles.Children.Add(bubble);actions.Add(new ConsolePlatformAction{Button=bubble,Name=game.Name,Game=game,Invoke=delegate{LaunchGame(captured,false);}});index++;}AddHardwareUtility(bubbles,"Content Manager","saved data","▣",Color.FromRgb(56,160,214),delegate{OpenWave1Subpage("saves");},175,175);AddHardwareUtility(bubbles,"Settings",definition.PrimaryBackend,"⚙",Color.FromRgb(42,111,188),delegate{OpenWave1Subpage("settings");},175,175);
        }

'''
if 'private bool IsWave45Shell()' not in text:
 anchor='        private bool IsWave3Shell()\n'
 if text.count(anchor)!=1:raise SystemExit('Wave4/5 methods insertion anchor missing')
 text=text.replace(anchor,methods+anchor,1)
cs.write_text(text,encoding='utf-8')
print('staged Wave 4 Arcade/FBNeo and Wave 5 PS4/Vita native surfaces')
