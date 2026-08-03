using System.IO;
using System.Linq;
using Windows.Devices.Enumeration;
using Windows.Media.Capture;
using Windows.Media.MediaProperties;
using Windows.Storage.Streams;

namespace NikonLink.Windows.Services;

/// <summary>
/// Windows MediaCapture source for built-in webcams and USB Video Class
/// cameras. JPEG output feeds the same preview and file workflow as PTP.
/// </summary>
public sealed class LocalCameraService : IAsyncDisposable
{
    private readonly SemaphoreSlim _gate = new(1, 1);
    private MediaCapture? _capture;

    public bool IsConnected => _capture is not null;
    public bool IsLiveView { get; private set; }
    public string DeviceName { get; private set; } = "本机摄像头";

    public async Task ConnectAsync(CancellationToken cancellationToken = default)
    {
        await _gate.WaitAsync(cancellationToken);
        try
        {
            await DisconnectCoreAsync();
            var devices = await DeviceInformation.FindAllAsync(
                DeviceClass.VideoCapture);
            cancellationToken.ThrowIfCancellationRequested();
            var selected = devices.FirstOrDefault(device => device.IsEnabled)
                ?? devices.FirstOrDefault()
                ?? throw new InvalidOperationException(
                    "没有检测到可用的本机摄像头");
            var capture = new MediaCapture();
            try
            {
                await capture.InitializeAsync(new MediaCaptureInitializationSettings
                {
                    VideoDeviceId = selected.Id,
                    StreamingCaptureMode = StreamingCaptureMode.Video,
                    MemoryPreference = MediaCaptureMemoryPreference.Cpu
                });
                cancellationToken.ThrowIfCancellationRequested();
                _capture = capture;
                DeviceName = selected.Name;
                IsLiveView = false;
            }
            catch (UnauthorizedAccessException error)
            {
                capture.Dispose();
                throw new UnauthorizedAccessException(
                    "未获得摄像头权限；请在 Windows 设置 → 隐私和安全性 → 相机中允许桌面应用访问摄像头。",
                    error);
            }
            catch
            {
                capture.Dispose();
                throw;
            }
        }
        finally
        {
            _gate.Release();
        }
    }

    public Task StartLiveViewAsync(CancellationToken cancellationToken = default)
    {
        cancellationToken.ThrowIfCancellationRequested();
        if (_capture is null) throw new InvalidOperationException(
            "请先连接本机摄像头");
        IsLiveView = true;
        return Task.CompletedTask;
    }

    public Task StopLiveViewAsync()
    {
        IsLiveView = false;
        return Task.CompletedTask;
    }

    public async Task<byte[]> GetLiveViewFrameAsync(
        CancellationToken cancellationToken = default)
    {
        if (!IsLiveView) throw new InvalidOperationException(
            "本机摄像头取景未开启");
        return await CaptureJpegAsync(cancellationToken);
    }

    public async Task<byte[]> CaptureJpegAsync(
        CancellationToken cancellationToken = default)
    {
        await _gate.WaitAsync(cancellationToken);
        try
        {
            var capture = _capture ?? throw new InvalidOperationException(
                "请先连接本机摄像头");
            using var stream = new InMemoryRandomAccessStream();
            await capture.CapturePhotoToStreamAsync(
                ImageEncodingProperties.CreateJpeg(),
                stream);
            cancellationToken.ThrowIfCancellationRequested();
            if (stream.Size == 0) throw new InvalidOperationException(
                "本机摄像头没有返回照片数据");
            if (stream.Size > int.MaxValue) throw new IOException(
                "本机摄像头照片过大，无法载入");
            stream.Seek(0);
            using var reader = new DataReader(stream.GetInputStreamAt(0));
            var size = checked((uint)stream.Size);
            var sizeInt = checked((int)size);
            await reader.LoadAsync(size);
            cancellationToken.ThrowIfCancellationRequested();
            var bytes = new byte[sizeInt];
            reader.ReadBytes(bytes);
            return bytes;
        }
        finally
        {
            _gate.Release();
        }
    }

    public async Task DisconnectAsync()
    {
        await _gate.WaitAsync();
        try
        {
            await DisconnectCoreAsync();
        }
        finally
        {
            _gate.Release();
        }
    }

    private Task DisconnectCoreAsync()
    {
        IsLiveView = false;
        var capture = _capture;
        _capture = null;
        DeviceName = "本机摄像头";
        capture?.Dispose();
        return Task.CompletedTask;
    }

    public async ValueTask DisposeAsync()
    {
        await DisconnectAsync();
        _gate.Dispose();
    }
}
