using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Threading;
using Microsoft.Win32;
using NikonLink.Windows.Services;

namespace NikonLink.Windows;

public partial class App : Application
{
    private const string ThemeLightSource = "Themes/Theme.Light.xaml";
    private const string ThemeDarkSource = "Themes/Theme.Dark.xaml";

    protected override void OnStartup(StartupEventArgs e)
    {
        DispatcherUnhandledException += HandleUnhandledException;
        DiagnosticLogger.Shared.StartSession();
        // v1.5.6 dual-theme: follow the Windows system app theme, live.
        ApplySystemTheme();
        SystemEvents.UserPreferenceChanged += OnUserPreferenceChanged;
        ShowSplash();
        base.OnStartup(e);
    }

    /// <summary>
    /// Swaps the merged theme dictionary to match the current Windows app theme.
    /// Brushes are single shared instances whose Color resolves through
    /// DynamicResource, so every control (XAML or code-built) repaints in place.
    /// </summary>
    private void ApplySystemTheme()
    {
        SwapTheme(IsSystemLightTheme());
    }

    private void SwapTheme(bool light)
    {
        var target = light ? ThemeLightSource : ThemeDarkSource;
        var dicts = Resources.MergedDictionaries;
        for (var i = 0; i < dicts.Count; i++)
        {
            var source = dicts[i].Source?.OriginalString;
            if (source is null) continue;
            var name = Path.GetFileName(source);
            if (name != "Theme.Light.xaml" && name != "Theme.Dark.xaml") continue;
            if (name == Path.GetFileName(target)) return;
            dicts[i] = new ResourceDictionary
            {
                Source = new Uri(target, UriKind.Relative)
            };
            return;
        }
        dicts.Add(new ResourceDictionary
        {
            Source = new Uri(target, UriKind.Relative)
        });
    }

    private static bool IsSystemLightTheme()
    {
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(
                @"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize");
            return key?.GetValue("AppsUseLightTheme") is int value && value == 1;
        }
        catch
        {
            return true; // registry unavailable: default to light
        }
    }

    private void OnUserPreferenceChanged(object sender, UserPreferenceChangedEventArgs e)
    {
        if (e.Category != UserPreferenceCategory.General) return;
        Dispatcher.BeginInvoke(DispatcherPriority.Background, ApplySystemTheme);
    }

    private void ShowSplash()
    {
        var splash = new Window
        {
            Width = 480,
            Height = 360,
            WindowStyle = WindowStyle.None,
            AllowsTransparency = true,
            Background = Brushes.Transparent,
            WindowStartupLocation = WindowStartupLocation.CenterScreen,
            Topmost = true,
            ShowInTaskbar = false
        };

        var grid = new Grid();
        grid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
        grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        grid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });

        var markBorder = new Border
        {
            Width = 80,
            Height = 80,
            CornerRadius = (CornerRadius)FindResource("CornerRadius20"),
            Background = (Brush)FindResource("GraphiteBrush"),
            HorizontalAlignment = HorizontalAlignment.Center,
            RenderTransformOrigin = new Point(0.5, 0.5)
        };
        var markScale = new ScaleTransform(1, 1);
        markBorder.RenderTransform = markScale;
        markBorder.Child = new TextBlock
        {
            Text = "Z",
            FontSize = 40,
            FontWeight = FontWeights.Bold,
            Foreground = (Brush)FindResource("AccentInkBrush"),
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center
        };
        Grid.SetRow(markBorder, 0);
        markBorder.VerticalAlignment = VerticalAlignment.Bottom;
        markBorder.Margin = new Thickness(0, 0, 0, 10);
        grid.Children.Add(markBorder);

        var brandStack = new StackPanel
        {
            HorizontalAlignment = HorizontalAlignment.Center,
            Margin = new Thickness(0, 20, 0, 0)
        };
        brandStack.Children.Add(new TextBlock
        {
            Text = "帧澈 ZENCHE",
            FontSize = 26,
            FontWeight = FontWeights.Bold,
            Foreground = (Brush)FindResource("InkBrush"),
            HorizontalAlignment = HorizontalAlignment.Center
        });
        brandStack.Children.Add(new TextBlock
        {
            Text = "Capture · Connect · Flow",
            FontSize = 14,
            Foreground = (Brush)FindResource("MutedBrush"),
            HorizontalAlignment = HorizontalAlignment.Center,
            Margin = new Thickness(0, 6, 0, 0)
        });
        Grid.SetRow(brandStack, 1);
        grid.Children.Add(brandStack);

        var bgBorder = new Border
        {
            Background = (Brush)FindResource("SplashPaperBrush"),
            CornerRadius = (CornerRadius)FindResource("CornerRadius16")
        };
        bgBorder.Child = grid;
        splash.Content = bgBorder;

        splash.Show();

        var animationsEnabled = SystemParameters.ClientAreaAnimation;
        if (animationsEnabled)
        {
            markScale.ScaleX = 0.72;
            markScale.ScaleY = 0.72;
            var spring = new ElasticEase
            {
                EasingMode = EasingMode.EaseOut,
                Oscillations = 1,
                Springiness = 7
            };
            var scaleAnimation = new DoubleAnimation
            {
                To = 1,
                Duration = TimeSpan.FromMilliseconds(600),
                EasingFunction = spring
            };
            markScale.BeginAnimation(ScaleTransform.ScaleXProperty, scaleAnimation);
            markScale.BeginAnimation(ScaleTransform.ScaleYProperty, scaleAnimation);

            brandStack.Opacity = 0;
            brandStack.BeginAnimation(
                UIElement.OpacityProperty,
                new DoubleAnimation
                {
                    To = 1,
                    BeginTime = TimeSpan.FromMilliseconds(500),
                    Duration = TimeSpan.FromMilliseconds(400),
                    EasingFunction = new CubicEase { EasingMode = EasingMode.EaseOut }
                });
        }

        var timer = new DispatcherTimer
        {
            Interval = TimeSpan.FromMilliseconds(animationsEnabled ? 2200 : 1200)
        };
        timer.Tick += (_, _) =>
        {
            timer.Stop();
            var fade = new DoubleAnimation
            {
                To = 0,
                Duration = TimeSpan.FromMilliseconds(animationsEnabled ? 500 : 200),
                EasingFunction = new CubicEase { EasingMode = EasingMode.EaseOut }
            };
            fade.Completed += (_, _) => splash.Close();
            splash.BeginAnimation(Window.OpacityProperty, fade);
        };
        splash.Closed += (_, _) => timer.Stop();
        timer.Start();
    }

    protected override void OnExit(ExitEventArgs e)
    {
        SystemEvents.UserPreferenceChanged -= OnUserPreferenceChanged;
        DiagnosticLogger.Shared.EndSession();
        base.OnExit(e);
    }

    private static void HandleUnhandledException(
        object sender,
        DispatcherUnhandledExceptionEventArgs e)
    {
        var exception = e.Exception;
        DiagnosticLogger.Shared.Error(
            "app",
            $"未处理异常：{exception}");
        try
        {
            ShowExceptionDetails(exception);
        }
        catch (Exception dialogError)
        {
            // 异常详情对话框自身失败时退回极简 MessageBox，
            // 不再递归进入未处理异常路径。
            MessageBox.Show(
                $"{exception}\n\n（详情对话框失败：{dialogError.Message}）",
                "帧澈 ZENCHE",
                MessageBoxButton.OK,
                MessageBoxImage.Error);
        }
        e.Handled = true;
    }

    /// <summary>
    /// 未处理异常详情对话框：异常类型 + Message + 完整 StackTrace
    /// （ToString() 全文，只读可滚动 TextBox），支持一键复制到剪贴板。
    /// 风格对齐现有深色主题（PaperBrush 底 / ErrorBrush 标题 / 日志盒样式）。
    /// </summary>
    private static void ShowExceptionDetails(Exception exception)
    {
        var details = exception.ToString();
        Window? dialog = null;
        var copyButton = new Button
        {
            Content = AppLocalization.T("复制详情"),
            Style = FindStyle("PrimaryButton"),
            MinWidth = 120,
            Height = 38,
            Padding = new Thickness(14, 0, 14, 0)
        };
        var closeButton = new Button
        {
            Content = AppLocalization.T("关闭"),
            Style = FindStyle("ButtonBase"),
            MinWidth = 110,
            Height = 38,
            Padding = new Thickness(14, 0, 14, 0)
        };
        var copyStatus = new TextBlock
        {
            FontSize = 12,
            Foreground = FindBrush("PositiveBrush"),
            VerticalAlignment = VerticalAlignment.Center,
            Margin = new Thickness(0, 0, 12, 0)
        };
        copyButton.Click += (_, _) =>
        {
            try
            {
                Clipboard.SetText(details);
                copyStatus.Text = AppLocalization.T("已复制到剪贴板");
            }
            catch (Exception clipboardError)
            {
                copyStatus.Text = clipboardError.Message;
                DiagnosticLogger.Shared.Warning(
                    "app",
                    $"复制异常详情到剪贴板失败：{clipboardError.Message}");
            }
        };
        closeButton.Click += (_, _) => dialog?.Close();

        var footer = new DockPanel { Margin = new Thickness(0, 16, 0, 0) };
        DockPanel.SetDock(copyButton, Dock.Right);
        DockPanel.SetDock(closeButton, Dock.Right);
        footer.Children.Add(copyButton);
        footer.Children.Add(closeButton);
        footer.Children.Add(copyStatus);

        var typeText = new TextBlock
        {
            Text = exception.GetType().FullName ?? exception.GetType().Name,
            FontSize = 13,
            FontWeight = FontWeights.SemiBold,
            FontFamily = new FontFamily("Consolas"),
            Foreground = FindBrush("ErrorBrush"),
            TextWrapping = TextWrapping.Wrap,
            Margin = new Thickness(0, 0, 0, 8)
        };
        var messageText = new TextBlock
        {
            Text = exception.Message,
            FontSize = 14,
            Foreground = FindBrush("InkBrush"),
            TextWrapping = TextWrapping.Wrap,
            Margin = new Thickness(0, 0, 0, 12)
        };
        var stackBox = new TextBox
        {
            Text = details,
            IsReadOnly = true,
            AcceptsReturn = true,
            TextWrapping = TextWrapping.NoWrap,
            HorizontalScrollBarVisibility = ScrollBarVisibility.Auto,
            VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
            Background = FindBrush("LogBgBrush"),
            Foreground = FindBrush("LogTextBrush"),
            BorderBrush = FindBrush("RuleBrush"),
            BorderThickness = new Thickness(1),
            Padding = new Thickness(14),
            FontFamily = new FontFamily("Consolas"),
            FontSize = 12
        };

        var header = new StackPanel { Margin = new Thickness(0, 0, 0, 14) };
        header.Children.Add(new TextBlock
        {
            Text = AppLocalization.T("未处理异常"),
            FontSize = 20,
            FontWeight = FontWeights.Bold,
            Foreground = FindBrush("InkBrush")
        });
        header.Children.Add(new TextBlock
        {
            Text = AppLocalization.T(
                "帧澈 ZENCHE 遇到一个未处理的错误。完整堆栈已写入诊断日志，可复制详情后反馈给开发者。"),
            FontSize = 12,
            Foreground = FindBrush("MutedBrush"),
            TextWrapping = TextWrapping.Wrap,
            Margin = new Thickness(0, 4, 0, 0)
        });

        var root = new DockPanel { Margin = new Thickness(24) };
        DockPanel.SetDock(header, Dock.Top);
        DockPanel.SetDock(footer, Dock.Bottom);
        root.Children.Add(header);
        root.Children.Add(footer);
        root.Children.Add(new StackPanel
        {
            Children = { typeText, messageText, stackBox }
        });

        dialog = new Window
        {
            Owner = Application.Current?.MainWindow,
            Title = $"{AppLocalization.T("未处理异常")} · 帧澈 ZENCHE",
            Width = 720,
            Height = 560,
            MinWidth = 520,
            MinHeight = 380,
            Background = FindBrush("PaperBrush"),
            WindowStartupLocation = WindowStartupLocation.CenterOwner,
            Content = root,
            ShowInTaskbar = false
        };
        dialog.ShowDialog();
    }

    /// <summary>
    /// 安全取主题画刷：资源缺失时退回系统默认，避免详情对话框自身
    /// 再触发未处理异常（递归进入同一条处理路径）。
    /// </summary>
    private static Brush FindBrush(string key)
    {
        try
        {
            return (Brush)(Application.Current?.FindResource(key)
                ?? SystemColors.WindowBrush);
        }
        catch (ResourceReferenceKeyNotFoundException)
        {
            return SystemColors.WindowBrush;
        }
    }

    /// <summary>
    /// 安全取主题控件样式：资源缺失时返回 null（Button 回落默认样式）。
    /// </summary>
    private static Style? FindStyle(string key)
    {
        try
        {
            return (Style?)Application.Current?.FindResource(key);
        }
        catch (ResourceReferenceKeyNotFoundException)
        {
            return null;
        }
    }
}
