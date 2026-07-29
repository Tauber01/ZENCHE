using System.Windows;
using System.Windows.Threading;
using NikonLink.Windows.Services;

namespace NikonLink.Windows;

public partial class App : Application
{
    protected override void OnStartup(StartupEventArgs e)
    {
        DispatcherUnhandledException += HandleUnhandledException;
        DiagnosticLogger.Shared.StartSession();
        base.OnStartup(e);
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
