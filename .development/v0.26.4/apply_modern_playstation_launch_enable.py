from pathlib import Path
import json,re
ROOT=Path(__file__).resolve().parents[2]
cs=ROOT/'Native'/'HuymaierConsole.ConsolePlatforms.cs'
text=cs.read_text(encoding='utf-8-sig')
anchor='            if (definition.Shell == "Atari2600" && exe.IndexOf("stella", StringComparison.OrdinalIgnoreCase) >= 0) { string overrides = BuildStellaOverrideArguments(); return (String.IsNullOrWhiteSpace(overrides) ? String.Empty : overrides + " ") + quoted; }\n'
modern='''            if (definition.Shell == "PS4")
            {
                string appRoot=Path.GetDirectoryName(gamePath); string titleId=String.Empty;
                try { string sfo=Path.Combine(appRoot ?? String.Empty,"sce_sys","param.sfo"); if(File.Exists(sfo)) titleId=ReadPspSfoString(sfo,"TITLE_ID"); } catch { }
                if(String.IsNullOrWhiteSpace(titleId) && !String.IsNullOrWhiteSpace(appRoot)) titleId=Path.GetFileName(appRoot.TrimEnd(Path.DirectorySeparatorChar,Path.AltDirectorySeparatorChar));
                string target=!String.IsNullOrWhiteSpace(titleId)?titleId:gamePath;
                StringBuilder shad=new StringBuilder(); if(settings.fullscreen) shad.Append("--fullscreen true "); shad.Append("-g ").Append(QuoteProcessArgument(target)); return shad.ToString();
            }
            if (definition.Shell == "Vita")
            {
                string appRoot=Path.GetDirectoryName(gamePath); string titleId=String.Empty;
                try { string sfo=Path.Combine(appRoot ?? String.Empty,"sce_sys","param.sfo"); if(File.Exists(sfo)) titleId=ReadPspSfoString(sfo,"TITLE_ID"); } catch { }
                if(String.IsNullOrWhiteSpace(titleId) && !String.IsNullOrWhiteSpace(appRoot)) titleId=Path.GetFileName(appRoot.TrimEnd(Path.DirectorySeparatorChar,Path.AltDirectorySeparatorChar));
                if(String.IsNullOrWhiteSpace(titleId)) return quoted;
                return (settings.fullscreen ? "-F " : String.Empty) + "-r " + QuoteProcessArgument(titleId);
            }
'''
if 'shad.Append("-g ")' not in text:
    if anchor not in text: raise SystemExit('BuildLaunchArguments insertion anchor missing')
    text=text.replace(anchor,anchor+modern,1)
cs.write_text(text,encoding='utf-8')

# Graduate PS4 and Vita as single-primary backend surfaces. The installed-content
# scanner remains authoritative; package archives are installation media only.
platforms={
 'PS4':('ps4','PlayStation 4',700,'shadPS4','shadps4','PS4 dynamic menu with installed application content area and system settings'),
 'Vita':('vita','PlayStation Vita',710,'Vita3K','vita3k','PS Vita LiveArea with installed application bubbles and Content Manager')
}
for folder,(pid,name,sort,backend,adapter,interface) in platforms.items():
    p=ROOT/'EmulatorPlatforms'/folder/'platform.json'; d=json.loads(p.read_text(encoding='utf-8-sig')); d['enabled']=True; d['version']='0.26.4-dev'; d['primaryBackend']=backend; d['adapter']=adapter; d['fallbackBackend']=''; d.pop('fallbackAdapter',None); d['directoryGameDetection']=['sce_sys/param.sfo','eboot.bin']; p.write_text(json.dumps(d,indent=2)+'\n',encoding='utf-8')
regp=ROOT/'EmulatorPlatforms'/'platform-registry.json'; reg=json.loads(regp.read_text(encoding='utf-8-sig')); items=list(reg.get('platforms',[])); by={str(x.get('id','')).lower():x for x in items}
basecaps=['library','cached-library','direct-launch','launch-return','controller-navigation','cover-art','compiled-native-host','in-process-platform-view','huymaier-native-path-picker','latest-emulator-install','emulator-first-cover-art','native-full-emulator-settings','unknown-setting-preservation','native-save-management','installed-application-library']
for folder,(pid,name,sort,backend,adapter,interface) in platforms.items():
    caps=basecaps+(['ps4-dynamic-menu','shadps4-title-id-launch'] if pid=='ps4' else ['vita-livearea','vita3k-installed-title-launch','content-manager'])
    entry={'id':pid,'name':name,'kind':'native-platform-view','enabled':True,'sortOrder':sort,'backend':backend,'interface':interface,'displayName':name,'menuName':name.replace('PlayStation ',''),'aliases':[name,folder,backend],'version':'0.26.4-dev','nativeType':'HuymaierConsole.NativeApp.ConsolePlatformWindow','capabilities':caps}
    if pid in by: by[pid].clear();by[pid].update(entry)
    else: items.append(entry);by[pid]=entry
reg['platforms']=sorted(items,key=lambda x:int(x.get('sortOrder',1000)));regp.write_text(json.dumps(reg,indent=2)+'\n',encoding='utf-8')
manifest=ROOT/'manifest.json';m=json.loads(manifest.read_text(encoding='utf-8-sig'));m['build']='platform-expansion-modern-playstation';features=list(m.get('features',[]));f='enables PS4/shadPS4 and PS Vita/Vita3K native installed-application surfaces using upstream-documented direct-launch contracts and native full backend settings';
if f not in features:features.append(f)
m['features']=features;manifest.write_text(json.dumps(m,indent=2)+'\n',encoding='utf-8')
print('materialized upstream-grounded PS4/Vita installed-title launch semantics and graduation')
