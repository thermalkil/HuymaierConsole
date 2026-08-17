param()
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$modelDefaults=Join-Path $root 'HuymaierModelDefaults.ps1'
$module=Join-Path $root 'HuymaierConsoleModelPresentation.ps1'
$host=Join-Path $root 'Native\HuymaierD3D11ShelfHost.cs'
$runtime=Join-Path $root 'Native\HuymaierD3D11ShelfRuntime.cpp'
$asset=Join-Path $root 'Native\HuymaierD3D11ShelfAsset.h'
foreach($p in @($modelDefaults,$module,$host,$runtime,$asset)){if(-not(Test-Path -LiteralPath $p -PathType Leaf)){throw "v0.30.6 model-presentation source missing: $p"}}
$nl=[Environment]::NewLine

# HUYMAIER_V0306_CONSOLE_MODEL_PRESENTATION_TRANSFORM_V1
# Load the console-only presentation editor after the established orientation/
# scale wrapper so it can extend that contract without changing provider models.
$defaultsText=Get-Content -Raw -LiteralPath $modelDefaults -Encoding UTF8
if($defaultsText -notmatch 'HUYMAIER_V0306_CONSOLE_MODEL_PRESENTATION_LOAD_V1'){
    $append=@'

# HUYMAIER_V0306_CONSOLE_MODEL_PRESENTATION_LOAD_V1
$script:HcConsoleModelPresentationPath=Join-Path $script:BaseDir 'HuymaierConsoleModelPresentation.ps1'
if(Test-Path -LiteralPath $script:HcConsoleModelPresentationPath -PathType Leaf){
    try{. $script:HcConsoleModelPresentationPath}
    catch{try{Write-Log ('Console model presentation editor load failed: '+$_.Exception.Message) 'ERROR'}catch{}}
}
'@
    $defaultsText=$defaultsText.TrimEnd()+$append+$nl
    Set-Content -LiteralPath $modelDefaults -Value $defaultsText -Encoding UTF8
}

$hostText=Get-Content -Raw -LiteralPath $host -Encoding UTF8
if($hostText -notmatch 'HUYMAIER_V0306_CONSOLE_PRESENTATION_NATIVE_BRIDGE_V1'){
    $marker='    // HUYMAIER_D3D11_DPI_AWARE_SHELF_V1'
    if(-not$hostText.Contains($marker)){throw 'Presentation host marker anchor missing.'}
    $hostText=$hostText.Replace($marker,$marker+$nl+'    // HUYMAIER_V0306_CONSOLE_PRESENTATION_NATIVE_BRIDGE_V1')

    $pinvoke='        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]'+$nl+'        internal static extern int HC_GPU_SetShelfItemView(IntPtr handle, int id, float yawOffset, float pitch, int spin);'
    $pinvokeNew=$pinvoke+$nl+$nl+'        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]'+$nl+'        internal static extern int HC_GPU_SetShelfItemPresentation(IntPtr handle, int id, float yawOffset, float pitch, float roll, float offsetX, float offsetY, int mirrorX, int mirrorY, int mirrorZ, int faceMode, float lightScale, float fanScale, int spin);'
    if(-not$hostText.Contains($pinvoke)){throw 'Presentation host P/Invoke anchor missing.'}
    $hostText=$hostText.Replace($pinvoke,$pinvokeNew)

    $state='            public float YawOffset = 0.0f;'+$nl+'            public float Pitch = -10.0f;'+$nl+'            public bool Spin = true;'
    $stateNew='            public float YawOffset = 0.0f;'+$nl+'            public float Pitch = -10.0f;'+$nl+'            public float Roll = 0.0f;'+$nl+'            public float OffsetX = 0.0f, OffsetY = 0.0f;'+$nl+'            public bool MirrorX, MirrorY, MirrorZ;'+$nl+'            public int FaceMode = 0;'+$nl+'            public float LightScale = 1.0f;'+$nl+'            public float FanScale = 1.0f;'+$nl+'            public bool Spin = true;'
    if(-not$hostText.Contains($state)){throw 'Presentation host ItemState anchor missing.'}
    $hostText=$hostText.Replace($state,$stateNew)

    $apply='                bool viewOk = D3D11ShelfNative.HC_GPU_SetShelfItemView(nativeHandle, id, state.YawOffset, state.Pitch, state.Spin ? 1 : 0) != 0;'+$nl+'                return layoutOk && viewOk;'
    $applyNew='                bool viewOk = D3D11ShelfNative.HC_GPU_SetShelfItemPresentation(nativeHandle, id, state.YawOffset, state.Pitch, state.Roll, state.OffsetX, state.OffsetY, state.MirrorX ? 1 : 0, state.MirrorY ? 1 : 0, state.MirrorZ ? 1 : 0, state.FaceMode, state.LightScale, state.FanScale, state.Spin ? 1 : 0) != 0;'+$nl+'                return layoutOk && viewOk;'
    if(-not$hostText.Contains($apply)){throw 'Presentation host replay anchor missing.'}
    $hostText=$hostText.Replace($apply,$applyNew)

    $clearAnchor='        public void ClearModels()'+$nl+'        {'
    if(-not$hostText.Contains($clearAnchor)){throw 'Presentation host public-method anchor missing.'}
    $presentationMethod=@'
        public bool SetItemPresentation(int id, double yawOffset, double pitch, double roll, double offsetX, double offsetY, bool mirrorX, bool mirrorY, bool mirrorZ, int faceMode, double lightScale, double fanScale, bool spin)
        {
            if (disposed || id < 0) return false;
            ItemState state;
            if (!itemStates.TryGetValue(id, out state) || state == null)
                state = new ItemState { Width = 1.0f, Height = 1.0f, Scale = .82f, Visible = true };
            state.YawOffset = (float)yawOffset;
            state.Pitch = Math.Max(-80.0f, Math.Min(80.0f, (float)pitch));
            state.Roll = (float)roll;
            state.OffsetX = Math.Max(-50.0f, Math.Min(50.0f, (float)offsetX));
            state.OffsetY = Math.Max(-50.0f, Math.Min(50.0f, (float)offsetY));
            state.MirrorX = mirrorX; state.MirrorY = mirrorY; state.MirrorZ = mirrorZ;
            state.FaceMode = Math.Max(0, Math.Min(2, faceMode));
            state.LightScale = Math.Max(.20f, Math.Min(2.00f, (float)lightScale));
            state.FanScale = Math.Max(0.0f, Math.Min(1.0f, (float)fanScale));
            state.Spin = spin;
            itemStates[id] = state;
            if (!NativeReady) return true;
            try { return D3D11ShelfNative.HC_GPU_SetShelfItemPresentation(nativeHandle, id, state.YawOffset, state.Pitch, state.Roll, state.OffsetX, state.OffsetY, state.MirrorX ? 1 : 0, state.MirrorY ? 1 : 0, state.MirrorZ ? 1 : 0, state.FaceMode, state.LightScale, state.FanScale, state.Spin ? 1 : 0) != 0; }
            catch { return false; }
        }

'@
    $hostText=$hostText.Replace($clearAnchor,$presentationMethod+$clearAnchor)
    Set-Content -LiteralPath $host -Value $hostText -Encoding UTF8
}

$runtimeText=Get-Content -Raw -LiteralPath $runtime -Encoding UTF8
if($runtimeText -notmatch 'HUYMAIER_V0306_CONSOLE_PRESENTATION_NATIVE_V1'){
    $item='        float yawOffset = 0.0f;'+$nl+'        float pitch = -10.0f;'+$nl+'        bool spin = true;'
    $itemNew='        float yawOffset = 0.0f;'+$nl+'        float pitch = -10.0f;'+$nl+'        float roll = 0.0f;'+$nl+'        float offsetX = 0.0f, offsetY = 0.0f;'+$nl+'        bool mirrorX = false, mirrorY = false, mirrorZ = false;'+$nl+'        int faceMode = 0;'+$nl+'        float lightScale = 1.0f;'+$nl+'        float fanScale = 1.0f;'+$nl+'        bool spin = true;'
    if(-not$runtimeText.Contains($item)){throw 'Presentation native Item anchor missing.'}
    $runtimeText=$runtimeText.Replace($item,$itemNew)

    $coreField='        ComPtr<ID3D11RasterizerState> rasterizerSingleSided;'+$nl+'        ComPtr<ID3D11RasterizerState> rasterizerDoubleSided;'
    $coreFieldNew='        ComPtr<ID3D11RasterizerState> rasterizerSingleSided;'+$nl+'        ComPtr<ID3D11RasterizerState> rasterizerSingleSidedMirrored;'+$nl+'        ComPtr<ID3D11RasterizerState> rasterizerDoubleSided;'
    if(-not$runtimeText.Contains($coreField)){throw 'Presentation native rasterizer field anchor missing.'}
    $runtimeText=$runtimeText.Replace($coreField,$coreFieldNew)

    $raster='        D3D11_RASTERIZER_DESC rd{};rd.FillMode=D3D11_FILL_SOLID;rd.CullMode=D3D11_CULL_BACK;rd.FrontCounterClockwise=TRUE;rd.DepthClipEnable=TRUE;rd.MultisampleEnable=FALSE;if(FAILED(hr=g_core.device->CreateRasterizerState(&rd,g_core.rasterizerSingleSided.GetAddressOf()))){g_core.initResult=hr;return hr;}rd.CullMode=D3D11_CULL_NONE;if(FAILED(hr=g_core.device->CreateRasterizerState(&rd,g_core.rasterizerDoubleSided.GetAddressOf()))){g_core.initResult=hr;return hr;}'
    $rasterNew='        D3D11_RASTERIZER_DESC rd{};rd.FillMode=D3D11_FILL_SOLID;rd.CullMode=D3D11_CULL_BACK;rd.FrontCounterClockwise=TRUE;rd.DepthClipEnable=TRUE;rd.MultisampleEnable=FALSE;if(FAILED(hr=g_core.device->CreateRasterizerState(&rd,g_core.rasterizerSingleSided.GetAddressOf()))){g_core.initResult=hr;return hr;}rd.FrontCounterClockwise=FALSE;if(FAILED(hr=g_core.device->CreateRasterizerState(&rd,g_core.rasterizerSingleSidedMirrored.GetAddressOf()))){g_core.initResult=hr;return hr;}rd.CullMode=D3D11_CULL_NONE;rd.FrontCounterClockwise=TRUE;if(FAILED(hr=g_core.device->CreateRasterizerState(&rd,g_core.rasterizerDoubleSided.GetAddressOf()))){g_core.initResult=hr;return hr;}'
    if(-not$runtimeText.Contains($raster)){throw 'Presentation native rasterizer creation anchor missing.'}
    $runtimeText=$runtimeText.Replace($raster,$rasterNew)

    $yaw='        const float yaw=24.0f+(item.spin?phase*16.0f:0.0f)+static_cast<float>((item.id*11)%360)+item.yawOffset;'
    if($runtimeText.Contains($yaw)){$runtimeText=$runtimeText.Replace($yaw,'        // HUYMAIER_V0304_MODEL_DEFAULT_ORIENTATION_V1'+$nl+'        // HUYMAIER_V0306_CONSOLE_PRESENTATION_NATIVE_V1'+$nl+'        const float yaw=24.0f+(item.spin?phase*16.0f*item.fanScale:0.0f)+item.yawOffset;')}
    elseif($runtimeText -notmatch 'HUYMAIER_V0304_MODEL_DEFAULT_ORIENTATION_V1'){throw 'Presentation native stable-yaw anchor missing.'}

    $world='        const float pitch=std::max(-80.0f,std::min(80.0f,item.pitch));'+$nl+'        XMMATRIX world=XMMatrixTranslation(-cx,-cy,-cz)*XMMatrixScaling(scale,scale,scale)*XMMatrixRotationX(XMConvertToRadians(pitch))*XMMatrixRotationY(XMConvertToRadians(yaw));XMMATRIX view=XMMatrixLookAtLH(XMVectorSet(0,.08f,-4.2f,1),XMVectorZero(),XMVectorSet(0,1,0,0));XMMATRIX proj=XMMatrixPerspectiveFovLH(XMConvertToRadians(34.0f),vp.Width/vp.Height,.01f,100.0f);XMMATRIX wvp=world*view*proj;'
    $worldNew='        const float pitch=std::max(-80.0f,std::min(80.0f,item.pitch));const float roll=item.roll;'+$nl+'        const bool mirrorParity=item.mirrorX^item.mirrorY^item.mirrorZ;const bool reverseFaces=(item.faceMode==1);const bool reversedCull=mirrorParity^reverseFaces;'+$nl+'        const float mx=item.mirrorX?-1.0f:1.0f,my=item.mirrorY?-1.0f:1.0f,mz=item.mirrorZ?-1.0f:1.0f;'+$nl+'        XMMATRIX world=XMMatrixTranslation(-cx,-cy,-cz)*XMMatrixScaling(scale*mx,scale*my,scale*mz)*XMMatrixRotationX(XMConvertToRadians(pitch))*XMMatrixRotationY(XMConvertToRadians(yaw))*XMMatrixRotationZ(XMConvertToRadians(roll))*XMMatrixTranslation(item.offsetX*.012f,-item.offsetY*.012f,0);XMMATRIX view=XMMatrixLookAtLH(XMVectorSet(0,.08f,-4.2f,1),XMVectorZero(),XMVectorSet(0,1,0,0));XMMATRIX proj=XMMatrixPerspectiveFovLH(XMConvertToRadians(34.0f),vp.Width/vp.Height,.01f,100.0f);XMMATRIX wvp=world*view*proj;'
    if(-not$runtimeText.Contains($world)){throw 'Presentation native world-transform anchor missing.'}
    $runtimeText=$runtimeText.Replace($world,$worldNew)

    $constants='c.extra=XMFLOAT4(d.alphaCutoff,item.selected?1.0f:0.0f,s.brightness,0);c.materialParams=XMFLOAT4(d.normalScale,d.occlusionStrength,0,0);'
    $constantsNew='c.extra=XMFLOAT4(d.alphaCutoff,item.selected?1.0f:0.0f,s.brightness*item.lightScale,mirrorParity?-1.0f:1.0f);c.materialParams=XMFLOAT4(d.normalScale,d.occlusionStrength,reverseFaces?-1.0f:1.0f,0);'
    if(-not$runtimeText.Contains($constants)){throw 'Presentation native lighting/parity constants anchor missing.'}
    $runtimeText=$runtimeText.Replace($constants,$constantsNew)

    $state='g_core.context->RSSetState((d.flags&1)?g_core.rasterizerDoubleSided.Get():g_core.rasterizerSingleSided.Get());'
    $stateNew='g_core.context->RSSetState(((d.flags&1)||item.faceMode==2)?g_core.rasterizerDoubleSided.Get():(reversedCull?g_core.rasterizerSingleSidedMirrored.Get():g_core.rasterizerSingleSided.Get()));'
    if(-not$runtimeText.Contains($state)){throw 'Presentation native face-mode anchor missing.'}
    $runtimeText=$runtimeText.Replace($state,$stateNew)

    $export='extern "C" __declspec(dllexport) int __cdecl HC_GPU_SetShelfItemView(void* handle,int id,float yawOffset,float pitch,int spin){if(!handle)return 0;std::lock_guard<std::mutex>guard(g_core.lock);ShelfSurface*s=static_cast<ShelfSurface*>(handle);auto it=s->items.find(id);if(it==s->items.end())return 0;Item&i=it->second;i.yawOffset=yawOffset;i.pitch=std::max(-80.0f,std::min(80.0f,pitch));i.spin=spin!=0;return 1;}'
    $exportNew=$export+$nl+'extern "C" __declspec(dllexport) int __cdecl HC_GPU_SetShelfItemPresentation(void* handle,int id,float yawOffset,float pitch,float roll,float offsetX,float offsetY,int mirrorX,int mirrorY,int mirrorZ,int faceMode,float lightScale,float fanScale,int spin){if(!handle)return 0;std::lock_guard<std::mutex>guard(g_core.lock);ShelfSurface*s=static_cast<ShelfSurface*>(handle);auto it=s->items.find(id);if(it==s->items.end())return 0;Item&i=it->second;i.yawOffset=yawOffset;i.pitch=std::max(-80.0f,std::min(80.0f,pitch));i.roll=roll;i.offsetX=std::max(-50.0f,std::min(50.0f,offsetX));i.offsetY=std::max(-50.0f,std::min(50.0f,offsetY));i.mirrorX=mirrorX!=0;i.mirrorY=mirrorY!=0;i.mirrorZ=mirrorZ!=0;i.faceMode=std::max(0,std::min(2,faceMode));i.lightScale=std::max(.20f,std::min(2.00f,lightScale));i.fanScale=std::max(0.0f,std::min(1.0f,fanScale));i.spin=spin!=0;return 1;}'
    if(-not$runtimeText.Contains($export)){throw 'Presentation native export anchor missing.'}
    $runtimeText=$runtimeText.Replace($export,$exportNew)
    Set-Content -LiteralPath $runtime -Value $runtimeText -Encoding UTF8
}

$assetText=Get-Content -Raw -LiteralPath $asset -Encoding UTF8
if($assetText -notmatch 'HUYMAIER_V0306_PRESENTATION_TANGENT_FACE_PARITY_V1'){
    $tangent='        o.t=float4(normalize(mul(float4(v.t.xyz,0),World).xyz),v.t.w);'
    $tangentNew='        // HUYMAIER_V0306_PRESENTATION_TANGENT_FACE_PARITY_V1'+$nl+'        float presentationTangentParity=(abs(Extra.w)<0.5)?1.0:Extra.w;'+$nl+'        o.t=float4(normalize(mul(float4(v.t.xyz,0),World).xyz),v.t.w*presentationTangentParity);'
    if(-not$assetText.Contains($tangent)){throw 'Presentation shader tangent anchor missing.'}
    $assetText=$assetText.Replace($tangent,$tangentNew)
    $normal='        float3 n=normalize(i.n);'
    $normalNew='        float3 n=normalize(i.n)*((MaterialParams.z<-.5)?-1.0:1.0);'
    if(-not$assetText.Contains($normal)){throw 'Presentation shader reverse-normal anchor missing.'}
    $assetText=$assetText.Replace($normal,$normalNew)
    Set-Content -LiteralPath $asset -Value $assetText -Encoding UTF8
}

Write-Host 'Applied v0.30.6 console-only full model presentation controls (transform, mirror, faces, light and fan); providers unchanged.'
