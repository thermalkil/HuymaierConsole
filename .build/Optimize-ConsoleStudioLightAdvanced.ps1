param()
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$module=Join-Path $root 'HuymaierConsoleModelPresentation.ps1'
$hostPath=Join-Path $root 'Native\HuymaierD3D11ShelfHost.cs'
$runtimePath=Join-Path $root 'Native\HuymaierD3D11ShelfRuntime.cpp'
$assetPath=Join-Path $root 'Native\HuymaierD3D11ShelfAsset.h'
foreach($p in @($module,$hostPath,$runtimePath,$assetPath)){if(-not(Test-Path -LiteralPath $p -PathType Leaf)){throw "v0.30.7 advanced studio-light source missing: $p"}}
$nl=[Environment]::NewLine
function Replace-HcOnce([string]$Text,[string]$Old,[string]$New,[string]$Label){
    $count=([regex]::Matches($Text,[regex]::Escape($Old))).Count
    if($count-ne1){throw "v0.30.7 advanced light expected exactly one $Label anchor, found $count."}
    return $Text.Replace($Old,$New)
}

# HUYMAIER_V0307_CONSOLE_STUDIO_LIGHT_ADVANCED_TRANSFORM_V1
$moduleText=Get-Content -Raw -LiteralPath $module -Encoding UTF8
if($moduleText -notmatch 'HUYMAIER_V0307_CONSOLE_STUDIO_LIGHT_ADVANCED_V1'){
    if($moduleText -notmatch 'HUYMAIER_V0307_CONSOLE_STUDIO_LIGHT_V1'){throw 'Advanced studio light requires the base v0.30.7 studio-light transform first.'}
    $moduleText=$moduleText.Replace('# HUYMAIER_V0307_CONSOLE_STUDIO_LIGHT_V1','# HUYMAIER_V0307_CONSOLE_STUDIO_LIGHT_V1'+$nl+'# HUYMAIER_V0307_CONSOLE_STUDIO_LIGHT_ADVANCED_V1')

    $moduleText=Replace-HcOnce $moduleText "'Key light','Light azimuth','Light elevation','Light temp','Ambient','Specular'" "'Light brightness','Light azimuth','Light elevation','Light distance','Light aim X','Light aim Y','Cone size','Cone softness','Light falloff','Light temp','Ambient','Specular','Highlight size'" 'advanced editor fields'

    $old=@'
$script:HcModelEditorKeyLightPercent=100
$script:HcModelEditorLightAzimuth=-36
$script:HcModelEditorLightElevation=43
$script:HcModelEditorLightTemperature=6500
$script:HcModelEditorAmbientPercent=100
$script:HcModelEditorSpecularPercent=100
'@.TrimEnd()
    $new=@'
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
'@.TrimEnd()
    $moduleText=Replace-HcOnce $moduleText $old $new 'advanced editor state'

    $moduleText=Replace-HcOnce $moduleText 'function Normalize-HcModelLightPercent {param([double]$Value);return [int]([math]::Round([math]::Max(20.0,[math]::Min(200.0,$Value))/10.0)*10.0)}' 'function Normalize-HcModelLightPercent {param([double]$Value);return [int]([math]::Round([math]::Max(20.0,[math]::Min(400.0,$Value))/10.0)*10.0)}' 'overall lighting range'
    $moduleText=Replace-HcOnce $moduleText 'function Normalize-HcModelKeyLightPercent {param([double]$Value);return [int]([math]::Round([math]::Max(0.0,[math]::Min(200.0,$Value))/10.0)*10.0)}' 'function Normalize-HcModelKeyLightPercent {param([double]$Value);return [int]([math]::Round([math]::Max(0.0,[math]::Min(500.0,$Value))/10.0)*10.0)}' 'key-light brightness range'
    $moduleText=Replace-HcOnce $moduleText 'function Normalize-HcModelLightAzimuth {param([double]$Value);while($Value-gt180.0){$Value-=360.0};while($Value-le-180.0){$Value+=360.0};return [int]([math]::Round($Value/5.0)*5.0)}' 'function Normalize-HcModelLightAzimuth {param([double]$Value);while($Value-gt180.0){$Value-=360.0};while($Value-le-180.0){$Value+=360.0};return [int]([math]::Round($Value))}' 'azimuth precision'
    $moduleText=Replace-HcOnce $moduleText 'function Normalize-HcModelLightElevation {param([double]$Value);return [int]([math]::Round([math]::Max(-80.0,[math]::Min(80.0,$Value))/5.0)*5.0)}' 'function Normalize-HcModelLightElevation {param([double]$Value);return [int]([math]::Round([math]::Max(-89.0,[math]::Min(89.0,$Value))))}' 'elevation precision'
    $moduleText=Replace-HcOnce $moduleText 'function Normalize-HcModelLightTemperature {param([double]$Value);return [int]([math]::Round([math]::Max(2500.0,[math]::Min(9000.0,$Value))/500.0)*500.0)}' 'function Normalize-HcModelLightTemperature {param([double]$Value);return [int]([math]::Round([math]::Max(1800.0,[math]::Min(12000.0,$Value))/100.0)*100.0)}' 'temperature range'
    $moduleText=Replace-HcOnce $moduleText 'function Normalize-HcModelAmbientPercent {param([double]$Value);return [int]([math]::Round([math]::Max(0.0,[math]::Min(200.0,$Value))/10.0)*10.0)}' 'function Normalize-HcModelAmbientPercent {param([double]$Value);return [int]([math]::Round([math]::Max(0.0,[math]::Min(300.0,$Value))/10.0)*10.0)}' 'ambient range'
    $moduleText=Replace-HcOnce $moduleText 'function Normalize-HcModelSpecularPercent {param([double]$Value);return [int]([math]::Round([math]::Max(0.0,[math]::Min(200.0,$Value))/10.0)*10.0)}' ('function Normalize-HcModelSpecularPercent {param([double]$Value);return [int]([math]::Round([math]::Max(0.0,[math]::Min(400.0,$Value))/10.0)*10.0)}'+$nl+'function Normalize-HcModelLightDistance {param([double]$Value);return [math]::Round([math]::Max(1.0,[math]::Min(20.0,$Value))*4.0)/4.0}'+$nl+'function Normalize-HcModelLightAimPercent {param([double]$Value);return [int]([math]::Round([math]::Max(-100.0,[math]::Min(100.0,$Value))/5.0)*5.0)}'+$nl+'function Normalize-HcModelConeDegrees {param([double]$Value);return [int]([math]::Round([math]::Max(5.0,[math]::Min(180.0,$Value))/5.0)*5.0)}'+$nl+'function Normalize-HcModelConeSoftnessPercent {param([double]$Value);return [int]([math]::Round([math]::Max(0.0,[math]::Min(100.0,$Value))/5.0)*5.0)}'+$nl+'function Normalize-HcModelFalloffPercent {param([double]$Value);return [int]([math]::Round([math]::Max(0.0,[math]::Min(200.0,$Value))/10.0)*10.0)}'+$nl+'function Normalize-HcModelHighlightSizePercent {param([double]$Value);return [int]([math]::Round([math]::Max(25.0,[math]::Min(400.0,$Value))/25.0)*25.0)}') 'advanced light normalizers'

    $old='$yaw=0.0;$pitch=-10.0;$roll=0.0;$scalePercent=100;$offsetX=0;$offsetY=0;$mirrorX=$false;$mirrorY=$false;$mirrorZ=$false;$faceMode=''Normal'';$light=100;$keyLight=100;$lightAzimuth=-36;$lightElevation=43;$lightTemperature=6500;$ambient=100;$specular=100;$fan=100'
    $new='$yaw=0.0;$pitch=-10.0;$roll=0.0;$scalePercent=100;$offsetX=0;$offsetY=0;$mirrorX=$false;$mirrorY=$false;$mirrorZ=$false;$faceMode=''Normal'';$light=100;$keyLight=100;$lightAzimuth=-36;$lightElevation=43;$lightDistance=8.0;$lightAimX=0;$lightAimY=0;$coneDegrees=180;$coneSoftness=50;$falloff=0;$lightTemperature=6500;$ambient=100;$specular=100;$highlightSize=100;$fan=100'
    $moduleText=Replace-HcOnce $moduleText $old $new 'advanced defaults'

    $old=@'
            try{$lightTemperature=Normalize-HcModelLightTemperature ([double](Get-EntryProperty $entry 'LightTemperature' 6500))}catch{}
            try{$ambient=Normalize-HcModelAmbientPercent ([double](Get-EntryProperty $entry 'AmbientPercent' 100))}catch{}
            try{$specular=Normalize-HcModelSpecularPercent ([double](Get-EntryProperty $entry 'SpecularPercent' 100))}catch{}
'@.TrimEnd()
    $new=@'
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
'@.TrimEnd()
    $moduleText=Replace-HcOnce $moduleText $old $new 'advanced config reads'

    $old="if(-not(Test-HcConsoleModelPresentationEditable `$Platform)){`$scalePercent=100;`$roll=0;`$offsetX=0;`$offsetY=0;`$mirrorX=`$false;`$mirrorY=`$false;`$mirrorZ=`$false;`$faceMode='Normal';`$light=100;`$keyLight=100;`$lightAzimuth=-36;`$lightElevation=43;`$lightTemperature=6500;`$ambient=100;`$specular=100;`$fan=100}"
    $new="if(-not(Test-HcConsoleModelPresentationEditable `$Platform)){`$scalePercent=100;`$roll=0;`$offsetX=0;`$offsetY=0;`$mirrorX=`$false;`$mirrorY=`$false;`$mirrorZ=`$false;`$faceMode='Normal';`$light=100;`$keyLight=100;`$lightAzimuth=-36;`$lightElevation=43;`$lightDistance=8.0;`$lightAimX=0;`$lightAimY=0;`$coneDegrees=180;`$coneSoftness=50;`$falloff=0;`$lightTemperature=6500;`$ambient=100;`$specular=100;`$highlightSize=100;`$fan=100}"
    $moduleText=Replace-HcOnce $moduleText $old $new 'advanced provider neutralization'

    $moduleText=Replace-HcOnce $moduleText 'LightElevation=[int]$lightElevation;LightTemperature=[int]$lightTemperature;AmbientPercent=[int]$ambient;SpecularPercent=[int]$specular;FanPercent=[int]$fan' 'LightElevation=[int]$lightElevation;LightDistance=[double]$lightDistance;LightAimXPercent=[int]$lightAimX;LightAimYPercent=[int]$lightAimY;ConeDegrees=[int]$coneDegrees;ConeSoftnessPercent=[int]$coneSoftness;FalloffPercent=[int]$falloff;LightTemperature=[int]$lightTemperature;AmbientPercent=[int]$ambient;SpecularPercent=[int]$specular;HighlightSizePercent=[int]$highlightSize;FanPercent=[int]$fan' 'advanced view object'

    $old='[int]$LightAzimuth=-36,[int]$LightElevation=43,[int]$LightTemperature=6500,[int]$AmbientPercent=100,[int]$SpecularPercent=100,[int]$FanPercent=100)'
    $new='[int]$LightAzimuth=-36,[int]$LightElevation=43,[double]$LightDistance=8.0,[int]$LightAimXPercent=0,[int]$LightAimYPercent=0,[int]$ConeDegrees=180,[int]$ConeSoftnessPercent=50,[int]$FalloffPercent=0,[int]$LightTemperature=6500,[int]$AmbientPercent=100,[int]$SpecularPercent=100,[int]$HighlightSizePercent=100,[int]$FanPercent=100)'
    $moduleText=Replace-HcOnce $moduleText $old $new 'advanced save parameters'

    $old='LightPercent=(Normalize-HcModelLightPercent $LightPercent);KeyLightPercent=(Normalize-HcModelKeyLightPercent $KeyLightPercent);LightAzimuth=(Normalize-HcModelLightAzimuth $LightAzimuth);LightElevation=(Normalize-HcModelLightElevation $LightElevation);LightTemperature=(Normalize-HcModelLightTemperature $LightTemperature)'
    $new='LightPercent=(Normalize-HcModelLightPercent $LightPercent);KeyLightPercent=(Normalize-HcModelKeyLightPercent $KeyLightPercent);LightAzimuth=(Normalize-HcModelLightAzimuth $LightAzimuth);LightElevation=(Normalize-HcModelLightElevation $LightElevation);LightDistance=(Normalize-HcModelLightDistance $LightDistance);LightAimXPercent=(Normalize-HcModelLightAimPercent $LightAimXPercent);LightAimYPercent=(Normalize-HcModelLightAimPercent $LightAimYPercent);ConeDegrees=(Normalize-HcModelConeDegrees $ConeDegrees);ConeSoftnessPercent=(Normalize-HcModelConeSoftnessPercent $ConeSoftnessPercent);FalloffPercent=(Normalize-HcModelFalloffPercent $FalloffPercent);LightTemperature=(Normalize-HcModelLightTemperature $LightTemperature)'
    $moduleText=Replace-HcOnce $moduleText $old $new 'advanced persistence line 1'
    $moduleText=Replace-HcOnce $moduleText 'AmbientPercent=(Normalize-HcModelAmbientPercent $AmbientPercent);SpecularPercent=(Normalize-HcModelSpecularPercent $SpecularPercent);FanPercent=' 'AmbientPercent=(Normalize-HcModelAmbientPercent $AmbientPercent);SpecularPercent=(Normalize-HcModelSpecularPercent $SpecularPercent);HighlightSizePercent=(Normalize-HcModelHighlightSizePercent $HighlightSizePercent);FanPercent=' 'advanced persistence line 2'

    $moduleText=Replace-HcOnce $moduleText '$script:HcModelEditorLightElevation=[int]$View.LightElevation;$script:HcModelEditorLightTemperature=[int]$View.LightTemperature;$script:HcModelEditorAmbientPercent=[int]$View.AmbientPercent;$script:HcModelEditorSpecularPercent=[int]$View.SpecularPercent;' '$script:HcModelEditorLightElevation=[int]$View.LightElevation;$script:HcModelEditorLightDistance=[double]$View.LightDistance;$script:HcModelEditorLightAimXPercent=[int]$View.LightAimXPercent;$script:HcModelEditorLightAimYPercent=[int]$View.LightAimYPercent;$script:HcModelEditorConeDegrees=[int]$View.ConeDegrees;$script:HcModelEditorConeSoftnessPercent=[int]$View.ConeSoftnessPercent;$script:HcModelEditorFalloffPercent=[int]$View.FalloffPercent;$script:HcModelEditorLightTemperature=[int]$View.LightTemperature;$script:HcModelEditorAmbientPercent=[int]$View.AmbientPercent;$script:HcModelEditorSpecularPercent=[int]$View.SpecularPercent;$script:HcModelEditorHighlightSizePercent=[int]$View.HighlightSizePercent;' 'advanced editor state from view'

    $moduleText=Replace-HcOnce $moduleText 'LightElevation=[int]$script:HcModelEditorLightElevation;LightTemperature=[int]$script:HcModelEditorLightTemperature;AmbientPercent=[int]$script:HcModelEditorAmbientPercent;SpecularPercent=[int]$script:HcModelEditorSpecularPercent;' 'LightElevation=[int]$script:HcModelEditorLightElevation;LightDistance=[double]$script:HcModelEditorLightDistance;LightAimXPercent=[int]$script:HcModelEditorLightAimXPercent;LightAimYPercent=[int]$script:HcModelEditorLightAimYPercent;ConeDegrees=[int]$script:HcModelEditorConeDegrees;ConeSoftnessPercent=[int]$script:HcModelEditorConeSoftnessPercent;FalloffPercent=[int]$script:HcModelEditorFalloffPercent;LightTemperature=[int]$script:HcModelEditorLightTemperature;AmbientPercent=[int]$script:HcModelEditorAmbientPercent;SpecularPercent=[int]$script:HcModelEditorSpecularPercent;HighlightSizePercent=[int]$script:HcModelEditorHighlightSizePercent;' 'advanced current view'

    $old='SetItemStudioLight($Id,[double]$View.KeyLightPercent/100.0,[double]$View.LightAzimuth,[double]$View.LightElevation,[double]$View.LightTemperature,[double]$View.AmbientPercent/100.0,[double]$View.SpecularPercent/100.0)'
    $new='SetItemStudioLight($Id,[double]$View.KeyLightPercent/100.0,[double]$View.LightAzimuth,[double]$View.LightElevation,[double]$View.LightDistance,[double]$View.LightAimXPercent/100.0,[double]$View.LightAimYPercent/100.0,[double]$View.ConeDegrees,[double]$View.ConeSoftnessPercent/100.0,[double]$View.FalloffPercent/100.0,[double]$View.LightTemperature,[double]$View.AmbientPercent/100.0,[double]$View.SpecularPercent/100.0,[double]$View.HighlightSizePercent/100.0)'
    $moduleText=Replace-HcOnce $moduleText $old $new 'advanced surface light call'

    $moduleText=Replace-HcOnce $moduleText "        'Key light'{return ([int]`$script:HcModelEditorKeyLightPercent).ToString()+'%'}" "        'Light brightness'{return ([int]`$script:HcModelEditorKeyLightPercent).ToString()+'%'}" 'brightness label'
    $moduleText=Replace-HcOnce $moduleText "        'Light elevation'{return ([int]`$script:HcModelEditorLightElevation).ToString()+'°'}" ("        'Light elevation'{return ([int]`$script:HcModelEditorLightElevation).ToString()+'°'}"+$nl+"        'Light distance'{return ([double]`$script:HcModelEditorLightDistance).ToString('0.00')}"+$nl+"        'Light aim X'{return ([int]`$script:HcModelEditorLightAimXPercent).ToString()+'%'}"+$nl+"        'Light aim Y'{return ([int]`$script:HcModelEditorLightAimYPercent).ToString()+'%'}"+$nl+"        'Cone size'{return ([int]`$script:HcModelEditorConeDegrees).ToString()+'°'}"+$nl+"        'Cone softness'{return ([int]`$script:HcModelEditorConeSoftnessPercent).ToString()+'%'}"+$nl+"        'Light falloff'{return ([int]`$script:HcModelEditorFalloffPercent).ToString()+'%'}") 'advanced value text'
    $moduleText=Replace-HcOnce $moduleText "        'Specular'{return ([int]`$script:HcModelEditorSpecularPercent).ToString()+'%'}" ("        'Specular'{return ([int]`$script:HcModelEditorSpecularPercent).ToString()+'%'}"+$nl+"        'Highlight size'{return ([int]`$script:HcModelEditorHighlightSizePercent).ToString()+'%'}") 'highlight value text'

    $old='-KeyLightPercent $v.KeyLightPercent -LightAzimuth $v.LightAzimuth -LightElevation $v.LightElevation -LightTemperature $v.LightTemperature -AmbientPercent $v.AmbientPercent -SpecularPercent $v.SpecularPercent -FanPercent $v.FanPercent)'
    $new='-KeyLightPercent $v.KeyLightPercent -LightAzimuth $v.LightAzimuth -LightElevation $v.LightElevation -LightDistance $v.LightDistance -LightAimXPercent $v.LightAimXPercent -LightAimYPercent $v.LightAimYPercent -ConeDegrees $v.ConeDegrees -ConeSoftnessPercent $v.ConeSoftnessPercent -FalloffPercent $v.FalloffPercent -LightTemperature $v.LightTemperature -AmbientPercent $v.AmbientPercent -SpecularPercent $v.SpecularPercent -HighlightSizePercent $v.HighlightSizePercent -FanPercent $v.FanPercent)'
    $moduleText=Replace-HcOnce $moduleText $old $new 'advanced save arguments'

    $moduleText=Replace-HcOnce $moduleText "        'Key light'{`$script:HcModelEditorKeyLightPercent=Normalize-HcModelKeyLightPercent ([int]`$script:HcModelEditorKeyLightPercent+10*`$Delta)}" "        'Light brightness'{`$script:HcModelEditorKeyLightPercent=Normalize-HcModelKeyLightPercent ([int]`$script:HcModelEditorKeyLightPercent+10*`$Delta)}" 'advanced brightness adjustment'
    $moduleText=Replace-HcOnce $moduleText "        'Light azimuth'{`$script:HcModelEditorLightAzimuth=Normalize-HcModelLightAzimuth ([int]`$script:HcModelEditorLightAzimuth+5*`$Delta)}" "        'Light azimuth'{`$script:HcModelEditorLightAzimuth=Normalize-HcModelLightAzimuth ([int]`$script:HcModelEditorLightAzimuth+1*`$Delta)}" 'azimuth adjustment precision'
    $moduleText=Replace-HcOnce $moduleText "        'Light elevation'{`$script:HcModelEditorLightElevation=Normalize-HcModelLightElevation ([int]`$script:HcModelEditorLightElevation+5*`$Delta)}" ("        'Light elevation'{`$script:HcModelEditorLightElevation=Normalize-HcModelLightElevation ([int]`$script:HcModelEditorLightElevation+1*`$Delta)}"+$nl+"        'Light distance'{`$script:HcModelEditorLightDistance=Normalize-HcModelLightDistance ([double]`$script:HcModelEditorLightDistance+0.25*`$Delta)}"+$nl+"        'Light aim X'{`$script:HcModelEditorLightAimXPercent=Normalize-HcModelLightAimPercent ([int]`$script:HcModelEditorLightAimXPercent+5*`$Delta)}"+$nl+"        'Light aim Y'{`$script:HcModelEditorLightAimYPercent=Normalize-HcModelLightAimPercent ([int]`$script:HcModelEditorLightAimYPercent+5*`$Delta)}"+$nl+"        'Cone size'{`$script:HcModelEditorConeDegrees=Normalize-HcModelConeDegrees ([int]`$script:HcModelEditorConeDegrees+5*`$Delta)}"+$nl+"        'Cone softness'{`$script:HcModelEditorConeSoftnessPercent=Normalize-HcModelConeSoftnessPercent ([int]`$script:HcModelEditorConeSoftnessPercent+5*`$Delta)}"+$nl+"        'Light falloff'{`$script:HcModelEditorFalloffPercent=Normalize-HcModelFalloffPercent ([int]`$script:HcModelEditorFalloffPercent+10*`$Delta)}") 'advanced position/cone adjustments'
    $moduleText=Replace-HcOnce $moduleText "        'Light temp'{`$script:HcModelEditorLightTemperature=Normalize-HcModelLightTemperature ([int]`$script:HcModelEditorLightTemperature+500*`$Delta)}" "        'Light temp'{`$script:HcModelEditorLightTemperature=Normalize-HcModelLightTemperature ([int]`$script:HcModelEditorLightTemperature+100*`$Delta)}" 'temperature adjustment precision'
    $moduleText=Replace-HcOnce $moduleText "        'Specular'{`$script:HcModelEditorSpecularPercent=Normalize-HcModelSpecularPercent ([int]`$script:HcModelEditorSpecularPercent+10*`$Delta)}" ("        'Specular'{`$script:HcModelEditorSpecularPercent=Normalize-HcModelSpecularPercent ([int]`$script:HcModelEditorSpecularPercent+10*`$Delta)}"+$nl+"        'Highlight size'{`$script:HcModelEditorHighlightSizePercent=Normalize-HcModelHighlightSizePercent ([int]`$script:HcModelEditorHighlightSizePercent+25*`$Delta)}") 'highlight adjustment'
    Set-Content -LiteralPath $module -Value $moduleText -Encoding UTF8
}

$hostText=Get-Content -Raw -LiteralPath $hostPath -Encoding UTF8
if($hostText -notmatch 'HUYMAIER_V0307_CONSOLE_STUDIO_LIGHT_ADVANCED_NATIVE_BRIDGE_V1'){
    if($hostText -notmatch 'HUYMAIER_V0307_CONSOLE_STUDIO_LIGHT_NATIVE_BRIDGE_V1'){throw 'Advanced studio light requires the base managed native bridge first.'}
    $hostText=$hostText.Replace('    // HUYMAIER_V0307_CONSOLE_STUDIO_LIGHT_NATIVE_BRIDGE_V1','    // HUYMAIER_V0307_CONSOLE_STUDIO_LIGHT_NATIVE_BRIDGE_V1'+$nl+'    // HUYMAIER_V0307_CONSOLE_STUDIO_LIGHT_ADVANCED_NATIVE_BRIDGE_V1')
    $hostText=Replace-HcOnce $hostText 'internal static extern int HC_GPU_SetShelfItemStudioLight(IntPtr handle, int id, float keyLightScale, float azimuth, float elevation, float temperatureKelvin, float ambientScale, float specularScale);' 'internal static extern int HC_GPU_SetShelfItemStudioLight(IntPtr handle, int id, float keyLightScale, float azimuth, float elevation, float distance, float aimX, float aimY, float coneDegrees, float coneSoftness, float falloffScale, float temperatureKelvin, float ambientScale, float specularScale, float highlightScale);' 'advanced host P/Invoke'

    $old='            public float LightAzimuth = -36.0f, LightElevation = 43.0f, LightTemperature = 6500.0f;'+$nl+'            public float AmbientScale = 1.0f, SpecularScale = 1.0f;'
    $new='            public float LightAzimuth = -36.0f, LightElevation = 43.0f, LightTemperature = 6500.0f;'+$nl+'            public float LightDistance = 8.0f, LightAimX = 0.0f, LightAimY = 0.0f;'+$nl+'            public float ConeDegrees = 180.0f, ConeSoftness = 0.5f, FalloffScale = 0.0f;'+$nl+'            public float AmbientScale = 1.0f, SpecularScale = 1.0f, HighlightScale = 1.0f;'
    $hostText=Replace-HcOnce $hostText $old $new 'advanced host state'

    $hostText=Replace-HcOnce $hostText 'state.KeyLightScale, state.LightAzimuth, state.LightElevation, state.LightTemperature, state.AmbientScale, state.SpecularScale)' 'state.KeyLightScale, state.LightAzimuth, state.LightElevation, state.LightDistance, state.LightAimX, state.LightAimY, state.ConeDegrees, state.ConeSoftness, state.FalloffScale, state.LightTemperature, state.AmbientScale, state.SpecularScale, state.HighlightScale)' 'advanced host replay call'

    $hostText=Replace-HcOnce $hostText 'public bool SetItemStudioLight(int id, double keyLightScale, double azimuth, double elevation, double temperatureKelvin, double ambientScale, double specularScale)' 'public bool SetItemStudioLight(int id, double keyLightScale, double azimuth, double elevation, double distance, double aimX, double aimY, double coneDegrees, double coneSoftness, double falloffScale, double temperatureKelvin, double ambientScale, double specularScale, double highlightScale)' 'advanced host method signature'
    $hostText=Replace-HcOnce $hostText 'state.KeyLightScale = Math.Max(0.0f, Math.Min(2.0f, (float)keyLightScale));' 'state.KeyLightScale = Math.Max(0.0f, Math.Min(5.0f, (float)keyLightScale));' 'advanced key clamp'
    $hostText=Replace-HcOnce $hostText 'state.LightElevation = Math.Max(-80.0f, Math.Min(80.0f, (float)elevation));' ('state.LightElevation = Math.Max(-89.0f, Math.Min(89.0f, (float)elevation));'+$nl+'            state.LightDistance = Math.Max(1.0f, Math.Min(20.0f, (float)distance));'+$nl+'            state.LightAimX = Math.Max(-1.0f, Math.Min(1.0f, (float)aimX)); state.LightAimY = Math.Max(-1.0f, Math.Min(1.0f, (float)aimY));'+$nl+'            state.ConeDegrees = Math.Max(5.0f, Math.Min(180.0f, (float)coneDegrees));'+$nl+'            state.ConeSoftness = Math.Max(0.0f, Math.Min(1.0f, (float)coneSoftness));'+$nl+'            state.FalloffScale = Math.Max(0.0f, Math.Min(2.0f, (float)falloffScale));') 'advanced position clamps'
    $hostText=Replace-HcOnce $hostText 'state.LightTemperature = Math.Max(2500.0f, Math.Min(9000.0f, (float)temperatureKelvin));' 'state.LightTemperature = Math.Max(1800.0f, Math.Min(12000.0f, (float)temperatureKelvin));' 'advanced temperature clamp'
    $hostText=Replace-HcOnce $hostText 'state.AmbientScale = Math.Max(0.0f, Math.Min(2.0f, (float)ambientScale));' 'state.AmbientScale = Math.Max(0.0f, Math.Min(3.0f, (float)ambientScale));' 'advanced ambient clamp'
    $hostText=Replace-HcOnce $hostText 'state.SpecularScale = Math.Max(0.0f, Math.Min(2.0f, (float)specularScale));' ('state.SpecularScale = Math.Max(0.0f, Math.Min(4.0f, (float)specularScale));'+$nl+'            state.HighlightScale = Math.Max(0.25f, Math.Min(4.0f, (float)highlightScale));') 'advanced specular/highlight clamp'
    $hostText=Replace-HcOnce $hostText 'nativeHandle, id, state.KeyLightScale, state.LightAzimuth, state.LightElevation, state.LightTemperature, state.AmbientScale, state.SpecularScale)' 'nativeHandle, id, state.KeyLightScale, state.LightAzimuth, state.LightElevation, state.LightDistance, state.LightAimX, state.LightAimY, state.ConeDegrees, state.ConeSoftness, state.FalloffScale, state.LightTemperature, state.AmbientScale, state.SpecularScale, state.HighlightScale)' 'advanced direct native call'
    $hostText=Replace-HcOnce $hostText 'state.LightScale = Math.Max(.20f, Math.Min(2.00f, (float)lightScale));' 'state.LightScale = Math.Max(.20f, Math.Min(4.00f, (float)lightScale));' 'overall light clamp managed'
    Set-Content -LiteralPath $hostPath -Value $hostText -Encoding UTF8
}

$runtimeText=Get-Content -Raw -LiteralPath $runtimePath -Encoding UTF8
if($runtimeText -notmatch 'HUYMAIER_V0307_CONSOLE_STUDIO_LIGHT_ADVANCED_NATIVE_V1'){
    if($runtimeText -notmatch 'HUYMAIER_V0307_CONSOLE_STUDIO_LIGHT_NATIVE_V1'){throw 'Advanced studio light requires base native studio light first.'}
    $runtimeText=$runtimeText.Replace('    // HUYMAIER_V0307_CONSOLE_STUDIO_LIGHT_NATIVE_V1','    // HUYMAIER_V0307_CONSOLE_STUDIO_LIGHT_NATIVE_V1'+$nl+'    // HUYMAIER_V0307_CONSOLE_STUDIO_LIGHT_ADVANCED_NATIVE_V1')
    $old='        float lightAzimuth = -36.0f, lightElevation = 43.0f, lightTemperature = 6500.0f;'+$nl+'        float ambientScale = 1.0f, specularScale = 1.0f;'
    $new='        float lightAzimuth = -36.0f, lightElevation = 43.0f, lightTemperature = 6500.0f;'+$nl+'        float lightDistance = 8.0f, lightAimX = 0.0f, lightAimY = 0.0f;'+$nl+'        float coneDegrees = 180.0f, coneSoftness = 0.5f, falloffScale = 0.0f;'+$nl+'        float ambientScale = 1.0f, specularScale = 1.0f, highlightScale = 1.0f;'
    $runtimeText=Replace-HcOnce $runtimeText $old $new 'advanced runtime state'
    $runtimeText=Replace-HcOnce $runtimeText '        XMFLOAT4 extra;'+$nl+'    };' ('        XMFLOAT4 extra;'+$nl+'        XMFLOAT4 extra2;'+$nl+'    };') 'advanced constants layout'

    $old='        StudioConstants studio{};if(item.studioLightOverride){const float az=XMConvertToRadians(item.lightAzimuth),el=XMConvertToRadians(item.lightElevation),ce=std::cos(el);studio.directionIntensity=XMFLOAT4(std::sin(az)*ce,std::sin(el),-std::cos(az)*ce,item.keyLightScale);const XMFLOAT3 lc=HcTemperatureToLinearRgb(item.lightTemperature);studio.colorAmbient=XMFLOAT4(lc.x,lc.y,lc.z,item.ambientScale);studio.extra=XMFLOAT4(item.specularScale,0,0,1);}else{studio.directionIntensity=XMFLOAT4(-0.45f,0.72f,-0.62f,1.0f);studio.colorAmbient=XMFLOAT4(1,1,1,1);studio.extra=XMFLOAT4(1,0,0,0);}D3D11_MAPPED_SUBRESOURCE studioMapped{};if(SUCCEEDED(g_core.context->Map(g_core.studioConstants.Get(),0,D3D11_MAP_WRITE_DISCARD,0,&studioMapped))){memcpy(studioMapped.pData,&studio,sizeof(studio));g_core.context->Unmap(g_core.studioConstants.Get(),0);}'
    $new='        StudioConstants studio{};if(item.studioLightOverride){const float az=XMConvertToRadians(item.lightAzimuth),el=XMConvertToRadians(item.lightElevation),ce=std::cos(el);const float targetX=item.offsetX*.012f+item.lightAimX,targetY=-item.offsetY*.012f+item.lightAimY;const float lx=targetX+std::sin(az)*ce*item.lightDistance,ly=targetY+std::sin(el)*item.lightDistance,lz=-std::cos(az)*ce*item.lightDistance;studio.directionIntensity=XMFLOAT4(lx,ly,lz,item.keyLightScale);const XMFLOAT3 lc=HcTemperatureToLinearRgb(item.lightTemperature);studio.colorAmbient=XMFLOAT4(lc.x,lc.y,lc.z,item.ambientScale);studio.extra=XMFLOAT4(item.specularScale,item.coneDegrees,item.coneSoftness,1);studio.extra2=XMFLOAT4(item.falloffScale,item.highlightScale,targetX,targetY);}else{studio.directionIntensity=XMFLOAT4(-0.45f,0.72f,-0.62f,1.0f);studio.colorAmbient=XMFLOAT4(1,1,1,1);studio.extra=XMFLOAT4(1,180,0,0);studio.extra2=XMFLOAT4(0,1,0,0);}D3D11_MAPPED_SUBRESOURCE studioMapped{};if(SUCCEEDED(g_core.context->Map(g_core.studioConstants.Get(),0,D3D11_MAP_WRITE_DISCARD,0,&studioMapped))){memcpy(studioMapped.pData,&studio,sizeof(studio));g_core.context->Unmap(g_core.studioConstants.Get(),0);}'
    $runtimeText=Replace-HcOnce $runtimeText $old $new 'advanced per-item constants'

    $old='extern "C" __declspec(dllexport) int __cdecl HC_GPU_SetShelfItemStudioLight(void* handle,int id,float keyLightScale,float azimuth,float elevation,float temperatureKelvin,float ambientScale,float specularScale){if(!handle)return 0;std::lock_guard<std::mutex>guard(g_core.lock);ShelfSurface*s=static_cast<ShelfSurface*>(handle);auto it=s->items.find(id);if(it==s->items.end())return 0;Item&i=it->second;i.keyLightScale=std::max(0.0f,std::min(2.0f,keyLightScale));i.lightAzimuth=azimuth;i.lightElevation=std::max(-80.0f,std::min(80.0f,elevation));i.lightTemperature=std::max(2500.0f,std::min(9000.0f,temperatureKelvin));i.ambientScale=std::max(0.0f,std::min(2.0f,ambientScale));i.specularScale=std::max(0.0f,std::min(2.0f,specularScale));i.studioLightOverride=true;return 1;}'
    $new='extern "C" __declspec(dllexport) int __cdecl HC_GPU_SetShelfItemStudioLight(void* handle,int id,float keyLightScale,float azimuth,float elevation,float distance,float aimX,float aimY,float coneDegrees,float coneSoftness,float falloffScale,float temperatureKelvin,float ambientScale,float specularScale,float highlightScale){if(!handle)return 0;std::lock_guard<std::mutex>guard(g_core.lock);ShelfSurface*s=static_cast<ShelfSurface*>(handle);auto it=s->items.find(id);if(it==s->items.end())return 0;Item&i=it->second;i.keyLightScale=std::max(0.0f,std::min(5.0f,keyLightScale));i.lightAzimuth=azimuth;i.lightElevation=std::max(-89.0f,std::min(89.0f,elevation));i.lightDistance=std::max(1.0f,std::min(20.0f,distance));i.lightAimX=std::max(-1.0f,std::min(1.0f,aimX));i.lightAimY=std::max(-1.0f,std::min(1.0f,aimY));i.coneDegrees=std::max(5.0f,std::min(180.0f,coneDegrees));i.coneSoftness=std::max(0.0f,std::min(1.0f,coneSoftness));i.falloffScale=std::max(0.0f,std::min(2.0f,falloffScale));i.lightTemperature=std::max(1800.0f,std::min(12000.0f,temperatureKelvin));i.ambientScale=std::max(0.0f,std::min(3.0f,ambientScale));i.specularScale=std::max(0.0f,std::min(4.0f,specularScale));i.highlightScale=std::max(0.25f,std::min(4.0f,highlightScale));i.studioLightOverride=true;return 1;}'
    $runtimeText=Replace-HcOnce $runtimeText $old $new 'advanced native export'
    $runtimeText=Replace-HcOnce $runtimeText 'i.lightScale=std::max(0.20f,std::min(2.00f,lightScale))' 'i.lightScale=std::max(0.20f,std::min(4.00f,lightScale))' 'overall light clamp native'
    Set-Content -LiteralPath $runtimePath -Value $runtimeText -Encoding UTF8
}

$assetText=Get-Content -Raw -LiteralPath $assetPath -Encoding UTF8
if($assetText -notmatch 'HUYMAIER_V0307_CONSOLE_STUDIO_LIGHT_ADVANCED_SHADER_V1'){
    if($assetText -notmatch 'HUYMAIER_V0307_CONSOLE_STUDIO_LIGHT_SHADER_V1'){throw 'Advanced studio light requires base shader transform first.'}
    $assetText=$assetText.Replace('    // HUYMAIER_V0307_CONSOLE_STUDIO_LIGHT_SHADER_V1','    // HUYMAIER_V0307_CONSOLE_STUDIO_LIGHT_SHADER_V1'+$nl+'    // HUYMAIER_V0307_CONSOLE_STUDIO_LIGHT_ADVANCED_SHADER_V1')
    $assetText=Replace-HcOnce $assetText '        float4 StudioLightExtra;'+$nl+'    };' ('        float4 StudioLightExtra;'+$nl+'        float4 StudioLightExtra2;'+$nl+'    };') 'advanced shader constants'

    $old=@'
            float3 v=normalize(float3(0.0,0.08,-4.2)-i.wp);
            bool customStudioLight=StudioLightExtra.w>0.5;
            float3 l0=customStudioLight?normalize(StudioLightDirectionIntensity.xyz):normalize(float3(-0.45,0.72,-0.62));
            float3 l1=normalize(float3(0.75,0.25,-0.55));
            float keyIntensity=customStudioLight?max(0.0,StudioLightDirectionIntensity.w):1.0;
            float3 keyColor=customStudioLight?max(StudioLightColorAmbient.rgb,0.0):float3(1,1,1);
            float ambientScale=customStudioLight?max(0.0,StudioLightColorAmbient.w):1.0;
            float specularScale=customStudioLight?max(0.0,StudioLightExtra.x):1.0;
            float d0=saturate(dot(n,l0));
            float d1=saturate(dot(n,l1));
            float3 h0=normalize(l0+v);
            float3 h1=normalize(l1+v);

            float3 diffuseLight=0.42*ambientScale.xxx+d0*0.30*keyIntensity*keyColor+d1*0.12;
            float bodyRetention=lerp(1.0,0.78,metallic);
            float3 body=baseRgb*diffuseLight*bodyRetention;

            float specularFactor=saturate(Surface.z);
            float3 dielectricF0=float3(0.04,0.04,0.04)*specularFactor;
            float3 f0=lerp(dielectricF0,baseRgb*specularFactor,metallic);
            float specPower=lerp(10.0,72.0,1.0-roughness);
            float directSpec0=pow(saturate(dot(n,h0)),specPower)*d0;
            float directSpec1=pow(saturate(dot(n,h1)),specPower)*d1;
            float3 directSpec=f0*(directSpec0*0.18*keyIntensity*keyColor+directSpec1*0.07)*specularScale;

            float environmentStrength=0.055+(1.0-roughness)*0.085+saturate(Surface.w)*0.025;
            float3 environmentSpec=f0*environmentStrength*specularScale;
            float3 metallicFill=baseRgb*metallic*(0.12*ambientScale+d0*0.08*keyIntensity);
            lit=(body+directSpec+environmentSpec+metallicFill)*occlusion;
'@.TrimEnd()
    $new=@'
            float3 v=normalize(float3(0.0,0.08,-4.2)-i.wp);
            bool customStudioLight=StudioLightExtra.w>0.5;
            if(!customStudioLight)
            {
                float3 l0=normalize(float3(-0.45,0.72,-0.62));
                float3 l1=normalize(float3(0.75,0.25,-0.55));
                float d0=saturate(dot(n,l0));
                float d1=saturate(dot(n,l1));
                float3 h0=normalize(l0+v);
                float3 h1=normalize(l1+v);
                float diffuseLight=0.42+d0*0.30+d1*0.12;
                float bodyRetention=lerp(1.0,0.78,metallic);
                float3 body=baseRgb*diffuseLight*bodyRetention;
                float specularFactor=saturate(Surface.z);
                float3 dielectricF0=float3(0.04,0.04,0.04)*specularFactor;
                float3 f0=lerp(dielectricF0,baseRgb*specularFactor,metallic);
                float specPower=lerp(10.0,72.0,1.0-roughness);
                float directSpec0=pow(saturate(dot(n,h0)),specPower)*d0;
                float directSpec1=pow(saturate(dot(n,h1)),specPower)*d1;
                float3 directSpec=f0*(directSpec0*0.18+directSpec1*0.07);
                float environmentStrength=0.055+(1.0-roughness)*0.085+saturate(Surface.w)*0.025;
                float3 environmentSpec=f0*environmentStrength;
                float3 metallicFill=baseRgb*metallic*(0.12+d0*0.08);
                lit=(body+directSpec+environmentSpec+metallicFill)*occlusion;
            }
            else
            {
                float3 lightPos=StudioLightDirectionIntensity.xyz;
                float3 toLight=lightPos-i.wp;
                float lightDistance=max(length(toLight),0.001);
                float3 l0=toLight/lightDistance;
                float3 target=float3(StudioLightExtra2.z,StudioLightExtra2.w,0.0);
                float3 spotAxis=normalize(target-lightPos);
                float3 fromLight=-l0;
                float coneDegrees=clamp(StudioLightExtra.y,5.0,180.0);
                float coneWeight=1.0;
                if(coneDegrees<179.5)
                {
                    float outerHalf=radians(coneDegrees*0.5);
                    float softness=saturate(StudioLightExtra.z);
                    float innerHalf=outerHalf*(1.0-softness*0.90);
                    float outerCos=cos(outerHalf);
                    float innerCos=cos(innerHalf);
                    float coneDot=dot(fromLight,spotAxis);
                    coneWeight=(softness<0.001)?step(outerCos,coneDot):smoothstep(outerCos,max(innerCos,outerCos+0.0001),coneDot);
                }
                float falloff=max(0.0,StudioLightExtra2.x);
                float distanceWeight=1.0/(1.0+falloff*lightDistance*lightDistance*0.06);
                float keyWeight=max(0.0,StudioLightDirectionIntensity.w)*coneWeight*distanceWeight;
                float3 keyColor=max(StudioLightColorAmbient.rgb,0.0);
                float ambientScale=max(0.0,StudioLightColorAmbient.w);
                float specularScale=max(0.0,StudioLightExtra.x);
                float highlightScale=max(0.25,StudioLightExtra2.y);
                float d0=saturate(dot(n,l0));
                float3 h0=normalize(l0+v);
                float3 diffuseLight=float3(0.42,0.42,0.42)*ambientScale+d0*0.30*keyWeight*keyColor;
                float bodyRetention=lerp(1.0,0.78,metallic);
                float3 body=baseRgb*diffuseLight*bodyRetention;
                float specularFactor=saturate(Surface.z);
                float3 dielectricF0=float3(0.04,0.04,0.04)*specularFactor;
                float3 f0=lerp(dielectricF0,baseRgb*specularFactor,metallic);
                float specPower=max(2.0,lerp(10.0,72.0,1.0-roughness)/highlightScale);
                float directSpec0=pow(saturate(dot(n,h0)),specPower)*d0;
                float3 directSpec=f0*(directSpec0*0.18*keyWeight*keyColor)*specularScale;
                float environmentStrength=0.055+(1.0-roughness)*0.085+saturate(Surface.w)*0.025;
                float3 environmentSpec=f0*environmentStrength*specularScale*ambientScale;
                float3 metallicFill=baseRgb*metallic*(0.12*ambientScale+d0*0.08*keyWeight);
                lit=(body+directSpec+environmentSpec+metallicFill)*occlusion;
            }
'@.TrimEnd()
    $assetText=Replace-HcOnce $assetText $old $new 'advanced spotlight shader'
    Set-Content -LiteralPath $assetPath -Value $assetText -Encoding UTF8
}

Write-Host 'Applied advanced console-only studio spotlight controls: 400% overall lighting, 500% key brightness, precise position, distance, aim, cone size/softness, falloff, 1800-12000K temperature, ambient, specular and highlight size. Providers remain on the exact legacy light path; no shadow pass added.'
