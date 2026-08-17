# HUYMAIER_V0306_CONSOLE_MODEL_PRESENTATION_EDITOR_V1
# HUYMAIER_V0307_CONSOLE_STUDIO_LIGHT_V1
# HUYMAIER_V0307_CONSOLE_STUDIO_LIGHT_ADVANCED_V1
# Console-only per-model presentation controls. Storefront/provider models are
# deliberately excluded and retain their existing presentation path unchanged.
# User GLB files are never modified; all corrections live in config.json.
Set-StrictMode -Version 2.0

$script:HcPresentationBaseOpenViewer=${function:Open-HcPlatformModelViewer}
$script:HcPresentationBaseCloseViewer=${function:Close-HcPlatformModelViewer}
$script:HcPresentationBaseApplyControllerNavigation=${function:Apply-ControllerNavigation}
$script:HcPresentationBaseUpdateGpuShelfLayoutForGroup=${function:Update-HcGpuShelfLayoutForGroup}
$script:HcPresentationBaseUpdateGpuModelViewerItem=${function:Update-HcGpuModelViewerItem}

$script:HcModelEditorFields=@('Yaw','Pitch','Roll','Scale','Position X','Position Y','Mirror X','Mirror Y','Mirror Z','Faces','Lighting','Light brightness','Light azimuth','Light elevation','Light distance','Light aim X','Light aim Y','Cone size','Cone softness','Light falloff','Light temp','Ambient','Specular','Highlight size','Fan motion')
$script:HcModelEditorFieldIndex=0
$script:HcModelEditorPanel=$null
$script:HcModelEditorPanelText=$null
$script:HcModelEditorOriginalView=$null
$script:HcModelEditorRoll=0.0
$script:HcModelEditorOffsetX=0
$script:HcModelEditorOffsetY=0
$script:HcModelEditorMirrorX=$false
$script:HcModelEditorMirrorY=$false
$script:HcModelEditorMirrorZ=$false
$script:HcModelEditorFaceMode='Normal'
$script:HcModelEditorLightPercent=100
$script:HcModelEditorKeyLightPercent=100
$script:HcModelEditorLightAzimuth=-36
$script:HcModelEditorLightElevation=43
$script:HcModelEditorLightDistance=8.0
$script:HcModelEditorLightAimXPercent=0
$script:HcModelEditorLightAimYPercent=0
$script:HcModelEditorConeDegrees=180
$script:HcModelEditorConeSoftnessPercent=50
$script:HcModelEditorFalloffPercent=0
$script:HcModelEditorLightTemperature=6500
$script:HcModelEditorAmbientPercent=100
$script:HcModelEditorSpecularPercent=100
$script:HcModelEditorHighlightSizePercent=100
$script:HcModelEditorFanPercent=100

function Test-HcConsoleModelPresentationEditable {
    param([string]$Platform)
    if([string]::IsNullOrWhiteSpace($Platform)){return $false}
    try{return (-not [bool](Test-HcStorefrontPlatform $Platform))}catch{return $true}
}
function Test-HcConsoleModelScaleEditable {param([string]$Platform);return (Test-HcConsoleModelPresentationEditable $Platform)}

function Normalize-HcModelRoll {param([double]$Roll);while($Roll-gt180.0){$Roll-=360.0};while($Roll-le-180.0){$Roll+=360.0};return [math]::Round($Roll,2)}
function Normalize-HcModelOffset {param([double]$Value);return [int]([math]::Round([math]::Max(-50.0,[math]::Min(50.0,$Value))/5.0)*5.0)}
function Normalize-HcModelLightPercent {param([double]$Value);return [int]([math]::Round([math]::Max(20.0,[math]::Min(400.0,$Value))/10.0)*10.0)}
function Normalize-HcModelKeyLightPercent {param([double]$Value);return [int]([math]::Round([math]::Max(0.0,[math]::Min(500.0,$Value))/10.0)*10.0)}
function Normalize-HcModelLightAzimuth {param([double]$Value);while($Value-gt180.0){$Value-=360.0};while($Value-le-180.0){$Value+=360.0};return [int]([math]::Round($Value))}
function Normalize-HcModelLightElevation {param([double]$Value);return [int]([math]::Round([math]::Max(-89.0,[math]::Min(89.0,$Value))))}
function Normalize-HcModelLightTemperature {param([double]$Value);return [int]([math]::Round([math]::Max(1800.0,[math]::Min(12000.0,$Value))/100.0)*100.0)}
function Normalize-HcModelAmbientPercent {param([double]$Value);return [int]([math]::Round([math]::Max(0.0,[math]::Min(300.0,$Value))/10.0)*10.0)}
function Normalize-HcModelSpecularPercent {param([double]$Value);return [int]([math]::Round([math]::Max(0.0,[math]::Min(400.0,$Value))/10.0)*10.0)}
function Normalize-HcModelLightDistance {param([double]$Value);return [math]::Round([math]::Max(1.0,[math]::Min(20.0,$Value))*4.0)/4.0}
function Normalize-HcModelLightAimPercent {param([double]$Value);return [int]([math]::Round([math]::Max(-100.0,[math]::Min(100.0,$Value))/5.0)*5.0)}
function Normalize-HcModelConeDegrees {param([double]$Value);return [int]([math]::Round([math]::Max(5.0,[math]::Min(180.0,$Value))/5.0)*5.0)}
function Normalize-HcModelConeSoftnessPercent {param([double]$Value);return [int]([math]::Round([math]::Max(0.0,[math]::Min(100.0,$Value))/5.0)*5.0)}
function Normalize-HcModelFalloffPercent {param([double]$Value);return [int]([math]::Round([math]::Max(0.0,[math]::Min(200.0,$Value))/10.0)*10.0)}
function Normalize-HcModelHighlightSizePercent {param([double]$Value);return [int]([math]::Round([math]::Max(25.0,[math]::Min(400.0,$Value))/25.0)*25.0)}
function Normalize-HcModelFanPercent {param([double]$Value);return [int]([math]::Round([math]::Max(0.0,[math]::Min(100.0,$Value))/10.0)*10.0)}
function Normalize-HcModelFaceMode {
    param([string]$Value)
    switch(([string]$Value).Trim().ToLowerInvariant()){'reverse'{return 'Reverse'}'reversed'{return 'Reverse'}'twosided'{return 'TwoSided'}'two-sided'{return 'TwoSided'}'double-sided'{return 'TwoSided'}default{return 'Normal'}}
}

function Get-HcModelDefaultView {
    param([string]$ModelPath,[string]$Platform='')
    Initialize-HcModelDefaultViewConfig
    $key=Get-HcModelDefaultViewKey $ModelPath $Platform
    $yaw=0.0;$pitch=-10.0;$roll=0.0;$scalePercent=100;$offsetX=0;$offsetY=0;$mirrorX=$false;$mirrorY=$false;$mirrorZ=$false;$faceMode='Normal';$light=100;$keyLight=100;$lightAzimuth=-36;$lightElevation=43;$lightDistance=8.0;$lightAimX=0;$lightAimY=0;$coneDegrees=180;$coneSoftness=50;$falloff=0;$lightTemperature=6500;$ambient=100;$specular=100;$highlightSize=100;$fan=100
    if($key){
        foreach($entry in @($script:Config.PlatformModelDefaultViews)){
            if($null-eq$entry){continue}
            $entryKey=[string](Get-EntryProperty $entry 'Key' '')
            if(-not$entryKey){$entryKey=Get-HcModelDefaultViewKey ([string](Get-EntryProperty $entry 'Model' '')) ([string](Get-EntryProperty $entry 'Platform' ''))}
            if(-not[string]::Equals($entryKey,$key,[StringComparison]::OrdinalIgnoreCase)){continue}
            try{$yaw=Normalize-HcModelYaw ([double](Get-EntryProperty $entry 'Yaw' 0.0))}catch{}
            try{$pitch=[math]::Max(-80.0,[math]::Min(80.0,[double](Get-EntryProperty $entry 'Pitch' -10.0)))}catch{}
            try{$roll=Normalize-HcModelRoll ([double](Get-EntryProperty $entry 'Roll' 0.0))}catch{}
            try{$scalePercent=Normalize-HcModelScalePercent ([double](Get-EntryProperty $entry 'ScalePercent' 100))}catch{}
            try{$offsetX=Normalize-HcModelOffset ([double](Get-EntryProperty $entry 'OffsetX' 0))}catch{}
            try{$offsetY=Normalize-HcModelOffset ([double](Get-EntryProperty $entry 'OffsetY' 0))}catch{}
            try{$mirrorX=[bool](Get-EntryProperty $entry 'MirrorX' $false)}catch{}
            try{$mirrorY=[bool](Get-EntryProperty $entry 'MirrorY' $false)}catch{}
            try{$mirrorZ=[bool](Get-EntryProperty $entry 'MirrorZ' $false)}catch{}
            try{$faceMode=Normalize-HcModelFaceMode ([string](Get-EntryProperty $entry 'FaceMode' 'Normal'))}catch{}
            try{$light=Normalize-HcModelLightPercent ([double](Get-EntryProperty $entry 'LightPercent' 100))}catch{}
            try{$keyLight=Normalize-HcModelKeyLightPercent ([double](Get-EntryProperty $entry 'KeyLightPercent' 100))}catch{}
            try{$lightAzimuth=Normalize-HcModelLightAzimuth ([double](Get-EntryProperty $entry 'LightAzimuth' -36))}catch{}
            try{$lightElevation=Normalize-HcModelLightElevation ([double](Get-EntryProperty $entry 'LightElevation' 43))}catch{}
            try{$lightDistance=Normalize-HcModelLightDistance ([double](Get-EntryProperty $entry 'LightDistance' 8.0))}catch{}
            try{$lightAimX=Normalize-HcModelLightAimPercent ([double](Get-EntryProperty $entry 'LightAimXPercent' 0))}catch{}
            try{$lightAimY=Normalize-HcModelLightAimPercent ([double](Get-EntryProperty $entry 'LightAimYPercent' 0))}catch{}
            try{$coneDegrees=Normalize-HcModelConeDegrees ([double](Get-EntryProperty $entry 'ConeDegrees' 180))}catch{}
            try{$coneSoftness=Normalize-HcModelConeSoftnessPercent ([double](Get-EntryProperty $entry 'ConeSoftnessPercent' 50))}catch{}
            try{$falloff=Normalize-HcModelFalloffPercent ([double](Get-EntryProperty $entry 'FalloffPercent' 0))}catch{}
            try{$lightTemperature=Normalize-HcModelLightTemperature ([double](Get-EntryProperty $entry 'LightTemperature' 6500))}catch{}
            try{$ambient=Normalize-HcModelAmbientPercent ([double](Get-EntryProperty $entry 'AmbientPercent' 100))}catch{}
            try{$specular=Normalize-HcModelSpecularPercent ([double](Get-EntryProperty $entry 'SpecularPercent' 100))}catch{}
            try{$highlightSize=Normalize-HcModelHighlightSizePercent ([double](Get-EntryProperty $entry 'HighlightSizePercent' 100))}catch{}
            try{$fan=Normalize-HcModelFanPercent ([double](Get-EntryProperty $entry 'FanPercent' 100))}catch{}
            break
        }
    }
    # Providers are intentionally neutral even if an old configuration entry exists.
    if(-not(Test-HcConsoleModelPresentationEditable $Platform)){$scalePercent=100;$roll=0;$offsetX=0;$offsetY=0;$mirrorX=$false;$mirrorY=$false;$mirrorZ=$false;$faceMode='Normal';$light=100;$keyLight=100;$lightAzimuth=-36;$lightElevation=43;$lightDistance=8.0;$lightAimX=0;$lightAimY=0;$coneDegrees=180;$coneSoftness=50;$falloff=0;$lightTemperature=6500;$ambient=100;$specular=100;$highlightSize=100;$fan=100}
    return [pscustomobject]@{Key=$key;Yaw=[double]$yaw;Pitch=[double]$pitch;Roll=[double]$roll;ScalePercent=[int]$scalePercent;OffsetX=[int]$offsetX;OffsetY=[int]$offsetY;MirrorX=[bool]$mirrorX;MirrorY=[bool]$mirrorY;MirrorZ=[bool]$mirrorZ;FaceMode=$faceMode;LightPercent=[int]$light;KeyLightPercent=[int]$keyLight;LightAzimuth=[int]$lightAzimuth;LightElevation=[int]$lightElevation;LightDistance=[double]$lightDistance;LightAimXPercent=[int]$lightAimX;LightAimYPercent=[int]$lightAimY;ConeDegrees=[int]$coneDegrees;ConeSoftnessPercent=[int]$coneSoftness;FalloffPercent=[int]$falloff;LightTemperature=[int]$lightTemperature;AmbientPercent=[int]$ambient;SpecularPercent=[int]$specular;HighlightSizePercent=[int]$highlightSize;FanPercent=[int]$fan}
}

function Set-HcModelDefaultView {
    param([string]$ModelPath,[string]$Platform,[double]$Yaw,[double]$Pitch,[int]$ScalePercent=100,[double]$Roll=0,[int]$OffsetX=0,[int]$OffsetY=0,[bool]$MirrorX=$false,[bool]$MirrorY=$false,[bool]$MirrorZ=$false,[string]$FaceMode='Normal',[int]$LightPercent=100,[int]$KeyLightPercent=100,[int]$LightAzimuth=-36,[int]$LightElevation=43,[double]$LightDistance=8.0,[int]$LightAimXPercent=0,[int]$LightAimYPercent=0,[int]$ConeDegrees=180,[int]$ConeSoftnessPercent=50,[int]$FalloffPercent=0,[int]$LightTemperature=6500,[int]$AmbientPercent=100,[int]$SpecularPercent=100,[int]$HighlightSizePercent=100,[int]$FanPercent=100)
    Initialize-HcModelDefaultViewConfig
    if(-not(Test-HcConsoleModelPresentationEditable $Platform)){return $false}
    $key=Get-HcModelDefaultViewKey $ModelPath $Platform;if([string]::IsNullOrWhiteSpace($key)){return $false}
    $items=New-Object System.Collections.ArrayList
    foreach($entry in @($script:Config.PlatformModelDefaultViews)){
        if($null-eq$entry){continue};$entryKey=[string](Get-EntryProperty $entry 'Key' '')
        if(-not$entryKey){$entryKey=Get-HcModelDefaultViewKey ([string](Get-EntryProperty $entry 'Model' '')) ([string](Get-EntryProperty $entry 'Platform' ''))}
        if(-not[string]::Equals($entryKey,$key,[StringComparison]::OrdinalIgnoreCase)){[void]$items.Add($entry)}
    }
    $modelName='';try{$modelName=[IO.Path]::GetFileName($ModelPath)}catch{}
    [void]$items.Add([pscustomobject]@{
        Key=$key;Model=$modelName;Platform=$Platform;Yaw=(Normalize-HcModelYaw $Yaw);Pitch=[math]::Round([math]::Max(-80.0,[math]::Min(80.0,$Pitch)),2);Roll=(Normalize-HcModelRoll $Roll)
        ScalePercent=(Normalize-HcModelScalePercent $ScalePercent);OffsetX=(Normalize-HcModelOffset $OffsetX);OffsetY=(Normalize-HcModelOffset $OffsetY)
        MirrorX=[bool]$MirrorX;MirrorY=[bool]$MirrorY;MirrorZ=[bool]$MirrorZ;FaceMode=(Normalize-HcModelFaceMode $FaceMode)
        LightPercent=(Normalize-HcModelLightPercent $LightPercent);KeyLightPercent=(Normalize-HcModelKeyLightPercent $KeyLightPercent);LightAzimuth=(Normalize-HcModelLightAzimuth $LightAzimuth);LightElevation=(Normalize-HcModelLightElevation $LightElevation);LightDistance=(Normalize-HcModelLightDistance $LightDistance);LightAimXPercent=(Normalize-HcModelLightAimPercent $LightAimXPercent);LightAimYPercent=(Normalize-HcModelLightAimPercent $LightAimYPercent);ConeDegrees=(Normalize-HcModelConeDegrees $ConeDegrees);ConeSoftnessPercent=(Normalize-HcModelConeSoftnessPercent $ConeSoftnessPercent);FalloffPercent=(Normalize-HcModelFalloffPercent $FalloffPercent);LightTemperature=(Normalize-HcModelLightTemperature $LightTemperature)
        AmbientPercent=(Normalize-HcModelAmbientPercent $AmbientPercent);SpecularPercent=(Normalize-HcModelSpecularPercent $SpecularPercent);HighlightSizePercent=(Normalize-HcModelHighlightSizePercent $HighlightSizePercent);FanPercent=(Normalize-HcModelFanPercent $FanPercent);UpdatedUtc=[DateTime]::UtcNow.ToString('o')
    })
    $script:Config.PlatformModelDefaultViews=[object[]]$items.ToArray();Save-Config;return $true
}

function Set-HcModelPresentationStateFromView {
    param($View)
    if($null-eq$View){return}
    $script:HcModelViewerYaw=[double]$View.Yaw;$script:HcModelViewerPitch=[double]$View.Pitch;$script:HcModelEditorRoll=[double]$View.Roll
    $script:HcModelEditorScalePercent=[int]$View.ScalePercent;$script:HcModelEditorOffsetX=[int]$View.OffsetX;$script:HcModelEditorOffsetY=[int]$View.OffsetY
    $script:HcModelEditorMirrorX=[bool]$View.MirrorX;$script:HcModelEditorMirrorY=[bool]$View.MirrorY;$script:HcModelEditorMirrorZ=[bool]$View.MirrorZ
    $script:HcModelEditorFaceMode=[string]$View.FaceMode;$script:HcModelEditorLightPercent=[int]$View.LightPercent;$script:HcModelEditorKeyLightPercent=[int]$View.KeyLightPercent;$script:HcModelEditorLightAzimuth=[int]$View.LightAzimuth;$script:HcModelEditorLightElevation=[int]$View.LightElevation;$script:HcModelEditorLightDistance=[double]$View.LightDistance;$script:HcModelEditorLightAimXPercent=[int]$View.LightAimXPercent;$script:HcModelEditorLightAimYPercent=[int]$View.LightAimYPercent;$script:HcModelEditorConeDegrees=[int]$View.ConeDegrees;$script:HcModelEditorConeSoftnessPercent=[int]$View.ConeSoftnessPercent;$script:HcModelEditorFalloffPercent=[int]$View.FalloffPercent;$script:HcModelEditorLightTemperature=[int]$View.LightTemperature;$script:HcModelEditorAmbientPercent=[int]$View.AmbientPercent;$script:HcModelEditorSpecularPercent=[int]$View.SpecularPercent;$script:HcModelEditorHighlightSizePercent=[int]$View.HighlightSizePercent;$script:HcModelEditorFanPercent=[int]$View.FanPercent
    Set-HcActiveConsoleModelViewerScale ([int]$View.ScalePercent)
}

function Get-HcModelEditorCurrentView {
    [pscustomobject]@{Yaw=[double]$script:HcModelViewerYaw;Pitch=[double]$script:HcModelViewerPitch;Roll=[double]$script:HcModelEditorRoll;ScalePercent=[int]$script:HcModelEditorScalePercent;OffsetX=[int]$script:HcModelEditorOffsetX;OffsetY=[int]$script:HcModelEditorOffsetY;MirrorX=[bool]$script:HcModelEditorMirrorX;MirrorY=[bool]$script:HcModelEditorMirrorY;MirrorZ=[bool]$script:HcModelEditorMirrorZ;FaceMode=[string]$script:HcModelEditorFaceMode;LightPercent=[int]$script:HcModelEditorLightPercent;KeyLightPercent=[int]$script:HcModelEditorKeyLightPercent;LightAzimuth=[int]$script:HcModelEditorLightAzimuth;LightElevation=[int]$script:HcModelEditorLightElevation;LightDistance=[double]$script:HcModelEditorLightDistance;LightAimXPercent=[int]$script:HcModelEditorLightAimXPercent;LightAimYPercent=[int]$script:HcModelEditorLightAimYPercent;ConeDegrees=[int]$script:HcModelEditorConeDegrees;ConeSoftnessPercent=[int]$script:HcModelEditorConeSoftnessPercent;FalloffPercent=[int]$script:HcModelEditorFalloffPercent;LightTemperature=[int]$script:HcModelEditorLightTemperature;AmbientPercent=[int]$script:HcModelEditorAmbientPercent;SpecularPercent=[int]$script:HcModelEditorSpecularPercent;HighlightSizePercent=[int]$script:HcModelEditorHighlightSizePercent;FanPercent=[int]$script:HcModelEditorFanPercent}
}

function Get-HcModelFaceModeCode {param([string]$Mode);switch(Normalize-HcModelFaceMode $Mode){'Reverse'{return 1}'TwoSided'{return 2}default{return 0}}}
function Apply-HcConsolePresentationToSurface {
    param($Surface,[int]$Id,$View,[bool]$Spin)
    if($null-eq$Surface-or$null-eq$View){return}
    if($Surface.PSObject.Methods['SetItemPresentation']){
        try{[void]$Surface.SetItemPresentation($Id,[double]$View.Yaw,[double]$View.Pitch,[double]$View.Roll,[double]$View.OffsetX,[double]$View.OffsetY,[bool]$View.MirrorX,[bool]$View.MirrorY,[bool]$View.MirrorZ,[int](Get-HcModelFaceModeCode ([string]$View.FaceMode),[double]$View.LightPercent/100.0,[double]$View.FanPercent/100.0,$Spin))}catch{}
    }elseif($Surface.PSObject.Methods['SetItemView']){try{[void]$Surface.SetItemView($Id,[double]$View.Yaw,[double]$View.Pitch,$Spin)}catch{}}
}

# The helper above is kept intentionally simple in PowerShell, but comma parsing
# around nested method arguments is brittle in Windows PowerShell 5.1. This
# explicit wrapper is the authoritative call site used below.
function Set-HcConsolePresentationOnSurface {
    param($Surface,[int]$Id,$View,[bool]$Spin)
    if($null-eq$Surface-or$null-eq$View){return}
    if($Surface.PSObject.Methods['SetItemPresentation']){
        try{
            $face=[int](Get-HcModelFaceModeCode ([string]$View.FaceMode));$light=[double]$View.LightPercent/100.0;$fan=[double]$View.FanPercent/100.0
            [void]$Surface.SetItemPresentation($Id,[double]$View.Yaw,[double]$View.Pitch,[double]$View.Roll,[double]$View.OffsetX,[double]$View.OffsetY,[bool]$View.MirrorX,[bool]$View.MirrorY,[bool]$View.MirrorZ,$face,$light,$fan,$Spin)
            if($Surface.PSObject.Methods['SetItemStudioLight']){[void]$Surface.SetItemStudioLight($Id,[double]$View.KeyLightPercent/100.0,[double]$View.LightAzimuth,[double]$View.LightElevation,[double]$View.LightDistance,[double]$View.LightAimXPercent/100.0,[double]$View.LightAimYPercent/100.0,[double]$View.ConeDegrees,[double]$View.ConeSoftnessPercent/100.0,[double]$View.FalloffPercent/100.0,[double]$View.LightTemperature,[double]$View.AmbientPercent/100.0,[double]$View.SpecularPercent/100.0,[double]$View.HighlightSizePercent/100.0)}
        }catch{}
    }elseif($Surface.PSObject.Methods['SetItemView']){try{[void]$Surface.SetItemView($Id,[double]$View.Yaw,[double]$View.Pitch,$Spin)}catch{}}
}

function Update-HcGpuModelViewerItem {
    & $script:HcPresentationBaseUpdateGpuModelViewerItem
    if(-not$script:HcModelViewerActive-or-not(Test-HcConsoleModelPresentationEditable ([string]$script:HcModelViewerPlatform))){return}
    $view=Get-HcModelEditorCurrentView
    Set-HcConsolePresentationOnSurface $script:HcModelViewerView 0 $view ([bool]$script:HcModelViewerSpin)
}

function Update-HcGpuShelfLayoutForGroup {
    param($Group,[bool]$Focused)
    & $script:HcPresentationBaseUpdateGpuShelfLayoutForGroup $Group $Focused
    if($null-eq$Group-or-not[string]::Equals([string]$Group.Key,'Consoles',[StringComparison]::OrdinalIgnoreCase)-or$null-eq$Group.Surface){return}
    foreach($card in @($Group.Cards)){
        if($null-eq$card-or-not[bool]$card.GpuReady-or[string]::IsNullOrWhiteSpace([string]$card.Path)){continue}
        try{$view=Get-HcModelDefaultView ([string]$card.Path) ([string]$card.Platform);Set-HcConsolePresentationOnSurface $Group.Surface ([int]$card.ActionIndex) $view $true}catch{}
    }
}

function Get-HcModelEditorValueText {
    param([string]$Field)
    switch($Field){
        'Yaw'{return (([math]::Round([double]$script:HcModelViewerYaw)).ToString()+'°')}
        'Pitch'{return (([math]::Round([double]$script:HcModelViewerPitch)).ToString()+'°')}
        'Roll'{return (([math]::Round([double]$script:HcModelEditorRoll)).ToString()+'°')}
        'Scale'{return ([int]$script:HcModelEditorScalePercent).ToString()+'%'}
        'Position X'{return ([int]$script:HcModelEditorOffsetX).ToString()+'%'}
        'Position Y'{return ([int]$script:HcModelEditorOffsetY).ToString()+'%'}
        'Mirror X'{return $(if($script:HcModelEditorMirrorX){'ON'}else{'OFF'})}
        'Mirror Y'{return $(if($script:HcModelEditorMirrorY){'ON'}else{'OFF'})}
        'Mirror Z'{return $(if($script:HcModelEditorMirrorZ){'ON'}else{'OFF'})}
        'Faces'{return [string]$script:HcModelEditorFaceMode}
        'Lighting'{return ([int]$script:HcModelEditorLightPercent).ToString()+'%'}
        'Light brightness'{return ([int]$script:HcModelEditorKeyLightPercent).ToString()+'%'}
        'Light azimuth'{return ([int]$script:HcModelEditorLightAzimuth).ToString()+'Â°'}
        'Light elevation'{return ([int]$script:HcModelEditorLightElevation).ToString()+'Â°'}
        'Light distance'{return ([double]$script:HcModelEditorLightDistance).ToString('0.00')}
        'Light aim X'{return ([int]$script:HcModelEditorLightAimXPercent).ToString()+'%'}
        'Light aim Y'{return ([int]$script:HcModelEditorLightAimYPercent).ToString()+'%'}
        'Cone size'{return ([int]$script:HcModelEditorConeDegrees).ToString()+'Â°'}
        'Cone softness'{return ([int]$script:HcModelEditorConeSoftnessPercent).ToString()+'%'}
        'Light falloff'{return ([int]$script:HcModelEditorFalloffPercent).ToString()+'%'}
        'Light temp'{return ([int]$script:HcModelEditorLightTemperature).ToString()+'K'}
        'Ambient'{return ([int]$script:HcModelEditorAmbientPercent).ToString()+'%'}
        'Specular'{return ([int]$script:HcModelEditorSpecularPercent).ToString()+'%'}
        'Highlight size'{return ([int]$script:HcModelEditorHighlightSizePercent).ToString()+'%'}
        'Fan motion'{return ([int]$script:HcModelEditorFanPercent).ToString()+'%'}
    }
    return ''
}

function Update-HcModelEditorPanelText {
    if($null-eq$script:HcModelEditorPanelText){return}
    $lines=New-Object System.Collections.Generic.List[string]
    [void]$lines.Add('CONSOLE MODEL')
    [void]$lines.Add('')
    for($i=0;$i-lt$script:HcModelEditorFields.Count;$i++){$field=[string]$script:HcModelEditorFields[$i];$prefix=$(if($i-eq[int]$script:HcModelEditorFieldIndex){'› '}else{'  '});[void]$lines.Add($prefix+$field.PadRight(13)+'  '+(Get-HcModelEditorValueText $field))}
    [void]$lines.Add('');[void]$lines.Add('Up/Down  Select');[void]$lines.Add('Left/Right  Adjust');[void]$lines.Add('LB/RB  Previous/Next')
    $script:HcModelEditorPanelText.Text=($lines-join"`r`n")
}

function Update-HcModelEditorChrome {
    if(-not$script:HcModelViewerActive-or$null-eq$script:HcModelViewerOverlay){return}
    $editable=Test-HcConsoleModelPresentationEditable ([string]$script:HcModelViewerPlatform)
    try{
        if($null-eq$script:HcModelEditorHint){foreach($child in @($script:HcModelViewerOverlay.Children)){if($child-is[System.Windows.Controls.TextBlock]-and[System.Windows.Controls.Grid]::GetRow($child)-eq2){$script:HcModelEditorHint=$child;break}}}
        if($script:HcModelEditorHint){
            if($script:HcModelEditorActive){$field=[string]$script:HcModelEditorFields[[int]$script:HcModelEditorFieldIndex];$script:HcModelEditorHint.Text=('EDIT MODEL  •  '+$field+' = '+(Get-HcModelEditorValueText $field)+'  •  D-PAD Adjust  •  A Save  •  Y Reset  •  B Cancel');$script:HcModelEditorHint.HorizontalAlignment='Left';$script:HcModelEditorHint.Margin='42,0,390,0'}
            elseif($editable){$script:HcModelEditorHint.Text='LEFT STICK / D-PAD Rotate temporary  •  X/Square Edit Model  •  A/Cross Saved View  •  B/Circle Back';$script:HcModelEditorHint.HorizontalAlignment='Left';$script:HcModelEditorHint.Margin='42,0,210,0'}
            else{$script:HcModelEditorHint.Text='LEFT STICK / D-PAD Rotate temporary  •  LB / RB Zoom  •  A/Cross Reset View  •  B/Circle Back';$script:HcModelEditorHint.HorizontalAlignment='Center';$script:HcModelEditorHint.Margin='0'}
        }
        if($editable-and$null-eq$script:HcModelEditorButton){
            $button=New-Object System.Windows.Controls.Button;$button.Content='EDIT MODEL';$button.Width=148;$button.Height=40;$button.Margin='0,14,42,14';$button.HorizontalAlignment='Right';$button.VerticalAlignment='Center';$button.FontSize=14;$button.FontWeight='SemiBold';$button.Foreground='White';$button.Background='#26384F';$button.BorderBrush='#7489A4';$button.BorderThickness='1';$button.Cursor='Hand';$button.Add_Click({try{Enter-HcModelOrientationEditor}catch{}});[System.Windows.Controls.Grid]::SetRow($button,2);[void]$script:HcModelViewerOverlay.Children.Add($button);$script:HcModelEditorButton=$button
        }
        if($script:HcModelEditorButton){$script:HcModelEditorButton.Visibility=$(if($editable){'Visible'}else{'Collapsed'});$script:HcModelEditorButton.Content=$(if($script:HcModelEditorActive){'EDITING…'}else{'EDIT MODEL'});$script:HcModelEditorButton.IsEnabled=(-not$script:HcModelEditorActive)}
        if($editable-and$null-eq$script:HcModelEditorPanel){
            $border=New-Object System.Windows.Controls.Border;$border.Width=310;$border.HorizontalAlignment='Right';$border.VerticalAlignment='Center';$border.Margin='0,28,58,28';$border.Padding='18';$border.Background='#E5121B27';$border.BorderBrush='#526B89';$border.BorderThickness='1';$border.CornerRadius='14';$border.Visibility='Collapsed'
            $text=New-Object System.Windows.Controls.TextBlock;$text.FontFamily='Consolas';$text.FontSize=15;$text.Foreground='#E8EEF7';$text.LineHeight=22;$border.Child=$text;[System.Windows.Controls.Grid]::SetRow($border,1);[void]$script:HcModelViewerOverlay.Children.Add($border);$script:HcModelEditorPanel=$border;$script:HcModelEditorPanelText=$text
        }
        if($script:HcModelEditorPanel){$script:HcModelEditorPanel.Visibility=$(if($editable-and$script:HcModelEditorActive){'Visible'}else{'Collapsed'});Update-HcModelEditorPanelText}
    }catch{try{Write-Log ('Console model presentation editor chrome recovered: '+$_.Exception.Message) 'WARN'}catch{}}
}

function Enter-HcModelOrientationEditor {
    if(-not$script:HcModelViewerActive-or$script:HcModelEditorActive-or-not(Test-HcConsoleModelPresentationEditable ([string]$script:HcModelViewerPlatform))){return}
    $saved=Get-HcActiveModelDefaultView;$script:HcModelEditorOriginalView=$saved;Set-HcModelPresentationStateFromView $saved;$script:HcModelEditorFieldIndex=0;$script:HcModelViewerSpin=$false;$script:HcModelEditorActive=$true;Update-HcGpuModelViewerItem;Update-HcModelEditorChrome
    try{Set-ConsoleNotice ('Editing full 3D presentation for '+$script:HcModelViewerPlatform+'.') 'INFO'}catch{}
}

function Save-HcModelOrientationEditor {
    if(-not$script:HcModelEditorActive){return}
    $v=Get-HcModelEditorCurrentView
    if(Set-HcModelDefaultView -ModelPath ([string]$script:HcModelViewerModelPath) -Platform ([string]$script:HcModelViewerPlatform) -Yaw $v.Yaw -Pitch $v.Pitch -ScalePercent $v.ScalePercent -Roll $v.Roll -OffsetX $v.OffsetX -OffsetY $v.OffsetY -MirrorX $v.MirrorX -MirrorY $v.MirrorY -MirrorZ $v.MirrorZ -FaceMode $v.FaceMode -LightPercent $v.LightPercent -KeyLightPercent $v.KeyLightPercent -LightAzimuth $v.LightAzimuth -LightElevation $v.LightElevation -LightDistance $v.LightDistance -LightAimXPercent $v.LightAimXPercent -LightAimYPercent $v.LightAimYPercent -ConeDegrees $v.ConeDegrees -ConeSoftnessPercent $v.ConeSoftnessPercent -FalloffPercent $v.FalloffPercent -LightTemperature $v.LightTemperature -AmbientPercent $v.AmbientPercent -SpecularPercent $v.SpecularPercent -HighlightSizePercent $v.HighlightSizePercent -FanPercent $v.FanPercent){try{Set-ConsoleNotice ('Saved 3D model presentation for '+$script:HcModelViewerPlatform+'.') 'INFO'}catch{}}
    $script:HcModelEditorOriginalView=Get-HcActiveModelDefaultView;$script:HcModelEditorActive=$false;$script:HcModelViewerSpin=([int]$script:HcModelEditorFanPercent-gt0);Update-HcGpuModelViewerItem;Update-HcModelEditorChrome;try{Update-HcGpuShelfLayout}catch{}
}

function Reset-HcModelOrientationEditor {
    if(-not$script:HcModelViewerActive-or-not(Test-HcConsoleModelPresentationEditable ([string]$script:HcModelViewerPlatform))){return}
    Reset-HcModelDefaultView ([string]$script:HcModelViewerModelPath) ([string]$script:HcModelViewerPlatform);$defaults=Get-HcModelDefaultView ([string]$script:HcModelViewerModelPath) ([string]$script:HcModelViewerPlatform);Set-HcModelPresentationStateFromView $defaults;$script:HcModelEditorOriginalView=$defaults;$script:HcModelEditorActive=$false;$script:HcModelViewerSpin=$true;Update-HcGpuModelViewerItem;Update-HcModelEditorChrome;try{Update-HcGpuShelfLayout}catch{};try{Set-ConsoleNotice ('Reset 3D presentation for '+$script:HcModelViewerPlatform+'.') 'INFO'}catch{}
}

function Cancel-HcModelOrientationEditor {
    if(-not$script:HcModelEditorActive){return};if($script:HcModelEditorOriginalView){Set-HcModelPresentationStateFromView $script:HcModelEditorOriginalView};$script:HcModelEditorActive=$false;$script:HcModelViewerSpin=([int]$script:HcModelEditorFanPercent-gt0);Update-HcGpuModelViewerItem;Update-HcModelEditorChrome
}

function Step-HcModelEditorField {param([int]$Delta);$count=[int]$script:HcModelEditorFields.Count;if($count-le0){return};$script:HcModelEditorFieldIndex=([int]$script:HcModelEditorFieldIndex+$Delta+$count)%$count;Update-HcModelEditorChrome}
function Adjust-HcModelEditorField {
    param([int]$Delta)
    if($Delta-eq0){return};$field=[string]$script:HcModelEditorFields[[int]$script:HcModelEditorFieldIndex]
    switch($field){
        'Yaw'{$script:HcModelViewerYaw=Normalize-HcModelYaw ([double]$script:HcModelViewerYaw+5*$Delta)}
        'Pitch'{$script:HcModelViewerPitch=[math]::Max(-80.0,[math]::Min(80.0,[double]$script:HcModelViewerPitch+5*$Delta))}
        'Roll'{$script:HcModelEditorRoll=Normalize-HcModelRoll ([double]$script:HcModelEditorRoll+5*$Delta)}
        'Scale'{Set-HcActiveConsoleModelViewerScale ([int]$script:HcModelEditorScalePercent+10*$Delta)}
        'Position X'{$script:HcModelEditorOffsetX=Normalize-HcModelOffset ([int]$script:HcModelEditorOffsetX+5*$Delta)}
        'Position Y'{$script:HcModelEditorOffsetY=Normalize-HcModelOffset ([int]$script:HcModelEditorOffsetY+5*$Delta)}
        'Mirror X'{$script:HcModelEditorMirrorX=-not[bool]$script:HcModelEditorMirrorX}
        'Mirror Y'{$script:HcModelEditorMirrorY=-not[bool]$script:HcModelEditorMirrorY}
        'Mirror Z'{$script:HcModelEditorMirrorZ=-not[bool]$script:HcModelEditorMirrorZ}
        'Faces'{if($Delta-gt0){$script:HcModelEditorFaceMode=$(switch($script:HcModelEditorFaceMode){'Normal'{'Reverse'}'Reverse'{'TwoSided'}default{'Normal'}})}else{$script:HcModelEditorFaceMode=$(switch($script:HcModelEditorFaceMode){'Normal'{'TwoSided'}'TwoSided'{'Reverse'}default{'Normal'}})}}
        'Lighting'{$script:HcModelEditorLightPercent=Normalize-HcModelLightPercent ([int]$script:HcModelEditorLightPercent+10*$Delta)}
        'Light brightness'{$script:HcModelEditorKeyLightPercent=Normalize-HcModelKeyLightPercent ([int]$script:HcModelEditorKeyLightPercent+10*$Delta)}
        'Light azimuth'{$script:HcModelEditorLightAzimuth=Normalize-HcModelLightAzimuth ([int]$script:HcModelEditorLightAzimuth+1*$Delta)}
        'Light elevation'{$script:HcModelEditorLightElevation=Normalize-HcModelLightElevation ([int]$script:HcModelEditorLightElevation+1*$Delta)}
        'Light distance'{$script:HcModelEditorLightDistance=Normalize-HcModelLightDistance ([double]$script:HcModelEditorLightDistance+0.25*$Delta)}
        'Light aim X'{$script:HcModelEditorLightAimXPercent=Normalize-HcModelLightAimPercent ([int]$script:HcModelEditorLightAimXPercent+5*$Delta)}
        'Light aim Y'{$script:HcModelEditorLightAimYPercent=Normalize-HcModelLightAimPercent ([int]$script:HcModelEditorLightAimYPercent+5*$Delta)}
        'Cone size'{$script:HcModelEditorConeDegrees=Normalize-HcModelConeDegrees ([int]$script:HcModelEditorConeDegrees+5*$Delta)}
        'Cone softness'{$script:HcModelEditorConeSoftnessPercent=Normalize-HcModelConeSoftnessPercent ([int]$script:HcModelEditorConeSoftnessPercent+5*$Delta)}
        'Light falloff'{$script:HcModelEditorFalloffPercent=Normalize-HcModelFalloffPercent ([int]$script:HcModelEditorFalloffPercent+10*$Delta)}
        'Light temp'{$script:HcModelEditorLightTemperature=Normalize-HcModelLightTemperature ([int]$script:HcModelEditorLightTemperature+100*$Delta)}
        'Ambient'{$script:HcModelEditorAmbientPercent=Normalize-HcModelAmbientPercent ([int]$script:HcModelEditorAmbientPercent+10*$Delta)}
        'Specular'{$script:HcModelEditorSpecularPercent=Normalize-HcModelSpecularPercent ([int]$script:HcModelEditorSpecularPercent+10*$Delta)}
        'Highlight size'{$script:HcModelEditorHighlightSizePercent=Normalize-HcModelHighlightSizePercent ([int]$script:HcModelEditorHighlightSizePercent+25*$Delta)}
        'Fan motion'{$script:HcModelEditorFanPercent=Normalize-HcModelFanPercent ([int]$script:HcModelEditorFanPercent+10*$Delta)}
    }
    $script:HcModelViewerSpin=$false;Update-HcGpuModelViewerItem;Update-HcModelEditorChrome
}

function Open-HcPlatformModelViewer {
    param([string]$Platform,[string]$ModelPath='')
    $opened=[bool](& $script:HcPresentationBaseOpenViewer $Platform $ModelPath);if(-not$opened){return $false}
    if(Test-HcConsoleModelPresentationEditable $Platform){$saved=Get-HcActiveModelDefaultView;Set-HcModelPresentationStateFromView $saved;$script:HcModelViewerSpin=([int]$saved.FanPercent-gt0);Update-HcGpuModelViewerItem}
    $script:HcModelEditorPanel=$null;$script:HcModelEditorPanelText=$null;$script:HcModelEditorOriginalView=$null;Update-HcModelEditorChrome;return $true
}
function Close-HcPlatformModelViewer {$script:HcModelEditorPanel=$null;$script:HcModelEditorPanelText=$null;$script:HcModelEditorOriginalView=$null;& $script:HcPresentationBaseCloseViewer}

function Apply-ControllerNavigation {
    param([int]$Mask,[string]$Direction)
    if(-not$script:HcModelViewerActive){& $script:HcPresentationBaseApplyControllerNavigation $Mask $Direction;return}
    $editable=Test-HcConsoleModelPresentationEditable ([string]$script:HcModelViewerPlatform)
    if(-not$editable){
        # Providers are intentionally immutable from Edit Model.
        if(Is-NewButtonPress $Mask 16){$script:LastGamepadMask=$Mask;return}
        & $script:HcPresentationBaseApplyControllerNavigation $Mask $Direction;return
    }
    if(-not$script:HcModelEditorActive){& $script:HcPresentationBaseApplyControllerNavigation $Mask $Direction;return}
    if(Is-NewButtonPress $Mask 2){Cancel-HcModelOrientationEditor;$script:LastGamepadMask=$Mask;return}
    $now=Get-Date
    if($Direction){
        if($Direction-ne$script:LastDirection-or$now-ge$script:NextDirectionAt){
            switch($Direction){'Up'{Step-HcModelEditorField -1}'Down'{Step-HcModelEditorField 1}'Left'{Adjust-HcModelEditorField -1}'Right'{Adjust-HcModelEditorField 1}}
            $newDirection=$Direction-ne$script:LastDirection;$script:LastDirection=$Direction;$script:NextDirectionAt=$now.AddMilliseconds($(if($newDirection){170}else{80}))
        }
    }else{$script:LastDirection='';$script:NextDirectionAt=[datetime]::MinValue}
    if(Is-NewButtonPress $Mask 1024){Step-HcModelEditorField -1;$script:LastGamepadMask=$Mask;return}
    if(Is-NewButtonPress $Mask 2048){Step-HcModelEditorField 1;$script:LastGamepadMask=$Mask;return}
    if(Is-NewButtonPress $Mask 4){Save-HcModelOrientationEditor;$script:LastGamepadMask=$Mask;return}
    if(Is-NewButtonPress $Mask 8){Cancel-HcModelOrientationEditor;$script:LastGamepadMask=$Mask;return}
    if(Is-NewButtonPress $Mask 32){Reset-HcModelOrientationEditor;$script:LastGamepadMask=$Mask;return}
    $script:LastGamepadMask=$Mask
}

try{Write-Log 'Console-only full 3D model presentation editor initialized.'}catch{}


