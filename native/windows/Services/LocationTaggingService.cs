using Windows.Devices.Geolocation;

namespace NikonLink.Windows.Services;

public sealed record CaptureLocation(
    double Latitude,
    double Longitude,
    double Altitude,
    double HorizontalAccuracy,
    DateTimeOffset CapturedAt);

public sealed class LocationTaggingService
{
    private Geolocator? _locator;
    private CaptureLocation? _latest;

    public bool Enabled { get; private set; }
    public string Status { get; private set; } = "定位未开启";

    public event EventHandler<string>? StatusChanged;

    public async Task SetEnabledAsync(bool enabled)
    {
        if (!enabled)
        {
            Enabled = false;
            _locator = null;
            _latest = null;
            SetStatus("定位未开启");
            return;
        }
        var access = await Geolocator.RequestAccessAsync();
        if (access != GeolocationAccessStatus.Allowed)
        {
            Enabled = false;
            SetStatus("定位权限不可用");
            return;
        }
        Enabled = true;
        _locator = new Geolocator
        {
            DesiredAccuracy = PositionAccuracy.High,
            MovementThreshold = 5,
            ReportInterval = 1000
        };
        await RefreshAsync();
    }

    public async Task RefreshAsync(CancellationToken cancellationToken = default)
    {
        if (!Enabled || _locator is null) return;
        SetStatus("正在获取位置…");
        try
        {
            cancellationToken.ThrowIfCancellationRequested();
            var position = await _locator.GetGeopositionAsync(
                maximumAge: TimeSpan.FromMinutes(2),
                timeout: TimeSpan.FromSeconds(12));
            cancellationToken.ThrowIfCancellationRequested();
            var coordinate = position.Coordinate;
            var point = coordinate.Point.Position;
            _latest = new CaptureLocation(
                point.Latitude,
                point.Longitude,
                point.Altitude,
                coordinate.Accuracy,
                coordinate.Timestamp);
            SetStatus($"定位就绪 · ±{coordinate.Accuracy:0} m");
        }
        catch (Exception error)
        {
            SetStatus($"定位失败：{error.Message}");
        }
    }

    public CaptureLocation? Snapshot(TimeSpan? maximumAge = null)
    {
        var age = maximumAge ?? TimeSpan.FromMinutes(2);
        return Enabled && _latest is not null &&
            DateTimeOffset.Now - _latest.CapturedAt <= age
                ? _latest
                : null;
    }

    private void SetStatus(string value)
    {
        Status = value;
        StatusChanged?.Invoke(this, value);
    }
}
