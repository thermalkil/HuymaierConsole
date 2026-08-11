from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
worker=ROOT/'HuymaierEmulatorSettingsWorker.ps1'
text=worker.read_text(encoding='utf-8-sig')

old="        'bigpemu' {Add-Root $roots $seen (Join-Path $app 'BigPEmu');Add-Root $roots $seen (Join-Path $local 'BigPEmu')}"
new="        'bigpemu' {Add-Root $roots $seen (Join-Path $app 'BigPEmu');Add-Root $roots $seen (Join-Path $local 'BigPEmu');foreach($folder in @((Get-EntryProperty $Settings 'gameFolders' @()))){Add-Root $roots $seen ([string]$folder)}}"
if old in text:text=text.replace(old,new,1)
elif new not in text:raise SystemExit('BigPEmu root discovery anchor missing')

old2="            'bigpemu' {foreach($rel in @('BigPEmu.ini','bigpemu.ini','config.ini','settings.ini','config.json','settings.json')){Add-File (Join-Path $root $rel)};try{Get-ChildItem -LiteralPath $root -File -ErrorAction SilentlyContinue|Where-Object{$_.Name -match '(?i)(bigpemu|config|settings|profile).*\\.(ini|cfg|json)$'}|Select-Object -First 40|ForEach-Object{Add-File $_.FullName}}catch{}}"
new2="            'bigpemu' {foreach($rel in @('BigPEmuConfig.bigpcfg','UserData\\BigPEmuConfig.bigpcfg','BigPEmu.ini','bigpemu.ini','config.ini','settings.ini','config.json','settings.json')){Add-File (Join-Path $root $rel)};try{Get-ChildItem -LiteralPath $root -File -Recurse -ErrorAction SilentlyContinue|Where-Object{$_.Name -ieq 'BigPEmuConfig.bigpcfg' -or $_.Extension -ieq '.bigpcfg' -or $_.Name -match '(?i)(bigpemu|config|settings|profile).*\\.(ini|cfg|json)$'}|Select-Object -First 500|ForEach-Object{Add-File $_.FullName}}catch{}}"
if old2 in text:text=text.replace(old2,new2,1)
elif new2 not in text:raise SystemExit('BigPEmu config discovery anchor missing')
worker.write_text(text,encoding='utf-8-sig')

core=ROOT/'HuymaierEmulatorSettings.ps1'
c=core.read_text(encoding='utf-8-sig')
marker="        if($AdapterId -ieq 'ares'){$Format='bml'}"
insert="        if($AdapterId -ieq 'bigpemu' -and $ext -ieq '.bigpcfg'){$Format='json'}\n"
if insert.strip() not in c:
    if marker not in c:raise SystemExit('Settings format adapter anchor missing')
    c=c.replace(marker,insert+marker,1)
core.write_text(c,encoding='utf-8-sig')
print('materialized BigPEmu global/portable/per-game .bigpcfg JSON settings discovery')
