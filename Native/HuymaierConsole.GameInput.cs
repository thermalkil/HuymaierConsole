using System;
using System.Runtime.InteropServices;
using System.Threading;

namespace HuymaierConsole.NativeApp
{
    public static class HuymaierBuildStamp
    {
        public const string Version = "0.26.4";
        public const string Architecture = "x64";
    }

    public sealed class HuymaierPointerState
    {
        public bool Available { get; set; }
        public float LeftX { get; set; }
        public float LeftY { get; set; }
        public float RightX { get; set; }
        public float RightY { get; set; }
        public float LeftTrigger { get; set; }
        public float RightTrigger { get; set; }
        public uint Buttons { get; set; }
    }

    public static class HuymaierPointerInput
    {
        public static HuymaierPointerState GetState()
        {
            return HuymaierSystemButtonBridge.ReadPointerState();
        }
    }

    public static class HuymaierInstanceGate
    {
        private static readonly object Sync = new object();
        private static Mutex instanceMutex;
        private static bool ownsMutex;

        public static bool TryAcquire()
        {
            lock (Sync)
            {
                if (ownsMutex) return true;
                if (instanceMutex == null)
                    instanceMutex = new Mutex(false, "Local\\HuymaierConsole.MainInstance");
                try
                {
                    ownsMutex = instanceMutex.WaitOne(0, false);
                }
                catch (AbandonedMutexException)
                {
                    ownsMutex = true;
                }
                return ownsMutex;
            }
        }

        public static void Release()
        {
            lock (Sync)
            {
                if (instanceMutex == null) return;
                if (ownsMutex)
                {
                    try { instanceMutex.ReleaseMutex(); }
                    catch { }
                }
                ownsMutex = false;
                try { instanceMutex.Dispose(); }
                catch { }
                instanceMutex = null;
            }
        }
    }

    public static class HuymaierSystemButtonStatus
    {
        public static bool IsAvailable
        {
            get { return HuymaierSystemButtonBridge.IsAvailable; }
        }
    }

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
        private static extern int HC_ReadGamepadPointerState(
            out float leftX,
            out float leftY,
            out float rightX,
            out float rightY,
            out float leftTrigger,
            out float rightTrigger,
            out uint buttons);

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

        internal static HuymaierPointerState ReadPointerState()
        {
            EnsureInitialized();
            HuymaierPointerState state = new HuymaierPointerState();
            if (!available) return state;
            try
            {
                float lx, ly, rx, ry, lt, rt;
                uint buttons;
                int result = HC_ReadGamepadPointerState(out lx, out ly, out rx, out ry, out lt, out rt, out buttons);
                if (result == 0) return state;
                state.Available = true;
                state.LeftX = lx;
                state.LeftY = ly;
                state.RightX = rx;
                state.RightY = ry;
                state.LeftTrigger = lt;
                state.RightTrigger = rt;
                state.Buttons = buttons;
                return state;
            }
            catch
            {
                available = false;
                return state;
            }
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
