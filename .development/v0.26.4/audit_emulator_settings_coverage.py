from pathlib import Path
import json,re
ROOT=Path(__file__).resolve().parents[2]
registry=json.loads((ROOT/'EmulatorPlatforms'/'platform-registry.json').read_text(encoding='utf-8-sig'))
worker=(ROOT/'HuymaierEmulatorSettingsWorker.ps1').read_text(encoding='utf-8-sig') if (ROOT/'HuymaierEmulatorSettingsWorker.ps1').exists() else ''
core=(ROOT/'HuymaierEmulatorSettings.ps1').read_text(encoding='utf-8-sig') if (ROOT/'HuymaierEmulatorSettings.ps1').exists() else ''
rows=[]
for entry in registry.get('platforms',[]):
    pid=str(entry.get('id','')).strip(); name=str(entry.get('displayName') or entry.get('name') or pid); enabled=bool(entry.get('enabled',False)); backend=str(entry.get('backend','')).strip()
    candidates=[]
    for folder in (ROOT/'EmulatorPlatforms').iterdir():
        if not folder.is_dir(): continue
        p=folder/'platform.json'
        if not p.exists(): continue
        try:d=json.loads(p.read_text(encoding='utf-8-sig'))
        except Exception:continue
        aliases=[str(d.get('id','')),str(d.get('displayName','')),folder.name]
        if any(a.lower()==pid.lower() for a in aliases if a):candidates.append((folder,d))
    definition=candidates[0][1] if candidates else {}
    adapter=str(definition.get('adapter','')).strip()
    fallback_adapter=str(definition.get('fallbackAdapter','')).strip()
    primary=str(definition.get('primaryBackend') or backend).strip()
    settings_default=bool(candidates and (candidates[0][0]/'settings.default.json').exists())
    adapter_referenced=bool(adapter and re.search(r"['\"]"+re.escape(adapter)+r"['\"]",worker,re.I))
    special=False
    if adapter.lower()=='stella':special='Get-StellaCliSettings' in worker
    elif adapter.lower()=='mame':special='Get-MameCliSettings' in worker
    else:special=adapter_referenced
    formats=[]
    for marker,label in [('Get-HcIniSettings','INI'),('Get-HcJsonSettings','JSON'),('Get-HcTomlScalarSettings','TOML'),('Get-HcYamlScalarSettings','YAML'),('Get-HcBmlScalarSettings','BML'),('Get-HcMednafenSettings','Mednafen KV')]:
        if marker in core:formats.append(label)
    rows.append({'id':pid,'name':name,'enabled':enabled,'primaryBackend':primary,'adapter':adapter,'fallbackAdapter':fallback_adapter,'platformDefinitionFound':bool(candidates),'settingsDefault':settings_default,'adapterDiscoveryPresent':adapter_referenced,'specialAdapterReady':bool(special),'nativeSettingsReady':bool(adapter and settings_default and special),'supportedCoreFormats':formats})
report={'schemaVersion':1,'generatedFromBranch':'feature/v0.26.4-platform-expansion','platformCount':len(rows),'enabledCount':sum(1 for r in rows if r['enabled']),'enabledMissingNativeSettings':[r['id'] for r in rows if r['enabled'] and not r['nativeSettingsReady']],'platforms':rows}
(ROOT/'.development'/'v0.26.4'/'emulator-settings-coverage.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
lines=['# v0.26.4 emulator settings coverage','',f"Platforms in registry: **{len(rows)}**  ",f"Enabled: **{report['enabledCount']}**  ",f"Enabled missing a complete native adapter: **{len(report['enabledMissingNativeSettings'])}**",'','| Platform | Enabled | Backend | Adapter | Native settings ready |','|---|---:|---|---|---:|']
for r in rows:lines.append(f"| {r['name']} | {'yes' if r['enabled'] else 'no'} | {r['primaryBackend']} | {r['adapter'] or 'MISSING'} | {'yes' if r['nativeSettingsReady'] else 'NO'} |")
lines+=['','Enabled platforms missing native settings: '+(', '.join(report['enabledMissingNativeSettings']) if report['enabledMissingNativeSettings'] else 'none')]
(ROOT/'Docs'/'EMULATOR-SETTINGS-COVERAGE-v0.26.4.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
print(json.dumps({'platformCount':len(rows),'enabledCount':report['enabledCount'],'enabledMissing':report['enabledMissingNativeSettings']}))
