# Huymaier Console v0.26.2 Steam owned-library enrichment.
# Dot-sourced inside HuymaierSteamWorker.ps1 after its core helper functions.
# Installed appmanifest data stays authoritative for install state. This layer
# only enriches the catalog with the signed-in account's visible owned library.

$script:HcSteamOwnershipBaseRefresh=${function:Refresh-SteamCatalog}

function Get-HcSteamSignedInUser {
    $fallback=''
    foreach($root in @(Get-SteamRoots)){
        $loginUsers=Join-Path ([string]$root) 'config\loginusers.vdf'
        if(-not(Test-Path -LiteralPath $loginUsers -PathType Leaf)){continue}
        try{
            $text=Get-Content -Raw -LiteralPath $loginUsers -Encoding UTF8
            foreach($match in [regex]::Matches($text,'(?s)"(7656119\d{10})"\s*\{(.*?)\n\s*\}')){
                $steamId=[string]$match.Groups[1].Value
                $block=[string]$match.Groups[2].Value
                if(-not $fallback){$fallback=$steamId}
                if($block -match '(?im)^\s*"MostRecent"\s+"1"\s*$'){return $steamId}
            }
        }catch{Write-LogLine "Steam loginusers.vdf could not be read: $($_.Exception.Message)" 'WARN'}
    }
    return $fallback
}

function Get-HcSteamCommunityOwnedLibrary {
    param([string]$SteamId)
    $result=[ordered]@{Available=$false;Private=$false;SteamId=$SteamId;Games=@();Error=''}
    if([string]::IsNullOrWhiteSpace($SteamId)){$result.Error='No signed-in SteamID was found in loginusers.vdf.';return [pscustomobject]$result}
    try{
        $uri="https://steamcommunity.com/profiles/$SteamId/games?tab=all&xml=1"
        $response=Invoke-WebRequest -UseBasicParsing -Uri $uri -TimeoutSec 12 -Headers @{'Accept'='application/xml,text/xml;q=0.9,*/*;q=0.8';'User-Agent'='HuymaierConsole/0.26.2'}
        if($null -eq $response -or [string]::IsNullOrWhiteSpace([string]$response.Content)){throw 'Steam Community returned an empty response.'}
        [xml]$xml=[string]$response.Content
        $privacy=[string]$xml.gamesList.privacyState
        if($privacy -and -not [string]::Equals($privacy,'public',[StringComparison]::OrdinalIgnoreCase)){
            $result.Private=$true;$result.Error="Steam game details are $privacy.";return [pscustomobject]$result
        }
        $items=New-Object System.Collections.ArrayList
        foreach($game in @($xml.gamesList.games.game)){
            if($null -eq $game){continue}
            $id=[string]$game.appID;$name=[string]$game.name
            if([string]::IsNullOrWhiteSpace($id) -or $id -notmatch '^\d+$' -or [string]::IsNullOrWhiteSpace($name)){continue}
            [void]$items.Add([pscustomobject]@{Id=$id;Name=$name})
        }
        # A public profile with zero games is still a successful authoritative
        # response; do not confuse that with a network/privacy failure.
        $result.Available=$true;$result.Games=[object[]]$items.ToArray();return [pscustomobject]$result
    }catch{
        $result.Error=$_.Exception.Message
        return [pscustomobject]$result
    }
}

function Merge-HcSteamOwnedLibrary {
    param([object[]]$InstalledOrKnown,$Ownership)
    $items=New-Object System.Collections.ArrayList;$index=@{}
    foreach($game in @($InstalledOrKnown)){
        if($null -eq $game){continue}
        $id=[string](Get-Prop $game 'Id' '')
        if($id -and -not $index.ContainsKey($id)){$index[$id]=$items.Count}
        [void]$items.Add($game)
    }
    if($null -eq $Ownership -or -not [bool](Get-Prop $Ownership 'Available' $false)){return [object[]]$items.ToArray()}
    $root='';foreach($candidate in @(Get-SteamRoots)){if(-not $root){$root=[string]$candidate}}
    foreach($owned in @(Get-Prop $Ownership 'Games' @())){
        $id=[string](Get-Prop $owned 'Id' '');$name=[string](Get-Prop $owned 'Name' '')
        if(-not $id -or -not $name -or $index.ContainsKey($id)){continue}
        $art=$(if($root){Get-SteamArtwork $root $id}else{''})
        [void]$items.Add([pscustomobject]@{
            Id=$id;Name=$name;Provider='Steam';Source='Steam';Installed=$false;
            InstallPath='';Path='';LaunchTarget=("steam://rungameid/"+$id);ArtworkPath=$art;
            Description='Owned Steam library title';SizeText='';InstallSizeBytes=[int64]0;
            UpdateAvailable=$false;BuildId=''
        })
        $index[$id]=$items.Count-1
    }
    return [object[]]$items.ToArray()
}

function Refresh-SteamCatalog {
    $baseGames=@(& $script:HcSteamOwnershipBaseRefresh)
    $node=Get-ExistingSteamNode
    $steamId=Get-HcSteamSignedInUser
    $ownership=Get-HcSteamCommunityOwnedLibrary $steamId
    $games=@(Merge-HcSteamOwnedLibrary $baseGames $ownership)
    if($null -eq $node){
        $node=[pscustomobject]@{Id='Steam';Name='Steam';Backend='Steam Client';SchemaVersion=1;ToolReady=$false;Authenticated=$false;ToolPath='';Status='Steam catalog initialized.';Error='';Games=@();Updated=(Get-Date).ToString('o')}
    }
    $installed=@($games|Where-Object{[bool](Get-Prop $_ 'Installed' $false)}).Count
    $complete=[bool](Get-Prop $ownership 'Available' $false)
    $status=if($complete){"$($games.Count) owned Steam game(s) loaded; $installed installed."}elseif([bool](Get-Prop $ownership 'Private' $false)){"$installed installed Steam game(s) loaded. Owned-library list is hidden by Steam game-details privacy."}else{"$installed installed Steam game(s) loaded. Owned-library list is currently unavailable; installed count remains authoritative."}
    $enriched=[pscustomobject]@{
        Id='Steam';Name='Steam';Backend='Steam Client';SchemaVersion=2;
        ToolReady=[bool](Get-Prop $node 'ToolReady' $false);Authenticated=[bool](Get-Prop $node 'Authenticated' $false);
        ToolPath=[string](Get-Prop $node 'ToolPath' '');Status=$status;Error='';Games=[object[]]$games;
        OwnershipComplete=$complete;OwnershipSource=$(if($complete){'Steam Community'}else{'Installed/known local cache'});
        OwnershipPrivate=[bool](Get-Prop $ownership 'Private' $false);OwnershipError=[string](Get-Prop $ownership 'Error' '');
        AccountSteamId=$steamId;OwnershipAttemptedAt=(Get-Date).ToString('o');Updated=(Get-Date).ToString('o')
    }
    Save-SteamNode $enriched
    if($complete){Write-LogLine "Steam owned-library enrichment loaded $($games.Count) owned title(s) for $steamId."}
    elseif([bool](Get-Prop $ownership 'Private' $false)){Write-LogLine 'Steam owned-library enrichment is unavailable because game-details privacy is not public.' 'WARN'}
    elseif([string](Get-Prop $ownership 'Error' '')){Write-LogLine ("Steam owned-library enrichment unavailable: "+[string](Get-Prop $ownership 'Error' '')) 'WARN'}
    return [object[]]$games
}
