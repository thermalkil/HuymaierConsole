from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]

installer=ROOT/'HuymaierEmulatorInstaller.ps1'
p=installer.read_text(encoding='utf-8-sig')

bigpemu=r'''
function Install-BigPEmuLatest {
    $pageUrl='https://www.richwhitehouse.com/jaguar/index.php?content=download'
    $page=Invoke-WebRequest -UseBasicParsing -Uri $pageUrl -Headers @{'User-Agent'='Huymaier-Console/0.26.4'}
    $html=[string]$page.Content
    $matches=[regex]::Matches($html,'(?i)href=["''](?<url>[^"'']*BigPEmu[^"'']*(?:Win|Windows|x64|64)[^"'']*\.zip)["'']')
    if($matches.Count -eq 0){$matches=[regex]::Matches($html,'(?i)href=["''](?<url>[^"'']*BigPEmu[^"'']*\.zip)["'']')}
    if($matches.Count -eq 0){throw 'The current official BigPEmu Windows archive could not be identified from the BigPEmu download page.'}
    $href=[System.Net.WebUtility]::HtmlDecode($matches[0].Groups['url'].Value)
    $url=$href;if($href -notmatch '^https?://'){$url=(New-Object Uri ([uri]$pageUrl),$href).AbsoluteUri}
    $target=Join-Path $DestinationRoot 'BigPEmu';$work=Join-Path $env:TEMP ('hc-bigpemu-'+[guid]::NewGuid().ToString('N'));New-Item -ItemType Directory -Force -Path $work|Out-Null
    try{$archive=Join-Path $work 'BigPEmu-Windows.zip';Invoke-WebRequest -UseBasicParsing -Headers $headers -Uri $url -OutFile $archive;New-Item -ItemType Directory -Force -Path $target|Out-Null;Expand-HcArchive $archive $target;$exe=Get-ChildItem -LiteralPath $target -Filter 'BigPEmu.exe' -File -Recurse -ErrorAction SilentlyContinue|Select-Object -First 1;if(-not $exe){$exe=Get-ChildItem -LiteralPath $target -Filter 'bigpemu.exe' -File -Recurse -ErrorAction SilentlyContinue|Select-Object -First 1};if(-not $exe){throw 'BigPEmu.exe was not found after extraction.'};return $exe.FullName}finally{Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue}
}

'''
if 'function Install-BigPEmuLatest {' not in p:
    marker='function Install-StellaLatest {'
    if p.count(marker)!=1:raise SystemExit('BigPEmu installer insertion anchor missing')
    p=p.replace(marker,bigpemu+marker,1)

cases=r'''    'ATARILYNX' {$exe=Install-MednafenLatest}
    'NEOGEO' {$exe=Install-GithubArchive 'finalburnneo/FBNeo' { $_.name -match '(?i)(fbneo|finalburn).*(windows|win|x64|64).*\.(zip|7z)$' -and $_.name -notmatch '(?i)(source|debug|symbols|pdb)' } 'FinalBurnNeo' @('fbneo.exe','FinalBurnNeo.exe')}
    'NGPC' {$exe=Install-MednafenLatest}
    'JAGUAR' {$exe=Install-BigPEmuLatest}
    'PRIMEHACK' {$exe=Install-GithubArchive 'shiiion/dolphin' { $_.name -match '(?i)(primehack|dolphin).*(windows|win|x64|64).*\.(zip|7z)$' -and $_.name -notmatch '(?i)(source|symbols|pdb|debug)' } 'PrimeHack' @('PrimeHack.exe','DolphinQt2.exe','Dolphin.exe')}
'''
if "'ATARILYNX' {$exe=Install-MednafenLatest}" not in p:
    anchor="    'ATARI2600' {$exe=Install-StellaLatest}"
    idx=p.find(anchor)
    if idx<0:raise SystemExit('Wave3 installer cases anchor missing')
    p=p[:idx]+cases+p[idx:]
installer.write_text(p,encoding='utf-8')

worker=ROOT/'HuymaierEmulatorSettingsWorker.ps1'
w=worker.read_text(encoding='utf-8-sig')
if "'fbneo' {Add-Root" not in w:
    anchor="        'mesence' {Add-Root $roots $seen (Join-Path $app 'Mesen');Add-Root $roots $seen (Join-Path $app 'Mesen2');Add-Root $roots $seen (Join-Path $local 'Mesen');Add-Root $roots $seen (Join-Path $local 'Mesen2')}"
    add="""        'fbneo' {Add-Root $roots $seen (Join-Path $app 'FBNeo');Add-Root $roots $seen (Join-Path $local 'FBNeo');Add-Root $roots $seen (Join-Path $app 'FinalBurn Neo')}\n        'primehack' {Add-Root $roots $seen (Join-Path $app 'PrimeHack');Add-Root $roots $seen (Join-Path $local 'PrimeHack');Add-Root $roots $seen (Join-Path $docs 'PrimeHack');Add-Root $roots $seen (Join-Path $docs 'Dolphin Emulator')}\n        'bigpemu' {Add-Root $roots $seen (Join-Path $app 'BigPEmu');Add-Root $roots $seen (Join-Path $local 'BigPEmu')}\n"""
    if w.count(anchor)!=1:raise SystemExit('Wave3 settings roots anchor missing')
    w=w.replace(anchor,add+anchor,1)
if "'primehack' {foreach($rel" not in w:
    anchor="            'mesence' {foreach($rel in @('settings.json','Settings.json','config.json','preferences.json','Mesen.json','Mesen2.json')){Add-File (Join-Path $root $rel)};try{Get-ChildItem -LiteralPath $root -File -ErrorAction SilentlyContinue|Where-Object{$_.Name -match '(?i)(settings|config|preferences).*\\.(json|ini|cfg)$'}|Select-Object -First 20|ForEach-Object{Add-File $_.FullName}}catch{}}"
    add="""            'fbneo' {foreach($rel in @('config\\fbneo.ini','config\\fbneo.cfg','fbneo.ini','fbneo.cfg')){Add-File (Join-Path $root $rel)};try{Get-ChildItem -LiteralPath (Join-Path $root 'config') -File -ErrorAction SilentlyContinue|Where-Object{$_.Extension -match '(?i)^\\.(ini|cfg)$'}|Select-Object -First 80|ForEach-Object{Add-File $_.FullName}}catch{}}\n            'primehack' {foreach($rel in @('Config\\Dolphin.ini','Config\\GFX.ini','Config\\PrimeHack.ini','Config\\WiimoteNew.ini','Config\\Hotkeys.ini','Config\\Logger.ini','Dolphin.ini','GFX.ini','PrimeHack.ini')){Add-File (Join-Path $root $rel)}}\n            'bigpemu' {foreach($rel in @('BigPEmu.ini','bigpemu.ini','config.ini','settings.ini','config.json','settings.json')){Add-File (Join-Path $root $rel)};try{Get-ChildItem -LiteralPath $root -File -ErrorAction SilentlyContinue|Where-Object{$_.Name -match '(?i)(bigpemu|config|settings|profile).*\\.(ini|cfg|json)$'}|Select-Object -First 40|ForEach-Object{Add-File $_.FullName}}catch{}}\n"""
    if w.count(anchor)!=1:raise SystemExit('Wave3 config discovery anchor missing')
    w=w.replace(anchor,add+anchor,1)
worker.write_text(w,encoding='utf-8')

lib=ROOT/'HuymaierNativeConsoleLibraryWorker.ps1'
l=lib.read_text(encoding='utf-8-sig')
if "'ATARILYNX' { return @('.lnx'" not in l:
    anchor="        'ATARI2600' { return @('.a26','.bin','.rom','.zip') }"
    add="""        'ATARILYNX' { return @('.lnx','.lyx','.o','.zip') }\n        'NEOGEO' { return @('.zip','.7z','.neo') }\n        'NGPC' { return @('.ngc','.ngp','.npc','.zip') }\n        'JAGUAR' { return @('.j64','.jag','.rom','.bin','.abs','.cof','.zip') }\n        'PRIMEHACK' { return @('.iso','.rvz','.wbfs','.gcm','.ciso') }\n"""
    if l.count(anchor)!=1:raise SystemExit('Wave3 count-scanner anchor missing')
    l=l.replace(anchor,add+anchor,1)
lib.write_text(l,encoding='utf-8')
print('materialized Wave 3 emulator install, settings discovery and count scanning')
