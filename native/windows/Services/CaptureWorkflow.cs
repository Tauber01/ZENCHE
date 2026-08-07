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
        CancellationToken cancellationToken = default,
        CaptureLocation? location = null,
        string? pairedWithFilename = null)
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
        await FinalizeAsync(
            destination,
            cancellationToken,
            location,
            pairedWithFilename);
        Status = $"已写入会话 · {Path.GetFileName(destination)}";
        return destination;
    }

    /// <summary>E5 live 图：把快门切片 AVI 以照片同 base 存入会话，
    /// XMP sidecar 写配对标记（指向配对照片），双备份/SHA-256 全复用。
    /// TBC-awaiting-hardware。</summary>
    public async Task<string> StoreLivePhotoClipAsync(
        string source,
        string baseName,
        string pairedPhotoFilename,
        string cameraName,
        CancellationToken cancellationToken = default)
    {
        EnsureDirectories();
        var destination = UniquePath(
            PrimaryDirectory,
            $"{Sanitize(baseName)}_live",
            ".avi");
        if (File.Exists(destination))
        {
            File.Delete(destination);
        }
        File.Move(source, destination);
        await FinalizeAsync(
            destination,
            cancellationToken,
            null,
            pairedPhotoFilename);
        Status = $"live 图视频已写入会话 · {Path.GetFileName(destination)}";
        return destination;
    }

    /// <summary>E6 延时合成：把渲染好的 MP4 以新 base 存入会话，
    /// 复用 finalize 全套（XMP sidecar/双备份/SHA-256 清单）。
    /// TBC-awaiting-hardware。</summary>
    public async Task<string> StoreTimelapseVideoAsync(
        string source,
        string cameraName,
        CancellationToken cancellationToken = default)
    {
        EnsureDirectories();
        var destination = UniquePath(
            PrimaryDirectory,
            ReserveBaseName(cameraName),
            ".mp4");
        if (File.Exists(destination))
        {
            File.Delete(destination);
        }
        File.Move(source, destination);
        await FinalizeAsync(
            destination,
            cancellationToken,
            null,
            null);
        Status = $"延时视频已写入会话 · {Path.GetFileName(destination)}";
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

    public string ReserveExternalRecording(
        string cameraName,
        string extension = ".avi")
    {
        EnsureDirectories();
        var normalized = extension.Equals(
            ".avi",
            StringComparison.OrdinalIgnoreCase) ? ".avi" : ".avi";
        return UniquePath(
            PrimaryDirectory,
            ReserveBaseName(cameraName),
            normalized);
    }

    public async Task CompleteExternalRecordingAsync(
        string recording,
        CancellationToken cancellationToken = default)
    {
        if (!File.Exists(recording) || new FileInfo(recording).Length == 0)
        {
            throw new IOException("外录文件为空。");
        }
        await FinalizeAsync(recording, cancellationToken, null);
        Status = $"外录已写入会话 · {Path.GetFileName(recording)}";
    }

    private async Task FinalizeAsync(
        string primary,
        CancellationToken cancellationToken,
        CaptureLocation? location,
        string? pairedWithFilename = null)
    {
        if (!IsActive && location is null && pairedWithFilename is null)
        {
            return;
        }
        var sidecar = Path.ChangeExtension(primary, ".xmp");
        await File.WriteAllTextAsync(
            sidecar,
            Xmp(Path.GetFileName(primary), location, pairedWithFilename),
            Encoding.UTF8,
            cancellationToken);
        if (!IsActive || SessionRoot is null)
        {
            return;
        }
        await using var stream = File.OpenRead(primary);
        var digest = Convert.ToHexString(
            await SHA256.HashDataAsync(stream, cancellationToken))
            .ToLowerInvariant();
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

    private string Xmp(
        string filename,
        CaptureLocation? location,
        string? pairedWithFilename = null)
    {
        var gps = location is null ? "" : GpsAttributes(location);
        var pairing = pairedWithFilename is null
            ? ""
            : $"\n              xmp:Label=\"live-photo\"\n              dc:relation=\"{Xml(pairedWithFilename)}\"";
        return $"""
        <?xpacket begin="" id="W5M0MpCehiHzreSzNTczkc9d"?>
        <x:xmpmeta xmlns:x="adobe:ns:meta/">
          <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
            <rdf:Description rdf:about=""
              xmlns:xmp="http://ns.adobe.com/xap/1.0/"
              xmlns:dc="http://purl.org/dc/elements/1.1/"
              xmlns:exif="http://ns.adobe.com/exif/1.0/"
              xmp:Rating="{Configuration.Rating}"{gps}{pairing}>
              <dc:title><rdf:Alt><rdf:li xml:lang="x-default">{Xml(Configuration.Name)}</rdf:li></rdf:Alt></dc:title>
              <dc:creator><rdf:Seq><rdf:li>{Xml(Configuration.Creator)}</rdf:li></rdf:Seq></dc:creator>
              <dc:rights><rdf:Alt><rdf:li xml:lang="x-default">{Xml(Configuration.Rights)}</rdf:li></rdf:Alt></dc:rights>
              <dc:description><rdf:Alt><rdf:li xml:lang="x-default">{Xml(filename)}</rdf:li></rdf:Alt></dc:description>
            </rdf:Description>
          </rdf:RDF>
        </x:xmpmeta>
        <?xpacket end="w"?>
        """;
    }

    private static string GpsAttributes(CaptureLocation location)
    {
        var altitudeReference = location.Altitude < 0 ? 1 : 0;
        return $"""

              exif:GPSLatitude="{GpsCoordinate(location.Latitude, "N", "S")}"
              exif:GPSLongitude="{GpsCoordinate(location.Longitude, "E", "W")}"
              exif:GPSAltitude="{Math.Abs(location.Altitude):0.00}"
              exif:GPSAltitudeRef="{altitudeReference}"
              exif:GPSHPositioningError="{Math.Max(0, location.HorizontalAccuracy):0.00}"
              exif:GPSDateStamp="{location.CapturedAt.UtcDateTime:yyyy:MM:dd}"
        """;
    }

    private static string GpsCoordinate(
        double value,
        string positive,
        string negative)
    {
        var direction = value >= 0 ? positive : negative;
        var absolute = Math.Abs(value);
        var degrees = (int)absolute;
        var minutes = (absolute - degrees) * 60;
        return FormattableString.Invariant($"{degrees},{minutes:0.000000}{direction}");
    }

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
