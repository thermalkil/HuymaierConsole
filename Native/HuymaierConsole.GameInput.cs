using System;
using System.Runtime.InteropServices;
using System.Threading;

namespace HuymaierConsole.NativeApp
{
    internal static class HuymaierSystemButtonBridge
    {
        private const string BridgeDll = "HuymaierGameInputBridge.dll";
        private static readonly object Sync = new object();
        private static int initializationState;
        private static bool available;

        [DllImport(BridgeDll, CallingConvention = CallingConvention.Cdecl)]
        private static extern int HC_GameInputInitialize();

        [DllImport(BridgeDll, CallingConvention = CallingConvention.Cdecl)]
        private static extern int HC_ConsumeGuidePress();

        [DllImport(BridgeDll, CallingConvention = CallingConvention.Cdecl)]
        private static extern int HC_ConsumeSharePress();

        [DllImport(BridgeDll, CallingConvention = CallingConvention.Cdecl)]
        private static extern void HC_GameInputShutdown();

        internal static bool IsAvailable
        {
            get
            {
                EnsureInitialized();
                return available;
            }
        }

        internal static bool ConsumeGuidePress()
        {
            EnsureInitialized();
            if (!available) return false;
            try { return HC_ConsumeGuidePress() != 0; }
            catch { available = false; return false; }
        }

        internal static bool ConsumeSharePress()
        {
            EnsureInitialized();
            if (!available) return false;
            try { return HC_ConsumeSharePress() != 0; }
            catch { available = false; return false; }
        }

        internal static void Shutdown()
        {
            lock (Sync)
            {
                if (initializationState == 0) return;
                if (available)
                {
                    try { HC_GameInputShutdown(); }
                    catch { }
                }
                available = false;
                Volatile.Write(ref initializationState, 0);
            }
        }

        private static void EnsureInitialized()
        {
            if (Volatile.Read(ref initializationState) != 0) return;
            lock (Sync)
            {
                if (initializationState != 0) return;
                try { available = HC_GameInputInitialize() != 0; }
                catch (DllNotFoundException) { available = false; }
                catch (EntryPointNotFoundException) { available = false; }
                catch (BadImageFormatException) { available = false; }
                catch { available = false; }
                Volatile.Write(ref initializationState, 1);
            }
        }
    }
}
