from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
cs=ROOT/'Native'/'HuymaierConsole.ConsolePlatforms.cs'
text=cs.read_text(encoding='utf-8-sig')

# Modern PlayStation emulators install/extract applications. Package files are
# install media, not normal direct-launch library entries.
anchor='        private void RefreshLibrary(bool showNotice)\n        {\n'
if 'RefreshModernPlayStationLibrary(showNotice)' not in text:
    if text.count(anchor)!=1: raise SystemExit(f'RefreshLibrary anchor expected one match, found {text.count(anchor)}')
    text=text.replace(anchor,anchor+'            if (definition.Shell == "PS4" || definition.Shell == "Vita") { RefreshModernPlayStationLibrary(showNotice); return; }\n',1)

methods=r'''
        private List<string> GetModernPlayStationContentRoots()
        {
            List<string> roots=new List<string>();
            Action<string> add=delegate(string value){if(String.IsNullOrWhiteSpace(value))return;try{if(File.Exists(value))value=Path.GetDirectoryName(value);if(Directory.Exists(value)&&!roots.Contains(value,StringComparer.OrdinalIgnoreCase))roots.Add(value);}catch{}};
            foreach(string folder in settings.gameFolders) add(folder); add(settings.emulatorDataPath);
            string exeRoot=!String.IsNullOrWhiteSpace(settings.emulatorPath)&&File.Exists(settings.emulatorPath)?Path.GetDirectoryName(settings.emulatorPath):String.Empty; add(exeRoot);
            if(definition.Shell=="Vita")
            {
                foreach(string root in roots.ToArray()) { try { add(Path.Combine(root,"ux0","app")); add(Path.Combine(root,"Vita3K","ux0","app")); } catch{} }
                string app=Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData); string local=Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
                add(Path.Combine(app,"Vita3K","Vita3K","ux0","app")); add(Path.Combine(app,"Vita3K","ux0","app")); add(Path.Combine(local,"Vita3K","ux0","app"));
            }
            return roots;
        }

        private ConsolePlatformGame CreateModernPlayStationGame(string ebootPath)
        {
            try
            {
                string appRoot=Path.GetDirectoryName(ebootPath); if(String.IsNullOrWhiteSpace(appRoot))return null;
                string sfo=Path.Combine(appRoot,"sce_sys","param.sfo"); if(!File.Exists(sfo))return null;
                string title=ReadPspSfoString(sfo,"TITLE"); string titleId=ReadPspSfoString(sfo,"TITLE_ID");
                if(String.IsNullOrWhiteSpace(titleId)) titleId=ReadPspSfoString(sfo,"TITLEID");
                if(String.IsNullOrWhiteSpace(title)) title=!String.IsNullOrWhiteSpace(titleId)?titleId:Path.GetFileName(appRoot);
                string icon=Path.Combine(appRoot,"sce_sys","icon0.png"); if(!File.Exists(icon)) icon=Path.Combine(appRoot,"sce_sys","icon0.PNG");
                string cover=File.Exists(icon)?icon:FindCover(ebootPath);
                ConsolePlatformGame game=new ConsolePlatformGame { Name=title, Path=ebootPath, Cover=cover };
                try
                {
                    System.Reflection.PropertyInfo idProperty=game.GetType().GetProperty("TitleId"); if(idProperty!=null&&idProperty.CanWrite)idProperty.SetValue(game,titleId,null);
                    System.Reflection.PropertyInfo rootProperty=game.GetType().GetProperty("ContentRoot"); if(rootProperty!=null&&rootProperty.CanWrite)rootProperty.SetValue(game,appRoot,null);
                }catch{}
                return game;
            }catch{return null;}
        }

        private void RefreshModernPlayStationLibrary(bool showNotice)
        {
            List<ConsolePlatformGame> found=new List<ConsolePlatformGame>(); HashSet<string> seen=new HashSet<string>(StringComparer.OrdinalIgnoreCase); int visited=0;
            foreach(string rootPath in GetModernPlayStationContentRoots())
            {
                if(!Directory.Exists(rootPath))continue;
                try
                {
                    if(definition.Shell=="Vita" && String.Equals(Path.GetFileName(rootPath.TrimEnd(Path.DirectorySeparatorChar)),"app",StringComparison.OrdinalIgnoreCase))
                    {
                        foreach(string appRoot in Directory.GetDirectories(rootPath))
                        {
                            string eboot=Path.Combine(appRoot,"eboot.bin"); if(!File.Exists(eboot)||!seen.Add(eboot))continue; ConsolePlatformGame game=CreateModernPlayStationGame(eboot); if(game!=null)found.Add(game);
                        }
                        continue;
                    }
                    foreach(string eboot in Directory.EnumerateFiles(rootPath,"eboot.bin",SearchOption.AllDirectories))
                    {
                        if(++visited>12000)break; if(!seen.Add(eboot))continue; ConsolePlatformGame game=CreateModernPlayStationGame(eboot); if(game!=null)found.Add(game);
                    }
                }catch{}
                if(visited>12000)break;
            }
            games=found.GroupBy(delegate(ConsolePlatformGame game){return game.Path;},StringComparer.OrdinalIgnoreCase).Select(delegate(IGrouping<string,ConsolePlatformGame> group){return group.First();}).OrderBy(delegate(ConsolePlatformGame game){return game.Name;},StringComparer.CurrentCultureIgnoreCase).ToList();
            selected=0;SaveCachedGames();if(showNotice)ShowNotice("Installed library refreshed — "+games.Count.ToString(CultureInfo.InvariantCulture)+" applications");RenderPage();QueueConsoleArtworkRefresh();
        }

'''
if 'private void RefreshModernPlayStationLibrary(bool showNotice)' not in text:
    insert='        private static string CleanName(string value)\n'
    if text.count(insert)!=1: raise SystemExit('Modern PlayStation library methods insertion anchor missing')
    text=text.replace(insert,methods+insert,1)

# Extend cache shape without requiring old cache migration; JavaScriptSerializer
# ignores absent fields in existing caches.
if 'public string TitleId { get; set; }' not in text:
    candidate='        public string Cover { get; set; }\n'
    if text.count(candidate)==1:
        text=text.replace(candidate,candidate+'        public string TitleId { get; set; }\n        public string ContentRoot { get; set; }\n',1)

cs.write_text(text,encoding='utf-8')

worker=ROOT/'HuymaierNativeConsoleLibraryWorker.ps1'
w=worker.read_text(encoding='utf-8-sig')
# Replace preliminary package-extension counting with installed application roots.
marker='$extensions=@(Get-Extensions $PlatformId)\n$seen=@{}\n$filesVisited=0\n'
if 'function Count-ModernInstalledApplications' not in w:
    helper=r'''
function Count-ModernInstalledApplications([string]$Id,[System.Collections.ArrayList]$Roots){
    $seen=@{};$visited=0
    foreach($root in @($Roots)){
        $candidates=New-Object System.Collections.ArrayList
        [void]$candidates.Add($root)
        if($Id -eq 'VITA'){
            foreach($candidate in @((Join-Path $root 'ux0\app'),(Join-Path $root 'Vita3K\ux0\app'))){if(Test-Path -LiteralPath $candidate -PathType Container){[void]$candidates.Add($candidate)}}
        }
        foreach($base in @($candidates)){
            if(-not(Test-Path -LiteralPath $base -PathType Container)){continue}
            try{
                foreach($eboot in Get-ChildItem -LiteralPath $base -Filter 'eboot.bin' -File -Recurse -ErrorAction SilentlyContinue){
                    if(++$visited -gt 12000){break};$appRoot=$eboot.Directory.FullName;$sfo=Join-Path $appRoot 'sce_sys\param.sfo';if(-not(Test-Path -LiteralPath $sfo -PathType Leaf)){continue};$seen[$eboot.FullName.ToLowerInvariant()]=$true
                }
            }catch{}
            if($visited -gt 12000){break}
        }
        if($visited -gt 12000){break}
    }
    return [pscustomobject]@{Count=$seen.Count;Visited=$visited}
}

'''
    insertion='function Get-Extensions([string]$Id){\n'
    if w.count(insertion)!=1: raise SystemExit('Modern count helper insertion anchor missing')
    w=w.replace(insertion,helper+insertion,1)
if marker in w and "if($PlatformId.ToUpperInvariant() -in @('PS4','VITA'))" not in w:
    replacement=marker+"if($PlatformId.ToUpperInvariant() -in @('PS4','VITA')){\n    $modern=Count-ModernInstalledApplications $PlatformId $roots\n    $result=[ordered]@{Platform=$PlatformId.ToUpperInvariant();Count=[int]$modern.Count;UpdatedAt=(Get-Date).ToString('o');Error='';Roots=@($roots);FilesVisited=[int]$modern.Visited}\n    $dir=Split-Path -Parent $ResultPath;if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null};$result|ConvertTo-Json -Depth 5|Set-Content -LiteralPath $ResultPath -Encoding UTF8;exit 0\n}\n"
    w=w.replace(marker,replacement,1)
worker.write_text(w,encoding='utf-8')
print('materialized PS4/Vita installed-application library model')
