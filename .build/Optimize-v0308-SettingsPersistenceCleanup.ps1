param()
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
# HUYMAIER_V0308_SETTINGS_PERSISTENCE_CLEANUP_TRANSFORM_V1
$root=Split-Path -Parent $PSScriptRoot
$lf="`n"
function Read-Normalized([string]$Path){return ([IO.File]::ReadAllText($Path,[Text.Encoding]::UTF8).Replace("`r`n","`n"))}
function Write-Normalized([string]$Path,[string]$Text){[IO.File]::WriteAllText($Path,$Text.Replace("`n","`r`n"),(New-Object Text.UTF8Encoding($true)))}
function Replace-Required([string]$Text,[string]$Old,[string]$New,[string]$Label){if(-not $Text.Contains($Old)){throw "v0.30.8 settings/cleanup transform anchor missing: $Label"};return $Text.Replace($Old,$New)}
function Replace-FunctionBlock([string]$Text,[string]$Name,[string]$Replacement){
    $marker='function '+$Name+' {'
    $start=$Text.IndexOf($marker,[StringComparison]::Ordinal)
    if($start-lt0){throw "Function not found: $Name"}
    $open=$Text.IndexOf('{',$start)
    $depth=0;$end=-1;$quote=[char]0;$escape=$false
    for($i=$open;$i-lt$Text.Length;$i++){
        $ch=$Text[$i]
        if($quote-ne[char]0){
            if($escape){$escape=$false;continue}
            if($ch-eq'`'){$escape=$true;continue}
            if($ch-eq$quote){$quote=[char]0}
            continue
        }
        if($ch-eq"'"-or$ch-eq'"'){$quote=$ch;continue}
        if($ch-eq'{'){$depth++}
        elseif($ch-eq'}'){$depth--;if($depth-eq0){$end=$i+1;break}}
    }
    if($end-lt0){throw "Could not locate end of function: $Name"}
    while($end-lt$Text.Length-and($Text[$end]-eq"`r"-or$Text[$end]-eq"`n")){$end++}
    return $Text.Remove($start,$end-$start).Insert($start,$Replacement.TrimEnd()+$lf+$lf)
}
function Remove-BraceBlock([string]$Text,[string]$Marker){
    $start=$Text.IndexOf($Marker,[StringComparison]::Ordinal)
    if($start-lt0){return $Text}
    $open=$Text.IndexOf('{',$start);if($open-lt0){throw "Opening brace missing for $Marker"}
    $depth=0;$end=-1;$quote=[char]0;$escape=$false
    for($i=$open;$i-lt$Text.Length;$i++){
        $ch=$Text[$i]
        if($quote-ne[char]0){if($escape){$escape=$false;continue};if($ch-eq'`'){$escape=$true;continue};if($ch-eq$quote){$quote=[char]0};continue}
        if($ch-eq"'"-or$ch-eq'"'){$quote=$ch;continue}
        if($ch-eq'{'){$depth++}elseif($ch-eq'}'){$depth--;if($depth-eq0){$end=$i+1;break}}
    }
    if($end-lt0){throw "Closing brace missing for $Marker"}
    while($end-lt$Text.Length-and($Text[$end]-eq"`r"-or$Text[$end]-eq"`n")){$end++}
    return $Text.Remove($start,$end-$start)
}

# Core settings storage: one persistence owner, no property allowlist.
$corePath=Join-Path $root 'HuymaierConsole.ps1'
$core=Read-Normalized $corePath
if($core-notmatch'HUYMAIER_V0308_SETTINGS_STORE_CORE_V1'){
    $anchor='$script:BackgroundTasksModulePath = Join-Path $script:BaseDir ''HuymaierBackgroundTasks.ps1'' # HUYMAIER_V0308_BACKGROUND_TASK_CORE_V2'
    $insert=@($anchor,'$script:SettingsStoreModulePath = Join-Path $script:BaseDir ''HuymaierSettingsStore.ps1'' # HUYMAIER_V0308_SETTINGS_STORE_CORE_V1')-join$lf
    $core=Replace-Required $core $anchor $insert 'settings store path'
    $anchor='function New-DefaultConfig {'
    $insert=@('if (Test-Path -LiteralPath $script:SettingsStoreModulePath) {','    try { . $script:SettingsStoreModulePath; Repair-HcSettingsStoreArtifacts -Path $script:ConfigPath }','    catch { Write-Log "Settings store load failed: $($_.Exception.Message)" ''ERROR'' }','}',$anchor)-join$lf
    $core=Replace-Required $core $anchor $insert 'settings store early load'
    if($core-notmatch'ConfigSchemaVersion = 2'){
        $core=Replace-Required $core "    [pscustomobject]@{`n        BrowserName = ''" "    [pscustomobject]@{`n        ConfigSchemaVersion = 2`n        BrowserName = ''" 'config schema default'
    }
    if($core-notmatch'ConsoleBrightness = 100'){
        $core=Replace-Required $core '        UiSoundVolume = 62' "        UiSoundVolume = 62`n        ConsoleBrightness = 100" 'console brightness default'
    }
    $load=@'
function Load-Config {
    $defaults=New-DefaultConfig
    try{
        $loaded=Read-HcPersistedConfig -Path $script:ConfigPath
        if($null-ne$loaded){$defaults=Merge-HcPersistedConfig -Defaults $defaults -Loaded $loaded}
    }catch{Write-Log "Config load failed: $($_.Exception.Message)" 'WARN'}
    foreach($collectionName in @('CustomGames','CustomApps','ImportedGames','RecentGames','RecentApps','StorefrontRoots','StorefrontInstallOverrides','ProviderInstallRoots','FavoriteGames','RecompGames','PlatformModelDefaultViews')){
        if($null-ne$defaults.PSObject.Properties[$collectionName]){$defaults.$collectionName=Convert-ToStableArray $defaults.$collectionName}
    }
    try{$defaults.GameBarScale=[math]::Max(70,[math]::Min(140,[int]$defaults.GameBarScale))}catch{$defaults.GameBarScale=100}
    try{$defaults.PlatformIconScale=[math]::Max(60,[math]::Min(180,[int]$defaults.PlatformIconScale))}catch{$defaults.PlatformIconScale=100}
    try{$defaults.PlatformModelScale=[math]::Max(50,[math]::Min(200,[int]$defaults.PlatformModelScale))}catch{$defaults.PlatformModelScale=100}
    if(@('Icons','3D Models')-notcontains[string]$defaults.PlatformVisualStyle){$defaults.PlatformVisualStyle='Icons'}
    try{$defaults.UiSoundVolume=[math]::Max(0,[math]::Min(100,[int]$defaults.UiSoundVolume))}catch{$defaults.UiSoundVolume=62}
    try{$defaults.ConsoleBrightness=[math]::Max(0,[math]::Min(200,[int]$defaults.ConsoleBrightness))}catch{$defaults.ConsoleBrightness=100}
    if([string]::IsNullOrWhiteSpace([string]$defaults.ConsoleName)){$defaults.ConsoleName='Huymaier Console'}
    return $defaults
}
'@
    $core=Replace-FunctionBlock $core 'Load-Config' $load
    $save=@'
function Save-Config {
    try{
        if(-not(Write-HcConfigAtomic -Path $script:ConfigPath -Config $script:Config -Depth 16)){throw 'Settings store did not confirm the write.'}
    }catch{Write-Log "Config save failed: $($_.Exception.Message)" 'ERROR'}
}
'@
    $core=Replace-FunctionBlock $core 'Save-Config' $save
    $anchor="        Save-Config`n        Write-Log 'Huymaier Console closed.'"
    $insert="        try{if(Get-Command Flush-HcModelEditorAutoSave -ErrorAction SilentlyContinue){Flush-HcModelEditorAutoSave}}catch{Write-Log \"3D model settings flush on close failed: `$(`$_.Exception.Message)\" 'WARN'}`n        Save-Config`n        Write-Log 'Huymaier Console closed.'"
    $core=Replace-Required $core $anchor $insert 'shutdown settings flush'
}
Write-Normalized $corePath $core

# Remove the old ConsoleBrightness raw-config workaround. Dynamic merge now owns it.
$customPath=Join-Path $root 'HuymaierCustomization.ps1'
$custom=Read-Normalized $customPath
if($custom-notmatch'HUYMAIER_V0308_SETTINGS_DYNAMIC_MERGE_V1'){
    $marker="    if(`$null -eq `$script:Config.PSObject.Properties['ConsoleBrightness']){"
    if($custom.Contains($marker)){$custom=Remove-BraceBlock $custom $marker}
    $anchor="    Add-HcCustomizationConfigProperty 'UiSoundVolume' 62"
    $insert=@($anchor,"    Add-HcCustomizationConfigProperty 'ConsoleBrightness' 100 # HUYMAIER_V0308_SETTINGS_DYNAMIC_MERGE_V1")-join$lf
    $custom=Replace-Required $custom $anchor $insert 'customization brightness default'
}
Write-Normalized $customPath $custom

# Model editor settings auto-save after a short idle period. Explicit Cancel still
# restores and persists the original snapshot, so auto-save does not remove undo.
$modelPath=Join-Path $root 'HuymaierConsoleModelPresentation.ps1'
$model=Read-Normalized $modelPath
if($model-notmatch'HUYMAIER_V0308_MODEL_SETTINGS_AUTOSAVE_V1'){
    $anchor='$script:HcModelEditorFanPercent=100'
    $insert=@($anchor,'$script:HcModelEditorAutoSaveTimer=$null # HUYMAIER_V0308_MODEL_SETTINGS_AUTOSAVE_V1','$script:HcModelEditorAutoSaveDirty=$false')-join$lf
    $model=Replace-Required $model $anchor $insert 'model autosave state'
    $anchor='function Get-HcModelEditorValueText {'
    $helpers=@'
function Save-HcModelViewSnapshotToConfig {
    param($v)
    if($null-eq$v){return $false}
    return [bool](Set-HcModelDefaultView -ModelPath ([string]$script:HcModelViewerModelPath) -Platform ([string]$script:HcModelViewerPlatform) -Yaw $v.Yaw -Pitch $v.Pitch -ScalePercent $v.ScalePercent -Roll $v.Roll -OffsetX $v.OffsetX -OffsetY $v.OffsetY -MirrorX $v.MirrorX -MirrorY $v.MirrorY -MirrorZ $v.MirrorZ -FaceMode $v.FaceMode -LightPercent $v.LightPercent -KeyLightPercent $v.KeyLightPercent -LightAzimuth $v.LightAzimuth -LightElevation $v.LightElevation -LightDistance $v.LightDistance -LightAimXPercent $v.LightAimXPercent -LightAimYPercent $v.LightAimYPercent -ConeDegrees $v.ConeDegrees -ConeSoftnessPercent $v.ConeSoftnessPercent -FalloffPercent $v.FalloffPercent -LightTemperature $v.LightTemperature -AmbientPercent $v.AmbientPercent -SpecularPercent $v.SpecularPercent -HighlightSizePercent $v.HighlightSizePercent -FanPercent $v.FanPercent)
}
function Initialize-HcModelEditorAutoSave {
    if($null-ne$script:HcModelEditorAutoSaveTimer){return}
    $timer=New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval=[TimeSpan]::FromMilliseconds(650)
    $timer.Add_Tick({
        try{
            $script:HcModelEditorAutoSaveTimer.Stop()
            if($script:HcModelEditorAutoSaveDirty-and$script:HcModelEditorActive){
                $script:HcModelEditorAutoSaveDirty=$false
                [void](Save-HcModelViewSnapshotToConfig (Get-HcModelEditorCurrentView))
            }
        }catch{try{Write-Log ('3D model auto-save recovered: '+$_.Exception.Message) 'WARN'}catch{}}
    })
    $script:HcModelEditorAutoSaveTimer=$timer
}
function Queue-HcModelEditorAutoSave {
    if(-not$script:HcModelEditorActive){return}
    Initialize-HcModelEditorAutoSave
    $script:HcModelEditorAutoSaveDirty=$true
    $script:HcModelEditorAutoSaveTimer.Stop();$script:HcModelEditorAutoSaveTimer.Start()
}
function Stop-HcModelEditorAutoSave {
    param([switch]$Discard)
    if($null-ne$script:HcModelEditorAutoSaveTimer){$script:HcModelEditorAutoSaveTimer.Stop()}
    if($Discard){$script:HcModelEditorAutoSaveDirty=$false}
}
function Flush-HcModelEditorAutoSave {
    if($null-ne$script:HcModelEditorAutoSaveTimer){$script:HcModelEditorAutoSaveTimer.Stop()}
    if($script:HcModelEditorAutoSaveDirty-and$script:HcModelEditorActive){
        $script:HcModelEditorAutoSaveDirty=$false
        [void](Save-HcModelViewSnapshotToConfig (Get-HcModelEditorCurrentView))
    }
}

'@
    $model=Replace-Required $model $anchor ($helpers+$anchor) 'model autosave helpers'
    $model=$model.Replace('    $script:HcModelViewerSpin=$false;Update-HcGpuModelViewerItem;Update-HcModelEditorChrome'+$lf+'}', '    $script:HcModelViewerSpin=$false;Queue-HcModelEditorAutoSave;Update-HcGpuModelViewerItem;Update-HcModelEditorChrome'+$lf+'}')
    if($model-notmatch'Queue-HcModelEditorAutoSave;Update-HcGpuModelViewerItem'){throw 'Model adjustment auto-save hook was not installed.'}
    $saveFn=@'
function Save-HcModelOrientationEditor {
    if(-not$script:HcModelEditorActive){return}
    Stop-HcModelEditorAutoSave -Discard
    $v=Get-HcModelEditorCurrentView
    if(Save-HcModelViewSnapshotToConfig $v){try{Set-ConsoleNotice ('Saved 3D model presentation for '+$script:HcModelViewerPlatform+'.') 'INFO'}catch{}}
    $script:HcModelEditorOriginalView=Get-HcActiveModelDefaultView;$script:HcModelEditorActive=$false;$script:HcModelViewerSpin=([int]$script:HcModelEditorFanPercent-gt0);Update-HcGpuModelViewerItem;Update-HcModelEditorChrome;try{Update-HcGpuShelfLayout}catch{}
}
'@
    $model=Replace-FunctionBlock $model 'Save-HcModelOrientationEditor' $saveFn
    $resetFn=@'
function Reset-HcModelOrientationEditor {
    if(-not$script:HcModelViewerActive-or-not(Test-HcConsoleModelPresentationEditable ([string]$script:HcModelViewerPlatform))){return}
    Stop-HcModelEditorAutoSave -Discard
    Reset-HcModelDefaultView ([string]$script:HcModelViewerModelPath) ([string]$script:HcModelViewerPlatform);$defaults=Get-HcModelDefaultView ([string]$script:HcModelViewerModelPath) ([string]$script:HcModelViewerPlatform);Set-HcModelPresentationStateFromView $defaults;$script:HcModelEditorOriginalView=$defaults;$script:HcModelEditorActive=$false;$script:HcModelViewerSpin=$true;Update-HcGpuModelViewerItem;Update-HcModelEditorChrome;try{Update-HcGpuShelfLayout}catch{};try{Set-ConsoleNotice ('Reset 3D presentation for '+$script:HcModelViewerPlatform+'.') 'INFO'}catch{}
}
'@
    $model=Replace-FunctionBlock $model 'Reset-HcModelOrientationEditor' $resetFn
    $cancelFn=@'
function Cancel-HcModelOrientationEditor {
    if(-not$script:HcModelEditorActive){return}
    Stop-HcModelEditorAutoSave -Discard
    if($script:HcModelEditorOriginalView){
        Set-HcModelPresentationStateFromView $script:HcModelEditorOriginalView
        [void](Save-HcModelViewSnapshotToConfig $script:HcModelEditorOriginalView)
    }
    $script:HcModelEditorActive=$false;$script:HcModelViewerSpin=([int]$script:HcModelEditorFanPercent-gt0);Update-HcGpuModelViewerItem;Update-HcModelEditorChrome
}
'@
    $model=Replace-FunctionBlock $model 'Cancel-HcModelOrientationEditor' $cancelFn
    $closeFn=@'
function Close-HcPlatformModelViewer {
    if($script:HcModelEditorActive){Flush-HcModelEditorAutoSave}
    Stop-HcModelEditorAutoSave -Discard
    $script:HcModelEditorPanel=$null;$script:HcModelEditorPanelText=$null;$script:HcModelEditorOriginalView=$null
    & $script:HcPresentationBaseCloseViewer
}
'@
    $model=Replace-FunctionBlock $model 'Close-HcPlatformModelViewer' $closeFn
}
Write-Normalized $modelPath $model

# Bootstrap + installer know the settings store is a required production module.
$bootstrapPath=Join-Path $root 'HuymaierBootstrap.ps1'
$bootstrap=Read-Normalized $bootstrapPath
if($bootstrap-notmatch'HUYMAIER_V0308_SETTINGS_STORE_PREFLIGHT_V1'){
    $anchor='$backgroundTasksPath=Join-Path $baseDir ''HuymaierBackgroundTasks.ps1'' # HUYMAIER_V0308_BACKGROUND_TASK_PREFLIGHT_V2'
    $insert=@($anchor,'$settingsStorePath=Join-Path $baseDir ''HuymaierSettingsStore.ps1'' # HUYMAIER_V0308_SETTINGS_STORE_PREFLIGHT_V1')-join$lf
    $bootstrap=Replace-Required $bootstrap $anchor $insert 'settings preflight path'
    $anchor="        [pscustomobject]@{Path=`$backgroundTasksPath;Label='Background task HUD and coordinator'},"
    $insert=@($anchor,"        [pscustomobject]@{Path=`$settingsStorePath;Label='Central settings persistence store'},")-join$lf
    $bootstrap=Replace-Required $bootstrap $anchor $insert 'settings preflight entry'
}
Write-Normalized $bootstrapPath $bootstrap

$installerPath=Join-Path $root 'Install-HuymaierConsole.ps1'
$installer=Read-Normalized $installerPath
if($installer-notmatch'HUYMAIER_V0308_SETTINGS_STORE_INSTALLER_V1'){
    $anchor="            'HuymaierBackgroundTasks.ps1', # HUYMAIER_V0308_BACKGROUND_TASK_INSTALLER_V2"
    $insert=@($anchor,"            'HuymaierSettingsStore.ps1', # HUYMAIER_V0308_SETTINGS_STORE_INSTALLER_V1")-join$lf
    $installer=Replace-Required $installer $anchor $insert 'settings installer preflight cache'
}
Write-Normalized $installerPath $installer

$installerCorePath=Join-Path $root 'HuymaierInstallerCore.ps1'
$installerCore=Read-Normalized $installerCorePath
if($installerCore-notmatch'HUYMAIER_V0308_SETTINGS_STORE_REQUIRED_V1'){
    $anchor="'HuymaierArtworkSources.ps1','HuymaierArtworkSourcesTgdbSchema.ps1','HuymaierArtworkManagement.ps1','HuymaierBackgroundTasks.ps1','HuymaierGameBar.ps1', # HUYMAIER_V0308_ARTWORK_INSTALLER_REQUIRED_V2 HUYMAIER_V0308_BACKGROUND_TASK_REQUIRED_V2"
    $insert="'HuymaierArtworkSources.ps1','HuymaierArtworkSourcesTgdbSchema.ps1','HuymaierArtworkManagement.ps1','HuymaierBackgroundTasks.ps1','HuymaierSettingsStore.ps1','HuymaierGameBar.ps1', # HUYMAIER_V0308_ARTWORK_INSTALLER_REQUIRED_V2 HUYMAIER_V0308_BACKGROUND_TASK_REQUIRED_V2 HUYMAIER_V0308_SETTINGS_STORE_REQUIRED_V1"
    $installerCore=Replace-Required $installerCore $anchor $insert 'settings required payload'
    $anchor="    'Native\\GuideBridge\\HuymaierGuideBridge.cpp'"
    $insert=@($anchor,"    'HuymaierV0262Hardening.ps1',","    'HuymaierV0262ProviderRuntime.ps1',","    'HuymaierV0262Runtime.ps1'")-join$lf
    $installerCore=Replace-Required $installerCore $anchor $insert 'retired runtime installer cleanup'
}
Write-Normalized $installerCorePath $installerCore

# Retire unreferenced v0.26.2 compatibility payload. Fail closed if any active
# production source still names one of these files.
$retired=@('HuymaierV0262Hardening.ps1','HuymaierV0262ProviderRuntime.ps1','HuymaierV0262Runtime.ps1')
$productionFiles=@(Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction Stop|Where-Object{
    $rel=$_.FullName.Substring($root.Length).TrimStart('\\','/').Replace('\\','/')
    $rel-notmatch '^(\.git/|\.github/|\.development/|\.build/|\.release/|\.source/|Docs/)' -and $_.Extension -in @('.ps1','.psm1','.psd1','.cs','.cpp','.h','.json','.cmd')
})
foreach($name in $retired){
    $refs=New-Object System.Collections.ArrayList
    foreach($file in $productionFiles){
        if([string]::Equals($file.Name,$name,[StringComparison]::OrdinalIgnoreCase)){continue}
        try{if([IO.File]::ReadAllText($file.FullName,[Text.Encoding]::UTF8).IndexOf($name,[StringComparison]::OrdinalIgnoreCase)-ge0){[void]$refs.Add($file.FullName)}}catch{}
    }
    if($refs.Count-gt0){throw ('Cannot retire '+$name+'; active production references remain: '+(@($refs)-join', '))}
    Remove-Item -LiteralPath (Join-Path $root $name) -Force -ErrorAction SilentlyContinue
}

$buildPath=Join-Path $root '.build/Build-HuymaierReleaseCandidate.ps1'
$build=Read-Normalized $buildPath
if($build-notmatch'HUYMAIER_V0308_RETIRED_RUNTIME_CLEANUP_V1'){
    $anchor="    'Native\\GuideBridge'"
    $insert=@($anchor+", # HUYMAIER_V0308_RETIRED_RUNTIME_CLEANUP_V1","    'HuymaierV0262Hardening.ps1',","    'HuymaierV0262ProviderRuntime.ps1',","    'HuymaierV0262Runtime.ps1'")-join$lf
    $build=Replace-Required $build $anchor $insert 'candidate retired runtime strip list'
}
Write-Normalized $buildPath $build

Write-Host 'Applied v0.30.8 centralized settings persistence, 3D model auto-save, and production runtime cleanup.'
