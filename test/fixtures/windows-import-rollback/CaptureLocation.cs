namespace NikonLink.Windows.Services;

public sealed record CaptureLocation(
    double Latitude,
    double Longitude,
    double Altitude,
    double HorizontalAccuracy,
    DateTimeOffset CapturedAt);
