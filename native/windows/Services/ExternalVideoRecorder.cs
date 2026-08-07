using System.IO;
using System.Text;

namespace NikonLink.Windows.Services;

/// <summary>
/// Streams JPEG live-view frames into a seekable Motion-JPEG AVI. This keeps
/// tethered recording independent of vendor-specific movie download APIs.
/// </summary>
public sealed class ExternalVideoRecorder : IDisposable
{
    public sealed record RecordingResult(string Path, int Frames, long Bytes);

    private sealed record IndexEntry(long Offset, int Size);

    private readonly object _gate = new();
    private readonly List<IndexEntry> _index = [];
    private FileStream? _stream;
    private BinaryWriter? _writer;
    private string? _path;
    private int _frameRate;
    private int _width;
    private int _height;
    private int _largestFrame;
    private long _lastFrameTicks;
    private long _riffSizeOffset;
    private long _totalFramesOffset;
    private long _streamLengthOffset;
    private long _suggestedBufferOffset;
    private long _streamSuggestedBufferOffset;
    private long _moviSizeOffset;
    private long _moviTypeOffset;
    private long _moviDataOffset;

    public bool IsRecording
    {
        get { lock (_gate) return _path is not null; }
    }

    public void Start(string path, int frameRate)
    {
        lock (_gate)
        {
            if (_path is not null) throw new InvalidOperationException(
                "外录已经开始。");
            Directory.CreateDirectory(Path.GetDirectoryName(path) ?? ".");
            _path = path;
            _frameRate = Math.Clamp(frameRate, 1, 120);
            _width = 0;
            _height = 0;
            _largestFrame = 0;
            _lastFrameTicks = 0;
            _index.Clear();
        }
    }

    public void AppendJpeg(byte[] jpeg, bool throttle = true)
    {
        lock (_gate)
        {
            if (_path is null || jpeg.Length == 0) return;
            var now = System.Diagnostics.Stopwatch.GetTimestamp();
            if (throttle)
            {
                var minimumTicks = System.Diagnostics.Stopwatch.Frequency /
                    Math.Max(1, _frameRate);
                if (_lastFrameTicks != 0 && now - _lastFrameTicks < minimumTicks)
                {
                    return;
                }
            }
            if (_writer is null)
            {
                (_width, _height) = JpegDimensions(jpeg);
                _stream = new FileStream(
                    _path,
                    FileMode.Create,
                    FileAccess.ReadWrite,
                    FileShare.Read,
                    1024 * 1024,
                    FileOptions.SequentialScan);
                _writer = new BinaryWriter(_stream, Encoding.ASCII, leaveOpen: true);
                WriteHeader();
            }
            var chunkOffset = _stream!.Position;
            Ascii("00dc");
            Int32(jpeg.Length);
            _writer.Write(jpeg);
            if ((jpeg.Length & 1) != 0) _writer.Write((byte)0);
            _index.Add(new IndexEntry(chunkOffset - _moviTypeOffset, jpeg.Length));
            _largestFrame = Math.Max(_largestFrame, jpeg.Length);
            _lastFrameTicks = now;
        }
    }

    public RecordingResult? StopIfRecording()
    {
        lock (_gate)
        {
            return _path is null ? null : StopLocked();
        }
    }

    public RecordingResult Stop()
    {
        lock (_gate)
        {
            if (_path is null) throw new InvalidOperationException(
                "外录尚未开始。");
            return StopLocked();
        }
    }

    public void Abort()
    {
        lock (_gate)
        {
            var abandoned = _path;
            _path = null;
            _writer?.Dispose();
            _writer = null;
            _stream?.Dispose();
            _stream = null;
            _index.Clear();
            if (abandoned is not null) File.Delete(abandoned);
        }
    }

    public void Dispose() => Abort();

    private RecordingResult StopLocked()
    {
        var finished = _path!;
        _path = null;
        if (_writer is null || _stream is null || _index.Count == 0)
        {
            _writer?.Dispose();
            _stream?.Dispose();
            _writer = null;
            _stream = null;
            if (File.Exists(finished)) File.Delete(finished);
            throw new IOException("没有收到可写入的实时取景帧。");
        }
        var frameCount = _index.Count;
        var indexStart = _stream.Position;
        Ascii("idx1");
        Int32(frameCount * 16L);
        foreach (var entry in _index)
        {
            Ascii("00dc");
            Int32(0x10);
            Int32(entry.Offset);
            Int32(entry.Size);
        }
        var fileLength = _stream.Position;
        PatchInt32(_riffSizeOffset, fileLength - 8);
        PatchInt32(_totalFramesOffset, frameCount);
        PatchInt32(_streamLengthOffset, frameCount);
        PatchInt32(_suggestedBufferOffset, _largestFrame);
        PatchInt32(_streamSuggestedBufferOffset, _largestFrame);
        PatchInt32(_moviSizeOffset, 4 + indexStart - _moviDataOffset);
        _writer.Flush();
        _stream.Flush(flushToDisk: true);
        _writer.Dispose();
        _stream.Dispose();
        _writer = null;
        _stream = null;
        _index.Clear();
        return new RecordingResult(finished, frameCount, fileLength);
    }

    private void WriteHeader()
    {
        Ascii("RIFF");
        _riffSizeOffset = _stream!.Position;
        Int32(0);
        Ascii("AVI ");
        Ascii("LIST");
        var hdrlSizeOffset = _stream.Position;
        Int32(0);
        Ascii("hdrl");
        var hdrlDataOffset = _stream.Position;

        Ascii("avih");
        Int32(56);
        Int32(1_000_000 / _frameRate);
        Int32(0); Int32(0); Int32(0x10);
        _totalFramesOffset = _stream.Position;
        Int32(0);
        Int32(0); Int32(1);
        _suggestedBufferOffset = _stream.Position;
        Int32(0);
        Int32(_width); Int32(_height);
        Int32(0); Int32(0); Int32(0); Int32(0);

        Ascii("LIST");
        var strlSizeOffset = _stream.Position;
        Int32(0);
        Ascii("strl");
        var strlDataOffset = _stream.Position;
        Ascii("strh");
        Int32(56);
        Ascii("vids"); Ascii("MJPG");
        Int32(0); Int16(0); Int16(0); Int32(0);
        Int32(1); Int32(_frameRate); Int32(0);
        _streamLengthOffset = _stream.Position;
        Int32(0);
        _streamSuggestedBufferOffset = _stream.Position;
        Int32(0);
        Int32(uint.MaxValue); Int32(0);
        Int16(0); Int16(0); Int16(_width); Int16(_height);

        Ascii("strf");
        Int32(40); Int32(40);
        Int32(_width); Int32(_height);
        Int16(1); Int16(24); Ascii("MJPG");
        Int32((long)_width * _height * 3);
        Int32(0); Int32(0); Int32(0); Int32(0);
        var headerEnd = _stream.Position;
        PatchInt32(strlSizeOffset, headerEnd - strlDataOffset + 4);
        PatchInt32(hdrlSizeOffset, headerEnd - hdrlDataOffset + 4);
        _stream.Position = headerEnd;
        Ascii("LIST");
        _moviSizeOffset = _stream.Position;
        Int32(0);
        _moviTypeOffset = _stream.Position;
        Ascii("movi");
        _moviDataOffset = _stream.Position;
    }

    private void PatchInt32(long offset, long value)
    {
        var current = _stream!.Position;
        _stream.Position = offset;
        Int32(value);
        _stream.Position = current;
    }

    private void Ascii(string value) =>
        _writer!.Write(Encoding.ASCII.GetBytes(value));

    private void Int16(long value)
    {
        _writer!.Write((byte)(value & 0xff));
        _writer.Write((byte)((value >> 8) & 0xff));
    }

    private void Int32(long value)
    {
        _writer!.Write((byte)(value & 0xff));
        _writer.Write((byte)((value >> 8) & 0xff));
        _writer.Write((byte)((value >> 16) & 0xff));
        _writer.Write((byte)((value >> 24) & 0xff));
    }

    private static (int Width, int Height) JpegDimensions(byte[] jpeg)
    {
        if (jpeg.Length < 4 || jpeg[0] != 0xff || jpeg[1] != 0xd8)
        {
            throw new IOException("实时取景帧不是有效 JPEG。");
        }
        var offset = 2;
        while (offset + 8 < jpeg.Length)
        {
            while (offset < jpeg.Length && jpeg[offset] != 0xff) offset++;
            while (offset < jpeg.Length && jpeg[offset] == 0xff) offset++;
            if (offset >= jpeg.Length) break;
            var marker = jpeg[offset++];
            if (marker is 0xd8 or 0xd9) continue;
            if (offset + 1 >= jpeg.Length) break;
            var length = (jpeg[offset] << 8) | jpeg[offset + 1];
            if (length < 2 || offset + length > jpeg.Length) break;
            if (marker is >= 0xc0 and <= 0xc3 or >= 0xc5 and <= 0xc7 or
                >= 0xc9 and <= 0xcb or >= 0xcd and <= 0xcf)
            {
                var height = (jpeg[offset + 3] << 8) | jpeg[offset + 4];
                var width = (jpeg[offset + 5] << 8) | jpeg[offset + 6];
                if (width > 0 && height > 0) return (width, height);
            }
            offset += length;
        }
        throw new IOException("无法读取实时取景 JPEG 尺寸。");
    }
}
