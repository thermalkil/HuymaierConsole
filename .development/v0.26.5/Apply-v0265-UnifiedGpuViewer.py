from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]

def patch(rel, old, new, count=1):
    p=ROOT/rel
    text=p.read_text(encoding='utf-8-sig')
    n=text.count(old)
    if n!=count:
        raise RuntimeError(f'{rel}: expected {count} occurrence(s), got {n}: {old[:120]!r}')
    p.write_text(text.replace(old,new,count),encoding='utf-8')

# Native surface: add per-item view state while preserving existing shelf defaults.
rel=Path('Native/HuymaierD3D11ShelfRuntime.cpp')
patch(rel,
'''        float modelScale = 0.70f;\n        bool selected = false;\n        bool visible = false;\n''',
'''        float modelScale = 0.70f;\n        float yawOffset = 0.0f;\n        float pitch = -10.0f;\n        bool spin = true;\n        bool selected = false;\n        bool visible = false;\n''')
patch(rel,
'''        const float scale=(2.60f/diameter)*std::max(.45f,std::min(.82f,item.modelScale))*(item.selected?1.04f:1.0f);const float yaw=24.0f+phase*16.0f+static_cast<float>((item.id*11)%360);\n        XMMATRIX world=XMMatrixTranslation(-cx,-cy,-cz)*XMMatrixScaling(scale,scale,scale)*XMMatrixRotationX(XMConvertToRadians(-10.0f))*XMMatrixRotationY(XMConvertToRadians(yaw));''',
'''        const float scale=(2.60f/diameter)*std::max(.45f,std::min(.90f,item.modelScale))*(item.selected?1.04f:1.0f);\n        const float yaw=24.0f+(item.spin?phase*16.0f:0.0f)+static_cast<float>((item.id*11)%360)+item.yawOffset;\n        const float pitch=std::max(-80.0f,std::min(80.0f,item.pitch));\n        XMMATRIX world=XMMatrixTranslation(-cx,-cy,-cz)*XMMatrixScaling(scale,scale,scale)*XMMatrixRotationX(XMConvertToRadians(pitch))*XMMatrixRotationY(XMConvertToRadians(yaw));''')
patch(rel,
'''extern "C" __declspec(dllexport) int __cdecl HC_GPU_SetShelfBrightness(void* handle,float brightness){if(!handle)return 0;std::lock_guard<std::mutex>guard(g_core.lock);ShelfSurface*s=static_cast<ShelfSurface*>(handle);s->brightness=std::max(0.50f,std::min(2.50f,brightness));return 1;}\n''',
'''extern "C" __declspec(dllexport) int __cdecl HC_GPU_SetShelfItemView(void* handle,int id,float yawOffset,float pitch,int spin){if(!handle)return 0;std::lock_guard<std::mutex>guard(g_core.lock);ShelfSurface*s=static_cast<ShelfSurface*>(handle);auto it=s->items.find(id);if(it==s->items.end())return 0;Item&i=it->second;i.yawOffset=yawOffset;i.pitch=std::max(-80.0f,std::min(80.0f,pitch));i.spin=spin!=0;return 1;}\nextern "C" __declspec(dllexport) int __cdecl HC_GPU_SetShelfBrightness(void* handle,float brightness){if(!handle)return 0;std::lock_guard<std::mutex>guard(g_core.lock);ShelfSurface*s=static_cast<ShelfSurface*>(handle);s->brightness=std::max(0.50f,std::min(2.50f,brightness));return 1;}\n''')

# Managed D3DImage host: persist view state through DPI/surface recreation.
rel=Path('Native/HuymaierD3D11ShelfHost.cs')
patch(rel,
'''        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]\n        internal static extern int HC_GPU_SetShelfBrightness(IntPtr handle, float brightness);\n''',
'''        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]\n        internal static extern int HC_GPU_SetShelfItemView(IntPtr handle, int id, float yawOffset, float pitch, int spin);\n\n        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]\n        internal static extern int HC_GPU_SetShelfBrightness(IntPtr handle, float brightness);\n''')
patch(rel,
'''        private sealed class ItemState\n        {\n            public float X, Y, Width, Height, Scale;\n            public bool Selected, Visible;\n        }\n''',
'''        private sealed class ItemState\n        {\n            public float X, Y, Width, Height, Scale;\n            public float YawOffset = 0.0f;\n            public float Pitch = -10.0f;\n            public bool Spin = true;\n            public bool Selected, Visible;\n        }\n''')
patch(rel,
'''                return D3D11ShelfNative.HC_GPU_SetShelfItem(\n                    nativeHandle, id,\n                    state.X * (float)dpiScaleX, state.Y * (float)dpiScaleY,\n                    state.Width * (float)dpiScaleX, state.Height * (float)dpiScaleY,\n                    state.Scale, state.Selected ? 1 : 0, state.Visible ? 1 : 0) != 0;\n''',
'''                bool layoutOk = D3D11ShelfNative.HC_GPU_SetShelfItem(\n                    nativeHandle, id,\n                    state.X * (float)dpiScaleX, state.Y * (float)dpiScaleY,\n                    state.Width * (float)dpiScaleX, state.Height * (float)dpiScaleY,\n                    state.Scale, state.Selected ? 1 : 0, state.Visible ? 1 : 0) != 0;\n                bool viewOk = D3D11ShelfNative.HC_GPU_SetShelfItemView(nativeHandle, id, state.YawOffset, state.Pitch, state.Spin ? 1 : 0) != 0;\n                return layoutOk && viewOk;\n''')
patch(rel,
'''            ItemState state = new ItemState\n            {\n                X = (float)x,\n                Y = (float)y,\n                Width = Math.Max(0, (float)width),\n                Height = Math.Max(0, (float)height),\n                Scale = Math.Max(.40f, Math.Min(.90f, (float)scale)),\n                Selected = selected,\n                Visible = visible\n            };\n            itemStates[id] = state;\n            return ApplyItemToNative(id, state);\n        }\n\n        public void ClearModels()\n''',
'''            ItemState state;\n            if (!itemStates.TryGetValue(id, out state) || state == null) state = new ItemState();\n            state.X = (float)x;\n            state.Y = (float)y;\n            state.Width = Math.Max(0, (float)width);\n            state.Height = Math.Max(0, (float)height);\n            state.Scale = Math.Max(.40f, Math.Min(.90f, (float)scale));\n            state.Selected = selected;\n            state.Visible = visible;\n            itemStates[id] = state;\n            return ApplyItemToNative(id, state);\n        }\n\n        public bool SetItemView(int id, double yawOffset, double pitch, bool spin)\n        {\n            if (disposed || id < 0) return false;\n            ItemState state;\n            if (!itemStates.TryGetValue(id, out state) || state == null)\n            {\n                state = new ItemState { Width = 1.0f, Height = 1.0f, Scale = .82f, Visible = true };\n            }\n            state.YawOffset = (float)yawOffset;\n            state.Pitch = Math.Max(-80.0f, Math.Min(80.0f, (float)pitch));\n            state.Spin = spin;\n            itemStates[id] = state;\n            if (!NativeReady) return true;\n            try { return D3D11ShelfNative.HC_GPU_SetShelfItemView(nativeHandle, id, state.YawOffset, state.Pitch, state.Spin ? 1 : 0) != 0; }\n            catch { return false; }\n        }\n\n        public void ClearModels()\n''')

# Full-screen viewer now owns only UI/controller chrome. Actual model pixels come
# from the exact same HC3D v3 + D3D11 shelf surface used on the Games page.
rel=Path('HuymaierLivePlatformModels.ps1')
p=ROOT/rel
text=p.read_text(encoding='utf-8-sig')
text=text.replace('# HUYMAIER_CONTEXT_AWARE_MODEL_VIEWER_V1','# HUYMAIER_CONTEXT_AWARE_MODEL_VIEWER_V2\n# HUYMAIER_SHARED_D3D11_MODEL_VIEWER_V1',1)
# state
old="$script:HcModelViewerView=$null\n$script:HcModelViewerActive=$false\n$script:HcModelViewerPlatform=''\n"
new="$script:HcModelViewerView=$null\n$script:HcModelViewerStage=$null\n$script:HcModelViewerActive=$false\n$script:HcModelViewerPlatform=''\n$script:HcModelViewerYaw=0.0\n$script:HcModelViewerPitch=-10.0\n$script:HcModelViewerScale=0.82\n$script:HcModelViewerSpin=$true\n"
if text.count(old)!=1: raise RuntimeError('viewer state anchor mismatch')
text=text.replace(old,new,1)
# close dispose
old="""    $script:HcModelViewerOverlay=$null\n    $script:HcModelViewerView=$null\n    $script:HcModelViewerPlatform=''\n"""
new="""    try{if($script:HcModelViewerView -and $script:HcModelViewerView.PSObject.Methods['Dispose']){$script:HcModelViewerView.Dispose()}}catch{}\n    $script:HcModelViewerOverlay=$null\n    $script:HcModelViewerView=$null\n    $script:HcModelViewerStage=$null\n    $script:HcModelViewerPlatform=''\n    $script:HcModelViewerYaw=0.0;$script:HcModelViewerPitch=-10.0;$script:HcModelViewerScale=0.82;$script:HcModelViewerSpin=$true\n"""
if text.count(old)!=1: raise RuntimeError('viewer close anchor mismatch')
text=text.replace(old,new,1)
# insert helper before Open
open_anchor='function Open-HcPlatformModelViewer {\n'
if text.count(open_anchor)!=1: raise RuntimeError('viewer open anchor mismatch')
helpers=r'''function Get-HcModelViewerGpuCache {
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

'''
text=text.replace(open_anchor,helpers+open_anchor,1)
# replace initial WPF view creation
old="""    $view=New-HcLiveModelView $path 115\n    if($null -eq $view){return $false}\n    $root=$script:Window.Content\n"""
new="""    $cache=Get-HcModelViewerGpuCache $path\n    if([string]::IsNullOrWhiteSpace($cache)){return $false}\n    $gpuType=Get-HcGpuShelfHostType\n    if($null-eq$gpuType){return $false}\n    try{$view=New-Object $gpuType.FullName}catch{try{$view=[Activator]::CreateInstance($gpuType)}catch{return $false}}\n    try{$view.SetBrightnessPercent([double]$script:Config.PlatformModelBrightness)}catch{}\n    try{if(-not$view.LoadModel(0,$cache)){try{$view.Dispose()}catch{};return $false}}catch{try{$view.Dispose()}catch{};return $false}\n    $root=$script:Window.Content\n"""
if text.count(old)!=1: raise RuntimeError('viewer WPF creation anchor mismatch')
text=text.replace(old,new,1)
# stage child and state set/hook
old="""    [System.Windows.Controls.Grid]::SetRow($stage,1);$stage.Child=$view;[void]$overlay.Children.Add($stage)\n\n    $hint=New-Object System.Windows.Controls.TextBlock\n"""
new="""    [System.Windows.Controls.Grid]::SetRow($stage,1);$stage.Child=$view;[void]$overlay.Children.Add($stage)\n    $stage.Add_SizeChanged({try{Update-HcGpuModelViewerItem}catch{}})\n\n    $hint=New-Object System.Windows.Controls.TextBlock\n"""
if text.count(old)!=1: raise RuntimeError('viewer stage anchor mismatch')
text=text.replace(old,new,1)
old="""    $overlay.Add_MouseWheel({param($sender,$eventArgs)try{if($script:HcModelViewerView){$script:HcModelViewerView.Zoom($(if($eventArgs.Delta-gt0){0.25}else{-0.25}));$eventArgs.Handled=$true}}catch{}})\n    [void]$root.Children.Add($overlay)\n    $script:HcModelViewerOverlay=$overlay;$script:HcModelViewerView=$view;$script:HcModelViewerPlatform=$Platform;$script:HcModelViewerActive=$true\n"""
new="""    $overlay.Add_MouseWheel({param($sender,$eventArgs)try{if($script:HcModelViewerView){$delta=$(if($eventArgs.Delta-gt0){.05}else{-.05});$script:HcModelViewerScale=[math]::Max(.45,[math]::Min(.90,$script:HcModelViewerScale+$delta));Update-HcGpuModelViewerItem;$eventArgs.Handled=$true}}catch{}})\n    [void]$root.Children.Add($overlay)\n    $script:HcModelViewerOverlay=$overlay;$script:HcModelViewerView=$view;$script:HcModelViewerStage=$stage;$script:HcModelViewerPlatform=$Platform;$script:HcModelViewerActive=$true\n    $script:HcModelViewerYaw=0.0;$script:HcModelViewerPitch=-10.0;$script:HcModelViewerScale=.82;$script:HcModelViewerSpin=$true\n    Update-HcGpuModelViewerItem\n"""
if text.count(old)!=1: raise RuntimeError('viewer activation anchor mismatch')
text=text.replace(old,new,1)
# controller block replace rotation/zoom/reset calls
old="""            try{switch($Direction){'Left'{$script:HcModelViewerView.Rotate(-6,0)}'Right'{$script:HcModelViewerView.Rotate(6,0)}'Up'{$script:HcModelViewerView.Rotate(0,-5)}'Down'{$script:HcModelViewerView.Rotate(0,5)}}}catch{}\n"""
new="""            try{switch($Direction){'Left'{$script:HcModelViewerYaw-=6}'Right'{$script:HcModelViewerYaw+=6}'Up'{$script:HcModelViewerPitch=[math]::Max(-80,$script:HcModelViewerPitch-5)}'Down'{$script:HcModelViewerPitch=[math]::Min(80,$script:HcModelViewerPitch+5)}};$script:HcModelViewerSpin=$false;Update-HcGpuModelViewerItem}catch{}\n"""
if text.count(old)!=1: raise RuntimeError('viewer rotate anchor mismatch')
text=text.replace(old,new,1)
old="""    if(Is-NewButtonPress $Mask 4){try{$script:HcModelViewerView.ResetView()}catch{}}\n    if(Is-NewButtonPress $Mask 8){Close-HcPlatformModelViewer;$script:LastGamepadMask=$Mask;return}\n    if(Is-NewButtonPress $Mask 1024){try{$script:HcModelViewerView.Zoom(0.35)}catch{}}\n    if(Is-NewButtonPress $Mask 2048){try{$script:HcModelViewerView.Zoom(-0.35)}catch{}}\n"""
new="""    if(Is-NewButtonPress $Mask 4){$script:HcModelViewerYaw=0.0;$script:HcModelViewerPitch=-10.0;$script:HcModelViewerScale=.82;$script:HcModelViewerSpin=$true;Update-HcGpuModelViewerItem}\n    if(Is-NewButtonPress $Mask 8){Close-HcPlatformModelViewer;$script:LastGamepadMask=$Mask;return}\n    if(Is-NewButtonPress $Mask 1024){$script:HcModelViewerScale=[math]::Min(.90,$script:HcModelViewerScale+.05);Update-HcGpuModelViewerItem}\n    if(Is-NewButtonPress $Mask 2048){$script:HcModelViewerScale=[math]::Max(.45,$script:HcModelViewerScale-.05);Update-HcGpuModelViewerItem}\n"""
if text.count(old)!=1: raise RuntimeError('viewer reset zoom anchor mismatch')
text=text.replace(old,new,1)
p.write_text(text,encoding='utf-8')

print('unifiedGpuViewerPatchApplied: success')
