Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$utf8=New-Object Text.UTF8Encoding($false)
function ReadText([string]$p){([IO.File]::ReadAllText($p)).Replace("`r`n","`n")}
function WriteText([string]$p,[string]$s){[IO.File]::WriteAllText($p,$s.Replace("`r`n","`n"),$utf8)}
function ReplaceReq([string]$s,[string]$old,[string]$new,[string]$label){if($s.Contains($new)){return $s};if(-not$s.Contains($old)){throw "Patch anchor missing: $label"};$s.Replace($old,$new)}

# HC3D v2: winding is now normalized after negative-determinant glTF node
# transforms. Bump the cache version because index data changes.
$compilerPath=Join-Path $root 'Native\HuymaierGpuShelfAssetCompiler.cs'
$c=ReadText $compilerPath
$c=ReplaceReq $c 'public const int CacheVersion = 1;' 'public const int CacheVersion = 2;' 'HC3D cache version 2'
$normalAnchor=@'
        private static void TransformNormal(double[] m, double x, double y, double z, out double ox, out double oy, out double oz)
        {
            ox = m[0] * x + m[4] * y + m[8] * z;
            oy = m[1] * x + m[5] * y + m[9] * z;
            oz = m[2] * x + m[6] * y + m[10] * z;
            double len = Math.Sqrt(ox * ox + oy * oy + oz * oz);
            if (len > 0.0000001) { ox /= len; oy /= len; oz /= len; }
            else { ox = 0; oy = 1; oz = 0; }
        }
'@.Replace("`r`n","`n")
$normalNew=$normalAnchor+@'

        private static double Determinant3x3(double[] m)
        {
            return m[0] * (m[5] * m[10] - m[9] * m[6])
                 - m[4] * (m[1] * m[10] - m[9] * m[2])
                 + m[8] * (m[1] * m[6] - m[5] * m[2]);
        }
'@.Replace("`r`n","`n")
if(-not$c.Contains('private static double Determinant3x3')){$c=ReplaceReq $c $normalAnchor $normalNew 'mirrored transform determinant helper'}
$old=@'
                    int[] ix = ReadIndices(doc, JsonUtil.Int(primitive, "indices", -1), pos.Length);
                    DrawBatch batch = MaterialBatch(doc, materialIndex);
                    batch.FirstIndex = indices.Count; batch.IndexCount = ix.Length;
                    for (int i = 0; i < ix.Length; i++) indices.Add((uint)(baseVertex + ix[i]));
                    draws.Add(batch);
'@.Replace("`r`n","`n")
$new=@'
                    int[] ix = ReadIndices(doc, JsonUtil.Int(primitive, "indices", -1), pos.Length);
                    DrawBatch batch = MaterialBatch(doc, materialIndex);
                    batch.FirstIndex = indices.Count; batch.IndexCount = ix.Length;
                    bool mirrored = Determinant3x3(world) < -0.0000000001;
                    if (mirrored)
                    {
                        // glTF front faces are CCW. Baking a negative-determinant
                        // node transform into vertices reverses triangle winding;
                        // swap indices 1/2 so the authored front face stays front.
                        for (int i = 0; i + 2 < ix.Length; i += 3)
                        {
                            indices.Add((uint)(baseVertex + ix[i]));
                            indices.Add((uint)(baseVertex + ix[i + 2]));
                            indices.Add((uint)(baseVertex + ix[i + 1]));
                        }
                    }
                    else
                    {
                        for (int i = 0; i < ix.Length; i++) indices.Add((uint)(baseVertex + ix[i]));
                    }
                    draws.Add(batch);
'@.Replace("`r`n","`n")
$c=ReplaceReq $c $old $new 'mirrored transform winding normalization'
WriteText $compilerPath $c

$assetPath=Join-Path $root 'Native\HuymaierD3D11ShelfAsset.cpp'
$a=ReadText $assetPath
$a=ReplaceReq $a 'if (version != 1 || quality < 128 || quality > 2048 ||' 'if (version != 2 || quality < 128 || quality > 2048 ||' 'HC3D v2 asset loader'
WriteText $assetPath $a

# Native D3D11 shelf: honor single-vs-double-sided glTF materials and expose a
# per-surface brightness multiplier. Single-sided meshes no longer show their
# mirrored back faces (the Nintendo DS logo regression).
$runtimePath=Join-Path $root 'Native\HuymaierD3D11ShelfRuntime.cpp'
$r=ReadText $runtimePath
$r=ReplaceReq $r '        std::unordered_map<int, Item> items;' "        std::unordered_map<int, Item> items;`n        float brightness = 1.0f;" 'shelf brightness state'
$r=ReplaceReq $r '        ComPtr<ID3D11RasterizerState> rasterizer;' "        ComPtr<ID3D11RasterizerState> rasterizerSingleSided;`n        ComPtr<ID3D11RasterizerState> rasterizerDoubleSided;" 'dual rasterizer states'
$r=ReplaceReq $r '    return float4((lit + em + spec.xxx + selectedLift.xxx) * alpha, alpha);' '    float brightness = max(0.25, Extra.z);`n    return float4((lit + em + spec.xxx + selectedLift.xxx) * brightness * alpha, alpha);' 'shader brightness multiplier'
$old="        D3D11_RASTERIZER_DESC rd{};rd.FillMode=D3D11_FILL_SOLID;rd.CullMode=D3D11_CULL_NONE;rd.DepthClipEnable=TRUE;rd.MultisampleEnable=FALSE;`n        if (FAILED(hr=g_core.device->CreateRasterizerState(&rd,g_core.rasterizer.GetAddressOf()))) { g_core.initResult=hr; return hr; }"
$new="        D3D11_RASTERIZER_DESC rd{};rd.FillMode=D3D11_FILL_SOLID;rd.CullMode=D3D11_CULL_BACK;rd.FrontCounterClockwise=TRUE;rd.DepthClipEnable=TRUE;rd.MultisampleEnable=FALSE;`n        if (FAILED(hr=g_core.device->CreateRasterizerState(&rd,g_core.rasterizerSingleSided.GetAddressOf()))) { g_core.initResult=hr; return hr; }`n        rd.CullMode=D3D11_CULL_NONE;`n        if (FAILED(hr=g_core.device->CreateRasterizerState(&rd,g_core.rasterizerDoubleSided.GetAddressOf()))) { g_core.initResult=hr; return hr; }"
$r=ReplaceReq $r $old $new 'glTF single/double-sided rasterizers'
$r=ReplaceReq $r 'c.extra=XMFLOAT4(d.alphaCutoff,item.selected?1.0f:0.0f,0,0);c.flags=XMINT4' 'c.extra=XMFLOAT4(d.alphaCutoff,item.selected?1.0f:0.0f,s.brightness,0);c.flags=XMINT4' 'per-draw brightness constant'
$r=ReplaceReq $r '            D3D11_MAPPED_SUBRESOURCE mapped{};' "            g_core.context->RSSetState((d.flags&1)?g_core.rasterizerDoubleSided.Get():g_core.rasterizerSingleSided.Get());`n            D3D11_MAPPED_SUBRESOURCE mapped{};" 'per-material face culling'
$r=ReplaceReq $r 'g_core.context->PSSetConstantBuffers(0,1,&cb);g_core.context->RSSetState(g_core.rasterizer.Get());float blendFactor' 'g_core.context->PSSetConstantBuffers(0,1,&cb);float blendFactor' 'remove global cull-none state'
$setItem=@'
extern "C" __declspec(dllexport) int __cdecl HC_GPU_SetShelfItem(void* handle,int id,float x,float y,float width,float height,float scale,int selected,int visible)
{
    if(!handle||width<0||height<0)return 0;std::lock_guard<std::mutex>guard(g_core.lock);ShelfSurface*s=static_cast<ShelfSurface*>(handle);auto it=s->items.find(id);if(it==s->items.end())return 0;Item&i=it->second;i.x=x;i.y=y;i.width=width;i.height=height;i.modelScale=scale;i.selected=selected!=0;i.visible=visible!=0;return 1;
}
'@.Replace("`r`n","`n")
$setItemNew=$setItem+@'

extern "C" __declspec(dllexport) int __cdecl HC_GPU_SetShelfBrightness(void* handle,float brightness)
{
    if(!handle)return 0;std::lock_guard<std::mutex>guard(g_core.lock);ShelfSurface*s=static_cast<ShelfSurface*>(handle);s->brightness=std::max(0.50f,std::min(2.50f,brightness));return 1;
}
'@.Replace("`r`n","`n")
if(-not$r.Contains('HC_GPU_SetShelfBrightness')){$r=ReplaceReq $r $setItem $setItemNew 'native shelf brightness export'}
WriteText $runtimePath $r

# Managed D3DImage host persists brightness across surface recreation.
$hostPath=Join-Path $root 'Native\HuymaierD3D11ShelfHost.cs'
$h=ReadText $hostPath
$h=ReplaceReq $h '        internal static extern int HC_GPU_SetShelfItem(IntPtr handle, int id, float x, float y, float width, float height, float scale, int selected, int visible);' "        internal static extern int HC_GPU_SetShelfItem(IntPtr handle, int id, float x, float y, float width, float height, float scale, int selected, int visible);`n`n        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]`n        internal static extern int HC_GPU_SetShelfBrightness(IntPtr handle, float brightness);" 'managed brightness import'
$h=ReplaceReq $h '        private double dpiScaleY = 1.0;' "        private double dpiScaleY = 1.0;`n        private double brightnessPercent = 135.0;" 'managed brightness state'
$clearAnchor=@'
        public void ClearModels()
        {
            modelPaths.Clear();
            itemStates.Clear();
            if (!NativeReady) return;
            try { D3D11ShelfNative.HC_GPU_ClearShelfItems(nativeHandle); } catch { }
        }
'@.Replace("`r`n","`n")
$clearNew=$clearAnchor+@'

        public void SetBrightnessPercent(double percent)
        {
            brightnessPercent = Math.Max(50.0, Math.Min(250.0, percent));
            if (!NativeReady) return;
            try { D3D11ShelfNative.HC_GPU_SetShelfBrightness(nativeHandle, (float)(brightnessPercent / 100.0)); } catch { }
        }
'@.Replace("`r`n","`n")
if(-not$h.Contains('public void SetBrightnessPercent')){$h=ReplaceReq $h $clearAnchor $clearNew 'managed SetBrightnessPercent'}
$h=ReplaceReq $h '            ReplayState();' "            try { D3D11ShelfNative.HC_GPU_SetShelfBrightness(nativeHandle, (float)(brightnessPercent / 100.0)); } catch { }`n            ReplayState();" 'brightness replay on surface recreation'
WriteText $hostPath $h

# Settings share one brightness value between shelf renderer and full model viewer.
$userPath=Join-Path $root 'HuymaierUser3DModels.ps1'
$u=ReadText $userPath
$u=ReplaceReq $u "    if(`$null -eq `$script:Config.PSObject.Properties['PlatformModelScale']){`$script:Config|Add-Member PlatformModelScale 100 -Force}" "    if(`$null -eq `$script:Config.PSObject.Properties['PlatformModelScale']){`$script:Config|Add-Member PlatformModelScale 100 -Force}`n    if(`$null -eq `$script:Config.PSObject.Properties['PlatformModelBrightness']){`$script:Config|Add-Member PlatformModelBrightness 135 -Force}" 'model brightness config default'
$u=ReplaceReq $u '    try{$script:Config.PlatformModelScale=[math]::Max(50,[math]::Min(200,[int]$script:Config.PlatformModelScale))}catch{$script:Config.PlatformModelScale=100}' "    try{`$script:Config.PlatformModelScale=[math]::Max(50,[math]::Min(200,[int]`$script:Config.PlatformModelScale))}catch{`$script:Config.PlatformModelScale=100}`n    try{`$script:Config.PlatformModelBrightness=[math]::Max(50,[math]::Min(250,[int]`$script:Config.PlatformModelBrightness))}catch{`$script:Config.PlatformModelBrightness=135}" 'model brightness config clamp'
$u=$u.Replace("'platform-model-scale-slider','open-3d-models-folder'","'platform-model-scale-slider','platform-model-brightness-slider','open-3d-models-folder'")
$slider="[void]`$result.Add((New-SliderAction 'platform-model-scale-slider' '3D shelf model size' ([int]`$script:Config.PlatformModelScale) 'Adjust rotation-safe camera framing for the compact 3D shelf models. Models remain inside their viewports while rotating.' 50 200));"
$brightness="$slider[void]`$result.Add((New-SliderAction 'platform-model-brightness-slider' '3D model brightness' ([int]`$script:Config.PlatformModelBrightness) 'Adjust lighting for both the Games 3D shelves and the full-screen model viewer.' 50 250));"
$u=$u.Replace($slider,$brightness)
$case="'platform-model-scale-slider'{`$value=[math]::Max(50,[math]::Min(200,([int]`$script:Config.PlatformModelScale)+`$Delta));`$script:Config.PlatformModelScale=`$value}"
$caseNew="$case'platform-model-brightness-slider'{`$value=[math]::Max(50,[math]::Min(250,([int]`$script:Config.PlatformModelBrightness)+`$Delta));`$script:Config.PlatformModelBrightness=`$value;if((Get-Command Update-HcGpuShelfBrightness -ErrorAction SilentlyContinue)){Update-HcGpuShelfBrightness}}"
$u=$u.Replace($case,$caseNew)
if(-not$u.Contains('PlatformModelBrightness')){throw 'Model brightness settings patch failed.'}
WriteText $userPath $u

# V7 applies the setting immediately to every native surface and HC3D v2 invalidates
# old caches once, preventing pre-winding-fix cache reuse.
$v7Path=Join-Path $root 'HuymaierGpuPlatformShelves.ps1'
$v=ReadText $v7Path
$v=ReplaceReq $v 'if($reader.ReadInt32()-ne1){return $false}' 'if($reader.ReadInt32()-ne2){return $false}' 'V7 HC3D v2 cache freshness'
$groupAnchor="    `$surface=`$null;if(Initialize-HcGpuShelfRuntime){try{`$surface=New-Object HuymaierConsole.Modeling.D3D11ShelfSurface;`$surface.HorizontalAlignment='Stretch';`$surface.VerticalAlignment='Stretch';`$container.Children.Add(`$surface)|Out-Null}catch{try{Write-Log ('GPU shelf surface creation failed: '+`$_.Exception.Message) 'WARN'}catch{}}}"
$groupNew="    `$surface=`$null;if(Initialize-HcGpuShelfRuntime){try{`$surface=New-Object HuymaierConsole.Modeling.D3D11ShelfSurface;`$surface.HorizontalAlignment='Stretch';`$surface.VerticalAlignment='Stretch';if(`$surface.PSObject.Methods['SetBrightnessPercent']){`$surface.SetBrightnessPercent([double]`$script:Config.PlatformModelBrightness)};`$container.Children.Add(`$surface)|Out-Null}catch{try{Write-Log ('GPU shelf surface creation failed: '+`$_.Exception.Message) 'WARN'}catch{}}}"
$v=ReplaceReq $v $groupAnchor $groupNew 'V7 surface brightness initialization'
$layoutAnchor='function Update-HcGpuShelfLayout {'
$brightnessFn=@'
function Update-HcGpuShelfBrightness {
    foreach($key in @('Providers','Consoles')){
        $group=Get-HcGpuShelfGroup $key
        if($group-and$group.Surface-and$group.Surface.PSObject.Methods['SetBrightnessPercent']){try{$group.Surface.SetBrightnessPercent([double]$script:Config.PlatformModelBrightness)}catch{}}
    }
}

function Update-HcGpuShelfLayout {
'@.Replace("`r`n","`n")
if(-not$v.Contains('function Update-HcGpuShelfBrightness')){$v=ReplaceReq $v $layoutAnchor $brightnessFn 'V7 brightness update helper'}
WriteText $v7Path $v

# Full WPF viewer uses authored glTF V coordinates, matching the now-correct D3D
# shelf. Do not vertically invert a second time.
$viewerPath=Join-Path $root 'Native\HuymaierModelPreviewWorker.cs'
$w=ReadText $viewerPath
$w=ReplaceReq $w 'if (binding == null) return new Point(u, 1.0 - v);' 'if (binding == null) return new Point(u, v);' 'full viewer raw UV orientation'
$w=ReplaceReq $w 'return new Point(su, 1.0 - sv);' 'return new Point(su, sv);' 'full viewer transformed UV orientation'
WriteText $viewerPath $w

# LiveModelView exposes the shared brightness control by scaling the authored light
# rig and adding a neutral ambient boost above 100%.
$controlPath=Join-Path $root 'Native\HuymaierLiveModelControl.cs'
$l=ReadText $controlPath
$l=ReplaceReq $l '        private readonly double normalizedScale;`n        private double zoomDistance;' "        private readonly double normalizedScale;`n        private readonly AmbientLight ambientLight;`n        private readonly DirectionalLight keyLight;`n        private readonly DirectionalLight fillLight;`n        private readonly DirectionalLight rimLight;`n        private readonly AmbientLight brightnessLight;`n        private double zoomDistance;`n        public double BrightnessPercent { get; private set; }" 'LiveModelView brightness fields'
$old=@'
            Model3DGroup lights = new Model3DGroup();
            lights.Children.Add(new AmbientLight(Color.FromRgb(128, 133, 145)));
            lights.Children.Add(new DirectionalLight(Color.FromRgb(255, 252, 242), new Vector3D(-0.6, -0.8, -1.7)));
            lights.Children.Add(new DirectionalLight(Color.FromRgb(145, 177, 220), new Vector3D(1.0, 0.35, -0.8)));
            lights.Children.Add(new DirectionalLight(Color.FromRgb(218, 184, 104), new Vector3D(0.25, 0.8, 0.65)));
            ModelVisual3D lightVisual = new ModelVisual3D();
            lightVisual.Content = lights;
'@.Replace("`r`n","`n")
$new=@'
            Model3DGroup lights = new Model3DGroup();
            ambientLight = new AmbientLight(Color.FromRgb(128, 133, 145));
            keyLight = new DirectionalLight(Color.FromRgb(255, 252, 242), new Vector3D(-0.6, -0.8, -1.7));
            fillLight = new DirectionalLight(Color.FromRgb(145, 177, 220), new Vector3D(1.0, 0.35, -0.8));
            rimLight = new DirectionalLight(Color.FromRgb(218, 184, 104), new Vector3D(0.25, 0.8, 0.65));
            brightnessLight = new AmbientLight(Color.FromRgb(0, 0, 0));
            lights.Children.Add(ambientLight);
            lights.Children.Add(keyLight);
            lights.Children.Add(fillLight);
            lights.Children.Add(rimLight);
            lights.Children.Add(brightnessLight);
            SetBrightnessPercent(100.0);
            ModelVisual3D lightVisual = new ModelVisual3D();
            lightVisual.Content = lights;
'@.Replace("`r`n","`n")
$l=ReplaceReq $l $old $new 'LiveModelView adjustable light rig'
$scaleAnchor=@'
        public void SetScalePercent(double percent)
        {
            double factor = Math.Max(0.40, Math.Min(2.20, percent / 100.0));
            double value = normalizedScale * factor;
            scaleTransform.ScaleX = value;
            scaleTransform.ScaleY = value;
            scaleTransform.ScaleZ = value;
        }
'@.Replace("`r`n","`n")
$scaleNew=$scaleAnchor+@'

        private static Color ScaleLight(Color source, double factor)
        {
            factor = Math.Max(0.0, Math.Min(1.0, factor));
            return Color.FromRgb((byte)Math.Round(source.R * factor),(byte)Math.Round(source.G * factor),(byte)Math.Round(source.B * factor));
        }

        public void SetBrightnessPercent(double percent)
        {
            BrightnessPercent = Math.Max(50.0, Math.Min(250.0, percent));
            double factor = BrightnessPercent / 100.0;
            double baseScale = Math.Min(1.0, factor);
            ambientLight.Color = ScaleLight(Color.FromRgb(128,133,145), baseScale);
            keyLight.Color = ScaleLight(Color.FromRgb(255,252,242), baseScale);
            fillLight.Color = ScaleLight(Color.FromRgb(145,177,220), baseScale);
            rimLight.Color = ScaleLight(Color.FromRgb(218,184,104), baseScale);
            int boost = factor > 1.0 ? (int)Math.Round(Math.Min(175.0, (factor - 1.0) * 115.0)) : 0;
            brightnessLight.Color = Color.FromRgb((byte)boost,(byte)boost,(byte)boost);
        }
'@.Replace("`r`n","`n")
if(-not$l.Contains('public void SetBrightnessPercent')){$l=ReplaceReq $l $scaleAnchor $scaleNew 'LiveModelView brightness method'}
WriteText $controlPath $l

$livePs=Join-Path $root 'HuymaierLivePlatformModels.ps1'
$lp=ReadText $livePs
$lp=ReplaceReq $lp '        $view.SetScalePercent([double]$ScalePercent)`n        return $view' "        `$view.SetScalePercent([double]`$ScalePercent)`n        try{if(`$view.PSObject.Methods['SetBrightnessPercent']){`$view.SetBrightnessPercent([double]`$script:Config.PlatformModelBrightness)}}catch{}`n        return `$view" 'full viewer shared brightness setting'
WriteText $livePs $lp

Write-Host 'modelRenderingPatchGate: success'
