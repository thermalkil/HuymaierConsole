from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
path=ROOT/'Native'/'HuymaierConsole.ConsolePlatforms.cs';text=path.read_text(encoding='utf-8-sig')
old='''        private void RenderWave3Subpage()
        {
            if (dashboardSubpage == "library") { RenderWave1Library(); return; }
            if (dashboardSubpage == "settings" || dashboardSubpage == "backend-settings" || dashboardSubpage == "backend-settings-list" || dashboardSubpage == "backend-setting-detail") { RenderWave1Subpage(); return; }
            if (dashboardSubpage == "saves") { RenderWave1Storage(); return; }
            RenderWave1Settings();
        }
'''
new='''        private void RenderWave3Subpage()
        {
            if (dashboardSubpage == "library") { RenderWave1Library(); return; }
            if (dashboardSubpage == "backend-settings" || dashboardSubpage == "backend-settings-list" || dashboardSubpage == "backend-setting-detail") { RenderWave1Subpage(); return; }
            if (dashboardSubpage == "settings") { RenderWave3Settings(); return; }
            if (dashboardSubpage == "saves") { RenderWave3Storage(); return; }
            RenderWave3Settings();
        }
'''
if old in text:text=text.replace(old,new,1)
elif 'private void RenderWave3Settings()' not in text:raise SystemExit('Wave3 subpage replacement anchor missing')
methods=r'''
        private Color GetWave3Accent(){if(definition.Shell=="AtariLynx")return Color.FromRgb(226,82,44);if(definition.Shell=="NeoGeo")return Color.FromRgb(215,31,39);if(definition.Shell=="NGPC")return Color.FromRgb(78,183,182);if(definition.Shell=="Jaguar")return Color.FromRgb(209,35,42);return Color.FromRgb(63,225,211);}
        private string[] GetWave3SaveExtensions(){if(definition.Shell=="NeoGeo")return new[]{".mem",".nv",".nvram",".sav",".srm",".fs"};if(definition.Shell=="Jaguar")return new[]{".sav",".nv",".nvram",".eeprom",".eep",".ram"};return new[]{".sav",".srm",".ram",".rtc",".gci",".raw",".bin"};}
        private List<string> FindWave3SaveFiles(){HashSet<string> found=new HashSet<string>(StringComparer.OrdinalIgnoreCase);List<string> roots=FindSaveRoots();Action<string> addRoot=delegate(string value){if(String.IsNullOrWhiteSpace(value))return;try{if(File.Exists(value))value=Path.GetDirectoryName(value);if(Directory.Exists(value)&&!roots.Contains(value,StringComparer.OrdinalIgnoreCase))roots.Add(value);}catch{}};addRoot(settings.emulatorDataPath);addRoot(settings.emulatorPath);addRoot(settings.fallbackEmulatorPath);foreach(string root in roots.ToArray())foreach(string name in new[]{"sav","Save","Saves","memcard","Memcard","nvram","NVRAM","GC","Wii"}){try{addRoot(Path.Combine(root,name));}catch{}};string[] exts=GetWave3SaveExtensions();int visited=0;foreach(string root in roots){if(!Directory.Exists(root))continue;try{foreach(string file in Directory.EnumerateFiles(root,"*",SearchOption.AllDirectories)){if(++visited>10000)break;if(exts.Contains(Path.GetExtension(file),StringComparer.OrdinalIgnoreCase))found.Add(file);}}catch{}if(visited>10000)break;}return found.OrderBy(delegate(string p){return Path.GetFileName(p);},StringComparer.CurrentCultureIgnoreCase).ToList();}
        private void RenderWave3Storage(){Color accent=GetWave3Accent();titleText.Text=definition.Shell=="NeoGeo"?"Memory Card":(definition.Shell=="PrimeHack"?"Prime Save Data":"Saved Data");subtitleText.Text=definition.DisplayName+" native save storage";columns=3;WrapPanel panel=new WrapPanel{Margin=new Thickness(35,8,35,24)};contentHost.Children.Add(new ScrollViewer{VerticalScrollBarVisibility=ScrollBarVisibility.Hidden,Content=panel});List<string>saves=FindWave3SaveFiles();foreach(string value in saves.Take(700)){string captured=value;AddHardwareUtility(panel,Path.GetFileNameWithoutExtension(value),FormatBytes(GetPathSize(value))+"  •  "+Path.GetExtension(value).TrimStart('.').ToUpperInvariant(),"▣",accent,delegate{BackupNativeSavePath(captured,definition.Id+"-"+Path.GetFileNameWithoutExtension(captured));},300,120);}if(saves.Count==0)AddHardwareUtility(panel,"No Saved Data",definition.PrimaryBackend+" has no detected save data yet.","▣",accent,delegate{dashboardSubpage="settings";selected=0;RenderPage();},300,120);else AddHardwareUtility(panel,"Back Up All",saves.Count+" save item(s)","⇧",accent,delegate{foreach(string value in saves)BackupNativeSavePath(value,definition.Id+"-"+Path.GetFileNameWithoutExtension(value));},300,120);}
        private void RenderWave3Settings(){Color accent=GetWave3Accent();titleText.Text=definition.DisplayName+" System";subtitleText.Text=definition.PrimaryBackend+"  •  native emulator integration";columns=3;WrapPanel panel=new WrapPanel{Margin=new Thickness(45,20,45,24)};contentHost.Children.Add(new ScrollViewer{VerticalScrollBarVisibility=ScrollBarVisibility.Hidden,Content=panel});if(String.IsNullOrWhiteSpace(settings.emulatorPath)||!File.Exists(settings.emulatorPath)){AddHardwareUtility(panel,"Locate Emulator",definition.PrimaryBackend,"⌕",accent,ChoosePrimaryEmulator,300,135);AddHardwareUtility(panel,"Install Latest",definition.PrimaryBackend+" official/current supported build","↓",accent,InstallPrimaryEmulator,300,135);}else AddHardwareUtility(panel,definition.PrimaryBackend,settings.emulatorPath,"✓",accent,ChoosePrimaryEmulator,300,135);AddHardwareUtility(panel,"Full Emulator Settings","Every discovered backend setting","⚙",accent,OpenNativeBackendSettings,300,135);AddHardwareUtility(panel,"Emulator Data",DisplayPath(settings.emulatorDataPath),"▣",accent,ChooseEmulatorDataRoot,300,135);AddHardwareUtility(panel,"Game Folders",settings.gameFolders.Count+" configured","▦",accent,AddGameFolder,300,135);AddHardwareUtility(panel,"Saved Data","Native storage manager","◫",accent,delegate{dashboardSubpage="saves";selected=0;RenderPage();},300,135);AddHardwareUtility(panel,"Refresh Library",games.Count+" titles","↻",accent,delegate{RefreshLibrary(true);},300,135);}

'''
anchor='        private void RenderAtariLynxHandheld()\n'
if 'private void RenderWave3Settings()' not in text:
    if text.count(anchor)!=1:raise SystemExit('Wave3 settings/storage insertion anchor missing')
    text=text.replace(anchor,methods+anchor,1)
path.write_text(text,encoding='utf-8');print('materialized Wave 3 platform-styled settings and native save storage')
