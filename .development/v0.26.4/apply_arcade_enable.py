from pathlib import Path
import json,re
ROOT=Path(__file__).resolve().parents[2]
platforms={
 'Arcade':('arcade','Arcade',600,'MAME','mame','native arcade cabinet/software wall with operator/service configuration'),
 'FinalBurnNeo':('finalburnneo','FinalBurn Neo',610,'FinalBurn Neo','fbneo','FBNeo arcade cabinet and operator interface'),
 'NeoGeo':('neogeo','Neo Geo',530,'FinalBurn Neo','fbneo','Neo Geo AES/MVS cartridge-system interface with memory-card/operator storage')
}
for folder,(pid,name,sort,backend,adapter,interface) in platforms.items():
    p=ROOT/'EmulatorPlatforms'/folder/'platform.json';d=json.loads(p.read_text(encoding='utf-8-sig'));d['enabled']=True;d['version']='0.26.4-dev';d['primaryBackend']=backend;d['adapter']=adapter;d['fallbackBackend']='';d.pop('fallbackAdapter',None);p.write_text(json.dumps(d,indent=2)+'\n',encoding='utf-8')
regp=ROOT/'EmulatorPlatforms'/'platform-registry.json';reg=json.loads(regp.read_text(encoding='utf-8-sig'));items=list(reg.get('platforms',[]));by={str(x.get('id','')).lower():x for x in items}
common=['library','cached-library','direct-launch','launch-return','controller-navigation','cover-art','compiled-native-host','in-process-platform-view','huymaier-native-path-picker','latest-emulator-install','emulator-first-cover-art','native-full-emulator-settings','unknown-setting-preservation','native-save-management','alphabet-index','operator-settings']
for folder,(pid,name,sort,backend,adapter,interface) in platforms.items():
    caps=common[:]
    if pid=='arcade':caps+=['mame-driver-launch','mame-showconfig-settings','rompath-launch-registration','nvram-management','high-score-storage']
    else:caps+=['fbneo-driver-launch','fbneo-native-rom-path-registration','fbneo-key-value-settings','fbneo-default-config-bootstrap']
    if pid=='neogeo':caps+=['memory-card-management','aes-mvs-presentation']
    entry={'id':pid,'name':name,'kind':'native-platform-view','enabled':True,'sortOrder':sort,'backend':backend,'interface':interface,'displayName':name,'menuName':name,'aliases':[name,folder,backend],'version':'0.26.4-dev','nativeType':'HuymaierConsole.NativeApp.ConsolePlatformWindow','capabilities':caps}
    if pid in by:by[pid].clear();by[pid].update(entry)
    else:items.append(entry);by[pid]=entry
reg['platforms']=sorted(items,key=lambda x:int(x.get('sortOrder',1000)));regp.write_text(json.dumps(reg,indent=2)+'\n',encoding='utf-8')
manifest=ROOT/'manifest.json';m=json.loads(manifest.read_text(encoding='utf-8-sig'));m['build']='platform-expansion-arcade';features=list(m.get('features',[]));f='enables native Arcade/MAME, FinalBurn Neo and Neo Geo surfaces with driver-name launch, native ROM-path registration, operator settings and storage management';
if f not in features:features.append(f)
m['features']=features;manifest.write_text(json.dumps(m,indent=2)+'\n',encoding='utf-8')
print('graduated Arcade/MAME, FinalBurn Neo and Neo Geo with proven primary backend contracts')
