# Huymaier Console v0.26.2 Steam ownership-aware count adapter.
# Keeps the Games rail honest when Steam game-details privacy/network prevents a
# complete owned-library response: installed count remains accurate and the UI
# stops claiming a stale/incomplete owned total as authoritative.

$script:HcSteamOwnershipBaseCount=${function:Get-PlatformCountSummary}

function Get-PlatformCountSummary {
    param([string]$Platform)
    if(-not [string]::Equals($Platform,'Steam',[StringComparison]::OrdinalIgnoreCase)){
        return (& $script:HcSteamOwnershipBaseCount $Platform)
    }
    $installed=@(Get-PlatformGames 'Steam').Count
    try{
        $node=Get-ProviderCatalogNode 'Steam'
        $games=@(Get-EntryProperty $node 'Games' @())
        $attempted=[string](Get-EntryProperty $node 'OwnershipAttemptedAt' '')
        $complete=[bool](Get-EntryProperty $node 'OwnershipComplete' $false)
        if($complete){
            $fallbackOwned=@($games|Where-Object{[bool](Get-EntryProperty $_ 'Owned' $false)}).Count
            $owned=[int](Get-EntryProperty $node 'OwnedCount' $fallbackOwned)
            return [pscustomobject]@{Installed=$installed;Owned=$owned;Pending=$false}
        }
        if(-not $attempted){Request-HcSteamCatalogRefresh;return [pscustomobject]@{Installed=$installed;Owned=$installed;Pending=$true}}
        return [pscustomobject]@{Installed=$installed;Owned=$installed;Pending=$false}
    }catch{
        Request-HcSteamCatalogRefresh
        return [pscustomobject]@{Installed=$installed;Owned=$installed;Pending=$true}
    }
}
