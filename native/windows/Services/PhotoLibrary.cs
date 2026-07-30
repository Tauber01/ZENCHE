using NikonLink.Windows.Models;
using System.IO;

namespace NikonLink.Windows.Services;

public sealed class PhotoLibrary
{
    private static readonly string[] SupportedExtensions =
        [
            ".jpg", ".jpeg", ".png", ".nef", ".nrw", ".heif", ".heic",
            ".tif", ".tiff", ".mp4", ".mov", ".m4v"
        ];

    public PhotoLibrary(string? directoryPath = null)
    {
        var pictures = Environment.GetFolderPath(
            Environment.SpecialFolder.MyPictures);
        var preferredDirectory = Path.Combine(pictures, "ZENCHE");
        var legacyDirectory = Path.Combine(pictures, "Nikon" + " Link");
        if (directoryPath is null &&
            !Directory.Exists(preferredDirectory) &&
            Directory.Exists(legacyDirectory))
        {
            try
            {
                Directory.Move(legacyDirectory, preferredDirectory);
            }
            catch (IOException)
            {
                // Keep startup resilient if another process still holds a file.
            }
        }
        DirectoryPath = directoryPath ?? preferredDirectory;
        Directory.CreateDirectory(DirectoryPath);
    }

    public string DirectoryPath { get; }

    public IReadOnlyList<PhotoItem> List()
    {
        Directory.CreateDirectory(DirectoryPath);
        return Directory.EnumerateFiles(
                DirectoryPath,
                "*",
                SearchOption.AllDirectories)
            .Where(path =>
                !path.Split(Path.DirectorySeparatorChar)
                    .Contains("Backup", StringComparer.OrdinalIgnoreCase))
            .Where(path => SupportedExtensions.Contains(
                Path.GetExtension(path),
                StringComparer.OrdinalIgnoreCase))
            .OrderByDescending(File.GetLastWriteTimeUtc)
            .Select(path => new PhotoItem(path))
            .ToList();
    }

    public IReadOnlyList<PhotoItem> ListSystemAlbum(int limit = 80)
    {
        var pictures = Environment.GetFolderPath(
            Environment.SpecialFolder.MyPictures);
        if (string.IsNullOrWhiteSpace(pictures) ||
            !Directory.Exists(pictures))
        {
            return [];
        }
        var libraryRoot = Path.GetFullPath(DirectoryPath)
            .TrimEnd(Path.DirectorySeparatorChar)
            + Path.DirectorySeparatorChar;
        var options = new EnumerationOptions
        {
            RecurseSubdirectories = true,
            IgnoreInaccessible = true,
            ReturnSpecialDirectories = false
        };
        return Directory.EnumerateFiles(pictures, "*", options)
            .Where(path =>
                SupportedExtensions.Contains(
                    Path.GetExtension(path),
                    StringComparer.OrdinalIgnoreCase) &&
                !Path.GetFullPath(path).StartsWith(
                    libraryRoot,
                    StringComparison.OrdinalIgnoreCase))
            .OrderByDescending(File.GetLastWriteTimeUtc)
            .Take(Math.Max(1, limit))
            .Select(path => new PhotoItem(path, IsLibraryItem: false))
            .ToList();
    }

    public async Task<string> SaveCaptureAsync(
        byte[] jpeg,
        CancellationToken cancellationToken = default)
    {
        var filename = $"NIKON_{DateTime.Now:yyyyMMdd_HHmmss_fff}.JPG";
        var destination = UniqueDestination(filename);
        await File.WriteAllBytesAsync(destination, jpeg, cancellationToken);
        return destination;
    }

    public IReadOnlyList<string> ImportFiles(IEnumerable<string> sourcePaths)
    {
        Directory.CreateDirectory(DirectoryPath);
        var imported = new List<string>();
        foreach (var sourcePath in sourcePaths)
        {
            if (!File.Exists(sourcePath) ||
                !SupportedExtensions.Contains(
                    Path.GetExtension(sourcePath),
                    StringComparer.OrdinalIgnoreCase))
            {
                continue;
            }
            var destination = UniqueDestination(Path.GetFileName(sourcePath));
            File.Copy(sourcePath, destination);
            imported.Add(destination);
        }
        return imported;
    }

    public string UniqueDestination(string remoteName)
    {
        var safeName = SafeFilename(remoteName);
        var initial = Path.Combine(DirectoryPath, safeName);
        if (!File.Exists(initial))
        {
            return initial;
        }
        var stem = Path.GetFileNameWithoutExtension(safeName);
        var extension = Path.GetExtension(safeName);
        return Path.Combine(
            DirectoryPath,
            $"{stem}_{DateTime.Now:yyyyMMdd_HHmmss_fff}{extension}");
    }

    public static string SafeFilename(string remoteName)
    {
        var name = Path.GetFileName(
            remoteName.Replace('\0', '_').Replace('/', Path.DirectorySeparatorChar));
        foreach (var invalid in Path.GetInvalidFileNameChars())
        {
            name = name.Replace(invalid, '_');
        }
        return string.IsNullOrWhiteSpace(name) || name is "." or ".."
            ? $"NIKON_{DateTime.Now:yyyyMMdd_HHmmss}.JPG"
            : name.Trim();
    }
}
