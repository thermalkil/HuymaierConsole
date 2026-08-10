param([Parameter(Mandatory=$true)][string]$StageRoot,[Parameter(Mandatory=$true)][string]$ValidationPath)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'

$ownershipPath=Join-Path $StageRoot 'HuymaierSteamOwnership.ps1'
$ownershipRuntimePath=Join-Path $StageRoot 'HuymaierSteamOwnershipRuntime.ps1'
$workerPath=Join-Path $StageRoot 'HuymaierSteamWorker.ps1'
$providerRuntimePath=Join-Path $StageRoot 'HuymaierV0262ProviderRuntime.ps1'
foreach($path in @($ownershipPath,$ownershipRuntimePath,$workerPath,$providerRuntimePath)){if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "Steam ownership candidate payload is missing: $path"}}

$worker=Get-Content -Raw -LiteralPath $workerPath -Encoding UTF8
if($worker -notmatch [regex]::Escape("HuymaierSteamOwnership.ps1")){throw 'Steam worker does not load owned-library enrichment.'}
$providerRuntime=Get-Content -Raw -LiteralPath $providerRuntimePath -Encoding UTF8
if($providerRuntime -notmatch [regex]::Escape('HuymaierSteamOwnershipRuntime.ps1')){throw 'Shell provider runtime does not load ownership-aware Steam counts.'}
$ownership=Get-Content -Raw -LiteralPath $ownershipPath -Encoding UTF8
foreach($required in @('loginusers.vdf','steamcommunity.com/profiles/','$SteamId/games?tab=all&xml=1','privacyState','OwnershipComplete','OwnershipPrivate','OwnershipAttemptedAt','Installed/known local cache')){if($ownership -notmatch [regex]::Escape($required)){throw "Steam ownership enrichment invariant is missing: $required"}}
$ownershipRuntime=Get-Content -Raw -LiteralPath $ownershipRuntimePath -Encoding UTF8
foreach($required in @('OwnershipComplete','OwnershipAttemptedAt','Owned=$installed;Pending=$false','Request-HcSteamCatalogRefresh')){if($ownershipRuntime -notmatch [regex]::Escape($required)){throw "Steam ownership count fallback invariant is missing: $required"}}

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
    function Refresh-SteamCatalog {return @([pscustomobject]@{Id='10';Name='Installed Game';Provider='Steam';Source='Steam';Installed=$true;InstallPath='C:\FakeSteam\steamapps\common\Installed Game';Path='C:\FakeSteam\steamapps\common\Installed Game';LaunchTarget='steam://rungameid/10';ArtworkPath='';Description='Steam library title';SizeText='1 GB';InstallSizeBytes=[int64]1GB;UpdateAvailable=$false;BuildId='1'})}
    . $ownershipPath
    function Get-HcSteamSignedInUser {return '76561198000000000'}
    function Invoke-WebRequest {
        param([switch]$UseBasicParsing,[string]$Uri,[int]$TimeoutSec,$Headers)
        return [pscustomobject]@{Content='<gamesList><privacyState>public</privacyState><games><game><appID>10</appID><name>Installed Game</name></game><game><appID>20</appID><name>Owned Uninstalled Game</name></game></games></gamesList>'}
    }
    $games=@(Refresh-SteamCatalog)
    if($games.Count -ne 2){throw "Public Steam ownership merge returned $($games.Count) games instead of 2."}
    $installed=@($games|Where-Object{[string]$_.Id -eq '10'}|Select-Object -First 1)
    $owned=@($games|Where-Object{[string]$_.Id -eq '20'}|Select-Object -First 1)
    if($installed.Count -ne 1 -or -not [bool]$installed[0].Installed){throw 'Public Steam ownership merge lost installed appmanifest state.'}
    if($owned.Count -ne 1 -or [bool]$owned[0].Installed){throw 'Public Steam ownership merge did not add the uninstalled owned title correctly.'}
    if($null -eq $script:SavedSteamNode -or -not [bool]$script:SavedSteamNode.OwnershipComplete -or [bool]$script:SavedSteamNode.OwnershipPrivate){throw 'Public Steam ownership node was not marked complete.'}
    if([string]$owned[0].LaunchTarget -ne 'steam://rungameid/20'){throw 'Owned uninstalled Steam title has the wrong launch/install identity.'}

    function Invoke-WebRequest {
        param([switch]$UseBasicParsing,[string]$Uri,[int]$TimeoutSec,$Headers)
        return [pscustomobject]@{Content='<gamesList><privacyState>private</privacyState></gamesList>'}
    }
    $privateGames=@(Refresh-SteamCatalog)
    if($privateGames.Count -ne 1 -or -not [bool]$privateGames[0].Installed){throw 'Private Steam privacy fallback did not retain the authoritative installed title.'}
    if($null -eq $script:SavedSteamNode -or [bool]$script:SavedSteamNode.OwnershipComplete -or -not [bool]$script:SavedSteamNode.OwnershipPrivate){throw 'Private Steam game-details response was not represented as an incomplete/private ownership list.'}
    if(-not [string]$script:SavedSteamNode.OwnershipAttemptedAt){throw 'Private Steam privacy fallback did not record an ownership attempt, which would leave the Games card scanning forever.'}
}

$validation=Get-Content -Raw -LiteralPath $ValidationPath -Encoding UTF8|ConvertFrom-Json
$validation|Add-Member -NotePropertyName steamOwnedLibraryMergeGate -NotePropertyValue 'success' -Force
$validation|Add-Member -NotePropertyName steamPrivateFallbackGate -NotePropertyValue 'success' -Force
$validation|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $ValidationPath -Encoding UTF8
Write-Host 'v0.26.2 Steam owned-library behavior tests passed.'
