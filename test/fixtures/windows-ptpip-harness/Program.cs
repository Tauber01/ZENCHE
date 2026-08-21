// ZENCHE Windows PTP/IP 行为验证线束：进程内伪相机（TcpListener @ 127.0.0.1）
// 驱动 native/windows/Services/PtpIpCamera.cs 的真实代码路径。
// 由 test/native-windows-ptpip-behavior.test.mjs 调用；输出机器可校验行：
//   RESULT <scenario> PASS|FAIL <details>
// 帧格式与生产代码一致：[u32 长度 LE][u32 类型 LE][载荷]，长度含 8 字节头。
using System.Buffers.Binary;
using System.Diagnostics;
using System.Net;
using System.Net.Sockets;
using System.Text;
using NikonLink.Windows.Services;

var scenario = args.Length > 0 ? args[0] : string.Empty;
try
{
    switch (scenario)
    {
        case "a": await ScenarioFullConnectAsync(); break;
        case "b": await ScenarioProbeTimeoutAsync(); break;
        case "c": await ScenarioEventChannelHalfCloseAsync(); break;
        case "d": await ScenarioSilentHandshakeAsync(); break;
        case "e": await ScenarioStaleGenerationAsync(); break;
        default:
            Console.WriteLine($"RESULT {scenario} FAIL unknown-scenario");
            return 1;
    }
}
catch (Exception error)
{
    Console.WriteLine($"RESULT {scenario} FAIL {error.GetType().Name}: {error.Message}");
    return 1;
}
return 0;

// (a) 完整 connect + OpenSession + probe 成功。
static async Task ScenarioFullConnectAsync()
{
    using var camera = new FakePtpIpCamera();
    await using var client = new PtpIpCamera();
    var stopwatch = Stopwatch.StartNew();
    var connection = await client.ConnectWithOwnershipAsync(
        "127.0.0.1",
        camera.Port);
    if (!client.IsConnected)
    {
        throw new Exception("连接成功后 IsConnected 应为 true");
    }
    if (connection.SessionGeneration <= 0)
    {
        throw new Exception("会话代际应为正数");
    }
    await client.ProbeAsync();
    Console.WriteLine(
        $"RESULT a PASS camera={connection.CameraName} " +
        $"elapsed_ms={stopwatch.ElapsedMilliseconds}");
}

// (b) 伪相机忽略探测请求 → ProbeAsync 在 ≈ProbeTimeoutMilliseconds 内失败。
static async Task ScenarioProbeTimeoutAsync()
{
    using var camera = new FakePtpIpCamera(answerProbes: false);
    await using var client = new PtpIpCamera();
    await client.ConnectWithOwnershipAsync("127.0.0.1", camera.Port);
    var stopwatch = Stopwatch.StartNew();
    try
    {
        await client.ProbeAsync();
        throw new Exception("相机忽略探测时 ProbeAsync 不应成功");
    }
    catch (TimeoutException)
    {
        // 预期路径。
    }
    var elapsed = stopwatch.ElapsedMilliseconds;
    var probeTimeout = PtpIpCamera.ProbeTimeoutMilliseconds;
    if (elapsed < probeTimeout - 500 || elapsed > probeTimeout + 5000)
    {
        throw new Exception(
            $"探测超时耗时异常：{elapsed}ms（预期≈{probeTimeout}ms）");
    }
    Console.WriteLine(
        $"RESULT b PASS elapsed_ms={elapsed} probe_timeout_ms={probeTimeout}");
}

// (c) 伪相机半关闭事件通道 → 下一次探测必须暴露 reader 失败（IOException），
//     不得静默成功、也不得仅按超时处理。
static async Task ScenarioEventChannelHalfCloseAsync()
{
    using var camera = new FakePtpIpCamera(halfCloseEventAfterOpenSession: true);
    await using var client = new PtpIpCamera();
    await client.ConnectWithOwnershipAsync("127.0.0.1", camera.Port);
    await camera.OpenSessionResponded.WaitAsync(TimeSpan.FromSeconds(5));
    Exception? observed = null;
    var deadline = Stopwatch.StartNew();
    while (deadline.ElapsedMilliseconds < 5000)
    {
        try
        {
            await client.ProbeAsync();
        }
        catch (Exception error)
        {
            observed = error;
            break;
        }
        await Task.Delay(100);
    }
    if (observed is null)
    {
        throw new Exception("事件通道半关闭后探测仍然成功");
    }
    if (observed is not IOException || !observed.Message.Contains("事件通道"))
    {
        throw new Exception(
            "探测应暴露事件通道 IOException，实际：" +
            $"{observed.GetType().Name}: {observed.Message}");
    }
    Console.WriteLine($"RESULT c PASS detail={observed.GetType().Name}");
}

// (d) 伪相机接受 TCP 但永不应答握手。传输层对握手阶段没有内置超时
//     （12s 握手预算在 UI 层 MainWindow）；这里断言传输层实际保证的语义：
//     不自行结束，且调用方 CancellationToken 能终止并完成清理。
static async Task ScenarioSilentHandshakeAsync()
{
    using var camera = new FakePtpIpCamera(answerHandshake: false);
    await using var client = new PtpIpCamera();
    using var caller = new CancellationTokenSource(TimeSpan.FromSeconds(4));
    var stopwatch = Stopwatch.StartNew();
    var connect = client.ConnectWithOwnershipAsync(
        "127.0.0.1",
        camera.Port,
        caller.Token);
    if (await Task.WhenAny(connect, Task.Delay(2000)) == connect)
    {
        throw new Exception("握手无应答时连接不应在 2s 内自行结束");
    }
    try
    {
        await connect;
        throw new Exception("握手无应答时连接不应成功");
    }
    catch (OperationCanceledException)
    {
        // 由调用方 CTS 取消——传输层为握手阶段保证的唯一取消语义。
    }
    var elapsed = stopwatch.ElapsedMilliseconds;
    if (elapsed < 3000 || elapsed > 10000)
    {
        throw new Exception($"调用方取消耗时异常：{elapsed}ms");
    }
    if (client.IsConnected)
    {
        throw new Exception("握手取消后 IsConnected 应为 false");
    }
    Console.WriteLine(
        $"RESULT d PASS elapsed_ms={elapsed} " +
        "note=no-transport-handshake-timeout;caller-token-cancels");
}

// (e) 过期代际所有权：错误代际的 DisconnectIfOwnedAsync 不得拆除存活会话。
static async Task ScenarioStaleGenerationAsync()
{
    using var camera = new FakePtpIpCamera();
    await using var client = new PtpIpCamera();
    var connection = await client.ConnectWithOwnershipAsync(
        "127.0.0.1",
        camera.Port);
    await client.DisconnectIfOwnedAsync(connection.SessionGeneration + 999);
    if (!client.IsConnected)
    {
        throw new Exception("错误代际拆除了存活会话");
    }
    await client.ProbeAsync(); // 会话仍须可用
    await client.DisconnectIfOwnedAsync(connection.SessionGeneration);
    if (client.IsConnected)
    {
        throw new Exception("正确代际未能拆除会话");
    }
    Console.WriteLine("RESULT e PASS");
}

/// <summary>
/// 进程内伪 PTP/IP 相机：单 TcpListener，先接入命令通道、握手完成后再接
/// 事件通道。type 1→2 握手应答；type 3→4 事件通道应答；type 6 命令容器 →
/// type 7 响应 0x2001；事件通道 type 13 探测 → type 14（可配置忽略）。
/// </summary>
internal sealed class FakePtpIpCamera : IDisposable
{
    private readonly TcpListener _listener = new(IPAddress.Loopback, 0);
    private readonly CancellationTokenSource _shutdown = new();
    private readonly TaskCompletionSource _openSessionResponded =
        new(TaskCreationOptions.RunContinuationsAsynchronously);
    private readonly bool _answerHandshake;
    private readonly bool _answerProbes;
    private readonly bool _halfCloseEventAfterOpenSession;
    private readonly Task _runTask;
    private volatile TcpClient? _eventChannel;

    public FakePtpIpCamera(
        bool answerHandshake = true,
        bool answerProbes = true,
        bool halfCloseEventAfterOpenSession = false)
    {
        _answerHandshake = answerHandshake;
        _answerProbes = answerProbes;
        _halfCloseEventAfterOpenSession = halfCloseEventAfterOpenSession;
        _listener.Start();
        Port = ((IPEndPoint)_listener.LocalEndpoint).Port;
        _runTask = RunAsync(_shutdown.Token);
    }

    public int Port { get; }

    public Task OpenSessionResponded => _openSessionResponded.Task;

    private async Task RunAsync(CancellationToken cancellationToken)
    {
        try
        {
            var command = await _listener.AcceptTcpClientAsync(cancellationToken);
            var commandTask = RunCommandChannelAsync(command, cancellationToken);
            var eventChannel = await _listener.AcceptTcpClientAsync(cancellationToken);
            _eventChannel = eventChannel;
            var eventTask = RunEventChannelAsync(eventChannel, cancellationToken);
            await Task.WhenAll(commandTask, eventTask);
        }
        catch (OperationCanceledException)
        {
            // 正常关闭。
        }
        catch (ObjectDisposedException)
        {
            // 正常关闭。
        }
        catch (SocketException)
        {
            // 对端消失。
        }
    }

    private async Task RunCommandChannelAsync(
        TcpClient client,
        CancellationToken cancellationToken)
    {
        try
        {
            using (client)
            {
                var stream = client.GetStream();
                while (!cancellationToken.IsCancellationRequested)
                {
                    var (type, payload) = await ReadPacketAsync(
                        stream,
                        cancellationToken);
                    if (type == 1)
                    {
                        // type 1 InitCommandRequest → type 2 InitCommandAck：
                        // [u32 connectionNumber][16B GUID][UTF16 名称][u32 版本]
                        if (!_answerHandshake)
                        {
                            continue; // 接受 TCP 但永不应答握手（场景 d）
                        }
                        using var ack = new MemoryStream();
                        WriteUInt32(ack, 1);
                        ack.Write(new byte[16]);
                        ack.Write(Encoding.Unicode.GetBytes("ZENCHE FakeCam\0"));
                        WriteUInt32(ack, 0x00010000);
                        await WritePacketAsync(
                            stream,
                            2,
                            ack.ToArray(),
                            cancellationToken);
                    }
                    else if (type == 6)
                    {
                        // type 6 命令容器：[u32 dataPhase][u16 op][u32 txn][参数…]
                        // 响应 type 7：[u16 0x2001][u32 txn]
                        var operation = BinaryPrimitives
                            .ReadUInt16LittleEndian(payload.AsSpan(4, 2));
                        var transaction = BinaryPrimitives
                            .ReadUInt32LittleEndian(payload.AsSpan(6, 4));
                        var response = new byte[6];
                        BinaryPrimitives.WriteUInt16LittleEndian(response, 0x2001);
                        BinaryPrimitives.WriteUInt32LittleEndian(
                            response.AsSpan(2, 4),
                            transaction);
                        await WritePacketAsync(
                            stream,
                            7,
                            response,
                            cancellationToken);
                        if (operation == 0x1002)
                        {
                            _openSessionResponded.TrySetResult();
                            if (_halfCloseEventAfterOpenSession)
                            {
                                // 半关闭事件通道（server→client 方向 FIN）。
                                try
                                {
                                    _eventChannel?.Client.Shutdown(
                                        SocketShutdown.Send);
                                }
                                catch (SocketException)
                                {
                                    // 对端已离开。
                                }
                            }
                        }
                    }
                }
            }
        }
        catch (Exception)
        {
            // 通道随会话结束而关闭；伪相机无需上报。
        }
    }

    private async Task RunEventChannelAsync(
        TcpClient client,
        CancellationToken cancellationToken)
    {
        try
        {
            using (client)
            {
                var stream = client.GetStream();
                while (!cancellationToken.IsCancellationRequested)
                {
                    var (type, _) = await ReadPacketAsync(
                        stream,
                        cancellationToken);
                    if (type == 3)
                    {
                        await WritePacketAsync(stream, 4, [], cancellationToken);
                    }
                    else if (type == 13 && _answerProbes)
                    {
                        await WritePacketAsync(stream, 14, [], cancellationToken);
                    }
                }
            }
        }
        catch (Exception)
        {
            // 通道随会话结束而关闭；伪相机无需上报。
        }
    }

    private static async Task<(uint Type, byte[] Payload)> ReadPacketAsync(
        NetworkStream stream,
        CancellationToken cancellationToken)
    {
        var header = await ReadExactlyAsync(stream, 8, cancellationToken);
        var length = checked((int)BinaryPrimitives.ReadUInt32LittleEndian(header));
        if (length is < 8 or > 67108864)
        {
            throw new IOException("无效帧长度");
        }
        var payload = new byte[length - 8];
        if (payload.Length > 0)
        {
            var remainder = await ReadExactlyAsync(
                stream,
                payload.Length,
                cancellationToken);
            remainder.CopyTo(payload, 0);
        }
        return (BinaryPrimitives.ReadUInt32LittleEndian(header.AsSpan(4)), payload);
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
                throw new IOException("对端提前关闭连接");
            }
            offset += count;
        }
        return result;
    }

    private static async Task WritePacketAsync(
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

    private static void WriteUInt32(Stream stream, uint value)
    {
        Span<byte> buffer = stackalloc byte[4];
        BinaryPrimitives.WriteUInt32LittleEndian(buffer, value);
        stream.Write(buffer);
    }

    public void Dispose()
    {
        _shutdown.Cancel();
        _listener.Stop();
        try
        {
            _runTask.Wait(TimeSpan.FromSeconds(2));
        }
        catch
        {
            // 关闭路径尽力而为。
        }
        _shutdown.Dispose();
    }
}
