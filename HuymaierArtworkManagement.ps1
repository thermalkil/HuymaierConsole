# HUYMAIER_V0308_ARTWORK_MANAGEMENT_V1
# Controller-safe UI helpers for artwork maintenance. Loaded before the game
# experience module so its Manage menu can call these functions without touching
# provider/storefront model rendering.

$script:HcCoverProjectMappingsPath=Join-Path $script:ArtworkCacheRoot 'cover-project-mappings.json'
$script:HcArtworkFailureCachePath=Join-Path $script:ArtworkCacheRoot 'artwork-failures.json'
$script:HcArtworkProvenanceCachePath=Join-Path $script:ArtworkCacheRoot 'artwork-provenance.json'
$script:HcArtworkIndexPath=Join-Path $script:ArtworkCacheRoot 'artwork-index.tsv'

function Initialize-HcArtworkManagement {
    try{
        if(-not (Test-Path -LiteralPath $script:HcCoverProjectMappingsPath -PathType Leaf)){
            [pscustomobject]@{
                Version=1
                Description='Optional curated mappings for The Cover Project. Add entries with Platform, Title, and either Url or LocalPath. Huymaier Console never scrapes The Cover Project automatically.'
                Entries=@()
            }|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $script:HcCoverProjectMappingsPath -Encoding UTF8
        }
    }catch{}
}
Initialize-HcArtworkManagement

function Test-HcArtworkCachePath {
    param([string]$Path)
    if(-not $Path){return $false}
    try{
        $root=[IO.Path]::GetFullPath($script:ArtworkCacheRoot).TrimEnd('\')+'\'
        $full=[IO.Path]::GetFullPath($Path)
        return $full.StartsWith($root,[StringComparison]::OrdinalIgnoreCase)
    }catch{return $false}
}
function Get-HcArtworkGameSource {
    param($Game)
    $source=[string](Get-EntryProperty $Game 'Provider' '')
    if(-not $source){$source=[string](Get-EntryProperty $Game 'Source' '')}
    if(-not $source){$source=[string]$script:SelectedGamePlatform}
    return $source
}
function Get-HcArtworkComparableId {
    param([string]$Value,[string]$Source='')
    if(-not $Value){return ''}
    $id=$Value.Trim().ToLowerInvariant()
    if($Source){$prefix=$Source.Trim().ToLowerInvariant()+':';if($id.StartsWith($prefix)){$id=$id.Substring($prefix.Length)}}
    return $id
}
function Test-HcArtworkGameMatch {
    param($Entry,$Game)
    if($null -eq $Entry -or $null -eq $Game){return $false}
    $source=Get-HcArtworkGameSource $Game
    $entrySource=[string](Get-EntryProperty $Entry 'Provider' (Get-EntryProperty $Entry 'Source' ''))
    if($entrySource -and $source -and -not [string]::Equals($entrySource,$source,[StringComparison]::OrdinalIgnoreCase)){return $false}
    $wantedId=Get-HcArtworkComparableId ([string](Get-EntryProperty $Game 'ProviderGameId' (Get-EntryProperty $Game 'Id' ''))) $source
    $entryId=Get-HcArtworkComparableId ([string](Get-EntryProperty $Entry 'ProviderGameId' (Get-EntryProperty $Entry 'Id' ''))) $source
    if($wantedId -and $entryId -and [string]::Equals($wantedId,$entryId,[StringComparison]::OrdinalIgnoreCase)){return $true}
    $wantedName=([string](Get-EntryProperty $Game 'Name' '')).ToLowerInvariant() -replace '[^a-z0-9]+',' '
    $entryName=([string](Get-EntryProperty $Entry 'Name' '')).ToLowerInvariant() -replace '[^a-z0-9]+',' '
    return ($wantedName.Trim() -and [string]::Equals($wantedName.Trim(),$entryName.Trim(),[StringComparison]::OrdinalIgnoreCase))
}
function Test-HcSelectedGameHasExternalArtwork {
    $game=Get-HcSelectedGame
    if($null -eq $game){return $false}
    return (Test-HcArtworkCachePath ([string](Get-EntryProperty $game 'ArtworkPath' '')))
}

function Start-HcSelectedGameArtworkRefresh {
    $game=Get-HcSelectedGame
    if($null -eq $game){Set-ConsoleNotice 'No game is selected.' 'WARN';return}
    $source=Get-HcArtworkGameSource $game
    $id=[string](Get-EntryProperty $game 'ProviderGameId' (Get-EntryProperty $game 'Id' ''))
    $name=[string](Get-EntryProperty $game 'Name' '')
    try{
        Start-OnlineArtworkScan -ResetCursor -Force -Platform $source -GameId $id -GameName $name
        Set-ConsoleNotice "Searching for cover art for $name in the background." 'INFO'
    }catch{Set-ConsoleNotice "Cover-art search could not start: $($_.Exception.Message)" 'ERROR'}
}
function Start-HcArtworkPlatformRefresh {
    $platform=[string]$script:SelectedGamePlatform
    if(-not $platform){Set-ConsoleNotice 'Choose a game platform first.' 'WARN';return}
    Start-OnlineArtworkScan -ResetCursor -Force -Platform $platform
    Set-ConsoleNotice "Missing cover art is being refreshed for $platform." 'INFO'
}
function Start-HcArtworkRetryUnresolved {
    try{Remove-Item -LiteralPath $script:HcArtworkFailureCachePath -Force -ErrorAction SilentlyContinue}catch{}
    Start-OnlineArtworkScan -ResetCursor -Force
    Set-ConsoleNotice 'Unresolved artwork failures were cleared and the background scan was restarted.' 'INFO'
}
function Open-HcArtworkCache {
    try{Start-UriOrShellTarget $script:ArtworkCacheRoot}catch{Set-ConsoleNotice 'The artwork cache folder could not be opened.' 'WARN'}
}

function Remove-HcArtworkIndexForGame {
    param($Game)
    if(-not (Test-Path -LiteralPath $script:HcArtworkIndexPath -PathType Leaf)){return}
    $name=[string](Get-EntryProperty $Game 'Name' '');if(-not $name){return}
    $normalized=(($name.ToLowerInvariant() -replace '\([^)]*(usa|europe|world|japan|disc|disk|rev|beta|demo)[^)]*\)','' -replace '\[[^]]+\]','' -replace '[^a-z0-9]+',' ').Trim())
    $source=(Get-HcArtworkGameSource $Game).ToLowerInvariant()
    try{
        $keep=New-Object System.Collections.ArrayList
        foreach($line in @(Get-Content -LiteralPath $script:HcArtworkIndexPath -ErrorAction SilentlyContinue)){
            $parts=[string]$line -split "`t",2
            if($parts.Count -ne 2){continue}
            $key=[string]$parts[0]
            if([string]::Equals($key,"$source|$normalized",[StringComparison]::OrdinalIgnoreCase) -or [string]::Equals($key,"*|$normalized",[StringComparison]::OrdinalIgnoreCase)){continue}
            [void]$keep.Add($line)
        }
        $tmp=$script:HcArtworkIndexPath+'.tmp';$keep|Set-Content -LiteralPath $tmp -Encoding UTF8;Move-Item -LiteralPath $tmp -Destination $script:HcArtworkIndexPath -Force
    }catch{}
}
function Remove-HcArtworkProvenanceForGame {
    param($Game)
    if(-not (Test-Path -LiteralPath $script:HcArtworkProvenanceCachePath -PathType Leaf)){return}
    try{
        $payload=Get-Content -Raw -LiteralPath $script:HcArtworkProvenanceCachePath -Encoding UTF8|ConvertFrom-Json
        $entries=New-Object System.Collections.ArrayList
        foreach($entry in @(Get-EntryProperty $payload 'Entries' @())){
            $sameName=[string]::Equals([string](Get-EntryProperty $entry 'GameName' ''),[string](Get-EntryProperty $Game 'Name' ''),[StringComparison]::OrdinalIgnoreCase)
            $platform=[string](Get-EntryProperty $entry 'Platform' '')
            $source=Get-HcArtworkGameSource $Game
            $sameSource=(-not $platform -or -not $source -or [string]::Equals($platform,$source,[StringComparison]::OrdinalIgnoreCase))
            if($sameName -and $sameSource){continue}
            [void]$entries.Add($entry)
        }
        [pscustomobject]@{Version=1;Updated=(Get-Date).ToString('o');Entries=[object[]]$entries.ToArray()}|ConvertTo-Json -Depth 12|Set-Content -LiteralPath ($script:HcArtworkProvenanceCachePath+'.tmp') -Encoding UTF8
        Move-Item -LiteralPath ($script:HcArtworkProvenanceCachePath+'.tmp') -Destination $script:HcArtworkProvenanceCachePath -Force
    }catch{}
}
function Clear-HcCachedArtworkFields {
    param($Entry)
    $changed=$false
    foreach($property in @('ArtworkPath','HeroArtworkPath')){
        $path=[string](Get-EntryProperty $Entry $property '')
        if($path -and (Test-HcArtworkCachePath $path)){
            if($Entry.PSObject.Properties[$property]){$Entry.$property=''}else{$Entry|Add-Member -NotePropertyName $property -NotePropertyValue ''}
            $changed=$true
        }
    }
    return $changed
}
function Reset-HcSelectedGameArtwork {
    $game=Get-HcSelectedGame
    if($null -eq $game){Set-ConsoleNotice 'No game is selected.' 'WARN';return}
    $changed=$false
    foreach($collectionName in @('ImportedGames','CustomGames','RecentGames')){
        foreach($entry in @($script:Config.$collectionName)){
            if(Test-HcArtworkGameMatch $entry $game){if(Clear-HcCachedArtworkFields $entry){$changed=$true}}
        }
    }
    if($changed){Save-Config}
    $provider=Get-HcArtworkGameSource $game
    $providerId=Get-HcArtworkComparableId ([string](Get-EntryProperty $game 'ProviderGameId' (Get-EntryProperty $game 'Id' ''))) $provider
    if($provider -and $providerId -and (Test-Path -LiteralPath $script:ProviderCatalogPath -PathType Leaf)){
        try{
            $catalog=Read-GameProviderCatalog;$providerChanged=$false
            foreach($node in @(Get-EntryProperty $catalog 'Providers' @())){
                if(-not [string]::Equals([string](Get-EntryProperty $node 'Id' ''),$provider,[StringComparison]::OrdinalIgnoreCase)){continue}
                foreach($entry in @(Get-EntryProperty $node 'Games' @())){
                    $entryId=Get-HcArtworkComparableId ([string](Get-EntryProperty $entry 'Id' '')) $provider
                    if([string]::Equals($entryId,$providerId,[StringComparison]::OrdinalIgnoreCase)){if(Clear-HcCachedArtworkFields $entry){$providerChanged=$true}}
                }
            }
            if($providerChanged){$tmp=$script:ProviderCatalogPath+'.artwork-revert.tmp';ConvertTo-Json -InputObject $catalog -Depth 30|Set-Content -LiteralPath $tmp -Encoding UTF8;Move-Item -LiteralPath $tmp -Destination $script:ProviderCatalogPath -Force;$script:ProviderCatalog=$catalog;$changed=$true}
        }catch{Write-Log "Artwork revert provider update failed: $($_.Exception.Message)" 'WARN'}
    }
    Remove-HcArtworkIndexForGame $game
    Remove-HcArtworkProvenanceForGame $game
    if(Test-HcArtworkCachePath ([string](Get-EntryProperty $game 'ArtworkPath' ''))){$game.ArtworkPath=''}
    if(Test-HcArtworkCachePath ([string](Get-EntryProperty $game 'HeroArtworkPath' ''))){$game.HeroArtworkPath=''}
    try{Clear-HcGameDataCache -DropPersistent}catch{}
    Set-ConsoleNotice $(if($changed){'External artwork was unlinked. Provider/default artwork is now preferred.'}else{'This game is already using provider/default artwork.'}) 'INFO'
    Render-Page
}
