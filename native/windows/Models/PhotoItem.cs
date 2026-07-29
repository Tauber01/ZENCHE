using System.Globalization;
using System.IO;

namespace NikonLink.Windows.Models;

public sealed record PhotoItem(string Path)
{
    private readonly FileInfo _info = new(Path);

    public string Name => _info.Name;

    public string Detail =>
        $"{FormatBytes(_info.Exists ? _info.Length : 0)} · " +
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
