param()
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
# HUYMAIER_V0308_TGDB_SCHEMA_TRANSFORM_V1
$root=Split-Path -Parent $PSScriptRoot
function Read-Normalized([string]$Path){return ([IO.File]::ReadAllText($Path,[Text.Encoding]::UTF8).Replace("`r`n","`n"))}
function Write-Normalized([string]$Path,[string]$Text){[IO.File]::WriteAllText($Path,$Text.Replace("`n","`r`n"),(New-Object Text.UTF8Encoding($true)))}
function Replace-Required([string]$Text,[string]$Old,[string]$New,[string]$Label){if(-not $Text.Contains($Old)){throw "v0.30.8 TGDB schema transform anchor missing: $Label"};return $Text.Replace($Old,$New)}
$lf="`n"
$workerPath=Join-Path $root 'HuymaierArtworkWorker.ps1'
$worker=Read-Normalized $workerPath
if($worker -notmatch 'HUYMAIER_V0308_TGDB_SCHEMA_WORKER_V1'){
    $anchor="    if(Test-Path -LiteralPath `$externalSourcesPath -PathType Leaf){. `$externalSourcesPath}"
    $insert=@($anchor,"    `$tgdbSchemaPath=Join-Path (Split-Path -Parent `$MyInvocation.MyCommand.Path) 'HuymaierArtworkSourcesTgdbSchema.ps1' # HUYMAIER_V0308_TGDB_SCHEMA_WORKER_V1","    if(Test-Path -LiteralPath `$tgdbSchemaPath -PathType Leaf){. `$tgdbSchemaPath}") -join $lf
    $worker=Replace-Required $worker $anchor $insert 'worker TGDB schema module load'
}
Write-Normalized $workerPath $worker
$bootstrapPath=Join-Path $root 'HuymaierBootstrap.ps1'
$bootstrap=Read-Normalized $bootstrapPath
if($bootstrap -notmatch 'HUYMAIER_V0308_TGDB_SCHEMA_PREFLIGHT_V1'){
    $anchor="`$artworkSourcesPath=Join-Path `$baseDir 'HuymaierArtworkSources.ps1' # HUYMAIER_V0308_ARTWORK_PREFLIGHT_V1"
    $insert=@($anchor,"`$artworkTgdbSchemaPath=Join-Path `$baseDir 'HuymaierArtworkSourcesTgdbSchema.ps1' # HUYMAIER_V0308_TGDB_SCHEMA_PREFLIGHT_V1") -join $lf
    $bootstrap=Replace-Required $bootstrap $anchor $insert 'bootstrap TGDB schema path'
    $anchor="        [pscustomobject]@{Path=`$artworkSourcesPath;Label='TheGamesDB and curated artwork sources'},"
    $insert=@($anchor,"        [pscustomobject]@{Path=`$artworkTgdbSchemaPath;Label='TheGamesDB current API schema adapter'},") -join $lf
    $bootstrap=Replace-Required $bootstrap $anchor $insert 'bootstrap TGDB schema preflight entry'
}
Write-Normalized $bootstrapPath $bootstrap
Write-Host 'Applied Huymaier Console v0.30.8 TheGamesDB current-schema transform.'
