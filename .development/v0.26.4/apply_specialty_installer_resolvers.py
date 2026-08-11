from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[2]
path=ROOT/'HuymaierEmulatorInstaller.ps1'
text=path.read_text(encoding='utf-8-sig')
start=text.find('function Install-BigPEmuLatest {')
end=text.find('\nfunction Install-StellaLatest {',start)
if start<0 or end<0:raise SystemExit('BigPEmu installer function boundaries missing')
replacement=r'''function Install-BigPEmuLatest {
    $pageUrl='https://www.richwhitehouse.com/jaguar/index.php?content=download'
    $page=Invoke-WebRequest -UseBasicParsing -Uri $pageUrl -Headers @{'User-Agent'='Huymaier-Console/0.26.4'}
    $html=[string]$page.Content
    # The official page labels the architecture next to each link. The x64 build
    # intentionally has no x64 token in its filename (BigPEmu_vNNNN.zip), while
    # ARM64 is named BigPEmu_WinARM64_vNNNN.zip. Resolve by the page label first.
    $architecture=[string]$env:PROCESSOR_ARCHITECTURE
    $wantArm=($architecture -match '(?i)ARM64')
    $labelPattern=$(if($wantArm){'Windows\s*\(ARM64\)'}else{'Windows\s*\(x64\)'})
    $pattern='(?is)'+$labelPattern+'.{0,1200}?href=["''](?<url>[^"'']*BigPEmu[^"'']*\.zip)["'']'
    $match=[regex]::Match($html,$pattern)
    if(-not $match.Success){
        $links=@([regex]::Matches($html,'(?i)href=["''](?<url>[^"'']*BigPEmu[^"'']*\.zip)["'']')|ForEach-Object{$_.Groups['url'].Value})
        if($wantArm){$href=@($links|Where-Object{$_ -match '(?i)WinARM64'}|Select-Object -First 1)}
        else{$href=@($links|Where-Object{$_ -notmatch '(?i)(ARM64|Linux|Android)' }|Select-Object -First 1)}
        if(-not $href){throw 'The current official BigPEmu Windows archive could not be identified from the BigPEmu download page.'}
        $href=[string]$href[0]
    }else{$href=$match.Groups['url'].Value}
    $href=[System.Net.WebUtility]::HtmlDecode([string]$href)
    if(-not $wantArm -and $href -match '(?i)ARM64'){throw 'The BigPEmu resolver selected an ARM64 archive on an x64 Windows host.'}
    if($wantArm -and $href -notmatch '(?i)ARM64'){throw 'The BigPEmu resolver did not select the ARM64 archive on an ARM64 Windows host.'}
    $url=$href;if($href -notmatch '^https?://'){$url=(New-Object Uri ([uri]$pageUrl),$href).AbsoluteUri}
    $target=Join-Path $DestinationRoot 'BigPEmu';$work=Join-Path $env:TEMP ('hc-bigpemu-'+[guid]::NewGuid().ToString('N'));New-Item -ItemType Directory -Force -Path $work|Out-Null
    try{
        $archive=Join-Path $work ([IO.Path]::GetFileName(([uri]$url).AbsolutePath));Invoke-WebRequest -UseBasicParsing -Headers $headers -Uri $url -OutFile $archive
        New-Item -ItemType Directory -Force -Path $target|Out-Null;Expand-HcArchive $archive $target
        $exe=Get-ChildItem -LiteralPath $target -Filter 'BigPEmu.exe' -File -Recurse -ErrorAction SilentlyContinue|Select-Object -First 1
        if(-not $exe){$exe=Get-ChildItem -LiteralPath $target -Filter 'bigpemu.exe' -File -Recurse -ErrorAction SilentlyContinue|Select-Object -First 1}
        if(-not $exe){throw 'BigPEmu.exe was not found after extraction.'}
        return $exe.FullName
    }finally{Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue}
}
'''
text=text[:start]+replacement+text[end:]
old="{ $_.name -match '(?i)(fbneo|finalburn).*(windows|win|x64|64).*\\.(zip|7z)$' -and $_.name -notmatch '(?i)(source|debug|symbols|pdb)' } 'FinalBurnNeo' @('fbneo.exe','FinalBurnNeo.exe')"
new="{ $_.name -ieq 'windows-x86_64.zip' -or ($_.name -match '(?i)(fbneo|finalburn).*(windows|win).*(x86_64|x64|64).*\\.(zip|7z)$' -and $_.name -notmatch '(?i)(source|debug|symbols|pdb)') } 'FinalBurnNeo' @('fbneo.exe','fbneo64.exe','FinalBurnNeo.exe','FinalBurnNeo64.exe','FinalBurn Neo.exe')"
count=text.count(old)
if count not in (0,2):raise SystemExit(f'Expected zero or two legacy FBNeo resolver filters, found {count}')
if count:text=text.replace(old,new)
# A nightly archive may rename the Windows executable without changing the
# official asset contract. For FinalBurnNeo only, resolve any shipped .exe whose
# filename clearly identifies FBNeo/FinalBurn, after the preferred exact names.
anchor='''        foreach($name in $ExecutableNames){$exe=Get-ChildItem -LiteralPath $target -Filter $name -File -Recurse -ErrorAction SilentlyContinue|Select-Object -First 1;if($exe){return $exe.FullName}}\n        throw "Installed $TargetName but its executable was not found."'''
replacement_anchor='''        foreach($name in $ExecutableNames){$exe=Get-ChildItem -LiteralPath $target -Filter $name -File -Recurse -ErrorAction SilentlyContinue|Select-Object -First 1;if($exe){return $exe.FullName}}\n        if($TargetName -eq 'FinalBurnNeo'){$exe=Get-ChildItem -LiteralPath $target -Filter '*.exe' -File -Recurse -ErrorAction SilentlyContinue|Where-Object{$_.Name -match '(?i)(fbneo|finalburn)' -and $_.Name -notmatch '(?i)(debug|test|benchmark|unins|setup)'}|Select-Object -First 1;if($exe){return $exe.FullName}}\n        throw "Installed $TargetName but its executable was not found."'''
if "if($TargetName -eq 'FinalBurnNeo')" not in text:
    if text.count(anchor)!=1:raise SystemExit('Install-GithubArchive executable resolution anchor missing')
    text=text.replace(anchor,replacement_anchor,1)
if "'FINALBURNNEO'" in text and "windows-x86_64.zip" not in text:raise SystemExit('FBNeo x86_64 resolver was not materialized')
path.write_text(text,encoding='utf-8-sig')
print('materialized architecture-correct BigPEmu and official FBNeo Windows x86_64 resolvers with archive-name fallback')
