using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

namespace HuymaierConsole.Native
{
    public sealed class DisplayModeInfo
    {
        public string DeviceName { get; set; }
        public string FriendlyName { get; set; }
        public bool Primary { get; set; }
        public int Width { get; set; }
        public int Height { get; set; }
        public int Frequency { get; set; }
        public int BitsPerPixel { get; set; }
    }

    public sealed class HdrStatusInfo
    {
        public bool Supported { get; set; }
        public bool Enabled { get; set; }
        public string Api { get; set; }
        public int ResultCode { get; set; }
    }

    public static class DisplayBridge
    {
        private const int ENUM_CURRENT_SETTINGS = -1;
        private const int DISPLAY_DEVICE_ATTACHED_TO_DESKTOP = 0x1;
        private const int DISPLAY_DEVICE_PRIMARY_DEVICE = 0x4;
        private const int DM_BITSPERPEL = 0x00040000;
        private const int DM_PELSWIDTH = 0x00080000;
        private const int DM_PELSHEIGHT = 0x00100000;
        private const int DM_DISPLAYFREQUENCY = 0x00400000;
        private const int CDS_UPDATEREGISTRY = 0x00000001;
        private const int CDS_TEST = 0x00000002;
        private const int DISP_CHANGE_SUCCESSFUL = 0;
        private const uint QDC_ONLY_ACTIVE_PATHS = 0x00000002;
        private const int DISPLAYCONFIG_DEVICE_INFO_GET_SOURCE_NAME = 1;
        private const int DISPLAYCONFIG_DEVICE_INFO_GET_ADVANCED_COLOR_INFO = 9;
        private const int DISPLAYCONFIG_DEVICE_INFO_SET_ADVANCED_COLOR_STATE = 10;
        private const int DISPLAYCONFIG_DEVICE_INFO_GET_ADVANCED_COLOR_INFO_2 = 15;
        private const int DISPLAYCONFIG_DEVICE_INFO_SET_HDR_STATE = 16;
        private const int ERROR_SUCCESS = 0;
        private const int DISPLAYCONFIG_ADVANCED_COLOR_MODE_HDR = 2;

        [StructLayout(LayoutKind.Sequential)]
        private struct POINTL
        {
            public int x;
            public int y;
        }

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        private struct DISPLAY_DEVICE
        {
            public int cb;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string DeviceName;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceString;
            public int StateFlags;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceID;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceKey;
        }

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        private struct DEVMODE
        {
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmDeviceName;
            public short dmSpecVersion;
            public short dmDriverVersion;
            public short dmSize;
            public short dmDriverExtra;
            public int dmFields;
            public POINTL dmPosition;
            public int dmDisplayOrientation;
            public int dmDisplayFixedOutput;
            public short dmColor;
            public short dmDuplex;
            public short dmYResolution;
            public short dmTTOption;
            public short dmCollate;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmFormName;
            public short dmLogPixels;
            public int dmBitsPerPel;
            public int dmPelsWidth;
            public int dmPelsHeight;
            public int dmDisplayFlags;
            public int dmDisplayFrequency;
            public int dmICMMethod;
            public int dmICMIntent;
            public int dmMediaType;
            public int dmDitherType;
            public int dmReserved1;
            public int dmReserved2;
            public int dmPanningWidth;
            public int dmPanningHeight;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct LUID
        {
            public uint LowPart;
            public int HighPart;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct DISPLAYCONFIG_RATIONAL
        {
            public uint Numerator;
            public uint Denominator;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct DISPLAYCONFIG_2DREGION
        {
            public uint cx;
            public uint cy;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct DISPLAYCONFIG_VIDEO_SIGNAL_INFO
        {
            public ulong pixelRate;
            public DISPLAYCONFIG_RATIONAL hSyncFreq;
            public DISPLAYCONFIG_RATIONAL vSyncFreq;
            public DISPLAYCONFIG_2DREGION activeSize;
            public DISPLAYCONFIG_2DREGION totalSize;
            public uint videoStandard;
            public int scanLineOrdering;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct DISPLAYCONFIG_TARGET_MODE
        {
            public DISPLAYCONFIG_VIDEO_SIGNAL_INFO targetVideoSignalInfo;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct DISPLAYCONFIG_SOURCE_MODE
        {
            public uint width;
            public uint height;
            public int pixelFormat;
            public POINTL position;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct RECT
        {
            public int left;
            public int top;
            public int right;
            public int bottom;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct DISPLAYCONFIG_DESKTOP_IMAGE_INFO
        {
            public POINTL PathSourceSize;
            public RECT DesktopImageRegion;
            public RECT DesktopImageClip;
        }

        [StructLayout(LayoutKind.Explicit)]
        private struct DISPLAYCONFIG_MODE_INFO_UNION
        {
            [FieldOffset(0)] public DISPLAYCONFIG_TARGET_MODE targetMode;
            [FieldOffset(0)] public DISPLAYCONFIG_SOURCE_MODE sourceMode;
            [FieldOffset(0)] public DISPLAYCONFIG_DESKTOP_IMAGE_INFO desktopImageInfo;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct DISPLAYCONFIG_MODE_INFO
        {
            public int infoType;
            public uint id;
            public LUID adapterId;
            public DISPLAYCONFIG_MODE_INFO_UNION modeInfo;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct DISPLAYCONFIG_PATH_SOURCE_INFO
        {
            public LUID adapterId;
            public uint id;
            public uint modeInfoIdx;
            public uint statusFlags;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct DISPLAYCONFIG_PATH_TARGET_INFO
        {
            public LUID adapterId;
            public uint id;
            public uint modeInfoIdx;
            public int outputTechnology;
            public int rotation;
            public int scaling;
            public DISPLAYCONFIG_RATIONAL refreshRate;
            public int scanLineOrdering;
            [MarshalAs(UnmanagedType.Bool)] public bool targetAvailable;
            public uint statusFlags;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct DISPLAYCONFIG_PATH_INFO
        {
            public DISPLAYCONFIG_PATH_SOURCE_INFO sourceInfo;
            public DISPLAYCONFIG_PATH_TARGET_INFO targetInfo;
            public uint flags;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct DISPLAYCONFIG_DEVICE_INFO_HEADER
        {
            public int type;
            public uint size;
            public LUID adapterId;
            public uint id;
        }

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        private struct DISPLAYCONFIG_SOURCE_DEVICE_NAME
        {
            public DISPLAYCONFIG_DEVICE_INFO_HEADER header;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string viewGdiDeviceName;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct DISPLAYCONFIG_GET_ADVANCED_COLOR_INFO
        {
            public DISPLAYCONFIG_DEVICE_INFO_HEADER header;
            public uint value;
            public int colorEncoding;
            public uint bitsPerColorChannel;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct DISPLAYCONFIG_SET_ADVANCED_COLOR_STATE
        {
            public DISPLAYCONFIG_DEVICE_INFO_HEADER header;
            public uint value;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct DISPLAYCONFIG_GET_ADVANCED_COLOR_INFO_2
        {
            public DISPLAYCONFIG_DEVICE_INFO_HEADER header;
            public uint value;
            public int colorEncoding;
            public uint bitsPerColorChannel;
            public int activeColorMode;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct DISPLAYCONFIG_SET_HDR_STATE
        {
            public DISPLAYCONFIG_DEVICE_INFO_HEADER header;
            public uint value;
        }

        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        private static extern bool EnumDisplayDevices(string lpDevice, uint iDevNum, ref DISPLAY_DEVICE lpDisplayDevice, uint dwFlags);

        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        private static extern bool EnumDisplaySettings(string deviceName, int modeNum, ref DEVMODE devMode);

        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        private static extern int ChangeDisplaySettingsEx(string lpszDeviceName, ref DEVMODE lpDevMode, IntPtr hwnd, int dwflags, IntPtr lParam);

        [DllImport("user32.dll")]
        private static extern int GetDisplayConfigBufferSizes(uint flags, out uint numPathArrayElements, out uint numModeInfoArrayElements);

        [DllImport("user32.dll")]
        private static extern int QueryDisplayConfig(uint flags, ref uint numPathArrayElements, [Out] DISPLAYCONFIG_PATH_INFO[] pathInfoArray, ref uint numModeInfoArrayElements, [Out] DISPLAYCONFIG_MODE_INFO[] modeInfoArray, IntPtr currentTopologyId);

        [DllImport("user32.dll")]
        private static extern int DisplayConfigGetDeviceInfo(IntPtr requestPacket);

        [DllImport("user32.dll")]
        private static extern int DisplayConfigSetDeviceInfo(IntPtr setPacket);

        private static DEVMODE NewDevMode()
        {
            DEVMODE mode = new DEVMODE();
            mode.dmDeviceName = new string('\0', 32);
            mode.dmFormName = new string('\0', 32);
            mode.dmSize = (short)Marshal.SizeOf(typeof(DEVMODE));
            return mode;
        }

        public static DisplayModeInfo[] GetDisplays()
        {
            List<DisplayModeInfo> result = new List<DisplayModeInfo>();
            uint index = 0;
            while (true)
            {
                DISPLAY_DEVICE display = new DISPLAY_DEVICE();
                display.cb = Marshal.SizeOf(typeof(DISPLAY_DEVICE));
                if (!EnumDisplayDevices(null, index, ref display, 0)) break;
                index++;
                if ((display.StateFlags & DISPLAY_DEVICE_ATTACHED_TO_DESKTOP) == 0) continue;

                DEVMODE current = NewDevMode();
                if (!EnumDisplaySettings(display.DeviceName, ENUM_CURRENT_SETTINGS, ref current)) continue;

                string friendly = String.IsNullOrEmpty(display.DeviceString) ? display.DeviceName : display.DeviceString;
                DISPLAY_DEVICE monitor = new DISPLAY_DEVICE();
                monitor.cb = Marshal.SizeOf(typeof(DISPLAY_DEVICE));
                if (EnumDisplayDevices(display.DeviceName, 0, ref monitor, 0) && !String.IsNullOrEmpty(monitor.DeviceString))
                {
                    friendly = monitor.DeviceString;
                }

                DisplayModeInfo item = new DisplayModeInfo();
                item.DeviceName = display.DeviceName;
                item.FriendlyName = friendly;
                item.Primary = (display.StateFlags & DISPLAY_DEVICE_PRIMARY_DEVICE) != 0;
                item.Width = current.dmPelsWidth;
                item.Height = current.dmPelsHeight;
                item.Frequency = current.dmDisplayFrequency;
                item.BitsPerPixel = current.dmBitsPerPel;
                result.Add(item);
            }
            return result.ToArray();
        }

        public static DisplayModeInfo[] GetModes(string deviceName)
        {
            List<DisplayModeInfo> result = new List<DisplayModeInfo>();
            HashSet<string> seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            int index = 0;
            while (true)
            {
                DEVMODE mode = NewDevMode();
                if (!EnumDisplaySettings(deviceName, index, ref mode)) break;
                index++;
                if (mode.dmBitsPerPel < 32 || mode.dmPelsWidth < 640 || mode.dmPelsHeight < 480 || mode.dmDisplayFrequency <= 0) continue;
                string key = mode.dmPelsWidth + "x" + mode.dmPelsHeight + "@" + mode.dmDisplayFrequency;
                if (!seen.Add(key)) continue;
                DisplayModeInfo item = new DisplayModeInfo();
                item.DeviceName = deviceName;
                item.Width = mode.dmPelsWidth;
                item.Height = mode.dmPelsHeight;
                item.Frequency = mode.dmDisplayFrequency;
                item.BitsPerPixel = mode.dmBitsPerPel;
                result.Add(item);
            }
            result.Sort(delegate(DisplayModeInfo a, DisplayModeInfo b)
            {
                int pixels = (a.Width * a.Height).CompareTo(b.Width * b.Height);
                if (pixels != 0) return pixels;
                return a.Frequency.CompareTo(b.Frequency);
            });
            return result.ToArray();
        }

        public static int ApplyMode(string deviceName, int width, int height, int frequency)
        {
            DEVMODE mode = NewDevMode();
            if (!EnumDisplaySettings(deviceName, ENUM_CURRENT_SETTINGS, ref mode)) return -100;
            mode.dmPelsWidth = width;
            mode.dmPelsHeight = height;
            mode.dmDisplayFrequency = frequency;
            mode.dmFields = DM_PELSWIDTH | DM_PELSHEIGHT | DM_DISPLAYFREQUENCY | DM_BITSPERPEL;
            int test = ChangeDisplaySettingsEx(deviceName, ref mode, IntPtr.Zero, CDS_TEST, IntPtr.Zero);
            if (test != DISP_CHANGE_SUCCESSFUL) return test;
            return ChangeDisplaySettingsEx(deviceName, ref mode, IntPtr.Zero, CDS_UPDATEREGISTRY, IntPtr.Zero);
        }

        private static bool TryGetTarget(string deviceName, out LUID adapterId, out uint targetId)
        {
            adapterId = new LUID();
            targetId = 0;
            uint pathCount;
            uint modeCount;
            int result = GetDisplayConfigBufferSizes(QDC_ONLY_ACTIVE_PATHS, out pathCount, out modeCount);
            if (result != ERROR_SUCCESS || pathCount == 0) return false;

            DISPLAYCONFIG_PATH_INFO[] paths = new DISPLAYCONFIG_PATH_INFO[(int)pathCount];
            DISPLAYCONFIG_MODE_INFO[] modes = new DISPLAYCONFIG_MODE_INFO[(int)modeCount];
            result = QueryDisplayConfig(QDC_ONLY_ACTIVE_PATHS, ref pathCount, paths, ref modeCount, modes, IntPtr.Zero);
            if (result != ERROR_SUCCESS) return false;

            for (int i = 0; i < pathCount; i++)
            {
                DISPLAYCONFIG_SOURCE_DEVICE_NAME source = new DISPLAYCONFIG_SOURCE_DEVICE_NAME();
                source.header.type = DISPLAYCONFIG_DEVICE_INFO_GET_SOURCE_NAME;
                source.header.size = (uint)Marshal.SizeOf(typeof(DISPLAYCONFIG_SOURCE_DEVICE_NAME));
                source.header.adapterId = paths[i].sourceInfo.adapterId;
                source.header.id = paths[i].sourceInfo.id;
                source.viewGdiDeviceName = new string('\0', 32);

                IntPtr ptr = Marshal.AllocHGlobal(Marshal.SizeOf(typeof(DISPLAYCONFIG_SOURCE_DEVICE_NAME)));
                try
                {
                    Marshal.StructureToPtr(source, ptr, false);
                    result = DisplayConfigGetDeviceInfo(ptr);
                    if (result != ERROR_SUCCESS) continue;
                    source = (DISPLAYCONFIG_SOURCE_DEVICE_NAME)Marshal.PtrToStructure(ptr, typeof(DISPLAYCONFIG_SOURCE_DEVICE_NAME));
                    if (String.Equals(source.viewGdiDeviceName, deviceName, StringComparison.OrdinalIgnoreCase))
                    {
                        adapterId = paths[i].targetInfo.adapterId;
                        targetId = paths[i].targetInfo.id;
                        return true;
                    }
                }
                finally
                {
                    Marshal.FreeHGlobal(ptr);
                }
            }
            return false;
        }

        private static int GetDeviceInfo<T>(ref T packet) where T : struct
        {
            int size = Marshal.SizeOf(typeof(T));
            IntPtr ptr = Marshal.AllocHGlobal(size);
            try
            {
                Marshal.StructureToPtr(packet, ptr, false);
                int result = DisplayConfigGetDeviceInfo(ptr);
                packet = (T)Marshal.PtrToStructure(ptr, typeof(T));
                return result;
            }
            finally
            {
                Marshal.FreeHGlobal(ptr);
            }
        }

        private static int SetDeviceInfo<T>(ref T packet) where T : struct
        {
            int size = Marshal.SizeOf(typeof(T));
            IntPtr ptr = Marshal.AllocHGlobal(size);
            try
            {
                Marshal.StructureToPtr(packet, ptr, false);
                return DisplayConfigSetDeviceInfo(ptr);
            }
            finally
            {
                Marshal.FreeHGlobal(ptr);
            }
        }

        public static HdrStatusInfo GetHdrStatus(string deviceName)
        {
            HdrStatusInfo status = new HdrStatusInfo();
            status.Api = "Unavailable";
            LUID adapterId;
            uint targetId;
            if (!TryGetTarget(deviceName, out adapterId, out targetId))
            {
                status.ResultCode = -200;
                return status;
            }

            DISPLAYCONFIG_GET_ADVANCED_COLOR_INFO_2 info2 = new DISPLAYCONFIG_GET_ADVANCED_COLOR_INFO_2();
            info2.header.type = DISPLAYCONFIG_DEVICE_INFO_GET_ADVANCED_COLOR_INFO_2;
            info2.header.size = (uint)Marshal.SizeOf(typeof(DISPLAYCONFIG_GET_ADVANCED_COLOR_INFO_2));
            info2.header.adapterId = adapterId;
            info2.header.id = targetId;
            int result = GetDeviceInfo(ref info2);
            if (result == ERROR_SUCCESS)
            {
                status.Supported = (info2.value & (1u << 4)) != 0;
                status.Enabled = info2.activeColorMode == DISPLAYCONFIG_ADVANCED_COLOR_MODE_HDR || (info2.value & (1u << 5)) != 0;
                status.Api = "Windows 11 HDR";
                status.ResultCode = result;
                return status;
            }

            DISPLAYCONFIG_GET_ADVANCED_COLOR_INFO info = new DISPLAYCONFIG_GET_ADVANCED_COLOR_INFO();
            info.header.type = DISPLAYCONFIG_DEVICE_INFO_GET_ADVANCED_COLOR_INFO;
            info.header.size = (uint)Marshal.SizeOf(typeof(DISPLAYCONFIG_GET_ADVANCED_COLOR_INFO));
            info.header.adapterId = adapterId;
            info.header.id = targetId;
            result = GetDeviceInfo(ref info);
            status.ResultCode = result;
            if (result == ERROR_SUCCESS)
            {
                status.Supported = (info.value & 1u) != 0;
                status.Enabled = (info.value & 2u) != 0;
                status.Api = "Advanced Color";
            }
            return status;
        }

        public static int SetHdrState(string deviceName, bool enabled)
        {
            LUID adapterId;
            uint targetId;
            if (!TryGetTarget(deviceName, out adapterId, out targetId)) return -200;

            DISPLAYCONFIG_SET_HDR_STATE hdr = new DISPLAYCONFIG_SET_HDR_STATE();
            hdr.header.type = DISPLAYCONFIG_DEVICE_INFO_SET_HDR_STATE;
            hdr.header.size = (uint)Marshal.SizeOf(typeof(DISPLAYCONFIG_SET_HDR_STATE));
            hdr.header.adapterId = adapterId;
            hdr.header.id = targetId;
            hdr.value = enabled ? 1u : 0u;
            int result = SetDeviceInfo(ref hdr);
            if (result == ERROR_SUCCESS) return result;

            DISPLAYCONFIG_SET_ADVANCED_COLOR_STATE advanced = new DISPLAYCONFIG_SET_ADVANCED_COLOR_STATE();
            advanced.header.type = DISPLAYCONFIG_DEVICE_INFO_SET_ADVANCED_COLOR_STATE;
            advanced.header.size = (uint)Marshal.SizeOf(typeof(DISPLAYCONFIG_SET_ADVANCED_COLOR_STATE));
            advanced.header.adapterId = adapterId;
            advanced.header.id = targetId;
            advanced.value = enabled ? 1u : 0u;
            return SetDeviceInfo(ref advanced);
        }
    }
}
