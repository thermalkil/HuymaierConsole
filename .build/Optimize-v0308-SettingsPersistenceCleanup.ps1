param()
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
# HUYMAIER_V0308_SETTINGS_PERSISTENCE_CLEANUP_TRANSFORM_V4
$root=Split-Path -Parent $PSScriptRoot
$lf="`n"
function Read-Normalized([string]$Path){([IO.File]::ReadAllText($Path,[Text.Encoding]::UTF8)).Replace("`r`n","`n")}
function Write-Normalized([string]$Path,[string]$Text){[IO.File]::WriteAllText($Path,$Text.Replace("`n","`r`n"),(New-Object Text.UTF8Encoding($true)))}
function Replace-Required([string]$Text,[string]$Old,[string]$New,[string]$Label){if(-not$Text.Contains($Old)){throw "v0.30.8 settings/cleanup transform anchor missing: $Label"};$Text.Replace($Old,$New)}
function Replace-Range([string]$Text,[string]$Start,[string]$End,[string]$Replacement,[string]$Label){$a=$Text.IndexOf($Start,[StringComparison]::Ordinal);if($a-lt0){throw "Range start missing ($Label): $Start"};$b=$Text.IndexOf($End,$a+$Start.Length,[StringComparison]::Ordinal);if($b-lt0){throw "Range end missing ($Label): $End"};$Text.Remove($a,$b-$a).Insert($a,$Replacement.TrimEnd()+$lf+$lf)}

$corePath=Join-Path $root 'HuymaierConsole.ps1';$core=Read-Normalized $corePath
if($core-notmatch'HUYMAIER_V0308_SETTINGS_STORE_CORE_V4'){
    $anchor='$script:BackgroundTasksModulePath = Join-Path $script:BaseDir ''HuymaierBackgroundTasks.ps1'' # HUYMAIER_V0308_BACKGROUND_TASK_CORE_V2'
    $core=Replace-Required $core $anchor (@($anchor,'$script:SettingsStoreModulePath = Join-Path $script:BaseDir ''HuymaierSettingsStore.ps1'' # HUYMAIER_V0308_SETTINGS_STORE_CORE_V4')-join$lf) 'settings store path'
    $anchor='function New-DefaultConfig {'
    $pre=@'
if (Test-Path -LiteralPath $script:SettingsStoreModulePath) {
    try { . $script:SettingsStoreModulePath; Repair-HcSettingsStoreArtifacts -Path $script:ConfigPath }
    catch { Write-Log "Settings store load failed: $($_.Exception.Message)" 'ERROR' }
}
function New-DefaultConfig {
'@
    $core=Replace-Required $core $anchor $pre.TrimEnd() 'settings store early load'
    if($core-notmatch'ConfigSchemaVersion = 2'){$core=Replace-Required $core "    [pscustomobject]@{`n        BrowserName = ''" "    [pscustomobject]@{`n        ConfigSchemaVersion = 2`n        BrowserName = ''" 'config schema'}
    if($core-notmatch'ConsoleBrightness = 100'){$core=Replace-Required $core '        UiSoundVolume = 62' "        UiSoundVolume = 62`n        ConsoleBrightness = 100" 'brightness default'}
    $load=@'
function Load-Config {
    $defaults=New-DefaultConfig
    try{$loaded=Read-HcPersistedConfig -Path $script:ConfigPath;if($null-ne$loaded){$defaults=Merge-HcPersistedConfig -Defaults $defaults -Loaded $loaded}}catch{Write-Log "Config load failed: $($_.Exception.Message)" 'WARN'}
    foreach($name in @('CustomGames','CustomApps','ImportedGames','RecentGames','RecentApps','StorefrontRoots','StorefrontInstallOverrides','ProviderInstallRoots','FavoriteGames','RecompGames','PlatformModelDefaultViews')){if($null-ne$defaults.PSObject.Properties[$name]){$defaults.$name=Convert-ToStableArray $defaults.$name}}
    try{$defaults.GameBarScale=[math]::Max(70,[math]::Min(140,[int]$defaults.GameBarScale))}catch{$defaults.GameBarScale=100}
    try{$defaults.PlatformIconScale=[math]::Max(60,[math]::Min(180,[int]$defaults.PlatformIconScale))}catch{$defaults.PlatformIconScale=100}
    try{$defaults.PlatformModelScale=[math]::Max(50,[math]::Min(200,[int]$defaults.PlatformModelScale))}catch{$defaults.PlatformModelScale=100}
    if(@('Icons','3D Models')-notcontains[string]$defaults.PlatformVisualStyle){$defaults.PlatformVisualStyle='Icons'}
    try{$defaults.UiSoundVolume=[math]::Max(0,[math]::Min(100,[int]$defaults.UiSoundVolume))}catch{$defaults.UiSoundVolume=62}
    try{$defaults.ConsoleBrightness=[math]::Max(0,[math]::Min(200,[int]$defaults.ConsoleBrightness))}catch{$defaults.ConsoleBrightness=100}
    if([string]::IsNullOrWhiteSpace([string]$defaults.ConsoleName)){$defaults.ConsoleName='Huymaier Console'}
    $defaults
}
'@
    $core=Replace-Range $core 'function Load-Config {' 'function Save-Config {' $load 'config loader'
    $save=@'
function Save-Config {
    try{if(-not(Write-HcConfigAtomic -Path $script:ConfigPath -Config $script:Config -Depth 16)){throw 'Settings store did not confirm the write.'}}catch{Write-Log "Config save failed: $($_.Exception.Message)" 'ERROR'}
}
'@
    $core=Replace-Range $core 'function Save-Config {' '$script:Config = Load-Config' $save 'config writer'
    $anchor="        Write-Log 'Huymaier Console closed.'"
    $flush=@'
        try{if(Get-Command Flush-HcModelEditorAutoSave -ErrorAction SilentlyContinue){Flush-HcModelEditorAutoSave}}catch{Write-Log "3D model settings flush on close failed: $($_.Exception.Message)" 'WARN'}
        Write-Log 'Huymaier Console closed.'
'@
    $core=Replace-Required $core $anchor $flush.TrimEnd() 'shutdown model settings flush'
}
Write-Normalized $corePath $core

$customPath=Join-Path $root 'HuymaierCustomization.ps1';$custom=Read-Normalized $customPath
if($custom-notmatch'HUYMAIER_V0308_SETTINGS_DYNAMIC_MERGE_V4'){
    $start="    if(`$null -eq `$script:Config.PSObject.Properties['ConsoleBrightness']){";$end='    try{$script:Config.UiSoundVolume='
    $a=$custom.IndexOf($start,[StringComparison]::Ordinal);if($a-ge0){$b=$custom.IndexOf($end,$a,[StringComparison]::Ordinal);if($b-lt0){throw 'Brightness workaround end anchor missing.'};$custom=$custom.Remove($a,$b-$a)}
    $anchor="    Add-HcCustomizationConfigProperty 'UiSoundVolume' 62";$custom=Replace-Required $custom $anchor (@($anchor,"    Add-HcCustomizationConfigProperty 'ConsoleBrightness' 100 # HUYMAIER_V0308_SETTINGS_DYNAMIC_MERGE_V4")-join$lf) 'brightness config owner'
}
Write-Normalized $customPath $custom

$modelPath=Join-Path $root 'HuymaierConsoleModelPresentation.ps1';$model=Read-Normalized $modelPath
if($model-notmatch'HUYMAIER_V0308_MODEL_SETTINGS_AUTOSAVE_V4'){
    $anchor='$script:HcModelEditorFanPercent=100';$model=Replace-Required $model $anchor (@($anchor,'$script:HcModelEditorAutoSaveTimer=$null # HUYMAIER_V0308_MODEL_SETTINGS_AUTOSAVE_V4','$script:HcModelEditorAutoSaveDirty=$false')-join$lf) 'model autosave state'
    $anchor='function Get-HcModelEditorValueText {'
    $helpers=@'
function Save-HcModelViewSnapshotToConfig {
    param($v)
    if($null-eq$v){return $false}
    [bool](Set-HcModelDefaultView -ModelPath ([string]$script:HcModelViewerModelPath) -Platform ([string]$script:HcModelViewerPlatform) -Yaw $v.Yaw -Pitch $v.Pitch -ScalePercent $v.ScalePercent -Roll $v.Roll -OffsetX $v.OffsetX -OffsetY $v.OffsetY -MirrorX $v.MirrorX -MirrorY $v.MirrorY -MirrorZ $v.MirrorZ -FaceMode $v.FaceMode -LightPercent $v.LightPercent -KeyLightPercent $v.KeyLightPercent -LightAzimuth $v.LightAzimuth -LightElevation $v.LightElevation -LightDistance $v.LightDistance -LightAimXPercent $v.LightAimXPercent -LightAimYPercent $v.LightAimYPercent -ConeDegrees $v.ConeDegrees -ConeSoftnessPercent $v.ConeSoftnessPercent -FalloffPercent $v.FalloffPercent -LightTemperature $v.LightTemperature -AmbientPercent $v.AmbientPercent -SpecularPercent $v.SpecularPercent -HighlightSizePercent $v.HighlightSizePercent -FanPercent $v.FanPercent)
}
function Initialize-HcModelEditorAutoSave {
    if($null-ne$script:HcModelEditorAutoSaveTimer){return};$timer=New-Object System.Windows.Threading.DispatcherTimer;$timer.Interval=[TimeSpan]::FromMilliseconds(650)
    $timer.Add_Tick({try{$script:HcModelEditorAutoSaveTimer.Stop();if($script:HcModelEditorAutoSaveDirty-and$script:HcModelEditorActive){$script:HcModelEditorAutoSaveDirty=$false;[void](Save-HcModelViewSnapshotToConfig (Get-HcModelEditorCurrentView))}}catch{try{Write-Log ('3D model auto-save recovered: '+$_.Exception.Message) 'WARN'}catch{}}});$script:HcModelEditorAutoSaveTimer=$timer
}
function Queue-HcModelEditorAutoSave {if(-not$script:HcModelEditorActive){return};Initialize-HcModelEditorAutoSave;$script:HcModelEditorAutoSaveDirty=$true;$script:HcModelEditorAutoSaveTimer.Stop();$script:HcModelEditorAutoSaveTimer.Start()}
function Stop-HcModelEditorAutoSave {param([switch]$Discard);if($null-ne$script:HcModelEditorAutoSaveTimer){$script:HcModelEditorAutoSaveTimer.Stop()};if($Discard){$script:HcModelEditorAutoSaveDirty=$false}}
function Flush-HcModelEditorAutoSave {if($null-ne$script:HcModelEditorAutoSaveTimer){$script:HcModelEditorAutoSaveTimer.Stop()};if($script:HcModelEditorAutoSaveDirty-and$script:HcModelEditorActive){$script:HcModelEditorAutoSaveDirty=$false;[void](Save-HcModelViewSnapshotToConfig (Get-HcModelEditorCurrentView))}}

'@
    $model=Replace-Required $model $anchor ($helpers+$anchor) 'model autosave helpers'
    $save=@'
function Save-HcModelOrientationEditor {
    if(-not$script:HcModelEditorActive){return};Stop-HcModelEditorAutoSave -Discard;$v=Get-HcModelEditorCurrentView
    if(Save-HcModelViewSnapshotToConfig $v){try{Set-ConsoleNotice ('Saved 3D model presentation for '+$script:HcModelViewerPlatform+'.') 'INFO'}catch{}}
    $script:HcModelEditorOriginalView=Get-HcActiveModelDefaultView;$script:HcModelEditorActive=$false;$script:HcModelViewerSpin=([int]$script:HcModelEditorFanPercent-gt0);Update-HcGpuModelViewerItem;Update-HcModelEditorChrome;try{Update-HcGpuShelfLayout}catch{}
}
'@
    $model=Replace-Range $model 'function Save-HcModelOrientationEditor {' 'function Reset-HcModelOrientationEditor {' $save 'model save'
    $reset=@'
function Reset-HcModelOrientationEditor {
    if(-not$script:HcModelViewerActive-or-not(Test-HcConsoleModelPresentationEditable ([string]$script:HcModelViewerPlatform))){return};Stop-HcModelEditorAutoSave -Discard
    Reset-HcModelDefaultView ([string]$script:HcModelViewerModelPath) ([string]$script:HcModelViewerPlatform);$defaults=Get-HcModelDefaultView ([string]$script:HcModelViewerModelPath) ([string]$script:HcModelViewerPlatform);Set-HcModelPresentationStateFromView $defaults;$script:HcModelEditorOriginalView=$defaults;$script:HcModelEditorActive=$false;$script:HcModelViewerSpin=$true;Update-HcGpuModelViewerItem;Update-HcModelEditorChrome;try{Update-HcGpuShelfLayout}catch{};try{Set-ConsoleNotice ('Reset 3D presentation for '+$script:HcModelViewerPlatform+'.') 'INFO'}catch{}
}
'@
    $model=Replace-Range $model 'function Reset-HcModelOrientationEditor {' 'function Cancel-HcModelOrientationEditor {' $reset 'model reset'
    $cancel=@'
function Cancel-HcModelOrientationEditor {
    if(-not$script:HcModelEditorActive){return};Stop-HcModelEditorAutoSave -Discard
    if($script:HcModelEditorOriginalView){Set-HcModelPresentationStateFromView $script:HcModelEditorOriginalView;[void](Save-HcModelViewSnapshotToConfig $script:HcModelEditorOriginalView)}
    $script:HcModelEditorActive=$false;$script:HcModelViewerSpin=([int]$script:HcModelEditorFanPercent-gt0);Update-HcGpuModelViewerItem;Update-HcModelEditorChrome
}
'@
    $model=Replace-Range $model 'function Cancel-HcModelOrientationEditor {' 'function Step-HcModelEditorField' $cancel 'model cancel'
    $old='    $script:HcModelViewerSpin=$false;Update-HcGpuModelViewerItem;Update-HcModelEditorChrome'
    $new='    $script:HcModelViewerSpin=$false;Queue-HcModelEditorAutoSave;Update-HcGpuModelViewerItem;Update-HcModelEditorChrome'
    $model=Replace-Required $model $old $new 'model adjustment autosave'
    $close=@'
function Close-HcPlatformModelViewer {
    if($script:HcModelEditorActive){Flush-HcModelEditorAutoSave};Stop-HcModelEditorAutoSave -Discard
    $script:HcModelEditorPanel=$null;$script:HcModelEditorPanelText=$null;$script:HcModelEditorOriginalView=$null;& $script:HcPresentationBaseCloseViewer
}
'@
    $model=Replace-Range $model 'function Close-HcPlatformModelViewer {' 'function Apply-ControllerNavigation {' $close 'model close flush'
}
Write-Normalized $modelPath $model

$bootstrapPath=Join-Path $root 'HuymaierBootstrap.ps1';$bootstrap=Read-Normalized $bootstrapPath
if($bootstrap-notmatch'HUYMAIER_V0308_SETTINGS_STORE_PREFLIGHT_V4'){
    $anchor='$backgroundTasksPath=Join-Path $baseDir ''HuymaierBackgroundTasks.ps1'' # HUYMAIER_V0308_BACKGROUND_TASK_PREFLIGHT_V2';$bootstrap=Replace-Required $bootstrap $anchor (@($anchor,'$settingsStorePath=Join-Path $baseDir ''HuymaierSettingsStore.ps1'' # HUYMAIER_V0308_SETTINGS_STORE_PREFLIGHT_V4')-join$lf) 'settings preflight path'
    $anchor="        [pscustomobject]@{Path=`$backgroundTasksPath;Label='Background task HUD and coordinator'},";$bootstrap=Replace-Required $bootstrap $anchor (@($anchor,"        [pscustomobject]@{Path=`$settingsStorePath;Label='Central settings persistence store'},")-join$lf) 'settings preflight entry'
}
Write-Normalized $bootstrapPath $bootstrap

$installerPath=Join-Path $root 'Install-HuymaierConsole.ps1';$installer=Read-Normalized $installerPath
if($installer-notmatch'HUYMAIER_V0308_SETTINGS_STORE_INSTALLER_V4'){$anchor="            'HuymaierBackgroundTasks.ps1', # HUYMAIER_V0308_BACKGROUND_TASK_INSTALLER_V2";$installer=Replace-Required $installer $anchor (@($anchor,"            'HuymaierSettingsStore.ps1', # HUYMAIER_V0308_SETTINGS_STORE_INSTALLER_V4")-join$lf) 'settings installer cache'}
Write-Normalized $installerPath $installer

$installerCorePath=Join-Path $root 'HuymaierInstallerCore.ps1';$installerCore=Read-Normalized $installerCorePath
if($installerCore-notmatch'HUYMAIER_V0308_SETTINGS_STORE_REQUIRED_V4'){
    $anchor="'HuymaierArtworkSources.ps1','HuymaierArtworkSourcesTgdbSchema.ps1','HuymaierArtworkManagement.ps1','HuymaierBackgroundTasks.ps1','HuymaierGameBar.ps1', # HUYMAIER_V0308_ARTWORK_INSTALLER_REQUIRED_V2 HUYMAIER_V0308_BACKGROUND_TASK_REQUIRED_V2"
    $insert="'HuymaierArtworkSources.ps1','HuymaierArtworkSourcesTgdbSchema.ps1','HuymaierArtworkManagement.ps1','HuymaierBackgroundTasks.ps1','HuymaierSettingsStore.ps1','HuymaierGameBar.ps1', # HUYMAIER_V0308_ARTWORK_INSTALLER_REQUIRED_V2 HUYMAIER_V0308_BACKGROUND_TASK_REQUIRED_V2 HUYMAIER_V0308_SETTINGS_STORE_REQUIRED_V4"
    $installerCore=Replace-Required $installerCore $anchor $insert 'settings required payload'
}
Write-Normalized $installerCorePath $installerCore

# Remove only old compatibility scripts with no active production reference.
$retired=@('HuymaierV0262Hardening.ps1','HuymaierV0262ProviderRuntime.ps1','HuymaierV0262Runtime.ps1')
$prod=@(Get-ChildItem -LiteralPath $root -Recurse -File|Where-Object{$rel=$_.FullName.Substring($root.Length).TrimStart([char[]]'\/').Replace('\','/');$rel-notmatch '^(\.git/|\.github/|\.development/|\.build/|\.release/|\.source/|Docs/)' -and $_.Extension-in@('.ps1','.psm1','.psd1','.cs','.cpp','.h','.json','.cmd')})
foreach($name in $retired){$refs=@();foreach($file in $prod){if($file.Name-eq$name){continue};try{if([IO.File]::ReadAllText($file.FullName,[Text.Encoding]::UTF8).IndexOf($name,[StringComparison]::OrdinalIgnoreCase)-ge0){$refs+=$file.FullName}}catch{}};if($refs.Count){throw ('Cannot retire '+$name+'; references remain: '+($refs-join', '))};Remove-Item -LiteralPath (Join-Path $root $name) -Force -ErrorAction SilentlyContinue}

$buildPath=Join-Path $root '.build/Build-HuymaierReleaseCandidate.ps1';$build=Read-Normalized $buildPath
if($build-notmatch'HUYMAIER_V0308_RETIRED_RUNTIME_CLEANUP_V4'){
    $anchor="    'Native\GuideBridge'";$first=$anchor+", # HUYMAIER_V0308_RETIRED_RUNTIME_CLEANUP_V4";$build=Replace-Required $build $anchor (@($first,"    'HuymaierV0262Hardening.ps1',","    'HuymaierV0262ProviderRuntime.ps1',","    'HuymaierV0262Runtime.ps1'")-join$lf) 'candidate retired runtime strip list'
}
Write-Normalized $buildPath $build
Write-Host 'Applied v0.30.8 centralized settings persistence, 3D model auto-save, and production runtime cleanup.'
