# HUYMAIER_V0304_MODEL_DEFAULT_ORIENTATION_EDITOR_V1
# HUYMAIER_V0306_CONSOLE_MODEL_SCALE_EDITOR_V1
# Per-model presentation defaults for user-owned GLBs.
# The GLB itself is never modified; orientation/scale metadata lives in config.json.
# v0.30.6 scale editing is deliberately CONSOLE-ONLY. Provider/storefront models
# retain their existing presentation path and are never rescaled by this module.
Set-StrictMode -Version 2.0

$script:HcModelDefaultsBaseOpenViewer=${function:Open-HcPlatformModelViewer}
$script:HcModelDefaultsBaseCloseViewer=${function:Close-HcPlatformModelViewer}
$script:HcModelDefaultsBaseApplyControllerNavigation=${function:Apply-ControllerNavigation}
$script:HcModelDefaultsBaseUpdateGpuShelfLayoutForGroup=${function:Update-HcGpuShelfLayoutForGroup}
$script:HcModelEditorActive=$false
$script:HcModelEditorButton=$null
$script:HcModelEditorHint=$null
$script:HcModelViewerModelPath=''
$script:HcModelEditorOriginalYaw=0.0
$script:HcModelEditorOriginalPitch=-10.0
$script:HcModelEditorOriginalScalePercent=100
$script:HcModelEditorScalePercent=100

function Initialize-HcModelDefaultViewConfig {
    if($null -eq $script:Config.PSObject.Properties['PlatformModelDefaultViews']){
        $script:Config|Add-Member -NotePropertyName 'PlatformModelDefaultViews' -NotePropertyValue @() -Force
    }
    if($null -eq $script:Config.PlatformModelDefaultViews){$script:Config.PlatformModelDefaultViews=@()}
}

function Get-HcModelDefaultViewKey {
    param([string]$ModelPath,[string]$Platform='')
    if(-not[string]::IsNullOrWhiteSpace($ModelPath)){
        try{
            $name=[IO.Path]::GetFileName($ModelPath)
            if(-not[string]::IsNullOrWhiteSpace($name)){return $name.Trim().ToLowerInvariant()}
        }catch{}
    }
    if(-not[string]::IsNullOrWhiteSpace($Platform)){return ('platform:'+$Platform.Trim().ToLowerInvariant())}
    return ''
}

function Normalize-HcModelYaw {
    param([double]$Yaw)
    while($Yaw -gt 180.0){$Yaw-=360.0}
    while($Yaw -le -180.0){$Yaw+=360.0}
    return [math]::Round($Yaw,2)
}

function Normalize-HcModelScalePercent {
    param([double]$ScalePercent)
    return [int]([math]::Round([math]::Max(30.0,[math]::Min(300.0,$ScalePercent))/10.0)*10.0)
}

function Test-HcConsoleModelScaleEditable {
    param([string]$Platform)
    if([string]::IsNullOrWhiteSpace($Platform)){return $false}
    try{return (-not [bool](Test-HcStorefrontPlatform $Platform))}catch{return $true}
}

function Get-HcModelDefaultView {
    param([string]$ModelPath,[string]$Platform='')
    Initialize-HcModelDefaultViewConfig
    $key=Get-HcModelDefaultViewKey $ModelPath $Platform
    $yaw=0.0;$pitch=-10.0;$scalePercent=100
    if($key){
        foreach($entry in @($script:Config.PlatformModelDefaultViews)){
            if($null -eq $entry){continue}
            $entryKey=[string](Get-EntryProperty $entry 'Key' '')
            if(-not$entryKey){$entryKey=Get-HcModelDefaultViewKey ([string](Get-EntryProperty $entry 'Model' '')) ([string](Get-EntryProperty $entry 'Platform' ''))}
            if(-not[string]::Equals($entryKey,$key,[StringComparison]::OrdinalIgnoreCase)){continue}
            try{$yaw=Normalize-HcModelYaw ([double](Get-EntryProperty $entry 'Yaw' 0.0))}catch{$yaw=0.0}
            try{$pitch=[math]::Max(-80.0,[math]::Min(80.0,[double](Get-EntryProperty $entry 'Pitch' -10.0)))}catch{$pitch=-10.0}
            try{$scalePercent=Normalize-HcModelScalePercent ([double](Get-EntryProperty $entry 'ScalePercent' 100))}catch{$scalePercent=100}
            break
        }
    }
    return [pscustomobject]@{Key=$key;Yaw=[double]$yaw;Pitch=[double]$pitch;ScalePercent=[int]$scalePercent}
}

function Set-HcModelDefaultView {
    param([string]$ModelPath,[string]$Platform,[double]$Yaw,[double]$Pitch,[int]$ScalePercent=100)
    Initialize-HcModelDefaultViewConfig
    $key=Get-HcModelDefaultViewKey $ModelPath $Platform
    if([string]::IsNullOrWhiteSpace($key)){return $false}
    $items=New-Object System.Collections.ArrayList
    foreach($entry in @($script:Config.PlatformModelDefaultViews)){
        if($null -eq $entry){continue}
        $entryKey=[string](Get-EntryProperty $entry 'Key' '')
        if(-not$entryKey){$entryKey=Get-HcModelDefaultViewKey ([string](Get-EntryProperty $entry 'Model' '')) ([string](Get-EntryProperty $entry 'Platform' ''))}
        if([string]::Equals($entryKey,$key,[StringComparison]::OrdinalIgnoreCase)){continue}
        [void]$items.Add($entry)
    }
    $modelName=''
    try{$modelName=[IO.Path]::GetFileName($ModelPath)}catch{}
    $savedScale=$(if(Test-HcConsoleModelScaleEditable $Platform){Normalize-HcModelScalePercent $ScalePercent}else{100})
    [void]$items.Add([pscustomobject]@{
        Key=$key
        Model=$modelName
        Platform=$Platform
        Yaw=(Normalize-HcModelYaw $Yaw)
        Pitch=[math]::Round([math]::Max(-80.0,[math]::Min(80.0,$Pitch)),2)
        ScalePercent=[int]$savedScale
        UpdatedUtc=[DateTime]::UtcNow.ToString('o')
    })
    $script:Config.PlatformModelDefaultViews=[object[]]$items.ToArray()
    Save-Config
    return $true
}

function Reset-HcModelDefaultView {
    param([string]$ModelPath,[string]$Platform)
    Initialize-HcModelDefaultViewConfig
    $key=Get-HcModelDefaultViewKey $ModelPath $Platform
    if([string]::IsNullOrWhiteSpace($key)){return}
    $items=New-Object System.Collections.ArrayList
    foreach($entry in @($script:Config.PlatformModelDefaultViews)){
        if($null -eq $entry){continue}
        $entryKey=[string](Get-EntryProperty $entry 'Key' '')
        if(-not$entryKey){$entryKey=Get-HcModelDefaultViewKey ([string](Get-EntryProperty $entry 'Model' '')) ([string](Get-EntryProperty $entry 'Platform' ''))}
        if(-not[string]::Equals($entryKey,$key,[StringComparison]::OrdinalIgnoreCase)){[void]$items.Add($entry)}
    }
    $script:Config.PlatformModelDefaultViews=[object[]]$items.ToArray()
    Save-Config
}

function Get-HcActiveModelDefaultView {
    $path=[string]$script:HcModelViewerModelPath
    if([string]::IsNullOrWhiteSpace($path) -and -not[string]::IsNullOrWhiteSpace([string]$script:HcModelViewerPlatform)){
        try{$path=Resolve-HcLivePlatformModelPath ([string]$script:HcModelViewerPlatform)}catch{}
    }
    return (Get-HcModelDefaultView $path ([string]$script:HcModelViewerPlatform))
}

function Set-HcActiveConsoleModelViewerScale {
    param([int]$ScalePercent)
    $script:HcModelEditorScalePercent=Normalize-HcModelScalePercent $ScalePercent
    $script:HcModelViewerScale=.82*([double]$script:HcModelEditorScalePercent/100.0)
}

function Update-HcModelEditorChrome {
    if(-not$script:HcModelViewerActive -or $null -eq $script:HcModelViewerOverlay){return}
    try{
        if($null -eq $script:HcModelEditorHint){
            foreach($child in @($script:HcModelViewerOverlay.Children)){
                if($child -is [System.Windows.Controls.TextBlock] -and [System.Windows.Controls.Grid]::GetRow($child) -eq 2){$script:HcModelEditorHint=$child;break}
            }
        }
        if($script:HcModelEditorHint){
            if($script:HcModelEditorActive){
                if(Test-HcConsoleModelScaleEditable ([string]$script:HcModelViewerPlatform)){
                    $script:HcModelEditorHint.Text=('EDIT MODEL  •  D-PAD Rotate  •  LB / RB Scale '+[int]$script:HcModelEditorScalePercent+'%  •  A/Cross Save  •  Y/Triangle Reset  •  B/Circle Cancel')
                }else{
                    $script:HcModelEditorHint.Text='EDIT MODEL  •  LEFT STICK / D-PAD Rotate  •  A/Cross Save Default  •  Y/Triangle Reset Default  •  B/Circle Cancel'
                }
                $script:HcModelEditorHint.HorizontalAlignment='Left';$script:HcModelEditorHint.Margin='42,0,210,0'
            }else{
                $script:HcModelEditorHint.Text='LEFT STICK / D-PAD Rotate temporary  •  X/Square Edit Model  •  LB / RB Zoom  •  A/Cross Saved View  •  B/Circle Back'
                $script:HcModelEditorHint.HorizontalAlignment='Left';$script:HcModelEditorHint.Margin='42,0,210,0'
            }
        }
        if($null -eq $script:HcModelEditorButton){
            $button=New-Object System.Windows.Controls.Button
            $button.Content='EDIT MODEL';$button.Width=148;$button.Height=40;$button.Margin='0,14,42,14';$button.HorizontalAlignment='Right';$button.VerticalAlignment='Center'
            $button.FontSize=14;$button.FontWeight='SemiBold';$button.Foreground='White';$button.Background='#26384F';$button.BorderBrush='#7489A4';$button.BorderThickness='1';$button.Cursor='Hand'
            $button.Add_Click({try{Enter-HcModelOrientationEditor}catch{}})
            [System.Windows.Controls.Grid]::SetRow($button,2);[void]$script:HcModelViewerOverlay.Children.Add($button);$script:HcModelEditorButton=$button
        }
        if($script:HcModelEditorButton){$script:HcModelEditorButton.Content=$(if($script:HcModelEditorActive){'EDITING…'}else{'EDIT MODEL'});$script:HcModelEditorButton.IsEnabled=(-not$script:HcModelEditorActive)}
    }catch{try{Write-Log ('Model editor chrome refresh recovered: '+$_.Exception.Message) 'WARN'}catch{}}
}

function Enter-HcModelOrientationEditor {
    if(-not$script:HcModelViewerActive -or $script:HcModelEditorActive){return}
    $saved=Get-HcActiveModelDefaultView
    $script:HcModelEditorOriginalYaw=[double]$saved.Yaw;$script:HcModelEditorOriginalPitch=[double]$saved.Pitch
    $script:HcModelEditorOriginalScalePercent=[int]$saved.ScalePercent;$script:HcModelEditorScalePercent=[int]$saved.ScalePercent
    if(Test-HcConsoleModelScaleEditable ([string]$script:HcModelViewerPlatform)){Set-HcActiveConsoleModelViewerScale ([int]$saved.ScalePercent)}
    $script:HcModelViewerSpin=$false;$script:HcModelEditorActive=$true
    Update-HcGpuModelViewerItem;Update-HcModelEditorChrome
    try{Set-ConsoleNotice ('Editing default 3D presentation for '+$script:HcModelViewerPlatform+'.') 'INFO'}catch{}
}

function Save-HcModelOrientationEditor {
    if(-not$script:HcModelEditorActive){return}
    $saveScale=$(if(Test-HcConsoleModelScaleEditable ([string]$script:HcModelViewerPlatform)){[int]$script:HcModelEditorScalePercent}else{100})
    if(Set-HcModelDefaultView ([string]$script:HcModelViewerModelPath) ([string]$script:HcModelViewerPlatform) ([double]$script:HcModelViewerYaw) ([double]$script:HcModelViewerPitch) $saveScale){
        $script:HcModelEditorOriginalYaw=[double]$script:HcModelViewerYaw;$script:HcModelEditorOriginalPitch=[double]$script:HcModelViewerPitch;$script:HcModelEditorOriginalScalePercent=[int]$saveScale
        try{Set-ConsoleNotice ('Saved default 3D presentation for '+$script:HcModelViewerPlatform+'.') 'INFO'}catch{}
    }
    $script:HcModelEditorActive=$false;$script:HcModelViewerSpin=$true
    Update-HcGpuModelViewerItem;Update-HcModelEditorChrome
    try{Update-HcGpuShelfLayout}catch{}
}

function Reset-HcModelOrientationEditor {
    if(-not$script:HcModelViewerActive){return}
    Reset-HcModelDefaultView ([string]$script:HcModelViewerModelPath) ([string]$script:HcModelViewerPlatform)
    $script:HcModelViewerYaw=0.0;$script:HcModelViewerPitch=-10.0;$script:HcModelEditorScalePercent=100;$script:HcModelEditorOriginalScalePercent=100
    if(Test-HcConsoleModelScaleEditable ([string]$script:HcModelViewerPlatform)){$script:HcModelViewerScale=.82}
    $script:HcModelViewerSpin=$true;$script:HcModelEditorActive=$false
    Update-HcGpuModelViewerItem;Update-HcModelEditorChrome
    try{Update-HcGpuShelfLayout}catch{}
    try{Set-ConsoleNotice ('Reset default 3D presentation for '+$script:HcModelViewerPlatform+'.') 'INFO'}catch{}
}

function Cancel-HcModelOrientationEditor {
    if(-not$script:HcModelEditorActive){return}
    $script:HcModelViewerYaw=[double]$script:HcModelEditorOriginalYaw;$script:HcModelViewerPitch=[double]$script:HcModelEditorOriginalPitch
    if(Test-HcConsoleModelScaleEditable ([string]$script:HcModelViewerPlatform)){Set-HcActiveConsoleModelViewerScale ([int]$script:HcModelEditorOriginalScalePercent)}
    $script:HcModelViewerSpin=$true;$script:HcModelEditorActive=$false
    Update-HcGpuModelViewerItem;Update-HcModelEditorChrome
}

function Open-HcPlatformModelViewer {
    param([string]$Platform,[string]$ModelPath='')
    $path=[string]$ModelPath
    if([string]::IsNullOrWhiteSpace($path)){try{$path=Resolve-HcLivePlatformModelPath $Platform}catch{}}
    $opened=[bool](& $script:HcModelDefaultsBaseOpenViewer $Platform $ModelPath)
    if(-not$opened){return $false}
    $script:HcModelViewerModelPath=$path;$script:HcModelEditorActive=$false;$script:HcModelEditorButton=$null;$script:HcModelEditorHint=$null
    $saved=Get-HcModelDefaultView $path $Platform
    $script:HcModelViewerYaw=[double]$saved.Yaw;$script:HcModelViewerPitch=[double]$saved.Pitch;$script:HcModelViewerSpin=$true
    if(Test-HcConsoleModelScaleEditable $Platform){Set-HcActiveConsoleModelViewerScale ([int]$saved.ScalePercent)}else{$script:HcModelEditorScalePercent=100}
    Update-HcGpuModelViewerItem;Update-HcModelEditorChrome
    return $true
}

function Close-HcPlatformModelViewer {
    $script:HcModelEditorActive=$false;$script:HcModelEditorButton=$null;$script:HcModelEditorHint=$null;$script:HcModelViewerModelPath='';$script:HcModelEditorScalePercent=100
    & $script:HcModelDefaultsBaseCloseViewer
}

function Update-HcGpuShelfLayoutForGroup {
    param($Group,[bool]$Focused)
    & $script:HcModelDefaultsBaseUpdateGpuShelfLayoutForGroup $Group $Focused
    if($null -eq $Group -or $null -eq $Group.Surface -or -not$Group.Surface.PSObject.Methods['SetItemView']){return}
    $isConsoleGroup=[string]::Equals([string]$Group.Key,'Consoles',[StringComparison]::OrdinalIgnoreCase)
    foreach($card in @($Group.Cards)){
        if($null -eq $card -or -not[bool]$card.GpuReady -or [string]::IsNullOrWhiteSpace([string]$card.Path)){continue}
        try{
            $view=Get-HcModelDefaultView ([string]$card.Path) ([string]$card.Platform)
            [void]$Group.Surface.SetItemView([int]$card.ActionIndex,[double]$view.Yaw,[double]$view.Pitch,$true)
            if($isConsoleGroup -and $Group.Surface.PSObject.Methods['SetItem']){
                $point=$card.VisualHost.TranslatePoint((New-Object System.Windows.Point 0,0),$Group.Container)
                $w=[double]$card.VisualHost.ActualWidth;if($w-le1){$w=[double]$card.Button.Width-12}
                $h=[double]$card.VisualHost.ActualHeight;if($h-le1){$h=[double]$card.VisualHost.Height}
                $visible=($point.X+$w-gt0-and$point.X-lt$Group.Container.ActualWidth-and$point.Y+$h-gt0-and$point.Y-lt$Group.Container.ActualHeight)
                $baseScale=0.55+(([math]::Max(50,[math]::Min(200,[int]$script:Config.PlatformModelScale))-50.0)/150.0)*0.15
                $itemScale=$baseScale*([double]$view.ScalePercent/100.0)
                [void]$Group.Surface.SetItem([int]$card.ActionIndex,$point.X,$point.Y,$w,$h,$itemScale,([int]$card.ShelfIndex-eq[int]$Group.SelectedLocalIndex),$visible)
            }
        }catch{}
    }
}

function Apply-ControllerNavigation {
    param([int]$Mask,[string]$Direction)
    if(-not$script:HcModelViewerActive){& $script:HcModelDefaultsBaseApplyControllerNavigation $Mask $Direction;return}

    if(-not$script:HcModelEditorActive){
        if(Is-NewButtonPress $Mask 16){Enter-HcModelOrientationEditor;$script:LastGamepadMask=$Mask;return}
        if(Is-NewButtonPress $Mask 4){
            $saved=Get-HcActiveModelDefaultView;$script:HcModelViewerYaw=[double]$saved.Yaw;$script:HcModelViewerPitch=[double]$saved.Pitch
            if(Test-HcConsoleModelScaleEditable ([string]$script:HcModelViewerPlatform)){Set-HcActiveConsoleModelViewerScale ([int]$saved.ScalePercent)}else{$script:HcModelViewerScale=.82}
            $script:HcModelViewerSpin=$true;Update-HcGpuModelViewerItem;$script:LastGamepadMask=$Mask;return
        }
        & $script:HcModelDefaultsBaseApplyControllerNavigation $Mask $Direction;return
    }

    if(Is-NewButtonPress $Mask 2){Cancel-HcModelOrientationEditor;& $script:HcModelDefaultsBaseApplyControllerNavigation $Mask $Direction;return}
    $now=Get-Date
    if($Direction){
        if($Direction-ne$script:LastDirection-or$now-ge$script:NextDirectionAt){
            switch($Direction){
                'Left' {$script:HcModelViewerYaw=Normalize-HcModelYaw ([double]$script:HcModelViewerYaw-6.0)}
                'Right' {$script:HcModelViewerYaw=Normalize-HcModelYaw ([double]$script:HcModelViewerYaw+6.0)}
                'Up' {$script:HcModelViewerPitch=[math]::Max(-80.0,[double]$script:HcModelViewerPitch-5.0)}
                'Down' {$script:HcModelViewerPitch=[math]::Min(80.0,[double]$script:HcModelViewerPitch+5.0)}
            }
            $script:HcModelViewerSpin=$false;Update-HcGpuModelViewerItem
            $newDirection=$Direction-ne$script:LastDirection;$script:LastDirection=$Direction;$script:NextDirectionAt=$now.AddMilliseconds($(if($newDirection){150}else{55}))
        }
    }else{$script:LastDirection='';$script:NextDirectionAt=[datetime]::MinValue}

    if(Test-HcConsoleModelScaleEditable ([string]$script:HcModelViewerPlatform)){
        if(Is-NewButtonPress $Mask 1024){Set-HcActiveConsoleModelViewerScale ([int]$script:HcModelEditorScalePercent+10);$script:HcModelViewerSpin=$false;Update-HcGpuModelViewerItem;Update-HcModelEditorChrome;$script:LastGamepadMask=$Mask;return}
        if(Is-NewButtonPress $Mask 2048){Set-HcActiveConsoleModelViewerScale ([int]$script:HcModelEditorScalePercent-10);$script:HcModelViewerSpin=$false;Update-HcGpuModelViewerItem;Update-HcModelEditorChrome;$script:LastGamepadMask=$Mask;return}
    }
    if(Is-NewButtonPress $Mask 4){Save-HcModelOrientationEditor;$script:LastGamepadMask=$Mask;return}
    if(Is-NewButtonPress $Mask 8){Cancel-HcModelOrientationEditor;$script:LastGamepadMask=$Mask;return}
    if(Is-NewButtonPress $Mask 32){Reset-HcModelOrientationEditor;$script:LastGamepadMask=$Mask;return}
    $script:LastGamepadMask=$Mask
}

Initialize-HcModelDefaultViewConfig
# HUYMAIER_V0306_CONSOLE_MODEL_PRESENTATION_LOAD_V1
$script:HcConsoleModelPresentationPath=Join-Path $script:BaseDir 'HuymaierConsoleModelPresentation.ps1'
if(Test-Path -LiteralPath $script:HcConsoleModelPresentationPath -PathType Leaf){
    try{. $script:HcConsoleModelPresentationPath}
    catch{try{Write-Log ('Console model presentation editor load failed: '+$_.Exception.Message) 'ERROR'}catch{}}
}

