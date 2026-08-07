using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices.WindowsRuntime;
using System.Threading.Tasks;
using Windows.Graphics.Imaging;
using Windows.Storage;
using Windows.Storage.Streams;

namespace NikonLink.Windows.Services;

/// <summary>
/// E7 焦点包围合成：把不同对焦距离的序列帧合成一张全清晰 JPEG。
/// 算法（五端同构，纯 CPU 逐像素）：
///   1. 全局亮度归一——以首帧平均亮度为基准，每帧 scale = clamp(mean0/mean_i, 0.5, 2.0)
///      （手持微抖/曝光微差的包围帧亮度归一；亚像素位移对齐工程量过大，列入 backlog）。
///   2. 清晰度测度——3×3 拉普拉斯核（全 8 邻域中心 8）作用于归一亮度，取绝对响应。
///   3. 逐像素融合——取 |lap| 最大帧的 BGRA（×scale 归一），边界 1px 取首帧。
/// 内存优化：两遍式逐帧融合，峰值仅 2 帧像素 + 全局 best 数组（不保留全部帧）。
/// 损坏帧跳过并计数，不整批失败；进度回调 + 取消检查。
/// TBC-awaiting-hardware（合成结果依赖真实包围序列，需实机验证）。
/// </summary>
public sealed class FocusStackComposer
{
    public sealed record Result(
        string Url,
        int SourcesUsed,
        int SkippedFrames);

    /// <summary>
    /// 逐帧合成。progress 报告 (已处理帧数, 总帧数)；取消时抛
    /// OperationCanceledException。
    /// </summary>
    public async Task<Result> ComposeAsync(
        IReadOnlyList<string> frames,
        string outputPath,
        Func<bool> isCancelled,
        Action<int, int>? onProgress = null)
    {
        if (frames.Count == 0)
        {
            throw new InvalidOperationException("请至少选择一帧。");
        }

        // 首帧尺寸作为统一画布（包围帧同尺寸；异尺寸按 aspect-fit 黑底绘制）。
        var (width, height) = await DecodeSizeAsync(frames[0]);
        if (width <= 0 || height <= 0)
        {
            throw new InvalidOperationException("所选帧均无法解码，未生成合成图。");
        }

        var bestRgb = new byte[width * height * 3];
        var bestLap = new float[width * height];
        for (var i = 0; i < bestLap.Length; i++)
        {
            bestLap[i] = -1f;
        }
        var skipped = 0;
        var sourcesUsed = 0;
        double referenceMean = 0;

        for (var index = 0; index < frames.Count; index++)
        {
            if (isCancelled())
            {
                throw new OperationCanceledException("已取消");
            }
            var rgb = await DecodeFrameToRgbAsync(frames[index], width, height);
            if (rgb is null)
            {
                skipped++;
                onProgress?.Invoke(index + 1, frames.Count);
                continue;
            }
            var luminance = new float[width * height];
            double sum = 0;
            for (var pixel = 0; pixel < width * height; pixel++)
            {
                var offset = pixel * 3;
                var y = (77f * rgb[offset] + 150f * rgb[offset + 1] + 29f * rgb[offset + 2]) / 255f;
                luminance[pixel] = y;
                sum += y;
            }
            var mean = sum / (width * height);

            if (sourcesUsed == 0)
            {
                referenceMean = mean;
                Array.Copy(rgb, bestRgb, rgb.Length);
                for (var y = 1; y < height - 1; y++)
                {
                    for (var x = 1; x < width - 1; x++)
                    {
                        var p = y * width + x;
                        bestLap[p] = Math.Abs(
                            8 * luminance[p]
                            - luminance[p - width] - luminance[p + width]
                            - luminance[p - 1] - luminance[p + 1]
                            - luminance[p - width - 1] - luminance[p - width + 1]
                            - luminance[p + width - 1] - luminance[p + width + 1]);
                    }
                }
            }
            else
            {
                var scale = (float)Math.Clamp(
                    mean == 0 ? 1.0 : referenceMean / mean, 0.5, 2.0);
                var normalized = new float[width * height];
                for (var pixel = 0; pixel < width * height; pixel++)
                {
                    normalized[pixel] = luminance[pixel] * scale;
                }
                for (var y = 1; y < height - 1; y++)
                {
                    for (var x = 1; x < width - 1; x++)
                    {
                        var p = y * width + x;
                        var lap = Math.Abs(
                            8 * normalized[p]
                            - normalized[p - width] - normalized[p + width]
                            - normalized[p - 1] - normalized[p + 1]
                            - normalized[p - width - 1] - normalized[p - width + 1]
                            - normalized[p + width - 1] - normalized[p + width + 1]);
                        if (lap > bestLap[p])
                        {
                            bestLap[p] = lap;
                            var offset = p * 3;
                            bestRgb[offset] = ClampByte(rgb[offset] * scale);
                            bestRgb[offset + 1] = ClampByte(rgb[offset + 1] * scale);
                            bestRgb[offset + 2] = ClampByte(rgb[offset + 2] * scale);
                        }
                    }
                }
            }
            sourcesUsed++;
            onProgress?.Invoke(index + 1, frames.Count);
        }

        if (sourcesUsed < 2)
        {
            throw new InvalidOperationException(
                $"可合成帧不足（成功解码 {sourcesUsed} 帧，焦点合成需要至少 2 帧）。");
        }

        await EncodeJpegAsync(outputPath, bestRgb, width, height);
        return new Result(outputPath, sourcesUsed, skipped);
    }

    private static byte ClampByte(float value)
    {
        return (byte)Math.Max(0, Math.Min(255, MathF.Round(value)));
    }

    // MARK: - 帧解码

    private static async Task<(int Width, int Height)> DecodeSizeAsync(string path)
    {
        try
        {
            var file = await StorageFile.GetFileFromPathAsync(path);
            using var stream = await file.OpenReadAsync();
            var decoder = await BitmapDecoder.CreateAsync(stream);
            return ((int)decoder.PixelWidth, (int)decoder.PixelHeight);
        }
        catch
        {
            return (0, 0);
        }
    }

    /// <summary>
    /// 解码单帧并绘制到统一画布（aspect-fit 黑底），返回 RGB888。失败返回 null。
    /// </summary>
    private static async Task<byte[]?> DecodeFrameToRgbAsync(
        string path,
        int width,
        int height)
    {
        try
        {
            var file = await StorageFile.GetFileFromPathAsync(path);
            using var stream = await file.OpenReadAsync();
            var decoder = await BitmapDecoder.CreateAsync(stream);
            // 先按原始尺寸解码为 BGRA8。
            var source = await decoder.GetSoftwareBitmapAsync(
                BitmapPixelFormat.Bgra8, BitmapAlphaMode.Ignore);
            var sourceBytes = new byte[source.PixelWidth * source.PixelHeight * 4];
            source.CopyToBuffer(sourceBytes.AsBuffer());

            var canvas = new byte[width * height * 3]; // RGB 黑底（默认全 0）
            var srcW = (int)source.PixelWidth;
            var srcH = (int)source.PixelHeight;
            if (srcW == width && srcH == height)
            {
                // 同尺寸直拷（BGRA → RGB）。
                for (var pixel = 0; pixel < width * height; pixel++)
                {
                    var src = pixel * 4;
                    var dst = pixel * 3;
                    canvas[dst] = sourceBytes[src + 2]; // R
                    canvas[dst + 1] = sourceBytes[src + 1]; // G
                    canvas[dst + 2] = sourceBytes[src]; // B
                }
            }
            else
            {
                // aspect-fit：等比缩放并居中（最近邻，与 Apple/Android 端画布语义对齐）。
                var scale = Math.Min(
                    (double)width / srcW, (double)height / srcH);
                var fittedWidth = Math.Max(1, (int)Math.Floor(srcW * scale));
                var fittedHeight = Math.Max(1, (int)Math.Floor(srcH * scale));
                var offsetX = (width - fittedWidth) / 2;
                var offsetY = (height - fittedHeight) / 2;
                for (var y = 0; y < fittedHeight; y++)
                {
                    var srcY = Math.Min(srcH - 1, (int)Math.Floor(y / scale));
                    for (var x = 0; x < fittedWidth; x++)
                    {
                        var srcX = Math.Min(srcW - 1, (int)Math.Floor(x / scale));
                        var src = (srcY * srcW + srcX) * 4;
                        var dst = ((offsetY + y) * width + (offsetX + x)) * 3;
                        canvas[dst] = sourceBytes[src + 2];
                        canvas[dst + 1] = sourceBytes[src + 1];
                        canvas[dst + 2] = sourceBytes[src];
                    }
                }
            }
            return canvas;
        }
        catch
        {
            return null;
        }
    }

    // MARK: - JPEG 写出

    private static async Task EncodeJpegAsync(
        string outputPath,
        byte[] rgb,
        int width,
        int height)
    {
        var outputFolder = await StorageFolder.GetFolderFromPathAsync(
            Path.GetDirectoryName(outputPath)
            ?? throw new InvalidOperationException("输出目录无效。"));
        var file = await outputFolder.CreateFileAsync(
            Path.GetFileName(outputPath),
            CreationCollisionOption.ReplaceExisting);
        using (var stream = await file.OpenAsync(FileAccessMode.ReadWrite))
        {
            var encoder = await BitmapEncoder.CreateAsync(
                BitmapEncoder.JpegEncoderId, stream);
            var bgra = new byte[width * height * 4];
            for (var pixel = 0; pixel < width * height; pixel++)
            {
                var src = pixel * 3;
                var dst = pixel * 4;
                bgra[dst] = rgb[src + 2]; // B
                bgra[dst + 1] = rgb[src + 1]; // G
                bgra[dst + 2] = rgb[src]; // R
                bgra[dst + 3] = 255; // A
            }
            encoder.SetPixelData(
                BitmapPixelFormat.Bgra8,
                BitmapAlphaMode.Ignore,
                (uint)width,
                (uint)height,
                96,
                96,
                bgra);
            await encoder.FlushAsync();
        }
    }
}
