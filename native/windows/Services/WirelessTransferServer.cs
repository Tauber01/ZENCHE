namespace NikonLink.Windows.Services;

public sealed class WirelessTransferServer : IAsyncDisposable
{
    public const int FtpPort = WirelessFtpServer.Port;
    public const int HttpPort = WirelessHttpServer.Port;
    public const string Username = WirelessFtpServer.Username;
    public const string Password = WirelessFtpServer.Password;

    private readonly WirelessFtpServer _ftp;
    private readonly WirelessHttpServer _http;
    private bool _running;

    public WirelessTransferServer(PhotoLibrary library)
    {
        _ftp = new WirelessFtpServer(library);
        _http = new WirelessHttpServer(library);
        _ftp.StatusChanged += (_, status) => PublishStatus(status);
        _http.StatusChanged += (_, status) => PublishStatus(status);
        _ftp.FileReceived += (_, path) => FileReceived?.Invoke(this, path);
        _http.FileReceived += (_, path) => FileReceived?.Invoke(this, path);
        _ftp.Failed += (_, error) => Failed?.Invoke(this, error);
        _http.Failed += (_, error) => Failed?.Invoke(this, error);
    }

    public event EventHandler<string>? StatusChanged;
    public event EventHandler<string>? FileReceived;
    public event EventHandler<Exception>? Failed;

    public bool IsRunning => _running;
    public string LocalAddress => _ftp.LocalAddress;

    public async Task StartAsync()
    {
        if (_running)
        {
            return;
        }
        _running = true;
        try
        {
            await _ftp.StartAsync();
            await _http.StartAsync();
            StatusChanged?.Invoke(
                this,
                "等待 FTP / HTTP / WebDAV 图片");
        }
        catch
        {
            _running = false;
            await _http.StopAsync();
            await _ftp.StopAsync();
            throw;
        }
    }

    public async Task StopAsync()
    {
        if (!_running)
        {
            return;
        }
        _running = false;
        await _http.StopAsync();
        await _ftp.StopAsync();
        StatusChanged?.Invoke(this, "无线收件箱未开启");
    }

    private void PublishStatus(string status)
    {
        if (!_running || status == "无线收件箱未开启")
        {
            return;
        }
        StatusChanged?.Invoke(
            this,
            status == "等待相机无线传输"
                ? "等待 FTP / HTTP / WebDAV 图片"
                : status);
    }

    public async ValueTask DisposeAsync()
    {
        await StopAsync();
        GC.SuppressFinalize(this);
    }
}
