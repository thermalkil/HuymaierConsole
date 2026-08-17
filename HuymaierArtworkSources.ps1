# HUYMAIER_V0308_ARTWORK_SOURCES_V1
# Worker-side external artwork providers for Huymaier Console.
# This file is dot-sourced by HuymaierArtworkWorker.ps1 after config.json is loaded.
# TheGamesDB is the primary external matcher. The Cover Project is intentionally
# exposed only through user-curated mappings; this module never scrapes its site.

$script:HcArtworkFailurePath=Join-Path $CacheDir 'artwork-failures.json'
$script:HcArtworkProvenancePath=Join-Path $CacheDir 'artwork-provenance.json'
$script:HcTgdbPlatformCachePath=Join-Path $CacheDir 'thegamesdb-platforms.json'
$script:HcCoverProjectMappingPath=Join-Path $CacheDir 'cover-project-mappings.json'
$script:HcArtworkFailures=New-Object System.Collections.ArrayList
$script:HcArtworkProvenance=New-Object System.Collections.ArrayList
$script:HcTgdbPlatforms=$null

function Get-HcJsonEntries {
    param([string]$Path,[string]$Property='Entries')
    $items=New-Object System.Collections.ArrayList
    if(-not $Path -or -not (Test-Path -LiteralPath $Path -PathType Leaf)){return [object[]]$items.ToArray()}
    try{
        $payload=Get-Content -Raw -LiteralPath $Path -Encoding UTF8|ConvertFrom-Json
        $value=if($Property){Get-Prop $payload $Property @()}else{$payload}
        foreach($item in @(To-Array $value)){if($null -ne $item){[void]$items.Add($item)}}
    }catch{}
    return [object[]]$items.ToArray()
}
foreach($entry in @(Get-HcJsonEntries $script:HcArtworkFailurePath)){[void]$script:HcArtworkFailures.Add($entry)}
foreach($entry in @(Get-HcJsonEntries $script:HcArtworkProvenancePath)){[void]$script:HcArtworkProvenance.Add($entry)}

function Save-HcArtworkAuxiliaryState {
    try{Write-AtomicJson $script:HcArtworkFailurePath ([pscustomobject]@{Version=1;Updated=(Get-Date).ToString('o');Entries=[object[]]$script:HcArtworkFailures.ToArray()})}catch{}
    try{Write-AtomicJson $script:HcArtworkProvenancePath ([pscustomobject]@{Version=1;Updated=(Get-Date).ToString('o');Entries=[object[]]$script:HcArtworkProvenance.ToArray()})}catch{}
}

function Get-HcArtworkIdentity {
    param($Game)
    $source=[string](Get-Prop $Game 'Source' (Get-Prop $Game 'Provider' 'Game'))
    $id=[string](Get-Prop $Game 'Id' (Get-Prop $Game 'ProviderGameId' ''))
    if($id){return ($source.ToLowerInvariant()+'|id|'+$id.ToLowerInvariant())}
    return ($source.ToLowerInvariant()+'|name|'+(Normalize-Name ([string](Get-Prop $Game 'Name' ''))))
}
function Get-HcArtworkLookupKey {
    param($Game,[string]$ProviderName)
    return (($ProviderName.ToLowerInvariant())+'|'+(Get-HcArtworkIdentity $Game))
}
function Get-HcFailureEntry {
    param([string]$Key)
    foreach($entry in @($script:HcArtworkFailures)){if([string]::Equals([string](Get-Prop $entry 'Key' ''),$Key,[StringComparison]::OrdinalIgnoreCase)){return $entry}}
    return $null
}
function Test-HcArtworkLookupSuppressed {
    param([string]$Key)
    $entry=Get-HcFailureEntry $Key
    if($null -eq $entry){return $false}
    try{return ([datetime](Get-Prop $entry 'NextRetry' ([datetime]::MinValue)) -gt (Get-Date))}catch{return $false}
}
function Set-HcArtworkFailure {
    param([string]$Key,[string]$Reason,[int]$RetryHours=168)
    if(-not $Key){return}
    $attempts=1;$old=Get-HcFailureEntry $Key
    if($null -ne $old){try{$attempts=[int](Get-Prop $old 'Attempts' 0)+1}catch{$attempts=1}}
    $next=New-Object System.Collections.ArrayList
    foreach($entry in @($script:HcArtworkFailures)){if(-not [string]::Equals([string](Get-Prop $entry 'Key' ''),$Key,[StringComparison]::OrdinalIgnoreCase)){[void]$next.Add($entry)}}
    [void]$next.Add([pscustomobject]@{Key=$Key;Reason=$Reason;Attempts=$attempts;LastAttempt=(Get-Date).ToString('o');NextRetry=(Get-Date).AddHours([math]::Max(1,$RetryHours)).ToString('o')})
    $script:HcArtworkFailures=$next
}
function Clear-HcArtworkFailure {
    param([string]$Key)
    $next=New-Object System.Collections.ArrayList
    foreach($entry in @($script:HcArtworkFailures)){if(-not [string]::Equals([string](Get-Prop $entry 'Key' ''),$Key,[StringComparison]::OrdinalIgnoreCase)){[void]$next.Add($entry)}}
    $script:HcArtworkFailures=$next
}
function Set-HcArtworkProvenance {
    param($Game,[string]$Source,[string]$MatchedTitle,[string]$MatchedPlatform,[string]$SourceUrl,[string]$LocalPath,[double]$Confidence,[string]$SourceGameId='')
    if(-not $Game -or -not $LocalPath){return}
    $key=Get-HcArtworkIdentity $Game
    $next=New-Object System.Collections.ArrayList
    foreach($entry in @($script:HcArtworkProvenance)){if(-not [string]::Equals([string](Get-Prop $entry 'Key' ''),$key,[StringComparison]::OrdinalIgnoreCase)){[void]$next.Add($entry)}}
    [void]$next.Add([pscustomobject]@{
        Key=$key;GameId=[string](Get-Prop $Game 'Id' '');GameName=[string](Get-Prop $Game 'Name' '');Platform=[string](Get-Prop $Game 'Source' '');
        Source=$Source;MatchedTitle=$MatchedTitle;MatchedPlatform=$MatchedPlatform;SourceGameId=$SourceGameId;SourceUrl=$SourceUrl;LocalCachePath=$LocalPath;
        Confidence=[math]::Round([math]::Max(0.0,[math]::Min(1.0,$Confidence)),4);AssignedAt=(Get-Date).ToString('o')
    })
    $script:HcArtworkProvenance=$next
}

function Test-HcPlatformSpecificArtworkSource {
    param([string]$Source)
    $s=Normalize-Name $Source
    if(-not $s){return $false}
    if($s -match '^(steam|epic|epic games|gog|ea|ea app|ubisoft|battle net|battlenet|rockstar|amazon|amazon games|pc|windows|custom|generic|recomps)$'){return $false}
    return ($s -match 'playstation|^ps[1-5]$|psp|vita|xbox|gamecube|^wii|switch|nintendo|nes|snes|n64|game boy|dreamcast|saturn|genesis|mega drive|sega|atari|neo geo|turbografx|pc engine|arcade|mame|lynx|jaguar')
}

function Get-HcPlatformAliases {
    param($Game)
    $values=New-Object System.Collections.ArrayList
    foreach($value in @(
        [string](Get-Prop $Game 'Source' ''),[string](Get-Prop $Game 'Provider' ''),[string](Get-Prop $Game 'Platform' ''),
        [string](Get-Prop $Game 'PlatformName' ''),[string](Get-Prop $Game 'PlatformSlug' '')
    )){if($value){[void]$values.Add($value)}}
    $source=Normalize-Name ([string](Get-Prop $Game 'Source' ''))
    $extra=@()
    switch -Regex($source){
        '^ps1$|playstation 1|sony playstation$' {$extra=@('PlayStation','Sony PlayStation','PS1')}
        '^ps2$|playstation 2' {$extra=@('PlayStation 2','Sony PlayStation 2','PS2')}
        '^ps3$|playstation 3' {$extra=@('PlayStation 3','Sony PlayStation 3','PS3')}
        '^ps4$|playstation 4' {$extra=@('PlayStation 4','Sony PlayStation 4','PS4')}
        '^ps5$|playstation 5' {$extra=@('PlayStation 5','Sony PlayStation 5','PS5')}
        'psp|playstation portable' {$extra=@('PlayStation Portable','Sony PSP','PSP')}
        'vita|playstation vita' {$extra=@('PlayStation Vita','Sony PlayStation Vita','PS Vita')}
        '^xbox$|original xbox' {$extra=@('Xbox','Microsoft Xbox','Original Xbox')}
        'xbox 360|xbox360' {$extra=@('Xbox 360','Microsoft Xbox 360')}
        'xbox one' {$extra=@('Xbox One','Microsoft Xbox One')}
        'xbox series' {$extra=@('Xbox Series X/S','Xbox Series','Microsoft Xbox Series X/S')}
        'gamecube' {$extra=@('Nintendo GameCube','GameCube')}
        '^wii$|nintendo wii$' {$extra=@('Nintendo Wii','Wii')}
        'wii u|wiiu' {$extra=@('Nintendo Wii U','Wii U')}
        'switch' {$extra=@('Nintendo Switch','Switch')}
        '^nes$|nintendo entertainment' {$extra=@('Nintendo Entertainment System','NES')}
        '^snes$|super nintendo' {$extra=@('Super Nintendo Entertainment System','SNES','Super Nintendo')}
        '^n64$|nintendo 64' {$extra=@('Nintendo 64','N64')}
        'game boy advance|^gba$' {$extra=@('Nintendo Game Boy Advance','Game Boy Advance','GBA')}
        'game boy color|^gbc$' {$extra=@('Nintendo Game Boy Color','Game Boy Color','GBC')}
        '^game boy$|^gb$' {$extra=@('Nintendo Game Boy','Game Boy')}
        'nintendo ds|^nds$' {$extra=@('Nintendo DS','NDS')}
        'nintendo dsi|^dsi$' {$extra=@('Nintendo DSi','DSi')}
        '3ds|nintendo 3ds' {$extra=@('Nintendo 3DS','3DS')}
        'dreamcast' {$extra=@('Sega Dreamcast','Dreamcast')}
        'saturn' {$extra=@('Sega Saturn','Saturn')}
        'genesis|mega drive' {$extra=@('Sega Genesis','Sega Mega Drive','Genesis','Mega Drive')}
        'sega cd|mega cd' {$extra=@('Sega CD','Mega-CD','Mega CD')}
        '32x' {$extra=@('Sega 32X','32X')}
        'master system' {$extra=@('Sega Master System','Master System')}
        'game gear' {$extra=@('Sega Game Gear','Game Gear')}
        'atari 2600' {$extra=@('Atari 2600')}
        'atari 5200' {$extra=@('Atari 5200')}
        'atari 7800' {$extra=@('Atari 7800')}
        'atari lynx|^lynx$' {$extra=@('Atari Lynx','Lynx')}
        'jaguar' {$extra=@('Atari Jaguar','Jaguar')}
        'neo geo pocket color' {$extra=@('Neo Geo Pocket Color','SNK Neo Geo Pocket Color')}
        '^neo geo$' {$extra=@('Neo Geo','SNK Neo Geo')}
        'turbografx|pc engine' {$extra=@('TurboGrafx-16','PC Engine','NEC PC Engine')}
        'arcade|mame' {$extra=@('Arcade','MAME')}
        default {
            if($source -match 'steam|epic|gog|ea|ubisoft|battle net|rockstar|amazon|pc|windows|custom|generic|recomps'){$extra=@('PC','Microsoft Windows','Windows')}
        }
    }
    foreach($value in $extra){[void]$values.Add($value)}
    $seen=@{};$result=New-Object System.Collections.ArrayList
    foreach($value in @($values)){$n=Normalize-Name ([string]$value);if($n -and -not $seen.ContainsKey($n)){$seen[$n]=$true;[void]$result.Add($n)}}
    return [object[]]$result.ToArray()
}
function Get-HcPlatformScore {
    param($Game,[string]$CandidatePlatform)
    $candidate=Normalize-Name $CandidatePlatform
    $platformSpecific=Test-HcPlatformSpecificArtworkSource ([string](Get-Prop $Game 'Source' ''))
    if(-not $candidate){return $(if($platformSpecific){0.0}else{0.6})}
    foreach($alias in @(Get-HcPlatformAliases $Game)){
        if($candidate -eq $alias){return 1.0}
        if($candidate.Contains($alias) -or $alias.Contains($candidate)){return 0.92}
    }
    if(-not $platformSpecific -and $candidate -match 'pc|windows'){return 1.0}
    return $(if($platformSpecific){0.0}else{0.55})
}

function Get-HcTheGamesDbKey {
    try{$value=[string](Get-Prop $config 'TheGamesDbApiKey' '');if(-not [string]::IsNullOrWhiteSpace($value)){return $value.Trim()}}catch{}
    try{$value=[string]$env:HUYMAIER_THEGAMESDB_API_KEY;if(-not [string]::IsNullOrWhiteSpace($value)){return $value.Trim()}}catch{}
    return ''
}
function Get-HcTgdbPlatformCatalog {
    param([string]$ApiKey)
    if($null -ne $script:HcTgdbPlatforms){return [object[]]$script:HcTgdbPlatforms}
    $items=New-Object System.Collections.ArrayList
    try{
        if(Test-Path -LiteralPath $script:HcTgdbPlatformCachePath -PathType Leaf){
            $file=Get-Item -LiteralPath $script:HcTgdbPlatformCachePath
            if(((Get-Date)-$file.LastWriteTime).TotalDays -lt 30){
                $payload=Get-Content -Raw -LiteralPath $file.FullName -Encoding UTF8|ConvertFrom-Json
                foreach($p in @(Get-Prop $payload 'Platforms' @())){if($null -ne $p){[void]$items.Add($p)}}
                if($items.Count -gt 0){$script:HcTgdbPlatforms=[object[]]$items.ToArray();return [object[]]$script:HcTgdbPlatforms}
            }
        }
    }catch{}
    if(-not $ApiKey){$script:HcTgdbPlatforms=@();return @()}
    try{
        $url='https://api.thegamesdb.net/v1/Platforms?apikey='+[uri]::EscapeDataString($ApiKey)
        $response=Invoke-RestMethod -Uri $url -TimeoutSec 18 -Headers @{'User-Agent'='HuymaierConsole/0.30.8';'Accept'='application/json'}
        foreach($p in @(Get-Prop (Get-Prop $response 'data' $null) 'platforms' @())){
            $id=[string](Get-Prop $p 'id' '');$name=[string](Get-Prop $p 'name' (Get-Prop $p 'platform' ''))
            if($id -and $name){[void]$items.Add([pscustomobject]@{Id=$id;Name=$name;Normalized=(Normalize-Name $name)})}
        }
        if($items.Count -gt 0){Write-AtomicJson $script:HcTgdbPlatformCachePath ([pscustomobject]@{Updated=(Get-Date).ToString('o');Platforms=[object[]]$items.ToArray()})}
    }catch{}
    $script:HcTgdbPlatforms=[object[]]$items.ToArray();return [object[]]$script:HcTgdbPlatforms
}
function Get-HcTgdbPlatformName {
    param([string]$PlatformId,[object[]]$Catalog)
    if(-not $PlatformId){return ''}
    foreach($p in @($Catalog)){if([string]::Equals([string](Get-Prop $p 'Id' ''),$PlatformId,[StringComparison]::OrdinalIgnoreCase)){return [string](Get-Prop $p 'Name' '')}}
    return ''
}
function Invoke-HcTgdbNameRequest {
    param([string]$ApiKey,[string]$Name)
    $encodedName=[uri]::EscapeDataString($Name);$encodedKey=[uri]::EscapeDataString($ApiKey)
    $last=$null
    foreach($version in @('v1.1','v1')){
        try{
            $url="https://api.thegamesdb.net/$version/Games/ByGameName?apikey=$encodedKey&name=$encodedName&include=boxart&fields=platform"
            return Invoke-RestMethod -Uri $url -TimeoutSec 18 -Headers @{'User-Agent'='HuymaierConsole/0.30.8';'Accept'='application/json'}
        }catch{$last=$_}
    }
    if($null -ne $last){throw $last}
    return $null
}
function Get-HcObjectPropertyValue {
    param($Object,[string]$PropertyName)
    if($null -eq $Object -or -not $PropertyName){return $null}
    try{$p=$Object.PSObject.Properties[$PropertyName];if($null -ne $p){return $p.Value}}catch{}
    return $null
}
function Add-HcImageNodes {
    param([System.Collections.ArrayList]$Target,$Value)
    if($null -eq $Value){return}
    if($Value -is [string]){return}
    try{foreach($item in $Value){if($null -ne $item){[void]$Target.Add($item)}};return}catch{}
    [void]$Target.Add($Value)
}
function Get-HcTgdbImageNodes {
    param($Response,[string]$GameId)
    $nodes=New-Object System.Collections.ArrayList
    $extra=Get-Prop $Response 'extra' $null
    $box=Get-Prop $extra 'boxart' $null
    $boxData=Get-Prop $box 'data' $null
    if($null -ne $boxData){$specific=Get-HcObjectPropertyValue $boxData $GameId;if($null -ne $specific){Add-HcImageNodes $nodes $specific}else{Add-HcImageNodes $nodes $boxData}}
    $data=Get-Prop $Response 'data' $null
    $images=Get-Prop $data 'images' $null
    if($null -ne $images){$specific=Get-HcObjectPropertyValue $images $GameId;if($null -ne $specific){Add-HcImageNodes $nodes $specific}else{Add-HcImageNodes $nodes $images}}
    return [object[]]$nodes.ToArray()
}
function Get-HcTgdbBaseUrl {
    param($Response)
    $extra=Get-Prop $Response 'extra' $null
    foreach($holder in @((Get-Prop $extra 'boxart' $null),$extra,(Get-Prop (Get-Prop $Response 'data' $null) 'base_url' $null))){
        if($null -eq $holder){continue}
        $base=Get-Prop $holder 'base_url' $holder
        foreach($key in @('original','large','medium','small')){$value=[string](Get-Prop $base $key '');if($value){return $value}}
    }
    return 'https://cdn.thegamesdb.net/images/original/'
}
function Get-HcTgdbBestImage {
    param($Response,[string]$GameId)
    $best=$null;$bestRank=-1.0
    foreach($image in @(Get-HcTgdbImageNodes $Response $GameId)){
        if($null -eq $image){continue}
        $type=([string](Get-Prop $image 'type' (Get-Prop $image 'image_type' ''))).ToLowerInvariant()
        $side=([string](Get-Prop $image 'side' '')).ToLowerInvariant()
        $file=[string](Get-Prop $image 'filename' (Get-Prop $image 'url' ''))
        if(-not $file){continue}
        if($type -and $type -notmatch 'boxart|box art|cover'){continue}
        if($side -eq 'back'){continue}
        $width=0;$height=0;try{$width=[int](Get-Prop $image 'width' 0)}catch{};try{$height=[int](Get-Prop $image 'height' 0)}catch{}
        $rank=0.0;if($side -eq 'front'){$rank+=1000000};if($height -gt $width -and $height -gt 0){$rank+=200000};$rank+=[math]::Min(150000.0,[double]($width*$height)/10.0)
        if($rank -gt $bestRank){$bestRank=$rank;$best=$image}
    }
    if($null -eq $best){return $null}
    $file=[string](Get-Prop $best 'filename' (Get-Prop $best 'url' ''))
    $url=$file
    if($url -notmatch '^https?://'){$base=Get-HcTgdbBaseUrl $Response;if(-not $base.EndsWith('/')){$base+='/' };$url=$base+$file.TrimStart('/')}
    return [pscustomobject]@{Url=$url;Width=[int](Get-Prop $best 'width' 0);Height=[int](Get-Prop $best 'height' 0);Side=[string](Get-Prop $best 'side' '')}
}
function Get-HcTgdbImagesRequest {
    param([string]$ApiKey,[string]$GameId)
    $key=[uri]::EscapeDataString($ApiKey);$id=[uri]::EscapeDataString($GameId)
    foreach($url in @(
        "https://api.thegamesdb.net/v1/Games/Images?apikey=$key&games_id=$id&filter%5Bimage_type%5D=boxart",
        "https://api.thegamesdb.net/v1/Games/Images?apikey=$key&games_id=$id"
    )){try{return Invoke-RestMethod -Uri $url -TimeoutSec 18 -Headers @{'User-Agent'='HuymaierConsole/0.30.8';'Accept'='application/json'}}catch{}}
    return $null
}

function Try-HcTheGamesDbArt {
    param($Game,[string]$Target)
    $apiKey=Get-HcTheGamesDbKey;if(-not $apiKey){return $null}
    $name=[string](Get-Prop $Game 'Name' '');if(-not $name){return $null}
    $lookupKey=Get-HcArtworkLookupKey $Game 'TheGamesDB';if(Test-HcArtworkLookupSuppressed $lookupKey){return $null}
    $platformCatalog=@(Get-HcTgdbPlatformCatalog $apiKey)
    $best=$null;$bestScore=0.0;$bestTitleScore=0.0;$bestPlatformScore=0.0;$bestResponse=$null;$bestPlatform='';$bestId=''
    $variantIndex=0;$networkFailure=$false
    foreach($variant in @(Get-NameVariants $name|Select-Object -First 4)){
        $response=$null
        try{$response=Invoke-HcTgdbNameRequest $apiKey ([string]$variant)}catch{$networkFailure=$true;break}
        foreach($candidate in @(Get-Prop (Get-Prop $response 'data' $null) 'games' @())){
            if($null -eq $candidate){continue}
            $title=[string](Get-Prop $candidate 'game_title' (Get-Prop $candidate 'gameTitle' (Get-Prop $candidate 'title' (Get-Prop $candidate 'name' ''))))
            $id=[string](Get-Prop $candidate 'id' '')
            $platformValue=Get-Prop $candidate 'platform' '';$platformId='';$platformName=''
            if($platformValue -is [string] -or $platformValue -is [ValueType]){$platformId=[string]$platformValue;$platformName=Get-HcTgdbPlatformName $platformId $platformCatalog;if(-not $platformName -and $platformId -notmatch '^\d+$'){$platformName=$platformId}}
            else{$platformId=[string](Get-Prop $platformValue 'id' '');$platformName=[string](Get-Prop $platformValue 'name' '');if(-not $platformName){$platformName=Get-HcTgdbPlatformName $platformId $platformCatalog}}
            $titleScore=Get-NameScore $name $title;$platformScore=Get-HcPlatformScore $Game $platformName
            $score=($titleScore*0.78)+($platformScore*0.22)-([math]::Min(0.09,$variantIndex*0.03))
            if($score -gt $bestScore){$bestScore=$score;$bestTitleScore=$titleScore;$bestPlatformScore=$platformScore;$best=$candidate;$bestResponse=$response;$bestPlatform=$platformName;$bestId=$id}
        }
        if($bestScore -ge .97){break};$variantIndex++
    }
    if($networkFailure){Set-HcArtworkFailure $lookupKey 'NetworkOrApiError' 24;return $null}
    $platformSpecific=Test-HcPlatformSpecificArtworkSource ([string](Get-Prop $Game 'Source' ''))
    if($null -eq $best -or $bestTitleScore -lt .72 -or $bestScore -lt .80 -or ($platformSpecific -and $bestPlatformScore -lt .85)){
        Set-HcArtworkFailure $lookupKey $(if($null -eq $best){'NotFound'}else{'LowConfidence'}) $(if($null -eq $best){168}else{72});return $null
    }
    $image=Get-HcTgdbBestImage $bestResponse $bestId
    if($null -eq $image){$images=Get-HcTgdbImagesRequest $apiKey $bestId;if($null -ne $images){$image=Get-HcTgdbBestImage $images $bestId}}
    if($null -eq $image -or -not $image.Url){Set-HcArtworkFailure $lookupKey 'NoFrontBoxArt' 168;return $null}
    $path=Download-Art ([string]$image.Url) $Target
    if(-not $path){Set-HcArtworkFailure $lookupKey 'ImageDownloadFailed' 24;return $null}
    $matchedTitle=[string](Get-Prop $best 'game_title' (Get-Prop $best 'gameTitle' (Get-Prop $best 'title' (Get-Prop $best 'name' $name))))
    Clear-HcArtworkFailure $lookupKey
    Set-HcArtworkProvenance $Game 'TheGamesDB' $matchedTitle $bestPlatform ([string]$image.Url) $path $bestScore $bestId
    return [pscustomobject]@{Path=$path;Source='TheGamesDB';MatchedTitle=$matchedTitle;MatchedPlatform=$bestPlatform;SourceUrl=[string]$image.Url;Confidence=[math]::Round($bestScore,4);SourceGameId=$bestId}
}

function Get-HcCoverProjectMappings {
    $items=New-Object System.Collections.ArrayList
    foreach($entry in @(Get-HcJsonEntries $script:HcCoverProjectMappingPath)){if($null -ne $entry){[void]$items.Add($entry)}}
    return [object[]]$items.ToArray()
}
function Test-HcCoverProjectPlatformMatch {
    param($Game,[string]$MappingPlatform)
    if(-not $MappingPlatform){return $true}
    $mapping=Normalize-Name $MappingPlatform
    foreach($alias in @(Get-HcPlatformAliases $Game)){if($mapping -eq $alias -or $mapping.Contains($alias) -or $alias.Contains($mapping)){return $true}}
    return $false
}
function Try-HcCoverProjectMappingArt {
    param($Game,[string]$Target)
    $name=[string](Get-Prop $Game 'Name' '');if(-not $name){return $null};$wanted=Normalize-Name $name
    $best=$null
    foreach($entry in @(Get-HcCoverProjectMappings)){
        $source=[string](Get-Prop $entry 'Source' 'TheCoverProject');if($source -and $source -notmatch '(?i)the\s*cover\s*project|thecoverproject'){continue}
        $title=[string](Get-Prop $entry 'Title' (Get-Prop $entry 'Game' (Get-Prop $entry 'Name' '')));if((Normalize-Name $title) -ne $wanted){continue}
        $platform=[string](Get-Prop $entry 'Platform' '');if(-not (Test-HcCoverProjectPlatformMatch $Game $platform)){continue}
        $best=$entry;break
    }
    if($null -eq $best){return $null}
    $path=[string](Get-Prop $best 'LocalPath' '');if($path -and -not [IO.Path]::IsPathRooted($path)){$path=Join-Path $CacheDir $path}
    if($path -and -not (Test-ImageFile $path)){$path=''}
    $url=[string](Get-Prop $best 'Url' (Get-Prop $best 'SourceUrl' ''))
    if(-not $path -and $url){$path=Download-Art $url $Target}
    if(-not $path){return $null}
    $title=[string](Get-Prop $best 'MatchedTitle' (Get-Prop $best 'Title' $name));$platform=[string](Get-Prop $best 'MatchedPlatform' (Get-Prop $best 'Platform' ([string](Get-Prop $Game 'Source' ''))))
    Set-HcArtworkProvenance $Game 'TheCoverProject' $title $platform $url $path 1.0 ''
    return [pscustomobject]@{Path=$path;Source='TheCoverProject';MatchedTitle=$title;MatchedPlatform=$platform;SourceUrl=$url;Confidence=1.0;SourceGameId=''}
}
