using System.Buffers.Binary;
using System.IO;
using System.Net.Sockets;
using System.Text;
using NikonLink.Windows.Models;

namespace NikonLink.Windows.Services;

public sealed class PtpIpCamera : IAsyncDisposable
{
    private TcpClient? _commandClient;
    private TcpClient? _eventClient;
    private NetworkStream? _commandStream;
    private NetworkStream? _eventStream;
    private uint _transactionId = 1;

    public bool IsConnected => _commandStream is not null;
    public string CameraName { get; private set; } = "PTP/IP Camera";
    public string Status { get; private set; } = "Wi‑Fi 相机未连接";

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
        CameraName = "PTP/IP Camera";
        Status = "Wi‑Fi 相机未连接";
        return Task.CompletedTask;
    }

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

    private static ushort ReadUInt16(byte[] value, int offset) =>
        BinaryPrimitives.ReadUInt16LittleEndian(value.AsSpan(offset, 2));

    private static uint ReadUInt32(byte[] value, int offset) =>
        BinaryPrimitives.ReadUInt32LittleEndian(value.AsSpan(offset, 4));
}
