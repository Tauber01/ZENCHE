using System.Net.Http;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text.Json;

namespace NikonLink.Windows.Services;

public sealed record UpdateCheckResult(
    bool IsAvailable,
    string Version,
    string DownloadUrl);

public sealed class UpdateService
{
    private const string LatestReleaseApi =
        "https://api.github.com/repos/Tauber01/ZENCHE/releases/latest";
    private const string ReleasesUrl =
        "https://github.com/Tauber01/ZENCHE/releases";
    private static readonly HttpClient Client = CreateClient();

    public string CurrentVersion { get; } =
        Assembly.GetEntryAssembly()?.GetName().Version?.ToString(3) ?? "0.8.3";

    public async Task<UpdateCheckResult> CheckAsync(
        CancellationToken cancellationToken = default)
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
        var architecture =
            RuntimeInformation.ProcessArchitecture == Architecture.Arm64
                ? "arm64"
                : "x64";
        var suffix = $"-Windows-{architecture}-Setup.exe";

        if (root.TryGetProperty("assets", out var assets))
        {
            foreach (var asset in assets.EnumerateArray())
            {
                var name = asset.GetProperty("name").GetString() ?? "";
                if (!name.EndsWith(suffix, StringComparison.OrdinalIgnoreCase))
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

    private static HttpClient CreateClient()
    {
        var client = new HttpClient
        {
            Timeout = TimeSpan.FromSeconds(20)
        };
        client.DefaultRequestHeaders.Accept.ParseAdd(
            "application/vnd.github+json");
        client.DefaultRequestHeaders.UserAgent.ParseAdd("ZENCHE-Windows/0.8.3");
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
}
