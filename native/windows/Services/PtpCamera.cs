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
    private const ushort ResponseSessionAlreadyOpen = 0x201e;
    private const ushort OpenSession = 0x1002;
    private const ushort CloseSession = 0x1003;
    private const ushort GetStorageIds = 0x1004;
    private const ushort GetStorageInfo = 0x1005;
    private const ushort GetObjectHandles = 0x1007;
    private const ushort GetObjectInfo = 0x1008;
    private const ushort GetObject = 0x1009;
    private const ushort GetThumb = 0x100a;
    private const ushort DeleteObject = 0x100b;
    private const ushort GetDevicePropertyDescription = 0x1014;
    private const ushort GetDevicePropertyValue = 0x1015;
    private const ushort SetDeviceProperty = 0x1016;
    private const ushort ChangeCameraMode = 0x90c2;
    private const ushort DeviceReady = 0x90c8;
    private const ushort GetEvent = 0x90c7;
    private const ushort StartLiveViewOperation = 0x9201;
    private const ushort EndLiveViewOperation = 0x9202;
    private const ushort GetLiveViewImage = 0x9203;
    private const ushort ManualFocusDriveOperation = 0x9204;
    private const ushort CaptureToSdram = 0x9207;
    private const ushort TerminateCapture = 0x920c;
    private const ushort ObjectAddedInSdram = 0xc101;
    private const ushort ExposureTime = 0x500d;
    private const ushort NikonMovieFileType = 0xd0af;
    private const uint NikonMovieProResToneMode = 0x0001d000;
    private const uint NikonMovieH265ToneMode = 0x0001d001;
    private const uint NikonMovieNRawToneMode = 0x0001d028;
    private const uint NikonMovieProResRawToneMode = 0x0001d029;
    private const uint NikonH264EightBit = 0x00000801;
    private const uint NikonH265TenBit = 0x00010a00;
    private const uint NikonNRawTwelveBit = 0x00020c02;
    private const uint NikonProRes422TenBit = 0x00100a00;
    private const uint NikonProResRawTwelveBit = 0x00110c00;
    private const ushort SonyPictureProfile = 0xd23f;
    private const ushort SonyMovieFileFormat = 0xd241;
    private const ushort CanonEosSetDevicePropValueEx = 0x9110;
    private const ushort CanonLogGamma = 0xd176;
    // E2 1.5.9：佳能 EOS 取景扩展（libgphoto2 camlibs/ptp2/ptp.h 常量）：
    // - EOS_GetViewFinderData(0x9153)：实时取景取帧，数据段为 EOS dataset
    //   （[u32 len][u32 type][payload] 序列，JPEG 在 type 1/9/11 载荷中）
    // - 属性读走标准 GetDevicePropertyValue(0x1015)；0x9114 实为 SetRemoteMode 非属性读
    private const ushort CanonEosGetViewFinderData = 0x9153;
    // Canon EOS 录像/取景扩展（libgphoto2 camlibs/ptp2/ptp.h 常量）：
    // - EVFRecordStatus(0xD1b8)：0=停止录像 1=开始录像（digiCamControl/qDslrDashboard 社区方案）
    // - EVFMode(0xD1b1)：UINT16，0=off 1=on（gphoto2 canon.c 序列）
    // - EVFOutputDevice(0xD1b0)：UINT32 mask，bit0=TFT bit1=PC，2=PC（gphoto2 canon.c 序列）
    private const uint CanonEvfRecordStatus = 0xD1b8;
    private const uint CanonEvfMode = 0xD1b1;
    private const uint CanonEvfOutputDevice = 0xD1b0;
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
    private readonly Dictionary<uint, bool> _writableProperties = [];
    private readonly HashSet<string> _deniedParameters = [];
    private readonly SonyOfficialSdkCamera _sonySDK =
        SonyOfficialSdkCamera.Shared;
    private IPtpVendorOps _vendorOps = new NikonVendorOps();

    public CameraProfile? Profile { get; private set; }
    public bool IsConnected => _sonySDK.IsConnected || _deviceHandle != nint.Zero;
    public bool IsLiveView => _sonySDK.IsConnected
        ? _sonySDK.IsLiveView
        : _liveView;
    public bool IsMovieRecording => _sonySDK.IsConnected
        ? _sonySDK.IsMovieRecording
        : _movieRecording;

    public async Task<CameraStorageSnapshot> ListStorageAsync(
        CancellationToken cancellationToken = default)
    {
        await _gate.WaitAsync(cancellationToken);
        try
        {
            EnsureStorageTransport();
            var resumeLiveView = _liveView;
            if (resumeLiveView) await StopLiveViewCoreAsync(cancellationToken);
            try
            {
                var volumes = new List<CameraStorageVolume>();
                var items = new List<CameraStorageItem>();
                var storageIds = CameraStorageParser.StorageIds(
                    await TransactAsync(
                        GetStorageIds,
                        null,
                        null,
                        15_000,
                        cancellationToken));
                foreach (var storageId in storageIds)
                {
                    volumes.Add(CameraStorageParser.StorageInfo(
                        storageId,
                        await TransactAsync(
                            GetStorageInfo,
                            [storageId],
                            null,
                            15_000,
                            cancellationToken)));
                    var pendingHandles = new Queue<uint>(CameraStorageParser.StorageIds(
                        await TransactAsync(
                            GetObjectHandles,
                            [storageId, 0, uint.MaxValue],
                            null,
                            30_000,
                            cancellationToken)));
                    var visitedHandles = new HashSet<uint>();
                    while (pendingHandles.TryDequeue(out var handle))
                    {
                        if (!visitedHandles.Add(handle)) continue;
                        var objectInfo = await TransactAsync(
                            GetObjectInfo,
                            [handle],
                            null,
                            15_000,
                            cancellationToken);
                        if (CameraStorageParser.IsAssociation(objectInfo))
                        {
                            var children = CameraStorageParser.StorageIds(
                                await TransactAsync(
                                    GetObjectHandles,
                                    [storageId, 0, handle],
                                    null,
                                    30_000,
                                    cancellationToken));
                            foreach (var child in children)
                            {
                                if (!visitedHandles.Contains(child)) pendingHandles.Enqueue(child);
                            }
                        }
                        else
                        {
                            var item = CameraStorageParser.ObjectInfo(handle, objectInfo);
                            if (item is not null) items.Add(item);
                        }
                    }
                }
                items.Sort((left, right) =>
                {
                    var byDate = string.Compare(
                        right.CapturedAt,
                        left.CapturedAt,
                        StringComparison.Ordinal);
                    return byDate != 0
                        ? byDate
                        : string.Compare(
                            right.Filename,
                            left.Filename,
                            StringComparison.OrdinalIgnoreCase);
                });
                return new CameraStorageSnapshot(volumes, items);
            }
            finally
            {
                if (resumeLiveView && IsConnected)
                {
                    await ResumeLiveViewAfterExclusiveOperationAsync(cancellationToken);
                }
            }
        }
        finally
        {
            _gate.Release();
        }
    }

    public async Task<byte[]> GetStorageThumbnailAsync(
        uint handle,
        CancellationToken cancellationToken = default)
    {
        await _gate.WaitAsync(cancellationToken);
        try
        {
            EnsureStorageTransport();
            return await TransactAsync(
                GetThumb,
                [handle],
                null,
                30_000,
                cancellationToken);
        }
        finally
        {
            _gate.Release();
        }
    }

    public async Task<byte[]> DownloadStorageObjectAsync(
        uint handle,
        CancellationToken cancellationToken = default)
    {
        await _gate.WaitAsync(cancellationToken);
        try
        {
            EnsureStorageTransport();
            var resumeLiveView = _liveView;
            if (resumeLiveView) await StopLiveViewCoreAsync(cancellationToken);
            try
            {
                return await TransactAsync(
                    GetObject,
                    [handle],
                    null,
                    180_000,
                    cancellationToken);
            }
            finally
            {
                if (resumeLiveView && IsConnected)
                {
                    await ResumeLiveViewAfterExclusiveOperationAsync(cancellationToken);
                }
            }
        }
        finally
        {
            _gate.Release();
        }
    }

    public async Task DeleteStorageObjectAsync(
        uint handle,
        CancellationToken cancellationToken = default)
    {
        await _gate.WaitAsync(cancellationToken);
        try
        {
            EnsureStorageTransport();
            var resumeLiveView = _liveView;
            if (resumeLiveView) await StopLiveViewCoreAsync(cancellationToken);
            try
            {
                await TransactAsync(
                    DeleteObject,
                    [handle, 0],
                    null,
                    30_000,
                    cancellationToken);
            }
            finally
            {
                if (resumeLiveView && IsConnected)
                {
                    await ResumeLiveViewAfterExclusiveOperationAsync(cancellationToken);
                }
            }
        }
        finally
        {
            _gate.Release();
        }
    }

    private void EnsureStorageTransport()
    {
        if (_sonySDK.IsConnected)
        {
            throw new NotSupportedException(
                "当前 Sony 官方 SDK 会话未开放机内文件枚举；请切换相机为 USB/PTP 或使用 Wi‑Fi/PTP‑IP。");
        }
        EnsureConnected();
    }

    public async Task<CameraProfile> ConnectAsync(
        CancellationToken cancellationToken = default)
    {
        await _gate.WaitAsync(cancellationToken);
        try
        {
            DisconnectCore();
            cancellationToken.ThrowIfCancellationRequested();
            CameraProfile? sonyProfile = null;
            if (await Task.Run(() =>
                {
                    var connected = _sonySDK.TryConnect(out var matched);
                    if (connected) sonyProfile = matched;
                    return connected;
                }, cancellationToken))
            {
                var sonyMatchedProfile =
                    sonyProfile ?? CameraProfile.Find(0x054c, 0)!;
                Profile = sonyMatchedProfile;
                return sonyMatchedProfile;
            }
            InitializeLibUsb();
            var profile = OpenSupportedDevice();
            if (profile.VendorId == 0x054c)
            {
                throw new InvalidOperationException(
                    "已检测到索尼相机，但 Camera Remote SDK 2.02.00 未能建立会话。" +
                    "请在机身 USB 连接设置中启用电脑遥控后重试。");
            }
            _vendorOps = PtpVendorOps.ForVendor(profile.VendorId);
            await TransactAsync(
                OpenSession,
                [1],
                null,
                10_000,
                cancellationToken);
            Profile = profile;
            await RefreshParameterCapabilitiesAsync(cancellationToken);
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
            if (_sonySDK.IsConnected)
            {
                await Task.Run(_sonySDK.StartLiveView, cancellationToken);
                return;
            }
            if (_liveView)
            {
                return;
            }
            if (Profile?.VendorId == 0x04a9)
            {
                // E2 1.5.9：佳能 EOS 取景序列（对齐 libgphoto2 canon.c，TBC-awaiting-hardware）。
                if (!await CanonOpenLiveViewAsync(cancellationToken))
                {
                    throw new InvalidOperationException(
                        $"{CameraName} 未能确认进入佳能实时取景（机身未确认取景输出）。");
                }
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
            if (_sonySDK.IsConnected)
            {
                if (!_sonySDK.IsLiveView)
                {
                    throw new InvalidOperationException("实时取景尚未开启。");
                }
                return await Task.Run(
                    _sonySDK.GetLiveViewFrame,
                    cancellationToken);
            }
            if (!_liveView)
            {
                throw new InvalidOperationException("实时取景尚未开启。");
            }
            if (Profile?.VendorId == 0x04a9)
            {
                // E2 1.5.9：佳能走 EOS_GetViewFinderData(0x9153)（TBC-awaiting-hardware）。
                return await CanonGetLiveViewFrameAsync(cancellationToken);
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
            if (_sonySDK.IsConnected)
            {
                await Task.Run(
                    () => _sonySDK.SetMovieRecording(true),
                    cancellationToken);
                return;
            }
            if (_movieRecording)
            {
                return;
            }
            if (Profile?.VendorId == 0x04a9)
            {
                await CanonStartMovieRecordingAsync(cancellationToken);
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
                _vendorOps.StartMovieRecording,
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
            if (_sonySDK.IsConnected)
            {
                await Task.Run(
                    () => _sonySDK.SetMovieRecording(false),
                    cancellationToken);
                return;
            }
            if (!_movieRecording)
            {
                return;
            }
            if (Profile?.VendorId == 0x04a9)
            {
                try
                {
                    await CanonStopMovieRecordingAsync(cancellationToken);
                }
                finally
                {
                    _movieRecording = false;
                }
                return;
            }
            try
            {
                await TransactAsync(
                    _vendorOps.EndMovieRecording,
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

    /// <summary>
    /// 佳能 EOS 录像启停：经 EOS_SetDevicePropValueEx(0x9110) 写
    /// EVFRecordStatus(0xD1b8)，0=停止录像、1=开始录像。
    /// 参照 libgphoto2 常量与 digiCamControl/qDslrDashboard 社区方案实现，
    /// 未在佳能实机验证（TBC-awaiting-hardware）。
    /// </summary>
    private async Task CanonWriteEosPropAsync(
        uint propCode,
        uint value,
        CancellationToken cancellationToken)
    {
        var payload = new byte[12];
        BinaryPrimitives.WriteUInt32LittleEndian(payload.AsSpan(0, 4), 12);
        BinaryPrimitives.WriteUInt32LittleEndian(
            payload.AsSpan(4, 4), propCode);
        BinaryPrimitives.WriteUInt32LittleEndian(
            payload.AsSpan(8, 4), value);
        await TransactAsync(
            CanonEosSetDevicePropValueEx,
            null,
            payload,
            10_000,
            cancellationToken);
    }

    private async Task CanonStartMovieRecordingAsync(
        CancellationToken cancellationToken)
    {
        // 未处于取景态时，先按 gphoto2 canon.c 序列开启实时取景：
        // EVFMode=1（on）+ EVFOutputDevice 置 PC 位（2）。部分机型在 Movie
        // 模式下对 EVFMode 返回 Busy，容忍失败不阻断录像。
        if (!_liveView)
        {
            try
            {
                await CanonOpenLiveViewAsync(cancellationToken);
            }
            catch (Exception)
            {
                // 取景开启失败不阻断录像（Movie 模式 Busy 容忍）。
            }
        }
        // TBC-awaiting-hardware：EOS 相机开始/停止录像均写 EVFRecordStatus。
        await CanonWriteEosPropAsync(
            CanonEvfRecordStatus,
            1,
            cancellationToken);
        _movieRecording = true;
    }

    private async Task CanonStopMovieRecordingAsync(
        CancellationToken cancellationToken)
    {
        // TBC-awaiting-hardware：0=停止录像。
        await CanonWriteEosPropAsync(
            CanonEvfRecordStatus,
            0,
            cancellationToken);
    }

    /// <summary>
    /// E2 1.5.9：佳能 EOS 实时取景开启（对齐 libgphoto2 canon.c 序列，
    /// TBC-awaiting-hardware）：
    /// 1. EVFMode(0xD1b1) 读当前值，非 1 才写 1（Movie 模式 Busy 容忍）；
    /// 2. EVFOutputDevice(0xD1b0) 条件写——仅当前值 (cur &amp; ~1) == 0 时写 2
    ///    （PC 输出位），读失败回退无条件写。
    /// 返回是否确认进入取景态（两写至少一处被接受/已满足）。
    /// </summary>
    private async Task<bool> CanonOpenLiveViewAsync(
        CancellationToken cancellationToken)
    {
        var confirmed = false;
        // EVFMode：读当前值，非 1 才写（gphoto2「do not set it everytime」）。
        try
        {
            var mode = await CanonReadEosPropValueAsync(
                (ushort)CanonEvfMode,
                cancellationToken);
            if (mode != 1)
            {
                try
                {
                    await CanonWriteEosPropAsync(
                        CanonEvfMode,
                        1,
                        cancellationToken); // TBC-awaiting-hardware
                }
                catch (Exception)
                {
                    // Movie 模式下 EVFMode 可能返回 Busy，容忍继续。
                }
            }
            confirmed = true;
        }
        catch (Exception)
        {
            // 读取失败容忍
        }
        // EVFOutputDevice：仅 (cur & ~1) == 0 时写 2（对齐 libgphoto2 canon.c）。
        try
        {
            uint current;
            try
            {
                current = await CanonReadEosPropValueAsync(
                    (ushort)CanonEvfOutputDevice,
                    cancellationToken);
            }
            catch (Exception)
            {
                current = uint.MaxValue; // 读失败回退无条件写
            }
            if (current == uint.MaxValue || (current & ~1u) == 0)
            {
                try
                {
                    await CanonWriteEosPropAsync(
                        CanonEvfOutputDevice,
                        2,
                        cancellationToken); // TBC-awaiting-hardware
                }
                catch (Exception)
                {
                    // 容忍。
                }
            }
            confirmed = true;
        }
        catch (Exception)
        {
            // 容忍。
        }
        _liveView = confirmed;
        return confirmed;
    }

    /// <summary>
    /// E2 1.5.9：佳能 EOS 实时取景取帧——GetViewFinderData(0x9153)，
    /// 数据段为 EOS dataset（[u32 len][u32 type][payload] 序列），
    /// JPEG 在 type 1/9/11 载荷中（TBC-awaiting-hardware）。
    /// </summary>
    private async Task<byte[]> CanonGetLiveViewFrameAsync(
        CancellationToken cancellationToken)
    {
        var raw = await TransactAsync(
            CanonEosGetViewFinderData,
            [0x00200000u, 0u, 0u],
            null,
            12_000,
            cancellationToken);
        return ExtractEosJpeg(raw);
    }

    /// <summary>
    /// E2 1.5.9：EOS dataset → 内嵌 JPEG 提取。对齐 libgphoto2 library.c
    /// ptp_canon_eos_get_viewfinder_image 的解析：多个 blob 依
    /// [u32 len][u32 type][payload] 排列；type 1=常规 JPEG、9=Movie 模式 JPEG、
    /// 11=JPEG；其余 type 跳过 len 字节。
    /// </summary>
    private byte[] ExtractEosJpeg(byte[] source)
    {
        var offset = 0;
        while (offset + 8 <= source.Length)
        {
            var len = (int)BinaryPrimitives.ReadUInt32LittleEndian(
                source.AsSpan(offset, 4));
            var type = BinaryPrimitives.ReadUInt32LittleEndian(
                source.AsSpan(offset + 4, 4));
            if (len < 8 || offset + len > source.Length)
            {
                break;
            }
            if (type == 1 || type == 9 || type == 11)
            {
                // 载荷为 JPEG；再经标记扫描兜底（部分机身载荷带前导头）。
                return ExtractJpeg(source[offset..(offset + len)]);
            }
            offset += len;
        }
        throw new IOException(
            $"{CameraName} 返回的佳能取景数据中没有 JPEG 图像。");
    }

    /// <summary>
    /// E2 1.5.9：EOS 属性读取。走标准 GetDevicePropertyValue(0x1015)——gphoto2
    /// 对 EOS 属性读取同样用标准 0x1015/0x1014；0x9114 实为 SetRemoteMode 非属性读。
    /// UINT16 属性返回 2 字节，UINT32 返回 4 字节。
    /// </summary>
    private async Task<uint> CanonReadEosPropValueAsync(
        ushort propCode,
        CancellationToken cancellationToken)
    {
        var data = await TransactAsync(
            GetDevicePropertyValue,
            [propCode],
            null,
            5_000,
            cancellationToken);
        if (data.Length < 2)
        {
            throw new InvalidOperationException("佳能属性读取返回长度不足。");
        }
        return data.Length >= 4
            ? BinaryPrimitives.ReadUInt32LittleEndian(data)
            : BinaryPrimitives.ReadUInt16LittleEndian(data);
    }

    public async Task<byte[]> CaptureAsync(
        CancellationToken cancellationToken = default)
    {
        await _gate.WaitAsync(cancellationToken);
        try
        {
            EnsureConnected();
            if (_sonySDK.IsConnected)
            {
                return await Task.Run(_sonySDK.Capture, cancellationToken);
            }
            var resumeLiveView = _liveView;
            var releaseRemoteMode = false;
            if (resumeLiveView)
            {
                await StopLiveViewCoreAsync(cancellationToken);
            }
            try
            {
                await WaitUntilDeviceReadyAsync(8_000, cancellationToken);
                if (_exposureMode == "bulb")
                {
                    await TransactAsync(
                        ChangeCameraMode,
                        [1],
                        null,
                        10_000,
                        cancellationToken);
                    releaseRemoteMode = true;
                    await SetPropertyCoreAsync(
                        0x500e,
                        LittleEndian16(1),
                        cancellationToken);
                    await SetShutterRawAsync(
                        false,
                        uint.MaxValue,
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
                await WaitUntilDeviceReadyAsync(8_000, cancellationToken);
                return ExtractJpeg(source);
            }
            finally
            {
                if (releaseRemoteMode && IsConnected)
                {
                    try
                    {
                        await WaitUntilDeviceReadyAsync(8_000, cancellationToken);
                    }
                    catch
                    {
                        // Still try to release remote mode below.
                    }
                    try
                    {
                        await TransactAsync(
                            ChangeCameraMode,
                            [0],
                            null,
                            10_000,
                            cancellationToken);
                    }
                    catch
                    {
                        // The capture result is still valid. A reconnect will
                        // release remote mode if the body disappeared.
                    }
                }
                if (resumeLiveView && IsConnected)
                {
                    await ResumeLiveViewAfterExclusiveOperationAsync(
                        cancellationToken);
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
        var resumeLiveView = false;
        try
        {
            EnsureConnected();
            if (_sonySDK.IsConnected)
            {
                await Task.Run(
                    () => _sonySDK.SetParameter(name, rawValue),
                    cancellationToken);
                return;
            }
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
            resumeLiveView = _liveView;
            if (resumeLiveView)
            {
                await StopLiveViewCoreAsync(cancellationToken);
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

            if (name == "videoCodec")
            {
                await SetVideoCodecAsync(
                    Convert.ToString(rawValue) ?? "h265",
                    cancellationToken);
                return;
            }
            if (name == "videoLog")
            {
                await SetVideoLogAsync(
                    Convert.ToString(rawValue) ?? "off",
                    cancellationToken);
                return;
            }
            if (name == "nLog")
            {
                await SetVideoLogAsync(
                    Convert.ToBoolean(rawValue) ? "nlog" : "off",
                    cancellationToken);
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
                case "videoExposureTime":
                    await SetShutterSecondsAsync(
                        number,
                        name == "videoExposureTime",
                        cancellationToken);
                    return;
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
                        // Keep Bulb local until CaptureAsync starts. Entering
                        // Nikon remote mode here leaves the body shutter locked.
                        _exposureMode = requestedExposureMode;
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
            throw new InvalidOperationException(
                $"{CameraName} 当前状态暂时拒绝写入此参数。" +
                "请确认机身处于允许调整的曝光模式后重试。",
                error);
        }
        finally
        {
            if (resumeLiveView && IsConnected)
            {
                await ResumeLiveViewAfterExclusiveOperationAsync(
                    cancellationToken);
            }
            _gate.Release();
        }
    }

    private async Task SetVideoCodecAsync(
        string codec,
        CancellationToken cancellationToken)
    {
        if (Profile is null)
        {
            throw new InvalidOperationException("请先连接支持的相机。");
        }
        if (Profile.VendorId == 0x054c)
        {
            var sonyValue = codec switch
            {
                "sonyXavcHs8k" => 10,
                "sonyXavcHs4k" => 11,
                "sonyXavcS4k" => 8,
                "sonyXavcSHd" => 9,
                "sonyXavcSi4k" => 14,
                "sonyXavcSiHd" => 15,
                _ => -1
            };
            if (sonyValue < 0)
            {
                throw new InvalidOperationException(
                    "Sony 不支持所选视频录制规格。");
            }
            await SetPropertyCoreAsync(
                SonyMovieFileFormat,
                [(byte)sonyValue],
                cancellationToken);
            return;
        }
        if (Profile.VendorId == 0x04a9)
        {
            // E2 1.5.9 边界：佳能录制格式维持显式抛错——EOS 通道仅覆盖
            // 取景/参数读写；录制规格需在机身选择（TBC-awaiting-hardware）。
            throw new InvalidOperationException(
                $"{CameraName} 未报告可写的佳能录制格式属性；" +
                "规格已展示，请在机身中选择 RAW、XF-HEVC S 或 XF-AVC S。");
        }
        if (Profile.VendorId != 0x04b0)
        {
            throw new InvalidOperationException(
                "当前相机不支持远程切换视频录制规格。");
        }
        if ((codec is "nRaw" or "proResRAW" or "proRes422HQ") &&
            !(CameraName.Contains("Z9", StringComparison.OrdinalIgnoreCase) ||
              CameraName.Contains("Z8", StringComparison.OrdinalIgnoreCase) ||
              CameraName.Contains("Z6III", StringComparison.OrdinalIgnoreCase) ||
              CameraName.Contains("ZR", StringComparison.OrdinalIgnoreCase)))
        {
            throw new InvalidOperationException(
                $"{CameraName} 不支持所选 RAW/ProRes 视频编码。");
        }
        var value = codec.ToLowerInvariant() switch
        {
            "h265" => NikonH265TenBit,
            "prores422hq" => NikonProRes422TenBit,
            "proresraw" => NikonProResRawTwelveBit,
            "nraw" => NikonNRawTwelveBit,
            _ => NikonH264EightBit
        };
        await SetPropertyCoreAsync(
            NikonMovieFileType,
            LittleEndian32(value),
            cancellationToken);
    }

    private async Task SetVideoLogAsync(
        string logProfile,
        CancellationToken cancellationToken)
    {
        if (Profile is null)
        {
            throw new InvalidOperationException("请先连接支持的相机。");
        }
        if (Profile.VendorId == 0x054c)
        {
            var sonyValue = logProfile switch
            {
                "off" => 0,
                "sonySLog2" => 7,
                "sonySLog3Cine" => 8,
                "sonySLog3" => 9,
                "sonyHlg" => 10,
                _ => -1
            };
            if (sonyValue < 0)
            {
                throw new InvalidOperationException(
                    "Sony 不支持所选 Log / Picture Profile。");
            }
            await SetPropertyCoreAsync(
                SonyPictureProfile,
                [(byte)sonyValue],
                cancellationToken);
            return;
        }
        if (Profile.VendorId == 0x04a9)
        {
            var canonValue = logProfile switch
            {
                "off" => 0,
                "canonLog" => 1,
                "canonLog2" => 2,
                "canonLog3" => 3,
                _ => -1
            };
            if (canonValue < 0)
            {
                throw new InvalidOperationException(
                    "Canon 不支持所选 Canon Log 曲线。");
            }
            var payload = new byte[12];
            BinaryPrimitives.WriteUInt32LittleEndian(payload.AsSpan(0, 4), 12);
            BinaryPrimitives.WriteUInt32LittleEndian(
                payload.AsSpan(4, 4), CanonLogGamma);
            BinaryPrimitives.WriteUInt32LittleEndian(
                payload.AsSpan(8, 4), (uint)canonValue);
            await TransactAsync(
                CanonEosSetDevicePropValueEx,
                null,
                payload,
                10_000,
                cancellationToken);
            return;
        }
        if (Profile.VendorId != 0x04b0)
        {
            throw new InvalidOperationException(
                "当前相机不支持远程切换 Log 曲线。");
        }
        var enabled = logProfile != "off";
        if (enabled && logProfile != "nlog")
        {
            throw new InvalidOperationException("Nikon 机身仅支持 N-Log。");
        }
        var fileTypeData = await TransactAsync(
            GetDevicePropertyValue,
            [NikonMovieFileType],
            null,
            10_000,
            cancellationToken);
        if (fileTypeData.Length < 4)
        {
            throw new InvalidOperationException(
                "相机未返回有效的视频编码值。");
        }
        var fileType = BinaryPrimitives.ReadUInt32LittleEndian(fileTypeData);
        var toneProperty = NikonToneProperty(fileType, enabled);
        if (toneProperty == 0) return;
        await SetPropertyCoreAsync(
            toneProperty,
            [(byte)(enabled ? 1 : 0)],
            cancellationToken);
    }

    private static uint NikonToneProperty(uint fileType, bool enabled) =>
        fileType switch
        {
            NikonH265TenBit => NikonMovieH265ToneMode,
            NikonNRawTwelveBit => NikonMovieNRawToneMode,
            NikonProRes422TenBit => NikonMovieProResToneMode,
            NikonProResRawTwelveBit => NikonMovieProResRawToneMode,
            _ when !enabled => 0,
            _ => throw new InvalidOperationException(
                "当前编码不支持 N-Log；请选择 H.265 10-bit、N-RAW、" +
                "ProRes 422 HQ 或 ProRes RAW。")
        };

    public async Task MoveFocusAsync(
        int signedStep,
        CancellationToken cancellationToken = default)
    {
        await _gate.WaitAsync(cancellationToken);
        var resumeLiveView = false;
        try
        {
            EnsureConnected();
            if (_sonySDK.IsConnected)
            {
                throw new InvalidOperationException(
                    "Sony Camera Remote SDK 当前未开放本机型的相对焦点步进。");
            }
            if (!_liveView)
            {
                throw new InvalidOperationException(
                    "焦点步进仅能在实时取景开启时使用。");
            }
            var normalized = Math.Clamp(signedStep, -3, 3);
            if (normalized == 0)
            {
                return;
            }

            // A live-view frame can still be draining inside the camera when
            // the host receives its response.  Nikon reports that transition
            // as PTP DeviceBusy (0x2019), which gphoto2 surfaces as
            // "I/O in progress".  Make the focus operation exclusive and
            // restart live view before issuing 0x9204 so polling cannot race
            // the lens-drive command.
            resumeLiveView = _liveView;
            if (resumeLiveView)
            {
                await StopLiveViewCoreAsync(cancellationToken);
                await StartLiveViewForManualFocusAsync(cancellationToken);
            }

            var direction = normalized < 0 ? 0x1u : 0x2u;
            var amount = Math.Abs(normalized) switch
            {
                1 => 128u,
                2 => 512u,
                _ => 1024u
            };
            await SendManualFocusDriveWithRetryAsync(
                direction,
                amount,
                cancellationToken);
            await WaitUntilDeviceReadyAsync(4_000, cancellationToken);
        }
        finally
        {
            if (resumeLiveView && IsConnected && !_liveView)
            {
                await ResumeLiveViewAfterExclusiveOperationAsync(
                    CancellationToken.None);
            }
            _gate.Release();
        }
    }

    public async Task TriggerAutoFocusAsync(
        CancellationToken cancellationToken = default)
    {
        await _gate.WaitAsync(cancellationToken);
        var resumeLiveView = false;
        try
        {
            EnsureConnected();
            if (_sonySDK.IsConnected)
            {
                if (!_sonySDK.IsLiveView)
                {
                    throw new InvalidOperationException(
                        "AF-ON 仅能在实时取景开启时使用。");
                }
                await Task.Run(_sonySDK.TriggerAutofocus, cancellationToken);
                return;
            }
            if (!_liveView)
            {
                throw new InvalidOperationException(
                    "AF-ON 仅能在实时取景开启时使用。");
            }
            resumeLiveView = _liveView;
            if (resumeLiveView)
            {
                await StopLiveViewCoreAsync(cancellationToken);
                await StartLiveViewForManualFocusAsync(cancellationToken);
            }
            try
            {
                await SetPropertyCoreAsync(
                    0xd061,
                    [0],
                    cancellationToken);
            }
            catch (CameraProtocolException)
            {
                await SetPropertyCoreAsync(
                    0x500a,
                    LittleEndian16(0x8010),
                    cancellationToken);
            }
            await SendAutoFocusDriveWithRetryAsync(cancellationToken);
            await WaitUntilDeviceReadyAsync(4_000, cancellationToken);
        }
        finally
        {
            if (resumeLiveView && IsConnected && !_liveView)
            {
                await ResumeLiveViewAfterExclusiveOperationAsync(
                    CancellationToken.None);
            }
            _gate.Release();
        }
    }

    private async Task SendAutoFocusDriveWithRetryAsync(
        CancellationToken cancellationToken)
    {
        Exception? finalError = null;
        for (var attempt = 1; attempt <= 5; attempt++)
        {
            try
            {
                await TransactAsync(
                    0x90c1,
                    [],
                    null,
                    10_000,
                    cancellationToken);
                return;
            }
            catch (CameraProtocolException error)
                when (IsDeviceBusyResponse(error.ResponseCode))
            {
                finalError = error;
            }
            catch (IOException error)
                when (IsUsbBusy(error))
            {
                finalError = error;
            }
            if (attempt < 5)
            {
                await Task.Delay(180 * attempt, cancellationToken);
            }
        }
        throw new InvalidOperationException(
            $"{CameraName} 当前正在处理上一条相机指令，AF-ON 未执行。",
            finalError);
    }

    private async Task StartLiveViewForManualFocusAsync(
        CancellationToken cancellationToken)
    {
        Exception? finalError = null;
        for (var attempt = 1; attempt <= 3; attempt++)
        {
            try
            {
                await WaitUntilDeviceReadyAsync(4_000, cancellationToken);
                await TransactAsync(
                    StartLiveViewOperation,
                    null,
                    null,
                    10_000,
                    cancellationToken);
                _liveView = true;
                // Give the body one frame interval to leave the start-live-view
                // transition before accepting the lens-drive command.
                await Task.Delay(180, cancellationToken);
                return;
            }
            catch (Exception error)
                when (!cancellationToken.IsCancellationRequested)
            {
                finalError = error;
                _liveView = false;
                if (attempt < 3)
                {
                    await Task.Delay(180 * attempt, cancellationToken);
                }
            }
        }
        throw new InvalidOperationException(
            $"{CameraName} 无法为手动对焦恢复实时取景。",
            finalError);
    }

    private async Task SendManualFocusDriveWithRetryAsync(
        uint direction,
        uint amount,
        CancellationToken cancellationToken)
    {
        Exception? finalError = null;
        for (var attempt = 1; attempt <= 5; attempt++)
        {
            try
            {
                await TransactAsync(
                    ManualFocusDriveOperation,
                    [direction, amount],
                    null,
                    10_000,
                    cancellationToken);
                return;
            }
            catch (CameraProtocolException error)
                when (IsDeviceBusyResponse(error.ResponseCode))
            {
                finalError = error;
            }
            catch (IOException error)
                when (IsUsbBusy(error))
            {
                finalError = error;
            }

            if (attempt < 5)
            {
                await Task.Delay(180 * attempt, cancellationToken);
            }
        }
        throw new InvalidOperationException(
            $"{CameraName} 当前正在处理上一条相机指令，手动对焦未执行。",
            finalError);
    }

    private static bool IsDeviceBusyResponse(ushort responseCode) =>
        responseCode == 0x2019;

    private static bool IsUsbBusy(IOException error)
    {
        var message = error.Message;
        return message.Contains("BUSY", StringComparison.OrdinalIgnoreCase) ||
            message.Contains("I/O in progress", StringComparison.OrdinalIgnoreCase);
    }

    public async Task DisconnectAsync(
        CancellationToken cancellationToken = default)
    {
        await _gate.WaitAsync(cancellationToken);
        try
        {
            if (_sonySDK.IsConnected)
            {
                if (_sonySDK.IsMovieRecording)
                {
                    try { _sonySDK.SetMovieRecording(false); } catch { }
                }
                _sonySDK.StopLiveView();
                _sonySDK.Disconnect();
                Profile = null;
                return;
            }
            if (_movieRecording)
            {
                try
                {
                    if (Profile?.VendorId == 0x04a9)
                    {
                        await CanonStopMovieRecordingAsync(cancellationToken);
                    }
                    else
                    {
                        await TransactAsync(
                            _vendorOps.EndMovieRecording,
                            null,
                            null,
                            15_000,
                            cancellationToken);
                    }
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

        ushort? unsupportedVendor = null;
        ushort? unsupportedProduct = null;
        try
        {
            for (nint index = 0; index < count; index++)
            {
                var device = Marshal.ReadIntPtr(list, checked((int)index * nint.Size));
                if (device == nint.Zero ||
                    LibUsbNative.libusb_get_device_descriptor(
                        device,
                        out var descriptor) != LibUsbNative.Success ||
                    !CameraProfile.SupportedVendorIds.Contains(descriptor.VendorId))
                {
                    continue;
                }

                var profile = CameraProfile.Find(descriptor.VendorId, descriptor.ProductId);
                if (profile is null)
                {
                    unsupportedVendor = descriptor.VendorId;
                    unsupportedProduct = descriptor.ProductId;
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

        if (unsupportedVendor.HasValue)
        {
            throw new InvalidOperationException(
                $"检测到未支持的 USB 相机设备 {unsupportedVendor.Value:x4}:{unsupportedProduct.Value:x4}。" +
                $"当前支持 {CameraProfile.Summary}。");
        }
        throw new InvalidOperationException(
            $"没有检测到支持的相机。请连接 {CameraProfile.Summary}。");
    }

    private void OpenDevice(nint device, CameraProfile profile)
    {
        var status = LibUsbNative.libusb_open(device, out _deviceHandle);
        if (status != LibUsbNative.Success || _deviceHandle == nint.Zero)
        {
            var errorName = LibUsbNative.ErrorName(status);
            throw new InvalidOperationException(
                $"无法打开 {profile.Name}：{errorName}。" +
                "请关闭 NX Tether、Camera Control Pro、照片等可能占用相机的软件，" +
                "并使用 Zadig 将相机 PTP/Still Image 接口替换为 WinUSB 或 libusbK。");
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
            var errorName = LibUsbNative.ErrorName(status);
            var guidance = status == LibUsbNative.ErrorAccess
                ? "\n请依次排查：\n"
                    + "1. 关闭 NX Tether、Camera Control Pro、照片、"
                    + "文件资源管理器等可能占用相机的软件。\n"
                    + "2. 在 Zadig 中选择正确的 PTP/Still Image 接口"
                    + "（而非整个设备），替换为 WinUSB 或 libusbK。\n"
                    + "3. 更换 USB 端口或数据线后重试。\n"
                    + "4. 在设备管理器中确认相机接口驱动已替换，"
                    + "未被 Windows 内置驱动重新抢占。"
                : "。请安装 WinUSB/libusbK 驱动。";
            throw new InvalidOperationException(
                $"无法声明 {profile.Name} 的 PTP 接口：{errorName}{guidance}");
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
        var transaction = operation == OpenSession ? 0 : ++_transaction;
        _transaction = transaction;
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
        if (response.Code != ResponseOk &&
            !(operation == OpenSession &&
              response.Code == ResponseSessionAlreadyOpen))
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
        uint property,
        byte[] value,
        CancellationToken cancellationToken) =>
        TransactAsync(
            SetDeviceProperty,
            [property],
            value,
            10_000,
            cancellationToken);

    private async Task SetShutterSecondsAsync(
        double seconds,
        bool video,
        CancellationToken cancellationToken)
    {
        if (!double.IsFinite(seconds) || seconds <= 0)
        {
            throw new InvalidOperationException("快门速度必须大于 0 秒。");
        }
        CameraProtocolException? finalError = null;
        foreach (var property in ShutterProperties(video))
        {
            var encoded = property == ExposureTime
                ? LittleEndian32((uint)Math.Round(seconds * 10_000))
                : EncodeShutterValue(seconds);
            try
            {
                await SetPropertyCoreAsync(
                    property,
                    encoded,
                    cancellationToken);
                return;
            }
            catch (CameraProtocolException error)
                when (IsPropertyCompatibilityResponse(error.ResponseCode))
            {
                finalError = error;
            }
        }
        throw new InvalidOperationException(
            $"{CameraName} 当前没有可写的{(video ? "视频" : "照片")}快门属性。" +
            "请确认相机处于 M/S 模式，且未在机身菜单中锁定曝光参数。",
            finalError);
    }

    private async Task SetShutterRawAsync(
        bool video,
        uint rawValue,
        CancellationToken cancellationToken)
    {
        CameraProtocolException? finalError = null;
        foreach (var property in ShutterProperties(video))
        {
            try
            {
                await SetPropertyCoreAsync(
                    property,
                    LittleEndian32(rawValue),
                    cancellationToken);
                return;
            }
            catch (CameraProtocolException error)
                when (IsPropertyCompatibilityResponse(error.ResponseCode))
            {
                finalError = error;
            }
        }
        throw new InvalidOperationException(
            $"{CameraName} 当前不支持通过 USB/PTP 设置 B 门快门。",
            finalError);
    }

    private ushort[] ShutterProperties(bool video) => video
        ? _vendorOps.VideoShutterProperties
        : _vendorOps.ShutterProperties;

    private byte[] EncodeShutterValue(double seconds) =>
        _vendorOps.EncodeShutterValue(seconds);

    private bool HasWritableShutterProperty(bool video)
    {
        var hasUnknownProperty = false;
        foreach (var property in ShutterProperties(video))
        {
            if (!_writableProperties.TryGetValue(property, out var writable))
            {
                hasUnknownProperty = true;
            }
            else if (writable)
            {
                return true;
            }
        }
        return hasUnknownProperty;
    }

    private static byte[] NikonShutterValue(double seconds)
    {
        long numerator;
        long denominator;
        if (seconds < 1)
        {
            numerator = 1;
            denominator = Math.Max(1, (long)Math.Round(1 / seconds));
        }
        else if (Math.Abs(seconds - Math.Round(seconds)) < 0.000001)
        {
            numerator = (long)Math.Round(seconds);
            denominator = 1;
        }
        else
        {
            denominator = 1_000;
            numerator = (long)Math.Round(seconds * denominator);
            var divisor = GreatestCommonDivisor(numerator, denominator);
            numerator /= divisor;
            denominator /= divisor;
        }
        numerator = Math.Clamp(numerator, 1, ushort.MaxValue);
        denominator = Math.Clamp(denominator, 1, ushort.MaxValue);
        return LittleEndian32(
            (uint)((numerator << 16) | denominator));
    }

    private static long GreatestCommonDivisor(long left, long right)
    {
        while (right != 0)
        {
            var remainder = left % right;
            left = right;
            right = remainder;
        }
        return Math.Max(1, left);
    }

    private static bool IsPropertyCompatibilityResponse(ushort code) =>
        code is 0x2005 or 0x200a or 0x200f or 0x201c or 0x201d;

    private async Task WaitUntilDeviceReadyAsync(
        int timeoutMilliseconds,
        CancellationToken cancellationToken)
    {
        CameraProtocolException? finalError = null;
        var deadline = DateTime.UtcNow.AddMilliseconds(timeoutMilliseconds);
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
                return;
            }
            catch (CameraProtocolException error)
            {
                finalError = error;
                await Task.Delay(180, cancellationToken);
            }
        }
        throw new InvalidOperationException(
            $"{CameraName} 在独占操作后未恢复就绪状态。",
            finalError);
    }

    private async Task ResumeLiveViewAfterExclusiveOperationAsync(
        CancellationToken cancellationToken)
    {
        for (var attempt = 1; attempt <= 3 && IsConnected; attempt++)
        {
            try
            {
                await WaitUntilDeviceReadyAsync(4_000, cancellationToken);
                await TransactAsync(
                    StartLiveViewOperation,
                    null,
                    null,
                    10_000,
                    cancellationToken);
                _liveView = true;
                return;
            }
            catch when (!cancellationToken.IsCancellationRequested)
            {
                _liveView = false;
                await Task.Delay(250 * attempt, cancellationToken);
            }
        }
    }

    private async Task StopLiveViewCoreAsync(
        CancellationToken cancellationToken)
    {
        if (_sonySDK.IsConnected)
        {
            _sonySDK.StopLiveView();
            return;
        }
        if (!_liveView || !IsConnected)
        {
            _liveView = false;
            return;
        }
        if (Profile?.VendorId == 0x04a9)
        {
            try
            {
                // E2 1.5.9：佳能先关 PC 输出再关取景模式（TBC-awaiting-hardware）。
                await CanonWriteEosPropAsync(
                    CanonEvfOutputDevice,
                    0,
                    cancellationToken);
                await CanonWriteEosPropAsync(
                    CanonEvfMode,
                    0,
                    cancellationToken);
            }
            catch (Exception)
            {
                // 忽略关闭失败
            }
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
        if (_sonySDK.IsConnected)
        {
            return name is "exposureTime" or "videoExposureTime" or
                "aperture" or "iso" or "exposureCompensation" or
                "videoCodec" or "videoLog";
        }
        if (name == "videoCodec" && Profile?.VendorId == 0x04a9)
        {
            return false;
        }
        if (_deniedParameters.Contains(name) || !CanAdjust(name))
        {
            return false;
        }
        return true;
    }

    public string ParameterLockReason(string name)
    {
        if (name == "videoCodec" && Profile?.VendorId == 0x04a9)
        {
            return "该 Canon 机身未报告通用可写的录制格式属性，请在机身菜单中选择规格";
        }
        if (_deniedParameters.Contains(name))
        {
            return "相机已拒绝此参数，本次连接内保持锁定";
        }
        if (!CanAdjust(name))
        {
            return "当前拍摄模式下由相机控制";
        }
        return "当前不可调整";
    }

    private bool CanAdjust(string name) => name switch
    {
        "exposureTime" or "videoExposureTime" =>
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
        var vendorProperties = new List<uint> { ExposureTime };
        foreach (var p in _vendorOps.ShutterProperties)
            if (!vendorProperties.Contains(p)) vendorProperties.Add(p);
        foreach (var p in _vendorOps.VideoShutterProperties)
            if (!vendorProperties.Contains(p)) vendorProperties.Add(p);
        if (_vendorOps.PictureControlProperty is { } pc && !vendorProperties.Contains(pc))
            vendorProperties.Add(pc);
        uint[] properties =
        [
            0x5005, 0x5007, 0x500a,
            0x500e, 0x500f, 0x5010,
            NikonMovieFileType, NikonMovieProResToneMode,
            NikonMovieH265ToneMode, NikonMovieNRawToneMode,
            NikonMovieProResRawToneMode,
            SonyMovieFileFormat, SonyPictureProfile,
            .. vendorProperties,
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

    private uint PropertyCode(string name) => name switch
    {
        "whiteBalanceMode" => 0x5005,
        "aperture" => 0x5007,
        "focusMode" => 0x500a,
        "exposureTime" => ExposureTime,
        "videoExposureTime" => _vendorOps.VideoShutterProperties[0],
        "exposureMode" => 0x500e,
        "iso" => 0x500f,
        "exposureCompensation" => 0x5010,
        "pictureControl" => _vendorOps.PictureControlProperty ?? 0,
        "videoCodec" => Profile?.VendorId == 0x054c
            ? SonyMovieFileFormat
            : NikonMovieFileType,
        "videoLog" or "nLog" => Profile?.VendorId switch
        {
            0x054c => SonyPictureProfile,
            0x04a9 => CanonLogGamma,
            _ => NikonMovieH265ToneMode
        },
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
            throw new InvalidOperationException("请先连接支持的相机。");
        }
    }

    private void EnsureConnectedForOperation(ushort operation)
    {
        if (operation == OpenSession)
        {
            if (_deviceHandle == nint.Zero)
            {
                throw new InvalidOperationException("无法打开 USB 相机连接。");
            }
            return;
        }
        EnsureConnected();
    }

    private string CameraName => Profile?.Name ?? "相机";

    private void DisconnectCore()
    {
        if (_sonySDK.IsConnected)
        {
            _sonySDK.Disconnect();
        }
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
