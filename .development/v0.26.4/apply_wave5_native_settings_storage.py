from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[2]
path=ROOT/'Native'/'HuymaierConsole.ConsolePlatforms.cs'
text=path.read_text(encoding='utf-8-sig')

def method_span(source, signature):
    start=source.find(signature)
    if start < 0:return None
    brace=source.find('{',start)
    if brace < 0:return None
    depth=0;in_string=False;verbatim=False;escape=False;i=brace
    while i < len(source):
        ch=source[i]
        if in_string:
            if verbatim:
                if ch=='"':
                    if i+1 < len(source) and source[i+1]=='"':i+=2;continue
                    in_string=False;verbatim=False
            else:
                if escape:escape=False
                elif ch=='\\':escape=True
                elif ch=='"':in_string=False
        else:
            if ch=='"':
                in_string=True;verbatim=(i>0 and source[i-1]=='@')
            elif ch=='{':depth+=1
            elif ch=='}':
                depth-=1
                if depth==0:return (start,i+1)
        i+=1
    return None

# Route PS4/Vita settings and storage inside the current Wave4/5 subpage method.
# This deliberately does not depend on the exact one-line body used by an older
# materializer, so adding Arcade/operator cases cannot invalidate the patch.
if 'private void RenderModernPlayStationSettings()' not in text:
    span=method_span(text,'private void RenderWave45Subpage()')
    if span is None:raise SystemExit('RenderWave45Subpage method is missing; materialize Wave4/5 stage first')
    start,end=span;block=text[start:end]
    settings_route='if((definition.Shell=="PS4"||definition.Shell=="Vita")&&dashboardSubpage=="settings"){RenderModernPlayStationSettings();return;}'
    saves_route='if((definition.Shell=="PS4"||definition.Shell=="Vita")&&dashboardSubpage=="saves"){RenderModernPlayStationStorage();return;}'
    if settings_route not in block:
        match=re.search(r'if\s*\(\s*dashboardSubpage\s*==\s*"settings"\s*\)\s*\{\s*RenderWave1Settings\s*\(\s*\)\s*;\s*return\s*;\s*\}',block)
        if not match:raise SystemExit('Generic Wave4/5 settings fallback was not found')
        block=block[:match.start()]+settings_route+block[match.start():]
    if saves_route not in block:
        match=re.search(r'if\s*\(\s*dashboardSubpage\s*==\s*"saves"\s*\)\s*\{\s*RenderWave1Storage\s*\(\s*\)\s*;\s*return\s*;\s*\}',block)
        if not match:raise SystemExit('Generic Wave4/5 storage fallback was not found')
        block=block[:match.start()]+saves_route+block[match.start():]
    text=text[:start]+block+text[end:]

methods=r'''
        private Color GetModernPlayStationAccent(){return definition.Shell=="PS4"?Color.FromRgb(75,173,255):Color.FromRgb(115,222,255);}
        private List<string> GetModernPlayStationSaveRoots()
        {
            List<string> roots=new List<string>();
            Action<string> add=delegate(string value){if(String.IsNullOrWhiteSpace(value))return;try{if(File.Exists(value))value=Path.GetDirectoryName(value);if(Directory.Exists(value)&&!roots.Contains(value,StringComparer.OrdinalIgnoreCase))roots.Add(value);}catch{}};
            add(settings.emulatorDataPath);
            string exeRoot=!String.IsNullOrWhiteSpace(settings.emulatorPath)&&File.Exists(settings.emulatorPath)?Path.GetDirectoryName(settings.emulatorPath):String.Empty;add(exeRoot);
            foreach(string root in roots.ToArray())
            {
                try
                {
                    if(definition.Shell=="Vita")
                    {
                        add(Path.Combine(root,"ux0","user","00","savedata"));
                        add(Path.Combine(root,"Vita3K","ux0","user","00","savedata"));
                    }
                    else
                    {
                        add(Path.Combine(root,"user","savedata"));
                        add(Path.Combine(root,"savedata"));
                        add(Path.Combine(root,"user","home"));
                        add(Path.Combine(root,"save"));
                    }
                }catch{}
            }
            return roots;
        }
        private List<string> FindModernPlayStationSaveItems()
        {
            HashSet<string> items=new HashSet<string>(StringComparer.OrdinalIgnoreCase);int visited=0;
            foreach(string root in GetModernPlayStationSaveRoots())
            {
                if(!Directory.Exists(root))continue;
                try{foreach(string dir in Directory.GetDirectories(root)){if(++visited>4000)break;items.Add(dir);}}catch{}
                if(visited>4000)break;
            }
            return items.OrderBy(delegate(string value){return Path.GetFileName(value);},StringComparer.CurrentCultureIgnoreCase).ToList();
        }
        private void RenderModernPlayStationStorage()
        {
            Color accent=GetModernPlayStationAccent();bool vita=definition.Shell=="Vita";
            titleText.Text=vita?"Content Manager":"Saved Data Management";
            subtitleText.Text=vita?"PS Vita saved data inside the Vita3K user environment":"PS4 saved data inside the shadPS4 user environment";
            columns=3;WrapPanel panel=new WrapPanel{Margin=new Thickness(42,10,42,24)};
            contentHost.Children.Add(new ScrollViewer{VerticalScrollBarVisibility=ScrollBarVisibility.Hidden,Content=panel});
            List<string> items=FindModernPlayStationSaveItems();
            foreach(string value in items.Take(500))
            {
                string captured=value;string title=Path.GetFileName(value);string sfo=Path.Combine(value,"param.sfo");
                if(File.Exists(sfo)){string parsed=ReadPspSfoString(sfo,"TITLE");if(!String.IsNullOrWhiteSpace(parsed))title=parsed;}
                AddHardwareUtility(panel,title,FormatBytes(GetPathSize(value))+"  •  "+Path.GetFileName(value),vita?"◉":"▣",accent,delegate{BackupNativeSavePath(captured,definition.Id+"-"+Path.GetFileName(captured));},300,130);
            }
            if(items.Count==0)AddHardwareUtility(panel,"No Saved Data","No emulator save directories have been detected yet.",vita?"◉":"▣",accent,delegate{dashboardSubpage="settings";selected=0;RenderPage();},300,130);
            else AddHardwareUtility(panel,"Back Up All",items.Count+" save item(s)","⇧",accent,delegate{foreach(string value in items)BackupNativeSavePath(value,definition.Id+"-"+Path.GetFileName(value));},300,130);
        }
        private void RenderModernPlayStationSettings()
        {
            Color accent=GetModernPlayStationAccent();bool vita=definition.Shell=="Vita";
            titleText.Text="Settings";subtitleText.Text=definition.PrimaryBackend+"  •  Huymaier native system integration";columns=3;
            Grid body=new Grid{Margin=new Thickness(45,6,45,24)};body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(vita?95:74)});body.RowDefinitions.Add(new RowDefinition{Height=new GridLength(1,GridUnitType.Star)});contentHost.Children.Add(body);
            Border header=new Border{CornerRadius=new CornerRadius(vita?38:4),Background=new LinearGradientBrush(Color.FromArgb(220,accent.R,accent.G,accent.B),Color.FromArgb(150,13,66,135),0),BorderBrush=new SolidColorBrush(Color.FromArgb(210,255,255,255)),BorderThickness=new Thickness(2),Padding=new Thickness(20),Child=new TextBlock{Text=vita?"LIVEAREA SYSTEM SETTINGS":"PS4 SYSTEM SETTINGS",FontSize=20,FontWeight=FontWeights.SemiBold,Foreground=Brushes.White,HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center}};body.Children.Add(header);
            WrapPanel panel=new WrapPanel{Margin=new Thickness(0,12,0,0)};ScrollViewer scroll=new ScrollViewer{VerticalScrollBarVisibility=ScrollBarVisibility.Hidden,Content=panel};Grid.SetRow(scroll,1);body.Children.Add(scroll);
            if(String.IsNullOrWhiteSpace(settings.emulatorPath)||!File.Exists(settings.emulatorPath))
            {
                AddHardwareUtility(panel,"Locate Emulator",definition.PrimaryBackend,"⌕",accent,ChoosePrimaryEmulator,300,132);
                AddHardwareUtility(panel,"Install Latest",definition.PrimaryBackend+" current supported build","↓",accent,InstallPrimaryEmulator,300,132);
            }
            else AddHardwareUtility(panel,definition.PrimaryBackend,settings.emulatorPath,"✓",accent,ChoosePrimaryEmulator,300,132);
            AddHardwareUtility(panel,"Full Emulator Settings","Every discovered backend setting","⚙",accent,OpenNativeBackendSettings,300,132);
            AddHardwareUtility(panel,"Emulator Data",DisplayPath(settings.emulatorDataPath),"▣",accent,ChooseEmulatorDataRoot,300,132);
            AddHardwareUtility(panel,"Application Folders",settings.gameFolders.Count+" configured","▦",accent,AddGameFolder,300,132);
            AddHardwareUtility(panel,vita?"Content Manager":"Saved Data Management","Native save storage","◫",accent,delegate{dashboardSubpage="saves";selected=0;RenderPage();},300,132);
            AddHardwareUtility(panel,"Refresh Installed Apps",games.Count+" installed applications","↻",accent,delegate{RefreshLibrary(true);},300,132);
        }

'''
if 'private void RenderModernPlayStationSettings()' not in text:
    match=re.search(r'(?m)^\s*private\s+void\s+RenderPs4DynamicMenu\s*\(\s*\)',text)
    if not match:raise SystemExit('RenderPs4DynamicMenu method is missing; materialize Wave4/5 stage first')
    text=text[:match.start()]+methods+text[match.start():]
path.write_text(text,encoding='utf-8')
print('materialized PS4 Dynamic Menu and Vita LiveArea native settings/storage subpages')
