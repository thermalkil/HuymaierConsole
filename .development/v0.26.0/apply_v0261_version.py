from pathlib import Path
import json

ROOT=Path(__file__).resolve().parents[2]

core=ROOT/'HuymaierConsole.ps1'
text=core.read_text(encoding='utf-8-sig')
if text.count("$script:AppVersion = '0.26.0'") != 1:
    raise RuntimeError('core AppVersion marker not found exactly once')
text=text.replace("$script:AppVersion = '0.26.0'","$script:AppVersion = '0.26.1'",1)
core.write_text(text,encoding='utf-8')

bootstrap=ROOT/'HuymaierBootstrap.ps1'
text=bootstrap.read_text(encoding='utf-8-sig')
text=text.replace("Huymaier Console v0.26.0 preflight passed.","Huymaier Console v0.26.1 preflight passed.")
text=text.replace("v0.26.0 preflight/startup failed:","v0.26.1 preflight/startup failed:")
bootstrap.write_text(text,encoding='utf-8')

manifest_path=ROOT/'manifest.json'
data=json.loads(manifest_path.read_text(encoding='utf-8-sig'))
data['version']='0.26.1'
data['baseVersion']='0.26.0'
data['build']='installer-lock-and-atomic-rollback-hotfix'
features=list(data.get('features',[]))
features.extend([
    'stops all native Huymaier Console hosts before replacing any installed payload files',
    'skips byte-identical locked files and retries changed locked files instead of aborting immediately',
    'uses recursive updater rollback so a failed update cannot relaunch a mixed native/script installation'
])
data['features']=features
data['description']='v0.26.1 hotfix for reliable self-update/install replacement while preserving the runtime-tested v0.26.0 Game Bar, Guide routing, task switcher, and popup navigation behavior.'
manifest_path.write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8')
print('Versioned installer hotfix candidate as v0.26.1.')
