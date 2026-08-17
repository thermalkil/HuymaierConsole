param()
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$module=Join-Path $root 'HuymaierConsoleModelPresentation.ps1'
$host=Join-Path $root 'Native\HuymaierD3D11ShelfHost.cs'
$runtime=Join-Path $root 'Native\HuymaierD3D11ShelfRuntime.cpp'
$asset=Join-Path $root 'Native\HuymaierD3D11ShelfAsset.h'
foreach($p in @($module,$host,$runtime,$asset)){if(-not(Test-Path -LiteralPath $p -PathType Leaf)){throw "v0.30.7 studio-light source missing: $p"}}
$nl=[Environment]::NewLine

# HUYMAIER_V0307_CONSOLE_STUDIO_LIGHT_TRANSFORM_V1
# The feature is console-only at the PowerShell routing layer. Native defaults
# remain the exact pre-v0.30.7 showroom lighting, so provider/storefront models
# are pixel-identical unless SetItemStudioLight is explicitly called.

$moduleText=Get-Content -Raw -LiteralPath $module -Encoding UTF8
if($moduleText -notmatch 'HUYMAIER_V0307_CONSOLE_STUDIO_LIGHT_V1'){
    $moduleText=$moduleText.Replace("# HUYMAIER_V0306_CONSOLE_MODEL_PRESENTATION_EDITOR_V1","# HUYMAIER_V0306_CONSOLE_MODEL_PRESENTATION_EDITOR_V1${nl}# HUYMAIER_V0307_CONSOLE_STUDIO_LIGHT_V1")

    $oldFields="$script:HcModelEditorFields=@('Yaw','Pitch','Roll','Scale','Position X','Position Y','Mirror X','Mirror Y','Mirror Z','Faces','Lighting','Fan motion')"
    $newFields="$script:HcModelEditorFields=@('Yaw','Pitch','Roll','Scale','Position X','Position Y','Mirror X','Mirror Y','Mirror Z','Faces','Lighting','Key light','Light azimuth','Light elevation','Light temp','Ambient','Specular','Fan motion')"
    if(-not$moduleText.Contains($oldFields)){throw 'v0.30.7 editor field anchor missing.'};$moduleText=$moduleText.Replace($oldFields,$newFields)

    $oldState="$script:HcModelEditorLightPercent=100${nl}$script:HcModelEditorFanPercent=100"
    $newState="$script:HcModelEditorLightPercent=100${nl}$script:HcModelEditorKeyLightPercent=100${nl}$script:HcModelEditorLightAzimuth=-36${nl}$script:HcModelEditorLightElevation=43${nl}$script:HcModelEditorLightTemperature=6500${nl}$script:HcModelEditorAmbientPercent=100${nl}$script:HcModelEditorSpecularPercent=100${nl}$script:HcModelEditorFanPercent=100"
    if(-not$moduleText.Contains($oldState)){throw 'v0.30.7 editor state anchor missing.'};$moduleText=$moduleText.Replace($oldState,$newState)

    $oldNorm="function Normalize-HcModelLightPercent {param([double]$Value);return [int]([math]::Round([math]::Max(20.0,[math]::Min(200.0,$Value))/10.0)*10.0)}"
    $newNorm=@'
function Normalize-HcModelLightPercent {param([double]$Value);return [int]([math]::Round([math]::Max(20.0,[math]::Min(200.0,$Value))/10.0)*10.0)}
function Normalize-HcModelKeyLightPercent {param([double]$Value);return [int]([math]::Round([math]::Max(0.0,[math]::Min(200.0,$Value))/10.0)*10.0)}
function Normalize-HcModelLightAzimuth {param([double]$Value);while($Value-gt180.0){$Value-=360.0};while($Value-le-180.0){$Value+=360.0};return [int]([math]::Round($Value/5.0)*5.0)}
function Normalize-HcModelLightElevation {param([double]$Value);return [int]([math]::Round([math]::Max(-80.0,[math]::Min(80.0,$Value))/5.0)*5.0)}
function Normalize-HcModelLightTemperature {param([double]$Value);return [int]([math]::Round([math]::Max(2500.0,[math]::Min(9000.0,$Value))/500.0)*500.0)}
function Normalize-HcModelAmbientPercent {param([double]$Value);return [int]([math]::Round([math]::Max(0.0,[math]::Min(200.0,$Value))/10.0)*10.0)}
function Normalize-HcModelSpecularPercent {param([double]$Value);return [int]([math]::Round([math]::Max(0.0,[math]::Min(200.0,$Value))/10.0)*10.0)}
'@
    if(-not$moduleText.Contains($oldNorm)){throw 'v0.30.7 normalization anchor missing.'};$moduleText=$moduleText.Replace($oldNorm,$newNorm.TrimEnd())

    $oldDefaults='$yaw=0.0;$pitch=-10.0;$roll=0.0;$scalePercent=100;$offsetX=0;$offsetY=0;$mirrorX=$false;$mirrorY=$false;$mirrorZ=$false;$faceMode=''Normal'';$light=100;$fan=100'
    $newDefaults='$yaw=0.0;$pitch=-10.0;$roll=0.0;$scalePercent=100;$offsetX=0;$offsetY=0;$mirrorX=$false;$mirrorY=$false;$mirrorZ=$false;$faceMode=''Normal'';$light=100;$keyLight=100;$lightAzimuth=-36;$lightElevation=43;$lightTemperature=6500;$ambient=100;$specular=100;$fan=100'
    if(-not$moduleText.Contains($oldDefaults)){throw 'v0.30.7 default-value anchor missing.'};$moduleText=$moduleText.Replace($oldDefaults,$newDefaults)

    $oldRead="            try{$light=Normalize-HcModelLightPercent ([double](Get-EntryProperty $entry 'LightPercent' 100))}catch{}${nl}            try{$fan=Normalize-HcModelFanPercent ([double](Get-EntryProperty $entry 'FanPercent' 100))}catch{}"
    $newRead=@'
            try{$light=Normalize-HcModelLightPercent ([double](Get-EntryProperty $entry 'LightPercent' 100))}catch{}
            try{$keyLight=Normalize-HcModelKeyLightPercent ([double](Get-EntryProperty $entry 'KeyLightPercent' 100))}catch{}
            try{$lightAzimuth=Normalize-HcModelLightAzimuth ([double](Get-EntryProperty $entry 'LightAzimuth' -36))}catch{}
            try{$lightElevation=Normalize-HcModelLightElevation ([double](Get-EntryProperty $entry 'LightElevation' 43))}catch{}
            try{$lightTemperature=Normalize-HcModelLightTemperature ([double](Get-EntryProperty $entry 'LightTemperature' 6500))}catch{}
            try{$ambient=Normalize-HcModelAmbientPercent ([double](Get-EntryProperty $entry 'AmbientPercent' 100))}catch{}
            try{$specular=Normalize-HcModelSpecularPercent ([double](Get-EntryProperty $entry 'SpecularPercent' 100))}catch{}
            try{$fan=Normalize-HcModelFanPercent ([double](Get-EntryProperty $entry 'FanPercent' 100))}catch{}
'@
    if(-not$moduleText.Contains($oldRead)){throw 'v0.30.7 config-read anchor missing.'};$moduleText=$moduleText.Replace($oldRead,$newRead.TrimEnd())

    $oldProvider='if(-not(Test-HcConsoleModelPresentationEditable $Platform)){$scalePercent=100;$roll=0;$offsetX=0;$offsetY=0;$mirrorX=$false;$mirrorY=$false;$mirrorZ=$false;$faceMode=''Normal'';$light=100;$fan=100}'
    $newProvider='if(-not(Test-HcConsoleModelPresentationEditable $Platform)){$scalePercent=100;$roll=0;$offsetX=0;$offsetY=0;$mirrorX=$false;$mirrorY=$false;$mirrorZ=$false;$faceMode=''Normal'';$light=100;$keyLight=100;$lightAzimuth=-36;$lightElevation=43;$lightTemperature=6500;$ambient=100;$specular=100;$fan=100}'
    if(-not$moduleText.Contains($oldProvider)){throw 'v0.30.7 provider-neutral anchor missing.'};$moduleText=$moduleText.Replace($oldProvider,$newProvider)

    $oldReturn='return [pscustomobject]@{Key=$key;Yaw=[double]$yaw;Pitch=[double]$pitch;Roll=[double]$roll;ScalePercent=[int]$scalePercent;OffsetX=[int]$offsetX;OffsetY=[int]$offsetY;MirrorX=[bool]$mirrorX;MirrorY=[bool]$mirrorY;MirrorZ=[bool]$mirrorZ;FaceMode=$faceMode;LightPercent=[int]$light;FanPercent=[int]$fan}'
    $newReturn='return [pscustomobject]@{Key=$key;Yaw=[double]$yaw;Pitch=[double]$pitch;Roll=[double]$roll;ScalePercent=[int]$scalePercent;OffsetX=[int]$offsetX;OffsetY=[int]$offsetY;MirrorX=[bool]$mirrorX;MirrorY=[bool]$mirrorY;MirrorZ=[bool]$mirrorZ;FaceMode=$faceMode;LightPercent=[int]$light;KeyLightPercent=[int]$keyLight;LightAzimuth=[int]$lightAzimuth;LightElevation=[int]$lightElevation;LightTemperature=[int]$lightTemperature;AmbientPercent=[int]$ambient;SpecularPercent=[int]$specular;FanPercent=[int]$fan}'
    if(-not$moduleText.Contains($oldReturn)){throw 'v0.30.7 view-return anchor missing.'};$moduleText=$moduleText.Replace($oldReturn,$newReturn)

    $oldParams="param([string]$ModelPath,[string]$Platform,[double]$Yaw,[double]$Pitch,[int]$ScalePercent=100,[double]$Roll=0,[int]$OffsetX=0,[int]$OffsetY=0,[bool]$MirrorX=$false,[bool]$MirrorY=$false,[bool]$MirrorZ=$false,[string]$FaceMode='Normal',[int]$LightPercent=100,[int]$FanPercent=100)"
    $newParams="param([string]$ModelPath,[string]$Platform,[double]$Yaw,[double]$Pitch,[int]$ScalePercent=100,[double]$Roll=0,[int]$OffsetX=0,[int]$OffsetY=0,[bool]$MirrorX=$false,[bool]$MirrorY=$false,[bool]$MirrorZ=$false,[string]$FaceMode='Normal',[int]$LightPercent=100,[int]$KeyLightPercent=100,[int]$LightAzimuth=-36,[int]$LightElevation=43,[int]$LightTemperature=6500,[int]$AmbientPercent=100,[int]$SpecularPercent=100,[int]$FanPercent=100)"
    if(-not$moduleText.Contains($oldParams)){throw 'v0.30.7 Set-HcModelDefaultView parameter anchor missing.'};$moduleText=$moduleText.Replace($oldParams,$newParams)

    $oldPersist="        LightPercent=(Normalize-HcModelLightPercent $LightPercent);FanPercent=(Normalize-HcModelFanPercent $FanPercent);UpdatedUtc=[DateTime]::UtcNow.ToString('o')"
    $newPersist="        LightPercent=(Normalize-HcModelLightPercent $LightPercent);KeyLightPercent=(Normalize-HcModelKeyLightPercent $KeyLightPercent);LightAzimuth=(Normalize-HcModelLightAzimuth $LightAzimuth);LightElevation=(Normalize-HcModelLightElevation $LightElevation);LightTemperature=(Normalize-HcModelLightTemperature $LightTemperature)${nl}        AmbientPercent=(Normalize-HcModelAmbientPercent $AmbientPercent);SpecularPercent=(Normalize-HcModelSpecularPercent $SpecularPercent);FanPercent=(Normalize-HcModelFanPercent $FanPercent);UpdatedUtc=[DateTime]::UtcNow.ToString('o')"
    if(-not$moduleText.Contains($oldPersist)){throw 'v0.30.7 persistence anchor missing.'};$moduleText=$moduleText.Replace($oldPersist,$newPersist)

    $oldStateFrom="$script:HcModelEditorFaceMode=[string]$View.FaceMode;$script:HcModelEditorLightPercent=[int]$View.LightPercent;$script:HcModelEditorFanPercent=[int]$View.FanPercent"
    $newStateFrom="$script:HcModelEditorFaceMode=[string]$View.FaceMode;$script:HcModelEditorLightPercent=[int]$View.LightPercent;$script:HcModelEditorKeyLightPercent=[int]$View.KeyLightPercent;$script:HcModelEditorLightAzimuth=[int]$View.LightAzimuth;$script:HcModelEditorLightElevation=[int]$View.LightElevation;$script:HcModelEditorLightTemperature=[int]$View.LightTemperature;$script:HcModelEditorAmbientPercent=[int]$View.AmbientPercent;$script:HcModelEditorSpecularPercent=[int]$View.SpecularPercent;$script:HcModelEditorFanPercent=[int]$View.FanPercent"
    if(-not$moduleText.Contains($oldStateFrom)){throw 'v0.30.7 state-from-view anchor missing.'};$moduleText=$moduleText.Replace($oldStateFrom,$newStateFrom)

    $oldCurrent='[pscustomobject]@{Yaw=[double]$script:HcModelViewerYaw;Pitch=[double]$script:HcModelViewerPitch;Roll=[double]$script:HcModelEditorRoll;ScalePercent=[int]$script:HcModelEditorScalePercent;OffsetX=[int]$script:HcModelEditorOffsetX;OffsetY=[int]$script:HcModelEditorOffsetY;MirrorX=[bool]$script:HcModelEditorMirrorX;MirrorY=[bool]$script:HcModelEditorMirrorY;MirrorZ=[bool]$script:HcModelEditorMirrorZ;FaceMode=[string]$script:HcModelEditorFaceMode;LightPercent=[int]$script:HcModelEditorLightPercent;FanPercent=[int]$script:HcModelEditorFanPercent}'
    $newCurrent='[pscustomobject]@{Yaw=[double]$script:HcModelViewerYaw;Pitch=[double]$script:HcModelViewerPitch;Roll=[double]$script:HcModelEditorRoll;ScalePercent=[int]$script:HcModelEditorScalePercent;OffsetX=[int]$script:HcModelEditorOffsetX;OffsetY=[int]$script:HcModelEditorOffsetY;MirrorX=[bool]$script:HcModelEditorMirrorX;MirrorY=[bool]$script:HcModelEditorMirrorY;MirrorZ=[bool]$script:HcModelEditorMirrorZ;FaceMode=[string]$script:HcModelEditorFaceMode;LightPercent=[int]$script:HcModelEditorLightPercent;KeyLightPercent=[int]$script:HcModelEditorKeyLightPercent;LightAzimuth=[int]$script:HcModelEditorLightAzimuth;LightElevation=[int]$script:HcModelEditorLightElevation;LightTemperature=[int]$script:HcModelEditorLightTemperature;AmbientPercent=[int]$script:HcModelEditorAmbientPercent;SpecularPercent=[int]$script:HcModelEditorSpecularPercent;FanPercent=[int]$script:HcModelEditorFanPercent}'
    if(-not$moduleText.Contains($oldCurrent)){throw 'v0.30.7 current-view anchor missing.'};$moduleText=$moduleText.Replace($oldCurrent,$newCurrent)

    $oldSurface='            [void]$Surface.SetItemPresentation($Id,[double]$View.Yaw,[double]$View.Pitch,[double]$View.Roll,[double]$View.OffsetX,[double]$View.OffsetY,[bool]$View.MirrorX,[bool]$View.MirrorY,[bool]$View.MirrorZ,$face,$light,$fan,$Spin)'
    $newSurface=$oldSurface+$nl+"            if($Surface.PSObject.Methods['SetItemStudioLight']){[void]$Surface.SetItemStudioLight($Id,[double]$View.KeyLightPercent/100.0,[double]$View.LightAzimuth,[double]$View.LightElevation,[double]$View.LightTemperature,[double]$View.AmbientPercent/100.0,[double]$View.SpecularPercent/100.0)}"
    if(-not$moduleText.Contains($oldSurface)){throw 'v0.30.7 surface studio-light anchor missing.'};$moduleText=$moduleText.Replace($oldSurface,$newSurface)

    $oldValues="        'Lighting'{return ([int]$script:HcModelEditorLightPercent).ToString()+'%'}${nl}        'Fan motion'{return ([int]$script:HcModelEditorFanPercent).ToString()+'%'}"
    $newValues=@'
        'Lighting'{return ([int]$script:HcModelEditorLightPercent).ToString()+'%'}
        'Key light'{return ([int]$script:HcModelEditorKeyLightPercent).ToString()+'%'}
        'Light azimuth'{return ([int]$script:HcModelEditorLightAzimuth).ToString()+'°'}
        'Light elevation'{return ([int]$script:HcModelEditorLightElevation).ToString()+'°'}
        'Light temp'{return ([int]$script:HcModelEditorLightTemperature).ToString()+'K'}
        'Ambient'{return ([int]$script:HcModelEditorAmbientPercent).ToString()+'%'}
        'Specular'{return ([int]$script:HcModelEditorSpecularPercent).ToString()+'%'}
        'Fan motion'{return ([int]$script:HcModelEditorFanPercent).ToString()+'%'}
'@
    if(-not$moduleText.Contains($oldValues)){throw 'v0.30.7 editor value-text anchor missing.'};$moduleText=$moduleText.Replace($oldValues,$newValues.TrimEnd())

    $oldSave='-FaceMode $v.FaceMode -LightPercent $v.LightPercent -FanPercent $v.FanPercent)'
    $newSave='-FaceMode $v.FaceMode -LightPercent $v.LightPercent -KeyLightPercent $v.KeyLightPercent -LightAzimuth $v.LightAzimuth -LightElevation $v.LightElevation -LightTemperature $v.LightTemperature -AmbientPercent $v.AmbientPercent -SpecularPercent $v.SpecularPercent -FanPercent $v.FanPercent)'
    if(-not$moduleText.Contains($oldSave)){throw 'v0.30.7 save-editor anchor missing.'};$moduleText=$moduleText.Replace($oldSave,$newSave)

    $oldAdjust="        'Lighting'{$script:HcModelEditorLightPercent=Normalize-HcModelLightPercent ([int]$script:HcModelEditorLightPercent+10*$Delta)}${nl}        'Fan motion'{$script:HcModelEditorFanPercent=Normalize-HcModelFanPercent ([int]$script:HcModelEditorFanPercent+10*$Delta)}"
    $newAdjust=@'
        'Lighting'{$script:HcModelEditorLightPercent=Normalize-HcModelLightPercent ([int]$script:HcModelEditorLightPercent+10*$Delta)}
        'Key light'{$script:HcModelEditorKeyLightPercent=Normalize-HcModelKeyLightPercent ([int]$script:HcModelEditorKeyLightPercent+10*$Delta)}
        'Light azimuth'{$script:HcModelEditorLightAzimuth=Normalize-HcModelLightAzimuth ([int]$script:HcModelEditorLightAzimuth+5*$Delta)}
        'Light elevation'{$script:HcModelEditorLightElevation=Normalize-HcModelLightElevation ([int]$script:HcModelEditorLightElevation+5*$Delta)}
        'Light temp'{$script:HcModelEditorLightTemperature=Normalize-HcModelLightTemperature ([int]$script:HcModelEditorLightTemperature+500*$Delta)}
        'Ambient'{$script:HcModelEditorAmbientPercent=Normalize-HcModelAmbientPercent ([int]$script:HcModelEditorAmbientPercent+10*$Delta)}
        'Specular'{$script:HcModelEditorSpecularPercent=Normalize-HcModelSpecularPercent ([int]$script:HcModelEditorSpecularPercent+10*$Delta)}
        'Fan motion'{$script:HcModelEditorFanPercent=Normalize-HcModelFanPercent ([int]$script:HcModelEditorFanPercent+10*$Delta)}
'@
    if(-not$moduleText.Contains($oldAdjust)){throw 'v0.30.7 adjust-field anchor missing.'};$moduleText=$moduleText.Replace($oldAdjust,$newAdjust.TrimEnd())

    Set-Content -LiteralPath $module -Value $moduleText -Encoding UTF8
}

$hostText=Get-Content -Raw -LiteralPath $host -Encoding UTF8
if($hostText -notmatch 'HUYMAIER_V0307_CONSOLE_STUDIO_LIGHT_NATIVE_BRIDGE_V1'){
    $marker='    // HUYMAIER_V0306_CONSOLE_PRESENTATION_NATIVE_BRIDGE_V1'
    if(-not$hostText.Contains($marker)){throw 'v0.30.7 requires the v0.30.6 host presentation transform first.'}
    $hostText=$hostText.Replace($marker,$marker+$nl+'    // HUYMAIER_V0307_CONSOLE_STUDIO_LIGHT_NATIVE_BRIDGE_V1')

    $pinvoke='        internal static extern int HC_GPU_SetShelfItemPresentation(IntPtr handle, int id, float yawOffset, float pitch, float roll, float offsetX, float offsetY, int mirrorX, int mirrorY, int mirrorZ, int faceMode, float lightScale, float fanScale, int spin);'
    $pinvokeNew=$pinvoke+$nl+$nl+'        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]'+$nl+'        internal static extern int HC_GPU_SetShelfItemStudioLight(IntPtr handle, int id, float keyLightScale, float azimuth, float elevation, float temperatureKelvin, float ambientScale, float specularScale);'
    if(-not$hostText.Contains($pinvoke)){throw 'v0.30.7 host studio-light P/Invoke anchor missing.'};$hostText=$hostText.Replace($pinvoke,$pinvokeNew)

    $state='            public float LightScale = 1.0f;'+$nl+'            public float FanScale = 1.0f;'
    $stateNew='            public float LightScale = 1.0f;'+$nl+'            public float KeyLightScale = 1.0f;'+$nl+'            public float LightAzimuth = -36.0f, LightElevation = 43.0f, LightTemperature = 6500.0f;'+$nl+'            public float AmbientScale = 1.0f, SpecularScale = 1.0f;'+$nl+'            public bool StudioLightOverride = false;'+$nl+'            public float FanScale = 1.0f;'
    if(-not$hostText.Contains($state)){throw 'v0.30.7 host ItemState anchor missing.'};$hostText=$hostText.Replace($state,$stateNew)

    $apply='                bool viewOk = D3D11ShelfNative.HC_GPU_SetShelfItemPresentation(nativeHandle, id, state.YawOffset, state.Pitch, state.Roll, state.OffsetX, state.OffsetY, state.MirrorX ? 1 : 0, state.MirrorY ? 1 : 0, state.MirrorZ ? 1 : 0, state.FaceMode, state.LightScale, state.FanScale, state.Spin ? 1 : 0) != 0;'+$nl+'                return layoutOk && viewOk;'
    $applyNew='                bool viewOk = D3D11ShelfNative.HC_GPU_SetShelfItemPresentation(nativeHandle, id, state.YawOffset, state.Pitch, state.Roll, state.OffsetX, state.OffsetY, state.MirrorX ? 1 : 0, state.MirrorY ? 1 : 0, state.MirrorZ ? 1 : 0, state.FaceMode, state.LightScale, state.FanScale, state.Spin ? 1 : 0) != 0;'+$nl+'                bool studioOk = !state.StudioLightOverride || D3D11ShelfNative.HC_GPU_SetShelfItemStudioLight(nativeHandle, id, state.KeyLightScale, state.LightAzimuth, state.LightElevation, state.LightTemperature, state.AmbientScale, state.SpecularScale) != 0;'+$nl+'                return layoutOk && viewOk && studioOk;'
    if(-not$hostText.Contains($apply)){throw 'v0.30.7 host native replay anchor missing.'};$hostText=$hostText.Replace($apply,$applyNew)

    $clearAnchor='        public void ClearModels()'+$nl+'        {'
    if(-not$hostText.Contains($clearAnchor)){throw 'v0.30.7 host method anchor missing.'}
    $studioMethod=@'
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
    $hostText=$hostText.Replace($clearAnchor,$studioMethod+$clearAnchor)
    Set-Content -LiteralPath $host -Value $hostText -Encoding UTF8
}

$runtimeText=Get-Content -Raw -LiteralPath $runtime -Encoding UTF8
if($runtimeText -notmatch 'HUYMAIER_V0307_CONSOLE_STUDIO_LIGHT_NATIVE_V1'){
    if($runtimeText -notmatch 'HUYMAIER_V0306_CONSOLE_PRESENTATION_NATIVE_V1'){throw 'v0.30.7 requires the v0.30.6 native presentation transform first.'}

    $constants='    struct Constants'+$nl+'    {'
    $studioStruct=@'
    // HUYMAIER_V0307_CONSOLE_STUDIO_LIGHT_NATIVE_V1
    struct StudioConstants
    {
        XMFLOAT4 directionIntensity;
        XMFLOAT4 colorAmbient;
        XMFLOAT4 extra;
    };

'@
    if(-not$runtimeText.Contains($constants)){throw 'v0.30.7 runtime constants anchor missing.'};$runtimeText=$runtimeText.Replace($constants,$studioStruct+$constants)

    $item='        float lightScale = 1.0f;'+$nl+'        float fanScale = 1.0f;'
    $itemNew='        float lightScale = 1.0f;'+$nl+'        float keyLightScale = 1.0f;'+$nl+'        float lightAzimuth = -36.0f, lightElevation = 43.0f, lightTemperature = 6500.0f;'+$nl+'        float ambientScale = 1.0f, specularScale = 1.0f;'+$nl+'        bool studioLightOverride = false;'+$nl+'        float fanScale = 1.0f;'
    if(-not$runtimeText.Contains($item)){throw 'v0.30.7 runtime Item lighting anchor missing.'};$runtimeText=$runtimeText.Replace($item,$itemNew)

    $core='        ComPtr<ID3D11Buffer> constants;'
    $coreNew=$core+$nl+'        ComPtr<ID3D11Buffer> studioConstants;'
    if(-not$runtimeText.Contains($core)){throw 'v0.30.7 runtime studio constant-buffer field anchor missing.'};$runtimeText=$runtimeText.Replace($core,$coreNew)

    $buffer='        D3D11_BUFFER_DESC cb{};cb.ByteWidth=sizeof(Constants);cb.Usage=D3D11_USAGE_DYNAMIC;cb.BindFlags=D3D11_BIND_CONSTANT_BUFFER;cb.CPUAccessFlags=D3D11_CPU_ACCESS_WRITE;if(FAILED(hr=g_core.device->CreateBuffer(&cb,nullptr,g_core.constants.GetAddressOf()))){g_core.initResult=hr;return hr;}'
    $bufferNew=$buffer+$nl+'        D3D11_BUFFER_DESC scb{};scb.ByteWidth=sizeof(StudioConstants);scb.Usage=D3D11_USAGE_DYNAMIC;scb.BindFlags=D3D11_BIND_CONSTANT_BUFFER;scb.CPUAccessFlags=D3D11_CPU_ACCESS_WRITE;if(FAILED(hr=g_core.device->CreateBuffer(&scb,nullptr,g_core.studioConstants.GetAddressOf()))){g_core.initResult=hr;return hr;}'
    if(-not$runtimeText.Contains($buffer)){throw 'v0.30.7 runtime studio constant-buffer creation anchor missing.'};$runtimeText=$runtimeText.Replace($buffer,$bufferNew)

    $sampler='    ID3D11SamplerState* GetSampler(int wrapS,int wrapT)'
    $helper=@'
    XMFLOAT3 HcTemperatureToLinearRgb(float kelvin)
    {
        const float t=std::max(2500.0f,std::min(9000.0f,kelvin))/100.0f;
        float r=255.0f,g=255.0f,b=255.0f;
        if(t<=66.0f){r=255.0f;g=99.4708025861f*std::log(std::max(t,1.0f))-161.1195681661f;if(t<=19.0f)b=0.0f;else b=138.5177312231f*std::log(t-10.0f)-305.0447927307f;}
        else{r=329.698727446f*std::pow(t-60.0f,-0.1332047592f);g=288.1221695283f*std::pow(t-60.0f,-0.0755148492f);b=255.0f;}
        auto clamp01=[](float v){return std::max(0.0f,std::min(1.0f,v/255.0f));};
        auto linear=[](float c){return c<=0.04045f?c/12.92f:std::pow((c+0.055f)/1.055f,2.4f);};
        float sr=clamp01(r),sg=clamp01(g),sb=clamp01(b);return XMFLOAT3(linear(sr),linear(sg),linear(sb));
    }

'@
    if(-not$runtimeText.Contains($sampler)){throw 'v0.30.7 runtime temperature-helper anchor missing.'};$runtimeText=$runtimeText.Replace($sampler,$helper+$sampler)

    $world='        XMMATRIX world=XMMatrixTranslation(-cx,-cy,-cz)*XMMatrixScaling(scale*mx,scale*my,scale*mz)*XMMatrixRotationX(XMConvertToRadians(pitch))*XMMatrixRotationY(XMConvertToRadians(yaw))*XMMatrixRotationZ(XMConvertToRadians(roll))*XMMatrixTranslation(item.offsetX*.012f,-item.offsetY*.012f,0);XMMATRIX view=XMMatrixLookAtLH(XMVectorSet(0,.08f,-4.2f,1),XMVectorZero(),XMVectorSet(0,1,0,0));XMMATRIX proj=XMMatrixPerspectiveFovLH(XMConvertToRadians(34.0f),vp.Width/vp.Height,.01f,100.0f);XMMATRIX wvp=world*view*proj;'
    $worldNew=$world+$nl+'        StudioConstants studio{};if(item.studioLightOverride){const float az=XMConvertToRadians(item.lightAzimuth),el=XMConvertToRadians(item.lightElevation);const float ce=std::cos(el);studio.directionIntensity=XMFLOAT4(std::sin(az)*ce,std::sin(el),-std::cos(az)*ce,item.keyLightScale);const XMFLOAT3 lc=HcTemperatureToLinearRgb(item.lightTemperature);studio.colorAmbient=XMFLOAT4(lc.x,lc.y,lc.z,item.ambientScale);studio.extra=XMFLOAT4(item.specularScale,0,0,1);}else{studio.directionIntensity=XMFLOAT4(-0.45f,0.72f,-0.62f,1.0f);studio.colorAmbient=XMFLOAT4(1,1,1,1);studio.extra=XMFLOAT4(1,0,0,0);}D3D11_MAPPED_SUBRESOURCE studioMapped{};if(SUCCEEDED(g_core.context->Map(g_core.studioConstants.Get(),0,D3D11_MAP_WRITE_DISCARD,0,&studioMapped))){memcpy(studioMapped.pData,&studio,sizeof(studio));g_core.context->Unmap(g_core.studioConstants.Get(),0);}'
    if(-not$runtimeText.Contains($world)){throw 'v0.30.7 runtime per-item studio-light anchor missing.'};$runtimeText=$runtimeText.Replace($world,$worldNew)

    $bind='ID3D11Buffer* cb=g_core.constants.Get();g_core.context->VSSetConstantBuffers(0,1,&cb);g_core.context->PSSetConstantBuffers(0,1,&cb);'
    $bindNew=$bind+'ID3D11Buffer* scb=g_core.studioConstants.Get();g_core.context->PSSetConstantBuffers(1,1,&scb);'
    if(-not$runtimeText.Contains($bind)){throw 'v0.30.7 runtime studio-buffer bind anchor missing.'};$runtimeText=$runtimeText.Replace($bind,$bindNew)

    $export='extern "C" __declspec(dllexport) int __cdecl HC_GPU_SetShelfItemPresentation(void* handle,int id,float yawOffset,float pitch,float roll,float offsetX,float offsetY,int mirrorX,int mirrorY,int mirrorZ,int faceMode,float lightScale,float fanScale,int spin)'
    $idx=$runtimeText.IndexOf($export,[StringComparison]::Ordinal);if($idx-lt0){throw 'v0.30.7 runtime presentation export anchor missing.'}
    $lineEnd=$runtimeText.IndexOf($nl,$idx);if($lineEnd-lt0){$lineEnd=$runtimeText.Length}else{$lineEnd+=$nl.Length}
    $studioExport='extern "C" __declspec(dllexport) int __cdecl HC_GPU_SetShelfItemStudioLight(void* handle,int id,float keyLightScale,float azimuth,float elevation,float temperatureKelvin,float ambientScale,float specularScale){if(!handle)return 0;std::lock_guard<std::mutex>guard(g_core.lock);ShelfSurface*s=static_cast<ShelfSurface*>(handle);auto it=s->items.find(id);if(it==s->items.end())return 0;Item&i=it->second;i.keyLightScale=std::max(0.0f,std::min(2.0f,keyLightScale));i.lightAzimuth=azimuth;i.lightElevation=std::max(-80.0f,std::min(80.0f,elevation));i.lightTemperature=std::max(2500.0f,std::min(9000.0f,temperatureKelvin));i.ambientScale=std::max(0.0f,std::min(2.0f,ambientScale));i.specularScale=std::max(0.0f,std::min(2.0f,specularScale));i.studioLightOverride=true;return 1;}'+$nl
    $runtimeText=$runtimeText.Insert($lineEnd,$studioExport)
    Set-Content -LiteralPath $runtime -Value $runtimeText -Encoding UTF8
}

$assetText=Get-Content -Raw -LiteralPath $asset -Encoding UTF8
if($assetText -notmatch 'HUYMAIER_V0307_CONSOLE_STUDIO_LIGHT_SHADER_V1'){
    $cbuffer='    Texture2D BaseTexture : register(t0);'
    $studioCbuffer=@'
    // HUYMAIER_V0307_CONSOLE_STUDIO_LIGHT_SHADER_V1
    cbuffer StudioLightConstants : register(b1)
    {
        float4 StudioLightDirectionIntensity;
        float4 StudioLightColorAmbient;
        float4 StudioLightExtra;
    };
'@
    if(-not$assetText.Contains($cbuffer)){throw 'v0.30.7 shader cbuffer anchor missing.'};$assetText=$assetText.Replace($cbuffer,$studioCbuffer.TrimEnd()+$nl+$cbuffer)

    $oldLighting=@'
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
'@
    $newLighting=@'
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
'@
    if(-not$assetText.Contains($oldLighting)){throw 'v0.30.7 shader showroom-lighting anchor missing.'};$assetText=$assetText.Replace($oldLighting,$newLighting)
    Set-Content -LiteralPath $asset -Value $assetText -Encoding UTF8
}

Write-Host 'Applied v0.30.7 console-only editable studio key light (direction, intensity, temperature, ambient and specular); provider lighting remains unchanged.'
