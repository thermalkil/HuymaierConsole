# Huymaier Console built-in provider/console 3D model atlas runtime.
# HUYMAIER_PLATFORM_3D_ATLAS_RUNTIME_V1
# The built-in atlas contains lightweight transparent presentation renders
# derived from the supplied GLB model pack. Custom LocalAppData model maps may
# still point directly at GLB files and use the background preview worker.
Set-StrictMode -Version 2.0

$script:HcAtlasBaseInitializeModelMap=${function:Initialize-HcModelMap}
$script:HcAtlasBaseModelCardImage=${function:New-HcModelCardImage}
$script:HcModelAtlas=$null
$script:HcModelAtlasBitmap=$null
$script:HcModelAtlasFrames=@{}
$script:HcModelAtlasCrops=@{}

function Reset-HcModelAtlasState {
    $script:HcModelAtlas=$null
    $script:HcModelAtlasBitmap=$null
    $script:HcModelAtlasFrames=@{}
    $script:HcModelAtlasCrops=@{}
}

function Initialize-HcModelMap {
    $root=Get-HcModelPackRoot
    $mapPath=$(if($root){Join-Path $root 'model-map.json'}else{''})
    if($script:HcModelMap -and [string]::Equals($script:HcModelMapPath,$mapPath,[StringComparison]::OrdinalIgnoreCase)){return}
    Reset-HcModelAtlasState
    $script:HcModelMap=@{};$script:HcModelMapPath=$mapPath
    if(-not $mapPath){return}
    try{
        $json=Get-Content -Raw -LiteralPath $mapPath -Encoding UTF8|ConvertFrom-Json
        $models=Get-EntryProperty $json 'models' $null
        if($null -ne $models){
            foreach($property in @($models.PSObject.Properties)){
                $key=[string]$property.Name;$value=[string]$property.Value
                if($key -and $value){$script:HcModelMap[$key.ToLowerInvariant()]=$value}
            }
        }
        $format=[string](Get-EntryProperty $json 'runtimeFormat' '')
        $atlas=Get-EntryProperty $json 'atlas' $null
        if([string]::Equals($format,'transparent-png-atlas',[StringComparison]::OrdinalIgnoreCase) -and $null -ne $atlas){
            $file=[string](Get-EntryProperty $atlas 'file' '')
            $cellWidth=[int](Get-EntryProperty $atlas 'cellWidth' 0)
            $cellHeight=[int](Get-EntryProperty $atlas 'cellHeight' 0)
            $columns=[int](Get-EntryProperty $atlas 'columns' 0)
            $rows=[int](Get-EntryProperty $atlas 'rows' 0)
            $frames=Get-EntryProperty $atlas 'frames' $null
            $atlasPath=$(if($file){Join-Path $root $file}else{''})
            if($atlasPath -and $cellWidth -gt 0 -and $cellHeight -gt 0 -and $columns -gt 0 -and $rows -gt 0 -and $null -ne $frames){
                foreach($property in @($frames.PSObject.Properties)){$script:HcModelAtlasFrames[[string]$property.Name.ToLowerInvariant()]=[int]$property.Value}
                $script:HcModelAtlas=[pscustomobject]@{Path=$atlasPath;CellWidth=$cellWidth;CellHeight=$cellHeight;Columns=$columns;Rows=$rows}
            }
        }
    }catch{Reset-HcModelAtlasState;Write-Log ('3D model map could not be read: '+$_.Exception.Message) 'WARN'}
}

function Test-HcModelPackAvailable {
    Initialize-HcModelMap
    if($script:HcModelMap.Count -eq 0){return $false}
    if($null -ne $script:HcModelAtlas){return (Test-Path -LiteralPath ([string]$script:HcModelAtlas.Path) -PathType Leaf)}
    $root=Get-HcModelPackRoot
    if(-not $root){return $false}
    foreach($value in @($script:HcModelMap.Values|Select-Object -Unique)){
        if(-not $value -or ([string]$value).StartsWith('atlas:',[StringComparison]::OrdinalIgnoreCase)){continue}
        if(Test-Path -LiteralPath (Join-Path $root ([string]$value)) -PathType Leaf){return $true}
    }
    return $false
}

function Get-HcPlatformModelAliases {
    param([string]$Platform)
    $aliases=New-Object System.Collections.ArrayList
    if($Platform){[void]$aliases.Add($Platform)}
    switch -Regex ($Platform){
        '^(?i)Xbox$' {if(Test-HcStorefrontPlatform $Platform){[void]$aliases.Insert(0,'Xbox App')}else{[void]$aliases.Add('Original Xbox')}}
        '^(?i)Epic$' {[void]$aliases.Add('Epic Games')}
        '^(?i)Amazon$' {[void]$aliases.Add('Amazon Games')}
        '^(?i)EA$' {[void]$aliases.Add('EA app')}
        '^(?i)BattleNet$' {[void]$aliases.Add('Battle.net')}
        '^(?i)Rockstar$' {[void]$aliases.Add('Rockstar Games')}
    }
    return [object[]]$aliases.ToArray()
}

function Resolve-HcPlatformModelPath {
    param([string]$Platform)
    if(-not $Platform){return ''}
    Initialize-HcModelMap
    if($script:HcModelMap.Count -eq 0){return ''}
    $root=Get-HcModelPackRoot
    foreach($alias in @(Get-HcPlatformModelAliases $Platform)){
        $key=([string]$alias).ToLowerInvariant()
        if(-not $script:HcModelMap.ContainsKey($key)){continue}
        $value=[string]$script:HcModelMap[$key]
        if($value.StartsWith('atlas:',[StringComparison]::OrdinalIgnoreCase)){
            $frame=$value.Substring(6).ToLowerInvariant()
            if($null -ne $script:HcModelAtlas -and $script:HcModelAtlasFrames.ContainsKey($frame) -and (Test-Path -LiteralPath ([string]$script:HcModelAtlas.Path) -PathType Leaf)){return $value}
            continue
        }
        $path=Join-Path $root $value
        if(Test-Path -LiteralPath $path -PathType Leaf){return $path}
    }
    return ''
}

function Initialize-HcModelAtlasBitmap {
    Initialize-HcModelMap
    if($null -ne $script:HcModelAtlasBitmap){return $true}
    if($null -eq $script:HcModelAtlas -or -not(Test-Path -LiteralPath ([string]$script:HcModelAtlas.Path) -PathType Leaf)){return $false}
    try{
        $bitmap=New-Object System.Windows.Media.Imaging.BitmapImage
        $bitmap.BeginInit();$bitmap.CacheOption=[System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad;$bitmap.UriSource=New-Object Uri -ArgumentList ([string]$script:HcModelAtlas.Path);$bitmap.EndInit();$bitmap.Freeze()
        $needWidth=[int]$script:HcModelAtlas.CellWidth*[int]$script:HcModelAtlas.Columns
        $needHeight=[int]$script:HcModelAtlas.CellHeight*[int]$script:HcModelAtlas.Rows
        if($bitmap.PixelWidth -lt $needWidth -or $bitmap.PixelHeight -lt $needHeight){throw "3D model atlas dimensions $($bitmap.PixelWidth)x$($bitmap.PixelHeight) are smaller than declared $needWidth x $needHeight."}
        $script:HcModelAtlasBitmap=$bitmap
        return $true
    }catch{Write-Log ('3D model atlas could not be loaded: '+$_.Exception.Message) 'WARN';return $false}
}

function Get-HcAtlasImageSource {
    param([string]$FrameKey)
    $key=([string]$FrameKey).ToLowerInvariant()
    if(-not $key){return $null}
    if($script:HcModelAtlasCrops.ContainsKey($key)){return $script:HcModelAtlasCrops[$key]}
    if(-not(Initialize-HcModelAtlasBitmap) -or -not $script:HcModelAtlasFrames.ContainsKey($key)){return $null}
    try{
        $index=[int]$script:HcModelAtlasFrames[$key]
        if($index -lt 0 -or $index -ge ([int]$script:HcModelAtlas.Columns*[int]$script:HcModelAtlas.Rows)){return $null}
        $column=$index % [int]$script:HcModelAtlas.Columns
        $row=[math]::Floor($index/[double][int]$script:HcModelAtlas.Columns)
        $rect=New-Object System.Windows.Int32Rect -ArgumentList ([int]($column*[int]$script:HcModelAtlas.CellWidth)),([int]($row*[int]$script:HcModelAtlas.CellHeight)),([int]$script:HcModelAtlas.CellWidth),([int]$script:HcModelAtlas.CellHeight)
        $crop=New-Object System.Windows.Media.Imaging.CroppedBitmap -ArgumentList $script:HcModelAtlasBitmap,$rect
        try{$crop.Freeze()}catch{}
        $script:HcModelAtlasCrops[$key]=$crop
        return $crop
    }catch{Write-Log ('3D model atlas frame failed for '+$key+': '+$_.Exception.Message) 'WARN';return $null}
}

function New-HcModelCardImage {
    param([string]$Platform,[string]$ModelPath,[string]$CachePath)
    if($ModelPath -and $ModelPath.StartsWith('atlas:',[StringComparison]::OrdinalIgnoreCase)){
        $image=New-Object System.Windows.Controls.Image
        $image.Width=112;$image.Height=86;$image.Stretch='Uniform';$image.HorizontalAlignment='Center';$image.VerticalAlignment='Center';$image.SnapsToDevicePixels=$true
        $source=Get-HcAtlasImageSource $ModelPath.Substring(6)
        if($null -eq $source){try{$image.Source=(New-PlatformIconImage $Platform 64).Source}catch{}}
        else{$image.Source=$source}
        return $image
    }
    return (& $script:HcAtlasBaseModelCardImage $Platform $ModelPath $CachePath)
}

function New-PlatformCard {
    param([string]$Platform,[int]$Index)
    $button=& $script:HcModelsBaseNewPlatformCard $Platform $Index
    if(Get-HcPlatformVisualStyle -ne '3D Models'){return $button}
    $model=Resolve-HcPlatformModelPath $Platform
    if(-not $model){return $button}
    $cache=$(if($model.StartsWith('atlas:',[StringComparison]::OrdinalIgnoreCase)){''}else{Get-HcModelPreviewCachePath $model})
    try{
        $grid=$button.Content;$iconBorder=$null
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

function Add-HcPlatformVisualAction {
    param($Page)
    if($null -eq $Page){return $Page}
    $style=Get-HcPlatformVisualStyle
    $pack=$(if(Test-HcModelPackAvailable){'Built-in lightweight model renders are ready. Custom GLB overrides are supported from the Huymaier model folder.'}else{'The built-in model atlas is unavailable, so icons remain the safe fallback.'})
    $action=New-Action 'platform-visual-style' ('Platform visuals: '+$style) ('Choose Icons or 3D Models for provider and console cards. '+$pack)
    $result=New-Object System.Collections.ArrayList;$inserted=$false
    foreach($existing in @($Page.Actions)){
        [void]$result.Add($existing)
        if(-not $inserted -and [string](Get-EntryProperty $existing 'Id' '') -eq 'customization-preset'){[void]$result.Add($action);$inserted=$true}
    }
    if(-not $inserted){[void]$result.Add($action)}
    $Page.Actions=[object[]]$result.ToArray();return $Page
}
