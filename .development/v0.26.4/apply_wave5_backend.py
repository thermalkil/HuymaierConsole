from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
installer=ROOT/'HuymaierEmulatorInstaller.ps1';p=installer.read_text(encoding='utf-8-sig')
cases=r'''    'PS4' {$exe=Install-GithubArchive 'shadps4-emu/shadPS4' { $_.name -match '(?i)(windows|win).*(x64|64).*\.(zip|7z)$' -or $_.name -match '(?i)shadps4.*windows.*\.(zip|7z)$' } 'shadPS4' @('shadPS4.exe','shadps4.exe')}
    'VITA' {$exe=Install-GithubArchive 'Vita3K/Vita3K' { $_.name -match '(?i)(windows|win).*(x64|64).*\.(zip|7z)$' -or $_.name -match '(?i)Vita3K.*windows.*\.(zip|7z)$' } 'Vita3K' @('Vita3K.exe','vita3k.exe')}
'''
if "'PS4' {$exe=Install-GithubArchive 'shadps4-emu/shadPS4'" not in p:
    anchor="    'ARCADE' {$exe=Install-MameLatest}"
    idx=p.find(anchor)
    if idx<0:raise SystemExit('Wave5 installer case anchor missing')
    p=p[:idx]+cases+p[idx:]
installer.write_text(p,encoding='utf-8')

worker=ROOT/'HuymaierEmulatorSettingsWorker.ps1';w=worker.read_text(encoding='utf-8-sig')
if "'shadps4' {Add-Root" not in w:
    anchor="        'fbneo' {Add-Root $roots $seen (Join-Path $app 'FBNeo');Add-Root $roots $seen (Join-Path $local 'FBNeo');Add-Root $roots $seen (Join-Path $app 'FinalBurn Neo')}"
    add="""        'shadps4' {Add-Root $roots $seen (Join-Path $app 'shadPS4');Add-Root $roots $seen (Join-Path $local 'shadPS4');Add-Root $roots $seen (Join-Path $docs 'shadPS4')}\n        'vita3k' {Add-Root $roots $seen (Join-Path $app 'Vita3K');Add-Root $roots $seen (Join-Path $local 'Vita3K');Add-Root $roots $seen (Join-Path $docs 'Vita3K')}\n"""
    if w.count(anchor)!=1:raise SystemExit('Wave5 settings roots anchor missing')
    w=w.replace(anchor,add+anchor,1)
if "'shadps4' {foreach($rel" not in w:
    anchor="            'fbneo' {foreach($rel in @('config\\fbneo.ini','config\\fbneo.cfg','fbneo.ini','fbneo.cfg')){Add-File (Join-Path $root $rel)};try{Get-ChildItem -LiteralPath (Join-Path $root 'config') -File -ErrorAction SilentlyContinue|Where-Object{$_.Extension -match '(?i)^\\.(ini|cfg)$'}|Select-Object -First 80|ForEach-Object{Add-File $_.FullName}}catch{}}"
    add="""            'shadps4' {foreach($rel in @('config.toml','settings.toml','config.json','settings.json','config.ini')){Add-File (Join-Path $root $rel)};try{Get-ChildItem -LiteralPath $root -File -ErrorAction SilentlyContinue|Where-Object{$_.Name -match '(?i)(config|settings).*\\.(toml|json|ini|cfg)$'}|Select-Object -First 30|ForEach-Object{Add-File $_.FullName}}catch{}}\n            'vita3k' {foreach($rel in @('config.yml','config.yaml','config\\config.yml','config\\config.yaml')){Add-File (Join-Path $root $rel)};try{Get-ChildItem -LiteralPath $root -File -ErrorAction SilentlyContinue|Where-Object{$_.Name -match '(?i)(config|settings).*\\.(ya?ml|json|ini)$'}|Select-Object -First 30|ForEach-Object{Add-File $_.FullName}}catch{}}\n"""
    if w.count(anchor)!=1:raise SystemExit('Wave5 config discovery anchor missing')
    w=w.replace(anchor,add+anchor,1)
worker.write_text(w,encoding='utf-8')

lib=ROOT/'HuymaierNativeConsoleLibraryWorker.ps1';l=lib.read_text(encoding='utf-8-sig')
if "'PS4' { return @('.pkg','.elf','.bin') }" not in l:
    anchor="        'ARCADE' { return @('.zip','.7z','.chd') }"
    add="        'PS4' { return @('.pkg','.elf','.bin') }\n        'VITA' { return @('.vpk','.pkg','.zip') }\n"
    if l.count(anchor)!=1:raise SystemExit('Wave5 count scanner anchor missing')
    l=l.replace(anchor,add+anchor,1)
lib.write_text(l,encoding='utf-8')
print('materialized shadPS4/Vita3K install, settings discovery and preliminary package count scanning')
