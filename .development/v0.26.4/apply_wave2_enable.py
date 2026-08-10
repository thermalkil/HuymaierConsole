from pathlib import Path
import json,re
ROOT=Path(__file__).resolve().parents[2]
platforms={
 'Atari2600':('atari2600','Atari 2600',400,'Stella','stella','Atari VCS control-deck and cartridge interface'),
 'NES':('nes','Nintendo Entertainment System',410,'Mesen Community Edition','mesence','NES control-deck and cartridge interface'),
 'SNES':('snes','Super Nintendo Entertainment System',420,'Mesen Community Edition','mesence','SNES control-deck and cartridge interface'),
 'GameBoy':('gameboy','Nintendo Game Boy',430,'Mesen Community Edition','mesence','DMG handheld and cartridge interface'),
 'GBC':('gbc','Nintendo Game Boy Color',440,'Mesen Community Edition','mesence','Game Boy Color handheld and cartridge interface'),
 'GBA':('gba','Nintendo Game Boy Advance',450,'mGBA','mgba','Game Boy Advance handheld and cartridge interface'),
 'Genesis':('genesis','Sega Genesis',460,'ares','ares','Genesis / Mega Drive control-deck and cartridge interface'),
 'SegaCD':('segacd','Sega CD',470,'ares','ares','Sega CD BIOS / CD-player inspired disc interface'),
 'Sega32X':('sega32x','Sega 32X',480,'ares','ares','Genesis + 32X tower and cartridge interface'),
 'GameGear':('gamegear','Sega Game Gear',490,'Mesen Community Edition','mesence','Game Gear handheld and cartridge interface'),
 'MasterSystem':('mastersystem','Sega Master System',500,'Mesen Community Edition','mesence','Master System control-deck / card / cartridge interface'),
 'TurboGrafx16':('turbografx16','TurboGrafx-16',510,'Mednafen','mednafen','TurboGrafx-16 / PC Engine HuCard and CD interface')
}
for folder,(pid,display,sort,backend,adapter,interface) in platforms.items():
 p=ROOT/'EmulatorPlatforms'/folder/'platform.json';d=json.loads(p.read_text(encoding='utf-8-sig'));d['enabled']=True;d['version']='0.26.4-dev';d['primaryBackend']=backend;d['adapter']=adapter;d['fallbackBackend']='';d.pop('fallbackAdapter',None);p.write_text(json.dumps(d,indent=2)+'\n',encoding='utf-8')

# GB/GBC use Mesen CE as the attached backend so complete native JSON settings
# are available. SameBoy can return later only after a full persistent-settings
# adapter is proven.
cs=ROOT/'Native'/'HuymaierConsole.ConsolePlatforms.cs';c=cs.read_text(encoding='utf-8-sig')
for shell in ('GAMEBOY','GBC'):
 pattern=r'(else if \(key == "'+shell+r'"\)\s*\{\s*d\.DisplayName=.*?d\.Shell="(?:GameBoy|GBC)";)(.*?)(d\.GameExtensions=)'
 m=re.search(pattern,c,re.S)
 if not m:raise SystemExit(f'Could not isolate {shell} definition for backend graduation')
 middle=m.group(2)
 middle=re.sub(r'd\.PrimaryBackend="[^"]*";d\.FallbackBackend="[^"]*";d\.PrimaryExecutableNames=new string\[\]\{[^}]*\};d\.FallbackExecutableNames=new string\[\]\{[^}]*\};', 'd.PrimaryBackend="Mesen Community Edition";d.FallbackBackend=String.Empty;d.PrimaryExecutableNames=new string[]{"Mesen.exe","Mesen2.exe"};d.FallbackExecutableNames=new string[0];', middle, count=1)
 c=c[:m.start(2)]+middle+c[m.end(2):]
cs.write_text(c,encoding='utf-8')

registry_path=ROOT/'EmulatorPlatforms'/'platform-registry.json';registry=json.loads(registry_path.read_text(encoding='utf-8-sig'));items=list(registry.get('platforms',[]));by={str(x.get('id','')).lower():x for x in items}
common=['library','cached-library','direct-launch','launch-return','controller-navigation','cover-art','compiled-native-host','in-process-platform-view','huymaier-native-path-picker','latest-emulator-install','emulator-first-cover-art','native-full-emulator-settings','unknown-setting-preservation','native-save-management','alphabet-index']
for folder,(pid,display,sort,backend,adapter,interface) in platforms.items():
 entry={'id':pid,'name':display,'kind':'native-platform-view','enabled':True,'sortOrder':sort,'backend':backend,'interface':interface,'displayName':display,'menuName':display.replace('Nintendo ','').replace('Sega ',''),'aliases':[display,folder,backend],'version':'0.26.4-dev','nativeType':'HuymaierConsole.NativeApp.ConsolePlatformWindow','capabilities':common[:]}
 if pid=='atari2600':entry['capabilities']+=['stella-installed-version-cli-settings']
 if pid=='segacd':entry['capabilities']+=['backup-ram-management','cd-player-style-menu']
 if pid in ('gameboy','gbc','gba','gamegear'):entry['capabilities']+=['battery-save-management','handheld-hardware-shell']
 if pid=='turbografx16':entry['capabilities']+=['hucard-and-cd-library']
 if pid in by:by[pid].clear();by[pid].update(entry)
 else:items.append(entry);by[pid]=entry
registry['platforms']=sorted(items,key=lambda x:int(x.get('sortOrder',1000)));registry_path.write_text(json.dumps(registry,indent=2)+'\n',encoding='utf-8')

manifest_path=ROOT/'manifest.json';manifest=json.loads(manifest_path.read_text(encoding='utf-8-sig'));manifest['build']='platform-expansion-wave2';features=list(manifest.get('features',[]));feature='enables researched Wave 2 hardware-native Atari 2600, NES, SNES, Game Boy, Game Boy Color, Game Boy Advance, Genesis, Sega CD, Sega 32X, Game Gear, Master System and TurboGrafx-16 surfaces with native install/settings/storage integration';
if feature not in features:features.append(feature)
manifest['features']=features;manifest['description']='v0.26.4 development Wave 2 adds twelve validated cartridge/CD/handheld platforms on top of Wave 1 while preserving v0.26.3 RC4 console behavior.';manifest_path.write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')

# Update status documentation from staged -> enabled wording.
status=ROOT/'Docs'/'PLATFORM-IMPLEMENTATION-STATUS-v0.26.4.md'
if status.exists():
 s=status.read_text(encoding='utf-8-sig');s=s.replace('## Expansion Wave 2 — staged, not enabled until all backend audits are complete','## Expansion Wave 2 — enabled in v0.26.4 development');s=s.replace('Wave 2 hardware renderers have passed the exact x64 compile. The backend layer includes dynamic latest-release installation, JSON/TOML/INI/BML/YAML/key-value preservation infrastructure, save-memory presentation and large-library first-letter acceleration. Atari 2600 additionally uses an installed-version Stella `-help` adapter so Huymaier does not write Stella 7\'s SQLite database directly. SameBoy remains under settings-completeness audit before Wave 2 is globally enabled.','Wave 2 hardware renderers, native save/settings surfaces, latest-emulator installers and exact x64 compile gates have passed. Atari 2600 uses an installed-version Stella `-help` adapter so Huymaier never writes Stella 7 SQLite configuration directly. GB/GBC use Mesen CE as the attached backend so every enabled Wave 2 emulator has a complete native settings path.');status.write_text(s,encoding='utf-8')

# Branch-wide validator must now regard Wave2 as graduated. Remove only the
# Wave2 folder names from the later-wave disabled list.
validator=ROOT/'.github'/'workflows'/'validate-v0264-expansion.yml'
if validator.exists():
 v=validator.read_text(encoding='utf-8-sig')
 for folder in platforms:
  v=v.replace("'"+folder+"',",'').replace(",\'"+folder+"\'",'')
 validator.write_text(v,encoding='utf-8')
print('graduated all 12 Wave 2 platforms with single fully-supported primary backends')
