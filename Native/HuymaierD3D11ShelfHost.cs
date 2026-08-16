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
    // HUYMAIER_D3D11_SHELF_HOST_V2
    // HUYMAIER_D3D11_DPI_AWARE_SHELF_V1
    // WPF owns navigation and chrome. The persistent shelf surface, asset cache,
    // turntable animation and model rendering are owned by native D3D11.
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
                return D3D11ShelfNative.HC_GPU_SetShelfItem(
                    nativeHandle, id,
                    state.X * (float)dpiScaleX, state.Y * (float)dpiScaleY,
                    state.Width * (float)dpiScaleX, state.Height * (float)dpiScaleY,
                    state.Scale, state.Selected ? 1 : 0, state.Visible ? 1 : 0) != 0;
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
            ItemState state = new ItemState
            {
                X = (float)x,
                Y = (float)y,
                Width = Math.Max(0, (float)width),
                Height = Math.Max(0, (float)height),
                Scale = Math.Max(.40f, Math.Min(.90f, (float)scale)),
                Selected = selected,
                Visible = visible
            };
            itemStates[id] = state;
            return ApplyItemToNative(id, state);
        }

        public void ClearModels()
        {
            modelPaths.Clear();
            itemStates.Clear();
            if (!NativeReady) return;
            try { D3D11ShelfNative.HC_GPU_ClearShelfItems(nativeHandle); } catch { }
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
            float phase = (float)renderClock.Elapsed.TotalSeconds;
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
