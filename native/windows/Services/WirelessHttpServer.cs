using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Text.Json;

namespace NikonLink.Windows.Services;

public sealed class WirelessHttpServer : IAsyncDisposable
{
    public const int Port = 8080;
    private const long MaximumFileSize = 16L * 1024 * 1024 * 1024;
    private const int MaximumHeaderSize = 32 * 1024;
    private static readonly string Authorization =
        "Basic " + Convert.ToBase64String(
            Encoding.UTF8.GetBytes(
                $"{WirelessFtpServer.Username}:{WirelessFtpServer.Password}"));

    private readonly PhotoLibrary _library;
    private readonly object _clientLock = new();
    private readonly HashSet<TcpClient> _clients = [];
    private TcpListener? _listener;
    private CancellationTokenSource? _cancellation;
    private Task? _acceptTask;

    public WirelessHttpServer(PhotoLibrary library)
    {
        _library = library;
    }

    public event EventHandler<string>? StatusChanged;
    public event EventHandler<string>? FileReceived;
    public event EventHandler<Exception>? Failed;

    public bool IsRunning =>
        _listener is not null &&
        _cancellation is { IsCancellationRequested: false };

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
                var client =
                    await listener.AcceptTcpClientAsync(cancellationToken);
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
        try
        {
            client.ReceiveTimeout = 120_000;
            client.SendTimeout = 120_000;
            client.NoDelay = true;
            await using var stream = client.GetStream();
            var request = await ReadRequestAsync(stream, cancellationToken);
            if (request is null)
            {
                return;
            }
            if (!request.Headers.TryGetValue(
                    "authorization",
                    out var authorization) ||
                authorization != Authorization)
            {
                await RespondAsync(
                    stream,
                    401,
                    "Unauthorized",
                    "需要使用 帧澈 ZENCHE 无线收件箱账号。",
                    new Dictionary<string, string>
                    {
                        ["WWW-Authenticate"] = "Basic realm=\"ZENCHE\""
                    },
                    cancellationToken);
                return;
            }

            switch (request.Method)
            {
                case "OPTIONS":
                    await RespondAsync(
                        stream,
                        200,
                        "OK",
                        string.Empty,
                        new Dictionary<string, string>
                        {
                            ["Allow"] =
                                "OPTIONS, GET, PUT, POST, MKCOL, PROPFIND",
                            ["DAV"] = "1"
                        },
                        cancellationToken);
                    break;
                case "GET":
                    await RespondAsync(
                        stream,
                        200,
                        "OK",
                        "{\"service\":\"ZENCHE\",\"upload\":\"ready\"}",
                        new Dictionary<string, string>
                        {
                            ["Content-Type"] =
                                "application/json; charset=utf-8"
                        },
                        cancellationToken);
                    break;
                case "MKCOL":
                    await RespondAsync(
                        stream,
                        201,
                        "Created",
                        string.Empty,
                        new Dictionary<string, string> { ["DAV"] = "1" },
                        cancellationToken);
                    break;
                case "PROPFIND":
                    const string xml =
                        "<?xml version=\"1.0\" encoding=\"utf-8\"?>" +
                        "<d:multistatus xmlns:d=\"DAV:\"><d:response>" +
                        "<d:href>/</d:href><d:propstat><d:prop>" +
                        "<d:resourcetype><d:collection/></d:resourcetype>" +
                        "<d:displayname>ZENCHE</d:displayname></d:prop>" +
                        "<d:status>HTTP/1.1 200 OK</d:status></d:propstat>" +
                        "</d:response></d:multistatus>";
                    await RespondAsync(
                        stream,
                        207,
                        "Multi-Status",
                        xml,
                        new Dictionary<string, string>
                        {
                            ["Content-Type"] =
                                "application/xml; charset=utf-8",
                            ["DAV"] = "1"
                        },
                        cancellationToken);
                    break;
                case "PUT":
                case "POST":
                    await ReceiveAsync(request, stream, cancellationToken);
                    break;
                default:
                    await RespondAsync(
                        stream,
                        405,
                        "Method Not Allowed",
                        "此无线入口仅支持图片上传。",
                        new Dictionary<string, string>
                        {
                            ["Allow"] =
                                "OPTIONS, GET, PUT, POST, MKCOL, PROPFIND"
                        },
                        cancellationToken);
                    break;
            }
        }
        catch (OperationCanceledException)
        {
        }
        catch (IOException)
        {
        }
        catch (Exception error)
        {
            if (!cancellationToken.IsCancellationRequested)
            {
                Failed?.Invoke(this, error);
            }
        }
        finally
        {
            client.Dispose();
            lock (_clientLock)
            {
                _clients.Remove(client);
            }
        }
    }

    private async Task ReceiveAsync(
        Request request,
        NetworkStream stream,
        CancellationToken cancellationToken)
    {
        if (!request.Headers.TryGetValue(
                "content-length",
                out var lengthText) ||
            !long.TryParse(lengthText, out var length))
        {
            await RespondAsync(
                stream,
                411,
                "Length Required",
                "请提供有效的 Content-Length。",
                null,
                cancellationToken);
            return;
        }
        if (length <= 0 || length > MaximumFileSize)
        {
            await RespondAsync(
                stream,
                413,
                "Content Too Large",
                "图片大小必须在 1 字节到 16 GB 之间。",
                null,
                cancellationToken);
            return;
        }
        var filename = RequestedFilename(request);
        if (string.IsNullOrWhiteSpace(filename))
        {
            await RespondAsync(
                stream,
                400,
                "Bad Request",
                "请使用 /upload/文件名，或提供 X-Filename 请求头。",
                null,
                cancellationToken);
            return;
        }

        StatusChanged?.Invoke(
            this,
            $"正在通过 HTTP / WebDAV 接收 {filename}");
        var destination = _library.UniqueDestination(filename);
        var temporary =
            destination + "." + Guid.NewGuid().ToString("N") + ".part";
        try
        {
            await using var output = new FileStream(
                temporary,
                FileMode.CreateNew,
                FileAccess.Write,
                FileShare.None,
                256 * 1024,
                FileOptions.Asynchronous | FileOptions.SequentialScan);
            var buffer = new byte[256 * 1024];
            long remaining = length;
            while (remaining > 0)
            {
                var count = await stream.ReadAsync(
                    buffer.AsMemory(
                        0,
                        (int)Math.Min(buffer.Length, remaining)),
                    cancellationToken);
                if (count == 0)
                {
                    throw new IOException("图片上传提前中断。");
                }
                await output.WriteAsync(
                    buffer.AsMemory(0, count),
                    cancellationToken);
                remaining -= count;
            }
            await output.FlushAsync(cancellationToken);
            output.Flush(true);
            File.Move(temporary, destination);
        }
        finally
        {
            if (File.Exists(temporary))
            {
                File.Delete(temporary);
            }
        }

        FileReceived?.Invoke(this, destination);
        var body = JsonSerializer.Serialize(
            new { saved = Path.GetFileName(destination) });
        await RespondAsync(
            stream,
            201,
            "Created",
            body,
            new Dictionary<string, string>
            {
                ["Content-Type"] = "application/json; charset=utf-8",
                ["Location"] =
                    "/" + Uri.EscapeDataString(Path.GetFileName(destination))
            },
            cancellationToken);
    }

    private static async Task<Request?> ReadRequestAsync(
        NetworkStream stream,
        CancellationToken cancellationToken)
    {
        var bytes = new List<byte>();
        var single = new byte[1];
        var matched = 0;
        while (bytes.Count < MaximumHeaderSize)
        {
            var count = await stream.ReadAsync(single, cancellationToken);
            if (count == 0)
            {
                return null;
            }
            var value = single[0];
            bytes.Add(value);
            if ((matched is 0 or 2) && value == '\r')
            {
                matched++;
            }
            else if ((matched is 1 or 3) && value == '\n')
            {
                matched++;
                if (matched == 4)
                {
                    break;
                }
            }
            else
            {
                matched = value == '\r' ? 1 : 0;
            }
        }
        if (matched != 4)
        {
            return null;
        }
        var text = Encoding.UTF8.GetString(
            bytes.GetRange(0, bytes.Count - 4).ToArray());
        var lines = text.Split("\r\n", StringSplitOptions.None);
        var requestLine = lines[0].Split(' ', 3);
        if (requestLine.Length < 2)
        {
            return null;
        }
        var headers = new Dictionary<string, string>(
            StringComparer.OrdinalIgnoreCase);
        foreach (var line in lines.Skip(1))
        {
            var separator = line.IndexOf(':');
            if (separator <= 0)
            {
                continue;
            }
            headers[line[..separator].Trim().ToLowerInvariant()] =
                line[(separator + 1)..].Trim();
        }
        return new Request(
            requestLine[0].ToUpperInvariant(),
            requestLine[1],
            headers);
    }

    private static string? RequestedFilename(Request request)
    {
        if (request.Headers.TryGetValue("x-filename", out var explicitName) &&
            !string.IsNullOrWhiteSpace(explicitName))
        {
            return explicitName.Trim();
        }
        if (!Uri.TryCreate(
                "http://127.0.0.1" + request.Target,
                UriKind.Absolute,
                out var uri))
        {
            return null;
        }
        var path = Uri.UnescapeDataString(uri.AbsolutePath);
        if (path is not "/" and not "/upload" and not "/upload/")
        {
            return Path.GetFileName(path);
        }
        foreach (var part in uri.Query.TrimStart('?').Split('&'))
        {
            var pair = part.Split('=', 2);
            if (pair.Length == 2 &&
                pair[0].Equals("filename", StringComparison.OrdinalIgnoreCase))
            {
                return WebUtility.UrlDecode(pair[1]);
            }
        }
        return null;
    }

    private static async Task RespondAsync(
        NetworkStream stream,
        int status,
        string reason,
        string body,
        IReadOnlyDictionary<string, string>? headers,
        CancellationToken cancellationToken)
    {
        var content = Encoding.UTF8.GetBytes(body);
        var head = new StringBuilder()
            .Append($"HTTP/1.1 {status} {reason}\r\n")
            .Append("Connection: close\r\n")
            .Append($"Content-Length: {content.Length}\r\n");
        if (headers is not null)
        {
            foreach (var (name, value) in headers)
            {
                head.Append($"{name}: {value}\r\n");
            }
        }
        head.Append("\r\n");
        await stream.WriteAsync(
            Encoding.ASCII.GetBytes(head.ToString()),
            cancellationToken);
        await stream.WriteAsync(content, cancellationToken);
        await stream.FlushAsync(cancellationToken);
    }

    private sealed record Request(
        string Method,
        string Target,
        Dictionary<string, string> Headers);

    public async ValueTask DisposeAsync()
    {
        await StopAsync();
        GC.SuppressFinalize(this);
    }
}
