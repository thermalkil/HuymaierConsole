Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$manual=Join-Path $root 'HuymaierRecompsManual.ps1'
$custom=Join-Path $root 'HuymaierCustomization.ps1'
foreach($p in @($manual,$custom)){if(-not(Test-Path -LiteralPath $p -PathType Leaf)){throw "Manual Recomps source missing: $p"}}
foreach($p in @($manual,$custom)){$tokens=$null;$errors=$null;[void][Management.Automation.Language.Parser]::ParseFile($p,[ref]$tokens,[ref]$errors);if(@($errors).Count){throw "$p failed Windows PowerShell 5.1 parse: $(@($errors|ForEach-Object{$_.Message}) -join '; ')"}}
$customText=Get-Content -Raw -LiteralPath $custom -Encoding UTF8
if($customText.IndexOf("HuymaierRecompsManual.ps1",[StringComparison]::Ordinal)-lt0){throw 'Customization layer does not load the manual Recomps module.'}
$manualText=Get-Content -Raw -LiteralPath $manual -Encoding UTF8
foreach($needle in @('provider-recomps-add','RecompGame','Remove from Recomps','RecompGames','Get-HcManualRecompGames','Complete-NativeFileSelection','provider-recomp-remove:')){if($manualText.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "Manual Recomps contract missing: $needle"}}
foreach($forbidden in @('Get-ChildItem -LiteralPath $root -Filter ''*.exe''','Select-HcRecompExecutable')){if($manualText.IndexOf($forbidden,[StringComparison]::Ordinal)-ge0){throw "Manual Recomps reintroduced folder scanning/guessing: $forbidden"}}

$temp=Join-Path $(if($env:RUNNER_TEMP){$env:RUNNER_TEMP}else{[IO.Path]::GetTempPath()}) ('hc-manual-recomps-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $temp|Out-Null
try{
    $exe1=Join-Path $temp 'Zelda64Recompiled.exe';$exe2=Join-Path $temp 'MajorasMaskRecompiled.exe';$exe3=Join-Path $temp 'StarFox64Recompiled.exe'
    foreach($exe in @($exe1,$exe2,$exe3)){New-Item -ItemType File -Force -Path $exe|Out-Null}
    $script:ConfigPath=Join-Path $temp 'config.json'
    $script:Config=[pscustomobject]@{RecentGames=@();FavoriteGames=@()}
    $script:SelectedProviderGame=$null;$script:SelectedGamePlatform='Recomps';$script:SelectedTab=1;$script:SubPage='ProviderStore';$script:SelectedAction=0
    $script:FileBrowserEntryType='';$script:FileBrowserReturnTab=1;$script:FileBrowserReturnSubPage='ProviderStore'
    $script:Notice='';$script:Picker=$null;$script:Confirm=$null;$script:BaseFileSelection=$null;$script:BaseAction=$null

    function Convert-ToStableArray {param($Value);$a=New-Object Collections.ArrayList;if($null-ne$Value){try{foreach($v in $Value){[void]$a.Add($v)}}catch{[void]$a.Add($Value)}};return ,([object[]]$a.ToArray())}
    function Get-EntryProperty {param($Object,[string]$Name,$Default=$null);if($null-eq$Object){return $Default};$p=$Object.PSObject.Properties[$Name];if($null-eq$p-or$null-eq$p.Value){return $Default};return $p.Value}
    function Save-Config {$script:Config|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $script:ConfigPath -Encoding UTF8}
    function Set-ConsoleNotice {param([string]$Message,[string]$Level='INFO');$script:Notice=$Message}
    function Write-Log {param([string]$Message,[string]$Level='INFO')}
    function Render-Page {}
    function Update-NavVisuals {}
    function New-Action {param([string]$Id,[string]$Title='',[string]$Description='');[pscustomobject]@{Id=$Id;Title=$Title;Description=$Description}}
    function Start-NativeFilePicker {param([string]$Mode,[string]$Store,[string]$EntryType,[int]$ReturnTab=-1,[string]$StartPath='');$script:Picker=[pscustomobject]@{Mode=$Mode;Store=$Store;EntryType=$EntryType;ReturnTab=$ReturnTab;StartPath=$StartPath};$script:FileBrowserEntryType=$EntryType;$script:FileBrowserReturnTab=$ReturnTab;$script:FileBrowserReturnSubPage='ProviderStore'}
    function Request-NativeConfirmation {param([string]$Action,[string]$Question);$script:Confirm=[pscustomobject]@{Action=$Action;Question=$Question}}
    function Get-GameProviderDefinitions {return @([pscustomobject]@{Id='Recomps';Name='Recomps';Backend='Native';Description='old';Glyph='RECOMP'})}
    function Get-ProviderCatalogNode {param([string]$Provider);return [pscustomobject]@{Id=$Provider;Games=@()}}
    function Add-ProviderControlRail {param([string]$Provider)}
    function Render-GameProviderStore {param([string]$Provider)}
    function Get-GameProviderPageDefinition {return $null}
    function Invoke-GameProviderAction {param([string]$Id);return $false}
    function Complete-ProviderConfirmation {param([string]$Action);return $false}
    function Complete-NativeFileSelection {param($Entry);$script:BaseFileSelection=$Entry}
    function Get-PageDefinition {param([int]$Index);return [pscustomobject]@{Actions=@((New-Action 'recomps-root' 'Old Recomps root'),(New-Action 'keep' 'Keep'))}}
    function Invoke-Action {param([string]$Id);$script:BaseAction=$Id}
    function Get-SelectedProviderGame {return $script:SelectedProviderGame}

    . $manual

    [void](Add-HcManualRecompExecutable $exe1)
    [void](Add-HcManualRecompExecutable $exe2)
    if(@(Get-HcManualRecompGames).Count-ne2){throw 'Adding two recomp executables did not preserve both games.'}
    [void](Add-HcManualRecompExecutable $exe1)
    if(@(Get-HcManualRecompGames).Count-ne2){throw 'Duplicate recomp executable was added twice.'}

    # Simulate the legacy core loader dropping unknown properties, then prove the
    # module recovers RecompGames directly from the persisted config JSON.
    $script:Config=[pscustomobject]@{RecentGames=@();FavoriteGames=@()}
    Initialize-HcManualRecompConfig
    if(@($script:Config.RecompGames).Count-ne2){throw 'Manual Recomps list did not survive config reload recovery.'}

    Start-HcManualRecompPicker
    if($null-eq$script:Picker-or$script:Picker.Mode-ne'PickExecutable'-or$script:Picker.Store-ne'Recomps'-or$script:Picker.EntryType-ne'RecompGame'){throw 'Add Recomp Game did not open the one-executable native picker.'}
    Complete-NativeFileSelection ([pscustomobject]@{Type='File';FullName=$exe3})
    if(@(Get-HcManualRecompGames).Count-ne3){throw 'Native picker completion did not append the third recomp game.'}

    $games=@(Get-HcManualRecompGames);$remove=$games[1]
    $script:SelectedProviderGame=$remove;$script:SubPage='ProviderGame'
    $page=Get-GameProviderPageDefinition
    $ids=@($page.Actions|ForEach-Object{[string]$_.Id})
    foreach($required in @('provider-game-launch','provider-recomps-open-folder','provider-recomps-remove','provider-game-back')){if($ids-notcontains$required){throw "Manual Recomps game page action missing: $required"}}
    foreach($forbidden in @('provider-game-update','provider-game-verify','provider-game-uninstall','provider-game-install','provider-game-location')){if($ids-contains$forbidden){throw "Manual Recomps exposed backend-only action: $forbidden"}}

    if(-not(Invoke-GameProviderAction 'provider-recomps-remove')){throw 'Remove from Recomps action was not handled.'}
    if($null-eq$script:Confirm-or$script:Confirm.Action-notmatch'^provider-recomp-remove:'){throw 'Remove from Recomps did not use native confirmation.'}
    if(-not(Complete-ProviderConfirmation $script:Confirm.Action)){throw 'Confirmed manual Recomps removal was not handled.'}
    if(@(Get-HcManualRecompGames).Count-ne2){throw 'Confirmed removal did not remove exactly one Recomps entry.'}
    if(-not(Test-Path -LiteralPath $exe2 -PathType Leaf)){throw 'Removing a Recomps entry deleted the game executable.'}

    $node=Get-ProviderCatalogNode 'Recomps'
    if(@($node.Games).Count-ne2-or-not[bool]$node.ToolReady){throw 'Recomps provider catalog is not backed by the manual list.'}
    $settings=Get-PageDefinition 7
    if(@($settings.Actions|Where-Object{$_.Id-eq'recomps-root'}).Count-ne0){throw 'Obsolete Recomps root-folder setting is still visible.'}

    Write-Host 'manualRecompsMultiGameAddGate: success'
    Write-Host 'manualRecompsDuplicateGuardGate: success'
    Write-Host 'manualRecompsRestartPersistenceGate: success'
    Write-Host 'manualRecompsNativeExePickerGate: success'
    Write-Host 'manualRecompsRemoveWithoutDeleteGate: success'
    Write-Host 'manualRecompsProviderCatalogGate: success'
    Write-Host 'manualRecompsNoFolderScanGate: success'
}finally{Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue}
