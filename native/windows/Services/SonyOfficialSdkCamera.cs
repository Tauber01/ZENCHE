using NikonLink.Windows.Models;
using System.IO;
using System.Runtime.InteropServices;

namespace NikonLink.Windows.Services;

internal sealed record SonyOfficialSdkStatus(
    bool Loaded,
    bool Ready,
    string Detail,
    IReadOnlyList<string> Devices)
{
    public static SonyOfficialSdkStatus Pending { get; } = new(
        false,
        false,
        "等待检测",
        []);

    public string Summary => Ready
        ? "Camera Remote SDK 2.02.00 已就绪"
        : Loaded
            ? "官方 SDK 已安装，初始化或枚举失败"
            : "官方 SDK 运行库未载入";
}

internal sealed class SonyOfficialSdkCamera
{
    public static SonyOfficialSdkCamera Shared { get; } = new();

    private const uint ErrorNone = 0;
    private const uint CommandRelease = 0;
    private const uint CommandMovieRecord = 1;
    private const uint CommandTrackingAfOn = 24;
    private const ushort CommandUp = 0;
    private const ushort CommandDown = 1;
    private const uint PropertyFNumber = 256;
    private const uint PropertyExposureCompensation = 257;
    private const uint PropertyShutterSpeed = 259;
    private const uint PropertyIso = 260;
    private const uint PropertyMovieFileFormat = 295;
    private const uint PropertyPictureProfile = 426;

    private readonly object _gate = new();
    private readonly string _runtimeRoot = AppContext.BaseDirectory;
    private nint _library;
    private NativeApi? _api;
    private CallbackBridge? _callback;
    private nint _cameraList;
    private long _deviceHandle;
    private string _model = "";
    private string _saveRoot = "";
    private bool _liveView;
    private bool _movieRecording;

    public SonyOfficialSdkStatus Status { get; private set; } =
        SonyOfficialSdkStatus.Pending;
    public bool IsConnected => _deviceHandle != 0;
    public bool IsLiveView => _liveView;
    public bool IsMovieRecording => _movieRecording;

    public SonyOfficialSdkStatus Probe(bool allowEnumeration = true)
    {
        lock (_gate)
        {
            if (IsConnected)
            {
                Status = new SonyOfficialSdkStatus(
                    true,
                    true,
                    "官方 SDK 正在控制当前索尼相机",
                    [$"{_model} · 已连接"]);
                return Status;
            }
            if (!TryLoad(out var loadError))
            {
                Status = new SonyOfficialSdkStatus(
                    false,
                    false,
                    loadError,
                    []);
                return Status;
            }
            if (!allowEnumeration)
            {
                Status = new SonyOfficialSdkStatus(
                    true,
                    true,
                    "SDK 已安装 · 断开当前 USB 会话后可重新枚举",
                    []);
                return Status;
            }

            var initialized = false;
            nint cameras = 0;
            try
            {
                initialized = _api!.Init(0);
                if (!initialized)
                {
                    Status = new SonyOfficialSdkStatus(
                        true,
                        false,
                        "SDK 初始化失败",
                        []);
                    return Status;
                }
                var error = _api.EnumCameraObjects(out cameras, 3);
                if (error != ErrorNone)
                {
                    Status = new SonyOfficialSdkStatus(
                        true,
                        false,
                        $"相机枚举失败 · 错误码 {error}",
                        []);
                    return Status;
                }
                var devices = ReadCameraModels(cameras)
                    .Select(model => $"{model} · 可连接")
                    .ToArray();
                Status = new SonyOfficialSdkStatus(
                    true,
                    true,
                    devices.Length == 0
                        ? "SDK 已就绪 · 未发现空闲索尼相机"
                        : $"SDK 已发现 {devices.Length} 台索尼相机",
                    devices);
                return Status;
            }
            catch (Exception error)
            {
                Status = new SonyOfficialSdkStatus(
                    true,
                    false,
                    $"SDK 探测失败 · {error.Message}",
                    []);
                return Status;
            }
            finally
            {
                if (cameras != 0) ReleaseCameraList(cameras);
                if (initialized) _api!.Release();
            }
        }
    }

    public bool TryConnect(out CameraProfile profile)
    {
        lock (_gate)
        {
            profile = CameraProfile.Find(0x054c, 0)!;
            if (!TryLoad(out _)) return false;
            if (!_api!.Init(0)) return false;

            nint cameras = 0;
            try
            {
                var error = _api.EnumCameraObjects(out cameras, 3);
                if (error != ErrorNone || cameras == 0 || CameraCount(cameras) == 0)
                {
                    _api.Release();
                    return false;
                }
                var camera = CameraAt(cameras, 0);
                if (camera == 0)
                {
                    ReleaseCameraList(cameras);
                    _api.Release();
                    return false;
                }

                _callback ??= new CallbackBridge();
                _callback.ResetConnection();
                error = _api.Connect(
                    camera,
                    _callback.Instance,
                    out var handle,
                    0,
                    1,
                    0,
                    0,
                    0,
                    0,
                    0);
                if (error != ErrorNone || handle == 0 ||
                    !_callback.WaitForConnection(TimeSpan.FromSeconds(8)))
                {
                    if (handle != 0) _api.ReleaseDevice(handle);
                    ReleaseCameraList(cameras);
                    _api.Release();
                    throw new InvalidOperationException(
                        $"Sony Camera Remote SDK 连接失败（错误码 {error}）。");
                }

                _deviceHandle = handle;
                _cameraList = cameras;
                cameras = 0;
                _model = CameraModel(camera);
                if (string.IsNullOrWhiteSpace(_model)) _model = "Sony Camera";
                _saveRoot = Path.Combine(
                    Path.GetTempPath(),
                    "ZENCHE",
                    "SonySDK");
                Directory.CreateDirectory(_saveRoot);
                error = _api.SetSaveInfo(
                    _deviceHandle,
                    _saveRoot,
                    "ZENCHE",
                    -1);
                Check(error, "设置照片保存目录");
                profile = MatchProfile(_model);
                Status = new SonyOfficialSdkStatus(
                    true,
                    true,
                    "官方 SDK 正在控制当前索尼相机",
                    [$"{_model} · 已连接"]);
                return true;
            }
            catch
            {
                if (_deviceHandle != 0)
                {
                    Disconnect();
                }
                else
                {
                    if (cameras != 0) ReleaseCameraList(cameras);
                    _api.Release();
                }
                throw;
            }
        }
    }

    public void StartLiveView()
    {
        lock (_gate)
        {
            _ = GetLiveViewFrameCore();
            _liveView = true;
        }
    }

    public void StopLiveView()
    {
        lock (_gate) _liveView = false;
    }

    public byte[] GetLiveViewFrame()
    {
        lock (_gate) return GetLiveViewFrameCore();
    }

    public byte[] Capture()
    {
        CallbackBridge callback;
        lock (_gate)
        {
            EnsureConnected();
            callback = _callback!;
            callback.ResetDownload();
            Check(
                _api!.SendCommand(
                    _deviceHandle,
                    CommandRelease,
                    CommandDown),
                "按下快门");
            Thread.Sleep(35);
            Check(
                _api.SendCommand(
                    _deviceHandle,
                    CommandRelease,
                    CommandUp),
                "释放快门");
        }
        var filename = callback.WaitForDownload(TimeSpan.FromSeconds(60));
        if (string.IsNullOrWhiteSpace(filename))
        {
            throw new IOException("Sony Camera Remote SDK 未返回拍摄文件。");
        }
        var path = Path.IsPathRooted(filename)
            ? filename
            : Path.Combine(_saveRoot, filename);
        var data = File.ReadAllBytes(path);
        try { File.Delete(path); } catch { }
        return data;
    }

    public void SetMovieRecording(bool recording)
    {
        lock (_gate)
        {
            EnsureConnected();
            Check(
                _api!.SendCommand(
                    _deviceHandle,
                    CommandMovieRecord,
                    recording ? CommandDown : CommandUp),
                recording ? "开始视频录制" : "停止视频录制");
            _movieRecording = recording;
        }
    }

    public void TriggerAutofocus()
    {
        lock (_gate)
        {
            EnsureConnected();
            Check(
                _api!.SendCommand(
                    _deviceHandle,
                    CommandTrackingAfOn,
                    CommandDown),
                "AF-ON 按下");
            Thread.Sleep(120);
            Check(
                _api.SendCommand(
                    _deviceHandle,
                    CommandTrackingAfOn,
                    CommandUp),
                "AF-ON 释放");
        }
    }

    public void SetParameter(string name, object rawValue)
    {
        var property = name switch
        {
            "videoCodec" => PropertyMovieFileFormat,
            "videoLog" => PropertyPictureProfile,
            "aperture" => PropertyFNumber,
            "iso" => PropertyIso,
            "exposureCompensation" => PropertyExposureCompensation,
            "exposureTime" or "videoExposureTime" => PropertyShutterSpeed,
            _ => throw new InvalidOperationException(
                $"Sony Camera Remote SDK 当前不支持参数：{name}")
        };
        ulong value = name switch
        {
            "videoCodec" => Convert.ToString(rawValue) switch
            {
                "sonyXavcHs8k" => 4,
                "sonyXavcHs4k" => 5,
                "sonyXavcS4k" => 2,
                "sonyXavcSHd" => 3,
                "sonyXavcSi4k" => 8,
                "sonyXavcSiHd" => 9,
                _ => throw new InvalidOperationException(
                    "Sony 不支持所选视频录制规格。")
            },
            "videoLog" => Convert.ToString(rawValue) switch
            {
                "off" => 0,
                "sonySLog2" => 7,
                "sonySLog3Cine" => 8,
                "sonySLog3" => 9,
                "sonyHlg" => 10,
                _ => throw new InvalidOperationException(
                    "Sony 不支持所选 Log / Picture Profile。")
            },
            "aperture" => checked((ulong)Math.Round(Convert.ToDouble(rawValue) * 100)),
            "iso" => checked((ulong)Convert.ToInt32(rawValue)),
            "exposureCompensation" => unchecked((ulong)(long)Math.Round(
                Convert.ToDouble(rawValue) * 1000)),
            _ => EncodeShutter(Convert.ToDouble(rawValue))
        };
        SetProperty(property, value);
    }

    public void Disconnect()
    {
        lock (_gate)
        {
            if (_deviceHandle != 0)
            {
                _api!.Disconnect(_deviceHandle);
                _api.ReleaseDevice(_deviceHandle);
            }
            _deviceHandle = 0;
            if (_cameraList != 0) ReleaseCameraList(_cameraList);
            _cameraList = 0;
            _api?.Release();
            _model = "";
            _saveRoot = "";
            _liveView = false;
            _movieRecording = false;
        }
    }

    private byte[] GetLiveViewFrameCore()
    {
        EnsureConnected();
        var imageInfo = Marshal.AllocHGlobal(64);
        var imageData = Marshal.AllocHGlobal(64);
        nint buffer = 0;
        try
        {
            _api!.ConstructImageInfo(imageInfo);
            Check(
                _api.GetLiveViewImageInfo(_deviceHandle, imageInfo),
                "获取实时取景信息");
            var size = _api.GetImageBufferSize(imageInfo);
            if (size == 0 || size > 128 * 1024 * 1024)
            {
                throw new IOException("Sony SDK 返回了无效的实时取景缓冲区。 ");
            }
            buffer = Marshal.AllocHGlobal(checked((int)size));
            _api.ConstructImageData(imageData);
            _api.SetImageData(imageData, buffer);
            _api.SetImageSize(imageData, size);
            Check(
                _api.GetLiveViewImage(_deviceHandle, imageData),
                "获取实时取景图像");
            var actual = _api.GetImageDataSize(imageData);
            if (actual == 0 || actual > size)
            {
                throw new IOException("Sony SDK 未返回有效的实时取景图像。 ");
            }
            var result = new byte[actual];
            Marshal.Copy(_api.GetImageDataPointer(imageData), result, 0, (int)actual);
            return result;
        }
        finally
        {
            if (buffer != 0) Marshal.FreeHGlobal(buffer);
            try { _api?.DestructImageData(imageData); } catch { }
            try { _api?.DestructImageInfo(imageInfo); } catch { }
            Marshal.FreeHGlobal(imageData);
            Marshal.FreeHGlobal(imageInfo);
        }
    }

    private void SetProperty(uint code, ulong value)
    {
        lock (_gate)
        {
            EnsureConnected();
            var requested = code;
            var error = _api!.GetSelectDeviceProperties(
                _deviceHandle,
                1,
                ref requested,
                out var properties,
                out var count);
            Check(error, "读取相机属性");
            try
            {
                if (properties == 0 || count < 1 ||
                    !_api.IsPropertyWritable(properties))
                {
                    throw new InvalidOperationException(
                        "当前机型或拍摄模式未开放此 Sony SDK 属性。 ");
                }
                _api.SetPropertyCurrentValue(properties, value);
                Check(
                    _api.SetDeviceProperty(_deviceHandle, properties),
                    "写入相机属性");
            }
            finally
            {
                if (properties != 0)
                {
                    _api.ReleaseDeviceProperties(_deviceHandle, properties);
                }
            }
        }
    }

    private bool TryLoad(out string error)
    {
        if (_api is not null)
        {
            error = "";
            return true;
        }
        var corePath = Path.Combine(_runtimeRoot, "Cr_Core.dll");
        if (!File.Exists(corePath))
        {
            corePath = Path.Combine(_runtimeRoot, "SonySDK", "Cr_Core.dll");
        }
        if (!File.Exists(corePath))
        {
            error = "Cr_Core.dll 未找到";
            return false;
        }
        try
        {
            SetDllDirectory(Path.GetDirectoryName(corePath));
            _library = NativeLibrary.Load(corePath);
            _api = new NativeApi(_library);
            error = "";
            return true;
        }
        catch (Exception exception)
        {
            error = $"SDK 加载失败 · {exception.Message}";
            return false;
        }
    }

    private IReadOnlyList<string> ReadCameraModels(nint cameras)
    {
        var result = new List<string>();
        var count = Math.Min(CameraCount(cameras), 64u);
        for (var index = 0u; index < count; index++)
        {
            var camera = CameraAt(cameras, index);
            if (camera == 0) continue;
            result.Add(CameraModel(camera));
        }
        return result;
    }

    private static uint CameraCount(nint cameras) =>
        VDelegate<ObjectCountDelegate>(cameras, 0)(cameras);

    private static nint CameraAt(nint cameras, uint index) =>
        VDelegate<ObjectAtDelegate>(cameras, 1)(cameras, index);

    private static void ReleaseCameraList(nint cameras) =>
        VDelegate<ObjectReleaseDelegate>(cameras, 2)(cameras);

    private static string CameraModel(nint camera)
    {
        var pointer = VDelegate<ObjectStringDelegate>(camera, 3)(camera);
        return pointer == 0 ? "Sony Camera" :
            Marshal.PtrToStringUTF8(pointer) ?? "Sony Camera";
    }

    private static T VDelegate<T>(nint instance, int slot) where T : Delegate
    {
        var table = Marshal.ReadIntPtr(instance);
        var method = Marshal.ReadIntPtr(table, slot * nint.Size);
        return Marshal.GetDelegateForFunctionPointer<T>(method);
    }

    private static CameraProfile MatchProfile(string model)
    {
        // Longest-alias matching against the shared Sony registry keeps
        // ZV-E10M2 on ZV-E10 II and ILCE-1M2 on A1 II instead of their
        // base models (see CameraProfile.MatchSonyModel).
        var matched = CameraProfile.MatchSonyModel(model);
        if (matched is not null)
        {
            return matched;
        }
        return new CameraProfile(
            model.StartsWith("Sony", StringComparison.OrdinalIgnoreCase)
                ? model
                : $"Sony {model}",
            "Sony",
            0x054c,
            0,
            100,
            102400);
    }

    private static ulong EncodeShutter(double seconds)
    {
        seconds = Math.Max(0.000001, seconds);
        return seconds < 1
            ? (1UL << 16) | checked((uint)Math.Round(1 / seconds))
            : (checked((ulong)Math.Round(seconds)) << 16) | 1;
    }

    private void EnsureConnected()
    {
        if (!IsConnected)
        {
            throw new InvalidOperationException("请先连接索尼相机。 ");
        }
    }

    private static void Check(uint error, string operation)
    {
        if (error != ErrorNone)
        {
            throw new InvalidOperationException(
                $"Sony Camera Remote SDK 执行“{operation}”失败（错误码 {error}）。");
        }
    }

    [DllImport("kernel32", CharSet = CharSet.Unicode, SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool SetDllDirectory(string? path);

    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    private delegate uint ObjectCountDelegate(nint instance);
    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    private delegate nint ObjectAtDelegate(nint instance, uint index);
    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    private delegate void ObjectReleaseDelegate(nint instance);
    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    private delegate nint ObjectStringDelegate(nint instance);

    private sealed class NativeApi
    {
        public NativeApi(nint library)
        {
            Init = Export<InitDelegate>(library, "Init");
            Release = Export<ReleaseDelegate>(library, "Release");
            EnumCameraObjects = Export<EnumDelegate>(library, "EnumCameraObjects");
            Connect = Export<ConnectDelegate>(library, "Connect");
            Disconnect = Export<DeviceDelegate>(library, "Disconnect");
            ReleaseDevice = Export<DeviceDelegate>(library, "ReleaseDevice");
            SetSaveInfo = Export<SetSaveInfoDelegate>(library, "SetSaveInfo");
            SendCommand = Export<SendCommandDelegate>(library, "SendCommand");
            GetLiveViewImageInfo = Export<ImageCallDelegate>(library, "GetLiveViewImageInfo");
            GetLiveViewImage = Export<ImageCallDelegate>(library, "GetLiveViewImage");
            GetSelectDeviceProperties = Export<GetPropertiesDelegate>(library, "GetSelectDeviceProperties");
            ReleaseDeviceProperties = Export<ReleasePropertiesDelegate>(library, "ReleaseDeviceProperties");
            SetDeviceProperty = Export<SetDevicePropertyDelegate>(library, "SetDeviceProperty");
            ConstructImageInfo = Export<ObjectMethodDelegate>(library, "??0CrImageInfo@SCRSDK@@QEAA@XZ");
            DestructImageInfo = Export<ObjectMethodDelegate>(library, "??1CrImageInfo@SCRSDK@@QEAA@XZ");
            GetImageBufferSize = Export<ObjectUIntDelegate>(library, "?GetBufferSize@CrImageInfo@SCRSDK@@QEBAIXZ");
            ConstructImageData = Export<ObjectMethodDelegate>(library, "??0CrImageDataBlock@SCRSDK@@QEAA@XZ");
            DestructImageData = Export<ObjectMethodDelegate>(library, "??1CrImageDataBlock@SCRSDK@@QEAA@XZ");
            SetImageData = Export<ObjectPointerDelegate>(library, "?SetData@CrImageDataBlock@SCRSDK@@QEAAXPEAE@Z");
            SetImageSize = Export<ObjectSetUIntDelegate>(library, "?SetSize@CrImageDataBlock@SCRSDK@@QEAAXI@Z");
            GetImageDataSize = Export<ObjectUIntDelegate>(library, "?GetImageSize@CrImageDataBlock@SCRSDK@@QEBAIXZ");
            GetImageDataPointer = Export<ObjectPointerResultDelegate>(library, "?GetImageData@CrImageDataBlock@SCRSDK@@QEBAPEAEXZ");
            IsPropertyWritable = Export<ObjectBoolDelegate>(library, "?IsSetEnableCurrentValue@CrDeviceProperty@SCRSDK@@QEBA_NXZ");
            SetPropertyCurrentValue = Export<ObjectSetULongDelegate>(library, "?SetCurrentValue@CrDeviceProperty@SCRSDK@@QEAAX_K@Z");
        }

        public InitDelegate Init { get; }
        public ReleaseDelegate Release { get; }
        public EnumDelegate EnumCameraObjects { get; }
        public ConnectDelegate Connect { get; }
        public DeviceDelegate Disconnect { get; }
        public DeviceDelegate ReleaseDevice { get; }
        public SetSaveInfoDelegate SetSaveInfo { get; }
        public SendCommandDelegate SendCommand { get; }
        public ImageCallDelegate GetLiveViewImageInfo { get; }
        public ImageCallDelegate GetLiveViewImage { get; }
        public GetPropertiesDelegate GetSelectDeviceProperties { get; }
        public ReleasePropertiesDelegate ReleaseDeviceProperties { get; }
        public SetDevicePropertyDelegate SetDeviceProperty { get; }
        public ObjectMethodDelegate ConstructImageInfo { get; }
        public ObjectMethodDelegate DestructImageInfo { get; }
        public ObjectUIntDelegate GetImageBufferSize { get; }
        public ObjectMethodDelegate ConstructImageData { get; }
        public ObjectMethodDelegate DestructImageData { get; }
        public ObjectPointerDelegate SetImageData { get; }
        public ObjectSetUIntDelegate SetImageSize { get; }
        public ObjectUIntDelegate GetImageDataSize { get; }
        public ObjectPointerResultDelegate GetImageDataPointer { get; }
        public ObjectBoolDelegate IsPropertyWritable { get; }
        public ObjectSetULongDelegate SetPropertyCurrentValue { get; }

        private static T Export<T>(nint library, string name) where T : Delegate =>
            Marshal.GetDelegateForFunctionPointer<T>(NativeLibrary.GetExport(library, name));
    }

    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    [return: MarshalAs(UnmanagedType.I1)]
    private delegate bool InitDelegate(uint logType);
    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    [return: MarshalAs(UnmanagedType.I1)]
    private delegate bool ReleaseDelegate();
    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    private delegate uint EnumDelegate(out nint cameras, byte timeoutSeconds);
    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    private delegate uint ConnectDelegate(
        nint camera,
        nint callback,
        out long deviceHandle,
        uint controlMode,
        uint reconnect,
        nint userId,
        nint password,
        nint fingerprint,
        uint fingerprintSize,
        nint pairingName);
    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    private delegate uint DeviceDelegate(long deviceHandle);
    [UnmanagedFunctionPointer(CallingConvention.Winapi, CharSet = CharSet.Ansi)]
    private delegate uint SetSaveInfoDelegate(
        long deviceHandle,
        string path,
        string prefix,
        int startNumber);
    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    private delegate uint SendCommandDelegate(
        long deviceHandle,
        uint command,
        ushort parameter);
    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    private delegate uint ImageCallDelegate(long deviceHandle, nint image);
    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    private delegate uint GetPropertiesDelegate(
        long deviceHandle,
        uint codeCount,
        ref uint codes,
        out nint properties,
        out int propertyCount);
    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    private delegate uint ReleasePropertiesDelegate(long deviceHandle, nint properties);
    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    private delegate uint SetDevicePropertyDelegate(long deviceHandle, nint property);
    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    private delegate void ObjectMethodDelegate(nint instance);
    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    private delegate uint ObjectUIntDelegate(nint instance);
    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    private delegate void ObjectPointerDelegate(nint instance, nint pointer);
    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    private delegate nint ObjectPointerResultDelegate(nint instance);
    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    private delegate void ObjectSetUIntDelegate(nint instance, uint value);
    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    private delegate void ObjectSetULongDelegate(nint instance, ulong value);
    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    [return: MarshalAs(UnmanagedType.I1)]
    private delegate bool ObjectBoolDelegate(nint instance);

    private sealed class CallbackBridge
    {
        private readonly List<Delegate> _delegates = [];
        private readonly ManualResetEventSlim _connection = new(false);
        private readonly ManualResetEventSlim _download = new(false);
        private volatile bool _connected;
        private string _downloadedFile = "";

        public CallbackBridge()
        {
            var table = Marshal.AllocHGlobal(nint.Size * 21);
            Instance = Marshal.AllocHGlobal(nint.Size);
            Marshal.WriteIntPtr(Instance, table);
            Write(table, 0, new ConnectedCallback(OnConnected));
            Write(table, 1, new UIntCallback(OnDisconnected));
            Write(table, 2, new VoidCallback(_ => { }));
            Write(table, 3, new CodesCallback((_, _, _) => { }));
            Write(table, 4, new VoidCallback(_ => { }));
            Write(table, 5, new CodesCallback((_, _, _) => { }));
            Write(table, 6, new DownloadCallback(OnDownload));
            Write(table, 7, new OperationCallback((_, _, _) => { }));
            Write(table, 8, new ContentsCallback((_, _, _, _) => { }));
            Write(table, 9, new UIntCallback((_, _) => { }));
            Write(table, 10, new WarningExtCallback((_, _, _, _, _) => { }));
            Write(table, 11, new UIntCallback((_, _) => { }));
            Write(table, 12, new FtpCallback((_, _, _, _) => { }));
            Write(table, 13, new RemoteFileCallback((_, _, _, _) => { }));
            Write(table, 14, new RemoteDataCallback((_, _, _, _, _) => { }));
            Write(table, 15, new ListChangedCallback((_, _, _, _) => { }));
            Write(table, 16, new OperationCallback((_, _, _) => { }));
            Write(table, 17, new UIntCallback((_, _) => { }));
            Write(table, 18, new PlaybackCallback((_, _, _, _, _, _, _, _) => { }));
            Write(table, 19, new CodesCallback((_, _, _) => { }));
            Write(table, 20, new PostViewCallback((_, _, _) => { }));
        }

        public nint Instance { get; }

        public void ResetConnection()
        {
            _connected = false;
            _connection.Reset();
        }

        public bool WaitForConnection(TimeSpan timeout) =>
            _connection.Wait(timeout) && _connected;

        public void ResetDownload()
        {
            _downloadedFile = "";
            _download.Reset();
        }

        public string WaitForDownload(TimeSpan timeout) =>
            _download.Wait(timeout) ? _downloadedFile : "";

        private void OnConnected(nint _, uint __)
        {
            _connected = true;
            _connection.Set();
        }

        private void OnDisconnected(nint _, uint __)
        {
            _connected = false;
            _connection.Set();
        }

        private void OnDownload(nint _, nint filename, uint __)
        {
            _downloadedFile = filename == 0
                ? ""
                : Marshal.PtrToStringUTF8(filename) ?? "";
            _download.Set();
        }

        private void Write(nint table, int slot, Delegate callback)
        {
            _delegates.Add(callback);
            Marshal.WriteIntPtr(
                table,
                slot * nint.Size,
                Marshal.GetFunctionPointerForDelegate(callback));
        }
    }

    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    private delegate void ConnectedCallback(nint instance, uint version);
    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    private delegate void VoidCallback(nint instance);
    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    private delegate void UIntCallback(nint instance, uint value);
    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    private delegate void CodesCallback(nint instance, uint count, nint codes);
    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    private delegate void DownloadCallback(nint instance, nint filename, uint type);
    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    private delegate void OperationCallback(nint instance, uint code, nint result);
    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    private delegate void ContentsCallback(nint instance, uint notify, ulong handle, nint filename);
    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    private delegate void WarningExtCallback(nint instance, uint warning, int first, int second, int third);
    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    private delegate void FtpCallback(nint instance, uint notify, uint success, uint failure);
    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    private delegate void RemoteFileCallback(nint instance, uint notify, uint percent, nint filename);
    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    private delegate void RemoteDataCallback(nint instance, uint notify, uint percent, nint data, ulong size);
    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    private delegate void ListChangedCallback(nint instance, uint notify, uint slot, uint size);
    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    private delegate void PlaybackCallback(nint instance, byte mediaType, int size, nint data, long pts, long dts, int first, int second);
    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    private delegate void PostViewCallback(nint instance, nint filename, uint size);
}
