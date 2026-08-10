from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]

# ---- latest supported emulator installers ----
installer=ROOT/'HuymaierEmulatorInstaller.ps1'
p=installer.read_text(encoding='utf-8-sig')

stella=r'''
function Install-StellaLatest {
    $page=Invoke-WebRequest -UseBasicParsing -Uri 'https://stella-emu.github.io/downloads.html' -Headers @{'User-Agent'='Huymaier-Console/0.26.4'}
    $html=[string]$page.Content
    $matches=[regex]::Matches($html,'(?i)href=["''](?<url>[^"'']*Stella-(?<version>[0-9]+(?:\.[0-9]+)+[a-z]?)-windows\.zip)["'']')
    if($matches.Count -eq 0){throw 'The current official Stella 64-bit Windows ZIP could not be identified.'}
    $href=[System.Net.WebUtility]::HtmlDecode($matches[0].Groups['url'].Value)
    $url=$href;if($href -notmatch '^https?://'){$url=(New-Object Uri ([uri]'https://stella-emu.github.io/'),$href).AbsoluteUri}
    $target=Join-Path $DestinationRoot 'Stella';$work=Join-Path $env:TEMP ('hc-stella-'+[guid]::NewGuid().ToString('N'));New-Item -ItemType Directory -Force -Path $work|Out-Null
    try{$archive=Join-Path $work 'stella-windows.zip';Invoke-WebRequest -UseBasicParsing -Headers $headers -Uri $url -OutFile $archive;New-Item -ItemType Directory -Force -Path $target|Out-Null;Expand-HcArchive $archive $target;$exe=Get-ChildItem -LiteralPath $target -Filter 'Stella.exe' -File -Recurse -ErrorAction SilentlyContinue|Select-Object -First 1;if(-not $exe){$exe=Get-ChildItem -LiteralPath $target -Filter 'stella.exe' -File -Recurse -ErrorAction SilentlyContinue|Select-Object -First 1};if(-not $exe){throw 'Stella.exe was not found after extraction.'};return $exe.FullName}finally{Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue}
}

'''
if 'function Install-StellaLatest {' not in p:
    marker='function Install-MednafenLatest {'
    if p.count(marker)!=1:raise SystemExit('Stella installer insertion anchor missing')
    p=p.replace(marker,stella+marker,1)

wave2_cases=r'''    'ATARI2600' {$exe=Install-StellaLatest}
    'NES' {$exe=Install-GithubArchive 'nesdev-org/MesenCE' { $_.name -match '(?i)(mesen).*(windows|win|x64|64).*\.(zip|7z)$' -and $_.name -notmatch '(?i)(source|symbols|pdb|debug)' } 'MesenCE' @('Mesen.exe','Mesen2.exe')}
    'SNES' {$exe=Install-GithubArchive 'nesdev-org/MesenCE' { $_.name -match '(?i)(mesen).*(windows|win|x64|64).*\.(zip|7z)$' -and $_.name -notmatch '(?i)(source|symbols|pdb|debug)' } 'MesenCE' @('Mesen.exe','Mesen2.exe')}
    'GAMEBOY' {$exe=Install-GithubArchive 'LIJI32/SameBoy' { $_.name -match '(?i)(winsdl|windows).*\.zip$' -and $_.name -notmatch '(?i)(source|debug|symbols)' } 'SameBoy' @('sameboy.exe','SameBoy.exe')}
    'GBC' {$exe=Install-GithubArchive 'LIJI32/SameBoy' { $_.name -match '(?i)(winsdl|windows).*\.zip$' -and $_.name -notmatch '(?i)(source|debug|symbols)' } 'SameBoy' @('sameboy.exe','SameBoy.exe')}
    'GBA' {$exe=Install-GithubArchive 'mgba-emu/mgba' { $_.name -match '(?i)(windows|win).*(64|x64).*\.zip$' -or $_.name -match '(?i)mGBA.*win64.*\.zip$' } 'mGBA' @('mGBA.exe','mGBA-qt.exe','mgba.exe')}
    'GENESIS' {$exe=Install-GithubArchive 'ares-emulator/ares' { $_.name -match '(?i)windows.*(x64|64).*\.zip$' -or $_.name -match '(?i)^ares.*windows.*\.zip$' } 'ares' @('ares.exe')}
    'SEGACD' {$exe=Install-GithubArchive 'ares-emulator/ares' { $_.name -match '(?i)windows.*(x64|64).*\.zip$' -or $_.name -match '(?i)^ares.*windows.*\.zip$' } 'ares' @('ares.exe')}
    'SEGA32X' {$exe=Install-GithubArchive 'ares-emulator/ares' { $_.name -match '(?i)windows.*(x64|64).*\.zip$' -or $_.name -match '(?i)^ares.*windows.*\.zip$' } 'ares' @('ares.exe')}
    'GAMEGEAR' {$exe=Install-GithubArchive 'nesdev-org/MesenCE' { $_.name -match '(?i)(mesen).*(windows|win|x64|64).*\.(zip|7z)$' -and $_.name -notmatch '(?i)(source|symbols|pdb|debug)' } 'MesenCE' @('Mesen.exe','Mesen2.exe')}
    'MASTERSYSTEM' {$exe=Install-GithubArchive 'nesdev-org/MesenCE' { $_.name -match '(?i)(mesen).*(windows|win|x64|64).*\.(zip|7z)$' -and $_.name -notmatch '(?i)(source|symbols|pdb|debug)' } 'MesenCE' @('Mesen.exe','Mesen2.exe')}
    'TURBOGRAFX16' {$exe=Install-MednafenLatest}
'''
if "'ATARI2600' {$exe=Install-StellaLatest}" not in p:
    anchor="    '3DS' {$exe=Install-GithubArchive 'azahar-emu/azahar'"
    idx=p.find(anchor)
    if idx<0:raise SystemExit('Wave2 installer case anchor missing')
    p=p[:idx]+wave2_cases+p[idx:]
installer.write_text(p,encoding='utf-8')

# ---- full native settings discovery for Wave 2 backends ----
worker=ROOT/'HuymaierEmulatorSettingsWorker.ps1'
w=worker.read_text(encoding='utf-8-sig')
if "'mesence' {Add-Root" not in w:
    anchor="        'azahar' {Add-Root $roots $seen (Join-Path $app 'Azahar');Add-Root $roots $seen (Join-Path $app 'azahar');Add-Root $roots $seen (Join-Path $local 'Azahar')}"
    additions="""        'mesence' {Add-Root $roots $seen (Join-Path $app 'Mesen');Add-Root $roots $seen (Join-Path $app 'Mesen2');Add-Root $roots $seen (Join-Path $local 'Mesen');Add-Root $roots $seen (Join-Path $local 'Mesen2')}\n        'sameboy' {Add-Root $roots $seen (Join-Path $app 'SameBoy');Add-Root $roots $seen (Join-Path $local 'SameBoy')}\n        'mgba' {Add-Root $roots $seen (Join-Path $app 'mGBA');Add-Root $roots $seen (Join-Path $local 'mGBA')}\n        'stella' {Add-Root $roots $seen (Join-Path $app 'Stella')}\n        'ares' {Add-Root $roots $seen (Join-Path $app 'ares');Add-Root $roots $seen (Join-Path $local 'ares')}\n"""
    if w.count(anchor)!=1:raise SystemExit('Wave2 settings root anchor missing')
    w=w.replace(anchor,additions+anchor,1)

if "'mesence' {foreach($rel" not in w:
    anchor="            'azahar' {foreach($rel in @('config\\qt-config.ini','qt-config.ini','config.ini')){Add-File (Join-Path $root $rel)}}"
    additions="""            'mesence' {foreach($rel in @('settings.json','Settings.json','config.json','preferences.json','Mesen.json','Mesen2.json')){Add-File (Join-Path $root $rel)};try{Get-ChildItem -LiteralPath $root -File -ErrorAction SilentlyContinue|Where-Object{$_.Name -match '(?i)(settings|config|preferences).*\\.(json|ini|cfg)$'}|Select-Object -First 20|ForEach-Object{Add-File $_.FullName}}catch{}}\n            'sameboy' {foreach($rel in @('sameboy.ini','SameBoy.ini','sameboy.cfg','preferences.ini','config.ini')){Add-File (Join-Path $root $rel)};try{Get-ChildItem -LiteralPath $root -File -ErrorAction SilentlyContinue|Where-Object{$_.Name -match '(?i)(sameboy|settings|config|preferences).*\\.(ini|cfg|json)$'}|Select-Object -First 20|ForEach-Object{Add-File $_.FullName}}catch{}}\n            'mgba' {foreach($rel in @('config.ini','mGBA.ini','mgba.ini','qt.ini')){Add-File (Join-Path $root $rel)};try{Get-ChildItem -LiteralPath $root -File -ErrorAction SilentlyContinue|Where-Object{$_.Name -match '(?i)(mgba|config|settings).*\\.(ini|cfg|json)$'}|Select-Object -First 20|ForEach-Object{Add-File $_.FullName}}catch{}}\n            'stella' {foreach($rel in @('stella.ini','settings.ini','config.ini')){Add-File (Join-Path $root $rel)}}\n"""
    if w.count(anchor)!=1:raise SystemExit('Wave2 explicit config anchor missing')
    w=w.replace(anchor,additions+anchor,1)
worker.write_text(w,encoding='utf-8')

# ---- main Platforms rail background count scan ----
lib=ROOT/'HuymaierNativeConsoleLibraryWorker.ps1'
l=lib.read_text(encoding='utf-8-sig')
if "'ATARI2600' { return @('.a26'" not in l:
    anchor="        'N64' { return @('.z64','.n64','.v64','.zip','.7z') }"
    additions="""        'ATARI2600' { return @('.a26','.bin','.rom','.zip') }\n        'NES' { return @('.nes','.fds','.unf','.unif','.zip') }\n        'SNES' { return @('.sfc','.smc','.fig','.swc','.zip') }\n        'GAMEBOY' { return @('.gb','.sgb','.zip') }\n        'GBC' { return @('.gbc','.gb','.zip') }\n        'GBA' { return @('.gba','.agb','.zip') }\n        'GENESIS' { return @('.md','.gen','.bin','.smd','.zip') }\n        'SEGACD' { return @('.cue','.chd','.iso','.bin') }\n        'SEGA32X' { return @('.32x','.bin','.md','.zip') }\n        'GAMEGEAR' { return @('.gg','.zip') }\n        'MASTERSYSTEM' { return @('.sms','.sg','.zip') }\n        'TURBOGRAFX16' { return @('.pce','.sgx','.cue','.chd','.zip') }\n"""
    if l.count(anchor)!=1:raise SystemExit('Wave2 library extension anchor missing')
    l=l.replace(anchor,additions+anchor,1)
lib.write_text(l,encoding='utf-8')

print('materialized Wave 2 latest-emulator install, settings discovery and library scanning')
