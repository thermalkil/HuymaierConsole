using System;
using System.Runtime.InteropServices;

namespace Huymaier.EmulatorPlatforms
{
    [StructLayout(LayoutKind.Sequential)]
    public struct XInputGamepad
    {
        public ushort Buttons;
        public byte LeftTrigger;
        public byte RightTrigger;
        public short ThumbLX;
        public short ThumbLY;
        public short ThumbRX;
        public short ThumbRY;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct XInputState
    {
        public uint PacketNumber;
        public XInputGamepad Gamepad;
    }

    public static class XInputBridge
    {
        [DllImport("xinput1_4.dll", EntryPoint = "XInputGetState")]
        private static extern uint GetState14(uint index, out XInputState state);

        [DllImport("xinput1_3.dll", EntryPoint = "XInputGetState")]
        private static extern uint GetState13(uint index, out XInputState state);

        public static bool TryGetState(int index, out XInputState state)
        {
            state = new XInputState();
            try { return GetState14((uint)index, out state) == 0; }
            catch (DllNotFoundException)
            {
                try { return GetState13((uint)index, out state) == 0; }
                catch { return false; }
            }
            catch { return false; }
        }
    }
}
