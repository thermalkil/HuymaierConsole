# HUYMAIER_V0308_TGDB_SCHEMA_V1
# TheGamesDB schema adapter overrides. The current API returns keyed platform/image
# objects and exposes included platform/boxart metadata under `include`.
# Loaded after HuymaierArtworkSources.ps1 so these definitions are authoritative.

function Get-HcTgdbKeyedValues {
    param($Value)
    $items=New-Object System.Collections.ArrayList
    if($null -eq $Value){return [object[]]$items.ToArray()}
    if($Value -is [System.Collections.IDictionary]){
        foreach($key in @($Value.Keys)){if($null -ne $Value[$key]){[void]$items.Add($Value[$key])}}
        return [object[]]$items.ToArray()
    }
    if($Value -is [System.Array] -or $Value -is [System.Collections.IList]){
        foreach($item in @($Value)){if($null -ne $item){[void]$items.Add($item)}}
        return [object[]]$items.ToArray()
    }
    try{
        if($null -ne $Value.PSObject.Properties['id']){[void]$items.Add($Value);return [object[]]$items.ToArray()}
        foreach($property in @($Value.PSObject.Properties)){
            if($null -ne $property -and $null -ne $property.Value){[void]$items.Add($property.Value)}
        }
    }catch{[void]$items.Add($Value)}
    return [object[]]$items.ToArray()
}

function ConvertTo-HcPlatformComparable {
    param([string]$Value)
    $normalized=Normalize-Name $Value
    return (($normalized -replace '^(sony|microsoft|nintendo|sega|nec|snk)\s+','').Trim())
}

function Get-HcPlatformScore {
    param($Game,[string]$CandidatePlatform)
    $candidate=Normalize-Name $CandidatePlatform
    $platformSpecific=Test-HcPlatformSpecificArtworkSource ([string](Get-Prop $Game 'Source' ''))
    if(-not $candidate){return $(if($platformSpecific){0.0}else{0.6})}
    $candidateComparable=ConvertTo-HcPlatformComparable $candidate
    foreach($alias in @(Get-HcPlatformAliases $Game)){
        $aliasNormalized=Normalize-Name ([string]$alias)
        if($candidate -eq $aliasNormalized){return 1.0}
        if($candidateComparable -and $candidateComparable -eq (ConvertTo-HcPlatformComparable $aliasNormalized)){return 0.98}
    }
    if(-not $platformSpecific -and $candidate -match '(^|\s)(pc|windows)(\s|$)'){return 1.0}
    return $(if($platformSpecific){0.0}else{0.55})
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
        $platforms=Get-Prop (Get-Prop $response 'data' $null) 'platforms' $null
        foreach($p in @(Get-HcTgdbKeyedValues $platforms)){
            $id=[string](Get-Prop $p 'id' '')
            $name=[string](Get-Prop $p 'name' (Get-Prop $p 'platform' ''))
            if($id -and $name){[void]$items.Add([pscustomobject]@{Id=$id;Name=$name;Normalized=(Normalize-Name $name);Comparable=(ConvertTo-HcPlatformComparable $name)})}
        }
        if($items.Count -gt 0){Write-AtomicJson $script:HcTgdbPlatformCachePath ([pscustomobject]@{Updated=(Get-Date).ToString('o');Platforms=[object[]]$items.ToArray()})}
    }catch{}
    $script:HcTgdbPlatforms=[object[]]$items.ToArray()
    return [object[]]$script:HcTgdbPlatforms
}

function Get-HcTgdbPlatformIdsForGame {
    param($Game,[object[]]$Catalog)
    $ids=New-Object System.Collections.ArrayList
    $seen=@{}
    $aliases=@(Get-HcPlatformAliases $Game)
    foreach($platform in @($Catalog)){
        $id=[string](Get-Prop $platform 'Id' '')
        $name=[string](Get-Prop $platform 'Name' '')
        if(-not $id -or -not $name){continue}
        $candidate=Normalize-Name $name
        $candidateComparable=ConvertTo-HcPlatformComparable $candidate
        $match=$false
        foreach($alias in $aliases){
            $aliasNormalized=Normalize-Name ([string]$alias)
            if($candidate -eq $aliasNormalized -or ($candidateComparable -and $candidateComparable -eq (ConvertTo-HcPlatformComparable $aliasNormalized))){$match=$true;break}
        }
        if($match -and -not $seen.ContainsKey($id)){$seen[$id]=$true;[void]$ids.Add($id)}
    }
    return [object[]]$ids.ToArray()
}

function Get-HcTgdbIncludedPlatformName {
    param($Response,[string]$PlatformId)
    if($null -eq $Response -or -not $PlatformId){return ''}
    $include=Get-Prop $Response 'include' $null
    $platformBlock=Get-Prop $include 'platform' $null
    foreach($holder in @((Get-Prop $platformBlock 'data' $null),$platformBlock)){
        if($null -eq $holder){continue}
        $node=Get-HcObjectPropertyValue $holder $PlatformId
        if($null -ne $node){$name=[string](Get-Prop $node 'name' '');if($name){return $name}}
    }
    return ''
}

function Invoke-HcTgdbNameRequest {
    param([string]$ApiKey,[string]$Name,[string]$PlatformFilter='')
    $encodedName=[uri]::EscapeDataString($Name)
    $encodedKey=[uri]::EscapeDataString($ApiKey)
    $filterArg=''
    if($PlatformFilter){$filterArg='&filter%5Bplatform%5D='+[uri]::EscapeDataString($PlatformFilter)}
    $last=$null
    foreach($version in @('v1.1','v1')){
        try{
            $url="https://api.thegamesdb.net/$version/Games/ByGameName?apikey=$encodedKey&name=$encodedName&include=boxart%2Cplatform&fields=platform$filterArg"
            return Invoke-RestMethod -Uri $url -TimeoutSec 18 -Headers @{'User-Agent'='HuymaierConsole/0.30.8';'Accept'='application/json'}
        }catch{$last=$_}
    }
    if($null -ne $last){throw $last}
    return $null
}

function Get-HcTgdbImageNodes {
    param($Response,[string]$GameId)
    $nodes=New-Object System.Collections.ArrayList
    $include=Get-Prop $Response 'include' $null
    $includeBox=Get-Prop $include 'boxart' $null
    $includeData=Get-Prop $includeBox 'data' $null
    if($null -ne $includeData){$specific=Get-HcObjectPropertyValue $includeData $GameId;if($null -ne $specific){Add-HcImageNodes $nodes $specific}}
    $extra=Get-Prop $Response 'extra' $null
    $box=Get-Prop $extra 'boxart' $null
    $boxData=Get-Prop $box 'data' $null
    if($null -ne $boxData){$specific=Get-HcObjectPropertyValue $boxData $GameId;if($null -ne $specific){Add-HcImageNodes $nodes $specific}}
    $data=Get-Prop $Response 'data' $null
    $images=Get-Prop $data 'images' $null
    if($null -ne $images){$specific=Get-HcObjectPropertyValue $images $GameId;if($null -ne $specific){Add-HcImageNodes $nodes $specific}}
    return [object[]]$nodes.ToArray()
}

function Get-HcTgdbBaseUrl {
    param($Response)
    $include=Get-Prop $Response 'include' $null
    $extra=Get-Prop $Response 'extra' $null
    foreach($holder in @(
        (Get-Prop (Get-Prop $include 'boxart' $null) 'base_url' $null),
        (Get-Prop (Get-Prop $extra 'boxart' $null) 'base_url' $null),
        (Get-Prop (Get-Prop $Response 'data' $null) 'base_url' $null)
    )){
        if($null -eq $holder){continue}
        foreach($key in @('original','large','medium','small','thumb')){$value=[string](Get-Prop $holder $key '');if($value){return $value}}
    }
    return 'https://cdn.thegamesdb.net/images/original/'
}

function Get-HcTgdbBestImage {
    param($Response,[string]$GameId)
    $best=$null;$bestRank=-1.0;$bestWidth=0;$bestHeight=0
    foreach($image in @(Get-HcTgdbImageNodes $Response $GameId)){
        if($null -eq $image){continue}
        $type=([string](Get-Prop $image 'type' (Get-Prop $image 'image_type' ''))).ToLowerInvariant()
        $side=([string](Get-Prop $image 'side' '')).ToLowerInvariant()
        $file=[string](Get-Prop $image 'filename' (Get-Prop $image 'url' ''))
        if(-not $file){continue}
        if($type -and $type -notmatch 'boxart|box art|cover'){continue}
        if($side -eq 'back'){continue}
        $width=0;$height=0
        try{$width=[int](Get-Prop $image 'width' 0)}catch{}
        try{$height=[int](Get-Prop $image 'height' 0)}catch{}
        if(($width -le 0 -or $height -le 0)){
            $resolution=[string](Get-Prop $image 'resolution' '')
            if($resolution -match '^(\d+)\s*[xX]\s*(\d+)$'){try{$width=[int]$Matches[1];$height=[int]$Matches[2]}catch{}}
        }
        $rank=0.0
        if($side -eq 'front'){$rank+=1000000}
        if($height -gt $width -and $height -gt 0){$rank+=200000}
        if($width -gt 0 -and $height -gt 0){$rank+=[math]::Min(150000.0,[double]($width*$height)/10.0)}
        if($rank -gt $bestRank){$bestRank=$rank;$best=$image;$bestWidth=$width;$bestHeight=$height}
    }
    if($null -eq $best){return $null}
    $file=[string](Get-Prop $best 'filename' (Get-Prop $best 'url' ''))
    $url=$file
    if($url -notmatch '^https?://'){$base=Get-HcTgdbBaseUrl $Response;if(-not $base.EndsWith('/')){$base+='/' };$url=$base+$file.TrimStart('/')}
    return [pscustomobject]@{Url=$url;Width=$bestWidth;Height=$bestHeight;Side=[string](Get-Prop $best 'side' '')}
}

function Try-HcTheGamesDbArt {
    param($Game,[string]$Target)
    $apiKey=Get-HcTheGamesDbKey
    if(-not $apiKey){return $null}
    $name=[string](Get-Prop $Game 'Name' '')
    if(-not $name){return $null}
    $lookupKey=Get-HcArtworkLookupKey $Game 'TheGamesDB'
    if(Test-HcArtworkLookupSuppressed $lookupKey){return $null}
    $platformCatalog=@(Get-HcTgdbPlatformCatalog $apiKey)
    $platformIds=@(Get-HcTgdbPlatformIdsForGame $Game $platformCatalog)
    $platformFilter=($platformIds -join ',')
    $platformSpecific=Test-HcPlatformSpecificArtworkSource ([string](Get-Prop $Game 'Source' ''))
    $best=$null;$bestScore=0.0;$bestTitleScore=0.0;$bestPlatformScore=0.0;$bestResponse=$null;$bestPlatform='';$bestId=''
    $variantIndex=0;$networkFailure=$false
    foreach($variant in @(Get-NameVariants $name|Select-Object -First 4)){
        $response=$null
        try{$response=Invoke-HcTgdbNameRequest $apiKey ([string]$variant) $platformFilter}catch{$networkFailure=$true;break}
        foreach($candidate in @(Get-Prop (Get-Prop $response 'data' $null) 'games' @())){
            if($null -eq $candidate){continue}
            $title=[string](Get-Prop $candidate 'game_title' (Get-Prop $candidate 'gameTitle' (Get-Prop $candidate 'title' (Get-Prop $candidate 'name' ''))))
            $id=[string](Get-Prop $candidate 'id' '')
            $platformValue=Get-Prop $candidate 'platform' '';$platformId='';$platformName=''
            if($platformValue -is [string] -or $platformValue -is [ValueType]){
                $platformId=[string]$platformValue
                $platformName=Get-HcTgdbIncludedPlatformName $response $platformId
                if(-not $platformName){$platformName=Get-HcTgdbPlatformName $platformId $platformCatalog}
                if(-not $platformName -and $platformId -notmatch '^\d+$'){$platformName=$platformId}
            }else{
                $platformId=[string](Get-Prop $platformValue 'id' '')
                $platformName=[string](Get-Prop $platformValue 'name' '')
                if(-not $platformName){$platformName=Get-HcTgdbIncludedPlatformName $response $platformId}
                if(-not $platformName){$platformName=Get-HcTgdbPlatformName $platformId $platformCatalog}
            }
            $titleScore=Get-NameScore $name $title
            $platformScore=Get-HcPlatformScore $Game $platformName
            $score=($titleScore*0.78)+($platformScore*0.22)-([math]::Min(0.09,$variantIndex*0.03))
            if($score -gt $bestScore){$bestScore=$score;$bestTitleScore=$titleScore;$bestPlatformScore=$platformScore;$best=$candidate;$bestResponse=$response;$bestPlatform=$platformName;$bestId=$id}
        }
        if($bestScore -ge .97){break}
        $variantIndex++
    }
    if($networkFailure){Set-HcArtworkFailure $lookupKey 'NetworkOrApiError' 24;return $null}
    if($null -eq $best -or $bestTitleScore -lt .72 -or $bestScore -lt .80 -or ($platformSpecific -and $bestPlatformScore -lt .85)){
        Set-HcArtworkFailure $lookupKey $(if($null -eq $best){'NotFound'}else{'LowConfidence'}) $(if($null -eq $best){168}else{72})
        return $null
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
