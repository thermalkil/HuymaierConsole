from pathlib import Path
import json

OLD='0.26.3'
NEW='0.26.4'
ROOT=Path(__file__).resolve().parents[2]

def replace_one(relative, old, new):
    p=ROOT/relative
    text=p.read_text(encoding='utf-8-sig')
    count=text.count(old)
    if count != 1:
        raise SystemExit(f'{relative}: expected exactly one {old!r}, found {count}')
    p.write_text(text.replace(old,new,1),encoding='utf-8')

replace_one('HuymaierConsole.ps1', "$script:AppVersion = '0.26.3'", "$script:AppVersion = '0.26.4'")
replace_one('HuymaierBootstrap.ps1', "$script:ExpectedConsoleVersion='0.26.3'", "$script:ExpectedConsoleVersion='0.26.4'")
replace_one('HuymaierInstallerCore.ps1', "$script:InstallVersion='0.26.3'", "$script:InstallVersion='0.26.4'")
replace_one('Native/HuymaierConsole.GameInput.cs', 'public const string Version = "0.26.3";', 'public const string Version = "0.26.4";')
replace_one('Native/HuymaierConsole.NativeApp.cs', 'public string Version { get { return "0.26.3"; } }', 'public string Version { get { return "0.26.4"; } }')
replace_one('FSEPackage/AppxManifest.xml', 'Version="0.26.3.0"', 'Version="0.26.4.0"')

p=ROOT/'manifest.json'
data=json.loads(p.read_text(encoding='utf-8-sig'))
if data.get('version') != OLD:
    raise SystemExit(f'manifest.json expected {OLD}, got {data.get("version")}')
data['version']=NEW
data['baseVersion']='0.26.3'
data['builtFrom']='HC262.zip'
data['build']='platform-expansion-rc1'
data['description']='v0.26.4 RC1 expands Huymaier Console with validated native platform support while preserving the tested v0.26.3 console-fidelity and v0.26.2 Guide/Game Bar baselines. PS4, PS Vita and MAME Arcade are included only after live backend/runtime validation; FBNeo/Neo Geo and Jaguar remain staged.'
p.write_text(json.dumps(data,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')

readme=ROOT/'README.md'
text=readme.read_text(encoding='utf-8-sig')
text=text.replace('The active development branch for **v0.26.3** is focused on native-console fidelity and emulator integration.','The active development branch for **v0.26.4** expands the validated native platform library while preserving the v0.26.3 console-fidelity work and the tested v0.26.2 Guide/Game Bar behavior.')
text=text.replace('## v0.26.3 development goals','## v0.26.4 development status')
text=text.replace('The v0.26.3 console-fidelity pass is replacing generalized non-PlayStation console surfaces with interfaces that match each console\'s real design language and navigation model.','v0.26.4 builds on the console-fidelity pass with researched native platform expansion, complete backend settings integration, controller-first storage management, and validated emulator installation/launch contracts.')
readme.write_text(text,encoding='utf-8')
print('materialized v0.26.4 version invariants')
