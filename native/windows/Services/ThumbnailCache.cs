using System.Collections.Concurrent;
using System.IO;
using System.Windows.Media.Imaging;

namespace NikonLink.Windows.Services;

/// <summary>
/// Bounded in-memory thumbnail cache for local library files.
/// Decodes images on a background thread and returns frozen <see cref="BitmapSource"/>
/// instances that can be used from the UI thread.
/// </summary>
public sealed class ThumbnailCache
{
    private sealed class CacheEntry(BitmapSource source, DateTime accessedAt)
    {
        public BitmapSource Source { get; } = source;
        public DateTime AccessedAt { get; set; } = accessedAt;
    }

    private const int Capacity = 128;
    private const int DecodePixelWidth = 240;
    private readonly ConcurrentDictionary<string, CacheEntry> _cache = new();
    private readonly SemaphoreSlim _gate = new(1, 1);

    /// <summary>
    /// Returns a frozen thumbnail for <paramref name="path"/>.
    /// Results are decoded on a background thread and cached with an LRU eviction policy.
    /// </summary>
    public async Task<BitmapSource?> GetAsync(string path)
    {
        if (string.IsNullOrWhiteSpace(path) || !File.Exists(path))
        {
            return null;
        }

        var normalized = Path.GetFullPath(path);
        if (_cache.TryGetValue(normalized, out var existing))
        {
            existing.AccessedAt = DateTime.UtcNow;
            return existing.Source;
        }

        await _gate.WaitAsync().ConfigureAwait(false);
        try
        {
            // Double-check after acquiring the gate.
            if (_cache.TryGetValue(normalized, out existing))
            {
                existing.AccessedAt = DateTime.UtcNow;
                return existing.Source;
            }

            var source = await Task.Run(() => DecodeThumbnail(normalized)).ConfigureAwait(false);
            if (source is null)
            {
                return null;
            }

            EvictIfNeeded();
            _cache[normalized] = new CacheEntry(source, DateTime.UtcNow);
            return source;
        }
        finally
        {
            _gate.Release();
        }
    }

    private static BitmapSource? DecodeThumbnail(string path)
    {
        try
        {
            var bitmap = new BitmapImage();
            bitmap.BeginInit();
            bitmap.CacheOption = BitmapCacheOption.OnLoad;
            bitmap.DecodePixelWidth = DecodePixelWidth;
            bitmap.UriSource = new Uri(path, UriKind.Absolute);
            bitmap.EndInit();
            bitmap.Freeze();
            return bitmap;
        }
        catch
        {
            return null;
        }
    }

    private void EvictIfNeeded()
    {
        while (_cache.Count >= Capacity)
        {
            var oldest = _cache.MinBy(entry => entry.Value.AccessedAt);
            if (oldest.Key is null)
            {
                break;
            }

            _cache.TryRemove(oldest.Key, out _);
        }
    }
}
