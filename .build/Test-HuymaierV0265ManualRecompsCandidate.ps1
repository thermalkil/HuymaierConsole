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
$finalPath=NeedFile 'HuymaierRecompsFinal.ps1'
$final=Get-Content -Raw -LiteralPath $finalPath -Encoding UTF8
foreach($needle in @('Get-HcManualRecompGames','HcRecompsSimpleLibraryInstalled','HcRecompsSimpleBaseRenderGamesHub','HcRecompsSimpleBaseInvokeAction','RecompsLibrary','RecompsGame','recomps-add-game','recomp-open:','recomp-launch','recomp-remove','HuymaierRecompsFinal.SimpleLibrary')){if($final.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "Staged simple Recomps final owner missing: $needle"}}
# These are source-text needles. Keep them single-quoted so StrictMode never
# evaluates $script:SubPage in the candidate-test process itself.
foreach($forbidden in @('$script:SubPage=''PlatformChoice''','$script:SubPage=''ProviderStore'';$script:SelectedAction=0;Render-Page')){if($final.IndexOf($forbidden,[StringComparison]::Ordinal)-ge0){throw "Staged final Recomps owner can still route into the retired generic provider/platform chooser: $forbidden"}}

$core=Get-Content -Raw -LiteralPath (NeedFile 'HuymaierConsole.ps1') -Encoding UTF8
$v7=$core.IndexOf('HUYMAIER_GPU_3D_SHELVES_RUNTIME_LOAD_V1',[StringComparison]::Ordinal)
$manualFinal=$core.IndexOf('HUYMAIER_MANUAL_RECOMPS_FINAL_LOAD_V1',[StringComparison]::Ordinal)
if($v7-lt0-or$manualFinal-le$v7){throw 'Staged manual Recomps final ownership does not load after V7.'}
foreach($needle in @("ManualRecompsFinalModulePath = Join-Path `$script:BaseDir 'HuymaierRecompsFinal.ps1'",'. $script:ManualRecompsFinalModulePath','HUYMAIER_MANUAL_RECOMPS_CONFIG_V1','RecompGames = @()',"'FavoriteGames','RecompGames')) {","'ProviderInstallRoots','FavoriteGames','RecompGames')) {","EntryType,'RecompGame'", "{@('.exe')}else{@('.exe','.lnk','.url')}")){if($core.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "Staged core omits manual Recomps persistence/picker contract: $needle"}}
if($core.IndexOf("if (`$script:FileBrowserMode -eq 'PickExecutable') { `$allowed=@('.exe','.lnk','.url') }",[StringComparison]::Ordinal)-ge0){throw 'Staged RecompGame picker still exposes shortcut/URL choices.'}

$bootstrap=Get-Content -Raw -LiteralPath (NeedFile 'HuymaierBootstrap.ps1') -Encoding UTF8
foreach($needle in @('HUYMAIER_MANUAL_RECOMPS_PREFLIGHT_V1','HuymaierRecompsManual.ps1','HuymaierRecompsFinal.ps1','Manual Recomps library runtime','Manual Recomps final ownership runtime')){if($bootstrap.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "Staged bootstrap omits manual Recomps preflight: $needle"}}
$installer=Get-Content -Raw -LiteralPath (NeedFile 'Install-HuymaierConsole.ps1') -Encoding UTF8
foreach($needle in @('HUYMAIER_MANUAL_RECOMPS_INSTALLER_CACHE_V1',"'HuymaierRecompsManual.ps1'","'HuymaierRecompsFinal.ps1'")){if($installer.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "Staged installer omits manual Recomps cache payload: $needle"}}

# Execute the packaged final owner in a small fake Games environment. This is
# deliberately behavioral: the candidate fails if the packaged runtime sends
# Recomps into PlatformChoice/ProviderStore even when all source strings exist.
$temp=Join-Path $(if($env:RUNNER_TEMP){$env:RUNNER_TEMP}else{[IO.Path]::GetTempPath()}) ('hc-staged-recomps-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $temp|Out-Null
try{
    $exe1=Join-Path $temp 'GameOne.exe';$exe2=Join-Path $temp 'GameTwo.exe'
    New-Item -ItemType File -Force -Path $exe1,$exe2|Out-Null
    $script:StageRecompGames=@(
        [pscustomobject]@{Id='Recomps:one';Name='Game One';Provider='Recomps';Source='Recomps';LaunchTarget=$exe1;Path=$temp;InstallPath=$temp;Installed=$true},
        [pscustomobject]@{Id='Recomps:two';Name='Game Two';Provider='Recomps';Source='Recomps';LaunchTarget=$exe2;Path=$temp;InstallPath=$temp;Installed=$true}
    )
    $script:GameHubPlatforms=@('Steam','Recomps','PS4')
    $script:SelectedGamePlatform='Steam';$script:SelectedTab=1;$script:SubPage='';$script:SelectedAction=0
    $script:SelectedProviderGame=$null;$script:FileBrowserEntryType='';$script:StageRendered='';$script:StageBaseAction='';$script:StageBaseBack=0;$script:StageBaseComplete=0;$script:StagePickerCount=0;$script:StageRemovedId='';$script:StageRenderCount=0;$script:HcSelectedRecompId=''

    function Get-HcManualRecompGames {return [object[]]@($script:StageRecompGames)}
    function Get-EntryProperty {param($Object,[string]$Name,$Default=$null);if($null-eq$Object){return $Default};$p=$Object.PSObject.Properties[$Name];if($null-eq$p-or$null-eq$p.Value){return $Default};return $p.Value}
    function Render-GamesHub {$script:StageRendered='base'}
    function Invoke-Action {param([string]$Id);$script:StageBaseAction=$Id}
    function Handle-Back {$script:StageBaseBack++}
    function Get-PageDefinition {param([int]$Index);return [pscustomobject]@{Actions=@()}}
    function Complete-ProviderConfirmation {param([string]$Action);return $false}
    function Complete-NativeFileSelection {param($Entry);$script:StageBaseComplete++;$script:SubPage='ProviderStore'}
    function Render-Page {$script:StageRenderCount++}
    function Update-NavVisuals {}
    function Update-ActionVisuals {}
    function Invoke-UiFeedback {param([string]$Kind)}
    function Start-HcManualRecompPicker {$script:StagePickerCount++}
    function Remove-HcManualRecompGame {param([string]$Id);$script:StageRemovedId=$Id;return $true}
    function Set-ConsoleNotice {param([string]$Message,[string]$Level='INFO')}
    function Request-NativeConfirmation {param([string]$Action,[string]$Question);$script:StageConfirmAction=$Action}
    function Get-SelectedProviderGame {return $script:SelectedProviderGame}
    function Start-ExternalProcess {param([string]$Path,[string[]]$Arguments=@(),[string]$WorkingDirectory='');$script:StageLaunchedPath=$Path;return $null}
    function Add-ToRecent {param([string]$Type,$Entry)}
    function Convert-ToStableArray {param($Value);return [object[]]@($Value)}
    function New-Action {param([string]$Id,[string]$Title='',[string]$Description='');return [pscustomobject]@{Id=$Id;Title=$Title;Description=$Description}}

    . $finalPath

    Invoke-Action 'platform-select:1'
    if($script:SelectedGamePlatform-ne'Recomps'){throw 'Packaged Recomps tile did not select Recomps.'}
    if($script:SubPage-ne'RecompsLibrary'){throw "Packaged Recomps tile entered '$($script:SubPage)' instead of RecompsLibrary."}
    if($script:StageBaseAction){throw "Packaged Recomps tile leaked into generic platform routing: $($script:StageBaseAction)"}

    # Replace the visual renderers only after loading the actual packaged owner;
    # this lets us exercise navigation in a headless CI process without WPF UI.
    function Render-HcRecompsLibrary {$script:StageRendered='recomps-library'}
    function Render-HcRecompGame {$script:StageRendered='recomps-game'}
    foreach($stale in @('PlatformChoice','ProviderStore','PlatformHome','PlatformShelf','PlatformLibrary')){
        $script:SubPage=$stale;$script:StageRendered=''
        Render-GamesHub
        if($script:SubPage-ne'RecompsLibrary'-or$script:StageRendered-ne'recomps-library'){throw "Packaged stale Recomps page '$stale' was not normalized to the direct library."}
    }

    $script:SubPage='RecompsLibrary';$script:StageBaseAction=''
    Invoke-Action 'platform-store'
    if($script:SubPage-ne'RecompsLibrary'-or$script:StageBaseAction){throw 'Packaged Install & Manage route can still take over Recomps.'}

    Invoke-Action 'recomps-add-game'
    if($script:StagePickerCount-ne1){throw 'Packaged Add Recomp Game did not invoke the exact-EXE picker.'}

    $script:HcRecompPageEntries=[object[]]@($script:StageRecompGames)
    Invoke-Action 'recomp-open:1'
    if($script:HcSelectedRecompId-ne'Recomps:two'-or$script:SubPage-ne'RecompsGame'){throw 'Packaged saved recomp entry did not open RecompsGame.'}

    $script:SelectedGamePlatform='Recomps';$script:FileBrowserEntryType='RecompGame';$script:SubPage='FilePicker'
    Complete-NativeFileSelection ([pscustomobject]@{Type='File';FullName=$exe1})
    if($script:StageBaseComplete-ne1-or$script:SubPage-ne'RecompsLibrary'){throw 'Packaged EXE picker did not return directly to RecompsLibrary.'}

    $script:HcSelectedRecompId='Recomps:two';$script:SubPage='RecompsGame'
    if(-not(Complete-ProviderConfirmation 'recomp-simple-remove:Recomps:two')){throw 'Packaged simple Recomps remove confirmation was not handled.'}
    if($script:StageRemovedId-ne'Recomps:two'-or$script:SubPage-ne'RecompsLibrary'){throw 'Packaged remove did not return to RecompsLibrary.'}
    if(-not(Test-Path -LiteralPath $exe2 -PathType Leaf)){throw 'Packaged remove behavior deleted the selected executable.'}
}finally{
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}

$validation=Get-Content -Raw -LiteralPath $ValidationPath -Encoding UTF8|ConvertFrom-Json
if($null-eq$validation){throw 'Candidate validation record is unreadable.'}
Write-Host 'stagedManualRecompsMultiGameLibraryGate: success'
Write-Host 'stagedManualRecompsNativeConfigPersistenceGate: success'
Write-Host 'stagedManualRecompsExactExeGate: success'
Write-Host 'stagedManualRecompsExeOnlyPickerGate: success'
Write-Host 'stagedManualRecompsRemoveWithoutDeleteGate: success'
Write-Host 'stagedManualRecompsNoFolderScanGate: success'
Write-Host 'stagedManualRecompsFinalAfterV7Gate: success'
Write-Host 'stagedManualRecompsDirectLibraryGate: success'
Write-Host 'stagedManualRecompsNoPlatformChoiceGate: success'
Write-Host 'stagedManualRecompsNoProviderStoreGate: success'
Write-Host 'stagedManualRecompsBehavioralRoutingGate: success'
Write-Host 'stagedManualRecompsInstallerBootstrapGate: success'
