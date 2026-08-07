using System.IO;
using Windows.Foundation;
using Windows.Media.Editing;
using Windows.Media.MediaProperties;
using Windows.Media.Transcoding;
using Windows.Storage;

namespace NikonLink.Windows.Services;

/// <summary>
/// E6 延时合成：把序列帧（JPEG/PNG/HEIC/TIFF）按帧率编码为 H.264 MP4。
/// Windows 用平台原生编码链：MediaClip.CreateFromImageFileAsync 将每帧图像
/// 作为静态帧 clip 装入 MediaComposition，RenderToFileAsync 渲染为 H.264 MP4。
/// 损坏帧跳过并计数，不整批失败；进度回调 + 取消检查。
/// TBC-awaiting-hardware（编码器行为依赖系统，需实机验证）。
/// </summary>
public sealed class TimelapseComposer
{
    public sealed record Options(
        int FrameRate = 24); // 24/25/30

    public sealed record Result(
        string Url,
        int FramesWritten,
        int SkippedFrames);

    /// <summary>
    /// 逐帧合成。progress 报告 (已处理帧数, 总帧数)；取消时抛
    /// OperationCanceledException。
    /// </summary>
    public async Task<Result> ComposeAsync(
        IReadOnlyList<string> frames,
        string outputPath,
        Options options,
        Func<bool> isCancelled,
        Action<int, int>? onProgress = null)
    {
        if (frames.Count == 0)
        {
            throw new InvalidOperationException("请至少选择一帧。");
        }
        var fps = Math.Clamp(options.FrameRate, 1, 60);

        var composition = new MediaComposition();
        var skipped = 0;

        // 首帧尺寸作为统一画布；异尺寸帧由渲染器按画面适配（黑边补齐）。
        for (var index = 0; index < frames.Count; index++)
        {
            if (isCancelled())
            {
                throw new OperationCanceledException();
            }
            try
            {
                var file = await StorageFile.GetFileFromPathAsync(frames[index]);
                // 首参 originalDuration 即该静态帧在成片中的时长；TrimmedDuration 只读。
                var clip = await MediaClip.CreateFromImageFileAsync(
                    file,
                    TimeSpan.FromSeconds(1.0 / fps));
                composition.Clips.Add(clip);
            }
            catch
            {
                skipped++;
            }
            onProgress?.Invoke(index + 1, frames.Count);
        }

        var written = composition.Clips.Count;
        if (written == 0)
        {
            throw new InvalidOperationException("所选帧均无法解码，未生成视频。");
        }

        var outputFolderPath = Path.GetDirectoryName(outputPath)
            ?? throw new InvalidOperationException("输出目录无效。");
        var outputFolder = await StorageFolder.GetFolderFromPathAsync(
            outputFolderPath);
        var outputFile = await outputFolder.CreateFileAsync(
            Path.GetFileName(outputPath),
            CreationCollisionOption.ReplaceExisting);
        var profile = MediaEncodingProfile.CreateMp4(
            VideoEncodingQuality.HD1080p);
        profile.Video.FrameRate.Numerator = (uint)fps;
        profile.Video.FrameRate.Denominator = 1;

        // RenderToFileAsync 返回 IAsyncOperationWithProgress<TranscodeFailureReason,
        // double>（进度 0-100）。直接用原始 WinRT 异步对象挂 Progress/Completed
        // 委托，避免 AsTask 扩展方法在 CsWinRT 投影下的重载签名差异；取消经
        // 轮询调 action.Cancel()。
        var action = composition.RenderToFileAsync(
            outputFile,
            MediaTrimmingPreference.Precise,
            profile);
        action.Progress = (_, value) =>
        {
            var total = Math.Max(1, frames.Count);
            var done = (int)Math.Round(value / 100.0 * total);
            onProgress?.Invoke(Math.Min(done, total), total);
        };

        var tcs = new TaskCompletionSource<bool>(
            TaskCreationOptions.RunContinuationsAsynchronously);
        action.Completed = (_, status) =>
        {
            switch (status)
            {
                case AsyncStatus.Completed:
                    tcs.SetResult(true);
                    break;
                case AsyncStatus.Canceled:
                    tcs.SetCanceled();
                    break;
                default:
                    tcs.SetException(action.ErrorCode
                        ?? new InvalidOperationException("视频渲染失败。"));
                    break;
            }
        };

        var poller = PollCancellationAsync(isCancelled, action);
        try
        {
            await tcs.Task;
        }
        finally
        {
            await poller;
        }
        return new Result(outputPath, written, skipped);
    }

    private static async Task PollCancellationAsync(
        Func<bool> isCancelled,
        IAsyncOperationWithProgress<TranscodeFailureReason, double> action)
    {
        while (!isCancelled() && action.Status == AsyncStatus.Started)
        {
            await Task.Delay(100);
        }
        if (isCancelled() && action.Status == AsyncStatus.Started)
        {
            action.Cancel();
        }
    }
}
