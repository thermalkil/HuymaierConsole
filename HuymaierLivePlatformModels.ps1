# HUYMAIER_LIVE_PLATFORM_3D_HELPERS_V3
# HUYMAIER_CONTEXT_AWARE_MODEL_VIEWER_V1
# GLB/ViewPort3D helper and full-screen model viewer only.
#
# This module does not create Games cards, inject Settings actions, or own the
# platform rail. HuymaierUser3DModels V4 owns presentation. Keeping rendering
# helpers separate prevents late wrapper/load-order regressions.
# V4 owns the card tooltip/action text: X/Square View 3D model.

Set-StrictMode -Version 2.0

$script:HcLiveModelAssemblyPath=Join-Path $script:BaseDir 'HuymaierLiveModel3D.dll'
$script:HcLiveModelAssemblyReady=$false
$script:HcModelViewerOverlay=$null
$script:HcModelViewerView=$null
$script:HcModelViewerActive=$false
$script:HcModelViewerPlatform=''
$script:HcLiveBaseInvokeSecondaryAction=${function:Invoke-SecondaryAction}
$script:HcLiveBaseApplyControllerNavigation=${function:Apply-ControllerNavigation}

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

function New-HcLiveModelView {
    param([string]$Path,[int]$ScalePercent=100,[switch]$CardMode)
    if(-not(Initialize-HcLiveModelAssembly)){return $null}
    if([string]::IsNullOrWhiteSpace($Path)-or-not(Test-Path -LiteralPath $Path -PathType Leaf)){return $null}
    try{
        $view=$(if($CardMode){New-Object HuymaierConsole.Modeling.LiveModelView -ArgumentList @($Path,$true)}else{New-Object HuymaierConsole.Modeling.LiveModelView -ArgumentList $Path})
        $view.SetScalePercent([double]$ScalePercent)
        return $view
    }catch{
        try{Write-Log ('Live model view failed for '+$Path+': '+$_.Exception.Message) 'WARN'}catch{}
        return $null
    }
}

function Get-HcPlatformVisualHost {
    param($Button)
    if($null -eq $Button-or$null -eq $Button.Content-or-not($Button.Content -is [System.Windows.Controls.Grid])){return $null}
    foreach($child in @($Button.Content.Children)){
        try{if($child -is [System.Windows.Controls.Border]-and[System.Windows.Controls.Grid]::GetRow($child)-eq0){return $child}}catch{}
    }
    return $null
}

function Get-HcSelectedPlatformForViewer {
    $action=Get-SelectedActionObject
    if($null -eq $action){return ''}
    $id=[string](Get-EntryProperty $action 'Id' '')
    if($id -notmatch '^platform-select:(\d+)$'){return ''}
    $index=[int]$matches[1]
    if($index-lt0-or$index-ge$script:GameHubPlatforms.Count){return ''}
    return [string]$script:GameHubPlatforms[$index]
}

function Close-HcPlatformModelViewer {
    if(-not$script:HcModelViewerActive){return}
    try{
        $root=$script:Window.Content
        if($script:HcModelViewerOverlay-and$root -is [System.Windows.Controls.Panel]){[void]$root.Children.Remove($script:HcModelViewerOverlay)}
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
    param([string]$Platform,[string]$ModelPath='')
    if([string]::IsNullOrWhiteSpace($Platform)){return $false}
    $path=[string]$ModelPath
    if([string]::IsNullOrWhiteSpace($path)){try{$path=Resolve-HcLivePlatformModelPath $Platform}catch{}}
    if([string]::IsNullOrWhiteSpace($path)){
        try{Set-ConsoleNotice ('Live 3D model asset is not installed for '+$Platform+'.') 'WARN'}catch{}
        return $false
    }
    $view=New-HcLiveModelView $path 115
    if($null -eq $view){return $false}
    $root=$script:Window.Content
    if($null -eq $root-or-not($root -is [System.Windows.Controls.Grid])){return $false}
    Close-HcPlatformModelViewer

    $overlay=New-Object System.Windows.Controls.Grid
    $overlay.Background='#F7060A12'
    [System.Windows.Controls.Panel]::SetZIndex($overlay,2200)
    $overlay.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height='86'}))
    $overlay.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height='*'}))
    $overlay.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height='70'}))

    $title=New-Object System.Windows.Controls.TextBlock
    $title.Text=$Platform+' — 3D MODEL';$title.FontSize=30;$title.FontWeight='Bold';$title.Foreground='White';$title.Margin='42,26,42,0'
    [System.Windows.Controls.Grid]::SetRow($title,0);[void]$overlay.Children.Add($title)

    $stage=New-Object System.Windows.Controls.Border
    $stage.Background='#12000000';$stage.BorderBrush='#30435D';$stage.BorderThickness='1';$stage.CornerRadius=22;$stage.Margin='42,8,42,14';$stage.Padding='16'
    [System.Windows.Controls.Grid]::SetRow($stage,1);$stage.Child=$view;[void]$overlay.Children.Add($stage)

    $hint=New-Object System.Windows.Controls.TextBlock
    $hint.Text='LEFT STICK / D-PAD  Rotate     LB / RB  Zoom     A/Cross  Reset view     B/Circle  Back';$hint.FontSize=17;$hint.FontWeight='SemiBold';$hint.Foreground='#D8E2EF';$hint.HorizontalAlignment='Center';$hint.VerticalAlignment='Center'
    [System.Windows.Controls.Grid]::SetRow($hint,2);[void]$overlay.Children.Add($hint)

    $overlay.Add_MouseWheel({param($sender,$eventArgs)try{if($script:HcModelViewerView){$script:HcModelViewerView.Zoom($(if($eventArgs.Delta-gt0){0.25}else{-0.25}));$eventArgs.Handled=$true}}catch{}})
    [void]$root.Children.Add($overlay)
    $script:HcModelViewerOverlay=$overlay;$script:HcModelViewerView=$view;$script:HcModelViewerPlatform=$Platform;$script:HcModelViewerActive=$true
    $script:LastGamepadMask=0;$script:LastDirection='';$script:NextDirectionAt=[datetime]::MinValue
    try{Write-Log ('Opened live 3D model viewer: '+$Platform)}catch{}
    return $true
}

function Invoke-SecondaryAction {
    $platform=Get-HcSelectedPlatformForViewer
    if(-not[string]::IsNullOrWhiteSpace($platform)){
        if(Open-HcPlatformModelViewer $platform){try{Invoke-UiFeedback 'Confirm'}catch{}}
        return
    }
    & $script:HcLiveBaseInvokeSecondaryAction
}

function Apply-ControllerNavigation {
    param([int]$Mask,[string]$Direction)
    if(-not$script:HcModelViewerActive){& $script:HcLiveBaseApplyControllerNavigation $Mask $Direction;return}
    if(Is-NewButtonPress $Mask 2){Close-HcPlatformModelViewer;& $script:HcLiveBaseApplyControllerNavigation $Mask $Direction;return}
    $now=Get-Date
    if($Direction){
        if($Direction-ne$script:LastDirection-or$now-ge$script:NextDirectionAt){
            try{switch($Direction){'Left'{$script:HcModelViewerView.Rotate(-6,0)}'Right'{$script:HcModelViewerView.Rotate(6,0)}'Up'{$script:HcModelViewerView.Rotate(0,-5)}'Down'{$script:HcModelViewerView.Rotate(0,5)}}}catch{}
            $newDirection=$Direction-ne$script:LastDirection;$script:LastDirection=$Direction;$script:NextDirectionAt=$now.AddMilliseconds($(if($newDirection){150}else{55}))
        }
    }else{$script:LastDirection='';$script:NextDirectionAt=[datetime]::MinValue}
    if(Is-NewButtonPress $Mask 4){try{$script:HcModelViewerView.ResetView()}catch{}}
    if(Is-NewButtonPress $Mask 8){Close-HcPlatformModelViewer;$script:LastGamepadMask=$Mask;return}
    if(Is-NewButtonPress $Mask 1024){try{$script:HcModelViewerView.Zoom(0.35)}catch{}}
    if(Is-NewButtonPress $Mask 2048){try{$script:HcModelViewerView.Zoom(-0.35)}catch{}}
    $script:LastGamepadMask=$Mask
}

try{[void](Initialize-HcLiveModelAssembly)}catch{}
