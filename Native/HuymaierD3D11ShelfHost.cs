using System;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Interop;
using System.Windows.Media;

namespace HuymaierConsole.Modeling
{
    // HUYMAIER_D3D11_SHELF_HOST_V1
    // WPF owns navigation/chrome; the shelf pixels are produced by the native
    // D3D11 backend and shared into WPF without a CPU readback through D3DImage.
    internal static class D3D11ShelfNative
    {
        private const string DllName = "HuymaierD3D11ShelfRenderer.dll";

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        internal static extern int HC_D3D11SmokeTest();

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        internal static extern IntPtr HC_D3D11CreateWpfSurface(int width, int height, out IntPtr surface9);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        internal static extern int HC_D3D11RenderWpfSurface(IntPtr handle, float phase);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        internal static extern void HC_D3D11ReleaseSurfacePointer(IntPtr surface9);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        internal static extern void HC_D3D11DestroyWpfSurface(IntPtr handle);
    }

    public sealed class D3D11ShelfSurface : Grid, IDisposable
    {
        private readonly Image image;
        private readonly D3DImage source;
        private IntPtr nativeHandle;
        private IntPtr nativeSurface;
        private int pixelWidth;
        private int pixelHeight;
        private bool rendering;
        private bool disposed;
        private float phase;

        public bool NativeReady { get { return nativeHandle != IntPtr.Zero && nativeSurface != IntPtr.Zero; } }
        public int PixelWidth { get { return pixelWidth; } }
        public int PixelHeight { get { return pixelHeight; } }

        public static int RunNativeSmokeTest()
        {
            return D3D11ShelfNative.HC_D3D11SmokeTest();
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
            int w = Math.Max(1, (int)Math.Ceiling(ActualWidth));
            int h = Math.Max(1, (int)Math.Ceiling(ActualHeight));
            if (Math.Abs(w - pixelWidth) >= 2 || Math.Abs(h - pixelHeight) >= 2)
                RecreateSurface(w, h);
        }

        private void EnsureSurface()
        {
            if (disposed || NativeReady) return;
            int w = Math.Max(1, (int)Math.Ceiling(ActualWidth));
            int h = Math.Max(1, (int)Math.Ceiling(ActualHeight));
            if (w <= 1) w = 640;
            if (h <= 1) h = 220;
            RecreateSurface(w, h);
        }

        private void RecreateSurface(int width, int height)
        {
            ReleaseSurface();
            IntPtr surface9;
            IntPtr handle = D3D11ShelfNative.HC_D3D11CreateWpfSurface(width, height, out surface9);
            if (handle == IntPtr.Zero || surface9 == IntPtr.Zero)
            {
                if (surface9 != IntPtr.Zero) D3D11ShelfNative.HC_D3D11ReleaseSurfacePointer(surface9);
                if (handle != IntPtr.Zero) D3D11ShelfNative.HC_D3D11DestroyWpfSurface(handle);
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
        }

        private void OnRendering(object sender, EventArgs e)
        {
            if (disposed || !NativeReady || pixelWidth <= 0 || pixelHeight <= 0) return;
            phase += 0.0125f;
            if (phase > 10000.0f) phase = 0.0f;
            if (D3D11ShelfNative.HC_D3D11RenderWpfSurface(nativeHandle, phase) == 0) return;
            source.Lock();
            try { source.AddDirtyRect(new Int32Rect(0, 0, pixelWidth, pixelHeight)); }
            finally { source.Unlock(); }
        }

        private void ReleaseSurface()
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
                D3D11ShelfNative.HC_D3D11ReleaseSurfacePointer(nativeSurface);
                nativeSurface = IntPtr.Zero;
            }
            if (nativeHandle != IntPtr.Zero)
            {
                D3D11ShelfNative.HC_D3D11DestroyWpfSurface(nativeHandle);
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
            ReleaseSurface();
            GC.SuppressFinalize(this);
        }
    }
}
