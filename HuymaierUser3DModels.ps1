# HUYMAIER_USER_3D_MODELS_RUNTIME_V4
# Authoritative platform/provider presentation owner for v0.26.5.
#
# Large GLB assets are user-owned and persist outside update payloads in
# %LOCALAPPDATA%\Huymaier Console\3D Models (or a portable 3D Models folder).
# V4 owns card creation, rail dispatch, Customization settings and their actions.
# Older preview/atlas/live card wrappers remain compatibility helpers only.

Set-StrictMode -Version 2.0

$script:HcPlatformPresentationOwner='HuymaierUser3DModelsV4'
$script:HcUser3DModelsRoot=Join-Path $script:DataDir '3D Models'
$script:HcPortable3DModelsRoot=Join-Path $script:BaseDir '3D Models'
$script:HcUser3DModelsGuidePath=Join-Path $script:HcUser3DModelsRoot 'README - Model Names.txt'

# Bind to the clean pre-3D presentation contract captured by HuymaierPlatformModels.
$baseCardVar=Get-Variable HcModelsBaseNewPlatformCard -Scope Script -ErrorAction SilentlyContinue
$baseRailVar=Get-Variable HcModelsBaseAddPlatformRail -Scope Script -ErrorAction SilentlyContinue
$basePageVar=Get-Variable HcModelsBaseGetPageDefinition -Scope Script -ErrorAction SilentlyContinue
$baseActionVar=Get-Variable HcModelsBaseInvokeAction -Scope Script -ErrorAction SilentlyContinue
$script:HcUserModelsBaseNewPlatformCard=$(if($baseCardVar-and$baseCardVar.Value){$baseCardVar.Value}else{${function:New-PlatformCard}})
$script:HcUserModelsBaseAddPlatformRail=$(if($baseRailVar-and$baseRailVar.Value){$baseRailVar.Value}else{${function:Add-PlatformRail}})
$script:HcUserModelsBaseGetPageDefinition=$(if($basePageVar-and$basePageVar.Value){$basePageVar.Value}else{${function:Get-PageDefinition}})
$script:HcUserModelsBaseInvokeAction=$(if($baseActionVar-and$baseActionVar.Value){$baseActionVar.Value}else{${function:Invoke-Action}})
$script:HcUserModelsBaseAdjustSelectedSlider=${function:Adjust-SelectedSlider}
$script:HcUserModelsBaseApplyControllerNavigation=${function:Apply-ControllerNavigation}

$script:HcUser3DModelNameMap=$null
$script:HcUser3DCardQueue=New-Object System.Collections.ArrayList
$script:HcUser3DCardTimer=$null
$script:HcUser3DCardGeneration=0
$script:HcUser3DQueuedCount=0
$script:HcUser3DReadyCount=0
$script:HcUser3DMissingCount=0
$script:HcUser3DFailedCount=0

function Initialize-HcPlatformPresentationConfig {
    if($null -eq $script:Config.PSObject.Properties['PlatformVisualStyle']){$script:Config|Add-Member PlatformVisualStyle 'Icons' -Force}
    if($null -eq $script:Config.PSObject.Properties['PlatformIconScale']){$script:Config|Add-Member PlatformIconScale 100 -Force}
    if($null -eq $script:Config.PSObject.Properties['PlatformModelScale']){$script:Config|Add-Member PlatformModelScale 100 -Force}
    if([string]$script:Config.PlatformVisualStyle -notin @('Icons','3D Models')){$script:Config.PlatformVisualStyle='Icons'}
    try{$script:Config.PlatformIconScale=[math]::Max(60,[math]::Min(180,[int]$script:Config.PlatformIconScale))}catch{$script:Config.PlatformIconScale=100}
    try{$script:Config.PlatformModelScale=[math]::Max(50,[math]::Min(200,[int]$script:Config.PlatformModelScale))}catch{$script:Config.PlatformModelScale=100}
}
function Get-HcPlatformVisualStyle {Initialize-HcPlatformPresentationConfig;return [string]$script:Config.PlatformVisualStyle}

function Get-HcUser3DModelNames {
    @(
        'Arcade.glb','Atari 2600.glb','Atari Lynx.glb','Epic Games.glb','Neo Geo Pocket Color.glb','Neo Geo.glb',
        'Nintendo 3DS.glb','Nintendo 64.glb','Nintendo DS.glb','Nintendo DSI.glb','Nintendo Entertainment System.glb',
        'Nintendo Game Boy Advance.glb','Nintendo Game Boy Color.glb','Nintendo Game Boy.glb','Nintendo GameCube.glb',
        'Nintendo Switch.glb','Nintendo Wii U.glb','Nintendo Wii.glb','PlayStation 2.glb','PlayStation 3.glb','Playstation 4.glb',
        'Playstation 5.glb','Sega Dreamcast.glb','Sega Genesis.glb','Sega Logo.glb','Sega Master System.glb','Sega Mega Drive.glb',
        'Sega Saturn.glb','Sony Playstation Portable.glb','Sony Playstation Vita.glb','Sony PlayStation.glb','Steam.glb',
        'Super Nintendo Entertainment System.glb','XBOX 360.glb','Xbox One.glb','Xbox.glb'
    )
}
function Get-HcUser3DModelRoots {
    $roots=New-Object System.Collections.Generic.List[string];[void]$roots.Add($script:HcUser3DModelsRoot)
    if(-not[string]::Equals($script:HcPortable3DModelsRoot,$script:HcUser3DModelsRoot,[StringComparison]::OrdinalIgnoreCase)){[void]$roots.Add($script:HcPortable3DModelsRoot)}
    [string[]]$roots.ToArray()
}
function Initialize-HcUser3DModelsFolder {
    try{
        if(-not(Test-Path $script:HcUser3DModelsRoot -PathType Container)){New-Item -ItemType Directory -Path $script:HcUser3DModelsRoot -Force|Out-Null}
        if(-not(Test-Path $script:HcUser3DModelsGuidePath -PathType Leaf)){
            $lines=New-Object System.Collections.Generic.List[string]
            foreach($line in @('HUYMAIER CONSOLE - 3D MODELS','','Place your .glb files in this folder. Huymaier Console does not bundle large model packs.','The names below match the original Huymaier model pack exactly. Windows filename matching is case-insensitive.','Missing or failed models keep the normal icon. No static fake 3D image is substituted.','Games cards use real geometry with lightweight card materials; X/Square opens the full original material/texture viewer.','','Supported original filenames:')){[void]$lines.Add($line)}
            foreach($name in @(Get-HcUser3DModelNames)){[void]$lines.Add('  '+$name)}
            foreach($line in @('','You may replace any file with your own GLB while keeping the same filename.','A portable 3D Models folder beside HuymaierConsole.ps1 is also recognized when present.')){[void]$lines.Add($line)}
            [IO.File]::WriteAllLines($script:HcUser3DModelsGuidePath,[string[]]$lines.ToArray(),(New-Object Text.UTF8Encoding($false)))
        }
    }catch{try{Write-Log ('3D Models folder could not be prepared: '+$_.Exception.Message) 'WARN'}catch{}}
    $script:HcUser3DModelsRoot
}
function Get-HcDetectedUser3DModelCount {
    [void](Initialize-HcUser3DModelsFolder);$seen=@{}
    foreach($root in @(Get-HcUser3DModelRoots)){if(-not(Test-Path $root -PathType Container)){continue};foreach($file in @(Get-ChildItem $root -Filter '*.glb' -File -ErrorAction SilentlyContinue)){$seen[$file.Name.ToLowerInvariant()]=$true}}
    [int]$seen.Count
}

function Initialize-HcUser3DModelNameMap {
    if($null-ne$script:HcUser3DModelNameMap){return}
    $result=@{}
    try{
        $mapPath=Join-Path $script:BaseDir 'Assets\Models\model-map.json'
        if(Test-Path $mapPath -PathType Leaf){
            $map=Get-Content -Raw $mapPath -Encoding UTF8|ConvertFrom-Json;$sourceModels=Get-EntryProperty $map 'sourceModels' $null;$models=Get-EntryProperty $map 'models' $null
            if($sourceModels){foreach($sourceProp in @($sourceModels.PSObject.Properties)){$sourceName=[string]$sourceProp.Name;$file=[string]$sourceProp.Value;if(-not$sourceName-or-not$file){continue};$result[$sourceName.ToLowerInvariant()]=$file;if($models){$sourceAlias=$models.PSObject.Properties|Where-Object{[string]::Equals([string]$_.Name,$sourceName,[StringComparison]::OrdinalIgnoreCase)}|Select-Object -First 1;if($sourceAlias){$sourceValue=[string]$sourceAlias.Value;foreach($modelProp in @($models.PSObject.Properties)){if([string]::Equals([string]$modelProp.Value,$sourceValue,[StringComparison]::OrdinalIgnoreCase)){$result[([string]$modelProp.Name).ToLowerInvariant()]=$file}}}}}}
        }
    }catch{try{Write-Log ('3D Models alias map could not be prepared: '+$_.Exception.Message) 'WARN'}catch{}}
    $explicit=@{
        'ps1'='Sony PlayStation.glb';'playstation'='Sony PlayStation.glb';'playstation 1'='Sony PlayStation.glb';'ps2'='PlayStation 2.glb';'playstation 2'='PlayStation 2.glb';'ps3'='PlayStation 3.glb';'playstation 3'='PlayStation 3.glb';'ps4'='Playstation 4.glb';'playstation 4'='Playstation 4.glb';'ps5'='Playstation 5.glb';'playstation 5'='Playstation 5.glb';'psp'='Sony Playstation Portable.glb';'playstation portable'='Sony Playstation Portable.glb';'vita'='Sony Playstation Vita.glb';'playstation vita'='Sony Playstation Vita.glb';'original xbox'='Xbox.glb';'xbox 360'='XBOX 360.glb';'xbox one'='Xbox One.glb';'gamecube'='Nintendo GameCube.glb';'wii'='Nintendo Wii.glb';'wii u'='Nintendo Wii U.glb';'switch'='Nintendo Switch.glb';'snes'='Super Nintendo Entertainment System.glb';'super nintendo'='Super Nintendo Entertainment System.glb';'steam'='Steam.glb';'epic'='Epic Games.glb';'epic games'='Epic Games.glb'
    }
    foreach($key in $explicit.Keys){$result[$key]=[string]$explicit[$key]};$script:HcUser3DModelNameMap=$result
}
function Get-HcUserModelFileName([string]$Platform){if([string]::IsNullOrWhiteSpace($Platform)){return ''};Initialize-HcUser3DModelNameMap;$key=$Platform.ToLowerInvariant();if($script:HcUser3DModelNameMap.ContainsKey($key)){return [string]$script:HcUser3DModelNameMap[$key]};(($Platform-replace'[\\/:*?"<>|]','_')+'.glb')}
function Resolve-HcLivePlatformModelPath([string]$Platform){
    if([string]::IsNullOrWhiteSpace($Platform)){return ''};[void](Initialize-HcUser3DModelsFolder);$names=New-Object System.Collections.Generic.List[string];$primary=Get-HcUserModelFileName $Platform;if($primary){[void]$names.Add($primary)};$plain=(($Platform-replace'[\\/:*?"<>|]','_')+'.glb');if(-not$names.Contains($plain)){[void]$names.Add($plain)}
    foreach($root in @(Get-HcUser3DModelRoots)){foreach($name in @($names|Select-Object -Unique)){try{$candidate=Join-Path $root $name;if(Test-Path $candidate -PathType Leaf){return (Resolve-Path $candidate).Path}}catch{}}};''
}

function Reset-HcUser3DCardQueue {$script:HcUser3DCardGeneration++;$script:HcUser3DCardQueue=New-Object System.Collections.ArrayList;$script:HcUser3DQueuedCount=0;$script:HcUser3DReadyCount=0;$script:HcUser3DMissingCount=0;$script:HcUser3DFailedCount=0;if($script:HcUser3DCardTimer){try{$script:HcUser3DCardTimer.Stop()}catch{}}}
function Start-HcUser3DCardTimer {
    if(-not$script:HcUser3DCardTimer){$timer=New-Object System.Windows.Threading.DispatcherTimer;$timer.Interval=[TimeSpan]::FromMilliseconds(90);$timer.Add_Tick({try{Update-HcUser3DCardQueue}catch{$script:HcUser3DFailedCount++;try{Write-Log ('Live 3D card queue tick failed: '+$_.Exception.Message) 'ERROR'}catch{}}});$script:HcUser3DCardTimer=$timer};if(-not$script:HcUser3DCardTimer.IsEnabled){$script:HcUser3DCardTimer.Start()}
}
function Queue-HcUser3DCard($Button,$VisualHost,[string]$Platform,[string]$Path){if(-not$Button-or-not$VisualHost-or[string]::IsNullOrWhiteSpace($Path)){return};[void]$script:HcUser3DCardQueue.Add([pscustomobject]@{Generation=$script:HcUser3DCardGeneration;Button=$Button;VisualHost=$VisualHost;Platform=$Platform;Path=$Path});$script:HcUser3DQueuedCount++;Start-HcUser3DCardTimer}
function New-HcUserCardLiveModelView([string]$Path,[int]$ScalePercent){if(-not(Initialize-HcLiveModelAssembly)){return $null};try{$view=New-Object HuymaierConsole.Modeling.LiveModelView -ArgumentList @($Path,$true);$view.SetScalePercent([double]$ScalePercent);$view}catch{try{Write-Log ('Live 3D card scene failed for '+$Path+': '+$_.Exception.Message) 'WARN'}catch{};$null}}
function Update-HcUser3DCardQueue {
    if((Get-HcPlatformVisualStyle)-ne'3D Models'){try{$script:HcUser3DCardTimer.Stop()}catch{};$script:HcUser3DCardQueue=New-Object System.Collections.ArrayList;return}
    if($script:HcUser3DCardQueue.Count-le0){try{$script:HcUser3DCardTimer.Stop()}catch{};return}
    $item=$script:HcUser3DCardQueue[0];$script:HcUser3DCardQueue.RemoveAt(0);if(-not$item-or[int]$item.Generation-ne$script:HcUser3DCardGeneration){return}
    $button=$item.Button;$visualHost=$item.VisualHost;$platform=[string]$item.Platform;$path=[string]$item.Path;if(-not$button-or-not$visualHost-or-not(Test-Path $path -PathType Leaf)){return}
    $oldChild=$null;try{$oldChild=$visualHost.Child}catch{}
    try{$view=New-HcUserCardLiveModelView $path ([int]$script:Config.PlatformModelScale);if($null-eq$view){throw 'Live model view could not be created.'};if([int]$view.GeometryCount-le0-or[int]$view.VertexCount-le0){throw 'Live model view reported no renderable geometry.'};$visualHost.Background='Transparent';$visualHost.BorderThickness='0';$visualHost.CornerRadius=0;$visualHost.Width=112;$visualHost.Height=96;$visualHost.Child=$view;$button.DataContext=[pscustomobject]@{HcLiveModelCard=$true;Platform=$platform;ModelPath=$path;GeometryCount=[int]$view.GeometryCount;VertexCount=[int]$view.VertexCount};$button.ToolTip='A/Cross Open platform   X/Square View 3D model';$script:HcUser3DReadyCount++;try{Write-Log ('Live 3D card ready: '+$platform+' geometry='+[int]$view.GeometryCount+' vertices='+[int]$view.VertexCount)}catch{}}
    catch{$script:HcUser3DFailedCount++;try{if($oldChild){$visualHost.Child=$oldChild}}catch{};try{Write-Log ('Live 3D card kept icon for '+$platform+': '+$_.Exception.Message) 'WARN'}catch{}}
}

function New-PlatformCard([string]$Platform,[int]$Index){
    $button=& $script:HcUserModelsBaseNewPlatformCard $Platform $Index;if(-not$button){return $button}
    if((Get-HcPlatformVisualStyle)-eq'Icons'){$scale=[math]::Max(.60,[math]::Min(1.80,([int]$script:Config.PlatformIconScale)/100.0));$button.LayoutTransform=New-Object System.Windows.Media.ScaleTransform($scale,$scale);return $button}
    $path=Resolve-HcLivePlatformModelPath $Platform;if(-not$path){$script:HcUser3DMissingCount++;$button.ToolTip='A/Cross Open platform   Add a matching GLB in the 3D Models folder to enable live 3D';return $button}
    $visualHost=Get-HcPlatformVisualHost $button;if(-not$visualHost){$script:HcUser3DFailedCount++;try{Write-Log ('Live 3D card visual host was not found for '+$Platform) 'WARN'}catch{};return $button}
    $button.ToolTip='A/Cross Open platform   Loading live 3D model…   X/Square View model';Queue-HcUser3DCard $button $visualHost $Platform $path;$button
}
function Add-PlatformRail {
    Reset-HcUser3DCardQueue;& $script:HcUserModelsBaseAddPlatformRail;if($script:HcUser3DCardQueue.Count-gt0){Start-HcUser3DCardTimer}
    try{Write-Log ('3D platform presentation pass: owner='+$script:HcPlatformPresentationOwner+'; style='+(Get-HcPlatformVisualStyle)+'; detected='+(Get-HcDetectedUser3DModelCount)+'; queued='+$script:HcUser3DQueuedCount+'; missing='+$script:HcUser3DMissingCount+'; failed='+$script:HcUser3DFailedCount)}catch{}
}

function Add-HcPlatformPresentationSettings($Page){
    $style=Get-HcPlatformVisualStyle;$detected=Get-HcDetectedUser3DModelCount;$result=New-Object System.Collections.Generic.List[object];$inserted=$false
    foreach($item in @($Page.Actions)){$id=[string](Get-EntryProperty $item 'Id' '');if($id-in@('platform-visual-style','platform-icon-scale-slider','platform-model-scale-slider','open-3d-models-folder','3d-models-detected')){continue};[void]$result.Add($item);if(-not$inserted-and$id-eq'customization-preset'){[void]$result.Add((New-Action 'platform-visual-style' ('Platform visuals: '+$style) 'Choose Icons or real live GLB models for Games platform/provider cards. Missing or failed GLBs keep the normal icon.'));[void]$result.Add((New-SliderAction 'platform-icon-scale-slider' 'Icon card size' ([int]$script:Config.PlatformIconScale) 'Scale platform cards while Icons mode is selected.' 60 180));[void]$result.Add((New-SliderAction 'platform-model-scale-slider' '3D model size' ([int]$script:Config.PlatformModelScale) 'Scale live GLB geometry inside each platform card.' 50 200));[void]$result.Add((New-Action 'open-3d-models-folder' ('3D Models Folder - '+$detected+' detected') 'Open the persistent model folder. Use the original Huymaier .glb filenames listed in the README.'));$inserted=$true}}
    if(-not$inserted){[void]$result.Add((New-Action 'platform-visual-style' ('Platform visuals: '+$style) 'Choose Icons or real live GLB models for Games platform/provider cards. Missing or failed GLBs keep the normal icon.'));[void]$result.Add((New-SliderAction 'platform-icon-scale-slider' 'Icon card size' ([int]$script:Config.PlatformIconScale) 'Scale platform cards while Icons mode is selected.' 60 180));[void]$result.Add((New-SliderAction 'platform-model-scale-slider' '3D model size' ([int]$script:Config.PlatformModelScale) 'Scale live GLB geometry inside each platform card.' 50 200));[void]$result.Add((New-Action 'open-3d-models-folder' ('3D Models Folder - '+$detected+' detected') 'Open the persistent model folder. Use the original Huymaier .glb filenames listed in the README.'))}
    $Page.Actions=[object[]]$result.ToArray();$Page
}
function Get-PageDefinition([int]$Index){$page=& $script:HcUserModelsBaseGetPageDefinition $Index;if(-not$page-or$Index-ne7){return $page};if($script:SubPage-ne'Customization'){return $page};Add-HcPlatformPresentationSettings $page}

function Invoke-Action([string]$Id){
    switch($Id){
        'platform-visual-style' {Initialize-HcPlatformPresentationConfig;$script:Config.PlatformVisualStyle=$(if((Get-HcPlatformVisualStyle)-eq'Icons'){'3D Models'}else{'Icons'});Save-Config;try{Write-Log ('Platform visuals changed to '+$script:Config.PlatformVisualStyle+'.')}catch{};Render-Page;return}
        'platform-icon-scale-slider' {[void](Adjust-SelectedSlider 5);return}
        'platform-model-scale-slider' {[void](Adjust-SelectedSlider 5);return}
        'open-3d-models-folder' {$path=Initialize-HcUser3DModelsFolder;try{Start-Process explorer.exe -ArgumentList ('"'+$path+'"')|Out-Null;Set-ConsoleNotice ('3D Models folder opened. '+(Get-HcDetectedUser3DModelCount)+' GLB file(s) detected.') 'INFO'}catch{try{Set-ConsoleNotice ('Could not open 3D Models folder: '+$_.Exception.Message) 'ERROR'}catch{}};return}
        default {& $script:HcUserModelsBaseInvokeAction $Id}
    }
}
function Adjust-SelectedSlider([int]$Delta){
    $action=Get-SelectedActionObject;if(-not$action){return $false};$id=[string](Get-EntryProperty $action 'Id' '')
    switch($id){
        'platform-icon-scale-slider' {$value=[math]::Max(60,[math]::Min(180,([int]$script:Config.PlatformIconScale)+$Delta));$script:Config.PlatformIconScale=$value}
        'platform-model-scale-slider' {$value=[math]::Max(50,[math]::Min(200,([int]$script:Config.PlatformModelScale)+$Delta));$script:Config.PlatformModelScale=$value}
        default {return (& $script:HcUserModelsBaseAdjustSelectedSlider $Delta)}
    }
    Save-Config;try{$action.Value=$value;$control=$script:SliderControls[$id];if($control){$control.Slider.Value=$value;$control.Text.Text=($value.ToString()+'%')}}catch{};try{Invoke-UiFeedback 'Navigate'}catch{};$true
}

# Final UI dispatch boundary: native polling failures remain native-poll failures;
# page/action/render failures are logged accurately and cannot masquerade as a
# controller-backend failure in Process-Gamepads.
function Apply-ControllerNavigation([int]$Mask,[string]$Direction){
    try{& $script:HcUserModelsBaseApplyControllerNavigation $Mask $Direction}
    catch{try{Write-Log ('Controller UI dispatch failed: '+$_.Exception.Message) 'ERROR'}catch{};$script:LastGamepadMask=$Mask;$script:LastDirection='';$script:NextDirectionAt=[datetime]::MinValue}
}

Initialize-HcPlatformPresentationConfig
[void](Initialize-HcUser3DModelsFolder)
try{Write-Log ('Platform presentation owner initialized: '+$script:HcPlatformPresentationOwner)}catch{}
