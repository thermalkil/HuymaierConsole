using System;
using System.Diagnostics;
using System.Windows.Media;

namespace HuymaierConsole.Native
{
    public static class FrameRateMonitor
    {
        private static readonly object Sync = new object();
        private static Stopwatch stopwatch;
        private static long frames;
        private static double fps;
        private static bool running;

        public static double Fps { get { lock (Sync) { return fps; } } }

        public static void Start()
        {
            lock (Sync)
            {
                if (running) return;
                stopwatch = Stopwatch.StartNew();
                frames = 0;
                fps = 0;
                CompositionTarget.Rendering += OnRendering;
                running = true;
            }
        }

        public static void Stop()
        {
            lock (Sync)
            {
                if (!running) return;
                CompositionTarget.Rendering -= OnRendering;
                running = false;
                fps = 0;
                if (stopwatch != null) stopwatch.Stop();
            }
        }

        private static void OnRendering(object sender, EventArgs args)
        {
            lock (Sync)
            {
                if (!running || stopwatch == null) return;
                frames++;
                if (stopwatch.ElapsedMilliseconds >= 1000)
                {
                    fps = frames * 1000.0 / Math.Max(1.0, stopwatch.ElapsedMilliseconds);
                    frames = 0;
                    stopwatch.Restart();
                }
            }
        }
    }
}
