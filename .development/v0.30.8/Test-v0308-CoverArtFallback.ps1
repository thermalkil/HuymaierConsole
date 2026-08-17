param([string]$StageRoot='')
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
# HUYMAIER_V0308_COVER_ART_TEST_V1
if(-not $StageRoot){$StageRoot=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)}
$StageRoot=(Resolve-Path -LiteralPath $StageRoot).Path
function Assert([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message}}
function Text([string]$Relative){$path=Join-Path $StageRoot $Relative;Assert (Test-Path -LiteralPath $path -PathType Leaf) "Missing $Relative";return Get-Content -Raw -LiteralPath $path -Encoding UTF8}
function Assert-Parse([string]$Relative){$path=Join-Path $StageRoot $Relative;$tokens=$null;$errors=$null;[void][Management.Automation.Language.Parser]::ParseFile($path,[ref]$tokens,[ref]$errors);if($errors.Count){throw "$Relative failed PowerShell 5.1 parse: $($errors[0].Message)"}}
foreach($relative in @('HuymaierConsole.ps1','HuymaierArtworkWorker.ps1','HuymaierArtworkSources.ps1','HuymaierArtworkManagement.ps1','HuymaierGameExperience.ps1','HuymaierBootstrap.ps1')){Assert-Parse $relative}
$core=Text 'HuymaierConsole.ps1';$worker=Text 'HuymaierArtworkWorker.ps1';$sources=Text 'HuymaierArtworkSources.ps1';$management=Text 'HuymaierArtworkManagement.ps1';$game=Text 'HuymaierGameExperience.ps1';$bootstrap=Text 'HuymaierBootstrap.ps1'
Assert ($core.Contains('$script:AppVersion = ''0.30.8''')) 'Core version is not 0.30.8.'
Assert ($core.Contains('TheGamesDbApiKey')) 'TheGamesDB API key is not persisted in config.'
Assert ($core.Contains('''thegamesdb-key''')) 'TheGamesDB settings action is missing.'
Assert ($core.Contains('''artwork-retry-unresolved''')) 'Retry unresolved artwork action is missing.'
Assert ($core.Contains('''artwork-refresh-platform''')) 'Platform artwork refresh action is missing.'
Assert ($core.Contains('[string]$GameId='''''',[string]$GameName=''''''')) 'Single-game artwork scan parameters are missing.'
Assert ($core.Contains('HuymaierArtworkManagement.ps1')) 'Artwork management module is not loaded by the shell.'
Assert ($worker.Contains('HUYMAIER_V0308_COVER_ART_WORKER_V1')) 'Artwork worker transform marker is missing.'
Assert ($worker.Contains('Try-HcTheGamesDbArt')) 'TheGamesDB is not wired into the artwork worker.'
Assert ($worker.Contains('Try-HcCoverProjectMappingArt')) 'The Cover Project mapping provider is not wired into the artwork worker.'
Assert (-not $worker.Contains('if(-not $found){$found=Try-WikipediaArt $game $target}')) 'Wikipedia remains an automatic cover assignment path.'
Assert (-not $worker.Contains('if(-not $found){$found=Try-BingImageArt $game $target}')) 'Bing remains an automatic cover assignment path.'
$tgdbAt=$worker.IndexOf('Try-HcTheGamesDbArt');$tcpAt=$worker.IndexOf('Try-HcCoverProjectMappingArt');$libretroAt=$worker.IndexOf('Try-LibretroArt $game $target');Assert ($tgdbAt -ge 0 -and $tcpAt -gt $tgdbAt -and $libretroAt -gt $tcpAt) 'External source order is not TheGamesDB -> Cover Project -> structured legacy fallback.'
Assert ($worker.Contains('Test-HcPlatformSpecificArtworkSource')) 'Platform-safe cache keys are not active.'
Assert ($worker.Contains('Save-HcArtworkAuxiliaryState')) 'Artwork provenance/failure state is not persisted.'
Assert ($sources.Contains('https://api.thegamesdb.net/v1/Platforms')) 'TheGamesDB platform catalog endpoint is missing.'
Assert ($sources.Contains('/Games/ByGameName?apikey=')) 'TheGamesDB title search endpoint is missing.'
Assert ($sources.Contains('/Games/Images?apikey=')) 'TheGamesDB image endpoint is missing.'
Assert ($sources.Contains('NoFrontBoxArt')) 'Front-box-art rejection path is missing.'
Assert ($sources.Contains('LowConfidence')) 'Low-confidence rejection path is missing.'
Assert ($sources.Contains('artwork-failures.json')) 'Negative lookup cache is missing.'
Assert ($sources.Contains('artwork-provenance.json')) 'Artwork provenance store is missing.'
Assert ($sources.Contains('cover-project-mappings.json')) 'Curated Cover Project mapping store is missing.'
Assert (-not ($sources -match 'Invoke-(WebRequest|RestMethod)[^\r\n]+thecoverproject\.net')) 'The Cover Project must not be scraped automatically.'
Assert ($game.Contains('Search cover art')) 'Per-game Search cover art UX is missing.'
Assert ($game.Contains('Revert to provider / default')) 'Per-game artwork revert UX is missing.'
Assert ($game.Contains('Open artwork cache')) 'Per-game artwork cache UX is missing.'
Assert ($management.Contains('artwork-failures.json') -and $management.Contains('cover-project-mappings.json')) 'Artwork maintenance files are not exposed.'
Assert ($bootstrap.Contains('HuymaierArtworkSources.ps1') -and $bootstrap.Contains('HuymaierArtworkManagement.ps1')) 'New artwork modules are not in startup preflight.'
$manifest=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'manifest.json') -Encoding UTF8|ConvertFrom-Json;Assert ([string]$manifest.version -eq '0.30.8') 'manifest version is not 0.30.8.';Assert ([string]$manifest.baseVersion -eq '0.30.7') 'manifest baseVersion is not 0.30.7.'
$appx=Text 'FSEPackage\AppxManifest.xml';Assert ($appx.Contains('Version="0.30.8.0"')) 'FSE AppX version is not 0.30.8.0.'
$testCache=Join-Path $env:TEMP ('hc-art-test-'+[guid]::NewGuid().ToString('N'));New-Item -ItemType Directory -Force -Path $testCache|Out-Null
try{
    $CacheDir=$testCache;$config=[pscustomobject]@{TheGamesDbApiKey=''}
    function Get-Prop{param($Object,[string]$Name,$Default=$null);if($null -eq $Object){return $Default};$p=$Object.PSObject.Properties[$Name];if($null -eq $p -or $null -eq $p.Value){return $Default};return $p.Value}
    function To-Array{param($Value);if($null -eq $Value){return @()};return @($Value)}
    function Normalize-Name{param([string]$Name);if(-not $Name){return ''};return (($Name.ToLowerInvariant() -replace '[™®©]','' -replace '[^a-z0-9]+',' ').Trim())}
    function Get-NameVariants{param([string]$Name);return @($Name)}
    function Get-NameScore{param([string]$A,[string]$B);if((Normalize-Name $A) -eq (Normalize-Name $B)){return 1.0};return 0.0}
    function Write-AtomicJson{param([string]$Path,$Value);$Value|ConvertTo-Json -Depth 20|Set-Content -LiteralPath $Path -Encoding UTF8}
    function Download-Art{param([string]$Url,[string]$Target);return $null}
    function Test-ImageFile{param([string]$Path);return $false}
    . (Join-Path $StageRoot 'HuymaierArtworkSources.ps1')
    $ps3=[pscustomobject]@{Source='PS3';Name='Example';Id='1'};$gc=[pscustomobject]@{Source='GameCube';Name='Example';Id='2'}
    Assert ((Get-HcPlatformAliases $ps3) -contains 'playstation 3') 'PS3 alias mapping is missing.'
    Assert ((Get-HcPlatformAliases $gc) -contains 'nintendo gamecube') 'GameCube alias mapping is missing.'
    Assert ((Get-HcPlatformScore $ps3 'Sony PlayStation 3') -ge .9) 'Correct PS3 platform does not score highly.'
    Assert ((Get-HcPlatformScore $ps3 'Xbox 360') -eq 0) 'Wrong console platform is not rejected.'
    Assert (Test-HcPlatformSpecificArtworkSource 'PS2') 'PS2 is not platform-specific.'
    Assert (-not (Test-HcPlatformSpecificArtworkSource 'Steam')) 'Steam was treated as a console platform.'
    $key=Get-HcArtworkLookupKey $ps3 'TheGamesDB';Set-HcArtworkFailure $key 'NotFound' 24;Assert (Test-HcArtworkLookupSuppressed $key) 'Failed lookup backoff is not active.'
}finally{Remove-Item -LiteralPath $testCache -Recurse -Force -ErrorAction SilentlyContinue}
Write-Host 'v0.30.8 cover-art fallback validation passed.'
