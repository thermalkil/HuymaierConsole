#!/usr/bin/env python3
from pathlib import Path
import json

ROOT=Path(__file__).resolve().parents[2]
OLD='0.26.1';NEW='0.26.2'

def read(path): return path.read_text(encoding='utf-8-sig')
def write(path,text): path.write_text(text,encoding='utf-8-sig',newline='\n')
def replace(path,old,new,count=None):
    text=read(path);found=text.count(old)
    if found==0: raise SystemExit(f'{path}: missing {old!r}')
    if count is not None and found!=count: raise SystemExit(f'{path}: expected {count} matches for {old!r}, found {found}')
    write(path,text.replace(old,new))
    print(f'{path.relative_to(ROOT)}: replaced {found} occurrence(s)')

manifest_path=ROOT/'manifest.json'
manifest=json.loads(manifest_path.read_text(encoding='utf-8-sig'))
if manifest.get('version')!=OLD: raise SystemExit(f"manifest version is {manifest.get('version')}, expected {OLD}")
manifest['version']=NEW
manifest['baseVersion']=OLD
manifest['build']='controller-customization-provider-runtime'
manifest['builtFrom']='HC261.zip'
manifest['features']=[
  'opens Huymaier Game Bar above external apps and Huymaier-native console surfaces while keeping main-shell Guide mapped to Quick Access',
  'adds controller-first visual color wheels for interface, focus, accent, and dynamic-theme colors without requiring hex entry',
  'adds persistent Games layout editing for storefront/console order, visibility, and per-platform tile sizing',
  'repairs shared Manage/action-card sizing so highlighted titles and descriptions are not clipped',
  'adds Steam client game management through the unified provider experience with install, verify, update, uninstall, launch, and Steam transfer telemetry',
  'adds safe indeterminate live activity telemetry for GOG and Amazon when their backends do not expose a trustworthy total',
  'preserves the v0.26.1 transactional installer, exact-artifact updater, x64 GameInput bridge, and fail-closed mixed-version protection',
  'preserves the v0.26.1 storefront library import/file-browser repair and strict Xbox versus Original Xbox platform identity'
]
manifest['description']='v0.26.2 expands the controller-first console experience with native-surface Game Bar routing, visual color and layout customization, Steam game management, multi-provider download telemetry, and shared card-rendering fixes while retaining the v0.26.1 integrity architecture.'
manifest_path.write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')

replace(ROOT/'HuymaierConsole.ps1',"$script:AppVersion = '0.26.1'","$script:AppVersion = '0.26.2'",1)
replace(ROOT/'HuymaierBootstrap.ps1',OLD,NEW)
replace(ROOT/'HuymaierInstallerCore.ps1',"$script:InstallVersion='0.26.1'","$script:InstallVersion='0.26.2'",1)
replace(ROOT/'Native'/'HuymaierConsole.GameInput.cs','public const string Version = "0.26.1";','public const string Version = "0.26.2";',1)
replace(ROOT/'Native'/'HuymaierConsole.NativeApp.cs','return "0.26.1";','return "0.26.2";',1)
replace(ROOT/'FSEPackage'/'AppxManifest.xml','Version="0.26.1.0"','Version="0.26.2.0"',1)
print('Applied v0.26.2 cross-file version transition.')
