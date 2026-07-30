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
    private static readonly char[] Bars = "▁▂▃▄▅▆▇█".ToCharArray();

    public static ProfessionalMonitorResult Process(
        BitmapSource source,
        bool focusPeaking,
        bool falseColor)
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
        var red = new int[16];
        var green = new int[16];
        var blue = new int[16];
        var waveformSum = new int[24];
        var waveformCount = new int[24];
        var hueSum = new int[24];
        var hueCount = new int[24];

        for (var y = 0; y < height; y++)
        {
            for (var x = 0; x < width; x++)
            {
                var pixel = y * width + x;
                var offset = y * stride + x * 4;
                var b = pixels[offset];
                var g = pixels[offset + 1];
                var r = pixels[offset + 2];
                var value = (54 * r + 183 * g + 19 * b) >> 8;
                if (luminance is not null)
                {
                    luminance[pixel] = value;
                }
                red[Math.Min(15, r >> 4)]++;
                green[Math.Min(15, g >> 4)]++;
                blue[Math.Min(15, b >> 4)]++;
                var column = Math.Min(23, x * 24 / Math.Max(1, width));
                waveformSum[column] += value;
                waveformCount[column]++;
                var maximum = Math.Max(r, Math.Max(g, b));
                var minimum = Math.Min(r, Math.Min(g, b));
                var saturation = maximum - minimum;
                if (saturation > 8)
                {
                    var hue = HueIndex(r, g, b, maximum, saturation);
                    hueSum[hue] += saturation;
                    hueCount[hue]++;
                }
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
        if (focusPeaking || falseColor)
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
            Sparkline(red),
            Sparkline(green),
            Sparkline(blue),
            Sparkline(Averages(waveformSum, waveformCount)),
            Sparkline(Averages(hueSum, hueCount)),
            (int)Math.Round(
                peakingPixels * 100.0 / Math.Max(1, width * height)));
    }

    private static int HueIndex(
        int red,
        int green,
        int blue,
        int maximum,
        int delta)
    {
        double hue;
        if (maximum == red)
        {
            hue = (green - blue) / (double)delta;
        }
        else if (maximum == green)
        {
            hue = 2 + (blue - red) / (double)delta;
        }
        else
        {
            hue = 4 + (red - green) / (double)delta;
        }
        var degrees = hue * 60 % 360;
        if (degrees < 0)
        {
            degrees += 360;
        }
        return Math.Min(23, (int)(degrees / 15));
    }

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

    private static int[] Averages(int[] sums, int[] counts)
    {
        var values = new int[sums.Length];
        for (var index = 0; index < sums.Length; index++)
        {
            values[index] = counts[index] == 0
                ? 0
                : sums[index] / counts[index];
        }
        return values;
    }

    private static string Sparkline(int[] values)
    {
        var maximum = Math.Max(1, values.Max());
        return new string(values.Select(value =>
            Bars[Math.Min(
                Bars.Length - 1,
                value * (Bars.Length - 1) / maximum)]).ToArray());
    }
}
