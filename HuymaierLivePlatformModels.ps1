# HUYMAIER_LIVE_PLATFORM_3D_HELPERS_V3
# HUYMAIER_CONTEXT_AWARE_MODEL_VIEWER_V2
# HUYMAIER_SHARED_D3D11_MODEL_VIEWER_V1
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
$script:HcModelViewerStage=$null
$script:HcModelViewerActive=$false
$script:HcModelViewerPlatform=''
$script:HcModelViewerYaw=0.0
$script:HcModelViewerPitch=-10.0
$script:HcModelViewerScale=0.82
$script:HcModelViewerSpin=$true
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
        try{if($view.PSObject.Methods['SetBrightnessPercent']){$view.SetBrightnessPercent([double]$script:Config.PlatformModelBrightness)}}catch{}
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
    try{if($script:HcModelViewerView -and $script:HcModelViewerView.PSObject.Methods['Dispose']){$script:HcModelViewerView.Dispose()}}catch{}
    $script:HcModelViewerOverlay=$null
    $script:HcModelViewerView=$null
    $script:HcModelViewerStage=$null
    $script:HcModelViewerPlatform=''
    $script:HcModelViewerYaw=0.0;$script:HcModelViewerPitch=-10.0;$script:HcModelViewerScale=0.82;$script:HcModelViewerSpin=$true
    $script:HcModelViewerActive=$false
    $script:LastGamepadMask=0
    $script:LastDirection=''
    $script:NextDirectionAt=[datetime]::MinValue
    try{Update-Footer}catch{}
}

function Get-HcModelViewerGpuCache {
    param([string]$ModelPath)
    if([string]::IsNullOrWhiteSpace($ModelPath)-or-not(Test-Path -LiteralPath $ModelPath -PathType Leaf)){return $null}
    if(-not(Initialize-HcGpuShelfRuntime)){return $null}
    $cache=Get-HcGpuShelfCachePath $ModelPath
    if(Test-HcGpuShelfCacheCurrent $ModelPath $cache){return $cache}
    $args='--model "'+$ModelPath.Replace('"','\"')+'" --cache "'+$cache.Replace('"','\"')+'" --size '+[int]$script:HcGpuShelfCacheQuality
    try{
        $process=Start-Process -FilePath $script:HcGpuShelfCompilerExe -ArgumentList $args -WindowStyle Hidden -PassThru
        if(-not$process.WaitForExit(45000)){try{$process.Kill()}catch{};throw 'GPU model-viewer cache compile timed out.'}
        $code=[int]$process.ExitCode;try{$process.Dispose()}catch{}
        if($code-ne0-or-not(Test-HcGpuShelfCacheCurrent $ModelPath $cache)){throw ('GPU model-viewer cache compile failed with exit code '+$code+'.')}
        return $cache
    }catch{
        try{Write-Log ('GPU model-viewer cache unavailable for '+$ModelPath+': '+$_.Exception.Message) 'WARN'}catch{}
        return $null
    }
}

function Update-HcGpuModelViewerItem {
    if(-not$script:HcModelViewerActive-or$null-eq$script:HcModelViewerView){return}
    $w=1200.0;$h=700.0
    try{if($script:HcModelViewerStage.ActualWidth-gt20){$w=[double]$script:HcModelViewerStage.ActualWidth};if($script:HcModelViewerStage.ActualHeight-gt20){$h=[double]$script:HcModelViewerStage.ActualHeight}}catch{}
    try{[void]$script:HcModelViewerView.SetItem(0,0,0,$w,$h,[double]$script:HcModelViewerScale,$false,$true)}catch{}
    try{[void]$script:HcModelViewerView.SetItemView(0,[double]$script:HcModelViewerYaw,[double]$script:HcModelViewerPitch,[bool]$script:HcModelViewerSpin)}catch{}
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
    $cache=Get-HcModelViewerGpuCache $path
    if([string]::IsNullOrWhiteSpace($cache)){return $false}
    $gpuType=Get-HcGpuShelfHostType
    if($null-eq$gpuType){return $false}
    try{$view=New-Object $gpuType.FullName}catch{try{$view=[Activator]::CreateInstance($gpuType)}catch{return $false}}
    try{$view.SetBrightnessPercent([double]$script:Config.PlatformModelBrightness)}catch{}
    try{if(-not$view.LoadModel(0,$cache)){try{$view.Dispose()}catch{};return $false}}catch{try{$view.Dispose()}catch{};return $false}
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
    $viewerGroup=$(if(Test-HcStorefrontPlatform $Platform){'Providers'}else{'Consoles'})
    $title.Text=(Get-HcPlatformDisplayLabel $Platform $viewerGroup)+' — 3D MODEL';$title.FontSize=30;$title.FontWeight='Bold';$title.Foreground='White';$title.Margin='42,26,42,0'
    [System.Windows.Controls.Grid]::SetRow($title,0);[void]$overlay.Children.Add($title)

    $stage=New-Object System.Windows.Controls.Border
    $stage.Background='#12000000';$stage.BorderBrush='#30435D';$stage.BorderThickness='1';$stage.CornerRadius=22;$stage.Margin='42,8,42,14';$stage.Padding='16'
    [System.Windows.Controls.Grid]::SetRow($stage,1);$stage.Child=$view;[void]$overlay.Children.Add($stage)
    $stage.Add_SizeChanged({try{Update-HcGpuModelViewerItem}catch{}})

    $hint=New-Object System.Windows.Controls.TextBlock
    $hint.Text='LEFT STICK / D-PAD  Rotate     LB / RB  Zoom     A/Cross  Reset view     B/Circle  Back';$hint.FontSize=17;$hint.FontWeight='SemiBold';$hint.Foreground='#D8E2EF';$hint.HorizontalAlignment='Center';$hint.VerticalAlignment='Center'
    [System.Windows.Controls.Grid]::SetRow($hint,2);[void]$overlay.Children.Add($hint)

    $overlay.Add_MouseWheel({param($sender,$eventArgs)try{if($script:HcModelViewerView){$delta=$(if($eventArgs.Delta-gt0){.05}else{-.05});$script:HcModelViewerScale=[math]::Max(.45,[math]::Min(.90,$script:HcModelViewerScale+$delta));Update-HcGpuModelViewerItem;$eventArgs.Handled=$true}}catch{}})
    [void]$root.Children.Add($overlay)
    $script:HcModelViewerOverlay=$overlay;$script:HcModelViewerView=$view;$script:HcModelViewerStage=$stage;$script:HcModelViewerPlatform=$Platform;$script:HcModelViewerActive=$true
    $script:HcModelViewerYaw=0.0;$script:HcModelViewerPitch=-10.0;$script:HcModelViewerScale=.82;$script:HcModelViewerSpin=$true
    Update-HcGpuModelViewerItem
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
            try{switch($Direction){'Left'{$script:HcModelViewerYaw-=6}'Right'{$script:HcModelViewerYaw+=6}'Up'{$script:HcModelViewerPitch=[math]::Max(-80,$script:HcModelViewerPitch-5)}'Down'{$script:HcModelViewerPitch=[math]::Min(80,$script:HcModelViewerPitch+5)}};$script:HcModelViewerSpin=$false;Update-HcGpuModelViewerItem}catch{}
            $newDirection=$Direction-ne$script:LastDirection;$script:LastDirection=$Direction;$script:NextDirectionAt=$now.AddMilliseconds($(if($newDirection){150}else{55}))
        }
    }else{$script:LastDirection='';$script:NextDirectionAt=[datetime]::MinValue}
    if(Is-NewButtonPress $Mask 4){$script:HcModelViewerYaw=0.0;$script:HcModelViewerPitch=-10.0;$script:HcModelViewerScale=.82;$script:HcModelViewerSpin=$true;Update-HcGpuModelViewerItem}
    if(Is-NewButtonPress $Mask 8){Close-HcPlatformModelViewer;$script:LastGamepadMask=$Mask;return}
    if(Is-NewButtonPress $Mask 1024){$script:HcModelViewerScale=[math]::Min(.90,$script:HcModelViewerScale+.05);Update-HcGpuModelViewerItem}
    if(Is-NewButtonPress $Mask 2048){$script:HcModelViewerScale=[math]::Max(.45,$script:HcModelViewerScale-.05);Update-HcGpuModelViewerItem}
    $script:LastGamepadMask=$Mask
}

try{[void](Initialize-HcLiveModelAssembly)}catch{}
