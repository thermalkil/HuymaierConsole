param()
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$module=Join-Path $root 'HuymaierConsoleModelPresentation.ps1'
$hostPath=Join-Path $root 'Native\HuymaierD3D11ShelfHost.cs'
$runtimePath=Join-Path $root 'Native\HuymaierD3D11ShelfRuntime.cpp'
$assetPath=Join-Path $root 'Native\HuymaierD3D11ShelfAsset.h'
foreach($p in @($module,$hostPath,$runtimePath,$assetPath)){if(-not(Test-Path -LiteralPath $p -PathType Leaf)){throw "v0.30.7 studio-light source missing: $p"}}
$nl=[Environment]::NewLine
function Replace-HcOnce([string]$Text,[string]$Old,[string]$New,[string]$Label){
    $count=([regex]::Matches($Text,[regex]::Escape($Old))).Count
    if($count-ne1){throw "v0.30.7 expected exactly one $Label anchor, found $count."}
    return $Text.Replace($Old,$New)
}

# HUYMAIER_V0307_CONSOLE_STUDIO_LIGHT_TRANSFORM_V1
$moduleText=Get-Content -Raw -LiteralPath $module -Encoding UTF8
if($moduleText -notmatch 'HUYMAIER_V0307_CONSOLE_STUDIO_LIGHT_V1'){
    $moduleText=Replace-HcOnce $moduleText '# HUYMAIER_V0306_CONSOLE_MODEL_PRESENTATION_EDITOR_V1' ('# HUYMAIER_V0306_CONSOLE_MODEL_PRESENTATION_EDITOR_V1'+$nl+'# HUYMAIER_V0307_CONSOLE_STUDIO_LIGHT_V1') 'module marker'

    $old=@'
$script:HcModelEditorFields=@('Yaw','Pitch','Roll','Scale','Position X','Position Y','Mirror X','Mirror Y','Mirror Z','Faces','Lighting','Fan motion')
'@.Trim()
    $new=@'
$script:HcModelEditorFields=@('Yaw','Pitch','Roll','Scale','Position X','Position Y','Mirror X','Mirror Y','Mirror Z','Faces','Lighting','Key light','Light azimuth','Light elevation','Light temp','Ambient','Specular','Fan motion')
'@.Trim()
    $moduleText=Replace-HcOnce $moduleText $old $new 'editor fields'

    $old=@'
$script:HcModelEditorLightPercent=100
$script:HcModelEditorFanPercent=100
'@.Trim()
    $new=@'
$script:HcModelEditorLightPercent=100
$script:HcModelEditorKeyLightPercent=100
$script:HcModelEditorLightAzimuth=-36
$script:HcModelEditorLightElevation=43
$script:HcModelEditorLightTemperature=6500
$script:HcModelEditorAmbientPercent=100
$script:HcModelEditorSpecularPercent=100
$script:HcModelEditorFanPercent=100
'@.Trim()
    $moduleText=Replace-HcOnce $moduleText $old $new 'editor state'

    $old=@'
function Normalize-HcModelLightPercent {param([double]$Value);return [int]([math]::Round([math]::Max(20.0,[math]::Min(200.0,$Value))/10.0)*10.0)}
'@.Trim()
    $new=@'
function Normalize-HcModelLightPercent {param([double]$Value);return [int]([math]::Round([math]::Max(20.0,[math]::Min(200.0,$Value))/10.0)*10.0)}
function Normalize-HcModelKeyLightPercent {param([double]$Value);return [int]([math]::Round([math]::Max(0.0,[math]::Min(200.0,$Value))/10.0)*10.0)}
function Normalize-HcModelLightAzimuth {param([double]$Value);while($Value-gt180.0){$Value-=360.0};while($Value-le-180.0){$Value+=360.0};return [int]([math]::Round($Value/5.0)*5.0)}
function Normalize-HcModelLightElevation {param([double]$Value);return [int]([math]::Round([math]::Max(-80.0,[math]::Min(80.0,$Value))/5.0)*5.0)}
function Normalize-HcModelLightTemperature {param([double]$Value);return [int]([math]::Round([math]::Max(2500.0,[math]::Min(9000.0,$Value))/500.0)*500.0)}
function Normalize-HcModelAmbientPercent {param([double]$Value);return [int]([math]::Round([math]::Max(0.0,[math]::Min(200.0,$Value))/10.0)*10.0)}
function Normalize-HcModelSpecularPercent {param([double]$Value);return [int]([math]::Round([math]::Max(0.0,[math]::Min(200.0,$Value))/10.0)*10.0)}
'@.Trim()
    $moduleText=Replace-HcOnce $moduleText $old $new 'normalizers'

    $old=@'
$yaw=0.0;$pitch=-10.0;$roll=0.0;$scalePercent=100;$offsetX=0;$offsetY=0;$mirrorX=$false;$mirrorY=$false;$mirrorZ=$false;$faceMode='Normal';$light=100;$fan=100
'@.Trim()
    $new=@'
$yaw=0.0;$pitch=-10.0;$roll=0.0;$scalePercent=100;$offsetX=0;$offsetY=0;$mirrorX=$false;$mirrorY=$false;$mirrorZ=$false;$faceMode='Normal';$light=100;$keyLight=100;$lightAzimuth=-36;$lightElevation=43;$lightTemperature=6500;$ambient=100;$specular=100;$fan=100
'@.Trim()
    $moduleText=Replace-HcOnce $moduleText $old $new 'view defaults'

    $old=@'
            try{$light=Normalize-HcModelLightPercent ([double](Get-EntryProperty $entry 'LightPercent' 100))}catch{}
            try{$fan=Normalize-HcModelFanPercent ([double](Get-EntryProperty $entry 'FanPercent' 100))}catch{}
'@.TrimEnd()
    $new=@'
            try{$light=Normalize-HcModelLightPercent ([double](Get-EntryProperty $entry 'LightPercent' 100))}catch{}
            try{$keyLight=Normalize-HcModelKeyLightPercent ([double](Get-EntryProperty $entry 'KeyLightPercent' 100))}catch{}
            try{$lightAzimuth=Normalize-HcModelLightAzimuth ([double](Get-EntryProperty $entry 'LightAzimuth' -36))}catch{}
            try{$lightElevation=Normalize-HcModelLightElevation ([double](Get-EntryProperty $entry 'LightElevation' 43))}catch{}
            try{$lightTemperature=Normalize-HcModelLightTemperature ([double](Get-EntryProperty $entry 'LightTemperature' 6500))}catch{}
            try{$ambient=Normalize-HcModelAmbientPercent ([double](Get-EntryProperty $entry 'AmbientPercent' 100))}catch{}
            try{$specular=Normalize-HcModelSpecularPercent ([double](Get-EntryProperty $entry 'SpecularPercent' 100))}catch{}
            try{$fan=Normalize-HcModelFanPercent ([double](Get-EntryProperty $entry 'FanPercent' 100))}catch{}
'@.TrimEnd()
    $moduleText=Replace-HcOnce $moduleText $old $new 'config reads'

    $old=@'
if(-not(Test-HcConsoleModelPresentationEditable $Platform)){$scalePercent=100;$roll=0;$offsetX=0;$offsetY=0;$mirrorX=$false;$mirrorY=$false;$mirrorZ=$false;$faceMode='Normal';$light=100;$fan=100}
'@.Trim()
    $new=@'
if(-not(Test-HcConsoleModelPresentationEditable $Platform)){$scalePercent=100;$roll=0;$offsetX=0;$offsetY=0;$mirrorX=$false;$mirrorY=$false;$mirrorZ=$false;$faceMode='Normal';$light=100;$keyLight=100;$lightAzimuth=-36;$lightElevation=43;$lightTemperature=6500;$ambient=100;$specular=100;$fan=100}
'@.Trim()
    $moduleText=Replace-HcOnce $moduleText $old $new 'provider neutralization'

    $old=@'
return [pscustomobject]@{Key=$key;Yaw=[double]$yaw;Pitch=[double]$pitch;Roll=[double]$roll;ScalePercent=[int]$scalePercent;OffsetX=[int]$offsetX;OffsetY=[int]$offsetY;MirrorX=[bool]$mirrorX;MirrorY=[bool]$mirrorY;MirrorZ=[bool]$mirrorZ;FaceMode=$faceMode;LightPercent=[int]$light;FanPercent=[int]$fan}
'@.Trim()
    $new=@'
return [pscustomobject]@{Key=$key;Yaw=[double]$yaw;Pitch=[double]$pitch;Roll=[double]$roll;ScalePercent=[int]$scalePercent;OffsetX=[int]$offsetX;OffsetY=[int]$offsetY;MirrorX=[bool]$mirrorX;MirrorY=[bool]$mirrorY;MirrorZ=[bool]$mirrorZ;FaceMode=$faceMode;LightPercent=[int]$light;KeyLightPercent=[int]$keyLight;LightAzimuth=[int]$lightAzimuth;LightElevation=[int]$lightElevation;LightTemperature=[int]$lightTemperature;AmbientPercent=[int]$ambient;SpecularPercent=[int]$specular;FanPercent=[int]$fan}
'@.Trim()
    $moduleText=Replace-HcOnce $moduleText $old $new 'view object'

    $old=@'
param([string]$ModelPath,[string]$Platform,[double]$Yaw,[double]$Pitch,[int]$ScalePercent=100,[double]$Roll=0,[int]$OffsetX=0,[int]$OffsetY=0,[bool]$MirrorX=$false,[bool]$MirrorY=$false,[bool]$MirrorZ=$false,[string]$FaceMode='Normal',[int]$LightPercent=100,[int]$FanPercent=100)
'@.Trim()
    $new=@'
param([string]$ModelPath,[string]$Platform,[double]$Yaw,[double]$Pitch,[int]$ScalePercent=100,[double]$Roll=0,[int]$OffsetX=0,[int]$OffsetY=0,[bool]$MirrorX=$false,[bool]$MirrorY=$false,[bool]$MirrorZ=$false,[string]$FaceMode='Normal',[int]$LightPercent=100,[int]$KeyLightPercent=100,[int]$LightAzimuth=-36,[int]$LightElevation=43,[int]$LightTemperature=6500,[int]$AmbientPercent=100,[int]$SpecularPercent=100,[int]$FanPercent=100)
'@.Trim()
    $moduleText=Replace-HcOnce $moduleText $old $new 'Set-HcModelDefaultView parameters'

    $old=@'
        LightPercent=(Normalize-HcModelLightPercent $LightPercent);FanPercent=(Normalize-HcModelFanPercent $FanPercent);UpdatedUtc=[DateTime]::UtcNow.ToString('o')
'@.Trim()
    $new=@'
        LightPercent=(Normalize-HcModelLightPercent $LightPercent);KeyLightPercent=(Normalize-HcModelKeyLightPercent $KeyLightPercent);LightAzimuth=(Normalize-HcModelLightAzimuth $LightAzimuth);LightElevation=(Normalize-HcModelLightElevation $LightElevation);LightTemperature=(Normalize-HcModelLightTemperature $LightTemperature)
        AmbientPercent=(Normalize-HcModelAmbientPercent $AmbientPercent);SpecularPercent=(Normalize-HcModelSpecularPercent $SpecularPercent);FanPercent=(Normalize-HcModelFanPercent $FanPercent);UpdatedUtc=[DateTime]::UtcNow.ToString('o')
'@.Trim()
    $moduleText=Replace-HcOnce $moduleText $old $new 'config persistence'

    $old=@'
$script:HcModelEditorFaceMode=[string]$View.FaceMode;$script:HcModelEditorLightPercent=[int]$View.LightPercent;$script:HcModelEditorFanPercent=[int]$View.FanPercent
'@.Trim()
    $new=@'
$script:HcModelEditorFaceMode=[string]$View.FaceMode;$script:HcModelEditorLightPercent=[int]$View.LightPercent;$script:HcModelEditorKeyLightPercent=[int]$View.KeyLightPercent;$script:HcModelEditorLightAzimuth=[int]$View.LightAzimuth;$script:HcModelEditorLightElevation=[int]$View.LightElevation;$script:HcModelEditorLightTemperature=[int]$View.LightTemperature;$script:HcModelEditorAmbientPercent=[int]$View.AmbientPercent;$script:HcModelEditorSpecularPercent=[int]$View.SpecularPercent;$script:HcModelEditorFanPercent=[int]$View.FanPercent
'@.Trim()
    $moduleText=Replace-HcOnce $moduleText $old $new 'editor state from view'

    $old=@'
[pscustomobject]@{Yaw=[double]$script:HcModelViewerYaw;Pitch=[double]$script:HcModelViewerPitch;Roll=[double]$script:HcModelEditorRoll;ScalePercent=[int]$script:HcModelEditorScalePercent;OffsetX=[int]$script:HcModelEditorOffsetX;OffsetY=[int]$script:HcModelEditorOffsetY;MirrorX=[bool]$script:HcModelEditorMirrorX;MirrorY=[bool]$script:HcModelEditorMirrorY;MirrorZ=[bool]$script:HcModelEditorMirrorZ;FaceMode=[string]$script:HcModelEditorFaceMode;LightPercent=[int]$script:HcModelEditorLightPercent;FanPercent=[int]$script:HcModelEditorFanPercent}
'@.Trim()
    $new=@'
[pscustomobject]@{Yaw=[double]$script:HcModelViewerYaw;Pitch=[double]$script:HcModelViewerPitch;Roll=[double]$script:HcModelEditorRoll;ScalePercent=[int]$script:HcModelEditorScalePercent;OffsetX=[int]$script:HcModelEditorOffsetX;OffsetY=[int]$script:HcModelEditorOffsetY;MirrorX=[bool]$script:HcModelEditorMirrorX;MirrorY=[bool]$script:HcModelEditorMirrorY;MirrorZ=[bool]$script:HcModelEditorMirrorZ;FaceMode=[string]$script:HcModelEditorFaceMode;LightPercent=[int]$script:HcModelEditorLightPercent;KeyLightPercent=[int]$script:HcModelEditorKeyLightPercent;LightAzimuth=[int]$script:HcModelEditorLightAzimuth;LightElevation=[int]$script:HcModelEditorLightElevation;LightTemperature=[int]$script:HcModelEditorLightTemperature;AmbientPercent=[int]$script:HcModelEditorAmbientPercent;SpecularPercent=[int]$script:HcModelEditorSpecularPercent;FanPercent=[int]$script:HcModelEditorFanPercent}
'@.Trim()
    $moduleText=Replace-HcOnce $moduleText $old $new 'current view'

    $old=@'
            [void]$Surface.SetItemPresentation($Id,[double]$View.Yaw,[double]$View.Pitch,[double]$View.Roll,[double]$View.OffsetX,[double]$View.OffsetY,[bool]$View.MirrorX,[bool]$View.MirrorY,[bool]$View.MirrorZ,$face,$light,$fan,$Spin)
'@.Trim()
    $new=@'
            [void]$Surface.SetItemPresentation($Id,[double]$View.Yaw,[double]$View.Pitch,[double]$View.Roll,[double]$View.OffsetX,[double]$View.OffsetY,[bool]$View.MirrorX,[bool]$View.MirrorY,[bool]$View.MirrorZ,$face,$light,$fan,$Spin)
            if($Surface.PSObject.Methods['SetItemStudioLight']){[void]$Surface.SetItemStudioLight($Id,[double]$View.KeyLightPercent/100.0,[double]$View.LightAzimuth,[double]$View.LightElevation,[double]$View.LightTemperature,[double]$View.AmbientPercent/100.0,[double]$View.SpecularPercent/100.0)}
'@.Trim()
    $moduleText=Replace-HcOnce $moduleText $old $new 'surface studio light call'

    $old=@'
        'Lighting'{return ([int]$script:HcModelEditorLightPercent).ToString()+'%'}
        'Fan motion'{return ([int]$script:HcModelEditorFanPercent).ToString()+'%'}
'@.TrimEnd()
    $new=@'
        'Lighting'{return ([int]$script:HcModelEditorLightPercent).ToString()+'%'}
        'Key light'{return ([int]$script:HcModelEditorKeyLightPercent).ToString()+'%'}
        'Light azimuth'{return ([int]$script:HcModelEditorLightAzimuth).ToString()+'°'}
        'Light elevation'{return ([int]$script:HcModelEditorLightElevation).ToString()+'°'}
        'Light temp'{return ([int]$script:HcModelEditorLightTemperature).ToString()+'K'}
        'Ambient'{return ([int]$script:HcModelEditorAmbientPercent).ToString()+'%'}
        'Specular'{return ([int]$script:HcModelEditorSpecularPercent).ToString()+'%'}
        'Fan motion'{return ([int]$script:HcModelEditorFanPercent).ToString()+'%'}
'@.TrimEnd()
    $moduleText=Replace-HcOnce $moduleText $old $new 'editor value text'

    $moduleText=Replace-HcOnce $moduleText '-FaceMode $v.FaceMode -LightPercent $v.LightPercent -FanPercent $v.FanPercent)' '-FaceMode $v.FaceMode -LightPercent $v.LightPercent -KeyLightPercent $v.KeyLightPercent -LightAzimuth $v.LightAzimuth -LightElevation $v.LightElevation -LightTemperature $v.LightTemperature -AmbientPercent $v.AmbientPercent -SpecularPercent $v.SpecularPercent -FanPercent $v.FanPercent)' 'save arguments'

    $old=@'
        'Lighting'{$script:HcModelEditorLightPercent=Normalize-HcModelLightPercent ([int]$script:HcModelEditorLightPercent+10*$Delta)}
        'Fan motion'{$script:HcModelEditorFanPercent=Normalize-HcModelFanPercent ([int]$script:HcModelEditorFanPercent+10*$Delta)}
'@.TrimEnd()
    $new=@'
        'Lighting'{$script:HcModelEditorLightPercent=Normalize-HcModelLightPercent ([int]$script:HcModelEditorLightPercent+10*$Delta)}
        'Key light'{$script:HcModelEditorKeyLightPercent=Normalize-HcModelKeyLightPercent ([int]$script:HcModelEditorKeyLightPercent+10*$Delta)}
        'Light azimuth'{$script:HcModelEditorLightAzimuth=Normalize-HcModelLightAzimuth ([int]$script:HcModelEditorLightAzimuth+5*$Delta)}
        'Light elevation'{$script:HcModelEditorLightElevation=Normalize-HcModelLightElevation ([int]$script:HcModelEditorLightElevation+5*$Delta)}
        'Light temp'{$script:HcModelEditorLightTemperature=Normalize-HcModelLightTemperature ([int]$script:HcModelEditorLightTemperature+500*$Delta)}
        'Ambient'{$script:HcModelEditorAmbientPercent=Normalize-HcModelAmbientPercent ([int]$script:HcModelEditorAmbientPercent+10*$Delta)}
        'Specular'{$script:HcModelEditorSpecularPercent=Normalize-HcModelSpecularPercent ([int]$script:HcModelEditorSpecularPercent+10*$Delta)}
        'Fan motion'{$script:HcModelEditorFanPercent=Normalize-HcModelFanPercent ([int]$script:HcModelEditorFanPercent+10*$Delta)}
'@.TrimEnd()
    $moduleText=Replace-HcOnce $moduleText $old $new 'editor adjustments'
    Set-Content -LiteralPath $module -Value $moduleText -Encoding UTF8
}

$hostText=Get-Content -Raw -LiteralPath $hostPath -Encoding UTF8
if($hostText -notmatch 'HUYMAIER_V0307_CONSOLE_STUDIO_LIGHT_NATIVE_BRIDGE_V1'){
    if($hostText -notmatch 'HUYMAIER_V0306_CONSOLE_PRESENTATION_NATIVE_BRIDGE_V1'){throw 'v0.30.7 requires v0.30.6 host presentation transform first.'}
    $hostText=$hostText.Replace('    // HUYMAIER_V0306_CONSOLE_PRESENTATION_NATIVE_BRIDGE_V1','    // HUYMAIER_V0306_CONSOLE_PRESENTATION_NATIVE_BRIDGE_V1'+$nl+'    // HUYMAIER_V0307_CONSOLE_STUDIO_LIGHT_NATIVE_BRIDGE_V1')
    $old=@'
        internal static extern int HC_GPU_SetShelfItemPresentation(IntPtr handle, int id, float yawOffset, float pitch, float roll, float offsetX, float offsetY, int mirrorX, int mirrorY, int mirrorZ, int faceMode, float lightScale, float fanScale, int spin);
'@.Trim()
    $new=$old+$nl+$nl+'        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]'+$nl+'        internal static extern int HC_GPU_SetShelfItemStudioLight(IntPtr handle, int id, float keyLightScale, float azimuth, float elevation, float temperatureKelvin, float ambientScale, float specularScale);'
    $hostText=Replace-HcOnce $hostText $old $new 'host P/Invoke'

    $old=@'
            public float LightScale = 1.0f;
            public float FanScale = 1.0f;
'@.TrimEnd()
    $new=@'
            public float LightScale = 1.0f;
            public float KeyLightScale = 1.0f;
            public float LightAzimuth = -36.0f, LightElevation = 43.0f, LightTemperature = 6500.0f;
            public float AmbientScale = 1.0f, SpecularScale = 1.0f;
            public bool StudioLightOverride = false;
            public float FanScale = 1.0f;
'@.TrimEnd()
    $hostText=Replace-HcOnce $hostText $old $new 'host item lighting state'

    $old=@'
                bool viewOk = D3D11ShelfNative.HC_GPU_SetShelfItemPresentation(nativeHandle, id, state.YawOffset, state.Pitch, state.Roll, state.OffsetX, state.OffsetY, state.MirrorX ? 1 : 0, state.MirrorY ? 1 : 0, state.MirrorZ ? 1 : 0, state.FaceMode, state.LightScale, state.FanScale, state.Spin ? 1 : 0) != 0;
                return layoutOk && viewOk;
'@.TrimEnd()
    $new=@'
                bool viewOk = D3D11ShelfNative.HC_GPU_SetShelfItemPresentation(nativeHandle, id, state.YawOffset, state.Pitch, state.Roll, state.OffsetX, state.OffsetY, state.MirrorX ? 1 : 0, state.MirrorY ? 1 : 0, state.MirrorZ ? 1 : 0, state.FaceMode, state.LightScale, state.FanScale, state.Spin ? 1 : 0) != 0;
                bool studioOk = !state.StudioLightOverride || D3D11ShelfNative.HC_GPU_SetShelfItemStudioLight(nativeHandle, id, state.KeyLightScale, state.LightAzimuth, state.LightElevation, state.LightTemperature, state.AmbientScale, state.SpecularScale) != 0;
                return layoutOk && viewOk && studioOk;
'@.TrimEnd()
    $hostText=Replace-HcOnce $hostText $old $new 'host replay'

    $anchor='        public void ClearModels()'+$nl+'        {'
    if(-not$hostText.Contains($anchor)){throw 'v0.30.7 host public method anchor missing.'}
    $method=@'
        public bool SetItemStudioLight(int id, double keyLightScale, double azimuth, double elevation, double temperatureKelvin, double ambientScale, double specularScale)
        {
            if (disposed || id < 0) return false;
            ItemState state;
            if (!itemStates.TryGetValue(id, out state) || state == null)
                state = new ItemState { Width = 1.0f, Height = 1.0f, Scale = .82f, Visible = true };
            state.KeyLightScale = Math.Max(0.0f, Math.Min(2.0f, (float)keyLightScale));
            state.LightAzimuth = (float)azimuth;
            state.LightElevation = Math.Max(-80.0f, Math.Min(80.0f, (float)elevation));
            state.LightTemperature = Math.Max(2500.0f, Math.Min(9000.0f, (float)temperatureKelvin));
            state.AmbientScale = Math.Max(0.0f, Math.Min(2.0f, (float)ambientScale));
            state.SpecularScale = Math.Max(0.0f, Math.Min(2.0f, (float)specularScale));
            state.StudioLightOverride = true;
            itemStates[id] = state;
            if (!NativeReady) return true;
            try { return D3D11ShelfNative.HC_GPU_SetShelfItemStudioLight(nativeHandle, id, state.KeyLightScale, state.LightAzimuth, state.LightElevation, state.LightTemperature, state.AmbientScale, state.SpecularScale) != 0; }
            catch { return false; }
        }

'@
    $hostText=$hostText.Replace($anchor,$method+$anchor)
    Set-Content -LiteralPath $hostPath -Value $hostText -Encoding UTF8
}

$runtimeText=Get-Content -Raw -LiteralPath $runtimePath -Encoding UTF8
if($runtimeText -notmatch 'HUYMAIER_V0307_CONSOLE_STUDIO_LIGHT_NATIVE_V1'){
    if($runtimeText -notmatch 'HUYMAIER_V0306_CONSOLE_PRESENTATION_NATIVE_V1'){throw 'v0.30.7 requires v0.30.6 native presentation transform first.'}
    $anchor='    struct Constants'+$nl+'    {'
    if(-not$runtimeText.Contains($anchor)){throw 'v0.30.7 runtime constants anchor missing.'}
    $studio=@'
    // HUYMAIER_V0307_CONSOLE_STUDIO_LIGHT_NATIVE_V1
    struct StudioConstants
    {
        XMFLOAT4 directionIntensity;
        XMFLOAT4 colorAmbient;
        XMFLOAT4 extra;
    };

'@
    $runtimeText=$runtimeText.Replace($anchor,$studio+$anchor)

    $old=@'
        float lightScale = 1.0f;
        float fanScale = 1.0f;
'@.TrimEnd()
    $new=@'
        float lightScale = 1.0f;
        float keyLightScale = 1.0f;
        float lightAzimuth = -36.0f, lightElevation = 43.0f, lightTemperature = 6500.0f;
        float ambientScale = 1.0f, specularScale = 1.0f;
        bool studioLightOverride = false;
        float fanScale = 1.0f;
'@.TrimEnd()
    $runtimeText=Replace-HcOnce $runtimeText $old $new 'runtime item lighting state'
    $runtimeText=Replace-HcOnce $runtimeText '        ComPtr<ID3D11Buffer> constants;' ('        ComPtr<ID3D11Buffer> constants;'+$nl+'        ComPtr<ID3D11Buffer> studioConstants;') 'runtime studio buffer member'

    $old=@'
        D3D11_BUFFER_DESC cb{};cb.ByteWidth=sizeof(Constants);cb.Usage=D3D11_USAGE_DYNAMIC;cb.BindFlags=D3D11_BIND_CONSTANT_BUFFER;cb.CPUAccessFlags=D3D11_CPU_ACCESS_WRITE;if(FAILED(hr=g_core.device->CreateBuffer(&cb,nullptr,g_core.constants.GetAddressOf()))){g_core.initResult=hr;return hr;}
'@.Trim()
    $new=$old+$nl+'        D3D11_BUFFER_DESC scb{};scb.ByteWidth=sizeof(StudioConstants);scb.Usage=D3D11_USAGE_DYNAMIC;scb.BindFlags=D3D11_BIND_CONSTANT_BUFFER;scb.CPUAccessFlags=D3D11_CPU_ACCESS_WRITE;if(FAILED(hr=g_core.device->CreateBuffer(&scb,nullptr,g_core.studioConstants.GetAddressOf()))){g_core.initResult=hr;return hr;}'
    $runtimeText=Replace-HcOnce $runtimeText $old $new 'runtime studio buffer creation'

    $anchor='    ID3D11SamplerState* GetSampler(int wrapS,int wrapT)'
    if(-not$runtimeText.Contains($anchor)){throw 'v0.30.7 runtime helper anchor missing.'}
    $helper=@'
    XMFLOAT3 HcTemperatureToLinearRgb(float kelvin)
    {
        const float t=std::max(2500.0f,std::min(9000.0f,kelvin))/100.0f;
        float r=255.0f,g=255.0f,b=255.0f;
        if(t<=66.0f){r=255.0f;g=99.4708025861f*std::log(std::max(t,1.0f))-161.1195681661f;if(t<=19.0f)b=0.0f;else b=138.5177312231f*std::log(t-10.0f)-305.0447927307f;}
        else{r=329.698727446f*std::pow(t-60.0f,-0.1332047592f);g=288.1221695283f*std::pow(t-60.0f,-0.0755148492f);b=255.0f;}
        auto clamp01=[](float v){return std::max(0.0f,std::min(1.0f,v/255.0f));};
        auto linear=[](float c){return c<=0.04045f?c/12.92f:std::pow((c+0.055f)/1.055f,2.4f);};
        const float sr=clamp01(r),sg=clamp01(g),sb=clamp01(b);return XMFLOAT3(linear(sr),linear(sg),linear(sb));
    }

'@
    $runtimeText=$runtimeText.Replace($anchor,$helper+$anchor)

    $old=@'
        XMMATRIX world=XMMatrixTranslation(-cx,-cy,-cz)*XMMatrixScaling(scale*mx,scale*my,scale*mz)*XMMatrixRotationX(XMConvertToRadians(pitch))*XMMatrixRotationY(XMConvertToRadians(yaw))*XMMatrixRotationZ(XMConvertToRadians(roll))*XMMatrixTranslation(item.offsetX*.012f,-item.offsetY*.012f,0);XMMATRIX view=XMMatrixLookAtLH(XMVectorSet(0,.08f,-4.2f,1),XMVectorZero(),XMVectorSet(0,1,0,0));XMMATRIX proj=XMMatrixPerspectiveFovLH(XMConvertToRadians(34.0f),vp.Width/vp.Height,.01f,100.0f);XMMATRIX wvp=world*view*proj;
'@.Trim()
    $new=$old+$nl+'        StudioConstants studio{};if(item.studioLightOverride){const float az=XMConvertToRadians(item.lightAzimuth),el=XMConvertToRadians(item.lightElevation),ce=std::cos(el);studio.directionIntensity=XMFLOAT4(std::sin(az)*ce,std::sin(el),-std::cos(az)*ce,item.keyLightScale);const XMFLOAT3 lc=HcTemperatureToLinearRgb(item.lightTemperature);studio.colorAmbient=XMFLOAT4(lc.x,lc.y,lc.z,item.ambientScale);studio.extra=XMFLOAT4(item.specularScale,0,0,1);}else{studio.directionIntensity=XMFLOAT4(-0.45f,0.72f,-0.62f,1.0f);studio.colorAmbient=XMFLOAT4(1,1,1,1);studio.extra=XMFLOAT4(1,0,0,0);}D3D11_MAPPED_SUBRESOURCE studioMapped{};if(SUCCEEDED(g_core.context->Map(g_core.studioConstants.Get(),0,D3D11_MAP_WRITE_DISCARD,0,&studioMapped))){memcpy(studioMapped.pData,&studio,sizeof(studio));g_core.context->Unmap(g_core.studioConstants.Get(),0);}'
    $runtimeText=Replace-HcOnce $runtimeText $old $new 'runtime per-item studio constants'

    $old='ID3D11Buffer* cb=g_core.constants.Get();g_core.context->VSSetConstantBuffers(0,1,&cb);g_core.context->PSSetConstantBuffers(0,1,&cb);'
    $new=$old+'ID3D11Buffer* scb=g_core.studioConstants.Get();g_core.context->PSSetConstantBuffers(1,1,&scb);'
    $runtimeText=Replace-HcOnce $runtimeText $old $new 'runtime studio buffer binding'

    $needle='extern "C" __declspec(dllexport) int __cdecl HC_GPU_SetShelfItemPresentation(void* handle,int id,float yawOffset,float pitch,float roll,float offsetX,float offsetY,int mirrorX,int mirrorY,int mirrorZ,int faceMode,float lightScale,float fanScale,int spin)'
    $start=$runtimeText.IndexOf($needle,[StringComparison]::Ordinal);if($start-lt0){throw 'v0.30.7 runtime presentation export anchor missing.'}
    $end=$runtimeText.IndexOf($nl,$start);if($end-lt0){throw 'v0.30.7 runtime presentation export line ending missing.'};$end+=$nl.Length
    $export='extern "C" __declspec(dllexport) int __cdecl HC_GPU_SetShelfItemStudioLight(void* handle,int id,float keyLightScale,float azimuth,float elevation,float temperatureKelvin,float ambientScale,float specularScale){if(!handle)return 0;std::lock_guard<std::mutex>guard(g_core.lock);ShelfSurface*s=static_cast<ShelfSurface*>(handle);auto it=s->items.find(id);if(it==s->items.end())return 0;Item&i=it->second;i.keyLightScale=std::max(0.0f,std::min(2.0f,keyLightScale));i.lightAzimuth=azimuth;i.lightElevation=std::max(-80.0f,std::min(80.0f,elevation));i.lightTemperature=std::max(2500.0f,std::min(9000.0f,temperatureKelvin));i.ambientScale=std::max(0.0f,std::min(2.0f,ambientScale));i.specularScale=std::max(0.0f,std::min(2.0f,specularScale));i.studioLightOverride=true;return 1;}'+$nl
    $runtimeText=$runtimeText.Insert($end,$export)
    Set-Content -LiteralPath $runtimePath -Value $runtimeText -Encoding UTF8
}

$assetText=Get-Content -Raw -LiteralPath $assetPath -Encoding UTF8
if($assetText -notmatch 'HUYMAIER_V0307_CONSOLE_STUDIO_LIGHT_SHADER_V1'){
    $anchor='    Texture2D BaseTexture : register(t0);'
    if(-not$assetText.Contains($anchor)){throw 'v0.30.7 shader cbuffer anchor missing.'}
    $cb=@'
    // HUYMAIER_V0307_CONSOLE_STUDIO_LIGHT_SHADER_V1
    cbuffer StudioLightConstants : register(b1)
    {
        float4 StudioLightDirectionIntensity;
        float4 StudioLightColorAmbient;
        float4 StudioLightExtra;
    };
'@
    $assetText=$assetText.Replace($anchor,$cb.TrimEnd()+$nl+$anchor)

    $old=@'
            float3 v=normalize(float3(0.0,0.08,-4.2)-i.wp);
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
'@.TrimEnd()
    $new=@'
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
    $assetText=Replace-HcOnce $assetText $old $new 'shader showroom lighting'
    Set-Content -LiteralPath $assetPath -Value $assetText -Encoding UTF8
}

Write-Host 'Applied v0.30.7 console-only editable studio key light: intensity, direction, temperature, ambient and specular; provider lighting remains on the exact legacy path.'
