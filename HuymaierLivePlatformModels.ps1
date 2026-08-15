# HUYMAIER_LIVE_PLATFORM_3D_RUNTIME_V1
# Real GLB-backed platform visuals layered over the safe atlas fallback.
# Loaded after HuymaierPlatformModels.ps1 and HuymaierPlatformAtlas.ps1.

Set-StrictMode -Version 2.0

$script:HcLiveModelAssemblyPath = Join-Path $script:BaseDir 'HuymaierLiveModel3D.dll'
$script:HcLiveModelAssemblyReady = $false
$script:HcModelViewerOverlay = $null
$script:HcModelViewerView = $null
$script:HcModelViewerActive = $false
$script:HcModelViewerPlatform = ''

$script:HcLiveBaseNewPlatformCard = ${function:New-PlatformCard}
$script:HcLiveBaseGetPageDefinition = ${function:Get-PageDefinition}
$script:HcLiveBaseInvokeAction = ${function:Invoke-Action}
$script:HcLiveBaseAdjustSelectedSlider = ${function:Adjust-SelectedSlider}
$script:HcLiveBaseInvokeSecondaryAction = ${function:Invoke-SecondaryAction}
$script:HcLiveBaseApplyControllerNavigation = ${function:Apply-ControllerNavigation}

function Add-HcLiveConfigProperty {
    param([string]$Name,$Value)
    if($null -eq $script:Config.PSObject.Properties[$Name]){
        $script:Config | Add-Member -NotePropertyName $Name -NotePropertyValue $Value -Force
    }
}

Add-HcLiveConfigProperty 'PlatformVisualStyle' 'Icons'
Add-HcLiveConfigProperty 'PlatformIconScale' 100
Add-HcLiveConfigProperty 'PlatformModelScale' 100
try{$script:Config.PlatformIconScale=[math]::Max(60,[math]::Min(180,[int]$script:Config.PlatformIconScale))}catch{$script:Config.PlatformIconScale=100}
try{$script:Config.PlatformModelScale=[math]::Max(50,[math]::Min(200,[int]$script:Config.PlatformModelScale))}catch{$script:Config.PlatformModelScale=100}

function Initialize-HcLiveModelAssembly {
    if($script:HcLiveModelAssemblyReady){return $true}
    if(-not(Test-Path -LiteralPath $script:HcLiveModelAssemblyPath -PathType Leaf)){return $false}
    try{
        if(-not('HuymaierConsole.Modeling.LiveModelView' -as [type])){Add-Type -Path $script:HcLiveModelAssemblyPath -ErrorAction Stop}
        $script:HcLiveModelAssemblyReady=$null -ne ('HuymaierConsole.Modeling.LiveModelView' -as [type])
    }catch{
        $script:HcLiveModelAssemblyReady=$false
        try{Write-Log ('Live 3D model assembly load failed: '+$_.Exception.Message) 'WARN'}catch{}
    }
    return $script:HcLiveModelAssemblyReady
}

function Get-HcModelPropertyCaseInsensitive {
    param($Object,[string]$Name)
    if($null -eq $Object -or [string]::IsNullOrWhiteSpace($Name)){return $null}
    foreach($property in @($Object.PSObject.Properties)){
        if([string]::Equals([string]$property.Name,$Name,[StringComparison]::OrdinalIgnoreCase)){return $property}
    }
    return $null
}

function Get-HcPlatformFrameName {
    param([string]$Platform)
    try{Initialize-HcModelMap}catch{}
    if($null -eq $script:HcPlatformModelMap){return ''}
    $prop=Get-HcModelPropertyCaseInsensitive $script:HcPlatformModelMap $Platform
    if($null -eq $prop){return ''}
    $value=[string]$prop.Value
    if($value.StartsWith('atlas:',[StringComparison]::OrdinalIgnoreCase)){return $value.Substring(6)}
    return ''
}

function Get-HcLegacyLiveModelFileName {
    param([string]$Platform,[string]$Frame)
    try{
        $mapPath=Join-Path $script:BaseDir 'Assets\Models\model-map.json'
        if(-not(Test-Path -LiteralPath $mapPath -PathType Leaf)){return ''}
        $map=Get-Content -Raw -LiteralPath $mapPath -Encoding UTF8|ConvertFrom-Json
        if($null -eq $map.PSObject.Properties['sourceModels']){return ''}
        $direct=Get-HcModelPropertyCaseInsensitive $map.sourceModels $Platform
        if($null -ne $direct){return [string]$direct.Value}
        if(-not [string]::IsNullOrWhiteSpace($Frame) -and $null -ne $map.PSObject.Properties['models']){
            foreach($sourceProp in @($map.sourceModels.PSObject.Properties)){
                $alias=Get-HcModelPropertyCaseInsensitive $map.models ([string]$sourceProp.Name)
                if($null -eq $alias){continue}
                $aliasValue=[string]$alias.Value
                if($aliasValue.StartsWith('atlas:',[StringComparison]::OrdinalIgnoreCase) -and [string]::Equals($aliasValue.Substring(6),$Frame,[StringComparison]::OrdinalIgnoreCase)){
                    return [string]$sourceProp.Value
                }
            }
        }
    }catch{}
    return ''
}

function Resolve-HcLivePlatformModelPath {
    param([string]$Platform)
    if([string]::IsNullOrWhiteSpace($Platform)){return ''}
    $frame=Get-HcPlatformFrameName $Platform
    $legacy=Get-HcLegacyLiveModelFileName $Platform $frame
    $roots=@(
        (Join-Path $script:DataDir 'Models'),
        (Join-Path $script:DataDir 'Models\Live'),
        (Join-Path $script:BaseDir 'Assets\Models'),
        (Join-Path $script:BaseDir 'Assets\Models\Live')
    )
    $names=New-Object System.Collections.Generic.List[string]
    if(-not [string]::IsNullOrWhiteSpace($legacy)){[void]$names.Add($legacy)}
    if(-not [string]::IsNullOrWhiteSpace($frame)){[void]$names.Add($frame+'.glb')}
    [void]$names.Add(($Platform -replace '[\\/:*?"<>|]','_')+'.glb')
    foreach($root in $roots){
        foreach($name in $names){
            try{
                $candidate=Join-Path $root $name
                if(Test-Path -LiteralPath $candidate -PathType Leaf){return (Resolve-Path -LiteralPath $candidate).Path}
            }catch{}
        }
    }
    return ''
}

function New-HcLiveModelView {
    param([string]$Path,[int]$ScalePercent=100)
    if(-not(Initialize-HcLiveModelAssembly)){return $null}
    if([string]::IsNullOrWhiteSpace($Path) -or -not(Test-Path -LiteralPath $Path -PathType Leaf)){return $null}
    try{
        $view=New-Object HuymaierConsole.Modeling.LiveModelView -ArgumentList $Path
        $view.SetScalePercent([double]$ScalePercent)
        return $view
    }catch{
        try{Write-Log ('Live model view failed for '+$Path+': '+$_.Exception.Message) 'WARN'}catch{}
        return $null
    }
}

function Get-HcPlatformVisualHost {
    param($Button)
    if($null -eq $Button -or $null -eq $Button.Content -or -not($Button.Content -is [System.Windows.Controls.Grid])){return $null}
    foreach($child in @($Button.Content.Children)){
        try{
            if($child -is [System.Windows.Controls.Border] -and [System.Windows.Controls.Grid]::GetRow($child) -eq 0){return $child}
        }catch{}
    }
    return $null
}

function Set-HcAtlasFallbackVisual {
    param($Host,[string]$Platform,[int]$ScalePercent)
    if($null -eq $Host -or -not(Get-Command Get-HcAtlasImageSource -ErrorAction SilentlyContinue)){return $false}
    try{
        $source=Get-HcAtlasImageSource $Platform
        if($null -eq $source){return $false}
        $image=New-Object System.Windows.Controls.Image
        $image.Source=$source
        $image.Stretch='Uniform'
        $image.HorizontalAlignment='Center'
        $image.VerticalAlignment='Center'
        $factor=[math]::Max(.5,[math]::Min(2.0,$ScalePercent/100.0))
        $image.Width=84*$factor
        $image.Height=84*$factor
        $image.IsHitTestVisible=$false
        $Host.Child=$image
        return $true
    }catch{return $false}
}

function New-PlatformCard {
    param([string]$Platform,[int]$Index)
    $button=& $script:HcLiveBaseNewPlatformCard $Platform $Index
    if($null -eq $button){return $button}
    $style=Get-HcPlatformVisualStyle
    if($style -eq 'Icons'){
        $scale=[math]::Max(.60,[math]::Min(1.80,([int]$script:Config.PlatformIconScale)/100.0))
        $button.LayoutTransform=New-Object System.Windows.Media.ScaleTransform($scale,$scale)
        return $button
    }

    $host=Get-HcPlatformVisualHost $button
    if($null -eq $host){return $button}
    $modelScale=[int]$script:Config.PlatformModelScale
    $path=Resolve-HcLivePlatformModelPath $Platform
    if(-not [string]::IsNullOrWhiteSpace($path)){
        $view=New-HcLiveModelView $path $modelScale
        if($null -ne $view){
            $host.Background='Transparent'
            $host.BorderThickness='0'
            $host.CornerRadius=0
            $host.Width=112
            $host.Height=96
            $host.Child=$view
            $button.ToolTip='A/Cross Open platform   X/Square View 3D model'
            return $button
        }
    }
    [void](Set-HcAtlasFallbackVisual $host $Platform $modelScale)
    $button.ToolTip='A/Cross Open platform   X/Square View model when live GLB is available'
    return $button
}

function Get-PageDefinition {
    param([int]$Index)
    $page=& $script:HcLiveBaseGetPageDefinition $Index
    if($null -eq $page -or $Index -ne 7 -or $script:SubPage){return $page}
    $actions=New-Object System.Collections.Generic.List[object]
    [void]$actions.Add((New-Action 'platform-visual-style' ('Platform visuals: '+(Get-HcPlatformVisualStyle)) 'Icons use the original cards. 3D Models uses live GLB geometry when available and keeps the atlas only as a safe fallback.'))
    [void]$actions.Add((New-SliderAction 'platform-icon-scale-slider' 'Icon card size' ([int]$script:Config.PlatformIconScale) 'Scale the complete platform cards while Icons mode is selected.' 60 180))
    [void]$actions.Add((New-SliderAction 'platform-model-scale-slider' '3D model size' ([int]$script:Config.PlatformModelScale) 'Scale the live console/provider model inside each platform card.' 50 200))
    foreach($item in @($page.Actions)){[void]$actions.Add($item)}
    $page.Actions=[object[]]$actions.ToArray()
    return $page
}

function Invoke-Action {
    param([string]$Id)
    switch($Id){
        'platform-visual-style' {
            $script:Config.PlatformVisualStyle=$(if((Get-HcPlatformVisualStyle) -eq 'Icons'){'3D Models'}else{'Icons'})
            Save-Config
            Render-Page
            return
        }
        'platform-icon-scale-slider' {[void](Adjust-SelectedSlider 5);return}
        'platform-model-scale-slider' {[void](Adjust-SelectedSlider 5);return}
        default {& $script:HcLiveBaseInvokeAction $Id}
    }
}

function Adjust-SelectedSlider {
    param([int]$Delta)
    $action=Get-SelectedActionObject
    if($null -eq $action){return $false}
    $id=[string](Get-EntryProperty $action 'Id' '')
    $value=0
    switch($id){
        'platform-icon-scale-slider' {
            $value=[math]::Max(60,[math]::Min(180,([int]$script:Config.PlatformIconScale)+$Delta))
            $script:Config.PlatformIconScale=$value
            Save-Config
        }
        'platform-model-scale-slider' {
            $value=[math]::Max(50,[math]::Min(200,([int]$script:Config.PlatformModelScale)+$Delta))
            $script:Config.PlatformModelScale=$value
            Save-Config
        }
        default {return (& $script:HcLiveBaseAdjustSelectedSlider $Delta)}
    }
    try{$action.Value=$value}catch{}
    try{$control=$script:SliderControls[$id];if($control){$control.Slider.Value=$value;$control.Text.Text=($value.ToString()+'%')}}catch{}
    try{Invoke-UiFeedback 'Navigate'}catch{}
    return $true
}

function Get-HcSelectedPlatformForViewer {
    $action=Get-SelectedActionObject
    if($null -eq $action){return ''}
    $id=[string](Get-EntryProperty $action 'Id' '')
    if($id -notmatch '^platform-select:(\d+)$'){return ''}
    $index=[int]$matches[1]
    if($index -lt 0 -or $index -ge $script:GameHubPlatforms.Count){return ''}
    return [string]$script:GameHubPlatforms[$index]
}

function Close-HcPlatformModelViewer {
    if(-not $script:HcModelViewerActive){return}
    try{
        $root=$script:Window.Content
        if($null -ne $script:HcModelViewerOverlay -and $root -is [System.Windows.Controls.Panel]){[void]$root.Children.Remove($script:HcModelViewerOverlay)}
    }catch{}
    $script:HcModelViewerOverlay=$null
    $script:HcModelViewerView=$null
    $script:HcModelViewerPlatform=''
    $script:HcModelViewerActive=$false
    $script:LastGamepadMask=0
    $script:LastDirection=''
    $script:NextDirectionAt=[datetime]::MinValue
    try{Update-Footer}catch{}
}

function Open-HcPlatformModelViewer {
    param([string]$Platform)
    if([string]::IsNullOrWhiteSpace($Platform)){return $false}
    $path=Resolve-HcLivePlatformModelPath $Platform
    if([string]::IsNullOrWhiteSpace($path)){
        try{Set-ConsoleNotice ('Live 3D model asset is not installed for '+$Platform+'.') 'WARN'}catch{}
        return $false
    }
    $view=New-HcLiveModelView $path 115
    if($null -eq $view){return $false}
    $root=$script:Window.Content
    if($null -eq $root -or -not($root -is [System.Windows.Controls.Grid])){return $false}
    Close-HcPlatformModelViewer

    $overlay=New-Object System.Windows.Controls.Grid
    $overlay.Background='#F7060A12'
    [System.Windows.Controls.Panel]::SetZIndex($overlay,2200)
    $overlay.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height='86'}))
    $overlay.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height='*'}))
    $overlay.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height='70'}))

    $title=New-Object System.Windows.Controls.TextBlock
    $title.Text=$Platform+' — 3D MODEL'
    $title.FontSize=30
    $title.FontWeight='Bold'
    $title.Foreground='White'
    $title.Margin='42,26,42,0'
    [System.Windows.Controls.Grid]::SetRow($title,0)
    [void]$overlay.Children.Add($title)

    $stage=New-Object System.Windows.Controls.Border
    $stage.Background='#12000000'
    $stage.BorderBrush='#30435D'
    $stage.BorderThickness='1'
    $stage.CornerRadius=22
    $stage.Margin='42,8,42,14'
    $stage.Padding='16'
    [System.Windows.Controls.Grid]::SetRow($stage,1)
    $stage.Child=$view
    [void]$overlay.Children.Add($stage)

    $hint=New-Object System.Windows.Controls.TextBlock
    $hint.Text='LEFT STICK / D-PAD  Rotate     LB / RB  Zoom     A/Cross  Reset view     B/Circle  Back'
    $hint.FontSize=17
    $hint.FontWeight='SemiBold'
    $hint.Foreground='#D8E2EF'
    $hint.HorizontalAlignment='Center'
    $hint.VerticalAlignment='Center'
    [System.Windows.Controls.Grid]::SetRow($hint,2)
    [void]$overlay.Children.Add($hint)

    $overlay.Add_MouseWheel({param($sender,$eventArgs)try{if($null -ne $script:HcModelViewerView){$script:HcModelViewerView.Zoom($(if($eventArgs.Delta -gt 0){0.25}else{-0.25}));$eventArgs.Handled=$true}}catch{}})
    [void]$root.Children.Add($overlay)
    $script:HcModelViewerOverlay=$overlay
    $script:HcModelViewerView=$view
    $script:HcModelViewerPlatform=$Platform
    $script:HcModelViewerActive=$true
    $script:LastGamepadMask=0
    $script:LastDirection=''
    $script:NextDirectionAt=[datetime]::MinValue
    try{Write-Log ('Opened live 3D model viewer: '+$Platform)}catch{}
    return $true
}

function Invoke-SecondaryAction {
    $platform=Get-HcSelectedPlatformForViewer
    if(-not [string]::IsNullOrWhiteSpace($platform)){
        if(Open-HcPlatformModelViewer $platform){try{Invoke-UiFeedback 'Confirm'}catch{}}
        return
    }
    & $script:HcLiveBaseInvokeSecondaryAction
}

function Apply-ControllerNavigation {
    param([int]$Mask,[string]$Direction)
    if(-not $script:HcModelViewerActive){& $script:HcLiveBaseApplyControllerNavigation $Mask $Direction;return}

    if(Is-NewButtonPress $Mask 2){
        Close-HcPlatformModelViewer
        & $script:HcLiveBaseApplyControllerNavigation $Mask $Direction
        return
    }
    $now=Get-Date
    if($Direction){
        if($Direction -ne $script:LastDirection -or $now -ge $script:NextDirectionAt){
            try{
                switch($Direction){
                    'Left' {$script:HcModelViewerView.Rotate(-6,0)}
                    'Right' {$script:HcModelViewerView.Rotate(6,0)}
                    'Up' {$script:HcModelViewerView.Rotate(0,-5)}
                    'Down' {$script:HcModelViewerView.Rotate(0,5)}
                }
            }catch{}
            $newDirection=$Direction -ne $script:LastDirection
            $script:LastDirection=$Direction
            $script:NextDirectionAt=$now.AddMilliseconds($(if($newDirection){150}else{55}))
        }
    }else{
        $script:LastDirection=''
        $script:NextDirectionAt=[datetime]::MinValue
    }
    if(Is-NewButtonPress $Mask 4){try{$script:HcModelViewerView.ResetView()}catch{}}
    if(Is-NewButtonPress $Mask 8){Close-HcPlatformModelViewer;$script:LastGamepadMask=$Mask;return}
    if(Is-NewButtonPress $Mask 1024){try{$script:HcModelViewerView.Zoom(0.35)}catch{}}
    if(Is-NewButtonPress $Mask 2048){try{$script:HcModelViewerView.Zoom(-0.35)}catch{}}
    $script:LastGamepadMask=$Mask
}

try{Initialize-HcLiveModelAssembly|Out-Null}catch{}
