from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[2]

platforms={
    'PS1':('duckstation','DuckStation'),
    'PS2':('pcsx2','PCSX2'),
    'PS3':('rpcs3','RPCS3'),
}
for folder,(adapter,backend) in platforms.items():
    p=ROOT/'EmulatorPlatforms'/folder/'platform.json'
    data=json.loads(p.read_text(encoding='utf-8-sig'))
    data['adapter']=adapter
    data['primaryBackend']=backend
    data['nativeFullEmulatorSettings']=True
    p.write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8-sig')

worker=ROOT/'HuymaierEmulatorSettingsWorker.ps1'
text=worker.read_text(encoding='utf-8-sig')
root_anchor="        'shadps4' {Add-Root $roots $seen (Join-Path $app 'shadPS4');Add-Root $roots $seen (Join-Path $local 'shadPS4');Add-Root $roots $seen (Join-Path $docs 'shadPS4')}"
if "'duckstation' {" not in text:
    roots="""        'duckstation' {Add-Root $roots $seen ([string](Get-EntryProperty $Settings 'dataRoot' ''));Add-Root $roots $seen ([string](Get-EntryProperty $Settings 'duckStationPath' ''));Add-Root $roots $seen (Join-Path $docs 'DuckStation');Add-Root $roots $seen (Join-Path $app 'DuckStation');Add-Root $roots $seen (Join-Path $local 'DuckStation')}\n        'pcsx2' {Add-Root $roots $seen ([string](Get-EntryProperty $Settings 'dataRoot' ''));Add-Root $roots $seen ([string](Get-EntryProperty $Settings 'pcsx2Path' ''));Add-Root $roots $seen (Join-Path $docs 'PCSX2');Add-Root $roots $seen (Join-Path $app 'PCSX2');Add-Root $roots $seen (Join-Path $local 'PCSX2')}\n        'rpcs3' {Add-Root $roots $seen ([string](Get-EntryProperty $Settings 'rpcs3DataPath' ''));Add-Root $roots $seen ([string](Get-EntryProperty $Settings 'rpcs3Path' ''));Add-Root $roots $seen (Join-Path $app 'rpcs3');Add-Root $roots $seen (Join-Path $local 'rpcs3');Add-Root $roots $seen (Join-Path $docs 'RPCS3')}\n"""
    if text.count(root_anchor)!=1: raise SystemExit('PlayStation adapter root insertion anchor missing')
    text=text.replace(root_anchor,roots+root_anchor,1)

config_anchor="            'shadps4' {foreach($rel in @('config.toml','settings.toml','config.json','settings.json','config.ini')){Add-File (Join-Path $root $rel)};try{Get-ChildItem -LiteralPath $root -File -ErrorAction SilentlyContinue|Where-Object{$_.Name -match '(?i)(config|settings).*\\.(toml|json|ini|cfg)$'}|Select-Object -First 30|ForEach-Object{Add-File $_.FullName}}catch{}}"
if "'duckstation' {foreach($rel" not in text:
    configs="""            'duckstation' {foreach($rel in @('settings.ini','portable.txt','config\\settings.ini')){Add-File (Join-Path $root $rel)};foreach($dirName in @('gamesettings','inputprofiles')){try{Get-ChildItem -LiteralPath (Join-Path $root $dirName) -File -Filter '*.ini' -ErrorAction SilentlyContinue|Select-Object -First 300|ForEach-Object{Add-File $_.FullName}}catch{}}}\n            'pcsx2' {foreach($rel in @('inis\\PCSX2.ini','inis\\GS.ini','inis\\SPU2.ini','inis\\DEV9.ini','inis\\USB.ini','inis\\PAD.ini','PCSX2.ini','GS.ini')){Add-File (Join-Path $root $rel)};try{Get-ChildItem -LiteralPath $root -File -Recurse -ErrorAction SilentlyContinue|Where-Object{$_.Extension -ieq '.ini' -and $_.FullName -notmatch '(?i)\\logs?\\'}|Select-Object -First 350|ForEach-Object{Add-File $_.FullName}}catch{}}\n            'rpcs3' {foreach($rel in @('config.yml','config.yaml','GuiConfigs\\CurrentSettings.ini')){Add-File (Join-Path $root $rel)};try{Get-ChildItem -LiteralPath (Join-Path $root 'custom_configs') -File -ErrorAction SilentlyContinue|Where-Object{$_.Extension -match '(?i)^\\.ya?ml$'}|Select-Object -First 500|ForEach-Object{Add-File $_.FullName}}catch{};try{Get-ChildItem -LiteralPath $root -File -ErrorAction SilentlyContinue|Where-Object{$_.Name -match '(?i)^config\\.ya?ml$'}|ForEach-Object{Add-File $_.FullName}}catch{}}\n"""
    if text.count(config_anchor)!=1: raise SystemExit('PlayStation adapter config insertion anchor missing')
    text=text.replace(config_anchor,configs+config_anchor,1)
worker.write_text(text,encoding='utf-8')
print('materialized DuckStation, PCSX2 and RPCS3 complete settings discovery adapters')
