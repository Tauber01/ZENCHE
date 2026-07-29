using System.IO;
using System.Net;
using System.Net.NetworkInformation;
using System.Net.Sockets;
using System.Text;

namespace NikonLink.Windows.Services;

public sealed class WirelessFtpServer : IAsyncDisposable
{
    public const int Port = 2121;
    public const string Username = "nikonlink";
    public const string Password = "nikonlink";
    private const long MaximumFileSize = 16L * 1024 * 1024 * 1024;

    private readonly PhotoLibrary _library;
    private readonly object _clientLock = new();
    private readonly HashSet<TcpClient> _clients = [];
    private TcpListener? _listener;
    private CancellationTokenSource? _cancellation;
    private Task? _acceptTask;

    public WirelessFtpServer(PhotoLibrary library)
    {
        _library = library;
    }

    public event EventHandler<string>? StatusChanged;
    public event EventHandler<string>? FileReceived;
    public event EventHandler<Exception>? Failed;

    public bool IsRunning =>
        _listener is not null && _cancellation is { IsCancellationRequested: false };

    public string LocalAddress => FindLocalAddress() ?? "未检测到局域网 IPv4 地址";

    public Task StartAsync()
    {
        if (IsRunning)
        {
            return Task.CompletedTask;
        }
        Directory.CreateDirectory(_library.DirectoryPath);
        _cancellation = new CancellationTokenSource();
        _listener = new TcpListener(IPAddress.Any, Port);
        _listener.Server.SetSocketOption(
            SocketOptionLevel.Socket,
            SocketOptionName.ReuseAddress,
            true);
        _listener.Start();
        _acceptTask = AcceptLoopAsync(_cancellation.Token);
        OnStatus("等待相机无线传输");
        return Task.CompletedTask;
    }

    public async Task StopAsync()
    {
        var cancellation = _cancellation;
        var listener = _listener;
        _cancellation = null;
        _listener = null;
        cancellation?.Cancel();
        listener?.Stop();

        TcpClient[] clients;
        lock (_clientLock)
        {
            clients = [.. _clients];
            _clients.Clear();
        }
        foreach (var client in clients)
        {
            client.Dispose();
        }
        if (_acceptTask is not null)
        {
            try
            {
                await _acceptTask;
            }
            catch (OperationCanceledException)
            {
            }
            catch (ObjectDisposedException)
            {
            }
        }
        cancellation?.Dispose();
        OnStatus("无线收件箱未开启");
    }

    private async Task AcceptLoopAsync(CancellationToken cancellationToken)
    {
        var listener = _listener;
        if (listener is null)
        {
            return;
        }
        try
        {
            while (!cancellationToken.IsCancellationRequested)
            {
                var client = await listener.AcceptTcpClientAsync(cancellationToken);
                lock (_clientLock)
                {
                    _clients.Add(client);
                }
                _ = HandleClientAsync(client, cancellationToken);
            }
        }
        catch (OperationCanceledException)
        {
        }
        catch (ObjectDisposedException)
        {
        }
        catch (Exception error)
        {
            if (!cancellationToken.IsCancellationRequested)
            {
                Failed?.Invoke(this, error);
            }
        }
    }

    private async Task HandleClientAsync(
        TcpClient client,
        CancellationToken cancellationToken)
    {
        TcpListener? passiveListener = null;
        try
        {
            client.ReceiveTimeout = 120_000;
            client.SendTimeout = 120_000;
            await using var stream = client.GetStream();
            using var reader = new StreamReader(
                stream,
                new UTF8Encoding(false),
                false,
                4096,
                leaveOpen: true);
            using var writer = new StreamWriter(
                stream,
                new UTF8Encoding(false),
                4096,
                leaveOpen: true)
            {
                NewLine = "\r\n",
                AutoFlush = true
            };

            await ReplyAsync(writer, "220 Nikon Link Wireless Inbox ready");
            OnStatus("相机已连接，等待图片");
            var acceptedUser = false;
            var authenticated = false;
            long restartOffset = 0;

            while (!cancellationToken.IsCancellationRequested)
            {
                var line = await reader.ReadLineAsync(cancellationToken);
                if (line is null)
                {
                    break;
                }
                var trimmed = line.Trim();
                var separator = trimmed.IndexOf(' ');
                var command = (separator < 0
                        ? trimmed
                        : trimmed[..separator])
                    .ToUpperInvariant();
                var argument = separator < 0 ? string.Empty : trimmed[(separator + 1)..].Trim();

                switch (command)
                {
                    case "USER":
                        acceptedUser = string.Equals(
                            argument,
                            Username,
                            StringComparison.OrdinalIgnoreCase);
                        await ReplyAsync(
                            writer,
                            acceptedUser
                                ? "331 Password required"
                                : "530 Invalid user");
                        continue;
                    case "PASS":
                        authenticated = acceptedUser && argument == Password;
                        await ReplyAsync(
                            writer,
                            authenticated
                                ? "230 Login successful"
                                : "530 Login incorrect");
                        continue;
                    case "QUIT":
                        await ReplyAsync(writer, "221 Goodbye");
                        return;
                    case "NOOP":
                        await ReplyAsync(writer, "200 OK");
                        continue;
                    case "SYST":
                        await ReplyAsync(writer, "215 UNIX Type: L8");
                        continue;
                    case "FEAT":
                        await writer.WriteAsync(
                            "211-Features\r\n EPSV\r\n PASV\r\n SIZE\r\n UTF8\r\n211 End\r\n");
                        continue;
                    case "OPTS":
                    case "CLNT":
                        await ReplyAsync(writer, "200 OK");
                        continue;
                }

                if (!authenticated)
                {
                    await ReplyAsync(writer, "530 Please login");
                    continue;
                }

                switch (command)
                {
                    case "PWD":
                    case "XPWD":
                        await ReplyAsync(writer, "257 \"/\" is current directory");
                        break;
                    case "CWD":
                    case "CDUP":
                        await ReplyAsync(writer, "250 Directory changed");
                        break;
                    case "MKD":
                    case "XMKD":
                        await ReplyAsync(writer, "257 Directory ready");
                        break;
                    case "TYPE":
                    case "MODE":
                    case "STRU":
                        await ReplyAsync(writer, "200 Transfer mode set");
                        break;
                    case "PASV":
                    case "EPSV":
                        passiveListener?.Stop();
                        var localAddress =
                            ((IPEndPoint)client.Client.LocalEndPoint!).Address;
                        passiveListener = new TcpListener(localAddress, 0);
                        passiveListener.Start(1);
                        var passivePort =
                            ((IPEndPoint)passiveListener.LocalEndpoint).Port;
                        if (command == "EPSV")
                        {
                            await ReplyAsync(
                                writer,
                                $"229 Entering Extended Passive Mode (|||{passivePort}|)");
                        }
                        else if (localAddress.AddressFamily != AddressFamily.InterNetwork)
                        {
                            await ReplyAsync(writer, "425 IPv4 connection required");
                            passiveListener.Stop();
                            passiveListener = null;
                        }
                        else
                        {
                            var octets = localAddress.GetAddressBytes();
                            await ReplyAsync(
                                writer,
                                $"227 Entering Passive Mode (" +
                                $"{octets[0]},{octets[1]},{octets[2]},{octets[3]}," +
                                $"{passivePort / 256},{passivePort % 256})");
                        }
                        break;
                    case "REST":
                        _ = long.TryParse(argument, out restartOffset);
                        restartOffset = Math.Max(0, restartOffset);
                        await ReplyAsync(writer, "350 Restart position accepted");
                        break;
                    case "STOR":
                    case "APPE":
                        if (passiveListener is null)
                        {
                            await ReplyAsync(writer, "425 Use PASV first");
                            break;
                        }
                        await ReplyAsync(writer, "150 Opening binary connection");
                        try
                        {
                            var destination = await ReceiveFileAsync(
                                passiveListener,
                                argument,
                                command == "APPE" || restartOffset > 0,
                                restartOffset,
                                cancellationToken);
                            await ReplyAsync(writer, "226 Transfer complete");
                            FileReceived?.Invoke(this, destination);
                        }
                        catch
                        {
                            await ReplyAsync(writer, "451 Transfer failed");
                        }
                        finally
                        {
                            passiveListener.Stop();
                            passiveListener = null;
                            restartOffset = 0;
                        }
                        break;
                    case "LIST":
                    case "NLST":
                        if (passiveListener is null)
                        {
                            await ReplyAsync(writer, "425 Use PASV first");
                            break;
                        }
                        await ReplyAsync(writer, "150 Opening data connection");
                        try
                        {
                            using var dataClient =
                                await passiveListener.AcceptTcpClientAsync(
                                    cancellationToken);
                            await using var dataStream = dataClient.GetStream();
                            await dataStream.FlushAsync(cancellationToken);
                            await ReplyAsync(writer, "226 Directory send OK");
                        }
                        finally
                        {
                            passiveListener.Stop();
                            passiveListener = null;
                        }
                        break;
                    case "SIZE":
                    case "MDTM":
                        await ReplyAsync(writer, "550 File unavailable");
                        break;
                    case "PORT":
                    case "EPRT":
                        await ReplyAsync(writer, "502 Enable PASV mode on camera");
                        break;
                    default:
                        await ReplyAsync(writer, "502 Command not implemented");
                        break;
                }
            }
        }
        catch (OperationCanceledException)
        {
        }
        catch (IOException)
        {
            if (IsRunning)
            {
                OnStatus("无线连接已断开，等待相机重连");
            }
        }
        finally
        {
            passiveListener?.Stop();
            client.Dispose();
            lock (_clientLock)
            {
                _clients.Remove(client);
            }
            if (IsRunning)
            {
                OnStatus("等待相机无线传输");
            }
        }
    }

    private async Task<string> ReceiveFileAsync(
        TcpListener passiveListener,
        string remoteName,
        bool append,
        long restartOffset,
        CancellationToken cancellationToken)
    {
        var finalDestination = _library.UniqueDestination(remoteName);
        var temporary = finalDestination + "." + Guid.NewGuid().ToString("N") + ".part";
        try
        {
            using var dataClient =
                await passiveListener.AcceptTcpClientAsync(cancellationToken);
            dataClient.ReceiveTimeout = 120_000;
            await using var input = dataClient.GetStream();
            await using var output = new FileStream(
                temporary,
                FileMode.CreateNew,
                FileAccess.Write,
                FileShare.None,
                256 * 1024,
                FileOptions.Asynchronous | FileOptions.SequentialScan);
            if (append && restartOffset > 0 && File.Exists(finalDestination))
            {
                await using var existing = File.OpenRead(finalDestination);
                await existing.CopyToAsync(output, cancellationToken);
                output.Position = Math.Min(restartOffset, output.Length);
            }

            var buffer = new byte[256 * 1024];
            long total = output.Length;
            while (true)
            {
                var count = await input.ReadAsync(buffer, cancellationToken);
                if (count == 0)
                {
                    break;
                }
                total += count;
                if (total > MaximumFileSize)
                {
                    throw new IOException("无线文件超过 16 GB 限制。");
                }
                await output.WriteAsync(buffer.AsMemory(0, count), cancellationToken);
            }
            await output.FlushAsync(cancellationToken);
            output.Flush(true);
            if (total == 0)
            {
                throw new IOException("相机发送了空文件。");
            }
            File.Move(temporary, finalDestination);
            return finalDestination;
        }
        finally
        {
            if (File.Exists(temporary))
            {
                File.Delete(temporary);
            }
        }
    }

    private static Task ReplyAsync(StreamWriter writer, string line) =>
        writer.WriteLineAsync(line);

    private void OnStatus(string status) =>
        StatusChanged?.Invoke(this, status);

    private static string? FindLocalAddress()
    {
        string? fallback = null;
        foreach (var network in NetworkInterface.GetAllNetworkInterfaces())
        {
            if (network.OperationalStatus != OperationalStatus.Up ||
                network.NetworkInterfaceType == NetworkInterfaceType.Loopback)
            {
                continue;
            }
            foreach (var information in
                     network.GetIPProperties().UnicastAddresses)
            {
                var address = information.Address;
                if (address.AddressFamily != AddressFamily.InterNetwork ||
                    IPAddress.IsLoopback(address))
                {
                    continue;
                }
                if (network.NetworkInterfaceType ==
                    NetworkInterfaceType.Wireless80211)
                {
                    return address.ToString();
                }
                fallback ??= address.ToString();
            }
        }
        return fallback;
    }

    public async ValueTask DisposeAsync()
    {
        await StopAsync();
        GC.SuppressFinalize(this);
    }
}
