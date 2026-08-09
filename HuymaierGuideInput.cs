using System;
using System.IO;
using System.Runtime.InteropServices;

namespace HuymaierConsole.Native
{
    public static class NativeGuideInput
    {
        [DllImport("HuymaierGuideBridge.dll", CallingConvention = CallingConvention.StdCall)]
        private static extern int HCGuideInitialize();

        [DllImport("HuymaierGuideBridge.dll", CallingConvention = CallingConvention.StdCall)]
        private static extern uint HCGuideConsumePresses();

        [DllImport("HuymaierGuideBridge.dll", CallingConvention = CallingConvention.StdCall)]
        private static extern int HCGuideIsAvailable();

        [DllImport("HuymaierGuideBridge.dll", CallingConvention = CallingConvention.StdCall)]
        private static extern void HCGuideShutdown();

        private static bool attempted;
        private static bool available;

        public static bool Initialize(string baseDirectory)
        {
            if (attempted) return available;
            attempted = true;
            try
            {
                string dll = Path.Combine(baseDirectory ?? String.Empty, "HuymaierGuideBridge.dll");
                if (!File.Exists(dll)) return false;
                available = HCGuideInitialize() != 0 && HCGuideIsAvailable() != 0;
            }
            catch
            {
                available = false;
            }
            return available;
        }

        public static bool IsAvailable
        {
            get
            {
                if (!available) return false;
                try { return HCGuideIsAvailable() != 0; }
                catch { available = false; return false; }
            }
        }

        public static bool ConsumeGuidePress()
        {
            if (!IsAvailable) return false;
            try { return HCGuideConsumePresses() > 0; }
            catch { available = false; return false; }
        }

        public static uint ConsumeGuidePressCount()
        {
            if (!IsAvailable) return 0;
            try { return HCGuideConsumePresses(); }
            catch { available = false; return 0; }
        }

        public static void Shutdown()
        {
            if (!available) return;
            try { HCGuideShutdown(); } catch { }
            available = false;
        }
    }
}
