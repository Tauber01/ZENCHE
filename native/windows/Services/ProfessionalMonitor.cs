using NikonLink.Windows.Models;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;

namespace NikonLink.Windows.Services;

public sealed record ProfessionalMonitorResult(
    BitmapSource Image,
    string RedHistogram,
    string GreenHistogram,
    string BlueHistogram,
    string Waveform,
    string Vectorscope,
    int PeakingCoverage);

public static class ProfessionalMonitor
{
    private const int ScopeColumns = 64;
    private const int ScopeRows = 48;
    private const string Hex = "0123456789ABCDEF";

    public static ProfessionalMonitorResult Process(
        BitmapSource source,
        bool focusPeaking,
        bool falseColor) => Process(source, focusPeaking, falseColor, null);

    internal static ProfessionalMonitorResult Process(
        BitmapSource source,
        bool focusPeaking,
        bool falseColor,
        NikonCloudPreset? nikonCloudPreset)
    {
        BitmapSource working = new FormatConvertedBitmap(
            source,
            PixelFormats.Bgra32,
            null,
            0);
        var scale = Math.Min(
            1,
            640.0 / Math.Max(working.PixelWidth, working.PixelHeight));
        if (scale < 1)
        {
            var resized = new TransformedBitmap(
                working,
                new ScaleTransform(scale, scale));
            resized.Freeze();
            working = resized;
        }
        var width = working.PixelWidth;
        var height = working.PixelHeight;
        var stride = width * 4;
        var pixels = new byte[stride * height];
        working.CopyPixels(pixels, stride, 0);
        var luminance = focusPeaking
            ? new int[width * height]
            : null;
        var red = ScopeBuffer();
        var green = ScopeBuffer();
        var blue = ScopeBuffer();
        var lumaScope = ScopeBuffer();
        var cbScope = ScopeBuffer();
        var crScope = ScopeBuffer();

        for (var y = 0; y < height; y++)
        {
            for (var x = 0; x < width; x++)
            {
                var pixel = y * width + x;
                var offset = y * stride + x * 4;
                var b = (int)pixels[offset];
                var g = (int)pixels[offset + 1];
                var r = (int)pixels[offset + 2];
                if (nikonCloudPreset is not null)
                {
                    var cloudRed = r / 255.0;
                    var cloudGreen = g / 255.0;
                    var cloudBlue = b / 255.0;
                    nikonCloudPreset.ApplyPreviewEffect(
                        ref cloudRed,
                        ref cloudGreen,
                        ref cloudBlue);
                    r = Clamp8((int)Math.Round(cloudRed * 255));
                    g = Clamp8((int)Math.Round(cloudGreen * 255));
                    b = Clamp8((int)Math.Round(cloudBlue * 255));
                    pixels[offset] = (byte)b;
                    pixels[offset + 1] = (byte)g;
                    pixels[offset + 2] = (byte)r;
                    pixels[offset + 3] = 255;
                }
                var value = (54 * r + 183 * g + 19 * b) >> 8;
                if (luminance is not null)
                {
                    luminance[pixel] = value;
                }
                var column = Math.Min(ScopeColumns - 1, x * ScopeColumns / Math.Max(1, width));
                Accumulate(red, column, r);
                Accumulate(green, column, g);
                Accumulate(blue, column, b);
                Accumulate(lumaScope, column, value);
                var cb = Clamp8(128 + ((-29 * r - 99 * g + 128 * b) >> 8));
                var cr = Clamp8(128 + ((128 * r - 116 * g - 12 * b) >> 8));
                Accumulate(cbScope, column, cb);
                Accumulate(crScope, column, cr);
                if (falseColor)
                {
                    var color = FalseColor(value);
                    pixels[offset] = color.B;
                    pixels[offset + 1] = color.G;
                    pixels[offset + 2] = color.R;
                }
            }
        }

        var peakingPixels = 0;
        if (focusPeaking && width > 2 && height > 2)
        {
            for (var y = 1; y < height - 1; y++)
            {
                for (var x = 1; x < width - 1; x++)
                {
                    var pixel = y * width + x;
                    var horizontal = Math.Abs(
                        luminance![pixel - 1] - luminance[pixel + 1]);
                    var vertical = Math.Abs(
                        luminance[pixel - width] -
                        luminance[pixel + width]);
                    if (horizontal + vertical <= 72)
                    {
                        continue;
                    }
                    var offset = y * stride + x * 4;
                    pixels[offset] = 205;
                    pixels[offset + 1] = 38;
                    pixels[offset + 2] = 255;
                    pixels[offset + 3] = 255;
                    peakingPixels++;
                }
            }
        }

        BitmapSource output;
        if (focusPeaking || falseColor || nikonCloudPreset is not null)
        {
            var rendered = new WriteableBitmap(
                width,
                height,
                source.DpiX,
                source.DpiY,
                PixelFormats.Bgra32,
                null);
            rendered.WritePixels(
                new Int32Rect(0, 0, width, height),
                pixels,
                stride,
                0);
            rendered.Freeze();
            output = rendered;
        }
        else
        {
            working.Freeze();
            output = working;
        }
        return new ProfessionalMonitorResult(
            output,
            DensityMap(red),
            DensityMap(green),
            DensityMap(blue),
            DensityMap(lumaScope),
            $"{DensityMap(cbScope)}|{DensityMap(crScope)}",
            (int)Math.Round(
                peakingPixels * 100.0 / Math.Max(1, width * height)));
    }

    private static int[] ScopeBuffer() => new int[ScopeColumns * ScopeRows];

    private static void Accumulate(int[] buffer, int column, int value)
    {
        var row = ScopeRows - 1 - Clamp8(value) * (ScopeRows - 1) / 255;
        buffer[row * ScopeColumns + column]++;
    }

    private static int Clamp8(int value) => Math.Min(255, Math.Max(0, value));

    private static Color FalseColor(int luma) => luma switch
    {
        < 32 => Color.FromRgb(18, 24, 150),
        < 64 => Color.FromRgb(0, 150, 255),
        < 112 => Color.FromRgb(32, 205, 120),
        < 160 => Color.FromRgb(126, 126, 126),
        < 208 => Color.FromRgb(255, 205, 20),
        < 240 => Color.FromRgb(255, 92, 32),
        _ => Color.FromRgb(255, 32, 56)
    };

    private static string DensityMap(int[] values)
    {
        var maximum = Math.Max(1, values.Max());
        var divisor = Math.Log(1.0 + maximum);
        return $"S{ScopeColumns}x{ScopeRows}:" + new string(values.Select(value =>
            Hex[Math.Min(15, Math.Max(0,
                (int)Math.Round(Math.Log(1.0 + value) / divisor * 15)))])
            .ToArray());
    }
}
