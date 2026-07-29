using NikonLink.Windows.Models;
using NikonLink.Windows.Services;
using System.Collections.ObjectModel;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Imaging;

namespace NikonLink.Windows;

public partial class MainWindow : Window
{
    private readonly PtpCamera _camera = new();
    private readonly PhotoLibrary _library = new();
    private readonly WirelessFtpServer _wirelessServer;
    private readonly DiagnosticLogger _diagnostics = DiagnosticLogger.Shared;
    private readonly ObservableCollection<PhotoItem> _photos = [];
    private CancellationTokenSource? _previewCancellation;
    private Task? _previewTask;
    private bool _operationInProgress;
    private bool _initializing = true;
    private bool _shutdownStarted;

    public MainWindow()
    {
        InitializeComponent();
        _wirelessServer = new WirelessFtpServer(_library);
        _wirelessServer.StatusChanged += (_, status) =>
            Dispatcher.Invoke(() =>
            {
                _diagnostics.Info("wireless", status);
                WirelessStatusText.Text = status;
                OperationStatusText.Text = status;
            });
        _wirelessServer.FileReceived += (_, path) =>
            Dispatcher.Invoke(() =>
            {
                _diagnostics.Info(
                    "wireless",
                    $"已接收文件；名称={Path.GetFileName(path)}");
                OperationStatusText.Text = $"已接收 {Path.GetFileName(path)}";
                RefreshPhotoList();
            });
        _wirelessServer.Failed += (_, error) =>
            Dispatcher.Invoke(() =>
            {
                _diagnostics.Error("wireless", error.ToString());
                WirelessStatusText.Text = $"无线接收失败：{error.Message}";
                WirelessButton.Content = "开启无线接收";
                ShowError(error.Message);
            });
        PhotoList.ItemsSource = _photos;
        DiagnosticLogPathText.Text =
            "按日写入、5 MB 滚动、保留 14 天\n" +
            _diagnostics.DirectoryPath;
        RefreshPhotoList();
        SetCurrentNavigation(CaptureNav);
        _initializing = false;
        Closing += Window_Closing;
    }

    private async void ConnectButton_Click(object sender, RoutedEventArgs e)
    {
        if (_operationInProgress)
        {
            return;
        }
        if (_camera.IsConnected)
        {
            await RunOperationAsync("正在断开相机…", async token =>
            {
                await StopPreviewLoopAsync();
                await _camera.DisconnectAsync(token);
                SetConnectionState(null);
                OperationStatusText.Text = "相机已断开";
            });
            return;
        }

        await RunOperationAsync("正在连接 Nikon 相机…", async token =>
        {
            var profile = await _camera.ConnectAsync(token);
            SetConnectionState(profile);
            OperationStatusText.Text = $"{profile.Name} 已连接";
        });
    }

    private async void LiveViewButton_Click(object sender, RoutedEventArgs e)
    {
        if (_operationInProgress || !_camera.IsConnected)
        {
            return;
        }
        if (_camera.IsLiveView)
        {
            await RunOperationAsync("正在停止实时取景…", async token =>
            {
                await StopPreviewLoopAsync();
                await _camera.StopLiveViewAsync(token);
                UpdateLiveViewState();
            });
            return;
        }
        await RunOperationAsync("正在开启实时取景…", async token =>
        {
            await _camera.StartLiveViewAsync(token);
            UpdateLiveViewState();
            StartPreviewLoop();
        });
    }

    private async void ShutterButton_Click(object sender, RoutedEventArgs e)
    {
        if (_operationInProgress || !_camera.IsConnected)
        {
            return;
        }
        await RunOperationAsync("正在拍摄并下载 JPEG…", async token =>
        {
            var jpeg = await _camera.CaptureAsync(token);
            var path = await _library.SaveCaptureAsync(jpeg, token);
            DisplayJpeg(jpeg);
            RefreshPhotoList();
            OperationStatusText.Text = $"已保存 {Path.GetFileName(path)}";
        });
    }

    private async void ParameterBox_SelectionChanged(
        object sender,
        SelectionChangedEventArgs e)
    {
        if (_initializing ||
            !_camera.IsConnected ||
            _operationInProgress ||
            sender is not ComboBox combo ||
            combo.SelectedItem is not ComboBoxItem item)
        {
            return;
        }

        var parameter = combo.Name switch
        {
            nameof(ShutterBox) => "exposureTime",
            nameof(ApertureBox) => "aperture",
            nameof(IsoBox) => "iso",
            nameof(ExposureCompensationBox) => "exposureCompensation",
            nameof(FocusModeBox) => "focusMode",
            nameof(WhiteBalanceBox) => "whiteBalanceMode",
            nameof(PictureControlBox) => "pictureControl",
            _ => string.Empty
        };
        if (string.IsNullOrEmpty(parameter))
        {
            return;
        }
        object value = parameter is
            "exposureTime" or "aperture" or "iso" or "exposureCompensation"
            ? double.Parse(
                Convert.ToString(item.Tag) ?? "0",
                CultureInfo.InvariantCulture)
            : Convert.ToString(item.Tag) ?? string.Empty;

        await RunOperationAsync($"正在设置{item.Content}…", async token =>
        {
            await _camera.SetParameterAsync(parameter, value, token);
            OperationStatusText.Text = $"已设置 {item.Content}";
        });
    }

    private async void ExposureModeBox_SelectionChanged(
        object sender,
        SelectionChangedEventArgs e)
    {
        UpdateExposureAvailability();
        if (_initializing ||
            !_camera.IsConnected ||
            _operationInProgress ||
            ExposureModeBox.SelectedItem is not ComboBoxItem item)
        {
            return;
        }
        var value = Convert.ToString(item.Tag) ?? "manual";
        await RunOperationAsync($"正在切换至 {item.Content}…", async token =>
        {
            await _camera.SetParameterAsync("exposureMode", value, token);
            UpdateExposureAvailability();
            OperationStatusText.Text = $"拍摄模式：{item.Content}";
        });
    }

    private void Navigate_Click(object sender, RoutedEventArgs e)
    {
        if (sender is not Button button)
        {
            return;
        }
        SetCurrentNavigation(button);
        var destination = Convert.ToString(button.Tag);
        CapturePanel.Visibility =
            destination is "capture" or "monitor"
                ? Visibility.Visible
                : Visibility.Collapsed;
        LibraryPanel.Visibility =
            destination == "library"
                ? Visibility.Visible
                : Visibility.Collapsed;
        TransferPanel.Visibility =
            destination == "transfer"
                ? Visibility.Visible
                : Visibility.Collapsed;
        var cameraWorkspace = destination is "capture" or "monitor";
        ParameterPanelShell.Visibility =
            cameraWorkspace ? Visibility.Visible : Visibility.Collapsed;
        ParameterColumn.Width =
            cameraWorkspace ? new GridLength(300) : new GridLength(0);
        if (destination == "library")
        {
            RefreshPhotoList();
        }
        PreviewDetailText.Text = destination == "monitor"
            ? "相机原生 JPEG · 监看输出 · 不修改原片"
            : "相机原生 JPEG · 本地预览";
    }

    private async void WirelessButton_Click(object sender, RoutedEventArgs e)
    {
        if (_wirelessServer.IsRunning)
        {
            await _wirelessServer.StopAsync();
            _diagnostics.Info("wireless", "无线收件箱已停止");
            WirelessButton.Content = "开启无线接收";
            WirelessAddressText.Text = "—";
            OperationStatusText.Text = "无线收件箱已停止";
            return;
        }
        try
        {
            await _wirelessServer.StartAsync();
            _diagnostics.Info(
                "wireless",
                $"无线收件箱已开启；地址={_wirelessServer.LocalAddress}:" +
                $"{WirelessFtpServer.Port}");
            WirelessButton.Content = "停止无线接收";
            WirelessAddressText.Text =
                $"{_wirelessServer.LocalAddress}:{WirelessFtpServer.Port}";
            OperationStatusText.Text = "无线收件箱已开启";
        }
        catch (Exception error)
        {
            _diagnostics.Error("wireless", error.Message);
            ShowError($"无法开启无线收件箱：{error.Message}");
        }
    }

    private void OpenLogFolder_Click(object sender, RoutedEventArgs e)
    {
        _diagnostics.Info("diagnostics", "用户打开日志目录");
        _diagnostics.OpenDirectory();
    }

    private void ReportIssue_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            _diagnostics.OpenGitHubIssue();
        }
        catch (Exception error)
        {
            _diagnostics.Error(
                "diagnostics",
                $"无法打开 GitHub Issue 提交页：{error.Message}");
            ShowError("无法打开浏览器，请访问 github.com/Tauber01/NikonLink/issues");
        }
    }

    private void OpenPhotoFolder_Click(object sender, RoutedEventArgs e)
    {
        Process.Start(new ProcessStartInfo
        {
            FileName = _library.DirectoryPath,
            UseShellExecute = true
        });
    }

    private void PhotoList_SelectionChanged(
        object sender,
        SelectionChangedEventArgs e)
    {
        DeletePhotoButton.IsEnabled = PhotoList.SelectedItem is PhotoItem;
        if (PhotoList.SelectedItem is not PhotoItem item)
        {
            return;
        }
        if (Path.GetExtension(item.Path).Equals(
            ".jpg",
            StringComparison.OrdinalIgnoreCase) ||
            Path.GetExtension(item.Path).Equals(
                ".jpeg",
                StringComparison.OrdinalIgnoreCase))
        {
            try
            {
                var bytes = File.ReadAllBytes(item.Path);
                DisplayJpeg(bytes);
            }
            catch
            {
            }
        }
    }

    private void DeletePhotoButton_Click(object sender, RoutedEventArgs e)
    {
        if (PhotoList.SelectedItem is not PhotoItem item)
        {
            return;
        }
        try
        {
            File.Delete(item.Path);
            RefreshPhotoList();
            OperationStatusText.Text = $"已删除 {item.Name}";
        }
        catch (Exception error)
        {
            ShowError($"无法删除 {item.Name}：{error.Message}");
        }
    }

    private void StartPreviewLoop()
    {
        _previewCancellation?.Cancel();
        _previewCancellation?.Dispose();
        _previewCancellation = new CancellationTokenSource();
        _previewTask = PreviewLoopAsync(_previewCancellation.Token);
    }

    private async Task PreviewLoopAsync(CancellationToken cancellationToken)
    {
        while (!cancellationToken.IsCancellationRequested &&
               _camera.IsConnected &&
               _camera.IsLiveView)
        {
            try
            {
                var jpeg = await _camera.GetLiveViewFrameAsync(cancellationToken);
                await Dispatcher.InvokeAsync(() => DisplayJpeg(jpeg));
            }
            catch (OperationCanceledException)
            {
                break;
            }
            catch (Exception error)
            {
                _diagnostics.Warning(
                    "liveview",
                    $"获取实时取景帧失败，将重试：{error.Message}");
                await Dispatcher.InvokeAsync(() =>
                {
                    OperationStatusText.Text =
                        $"实时取景暂停：{error.Message}";
                });
                await Task.Delay(600, cancellationToken);
            }
        }
    }

    private async Task StopPreviewLoopAsync()
    {
        var cancellation = _previewCancellation;
        var task = _previewTask;
        _previewCancellation = null;
        _previewTask = null;
        cancellation?.Cancel();
        if (task is not null)
        {
            try
            {
                await task;
            }
            catch (OperationCanceledException)
            {
            }
        }
        cancellation?.Dispose();
    }

    private async Task RunOperationAsync(
        string status,
        Func<CancellationToken, Task> operation)
    {
        _operationInProgress = true;
        _diagnostics.Info("operation", status);
        OperationStatusText.Text = status;
        UpdateEnabledState();
        try
        {
            using var cancellation = new CancellationTokenSource(
                TimeSpan.FromMinutes(3));
            await operation(cancellation.Token);
            _diagnostics.Info("operation", $"操作完成：{status}");
        }
        catch (Exception error)
        {
            _diagnostics.Error(
                "operation",
                $"操作失败：{status}；错误={error}");
            OperationStatusText.Text = error.Message;
            ShowError(error.Message);
        }
        finally
        {
            _operationInProgress = false;
            UpdateEnabledState();
            UpdateLiveViewState();
        }
    }

    private void SetConnectionState(CameraProfile? profile)
    {
        CameraStatusText.Text = profile is null
            ? "未连接 · WINDOWS USB/PTP"
            : $"{profile.Name} · USB/PTP";
        ConnectButton.Content = profile is null ? "连接相机" : "断开相机";
        PreviewEmpty.Visibility = profile is null
            ? Visibility.Visible
            : PreviewEmpty.Visibility;
        if (profile is null)
        {
            PreviewImage.Source = null;
            PreviewEmpty.Visibility = Visibility.Visible;
        }
        UpdateEnabledState();
        UpdateLiveViewState();
    }

    private void UpdateEnabledState()
    {
        var connected = _camera.IsConnected && !_operationInProgress;
        ConnectButton.IsEnabled = !_operationInProgress;
        LiveViewButton.IsEnabled = connected;
        ShutterButton.IsEnabled = connected;
        ExposureModeBox.IsEnabled = connected;
        FocusModeBox.IsEnabled = connected;
        WhiteBalanceBox.IsEnabled = connected;
        PictureControlBox.IsEnabled = connected;
        UpdateExposureAvailability();
    }

    private void UpdateExposureAvailability()
    {
        var connected = _camera.IsConnected && !_operationInProgress;
        var mode = ExposureModeBox.SelectedItem is ComboBoxItem item
            ? Convert.ToString(item.Tag) ?? "manual"
            : "manual";
        ShutterBox.IsEnabled =
            connected && (mode is "manual" or "shutterPriority");
        ApertureBox.IsEnabled =
            connected && (mode is "manual" or "aperturePriority" or "bulb");
        IsoBox.IsEnabled = connected;
        ExposureCompensationBox.IsEnabled =
            connected &&
            (mode is "program" or "aperturePriority" or "shutterPriority");
    }

    private void UpdateLiveViewState()
    {
        var live = _camera.IsLiveView;
        LiveViewButton.Content = live ? "停止取景" : "开启取景";
        LiveBadge.Text = live ? "LIVE VIEW ON" : "LIVE VIEW OFF";
        LiveBadge.Foreground = live
            ? (Brush)FindResource("AccentInkBrush")
            : (Brush)FindResource("GraphiteMutedBrush");
    }

    private void DisplayJpeg(byte[] jpeg)
    {
        using var stream = new MemoryStream(jpeg, writable: false);
        var bitmap = new BitmapImage();
        bitmap.BeginInit();
        bitmap.CacheOption = BitmapCacheOption.OnLoad;
        bitmap.StreamSource = stream;
        bitmap.EndInit();
        bitmap.Freeze();
        PreviewImage.Source = bitmap;
        PreviewEmpty.Visibility = Visibility.Collapsed;
    }

    private void RefreshPhotoList()
    {
        var items = _library.List();
        _photos.Clear();
        foreach (var item in items)
        {
            _photos.Add(item);
        }
        PhotoCountText.Text = $"{items.Count} 张照片";
        DeletePhotoButton.IsEnabled = false;
    }

    private void SetCurrentNavigation(Button current)
    {
        foreach (var button in new[]
                 {
                     CaptureNav,
                     MonitorNav,
                     LibraryNav,
                     TransferNav
                 })
        {
            button.Background = button == current
                ? (Brush)FindResource("AccentSoftBrush")
                : Brushes.Transparent;
            button.Foreground = button == current
                ? (Brush)FindResource("AccentBrush")
                : (Brush)FindResource("InkBrush");
            button.FontWeight = button == current
                ? FontWeights.Bold
                : FontWeights.Normal;
        }
    }

    private static void ShowError(string message)
    {
        DiagnosticLogger.Shared.Error("ui", message);
        MessageBox.Show(
            message,
            "Nikon Link",
            MessageBoxButton.OK,
            MessageBoxImage.Warning);
    }

    private async void Window_Closing(
        object? sender,
        System.ComponentModel.CancelEventArgs e)
    {
        if (_shutdownStarted)
        {
            return;
        }

        e.Cancel = true;
        _shutdownStarted = true;
        Closing -= Window_Closing;
        try
        {
            await StopPreviewLoopAsync();
            await _wirelessServer.DisposeAsync();
            if (_camera.IsConnected)
            {
                await _camera.DisconnectAsync();
            }
            _camera.Dispose();
        }
        catch
        {
        }
        Close();
    }
}
