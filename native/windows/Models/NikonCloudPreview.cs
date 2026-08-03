using System.IO;
using System.Text.Json;

namespace NikonLink.Windows.Models;

internal sealed class NikonCloudCatalog
{
    public int SchemaVersion { get; init; }
    public int PresetCount { get; init; }
    public List<NikonCloudPreset> Presets { get; init; } = [];

    public static NikonCloudCatalog Load()
    {
        var path = Path.Combine(
            AppContext.BaseDirectory,
            "Assets",
            "nikon-cloud-presets.json");
        if (!File.Exists(path)) return new NikonCloudCatalog();
        try
        {
            return JsonSerializer.Deserialize<NikonCloudCatalog>(
                File.ReadAllText(path),
                new JsonSerializerOptions
                {
                    PropertyNameCaseInsensitive = true
                }) ?? new NikonCloudCatalog();
        }
        catch
        {
            return new NikonCloudCatalog();
        }
    }
}

internal sealed class NikonCloudPreset
{
    private static readonly double[] MixerAnchors =
        [0, 30, 60, 120, 180, 240, 280, 330];
    public string Id { get; init; } = "";
    public string Name { get; init; } = "";
    public string Filename { get; init; } = "";
    public bool HasCustomToneCurve { get; init; }
    public NikonCloudTone Tone { get; init; } = new();
    public NikonCloudGrading Grading { get; init; } = new();
    public List<NikonCloudColorMix> Mixer { get; init; } = [];
    public List<double> ToneCurve { get; init; } = [];

    public void ApplyColorMixer(ref double red, ref double green, ref double blue)
    {
        if (Mixer.Count != 8) return;
        red = Clamp(red);
        green = Clamp(green);
        blue = Clamp(blue);
        var maximum = Math.Max(red, Math.Max(green, blue));
        var minimum = Math.Min(red, Math.Min(green, blue));
        var delta = maximum - minimum;
        var lightness = (maximum + minimum) / 2;
        var saturation = 0.0;
        var hue = 0.0;
        if (delta >= .000001)
        {
            saturation = delta / Math.Max(
                .000001,
                1 - Math.Abs(2 * lightness - 1));
            if (maximum == red)
                hue = 60 * (((green - blue) / delta) % 6);
            else if (maximum == green)
                hue = 60 * ((blue - red) / delta + 2);
            else
                hue = 60 * ((red - green) / delta + 4);
            if (hue < 0) hue += 360;
        }
        var totalWeight = 0.0;
        var hueShift = 0.0;
        var chromaShift = 0.0;
        var brightnessShift = 0.0;
        for (var index = 0; index < MixerAnchors.Length; index++)
        {
            var direct = Math.Abs(hue - MixerAnchors[index]);
            var distance = Math.Min(direct, 360 - direct);
            var weight = Math.Max(0, 1 - distance / 60);
            totalWeight += weight;
            hueShift += Mixer[index].Hue * weight;
            chromaShift += Mixer[index].Chroma * weight;
            brightnessShift += Mixer[index].Brightness * weight;
        }
        if (totalWeight > 0)
        {
            hue = (hue + hueShift / totalWeight * .5) % 360;
            if (hue < 0) hue += 360;
            saturation = Clamp(
                saturation * (1 + chromaShift / totalWeight / 64));
            lightness = Clamp(
                lightness + brightnessShift / totalWeight / 255);
        }
        (red, green, blue) = HslToRgb(
            hue,
            saturation,
            lightness);
    }

    public void ApplyPreviewEffect(
        ref double red,
        ref double green,
        ref double blue)
    {
        red = Clamp(red);
        green = Clamp(green);
        blue = Clamp(blue);
        var luma = Clamp(red * .2126 + green * .7152 + blue * .0722);
        var contrast = 1 + Tone.Contrast / 120;
        red = (red - .5) * contrast + .5;
        green = (green - .5) * contrast + .5;
        blue = (blue - .5) * contrast + .5;

        var shadows = Math.Pow(1 - luma, 2);
        var midtones = 1 - Math.Abs(luma * 2 - 1);
        var highlights = Math.Pow(luma, 2);
        var tonalShift = Tone.Shadows / 400 * shadows
            + Tone.Highlights / 400 * highlights
            + Tone.Blacks / 500 * Math.Pow(1 - luma, 4)
            + Tone.Whites / 500 * Math.Pow(luma, 4);
        red += tonalShift;
        green += tonalShift;
        blue += tonalShift;

        luma = Clamp(red * .2126 + green * .7152 + blue * .0722);
        var saturation = Math.Max(0, 1 + Tone.Saturation / 100);
        red = luma + (red - luma) * saturation;
        green = luma + (green - luma) * saturation;
        blue = luma + (blue - luma) * saturation;

        var gradeX = Grading.Lift.X / 800 * shadows
            + Grading.Gamma.X / 800 * midtones
            + Grading.Gain.X / 800 * highlights;
        var gradeY = Grading.Lift.Y / 800 * shadows
            + Grading.Gamma.Y / 800 * midtones
            + Grading.Gain.Y / 800 * highlights;
        red += gradeX - gradeY * .5;
        green += gradeY - gradeX * .5;
        blue -= (gradeX + gradeY) * .5;

        if (ToneCurve.Count > 1)
        {
            red = CurveValue(Clamp(red));
            green = CurveValue(Clamp(green));
            blue = CurveValue(Clamp(blue));
        }
        ApplyColorMixer(ref red, ref green, ref blue);
    }

    private double CurveValue(double input)
    {
        var scaled = input * (ToneCurve.Count - 1);
        var lower = Math.Min(
            ToneCurve.Count - 1,
            Math.Max(0, (int)Math.Floor(scaled)));
        var upper = Math.Min(ToneCurve.Count - 1, lower + 1);
        var amount = scaled - lower;
        return Clamp(
            ToneCurve[lower] + (ToneCurve[upper] - ToneCurve[lower]) * amount);
    }

    private static (double Red, double Green, double Blue) HslToRgb(
        double hue,
        double saturation,
        double lightness)
    {
        var chroma = (1 - Math.Abs(2 * lightness - 1)) * saturation;
        var sector = hue / 60;
        var secondary = chroma * (1 - Math.Abs(sector % 2 - 1));
        (double Red, double Green, double Blue) components = sector switch
        {
            < 1 => (chroma, secondary, 0),
            < 2 => (secondary, chroma, 0),
            < 3 => (0, chroma, secondary),
            < 4 => (0, secondary, chroma),
            < 5 => (secondary, 0, chroma),
            _ => (chroma, 0, secondary)
        };
        var match = lightness - chroma / 2;
        return (
            Clamp(components.Red + match),
            Clamp(components.Green + match),
            Clamp(components.Blue + match));
    }

    private static double Clamp(double value) => Math.Clamp(value, 0, 1);

}

internal sealed class NikonCloudTone
{
    public double Contrast { get; init; }
    public double Highlights { get; init; }
    public double Shadows { get; init; }
    public double Whites { get; init; }
    public double Blacks { get; init; }
    public double Saturation { get; init; }
    public double Texture { get; init; }
    public double Clarity { get; init; }
    public double Sharpening { get; init; }
}

internal sealed class NikonCloudGrading
{
    public NikonCloudGradePoint Lift { get; init; } = new();
    public NikonCloudGradePoint Gamma { get; init; } = new();
    public NikonCloudGradePoint Gain { get; init; } = new();
}

internal sealed class NikonCloudGradePoint
{
    public double X { get; init; }
    public double Y { get; init; }
}

internal sealed class NikonCloudColorMix
{
    public int Hue { get; init; }
    public int Chroma { get; init; }
    public int Brightness { get; init; }
}
