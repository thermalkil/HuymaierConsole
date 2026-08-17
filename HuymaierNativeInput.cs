using System;
using System.Collections.Generic;
using System.IO.MemoryMappedFiles;
using System.Runtime.InteropServices;
using System.Text;

namespace HuymaierConsole.Native
{



    public sealed class LegacyJoystickSnapshot
    {
        public int Id { get; set; }
        public string Name { get; set; }
        public uint Buttons { get; set; }
        public uint Pov { get; set; }
        public uint X { get; set; }
        public uint Y { get; set; }
        public uint Z { get; set; }
        public uint R { get; set; }
        public uint U { get; set; }
        public uint V { get; set; }
    }

    public static class LegacyJoystick
    {
        private const uint JOY_RETURNALL = 0x000000FF;
        private const uint MMSYSERR_NOERROR = 0;

        [StructLayout(LayoutKind.Sequential)]
        private struct JOYINFOEX
        {
            public uint dwSize;
            public uint dwFlags;
            public uint dwXpos;
            public uint dwYpos;
            public uint dwZpos;
            public uint dwRpos;
            public uint dwUpos;
            public uint dwVpos;
            public uint dwButtons;
            public uint dwButtonNumber;
            public uint dwPOV;
            public uint dwReserved1;
            public uint dwReserved2;
        }

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        private struct JOYCAPS
        {
            public ushort wMid;
            public ushort wPid;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string szPname;
            public uint wXmin;
            public uint wXmax;
            public uint wYmin;
            public uint wYmax;
            public uint wZmin;
            public uint wZmax;
            public uint wNumButtons;
            public uint wPeriodMin;
            public uint wPeriodMax;
            public uint wRmin;
            public uint wRmax;
            public uint wUmin;
            public uint wUmax;
            public uint wVmin;
            public uint wVmax;
            public uint wCaps;
            public uint wMaxAxes;
            public uint wNumAxes;
            public uint wMaxButtons;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string szRegKey;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 260)] public string szOEMVxD;
        }

        [DllImport("winmm.dll")]
        private static extern uint joyGetNumDevs();

        [DllImport("winmm.dll", CharSet = CharSet.Unicode)]
        private static extern uint joyGetDevCaps(uint uJoyID, ref JOYCAPS pjc, uint cbjc);

        [DllImport("winmm.dll")]
        private static extern uint joyGetPosEx(uint uJoyID, ref JOYINFOEX pji);

        public static LegacyJoystickSnapshot[] GetSnapshots()
        {
            var list = new List<LegacyJoystickSnapshot>();
            uint count = Math.Min(joyGetNumDevs(), 32u);
            for (uint id = 0; id < count; id++)
            {
                var info = new JOYINFOEX();
                info.dwSize = (uint)Marshal.SizeOf(typeof(JOYINFOEX));
                info.dwFlags = JOY_RETURNALL;
                if (joyGetPosEx(id, ref info) != MMSYSERR_NOERROR) continue;

                string name = "Game Controller";
                var caps = new JOYCAPS();
                if (joyGetDevCaps(id, ref caps, (uint)Marshal.SizeOf(typeof(JOYCAPS))) == MMSYSERR_NOERROR && !String.IsNullOrWhiteSpace(caps.szPname))
                    name = caps.szPname.Trim();

                // Gaming mice such as Swiftpoint Z/Z2 intentionally expose a
                // DirectInput joystick interface. They are pointing devices,
                // not shell navigation controllers, and their resting tilt
                // axes can otherwise look like a permanently held direction.
                string lowerName = (name ?? String.Empty).ToLowerInvariant();
                if (lowerName.Contains("swiftpoint") || lowerName.Contains("mouse") ||
                    lowerName.Contains("trackball") || lowerName.Contains("touchpad") ||
                    lowerName.Contains("trackpad") || lowerName.Contains("spacemouse") ||
                    lowerName.Contains("3dconnexion"))
                    continue;

                list.Add(new LegacyJoystickSnapshot {
                    Id = (int)id,
                    Name = name,
                    Buttons = info.dwButtons,
                    Pov = info.dwPOV,
                    X = info.dwXpos,
                    Y = info.dwYpos,
                    Z = info.dwZpos,
                    R = info.dwRpos,
                    U = info.dwUpos,
                    V = info.dwVpos
                });
            }
            return list.ToArray();
        }
    }

    public sealed class HidControllerSnapshot
    {
        public long DeviceHandle { get; set; }
        public string Name { get; set; }
        public int VendorId { get; set; }
        public int ProductId { get; set; }
        public int Mask { get; set; }
        public string Direction { get; set; }
        public bool Activity { get; set; }
        public string Family { get; set; }
        public string Connection { get; set; }
        public DateTime LastSeenUtc { get; set; }
        internal int PendingMask { get; set; }
        internal string PendingDirection { get; set; }
    }

    /// <summary>
    /// Allocation-free snapshot used by the shell navigation poller. Button and
    /// direction edges are latched until a consumer observes them so a quick tap
    /// is not lost while WPF is rendering or decoding artwork.
    /// </summary>
    public struct HidNavigationSnapshot
    {
        public long DeviceHandle;
        public int Mask;
        public string Direction;
        public DateTime LastSeenUtc;
    }

    /// <summary>
    /// WM_INPUT-backed Sony HID controller reader. This path is independent of
    /// XInput, Steam Input and Windows.Gaming.Input, which allows Bluetooth
    /// DualSense controllers to navigate the shell without a remapper.
    /// </summary>
    public static class NativeCursorRouter
    {
        [StructLayout(LayoutKind.Sequential)] private struct POINT { public int X; public int Y; }
        [DllImport("user32.dll")] private static extern bool SetCursorPos(int X, int Y);
        [DllImport("user32.dll")] private static extern bool GetCursorPos(out POINT point);
        [DllImport("user32.dll")] private static extern int GetSystemMetrics(int nIndex);
        public static void ParkTopRight()
        {
            try
            {
                int width = GetSystemMetrics(0);
                if (width < 4) width = 1920;
                SetCursorPos(width - 2, 2);
            }
            catch { }
        }
        public static long GetCursorPosition()
        {
            try
            {
                POINT point;
                if (!GetCursorPos(out point)) return 0;
                return ((long)(uint)point.X << 32) | (uint)point.Y;
            }
            catch { return 0; }
        }
        public static bool MovedFrom(long packedPosition, int threshold)
        {
            try
            {
                if (packedPosition == 0) return true;
                POINT point;
                if (!GetCursorPos(out point)) return true;
                int oldX = unchecked((int)(packedPosition >> 32));
                int oldY = unchecked((int)(packedPosition & 0xffffffffL));
                return Math.Abs(point.X - oldX) > threshold || Math.Abs(point.Y - oldY) > threshold;
            }
            catch { return true; }
        }
    }

    public static class RawHidController
    {
        private const uint RIDEV_INPUTSINK = 0x00000100;
        private const uint RIDEV_DEVNOTIFY = 0x00002000;
        private const uint RID_INPUT = 0x10000003;
        private const uint RIDI_DEVICENAME = 0x20000007;
        private const uint RIDI_DEVICEINFO = 0x2000000b;
        private const uint RIM_TYPEHID = 2;
        private const int GIDC_ARRIVAL = 1;
        private const int GIDC_REMOVAL = 2;

        private const ushort SONY_VENDOR_ID = 0x054C;

        // HUYMAIER_SONY_POINTER_SHARED_STATE_V1
        // Publish the proven WM_INPUT Sony controller state for pointer-only
        // consumers. Normal shell navigation remains in this process and is
        // still suppressed whenever Huymaier is not foregrounded. The PS/Guide
        // button is also carried as a dedicated high pointer bit so the global
        // Game Bar watcher can consume it without touching normal navigation.
        private const string POINTER_MAP_NAME = "Local\\HuymaierConsole.PointerStateV1";
        private const int POINTER_MAP_SIZE = 64;
        private const int POINTER_MAP_MAGIC = 0x31504348; // HCP1
        private static readonly object PointerSync = new object();
        private static MemoryMappedFile pointerMap;
        private static MemoryMappedViewAccessor pointerView;
        private static int pointerSequence;
        [DllImport("kernel32.dll")] private static extern ulong GetTickCount64();
        private static readonly object Sync = new object();
        private static readonly Dictionary<long, HidControllerSnapshot> Snapshots = new Dictionary<long, HidControllerSnapshot>();
        private static readonly List<long> StaleNavigationKeys = new List<long>(8);
        private static bool registered;
        private static int sonyPacketsSeen;
        private static int lastReportId = -1;
        private static int lastReportLength;
        private static int lastProductId;
        private static DateTime lastConnectionScanUtc = DateTime.MinValue;
        private static bool cachedSonyControllerConnected;

        [StructLayout(LayoutKind.Sequential)]
        private struct RAWINPUTDEVICE
        {
            public ushort usUsagePage;
            public ushort usUsage;
            public uint dwFlags;
            public IntPtr hwndTarget;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct RAWINPUTHEADER
        {
            public uint dwType;
            public uint dwSize;
            public IntPtr hDevice;
            public IntPtr wParam;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct RAWINPUTDEVICELIST
        {
            public IntPtr hDevice;
            public uint dwType;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct RID_DEVICE_INFO_MOUSE
        {
            public uint dwId;
            public uint dwNumberOfButtons;
            public uint dwSampleRate;
            public int fHasHorizontalWheel;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct RID_DEVICE_INFO_KEYBOARD
        {
            public uint dwType;
            public uint dwSubType;
            public uint dwKeyboardMode;
            public uint dwNumberOfFunctionKeys;
            public uint dwNumberOfIndicators;
            public uint dwNumberOfKeysTotal;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct RID_DEVICE_INFO_HID
        {
            public uint dwVendorId;
            public uint dwProductId;
            public uint dwVersionNumber;
            public ushort usUsagePage;
            public ushort usUsage;
        }

        [StructLayout(LayoutKind.Explicit)]
        private struct RID_DEVICE_INFO_UNION
        {
            [FieldOffset(0)] public RID_DEVICE_INFO_MOUSE mouse;
            [FieldOffset(0)] public RID_DEVICE_INFO_KEYBOARD keyboard;
            [FieldOffset(0)] public RID_DEVICE_INFO_HID hid;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct RID_DEVICE_INFO
        {
            public uint cbSize;
            public uint dwType;
            public RID_DEVICE_INFO_UNION info;
        }

        [DllImport("user32.dll", SetLastError = true)]
        private static extern bool RegisterRawInputDevices(
            [In] RAWINPUTDEVICE[] pRawInputDevices,
            uint uiNumDevices,
            uint cbSize);

        [DllImport("user32.dll", SetLastError = true)]
        private static extern uint GetRawInputData(
            IntPtr hRawInput,
            uint uiCommand,
            IntPtr pData,
            ref uint pcbSize,
            uint cbSizeHeader);

        [DllImport("user32.dll", SetLastError = true)]
        private static extern uint GetRawInputDeviceList(
            IntPtr pRawInputDeviceList,
            ref uint puiNumDevices,
            uint cbSize);

        [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        private static extern uint GetRawInputDeviceInfo(
            IntPtr hDevice,
            uint uiCommand,
            StringBuilder pData,
            ref uint pcbSize);

        [DllImport("user32.dll", SetLastError = true)]
        private static extern uint GetRawInputDeviceInfo(
            IntPtr hDevice,
            uint uiCommand,
            ref RID_DEVICE_INFO pData,
            ref uint pcbSize);

        public static bool Register(IntPtr windowHandle)
        {
            if (windowHandle == IntPtr.Zero) return false;
            var devices = new RAWINPUTDEVICE[2];
            devices[0] = new RAWINPUTDEVICE {
                usUsagePage = 0x01,
                usUsage = 0x04,
                dwFlags = RIDEV_INPUTSINK | RIDEV_DEVNOTIFY,
                hwndTarget = windowHandle
            };
            devices[1] = new RAWINPUTDEVICE {
                usUsagePage = 0x01,
                usUsage = 0x05,
                dwFlags = RIDEV_INPUTSINK | RIDEV_DEVNOTIFY,
                hwndTarget = windowHandle
            };
            registered = RegisterRawInputDevices(devices, (uint)devices.Length, (uint)Marshal.SizeOf(typeof(RAWINPUTDEVICE)));
            lock (Sync)
            {
                lastConnectionScanUtc = DateTime.MinValue;
                cachedSonyControllerConnected = false;
            }
            return registered;
        }

        public static void ProcessDeviceChange(IntPtr change, IntPtr device)
        {
            int kind = change.ToInt32();
            long key = device == IntPtr.Zero ? 0L : device.ToInt64();
            if (kind == GIDC_ARRIVAL && device != IntPtr.Zero)
            {
                try
                {
                    int vendorId, productId;
                    GetDeviceIdentity(device, out vendorId, out productId);
                    if (vendorId != SONY_VENDOR_ID) return;
                }
                catch { return; }
            }
            lock (Sync)
            {
                // This cache contains Sony HID devices only.  Xbox/XInput arrival
                // and removal bursts must not invalidate it or race the shell poller.
                if (kind == GIDC_REMOVAL && key != 0L && !Snapshots.ContainsKey(key)) return;
                lastConnectionScanUtc = DateTime.MinValue;
                cachedSonyControllerConnected = false;
                if (key != 0L && (kind == GIDC_ARRIVAL || kind == GIDC_REMOVAL)) Snapshots.Remove(key);
                if (kind == GIDC_REMOVAL)
                {
                    DateTime now = DateTime.UtcNow;
                    StaleNavigationKeys.Clear();
                    foreach (var pair in Snapshots)
                        if ((now - pair.Value.LastSeenUtc).TotalMilliseconds > 250) StaleNavigationKeys.Add(pair.Key);
                    foreach (long stale in StaleNavigationKeys) Snapshots.Remove(stale);
                }
            }
        }

        public static bool HasConnectedSonyController()
        {
            DateTime now = DateTime.UtcNow;
            lock (Sync)
            {
                if ((now - lastConnectionScanUtc).TotalMilliseconds < 750) return cachedSonyControllerConnected;
            }

            bool found = false;
            uint count = 0;
            uint size = (uint)Marshal.SizeOf(typeof(RAWINPUTDEVICELIST));
            uint first = GetRawInputDeviceList(IntPtr.Zero, ref count, size);
            if (first != UInt32.MaxValue && count > 0 && count <= 1024)
            {
                long bytes = (long)count * (long)size;
                if (bytes > 0 && bytes <= Int32.MaxValue)
                {
                    IntPtr buffer = Marshal.AllocHGlobal((int)bytes);
                    try
                    {
                        uint available = count;
                        uint result = GetRawInputDeviceList(buffer, ref available, size);
                        if (result != UInt32.MaxValue)
                        {
                            uint limit = Math.Min(result, available);
                            for (uint index = 0; index < limit; index++)
                            {
                                IntPtr address = new IntPtr(buffer.ToInt64() + ((long)index * (long)size));
                                RAWINPUTDEVICELIST device = (RAWINPUTDEVICELIST)Marshal.PtrToStructure(address, typeof(RAWINPUTDEVICELIST));
                                if (device.dwType != RIM_TYPEHID || device.hDevice == IntPtr.Zero) continue;
                                try
                                {
                                    int vendorId;
                                    int productId;
                                    GetDeviceIdentity(device.hDevice, out vendorId, out productId);
                                    if (vendorId == SONY_VENDOR_ID && IsSupportedSonyControllerProduct(productId))
                                    {
                                        found = true;
                                        break;
                                    }
                                }
                                catch { }
                            }
                        }
                    }
                    finally
                    {
                        Marshal.FreeHGlobal(buffer);
                    }
                }
            }

            lock (Sync)
            {
                cachedSonyControllerConnected = found;
                lastConnectionScanUtc = now;
                return cachedSonyControllerConnected;
            }
        }

        private static bool IsSupportedSonyControllerProduct(int productId)
        {
            switch (productId)
            {
                case 0x05C4: // DualShock 4 v1
                case 0x09CC: // DualShock 4 v2
                case 0x0CE6: // DualSense
                case 0x0DF2: // DualSense Edge
                    return true;
                default:
                    return false;
            }
        }

        public static bool IsRegistered()
        {
            return registered;
        }

        public static string GetDiagnostics()
        {
            return String.Format(
                "Registered={0}; SonyPackets={1}; LastReport=0x{2:X2}; LastLength={3}; LastProduct=0x{4:X4}",
                registered, sonyPacketsSeen, lastReportId < 0 ? 0 : lastReportId,
                lastReportLength, lastProductId);
        }

        public static void ProcessInput(IntPtr rawInputHandle)
        {
            if (rawInputHandle == IntPtr.Zero) return;
            uint size = 0;
            uint headerSize = (uint)Marshal.SizeOf(typeof(RAWINPUTHEADER));
            if (GetRawInputData(rawInputHandle, RID_INPUT, IntPtr.Zero, ref size, headerSize) == UInt32.MaxValue || size < headerSize + 8)
                return;
            // A device can publish a transient/corrupt report length while it is
            // being added or removed. Never allocate an unbounded native buffer.
            if (size > 1024 * 1024 || size > Int32.MaxValue) return;

            IntPtr buffer = Marshal.AllocHGlobal((int)size);
            try
            {
                uint received = size;
                if (GetRawInputData(rawInputHandle, RID_INPUT, buffer, ref received, headerSize) == UInt32.MaxValue)
                    return;

                RAWINPUTHEADER header = (RAWINPUTHEADER)Marshal.PtrToStructure(buffer, typeof(RAWINPUTHEADER));
                if (header.dwType != RIM_TYPEHID || header.hDevice == IntPtr.Zero) return;

                int vendorId;
                int productId;
                try { GetDeviceIdentity(header.hDevice, out vendorId, out productId); }
                catch { return; }
                if (vendorId != SONY_VENDOR_ID || !IsSupportedSonyControllerProduct(productId)) return;

                int rawHidOffset = (int)headerSize;
                if (rawHidOffset < 0 || rawHidOffset + 8 > received) return;
                uint reportSize = (uint)Marshal.ReadInt32(buffer, rawHidOffset);
                uint reportCount = (uint)Marshal.ReadInt32(buffer, rawHidOffset + 4);
                // DualShock/DualSense reports are small. Caps protect the UI
                // process from malformed data during Bluetooth hot-plug.
                if (reportSize == 0 || reportSize > 1024 || reportCount == 0 || reportCount > 64) return;

                int payloadOffset = rawHidOffset + 8;
                ulong payloadBytes = (ulong)reportSize * (ulong)reportCount;
                if ((ulong)payloadOffset + payloadBytes > (ulong)received) return;
                for (uint reportIndex = 0; reportIndex < reportCount; reportIndex++)
                {
                    long relative = (long)payloadOffset + ((long)reportIndex * (long)reportSize);
                    if (relative < payloadOffset || relative + reportSize > received) break;
                    long reportAddress = buffer.ToInt64() + relative;
                    byte[] report = new byte[(int)reportSize];
                    Marshal.Copy(new IntPtr(reportAddress), report, 0, (int)reportSize);
                    sonyPacketsSeen++;
                    lastReportId = report.Length > 0 ? report[0] : -1;
                    lastReportLength = report.Length;
                    lastProductId = productId;
                    try { ParseSonyReport(header.hDevice, vendorId, productId, report); }
                    catch { /* Ignore a single malformed hot-plug report. */ }
                }
            }
            finally
            {
                Marshal.FreeHGlobal(buffer);
            }
        }

        public static HidControllerSnapshot[] GetSnapshots()
        {
            lock (Sync)
            {
                var now = DateTime.UtcNow;
                var stale = new List<long>();
                foreach (var pair in Snapshots)
                {
                    double age = (now - pair.Value.LastSeenUtc).TotalSeconds;
                    if (age > 30) stale.Add(pair.Key);
                    else if (age > 0.35)
                    {
                        pair.Value.Mask = 0;
                        pair.Value.Direction = String.Empty;
                        pair.Value.Activity = false;
                        pair.Value.PendingMask = 0;
                        pair.Value.PendingDirection = String.Empty;
                    }
                }
                foreach (long key in stale) Snapshots.Remove(key);

                var result = new HidControllerSnapshot[Snapshots.Count];
                int index = 0;
                foreach (var pair in Snapshots)
                {
                    HidControllerSnapshot value = pair.Value;
                    result[index++] = new HidControllerSnapshot {
                        DeviceHandle = value.DeviceHandle,
                        Name = value.Name,
                        VendorId = value.VendorId,
                        ProductId = value.ProductId,
                        Mask = value.Mask,
                        Direction = value.Direction,
                        Activity = value.Activity,
                        Family = value.Family,
                        Connection = value.Connection,
                        LastSeenUtc = value.LastSeenUtc,
                        PendingMask = value.PendingMask,
                        PendingDirection = value.PendingDirection
                    };
                }
                return result;
            }
        }

        public static bool ConsumeGuideEdge()
        {
            lock (Sync)
            {
                DateTime now = DateTime.UtcNow;
                foreach (var pair in Snapshots)
                {
                    HidControllerSnapshot value = pair.Value;
                    if (value == null || (now - value.LastSeenUtc).TotalSeconds > 3) continue;
                    if ((value.PendingMask & 2) == 0) continue;
                    value.PendingMask &= ~2;
                    return true;
                }
                return false;
            }
        }

        public static int CopyNavigationSnapshots(HidNavigationSnapshot[] destination)
        {
            if (destination == null || destination.Length == 0) return 0;
            lock (Sync)
            {
                DateTime now = DateTime.UtcNow;
                StaleNavigationKeys.Clear();
                foreach (var pair in Snapshots)
                {
                    double age = (now - pair.Value.LastSeenUtc).TotalSeconds;
                    if (age > 30) StaleNavigationKeys.Add(pair.Key);
                    else if (age > 0.35)
                    {
                        pair.Value.Mask = 0;
                        pair.Value.Direction = String.Empty;
                        pair.Value.Activity = false;
                        pair.Value.PendingMask = 0;
                        pair.Value.PendingDirection = String.Empty;
                    }
                }
                foreach (long key in StaleNavigationKeys) Snapshots.Remove(key);

                int index = 0;
                foreach (var pair in Snapshots)
                {
                    if (index >= destination.Length) break;
                    HidControllerSnapshot value = pair.Value;
                    int effectiveMask = value.Mask | value.PendingMask;
                    string effectiveDirection = !String.IsNullOrWhiteSpace(value.PendingDirection)
                        ? value.PendingDirection
                        : value.Direction;
                    destination[index++] = new HidNavigationSnapshot {
                        DeviceHandle = value.DeviceHandle,
                        Mask = effectiveMask,
                        Direction = effectiveDirection ?? String.Empty,
                        LastSeenUtc = value.LastSeenUtc
                    };
                    value.PendingMask = 0;
                    value.PendingDirection = String.Empty;
                }
                return index;
            }
        }

        private static void ParseSonyReport(IntPtr device, int vendorId, int productId, byte[] report)
        {
            if (report == null || report.Length < 12) return;

            int stateBase;
            string connection;
            byte reportId = report[0];
            bool dualSense = productId == 0x0CE6 || productId == 0x0DF2;

            // Raw Input normally includes the HID report ID, but some Bluetooth
            // stacks strip it. Accept both numbered and stripped Sony layouts.
            // DualSense USB: 01 [LX LY RX RY L2 R2 Seq B1 B2 B3 ...]
            if (reportId == 0x01)
            {
                stateBase = 1;
                connection = "USB HID";
            }
            // DualSense Bluetooth: 31 [tag LX LY RX RY L2 R2 Seq B1 B2 B3 ...]
            else if (reportId == 0x31)
            {
                stateBase = 2;
                connection = "Bluetooth HID";
            }
            // Some Windows Bluetooth paths strip 31 and leave the 02 tag first.
            else if (dualSense && reportId == 0x02 && report.Length >= 70)
            {
                stateBase = 1;
                connection = "Bluetooth HID";
            }
            // Other Raw Input drivers strip both the report ID and Bluetooth tag.
            else if (dualSense && report.Length >= 70)
            {
                stateBase = 0;
                connection = "Bluetooth HID";
            }
            // An unnumbered 64-byte DualSense/DS4 USB report starts directly at LX.
            else if (dualSense && report.Length >= 60)
            {
                stateBase = 0;
                connection = "USB HID";
            }
            // DualShock 4 Bluetooth commonly uses report 11 with two header bytes.
            else if (reportId == 0x11)
            {
                stateBase = 3;
                connection = "Bluetooth HID";
            }
            else
            {
                return;
            }

            if (stateBase + 9 >= report.Length) return;

            byte lx = report[stateBase + 0];
            byte ly = report[stateBase + 1];
            byte rx = report[stateBase + 2];
            byte ry = report[stateBase + 3];
            byte buttons1 = report[stateBase + 7];
            byte buttons2 = report[stateBase + 8];
            byte buttons3 = report[stateBase + 9];

            int mask = 0;
            // Cross / confirm, Circle / back, Options / menu, L1 / R1.
            if ((buttons1 & 0x20) != 0) mask |= 4;
            if ((buttons1 & 0x40) != 0) mask |= 8;
            if ((buttons1 & 0x10) != 0) mask |= 16;
            if ((buttons1 & 0x80) != 0) mask |= 32;
            if ((buttons2 & 0x20) != 0) mask |= 1;
            if ((buttons3 & 0x01) != 0) mask |= 2;
            if ((buttons2 & 0x01) != 0) mask |= 1024;
            if ((buttons2 & 0x02) != 0) mask |= 2048;

            string direction = String.Empty;
            int dpad = buttons1 & 0x0F;
            if (dpad == 0 || dpad == 1 || dpad == 7) direction = "Up";
            else if (dpad == 2 || dpad == 3) direction = "Right";
            else if (dpad == 4 || dpad == 5) direction = "Down";
            else if (dpad == 6) direction = "Left";

            if (String.IsNullOrEmpty(direction))
            {
                if (lx < 66) direction = "Left";
                else if (lx > 190) direction = "Right";
                else if (ly < 66) direction = "Up";
                else if (ly > 190) direction = "Down";
            }

            bool activity = mask != 0 || !String.IsNullOrEmpty(direction) ||
                            Math.Abs((int)lx - 128) > 30 || Math.Abs((int)ly - 128) > 30;

            long key = device.ToInt64();
            string model = GetSonyModelName(productId);
            string deviceName = GetDeviceName(device);
            if (String.IsNullOrWhiteSpace(deviceName)) deviceName = model;

            lock (Sync)
            {
                HidControllerSnapshot previous;
                int pendingMask = 0;
                string pendingDirection = String.Empty;
                if (Snapshots.TryGetValue(key, out previous) && previous != null)
                {
                    pendingMask = previous.PendingMask | (mask & ~previous.Mask);
                    pendingDirection = previous.PendingDirection ?? String.Empty;
                    if (!String.IsNullOrWhiteSpace(direction) &&
                        !String.Equals(direction, previous.Direction, StringComparison.Ordinal) &&
                        String.IsNullOrWhiteSpace(pendingDirection))
                        pendingDirection = direction;
                }
                else
                {
                    pendingMask = mask;
                    pendingDirection = direction ?? String.Empty;
                }

                Snapshots[key] = new HidControllerSnapshot {
                    DeviceHandle = key,
                    Name = deviceName,
                    VendorId = vendorId,
                    ProductId = productId,
                    Mask = mask,
                    Direction = direction,
                    Activity = activity,
                    Family = "PlayStation",
                    Connection = connection,
                    LastSeenUtc = DateTime.UtcNow,
                    PendingMask = pendingMask,
                    PendingDirection = pendingDirection
                };
            }

            // Keep pointer publication outside the navigation-state lock so map
            // access can never stall controller edge consumption.
            PublishPointerState(productId, lx, ly, rx, ry, buttons1, buttons2, buttons3);
        }

        private static float NormalizePointerAxis(byte raw, bool invert)
        {
            float value = invert ? (128.0f - raw) / 127.0f : (raw - 128.0f) / 127.0f;
            if (value < -1.0f) return -1.0f;
            if (value > 1.0f) return 1.0f;
            return value;
        }

        private static uint BuildPointerButtons(byte buttons1, byte buttons2, byte buttons3)
        {
            uint pointerButtons = 0;
            // PlayStation -> generic pointer contract used by the streaming host:
            // Cross click, Circle back, Square keyboard, Triangle auxiliary,
            // L1/R1 large scroll, Options/Menu, Share/View. Bit 0x0100 is
            // intentionally reserved for the global PS/Guide button and is not
            // interpreted as a local streaming-app command.
            if ((buttons1 & 0x20) != 0) pointerButtons |= 0x0001;
            if ((buttons1 & 0x40) != 0) pointerButtons |= 0x0002;
            if ((buttons1 & 0x10) != 0) pointerButtons |= 0x0004;
            if ((buttons1 & 0x80) != 0) pointerButtons |= 0x0008;
            if ((buttons2 & 0x01) != 0) pointerButtons |= 0x0010;
            if ((buttons2 & 0x02) != 0) pointerButtons |= 0x0020;
            if ((buttons2 & 0x20) != 0) pointerButtons |= 0x0040;
            if ((buttons2 & 0x10) != 0) pointerButtons |= 0x0080;
            if ((buttons3 & 0x01) != 0) pointerButtons |= 0x0100;
            return pointerButtons;
        }

        private static void EnsurePointerMap()
        {
            if (pointerMap != null && pointerView != null) return;
            pointerMap = MemoryMappedFile.CreateOrOpen(POINTER_MAP_NAME, POINTER_MAP_SIZE, MemoryMappedFileAccess.ReadWrite);
            pointerView = pointerMap.CreateViewAccessor(0, POINTER_MAP_SIZE, MemoryMappedFileAccess.ReadWrite);
            pointerView.Write(0, POINTER_MAP_MAGIC);
            pointerView.Write(4, 1);
            pointerView.Write(8, 0);
        }

        private static void PublishPointerState(int productId, byte lx, byte ly, byte rx, byte ry, byte buttons1, byte buttons2, byte buttons3)
        {
            try
            {
                lock (PointerSync)
                {
                    EnsurePointerMap();
                    int odd = pointerSequence + 1;
                    if ((odd & 1) == 0) odd++;
                    pointerView.Write(8, odd);
                    System.Threading.Thread.MemoryBarrier();
                    pointerView.Write(0, POINTER_MAP_MAGIC);
                    pointerView.Write(4, 1);
                    pointerView.Write(12, productId);
                    pointerView.Write(16, GetTickCount64());
                    pointerView.Write(24, NormalizePointerAxis(lx, false));
                    pointerView.Write(28, NormalizePointerAxis(ly, true));
                    pointerView.Write(32, NormalizePointerAxis(rx, false));
                    pointerView.Write(36, NormalizePointerAxis(ry, true));
                    pointerView.Write(40, BuildPointerButtons(buttons1, buttons2, buttons3));
                    System.Threading.Thread.MemoryBarrier();
                    pointerSequence = odd + 1;
                    pointerView.Write(8, pointerSequence);
                    pointerView.Flush();
                }
            }
            catch
            {
                // Pointer/Guide publication is supplemental. Never let it
                // destabilize the already-proven Raw HID navigation path.
            }
        }

        private static string GetSonyModelName(int productId)
        {
            switch (productId)
            {
                case 0x0CE6: return "DualSense Wireless Controller";
                case 0x0DF2: return "DualSense Edge Wireless Controller";
                case 0x05C4:
                case 0x09CC: return "DualShock 4 Wireless Controller";
                default: return "PlayStation Wireless Controller";
            }
        }

        private static void GetDeviceIdentity(IntPtr device, out int vendorId, out int productId)
        {
            vendorId = 0;
            productId = 0;
            RID_DEVICE_INFO info = new RID_DEVICE_INFO();
            info.cbSize = (uint)Marshal.SizeOf(typeof(RID_DEVICE_INFO));
            uint size = info.cbSize;
            uint result = GetRawInputDeviceInfo(device, RIDI_DEVICEINFO, ref info, ref size);
            if (result == UInt32.MaxValue || info.dwType != RIM_TYPEHID) return;
            vendorId = (int)info.info.hid.dwVendorId;
            productId = (int)info.info.hid.dwProductId;
        }

        private static string GetDeviceName(IntPtr device)
        {
            uint chars = 0;
            uint result = GetRawInputDeviceInfo(device, RIDI_DEVICENAME, null, ref chars);
            if (result == UInt32.MaxValue || chars == 0 || chars > 4096) return String.Empty;
            StringBuilder builder = new StringBuilder((int)chars + 1);
            result = GetRawInputDeviceInfo(device, RIDI_DEVICENAME, builder, ref chars);
            if (result == UInt32.MaxValue) return String.Empty;
            return builder.ToString();
        }
    }
}

