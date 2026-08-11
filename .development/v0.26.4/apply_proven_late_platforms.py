from pathlib import Path
import json

ROOT=Path(__file__).resolve().parents[2]

# Arcade graduates only with MAME. FBNeo/Neo Geo and Jaguar remain staged until
# their backend-specific first-run/full-settings requirements can be proven.
arcade_path=ROOT/'EmulatorPlatforms'/'Arcade'/'platform.json'
arcade=json.loads(arcade_path.read_text(encoding='utf-8-sig'))
arcade['enabled']=True
arcade['version']='0.26.4-dev'
arcade['primaryBackend']='MAME'
arcade['adapter']='mame'
arcade['fallbackBackend']=''
arcade.pop('fallbackAdapter',None)
arcade_path.write_text(json.dumps(arcade,indent=2)+'\n',encoding='utf-8')

for folder in ('FinalBurnNeo','NeoGeo','Jaguar'):
    p=ROOT/'EmulatorPlatforms'/folder/'platform.json'
    d=json.loads(p.read_text(encoding='utf-8-sig'))
    d['enabled']=False
    d['version']='0.26.4-dev'
    p.write_text(json.dumps(d,indent=2)+'\n',encoding='utf-8')

reg_path=ROOT/'EmulatorPlatforms'/'platform-registry.json'
reg=json.loads(reg_path.read_text(encoding='utf-8-sig'))
items=list(reg.get('platforms',[]))
by={str(x.get('id','')).lower():x for x in items}
arc=by.get('arcade')
if arc is None:
    arc={'id':'arcade'};items.append(arc);by['arcade']=arc
arc.clear();arc.update({
    'id':'arcade','name':'Arcade','kind':'native-platform-view','enabled':True,
    'sortOrder':600,'backend':'MAME',
    'interface':'native arcade cabinet/software wall with operator/service configuration',
    'displayName':'Arcade','menuName':'Arcade','aliases':['Arcade','MAME'],
    'version':'0.26.4-dev','nativeType':'HuymaierConsole.NativeApp.ConsolePlatformWindow',
    'capabilities':['library','cached-library','direct-launch','launch-return','controller-navigation','cover-art','compiled-native-host','in-process-platform-view','huymaier-native-path-picker','latest-emulator-install','emulator-first-cover-art','native-full-emulator-settings','unknown-setting-preservation','native-save-management','alphabet-index','operator-settings','mame-driver-launch','mame-showconfig-settings','rompath-launch-registration','nvram-management','high-score-storage']
})
for pid in ('finalburnneo','neogeo','jaguar'):
    if pid in by: by[pid]['enabled']=False
reg['platforms']=sorted(items,key=lambda x:int(x.get('sortOrder',1000)))
reg_path.write_text(json.dumps(reg,indent=2)+'\n',encoding='utf-8')

manifest_path=ROOT/'manifest.json'
m=json.loads(manifest_path.read_text(encoding='utf-8-sig'))
m['build']='platform-expansion-proven-late'
features=list(m.get('features',[]))
feature='graduates PS4/shadPS4, PS Vita/Vita3K and Arcade/MAME after live x64 backend and runtime-contract validation while keeping FinalBurn Neo, Neo Geo and Jaguar staged'
if feature not in features: features.append(feature)
m['features']=features
m['description']='v0.26.4 development expands the native console/platform library with validated Wave 1-3 systems plus proven PS4, PS Vita and MAME Arcade support; FBNeo/Neo Geo and Jaguar remain staged pending backend-specific first-run settings readiness.'
manifest_path.write_text(json.dumps(m,indent=2)+'\n',encoding='utf-8')
print('graduated proven late platforms: PS4/Vita are handled by their upstream-grounded materializer; Arcade is MAME-only; FBNeo/NeoGeo/Jaguar remain staged')
