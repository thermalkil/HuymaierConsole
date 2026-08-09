param(
    [Parameter(Mandatory=$true)][string]$ConfigPath,
    [Parameter(Mandatory=$true)][string]$ProviderCatalogPath,
    [Parameter(Mandatory=$true)][string]$CacheDir,
    [Parameter(Mandatory=$true)][string]$StatePath,
    [Parameter(Mandatory=$true)][string]$ResultPath,
    [string]$Platform=''
)

Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
New-Item -ItemType Directory -Force -Path $CacheDir|Out-Null

$workerMutex=$null
try{
    $workerMutex=New-Object System.Threading.Mutex($false,'Local\HuymaierConsoleArtworkWorker')
    $acquired=$workerMutex.WaitOne(0)
}catch [System.Threading.AbandonedMutexException]{$acquired=$true}catch{$acquired=$true}
if(-not $acquired){exit 0}

function Get-Prop{param($Object,[string]$Name,$Default=$null);if($null -eq $Object){return $Default};try{$p=$Object.PSObject.Properties[$Name];if($null -ne $p -and $null -ne $p.Value){return $p.Value}}catch{};return $Default}
function To-Array{param($Value);$list=New-Object System.Collections.ArrayList;if($null -ne $Value){try{foreach($item in $Value){[void]$list.Add($item)}}catch{[void]$list.Add($Value)}};return ,([object[]]$list.ToArray())}
function Write-AtomicJson{param([string]$Path,$Value);$tmp="$Path.tmp";ConvertTo-Json -InputObject $Value -Depth 20|Set-Content -LiteralPath $tmp -Encoding UTF8;Move-Item -LiteralPath $tmp -Destination $Path -Force}
function Write-State{param([bool]$Busy,[string]$Message,[int]$Progress=-1,[string]$Error='');Write-AtomicJson $StatePath ([pscustomobject]@{Busy=$Busy;Message=$Message;Progress=$Progress;Error=$Error;WorkerPid=$PID;Updated=(Get-Date).ToString('o')})}
function Normalize-Name{param([string]$Name);if(-not $Name){return ''};return (($Name.ToLowerInvariant() -replace '\([^)]*(usa|europe|world|japan|disc|disk|rev|beta|demo)[^)]*\)','' -replace '\[[^]]+\]','' -replace '[^a-z0-9]+',' ').Trim())}
function Safe-FileName{param([string]$Value);$safe=$Value -replace '[^a-zA-Z0-9._-]','_';if($safe.Length -gt 120){$safe=$safe.Substring(0,120)};return $safe}

function Get-NameVariants{
    param([string]$Name)
    $list=New-Object System.Collections.ArrayList
    foreach($candidate in @(
        $Name,
        ($Name -replace '\s*[\(\[].*?[\)\]]\s*',' '),
        ($Name -replace '(?i)\s*[-:]?\s*(game of the year|goty|complete|definitive|ultimate|deluxe|special|remastered|remaster|enhanced|anniversary|edition)\b.*$',''),
        ($Name -replace '(?i)\s*(disc|disk|cd)\s*\d+.*$','')
    )){
        $clean=($candidate -replace '\s+',' ').Trim()
        if($clean -and -not (@($list)|Where-Object{[string]::Equals([string]$_,$clean,[StringComparison]::OrdinalIgnoreCase)})){[void]$list.Add($clean)}
    }
    return [object[]]$list.ToArray()
}
function Get-TokenSet{param([string]$Value);$set=@{};foreach($token in ((Normalize-Name $Value)-split ' ')){if($token.Length -gt 1){$set[$token]=$true}};return $set}
function Get-NameScore{
    param([string]$Wanted,[string]$Candidate)
    $a=Normalize-Name $Wanted;$b=Normalize-Name $Candidate
    if(-not $a -or -not $b){return 0.0};if($a -eq $b){return 1.0}
    $sa=Get-TokenSet $a;$sb=Get-TokenSet $b;$intersection=0
    foreach($key in $sa.Keys){if($sb.ContainsKey($key)){$intersection++}}
    $union=@(@($sa.Keys)+@($sb.Keys)|Select-Object -Unique).Count
    $jaccard=if($union -gt 0){$intersection/[double]$union}else{0.0}
    $contains=if($a.Contains($b) -or $b.Contains($a)){0.18}else{0.0}
    $prefix=if($a.Length -ge 4 -and $b.Length -ge 4 -and $a.Substring(0,4) -eq $b.Substring(0,4)){0.08}else{0.0}
    return [math]::Min(1.0,$jaccard+$contains+$prefix)
}
function Get-UrlsRecursive{
    param($Object,[string]$Path='')
    $urls=New-Object System.Collections.ArrayList
    if($null -eq $Object){return [object[]]$urls.ToArray()}
    if($Object -is [string]){
        if($Object -match '^(https?:)?//' -or $Object -match '\.(jpg|jpeg|png|webp)(\?|$)'){[void]$urls.Add([pscustomobject]@{Url=[string]$Object;Path=$Path})}
        return [object[]]$urls.ToArray()
    }
    if($Object -is [System.Collections.IDictionary]){
        foreach($key in $Object.Keys){foreach($item in @(Get-UrlsRecursive $Object[$key] ($Path+'/'+[string]$key))){[void]$urls.Add($item)}}
        return [object[]]$urls.ToArray()
    }
    if($Object -is [System.Collections.IEnumerable]){
        $index=0
        foreach($node in $Object){foreach($item in @(Get-UrlsRecursive $node ($Path+'/'+$index))){[void]$urls.Add($item)};$index++}
        return [object[]]$urls.ToArray()
    }
    if($Object -is [pscustomobject]){
        foreach($prop in $Object.PSObject.Properties){foreach($item in @(Get-UrlsRecursive $prop.Value ($Path+'/'+$prop.Name))){[void]$urls.Add($item)}}
    }
    return [object[]]$urls.ToArray()
}

function Test-ImageFile{
    param([string]$Path)
    try{
        if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){return $false}
        $item=Get-Item -LiteralPath $Path
        if($item.Length -lt 1024){return $false}
        $bytes=[IO.File]::ReadAllBytes($Path)
        if($bytes.Length -lt 12){return $false}
        $jpg=($bytes[0]-eq 0xFF -and $bytes[1]-eq 0xD8)
        $png=($bytes[0]-eq 0x89 -and $bytes[1]-eq 0x50 -and $bytes[2]-eq 0x4E -and $bytes[3]-eq 0x47)
        $webp=([Text.Encoding]::ASCII.GetString($bytes,0,4)-eq 'RIFF' -and [Text.Encoding]::ASCII.GetString($bytes,8,4)-eq 'WEBP')
        return $jpg -or $png -or $webp
    }catch{return $false}
}

function Download-Art{
    param([string]$Url,[string]$Target)
    if(-not $Url){return ''}
    if($Url.StartsWith('//')){$Url='https:'+$Url}
    if(Test-ImageFile $Target){return $Target}
    try{
        Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $Target -TimeoutSec 20 -Headers @{'User-Agent'='Mozilla/5.0 HuymaierConsole/0.25'}
        if(Test-ImageFile $Target){return $Target}
    }catch{}
    Remove-Item -LiteralPath $Target -Force -ErrorAction SilentlyContinue
    return ''
}

function Find-LocalArtwork{
    param($Game)
    $roots=New-Object System.Collections.ArrayList
    foreach($value in @((Get-Prop $Game 'Path' ''),(Get-Prop $Game 'InstallPath' ''))){
        $path=[string]$value
        if($path){if(Test-Path -LiteralPath $path -PathType Leaf){$path=Split-Path -Parent $path};if(Test-Path -LiteralPath $path -PathType Container){[void]$roots.Add($path)}}
    }
    $preferred='(?i)(cover|box.?art|poster|portrait|library_600x900|capsule|keyart|tile|hero|artwork).*(jpg|jpeg|png|webp)$'
    foreach($root in $roots){
        foreach($name in @('cover.jpg','cover.png','cover.webp','boxart.jpg','boxart.png','poster.jpg','poster.png','folder.jpg','folder.png','library_600x900.jpg','library_600x900_2x.jpg','capsule_600x900.jpg','portrait.jpg')){
            $candidate=Join-Path $root $name;if(Test-ImageFile $candidate){return $candidate}
        }
        try{
            $files=New-Object System.Collections.ArrayList
            foreach($item in @(Get-ChildItem -LiteralPath $root -File -ErrorAction SilentlyContinue|Where-Object{$_.Name -match $preferred}|Sort-Object Length -Descending|Select-Object -First 30)){[void]$files.Add($item)}
            foreach($dir in @(Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue|Where-Object{$_.Name -match '(?i)(art|cover|image|media|asset|poster|icon)' }|Select-Object -First 12)){
                foreach($item in @(Get-ChildItem -LiteralPath $dir.FullName -File -ErrorAction SilentlyContinue|Where-Object{$_.Name -match $preferred}|Sort-Object Length -Descending|Select-Object -First 20)){[void]$files.Add($item)}
            }
            foreach($candidate in @($files|Sort-Object Length -Descending)){if($candidate -and (Test-ImageFile $candidate.FullName)){return $candidate.FullName}}
        }catch{}
    }
    return ''
}

function Get-LibretroRepository{
    param([string]$Source)
    switch -Regex(([string]$Source).ToLowerInvariant()){
        '^ps1$|playstation 1|sony.*playstation$' { return 'Sony_-_PlayStation' }
        '^ps2$|playstation 2' { return 'Sony_-_PlayStation_2' }
        '^psp$|playstation portable' { return 'Sony_-_PlayStation_Portable' }
        '^ps3$|playstation 3' { return 'Sony_-_PlayStation_3' }
        '^xbox$|original xbox|microsoft.*xbox$' { return 'Microsoft_-_Xbox' }
        '^xbox360$|xbox 360|microsoft.*xbox 360' { return 'Microsoft_-_Xbox_360' }
        '^gamecube$|nintendo gamecube' { return 'Nintendo_-_GameCube' }
        '^wii$|nintendo wii$' { return 'Nintendo_-_Wii' }
        '^wii u$' { return 'Nintendo_-_Wii_U' }
        '^switch$|nintendo switch' { return 'Nintendo_-_Nintendo_Switch' }
        '^dreamcast$' { return 'Sega_-_Dreamcast' }
        '^saturn$' { return 'Sega_-_Saturn' }
        '^genesis$|mega drive' { return 'Sega_-_Mega_Drive_-_Genesis' }
        '^snes$|super nintendo' { return 'Nintendo_-_Super_Nintendo_Entertainment_System' }
        '^nes$|nintendo entertainment' { return 'Nintendo_-_Nintendo_Entertainment_System' }
        '^n64$|nintendo 64' { return 'Nintendo_-_Nintendo_64' }
        '^gba$|game boy advance' { return 'Nintendo_-_Game_Boy_Advance' }
        '^gbc$|game boy color' { return 'Nintendo_-_Game_Boy_Color' }
        '^game boy$|^gb$' { return 'Nintendo_-_Game_Boy' }
        default { return '' }
    }
}

function Try-LibretroArt{
    param($Game,[string]$Target)
    $repo=Get-LibretroRepository ([string](Get-Prop $Game 'Source' ''))
    if(-not $repo){return ''}
    $name=[string](Get-Prop $Game 'Name' '')
    if(-not $name){return ''}
    $variants=New-Object System.Collections.ArrayList
    foreach($base in @(Get-NameVariants $name)){
        foreach($variant in @($base,"$base (USA)","$base (Europe)","$base (World)",($base -replace '&','and'),($base -replace ' and ',' & '))){
            if($variant -and -not (@($variants)|Where-Object{[string]::Equals([string]$_,[string]$variant,[StringComparison]::OrdinalIgnoreCase)})){[void]$variants.Add($variant)}
        }
    }
    $systemName=($repo -replace '_-_',' - ') -replace '_',' '
    $systemEncoded=[uri]::EscapeDataString([string]$systemName)
    foreach($variant in $variants){
        $encoded=[uri]::EscapeDataString([string]$variant).Replace('%2F','%2F')
        foreach($url in @(
            "https://thumbnails.libretro.com/$systemEncoded/Named_Boxarts/$encoded.png",
            "https://raw.githubusercontent.com/libretro-thumbnails/$repo/master/Named_Boxarts/$encoded.png"
        )){
            $found=Download-Art $url $Target
            if($found){return $found}
        }
    }
    return ''
}

function Try-SteamEquivalentArt{
    param($Game,[string]$Target)
    $id=[string](Get-Prop $Game 'Id' '')
    $launch=[string](Get-Prop $Game 'LaunchTarget' '')
    $appId=''
    if($id -match '^Steam:(\d+)$'){$appId=$matches[1]}
    elseif($launch -match 'rungameid/(\d+)'){$appId=$matches[1]}
    $name=[string](Get-Prop $Game 'Name' '')
    if(-not $appId -and $name){
        $bestScore=0.0;$bestId=''
        foreach($variant in @(Get-NameVariants $name)){
            try{
                $query=[uri]::EscapeDataString($variant)
                $search=Invoke-RestMethod -Uri "https://store.steampowered.com/api/storesearch/?term=$query&l=english&cc=US" -TimeoutSec 12 -Headers @{'User-Agent'='HuymaierConsole/0.25'}
                foreach($item in @(Get-Prop $search 'items' @())){
                    $score=Get-NameScore $name ([string](Get-Prop $item 'name' ''))
                    if($score -gt $bestScore){$bestScore=$score;$bestId=[string](Get-Prop $item 'id' '')}
                }
            }catch{}
            if($bestScore -ge .92){break}
        }
        if($bestScore -ge .48){$appId=$bestId}
    }
    if(-not $appId){return ''}
    foreach($url in @(
        "https://cdn.cloudflare.steamstatic.com/steam/apps/$appId/library_600x900_2x.jpg",
        "https://cdn.cloudflare.steamstatic.com/steam/apps/$appId/library_600x900.jpg",
        "https://cdn.cloudflare.steamstatic.com/steam/apps/$appId/capsule_616x353.jpg",
        "https://cdn.cloudflare.steamstatic.com/steam/apps/$appId/header.jpg"
    )){
        $found=Download-Art $url $Target
        if($found){return $found}
    }
    return ''
}

function Try-GogCatalogArt{
    param($Game,[string]$Target)
    $name=[string](Get-Prop $Game 'Name' '')
    if(-not $name){return ''}
    $best=$null;$bestScore=0.0
    foreach($variant in @(Get-NameVariants $name)){
        try{
            $query=[uri]::EscapeDataString('like:'+$variant)
            $response=Invoke-RestMethod -Uri "https://catalog.gog.com/v1/catalog?query=$query&limit=20&productType=in:game,pack&countryCode=US&locale=en-US&currencyCode=USD" -TimeoutSec 14 -Headers @{'User-Agent'='HuymaierConsole/0.25'}
            foreach($product in @((Get-Prop $response 'products' (Get-Prop $response 'items' @())))){
                $title=[string](Get-Prop $product 'title' (Get-Prop $product 'name' ''))
                $score=Get-NameScore $name $title
                if($score -gt $bestScore){$bestScore=$score;$best=$product}
            }
        }catch{}
        if($bestScore -ge .92){break}
    }
    if($null -eq $best -or $bestScore -lt .48){return ''}
    $candidates=@(Get-UrlsRecursive $best)|Sort-Object @{Expression={if($_.Path -match '(?i)(vertical|box|cover|product|tile)'){0}elseif($_.Path -match '(?i)(background|horizontal|hero)'){1}else{2}}},Path
    foreach($candidate in $candidates){$url=[string]$candidate.Url;if($url -and $url -notmatch '(?i)(logo|icon).*svg'){if($url.StartsWith('//')){$url='https:'+$url};$found=Download-Art $url $Target;if($found){return $found}}}
    return ''
}

function Try-WikipediaArt{
    param($Game,[string]$Target)
    $name=[string](Get-Prop $Game 'Name' '')
    if(-not $name){return ''}
    foreach($variant in @(Get-NameVariants $name)){
        try{
            $query=[uri]::EscapeDataString($variant+' video game')
            $url="https://en.wikipedia.org/w/api.php?action=query&generator=search&gsrsearch=$query&gsrlimit=5&prop=pageimages&piprop=thumbnail&pithumbsize=800&format=json&formatversion=2"
            $response=Invoke-RestMethod -Uri $url -TimeoutSec 14 -Headers @{'User-Agent'='HuymaierConsole/0.25 (local game library artwork)'}
            $pages=@(Get-Prop (Get-Prop $response 'query' $null) 'pages' @())
            $ranked=@()
            foreach($page in $pages){$score=Get-NameScore $name ([string](Get-Prop $page 'title' ''));$thumb=Get-Prop $page 'thumbnail' $null;$source=[string](Get-Prop $thumb 'source' '');if($source){$ranked+=[pscustomobject]@{Score=$score;Url=$source}}}
            foreach($item in @($ranked|Sort-Object Score -Descending)){if([double]$item.Score -ge .35){$found=Download-Art ([string]$item.Url) $Target;if($found){return $found}}}
        }catch{}
    }
    return ''
}


$artIndexPath=Join-Path $CacheDir 'artwork-index.tsv'
$artIndex=@{}
try{
    if(Test-Path -LiteralPath $artIndexPath -PathType Leaf){
        foreach($line in Get-Content -LiteralPath $artIndexPath -ErrorAction SilentlyContinue){
            $parts=[string]$line -split "`t",2
            if($parts.Count -eq 2 -and $parts[0] -and (Test-ImageFile $parts[1])){$artIndex[$parts[0]]=$parts[1]}
        }
    }
}catch{}
function Get-ArtIndexKey{param([string]$Source,[string]$Name);return (([string]$Source).ToLowerInvariant()+'|'+(Normalize-Name $Name))}
function Get-IndexedArt{
    param($Game)
    $name=[string](Get-Prop $Game 'Name' '');$source=[string](Get-Prop $Game 'Source' '')
    foreach($key in @((Get-ArtIndexKey $source $name),(Get-ArtIndexKey '*' $name))){if($key -and $artIndex.ContainsKey($key)){if(Test-ImageFile ([string]$artIndex[$key])){return [string]$artIndex[$key]}}}
    return ''
}
function Set-IndexedArt{
    param([string]$Source,[string]$Name,[string]$Path)
    if(-not $Name -or -not (Test-ImageFile $Path)){return}
    $artIndex[(Get-ArtIndexKey $Source $Name)]=$Path;$artIndex[(Get-ArtIndexKey '*' $Name)]=$Path
}
function Save-ArtIndex{
    try{
        $lines=New-Object System.Collections.ArrayList
        foreach($key in @($artIndex.Keys|Sort-Object)){if($key -and (Test-ImageFile ([string]$artIndex[$key]))){[void]$lines.Add($key+"`t"+[string]$artIndex[$key])}}
        $tmp=$artIndexPath+'.tmp';$lines|Set-Content -LiteralPath $tmp -Encoding UTF8;Move-Item -LiteralPath $tmp -Destination $artIndexPath -Force
    }catch{}
}
function Get-EsDePlatformAliases{
    param([string]$Source)
    switch -Regex(([string]$Source).ToLowerInvariant()){
        '^xbox$|original xbox' {return @('xbox','xboxclassic')}
        'xbox.?360' {return @('xbox360')}
        '^ps3$|playstation 3' {return @('ps3')}
        '^ps2$|playstation 2' {return @('ps2')}
        '^ps1$|playstation 1|playstation$' {return @('psx','ps1')}
        'gamecube' {return @('gc','gamecube')}
        '^wii$' {return @('wii')}
        'wii u' {return @('wiiu')}
        'switch' {return @('switch')}
        'n64|nintendo 64' {return @('n64')}
        'dreamcast' {return @('dreamcast')}
        default {return @()}
    }
}
function Try-EsDeMediaArt{
    param($Game)
    $name=[string](Get-Prop $Game 'Name' '');if(-not $name){return ''};$source=[string](Get-Prop $Game 'Source' '')
    $roots=New-Object System.Collections.ArrayList
    foreach($root in @((Join-Path $env:USERPROFILE 'ES-DE\downloaded_media'),(Join-Path $env:APPDATA 'ES-DE\downloaded_media'),(Join-Path $env:LOCALAPPDATA 'ES-DE\downloaded_media'))){if($root -and (Test-Path -LiteralPath $root -PathType Container)){[void]$roots.Add($root)}}
    $best='';$bestScore=0.0
    foreach($root in $roots){
        $platformDirs=@();$aliases=@(Get-EsDePlatformAliases $source)
        if($aliases.Count -gt 0){foreach($alias in $aliases){$candidate=Join-Path $root $alias;if(Test-Path -LiteralPath $candidate -PathType Container){$platformDirs+=$candidate}}}else{$platformDirs=@($root)}
        foreach($platformDir in $platformDirs){
            foreach($mediaName in @('covers','boxart','miximages','fanart')){
                $media=Join-Path $platformDir $mediaName;if(-not (Test-Path -LiteralPath $media -PathType Container)){continue}
                try{foreach($file in @(Get-ChildItem -LiteralPath $media -File -ErrorAction SilentlyContinue|Where-Object{$_.Extension -match '(?i)^\.(png|jpg|jpeg|webp)$'}|Select-Object -First 4000)){$score=Get-NameScore $name $file.BaseName;if($score -gt $bestScore){$bestScore=$score;$best=$file.FullName};if($score -ge .98){return $file.FullName}}}catch{}
            }
        }
    }
    if($bestScore -ge .72){return $best};return ''
}
function Try-BingImageArt{
    param($Game,[string]$Target)
    $name=[string](Get-Prop $Game 'Name' '');if(-not $name){return ''};$source=[string](Get-Prop $Game 'Source' 'video game')
    try{
        $query=[uri]::EscapeDataString('"'+$name+'" '+$source+' box art front cover')
        $html=(Invoke-WebRequest -UseBasicParsing -Uri ("https://www.bing.com/images/search?q="+$query+"&form=HDRSC3") -TimeoutSec 15 -Headers @{'User-Agent'='Mozilla/5.0 HuymaierConsole/0.25'}).Content
        $matches=[regex]::Matches($html,'(?i)"murl"\s*:\s*"(https?:\\/\\/[^"\\]+(?:\\.[^"\\]*)*)"')
        $tried=0
        foreach($m in $matches){
            if($tried -ge 8){break};$url=$m.Groups[1].Value -replace '\\/','/' -replace '\\u0026','&';if($url -notmatch '(?i)\.(jpg|jpeg|png|webp)(\?|$)'){continue};$tried++;$found=Download-Art $url $Target;if($found){return $found}
        }
    }catch{}
    return ''
}

try{
    Write-State $true 'Preparing online box-art scan...' 0
    if(-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)){throw 'The console configuration file was not found.'}
    $config=Get-Content -Raw -LiteralPath $ConfigPath|ConvertFrom-Json
    $gameList=New-Object System.Collections.ArrayList
    $providerMap=@{}
    $catalog=$null
    # Provider-owned games are scanned first. Their APIs usually expose the
    # highest-quality artwork URLs and those results can then be reused by the
    # locally installed copy of the same title later in this same batch.
    if(Test-Path -LiteralPath $ProviderCatalogPath -PathType Leaf){
        try{
            $catalog=Get-Content -Raw -LiteralPath $ProviderCatalogPath|ConvertFrom-Json
            foreach($node in @(Get-Prop $catalog 'Providers' @())){
                $providerId=[string](Get-Prop $node 'Id' '')
                if($Platform -and -not [string]::Equals($providerId,$Platform,[StringComparison]::OrdinalIgnoreCase)){continue}
                foreach($providerGame in @(Get-Prop $node 'Games' @())){
                    if($null -eq $providerGame){continue}
                    $providerGameId=[string](Get-Prop $providerGame 'Id' '')
                    $name=[string](Get-Prop $providerGame 'Name' '')
                    if(-not $providerGameId -or -not $name){continue}
                    $art=[string](Get-Prop $providerGame 'ArtworkPath' '')
                    $hero=[string](Get-Prop $providerGame 'HeroArtworkPath' '')
                    $nameKey=$providerId.ToLowerInvariant()+'|'+(Normalize-Name $name)
                    if($art -and (Test-ImageFile $art)){$providerMap[$nameKey]=$art}
                    [void]$gameList.Add([pscustomobject]@{
                        Id=($providerId+':'+$providerGameId);ProviderGameId=$providerGameId;Provider=$providerId;Source=$providerId;Name=$name;
                        ArtworkPath=$art;HeroArtworkPath=$hero;ArtworkUrl=[string](Get-Prop $providerGame 'ArtworkUrl' '');
                        HeroArtworkUrl=[string](Get-Prop $providerGame 'HeroArtworkUrl' (Get-Prop $providerGame 'BackgroundUrl' ''));
                        ImageUrl=[string](Get-Prop $providerGame 'ImageUrl' '');CoverUrl=[string](Get-Prop $providerGame 'CoverUrl' '');
                        Path=[string](Get-Prop $providerGame 'InstallPath' '');InstallPath=[string](Get-Prop $providerGame 'InstallPath' '')
                    })
                }
            }
        }catch{}
    }
    foreach($game in @(To-Array (Get-Prop $config 'ImportedGames' @()))){if($null -ne $game -and (-not $Platform -or [string]::Equals([string](Get-Prop $game 'Source' ''),$Platform,[StringComparison]::OrdinalIgnoreCase))){[void]$gameList.Add($game)}}
    foreach($game in @(To-Array (Get-Prop $config 'CustomGames' @()))){if($null -ne $game -and (-not $Platform -or [string]::Equals([string](Get-Prop $game 'Source' ''),$Platform,[StringComparison]::OrdinalIgnoreCase))){[void]$gameList.Add($game)}}
    $games=[object[]]$gameList.ToArray()

    $items=New-Object System.Collections.ArrayList
    $processed=0;$downloaded=0;$limit=60;$scanLimit=180;$cursor=0
    if(Test-Path -LiteralPath $ResultPath -PathType Leaf){
        try{$previous=Get-Content -Raw -LiteralPath $ResultPath|ConvertFrom-Json;if([string]::Equals([string](Get-Prop $previous 'Platform' ''),[string]$Platform,[StringComparison]::OrdinalIgnoreCase)){$cursor=[int](Get-Prop $previous 'NextIndex' 0)}else{$cursor=0}}catch{$cursor=0}
    }
    if($cursor -lt 0 -or $cursor -ge $games.Count){$cursor=0}
    $index=$cursor
    while($index -lt $games.Count -and $processed -lt $scanLimit -and $downloaded -lt $limit){
        $game=$games[$index];$index++
        if($null -eq $game){continue}
        $id=[string](Get-Prop $game 'Id' '')
        if(-not $id){$id=([string](Get-Prop $game 'Source' 'Game'))+':'+(Normalize-Name ([string](Get-Prop $game 'Name' '')))}
        $current=[string](Get-Prop $game 'ArtworkPath' '')
        $currentHero=[string](Get-Prop $game 'HeroArtworkPath' '')
        $needsArt=(-not $current -or -not (Test-ImageFile $current))
        $needsHero=(-not $currentHero -or -not (Test-ImageFile $currentHero))
        if(-not $needsArt -and -not $needsHero){continue}
        $processed++
        $source=[string](Get-Prop $game 'Source' '')
        $provider=[string](Get-Prop $game 'Provider' $source)
        $providerGameId=[string](Get-Prop $game 'ProviderGameId' '')
        $name=[string](Get-Prop $game 'Name' 'Game')
        Write-State $true "Finding artwork for $name..." ([math]::Min(95,5+[math]::Floor(($processed/[double]$scanLimit)*88)))
        $found=if($needsArt){Find-LocalArtwork $game}else{$current}
        if(-not $found){$found=Get-IndexedArt $game}
        if(-not $found){$found=Try-EsDeMediaArt $game}
        if(-not $found){
            $providerKey=$source.ToLowerInvariant()+'|'+(Normalize-Name $name)
            if($providerMap.ContainsKey($providerKey)){$found=[string]$providerMap[$providerKey]}
        }
        $safe=Safe-FileName $id
        $target=Join-Path $CacheDir "$safe.jpg"
        if(-not $found){
            foreach($property in @('ArtworkUrl','ImageUrl','CoverUrl','BoxArtUrl','IconUrl','CrownImageUrl')){
                $url=[string](Get-Prop $game $property '')
                if($url){$found=Download-Art $url $target;if($found){break}}
            }
        }
        if(-not $found){$found=Try-LibretroArt $game $target}
        if(-not $found -and $source -match '(?i)gog|pc|windows|custom|generic'){ $found=Try-GogCatalogArt $game $target }
        if(-not $found){$found=Try-SteamEquivalentArt $game $target}
        if(-not $found){$found=Try-WikipediaArt $game $target}
        if(-not $found){$found=Try-BingImageArt $game $target}

        $hero=$currentHero
        if($needsHero){
            $heroTarget=Join-Path $CacheDir ($safe+'_hero.jpg')
            foreach($property in @('HeroArtworkUrl','BackgroundUrl','BackgroundUrl1','BackgroundUrl2','HeroUrl')){
                $heroUrl=[string](Get-Prop $game $property '')
                if($heroUrl){$hero=Download-Art $heroUrl $heroTarget;if($hero){break}}
            }
            if(-not $hero -and $found){$hero=$found}
        }
        if($found){$providerKey=$source.ToLowerInvariant()+'|'+(Normalize-Name $name);$providerMap[$providerKey]=$found;Set-IndexedArt $source $name $found}
        if($found -or $hero){
            [void]$items.Add([pscustomobject]@{Id=$id;Provider=$provider;ProviderGameId=$providerGameId;ArtworkPath=$found;HeroArtworkPath=$hero;Name=$name;Source=$source})
            $downloaded++
        }
    }
    $hasMore=($index -lt $games.Count)
    $nextIndex=if($hasMore){$index}else{0}
    $remainingMissing=@($games|Where-Object{ -not ([string](Get-Prop $_ 'ArtworkPath' '')) -or -not (Test-ImageFile ([string](Get-Prop $_ 'ArtworkPath' ''))) }).Count
    $result=[pscustomobject]@{Platform=[string]$Platform;Items=[object[]]$items.ToArray();Downloaded=$downloaded;Scanned=$processed;Remaining=$remainingMissing;HasMore=$hasMore;NextIndex=$nextIndex;Updated=(Get-Date).ToString('o')}
    Save-ArtIndex
    Write-AtomicJson $ResultPath $result
    Write-State $false "Online box-art scan complete. $downloaded image(s) added." 100
}catch{
    Write-State $false 'Online box-art scan failed.' -1 $_.Exception.Message
    exit 1
}
