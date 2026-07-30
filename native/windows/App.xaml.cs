using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Threading;
using NikonLink.Windows.Services;

namespace NikonLink.Windows;

public partial class App : Application
{
    protected override void OnStartup(StartupEventArgs e)
    {
        DispatcherUnhandledException += HandleUnhandledException;
        DiagnosticLogger.Shared.StartSession();
        ShowSplash();
        base.OnStartup(e);
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
            Background = new SolidColorBrush(
                (Color)ColorConverter.ConvertFromString("#0C0F15")),
            HorizontalAlignment = HorizontalAlignment.Center
        };
        markBorder.Child = new TextBlock
        {
            Text = "Z",
            FontSize = 40,
            FontWeight = FontWeights.Bold,
            Foreground = Brushes.White,
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
            Foreground = new SolidColorBrush(
                (Color)ColorConverter.ConvertFromString("#171C26")),
            HorizontalAlignment = HorizontalAlignment.Center
        });
        brandStack.Children.Add(new TextBlock
        {
            Text = "Capture · Connect · Flow",
            FontSize = 14,
            Foreground = new SolidColorBrush(
                (Color)ColorConverter.ConvertFromString("#525D6D")),
            HorizontalAlignment = HorizontalAlignment.Center,
            Margin = new Thickness(0, 6, 0, 0)
        });
        Grid.SetRow(brandStack, 1);
        grid.Children.Add(brandStack);

        var bgBorder = new Border
        {
            Background = new SolidColorBrush(
                (Color)ColorConverter.ConvertFromString("#F7F9FC")),
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
