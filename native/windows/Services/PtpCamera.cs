using NikonLink.Windows.Models;
using System.Buffers.Binary;
using System.IO;
using System.Runtime.InteropServices;

namespace NikonLink.Windows.Services;

public sealed class PtpCamera : IDisposable
{
    private const ushort ContainerCommand = 1;
    private const ushort ContainerData = 2;
    private const ushort ContainerResponse = 3;
    private const ushort ResponseOk = 0x2001;
    private const ushort OpenSession = 0x1002;
    private const ushort CloseSession = 0x1003;
    private const ushort GetObject = 0x1009;
    private const ushort GetDevicePropertyDescription = 0x1014;
    private const ushort SetDeviceProperty = 0x1016;
    private const ushort ChangeCameraMode = 0x90c2;
    private const ushort DeviceReady = 0x90c8;
    private const ushort GetEvent = 0x90c7;
    private const ushort StartLiveViewOperation = 0x9201;
    private const ushort EndLiveViewOperation = 0x9202;
    private const ushort GetLiveViewImage = 0x9203;
    private const ushort CaptureToSdram = 0x9207;
    private const ushort StartMovieRecordingOperation = 0x920a;
    private const ushort EndMovieRecordingOperation = 0x920b;
    private const ushort TerminateCapture = 0x920c;
    private const ushort ObjectAddedInSdram = 0xc101;
    private const int StillImageClass = 6;
    private const int MaximumContainerSize = 256 * 1024 * 1024;

    private readonly SemaphoreSlim _gate = new(1, 1);
    private nint _context;
    private nint _deviceHandle;
    private int _interfaceNumber = -1;
    private byte _bulkIn;
    private byte _bulkOut;
    private uint _transaction;
    private bool _liveView;
    private bool _movieRecording;
    private bool _disposed;
    private string _exposureMode = "manual";
    private int _bulbDurationSeconds = 5;
    private readonly Dictionary<ushort, bool> _writableProperties = [];
    private readonly HashSet<string> _deniedParameters = [];

    public CameraProfile? Profile { get; private set; }
    public bool IsConnected => _deviceHandle != nint.Zero;
    public bool IsLiveView => _liveView;
    public bool IsMovieRecording => _movieRecording;

    public async Task<CameraProfile> ConnectAsync(
        CancellationToken cancellationToken = default)
    {
        await _gate.WaitAsync(cancellationToken);
        try
        {
            DisconnectCore();
            InitializeLibUsb();
            var profile = OpenSupportedDevice();
            await TransactAsync(
                OpenSession,
                [1],
                null,
                10_000,
                cancellationToken);
            await RefreshParameterCapabilitiesAsync(cancellationToken);
            Profile = profile;
            return profile;
        }
        catch
        {
            DisconnectCore();
            throw;
        }
        finally
        {
            _gate.Release();
        }
    }

    public async Task StartLiveViewAsync(
        CancellationToken cancellationToken = default)
    {
        await _gate.WaitAsync(cancellationToken);
        try
        {
            EnsureConnected();
            if (_liveView)
            {
                return;
            }
            await TransactAsync(
                StartLiveViewOperation,
                null,
                null,
                10_000,
                cancellationToken);
            _liveView = true;
        }
        finally
        {
            _gate.Release();
        }
    }

    public async Task StopLiveViewAsync(
        CancellationToken cancellationToken = default)
    {
        await _gate.WaitAsync(cancellationToken);
        try
        {
            await StopLiveViewCoreAsync(cancellationToken);
        }
        finally
        {
            _gate.Release();
        }
    }

    public async Task<byte[]> GetLiveViewFrameAsync(
        CancellationToken cancellationToken = default)
    {
        await _gate.WaitAsync(cancellationToken);
        try
        {
            EnsureConnected();
            if (!_liveView)
            {
                throw new InvalidOperationException("实时取景尚未开启。");
            }
            var data = await TransactAsync(
                GetLiveViewImage,
                null,
                null,
                12_000,
                cancellationToken);
            return ExtractJpeg(data);
        }
        finally
        {
            _gate.Release();
        }
    }

    public async Task StartMovieRecordingAsync(
        CancellationToken cancellationToken = default)
    {
        await _gate.WaitAsync(cancellationToken);
        try
        {
            EnsureConnected();
            if (_movieRecording)
            {
                return;
            }
            if (!_liveView)
            {
                await TransactAsync(
                    StartLiveViewOperation,
                    null,
                    null,
                    10_000,
                    cancellationToken);
                _liveView = true;
            }
            await TransactAsync(
                StartMovieRecordingOperation,
                null,
                null,
                15_000,
                cancellationToken);
            _movieRecording = true;
        }
        finally
        {
            _gate.Release();
        }
    }

    public async Task StopMovieRecordingAsync(
        CancellationToken cancellationToken = default)
    {
        await _gate.WaitAsync(cancellationToken);
        try
        {
            EnsureConnected();
            if (!_movieRecording)
            {
                return;
            }
            try
            {
                await TransactAsync(
                    EndMovieRecordingOperation,
                    null,
                    null,
                    15_000,
                    cancellationToken);
            }
            finally
            {
                _movieRecording = false;
            }
        }
        finally
        {
            _gate.Release();
        }
    }

    public async Task<byte[]> CaptureAsync(
        CancellationToken cancellationToken = default)
    {
        await _gate.WaitAsync(cancellationToken);
        try
        {
            EnsureConnected();
            var resumeLiveView = _liveView;
            if (resumeLiveView)
            {
                await StopLiveViewCoreAsync(cancellationToken);
            }
            try
            {
                if (_exposureMode == "bulb")
                {
                    await TransactAsync(
                        ChangeCameraMode,
                        [1],
                        null,
                        10_000,
                        cancellationToken);
                    await SetPropertyCoreAsync(
                        0x500e,
                        LittleEndian16(1),
                        cancellationToken);
                    await SetPropertyCoreAsync(
                        0x500d,
                        LittleEndian32(uint.MaxValue),
                        cancellationToken);
                    await TransactAsync(
                        CaptureToSdram,
                        [uint.MaxValue, 1],
                        null,
                        60_000,
                        cancellationToken);
                    await Task.Delay(
                        TimeSpan.FromSeconds(Math.Clamp(_bulbDurationSeconds, 1, 900)),
                        cancellationToken);
                    await TransactAsync(
                        TerminateCapture,
                        [0, 0],
                        null,
                        15_000,
                        cancellationToken);
                }
                else
                {
                    await TransactAsync(
                        CaptureToSdram,
                        [uint.MaxValue, 1],
                        null,
                        60_000,
                        cancellationToken);
                }

                uint handle = 0xffff0001;
                var deadline = DateTime.UtcNow.AddSeconds(30);
                while (DateTime.UtcNow < deadline)
                {
                    cancellationToken.ThrowIfCancellationRequested();
                    try
                    {
                        await TransactAsync(
                            DeviceReady,
                            null,
                            null,
                            3_000,
                            cancellationToken);
                        var events = await TransactAsync(
                            GetEvent,
                            null,
                            null,
                            3_000,
                            cancellationToken);
                        var eventHandle = FindSdramObject(events);
                        if (eventHandle != 0)
                        {
                            handle = eventHandle;
                            break;
                        }
                    }
                    catch (CameraProtocolException)
                    {
                        // The body may report busy while it writes the capture.
                    }
                    await Task.Delay(180, cancellationToken);
                }

                var source = await TransactAsync(
                    GetObject,
                    [handle],
                    null,
                    60_000,
                    cancellationToken);
                return ExtractJpeg(source);
            }
            finally
            {
                if (resumeLiveView && IsConnected)
                {
                    try
                    {
                        await TransactAsync(
                            StartLiveViewOperation,
                            null,
                            null,
                            10_000,
                            cancellationToken);
                        _liveView = true;
                    }
                    catch
                    {
                        _liveView = false;
                    }
                }
            }
        }
        finally
        {
            _gate.Release();
        }
    }

    public async Task SetParameterAsync(
        string name,
        object rawValue,
        CancellationToken cancellationToken = default)
    {
        await _gate.WaitAsync(cancellationToken);
        try
        {
            EnsureConnected();
            if (name == "bulbDuration")
            {
                if (_exposureMode != "bulb")
                {
                    throw new InvalidOperationException(
                        "B门曝光时长仅能在 M 拍摄模式的 B门快门速度下调整。");
                }
                _bulbDurationSeconds = Math.Clamp(Convert.ToInt32(rawValue), 1, 900);
                return;
            }
            if (!CanAdjustParameter(name))
            {
                throw new InvalidOperationException(ParameterLockReason(name));
            }

            if (name == "focusMode")
            {
                var mode = Convert.ToString(rawValue) ?? "single-shot";
                var stillValue = mode switch
                {
                    "manual" => 0x0001,
                    "continuous" => 0x8011,
                    _ => 0x8010
                };
                try
                {
                    await SetPropertyCoreAsync(
                        0x500a,
                        LittleEndian16(stillValue),
                        cancellationToken);
                }
                catch (CameraProtocolException)
                {
                    var liveValue = mode switch
                    {
                        "manual" => 4,
                        "continuous" => 1,
                        _ => 0
                    };
                    await SetPropertyCoreAsync(
                        0xd061,
                        [(byte)liveValue],
                        cancellationToken);
                }
                return;
            }

            ushort property;
            byte[] value;
            var number = rawValue is IConvertible
                ? Convert.ToDouble(rawValue)
                : 0;
            switch (name)
            {
                case "exposureTime":
                    property = 0x500d;
                    value = LittleEndian32((uint)Math.Round(number * 10_000));
                    break;
                case "aperture":
                    property = 0x5007;
                    value = LittleEndian16((int)Math.Round(number * 100));
                    break;
                case "iso":
                    property = 0x500f;
                    value = LittleEndian16((int)Math.Round(number));
                    break;
                case "exposureCompensation":
                    property = 0x5010;
                    value = LittleEndian16((short)Math.Round(number * 1000));
                    break;
                case "whiteBalanceMode":
                    property = 0x5005;
                    value = LittleEndian16(
                        Convert.ToString(rawValue) == "continuous"
                            ? 0x0002
                            : 0x8013);
                    break;
                case "pictureControl":
                    property = 0xd200;
                    value = LittleEndian16((Convert.ToString(rawValue)) switch
                    {
                        "neutral" => 2,
                        "vivid" => 3,
                        "monochrome" => 4,
                        "portrait" => 5,
                        "landscape" => 6,
                        "flat" => 7,
                        "auto" => 8,
                        _ => 1
                    });
                    break;
                case "exposureMode":
                    var requestedExposureMode =
                        Convert.ToString(rawValue) ?? "manual";
                    property = 0x500e;
                    if (requestedExposureMode == "bulb")
                    {
                        await TransactAsync(
                            ChangeCameraMode,
                            [1],
                            null,
                            10_000,
                            cancellationToken);
                        await SetPropertyCoreAsync(
                            property,
                            LittleEndian16(1),
                            cancellationToken);
                        await SetPropertyCoreAsync(
                            0x500d,
                            LittleEndian32(uint.MaxValue),
                            cancellationToken);
                        _exposureMode = requestedExposureMode;
                        await RefreshParameterCapabilitiesAsync(cancellationToken);
                        return;
                    }
                    value = LittleEndian16(requestedExposureMode switch
                    {
                        "aperturePriority" => 3,
                        "shutterPriority" => 4,
                        "program" => 2,
                        _ => 1
                    });
                    break;
                default:
                    throw new InvalidOperationException(
                        $"{CameraName} 不支持此参数：{name}");
            }
            await SetPropertyCoreAsync(property, value, cancellationToken);
            if (name == "exposureMode")
            {
                _exposureMode = Convert.ToString(rawValue) ?? "manual";
                await RefreshParameterCapabilitiesAsync(cancellationToken);
            }
        }
        catch (CameraProtocolException error)
            when (error.ResponseCode == 0x200f)
        {
            _deniedParameters.Add(name);
            throw new InvalidOperationException(
                $"{CameraName} 报告此参数当前只读；" +
                "帧澈 ZENCHE 已锁定该控件以防止重复报错。",
                error);
        }
        finally
        {
            _gate.Release();
        }
    }

    public async Task DisconnectAsync(
        CancellationToken cancellationToken = default)
    {
        await _gate.WaitAsync(cancellationToken);
        try
        {
            if (_movieRecording)
            {
                try
                {
                    await TransactAsync(
                        EndMovieRecordingOperation,
                        null,
                        null,
                        15_000,
                        cancellationToken);
                }
                catch
                {
                }
                _movieRecording = false;
            }
            await StopLiveViewCoreAsync(cancellationToken);
            if (_deviceHandle != nint.Zero)
            {
                try
                {
                    await TransactAsync(
                        CloseSession,
                        null,
                        null,
                        2_000,
                        cancellationToken);
                }
                catch
                {
                    // Device removal and shutdown are best effort.
                }
            }
            DisconnectCore();
        }
        finally
        {
            _gate.Release();
        }
    }

    private void InitializeLibUsb()
    {
        try
        {
            var status = LibUsbNative.libusb_init(out _context);
            if (status != LibUsbNative.Success)
            {
                throw new InvalidOperationException(
                    $"无法初始化 libusb：{LibUsbNative.ErrorName(status)}。");
            }
        }
        catch (DllNotFoundException error)
        {
            throw new InvalidOperationException(
                "未找到 libusb-1.0.dll。请使用 scripts/build-windows.ps1 " +
                "打包，或将官方 64 位 DLL 放入应用目录。",
                error);
        }
        catch (BadImageFormatException error)
        {
            throw new InvalidOperationException(
                "libusb-1.0.dll 架构不匹配；64 位 帧澈 ZENCHE 需要 MS64 DLL。",
                error);
        }
    }

    private CameraProfile OpenSupportedDevice()
    {
        var count = LibUsbNative.libusb_get_device_list(_context, out var list);
        if (count < 0 || list == nint.Zero)
        {
            throw new InvalidOperationException("无法枚举 Windows USB 设备。");
        }

        ushort? unsupportedNikon = null;
        try
        {
            for (nint index = 0; index < count; index++)
            {
                var device = Marshal.ReadIntPtr(list, checked((int)index * nint.Size));
                if (device == nint.Zero ||
                    LibUsbNative.libusb_get_device_descriptor(
                        device,
                        out var descriptor) != LibUsbNative.Success ||
                    descriptor.VendorId != CameraProfile.NikonVendorId)
                {
                    continue;
                }

                var profile = CameraProfile.Find(descriptor.ProductId);
                if (profile is null)
                {
                    unsupportedNikon = descriptor.ProductId;
                    continue;
                }
                OpenDevice(device, profile);
                return profile;
            }
        }
        finally
        {
            LibUsbNative.libusb_free_device_list(list, 1);
        }

        if (unsupportedNikon.HasValue)
        {
            throw new InvalidOperationException(
                $"检测到未支持的 Nikon USB 设备 04b0:{unsupportedNikon.Value:x4}。" +
                $"当前支持 {CameraProfile.Summary}。");
        }
        throw new InvalidOperationException(
            $"没有检测到支持的 Nikon 相机。请连接 {CameraProfile.Summary}。");
    }

    private void OpenDevice(nint device, CameraProfile profile)
    {
        var status = LibUsbNative.libusb_open(device, out _deviceHandle);
        if (status != LibUsbNative.Success || _deviceHandle == nint.Zero)
        {
            throw new InvalidOperationException(
                $"无法打开 {profile.Name}：{LibUsbNative.ErrorName(status)}。" +
                "请关闭 NX Tether，并确认相机接口已绑定 WinUSB。");
        }

        var configStatus = LibUsbNative.libusb_get_active_config_descriptor(
            device,
            out var configPointer);
        if (configStatus != LibUsbNative.Success || configPointer == nint.Zero)
        {
            throw new InvalidOperationException(
                $"{profile.Name} 没有可读取的 USB 配置描述符。");
        }

        try
        {
            var config = Marshal.PtrToStructure<LibUsbNative.ConfigDescriptor>(
                configPointer);
            FindStillImageInterface(config);
        }
        finally
        {
            LibUsbNative.libusb_free_config_descriptor(configPointer);
        }

        if (_interfaceNumber < 0 || _bulkIn == 0 || _bulkOut == 0)
        {
            throw new InvalidOperationException(
                $"{profile.Name} 没有提供可用的 PTP bulk 接口。");
        }

        _ = LibUsbNative.libusb_set_auto_detach_kernel_driver(_deviceHandle, 1);
        status = LibUsbNative.libusb_claim_interface(
            _deviceHandle,
            _interfaceNumber);
        if (status != LibUsbNative.Success)
        {
            throw new InvalidOperationException(
                $"无法声明 {profile.Name} 的 PTP 接口：" +
                $"{LibUsbNative.ErrorName(status)}。请安装 WinUSB/libusbK 驱动。");
        }
        _transaction = 0;
        Profile = profile;
    }

    private void FindStillImageInterface(LibUsbNative.ConfigDescriptor config)
    {
        var interfaceSize = Marshal.SizeOf<LibUsbNative.Interface>();
        var interfaceDescriptorSize =
            Marshal.SizeOf<LibUsbNative.InterfaceDescriptor>();
        var endpointSize = Marshal.SizeOf<LibUsbNative.EndpointDescriptor>();

        for (var interfaceIndex = 0;
             interfaceIndex < config.InterfaceCount;
             interfaceIndex++)
        {
            var interfacePointer = nint.Add(
                config.Interfaces,
                interfaceIndex * interfaceSize);
            var usbInterface = Marshal.PtrToStructure<LibUsbNative.Interface>(
                interfacePointer);
            for (var alternateIndex = 0;
                 alternateIndex < usbInterface.AlternateSettingCount;
                 alternateIndex++)
            {
                var descriptorPointer = nint.Add(
                    usbInterface.AlternateSettings,
                    alternateIndex * interfaceDescriptorSize);
                var descriptor =
                    Marshal.PtrToStructure<LibUsbNative.InterfaceDescriptor>(
                        descriptorPointer);
                if (descriptor.InterfaceClass != StillImageClass)
                {
                    continue;
                }

                byte input = 0;
                byte output = 0;
                for (var endpointIndex = 0;
                     endpointIndex < descriptor.EndpointCount;
                     endpointIndex++)
                {
                    var endpointPointer = nint.Add(
                        descriptor.Endpoints,
                        endpointIndex * endpointSize);
                    var endpoint =
                        Marshal.PtrToStructure<LibUsbNative.EndpointDescriptor>(
                            endpointPointer);
                    if ((endpoint.Attributes & LibUsbNative.TransferTypeMask) !=
                        LibUsbNative.TransferTypeBulk)
                    {
                        continue;
                    }
                    if ((endpoint.EndpointAddress & LibUsbNative.EndpointIn) != 0)
                    {
                        input = endpoint.EndpointAddress;
                    }
                    else
                    {
                        output = endpoint.EndpointAddress;
                    }
                }
                if (input != 0 && output != 0)
                {
                    _interfaceNumber = descriptor.InterfaceNumber;
                    _bulkIn = input;
                    _bulkOut = output;
                    return;
                }
            }
        }
    }

    private async Task<byte[]> TransactAsync(
        ushort operation,
        uint[]? parameters,
        byte[]? outgoingData,
        uint timeout,
        CancellationToken cancellationToken)
    {
        EnsureConnectedForOperation(operation);
        var transaction = ++_transaction;
        var parameterBytes = new byte[(parameters?.Length ?? 0) * 4];
        if (parameters is not null)
        {
            for (var index = 0; index < parameters.Length; index++)
            {
                BinaryPrimitives.WriteUInt32LittleEndian(
                    parameterBytes.AsSpan(index * 4, 4),
                    parameters[index]);
            }
        }

        await SendContainerAsync(
            ContainerCommand,
            operation,
            transaction,
            parameterBytes,
            timeout,
            cancellationToken);
        if (outgoingData is not null)
        {
            await SendContainerAsync(
                ContainerData,
                operation,
                transaction,
                outgoingData,
                timeout,
                cancellationToken);
        }

        var first = await ReceiveContainerAsync(timeout, cancellationToken);
        var data = Array.Empty<byte>();
        var response = first;
        if (first.Type == ContainerData)
        {
            data = first.Payload;
            response = await ReceiveContainerAsync(timeout, cancellationToken);
        }
        if (response.Type != ContainerResponse)
        {
            throw new CameraProtocolException(
                $"{CameraName} 返回了无效的 PTP 容器类型 {response.Type}。");
        }
        if (response.Transaction != transaction ||
            (first.Type == ContainerData && first.Transaction != transaction))
        {
            throw new CameraProtocolException(
                $"{CameraName} 返回了不匹配的 PTP 事务编号。");
        }
        if (response.Code != ResponseOk)
        {
            throw new CameraProtocolException(
                $"{CameraName} PTP 错误 0x{response.Code:X4}（操作 0x{operation:X4}）",
                response.Code,
                operation);
        }
        return data;
    }

    private Task SendContainerAsync(
        ushort type,
        ushort code,
        uint transaction,
        byte[] payload,
        uint timeout,
        CancellationToken cancellationToken)
    {
        return Task.Run(() =>
        {
            cancellationToken.ThrowIfCancellationRequested();
            var bytes = new byte[12 + payload.Length];
            BinaryPrimitives.WriteUInt32LittleEndian(
                bytes.AsSpan(0, 4),
                (uint)bytes.Length);
            BinaryPrimitives.WriteUInt16LittleEndian(bytes.AsSpan(4, 2), type);
            BinaryPrimitives.WriteUInt16LittleEndian(bytes.AsSpan(6, 2), code);
            BinaryPrimitives.WriteUInt32LittleEndian(
                bytes.AsSpan(8, 4),
                transaction);
            payload.CopyTo(bytes, 12);

            var offset = 0;
            while (offset < bytes.Length)
            {
                cancellationToken.ThrowIfCancellationRequested();
                var chunk = new byte[bytes.Length - offset];
                Buffer.BlockCopy(bytes, offset, chunk, 0, chunk.Length);
                var status = LibUsbNative.libusb_bulk_transfer(
                    _deviceHandle,
                    _bulkOut,
                    chunk,
                    chunk.Length,
                    out var transferred,
                    timeout);
                if (status != LibUsbNative.Success || transferred <= 0)
                {
                    throw new IOException(
                        $"向 {CameraName} 发送 USB 数据失败：" +
                        $"{LibUsbNative.ErrorName(status)}。");
                }
                offset += transferred;
            }
        }, cancellationToken);
    }

    private Task<PtpContainer> ReceiveContainerAsync(
        uint timeout,
        CancellationToken cancellationToken)
    {
        return Task.Run(() =>
        {
            cancellationToken.ThrowIfCancellationRequested();
            var first = new byte[1024 * 1024];
            var status = LibUsbNative.libusb_bulk_transfer(
                _deviceHandle,
                _bulkIn,
                first,
                first.Length,
                out var received,
                timeout);
            if (status != LibUsbNative.Success || received < 12)
            {
                throw new IOException(
                    $"读取 {CameraName} USB 数据失败：" +
                    $"{LibUsbNative.ErrorName(status)}。");
            }

            var total = BinaryPrimitives.ReadUInt32LittleEndian(first.AsSpan(0, 4));
            var type = BinaryPrimitives.ReadUInt16LittleEndian(first.AsSpan(4, 2));
            var code = BinaryPrimitives.ReadUInt16LittleEndian(first.AsSpan(6, 2));
            var transaction =
                BinaryPrimitives.ReadUInt32LittleEndian(first.AsSpan(8, 4));
            if (total < 12 || total > MaximumContainerSize)
            {
                throw new IOException($"{CameraName} 返回的数据长度无效：{total}。");
            }

            using var stream = new MemoryStream(checked((int)total));
            stream.Write(first, 0, Math.Min(received, checked((int)total)));
            while (stream.Length < total)
            {
                cancellationToken.ThrowIfCancellationRequested();
                var remaining = checked((int)(total - stream.Length));
                var chunk = new byte[Math.Min(1024 * 1024, remaining)];
                status = LibUsbNative.libusb_bulk_transfer(
                    _deviceHandle,
                    _bulkIn,
                    chunk,
                    chunk.Length,
                    out var count,
                    timeout);
                if (status != LibUsbNative.Success || count <= 0)
                {
                    throw new IOException(
                        $"{CameraName} 图像传输中断：" +
                        $"{LibUsbNative.ErrorName(status)}。");
                }
                stream.Write(chunk, 0, Math.Min(count, remaining));
            }
            var container = stream.ToArray();
            return new PtpContainer(
                type,
                code,
                transaction,
                container[12..checked((int)total)]);
        }, cancellationToken);
    }

    private Task SetPropertyCoreAsync(
        ushort property,
        byte[] value,
        CancellationToken cancellationToken) =>
        TransactAsync(
            SetDeviceProperty,
            [property],
            value,
            10_000,
            cancellationToken);

    private async Task StopLiveViewCoreAsync(
        CancellationToken cancellationToken)
    {
        if (!_liveView || !IsConnected)
        {
            _liveView = false;
            return;
        }
        try
        {
            await TransactAsync(
                EndLiveViewOperation,
                null,
                null,
                5_000,
                cancellationToken);
        }
        finally
        {
            _liveView = false;
        }
    }

    public bool CanAdjustParameter(string name)
    {
        if (_deniedParameters.Contains(name) || !CanAdjust(name))
        {
            return false;
        }
        var property = PropertyCode(name);
        return property == 0 ||
            !_writableProperties.TryGetValue(property, out var writable) ||
            writable;
    }

    public string ParameterLockReason(string name)
    {
        if (_deniedParameters.Contains(name))
        {
            return "相机已拒绝此参数，本次连接内保持锁定";
        }
        if (!CanAdjust(name))
        {
            return "当前拍摄模式下由相机控制";
        }
        return _writableProperties.TryGetValue(PropertyCode(name), out var writable)
            && !writable
                ? "相机固件报告此参数为只读"
                : "当前不可调整";
    }

    private bool CanAdjust(string name) => name switch
    {
        "exposureTime" =>
            _exposureMode is "manual" or "shutterPriority",
        "aperture" =>
            _exposureMode is "manual" or "aperturePriority" or "bulb",
        "iso" => true,
        "exposureCompensation" =>
            _exposureMode is "program" or "aperturePriority" or "shutterPriority",
        _ => true
    };

    private async Task RefreshParameterCapabilitiesAsync(
        CancellationToken cancellationToken)
    {
        _writableProperties.Clear();
        _deniedParameters.Clear();
        ushort[] properties =
        [
            0x5005, 0x5007, 0x500a, 0x500d,
            0x500e, 0x500f, 0x5010, 0xd200
        ];
        foreach (var property in properties)
        {
            try
            {
                var descriptor = await TransactAsync(
                    GetDevicePropertyDescription,
                    [property],
                    null,
                    5_000,
                    cancellationToken);
                if (descriptor.Length >= 5)
                {
                    _writableProperties[property] = descriptor[4] != 0;
                }
            }
            catch (CameraProtocolException)
            {
                // Older bodies may omit descriptors; mode gating remains.
            }
        }
    }

    private static ushort PropertyCode(string name) => name switch
    {
        "whiteBalanceMode" => 0x5005,
        "aperture" => 0x5007,
        "focusMode" => 0x500a,
        "exposureTime" => 0x500d,
        "exposureMode" => 0x500e,
        "iso" => 0x500f,
        "exposureCompensation" => 0x5010,
        "pictureControl" => 0xd200,
        _ => 0
    };

    private static uint FindSdramObject(byte[] events)
    {
        if (events.Length < 2)
        {
            return 0;
        }
        var count = BinaryPrimitives.ReadUInt16LittleEndian(events.AsSpan(0, 2));
        var offset = 2;
        for (var index = 0;
             index < count && offset + 6 <= events.Length;
             index++, offset += 6)
        {
            var code = BinaryPrimitives.ReadUInt16LittleEndian(
                events.AsSpan(offset, 2));
            var handle = BinaryPrimitives.ReadUInt32LittleEndian(
                events.AsSpan(offset + 2, 4));
            if (code == ObjectAddedInSdram)
            {
                return handle;
            }
        }
        return 0;
    }

    private byte[] ExtractJpeg(byte[] source)
    {
        var start = -1;
        var end = -1;
        for (var index = 0; index < source.Length - 1; index++)
        {
            if (start < 0 && source[index] == 0xff && source[index + 1] == 0xd8)
            {
                start = index;
            }
            if (start >= 0 && source[index] == 0xff && source[index + 1] == 0xd9)
            {
                end = index + 2;
            }
        }
        if (start < 0 || end <= start)
        {
            throw new IOException($"{CameraName} 返回的数据中没有 JPEG 图像。");
        }
        return source[start..end];
    }

    private static byte[] LittleEndian16(int value)
    {
        var bytes = new byte[2];
        BinaryPrimitives.WriteInt16LittleEndian(bytes, unchecked((short)value));
        return bytes;
    }

    private static byte[] LittleEndian32(uint value)
    {
        var bytes = new byte[4];
        BinaryPrimitives.WriteUInt32LittleEndian(bytes, value);
        return bytes;
    }

    private void EnsureConnected()
    {
        ObjectDisposedException.ThrowIf(_disposed, this);
        if (!IsConnected)
        {
            throw new InvalidOperationException("请先连接支持的 Nikon 相机。");
        }
    }

    private void EnsureConnectedForOperation(ushort operation)
    {
        if (operation == OpenSession)
        {
            if (_deviceHandle == nint.Zero)
            {
                throw new InvalidOperationException("无法打开 Nikon USB 连接。");
            }
            return;
        }
        EnsureConnected();
    }

    private string CameraName => Profile?.Name ?? "Nikon 相机";

    private void DisconnectCore()
    {
        if (_deviceHandle != nint.Zero)
        {
            if (_interfaceNumber >= 0)
            {
                _ = LibUsbNative.libusb_release_interface(
                    _deviceHandle,
                    _interfaceNumber);
            }
            LibUsbNative.libusb_close(_deviceHandle);
        }
        if (_context != nint.Zero)
        {
            LibUsbNative.libusb_exit(_context);
        }
        _deviceHandle = nint.Zero;
        _context = nint.Zero;
        _interfaceNumber = -1;
        _bulkIn = 0;
        _bulkOut = 0;
        _transaction = 0;
        _liveView = false;
        _movieRecording = false;
        _writableProperties.Clear();
        _deniedParameters.Clear();
        Profile = null;
    }

    public void Dispose()
    {
        if (_disposed)
        {
            return;
        }
        DisconnectCore();
        _gate.Dispose();
        _disposed = true;
        GC.SuppressFinalize(this);
    }

    private sealed record PtpContainer(
        ushort Type,
        ushort Code,
        uint Transaction,
        byte[] Payload);
}

public sealed class CameraProtocolException : IOException
{
    public CameraProtocolException(
        string message,
        ushort responseCode = 0,
        ushort operationCode = 0)
        : base(message)
    {
        ResponseCode = responseCode;
        OperationCode = operationCode;
    }

    public ushort ResponseCode { get; }
    public ushort OperationCode { get; }
}
