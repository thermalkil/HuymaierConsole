from pathlib import Path
import json

ROOT=Path(__file__).resolve().parents[2]
registry_path=ROOT/'EmulatorPlatforms'/'platform-registry.json'
registry=json.loads(registry_path.read_text(encoding='utf-8-sig'))
platforms=list(registry.get('platforms',[]))
by_id={str(item.get('id','')).lower():item for item in platforms}

common=[
    'library','cached-library','direct-launch','launch-return','controller-navigation',
    'startup-video','cover-art','compiled-native-host','in-process-platform-view',
    'huymaier-native-path-picker','latest-emulator-install','emulator-first-cover-art',
    'native-full-emulator-settings','unknown-setting-preservation','native-save-management'
]

def entry(id_,name,sort,backend,fallback,interface,menu,aliases,extra=None):
    caps=list(common)
    for value in extra or []:
        if value not in caps:caps.append(value)
    return {
        'id':id_,'name':name,'kind':'native-platform-view','enabled':True,'sortOrder':sort,
        'backend':backend,'fallbackBackend':fallback,'interface':interface,
        'displayName':name,'menuName':menu,'aliases':aliases,'version':'0.26.4-dev',
        'nativeType':'HuymaierConsole.NativeApp.ConsolePlatformWindow','capabilities':caps
    }

wave1=[
    entry('psp','PlayStation Portable',305,'PPSSPP','PPSSPP Development','Native PSP XMB','PSP',['PlayStation Portable','Sony PlayStation Portable','PSP','PPSSPP'],['saved-data-utility','xmb-navigation']),
    entry('nds','Nintendo DS',312,'melonDS','melonDS Development','Native Nintendo DS firmware-menu interface','Nintendo DS',['Nintendo DS','NDS','DS','melonDS'],['dual-screen-menu','game-save-management']),
    entry('dsi','Nintendo DSi',314,'melonDS','melonDS Development','Native Nintendo DSi Menu interface','Nintendo DSi',['Nintendo DSi','DSi','DSI','melonDS DSi'],['dual-screen-menu','dsi-system-memory']),
    entry('3ds','Nintendo 3DS',316,'Azahar','Azahar Nightly','Native dual-screen Nintendo 3DS HOME Menu','Nintendo 3DS',['Nintendo 3DS','3DS','Azahar'],['dual-screen-menu','sdmc-data-management','nand-data-management']),
    entry('dreamcast','Sega Dreamcast',380,'Flycast','Flycast Development','Native Dreamcast BIOS Play / File / Music / Settings interface','Dreamcast',['Sega Dreamcast','Dreamcast','Flycast'],['vmu-management','bios-style-menu']),
    entry('saturn','Sega Saturn',390,'Mednafen','Kronos','Native Sega Saturn BIOS-style system menu','Saturn',['Sega Saturn','Saturn','Mednafen Saturn','Kronos'],['backup-memory-management','cd-player-style-menu'])
]

for item in wave1:
    key=item['id'].lower()
    if key in by_id:
        by_id[key].clear();by_id[key].update(item)
    else:
        platforms.append(item);by_id[key]=item

registry['platforms']=sorted(platforms,key=lambda item:int(item.get('sortOrder',1000)))
registry_path.write_text(json.dumps(registry,indent=2)+'\n',encoding='utf-8')

for folder in ['PSP','NDS','DSI','3DS','Dreamcast','Saturn']:
    path=ROOT/'EmulatorPlatforms'/folder/'platform.json'
    data=json.loads(path.read_text(encoding='utf-8-sig'))
    data['enabled']=True
    data['version']='0.26.4-dev'
    path.write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8')

manifest_path=ROOT/'manifest.json'
manifest=json.loads(manifest_path.read_text(encoding='utf-8-sig'))
manifest['build']='platform-expansion-wave1'
features=list(manifest.get('features',[]))
feature='enables the first researched expansion wave: PSP, Nintendo DS, Nintendo DSi, Nintendo 3DS, Dreamcast and Saturn native platform surfaces with native settings, install and storage integration'
if feature not in features:features.append(feature)
manifest['features']=features
manifest['description']='v0.26.4 development Wave 1 enables six researched native platform surfaces on top of the successful v0.26.3 RC4 source while preserving the existing console interfaces.'
manifest_path.write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
print('enabled v0.26.4 Wave 1 platform registry entries')
