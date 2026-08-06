using System.Diagnostics;
using System.IO;

namespace NikonLink.Windows.Services;

/// <summary>
/// 内存环形取景帧缓冲 + 快门切片（E5 live 图，路线 B）：
/// 取景开启时常开入环（只保留最近 maxSeconds 帧），快门触发时把
/// 最近 N 秒帧写为 Motion-JPEG AVI，与照片共用 reservedBaseName 配对入库。
/// TBC-awaiting-hardware（实机取景帧率/码率待验证）。
/// </summary>
public sealed class LivePhotoClipRecorder
{
    private sealed record RingFrame(byte[] Data, long TimestampTicks);

    private readonly object _gate = new();
    private bool _armed;
    private readonly List<RingFrame> _ring = [];
    private int _frameRate = 10;
    private double _maxSeconds = 3.0;
    private long _lastAppendTicks;

    public bool IsArmed
    {
        get { lock (_gate) return _armed; }
    }

    public void Arm(int frameRate, double maxSeconds)
    {
        lock (_gate)
        {
            _armed = true;
            _frameRate = Math.Clamp(frameRate, 1, 120);
            _maxSeconds = Math.Clamp(maxSeconds, 0.5, 30);
            _ring.Clear();
            _lastAppendTicks = 0;
        }
    }

    public void Disarm()
    {
        lock (_gate)
        {
            _armed = false;
            _ring.Clear();
            _lastAppendTicks = 0;
        }
    }

    /// <summary>按帧率节流入环；超过 maxSeconds 的旧帧被淘汰。</summary>
    public void Append(byte[] jpeg)
    {
        lock (_gate)
        {
            if (!_armed || jpeg.Length == 0)
            {
                return;
            }
            var now = Stopwatch.GetTimestamp();
            if (_lastAppendTicks != 0 &&
                now - _lastAppendTicks <
                Stopwatch.Frequency / Math.Max(1, _frameRate))
            {
                return;
            }
            _lastAppendTicks = now;
            _ring.Add(new RingFrame(jpeg, now));
            var cutoff = now - (long)(Stopwatch.Frequency * _maxSeconds);
            while (_ring.Count > 0 && _ring[0].TimestampTicks < cutoff)
            {
                _ring.RemoveAt(0);
            }
        }
    }

    /// <summary>把最近 maxSeconds 帧写为 AVI 切片；环为空返回 null。
    /// 复用 ExternalVideoRecorder 的 AVI 写入逻辑（字节级同构五端）。</summary>
    public ExternalVideoRecorder.RecordingResult? CaptureSlice(string path)
    {
        byte[][] frames;
        lock (_gate)
        {
            if (!_armed || _ring.Count == 0)
            {
                return null;
            }
            frames = _ring.Select(frame => frame.Data).ToArray();
        }
        var recorder = new ExternalVideoRecorder();
        try
        {
            recorder.Start(path, _frameRate);
            foreach (var frame in frames)
            {
                recorder.AppendJpeg(frame, throttle: false);
            }
            return recorder.StopIfRecording();
        }
        catch
        {
            recorder.Abort();
            throw;
        }
    }
}
