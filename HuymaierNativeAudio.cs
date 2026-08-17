using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

namespace HuymaierConsole.Native
{
    public sealed class AudioEndpointInfo
    {
        public string Id { get; set; }
        public string Name { get; set; }
        public bool IsDefault { get; set; }
        public int State { get; set; }
        public override string ToString() { return Name; }
    }

    public static class AudioBridge
    {
        private const int DEVICE_STATE_ACTIVE = 0x1;
        private static PROPERTYKEY PKEY_Device_FriendlyName = new PROPERTYKEY
        {
            fmtid = new Guid("A45C254E-DF1C-4EFD-8020-67D146A850E0"),
            pid = 14
        };

        public static AudioEndpointInfo[] GetRenderEndpoints()
        {
            var results = new List<AudioEndpointInfo>();
            IMMDeviceEnumerator enumerator = null;
            IMMDeviceCollection collection = null;
            IMMDevice defaultDevice = null;
            string defaultId = null;
            try
            {
                enumerator = (IMMDeviceEnumerator)new MMDeviceEnumeratorComObject();
                try
                {
                    enumerator.GetDefaultAudioEndpoint(EDataFlow.eRender, ERole.eMultimedia, out defaultDevice);
                    if (defaultDevice != null) defaultDevice.GetId(out defaultId);
                }
                catch { }

                enumerator.EnumAudioEndpoints(EDataFlow.eRender, DEVICE_STATE_ACTIVE, out collection);
                uint count;
                collection.GetCount(out count);
                for (uint i = 0; i < count; i++)
                {
                    IMMDevice device;
                    collection.Item(i, out device);
                    if (device == null) continue;
                    try
                    {
                        string id;
                        device.GetId(out id);
                        IPropertyStore store;
                        device.OpenPropertyStore(0, out store);
                        PROPVARIANT value;
                        store.GetValue(ref PKEY_Device_FriendlyName, out value);
                        string name = value.GetString();
                        value.Clear();
                        results.Add(new AudioEndpointInfo
                        {
                            Id = id,
                            Name = String.IsNullOrWhiteSpace(name) ? "Audio output" : name,
                            IsDefault = String.Equals(id, defaultId, StringComparison.OrdinalIgnoreCase),
                            State = DEVICE_STATE_ACTIVE
                        });
                        if (store != null) Marshal.ReleaseComObject(store);
                    }
                    finally { Marshal.ReleaseComObject(device); }
                }
            }
            finally
            {
                if (defaultDevice != null) Marshal.ReleaseComObject(defaultDevice);
                if (collection != null) Marshal.ReleaseComObject(collection);
                if (enumerator != null) Marshal.ReleaseComObject(enumerator);
            }
            return results.ToArray();
        }

        public static string GetDefaultEndpointId()
        {
            IMMDeviceEnumerator enumerator = null;
            IMMDevice device = null;
            try
            {
                enumerator = (IMMDeviceEnumerator)new MMDeviceEnumeratorComObject();
                int hr = enumerator.GetDefaultAudioEndpoint(EDataFlow.eRender, ERole.eMultimedia, out device);
                if (hr != 0 || device == null) return String.Empty;
                string id;
                device.GetId(out id);
                return id ?? String.Empty;
            }
            catch { return String.Empty; }
            finally
            {
                if (device != null) Marshal.ReleaseComObject(device);
                if (enumerator != null) Marshal.ReleaseComObject(enumerator);
            }
        }

        public static float GetMasterVolume()
        {
            IAudioEndpointVolume volume = GetDefaultVolume();
            if (volume == null) return 0;
            try { float value; volume.GetMasterVolumeLevelScalar(out value); return value; }
            finally { Marshal.ReleaseComObject(volume); }
        }

        public static bool GetMute()
        {
            IAudioEndpointVolume volume = GetDefaultVolume();
            if (volume == null) return false;
            try { bool value; volume.GetMute(out value); return value; }
            finally { Marshal.ReleaseComObject(volume); }
        }

        public static void SetMasterVolume(float value)
        {
            IAudioEndpointVolume volume = GetDefaultVolume();
            if (volume == null) return;
            try
            {
                value = Math.Max(0f, Math.Min(1f, value));
                Guid context = Guid.Empty;
                volume.SetMasterVolumeLevelScalar(value, ref context);
            }
            finally { Marshal.ReleaseComObject(volume); }
        }

        public static void SetMute(bool muted)
        {
            IAudioEndpointVolume volume = GetDefaultVolume();
            if (volume == null) return;
            try { Guid context = Guid.Empty; volume.SetMute(muted, ref context); }
            finally { Marshal.ReleaseComObject(volume); }
        }

        public static bool SetDefaultEndpoint(string endpointId)
        {
            if (String.IsNullOrWhiteSpace(endpointId)) return false;
            try
            {
                IPolicyConfig policy = (IPolicyConfig)new PolicyConfigClient();
                policy.SetDefaultEndpoint(endpointId, ERole.eConsole);
                policy.SetDefaultEndpoint(endpointId, ERole.eMultimedia);
                policy.SetDefaultEndpoint(endpointId, ERole.eCommunications);
                Marshal.ReleaseComObject(policy);
                return true;
            }
            catch { return false; }
        }

        private static IAudioEndpointVolume GetDefaultVolume()
        {
            IMMDeviceEnumerator enumerator = null;
            IMMDevice device = null;
            try
            {
                enumerator = (IMMDeviceEnumerator)new MMDeviceEnumeratorComObject();
                enumerator.GetDefaultAudioEndpoint(EDataFlow.eRender, ERole.eMultimedia, out device);
                Guid iid = typeof(IAudioEndpointVolume).GUID;
                object endpoint;
                device.Activate(ref iid, 23, IntPtr.Zero, out endpoint);
                return (IAudioEndpointVolume)endpoint;
            }
            finally
            {
                if (device != null) Marshal.ReleaseComObject(device);
                if (enumerator != null) Marshal.ReleaseComObject(enumerator);
            }
        }
    }

    internal enum EDataFlow { eRender, eCapture, eAll, EDataFlow_enum_count }
    internal enum ERole { eConsole, eMultimedia, eCommunications, ERole_enum_count }

    [ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]
    internal class MMDeviceEnumeratorComObject { }

    [ComImport, Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IMMDeviceEnumerator
    {
        [PreserveSig]
        int EnumAudioEndpoints(EDataFlow dataFlow, int dwStateMask, out IMMDeviceCollection ppDevices);
        [PreserveSig]
        int GetDefaultAudioEndpoint(EDataFlow dataFlow, ERole role, out IMMDevice ppEndpoint);
        [PreserveSig]
        int GetDevice([MarshalAs(UnmanagedType.LPWStr)] string pwstrId, out IMMDevice ppDevice);
        [PreserveSig]
        int RegisterEndpointNotificationCallback(IntPtr pClient);
        [PreserveSig]
        int UnregisterEndpointNotificationCallback(IntPtr pClient);
    }

    [ComImport, Guid("0BD7A1BE-7A1A-44DB-8397-C0A9D6319F86"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IMMDeviceCollection
    {
        [PreserveSig]
        int GetCount(out uint pcDevices);
        [PreserveSig]
        int Item(uint nDevice, out IMMDevice ppDevice);
    }

    [ComImport, Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IMMDevice
    {
        [PreserveSig]
        int Activate(ref Guid iid, int dwClsCtx, IntPtr pActivationParams, [MarshalAs(UnmanagedType.IUnknown)] out object ppInterface);
        [PreserveSig]
        int OpenPropertyStore(int stgmAccess, out IPropertyStore ppProperties);
        [PreserveSig]
        int GetId([MarshalAs(UnmanagedType.LPWStr)] out string ppstrId);
        [PreserveSig]
        int GetState(out int pdwState);
    }

    [ComImport, Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IPropertyStore
    {
        [PreserveSig]
        int GetCount(out uint cProps);
        [PreserveSig]
        int GetAt(uint iProp, out PROPERTYKEY pkey);
        [PreserveSig]
        int GetValue(ref PROPERTYKEY key, out PROPVARIANT pv);
        [PreserveSig]
        int SetValue(ref PROPERTYKEY key, ref PROPVARIANT propvar);
        [PreserveSig]
        int Commit();
    }

    [ComImport, Guid("5CDF2C82-841E-4546-9722-0CF74078229A"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IAudioEndpointVolume
    {
        [PreserveSig]
        int RegisterControlChangeNotify(IntPtr pNotify);
        [PreserveSig]
        int UnregisterControlChangeNotify(IntPtr pNotify);
        [PreserveSig]
        int GetChannelCount(out uint channelCount);
        [PreserveSig]
        int SetMasterVolumeLevel(float levelDB, ref Guid eventContext);
        [PreserveSig]
        int SetMasterVolumeLevelScalar(float level, ref Guid eventContext);
        [PreserveSig]
        int GetMasterVolumeLevel(out float levelDB);
        [PreserveSig]
        int GetMasterVolumeLevelScalar(out float level);
        [PreserveSig]
        int SetChannelVolumeLevel(uint channelNumber, float levelDB, ref Guid eventContext);
        [PreserveSig]
        int SetChannelVolumeLevelScalar(uint channelNumber, float level, ref Guid eventContext);
        [PreserveSig]
        int GetChannelVolumeLevel(uint channelNumber, out float levelDB);
        [PreserveSig]
        int GetChannelVolumeLevelScalar(uint channelNumber, out float level);
        [PreserveSig]
        int SetMute([MarshalAs(UnmanagedType.Bool)] bool isMuted, ref Guid eventContext);
        [PreserveSig]
        int GetMute([MarshalAs(UnmanagedType.Bool)] out bool isMuted);
        [PreserveSig]
        int GetVolumeStepInfo(out uint step, out uint stepCount);
        [PreserveSig]
        int VolumeStepUp(ref Guid eventContext);
        [PreserveSig]
        int VolumeStepDown(ref Guid eventContext);
        [PreserveSig]
        int QueryHardwareSupport(out uint hardwareSupportMask);
        [PreserveSig]
        int GetVolumeRange(out float volumeMinDB, out float volumeMaxDB, out float volumeIncrementDB);
    }

    [ComImport, Guid("870AF99C-171D-4F9E-AF0D-E63DF40C2BC9")]
    internal class PolicyConfigClient { }

    [ComImport, Guid("F8679F50-850A-41CF-9C72-430F290290C8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IPolicyConfig
    {
        [PreserveSig]
        int GetMixFormat([MarshalAs(UnmanagedType.LPWStr)] string deviceId, IntPtr format);
        [PreserveSig]
        int GetDeviceFormat([MarshalAs(UnmanagedType.LPWStr)] string deviceId, int defaultFormat, IntPtr format);
        [PreserveSig]
        int ResetDeviceFormat([MarshalAs(UnmanagedType.LPWStr)] string deviceId);
        [PreserveSig]
        int SetDeviceFormat([MarshalAs(UnmanagedType.LPWStr)] string deviceId, IntPtr endpointFormat, IntPtr mixFormat);
        [PreserveSig]
        int GetProcessingPeriod([MarshalAs(UnmanagedType.LPWStr)] string deviceId, int defaultPeriod, IntPtr defaultPeriodValue, IntPtr minimumPeriodValue);
        [PreserveSig]
        int SetProcessingPeriod([MarshalAs(UnmanagedType.LPWStr)] string deviceId, IntPtr period);
        [PreserveSig]
        int GetShareMode([MarshalAs(UnmanagedType.LPWStr)] string deviceId, IntPtr mode);
        [PreserveSig]
        int SetShareMode([MarshalAs(UnmanagedType.LPWStr)] string deviceId, IntPtr mode);
        [PreserveSig]
        int GetPropertyValue([MarshalAs(UnmanagedType.LPWStr)] string deviceId, ref PROPERTYKEY key, IntPtr value);
        [PreserveSig]
        int SetPropertyValue([MarshalAs(UnmanagedType.LPWStr)] string deviceId, ref PROPERTYKEY key, IntPtr value);
        [PreserveSig]
        int SetDefaultEndpoint([MarshalAs(UnmanagedType.LPWStr)] string deviceId, ERole role);
        [PreserveSig]
        int SetEndpointVisibility([MarshalAs(UnmanagedType.LPWStr)] string deviceId, int visible);
    }

    [StructLayout(LayoutKind.Sequential)]
    internal struct PROPERTYKEY { public Guid fmtid; public int pid; }

    [StructLayout(LayoutKind.Explicit)]
    internal struct PROPVARIANT
    {
        [FieldOffset(0)] public ushort vt;
        [FieldOffset(8)] public IntPtr pointerValue;
        public string GetString() { return vt == 31 && pointerValue != IntPtr.Zero ? Marshal.PtrToStringUni(pointerValue) : String.Empty; }
        public void Clear() { PropVariantClear(ref this); }
        [DllImport("ole32.dll")] private static extern int PropVariantClear(ref PROPVARIANT pvar);
    }
}
