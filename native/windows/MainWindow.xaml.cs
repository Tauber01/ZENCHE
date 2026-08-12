using NikonLink.Windows.Models;
using NikonLink.Windows.Services;
using Microsoft.Win32;
using Microsoft.Win32.SafeHandles;
using System.Buffers.Binary;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Net.Http;
using System.Runtime.InteropServices;
using System.Text.Json;
using System.Windows;
using System.Windows.Automation;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Input;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Media.Imaging;
#if NIKONLINK_WINDOWS_SHARE
using Windows.ApplicationModel.DataTransfer;
using Windows.Storage;
#endif

namespace NikonLink.Windows;

public partial class MainWindow : Window
{
    [StructLayout(LayoutKind.Sequential)]
    private struct ByHandleFileInformation
    {
        public uint FileAttributes;
        public System.Runtime.InteropServices.ComTypes.FILETIME CreationTime;
        public System.Runtime.InteropServices.ComTypes.FILETIME LastAccessTime;
        public System.Runtime.InteropServices.ComTypes.FILETIME LastWriteTime;
        public uint VolumeSerialNumber;
        public uint FileSizeHigh;
        public uint FileSizeLow;
        public uint NumberOfLinks;
        public uint FileIndexHigh;
        public uint FileIndexLow;
    }

    private readonly record struct WindowsFileIdentity(
        uint VolumeSerialNumber,
        uint FileIndexHigh,
        uint FileIndexLow);

    [DllImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool GetFileInformationByHandle(
        SafeFileHandle file,
        out ByHandleFileInformation information);

    private sealed record PreparedPreview(
        BitmapSource Source,
        BitmapSource Display,
        ProfessionalMonitorResult Monitor);

    private sealed class RememberedCameraDevice
    {
        public string Id { get; set; } = "";
        public string Name { get; set; } = "";
        public string Vendor { get; set; } = "Camera";
        public string Transport { get; set; } = "USB/PTP";
        public DateTime LastConnectedAt { get; set; } = DateTime.Now;
    }

    private sealed class WorkspaceLayoutState
    {
        public int SchemaVersion { get; set; } = 1;
        public double Left { get; set; } = double.NaN;
        public double Top { get; set; } = double.NaN;
        public double Width { get; set; } = 1440;
        public double Height { get; set; } = 900;
        public bool Maximized { get; set; }
        public double SidebarWidth { get; set; } = 176;
        public double ParameterWidth { get; set; } = 380;
        public double EditorMediaWidth { get; set; } = 240;
        public double EditorToolsWidth { get; set; } = 380;
        public double EditorBottomHeight { get; set; } = 360;
        public double EditorAiToolsWidth { get; set; } = 440;
    }

    private sealed class LibraryBranch
    {
        public string Id { get; set; } = Guid.NewGuid().ToString("N");
        public string Name { get; set; } = "未命名分支";
        public List<LibraryBranch> Children { get; set; } = [];
    }

    private sealed class LibraryTreeNode
    {
        public required string Name { get; init; }
        public string Detail { get; init; } = "";
        public string Icon { get; init; } = "▱";
        public BitmapSource? Thumbnail { get; init; }
        public string? BranchId { get; init; }
        public PhotoItem? Item { get; init; }
        public bool IsUnclassified { get; init; }
        public bool IsExpanded { get; set; }
        public ObservableCollection<LibraryTreeNode> Children { get; } = [];
    }

    private sealed class CameraStorageListItem : INotifyPropertyChanged
    {
        private BitmapSource? _thumbnail;

        public required CameraStorageItem Item { get; init; }
        public string Name => Item.Filename;
        public string Icon => Item.IsVideo ? "▶" : "▣";
        public string Detail =>
            $"{FormatStorageBytes(Item.SizeBytes)}" +
            (Item.Width > 0 && Item.Height > 0
                ? $" · {Item.Width} × {Item.Height}"
                : "") +
            $" · {Item.CapturedAt}" +
            (Item.IsProtected ? " · 已保护" : "");

        public BitmapSource? Thumbnail
        {
            get => _thumbnail;
            set
            {
                if (ReferenceEquals(_thumbnail, value)) return;
                _thumbnail = value;
                PropertyChanged?.Invoke(
                    this,
                    new PropertyChangedEventArgs(nameof(Thumbnail)));
            }
        }

        public event PropertyChangedEventHandler? PropertyChanged;
    }

    private sealed class EditorPhotoChoice
    {
        public required PhotoItem Item { get; init; }

        public override string ToString() => Item.Name;
    }

    private sealed class EditorCurvePoint
    {
        public double X { get; set; }
        public double Y { get; set; }
        public EditorCurvePoint(double x, double y) { X = x; Y = y; }
        public EditorCurvePoint Copy() => new(X, Y);
    }

    private sealed class EditorMaskPoint
    {
        public double X { get; set; }
        public double Y { get; set; }
        public EditorMaskPoint(double x, double y) { X = x; Y = y; }
        public EditorMaskPoint Copy() => new(X, Y);
    }

    private sealed class EditorMaskStroke
    {
        public bool Subtract { get; set; }
        public double Size { get; set; } = 18;
        public List<EditorMaskPoint> Points { get; set; } = [];
        public EditorMaskStroke Copy() => new()
        {
            Subtract = Subtract,
            Size = Size,
            Points = Points.Select(point => point.Copy()).ToList()
        };
    }

    private sealed class EditorMaskLayer
    {
        public Guid Id { get; init; } = Guid.NewGuid();
        public string Name { get; set; } = "";
        public bool IsVisible { get; set; } = true;
        public string Type { get; set; } = "画笔";
        public double Amount { get; set; } = 100;
        public double Feather { get; set; } = 50;
        public bool Invert { get; set; }
        public bool Subtract { get; set; }
        public double BrushSize { get; set; } = 18;
        public List<EditorMaskStroke> Strokes { get; set; } = [];
        public double Exposure { get; set; }
        public double Contrast { get; set; }
        public double Highlights { get; set; }
        public double Shadows { get; set; }
        public double Temperature { get; set; }
        public double Tint { get; set; }
        public double Saturation { get; set; }
        public double Clarity { get; set; }

        public EditorMaskLayer Copy() => new()
        {
            Id = Id,
            Name = Name,
            IsVisible = IsVisible,
            Type = Type,
            Amount = Amount,
            Feather = Feather,
            Invert = Invert,
            Subtract = Subtract,
            BrushSize = BrushSize,
            Strokes = Strokes.Select(stroke => stroke.Copy()).ToList(),
            Exposure = Exposure,
            Contrast = Contrast,
            Highlights = Highlights,
            Shadows = Shadows,
            Temperature = Temperature,
            Tint = Tint,
            Saturation = Saturation,
            Clarity = Clarity
        };
    }

    private sealed class EditorAdjustments
    {
        public double Exposure { get; set; }
        public double Contrast { get; set; }
        public double Highlights { get; set; }
        public double Shadows { get; set; }
        public double Whites { get; set; }
        public double Blacks { get; set; }
        public double Temperature { get; set; }
        public double Tint { get; set; }
        public double Vibrance { get; set; }
        public double Saturation { get; set; }
        public double Texture { get; set; }
        public double Clarity { get; set; }
        public double Sharpening { get; set; }
        public double NoiseReduction { get; set; }
        public double Dehaze { get; set; }
        public double Vignette { get; set; }
        // DaVinci-style grading controls. Values are intentionally normalized
        // to the existing -100...100 editor range so presets and reset remain
        // backwards compatible.
        public double Lift { get; set; }
        public double Gamma { get; set; }
        public double Gain { get; set; }
        public double LiftX { get; set; }
        public double LiftY { get; set; }
        public double GammaX { get; set; }
        public double GammaY { get; set; }
        public double GainX { get; set; }
        public double GainY { get; set; }
        public double CurveShadows { get; set; }
        public double CurveMidtones { get; set; }
        public double CurveHighlights { get; set; }
        public List<EditorCurvePoint> CurvePoints { get; set; } = DefaultCurvePoints();

        private static List<EditorCurvePoint> DefaultCurvePoints() =>
            [new(0, 0), new(.25, .25), new(.5, .5), new(.75, .75), new(1, 1)];
        public string MaskType { get; set; } = "无";
        public double MaskAmount { get; set; }
        public double MaskFeather { get; set; } = 50;
        public bool MaskInvert { get; set; }
        public bool MaskSubtract { get; set; }
        public double MaskBrushSize { get; set; } = 18;
        public List<EditorMaskStroke> MaskStrokes { get; set; } = [];
        public double MaskExposure { get; set; }
        public double MaskContrast { get; set; }
        public double MaskHighlights { get; set; }
        public double MaskShadows { get; set; }
        public double MaskTemperature { get; set; }
        public double MaskTint { get; set; }
        public double MaskSaturation { get; set; }
        public double MaskClarity { get; set; }
        public List<EditorMaskLayer> MaskLayers { get; set; } = [];
        public Guid? ActiveMaskLayerId { get; set; }
        public int NextMaskNumber { get; set; } = 1;
        public bool PickerEnabled { get; set; }
        public string PickedColorHex { get; set; } = "未取样";
        public int Rotation { get; set; }
        public bool FlipHorizontal { get; set; }
        public bool FlipVertical { get; set; }
        public bool ShowingOriginal { get; set; }
        public string CropRatio { get; set; } = "original";

        public void Reset()
        {
            Exposure = 0;
            Contrast = 0;
            Highlights = 0;
            Shadows = 0;
            Whites = 0;
            Blacks = 0;
            Temperature = 0;
            Tint = 0;
            Vibrance = 0;
            Saturation = 0;
            Texture = 0;
            Clarity = 0;
            Sharpening = 0;
            NoiseReduction = 0;
            Dehaze = 0;
            Vignette = 0;
            Lift = 0;
            Gamma = 0;
            Gain = 0;
            LiftX = 0;
            LiftY = 0;
            GammaX = 0;
            GammaY = 0;
            GainX = 0;
            GainY = 0;
            CurveShadows = 0;
            CurveMidtones = 0;
            CurveHighlights = 0;
            CurvePoints = DefaultCurvePoints();
            MaskType = "无";
            MaskAmount = 0;
            MaskFeather = 50;
            MaskInvert = false;
            MaskSubtract = false;
            MaskBrushSize = 18;
            MaskStrokes = [];
            MaskExposure = 0;
            MaskContrast = 0;
            MaskHighlights = 0;
            MaskShadows = 0;
            MaskTemperature = 0;
            MaskTint = 0;
            MaskSaturation = 0;
            MaskClarity = 0;
            MaskLayers = [];
            ActiveMaskLayerId = null;
            NextMaskNumber = 1;
            PickerEnabled = false;
            PickedColorHex = "未取样";
            Rotation = 0;
            FlipHorizontal = false;
            FlipVertical = false;
            ShowingOriginal = false;
            CropRatio = "original";
        }

        public void ResetTone()
        {
            var geometry = (
                Rotation,
                FlipHorizontal,
                FlipVertical,
                CropRatio);
            Reset();
            Rotation = geometry.Rotation;
            FlipHorizontal = geometry.FlipHorizontal;
            FlipVertical = geometry.FlipVertical;
            CropRatio = geometry.CropRatio;
        }

        public EditorAdjustments Copy() => new()
        {
            Exposure = Exposure,
            Contrast = Contrast,
            Highlights = Highlights,
            Shadows = Shadows,
            Whites = Whites,
            Blacks = Blacks,
            Temperature = Temperature,
            Tint = Tint,
            Vibrance = Vibrance,
            Saturation = Saturation,
            Texture = Texture,
            Clarity = Clarity,
            Sharpening = Sharpening,
            NoiseReduction = NoiseReduction,
            Dehaze = Dehaze,
            Vignette = Vignette,
            Lift = Lift,
            Gamma = Gamma,
            Gain = Gain,
            LiftX = LiftX,
            LiftY = LiftY,
            GammaX = GammaX,
            GammaY = GammaY,
            GainX = GainX,
            GainY = GainY,
            CurveShadows = CurveShadows,
            CurveMidtones = CurveMidtones,
            CurveHighlights = CurveHighlights,
            CurvePoints = CurvePoints.Select(point => point.Copy()).ToList(),
            MaskType = MaskType,
            MaskAmount = MaskAmount,
            MaskFeather = MaskFeather,
            MaskInvert = MaskInvert,
            MaskSubtract = MaskSubtract,
            MaskBrushSize = MaskBrushSize,
            MaskStrokes = MaskStrokes.Select(stroke => stroke.Copy()).ToList(),
            MaskExposure = MaskExposure,
            MaskContrast = MaskContrast,
            MaskHighlights = MaskHighlights,
            MaskShadows = MaskShadows,
            MaskTemperature = MaskTemperature,
            MaskTint = MaskTint,
            MaskSaturation = MaskSaturation,
            MaskClarity = MaskClarity,
            MaskLayers = MaskLayers.Select(layer => layer.Copy()).ToList(),
            ActiveMaskLayerId = ActiveMaskLayerId,
            NextMaskNumber = NextMaskNumber,
            PickerEnabled = PickerEnabled,
            PickedColorHex = PickedColorHex,
            Rotation = Rotation,
            FlipHorizontal = FlipHorizontal,
            FlipVertical = FlipVertical,
            ShowingOriginal = ShowingOriginal,
            CropRatio = CropRatio
        };

        public EditorMaskLayer? ActiveMaskLayer() => ActiveMaskLayerId is { } id
            ? MaskLayers.FirstOrDefault(layer => layer.Id == id)
            : null;

        public bool ActiveMaskLayerIsVisible() =>
            ActiveMaskLayer()?.IsVisible == true;

        public void CreateMaskLayer()
        {
            PersistActiveMaskLayer();
            var layer = new EditorMaskLayer
            {
                Name = $"{AppLocalization.T("蒙版")} {NextMaskNumber++}"
            };
            MaskLayers.Add(layer);
            LoadMaskLayer(layer);
        }

        public void EnsureMaskLayer()
        {
            if (ActiveMaskLayer() is null || MaskType == "无")
                CreateMaskLayer();
        }

        public void SelectMaskLayer(Guid id)
        {
            if (ActiveMaskLayerId == id) return;
            PersistActiveMaskLayer();
            var layer = MaskLayers.FirstOrDefault(candidate => candidate.Id == id);
            if (layer is not null) LoadMaskLayer(layer);
        }

        public void DeleteActiveMaskLayer()
        {
            var active = ActiveMaskLayer();
            if (active is null) return;
            var index = MaskLayers.IndexOf(active);
            PersistActiveMaskLayer();
            MaskLayers.RemoveAt(index);
            if (MaskLayers.Count == 0)
            {
                ActiveMaskLayerId = null;
                MaskType = "无";
                MaskStrokes = [];
            }
            else
            {
                LoadMaskLayer(MaskLayers[Math.Min(index, MaskLayers.Count - 1)]);
            }
        }

        public void SetMaskLayerVisible(Guid id, bool visible)
        {
            PersistActiveMaskLayer();
            var layer = MaskLayers.FirstOrDefault(candidate => candidate.Id == id);
            if (layer is not null) layer.IsVisible = visible;
        }

        public EditorMaskLayer DisplayedMaskLayer(EditorMaskLayer layer) =>
            layer.Id == ActiveMaskLayerId ? SnapshotMaskLayer(layer) : layer.Copy();

        public List<EditorMaskLayer> EffectiveMaskLayers() =>
            MaskLayers.Select(DisplayedMaskLayer).ToList();

        private void PersistActiveMaskLayer()
        {
            var active = ActiveMaskLayer();
            if (active is null) return;
            MaskLayers[MaskLayers.IndexOf(active)] = SnapshotMaskLayer(active);
        }

        private EditorMaskLayer SnapshotMaskLayer(EditorMaskLayer identity) => new()
        {
            Id = identity.Id,
            Name = identity.Name,
            IsVisible = identity.IsVisible,
            Type = MaskType,
            Amount = MaskAmount,
            Feather = MaskFeather,
            Invert = MaskInvert,
            Subtract = MaskSubtract,
            BrushSize = MaskBrushSize,
            Strokes = MaskStrokes.Select(stroke => stroke.Copy()).ToList(),
            Exposure = MaskExposure,
            Contrast = MaskContrast,
            Highlights = MaskHighlights,
            Shadows = MaskShadows,
            Temperature = MaskTemperature,
            Tint = MaskTint,
            Saturation = MaskSaturation,
            Clarity = MaskClarity
        };

        private void LoadMaskLayer(EditorMaskLayer layer)
        {
            ActiveMaskLayerId = layer.Id;
            MaskType = layer.Type;
            MaskAmount = layer.Amount;
            MaskFeather = layer.Feather;
            MaskInvert = layer.Invert;
            MaskSubtract = layer.Subtract;
            MaskBrushSize = layer.BrushSize;
            MaskStrokes = layer.Strokes.Select(stroke => stroke.Copy()).ToList();
            MaskExposure = layer.Exposure;
            MaskContrast = layer.Contrast;
            MaskHighlights = layer.Highlights;
            MaskShadows = layer.Shadows;
            MaskTemperature = layer.Temperature;
            MaskTint = layer.Tint;
            MaskSaturation = layer.Saturation;
            MaskClarity = layer.Clarity;
        }
    }

    private sealed class EditorWheelControl : FrameworkElement
    {
        private readonly Pen _ringPen = new(Brushes.White, 1);
        private bool _dragging;
        public Brush Accent { get; set; } = Brushes.DeepSkyBlue;
        public double XValue { get; set; }
        public double YValue { get; set; }
        public event Action<double, double>? ValueChanged;

        protected override void OnRender(DrawingContext dc)
        {
            base.OnRender(dc);
            var center = new Point(ActualWidth / 2, ActualHeight / 2);
            var radius = Math.Max(8, Math.Min(ActualWidth, ActualHeight) * 0.38);
            var colors = new[] { Colors.Red, Colors.Yellow, Colors.LimeGreen, Colors.Cyan, Colors.Blue, Colors.Magenta };
            for (var i = 0; i < colors.Length; i++) DrawWheelSegment(dc, center, radius, i * 60 - 90, (i + 1) * 60 - 90, new SolidColorBrush(colors[i]));
            dc.DrawEllipse((Brush)FindResource("ScopeWellBrush"), _ringPen, center, radius - 6, radius - 6);
            var knobX = center.X + Math.Clamp(XValue / 100, -1, 1) * radius * .72;
            var knobY = center.Y - Math.Clamp(YValue / 100, -1, 1) * radius * .72;
            dc.DrawEllipse(Accent, null, new Point(knobX, knobY), 6, 6);
            dc.DrawEllipse(null, new Pen(Accent, 1), center, radius - 1, radius - 1);
        }

        private static void DrawWheelSegment(DrawingContext dc, Point center, double radius, double start, double end, Brush brush)
        {
            static Point Polar(Point c, double r, double degrees)
            {
                var radians = degrees * Math.PI / 180;
                return new Point(c.X + Math.Cos(radians) * r, c.Y + Math.Sin(radians) * r);
            }
            var geometry = new StreamGeometry();
            using (var ctx = geometry.Open())
            {
                ctx.BeginFigure(center, true, true);
                ctx.LineTo(Polar(center, radius, start), true, false);
                ctx.ArcTo(Polar(center, radius, end), new Size(radius, radius), 60, false, SweepDirection.Clockwise, true, false);
            }
            geometry.Freeze();
            dc.DrawGeometry(brush, null, geometry);
        }

        protected override void OnMouseLeftButtonDown(MouseButtonEventArgs e)
        {
            _dragging = true;
            CaptureMouse();
            UpdateValue(e.GetPosition(this));
            e.Handled = true;
        }

        protected override void OnMouseMove(MouseEventArgs e)
        {
            if (_dragging) UpdateValue(e.GetPosition(this));
        }

        protected override void OnMouseLeftButtonUp(MouseButtonEventArgs e)
        {
            _dragging = false;
            ReleaseMouseCapture();
            e.Handled = true;
        }

        private void UpdateValue(Point point)
        {
            var center = new Point(ActualWidth / 2, ActualHeight / 2);
            var radius = Math.Max(8, Math.Min(ActualWidth, ActualHeight) * 0.38);
            var dx = Math.Clamp((point.X - center.X) / (radius * .72), -1, 1);
            var dy = Math.Clamp((center.Y - point.Y) / (radius * .72), -1, 1);
            XValue = Math.Clamp(dx * 100, -100, 100);
            YValue = Math.Clamp(dy * 100, -100, 100);
            InvalidateVisual();
            ValueChanged?.Invoke(XValue, YValue);
        }
    }

    private sealed class EditorCurveControl : FrameworkElement
    {
        private readonly EditorAdjustments _settings;
        private bool _dragging;
        private int _activePoint = -1;
        public event Action<string, double>? ValueChanged;

        public EditorCurveControl(EditorAdjustments settings) => _settings = settings;

        protected override void OnRender(DrawingContext dc)
        {
            base.OnRender(dc);
            var w = Math.Max(1, ActualWidth);
            var h = Math.Max(1, ActualHeight);
            dc.DrawRoundedRectangle((Brush)FindResource("ScopeWellBrush"), new Pen((Brush)FindResource("ScopeWellBorderBrush"), 1), new Rect(0, 0, w, h), 8, 8);
            var guide = new Pen((Brush)FindResource("GuideWhiteBrush"), 1) { DashStyle = new DashStyle(new[] { 4d, 4d }, 0) };
            dc.DrawLine(guide, new Point(0, h), new Point(w, 0));
            var accent = (Brush)Application.Current.FindResource("AccentBrush");
            var curvePen = new Pen(accent, 2);
            var geometry = new StreamGeometry();
            using (var ctx = geometry.Open())
            {
                var points = _settings.CurvePoints.OrderBy(point => point.X).ToList();
                if (points.Count == 0) points = [new EditorCurvePoint(0, 0), new EditorCurvePoint(1, 1)];
                ctx.BeginFigure(new Point(points[0].X * w, (1 - points[0].Y) * h), false, false);
                for (var index = 0; index < points.Count - 1; index++)
                {
                    var p0 = points[Math.Max(0, index - 1)];
                    var p1 = points[index];
                    var p2 = points[index + 1];
                    var p3 = points[Math.Min(points.Count - 1, index + 2)];
                    var c1 = new Point((p1.X + (p2.X - p0.X) / 6) * w, (1 - (p1.Y + (p2.Y - p0.Y) / 6)) * h);
                    var c2 = new Point((p2.X - (p3.X - p1.X) / 6) * w, (1 - (p2.Y - (p3.Y - p1.Y) / 6)) * h);
                    ctx.BezierTo(c1, c2, new Point(p2.X * w, (1 - p2.Y) * h), true, false);
                }
            }
            geometry.Freeze();
            dc.DrawGeometry(null, curvePen, geometry);
            foreach (var point in _settings.CurvePoints) DrawPoint(dc, point.X * w, (1 - point.Y) * h, accent);
        }

        private static void DrawPoint(DrawingContext dc, double x, double y, Brush brush) => dc.DrawEllipse(brush, null, new Point(x, y), 6, 6);

        protected override void OnMouseLeftButtonDown(MouseButtonEventArgs e)
        {
            _dragging = true;
            CaptureMouse();
            _activePoint = FindOrCreatePoint(e.GetPosition(this));
            UpdateValue(e.GetPosition(this));
            e.Handled = true;
        }

        protected override void OnMouseMove(MouseEventArgs e)
        {
            if (_dragging) UpdateValue(e.GetPosition(this));
        }

        protected override void OnMouseLeftButtonUp(MouseButtonEventArgs e)
        {
            _dragging = false;
            _activePoint = -1;
            ReleaseMouseCapture();
            e.Handled = true;
        }

        private void UpdateValue(Point point)
        {
            var x = Math.Clamp(point.X / Math.Max(1, ActualWidth), 0, 1);
            var y = Math.Clamp(1 - point.Y / Math.Max(1, ActualHeight), 0, 1);
            if (_activePoint < 0) _activePoint = FindOrCreatePoint(point);
            _settings.CurvePoints[_activePoint].X = x;
            _settings.CurvePoints[_activePoint].Y = y;
            InvalidateVisual();
            ValueChanged?.Invoke("curve", y);
        }

        private int FindOrCreatePoint(Point point)
        {
            var x = Math.Clamp(point.X / Math.Max(1, ActualWidth), 0, 1);
            var y = Math.Clamp(1 - point.Y / Math.Max(1, ActualHeight), 0, 1);
            var nearest = _settings.CurvePoints
                .Select((candidate, index) => (candidate, index, distance: Math.Pow(candidate.X - x, 2) + Math.Pow(candidate.Y - y, 2)))
                .OrderBy(item => item.distance)
                .FirstOrDefault();
            if (nearest.candidate is not null && nearest.distance <= .035 * .035) return nearest.index;
            _settings.CurvePoints.Add(new EditorCurvePoint(x, y));
            return _settings.CurvePoints.Count - 1;
        }
    }

    private sealed record EditorSliderSpec(
        string Key,
        string Label,
        double Minimum,
        double Maximum,
        bool Exposure = false);

    private sealed record EditorAIAnalysis(
        double MeanLuma,
        double Contrast,
        double ShadowRatio,
        double HighlightRatio,
        double Saturation,
        double Red,
        double Green,
        double Blue,
        double Detail)
    {
        public string Summary =>
            MeanLuma < 0.38
                ? "检测到画面偏暗，已提亮阴影并保护高光"
                : MeanLuma > 0.64 || HighlightRatio > 0.08
                    ? "检测到画面偏亮，已回收高光并恢复层次"
                    : Contrast < 0.16
                        ? "检测到动态范围偏平，已增强层次与色彩"
                        : "曝光均衡，已优化色彩与细节";
    }

    private static readonly string AnnouncementStatePath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "NikonLink",
        "dismissed-announcement-version.txt");
    private static readonly string LibraryBranchStatePath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "NikonLink",
        "library-branches.json");
    private static readonly string LibraryFileAssignmentStatePath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "NikonLink",
        "library-file-assignments.json");
    private static readonly string RememberedDevicesStatePath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "NikonLink",
        "remembered-camera-devices.json");
    private static readonly string ExternalRecordingStatePath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "NikonLink",
        "external-recording-enabled.txt");
    private static readonly string WifiConnectionModeStatePath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "NikonLink",
        "wifi-camera-connection-mode.txt");
    private static readonly string LivePhotoStatePath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "NikonLink",
        "live-photo-enabled.txt");
    private static readonly string LivePhotoSecondsStatePath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "NikonLink",
        "live-photo-seconds.txt");
    private static readonly string WorkspaceLayoutStatePath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "NikonLink",
        "desktop-workspace-layout-v1.json");
    private const string LibraryDragFormat = "ZENCHE.LibraryFilePath";
    private const string AfdianUrl = "https://www.ifdian.net/a/Tauber";
    private const string ZencheWebsiteUrl = "https://zenche.top";
    private readonly PtpCamera _camera = new();
    private readonly PtpIpCamera _wifiCamera = new();
    private readonly LocalCameraService _localCamera = new();
    private readonly ExternalVideoRecorder _externalVideoRecorder = new();
    private readonly LivePhotoClipRecorder _livePhotoClipRecorder = new();
    private readonly BluetoothRemoteController _bluetoothRemote = new();
    private readonly LocationTaggingService _locationTagging = new();
    private readonly NikonOfficialSdkService _nikonOfficialSdk = new();
    private readonly SonyOfficialSdkCamera _sonyOfficialSdk =
        SonyOfficialSdkCamera.Shared;
    private readonly PhotoLibrary _library = new();
    private readonly CaptureWorkflow _workflow;
    private readonly WirelessTransferServer _wirelessServer;
    private readonly DiagnosticLogger _diagnostics = DiagnosticLogger.Shared;
    private readonly UpdateService _updateService = new();
    private readonly AuthService _authService = new();
    private WorkspaceLayoutState _workspaceLayout = LoadWorkspaceLayout();
    private string _currentDestination = "capture";
    private readonly List<LibraryBranch> _libraryBranches;
    private readonly Dictionary<string, string> _libraryFileAssignments;
    private readonly List<RememberedCameraDevice> _rememberedDevices;
    private readonly ObservableCollection<CameraStorageListItem>
        _cameraStorageRows = [];
    private CameraStorageSnapshot _cameraStorageSnapshot =
        CameraStorageSnapshot.Empty;
    private bool _cameraStorageBusy;
    private bool _localDownloadBusy;
    private bool _localDownloadPreparationBusy;
    private CancellationTokenSource? _previewCancellation;
    private Task? _previewTask;
    private CancellationTokenSource? _shootingTaskCancellation;
    private bool _operationInProgress;
    private string? _lastConnectionError;
    private bool _gridEditMode;
    private bool[] _gridHiddenTiles = new bool[6];
    private bool _initializing = true;
    private bool _shutdownStarted;
    private bool _signedInServicesInitialized;
    private bool _authRegisterMode;
    private bool _authCodeRequired = true;
    private bool _authBusy;
    private int _authCodeCountdown;
    private readonly System.Windows.Threading.DispatcherTimer _authCodeTimer = new()
    {
        Interval = TimeSpan.FromSeconds(1)
    };
    private bool _configuringVideoControls;
    private bool _videoMode;
    private bool _videoRecording;
    private bool _externalRecordToDevice = true;
    private string _wifiConnectionMode = "ap";
    // ── E5 1.5.9：live 图（取景帧环形缓冲 + 快门切片配对）──
    private bool _livePhotoEnabled;
    private double _livePhotoSeconds = 3.0;
    // ── E3 1.5.9：Wi‑Fi PTP/IP 取景 / 参数缓存 ──
    private CancellationTokenSource? _wifiPreviewCancellation;
    private Task? _wifiPreviewTask;
    private ushort _wifiIso;
    private double _wifiAperture;
    private double _wifiShutterSeconds;
    private TextBlock? WifiParameterReadout;
    // ── B2 WiFi 连接监看：保活/自动重连/网络监听 ──
    private static readonly int[] WifiReconnectBackoffMs =
        { 1000, 2000, 4000, 8000, 16000, 30000 };
    private static int WifiBackoffDelayMs(int attempt) =>
        WifiReconnectBackoffMs[
            Math.Clamp(attempt, 1, WifiReconnectBackoffMs.Length) - 1];
    private readonly System.Windows.Threading.DispatcherTimer
        _wifiHeartbeatTimer = new()
        {
            Interval = TimeSpan.FromMilliseconds(5000)
        };
    private CancellationTokenSource? _wifiReconnectCts;
    private bool _wifiReconnecting;
    private bool _wifiManualDisconnect;
    private int _wifiMissedHeartbeats;
    private int _wifiReconnectAttempt;
    private string _wifiHost = "192.168.1.1";
    private int _wifiPort = 15740;
    private DateTime? _recordingStartedAt;
    private readonly System.Windows.Threading.DispatcherTimer _monitorTimecodeTimer =
        new() { Interval = TimeSpan.FromMilliseconds(100) };
    private readonly System.Windows.Threading.DispatcherTimer _editorPreviewTimer =
        new() { Interval = TimeSpan.FromMilliseconds(33) };
    private bool _editorPreviewPending;
    private int _previewAnalysisSequence;
    private double _videoFrameRate = 30;
    private double _videoShutterAngle = 180;
    private string _videoShutterMode = "angle";
    private double _photoShutterSeconds = 0.008;
    private string _videoCodec = "h265";
    private string _videoLogProfile = "off";
    private string _shootingTaskKind = "interval";
    private int _shootingTaskCount = 5;
    private int _shootingTaskInterval = 3;
    private int _shootingTaskStep = 1;
    private bool _focusPeakingEnabled;
    private bool _falseColorEnabled;
    private bool _monitorLutEnabled;
    private bool _monitorZebraEnabled;
    private string? _availableUpdateUrl;
    private bool _checkingForUpdates;
    private bool _announcementShownThisLaunch;
    private Window? _immersivePreviewWindow;
    private Image? _immersivePreviewImage;
    private Button? _immersiveRecordButton;
    private WaveformScope? _immersiveScope;
    private Point _libraryDragStart;
    private bool _libraryDragInProgress;
    private TreeViewItem? _libraryDropTarget;
    private string? _editorSelectedPath;
    private readonly EditorAdjustments _editorAdjustments = new();
    private readonly NikonCloudCatalog _nikonCloudCatalog =
        NikonCloudCatalog.Load();
    private NikonCloudPreset? _selectedNikonCloudPreset;
    private NikonCloudPreset? _monitorNikonCloudPreset;
    private bool _updatingMonitorCloudControls;
    private BitmapSource? _lastPreviewSource;
    private NikonCloudPreset? _editorCloudPresetBeforeAI;
    private EditorAdjustments? _editorSettingsBeforeAI;
    private EditorAdjustments? _editorAICopiedSettings;
    // E8 1.5.9: AI 批量应用（本地渲染，0 服务器消耗）——队列状态。
    private bool _aiBatchApplying;
    private volatile bool _aiBatchCancelled;
    private int _aiBatchProgress;
    private int _aiBatchTotal;
    private int _aiBatchSkipped;
    private EditorAIAnalysis? _editorAIAnalysis;
    private readonly Dictionary<string, Slider> _editorSliders = [];
    private readonly Dictionary<string, Slider> _editorGradeSliders = [];
    private readonly Dictionary<string, EditorWheelControl> _editorWheelControls = [];
    private EditorCurveControl? _editorCurveControl;
    private ComboBox? _editorCropBox;
    private ComboBox? _editorMaskBox;
    private Slider? _editorMaskAmountSlider;
    private Slider? _editorMaskFeatherSlider;
    private Slider? _editorMaskBrushSizeSlider;
    private CheckBox? _editorMaskInvertCheckBox;
    private StackPanel? _editorMaskListPanel;
    private TextBlock? _editorPickedColorText;
    private bool _editorPickerArmed;
    private EditorMaskStroke? _activeEditorMaskStroke;
    private bool _updatingEditorControls;
    private string _aiPrompt = "";
    private string _aiManualPrompt = "";
    private readonly HashSet<string> _aiSelectedPresets = [];
    private int _aiMode; // 0=edit, 1=generate
    private int _aiRatioIndex;
    private int _aiResolutionIndex;
    private string? _aiResultPath;
    private int? _aiServerRemainingUsage;
    private bool _aiGenerating;
    private bool _editorInAiMode;

    private static readonly string[] AiSizes =
    [
        "1024x1024", "1792x1024", "1024x1792", "1365x1024", "1536x1024"
    ];

    private const int AiMaxUsage = 100;
    private const string AiServerDefault = "https://zenche.top/api";
    private const string AiServerLegacy = "http://101.34.255.115:8787";
    private const string AiRebindEndpoint =
        "https://zenche.top/api/v1/ai/rebind";
    private const int AiRebindResponseLimit = 64 * 1024;
    private static readonly string AiDataDir = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "NikonLink");

    private static bool IsAiActivated()
    {
        var activatedPath = Path.Combine(AiDataDir, "ai-activated.txt");
        return File.Exists(activatedPath) && GetRemainingUsage() > 0;
    }

    private static int GetRemainingUsage()
    {
        var serverRemainingPath = Path.Combine(
            AiDataDir,
            "ai-server-remaining.txt");
        if (File.Exists(serverRemainingPath) &&
            int.TryParse(
                File.ReadAllText(serverRemainingPath).Trim(),
                NumberStyles.Integer,
                CultureInfo.InvariantCulture,
                out var serverRemaining))
        {
            return Math.Clamp(serverRemaining, 0, AiMaxUsage);
        }
        return GetLocalRemainingUsage();
    }

    private static int GetLocalRemainingUsage()
    {
        var countPath = Path.Combine(AiDataDir, "ai-usage-count.txt");
        var count = 0;
        if (File.Exists(countPath))
            int.TryParse(File.ReadAllText(countPath).Trim(), out count);
        return Math.Max(0, AiMaxUsage - count);
    }

    private static void SaveServerRemainingUsage(int remaining)
    {
        Directory.CreateDirectory(AiDataDir);
        File.WriteAllText(
            Path.Combine(AiDataDir, "ai-server-remaining.txt"),
            Math.Clamp(remaining, 0, AiMaxUsage).ToString(
                CultureInfo.InvariantCulture));
    }

    private int CurrentRemainingUsage() =>
        _aiServerRemainingUsage ?? GetRemainingUsage();

    private bool HasAiUsageAvailable() => CurrentRemainingUsage() > 0;

    private static int? ReadServerRemainingUsage(HttpResponseMessage response)
    {
        if (!response.Headers.TryGetValues(
                "X-ZENCHE-Remaining",
                out var values))
        {
            return null;
        }
        var value = values.FirstOrDefault();
        return int.TryParse(
                value,
                NumberStyles.Integer,
                CultureInfo.InvariantCulture,
                out var remaining)
            ? Math.Clamp(remaining, 0, AiMaxUsage)
            : null;
    }

    private static void RecordAiUsage()
    {
        Directory.CreateDirectory(AiDataDir);
        var countPath = Path.Combine(AiDataDir, "ai-usage-count.txt");
        var count = 0;
        if (File.Exists(countPath))
            int.TryParse(File.ReadAllText(countPath).Trim(), out count);
        count++;
        File.WriteAllText(countPath, count.ToString());
        if (count >= AiMaxUsage)
        {
            var activatedPath = Path.Combine(AiDataDir, "ai-activated.txt");
            if (File.Exists(activatedPath)) File.Delete(activatedPath);
        }
    }

    private static string GetDeviceId()
    {
        var devicePath = Path.Combine(AiDataDir, "ai-device-id.txt");
        if (File.Exists(devicePath))
        {
            var existing = File.ReadAllText(devicePath).Trim();
            if (existing.Length > 0) return existing;
        }
        var id = System.Security.Principal.WindowsIdentity.GetCurrent().User?.Value
                 ?? Guid.NewGuid().ToString();
        Directory.CreateDirectory(AiDataDir);
        File.WriteAllText(devicePath, id);
        return id;
    }

    private static string LoadAiServerUrl()
    {
        try
        {
            var serverPath = Path.Combine(AiDataDir, "ai-server-url.txt");
            if (File.Exists(serverPath))
            {
                var value = File.ReadAllText(serverPath).Trim().TrimEnd('/');
                if (value.Length > 0 &&
                    !string.Equals(value, AiServerLegacy,
                        StringComparison.OrdinalIgnoreCase))
                    return value;
            }
        }
        catch (Exception error)
        {
            DiagnosticLogger.Shared.Warning(
                "ai", $"读取 AI 服务器地址失败：{error.Message}");
        }
        return AiServerDefault;
    }

    private static string LoadActivationCode()
    {
        try
        {
            var codePath = Path.Combine(AiDataDir, "ai-activation-code.txt");
            if (File.Exists(codePath))
            {
                var value = File.ReadAllText(codePath).Trim();
                if (value.Length > 0) return value;
            }
        }
        catch (Exception error)
        {
            DiagnosticLogger.Shared.Warning(
                "ai", $"读取激活码失败：{error.Message}");
        }
        return string.Empty;
    }

    private static void SaveActivationCode(string code)
    {
        try
        {
            Directory.CreateDirectory(AiDataDir);
            var codePath = Path.Combine(AiDataDir, "ai-activation-code.txt");
            File.WriteAllText(codePath, code.Trim());
        }
        catch (Exception error)
        {
            DiagnosticLogger.Shared.Warning(
                "ai", $"保存激活码失败：{error.Message}");
        }
    }

    private static void SaveReboundActivation(string code, int remaining)
    {
        Directory.CreateDirectory(AiDataDir);
        var bounded = Math.Clamp(remaining, 0, AiMaxUsage);
        var transactionId = Guid.NewGuid().ToString("N");
        var codePath = Path.Combine(AiDataDir, "ai-activation-code.txt");
        var countPath = Path.Combine(AiDataDir, "ai-usage-count.txt");
        var remainingPath = Path.Combine(AiDataDir, "ai-server-remaining.txt");
        var activatedPath = Path.Combine(AiDataDir, "ai-activated.txt");
        var codeTemp = codePath + "." + transactionId + ".tmp";
        var countTemp = countPath + "." + transactionId + ".tmp";
        var remainingTemp = remainingPath + "." + transactionId + ".tmp";
        var activatedTemp = activatedPath + "." + transactionId + ".tmp";
        var temporaryPaths = new[]
        {
            codeTemp, countTemp, remainingTemp, activatedTemp
        };
        try
        {
            File.WriteAllText(codeTemp, code.Trim());
            File.WriteAllText(
                countTemp,
                (AiMaxUsage - bounded).ToString(CultureInfo.InvariantCulture));
            File.WriteAllText(
                remainingTemp,
                bounded.ToString(CultureInfo.InvariantCulture));
            File.WriteAllText(activatedTemp, bounded > 0 ? "1" : "0");

            // Same-directory moves are atomic per file. Publish the server
            // counter first and the activation marker last so a crash cannot
            // expose unverified data as a newly active entitlement.
            File.Move(remainingTemp, remainingPath, true);
            File.Move(countTemp, countPath, true);
            File.Move(codeTemp, codePath, true);
            if (bounded > 0)
            {
                File.Move(activatedTemp, activatedPath, true);
            }
            else
            {
                if (File.Exists(activatedPath)) File.Delete(activatedPath);
                File.Delete(activatedTemp);
            }
        }
        finally
        {
            foreach (var path in temporaryPaths)
            {
                try
                {
                    if (File.Exists(path)) File.Delete(path);
                }
                catch
                {
                    // A stale transaction file is inert and can be retried.
                }
            }
        }
    }

    private const string AiActivationPublicKey =
        "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAngqgOi5fjajCPusMNsfB" +
        "FdMmWyzAGArL5bA+JK/uW+Md/YDtGvXjgSodev7VOQ9SPWqHUYA+XTpdyeCA+weL" +
        "32JhFf+8+a28DjIp7RMv962m1qXJLtcdFbiBjWGDWF+itDJGUgR5OQbxV8xDd/kj" +
        "c1ZT5ft7r2KwECUvwjKr9SAOWGJPK9oNmo9u2kW/6PbjpSEIhDH88FYloNWxpmdW" +
        "XoQ2YYAfd5sKc0CNcBFdu2oEFGFHeUufbhgkZWtDPCS299W4TuWyTDfWPx4+Raap" +
        "bcVF9RfFPa1uI7MpyrOqrGgSnuSC7HxY/B+NXm5rt4p3ZRaOzyKBiZEQ8Sg0XpKI" +
        "3wIDAQAB";

    private static bool VerifyActivationCode(string code, string deviceId)
    {
        var trimmed = code.Trim();
        if (string.IsNullOrEmpty(trimmed) || string.IsNullOrEmpty(deviceId))
        {
            return false;
        }
        var parts = trimmed.Split('-');
        if (parts.Length < 4 || parts[0] != "ZENCHE" || parts[1] != "AI")
        {
            return false;
        }
        var expiry = parts[parts.Length - 1];
        if (!DateTime.TryParseExact(
                expiry,
                "yyyyMMdd",
                CultureInfo.InvariantCulture,
                DateTimeStyles.None,
                out var expiryDate) ||
            expiryDate < DateTime.Today)
        {
            return false;
        }
        var signatureText = string.Join("-", parts, 2, parts.Length - 3);
        try
        {
            var signature = Convert.FromBase64String(signatureText);
            var payload = $"{deviceId}:{expiry}:a1b2c3d4e5f6";
            using var rsa = System.Security.Cryptography.RSA.Create();
            rsa.ImportSubjectPublicKeyInfo(
                Convert.FromBase64String(AiActivationPublicKey),
                out _);
            return rsa.VerifyData(
                System.Text.Encoding.UTF8.GetBytes(payload),
                signature,
                System.Security.Cryptography.HashAlgorithmName.SHA256,
                System.Security.Cryptography.RSASignaturePadding.Pkcs1);
        }
        catch
        {
            return false;
        }
    }

    private void AiBuy_Click(object sender, RoutedEventArgs e)
    {
        OpenAfdian();
    }

    private void AiOfficialWebsite_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            Process.Start(new ProcessStartInfo
            {
                FileName = ZencheWebsiteUrl,
                UseShellExecute = true
            });
        }
        catch (Exception error)
        {
            _diagnostics.Error(
                "activation",
                $"无法打开官网兑换页：{error.Message}");
            ShowError("无法打开浏览器，请访问 zenche.top");
        }
    }

    private void AiActivate_Click(object sender, RoutedEventArgs e)
    {
        var code = AiActivationCodeBox.Text.Trim();
        if (string.IsNullOrEmpty(code))
        {
            AiActivationStatusText.Text = AppLocalization.T("请输入激活码");
            return;
        }
        // 本地 RSA 验签激活（公钥在客户端），服务器端负责真正计数
        if (!VerifyActivationCode(code, GetDeviceId()))
        {
            AiActivationStatusText.Text = AppLocalization.T("激活码无效或已过期");
            return;
        }
        SaveActivationCode(code);
        var activatedPath = Path.Combine(AiDataDir, "ai-activated.txt");
        Directory.CreateDirectory(AiDataDir);
        File.WriteAllText(
            Path.Combine(AiDataDir, "ai-usage-count.txt"),
            "0");
        File.WriteAllText(activatedPath, "1");
        var serverRemainingPath = Path.Combine(
            AiDataDir,
            "ai-server-remaining.txt");
        if (File.Exists(serverRemainingPath))
        {
            File.Delete(serverRemainingPath);
        }
        AiActivationStatusText.Text = AppLocalization.T("激活成功！AI 功能已解锁");
        _aiServerRemainingUsage = null;
        AiActivationCodeBox.Text = "";
    }

    private async void AiRebind_Click(object sender, RoutedEventArgs e)
    {
        var oldDeviceId = AiRebindOldDeviceIdBox.Text.Trim();
        var oldCode = AiRebindOldCodeBox.Password.Trim();
        if (oldDeviceId.Length == 0 || oldCode.Length == 0)
        {
            AiActivationStatusText.Text =
                AppLocalization.T("请输入旧设备 ID 和旧激活码");
            return;
        }
        if (!VerifyActivationCode(oldCode, oldDeviceId))
        {
            AiActivationStatusText.Text = AppLocalization.T(
                "旧设备 ID 与旧激活码不匹配或已过期");
            return;
        }

        AiRebindButton.IsEnabled = false;
        AiRebindButton.Content = AppLocalization.T("正在迁移…");
        AiActivationStatusText.Text = AppLocalization.T("正在迁移…");
        try
        {
            var currentDeviceId = GetDeviceId();
            var payload = JsonSerializer.SerializeToUtf8Bytes(new
            {
                activationCode = oldCode,
                oldDeviceId,
                newDeviceId = currentDeviceId
            });
            using var client = new HttpClient
            {
                Timeout = TimeSpan.FromSeconds(30)
            };
            using var request = new HttpRequestMessage(
                HttpMethod.Post,
                AiRebindEndpoint)
            {
                Content = new ByteArrayContent(payload)
            };
            request.Content.Headers.ContentType =
                new System.Net.Http.Headers.MediaTypeHeaderValue(
                    "application/json");
            var accountToken = _authService.GetToken();
            if (!string.IsNullOrWhiteSpace(accountToken))
            {
                request.Headers.Authorization =
                    new System.Net.Http.Headers.AuthenticationHeaderValue(
                        "Bearer", accountToken);
            }
            using var response = await client.SendAsync(
                request,
                HttpCompletionOption.ResponseHeadersRead);
            var responseBytes = await ReadLimitedResponseAsync(
                response.Content,
                AiRebindResponseLimit);
            using var document = JsonDocument.Parse(responseBytes);
            var root = document.RootElement;
            if (!response.IsSuccessStatusCode)
            {
                var serverMessage = root.TryGetProperty("error", out var error)
                    && error.ValueKind == JsonValueKind.String
                        ? error.GetString()
                        : null;
                throw new InvalidOperationException(
                    string.IsNullOrWhiteSpace(serverMessage)
                        ? $"设备码恢复服务返回错误 {(int)response.StatusCode}"
                        : serverMessage);
            }
            if (!root.TryGetProperty("newCode", out var codeElement)
                || codeElement.ValueKind != JsonValueKind.String
                || !root.TryGetProperty("remaining", out var remainingElement)
                || !remainingElement.TryGetInt32(out var remaining)
                || remaining < 0
                || remaining > AiMaxUsage)
            {
                throw new InvalidOperationException("设备码恢复响应无效");
            }
            var newCode = codeElement.GetString()?.Trim() ?? "";
            if (newCode.Length == 0)
            {
                throw new InvalidOperationException("设备码恢复响应无效");
            }
            if (!VerifyActivationCode(newCode, currentDeviceId))
            {
                throw new InvalidOperationException(
                    "服务器返回的新激活码验证失败，未修改本机数据");
            }

            SaveReboundActivation(newCode, remaining);
            _aiServerRemainingUsage = remaining;
            AiRebindOldDeviceIdBox.Text = "";
            AiRebindOldCodeBox.Password = "";
            AiActivationStatusText.Text = AppLocalization.T(
                "设备码恢复成功，AI 权益已迁移到当前设备");
        }
        catch (Exception error)
        {
            AiActivationStatusText.Text = AppLocalization.T(
                $"设备码恢复失败：{error.Message}");
        }
        finally
        {
            AiRebindButton.IsEnabled = true;
            AiRebindButton.Content = AppLocalization.T("恢复到当前设备");
        }
    }

    private static async Task<byte[]> ReadLimitedResponseAsync(
        HttpContent content,
        int maximumBytes)
    {
        if (content.Headers.ContentLength is long length
            && length > maximumBytes)
        {
            throw new InvalidOperationException("设备码恢复响应过大");
        }
        await using var stream = await content.ReadAsStreamAsync();
        using var buffer = new MemoryStream();
        var chunk = new byte[4096];
        while (true)
        {
            var read = await stream.ReadAsync(chunk);
            if (read == 0) break;
            if (buffer.Length + read > maximumBytes)
            {
                throw new InvalidOperationException("设备码恢复响应过大");
            }
            buffer.Write(chunk, 0, read);
        }
        return buffer.ToArray();
    }

    private void AiCopyDeviceId_Click(object sender, RoutedEventArgs e)
    {
        Clipboard.SetText(GetDeviceId());
        AiActivationStatusText.Text = AppLocalization.T("设备 ID 已复制，可前往官网兑换密钥");
    }
#if NIKONLINK_WINDOWS_SHARE
    private DataTransferManager? _dataTransferManager;
#endif
    private string? _sharePhotoPath;

    public MainWindow()
    {
        InitializeComponent();
        _authCodeTimer.Tick += AuthCodeTimer_Tick;
        CameraStorageList.ItemsSource = _cameraStorageRows;
        _monitorTimecodeTimer.Tick += (_, _) => UpdateMonitorTimecode();
        _editorPreviewTimer.Tick += (_, _) =>
        {
            _editorPreviewTimer.Stop();
            if (!_editorPreviewPending || _shutdownStarted)
            {
                return;
            }
            _editorPreviewPending = false;
            RenderEditorPreviewNow();
        };
        BuildEditorAdjustmentControls();
        EditorPresetBox.SelectedIndex = 0;
        NikonCloudPresetBox.Items.Add(new ComboBoxItem
        {
            Content = AppLocalization.T("关闭云创预览"),
            Tag = null
        });
        foreach (var preset in _nikonCloudCatalog.Presets)
        {
            NikonCloudPresetBox.Items.Add(new ComboBoxItem
            {
                Content = preset.Name +
                    (preset.HasCustomToneCurve ? " · Curve" : ""),
                Tag = preset
            });
        }
        NikonCloudPresetBox.SelectedIndex = 0;
        PopulateMonitorNikonCloudPresetBoxes();
        _libraryBranches = LoadLibraryBranches();
        _libraryFileAssignments = LoadLibraryFileAssignments();
        _rememberedDevices = LoadRememberedDevices();
        _workflow = new CaptureWorkflow(_library.DirectoryPath);
        LoadCaptureSessionControls();
        _wirelessServer = new WirelessTransferServer(_library);
        _wirelessServer.StatusChanged += (_, status) =>
            Dispatcher.Invoke(() =>
            {
                _diagnostics.Info("wireless", status);
                WirelessStatusText.Text = AppLocalization.T(status);
                OperationStatusText.Text = AppLocalization.T(status);
            });
        _wirelessServer.FileReceived += (_, path) =>
            Dispatcher.Invoke(() =>
            {
                _diagnostics.Info(
                    "wireless",
                    $"已接收文件；名称={Path.GetFileName(path)}");
                OperationStatusText.Text = AppLocalization.T(
                    $"已接收 {Path.GetFileName(path)}");
                RefreshPhotoList();
            });
        _wirelessServer.Failed += (_, error) =>
            Dispatcher.Invoke(() =>
            {
                _diagnostics.Error("wireless", error.ToString());
                WirelessStatusText.Text = AppLocalization.T(
                    $"无线接收失败：{error.Message}");
                WirelessButton.Content =
                    AppLocalization.T("开启无线接收");
                ShowError(error.Message);
            });
        _bluetoothRemote.StatusChanged += (_, status) =>
            Dispatcher.Invoke(() =>
            {
                OperationStatusText.Text = AppLocalization.T(status);
                UpdateConnectionSummary();
            });
        _bluetoothRemote.ShutterPressed += (_, _) =>
            Dispatcher.Invoke(() =>
                ShutterButton_Click(this, new RoutedEventArgs()));
        _locationTagging.StatusChanged += (_, status) =>
            Dispatcher.Invoke(() =>
                OperationStatusText.Text = AppLocalization.T(status));
        DiagnosticLogPathText.Text = AppLocalization.T(
            "按日写入、5 MB 滚动、保留 14 天\n") +
            _diagnostics.DirectoryPath;
        CurrentVersionText.Text = AppLocalization.T(
            $"当前版本 {_updateService.CurrentVersion} · 优先通过 Mirror酱检查更新，无可用 CDN 下载地址时自动回退 GitHub Releases");
        SidebarVersionText.Text = $"ZENCHE {_updateService.CurrentVersion}";
        MirrorChyanCdkBox.Password = _updateService.LoadMirrorChyanCdk();
        _externalRecordToDevice = LoadExternalRecordingPreference();
        _wifiConnectionMode = LoadWifiConnectionModePreference();
        _livePhotoEnabled = LoadLivePhotoPreference();
        _livePhotoSeconds = LoadLivePhotoSecondsPreference();
        WifiCameraTransferHost.Content = BuildWifiCameraTransferPanel();
        CaptureAssistSettingsHost.Content = BuildCaptureAssistSettingsPanel();
        ExternalRecordingCheck.IsChecked = _externalRecordToDevice;
        ConfigureVideoRecordingOptions(null);
        ConfigureFineExposureControls();
        ConfigureShutterControl(false);
        RefreshPhotoList();
        RefreshRememberedDevices();
        SetCurrentNavigation(CaptureNav);
        LanguageBox.SelectedIndex = AppLocalization.Current switch
        {
            InterfaceLanguage.English => 1,
            InterfaceLanguage.Japanese => 2,
            _ => 0
        };
        AppLocalization.Apply(this);
        UpdateAuthLocalizedText();
        _initializing = false;
        UpdateExposureReadout();
        UpdateControlStatusRow();
        ShootingTaskStepText.IsEnabled = false;
        Closing += Window_Closing;
        Loaded += MainWindow_Loaded;
        PreviewKeyUp += MainWindow_PreviewKeyUp;
        SizeChanged += (_, _) => ApplyResponsiveEditorLayout();
        ApplyResponsiveEditorLayout();
    }

    private void ApplyResponsiveEditorLayout()
    {
        if (EditorMediaColumn is null ||
            EditorToolsColumn is null ||
            EditorAiPreviewColumn is null ||
            EditorAiToolsColumn is null)
        {
            return;
        }
        var availableWidth = ActualWidth > 0 ? ActualWidth : Width;
        var compact = availableWidth < 1120;
        var cameraWorkspace = _currentDestination is "capture" or "monitor";
        var editorWorkspace = _currentDestination == "editor";
        var minimumWorkspaceWidth = cameraWorkspace
            ? 620d
            : editorWorkspace
                ? (compact ? 708d : 828d)
                : 380d;
        var maximumSidebarWidth = Math.Clamp(
            availableWidth - minimumWorkspaceWidth,
            72d,
            360d);
        SidebarColumn.MaxWidth = maximumSidebarWidth;
        var sidebarWidth = Math.Clamp(
            _workspaceLayout.SidebarWidth,
            72d,
            maximumSidebarWidth);
        SidebarColumn.Width = new GridLength(sidebarWidth);

        ParameterColumn.MinWidth = cameraWorkspace ? 240 : 0;
        ParameterColumn.MaxWidth = cameraWorkspace
            ? Math.Clamp(
                availableWidth - sidebarWidth - 380d,
                240d,
                720d)
            : 0;
        ParameterColumn.Width = cameraWorkspace
            ? new GridLength(Math.Clamp(
                _workspaceLayout.ParameterWidth,
                240d,
                ParameterColumn.MaxWidth))
            : new GridLength(0);

        EditorMediaColumn.MinWidth = compact ? 0 : 140;
        EditorMediaColumn.Width = compact
            ? new GridLength(0)
            : new GridLength(Math.Clamp(
                _workspaceLayout.EditorMediaWidth, 140, 520));
        EditorMediaRail.Visibility = compact
            ? Visibility.Collapsed
            : Visibility.Visible;
        EditorToolsColumn.Width = new GridLength(
            compact
                ? 300
                : Math.Clamp(_workspaceLayout.EditorToolsWidth, 280, 720));
        EditorAiPreviewColumn.MinWidth = compact ? 0 : 360;
        EditorAiPreviewColumn.Width = compact
            ? new GridLength(0)
            : new GridLength(1, GridUnitType.Star);
        AiPreviewPanel.Visibility = compact
            ? Visibility.Collapsed
            : Visibility.Visible;
        EditorAiToolsSplitter.Visibility = compact
            ? Visibility.Collapsed
            : Visibility.Visible;
        EditorAiToolsColumn.MinWidth = compact ? 0 : 340;
        EditorAiToolsColumn.MaxWidth = compact
            ? double.PositiveInfinity
            : 720;
        EditorAiToolsColumn.Width = compact
            ? new GridLength(1, GridUnitType.Star)
            : new GridLength(Math.Clamp(
                _workspaceLayout.EditorAiToolsWidth, 340, 720));
    }

    private async void MainWindow_Loaded(object sender, RoutedEventArgs e)
    {
        ApplyWorkspaceLayout();
#if NIKONLINK_WINDOWS_SHARE
        try
        {
            var handle = new WindowInteropHelper(this).Handle;
            _dataTransferManager =
                DataTransferManagerHelper.GetForWindow(handle);
            _dataTransferManager.DataRequested += Share_DataRequested;
        }
        catch (Exception error)
        {
            _diagnostics.Warning(
                "share",
                $"Windows 分享面板初始化失败：{error.Message}");
        }
#endif
        await BootstrapAuthAsync();
    }

    // ── W13-e Windows 邮箱账号登录墙 ──────────────────────────────────────

    private async Task BootstrapAuthAsync()
    {
        AuthWall.Visibility = Visibility.Visible;
        AuthCheckingPanel.Visibility = Visibility.Visible;
        AuthFormPanel.Visibility = Visibility.Collapsed;
        AuthCheckingText.Text = AppLocalization.T("正在验证登录状态…");
        if (!_authService.HasSession())
        {
            ShowAuthForm();
            return;
        }

        var result = await _authService.MeAsync();
        if (result.IsSuccess || result.IsOfflineTolerable)
        {
            await EnterSignedInStateAsync();
            return;
        }

        var cleared = _authService.ClearSession();
        ShowAuthForm(
            cleared ? result.Message : AuthService.LocalCleanupFailureMessage);
    }

    private async Task EnterSignedInStateAsync()
    {
        AuthWall.Visibility = Visibility.Collapsed;
        AuthCheckingPanel.Visibility = Visibility.Collapsed;
        AuthFormPanel.Visibility = Visibility.Collapsed;
        AccountEmailText.Text = string.IsNullOrWhiteSpace(_authService.GetEmail())
            ? AppLocalization.T("未登录")
            : _authService.GetEmail();
        LogoutButton.IsEnabled = true;
        if (_signedInServicesInitialized) return;
        _signedInServicesInitialized = true;
        ShowLaunchAnnouncementIfNeeded();
        await RefreshNikonOfficialSdkAsync(allowRemoteProbe: !_camera.IsConnected);
        await RefreshSonyOfficialSdkAsync(allowEnumeration: !_camera.IsConnected);
        await CheckForUpdatesAsync(silent: true);
    }

    private void ShowAuthForm(string? message = null)
    {
        foreach (var owned in OwnedWindows.Cast<Window>().ToArray())
        {
            owned.Close();
        }
        _authBusy = false;
        _authCodeRequired = true;
        _authCodeTimer.Stop();
        _authCodeCountdown = 0;
        AuthWall.Visibility = Visibility.Visible;
        AuthCheckingPanel.Visibility = Visibility.Collapsed;
        AuthFormPanel.Visibility = Visibility.Visible;
        AuthEmailBox.IsEnabled = true;
        AuthPasswordBox.IsEnabled = true;
        AuthCodeBox.IsEnabled = true;
        AuthSendCodeButton.IsEnabled = true;
        SetAuthMode(register: false);
        AuthErrorText.Text = string.IsNullOrWhiteSpace(message)
            ? ""
            : AppLocalization.T(message);
        Dispatcher.BeginInvoke(
            System.Windows.Threading.DispatcherPriority.Input,
            () => AuthEmailBox.Focus());
    }

    private void SetAuthMode(bool register)
    {
        _authRegisterMode = register;
        AuthLoginModeButton.Style = (Style)FindResource(
            register ? "ButtonBase" : "PrimaryButton");
        AuthRegisterModeButton.Style = (Style)FindResource(
            register ? "PrimaryButton" : "ButtonBase");
        AuthCodePanel.Visibility = register && _authCodeRequired
            ? Visibility.Visible
            : Visibility.Collapsed;
        UpdateAuthLocalizedText();
        AuthErrorText.Text = "";
    }

    private void UpdateAuthLocalizedText()
    {
        AuthLoginModeButton.Content = AppLocalization.T("已有账号");
        AuthRegisterModeButton.Content = AppLocalization.T("创建账号");
        AuthSubmitButton.Content = AppLocalization.T(
            _authBusy
                ? _authRegisterMode ? "正在注册…" : "正在登录…"
                : _authRegisterMode ? "注册" : "登录");
        AuthModeHintText.Text = AppLocalization.T(
            _authRegisterMode
                ? "已有账号？切换到「登录」"
                : "还没有账号？切换到「注册」即可创建");
        AuthSendCodeButton.Content = _authCodeCountdown > 0
            ? AppLocalization.T("重新获取") + $" ({_authCodeCountdown}s)"
            : AppLocalization.T("获取验证码");
        AutomationProperties.SetName(AuthWall, AppLocalization.T("账号登录"));
        AutomationProperties.SetName(AuthEmailBox, AppLocalization.T("邮箱"));
        AutomationProperties.SetName(
            AuthPasswordBox,
            AppLocalization.T("密码（至少 8 位）"));
        AutomationProperties.SetName(
            AuthCodeBox,
            AppLocalization.T("6 位验证码"));
    }

    private void SetAuthBusy(bool busy)
    {
        _authBusy = busy;
        AuthEmailBox.IsEnabled = !busy;
        AuthPasswordBox.IsEnabled = !busy;
        AuthCodeBox.IsEnabled = !busy;
        AuthLoginModeButton.IsEnabled = !busy;
        AuthRegisterModeButton.IsEnabled = !busy;
        AuthSubmitButton.IsEnabled = !busy;
        AuthSendCodeButton.IsEnabled = !busy && _authCodeCountdown == 0;
        UpdateAuthLocalizedText();
    }

    private void AuthLoginMode_Click(object sender, RoutedEventArgs e) =>
        SetAuthMode(register: false);

    private void AuthRegisterMode_Click(object sender, RoutedEventArgs e) =>
        SetAuthMode(register: true);

    private async void AuthSendCode_Click(object sender, RoutedEventArgs e)
    {
        if (_authBusy) return;
        var email = AuthEmailBox.Text.Trim();
        if (!IsValidAuthEmail(email))
        {
            AuthErrorText.Text = AppLocalization.T("请输入有效的邮箱地址");
            return;
        }
        SetAuthBusy(true);
        AuthErrorText.Text = "";
        var result = await _authService.RequestEmailCodeAsync(email);
        SetAuthBusy(false);
        if (result.IsSuccess)
        {
            _authCodeRequired = true;
            AuthCodePanel.Visibility = Visibility.Visible;
            _authCodeCountdown = 60;
            _authCodeTimer.Start();
            AuthSendCodeButton.IsEnabled = false;
            AuthErrorText.Text = AppLocalization.T("验证码已发送至") + " " + email;
            UpdateAuthLocalizedText();
        }
        else if (result.Status == 503 && !result.IsProtocolError)
        {
            _authCodeRequired = false;
            AuthCodePanel.Visibility = Visibility.Collapsed;
            AuthErrorText.Text = AppLocalization.T("邮箱验证暂不可用，可直接注册");
        }
        else
        {
            AuthErrorText.Text = AppLocalization.T(result.Message);
        }
    }

    private async void AuthSubmit_Click(object sender, RoutedEventArgs e)
    {
        if (_authBusy) return;
        var email = AuthEmailBox.Text.Trim();
        var password = AuthPasswordBox.Password;
        var code = AuthCodeBox.Text.Trim();
        if (!IsValidAuthEmail(email))
        {
            AuthErrorText.Text = AppLocalization.T("请输入有效的邮箱地址");
            return;
        }
        if (password.Length < 8)
        {
            AuthErrorText.Text = AppLocalization.T("密码至少需要 8 位");
            return;
        }
        if (_authRegisterMode &&
            _authCodeRequired &&
            (code.Length != 6 || code.Any(character => !char.IsDigit(character))))
        {
            AuthErrorText.Text = AppLocalization.T("请输入 6 位验证码");
            return;
        }

        SetAuthBusy(true);
        AuthErrorText.Text = "";
        var result = _authRegisterMode
            ? await _authService.RegisterAsync(
                email,
                password,
                _authCodeRequired ? code : null)
            : await _authService.LoginAsync(email, password);
        SetAuthBusy(false);
        if (result.IsSuccess)
        {
            AuthPasswordBox.Clear();
            AuthCodeBox.Clear();
            _authCodeTimer.Stop();
            await EnterSignedInStateAsync();
        }
        else
        {
            AuthErrorText.Text = AppLocalization.T(result.Message);
        }
    }

    private async void LogoutButton_Click(object sender, RoutedEventArgs e)
    {
        if (_authBusy) return;
        LogoutButton.IsEnabled = false;
        LogoutButton.Content = AppLocalization.T("正在退出…");
        AuthWall.Visibility = Visibility.Visible;
        AuthFormPanel.Visibility = Visibility.Collapsed;
        AuthCheckingPanel.Visibility = Visibility.Visible;
        AuthCheckingText.Text = AppLocalization.T("正在退出…");
        await CloseAuthSensitiveStateAsync();
        var result = await _authService.LogoutAsync();
        AccountEmailText.Text = AppLocalization.T("未登录");
        LogoutButton.Content = AppLocalization.T("退出登录");
        ShowAuthForm(result.LocalCleanupFailed ? result.Message : null);
    }

    private async Task CloseAuthSensitiveStateAsync()
    {
        foreach (var owned in OwnedWindows.Cast<Window>().ToArray())
        {
            TryAuthCleanupStep("关闭附属窗口", owned.Close);
        }
        TryAuthCleanupStep("停止 Wi-Fi 监控", StopWifiMonitoring);
        TryAuthCleanupStep("停止 Wi-Fi 预览", StopWifiPreviewLoop);
        if (_immersivePreviewWindow is { } immersive)
        {
            TryAuthCleanupStep(
                "关闭沉浸式预览",
                () => CloseImmersivePreview(immersive));
        }

        await TryAuthCleanupStepAsync(
            "结束外部录制",
            FinishExternalRecordingForDisconnectAsync);
        await TryAuthCleanupStepAsync("停止预览循环", StopPreviewLoopAsync);
        await TryAuthCleanupStepAsync(
            "停止无线服务",
            async () =>
            {
                if (_wirelessServer.IsRunning) await _wirelessServer.StopAsync();
            });
        TryAuthCleanupStep("停止蓝牙遥控", _bluetoothRemote.Stop);
        await TryAuthCleanupStepAsync(
            "停止定位标记",
            async () =>
            {
                if (_locationTagging.Enabled)
                    await _locationTagging.SetEnabledAsync(false);
            });
        await TryAuthCleanupStepAsync(
            "断开本机摄像头",
            async () =>
            {
                if (_localCamera.IsConnected) await _localCamera.DisconnectAsync();
            });
        await TryAuthCleanupStepAsync(
            "断开 Wi-Fi 相机",
            async () =>
            {
                if (_wifiCamera.IsConnected) await _wifiCamera.DisconnectAsync();
            });
        await TryAuthCleanupStepAsync(
            "断开 USB/PTP 相机",
            async () =>
            {
                if (_camera.IsConnected) await _camera.DisconnectAsync();
            });
    }

    private void TryAuthCleanupStep(string step, Action cleanup)
    {
        try
        {
            cleanup();
        }
        catch (Exception error)
        {
            _diagnostics.Warning(
                "auth", $"退出登录时{step}失败：{error.Message}");
        }
    }

    private async Task TryAuthCleanupStepAsync(string step, Func<Task> cleanup)
    {
        try
        {
            await cleanup();
        }
        catch (Exception error)
        {
            _diagnostics.Warning(
                "auth", $"退出登录时{step}失败：{error.Message}");
        }
    }

    private void AuthCodeTimer_Tick(object? sender, EventArgs e)
    {
        if (_authCodeCountdown > 0) _authCodeCountdown--;
        if (_authCodeCountdown <= 0)
        {
            _authCodeTimer.Stop();
            AuthSendCodeButton.IsEnabled = !_authBusy;
        }
        UpdateAuthLocalizedText();
    }

    private static bool IsValidAuthEmail(string email)
    {
        var at = email.IndexOf('@');
        var dot = email.LastIndexOf('.');
        return at > 0 && dot > at + 1 && dot < email.Length - 1;
    }

    private void AuthEmailBox_KeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key != Key.Enter) return;
        e.Handled = true;
        AuthPasswordBox.Focus();
    }

    private void AuthPasswordBox_KeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key != Key.Enter) return;
        e.Handled = true;
        if (_authRegisterMode && _authCodeRequired)
            AuthCodeBox.Focus();
        else
            AuthSubmit_Click(sender, new RoutedEventArgs());
    }

    private void AuthCodeBox_KeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key != Key.Enter) return;
        e.Handled = true;
        AuthSubmit_Click(sender, new RoutedEventArgs());
    }

    private void MainWindow_PreviewKeyUp(object sender, KeyEventArgs e)
    {
        if (!_bluetoothRemote.Enabled) return;
        var key = e.Key == Key.System ? e.SystemKey : e.Key;
        if (key is Key.VolumeUp or Key.VolumeDown or Key.MediaPlayPause)
        {
            e.Handled = true;
            ShutterButton_Click(this, new RoutedEventArgs());
        }
    }

    private void ConnectButton_Click(object sender, RoutedEventArgs e)
    {
        ShowConnectionDialog();
    }

    private FrameworkElement BuildWifiCameraTransferPanel()
    {
        var hostBox = new TextBox
        {
            Text = "192.168.1.1",
            MinWidth = 280,
            Height = 36,
            Padding = new Thickness(8, 5, 8, 5)
        };
        var portBox = new TextBox
        {
            Text = "15740",
            Width = 86,
            Height = 36,
            Margin = new Thickness(10, 0, 0, 0),
            Padding = new Thickness(8, 5, 8, 5)
        };
        var status = new TextBlock
        {
            Text = AppLocalization.T(_wifiCamera.Status),
            Foreground = (Brush)FindResource("MutedBrush")
        };
        var button = new Button
        {
            Content = AppLocalization.T(_wifiCamera.IsConnected ? "断开" : "连接"),
            Width = 92,
            Height = 40,
            Style = (Style)FindResource("ButtonBase")
        };
        var content = new StackPanel();
        content.Children.Add(status);
        content.Children.Add(new TextBlock
        {
            Text = AppLocalization.T("连接模式"),
            Margin = new Thickness(0, 10, 0, 4),
            FontSize = 11,
            FontWeight = FontWeights.SemiBold,
            Foreground = (Brush)FindResource("MutedBrush")
        });
        var mode = new ComboBox
        {
            MinWidth = 280,
            Height = 36,
            IsEnabled = !_wifiCamera.IsConnected
        };
        mode.Items.Add(new ComboBoxItem
        {
            Content = AppLocalization.T("AP 直连"),
            Tag = "ap"
        });
        mode.Items.Add(new ComboBoxItem
        {
            Content = AppLocalization.T("STA 局域网"),
            Tag = "sta"
        });
        var modeHelp = new TextBlock
        {
            Text = AppLocalization.T(
                "AP 模式：让电脑加入相机热点；相机地址通常为 192.168.1.1。"),
            Margin = new Thickness(0, 6, 0, 0),
            FontSize = 11,
            TextWrapping = TextWrapping.Wrap,
            Foreground = (Brush)FindResource("MutedBrush")
        };
        mode.SelectionChanged += (_, _) =>
        {
            if (mode.SelectedItem is not ComboBoxItem selected) return;
            _wifiConnectionMode = selected.Tag as string == "sta" ? "sta" : "ap";
            SaveWifiConnectionModePreference(_wifiConnectionMode);
            modeHelp.Text = AppLocalization.T(
                _wifiConnectionMode == "sta"
                    ? "STA 模式：让相机与电脑加入同一局域网，并输入路由器分配给相机的 IP 地址。"
                    : "AP 模式：让电脑加入相机热点；相机地址通常为 192.168.1.1。");
        };
        mode.SelectedIndex = _wifiConnectionMode == "sta" ? 1 : 0;
        content.Children.Add(mode);
        content.Children.Add(modeHelp);

        var endpoint = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            Margin = new Thickness(0, 10, 0, 0)
        };
        endpoint.Children.Add(hostBox);
        endpoint.Children.Add(portBox);
        content.Children.Add(endpoint);

        // ── E3 1.5.9：Wi‑Fi PTP/IP 取景 / 录像 / 参数控制卡 ──
        var wifiControls = new StackPanel
        {
            Margin = new Thickness(0, 14, 0, 0)
        };
        var wifiControlTitle = new TextBlock
        {
            Text = AppLocalization.T("Wi‑Fi 相机控制 · PTP/IP"),
            Margin = new Thickness(0, 0, 0, 6),
            FontSize = 12,
            FontWeight = FontWeights.SemiBold,
            Foreground = (Brush)FindResource("MutedBrush")
        };
        wifiControls.Children.Add(wifiControlTitle);
        var wifiRecord = new Button
        {
            Content = AppLocalization.T("开始录制"),
            Height = 38,
            Margin = new Thickness(0, 6, 0, 0),
            Style = (Style)FindResource("DangerButton")
        };
        wifiRecord.Click += async (_, _) => await ToggleWifiMovieRecordingAsync();
        var wifiLiveView = new Button
        {
            Content = AppLocalization.T("开启实时取景"),
            Height = 38,
            Margin = new Thickness(0, 4, 0, 0),
            Style = (Style)FindResource("ButtonBase")
        };
        wifiLiveView.Click += async (_, _) =>
        {
            if (!_wifiCamera.IsConnected)
            {
                return;
            }
            if (_wifiCamera.IsLiveView)
            {
                await RunOperationAsync("正在停止 Wi‑Fi 实时取景…", async token =>
                {
                    await _wifiCamera.StopLiveViewAsync(token);
                    StopWifiPreviewLoop();
                    UpdateWifiControlState(wifiLiveView, wifiRecord);
                });
            }
            else
            {
                await RunOperationAsync("正在开启 Wi‑Fi 实时取景…", async token =>
                {
                    await _wifiCamera.StartLiveViewAsync(token);
                    StartWifiPreviewLoop();
                    UpdateWifiControlState(wifiLiveView, wifiRecord);
                });
            }
        };
        wifiControls.Children.Add(wifiLiveView);
        wifiControls.Children.Add(wifiRecord);
        var wifiParamReadout = new TextBlock
        {
            Text = AppLocalization.T("参数待读取 · 连接后自动刷新"),
            Margin = new Thickness(0, 10, 0, 0),
            FontSize = 12,
            FontFamily = (FontFamily)FindResource("MonoFont"),
            Foreground = (Brush)FindResource("MutedBrush")
        };
        WifiParameterReadout = wifiParamReadout;
        wifiControls.Children.Add(wifiParamReadout);
        wifiControls.Children.Add(WifiStepperRow(
            "ISO", () => StepWifiIsoAsync(-1), () => StepWifiIsoAsync(1)));
        wifiControls.Children.Add(WifiStepperRow(
            "光圈", () => StepWifiApertureAsync(-1), () => StepWifiApertureAsync(1)));
        wifiControls.Children.Add(WifiStepperRow(
            "快门", () => StepWifiShutterAsync(-1), () => StepWifiShutterAsync(1)));
        wifiControls.Visibility = Visibility.Collapsed;
        content.Children.Add(wifiControls);

        void UpdateWifiControlState(Button liveViewButton, Button recordButton)
        {
            var connected = _wifiCamera.IsConnected;
            wifiControls.Visibility = connected
                ? Visibility.Visible : Visibility.Collapsed;
            liveViewButton.Content = AppLocalization.T(
                _wifiCamera.IsLiveView ? "停止实时取景" : "开启实时取景");
            liveViewButton.IsEnabled = connected;
            recordButton.IsEnabled = connected &&
                (_wifiCamera.Vendor == PtpIpCamera.CameraVendor.Nikon ||
                 _wifiCamera.Vendor == PtpIpCamera.CameraVendor.Canon);
            UpdateWifiParameterReadout();
        }
        UpdateWifiControlState(wifiLiveView, wifiRecord);

        button.Click += async (_, _) =>
        {
            button.IsEnabled = false;
            mode.IsEnabled = false;
            try
            {
                if (_wifiCamera.IsConnected)
                {
                    StopWifiMonitoring();
                    StopWifiPreviewLoop();
                    await _wifiCamera.DisconnectAsync();
                    _lastConnectionError = null;
                }
                else
                {
                    if (!int.TryParse(portBox.Text, out var port))
                    {
                        throw new ArgumentException("Wi‑Fi 相机端口无效");
                    }
                    _wifiHost = hostBox.Text.Trim();
                    _wifiPort = port;
                    _wifiManualDisconnect = false;
                    _wifiReconnecting = false;
                    _wifiReconnectAttempt = 0;
                    _wifiMissedHeartbeats = 0;
                    using var timeout = new CancellationTokenSource(
                        TimeSpan.FromSeconds(12));
                    await _wifiCamera.ConnectAsync(
                        _wifiHost, _wifiPort, timeout.Token);
                    // E3 1.5.9：识别厂商（GetDeviceInfo 0x1001 + 名称启发式）；
                    // 尼康/佳能自动开实时取景并拉帧（约 10fps），刷新参数。
                    await _wifiCamera.DetectVendorAsync(timeout.Token);
                    if (_wifiCamera.Vendor != PtpIpCamera.CameraVendor.Unknown)
                    {
                        await _wifiCamera.StartLiveViewAsync(timeout.Token);
                        StartWifiPreviewLoop();
                        await RefreshWifiParametersAsync();
                    }
                    _lastConnectionError = null;
                    _diagnostics.Info(
                        "wifi-camera",
                        $"PTP/IP 已连接；模式={_wifiConnectionMode.ToUpperInvariant()}；" +
                        $"相机={_wifiCamera.CameraName}；厂商={_wifiCamera.Vendor}");
                    StartWifiMonitoring();
                }
            }
            catch (Exception error)
            {
                _lastConnectionError = error.Message;
                ShowError(error.Message);
            }
            status.Text = _wifiCamera.IsConnected
                ? $"{_wifiConnectionMode.ToUpperInvariant()} · {AppLocalization.T(_wifiCamera.Status)}"
                : AppLocalization.T(_wifiCamera.Status);
            button.Content = AppLocalization.T(
                _wifiCamera.IsConnected ? "断开" : "连接");
            button.IsEnabled = true;
            mode.IsEnabled = !_wifiCamera.IsConnected;
            UpdateWifiControlState(wifiLiveView, wifiRecord);
            UpdateConnectionSummary();
            UpdateEnabledState();
            UpdateExposureReadout();
        };

        return ConnectionCard("Wi‑Fi 相机 · PTP/IP", content, button);
    }

    /// <summary>E3 1.5.9：Wi‑Fi 参数步进行（标题 + 减/加按钮）。</summary>
    private FrameworkElement WifiStepperRow(
        string title,
        Func<Task> decrease,
        Func<Task> increase)
    {
        var minus = new Button
        {
            Content = "−",
            Width = 30,
            Height = 30,
            Style = (Style)FindResource("ButtonBase")
        };
        minus.Click += async (_, _) => await decrease();
        var plus = new Button
        {
            Content = "+",
            Width = 30,
            Height = 30,
            Style = (Style)FindResource("ButtonBase")
        };
        plus.Click += async (_, _) => await increase();
        var row = new DockPanel
        {
            Margin = new Thickness(0, 6, 0, 0)
        };
        DockPanel.SetDock(plus, Dock.Right);
        DockPanel.SetDock(minus, Dock.Right);
        row.Children.Add(plus);
        row.Children.Add(minus);
        row.Children.Add(new TextBlock
        {
            Text = AppLocalization.T(title),
            VerticalAlignment = VerticalAlignment.Center,
            FontSize = 12
        });
        return row;
    }

    // ── B2 WiFi 连接监看：心跳 / 退避重连 / 网络监听 ──

    private void StartWifiMonitoring()
    {
        _wifiHeartbeatTimer.Tick -= WifiHeartbeatTimer_Tick;
        _wifiHeartbeatTimer.Tick += WifiHeartbeatTimer_Tick;
        _wifiHeartbeatTimer.Start();
        System.Net.NetworkInformation.NetworkChange
            .NetworkAvailabilityChanged -= OnNetworkAvailabilityChanged;
        System.Net.NetworkInformation.NetworkChange
            .NetworkAvailabilityChanged += OnNetworkAvailabilityChanged;
    }

    private void StopWifiMonitoring()
    {
        _wifiHeartbeatTimer.Stop();
        _wifiReconnectCts?.Cancel();
        _wifiReconnectCts = null;
        System.Net.NetworkInformation.NetworkChange
            .NetworkAvailabilityChanged -= OnNetworkAvailabilityChanged;
    }

    // ── E3 1.5.9：Wi‑Fi PTP/IP 实时取景 / 参数 / 录像 ──

    private void StartWifiPreviewLoop()
    {
        StopWifiPreviewLoop();
        _wifiPreviewCancellation = new CancellationTokenSource();
        _wifiPreviewTask = WifiPreviewLoopAsync(
            _wifiPreviewCancellation.Token);
    }

    private void StopWifiPreviewLoop()
    {
        _wifiPreviewCancellation?.Cancel();
        _wifiPreviewCancellation?.Dispose();
        _wifiPreviewCancellation = null;
        _wifiPreviewTask = null;
    }

    private async Task WifiPreviewLoopAsync(CancellationToken cancellationToken)
    {
        var failures = 0;
        while (!cancellationToken.IsCancellationRequested &&
               _wifiCamera.IsConnected && _wifiCamera.IsLiveView)
        {
            try
            {
                var jpeg = await _wifiCamera.GetLiveViewFrameAsync(
                    cancellationToken);
                failures = 0;
                var prepared = await Task.Run(
                    () => PrepareJpeg(
                        jpeg,
                        _videoMode,
                        false,
                        false,
                        _videoRecording,
                        _monitorNikonCloudPreset),
                    cancellationToken);
                await Dispatcher.InvokeAsync(
                    () => DisplayWifiPreparedPreview(prepared));
            }
            catch (OperationCanceledException)
            {
                break;
            }
            catch (Exception error)
            {
                failures++;
                _diagnostics.Warning(
                    "wifi-liveview",
                    $"获取 Wi‑Fi 实时取景帧失败（{failures}/3）：{error.Message}");
                if (failures >= 3)
                {
                    _diagnostics.Warning(
                        "wifi-liveview",
                        "连续 3 次未收到 Wi‑Fi 实时取景画面，已停止重试。");
                    break;
                }
                try
                {
                    await Task.Delay(600, cancellationToken);
                }
                catch (OperationCanceledException)
                {
                    break;
                }
            }
        }
    }

    private void DisplayWifiPreparedPreview(PreparedPreview prepared)
    {
        _lastPreviewSource = prepared.Source;
        PreviewImage.Source = prepared.Display;
        MonitorPreviewImage.Source = prepared.Display;
        MonitorPreviewEmpty.Visibility = Visibility.Collapsed;
        MonitorCameraOverlay.Text =
            $"{_wifiCamera.CameraName} · {_wifiConnectionMode.ToUpperInvariant()} · WI‑FI/PTP‑IP";
        MonitorRgbScope.SetData(
            prepared.Monitor.RedHistogram,
            prepared.Monitor.GreenHistogram,
            prepared.Monitor.BlueHistogram);
        _immersiveScope?.SetData(
            prepared.Monitor.RedHistogram,
            prepared.Monitor.GreenHistogram,
            prepared.Monitor.BlueHistogram);
        if (_immersivePreviewImage is not null)
        {
            _immersivePreviewImage.Source = prepared.Display;
        }
        UpdateLiveViewState();
    }

    /// <summary>
    /// 从 Wi‑Fi 相机读取 ISO/光圈/快门并缓存到本地字段（单属性失败不阻断其余）。
    /// </summary>
    private async Task RefreshWifiParametersAsync()
    {
        if (!_wifiCamera.IsConnected)
        {
            return;
        }
        try
        {
            var isoData = await _wifiCamera.ReadPropertyAsync(0x500f);
            _wifiIso = isoData.Length >= 2
                ? BinaryPrimitives.ReadUInt16LittleEndian(isoData)
                : (ushort)0;
        }
        catch (Exception error)
        {
            _diagnostics.Warning(
                "wifi-params", $"读取 Wi‑Fi ISO 失败：{error.Message}");
        }
        try
        {
            var fNumberData = await _wifiCamera.ReadPropertyAsync(0x5007);
            if (fNumberData.Length >= 2)
            {
                _wifiAperture = BinaryPrimitives.ReadUInt16LittleEndian(
                    fNumberData) / 100.0;
            }
        }
        catch (Exception error)
        {
            _diagnostics.Warning(
                "wifi-params", $"读取 Wi‑Fi 光圈失败：{error.Message}");
        }
        try
        {
            var shutterData = await _wifiCamera.ReadPropertyAsync(0x500d);
            if (shutterData.Length >= 4)
            {
                _wifiShutterSeconds = BinaryPrimitives.ReadUInt32LittleEndian(
                    shutterData) / 10000.0;
            }
        }
        catch (Exception error)
        {
            _diagnostics.Warning(
                "wifi-params", $"读取 Wi‑Fi 快门失败：{error.Message}");
        }
        await Dispatcher.InvokeAsync(UpdateWifiParameterReadout);
    }

    private void UpdateWifiParameterReadout()
    {
        if (WifiParameterReadout is null)
        {
            return;
        }
        var shutter = _wifiShutterSeconds > 0
            ? (_wifiShutterSeconds >= 1
                ? $"{_wifiShutterSeconds:0.##}″"
                : $"1/{Math.Max(1, (int)Math.Round(1 / _wifiShutterSeconds))}")
            : "—";
        var aperture = _wifiAperture > 0
            ? $"f/{_wifiAperture:0.#}"
            : "—";
        WifiParameterReadout.Text = AppLocalization.T(
            $"ISO {(_wifiIso > 0 ? _wifiIso.ToString() : "—")} · {aperture} · {shutter}");
    }

    private async Task StepWifiIsoAsync(int direction)
    {
        if (!_wifiCamera.IsConnected) return;
        var values = new[] { 64, 80, 100, 125, 160, 200, 250, 320, 400, 500,
            640, 800, 1000, 1250, 1600, 2000, 2500, 3200, 4000, 5000, 6400,
            8000, 10000, 12800, 16000, 20000, 25600, 32000, 40000, 51200,
            64000, 102400 };
        var currentIndex = Array.FindIndex(values, v => v >= _wifiIso);
        if (currentIndex < 0) currentIndex = 0;
        var next = Math.Clamp(currentIndex + direction, 0, values.Length - 1);
        var payload = new byte[2];
        BinaryPrimitives.WriteUInt16LittleEndian(
            payload, (ushort)values[next]);
        await RunOperationAsync(
            $"正在写入 Wi‑Fi ISO {values[next]}…",
            async token =>
            {
                await _wifiCamera.WritePropertyAsync(0x500f, payload, token);
                await RefreshWifiParametersAsync();
            });
    }

    private async Task StepWifiApertureAsync(int direction)
    {
        if (!_wifiCamera.IsConnected) return;
        var values = new[] { 1.4, 1.6, 1.8, 2.0, 2.2, 2.5, 2.8, 3.2, 3.5,
            4.0, 4.5, 5.0, 5.6, 6.3, 7.1, 8.0, 9.0, 10.0, 11.0, 13.0, 14.0,
            16.0, 18.0, 20.0, 22.0 };
        var currentIndex = Array.FindIndex(
            values, v => v >= _wifiAperture - 0.01);
        if (currentIndex < 0) currentIndex = 0;
        var next = Math.Clamp(currentIndex + direction, 0, values.Length - 1);
        var payload = new byte[2];
        BinaryPrimitives.WriteUInt16LittleEndian(
            payload, (ushort)(values[next] * 100));
        await RunOperationAsync(
            $"正在写入 Wi‑Fi 光圈 f/{values[next]:0.#}…",
            async token =>
            {
                await _wifiCamera.WritePropertyAsync(0x5007, payload, token);
                await RefreshWifiParametersAsync();
            });
    }

    private async Task StepWifiShutterAsync(int direction)
    {
        if (!_wifiCamera.IsConnected) return;
        // E3 遗留缺陷修复（pro 已裁定属实）：旧实现用降序分母 +
        // Array.FindIndex(1.0/d <= seconds) 恒命中首档 d=8000，无法步进。
        // 现改为升序秒值阶梯 + firstAtLeast，与 E4 Android/Harmony 同构。
        var ladder = new[]
        {
            1.0 / 8000, 1.0 / 4000, 1.0 / 2000, 1.0 / 1000,
            1.0 / 500, 1.0 / 250, 1.0 / 125, 1.0 / 60,
            1.0 / 30, 1.0 / 15, 1.0 / 8, 1.0 / 4, 1.0 / 2, 1.0
        };
        var currentIndex = FirstAtLeast(ladder, _wifiShutterSeconds - 0.00001);
        var next = Math.Clamp(
            currentIndex + direction, 0, ladder.Length - 1);
        var seconds = ladder[next];
        var payload = new byte[4];
        BinaryPrimitives.WriteUInt32LittleEndian(
            payload, (uint)(seconds * 10000));
        await RunOperationAsync(
            seconds >= 1
                ? $"正在写入 Wi‑Fi 快门 {seconds:0.#}″…"
                : $"正在写入 Wi‑Fi 快门 1/{1.0 / seconds:0}…",
            async token =>
            {
                await _wifiCamera.WritePropertyAsync(0x500d, payload, token);
                await RefreshWifiParametersAsync();
            });
    }

    /// <summary>升序阶梯中第一个 ≥ value 的下标（无则返回末位）。</summary>
    private static int FirstAtLeast(IReadOnlyList<double> ladder, double value)
    {
        for (var i = 0; i < ladder.Count; i++)
        {
            if (ladder[i] >= value)
            {
                return i;
            }
        }
        return ladder.Count - 1;
    }

    /// <summary>Wi‑Fi 录像开关（Nikon 0x920a/0x920b；Canon EVFRecordStatus，TBC）。</summary>
    private async Task ToggleWifiMovieRecordingAsync()
    {
        if (!_wifiCamera.IsConnected)
        {
            return;
        }
        if (_wifiCamera.IsMovieRecording)
        {
            await RunOperationAsync("正在停止 Wi‑Fi 录像…", async token =>
            {
                await _wifiCamera.StopMovieRecordingAsync(token);
                _videoRecording = false;
                _recordingStartedAt = null;
                OperationStatusText.Text = AppLocalization.T(
                    "Wi‑Fi 录像已停止 · 文件保存在相机卡内");
            });
        }
        else
        {
            if (_wifiCamera.Vendor != PtpIpCamera.CameraVendor.Nikon &&
                _wifiCamera.Vendor != PtpIpCamera.CameraVendor.Canon)
            {
                ShowError("已连相机暂不支持 PTP/IP 远程录像");
                return;
            }
            await RunOperationAsync("正在开始 Wi‑Fi 录像…", async token =>
            {
                await _wifiCamera.StartMovieRecordingAsync(token);
                _videoRecording = true;
                _recordingStartedAt = DateTime.Now;
                OperationStatusText.Text = AppLocalization.T(
                    "Wi‑Fi 录像中 · 文件保存在相机卡内");
            });
        }
        UpdateRecordingState();
    }

    private async void WifiHeartbeatTimer_Tick(object? sender, EventArgs e)
    {
        if (!_wifiCamera.IsConnected || _wifiReconnecting ||
            _wifiManualDisconnect)
        {
            return;
        }
        bool alive;
        try
        {
            await _wifiCamera.ProbeAsync();
            alive = true;
        }
        catch
        {
            alive = false;
        }
        if (!_wifiCamera.IsConnected || _wifiManualDisconnect)
        {
            return;
        }
        if (alive)
        {
            _wifiMissedHeartbeats = 0;
        }
        else
        {
            _wifiMissedHeartbeats++;
            if (_wifiMissedHeartbeats >= 3)
            {
                _wifiMissedHeartbeats = 0;
                EnterWifiReconnecting();
            }
        }
    }

    private void EnterWifiReconnecting()
    {
        if (!_wifiCamera.IsConnected || _wifiReconnecting ||
            _wifiManualDisconnect)
        {
            return;
        }
        _wifiReconnecting = true;
        _wifiReconnectAttempt = 0;
        _wifiHeartbeatTimer.Stop();
        _diagnostics.Info(
            "wifi-camera",
            "Wi‑Fi 链路已断开，进入自动重连");
        UpdateConnectionSummary();
        UpdateControlStatusRow();
        ScheduleWifiReconnect();
    }

    private void ScheduleWifiReconnect()
    {
        if (!_wifiReconnecting || _wifiManualDisconnect)
        {
            return;
        }
        _wifiReconnectAttempt++;
        var delay = WifiBackoffDelayMs(_wifiReconnectAttempt);
        _wifiReconnectCts?.Cancel();
        var cts = new CancellationTokenSource();
        _wifiReconnectCts = cts;
        _diagnostics.Info(
            "wifi-camera",
            $"调度自动重连（第 {_wifiReconnectAttempt} 次，退避 {delay}ms）");
        _ = ReconnectAfterDelayAsync(delay, cts.Token);
    }

    private async Task ReconnectAfterDelayAsync(
        int delayMs,
        CancellationToken token)
    {
        try
        {
            await Task.Delay(delayMs, token);
        }
        catch (OperationCanceledException)
        {
            return;
        }
        await AttemptWifiReconnectAsync(token);
    }

    private async Task AttemptWifiReconnectAsync(CancellationToken token)
    {
        if (!_wifiReconnecting || _wifiManualDisconnect)
        {
            return;
        }
        UpdateControlStatusRow();
        try
        {
            await _wifiCamera.ConnectAsync(_wifiHost, _wifiPort, token);
            _wifiReconnecting = false;
            _wifiReconnectAttempt = 0;
            _lastConnectionError = null;
            _diagnostics.Info(
                "wifi-camera",
                $"PTP/IP 自动重连成功；相机={_wifiCamera.CameraName}");
            // E3 1.5.9：重连成功后恢复厂商识别、取景与参数（对齐 iOS 重连路径）。
            await _wifiCamera.DetectVendorAsync(token);
            if (_wifiCamera.Vendor != PtpIpCamera.CameraVendor.Unknown)
            {
                await _wifiCamera.StartLiveViewAsync(token);
                StartWifiPreviewLoop();
                await RefreshWifiParametersAsync();
            }
            StartWifiMonitoring();
            UpdateConnectionSummary();
            UpdateControlStatusRow();
        }
        catch
        {
            if (!_wifiReconnecting || _wifiManualDisconnect)
            {
                return;
            }
            ScheduleWifiReconnect();
        }
    }

    /// <summary>NetworkAvailabilityChanged：网络丢失即判链路不可用。</summary>
    private void OnNetworkAvailabilityChanged(
        object? sender,
        System.Net.NetworkInformation.NetworkAvailabilityEventArgs e)
    {
        if (e.IsAvailable)
        {
            return;
        }
        Dispatcher.Invoke(() =>
        {
            if (_wifiCamera.IsConnected && !_wifiManualDisconnect)
            {
                EnterWifiReconnecting();
            }
        });
    }

    private FrameworkElement BuildCaptureAssistSettingsPanel()
    {
        var root = new StackPanel();
        root.Children.Add(new TextBlock
        {
            Text = AppLocalization.T("拍摄辅助"),
            Style = (Style)FindResource("SettingsCardTitle")
        });
        root.Children.Add(new TextBlock
        {
            Text = AppLocalization.T("蓝牙遥控与拍摄定位"),
            Margin = new Thickness(0, 4, 0, 14),
            Foreground = (Brush)FindResource("MutedBrush")
        });

        var bluetoothStatus = new TextBlock
        {
            Text = AppLocalization.T(_bluetoothRemote.Status),
            Style = (Style)FindResource("SettingsFeedbackBody")
        };
        var bluetoothBody = new StackPanel();
        bluetoothBody.Children.Add(new TextBlock
        {
            Text = AppLocalization.T("蓝牙遥控拍摄"),
            FontWeight = FontWeights.SemiBold
        });
        bluetoothBody.Children.Add(bluetoothStatus);
        bluetoothBody.Children.Add(new TextBlock
        {
            Text = AppLocalization.T(
                "兼容 ZENCHE BLE Remote 服务；遥控器发出快门通知后，将触发当前已连接相机。"),
            Margin = new Thickness(0, 4, 0, 0),
            Style = (Style)FindResource("SettingsHint"),
            TextWrapping = TextWrapping.Wrap
        });
        var bluetoothToggle = new CheckBox
        {
            Content = AppLocalization.T("启用"),
            IsChecked = _bluetoothRemote.Enabled,
            VerticalAlignment = VerticalAlignment.Center
        };
        bluetoothToggle.Checked += (_, _) =>
        {
            try { _bluetoothRemote.Start(); }
            catch (Exception error) { ShowError(error.Message); }
            bluetoothStatus.Text = AppLocalization.T(_bluetoothRemote.Status);
        };
        bluetoothToggle.Unchecked += (_, _) =>
        {
            _bluetoothRemote.Stop();
            bluetoothStatus.Text = AppLocalization.T(_bluetoothRemote.Status);
        };
        var bluetoothRow = new Grid();
        bluetoothRow.ColumnDefinitions.Add(new ColumnDefinition());
        bluetoothRow.ColumnDefinitions.Add(new ColumnDefinition
        {
            Width = GridLength.Auto
        });
        bluetoothRow.Children.Add(bluetoothBody);
        Grid.SetColumn(bluetoothToggle, 1);
        bluetoothToggle.Margin = new Thickness(16, 0, 0, 0);
        bluetoothRow.Children.Add(bluetoothToggle);
        root.Children.Add(bluetoothRow);

        root.Children.Add(new Border
        {
            Height = 1,
            Margin = new Thickness(0, 14, 0, 14),
            Background = (Brush)FindResource("RuleBrush")
        });

        var locationStatus = new TextBlock
        {
            Text = AppLocalization.T(_locationTagging.Status),
            Style = (Style)FindResource("SettingsFeedbackBody")
        };
        var locationBody = new StackPanel();
        locationBody.Children.Add(new TextBlock
        {
            Text = AppLocalization.T("拍摄位置"),
            FontWeight = FontWeights.SemiBold
        });
        locationBody.Children.Add(locationStatus);
        locationBody.Children.Add(new TextBlock
        {
            Text = AppLocalization.T(
                "仅在应用使用期间定位；下载的照片会生成包含 GPS 信息的标准 XMP 旁车文件。"),
            Margin = new Thickness(0, 4, 0, 0),
            Style = (Style)FindResource("SettingsHint"),
            TextWrapping = TextWrapping.Wrap
        });
        var locationToggle = new CheckBox
        {
            Content = AppLocalization.T("启用"),
            IsChecked = _locationTagging.Enabled,
            VerticalAlignment = VerticalAlignment.Center
        };
        locationToggle.Checked += async (_, _) =>
        {
            await _locationTagging.SetEnabledAsync(true);
            locationStatus.Text = AppLocalization.T(_locationTagging.Status);
            locationToggle.IsChecked = _locationTagging.Enabled;
        };
        locationToggle.Unchecked += async (_, _) =>
        {
            await _locationTagging.SetEnabledAsync(false);
            locationStatus.Text = AppLocalization.T(_locationTagging.Status);
        };
        var locationRow = new Grid();
        locationRow.ColumnDefinitions.Add(new ColumnDefinition());
        locationRow.ColumnDefinitions.Add(new ColumnDefinition
        {
            Width = GridLength.Auto
        });
        locationRow.Children.Add(locationBody);
        Grid.SetColumn(locationToggle, 1);
        locationToggle.Margin = new Thickness(16, 0, 0, 0);
        locationRow.Children.Add(locationToggle);
        root.Children.Add(locationRow);

        root.Children.Add(new Border
        {
            Height = 1,
            Margin = new Thickness(0, 14, 0, 14),
            Background = (Brush)FindResource("RuleBrush")
        });

        // ── E5 1.5.9：live 图（取景帧环形缓冲 + 快门切片配对）──
        var livePhotoBody = new StackPanel();
        livePhotoBody.Children.Add(new TextBlock
        {
            Text = AppLocalization.T("Live 图"),
            FontWeight = FontWeights.SemiBold
        });
        livePhotoBody.Children.Add(new TextBlock
        {
            Text = AppLocalization.T("快门时附带最近几秒取景切片"),
            Margin = new Thickness(0, 4, 0, 0),
            Style = (Style)FindResource("SettingsHint"),
            TextWrapping = TextWrapping.Wrap
        });
        var livePhotoToggle = new CheckBox
        {
            Content = AppLocalization.T("启用"),
            IsChecked = _livePhotoEnabled,
            VerticalAlignment = VerticalAlignment.Center
        };
        var livePhotoSecondsBox = new ComboBox
        {
            IsEnabled = _livePhotoEnabled,
            MinWidth = 72
        };
        foreach (var seconds in new[] { 1, 3, 5, 10, 15 })
        {
            livePhotoSecondsBox.Items.Add(new ComboBoxItem
            {
                Content = AppLocalization.T(
                    seconds == 1 ? "1 秒" : $"{seconds} 秒"),
                Tag = seconds
            });
        }
        livePhotoSecondsBox.SelectedIndex =
            Math.Max(0, new[] { 1, 3, 5, 10, 15 }.ToList()
                .IndexOf((int)Math.Round(_livePhotoSeconds)));
        livePhotoToggle.Checked += (_, _) =>
        {
            _livePhotoEnabled = true;
            SaveLivePhotoPreference(true);
            livePhotoSecondsBox.IsEnabled = true;
            SyncLivePhotoRing();
            OperationStatusText.Text = AppLocalization.T(
                $"live 图已开启 · 快门将附带最近 {Math.Round(_livePhotoSeconds)} 秒取景切片");
        };
        livePhotoToggle.Unchecked += (_, _) =>
        {
            _livePhotoEnabled = false;
            SaveLivePhotoPreference(false);
            livePhotoSecondsBox.IsEnabled = false;
            SyncLivePhotoRing();
            OperationStatusText.Text = AppLocalization.T("live 图已关闭");
        };
        livePhotoSecondsBox.SelectionChanged += (_, _) =>
        {
            if (livePhotoSecondsBox.SelectedItem is not ComboBoxItem item ||
                item.Tag is not int seconds)
            {
                return;
            }
            _livePhotoSeconds = seconds;
            SaveLivePhotoSecondsPreference(seconds);
            if (_livePhotoClipRecorder.IsArmed)
            {
                _livePhotoClipRecorder.Arm(
                    Math.Max(4, (int)Math.Round(_videoFrameRate)),
                    _livePhotoSeconds);
            }
            OperationStatusText.Text = AppLocalization.T(
                $"live 图切片时长已设为 {seconds} 秒");
        };
        var livePhotoRow = new Grid();
        livePhotoRow.ColumnDefinitions.Add(new ColumnDefinition());
        livePhotoRow.ColumnDefinitions.Add(new ColumnDefinition
        {
            Width = GridLength.Auto
        });
        livePhotoRow.Children.Add(livePhotoBody);
        var livePhotoControls = new StackPanel
        {
            Orientation = Orientation.Horizontal
        };
        livePhotoControls.Children.Add(livePhotoSecondsBox);
        livePhotoControls.Children.Add(livePhotoToggle);
        Grid.SetColumn(livePhotoControls, 1);
        livePhotoControls.Margin = new Thickness(16, 0, 0, 0);
        livePhotoRow.Children.Add(livePhotoControls);
        root.Children.Add(livePhotoRow);

        return new Border
        {
            Padding = new Thickness(18),
            Background = (Brush)FindResource("SurfaceBrush"),
            BorderBrush = (Brush)FindResource("RuleBrush"),
            BorderThickness = new Thickness(1),
            CornerRadius = (CornerRadius)FindResource("CornerRadius12"),
            Child = root
        };
    }

    private async Task ToggleUsbConnectionAsync()
    {
        if (_operationInProgress)
        {
            return;
        }
        if (_camera.IsConnected)
        {
            await RunOperationAsync("正在断开相机…", async token =>
            {
                await FinishExternalRecordingForDisconnectAsync();
                await StopPreviewLoopAsync();
                await _camera.DisconnectAsync(token);
                SetConnectionState(null);
                OperationStatusText.Text =
                    AppLocalization.T("相机已断开");
            }, connectionAttempt: true);
            return;
        }

        await RunOperationAsync("正在连接相机…", async token =>
        {
            var profile = await _camera.ConnectAsync(token);
            SetConnectionState(profile);
            RememberConnectedDevice(profile);
            OperationStatusText.Text =
                AppLocalization.T($"{profile.Name} 已连接");
        }, connectionAttempt: true);
    }

    private async Task ToggleLocalCameraConnectionAsync()
    {
        if (_operationInProgress) return;
        if (_localCamera.IsConnected)
        {
            await RunOperationAsync("正在断开本机摄像头…", async _ =>
            {
                await FinishExternalRecordingForDisconnectAsync();
                await StopPreviewLoopAsync();
                await _localCamera.DisconnectAsync();
                PreviewImage.Source = null;
                PreviewEmpty.Visibility = Visibility.Visible;
                OperationStatusText.Text = AppLocalization.T("本机摄像头已断开");
            }, connectionAttempt: true);
        }
        else
        {
            await RunOperationAsync("正在连接本机摄像头…", async token =>
            {
                if (_camera.IsConnected)
                {
                    await FinishExternalRecordingForDisconnectAsync();
                    await StopPreviewLoopAsync();
                    await _camera.DisconnectAsync(token);
                    SetConnectionState(null);
                }
                if (_wifiCamera.IsConnected)
                {
                    await _wifiCamera.DisconnectAsync();
                }
                await _localCamera.ConnectAsync(token);
                RememberLocalCamera(_localCamera.DeviceName);
                OperationStatusText.Text = AppLocalization.T(
                    $"{_localCamera.DeviceName} 已连接");
            }, connectionAttempt: true);
        }
        UpdateConnectionSummary();
        UpdateEnabledState();
        UpdateLiveViewState();
        UpdateExposureReadout();
        RefreshRememberedDevices();
    }

    private void ShowConnectionDialog()
    {
        var panel = new StackPanel { Margin = new Thickness(24) };
        panel.Children.Add(new TextBlock
        {
            Text = AppLocalization.T("相机连接"),
            FontSize = 24,
            FontWeight = FontWeights.Bold,
            Foreground = (Brush)FindResource("InkBrush")
        });
        panel.Children.Add(new TextBlock
        {
            Text = AppLocalization.T("本机摄像头、USB/PTP 与官方 SDK"),
            Margin = new Thickness(0, 4, 0, 18),
            Foreground = (Brush)FindResource("MutedBrush")
        });

        var sdkSummary = new TextBlock
        {
            Foreground = (Brush)FindResource("MutedBrush"),
            TextWrapping = TextWrapping.Wrap
        };
        var sdkRemote = new TextBlock
        {
            Margin = new Thickness(0, 7, 0, 0),
            FontSize = 11,
            Foreground = (Brush)FindResource("MutedBrush"),
            TextWrapping = TextWrapping.Wrap
        };
        var sdkImage = new TextBlock
        {
            Margin = new Thickness(0, 4, 0, 0),
            FontSize = 11,
            Foreground = (Brush)FindResource("MutedBrush"),
            TextWrapping = TextWrapping.Wrap
        };
        var sdkDevices = new TextBlock
        {
            Margin = new Thickness(0, 5, 0, 0),
            FontSize = 11,
            Foreground = (Brush)FindResource("MutedBrush"),
            TextWrapping = TextWrapping.Wrap
        };
        var sdkContent = new StackPanel();
        sdkContent.Children.Add(sdkSummary);
        sdkContent.Children.Add(sdkRemote);
        sdkContent.Children.Add(sdkImage);
        sdkContent.Children.Add(sdkDevices);
        var sdkRefresh = new Button
        {
            Content = AppLocalization.T("重新检测"),
            Width = 92,
            Height = 40,
            Style = (Style)FindResource("ButtonBase")
        };
        void UpdateSdkCard()
        {
            var status = _nikonOfficialSdk.Status;
            sdkSummary.Text = AppLocalization.T(status.Summary);
            sdkRemote.Text = $"Remote SDK 2.0.0 · {AppLocalization.T(status.RemoteDetail)}";
            sdkImage.Text = $"Image SDK 1.46.0 · {AppLocalization.T(status.ImageDetail)}";
            sdkDevices.Text = status.Devices.Count == 0
                ? ""
                : string.Join(
                    "\n",
                    status.Devices.Select(device =>
                        $"▣ {device.Name} · " +
                        AppLocalization.T(device.Available ? "可连接" : "正被占用")));
            sdkRefresh.ToolTip = _camera.IsConnected
                ? AppLocalization.T("断开当前 USB 会话后可重新检测")
                : null;
        }
        UpdateSdkCard();
        sdkRefresh.Click += async (_, _) =>
        {
            sdkRefresh.IsEnabled = false;
            await RefreshNikonOfficialSdkAsync(
                allowRemoteProbe: !_camera.IsConnected);
            UpdateSdkCard();
            sdkRefresh.IsEnabled = true;
        };
        panel.Children.Add(ConnectionCard(
            "尼康官方 SDK",
            sdkContent,
            sdkRefresh));

        var sonySummary = new TextBlock
        {
            Foreground = (Brush)FindResource("MutedBrush"),
            TextWrapping = TextWrapping.Wrap
        };
        var sonyDetail = new TextBlock
        {
            Margin = new Thickness(0, 7, 0, 0),
            FontSize = 11,
            Foreground = (Brush)FindResource("MutedBrush"),
            TextWrapping = TextWrapping.Wrap
        };
        var sonyDevices = new TextBlock
        {
            Margin = new Thickness(0, 5, 0, 0),
            FontSize = 11,
            Foreground = (Brush)FindResource("MutedBrush"),
            TextWrapping = TextWrapping.Wrap
        };
        var sonyNotice = new TextBlock
        {
            Text = AppLocalization.T(
                "连接即表示同意索尼 SDK 使用限制；帧澈独立提供产品支持。"),
            Margin = new Thickness(0, 6, 0, 0),
            Style = (Style)FindResource("DialogHint"),
            TextWrapping = TextWrapping.Wrap
        };
        var sonyContent = new StackPanel();
        sonyContent.Children.Add(sonySummary);
        sonyContent.Children.Add(sonyDetail);
        sonyContent.Children.Add(sonyDevices);
        sonyContent.Children.Add(sonyNotice);
        var sonyRefresh = new Button
        {
            Content = AppLocalization.T("重新检测"),
            Width = 92,
            Height = 40,
            Style = (Style)FindResource("ButtonBase")
        };
        void UpdateSonySdkCard()
        {
            var status = _sonyOfficialSdk.Status;
            sonySummary.Text = AppLocalization.T(status.Summary);
            sonyDetail.Text =
                $"Camera Remote SDK 2.02.00 · {AppLocalization.T(status.Detail)}";
            sonyDevices.Text = status.Devices.Count == 0
                ? ""
                : string.Join("\n", status.Devices.Select(device => $"▣ {device}"));
            sonyRefresh.ToolTip = _camera.IsConnected
                ? AppLocalization.T("断开当前 USB 会话后可重新检测")
                : null;
        }
        UpdateSonySdkCard();
        sonyRefresh.Click += async (_, _) =>
        {
            sonyRefresh.IsEnabled = false;
            await RefreshSonyOfficialSdkAsync(
                allowEnumeration: !_camera.IsConnected);
            UpdateSonySdkCard();
            sonyRefresh.IsEnabled = true;
        };
        panel.Children.Add(ConnectionCard(
            "索尼官方 SDK",
            sonyContent,
            sonyRefresh));

        var localStatus = new TextBlock
        {
            Text = AppLocalization.T(
                _localCamera.IsConnected
                    ? $"{_localCamera.DeviceName} · 已连接"
                    : "使用电脑内置或外接摄像头取景、拍照并保存到文件库"),
            Foreground = (Brush)FindResource("MutedBrush"),
            TextWrapping = TextWrapping.Wrap
        };
        var localButton = new Button
        {
            Content = AppLocalization.T(_localCamera.IsConnected ? "断开" : "连接"),
            Width = 92,
            Height = 40,
            Style = (Style)FindResource("ButtonBase")
        };
        localButton.Click += async (_, _) =>
        {
            localButton.IsEnabled = false;
            await ToggleLocalCameraConnectionAsync();
            localStatus.Text = AppLocalization.T(
                _localCamera.IsConnected
                    ? $"{_localCamera.DeviceName} · 已连接"
                    : "使用电脑内置或外接摄像头取景、拍照并保存到文件库");
            localButton.Content = AppLocalization.T(
                _localCamera.IsConnected ? "断开" : "连接");
            localButton.IsEnabled = true;
        };
        panel.Children.Add(ConnectionCard(
            "本机摄像头",
            localStatus,
            localButton));

        var usbStatus = new TextBlock
        {
            Text = _camera.IsConnected
                ? $"{_camera.Profile?.Name ?? "相机"} · 已连接"
                : "联机拍摄、参数控制、实时监看和文件传输",
            Foreground = (Brush)FindResource("MutedBrush")
        };
        var usbButton = new Button
        {
            Content = AppLocalization.T(_camera.IsConnected ? "断开" : "连接"),
            Width = 92,
            Height = 40,
            Style = (Style)FindResource("ButtonBase")
        };
        var usbCard = ConnectionCard("USB / PTP", usbStatus, usbButton);
        usbButton.Click += async (_, _) =>
        {
            usbButton.IsEnabled = false;
            await ToggleUsbConnectionAsync();
            usbStatus.Text = _camera.IsConnected
                ? $"{_camera.Profile?.Name ?? "相机"} · 已连接"
                : "联机拍摄、参数控制、实时监看和文件传输";
            usbButton.Content = AppLocalization.T(
                _camera.IsConnected ? "断开" : "连接");
            usbButton.IsEnabled = true;
        };
        panel.Children.Add(usbCard);

        var closeButton = new Button
        {
            Content = AppLocalization.T("关闭"),
            Width = 96,
            Height = 40,
            Margin = new Thickness(0, 18, 0, 0),
            HorizontalAlignment = HorizontalAlignment.Right,
            Style = (Style)FindResource("ButtonBase")
        };
        panel.Children.Add(closeButton);
        var dialog = new Window
        {
            Owner = this,
            Title = "帧澈 ZENCHE · 连接管理",
            Width = 660,
            Height = 680,
            WindowStartupLocation = WindowStartupLocation.CenterOwner,
            ResizeMode = ResizeMode.NoResize,
            Background = (Brush)FindResource("PaperBrush"),
            Content = new ScrollViewer
            {
                VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
                Content = panel
            }
        };
        closeButton.Click += (_, _) => dialog.Close();
        dialog.ShowDialog();
    }

    private async Task RefreshNikonOfficialSdkAsync(bool allowRemoteProbe)
    {
        try
        {
            var status = await Task.Run(() =>
                _nikonOfficialSdk.Probe(allowRemoteProbe));
            _diagnostics.Info(
                "nikon-sdk",
                $"官方 SDK 探测完成；Remote={status.RemoteReady}；" +
                $"Image={status.ImageReady}；Devices={status.Devices.Count}");
        }
        catch (Exception error)
        {
            _diagnostics.Warning(
                "nikon-sdk",
                $"官方 SDK 探测失败：{error.Message}");
        }
    }

    private async Task RefreshSonyOfficialSdkAsync(bool allowEnumeration)
    {
        try
        {
            var status = await Task.Run(() =>
                _sonyOfficialSdk.Probe(allowEnumeration));
            _diagnostics.Info(
                "sony-sdk",
                $"官方 SDK 探测完成；Ready={status.Ready}；" +
                $"Devices={status.Devices.Count}");
        }
        catch (Exception error)
        {
            _diagnostics.Warning(
                "sony-sdk",
                $"官方 SDK 探测失败：{error.Message}");
        }
    }

    private Border ConnectionCard(
        string title,
        UIElement content,
        UIElement action)
    {
        var grid = new Grid();
        grid.ColumnDefinitions.Add(new ColumnDefinition());
        grid.ColumnDefinitions.Add(new ColumnDefinition
        {
            Width = GridLength.Auto
        });
        var body = new StackPanel();
        body.Children.Add(new TextBlock
        {
            Text = AppLocalization.T(title),
            Style = (Style)FindResource("DialogTitle"),
            Foreground = (Brush)FindResource("InkBrush")
        });
        if (content is FrameworkElement element)
        {
            element.Margin = new Thickness(0, 4, 0, 0);
        }
        body.Children.Add(content);
        grid.Children.Add(body);
        Grid.SetColumn(action, 1);
        if (action is FrameworkElement actionElement)
        {
            actionElement.Margin = new Thickness(16, 0, 0, 0);
        }
        grid.Children.Add(action);
        return new Border
        {
            Margin = new Thickness(0, 0, 0, 12),
            Padding = new Thickness(16),
            Background = (Brush)FindResource("SurfaceBrush"),
            BorderBrush = (Brush)FindResource("RuleBrush"),
            BorderThickness = new Thickness(1),
            CornerRadius = (CornerRadius)FindResource("CornerRadius12"),
            Child = grid
        };
    }

    private async void LiveViewButton_Click(object sender, RoutedEventArgs e)
    {
        if (_operationInProgress ||
            (!_camera.IsConnected && !_localCamera.IsConnected &&
             !_wifiCamera.IsConnected))
        {
            return;
        }
        if (_wifiCamera.IsConnected && !_camera.IsConnected && !_localCamera.IsConnected)
        {
            if (_wifiCamera.IsLiveView)
            {
                await RunOperationAsync("正在停止 Wi‑Fi 实时取景…", async token =>
                {
                    await _wifiCamera.StopLiveViewAsync(token);
                    StopWifiPreviewLoop();
                    UpdateLiveViewState();
                });
            }
            else
            {
                await RunOperationAsync("正在开启 Wi‑Fi 实时取景…", async token =>
                {
                    await _wifiCamera.StartLiveViewAsync(token);
                    StartWifiPreviewLoop();
                    UpdateLiveViewState();
                });
            }
            return;
        }
        if (_localCamera.IsConnected)
        {
            if (_localCamera.IsLiveView)
            {
                await RunOperationAsync("正在停止本机摄像头取景…", async _ =>
                {
                    await StopPreviewLoopAsync();
                    await _localCamera.StopLiveViewAsync();
                    UpdateLiveViewState();
                });
            }
            else
            {
                await RunOperationAsync("正在开启本机摄像头取景…", async token =>
                {
                    await _localCamera.StartLiveViewAsync(token);
                    UpdateLiveViewState();
                    StartPreviewLoop();
                });
            }
            return;
        }
        if (_camera.IsLiveView)
        {
            await RunOperationAsync("正在停止实时取景…", async token =>
            {
                await StopPreviewLoopAsync();
                await _camera.StopLiveViewAsync(token);
                UpdateLiveViewState();
            });
            return;
        }
        await RunOperationAsync("正在开启实时取景…", async token =>
        {
            await _camera.StartLiveViewAsync(token);
            UpdateLiveViewState();
            StartPreviewLoop();
        });
    }

    private void FullscreenPreviewButton_Click(
        object sender,
        RoutedEventArgs e)
    {
        if (_immersivePreviewWindow is not null)
        {
            _immersivePreviewWindow.Activate();
            return;
        }
        var viewer = new Window
        {
            Title = _videoMode
                ? "帧澈 ZENCHE · 视频全屏监看"
                : "帧澈 ZENCHE · 照片全屏取景",
            WindowStyle = WindowStyle.None,
            WindowState = WindowState.Maximized,
            ResizeMode = ResizeMode.NoResize,
            Background = Brushes.Black
        };
        _immersivePreviewWindow = viewer;
        var root = new Grid
        {
            Background = Brushes.Black
        };
        var preview = new Image
        {
            Source = PreviewImage.Source,
            Stretch = Stretch.Uniform
        };
        _immersivePreviewImage = preview;
        root.Children.Add(preview);
        root.Children.Add(new Border
        {
            Width = 84,
            Height = 84,
            BorderThickness = new Thickness(2),
            BorderBrush = (Brush)FindResource("AccentBorderBrush"),
            CornerRadius = (CornerRadius)FindResource("CornerRadius5"),
            Background = Brushes.Transparent,
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center,
            IsHitTestVisible = false
        });

        var top = new DockPanel
        {
            Margin = new Thickness(20),
            VerticalAlignment = VerticalAlignment.Top
        };
        var close = new Button
        {
            Content = "⌄ 退出全屏",
            Width = 126,
            Height = 44,
            Style = (Style)FindResource("ButtonBase")
        };
        close.Click += (_, _) => CloseImmersivePreview(viewer);
        DockPanel.SetDock(close, Dock.Left);
        top.Children.Add(close);
        var status = new TextBlock
        {
            Text =
                $"{(_camera.IsLiveView ? "● LIVE" : "● NO SOURCE")} · " +
                $"{_camera.Profile?.Name ?? "Nikon 相机"} · USB/PTP",
            Foreground = Brushes.White,
            FontFamily = (FontFamily)FindResource("MonoFont"),
            FontWeight = FontWeights.SemiBold,
            VerticalAlignment = VerticalAlignment.Center,
            HorizontalAlignment = HorizontalAlignment.Center,
            Background = (Brush)FindResource("ScrimMidBrush"),
            Padding = new Thickness(14, 8, 14, 8)
        };
        top.Children.Add(status);
        root.Children.Add(top);

        root.Children.Add(ImmersiveTelemetryHud());

        var leftRail = ImmersiveToolRail();
        root.Children.Add(leftRail);

        var scopeDock = ImmersiveScopeDock();
        root.Children.Add(scopeDock);

        var rightRail = new StackPanel
        {
            Width = 112,
            Margin = new Thickness(0, 0, 20, 0),
            VerticalAlignment = VerticalAlignment.Center,
            HorizontalAlignment = HorizontalAlignment.Right
        };
        rightRail.Children.Add(new TextBlock
        {
            Text = _videoMode ? "视频" : "照片",
            Foreground = _videoMode
                ? (Brush)FindResource("VideoBrush")
                : (Brush)FindResource("AccentBrush"),
            FontSize = 18,
            FontWeight = FontWeights.Bold,
            TextAlignment = TextAlignment.Center,
            Margin = new Thickness(0, 0, 0, 12)
        });
        var capture = new Button
        {
            Content = _videoMode
                ? (_videoRecording ? "■\n停止" : "●\n录制")
                : "●\n拍摄",
            Width = 96,
            Height = 96,
            FontSize = 16, // v1.5.7 F5: 录制钮符号字号（归档不改值）
            Style = (Style)FindResource(
                _videoMode ? "DangerButton" : "PrimaryButton"),
            IsEnabled = _camera.IsConnected
        };
        capture.Click += ShutterButton_Click;
        if (_videoMode)
        {
            _immersiveRecordButton = capture;
        }
        rightRail.Children.Add(capture);
        var liveView = new Button
        {
            Content = AppLocalization.T(
                _camera.IsLiveView ? "停止取景" : "开启取景"),
            Height = 44,
            MinWidth = 92,
            Margin = new Thickness(0, 10, 0, 0),
            Style = (Style)FindResource("ButtonBase"),
            IsEnabled = _camera.IsConnected
        };
        liveView.Click += LiveViewButton_Click;
        rightRail.Children.Add(liveView);
        root.Children.Add(rightRail);

        var exposure = new TextBlock
        {
            Text = _camera.IsConnected
                ? _videoMode
                    ? $"{_videoShutterAngle:0.#}°   {_videoFrameRate:0} fps   {VideoCodecShortLabel()}   {VideoLogShortLabel()}"
                    : $"{ExposureModeText()}   JPEG   帧澈 ZENCHE"
                : "—",
            Foreground = Brushes.White,
            FontFamily = (FontFamily)FindResource("MonoFont"),
            FontWeight = FontWeights.SemiBold,
            Background = (Brush)FindResource("ScrimStrongBrush"),
            Padding = new Thickness(18, 10, 18, 10),
            Margin = new Thickness(0, 0, 0, 24),
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Bottom
        };
        root.Children.Add(exposure);

        var parameterBar = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            HorizontalAlignment = HorizontalAlignment.Left
        };
        parameterBar.Children.Add(
            ImmersiveParameterControl(
                _videoMode ? "快门角度" : "快门",
                ShutterBox));
        parameterBar.Children.Add(
            ImmersiveParameterControl(
                "光圈",
                ApertureBox));
        parameterBar.Children.Add(
            ImmersiveParameterControl("ISO", IsoBox));
        parameterBar.Children.Add(
            ImmersiveParameterControl("曝光补偿", ExposureCompensationBox));
        var parameterScroller = new ScrollViewer
        {
            Content = parameterBar,
            HorizontalScrollBarVisibility = ScrollBarVisibility.Auto,
            VerticalScrollBarVisibility = ScrollBarVisibility.Disabled
        };

        var moreParameterBar = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            HorizontalAlignment = HorizontalAlignment.Left
        };
        if (_videoMode)
        {
            moreParameterBar.Children.Add(
                ImmersiveParameterControl("视频帧率", VideoFrameRateBox));
            moreParameterBar.Children.Add(
                ImmersiveParameterControl("曝光模式", ExposureModeBox));
            moreParameterBar.Children.Add(
                ImmersiveParameterControl("视频录制规格", VideoCodecBox));
            moreParameterBar.Children.Add(
                ImmersiveParameterControl("Log", VideoLogBox));
        }
        else
        {
            moreParameterBar.Children.Add(
                ImmersiveParameterControl("拍摄模式", ExposureModeBox));
        }
        moreParameterBar.Children.Add(
            ImmersiveParameterControl("对焦", FocusModeBox));
        moreParameterBar.Children.Add(
            ImmersiveParameterControl("白平衡", WhiteBalanceBox));
        moreParameterBar.Children.Add(
            ImmersiveParameterControl("优化校准", PictureControlBox));
        var moreParameterScroller = new ScrollViewer
        {
            Content = moreParameterBar,
            HorizontalScrollBarVisibility = ScrollBarVisibility.Auto,
            VerticalScrollBarVisibility = ScrollBarVisibility.Disabled
        };
        var moreParameterTray = new Expander
        {
            Header = "更多参数",
            IsExpanded = false,
            Content = moreParameterScroller,
            Foreground = Brushes.White,
            Background = (Brush)FindResource("ScrimSoftBrush"),
            Padding = new Thickness(6),
            Margin = new Thickness(0, 6, 0, 0)
        };
        var parameterContent = new StackPanel();
        parameterContent.Children.Add(parameterScroller);
        parameterContent.Children.Add(moreParameterTray);
        var parameterTray = ImmersiveParameterTray(parameterContent);
        root.Children.Add(parameterTray);
        void ApplyImmersiveLayout()
        {
            var landscape = viewer.ActualWidth <= 0 ||
                viewer.ActualWidth >= viewer.ActualHeight;
            leftRail.Orientation = landscape
                ? Orientation.Vertical
                : Orientation.Horizontal;
            leftRail.Width = landscape ? 76 : double.NaN;
            leftRail.HorizontalAlignment = landscape
                ? HorizontalAlignment.Left
                : HorizontalAlignment.Center;
            leftRail.VerticalAlignment = landscape
                ? VerticalAlignment.Center
                : VerticalAlignment.Top;
            leftRail.Margin = landscape
                ? new Thickness(20, 0, 0, 0)
                : new Thickness(20, 86, 20, 0);

            rightRail.Orientation = landscape
                ? Orientation.Vertical
                : Orientation.Horizontal;
            rightRail.Width = landscape ? 112 : double.NaN;
            rightRail.HorizontalAlignment = landscape
                ? HorizontalAlignment.Right
                : HorizontalAlignment.Center;
            rightRail.VerticalAlignment = landscape
                ? VerticalAlignment.Center
                : VerticalAlignment.Bottom;
            rightRail.Margin = landscape
                ? new Thickness(0, 0, 20, 0)
                : new Thickness(20, 0, 20, 18);

            parameterTray.Margin = landscape
                ? new Thickness(112, 0, 124, 78)
                : new Thickness(18, 0, 18, 168);
            exposure.Margin = landscape
                ? new Thickness(0, 0, 0, 24)
                : new Thickness(0, 0, 0, 122);
            scopeDock.Visibility = landscape
                ? Visibility.Visible
                : Visibility.Collapsed;
        }
        viewer.SizeChanged += (_, _) => ApplyImmersiveLayout();
        viewer.Content = root;
        viewer.KeyDown += (_, args) =>
        {
            if (args.Key == Key.Escape)
            {
                CloseImmersivePreview(viewer);
            }
        };
        viewer.Closed += (_, _) =>
        {
            if (ReferenceEquals(_immersivePreviewWindow, viewer))
            {
                _immersivePreviewWindow = null;
                _immersivePreviewImage = null;
                _immersiveRecordButton = null;
                _immersiveScope = null;
            }
        };
        viewer.Show();
        viewer.Dispatcher.BeginInvoke(ApplyImmersiveLayout);
    }

    private Border ImmersiveTelemetryHud()
    {
        var connected = _camera.IsConnected;
        var row = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            Background = (Brush)FindResource("StudioPanelBrush")
        };
        void AddCell(string label, string value)
        {
            row.Children.Add(new Border
            {
                Width = 106,
                Height = 52,
                Padding = new Thickness(10, 5, 10, 5),
                Background = (Brush)FindResource("StudioPanelBrush"),
                BorderBrush = (Brush)FindResource("StudioRuleBrush"),
                BorderThickness = new Thickness(0, 0, 1, 0),
                Child = new StackPanel
                {
                    Children =
                    {
                        new TextBlock
                        {
                            Text = label,
                            Style = (Style)FindResource("TelemetryMicro"),
                        },
                        new TextBlock
                        {
                            Text = value,
                            FontFamily = (FontFamily)FindResource("MonoFont"),
                            FontSize = 12,
                            FontWeight = FontWeights.SemiBold,
                            Foreground = Brushes.White,
                            TextTrimming = TextTrimming.CharacterEllipsis
                        }
                    }
                }
            });
        }
        AddCell("SOURCE", connected ? "USB/PTP" : "OFFLINE");
        AddCell("FORMAT", connected
            ? _videoMode
                ? $"{_videoFrameRate:0}P · {VideoCodecShortLabel()}"
                : "PHOTO · JPEG"
            : "—");
        AddCell("SHUTTER", connected ? SelectedContent(ShutterBox, "—") : "—");
        AddCell("IRIS", connected ? SelectedContent(ApertureBox, "—") : "—");
        AddCell("ISO", connected
            ? SelectedContent(IsoBox, "—").Replace("ISO ", "")
            : "—");
        AddCell("EV", connected
            ? SelectedContent(ExposureCompensationBox, "—")
            : "—");
        AddCell("STATE", connected
            ? _videoRecording ? "REC" : _camera.IsLiveView ? "LIVE" : "STBY"
            : "OFFLINE");
        return new Border
        {
            Height = 52,
            Margin = new Thickness(170, 76, 170, 0),
            VerticalAlignment = VerticalAlignment.Top,
            HorizontalAlignment = HorizontalAlignment.Stretch,
            Background = (Brush)FindResource("StudioPanelBrush"),
            BorderBrush = (Brush)FindResource("StudioRuleBrush"),
            BorderThickness = new Thickness(1),
            CornerRadius = (CornerRadius)FindResource("CornerRadius5"),
            ClipToBounds = true,
            Child = new ScrollViewer
            {
                Content = row,
                HorizontalScrollBarVisibility = ScrollBarVisibility.Hidden,
                VerticalScrollBarVisibility = ScrollBarVisibility.Disabled
            }
        };
    }

    private StackPanel ImmersiveToolRail()
    {
        var rail = new StackPanel
        {
            Width = 76,
            Margin = new Thickness(20, 0, 0, 0),
            VerticalAlignment = VerticalAlignment.Center,
            HorizontalAlignment = HorizontalAlignment.Left,
            Background = (Brush)FindResource("StudioPanelScrimBrush")
        };
        rail.Children.Add(ImmersiveReadout(
            _camera.IsConnected
                ? _videoMode ? $"{_videoFrameRate:0}P" : ExposureModeText()
                : "—"));
        rail.Children.Add(ImmersiveReadout(
            _camera.IsConnected ? "USB\nPTP" : "OFFLINE"));
        if (_videoMode)
        {
            var peaking = new Button
            {
                Content = "峰值",
                Height = 44,
                Margin = new Thickness(6, 0, 6, 6),
                Style = (Style)FindResource("ButtonBase")
            };
            peaking.Click += MonitorFocusButton_Click;
            rail.Children.Add(peaking);
            var falseColor = new Button
            {
                Content = "假色",
                Height = 44,
                Margin = new Thickness(6, 0, 6, 6),
                Style = (Style)FindResource("ButtonBase")
            };
            falseColor.Click += MonitorFalseColorButton_Click;
            rail.Children.Add(falseColor);
        }
        var autoFocus = new Button
        {
            Content = "AF",
            Height = 44,
            Margin = new Thickness(6, 0, 6, 6),
            Style = (Style)FindResource("ButtonBase"),
            IsEnabled = _camera.IsConnected && _camera.IsLiveView
        };
        autoFocus.Click += CaptureAutoFocusButton_Click;
        rail.Children.Add(autoFocus);
        return rail;
    }

    private Border ImmersiveScopeDock()
    {
        _immersiveScope = new WaveformScope
        {
            Mode = WaveformScopeMode.RgbParade,
            Width = 180,
            Height = 76
        };
        var audio = new WaveformScope
        {
            Mode = WaveformScopeMode.Audio,
            Width = 88,
            Height = 76,
            Margin = new Thickness(5, 0, 0, 0)
        };
        var row = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            Children = { _immersiveScope, audio }
        };
        return new Border
        {
            Width = 284,
            Height = 86,
            Margin = new Thickness(20, 0, 0, 174),
            HorizontalAlignment = HorizontalAlignment.Left,
            VerticalAlignment = VerticalAlignment.Bottom,
            Padding = new Thickness(5),
            Background = (Brush)FindResource("StudioCanvasBrush"),
            BorderBrush = (Brush)FindResource("StudioRuleBrush"),
            BorderThickness = new Thickness(1),
            CornerRadius = (CornerRadius)FindResource("CornerRadius5"),
            Child = row
        };
    }

    private Expander ImmersiveParameterTray(FrameworkElement content)
    {
        return new Expander
        {
            Header = "参数",
            IsExpanded = true,
            Content = content,
            Foreground = Brushes.White,
            Background = (Brush)FindResource("StudioPanelBrush"),
            BorderBrush = (Brush)FindResource("StudioRuleBrush"),
            BorderThickness = new Thickness(1),
            Padding = new Thickness(8),
            Margin = new Thickness(112, 0, 124, 78),
            HorizontalAlignment = HorizontalAlignment.Stretch,
            VerticalAlignment = VerticalAlignment.Bottom
        };
    }

    private Border ImmersiveParameterControl(
        string label,
        ComboBox source)
    {
        var value = new TextBlock
        {
            Text = ImmersiveParameterLabel(source),
            Foreground = source.IsEnabled
                ? (Brush)FindResource("StudioGoldBrush")
                : Brushes.White,
            FontFamily = (FontFamily)FindResource("MonoFont"),
            FontWeight = FontWeights.SemiBold,
            Width = 104,
            TextAlignment = TextAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center,
            TextTrimming = TextTrimming.CharacterEllipsis
        };
        var minus = new Button
        {
            Content = "−",
            Width = 44,
            Height = 44,
            Style = (Style)FindResource("ButtonBase")
        };
        var plus = new Button
        {
            Content = "+",
            Width = 44,
            Height = 44,
            Style = (Style)FindResource("ButtonBase")
        };
        minus.Click += (_, _) => AdjustParameterSelection(source, -1, value);
        plus.Click += (_, _) => AdjustParameterSelection(source, 1, value);
        minus.IsEnabled = source.IsEnabled;
        plus.IsEnabled = source.IsEnabled;
        var row = new StackPanel
        {
            Orientation = Orientation.Horizontal
        };
        row.Children.Add(minus);
        row.Children.Add(new StackPanel
        {
            Width = 104,
            Children =
            {
                new TextBlock
                {
                    Text = label,
                    Style = (Style)FindResource("ImmersiveLabel"),
                    TextAlignment = TextAlignment.Center
                },
                value
            }
        });
        row.Children.Add(plus);
        var control = new Border
        {
            Background = (Brush)FindResource("StudioPanelBrush"),
            BorderBrush = source.IsEnabled
                ? (Brush)FindResource("StudioGoldBrush")
                : (Brush)FindResource("StudioRuleBrush"),
            BorderThickness = new Thickness(1),
            CornerRadius = (CornerRadius)FindResource("CornerRadius7"),
            Padding = new Thickness(4),
            Margin = new Thickness(4, 0, 4, 0),
            Child = row
        };
        control.Opacity = source.IsEnabled ? 1 : 0.48;
        control.ToolTip = source.IsEnabled
            ? label
            : source.ToolTip ?? $"{label}当前不可调整";
        return control;
    }

    private static string SelectedParameterLabel(ComboBox source)
    {
        if (source.SelectedItem is not ComboBoxItem item)
        {
            return "—";
        }
        return Convert.ToString(item.Content) ?? "—";
    }

    private string ImmersiveParameterLabel(ComboBox source)
    {
        return _camera.IsConnected
            ? SelectedParameterLabel(source)
            : "—";
    }

    private void AdjustParameterSelection(
        ComboBox source,
        int direction,
        TextBlock value)
    {
        if (!source.IsEnabled || source.Items.Count == 0)
        {
            return;
        }
        source.SelectedIndex = Math.Clamp(
            source.SelectedIndex + direction,
            0,
            source.Items.Count - 1);
        value.Text = ImmersiveParameterLabel(source);
    }

    private void CloseImmersivePreview(Window viewer)
    {
        if (!ReferenceEquals(_immersivePreviewWindow, viewer))
        {
            return;
        }
        _immersivePreviewImage = null;
        _immersiveRecordButton = null;
        _immersiveScope = null;
        _immersivePreviewWindow = null;
        viewer.Dispatcher.BeginInvoke(viewer.Close);
    }

    private Border ImmersiveReadout(string value)
    {
        return new Border
        {
            Background = (Brush)FindResource("ScrimStrongBrush"),
            CornerRadius = (CornerRadius)FindResource("CornerRadius10"),
            Margin = new Thickness(0, 0, 0, 12),
            Padding = new Thickness(8),
            Height = 58,
            Child = new TextBlock
            {
                Text = value,
                Foreground = Brushes.White,
                FontWeight = FontWeights.Bold,
                TextAlignment = TextAlignment.Center,
                VerticalAlignment = VerticalAlignment.Center
            }
        };
    }

    private Border ImmersiveToggleControl(string label, CheckBox source)
    {
        var toggle = new CheckBox
        {
            Content = source.IsChecked == true ? "开启" : "关闭",
            IsChecked = source.IsChecked,
            IsEnabled = source.IsEnabled,
            Foreground = Brushes.White,
            VerticalAlignment = VerticalAlignment.Center
        };
        toggle.Click += (_, _) =>
        {
            source.IsChecked = toggle.IsChecked;
            source.RaiseEvent(new RoutedEventArgs(ButtonBase.ClickEvent));
            toggle.Content = toggle.IsChecked == true ? "开启" : "关闭";
        };
        return new Border
        {
            Margin = new Thickness(4),
            Padding = new Thickness(10),
            Background = (Brush)FindResource("GraphiteScrimBrush"),
            CornerRadius = (CornerRadius)FindResource("CornerRadius8"),
            Child = new StackPanel
            {
                Children =
                {
                    new TextBlock
                    {
                        Text = label,
                        Foreground = (Brush)FindResource("GraphiteMutedBrush"),
                        FontSize = 11
                    },
                    toggle
                }
            }
        };
    }

    private string ExposureModeText()
    {
        return ExposureModeBox.SelectedItem is ComboBoxItem item
            ? (Convert.ToString(item.Tag) switch
            {
                "program" => "P",
                "shutterPriority" => "S",
                "aperturePriority" => "A",
                "bulb" => "B",
                _ => "M"
            })
            : "M";
    }

    /** v1.5.5 fig1 parameter grid: 全部 resets hidden tiles and exits edit mode. */
    private void GridEditAllButton_Click(object sender, RoutedEventArgs e)
    {
        _gridEditMode = false;
        Array.Fill(_gridHiddenTiles, false);
        UpdateControlParameterGrid();
    }

    /** v1.5.5 fig1 parameter grid: 编辑 reveals per-tile hide affordances. */
    private void GridEditButton_Click(object sender, RoutedEventArgs e)
    {
        _gridEditMode = true;
        UpdateControlParameterGrid();
    }

    /** v1.5.5 fig1 parameter grid: hide a single tile (edit mode only). */
    private void ParameterTileHide_Click(object sender, MouseButtonEventArgs e)
    {
        if (!_gridEditMode ||
            sender is not FrameworkElement tile)
        {
            return;
        }
        var tag = Convert.ToString(tile.Tag);
        var index = Array.IndexOf(
            new[] { "ParameterTileSource", "ParameterTileMode", "ParameterTileShutter", "ParameterTileAperture", "ParameterTileIso", "ParameterTileCompensation" },
            tag);
        if (index >= 0)
        {
            _gridHiddenTiles[index] = true;
        }
        UpdateControlParameterGrid();
    }

    /** v1.5.5 fig1 parameter grid: apply edit-mode / hidden-tile state to tiles. */
    private void UpdateControlParameterGrid()
    {
        var tiles = new[]
        {
            ParameterTileSource,
            ParameterTileMode,
            ParameterTileShutter,
            ParameterTileAperture,
            ParameterTileIso,
            ParameterTileCompensation
        };
        var hides = new[]
        {
            ParameterTileSourceHide,
            ParameterTileModeHide,
            ParameterTileShutterHide,
            ParameterTileApertureHide,
            ParameterTileIsoHide,
            ParameterTileCompensationHide
        };
        var shown = 0;
        for (var index = 0; index < tiles.Length; index++)
        {
            var hidden = _gridHiddenTiles[index];
            tiles[index].Visibility = hidden
                ? Visibility.Collapsed
                : Visibility.Visible;
            hides[index].Visibility =
                !hidden && _gridEditMode
                    ? Visibility.Visible
                    : Visibility.Collapsed;
            if (!hidden)
            {
                shown++;
            }
        }
        if (GridEditAllButton is not null)
        {
            GridEditAllButton.Opacity = _gridEditMode ? 1.0 : 0.7;
            GridEditButton.Opacity = _gridEditMode ? 0.7 : 1.0;
        }
        if (shown == 0)
        {
            ParameterTileEmptyText.Visibility = Visibility.Visible;
        }
        else
        {
            ParameterTileEmptyText.Visibility = Visibility.Collapsed;
        }
    }

    private async void ShutterButton_Click(object sender, RoutedEventArgs e)
    {
        if (_operationInProgress)
        {
            return;
        }
        if (_localCamera.IsConnected)
        {
            if (_videoMode)
            {
                if (!_externalRecordToDevice)
                {
                    ShowError("本机摄像头视频需要开启“外录到当前智能设备”。");
                    return;
                }
                await ToggleMovieRecordingAsync();
                return;
            }
            await RunOperationAsync("正在使用本机摄像头拍摄…", async token =>
            {
                if (_locationTagging.Enabled)
                {
                    await _locationTagging.RefreshAsync(token);
                }
                // E5 1.5.9：live 图——与 USB 路径同构：先 reserve base，
                // 照片与切片 AVI 同 base 配对。
                var baseName = _workflow.ReserveBaseName(_localCamera.DeviceName);
                string? liveClipPath = null;
                if (_livePhotoEnabled)
                {
                    liveClipPath = CaptureLivePhotoSlice();
                }
                var jpeg = await _localCamera.CaptureJpegAsync(token);
                var path = await _workflow.StoreAsync(
                    jpeg,
                    "local-camera.jpg",
                    _localCamera.DeviceName,
                    reservedBaseName: baseName,
                    cancellationToken: token,
                    location: _locationTagging.Snapshot(),
                    pairedWithFilename: liveClipPath is null
                        ? null
                        : $"{baseName}_live.avi");
                if (liveClipPath is not null)
                {
                    await _workflow.StoreLivePhotoClipAsync(
                        liveClipPath,
                        baseName,
                        Path.GetFileName(path),
                        _localCamera.DeviceName,
                        token);
                }
                DisplayJpeg(jpeg);
                RefreshPhotoList();
                OperationStatusText.Text = AppLocalization.T(
                    $"本机拍摄已保存 · {Path.GetFileName(path)}");
            });
            return;
        }
        if (!_camera.IsConnected && _wifiCamera.IsConnected)
        {
            if (_videoMode)
            {
                // E3 1.5.9：Wi‑Fi PTP/IP 录像（Nikon 0x920a/0x920b；Canon EVFRecordStatus，TBC）。
                await ToggleWifiMovieRecordingAsync();
                return;
            }
            await RunOperationAsync("正在通过 Wi‑Fi 触发相机快门…", async token =>
            {
                // E5 1.5.9：Wi‑Fi PTP 拍照不生成 live 图切片——原片在相机
                // 存储卡内，本地无照片文件可配对，切片会导致孤儿 AVI。
                await _wifiCamera.CaptureAsync(token);
                OperationStatusText.Text = AppLocalization.T(
                    "Wi‑Fi 快门已触发 · 原片保存在相机卡内");
            });
            UpdateConnectionSummary();
            return;
        }
        if (!_camera.IsConnected)
        {
            return;
        }
        if (_videoMode)
        {
            await ToggleMovieRecordingAsync();
            return;
        }
        await RunOperationAsync("正在拍摄并下载 JPEG…", async token =>
        {
            if (_locationTagging.Enabled)
            {
                await _locationTagging.RefreshAsync(token);
            }
            // E5 1.5.9：live 图——先 reserve base，照片与切片 AVI 同 base 配对。
            var baseName = _workflow.ReserveBaseName(
                _camera.Profile?.Name ?? "Nikon 相机");
            string? liveClipPath = null;
            if (_livePhotoEnabled)
            {
                liveClipPath = CaptureLivePhotoSlice();
            }
            var jpeg = await _camera.CaptureAsync(token);
            var path = await _workflow.StoreAsync(
                jpeg,
                "capture.jpg",
                _camera.Profile?.Name ?? "Nikon 相机",
                reservedBaseName: baseName,
                cancellationToken: token,
                location: _locationTagging.Snapshot(),
                // 仅当切片实际生成（开关开且取景帧已入环）才写配对标记，
                // 避免 XMP 指向不存在的 AVI。
                pairedWithFilename: liveClipPath is null
                    ? null
                    : $"{baseName}_live.avi");
            if (liveClipPath is not null)
            {
                await _workflow.StoreLivePhotoClipAsync(
                    liveClipPath,
                    baseName,
                    Path.GetFileName(path),
                    _camera.Profile?.Name ?? "Nikon 相机",
                    token);
            }
            DisplayJpeg(jpeg);
            RefreshPhotoList();
            OperationStatusText.Text = AppLocalization.T(
                $"已保存 {Path.GetFileName(path)}");
        });
    }

    private async void CaptureAutoFocusButton_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            await _camera.TriggerAutoFocusAsync(CancellationToken.None);
            OperationStatusText.Text = AppLocalization.T("AF-ON 已触发");
        }
        catch (Exception error)
        {
            OperationStatusText.Text = AppLocalization.T($"AF-ON 失败：{error.Message}");
        }
    }

    private async Task StartShootingTaskAsync()
    {
        if (_operationInProgress || !_camera.IsConnected)
        {
            return;
        }
        _shootingTaskCancellation?.Cancel();
        _shootingTaskCancellation?.Dispose();
        _shootingTaskCancellation = new CancellationTokenSource();
        var token = _shootingTaskCancellation.Token;
        var kind = _shootingTaskKind;
        var count = Math.Clamp(_shootingTaskCount, 1, 999);
        var interval = Math.Clamp(_shootingTaskInterval, 1, 3600);
        var step = Math.Clamp(_shootingTaskStep, 1, 3);
        var originalMode = ExposureModeBox.SelectedItem is ComboBoxItem modeItem
            ? Convert.ToString(modeItem.Tag) ?? "manual"
            : "manual";
        var originalCompensation =
            ExposureCompensationBox.SelectedItem is ComboBoxItem compensationItem &&
            double.TryParse(
                Convert.ToString(compensationItem.Tag),
                NumberStyles.Float,
                CultureInfo.InvariantCulture,
                out var compensation)
                ? compensation
                : 0;
        _operationInProgress = true;
        UpdateEnabledState();
        ShootingTaskButton.Content = AppLocalization.T("取消任务");
        ShootingTaskStatusText.Text = AppLocalization.T(
            $"{ShootingTaskLabel(kind)}准备中");
        await StopPreviewLoopAsync();
        try
        {
            var total = kind == "bulb" ? 1 : count;
            if (kind == "exposure" && total % 2 == 0)
            {
                total++;
            }
            if (kind == "focus" && !_camera.IsLiveView)
            {
                await _camera.StartLiveViewAsync(token);
            }
            if (kind == "bulb")
            {
                await _camera.SetParameterAsync("exposureMode", "bulb", token);
                await _camera.SetParameterAsync(
                    "bulbDuration",
                    interval,
                    token);
            }
            for (var index = 0; index < total; index++)
            {
                token.ThrowIfCancellationRequested();
                if (kind == "exposure")
                {
                    var center = total / 2;
                    await _camera.SetParameterAsync(
                        "exposureCompensation",
                        originalCompensation + (index - center) * step,
                        token);
                }
                if (kind == "focus" && index > 0)
                {
                    await _camera.MoveFocusAsync(step, token);
                }
                var jpeg = await _camera.CaptureAsync(token);
                if (_locationTagging.Enabled)
                {
                    await _locationTagging.RefreshAsync(token);
                }
                var path = await _workflow.StoreAsync(
                    jpeg,
                    "capture.jpg",
                    _camera.Profile?.Name ?? "Nikon 相机",
                    cancellationToken: token,
                    location: _locationTagging.Snapshot());
                DisplayJpeg(jpeg);
                RefreshPhotoList();
                ShootingTaskStatusText.Text = AppLocalization.T(
                    $"{ShootingTaskLabel(kind)} · {index + 1}/{total} · " +
                    Path.GetFileName(path));
                OperationStatusText.Text = ShootingTaskStatusText.Text;
                if (kind == "interval" && index + 1 < total)
                {
                    await Task.Delay(TimeSpan.FromSeconds(interval), token);
                }
            }
            await RestoreTaskCameraStateAsync(
                kind,
                originalCompensation,
                originalMode,
                CancellationToken.None);
            ShootingTaskStatusText.Text = AppLocalization.T(
                $"{ShootingTaskLabel(kind)}已完成");
        }
        catch (OperationCanceledException)
        {
            await RestoreTaskCameraStateAsync(
                kind,
                originalCompensation,
                originalMode,
                CancellationToken.None);
            ShootingTaskStatusText.Text =
                AppLocalization.T("拍摄任务已取消");
        }
        catch (Exception error)
        {
            await RestoreTaskCameraStateAsync(
                kind,
                originalCompensation,
                originalMode,
                CancellationToken.None);
            _diagnostics.Error(
                "capture-task",
                $"{ShootingTaskLabel(kind)}失败：{error}");
            ShootingTaskStatusText.Text =
                AppLocalization.T("拍摄任务失败");
            ShowError(error.Message);
        }
        finally
        {
            _operationInProgress = false;
            _shootingTaskCancellation?.Dispose();
            _shootingTaskCancellation = null;
            ShootingTaskButton.Content = AppLocalization.T("开始任务");
            UpdateEnabledState();
            UpdateLiveViewState();
            if (_camera.IsLiveView)
            {
                StartPreviewLoop();
            }
        }
    }

    private async void ShootingTaskButton_Click(
        object sender,
        RoutedEventArgs e)
    {
        if (_shootingTaskCancellation is not null && _operationInProgress)
        {
            _shootingTaskCancellation.Cancel();
            ShootingTaskStatusText.Text =
                AppLocalization.T("正在取消拍摄任务…");
            return;
        }
        if (ShootingTaskKindBox.SelectedItem is ComboBoxItem kindItem)
        {
            _shootingTaskKind =
                Convert.ToString(kindItem.Tag) ?? "interval";
        }
        _shootingTaskCount = ParseBounded(
            ShootingTaskCountText.Text,
            1,
            999,
            5);
        _shootingTaskInterval = ParseBounded(
            ShootingTaskIntervalText.Text,
            1,
            3600,
            3);
        _shootingTaskStep = ParseBounded(
            ShootingTaskStepText.Text,
            1,
            3,
            1);
        ShootingTaskCountText.Text = _shootingTaskCount.ToString();
        ShootingTaskIntervalText.Text = _shootingTaskInterval.ToString();
        ShootingTaskStepText.Text = _shootingTaskStep.ToString();
        await StartShootingTaskAsync();
    }

    private void ShootingTaskKindBox_SelectionChanged(
        object sender,
        SelectionChangedEventArgs e)
    {
        if (_initializing ||
            ShootingTaskKindBox.SelectedItem is not ComboBoxItem item)
        {
            return;
        }
        _shootingTaskKind = Convert.ToString(item.Tag) ?? "interval";
        ShootingTaskIntervalLabel.Text = AppLocalization.T(
            _shootingTaskKind == "bulb"
                ? "曝光时长（秒）"
                : "间隔（秒）");
        ShootingTaskCountText.IsEnabled = _shootingTaskKind != "bulb";
        ShootingTaskStepText.IsEnabled =
            _shootingTaskKind is "exposure" or "focus";
    }

    private static int ParseBounded(
        string value,
        int minimum,
        int maximum,
        int fallback) =>
        int.TryParse(value, out var parsed)
            ? Math.Clamp(parsed, minimum, maximum)
            : fallback;

    private void FocusPeakingCheck_Click(
        object sender,
        RoutedEventArgs e)
    {
        _focusPeakingEnabled = FocusPeakingCheck.IsChecked == true;
    }

    private void FalseColorCheck_Click(
        object sender,
        RoutedEventArgs e)
    {
        _falseColorEnabled = FalseColorCheck.IsChecked == true;
    }

    private void MonitorFocusButton_Click(object sender, RoutedEventArgs e)
    {
        _focusPeakingEnabled = !_focusPeakingEnabled;
        FocusPeakingCheck.IsChecked = _focusPeakingEnabled;
        RefreshMonitorPreview();
    }

    private void PopulateMonitorNikonCloudPresetBoxes()
    {
        _updatingMonitorCloudControls = true;
        foreach (var box in new[]
                 {
                     CaptureNikonCloudPresetBox,
                     MonitorNikonCloudPresetBox
                 })
        {
            box.Items.Add(new ComboBoxItem
            {
                Content = AppLocalization.T("关闭云创监看"),
                Tag = null
            });
            foreach (var preset in _nikonCloudCatalog.Presets)
            {
                box.Items.Add(new ComboBoxItem
                {
                    Content = preset.Name +
                        (preset.HasCustomToneCurve ? " · Curve" : ""),
                    Tag = preset
                });
            }
            box.SelectedIndex = 0;
        }
        _updatingMonitorCloudControls = false;
    }

    private void MonitorNikonCloudPresetBox_SelectionChanged(
        object sender,
        SelectionChangedEventArgs e)
    {
        if (_updatingMonitorCloudControls ||
            sender is not ComboBox source ||
            source.SelectedItem is not ComboBoxItem item)
        {
            return;
        }
        _monitorNikonCloudPreset = item.Tag as NikonCloudPreset;
        var selectedIndex = _monitorNikonCloudPreset is null
            ? 0
            : _nikonCloudCatalog.Presets.FindIndex(
                preset => preset.Id == _monitorNikonCloudPreset.Id) + 1;
        _updatingMonitorCloudControls = true;
        CaptureNikonCloudPresetBox.SelectedIndex = selectedIndex;
        MonitorNikonCloudPresetBox.SelectedIndex = selectedIndex;
        CaptureNikonCloudPresetBox.IsDropDownOpen = false;
        MonitorNikonCloudPresetBox.IsDropDownOpen = false;
        _updatingMonitorCloudControls = false;
        OperationStatusText.Text = AppLocalization.T(
            _monitorNikonCloudPreset is null
                ? "尼康云创监看已关闭"
                : $"尼康云创监看 · {_monitorNikonCloudPreset.Name} · 照片/视频 · SDR 近似");
        RefreshMonitorPreview();
    }

    private void MonitorLutButton_Click(object sender, RoutedEventArgs e)
    {
        _monitorLutEnabled = !_monitorLutEnabled;
        EditorStatusText.Text = AppLocalization.T(_monitorLutEnabled ? "监看 LUT 已启用" : "监看 LUT 已关闭");
    }

    private void MonitorFalseColorButton_Click(object sender, RoutedEventArgs e)
    {
        _falseColorEnabled = !_falseColorEnabled;
        FalseColorCheck.IsChecked = _falseColorEnabled;
        RefreshMonitorPreview();
    }

    private void MonitorZebraButton_Click(object sender, RoutedEventArgs e)
    {
        _monitorZebraEnabled = !_monitorZebraEnabled;
        EditorStatusText.Text = AppLocalization.T(_monitorZebraEnabled ? "斑马线提示已启用" : "斑马线提示已关闭");
    }

    private async void MonitorAutoFocusButton_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            await _camera.TriggerAutoFocusAsync(CancellationToken.None);
            EditorStatusText.Text = AppLocalization.T("AF-ON 已触发");
        }
        catch (Exception error)
        {
            EditorStatusText.Text = AppLocalization.T($"AF-ON 失败：{error.Message}");
        }
    }

    private async void MonitorPreviewImage_MouseLeftButtonUp(object sender, MouseButtonEventArgs e)
    {
        if (!_camera.IsLiveView || MonitorPreviewImage.ActualWidth <= 0 || MonitorPreviewImage.ActualHeight <= 0)
        {
            EditorStatusText.Text = AppLocalization.T("请先开启实时取景");
            return;
        }
        var point = e.GetPosition(MonitorPreviewImage);
        var rect = GetUniformImageRect(MonitorPreviewImage, MonitorPreviewImage.Source as BitmapSource);
        if (!rect.Contains(point))
        {
            EditorStatusText.Text = AppLocalization.T("请点击画面区域进行对焦");
            return;
        }
        var normalizedX = Math.Clamp((point.X - rect.Left) / rect.Width, 0, 1);
        var normalizedY = Math.Clamp((point.Y - rect.Top) / rect.Height, 0, 1);
        MonitorFocusReticle.Margin = new Thickness(
            rect.Left + normalizedX * rect.Width - 22,
            rect.Top + normalizedY * rect.Height - 22, 0, 0);
        MonitorFocusReticle.Visibility = Visibility.Visible;
        try
        {
            await _camera.SetParameterAsync("focusMode", "single-shot", CancellationToken.None);
            var dx = normalizedX - 0.5;
            var dy = normalizedY - 0.5;
            var step = Math.Abs(dx) >= Math.Abs(dy)
                ? (int)Math.Round(Math.Clamp(dx * 8, -3, 3))
                : (int)Math.Round(Math.Clamp(dy * 8, -3, 3));
            if (step != 0) await _camera.MoveFocusAsync(step, CancellationToken.None);
            EditorStatusText.Text = AppLocalization.T(
                step == 0 ? "已触发单次自动对焦" : "焦点步进已完成（当前相机不支持二维对焦点）");
        }
        catch (Exception error)
        {
            EditorStatusText.Text = AppLocalization.T($"对焦请求失败：{error.Message}");
        }
        await Task.Delay(1200);
        MonitorFocusReticle.Visibility = Visibility.Collapsed;
    }

    private static Rect GetUniformImageRect(FrameworkElement host, BitmapSource? source)
    {
        if (source is null || host.ActualWidth <= 0 || host.ActualHeight <= 0)
            return new Rect(0, 0, host.ActualWidth, host.ActualHeight);
        var scale = Math.Min(host.ActualWidth / source.PixelWidth, host.ActualHeight / source.PixelHeight);
        var width = source.PixelWidth * scale;
        var height = source.PixelHeight * scale;
        return new Rect((host.ActualWidth - width) / 2, (host.ActualHeight - height) / 2, width, height);
    }

    private void RefreshMonitorPreview()
    {
        if (_lastPreviewSource is BitmapSource bitmap)
        {
            var monitor = ProfessionalMonitor.Process(
                bitmap,
                _focusPeakingEnabled,
                _falseColorEnabled,
                _monitorNikonCloudPreset);
            DisplayPreparedPreview(new PreparedPreview(
                bitmap,
                _videoMode || _monitorNikonCloudPreset is not null
                    ? monitor.Image : bitmap,
                monitor));
        }
    }

    private void LoadCaptureSessionControls()
    {
        var configuration = _workflow.Configuration;
        SessionNameText.Text = configuration.Name;
        SessionNamingTemplateText.Text = configuration.NamingTemplate;
        SessionCreatorText.Text = configuration.Creator;
        SessionRightsText.Text = configuration.Rights;
        SessionRatingBox.SelectedIndex =
            Math.Clamp(configuration.Rating, 0, 5);
        SessionDualBackupCheck.IsChecked =
            configuration.DualBackupEnabled;
        SessionStatusText.Text = AppLocalization.T(_workflow.Status);
        SessionActionButton.Content = AppLocalization.T(
            _workflow.IsActive ? "结束会话" : "开始会话");
    }

    private void SessionActionButton_Click(
        object sender,
        RoutedEventArgs e)
    {
        try
        {
            if (_workflow.IsActive)
            {
                _workflow.End();
            }
            else
            {
                var rating =
                    SessionRatingBox.SelectedItem is ComboBoxItem ratingItem &&
                    int.TryParse(
                        Convert.ToString(ratingItem.Tag),
                        out var selectedRating)
                        ? selectedRating
                        : 0;
                _workflow.Begin(
                    new CaptureSessionConfiguration(
                        SessionNameText.Text,
                        SessionNamingTemplateText.Text,
                        SessionCreatorText.Text,
                        SessionRightsText.Text,
                        rating,
                        SessionDualBackupCheck.IsChecked == true));
            }
            LoadCaptureSessionControls();
            OperationStatusText.Text =
                AppLocalization.T(_workflow.Status);
        }
        catch (Exception error)
        {
            ShowError(error.Message);
        }
    }

    private async Task RestoreTaskCameraStateAsync(
        string kind,
        double compensation,
        string exposureMode,
        CancellationToken cancellationToken)
    {
        try
        {
            if (kind == "exposure")
            {
                await _camera.SetParameterAsync(
                    "exposureCompensation",
                    compensation,
                    cancellationToken);
            }
            if (kind == "bulb" && exposureMode != "bulb")
            {
                await _camera.SetParameterAsync(
                    "exposureMode",
                    exposureMode,
                    cancellationToken);
            }
        }
        catch
        {
        }
    }

    private static string ShootingTaskLabel(string kind) => kind switch
    {
        "exposure" => "曝光包围",
        "focus" => "焦点包围",
        "bulb" => "B 门计时",
        _ => "间隔拍摄"
    };

    private async Task ToggleMovieRecordingAsync()
    {
        await RunOperationAsync(
            _videoRecording ? "正在停止视频录制…" : "正在开始视频录制…",
            async token =>
            {
                if (_videoRecording)
                {
                    Exception? bodyError = null;
                    if (_camera.IsConnected && _camera.IsMovieRecording)
                    {
                        try
                        {
                            await _camera.StopMovieRecordingAsync(token);
                        }
                        catch (Exception error)
                        {
                            bodyError = error;
                        }
                    }
                    var result = _externalVideoRecorder.StopIfRecording();
                    if (result is not null)
                    {
                        await _workflow.CompleteExternalRecordingAsync(
                            result.Path,
                            token);
                        _diagnostics.Info(
                            "external-recording",
                            $"外录完成；文件={Path.GetFileName(result.Path)}；" +
                            $"帧数={result.Frames}；大小={result.Bytes}");
                        RefreshPhotoList();
                    }
                    if (bodyError is not null) throw bodyError;
                }
                else
                {
                    if (_externalRecordToDevice &&
                        !_camera.IsLiveView && !_localCamera.IsLiveView)
                    {
                        if (_localCamera.IsConnected)
                        {
                            await _localCamera.StartLiveViewAsync(token);
                        }
                        else
                        {
                            await _camera.StartLiveViewAsync(token);
                        }
                        StartPreviewLoop();
                    }
                    if (_externalRecordToDevice)
                    {
                        var target = _workflow.ReserveExternalRecording(
                            _localCamera.IsConnected
                                ? _localCamera.DeviceName
                                : _camera.Profile?.Name ?? "Camera");
                        _externalVideoRecorder.Start(
                            target,
                            (int)Math.Round(_videoFrameRate));
                    }
                    Exception? bodyError = null;
                    if (_camera.IsConnected)
                    {
                        try
                        {
                            await _camera.StartMovieRecordingAsync(token);
                        }
                        catch (Exception error)
                        {
                            bodyError = error;
                        }
                    }
                    if (bodyError is not null &&
                        !_externalVideoRecorder.IsRecording)
                    {
                        throw bodyError;
                    }
                    if (bodyError is not null)
                    {
                        OperationStatusText.Text = AppLocalization.T(
                            "机身录制不可用，已继续外录到当前设备");
                    }
                }
                _videoRecording = _externalVideoRecorder.IsRecording ||
                    (_camera.IsConnected && _camera.IsMovieRecording);
                _recordingStartedAt = _videoRecording ? DateTime.Now : null;
                OperationStatusText.Text = AppLocalization.T(
                    _videoRecording
                        ? _externalVideoRecorder.IsRecording
                            ? "● EXT REC · 正在外录到当前智能设备"
                            : "● REC · 视频正在录制到相机存储卡"
                        : "录制已停止 · 外录文件已保存到 ZENCHE 文件库");
            });
        UpdateRecordingState();
    }

    private void UpdateRecordingState()
    {
        if (_videoRecording && !_monitorTimecodeTimer.IsEnabled)
        {
            _monitorTimecodeTimer.Start();
        }
        else if (!_videoRecording && _monitorTimecodeTimer.IsEnabled)
        {
            _monitorTimecodeTimer.Stop();
        }
        UpdateMonitorTimecode();
        if (_videoMode)
        {
            ShutterButton.ToolTip = AppLocalization.T(
                _videoRecording ? "停止录制" : "开始录制");
        }
        if (_immersiveRecordButton is not null)
        {
            _immersiveRecordButton.Content = AppLocalization.T(
                _videoRecording ? "■\n停止" : "●\n录制");
        }
    }

    private void ExternalRecordingCheck_Click(
        object sender,
        RoutedEventArgs e)
    {
        if (_videoRecording)
        {
            ExternalRecordingCheck.IsChecked = _externalRecordToDevice;
            return;
        }
        _externalRecordToDevice = ExternalRecordingCheck.IsChecked == true;
        SaveExternalRecordingPreference(_externalRecordToDevice);
        OperationStatusText.Text = AppLocalization.T(
            _externalRecordToDevice
                ? "外录已开启 · 视频将写入 ZENCHE 文件库"
                : "外录已关闭 · PTP 相机仅记录到机身存储卡");
    }

    private static bool LoadExternalRecordingPreference()
    {
        try
        {
            return !File.Exists(ExternalRecordingStatePath) ||
                File.ReadAllText(ExternalRecordingStatePath).Trim() != "0";
        }
        catch
        {
            return true;
        }
    }

    private static void SaveExternalRecordingPreference(bool enabled)
    {
        try
        {
            Directory.CreateDirectory(
                Path.GetDirectoryName(ExternalRecordingStatePath)!);
            File.WriteAllText(
                ExternalRecordingStatePath,
                enabled ? "1" : "0");
        }
        catch (Exception error)
        {
            DiagnosticLogger.Shared.Warning(
                "external-recording",
                $"保存外录偏好失败：{error.Message}");
        }
    }

    private static bool LoadLivePhotoPreference()
    {
        try
        {
            return File.Exists(LivePhotoStatePath) &&
                File.ReadAllText(LivePhotoStatePath).Trim() == "1";
        }
        catch
        {
            return false;
        }
    }

    private static void SaveLivePhotoPreference(bool enabled)
    {
        try
        {
            Directory.CreateDirectory(
                Path.GetDirectoryName(LivePhotoStatePath)!);
            File.WriteAllText(LivePhotoStatePath, enabled ? "1" : "0");
        }
        catch (Exception error)
        {
            DiagnosticLogger.Shared.Warning(
                "live-photo",
                $"保存 live 图偏好失败：{error.Message}");
        }
    }

    private static double LoadLivePhotoSecondsPreference()
    {
        try
        {
            if (!File.Exists(LivePhotoSecondsStatePath))
            {
                return 3.0;
            }
            var parsed = double.TryParse(
                File.ReadAllText(LivePhotoSecondsStatePath).Trim(),
                out var seconds);
            return parsed ? Math.Clamp(seconds, 1, 15) : 3.0;
        }
        catch
        {
            return 3.0;
        }
    }

    private static void SaveLivePhotoSecondsPreference(double seconds)
    {
        try
        {
            Directory.CreateDirectory(
                Path.GetDirectoryName(LivePhotoSecondsStatePath)!);
            File.WriteAllText(
                LivePhotoSecondsStatePath,
                seconds.ToString(System.Globalization.CultureInfo.InvariantCulture));
        }
        catch (Exception error)
        {
            DiagnosticLogger.Shared.Warning(
                "live-photo",
                $"保存 live 图时长偏好失败：{error.Message}");
        }
    }

    private static string LoadWifiConnectionModePreference()
    {
        try
        {
            return File.Exists(WifiConnectionModeStatePath) &&
                File.ReadAllText(WifiConnectionModeStatePath).Trim() == "sta"
                    ? "sta"
                    : "ap";
        }
        catch
        {
            return "ap";
        }
    }

    private static void SaveWifiConnectionModePreference(string mode)
    {
        try
        {
            Directory.CreateDirectory(
                Path.GetDirectoryName(WifiConnectionModeStatePath)!);
            File.WriteAllText(
                WifiConnectionModeStatePath,
                mode == "sta" ? "sta" : "ap");
        }
        catch (Exception error)
        {
            DiagnosticLogger.Shared.Warning(
                "wifi-camera",
                $"保存 Wi-Fi 连接模式失败：{error.Message}");
        }
    }

    private void UpdateMonitorTimecode()
    {
        if (MonitorTimecodeText is null)
        {
            return;
        }
        if (!_videoRecording || !_recordingStartedAt.HasValue)
        {
            MonitorTimecodeText.Text = "00:00:00:00";
            return;
        }
        var elapsed = DateTime.Now - _recordingStartedAt.Value;
        var centiseconds = Math.Max(0, (int)(elapsed.TotalMilliseconds / 10));
        MonitorTimecodeText.Text = string.Format(
            CultureInfo.InvariantCulture,
            "{0:00}:{1:00}:{2:00}:{3:00}",
            centiseconds / 360000,
            (centiseconds / 6000) % 60,
            (centiseconds / 100) % 60,
            centiseconds % 100);
    }

    private async void ParameterBox_SelectionChanged(
        object sender,
        SelectionChangedEventArgs e)
    {
        if (_initializing)
        {
            return;
        }
        UpdateExposureReadout();
        if (_configuringVideoControls ||
            !_camera.IsConnected ||
            _operationInProgress ||
            sender is not ComboBox combo ||
            combo.SelectedItem is not ComboBoxItem item)
        {
            return;
        }

        var parameter = combo.Name switch
        {
            nameof(ShutterBox) =>
                _videoMode ? "videoExposureTime" : "exposureTime",
            nameof(ApertureBox) => "aperture",
            nameof(IsoBox) => "iso",
            nameof(ExposureCompensationBox) => "exposureCompensation",
            nameof(FocusModeBox) => "focusMode",
            nameof(WhiteBalanceBox) => "whiteBalanceMode",
            nameof(PictureControlBox) => "pictureControl",
            _ => string.Empty
        };
        if (string.IsNullOrEmpty(parameter))
        {
            return;
        }
        if (combo == ShutterBox)
        {
            if (_videoMode && _videoShutterMode == "angle" &&
                double.TryParse(
                    item.Uid,
                    NumberStyles.Float,
                    CultureInfo.InvariantCulture,
                    out var angle))
            {
                _videoShutterAngle = angle;
            }
            else if (_videoMode && _videoShutterMode == "speed" &&
                     double.TryParse(Convert.ToString(item.Tag), NumberStyles.Float, CultureInfo.InvariantCulture, out var videoSeconds))
            {
                _photoShutterSeconds = videoSeconds;
            }
            else if (!_videoMode &&
                     double.TryParse(
                         Convert.ToString(item.Tag),
                         NumberStyles.Float,
                         CultureInfo.InvariantCulture,
                         out var seconds))
            {
                _photoShutterSeconds = seconds;
            }
        }
        object value = parameter is
            "exposureTime" or "videoExposureTime" or
            "aperture" or "iso" or "exposureCompensation"
            ? double.Parse(
                Convert.ToString(item.Tag) ?? "0",
                CultureInfo.InvariantCulture)
            : Convert.ToString(item.Tag) ?? string.Empty;

        await RunOperationAsync($"正在设置{item.Content}…", async token =>
        {
            await _camera.SetParameterAsync(parameter, value, token);
            OperationStatusText.Text =
                AppLocalization.T($"已设置 {item.Content}");
        });
    }

    private async void ExposureModeBox_SelectionChanged(
        object sender,
        SelectionChangedEventArgs e)
    {
        // XAML 会先选中曝光模式，再继续创建后面的快门、光圈等控件。
        // InitializeComponent 完成前不能刷新整组参数可用性。
        if (_initializing)
        {
            return;
        }
        UpdateExposureAvailability();
        if (!_camera.IsConnected ||
            _operationInProgress ||
            ExposureModeBox.SelectedItem is not ComboBoxItem item)
        {
            return;
        }
        var value = Convert.ToString(item.Tag) ?? "manual";
        await RunOperationAsync($"正在切换至 {item.Content}…", async token =>
        {
            await _camera.SetParameterAsync("exposureMode", value, token);
            UpdateExposureAvailability();
            OperationStatusText.Text =
                AppLocalization.T($"拍摄模式：{item.Content}");
        });
    }

    private void VideoShutterModeBox_SelectionChanged(
        object sender,
        SelectionChangedEventArgs e)
    {
        if (VideoShutterModeBox.SelectedItem is not ComboBoxItem item)
        {
            return;
        }
        _videoShutterMode = Convert.ToString(item.Tag) ?? "angle";
        // 先保留 XAML 预选值，但后面的 ShutterBox 创建前不能刷新控件。
        if (_initializing)
        {
            return;
        }
        if (!_configuringVideoControls)
        {
            ConfigureShutterControl(_videoMode);
            if (_videoMode) _ = ApplyCurrentVideoShutterAsync();
        }
    }

    private async void VideoCodecBox_SelectionChanged(
        object sender,
        SelectionChangedEventArgs e)
    {
        if (VideoCodecBox.SelectedItem is not ComboBoxItem item)
        {
            return;
        }
        _videoCodec = Convert.ToString(item.Tag) ?? "h265";
        if (_initializing)
        {
            return;
        }
        UpdateExposureAvailability();
        if (_configuringVideoControls ||
            !_camera.IsConnected || _operationInProgress)
        {
            return;
        }
        await RunOperationAsync($"正在设置视频录制规格 {item.Content}…", async token =>
        {
            await _camera.SetParameterAsync("videoCodec", _videoCodec, token);
            OperationStatusText.Text = AppLocalization.T(
                $"视频录制规格：{item.Content}");
        });
    }

    private async void VideoLogBox_SelectionChanged(
        object sender,
        SelectionChangedEventArgs e)
    {
        if (VideoLogBox.SelectedItem is not ComboBoxItem item)
        {
            return;
        }
        _videoLogProfile = Convert.ToString(item.Tag) ?? "off";
        UpdateExposureReadout();
        if (_initializing || _configuringVideoControls ||
            !_camera.IsConnected || _operationInProgress)
        {
            return;
        }
        await RunOperationAsync(
            $"正在设置 {item.Content}…",
            async token =>
            {
                await _camera.SetParameterAsync(
                    "videoLog",
                    _videoLogProfile,
                    token);
                OperationStatusText.Text = AppLocalization.T(
                    $"Log / Picture Profile：{item.Content}");
            });
    }

    private string VideoCodecShortLabel() => _videoCodec switch
    {
        "h264" => "H.264",
        "proRes422HQ" => "ProRes 422 HQ",
        "proResRAW" => "ProRes RAW",
        "nRaw" => "N-RAW",
        "sonyXavcHs8k" => "XAVC HS 8K",
        "sonyXavcHs4k" => "XAVC HS 4K",
        "sonyXavcS4k" => "XAVC S 4K",
        "sonyXavcSHd" => "XAVC S HD",
        "sonyXavcSi4k" => "XAVC S-I 4K",
        "sonyXavcSiHd" => "XAVC S-I HD",
        "canonRaw" => "RAW",
        "canonXfHevc422" or "canonXfHevc420" => "XF-HEVC S",
        "canonXfAvc422" or "canonXfAvc420" => "XF-AVC S",
        _ => "H.265"
    };

    private string VideoLogShortLabel() => _videoLogProfile switch
    {
        "nlog" => "N-Log",
        "sonySLog2" => "S-Log2",
        "sonySLog3Cine" or "sonySLog3" => "S-Log3",
        "sonyHlg" => "HLG",
        "canonLog" => "Canon Log",
        "canonLog2" => "Canon Log 2",
        "canonLog3" => "Canon Log 3",
        _ => "SDR"
    };

    private void ConfigureVideoRecordingOptions(CameraProfile? profile)
    {
        var vendorId = profile?.VendorId ?? 0x04b0;
        (string Value, string Label)[] codecs = vendorId switch
        {
            0x054c =>
            [
                ("sonyXavcHs8k", "XAVC HS 8K · HEVC Long GOP"),
                ("sonyXavcHs4k", "XAVC HS 4K · HEVC Long GOP"),
                ("sonyXavcS4k", "XAVC S 4K · AVC Long GOP"),
                ("sonyXavcSHd", "XAVC S HD · AVC Long GOP"),
                ("sonyXavcSi4k", "XAVC S-I 4K · AVC Intra"),
                ("sonyXavcSiHd", "XAVC S-I HD · AVC Intra")
            ],
            0x04a9 =>
            [
                ("canonRaw", "RAW · 12-bit"),
                ("canonXfHevc422", "XF-HEVC S · 4:2:2 10-bit"),
                ("canonXfHevc420", "XF-HEVC S · 4:2:0 10-bit"),
                ("canonXfAvc422", "XF-AVC S · 4:2:2 10-bit"),
                ("canonXfAvc420", "XF-AVC S · 4:2:0 8-bit")
            ],
            _ =>
            [
                ("h264", "H.264 / AVC · 8-bit"),
                ("h265", "H.265 / HEVC · 10-bit"),
                ("proRes422HQ", "Apple ProRes 422 HQ · 10-bit"),
                ("proResRAW", "Apple ProRes RAW HQ · 12-bit"),
                ("nRaw", "N-RAW · 12-bit NEV")
            ]
        };
        (string Value, string Label)[] logs = vendorId switch
        {
            0x054c =>
            [
                ("off", "关闭 · SDR"),
                ("sonySLog2", "PP7 · S-Log2"),
                ("sonySLog3Cine", "PP8 · S-Log3 / S-Gamut3.Cine"),
                ("sonySLog3", "PP9 · S-Log3 / S-Gamut3"),
                ("sonyHlg", "PP10 · HLG")
            ],
            0x04a9 =>
            [
                ("off", "关闭 · SDR"),
                ("canonLog", "Canon Log"),
                ("canonLog2", "Canon Log 2"),
                ("canonLog3", "Canon Log 3")
            ],
            _ => [("off", "关闭 · SDR"), ("nlog", "N-Log")]
        };

        var previousConfiguring = _configuringVideoControls;
        _configuringVideoControls = true;
        try
        {
            VideoCodecBox.Items.Clear();
            foreach (var option in codecs)
            {
                VideoCodecBox.Items.Add(new ComboBoxItem
                {
                    Tag = option.Value,
                    Content = AppLocalization.T(option.Label)
                });
            }
            var codecIndex = Array.FindIndex(
                codecs,
                option => option.Value == _videoCodec);
            VideoCodecBox.SelectedIndex = codecIndex >= 0 ? codecIndex : 0;
            _videoCodec = codecs[VideoCodecBox.SelectedIndex].Value;

            VideoLogBox.Items.Clear();
            foreach (var option in logs)
            {
                VideoLogBox.Items.Add(new ComboBoxItem
                {
                    Tag = option.Value,
                    Content = AppLocalization.T(option.Label)
                });
            }
            var logIndex = Array.FindIndex(
                logs,
                option => option.Value == _videoLogProfile);
            VideoLogBox.SelectedIndex = logIndex >= 0 ? logIndex : 0;
            _videoLogProfile = logs[VideoLogBox.SelectedIndex].Value;
        }
        finally
        {
            _configuringVideoControls = previousConfiguring;
        }
    }

    private async Task ApplyCurrentVideoShutterAsync()
    {
        if (!_videoMode || !_camera.IsConnected || _operationInProgress)
        {
            return;
        }
        var seconds = _videoShutterMode == "angle"
            ? _videoShutterAngle / (360 * _videoFrameRate)
            : _photoShutterSeconds;
        await RunOperationAsync("正在应用视频快门…", async token =>
        {
            await _camera.SetParameterAsync("videoExposureTime", seconds, token);
            OperationStatusText.Text = AppLocalization.T(
                _videoShutterMode == "angle"
                    ? $"快门角度 {_videoShutterAngle:g}° · {_videoFrameRate:g} fps"
                    : $"快门速度 {_photoShutterSeconds:g} s · {_videoFrameRate:g} fps");
        });
    }

    private void Navigate_Click(object sender, RoutedEventArgs e)
    {
        if (sender is not Button button)
        {
            return;
        }
        var destination = Convert.ToString(button.Tag);
        ShowDestination(button, destination);
    }

    private void SettingsButton_Click(object sender, RoutedEventArgs e)
    {
        ShowDestination(null, "settings");
    }

    private void WorkspacePreset_Click(object sender, RoutedEventArgs e)
    {
        var preset = sender is Button button
            ? Convert.ToString(button.Tag) ?? "standard"
            : "standard";
        ApplyWorkspacePreset(preset);
    }

    private void ResetWorkspaceLayout_Click(object sender, RoutedEventArgs e) =>
        ApplyWorkspacePreset("standard");

    private void WorkspaceSplitter_DragCompleted(
        object sender,
        DragCompletedEventArgs e)
    {
        SaveWorkspaceLayout();
    }

    private void ApplyWorkspacePreset(string preset)
    {
        (
            double sidebar,
            double parameter,
            double editorMedia,
            double editorTools,
            double editorBottom,
            double editorAiTools,
            double windowWidth,
            double windowHeight
        ) values = preset switch
        {
            "capture" => (120d, 420d, 220d, 360d, 320d, 400d, 1540d, 960d),
            "monitor" => (96d, 320d, 200d, 340d, 300d, 380d, 1580d, 940d),
            "editor" => (104d, 360d, 280d, 440d, 480d, 520d, 1680d, 1020d),
            "compact" => (88d, 260d, 140d, 300d, 240d, 340d, 1160d, 760d),
            _ => (176d, 380d, 240d, 380d, 360d, 440d, 1440d, 900d)
        };
        _workspaceLayout.SidebarWidth = values.sidebar;
        _workspaceLayout.ParameterWidth = values.parameter;
        _workspaceLayout.EditorMediaWidth = values.editorMedia;
        _workspaceLayout.EditorToolsWidth = values.editorTools;
        _workspaceLayout.EditorBottomHeight = values.editorBottom;
        _workspaceLayout.EditorAiToolsWidth = values.editorAiTools;
        ResizeWindowInsideVisibleArea(values.windowWidth, values.windowHeight);
        ApplyWorkspacePanelSizes();
        SaveWorkspaceLayout(capturePanelSizes: false);
    }

    private void ApplyWorkspaceLayout()
    {
        var workArea = new Rect(
            SystemParameters.VirtualScreenLeft,
            SystemParameters.VirtualScreenTop,
            SystemParameters.VirtualScreenWidth,
            SystemParameters.VirtualScreenHeight);
        var width = Math.Clamp(_workspaceLayout.Width, MinWidth, workArea.Width);
        var height = Math.Clamp(_workspaceLayout.Height, MinHeight, workArea.Height);
        var left = double.IsFinite(_workspaceLayout.Left)
            ? _workspaceLayout.Left
            : workArea.Left + (workArea.Width - width) / 2;
        var top = double.IsFinite(_workspaceLayout.Top)
            ? _workspaceLayout.Top
            : workArea.Top + (workArea.Height - height) / 2;
        Left = Math.Clamp(left, workArea.Left, workArea.Right - width);
        Top = Math.Clamp(top, workArea.Top, workArea.Bottom - height);
        Width = width;
        Height = height;
        ApplyWorkspacePanelSizes();
        if (_workspaceLayout.Maximized)
        {
            WindowState = WindowState.Maximized;
        }
    }

    private void ApplyWorkspacePanelSizes()
    {
        EditorBottomRow.Height = new GridLength(Math.Clamp(
            _workspaceLayout.EditorBottomHeight, 220, 680));
        ApplyResponsiveEditorLayout();
    }

    private void CaptureWorkspacePanelSizes()
    {
        _workspaceLayout.SidebarWidth = Math.Clamp(
            SidebarColumn.ActualWidth, 72, 360);
        if (ParameterPanelShell.Visibility == Visibility.Visible)
        {
            _workspaceLayout.ParameterWidth = Math.Clamp(
                ParameterColumn.ActualWidth, 240, 720);
        }
        if (EditorMediaRail.Visibility == Visibility.Visible)
        {
            _workspaceLayout.EditorMediaWidth = Math.Clamp(
                EditorMediaColumn.ActualWidth, 140, 520);
        }
        _workspaceLayout.EditorToolsWidth = Math.Clamp(
            EditorToolsColumn.ActualWidth, 280, 720);
        _workspaceLayout.EditorBottomHeight = Math.Clamp(
            EditorBottomRow.ActualHeight, 220, 680);
        if (EditorAiGrid.Visibility == Visibility.Visible &&
            EditorAiToolsColumn.ActualWidth > 0)
        {
            _workspaceLayout.EditorAiToolsWidth = Math.Clamp(
                EditorAiToolsColumn.ActualWidth, 340, 720);
        }
    }

    private void ResizeWindowInsideVisibleArea(double requestedWidth, double requestedHeight)
    {
        if (WindowState != WindowState.Normal)
        {
            WindowState = WindowState.Normal;
        }
        var workArea = new Rect(
            SystemParameters.VirtualScreenLeft,
            SystemParameters.VirtualScreenTop,
            SystemParameters.VirtualScreenWidth,
            SystemParameters.VirtualScreenHeight);
        Width = Math.Clamp(requestedWidth, MinWidth, workArea.Width);
        Height = Math.Clamp(requestedHeight, MinHeight, workArea.Height);
        Left = workArea.Left + (workArea.Width - Width) / 2;
        Top = workArea.Top + (workArea.Height - Height) / 2;
    }

    private static WorkspaceLayoutState LoadWorkspaceLayout()
    {
        try
        {
            if (!File.Exists(WorkspaceLayoutStatePath))
            {
                return new WorkspaceLayoutState();
            }
            var loaded = JsonSerializer.Deserialize<WorkspaceLayoutState>(
                File.ReadAllText(WorkspaceLayoutStatePath));
            return loaded is { SchemaVersion: 1 }
                ? loaded
                : new WorkspaceLayoutState();
        }
        catch
        {
            return new WorkspaceLayoutState();
        }
    }

    private void SaveWorkspaceLayout(bool capturePanelSizes = true)
    {
        try
        {
            if (capturePanelSizes)
            {
                CaptureWorkspacePanelSizes();
            }
            var bounds = WindowState == WindowState.Normal
                ? new Rect(Left, Top, ActualWidth, ActualHeight)
                : RestoreBounds;
            if (bounds.Width >= MinWidth && bounds.Height >= MinHeight)
            {
                _workspaceLayout.Left = bounds.Left;
                _workspaceLayout.Top = bounds.Top;
                _workspaceLayout.Width = bounds.Width;
                _workspaceLayout.Height = bounds.Height;
            }
            _workspaceLayout.Maximized = WindowState == WindowState.Maximized;
            Directory.CreateDirectory(
                Path.GetDirectoryName(WorkspaceLayoutStatePath)!);
            File.WriteAllText(
                WorkspaceLayoutStatePath,
                JsonSerializer.Serialize(_workspaceLayout));
        }
        catch (Exception error)
        {
            _diagnostics.Warning(
                "workspace", $"保存桌面工作区布局失败：{error.Message}");
        }
    }

    private void LanguageBox_SelectionChanged(
        object sender,
        SelectionChangedEventArgs e)
    {
        if (_initializing ||
            LanguageBox.SelectedItem is not ComboBoxItem item)
        {
            return;
        }
        var language = Convert.ToString(item.Tag) switch
        {
            "en" => InterfaceLanguage.English,
            "ja" => InterfaceLanguage.Japanese,
            _ => InterfaceLanguage.SimplifiedChinese
        };
        AppLocalization.SetLanguage(language);
        AppLocalization.Apply(this);
        UpdateAuthLocalizedText();
        AccountEmailText.Text = string.IsNullOrWhiteSpace(_authService.GetEmail())
            ? AppLocalization.T("未登录")
            : _authService.GetEmail();
        UpdateExposureReadout();
    }

    private void ShowDestination(Button? navigation, string? destination)
    {
        _currentDestination = destination ?? "capture";
        SetCurrentNavigation(navigation);
        CapturePanel.Visibility =
            destination == "capture"
                ? Visibility.Visible
                : Visibility.Collapsed;
        MonitorDashboard.Visibility =
            destination == "monitor"
                ? Visibility.Visible
                : Visibility.Collapsed;
        LibraryPanel.Visibility =
            destination == "library"
                ? Visibility.Visible
                : Visibility.Collapsed;
        DevicesPanel.Visibility =
            destination == "devices"
                ? Visibility.Visible
                : Visibility.Collapsed;
        EditorPanel.Visibility =
            destination == "editor"
                ? Visibility.Visible
                : Visibility.Collapsed;
        SettingsPanel.Visibility =
            destination == "settings"
                ? Visibility.Visible
                : Visibility.Collapsed;
        if (destination == "settings" && AiDeviceIdText is not null)
        {
            AiDeviceIdText.Text = GetDeviceId();
        }
        var cameraWorkspace = destination is "capture" or "monitor";
        ParameterPanelShell.Visibility =
            cameraWorkspace ? Visibility.Visible : Visibility.Collapsed;
        ParameterSplitter.Visibility =
            cameraWorkspace ? Visibility.Visible : Visibility.Collapsed;
        ApplyResponsiveEditorLayout();
        // v1.5.7 issue 655a0a14: 视频页右侧参数面板强制恒深白字，拍照页仍随主题
        ApplyParameterPanelMonitorTheme(destination == "monitor");
        if (destination == "library")
        {
            RefreshPhotoList();
            LoadCaptureSessionControls();
        }
        if (destination == "devices")
        {
            RefreshRememberedDevices();
        }
        if (destination == "editor")
        {
            // 模式保持稳定：仅在 EditorWorkbenchTool_Click 显式设态，
            // 进入编辑器不再翻转（修复 v1.5.5 每次进入 PRO↔AI 翻转 bug）。
            if (!_editorInAiMode)
            {
                EditorProGrid.Visibility = Visibility.Visible;
                EditorAiGrid.Visibility = Visibility.Collapsed;
                EditorHeaderTitle.Text = AppLocalization.T("专业显影");
                EditorHeaderSubtitle.Text = AppLocalization.T(
                    "分组调整光线、色彩、细节、效果与几何；始终保留原文件。");
                UpdateEditorToolStrip("pro");
            }
            RefreshImageEditor();
        }
        else
        {
            _editorPreviewTimer.Stop();
            _editorPreviewPending = false;
            EditorPreviewImage.Source = null;
            AiPreviewImage.Source = null;
            ClearAiResultFile();
            EditorScopeWaveform.SetData("—", "—", "—");
        }
        ShootingTaskPanel.Visibility =
            destination == "capture"
                ? Visibility.Visible
                : Visibility.Collapsed;
        ProfessionalMonitorPanel.Visibility =
            destination == "monitor"
                ? Visibility.Visible
                : Visibility.Collapsed;
        PreviewDetailText.Text = AppLocalization.T(
            destination == "monitor"
                ? "相机原生 JPEG · 监看输出 · 不修改原片"
                : "相机原生 JPEG · 本地预览");
        ConfigureShutterControl(destination == "monitor");
        ShutterButton.ToolTip = AppLocalization.T(
            destination == "monitor"
                ? (_videoRecording ? "停止录制" : "开始录制")
                : "拍摄照片");
    }

    /// <summary>
    /// v1.5.7 issue 655a0a14: 视频页右侧参数面板强制恒深白字（对齐 Android/Harmony
    /// 视频页参数面板恒深口径）；拍照页与其余页面仍随主题。通过子树 DynamicResource
    /// 覆盖实现，不改全局资源；离开视频页时恢复。
    /// </summary>
    private void ApplyParameterPanelMonitorTheme(bool monitor)
    {
        if (monitor)
        {
            ParameterPanelShell.Background =
                (Brush)FindResource("MonitorWellCardBrush");
            ParameterPanelShell.BorderBrush =
                (Brush)FindResource("MonitorWellSecondaryBrush");
            System.Windows.Documents.TextElement.SetForeground(
                ParameterPanelShell,
                (Brush)FindResource("MonitorWellTextBrush"));
            ParameterPanelShell.Resources["MutedBrush"] =
                (Brush)FindResource("MonitorWellTextBrush");
            ParameterPanelShell.Resources["SurfaceBrush"] =
                (Brush)FindResource("MonitorWellSecondaryBrush");
            ParameterPanelShell.Resources["RuleStrongBrush"] =
                (Brush)FindResource("MonitorWellSecondaryBrush");
        }
        else
        {
            ParameterPanelShell.Background =
                (Brush)FindResource("Paper2Brush");
            ParameterPanelShell.BorderBrush =
                (Brush)FindResource("RuleBrush");
            ParameterPanelShell.ClearValue(
                System.Windows.Documents.TextElement.ForegroundProperty);
            ParameterPanelShell.Resources.Clear();
        }
    }

    private async void VideoFrameRateBox_SelectionChanged(
        object sender,
        SelectionChangedEventArgs e)
    {
        if (_initializing ||
            _configuringVideoControls ||
            VideoFrameRateBox.SelectedItem is not ComboBoxItem item ||
            !double.TryParse(
                Convert.ToString(item.Tag),
                NumberStyles.Float,
                CultureInfo.InvariantCulture,
                out var frameRate))
        {
            return;
        }
        _videoFrameRate = frameRate;
        if (!_videoMode)
        {
            return;
        }
        ConfigureShutterControl(true);
        if (!_camera.IsConnected || _operationInProgress)
        {
            OperationStatusText.Text = AppLocalization.T(
                $"视频曝光参考：{_videoShutterAngle:g}° · {_videoFrameRate:g} fps");
            return;
        }
        var seconds = _videoShutterMode == "angle"
            ? _videoShutterAngle / (360 * _videoFrameRate)
            : _photoShutterSeconds;
        await RunOperationAsync(
            _videoShutterMode == "angle"
                ? $"正在按 {_videoShutterAngle:g}° 换算曝光时间…"
                : $"正在设置视频快门速度 {_photoShutterSeconds:g} s…",
            async token =>
            {
                await _camera.SetParameterAsync(
                    "videoExposureTime",
                    seconds,
                    token);
                OperationStatusText.Text = AppLocalization.T(
                    _videoShutterMode == "angle"
                        ? $"快门角度 {_videoShutterAngle:g}° · {_videoFrameRate:g} fps"
                        : $"快门速度 {_photoShutterSeconds:g} s · {_videoFrameRate:g} fps");
            });
    }

    private void ConfigureShutterControl(bool videoMode)
    {
        _videoMode = videoMode;
        _configuringVideoControls = true;
        try
        {
            ParameterPanelTitle.Text = AppLocalization.T(
                videoMode ? "视频曝光与监看" : "拍摄控制");
            ExposureModeLabel.Text = AppLocalization.T(
                videoMode ? "视频曝光模式" : "拍摄模式");
            VideoFrameRateLabel.Visibility =
                videoMode ? Visibility.Visible : Visibility.Collapsed;
            VideoFrameRateBox.Visibility =
                videoMode ? Visibility.Visible : Visibility.Collapsed;
            ShutterLabel.Text = AppLocalization.T(
                videoMode && _videoShutterMode == "angle" ? "快门角度" : "快门速度");
            VideoShutterModeLabel.Visibility = videoMode ? Visibility.Visible : Visibility.Collapsed;
            VideoShutterModeBox.Visibility = videoMode ? Visibility.Visible : Visibility.Collapsed;
            VideoCodecLabel.Visibility = videoMode ? Visibility.Visible : Visibility.Collapsed;
            VideoCodecBox.Visibility = videoMode ? Visibility.Visible : Visibility.Collapsed;
            VideoLogLabel.Visibility = videoMode ? Visibility.Visible : Visibility.Collapsed;
            VideoLogBox.Visibility = videoMode ? Visibility.Visible : Visibility.Collapsed;
            ExternalRecordingCheck.Visibility =
                videoMode ? Visibility.Visible : Visibility.Collapsed;
            ExternalRecordingHint.Visibility =
                videoMode ? Visibility.Visible : Visibility.Collapsed;
            ShutterBox.Items.Clear();
            if (videoMode && _videoShutterMode == "angle")
            {
                foreach (var angle in new[]
                         {
                             45.0,
                             60.0,
                             72.0,
                             90.0,
                             108.0,
                             120.0,
                             144.0,
                             150.0,
                             172.8,
                             180.0,
                             216.0,
                             240.0,
                             270.0,
                             300.0,
                             324.0,
                             360.0
                         })
                {
                    var seconds = angle / (360 * _videoFrameRate);
                    var denominator = Math.Round(1 / seconds);
                    var option = new ComboBoxItem
                    {
                        Tag = seconds.ToString(
                            "G17",
                            CultureInfo.InvariantCulture),
                        Uid = angle.ToString(
                            "G",
                            CultureInfo.InvariantCulture),
                        Content = $"{angle:g}° · 约 1/{denominator:g} s"
                    };
                    ShutterBox.Items.Add(option);
                    if (Math.Abs(angle - _videoShutterAngle) < 0.01)
                    {
                        ShutterBox.SelectedItem = option;
                    }
                }
            }
            else
            {
                foreach (var seconds in FineShutterValues())
                {
                    var label = seconds < 1
                        ? $"1/{Math.Round(1 / seconds):g} s"
                        : $"{seconds:g} s";
                    var item = new ComboBoxItem
                    {
                        Tag = seconds.ToString(
                            "G17",
                            CultureInfo.InvariantCulture),
                        Content = label
                    };
                    ShutterBox.Items.Add(item);
                    if (Math.Abs(seconds - _photoShutterSeconds) < 0.000001)
                    {
                        ShutterBox.SelectedItem = item;
                    }
                }
            }
            if (ShutterBox.SelectedItem is null && ShutterBox.Items.Count > 0)
            {
                ShutterBox.SelectedIndex = 0;
            }
        }
        finally
        {
            _configuringVideoControls = false;
        }
        UpdateExposureAvailability();
    }

    private async void WirelessButton_Click(object sender, RoutedEventArgs e)
    {
        if (_wirelessServer.IsRunning)
        {
            await _wirelessServer.StopAsync();
            _diagnostics.Info("wireless", "无线收件箱已停止");
            WirelessButton.Content =
                AppLocalization.T("开启无线接收");
            WirelessAddressText.Text = "—";
            OperationStatusText.Text =
                AppLocalization.T("无线收件箱已停止");
            return;
        }
        try
        {
            await _wirelessServer.StartAsync();
            _diagnostics.Info(
                "wireless",
                $"无线收件箱已开启；FTP={_wirelessServer.LocalAddress}:" +
                $"{WirelessTransferServer.FtpPort}；HTTP/WebDAV=" +
                $"{_wirelessServer.LocalAddress}:{WirelessTransferServer.HttpPort}");
            WirelessButton.Content =
                AppLocalization.T("停止无线接收");
            WirelessAddressText.Text =
                $"FTP/PASV  {_wirelessServer.LocalAddress}:" +
                $"{WirelessTransferServer.FtpPort}\n" +
                $"HTTP 上传  http://{_wirelessServer.LocalAddress}:" +
                $"{WirelessTransferServer.HttpPort}/upload/文件名\n" +
                $"WebDAV  http://{_wirelessServer.LocalAddress}:" +
                $"{WirelessTransferServer.HttpPort}/";
            OperationStatusText.Text =
                AppLocalization.T("无线收件箱已开启");
        }
        catch (Exception error)
        {
            _diagnostics.Error("wireless", error.Message);
            ShowError($"无法开启无线收件箱：{error.Message}");
        }
    }

    private void ConfigureFineExposureControls()
    {
        PopulateNumericOptions(
            ApertureBox,
            [
                1.2, 1.4, 1.6, 1.8, 2, 2.2, 2.5, 2.8, 3.2, 3.5,
                4, 4.5, 5, 5.6, 6.3, 7.1, 8, 9, 10, 11, 13, 14,
                16, 18, 20, 22
            ],
            4,
            value => $"f/{value:g}");
        PopulateNumericOptions(
            IsoBox,
            [
                64, 80, 100, 125, 160, 200, 250, 320, 400, 500, 640,
                800, 1000, 1250, 1600, 2000, 2500, 3200, 4000, 5000,
                6400, 8000, 10000, 12800, 16000, 20000, 25600, 32000,
                40000, 51200, 64000, 80000, 102400
            ],
            400,
            value => $"ISO {value:g}");
        PopulateNumericOptions(
            ExposureCompensationBox,
            Enumerable.Range(-15, 31).Select(value => value / 3.0),
            0,
            value => $"{value:+0.0;-0.0;0.0} EV");
    }

    private static void PopulateNumericOptions(
        ComboBox box,
        IEnumerable<double> values,
        double selected,
        Func<double, string> label)
    {
        box.Items.Clear();
        foreach (var value in values)
        {
            var item = new ComboBoxItem
            {
                Tag = value.ToString("G17", CultureInfo.InvariantCulture),
                Content = label(value)
            };
            box.Items.Add(item);
            if (Math.Abs(value - selected) < 0.000001)
            {
                box.SelectedItem = item;
            }
        }
    }

    private static double[] FineShutterValues() =>
    [
        1.0 / 8000, 1.0 / 6400, 1.0 / 5000, 1.0 / 4000,
        1.0 / 3200, 1.0 / 2500, 1.0 / 2000, 1.0 / 1600,
        1.0 / 1250, 1.0 / 1000, 1.0 / 800, 1.0 / 640,
        1.0 / 500, 1.0 / 400, 1.0 / 320, 1.0 / 250,
        1.0 / 200, 1.0 / 160, 1.0 / 125, 1.0 / 100,
        1.0 / 80, 1.0 / 60, 1.0 / 50, 1.0 / 40,
        1.0 / 30, 1.0 / 25, 1.0 / 20, 1.0 / 15,
        1.0 / 13, 1.0 / 10, 1.0 / 8, 1.0 / 6,
        1.0 / 5, 1.0 / 4, 1.0 / 3, 1.0 / 2,
        1, 1.3, 1.6, 2, 2.5, 3.2, 4, 5, 6, 8,
        10, 13, 15, 20, 25, 30
    ];

    private void OpenLogFolder_Click(object sender, RoutedEventArgs e)
    {
        _diagnostics.Info("diagnostics", "用户打开日志目录");
        _diagnostics.OpenDirectory();
    }

    private async void CheckUpdateButton_Click(
        object sender,
        RoutedEventArgs e)
    {
        await CheckForUpdatesAsync(silent: false);
    }

    private async Task CheckForUpdatesAsync(bool silent)
    {
        if (_checkingForUpdates)
        {
            return;
        }
        _checkingForUpdates = true;
        CheckUpdateButton.IsEnabled = false;
        CheckUpdateButton.Content =
            AppLocalization.T("正在检查…");
        if (!silent)
        {
            UpdateStatusText.Text =
                AppLocalization.T("正在检查更新…");
        }
        try
        {
            var update = await _updateService.CheckAsync();
            if (update.IsAvailable)
            {
                _availableUpdateUrl = update.DownloadUrl;
                UpdateStatusText.Text =
                    AppLocalization.T(
                        $"发现新版本 {update.Version}"
                        + (update.Notice is null ? "" : $" · {update.Notice}"));
                OpenUpdateButton.Content =
                    AppLocalization.T($"获取 {update.Version}");
                OpenUpdateButton.Visibility = Visibility.Visible;
            }
            else
            {
                _availableUpdateUrl = null;
                UpdateStatusText.Text =
                    AppLocalization.T(
                        "已是最新版本"
                        + (update.Notice is null ? "" : $" · {update.Notice}"));
                OpenUpdateButton.Visibility = Visibility.Collapsed;
            }
        }
        catch (Exception error)
        {
            _diagnostics.Error("update", $"检查更新失败：{error.Message}");
            if (!silent)
            {
                UpdateStatusText.Text =
                    AppLocalization.T("检查失败，请确认网络后重试");
            }
        }
        finally
        {
            _checkingForUpdates = false;
            CheckUpdateButton.IsEnabled = true;
            CheckUpdateButton.Content =
                AppLocalization.T("检查更新");
        }
    }

    private void OpenUpdateButton_Click(object sender, RoutedEventArgs e)
    {
        var target = _availableUpdateUrl ??
                     "https://github.com/Tauber01/ZENCHE/releases";
        try
        {
            Process.Start(new ProcessStartInfo
            {
                FileName = target,
                UseShellExecute = true
            });
        }
        catch (Exception error)
        {
            _diagnostics.Error("update", $"无法打开更新页：{error.Message}");
            ShowError("无法打开浏览器，请访问 github.com/Tauber01/ZENCHE/releases");
        }
    }

    private void SaveMirrorChyanCdkButton_Click(
        object sender,
        RoutedEventArgs e)
    {
        try
        {
            _updateService.SaveMirrorChyanCdk(MirrorChyanCdkBox.Password);
            UpdateStatusText.Text = AppLocalization.T(
                string.IsNullOrWhiteSpace(MirrorChyanCdkBox.Password)
                    ? "Mirror酱 CDK 已清除"
                    : "Mirror酱 CDK 已安全保存");
        }
        catch (Exception error)
        {
            _diagnostics.Error(
                "update",
                $"无法保存 Mirror酱 CDK：{error.Message}");
            UpdateStatusText.Text =
                AppLocalization.T("Mirror酱 CDK 保存失败");
        }
    }

    private void OpenMirrorChyanButton_Click(
        object sender,
        RoutedEventArgs e)
    {
        try
        {
            Process.Start(new ProcessStartInfo
            {
                FileName = _updateService.MirrorChyanWebsiteUrl,
                UseShellExecute = true
            });
        }
        catch (Exception error)
        {
            _diagnostics.Error(
                "update",
                $"无法打开 Mirror酱：{error.Message}");
            ShowError("无法打开 Mirror酱网站");
        }
    }

    private void ViewLogs_Click(object sender, RoutedEventArgs e)
    {
        _diagnostics.Info("diagnostics", "用户查询近期日志");
        var viewer = new Window
        {
            Owner = this,
            Title = "帧澈 ZENCHE · 诊断日志查询",
            Width = 820,
            Height = 560,
            MinWidth = 560,
            MinHeight = 360,
            Background = (Brush)FindResource("PaperBrush"),
            WindowStartupLocation = WindowStartupLocation.CenterOwner
        };
        var logGrid = new Grid { Margin = new Thickness(20) };
        logGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        logGrid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
        logGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        var logHeader = new StackPanel { Margin = new Thickness(0, 0, 0, 12) };
        logHeader.Children.Add(new TextBlock
        {
            Text = "诊断日志查询",
            Style = (Style)FindResource("SettingsLogTitle")
        });
        logHeader.Children.Add(new TextBlock
        {
            Text = "显示近期脱敏日志；刷新可读取最新记录。",
            Style = (Style)FindResource("SettingsFeedbackBody"),
            Margin = new Thickness(0, 2, 0, 0)
        });
        logGrid.Children.Add(logHeader);
        var logBox = new TextBox
        {
            Text = _diagnostics.RecentText(12_000),
            Style = (Style)FindResource("SettingsLogBox"),
            IsReadOnly = true,
            AcceptsReturn = true,
            TextWrapping = TextWrapping.NoWrap,
            HorizontalScrollBarVisibility = ScrollBarVisibility.Auto,
            VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
            Background = (Brush)FindResource("LogBgBrush"),
            Foreground = (Brush)FindResource("LogTextBrush"),
            BorderBrush = (Brush)FindResource("RuleBrush"),
            BorderThickness = new Thickness(1),
            Padding = new Thickness(14)
        };
        Grid.SetRow(logBox, 1);
        logGrid.Children.Add(logBox);
        var logActions = new DockPanel { Margin = new Thickness(0, 12, 0, 0) };
        var refreshBtn = new Button
        {
            Content = "刷新",
            Style = (Style)FindResource("ButtonBase"),
            Width = 100
        };
        refreshBtn.Click += (_, _) =>
        {
            logBox.Text = _diagnostics.RecentText(12_000);
        };
        DockPanel.SetDock(refreshBtn, Dock.Left);
        logActions.Children.Add(refreshBtn);
        var closeLogBtn = new Button
        {
            Content = "关闭",
            Style = (Style)FindResource("PrimaryButton"),
            Width = 100
        };
        closeLogBtn.Click += (_, _) => viewer.Close();
        DockPanel.SetDock(closeLogBtn, Dock.Right);
        logActions.Children.Add(closeLogBtn);
        Grid.SetRow(logActions, 2);
        logGrid.Children.Add(logActions);
        viewer.Content = logGrid;
        viewer.ShowDialog();
    }

    private void ReportIssue_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            _diagnostics.OpenGitHubIssue();
        }
        catch (Exception error)
        {
            _diagnostics.Error(
                "diagnostics",
                $"无法打开 GitHub Issue 提交页：{error.Message}");
            ShowError("无法打开浏览器，请访问 github.com/Tauber01/ZENCHE/issues");
        }
    }

    private void DonationButton_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            var image = new BitmapImage(
                new Uri(
                    "pack://application:,,,/Assets/wechat-donation.png",
                    UriKind.Absolute));
            var root = new Grid { Margin = new Thickness(24) };
            root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            root.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
            root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });

            var header = new StackPanel { Margin = new Thickness(0, 0, 0, 14) };
            header.Children.Add(new TextBlock
            {
                Text = AppLocalization.T("爱发电赞助"),
                Style = (Style)FindResource("DisplayText")
            });
            header.Children.Add(new TextBlock
            {
                Text = AppLocalization.T(
                    "扫描二维码，或打开爱发电主页支持项目。"),
                FontSize = 12,
                Foreground = (Brush)FindResource("MutedBrush"),
                Margin = new Thickness(0, 4, 0, 0)
            });
            root.Children.Add(header);

            var feedbackCard = CreateFastFeedbackCard();
            Grid.SetRow(feedbackCard, 1);
            root.Children.Add(feedbackCard);

            var imageCard = new Border
            {
                Background = (Brush)FindResource("SurfaceBrush"),
                BorderBrush = (Brush)FindResource("RuleBrush"),
                BorderThickness = new Thickness(1),
                CornerRadius = (CornerRadius)FindResource("CornerRadius12"),
                Padding = new Thickness(8),
                Child = new Image
                {
                    Source = image,
                    Stretch = Stretch.Uniform
                }
            };
            imageCard.Margin = new Thickness(0, 14, 0, 0);
            Grid.SetRow(imageCard, 2);
            root.Children.Add(imageCard);

            var footer = new TextBlock
            {
                Text = AppLocalization.T(
                    "软件功能永久免费，赞助为自愿行为。\n" +
                    "赞助不会解锁软件功能，也不影响公开 Issue 的处理。"),
                FontSize = 11,
                Foreground = (Brush)FindResource("MutedBrush"),
                Margin = new Thickness(0, 12, 0, 0),
                TextAlignment = TextAlignment.Left
            };
            Grid.SetRow(footer, 3);
            root.Children.Add(footer);

            var dialog = new Window
            {
                Owner = this,
                Title = AppLocalization.T("爱发电赞助"),
                Width = 520,
                Height = 780,
                MinWidth = 360,
                MinHeight = 620,
                Background = (Brush)FindResource("PaperBrush"),
                WindowStartupLocation = WindowStartupLocation.CenterOwner,
                Content = root
            };
            dialog.ShowDialog();
        }
        catch (Exception error)
        {
            _diagnostics.Error(
                "support",
                $"无法显示赞助二维码：{error.Message}");
            ShowError("无法显示赞助二维码，请稍后重试。");
        }
    }

    private void OpenAfdianButton_Click(object sender, RoutedEventArgs e)
    {
        OpenAfdian();
    }

    private static void OpenAfdian()
    {
        Process.Start(new ProcessStartInfo
        {
            FileName = AfdianUrl,
            UseShellExecute = true
        });
    }

    private Border CreateFastFeedbackCard()
    {
        var copy = new StackPanel
        {
            Margin = new Thickness(0, 0, 16, 0)
        };
        copy.Children.Add(new TextBlock
        {
            Text = AppLocalization.T("快速问题反馈"),
            FontSize = 15,
            FontWeight = FontWeights.Bold
        });
        copy.Children.Add(new TextBlock
        {
            Text = AppLocalization.T(
                "公开问题可继续在 GitHub 免费提交；在爱发电赞助后，可获取快速问题反馈渠道。"),
            FontSize = 12,
            Foreground = (Brush)FindResource("MutedBrush"),
            Margin = new Thickness(0, 4, 0, 0),
            TextWrapping = TextWrapping.Wrap
        });
        copy.Children.Add(new TextBlock
        {
            Text = AppLocalization.T("官方 QQ 群：165315727"),
            Style = (Style)FindResource("FastFeedbackMono"),
            FontWeight = FontWeights.Bold,
            Foreground = (Brush)FindResource("AccentBrush"),
            Margin = new Thickness(0, 6, 0, 0)
        });

        var openButton = new Button
        {
            Content = AppLocalization.T("打开爱发电"),
            Style = (Style)FindResource("ButtonBase"),
            MinWidth = 124,
            VerticalAlignment = VerticalAlignment.Center
        };
        openButton.Click += (_, _) => OpenAfdian();

        var grid = new Grid();
        grid.ColumnDefinitions.Add(new ColumnDefinition());
        grid.ColumnDefinitions.Add(new ColumnDefinition
        {
            Width = GridLength.Auto
        });
        grid.Children.Add(copy);
        Grid.SetColumn(openButton, 1);
        grid.Children.Add(openButton);

        return new Border
        {
            Background = (Brush)FindResource("AccentSoftBrush"),
            BorderBrush = (Brush)FindResource("PhotoSoftBorderBrush"),
            BorderThickness = new Thickness(1),
            CornerRadius = (CornerRadius)FindResource("CornerRadius12"),
            Padding = new Thickness(14),
            Child = grid
        };
    }

    private void ShowLaunchAnnouncementIfNeeded()
    {
        if (_announcementShownThisLaunch)
        {
            return;
        }
        _announcementShownThisLaunch = true;
        var version = _updateService.CurrentVersion;
        try
        {
            if (File.Exists(AnnouncementStatePath) &&
                string.Equals(
                    File.ReadAllText(AnnouncementStatePath).Trim(),
                    version,
                    StringComparison.Ordinal))
            {
                return;
            }
        }
        catch (Exception error)
        {
            _diagnostics.Warning(
                "announcement",
                $"读取公告提醒设置失败：{error.Message}");
        }

        // D1 1.5.8：启动路径公告区整体降级保护——UI 构建（FindResource/
        // BitmapImage/资源查找）或 ShowDialog 展示失败时只记诊断日志，
        // 不弹窗、不阻断启动。
        try
        {
        var doNotRemind = new CheckBox
        {
            Content = AppLocalization.T(
                "不再提醒（软件更新后仍会显示）"),
            FontSize = 12, // v1.5.7 F5 二轮打回修复: CheckBox 不能用 TextBlock 样式（运行时崩溃），恢复字号字面量（裁决对齐 12）
            VerticalContentAlignment = VerticalAlignment.Center
        };
        var closeButton = new Button
        {
            Content = AppLocalization.T("关闭公告"),
            MinWidth = 110,
            Height = 38,
            Padding = new Thickness(14, 0, 14, 0)
        };
        var footer = new DockPanel
        {
            Margin = new Thickness(0, 16, 0, 0)
        };
        DockPanel.SetDock(closeButton, Dock.Right);
        footer.Children.Add(closeButton);
        footer.Children.Add(doNotRemind);

        var body = new StackPanel();
        body.Children.Add(new TextBlock
        {
            Text = AppLocalization.T("本次更新"),
            Style = (Style)FindResource("AnnouncementSection"),
            Margin = new Thickness(0, 0, 0, 8)
        });
        body.Children.Add(new TextBlock
        {
            Text = AppLocalization.T(
                "• 新增“下载到本地”：联机拍摄、相机卡下载、AI 修图/生图与专业编辑结果都可以通过系统保存器另存到用户选择的位置。\n" +
                "• 五端文件库均提供统一入口；支持应用内预览的页面也提供快捷入口。AI 与专业编辑提供直达入口；“保存到系统相册”继续作为独立操作保留。\n" +
                "• 导出只创建副本，不移动或删除 ZENCHE 文件库中的源文件；macOS 与 Windows 的 AI 修图也改为始终生成新文件，不再覆盖原图。\n" +
                "• 用户取消时不显示错误；只有复制完成、同步落盘且大小校验通过后才显示成功。失败时会清理临时文件，并尽力删除未完成的目标。\n" +
                "• GitHub Release 提供 1.5.13 五端安装包，官网自动更新仍保持 1.5.10。各平台签名与安装边界，以及系统保存器、权限、同名文件、大文件和存储空间不足等场景，请参阅发布说明并按需真机验证。"),
            Style = (Style)FindResource("AnnouncementBody"),
            TextWrapping = TextWrapping.Wrap,
            LineHeight = 22,
            Margin = new Thickness(0, 0, 0, 18)
        });

        var warning = new StackPanel
        {
            Margin = new Thickness(0),
        };
        warning.Children.Add(new TextBlock
        {
            Text = AppLocalization.T("谨防诈骗"),
            Style = (Style)FindResource("AnnouncementTitle"),
            Foreground = (Brush)FindResource("WarnDeepBrush"),
            Margin = new Thickness(0, 0, 0, 7)
        });
        warning.Children.Add(new TextBlock
        {
            Text = AppLocalization.T(
                "帧澈 ZENCHE 是开源免费项目。任何声称“进群领取软件”" +
                "或要求付费购买软件的人都是骗子，请勿转账。"),
            Style = (Style)FindResource("AnnouncementBody"),
            FontWeight = FontWeights.SemiBold, // macOS 基准 body 12+semibold（SettingsSheet.swift:1003）
            Foreground = (Brush)FindResource("WarnDarkBrush"),
            TextWrapping = TextWrapping.Wrap,
            LineHeight = 21
        });
        body.Children.Add(new Border
        {
            Background = (Brush)FindResource("WarnBgBrush"),
            BorderBrush = (Brush)FindResource("WarnBgSoftBrush"),
            BorderThickness = new Thickness(1),
            CornerRadius = (CornerRadius)FindResource("CornerRadius12"),
            Padding = new Thickness(16),
            Margin = new Thickness(0, 0, 0, 18),
            Child = warning
        });

        var sponsorCard = new Border
        {
            Background = (Brush)FindResource("SurfaceBrush"),
            BorderBrush = (Brush)FindResource("RuleBrush"),
            BorderThickness = new Thickness(1),
            CornerRadius = (CornerRadius)FindResource("CornerRadius12"),
            Padding = new Thickness(16),
            Child = new StackPanel
            {
                Children =
                {
                    new TextBlock
                    {
                        Text = AppLocalization.T("自愿赞助"),
                        Style = (Style)FindResource("AnnouncementTitle"),
                        Margin = new Thickness(0, 0, 0, 6)
                    },
                    new TextBlock
                    {
                        Text = AppLocalization.T(
                            "如果本项目对你有帮助，欢迎自愿打赏；软件功能永久免费。"),
                        Style = (Style)FindResource("AnnouncementSub"),
                        Foreground = (Brush)FindResource("MutedBrush"),
                        TextWrapping = TextWrapping.Wrap,
                        Margin = new Thickness(0, 0, 0, 10)
                    },
                }
            }
        };
        var sponsorContent = (StackPanel)sponsorCard.Child;
        var sponsorFeedback = CreateFastFeedbackCard();
        sponsorFeedback.Margin = new Thickness(0, 0, 0, 14);
        sponsorContent.Children.Add(sponsorFeedback);
        sponsorContent.Children.Add(new Image
        {
            Source = new BitmapImage(
                new Uri(
                    "pack://application:,,,/Assets/wechat-donation.png",
                    UriKind.Absolute)),
            MaxHeight = 470,
            Stretch = Stretch.Uniform,
            HorizontalAlignment = HorizontalAlignment.Center
        });
        body.Children.Add(sponsorCard);

        var header = new StackPanel
        {
            Margin = new Thickness(0, 0, 0, 14)
        };
        header.Children.Add(new TextBlock
        {
            Text = AppLocalization.T("更新公告"),
            Style = (Style)FindResource("AnnouncementHeading")
        });
        header.Children.Add(new TextBlock
        {
            Text = $"{AppLocalization.T("当前版本")} {version}",
            FontSize = 12,
            FontFamily = new FontFamily("Consolas"),
            Foreground = (Brush)FindResource("MutedBrush")
        });

        var root = new DockPanel
        {
            Margin = new Thickness(24)
        };
        DockPanel.SetDock(header, Dock.Top);
        DockPanel.SetDock(footer, Dock.Bottom);
        root.Children.Add(header);
        root.Children.Add(footer);
        root.Children.Add(new ScrollViewer
        {
            Content = body,
            VerticalScrollBarVisibility = ScrollBarVisibility.Auto
        });

        var dialog = new Window
        {
            Owner = this,
            Title = AppLocalization.T("更新公告"),
            Width = 660,
            Height = 820,
            MinWidth = 460,
            MinHeight = 620,
            Background = (Brush)FindResource("PaperBrush"),
            WindowStartupLocation = WindowStartupLocation.CenterOwner,
            Content = root
        };
        closeButton.Click += (_, _) => dialog.Close();
        dialog.Closed += (_, _) =>
        {
            if (doNotRemind.IsChecked != true)
            {
                return;
            }
            try
            {
                Directory.CreateDirectory(
                    Path.GetDirectoryName(AnnouncementStatePath)!);
                File.WriteAllText(AnnouncementStatePath, version);
            }
            catch (Exception error)
            {
                _diagnostics.Warning(
                    "announcement",
                    $"保存公告提醒设置失败：{error.Message}");
            }
        };
        dialog.ShowDialog();
        }
        catch (Exception error)
        {
            _diagnostics.Warning(
                "announcement",
                $"展示更新公告失败，已跳过：{error}");
        }
    }

    private void OpenPhotoFolder_Click(object sender, RoutedEventArgs e)
    {
        Process.Start(new ProcessStartInfo
        {
            FileName = _library.DirectoryPath,
            UseShellExecute = true
        });
    }

    /// <summary>
    /// E6 延时合成：文件库工具条入口。帧多选（按文件名排序）+ 帧率 24/25/30
    /// → TimelapseComposer（MediaComposition H.264 MP4）→ CaptureWorkflow 入库。
    /// TBC-awaiting-hardware。
    /// </summary>
    private async void ComposeTimelapse_Click(object sender, RoutedEventArgs e)
    {
        var photos = _library.List()
            .Where(item => !item.IsVideo)
            .OrderBy(item => item.Name, StringComparer.OrdinalIgnoreCase)
            .ToList();
        if (photos.Count == 0)
        {
            OperationStatusText.Text = AppLocalization.T(
                "文件库暂无照片，请先拍摄或导入。");
            return;
        }

        var panel = new StackPanel { Margin = new Thickness(20) };
        panel.Children.Add(new TextBlock
        {
            Text = "合成延时视频",
            FontSize = 20,
            FontWeight = FontWeights.SemiBold
        });
        panel.Children.Add(new TextBlock
        {
            Text = "选择序列帧（按文件名排序合成）并设置帧率。损坏帧自动跳过。",
            Foreground = (Brush)FindResource("MutedBrush"),
            Margin = new Thickness(0, 4, 0, 12)
        });

        var checkboxes = new List<CheckBox>();
        var listPanel = new StackPanel { Margin = new Thickness(0, 0, 0, 12) };
        foreach (var photo in photos)
        {
            var check = new CheckBox
            {
                Content = $"{photo.Name}  ·  {photo.Detail}",
                IsChecked = false,
                Margin = new Thickness(0, 3, 0, 3)
            };
            checkboxes.Add(check);
            listPanel.Children.Add(check);
        }
        panel.Children.Add(new ScrollViewer
        {
            MaxHeight = 320,
            VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
            Content = listPanel
        });

        var frameRateBox = new ComboBox
        {
            Width = 140,
            HorizontalAlignment = HorizontalAlignment.Left,
            Margin = new Thickness(0, 0, 0, 12)
        };
        frameRateBox.Items.Add("24 fps");
        frameRateBox.Items.Add("25 fps");
        frameRateBox.Items.Add("30 fps");
        frameRateBox.SelectedIndex = 0;
        panel.Children.Add(new StackPanel
        {
            Orientation = Orientation.Horizontal,
            Children =
            {
                new TextBlock
                {
                    Text = "帧率：",
                    VerticalAlignment = VerticalAlignment.Center
                },
                frameRateBox
            }
        });

        var progress = new ProgressBar
        {
            Height = 18,
            Minimum = 0,
            Maximum = 100,
            Margin = new Thickness(0, 12, 0, 6),
            Visibility = Visibility.Collapsed
        };
        var progressText = new TextBlock
        {
            Foreground = (Brush)FindResource("MutedBrush"),
            Margin = new Thickness(0, 0, 0, 6),
            Visibility = Visibility.Collapsed
        };
        var resultText = new TextBlock
        {
            Foreground = (Brush)FindResource("PositiveBrush"),
            Margin = new Thickness(0, 6, 0, 0),
            TextWrapping = TextWrapping.Wrap
        };
        var errorText = new TextBlock
        {
            Foreground = (Brush)FindResource("DangerBrush"),
            Margin = new Thickness(0, 6, 0, 0),
            TextWrapping = TextWrapping.Wrap
        };
        panel.Children.Add(progress);
        panel.Children.Add(progressText);
        panel.Children.Add(resultText);
        panel.Children.Add(errorText);

        var startButton = new Button
        {
            Content = "开始合成",
            Style = (Style)FindResource("PrimaryButton"),
            Margin = new Thickness(0, 12, 8, 0),
            HorizontalAlignment = HorizontalAlignment.Right
        };
        var cancelButton = new Button
        {
            Content = "取消",
            Style = (Style)FindResource("ButtonBase"),
            Margin = new Thickness(0, 12, 0, 0),
            HorizontalAlignment = HorizontalAlignment.Right,
            Visibility = Visibility.Collapsed
        };
        var closeButton = new Button
        {
            Content = "关闭",
            Style = (Style)FindResource("ButtonBase"),
            Margin = new Thickness(8, 12, 0, 0),
            HorizontalAlignment = HorizontalAlignment.Right
        };
        panel.Children.Add(new StackPanel
        {
            Orientation = Orientation.Horizontal,
            HorizontalAlignment = HorizontalAlignment.Right,
            Children = { startButton, cancelButton, closeButton }
        });

        var dialog = new Window
        {
            Owner = this,
            Title = "帧澈 ZENCHE · 合成延时视频",
            Width = 640,
            Height = 620,
            WindowStartupLocation = WindowStartupLocation.CenterOwner,
            ResizeMode = ResizeMode.NoResize,
            Background = (Brush)FindResource("PaperBrush"),
            Content = panel
        };
        closeButton.Click += (_, _) => dialog.Close();

        var running = false;
        var cancelled = false;
        startButton.Click += async (_, _) =>
        {
            if (running)
            {
                return;
            }
            var selected = new List<string>();
            for (var i = 0; i < checkboxes.Count; i++)
            {
                if (checkboxes[i].IsChecked == true)
                {
                    selected.Add(photos[i].Path);
                }
            }
            if (selected.Count == 0)
            {
                errorText.Text = "请至少选择一帧。";
                return;
            }
            running = true;
            cancelled = false;
            progress.Value = 0;
            progress.Visibility = Visibility.Visible;
            progressText.Visibility = Visibility.Visible;
            startButton.Visibility = Visibility.Collapsed;
            cancelButton.Visibility = Visibility.Visible;
            resultText.Text = "";
            errorText.Text = "";

            var fps = new[] { 24, 25, 30 }[frameRateBox.SelectedIndex];
            var temporary = Path.Combine(
                Path.GetTempPath(),
                $"timelapse-{Guid.NewGuid():N}.mp4");
            try
            {
                var composer = new TimelapseComposer();
                var composeResult = await composer.ComposeAsync(
                    selected,
                    temporary,
                    new TimelapseComposer.Options(fps),
                    () => cancelled,
                    (done, total) =>
                    {
                        progress.Dispatcher.Invoke(() =>
                        {
                            progress.Value = total == 0
                                ? 0
                                : done * 100.0 / total;
                            progressText.Text = $"{done}/{total}";
                        });
                    });
                var destination = await _workflow.StoreTimelapseVideoAsync(
                    temporary,
                    "延时合成");
                RefreshPhotoList();
                progress.Visibility = Visibility.Collapsed;
                progressText.Visibility = Visibility.Collapsed;
                resultText.Text =
                    $"已合成 {composeResult.FramesWritten} 帧" +
                    (composeResult.SkippedFrames > 0
                        ? $"（跳过 {composeResult.SkippedFrames} 个损坏帧）"
                        : "") +
                    $" → {Path.GetFileName(destination)}";
            }
            catch (OperationCanceledException)
            {
                errorText.Text = "已取消";
            }
            catch (Exception error)
            {
                errorText.Text = $"视频编码失败：{error.Message}";
            }
            finally
            {
                running = false;
                startButton.Visibility = Visibility.Visible;
                cancelButton.Visibility = Visibility.Collapsed;
                try
                {
                    if (File.Exists(temporary))
                    {
                        File.Delete(temporary);
                    }
                }
                catch (IOException)
                {
                    // 临时文件清理失败可忽略。
                }
            }
        };
        cancelButton.Click += (_, _) => cancelled = true;

        dialog.ShowDialog();
    }


    /// <summary>
    /// E7 焦点合成：文件库工具条入口。帧多选（按文件名排序）
    /// → FocusStackComposer（逐像素清晰度融合 JPEG）→ CaptureWorkflow 入库。
    /// TBC-awaiting-hardware。
    /// </summary>
    private async void ComposeFocusStack_Click(object sender, RoutedEventArgs e)
    {
        var photos = _library.List()
            .Where(item => !item.IsVideo)
            .OrderBy(item => item.Name, StringComparer.OrdinalIgnoreCase)
            .ToList();
        if (photos.Count == 0)
        {
            OperationStatusText.Text = AppLocalization.T(
                "文件库暂无照片，请先拍摄或导入。");
            return;
        }

        var panel = new StackPanel { Margin = new Thickness(20) };
        panel.Children.Add(new TextBlock
        {
            Text = "焦点合成",
            FontSize = 20,
            FontWeight = FontWeights.SemiBold
        });
        panel.Children.Add(new TextBlock
        {
            Text = "选择焦点包围序列帧（按文件名排序合成，逐像素取最清晰帧融合）。损坏帧自动跳过。",
            Foreground = (Brush)FindResource("MutedBrush"),
            Margin = new Thickness(0, 4, 0, 12)
        });

        var checkboxes = new List<CheckBox>();
        var listPanel = new StackPanel { Margin = new Thickness(0, 0, 0, 12) };
        foreach (var photo in photos)
        {
            var check = new CheckBox
            {
                Content = $"{photo.Name}  ·  {photo.Detail}",
                IsChecked = false,
                Margin = new Thickness(0, 3, 0, 3)
            };
            checkboxes.Add(check);
            listPanel.Children.Add(check);
        }
        panel.Children.Add(new ScrollViewer
        {
            MaxHeight = 320,
            VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
            Content = listPanel
        });

        var progress = new ProgressBar
        {
            Height = 18,
            Minimum = 0,
            Maximum = 100,
            Margin = new Thickness(0, 12, 0, 6),
            Visibility = Visibility.Collapsed
        };
        var progressText = new TextBlock
        {
            Foreground = (Brush)FindResource("MutedBrush"),
            Margin = new Thickness(0, 0, 0, 6),
            Visibility = Visibility.Collapsed
        };
        var resultText = new TextBlock
        {
            Foreground = (Brush)FindResource("PositiveBrush"),
            Margin = new Thickness(0, 6, 0, 0),
            TextWrapping = TextWrapping.Wrap
        };
        var errorText = new TextBlock
        {
            Foreground = (Brush)FindResource("DangerBrush"),
            Margin = new Thickness(0, 6, 0, 0),
            TextWrapping = TextWrapping.Wrap
        };
        panel.Children.Add(progress);
        panel.Children.Add(progressText);
        panel.Children.Add(resultText);
        panel.Children.Add(errorText);

        var startButton = new Button
        {
            Content = "开始合成",
            Style = (Style)FindResource("PrimaryButton"),
            Margin = new Thickness(0, 12, 8, 0),
            HorizontalAlignment = HorizontalAlignment.Right
        };
        var cancelButton = new Button
        {
            Content = "取消",
            Style = (Style)FindResource("ButtonBase"),
            Margin = new Thickness(0, 12, 0, 0),
            HorizontalAlignment = HorizontalAlignment.Right,
            Visibility = Visibility.Collapsed
        };
        var closeButton = new Button
        {
            Content = "关闭",
            Style = (Style)FindResource("ButtonBase"),
            Margin = new Thickness(8, 12, 0, 0),
            HorizontalAlignment = HorizontalAlignment.Right
        };
        panel.Children.Add(new StackPanel
        {
            Orientation = Orientation.Horizontal,
            HorizontalAlignment = HorizontalAlignment.Right,
            Children = { startButton, cancelButton, closeButton }
        });

        var dialog = new Window
        {
            Owner = this,
            Title = "帧澈 ZENCHE · 焦点合成",
            Width = 640,
            Height = 580,
            WindowStartupLocation = WindowStartupLocation.CenterOwner,
            ResizeMode = ResizeMode.NoResize,
            Background = (Brush)FindResource("PaperBrush"),
            Content = panel
        };
        closeButton.Click += (_, _) => dialog.Close();

        var running = false;
        var cancelled = false;
        startButton.Click += async (_, _) =>
        {
            if (running)
            {
                return;
            }
            var selected = new List<string>();
            for (var i = 0; i < checkboxes.Count; i++)
            {
                if (checkboxes[i].IsChecked == true)
                {
                    selected.Add(photos[i].Path);
                }
            }
            if (selected.Count < 2)
            {
                errorText.Text = "焦点合成需要至少选择两帧。";
                return;
            }
            running = true;
            cancelled = false;
            progress.Value = 0;
            progress.Visibility = Visibility.Visible;
            progressText.Visibility = Visibility.Visible;
            startButton.Visibility = Visibility.Collapsed;
            cancelButton.Visibility = Visibility.Visible;
            resultText.Text = "";
            errorText.Text = "";

            var temporary = Path.Combine(
                Path.GetTempPath(),
                $"focusstack-{Guid.NewGuid():N}.jpg");
            try
            {
                var composer = new FocusStackComposer();
                var composeResult = await composer.ComposeAsync(
                    selected,
                    temporary,
                    () => cancelled,
                    (done, total) =>
                    {
                        progress.Dispatcher.Invoke(() =>
                        {
                            progress.Value = total == 0
                                ? 0
                                : done * 100.0 / total;
                            progressText.Text = $"{done}/{total}";
                        });
                    });
                var destination = await _workflow.StoreFocusStackAsync(
                    temporary,
                    "焦点合成",
                    composeResult.SourcesUsed);
                RefreshPhotoList();
                progress.Visibility = Visibility.Collapsed;
                progressText.Visibility = Visibility.Collapsed;
                resultText.Text =
                    $"已合成 {composeResult.SourcesUsed} 帧" +
                    (composeResult.SkippedFrames > 0
                        ? $"（跳过 {composeResult.SkippedFrames} 个损坏帧）"
                        : "") +
                    $" → {Path.GetFileName(destination)}";
            }
            catch (OperationCanceledException)
            {
                errorText.Text = "已取消";
            }
            catch (Exception error)
            {
                errorText.Text = $"焦点合成失败：{error.Message}";
            }
            finally
            {
                running = false;
                startButton.Visibility = Visibility.Visible;
                cancelButton.Visibility = Visibility.Collapsed;
                try
                {
                    if (File.Exists(temporary))
                    {
                        File.Delete(temporary);
                    }
                }
                catch (IOException)
                {
                    // 临时文件清理失败可忽略。
                }
            }
        };
        cancelButton.Click += (_, _) => cancelled = true;

        dialog.ShowDialog();
    }

    private void OpenOwnerAlbum_Click(object sender, RoutedEventArgs e)
    {
        RefreshPhotoList();
        OperationStatusText.Text = AppLocalization.T(
            "已刷新系统相册与 帧澈 ZENCHE 文件库");
    }

    private void LinkCloudDrive_Click(object sender, RoutedEventArgs e)
    {
        ShowCloudDriveGuide();
    }

    private async void OpenCloudFilePicker()
    {
        var dialog = new OpenFileDialog
        {
            Title = "从网盘选择照片或视频",
            Filter =
                "照片与视频|*.jpg;*.jpeg;*.png;*.heic;*.heif;*.tif;*.tiff;*.nef;*.nrw;*.mp4;*.mov;*.m4v|" +
                "所有文件|*.*",
            Multiselect = true,
            CheckFileExists = true
        };
        if (dialog.ShowDialog(this) != true)
        {
            return;
        }
        try
        {
            var pairNames = new Dictionary<string, string>(
                StringComparer.OrdinalIgnoreCase);
            var imported = new List<string>();
            foreach (var source in dialog.FileNames)
            {
                var pairKey = Path.GetFileNameWithoutExtension(source);
                if (!pairNames.TryGetValue(pairKey, out var reservedBase))
                {
                    reservedBase = _workflow.ReserveBaseName("Imported");
                    pairNames[pairKey] = reservedBase;
                }
                imported.Add(await _workflow.ImportAsync(
                    source,
                    "Imported",
                    reservedBase));
            }
            RefreshPhotoList();
            OperationStatusText.Text = AppLocalization.T(
                imported.Count > 0
                    ? $"已从网盘加入 {imported.Count} 张照片"
                    : "没有可加入文件库的照片");
        }
        catch (Exception error)
        {
            ShowError($"无法从网盘加入照片：{error.Message}");
        }
    }

    private void ShowCloudDriveGuide()
    {
        var guide = new Window
        {
            Owner = this,
            Title = "链接网盘",
            Width = 660,
            Height = 720,
            MinWidth = 560,
            MinHeight = 560,
            Background = (Brush)FindResource("PaperBrush"),
            WindowStartupLocation = WindowStartupLocation.CenterOwner
        };
        var root = new Grid
        {
            Margin = new Thickness(26)
        };
        root.RowDefinitions.Add(new RowDefinition
        {
            Height = GridLength.Auto
        });
        root.RowDefinitions.Add(new RowDefinition
        {
            Height = new GridLength(1, GridUnitType.Star)
        });
        root.RowDefinitions.Add(new RowDefinition
        {
            Height = GridLength.Auto
        });
        var header = new StackPanel();
        header.Children.Add(new TextBlock
        {
            Text = "链接网盘",
            Style = (Style)FindResource("DisplayText") // v1.5.7 F5: FontSize=26 与 DisplayText 样式等值冗余，删除（只归档不改值）
        });
        header.Children.Add(new TextBlock
        {
            Text =
                "帧澈 ZENCHE 不代管网盘账号或密码。先在对应客户端登录，" +
                "再通过系统文件选择器从下载或同步目录加入媒体。",
            Foreground = (Brush)FindResource("MutedBrush"),
            TextWrapping = TextWrapping.Wrap,
            Margin = new Thickness(0, 8, 0, 18)
        });
        root.Children.Add(header);

        var providers = new StackPanel();
        AddCloudProvider(
            providers,
            "百度网盘",
            "安装客户端后，从下载或同步目录选择。",
            "https://pan.baidu.com/");
        AddCloudProvider(
            providers,
            "阿里云盘",
            "支持 Windows 桌面端；先下载或同步媒体。",
            "https://www.alipan.com/");
        AddCloudProvider(
            providers,
            "腾讯微云",
            "从微云客户端把文件下载到资源管理器。",
            "https://www.weiyun.com/");
        AddCloudProvider(
            providers,
            "夸克网盘",
            "使用桌面客户端下载到本机目录。",
            "https://pan.quark.cn/");
        AddCloudProvider(
            providers,
            "迅雷云盘",
            "通过迅雷客户端下载后从资源管理器选择。",
            "https://pan.xunlei.com/");
        AddCloudProvider(
            providers,
            "115",
            "在“存储”中下载文件后从本机选择。",
            "https://115.com/");
        var scroll = new ScrollViewer
        {
            Content = providers,
            VerticalScrollBarVisibility = ScrollBarVisibility.Auto
        };
        Grid.SetRow(scroll, 1);
        root.Children.Add(scroll);

        var actions = new DockPanel
        {
            Margin = new Thickness(0, 18, 0, 0)
        };
        var close = new Button
        {
            Content = "关闭",
            MinWidth = 100,
            Height = 40,
            Style = (Style)FindResource("ButtonBase")
        };
        close.Click += (_, _) => guide.Close();
        DockPanel.SetDock(close, Dock.Left);
        actions.Children.Add(close);
        var choose = new Button
        {
            Content = "选择文件并加入",
            MinWidth = 168,
            Height = 40,
            Style = (Style)FindResource("PrimaryButton")
        };
        choose.Click += (_, _) =>
        {
            guide.Close();
            OpenCloudFilePicker();
        };
        DockPanel.SetDock(choose, Dock.Right);
        actions.Children.Add(choose);
        Grid.SetRow(actions, 2);
        root.Children.Add(actions);
        guide.Content = root;
        guide.ShowDialog();
    }

    private void AddCloudProvider(
        Panel parent,
        string name,
        string note,
        string url)
    {
        var button = new Button
        {
            Content = new StackPanel
            {
                Children =
                {
                    new TextBlock
                    {
                        Text = name + "  ↗",
                        FontWeight = FontWeights.SemiBold
                    },
                    new TextBlock
                    {
                        Text = note,
                        Foreground = (Brush)FindResource("MutedBrush"),
                        TextWrapping = TextWrapping.Wrap,
                        Margin = new Thickness(0, 3, 0, 0)
                    }
                }
            },
            HorizontalContentAlignment = HorizontalAlignment.Left,
            MinHeight = 64,
            Margin = new Thickness(0, 0, 0, 8),
            Style = (Style)FindResource("ButtonBase")
        };
        button.Click += (_, _) => Process.Start(new ProcessStartInfo
        {
            FileName = url,
            UseShellExecute = true
        });
        parent.Children.Add(button);
    }

    private void PhotoTree_SelectedItemChanged(
        object sender,
        RoutedPropertyChangedEventArgs<object> e)
    {
        var selectedNode = PhotoTree.SelectedItem as LibraryTreeNode;
        var item = selectedNode?.Item;
        DeleteBranchButton.IsEnabled = selectedNode?.BranchId is not null;
        DeletePhotoButton.IsEnabled =
            item is { IsLibraryItem: true };
        DownloadPhotoButton.IsEnabled =
            item is { IsLibraryItem: true };
        SharePhotoButton.IsEnabled = item is not null;
        if (item is null)
        {
            return;
        }
        if (!item.IsVideo && IsEditableImage(item.Path))
        {
            _editorSelectedPath = item.Path;
        }
        if (Path.GetExtension(item.Path).Equals(
            ".jpg",
            StringComparison.OrdinalIgnoreCase) ||
            Path.GetExtension(item.Path).Equals(
                ".jpeg",
                StringComparison.OrdinalIgnoreCase))
        {
            try
            {
                var bytes = File.ReadAllBytes(item.Path);
                DisplayJpeg(bytes);
            }
            catch
            {
            }
        }
    }

    private void PhotoTree_MouseDoubleClick(
        object sender,
        MouseButtonEventArgs e)
    {
        if ((PhotoTree.SelectedItem as LibraryTreeNode)?.Item is { } item)
        {
            ShowLargePhoto(item);
        }
    }

    private void PhotoTree_PreviewMouseLeftButtonDown(
        object sender,
        MouseButtonEventArgs e)
    {
        _libraryDragStart = e.GetPosition(PhotoTree);
        _libraryDragInProgress = false;
    }

    private void PhotoTree_PreviewMouseLeftButtonUp(
        object sender,
        MouseButtonEventArgs e)
    {
        if (_libraryDragInProgress ||
            IsWithinToggleButton(e.OriginalSource as DependencyObject))
        {
            return;
        }
        var container = FindTreeViewItem(
            e.OriginalSource as DependencyObject);
        if (container?.DataContext is LibraryTreeNode
            {
                Item: null
            } node &&
            node.Children.Count > 0)
        {
            container.IsExpanded = !container.IsExpanded;
            e.Handled = true;
        }
    }

    private void PhotoTree_PreviewMouseMove(
        object sender,
        MouseEventArgs e)
    {
        if (e.LeftButton != MouseButtonState.Pressed)
        {
            return;
        }
        var position = e.GetPosition(PhotoTree);
        if (Math.Abs(position.X - _libraryDragStart.X) <
                SystemParameters.MinimumHorizontalDragDistance &&
            Math.Abs(position.Y - _libraryDragStart.Y) <
                SystemParameters.MinimumVerticalDragDistance)
        {
            return;
        }
        var container = FindTreeViewItem(e.OriginalSource as DependencyObject);
        if (container?.DataContext is not LibraryTreeNode
            {
                Item: { IsLibraryItem: true } item
            })
        {
            return;
        }
        var data = new DataObject(LibraryDragFormat, item.Path);
        _libraryDragInProgress = true;
        try
        {
            DragDrop.DoDragDrop(container, data, DragDropEffects.Move);
        }
        finally
        {
            _libraryDragInProgress = false;
        }
    }

    private void PhotoTree_DragOver(object sender, DragEventArgs e)
    {
        var container = FindTreeViewItem(e.OriginalSource as DependencyObject);
        var node = container?.DataContext as LibraryTreeNode;
        var validTarget =
            e.Data.GetDataPresent(LibraryDragFormat) &&
            node is not null &&
            (node.BranchId is not null || node.IsUnclassified);
        e.Effects = validTarget ? DragDropEffects.Move : DragDropEffects.None;
        e.Handled = true;
        SetLibraryDropTarget(validTarget ? container : null);
    }

    private void PhotoTree_DragLeave(object sender, DragEventArgs e)
    {
        SetLibraryDropTarget(null);
    }

    private void PhotoTree_Drop(object sender, DragEventArgs e)
    {
        var container = FindTreeViewItem(e.OriginalSource as DependencyObject);
        var node = container?.DataContext as LibraryTreeNode;
        if (node is null ||
            (node.BranchId is null && !node.IsUnclassified) ||
            e.Data.GetData(LibraryDragFormat) is not string path)
        {
            SetLibraryDropTarget(null);
            return;
        }
        if (node.IsUnclassified)
        {
            _libraryFileAssignments.Remove(path);
            OperationStatusText.Text = AppLocalization.T("已移到未分类");
        }
        else
        {
            _libraryFileAssignments[path] = node.BranchId!;
            OperationStatusText.Text = AppLocalization.T(
                $"已移到分支“{node.Name}”");
        }
        SaveLibraryFileAssignments();
        SetLibraryDropTarget(null);
        RefreshPhotoList();
        e.Handled = true;
    }

    private static TreeViewItem? FindTreeViewItem(DependencyObject? source)
    {
        while (source is not null && source is not TreeViewItem)
        {
            source = VisualTreeHelper.GetParent(source);
        }
        return source as TreeViewItem;
    }

    private static bool IsWithinToggleButton(DependencyObject? source)
    {
        while (source is not null)
        {
            if (source is ToggleButton)
            {
                return true;
            }
            source = VisualTreeHelper.GetParent(source);
        }
        return false;
    }

    private void SetLibraryDropTarget(TreeViewItem? target)
    {
        if (_libraryDropTarget == target)
        {
            return;
        }
        if (_libraryDropTarget is not null)
        {
            _libraryDropTarget.ClearValue(BackgroundProperty);
        }
        _libraryDropTarget = target;
        if (_libraryDropTarget is not null)
        {
            _libraryDropTarget.Background =
                (Brush)FindResource("AccentSoftBrush");
        }
    }

    private void SharePhotoButton_Click(object sender, RoutedEventArgs e)
    {
        if ((PhotoTree.SelectedItem as LibraryTreeNode)?.Item is { } item)
        {
            BeginShare(item.Path);
        }
    }

    private async void DownloadPhotoButton_Click(
        object sender,
        RoutedEventArgs e)
    {
        if ((PhotoTree.SelectedItem as LibraryTreeNode)?.Item is
            { IsLibraryItem: true } item)
        {
            await DownloadPhotoToLocalAsync(item);
        }
    }

    private Task<bool> DownloadPhotoToLocalAsync(
        PhotoItem item,
        Window? dialogOwner = null) =>
        DownloadFileToLocalAsync(
            item.Path,
            item.Name,
            dialogOwner: dialogOwner);

    private async Task<bool> DownloadFileToLocalAsync(
        string sourcePath,
        string suggestedFileName,
        Action<string>? statusSink = null,
        Window? dialogOwner = null,
        bool preparationOwner = false)
    {
        void UpdateStatus(string message)
        {
            var localized = AppLocalization.T(message);
            OperationStatusText.Text = localized;
            statusSink?.Invoke(localized);
        }

        if (_localDownloadBusy)
        {
            return false;
        }
        if (_localDownloadPreparationBusy && !preparationOwner)
        {
            return false;
        }
        if (!File.Exists(sourcePath))
        {
            UpdateStatus("文件不存在或为空，无法下载");
            return false;
        }
        try
        {
            if (new FileInfo(sourcePath).Length == 0)
            {
                UpdateStatus("文件不存在或为空，无法下载");
                return false;
            }
        }
        catch (Exception error)
        {
            _diagnostics.Error(
                "local-download",
                $"读取源文件失败：{error.Message}");
            UpdateStatus($"下载到本地失败：{error.Message}");
            return false;
        }

        var fileName = string.IsNullOrWhiteSpace(suggestedFileName)
            ? Path.GetFileName(sourcePath)
            : suggestedFileName;
        var extension = Path.GetExtension(fileName);
        var extensionLabel = string.IsNullOrWhiteSpace(extension)
            ? AppLocalization.T("文件")
            : extension.TrimStart('.').ToUpperInvariant() + " "
                + AppLocalization.T("文件");
        var dialog = new SaveFileDialog
        {
            Title = AppLocalization.T("下载到本地"),
            FileName = fileName,
            InitialDirectory = Environment.GetFolderPath(
                Environment.SpecialFolder.UserProfile) is { Length: > 0 } home
                    ? Path.Combine(home, "Downloads")
                    : "",
            AddExtension = !string.IsNullOrWhiteSpace(extension),
            DefaultExt = extension,
            Filter = string.IsNullOrWhiteSpace(extension)
                ? $"{AppLocalization.T("所有文件")}|*.*"
                : $"{extensionLabel}|*{extension}|"
                    + $"{AppLocalization.T("所有文件")}|*.*",
            OverwritePrompt = true,
            CheckPathExists = true
        };
        _localDownloadBusy = true;
        try
        {
            if (dialog.ShowDialog(dialogOwner ?? this) != true)
            {
                return false;
            }
            var destinationPath = dialog.FileName;
            UpdateStatus("正在保存…");
            await Task.Run(() => CopyFileToLocalAtomically(
                sourcePath,
                destinationPath));
            UpdateStatus(
                $"已下载到本地：{Path.GetFileName(destinationPath)}");
            _diagnostics.Info(
                "local-download",
                $"文件副本已保存；源={Path.GetFileName(sourcePath)}；目标={destinationPath}");
            return true;
        }
        catch (InvalidOperationException error)
        {
            UpdateStatus(error.Message);
            return false;
        }
        catch (Exception error)
        {
            _diagnostics.Error(
                "local-download",
                $"保存本地副本失败：{error.Message}");
            UpdateStatus($"下载到本地失败：{error.Message}");
            ShowError($"下载到本地失败：{error.Message}");
            return false;
        }
        finally
        {
            _localDownloadBusy = false;
        }
    }

    private static void CopyFileToLocalAtomically(
        string sourcePath,
        string destinationPath)
    {
        var sourceFullPath = Path.GetFullPath(sourcePath);
        var destinationFullPath = Path.GetFullPath(destinationPath);
        if (string.Equals(
            sourceFullPath,
            destinationFullPath,
            StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidOperationException("该文件已位于所选位置");
        }

        var destinationDirectory = Path.GetDirectoryName(destinationFullPath)
            ?? throw new IOException("所选保存位置无效");
        var temporaryPath = Path.Combine(
            destinationDirectory,
            $".zenche-download-{Guid.NewGuid():N}.tmp");
        try
        {
            using var source = new FileStream(
                sourceFullPath,
                FileMode.Open,
                FileAccess.Read,
                FileShare.Read,
                64 * 1024,
                FileOptions.SequentialScan);
            var sourceLength = source.Length;
            if (sourceLength == 0)
            {
                throw new InvalidOperationException(
                    "文件不存在或为空，无法下载");
            }
            var sourceIdentity = GetWindowsFileIdentity(
                source.SafeFileHandle);
            EnsureDestinationIsNotSource(
                sourceIdentity,
                destinationFullPath);

            using (var target = new FileStream(
                temporaryPath,
                FileMode.CreateNew,
                FileAccess.Write,
                FileShare.None,
                64 * 1024,
                FileOptions.SequentialScan))
            {
                source.CopyTo(target, 64 * 1024);
                target.Flush(flushToDisk: true);
            }
            if (new FileInfo(temporaryPath).Length != sourceLength)
            {
                throw new IOException("下载文件大小校验失败");
            }
            if (File.Exists(destinationFullPath))
            {
                EnsureDestinationIsNotSource(
                    sourceIdentity,
                    destinationFullPath);
                File.Replace(temporaryPath, destinationFullPath, null);
            }
            else
            {
                File.Move(temporaryPath, destinationFullPath);
            }
            if (!File.Exists(destinationFullPath) ||
                new FileInfo(destinationFullPath).Length != sourceLength)
            {
                throw new IOException("下载文件大小校验失败");
            }
        }
        finally
        {
            if (File.Exists(temporaryPath))
            {
                File.Delete(temporaryPath);
            }
        }
    }

    private static void EnsureDestinationIsNotSource(
        WindowsFileIdentity sourceIdentity,
        string destinationPath)
    {
        if (!File.Exists(destinationPath))
        {
            return;
        }
        using var destination = new FileStream(
            destinationPath,
            FileMode.Open,
            FileAccess.Read,
            FileShare.ReadWrite | FileShare.Delete);
        var destinationIdentity = GetWindowsFileIdentity(
            destination.SafeFileHandle);
        if (sourceIdentity == destinationIdentity)
        {
            throw new InvalidOperationException("该文件已位于所选位置");
        }
    }

    private static WindowsFileIdentity GetWindowsFileIdentity(
        SafeFileHandle file)
    {
        if (!GetFileInformationByHandle(file, out var information))
        {
            throw new IOException(
                "无法确认文件身份",
                new Win32Exception(Marshal.GetLastWin32Error()));
        }
        return new WindowsFileIdentity(
            information.VolumeSerialNumber,
            information.FileIndexHigh,
            information.FileIndexLow);
    }

    private void BeginShare(string path)
    {
        _sharePhotoPath = path;
#if NIKONLINK_WINDOWS_SHARE
        try
        {
            var handle = new WindowInteropHelper(this).Handle;
            DataTransferManagerHelper.ShowShareUIForWindow(handle);
        }
        catch (Exception error)
        {
            _diagnostics.Error(
                "share",
                $"无法打开 Windows 分享面板：{error.Message}");
            ShowError($"无法打开 Windows 分享面板：{error.Message}");
        }
#else
        Process.Start(new ProcessStartInfo
        {
            FileName = path,
            UseShellExecute = true
        });
#endif
    }

#if NIKONLINK_WINDOWS_SHARE
    private async void Share_DataRequested(
        DataTransferManager sender,
        DataRequestedEventArgs args)
    {
        var deferral = args.Request.GetDeferral();
        try
        {
            var path = _sharePhotoPath;
            if (string.IsNullOrWhiteSpace(path) || !File.Exists(path))
            {
                args.Request.FailWithDisplayText("请选择要分享的照片。");
                return;
            }
            var file = await StorageFile.GetFileFromPathAsync(path);
            args.Request.Data.Properties.Title = Path.GetFileName(path);
            args.Request.Data.Properties.Description =
                "来自 帧澈 ZENCHE 文件库";
            args.Request.Data.SetStorageItems([file]);
        }
        catch (Exception error)
        {
            _diagnostics.Error("share", $"准备分享照片失败：{error.Message}");
            args.Request.FailWithDisplayText("无法读取所选照片。");
        }
        finally
        {
            deferral.Complete();
        }
    }
#endif

    private void ShowLargePhoto(PhotoItem item)
    {
        if (item.IsVideo)
        {
            ShowLargeVideo(item);
            return;
        }
        try
        {
            var bitmap = new BitmapImage();
            bitmap.BeginInit();
            bitmap.CacheOption = BitmapCacheOption.OnLoad;
            bitmap.UriSource = new Uri(item.Path, UriKind.Absolute);
            bitmap.EndInit();
            bitmap.Freeze();

            var viewer = new Window
            {
                Owner = this,
                Title = item.Name,
                Width = 1100,
                Height = 760,
                MinWidth = 640,
                MinHeight = 480,
                Background = Brushes.Black,
                WindowStartupLocation = WindowStartupLocation.CenterOwner
            };
            var layout = new Grid();
            layout.RowDefinitions.Add(new RowDefinition
            {
                Height = GridLength.Auto
            });
            layout.RowDefinitions.Add(new RowDefinition
            {
                Height = new GridLength(1, GridUnitType.Star)
            });
            var toolbar = new DockPanel
            {
                Margin = new Thickness(16, 12, 16, 12)
            };
            var close = new Button
            {
                Content = "关闭",
                Width = 88,
                Style = (Style)FindResource("ButtonBase")
            };
            close.Click += (_, _) => viewer.Close();
            DockPanel.SetDock(close, Dock.Left);
            toolbar.Children.Add(close);
            var share = new Button
            {
                Content = "分享到社交平台",
                Width = 160,
                Style = (Style)FindResource("PrimaryButton")
            };
            share.Click += (_, _) => BeginShare(item.Path);
            DockPanel.SetDock(share, Dock.Right);
            toolbar.Children.Add(share);
            var download = new Button
            {
                Content = AppLocalization.T("下载到本地"),
                Width = 132,
                Margin = new Thickness(0, 0, 8, 0),
                Style = (Style)FindResource("PrimaryButton")
            };
            download.Click += async (_, _) =>
                await DownloadPhotoToLocalAsync(item, viewer);
            DockPanel.SetDock(download, Dock.Right);
            toolbar.Children.Add(download);
            layout.Children.Add(toolbar);

            var image = new Image
            {
                Source = bitmap,
                Stretch = Stretch.Uniform,
                Margin = new Thickness(12)
            };
            Grid.SetRow(image, 1);
            layout.Children.Add(image);
            viewer.Content = layout;
            viewer.ShowDialog();
        }
        catch (Exception error)
        {
            ShowError(
                "当前格式已安全保存，但系统无法显示这张照片的大图：" +
                error.Message);
        }
    }

    private void ShowLargeVideo(PhotoItem item)
    {
        var viewer = new Window
        {
            Owner = this,
            Title = item.Name,
            Width = 1100,
            Height = 760,
            MinWidth = 640,
            MinHeight = 480,
            Background = Brushes.Black,
            WindowStartupLocation = WindowStartupLocation.CenterOwner
        };
        var root = new Grid();
        var media = new MediaElement
        {
            Source = new Uri(item.Path, UriKind.Absolute),
            LoadedBehavior = MediaState.Manual,
            UnloadedBehavior = MediaState.Stop,
            Stretch = Stretch.Uniform
        };
        root.Children.Add(media);
        var toolbar = new DockPanel
        {
            Margin = new Thickness(16),
            VerticalAlignment = VerticalAlignment.Top
        };
        var close = new Button
        {
            Content = "关闭",
            Width = 88,
            Style = (Style)FindResource("ButtonBase")
        };
        close.Click += (_, _) => viewer.Close();
        DockPanel.SetDock(close, Dock.Left);
        toolbar.Children.Add(close);
        var share = new Button
        {
            Content = "分享到社交平台",
            Width = 160,
            Style = (Style)FindResource("PrimaryButton")
        };
        share.Click += (_, _) => BeginShare(item.Path);
        DockPanel.SetDock(share, Dock.Right);
        toolbar.Children.Add(share);
        var download = new Button
        {
            Content = AppLocalization.T("下载到本地"),
            Width = 132,
            Margin = new Thickness(0, 0, 8, 0),
            Style = (Style)FindResource("PrimaryButton")
        };
        download.Click += async (_, _) =>
            await DownloadPhotoToLocalAsync(item, viewer);
        DockPanel.SetDock(download, Dock.Right);
        toolbar.Children.Add(download);
        root.Children.Add(toolbar);
        viewer.Content = root;
        viewer.Loaded += (_, _) => media.Play();
        viewer.Closed += (_, _) => media.Close();
        viewer.ShowDialog();
    }

    private void DeletePhotoButton_Click(object sender, RoutedEventArgs e)
    {
        if ((PhotoTree.SelectedItem as LibraryTreeNode)?.Item is not
            {
                IsLibraryItem: true
            } item)
        {
            return;
        }
        try
        {
            File.Delete(item.Path);
            _libraryFileAssignments.Remove(item.Path);
            SaveLibraryFileAssignments();
            RefreshPhotoList();
            OperationStatusText.Text = AppLocalization.T(
                $"已删除 {item.Name}");
        }
        catch (Exception error)
        {
            ShowError($"无法删除 {item.Name}：{error.Message}");
        }
    }

    private void StartPreviewLoop()
    {
        SyncLivePhotoRing();
        _previewCancellation?.Cancel();
        _previewCancellation?.Dispose();
        _previewCancellation = new CancellationTokenSource();
        _previewTask = PreviewLoopAsync(_previewCancellation.Token);
    }

    /// <summary>E5 1.5.9：live 图环形缓冲启停（取景开启时 arm、停止时 disarm）。
    /// TBC-awaiting-hardware。</summary>
    private void SyncLivePhotoRing()
    {
        var anyLiveView = (_camera.IsConnected && _camera.IsLiveView) ||
                          (_localCamera.IsConnected && _localCamera.IsLiveView);
        if (_livePhotoEnabled && anyLiveView)
        {
            if (!_livePhotoClipRecorder.IsArmed)
            {
                _livePhotoClipRecorder.Arm(
                    Math.Max(4, (int)Math.Round(_videoFrameRate)),
                    _livePhotoSeconds);
            }
        }
        else if (_livePhotoClipRecorder.IsArmed)
        {
            _livePhotoClipRecorder.Disarm();
        }
    }

    /// <summary>E5 1.5.9：把环形缓冲最近 N 秒帧切为临时 AVI；环为空返回 null。
    /// TBC-awaiting-hardware。</summary>
    private string? CaptureLivePhotoSlice()
    {
        var tempPath = Path.Combine(
            Path.GetTempPath(),
            $"{Guid.NewGuid():N}.avi");
        var clip = _livePhotoClipRecorder.CaptureSlice(tempPath);
        return clip is null ? null : tempPath;
    }

    private async Task PreviewLoopAsync(CancellationToken cancellationToken)
    {
        var failures = 0;
        Task<byte[]>? pendingFetch = null;
        while (!cancellationToken.IsCancellationRequested &&
               ((_camera.IsConnected && _camera.IsLiveView) ||
                (_localCamera.IsConnected && _localCamera.IsLiveView)))
        {
            try
            {
                // Start next fetch before processing current frame
                Task<byte[]> NextFrame() => _localCamera.IsConnected
                    ? _localCamera.GetLiveViewFrameAsync(cancellationToken)
                    : _camera.GetLiveViewFrameAsync(cancellationToken);
                var fetchTask = pendingFetch ?? NextFrame();
                pendingFetch = NextFrame();
                var jpeg = await fetchTask;
                failures = 0;
                // E5 1.5.9：live 图环形缓冲常开（取景帧同源喂入，仅当开关开启）。
                if (_livePhotoEnabled)
                {
                    _livePhotoClipRecorder.Append(jpeg);
                }
                if (_externalVideoRecorder.IsRecording)
                {
                    try
                    {
                        _externalVideoRecorder.AppendJpeg(jpeg);
                    }
                    catch (Exception recordingError)
                    {
                        await FinishExternalRecordingAfterFailureAsync(
                            recordingError,
                            cancellationToken);
                    }
                }
                var videoMode = _videoMode;
                var recording = _videoRecording;
                var sequence = ++_previewAnalysisSequence;
                var analyzeFrame = !recording
                    || sequence % 6 == 0
                    || (_focusPeakingEnabled || _falseColorEnabled);
                var focusPeaking = videoMode && _focusPeakingEnabled && analyzeFrame;
                var falseColor = videoMode && _falseColorEnabled && analyzeFrame;
                var prepared = await Task.Run(
                    () => PrepareJpeg(
                        jpeg,
                        videoMode,
                        focusPeaking,
                        falseColor,
                        recording,
                        _monitorNikonCloudPreset),
                    cancellationToken);
                await Dispatcher.InvokeAsync(
                    () => DisplayPreparedPreview(prepared));
            }
            catch (OperationCanceledException)
            {
                break;
            }
            catch (Exception error)
            {
                failures++;
                _diagnostics.Warning(
                    "liveview",
                    $"获取实时取景帧失败（{failures}/3）：{error.Message}");
                if (failures >= 3)
                {
                    await FinishExternalRecordingForDisconnectAsync();
                    if (_localCamera.IsConnected)
                    {
                        await _localCamera.StopLiveViewAsync();
                    }
                    else
                    {
                        await _camera.StopLiveViewAsync(CancellationToken.None);
                    }
                    await Dispatcher.InvokeAsync(() =>
                    {
                        UpdateLiveViewState();
                        OperationStatusText.Text = AppLocalization.T(
                            "实时取景已安全停止 · 机身控制已释放");
                        ShowError(
                            "连续 3 次未收到实时取景画面，已停止重试并释放相机。");
                    });
                    break;
                }
                await Dispatcher.InvokeAsync(() =>
                {
                    OperationStatusText.Text = AppLocalization.T(
                        $"实时取景正在重试 · {failures}/3");
                });
                await Task.Delay(600, cancellationToken);
            }
        }
    }

    private async Task StopPreviewLoopAsync()
    {
        var cancellation = _previewCancellation;
        var task = _previewTask;
        _previewCancellation = null;
        _previewTask = null;
        cancellation?.Cancel();
        if (task is not null)
        {
            try
            {
                await task;
            }
            catch (OperationCanceledException)
            {
            }
        }
        cancellation?.Dispose();
        SyncLivePhotoRing();
    }
    private async Task FinishExternalRecordingAfterFailureAsync(
        Exception cause,
        CancellationToken cancellationToken)
    {
        try
        {
            var result = _externalVideoRecorder.StopIfRecording();
            if (result is not null)
            {
                await _workflow.CompleteExternalRecordingAsync(
                    result.Path,
                    cancellationToken);
            }
        }
        catch
        {
            _externalVideoRecorder.Abort();
        }
        _videoRecording = _camera.IsConnected && _camera.IsMovieRecording;
        if (!_videoRecording) _recordingStartedAt = null;
        await Dispatcher.InvokeAsync(() =>
        {
            UpdateRecordingState();
            RefreshPhotoList();
            ShowError($"外录已停止：{cause.Message}");
        });
    }

    private async Task FinishExternalRecordingForDisconnectAsync()
    {
        try
        {
            var result = _externalVideoRecorder.StopIfRecording();
            if (result is not null)
            {
                await _workflow.CompleteExternalRecordingAsync(result.Path);
                _diagnostics.Info(
                    "external-recording",
                    $"连接结束，已安全保存外录：{Path.GetFileName(result.Path)}");
                RefreshPhotoList();
            }
        }
        catch (Exception error)
        {
            _externalVideoRecorder.Abort();
            _diagnostics.Error(
                "external-recording",
                $"连接结束时无法完成外录：{error.Message}");
        }
        _videoRecording = false;
        _recordingStartedAt = null;
    }

    private async Task RunOperationAsync(
        string status,
        Func<CancellationToken, Task> operation,
        bool connectionAttempt = false)
    {
        _operationInProgress = true;
        _diagnostics.Info("operation", status);
        OperationStatusText.Text = AppLocalization.T(status);
        UpdateEnabledState();
        try
        {
            using var cancellation = new CancellationTokenSource(
                TimeSpan.FromMinutes(3));
            await operation(cancellation.Token);
            _diagnostics.Info("operation", $"操作完成：{status}");
            if (connectionAttempt)
            {
                _lastConnectionError = null;
            }
        }
        catch (Exception error)
        {
            _diagnostics.Error(
                "operation",
                $"操作失败：{status}；错误={error}");
            OperationStatusText.Text = AppLocalization.T(error.Message);
            if (connectionAttempt)
            {
                _lastConnectionError = error.Message;
            }
            ShowError(error.Message);
        }
        finally
        {
            _operationInProgress = false;
            UpdateEnabledState();
            UpdateLiveViewState();
            UpdateControlStatusRow();
        }
    }

    private void SetConnectionState(CameraProfile? profile)
    {
        ConfigureVideoRecordingOptions(profile);
        UpdateConnectionSummary();
        PreviewEmpty.Visibility = profile is null
            ? Visibility.Visible
            : PreviewEmpty.Visibility;
        if (profile is null)
        {
            _videoRecording = false;
            _recordingStartedAt = null;
            PreviewImage.Source = null;
            _lastPreviewSource = null;
            PreviewEmpty.Visibility = Visibility.Visible;
            UpdateRecordingState();
        }
        UpdateEnabledState();
        UpdateLiveViewState();
        UpdateExposureReadout();
        RefreshRememberedDevices();
    }

    private void UpdateConnectionSummary()
    {
        var anyConnected = _camera.IsConnected ||
            _localCamera.IsConnected ||
            _wifiCamera.IsConnected;
        CameraStatusText.Text = AppLocalization.T(
            _camera.IsConnected
                ? $"{_camera.Profile?.Name ?? "相机"} · USB/PTP"
                : _localCamera.IsConnected
                    ? $"{_localCamera.DeviceName} · 本机摄像头"
                : _wifiCamera.IsConnected
                    ? $"{_wifiCamera.CameraName} · {_wifiConnectionMode.ToUpperInvariant()} · WI‑FI/PTP‑IP"
                    : "未连接 · WINDOWS USB/PTP");
        ConnectButton.Content = AppLocalization.T("连接管理");
        ConnectionDot.Fill = (Brush)FindResource(
            anyConnected ? "PositiveBrush" : "MutedBrush");
        UpdateControlStatusRow();
    }

    /** v1.5.5 fig1 status row: ● state + transport capsule + connection error. */
    private void UpdateControlStatusRow()
    {
        if (ControlStatusText is null)
        {
            return;
        }
        var anyCamera = _camera.IsConnected ||
            _localCamera.IsConnected ||
            _wifiCamera.IsConnected;
        var loading = _operationInProgress;
        var failed = _lastConnectionError != null && !anyCamera && !loading;
        if (loading)
        {
            ControlStatusDot.Fill = (Brush)FindResource("UiAccentBrush");
            ControlStatusText.Text = AppLocalization.T("正在连接…");
            ControlStatusRateText.Text = AppLocalization.T("连接中");
        }
        else if (_wifiReconnecting)
        {
            ControlStatusDot.Fill = (Brush)FindResource("UiAccentBrush");
            ControlStatusText.Text = AppLocalization.T("Wi‑Fi 已断开，正在重连…");
            ControlStatusRateText.Text = AppLocalization.T("重连中");
        }
        else if (anyCamera)
        {
            ControlStatusDot.Fill = (Brush)FindResource("UiAccentBrush");
            ControlStatusText.Text = AppLocalization.T("就绪");
            ControlStatusRateText.Text = _camera.IsConnected
                ? "USB/PTP"
                : _wifiCamera.IsConnected ? "Wi‑Fi/PTP‑IP" : "SYSTEM";
        }
        else
        {
            ControlStatusDot.Fill = (Brush)FindResource(
                failed ? "VideoBrush" : "UiLabelBrush");
            ControlStatusText.Text = AppLocalization.T(
                failed ? "连接失败" : "未连接");
            ControlStatusRateText.Text = AppLocalization.T(
                failed ? "重试" : "待连接");
        }
        var showError = failed && _lastConnectionError != null;
        ControlStatusErrorText.Text = showError
            ? _lastConnectionError
            : "";
        ControlStatusErrorText.Visibility = showError
            ? Visibility.Visible
            : Visibility.Collapsed;
    }

    private void UpdateMonitorStorage()
    {
        if (MonitorStorageFreeText is null || MonitorStorageDetailText is null)
        {
            return;
        }
        try
        {
            var root = Path.GetPathRoot(_library.DirectoryPath);
            if (string.IsNullOrWhiteSpace(root)) throw new IOException("storage root unavailable");
            var drive = new DriveInfo(root);
            var free = drive.AvailableFreeSpace;
            MonitorStorageFreeText.Text = FormatStorageBytes(free);
            var usedPercent = drive.TotalSize > 0
                ? Math.Clamp((int)Math.Round((1 - free / (double)drive.TotalSize) * 100), 0, 100)
                : 0;
            MonitorStorageDetailText.Text = $"{usedPercent}% 已用 · 本地缓存";
        }
        catch
        {
            MonitorStorageFreeText.Text = "—";
            MonitorStorageDetailText.Text = "本地缓存 · 存储状态暂不可用";
        }
    }

    private static string FormatStorageBytes(long bytes)
    {
        if (bytes < 0) return "—";
        var value = (double)bytes;
        var units = new[] { "B", "KB", "MB", "GB", "TB" };
        var index = 0;
        while (value >= 1024 && index < units.Length - 1)
        {
            value /= 1024;
            index++;
        }
        return index == 0 ? $"{value:0} {units[index]}" : $"{value:0.0} {units[index]}";
    }

    private void UpdateEnabledState()
    {
        var connected = _camera.IsConnected && !_operationInProgress;
        var liveViewReady = (_camera.IsConnected || _localCamera.IsConnected ||
            _wifiCamera.IsConnected) &&
            !_operationInProgress;
        var photoCaptureReady =
            (_camera.IsConnected || _localCamera.IsConnected || _wifiCamera.IsConnected) &&
            !_operationInProgress;
        var videoRecordReady = _videoMode &&
            ((_camera.IsConnected && !_operationInProgress) ||
             (_wifiCamera.IsConnected &&
              (_wifiCamera.Vendor == PtpIpCamera.CameraVendor.Nikon ||
               _wifiCamera.Vendor == PtpIpCamera.CameraVendor.Canon) &&
              !_operationInProgress));
        ConnectButton.IsEnabled = !_operationInProgress;
        LiveViewButton.IsEnabled = liveViewReady;
        LiveMonitoringToggle.IsEnabled = liveViewReady;
        ShutterButton.IsEnabled = _videoMode
            ? videoRecordReady || (liveViewReady && _externalRecordToDevice)
            : photoCaptureReady;
        if (_immersiveRecordButton is not null)
        {
            _immersiveRecordButton.IsEnabled = _videoMode
                ? videoRecordReady || (liveViewReady && _externalRecordToDevice)
                : connected;
        }
        ExposureModeBox.IsEnabled = connected;
        VideoCodecBox.IsEnabled = connected;
        VideoLogBox.IsEnabled = connected;
        ExternalRecordingCheck.IsEnabled = !_videoRecording &&
            !_operationInProgress;
        CaptureAutoFocusButton.IsEnabled = connected && _camera.IsLiveView && !_operationInProgress;
        FocusModeBox.IsEnabled = connected;
        WhiteBalanceBox.IsEnabled = connected;
        PictureControlBox.IsEnabled = connected;
        ShootingTaskButton.IsEnabled =
            (_shootingTaskCancellation is not null && _operationInProgress) ||
            connected;
        if (RefreshCameraStorageButton is not null)
        {
            RefreshCameraStorageButton.IsEnabled =
                !_cameraStorageBusy && !_operationInProgress &&
                (_camera.IsConnected || _wifiCamera.IsConnected);
            if (!_camera.IsConnected && !_wifiCamera.IsConnected &&
                _cameraStorageRows.Count == 0)
            {
                CameraStorageStatusText.Text = AppLocalization.T(
                    "请连接 USB/PTP 或 Wi‑Fi/PTP‑IP 相机");
            }
        }
        UpdateExposureAvailability();
    }

    private void UpdateExposureAvailability()
    {
        var connected = _camera.IsConnected && !_operationInProgress;
        SetParameterAvailability(
            ExposureModeBox,
            "exposureMode",
            connected);
        SetParameterAvailability(
            ShutterBox,
            _videoMode ? "videoExposureTime" : "exposureTime",
            connected);
        SetParameterAvailability(ApertureBox, "aperture", connected);
        SetParameterAvailability(IsoBox, "iso", connected);
        SetParameterAvailability(
            ExposureCompensationBox,
            "exposureCompensation",
            connected);
        SetParameterAvailability(FocusModeBox, "focusMode", connected);
        SetParameterAvailability(
            WhiteBalanceBox,
            "whiteBalanceMode",
            connected);
        SetParameterAvailability(
            PictureControlBox,
            "pictureControl",
            connected);
        if (_videoMode)
        {
            SetParameterAvailability(VideoCodecBox, "videoCodec", connected);
            SetParameterAvailability(VideoLogBox, "videoLog", connected);
        }
        UpdateExposureReadout();
    }

    private void UpdateExposureReadout()
    {
        if (SourceReadoutText is null)
        {
            return;
        }
        var connected = _camera.IsConnected;
        SourceReadoutText.Text = connected
            ? "USB/PTP"
            : _localCamera.IsConnected
                ? "本机"
                : _wifiCamera.IsConnected
                    ? $"{_wifiConnectionMode.ToUpperInvariant()} · WI‑FI/PTP‑IP"
                    : "—";
        CaptureDeviceNameText.Text = _camera.IsConnected
            ? _camera.Profile?.Name ?? "Nikon 相机"
            : _localCamera.IsConnected
                ? "本机摄像头"
                : _wifiCamera.IsConnected ? "Wi‑Fi 相机" : "—";
        CaptureLinkText.Text = _camera.IsConnected
            ? "USB/PTP"
            : _localCamera.IsConnected
                ? "SYSTEM"
                : _wifiCamera.IsConnected ? "PTP-IP" : "OFFLINE";
        CaptureOutputText.Text = _camera.IsConnected ||
            _localCamera.IsConnected || _wifiCamera.IsConnected
                ? _videoMode
                    ? $"{_videoFrameRate:0}P · {VideoCodecShortLabel()}"
                    : "PHOTO · JPEG"
                : "—";
        ModeReadoutText.Text = connected ? ExposureModeText() : "—";
        ShutterReadoutText.Text = connected
            ? SelectedContent(ShutterBox, "—")
            : "—";
        ApertureReadoutText.Text = connected
            ? SelectedContent(ApertureBox, "—")
            : "—";
        IsoReadoutText.Text = connected
            ? SelectedContent(IsoBox, "—").Replace("ISO ", "")
            : "—";
        CompensationReadoutText.Text = connected
            ? SelectedContent(ExposureCompensationBox, "—")
            : "—";
        if (MonitorFrameRateText is not null)
        {
            MonitorFrameRateText.Text = connected ? $"{_videoFrameRate:0}" : "—";
            MonitorShutterText.Text = connected ? (_videoMode ? $"{_videoShutterAngle:0}°" : SelectedContent(ShutterBox, "—")) : "—";
            MonitorApertureText.Text = connected ? SelectedContent(ApertureBox, "—").Replace("f/", "f") : "—";
            MonitorIsoText.Text = connected ? SelectedContent(IsoBox, "—").Replace("ISO ", "") : "—";
            MonitorWhiteBalanceText.Text = connected ? SelectedContent(WhiteBalanceBox, "—") : "—";
            MonitorCodecText.Text = connected ? VideoCodecShortLabel() : "—";
            MonitorToneText.Text = connected ? VideoLogShortLabel() : "—";
            MonitorCameraOverlay.Text = connected
                ? $"{_camera.Profile?.Name ?? "相机"} · USB/PTP"
                : _localCamera.IsConnected
                    ? $"{_localCamera.DeviceName} · 本机摄像头"
                    : "未连接 · USB/PTP";
            UpdateMonitorStorage();
        }
        UpdateReadoutState(
            ShutterReadoutLabel,
            ShutterReadoutText,
            "快门",
            _videoMode ? "videoExposureTime" : "exposureTime",
            connected);
        UpdateReadoutState(
            ApertureReadoutLabel,
            ApertureReadoutText,
            "光圈",
            "aperture",
            connected);
        UpdateReadoutState(
            IsoReadoutLabel,
            IsoReadoutText,
            "ISO",
            "iso",
            connected);
        UpdateReadoutState(
            CompensationReadoutLabel,
            CompensationReadoutText,
            "曝光补偿",
            "exposureCompensation",
            connected);
    }

    private void UpdateReadoutState(
        TextBlock label,
        TextBlock value,
        string title,
        string parameter,
        bool connected)
    {
        var writable = connected && _camera.CanAdjustParameter(parameter);
        label.Text = AppLocalization.T(title) +
            (connected && !writable ? $" · {AppLocalization.T("自动")}" : "");
        value.Foreground = (Brush)FindResource(
            writable ? "ReadoutGlowBrush" : "GraphiteInkBrush");
    }

    private static string SelectedContent(ComboBox box, string fallback)
    {
        return box.SelectedItem is ComboBoxItem item
            ? Convert.ToString(item.Content) ?? fallback
            : fallback;
    }

    private void SetParameterAvailability(
        Control control,
        string parameter,
        bool connected)
    {
        var enabled = connected && _camera.CanAdjustParameter(parameter);
        control.IsEnabled = enabled;
        control.Opacity = enabled ? 1 : 0.48;
        ToolTipService.SetToolTip(
            control,
            enabled
                ? null
                : connected
                    ? _camera.ParameterLockReason(parameter)
                    : AppLocalization.T("连接相机后可调整"));
    }

    private void UpdateLiveViewState()
    {
        var live = _camera.IsLiveView || _localCamera.IsLiveView ||
            _wifiCamera.IsLiveView;
        LiveMonitoringToggle.Content = AppLocalization.T("实时监看");
        AutomationProperties.SetName(
            LiveMonitoringToggle,
            AppLocalization.T("实时监看"));
        LiveViewButton.Content =
            AppLocalization.T(live ? "停止取景" : "开启取景");
        LiveMonitoringToggle.IsChecked = live;
        LiveBadge.Text = live ? "LIVE VIEW ON" : "LIVE VIEW OFF";
        LiveBadge.Foreground = live
            ? (Brush)FindResource("AccentInkBrush")
            : (Brush)FindResource("GraphiteMutedBrush");
        CapturePreviewEmptyTitle.Text = AppLocalization.T(
            live ? "等待相机画面" : "实时监看已关闭");
        CapturePreviewEmptyDetail.Text = AppLocalization.T(
            live
                ? "连接相机后开启实时取景"
                : "打开开关即可恢复实时画面");
        if (!live)
        {
            PreviewImage.Source = null;
            MonitorPreviewImage.Source = null;
            _lastPreviewSource = null;
            PreviewEmpty.Visibility = Visibility.Visible;
            MonitorPreviewEmpty.Visibility = Visibility.Visible;
            if (_immersivePreviewImage is not null)
            {
                _immersivePreviewImage.Source = null;
            }
        }
        else
        {
            PreviewEmpty.Visibility = PreviewImage.Source is null
                ? Visibility.Visible
                : Visibility.Collapsed;
        }
        if (MonitorLiveStatusText is not null)
        {
            MonitorLiveStatusText.Text = live ? "LIVE" : "NO SOURCE";
            // v1.5.7 issue 655a0a14: LIVE/NO SOURCE 绿/灰状态字改纯白（视频井恒深）
            MonitorLiveStatusText.Foreground =
                (Brush)FindResource("MonitorWellTextBrush");
            MonitorPreviewEmpty.Visibility = live && MonitorPreviewImage.Source is not null
                ? Visibility.Collapsed
                : Visibility.Visible;
        }
    }

    private void DisplayJpeg(byte[] jpeg)
    {
        DisplayPreparedPreview(PrepareJpeg(
            jpeg,
            _videoMode,
            _videoMode && _focusPeakingEnabled,
            _videoMode && _falseColorEnabled,
            false,
            _monitorNikonCloudPreset));
    }

    private static PreparedPreview PrepareJpeg(
        byte[] jpeg,
        bool videoMode,
        bool focusPeaking,
        bool falseColor,
        bool recording = false,
        NikonCloudPreset? nikonCloudPreset = null)
    {
        using var stream = new MemoryStream(jpeg, writable: false);
        var bitmap = new BitmapImage();
        bitmap.BeginInit();
        bitmap.CacheOption = BitmapCacheOption.OnLoad;
        if (recording)
        {
            bitmap.DecodePixelWidth = 1280;
        }
        bitmap.StreamSource = stream;
        bitmap.EndInit();
        bitmap.Freeze();
        var monitor = ProfessionalMonitor.Process(
            bitmap,
            focusPeaking,
            falseColor,
            nikonCloudPreset);
        return new PreparedPreview(
            bitmap,
            videoMode || nikonCloudPreset is not null
                ? monitor.Image : bitmap,
            monitor);
    }

    private void DisplayPreparedPreview(PreparedPreview prepared)
    {
        _lastPreviewSource = prepared.Source;
        PreviewImage.Source = prepared.Display;
        MonitorPreviewImage.Source = prepared.Display;
        MonitorPreviewEmpty.Visibility = Visibility.Collapsed;
        MonitorCameraOverlay.Text = $"{(_camera.Profile?.Name ?? "未连接")} · USB/PTP";
        MonitorRgbScope.SetData(
            prepared.Monitor.RedHistogram,
            prepared.Monitor.GreenHistogram,
            prepared.Monitor.BlueHistogram);
        _immersiveScope?.SetData(
            prepared.Monitor.RedHistogram,
            prepared.Monitor.GreenHistogram,
            prepared.Monitor.BlueHistogram);
        if (_immersivePreviewImage is not null)
        {
            _immersivePreviewImage.Source = prepared.Display;
        }
        ProfessionalScope.SetData(
            prepared.Monitor.RedHistogram,
            prepared.Monitor.GreenHistogram,
            prepared.Monitor.BlueHistogram);
        PeakingCoverageText.Text = AppLocalization.T(
            $"峰值覆盖 {prepared.Monitor.PeakingCoverage}%");
        PreviewEmpty.Visibility = Visibility.Collapsed;
    }

    private async void RefreshCameraStorageButton_Click(
        object sender,
        RoutedEventArgs e)
    {
        if (_cameraStorageBusy) return;
        if (!_camera.IsConnected && !_wifiCamera.IsConnected)
        {
            CameraStorageStatusText.Text = AppLocalization.T(
                "请先连接 USB/PTP 或 Wi‑Fi/PTP‑IP 相机");
            ShowError("请先连接 USB/PTP 或 Wi‑Fi/PTP‑IP 相机。");
            return;
        }
        SetCameraStorageBusy(true, "正在读取存储卷与文件信息…");
        try
        {
            using var cancellation = new CancellationTokenSource(
                TimeSpan.FromMinutes(3));
            _cameraStorageSnapshot = _camera.IsConnected
                ? await _camera.ListStorageAsync(cancellation.Token)
                : await _wifiCamera.ListStorageAsync(cancellation.Token);
            _cameraStorageRows.Clear();
            foreach (var item in _cameraStorageSnapshot.Items)
            {
                _cameraStorageRows.Add(new CameraStorageListItem { Item = item });
            }
            var capacity = _cameraStorageSnapshot.CapacityBytes;
            CameraStorageSummaryText.Text = capacity > 0
                ? $"{FormatStorageBytes(Math.Max(
                    0,
                    capacity - _cameraStorageSnapshot.FreeBytes))} 已用 / " +
                  FormatStorageBytes(capacity)
                : $"{_cameraStorageSnapshot.Items.Count} 个机内文件";
            CameraStorageStatusText.Text = AppLocalization.T(
                $"读取完成 · {_cameraStorageSnapshot.Items.Count} 个文件");
            _diagnostics.Info(
                "camera-storage",
                $"读取机内存储完成；卷={_cameraStorageSnapshot.Volumes.Count}；" +
                $"文件={_cameraStorageSnapshot.Items.Count}");
        }
        catch (Exception error)
        {
            CameraStorageStatusText.Text = AppLocalization.T(
                $"读取失败 · {error.Message}");
            _diagnostics.Error("camera-storage", error.ToString());
            ShowError(error.Message);
        }
        finally
        {
            SetCameraStorageBusy(false);
        }
    }

    private void SelectAllCameraStorageButton_Click(
        object sender,
        RoutedEventArgs e)
    {
        var selectable = _cameraStorageRows
            .Where(row => !row.Item.IsProtected)
            .ToList();
        var selectedCount = CameraStorageList.SelectedItems
            .OfType<CameraStorageListItem>()
            .Count(row => !row.Item.IsProtected);
        CameraStorageList.SelectedItems.Clear();
        if (selectedCount != selectable.Count)
        {
            foreach (var row in selectable) CameraStorageList.SelectedItems.Add(row);
        }
        UpdateCameraStorageSelectionState();
    }

    private void CameraStorageList_SelectionChanged(
        object sender,
        SelectionChangedEventArgs e)
    {
        foreach (var row in CameraStorageList.SelectedItems
                     .OfType<CameraStorageListItem>()
                     .Where(row => row.Item.IsProtected)
                     .ToList())
        {
            CameraStorageList.SelectedItems.Remove(row);
        }
        UpdateCameraStorageSelectionState();
        foreach (var row in CameraStorageList.SelectedItems
                     .OfType<CameraStorageListItem>()
                     .Where(row => !row.Item.IsVideo && row.Thumbnail is null))
        {
            _ = LoadCameraStorageThumbnailAsync(row);
        }
    }

    private async Task LoadCameraStorageThumbnailAsync(CameraStorageListItem row)
    {
        try
        {
            using var cancellation = new CancellationTokenSource(
                TimeSpan.FromSeconds(30));
            var bytes = _camera.IsConnected
                ? await _camera.GetStorageThumbnailAsync(
                    row.Item.Handle,
                    cancellation.Token)
                : await _wifiCamera.GetStorageThumbnailAsync(
                    row.Item.Handle,
                    cancellation.Token);
            using var stream = new MemoryStream(bytes);
            var bitmap = new BitmapImage();
            bitmap.BeginInit();
            bitmap.CacheOption = BitmapCacheOption.OnLoad;
            bitmap.DecodePixelWidth = 144;
            bitmap.StreamSource = stream;
            bitmap.EndInit();
            bitmap.Freeze();
            row.Thumbnail = bitmap;
        }
        catch
        {
            // Some RAW/video objects do not expose a PTP thumbnail.
        }
    }

    private async void DownloadCameraStorageButton_Click(
        object sender,
        RoutedEventArgs e)
    {
        var selected = SelectedCameraStorageRows();
        if (_cameraStorageBusy || selected.Count == 0) return;
        SetCameraStorageBusy(true, $"正在下载 0 / {selected.Count}");
        try
        {
            using var cancellation = new CancellationTokenSource(
                TimeSpan.FromMinutes(20));
            for (var index = 0; index < selected.Count; index++)
            {
                var item = selected[index].Item;
                CameraStorageStatusText.Text = AppLocalization.T(
                    $"正在下载 {index + 1} / {selected.Count} · {item.Filename}");
                var bytes = _camera.IsConnected
                    ? await _camera.DownloadStorageObjectAsync(
                        item.Handle,
                        cancellation.Token)
                    : await _wifiCamera.DownloadStorageObjectAsync(
                        item.Handle,
                        cancellation.Token);
                await _workflow.StoreAsync(
                    bytes,
                    item.Filename,
                    _camera.IsConnected
                        ? _camera.Profile?.Name ?? "相机"
                        : _wifiCamera.CameraName,
                    cancellationToken: cancellation.Token);
            }
            CameraStorageList.SelectedItems.Clear();
            CameraStorageStatusText.Text = AppLocalization.T(
                $"已下载 {selected.Count} 个文件到 ZENCHE 文件库");
            RefreshPhotoList();
        }
        catch (Exception error)
        {
            CameraStorageStatusText.Text = AppLocalization.T(
                $"下载失败 · {error.Message}");
            _diagnostics.Error("camera-storage", error.ToString());
            ShowError(error.Message);
        }
        finally
        {
            SetCameraStorageBusy(false);
        }
    }

    private async void DeleteCameraStorageButton_Click(
        object sender,
        RoutedEventArgs e)
    {
        var selected = SelectedCameraStorageRows();
        if (_cameraStorageBusy || selected.Count == 0) return;
        var confirmation = MessageBox.Show(
            this,
            AppLocalization.T(
                $"将从相机存储卡永久删除所选 {selected.Count} 个文件。" +
                "\n\n此操作无法撤销；已保护文件不会被选择。"),
            AppLocalization.T("从相机永久删除？"),
            MessageBoxButton.OKCancel,
            MessageBoxImage.Warning,
            MessageBoxResult.Cancel);
        if (confirmation != MessageBoxResult.OK) return;

        SetCameraStorageBusy(true, "正在从相机删除…");
        try
        {
            using var cancellation = new CancellationTokenSource(
                TimeSpan.FromMinutes(10));
            foreach (var row in selected)
            {
                if (_camera.IsConnected)
                {
                    await _camera.DeleteStorageObjectAsync(
                        row.Item.Handle,
                        cancellation.Token);
                }
                else
                {
                    await _wifiCamera.DeleteStorageObjectAsync(
                        row.Item.Handle,
                        cancellation.Token);
                }
            }
            SetCameraStorageBusy(false);
            CameraStorageStatusText.Text = AppLocalization.T(
                $"已从相机删除 {selected.Count} 个文件");
            RefreshCameraStorageButton_Click(this, new RoutedEventArgs());
        }
        catch (Exception error)
        {
            CameraStorageStatusText.Text = AppLocalization.T(
                $"删除失败 · {error.Message}");
            _diagnostics.Error("camera-storage", error.ToString());
            ShowError(error.Message);
        }
        finally
        {
            SetCameraStorageBusy(false);
        }
    }

    private List<CameraStorageListItem> SelectedCameraStorageRows() =>
        CameraStorageList.SelectedItems
            .OfType<CameraStorageListItem>()
            .Where(row => !row.Item.IsProtected)
            .ToList();

    private void UpdateCameraStorageSelectionState()
    {
        var selectedCount = SelectedCameraStorageRows().Count;
        DownloadCameraStorageButton.IsEnabled =
            !_cameraStorageBusy && selectedCount > 0;
        DeleteCameraStorageButton.IsEnabled =
            !_cameraStorageBusy && selectedCount > 0;
        SelectAllCameraStorageButton.Content = AppLocalization.T(
            selectedCount > 0 &&
            selectedCount == _cameraStorageRows.Count(row => !row.Item.IsProtected)
                ? "取消全选"
                : "全选");
    }

    private void SetCameraStorageBusy(bool busy, string? status = null)
    {
        _cameraStorageBusy = busy;
        RefreshCameraStorageButton.IsEnabled =
            !busy && (_camera.IsConnected || _wifiCamera.IsConnected);
        SelectAllCameraStorageButton.IsEnabled =
            !busy && _cameraStorageRows.Count > 0;
        if (!string.IsNullOrWhiteSpace(status))
        {
            CameraStorageStatusText.Text = AppLocalization.T(status);
        }
        UpdateCameraStorageSelectionState();
    }

    private void RefreshPhotoList()
    {
        var libraryItems = _library.List();
        var systemItems = _library.ListSystemAlbum();
        var roots = new ObservableCollection<LibraryTreeNode>
        {
            BuildLocalLibraryNode(libraryItems),
            BuildSourceNode(
                "系统相册",
                "只读 · 保留在 Windows 图片库",
                systemItems),
            new()
            {
                Name = "无线传输",
                Detail = "FTP · HTTP · WebDAV",
                Icon = "⌁",
                IsExpanded = false
            }
        };
        PhotoTree.ItemsSource = roots;
        PhotoCountText.Text = AppLocalization.T(
            $"{libraryItems.Count} 个本地文件 · {systemItems.Count} 个系统相册项目");
        CaptureLibraryText.Text = AppLocalization.T(
            $"{libraryItems.Count} 个文件");
        DeletePhotoButton.IsEnabled = false;
        DeleteBranchButton.IsEnabled = false;
        SharePhotoButton.IsEnabled = false;
        DownloadPhotoButton.IsEnabled = false;
    }

    private LibraryTreeNode BuildSourceNode(
        string name,
        string detail,
        IReadOnlyList<PhotoItem> items)
    {
        var root = new LibraryTreeNode
        {
            Name = $"{name} · {items.Count}",
            Detail = detail,
            Icon = "▣",
            IsExpanded = true
        };
        root.Children.Add(BuildMediaTypeNode("照片", items, false));
        root.Children.Add(BuildMediaTypeNode("视频", items, true));
        return root;
    }

    private LibraryTreeNode BuildLocalLibraryNode(
        IReadOnlyList<PhotoItem> items)
    {
        var root = new LibraryTreeNode
        {
            Name = $"帧澈 ZENCHE 文件库 · {items.Count}",
            Detail = "用户分支与未分类媒体",
            Icon = "▣",
            IsExpanded = true
        };
        foreach (var branch in _libraryBranches)
        {
            root.Children.Add(BuildBranchNode(branch, items));
        }
        var unassigned = items
            .Where(item => !_libraryFileAssignments.ContainsKey(item.Path))
            .ToList();
        var unclassified = new LibraryTreeNode
        {
            Name = $"未分类 · {unassigned.Count}",
            Detail = "尚未放入用户分支的原始媒体",
            Icon = "▱",
            IsUnclassified = true,
            IsExpanded = true
        };
        unclassified.Children.Add(
            BuildMediaTypeNode("照片", unassigned, false));
        unclassified.Children.Add(
            BuildMediaTypeNode("视频", unassigned, true));
        root.Children.Add(unclassified);
        return root;
    }

    private static LibraryTreeNode BuildMediaTypeNode(
        string name,
        IReadOnlyList<PhotoItem> items,
        bool video)
    {
        var matches = items
            .Where(item => item.IsVideo == video)
            .OrderByDescending(item => File.GetLastWriteTimeUtc(item.Path))
            .ToList();
        var node = new LibraryTreeNode
        {
            Name = $"{name} · {matches.Count}",
            Detail = matches.Count == 0 ? $"暂无{name}" : "",
            Icon = video ? "▶" : "▧",
            IsExpanded = true
        };
        foreach (var item in matches)
        {
            node.Children.Add(new LibraryTreeNode
            {
                Name = item.Name,
                Detail = item.Detail,
                Icon = item.IsVideo ? "▶" : "◫",
                Thumbnail = CreateLibraryThumbnail(item),
                Item = item
            });
        }
        return node;
    }

    private LibraryTreeNode BuildBranchNode(
        LibraryBranch branch,
        IReadOnlyList<PhotoItem> items)
    {
        var assigned = items
            .Where(item =>
                _libraryFileAssignments.TryGetValue(
                    item.Path,
                    out var branchId) &&
                branchId == branch.Id)
            .ToList();
        var node = new LibraryTreeNode
        {
            Name = branch.Name,
            Detail = $"{assigned.Count} 个文件 · {branch.Children.Count} 个子分支",
            Icon = "▱",
            BranchId = branch.Id,
            IsExpanded = true
        };
        foreach (var item in assigned)
        {
            node.Children.Add(new LibraryTreeNode
            {
                Name = item.Name,
                Detail = item.Detail,
                Icon = item.IsVideo ? "▶" : "◫",
                Thumbnail = CreateLibraryThumbnail(item),
                Item = item
            });
        }
        foreach (var child in branch.Children)
        {
            node.Children.Add(BuildBranchNode(child, items));
        }
        return node;
    }

    private static BitmapSource? CreateLibraryThumbnail(PhotoItem item)
    {
        if (item.IsVideo)
        {
            return null;
        }
        try
        {
            var thumbnail = new BitmapImage();
            thumbnail.BeginInit();
            thumbnail.CacheOption = BitmapCacheOption.OnLoad;
            thumbnail.DecodePixelWidth = 112;
            thumbnail.UriSource = new Uri(item.Path, UriKind.Absolute);
            thumbnail.EndInit();
            thumbnail.Freeze();
            return thumbnail;
        }
        catch
        {
            return null;
        }
    }

    private void RefreshImageEditor()
    {
        if (_editorInAiMode)
        {
            RefreshAiEditor();
            return;
        }
        var previousPath = _editorSelectedPath;
        var choices = _library.List()
            .Where(item => !item.IsVideo && IsEditableImage(item.Path))
            .Select(item => new EditorPhotoChoice { Item = item })
            .ToList();
        _updatingEditorControls = true;
        EditorPhotoBox.ItemsSource = choices;
        EditorPhotoTree.ItemsSource = BuildEditorPhotoTree(
            choices.Select(choice => choice.Item).ToList());
        var selected = choices.FirstOrDefault(choice =>
            string.Equals(
                choice.Item.Path,
                _editorSelectedPath,
                StringComparison.OrdinalIgnoreCase)) ?? choices.FirstOrDefault();
        EditorPhotoBox.SelectedItem = selected;
        _editorSelectedPath = selected?.Item.Path;
        EditorPhotoPickerButton.Content = selected is null
            ? "选择照片"
            : $"▧  {selected.Item.Name}";
        EditorMediaCountText.Text = choices.Count.ToString(CultureInfo.InvariantCulture);
        EditorMediaSelectionText.Text = selected?.Item.Name
            ?? AppLocalization.T("未选择照片");
        _updatingEditorControls = false;
        if (!string.Equals(
                previousPath,
                _editorSelectedPath,
                StringComparison.OrdinalIgnoreCase))
        {
            ResetEditorControls();
        }
        UpdateEditorPreview();
    }

    private ObservableCollection<LibraryTreeNode> BuildEditorPhotoTree(
        IReadOnlyList<PhotoItem> photos)
    {
        var roots = new ObservableCollection<LibraryTreeNode>();
        var unclassified = photos
            .Where(item => !_libraryFileAssignments.ContainsKey(item.Path))
            .OrderByDescending(item => File.GetLastWriteTimeUtc(item.Path))
            .ToList();
        var unclassifiedNode = new LibraryTreeNode
        {
            Name = $"未分类 · {unclassified.Count}",
            Detail = "尚未放入用户分支的可编辑照片",
            Icon = "▱",
            IsUnclassified = true,
            IsExpanded = true
        };
        foreach (var item in unclassified)
        {
            unclassifiedNode.Children.Add(new LibraryTreeNode
            {
                Name = item.Name,
                Detail = item.Detail,
                Icon = "◫",
                Thumbnail = CreateLibraryThumbnail(item),
                Item = item
            });
        }
        roots.Add(unclassifiedNode);
        foreach (var branch in _libraryBranches)
        {
            roots.Add(BuildBranchNode(branch, photos));
        }
        return roots;
    }

    private void RefreshAiEditor()
    {
        var editablePhotos = _library.List()
            .Where(item => !item.IsVideo && IsEditableImage(item.Path))
            .ToList();
        if (_aiMode == 0 && (string.IsNullOrWhiteSpace(_editorSelectedPath) ||
            !editablePhotos.Any(item => string.Equals(
                item.Path,
                _editorSelectedPath,
                StringComparison.OrdinalIgnoreCase))))
        {
            _editorSelectedPath = editablePhotos.FirstOrDefault()?.Path;
        }
        var selectedPhoto = editablePhotos.FirstOrDefault(item => string.Equals(
            item.Path,
            _editorSelectedPath,
            StringComparison.OrdinalIgnoreCase));
        AiPhotoPickerButton.Content = selectedPhoto is null
            ? AppLocalization.T("选择照片")
            : $"▧  {selectedPhoto.Name}";
        EditorHeaderTitle.Text = AppLocalization.T("AI 工具");
        EditorHeaderSubtitle.Text = AppLocalization.T(
            "基于 nano-banana-2 模型的 AI 修图与生图；需在设置中输入激活码解锁。");
        UpdateEditorToolStrip("ai");
        EditorProGrid.Visibility = Visibility.Collapsed;
        EditorAiGrid.Visibility = Visibility.Visible;
        ApplyResponsiveEditorLayout();
        AiEditModeBtn.Style = (Style)FindResource(
            _aiMode == 0 ? "PrimaryButton" : "ButtonBase");
        AiGenModeBtn.Style = (Style)FindResource(
            _aiMode == 1 ? "PrimaryButton" : "ButtonBase");
        AiPromptBox.Text = _aiPrompt;
        AiPromptBox.TextChanged -= AiPromptBox_TextChanged;
        AiPromptBox.TextChanged += AiPromptBox_TextChanged;
        AiUnlockStatus.Text = IsAiActivated()
            ? AppLocalization.T($"已解锁 · 剩余 {CurrentRemainingUsage()} 次")
            : AppLocalization.T("需要激活");
        AiUnlockStatus.Foreground = IsAiActivated()
            ? (System.Windows.Media.Brush)FindResource("PositiveBrush")
            : (System.Windows.Media.Brush)FindResource("MutedBrush");
        AiRatioBox.SelectedIndex = Math.Clamp(_aiRatioIndex, 0, AiRatioBox.Items.Count - 1);
        AiResolutionBox.SelectedIndex = Math.Clamp(_aiResolutionIndex, 0, AiResolutionBox.Items.Count - 1);
        AiStatusText.Text = AppLocalization.T(
            _aiResultPath != null ? "生成完成" : "请输入提示词");
        var previewPath = _aiResultPath ?? (
            _aiMode == 0 && File.Exists(_editorSelectedPath)
                ? _editorSelectedPath
                : null);
        AiPreviewBadge.Text = AppLocalization.T(
            _aiResultPath != null ? "AI 生成" : "原图");
        AiPreviewBadge.Visibility = previewPath != null
            ? Visibility.Visible
            : Visibility.Collapsed;
        AiSaveBtn.Visibility = _aiResultPath != null
            ? Visibility.Visible
            : Visibility.Collapsed;
        AiDownloadBtn.Visibility = _aiResultPath != null
            ? Visibility.Visible
            : Visibility.Collapsed;
        AiPreviewEmpty.Visibility = previewPath != null
            ? Visibility.Collapsed
            : Visibility.Visible;
        if (previewPath != null)
        {
            try
            {
                var image = new BitmapImage();
                image.BeginInit();
                if (_aiResultPath != null)
                {
                    // 临时结果需在生命周期切换时删除：立即解码并释放文件句柄。
                    image.CacheOption = BitmapCacheOption.OnLoad;
                }
                image.UriSource = new Uri(previewPath);
                image.EndInit();
                AiPreviewImage.Source = image;
            }
            catch { }
        }
        else
        {
            AiPreviewImage.Source = null;
        }
        RefreshAiPresets();
    }

    private void RefreshAiPresets()
    {
        AiPresetPanel.Children.Clear();
        var clear = new Button { Content = AppLocalization.T("清空"), Height = 44, Margin = new Thickness(0, 0, 6, 6), Style = (Style)FindResource("ButtonBase") };
        clear.Click += (_, _) => { _aiSelectedPresets.Clear(); _aiManualPrompt = ""; AiPromptBox.Text = ComposeAiPrompt(); };
        AiPresetPanel.Children.Add(clear);
        var modules = new List<(string Category, string[] Values)>
        {
            ("主体", ["人像主体", "产品主体", "建筑主体", "风光主体", "食物主体"]),
            ("光线", ["柔和自然光", "电影感侧光", "金色时刻", "低调棚拍光", "夜景霓虹光"]),
            ("色彩", ["自然通透", "胶片暖调", "日系清新", "高反差黑白", "冷色城市"]),
            ("质感", ["保留真实皮肤纹理", "细节清晰", "轻微胶片颗粒", "柔和高光", "高动态范围"]),
            ("构图", ["浅景深", "干净背景", "对称构图", "环境叙事", "视觉焦点明确"]),
            ("约束", ["保持人物身份和五官", "不改变产品形状", "不添加多余物体", "不过度磨皮", "保留自然阴影"])
        };
        if (_aiMode == 0)
        {
            modules.Insert(5, (
                "智能移除",
                [
                    "去路人并自然补全背景",
                    "去穿帮并移除摄影器材、工作人员、反光与杂物"
                ]));
        }
        foreach (var module in modules)
        {
            AiPresetPanel.Children.Add(new TextBlock { Text = AppLocalization.T(module.Category), Foreground = (Brush)FindResource("MutedBrush"), Margin = new Thickness(0, 4, 0, 2) });
            var choices = new WrapPanel
            {
                HorizontalAlignment = HorizontalAlignment.Stretch,
                Margin = new Thickness(0, 0, 0, 6)
            };
            foreach (var value in module.Values)
            {
                var key = $"{module.Category}:{value}";
                var button = new Button { Content = AppLocalization.T(value), Height = 44, Margin = new Thickness(0, 0, 6, 6), Padding = new Thickness(10, 0, 10, 0), Style = (Style)FindResource("ButtonBase") };
                button.IsHitTestVisible = true;
                button.Click += (_, _) =>
                {
                    var selected = _aiSelectedPresets.Contains(key);
                    _aiSelectedPresets.RemoveWhere(item => item.StartsWith(module.Category + ":", StringComparison.Ordinal));
                    if (!selected) _aiSelectedPresets.Add(key);
                    AiPromptBox.Text = ComposeAiPrompt();
                };
                choices.Children.Add(button);
            }
            AiPresetPanel.Children.Add(choices);
        }
    }

    private void AiPromptBox_TextChanged(object sender, TextChangedEventArgs e)
    {
        if (AiPromptBox.IsFocused) _aiManualPrompt = AiPromptBox.Text.Trim();
    }

    private string ComposeAiPrompt()
    {
        var parts = new List<string>();
        if (!string.IsNullOrWhiteSpace(_aiManualPrompt)) parts.Add(_aiManualPrompt.Trim());
        foreach (var category in new[] { "主体", "光线", "色彩", "质感", "构图", "智能移除", "约束" })
        {
            var values = _aiSelectedPresets.Where(item => item.StartsWith(category + ":", StringComparison.Ordinal)).Select(item => item[(category.Length + 1)..]).ToArray();
            if (values.Length > 0) parts.Add($"{category}：{string.Join("、", values)}");
        }
        return string.Join("。", parts);
    }

    private void AiEditMode_Click(object sender, RoutedEventArgs e)
    {
        _aiMode = 0;
        ClearAiResultFile();
        _aiPrompt = ComposeAiPrompt();
        RefreshAiEditor();
        RefreshAiPresets();
    }

    private void AiGenMode_Click(object sender, RoutedEventArgs e)
    {
        _aiMode = 1;
        ClearAiResultFile();
        _aiSelectedPresets.RemoveWhere(item => item.StartsWith(
            "智能移除:",
            StringComparison.Ordinal));
        _aiPrompt = ComposeAiPrompt();
        RefreshAiEditor();
        RefreshAiPresets();
    }

    private void AiRatioBox_SelectionChanged(
        object sender,
        SelectionChangedEventArgs e)
    {
        if (AiRatioBox.SelectedIndex >= 0)
            _aiRatioIndex = AiRatioBox.SelectedIndex;
    }

    private void AiResolutionBox_SelectionChanged(
        object sender,
        SelectionChangedEventArgs e)
    {
        if (AiResolutionBox.SelectedIndex >= 0)
            _aiResolutionIndex = AiResolutionBox.SelectedIndex;
    }

    private async void AiGenerate_Click(object sender, RoutedEventArgs e)
    {
        _aiPrompt = AiPromptBox.Text.Trim();
        if (string.IsNullOrWhiteSpace(_aiPrompt))
        {
            AiStatusText.Text = AppLocalization.T("请输入提示词");
            return;
        }
        if (!IsAiActivated())
        {
            AiStatusText.Text = AppLocalization.T(
                "请先在设置中输入激活码解锁 AI 功能");
            return;
        }
        if (!HasAiUsageAvailable())
        {
            AiStatusText.Text = AppLocalization.T("AI 次数已用完，请重新兑换激活码");
            return;
        }
        if (_aiMode == 0 &&
            (string.IsNullOrWhiteSpace(_editorSelectedPath) ||
             !File.Exists(_editorSelectedPath)))
        {
            AiStatusText.Text = AppLocalization.T(
                "请先选择一张照片用于 AI 修图");
            return;
        }
        var activationCode = LoadActivationCode();
        _aiGenerating = true;
        AiGenerateBtn.IsEnabled = false;
        AiGenerateBtn.Content = AppLocalization.T("正在生成…");
        AiStatusText.Text = AppLocalization.T("正在调用 AI 模型…");
        try
        {
            var endpoint = $"{LoadAiServerUrl().TrimEnd('/')}/v1/ai";
            var size = AiSizes[Math.Clamp(_aiRatioIndex, 0, AiSizes.Length - 1)];
            var body = new Dictionary<string, object>
            {
                ["activationCode"] = activationCode,
                ["deviceId"] = GetDeviceId(),
                ["prompt"] = _aiPrompt,
                ["size"] = size
            };
            if (_aiMode == 0 && _editorSelectedPath != null)
            {
                var sourceBytes = await File.ReadAllBytesAsync(
                    _editorSelectedPath);
                if (sourceBytes.Length == 0)
                {
                    throw new InvalidOperationException(
                        "原图为空，未发送 AI 修图请求");
                }
                var b64 = Convert.ToBase64String(sourceBytes);
                body["image"] = $"data:{ImageMimeType(_editorSelectedPath)};base64,{b64}";
            }
            using var client = new HttpClient();
            client.Timeout = TimeSpan.FromSeconds(300);
            var content = new StringContent(
                JsonSerializer.Serialize(body),
                System.Text.Encoding.UTF8,
                "application/json");
            using var request = new HttpRequestMessage(HttpMethod.Post, endpoint)
            {
                Content = content
            };
            var accountToken = _authService.GetToken();
            if (Uri.TryCreate(endpoint, UriKind.Absolute, out var aiEndpoint)
                && aiEndpoint.Scheme.Equals(
                    Uri.UriSchemeHttps,
                    StringComparison.OrdinalIgnoreCase)
                && !string.IsNullOrWhiteSpace(accountToken))
            {
                request.Headers.Authorization =
                    new System.Net.Http.Headers.AuthenticationHeaderValue(
                        "Bearer", accountToken);
            }
            using var response = await client.SendAsync(request);
            var serverRemaining = ReadServerRemainingUsage(response);
            if (!response.IsSuccessStatusCode)
            {
                var code = (int)response.StatusCode;
                if (code == 403)
                {
                    _aiServerRemainingUsage = serverRemaining ?? 0;
                    SaveServerRemainingUsage(_aiServerRemainingUsage.Value);
                }
                if (code == 403)
                    throw new Exception("激活码无效或次数用完");
                if (code == 502)
                    throw new Exception("AI 服务暂时不可用");
                throw new Exception($"API 服务返回错误 {code}");
            }
            // The proxy is authoritative. Keep the local counter only for old
            // proxy deployments that do not return the remaining-use header.
            if (serverRemaining is { } remaining)
            {
                _aiServerRemainingUsage = remaining;
                SaveServerRemainingUsage(remaining);
            }
            var json = await response.Content.ReadAsStringAsync();
            using var doc = JsonDocument.Parse(json);
            var dataArr = doc.RootElement.GetProperty("data");
            if (dataArr.GetArrayLength() == 0)
                throw new Exception("AI 未返回有效图片");
            var first = dataArr[0];
            byte[] imageBytes;
            if (first.TryGetProperty("b64_json", out var b64El) &&
                b64El.GetString() is { Length: > 0 } b64Str)
            {
                imageBytes = Convert.FromBase64String(b64Str);
            }
            else if (first.TryGetProperty("url", out var urlEl) &&
                     urlEl.GetString() is { Length: > 0 } imageUrl)
            {
                imageBytes = await client.GetByteArrayAsync(imageUrl);
            }
            else
            {
                throw new Exception("AI 未返回有效图片");
            }
            var tempPath = Path.Combine(
                Path.GetTempPath(),
                $"zenche_ai_{DateTime.Now:yyyyMMddHHmmss}_{Guid.NewGuid():N}.jpg");
            await File.WriteAllBytesAsync(tempPath, imageBytes);
            ClearAiResultFile();
            _aiResultPath = tempPath;
            if (serverRemaining is null)
            {
                RecordAiUsage();
                _aiServerRemainingUsage = GetLocalRemainingUsage();
                SaveServerRemainingUsage(_aiServerRemainingUsage.Value);
            }
            AiStatusText.Text = AppLocalization.T("生成完成");
        }
        catch (Exception error)
        {
            _diagnostics.Error("ai", $"AI 调用失败：{error.Message}");
            AiStatusText.Text = AppLocalization.T(
                $"AI 生成失败：{error.Message}");
        }
        finally
        {
            _aiGenerating = false;
            AiGenerateBtn.IsEnabled = true;
            AiGenerateBtn.Content = AppLocalization.T("生成图像");
            RefreshAiEditor();
        }
    }

    private void AiSave_Click(object sender, RoutedEventArgs e)
    {
        if (_localDownloadPreparationBusy || _localDownloadBusy)
        {
            return;
        }
        SaveAiResultCopy();
    }

    private async void AiDownload_Click(object sender, RoutedEventArgs e)
    {
        if (_localDownloadBusy || _localDownloadPreparationBusy)
        {
            return;
        }
        var sourcePath = _aiResultPath;
        if (string.IsNullOrWhiteSpace(sourcePath) || !File.Exists(sourcePath))
        {
            return;
        }
        var destination = UniqueDestination(
            AiResultFileName(_aiMode, _editorSelectedPath));

        _localDownloadPreparationBusy = true;
        AiSaveBtn.IsEnabled = false;
        AiDownloadBtn.IsEnabled = false;
        try
        {
            AiStatusText.Text = AppLocalization.T("正在保存…");
            await Task.Run(() => SaveAiResultCopyCore(
                sourcePath,
                destination));
            _editorSelectedPath = destination;
            RefreshPhotoList();
            RefreshImageEditor();
            AiStatusText.Text = AppLocalization.T(
                $"已保存 AI 结果 · {Path.GetFileName(destination)}");
            await DownloadFileToLocalAsync(
                destination,
                Path.GetFileName(destination),
                message => AiStatusText.Text = message,
                preparationOwner: true);
        }
        catch (Exception error)
        {
            _diagnostics.Error("ai", $"准备 AI 本地副本失败：{error.Message}");
            AiStatusText.Text = AppLocalization.T("保存 AI 结果失败");
        }
        finally
        {
            _localDownloadPreparationBusy = false;
            var canSave = _aiResultPath is { } resultPath &&
                File.Exists(resultPath);
            AiSaveBtn.IsEnabled = canSave;
            AiDownloadBtn.IsEnabled = canSave;
        }
    }

    private string? SaveAiResultCopy()
    {
        if (_localDownloadPreparationBusy || _localDownloadBusy)
        {
            return null;
        }
        if (_aiResultPath == null || !File.Exists(_aiResultPath))
        {
            return null;
        }
        try
        {
            var destination = UniqueDestination(
                AiResultFileName(_aiMode, _editorSelectedPath));
            SaveAiResultCopyCore(_aiResultPath, destination);
            _editorSelectedPath = destination;
            RefreshPhotoList();
            RefreshImageEditor();
            AiStatusText.Text = AppLocalization.T(
                $"已保存 AI 结果 · {Path.GetFileName(destination)}");
            return destination;
        }
        catch (Exception error)
        {
            _diagnostics.Error("ai", $"保存 AI 结果失败：{error.Message}");
            AiStatusText.Text = AppLocalization.T("保存 AI 结果失败");
            return null;
        }
    }

    private static string AiResultFileName(
        int aiMode,
        string? editorSourcePath) =>
        aiMode == 0 &&
        !string.IsNullOrWhiteSpace(editorSourcePath) &&
        File.Exists(editorSourcePath)
            ? $"{Path.GetFileNameWithoutExtension(editorSourcePath)}_ai_edited_"
                + $"{DateTime.Now:yyyyMMdd_HHmmss}_{Guid.NewGuid():N}.jpg"
            : $"ai_generated_{DateTime.Now:yyyyMMdd_HHmmss}_"
                + $"{Guid.NewGuid():N}.jpg";

    private static void SaveAiResultCopyCore(
        string sourcePath,
        string destination)
    {
        using var source = File.OpenRead(sourcePath);
        var bytes = new byte[source.Length];
        source.ReadExactly(bytes);
        using var memory = new MemoryStream(bytes, writable: false);
        var decoder = BitmapDecoder.Create(
            memory,
            BitmapCreateOptions.PreservePixelFormat,
            BitmapCacheOption.OnLoad);
        SaveBitmapAtomically(destination, decoder.Frames[0]);
    }

    public string UniqueDestination(string filename)
    {
        return Path.Combine(_library.DirectoryPath, filename);
    }

    private static void SaveBitmapAtomically(
        string destination,
        BitmapSource bitmap)
    {
        var temporary = destination + $".zenche-{Guid.NewGuid():N}.tmp";
        try
        {
            var extension = Path.GetExtension(destination);
            BitmapEncoder encoder = extension.ToLowerInvariant() switch
            {
                ".png" => new PngBitmapEncoder(),
                ".bmp" => new BmpBitmapEncoder(),
                ".tif" or ".tiff" => new TiffBitmapEncoder(),
                _ => new JpegBitmapEncoder { QualityLevel = 95 }
            };
            encoder.Frames.Add(BitmapFrame.Create(bitmap));
            using (var fileStream = new FileStream(
                       temporary,
                       FileMode.CreateNew,
                       FileAccess.Write,
                       FileShare.None))
            {
                encoder.Save(fileStream);
                fileStream.Flush(true);
            }
            if (File.Exists(destination))
            {
                File.Replace(temporary, destination, null);
            }
            else
            {
                File.Move(temporary, destination);
            }
        }
        finally
        {
            if (File.Exists(temporary))
            {
                File.Delete(temporary);
            }
        }
    }

    /// <summary>
    /// 释放当前 AI 临时结果：遗忘路径引用并尽力删除本应用写入系统临时
    /// 目录的 zenche_ai_*.jpg 文件。容错：任何失败都不抛出、不阻断调用
    /// 路径；只删除与本应用生成命名完全匹配且位于系统临时目录的文件，
    /// 绝不触碰用户保存的正式副本或其它应用文件。
    /// </summary>
    private void ClearAiResultFile()
    {
        var path = _aiResultPath;
        _aiResultPath = null;
        TryDeleteAiTempFile(path);
    }

    /// <summary>
    /// 仅当 path 确属本应用写入系统临时目录的 zenche_ai_*.jpg 时尽力
    /// 删除，否则原样忽略。删除失败（如文件正被占用）静默容忍；异常
    /// 退出或瞬时占用可能遗留单个文件，避免目录级清扫与另一实例竞态。
    /// </summary>
    private static void TryDeleteAiTempFile(string? path)
    {
        if (string.IsNullOrWhiteSpace(path))
        {
            return;
        }
        try
        {
            var tempRoot = Path.GetTempPath().TrimEnd(
                Path.DirectorySeparatorChar,
                Path.AltDirectorySeparatorChar);
            if (!string.Equals(
                    Path.GetDirectoryName(path),
                    tempRoot,
                    StringComparison.OrdinalIgnoreCase))
            {
                return;
            }
            var fileName = Path.GetFileName(path);
            if (!fileName.StartsWith(
                    "zenche_ai_",
                    StringComparison.Ordinal) ||
                !fileName.EndsWith(
                    ".jpg",
                    StringComparison.OrdinalIgnoreCase))
            {
                return;
            }
            if (File.Exists(path))
            {
                File.Delete(path);
            }
        }
        catch
        {
            // 尽力而为：清理失败绝不阻断调用路径。
        }
    }

    private static string ImageMimeType(string? path)
    {
        return Path.GetExtension(path ?? string.Empty).ToLowerInvariant() switch
        {
            ".png" => "image/png",
            ".heic" or ".heif" => "image/heic",
            ".tif" or ".tiff" => "image/tiff",
            ".bmp" => "image/bmp",
            _ => "image/jpeg"
        };
    }

    private void EditorPhotoBox_SelectionChanged(
        object sender,
        SelectionChangedEventArgs e)
    {
        if (_initializing || _updatingEditorControls)
        {
            return;
        }
        _editorSelectedPath =
            (EditorPhotoBox.SelectedItem as EditorPhotoChoice)?.Item.Path;
        ResetEditorControls();
        UpdateEditorPreview();
    }

    private void EditorPhotoPickerButton_Click(
        object sender,
        RoutedEventArgs e)
    {
        if (sender is FrameworkElement target)
        {
            EditorPhotoPickerPopup.PlacementTarget = target;
        }
        EditorPhotoPickerPopup.IsOpen = true;
    }

    private void EditorPhotoTree_SelectedItemChanged(
        object sender,
        RoutedPropertyChangedEventArgs<object> e)
    {
        if (_updatingEditorControls ||
            e.NewValue is not LibraryTreeNode { Item: { } item })
        {
            return;
        }
        _editorSelectedPath = item.Path;
        ClearAiResultFile();
        var choice = EditorPhotoBox.Items
            .OfType<EditorPhotoChoice>()
            .FirstOrDefault(candidate =>
                string.Equals(
                    candidate.Item.Path,
                    item.Path,
                    StringComparison.OrdinalIgnoreCase));
        _updatingEditorControls = true;
        EditorPhotoBox.SelectedItem = choice;
        _updatingEditorControls = false;
        EditorPhotoPickerButton.Content = $"▧  {item.Name}";
        EditorPhotoPickerPopup.IsOpen = false;
        ResetEditorControls();
        if (_editorInAiMode)
            RefreshAiEditor();
        else
            UpdateEditorPreview();
    }

    private void BuildEditorAdjustmentControls()
    {
        EditorAdjustmentHost.Children.Clear();
        _editorSliders.Clear();
        EditorAdjustmentHost.Children.Add(CreateEditorGroup(
            "光线",
            true,
            new EditorSliderSpec("exposure", "曝光", -2, 2, true),
            new EditorSliderSpec("contrast", "对比度", -100, 100),
            new EditorSliderSpec("highlights", "高光", -100, 100),
            new EditorSliderSpec("shadows", "阴影", -100, 100),
            new EditorSliderSpec("whites", "白色色阶", -100, 100),
            new EditorSliderSpec("blacks", "黑色色阶", -100, 100)));
        EditorAdjustmentHost.Children.Add(CreateEditorGroup(
            "色彩",
            false,
            new EditorSliderSpec("temperature", "色温", -100, 100),
            new EditorSliderSpec("tint", "色调", -100, 100),
            new EditorSliderSpec("vibrance", "自然饱和度", -100, 100),
            new EditorSliderSpec("saturation", "饱和度", -100, 100)));
        EditorAdjustmentHost.Children.Add(CreateEditorColorWheelsGroup());
        EditorAdjustmentHost.Children.Add(CreateEditorCurvesGroup());
        EditorAdjustmentHost.Children.Add(CreateEditorPickerGroup());
        EditorAdjustmentHost.Children.Add(CreateEditorMaskGroup());
        EditorAdjustmentHost.Children.Add(CreateEditorGroup(
            "细节",
            false,
            new EditorSliderSpec("texture", "纹理", -100, 100),
            new EditorSliderSpec("clarity", "清晰度", -100, 100),
            new EditorSliderSpec("sharpening", "锐化", 0, 100),
            new EditorSliderSpec("noiseReduction", "降噪", 0, 100)));
        EditorAdjustmentHost.Children.Add(CreateEditorGroup(
            "效果",
            false,
            new EditorSliderSpec("dehaze", "去雾", -100, 100),
            new EditorSliderSpec("vignette", "暗角", -100, 100)));
        EditorAdjustmentHost.Children.Add(CreateEditorGeometryGroup());
    }

    private Expander CreateEditorColorWheelsGroup()
    {
        var content = new StackPanel { Margin = new Thickness(8, 6, 8, 10) };
        var intro = new TextBlock
        {
            Text = AppLocalization.T("Lift / Gamma / Gain · 三向色轮"),
            Foreground = (Brush)FindResource("MutedBrush"),
            FontSize = 11,
            Margin = new Thickness(0, 0, 0, 8)
        };
        content.Children.Add(intro);
        var wheels = new UniformGrid { Columns = 3, Rows = 1 };
        wheels.Children.Add(CreateColorWheel("lift", "阴影", "WheelLiftBrush"));
        wheels.Children.Add(CreateColorWheel("gamma", "中间调", "WheelGammaBrush"));
        wheels.Children.Add(CreateColorWheel("gain", "高光", "WheelGainBrush"));
        content.Children.Add(wheels);
        return new Expander
        {
            Header = AppLocalization.T("色轮"),
            Content = content,
            Margin = new Thickness(0, 0, 0, 6),
            Style = (Style)FindResource("EditorExpander")
        };
    }

    private FrameworkElement CreateColorWheel(string key, string label, string color)
    {
        var amount = new TextBlock
        {
            Text = $"{EditorWheelXForKey(key):+0;-0;0}, {EditorWheelYForKey(key):+0;-0;0}",
            Foreground = (Brush)FindResource("MutedBrush"),
            FontFamily = (FontFamily)FindResource("MonoFont"),
            HorizontalAlignment = HorizontalAlignment.Center
        };
        var direct = new EditorWheelControl
        {
            Accent = (Brush)FindResource(color),
            XValue = EditorWheelXForKey(key),
            YValue = EditorWheelYForKey(key),
            Width = 76,
            Height = 76,
            HorizontalAlignment = HorizontalAlignment.Center
        };
        direct.ValueChanged += (x, y) =>
        {
            amount.Text = $"{x:+0;-0;0}, {y:+0;-0;0}";
            SetEditorWheelAdjustment(key, x, y);
            if (!_initializing && !_updatingEditorControls) UpdateEditorPreview();
        };
        _editorWheelControls[key] = direct;
        var panel = new StackPanel { Margin = new Thickness(3, 0, 3, 0) };
        panel.Children.Add(direct);
        panel.Children.Add(new TextBlock { Text = AppLocalization.T(label), FontWeight = FontWeights.SemiBold, HorizontalAlignment = HorizontalAlignment.Center, Margin = new Thickness(0, 5, 0, 0) });
        panel.Children.Add(amount);
        return panel;
    }

    private Expander CreateEditorCurvesGroup()
    {
        var content = new StackPanel { Margin = new Thickness(8, 6, 8, 10) };
        content.Children.Add(new TextBlock
        {
            Text = AppLocalization.T("主曲线 · 拖动曲线控制点"),
            Foreground = (Brush)FindResource("MutedBrush"),
            FontSize = 11,
            Margin = new Thickness(0, 0, 0, 8)
        });
        var curve = new EditorCurveControl(_editorAdjustments)
        {
            Height = 150,
            HorizontalAlignment = HorizontalAlignment.Stretch
        };
        curve.ValueChanged += (_, _) =>
        {
            if (!_initializing && !_updatingEditorControls) UpdateEditorPreview();
        };
        _editorCurveControl = curve;
        content.Children.Add(curve);
        content.Children.Add(new TextBlock
        {
            Text = AppLocalization.T("点击任意位置新增控制点，拖动控制点调整曲线"),
            Foreground = (Brush)FindResource("MutedBrush"),
            FontSize = 11,
            Margin = new Thickness(0, 6, 0, 0)
        });
        return new Expander { Header = AppLocalization.T("曲线"), Content = content, Margin = new Thickness(0, 0, 0, 6), Style = (Style)FindResource("EditorExpander") };
    }

    private FrameworkElement CreateEditorGradeSlider(string key, string label, double min, double max)
    {
        var valueText = new TextBlock { Text = "0", Foreground = (Brush)FindResource("MutedBrush"), FontFamily = (FontFamily)FindResource("MonoFont"), HorizontalAlignment = HorizontalAlignment.Right };
        var heading = new DockPanel();
        heading.Children.Add(new TextBlock { Text = AppLocalization.T(label), FontWeight = FontWeights.SemiBold });
        DockPanel.SetDock(valueText, Dock.Right); heading.Children.Add(valueText);
        var slider = new Slider { Tag = $"grade:{key}", Minimum = min, Maximum = max, TickFrequency = 1, SmallChange = 1, IsSnapToTickEnabled = true, Style = (Style)FindResource("EditorSlider") };
        _editorGradeSliders[key] = slider;
        slider.ValueChanged += (_, _) => { valueText.Text = $"{slider.Value:+0;-0;0}"; SetEditorAdjustment(key, slider.Value); if (!_initializing && !_updatingEditorControls) UpdateEditorPreview(); };
        var row = new StackPanel { Margin = new Thickness(0, 2, 0, 5), MinHeight = 45 };
        row.Children.Add(heading); row.Children.Add(slider); return row;
    }

    private Expander CreateEditorPickerGroup()
    {
        var content = new StackPanel { Margin = new Thickness(8, 6, 8, 10) };
        _editorPickedColorText = new TextBlock { Text = AppLocalization.T("未取样"), Foreground = (Brush)FindResource("MutedBrush"), FontFamily = (FontFamily)FindResource("MonoFont"), Margin = new Thickness(0, 0, 0, 8) };
        content.Children.Add(new TextBlock { Text = AppLocalization.T("在预览画面点击取样色彩，自动微调色温与色调"), Foreground = (Brush)FindResource("MutedBrush"), FontSize = 11, Margin = new Thickness(0, 0, 0, 6) });
        var arm = new Button { Content = AppLocalization.T("取色器"), Style = (Style)FindResource("EditorToolButton") };
        arm.Click += (_, _) => { _editorPickerArmed = !_editorPickerArmed; _editorAdjustments.PickerEnabled = _editorPickerArmed; arm.Content = AppLocalization.T(_editorPickerArmed ? "点击预览取色 · 再次关闭" : "取色器"); EditorStatusText.Text = AppLocalization.T(_editorPickerArmed ? "取色器已启用，请点击预览画面" : "取色器已关闭"); };
        var center = new Button { Content = AppLocalization.T("取样画面中心"), Style = (Style)FindResource("EditorToolButton"), Margin = new Thickness(0, 6, 0, 0) };
        center.Click += (_, _) => SampleEditorPixelAtCenter();
        content.Children.Add(arm); content.Children.Add(center); content.Children.Add(_editorPickedColorText);
        return new Expander { Header = AppLocalization.T("取色器"), Content = content, Margin = new Thickness(0, 0, 0, 6), Style = (Style)FindResource("EditorExpander") };
    }

    private Expander CreateEditorMaskGroup()
    {
        var content = new StackPanel { Margin = new Thickness(8, 6, 8, 10) };
        content.Children.Add(new TextBlock
        {
            Text = AppLocalization.T("蒙版列表"),
            FontWeight = FontWeights.SemiBold,
            Margin = new Thickness(0, 0, 0, 5)
        });
        _editorMaskListPanel = new StackPanel
        {
            Margin = new Thickness(0, 0, 0, 8)
        };
        content.Children.Add(_editorMaskListPanel);
        RefreshEditorMaskList();
        var lifecycle = new UniformGrid { Columns = 2, Margin = new Thickness(0, 0, 0, 8) };
        var create = new Button
        {
            Content = AppLocalization.T("创建蒙版"),
            Height = 44,
            Style = (Style)FindResource("PrimaryButton")
        };
        create.Click += (_, _) =>
        {
            _editorAdjustments.CreateMaskLayer();
            EditorStatusText.Text = AppLocalization.T("蒙版已创建 · 在预览画面涂抹");
            RefreshEditorMaskList();
            SyncEditorSliders();
            UpdateEditorPreview();
        };
        var delete = new Button
        {
            Content = AppLocalization.T("删除蒙版"),
            Height = 44,
            Margin = new Thickness(8, 0, 0, 0),
            Style = (Style)FindResource("EditorToolButton")
        };
        delete.Click += (_, _) =>
        {
            _editorAdjustments.DeleteActiveMaskLayer();
            _activeEditorMaskStroke = null;
            EditorStatusText.Text = AppLocalization.T("蒙版已删除");
            RefreshEditorMaskList();
            SyncEditorSliders();
            UpdateEditorPreview();
        };
        lifecycle.Children.Add(create);
        lifecycle.Children.Add(delete);
        content.Children.Add(lifecycle);

        var brushes = new UniformGrid { Columns = 2, Margin = new Thickness(0, 0, 0, 8) };
        var addBrush = new Button
        {
            Content = AppLocalization.T("添加蒙版（画笔）"),
            Height = 44,
            Style = (Style)FindResource("EditorToolButton")
        };
        addBrush.Click += (_, _) =>
        {
            _editorAdjustments.EnsureMaskLayer();
            _editorAdjustments.MaskAmount = Math.Max(1, _editorAdjustments.MaskAmount);
            _editorAdjustments.MaskSubtract = false;
            EditorStatusText.Text = AppLocalization.T("添加蒙版画笔已启用");
            RedrawEditorMaskOverlay();
        };
        var subtractBrush = new Button
        {
            Content = AppLocalization.T("减去蒙版（画笔）"),
            Height = 44,
            Margin = new Thickness(8, 0, 0, 0),
            Style = (Style)FindResource("EditorToolButton")
        };
        subtractBrush.Click += (_, _) =>
        {
            _editorAdjustments.EnsureMaskLayer();
            _editorAdjustments.MaskAmount = Math.Max(1, _editorAdjustments.MaskAmount);
            _editorAdjustments.MaskSubtract = true;
            EditorStatusText.Text = AppLocalization.T("减去蒙版画笔已启用");
            RedrawEditorMaskOverlay();
        };
        brushes.Children.Add(addBrush);
        brushes.Children.Add(subtractBrush);
        content.Children.Add(brushes);

        content.Children.Add(new TextBlock
        {
            Text = AppLocalization.T("智能识别"),
            FontWeight = FontWeights.SemiBold,
            Margin = new Thickness(0, 2, 0, 5)
        });
        var smartMasks = new WrapPanel { Margin = new Thickness(0, 0, 0, 8) };
        foreach (var type in new[]
                 {
                     "智能主体", "智能天空", "智能背景",
                     "智能人物", "智能亮部", "智能暗部"
                 })
        {
            var smart = new Button
            {
                Content = AppLocalization.T(type),
                MinHeight = 42,
                Margin = new Thickness(0, 0, 7, 7),
                Style = (Style)FindResource("EditorToolButton")
            };
            smart.Click += (_, _) =>
            {
                _editorAdjustments.EnsureMaskLayer();
                _editorAdjustments.MaskType = type;
                _editorAdjustments.MaskAmount = 100;
                _editorAdjustments.MaskInvert = false;
                _editorAdjustments.MaskSubtract = false;
                _editorAdjustments.MaskStrokes.Clear();
                EditorStatusText.Text = AppLocalization.T(
                    "智能蒙版已创建 · 可继续添加或减去画笔");
                SyncEditorSliders();
                UpdateEditorPreview();
            };
            smartMasks.Children.Add(smart);
        }
        content.Children.Add(smartMasks);

        _editorMaskBox = new ComboBox { ItemsSource = new[] { "无", "画笔", "线性渐变", "径向渐变", "智能主体", "智能天空", "智能背景", "智能人物", "智能亮部", "智能暗部" }.Select(AppLocalization.T).ToList(), SelectedIndex = 0, Style = (Style)FindResource("EditorComboBox") };
        _editorMaskBox.SelectionChanged += (_, _) => { if (!_updatingEditorControls) { if (_editorMaskBox.SelectedIndex > 0) _editorAdjustments.EnsureMaskLayer(); _editorAdjustments.MaskType = _editorMaskBox.SelectedIndex switch { 1 => "画笔", 2 => "线性渐变", 3 => "径向渐变", 4 => "智能主体", 5 => "智能天空", 6 => "智能背景", 7 => "智能人物", 8 => "智能亮部", 9 => "智能暗部", _ => "无" }; if (_editorAdjustments.MaskType != "无" && _editorAdjustments.MaskAmount == 0) _editorAdjustments.MaskAmount = 100; RefreshEditorMaskList(); UpdateEditorPreview(); } };
        content.Children.Add(new TextBlock { Text = AppLocalization.T("蒙版类型"), FontWeight = FontWeights.SemiBold });
        content.Children.Add(_editorMaskBox);
        content.Children.Add(new TextBlock { Text = AppLocalization.T("强度"), FontWeight = FontWeights.SemiBold });
        var amountRow = CreateEditorMaskSlider("maskAmount", "强度", out var amountSlider);
        _editorMaskAmountSlider = amountSlider;
        content.Children.Add(amountRow);
        content.Children.Add(new TextBlock { Text = AppLocalization.T("羽化"), FontWeight = FontWeights.SemiBold });
        var featherRow = CreateEditorMaskSlider("maskFeather", "羽化", out var featherSlider);
        _editorMaskFeatherSlider = featherSlider;
        content.Children.Add(featherRow);
        content.Children.Add(new TextBlock { Text = AppLocalization.T("画笔大小"), FontWeight = FontWeights.SemiBold });
        var brushSizeRow = CreateEditorMaskSlider("maskBrushSize", "画笔大小", out var brushSizeSlider);
        _editorMaskBrushSizeSlider = brushSizeSlider;
        content.Children.Add(brushSizeRow);
        var invert = new CheckBox { Content = AppLocalization.T("反向蒙版") };
        _editorMaskInvertCheckBox = invert;
        invert.Checked += (_, _) =>
        {
            if (_updatingEditorControls) return;
            _editorAdjustments.MaskInvert = true;
            UpdateEditorPreview();
        };
        invert.Unchecked += (_, _) =>
        {
            if (_updatingEditorControls) return;
            _editorAdjustments.MaskInvert = false;
            UpdateEditorPreview();
        };
        content.Children.Add(invert);
        content.Children.Add(new Separator { Margin = new Thickness(0, 8, 0, 8) });
        content.Children.Add(new TextBlock
        {
            Text = AppLocalization.T("蒙版内调整"),
            FontWeight = FontWeights.SemiBold,
            Margin = new Thickness(0, 0, 0, 5)
        });
        foreach (var parameter in new (string Key, string Label)[]
                 {
                     ("maskExposure", "曝光"),
                     ("maskContrast", "对比度"),
                     ("maskHighlights", "高光"),
                     ("maskShadows", "阴影"),
                     ("maskTemperature", "色温"),
                     ("maskTint", "色调"),
                     ("maskSaturation", "饱和度"),
                     ("maskClarity", "清晰度")
                 })
        {
            content.Children.Add(CreateEditorMaskSlider(
                parameter.Key,
                parameter.Label,
                out _));
        }
        content.Children.Add(new TextBlock
        {
            Text = AppLocalization.T("蓝色显示当前蒙版覆盖；橡皮会擦除蓝色区域。"),
            Foreground = (Brush)FindResource("MutedBrush"),
            FontSize = 11,
            TextWrapping = TextWrapping.Wrap
        });
        return new Expander { Header = AppLocalization.T("蒙版"), Content = content, Margin = new Thickness(0, 0, 0, 6), Style = (Style)FindResource("EditorExpander") };
    }

    private void RefreshEditorMaskList()
    {
        if (_editorMaskListPanel is null) return;
        _editorMaskListPanel.Children.Clear();
        if (_editorAdjustments.MaskLayers.Count == 0)
        {
            _editorMaskListPanel.Children.Add(new TextBlock
            {
                Text = AppLocalization.T("暂无蒙版"),
                Foreground = (Brush)FindResource("MutedBrush"),
                MinHeight = 44,
                VerticalAlignment = VerticalAlignment.Center
            });
            return;
        }
        foreach (var layer in _editorAdjustments.MaskLayers)
        {
            var displayed = _editorAdjustments.DisplayedMaskLayer(layer);
            var row = new Border
            {
                Background = layer.Id == _editorAdjustments.ActiveMaskLayerId
                    ? (Brush)FindResource("AccentSoftBrush")
                    : (Brush)FindResource("SurfaceBrush"),
                BorderBrush = layer.Id == _editorAdjustments.ActiveMaskLayerId
                    ? (Brush)FindResource("AccentBrush")
                    : (Brush)FindResource("RuleBrush"),
                BorderThickness = new Thickness(1),
                CornerRadius = (CornerRadius)FindResource("CornerRadius8"),
                Margin = new Thickness(0, 0, 0, 6)
            };
            // Light selection chips keep dark text despite the dark rail.
            System.Windows.Documents.TextElement.SetForeground(
                row, (Brush)FindResource("InkBrush"));
            var layout = new DockPanel { LastChildFill = true };
            var visibility = new CheckBox
            {
                Content = AppLocalization.T("显示"),
                IsChecked = layer.IsVisible,
                MinWidth = 68,
                MinHeight = 44,
                VerticalContentAlignment = VerticalAlignment.Center,
                Margin = new Thickness(6, 0, 4, 0),
                ToolTip = AppLocalization.T(
                    layer.IsVisible ? "隐藏蒙版" : "显示蒙版")
            };
            visibility.Checked += (_, _) =>
            {
                _editorAdjustments.SetMaskLayerVisible(layer.Id, true);
                RefreshEditorMaskList();
                RedrawEditorMaskOverlay();
                UpdateEditorPreview();
            };
            visibility.Unchecked += (_, _) =>
            {
                _editorAdjustments.SetMaskLayerVisible(layer.Id, false);
                RefreshEditorMaskList();
                RedrawEditorMaskOverlay();
                UpdateEditorPreview();
            };
            DockPanel.SetDock(visibility, Dock.Right);
            layout.Children.Add(visibility);
            var select = new Button
            {
                Content = $"{(layer.Id == _editorAdjustments.ActiveMaskLayerId ? "●" : "○")}  {AppLocalization.T(layer.Name)} · {AppLocalization.T(displayed.Type)}",
                MinHeight = 44,
                HorizontalContentAlignment = HorizontalAlignment.Left,
                Style = (Style)FindResource("ButtonBase")
            };
            select.Click += (_, _) =>
            {
                _editorAdjustments.SelectMaskLayer(layer.Id);
                _activeEditorMaskStroke = null;
                EditorStatusText.Text = AppLocalization.T("已切换蒙版");
                SyncEditorSliders();
                RefreshEditorMaskList();
                RedrawEditorMaskOverlay();
                UpdateEditorPreview();
            };
            layout.Children.Add(select);
            row.Child = layout;
            _editorMaskListPanel.Children.Add(row);
        }
    }

    private FrameworkElement CreateEditorMaskSlider(string key, string label, out Slider slider)
    {
        var valueText = new TextBlock { Text = "0", Foreground = (Brush)FindResource("MutedBrush"), FontFamily = (FontFamily)FindResource("MonoFont"), HorizontalAlignment = HorizontalAlignment.Right };
        var heading = new DockPanel();
        heading.Children.Add(new TextBlock { Text = AppLocalization.T(label), FontWeight = FontWeights.SemiBold });
        DockPanel.SetDock(valueText, Dock.Right); heading.Children.Add(valueText);
        var isExposure = key == "maskExposure";
        var isLocal = key is "maskContrast" or "maskHighlights" or "maskShadows"
            or "maskTemperature" or "maskTint" or "maskSaturation" or "maskClarity";
        var createdSlider = new Slider
        {
            Tag = $"grade:{key}",
            Minimum = key == "maskBrushSize" ? 4 : isExposure ? -2 : isLocal ? -100 : 0,
            Maximum = key == "maskBrushSize" ? 64 : isExposure ? 2 : 100,
            TickFrequency = isExposure ? .05 : 1,
            SmallChange = isExposure ? .05 : 1,
            IsSnapToTickEnabled = true,
            Value = EditorAdjustmentForKey(key),
            Style = (Style)FindResource("EditorSlider")
        };
        slider = createdSlider;
        _editorGradeSliders[key] = createdSlider;
        createdSlider.ValueChanged += (_, _) => { valueText.Text = isExposure ? $"{createdSlider.Value:+0.00;-0.00;0.00} EV" : $"{createdSlider.Value:+0;-0;0}"; SetEditorAdjustment(key, createdSlider.Value); if (!_initializing && !_updatingEditorControls) UpdateEditorPreview(); };
        var row = new StackPanel { Margin = new Thickness(0, 2, 0, 5), MinHeight = 45 };
        row.Children.Add(heading); row.Children.Add(createdSlider);
        return row;
    }

    private Expander CreateEditorGroup(
        string title,
        bool expanded,
        params EditorSliderSpec[] specifications)
    {
        var content = new StackPanel
        {
            Margin = new Thickness(8, 6, 8, 10)
        };
        foreach (var specification in specifications)
        {
            content.Children.Add(CreateEditorSlider(specification));
        }
        return new Expander
        {
            Header = AppLocalization.T(title),
            IsExpanded = expanded,
            Content = content,
            Margin = new Thickness(0, 0, 0, 6),
            Style = (Style)FindResource("EditorExpander")
        };
    }

    private FrameworkElement CreateEditorSlider(
        EditorSliderSpec specification)
    {
        var valueText = new TextBlock
        {
            Text = EditorAdjustmentValue(0, specification.Exposure),
            Foreground = (Brush)FindResource("MutedBrush"),
            FontFamily = (FontFamily)FindResource("MonoFont"),
            HorizontalAlignment = HorizontalAlignment.Right
        };
        var heading = new DockPanel();
        heading.Children.Add(new TextBlock
        {
            Text = AppLocalization.T(specification.Label),
            FontWeight = FontWeights.SemiBold
        });
        DockPanel.SetDock(valueText, Dock.Right);
        heading.Children.Add(valueText);

        var slider = new Slider
        {
            Tag = specification.Key,
            Minimum = specification.Minimum,
            Maximum = specification.Maximum,
            TickFrequency = specification.Exposure ? 0.05 : 1,
            SmallChange = specification.Exposure ? 0.05 : 1,
            IsSnapToTickEnabled = true,
            Style = (Style)FindResource("EditorSlider")
        };
        _editorSliders[specification.Key] = slider;
        slider.ValueChanged += (_, _) =>
        {
            valueText.Text = EditorAdjustmentValue(
                slider.Value,
                specification.Exposure);
            SetEditorAdjustment(specification.Key, slider.Value);
            if (!_initializing && !_updatingEditorControls)
            {
                UpdateEditorPreview();
            }
        };

        var row = new StackPanel
        {
            Margin = new Thickness(0, 2, 0, 8),
            MinHeight = 52
        };
        row.Children.Add(heading);
        row.Children.Add(slider);
        return row;
    }

    private Expander CreateEditorGeometryGroup()
    {
        var ratios = new[] { "原始比例", "1:1", "4:3", "3:2", "16:9" };
        _editorCropBox = new ComboBox
        {
            ItemsSource = ratios.Select(AppLocalization.T).ToList(),
            SelectedIndex = 0,
            Margin = new Thickness(0, 4, 0, 10),
            Style = (Style)FindResource("EditorComboBox")
        };
        _editorCropBox.SelectionChanged += (_, _) =>
        {
            if (_updatingEditorControls)
            {
                return;
            }
            _editorAdjustments.CropRatio =
                _editorCropBox.SelectedIndex switch
                {
                    1 => "1:1",
                    2 => "4:3",
                    3 => "3:2",
                    4 => "16:9",
                    _ => "original"
                };
            UpdateEditorPreview();
        };

        var rotate = EditorGeometryButton("旋转 90°");
        rotate.Click += (_, _) =>
        {
            _editorAdjustments.Rotation =
                (_editorAdjustments.Rotation + 90) % 360;
            UpdateEditorPreview();
        };
        var horizontal = EditorGeometryButton("水平翻转");
        horizontal.Click += (_, _) =>
        {
            _editorAdjustments.FlipHorizontal =
                !_editorAdjustments.FlipHorizontal;
            UpdateEditorPreview();
        };
        var vertical = EditorGeometryButton("垂直翻转");
        vertical.Click += (_, _) =>
        {
            _editorAdjustments.FlipVertical =
                !_editorAdjustments.FlipVertical;
            UpdateEditorPreview();
        };
        var actions = new UniformGrid
        {
            Columns = 3
        };
        actions.Children.Add(rotate);
        actions.Children.Add(horizontal);
        actions.Children.Add(vertical);

        var content = new StackPanel
        {
            Margin = new Thickness(8, 6, 8, 10)
        };
        content.Children.Add(new TextBlock
        {
            Text = AppLocalization.T("裁切比例"),
            FontWeight = FontWeights.SemiBold
        });
        content.Children.Add(_editorCropBox);
        content.Children.Add(actions);
        return new Expander
        {
            Header = AppLocalization.T("几何"),
            Content = content,
            Margin = new Thickness(0, 0, 0, 6),
            Style = (Style)FindResource("EditorExpander")
        };
    }

    private Button EditorGeometryButton(string label) => new()
    {
        Content = AppLocalization.T(label),
        MinHeight = 42,
        Margin = new Thickness(2),
        Style = (Style)FindResource("EditorToolButton")
    };

    private static string EditorAdjustmentValue(
        double value,
        bool exposure) =>
        exposure
            ? $"{value:+0.00;-0.00;0.00} EV"
            : $"{value:+0;-0;0}";

    private void SetEditorAdjustment(string key, double value)
    {
        switch (key)
        {
            case "exposure":
                _editorAdjustments.Exposure = value;
                break;
            case "contrast":
                _editorAdjustments.Contrast = value;
                break;
            case "highlights":
                _editorAdjustments.Highlights = value;
                break;
            case "shadows":
                _editorAdjustments.Shadows = value;
                break;
            case "whites":
                _editorAdjustments.Whites = value;
                break;
            case "blacks":
                _editorAdjustments.Blacks = value;
                break;
            case "temperature":
                _editorAdjustments.Temperature = value;
                break;
            case "tint":
                _editorAdjustments.Tint = value;
                break;
            case "vibrance":
                _editorAdjustments.Vibrance = value;
                break;
            case "saturation":
                _editorAdjustments.Saturation = value;
                break;
            case "texture":
                _editorAdjustments.Texture = value;
                break;
            case "clarity":
                _editorAdjustments.Clarity = value;
                break;
            case "sharpening":
                _editorAdjustments.Sharpening = value;
                break;
            case "noiseReduction":
                _editorAdjustments.NoiseReduction = value;
                break;
            case "dehaze":
                _editorAdjustments.Dehaze = value;
                break;
            case "vignette":
                _editorAdjustments.Vignette = value;
                break;
            case "lift": _editorAdjustments.Lift = value; break;
            case "gamma": _editorAdjustments.Gamma = value; break;
            case "gain": _editorAdjustments.Gain = value; break;
            case "curveShadows": _editorAdjustments.CurveShadows = value; break;
            case "curveMidtones": _editorAdjustments.CurveMidtones = value; break;
            case "curveHighlights": _editorAdjustments.CurveHighlights = value; break;
            case "maskAmount": _editorAdjustments.MaskAmount = value; break;
            case "maskFeather": _editorAdjustments.MaskFeather = value; break;
            case "maskBrushSize": _editorAdjustments.MaskBrushSize = value; break;
            case "maskExposure": _editorAdjustments.MaskExposure = value; break;
            case "maskContrast": _editorAdjustments.MaskContrast = value; break;
            case "maskHighlights": _editorAdjustments.MaskHighlights = value; break;
            case "maskShadows": _editorAdjustments.MaskShadows = value; break;
            case "maskTemperature": _editorAdjustments.MaskTemperature = value; break;
            case "maskTint": _editorAdjustments.MaskTint = value; break;
            case "maskSaturation": _editorAdjustments.MaskSaturation = value; break;
            case "maskClarity": _editorAdjustments.MaskClarity = value; break;
        }
    }

    private double EditorWheelXForKey(string key) => key switch
    {
        "lift" => _editorAdjustments.LiftX,
        "gamma" => _editorAdjustments.GammaX,
        "gain" => _editorAdjustments.GainX,
        _ => 0
    };

    private double EditorWheelYForKey(string key) => key switch
    {
        "lift" => _editorAdjustments.LiftY,
        "gamma" => _editorAdjustments.GammaY,
        "gain" => _editorAdjustments.GainY,
        _ => 0
    };

    private void SetEditorWheelAdjustment(string key, double x, double y)
    {
        switch (key)
        {
            case "lift": _editorAdjustments.LiftX = x; _editorAdjustments.LiftY = y; break;
            case "gamma": _editorAdjustments.GammaX = x; _editorAdjustments.GammaY = y; break;
            case "gain": _editorAdjustments.GainX = x; _editorAdjustments.GainY = y; break;
        }
    }

    private void EditorPresetBox_SelectionChanged(
        object sender,
        SelectionChangedEventArgs e)
    {
        if (_initializing ||
            _updatingEditorControls ||
            EditorPresetBox.SelectedItem is not ComboBoxItem item)
        {
            return;
        }
        _editorSettingsBeforeAI = null;
        UndoEditorAIButton.IsEnabled = false;
        EditorAISummaryText.Text = AppLocalization.T("等待分析当前照片");
        ApplyEditorPreset(Convert.ToString(item.Tag) ?? "original");
        SyncEditorSliders();
        UpdateEditorPreview();
    }

    private void NikonCloudPresetBox_SelectionChanged(
        object sender,
        SelectionChangedEventArgs e)
    {
        if (_initializing ||
            _updatingEditorControls ||
            NikonCloudPresetBox.SelectedItem is not ComboBoxItem item)
        {
            return;
        }
        if (item.Tag is not NikonCloudPreset preset)
        {
            _selectedNikonCloudPreset = null;
            ApplyEditorPreset("original");
            SyncEditorSliders();
            UpdateEditorPreview();
            EditorStatusText.Text = AppLocalization.T(
                "尼康云创预览已关闭");
            return;
        }
        ApplyNikonCloudPreset(preset);
        SyncEditorSliders();
        UpdateEditorPreview();
    }

    private void ClearNikonCloudPresetSelection()
    {
        _selectedNikonCloudPreset = null;
        if (NikonCloudPresetBox.SelectedIndex == 0) return;
        var wasUpdating = _updatingEditorControls;
        _updatingEditorControls = true;
        NikonCloudPresetBox.SelectedIndex = 0;
        _updatingEditorControls = wasUpdating;
    }

    private void ApplyNikonCloudPreset(NikonCloudPreset preset)
    {
        _updatingEditorControls = true;
        EditorPresetBox.SelectedIndex = 0;
        _updatingEditorControls = false;
        _editorAdjustments.ResetTone();
        var tone = preset.Tone;
        _editorAdjustments.Contrast = tone.Contrast;
        _editorAdjustments.Highlights = tone.Highlights;
        _editorAdjustments.Shadows = tone.Shadows;
        _editorAdjustments.Whites = tone.Whites;
        _editorAdjustments.Blacks = tone.Blacks;
        _editorAdjustments.Saturation = tone.Saturation;
        _editorAdjustments.Texture = tone.Texture;
        _editorAdjustments.Clarity = tone.Clarity;
        _editorAdjustments.Sharpening = tone.Sharpening;
        _editorAdjustments.LiftX = preset.Grading.Lift.X;
        _editorAdjustments.LiftY = preset.Grading.Lift.Y;
        _editorAdjustments.GammaX = preset.Grading.Gamma.X;
        _editorAdjustments.GammaY = preset.Grading.Gamma.Y;
        _editorAdjustments.GainX = preset.Grading.Gain.X;
        _editorAdjustments.GainY = preset.Grading.Gain.Y;
        if (preset.ToneCurve.Count > 1)
        {
            var denominator = preset.ToneCurve.Count - 1.0;
            _editorAdjustments.CurvePoints = preset.ToneCurve
                .Select((value, index) => new EditorCurvePoint(
                    index / denominator,
                    Math.Clamp(value, 0, 1)))
                .ToList();
        }
        _selectedNikonCloudPreset = preset;
        _editorSettingsBeforeAI = null;
        _editorAIAnalysis = null;
        UndoEditorAIButton.IsEnabled = false;
        EditorAISummaryText.Text = AppLocalization.T("等待分析当前照片");
        _editorAdjustments.ShowingOriginal = false;
        EditorStatusText.Text = AppLocalization.T(
            $"尼康云创预览 · {preset.Name} · SDR 近似");
    }

    private void ApplyEditorPreset(string preset)
    {
        ClearNikonCloudPresetSelection();
        _editorAdjustments.ResetTone();
        switch (preset)
        {
            case "natural":
                _editorAdjustments.Contrast = 8;
                _editorAdjustments.Highlights = -18;
                _editorAdjustments.Shadows = 16;
                _editorAdjustments.Whites = 8;
                _editorAdjustments.Blacks = -8;
                _editorAdjustments.Vibrance = 14;
                _editorAdjustments.Texture = 8;
                _editorAdjustments.Clarity = 6;
                _editorAdjustments.Sharpening = 24;
                _editorAdjustments.NoiseReduction = 8;
                break;
            case "portrait":
                _editorAdjustments.Contrast = -4;
                _editorAdjustments.Highlights = -24;
                _editorAdjustments.Shadows = 18;
                _editorAdjustments.Temperature = 7;
                _editorAdjustments.Tint = 4;
                _editorAdjustments.Vibrance = 10;
                _editorAdjustments.Texture = -12;
                _editorAdjustments.Clarity = -6;
                _editorAdjustments.Sharpening = 16;
                _editorAdjustments.NoiseReduction = 22;
                _editorAdjustments.Vignette = -8;
                break;
            case "landscape":
                _editorAdjustments.Contrast = 12;
                _editorAdjustments.Highlights = -28;
                _editorAdjustments.Shadows = 14;
                _editorAdjustments.Whites = 12;
                _editorAdjustments.Blacks = -14;
                _editorAdjustments.Vibrance = 24;
                _editorAdjustments.Saturation = 5;
                _editorAdjustments.Texture = 16;
                _editorAdjustments.Clarity = 18;
                _editorAdjustments.Sharpening = 30;
                _editorAdjustments.Dehaze = 12;
                _editorAdjustments.Vignette = -10;
                break;
            case "monochrome":
                _editorAdjustments.Contrast = 22;
                _editorAdjustments.Highlights = -18;
                _editorAdjustments.Shadows = 12;
                _editorAdjustments.Whites = 10;
                _editorAdjustments.Blacks = -22;
                _editorAdjustments.Saturation = -100;
                _editorAdjustments.Texture = 12;
                _editorAdjustments.Clarity = 24;
                _editorAdjustments.Sharpening = 28;
                _editorAdjustments.Vignette = -14;
                break;
        }
        _editorAdjustments.ShowingOriginal = false;
        CompareEditorPhotoButton.Content =
            AppLocalization.T("查看原图");
    }

    private void SyncEditorSliders()
    {
        _updatingEditorControls = true;
        foreach (var entry in _editorSliders)
        {
            entry.Value.Value = EditorAdjustmentForKey(entry.Key);
        }
        foreach (var entry in _editorGradeSliders)
        {
            entry.Value.Value = EditorAdjustmentForKey(entry.Key);
        }
        foreach (var entry in _editorWheelControls)
        {
            entry.Value.XValue = EditorWheelXForKey(entry.Key);
            entry.Value.YValue = EditorWheelYForKey(entry.Key);
            entry.Value.InvalidateVisual();
        }
        _editorCurveControl?.InvalidateVisual();
        if (_editorMaskBox is not null)
            _editorMaskBox.SelectedIndex = _editorAdjustments.MaskType switch { "画笔" => 1, "线性渐变" => 2, "径向渐变" => 3, "智能主体" => 4, "智能天空" => 5, "智能背景" => 6, "智能人物" => 7, "智能亮部" => 8, "智能暗部" => 9, _ => 0 };
        if (_editorMaskAmountSlider is not null) _editorMaskAmountSlider.Value = _editorAdjustments.MaskAmount;
        if (_editorMaskFeatherSlider is not null) _editorMaskFeatherSlider.Value = _editorAdjustments.MaskFeather;
        if (_editorMaskBrushSizeSlider is not null) _editorMaskBrushSizeSlider.Value = _editorAdjustments.MaskBrushSize;
        if (_editorMaskInvertCheckBox is not null) _editorMaskInvertCheckBox.IsChecked = _editorAdjustments.MaskInvert;
        if (_editorPickedColorText is not null) _editorPickedColorText.Text = AppLocalization.T(_editorAdjustments.PickedColorHex);
        _updatingEditorControls = false;
    }

    private double EditorAdjustmentForKey(string key) => key switch
    {
        "exposure" => _editorAdjustments.Exposure,
        "contrast" => _editorAdjustments.Contrast,
        "highlights" => _editorAdjustments.Highlights,
        "shadows" => _editorAdjustments.Shadows,
        "whites" => _editorAdjustments.Whites,
        "blacks" => _editorAdjustments.Blacks,
        "temperature" => _editorAdjustments.Temperature,
        "tint" => _editorAdjustments.Tint,
        "vibrance" => _editorAdjustments.Vibrance,
        "saturation" => _editorAdjustments.Saturation,
        "texture" => _editorAdjustments.Texture,
        "clarity" => _editorAdjustments.Clarity,
        "sharpening" => _editorAdjustments.Sharpening,
        "noiseReduction" => _editorAdjustments.NoiseReduction,
        "dehaze" => _editorAdjustments.Dehaze,
        "vignette" => _editorAdjustments.Vignette,
        "lift" => _editorAdjustments.Lift,
        "gamma" => _editorAdjustments.Gamma,
        "gain" => _editorAdjustments.Gain,
        "curveShadows" => _editorAdjustments.CurveShadows,
        "curveMidtones" => _editorAdjustments.CurveMidtones,
        "curveHighlights" => _editorAdjustments.CurveHighlights,
        "maskAmount" => _editorAdjustments.MaskAmount,
        "maskFeather" => _editorAdjustments.MaskFeather,
        "maskBrushSize" => _editorAdjustments.MaskBrushSize,
        "maskExposure" => _editorAdjustments.MaskExposure,
        "maskContrast" => _editorAdjustments.MaskContrast,
        "maskHighlights" => _editorAdjustments.MaskHighlights,
        "maskShadows" => _editorAdjustments.MaskShadows,
        "maskTemperature" => _editorAdjustments.MaskTemperature,
        "maskTint" => _editorAdjustments.MaskTint,
        "maskSaturation" => _editorAdjustments.MaskSaturation,
        "maskClarity" => _editorAdjustments.MaskClarity,
        _ => 0
    };

    private void CompareEditorPhoto_Click(
        object sender,
        RoutedEventArgs e)
    {
        _editorAdjustments.ShowingOriginal =
            !_editorAdjustments.ShowingOriginal;
        CompareEditorPhotoButton.Content = AppLocalization.T(
            _editorAdjustments.ShowingOriginal
                ? "返回调整"
                : "查看原图");
        UpdateEditorPreview();
    }

    private void ResetEditor_Click(
        object sender,
        RoutedEventArgs e)
    {
        ResetEditorControls();
        UpdateEditorPreview();
    }

    private void ResetEditorControls()
    {
        _updatingEditorControls = true;
        _editorAdjustments.Reset();
        _selectedNikonCloudPreset = null;
        _editorCloudPresetBeforeAI = null;
        foreach (var slider in _editorSliders.Values)
        {
            slider.Value = 0;
        }
        foreach (var slider in _editorGradeSliders.Values)
        {
            slider.Value = slider.Tag?.ToString() == "grade:maskFeather" ? 50 : 0;
        }
        foreach (var wheel in _editorWheelControls)
        {
            wheel.Value.XValue = 0;
            wheel.Value.YValue = 0;
            wheel.Value.InvalidateVisual();
        }
        _editorCurveControl?.InvalidateVisual();
        if (_editorCropBox is not null)
        {
            _editorCropBox.SelectedIndex = 0;
        }
        if (_editorMaskBox is not null) _editorMaskBox.SelectedIndex = 0;
        if (_editorMaskAmountSlider is not null) _editorMaskAmountSlider.Value = 0;
        if (_editorMaskFeatherSlider is not null) _editorMaskFeatherSlider.Value = 50;
        if (_editorMaskBrushSizeSlider is not null) _editorMaskBrushSizeSlider.Value = 18;
        _editorPickerArmed = false;
        if (_editorPickedColorText is not null) _editorPickedColorText.Text = AppLocalization.T("未取样");
        EditorPresetBox.SelectedIndex = 0;
        NikonCloudPresetBox.SelectedIndex = 0;
        CompareEditorPhotoButton.Content =
            AppLocalization.T("查看原图");
        _editorSettingsBeforeAI = null;
        UndoEditorAIButton.IsEnabled = false;
        EditorAISummaryText.Text = AppLocalization.T("等待分析当前照片");
        _updatingEditorControls = false;
        EditorStatusText.Text = AppLocalization.T("调整不会覆盖原文件");
    }

    private void EditorAIIntensity_Changed(
        object sender,
        RoutedPropertyChangedEventArgs<double> e)
    {
        if (EditorAIIntensityText is not null)
        {
            EditorAIIntensityText.Text = $"{Math.Round(e.NewValue)}%";
        }
    }

    private void ApplyEditorAI_Click(
        object sender,
        RoutedEventArgs e)
    {
        if (string.IsNullOrWhiteSpace(_editorSelectedPath) ||
            !File.Exists(_editorSelectedPath))
        {
            return;
        }
        try
        {
            var analysis = _editorAIAnalysis ?? AnalyzeEditorPhoto(_editorSelectedPath);
            _editorSettingsBeforeAI = _editorAdjustments.Copy();
            _editorCloudPresetBeforeAI = _selectedNikonCloudPreset;
            _editorAIAnalysis = analysis;
            ApplyEditorAI(
                analysis,
                EditorAIIntensitySlider.Value / 100);
            _updatingEditorControls = true;
            EditorPresetBox.SelectedIndex = 0;
            _updatingEditorControls = false;
            SyncEditorSliders();
            UndoEditorAIButton.IsEnabled = true;
            EditorAISummaryText.Text = AppLocalization.T(analysis.Summary);
            UpdateEditorAIMetrics();
            CopyEditorAIButton.IsEnabled = true;
            EditorStatusText.Text = AppLocalization.T(
                "AI 优化已应用 · 可继续微调");
            UpdateEditorPreview();
        }
        catch (Exception error)
        {
            EditorStatusText.Text = AppLocalization.T(
                $"无法分析当前照片：{error.Message}");
        }
    }

    private void AnalyzeEditorAI_Click(object sender, RoutedEventArgs e)
    {
        if (string.IsNullOrWhiteSpace(_editorSelectedPath) ||
            !File.Exists(_editorSelectedPath))
        {
            return;
        }
        _editorAIAnalysis = AnalyzeEditorPhoto(_editorSelectedPath);
        if (_editorAIAnalysis is null)
        {
            EditorStatusText.Text = AppLocalization.T("无法分析当前照片");
            return;
        }
        EditorAISummaryText.Text = AppLocalization.T(_editorAIAnalysis.Summary);
        UpdateEditorAIMetrics();
        EditorStatusText.Text = AppLocalization.T("画面分析完成 · 可应用 AI 建议");
    }

    private void EditorWorkbenchTool_Click(object sender, RoutedEventArgs e)
    {
        if (sender is not Button button || button.Tag is not string tool)
        {
            return;
        }
        if (tool == "ai")
        {
            _editorInAiMode = true;
            UpdateEditorToolStrip("ai");
            RefreshAiEditor();
            return;
        }
        _editorInAiMode = false;
        EditorProGrid.Visibility = Visibility.Visible;
        EditorAiGrid.Visibility = Visibility.Collapsed;
        EditorHeaderTitle.Text = AppLocalization.T("专业显影");
        EditorHeaderSubtitle.Text = AppLocalization.T(
            "分组调整光线、色彩、细节、效果与几何；始终保留原文件。");
        UpdateEditorToolStrip("pro");
        UpdateEditorPreview();
    }

    private void UpdateEditorToolStrip(string tool)
    {
        // fig2 tool strip selection indicator (pure UI; no editor state machine).
        SetEditorToolActive(EditorModePro, tool != "ai");
        SetEditorToolActive(EditorModeAi, tool == "ai");
    }

    private void SetEditorToolActive(Button button, bool active)
    {
        button.Style = (Style)FindResource(
            active ? "EditorToolActive" : "EditorToolButton");
    }

    private void CopyEditorAI_Click(object sender, RoutedEventArgs e)
    {
        _editorAICopiedSettings = _editorAdjustments.Copy();
        PasteEditorAIButton.IsEnabled = true;
        BatchEditorAIButton.IsEnabled = true;
        EditorStatusText.Text = AppLocalization.T("已复制 AI 调整，可应用到下一张照片");
    }

    private void PasteEditorAI_Click(object sender, RoutedEventArgs e)
    {
        if (_editorAICopiedSettings is null)
        {
            return;
        }
        RestoreEditorAdjustments(_editorAICopiedSettings);
        ClearNikonCloudPresetSelection();
        _editorAdjustments.ShowingOriginal = false;
        UpdateEditorPreview();
        EditorStatusText.Text = AppLocalization.T("已粘贴 AI 调整");
    }

    /// E8 1.5.9: 批量应用 AI（本地渲染，0 服务器消耗）——后台任务逐张
    /// 渲染 + JPEG 副本，进度可见可取消，单张失败跳过计数不整批失败。
    private void BatchEditorAI_Click(object sender, RoutedEventArgs e)
    {
        if (_editorAICopiedSettings is null || _aiBatchApplying)
        {
            return;
        }
        var targets = _library.List()
            .Where(item => !item.IsVideo)
            .ToList();
        if (targets.Count == 0)
        {
            EditorStatusText.Text = AppLocalization.T("文件库没有可编辑照片");
            return;
        }
        _aiBatchApplying = true;
        _aiBatchCancelled = false;
        _aiBatchProgress = 0;
        _aiBatchTotal = targets.Count;
        _aiBatchSkipped = 0;
        BatchEditorAIButton.IsEnabled = false;
        BatchEditorAIProgress.Visibility = Visibility.Visible;
        BatchEditorAIStatus.Text = $"{0}/{targets.Count}";
        EditorStatusText.Text = AppLocalization.T(
            $"批量应用 AI 调整 · 本地处理零消耗 · 共 {targets.Count} 张");
        _ = Task.Run(async () =>
        {
            int skipped = 0;
            for (int index = 0; index < targets.Count; index++)
            {
                if (_aiBatchCancelled)
                {
                    await Dispatcher.InvokeAsync(() =>
                    {
                        FinishAIBatch(index, targets.Count);
                        EditorStatusText.Text = AppLocalization.T(
                            $"批量应用已取消 · 完成 {index}/{targets.Count}");
                    });
                    return;
                }
                var item = targets[index];
                bool ok = false;
                try
                {
                    var saved = _editorAICopiedSettings.Copy();
                    saved.ShowingOriginal = false;
                    var bitmap = RenderEditedBitmap(item.Path, saved, null);
                    var destination = UniqueEditedPath(item.Path);
                    var encoder = new JpegBitmapEncoder { QualityLevel = 95 };
                    encoder.Frames.Add(BitmapFrame.Create(bitmap));
                    using (var stream = File.Create(destination))
                    {
                        encoder.Save(stream);
                    }
                    ok = true;
                }
                catch
                {
                    ok = false;
                }
                if (!ok)
                {
                    skipped++;
                }
                int done = index + 1;
                int skippedSnapshot = skipped;
                await Dispatcher.InvokeAsync(() =>
                {
                    _aiBatchProgress = done;
                    _aiBatchSkipped = skippedSnapshot;
                    BatchEditorAIBar.Value =
                        100.0 * done / Math.Max(1, _aiBatchTotal);
                    BatchEditorAIStatus.Text = $"{done}/{_aiBatchTotal}";
                });
            }
            await Dispatcher.InvokeAsync(() =>
            {
                FinishAIBatch(targets.Count, targets.Count);
                EditorStatusText.Text = AppLocalization.T(
                    $"批量应用完成 · {targets.Count - skipped} 张已保存 · 跳过 {skipped}");
            });
        });
    }

    private void FinishAIBatch(int done, int total)
    {
        _aiBatchApplying = false;
        BatchEditorAIButton.IsEnabled =
            _editorAICopiedSettings != null;
        BatchEditorAIProgress.Visibility = Visibility.Collapsed;
        RefreshPhotoList();
        _ = done;
        _ = total;
    }

    private void BatchEditorAICancel_Click(object sender, RoutedEventArgs e)
    {
        _aiBatchCancelled = true;
    }

    private void UpdateEditorAIMetrics()
    {
        if (_editorAIAnalysis is null)
        {
            EditorAIMetricsText.Text = AppLocalization.T("等待分析");
            EditorScopeText.Text = AppLocalization.T("分析后显示实测范围");
            return;
        }
        var analysis = _editorAIAnalysis;
        EditorAIMetricsText.Text = AppLocalization.T(
            $"曝光 {analysis.MeanLuma:P0}  动态范围 {analysis.Contrast:P0}  " +
            $"色彩 {analysis.Saturation:P0}  细节 {analysis.Detail:P0}");
        EditorScopeText.Text = AppLocalization.T(
            $"LUMA {analysis.MeanLuma:P0}  RANGE {analysis.Contrast:P0}\n" +
            $"COLOR {analysis.Saturation:P0}  DETAIL {analysis.Detail:P0}");
    }

    private void UndoEditorAI_Click(
        object sender,
        RoutedEventArgs e)
    {
        if (_editorSettingsBeforeAI is null)
        {
            return;
        }
        RestoreEditorAdjustments(_editorSettingsBeforeAI);
        _selectedNikonCloudPreset = _editorCloudPresetBeforeAI;
        _updatingEditorControls = true;
        NikonCloudPresetBox.SelectedIndex = _selectedNikonCloudPreset is null
            ? 0
            : _nikonCloudCatalog.Presets.FindIndex(
                item => item.Id == _selectedNikonCloudPreset.Id) + 1;
        _updatingEditorControls = false;
        _editorCloudPresetBeforeAI = null;
        _editorSettingsBeforeAI = null;
        SyncEditorSliders();
        UndoEditorAIButton.IsEnabled = false;
        EditorAISummaryText.Text = AppLocalization.T("已撤销 AI 优化");
        EditorStatusText.Text = AppLocalization.T(
            "已恢复 AI 优化前的参数");
        UpdateEditorPreview();
    }

    private void RestoreEditorAdjustments(EditorAdjustments source)
    {
        _editorAdjustments.Exposure = source.Exposure;
        _editorAdjustments.Contrast = source.Contrast;
        _editorAdjustments.Highlights = source.Highlights;
        _editorAdjustments.Shadows = source.Shadows;
        _editorAdjustments.Whites = source.Whites;
        _editorAdjustments.Blacks = source.Blacks;
        _editorAdjustments.Temperature = source.Temperature;
        _editorAdjustments.Tint = source.Tint;
        _editorAdjustments.Vibrance = source.Vibrance;
        _editorAdjustments.Saturation = source.Saturation;
        _editorAdjustments.Texture = source.Texture;
        _editorAdjustments.Clarity = source.Clarity;
        _editorAdjustments.Sharpening = source.Sharpening;
        _editorAdjustments.NoiseReduction = source.NoiseReduction;
        _editorAdjustments.Dehaze = source.Dehaze;
        _editorAdjustments.Vignette = source.Vignette;
        _editorAdjustments.Lift = source.Lift;
        _editorAdjustments.Gamma = source.Gamma;
        _editorAdjustments.Gain = source.Gain;
        _editorAdjustments.LiftX = source.LiftX;
        _editorAdjustments.LiftY = source.LiftY;
        _editorAdjustments.GammaX = source.GammaX;
        _editorAdjustments.GammaY = source.GammaY;
        _editorAdjustments.GainX = source.GainX;
        _editorAdjustments.GainY = source.GainY;
        _editorAdjustments.CurveShadows = source.CurveShadows;
        _editorAdjustments.CurveMidtones = source.CurveMidtones;
        _editorAdjustments.CurveHighlights = source.CurveHighlights;
        _editorAdjustments.CurvePoints = source.CurvePoints.Select(point => point.Copy()).ToList();
        _editorAdjustments.Rotation = source.Rotation;
        _editorAdjustments.FlipHorizontal = source.FlipHorizontal;
        _editorAdjustments.FlipVertical = source.FlipVertical;
        _editorAdjustments.ShowingOriginal = source.ShowingOriginal;
        _editorAdjustments.CropRatio = source.CropRatio;
    }

    private void ApplyEditorAI(
        EditorAIAnalysis analysis,
        double intensity)
    {
        ClearNikonCloudPresetSelection();
        _editorAdjustments.ResetTone();
        var amount = Math.Clamp(intensity, 0.35, 1);
        var targetExposure = Math.Clamp(
            Math.Log2(0.48 / Math.Max(0.08, analysis.MeanLuma)) * 0.68,
            -0.8,
            0.8);
        _editorAdjustments.Exposure = targetExposure * amount;
        _editorAdjustments.Contrast = AIValue(
            Math.Clamp((0.20 - analysis.Contrast) * 130, -8, 24),
            amount);
        _editorAdjustments.Highlights = -AIValue(
            Math.Clamp(
                analysis.HighlightRatio * 360 +
                    Math.Max(0, analysis.MeanLuma - 0.55) * 70,
                6,
                48),
            amount);
        _editorAdjustments.Shadows = AIValue(
            Math.Clamp(
                analysis.ShadowRatio * 330 +
                    Math.Max(0, 0.44 - analysis.MeanLuma) * 75,
                6,
                46),
            amount);
        _editorAdjustments.Whites = AIValue(
            Math.Clamp((0.58 - analysis.MeanLuma) * 28, -8, 14),
            amount);
        _editorAdjustments.Blacks = -AIValue(
            Math.Clamp((0.21 - analysis.Contrast) * 55 + 5, 4, 18),
            amount);
        _editorAdjustments.Temperature = AIValue(
            Math.Clamp((analysis.Blue - analysis.Red) * 95, -18, 18),
            amount);
        var greenExcess = analysis.Green -
            (analysis.Red + analysis.Blue) / 2;
        _editorAdjustments.Tint = AIValue(
            Math.Clamp(greenExcess * 85, -14, 14),
            amount);
        _editorAdjustments.Vibrance = AIValue(
            Math.Clamp((0.30 - analysis.Saturation) * 95 + 6, 4, 26),
            amount);
        _editorAdjustments.Saturation = AIValue(
            Math.Clamp((0.22 - analysis.Saturation) * 28, -4, 8),
            amount);
        _editorAdjustments.Texture = AIValue(
            Math.Clamp((0.075 - analysis.Detail) * 170 + 7, 4, 16),
            amount);
        _editorAdjustments.Clarity = AIValue(
            Math.Clamp((0.19 - analysis.Contrast) * 70 + 6, 3, 18),
            amount);
        _editorAdjustments.Sharpening = AIValue(
            Math.Clamp((0.08 - analysis.Detail) * 210 + 20, 14, 34),
            amount);
        _editorAdjustments.NoiseReduction = AIValue(
            Math.Clamp(
                analysis.ShadowRatio * 120 +
                    Math.Max(0, 0.38 - analysis.MeanLuma) * 42 + 6,
                6,
                30),
            amount);
        _editorAdjustments.Dehaze = AIValue(
            Math.Clamp((0.18 - analysis.Contrast) * 75, 0, 16),
            amount);
        _editorAdjustments.ShowingOriginal = false;
        CompareEditorPhotoButton.Content = AppLocalization.T("查看原图");
    }

    private static double AIValue(double value, double amount) =>
        Math.Round(value * amount);

    private static EditorAIAnalysis AnalyzeEditorPhoto(string path)
    {
        using var stream = new MemoryStream(File.ReadAllBytes(path));
        var decoder = BitmapDecoder.Create(
            stream,
            BitmapCreateOptions.PreservePixelFormat,
            BitmapCacheOption.OnLoad);
        var source = decoder.Frames[0];
        var scale = Math.Min(1, 128.0 /
            Math.Max(source.PixelWidth, source.PixelHeight));
        var bitmap = new TransformedBitmap(
            source,
            new ScaleTransform(scale, scale));
        var converted = new FormatConvertedBitmap(
            bitmap,
            PixelFormats.Bgra32,
            null,
            0);
        var width = converted.PixelWidth;
        var height = converted.PixelHeight;
        var stride = width * 4;
        var pixels = new byte[stride * height];
        converted.CopyPixels(pixels, stride, 0);
        var count = width * height;
        var lumas = new double[count];
        double red = 0;
        double green = 0;
        double blue = 0;
        double saturation = 0;
        double mean = 0;
        var shadows = 0;
        var highlights = 0;
        for (var index = 0; index < count; index++)
        {
            var offset = index * 4;
            var b = pixels[offset] / 255.0;
            var g = pixels[offset + 1] / 255.0;
            var r = pixels[offset + 2] / 255.0;
            var luma = r * 0.2126 + g * 0.7152 + b * 0.0722;
            lumas[index] = luma;
            mean += luma;
            red += r;
            green += g;
            blue += b;
            saturation += Math.Max(r, Math.Max(g, b)) -
                Math.Min(r, Math.Min(g, b));
            if (luma < 0.10) shadows++;
            if (luma > 0.90) highlights++;
        }
        mean /= count;
        double variance = 0;
        double detail = 0;
        for (var y = 0; y < height; y++)
        {
            for (var x = 0; x < width; x++)
            {
                var index = y * width + x;
                variance += Math.Pow(lumas[index] - mean, 2);
                if (x > 0)
                {
                    detail += Math.Abs(lumas[index] - lumas[index - 1]);
                }
            }
        }
        return new EditorAIAnalysis(
            mean,
            Math.Sqrt(variance / count),
            shadows / (double)count,
            highlights / (double)count,
            saturation / count,
            red / count,
            green / count,
            blue / count,
            detail / Math.Max(1, height * (width - 1)));
    }

    private void UpdateEditorPreview()
    {
        // Slider and direct-manipulation events may arrive faster than the UI
        // can filter a preview. Coalesce them to one render per display frame.
        _editorPreviewPending = true;
        if (!_editorPreviewTimer.IsEnabled)
        {
            _editorPreviewTimer.Start();
        }
    }

    private void RenderEditorPreviewNow()
    {
        if (_currentDestination != "editor" || _editorInAiMode)
        {
            return;
        }
        if (string.IsNullOrWhiteSpace(_editorSelectedPath) ||
            !File.Exists(_editorSelectedPath))
        {
            EditorPreviewImage.Source = null;
            EditorPreviewEmpty.Visibility = Visibility.Visible;
            SaveEditedPhotoButton.IsEnabled = false;
            DownloadEditedPhotoButton.IsEnabled = false;
            EditorScopeWaveform.SetData("—", "—", "—");
            return;
        }
        try
        {
            var previewBitmap = RenderEditedBitmap(
                _editorSelectedPath,
                _editorAdjustments,
                _selectedNikonCloudPreset,
                1600);
            EditorPreviewImage.Source = previewBitmap;
            EditorPreviewEmpty.Visibility = Visibility.Collapsed;
            SaveEditedPhotoButton.IsEnabled = true;
            DownloadEditedPhotoButton.IsEnabled = true;
            RedrawEditorMaskOverlay();
            UpdateEditorScopeWaveform(previewBitmap);
        }
        catch (Exception error)
        {
            EditorPreviewImage.Source = null;
            EditorPreviewEmpty.Visibility = Visibility.Visible;
            SaveEditedPhotoButton.IsEnabled = false;
            DownloadEditedPhotoButton.IsEnabled = false;
            EditorStatusText.Text =
                AppLocalization.T($"无法预览：{error.Message}");
        }
    }

    private void UpdateEditorScopeWaveform(BitmapSource previewBitmap)
    {
        // 编辑页波形复用本帧预览，不再二次解码和滤镜渲染。
        try
        {
            BitmapSource scopeBitmap = previewBitmap;
            if (previewBitmap.PixelWidth > 320)
            {
                var scale = 320d / previewBitmap.PixelWidth;
                scopeBitmap = new TransformedBitmap(
                    previewBitmap,
                    new ScaleTransform(scale, scale));
                scopeBitmap.Freeze();
            }
            var monitor = ProfessionalMonitor.Process(
                scopeBitmap,
                false,
                false);
            EditorScopeWaveform.SetData(
                monitor.RedHistogram,
                monitor.GreenHistogram,
                monitor.BlueHistogram);
        }
        catch
        {
            EditorScopeWaveform.SetData("—", "—", "—");
        }
    }

    private void EditorPreviewImage_MouseLeftButtonDown(object sender, MouseButtonEventArgs e)
    {
        if (!_editorPickerArmed || string.IsNullOrWhiteSpace(_editorSelectedPath)) return;
        var point = e.GetPosition(EditorPreviewImage);
        var bitmap = EditorPreviewImage.Source as BitmapSource;
        if (bitmap is null || EditorPreviewImage.ActualWidth <= 0 || EditorPreviewImage.ActualHeight <= 0) return;
        var x = (int)Math.Clamp(point.X / EditorPreviewImage.ActualWidth * bitmap.PixelWidth, 0, bitmap.PixelWidth - 1);
        var y = (int)Math.Clamp(point.Y / EditorPreviewImage.ActualHeight * bitmap.PixelHeight, 0, bitmap.PixelHeight - 1);
        ApplyEditorPickerSample(bitmap, x, y);
        e.Handled = true;
    }

    private void EditorMaskCanvas_MouseLeftButtonDown(
        object sender,
        MouseButtonEventArgs e)
    {
        if (EditorPreviewImage.Source is not BitmapSource bitmap) return;
        var point = e.GetPosition(EditorMaskCanvas);
        var rect = GetUniformImageRect(EditorMaskCanvas, bitmap);
        if (!rect.Contains(point)) return;
        if (_editorPickerArmed)
        {
            var sampleX = (int)Math.Clamp(
                (point.X - rect.Left) / rect.Width * bitmap.PixelWidth,
                0,
                bitmap.PixelWidth - 1);
            var sampleY = (int)Math.Clamp(
                (point.Y - rect.Top) / rect.Height * bitmap.PixelHeight,
                0,
                bitmap.PixelHeight - 1);
            ApplyEditorPickerSample(bitmap, sampleX, sampleY);
            e.Handled = true;
            return;
        }
        if (_editorAdjustments.MaskType == "无" ||
            !_editorAdjustments.ActiveMaskLayerIsVisible()) return;
        _activeEditorMaskStroke = new EditorMaskStroke
        {
            Subtract = _editorAdjustments.MaskSubtract,
            Size = _editorAdjustments.MaskBrushSize
        };
        _activeEditorMaskStroke.Points.Add(EditorMaskPointFromPreview(point, rect));
        _editorAdjustments.MaskStrokes.Add(_activeEditorMaskStroke);
        EditorMaskCanvas.CaptureMouse();
        RedrawEditorMaskOverlay();
        e.Handled = true;
    }

    private void EditorMaskCanvas_MouseMove(
        object sender,
        MouseEventArgs e)
    {
        if (_activeEditorMaskStroke is null ||
            e.LeftButton != MouseButtonState.Pressed ||
            EditorPreviewImage.Source is not BitmapSource bitmap)
        {
            return;
        }
        var rect = GetUniformImageRect(EditorMaskCanvas, bitmap);
        var point = e.GetPosition(EditorMaskCanvas);
        point.X = Math.Clamp(point.X, rect.Left, rect.Right);
        point.Y = Math.Clamp(point.Y, rect.Top, rect.Bottom);
        _activeEditorMaskStroke.Points.Add(EditorMaskPointFromPreview(point, rect));
        RedrawEditorMaskOverlay();
        e.Handled = true;
    }

    private void EditorMaskCanvas_MouseLeftButtonUp(
        object sender,
        MouseButtonEventArgs e)
    {
        if (_activeEditorMaskStroke is null) return;
        _activeEditorMaskStroke = null;
        EditorMaskCanvas.ReleaseMouseCapture();
        EditorStatusText.Text = AppLocalization.T(
            _editorAdjustments.MaskSubtract
                ? "已减去蒙版区域"
                : "已添加蒙版区域");
        UpdateEditorPreview();
        e.Handled = true;
    }

    private static EditorMaskPoint EditorMaskPointFromPreview(
        Point point,
        Rect rect) => new(
            Math.Clamp((point.X - rect.Left) / Math.Max(1, rect.Width), 0, 1),
            Math.Clamp((point.Y - rect.Top) / Math.Max(1, rect.Height), 0, 1));

    private void RedrawEditorMaskOverlay()
    {
        EditorMaskCanvas.Children.Clear();
        if (_editorAdjustments.MaskType == "无" ||
            !_editorAdjustments.ActiveMaskLayerIsVisible() ||
            EditorPreviewImage.Source is not BitmapSource bitmap)
        {
            return;
        }
        var active = _editorAdjustments.ActiveMaskLayer();
        if (active is null) return;
        var layer = _editorAdjustments.DisplayedMaskLayer(active);
        var rect = GetUniformImageRect(EditorMaskCanvas, bitmap);
        var converted = new FormatConvertedBitmap(
            bitmap,
            PixelFormats.Bgra32,
            null,
            0);
        var width = converted.PixelWidth;
        var height = converted.PixelHeight;
        var stride = width * 4;
        var source = new byte[stride * height];
        converted.CopyPixels(source, stride, 0);
        var mask = BuildEditorMask(width, height, layer, source);
        var overlay = new byte[source.Length];
        var intensity = Math.Clamp(layer.Amount / 100, 0, 1);
        for (var index = 0; index < mask.Length; index++)
        {
            var coverage = mask[index] / 255.0;
            var effective = (layer.Invert ? 1 - coverage : coverage)
                * intensity;
            var alpha = (byte)Math.Round(150 * effective);
            var offset = index * 4;
            overlay[offset] = (byte)(230 * alpha / 255);
            overlay[offset + 1] = (byte)(115 * alpha / 255);
            overlay[offset + 2] = (byte)(22 * alpha / 255);
            overlay[offset + 3] = alpha;
        }
        var overlayBitmap = BitmapSource.Create(
            width,
            height,
            converted.DpiX,
            converted.DpiY,
            PixelFormats.Pbgra32,
            null,
            overlay,
            stride);
        overlayBitmap.Freeze();
        var overlayImage = new System.Windows.Controls.Image
        {
            Source = overlayBitmap,
            Width = rect.Width,
            Height = rect.Height,
            Stretch = Stretch.Fill,
            IsHitTestVisible = false
        };
        Canvas.SetLeft(overlayImage, rect.Left);
        Canvas.SetTop(overlayImage, rect.Top);
        EditorMaskCanvas.Children.Add(overlayImage);
    }

    private void SampleEditorPixelAtCenter()
    {
        if (EditorPreviewImage.Source is not BitmapSource bitmap) return;
        ApplyEditorPickerSample(bitmap, bitmap.PixelWidth / 2, bitmap.PixelHeight / 2);
    }

    private void ApplyEditorPickerSample(BitmapSource bitmap, int x, int y)
    {
        var sampled = new byte[4];
        bitmap.CopyPixels(new Int32Rect(Math.Clamp(x, 0, bitmap.PixelWidth - 1), Math.Clamp(y, 0, bitmap.PixelHeight - 1), 1, 1), sampled, 4, 0);
        var hex = $"#{sampled[2]:X2}{sampled[1]:X2}{sampled[0]:X2}";
        _editorAdjustments.PickedColorHex = hex;
        _editorAdjustments.PickerEnabled = false;
        _editorPickerArmed = false;
        _editorAdjustments.Temperature = Math.Clamp((sampled[0] - sampled[2]) / 2.55, -100, 100);
        _editorAdjustments.Tint = Math.Clamp((sampled[1] - (sampled[0] + sampled[2]) / 2) / 2.55, -100, 100);
        if (_editorPickedColorText is not null) _editorPickedColorText.Text = hex;
        EditorStatusText.Text = AppLocalization.T($"已取样 {hex} · 已微调色温/色调");
        SyncEditorSliders();
        UpdateEditorPreview();
    }

    private void SaveEditedPhoto_Click(
        object sender,
        RoutedEventArgs e)
    {
        if (_localDownloadPreparationBusy || _localDownloadBusy)
        {
            return;
        }
        SaveEditedPhotoCopy();
    }

    private async void DownloadEditedPhoto_Click(
        object sender,
        RoutedEventArgs e)
    {
        if (_localDownloadBusy || _localDownloadPreparationBusy)
        {
            return;
        }
        var sourcePath = _editorSelectedPath;
        if (string.IsNullOrWhiteSpace(sourcePath) || !File.Exists(sourcePath))
        {
            return;
        }
        var adjustments = _editorAdjustments.Copy();
        adjustments.ShowingOriginal = false;
        var nikonCloudPreset = _selectedNikonCloudPreset;
        var destination = UniqueEditedPath(sourcePath);

        _localDownloadPreparationBusy = true;
        SaveEditedPhotoButton.IsEnabled = false;
        DownloadEditedPhotoButton.IsEnabled = false;
        try
        {
            EditorStatusText.Text = AppLocalization.T("正在保存…");
            await Task.Run(() => SaveEditedPhotoCopyCore(
                sourcePath,
                destination,
                adjustments,
                nikonCloudPreset));
            _editorSelectedPath = destination;
            RefreshPhotoList();
            RefreshImageEditor();
            EditorStatusText.Text = AppLocalization.T(
                $"已保存副本 {Path.GetFileName(destination)}");
            await DownloadFileToLocalAsync(
                destination,
                Path.GetFileName(destination),
                message => EditorStatusText.Text = message,
                preparationOwner: true);
        }
        catch (Exception error)
        {
            EditorStatusText.Text =
                AppLocalization.T($"保存失败：{error.Message}");
            ShowError(error.Message);
        }
        finally
        {
            _localDownloadPreparationBusy = false;
            var canSave =
                !string.IsNullOrWhiteSpace(_editorSelectedPath) &&
                File.Exists(_editorSelectedPath);
            SaveEditedPhotoButton.IsEnabled = canSave;
            DownloadEditedPhotoButton.IsEnabled = canSave;
        }
    }

    private string? SaveEditedPhotoCopy()
    {
        if (_localDownloadPreparationBusy || _localDownloadBusy)
        {
            return null;
        }
        if (string.IsNullOrWhiteSpace(_editorSelectedPath) ||
            !File.Exists(_editorSelectedPath))
        {
            return null;
        }
        try
        {
            SaveEditedPhotoButton.IsEnabled = false;
            DownloadEditedPhotoButton.IsEnabled = false;
            EditorStatusText.Text = AppLocalization.T("正在保存…");
            var savedAdjustments = _editorAdjustments.Copy();
            savedAdjustments.ShowingOriginal = false;
            var destination = UniqueEditedPath(_editorSelectedPath);
            SaveEditedPhotoCopyCore(
                _editorSelectedPath,
                destination,
                savedAdjustments,
                _selectedNikonCloudPreset);
            _editorSelectedPath = destination;
            RefreshPhotoList();
            RefreshImageEditor();
            EditorStatusText.Text = AppLocalization.T(
                $"已保存副本 {Path.GetFileName(destination)}");
            return destination;
        }
        catch (Exception error)
        {
            EditorStatusText.Text =
                AppLocalization.T($"保存失败：{error.Message}");
            ShowError(error.Message);
            return null;
        }
        finally
        {
            var canSave = !string.IsNullOrWhiteSpace(_editorSelectedPath) &&
                File.Exists(_editorSelectedPath);
            SaveEditedPhotoButton.IsEnabled = canSave;
            DownloadEditedPhotoButton.IsEnabled = canSave;
        }
    }

    private static void SaveEditedPhotoCopyCore(
        string sourcePath,
        string destination,
        EditorAdjustments adjustments,
        NikonCloudPreset? nikonCloudPreset)
    {
        var bitmap = RenderEditedBitmap(
            sourcePath,
            adjustments,
            nikonCloudPreset);
        SaveBitmapAtomically(destination, bitmap);
    }

    private static bool IsEditableImage(string path)
    {
        return new[] { ".jpg", ".jpeg", ".png", ".bmp", ".tif", ".tiff" }
            .Contains(
                Path.GetExtension(path),
                StringComparer.OrdinalIgnoreCase);
    }

    private static BitmapSource RenderEditedBitmap(
        string path,
        EditorAdjustments settings,
        NikonCloudPreset? nikonCloudPreset,
        int decodePixelWidth = 0)
    {
        using var stream = new MemoryStream(File.ReadAllBytes(path));
        var decoder = BitmapDecoder.Create(
            stream,
            BitmapCreateOptions.PreservePixelFormat,
            BitmapCacheOption.OnLoad);
        BitmapSource source = decoder.Frames[0];
        if (decodePixelWidth > 0 && source.PixelWidth > decodePixelWidth)
        {
            var scale = (double)decodePixelWidth / source.PixelWidth;
            source = new TransformedBitmap(
                source,
                new ScaleTransform(scale, scale));
        }
        if (settings.ShowingOriginal)
        {
            source.Freeze();
            return source;
        }
        var converted = new FormatConvertedBitmap(
            source,
            PixelFormats.Bgra32,
            null,
            0);
        var stride = converted.PixelWidth * 4;
        var pixels = new byte[stride * converted.PixelHeight];
        converted.CopyPixels(pixels, stride, 0);
        var exposure = Math.Pow(2, settings.Exposure);
        var contrast =
            1 + settings.Contrast / 125 + settings.Dehaze / 210;
        var baseSaturation =
            1 + settings.Saturation / 100 + settings.Dehaze / 520;
        var temperature = settings.Temperature / 100;
        var tint = settings.Tint / 100;
        for (var index = 0; index < pixels.Length; index += 4)
        {
            var blue = pixels[index] / 255.0 * exposure;
            var green = pixels[index + 1] / 255.0 * exposure;
            var red = pixels[index + 2] / 255.0 * exposure;

            red += temperature * 0.12 + tint * 0.045;
            green -= tint * 0.08;
            blue -= temperature * 0.12 - tint * 0.045;

            var luminance =
                red * 0.2126 + green * 0.7152 + blue * 0.0722;
            var toneShift =
                settings.Shadows / 100
                    * Math.Pow(1 - ClampUnit(luminance), 2)
                    * 0.38
                + settings.Highlights / 100
                    * Math.Pow(ClampUnit(luminance), 2)
                    * 0.30
                + settings.Whites / 100
                    * SmoothStep(0.55, 1, luminance)
                    * 0.24
                + settings.Blacks / 100
                    * (1 - SmoothStep(0, 0.45, luminance))
                    * 0.20;
            red += toneShift;
            green += toneShift;
            blue += toneShift;

            var clarityMask =
                1 - Math.Abs(ClampUnit(luminance) * 2 - 1);
            var localContrast =
                1 + settings.Clarity / 100 * clarityMask * 0.38;
            red = (red - 0.5) * contrast * localContrast + 0.5;
            green = (green - 0.5) * contrast * localContrast + 0.5;
            blue = (blue - 0.5) * contrast * localContrast + 0.5;

            luminance =
                red * 0.2126 + green * 0.7152 + blue * 0.0722;
            var colorfulness =
                Math.Max(red, Math.Max(green, blue))
                - Math.Min(red, Math.Min(green, blue));
            var saturation = Math.Max(
                0,
                baseSaturation
                + settings.Vibrance / 100
                    * (1 - ClampUnit(colorfulness))
                    * 0.82);
            red = luminance + (red - luminance) * saturation;
            green = luminance + (green - luminance) * saturation;
            blue = luminance + (blue - luminance) * saturation;
            nikonCloudPreset?.ApplyColorMixer(ref red, ref green, ref blue);

            var pixelIndex = index / 4;
            var x = pixelIndex % converted.PixelWidth;
            var y = pixelIndex / converted.PixelWidth;
            var normalizedX =
                (x - converted.PixelWidth / 2.0) /
                Math.Max(1, converted.PixelWidth / 2.0);
            var normalizedY =
                (y - converted.PixelHeight / 2.0) /
                Math.Max(1, converted.PixelHeight / 2.0);
            var edge = Math.Min(
                1,
                Math.Sqrt(
                    normalizedX * normalizedX +
                    normalizedY * normalizedY));
            var vignette =
                1 + settings.Vignette / 100 * edge * edge * 0.72;
            // Apply independent X/Y wheel axes and the editable curve.
            var shadowWeight = Math.Pow(1 - ClampUnit(luminance), 2);
            var midWeight = 1 - Math.Abs(ClampUnit(luminance) * 2 - 1);
            var highlightWeight = Math.Pow(ClampUnit(luminance), 2);
            var wheelX = settings.LiftX / 100 * shadowWeight * 0.12
                + settings.GammaX / 100 * midWeight * 0.12
                + settings.GainX / 100 * highlightWeight * 0.12;
            var wheelY = settings.LiftY / 100 * shadowWeight * 0.12
                + settings.GammaY / 100 * midWeight * 0.12
                + settings.GainY / 100 * highlightWeight * 0.12;
            red += wheelX - wheelY * .5;
            green += wheelY - wheelX * .5;
            blue -= (wheelX + wheelY) * .5;
            if (settings.CurvePoints.Count > 2)
            {
                var mapped = CurveValue(settings.CurvePoints, luminance);
                var delta = mapped - luminance;
                red += delta;
                green += delta;
                blue += delta;
            }
            pixels[index] = ClampChannel(blue * vignette * 255);
            pixels[index + 1] = ClampChannel(green * vignette * 255);
            pixels[index + 2] = ClampChannel(red * vignette * 255);
        }
        ApplyEditorDetail(
            pixels,
            converted.PixelWidth,
            converted.PixelHeight,
            stride,
            settings);
        BitmapSource result = BitmapSource.Create(
            converted.PixelWidth,
            converted.PixelHeight,
            converted.DpiX,
            converted.DpiY,
            PixelFormats.Bgra32,
            null,
            pixels,
            stride);
        if (settings.FlipHorizontal)
        {
            result = new TransformedBitmap(
                result,
                new ScaleTransform(-1, 1));
        }
        if (settings.FlipVertical)
        {
            result = new TransformedBitmap(
                result,
                new ScaleTransform(1, -1));
        }
        if (settings.Rotation % 360 != 0)
        {
            result = new TransformedBitmap(
                result,
                new RotateTransform(settings.Rotation));
        }
        var cropRatio = EditorCropRatio(settings.CropRatio);
        if (cropRatio > 0)
        {
            var cropWidth = result.PixelWidth;
            var cropHeight = (int)Math.Round(cropWidth / cropRatio);
            if (cropHeight > result.PixelHeight)
            {
                cropHeight = result.PixelHeight;
                cropWidth = (int)Math.Round(cropHeight * cropRatio);
            }
            result = new CroppedBitmap(
                result,
                new Int32Rect(
                    Math.Max(0, (result.PixelWidth - cropWidth) / 2),
                    Math.Max(0, (result.PixelHeight - cropHeight) / 2),
                    Math.Max(1, cropWidth),
                    Math.Max(1, cropHeight)));
        }
        foreach (var layer in settings.EffectiveMaskLayers())
        {
            if (layer.IsVisible && layer.Type != "无")
                result = ApplyEditorMaskAdjustments(result, layer);
        }
        result.Freeze();
        return result;
    }

    private static BitmapSource ApplyEditorMaskAdjustments(
        BitmapSource source,
        EditorMaskLayer layer)
    {
        var converted = new FormatConvertedBitmap(
            source,
            PixelFormats.Bgra32,
            null,
            0);
        var width = converted.PixelWidth;
        var height = converted.PixelHeight;
        var stride = width * 4;
        var original = new byte[stride * height];
        converted.CopyPixels(original, stride, 0);
        var local = (byte[])original.Clone();
        var exposure = Math.Pow(2, layer.Exposure);
        var contrast = 1 + layer.Contrast / 100;
        var saturation = Math.Max(0, 1 + layer.Saturation / 100);
        var temperature = layer.Temperature / 100;
        var tint = layer.Tint / 100;
        for (var offset = 0; offset < local.Length; offset += 4)
        {
            var blue = original[offset] / 255.0 * exposure;
            var green = original[offset + 1] / 255.0 * exposure;
            var red = original[offset + 2] / 255.0 * exposure;
            red += temperature * .12 + tint * .045;
            green -= tint * .08;
            blue -= temperature * .12 - tint * .045;
            var luma = red * .2126 + green * .7152 + blue * .0722;
            var tone = layer.Shadows / 100
                * Math.Pow(1 - ClampUnit(luma), 2) * .38
                + layer.Highlights / 100
                * Math.Pow(ClampUnit(luma), 2) * .30;
            red += tone;
            green += tone;
            blue += tone;
            var clarityWeight = 1 - Math.Abs(ClampUnit(luma) * 2 - 1);
            var localContrast = contrast
                * (1 + layer.Clarity / 100 * clarityWeight * .38);
            red = (red - .5) * localContrast + .5;
            green = (green - .5) * localContrast + .5;
            blue = (blue - .5) * localContrast + .5;
            luma = red * .2126 + green * .7152 + blue * .0722;
            red = luma + (red - luma) * saturation;
            green = luma + (green - luma) * saturation;
            blue = luma + (blue - luma) * saturation;
            local[offset] = ClampChannel(blue * 255);
            local[offset + 1] = ClampChannel(green * 255);
            local[offset + 2] = ClampChannel(red * 255);
        }
        var mask = BuildEditorMask(width, height, layer, original);
        var intensity = Math.Clamp(layer.Amount / 100, 0, 1);
        for (var offset = 0; offset < local.Length; offset += 4)
        {
            var coverage = mask[offset / 4] / 255.0;
            var amount = (layer.Invert ? 1 - coverage : coverage)
                * intensity;
            for (var channel = 0; channel < 3; channel++)
            {
                local[offset + channel] = ClampChannel(
                    original[offset + channel]
                    + (local[offset + channel] - original[offset + channel])
                    * amount);
            }
        }
        return BitmapSource.Create(
            width,
            height,
            converted.DpiX,
            converted.DpiY,
            PixelFormats.Bgra32,
            null,
            local,
            stride);
    }

    private static byte[] BuildEditorMask(
        int width,
        int height,
        EditorMaskLayer layer,
        byte[] sourcePixels)
    {
        var mask = new byte[Math.Max(1, width * height)];
        if (layer.Type != "画笔")
        {
            for (var index = 0; index < mask.Length; index++)
            {
                var offset = index * 4;
                var coverage = SmartEditorMaskCoverage(
                    layer.Type,
                    sourcePixels[offset + 2] / 255.0,
                    sourcePixels[offset + 1] / 255.0,
                    sourcePixels[offset] / 255.0,
                    index % width,
                    index / width,
                    width,
                    height);
                mask[index] = (byte)Math.Clamp(
                    (int)Math.Round(coverage * 255),
                    0,
                    255);
            }
        }
        foreach (var stroke in layer.Strokes)
        {
            if (stroke.Points.Count == 0) continue;
            var previous = stroke.Points[0];
            StampEditorMask(mask, width, height, previous, stroke, layer.Feather);
            foreach (var current in stroke.Points.Skip(1))
            {
                var deltaX = (current.X - previous.X) * width;
                var deltaY = (current.Y - previous.Y) * height;
                var radius = Math.Max(
                    1,
                    stroke.Size / 200 * Math.Min(width, height));
                var steps = Math.Max(
                    1,
                    (int)Math.Ceiling(
                        Math.Sqrt(deltaX * deltaX + deltaY * deltaY)
                        / Math.Max(1, radius * .45)));
                for (var step = 1; step <= steps; step++)
                {
                    var progress = step / (double)steps;
                    StampEditorMask(
                        mask,
                        width,
                        height,
                        new EditorMaskPoint(
                            previous.X + (current.X - previous.X) * progress,
                            previous.Y + (current.Y - previous.Y) * progress),
                        stroke,
                        layer.Feather);
                }
                previous = current;
            }
        }
        var blurRadius = Math.Min(
            24,
            Math.Max(
                0,
                (int)Math.Round(
                    layer.Feather / 100
                    * Math.Min(width, height) * .015)));
        if (blurRadius > 0) BlurEditorMask(mask, width, height, blurRadius);
        return mask;
    }

    private static double SmartEditorMaskCoverage(
        string type,
        double red,
        double green,
        double blue,
        int x,
        int y,
        int width,
        int height)
    {
        var luma = red * .2126 + green * .7152 + blue * .0722;
        var chroma = Math.Max(red, Math.Max(green, blue))
            - Math.Min(red, Math.Min(green, blue));
        var unitX = x / (double)Math.Max(1, width - 1);
        var unitY = y / (double)Math.Max(1, height - 1);
        var center = 1 - Math.Min(1, Math.Sqrt(
            Math.Pow((unitX - .5) / .72, 2)
            + Math.Pow((unitY - .52) / .82, 2)));
        var subject = ClampUnit(center * .72 + chroma * .72
            + Math.Abs(luma - .5) * .18);
        if (type == "智能背景") return 1 - subject;
        if (type == "智能天空")
        {
            var top = ClampUnit((.76 - unitY) / .62);
            var skyColor = ClampUnit((blue - red * .88) * 2.5
                + (blue - green * .78) * 1.6 + .18);
            return top * skyColor * SmoothStep(.18, .82, luma);
        }
        if (type == "智能人物")
        {
            var skin = SmoothStep(.02, .20, red - blue)
                * SmoothStep(-.05, .16, red - green)
                * SmoothStep(.16, .78, luma);
            return ClampUnit(skin * .78 + subject * center * .42);
        }
        if (type == "智能亮部") return SmoothStep(.55, .88, luma);
        if (type == "智能暗部") return 1 - SmoothStep(.12, .48, luma);
        if (type == "线性渐变") return unitY;
        if (type == "径向渐变") return center;
        return subject;
    }

    private static void BlurEditorMask(
        byte[] mask,
        int width,
        int height,
        int radius)
    {
        var horizontal = new byte[mask.Length];
        var divisor = radius * 2 + 1;
        for (var y = 0; y < height; y++)
        {
            var sum = 0;
            for (var x = -radius; x <= radius; x++)
                sum += mask[y * width + Math.Clamp(x, 0, width - 1)];
            for (var x = 0; x < width; x++)
            {
                horizontal[y * width + x] = (byte)(sum / divisor);
                var removeX = Math.Max(0, x - radius);
                var addX = Math.Min(width - 1, x + radius + 1);
                sum += mask[y * width + addX] - mask[y * width + removeX];
            }
        }
        for (var x = 0; x < width; x++)
        {
            var sum = 0;
            for (var y = -radius; y <= radius; y++)
                sum += horizontal[Math.Clamp(y, 0, height - 1) * width + x];
            for (var y = 0; y < height; y++)
            {
                mask[y * width + x] = (byte)(sum / divisor);
                var removeY = Math.Max(0, y - radius);
                var addY = Math.Min(height - 1, y + radius + 1);
                sum += horizontal[addY * width + x]
                    - horizontal[removeY * width + x];
            }
        }
    }

    private static void StampEditorMask(
        byte[] mask,
        int width,
        int height,
        EditorMaskPoint point,
        EditorMaskStroke stroke,
        double feather)
    {
        var radius = Math.Max(
            1,
            stroke.Size / 200 * Math.Min(width, height));
        var softEdge = radius * Math.Clamp(feather, 0, 100) / 100;
        var outerRadius = radius + softEdge;
        var centerX = (int)Math.Round(point.X * (width - 1));
        var centerY = (int)Math.Round(point.Y * (height - 1));
        var extent = Math.Max(1, (int)Math.Ceiling(outerRadius));
        for (var y = Math.Max(0, centerY - extent);
             y <= Math.Min(height - 1, centerY + extent);
             y++)
        {
            for (var x = Math.Max(0, centerX - extent);
                 x <= Math.Min(width - 1, centerX + extent);
                 x++)
            {
                var deltaX = x - centerX;
                var deltaY = y - centerY;
                var distance = Math.Sqrt(deltaX * deltaX + deltaY * deltaY);
                if (distance > outerRadius) continue;
                var coverage = distance <= radius || softEdge <= 0
                    ? 1
                    : 1 - (distance - radius) / softEdge;
                var offset = y * width + x;
                var value = (byte)Math.Clamp(
                    (int)Math.Round(coverage * 255),
                    0,
                    255);
                mask[offset] = stroke.Subtract
                    ? (byte)Math.Max(0, mask[offset] - value)
                    : Math.Max(mask[offset], value);
            }
        }
    }

    private static void ApplyEditorDetail(
        byte[] pixels,
        int width,
        int height,
        int stride,
        EditorAdjustments settings)
    {
        var smoothing =
            settings.NoiseReduction / 100 * 0.58
            + Math.Max(0, -settings.Texture) / 100 * 0.24;
        var sharpening =
            settings.Sharpening / 100 * 1.15
            + Math.Max(0, settings.Texture) / 100 * 0.48
            + Math.Max(0, settings.Clarity) / 100 * 0.25;
        if (smoothing == 0 && sharpening == 0)
        {
            return;
        }
        var source = (byte[])pixels.Clone();
        for (var y = 1; y < height - 1; y++)
        {
            for (var x = 1; x < width - 1; x++)
            {
                var offset = y * stride + x * 4;
                for (var channel = 0; channel < 3; channel++)
                {
                    var center = source[offset + channel];
                    var average =
                        (center
                         + source[offset - 4 + channel]
                         + source[offset + 4 + channel]
                         + source[offset - stride + channel]
                         + source[offset + stride + channel]) / 5.0;
                    var smoothed =
                        center * (1 - smoothing) + average * smoothing;
                    pixels[offset + channel] = ClampChannel(
                        smoothed + (center - average) * sharpening);
                }
            }
        }
    }

    private static double EditorCropRatio(string cropRatio) =>
        cropRatio switch
        {
            "1:1" => 1,
            "4:3" => 4.0 / 3,
            "3:2" => 3.0 / 2,
            "16:9" => 16.0 / 9,
            _ => 0
        };

    private static double SmoothStep(
        double edge0,
        double edge1,
        double value)
    {
        var scaled = ClampUnit((value - edge0) / (edge1 - edge0));
        return scaled * scaled * (3 - 2 * scaled);
    }

    private static double CurveValue(List<EditorCurvePoint> source, double input)
    {
        var points = source.OrderBy(point => point.X).ToList();
        var x = ClampUnit(input);
        if (points.Count < 2) return x;
        if (x <= points[0].X) return points[0].Y;
        if (x >= points[^1].X) return points[^1].Y;
        var index = 1;
        while (index < points.Count && points[index].X < x) index++;
        var p0 = points[Math.Max(0, index - 2)];
        var p1 = points[index - 1];
        var p2 = points[index];
        var p3 = points[Math.Min(points.Count - 1, index + 1)];
        var t = (x - p1.X) / Math.Max(.0001, p2.X - p1.X);
        var t2 = t * t;
        var t3 = t2 * t;
        var y = .5 * (2 * p1.Y + (-p0.Y + p2.Y) * t
            + (2 * p0.Y - 5 * p1.Y + 4 * p2.Y - p3.Y) * t2
            + (-p0.Y + 3 * p1.Y - 3 * p2.Y + p3.Y) * t3);
        return ClampUnit(y);
    }

    private static double ClampUnit(double value) =>
        Math.Max(0, Math.Min(1, value));

    private static byte ClampChannel(double value) =>
        (byte)Math.Clamp(Math.Round(value), byte.MinValue, byte.MaxValue);

    private string UniqueEditedPath(string originalPath)
    {
        var stem = Path.GetFileNameWithoutExtension(originalPath);
        return _library.UniqueDestination(
            $"{stem}_edited_{DateTime.Now:yyyyMMdd_HHmmss}.jpg");
    }

    private void CreateLibraryBranch_Click(
        object sender,
        RoutedEventArgs e)
    {
        var selectedNode = PhotoTree.SelectedItem as LibraryTreeNode;
        var parent = FindLibraryBranch(selectedNode?.BranchId);
        var input = new TextBox
        {
            MinWidth = 320,
            Height = 36,
            Margin = new Thickness(0, 10, 0, 14)
        };
        var dialog = new Window
        {
            Owner = this,
            Title = "新建分支",
            Width = 430,
            Height = 210,
            ResizeMode = ResizeMode.NoResize,
            WindowStartupLocation = WindowStartupLocation.CenterOwner,
            Background = (Brush)FindResource("PaperBrush")
        };
        var layout = new StackPanel
        {
            Margin = new Thickness(22)
        };
        layout.Children.Add(new TextBlock
        {
            Text =
                $"将在“{parent?.Name ?? "帧澈 ZENCHE 文件库"}”下创建可继续展开的节点。",
            TextWrapping = TextWrapping.Wrap,
            Foreground = (Brush)FindResource("MutedBrush")
        });
        layout.Children.Add(input);
        var actions = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            HorizontalAlignment = HorizontalAlignment.Right
        };
        var cancel = new Button
        {
            Content = "取消",
            Width = 88,
            Height = 40,
            Style = (Style)FindResource("ButtonBase")
        };
        cancel.Click += (_, _) => dialog.Close();
        actions.Children.Add(cancel);
        var create = new Button
        {
            Content = "创建",
            Width = 88,
            Height = 40,
            Margin = new Thickness(8, 0, 0, 0),
            Style = (Style)FindResource("PrimaryButton")
        };
        create.Click += (_, _) =>
        {
            var name = input.Text.Trim();
            if (name.Length == 0)
            {
                return;
            }
            var branch = new LibraryBranch { Name = name };
            if (parent is null)
            {
                _libraryBranches.Add(branch);
            }
            else
            {
                parent.Children.Add(branch);
            }
            SaveLibraryBranches();
            RefreshPhotoList();
            dialog.Close();
        };
        actions.Children.Add(create);
        layout.Children.Add(actions);
        dialog.Content = layout;
        dialog.Loaded += (_, _) => input.Focus();
        dialog.ShowDialog();
    }

    private void DeleteLibraryBranch_Click(
        object sender,
        RoutedEventArgs e)
    {
        if (PhotoTree.SelectedItem is not LibraryTreeNode
            {
                BranchId: { } branchId
            } selectedNode)
        {
            return;
        }
        var branch = FindLibraryBranch(branchId);
        if (branch is null)
        {
            return;
        }
        var confirmation = MessageBox.Show(
            this,
            $"将同时删除“{branch.Name}”下的子分支；其中的文件会回到“未分类”，原文件不受影响。",
            "删除分支？",
            MessageBoxButton.YesNo,
            MessageBoxImage.Warning);
        if (confirmation != MessageBoxResult.Yes)
        {
            return;
        }
        var removedIds = new HashSet<string>();
        CollectLibraryBranchIds(branch, removedIds);
        if (!RemoveLibraryBranch(_libraryBranches, branchId))
        {
            return;
        }
        foreach (var path in _libraryFileAssignments
                     .Where(entry => removedIds.Contains(entry.Value))
                     .Select(entry => entry.Key)
                     .ToList())
        {
            _libraryFileAssignments.Remove(path);
        }
        SaveLibraryBranches();
        SaveLibraryFileAssignments();
        OperationStatusText.Text = AppLocalization.T(
            $"分支“{selectedNode.Name}”已删除，文件已回到未分类");
        RefreshPhotoList();
    }

    private static void CollectLibraryBranchIds(
        LibraryBranch branch,
        ISet<string> ids)
    {
        ids.Add(branch.Id);
        foreach (var child in branch.Children)
        {
            CollectLibraryBranchIds(child, ids);
        }
    }

    private static bool RemoveLibraryBranch(
        IList<LibraryBranch> branches,
        string id)
    {
        for (var index = 0; index < branches.Count; index++)
        {
            if (branches[index].Id == id)
            {
                branches.RemoveAt(index);
                return true;
            }
            if (RemoveLibraryBranch(branches[index].Children, id))
            {
                return true;
            }
        }
        return false;
    }

    private LibraryBranch? FindLibraryBranch(string? id)
    {
        if (string.IsNullOrWhiteSpace(id))
        {
            return null;
        }
        return FindLibraryBranch(_libraryBranches, id);
    }

    private static LibraryBranch? FindLibraryBranch(
        IEnumerable<LibraryBranch> branches,
        string id)
    {
        foreach (var branch in branches)
        {
            if (branch.Id == id)
            {
                return branch;
            }
            var child = FindLibraryBranch(branch.Children, id);
            if (child is not null)
            {
                return child;
            }
        }
        return null;
    }

    private static List<LibraryBranch> LoadLibraryBranches()
    {
        try
        {
            if (!File.Exists(LibraryBranchStatePath))
            {
                return [];
            }
            return JsonSerializer.Deserialize<List<LibraryBranch>>(
                File.ReadAllText(LibraryBranchStatePath)) ?? [];
        }
        catch
        {
            return [];
        }
    }

    private void SaveLibraryBranches()
    {
        var directory = Path.GetDirectoryName(LibraryBranchStatePath);
        if (!string.IsNullOrWhiteSpace(directory))
        {
            Directory.CreateDirectory(directory);
        }
        File.WriteAllText(
            LibraryBranchStatePath,
            JsonSerializer.Serialize(
                _libraryBranches,
                new JsonSerializerOptions { WriteIndented = true }));
    }

    private static Dictionary<string, string> LoadLibraryFileAssignments()
    {
        try
        {
            if (!File.Exists(LibraryFileAssignmentStatePath))
            {
                return [];
            }
            return JsonSerializer.Deserialize<Dictionary<string, string>>(
                File.ReadAllText(LibraryFileAssignmentStatePath)) ?? [];
        }
        catch
        {
            return [];
        }
    }

    private void SaveLibraryFileAssignments()
    {
        var directory = Path.GetDirectoryName(
            LibraryFileAssignmentStatePath);
        if (!string.IsNullOrWhiteSpace(directory))
        {
            Directory.CreateDirectory(directory);
        }
        File.WriteAllText(
            LibraryFileAssignmentStatePath,
            JsonSerializer.Serialize(
                _libraryFileAssignments,
                new JsonSerializerOptions { WriteIndented = true }));
    }

    private static List<RememberedCameraDevice> LoadRememberedDevices()
    {
        try
        {
            if (!File.Exists(RememberedDevicesStatePath)) return [];
            return JsonSerializer.Deserialize<List<RememberedCameraDevice>>(
                       File.ReadAllText(RememberedDevicesStatePath))?
                   .OrderByDescending(device => device.LastConnectedAt)
                   .ToList() ?? [];
        }
        catch (Exception error)
        {
            DiagnosticLogger.Shared.Warning(
                "devices",
                $"读取已连接设备失败：{error.Message}");
            return [];
        }
    }

    private void SaveRememberedDevices()
    {
        try
        {
            var directory = Path.GetDirectoryName(RememberedDevicesStatePath);
            if (!string.IsNullOrWhiteSpace(directory))
            {
                Directory.CreateDirectory(directory);
            }
            File.WriteAllText(
                RememberedDevicesStatePath,
                JsonSerializer.Serialize(
                    _rememberedDevices,
                    new JsonSerializerOptions { WriteIndented = true }));
        }
        catch (Exception error)
        {
            _diagnostics.Warning(
                "devices",
                $"保存已连接设备失败：{error.Message}");
        }
    }

    private void RememberConnectedDevice(CameraProfile profile)
    {
        var id = $"{profile.VendorId:x4}:{profile.ProductId:x4}:{profile.Name}";
        _rememberedDevices.RemoveAll(device => device.Id == id);
        _rememberedDevices.Insert(0, new RememberedCameraDevice
        {
            Id = id,
            Name = profile.Name,
            Vendor = profile.VendorName,
            Transport = "USB/PTP",
            LastConnectedAt = DateTime.Now
        });
        if (_rememberedDevices.Count > 12)
        {
            _rememberedDevices.RemoveRange(12, _rememberedDevices.Count - 12);
        }
        SaveRememberedDevices();
        RefreshRememberedDevices();
    }

    private void RememberLocalCamera(string name)
    {
        const string id = "windows-local-camera";
        _rememberedDevices.RemoveAll(device => device.Id == id);
        _rememberedDevices.Insert(0, new RememberedCameraDevice
        {
            Id = id,
            Name = name,
            Vendor = "System",
            Transport = "本机摄像头",
            LastConnectedAt = DateTime.Now
        });
        if (_rememberedDevices.Count > 12)
        {
            _rememberedDevices.RemoveRange(12, _rememberedDevices.Count - 12);
        }
        SaveRememberedDevices();
        RefreshRememberedDevices();
    }

    private void RefreshRememberedDevices()
    {
        if (DevicesWrapPanel is null || DevicesEmptyState is null) return;
        DevicesWrapPanel.Children.Clear();
        DevicesEmptyState.Visibility = _rememberedDevices.Count == 0
            ? Visibility.Visible
            : Visibility.Collapsed;
        foreach (var device in _rememberedDevices)
        {
            DevicesWrapPanel.Children.Add(BuildRememberedDeviceCard(device));
        }
    }

    private Border BuildRememberedDeviceCard(RememberedCameraDevice device)
    {
        var current = device.Transport == "本机摄像头"
            ? _localCamera.IsConnected && _localCamera.DeviceName == device.Name
            : _camera.IsConnected && _camera.Profile?.Name == device.Name;
        var card = new Border
        {
            Width = 360,
            Margin = new Thickness(0, 0, 16, 16),
            Background = (Brush)FindResource("SurfaceRaisedBrush"),
            BorderBrush = (Brush)FindResource(
                current ? "PositiveBrush" : "RuleBrush"),
            BorderThickness = new Thickness(1),
            CornerRadius = (CornerRadius)FindResource("CornerRadius18"),
            ClipToBounds = true
        };
        var content = new StackPanel();
        var filename = device.Vendor.Contains(
                "Sony",
                StringComparison.OrdinalIgnoreCase)
            ? "camera-sony.jpg"
            : device.Vendor.Contains(
                "Canon",
                StringComparison.OrdinalIgnoreCase)
                ? "camera-canon.jpg"
                : "camera-nikon.jpg";
        try
        {
            content.Children.Add(new Image
            {
                Height = 190,
                Stretch = Stretch.UniformToFill,
                Source = new BitmapImage(new Uri(
                    $"pack://application:,,,/Assets/{filename}",
                    UriKind.Absolute))
            });
        }
        catch
        {
            content.Children.Add(new Border
            {
                Height = 190,
                Background = (Brush)FindResource("GraphiteBrush"),
                // 占位图标 46pt，图标尺寸不受 TypeScale 约束（同 F1 先例）
                Child = new TextBlock
                {
                    Text = "◉",
                    FontSize = 46,
                    Foreground = Brushes.White,
                    HorizontalAlignment = HorizontalAlignment.Center,
                    VerticalAlignment = VerticalAlignment.Center
                }
            });
        }

        var body = new StackPanel { Margin = new Thickness(16) };
        var heading = new DockPanel();
        if (current)
        {
            var badge = new TextBlock
            {
                Text = AppLocalization.T("当前已连接"),
                Style = (Style)FindResource("DeviceBadgeText"),
                VerticalAlignment = VerticalAlignment.Center
            };
            DockPanel.SetDock(badge, Dock.Right);
            heading.Children.Add(badge);
        }
        heading.Children.Add(new TextBlock
        {
            Text = device.Name,
            Style = (Style)FindResource("DeviceNameText"),
            TextTrimming = TextTrimming.CharacterEllipsis
        });
        body.Children.Add(heading);
        body.Children.Add(new TextBlock
        {
            Text = $"{device.Vendor} · {device.Transport}",
            Margin = new Thickness(0, 9, 0, 0),
            Foreground = (Brush)FindResource("MutedBrush")
        });
        body.Children.Add(new TextBlock
        {
            Text = $"{AppLocalization.T("最近连接")} · " +
                   device.LastConnectedAt.ToString("yyyy-MM-dd HH:mm"),
            Margin = new Thickness(0, 7, 0, 0),
            Style = (Style)FindResource("DeviceMetaText")
        });

        var actions = new Grid { Margin = new Thickness(0, 14, 0, 0) };
        actions.ColumnDefinitions.Add(new ColumnDefinition());
        actions.ColumnDefinitions.Add(new ColumnDefinition
        {
            Width = new GridLength(112)
        });
        var reconnect = new Button
        {
            Content = AppLocalization.T("快速连接"),
            Height = 44,
            IsEnabled = !current && !_operationInProgress,
            Style = (Style)FindResource("PrimaryButton")
        };
        reconnect.Click += async (_, _) =>
            await ReconnectRememberedDeviceAsync(device);
        actions.Children.Add(reconnect);
        var forget = new Button
        {
            Content = AppLocalization.T("忘记设备"),
            Height = 44,
            Margin = new Thickness(10, 0, 0, 0),
            Style = (Style)FindResource("ButtonBase")
        };
        Grid.SetColumn(forget, 1);
        forget.Click += (_, _) =>
        {
            _rememberedDevices.RemoveAll(item => item.Id == device.Id);
            SaveRememberedDevices();
            RefreshRememberedDevices();
        };
        actions.Children.Add(forget);
        body.Children.Add(actions);
        content.Children.Add(body);
        card.Child = content;
        return card;
    }

    private async Task ReconnectRememberedDeviceAsync(
        RememberedCameraDevice device)
    {
        if (_operationInProgress) return;
        if (device.Transport == "本机摄像头")
        {
            if (!_localCamera.IsConnected)
            {
                await ToggleLocalCameraConnectionAsync();
            }
            return;
        }
        if (_camera.IsConnected)
        {
            await RunOperationAsync("正在断开相机…", async token =>
            {
                await FinishExternalRecordingForDisconnectAsync();
                await StopPreviewLoopAsync();
                await _camera.DisconnectAsync(token);
                SetConnectionState(null);
            });
        }
        if (_operationInProgress || _camera.IsConnected) return;
        await RunOperationAsync("正在连接相机…", async token =>
        {
            var profile = await _camera.ConnectAsync(token);
            SetConnectionState(profile);
            RememberConnectedDevice(profile);
            OperationStatusText.Text = AppLocalization.T(
                $"{profile.Name} 已连接");
        });
    }

    private void SetCurrentNavigation(Button? current)
    {
        var videoActive = current == MonitorNav;
        foreach (var button in new[]
                 {
                     CaptureNav,
                     MonitorNav,
                     EditorNav,
                     DevicesNav,
                     LibraryNav
                 })
        {
            button.Background = button == current
                ? (Brush)FindResource(
                    videoActive ? "VideoSoftBrush" : "AccentSoftBrush")
                : Brushes.Transparent;
            button.Foreground = button == current
                ? (Brush)FindResource(
                    videoActive ? "VideoBrush" : "AccentBrush")
                : (Brush)FindResource("InkBrush");
            button.FontWeight = button == current
                ? FontWeights.Bold
                : FontWeights.Normal;
        }
    }

    private static void ShowError(string message)
    {
        DiagnosticLogger.Shared.Error("ui", message);
        MessageBox.Show(
            AppLocalization.T(message),
            "帧澈 ZENCHE",
            MessageBoxButton.OK,
            MessageBoxImage.Warning);
    }

    private async void Window_Closing(
        object? sender,
        System.ComponentModel.CancelEventArgs e)
    {
        if (_shutdownStarted)
        {
            return;
        }

        e.Cancel = true;
        _shutdownStarted = true;
        SaveWorkspaceLayout();
        Closing -= Window_Closing;
        _monitorTimecodeTimer.Stop();
        _editorPreviewTimer.Stop();
        _editorPreviewPending = false;
        EditorPreviewImage.Source = null;
        AiPreviewImage.Source = null;
        ClearAiResultFile();
        StopWifiMonitoring();
        StopWifiPreviewLoop();
        if (_immersivePreviewWindow is { } immersive)
        {
            CloseImmersivePreview(immersive);
        }
        try
        {
            await FinishExternalRecordingForDisconnectAsync();
            await StopPreviewLoopAsync();
            await _wirelessServer.DisposeAsync();
            await _wifiCamera.DisposeAsync();
            await _localCamera.DisposeAsync();
            await _bluetoothRemote.DisposeAsync();
            await _locationTagging.SetEnabledAsync(false);
            if (_camera.IsConnected)
            {
                await _camera.DisconnectAsync();
            }
            _camera.Dispose();
            _externalVideoRecorder.Dispose();
        }
        catch
        {
        }
        Close();
    }
}
