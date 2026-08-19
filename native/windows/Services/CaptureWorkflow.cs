using System.IO;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.VisualBasic.FileIO;

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
    private static readonly HashSet<string> LibraryMediaExtensions = new(
        [
            ".jpg", ".jpeg", ".png", ".nef", ".nrw", ".arw", ".cr2", ".cr3",
            ".heif", ".heic", ".tif", ".tiff", ".mov", ".mp4", ".m4v", ".avi"
        ],
        StringComparer.OrdinalIgnoreCase);
    private readonly string _rootDirectory;
    private readonly string _statePath;
    private readonly object _stateLock = new();
    private readonly SemaphoreSlim _finalizeGate = new(1, 1);
    private int _counter = 1;
    private bool _importOperationActive;

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
        lock (_stateLock)
        {
            ThrowIfImportOperationActive();
            Configuration = Normalize(requested);
            IsActive = true;
            _counter = 1;
            EnsureDirectories();
            Persist();
            Status = $"会话进行中 · {Configuration.Name}";
        }
    }

    public void End()
    {
        lock (_stateLock)
        {
            ThrowIfImportOperationActive();
            IsActive = false;
            Persist();
            Status = "拍摄会话已结束";
        }
    }

    public string ReserveBaseName(string cameraName)
    {
        lock (_stateLock)
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

    /// <summary>
    /// E7 焦点合成：把合成好的 JPEG 以新 base 存入会话，
    /// 复用 FinalizeAsync 全套（XMP sidecar/双备份/SHA-256 清单），
    /// XMP 写 focus-stack 合成标记 + 源帧数。
    /// TBC-awaiting-hardware。
    /// </summary>
    public async Task<string> StoreFocusStackAsync(
        string source,
        string cameraName,
        int stackSourceCount,
        CancellationToken cancellationToken = default)
    {
        EnsureDirectories();
        var destination = UniquePath(
            PrimaryDirectory,
            ReserveBaseName(cameraName),
            ".jpg");
        if (File.Exists(destination))
        {
            File.Delete(destination);
        }
        File.Move(source, destination);
        await FinalizeAsync(
            destination,
            cancellationToken,
            null,
            null,
            stackSourceCount);
        Status = $"焦点合成已写入会话 · {Path.GetFileName(destination)}";
        return destination;
    }

    public static readonly string[] SupportedImportExtensions =
    [
        ".jpg", ".jpeg", ".png", ".heic", ".heif",
        ".tif", ".tiff", ".nef", ".nrw", ".arw", ".cr2", ".cr3",
        ".mov", ".mp4", ".m4v", ".avi"
    ];

    public static bool IsSupportedImportExtension(string path)
    {
        var extension = Path.GetExtension(path);
        return !string.IsNullOrEmpty(extension) &&
            SupportedImportExtensions.Contains(
                extension,
                StringComparer.OrdinalIgnoreCase);
    }

    public async Task<string> ImportAsync(
        string source,
        string cameraName,
        string? reservedBaseName = null,
        CancellationToken cancellationToken = default)
    {
        EnterImportOperation();
        try
        {
            return await ImportCoreAsync(
                source,
                cameraName,
                reservedBaseName,
                cancellationToken).ConfigureAwait(false);
        }
        finally
        {
            ExitImportOperation();
        }
    }

    private async Task<string> ImportCoreAsync(
        string source,
        string cameraName,
        string? reservedBaseName,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(source))
        {
            throw new ArgumentException("Source path is empty.", nameof(source));
        }

        var sourceFull = Path.GetFullPath(source);
        if (!File.Exists(sourceFull))
        {
            throw new FileNotFoundException("Source file not found.", sourceFull);
        }

        if (!IsSupportedImportExtension(sourceFull))
        {
            throw new IOException("不支持的文件格式。");
        }

        var sourceContainmentPath = ResolvePathForContainment(
            new FileInfo(sourceFull));
        var rootContainmentPath = ResolvePathForContainment(
            new DirectoryInfo(_rootDirectory));
        if (sourceContainmentPath.StartsWith(
                rootContainmentPath + Path.DirectorySeparatorChar,
                StringComparison.OrdinalIgnoreCase))
        {
            throw new IOException("源文件已在文件库中。");
        }

        EnsureDirectories();
        var extension = Path.GetExtension(sourceFull).ToLowerInvariant();
        var baseName = reservedBaseName is null
            ? ReserveBaseName(cameraName)
            : Sanitize(reservedBaseName);
        var destination = UniquePath(PrimaryDirectory, baseName, extension);
        var tempPath = Path.Combine(
            PrimaryDirectory,
            $".zenche-import-{Guid.NewGuid():N}.part");

        var published = false;
        try
        {
            var sourceInfo = new FileInfo(sourceFull);
            if (sourceInfo.Length <= 0)
            {
                throw new IOException("源文件为空。");
            }

            await using var sourceStream = new FileStream(
                sourceFull,
                FileMode.Open,
                FileAccess.Read,
                FileShare.Read,
                bufferSize: 81920,
                useAsync: true);
            await using var tempStream = new FileStream(
                tempPath,
                FileMode.CreateNew,
                FileAccess.Write,
                FileShare.None,
                bufferSize: 81920,
                useAsync: true);

            await sourceStream.CopyToAsync(
                tempStream,
                81920,
                cancellationToken).ConfigureAwait(false);
            await tempStream.FlushAsync(cancellationToken).ConfigureAwait(false);
            tempStream.Flush(flushToDisk: true);

            sourceStream.Close();
            tempStream.Close();

            sourceInfo.Refresh();
            var tempInfo = new FileInfo(tempPath);
            if (!tempInfo.Exists ||
                sourceInfo.Length <= 0 ||
                tempInfo.Length != sourceInfo.Length)
            {
                throw new IOException("临时文件大小与源文件不一致。");
            }

            File.Move(tempPath, destination);
            published = true;
            await FinalizeAsync(
                destination,
                cancellationToken,
                null,
                transactionalImport: true).ConfigureAwait(false);
            Status = $"已写入会话 · {Path.GetFileName(destination)}";
            return destination;
        }
        catch (Exception failure)
        {
            var cleanupFailures = new List<Exception>();
            try
            {
                await DeleteImportArtifactAsync(tempPath, PrimaryDirectory)
                    .ConfigureAwait(false);
            }
            catch (Exception cleanupFailure)
            {
                cleanupFailures.Add(cleanupFailure);
            }
            if (published)
            {
                try
                {
                    await DeleteImportArtifactAsync(destination, PrimaryDirectory)
                        .ConfigureAwait(false);
                }
                catch (Exception cleanupFailure)
                {
                    cleanupFailures.Add(cleanupFailure);
                }
            }
            if (cleanupFailures.Count > 0)
            {
                var failures = new List<Exception> { failure };
                failures.AddRange(cleanupFailures);
                throw new IOException(
                    "导入失败且文件回滚失败。",
                    new AggregateException(failures));
            }
            throw;
        }
    }

    public sealed record BatchImportResult(
        int Imported,
        int Skipped,
        int Failed,
        int Cancelled,
        int Total,
        string? NewestPath);

    private enum ImportPairKind
    {
        Other,
        Jpeg,
        Raw
    }

    private sealed class ImportPairReservation
    {
        public required string BaseName { get; init; }
        public bool HasJpeg { get; set; }
        public bool HasRaw { get; set; }
    }

    public async Task<BatchImportResult> BatchImportAsync(
        IReadOnlyList<string> sourcePaths,
        string cameraName,
        IProgress<(int Processed, int Total)>? progress = null,
        CancellationToken cancellationToken = default)
    {
        EnterImportOperation();
        try
        {
            return await BatchImportCoreAsync(
                sourcePaths,
                cameraName,
                progress,
                cancellationToken).ConfigureAwait(false);
        }
        finally
        {
            ExitImportOperation();
        }
    }

    private async Task<BatchImportResult> BatchImportCoreAsync(
        IReadOnlyList<string> sourcePaths,
        string cameraName,
        IProgress<(int Processed, int Total)>? progress,
        CancellationToken cancellationToken)
    {
        var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        var ordered = new List<string>();
        foreach (var path in sourcePaths)
        {
            var full = Path.GetFullPath(path);
            if (seen.Add(full))
            {
                ordered.Add(full);
            }
        }

        var pairNames = new Dictionary<string, ImportPairReservation>(
            StringComparer.OrdinalIgnoreCase);
        var imported = 0;
        var skipped = 0;
        var failed = 0;
        var cancelled = 0;
        string? newestPath = null;
        var total = ordered.Count;

        for (var index = 0; index < ordered.Count; index++)
        {
            if (cancellationToken.IsCancellationRequested)
            {
                cancelled = total - index;
                break;
            }
            var source = ordered[index];

            try
            {
                if (!File.Exists(source))
                {
                    skipped++;
                    progress?.Report((index + 1, total));
                    continue;
                }

                var pairKind = ImportPairKindForPath(source);
                string reservedBase;
                if (pairKind != ImportPairKind.Other)
                {
                    var canonicalSource = ResolvePathForContainment(
                        new FileInfo(source));
                    var pairKey = Path.Combine(
                        Path.GetDirectoryName(canonicalSource) ?? "",
                        Path.GetFileNameWithoutExtension(canonicalSource));
                    if (pairNames.TryGetValue(pairKey, out var pair) &&
                        ((pairKind == ImportPairKind.Jpeg && pair.HasRaw && !pair.HasJpeg) ||
                         (pairKind == ImportPairKind.Raw && pair.HasJpeg && !pair.HasRaw)))
                    {
                        reservedBase = pair.BaseName;
                        pair.HasJpeg |= pairKind == ImportPairKind.Jpeg;
                        pair.HasRaw |= pairKind == ImportPairKind.Raw;
                    }
                    else
                    {
                        reservedBase = ReserveBaseName(cameraName);
                        if (!pairNames.ContainsKey(pairKey))
                        {
                            pairNames[pairKey] = new ImportPairReservation
                            {
                                BaseName = reservedBase,
                                HasJpeg = pairKind == ImportPairKind.Jpeg,
                                HasRaw = pairKind == ImportPairKind.Raw
                            };
                        }
                    }
                }
                else
                {
                    reservedBase = ReserveBaseName(cameraName);
                }

                var destination = await ImportCoreAsync(
                    source,
                    cameraName,
                    reservedBase,
                    cancellationToken).ConfigureAwait(false);
                imported++;
                newestPath = destination;
            }
            catch (OperationCanceledException)
            {
                cancelled = total - index;
                break;
            }
            catch
            {
                failed++;
            }

            progress?.Report((index + 1, total));
        }

        if (cancelled == 0 && cancellationToken.IsCancellationRequested)
        {
            cancelled = total - imported - skipped - failed;
        }

        return new BatchImportResult(
            imported,
            skipped,
            failed,
            cancelled,
            total,
            newestPath);
    }

    private void EnterImportOperation()
    {
        lock (_stateLock)
        {
            if (_importOperationActive)
            {
                throw new InvalidOperationException("已有导入任务正在进行。");
            }
            _importOperationActive = true;
        }
    }

    private void ExitImportOperation()
    {
        lock (_stateLock)
        {
            _importOperationActive = false;
        }
    }

    private void ThrowIfImportOperationActive()
    {
        if (_importOperationActive)
        {
            throw new InvalidOperationException("导入期间不能切换拍摄会话。");
        }
    }

    /// <summary>
    /// Sends a library file to the Windows Recycle Bin, then reconciles the
    /// exact session that owns it. A same-stem sidecar remains while another
    /// media file still references it (for example a RAW + JPEG pair).
    /// </summary>
    public async Task RecycleLibraryFileAsync(
        string primary,
        CancellationToken cancellationToken = default)
    {
        lock (_stateLock)
        {
            if (_importOperationActive)
            {
                throw new InvalidOperationException(
                    "当前有导入任务正在进行，请稍后再删除。");
            }
        }

        await _finalizeGate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            var normalizedPrimary = Path.GetFullPath(primary);
            if (!IsDescendantPath(normalizedPrimary, _rootDirectory))
            {
                throw new UnauthorizedAccessException(
                    "只能移除帧澈 ZENCHE 文件库内的文件。");
            }
            if (!File.Exists(normalizedPrimary))
            {
                throw new FileNotFoundException(
                    "文件不存在，无法移到回收站。",
                    normalizedPrimary);
            }

            var sessionRoot = SessionRootOwning(normalizedPrimary);
            var sidecar = Path.ChangeExtension(normalizedPrimary, ".xmp");
            var backup = sessionRoot is not null
                ? Path.Combine(
                    sessionRoot,
                    "Backup",
                    Path.GetFileName(normalizedPrimary))
                : null;
            var backupSidecar = backup is null
                ? null
                : Path.ChangeExtension(backup, ".xmp");
            var keepSharedSidecar = HasSameStemMediaSibling(normalizedPrimary);

            FileSystem.DeleteFile(
                normalizedPrimary,
                UIOption.OnlyErrorDialogs,
                RecycleOption.SendToRecycleBin,
                UICancelOption.ThrowException);

            var failures = new List<Exception>();

            void AttemptRecycle(string? path)
            {
                if (string.IsNullOrWhiteSpace(path) || !File.Exists(path))
                {
                    return;
                }
                try
                {
                    FileSystem.DeleteFile(
                        path,
                        UIOption.OnlyErrorDialogs,
                        RecycleOption.SendToRecycleBin,
                        UICancelOption.ThrowException);
                }
                catch (Exception failure)
                {
                    failures.Add(failure);
                }
            }

            if (sessionRoot is not null)
            {
                var manifest = Path.Combine(sessionRoot, "checksums.sha256");
                if (File.Exists(manifest))
                {
                    try
                    {
                        var relative =
                            $"Primary/{Path.GetFileName(normalizedPrimary)}";
                        var existing = await File.ReadAllTextAsync(
                            manifest,
                            cancellationToken).ConfigureAwait(false);
                        var lines = existing
                            .Split('\n')
                            .Where(line => !line.TrimEnd().EndsWith(
                                $"  {relative}",
                                StringComparison.OrdinalIgnoreCase))
                            .ToList();
                        var updated = string.Join(
                            Environment.NewLine,
                            lines.Where(line => !string.IsNullOrWhiteSpace(line)));
                        if (!string.IsNullOrEmpty(updated))
                        {
                            updated += Environment.NewLine;
                        }
                        await WriteTextAtomicallyAsync(
                            manifest,
                            updated,
                            cancellationToken).ConfigureAwait(false);
                    }
                    catch (Exception failure)
                    {
                        failures.Add(failure);
                    }
                }
            }

            AttemptRecycle(backup);
            if (!keepSharedSidecar)
            {
                AttemptRecycle(sidecar);
                AttemptRecycle(backupSidecar);
            }

            if (failures.Count > 0)
            {
                throw new IOException(
                    "移到回收站时有部分关联项未能处理。",
                    new AggregateException(failures));
            }
        }
        finally
        {
            _finalizeGate.Release();
        }
    }

    private static bool IsDescendantPath(string candidate, string root)
    {
        var normalizedRoot = Path.TrimEndingDirectorySeparator(
            Path.GetFullPath(root));
        var normalizedCandidate = Path.GetFullPath(candidate);
        return normalizedCandidate.StartsWith(
            normalizedRoot + Path.DirectorySeparatorChar,
            StringComparison.OrdinalIgnoreCase);
    }

    private string? SessionRootOwning(string primary)
    {
        var primaryDirectory = Path.GetDirectoryName(primary);
        if (primaryDirectory is null ||
            !string.Equals(
                Path.GetFileName(primaryDirectory),
                "Primary",
                StringComparison.OrdinalIgnoreCase))
        {
            return null;
        }
        var candidate = Directory.GetParent(primaryDirectory)?.FullName;
        var sessionsDirectory = candidate is null
            ? null
            : Directory.GetParent(candidate)?.FullName;
        if (candidate is null ||
            sessionsDirectory is null ||
            !string.Equals(
                Path.GetFileName(sessionsDirectory),
                "Sessions",
                StringComparison.OrdinalIgnoreCase) ||
            !IsDescendantPath(candidate, _rootDirectory))
        {
            return null;
        }
        return candidate;
    }

    private static bool HasSameStemMediaSibling(string primary)
    {
        var directory = Path.GetDirectoryName(primary);
        if (directory is null || !Directory.Exists(directory))
        {
            return false;
        }
        var stem = Path.GetFileNameWithoutExtension(primary);
        return Directory.EnumerateFiles(directory)
            .Any(candidate =>
                !string.Equals(
                    Path.GetFullPath(candidate),
                    Path.GetFullPath(primary),
                    StringComparison.OrdinalIgnoreCase) &&
                string.Equals(
                    Path.GetFileNameWithoutExtension(candidate),
                    stem,
                    StringComparison.OrdinalIgnoreCase) &&
                LibraryMediaExtensions.Contains(Path.GetExtension(candidate)));
    }

    private static ImportPairKind ImportPairKindForPath(string path)
    {
        return Path.GetExtension(path).ToLowerInvariant() switch
        {
            ".jpg" or ".jpeg" => ImportPairKind.Jpeg,
            ".nef" or ".nrw" or ".arw" or ".cr2" or ".cr3" =>
                ImportPairKind.Raw,
            _ => ImportPairKind.Other
        };
    }

    private static void TryDelete(string path)
    {
        try
        {
            if (File.Exists(path))
            {
                File.Delete(path);
            }
        }
        catch
        {
            // Best-effort cleanup; leave temp-leak handling to diagnostics.
        }
    }

    private async Task DeleteImportArtifactAsync(
        string destination,
        string expectedParent)
    {
        var destinationParent = Path.TrimEndingDirectorySeparator(
            Path.GetFullPath(Path.GetDirectoryName(destination)!));
        var allowedParent = Path.TrimEndingDirectorySeparator(
            Path.GetFullPath(expectedParent));
        if (!string.Equals(
                destinationParent,
                allowedParent,
                StringComparison.OrdinalIgnoreCase))
        {
            throw new IOException(
                $"回滚目标不属于本次导入目录，已保留：{destination}");
        }
        await DeleteRollbackFileAsync(destination).ConfigureAwait(false);
    }

    private static string ResolvePathForContainment(FileSystemInfo item)
    {
        try
        {
            item = item.ResolveLinkTarget(returnFinalTarget: true) ?? item;
        }
        catch
        {
            // Fall back to the normalized picker path when link resolution is unavailable.
        }
        return Path.TrimEndingDirectorySeparator(Path.GetFullPath(item.FullName));
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
        string? pairedWithFilename = null,
        int? stackSourceCount = null,
        bool transactionalImport = false)
    {
        await _finalizeGate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            if (!IsActive && location is null && pairedWithFilename is null && stackSourceCount is null)
            {
                return;
            }
            var sidecar = Path.ChangeExtension(primary, ".xmp");
            var snapshot = transactionalImport
                ? await CaptureImportMetadataSnapshotAsync(
                    primary,
                    sidecar,
                    cancellationToken).ConfigureAwait(false)
                : null;
            try
            {
                await WriteTextAtomicallyAsync(
                    sidecar,
                    Xmp(Path.GetFileName(primary), location, pairedWithFilename, stackSourceCount),
                    cancellationToken).ConfigureAwait(false);
                if (!IsActive || SessionRoot is null)
                {
                    return;
                }
                await using var stream = File.OpenRead(primary);
                var digest = Convert.ToHexString(
                    await SHA256.HashDataAsync(stream, cancellationToken)
                        .ConfigureAwait(false))
                    .ToLowerInvariant();
                stream.Close();
                if (BackupDirectory is not null)
                {
                    Directory.CreateDirectory(BackupDirectory);
                    await CopyFileAtomicallyAsync(
                        primary,
                        Path.Combine(BackupDirectory, Path.GetFileName(primary)),
                        cancellationToken).ConfigureAwait(false);
                    await CopyFileAtomicallyAsync(
                        sidecar,
                        Path.Combine(BackupDirectory, Path.GetFileName(sidecar)),
                        cancellationToken).ConfigureAwait(false);
                }
                var manifest = Path.Combine(SessionRoot, "checksums.sha256");
                var existingManifest = File.Exists(manifest)
                    ? await File.ReadAllTextAsync(manifest, cancellationToken)
                        .ConfigureAwait(false)
                    : "";
                await WriteTextAtomicallyAsync(
                    manifest,
                    existingManifest +
                        $"{digest}  Primary/{Path.GetFileName(primary)}{Environment.NewLine}",
                    cancellationToken).ConfigureAwait(false);
            }
            catch (Exception failure) when (snapshot is not null)
            {
                try
                {
                    await RestoreImportMetadataAsync(snapshot)
                        .ConfigureAwait(false);
                }
                catch (Exception rollbackFailure)
                {
                    throw new IOException(
                        "导入失败且元数据回滚失败。",
                        new AggregateException(failure, rollbackFailure));
                }
                throw;
            }
        }
        finally
        {
            _finalizeGate.Release();
        }
    }

    private sealed record ImportMetadataSnapshot(
        string Sidecar,
        byte[]? SidecarData,
        string? Backup,
        string? BackupSidecar,
        byte[]? BackupSidecarData);

    private async Task<ImportMetadataSnapshot> CaptureImportMetadataSnapshotAsync(
        string primary,
        string sidecar,
        CancellationToken cancellationToken)
    {
        var sidecarData = File.Exists(sidecar)
            ? await File.ReadAllBytesAsync(sidecar, cancellationToken)
                .ConfigureAwait(false)
            : null;
        var backup = IsActive && BackupDirectory is not null
            ? Path.Combine(BackupDirectory, Path.GetFileName(primary))
            : null;
        if (backup is not null &&
            (File.Exists(backup) || Directory.Exists(backup)))
        {
            throw new IOException("备份目录已存在同名文件，未覆盖既有数据。");
        }
        var backupSidecar = backup is null
            ? null
            : Path.ChangeExtension(backup, ".xmp");
        var backupSidecarData =
            backupSidecar is not null && File.Exists(backupSidecar)
                ? await File.ReadAllBytesAsync(
                    backupSidecar,
                    cancellationToken).ConfigureAwait(false)
                : null;
        return new ImportMetadataSnapshot(
            sidecar,
            sidecarData,
            backup,
            backupSidecar,
            backupSidecarData);
    }

    private static async Task RestoreImportMetadataAsync(
        ImportMetadataSnapshot snapshot)
    {
        var failures = new List<Exception>();

        async Task AttemptAsync(Func<Task> operation)
        {
            try
            {
                await operation().ConfigureAwait(false);
            }
            catch (Exception failure)
            {
                failures.Add(failure);
            }
        }

        await AttemptAsync(
            () => DeleteRollbackFileAsync(snapshot.Backup))
            .ConfigureAwait(false);
        await AttemptAsync(
            () => RestoreFileAsync(
                snapshot.BackupSidecar,
                snapshot.BackupSidecarData)).ConfigureAwait(false);
        await AttemptAsync(
            () => RestoreFileAsync(snapshot.Sidecar, snapshot.SidecarData))
            .ConfigureAwait(false);

        if (failures.Count > 0)
        {
            throw new AggregateException(
                "元数据回滚有一个或多个步骤失败。",
                failures);
        }
    }

    private static async Task RestoreFileAsync(
        string? destination,
        byte[]? data)
    {
        if (destination is null)
        {
            return;
        }
        if (data is null)
        {
            await DeleteRollbackFileAsync(destination).ConfigureAwait(false);
            return;
        }
        await WriteBytesAtomicallyAsync(
            destination,
            data,
            CancellationToken.None).ConfigureAwait(false);
    }

    private static Task DeleteRollbackFileAsync(string? destination)
    {
        if (destination is null)
        {
            return Task.CompletedTask;
        }
        if (Directory.Exists(destination))
        {
            throw new IOException(
                $"回滚目标不是文件，已保留：{destination}");
        }
        if (File.Exists(destination))
        {
            File.Delete(destination);
        }
        if (File.Exists(destination) || Directory.Exists(destination))
        {
            throw new IOException($"回滚后目标仍然存在：{destination}");
        }
        return Task.CompletedTask;
    }

    private static async Task CopyFileAtomicallyAsync(
        string source,
        string destination,
        CancellationToken cancellationToken)
    {
        var temporary = Path.Combine(
            Path.GetDirectoryName(destination)!,
            $".zenche-copy-{Guid.NewGuid():N}.part");
        try
        {
            var sourceInfo = new FileInfo(source);
            await using var sourceStream = new FileStream(
                source,
                FileMode.Open,
                FileAccess.Read,
                FileShare.Read,
                81920,
                useAsync: true);
            await using var temporaryStream = new FileStream(
                temporary,
                FileMode.CreateNew,
                FileAccess.Write,
                FileShare.None,
                81920,
                useAsync: true);
            await sourceStream.CopyToAsync(
                temporaryStream,
                81920,
                cancellationToken).ConfigureAwait(false);
            await temporaryStream.FlushAsync(cancellationToken)
                .ConfigureAwait(false);
            temporaryStream.Flush(flushToDisk: true);
            sourceStream.Close();
            temporaryStream.Close();
            sourceInfo.Refresh();
            var temporaryInfo = new FileInfo(temporary);
            if (!temporaryInfo.Exists ||
                sourceInfo.Length <= 0 ||
                temporaryInfo.Length != sourceInfo.Length)
            {
                throw new IOException("备份文件大小与源文件不一致。");
            }
            File.Move(temporary, destination, overwrite: true);
        }
        finally
        {
            TryDelete(temporary);
        }
    }

    private static async Task WriteTextAtomicallyAsync(
        string destination,
        string content,
        CancellationToken cancellationToken)
    {
        await WriteBytesAtomicallyAsync(
            destination,
            Encoding.UTF8.GetBytes(content),
            cancellationToken).ConfigureAwait(false);
    }

    private static async Task WriteBytesAtomicallyAsync(
        string destination,
        byte[] bytes,
        CancellationToken cancellationToken)
    {
        var temporary = Path.Combine(
            Path.GetDirectoryName(destination)!,
            $".zenche-metadata-{Guid.NewGuid():N}.tmp");
        try
        {
            await using var stream = new FileStream(
                temporary,
                FileMode.CreateNew,
                FileAccess.Write,
                FileShare.None,
                4096,
                useAsync: true);
            await stream.WriteAsync(bytes, cancellationToken).ConfigureAwait(false);
            await stream.FlushAsync(cancellationToken).ConfigureAwait(false);
            stream.Flush(flushToDisk: true);
            stream.Close();
            File.Move(temporary, destination, overwrite: true);
        }
        finally
        {
            TryDelete(temporary);
        }
    }

    private string Xmp(
        string filename,
        CaptureLocation? location,
        string? pairedWithFilename = null,
        int? stackSourceCount = null)
    {
        var gps = location is null ? "" : GpsAttributes(location);
        var pairing = pairedWithFilename is null
            ? ""
            : $"\n              xmp:Label=\"live-photo\"\n              dc:relation=\"{Xml(pairedWithFilename)}\"";
        var stack = stackSourceCount is null
            ? ""
            : $"\n              xmp:Label=\"focus-stack\"\n              xmp:FocusStackSources=\"{stackSourceCount}\"";
        return $"""
        <?xpacket begin="" id="W5M0MpCehiHzreSzNTczkc9d"?>
        <x:xmpmeta xmlns:x="adobe:ns:meta/">
          <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
            <rdf:Description rdf:about=""
              xmlns:xmp="http://ns.adobe.com/xap/1.0/"
              xmlns:dc="http://purl.org/dc/elements/1.1/"
              xmlns:exif="http://ns.adobe.com/exif/1.0/"
              xmp:Rating="{Configuration.Rating}"{gps}{pairing}{stack}>
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
