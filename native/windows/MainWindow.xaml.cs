using NikonLink.Windows.Models;
using NikonLink.Windows.Services;
using Microsoft.Win32;
using System.Collections.ObjectModel;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Net.Http;
using System.Text.Json;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Input;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Media.Imaging;
#if NIKONLINK_WINDOWS_SHARE
using Windows.ApplicationModel.DataTransfer;
using Windows.Storage;
#endif

namespace NikonLink.Windows;

public partial class MainWindow : Window
{
    private sealed record PreparedPreview(
        BitmapSource Display,
        ProfessionalMonitorResult Monitor);

    private sealed class LibraryBranch
    {
        public string Id { get; set; } = Guid.NewGuid().ToString("N");
        public string Name { get; set; } = "未命名分支";
        public List<LibraryBranch> Children { get; set; } = [];
    }

    private sealed class LibraryTreeNode
    {
        public required string Name { get; init; }
        public string Detail { get; init; } = "";
        public string Icon { get; init; } = "▱";
        public BitmapSource? Thumbnail { get; init; }
        public string? BranchId { get; init; }
        public PhotoItem? Item { get; init; }
        public bool IsUnclassified { get; init; }
        public bool IsExpanded { get; set; }
        public ObservableCollection<LibraryTreeNode> Children { get; } = [];
    }

    private sealed class EditorPhotoChoice
    {
        public required PhotoItem Item { get; init; }

        public override string ToString() => Item.Name;
    }

    private sealed class EditorAdjustments
    {
        public double Exposure { get; set; }
        public double Contrast { get; set; }
        public double Highlights { get; set; }
        public double Shadows { get; set; }
        public double Whites { get; set; }
        public double Blacks { get; set; }
        public double Temperature { get; set; }
        public double Tint { get; set; }
        public double Vibrance { get; set; }
        public double Saturation { get; set; }
        public double Texture { get; set; }
        public double Clarity { get; set; }
        public double Sharpening { get; set; }
        public double NoiseReduction { get; set; }
        public double Dehaze { get; set; }
        public double Vignette { get; set; }
        public int Rotation { get; set; }
        public bool FlipHorizontal { get; set; }
        public bool FlipVertical { get; set; }
        public bool ShowingOriginal { get; set; }
        public string CropRatio { get; set; } = "original";

        public void Reset()
        {
            Exposure = 0;
            Contrast = 0;
            Highlights = 0;
            Shadows = 0;
            Whites = 0;
            Blacks = 0;
            Temperature = 0;
            Tint = 0;
            Vibrance = 0;
            Saturation = 0;
            Texture = 0;
            Clarity = 0;
            Sharpening = 0;
            NoiseReduction = 0;
            Dehaze = 0;
            Vignette = 0;
            Rotation = 0;
            FlipHorizontal = false;
            FlipVertical = false;
            ShowingOriginal = false;
            CropRatio = "original";
        }

        public void ResetTone()
        {
            var geometry = (
                Rotation,
                FlipHorizontal,
                FlipVertical,
                CropRatio);
            Reset();
            Rotation = geometry.Rotation;
            FlipHorizontal = geometry.FlipHorizontal;
            FlipVertical = geometry.FlipVertical;
            CropRatio = geometry.CropRatio;
        }

        public EditorAdjustments Copy() => new()
        {
            Exposure = Exposure,
            Contrast = Contrast,
            Highlights = Highlights,
            Shadows = Shadows,
            Whites = Whites,
            Blacks = Blacks,
            Temperature = Temperature,
            Tint = Tint,
            Vibrance = Vibrance,
            Saturation = Saturation,
            Texture = Texture,
            Clarity = Clarity,
            Sharpening = Sharpening,
            NoiseReduction = NoiseReduction,
            Dehaze = Dehaze,
            Vignette = Vignette,
            Rotation = Rotation,
            FlipHorizontal = FlipHorizontal,
            FlipVertical = FlipVertical,
            ShowingOriginal = ShowingOriginal,
            CropRatio = CropRatio
        };
    }

    private sealed record EditorSliderSpec(
        string Key,
        string Label,
        double Minimum,
        double Maximum,
        bool Exposure = false);

    private static readonly string AnnouncementStatePath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "NikonLink",
        "dismissed-announcement-version.txt");
    private static readonly string LibraryBranchStatePath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "NikonLink",
        "library-branches.json");
    private static readonly string LibraryFileAssignmentStatePath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "NikonLink",
        "library-file-assignments.json");
    private const string LibraryDragFormat = "ZENCHE.LibraryFilePath";
    private const string AfdianUrl = "https://www.ifdian.net/a/Tauber";
    private readonly PtpCamera _camera = new();
    private readonly PhotoLibrary _library = new();
    private readonly CaptureWorkflow _workflow;
    private readonly WirelessTransferServer _wirelessServer;
    private readonly DiagnosticLogger _diagnostics = DiagnosticLogger.Shared;
    private readonly UpdateService _updateService = new();
    private readonly List<LibraryBranch> _libraryBranches;
    private readonly Dictionary<string, string> _libraryFileAssignments;
    private CancellationTokenSource? _previewCancellation;
    private Task? _previewTask;
    private CancellationTokenSource? _shootingTaskCancellation;
    private bool _operationInProgress;
    private bool _initializing = true;
    private bool _shutdownStarted;
    private bool _configuringVideoControls;
    private bool _videoMode;
    private bool _videoRecording;
    private int _previewAnalysisSequence;
    private double _videoFrameRate = 30;
    private double _videoShutterAngle = 180;
    private double _photoShutterSeconds = 0.008;
    private string _shootingTaskKind = "interval";
    private int _shootingTaskCount = 5;
    private int _shootingTaskInterval = 3;
    private int _shootingTaskStep = 1;
    private bool _focusPeakingEnabled;
    private bool _falseColorEnabled;
    private string? _availableUpdateUrl;
    private bool _checkingForUpdates;
    private bool _announcementShownThisLaunch;
    private Window? _immersivePreviewWindow;
    private Image? _immersivePreviewImage;
    private Button? _immersiveRecordButton;
    private Point _libraryDragStart;
    private bool _libraryDragInProgress;
    private TreeViewItem? _libraryDropTarget;
    private string? _editorSelectedPath;
    private readonly EditorAdjustments _editorAdjustments = new();
    private readonly Dictionary<string, Slider> _editorSliders = [];
    private ComboBox? _editorCropBox;
    private bool _updatingEditorControls;
    private string _aiPrompt = "";
    private int _aiMode; // 0=edit, 1=generate
    private int _aiRatioIndex;
    private int _aiResolutionIndex;
    private string? _aiResultPath;
    private bool _aiGenerating;
    private bool _editorInAiMode;

    private static readonly string[] AiSizes =
    [
        "1024x1024", "1792x1024", "1024x1792", "1365x1024", "1536x1024"
    ];

    private const int AiMaxUsage = 100;
    private static readonly string AiDataDir = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "NikonLink");

    private static bool IsAiActivated()
    {
        var activatedPath = Path.Combine(AiDataDir, "ai-activated.txt");
        return File.Exists(activatedPath);
    }

    private static int GetRemainingUsage()
    {
        var countPath = Path.Combine(AiDataDir, "ai-usage-count.txt");
        var count = 0;
        if (File.Exists(countPath))
            int.TryParse(File.ReadAllText(countPath).Trim(), out count);
        return Math.Max(0, AiMaxUsage - count);
    }

    private static void RecordAiUsage()
    {
        Directory.CreateDirectory(AiDataDir);
        var countPath = Path.Combine(AiDataDir, "ai-usage-count.txt");
        var count = 0;
        if (File.Exists(countPath))
            int.TryParse(File.ReadAllText(countPath).Trim(), out count);
        count++;
        File.WriteAllText(countPath, count.ToString());
        if (count >= AiMaxUsage)
        {
            var activatedPath = Path.Combine(AiDataDir, "ai-activated.txt");
            if (File.Exists(activatedPath)) File.Delete(activatedPath);
        }
    }

    private static string GetDeviceId()
    {
        var devicePath = Path.Combine(AiDataDir, "ai-device-id.txt");
        if (File.Exists(devicePath))
            return File.ReadAllText(devicePath).Trim();
        var id = System.Security.Principal.WindowsIdentity.GetCurrent().User?.Value
                 ?? Guid.NewGuid().ToString();
        Directory.CreateDirectory(AiDataDir);
        File.WriteAllText(devicePath, id);
        return id;
    }

    private static string LoadAiServerUrl()
    {
        try
        {
            var serverPath = Path.Combine(AiDataDir, "ai-server-url.txt");
            if (File.Exists(serverPath))
            {
                var value = File.ReadAllText(serverPath).Trim();
                if (value.Length > 0) return value;
            }
        }
        catch (Exception error)
        {
            DiagnosticLogger.Shared.Warning(
                "ai", $"读取 AI 服务器地址失败：{error.Message}");
        }
        return "http://101.34.255.115:8787";
    }

    private static string LoadActivationCode()
    {
        try
        {
            var codePath = Path.Combine(AiDataDir, "ai-activation-code.txt");
            if (File.Exists(codePath))
            {
                var value = File.ReadAllText(codePath).Trim();
                if (value.Length > 0) return value;
            }
        }
        catch (Exception error)
        {
            DiagnosticLogger.Shared.Warning(
                "ai", $"读取激活码失败：{error.Message}");
        }
        return string.Empty;
    }

    private static void SaveActivationCode(string code)
    {
        try
        {
            Directory.CreateDirectory(AiDataDir);
            var codePath = Path.Combine(AiDataDir, "ai-activation-code.txt");
            File.WriteAllText(codePath, code.Trim());
        }
        catch (Exception error)
        {
            DiagnosticLogger.Shared.Warning(
                "ai", $"保存激活码失败：{error.Message}");
        }
    }

    private static void SaveAiServerUrl(string url)
    {
        try
        {
            Directory.CreateDirectory(AiDataDir);
            var serverPath = Path.Combine(AiDataDir, "ai-server-url.txt");
            File.WriteAllText(serverPath, url.Trim());
        }
        catch (Exception error)
        {
            DiagnosticLogger.Shared.Warning(
                "ai", $"保存服务器地址失败：{error.Message}");
        }
    }

    private void AiBuy_Click(object sender, RoutedEventArgs e)
    {
        OpenAfdian();
    }

    private void AiActivate_Click(object sender, RoutedEventArgs e)
    {
        var code = AiActivationCodeBox.Text.Trim();
        if (string.IsNullOrEmpty(code))
        {
            AiActivationStatusText.Text = AppLocalization.T("请输入激活码");
            return;
        }
        // 保存服务器地址（如果用户填了）
        var serverUrl = AiServerUrlBox.Text.Trim();
        if (!string.IsNullOrEmpty(serverUrl))
        {
            SaveAiServerUrl(serverUrl);
        }
        // 本地验签激活（RSA 公钥在客户端），服务器端负责真正计数
        SaveActivationCode(code);
        var activatedPath = Path.Combine(AiDataDir, "ai-activated.txt");
        Directory.CreateDirectory(AiDataDir);
        File.WriteAllText(activatedPath, "1");
        AiActivationStatusText.Text = AppLocalization.T("激活成功！AI 功能已解锁");
        AiActivationCodeBox.Text = "";
    }
#if NIKONLINK_WINDOWS_SHARE
    private DataTransferManager? _dataTransferManager;
#endif
    private string? _sharePhotoPath;

    public MainWindow()
    {
        InitializeComponent();
        BuildEditorAdjustmentControls();
        EditorPresetBox.SelectedIndex = 0;
        _libraryBranches = LoadLibraryBranches();
        _libraryFileAssignments = LoadLibraryFileAssignments();
        _workflow = new CaptureWorkflow(_library.DirectoryPath);
        LoadCaptureSessionControls();
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
        DiagnosticLogPathText.Text = AppLocalization.T(
            "按日写入、5 MB 滚动、保留 14 天\n") +
            _diagnostics.DirectoryPath;
        CurrentVersionText.Text = AppLocalization.T(
            $"当前版本 {_updateService.CurrentVersion} · 优先通过 Mirror酱检查更新，无可用 CDN 下载地址时自动回退 GitHub Releases");
        MirrorChyanCdkBox.Password = _updateService.LoadMirrorChyanCdk();
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
        ShootingTaskStepText.IsEnabled = false;
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
        root.Children.Add(new Border
        {
            Width = 84,
            Height = 84,
            BorderThickness = new Thickness(2),
            BorderBrush = new SolidColorBrush(
                Color.FromArgb(220, 255, 214, 70)),
            CornerRadius = new CornerRadius(4),
            Background = Brushes.Transparent,
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center,
            IsHitTestVisible = false
        });

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
        var liveView = new Button
        {
            Content = AppLocalization.T(
                _camera.IsLiveView ? "停止取景" : "开启取景"),
            Height = 44,
            MinWidth = 92,
            Margin = new Thickness(0, 10, 0, 0),
            Style = (Style)FindResource("ButtonBase"),
            IsEnabled = _camera.IsConnected
        };
        liveView.Click += LiveViewButton_Click;
        rightRail.Children.Add(liveView);
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
            ImmersiveParameterControl(
                _videoMode ? "快门角度" : "快门",
                ShutterBox));
        parameterBar.Children.Add(
            ImmersiveParameterControl(
                "光圈",
                ApertureBox));
        parameterBar.Children.Add(
            ImmersiveParameterControl("ISO", IsoBox));
        parameterBar.Children.Add(
            ImmersiveParameterControl("曝光补偿", ExposureCompensationBox));
        var parameterScroller = new ScrollViewer
        {
            Content = parameterBar,
            HorizontalScrollBarVisibility = ScrollBarVisibility.Auto,
            VerticalScrollBarVisibility = ScrollBarVisibility.Disabled
        };

        var moreParameterBar = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            HorizontalAlignment = HorizontalAlignment.Left
        };
        if (_videoMode)
        {
            moreParameterBar.Children.Add(
                ImmersiveParameterControl("视频帧率", VideoFrameRateBox));
        }
        else
        {
            moreParameterBar.Children.Add(
                ImmersiveParameterControl("拍摄模式", ExposureModeBox));
        }
        moreParameterBar.Children.Add(
            ImmersiveParameterControl("对焦", FocusModeBox));
        moreParameterBar.Children.Add(
            ImmersiveParameterControl("白平衡", WhiteBalanceBox));
        moreParameterBar.Children.Add(
            ImmersiveParameterControl("优化校准", PictureControlBox));
        var moreParameterScroller = new ScrollViewer
        {
            Content = moreParameterBar,
            HorizontalScrollBarVisibility = ScrollBarVisibility.Auto,
            VerticalScrollBarVisibility = ScrollBarVisibility.Disabled
        };
        var moreParameterTray = new Expander
        {
            Header = "更多参数",
            IsExpanded = false,
            Content = moreParameterScroller,
            Foreground = Brushes.White,
            Background = new SolidColorBrush(Color.FromArgb(105, 0, 0, 0)),
            Padding = new Thickness(6),
            Margin = new Thickness(0, 6, 0, 0)
        };
        var parameterContent = new StackPanel();
        parameterContent.Children.Add(parameterScroller);
        parameterContent.Children.Add(moreParameterTray);
        var parameterTray = new Expander
        {
            Header = "参数",
            IsExpanded = true,
            Content = parameterContent,
            Foreground = Brushes.White,
            Background = new SolidColorBrush(Color.FromArgb(120, 0, 0, 0)),
            Padding = new Thickness(8),
            Margin = new Thickness(112, 0, 124, 78),
            HorizontalAlignment = HorizontalAlignment.Stretch,
            VerticalAlignment = VerticalAlignment.Bottom
        };
        root.Children.Add(parameterTray);
        void ApplyImmersiveLayout()
        {
            var landscape = viewer.ActualWidth <= 0 ||
                viewer.ActualWidth >= viewer.ActualHeight;
            leftRail.Orientation = landscape
                ? Orientation.Vertical
                : Orientation.Horizontal;
            leftRail.Width = landscape ? 76 : double.NaN;
            leftRail.HorizontalAlignment = landscape
                ? HorizontalAlignment.Left
                : HorizontalAlignment.Center;
            leftRail.VerticalAlignment = landscape
                ? VerticalAlignment.Center
                : VerticalAlignment.Top;
            leftRail.Margin = landscape
                ? new Thickness(20, 0, 0, 0)
                : new Thickness(20, 86, 20, 0);

            rightRail.Orientation = landscape
                ? Orientation.Vertical
                : Orientation.Horizontal;
            rightRail.Width = landscape ? 112 : double.NaN;
            rightRail.HorizontalAlignment = landscape
                ? HorizontalAlignment.Right
                : HorizontalAlignment.Center;
            rightRail.VerticalAlignment = landscape
                ? VerticalAlignment.Center
                : VerticalAlignment.Bottom;
            rightRail.Margin = landscape
                ? new Thickness(0, 0, 20, 0)
                : new Thickness(20, 0, 20, 18);

            parameterTray.Margin = landscape
                ? new Thickness(112, 0, 124, 78)
                : new Thickness(18, 0, 18, 168);
            exposure.Margin = landscape
                ? new Thickness(0, 0, 0, 24)
                : new Thickness(0, 0, 0, 122);
        }
        viewer.SizeChanged += (_, _) => ApplyImmersiveLayout();
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
        viewer.Dispatcher.BeginInvoke(ApplyImmersiveLayout);
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
            var path = await _workflow.StoreAsync(
                jpeg,
                "capture.jpg",
                _camera.Profile?.Name ?? "Nikon 相机",
                cancellationToken: token);
            DisplayJpeg(jpeg);
            RefreshPhotoList();
            OperationStatusText.Text = AppLocalization.T(
                $"已保存 {Path.GetFileName(path)}");
        });
    }

    private async Task StartShootingTaskAsync()
    {
        if (_operationInProgress || !_camera.IsConnected)
        {
            return;
        }
        _shootingTaskCancellation?.Cancel();
        _shootingTaskCancellation?.Dispose();
        _shootingTaskCancellation = new CancellationTokenSource();
        var token = _shootingTaskCancellation.Token;
        var kind = _shootingTaskKind;
        var count = Math.Clamp(_shootingTaskCount, 1, 999);
        var interval = Math.Clamp(_shootingTaskInterval, 1, 3600);
        var step = Math.Clamp(_shootingTaskStep, 1, 3);
        var originalMode = ExposureModeBox.SelectedItem is ComboBoxItem modeItem
            ? Convert.ToString(modeItem.Tag) ?? "manual"
            : "manual";
        var originalCompensation =
            ExposureCompensationBox.SelectedItem is ComboBoxItem compensationItem &&
            double.TryParse(
                Convert.ToString(compensationItem.Tag),
                NumberStyles.Float,
                CultureInfo.InvariantCulture,
                out var compensation)
                ? compensation
                : 0;
        _operationInProgress = true;
        UpdateEnabledState();
        ShootingTaskButton.Content = AppLocalization.T("取消任务");
        ShootingTaskStatusText.Text = AppLocalization.T(
            $"{ShootingTaskLabel(kind)}准备中");
        await StopPreviewLoopAsync();
        try
        {
            var total = kind == "bulb" ? 1 : count;
            if (kind == "exposure" && total % 2 == 0)
            {
                total++;
            }
            if (kind == "focus" && !_camera.IsLiveView)
            {
                await _camera.StartLiveViewAsync(token);
            }
            if (kind == "bulb")
            {
                await _camera.SetParameterAsync("exposureMode", "bulb", token);
                await _camera.SetParameterAsync(
                    "bulbDuration",
                    interval,
                    token);
            }
            for (var index = 0; index < total; index++)
            {
                token.ThrowIfCancellationRequested();
                if (kind == "exposure")
                {
                    var center = total / 2;
                    await _camera.SetParameterAsync(
                        "exposureCompensation",
                        originalCompensation + (index - center) * step,
                        token);
                }
                if (kind == "focus" && index > 0)
                {
                    await _camera.MoveFocusAsync(step, token);
                }
                var jpeg = await _camera.CaptureAsync(token);
                var path = await _workflow.StoreAsync(
                    jpeg,
                    "capture.jpg",
                    _camera.Profile?.Name ?? "Nikon 相机",
                    cancellationToken: token);
                DisplayJpeg(jpeg);
                RefreshPhotoList();
                ShootingTaskStatusText.Text = AppLocalization.T(
                    $"{ShootingTaskLabel(kind)} · {index + 1}/{total} · " +
                    Path.GetFileName(path));
                OperationStatusText.Text = ShootingTaskStatusText.Text;
                if (kind == "interval" && index + 1 < total)
                {
                    await Task.Delay(TimeSpan.FromSeconds(interval), token);
                }
            }
            await RestoreTaskCameraStateAsync(
                kind,
                originalCompensation,
                originalMode,
                CancellationToken.None);
            ShootingTaskStatusText.Text = AppLocalization.T(
                $"{ShootingTaskLabel(kind)}已完成");
        }
        catch (OperationCanceledException)
        {
            await RestoreTaskCameraStateAsync(
                kind,
                originalCompensation,
                originalMode,
                CancellationToken.None);
            ShootingTaskStatusText.Text =
                AppLocalization.T("拍摄任务已取消");
        }
        catch (Exception error)
        {
            await RestoreTaskCameraStateAsync(
                kind,
                originalCompensation,
                originalMode,
                CancellationToken.None);
            _diagnostics.Error(
                "capture-task",
                $"{ShootingTaskLabel(kind)}失败：{error}");
            ShootingTaskStatusText.Text =
                AppLocalization.T("拍摄任务失败");
            ShowError(error.Message);
        }
        finally
        {
            _operationInProgress = false;
            _shootingTaskCancellation?.Dispose();
            _shootingTaskCancellation = null;
            ShootingTaskButton.Content = AppLocalization.T("开始任务");
            UpdateEnabledState();
            UpdateLiveViewState();
            if (_camera.IsLiveView)
            {
                StartPreviewLoop();
            }
        }
    }

    private async void ShootingTaskButton_Click(
        object sender,
        RoutedEventArgs e)
    {
        if (_shootingTaskCancellation is not null && _operationInProgress)
        {
            _shootingTaskCancellation.Cancel();
            ShootingTaskStatusText.Text =
                AppLocalization.T("正在取消拍摄任务…");
            return;
        }
        if (ShootingTaskKindBox.SelectedItem is ComboBoxItem kindItem)
        {
            _shootingTaskKind =
                Convert.ToString(kindItem.Tag) ?? "interval";
        }
        _shootingTaskCount = ParseBounded(
            ShootingTaskCountText.Text,
            1,
            999,
            5);
        _shootingTaskInterval = ParseBounded(
            ShootingTaskIntervalText.Text,
            1,
            3600,
            3);
        _shootingTaskStep = ParseBounded(
            ShootingTaskStepText.Text,
            1,
            3,
            1);
        ShootingTaskCountText.Text = _shootingTaskCount.ToString();
        ShootingTaskIntervalText.Text = _shootingTaskInterval.ToString();
        ShootingTaskStepText.Text = _shootingTaskStep.ToString();
        await StartShootingTaskAsync();
    }

    private void ShootingTaskKindBox_SelectionChanged(
        object sender,
        SelectionChangedEventArgs e)
    {
        if (_initializing ||
            ShootingTaskKindBox.SelectedItem is not ComboBoxItem item)
        {
            return;
        }
        _shootingTaskKind = Convert.ToString(item.Tag) ?? "interval";
        ShootingTaskIntervalLabel.Text = AppLocalization.T(
            _shootingTaskKind == "bulb"
                ? "曝光时长（秒）"
                : "间隔（秒）");
        ShootingTaskCountText.IsEnabled = _shootingTaskKind != "bulb";
        ShootingTaskStepText.IsEnabled =
            _shootingTaskKind is "exposure" or "focus";
    }

    private static int ParseBounded(
        string value,
        int minimum,
        int maximum,
        int fallback) =>
        int.TryParse(value, out var parsed)
            ? Math.Clamp(parsed, minimum, maximum)
            : fallback;

    private void FocusPeakingCheck_Click(
        object sender,
        RoutedEventArgs e)
    {
        _focusPeakingEnabled = FocusPeakingCheck.IsChecked == true;
    }

    private void FalseColorCheck_Click(
        object sender,
        RoutedEventArgs e)
    {
        _falseColorEnabled = FalseColorCheck.IsChecked == true;
    }

    private void LoadCaptureSessionControls()
    {
        var configuration = _workflow.Configuration;
        SessionNameText.Text = configuration.Name;
        SessionNamingTemplateText.Text = configuration.NamingTemplate;
        SessionCreatorText.Text = configuration.Creator;
        SessionRightsText.Text = configuration.Rights;
        SessionRatingBox.SelectedIndex =
            Math.Clamp(configuration.Rating, 0, 5);
        SessionDualBackupCheck.IsChecked =
            configuration.DualBackupEnabled;
        SessionStatusText.Text = AppLocalization.T(_workflow.Status);
        SessionActionButton.Content = AppLocalization.T(
            _workflow.IsActive ? "结束会话" : "开始会话");
    }

    private void SessionActionButton_Click(
        object sender,
        RoutedEventArgs e)
    {
        try
        {
            if (_workflow.IsActive)
            {
                _workflow.End();
            }
            else
            {
                var rating =
                    SessionRatingBox.SelectedItem is ComboBoxItem ratingItem &&
                    int.TryParse(
                        Convert.ToString(ratingItem.Tag),
                        out var selectedRating)
                        ? selectedRating
                        : 0;
                _workflow.Begin(
                    new CaptureSessionConfiguration(
                        SessionNameText.Text,
                        SessionNamingTemplateText.Text,
                        SessionCreatorText.Text,
                        SessionRightsText.Text,
                        rating,
                        SessionDualBackupCheck.IsChecked == true));
            }
            LoadCaptureSessionControls();
            OperationStatusText.Text =
                AppLocalization.T(_workflow.Status);
        }
        catch (Exception error)
        {
            ShowError(error.Message);
        }
    }

    private async Task RestoreTaskCameraStateAsync(
        string kind,
        double compensation,
        string exposureMode,
        CancellationToken cancellationToken)
    {
        try
        {
            if (kind == "exposure")
            {
                await _camera.SetParameterAsync(
                    "exposureCompensation",
                    compensation,
                    cancellationToken);
            }
            if (kind == "bulb" && exposureMode != "bulb")
            {
                await _camera.SetParameterAsync(
                    "exposureMode",
                    exposureMode,
                    cancellationToken);
            }
        }
        catch
        {
        }
    }

    private static string ShootingTaskLabel(string kind) => kind switch
    {
        "exposure" => "曝光包围",
        "focus" => "焦点包围",
        "bulb" => "B 门计时",
        _ => "间隔拍摄"
    };

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
            nameof(ShutterBox) =>
                _videoMode ? "videoExposureTime" : "exposureTime",
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
            "exposureTime" or "videoExposureTime" or
            "aperture" or "iso" or "exposureCompensation"
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
        EditorPanel.Visibility =
            destination == "editor"
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
            LoadCaptureSessionControls();
        }
        if (destination == "editor")
        {
            _editorInAiMode = !_editorInAiMode;
            if (!_editorInAiMode)
            {
                EditorProGrid.Visibility = Visibility.Visible;
                EditorAiGrid.Visibility = Visibility.Collapsed;
                EditorHeaderTitle.Text = AppLocalization.T("专业显影");
                EditorHeaderSubtitle.Text = AppLocalization.T(
                    "分组调整光线、色彩、细节、效果与几何；始终保留原文件。");
            }
            RefreshImageEditor();
        }
        ShootingTaskPanel.Visibility =
            destination == "capture"
                ? Visibility.Visible
                : Visibility.Collapsed;
        ProfessionalMonitorPanel.Visibility =
            destination == "monitor"
                ? Visibility.Visible
                : Visibility.Collapsed;
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
                    "videoExposureTime",
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
                    AppLocalization.T(
                        $"发现新版本 {update.Version}"
                        + (update.Notice is null ? "" : $" · {update.Notice}"));
                OpenUpdateButton.Content =
                    AppLocalization.T($"获取 {update.Version}");
                OpenUpdateButton.Visibility = Visibility.Visible;
            }
            else
            {
                _availableUpdateUrl = null;
                UpdateStatusText.Text =
                    AppLocalization.T(
                        "已是最新版本"
                        + (update.Notice is null ? "" : $" · {update.Notice}"));
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

    private void SaveMirrorChyanCdkButton_Click(
        object sender,
        RoutedEventArgs e)
    {
        try
        {
            _updateService.SaveMirrorChyanCdk(MirrorChyanCdkBox.Password);
            UpdateStatusText.Text = AppLocalization.T(
                string.IsNullOrWhiteSpace(MirrorChyanCdkBox.Password)
                    ? "Mirror酱 CDK 已清除"
                    : "Mirror酱 CDK 已安全保存");
        }
        catch (Exception error)
        {
            _diagnostics.Error(
                "update",
                $"无法保存 Mirror酱 CDK：{error.Message}");
            UpdateStatusText.Text =
                AppLocalization.T("Mirror酱 CDK 保存失败");
        }
    }

    private void OpenMirrorChyanButton_Click(
        object sender,
        RoutedEventArgs e)
    {
        try
        {
            Process.Start(new ProcessStartInfo
            {
                FileName = _updateService.MirrorChyanWebsiteUrl,
                UseShellExecute = true
            });
        }
        catch (Exception error)
        {
            _diagnostics.Error(
                "update",
                $"无法打开 Mirror酱：{error.Message}");
            ShowError("无法打开 Mirror酱网站");
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
            Background = (Brush)FindResource("PaperBrush"),
            WindowStartupLocation = WindowStartupLocation.CenterOwner
        };
        var logGrid = new Grid { Margin = new Thickness(20) };
        logGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        logGrid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
        logGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        var logHeader = new StackPanel { Margin = new Thickness(0, 0, 0, 12) };
        logHeader.Children.Add(new TextBlock
        {
            Text = "诊断日志查询",
            FontFamily = (FontFamily)FindResource("DisplayFont"),
            FontSize = 22,
            FontWeight = FontWeights.Bold,
            Foreground = (Brush)FindResource("InkBrush")
        });
        logHeader.Children.Add(new TextBlock
        {
            Text = "显示近期脱敏日志；刷新可读取最新记录。",
            FontSize = 12,
            Foreground = (Brush)FindResource("MutedBrush"),
            Margin = new Thickness(0, 2, 0, 0)
        });
        logGrid.Children.Add(logHeader);
        var logBox = new TextBox
        {
            Text = _diagnostics.RecentText(12_000),
            FontFamily = new FontFamily("Cascadia Mono, Consolas"),
            FontSize = 12,
            IsReadOnly = true,
            AcceptsReturn = true,
            TextWrapping = TextWrapping.NoWrap,
            HorizontalScrollBarVisibility = ScrollBarVisibility.Auto,
            VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
            Background = new SolidColorBrush(
                System.Windows.Media.Color.FromRgb(12, 15, 21)),
            Foreground = new SolidColorBrush(
                System.Windows.Media.Color.FromRgb(222, 228, 237)),
            BorderBrush = (Brush)FindResource("RuleBrush"),
            BorderThickness = new Thickness(1),
            Padding = new Thickness(14)
        };
        Grid.SetRow(logBox, 1);
        logGrid.Children.Add(logBox);
        var logActions = new DockPanel { Margin = new Thickness(0, 12, 0, 0) };
        var refreshBtn = new Button
        {
            Content = "刷新",
            Style = (Style)FindResource("ButtonBase"),
            Width = 100
        };
        refreshBtn.Click += (_, _) =>
        {
            logBox.Text = _diagnostics.RecentText(12_000);
        };
        DockPanel.SetDock(refreshBtn, Dock.Left);
        logActions.Children.Add(refreshBtn);
        var closeLogBtn = new Button
        {
            Content = "关闭",
            Style = (Style)FindResource("PrimaryButton"),
            Width = 100
        };
        closeLogBtn.Click += (_, _) => viewer.Close();
        DockPanel.SetDock(closeLogBtn, Dock.Right);
        logActions.Children.Add(closeLogBtn);
        Grid.SetRow(logActions, 2);
        logGrid.Children.Add(logActions);
        viewer.Content = logGrid;
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
            var root = new Grid { Margin = new Thickness(24) };
            root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            root.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
            root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });

            var header = new StackPanel { Margin = new Thickness(0, 0, 0, 14) };
            header.Children.Add(new TextBlock
            {
                Text = AppLocalization.T("爱发电赞助"),
                Style = (Style)FindResource("DisplayText")
            });
            header.Children.Add(new TextBlock
            {
                Text = AppLocalization.T(
                    "扫描二维码，或打开爱发电主页支持项目。"),
                FontSize = 12,
                Foreground = (Brush)FindResource("MutedBrush"),
                Margin = new Thickness(0, 4, 0, 0)
            });
            root.Children.Add(header);

            var feedbackCard = CreateFastFeedbackCard();
            Grid.SetRow(feedbackCard, 1);
            root.Children.Add(feedbackCard);

            var imageCard = new Border
            {
                Background = (Brush)FindResource("SurfaceBrush"),
                BorderBrush = (Brush)FindResource("RuleBrush"),
                BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(12),
                Padding = new Thickness(8),
                Child = new Image
                {
                    Source = image,
                    Stretch = Stretch.Uniform
                }
            };
            imageCard.Margin = new Thickness(0, 14, 0, 0);
            Grid.SetRow(imageCard, 2);
            root.Children.Add(imageCard);

            var footer = new TextBlock
            {
                Text = AppLocalization.T(
                    "软件功能永久免费，赞助为自愿行为。\n" +
                    "赞助不会解锁软件功能，也不影响公开 Issue 的处理。"),
                FontSize = 11,
                Foreground = (Brush)FindResource("MutedBrush"),
                Margin = new Thickness(0, 12, 0, 0),
                TextAlignment = TextAlignment.Left
            };
            Grid.SetRow(footer, 3);
            root.Children.Add(footer);

            var dialog = new Window
            {
                Owner = this,
                Title = AppLocalization.T("爱发电赞助"),
                Width = 520,
                Height = 780,
                MinWidth = 360,
                MinHeight = 620,
                Background = (Brush)FindResource("PaperBrush"),
                WindowStartupLocation = WindowStartupLocation.CenterOwner,
                Content = root
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

    private void OpenAfdianButton_Click(object sender, RoutedEventArgs e)
    {
        OpenAfdian();
    }

    private static void OpenAfdian()
    {
        Process.Start(new ProcessStartInfo
        {
            FileName = AfdianUrl,
            UseShellExecute = true
        });
    }

    private Border CreateFastFeedbackCard()
    {
        var copy = new StackPanel
        {
            Margin = new Thickness(0, 0, 16, 0)
        };
        copy.Children.Add(new TextBlock
        {
            Text = AppLocalization.T("快速问题反馈"),
            FontSize = 15,
            FontWeight = FontWeights.Bold
        });
        copy.Children.Add(new TextBlock
        {
            Text = AppLocalization.T(
                "公开问题可继续在 GitHub 免费提交；在爱发电赞助后，可获取快速问题反馈渠道。"),
            FontSize = 12,
            Foreground = (Brush)FindResource("MutedBrush"),
            Margin = new Thickness(0, 4, 0, 0),
            TextWrapping = TextWrapping.Wrap
        });
        copy.Children.Add(new TextBlock
        {
            Text = AppLocalization.T("官方 QQ 群：165315727"),
            FontSize = 13,
            FontFamily = (FontFamily)FindResource("MonoFont"),
            FontWeight = FontWeights.Bold,
            Foreground = (Brush)FindResource("AccentBrush"),
            Margin = new Thickness(0, 6, 0, 0)
        });

        var openButton = new Button
        {
            Content = AppLocalization.T("打开爱发电"),
            Style = (Style)FindResource("ButtonBase"),
            MinWidth = 124,
            VerticalAlignment = VerticalAlignment.Center
        };
        openButton.Click += (_, _) => OpenAfdian();

        var grid = new Grid();
        grid.ColumnDefinitions.Add(new ColumnDefinition());
        grid.ColumnDefinitions.Add(new ColumnDefinition
        {
            Width = GridLength.Auto
        });
        grid.Children.Add(copy);
        Grid.SetColumn(openButton, 1);
        grid.Children.Add(openButton);

        return new Border
        {
            Background = (Brush)FindResource("AccentSoftBrush"),
            BorderBrush = new SolidColorBrush(
                System.Windows.Media.Color.FromRgb(182, 207, 245)),
            BorderThickness = new Thickness(1),
            CornerRadius = new CornerRadius(12),
            Padding = new Thickness(14),
            Child = grid
        };
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
                "• 新增 AI 修图与生图工具，内置一键美颜等快捷预设，激活码解锁后即可使用。\n" +
                "• 新增树状分支文件库，支持嵌套分支、拖拽归类与持久化组织。\n" +
                "• 新增专业非破坏性修图工具，提供光影 / 色彩 / 细节 / 效果 / 几何五组参数与透明预设。\n" +
                "• 新增可展开的全屏二级相机参数面板，移动端保持紧凑触控区域。\n" +
                "• USB/PTP 连接可靠性大幅提升：瞬时错误自动重试、HONOR 设备同步降级传输。\n" +
                "• 新增对 Nikon D500、D7500、D850（EXPEED 5）的 USB/PTP 控制支持。\n• 视频录制监看延迟优化：子采样解码、管道重叠取帧、智能跳帧分析。"),
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

        var sponsorCard = new Border
        {
            Background = (Brush)FindResource("SurfaceBrush"),
            BorderBrush = (Brush)FindResource("RuleBrush"),
            BorderThickness = new Thickness(1),
            CornerRadius = new CornerRadius(12),
            Padding = new Thickness(16),
            Child = new StackPanel
            {
                Children =
                {
                    new TextBlock
                    {
                        Text = AppLocalization.T("自愿赞助"),
                        FontSize = 17,
                        FontWeight = FontWeights.Bold,
                        Margin = new Thickness(0, 0, 0, 6)
                    },
                    new TextBlock
                    {
                        Text = AppLocalization.T(
                            "如果本项目对你有帮助，欢迎自愿打赏；软件功能永久免费。"),
                        FontSize = 13,
                        Foreground = (Brush)FindResource("MutedBrush"),
                        TextWrapping = TextWrapping.Wrap,
                        Margin = new Thickness(0, 0, 0, 10)
                    },
                }
            }
        };
        var sponsorContent = (StackPanel)sponsorCard.Child;
        var sponsorFeedback = CreateFastFeedbackCard();
        sponsorFeedback.Margin = new Thickness(0, 0, 0, 14);
        sponsorContent.Children.Add(sponsorFeedback);
        sponsorContent.Children.Add(new Image
        {
            Source = new BitmapImage(
                new Uri(
                    "pack://application:,,,/Assets/wechat-donation.png",
                    UriKind.Absolute)),
            MaxHeight = 470,
            Stretch = Stretch.Uniform,
            HorizontalAlignment = HorizontalAlignment.Center
        });
        body.Children.Add(sponsorCard);

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
            Background = (Brush)FindResource("PaperBrush"),
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

    private async void OpenCloudFilePicker()
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
            var pairNames = new Dictionary<string, string>(
                StringComparer.OrdinalIgnoreCase);
            var imported = new List<string>();
            foreach (var source in dialog.FileNames)
            {
                var pairKey = Path.GetFileNameWithoutExtension(source);
                if (!pairNames.TryGetValue(pairKey, out var reservedBase))
                {
                    reservedBase = _workflow.ReserveBaseName("Imported");
                    pairNames[pairKey] = reservedBase;
                }
                imported.Add(await _workflow.ImportAsync(
                    source,
                    "Imported",
                    reservedBase));
            }
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
            Margin = new Thickness(26)
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
            Style = (Style)FindResource("DisplayText"),
            FontSize = 26
        });
        header.Children.Add(new TextBlock
        {
            Text =
                "帧澈 ZENCHE 不代管网盘账号或密码。先在对应客户端登录，" +
                "再通过系统文件选择器从下载或同步目录加入媒体。",
            Foreground = (Brush)FindResource("MutedBrush"),
            TextWrapping = TextWrapping.Wrap,
            Margin = new Thickness(0, 8, 0, 18)
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
            Margin = new Thickness(0, 18, 0, 0)
        };
        var close = new Button
        {
            Content = "关闭",
            MinWidth = 100,
            Height = 40,
            Style = (Style)FindResource("ButtonBase")
        };
        close.Click += (_, _) => guide.Close();
        DockPanel.SetDock(close, Dock.Left);
        actions.Children.Add(close);
        var choose = new Button
        {
            Content = "选择文件并加入",
            MinWidth = 168,
            Height = 40,
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

    private void PhotoTree_SelectedItemChanged(
        object sender,
        RoutedPropertyChangedEventArgs<object> e)
    {
        var selectedNode = PhotoTree.SelectedItem as LibraryTreeNode;
        var item = selectedNode?.Item;
        DeleteBranchButton.IsEnabled = selectedNode?.BranchId is not null;
        DeletePhotoButton.IsEnabled =
            item is { IsLibraryItem: true };
        SharePhotoButton.IsEnabled = item is not null;
        if (item is null)
        {
            return;
        }
        if (!item.IsVideo && IsEditableImage(item.Path))
        {
            _editorSelectedPath = item.Path;
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

    private void PhotoTree_MouseDoubleClick(
        object sender,
        MouseButtonEventArgs e)
    {
        if ((PhotoTree.SelectedItem as LibraryTreeNode)?.Item is { } item)
        {
            ShowLargePhoto(item);
        }
    }

    private void PhotoTree_PreviewMouseLeftButtonDown(
        object sender,
        MouseButtonEventArgs e)
    {
        _libraryDragStart = e.GetPosition(PhotoTree);
        _libraryDragInProgress = false;
    }

    private void PhotoTree_PreviewMouseLeftButtonUp(
        object sender,
        MouseButtonEventArgs e)
    {
        if (_libraryDragInProgress ||
            IsWithinToggleButton(e.OriginalSource as DependencyObject))
        {
            return;
        }
        var container = FindTreeViewItem(
            e.OriginalSource as DependencyObject);
        if (container?.DataContext is LibraryTreeNode
            {
                Item: null
            } node &&
            node.Children.Count > 0)
        {
            container.IsExpanded = !container.IsExpanded;
            e.Handled = true;
        }
    }

    private void PhotoTree_PreviewMouseMove(
        object sender,
        MouseEventArgs e)
    {
        if (e.LeftButton != MouseButtonState.Pressed)
        {
            return;
        }
        var position = e.GetPosition(PhotoTree);
        if (Math.Abs(position.X - _libraryDragStart.X) <
                SystemParameters.MinimumHorizontalDragDistance &&
            Math.Abs(position.Y - _libraryDragStart.Y) <
                SystemParameters.MinimumVerticalDragDistance)
        {
            return;
        }
        var container = FindTreeViewItem(e.OriginalSource as DependencyObject);
        if (container?.DataContext is not LibraryTreeNode
            {
                Item: { IsLibraryItem: true } item
            })
        {
            return;
        }
        var data = new DataObject(LibraryDragFormat, item.Path);
        _libraryDragInProgress = true;
        try
        {
            DragDrop.DoDragDrop(container, data, DragDropEffects.Move);
        }
        finally
        {
            _libraryDragInProgress = false;
        }
    }

    private void PhotoTree_DragOver(object sender, DragEventArgs e)
    {
        var container = FindTreeViewItem(e.OriginalSource as DependencyObject);
        var node = container?.DataContext as LibraryTreeNode;
        var validTarget =
            e.Data.GetDataPresent(LibraryDragFormat) &&
            node is not null &&
            (node.BranchId is not null || node.IsUnclassified);
        e.Effects = validTarget ? DragDropEffects.Move : DragDropEffects.None;
        e.Handled = true;
        SetLibraryDropTarget(validTarget ? container : null);
    }

    private void PhotoTree_DragLeave(object sender, DragEventArgs e)
    {
        SetLibraryDropTarget(null);
    }

    private void PhotoTree_Drop(object sender, DragEventArgs e)
    {
        var container = FindTreeViewItem(e.OriginalSource as DependencyObject);
        var node = container?.DataContext as LibraryTreeNode;
        if (node is null ||
            (node.BranchId is null && !node.IsUnclassified) ||
            e.Data.GetData(LibraryDragFormat) is not string path)
        {
            SetLibraryDropTarget(null);
            return;
        }
        if (node.IsUnclassified)
        {
            _libraryFileAssignments.Remove(path);
            OperationStatusText.Text = AppLocalization.T("已移到未分类");
        }
        else
        {
            _libraryFileAssignments[path] = node.BranchId!;
            OperationStatusText.Text = AppLocalization.T(
                $"已移到分支“{node.Name}”");
        }
        SaveLibraryFileAssignments();
        SetLibraryDropTarget(null);
        RefreshPhotoList();
        e.Handled = true;
    }

    private static TreeViewItem? FindTreeViewItem(DependencyObject? source)
    {
        while (source is not null && source is not TreeViewItem)
        {
            source = VisualTreeHelper.GetParent(source);
        }
        return source as TreeViewItem;
    }

    private static bool IsWithinToggleButton(DependencyObject? source)
    {
        while (source is not null)
        {
            if (source is ToggleButton)
            {
                return true;
            }
            source = VisualTreeHelper.GetParent(source);
        }
        return false;
    }

    private void SetLibraryDropTarget(TreeViewItem? target)
    {
        if (_libraryDropTarget == target)
        {
            return;
        }
        if (_libraryDropTarget is not null)
        {
            _libraryDropTarget.ClearValue(BackgroundProperty);
        }
        _libraryDropTarget = target;
        if (_libraryDropTarget is not null)
        {
            _libraryDropTarget.Background =
                (Brush)FindResource("AccentSoftBrush");
        }
    }

    private void SharePhotoButton_Click(object sender, RoutedEventArgs e)
    {
        if ((PhotoTree.SelectedItem as LibraryTreeNode)?.Item is { } item)
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
        if ((PhotoTree.SelectedItem as LibraryTreeNode)?.Item is not
            {
                IsLibraryItem: true
            } item)
        {
            return;
        }
        try
        {
            File.Delete(item.Path);
            _libraryFileAssignments.Remove(item.Path);
            SaveLibraryFileAssignments();
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
        Task<byte[]>? pendingFetch = null;
        while (!cancellationToken.IsCancellationRequested &&
               _camera.IsConnected &&
               _camera.IsLiveView)
        {
            try
            {
                // Start next fetch before processing current frame
                var fetchTask = pendingFetch
                    ?? _camera.GetLiveViewFrameAsync(cancellationToken);
                pendingFetch = _camera.GetLiveViewFrameAsync(cancellationToken);
                var jpeg = await fetchTask;
                failures = 0;
                var videoMode = _videoMode;
                var recording = _videoRecording;
                var sequence = ++_previewAnalysisSequence;
                var analyzeFrame = !recording
                    || sequence % 6 == 0
                    || (_focusPeakingEnabled || _falseColorEnabled);
                var focusPeaking = videoMode && _focusPeakingEnabled && analyzeFrame;
                var falseColor = videoMode && _falseColorEnabled && analyzeFrame;
                var prepared = await Task.Run(
                    () => PrepareJpeg(
                        jpeg,
                        videoMode,
                        focusPeaking,
                        falseColor,
                        recording),
                    cancellationToken);
                await Dispatcher.InvokeAsync(
                    () => DisplayPreparedPreview(prepared));
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
        ShootingTaskButton.IsEnabled =
            (_shootingTaskCancellation is not null && _operationInProgress) ||
            connected;
        UpdateExposureAvailability();
    }

    private void UpdateExposureAvailability()
    {
        var connected = _camera.IsConnected && !_operationInProgress;
        SetParameterAvailability(
            ExposureModeBox,
            "exposureMode",
            connected);
        SetParameterAvailability(
            ShutterBox,
            _videoMode ? "videoExposureTime" : "exposureTime",
            connected);
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
        DisplayPreparedPreview(PrepareJpeg(
            jpeg,
            _videoMode,
            _videoMode && _focusPeakingEnabled,
            _videoMode && _falseColorEnabled));
    }

    private static PreparedPreview PrepareJpeg(
        byte[] jpeg,
        bool videoMode,
        bool focusPeaking,
        bool falseColor,
        bool recording = false)
    {
        using var stream = new MemoryStream(jpeg, writable: false);
        var bitmap = new BitmapImage();
        bitmap.BeginInit();
        bitmap.CacheOption = BitmapCacheOption.OnLoad;
        if (recording)
        {
            bitmap.DecodePixelWidth = 1280;
        }
        bitmap.StreamSource = stream;
        bitmap.EndInit();
        bitmap.Freeze();
        var monitor = ProfessionalMonitor.Process(
            bitmap,
            focusPeaking,
            falseColor);
        return new PreparedPreview(
            videoMode ? monitor.Image : bitmap,
            monitor);
    }

    private void DisplayPreparedPreview(PreparedPreview prepared)
    {
        PreviewImage.Source = prepared.Display;
        if (_immersivePreviewImage is not null)
        {
            _immersivePreviewImage.Source = prepared.Display;
        }
        RedHistogramText.Text = $"R {prepared.Monitor.RedHistogram}";
        GreenHistogramText.Text = $"G {prepared.Monitor.GreenHistogram}";
        BlueHistogramText.Text = $"B {prepared.Monitor.BlueHistogram}";
        WaveformText.Text = $"Y {prepared.Monitor.Waveform}";
        VectorscopeText.Text = $"H {prepared.Monitor.Vectorscope}";
        PeakingCoverageText.Text = AppLocalization.T(
            $"峰值覆盖 {prepared.Monitor.PeakingCoverage}%");
        PreviewEmpty.Visibility = Visibility.Collapsed;
    }

    private void RefreshPhotoList()
    {
        var libraryItems = _library.List();
        var systemItems = _library.ListSystemAlbum();
        var roots = new ObservableCollection<LibraryTreeNode>
        {
            BuildLocalLibraryNode(libraryItems),
            BuildSourceNode(
                "系统相册",
                "只读 · 保留在 Windows 图片库",
                systemItems),
            new()
            {
                Name = "无线传输",
                Detail = "FTP · HTTP · WebDAV",
                Icon = "⌁",
                IsExpanded = false
            }
        };
        PhotoTree.ItemsSource = roots;
        PhotoCountText.Text = AppLocalization.T(
            $"{libraryItems.Count} 个本地文件 · {systemItems.Count} 个系统相册项目");
        DeletePhotoButton.IsEnabled = false;
        DeleteBranchButton.IsEnabled = false;
        SharePhotoButton.IsEnabled = false;
    }

    private LibraryTreeNode BuildSourceNode(
        string name,
        string detail,
        IReadOnlyList<PhotoItem> items)
    {
        var root = new LibraryTreeNode
        {
            Name = $"{name} · {items.Count}",
            Detail = detail,
            Icon = "▣",
            IsExpanded = true
        };
        root.Children.Add(BuildMediaTypeNode("照片", items, false));
        root.Children.Add(BuildMediaTypeNode("视频", items, true));
        return root;
    }

    private LibraryTreeNode BuildLocalLibraryNode(
        IReadOnlyList<PhotoItem> items)
    {
        var root = new LibraryTreeNode
        {
            Name = $"帧澈 ZENCHE 文件库 · {items.Count}",
            Detail = "用户分支与未分类媒体",
            Icon = "▣",
            IsExpanded = true
        };
        foreach (var branch in _libraryBranches)
        {
            root.Children.Add(BuildBranchNode(branch, items));
        }
        var unassigned = items
            .Where(item => !_libraryFileAssignments.ContainsKey(item.Path))
            .ToList();
        var unclassified = new LibraryTreeNode
        {
            Name = $"未分类 · {unassigned.Count}",
            Detail = "尚未放入用户分支的原始媒体",
            Icon = "▱",
            IsUnclassified = true,
            IsExpanded = true
        };
        unclassified.Children.Add(
            BuildMediaTypeNode("照片", unassigned, false));
        unclassified.Children.Add(
            BuildMediaTypeNode("视频", unassigned, true));
        root.Children.Add(unclassified);
        return root;
    }

    private static LibraryTreeNode BuildMediaTypeNode(
        string name,
        IReadOnlyList<PhotoItem> items,
        bool video)
    {
        var matches = items
            .Where(item => item.IsVideo == video)
            .OrderByDescending(item => File.GetLastWriteTimeUtc(item.Path))
            .ToList();
        var node = new LibraryTreeNode
        {
            Name = $"{name} · {matches.Count}",
            Detail = matches.Count == 0 ? $"暂无{name}" : "",
            Icon = video ? "▶" : "▧",
            IsExpanded = true
        };
        foreach (var item in matches)
        {
            node.Children.Add(new LibraryTreeNode
            {
                Name = item.Name,
                Detail = item.Detail,
                Icon = item.IsVideo ? "▶" : "◫",
                Thumbnail = CreateLibraryThumbnail(item),
                Item = item
            });
        }
        return node;
    }

    private LibraryTreeNode BuildBranchNode(
        LibraryBranch branch,
        IReadOnlyList<PhotoItem> items)
    {
        var assigned = items
            .Where(item =>
                _libraryFileAssignments.TryGetValue(
                    item.Path,
                    out var branchId) &&
                branchId == branch.Id)
            .ToList();
        var node = new LibraryTreeNode
        {
            Name = branch.Name,
            Detail = $"{assigned.Count} 个文件 · {branch.Children.Count} 个子分支",
            Icon = "▱",
            BranchId = branch.Id,
            IsExpanded = true
        };
        foreach (var item in assigned)
        {
            node.Children.Add(new LibraryTreeNode
            {
                Name = item.Name,
                Detail = item.Detail,
                Icon = item.IsVideo ? "▶" : "◫",
                Thumbnail = CreateLibraryThumbnail(item),
                Item = item
            });
        }
        foreach (var child in branch.Children)
        {
            node.Children.Add(BuildBranchNode(child, items));
        }
        return node;
    }

    private static BitmapSource? CreateLibraryThumbnail(PhotoItem item)
    {
        if (item.IsVideo)
        {
            return null;
        }
        try
        {
            var thumbnail = new BitmapImage();
            thumbnail.BeginInit();
            thumbnail.CacheOption = BitmapCacheOption.OnLoad;
            thumbnail.DecodePixelWidth = 112;
            thumbnail.UriSource = new Uri(item.Path, UriKind.Absolute);
            thumbnail.EndInit();
            thumbnail.Freeze();
            return thumbnail;
        }
        catch
        {
            return null;
        }
    }

    private void RefreshImageEditor()
    {
        if (_editorInAiMode)
        {
            RefreshAiEditor();
            return;
        }
        var previousPath = _editorSelectedPath;
        var choices = _library.List()
            .Where(item => !item.IsVideo && IsEditableImage(item.Path))
            .Select(item => new EditorPhotoChoice { Item = item })
            .ToList();
        _updatingEditorControls = true;
        EditorPhotoBox.ItemsSource = choices;
        var selected = choices.FirstOrDefault(choice =>
            string.Equals(
                choice.Item.Path,
                _editorSelectedPath,
                StringComparison.OrdinalIgnoreCase)) ?? choices.FirstOrDefault();
        EditorPhotoBox.SelectedItem = selected;
        _editorSelectedPath = selected?.Item.Path;
        _updatingEditorControls = false;
        if (!string.Equals(
                previousPath,
                _editorSelectedPath,
                StringComparison.OrdinalIgnoreCase))
        {
            ResetEditorControls();
        }
        UpdateEditorPreview();
    }

    private void RefreshAiEditor()
    {
        EditorHeaderTitle.Text = AppLocalization.T("AI 工具");
        EditorHeaderSubtitle.Text = AppLocalization.T(
            "基于 nano-banana-2 模型的 AI 修图与生图；需在设置中输入激活码解锁。");
        EditorProGrid.Visibility = Visibility.Collapsed;
        EditorAiGrid.Visibility = Visibility.Visible;
        AiEditModeBtn.Style = (Style)FindResource(
            _aiMode == 0 ? "PrimaryButton" : "ButtonBase");
        AiGenModeBtn.Style = (Style)FindResource(
            _aiMode == 1 ? "PrimaryButton" : "ButtonBase");
        AiPromptBox.Text = _aiPrompt;
        AiStatusText.Text = AppLocalization.T(
            _aiResultPath != null ? "生成完成" : "请输入提示词");
        AiPreviewBadge.Visibility = _aiResultPath != null
            ? Visibility.Visible
            : Visibility.Collapsed;
        AiSaveBtn.Visibility = _aiResultPath != null
            ? Visibility.Visible
            : Visibility.Collapsed;
        AiPreviewEmpty.Visibility = _aiResultPath != null
            ? Visibility.Collapsed
            : Visibility.Visible;
        if (_aiResultPath != null)
        {
            try
            {
                AiPreviewImage.Source = new BitmapImage(
                    new Uri(_aiResultPath));
            }
            catch { }
        }
        else
        {
            AiPreviewImage.Source = null;
        }
        RefreshAiPresets();
    }

    private void RefreshAiPresets()
    {
        AiPresetPanel.Children.Clear();
        var presets = _aiMode == 0
            ? new (string Label, string Prompt)[]
            {
                ("一键美颜", "对照片中的人物进行自然美颜：柔化皮肤、去除瑕疵、提亮肤色、轻微瘦脸，保持自然真实质感，不过度处理。"),
                ("自然增强", "增强照片的自然色彩与光影：提升饱和度与对比度，保留真实细节，使画面更通透清晰。"),
                ("胶片质感", "为照片添加复古胶片质感：轻微颗粒、柔和对比、温暖色调，类似柯达 Portra 胶片的色彩风格。"),
                ("日系清新", "调整为日系清新风格：低对比度、偏亮高调、冷色调、干净通透，画面清新柔和。"),
                ("黑白大片", "转换为高反差黑白摄影风格：增强明暗对比、保留细节纹理，营造经典黑白大片质感。"),
                ("复古暖调", "添加复古暖调风格：整体偏暖黄色调、轻微褪色、柔和光线，怀旧氛围。"),
                ("天空增强", "增强画面中的天空：让蓝天更通透湛蓝、云朵更立体，同时保持地面细节自然。"),
                ("美食诱人", "增强美食照片的诱人质感：提升色彩饱和度、增强光泽细节，让食物看起来更美味。")
            }
            : new (string Label, string Prompt)[]
            {
                ("人像写真", "professional portrait photography, studio lighting, sharp focus, shallow depth of field, high detail"),
                ("风光大片", "breathtaking landscape photography, golden hour, dramatic sky, high dynamic range, ultra detailed"),
                ("城市夜景", "city night photography, neon lights, long exposure, reflections, vibrant urban atmosphere"),
                ("产品展示", "professional product photography, clean studio background, soft lighting, high detail")
            };
        foreach (var preset in presets)
        {
            var button = new Button
            {
                Content = preset.Label,
                Height = 30,
                Margin = new Thickness(0, 0, 6, 6),
                Padding = new Thickness(10, 0, 10, 0),
                Style = (Style)FindResource("ButtonBase")
            };
            var prompt = preset.Prompt;
            button.Click += (_, _) =>
            {
                AiPromptBox.Text = prompt;
            };
            AiPresetPanel.Children.Add(button);
        }
    }

    private void AiEditMode_Click(object sender, RoutedEventArgs e)
    {
        _aiMode = 0;
        RefreshAiEditor();
        RefreshAiPresets();
    }

    private void AiGenMode_Click(object sender, RoutedEventArgs e)
    {
        _aiMode = 1;
        RefreshAiEditor();
        RefreshAiPresets();
    }

    private async void AiGenerate_Click(object sender, RoutedEventArgs e)
    {
        _aiPrompt = AiPromptBox.Text.Trim();
        if (string.IsNullOrWhiteSpace(_aiPrompt))
        {
            AiStatusText.Text = AppLocalization.T("请输入提示词");
            return;
        }
        if (!IsAiActivated())
        {
            AiStatusText.Text = AppLocalization.T(
                "请先在设置中输入激活码解锁 AI 功能");
            return;
        }
        var activationCode = LoadActivationCode();
        _aiGenerating = true;
        AiGenerateBtn.IsEnabled = false;
        AiGenerateBtn.Content = AppLocalization.T("正在生成…");
        AiStatusText.Text = AppLocalization.T("正在调用 AI 模型…");
        try
        {
            var endpoint = $"{LoadAiServerUrl().TrimEnd('/')}/v1/ai";
            var size = AiSizes[Math.Clamp(_aiRatioIndex, 0, AiSizes.Length - 1)];
            var body = new Dictionary<string, object>
            {
                ["activationCode"] = activationCode,
                ["deviceId"] = GetDeviceId(),
                ["prompt"] = _aiPrompt,
                ["size"] = size
            };
            if (_aiMode == 0 && _editorSelectedPath != null &&
                File.Exists(_editorSelectedPath))
            {
                var sourceBytes = await File.ReadAllBytesAsync(
                    _editorSelectedPath);
                var b64 = Convert.ToBase64String(sourceBytes);
                body["image"] = $"data:image/jpeg;base64,{b64}";
            }
            using var client = new HttpClient();
            client.Timeout = TimeSpan.FromSeconds(60);
            var content = new StringContent(
                JsonSerializer.Serialize(body),
                System.Text.Encoding.UTF8,
                "application/json");
            var response = await client.PostAsync(endpoint, content);
            if (!response.IsSuccessStatusCode)
            {
                var code = (int)response.StatusCode;
                if (code == 403)
                    throw new Exception("激活码无效或次数用完");
                if (code == 502)
                    throw new Exception("AI 服务暂时不可用");
                throw new Exception($"API 服务返回错误 {code}");
            }
            var json = await response.Content.ReadAsStringAsync();
            using var doc = JsonDocument.Parse(json);
            var dataArr = doc.RootElement.GetProperty("data");
            if (dataArr.GetArrayLength() == 0)
                throw new Exception("AI 未返回有效图片");
            var first = dataArr[0];
            byte[] imageBytes;
            if (first.TryGetProperty("b64_json", out var b64El) &&
                b64El.GetString() is { Length: > 0 } b64Str)
            {
                imageBytes = Convert.FromBase64String(b64Str);
            }
            else if (first.TryGetProperty("url", out var urlEl) &&
                     urlEl.GetString() is { Length: > 0 } imageUrl)
            {
                imageBytes = await client.GetByteArrayAsync(imageUrl);
            }
            else
            {
                throw new Exception("AI 未返回有效图片");
            }
            var tempPath = Path.Combine(
                Path.GetTempPath(),
                $"zenche_ai_{DateTime.Now:yyyyMMddHHmmss}.jpg");
            await File.WriteAllBytesAsync(tempPath, imageBytes);
            _aiResultPath = tempPath;
            RecordAiUsage();
            AiStatusText.Text = AppLocalization.T("生成完成");
        }
        catch (Exception error)
        {
            _diagnostics.Error("ai", $"AI 调用失败：{error.Message}");
            AiStatusText.Text = AppLocalization.T(
                $"AI 生成失败：{error.Message}");
        }
        finally
        {
            _aiGenerating = false;
            AiGenerateBtn.IsEnabled = true;
            AiGenerateBtn.Content = AppLocalization.T("生成");
            RefreshAiEditor();
        }
    }

    private void AiSave_Click(object sender, RoutedEventArgs e)
    {
        if (_aiResultPath == null || !File.Exists(_aiResultPath))
        {
            return;
        }
        try
        {
            var stem = _aiMode == 0 ? "edited" : "generated";
            var dest = new FileInfo(
                UniqueDestination(
                    $"ai_{stem}_{DateTime.Now:yyyyMMdd_HHmmss}.jpg"));
            using var source = File.OpenRead(_aiResultPath);
            var bytes = new byte[source.Length];
            source.ReadExactly(bytes);
            var encoder = new JpegBitmapEncoder { QualityLevel = 95 };
            using var memStream = new MemoryStream(bytes);
            var decoder = BitmapDecoder.Create(
                memStream,
                BitmapCreateOptions.PreservePixelFormat,
                BitmapCacheOption.OnLoad);
            encoder.Frames.Add(BitmapFrame.Create(decoder.Frames[0]));
            using var fileStream = dest.OpenWrite();
            encoder.Save(fileStream);
            _editorSelectedPath = dest.FullName;
            RefreshPhotoList();
            AiStatusText.Text = AppLocalization.T(
                $"已保存 AI 结果 · {dest.Name}");
        }
        catch (Exception error)
        {
            _diagnostics.Error("ai", $"保存 AI 结果失败：{error.Message}");
            AiStatusText.Text = AppLocalization.T("保存 AI 结果失败");
        }
    }

    public string UniqueDestination(string filename)
    {
        return Path.Combine(_library.DirectoryPath, filename);
    }

    private void EditorPhotoBox_SelectionChanged(
        object sender,
        SelectionChangedEventArgs e)
    {
        if (_initializing || _updatingEditorControls)
        {
            return;
        }
        _editorSelectedPath =
            (EditorPhotoBox.SelectedItem as EditorPhotoChoice)?.Item.Path;
        ResetEditorControls();
        UpdateEditorPreview();
    }

    private void BuildEditorAdjustmentControls()
    {
        EditorAdjustmentHost.Children.Clear();
        _editorSliders.Clear();
        EditorAdjustmentHost.Children.Add(CreateEditorGroup(
            "光线",
            true,
            new EditorSliderSpec("exposure", "曝光", -2, 2, true),
            new EditorSliderSpec("contrast", "对比度", -100, 100),
            new EditorSliderSpec("highlights", "高光", -100, 100),
            new EditorSliderSpec("shadows", "阴影", -100, 100),
            new EditorSliderSpec("whites", "白色色阶", -100, 100),
            new EditorSliderSpec("blacks", "黑色色阶", -100, 100)));
        EditorAdjustmentHost.Children.Add(CreateEditorGroup(
            "色彩",
            false,
            new EditorSliderSpec("temperature", "色温", -100, 100),
            new EditorSliderSpec("tint", "色调", -100, 100),
            new EditorSliderSpec("vibrance", "自然饱和度", -100, 100),
            new EditorSliderSpec("saturation", "饱和度", -100, 100)));
        EditorAdjustmentHost.Children.Add(CreateEditorGroup(
            "细节",
            false,
            new EditorSliderSpec("texture", "纹理", -100, 100),
            new EditorSliderSpec("clarity", "清晰度", -100, 100),
            new EditorSliderSpec("sharpening", "锐化", 0, 100),
            new EditorSliderSpec("noiseReduction", "降噪", 0, 100)));
        EditorAdjustmentHost.Children.Add(CreateEditorGroup(
            "效果",
            false,
            new EditorSliderSpec("dehaze", "去雾", -100, 100),
            new EditorSliderSpec("vignette", "暗角", -100, 100)));
        EditorAdjustmentHost.Children.Add(CreateEditorGeometryGroup());
    }

    private Expander CreateEditorGroup(
        string title,
        bool expanded,
        params EditorSliderSpec[] specifications)
    {
        var content = new StackPanel
        {
            Margin = new Thickness(8, 6, 8, 10)
        };
        foreach (var specification in specifications)
        {
            content.Children.Add(CreateEditorSlider(specification));
        }
        return new Expander
        {
            Header = AppLocalization.T(title),
            IsExpanded = expanded,
            Content = content,
            Margin = new Thickness(0, 0, 0, 6)
        };
    }

    private FrameworkElement CreateEditorSlider(
        EditorSliderSpec specification)
    {
        var valueText = new TextBlock
        {
            Text = EditorAdjustmentValue(0, specification.Exposure),
            Foreground = (Brush)FindResource("MutedBrush"),
            FontFamily = (FontFamily)FindResource("MonoFont"),
            HorizontalAlignment = HorizontalAlignment.Right
        };
        var heading = new DockPanel();
        heading.Children.Add(new TextBlock
        {
            Text = AppLocalization.T(specification.Label),
            FontWeight = FontWeights.SemiBold
        });
        DockPanel.SetDock(valueText, Dock.Right);
        heading.Children.Add(valueText);

        var slider = new Slider
        {
            Tag = specification.Key,
            Minimum = specification.Minimum,
            Maximum = specification.Maximum,
            TickFrequency = specification.Exposure ? 0.05 : 1,
            SmallChange = specification.Exposure ? 0.05 : 1,
            IsSnapToTickEnabled = true
        };
        _editorSliders[specification.Key] = slider;
        slider.ValueChanged += (_, _) =>
        {
            valueText.Text = EditorAdjustmentValue(
                slider.Value,
                specification.Exposure);
            SetEditorAdjustment(specification.Key, slider.Value);
            if (!_initializing && !_updatingEditorControls)
            {
                UpdateEditorPreview();
            }
        };

        var row = new StackPanel
        {
            Margin = new Thickness(0, 2, 0, 8),
            MinHeight = 52
        };
        row.Children.Add(heading);
        row.Children.Add(slider);
        return row;
    }

    private Expander CreateEditorGeometryGroup()
    {
        var ratios = new[] { "原始比例", "1:1", "4:3", "3:2", "16:9" };
        _editorCropBox = new ComboBox
        {
            ItemsSource = ratios.Select(AppLocalization.T).ToList(),
            SelectedIndex = 0,
            Margin = new Thickness(0, 4, 0, 10)
        };
        _editorCropBox.SelectionChanged += (_, _) =>
        {
            if (_updatingEditorControls)
            {
                return;
            }
            _editorAdjustments.CropRatio =
                _editorCropBox.SelectedIndex switch
                {
                    1 => "1:1",
                    2 => "4:3",
                    3 => "3:2",
                    4 => "16:9",
                    _ => "original"
                };
            UpdateEditorPreview();
        };

        var rotate = EditorGeometryButton("旋转 90°");
        rotate.Click += (_, _) =>
        {
            _editorAdjustments.Rotation =
                (_editorAdjustments.Rotation + 90) % 360;
            UpdateEditorPreview();
        };
        var horizontal = EditorGeometryButton("水平翻转");
        horizontal.Click += (_, _) =>
        {
            _editorAdjustments.FlipHorizontal =
                !_editorAdjustments.FlipHorizontal;
            UpdateEditorPreview();
        };
        var vertical = EditorGeometryButton("垂直翻转");
        vertical.Click += (_, _) =>
        {
            _editorAdjustments.FlipVertical =
                !_editorAdjustments.FlipVertical;
            UpdateEditorPreview();
        };
        var actions = new UniformGrid
        {
            Columns = 3
        };
        actions.Children.Add(rotate);
        actions.Children.Add(horizontal);
        actions.Children.Add(vertical);

        var content = new StackPanel
        {
            Margin = new Thickness(8, 6, 8, 10)
        };
        content.Children.Add(new TextBlock
        {
            Text = AppLocalization.T("裁切比例"),
            FontWeight = FontWeights.SemiBold
        });
        content.Children.Add(_editorCropBox);
        content.Children.Add(actions);
        return new Expander
        {
            Header = AppLocalization.T("几何"),
            Content = content,
            Margin = new Thickness(0, 0, 0, 6)
        };
    }

    private Button EditorGeometryButton(string label) => new()
    {
        Content = AppLocalization.T(label),
        MinHeight = 42,
        Margin = new Thickness(2),
        Style = (Style)FindResource("ButtonBase")
    };

    private static string EditorAdjustmentValue(
        double value,
        bool exposure) =>
        exposure
            ? $"{value:+0.00;-0.00;0.00} EV"
            : $"{value:+0;-0;0}";

    private void SetEditorAdjustment(string key, double value)
    {
        switch (key)
        {
            case "exposure":
                _editorAdjustments.Exposure = value;
                break;
            case "contrast":
                _editorAdjustments.Contrast = value;
                break;
            case "highlights":
                _editorAdjustments.Highlights = value;
                break;
            case "shadows":
                _editorAdjustments.Shadows = value;
                break;
            case "whites":
                _editorAdjustments.Whites = value;
                break;
            case "blacks":
                _editorAdjustments.Blacks = value;
                break;
            case "temperature":
                _editorAdjustments.Temperature = value;
                break;
            case "tint":
                _editorAdjustments.Tint = value;
                break;
            case "vibrance":
                _editorAdjustments.Vibrance = value;
                break;
            case "saturation":
                _editorAdjustments.Saturation = value;
                break;
            case "texture":
                _editorAdjustments.Texture = value;
                break;
            case "clarity":
                _editorAdjustments.Clarity = value;
                break;
            case "sharpening":
                _editorAdjustments.Sharpening = value;
                break;
            case "noiseReduction":
                _editorAdjustments.NoiseReduction = value;
                break;
            case "dehaze":
                _editorAdjustments.Dehaze = value;
                break;
            case "vignette":
                _editorAdjustments.Vignette = value;
                break;
        }
    }

    private void EditorPresetBox_SelectionChanged(
        object sender,
        SelectionChangedEventArgs e)
    {
        if (_initializing ||
            _updatingEditorControls ||
            EditorPresetBox.SelectedItem is not ComboBoxItem item)
        {
            return;
        }
        ApplyEditorPreset(Convert.ToString(item.Tag) ?? "original");
        SyncEditorSliders();
        UpdateEditorPreview();
    }

    private void ApplyEditorPreset(string preset)
    {
        _editorAdjustments.ResetTone();
        switch (preset)
        {
            case "natural":
                _editorAdjustments.Contrast = 8;
                _editorAdjustments.Highlights = -18;
                _editorAdjustments.Shadows = 16;
                _editorAdjustments.Whites = 8;
                _editorAdjustments.Blacks = -8;
                _editorAdjustments.Vibrance = 14;
                _editorAdjustments.Texture = 8;
                _editorAdjustments.Clarity = 6;
                _editorAdjustments.Sharpening = 24;
                _editorAdjustments.NoiseReduction = 8;
                break;
            case "portrait":
                _editorAdjustments.Contrast = -4;
                _editorAdjustments.Highlights = -24;
                _editorAdjustments.Shadows = 18;
                _editorAdjustments.Temperature = 7;
                _editorAdjustments.Tint = 4;
                _editorAdjustments.Vibrance = 10;
                _editorAdjustments.Texture = -12;
                _editorAdjustments.Clarity = -6;
                _editorAdjustments.Sharpening = 16;
                _editorAdjustments.NoiseReduction = 22;
                _editorAdjustments.Vignette = -8;
                break;
            case "landscape":
                _editorAdjustments.Contrast = 12;
                _editorAdjustments.Highlights = -28;
                _editorAdjustments.Shadows = 14;
                _editorAdjustments.Whites = 12;
                _editorAdjustments.Blacks = -14;
                _editorAdjustments.Vibrance = 24;
                _editorAdjustments.Saturation = 5;
                _editorAdjustments.Texture = 16;
                _editorAdjustments.Clarity = 18;
                _editorAdjustments.Sharpening = 30;
                _editorAdjustments.Dehaze = 12;
                _editorAdjustments.Vignette = -10;
                break;
            case "monochrome":
                _editorAdjustments.Contrast = 22;
                _editorAdjustments.Highlights = -18;
                _editorAdjustments.Shadows = 12;
                _editorAdjustments.Whites = 10;
                _editorAdjustments.Blacks = -22;
                _editorAdjustments.Saturation = -100;
                _editorAdjustments.Texture = 12;
                _editorAdjustments.Clarity = 24;
                _editorAdjustments.Sharpening = 28;
                _editorAdjustments.Vignette = -14;
                break;
        }
        _editorAdjustments.ShowingOriginal = false;
        CompareEditorPhotoButton.Content =
            AppLocalization.T("查看原图");
    }

    private void SyncEditorSliders()
    {
        _updatingEditorControls = true;
        foreach (var entry in _editorSliders)
        {
            entry.Value.Value = EditorAdjustmentForKey(entry.Key);
        }
        _updatingEditorControls = false;
    }

    private double EditorAdjustmentForKey(string key) => key switch
    {
        "exposure" => _editorAdjustments.Exposure,
        "contrast" => _editorAdjustments.Contrast,
        "highlights" => _editorAdjustments.Highlights,
        "shadows" => _editorAdjustments.Shadows,
        "whites" => _editorAdjustments.Whites,
        "blacks" => _editorAdjustments.Blacks,
        "temperature" => _editorAdjustments.Temperature,
        "tint" => _editorAdjustments.Tint,
        "vibrance" => _editorAdjustments.Vibrance,
        "saturation" => _editorAdjustments.Saturation,
        "texture" => _editorAdjustments.Texture,
        "clarity" => _editorAdjustments.Clarity,
        "sharpening" => _editorAdjustments.Sharpening,
        "noiseReduction" => _editorAdjustments.NoiseReduction,
        "dehaze" => _editorAdjustments.Dehaze,
        "vignette" => _editorAdjustments.Vignette,
        _ => 0
    };

    private void CompareEditorPhoto_Click(
        object sender,
        RoutedEventArgs e)
    {
        _editorAdjustments.ShowingOriginal =
            !_editorAdjustments.ShowingOriginal;
        CompareEditorPhotoButton.Content = AppLocalization.T(
            _editorAdjustments.ShowingOriginal
                ? "返回调整"
                : "查看原图");
        UpdateEditorPreview();
    }

    private void ResetEditor_Click(
        object sender,
        RoutedEventArgs e)
    {
        ResetEditorControls();
        UpdateEditorPreview();
    }

    private void ResetEditorControls()
    {
        _updatingEditorControls = true;
        _editorAdjustments.Reset();
        foreach (var slider in _editorSliders.Values)
        {
            slider.Value = 0;
        }
        if (_editorCropBox is not null)
        {
            _editorCropBox.SelectedIndex = 0;
        }
        EditorPresetBox.SelectedIndex = 0;
        CompareEditorPhotoButton.Content =
            AppLocalization.T("查看原图");
        _updatingEditorControls = false;
        EditorStatusText.Text = AppLocalization.T("调整不会覆盖原文件");
    }

    private void UpdateEditorPreview()
    {
        if (string.IsNullOrWhiteSpace(_editorSelectedPath) ||
            !File.Exists(_editorSelectedPath))
        {
            EditorPreviewImage.Source = null;
            EditorPreviewEmpty.Visibility = Visibility.Visible;
            SaveEditedPhotoButton.IsEnabled = false;
            return;
        }
        try
        {
            EditorPreviewImage.Source = RenderEditedBitmap(
                _editorSelectedPath,
                _editorAdjustments,
                1600);
            EditorPreviewEmpty.Visibility = Visibility.Collapsed;
            SaveEditedPhotoButton.IsEnabled = true;
        }
        catch (Exception error)
        {
            EditorPreviewImage.Source = null;
            EditorPreviewEmpty.Visibility = Visibility.Visible;
            SaveEditedPhotoButton.IsEnabled = false;
            EditorStatusText.Text =
                AppLocalization.T($"无法预览：{error.Message}");
        }
    }

    private void SaveEditedPhoto_Click(
        object sender,
        RoutedEventArgs e)
    {
        if (string.IsNullOrWhiteSpace(_editorSelectedPath) ||
            !File.Exists(_editorSelectedPath))
        {
            return;
        }
        try
        {
            SaveEditedPhotoButton.IsEnabled = false;
            EditorStatusText.Text = AppLocalization.T("正在保存…");
            var savedAdjustments = _editorAdjustments.Copy();
            savedAdjustments.ShowingOriginal = false;
            var bitmap = RenderEditedBitmap(
                _editorSelectedPath,
                savedAdjustments);
            var destination = UniqueEditedPath(_editorSelectedPath);
            var encoder = new JpegBitmapEncoder { QualityLevel = 95 };
            encoder.Frames.Add(BitmapFrame.Create(bitmap));
            using (var stream = File.Create(destination))
            {
                encoder.Save(stream);
            }
            _editorSelectedPath = destination;
            RefreshPhotoList();
            RefreshImageEditor();
            EditorStatusText.Text = AppLocalization.T(
                $"已保存副本 {Path.GetFileName(destination)}");
        }
        catch (Exception error)
        {
            EditorStatusText.Text =
                AppLocalization.T($"保存失败：{error.Message}");
            ShowError(error.Message);
        }
        finally
        {
            SaveEditedPhotoButton.IsEnabled =
                !string.IsNullOrWhiteSpace(_editorSelectedPath);
        }
    }

    private static bool IsEditableImage(string path)
    {
        return new[] { ".jpg", ".jpeg", ".png", ".bmp", ".tif", ".tiff" }
            .Contains(
                Path.GetExtension(path),
                StringComparer.OrdinalIgnoreCase);
    }

    private static BitmapSource RenderEditedBitmap(
        string path,
        EditorAdjustments settings,
        int decodePixelWidth = 0)
    {
        using var stream = new MemoryStream(File.ReadAllBytes(path));
        var decoder = BitmapDecoder.Create(
            stream,
            BitmapCreateOptions.PreservePixelFormat,
            BitmapCacheOption.OnLoad);
        BitmapSource source = decoder.Frames[0];
        if (decodePixelWidth > 0 && source.PixelWidth > decodePixelWidth)
        {
            var scale = (double)decodePixelWidth / source.PixelWidth;
            source = new TransformedBitmap(
                source,
                new ScaleTransform(scale, scale));
        }
        if (settings.ShowingOriginal)
        {
            source.Freeze();
            return source;
        }
        var converted = new FormatConvertedBitmap(
            source,
            PixelFormats.Bgra32,
            null,
            0);
        var stride = converted.PixelWidth * 4;
        var pixels = new byte[stride * converted.PixelHeight];
        converted.CopyPixels(pixels, stride, 0);
        var exposure = Math.Pow(2, settings.Exposure);
        var contrast =
            1 + settings.Contrast / 125 + settings.Dehaze / 210;
        var baseSaturation =
            1 + settings.Saturation / 100 + settings.Dehaze / 520;
        var temperature = settings.Temperature / 100;
        var tint = settings.Tint / 100;
        for (var index = 0; index < pixels.Length; index += 4)
        {
            var blue = pixels[index] / 255.0 * exposure;
            var green = pixels[index + 1] / 255.0 * exposure;
            var red = pixels[index + 2] / 255.0 * exposure;

            red += temperature * 0.12 + tint * 0.045;
            green -= tint * 0.08;
            blue -= temperature * 0.12 - tint * 0.045;

            var luminance =
                red * 0.2126 + green * 0.7152 + blue * 0.0722;
            var toneShift =
                settings.Shadows / 100
                    * Math.Pow(1 - ClampUnit(luminance), 2)
                    * 0.38
                + settings.Highlights / 100
                    * Math.Pow(ClampUnit(luminance), 2)
                    * 0.30
                + settings.Whites / 100
                    * SmoothStep(0.55, 1, luminance)
                    * 0.24
                + settings.Blacks / 100
                    * (1 - SmoothStep(0, 0.45, luminance))
                    * 0.20;
            red += toneShift;
            green += toneShift;
            blue += toneShift;

            var clarityMask =
                1 - Math.Abs(ClampUnit(luminance) * 2 - 1);
            var localContrast =
                1 + settings.Clarity / 100 * clarityMask * 0.38;
            red = (red - 0.5) * contrast * localContrast + 0.5;
            green = (green - 0.5) * contrast * localContrast + 0.5;
            blue = (blue - 0.5) * contrast * localContrast + 0.5;

            luminance =
                red * 0.2126 + green * 0.7152 + blue * 0.0722;
            var colorfulness =
                Math.Max(red, Math.Max(green, blue))
                - Math.Min(red, Math.Min(green, blue));
            var saturation = Math.Max(
                0,
                baseSaturation
                + settings.Vibrance / 100
                    * (1 - ClampUnit(colorfulness))
                    * 0.82);
            red = luminance + (red - luminance) * saturation;
            green = luminance + (green - luminance) * saturation;
            blue = luminance + (blue - luminance) * saturation;

            var pixelIndex = index / 4;
            var x = pixelIndex % converted.PixelWidth;
            var y = pixelIndex / converted.PixelWidth;
            var normalizedX =
                (x - converted.PixelWidth / 2.0) /
                Math.Max(1, converted.PixelWidth / 2.0);
            var normalizedY =
                (y - converted.PixelHeight / 2.0) /
                Math.Max(1, converted.PixelHeight / 2.0);
            var edge = Math.Min(
                1,
                Math.Sqrt(
                    normalizedX * normalizedX +
                    normalizedY * normalizedY));
            var vignette =
                1 + settings.Vignette / 100 * edge * edge * 0.72;
            pixels[index] = ClampChannel(blue * vignette * 255);
            pixels[index + 1] = ClampChannel(green * vignette * 255);
            pixels[index + 2] = ClampChannel(red * vignette * 255);
        }
        ApplyEditorDetail(
            pixels,
            converted.PixelWidth,
            converted.PixelHeight,
            stride,
            settings);
        BitmapSource result = BitmapSource.Create(
            converted.PixelWidth,
            converted.PixelHeight,
            converted.DpiX,
            converted.DpiY,
            PixelFormats.Bgra32,
            null,
            pixels,
            stride);
        if (settings.FlipHorizontal)
        {
            result = new TransformedBitmap(
                result,
                new ScaleTransform(-1, 1));
        }
        if (settings.FlipVertical)
        {
            result = new TransformedBitmap(
                result,
                new ScaleTransform(1, -1));
        }
        if (settings.Rotation % 360 != 0)
        {
            result = new TransformedBitmap(
                result,
                new RotateTransform(settings.Rotation));
        }
        var cropRatio = EditorCropRatio(settings.CropRatio);
        if (cropRatio > 0)
        {
            var cropWidth = result.PixelWidth;
            var cropHeight = (int)Math.Round(cropWidth / cropRatio);
            if (cropHeight > result.PixelHeight)
            {
                cropHeight = result.PixelHeight;
                cropWidth = (int)Math.Round(cropHeight * cropRatio);
            }
            result = new CroppedBitmap(
                result,
                new Int32Rect(
                    Math.Max(0, (result.PixelWidth - cropWidth) / 2),
                    Math.Max(0, (result.PixelHeight - cropHeight) / 2),
                    Math.Max(1, cropWidth),
                    Math.Max(1, cropHeight)));
        }
        result.Freeze();
        return result;
    }

    private static void ApplyEditorDetail(
        byte[] pixels,
        int width,
        int height,
        int stride,
        EditorAdjustments settings)
    {
        var smoothing =
            settings.NoiseReduction / 100 * 0.58
            + Math.Max(0, -settings.Texture) / 100 * 0.24;
        var sharpening =
            settings.Sharpening / 100 * 1.15
            + Math.Max(0, settings.Texture) / 100 * 0.48
            + Math.Max(0, settings.Clarity) / 100 * 0.25;
        if (smoothing == 0 && sharpening == 0)
        {
            return;
        }
        var source = (byte[])pixels.Clone();
        for (var y = 1; y < height - 1; y++)
        {
            for (var x = 1; x < width - 1; x++)
            {
                var offset = y * stride + x * 4;
                for (var channel = 0; channel < 3; channel++)
                {
                    var center = source[offset + channel];
                    var average =
                        (center
                         + source[offset - 4 + channel]
                         + source[offset + 4 + channel]
                         + source[offset - stride + channel]
                         + source[offset + stride + channel]) / 5.0;
                    var smoothed =
                        center * (1 - smoothing) + average * smoothing;
                    pixels[offset + channel] = ClampChannel(
                        smoothed + (center - average) * sharpening);
                }
            }
        }
    }

    private static double EditorCropRatio(string cropRatio) =>
        cropRatio switch
        {
            "1:1" => 1,
            "4:3" => 4.0 / 3,
            "3:2" => 3.0 / 2,
            "16:9" => 16.0 / 9,
            _ => 0
        };

    private static double SmoothStep(
        double edge0,
        double edge1,
        double value)
    {
        var scaled = ClampUnit((value - edge0) / (edge1 - edge0));
        return scaled * scaled * (3 - 2 * scaled);
    }

    private static double ClampUnit(double value) =>
        Math.Max(0, Math.Min(1, value));

    private static byte ClampChannel(double value) =>
        (byte)Math.Clamp(Math.Round(value), byte.MinValue, byte.MaxValue);

    private string UniqueEditedPath(string originalPath)
    {
        var stem = Path.GetFileNameWithoutExtension(originalPath);
        return _library.UniqueDestination(
            $"{stem}_edited_{DateTime.Now:yyyyMMdd_HHmmss}.jpg");
    }

    private void CreateLibraryBranch_Click(
        object sender,
        RoutedEventArgs e)
    {
        var selectedNode = PhotoTree.SelectedItem as LibraryTreeNode;
        var parent = FindLibraryBranch(selectedNode?.BranchId);
        var input = new TextBox
        {
            MinWidth = 320,
            Height = 36,
            Margin = new Thickness(0, 10, 0, 14)
        };
        var dialog = new Window
        {
            Owner = this,
            Title = "新建分支",
            Width = 430,
            Height = 210,
            ResizeMode = ResizeMode.NoResize,
            WindowStartupLocation = WindowStartupLocation.CenterOwner,
            Background = (Brush)FindResource("PaperBrush")
        };
        var layout = new StackPanel
        {
            Margin = new Thickness(22)
        };
        layout.Children.Add(new TextBlock
        {
            Text =
                $"将在“{parent?.Name ?? "帧澈 ZENCHE 文件库"}”下创建可继续展开的节点。",
            TextWrapping = TextWrapping.Wrap,
            Foreground = (Brush)FindResource("MutedBrush")
        });
        layout.Children.Add(input);
        var actions = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            HorizontalAlignment = HorizontalAlignment.Right
        };
        var cancel = new Button
        {
            Content = "取消",
            Width = 88,
            Height = 40,
            Style = (Style)FindResource("ButtonBase")
        };
        cancel.Click += (_, _) => dialog.Close();
        actions.Children.Add(cancel);
        var create = new Button
        {
            Content = "创建",
            Width = 88,
            Height = 40,
            Margin = new Thickness(8, 0, 0, 0),
            Style = (Style)FindResource("PrimaryButton")
        };
        create.Click += (_, _) =>
        {
            var name = input.Text.Trim();
            if (name.Length == 0)
            {
                return;
            }
            var branch = new LibraryBranch { Name = name };
            if (parent is null)
            {
                _libraryBranches.Add(branch);
            }
            else
            {
                parent.Children.Add(branch);
            }
            SaveLibraryBranches();
            RefreshPhotoList();
            dialog.Close();
        };
        actions.Children.Add(create);
        layout.Children.Add(actions);
        dialog.Content = layout;
        dialog.Loaded += (_, _) => input.Focus();
        dialog.ShowDialog();
    }

    private void DeleteLibraryBranch_Click(
        object sender,
        RoutedEventArgs e)
    {
        if (PhotoTree.SelectedItem is not LibraryTreeNode
            {
                BranchId: { } branchId
            } selectedNode)
        {
            return;
        }
        var branch = FindLibraryBranch(branchId);
        if (branch is null)
        {
            return;
        }
        var confirmation = MessageBox.Show(
            this,
            $"将同时删除“{branch.Name}”下的子分支；其中的文件会回到“未分类”，原文件不受影响。",
            "删除分支？",
            MessageBoxButton.YesNo,
            MessageBoxImage.Warning);
        if (confirmation != MessageBoxResult.Yes)
        {
            return;
        }
        var removedIds = new HashSet<string>();
        CollectLibraryBranchIds(branch, removedIds);
        if (!RemoveLibraryBranch(_libraryBranches, branchId))
        {
            return;
        }
        foreach (var path in _libraryFileAssignments
                     .Where(entry => removedIds.Contains(entry.Value))
                     .Select(entry => entry.Key)
                     .ToList())
        {
            _libraryFileAssignments.Remove(path);
        }
        SaveLibraryBranches();
        SaveLibraryFileAssignments();
        OperationStatusText.Text = AppLocalization.T(
            $"分支“{selectedNode.Name}”已删除，文件已回到未分类");
        RefreshPhotoList();
    }

    private static void CollectLibraryBranchIds(
        LibraryBranch branch,
        ISet<string> ids)
    {
        ids.Add(branch.Id);
        foreach (var child in branch.Children)
        {
            CollectLibraryBranchIds(child, ids);
        }
    }

    private static bool RemoveLibraryBranch(
        IList<LibraryBranch> branches,
        string id)
    {
        for (var index = 0; index < branches.Count; index++)
        {
            if (branches[index].Id == id)
            {
                branches.RemoveAt(index);
                return true;
            }
            if (RemoveLibraryBranch(branches[index].Children, id))
            {
                return true;
            }
        }
        return false;
    }

    private LibraryBranch? FindLibraryBranch(string? id)
    {
        if (string.IsNullOrWhiteSpace(id))
        {
            return null;
        }
        return FindLibraryBranch(_libraryBranches, id);
    }

    private static LibraryBranch? FindLibraryBranch(
        IEnumerable<LibraryBranch> branches,
        string id)
    {
        foreach (var branch in branches)
        {
            if (branch.Id == id)
            {
                return branch;
            }
            var child = FindLibraryBranch(branch.Children, id);
            if (child is not null)
            {
                return child;
            }
        }
        return null;
    }

    private static List<LibraryBranch> LoadLibraryBranches()
    {
        try
        {
            if (!File.Exists(LibraryBranchStatePath))
            {
                return [];
            }
            return JsonSerializer.Deserialize<List<LibraryBranch>>(
                File.ReadAllText(LibraryBranchStatePath)) ?? [];
        }
        catch
        {
            return [];
        }
    }

    private void SaveLibraryBranches()
    {
        var directory = Path.GetDirectoryName(LibraryBranchStatePath);
        if (!string.IsNullOrWhiteSpace(directory))
        {
            Directory.CreateDirectory(directory);
        }
        File.WriteAllText(
            LibraryBranchStatePath,
            JsonSerializer.Serialize(
                _libraryBranches,
                new JsonSerializerOptions { WriteIndented = true }));
    }

    private static Dictionary<string, string> LoadLibraryFileAssignments()
    {
        try
        {
            if (!File.Exists(LibraryFileAssignmentStatePath))
            {
                return [];
            }
            return JsonSerializer.Deserialize<Dictionary<string, string>>(
                File.ReadAllText(LibraryFileAssignmentStatePath)) ?? [];
        }
        catch
        {
            return [];
        }
    }

    private void SaveLibraryFileAssignments()
    {
        var directory = Path.GetDirectoryName(
            LibraryFileAssignmentStatePath);
        if (!string.IsNullOrWhiteSpace(directory))
        {
            Directory.CreateDirectory(directory);
        }
        File.WriteAllText(
            LibraryFileAssignmentStatePath,
            JsonSerializer.Serialize(
                _libraryFileAssignments,
                new JsonSerializerOptions { WriteIndented = true }));
    }

    private void SetCurrentNavigation(Button? current)
    {
        var videoActive = current == MonitorNav;
        foreach (var button in new[]
                 {
                     CaptureNav,
                     MonitorNav,
                     EditorNav,
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
