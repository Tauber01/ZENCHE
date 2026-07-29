using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.RegularExpressions;

namespace NikonLink.Windows.Services;

public sealed class DiagnosticLogger
{
    private const long MaxFileBytes = 5L * 1024L * 1024L;
    private static readonly TimeSpan Retention = TimeSpan.FromDays(14);
    private static readonly Uri IssueBase =
        new("https://github.com/Tauber01/ZENCHE/issues/new");
    private readonly object _gate = new();
    private readonly string _sessionId = Guid.NewGuid().ToString("N")[..8];

    private DiagnosticLogger()
    {
        DirectoryPath = Path.Combine(
            Environment.GetFolderPath(
                Environment.SpecialFolder.LocalApplicationData),
            "帧澈 ZENCHE",
            "Logs");
        try
        {
            Directory.CreateDirectory(DirectoryPath);
            RemoveExpiredLogs();
        }
        catch (Exception error)
        {
            Debug.WriteLine(
                $"ZENCHE diagnostics setup failed: {error.Message}");
        }
    }

    public static DiagnosticLogger Shared { get; } = new();

    public string DirectoryPath { get; }

    public void StartSession()
    {
        Info(
            "app",
            $"会话启动；版本={AppVersion()}" +
            $"；系统={RuntimeInformation.OSDescription}" +
            $"；架构={RuntimeInformation.ProcessArchitecture}");
    }

    public void EndSession()
    {
        Info("app", "会话结束");
    }

    public void Info(string category, string message) =>
        Write("INFO", category, message);

    public void Warning(string category, string message) =>
        Write("WARN", category, message);

    public void Error(string category, string message) =>
        Write("ERROR", category, message);

    public void OpenDirectory()
    {
        Directory.CreateDirectory(DirectoryPath);
        Process.Start(new ProcessStartInfo
        {
            FileName = DirectoryPath,
            UseShellExecute = true
        });
    }

    public void OpenGitHubIssue()
    {
        Info("diagnostics", "用户打开 GitHub Issue 提交页");
        var body =
            "## 问题描述\n\n请描述发生了什么，以及如何复现。\n\n" +
            "## 环境\n\n" +
            $"- 平台：{RuntimeInformation.OSDescription}\n" +
            $"- 架构：{RuntimeInformation.ProcessArchitecture}\n" +
            $"- 帧澈 ZENCHE：{AppVersion()}\n" +
            $"- 会话：{_sessionId}\n\n" +
            "## 最近诊断日志（已脱敏）\n\n```text\n" +
            RecentText(2_500) +
            "\n```\n\n" +
            "> 提交前请检查以上内容；不要填写密码、令牌或相机序列号。";
        var url =
            $"{IssueBase}?title={Uri.EscapeDataString("[Windows] ")}" +
            $"&body={Uri.EscapeDataString(body)}";
        Process.Start(new ProcessStartInfo
        {
            FileName = url,
            UseShellExecute = true
        });
    }

    public string RecentText(int maxCharacters)
    {
        lock (_gate)
        {
            try
            {
                var files = Directory.EnumerateFiles(DirectoryPath, "*.log")
                    .OrderByDescending(File.GetLastWriteTimeUtc);
                var result = "";
                foreach (var file in files)
                {
                    if (result.Length >= maxCharacters)
                    {
                        break;
                    }
                    var remaining = maxCharacters - result.Length;
                    var text = ReadTail(file, remaining);
                    if (text.Length > 0)
                    {
                        result = text +
                            (result.Length == 0 ? "" : "\n" + result);
                    }
                }
                return result.Length == 0 ? "暂无日志。" : Redact(result);
            }
            catch (Exception error)
            {
                Debug.WriteLine(
                    $"ZENCHE diagnostics read failed: {error.Message}");
                return "日志暂不可用。";
            }
        }
    }

    private void Write(string level, string category, string message)
    {
        lock (_gate)
        {
            try
            {
                Directory.CreateDirectory(DirectoryPath);
                var target = CurrentLogPath();
                if (File.Exists(target) &&
                    new FileInfo(target).Length >= MaxFileBytes)
                {
                    var rotated = Path.Combine(
                        DirectoryPath,
                        $"ZENCHE-{DateTime.Now:yyyy-MM-dd-HHmmss}" +
                        $"-{_sessionId}.log");
                    File.Move(target, rotated);
                }
                var cleanCategory = Regex.Replace(
                    Redact(category),
                    @"\s+",
                    " ");
                var cleanMessage = Redact(message ?? "未知错误");
                if (cleanMessage.Length > 32_768)
                {
                    cleanMessage = cleanMessage[..32_768];
                }
                cleanMessage = cleanMessage.Replace("\n", "\n    ");
                var entry =
                    $"{DateTimeOffset.Now:O} [{level}] [{_sessionId}] " +
                    $"[{cleanCategory}] {cleanMessage}{Environment.NewLine}";
                File.AppendAllText(target, entry, Encoding.UTF8);
            }
            catch (Exception error)
            {
                Debug.WriteLine(
                    $"ZENCHE diagnostics write failed: {error.Message}");
            }
        }
    }

    private string CurrentLogPath() =>
        Path.Combine(DirectoryPath, $"ZENCHE-{DateTime.Now:yyyy-MM-dd}.log");

    private static string ReadTail(string path, int maxCharacters)
    {
        var byteLimit = Math.Min(maxCharacters * 4, 32_000);
        using var stream = new FileStream(
            path,
            FileMode.Open,
            FileAccess.Read,
            FileShare.ReadWrite);
        var start = Math.Max(0, stream.Length - byteLimit);
        stream.Seek(start, SeekOrigin.Begin);
        var bytes = new byte[checked((int)(stream.Length - start))];
        _ = stream.Read(bytes, 0, bytes.Length);
        var text = Encoding.UTF8.GetString(bytes);
        if (start > 0)
        {
            var newline = text.IndexOf('\n');
            if (newline >= 0 && newline + 1 < text.Length)
            {
                text = text[(newline + 1)..];
            }
        }
        return text.Length > maxCharacters
            ? text[^maxCharacters..]
            : text;
    }

    private void RemoveExpiredLogs()
    {
        var cutoff = DateTime.UtcNow - Retention;
        foreach (var file in Directory.EnumerateFiles(DirectoryPath, "*.log"))
        {
            if (File.GetLastWriteTimeUtc(file) < cutoff)
            {
                try
                {
                    File.Delete(file);
                }
                catch
                {
                }
            }
        }
    }

    private static string Redact(string value)
    {
        var result = value.Replace(
            Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
            "<HOME>",
            StringComparison.OrdinalIgnoreCase);
        return Regex.Replace(
            result,
            @"(?i)((?:token|key|password|secret|serial(?: number)?|" +
            @"serialnumber|username)\s*[:=]\s*)\S+",
            "$1<REDACTED>");
    }

    private static string AppVersion()
    {
        var version = Assembly.GetExecutingAssembly()
            .GetCustomAttribute<AssemblyInformationalVersionAttribute>()?
            .InformationalVersion;
        return string.IsNullOrWhiteSpace(version) ? "unknown" : version;
    }
}
