# HUYMAIER_USER_3D_MODELS_RUNTIME_V4
# User-owned live platform model library. Large GLB assets are intentionally
# not shipped with Huymaier Console; users place their own models in a 3D Models
# folder using the original Huymaier model-pack filenames.
#
# V4 is the single owner of platform-card presentation. It bypasses the retired
# static preview/atlas/live card wrappers, keeps the proven layout/editing card
# as its baseline, and upgrades matching cards to real Viewport3D geometry only
# after the Games page is visible. Missing or failed GLBs always keep the icon.

Set-StrictMode -Version 2.0

$script:HcUser3DModelsRoot = Join-Path $script:DataDir '3D Models'
$script:HcPortable3DModelsRoot = Join-Path $script:BaseDir '3D Models'
$script:HcUser3DModelsGuidePath = Join-Path $script:HcUser3DModelsRoot 'README - Model Names.txt'
# Bind once to the pre-3D presentation contract captured by HuymaierPlatformModels.
# This deliberately bypasses the retired static preview/atlas/live card wrappers.
$baseCardVar=Get-Variable -Name HcModelsBaseNewPlatformCard -Scope Script -ErrorAction SilentlyContinue
$baseRailVar=Get-Variable -Name HcModelsBaseAddPlatformRail -Scope Script -ErrorAction SilentlyContinue
$basePageVar=Get-Variable -Name HcModelsBaseGetPageDefinition -Scope Script -ErrorAction SilentlyContinue
$baseActionVar=Get-Variable -Name HcModelsBaseInvokeAction -Scope Script -ErrorAction SilentlyContinue
$script:HcUserModelsBaseNewPlatformCard=$(if($null -ne $baseCardVar -and $null -ne $baseCardVar.Value){$baseCardVar.Value}else{${function:New-PlatformCard}})
$script:HcUserModelsBaseAddPlatformRail=$(if($null -ne $baseRailVar -and $null -ne $baseRailVar.Value){$baseRailVar.Value}else{${function:Add-PlatformRail}})
$script:HcUserModelsBaseGetPageDefinition=$(if($null -ne $basePageVar -and $null -ne $basePageVar.Value){$basePageVar.Value}else{${function:Get-PageDefinition}})
$script:HcUserModelsBaseInvokeAction=$(if($null -ne $baseActionVar -and $null -ne $baseActionVar.Value){$baseActionVar.Value}else{${function:Invoke-Action}})

$script:HcPlatformPresentationOwner='HuymaierUser3DModelsV4'
$script:HcUser3DModelNameMap = $null
$script:HcUser3DCardQueue = New-Object System.Collections.ArrayList
$script:HcUser3DCardTimer = $null
$script:HcUser3DCardGeneration = 0
$script:HcUser3DQueuedCount = 0
$script:HcUser3DReadyCount = 0
$script:HcUser3DMissingCount = 0
$script:HcUser3DFailedCount = 0

function Get-HcUser3DModelNames {
    return @(
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
    $roots=New-Object System.Collections.Generic.List[string]
    [void]$roots.Add($script:HcUser3DModelsRoot)
    if(-not [string]::Equals($script:HcPortable3DModelsRoot,$script:HcUser3DModelsRoot,[StringComparison]::OrdinalIgnoreCase)){[void]$roots.Add($script:HcPortable3DModelsRoot)}
    return [string[]]$roots.ToArray()
}

function Initialize-HcUser3DModelsFolder {
    try {
        if(-not(Test-Path -LiteralPath $script:HcUser3DModelsRoot -PathType Container)){New-Item -ItemType Directory -Path $script:HcUser3DModelsRoot -Force | Out-Null}
        if(-not(Test-Path -LiteralPath $script:HcUser3DModelsGuidePath -PathType Leaf)){
            $lines=New-Object System.Collections.Generic.List[string]
            [void]$lines.Add('HUYMAIER CONSOLE - 3D MODELS')
            [void]$lines.Add('')
            [void]$lines.Add('Place your .glb files in this folder. Huymaier Console does not bundle large model packs.')
            [void]$lines.Add('The names below match the original Huymaier model pack exactly. Windows filename matching is case-insensitive.')
            [void]$lines.Add('Missing or failed models keep the normal icon. No static fake 3D image is substituted.')
            [void]$lines.Add('Games cards use real geometry with lightweight card materials; X/Square opens the full original material/texture viewer.')
            [void]$lines.Add('')
            [void]$lines.Add('Supported original filenames:')
            foreach($name in @(Get-HcUser3DModelNames)){[void]$lines.Add('  '+$name)}
            [void]$lines.Add('')
            [void]$lines.Add('You may replace any file with your own GLB while keeping the same filename.')
            [void]$lines.Add('A portable 3D Models folder beside HuymaierConsole.ps1 is also recognized when present.')
            [IO.File]::WriteAllLines($script:HcUser3DModelsGuidePath,[string[]]$lines.ToArray(),(New-Object Text.UTF8Encoding($false)))
        }
    } catch {try{Write-Log ('3D Models folder could not be prepared: '+$_.Exception.Message) 'WARN'}catch{}}
    return $script:HcUser3DModelsRoot
}

function Get-HcDetectedUser3DModelCount {
    [void](Initialize-HcUser3DModelsFolder)
    $seen=@{}
    foreach($root in @(Get-HcUser3DModelRoots)){
        if(-not(Test-Path -LiteralPath $root -PathType Container)){continue}
        foreach($file in @(Get-ChildItem -LiteralPath $root -Filter '*.glb' -File -ErrorAction SilentlyContinue)){$seen[$file.Name.ToLowerInvariant()]=$true}
    }
    return [int]$seen.Count
}

function Initialize-HcUser3DModelNameMap {
    if($null -ne $script:HcUser3DModelNameMap){return}
    $result=@{}
    try{
        $mapPath=Join-Path $script:BaseDir 'Assets\Models\model-map.json'
        if(Test-Path -LiteralPath $mapPath -PathType Leaf){
            $map=Get-Content -Raw -LiteralPath $mapPath -Encoding UTF8|ConvertFrom-Json
            $sourceModels=Get-EntryProperty $map 'sourceModels' $null
            $models=Get-EntryProperty $map 'models' $null
            if($null -ne $sourceModels){
                foreach($sourceProp in @($sourceModels.PSObject.Properties)){
                    $sourceName=[string]$sourceProp.Name;$file=[string]$sourceProp.Value
                    if([string]::IsNullOrWhiteSpace($sourceName) -or [string]::IsNullOrWhiteSpace($file)){continue}
                    $result[$sourceName.ToLowerInvariant()]=$file
                    if($null -ne $models){
                        $sourceAlias=$models.PSObject.Properties | Where-Object {[string]::Equals([string]$_.Name,$sourceName,[StringComparison]::OrdinalIgnoreCase)} | Select-Object -First 1
                        if($null -ne $sourceAlias){
                            $sourceValue=[string]$sourceAlias.Value
                            foreach($modelProp in @($models.PSObject.Properties)){
                                if([string]::Equals([string]$modelProp.Value,$sourceValue,[StringComparison]::OrdinalIgnoreCase)){$result[([string]$modelProp.Name).ToLowerInvariant()]=$file}
                            }
                        }
                    }
                }
            }
        }
    }catch{try{Write-Log ('3D Models alias map could not be prepared: '+$_.Exception.Message) 'WARN'}catch{}}

    $explicit=@{
        'ps1'='Sony PlayStation.glb';'playstation'='Sony PlayStation.glb';'playstation 1'='Sony PlayStation.glb'
        'ps2'='PlayStation 2.glb';'playstation 2'='PlayStation 2.glb'
        'ps3'='PlayStation 3.glb';'playstation 3'='PlayStation 3.glb'
        'ps4'='Playstation 4.glb';'playstation 4'='Playstation 4.glb'
        'ps5'='Playstation 5.glb';'playstation 5'='Playstation 5.glb'
        'psp'='Sony Playstation Portable.glb';'playstation portable'='Sony Playstation Portable.glb'
        'vita'='Sony Playstation Vita.glb';'playstation vita'='Sony Playstation Vita.glb'
        'original xbox'='Xbox.glb';'xbox 360'='XBOX 360.glb';'xbox one'='Xbox One.glb'
        'gamecube'='Nintendo GameCube.glb';'wii'='Nintendo Wii.glb';'wii u'='Nintendo Wii U.glb';'switch'='Nintendo Switch.glb'
        'snes'='Super Nintendo Entertainment System.glb';'super nintendo'='Super Nintendo Entertainment System.glb'
        'steam'='Steam.glb';'epic'='Epic Games.glb';'epic games'='Epic Games.glb'
    }
    foreach($key in $explicit.Keys){$result[$key]=[string]$explicit[$key]}
    $script:HcUser3DModelNameMap=$result
}

function Get-HcUserModelFileName {
    param([string]$Platform)
    if([string]::IsNullOrWhiteSpace($Platform)){return ''}
    Initialize-HcUser3DModelNameMap
    $key=$Platform.ToLowerInvariant()
    if($script:HcUser3DModelNameMap.ContainsKey($key)){return [string]$script:HcUser3DModelNameMap[$key]}
    return (($Platform -replace '[\\/:*?"<>|]','_')+'.glb')
}

function Resolve-HcLivePlatformModelPath {
    param([string]$Platform)
    if([string]::IsNullOrWhiteSpace($Platform)){return ''}
    [void](Initialize-HcUser3DModelsFolder)
    $names=New-Object System.Collections.Generic.List[string]
    $primary=Get-HcUserModelFileName $Platform
    if(-not [string]::IsNullOrWhiteSpace($primary)){[void]$names.Add($primary)}
    $plain=(($Platform -replace '[\\/:*?"<>|]','_')+'.glb')
    if(-not $names.Contains($plain)){[void]$names.Add($plain)}
    foreach($root in @(Get-HcUser3DModelRoots)){
        foreach($name in @($names | Select-Object -Unique)){
            try{$candidate=Join-Path $root $name;if(Test-Path -LiteralPath $candidate -PathType Leaf){return (Resolve-Path -LiteralPath $candidate).Path}}catch{}
        }
    }
    return ''
}

function Reset-HcUser3DCardQueue {
    $script:HcUser3DCardGeneration++
    $script:HcUser3DCardQueue=New-Object System.Collections.ArrayList
    $script:HcUser3DQueuedCount=0
    $script:HcUser3DReadyCount=0
    $script:HcUser3DMissingCount=0
    $script:HcUser3DFailedCount=0
    if($null -ne $script:HcUser3DCardTimer){try{$script:HcUser3DCardTimer.Stop()}catch{}}
}

function Start-HcUser3DCardTimer {
    if($null -eq $script:HcUser3DCardTimer){
        $timer=New-Object System.Windows.Threading.DispatcherTimer
        $timer.Interval=[TimeSpan]::FromMilliseconds(90)
        $timer.Add_Tick({
            try{Update-HcUser3DCardQueue}
            catch{
                $script:HcUser3DFailedCount++
                try{Write-Log ('Live 3D card queue tick failed: '+$_.Exception.Message) 'ERROR'}catch{}
            }
        })
        $script:HcUser3DCardTimer=$timer
    }
    if(-not $script:HcUser3DCardTimer.IsEnabled){$script:HcUser3DCardTimer.Start()}
}

function Queue-HcUser3DCard {
    param($Button,$VisualHost,[string]$Platform,[string]$Path)
    if($null -eq $Button -or $null -eq $VisualHost -or [string]::IsNullOrWhiteSpace($Path)){return}
    [void]$script:HcUser3DCardQueue.Add([pscustomobject]@{Generation=$script:HcUser3DCardGeneration;Button=$Button;VisualHost=$VisualHost;Platform=$Platform;Path=$Path})
    $script:HcUser3DQueuedCount++
    Start-HcUser3DCardTimer
}

function New-HcUserCardLiveModelView {
    param([string]$Path,[int]$ScalePercent)
    if(-not(Initialize-HcLiveModelAssembly)){return $null}
    try{
        $view=New-Object HuymaierConsole.Modeling.LiveModelView -ArgumentList @($Path,$true)
        $view.SetScalePercent([double]$ScalePercent)
        return $view
    }catch{
        try{Write-Log ('Live 3D card scene failed for '+$Path+': '+$_.Exception.Message) 'WARN'}catch{}
        return $null
    }
}

function Update-HcUser3DCardQueue {
    if((Get-HcPlatformVisualStyle) -ne '3D Models'){
        try{$script:HcUser3DCardTimer.Stop()}catch{}
        $script:HcUser3DCardQueue=New-Object System.Collections.ArrayList
        return
    }
    if($script:HcUser3DCardQueue.Count -le 0){try{$script:HcUser3DCardTimer.Stop()}catch{};return}

    $item=$script:HcUser3DCardQueue[0]
    $script:HcUser3DCardQueue.RemoveAt(0)
    if($null -eq $item -or [int]$item.Generation -ne $script:HcUser3DCardGeneration){return}
    $button=$item.Button;$visualHost=$item.VisualHost;$platform=[string]$item.Platform;$path=[string]$item.Path
    if($null -eq $button -or $null -eq $visualHost -or -not(Test-Path -LiteralPath $path -PathType Leaf)){return}

    $oldChild=$null
    try{$oldChild=$visualHost.Child}catch{}
    try{
        $view=New-HcUserCardLiveModelView $path ([int]$script:Config.PlatformModelScale)
        if($null -eq $view){throw 'Live model view could not be created.'}
        if([int]$view.GeometryCount -le 0 -or [int]$view.VertexCount -le 0){throw 'Live model view reported no renderable geometry.'}
        $visualHost.Background='Transparent';$visualHost.BorderThickness='0';$visualHost.CornerRadius=0;$visualHost.Width=112;$visualHost.Height=96
        $visualHost.Child=$view
        $button.DataContext=[pscustomobject]@{HcLiveModelCard=$true;Platform=$platform;ModelPath=$path;GeometryCount=[int]$view.GeometryCount;VertexCount=[int]$view.VertexCount}
        $button.ToolTip='A/Cross Open platform   X/Square View 3D model'
        $script:HcUser3DReadyCount++
        try{Write-Log ('Live 3D card ready: '+$platform+' geometry='+[int]$view.GeometryCount+' vertices='+[int]$view.VertexCount)}catch{}
    }catch{
        $script:HcUser3DFailedCount++
        try{if($null -ne $oldChild){$visualHost.Child=$oldChild}}catch{}
        try{Write-Log ('Live 3D card kept icon for '+$platform+': '+$_.Exception.Message) 'WARN'}catch{}
    }
}

function New-PlatformCard {
    param([string]$Platform,[int]$Index)
    $button=& $script:HcUserModelsBaseNewPlatformCard $Platform $Index
    if($null -eq $button){return $button}
    if((Get-HcPlatformVisualStyle) -eq 'Icons'){
        $scale=[math]::Max(.60,[math]::Min(1.80,([int]$script:Config.PlatformIconScale)/100.0))
        $button.LayoutTransform=New-Object System.Windows.Media.ScaleTransform($scale,$scale)
        return $button
    }
    $path=Resolve-HcLivePlatformModelPath $Platform
    if([string]::IsNullOrWhiteSpace($path)){
        $script:HcUser3DMissingCount++
        $button.ToolTip='A/Cross Open platform   Add a matching GLB in the 3D Models folder to enable live 3D'
        return $button
    }
    $visualHost=Get-HcPlatformVisualHost $button
    if($null -eq $visualHost){
        $script:HcUser3DFailedCount++
        try{Write-Log ('Live 3D card visual host was not found for '+$Platform) 'WARN'}catch{}
        return $button
    }
    $button.ToolTip='A/Cross Open platform   Loading live 3D model…   X/Square View model'
    Queue-HcUser3DCard $button $visualHost $Platform $path
    return $button
}

function Add-PlatformRail {
    Reset-HcUser3DCardQueue
    & $script:HcUserModelsBaseAddPlatformRail
    if($script:HcUser3DCardQueue.Count -gt 0){Start-HcUser3DCardTimer}
    try{
        Write-Log ('3D platform presentation pass: owner='+$script:HcPlatformPresentationOwner+
            '; style='+(Get-HcPlatformVisualStyle)+
            '; detected='+(Get-HcDetectedUser3DModelCount)+
            '; queued='+$script:HcUser3DQueuedCount+
            '; missing='+$script:HcUser3DMissingCount+
            '; failed='+$script:HcUser3DFailedCount)
    }catch{}
}

function Get-PageDefinition {
    param([int]$Index)
    $page=& $script:HcUserModelsBaseGetPageDefinition $Index
    if($null -eq $page -or $Index -ne 7){return $page}
    $filtered=New-Object System.Collections.Generic.List[object]
    foreach($item in @($page.Actions)){
        $id=[string](Get-EntryProperty $item 'Id' '')
        if($id -in @('platform-visual-style','platform-icon-scale-slider','platform-model-scale-slider','open-3d-models-folder','3d-models-detected')){continue}
        [void]$filtered.Add($item)
    }
    $page.Actions=[object[]]$filtered.ToArray()
    if($script:SubPage -ne 'Customization'){return $page}
    $style=Get-HcPlatformVisualStyle;$detected=Get-HcDetectedUser3DModelCount
    $result=New-Object System.Collections.Generic.List[object];$inserted=$false
    foreach($item in @($page.Actions)){
        [void]$result.Add($item)
        if(-not $inserted -and [string](Get-EntryProperty $item 'Id' '') -eq 'customization-preset'){
            [void]$result.Add((New-Action 'platform-visual-style' ('Platform visuals: '+$style) 'Choose Icons or real live GLB models for Games platform/provider cards. Missing or failed GLBs keep the normal icon.'))
            [void]$result.Add((New-SliderAction 'platform-icon-scale-slider' 'Icon card size' ([int]$script:Config.PlatformIconScale) 'Scale platform cards while Icons mode is selected.' 60 180))
            [void]$result.Add((New-SliderAction 'platform-model-scale-slider' '3D model size' ([int]$script:Config.PlatformModelScale) 'Scale the live GLB geometry inside each platform card.' 50 200))
            [void]$result.Add((New-Action 'open-3d-models-folder' ('3D Models Folder - '+$detected+' detected') 'Open the persistent model folder. Use the original Huymaier .glb filenames listed in the included README.'))
            $inserted=$true
        }
    }
    if(-not $inserted){
        [void]$result.Add((New-Action 'platform-visual-style' ('Platform visuals: '+$style) 'Choose Icons or real live GLB models for Games platform/provider cards. Missing or failed GLBs keep the normal icon.'))
        [void]$result.Add((New-SliderAction 'platform-icon-scale-slider' 'Icon card size' ([int]$script:Config.PlatformIconScale) 'Scale platform cards while Icons mode is selected.' 60 180))
        [void]$result.Add((New-SliderAction 'platform-model-scale-slider' '3D model size' ([int]$script:Config.PlatformModelScale) 'Scale the live GLB geometry inside each platform card.' 50 200))
        [void]$result.Add((New-Action 'open-3d-models-folder' ('3D Models Folder - '+$detected+' detected') 'Open the persistent model folder. Use the original Huymaier .glb filenames listed in the included README.'))
    }
    $page.Actions=[object[]]$result.ToArray();return $page
}

function Invoke-Action {
    param([string]$Id)
    if($Id -eq 'open-3d-models-folder'){
        $path=Initialize-HcUser3DModelsFolder
        try{Start-Process explorer.exe -ArgumentList ('"'+$path+'"') | Out-Null;try{Set-ConsoleNotice ('3D Models folder opened. '+(Get-HcDetectedUser3DModelCount)+' GLB file(s) detected.') 'INFO'}catch{}}
        catch{try{Set-ConsoleNotice ('Could not open 3D Models folder: '+$_.Exception.Message) 'ERROR'}catch{}}
        return
    }
    & $script:HcUserModelsBaseInvokeAction $Id
}

[void](Initialize-HcUser3DModelsFolder)
try{Write-Log ('Platform presentation owner initialized: '+$script:HcPlatformPresentationOwner)}catch{}
