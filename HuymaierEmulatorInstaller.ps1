[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$PlatformId,
    [Parameter(Mandatory=$true)][string]$DestinationRoot,
    [string]$ConsoleRoot=''
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'

$PlatformId=$PlatformId.Trim().ToUpperInvariant()
$DestinationRoot=[IO.Path]::GetFullPath($DestinationRoot)
New-Item -ItemType Directory -Force -Path $DestinationRoot|Out-Null
if(-not $ConsoleRoot){$ConsoleRoot=Split-Path -Parent $MyInvocation.MyCommand.Path}
$ConsoleRoot=[IO.Path]::GetFullPath($ConsoleRoot)
$headers=@{'User-Agent'='Huymaier-Console/0.26.4';'Accept'='application/vnd.github+json'}

function Expand-HcArchive {
    param([Parameter(Mandatory=$true)][string]$Archive,[Parameter(Mandatory=$true)][string]$Destination)
    New-Item -ItemType Directory -Force -Path $Destination|Out-Null
    if($Archive -match '(?i)\.zip$'){
        Expand-Archive -LiteralPath $Archive -DestinationPath $Destination -Force
        return
    }
    $tar=Get-Command tar.exe -ErrorAction SilentlyContinue
    if($tar){& $tar.Source -xf $Archive -C $Destination;if($LASTEXITCODE -eq 0){return}}
    $seven=Get-Command 7z.exe -ErrorAction SilentlyContinue
    if(-not $seven){$seven=Get-Command 7za.exe -ErrorAction SilentlyContinue}
    if($seven){& $seven.Source x $Archive ('-o'+$Destination) -y|Out-Null;if($LASTEXITCODE -eq 0){return}}
    $portable7z=Join-Path $env:TEMP 'huymaier-7zr.exe'
    try{
        if(-not(Test-Path -LiteralPath $portable7z -PathType Leaf)){Invoke-WebRequest -UseBasicParsing -Headers $headers -Uri 'https://www.7-zip.org/a/7zr.exe' -OutFile $portable7z}
        & $portable7z x $Archive ('-o'+$Destination) -y|Out-Null
        if($LASTEXITCODE -eq 0){return}
    }catch{}
    throw "The downloaded archive could not be extracted: $Archive"
}

function Get-GithubReleaseAsset {
    param([string]$Repository,[scriptblock]$Filter)
    $release=Invoke-RestMethod -Headers $headers -Uri ("https://api.github.com/repos/{0}/releases/latest" -f $Repository)
    $asset=@($release.assets|Where-Object $Filter|Select-Object -First 1)
    if(-not $asset){throw "No supported Windows release asset was found for $Repository."}
    return $asset
}

function Install-GithubArchive {
    param([string]$Repository,[scriptblock]$Filter,[string]$TargetName,[string[]]$ExecutableNames)
    $asset=Get-GithubReleaseAsset $Repository $Filter
    $target=Join-Path $DestinationRoot $TargetName
    $work=Join-Path $env:TEMP ('hc-emu-'+[guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $work|Out-Null
    try{
        $archive=Join-Path $work ([string]$asset.name)
        Invoke-WebRequest -UseBasicParsing -Headers $headers -Uri ([string]$asset.browser_download_url) -OutFile $archive
        if($asset.PSObject.Properties['digest'] -and [string]$asset.digest -match '(?i)^sha256:(?<hash>[0-9a-f]{64})$'){
            $actual=(Get-FileHash -Algorithm SHA256 -LiteralPath $archive).Hash.ToLowerInvariant()
            if($actual -ne $matches['hash'].ToLowerInvariant()){throw "The downloaded release asset failed SHA-256 verification: $($asset.name)"}
        }
        $stage=Join-Path $work 'stage';Expand-HcArchive $archive $stage
        New-Item -ItemType Directory -Force -Path $target|Out-Null
        $roots=@(Get-ChildItem -LiteralPath $stage -Directory -ErrorAction SilentlyContinue)
        $source=$stage
        if($roots.Count -eq 1 -and @((Get-ChildItem -LiteralPath $stage -File -ErrorAction SilentlyContinue)).Count -eq 0){$source=$roots[0].FullName}
        Copy-Item -Path (Join-Path $source '*') -Destination $target -Recurse -Force
        foreach($name in $ExecutableNames){$exe=Get-ChildItem -LiteralPath $target -Filter $name -File -Recurse -ErrorAction SilentlyContinue|Select-Object -First 1;if($exe){return $exe.FullName}}
        if($TargetName -eq 'FinalBurnNeo'){$exe=Get-ChildItem -LiteralPath $target -Filter '*.exe' -File -Recurse -ErrorAction SilentlyContinue|Where-Object{$_.Name -match '(?i)(fbneo|finalburn)' -and $_.Name -notmatch '(?i)(debug|test|benchmark|unins|setup)'}|Select-Object -First 1;if($exe){return $exe.FullName}}
        throw "Installed $TargetName but its executable was not found."
    }finally{Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue}
}

function Install-DolphinLatest {
    $page=Invoke-WebRequest -UseBasicParsing -Uri 'https://dolphin-emu.org/download/' -Headers @{'User-Agent'='Huymaier-Console/0.26.4'}
    $html=[string]$page.Content
    $links=[regex]::Matches($html,'(?i)href=["''](?<url>[^"'']*dolphin-(?<version>[0-9A-Za-z._-]+)-x64\.7z)["'']')
    if($links.Count -eq 0){throw 'The current official Dolphin Windows x64 release link could not be identified.'}
    $href=[System.Net.WebUtility]::HtmlDecode($links[0].Groups['url'].Value)
    $url=$href
    if($href -notmatch '^https?://'){$url=(New-Object Uri ([uri]'https://dolphin-emu.org/download/'),$href).AbsoluteUri}
    $version=$links[0].Groups['version'].Value
    # Keep this literal naming convention visible for release validation.
    $archiveName="dolphin-$version-x64.7z"
    $target=Join-Path $DestinationRoot 'Dolphin'
    $work=Join-Path $env:TEMP ('hc-dolphin-'+[guid]::NewGuid().ToString('N'));New-Item -ItemType Directory -Force -Path $work|Out-Null
    try{$archive=Join-Path $work $archiveName;Invoke-WebRequest -UseBasicParsing -Headers $headers -Uri $url -OutFile $archive;New-Item -ItemType Directory -Force -Path $target|Out-Null;Expand-HcArchive $archive $target;$exe=Get-ChildItem -LiteralPath $target -Filter 'Dolphin.exe' -File -Recurse -ErrorAction SilentlyContinue|Select-Object -First 1;if(-not $exe){throw 'Dolphin.exe was not found after extraction.'};return $exe.FullName}finally{Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue}
}




function Install-MameLatest {
    $assets=Get-GithubLatestAssets 'mamedev/mame'
    $asset=@($assets|Where-Object{$_.name -match '(?i)^mame[0-9]+b?_64bit\.exe$' -or $_.name -match '(?i)mame.*64.*\.exe$'}|Select-Object -First 1)
    if(-not $asset){throw 'The latest official MAME GitHub release did not expose a 64-bit Windows self-extracting archive.'}
    $target=Join-Path $DestinationRoot 'MAME';$work=Join-Path $env:TEMP ('hc-mame-'+[guid]::NewGuid().ToString('N'));New-Item -ItemType Directory -Force -Path $work|Out-Null
    try{
        $archive=Join-Path $work ([string]$asset.name);Invoke-WebRequest -UseBasicParsing -Headers $headers -Uri ([string]$asset.browser_download_url) -OutFile $archive
        if($asset.PSObject.Properties['digest'] -and [string]$asset.digest -match '(?i)^sha256:(?<hash>[0-9a-f]{64})$'){$actual=(Get-FileHash -Algorithm SHA256 -LiteralPath $archive).Hash.ToLowerInvariant();if($actual -ne $matches['hash'].ToLowerInvariant()){throw 'The official MAME archive failed SHA-256 verification.'}}
        New-Item -ItemType Directory -Force -Path $target|Out-Null
        $process=Start-Process -FilePath $archive -ArgumentList @('-y',('-o'+$target)) -Wait -PassThru -WindowStyle Hidden
        if($process.ExitCode -ne 0){throw "MAME self-extractor exited with code $($process.ExitCode)."}
        $exe=Get-ChildItem -LiteralPath $target -Filter 'mame.exe' -File -Recurse -ErrorAction SilentlyContinue|Select-Object -First 1;if(-not $exe){$exe=Get-ChildItem -LiteralPath $target -Filter 'mame64.exe' -File -Recurse -ErrorAction SilentlyContinue|Select-Object -First 1};if(-not $exe){throw 'mame.exe was not found after extraction.'};return $exe.FullName
    }finally{Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue}
}

function Install-BigPEmuLatest {
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

function Install-EdenLatest {
    $release=Invoke-RestMethod -Headers @{'User-Agent'='Huymaier-Console/0.26.4'} -Uri 'https://git.eden-emu.dev/api/v1/repos/eden-emu/eden/releases/latest'
    $asset=@($release.assets|Where-Object{$_.name -match '(?i)(windows|win).*(x64|amd64).*\.(zip|7z)$' -or $_.name -match '(?i)(x64|amd64).*(windows|win).*\.(zip|7z)$'}|Select-Object -First 1)
    if(-not $asset){$asset=@($release.assets|Where-Object{$_.name -match '(?i)windows.*\.(zip|7z)$'}|Select-Object -First 1)}
    if(-not $asset){throw 'The latest Eden Windows archive could not be identified.'}
    $url=''
    if($asset.PSObject.Properties['browser_download_url'] -and $asset.browser_download_url){$url=[string]$asset.browser_download_url}
    elseif($asset.PSObject.Properties['url'] -and $asset.url){$url=[string]$asset.url}
    elseif($asset.PSObject.Properties['download_url'] -and $asset.download_url){$url=[string]$asset.download_url}
    if([string]::IsNullOrWhiteSpace($url)){throw 'The latest Eden release did not expose a downloadable Windows asset URL.'}
    $target=Join-Path $DestinationRoot 'Eden';$work=Join-Path $env:TEMP ('hc-eden-'+[guid]::NewGuid().ToString('N'));New-Item -ItemType Directory -Force -Path $work|Out-Null
    try{$archive=Join-Path $work ([string]$asset.name);Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $archive;Expand-HcArchive $archive $target;$exe=Get-ChildItem -LiteralPath $target -Filter 'eden.exe' -File -Recurse -ErrorAction SilentlyContinue|Select-Object -First 1;if(-not $exe){$exe=Get-ChildItem -LiteralPath $target -Filter 'Eden.exe' -File -Recurse -ErrorAction SilentlyContinue|Select-Object -First 1};if(-not $exe){throw 'Eden executable was not found after extraction.'};return $exe.FullName}finally{Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue}
}

$exe=''
switch($PlatformId){
    'PS1' {
        $script=Join-Path $ConsoleRoot 'Tools\Install-Latest-DuckStation.ps1';if(-not(Test-Path -LiteralPath $script)){throw 'Install-Latest-DuckStation.ps1 is missing.'}
        & $script -DestinationRoot $DestinationRoot
        $exe=Get-ChildItem -LiteralPath (Join-Path $DestinationRoot 'DuckStation') -Filter 'duckstation*.exe' -File -Recurse -ErrorAction SilentlyContinue|Select-Object -First 1 -ExpandProperty FullName
    }
    'PS2' {
        $script=Join-Path $ConsoleRoot 'Tools\Install-Latest-PCSX2.ps1';if(-not(Test-Path -LiteralPath $script)){throw 'Install-Latest-PCSX2.ps1 is missing.'}
        $dest=Join-Path $DestinationRoot 'PCSX2';& $script -Destination $dest
        $exe=Get-ChildItem -LiteralPath $dest -Filter 'pcsx2*.exe' -File -Recurse -ErrorAction SilentlyContinue|Select-Object -First 1 -ExpandProperty FullName
    }
    'PS3' {
        $script=Join-Path $ConsoleRoot 'Tools\Install-Latest-RPCS3.ps1';if(-not(Test-Path -LiteralPath $script)){throw 'Install-Latest-RPCS3.ps1 is missing.'}
        $dest=Join-Path $DestinationRoot 'RPCS3';& $script -Destination $dest
        $exe=Get-ChildItem -LiteralPath $dest -Filter 'rpcs3.exe' -File -Recurse -ErrorAction SilentlyContinue|Select-Object -First 1 -ExpandProperty FullName
    }
    'PS4' {$exe=Install-GithubArchive 'shadps4-emu/shadPS4' { $_.name -match '(?i)(windows|win).*(x64|64).*\.(zip|7z)$' -or $_.name -match '(?i)shadps4.*windows.*\.(zip|7z)$' } 'shadPS4' @('shadPS4.exe','shadps4.exe')}
    'VITA' {$exe=Install-GithubArchive 'Vita3K/Vita3K' { $_.name -match '(?i)(windows|win).*(x64|64).*\.(zip|7z)$' -or $_.name -match '(?i)Vita3K.*windows.*\.(zip|7z)$' } 'Vita3K' @('Vita3K.exe','vita3k.exe')}
    'ARCADE' {$exe=Install-MameLatest}
    'FINALBURNNEO' {$exe=Install-GithubArchive 'finalburnneo/FBNeo' { $_.name -ieq 'windows-x86_64.zip' -or ($_.name -match '(?i)(fbneo|finalburn).*(windows|win).*(x86_64|x64|64).*\.(zip|7z)$' -and $_.name -notmatch '(?i)(source|debug|symbols|pdb)') } 'FinalBurnNeo' @('fbneo.exe','fbneo64.exe','FinalBurnNeo.exe','FinalBurnNeo64.exe','FinalBurn Neo.exe')}
    'ATARILYNX' {$exe=Install-MednafenLatest}
    'NEOGEO' {$exe=Install-GithubArchive 'finalburnneo/FBNeo' { $_.name -ieq 'windows-x86_64.zip' -or ($_.name -match '(?i)(fbneo|finalburn).*(windows|win).*(x86_64|x64|64).*\.(zip|7z)$' -and $_.name -notmatch '(?i)(source|debug|symbols|pdb)') } 'FinalBurnNeo' @('fbneo.exe','fbneo64.exe','FinalBurnNeo.exe','FinalBurnNeo64.exe','FinalBurn Neo.exe')}
    'NGPC' {$exe=Install-MednafenLatest}
    'JAGUAR' {$exe=Install-BigPEmuLatest}
    'PRIMEHACK' {$exe=Install-GithubArchive 'shiiion/dolphin' { $_.name -match '(?i)(primehack|dolphin).*(windows|win|x64|64).*\.(zip|7z)$' -and $_.name -notmatch '(?i)(source|symbols|pdb|debug)' } 'PrimeHack' @('PrimeHack.exe','DolphinQt2.exe','Dolphin.exe')}
    'ATARI2600' {$exe=Install-StellaLatest}
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
    '3DS' {$exe=Install-GithubArchive 'azahar-emu/azahar' { $_.name -match '(?i)azahar.*windows.*\.(zip|7z)$' -and $_.name -notmatch '(?i)(libretro|symbols|debug|pdb|source)' } 'Azahar' @('azahar.exe','Azahar.exe')}
    'NDS' {$exe=Install-GithubArchive 'melonDS-emu/melonDS' { $_.name -match '(?i)(windows|win).*(x86_64|x64|64).*\.(zip|7z)$' -or $_.name -match '(?i)melonDS.*windows.*\.(zip|7z)$' } 'melonDS' @('melonDS.exe')}
    'DSI' {$exe=Install-GithubArchive 'melonDS-emu/melonDS' { $_.name -match '(?i)(windows|win).*(x86_64|x64|64).*\.(zip|7z)$' -or $_.name -match '(?i)melonDS.*windows.*\.(zip|7z)$' } 'melonDS' @('melonDS.exe')}
    'DREAMCAST' {$exe=Install-GithubArchive 'flyinghead/flycast' { $_.name -match '(?i)(windows|win).*(x64|64).*\.(zip|7z)$' -or $_.name -match '(?i)flycast.*(windows|win).*\.(zip|7z)$' } 'Flycast' @('flycast.exe','Flycast.exe')}
    'SATURN' {$exe=Install-MednafenLatest}
    'PSP' {$exe=Install-GithubArchive 'hrydgard/ppsspp' { $_.name -match '(?i)PPSSPP.*Windows.*64.*\.zip$' -or $_.name -match '(?i)Windows64.*\.zip$' } 'PPSSPP' @('PPSSPPWindows64.exe','PPSSPPWindows.exe','PPSSPPQt.exe')}
    'N64' {$exe=Install-GithubArchive 'Rosalie241/RMG' { $_.name -match '(?i)(windows|win).*(x64|64).*\.(zip|7z)$' -or $_.name -match '(?i)RMG.*Windows.*\.(zip|7z)$' } 'RMG' @('RMG.exe',"Rosalie's Mupen GUI.exe")}
    'GAMECUBE' {$exe=Install-DolphinLatest}
    'WII' {$exe=Install-DolphinLatest}
    'WIIU' {$exe=Install-GithubArchive 'cemu-project/Cemu' { $_.name -match '(?i)(windows|win).*(x64|64).*\.(zip|7z)$' -and $_.name -notmatch '(?i)(symbols|debug)' } 'Cemu' @('Cemu.exe')}
    'SWITCH' {$exe=Install-EdenLatest}
    'XBOX' {$exe=Install-GithubArchive 'xemu-project/xemu' { $_.name -match '(?i)windows-x86_64\.zip$' -and $_.name -notmatch '(?i)(dbg|pdb)' } 'xemu' @('xemu.exe')}
    'XBOX360' {$exe=Install-GithubArchive 'xenia-canary/xenia-canary' { $_.name -match '(?i)(windows|win).*\.zip$' -and $_.name -notmatch '(?i)(symbols|pdb|debug)' } 'XeniaCanary' @('xenia_canary.exe','xenia_canary_netplay.exe','xenia.exe')}
    default {throw "Unsupported emulator platform: $PlatformId"}
}
if(-not $exe -or -not(Test-Path -LiteralPath $exe -PathType Leaf)){throw "The emulator installation completed without a usable executable for $PlatformId."}
[pscustomobject]@{PlatformId=$PlatformId;Executable=[IO.Path]::GetFullPath($exe);DestinationRoot=$DestinationRoot}|ConvertTo-Json -Compress
