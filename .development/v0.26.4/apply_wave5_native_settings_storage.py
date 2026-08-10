from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
path=ROOT/'Native'/'HuymaierConsole.ConsolePlatforms.cs';text=path.read_text(encoding='utf-8-sig')
old='''        private void RenderWave45Subpage() { if(dashboardSubpage=="library"){RenderWave1Library();return;}if(dashboardSubpage=="backend-settings"||dashboardSubpage=="backend-settings-list"||dashboardSubpage=="backend-setting-detail"){RenderWave1Subpage();return;}if((definition.Shell=="Arcade"||definition.Shell=="FinalBurnNeo")&&dashboardSubpage=="settings"){RenderArcadeOperatorSettings();return;}if((definition.Shell=="Arcade"||definition.Shell=="FinalBurnNeo")&&dashboardSubpage=="saves"){RenderArcadeStorage();return;}if(dashboardSubpage=="settings"){RenderWave1Settings();return;}if(dashboardSubpage=="saves"){RenderWave1Storage();return;}RenderWave1Settings(); }
'''
new='''        private void RenderWave45Subpage() { if(dashboardSubpage=="library"){RenderWave1Library();return;}if(dashboardSubpage=="backend-settings"||dashboardSubpage=="backend-settings-list"||dashboardSubpage=="backend-setting-detail"){RenderWave1Subpage();return;}if((definition.Shell=="Arcade"||definition.Shell=="FinalBurnNeo")&&dashboardSubpage=="settings"){RenderArcadeOperatorSettings();return;}if((definition.Shell=="Arcade"||definition.Shell=="FinalBurnNeo")&&dashboardSubpage=="saves"){RenderArcadeStorage();return;}if((definition.Shell=="PS4"||definition.Shell=="Vita")&&dashboardSubpage=="settings"){RenderModernPlayStationSettings();return;}if((definition.Shell=="PS4"||definition.Shell=="Vita")&&dashboardSubpage=="saves"){RenderModernPlayStationStorage();return;}if(dashboardSubpage=="settings"){RenderWave1Settings();return;}if(dashboardSubpage=="saves"){RenderWave1Storage();return;}RenderWave1Settings(); }
'''
if old in text:text=text.replace(old,new,1)
elif 'private void RenderModernPlayStationSettings()' not in text:raise SystemExit('Modern PS subpage routing anchor missing')
methods=r'''
        private Color GetModernPlayStationAccent(){return definition.Shell=="PS4"?Color.FromRgb(75,173,255):Color.FromRgb(115,222,255);}
        private List<string> GetModernPlayStationSaveRoots()
        {
            List<string> roots=new List<string>();Action<string> add=delegate(string value){if(String.IsNullOrWhiteSpace(value))return;try{if(File.Exists(value))value=Path.GetDirectoryName(value);if(Directory.Exists(value)&&!roots.Contains(value,StringComparer.OrdinalIgnoreCase))roots.Add(value);}catch{}};add(settings.emulatorDataPath);add(settings.emulatorPath);string exeRoot=!String.IsNullOrWhiteSpace(settings.emulatorPath)&&File.Exists(settings.emulatorPath)?Path.GetDirectoryName(settings.emulatorPath):String.Empty;add(exeRoot);
            foreach(string root in roots.ToArray())
            {
                try
                {
                    if(definition.Shell=="Vita"){add(Path.Combine(root,"ux0","user","00","savedata"));add(Path.Combine(root,"Vita3K","ux0","user","00","savedata"));}
                    else{add(Path.Combine(root,"user","savedata"));add(Path.Combine(root,"savedata"));add(Path.Combine(root,"user","home"));add(Path.Combine(root,"save"));}
                }catch{}
            }
            return roots;
        }
        private List<string> FindModernPlayStationSaveItems()
        {
            HashSet<string> items=new HashSet<string>(StringComparer.OrdinalIgnoreCase);int visited=0;
            foreach(string root in GetModernPlayStationSaveRoots())
            {
                if(!Directory.Exists(root))continue;try{foreach(string dir in Directory.GetDirectories(root)){if(++visited>4000)break;items.Add(dir);}}catch{}if(visited>4000)break;
            }
            return items.OrderBy(delegate(string value){return Path.GetFileName(value);},StringComparer.CurrentCultureIgnoreCase).ToList();
        }
        private void RenderModernPlayStationStorage()
        {
            Color accent=GetModernPlayStationAccent();bool vita=definition.Shell=="Vita";titleText.Text=vita?"Content Manager":"Saved Data Management";subtitleText.Text=vita?"PS Vita saved data inside the Vita3K user environment":"PS4 saved data inside the shadPS4 user environment";columns=3;WrapPanel panel=new WrapPanel{Margin=new Thickness(42,10,42,24)};contentHost.Children.Add(new ScrollViewer{VerticalScrollBarVisibility=ScrollBarVisibility.Hidden,Content=panel});List<string> items=FindModernPlayStationSaveItems();foreach(string value in items.Take(500)){string captured=value;string title=Path.GetFileName(value);string sfo=Path.Combine(value,"param.sfo");if(File.Exists(sfo)){string parsed=ReadPspSfoString(sfo,"TITLE");if(!String.IsNullOrWhiteSpace(parsed))title=parsed;}AddHardwareUtility(panel,title,FormatBytes(GetPathSize(value))+"  •  "+Path.GetFileName(value),vita?"◉":"▣",accent,delegate{BackupNativeSavePath(captured,definition.Id+"-"+Path.GetFileName(captured));},300,130);}if(items.Count==0)AddHardwareUtility(panel,"No Saved Data","No emulator save directories have been detected yet.",vita?"◉":"▣",accent,delegate{dashboardSubpage="settings";selected=0;RenderPage();},300,130);else AddHardwareUtility(panel,"Back Up All",items.Count+" save item(s)","⇧",accent,delegate{foreach(string value in items)BackupNativeSavePath(value,definition.Id+"-"+Path.GetFileName(value));},300,130);
        }
        private void RenderModernPlayStationSettings()
        {
            Color accent=GetModernPlayStationAccent();bool vita=definition.Shell=="Vita";titleText.Text=vita?"Settings":"Settings";subtitleText.Text=definition.PrimaryBackend+"  •  Huymaier native system integration";columns=3;Grid body=new Grid{Margin=new Thickness(45,6,45,24)};body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(vita?95:74)});body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(1,GridUnitType.Star)});contentHost.Children.Add(body);Border header=new Border{CornerRadius=new CornerRadius(vita?38:4),Background=new LinearGradientBrush(Color.FromArgb(220,accent.R,accent.G,accent.B),Color.FromArgb(150,13,66,135),0),BorderBrush=new SolidColorBrush(Color.FromArgb(210,255,255,255)),BorderThickness=new Thickness(2),Padding=new Thickness(20),Child=new TextBlock{Text=vita?"LIVEAREA SYSTEM SETTINGS":"PS4 SYSTEM SETTINGS",FontSize=20,FontWeight=FontWeights.SemiBold,Foreground=Brushes.White,HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center}};body.Children.Add(header);WrapPanel panel=new WrapPanel{Margin=new Thickness(0,12,0,0)};ScrollViewer scroll=new ScrollViewer{VerticalScrollBarVisibility=ScrollBarVisibility.Hidden,Content=panel};Grid.SetRow(scroll,1);body.Children.Add(scroll);if(String.IsNullOrWhiteSpace(settings.emulatorPath)||!File.Exists(settings.emulatorPath)){AddHardwareUtility(panel,"Locate Emulator",definition.PrimaryBackend,"⌕",accent,ChoosePrimaryEmulator,300,132);AddHardwareUtility(panel,"Install Latest",definition.PrimaryBackend+" current supported build","↓",accent,InstallPrimaryEmulator,300,132);}else AddHardwareUtility(panel,definition.PrimaryBackend,settings.emulatorPath,"✓",accent,ChoosePrimaryEmulator,300,132);AddHardwareUtility(panel,"Full Emulator Settings","Every discovered backend setting","⚙",accent,OpenNativeBackendSettings,300,132);AddHardwareUtility(panel,"Emulator Data",DisplayPath(settings.emulatorDataPath),"▣",accent,ChooseEmulatorDataRoot,300,132);AddHardwareUtility(panel,"Application Folders",settings.gameFolders.Count+" configured","▦",accent,AddGameFolder,300,132);AddHardwareUtility(panel,vita?"Content Manager":"Saved Data Management","Native save storage","◫",accent,delegate{dashboardSubpage="saves";selected=0;RenderPage();},300,132);AddHardwareUtility(panel,"Refresh Installed Apps",games.Count+" installed applications","↻",accent,delegate{RefreshLibrary(true);},300,132);
        }

'''
anchor='        private void RenderPs4DynamicMenu()\n'
if 'private void RenderModernPlayStationSettings()' not in text:
    if text.count(anchor)!=1:raise SystemExit('Modern PS settings methods insertion anchor missing')
    text=text.replace(anchor,methods+anchor,1)
path.write_text(text,encoding='utf-8');print('materialized PS4 Dynamic Menu and Vita LiveArea native settings/storage subpages')
