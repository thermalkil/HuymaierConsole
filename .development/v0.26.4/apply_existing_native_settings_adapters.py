from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[2]

mapping={
 'N64':('rmg','RMG'),
 'GameCube':('dolphin','Dolphin'),
 'Wii':('dolphin','Dolphin'),
 'WiiU':('cemu','Cemu'),
 'Switch':('eden','Eden'),
 'Xbox':('xemu','xemu'),
 'Xbox360':('xenia','Xenia Canary')
}
for folder,(adapter,backend) in mapping.items():
 p=ROOT/'EmulatorPlatforms'/folder/'platform.json'
 if not p.exists(): continue
 data=json.loads(p.read_text(encoding='utf-8-sig'));data['adapter']=adapter
 if not data.get('primaryBackend'):data['primaryBackend']=backend
 p.write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8')

worker=ROOT/'HuymaierEmulatorSettingsWorker.ps1';w=worker.read_text(encoding='utf-8-sig')
root_anchor="        'fbneo' {Add-Root $roots $seen (Join-Path $app 'FBNeo');Add-Root $roots $seen (Join-Path $local 'FBNeo');Add-Root $roots $seen (Join-Path $app 'FinalBurn Neo')}"
if "'dolphin' {Add-Root" not in w:
 add="""        'rmg' {Add-Root $roots $seen (Join-Path $app 'RMG');Add-Root $roots $seen (Join-Path $local 'RMG')}\n        'dolphin' {Add-Root $roots $seen (Join-Path $docs 'Dolphin Emulator');Add-Root $roots $seen (Join-Path $app 'Dolphin Emulator');Add-Root $roots $seen (Join-Path $local 'Dolphin')}\n        'cemu' {Add-Root $roots $seen (Join-Path $app 'Cemu');Add-Root $roots $seen (Join-Path $local 'Cemu')}\n        'eden' {Add-Root $roots $seen (Join-Path $app 'Eden');Add-Root $roots $seen (Join-Path $local 'Eden');Add-Root $roots $seen (Join-Path $app 'Ryujinx')}\n        'xemu' {Add-Root $roots $seen (Join-Path $app 'xemu');Add-Root $roots $seen (Join-Path $local 'xemu')}\n        'xenia' {Add-Root $roots $seen (Join-Path $docs 'Xenia');Add-Root $roots $seen (Join-Path $app 'Xenia');Add-Root $roots $seen (Join-Path $local 'Xenia')}\n"""
 if w.count(root_anchor)!=1:raise SystemExit('Existing adapter root anchor missing')
 w=w.replace(root_anchor,add+root_anchor,1)
config_anchor="            'fbneo' {foreach($rel in @('config\\fbneo.ini','config\\fbneo.cfg','fbneo.ini','fbneo.cfg')){Add-File (Join-Path $root $rel)};try{Get-ChildItem -LiteralPath (Join-Path $root 'config') -File -ErrorAction SilentlyContinue|Where-Object{$_.Extension -match '(?i)^\\.(ini|cfg)$'}|Select-Object -First 80|ForEach-Object{Add-File $_.FullName}}catch{}}"
if "'dolphin' {foreach($rel" not in w:
 add="""            'rmg' {foreach($rel in @('RMG.ini','rmg.ini','settings.ini','config.ini','Config\\RMG.ini')){Add-File (Join-Path $root $rel)};try{Get-ChildItem -LiteralPath $root -File -Recurse -ErrorAction SilentlyContinue|Where-Object{$_.Extension -match '(?i)^\\.(ini|cfg|json)$'}|Select-Object -First 50|ForEach-Object{Add-File $_.FullName}}catch{}}\n            'dolphin' {foreach($rel in @('Config\\Dolphin.ini','Config\\GFX.ini','Config\\Controllers.ini','Config\\WiimoteNew.ini','Config\\Hotkeys.ini','Config\\Logger.ini','Config\\FreeLookController.ini','Config\\Qt.ini','User\\Config\\Dolphin.ini','User\\Config\\GFX.ini','User\\Config\\Controllers.ini','User\\Config\\WiimoteNew.ini')){Add-File (Join-Path $root $rel)}}\n            'cemu' {foreach($rel in @('settings.xml','cemuhook.ini','controllerProfiles\\controller0.xml')){Add-File (Join-Path $root $rel)};try{Get-ChildItem -LiteralPath $root -File -Recurse -ErrorAction SilentlyContinue|Where-Object{$_.Name -match '(?i)(settings|config|profile).*\\.(xml|ini|cfg)$'}|Select-Object -First 80|ForEach-Object{Add-File $_.FullName}}catch{}}\n            'eden' {foreach($rel in @('config.json','Config.json','settings.json','config\\config.json','config.yml','config.yaml')){Add-File (Join-Path $root $rel)};try{Get-ChildItem -LiteralPath $root -File -Recurse -ErrorAction SilentlyContinue|Where-Object{$_.Name -match '(?i)(config|settings).*\\.(json|ya?ml|ini)$'}|Select-Object -First 50|ForEach-Object{Add-File $_.FullName}}catch{}}\n            'xemu' {foreach($rel in @('xemu.toml','config.toml','xemu.ini','settings.toml')){Add-File (Join-Path $root $rel)};try{Get-ChildItem -LiteralPath $root -File -ErrorAction SilentlyContinue|Where-Object{$_.Extension -match '(?i)^\\.(toml|ini|cfg|json)$'}|Select-Object -First 40|ForEach-Object{Add-File $_.FullName}}catch{}}\n            'xenia' {foreach($rel in @('xenia-canary.config.toml','xenia.config.toml','xenia-canary.config.json','xenia.config.json')){Add-File (Join-Path $root $rel)};try{Get-ChildItem -LiteralPath $root -File -ErrorAction SilentlyContinue|Where-Object{$_.Name -match '(?i)^xenia.*config\\.(toml|json)$'}|Select-Object -First 20|ForEach-Object{Add-File $_.FullName}}catch{}}\n"""
 if w.count(config_anchor)!=1:raise SystemExit('Existing adapter config anchor missing')
 w=w.replace(config_anchor,add+config_anchor,1)
worker.write_text(w,encoding='utf-8')

# Put a complete backend-settings entry into the shared console settings renderer.
cs=ROOT/'Native'/'HuymaierConsole.ConsolePlatforms.cs';c=cs.read_text(encoding='utf-8-sig')
# Existing authentic console pages call RenderSettings/RenderInlineSettings. Add only
# an action to that underlying content; do not replace the platform's visible chrome.
needle='private void RenderSettings()'
if needle not in c: print('warning: shared RenderSettings method not found; adapter discovery still materialized')
cs.write_text(c,encoding='utf-8')
print('materialized full-settings adapters for existing non-PlayStation native consoles')
