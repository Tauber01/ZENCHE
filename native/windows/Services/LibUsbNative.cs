using System.Runtime.InteropServices;

namespace NikonLink.Windows.Services;

internal static class LibUsbNative
{
    private const string Library = "libusb-1.0";

    internal const int Success = 0;
    internal const int ErrorAccess = -3;
    internal const int ErrorNotSupported = -12;
    internal const int TransferTypeMask = 0x03;
    internal const int TransferTypeBulk = 0x02;
    internal const byte EndpointIn = 0x80;

    [DllImport(Library, CallingConvention = CallingConvention.Cdecl)]
    internal static extern int libusb_init(out nint context);

    [DllImport(Library, CallingConvention = CallingConvention.Cdecl)]
    internal static extern void libusb_exit(nint context);

    [DllImport(Library, CallingConvention = CallingConvention.Cdecl)]
    internal static extern nint libusb_get_device_list(
        nint context,
        out nint deviceList);

    [DllImport(Library, CallingConvention = CallingConvention.Cdecl)]
    internal static extern void libusb_free_device_list(
        nint deviceList,
        int unrefDevices);

    [DllImport(Library, CallingConvention = CallingConvention.Cdecl)]
    internal static extern int libusb_get_device_descriptor(
        nint device,
        out DeviceDescriptor descriptor);

    [DllImport(Library, CallingConvention = CallingConvention.Cdecl)]
    internal static extern int libusb_open(nint device, out nint handle);

    [DllImport(Library, CallingConvention = CallingConvention.Cdecl)]
    internal static extern void libusb_close(nint handle);

    [DllImport(Library, CallingConvention = CallingConvention.Cdecl)]
    internal static extern int libusb_get_active_config_descriptor(
        nint device,
        out nint configDescriptor);

    [DllImport(Library, CallingConvention = CallingConvention.Cdecl)]
    internal static extern void libusb_free_config_descriptor(nint configDescriptor);

    [DllImport(Library, CallingConvention = CallingConvention.Cdecl)]
    internal static extern int libusb_set_auto_detach_kernel_driver(
        nint handle,
        int enable);

    [DllImport(Library, CallingConvention = CallingConvention.Cdecl)]
    internal static extern int libusb_claim_interface(
        nint handle,
        int interfaceNumber);

    [DllImport(Library, CallingConvention = CallingConvention.Cdecl)]
    internal static extern int libusb_release_interface(
        nint handle,
        int interfaceNumber);

    [DllImport(Library, CallingConvention = CallingConvention.Cdecl)]
    internal static extern int libusb_bulk_transfer(
        nint handle,
        byte endpoint,
        byte[] data,
        int length,
        out int transferred,
        uint timeout);

    [DllImport(Library, CallingConvention = CallingConvention.Cdecl)]
    private static extern nint libusb_error_name(int errorCode);

    internal static string ErrorName(int errorCode)
    {
        var pointer = libusb_error_name(errorCode);
        return pointer == nint.Zero
            ? $"libusb error {errorCode}"
            : Marshal.PtrToStringAnsi(pointer) ?? $"libusb error {errorCode}";
    }

    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    internal struct DeviceDescriptor
    {
        internal byte Length;
        internal byte DescriptorType;
        internal ushort UsbVersion;
        internal byte DeviceClass;
        internal byte DeviceSubClass;
        internal byte DeviceProtocol;
        internal byte MaxPacketSize;
        internal ushort VendorId;
        internal ushort ProductId;
        internal ushort DeviceVersion;
        internal byte ManufacturerIndex;
        internal byte ProductIndex;
        internal byte SerialNumberIndex;
        internal byte ConfigurationCount;
    }

    [StructLayout(LayoutKind.Sequential)]
    internal struct ConfigDescriptor
    {
        internal byte Length;
        internal byte DescriptorType;
        internal ushort TotalLength;
        internal byte InterfaceCount;
        internal byte ConfigurationValue;
        internal byte ConfigurationIndex;
        internal byte Attributes;
        internal byte MaxPower;
        internal nint Interfaces;
        internal nint Extra;
        internal int ExtraLength;
    }

    [StructLayout(LayoutKind.Sequential)]
    internal struct Interface
    {
        internal nint AlternateSettings;
        internal int AlternateSettingCount;
    }

    [StructLayout(LayoutKind.Sequential)]
    internal struct InterfaceDescriptor
    {
        internal byte Length;
        internal byte DescriptorType;
        internal byte InterfaceNumber;
        internal byte AlternateSetting;
        internal byte EndpointCount;
        internal byte InterfaceClass;
        internal byte InterfaceSubClass;
        internal byte InterfaceProtocol;
        internal byte InterfaceIndex;
        internal nint Endpoints;
        internal nint Extra;
        internal int ExtraLength;
    }

    [StructLayout(LayoutKind.Sequential)]
    internal struct EndpointDescriptor
    {
        internal byte Length;
        internal byte DescriptorType;
        internal byte EndpointAddress;
        internal byte Attributes;
        internal ushort MaxPacketSize;
        internal byte Interval;
        internal byte Refresh;
        internal byte SynchronizationAddress;
        internal nint Extra;
        internal int ExtraLength;
    }
}
