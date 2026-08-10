from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
installer=ROOT/'HuymaierEmulatorInstaller.ps1'
p=installer.read_text(encoding='utf-8-sig')

def ponce(old,new,label):
    global p
    count=p.count(old)
    if count!=1:
        raise SystemExit(f'{label}: expected one match, found {count}')
    p=p.replace(old,new,1)

p=p.replace('Huymaier-Console/0.26.3','Huymaier-Console/0.26.4')

# Verify GitHub's release-asset digest when the API supplies one.
ponce(
    "        Invoke-WebRequest -UseBasicParsing -Headers $headers -Uri ([string]$asset.browser_download_url) -OutFile $archive\n        $stage=Join-Path $work 'stage';Expand-HcArchive $archive $stage",
    "        Invoke-WebRequest -UseBasicParsing -Headers $headers -Uri ([string]$asset.browser_download_url) -OutFile $archive\n        if($asset.PSObject.Properties['digest'] -and [string]$asset.digest -match '(?i)^sha256:(?<hash>[0-9a-f]{64})$'){\n            $actual=(Get-FileHash -Algorithm SHA256 -LiteralPath $archive).Hash.ToLowerInvariant()\n            if($actual -ne $matches['hash'].ToLowerInvariant()){throw \"The downloaded release asset failed SHA-256 verification: $($asset.name)\"}\n        }\n        $stage=Join-Path $work 'stage';Expand-HcArchive $archive $stage",
    'GitHub release digest verification'
)

# Never erase a managed emulator root before overlaying an update; portable user
# data/configs may legitimately live there.
p=p.replace("        Remove-Item -LiteralPath $target -Recurse -Force -ErrorAction SilentlyContinue\n        New-Item -ItemType Directory -Force -Path $target|Out-Null", "        New-Item -ItemType Directory -Force -Path $target|Out-Null")
p=p.replace("try{$archive=Join-Path $work $archiveName;Invoke-WebRequest -UseBasicParsing -Headers $headers -Uri $url -OutFile $archive;Remove-Item -LiteralPath $target -Recurse -Force -ErrorAction SilentlyContinue;Expand-HcArchive $archive $target;", "try{$archive=Join-Path $work $archiveName;Invoke-WebRequest -UseBasicParsing -Headers $headers -Uri $url -OutFile $archive;New-Item -ItemType Directory -Force -Path $target|Out-Null;Expand-HcArchive $archive $target;")

mednafen=r'''
function Install-MednafenLatest {
    $releasePage=Invoke-WebRequest -UseBasicParsing -Uri 'https://mednafen.github.io/releases/' -Headers @{'User-Agent'='Huymaier-Console/0.26.4'}
    $html=[string]$releasePage.Content
    $matches=[regex]::Matches($html,'(?i)href=["''](?<url>[^"'']*mednafen-(?<version>[0-9]+(?:\.[0-9]+)+)-win64\.zip)["'']')
    if($matches.Count -eq 0){throw 'The current official Mednafen 64-bit Windows release could not be identified.'}
    $href=[System.Net.WebUtility]::HtmlDecode($matches[0].Groups['url'].Value)
    $version=$matches[0].Groups['version'].Value
    $fileName="mednafen-$version-win64.zip"
    $url=$href
    if($href -notmatch '^https?://'){$url=(New-Object Uri ([uri]'https://mednafen.github.io/releases/'),$href).AbsoluteUri}
    $target=Join-Path $DestinationRoot 'Mednafen'
    $work=Join-Path $env:TEMP ('hc-mednafen-'+[guid]::NewGuid().ToString('N'));New-Item -ItemType Directory -Force -Path $work|Out-Null
    try{
        $archive=Join-Path $work $fileName
        Invoke-WebRequest -UseBasicParsing -Headers $headers -Uri $url -OutFile $archive
        try{
            $home=Invoke-WebRequest -UseBasicParsing -Uri 'https://mednafen.github.io/?lang=en' -Headers @{'User-Agent'='Huymaier-Console/0.26.4'}
            $pattern=[regex]::Escape($fileName)+'\s*(?:<[^>]+>|\s)*SHA-256:\s*(?<sha>[0-9a-fA-F]{64})'
            $shaMatch=[regex]::Match([string]$home.Content,$pattern,[Text.RegularExpressions.RegexOptions]::Singleline)
            if($shaMatch.Success){$actual=(Get-FileHash -Algorithm SHA256 -LiteralPath $archive).Hash.ToLowerInvariant();if($actual -ne $shaMatch.Groups['sha'].Value.ToLowerInvariant()){throw 'The official Mednafen archive failed SHA-256 verification.'}}
        }catch{if($_.Exception.Message -match 'failed SHA-256'){throw}}
        New-Item -ItemType Directory -Force -Path $target|Out-Null
        Expand-HcArchive $archive $target
        $exe=Get-ChildItem -LiteralPath $target -Filter 'mednafen.exe' -File -Recurse -ErrorAction SilentlyContinue|Select-Object -First 1
        if(-not $exe){throw 'mednafen.exe was not found after extraction.'}
        return $exe.FullName
    }finally{Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue}
}

'''
marker='function Install-EdenLatest {'
if 'function Install-MednafenLatest' not in p:
    if p.count(marker)!=1: raise SystemExit('Mednafen installer insertion anchor missing')
    p=p.replace(marker,mednafen+marker,1)

cases=r'''    '3DS' {$exe=Install-GithubArchive 'azahar-emu/azahar' { $_.name -match '(?i)azahar.*windows.*\.(zip|7z)$' -and $_.name -notmatch '(?i)(libretro|symbols|debug|pdb|source)' } 'Azahar' @('azahar.exe','Azahar.exe')}
    'NDS' {$exe=Install-GithubArchive 'melonDS-emu/melonDS' { $_.name -match '(?i)(windows|win).*(x86_64|x64|64).*\.(zip|7z)$' -or $_.name -match '(?i)melonDS.*windows.*\.(zip|7z)$' } 'melonDS' @('melonDS.exe')}
    'DSI' {$exe=Install-GithubArchive 'melonDS-emu/melonDS' { $_.name -match '(?i)(windows|win).*(x86_64|x64|64).*\.(zip|7z)$' -or $_.name -match '(?i)melonDS.*windows.*\.(zip|7z)$' } 'melonDS' @('melonDS.exe')}
    'DREAMCAST' {$exe=Install-GithubArchive 'flyinghead/flycast' { $_.name -match '(?i)(windows|win).*(x64|64).*\.(zip|7z)$' -or $_.name -match '(?i)flycast.*(windows|win).*\.(zip|7z)$' } 'Flycast' @('flycast.exe','Flycast.exe')}
    'SATURN' {$exe=Install-MednafenLatest}
    'PSP' {$exe=Install-GithubArchive 'hrydgard/ppsspp' { $_.name -match '(?i)PPSSPP.*Windows.*64.*\.zip$' -or $_.name -match '(?i)Windows64.*\.zip$' } 'PPSSPP' @('PPSSPPWindows64.exe','PPSSPPWindows.exe','PPSSPPQt.exe')}
'''
insert="    'N64' {$exe=Install-GithubArchive 'Rosalie241/RMG'"
if cases.strip() not in p:
    idx=p.find(insert)
    if idx<0: raise SystemExit('Wave1 installer switch insertion anchor missing')
    p=p[:idx]+cases+p[idx:]

installer.write_text(p,encoding='utf-8')

cs=ROOT/'Native'/'HuymaierConsole.ConsolePlatforms.cs'
c=cs.read_text(encoding='utf-8-sig')
old='''            else if (definition.Shell == "Switch") { AddExisting(roots, Path.Combine(app, "Ryujinx", "bis", "user", "save")); AddExisting(roots, Path.Combine(app, "Eden", "nand", "user", "save")); }
'''
new='''            else if (definition.Shell == "3DS")
            {
                string azaharData=settings.emulatorDataPath; AddExisting(roots, Path.Combine(azaharData,"sdmc")); AddExisting(roots, Path.Combine(azaharData,"nand")); AddExisting(roots,Path.Combine(app,"Azahar","sdmc")); AddExisting(roots,Path.Combine(app,"azahar","sdmc"));
            }
            else if (definition.Shell == "NDS")
            {
                AddExisting(roots, settings.emulatorDataPath); AddExisting(roots, Path.Combine(app,"melonDS")); AddExisting(roots, Path.Combine(local,"melonDS"));
            }
            else if (definition.Shell == "DSI")
            {
                AddExisting(roots, settings.emulatorDataPath); AddExisting(roots, Path.Combine(settings.emulatorDataPath,"NAND")); AddExisting(roots, Path.Combine(app,"melonDS")); AddExisting(roots, Path.Combine(local,"melonDS"));
            }
            else if (definition.Shell == "Dreamcast")
            {
                AddExisting(roots, settings.emulatorDataPath); AddExisting(roots, Path.Combine(exeRoot,"data")); AddExisting(roots, exeRoot); AddExisting(roots, Path.Combine(app,"flycast")); AddExisting(roots, Path.Combine(local,"flycast"));
            }
            else if (definition.Shell == "Saturn")
            {
                AddExisting(roots, Path.Combine(settings.emulatorDataPath,"sav")); AddExisting(roots, Path.Combine(exeRoot,"sav")); AddExisting(roots, Path.Combine(docs,"Mednafen","sav")); AddExisting(roots, Path.Combine(app,"Mednafen","sav"));
            }
            else if (definition.Shell == "PSP")
            {
                AddExisting(roots, Path.Combine(settings.emulatorDataPath,"PSP","SAVEDATA")); AddExisting(roots, Path.Combine(settings.emulatorDataPath,"memstick","PSP","SAVEDATA")); AddExisting(roots, Path.Combine(exeRoot,"memstick","PSP","SAVEDATA")); AddExisting(roots, Path.Combine(docs,"PPSSPP","PSP","SAVEDATA"));
            }
            else if (definition.Shell == "Switch") { AddExisting(roots, Path.Combine(app, "Ryujinx", "bis", "user", "save")); AddExisting(roots, Path.Combine(app, "Eden", "nand", "user", "save")); }
'''
if old not in c: raise SystemExit('Wave1 save-root insertion anchor missing')
c=c.replace(old,new,1)
cs.write_text(c,encoding='utf-8')
print('materialized Wave 1 latest-emulator install and storage roots')
