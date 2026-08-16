# HUYMAIER_USER_3D_MODELS_RUNTIME_V6
# HUYMAIER_3D_DUAL_SHELF_RUNTIME_V1
# HUYMAIER_3D_TEXTURED_BOUNDED_RESIDENCY_V2
# Authoritative platform/provider presentation owner for v0.26.5.
#
# User-owned GLBs persist outside update payloads in
# %LOCALAPPDATA%\Huymaier Console\3D Models (or a portable 3D Models folder).
# V6 separates storefront providers and console/emulator platforms into two
# compact horizontal shelves. Each shelf remembers its own selection. The
# focused shelf keeps selected + immediate neighbors textured while the other
# shelf keeps only its selected model resident, bounding decoded texture memory
# while preserving two visible rotating selections. Rotation changes only
# Viewport3D transforms; background polling cannot rebuild the active shelves.

Set-StrictMode -Version 2.0

$script:HcPlatformPresentationOwner='HuymaierUser3DModelsV6'
$script:HcUser3DModelsRoot=Join-Path $script:DataDir '3D Models'
$script:HcPortable3DModelsRoot=Join-Path $script:BaseDir '3D Models'
$script:HcUser3DModelsGuidePath=Join-Path $script:HcUser3DModelsRoot 'README - Model Names.txt'

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
$script:HcUserModelsBaseInvokeSecondaryAction=${function:Invoke-SecondaryAction}
$script:HcUserModelsBaseUpdateActionVisuals=${function:Update-ActionVisuals}
$script:HcUserModelsBaseRenderPage=${function:Render-Page}

$script:HcUser3DModelNameMap=$null
$script:Hc3DShelfMounted=$false
$script:Hc3DShelfGeneration=0
$script:Hc3DShelfCards=New-Object System.Collections.ArrayList
$script:Hc3DShelfGroups=@{}
$script:Hc3DShelfLoadQueue=New-Object System.Collections.ArrayList
$script:Hc3DShelfLoadTimer=$null
$script:Hc3DShelfSpinTimer=$null
$script:Hc3DShelfDetail=$null
$script:Hc3DDeferredRefreshCount=0
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
            foreach($line in @('HUYMAIER CONSOLE - 3D MODELS','','Place your .glb files in this folder. Huymaier Console does not bundle large model packs.','The names below match the original Huymaier model pack exactly. Windows filename matching is case-insensitive.','Missing or failed models keep the normal platform icon.','Games 3D mode uses two compact textured shelves: Providers on top and Consoles below.','Each shelf remembers its own selection. The focused shelf loads its selected model plus immediate neighbors; the other shelf retains only its selected model.','Selected shelf models rotate continuously without rebuilding the Games page. X/Square opens the dedicated full-screen viewer.','','Supported original filenames:')){[void]$lines.Add($line)}
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
function Resolve-HcShelfModelPath([string]$Platform,[string]$Group){
    if([string]::IsNullOrWhiteSpace($Platform)){return ''}
    if(-not[string]::Equals($Group,'Providers',[StringComparison]::OrdinalIgnoreCase)){return (Resolve-HcLivePlatformModelPath $Platform)}
    [void](Initialize-HcUser3DModelsFolder)
    $names=New-Object System.Collections.Generic.List[string]
    switch($Platform.ToLowerInvariant()){
        'steam' {[void]$names.Add('Steam.glb')}
        'epic' {[void]$names.Add('Epic Games.glb');[void]$names.Add('Epic.glb')}
        'epic games' {[void]$names.Add('Epic Games.glb')}
        'xbox' {[void]$names.Add('Xbox App.glb');[void]$names.Add('Microsoft Xbox App.glb')}
        'battle.net' {[void]$names.Add('Battle.net.glb');[void]$names.Add('BattleNet.glb')}
        default {[void]$names.Add((($Platform-replace'[\\/:*?"<>|]','_')+'.glb'))}
    }
    foreach($root in @(Get-HcUser3DModelRoots)){
        foreach($name in @($names|Select-Object -Unique)){
            try{$candidate=Join-Path $root $name;if(Test-Path $candidate -PathType Leaf){return (Resolve-Path $candidate).Path}}catch{}
        }
    }
    return ''
}

function Stop-Hc3DShelfTimers {
    if($script:Hc3DShelfLoadTimer){try{$script:Hc3DShelfLoadTimer.Stop()}catch{}}
    if($script:Hc3DShelfSpinTimer){try{$script:Hc3DShelfSpinTimer.Stop()}catch{}}
}
function Reset-Hc3DShelfRuntime {
    Stop-Hc3DShelfTimers
    $script:Hc3DShelfGeneration++
    $script:Hc3DShelfMounted=$false
    $script:Hc3DShelfCards=New-Object System.Collections.ArrayList
    $script:Hc3DShelfGroups=@{}
    $script:Hc3DShelfLoadQueue=New-Object System.Collections.ArrayList
    $script:Hc3DShelfDetail=$null
    $script:HcUser3DQueuedCount=0
    $script:HcUser3DReadyCount=0
    $script:HcUser3DMissingCount=0
    $script:HcUser3DFailedCount=0
}
function Get-Hc3DShelfSelectedCard {
    if(-not$script:Hc3DShelfMounted){return $null}
    foreach($card in @($script:Hc3DShelfCards)){
        if($null-ne$card-and[int]$card.ActionIndex-eq[int]$script:SelectedAction){return $card}
    }
    return $null
}
function Get-Hc3DShelfGroup([string]$Key){
    if([string]::IsNullOrWhiteSpace($Key)-or-not$script:Hc3DShelfGroups.ContainsKey($Key)){return $null}
    return $script:Hc3DShelfGroups[$Key]
}
function Get-Hc3DShelfSelectedCardForGroup([string]$Key){
    $group=Get-Hc3DShelfGroup $Key
    if($null-eq$group-or$group.Cards.Count-le0){return $null}
    $index=[math]::Max(0,[math]::Min($group.Cards.Count-1,[int]$group.SelectedLocalIndex))
    return $group.Cards[$index]
}
function Test-Hc3DCardShouldStayResident($Card,$FocusedCard){
    if($null-eq$Card){return $false}
    $group=Get-Hc3DShelfGroup ([string]$Card.Group)
    if($null-eq$group){return $false}
    $selected=[int]$group.SelectedLocalIndex
    if($null-ne$FocusedCard-and[string]::Equals([string]$FocusedCard.Group,[string]$Card.Group,[StringComparison]::OrdinalIgnoreCase)){
        return ([math]::Abs([int]$Card.ShelfIndex-$selected)-le1)
    }
    return ([int]$Card.ShelfIndex-eq$selected)
}
function Set-Hc3DShelfViewFraming($View,[int]$ScalePercent){
    if($null-eq$View){return}
    # 50..200 user scale maps to 55..70% camera occupancy. 70% is the
    # rotation-safe upper bound proven by the textured pixel gate.
    $safeScale=55.0+(([math]::Max(50,[math]::Min(200,$ScalePercent))-50.0)/150.0)*15.0
    try{$View.SetScalePercent($safeScale)}catch{}
}
function New-Hc3DShelfLiveModelView([string]$Path,[int]$ScalePercent){
    if(-not(Initialize-HcLiveModelAssembly)){return $null}
    try{
        $view=New-Object HuymaierConsole.Modeling.LiveModelView -ArgumentList @($Path)
        Set-Hc3DShelfViewFraming $view $ScalePercent
        return $view
    }catch{
        try{Write-Log ('Textured 3D shelf scene failed for '+$Path+': '+$_.Exception.Message) 'WARN'}catch{}
        return $null
    }
}
function Start-Hc3DShelfLoadTimer {
    if(-not$script:Hc3DShelfLoadTimer){
        $timer=New-Object System.Windows.Threading.DispatcherTimer
        $timer.Interval=[TimeSpan]::FromMilliseconds(120)
        $timer.Add_Tick({try{Update-Hc3DShelfLoadQueue}catch{$script:HcUser3DFailedCount++;try{Write-Log ('3D shelf load tick failed: '+$_.Exception.Message) 'ERROR'}catch{}}})
        $script:Hc3DShelfLoadTimer=$timer
    }
    if(-not$script:Hc3DShelfLoadTimer.IsEnabled){$script:Hc3DShelfLoadTimer.Start()}
}
function Queue-Hc3DShelfCard($Card,[bool]$Front){
    if($null-eq$Card-or$Card.Loading-or$null-ne$Card.View-or$Card.Failed-or[string]::IsNullOrWhiteSpace([string]$Card.Path)){return}
    $Card.Loading=$true
    $request=[pscustomobject]@{Generation=$script:Hc3DShelfGeneration;Card=$Card}
    if($Front){$script:Hc3DShelfLoadQueue.Insert(0,$request)}else{[void]$script:Hc3DShelfLoadQueue.Add($request)}
    $script:HcUser3DQueuedCount++
    Start-Hc3DShelfLoadTimer
}
function Trim-Hc3DShelfResidency($FocusedCard){
    $kept=New-Object System.Collections.ArrayList
    foreach($request in @($script:Hc3DShelfLoadQueue)){
        try{
            if($request-and$request.Card-and(Test-Hc3DCardShouldStayResident $request.Card $FocusedCard)){[void]$kept.Add($request)}
            elseif($request-and$request.Card){$request.Card.Loading=$false}
        }catch{}
    }
    $script:Hc3DShelfLoadQueue=$kept
    foreach($card in @($script:Hc3DShelfCards)){
        if($null-eq$card-or(Test-Hc3DCardShouldStayResident $card $FocusedCard)){continue}
        if($null-ne$card.View){
            try{$card.VisualHost.Child=$card.Icon}catch{}
            $card.View=$null
            $card.Loading=$false
        }
    }
}
function Update-Hc3DShelfLoadQueue {
    if(-not$script:Hc3DShelfMounted-or(Get-HcPlatformVisualStyle)-ne'3D Models'){try{$script:Hc3DShelfLoadTimer.Stop()}catch{};return}
    if($script:Hc3DShelfLoadQueue.Count-le0){try{$script:Hc3DShelfLoadTimer.Stop()}catch{};return}
    $request=$script:Hc3DShelfLoadQueue[0]
    $script:Hc3DShelfLoadQueue.RemoveAt(0)
    if($null-eq$request-or[int]$request.Generation-ne$script:Hc3DShelfGeneration){return}
    $card=$request.Card
    if($null-eq$card){return}
    $card.Loading=$false
    $focused=Get-Hc3DShelfSelectedCard
    if(-not(Test-Hc3DCardShouldStayResident $card $focused)){return}
    if(-not(Test-Path -LiteralPath ([string]$card.Path) -PathType Leaf)){$card.Failed=$true;$script:HcUser3DFailedCount++;return}
    try{
        $view=New-Hc3DShelfLiveModelView ([string]$card.Path) ([int]$script:Config.PlatformModelScale)
        if($null-eq$view){throw 'Textured live model view could not be created.'}
        if([int]$view.GeometryCount-le0-or[int]$view.VertexCount-le0){throw 'Textured live model view reported no renderable geometry.'}
        $card.VisualHost.Child=$view
        $card.View=$view
        $script:HcUser3DReadyCount++
        try{Write-Log ('Textured 3D shelf ready: '+$card.Platform+' group='+$card.Group+' geometry='+[int]$view.GeometryCount+' vertices='+[int]$view.VertexCount+' materials='+[int]$view.MaterialCount+' textures='+[int]$view.TextureCount+' images='+[int]$view.ImageCount)}catch{}
    }catch{
        $card.Failed=$true
        $script:HcUser3DFailedCount++
        try{$card.VisualHost.Child=$card.Icon}catch{}
        try{Write-Log ('3D shelf kept icon for '+$card.Platform+': '+$_.Exception.Message) 'WARN'}catch{}
    }
}
function Start-Hc3DShelfSpinTimer {
    if(-not$script:Hc3DShelfSpinTimer){
        $timer=New-Object System.Windows.Threading.DispatcherTimer
        $timer.Interval=[TimeSpan]::FromMilliseconds(50)
        $timer.Add_Tick({
            try{
                if(-not$script:Hc3DShelfMounted-or(Get-HcPlatformVisualStyle)-ne'3D Models'){return}
                $focused=Get-Hc3DShelfSelectedCard
                foreach($groupKey in @('Providers','Consoles')){
                    $selected=Get-Hc3DShelfSelectedCardForGroup $groupKey
                    if($null-ne$selected-and$null-ne$selected.View){$selected.View.Rotate(.34,0)}
                }
                if($null-ne$focused){
                    $group=Get-Hc3DShelfGroup ([string]$focused.Group)
                    foreach($card in @($group.Cards)){
                        if($null-eq$card.View-or[int]$card.ShelfIndex-eq[int]$group.SelectedLocalIndex){continue}
                        if([math]::Abs([int]$card.ShelfIndex-[int]$group.SelectedLocalIndex)-eq1){$card.View.Rotate(.12,0)}
                    }
                }
            }catch{}
        })
        $script:Hc3DShelfSpinTimer=$timer
    }
    if(-not$script:Hc3DShelfSpinTimer.IsEnabled){$script:Hc3DShelfSpinTimer.Start()}
}
function Queue-Hc3DShelfNeighborhood($FocusedCard){
    foreach($groupKey in @('Providers','Consoles')){
        $group=Get-Hc3DShelfGroup $groupKey
        if($null-eq$group-or$group.Cards.Count-le0){continue}
        $selected=[int]$group.SelectedLocalIndex
        $focusedGroup=($null-ne$FocusedCard-and[string]::Equals([string]$FocusedCard.Group,$groupKey,[StringComparison]::OrdinalIgnoreCase))
        $deltas=$(if($focusedGroup){@(0,1,-1)}else{@(0)})
        foreach($delta in $deltas){
            $index=$selected+$delta
            if($index-lt0-or$index-ge$group.Cards.Count){continue}
            $card=$group.Cards[$index]
            if([string]::IsNullOrWhiteSpace([string]$card.Path)){continue}
            Queue-Hc3DShelfCard $card ($delta-eq0)
        }
    }
}
function Center-Hc3DShelfSelection($FocusedCard){
    if($null-eq$FocusedCard){return}
    $group=Get-Hc3DShelfGroup ([string]$FocusedCard.Group)
    if($null-eq$group-or$null-eq$group.Scroll-or$null-eq$group.Row){return}
    try{
        $group.Row.UpdateLayout();$group.Scroll.UpdateLayout()
        $button=$FocusedCard.Button
        $origin=New-Object System.Windows.Point -ArgumentList 0,0
        $point=$button.TranslatePoint($origin,$group.Row)
        $target=[double]$point.X+([double]$button.ActualWidth/2.0)-([double]$group.Scroll.ViewportWidth/2.0)
        $group.Scroll.ScrollToHorizontalOffset([math]::Max(0,$target))
    }catch{}
}
function Update-Hc3DShelfSelection {
    if(-not$script:Hc3DShelfMounted-or$script:Hc3DShelfCards.Count-le0){return}
    $focused=Get-Hc3DShelfSelectedCard
    if($null-ne$focused){
        $focusGroup=Get-Hc3DShelfGroup ([string]$focused.Group)
        if($null-ne$focusGroup){$focusGroup.SelectedLocalIndex=[int]$focused.ShelfIndex}
        $script:SelectedGamePlatform=[string]$focused.Platform
    }
    Trim-Hc3DShelfResidency $focused
    foreach($groupKey in @('Providers','Consoles')){
        $group=Get-Hc3DShelfGroup $groupKey
        if($null-eq$group){continue}
        $selected=[int]$group.SelectedLocalIndex
        $groupFocused=($null-ne$focused-and[string]::Equals([string]$focused.Group,$groupKey,[StringComparison]::OrdinalIgnoreCase))
        for($i=0;$i-lt$group.Cards.Count;$i++){
            $card=$group.Cards[$i]
            $distance=[math]::Abs($i-$selected)
            if($distance-eq0){
                $card.Button.Width=$(if($groupFocused){286}else{236})
                $card.Button.Height=$(if($groupFocused){178}else{156})
                $card.VisualHost.Height=$(if($groupFocused){108}else{92})
                $card.Button.Opacity=1.0
                $card.Button.BorderBrush=$(if($groupFocused){'#F2D36B'}else{'#7D6B37'})
                $card.Button.BorderThickness=$(if($groupFocused){'3'}else{'2'})
                $card.Label.FontSize=$(if($groupFocused){16}else{14})
                $card.Count.FontSize=9
            }elseif($distance-eq1){
                $card.Button.Width=184;$card.Button.Height=146;$card.VisualHost.Height=86
                $card.Button.Opacity=.72;$card.Button.BorderBrush='#52637A';$card.Button.BorderThickness='1'
                $card.Label.FontSize=12;$card.Count.FontSize=8
            }else{
                $card.Button.Width=142;$card.Button.Height=128;$card.VisualHost.Height=72
                $card.Button.Opacity=.34;$card.Button.BorderBrush='#2D3C50';$card.Button.BorderThickness='1'
                $card.Label.FontSize=11;$card.Count.FontSize=8
            }
            if($null-ne$card.View){Set-Hc3DShelfViewFraming $card.View ([int]$script:Config.PlatformModelScale)}
        }
        $selectedCard=Get-Hc3DShelfSelectedCardForGroup $groupKey
        if($null-ne$group.Header){
            $group.Header.Text=$(if($null-ne$selectedCard){$group.Title+'   •   '+$selectedCard.Platform}else{$group.Title})
            $group.Header.Foreground=$(if($groupFocused){'#E7C45E'}else{'#D8E0EA'})
        }
    }
    if($null-ne$script:Hc3DShelfDetail){
        $script:Hc3DShelfDetail.Text='Left/Right browse   •   Up/Down switch shelf   •   A/Cross open   •   X/Square full-screen model'
    }
    Queue-Hc3DShelfNeighborhood $focused
    Start-Hc3DShelfSpinTimer
    Center-Hc3DShelfSelection $focused
}
function New-Hc3DShelfCard([string]$Platform,[int]$PlatformIndex,[string]$Group,[int]$ShelfIndex,[int]$ActionIndex){
    $button=New-Object System.Windows.Controls.Button
    $button.Tag=('platform-select:'+$PlatformIndex)
    $button.Width=142;$button.Height=128;$button.Margin='7,3';$button.Padding='6'
    $button.Background='#8C0B111C';$button.BorderBrush='#2D3C50';$button.BorderThickness='1';$button.Cursor='Hand'
    $button.RenderTransformOrigin='0.5,0.5'
    $button.Template=[Windows.Markup.XamlReader]::Parse('<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" TargetType="Button"><Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="14" Padding="{TemplateBinding Padding}" ClipToBounds="False"><ContentPresenter HorizontalAlignment="Stretch" VerticalAlignment="Stretch"/></Border></ControlTemplate>')
    $grid=New-Object System.Windows.Controls.Grid
    $grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height='*'}))
    $grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height='Auto'}))
    $grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height='Auto'}))
    $visualHost=New-Object System.Windows.Controls.Border
    $visualHost.Background='Transparent';$visualHost.BorderThickness='0';$visualHost.Height=72
    $visualHost.HorizontalAlignment='Stretch';$visualHost.VerticalAlignment='Stretch';$visualHost.ClipToBounds=$false
    $icon=New-PlatformIconImage $Platform 88
    $icon.HorizontalAlignment='Center';$icon.VerticalAlignment='Center';$visualHost.Child=$icon
    [System.Windows.Controls.Grid]::SetRow($visualHost,0);$grid.Children.Add($visualHost)|Out-Null
    $label=New-Object System.Windows.Controls.TextBlock
    $label.Text=$Platform;$label.FontSize=11;$label.FontWeight='SemiBold';$label.Foreground='White'
    $label.HorizontalAlignment='Center';$label.TextAlignment='Center';$label.TextTrimming='CharacterEllipsis';$label.Margin='3,3,3,0'
    [System.Windows.Controls.Grid]::SetRow($label,1);$grid.Children.Add($label)|Out-Null
    $summary=Get-PlatformCountSummary $Platform
    $count=New-Object System.Windows.Controls.TextBlock
    $count.Text=$(if([bool]$summary.Pending){'SCANNING…'}elseif([int]$summary.Owned-gt[int]$summary.Installed){([int]$summary.Installed).ToString()+' INSTALLED • '+([int]$summary.Owned).ToString()+' OWNED'}else{([int]$summary.Installed).ToString()+' GAMES'})
    $count.FontSize=8;$count.FontWeight='SemiBold';$count.Foreground='#94A6BE';$count.HorizontalAlignment='Center';$count.Margin='2,2,2,1'
    [System.Windows.Controls.Grid]::SetRow($count,2);$grid.Children.Add($count)|Out-Null
    $button.Content=$grid
    $button.Add_Click({param($sender,$eventArgs)try{Set-KeyboardActive;Invoke-UiFeedback 'Confirm';Invoke-Action ([string]$sender.Tag)}catch{try{Write-Log ('3D shelf platform action failed: '+$_.Exception.Message) 'ERROR'}catch{}}})
    $button.Add_MouseEnter({param($sender,$eventArgs)if(-not(Test-HcMouseHoverAllowed)){return};Set-KeyboardActive;$idx=[array]::IndexOf($script:ActionButtons,$sender);if($idx-ge0){$script:SelectedAction=$idx;Update-ActionVisuals}})
    $path=Resolve-HcShelfModelPath $Platform $Group
    if(-not$path){$script:HcUser3DMissingCount++;$button.ToolTip='A/Cross Open platform   •   Add a matching GLB to enable the 3D shelf model'}
    else{$button.ToolTip='A/Cross Open platform   •   X/Square View 3D model'}
    [pscustomobject]@{
        ActionIndex=$ActionIndex;PlatformIndex=$PlatformIndex;ShelfIndex=$ShelfIndex;Group=$Group
        Platform=$Platform;Button=$button;VisualHost=$visualHost;Icon=$icon;Label=$label;Count=$count
        Path=$path;View=$null;Loading=$false;Failed=$false
    }
}
function Add-Hc3DShelfGroup([string]$Key,[string]$Title,[object[]]$Entries){
    if($Entries.Count-le0){return}
    $header=New-Object System.Windows.Controls.TextBlock
    $header.Text=$Title;$header.FontSize=15;$header.FontWeight='SemiBold';$header.Foreground='#D8E0EA';$header.Margin='8,2,0,2'
    $script:ActionPanel.Children.Add($header)|Out-Null

    $row=New-Object System.Windows.Controls.StackPanel
    $row.Orientation='Horizontal';$row.VerticalAlignment='Center';$row.Margin='14,0,14,2'
    $cards=New-Object System.Collections.ArrayList
    $start=$script:ActionButtons.Count
    for($local=0;$local-lt$Entries.Count;$local++){
        $entry=$Entries[$local]
        $platform=[string]$entry.Platform
        $platformIndex=[int]$entry.PlatformIndex
        $actionIndex=$script:ActionButtons.Count
        $card=New-Hc3DShelfCard $platform $platformIndex $Key $local $actionIndex
        [void]$cards.Add($card);[void]$script:Hc3DShelfCards.Add($card)
        $row.Children.Add($card.Button)|Out-Null
        $script:ActionButtons+=$card.Button
        $script:CurrentActions+=(New-Action ('platform-select:'+$platformIndex) $platform)
    }

    $scroll=New-Object System.Windows.Controls.ScrollViewer
    $scroll.Height=188;$scroll.HorizontalScrollBarVisibility='Hidden';$scroll.VerticalScrollBarVisibility='Disabled'
    $scroll.PanningMode='HorizontalOnly';$scroll.Content=$row;$scroll.HorizontalContentAlignment='Left';$scroll.VerticalContentAlignment='Center'
    $script:ActionPanel.Children.Add($scroll)|Out-Null

    $group=[pscustomobject]@{Key=$Key;Title=$Title;Start=$start;Cards=$cards;Row=$row;Scroll=$scroll;Header=$header;SelectedLocalIndex=0}
    $script:Hc3DShelfGroups[$Key]=$group
    $script:HomeRows+=,[pscustomobject]@{Start=$start;Count=$cards.Count;Platform=$true}
}
function Add-Hc3DPlatformShelf {
    $script:Hc3DShelfMounted=$true
    $heading=New-Object System.Windows.Controls.TextBlock
    $heading.Text='Games';$heading.FontSize=28;$heading.FontWeight='Bold';$heading.Foreground='White';$heading.Margin='0,0,0,0'
    $script:ActionPanel.Children.Add($heading)|Out-Null
    $script:Hc3DShelfDetail=New-Object System.Windows.Controls.TextBlock
    $script:Hc3DShelfDetail.FontSize=10;$script:Hc3DShelfDetail.Foreground='#93A5BC';$script:Hc3DShelfDetail.Margin='8,0,0,4'
    $script:ActionPanel.Children.Add($script:Hc3DShelfDetail)|Out-Null

    $providers=New-Object System.Collections.ArrayList
    $consoles=New-Object System.Collections.ArrayList
    for($i=0;$i-lt$script:GameHubPlatforms.Count;$i++){
        $platform=[string]$script:GameHubPlatforms[$i]
        $entry=[pscustomobject]@{Platform=$platform;PlatformIndex=$i}
        if(Test-HcStorefrontPlatform $platform){[void]$providers.Add($entry)}else{[void]$consoles.Add($entry)}
    }
    Add-Hc3DShelfGroup 'Providers' 'Providers' ([object[]]$providers.ToArray())
    Add-Hc3DShelfGroup 'Consoles' 'Consoles' ([object[]]$consoles.ToArray())

    try{Write-Log ('3D dual shelf mounted: owner='+$script:HcPlatformPresentationOwner+'; detected='+(Get-HcDetectedUser3DModelCount)+'; providers='+$providers.Count+'; consoles='+$consoles.Count+'; maxTextureResidency=4')}catch{}
    Update-Hc3DShelfSelection
}

function New-PlatformCard([string]$Platform,[int]$Index){$button=& $script:HcUserModelsBaseNewPlatformCard $Platform $Index;if(-not$button){return $button};if((Get-HcPlatformVisualStyle)-eq'Icons'){$scale=[math]::Max(.60,[math]::Min(1.80,([int]$script:Config.PlatformIconScale)/100.0));$button.LayoutTransform=New-Object System.Windows.Media.ScaleTransform($scale,$scale)};$button}
function Add-PlatformRail {if((Get-HcPlatformVisualStyle)-eq'3D Models'){Add-Hc3DPlatformShelf;return};& $script:HcUserModelsBaseAddPlatformRail}
function Update-ActionVisuals {& $script:HcUserModelsBaseUpdateActionVisuals;if($script:Hc3DShelfMounted-and$script:SelectedTab-eq1-and-not$script:SubPage){Update-Hc3DShelfSelection}}
function Render-Page {if($script:Hc3DShelfMounted-and$script:SelectedTab-eq1-and-not$script:SubPage-and(Get-HcPlatformVisualStyle)-eq'3D Models'){$script:Hc3DDeferredRefreshCount++;if($script:Hc3DDeferredRefreshCount-eq1-or($script:Hc3DDeferredRefreshCount%20)-eq0){try{Write-Log ('Deferred redundant Games 3D shelf rebuild; count='+$script:Hc3DDeferredRefreshCount)}catch{}};return};Reset-Hc3DShelfRuntime;& $script:HcUserModelsBaseRenderPage}

function Add-HcPlatformPresentationSettings($Page){$style=Get-HcPlatformVisualStyle;$detected=Get-HcDetectedUser3DModelCount;$result=New-Object System.Collections.Generic.List[object];$inserted=$false;foreach($item in @($Page.Actions)){$id=[string](Get-EntryProperty $item 'Id' '');if($id-in@('platform-visual-style','platform-icon-scale-slider','platform-model-scale-slider','open-3d-models-folder','3d-models-detected')){continue};[void]$result.Add($item);if(-not$inserted-and$id-eq'customization-preset'){[void]$result.Add((New-Action 'platform-visual-style' ('Platform visuals: '+$style) 'Choose Icons or compact textured 3D shelves for Providers and Consoles.'));[void]$result.Add((New-SliderAction 'platform-icon-scale-slider' 'Icon card size' ([int]$script:Config.PlatformIconScale) 'Scale platform cards while Icons mode is selected.' 60 180));[void]$result.Add((New-SliderAction 'platform-model-scale-slider' '3D shelf model size' ([int]$script:Config.PlatformModelScale) 'Adjust rotation-safe camera framing for the compact 3D shelf models. Models remain inside their viewports while rotating.' 50 200));[void]$result.Add((New-Action 'open-3d-models-folder' ('3D Models Folder - '+$detected+' detected') 'Open the persistent model folder. Use the original Huymaier .glb filenames listed in the README.'));$inserted=$true}};if(-not$inserted){[void]$result.Add((New-Action 'platform-visual-style' ('Platform visuals: '+$style) 'Choose Icons or compact textured 3D shelves for Providers and Consoles.'));[void]$result.Add((New-SliderAction 'platform-icon-scale-slider' 'Icon card size' ([int]$script:Config.PlatformIconScale) 'Scale platform cards while Icons mode is selected.' 60 180));[void]$result.Add((New-SliderAction 'platform-model-scale-slider' '3D shelf model size' ([int]$script:Config.PlatformModelScale) 'Adjust rotation-safe camera framing for the compact 3D shelf models. Models remain inside their viewports while rotating.' 50 200));[void]$result.Add((New-Action 'open-3d-models-folder' ('3D Models Folder - '+$detected+' detected') 'Open the persistent model folder. Use the original Huymaier .glb filenames listed in the README.'))};$Page.Actions=[object[]]$result.ToArray();$Page}
function Get-PageDefinition([int]$Index){$page=& $script:HcUserModelsBaseGetPageDefinition $Index;if(-not$page-or$Index-ne7){return $page};if($script:SubPage-ne'Customization'){return $page};Add-HcPlatformPresentationSettings $page}
function Invoke-Action([string]$Id){switch($Id){'platform-visual-style'{Initialize-HcPlatformPresentationConfig;$script:Config.PlatformVisualStyle=$(if((Get-HcPlatformVisualStyle)-eq'Icons'){'3D Models'}else{'Icons'});Save-Config;try{Write-Log ('Platform visuals changed to '+$script:Config.PlatformVisualStyle+'.')}catch{};Render-Page;return}'platform-icon-scale-slider'{[void](Adjust-SelectedSlider 5);return}'platform-model-scale-slider'{[void](Adjust-SelectedSlider 5);return}'open-3d-models-folder'{$path=Initialize-HcUser3DModelsFolder;try{Start-Process explorer.exe -ArgumentList ('"'+$path+'"')|Out-Null;Set-ConsoleNotice ('3D Models folder opened. '+(Get-HcDetectedUser3DModelCount)+' GLB file(s) detected.') 'INFO'}catch{try{Set-ConsoleNotice ('Could not open 3D Models folder: '+$_.Exception.Message) 'ERROR'}catch{}};return}default{& $script:HcUserModelsBaseInvokeAction $Id}}}
function Adjust-SelectedSlider([int]$Delta){$action=Get-SelectedActionObject;if(-not$action){return $false};$id=[string](Get-EntryProperty $action 'Id' '');switch($id){'platform-icon-scale-slider'{$value=[math]::Max(60,[math]::Min(180,([int]$script:Config.PlatformIconScale)+$Delta));$script:Config.PlatformIconScale=$value}'platform-model-scale-slider'{$value=[math]::Max(50,[math]::Min(200,([int]$script:Config.PlatformModelScale)+$Delta));$script:Config.PlatformModelScale=$value}default{return (& $script:HcUserModelsBaseAdjustSelectedSlider $Delta)}};Save-Config;try{$action.Value=$value;$control=$script:SliderControls[$id];if($control){$control.Slider.Value=$value;$control.Text.Text=($value.ToString()+'%')}}catch{};try{Invoke-UiFeedback 'Navigate'}catch{};$true}
function Apply-ControllerNavigation([int]$Mask,[string]$Direction){try{& $script:HcUserModelsBaseApplyControllerNavigation $Mask $Direction}catch{try{Write-Log ('Controller UI dispatch failed: '+$_.Exception.Message) 'ERROR'}catch{};$script:LastGamepadMask=$Mask;$script:LastDirection='';$script:NextDirectionAt=[datetime]::MinValue}}
function Invoke-SecondaryAction {
    if($script:Hc3DShelfMounted-and$script:SelectedTab-eq1-and-not$script:SubPage){
        $card=Get-Hc3DShelfSelectedCard
        if($null-ne$card){
            if([string]::IsNullOrWhiteSpace([string]$card.Path)){
                try{Set-ConsoleNotice ('No 3D model is installed for '+$card.Platform+'.') 'WARN'}catch{}
                return
            }
            try{
                if(Open-HcPlatformModelViewer ([string]$card.Platform) ([string]$card.Path)){Invoke-UiFeedback 'Confirm'}
            }catch{try{Write-Log ('3D shelf viewer failed for '+$card.Platform+': '+$_.Exception.Message) 'ERROR'}catch{}}
            return
        }
    }
    & $script:HcUserModelsBaseInvokeSecondaryAction
}

Initialize-HcPlatformPresentationConfig
[void](Initialize-HcUser3DModelsFolder)
try{Write-Log ('Platform presentation owner initialized: '+$script:HcPlatformPresentationOwner)}catch{}
