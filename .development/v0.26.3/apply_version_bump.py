from pathlib import Path
import json

OLD='0.26.2'
NEW='0.26.3'

def replace_exact(path, old, new, count=1):
    p=Path(path)
    text=p.read_text(encoding='utf-8-sig')
    found=text.count(old)
    if found != count:
        raise SystemExit(f'{path}: expected {count} occurrence(s) of {old!r}, found {found}')
    text=text.replace(old,new)
    p.write_text(text,encoding='utf-8')

replace_exact('HuymaierConsole.ps1', "$script:AppVersion = '0.26.2'", "$script:AppVersion = '0.26.3'")
replace_exact('HuymaierBootstrap.ps1', "$script:ExpectedConsoleVersion='0.26.2'", "$script:ExpectedConsoleVersion='0.26.3'")
replace_exact('HuymaierInstallerCore.ps1', "$script:InstallVersion='0.26.2'", "$script:InstallVersion='0.26.3'")
replace_exact('Native/HuymaierConsole.GameInput.cs', 'public const string Version = "0.26.2";', 'public const string Version = "0.26.3";')
replace_exact('Native/HuymaierConsole.NativeApp.cs', 'public string Version { get { return "0.26.2"; } }', 'public string Version { get { return "0.26.3"; } }')
replace_exact('FSEPackage/AppxManifest.xml', 'Version="0.26.2.0"', 'Version="0.26.3.0"')

p=Path('manifest.json')
data=json.loads(p.read_text(encoding='utf-8-sig'))
if data.get('version') != OLD or data.get('baseVersion') != '0.26.1':
    raise SystemExit('manifest.json is not the expected v0.26.2 baseline')
data['version']=NEW
data['baseVersion']='0.26.2'
data['build']='native-console-fidelity'
data['builtFrom']='HC262.zip'
features=list(data.get('features',[]))
features.insert(0,'recreates the N64, GameCube, Wii, Wii U, Switch, Original Xbox, and Xbox 360 native interfaces with console-specific layouts and spatial navigation')
features.insert(1,'removes LB/RB shoulder-button page and selection switching from Huymaier native console interfaces while preserving D-pad/stick, confirm, back, Guide/Game Bar, launch/return, saves, and alternate-emulator behavior')
data['features']=features
data['description']='v0.26.3 is a focused native-console fidelity pass built on the published v0.26.2 baseline. It leaves the PS1, PS2, and PS3 interface implementations unchanged while replacing the generalized non-PlayStation shell behavior with console-specific layouts and controller navigation.'
p.write_text(json.dumps(data,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
