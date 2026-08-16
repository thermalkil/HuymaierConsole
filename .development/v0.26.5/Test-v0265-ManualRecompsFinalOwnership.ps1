Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$core=Join-Path $root 'HuymaierConsole.ps1'
$optimizer=Join-Path $root '.build\Optimize-User3DModels.ps1'
$manual=Join-Path $root 'HuymaierRecompsManual.ps1'
$final=Join-Path $root 'HuymaierRecompsFinal.ps1'
$bootstrap=Join-Path $root 'HuymaierBootstrap.ps1'
$installer=Join-Path $root 'Install-HuymaierConsole.ps1'
$sourceList=Join-Path $root '.source\source-files.txt'
foreach($p in @($core,$optimizer,$manual,$final,$bootstrap,$installer,$sourceList)){if(-not(Test-Path -LiteralPath $p -PathType Leaf)){throw "Manual Recomps final-ownership source missing: $p"}}
foreach($p in @($optimizer,$manual,$final)){$t=$null;$e=$null;[void][Management.Automation.Language.Parser]::ParseFile($p,[ref]$t,[ref]$e);if(@($e).Count){throw "$p failed Windows PowerShell 5.1 parse: $(@($e|ForEach-Object{$_.Message}) -join '; ')"}}

$optimizerText=Get-Content -Raw -LiteralPath $optimizer -Encoding UTF8
foreach($needle in @('HUYMAIER_MANUAL_RECOMPS_CONFIG_TRANSFORM_V1','HUYMAIER_MANUAL_RECOMPS_CONFIG_V1','RecompGames','RecompGame','HUYMAIER_MANUAL_RECOMPS_FINAL_LOAD_V1','HuymaierRecompsManual.ps1','HuymaierRecompsFinal.ps1','HUYMAIER_MANUAL_RECOMPS_PREFLIGHT_V1','HUYMAIER_MANUAL_RECOMPS_INSTALLER_CACHE_V1')){if($optimizerText.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "Manual Recomps release transform contract missing: $needle"}}
$finalText=Get-Content -Raw -LiteralPath $final -Encoding UTF8
foreach($needle in @('HcRecompsSimpleLibraryInstalled','HcRecompsSimpleBaseRenderGamesHub','HcRecompsSimpleBaseInvokeAction','RecompsLibrary','RecompsGame','recomps-add-game','recomp-launch','recomp-remove','platform-select:')){if($finalText.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "Simple Recomps final-owner contract missing: $needle"}}
$sources=@(Get-Content -LiteralPath $sourceList -Encoding UTF8)
foreach($name in @('HuymaierRecompsManual.ps1','HuymaierRecompsFinal.ps1')){if($sources-notcontains$name){throw "Release source list omits $name"}}

$temp=Join-Path $(if($env:RUNNER_TEMP){$env:RUNNER_TEMP}else{[IO.Path]::GetTempPath()}) ('hc-recomps-final-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $temp|Out-Null
try{
    $coreCopy=Join-Path $temp 'HuymaierConsole.ps1';$bootCopy=Join-Path $temp 'HuymaierBootstrap.ps1';$installCopy=Join-Path $temp 'Install-HuymaierConsole.ps1';$builderCopy=Join-Path $temp 'Build.Core.ps1'
    Copy-Item -LiteralPath $core -Destination $coreCopy
    Copy-Item -LiteralPath $bootstrap -Destination $bootCopy
    Copy-Item -LiteralPath $installer -Destination $installCopy
    Copy-Item -LiteralPath (Join-Path $root '.build\Build-HuymaierReleaseCandidate.Core.ps1') -Destination $builderCopy
    & (Join-Path $root '.build\Optimize-Platform3DModels.ps1') -CorePath $coreCopy -BootstrapPath $bootCopy -InstallerScriptPath $installCopy -CoreBuilderPath $builderCopy
    & $optimizer -CorePath $coreCopy -BootstrapPath $bootCopy -InstallerScriptPath $installCopy

    $coreText=Get-Content -Raw -LiteralPath $coreCopy -Encoding UTF8
    $v7=$coreText.IndexOf('HUYMAIER_GPU_3D_SHELVES_RUNTIME_LOAD_V1',[StringComparison]::Ordinal)
    $manualFinal=$coreText.IndexOf('HUYMAIER_MANUAL_RECOMPS_FINAL_LOAD_V1',[StringComparison]::Ordinal)
    if($v7-lt0-or$manualFinal-le$v7){throw 'Final manual Recomps ownership is not loaded after the V7 GPU shelf runtime.'}
    foreach($needle in @("ManualRecompsFinalModulePath = Join-Path `$script:BaseDir 'HuymaierRecompsFinal.ps1'",'. $script:ManualRecompsFinalModulePath','HUYMAIER_MANUAL_RECOMPS_CONFIG_V1','RecompGames = @()',"'FavoriteGames','RecompGames')) {","'ProviderInstallRoots','FavoriteGames','RecompGames')) {","EntryType,'RecompGame'", "{@('.exe')}else{@('.exe','.lnk','.url')}")){if($coreText.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "Transformed core is missing manual Recomps persistence/picker contract: $needle"}}
    if($coreText.IndexOf("if (`$script:FileBrowserMode -eq 'PickExecutable') { `$allowed=@('.exe','.lnk','.url') }",[StringComparison]::Ordinal)-ge0){throw 'Transformed core still exposes shortcut/URL choices to the RecompGame picker.'}

    $bootText=Get-Content -Raw -LiteralPath $bootCopy -Encoding UTF8
    foreach($needle in @('HUYMAIER_MANUAL_RECOMPS_PREFLIGHT_V1','HuymaierRecompsManual.ps1','HuymaierRecompsFinal.ps1','Manual Recomps library runtime','Manual Recomps final ownership runtime')){if($bootText.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "Bootstrap omits manual Recomps preflight contract: $needle"}}
    $installText=Get-Content -Raw -LiteralPath $installCopy -Encoding UTF8
    foreach($needle in @('HUYMAIER_MANUAL_RECOMPS_INSTALLER_CACHE_V1',"'HuymaierRecompsManual.ps1'","'HuymaierRecompsFinal.ps1'")){if($installText.IndexOf($needle,[StringComparison]::Ordinal)-lt0){throw "Installer cache omits manual Recomps runtime: $needle"}}

    # Simulate manual runtime -> V7 -> final owner. The final owner must wrap the
    # current post-V7 functions, then force Recomps directly into the simple EXE
    # library instead of restoring the old provider/platform chooser.
    $exe=Join-Path $temp 'ExampleRecomp.exe';New-Item -ItemType File -Force -Path $exe|Out-Null
    $script:ConfigPath=Join-Path $temp 'config.json'
    $script:Config=[pscustomobject]@{RecentGames=@();FavoriteGames=@();RecompGames=@([pscustomobject]@{Id='Recomps:test';Name='ExampleRecomp';LaunchTarget=$exe;ArtworkPath='';Added='now'})}
    $script:SelectedTab=1;$script:SelectedAction=0;$script:SelectedGamePlatform='Steam';$script:SubPage='';$script:GameHubPlatforms=@('Steam','Recomps');$script:FileBrowserEntryType='';$script:FileBrowserReturnTab=1;$script:FileBrowserReturnSubPage='ProviderStore';$script:Rendered='';$script:BaseAction=''
    function Convert-ToStableArray {param($Value);$a=New-Object Collections.ArrayList;if($null-ne$Value){try{foreach($v in $Value){[void]$a.Add($v)}}catch{[void]$a.Add($Value)}};return ,([object[]]$a.ToArray())}
    function Get-EntryProperty {param($Object,[string]$Name,$Default=$null);if($null-eq$Object){return $Default};$p=$Object.PSObject.Properties[$Name];if($null-eq$p-or$null-eq$p.Value){return $Default};return $p.Value}
    function Save-Config {}
    function Write-Log {param([string]$Message,[string]$Level='INFO')}
    function Set-ConsoleNotice {param([string]$Message,[string]$Level='INFO')}
    function Render-Page {}
    function Update-NavVisuals {}
    function Update-ActionVisuals {}
    function Invoke-UiFeedback {param([string]$Kind)}
    function Start-NativeFilePicker {param([string]$Mode,[string]$Store,[string]$EntryType,[int]$ReturnTab=-1,[string]$StartPath='')}
    function Request-NativeConfirmation {param([string]$Action,[string]$Question)}
    function New-Action {param([string]$Id,[string]$Title='',[string]$Description='');[pscustomobject]@{Id=$Id;Title=$Title;Description=$Description}}
    function Get-GameProviderDefinitions {return @([pscustomobject]@{Id='Recomps';Name='Recomps';Backend='Native';Description='legacy';Glyph='RECOMP'})}
    function Get-ProviderCatalogNode {param([string]$Provider);[pscustomobject]@{Id=$Provider;Games=@()}}
    function Add-ProviderControlRail {param([string]$Provider)}
    function Render-GameProviderStore {param([string]$Provider)}
    function Get-GameProviderPageDefinition {return $null}
    function Invoke-GameProviderAction {param([string]$Id);return $false}
    function Complete-ProviderConfirmation {param([string]$Action);return $false}
    function Complete-NativeFileSelection {param($Entry)}
    function Get-SelectedProviderGame {return $null}
    function Get-PageDefinition {param([int]$Index);[pscustomobject]@{Title='Base';Actions=@((New-Action 'keep' 'Keep'))}}
    function Invoke-Action {param([string]$Id);$script:BaseAction=$Id}
    function Render-GamesHub {$script:Rendered='pre-v7'}
    function Handle-Back {$script:BaseBack=$true}
    . $manual

    # V7 historically won these final functions and reintroduced provider UI.
    function Get-HcRecompGames {return @('legacy-folder-scan')}
    function Get-PageDefinition {param([int]$Index);[pscustomobject]@{Title='V7';Actions=@((New-Action 'recomps-root' 'Old root'),(New-Action 'keep' 'Keep'))}}
    function Invoke-Action {param([string]$Id);$script:V7Action=$Id}
    function Render-GamesHub {$script:Rendered='v7'}
    function Handle-Back {$script:V7Back=$true}
    . $final

    $games=@(Get-HcRecompGames)
    if($games.Count-ne1-or[string]$games[0].LaunchTarget-ne$exe){throw 'Final owner did not restore the explicit manual Recomps game list after V7.'}
    $page=Get-PageDefinition 7
    if(@($page.Actions|Where-Object{$_.Id-eq'recomps-root'}).Count-ne0){throw 'Final owner allowed the obsolete V7 Recomps root setting to survive.'}
    Invoke-Action 'platform-select:1'
    if($script:SelectedGamePlatform-ne'Recomps'-or$script:SubPage-ne'RecompsLibrary'){throw 'Final owner did not route the Recomps tile directly to RecompsLibrary.'}
    if([string]$script:HcManualRecompsFinalOwner-ne'HuymaierRecompsFinal.SimpleLibrary'){throw 'Simple manual Recomps final-owner marker is missing.'}

    Write-Host 'manualRecompsNativeConfigPersistenceGate: success'
    Write-Host 'manualRecompsExeOnlyPickerGate: success'
    Write-Host 'manualRecompsFinalAfterV7Gate: success'
    Write-Host 'manualRecompsDirectLibraryOwnerGate: success'
    Write-Host 'manualRecompsBootstrapPreflightGate: success'
    Write-Host 'manualRecompsInstallerCacheGate: success'
    Write-Host 'manualRecompsFinalResolverGate: success'
    Write-Host 'manualRecompsSourceListGate: success'
}finally{Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue}
