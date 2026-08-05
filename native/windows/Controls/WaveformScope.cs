using System.Globalization;
using System.Windows;
using System.Windows.Media;

namespace NikonLink.Windows;

public enum WaveformScopeMode
{
    RgbParade,
    Audio
}

public sealed class WaveformScope : FrameworkElement
{
    private static readonly Typeface LabelTypeface = new(
        new FontFamily("Consolas"),
        FontStyles.Normal,
        FontWeights.SemiBold,
        FontStretches.Normal);

    private string _red = "—";
    private string _green = "—";
    private string _blue = "—";
    private string _luma = "—";
    private string _chroma = "—";

    public WaveformScopeMode Mode { get; set; } = WaveformScopeMode.RgbParade;

    public void SetData(
        string red,
        string green,
        string blue,
        string luma,
        string chroma)
    {
        _red = red;
        _green = green;
        _blue = blue;
        _luma = luma;
        _chroma = chroma;
        InvalidateVisual();
    }

    protected override void OnRender(DrawingContext drawingContext)
    {
        base.OnRender(drawingContext);
        if (ActualWidth <= 2 || ActualHeight <= 2)
        {
            return;
        }

        var bounds = new Rect(0.5, 0.5, ActualWidth - 1, ActualHeight - 1);
        if (Mode == WaveformScopeMode.Audio)
        {
            DrawAudio(drawingContext, bounds);
            return;
        }

        DrawPanel(
            drawingContext,
            bounds,
            "RGB",
            [_red, _green, _blue],
            [Color.FromRgb(255, 48, 42), Color.FromRgb(40, 255, 105), Color.FromRgb(34, 64, 255)],
            parade: false);
    }

    private void DrawPanel(
        DrawingContext drawingContext,
        Rect bounds,
        string label,
        IReadOnlyList<string> values,
        IReadOnlyList<Color> colors,
        bool parade)
    {
        var footerHeight = Math.Min(14, Math.Max(10, bounds.Height * 0.17));
        var plotBounds = new Rect(
            bounds.X,
            bounds.Y,
            bounds.Width,
            Math.Max(1, bounds.Height - footerHeight));
        drawingContext.DrawRectangle(
            Brushes.Black,
            null,
            bounds);
        drawingContext.DrawRectangle(
            new SolidColorBrush(Color.FromRgb(5, 10, 15)),
            null,
            plotBounds);

        for (var index = 0; index < values.Count; index++)
        {
            DrawTrace(
                drawingContext,
                plotBounds,
                values[index],
                colors[index],
                parade ? index : -1,
                index + 1);
        }

        var guidePen = new Pen(new SolidColorBrush(Color.FromArgb(144, 255, 255, 255)), 0.72);
        for (var guide = 1; guide < 4; guide++)
        {
            var y = plotBounds.Top + plotBounds.Height * guide / 4;
            drawingContext.DrawLine(guidePen, new Point(plotBounds.Left, y), new Point(plotBounds.Right, y));
        }
        if (parade)
        {
            for (var guide = 1; guide < 3; guide++)
            {
                var x = plotBounds.Left + plotBounds.Width * guide / 3;
                drawingContext.DrawLine(guidePen, new Point(x, plotBounds.Top), new Point(x, plotBounds.Bottom));
            }
        }
        drawingContext.DrawRectangle(
            null,
            new Pen(new SolidColorBrush(Color.FromArgb(240, 255, 255, 255)), 1.1),
            plotBounds);

        var labelY = plotBounds.Bottom;
        if (parade)
        {
            DrawCenteredLabel(drawingContext, "R", bounds.Left + bounds.Width / 6, labelY, footerHeight);
            DrawCenteredLabel(drawingContext, "G", bounds.Left + bounds.Width / 2, labelY, footerHeight);
            DrawCenteredLabel(drawingContext, "B", bounds.Left + bounds.Width * 5 / 6, labelY, footerHeight);
        }
        else
        {
            DrawCenteredLabel(drawingContext, label, bounds.Left + bounds.Width / 2, labelY, footerHeight);
        }
    }

    private void DrawAudio(DrawingContext drawingContext, Rect bounds)
    {
        DrawPanel(drawingContext, bounds, "AUDIO", [], [], parade: false);
        var footerHeight = Math.Min(14, Math.Max(10, bounds.Height * 0.17));
        var plotHeight = bounds.Height - footerHeight;
        var cyan = Color.FromRgb(76, 199, 232);
        var start = new Point(bounds.Left + 4, bounds.Top + plotHeight / 2);
        var end = new Point(bounds.Right - 4, bounds.Top + plotHeight / 2);
        drawingContext.DrawLine(
            new Pen(new SolidColorBrush(Color.FromArgb(55, cyan.R, cyan.G, cyan.B)), 5),
            start,
            end);
        drawingContext.DrawLine(new Pen(new SolidColorBrush(cyan), 1), start, end);

    }

    private static void DrawTrace(
        DrawingContext drawingContext,
        Rect bounds,
        string value,
        Color color,
        int segment,
        int seed)
    {
        var inset = Math.Max(2, bounds.Width * 0.009);
        var segmentWidth = segment >= 0 ? bounds.Width / 3 : bounds.Width;
        var startX = segment >= 0
            ? bounds.Left + segmentWidth * segment + inset
            : bounds.Left + inset;
        var plotWidth = Math.Max(1, segmentWidth - inset * 2);
        var topInset = Math.Max(3, bounds.Height * 0.035);
        var bottom = bounds.Bottom - Math.Max(3, bounds.Height * 0.035);
        var plotHeight = Math.Max(1, bottom - bounds.Top - topInset);
        var density = ParseDensity(value);
        if (density is not null)
        {
            DrawDensity(
                drawingContext,
                density,
                color,
                startX,
                bounds.Top + topInset,
                plotWidth,
                plotHeight);
            return;
        }
        var levels = ParseLevels(value);
        var columns = Math.Min(220, Math.Max(56, (int)(plotWidth / 1.35)));

        var envelope = new StreamGeometry();
        var haze = new StreamGeometry();
        var cloud = new StreamGeometry();
        var sparks = new StreamGeometry();
        using (var envelopeContext = envelope.Open())
        using (var hazeContext = haze.Open())
        using (var cloudContext = cloud.Open())
        using (var sparksContext = sparks.Open())
        {
            for (var column = 0; column < columns; column++)
            {
                var progress = column / (double)Math.Max(1, columns - 1);
                var sample = progress * (levels.Count - 1);
                var lower = Math.Min(levels.Count - 1, (int)Math.Floor(sample));
                var upper = Math.Min(levels.Count - 1, lower + 1);
                var blend = sample - lower;
                var interpolated = levels[lower] + (levels[upper] - levels[lower]) * blend;
                var ripple = (ScopeNoise(column, 0, seed) - 0.5) * 0.075;
                var level = Math.Min(1, Math.Max(0.04, interpolated + ripple));
                var x = startX + plotWidth * progress;
                var envelopeY = bounds.Top + topInset
                    + plotHeight * (1 - (0.12 + level * 0.82));
                var envelopePoint = new Point(x, envelopeY);
                if (column == 0)
                {
                    envelopeContext.BeginFigure(envelopePoint, isFilled: false, isClosed: false);
                }
                else
                {
                    envelopeContext.LineTo(envelopePoint, isStroked: true, isSmoothJoin: true);
                }

                var particles = 18 + (int)Math.Round(level * 28);
                for (var particle = 0; particle < particles; particle++)
                {
                    var distribution = ScopeNoise(column, particle + 1, seed * 7);
                    var depth = Math.Pow(distribution, particle % 3 == 0 ? 2.25 : 0.72);
                    var jitterX = (ScopeNoise(column, particle + 11, seed * 13) - 0.5) * 2.2;
                    var jitterY = (ScopeNoise(column, particle + 29, seed * 17) - 0.5) * 2.4;
                    var y = Math.Min(
                        bottom,
                        Math.Max(bounds.Top + topInset, envelopeY + (bottom - envelopeY) * depth + jitterY));
                    var point = new Point(x + jitterX, y);
                    AddParticle(hazeContext, point);
                    if ((column + particle + seed) % 5 == 0)
                    {
                        AddParticle(sparksContext, point);
                    }
                    else
                    {
                        AddParticle(cloudContext, point);
                    }
                }
            }
        }
        envelope.Freeze();
        haze.Freeze();
        cloud.Freeze();
        sparks.Freeze();

        DrawTracePass(drawingContext, haze, color, 18, 1.7);
        DrawTracePass(drawingContext, cloud, color, 76, 0.75);
        DrawTracePass(drawingContext, sparks, color, 164, 1.15);
        DrawTracePass(drawingContext, envelope, color, 36, 3.2);
        DrawTracePass(drawingContext, envelope, color, 160, 0.72);
    }

    private static void DrawDensity(
        DrawingContext drawingContext,
        ScopeDensity density,
        Color color,
        double startX,
        double top,
        double width,
        double height)
    {
        var cellWidth = width / density.Columns;
        var cellHeight = height / density.Rows;
        var haze = new StreamGeometry();
        var cloud = new StreamGeometry();
        var sparks = new StreamGeometry();
        var envelope = new StreamGeometry();
        using (var hazeContext = haze.Open())
        using (var cloudContext = cloud.Open())
        using (var sparksContext = sparks.Open())
        using (var envelopeContext = envelope.Open())
        {
            var hasEnvelope = false;
            for (var column = 0; column < density.Columns; column++)
            {
                var firstRow = -1;
                for (var row = 0; row < density.Rows; row++)
                {
                    var level = density.Values[row * density.Columns + column];
                    if (level <= 0)
                    {
                        continue;
                    }
                    if (firstRow < 0)
                    {
                        firstRow = row;
                    }
                    var point = new Point(
                        startX + (column + 0.5) * cellWidth,
                        top + (row + 0.5) * cellHeight);
                    AddParticle(hazeContext, point);
                    if (level >= 9)
                    {
                        AddParticle(sparksContext, point);
                    }
                    else if (level >= 3)
                    {
                        AddParticle(cloudContext, point);
                    }
                }
                if (firstRow < 0)
                {
                    continue;
                }
                var envelopePoint = new Point(
                    startX + (column + 0.5) * cellWidth,
                    top + (firstRow + 0.5) * cellHeight);
                if (!hasEnvelope)
                {
                    envelopeContext.BeginFigure(envelopePoint, isFilled: false, isClosed: false);
                    hasEnvelope = true;
                }
                else
                {
                    envelopeContext.LineTo(envelopePoint, isStroked: true, isSmoothJoin: true);
                }
            }
        }
        haze.Freeze();
        cloud.Freeze();
        sparks.Freeze();
        envelope.Freeze();
        DrawTracePass(drawingContext, haze, color, 26, 1.7);
        DrawTracePass(drawingContext, cloud, color, 90, 0.9);
        DrawTracePass(drawingContext, sparks, color, 200, 1.25);
        DrawTracePass(drawingContext, envelope, color, 56, 2.8);
        DrawTracePass(drawingContext, envelope, color, 184, 0.68);
    }

    private static void AddParticle(StreamGeometryContext context, Point point)
    {
        context.BeginFigure(point, isFilled: false, isClosed: false);
        context.LineTo(new Point(point.X + 0.01, point.Y), isStroked: true, isSmoothJoin: false);
    }

    private static double ScopeNoise(int column, int particle, int seed)
    {
        var value = Math.Sin(
            ((column + 1) * 17 + (particle + 3) * 31 + seed * 47) * 12.9898)
            * 43758.5453;
        return value - Math.Floor(value);
    }

    private static void DrawTracePass(
        DrawingContext drawingContext,
        Geometry geometry,
        Color color,
        byte alpha,
        double width)
    {
        var pen = new Pen(new SolidColorBrush(Color.FromArgb(alpha, color.R, color.G, color.B)), width)
        {
            LineJoin = PenLineJoin.Round,
            StartLineCap = PenLineCap.Round,
            EndLineCap = PenLineCap.Round
        };
        drawingContext.DrawGeometry(null, pen, geometry);
    }

    private static IReadOnlyList<double> ParseLevels(string value)
    {
        const string bars = "▁▂▃▄▅▆▇█";
        var output = new List<double>();
        foreach (var character in value)
        {
            var level = bars.IndexOf(character);
            if (level >= 0)
            {
                output.Add(level / 7d);
            }
        }
        return output.Count > 1 ? output : [0.08, 0.08];
    }

    private static ScopeDensity? ParseDensity(string value)
    {
        var colon = value.IndexOf(':');
        if (!value.StartsWith('S') || colon < 2)
        {
            return null;
        }
        var dimensions = value[1..colon].Split('x', 2);
        if (dimensions.Length != 2 ||
            !int.TryParse(dimensions[0], out var columns) ||
            !int.TryParse(dimensions[1], out var rows))
        {
            return null;
        }
        var payload = value[(colon + 1)..];
        if (payload.Length != columns * rows)
        {
            return null;
        }
        var values = new int[payload.Length];
        for (var index = 0; index < payload.Length; index++)
        {
            if (!int.TryParse(payload[index].ToString(), NumberStyles.HexNumber,
                CultureInfo.InvariantCulture, out values[index]))
            {
                return null;
            }
        }
        return new ScopeDensity(columns, rows, values);
    }

    private sealed record ScopeDensity(int Columns, int Rows, int[] Values);

    private static void DrawCenteredLabel(
        DrawingContext drawingContext,
        string label,
        double centerX,
        double top,
        double height)
    {
        var text = Formatted(label, Math.Min(9, height * 0.68), Color.FromArgb(224, 255, 255, 255));
        drawingContext.DrawText(
            text,
            new Point(centerX - text.Width / 2, top + Math.Max(0, (height - text.Height) / 2)));
    }

    private static FormattedText Formatted(string text, double size, Color color)
    {
        return new FormattedText(
            text,
            CultureInfo.CurrentUICulture,
            FlowDirection.LeftToRight,
            LabelTypeface,
            size,
            new SolidColorBrush(color),
            1);
    }
}
