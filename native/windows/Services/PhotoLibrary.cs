using NikonLink.Windows.Models;
using System.IO;

namespace NikonLink.Windows.Services;

public sealed class PhotoLibrary
{
    private static readonly string[] SupportedExtensions =
        [".jpg", ".jpeg", ".nef", ".nrw", ".heif", ".heic", ".tif", ".tiff"];

    public PhotoLibrary()
    {
        DirectoryPath = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.MyPictures),
            "Nikon Link");
        Directory.CreateDirectory(DirectoryPath);
    }

    public string DirectoryPath { get; }

    public IReadOnlyList<PhotoItem> List()
    {
        Directory.CreateDirectory(DirectoryPath);
        return Directory.EnumerateFiles(DirectoryPath)
            .Where(path => SupportedExtensions.Contains(
                Path.GetExtension(path),
                StringComparer.OrdinalIgnoreCase))
            .OrderByDescending(File.GetLastWriteTimeUtc)
            .Select(path => new PhotoItem(path))
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
