using System.IO;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace NikonLink.Windows.Services;

public sealed record CaptureSessionConfiguration(
    string Name,
    string NamingTemplate,
    string Creator,
    string Rights,
    int Rating,
    bool DualBackupEnabled)
{
    public static CaptureSessionConfiguration Default { get; } = new(
        "未命名会话",
        "{session}_{date}_{counter}",
        "",
        "",
        0,
        true);
}

public sealed class CaptureWorkflow
{
    private readonly string _rootDirectory;
    private readonly string _statePath;
    private int _counter = 1;

    public CaptureWorkflow(string rootDirectory)
    {
        _rootDirectory = rootDirectory;
        _statePath = Path.Combine(rootDirectory, ".capture-session.json");
        Directory.CreateDirectory(rootDirectory);
        Load();
    }

    public CaptureSessionConfiguration Configuration { get; private set; } =
        CaptureSessionConfiguration.Default;

    public bool IsActive { get; private set; }

    public string Status { get; private set; } = "尚未开始拍摄会话";

    public string? SessionRoot => IsActive
        ? Path.Combine(
            _rootDirectory,
            "Sessions",
            Sanitize(Configuration.Name))
        : null;

    public string PrimaryDirectory => SessionRoot is null
        ? _rootDirectory
        : Path.Combine(SessionRoot, "Primary");

    public string? BackupDirectory =>
        IsActive && Configuration.DualBackupEnabled && SessionRoot is not null
            ? Path.Combine(SessionRoot, "Backup")
            : null;

    public void Begin(CaptureSessionConfiguration requested)
    {
        Configuration = Normalize(requested);
        IsActive = true;
        _counter = 1;
        EnsureDirectories();
        Persist();
        Status = $"会话进行中 · {Configuration.Name}";
    }

    public void End()
    {
        IsActive = false;
        Persist();
        Status = "拍摄会话已结束";
    }

    public string ReserveBaseName(string cameraName)
    {
        var value = Configuration.NamingTemplate
            .Replace("{session}", Configuration.Name)
            .Replace("{date}", DateTime.Now.ToString("yyyyMMdd_HHmmss"))
            .Replace("{counter}", _counter.ToString("0000"))
            .Replace("{camera}", cameraName);
        _counter++;
        Persist();
        return Sanitize(value);
    }

    public async Task<string> StoreAsync(
        byte[] bytes,
        string originalFilename,
        string cameraName,
        string? reservedBaseName = null,
        CancellationToken cancellationToken = default)
    {
        EnsureDirectories();
        var extension = Path.GetExtension(originalFilename);
        if (string.IsNullOrWhiteSpace(extension))
        {
            extension = ".jpg";
        }
        var baseName = reservedBaseName is null
            ? ReserveBaseName(cameraName)
            : Sanitize(reservedBaseName);
        var destination = UniquePath(PrimaryDirectory, baseName, extension);
        await File.WriteAllBytesAsync(destination, bytes, cancellationToken);
        await FinalizeAsync(destination, cancellationToken);
        Status = $"已写入会话 · {Path.GetFileName(destination)}";
        return destination;
    }

    public async Task<string> ImportAsync(
        string source,
        string cameraName,
        string? reservedBaseName = null,
        CancellationToken cancellationToken = default)
    {
        var bytes = await File.ReadAllBytesAsync(source, cancellationToken);
        return await StoreAsync(
            bytes,
            Path.GetFileName(source),
            cameraName,
            reservedBaseName,
            cancellationToken);
    }

    private async Task FinalizeAsync(
        string primary,
        CancellationToken cancellationToken)
    {
        if (!IsActive || SessionRoot is null)
        {
            return;
        }
        await using var stream = File.OpenRead(primary);
        var digest = Convert.ToHexString(
            await SHA256.HashDataAsync(stream, cancellationToken))
            .ToLowerInvariant();
        var sidecar = Path.ChangeExtension(primary, ".xmp");
        await File.WriteAllTextAsync(
            sidecar,
            Xmp(Path.GetFileName(primary)),
            Encoding.UTF8,
            cancellationToken);
        if (BackupDirectory is not null)
        {
            Directory.CreateDirectory(BackupDirectory);
            File.Copy(
                primary,
                Path.Combine(BackupDirectory, Path.GetFileName(primary)),
                true);
            File.Copy(
                sidecar,
                Path.Combine(BackupDirectory, Path.GetFileName(sidecar)),
                true);
        }
        var manifest = Path.Combine(SessionRoot, "checksums.sha256");
        await File.AppendAllTextAsync(
            manifest,
            $"{digest}  Primary/{Path.GetFileName(primary)}{Environment.NewLine}",
            Encoding.UTF8,
            cancellationToken);
    }

    private string Xmp(string filename) =>
        $"""
        <?xpacket begin="" id="W5M0MpCehiHzreSzNTczkc9d"?>
        <x:xmpmeta xmlns:x="adobe:ns:meta/">
          <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
            <rdf:Description rdf:about=""
              xmlns:xmp="http://ns.adobe.com/xap/1.0/"
              xmlns:dc="http://purl.org/dc/elements/1.1/"
              xmp:Rating="{Configuration.Rating}">
              <dc:title><rdf:Alt><rdf:li xml:lang="x-default">{Xml(Configuration.Name)}</rdf:li></rdf:Alt></dc:title>
              <dc:creator><rdf:Seq><rdf:li>{Xml(Configuration.Creator)}</rdf:li></rdf:Seq></dc:creator>
              <dc:rights><rdf:Alt><rdf:li xml:lang="x-default">{Xml(Configuration.Rights)}</rdf:li></rdf:Alt></dc:rights>
              <dc:description><rdf:Alt><rdf:li xml:lang="x-default">{Xml(filename)}</rdf:li></rdf:Alt></dc:description>
            </rdf:Description>
          </rdf:RDF>
        </x:xmpmeta>
        <?xpacket end="w"?>
        """;

    private void EnsureDirectories()
    {
        Directory.CreateDirectory(PrimaryDirectory);
        if (BackupDirectory is not null)
        {
            Directory.CreateDirectory(BackupDirectory);
        }
    }

    private void Load()
    {
        if (!File.Exists(_statePath))
        {
            return;
        }
        try
        {
            var state = JsonSerializer.Deserialize<PersistedState>(
                File.ReadAllText(_statePath));
            if (state is null)
            {
                return;
            }
            Configuration = Normalize(
                state.Configuration ?? CaptureSessionConfiguration.Default);
            IsActive = state.IsActive;
            _counter = Math.Max(1, state.Counter);
            if (IsActive)
            {
                EnsureDirectories();
                Status = $"会话进行中 · {Configuration.Name}";
            }
        }
        catch
        {
            IsActive = false;
        }
    }

    private void Persist()
    {
        Directory.CreateDirectory(_rootDirectory);
        File.WriteAllText(
            _statePath,
            JsonSerializer.Serialize(
                new PersistedState(Configuration, IsActive, _counter),
                new JsonSerializerOptions { WriteIndented = true }));
    }

    private static CaptureSessionConfiguration Normalize(
        CaptureSessionConfiguration value)
    {
        var name = string.IsNullOrWhiteSpace(value.Name)
            ? "未命名会话"
            : value.Name.Trim();
        var namingTemplate = string.IsNullOrWhiteSpace(value.NamingTemplate)
            ? "{session}_{date}_{counter}"
            : value.NamingTemplate.Trim();
        if (!namingTemplate.Contains("{counter}", StringComparison.Ordinal))
        {
            namingTemplate += "_{counter}";
        }
        return value with
        {
            Name = name,
            NamingTemplate = namingTemplate,
            Creator = value.Creator?.Trim() ?? "",
            Rights = value.Rights?.Trim() ?? "",
            Rating = Math.Clamp(value.Rating, 0, 5)
        };
    }

    private static string UniquePath(
        string directory,
        string baseName,
        string extension)
    {
        var result = Path.Combine(directory, baseName + extension.ToLowerInvariant());
        var suffix = 2;
        while (File.Exists(result))
        {
            result = Path.Combine(
                directory,
                $"{baseName}_{suffix}{extension.ToLowerInvariant()}");
            suffix++;
        }
        return result;
    }

    private static string Sanitize(string value)
    {
        foreach (var invalid in Path.GetInvalidFileNameChars()
                     .Concat(['/', '\\', ':', '?', '%', '*', '|', '"', '<', '>']))
        {
            value = value.Replace(invalid, '_');
        }
        value = value.Trim();
        if (string.IsNullOrWhiteSpace(value))
        {
            return "ZENCHE";
        }
        return value.Length > 120 ? value[..120] : value;
    }

    private static string Xml(string value) => value
        .Replace("&", "&amp;")
        .Replace("<", "&lt;")
        .Replace(">", "&gt;")
        .Replace("\"", "&quot;")
        .Replace("'", "&apos;");

    private sealed record PersistedState(
        CaptureSessionConfiguration? Configuration,
        bool IsActive,
        int Counter);
}
