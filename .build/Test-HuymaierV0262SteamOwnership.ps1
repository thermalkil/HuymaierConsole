param([Parameter(Mandatory=$true)][string]$StageRoot,[Parameter(Mandatory=$true)][string]$ValidationPath)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'

$ownershipPath=Join-Path $StageRoot 'HuymaierSteamOwnership.ps1'
$ownershipRuntimePath=Join-Path $StageRoot 'HuymaierSteamOwnershipRuntime.ps1'
$workerPath=Join-Path $StageRoot 'HuymaierSteamWorker.ps1'
$providerRuntimePath=Join-Path $StageRoot 'HuymaierV0262ProviderRuntime.ps1'
foreach($path in @($ownershipPath,$ownershipRuntimePath,$workerPath,$providerRuntimePath)){if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "Steam ownership candidate payload is missing: $path"}}

$worker=Get-Content -Raw -LiteralPath $workerPath -Encoding UTF8
if($worker -notmatch [regex]::Escape('HuymaierSteamOwnership.ps1')){throw 'Steam worker does not load owned-library enrichment.'}
$providerRuntime=Get-Content -Raw -LiteralPath $providerRuntimePath -Encoding UTF8
if($providerRuntime -notmatch [regex]::Escape('HuymaierSteamOwnershipRuntime.ps1')){throw 'Shell provider runtime does not load ownership-aware Steam counts.'}
$ownership=Get-Content -Raw -LiteralPath $ownershipPath -Encoding UTF8
foreach($required in @('loginusers.vdf','steamcommunity.com/profiles/','$SteamId/games?tab=all&xml=1','privacyState','OwnershipComplete','OwnershipPrivate','OwnershipAttemptedAt','OwnedCount','Owned=$true','Installed/known local cache')){if($ownership -notmatch [regex]::Escape($required)){throw "Steam ownership enrichment invariant is missing: $required"}}
$ownershipRuntime=Get-Content -Raw -LiteralPath $ownershipRuntimePath -Encoding UTF8
foreach($required in @('OwnershipComplete','OwnershipAttemptedAt','OwnedCount','Owned=$installed;Pending=$false','Request-HcSteamCatalogRefresh')){if($ownershipRuntime -notmatch [regex]::Escape($required)){throw "Steam ownership count fallback invariant is missing: $required"}}

# Execute the owned-library merger against deterministic fake Steam responses.
# No real account, network, registry, or Steam installation is used in CI.
& {
    $script:SavedSteamNode=$null
    function Get-SteamRoots {return @('C:\FakeSteam')}
    function Write-LogLine {param([string]$Message,[string]$Level='INFO')}
    function Get-Prop {param($Object,[string]$Name,$Default=$null);if($null -eq $Object){return $Default};$p=$Object.PSObject.Properties[$Name];if($null -ne $p -and $null -ne $p.Value){return $p.Value};return $Default}
    function Get-SteamArtwork {param([string]$Root,[string]$Id);return ''}
    function Get-ExistingSteamNode {return [pscustomobject]@{ToolReady=$true;Authenticated=$true;ToolPath='C:\FakeSteam\steam.exe';Games=@()}}
    function Save-SteamNode {param($Node);$script:SavedSteamNode=$Node}
    # App 10 is installed and owned. App 30 is installed but deliberately absent
    # from the owned response, proving installed does not inflate OwnedCount.
    function Refresh-SteamCatalog {return @(
        [pscustomobject]@{Id='10';Name='Installed Owned Game';Provider='Steam';Source='Steam';Installed=$true;InstallPath='C:\FakeSteam\steamapps\common\Installed Owned Game';Path='C:\FakeSteam\steamapps\common\Installed Owned Game';LaunchTarget='steam://rungameid/10';ArtworkPath='';Description='Steam library title';SizeText='1 GB';InstallSizeBytes=[int64]1GB;UpdateAvailable=$false;BuildId='1'},
        [pscustomobject]@{Id='30';Name='Installed Not Owned';Provider='Steam';Source='Steam';Installed=$true;InstallPath='C:\FakeSteam\steamapps\common\Installed Not Owned';Path='C:\FakeSteam\steamapps\common\Installed Not Owned';LaunchTarget='steam://rungameid/30';ArtworkPath='';Description='Steam library title';SizeText='1 GB';InstallSizeBytes=[int64]1GB;UpdateAvailable=$false;BuildId='1'}
    )}
    . $ownershipPath
    function Get-HcSteamSignedInUser {return '76561198000000000'}
    function Invoke-WebRequest {
        param([switch]$UseBasicParsing,[string]$Uri,[int]$TimeoutSec,$Headers)
        return [pscustomobject]@{Content='<gamesList><privacyState>public</privacyState><games><game><appID>10</appID><name>Installed Owned Game</name></game><game><appID>20</appID><name>Owned Uninstalled Game</name></game></games></gamesList>'}
    }
    $games=@(Refresh-SteamCatalog)
    if($games.Count -ne 3){throw "Public Steam ownership merge returned $($games.Count) games instead of 3."}
    $installedOwned=@($games|Where-Object{[string]$_.Id -eq '10'}|Select-Object -First 1)
    $ownedUninstalled=@($games|Where-Object{[string]$_.Id -eq '20'}|Select-Object -First 1)
    $installedNotOwned=@($games|Where-Object{[string]$_.Id -eq '30'}|Select-Object -First 1)
    if($installedOwned.Count -ne 1 -or -not [bool]$installedOwned[0].Installed -or -not [bool]$installedOwned[0].Owned){throw 'Public Steam ownership merge did not mark the installed owned AppID correctly.'}
    if($ownedUninstalled.Count -ne 1 -or [bool]$ownedUninstalled[0].Installed -or -not [bool]$ownedUninstalled[0].Owned){throw 'Public Steam ownership merge did not add the uninstalled owned title correctly.'}
    if($installedNotOwned.Count -ne 1 -or -not [bool]$installedNotOwned[0].Installed){throw 'Installed non-owned app state was lost.'}
    if($installedNotOwned[0].PSObject.Properties['Owned'] -and [bool]$installedNotOwned[0].Owned){throw 'Installed non-owned app incorrectly inflated the Steam owned set.'}
    if($null -eq $script:SavedSteamNode -or -not [bool]$script:SavedSteamNode.OwnershipComplete -or [bool]$script:SavedSteamNode.OwnershipPrivate){throw 'Public Steam ownership node was not marked complete.'}
    if([int]$script:SavedSteamNode.OwnedCount -ne 2){throw "Steam OwnedCount was $($script:SavedSteamNode.OwnedCount) instead of authoritative owned AppID count 2."}
    if([string]$ownedUninstalled[0].LaunchTarget -ne 'steam://rungameid/20'){throw 'Owned uninstalled Steam title has the wrong launch/install identity.'}

    function Invoke-WebRequest {
        param([switch]$UseBasicParsing,[string]$Uri,[int]$TimeoutSec,$Headers)
        return [pscustomobject]@{Content='<gamesList><privacyState>private</privacyState></gamesList>'}
    }
    $privateGames=@(Refresh-SteamCatalog)
    if($privateGames.Count -ne 2 -or @($privateGames|Where-Object{[bool]$_.Installed}).Count -ne 2){throw 'Private Steam privacy fallback did not retain authoritative installed titles.'}
    if($null -eq $script:SavedSteamNode -or [bool]$script:SavedSteamNode.OwnershipComplete -or -not [bool]$script:SavedSteamNode.OwnershipPrivate){throw 'Private Steam game-details response was not represented as an incomplete/private ownership list.'}
    if([int]$script:SavedSteamNode.OwnedCount -ne 0){throw 'Private Steam privacy fallback published a false authoritative owned count.'}
    if(-not [string]$script:SavedSteamNode.OwnershipAttemptedAt){throw 'Private Steam privacy fallback did not record an ownership attempt, which would leave the Games card scanning forever.'}
}

$validation=Get-Content -Raw -LiteralPath $ValidationPath -Encoding UTF8|ConvertFrom-Json
$validation|Add-Member -NotePropertyName steamOwnedLibraryMergeGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName steamOwnedCountAccuracyGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName steamPrivateFallbackGate -NotePropertyValue 'success' -Force
$validation|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $ValidationPath -Encoding UTF8
Write-Host 'v0.26.2 Steam owned-library behavior and count-accuracy tests passed.'
