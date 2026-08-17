using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Interop;
using System.Windows.Media;

namespace HuymaierConsole.Modeling
{
    // HUYMAIER_D3D11_SHELF_HOST_V3_BOUNDED_FAN_MOTION
    // HUYMAIER_D3D11_DPI_AWARE_SHELF_V1
    // HUYMAIER_V0306_CONSOLE_PRESENTATION_NATIVE_BRIDGE_V1
    // HUYMAIER_V0307_CONSOLE_STUDIO_LIGHT_NATIVE_BRIDGE_V1
    // HUYMAIER_V0307_CONSOLE_STUDIO_LIGHT_ADVANCED_NATIVE_BRIDGE_V1
    // HUYMAIER_V0306_CONSOLE_MODEL_SCALE_CAPACITY_V1
    // WPF owns navigation and chrome. The persistent shelf surface, asset cache,
    // bounded presentation animation and model rendering are owned by native D3D11.
    internal static class D3D11ShelfNative
    {
        private const string DllName = "HuymaierD3D11ShelfRenderer.dll";

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        internal static extern int HC_D3D11SmokeTest();

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Unicode)]
        internal static extern IntPtr HC_GPU_CreateShelfSurface(int width, int height, out IntPtr surface9);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Unicode)]
        internal static extern int HC_GPU_LoadShelfModel(IntPtr handle, int id, string cachePath);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        internal static extern int HC_GPU_SetShelfItem(IntPtr handle, int id, float x, float y, float width, float height, float scale, int selected, int visible);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        internal static extern int HC_GPU_SetShelfItemView(IntPtr handle, int id, float yawOffset, float pitch, int spin);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        internal static extern int HC_GPU_SetShelfItemPresentation(IntPtr handle, int id, float yawOffset, float pitch, float roll, float offsetX, float offsetY, int mirrorX, int mirrorY, int mirrorZ, int faceMode, float lightScale, float fanScale, int spin);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        internal static extern int HC_GPU_SetShelfItemStudioLight(IntPtr handle, int id, float keyLightScale, float azimuth, float elevation, float distance, float aimX, float aimY, float coneDegrees, float coneSoftness, float falloffScale, float temperatureKelvin, float ambientScale, float specularScale, float highlightScale);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        internal static extern int HC_GPU_SetShelfBrightness(IntPtr handle, float brightness);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        internal static extern void HC_GPU_ClearShelfItems(IntPtr handle);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        internal static extern int HC_GPU_RenderShelfSurface(IntPtr handle, float phase);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        internal static extern void HC_GPU_ReleaseShelfSurfacePointer(IntPtr surface9);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        internal static extern void HC_GPU_DestroyShelfSurface(IntPtr handle);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        internal static extern int HC_GPU_GetCachedAssetCount();
    }

    public sealed class D3D11ShelfSurface : Grid, IDisposable
    {
        private sealed class ItemState
        {
            public float X, Y, Width, Height, Scale;
            public float YawOffset = 0.0f;
            public float Pitch = -10.0f;
            public float Roll = 0.0f;
            public float OffsetX = 0.0f, OffsetY = 0.0f;
            public bool MirrorX, MirrorY, MirrorZ;
            public int FaceMode = 0;
            public float LightScale = 1.0f;
            public float KeyLightScale = 1.0f;
            public float LightAzimuth = -36.0f, LightElevation = 43.0f, LightTemperature = 6500.0f;
            public float LightDistance = 8.0f, LightAimX = 0.0f, LightAimY = 0.0f;
            public float ConeDegrees = 180.0f, ConeSoftness = 0.5f, FalloffScale = 0.0f;
            public float AmbientScale = 1.0f, SpecularScale = 1.0f, HighlightScale = 1.0f;
            public bool StudioLightOverride = false;
            public float FanScale = 1.0f;
            public bool Spin = true;
            public bool Selected, Visible;
        }

        private readonly Image image;
        private readonly D3DImage source;
        private readonly Dictionary<int, string> modelPaths = new Dictionary<int, string>();
        private readonly Dictionary<int, ItemState> itemStates = new Dictionary<int, ItemState>();
        private readonly Stopwatch renderClock = Stopwatch.StartNew();
        private IntPtr nativeHandle;
        private IntPtr nativeSurface;
        private int pixelWidth;
        private int pixelHeight;
        private bool rendering;
        private bool disposed;
        private double dpiScaleX = 1.0;
        private double dpiScaleY = 1.0;
        private double brightnessPercent = 135.0;

        // One complete center -> left -> center -> right -> center presentation
        // sweep takes eight seconds. Native rendering still owns the actual yaw;
        // supplying a bounded phase keeps its existing framing/material path while
        // preventing continuous 360-degree turntable rotation.
        private const double FanPeriodSeconds = 8.0;
        private const float FanPhaseAmplitude = 0.75f;

        public bool NativeReady { get { return nativeHandle != IntPtr.Zero && nativeSurface != IntPtr.Zero; } }
        public int PixelWidth { get { return pixelWidth; } }
        public int PixelHeight { get { return pixelHeight; } }
        public int LoadedModelCount { get { return modelPaths.Count; } }
        public static int NativeCachedAssetCount { get { try { return D3D11ShelfNative.HC_GPU_GetCachedAssetCount(); } catch { return 0; } } }

        public static int RunNativeSmokeTest()
        {
            return D3D11ShelfNative.HC_D3D11SmokeTest();
        }

        private bool RefreshDpiScale()
        {
            DpiScale dpi = VisualTreeHelper.GetDpi(this);
            double x = dpi.DpiScaleX > 0.0 ? dpi.DpiScaleX : 1.0;
            double y = dpi.DpiScaleY > 0.0 ? dpi.DpiScaleY : 1.0;
            bool changed = Math.Abs(x - dpiScaleX) > 0.0001 || Math.Abs(y - dpiScaleY) > 0.0001;
            dpiScaleX = x;
            dpiScaleY = y;
            return changed;
        }

        private int PixelWidthFor(double logicalWidth)
        {
            return Math.Max(1, (int)Math.Ceiling(Math.Max(0.0, logicalWidth) * dpiScaleX));
        }

        private int PixelHeightFor(double logicalHeight)
        {
            return Math.Max(1, (int)Math.Ceiling(Math.Max(0.0, logicalHeight) * dpiScaleY));
        }

        private bool ApplyItemToNative(int id, ItemState state)
        {
            if (!NativeReady || state == null) return true;
            try
            {
                bool layoutOk = D3D11ShelfNative.HC_GPU_SetShelfItem(
                    nativeHandle, id,
                    state.X * (float)dpiScaleX, state.Y * (float)dpiScaleY,
                    state.Width * (float)dpiScaleX, state.Height * (float)dpiScaleY,
                    state.Scale, state.Selected ? 1 : 0, state.Visible ? 1 : 0) != 0;
                bool viewOk = D3D11ShelfNative.HC_GPU_SetShelfItemPresentation(nativeHandle, id, state.YawOffset, state.Pitch, state.Roll, state.OffsetX, state.OffsetY, state.MirrorX ? 1 : 0, state.MirrorY ? 1 : 0, state.MirrorZ ? 1 : 0, state.FaceMode, state.LightScale, state.FanScale, state.Spin ? 1 : 0) != 0;
                bool studioOk = !state.StudioLightOverride || D3D11ShelfNative.HC_GPU_SetShelfItemStudioLight(nativeHandle, id, state.KeyLightScale, state.LightAzimuth, state.LightElevation, state.LightDistance, state.LightAimX, state.LightAimY, state.ConeDegrees, state.ConeSoftness, state.FalloffScale, state.LightTemperature, state.AmbientScale, state.SpecularScale, state.HighlightScale) != 0;
                return layoutOk && viewOk && studioOk;
            }
            catch { return false; }
        }

        public D3D11ShelfSurface()
        {
            ClipToBounds = true;
            Background = Brushes.Transparent;
            IsHitTestVisible = false;

            source = new D3DImage();
            image = new Image();
            image.Source = source;
            image.Stretch = Stretch.Fill;
            image.HorizontalAlignment = HorizontalAlignment.Stretch;
            image.VerticalAlignment = VerticalAlignment.Stretch;
            image.IsHitTestVisible = false;
            Children.Add(image);

            Loaded += OnLoaded;
            Unloaded += OnUnloaded;
            SizeChanged += OnSizeChanged;
        }

        public bool LoadModel(int id, string cachePath)
        {
            if (disposed || id < 0 || String.IsNullOrWhiteSpace(cachePath)) return false;
            modelPaths[id] = cachePath;
            if (!NativeReady) return true;
            try { return D3D11ShelfNative.HC_GPU_LoadShelfModel(nativeHandle, id, cachePath) != 0; }
            catch { return false; }
        }

        public bool SetItem(int id, double x, double y, double width, double height, double scale, bool selected, bool visible)
        {
            if (disposed || id < 0) return false;
            ItemState state;
            if (!itemStates.TryGetValue(id, out state) || state == null) state = new ItemState();
            state.X = (float)x;
            state.Y = (float)y;
            state.Width = Math.Max(0, (float)width);
            state.Height = Math.Max(0, (float)height);
            state.Scale = Math.Max(.12f, Math.Min(2.50f, (float)scale));
            state.Selected = selected;
            state.Visible = visible;
            itemStates[id] = state;
            return ApplyItemToNative(id, state);
        }

        public bool SetItemView(int id, double yawOffset, double pitch, bool spin)
        {
            if (disposed || id < 0) return false;
            ItemState state;
            if (!itemStates.TryGetValue(id, out state) || state == null)
            {
                state = new ItemState { Width = 1.0f, Height = 1.0f, Scale = .82f, Visible = true };
            }
            state.YawOffset = (float)yawOffset;
            state.Pitch = Math.Max(-80.0f, Math.Min(80.0f, (float)pitch));
            state.Spin = spin;
            itemStates[id] = state;
            if (!NativeReady) return true;
            try { return D3D11ShelfNative.HC_GPU_SetShelfItemView(nativeHandle, id, state.YawOffset, state.Pitch, state.Spin ? 1 : 0) != 0; }
            catch { return false; }
        }

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
            state.LightScale = Math.Max(.20f, Math.Min(4.00f, (float)lightScale));
            state.FanScale = Math.Max(0.0f, Math.Min(1.0f, (float)fanScale));
            state.Spin = spin;
            itemStates[id] = state;
            if (!NativeReady) return true;
            try { return D3D11ShelfNative.HC_GPU_SetShelfItemPresentation(nativeHandle, id, state.YawOffset, state.Pitch, state.Roll, state.OffsetX, state.OffsetY, state.MirrorX ? 1 : 0, state.MirrorY ? 1 : 0, state.MirrorZ ? 1 : 0, state.FaceMode, state.LightScale, state.FanScale, state.Spin ? 1 : 0) != 0; }
            catch { return false; }
        }
        public bool SetItemStudioLight(int id, double keyLightScale, double azimuth, double elevation, double distance, double aimX, double aimY, double coneDegrees, double coneSoftness, double falloffScale, double temperatureKelvin, double ambientScale, double specularScale, double highlightScale)
        {
            if (disposed || id < 0) return false;
            ItemState state;
            if (!itemStates.TryGetValue(id, out state) || state == null)
                state = new ItemState { Width = 1.0f, Height = 1.0f, Scale = .82f, Visible = true };
            state.KeyLightScale = Math.Max(0.0f, Math.Min(5.0f, (float)keyLightScale));
            state.LightAzimuth = (float)azimuth;
            state.LightElevation = Math.Max(-89.0f, Math.Min(89.0f, (float)elevation));
            state.LightDistance = Math.Max(1.0f, Math.Min(20.0f, (float)distance));
            state.LightAimX = Math.Max(-1.0f, Math.Min(1.0f, (float)aimX)); state.LightAimY = Math.Max(-1.0f, Math.Min(1.0f, (float)aimY));
            state.ConeDegrees = Math.Max(5.0f, Math.Min(180.0f, (float)coneDegrees));
            state.ConeSoftness = Math.Max(0.0f, Math.Min(1.0f, (float)coneSoftness));
            state.FalloffScale = Math.Max(0.0f, Math.Min(2.0f, (float)falloffScale));
            state.LightTemperature = Math.Max(1800.0f, Math.Min(12000.0f, (float)temperatureKelvin));
            state.AmbientScale = Math.Max(0.0f, Math.Min(3.0f, (float)ambientScale));
            state.SpecularScale = Math.Max(0.0f, Math.Min(4.0f, (float)specularScale));
            state.HighlightScale = Math.Max(0.25f, Math.Min(4.0f, (float)highlightScale));
            state.StudioLightOverride = true;
            itemStates[id] = state;
            if (!NativeReady) return true;
            try { return D3D11ShelfNative.HC_GPU_SetShelfItemStudioLight(nativeHandle, id, state.KeyLightScale, state.LightAzimuth, state.LightElevation, state.LightDistance, state.LightAimX, state.LightAimY, state.ConeDegrees, state.ConeSoftness, state.FalloffScale, state.LightTemperature, state.AmbientScale, state.SpecularScale, state.HighlightScale) != 0; }
            catch { return false; }
        }
        public void ClearModels()
        {
            modelPaths.Clear();
            itemStates.Clear();
            if (!NativeReady) return;
            try { D3D11ShelfNative.HC_GPU_ClearShelfItems(nativeHandle); } catch { }
        }
        public void SetBrightnessPercent(double percent)
        {
            brightnessPercent = Math.Max(0.0, Math.Min(200.0, percent));
            if (!NativeReady) return;
            try { D3D11ShelfNative.HC_GPU_SetShelfBrightness(nativeHandle, (float)(brightnessPercent / 100.0)); } catch { }
        }

        private void ReplayState()
        {
            if (!NativeReady) return;
            foreach (KeyValuePair<int, string> pair in modelPaths)
            {
                try { D3D11ShelfNative.HC_GPU_LoadShelfModel(nativeHandle, pair.Key, pair.Value); } catch { }
            }
            foreach (KeyValuePair<int, ItemState> pair in itemStates)
            {
                ItemState state = pair.Value;
                ApplyItemToNative(pair.Key, state);
            }
        }

        private void OnLoaded(object sender, RoutedEventArgs e)
        {
            EnsureSurface();
            if (!rendering)
            {
                CompositionTarget.Rendering += OnRendering;
                rendering = true;
            }
        }

        private void OnUnloaded(object sender, RoutedEventArgs e)
        {
            if (rendering)
            {
                CompositionTarget.Rendering -= OnRendering;
                rendering = false;
            }
        }

        private void OnSizeChanged(object sender, SizeChangedEventArgs e)
        {
            if (!IsLoaded || disposed) return;
            RefreshDpiScale();
            int w = PixelWidthFor(ActualWidth);
            int h = PixelHeightFor(ActualHeight);
            if (Math.Abs(w - pixelWidth) >= 2 || Math.Abs(h - pixelHeight) >= 2)
                RecreateSurface(w, h);
        }

        private void EnsureSurface()
        {
            if (disposed || NativeReady) return;
            RefreshDpiScale();
            int w = PixelWidthFor(ActualWidth);
            int h = PixelHeightFor(ActualHeight);
            if (w <= 1) w = 960;
            if (h <= 1) h = 320;
            RecreateSurface(w, h);
        }

        private void RecreateSurface(int width, int height)
        {
            ReleaseNativeSurface();
            IntPtr surface9;
            IntPtr handle;
            try { handle = D3D11ShelfNative.HC_GPU_CreateShelfSurface(width, height, out surface9); }
            catch { return; }
            if (handle == IntPtr.Zero || surface9 == IntPtr.Zero)
            {
                if (surface9 != IntPtr.Zero) try { D3D11ShelfNative.HC_GPU_ReleaseShelfSurfacePointer(surface9); } catch { }
                if (handle != IntPtr.Zero) try { D3D11ShelfNative.HC_GPU_DestroyShelfSurface(handle); } catch { }
                return;
            }

            nativeHandle = handle;
            nativeSurface = surface9;
            pixelWidth = width;
            pixelHeight = height;
            source.Lock();
            try
            {
                source.SetBackBuffer(D3DResourceType.IDirect3DSurface9, nativeSurface, true);
                source.AddDirtyRect(new Int32Rect(0, 0, width, height));
            }
            finally { source.Unlock(); }
            try { D3D11ShelfNative.HC_GPU_SetShelfBrightness(nativeHandle, (float)(brightnessPercent / 100.0)); } catch { }
            ReplayState();
        }

        private void OnRendering(object sender, EventArgs e)
        {
            if (disposed || !NativeReady || pixelWidth <= 0 || pixelHeight <= 0) return;
            if (RefreshDpiScale())
            {
                int dpiWidth = PixelWidthFor(ActualWidth);
                int dpiHeight = PixelHeightFor(ActualHeight);
                if (dpiWidth != pixelWidth || dpiHeight != pixelHeight)
                {
                    RecreateSurface(dpiWidth, dpiHeight);
                    if (!NativeReady) return;
                }
            }
            double seconds = renderClock.Elapsed.TotalSeconds;
            // Starts centered, moves left first, comes back through center, then
            // moves right and returns. The bounded phase can never accumulate a
            // full revolution, so the shelf reads as a subtle fan presentation.
            float phase = -FanPhaseAmplitude * (float)Math.Sin(seconds * (Math.PI * 2.0 / FanPeriodSeconds));
            int rendered;
            try { rendered = D3D11ShelfNative.HC_GPU_RenderShelfSurface(nativeHandle, phase); }
            catch { return; }
            if (rendered == 0) return;
            source.Lock();
            try { source.AddDirtyRect(new Int32Rect(0, 0, pixelWidth, pixelHeight)); }
            finally { source.Unlock(); }
        }

        private void ReleaseNativeSurface()
        {
            if (nativeSurface != IntPtr.Zero)
            {
                try
                {
                    source.Lock();
                    try { source.SetBackBuffer(D3DResourceType.IDirect3DSurface9, IntPtr.Zero); }
                    finally { source.Unlock(); }
                }
                catch { }
                try { D3D11ShelfNative.HC_GPU_ReleaseShelfSurfacePointer(nativeSurface); } catch { }
                nativeSurface = IntPtr.Zero;
            }
            if (nativeHandle != IntPtr.Zero)
            {
                try { D3D11ShelfNative.HC_GPU_DestroyShelfSurface(nativeHandle); } catch { }
                nativeHandle = IntPtr.Zero;
            }
            pixelWidth = 0;
            pixelHeight = 0;
        }

        public void Dispose()
        {
            if (disposed) return;
            disposed = true;
            if (rendering)
            {
                CompositionTarget.Rendering -= OnRendering;
                rendering = false;
            }
            ReleaseNativeSurface();
            modelPaths.Clear();
            itemStates.Clear();
            GC.SuppressFinalize(this);
        }
    }
}




