using System.Buffers.Binary;
using System.IO;
using System.Net.Sockets;
using System.Text;
using NikonLink.Windows.Models;

namespace NikonLink.Windows.Services;

public sealed class PtpIpCamera : IAsyncDisposable
{
    private sealed class PtpResponseException(
        ushort responseCode,
        string message) : Exception(message)
    {
        public ushort ResponseCode { get; } = responseCode;
    }

    private readonly record struct CommandSession(
        NetworkStream Stream,
        long Generation);

    public readonly record struct ConnectionResult(
        string CameraName,
        long SessionGeneration);

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
    private readonly SemaphoreSlim _commandGate = new(1, 1);
    private readonly SemaphoreSlim _eventWriteGate = new(1, 1);
    private readonly SemaphoreSlim _probeGate = new(1, 1);
    private readonly object _sessionSync = new();
    private readonly object _probeSync = new();
    private CancellationTokenSource? _eventReaderCancellation;
    private Task? _eventReaderTask;
    private TaskCompletionSource<long>? _probeResponseWaiter;
    private Exception? _eventReaderFailure;
    private Exception? _commandChannelFailure;
    private long _probeResponseSequence;
    private long _connectionAttemptGeneration;
    private long _sessionGeneration;
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
        var connection = await ConnectWithOwnershipAsync(
            host,
            port,
            cancellationToken);
        return connection.CameraName;
    }

    public async Task<ConnectionResult> ConnectWithOwnershipAsync(
        string host,
        int port = 15740,
        CancellationToken cancellationToken = default)
    {
        var connectionAttempt = ClaimConnectionAttempt();
        var connectionAttemptGeneration = connectionAttempt.Generation;
        await DisconnectSessionAsync(
            connectionAttempt.SessionGeneration);
        var sessionGeneration = CaptureSessionGeneration(
            connectionAttemptGeneration);
        if (string.IsNullOrWhiteSpace(host) || port is < 1 or > 65535)
        {
            throw new ArgumentException("Wi‑Fi 相机地址或端口无效");
        }

        Status = "正在连接 Wi‑Fi 相机…";
        TcpClient? commandClient = null;
        TcpClient? eventClient = null;
        NetworkStream? commandStream = null;
        NetworkStream? eventStream = null;
        try
        {
            commandClient = CreateTcpClient();
            lock (_sessionSync)
            {
                EnsureConnectionCurrent(
                    connectionAttemptGeneration,
                    sessionGeneration);
                _commandClient = commandClient;
            }
            await commandClient.ConnectAsync(host.Trim(), port, cancellationToken);
            EnsureConnectionCurrent(
                connectionAttemptGeneration,
                sessionGeneration);
            commandStream = commandClient.GetStream();
            lock (_sessionSync)
            {
                EnsureConnectionCurrent(
                    connectionAttemptGeneration,
                    sessionGeneration);
                _commandStream = commandStream;
            }

            using var commandPayload = new MemoryStream();
            commandPayload.Write(Guid.NewGuid().ToByteArray());
            WriteUtf16(commandPayload, "ZENCHE Windows");
            WriteUInt32(commandPayload, 0x00010000);
            await SendPacketAsync(
                commandStream,
                1,
                commandPayload.ToArray(),
                cancellationToken);
            var acknowledgment = await ReceivePacketAsync(
                commandStream,
                cancellationToken);
            EnsureConnectionCurrent(
                connectionAttemptGeneration,
                sessionGeneration);
            if (acknowledgment.Type != 2 || acknowledgment.Data.Length < 28)
            {
                throw new IOException("相机返回了无效的 PTP/IP 握手数据");
            }
            var connectionNumber = ReadUInt32(acknowledgment.Data, 8);
            var cameraName = ReadUtf16(acknowledgment.Data, 28);
            if (string.IsNullOrWhiteSpace(cameraName))
            {
                cameraName = "PTP/IP Camera";
            }

            eventClient = CreateTcpClient();
            lock (_sessionSync)
            {
                EnsureConnectionCurrent(
                    connectionAttemptGeneration,
                    sessionGeneration);
                _eventClient = eventClient;
            }
            await eventClient.ConnectAsync(host.Trim(), port, cancellationToken);
            EnsureConnectionCurrent(
                connectionAttemptGeneration,
                sessionGeneration);
            eventStream = eventClient.GetStream();
            lock (_sessionSync)
            {
                EnsureConnectionCurrent(
                    connectionAttemptGeneration,
                    sessionGeneration);
                _eventStream = eventStream;
            }
            var eventPayload = new byte[4];
            BinaryPrimitives.WriteUInt32LittleEndian(eventPayload, connectionNumber);
            await SendPacketAsync(
                eventStream,
                3,
                eventPayload,
                cancellationToken);
            var eventAcknowledgment = await ReceivePacketAsync(
                eventStream,
                cancellationToken);
            EnsureConnectionCurrent(
                connectionAttemptGeneration,
                sessionGeneration);
            if (eventAcknowledgment.Type != 4)
            {
                throw new IOException("相机未确认 PTP/IP 事件通道");
            }
            StartEventReader(eventStream, sessionGeneration);

            var response = await SendCommandAsync(
                0x1002,
                static () => 0,
                [1],
                cancellationToken);
            EnsureAccepted(response);
            EnsureConnectionCurrent(
                connectionAttemptGeneration,
                sessionGeneration);
            lock (_sessionSync)
            {
                EnsureConnectionCurrent(
                    connectionAttemptGeneration,
                    sessionGeneration);
                _transactionId = 1;
                CameraName = cameraName;
                Status = $"Wi‑Fi 已连接 · {CameraName}";
                return new ConnectionResult(
                    CameraName,
                    sessionGeneration);
            }
        }
        catch
        {
            commandStream?.Dispose();
            eventStream?.Dispose();
            commandClient?.Dispose();
            eventClient?.Dispose();
            await DisconnectSessionAsync(sessionGeneration);
            throw;
        }
    }

    private (long Generation, long SessionGeneration) ClaimConnectionAttempt()
    {
        lock (_sessionSync)
        {
            var generation = Interlocked.Increment(
                ref _connectionAttemptGeneration);
            return (
                generation,
                Volatile.Read(ref _sessionGeneration));
        }
    }

    private long CaptureSessionGeneration(long connectionAttemptGeneration)
    {
        lock (_sessionSync)
        {
            EnsureConnectionAttemptCurrent(connectionAttemptGeneration);
            return Volatile.Read(ref _sessionGeneration);
        }
    }

    private void EnsureConnectionCurrent(
        long connectionAttemptGeneration,
        long sessionGeneration)
    {
        EnsureConnectionAttemptCurrent(connectionAttemptGeneration);
        EnsureSessionCurrent(sessionGeneration);
    }

    private void EnsureConnectionAttemptCurrent(long expectedGeneration)
    {
        if (Volatile.Read(ref _connectionAttemptGeneration) !=
            expectedGeneration)
        {
            throw new OperationCanceledException(
                "PTP/IP 连接尝试已被取消或由新尝试取代");
        }
    }

    private void EnsureSessionCurrent(long expectedGeneration)
    {
        if (Volatile.Read(ref _sessionGeneration) != expectedGeneration)
        {
            throw new OperationCanceledException(
                "PTP/IP 连接已被断开或由新会话取代");
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
            () => _transactionId++,
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
                () => _transactionId++,
                [],
                cancellationToken));
        foreach (var storageId in storageIds)
        {
            volumes.Add(CameraStorageParser.StorageInfo(
                storageId,
                await SendCommandWithDataAsync(
                    0x1005,
                    () => _transactionId++,
                    [storageId],
                    cancellationToken)));
            var pendingHandles = new Queue<uint>(CameraStorageParser.StorageIds(
                await SendCommandWithDataAsync(
                    0x1007,
                    () => _transactionId++,
                    [storageId, 0, uint.MaxValue],
                    cancellationToken)));
            var visitedHandles = new HashSet<uint>();
            while (pendingHandles.TryDequeue(out var handle))
            {
                if (!visitedHandles.Add(handle)) continue;
                var objectInfo = await SendCommandWithDataAsync(
                    0x1008,
                    () => _transactionId++,
                    [handle],
                    cancellationToken);
                if (CameraStorageParser.IsAssociation(objectInfo))
                {
                    var children = CameraStorageParser.StorageIds(
                        await SendCommandWithDataAsync(
                            0x1007,
                            () => _transactionId++,
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
            () => _transactionId++,
            [handle],
            cancellationToken);

    public Task<byte[]> DownloadStorageObjectAsync(
        uint handle,
        CancellationToken cancellationToken = default) =>
        SendCommandWithDataAsync(
            0x1009,
            () => _transactionId++,
            [handle],
            cancellationToken);

    public async Task DeleteStorageObjectAsync(
        uint handle,
        CancellationToken cancellationToken = default)
    {
        var response = await SendCommandAsync(
            0x100b,
            () => _transactionId++,
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
        var session = CaptureCommandSession();
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
                () => _transactionId++,
                [],
                cancellationToken,
                session);
            var manufacturer = DeviceInfoManufacturer(info);
            if (!string.IsNullOrWhiteSpace(manufacturer))
            {
                resolved = VendorForManufacturer(
                    manufacturer,
                    nameBased);
            }
        }
        catch (PtpResponseException error) when (
            IsVendorDetectionFallback(error.ResponseCode))
        {
            // 部分机型拒绝 0x1001，退回握手名称启发式。传输与取消错误必须上抛。
        }
        CommitSessionState(session, () => _vendor = resolved);
        return resolved;
    }

    /// <summary>开始实时取景（Nikon 0x9201 / Canon EOS 序列，TBC-awaiting-hardware）。</summary>
    public async Task StartLiveViewAsync(
        CancellationToken cancellationToken = default)
    {
        var session = CaptureCommandSession();
        await StartLiveViewAsync(session, cancellationToken);
    }

    private async Task StartLiveViewAsync(
        CommandSession session,
        CancellationToken cancellationToken)
    {
        EnsureCommandSession(session.Stream, session.Generation);
        if (_liveView)
        {
            return;
        }
        if (_vendor == CameraVendor.Canon)
        {
            if (!await CanonOpenLiveViewAsync(session, cancellationToken))
            {
                throw new IOException(
                    $"{CameraName} 未能确认进入佳能实时取景（机身未确认取景输出）。");
            }
            CommitSessionState(session, () => _liveView = true);
            return;
        }
        var response = await SendCommandAsync(
            NikonStartLiveView,
            () => _transactionId++,
            [],
            cancellationToken,
            session);
        EnsureAccepted(response);
        CommitSessionState(session, () => _liveView = true);
    }

    /// <summary>停止实时取景（尽力而为）。</summary>
    public async Task StopLiveViewAsync(
        CancellationToken cancellationToken = default)
    {
        if (_commandStream is null)
        {
            _liveView = false;
            return;
        }
        var session = CaptureCommandSession();
        if (!_liveView)
        {
            return;
        }
        try
        {
            if (_vendor == CameraVendor.Canon)
            {
                try
                {
                    await CanonWriteEosPropAsync(
                        CanonEvfOutputDevice,
                        0,
                        cancellationToken,
                        session);
                    await CanonWriteEosPropAsync(
                        CanonEvfMode,
                        0,
                        cancellationToken,
                        session);
                }
                catch (PtpResponseException error) when (
                    !IsSessionFatalResponse(error.ResponseCode))
                {
                    // 关闭取景尽力而为；传输与取消错误仍上抛。
                }
            }
            else
            {
                await SendCommandAsync(
                    NikonEndLiveView,
                    () => _transactionId++,
                    [],
                    cancellationToken,
                    session);
            }
        }
        finally
        {
            TryCommitSessionState(session, () => _liveView = false);
        }
    }

    /// <summary>
    /// 取一帧实时取景 JPEG。Nikon 0x9203 / Canon 0x9153（EOS dataset → 内嵌
    /// JPEG 提取，TBC-awaiting-hardware）。
    /// </summary>
    public async Task<byte[]> GetLiveViewFrameAsync(
        CancellationToken cancellationToken = default)
    {
        var session = CaptureCommandSession();
        if (!_liveView)
        {
            throw new InvalidOperationException("实时取景尚未开启。");
        }
        if (_vendor == CameraVendor.Canon)
        {
            var raw = await SendCommandWithDataAsync(
                CanonEosGetViewFinderData,
                () => _transactionId++,
                [0x00200000u, 0u, 0u],
                cancellationToken,
                session);
            return ExtractEosJpeg(raw);
        }
        var data = await SendCommandWithDataAsync(
            NikonGetLiveViewImage,
            () => _transactionId++,
            [],
            cancellationToken,
            session);
        return ExtractJpeg(data);
    }

    /// <summary>开始录像（Nikon 0x920a / Canon EVFRecordStatus，TBC-awaiting-hardware）。</summary>
    public async Task StartMovieRecordingAsync(
        CancellationToken cancellationToken = default)
    {
        var session = CaptureCommandSession();
        if (_movieRecording)
        {
            return;
        }
        if (_vendor == CameraVendor.Canon)
        {
            await StartLiveViewAsync(session, cancellationToken);
            await CanonWriteEosPropAsync(
                CanonEvfRecordStatus,
                1,
                cancellationToken,
                session);
            CommitSessionState(session, () => _movieRecording = true);
            return;
        }
        if (!_liveView)
        {
            await StartLiveViewAsync(session, cancellationToken);
        }
        var response = await SendCommandAsync(
            NikonStartMovieRecording,
            () => _transactionId++,
            [],
            cancellationToken,
            session);
        EnsureAccepted(response);
        CommitSessionState(session, () => _movieRecording = true);
    }

    /// <summary>停止录像（Nikon 0x920b / Canon EVFRecordStatus=0，TBC-awaiting-hardware）。</summary>
    public async Task StopMovieRecordingAsync(
        CancellationToken cancellationToken = default)
    {
        var session = CaptureCommandSession();
        try
        {
            if (_vendor == CameraVendor.Canon)
            {
                await CanonWriteEosPropAsync(
                    CanonEvfRecordStatus,
                    0,
                    cancellationToken,
                    session);
            }
            else
            {
                var response = await SendCommandAsync(
                    NikonEndMovieRecording,
                    () => _transactionId++,
                    [],
                    cancellationToken,
                    session);
                EnsureAccepted(response);
            }
        }
        finally
        {
            TryCommitSessionState(session, () => _movieRecording = false);
        }
    }

    /// <summary>读取设备属性原始值（GetDevicePropValue 0x1015）。</summary>
    public Task<byte[]> ReadPropertyAsync(
        ushort property,
        CancellationToken cancellationToken = default) =>
        SendCommandWithDataAsync(
            GetDevicePropValue,
            () => _transactionId++,
            [property],
            cancellationToken);

    /// <summary>读取设备属性描述符（GetDevicePropDesc 0x1014），校验可写性。</summary>
    public Task<byte[]> ReadPropertyDescriptorAsync(
        ushort property,
        CancellationToken cancellationToken = default) =>
        SendCommandWithDataAsync(
            GetDevicePropDesc,
            () => _transactionId++,
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
            () => _transactionId++,
            [property],
            value,
            cancellationToken);
        EnsureAccepted(response);
    }

    /// <summary>Canon EOS 扩展属性写入（0x9110，12 字节 LE 载荷，TBC-awaiting-hardware）。</summary>
    private async Task CanonWriteEosPropAsync(
        uint propCode,
        uint value,
        CancellationToken cancellationToken,
        CommandSession? expectedSession = null)
    {
        var payload = new byte[12];
        BinaryPrimitives.WriteUInt32LittleEndian(payload.AsSpan(0, 4), 12);
        BinaryPrimitives.WriteUInt32LittleEndian(
            payload.AsSpan(4, 4), propCode);
        BinaryPrimitives.WriteUInt32LittleEndian(
            payload.AsSpan(8, 4), value);
        var response = await SendCommandWithDataOutAsync(
            CanonEosSetDevicePropValueEx,
            () => _transactionId++,
            [],
            payload,
            cancellationToken,
            expectedSession);
        EnsureAccepted(response);
    }

    /// <summary>
    /// Canon EOS 取景开启（对齐 libgphoto2 canon.c，TBC-awaiting-hardware）：
    /// EVFMode 读当前值非 1 才写（Busy 容忍）；EVFOutputDevice 仅 (cur &amp; ~1)==0 时
    /// 写 2=PC（读失败回退无条件写）。返回两写至少一处被接受/已满足。
    /// </summary>
    private async Task<bool> CanonOpenLiveViewAsync(
        CommandSession session,
        CancellationToken cancellationToken)
    {
        var confirmed = false;
        try
        {
            var mode = await ReadEosPropValueAsync(
                CanonEvfMode,
                cancellationToken,
                session);
            if (mode != 1)
            {
                try
                {
                    await CanonWriteEosPropAsync(
                        CanonEvfMode,
                        1,
                        cancellationToken,
                        session);
                }
                catch (PtpResponseException error) when (
                    !IsSessionFatalResponse(error.ResponseCode))
                {
                    // Movie 模式 Busy 容忍
                }
            }
            confirmed = true;
        }
        catch (PtpResponseException error) when (
            !IsSessionFatalResponse(error.ResponseCode))
        {
            // 相机拒绝读取时容忍；传输与取消错误必须上抛。
        }
        try
        {
            uint current;
            try
            {
                current = await ReadEosPropValueAsync(
                    CanonEvfOutputDevice,
                    cancellationToken,
                    session);
            }
            catch (PtpResponseException error) when (
                !IsSessionFatalResponse(error.ResponseCode))
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
                        cancellationToken,
                        session);
                }
                catch (PtpResponseException error) when (
                    !IsSessionFatalResponse(error.ResponseCode))
                {
                    // 容忍
                }
            }
            confirmed = true;
        }
        catch (PtpResponseException error) when (
            !IsSessionFatalResponse(error.ResponseCode))
        {
            // 容忍
        }
        return confirmed;
    }

    /// <summary>EOS 属性读取：标准 GetDevicePropValue(0x1015)（UINT16 回 2B / UINT32 回 4B）。</summary>
    private async Task<uint> ReadEosPropValueAsync(
        uint propCode,
        CancellationToken cancellationToken,
        CommandSession? expectedSession = null)
    {
        var data = await SendCommandWithDataAsync(
            GetDevicePropValue,
            () => _transactionId++,
            [propCode],
            cancellationToken,
            expectedSession);
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

    /// <summary>
    /// GetDeviceInfo 数据段 Manufacturer 解析：PIMA 15740 的字符串是
    /// 字符数前缀（含终止符）+ UTF-16LE，五个能力表是 AUINT16（u32 数量）。
    /// </summary>
    private static string? DeviceInfoManufacturer(byte[] data)
    {
        if (data.Length < 8)
        {
            return null;
        }
        var offset = 8;
        if (!ReadPtpString(data, ref offset, out _))
        {
            return null; // VendorExtensionDesc
        }
        if (offset + 2 > data.Length)
        {
            return null;
        }
        offset += 2; // FunctionalMode
        for (var i = 0; i < 5; i++)
        {
            if (!SkipAUInt16(data, ref offset))
            {
                return null;
            }
        }
        return ReadPtpString(data, ref offset, out var manufacturer)
            ? manufacturer
            : null;
    }

    private static bool SkipAUInt16(byte[] data, ref int offset)
    {
        if (offset < 0 || data.Length - offset < 4)
        {
            return false;
        }
        var count = ReadUInt32(data, offset);
        offset += 4;
        var remaining = data.Length - offset;
        if (count > (uint)(remaining / 2))
        {
            return false;
        }
        offset += checked((int)count * 2);
        return true;
    }

    private static bool ReadPtpString(
        byte[] data,
        ref int offset,
        out string text)
    {
        text = string.Empty;
        if (offset >= data.Length)
        {
            return false;
        }
        var characterCount = data[offset++];
        if (characterCount == 0)
        {
            return true;
        }
        var byteCount = checked(characterCount * 2);
        if (data.Length - offset < byteCount)
        {
            return false;
        }
        if (data[offset + byteCount - 2] != 0 ||
            data[offset + byteCount - 1] != 0)
        {
            return false;
        }
        var textByteCount = Math.Max(0, byteCount - 2);
        text = Encoding.Unicode.GetString(data, offset, textByteCount);
        offset += byteCount;
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
        Func<uint> transactionFactory,
        uint[] parameters,
        byte[] data,
        CancellationToken cancellationToken,
        CommandSession? expectedSession = null)
    {
        var stream = _commandStream;
        var sessionGeneration = Volatile.Read(ref _sessionGeneration);
        if (expectedSession is { } expected)
        {
            stream = expected.Stream;
            sessionGeneration = expected.Generation;
        }
        if (stream is null)
        {
            throw new InvalidOperationException("请先连接 Wi‑Fi 相机");
        }
        using var deadline = CreateCommandDeadline(cancellationToken);
        var token = deadline.Token;
        await _commandGate.WaitAsync(token);
        var transactionStarted = false;
        try
        {
            EnsureCommandSession(stream, sessionGeneration);
            var transaction = transactionFactory();
            using var payload = new MemoryStream();
            WriteUInt32(payload, 2);
            WriteUInt16(payload, operation);
            WriteUInt32(payload, transaction);
            foreach (var parameter in parameters)
            {
                WriteUInt32(payload, parameter);
            }
            transactionStarted = true;
            await SendPacketAsync(stream, 6, payload.ToArray(), token);
            ResetCommandDeadline(deadline);
            EnsureCommandSession(stream, sessionGeneration);

            using var startPayload = new MemoryStream();
            WriteUInt32(startPayload, transaction);
            WriteUInt64(startPayload, (ulong)data.Length);
            await SendPacketAsync(
                stream,
                9,
                startPayload.ToArray(),
                token);
            ResetCommandDeadline(deadline);
            EnsureCommandSession(stream, sessionGeneration);

            using var endPayload = new MemoryStream();
            WriteUInt32(endPayload, transaction);
            endPayload.Write(data);
            await SendPacketAsync(
                stream,
                12,
                endPayload.ToArray(),
                token);
            ResetCommandDeadline(deadline);
            EnsureCommandSession(stream, sessionGeneration);

            var response = await ReceivePacketAsync(stream, token);
            ResetCommandDeadline(deadline);
            EnsureCommandSession(stream, sessionGeneration);
            if (response.Type != 7 || response.Data.Length < 14 ||
                ReadUInt32(response.Data, 10) != transaction)
            {
                throw new IOException("相机返回了无效的 PTP/IP 响应");
            }
            var responseCode = ReadUInt16(response.Data, 8);
            RetireIfSessionFatal(
                responseCode,
                stream,
                sessionGeneration);
            return responseCode;
        }
        catch (IOException error)
        {
            RetireCommandSession(stream, sessionGeneration, error);
            throw;
        }
        catch (OperationCanceledException error) when (transactionStarted)
        {
            if (cancellationToken.IsCancellationRequested)
            {
                RetireCommandSession(stream, sessionGeneration, error);
                throw;
            }
            var timeout = new TimeoutException(
                "PTP/IP 命令事务超时",
                error);
            RetireCommandSession(stream, sessionGeneration, timeout);
            throw timeout;
        }
        catch (OperationCanceledException error)
            when (!cancellationToken.IsCancellationRequested)
        {
            // 内部 deadline 在事务开始前到期（例如等待命令 gate 超时）：
            // 尚未发送任何字节，无需退休；但要与用户取消区分开。
            throw new TimeoutException("PTP/IP 命令事务超时", error);
        }
        finally
        {
            _commandGate.Release();
        }
    }

    private void StartEventReader(
        NetworkStream stream,
        long sessionGeneration)
    {
        lock (_sessionSync)
        {
            EnsureSessionCurrent(sessionGeneration);
            if (!ReferenceEquals(_eventStream, stream))
            {
                throw new OperationCanceledException(
                    "PTP/IP 事件通道已被新会话取代");
            }
            _eventReaderCancellation?.Cancel();
            _eventReaderCancellation?.Dispose();
            _eventReaderCancellation = new CancellationTokenSource();
            lock (_probeSync)
            {
                _eventReaderFailure = null;
            }
            Interlocked.Exchange(ref _probeResponseSequence, 0);
            _eventReaderTask = RunEventReaderAsync(
                stream,
                sessionGeneration,
                _eventReaderCancellation.Token);
        }
    }

    private async Task RunEventReaderAsync(
        NetworkStream stream,
        long sessionGeneration,
        CancellationToken cancellationToken)
    {
        try
        {
            while (!cancellationToken.IsCancellationRequested)
            {
                var packet = await ReceivePacketAsync(stream, cancellationToken);
                switch (packet.Type)
                {
                    case 8:
                        // Event packet: the UI currently has no event consumers, but the
                        // channel must be drained so probes and camera notifications cannot
                        // block one another.
                        break;
                    case 13:
                        // Cameras may probe either side of the event channel.
                        await SendEventPacketAsync(
                            14,
                            [],
                            stream,
                            sessionGeneration,
                            cancellationToken);
                        break;
                    case 14:
                    {
                        var sequence = Interlocked.Increment(
                            ref _probeResponseSequence);
                        lock (_probeSync)
                        {
                            _probeResponseWaiter?.TrySetResult(sequence);
                        }
                        break;
                    }
                }
            }
        }
        catch (Exception) when (cancellationToken.IsCancellationRequested)
        {
            // Expected when disconnect closes the event socket.
        }
        catch (Exception error)
        {
            if (!ReferenceEquals(_eventStream, stream) ||
                Volatile.Read(ref _sessionGeneration) != sessionGeneration)
            {
                return;
            }
            var failure = new IOException("PTP/IP 事件通道已断开", error);
            lock (_probeSync)
            {
                _eventReaderFailure = failure;
                _probeResponseWaiter?.TrySetException(failure);
            }
        }
    }

    private async Task SendEventPacketAsync(
        uint type,
        byte[] payload,
        CancellationToken cancellationToken)
    {
        var stream = _eventStream ?? throw new InvalidOperationException(
            "PTP/IP 事件通道尚未建立");
        var sessionGeneration = Volatile.Read(ref _sessionGeneration);
        await SendEventPacketAsync(
            type,
            payload,
            stream,
            sessionGeneration,
            cancellationToken);
    }

    private async Task SendEventPacketAsync(
        uint type,
        byte[] payload,
        NetworkStream expectedStream,
        long expectedGeneration,
        CancellationToken cancellationToken)
    {
        await _eventWriteGate.WaitAsync(cancellationToken);
        try
        {
            if (!ReferenceEquals(_eventStream, expectedStream) ||
                Volatile.Read(ref _sessionGeneration) != expectedGeneration)
            {
                throw new OperationCanceledException(
                    "PTP/IP 事件通道已被断开或由新会话取代");
            }
            await SendPacketAsync(
                expectedStream,
                type,
                payload,
                cancellationToken);
            if (!ReferenceEquals(_eventStream, expectedStream) ||
                Volatile.Read(ref _sessionGeneration) != expectedGeneration)
            {
                throw new OperationCanceledException(
                    "PTP/IP 事件通道已被断开或由新会话取代");
            }
        }
        finally
        {
            _eventWriteGate.Release();
        }
    }

    public async Task DisconnectAsync()
    {
        var disconnectAttempt = ClaimConnectionAttempt();
        await DisconnectSessionAsync(
            disconnectAttempt.SessionGeneration);
    }

    public async Task DisconnectIfOwnedAsync(long expectedGeneration)
    {
        await DisconnectSessionAsync(expectedGeneration);
    }

    private async Task DisconnectSessionAsync(long expectedGeneration)
    {
        CancellationTokenSource? eventReaderCancellation;
        Task? eventReaderTask;
        NetworkStream? commandStream;
        NetworkStream? eventStream;
        TcpClient? commandClient;
        TcpClient? eventClient;
        lock (_sessionSync)
        {
            if (Volatile.Read(ref _sessionGeneration) != expectedGeneration)
            {
                return;
            }
            Interlocked.Increment(ref _sessionGeneration);
            eventReaderCancellation = _eventReaderCancellation;
            eventReaderTask = _eventReaderTask;
            commandStream = _commandStream;
            eventStream = _eventStream;
            commandClient = _commandClient;
            eventClient = _eventClient;
            _eventReaderCancellation = null;
            _eventReaderTask = null;
            _commandStream = null;
            _eventStream = null;
            _commandClient = null;
            _eventClient = null;
            lock (_probeSync)
            {
                _probeResponseWaiter?.TrySetException(
                    new IOException("PTP/IP 事件通道已关闭"));
                _probeResponseWaiter = null;
                _eventReaderFailure = null;
                _commandChannelFailure = null;
            }
            Interlocked.Exchange(ref _probeResponseSequence, 0);
            _transactionId = 1;
            _vendor = CameraVendor.Unknown;
            _liveView = false;
            _movieRecording = false;
            CameraName = "PTP/IP Camera";
            Status = "Wi‑Fi 相机未连接";
        }
        eventReaderCancellation?.Cancel();
        commandStream?.Dispose();
        eventStream?.Dispose();
        commandClient?.Dispose();
        eventClient?.Dispose();
        if (eventReaderTask is not null)
        {
            await eventReaderTask;
        }
        eventReaderCancellation?.Dispose();
    }

    /// <summary>
    /// 无副作用链路探测：在 event 通道发送 ProbeRequest(type 13)，等待常驻
    /// reader 收到 ProbeResponse(type 14)；单次探测超时 3s。
    /// </summary>
    public async Task ProbeAsync(
        CancellationToken cancellationToken = default)
    {
        if (_eventStream is null || _eventReaderTask is null)
        {
            throw new InvalidOperationException("请先连接 Wi‑Fi 相机");
        }
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(
            cancellationToken);
        timeout.CancelAfter(TimeSpan.FromMilliseconds(ProbeTimeoutMilliseconds));
        try
        {
            await _probeGate.WaitAsync(timeout.Token);
            try
            {
                var baseline = Interlocked.Read(ref _probeResponseSequence);
                var waiter = new TaskCompletionSource<long>(
                    TaskCreationOptions.RunContinuationsAsynchronously);
                lock (_probeSync)
                {
                    if (_commandChannelFailure is not null)
                    {
                        throw new IOException(
                            "PTP/IP 命令通道不可用",
                            _commandChannelFailure);
                    }
                    if (_eventReaderFailure is not null)
                    {
                        throw new IOException(
                            "PTP/IP 事件通道不可用",
                            _eventReaderFailure);
                    }
                    _probeResponseWaiter = waiter;
                }
                try
                {
                    await SendEventPacketAsync(13, [], timeout.Token);
                    var responseSequence = await waiter.Task.WaitAsync(
                        timeout.Token);
                    var observedSequence = Interlocked.Read(
                        ref _probeResponseSequence);
                    if (responseSequence <= baseline ||
                        observedSequence < responseSequence)
                    {
                        throw new IOException("相机返回了无效的 PTP/IP 探测响应");
                    }
                }
                finally
                {
                    lock (_probeSync)
                    {
                        if (ReferenceEquals(_probeResponseWaiter, waiter))
                        {
                            _probeResponseWaiter = null;
                        }
                    }
                }
            }
            finally
            {
                _probeGate.Release();
            }
        }
        catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            throw new TimeoutException("PTP/IP 事件通道探测超时");
        }
    }

    /// <summary>B2 保活参数（契约测试锚点）：单次探测超时 3s。</summary>
    public const int ProbeTimeoutMilliseconds = 3000;

    /// <summary>B4 保活参数（契约测试锚点）：命令事务空闲超时 12s。</summary>
    public const int CommandTransactionTimeoutMilliseconds = 12000;

    /// <summary>
    /// 为命令事务建立内部空闲超时：deadline 覆盖调用方 token（用户取消直接
    /// 传导），但内部计时是"连续 12 秒无 I/O 进展"而非整笔总时长——每个成功
    /// 收/发都会重置（ResetCommandDeadline）。这样大视频持续传输不受总时长
    /// 限制（与 Android setSoTimeout(12000) 的单次无进展语义一致），而卡死读
    /// 会在最后进展 12 秒后到期：退休 exact captured session 并置
    /// command-channel failure，让 event probe 在心跳中判离线进入统一重连。
    /// </summary>
    private static CancellationTokenSource CreateCommandDeadline(
        CancellationToken cancellationToken)
    {
        var deadline = CancellationTokenSource.CreateLinkedTokenSource(
            cancellationToken);
        ResetCommandDeadline(deadline);
        return deadline;
    }

    /// <summary>每次成功收发后调用，把空闲计时器重置为 12 秒。</summary>
    private static void ResetCommandDeadline(CancellationTokenSource deadline)
    {
        deadline.CancelAfter(
            TimeSpan.FromMilliseconds(CommandTransactionTimeoutMilliseconds));
    }

    public async ValueTask DisposeAsync() => await DisconnectAsync();

    private async Task<ushort> SendCommandAsync(
        ushort operation,
        Func<uint> transactionFactory,
        uint[] parameters,
        CancellationToken cancellationToken,
        CommandSession? expectedSession = null)
    {
        var stream = _commandStream;
        var sessionGeneration = Volatile.Read(ref _sessionGeneration);
        if (expectedSession is { } expected)
        {
            stream = expected.Stream;
            sessionGeneration = expected.Generation;
        }
        if (stream is null)
        {
            throw new InvalidOperationException("请先连接 Wi‑Fi 相机");
        }
        using var deadline = CreateCommandDeadline(cancellationToken);
        var token = deadline.Token;
        await _commandGate.WaitAsync(token);
        var transactionStarted = false;
        try
        {
            EnsureCommandSession(stream, sessionGeneration);
            var transaction = transactionFactory();
            using var payload = new MemoryStream();
            WriteUInt32(payload, 1);
            WriteUInt16(payload, operation);
            WriteUInt32(payload, transaction);
            foreach (var parameter in parameters)
            {
                WriteUInt32(payload, parameter);
            }
            transactionStarted = true;
            await SendPacketAsync(stream, 6, payload.ToArray(), token);
            ResetCommandDeadline(deadline);
            EnsureCommandSession(stream, sessionGeneration);
            var response = await ReceivePacketAsync(stream, token);
            ResetCommandDeadline(deadline);
            EnsureCommandSession(stream, sessionGeneration);
            if (response.Type != 7 || response.Data.Length < 14 ||
                ReadUInt32(response.Data, 10) != transaction)
            {
                throw new IOException("相机返回了无效的 PTP/IP 响应");
            }
            var responseCode = ReadUInt16(response.Data, 8);
            RetireIfSessionFatal(
                responseCode,
                stream,
                sessionGeneration);
            return responseCode;
        }
        catch (IOException error)
        {
            RetireCommandSession(stream, sessionGeneration, error);
            throw;
        }
        catch (OperationCanceledException error) when (transactionStarted)
        {
            if (cancellationToken.IsCancellationRequested)
            {
                RetireCommandSession(stream, sessionGeneration, error);
                throw;
            }
            var timeout = new TimeoutException(
                "PTP/IP 命令事务超时",
                error);
            RetireCommandSession(stream, sessionGeneration, timeout);
            throw timeout;
        }
        catch (OperationCanceledException error)
            when (!cancellationToken.IsCancellationRequested)
        {
            // 内部 deadline 在事务开始前到期（例如等待命令 gate 超时）：
            // 尚未发送任何字节，无需退休；但要与用户取消区分开。
            throw new TimeoutException("PTP/IP 命令事务超时", error);
        }
        finally
        {
            _commandGate.Release();
        }
    }

    private async Task<byte[]> SendCommandWithDataAsync(
        ushort operation,
        Func<uint> transactionFactory,
        uint[] parameters,
        CancellationToken cancellationToken,
        CommandSession? expectedSession = null)
    {
        var stream = _commandStream;
        var sessionGeneration = Volatile.Read(ref _sessionGeneration);
        if (expectedSession is { } expected)
        {
            stream = expected.Stream;
            sessionGeneration = expected.Generation;
        }
        if (stream is null)
        {
            throw new InvalidOperationException("请先连接 Wi‑Fi 相机");
        }
        using var deadline = CreateCommandDeadline(cancellationToken);
        var token = deadline.Token;
        await _commandGate.WaitAsync(token);
        var transactionStarted = false;
        try
        {
            EnsureCommandSession(stream, sessionGeneration);
            var transaction = transactionFactory();
            using var payload = new MemoryStream();
            // PTP/IP value 1 is used for data-in and no-data operations.
            WriteUInt32(payload, 1);
            WriteUInt16(payload, operation);
            WriteUInt32(payload, transaction);
            foreach (var parameter in parameters) WriteUInt32(payload, parameter);
            transactionStarted = true;
            await SendPacketAsync(stream, 6, payload.ToArray(), token);
            ResetCommandDeadline(deadline);
            EnsureCommandSession(stream, sessionGeneration);

            var first = await ReceivePacketAsync(stream, token);
            ResetCommandDeadline(deadline);
            EnsureCommandSession(stream, sessionGeneration);
            if (first.Type == 7)
            {
                if (first.Data.Length < 14 ||
                    ReadUInt32(first.Data, 10) != transaction)
                {
                    throw new IOException("相机返回了无效的 PTP/IP 响应");
                }
                EnsureAcceptedForSession(
                    ReadUInt16(first.Data, 8),
                    stream,
                    sessionGeneration);
                throw new IOException("相机没有返回 PTP/IP 数据阶段");
            }
            if (first.Type != 9 || first.Data.Length < 20 ||
                ReadUInt32(first.Data, 8) != transaction)
            {
                throw new IOException("相机返回了无效的 PTP/IP 数据阶段");
            }
            var totalLength = BinaryPrimitives.ReadUInt64LittleEndian(
                first.Data.AsSpan(12, 8));
            const ulong maximumObjectBytes = 512UL * 1024 * 1024;
            var hasDeclaredLength = totalLength != ulong.MaxValue;
            if (hasDeclaredLength && totalLength > maximumObjectBytes)
            {
                throw new IOException("机内文件超过当前 512 MB 单文件传输上限");
            }
            using var data = new MemoryStream(
                (int)Math.Min(
                    hasDeclaredLength ? totalLength : 8UL * 1024 * 1024,
                    8UL * 1024 * 1024));
            while (true)
            {
                var packet = await ReceivePacketAsync(stream, token);
                ResetCommandDeadline(deadline);
                EnsureCommandSession(stream, sessionGeneration);
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
                if (hasDeclaredLength && (ulong)data.Length > totalLength)
                {
                    throw new IOException("相机返回的数据超过 StartData 声明长度");
                }
                if (packet.Type == 12) break;
            }
            if (hasDeclaredLength && (ulong)data.Length != totalLength)
            {
                throw new IOException("相机返回的数据与 StartData 声明长度不一致");
            }
            var response = await ReceivePacketAsync(stream, token);
            ResetCommandDeadline(deadline);
            EnsureCommandSession(stream, sessionGeneration);
            if (response.Type != 7 || response.Data.Length < 14 ||
                ReadUInt32(response.Data, 10) != transaction)
            {
                throw new IOException("相机没有完成 PTP/IP 文件事务");
            }
            EnsureAcceptedForSession(
                ReadUInt16(response.Data, 8),
                stream,
                sessionGeneration);
            return data.ToArray();
        }
        catch (IOException error)
        {
            RetireCommandSession(stream, sessionGeneration, error);
            throw;
        }
        catch (OperationCanceledException error) when (transactionStarted)
        {
            if (cancellationToken.IsCancellationRequested)
            {
                RetireCommandSession(stream, sessionGeneration, error);
                throw;
            }
            var timeout = new TimeoutException(
                "PTP/IP 命令事务超时",
                error);
            RetireCommandSession(stream, sessionGeneration, timeout);
            throw timeout;
        }
        catch (OperationCanceledException error)
            when (!cancellationToken.IsCancellationRequested)
        {
            // 内部 deadline 在事务开始前到期（例如等待命令 gate 超时）：
            // 尚未发送任何字节，无需退休；但要与用户取消区分开。
            throw new TimeoutException("PTP/IP 命令事务超时", error);
        }
        finally
        {
            _commandGate.Release();
        }
    }

    private CommandSession CaptureCommandSession()
    {
        lock (_sessionSync)
        {
            var stream = _commandStream ?? throw new InvalidOperationException(
                "请先连接 Wi‑Fi 相机");
            var generation = Volatile.Read(ref _sessionGeneration);
            ThrowIfCommandChannelFailed();
            return new CommandSession(stream, generation);
        }
    }

    private void EnsureCommandSession(
        NetworkStream expectedStream,
        long expectedGeneration)
    {
        lock (_sessionSync)
        {
            if (!ReferenceEquals(_commandStream, expectedStream) ||
                Volatile.Read(ref _sessionGeneration) != expectedGeneration)
            {
                throw new OperationCanceledException(
                    "PTP/IP 命令通道已被断开或由新会话取代");
            }
            ThrowIfCommandChannelFailed();
        }
    }

    private void CommitSessionState(CommandSession session, Action commit)
    {
        lock (_sessionSync)
        {
            if (!ReferenceEquals(_commandStream, session.Stream) ||
                Volatile.Read(ref _sessionGeneration) != session.Generation)
            {
                throw new OperationCanceledException(
                    "PTP/IP 会话状态已被断开或由新会话取代");
            }
            ThrowIfCommandChannelFailed();
            commit();
        }
    }

    private bool TryCommitSessionState(CommandSession session, Action commit)
    {
        lock (_sessionSync)
        {
            if (!ReferenceEquals(_commandStream, session.Stream) ||
                Volatile.Read(ref _sessionGeneration) != session.Generation)
            {
                return false;
            }
            lock (_probeSync)
            {
                if (_commandChannelFailure is not null)
                {
                    return false;
                }
            }
            commit();
            return true;
        }
    }

    private void ThrowIfCommandChannelFailed()
    {
        lock (_probeSync)
        {
            if (_commandChannelFailure is { } failure)
            {
                throw new IOException("PTP/IP 命令通道不可用", failure);
            }
        }
    }

    private void RetireCommandSession(
        NetworkStream expectedStream,
        long expectedGeneration,
        Exception error)
    {
        TcpClient? client;
        lock (_sessionSync)
        {
            if (!ReferenceEquals(_commandStream, expectedStream) ||
                Volatile.Read(ref _sessionGeneration) != expectedGeneration)
            {
                return;
            }
            client = _commandClient;
            lock (_probeSync)
            {
                _commandChannelFailure ??= error;
                _probeResponseWaiter?.TrySetException(
                    new IOException("PTP/IP 命令通道已断开", error));
            }
            Status = "PTP/IP 命令通道已断开";
        }
        try
        {
            expectedStream.Dispose();
        }
        catch
        {
            // 退休动作必须保持幂等。
        }
        try
        {
            client?.Dispose();
        }
        catch
        {
            // 退休动作必须保持幂等。
        }
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

    private static TcpClient CreateTcpClient()
    {
        var client = new TcpClient { NoDelay = true };
        client.Client.SetSocketOption(
            SocketOptionLevel.Socket,
            SocketOptionName.KeepAlive,
            true);
        return client;
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

    private void EnsureAcceptedForSession(
        ushort response,
        NetworkStream stream,
        long generation)
    {
        if (response == 0x2001)
        {
            return;
        }
        RetireIfSessionFatal(response, stream, generation);
        throw new PtpResponseException(
            response,
            $"相机拒绝了 PTP/IP 操作（0x{response:X4}）");
    }

    private void RetireIfSessionFatal(
        ushort response,
        NetworkStream stream,
        long generation)
    {
        if (!IsSessionFatalResponse(response))
        {
            return;
        }
        var error = new PtpResponseException(
            response,
            $"相机拒绝了 PTP/IP 操作（0x{response:X4}）");
        RetireCommandSession(stream, generation, error);
        throw error;
    }

    private static void EnsureAccepted(ushort response)
    {
        if (response != 0x2001)
        {
            throw new PtpResponseException(
                response,
                $"相机拒绝了 PTP/IP 操作（0x{response:X4}）");
        }
    }

    private static bool IsVendorDetectionFallback(ushort response) =>
        response is 0x2005 or 0x200a or 0x2019;

    private static bool IsSessionFatalResponse(ushort response) =>
        response is 0x2003 or 0x2004 or 0x201e;

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
