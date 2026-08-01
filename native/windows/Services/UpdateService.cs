using System.IO;
using System.Net.Http;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace NikonLink.Windows.Services;

public sealed record UpdateCheckResult(
    bool IsAvailable,
    string Version,
    string DownloadUrl,
    string? Notice = null);

public sealed class UpdateService
{
    private const string DefaultMirrorChyanResourceId = "ZENCHE";
    private const string LatestReleaseApi =
        "https://api.github.com/repos/Tauber01/ZENCHE/releases/latest";
    private const string ReleasesUrl =
        "https://github.com/Tauber01/ZENCHE/releases";
    private static readonly HttpClient Client = CreateClient();
    private static readonly string CdkPath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "NikonLink",
        "mirrorchyan-cdk.dat");

    public string CurrentVersion { get; } =
        Assembly.GetEntryAssembly()?.GetName().Version?.ToString(3) ?? "1.3.0";

    public string MirrorChyanWebsiteUrl
    {
        get
        {
            var resourceId = Uri.EscapeDataString(MirrorChyanResourceId);
            return "https://mirrorchyan.com/zh/projects"
                   + $"?rid={resourceId}&source=zenche_windows_settings";
        }
    }

    public async Task<UpdateCheckResult> CheckAsync(
        CancellationToken cancellationToken = default)
    {
        try
        {
            var mirror = await CheckMirrorChyanAsync(cancellationToken);
            var version = NormalizeVersion(mirror.VersionName);
            if (!IsNewer(version, CurrentVersion))
            {
                return new UpdateCheckResult(
                    false,
                    version,
                    ReleasesUrl);
            }

            if (!string.Equals(
                    mirror.UpdateType,
                    "incremental",
                    StringComparison.OrdinalIgnoreCase) &&
                !string.IsNullOrWhiteSpace(mirror.DownloadUrl))
            {
                return new UpdateCheckResult(
                    true,
                    version,
                    mirror.DownloadUrl);
            }

            var fallback = await CheckGitHubAsync(cancellationToken);
            return fallback with
            {
                Notice = "Mirror酱未返回可直接安装的完整包，已回退 GitHub"
            };
        }
        catch (MirrorChyanException error)
        {
            var fallback = await CheckGitHubAsync(cancellationToken);
            return fallback with { Notice = error.FallbackStatus };
        }
        catch (Exception error) when (
            error is HttpRequestException or
            TaskCanceledException or
            JsonException)
        {
            var fallback = await CheckGitHubAsync(cancellationToken);
            return fallback with
            {
                Notice = "Mirror酱暂不可用，已回退 GitHub"
            };
        }
    }

    public string LoadMirrorChyanCdk()
    {
        if (!OperatingSystem.IsWindows() || !File.Exists(CdkPath))
        {
            return "";
        }

        try
        {
            var encrypted = File.ReadAllBytes(CdkPath);
            var clear = ProtectedData.Unprotect(
                encrypted,
                null,
                DataProtectionScope.CurrentUser);
            return Encoding.UTF8.GetString(clear);
        }
        catch
        {
            return "";
        }
    }

    public void SaveMirrorChyanCdk(string value)
    {
        if (!OperatingSystem.IsWindows())
        {
            return;
        }

        var cdk = value.Trim();
        if (cdk.Length == 0)
        {
            if (File.Exists(CdkPath))
            {
                File.Delete(CdkPath);
            }
            return;
        }

        Directory.CreateDirectory(Path.GetDirectoryName(CdkPath)!);
        var encrypted = ProtectedData.Protect(
            Encoding.UTF8.GetBytes(cdk),
            null,
            DataProtectionScope.CurrentUser);
        File.WriteAllBytes(CdkPath, encrypted);
    }

    private async Task<MirrorChyanVersion> CheckMirrorChyanAsync(
        CancellationToken cancellationToken)
    {
        var cdk = LoadMirrorChyanCdk();
        var parameters = new List<string>
        {
            $"current_version={Uri.EscapeDataString($"v{CurrentVersion}")}",
            "user_agent=ZENCHE_Windows",
            "os=win",
            $"arch={MirrorChyanArchitecture}",
            "channel=stable"
        };
        if (!string.IsNullOrWhiteSpace(cdk))
        {
            parameters.Add($"cdk={Uri.EscapeDataString(cdk)}");
        }

        var endpoint =
            "https://mirrorchyan.com/api/resources/"
            + $"{Uri.EscapeDataString(MirrorChyanResourceId)}/latest?"
            + string.Join("&", parameters);
        using var response = await Client.GetAsync(
            endpoint,
            cancellationToken);
        var body = await response.Content.ReadAsStringAsync(cancellationToken);
        using var document = JsonDocument.Parse(body);
        var root = document.RootElement;
        var code = root.GetProperty("code").GetInt32();
        var message = root.TryGetProperty("msg", out var msg)
            ? msg.GetString() ?? ""
            : "";
        if (code != 0 ||
            !root.TryGetProperty("data", out var data) ||
            data.ValueKind != JsonValueKind.Object)
        {
            throw new MirrorChyanException(code, message);
        }

        return new MirrorChyanVersion(
            data.GetProperty("version_name").GetString() ?? CurrentVersion,
            data.TryGetProperty("url", out var url)
                ? url.GetString() ?? ""
                : "",
            data.TryGetProperty("update_type", out var updateType)
                ? updateType.GetString()
                : null);
    }

    private async Task<UpdateCheckResult> CheckGitHubAsync(
        CancellationToken cancellationToken)
    {
        using var response = await Client.GetAsync(
            LatestReleaseApi,
            cancellationToken);
        response.EnsureSuccessStatusCode();
        await using var stream = await response.Content.ReadAsStreamAsync(
            cancellationToken);
        using var document = await JsonDocument.ParseAsync(
            stream,
            cancellationToken: cancellationToken);
        var root = document.RootElement;
        var version = NormalizeVersion(
            root.GetProperty("tag_name").GetString() ?? CurrentVersion);
        var releaseUrl =
            root.GetProperty("html_url").GetString() ?? ReleasesUrl;
        var downloadUrl = releaseUrl;
        var suffix =
            $"-Windows-{MirrorChyanArchitecture}-Setup.exe";

        if (root.TryGetProperty("assets", out var assets))
        {
            foreach (var asset in assets.EnumerateArray())
            {
                var name = asset.GetProperty("name").GetString() ?? "";
                if (!name.EndsWith(
                        suffix,
                        StringComparison.OrdinalIgnoreCase))
                {
                    continue;
                }
                downloadUrl =
                    asset.GetProperty("browser_download_url").GetString()
                    ?? releaseUrl;
                break;
            }
        }

        return new UpdateCheckResult(
            IsNewer(version, CurrentVersion),
            version,
            downloadUrl);
    }

    private static string MirrorChyanResourceId =>
        Environment.GetEnvironmentVariable(
            "ZENCHE_MIRRORCHYAN_RESOURCE_ID"
        )?.Trim() is { Length: > 0 } configured
            ? configured
            : DefaultMirrorChyanResourceId;

    private static string MirrorChyanArchitecture =>
        RuntimeInformation.ProcessArchitecture == Architecture.Arm64
            ? "arm64"
            : "x64";

    private static HttpClient CreateClient()
    {
        var client = new HttpClient
        {
            Timeout = TimeSpan.FromSeconds(20)
        };
        client.DefaultRequestHeaders.Accept.ParseAdd(
            "application/json");
        client.DefaultRequestHeaders.UserAgent.ParseAdd("ZENCHE-Windows/1.3.0");
        return client;
    }

    private static string NormalizeVersion(string value) =>
        value.TrimStart('v', 'V').Split('-', 2)[0];

    private static bool IsNewer(string candidate, string current)
    {
        return Version.TryParse(NormalizeVersion(candidate), out var left) &&
               Version.TryParse(NormalizeVersion(current), out var right) &&
               left > right;
    }

    private sealed record MirrorChyanVersion(
        string VersionName,
        string DownloadUrl,
        string? UpdateType);

    private sealed class MirrorChyanException : Exception
    {
        internal MirrorChyanException(int code, string message)
            : base($"MirrorChyan {code}: {message}")
        {
            Code = code;
        }

        private int Code { get; }

        internal string FallbackStatus => Code switch
        {
            7001 => "Mirror酱 CDK 已过期，已回退 GitHub",
            7002 => "Mirror酱 CDK 无效，已回退 GitHub",
            7003 => "Mirror酱今日下载额度已用完，已回退 GitHub",
            7004 => "Mirror酱 CDK 与资源不匹配，已回退 GitHub",
            7005 => "Mirror酱 CDK 已被停用，已回退 GitHub",
            8001 => "Mirror酱资源尚未配置，已回退 GitHub",
            _ => "Mirror酱暂不可用，已回退 GitHub"
        };
    }
}
