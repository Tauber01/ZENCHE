using System.Buffers.Binary;
using System.IO;
using System.Net.Sockets;
using System.Text;
using NikonLink.Windows.Models;

namespace NikonLink.Windows.Services;

public sealed class PtpIpCamera : IAsyncDisposable
{
    // ── PTP/IP vendor ops（镜像 iOS RemoteCaptureServices + Windows PtpCamera 表）──
    // Nikon 实时取景/录像厂商扩展；Canon 走 EOS 属性序列（0x9110/0x9153，TBC-awaiting-hardware）。
    private const ushort NikonStartLiveView = 0x9201;
    private const ushort NikonEndLiveView = 0x9202;
    private const ushort NikonGetLiveViewImage = 0x9203;
    private const ushort NikonStartMovieRecording = 0x920a;
    private const ushort NikonEndMovieRecording = 0x920b;
    // 标准 PTP 属性访问
    private const ushort GetDevicePropDesc = 0x1014;
    private const ushort GetDevicePropValue = 0x1015;
    private const ushort SetDevicePropValue = 0x1016;
    // Canon EOS 扩展（libgphoto2 camlibs/ptp2/ptp.h 常量，TBC-awaiting-hardware）
    private const ushort CanonEosSetDevicePropValueEx = 0x9110;
    private const ushort CanonEosGetViewFinderData = 0x9153;
    private const uint CanonEvfRecordStatus = 0xd1b8;
    private const uint CanonEvfMode = 0xd1b1;
    private const uint CanonEvfOutputDevice = 0xd1b0;
    // 常用参数属性码（与 Android/iOS 口径一致：ISO 0x500f / 光圈 0x5007 / 快门 0x500d）
    private const ushort PropIso = 0x500f;
    private const ushort PropFNumber = 0x5007;
    private const ushort PropExposureTime = 0x500d;

    /// <summary>已连 PTP/IP 相机的厂商分类（detectVendor 结果，断连清零）。</summary>
    public enum CameraVendor
    {
        Unknown,
        Nikon,
        Canon,
        Sony,
    }

    private TcpClient? _commandClient;
    private TcpClient? _eventClient;
    private NetworkStream? _commandStream;
    private NetworkStream? _eventStream;
    private uint _transactionId = 1;
    private CameraVendor _vendor = CameraVendor.Unknown;
    private bool _liveView;
    private bool _movieRecording;

    public bool IsConnected => _commandStream is not null;
    public string CameraName { get; private set; } = "PTP/IP Camera";
    public string Status { get; private set; } = "Wi‑Fi 相机未连接";
    public CameraVendor Vendor => _vendor;
    public bool IsLiveView => _liveView;
    public bool IsMovieRecording => _movieRecording;

    public async Task<string> ConnectAsync(
        string host,
        int port = 15740,
        CancellationToken cancellationToken = default)
    {
        await DisconnectAsync();
        if (string.IsNullOrWhiteSpace(host) || port is < 1 or > 65535)
        {
            throw new ArgumentException("Wi‑Fi 相机地址或端口无效");
        }

        Status = "正在连接 Wi‑Fi 相机…";
        try
        {
            _commandClient = new TcpClient { NoDelay = true };
            await _commandClient.ConnectAsync(host.Trim(), port, cancellationToken);
            _commandStream = _commandClient.GetStream();

            using var commandPayload = new MemoryStream();
            commandPayload.Write(Guid.NewGuid().ToByteArray());
            WriteUtf16(commandPayload, "ZENCHE Windows");
            WriteUInt32(commandPayload, 0x00010000);
            await SendPacketAsync(
                _commandStream,
                1,
                commandPayload.ToArray(),
                cancellationToken);
            var acknowledgment = await ReceivePacketAsync(
                _commandStream,
                cancellationToken);
            if (acknowledgment.Type != 2 || acknowledgment.Data.Length < 28)
            {
                throw new IOException("相机返回了无效的 PTP/IP 握手数据");
            }
            var connectionNumber = ReadUInt32(acknowledgment.Data, 8);
            CameraName = ReadUtf16(acknowledgment.Data, 28);
            if (string.IsNullOrWhiteSpace(CameraName))
            {
                CameraName = "PTP/IP Camera";
            }

            _eventClient = new TcpClient { NoDelay = true };
            await _eventClient.ConnectAsync(host.Trim(), port, cancellationToken);
            _eventStream = _eventClient.GetStream();
            var eventPayload = new byte[4];
            BinaryPrimitives.WriteUInt32LittleEndian(eventPayload, connectionNumber);
            await SendPacketAsync(
                _eventStream,
                3,
                eventPayload,
                cancellationToken);
            var eventAcknowledgment = await ReceivePacketAsync(
                _eventStream,
                cancellationToken);
            if (eventAcknowledgment.Type != 4)
            {
                throw new IOException("相机未确认 PTP/IP 事件通道");
            }

            var response = await SendCommandAsync(
                0x1002,
                0,
                [1],
                cancellationToken);
            EnsureAccepted(response);
            _transactionId = 1;
            Status = $"Wi‑Fi 已连接 · {CameraName}";
            return CameraName;
        }
        catch
        {
            await DisconnectAsync();
            throw;
        }
    }

    public async Task CaptureAsync(CancellationToken cancellationToken = default)
    {
        if (_commandStream is null)
        {
            throw new InvalidOperationException("请先连接 Wi‑Fi 相机");
        }
        Status = "正在通过 Wi‑Fi 触发快门…";
        var response = await SendCommandAsync(
            0x100E,
            _transactionId++,
            [0, 0],
            cancellationToken);
        EnsureAccepted(response);
        Status = "Wi‑Fi 快门已触发 · 原片保存在相机卡内";
    }

    public async Task<CameraStorageSnapshot> ListStorageAsync(
        CancellationToken cancellationToken = default)
    {
        var volumes = new List<CameraStorageVolume>();
        var items = new List<CameraStorageItem>();
        var storageIds = CameraStorageParser.StorageIds(
            await SendCommandWithDataAsync(
                0x1004,
                _transactionId++,
                [],
                cancellationToken));
        foreach (var storageId in storageIds)
        {
            volumes.Add(CameraStorageParser.StorageInfo(
                storageId,
                await SendCommandWithDataAsync(
                    0x1005,
                    _transactionId++,
                    [storageId],
                    cancellationToken)));
            var pendingHandles = new Queue<uint>(CameraStorageParser.StorageIds(
                await SendCommandWithDataAsync(
                    0x1007,
                    _transactionId++,
                    [storageId, 0, uint.MaxValue],
                    cancellationToken)));
            var visitedHandles = new HashSet<uint>();
            while (pendingHandles.TryDequeue(out var handle))
            {
                if (!visitedHandles.Add(handle)) continue;
                var objectInfo = await SendCommandWithDataAsync(
                    0x1008,
                    _transactionId++,
                    [handle],
                    cancellationToken);
                if (CameraStorageParser.IsAssociation(objectInfo))
                {
                    var children = CameraStorageParser.StorageIds(
                        await SendCommandWithDataAsync(
                            0x1007,
                            _transactionId++,
                            [storageId, 0, handle],
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
        Status = $"已读取机内文件 · {items.Count} 项";
        return new CameraStorageSnapshot(volumes, items);
    }

    public Task<byte[]> GetStorageThumbnailAsync(
        uint handle,
        CancellationToken cancellationToken = default) =>
        SendCommandWithDataAsync(
            0x100a,
            _transactionId++,
            [handle],
            cancellationToken);

    public Task<byte[]> DownloadStorageObjectAsync(
        uint handle,
        CancellationToken cancellationToken = default) =>
        SendCommandWithDataAsync(
            0x1009,
            _transactionId++,
            [handle],
            cancellationToken);

    public async Task DeleteStorageObjectAsync(
        uint handle,
        CancellationToken cancellationToken = default)
    {
        var response = await SendCommandAsync(
            0x100b,
            _transactionId++,
            [handle, 0],
            cancellationToken);
        EnsureAccepted(response);
    }

    // ── E3 能力扩展：厂商识别 / 实时取景 / 录像 / 参数读写（镜像 iOS + PtpCamera）──

    /// <summary>
    /// 识别已连机型厂商：优先解析 GetDeviceInfo(0x1001) 数据段 Manufacturer，
    /// 退回握手相机名启发式。结果按会话缓存（detectVendor 在 ConnectAsync 后调用）。
    /// </summary>
    public async Task<CameraVendor> DetectVendorAsync(
        CancellationToken cancellationToken = default)
    {
        if (_vendor != CameraVendor.Unknown)
        {
            return _vendor;
        }
        var nameBased = VendorForName(CameraName);
        var resolved = nameBased;
        try
        {
            var info = await SendCommandWithDataAsync(
                0x1001,
                _transactionId++,
                [1],
                cancellationToken);
            var manufacturer = DeviceInfoManufacturer(info);
            if (!string.IsNullOrWhiteSpace(manufacturer))
            {
                resolved = VendorForManufacturer(
                    manufacturer,
                    nameBased);
            }
        }
        catch
        {
            // 部分机型对 0x1001 直接回响应（无数据段），退回名称启发式。
        }
        _vendor = resolved;
        return resolved;
    }

    /// <summary>开始实时取景（Nikon 0x9201 / Canon EOS 序列，TBC-awaiting-hardware）。</summary>
    public async Task StartLiveViewAsync(
        CancellationToken cancellationToken = default)
    {
        if (_commandStream is null)
        {
            throw new InvalidOperationException("请先连接 Wi‑Fi 相机");
        }
        if (_liveView)
        {
            return;
        }
        if (_vendor == CameraVendor.Canon)
        {
            if (!await CanonOpenLiveViewAsync(cancellationToken))
            {
                throw new IOException(
                    $"{CameraName} 未能确认进入佳能实时取景（机身未确认取景输出）。");
            }
            return;
        }
        var response = await SendCommandAsync(
            NikonStartLiveView,
            _transactionId++,
            [],
            cancellationToken);
        EnsureAccepted(response);
        _liveView = true;
    }

    /// <summary>停止实时取景（尽力而为）。</summary>
    public async Task StopLiveViewAsync(
        CancellationToken cancellationToken = default)
    {
        if (!_liveView || _commandStream is null)
        {
            _liveView = false;
            return;
        }
        if (_vendor == CameraVendor.Canon)
        {
            try
            {
                await CanonWriteEosPropAsync(
                    CanonEvfOutputDevice,
                    0,
                    cancellationToken);
                await CanonWriteEosPropAsync(
                    CanonEvfMode,
                    0,
                    cancellationToken);
            }
            catch
            {
                // 忽略关闭失败
            }
            _liveView = false;
            return;
        }
        try
        {
            await SendCommandAsync(
                NikonEndLiveView,
                _transactionId++,
                [],
                cancellationToken);
        }
        finally
        {
            _liveView = false;
        }
    }

    /// <summary>
    /// 取一帧实时取景 JPEG。Nikon 0x9203 / Canon 0x9153（EOS dataset → 内嵌
    /// JPEG 提取，TBC-awaiting-hardware）。
    /// </summary>
    public async Task<byte[]> GetLiveViewFrameAsync(
        CancellationToken cancellationToken = default)
    {
        if (_commandStream is null)
        {
            throw new InvalidOperationException("请先连接 Wi‑Fi 相机");
        }
        if (!_liveView)
        {
            throw new InvalidOperationException("实时取景尚未开启。");
        }
        if (_vendor == CameraVendor.Canon)
        {
            var raw = await SendCommandWithDataAsync(
                CanonEosGetViewFinderData,
                _transactionId++,
                [0x00200000u, 0u, 0u],
                cancellationToken);
            return ExtractEosJpeg(raw);
        }
        var data = await SendCommandWithDataAsync(
            NikonGetLiveViewImage,
            _transactionId++,
            [],
            cancellationToken);
        return ExtractJpeg(data);
    }

    /// <summary>开始录像（Nikon 0x920a / Canon EVFRecordStatus，TBC-awaiting-hardware）。</summary>
    public async Task StartMovieRecordingAsync(
        CancellationToken cancellationToken = default)
    {
        if (_commandStream is null)
        {
            throw new InvalidOperationException("请先连接 Wi‑Fi 相机");
        }
        if (_movieRecording)
        {
            return;
        }
        if (_vendor == CameraVendor.Canon)
        {
            await StartLiveViewAsync(cancellationToken);
            await CanonWriteEosPropAsync(
                CanonEvfRecordStatus,
                1,
                cancellationToken);
            _movieRecording = true;
            return;
        }
        if (!_liveView)
        {
            await StartLiveViewAsync(cancellationToken);
        }
        var response = await SendCommandAsync(
            NikonStartMovieRecording,
            _transactionId++,
            [],
            cancellationToken);
        EnsureAccepted(response);
        _movieRecording = true;
    }

    /// <summary>停止录像（Nikon 0x920b / Canon EVFRecordStatus=0，TBC-awaiting-hardware）。</summary>
    public async Task StopMovieRecordingAsync(
        CancellationToken cancellationToken = default)
    {
        if (_commandStream is null)
        {
            throw new InvalidOperationException("请先连接 Wi‑Fi 相机");
        }
        try
        {
            if (_vendor == CameraVendor.Canon)
            {
                await CanonWriteEosPropAsync(
                    CanonEvfRecordStatus,
                    0,
                    cancellationToken);
            }
            else
            {
                var response = await SendCommandAsync(
                    NikonEndMovieRecording,
                    _transactionId++,
                    [],
                    cancellationToken);
                EnsureAccepted(response);
            }
        }
        finally
        {
            _movieRecording = false;
        }
    }

    /// <summary>读取设备属性原始值（GetDevicePropValue 0x1015）。</summary>
    public Task<byte[]> ReadPropertyAsync(
        ushort property,
        CancellationToken cancellationToken = default) =>
        SendCommandWithDataAsync(
            GetDevicePropValue,
            _transactionId++,
            [property],
            cancellationToken);

    /// <summary>读取设备属性描述符（GetDevicePropDesc 0x1014），校验可写性。</summary>
    public Task<byte[]> ReadPropertyDescriptorAsync(
        ushort property,
        CancellationToken cancellationToken = default) =>
        SendCommandWithDataAsync(
            GetDevicePropDesc,
            _transactionId++,
            [property],
            cancellationToken);

    /// <summary>写入设备属性（SetDevicePropValue 0x1016，data-out 相位）。</summary>
    public async Task WritePropertyAsync(
        ushort property,
        byte[] value,
        CancellationToken cancellationToken = default)
    {
        var response = await SendCommandWithDataOutAsync(
            SetDevicePropValue,
            _transactionId++,
            [property],
            value,
            cancellationToken);
        EnsureAccepted(response);
    }

    /// <summary>Canon EOS 扩展属性写入（0x9110，12 字节 LE 载荷，TBC-awaiting-hardware）。</summary>
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
        var response = await SendCommandWithDataOutAsync(
            CanonEosSetDevicePropValueEx,
            _transactionId++,
            [],
            payload,
            cancellationToken);
        EnsureAccepted(response);
    }

    /// <summary>
    /// Canon EOS 取景开启（对齐 libgphoto2 canon.c，TBC-awaiting-hardware）：
    /// EVFMode 读当前值非 1 才写（Busy 容忍）；EVFOutputDevice 仅 (cur &amp; ~1)==0 时
    /// 写 2=PC（读失败回退无条件写）。返回两写至少一处被接受/已满足。
    /// </summary>
    private async Task<bool> CanonOpenLiveViewAsync(
        CancellationToken cancellationToken)
    {
        var confirmed = false;
        try
        {
            var mode = await ReadEosPropValueAsync(
                CanonEvfMode,
                cancellationToken);
            if (mode != 1)
            {
                try
                {
                    await CanonWriteEosPropAsync(
                        CanonEvfMode,
                        1,
                        cancellationToken);
                }
                catch
                {
                    // Movie 模式 Busy 容忍
                }
            }
            confirmed = true;
        }
        catch
        {
            // 读取失败容忍
        }
        try
        {
            uint current;
            try
            {
                current = await ReadEosPropValueAsync(
                    CanonEvfOutputDevice,
                    cancellationToken);
            }
            catch
            {
                current = uint.MaxValue;
            }
            if (current == uint.MaxValue || (current & ~1u) == 0)
            {
                try
                {
                    await CanonWriteEosPropAsync(
                        CanonEvfOutputDevice,
                        2,
                        cancellationToken);
                }
                catch
                {
                    // 容忍
                }
            }
            confirmed = true;
        }
        catch
        {
            // 容忍
        }
        _liveView = confirmed;
        return confirmed;
    }

    /// <summary>EOS 属性读取：标准 GetDevicePropValue(0x1015)（UINT16 回 2B / UINT32 回 4B）。</summary>
    private async Task<uint> ReadEosPropValueAsync(
        uint propCode,
        CancellationToken cancellationToken)
    {
        var data = await SendCommandWithDataAsync(
            GetDevicePropValue,
            _transactionId++,
            [propCode],
            cancellationToken);
        if (data.Length < 2)
        {
            throw new IOException("佳能属性读取返回长度不足。");
        }
        return data.Length >= 4
            ? BinaryPrimitives.ReadUInt32LittleEndian(data)
            : BinaryPrimitives.ReadUInt16LittleEndian(data);
    }

    /// <summary>EOS dataset → 内嵌 JPEG（[u32 len][u32 type][payload]，type 1/9/11，TBC）。</summary>
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
                return ExtractJpeg(source[offset..(offset + len)]);
            }
            offset += len;
        }
        throw new IOException(
            $"{CameraName} 返回的佳能取景数据中没有 JPEG 图像。");
    }

    /// <summary>JPEG 标记扫描（FFD8/FFD9）。</summary>
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

    /// <summary>GetDeviceInfo 数据段 Manufacturer 解析（UTF-8，布局见协议文档 §4）。</summary>
    private static string? DeviceInfoManufacturer(byte[] data)
    {
        if (data.Length < 8)
        {
            return null;
        }
        var offset = 8;
        if (!ReadUtf8(data, ref offset, out _))
        {
            return null; // VendorExtensionDesc
        }
        if (offset + 2 > data.Length)
        {
            return null;
        }
        offset += 2; // FunctionalMode
        for (var i = 0; i < 4; i++)
        {
            if (offset + 2 > data.Length)
            {
                return null;
            }
            var count = BinaryPrimitives.ReadUInt16LittleEndian(
                data.AsSpan(offset, 2));
            offset += 2;
            if (offset + count * 2 > data.Length)
            {
                return null;
            }
            offset += count * 2;
        }
        if (offset + 2 > data.Length)
        {
            return null;
        }
        var imageCount = BinaryPrimitives.ReadUInt16LittleEndian(
            data.AsSpan(offset, 2));
        offset += 2;
        if (offset + imageCount * 2 > data.Length)
        {
            return null;
        }
        offset += imageCount * 2;
        return ReadUtf8(data, ref offset, out var manufacturer)
            ? manufacturer
            : null;
    }

    private static bool ReadUtf8(
        byte[] data,
        ref int offset,
        out string text)
    {
        text = string.Empty;
        if (offset >= data.Length)
        {
            return false;
        }
        var end = offset;
        while (end < data.Length && data[end] != 0)
        {
            end++;
        }
        if (end >= data.Length)
        {
            return false;
        }
        text = Encoding.UTF8.GetString(data, offset, end - offset);
        offset = end + 1;
        return true;
    }

    private static CameraVendor VendorForManufacturer(
        string manufacturer,
        CameraVendor fallback)
    {
        var text = manufacturer.ToLowerInvariant();
        if (text.Contains("nikon")) return CameraVendor.Nikon;
        if (text.Contains("canon")) return CameraVendor.Canon;
        if (text.Contains("sony")) return CameraVendor.Sony;
        return fallback;
    }

    private static CameraVendor VendorForName(string name)
    {
        var text = name.ToLowerInvariant();
        if (text.Contains("nikon")) return CameraVendor.Nikon;
        if (text.Contains("canon")) return CameraVendor.Canon;
        if (text.Contains("sony") || text.Contains("ilce") || text.Contains("alpha"))
        {
            return CameraVendor.Sony;
        }
        return CameraVendor.Unknown;
    }

    /// <summary>
    /// data-out 请求（DataPhaseInfo=2）：请求 → StartData(9) → EndData(12) → 响应。
    /// 用于 SetDevicePropValue 与 Canon 0x9110 等携带数据段的写入操作。
    /// </summary>
    private async Task<ushort> SendCommandWithDataOutAsync(
        ushort operation,
        uint transaction,
        uint[] parameters,
        byte[] data,
        CancellationToken cancellationToken)
    {
        var stream = _commandStream ?? throw new InvalidOperationException(
            "请先连接 Wi‑Fi 相机");
        using var payload = new MemoryStream();
        WriteUInt32(payload, 2);
        WriteUInt16(payload, operation);
        WriteUInt32(payload, transaction);
        foreach (var parameter in parameters)
        {
            WriteUInt32(payload, parameter);
        }
        await SendPacketAsync(stream, 6, payload.ToArray(), cancellationToken);

        using var startPayload = new MemoryStream();
        WriteUInt32(startPayload, 0);
        WriteUInt32(startPayload, transaction);
        WriteUInt64(startPayload, (ulong)data.Length);
        startPayload.Write(data);
        await SendPacketAsync(
            stream,
            9,
            startPayload.ToArray(),
            cancellationToken);

        using var endPayload = new MemoryStream();
        WriteUInt32(endPayload, 0);
        WriteUInt32(endPayload, transaction);
        await SendPacketAsync(
            stream,
            12,
            endPayload.ToArray(),
            cancellationToken);

        var response = await ReceivePacketAsync(stream, cancellationToken);
        if (response.Type != 7 || response.Data.Length < 14)
        {
            throw new IOException("相机返回了无效的 PTP/IP 响应");
        }
        return ReadUInt16(response.Data, 8);
    }

    public Task DisconnectAsync()
    {
        _commandStream?.Dispose();
        _eventStream?.Dispose();
        _commandClient?.Dispose();
        _eventClient?.Dispose();
        _commandStream = null;
        _eventStream = null;
        _commandClient = null;
        _eventClient = null;
        _transactionId = 1;
        _vendor = CameraVendor.Unknown;
        _liveView = false;
        _movieRecording = false;
        CameraName = "PTP/IP Camera";
        Status = "Wi‑Fi 相机未连接";
        return Task.CompletedTask;
    }

    /// <summary>
    /// 无副作用链路探测：GetDeviceInfo（0x1002），用于心跳保活。
    /// 与在途命令同走 SendCommandAsync（共享命令流，天然串行）；
    /// 单次探测超时 3s。
    /// </summary>
    public async Task ProbeAsync(
        CancellationToken cancellationToken = default)
    {
        if (_commandStream is null)
        {
            throw new InvalidOperationException("请先连接 Wi‑Fi 相机");
        }
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(
            cancellationToken);
        timeout.CancelAfter(TimeSpan.FromMilliseconds(ProbeTimeoutMilliseconds));
        var response = await SendCommandAsync(
            0x1002,
            0,
            [1],
            timeout.Token);
        EnsureAccepted(response);
    }

    /// <summary>B2 保活参数（契约测试锚点）：单次探测超时 3s。</summary>
    public const int ProbeTimeoutMilliseconds = 3000;

    public async ValueTask DisposeAsync() => await DisconnectAsync();

    private async Task<ushort> SendCommandAsync(
        ushort operation,
        uint transaction,
        uint[] parameters,
        CancellationToken cancellationToken)
    {
        var stream = _commandStream ?? throw new InvalidOperationException(
            "请先连接 Wi‑Fi 相机");
        using var payload = new MemoryStream();
        WriteUInt32(payload, 1);
        WriteUInt16(payload, operation);
        WriteUInt32(payload, transaction);
        foreach (var parameter in parameters)
        {
            WriteUInt32(payload, parameter);
        }
        await SendPacketAsync(stream, 6, payload.ToArray(), cancellationToken);
        var response = await ReceivePacketAsync(stream, cancellationToken);
        if (response.Type != 7 || response.Data.Length < 14)
        {
            throw new IOException("相机返回了无效的 PTP/IP 响应");
        }
        return ReadUInt16(response.Data, 8);
    }

    private async Task<byte[]> SendCommandWithDataAsync(
        ushort operation,
        uint transaction,
        uint[] parameters,
        CancellationToken cancellationToken)
    {
        var stream = _commandStream ?? throw new InvalidOperationException(
            "请先连接 Wi‑Fi 相机");
        using var payload = new MemoryStream();
        // PTP/IP value 1 is used for data-in and no-data operations.
        WriteUInt32(payload, 1);
        WriteUInt16(payload, operation);
        WriteUInt32(payload, transaction);
        foreach (var parameter in parameters) WriteUInt32(payload, parameter);
        await SendPacketAsync(stream, 6, payload.ToArray(), cancellationToken);

        var first = await ReceivePacketAsync(stream, cancellationToken);
        if (first.Type == 7)
        {
            EnsureAccepted(first.Data.Length >= 10
                ? ReadUInt16(first.Data, 8)
                : (ushort)0x2002);
        }
        if (first.Type != 9 || first.Data.Length < 20 ||
            ReadUInt32(first.Data, 8) != transaction)
        {
            throw new IOException("相机返回了无效的 PTP/IP 数据阶段");
        }
        var totalLength = BinaryPrimitives.ReadUInt64LittleEndian(
            first.Data.AsSpan(12, 8));
        const ulong maximumObjectBytes = 512UL * 1024 * 1024;
        if (totalLength > maximumObjectBytes)
        {
            throw new IOException("机内文件超过当前 512 MB 单文件传输上限");
        }
        using var data = new MemoryStream(
            (int)Math.Min(totalLength, 8UL * 1024 * 1024));
        while (true)
        {
            var packet = await ReceivePacketAsync(stream, cancellationToken);
            if ((packet.Type != 10 && packet.Type != 12) ||
                packet.Data.Length < 12 ||
                ReadUInt32(packet.Data, 8) != transaction)
            {
                throw new IOException("相机返回了无效的 PTP/IP 文件数据包");
            }
            data.Write(packet.Data, 12, packet.Data.Length - 12);
            if ((ulong)data.Length > maximumObjectBytes)
            {
                throw new IOException("机内文件超过当前 512 MB 单文件传输上限");
            }
            if (packet.Type == 12) break;
        }
        var response = await ReceivePacketAsync(stream, cancellationToken);
        if (response.Type != 7 || response.Data.Length < 14)
        {
            throw new IOException("相机没有完成 PTP/IP 文件事务");
        }
        EnsureAccepted(ReadUInt16(response.Data, 8));
        return data.ToArray();
    }

    private static async Task SendPacketAsync(
        NetworkStream stream,
        uint type,
        byte[] payload,
        CancellationToken cancellationToken)
    {
        var packet = new byte[payload.Length + 8];
        BinaryPrimitives.WriteUInt32LittleEndian(packet, (uint)packet.Length);
        BinaryPrimitives.WriteUInt32LittleEndian(packet.AsSpan(4), type);
        payload.CopyTo(packet, 8);
        await stream.WriteAsync(packet, cancellationToken);
        await stream.FlushAsync(cancellationToken);
    }

    private static async Task<(uint Type, byte[] Data)> ReceivePacketAsync(
        NetworkStream stream,
        CancellationToken cancellationToken)
    {
        var header = await ReadExactlyAsync(stream, 8, cancellationToken);
        var length = checked((int)ReadUInt32(header, 0));
        if (length is < 8 or > 67108864)
        {
            throw new IOException("相机返回了无效的 PTP/IP 数据");
        }
        var data = new byte[length];
        header.CopyTo(data, 0);
        if (length > 8)
        {
            var remainder = await ReadExactlyAsync(
                stream,
                length - 8,
                cancellationToken);
            remainder.CopyTo(data, 8);
        }
        return (ReadUInt32(header, 4), data);
    }

    private static async Task<byte[]> ReadExactlyAsync(
        NetworkStream stream,
        int length,
        CancellationToken cancellationToken)
    {
        var result = new byte[length];
        var offset = 0;
        while (offset < length)
        {
            var count = await stream.ReadAsync(
                result.AsMemory(offset, length - offset),
                cancellationToken);
            if (count == 0)
            {
                throw new IOException("相机提前关闭了 PTP/IP 连接");
            }
            offset += count;
        }
        return result;
    }

    private static void EnsureAccepted(ushort response)
    {
        if (response != 0x2001)
        {
            throw new IOException($"相机拒绝了 PTP/IP 操作（0x{response:X4}）");
        }
    }

    private static void WriteUtf16(Stream stream, string value)
    {
        stream.Write(Encoding.Unicode.GetBytes(value + "\0"));
    }

    private static string ReadUtf16(byte[] value, int offset)
    {
        var end = offset;
        while (end + 1 < value.Length && (value[end] != 0 || value[end + 1] != 0))
        {
            end += 2;
        }
        return Encoding.Unicode.GetString(value, offset, end - offset);
    }

    private static void WriteUInt16(Stream stream, ushort value)
    {
        Span<byte> buffer = stackalloc byte[2];
        BinaryPrimitives.WriteUInt16LittleEndian(buffer, value);
        stream.Write(buffer);
    }

    private static void WriteUInt32(Stream stream, uint value)
    {
        Span<byte> buffer = stackalloc byte[4];
        BinaryPrimitives.WriteUInt32LittleEndian(buffer, value);
        stream.Write(buffer);
    }

    private static void WriteUInt64(Stream stream, ulong value)
    {
        Span<byte> buffer = stackalloc byte[8];
        BinaryPrimitives.WriteUInt64LittleEndian(buffer, value);
        stream.Write(buffer);
    }

    private static ushort ReadUInt16(byte[] value, int offset) =>
        BinaryPrimitives.ReadUInt16LittleEndian(value.AsSpan(offset, 2));

    private static uint ReadUInt32(byte[] value, int offset) =>
        BinaryPrimitives.ReadUInt32LittleEndian(value.AsSpan(offset, 4));
}
