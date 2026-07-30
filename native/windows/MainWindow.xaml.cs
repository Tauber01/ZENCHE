using NikonLink.Windows.Models;
using NikonLink.Windows.Services;
using Microsoft.Win32;
using System.Collections.ObjectModel;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Data;
#if NIKONLINK_WINDOWS_SHARE
using Windows.ApplicationModel.DataTransfer;
using Windows.Storage;
#endif

namespace NikonLink.Windows;

public partial class MainWindow : Window
{
    private static readonly string AnnouncementStatePath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "NikonLink",
        "dismissed-announcement-version.txt");
    private readonly PtpCamera _camera = new();
    private readonly PhotoLibrary _library = new();
    private readonly WirelessTransferServer _wirelessServer;
    private readonly DiagnosticLogger _diagnostics = DiagnosticLogger.Shared;
    private readonly UpdateService _updateService = new();
    private readonly ObservableCollection<PhotoItem> _photos = [];
    private CancellationTokenSource? _previewCancellation;
    private Task? _previewTask;
    private bool _operationInProgress;
    private bool _initializing = true;
    private bool _shutdownStarted;
    private bool _configuringVideoControls;
    private bool _videoMode;
    private bool _videoRecording;
    private double _videoFrameRate = 30;
    private double _videoShutterAngle = 180;
    private double _photoShutterSeconds = 0.008;
    private string? _availableUpdateUrl;
    private bool _checkingForUpdates;
    private bool _announcementShownThisLaunch;
    private Window? _immersivePreviewWindow;
    private Image? _immersivePreviewImage;
    private Button? _immersiveRecordButton;
#if NIKONLINK_WINDOWS_SHARE
    private DataTransferManager? _dataTransferManager;
#endif
    private string? _sharePhotoPath;

    public MainWindow()
    {
        InitializeComponent();
        _wirelessServer = new WirelessTransferServer(_library);
        _wirelessServer.StatusChanged += (_, status) =>
            Dispatcher.Invoke(() =>
            {
                _diagnostics.Info("wireless", status);
                WirelessStatusText.Text = AppLocalization.T(status);
                OperationStatusText.Text = AppLocalization.T(status);
            });
        _wirelessServer.FileReceived += (_, path) =>
            Dispatcher.Invoke(() =>
            {
                _diagnostics.Info(
                    "wireless",
                    $"已接收文件；名称={Path.GetFileName(path)}");
                OperationStatusText.Text = AppLocalization.T(
                    $"已接收 {Path.GetFileName(path)}");
                RefreshPhotoList();
            });
        _wirelessServer.Failed += (_, error) =>
            Dispatcher.Invoke(() =>
            {
                _diagnostics.Error("wireless", error.ToString());
                WirelessStatusText.Text = AppLocalization.T(
                    $"无线接收失败：{error.Message}");
                WirelessButton.Content =
                    AppLocalization.T("开启无线接收");
                ShowError(error.Message);
            });
        var fileHierarchy = new ListCollectionView(_photos);
        fileHierarchy.GroupDescriptions.Add(
            new PropertyGroupDescription(nameof(PhotoItem.SourceGroup)));
        fileHierarchy.GroupDescriptions.Add(
            new PropertyGroupDescription(nameof(PhotoItem.MediaTypeGroup)));
        PhotoList.ItemsSource = fileHierarchy;
        DiagnosticLogPathText.Text = AppLocalization.T(
            "按日写入、5 MB 滚动、保留 14 天\n") +
            _diagnostics.DirectoryPath;
        CurrentVersionText.Text = AppLocalization.T(
            $"当前版本 {_updateService.CurrentVersion} · 从 GitHub Releases 检查新版本");
        ConfigureFineExposureControls();
        ConfigureShutterControl(false);
        RefreshPhotoList();
        SetCurrentNavigation(CaptureNav);
        LanguageBox.SelectedIndex = AppLocalization.Current switch
        {
            InterfaceLanguage.English => 1,
            InterfaceLanguage.Japanese => 2,
            _ => 0
        };
        AppLocalization.Apply(this);
        _initializing = false;
        Closing += Window_Closing;
        Loaded += MainWindow_Loaded;
    }

    private async void MainWindow_Loaded(object sender, RoutedEventArgs e)
    {
#if NIKONLINK_WINDOWS_SHARE
        try
        {
            var handle = new WindowInteropHelper(this).Handle;
            _dataTransferManager =
                DataTransferManagerHelper.GetForWindow(handle);
            _dataTransferManager.DataRequested += Share_DataRequested;
        }
        catch (Exception error)
        {
            _diagnostics.Warning(
                "share",
                $"Windows 分享面板初始化失败：{error.Message}");
        }
#endif
        ShowLaunchAnnouncementIfNeeded();
        await CheckForUpdatesAsync(silent: true);
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
                OperationStatusText.Text =
                    AppLocalization.T("相机已断开");
            });
            return;
        }

        await RunOperationAsync("正在连接 Nikon 相机…", async token =>
        {
            var profile = await _camera.ConnectAsync(token);
            SetConnectionState(profile);
            OperationStatusText.Text =
                AppLocalization.T($"{profile.Name} 已连接");
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

    private void FullscreenPreviewButton_Click(
        object sender,
        RoutedEventArgs e)
    {
        if (_immersivePreviewWindow is not null)
        {
            _immersivePreviewWindow.Activate();
            return;
        }
        var viewer = new Window
        {
            Title = _videoMode
                ? "帧澈 ZENCHE · 视频全屏监看"
                : "帧澈 ZENCHE · 照片全屏取景",
            WindowStyle = WindowStyle.None,
            WindowState = WindowState.Maximized,
            ResizeMode = ResizeMode.NoResize,
            Background = Brushes.Black
        };
        _immersivePreviewWindow = viewer;
        var root = new Grid
        {
            Background = Brushes.Black
        };
        var preview = new Image
        {
            Source = PreviewImage.Source,
            Stretch = Stretch.Uniform
        };
        _immersivePreviewImage = preview;
        root.Children.Add(preview);

        var top = new DockPanel
        {
            Margin = new Thickness(20),
            VerticalAlignment = VerticalAlignment.Top
        };
        var close = new Button
        {
            Content = "⌄ 退出全屏",
            Width = 126,
            Height = 44,
            Style = (Style)FindResource("ButtonBase")
        };
        close.Click += (_, _) => CloseImmersivePreview(viewer);
        DockPanel.SetDock(close, Dock.Left);
        top.Children.Add(close);
        var status = new TextBlock
        {
            Text =
                $"{(_camera.IsLiveView ? "● LIVE" : "● NO SOURCE")} · " +
                $"{_camera.Profile?.Name ?? "Nikon 相机"} · USB/PTP",
            Foreground = Brushes.White,
            FontFamily = (FontFamily)FindResource("MonoFont"),
            FontWeight = FontWeights.SemiBold,
            VerticalAlignment = VerticalAlignment.Center,
            HorizontalAlignment = HorizontalAlignment.Center,
            Background = new SolidColorBrush(Color.FromArgb(150, 0, 0, 0)),
            Padding = new Thickness(14, 8, 14, 8)
        };
        top.Children.Add(status);
        root.Children.Add(top);

        var leftRail = new StackPanel
        {
            Width = 76,
            Margin = new Thickness(20, 0, 0, 0),
            VerticalAlignment = VerticalAlignment.Center,
            HorizontalAlignment = HorizontalAlignment.Left
        };
        leftRail.Children.Add(ImmersiveReadout(
            _videoMode ? $"{_videoFrameRate:0}P" : ExposureModeText()));
        leftRail.Children.Add(ImmersiveReadout("USB\nPTP"));
        root.Children.Add(leftRail);

        var rightRail = new StackPanel
        {
            Width = 112,
            Margin = new Thickness(0, 0, 20, 0),
            VerticalAlignment = VerticalAlignment.Center,
            HorizontalAlignment = HorizontalAlignment.Right
        };
        rightRail.Children.Add(new TextBlock
        {
            Text = _videoMode ? "视频" : "照片",
            Foreground = _videoMode
                ? (Brush)FindResource("VideoBrush")
                : (Brush)FindResource("AccentBrush"),
            FontSize = 18,
            FontWeight = FontWeights.Bold,
            TextAlignment = TextAlignment.Center,
            Margin = new Thickness(0, 0, 0, 12)
        });
        var capture = new Button
        {
            Content = _videoMode
                ? (_videoRecording ? "■\n停止" : "●\n录制")
                : "●\n拍摄",
            Width = 96,
            Height = 96,
            Foreground = Brushes.White,
            FontSize = 16,
            FontWeight = FontWeights.Bold,
            Style = (Style)FindResource(
                _videoMode ? "DangerButton" : "PrimaryButton"),
            IsEnabled = _camera.IsConnected
        };
        capture.Click += ShutterButton_Click;
        if (_videoMode)
        {
            _immersiveRecordButton = capture;
        }
        rightRail.Children.Add(capture);
        root.Children.Add(rightRail);

        var exposure = new TextBlock
        {
            Text = _videoMode
                ? $"{_videoShutterAngle:0.#}°   {_videoFrameRate:0} fps   JPEG"
                : $"{ExposureModeText()}   JPEG   帧澈 ZENCHE",
            Foreground = Brushes.White,
            FontFamily = (FontFamily)FindResource("MonoFont"),
            FontWeight = FontWeights.SemiBold,
            Background = new SolidColorBrush(Color.FromArgb(155, 0, 0, 0)),
            Padding = new Thickness(18, 10, 18, 10),
            Margin = new Thickness(0, 0, 0, 24),
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Bottom
        };
        root.Children.Add(exposure);

        var parameterBar = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            HorizontalAlignment = HorizontalAlignment.Left
        };
        parameterBar.Children.Add(
            ImmersiveParameterControl("拍摄模式", ExposureModeBox));
        parameterBar.Children.Add(
            ImmersiveParameterControl(
                _videoMode ? "快门角度" : "快门",
                ShutterBox));
        parameterBar.Children.Add(
            ImmersiveParameterControl(
                _videoMode ? "视频帧率" : "光圈",
                _videoMode ? VideoFrameRateBox : ApertureBox));
        parameterBar.Children.Add(
            ImmersiveParameterControl("ISO", IsoBox));
        parameterBar.Children.Add(
            ImmersiveParameterControl("曝光补偿", ExposureCompensationBox));
        parameterBar.Children.Add(
            ImmersiveParameterControl("对焦", FocusModeBox));
        parameterBar.Children.Add(
            ImmersiveParameterControl("白平衡", WhiteBalanceBox));
        parameterBar.Children.Add(
            ImmersiveParameterControl("优化校准", PictureControlBox));
        var parameterScroller = new ScrollViewer
        {
            Content = parameterBar,
            HorizontalScrollBarVisibility = ScrollBarVisibility.Auto,
            VerticalScrollBarVisibility = ScrollBarVisibility.Disabled
        };
        var parameterTray = new Expander
        {
            Header = "参数",
            IsExpanded = true,
            Content = parameterScroller,
            Foreground = Brushes.White,
            Background = new SolidColorBrush(Color.FromArgb(120, 0, 0, 0)),
            Padding = new Thickness(8),
            Margin = new Thickness(112, 0, 124, 78),
            HorizontalAlignment = HorizontalAlignment.Stretch,
            VerticalAlignment = VerticalAlignment.Bottom
        };
        root.Children.Add(parameterTray);
        viewer.Content = root;
        viewer.KeyDown += (_, args) =>
        {
            if (args.Key == Key.Escape)
            {
                CloseImmersivePreview(viewer);
            }
        };
        viewer.Closed += (_, _) =>
        {
            if (ReferenceEquals(_immersivePreviewWindow, viewer))
            {
                _immersivePreviewWindow = null;
                _immersivePreviewImage = null;
                _immersiveRecordButton = null;
            }
        };
        viewer.Show();
    }

    private Border ImmersiveParameterControl(
        string label,
        ComboBox source)
    {
        var value = new TextBlock
        {
            Text = SelectedParameterLabel(source),
            Foreground = Brushes.White,
            FontFamily = (FontFamily)FindResource("MonoFont"),
            FontWeight = FontWeights.SemiBold,
            Width = 104,
            TextAlignment = TextAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center,
            TextTrimming = TextTrimming.CharacterEllipsis
        };
        var minus = new Button
        {
            Content = "−",
            Width = 44,
            Height = 44,
            Style = (Style)FindResource("ButtonBase")
        };
        var plus = new Button
        {
            Content = "+",
            Width = 44,
            Height = 44,
            Style = (Style)FindResource("ButtonBase")
        };
        minus.Click += (_, _) => AdjustParameterSelection(source, -1, value);
        plus.Click += (_, _) => AdjustParameterSelection(source, 1, value);
        minus.IsEnabled = source.IsEnabled;
        plus.IsEnabled = source.IsEnabled;
        var row = new StackPanel
        {
            Orientation = Orientation.Horizontal
        };
        row.Children.Add(minus);
        row.Children.Add(new StackPanel
        {
            Width = 104,
            Children =
            {
                new TextBlock
                {
                    Text = label,
                    Foreground = new SolidColorBrush(
                        Color.FromArgb(170, 255, 255, 255)),
                    FontSize = 10,
                    TextAlignment = TextAlignment.Center
                },
                value
            }
        });
        row.Children.Add(plus);
        var control = new Border
        {
            Background = new SolidColorBrush(Color.FromArgb(165, 0, 0, 0)),
            CornerRadius = new CornerRadius(10),
            Padding = new Thickness(4),
            Margin = new Thickness(4, 0, 4, 0),
            Child = row
        };
        control.Opacity = source.IsEnabled ? 1 : 0.48;
        control.ToolTip = source.IsEnabled
            ? label
            : source.ToolTip ?? $"{label}当前不可调整";
        return control;
    }

    private static string SelectedParameterLabel(ComboBox source)
    {
        if (source.SelectedItem is not ComboBoxItem item)
        {
            return "—";
        }
        return Convert.ToString(item.Content) ?? "—";
    }

    private static void AdjustParameterSelection(
        ComboBox source,
        int direction,
        TextBlock value)
    {
        if (!source.IsEnabled || source.Items.Count == 0)
        {
            return;
        }
        source.SelectedIndex = Math.Clamp(
            source.SelectedIndex + direction,
            0,
            source.Items.Count - 1);
        value.Text = SelectedParameterLabel(source);
    }

    private void CloseImmersivePreview(Window viewer)
    {
        if (!ReferenceEquals(_immersivePreviewWindow, viewer))
        {
            return;
        }
        _immersivePreviewImage = null;
        _immersiveRecordButton = null;
        _immersivePreviewWindow = null;
        viewer.Dispatcher.BeginInvoke(viewer.Close);
    }

    private Border ImmersiveReadout(string value)
    {
        return new Border
        {
            Background = new SolidColorBrush(Color.FromArgb(155, 0, 0, 0)),
            CornerRadius = new CornerRadius(10),
            Margin = new Thickness(0, 0, 0, 12),
            Padding = new Thickness(8),
            Height = 58,
            Child = new TextBlock
            {
                Text = value,
                Foreground = Brushes.White,
                FontWeight = FontWeights.Bold,
                TextAlignment = TextAlignment.Center,
                VerticalAlignment = VerticalAlignment.Center
            }
        };
    }

    private string ExposureModeText()
    {
        return ExposureModeBox.SelectedItem is ComboBoxItem item
            ? (Convert.ToString(item.Tag) switch
            {
                "program" => "P",
                "shutterPriority" => "S",
                "aperturePriority" => "A",
                "bulb" => "B",
                _ => "M"
            })
            : "M";
    }

    private async void ShutterButton_Click(object sender, RoutedEventArgs e)
    {
        if (_operationInProgress || !_camera.IsConnected)
        {
            return;
        }
        if (_videoMode)
        {
            await ToggleMovieRecordingAsync();
            return;
        }
        await RunOperationAsync("正在拍摄并下载 JPEG…", async token =>
        {
            var jpeg = await _camera.CaptureAsync(token);
            var path = await _library.SaveCaptureAsync(jpeg, token);
            DisplayJpeg(jpeg);
            RefreshPhotoList();
            OperationStatusText.Text = AppLocalization.T(
                $"已保存 {Path.GetFileName(path)}");
        });
    }

    private async Task ToggleMovieRecordingAsync()
    {
        await RunOperationAsync(
            _videoRecording ? "正在停止视频录制…" : "正在开始视频录制…",
            async token =>
            {
                if (_videoRecording)
                {
                    await _camera.StopMovieRecordingAsync(token);
                }
                else
                {
                    await _camera.StartMovieRecordingAsync(token);
                }
                _videoRecording = _camera.IsMovieRecording;
                OperationStatusText.Text = AppLocalization.T(
                    _videoRecording
                        ? "● REC · 视频正在录制到相机存储卡"
                        : "录制已停止 · 视频保存在相机存储卡");
            });
        UpdateRecordingState();
    }

    private void UpdateRecordingState()
    {
        if (_videoMode)
        {
            ShutterButton.Content = AppLocalization.T(
                _videoRecording ? "停止录制" : "开始录制");
        }
        if (_immersiveRecordButton is not null)
        {
            _immersiveRecordButton.Content = AppLocalization.T(
                _videoRecording ? "■\n停止" : "●\n录制");
        }
    }

    private async void ParameterBox_SelectionChanged(
        object sender,
        SelectionChangedEventArgs e)
    {
        if (_initializing ||
            _configuringVideoControls ||
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
        if (combo == ShutterBox)
        {
            if (_videoMode &&
                double.TryParse(
                    item.Uid,
                    NumberStyles.Float,
                    CultureInfo.InvariantCulture,
                    out var angle))
            {
                _videoShutterAngle = angle;
            }
            else if (!_videoMode &&
                     double.TryParse(
                         Convert.ToString(item.Tag),
                         NumberStyles.Float,
                         CultureInfo.InvariantCulture,
                         out var seconds))
            {
                _photoShutterSeconds = seconds;
            }
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
            OperationStatusText.Text =
                AppLocalization.T($"已设置 {item.Content}");
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
            OperationStatusText.Text =
                AppLocalization.T($"拍摄模式：{item.Content}");
        });
    }

    private void Navigate_Click(object sender, RoutedEventArgs e)
    {
        if (sender is not Button button)
        {
            return;
        }
        var destination = Convert.ToString(button.Tag);
        ShowDestination(button, destination);
    }

    private void SettingsButton_Click(object sender, RoutedEventArgs e)
    {
        ShowDestination(null, "settings");
    }

    private void LanguageBox_SelectionChanged(
        object sender,
        SelectionChangedEventArgs e)
    {
        if (_initializing ||
            LanguageBox.SelectedItem is not ComboBoxItem item)
        {
            return;
        }
        var language = Convert.ToString(item.Tag) switch
        {
            "en" => InterfaceLanguage.English,
            "ja" => InterfaceLanguage.Japanese,
            _ => InterfaceLanguage.SimplifiedChinese
        };
        AppLocalization.SetLanguage(language);
        AppLocalization.Apply(this);
    }

    private void ShowDestination(Button? navigation, string? destination)
    {
        SetCurrentNavigation(navigation);
        CapturePanel.Visibility =
            destination is "capture" or "monitor"
                ? Visibility.Visible
                : Visibility.Collapsed;
        LibraryPanel.Visibility =
            destination == "library"
                ? Visibility.Visible
                : Visibility.Collapsed;
        SettingsPanel.Visibility =
            destination == "settings"
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
        PreviewDetailText.Text = AppLocalization.T(
            destination == "monitor"
                ? "相机原生 JPEG · 监看输出 · 不修改原片"
                : "相机原生 JPEG · 本地预览");
        ConfigureShutterControl(destination == "monitor");
        ShutterButton.Content = AppLocalization.T(
            destination == "monitor"
                ? (_videoRecording ? "停止录制" : "开始录制")
                : "拍摄照片");
    }

    private async void VideoFrameRateBox_SelectionChanged(
        object sender,
        SelectionChangedEventArgs e)
    {
        if (_initializing ||
            _configuringVideoControls ||
            VideoFrameRateBox.SelectedItem is not ComboBoxItem item ||
            !double.TryParse(
                Convert.ToString(item.Tag),
                NumberStyles.Float,
                CultureInfo.InvariantCulture,
                out var frameRate))
        {
            return;
        }
        _videoFrameRate = frameRate;
        if (!_videoMode)
        {
            return;
        }
        ConfigureShutterControl(true);
        if (!_camera.IsConnected || _operationInProgress)
        {
            OperationStatusText.Text = AppLocalization.T(
                $"视频曝光参考：{_videoShutterAngle:g}° · {_videoFrameRate:g} fps");
            return;
        }
        var seconds = _videoShutterAngle / (360 * _videoFrameRate);
        await RunOperationAsync(
            $"正在按 {_videoShutterAngle:g}° 换算曝光时间…",
            async token =>
            {
                await _camera.SetParameterAsync(
                    "exposureTime",
                    seconds,
                    token);
                OperationStatusText.Text = AppLocalization.T(
                    $"快门角度 {_videoShutterAngle:g}° · {_videoFrameRate:g} fps");
            });
    }

    private void ConfigureShutterControl(bool videoMode)
    {
        _videoMode = videoMode;
        _configuringVideoControls = true;
        try
        {
            ParameterPanelTitle.Text = AppLocalization.T(
                videoMode ? "视频曝光三要素与参数" : "照片曝光与参数");
            VideoFrameRateLabel.Visibility =
                videoMode ? Visibility.Visible : Visibility.Collapsed;
            VideoFrameRateBox.Visibility =
                videoMode ? Visibility.Visible : Visibility.Collapsed;
            ShutterLabel.Text = AppLocalization.T(
                videoMode ? "快门角度" : "快门速度");
            ShutterBox.Items.Clear();
            if (videoMode)
            {
                foreach (var angle in new[]
                         {
                             45.0,
                             60.0,
                             72.0,
                             90.0,
                             108.0,
                             120.0,
                             144.0,
                             150.0,
                             172.8,
                             180.0,
                             216.0,
                             240.0,
                             270.0,
                             300.0,
                             324.0,
                             360.0
                         })
                {
                    var seconds = angle / (360 * _videoFrameRate);
                    var denominator = Math.Round(1 / seconds);
                    var option = new ComboBoxItem
                    {
                        Tag = seconds.ToString(
                            "G17",
                            CultureInfo.InvariantCulture),
                        Uid = angle.ToString(
                            "G",
                            CultureInfo.InvariantCulture),
                        Content = $"{angle:g}° · 约 1/{denominator:g} s"
                    };
                    ShutterBox.Items.Add(option);
                    if (Math.Abs(angle - _videoShutterAngle) < 0.01)
                    {
                        ShutterBox.SelectedItem = option;
                    }
                }
            }
            else
            {
                foreach (var seconds in FineShutterValues())
                {
                    var label = seconds < 1
                        ? $"1/{Math.Round(1 / seconds):g} s"
                        : $"{seconds:g} s";
                    var item = new ComboBoxItem
                    {
                        Tag = seconds.ToString(
                            "G17",
                            CultureInfo.InvariantCulture),
                        Content = label
                    };
                    ShutterBox.Items.Add(item);
                    if (Math.Abs(seconds - _photoShutterSeconds) < 0.000001)
                    {
                        ShutterBox.SelectedItem = item;
                    }
                }
            }
            if (ShutterBox.SelectedItem is null && ShutterBox.Items.Count > 0)
            {
                ShutterBox.SelectedIndex = 0;
            }
        }
        finally
        {
            _configuringVideoControls = false;
        }
        UpdateExposureAvailability();
    }

    private async void WirelessButton_Click(object sender, RoutedEventArgs e)
    {
        if (_wirelessServer.IsRunning)
        {
            await _wirelessServer.StopAsync();
            _diagnostics.Info("wireless", "无线收件箱已停止");
            WirelessButton.Content =
                AppLocalization.T("开启无线接收");
            WirelessAddressText.Text = "—";
            OperationStatusText.Text =
                AppLocalization.T("无线收件箱已停止");
            return;
        }
        try
        {
            await _wirelessServer.StartAsync();
            _diagnostics.Info(
                "wireless",
                $"无线收件箱已开启；FTP={_wirelessServer.LocalAddress}:" +
                $"{WirelessTransferServer.FtpPort}；HTTP/WebDAV=" +
                $"{_wirelessServer.LocalAddress}:{WirelessTransferServer.HttpPort}");
            WirelessButton.Content =
                AppLocalization.T("停止无线接收");
            WirelessAddressText.Text =
                $"FTP/PASV  {_wirelessServer.LocalAddress}:" +
                $"{WirelessTransferServer.FtpPort}\n" +
                $"HTTP 上传  http://{_wirelessServer.LocalAddress}:" +
                $"{WirelessTransferServer.HttpPort}/upload/文件名\n" +
                $"WebDAV  http://{_wirelessServer.LocalAddress}:" +
                $"{WirelessTransferServer.HttpPort}/";
            OperationStatusText.Text =
                AppLocalization.T("无线收件箱已开启");
        }
        catch (Exception error)
        {
            _diagnostics.Error("wireless", error.Message);
            ShowError($"无法开启无线收件箱：{error.Message}");
        }
    }

    private void ConfigureFineExposureControls()
    {
        PopulateNumericOptions(
            ApertureBox,
            [
                1.2, 1.4, 1.6, 1.8, 2, 2.2, 2.5, 2.8, 3.2, 3.5,
                4, 4.5, 5, 5.6, 6.3, 7.1, 8, 9, 10, 11, 13, 14,
                16, 18, 20, 22
            ],
            4,
            value => $"f/{value:g}");
        PopulateNumericOptions(
            IsoBox,
            [
                64, 80, 100, 125, 160, 200, 250, 320, 400, 500, 640,
                800, 1000, 1250, 1600, 2000, 2500, 3200, 4000, 5000,
                6400, 8000, 10000, 12800, 16000, 20000, 25600, 32000,
                40000, 51200, 64000, 80000, 102400
            ],
            400,
            value => $"ISO {value:g}");
        PopulateNumericOptions(
            ExposureCompensationBox,
            Enumerable.Range(-15, 31).Select(value => value / 3.0),
            0,
            value => $"{value:+0.0;-0.0;0.0} EV");
    }

    private static void PopulateNumericOptions(
        ComboBox box,
        IEnumerable<double> values,
        double selected,
        Func<double, string> label)
    {
        box.Items.Clear();
        foreach (var value in values)
        {
            var item = new ComboBoxItem
            {
                Tag = value.ToString("G17", CultureInfo.InvariantCulture),
                Content = label(value)
            };
            box.Items.Add(item);
            if (Math.Abs(value - selected) < 0.000001)
            {
                box.SelectedItem = item;
            }
        }
    }

    private static double[] FineShutterValues() =>
    [
        1.0 / 8000, 1.0 / 6400, 1.0 / 5000, 1.0 / 4000,
        1.0 / 3200, 1.0 / 2500, 1.0 / 2000, 1.0 / 1600,
        1.0 / 1250, 1.0 / 1000, 1.0 / 800, 1.0 / 640,
        1.0 / 500, 1.0 / 400, 1.0 / 320, 1.0 / 250,
        1.0 / 200, 1.0 / 160, 1.0 / 125, 1.0 / 100,
        1.0 / 80, 1.0 / 60, 1.0 / 50, 1.0 / 40,
        1.0 / 30, 1.0 / 25, 1.0 / 20, 1.0 / 15,
        1.0 / 13, 1.0 / 10, 1.0 / 8, 1.0 / 6,
        1.0 / 5, 1.0 / 4, 1.0 / 3, 1.0 / 2,
        1, 1.3, 1.6, 2, 2.5, 3.2, 4, 5, 6, 8,
        10, 13, 15, 20, 25, 30
    ];

    private void OpenLogFolder_Click(object sender, RoutedEventArgs e)
    {
        _diagnostics.Info("diagnostics", "用户打开日志目录");
        _diagnostics.OpenDirectory();
    }

    private async void CheckUpdateButton_Click(
        object sender,
        RoutedEventArgs e)
    {
        await CheckForUpdatesAsync(silent: false);
    }

    private async Task CheckForUpdatesAsync(bool silent)
    {
        if (_checkingForUpdates)
        {
            return;
        }
        _checkingForUpdates = true;
        CheckUpdateButton.IsEnabled = false;
        CheckUpdateButton.Content =
            AppLocalization.T("正在检查…");
        if (!silent)
        {
            UpdateStatusText.Text =
                AppLocalization.T("正在检查更新…");
        }
        try
        {
            var update = await _updateService.CheckAsync();
            if (update.IsAvailable)
            {
                _availableUpdateUrl = update.DownloadUrl;
                UpdateStatusText.Text =
                    AppLocalization.T($"发现新版本 {update.Version}");
                OpenUpdateButton.Content =
                    AppLocalization.T($"获取 {update.Version}");
                OpenUpdateButton.Visibility = Visibility.Visible;
            }
            else
            {
                _availableUpdateUrl = null;
                UpdateStatusText.Text =
                    AppLocalization.T("已是最新版本");
                OpenUpdateButton.Visibility = Visibility.Collapsed;
            }
        }
        catch (Exception error)
        {
            _diagnostics.Error("update", $"检查更新失败：{error.Message}");
            if (!silent)
            {
                UpdateStatusText.Text =
                    AppLocalization.T("检查失败，请确认网络后重试");
            }
        }
        finally
        {
            _checkingForUpdates = false;
            CheckUpdateButton.IsEnabled = true;
            CheckUpdateButton.Content =
                AppLocalization.T("检查更新");
        }
    }

    private void OpenUpdateButton_Click(object sender, RoutedEventArgs e)
    {
        var target = _availableUpdateUrl ??
                     "https://github.com/Tauber01/ZENCHE/releases";
        try
        {
            Process.Start(new ProcessStartInfo
            {
                FileName = target,
                UseShellExecute = true
            });
        }
        catch (Exception error)
        {
            _diagnostics.Error("update", $"无法打开更新页：{error.Message}");
            ShowError("无法打开浏览器，请访问 github.com/Tauber01/ZENCHE/releases");
        }
    }

    private void ViewLogs_Click(object sender, RoutedEventArgs e)
    {
        _diagnostics.Info("diagnostics", "用户查询近期日志");
        var viewer = new Window
        {
            Owner = this,
            Title = "帧澈 ZENCHE · 诊断日志查询",
            Width = 820,
            Height = 560,
            MinWidth = 560,
            MinHeight = 360,
            WindowStartupLocation = WindowStartupLocation.CenterOwner,
            Content = new TextBox
            {
                Text = _diagnostics.RecentText(12_000),
                Margin = new Thickness(18),
                FontFamily = new FontFamily("Cascadia Mono, Consolas"),
                FontSize = 12,
                IsReadOnly = true,
                AcceptsReturn = true,
                TextWrapping = TextWrapping.NoWrap,
                HorizontalScrollBarVisibility = ScrollBarVisibility.Auto,
                VerticalScrollBarVisibility = ScrollBarVisibility.Auto
            }
        };
        viewer.ShowDialog();
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
            ShowError("无法打开浏览器，请访问 github.com/Tauber01/ZENCHE/issues");
        }
    }

    private void DonationButton_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            var image = new BitmapImage(
                new Uri(
                    "pack://application:,,,/Assets/wechat-donation.png",
                    UriKind.Absolute));
            var dialog = new Window
            {
                Owner = this,
                Title = "请作者喝奶茶",
                Width = 500,
                Height = 700,
                MinWidth = 360,
                MinHeight = 520,
                WindowStartupLocation = WindowStartupLocation.CenterOwner,
                Content = new Image
                {
                    Source = image,
                    Margin = new Thickness(24),
                    Stretch = Stretch.Uniform
                }
            };
            dialog.ShowDialog();
        }
        catch (Exception error)
        {
            _diagnostics.Error(
                "support",
                $"无法显示赞助二维码：{error.Message}");
            ShowError("无法显示赞助二维码，请稍后重试。");
        }
    }

    private void ShowLaunchAnnouncementIfNeeded()
    {
        if (_announcementShownThisLaunch)
        {
            return;
        }
        _announcementShownThisLaunch = true;
        var version = _updateService.CurrentVersion;
        try
        {
            if (File.Exists(AnnouncementStatePath) &&
                string.Equals(
                    File.ReadAllText(AnnouncementStatePath).Trim(),
                    version,
                    StringComparison.Ordinal))
            {
                return;
            }
        }
        catch (Exception error)
        {
            _diagnostics.Warning(
                "announcement",
                $"读取公告提醒设置失败：{error.Message}");
        }

        var doNotRemind = new CheckBox
        {
            Content = AppLocalization.T(
                "不再提醒（软件更新后仍会显示）"),
            FontSize = 14,
            VerticalContentAlignment = VerticalAlignment.Center
        };
        var closeButton = new Button
        {
            Content = AppLocalization.T("关闭公告"),
            MinWidth = 110,
            Height = 38,
            Padding = new Thickness(14, 0, 14, 0)
        };
        var footer = new DockPanel
        {
            Margin = new Thickness(0, 16, 0, 0)
        };
        DockPanel.SetDock(closeButton, Dock.Right);
        footer.Children.Add(closeButton);
        footer.Children.Add(doNotRemind);

        var body = new StackPanel();
        body.Children.Add(new TextBlock
        {
            Text = AppLocalization.T("本次更新"),
            FontSize = 19,
            FontWeight = FontWeights.Bold,
            Margin = new Thickness(0, 0, 0, 8)
        });
        body.Children.Add(new TextBlock
        {
            Text = AppLocalization.T(
                "• 新增启动更新公告，并支持按版本控制提醒。\n" +
                "• 五端公告与赞助入口保持一致。\n" +
                "• 更新赞助图片并优化多语言体验。"),
            FontSize = 14,
            TextWrapping = TextWrapping.Wrap,
            LineHeight = 22,
            Margin = new Thickness(0, 0, 0, 18)
        });

        var warning = new StackPanel
        {
            Margin = new Thickness(0),
        };
        warning.Children.Add(new TextBlock
        {
            Text = AppLocalization.T("谨防诈骗"),
            FontSize = 17,
            FontWeight = FontWeights.Bold,
            Foreground = new SolidColorBrush(
                System.Windows.Media.Color.FromRgb(178, 25, 35)),
            Margin = new Thickness(0, 0, 0, 7)
        });
        warning.Children.Add(new TextBlock
        {
            Text = AppLocalization.T(
                "帧澈 ZENCHE 是开源免费项目。任何声称“进群领取软件”" +
                "或要求付费购买软件的人都是骗子，请勿转账。"),
            FontSize = 14,
            FontWeight = FontWeights.SemiBold,
            Foreground = new SolidColorBrush(
                System.Windows.Media.Color.FromRgb(117, 20, 28)),
            TextWrapping = TextWrapping.Wrap,
            LineHeight = 21
        });
        body.Children.Add(new Border
        {
            Background = new SolidColorBrush(
                System.Windows.Media.Color.FromRgb(255, 238, 238)),
            BorderBrush = new SolidColorBrush(
                System.Windows.Media.Color.FromRgb(244, 185, 185)),
            BorderThickness = new Thickness(1),
            CornerRadius = new CornerRadius(12),
            Padding = new Thickness(16),
            Margin = new Thickness(0, 0, 0, 18),
            Child = warning
        });

        body.Children.Add(new TextBlock
        {
            Text = AppLocalization.T("自愿赞助"),
            FontSize = 17,
            FontWeight = FontWeights.Bold,
            Margin = new Thickness(0, 0, 0, 6)
        });
        body.Children.Add(new TextBlock
        {
            Text = AppLocalization.T(
                "如果本项目对你有帮助，欢迎自愿打赏；软件功能永久免费。"),
            FontSize = 13,
            Foreground = (Brush)FindResource("MutedBrush"),
            TextWrapping = TextWrapping.Wrap,
            Margin = new Thickness(0, 0, 0, 10)
        });
        body.Children.Add(new Image
        {
            Source = new BitmapImage(
                new Uri(
                    "pack://application:,,,/Assets/wechat-donation.png",
                    UriKind.Absolute)),
            MaxHeight = 470,
            Stretch = Stretch.Uniform,
            HorizontalAlignment = HorizontalAlignment.Center
        });

        var header = new StackPanel
        {
            Margin = new Thickness(0, 0, 0, 14)
        };
        header.Children.Add(new TextBlock
        {
            Text = AppLocalization.T("更新公告"),
            FontSize = 25,
            FontWeight = FontWeights.Bold
        });
        header.Children.Add(new TextBlock
        {
            Text = $"{AppLocalization.T("当前版本")} {version}",
            FontSize = 12,
            FontFamily = new FontFamily("Consolas"),
            Foreground = (Brush)FindResource("MutedBrush")
        });

        var root = new DockPanel
        {
            Margin = new Thickness(24)
        };
        DockPanel.SetDock(header, Dock.Top);
        DockPanel.SetDock(footer, Dock.Bottom);
        root.Children.Add(header);
        root.Children.Add(footer);
        root.Children.Add(new ScrollViewer
        {
            Content = body,
            VerticalScrollBarVisibility = ScrollBarVisibility.Auto
        });

        var dialog = new Window
        {
            Owner = this,
            Title = AppLocalization.T("更新公告"),
            Width = 660,
            Height = 820,
            MinWidth = 460,
            MinHeight = 620,
            WindowStartupLocation = WindowStartupLocation.CenterOwner,
            Content = root
        };
        closeButton.Click += (_, _) => dialog.Close();
        dialog.Closed += (_, _) =>
        {
            if (doNotRemind.IsChecked != true)
            {
                return;
            }
            try
            {
                Directory.CreateDirectory(
                    Path.GetDirectoryName(AnnouncementStatePath)!);
                File.WriteAllText(AnnouncementStatePath, version);
            }
            catch (Exception error)
            {
                _diagnostics.Warning(
                    "announcement",
                    $"保存公告提醒设置失败：{error.Message}");
            }
        };
        dialog.ShowDialog();
    }

    private void OpenPhotoFolder_Click(object sender, RoutedEventArgs e)
    {
        Process.Start(new ProcessStartInfo
        {
            FileName = _library.DirectoryPath,
            UseShellExecute = true
        });
    }

    private void OpenOwnerAlbum_Click(object sender, RoutedEventArgs e)
    {
        RefreshPhotoList();
        OperationStatusText.Text = AppLocalization.T(
            "已刷新系统相册与 帧澈 ZENCHE 文件库");
    }

    private void LinkCloudDrive_Click(object sender, RoutedEventArgs e)
    {
        ShowCloudDriveGuide();
    }

    private void OpenCloudFilePicker()
    {
        var dialog = new OpenFileDialog
        {
            Title = "从网盘选择照片或视频",
            Filter =
                "照片与视频|*.jpg;*.jpeg;*.png;*.heic;*.heif;*.tif;*.tiff;*.nef;*.nrw;*.mp4;*.mov;*.m4v|" +
                "所有文件|*.*",
            Multiselect = true,
            CheckFileExists = true
        };
        if (dialog.ShowDialog(this) != true)
        {
            return;
        }
        try
        {
            var imported = _library.ImportFiles(dialog.FileNames);
            RefreshPhotoList();
            OperationStatusText.Text = AppLocalization.T(
                imported.Count > 0
                    ? $"已从网盘加入 {imported.Count} 张照片"
                    : "没有可加入文件库的照片");
        }
        catch (Exception error)
        {
            ShowError($"无法从网盘加入照片：{error.Message}");
        }
    }

    private void ShowCloudDriveGuide()
    {
        var guide = new Window
        {
            Owner = this,
            Title = "链接网盘",
            Width = 660,
            Height = 720,
            MinWidth = 560,
            MinHeight = 560,
            Background = (Brush)FindResource("PaperBrush"),
            WindowStartupLocation = WindowStartupLocation.CenterOwner
        };
        var root = new Grid
        {
            Margin = new Thickness(24)
        };
        root.RowDefinitions.Add(new RowDefinition
        {
            Height = GridLength.Auto
        });
        root.RowDefinitions.Add(new RowDefinition
        {
            Height = new GridLength(1, GridUnitType.Star)
        });
        root.RowDefinitions.Add(new RowDefinition
        {
            Height = GridLength.Auto
        });
        var header = new StackPanel();
        header.Children.Add(new TextBlock
        {
            Text = "链接网盘",
            Style = (Style)FindResource("DisplayText")
        });
        header.Children.Add(new TextBlock
        {
            Text =
                "帧澈 ZENCHE 不代管网盘账号或密码。先在对应客户端登录，" +
                "再通过系统文件选择器从下载或同步目录加入媒体。",
            Foreground = (Brush)FindResource("MutedBrush"),
            TextWrapping = TextWrapping.Wrap,
            Margin = new Thickness(0, 6, 0, 16)
        });
        root.Children.Add(header);

        var providers = new StackPanel();
        AddCloudProvider(
            providers,
            "百度网盘",
            "安装客户端后，从下载或同步目录选择。",
            "https://pan.baidu.com/");
        AddCloudProvider(
            providers,
            "阿里云盘",
            "支持 Windows 桌面端；先下载或同步媒体。",
            "https://www.alipan.com/");
        AddCloudProvider(
            providers,
            "腾讯微云",
            "从微云客户端把文件下载到资源管理器。",
            "https://www.weiyun.com/");
        AddCloudProvider(
            providers,
            "夸克网盘",
            "使用桌面客户端下载到本机目录。",
            "https://pan.quark.cn/");
        AddCloudProvider(
            providers,
            "迅雷云盘",
            "通过迅雷客户端下载后从资源管理器选择。",
            "https://pan.xunlei.com/");
        AddCloudProvider(
            providers,
            "115",
            "在“存储”中下载文件后从本机选择。",
            "https://115.com/");
        var scroll = new ScrollViewer
        {
            Content = providers,
            VerticalScrollBarVisibility = ScrollBarVisibility.Auto
        };
        Grid.SetRow(scroll, 1);
        root.Children.Add(scroll);

        var actions = new DockPanel
        {
            Margin = new Thickness(0, 16, 0, 0)
        };
        var close = new Button
        {
            Content = "关闭",
            Width = 96,
            Style = (Style)FindResource("ButtonBase")
        };
        close.Click += (_, _) => guide.Close();
        DockPanel.SetDock(close, Dock.Left);
        actions.Children.Add(close);
        var choose = new Button
        {
            Content = "选择文件并加入",
            Width = 168,
            Style = (Style)FindResource("PrimaryButton")
        };
        choose.Click += (_, _) =>
        {
            guide.Close();
            OpenCloudFilePicker();
        };
        DockPanel.SetDock(choose, Dock.Right);
        actions.Children.Add(choose);
        Grid.SetRow(actions, 2);
        root.Children.Add(actions);
        guide.Content = root;
        guide.ShowDialog();
    }

    private void AddCloudProvider(
        Panel parent,
        string name,
        string note,
        string url)
    {
        var button = new Button
        {
            Content = new StackPanel
            {
                Children =
                {
                    new TextBlock
                    {
                        Text = name + "  ↗",
                        FontWeight = FontWeights.SemiBold
                    },
                    new TextBlock
                    {
                        Text = note,
                        Foreground = (Brush)FindResource("MutedBrush"),
                        TextWrapping = TextWrapping.Wrap,
                        Margin = new Thickness(0, 3, 0, 0)
                    }
                }
            },
            HorizontalContentAlignment = HorizontalAlignment.Left,
            MinHeight = 64,
            Margin = new Thickness(0, 0, 0, 8),
            Style = (Style)FindResource("ButtonBase")
        };
        button.Click += (_, _) => Process.Start(new ProcessStartInfo
        {
            FileName = url,
            UseShellExecute = true
        });
        parent.Children.Add(button);
    }

    private void PhotoList_SelectionChanged(
        object sender,
        SelectionChangedEventArgs e)
    {
        DeletePhotoButton.IsEnabled =
            PhotoList.SelectedItem is PhotoItem { IsLibraryItem: true };
        SharePhotoButton.IsEnabled = PhotoList.SelectedItem is PhotoItem;
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

    private void PhotoList_MouseDoubleClick(
        object sender,
        MouseButtonEventArgs e)
    {
        if (PhotoList.SelectedItem is PhotoItem item)
        {
            ShowLargePhoto(item);
        }
    }

    private void SharePhotoButton_Click(object sender, RoutedEventArgs e)
    {
        if (PhotoList.SelectedItem is PhotoItem item)
        {
            BeginShare(item.Path);
        }
    }

    private void BeginShare(string path)
    {
        _sharePhotoPath = path;
#if NIKONLINK_WINDOWS_SHARE
        try
        {
            var handle = new WindowInteropHelper(this).Handle;
            DataTransferManagerHelper.ShowShareUIForWindow(handle);
        }
        catch (Exception error)
        {
            _diagnostics.Error(
                "share",
                $"无法打开 Windows 分享面板：{error.Message}");
            ShowError($"无法打开 Windows 分享面板：{error.Message}");
        }
#else
        Process.Start(new ProcessStartInfo
        {
            FileName = path,
            UseShellExecute = true
        });
#endif
    }

#if NIKONLINK_WINDOWS_SHARE
    private async void Share_DataRequested(
        DataTransferManager sender,
        DataRequestedEventArgs args)
    {
        var deferral = args.Request.GetDeferral();
        try
        {
            var path = _sharePhotoPath;
            if (string.IsNullOrWhiteSpace(path) || !File.Exists(path))
            {
                args.Request.FailWithDisplayText("请选择要分享的照片。");
                return;
            }
            var file = await StorageFile.GetFileFromPathAsync(path);
            args.Request.Data.Properties.Title = Path.GetFileName(path);
            args.Request.Data.Properties.Description =
                "来自 帧澈 ZENCHE 文件库";
            args.Request.Data.SetStorageItems([file]);
        }
        catch (Exception error)
        {
            _diagnostics.Error("share", $"准备分享照片失败：{error.Message}");
            args.Request.FailWithDisplayText("无法读取所选照片。");
        }
        finally
        {
            deferral.Complete();
        }
    }
#endif

    private void ShowLargePhoto(PhotoItem item)
    {
        if (item.IsVideo)
        {
            ShowLargeVideo(item);
            return;
        }
        try
        {
            var bitmap = new BitmapImage();
            bitmap.BeginInit();
            bitmap.CacheOption = BitmapCacheOption.OnLoad;
            bitmap.UriSource = new Uri(item.Path, UriKind.Absolute);
            bitmap.EndInit();
            bitmap.Freeze();

            var viewer = new Window
            {
                Owner = this,
                Title = item.Name,
                Width = 1100,
                Height = 760,
                MinWidth = 640,
                MinHeight = 480,
                Background = Brushes.Black,
                WindowStartupLocation = WindowStartupLocation.CenterOwner
            };
            var layout = new Grid();
            layout.RowDefinitions.Add(new RowDefinition
            {
                Height = GridLength.Auto
            });
            layout.RowDefinitions.Add(new RowDefinition
            {
                Height = new GridLength(1, GridUnitType.Star)
            });
            var toolbar = new DockPanel
            {
                Margin = new Thickness(16, 12, 16, 12)
            };
            var close = new Button
            {
                Content = "关闭",
                Width = 88,
                Style = (Style)FindResource("ButtonBase")
            };
            close.Click += (_, _) => viewer.Close();
            DockPanel.SetDock(close, Dock.Left);
            toolbar.Children.Add(close);
            var share = new Button
            {
                Content = "分享到社交平台",
                Width = 160,
                Style = (Style)FindResource("PrimaryButton")
            };
            share.Click += (_, _) => BeginShare(item.Path);
            DockPanel.SetDock(share, Dock.Right);
            toolbar.Children.Add(share);
            layout.Children.Add(toolbar);

            var image = new Image
            {
                Source = bitmap,
                Stretch = Stretch.Uniform,
                Margin = new Thickness(12)
            };
            Grid.SetRow(image, 1);
            layout.Children.Add(image);
            viewer.Content = layout;
            viewer.ShowDialog();
        }
        catch (Exception error)
        {
            ShowError(
                "当前格式已安全保存，但系统无法显示这张照片的大图：" +
                error.Message);
        }
    }

    private void ShowLargeVideo(PhotoItem item)
    {
        var viewer = new Window
        {
            Owner = this,
            Title = item.Name,
            Width = 1100,
            Height = 760,
            MinWidth = 640,
            MinHeight = 480,
            Background = Brushes.Black,
            WindowStartupLocation = WindowStartupLocation.CenterOwner
        };
        var root = new Grid();
        var media = new MediaElement
        {
            Source = new Uri(item.Path, UriKind.Absolute),
            LoadedBehavior = MediaState.Manual,
            UnloadedBehavior = MediaState.Stop,
            Stretch = Stretch.Uniform
        };
        root.Children.Add(media);
        var toolbar = new DockPanel
        {
            Margin = new Thickness(16),
            VerticalAlignment = VerticalAlignment.Top
        };
        var close = new Button
        {
            Content = "关闭",
            Width = 88,
            Style = (Style)FindResource("ButtonBase")
        };
        close.Click += (_, _) => viewer.Close();
        DockPanel.SetDock(close, Dock.Left);
        toolbar.Children.Add(close);
        var share = new Button
        {
            Content = "分享到社交平台",
            Width = 160,
            Style = (Style)FindResource("PrimaryButton")
        };
        share.Click += (_, _) => BeginShare(item.Path);
        DockPanel.SetDock(share, Dock.Right);
        toolbar.Children.Add(share);
        root.Children.Add(toolbar);
        viewer.Content = root;
        viewer.Loaded += (_, _) => media.Play();
        viewer.Closed += (_, _) => media.Close();
        viewer.ShowDialog();
    }

    private void DeletePhotoButton_Click(object sender, RoutedEventArgs e)
    {
        if (PhotoList.SelectedItem is not PhotoItem
            {
                IsLibraryItem: true
            } item)
        {
            return;
        }
        try
        {
            File.Delete(item.Path);
            RefreshPhotoList();
            OperationStatusText.Text = AppLocalization.T(
                $"已删除 {item.Name}");
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
        var failures = 0;
        while (!cancellationToken.IsCancellationRequested &&
               _camera.IsConnected &&
               _camera.IsLiveView)
        {
            try
            {
                var jpeg = await _camera.GetLiveViewFrameAsync(cancellationToken);
                failures = 0;
                await Dispatcher.InvokeAsync(() => DisplayJpeg(jpeg));
            }
            catch (OperationCanceledException)
            {
                break;
            }
            catch (Exception error)
            {
                failures++;
                _diagnostics.Warning(
                    "liveview",
                    $"获取实时取景帧失败（{failures}/3）：{error.Message}");
                if (failures >= 3)
                {
                    await _camera.StopLiveViewAsync(CancellationToken.None);
                    await Dispatcher.InvokeAsync(() =>
                    {
                        UpdateLiveViewState();
                        OperationStatusText.Text = AppLocalization.T(
                            "实时取景已安全停止 · 机身控制已释放");
                        ShowError(
                            "连续 3 次未收到实时取景画面，已停止重试并释放相机。");
                    });
                    break;
                }
                await Dispatcher.InvokeAsync(() =>
                {
                    OperationStatusText.Text = AppLocalization.T(
                        $"实时取景正在重试 · {failures}/3");
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
        OperationStatusText.Text = AppLocalization.T(status);
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
            OperationStatusText.Text = AppLocalization.T(error.Message);
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
        CameraStatusText.Text = AppLocalization.T(
            profile is null
                ? "未连接 · WINDOWS USB/PTP"
                : $"{profile.Name} · USB/PTP");
        ConnectButton.Content = AppLocalization.T(
            profile is null ? "连接相机" : "断开相机");
        PreviewEmpty.Visibility = profile is null
            ? Visibility.Visible
            : PreviewEmpty.Visibility;
        if (profile is null)
        {
            _videoRecording = false;
            PreviewImage.Source = null;
            PreviewEmpty.Visibility = Visibility.Visible;
            UpdateRecordingState();
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
        if (_immersiveRecordButton is not null)
        {
            _immersiveRecordButton.IsEnabled = connected;
        }
        ExposureModeBox.IsEnabled = connected;
        FocusModeBox.IsEnabled = connected;
        WhiteBalanceBox.IsEnabled = connected;
        PictureControlBox.IsEnabled = connected;
        UpdateExposureAvailability();
    }

    private void UpdateExposureAvailability()
    {
        var connected = _camera.IsConnected && !_operationInProgress;
        SetParameterAvailability(
            ExposureModeBox,
            "exposureMode",
            connected);
        SetParameterAvailability(ShutterBox, "exposureTime", connected);
        SetParameterAvailability(ApertureBox, "aperture", connected);
        SetParameterAvailability(IsoBox, "iso", connected);
        SetParameterAvailability(
            ExposureCompensationBox,
            "exposureCompensation",
            connected);
        SetParameterAvailability(FocusModeBox, "focusMode", connected);
        SetParameterAvailability(
            WhiteBalanceBox,
            "whiteBalanceMode",
            connected);
        SetParameterAvailability(
            PictureControlBox,
            "pictureControl",
            connected);
    }

    private void SetParameterAvailability(
        Control control,
        string parameter,
        bool connected)
    {
        var enabled = connected && _camera.CanAdjustParameter(parameter);
        control.IsEnabled = enabled;
        control.Opacity = enabled ? 1 : 0.48;
        ToolTipService.SetToolTip(
            control,
            enabled
                ? null
                : connected
                    ? _camera.ParameterLockReason(parameter)
                    : AppLocalization.T("连接相机后可调整"));
    }

    private void UpdateLiveViewState()
    {
        var live = _camera.IsLiveView;
        LiveViewButton.Content =
            AppLocalization.T(live ? "停止取景" : "开启取景");
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
        if (_immersivePreviewImage is not null)
        {
            _immersivePreviewImage.Source = bitmap;
        }
        PreviewEmpty.Visibility = Visibility.Collapsed;
    }

    private void RefreshPhotoList()
    {
        var libraryItems = _library.List();
        var systemItems = _library.ListSystemAlbum();
        var items = libraryItems
            .Concat(systemItems)
            .OrderByDescending(item => File.GetLastWriteTimeUtc(item.Path))
            .ToList();
        _photos.Clear();
        foreach (var item in items)
        {
            _photos.Add(item);
        }
        PhotoCountText.Text = AppLocalization.T(
            $"{libraryItems.Count} 个本地文件 · {systemItems.Count} 个系统相册项目");
        DeletePhotoButton.IsEnabled = false;
        SharePhotoButton.IsEnabled = false;
    }

    private void SetCurrentNavigation(Button? current)
    {
        var videoActive = current == MonitorNav;
        foreach (var button in new[]
                 {
                     CaptureNav,
                     MonitorNav,
                     LibraryNav
                 })
        {
            button.Background = button == current
                ? (Brush)FindResource(
                    videoActive ? "VideoSoftBrush" : "AccentSoftBrush")
                : Brushes.Transparent;
            button.Foreground = button == current
                ? (Brush)FindResource(
                    videoActive ? "VideoBrush" : "AccentBrush")
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
            AppLocalization.T(message),
            "帧澈 ZENCHE",
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
        if (_immersivePreviewWindow is { } immersive)
        {
            CloseImmersivePreview(immersive);
        }
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
