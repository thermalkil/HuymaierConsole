param(
    [Parameter(Mandatory=$true)][string]$StageRoot,
    [Parameter(Mandatory=$true)][string]$ValidationPath
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
function NeedFile([string]$Rel){$p=Join-Path $StageRoot $Rel;if(-not(Test-Path -LiteralPath $p -PathType Leaf)){throw "Staged manual Recomps payload missing: $Rel"};return $p}
function CheckPs([string]$Rel){$p=NeedFile $Rel;$t=$null;$e=$null;$ast=[Management.Automation.Language.Parser]::ParseFile($p,[ref]$t,[ref]$e);if(@($e).Count){throw "$Rel failed staged Windows PowerShell 5.1 parse: $(@($e|ForEach-Object{$_.Message}) -join '; ')"};foreach($v in @($ast.FindAll({param($n)$n -is [Management.Automation.Language.VariableExpressionAst]},$true))){if([string]::Equals([string]$v.VariablePath.UserPath,'Host',[StringComparison]::OrdinalIgnoreCase)){throw "Staged manual Recomps runtime references reserved `$Host: $Rel line $($v.Extent.StartLineNumber)"}};return $p}

if(-not(Test-Path -LiteralPath $ValidationPath -PathType Leaf)){throw "Candidate validation record missing: $ValidationPath"}
foreach($rel in @('HuymaierConsole.ps1','HuymaierBootstrap.ps1','Install-HuymaierConsole.ps1','HuymaierCustomization.ps1','HuymaierRecompsManual.ps1','HuymaierRecompsFinal.ps1')){CheckPs $rel|Out-Null}

$manual=Get-Content -Raw -LiteralPath (NeedFile 'HuymaierRecompsManual.ps1') -Encoding UTF8
foreach($needle in @('RecompGames','provider-recomps-add','PickExecutable','RecompGame','Get-HcManualRecompGames','Add-HcManualRecompExecutable','Remove-HcManualRecompGame','provider-recomps-remove','provider-recomp-remove:','No game files were deleted')){if($manual.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "Staged manual Recomps contract missing: $needle"}}
foreach($forbidden in @('Select-HcRecompExecutable','Get-ChildItem -LiteralPath $root -Filter ''*.exe''')){if($manual.IndexOf($forbidden,[StringComparison]::Ordinal)-ge0){throw "Staged manual Recomps reintroduced folder scanning/guessing: $forbidden"}}

$custom=Get-Content -Raw -LiteralPath (NeedFile 'HuymaierCustomization.ps1') -Encoding UTF8
if($custom.IndexOf('HuymaierRecompsManual.ps1',[StringComparison]::Ordinal)-lt0){throw 'Staged customization does not initialize the manual Recomps library.'}
$final=Get-Content -Raw -LiteralPath (NeedFile 'HuymaierRecompsFinal.ps1') -Encoding UTF8
foreach($needle in @('Get-HcManualRecompGames','HcManualRecompsBaseGetPageDefinition','HcManualRecompsBaseInvokeAction','HcManualRecompsFinalOwner')){if($final.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "Staged final manual Recomps owner missing: $needle"}}

$core=Get-Content -Raw -LiteralPath (NeedFile 'HuymaierConsole.ps1') -Encoding UTF8
$v7=$core.IndexOf('HUYMAIER_GPU_3D_SHELVES_RUNTIME_LOAD_V1',[StringComparison]::Ordinal)
$manualFinal=$core.IndexOf('HUYMAIER_MANUAL_RECOMPS_FINAL_LOAD_V1',[StringComparison]::Ordinal)
if($v7-lt0-or$manualFinal-le$v7){throw 'Staged manual Recomps final ownership does not load after V7.'}
foreach($needle in @("ManualRecompsFinalModulePath = Join-Path `$script:BaseDir 'HuymaierRecompsFinal.ps1'",'. $script:ManualRecompsFinalModulePath')){if($core.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "Staged core omits final manual Recomps runtime load: $needle"}}

$bootstrap=Get-Content -Raw -LiteralPath (NeedFile 'HuymaierBootstrap.ps1') -Encoding UTF8
foreach($needle in @('HUYMAIER_MANUAL_RECOMPS_PREFLIGHT_V1','HuymaierRecompsManual.ps1','HuymaierRecompsFinal.ps1','Manual Recomps library runtime','Manual Recomps final ownership runtime')){if($bootstrap.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "Staged bootstrap omits manual Recomps preflight: $needle"}}
$installer=Get-Content -Raw -LiteralPath (NeedFile 'Install-HuymaierConsole.ps1') -Encoding UTF8
foreach($needle in @('HUYMAIER_MANUAL_RECOMPS_INSTALLER_CACHE_V1',"'HuymaierRecompsManual.ps1'","'HuymaierRecompsFinal.ps1'")){if($installer.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "Staged installer omits manual Recomps cache payload: $needle"}}

$validation=Get-Content -Raw -LiteralPath $ValidationPath -Encoding UTF8|ConvertFrom-Json
if($null-eq$validation){throw 'Candidate validation record is unreadable.'}
Write-Host 'stagedManualRecompsMultiGameLibraryGate: success'
Write-Host 'stagedManualRecompsExactExeGate: success'
Write-Host 'stagedManualRecompsRemoveWithoutDeleteGate: success'
Write-Host 'stagedManualRecompsNoFolderScanGate: success'
Write-Host 'stagedManualRecompsFinalAfterV7Gate: success'
Write-Host 'stagedManualRecompsInstallerBootstrapGate: success'
