using System.Runtime.InteropServices;
using Windows.ApplicationModel.DataTransfer;
using WinRT;

namespace NikonLink.Windows.Services;

internal static class DataTransferManagerHelper
{
    private static readonly Guid DataTransferManagerId =
        new(
            0xa5caee9b,
            0x8708,
            0x49d1,
            0x8d,
            0x36,
            0x67,
            0xd2,
            0x5a,
            0x8d,
            0xa0,
            0x0c);

    public static DataTransferManager GetForWindow(nint windowHandle)
    {
        var interop =
            DataTransferManager.As<IDataTransferManagerInterop>();
        var id = DataTransferManagerId;
        var abi = interop.GetForWindow(windowHandle, ref id);
        return MarshalInterface<DataTransferManager>.FromAbi(abi);
    }

    public static void ShowShareUIForWindow(nint windowHandle)
    {
        DataTransferManager
            .As<IDataTransferManagerInterop>()
            .ShowShareUIForWindow(windowHandle);
    }

    [ComImport]
    [Guid("3A3DCD6C-3EAB-43DC-BCDE-45671CE800C8")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IDataTransferManagerInterop
    {
        nint GetForWindow(
            [In] nint appWindow,
            [In] ref Guid interfaceId);

        void ShowShareUIForWindow(nint appWindow);
    }
}
