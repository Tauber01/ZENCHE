using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
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
            CornerRadius = new CornerRadius(20),
            Background = (Brush)FindResource("LogBgBrush"),
            HorizontalAlignment = HorizontalAlignment.Center
        };
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
            Background = (Brush)FindResource("SurfaceBrush"),
            CornerRadius = new CornerRadius(16)
        };
        bgBorder.Child = grid;
        splash.Content = bgBorder;

        splash.Show();

        var timer = new DispatcherTimer
        {
            Interval = TimeSpan.FromMilliseconds(2500)
        };
        timer.Tick += (_, _) =>
        {
            timer.Stop();
            splash.Close();
        };
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
        DiagnosticLogger.Shared.Error(
            "app",
            $"未处理异常：{e.Exception}");
        MessageBox.Show(
            e.Exception.Message,
            "帧澈 ZENCHE",
            MessageBoxButton.OK,
            MessageBoxImage.Error);
        e.Handled = true;
    }
}
