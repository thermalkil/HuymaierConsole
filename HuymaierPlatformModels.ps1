# Huymaier Console platform/provider 3D model presentation.
# Keeps the existing icon cards as the default and fallback. When 3D Models is
# selected, a separate x64 worker renders the supplied GLB assets into cached,
# transparent card previews without blocking the shell UI thread.
Set-StrictMode -Version 2.0

$script:HcModelsBaseNewPlatformCard=${function:New-PlatformCard}
$script:HcModelsBaseGetPageDefinition=${function:Get-PageDefinition}
$script:HcModelsBaseInvokeAction=${function:Invoke-Action}
$script:HcModelsBaseAddPlatformRail=${function:Add-PlatformRail}
$script:HcModelsBaseUpdateActionVisuals=${function:Update-ActionVisuals}
$script:HcModelMap=$null
$script:HcModelMapPath=''
$script:HcModelPreviewWorkerPath=Join-Path $script:BaseDir 'HuymaierModelPreviewWorker.exe'
$script:HcModelPreviewCacheRoot=Join-Path $script:DataDir '3DModelCache'
$script:HcModelPreviewQueue=New-Object System.Collections.ArrayList
$script:HcModelPreviewTargets=@{}
$script:HcModelPreviewQueued=@{}
$script:HcModelPreviewProcess=$null
$script:HcModelPreviewActiveItem=$null
$script:HcModelPreviewTimer=$null

function Initialize-HcPlatformModelConfig {
    if($null -eq $script:Config.PSObject.Properties['PlatformVisualStyle']){
        $script:Config|Add-Member -NotePropertyName 'PlatformVisualStyle' -NotePropertyValue 'Icons' -Force
    }
    $value=[string](Get-EntryProperty $script:Config 'PlatformVisualStyle' 'Icons')
    if($value -notin @('Icons','3D Models')){$script:Config.PlatformVisualStyle='Icons'}
    try{New-Item -ItemType Directory -Path $script:HcModelPreviewCacheRoot -Force|Out-Null}catch{}
}

function Get-HcPlatformVisualStyle {
    Initialize-HcPlatformModelConfig
    return [string](Get-EntryProperty $script:Config 'PlatformVisualStyle' 'Icons')
}

function Get-HcModelPackCandidates {
    return @(
        (Join-Path $script:DataDir 'Models'),
        (Join-Path $script:BaseDir 'Assets\Models')
    )
}

function Get-HcModelPackRoot {
    foreach($root in @(Get-HcModelPackCandidates)){
        if(-not $root){continue}
        $map=Join-Path $root 'model-map.json'
        if(Test-Path -LiteralPath $map -PathType Leaf){return $root}
    }
    return ''
}

function Initialize-HcModelMap {
    $root=Get-HcModelPackRoot
    $mapPath=$(if($root){Join-Path $root 'model-map.json'}else{''})
    if($script:HcModelMap -and [string]::Equals($script:HcModelMapPath,$mapPath,[StringComparison]::OrdinalIgnoreCase)){return}
    $script:HcModelMap=@{};$script:HcModelMapPath=$mapPath
    if(-not $mapPath){return}
    try{
        $json=Get-Content -Raw -LiteralPath $mapPath -Encoding UTF8|ConvertFrom-Json
        $models=Get-EntryProperty $json 'models' $null
        if($null -ne $models){
            foreach($property in @($models.PSObject.Properties)){
                $key=[string]$property.Name;$file=[string]$property.Value
                if($key -and $file){$script:HcModelMap[$key.ToLowerInvariant()]=$file}
            }
        }
    }catch{Write-Log ('3D model map could not be read: '+$_.Exception.Message) 'WARN'}
}

function Test-HcModelPackAvailable {
    Initialize-HcModelMap
    if($script:HcModelMap.Count -eq 0){return $false}
    $root=Get-HcModelPackRoot
    if(-not $root){return $false}
    foreach($file in @($script:HcModelMap.Values|Select-Object -Unique)){if($file -and (Test-Path -LiteralPath (Join-Path $root ([string]$file)) -PathType Leaf)){return $true}}
    return $false
}

function Resolve-HcPlatformModelPath {
    param([string]$Platform)
    if(-not $Platform){return ''}
    Initialize-HcModelMap
    if($script:HcModelMap.Count -eq 0){return ''}
    $aliases=New-Object System.Collections.ArrayList
    [void]$aliases.Add($Platform)
    switch -Regex ($Platform){
        '^(?i)Xbox$' {if(Test-HcStorefrontPlatform $Platform){[void]$aliases.Insert(0,'Xbox App')}else{[void]$aliases.Add('Original Xbox')}}
        '^(?i)Epic$' {[void]$aliases.Add('Epic Games')}
        '^(?i)Amazon$' {[void]$aliases.Add('Amazon Games')}
        '^(?i)EA$' {[void]$aliases.Add('EA app')}
        '^(?i)BattleNet$' {[void]$aliases.Add('Battle.net')}
        '^(?i)Rockstar$' {[void]$aliases.Add('Rockstar Games')}
    }
    $root=Get-HcModelPackRoot
    foreach($alias in @($aliases)){
        $key=([string]$alias).ToLowerInvariant()
        if(-not $script:HcModelMap.ContainsKey($key)){continue}
        $file=[string]$script:HcModelMap[$key]
        $path=Join-Path $root $file
        if(Test-Path -LiteralPath $path -PathType Leaf){return $path}
    }
    return ''
}

function Get-HcModelPreviewCachePath {
    param([string]$ModelPath)
    if(-not $ModelPath){return ''}
    try{
        $item=Get-Item -LiteralPath $ModelPath -ErrorAction Stop
        $stem=[IO.Path]::GetFileNameWithoutExtension($ModelPath)
        $safe=[regex]::Replace($stem,'[^A-Za-z0-9._-]+','-').Trim('-')
        if(-not $safe){$safe='model'}
        return (Join-Path $script:HcModelPreviewCacheRoot ($safe+'-'+$item.Length+'-'+$item.LastWriteTimeUtc.Ticks+'.png'))
    }catch{return ''}
}

function Get-HcModelPreviewImageSource {
    param([string]$CachePath)
    if(-not $CachePath -or -not(Test-Path -LiteralPath $CachePath -PathType Leaf)){return $null}
    try{return (Get-ImageSourceFromPath $CachePath 320)}catch{return $null}
}

function Publish-HcModelPreview {
    param([string]$CachePath)
    if(-not $CachePath -or -not $script:HcModelPreviewTargets.ContainsKey($CachePath)){return}
    $source=Get-HcModelPreviewImageSource $CachePath
    if($null -eq $source){return}
    foreach($image in @($script:HcModelPreviewTargets[$CachePath])){
        try{if($null -ne $image){$image.Source=$source;$image.Opacity=1.0}}catch{}
    }
}

function Request-HcModelPreview {
    param([string]$ModelPath,[string]$CachePath,$Image)
    if(-not $ModelPath -or -not $CachePath -or $null -eq $Image){return}
    if(-not $script:HcModelPreviewTargets.ContainsKey($CachePath)){$script:HcModelPreviewTargets[$CachePath]=New-Object System.Collections.ArrayList}
    [void]$script:HcModelPreviewTargets[$CachePath].Add($Image)
    if(Test-Path -LiteralPath $CachePath -PathType Leaf){Publish-HcModelPreview $CachePath;return}
    if($script:HcModelPreviewQueued.ContainsKey($CachePath)){return}
    $script:HcModelPreviewQueued[$CachePath]=$true
    [void]$script:HcModelPreviewQueue.Add([pscustomobject]@{Model=$ModelPath;Cache=$CachePath})
    Start-HcModelPreviewTimer
}

function Start-HcModelPreviewTimer {
    if($null -ne $script:HcModelPreviewTimer){if(-not $script:HcModelPreviewTimer.IsEnabled){$script:HcModelPreviewTimer.Start()};return}
    $timer=New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval=[TimeSpan]::FromMilliseconds(180)
    $timer.Add_Tick({Update-HcModelPreviewQueue})
    $script:HcModelPreviewTimer=$timer
    $timer.Start()
}

function Update-HcModelPreviewQueue {
    if(Get-HcPlatformVisualStyle -ne '3D Models'){
        if($null -eq $script:HcModelPreviewProcess -or $script:HcModelPreviewProcess.HasExited){try{$script:HcModelPreviewTimer.Stop()}catch{}}
        return
    }
    if($null -ne $script:HcModelPreviewProcess){
        $alive=$false
        try{$script:HcModelPreviewProcess.Refresh();$alive=-not $script:HcModelPreviewProcess.HasExited}catch{}
        if($alive){return}
        $item=$script:HcModelPreviewActiveItem
        $exit=-1;try{$exit=$script:HcModelPreviewProcess.ExitCode}catch{}
        $script:HcModelPreviewProcess=$null;$script:HcModelPreviewActiveItem=$null
        if($null -ne $item){
            if($exit -eq 0 -and (Test-Path -LiteralPath $item.Cache -PathType Leaf)){Publish-HcModelPreview $item.Cache}
            elseif($exit -ne 0){Write-Log ('3D model preview worker failed for '+[IO.Path]::GetFileName([string]$item.Model)+' (exit '+$exit+').') 'WARN'}
        }
    }
    while($script:HcModelPreviewQueue.Count -gt 0){
        $item=$script:HcModelPreviewQueue[0];$script:HcModelPreviewQueue.RemoveAt(0)
        if(Test-Path -LiteralPath $item.Cache -PathType Leaf){Publish-HcModelPreview $item.Cache;continue}
        if(-not(Test-Path -LiteralPath $script:HcModelPreviewWorkerPath -PathType Leaf)){Write-Log '3D model preview worker is missing; platform icons remain active.' 'WARN';break}
        try{
            $args='--model "'+([string]$item.Model).Replace('"','')+'" --output "'+([string]$item.Cache).Replace('"','')+'" --size 256 --yaw 24 --pitch -12'
            $script:HcModelPreviewActiveItem=$item
            $script:HcModelPreviewProcess=Start-Process -FilePath $script:HcModelPreviewWorkerPath -ArgumentList $args -WindowStyle Hidden -PassThru
            return
        }catch{Write-Log ('3D model preview worker could not start: '+$_.Exception.Message) 'WARN';$script:HcModelPreviewActiveItem=$null;$script:HcModelPreviewProcess=$null}
    }
    if($script:HcModelPreviewQueue.Count -eq 0 -and $null -eq $script:HcModelPreviewProcess){try{$script:HcModelPreviewTimer.Stop()}catch{}}
}

function Reset-HcModelPreviewPageState {
    $script:HcModelPreviewTargets=@{}
    $script:HcModelPreviewQueue=New-Object System.Collections.ArrayList
    $script:HcModelPreviewQueued=@{}
    if($null -ne $script:HcModelPreviewActiveItem){
        $active=[string]$script:HcModelPreviewActiveItem.Cache
        if($active){$script:HcModelPreviewQueued[$active]=$true}
    }
}

function New-HcModelCardImage {
    param([string]$Platform,[string]$ModelPath,[string]$CachePath)
    $fallback=New-PlatformIconImage $Platform 64
    $image=New-Object System.Windows.Controls.Image
    $image.Width=112;$image.Height=86;$image.Stretch='Uniform';$image.HorizontalAlignment='Center';$image.VerticalAlignment='Center';$image.SnapsToDevicePixels=$true
    try{$image.Source=$fallback.Source}catch{}
    $cached=Get-HcModelPreviewImageSource $CachePath
    if($null -ne $cached){$image.Source=$cached;$image.Opacity=1.0}else{$image.Opacity=.82;Request-HcModelPreview $ModelPath $CachePath $image}
    return $image
}

function New-PlatformCard {
    param([string]$Platform,[int]$Index)
    $button=& $script:HcModelsBaseNewPlatformCard $Platform $Index
    if(Get-HcPlatformVisualStyle -ne '3D Models'){return $button}
    $model=Resolve-HcPlatformModelPath $Platform
    if(-not $model){return $button}
    $cache=Get-HcModelPreviewCachePath $model
    if(-not $cache){return $button}
    try{
        $grid=$button.Content
        $iconBorder=$null
        foreach($child in @($grid.Children)){
            if($child -is [System.Windows.Controls.Border] -and [math]::Abs([double]$child.Width-92) -lt .1 -and [math]::Abs([double]$child.Height-92) -lt .1){$iconBorder=$child;break}
        }
        if($null -eq $iconBorder){return $button}
        $iconBorder.Width=116;$iconBorder.Height=88;$iconBorder.CornerRadius=12;$iconBorder.BorderThickness='0';$iconBorder.Background='Transparent'
        $iconBorder.Child=New-HcModelCardImage $Platform $model $cache
        $button.DataContext=[pscustomobject]@{HcModelCard=$true;Platform=$Platform;Model=$model;Cache=$cache}
    }catch{Write-Log ('3D platform card fell back to icon for '+$Platform+': '+$_.Exception.Message) 'WARN'}
    return $button
}

function Add-PlatformRail {
    if(Get-HcPlatformVisualStyle -eq '3D Models'){Reset-HcModelPreviewPageState}
    & $script:HcModelsBaseAddPlatformRail
}

function Update-ActionVisuals {
    & $script:HcModelsBaseUpdateActionVisuals
    # Give the selected model card a restrained console-style lift while keeping
    # the rendered model itself cached/static. This avoids loading dozens of live
    # Viewport3D scenes on the Games page.
    if(Get-HcPlatformVisualStyle -ne '3D Models'){return}
    try{
        for($i=0;$i -lt @($script:ActionButtons).Count;$i++){
            $button=$script:ActionButtons[$i]
            if($null -eq $button -or $null -eq $button.DataContext -or -not [bool](Get-EntryProperty $button.DataContext 'HcModelCard' $false)){continue}
            $grid=$button.Content
            foreach($child in @($grid.Children)){
                if($child -is [System.Windows.Controls.Border] -and $child.Width -ge 110 -and $child.Height -ge 84){
                    $child.Opacity=$(if($i -eq $script:SelectedAction){1.0}else{.90});break
                }
            }
        }
    }catch{}
}

function Add-HcPlatformVisualAction {
    param($Page)
    if($null -eq $Page){return $Page}
    $style=Get-HcPlatformVisualStyle
    $pack=$(if(Test-HcModelPackAvailable){'Model pack detected; unavailable/future platforms still fall back to icons.'}else{'No model pack is installed, so icons will remain as the fallback.'})
    $action=New-Action 'platform-visual-style' ('Platform visuals: '+$style) ('Choose the Games provider/console card presentation. 3D Models uses cached renders from GLB assets. '+$pack)
    $result=New-Object System.Collections.ArrayList;$inserted=$false
    foreach($existing in @($Page.Actions)){
        [void]$result.Add($existing)
        if(-not $inserted -and [string](Get-EntryProperty $existing 'Id' '') -eq 'customization-preset'){[void]$result.Add($action);$inserted=$true}
    }
    if(-not $inserted){[void]$result.Add($action)}
    $Page.Actions=[object[]]$result.ToArray()
    return $Page
}

function Get-PageDefinition {
    param([int]$Index)
    $page=& $script:HcModelsBaseGetPageDefinition $Index
    if($Index -eq 7 -and $script:SubPage -eq 'Customization'){$page=Add-HcPlatformVisualAction $page}
    return $page
}

function Invoke-Action {
    param([string]$Id)
    if($Id -eq 'platform-visual-style'){
        Initialize-HcPlatformModelConfig
        $script:Config.PlatformVisualStyle=$(if((Get-HcPlatformVisualStyle) -eq 'Icons'){'3D Models'}else{'Icons'})
        Save-Config
        if($script:Config.PlatformVisualStyle -eq '3D Models' -and -not(Test-HcModelPackAvailable)){Set-ConsoleNotice '3D Models selected. No model pack is installed yet, so missing cards will use icons.' 'WARN'}
        else{Set-ConsoleNotice ('Platform visuals changed to '+$script:Config.PlatformVisualStyle+'.') 'INFO'}
        Render-Page;return
    }
    & $script:HcModelsBaseInvokeAction $Id
}

Initialize-HcPlatformModelConfig
