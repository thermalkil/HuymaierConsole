Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$final=Join-Path $root 'HuymaierRecompsFinal.ps1'
if(-not(Test-Path -LiteralPath $final -PathType Leaf)){throw "Recomps final runtime missing: $final"}
$tokens=$null;$errors=$null
[void][Management.Automation.Language.Parser]::ParseFile($final,[ref]$tokens,[ref]$errors)
if(@($errors).Count){throw "Recomps final runtime failed Windows PowerShell 5.1 parse: $(@($errors|ForEach-Object{$_.Message}) -join '; ')"}
$text=Get-Content -Raw -LiteralPath $final -Encoding UTF8
foreach($needle in @('RecompsLibrary','RecompsGame','recomps-add-game','recomp-launch','recomp-remove','platform-select:','HcRecompsSimpleBaseRenderGamesHub','HcRecompsSimpleBaseInvokeAction')){if($text.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "Direct Recomps library contract missing: $needle"}}

$temp=Join-Path $(if($env:RUNNER_TEMP){$env:RUNNER_TEMP}else{[IO.Path]::GetTempPath()}) ('hc-recomps-direct-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $temp|Out-Null
try{
    $exe1=Join-Path $temp 'GameOne.exe';$exe2=Join-Path $temp 'GameTwo.exe'
    New-Item -ItemType File -Force -Path $exe1,$exe2|Out-Null
    $script:Games=@(
        [pscustomobject]@{Id='Recomps:one';Name='Game One';Provider='Recomps';Source='Recomps';LaunchTarget=$exe1;Path=$temp;InstallPath=$temp;Installed=$true},
        [pscustomobject]@{Id='Recomps:two';Name='Game Two';Provider='Recomps';Source='Recomps';LaunchTarget=$exe2;Path=$temp;InstallPath=$temp;Installed=$true}
    )
    $script:GameHubPlatforms=@('Steam','Recomps','PS4')
    $script:SelectedGamePlatform='Steam';$script:SelectedTab=1;$script:SubPage='';$script:SelectedAction=0
    $script:SelectedProviderGame=$null;$script:FileBrowserEntryType='';$script:Rendered='';$script:BaseAction='';$script:BaseBack=0;$script:BaseComplete=0;$script:PickerCount=0;$script:RemovedId='';$script:RenderCount=0

    function Get-HcManualRecompGames {return [object[]]@($script:Games)}
    function Get-EntryProperty {param($Object,[string]$Name,$Default=$null);if($null-eq$Object){return $Default};$p=$Object.PSObject.Properties[$Name];if($null-eq$p-or$null-eq$p.Value){return $Default};return $p.Value}
    function Render-GamesHub {$script:Rendered='base'}
    function Invoke-Action {param([string]$Id);$script:BaseAction=$Id}
    function Handle-Back {$script:BaseBack++}
    function Get-PageDefinition {param([int]$Index);return [pscustomobject]@{Actions=@()}}
    function Complete-ProviderConfirmation {param([string]$Action);return $false}
    function Complete-NativeFileSelection {param($Entry);$script:BaseComplete++;$script:SubPage='ProviderStore'}
    function Render-Page {$script:RenderCount++}
    function Update-NavVisuals {}
    function Invoke-UiFeedback {param([string]$Kind)}
    function Start-HcManualRecompPicker {$script:PickerCount++}
    function Remove-HcManualRecompGame {param([string]$Id);$script:RemovedId=$Id;return $true}
    function Set-ConsoleNotice {param([string]$Message,[string]$Level='INFO')}
    function Request-NativeConfirmation {param([string]$Action,[string]$Question);$script:ConfirmAction=$Action}
    function Get-SelectedProviderGame {return $script:SelectedProviderGame}
    function Start-ExternalProcess {param([string]$Path,[string[]]$Arguments=@(),[string]$WorkingDirectory='');$script:LaunchedPath=$Path;return $null}
    function Add-ToRecent {param([string]$Type,$Entry)}
    function Convert-ToStableArray {param($Value);return [object[]]@($Value)}
    function New-Action {param([string]$Id,[string]$Title='',[string]$Description='');return [pscustomobject]@{Id=$Id;Title=$Title;Description=$Description}}

    . $final

    Invoke-Action 'platform-select:1'
    if($script:SelectedGamePlatform-ne'Recomps'){throw 'Selecting the Recomps platform tile did not select Recomps.'}
    if($script:SubPage-ne'RecompsLibrary'){throw "Selecting Recomps entered '$($script:SubPage)' instead of RecompsLibrary."}
    if($script:BaseAction){throw "Selecting Recomps leaked into the generic platform action path: $($script:BaseAction)"}

    # The old screenshot path must be impossible even if stale navigation state
    # from a previous build restores PlatformChoice or ProviderStore.
    function Render-HcRecompsLibrary {$script:Rendered='recomps-library'}
    function Render-HcRecompGame {$script:Rendered='recomps-game'}
    foreach($stale in @('PlatformChoice','ProviderStore','PlatformHome','PlatformShelf','PlatformLibrary')){
        $script:SubPage=$stale;$script:Rendered=''
        Render-GamesHub
        if($script:SubPage-ne'RecompsLibrary'-or$script:Rendered-ne'recomps-library'){throw "Stale Recomps page '$stale' was not normalized to the simple manual library."}
    }

    $script:SubPage='RecompsLibrary';$script:BaseAction=''
    Invoke-Action 'platform-store'
    if($script:SubPage-ne'RecompsLibrary'-or$script:BaseAction){throw 'Install & Manage can still take over the Recomps page.'}

    Invoke-Action 'recomps-add-game'
    if($script:PickerCount-ne1){throw 'Add Recomp Game did not open the exact-EXE picker.'}

    $script:HcRecompPageEntries=[object[]]@($script:Games)
    Invoke-Action 'recomp-open:1'
    if($script:HcSelectedRecompId-ne'Recomps:two'-or$script:SubPage-ne'RecompsGame'){throw 'Selecting a saved recomp game did not open its simple game page.'}

    $script:SubPage='RecompsGame'
    Handle-Back
    if($script:SubPage-ne'RecompsLibrary'-or$script:BaseBack-ne0){throw 'Back from a Recomps game did not return to the Recomps library.'}
    $script:SubPage='RecompsLibrary'
    Handle-Back
    if($script:SubPage-ne''-or$script:BaseBack-ne0){throw 'Back from the Recomps library did not return to the platform shelf.'}

    $script:SelectedGamePlatform='Recomps';$script:FileBrowserEntryType='RecompGame';$script:SubPage='FilePicker'
    Complete-NativeFileSelection ([pscustomobject]@{Type='File';FullName=$exe1})
    if($script:BaseComplete-ne1-or$script:SubPage-ne'RecompsLibrary'){throw 'Completing the recomp EXE picker did not return directly to RecompsLibrary.'}

    $script:HcSelectedRecompId='Recomps:two';$script:SubPage='RecompsGame'
    if(-not(Complete-ProviderConfirmation 'recomp-simple-remove:Recomps:two')){throw 'Simple Recomps remove confirmation was not handled.'}
    if($script:RemovedId-ne'Recomps:two'-or$script:SubPage-ne'RecompsLibrary'){throw 'Removing one recomp game did not return to the manual library.'}
    if(-not(Test-Path -LiteralPath $exe2 -PathType Leaf)){throw 'Removing a Recomps entry deleted the executable.'}

    Write-Host 'recompsDirectTileToLibraryGate: success'
    Write-Host 'recompsNoPlatformChoiceGate: success'
    Write-Host 'recompsNoProviderStoreGate: success'
    Write-Host 'recompsExactExePickerReturnGate: success'
    Write-Host 'recompsSimpleGamePageGate: success'
    Write-Host 'recompsSimpleRemoveWithoutDeleteGate: success'
}finally{Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue}
