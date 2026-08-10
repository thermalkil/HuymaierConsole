from pathlib import Path
import json,re
ROOT=Path(__file__).resolve().parents[2]
platforms={
 'AtariLynx':('atarilynx','Atari Lynx',520,'Mednafen','mednafen','Atari Lynx handheld interface'),
 'NeoGeo':('neogeo','Neo Geo',530,'FinalBurn Neo','fbneo','Neo Geo AES/MVS cartridge-system interface'),
 'NGPC':('ngpc','Neo Geo Pocket Color',540,'Mednafen','mednafen','Neo Geo Pocket Color handheld interface'),
 'PrimeHack':('primehack','Metroid PrimeHack',550,'PrimeHack','primehack','Prime-series visor HUD interface for PrimeHack')
}
for folder,(pid,display,sort,backend,adapter,interface) in platforms.items():
 p=ROOT/'EmulatorPlatforms'/folder/'platform.json';d=json.loads(p.read_text(encoding='utf-8-sig'));d['enabled']=True;d['version']='0.26.4-dev';d['primaryBackend']=backend;d['adapter']=adapter;d['fallbackBackend']='';d.pop('fallbackAdapter',None);p.write_text(json.dumps(d,indent=2)+'\n',encoding='utf-8')
# Avoid exposing unaudited optional fallback backends in C# for graduated Wave3.
cs=ROOT/'Native'/'HuymaierConsole.ConsolePlatforms.cs';c=cs.read_text(encoding='utf-8-sig')
for shell in ('ATARILYNX','NEOGEO','NGPC','PRIMEHACK'):
 pattern=r'(else if \(key == "'+shell+r'"\)\s*\{.*?d\.PrimaryBackend="[^"]*";)d\.FallbackBackend="[^"]*";(d\.PrimaryExecutableNames=new string\[\]\{[^}]*\};)d\.FallbackExecutableNames=new string\[\]\{[^}]*\};'
 c,count=re.subn(pattern,r'\1d.FallbackBackend=String.Empty;\2d.FallbackExecutableNames=new string[0];',c,count=1,flags=re.S)
 if count!=1:raise SystemExit(f'Could not remove unaudited fallback from {shell}')
cs.write_text(c,encoding='utf-8')
regp=ROOT/'EmulatorPlatforms'/'platform-registry.json';reg=json.loads(regp.read_text(encoding='utf-8-sig'));items=list(reg.get('platforms',[]));by={str(x.get('id','')).lower():x for x in items};caps=['library','cached-library','direct-launch','launch-return','controller-navigation','cover-art','compiled-native-host','in-process-platform-view','huymaier-native-path-picker','latest-emulator-install','emulator-first-cover-art','native-full-emulator-settings','unknown-setting-preservation','native-save-management','alphabet-index']
for folder,(pid,display,sort,backend,adapter,interface) in platforms.items():
 entry={'id':pid,'name':display,'kind':'native-platform-view','enabled':True,'sortOrder':sort,'backend':backend,'interface':interface,'displayName':display,'menuName':display,'aliases':[display,folder,backend],'version':'0.26.4-dev','nativeType':'HuymaierConsole.NativeApp.ConsolePlatformWindow','capabilities':caps[:]}
 if pid=='neogeo':entry['capabilities']+=['memory-card-management','operator-settings']
 if pid=='primehack':entry['capabilities']+=['prime-visor-interface','primehack-controller-settings']
 if pid in by:by[pid].clear();by[pid].update(entry)
 else:items.append(entry);by[pid]=entry
reg['platforms']=sorted(items,key=lambda x:int(x.get('sortOrder',1000)));regp.write_text(json.dumps(reg,indent=2)+'\n',encoding='utf-8')
# Jaguar deliberately remains disabled.
jag=ROOT/'EmulatorPlatforms'/'Jaguar'/'platform.json'
if jag.exists():d=json.loads(jag.read_text(encoding='utf-8-sig'));d['enabled']=False;jag.write_text(json.dumps(d,indent=2)+'\n',encoding='utf-8')
manifest=ROOT/'manifest.json';m=json.loads(manifest.read_text(encoding='utf-8-sig'));m['build']='platform-expansion-wave3-partial';f=list(m.get('features',[]));feature='enables Atari Lynx, Neo Geo, Neo Geo Pocket Color and PrimeHack native expansion surfaces while keeping Jaguar staged pending a complete BigPEmu settings adapter';
if feature not in f:f.append(feature)
m['features']=f;manifest.write_text(json.dumps(m,indent=2)+'\n',encoding='utf-8')
validator=ROOT/'.github'/'workflows'/'validate-v0264-expansion.yml'
if validator.exists():
 v=validator.read_text(encoding='utf-8-sig')
 for folder in platforms:v=v.replace("'"+folder+"',",'').replace(",\'"+folder+"\'",'')
 validator.write_text(v,encoding='utf-8')
print('graduated Wave3 Lynx/NeoGeo/NGPC/PrimeHack; Jaguar remains staged')
