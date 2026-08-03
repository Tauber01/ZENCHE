using System.Buffers.Binary;
using System.IO;
using System.Text;

namespace NikonLink.Windows.Models;

public sealed record CameraStorageVolume(
    uint Id,
    string Name,
    long CapacityBytes,
    long FreeBytes,
    uint FreeImages,
    bool IsReadOnly);

public sealed record CameraStorageItem(
    uint Handle,
    uint StorageId,
    ushort Format,
    string Filename,
    long SizeBytes,
    int Width,
    int Height,
    string CapturedAt,
    bool IsProtected)
{
    public bool IsVideo
    {
        get
        {
            var extension = Path.GetExtension(Filename);
            return extension.Equals(".mov", StringComparison.OrdinalIgnoreCase) ||
                   extension.Equals(".mp4", StringComparison.OrdinalIgnoreCase) ||
                   extension.Equals(".avi", StringComparison.OrdinalIgnoreCase) ||
                   extension.Equals(".m4v", StringComparison.OrdinalIgnoreCase) ||
                   extension.Equals(".mts", StringComparison.OrdinalIgnoreCase) ||
                   extension.Equals(".m2ts", StringComparison.OrdinalIgnoreCase);
        }
    }
}

public sealed class CameraStorageSnapshot
{
    public CameraStorageSnapshot(
        IReadOnlyList<CameraStorageVolume> volumes,
        IReadOnlyList<CameraStorageItem> items)
    {
        Volumes = volumes;
        Items = items;
    }

    public IReadOnlyList<CameraStorageVolume> Volumes { get; }
    public IReadOnlyList<CameraStorageItem> Items { get; }
    public long CapacityBytes => SaturatingSum(Volumes.Select(volume => volume.CapacityBytes));
    public long FreeBytes => SaturatingSum(Volumes.Select(volume => volume.FreeBytes));

    public static CameraStorageSnapshot Empty { get; } = new([], []);

    private static long SaturatingSum(IEnumerable<long> values)
    {
        long total = 0;
        foreach (var value in values)
        {
            if (value > 0 && total > long.MaxValue - value) return long.MaxValue;
            total += value;
        }
        return total;
    }
}

internal static class CameraStorageParser
{
    public static IReadOnlyList<uint> StorageIds(byte[] data)
    {
        if (data.Length < 4) return [];
        var requested = ReadUInt32(data, 0);
        var count = (int)Math.Min(requested, (uint)((data.Length - 4) / 4));
        var result = new List<uint>(count);
        for (var index = 0; index < count; index++)
        {
            result.Add(ReadUInt32(data, 4 + index * 4));
        }
        return result;
    }

    public static CameraStorageVolume StorageInfo(uint storageId, byte[] data)
    {
        if (data.Length < 26)
        {
            return new(storageId, StorageLabel(storageId), 0, 0, 0, false);
        }
        var description = ReadPtpString(data, 26);
        var label = ReadPtpString(data, description.NextOffset);
        var name = !string.IsNullOrWhiteSpace(label.Value)
            ? label.Value
            : !string.IsNullOrWhiteSpace(description.Value)
                ? description.Value
                : StorageLabel(storageId);
        return new(
            storageId,
            name,
            ReadUInt64Saturated(data, 6),
            ReadUInt64Saturated(data, 14),
            ReadUInt32(data, 22),
            ReadUInt16(data, 4) != 0);
    }

    public static CameraStorageItem? ObjectInfo(uint handle, byte[] data)
    {
        if (data.Length < 52 || ReadUInt16(data, 42) != 0) return null;
        var filename = ReadPtpString(data, 52);
        if (string.IsNullOrWhiteSpace(filename.Value)) return null;
        var capturedAt = ReadPtpString(data, filename.NextOffset);
        return new(
            handle,
            ReadUInt32(data, 0),
            ReadUInt16(data, 4),
            filename.Value,
            ReadUInt32(data, 8),
            SaturatedInt(ReadUInt32(data, 26)),
            SaturatedInt(ReadUInt32(data, 30)),
            DisplayDate(capturedAt.Value),
            ReadUInt16(data, 6) != 0);
    }

    public static bool IsAssociation(byte[] data) =>
        data.Length >= 52 && ReadUInt16(data, 42) != 0;

    private static (string Value, int NextOffset) ReadPtpString(byte[] data, int offset)
    {
        if (offset < 0 || offset >= data.Length) return (string.Empty, data.Length);
        var charactersIncludingNull = data[offset];
        if (charactersIncludingNull == 0) return (string.Empty, offset + 1);
        var byteCount = Math.Max(0, (charactersIncludingNull - 1) * 2);
        var available = Math.Min(byteCount, data.Length - offset - 1);
        available -= available % 2;
        var value = Encoding.Unicode.GetString(data, offset + 1, available);
        var next = Math.Min(data.Length, offset + 1 + charactersIncludingNull * 2);
        return (value, next);
    }

    private static string DisplayDate(string value)
    {
        if (value.Length < 8) return "—";
        var result = $"{value[..4]}-{value[4..6]}-{value[6..8]}";
        if (value.Length >= 15 && value[8] == 'T')
        {
            result += $" {value[9..11]}:{value[11..13]}:{value[13..15]}";
        }
        return result;
    }

    private static string StorageLabel(uint id) => $"存储卡 {id:X8}";

    private static ushort ReadUInt16(byte[] data, int offset) =>
        offset >= 0 && offset + 2 <= data.Length
            ? BinaryPrimitives.ReadUInt16LittleEndian(data.AsSpan(offset, 2))
            : (ushort)0;

    private static uint ReadUInt32(byte[] data, int offset) =>
        offset >= 0 && offset + 4 <= data.Length
            ? BinaryPrimitives.ReadUInt32LittleEndian(data.AsSpan(offset, 4))
            : 0;

    private static long ReadUInt64Saturated(byte[] data, int offset)
    {
        if (offset < 0 || offset + 8 > data.Length) return 0;
        var value = BinaryPrimitives.ReadUInt64LittleEndian(data.AsSpan(offset, 8));
        return value > long.MaxValue ? long.MaxValue : (long)value;
    }

    private static int SaturatedInt(uint value) =>
        value > int.MaxValue ? int.MaxValue : (int)value;
}
