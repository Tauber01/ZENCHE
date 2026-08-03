using System.Runtime.InteropServices;
using System.Text;
using System.IO;

namespace NikonLink.Windows.Services;

internal sealed record NikonOfficialSdkDevice(
    uint Id,
    string Name,
    bool Available,
    string Version);

internal sealed record NikonOfficialSdkStatus(
    bool RemoteLoaded,
    bool RemoteReady,
    string RemoteDetail,
    bool ImageLoaded,
    bool ImageReady,
    string ImageDetail,
    IReadOnlyList<NikonOfficialSdkDevice> Devices)
{
    public static NikonOfficialSdkStatus Pending { get; } = new(
        false,
        false,
        "等待检测",
        false,
        false,
        "等待检测",
        []);

    public string Summary => RemoteReady && ImageReady
        ? "Remote SDK 2.0.0 与 Image SDK 1.46.0 已就绪"
        : RemoteLoaded || ImageLoaded
            ? "官方 SDK 已安装，部分组件初始化失败"
            : "官方 SDK 运行库未载入";
}

internal sealed class NikonOfficialSdkService
{
    private readonly string _sdkRoot = Path.Combine(
        AppContext.BaseDirectory,
        "NikonSDK");

    public NikonOfficialSdkStatus Status { get; private set; } =
        NikonOfficialSdkStatus.Pending;

    public NikonOfficialSdkStatus Probe(bool allowRemoteProbe = true)
    {
        var remote = ProbeRemote(allowRemoteProbe);
        var image = ProbeImage();
        Status = new NikonOfficialSdkStatus(
            remote.Loaded,
            remote.Ready,
            remote.Detail,
            image.Loaded,
            image.Ready,
            image.Detail,
            remote.Devices);
        return Status;
    }

    private RemoteProbe ProbeRemote(bool allowProbe)
    {
        var runtime = Path.Combine(_sdkRoot, "Remote");
        var libraryPath = Path.Combine(runtime, "ControlServiceLayer.dll");
        if (!File.Exists(libraryPath))
        {
            return new RemoteProbe(
                false,
                false,
                "Remote SDK 运行库未找到",
                []);
        }
        InstallRemoteConfiguration(runtime);
        if (!allowProbe)
        {
            return new RemoteProbe(
                true,
                true,
                "SDK 已安装 · 断开当前 USB 会话后可重新检测",
                []);
        }

        nint library = 0;
        nint deviceList = 0;
        InitializeSdkDelegate? initialize = null;
        FreeSdkDelegate? freeSdk = null;
        var initialized = false;
        AllocateMemoryDelegate allocate = size =>
            Marshal.AllocHGlobal(checked((nint)size));
        FreeMemoryDelegate free = pointer =>
        {
            if (pointer != 0) Marshal.FreeHGlobal(pointer);
        };
        UiRequestDelegate uiRequest = (_, _) => 0;
        EventDelegate eventCallback = (_, _, _) => { };
        ProgressDelegate progress = (_, _, _, _, _) => { };
        DataDelegate data = (_, _, _) => 0;
        LiveViewDelegate liveView = (_, _) => { };
        try
        {
            using var searchPath = new DllDirectoryScope(runtime);
            library = NativeLibrary.Load(libraryPath);
            initialize = Marshal.GetDelegateForFunctionPointer<InitializeSdkDelegate>(
                NativeLibrary.GetExport(library, "InitializeSDK"));
            freeSdk = Marshal.GetDelegateForFunctionPointer<FreeSdkDelegate>(
                NativeLibrary.GetExport(library, "FreeSDK"));
            var callbacks = new CallbackRegistration
            {
                UiRequest = Marshal.GetFunctionPointerForDelegate(uiRequest),
                Event = Marshal.GetFunctionPointerForDelegate(eventCallback),
                Progress = Marshal.GetFunctionPointerForDelegate(progress),
                Data = Marshal.GetFunctionPointerForDelegate(data),
                LiveViewData = Marshal.GetFunctionPointerForDelegate(liveView),
                Reference = 0
            };
            var result = initialize(
                allocate,
                free,
                ref callbacks,
                out deviceList,
                0);
            initialized = result == 0;
            if (result != 0)
            {
                return new RemoteProbe(
                    true,
                    false,
                    $"初始化失败 · 错误码 {result}",
                    []);
            }

            var devices = ReadDevices(deviceList);
            return new RemoteProbe(
                true,
                true,
                devices.Count == 0
                    ? "SDK 已就绪 · 未发现空闲尼康相机"
                    : $"SDK 已发现 {devices.Count} 台尼康相机",
                devices);
        }
        catch (Exception error)
        {
            return new RemoteProbe(
                true,
                false,
                $"Remote SDK 加载失败 · {error.Message}",
                []);
        }
        finally
        {
            if (initialized && freeSdk is not null)
            {
                try { freeSdk(); }
                catch { }
            }
            if (deviceList != 0)
            {
                try
                {
                    var list = Marshal.PtrToStructure<DeviceList>(deviceList);
                    if (list.Devices != 0) Marshal.FreeHGlobal(list.Devices);
                    Marshal.FreeHGlobal(deviceList);
                }
                catch { }
            }
            if (library != 0) NativeLibrary.Free(library);
            GC.KeepAlive(initialize);
            GC.KeepAlive(freeSdk);
            GC.KeepAlive(allocate);
            GC.KeepAlive(free);
            GC.KeepAlive(uiRequest);
            GC.KeepAlive(eventCallback);
            GC.KeepAlive(progress);
            GC.KeepAlive(data);
            GC.KeepAlive(liveView);
        }
    }

    private ImageProbe ProbeImage()
    {
        var runtime = Path.Combine(_sdkRoot, "Image");
        var libraryPath = Path.Combine(runtime, "NkImgSDK.dll");
        if (!File.Exists(libraryPath))
        {
            return new ImageProbe(
                false,
                false,
                "Image SDK 运行库未找到");
        }

        nint library = 0;
        nint parametersPointer = 0;
        nint sdkLibraryPointer = 0;
        var swapFile = Path.Combine(
            Path.GetTempPath(),
            $"zenche-image-sdk-{Environment.ProcessId}.tmp");
        var originalDirectory = Environment.CurrentDirectory;
        try
        {
            using var searchPath = new DllDirectoryScope(runtime);
            Environment.CurrentDirectory = runtime;
            library = NativeLibrary.Load(libraryPath);
            var entry = Marshal.GetDelegateForFunctionPointer<ImageEntryDelegate>(
                NativeLibrary.GetExport(library, "Nkfl_Entry"));
            sdkLibraryPointer = Marshal.AllocHGlobal(nint.Size);
            Marshal.WriteIntPtr(sdkLibraryPointer, 0);
            var profilePath = Path.Combine(runtime, "Profiles");
            var parameters = new ImageLibraryParameters
            {
                Size = (uint)Marshal.SizeOf<ImageLibraryParameters>(),
                Version = 0x01000000,
                VirtualMemoryMegabytes = 512,
                Library = sdkLibraryPointer,
                VirtualMemoryFile = FixedAnsi(swapFile, 260),
                DefaultProfilePath = FixedAnsi(profilePath, 260)
            };
            parametersPointer = Marshal.AllocHGlobal(
                Marshal.SizeOf<ImageLibraryParameters>());
            Marshal.StructureToPtr(parameters, parametersPointer, false);
            var result = entry(0x0001, parametersPointer);
            if (result == 0) entry(0x0002, 0);
            return new ImageProbe(
                true,
                result == 0,
                result == 0
                    ? "NEF / NRW 引擎已完成官方初始化"
                    : $"初始化失败 · 错误码 {result}");
        }
        catch (Exception error)
        {
            return new ImageProbe(
                true,
                false,
                $"Image SDK 加载失败 · {error.Message}");
        }
        finally
        {
            Environment.CurrentDirectory = originalDirectory;
            if (parametersPointer != 0) Marshal.FreeHGlobal(parametersPointer);
            if (sdkLibraryPointer != 0) Marshal.FreeHGlobal(sdkLibraryPointer);
            if (library != 0) NativeLibrary.Free(library);
            try { if (File.Exists(swapFile)) File.Delete(swapFile); }
            catch { }
        }
    }

    private static List<NikonOfficialSdkDevice> ReadDevices(nint pointer)
    {
        if (pointer == 0) return [];
        var list = Marshal.PtrToStructure<DeviceList>(pointer);
        if (list.Devices == 0 || list.Elements == 0) return [];
        var result = new List<NikonOfficialSdkDevice>();
        var size = Marshal.SizeOf<DeviceInfo>();
        var count = Math.Min(list.Elements, 64u);
        for (var index = 0u; index < count; index++)
        {
            var address = list.Devices + checked((int)(index * size));
            var item = Marshal.PtrToStructure<DeviceInfo>(address);
            result.Add(new NikonOfficialSdkDevice(
                item.Id,
                item.Name.TrimEnd('\0'),
                item.Available,
                item.Version.TrimEnd('\0')));
        }
        return result;
    }

    private static byte[] FixedAnsi(string value, int length)
    {
        var result = new byte[length];
        var source = Encoding.UTF8.GetBytes(value);
        Array.Copy(source, result, Math.Min(source.Length, length - 1));
        return result;
    }

    private static void InstallRemoteConfiguration(string runtime)
    {
        var destination = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "Nikon",
            "NXTether");
        Directory.CreateDirectory(destination);
        foreach (var name in new[]
                 {
                     "DC_PTP_Config.config",
                     "MaidLayer.config",
                     "RangeValue.config"
                 })
        {
            var source = Path.Combine(runtime, name);
            if (File.Exists(source))
            {
                File.Copy(source, Path.Combine(destination, name), true);
            }
        }
    }

    private sealed record RemoteProbe(
        bool Loaded,
        bool Ready,
        string Detail,
        IReadOnlyList<NikonOfficialSdkDevice> Devices);

    private sealed record ImageProbe(
        bool Loaded,
        bool Ready,
        string Detail);

    [StructLayout(LayoutKind.Sequential)]
    private struct CallbackRegistration
    {
        public nint UiRequest;
        public nint Event;
        public nint Progress;
        public nint Data;
        public nint LiveViewData;
        public nint Reference;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct DeviceList
    {
        public uint Elements;
        public uint Value;
        public nint Devices;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Ansi)]
    private struct DeviceInfo
    {
        public uint Id;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 64)]
        public string Name;
        [MarshalAs(UnmanagedType.I1)]
        public bool Available;
        public uint ConnectedPid;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 64)]
        public string Version;
    }

    [StructLayout(LayoutKind.Sequential, Pack = 8)]
    private struct ImageLibraryParameters
    {
        public uint Size;
        public uint Version;
        public uint VirtualMemoryMegabytes;
        public nint Library;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 260)]
        public byte[] VirtualMemoryFile;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 260)]
        public byte[] DefaultProfilePath;
    }

    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    private delegate nint AllocateMemoryDelegate(nuint size);

    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    private delegate void FreeMemoryDelegate(nint pointer);

    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    private delegate uint UiRequestDelegate(nint reference, nint request);

    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    private delegate void EventDelegate(
        nint reference,
        uint eventId,
        nuint data);

    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    private delegate void ProgressDelegate(
        uint command,
        uint parameter,
        nint reference,
        uint done,
        uint total);

    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    private delegate int DataDelegate(nint reference, nint info, nint data);

    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    private delegate void LiveViewDelegate(nint reference, nint data);

    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    private delegate int InitializeSdkDelegate(
        AllocateMemoryDelegate allocate,
        FreeMemoryDelegate free,
        ref CallbackRegistration callbacks,
        out nint devices,
        nint capabilities);

    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    private delegate int FreeSdkDelegate();

    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    private delegate uint ImageEntryDelegate(uint command, nint parameters);

    private sealed class DllDirectoryScope : IDisposable
    {
        public DllDirectoryScope(string path)
        {
            if (!SetDllDirectory(path))
            {
                throw new InvalidOperationException(
                    $"Cannot add Nikon SDK DLL directory: {path}");
            }
        }

        public void Dispose() => SetDllDirectory(null);

        [DllImport("kernel32", CharSet = CharSet.Unicode, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool SetDllDirectory(string? path);
    }
}
