from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
core=ROOT/'HuymaierEmulatorSettings.ps1';c=core.read_text(encoding='utf-8-sig')
marker="        if($AdapterId -ieq 'bigpemu' -and $ext -ieq '.bigpcfg'){$Format='json'}"
insert="        if($AdapterId -ieq 'fbneo'){$Format='key-value'}\n"
if insert.strip() not in c:
    if marker not in c:
        marker="        if($AdapterId -ieq 'mednafen'){$Format='key-value'}"
    if marker not in c:raise SystemExit('FBNeo format insertion anchor missing')
    c=c.replace(marker,insert+marker,1)
core.write_text(c,encoding='utf-8-sig')

worker=ROOT/'HuymaierEmulatorSettingsWorker.ps1';w=worker.read_text(encoding='utf-8-sig')
old="            'fbneo' {foreach($rel in @('config\\fbneo.ini','config\\fbneo.cfg','fbneo.ini','fbneo.cfg')){Add-File (Join-Path $root $rel)};try{Get-ChildItem -LiteralPath (Join-Path $root 'config') -File -ErrorAction SilentlyContinue|Where-Object{$_.Extension -match '(?i)^\\.(ini|cfg)$'}|Select-Object -First 80|ForEach-Object{Add-File $_.FullName}}catch{}}"
new="            'fbneo' {foreach($rel in @('config\\fbneo.ini','config\\fbneo64.ini','config\\FinalBurnNeo.ini','config\\FinalBurnNeo64.ini','config\\fbneo.cfg','fbneo.ini','fbneo64.ini','fbneo.cfg')){Add-File (Join-Path $root $rel)};try{Get-ChildItem -LiteralPath (Join-Path $root 'config') -File -ErrorAction SilentlyContinue|Where-Object{$_.Extension -match '(?i)^\\.(ini|cfg)$'}|Select-Object -First 120|ForEach-Object{Add-File $_.FullName}}catch{}}"
if old in w:w=w.replace(old,new,1)
elif new not in w:raise SystemExit('FBNeo config discovery anchor missing')
worker.write_text(w,encoding='utf-8-sig')

cs=ROOT/'Native'/'HuymaierConsole.ConsolePlatforms.cs';text=cs.read_text(encoding='utf-8-sig')
# Ensure user ROM directory exists in FBNeo's own config before command-line driver launch.
helper=r'''
        private void EnsureFbNeoRomPath(string executable, string romDirectory)
        {
            if(String.IsNullOrWhiteSpace(executable)||String.IsNullOrWhiteSpace(romDirectory)||!Directory.Exists(romDirectory))return;
            try
            {
                string root=Path.GetDirectoryName(executable);string configDir=Path.Combine(root,"config");Directory.CreateDirectory(configDir);string configPath=Path.Combine(configDir,Path.GetFileNameWithoutExtension(executable)+".ini");
                if(!File.Exists(configPath))
                {
                    try
                    {
                        ProcessStartInfo init=new ProcessStartInfo(executable,"-listinfo");init.WorkingDirectory=root;init.UseShellExecute=false;init.CreateNoWindow=true;using(Process p=Process.Start(init)){if(p!=null&&!p.WaitForExit(12000)){try{p.Kill();}catch{}}}
                    }catch(Exception initEx){WritePlatformLog("FBNeo default-config initialization recovered: "+initEx.Message,"WARN");}
                }
                List<string> lines=File.Exists(configPath)?File.ReadAllLines(configPath,Encoding.UTF8).ToList():new List<string>();string normalized=romDirectory.TrimEnd('\\','/')+Path.DirectorySeparatorChar;int match=-1;for(int i=0;i<lines.Count;i++){if(lines[i].TrimStart().StartsWith("szAppRomPaths[0] ",StringComparison.OrdinalIgnoreCase)){match=i;break;}}
                string row="szAppRomPaths[0] "+normalized;if(match>=0){if(String.Equals(lines[match],row,StringComparison.Ordinal))return;lines[match]=row;}else lines.Add(row);
                if(File.Exists(configPath)){string backup=configPath+".huymaier-"+DateTime.UtcNow.ToString("yyyyMMddHHmmss",CultureInfo.InvariantCulture)+".bak";try{File.Copy(configPath,backup,false);}catch{}}
                File.WriteAllLines(configPath,lines.ToArray(),new UTF8Encoding(false));
            }
            catch(Exception ex){WritePlatformLog("Could not register FBNeo ROM path: "+ex.Message,"WARN");}
        }

'''
if 'private void EnsureFbNeoRomPath(' not in text:
    anchor='        private string BuildLaunchArguments(string executable, string gamePath)\n'
    if text.count(anchor)!=1:raise SystemExit('FBNeo launch helper insertion anchor missing')
    text=text.replace(anchor,helper+anchor,1)
# Direct FBNeo launch uses driver name; source ProcessCmdLine matches BurnDrv DRV_NAME, not archive path.
needle='            if (definition.Shell == "Arcade" && exe.IndexOf("mame", StringComparison.OrdinalIgnoreCase) >= 0) { string driver=Path.GetFileNameWithoutExtension(gamePath); string romDir=Path.GetDirectoryName(gamePath); string overrides=BuildMameOverrideArguments(); StringBuilder mame=new StringBuilder(); if(!String.IsNullOrWhiteSpace(overrides))mame.Append(overrides).Append(\' \'); if(!String.IsNullOrWhiteSpace(romDir))mame.Append("-rompath ").Append(QuoteProcessArgument(romDir)).Append(\' \'); mame.Append(driver); return mame.ToString(); }\n'
fb='            if ((definition.Shell == "FinalBurnNeo" || definition.Shell == "NeoGeo" || definition.Shell == "Arcade") && exe.IndexOf("fbneo", StringComparison.OrdinalIgnoreCase) >= 0) { string driver=Path.GetFileNameWithoutExtension(gamePath); string romDir=Path.GetDirectoryName(gamePath); EnsureFbNeoRomPath(executable,romDir); return driver; }\n'
if fb.strip() not in text:
    if needle not in text:raise SystemExit('MAME launch anchor missing for FBNeo direct-launch integration')
    text=text.replace(needle,needle+fb,1)
cs.write_text(text,encoding='utf-8')
print('materialized FBNeo key/value full settings, default config bootstrap, ROM-path registration and driver-name launch')
