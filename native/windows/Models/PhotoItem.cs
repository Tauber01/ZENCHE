using System.Globalization;
using System.IO;

namespace NikonLink.Windows.Models;

public sealed record PhotoItem(string Path, bool IsLibraryItem = true)
{
    private readonly FileInfo _info = new(Path);

    public string Name => _info.Name;
    public string Source => IsLibraryItem ? "帧澈 ZENCHE 文件库" : "系统相册";
    public string SourceGroup => Source;
    public bool IsVideo =>
        new[] { ".mp4", ".mov", ".m4v", ".avi" }.Contains(
            _info.Extension,
            StringComparer.OrdinalIgnoreCase);
    public string MediaTypeGroup => IsVideo ? "视频" : "照片";
    public DateTime LastWriteTimeUtc =>
        _info.Exists ? _info.LastWriteTimeUtc : DateTime.MinValue;

    public string Detail =>
        $"{Source} · {FormatBytes(_info.Exists ? _info.Length : 0)} · " +
        $"{_info.LastWriteTime.ToString("yyyy-MM-dd HH:mm", CultureInfo.CurrentCulture)}";

    private static string FormatBytes(long size)
    {
        string[] units = ["B", "KB", "MB", "GB"];
        var value = (double)Math.Max(0, size);
        var index = 0;
        while (value >= 1024 && index < units.Length - 1)
        {
            value /= 1024;
            index++;
        }
        return $"{value:0.#} {units[index]}";
    }
}
