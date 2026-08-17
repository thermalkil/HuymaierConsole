param([string]$StageRoot='')
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
# HUYMAIER_V0308_TGDB_SCHEMA_TEST_V2
if(-not $StageRoot){$StageRoot=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)}
$StageRoot=(Resolve-Path -LiteralPath $StageRoot).Path
function Assert([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message}}
function Text([string]$Relative){$path=Join-Path $StageRoot $Relative;Assert (Test-Path -LiteralPath $path -PathType Leaf) "Missing $Relative";return Get-Content -Raw -LiteralPath $path -Encoding UTF8}
function Assert-Parse([string]$Relative){$path=Join-Path $StageRoot $Relative;$tokens=$null;$errors=$null;[void][Management.Automation.Language.Parser]::ParseFile($path,[ref]$tokens,[ref]$errors);if($errors.Count){throw "$Relative failed PowerShell 5.1 parse: $($errors[0].Message)"}}
foreach($relative in @('HuymaierArtworkSourcesTgdbSchema.ps1','HuymaierArtworkWorker.ps1','HuymaierBootstrap.ps1','Install-HuymaierConsole.ps1','HuymaierInstallerCore.ps1')){Assert-Parse $relative}
$schema=Text 'HuymaierArtworkSourcesTgdbSchema.ps1';$worker=Text 'HuymaierArtworkWorker.ps1';$bootstrap=Text 'HuymaierBootstrap.ps1';$installer=Text 'Install-HuymaierConsole.ps1';$installerCore=Text 'HuymaierInstallerCore.ps1'
Assert ($worker.Contains('HuymaierArtworkSourcesTgdbSchema.ps1')) 'Artwork worker does not load the current TheGamesDB schema adapter.'
Assert ($bootstrap.Contains('HuymaierArtworkSourcesTgdbSchema.ps1')) 'Bootstrap preflight does not cover the current TheGamesDB schema adapter.'
Assert ($installer.Contains('[string]$Version=''0.30.8''') -and $installer.Contains('-Version ''0.30.8''')) 'Installer preflight cache version was not bumped to 0.30.8.'
Assert ($installerCore.Contains('$script:InstallVersion=''0.30.8''')) 'Installer core version was not bumped to 0.30.8.'
Assert ($installer.Contains('HuymaierArtworkSourcesTgdbSchema.ps1')) 'Installer preflight cache does not include the TheGamesDB schema adapter.'
Assert ($installerCore.Contains('HuymaierArtworkSourcesTgdbSchema.ps1')) 'Installer required payload does not include the TheGamesDB schema adapter.'
Assert ($schema.Contains('include=boxart%2Cplatform')) 'TheGamesDB search does not request boxart and platform metadata together.'
Assert ($schema.Contains('filter%5Bplatform%5D')) 'TheGamesDB search does not support platform filtering.'
Assert ($schema.Contains('Get-Prop $Response ''include''')) 'TheGamesDB include response shape is not handled.'
$testCache=Join-Path $env:TEMP ('hc-tgdb-schema-test-'+[guid]::NewGuid().ToString('N'));New-Item -ItemType Directory -Force -Path $testCache|Out-Null
try{
    $CacheDir=$testCache;$config=[pscustomobject]@{TheGamesDbApiKey=''}
    function Get-Prop{param($Object,[string]$Name,$Default=$null);if($null -eq $Object){return $Default};$p=$Object.PSObject.Properties[$Name];if($null -eq $p -or $null -eq $p.Value){return $Default};return $p.Value}
    function To-Array{param($Value);if($null -eq $Value){return @()};return @($Value)}
    function Normalize-Name{param([string]$Name);if(-not $Name){return ''};return (($Name.ToLowerInvariant() -replace '[™®©]','' -replace '[^a-z0-9]+',' ').Trim())}
    function Get-NameVariants{param([string]$Name);return @($Name)}
    function Get-NameScore{param([string]$A,[string]$B);if((Normalize-Name $A) -eq (Normalize-Name $B)){return 1.0};return 0.0}
    function Write-AtomicJson{param([string]$Path,$Value);$Value|ConvertTo-Json -Depth 30|Set-Content -LiteralPath $Path -Encoding UTF8}
    function Download-Art{param([string]$Url,[string]$Target);return $null}
    function Test-ImageFile{param([string]$Path);return $false}
    . (Join-Path $StageRoot 'HuymaierArtworkSources.ps1')
    . (Join-Path $StageRoot 'HuymaierArtworkSourcesTgdbSchema.ps1')
    $keyed=[pscustomobject]@{
        '18'=[pscustomobject]@{id=18;name='Sega Genesis';alias='sega-genesis'}
        '20'=[pscustomobject]@{id=20;name='Sony PlayStation 3';alias='sony-playstation-3'}
    }
    $values=@(Get-HcTgdbKeyedValues $keyed);Assert ($values.Count -eq 2) 'Keyed TheGamesDB platform objects are not enumerated correctly.'
    $ps1=[pscustomobject]@{Source='PS1';Name='Example';Id='1'};Assert ((Get-HcPlatformScore $ps1 'Sony PlayStation') -ge .98) 'PS1 platform equivalence failed.';Assert ((Get-HcPlatformScore $ps1 'Sony PlayStation 2') -eq 0) 'PS1 incorrectly matches PlayStation 2.'
    $genesis=[pscustomobject]@{Source='Genesis';Name='Sonic the Hedgehog';Id='2'};$catalog=@([pscustomobject]@{Id='18';Name='Sega Genesis'},[pscustomobject]@{Id='20';Name='Sony PlayStation 3'});$ids=@(Get-HcTgdbPlatformIdsForGame $genesis $catalog);Assert ($ids.Count -eq 1 -and [string]$ids[0] -eq '18') 'Platform ID filtering did not select only Sega Genesis.'
    $fixture=[pscustomobject]@{
        data=[pscustomobject]@{games=@([pscustomobject]@{id=53;game_title='Sonic the Hedgehog';platform=18})}
        include=[pscustomobject]@{
            platform=[pscustomobject]@{data=[pscustomobject]@{'18'=[pscustomobject]@{id=18;name='Sega Genesis';alias='sega-genesis'}}}
            boxart=[pscustomobject]@{
                base_url=[pscustomobject]@{original='https://cdn.thegamesdb.net/images/original/';large='https://cdn.thegamesdb.net/images/large/'}
                data=[pscustomobject]@{'53'=@(
                    [pscustomobject]@{id=17438;type='boxart';side='front';filename='boxart/front/53-1.jpg';resolution='1521x2156'},
                    [pscustomobject]@{id=17439;type='boxart';side='back';filename='boxart/back/53-1.jpg';resolution='1521x2156'}
                )}
            }
        }
    }
    Assert ((Get-HcTgdbIncludedPlatformName $fixture '18') -eq 'Sega Genesis') 'Included TheGamesDB platform metadata was not resolved.'
    $image=Get-HcTgdbBestImage $fixture '53';Assert ($null -ne $image) 'Included TheGamesDB boxart was not resolved.';Assert ($image.Url -eq 'https://cdn.thegamesdb.net/images/original/boxart/front/53-1.jpg') 'Front boxart URL was not constructed from the current API base URL.';Assert ($image.Width -eq 1521 -and $image.Height -eq 2156) 'TheGamesDB resolution metadata was not parsed for quality ranking.'
}finally{Remove-Item -LiteralPath $testCache -Recurse -Force -ErrorAction SilentlyContinue}
Write-Host 'v0.30.8 TheGamesDB current-schema validation passed.'
