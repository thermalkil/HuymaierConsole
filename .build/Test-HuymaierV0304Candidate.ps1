param(
    [Parameter(Mandatory=$true)][string]$StageRoot,
    [Parameter(Mandatory=$true)][string]$ValidationPath
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
if(-not(Test-Path -LiteralPath $StageRoot -PathType Container)){throw "v0.30.4 stage root missing: $StageRoot"}
if(-not(Test-Path -LiteralPath $ValidationPath -PathType Leaf)){throw "v0.30.4 validation record missing: $ValidationPath"}
$validation=Get-Content -Raw -LiteralPath $ValidationPath -Encoding UTF8|ConvertFrom-Json
if([string]$validation.version -ne '0.30.4'){throw "Expected validation version 0.30.4, found $($validation.version)."}
if([string]$validation.asset -ne 'HC0304.zip'){throw "Expected HC0304.zip, found $($validation.asset)."}

$manifest=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'manifest.json') -Encoding UTF8|ConvertFrom-Json
if([string]$manifest.version -ne '0.30.4' -or [string]$manifest.baseVersion -ne '0.30.3'){throw 'v0.30.4 manifest identity/base release is wrong.'}
$appx=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'FSEPackage\AppxManifest.xml') -Encoding UTF8
if($appx -notmatch 'Version="0\.30\.4\.0"'){throw 'v0.30.4 AppX identity is missing.'}
Write-Host 'v0304VersionIdentityGate: success'

$core=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'HuymaierConsole.ps1') -Encoding UTF8
$modulePath=Join-Path $StageRoot 'HuymaierModelDefaults.ps1'
$module=Get-Content -Raw -LiteralPath $modulePath -Encoding UTF8
$bootstrap=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'HuymaierBootstrap.ps1') -Encoding UTF8
$installer=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'Install-HuymaierConsole.ps1') -Encoding UTF8
$native=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'Native\HuymaierD3D11ShelfRuntime.cpp') -Encoding UTF8
foreach($needle in @('HUYMAIER_V0304_MODEL_DEFAULT_CONFIG_V1','PlatformModelDefaultViews','HUYMAIER_V0304_MODEL_DEFAULT_RUNTIME_LOAD_V1','HuymaierModelDefaults.ps1')){if(-not$core.Contains($needle)){throw "Staged core missing model-default contract: $needle"}}
foreach($needle in @('HUYMAIER_V0304_MODEL_DEFAULT_ORIENTATION_EDITOR_V1','EDIT MODEL','A/Cross Save Default','Y/Triangle Reset Default','Set-HcModelDefaultView','SetItemView([int]$card.ActionIndex')){if(-not$module.Contains($needle)){throw "Staged model-default runtime missing: $needle"}}
if(-not$bootstrap.Contains('HUYMAIER_V0304_MODEL_DEFAULT_PREFLIGHT_V1')){throw 'Staged bootstrap lacks model-default preflight.'}
if(-not$installer.Contains('HUYMAIER_V0304_MODEL_DEFAULT_INSTALLER_CACHE_V1')){throw 'Staged installer lacks model-default startup-cache entry.'}
if(-not$native.Contains('HUYMAIER_V0304_MODEL_DEFAULT_ORIENTATION_V1')){throw 'Staged native renderer lacks stable default-orientation transform.'}
if($native.Contains('static_cast<float>((item.id*11)%360)')){throw 'Staged renderer still rotates model orientation by action index.'}
Write-Host 'v0304ModelEditorStageGate: success'
Write-Host 'v0304ModelPersistenceStageGate: success'
Write-Host 'v0304StableYawStageGate: success'

$updater=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'HuymaierSelfUpdater.ps1') -Encoding UTF8
$fseHostSource=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'HuymaierFSEHost.cs') -Encoding UTF8
foreach($needle in @('HUYMAIER_FSE_HOST','HuymaierConsoleFseUpdate.lock','WaitForUpdateHandoffToStart','WaitForUpdateHandoff(handoffPath)')){
    if($fseHostSource.IndexOf($needle,[StringComparison]::Ordinal) -lt 0){throw "Staged v0.30.3 FSE host handoff contract missing: $needle"}
}
foreach($needle in @("GetEnvironmentVariable('HUYMAIER_FSE_HOST')",'HuymaierConsoleFseUpdate.lock','if($relaunch -and -not $isFseManaged)','Windows FSE host owns post-update relaunch.')){
    if($updater.IndexOf($needle,[StringComparison]::Ordinal) -lt 0){throw "Staged v0.30.3 self-updater handoff contract missing: $needle"}
}
Write-Host 'v0304FseUpdaterCarryForwardGate: success'

$customization=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'HuymaierCustomization.ps1') -Encoding UTF8
if($customization -notmatch 'HUYMAIER_V0302_CONSOLE_BRIGHTNESS_V1'){throw 'Overall console brightness carry-forward marker is missing.'}
if($customization -notmatch 'Maximum=200' -or $customization -notmatch 'TickFrequency=10'){throw 'Overall console brightness 0-200 / 10-step contract is missing.'}
Write-Host 'v0304ConsoleBrightnessCarryForwardGate: success'

$tokens=$null;$errors=$null
[void][Management.Automation.Language.Parser]::ParseFile($modulePath,[ref]$tokens,[ref]$errors)
if($errors.Count){throw ('Staged HuymaierModelDefaults.ps1 failed PowerShell 5.1 parse: '+(@($errors|ForEach-Object{$_.Message}) -join '; '))}
Write-Host 'v0304ModelDefaultsPs51ParseGate: success'
