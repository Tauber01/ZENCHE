namespace NikonLink.Windows.Models;

public sealed record CameraProfile(
    string Name,
    ushort ProductId,
    int MinimumIso,
    int MaximumIso)
{
    public const ushort NikonVendorId = 0x04b0;

    public static readonly IReadOnlyList<CameraProfile> Supported =
    [
        new("Nikon D500", 0x043a, 100, 51200),
        new("Nikon Z7", 0x0442, 64, 25600),
        new("Nikon Z6", 0x0443, 100, 51200),
        new("Nikon Z50", 0x0444, 100, 51200),
        new("Nikon D7500", 0x0445, 100, 51200),
        new("Nikon D780", 0x0446, 100, 51200),
        new("Nikon D6", 0x0447, 100, 102400),
        new("Nikon Z5", 0x0448, 100, 51200),
        new("Nikon D850", 0x044a, 64, 25600),
        new("Nikon Z7II", 0x044b, 64, 25600),
        new("Nikon Z6II", 0x044c, 100, 51200),
        new("Nikon Z fc", 0x044f, 100, 51200),
        new("Nikon Z9", 0x0450, 64, 25600),
        new("Nikon Z8", 0x0451, 64, 25600),
        new("Nikon Z30", 0x0452, 100, 51200),
        new("Nikon Z f", 0x0453, 100, 64000),
        new("Nikon Z6III", 0x0454, 100, 64000),
        new("Nikon Z50II", 0x0455, 100, 51200),
        new("Nikon Z5II", 0x0456, 100, 64000),
        new("Nikon ZR", 0x0457, 100, 51200)
    ];

    public static string Summary =>
        string.Join("、", Supported.Select(camera =>
            camera.Name.Replace("Nikon ", string.Empty)));

    public static CameraProfile? Find(ushort productId) =>
        Supported.FirstOrDefault(camera => camera.ProductId == productId);
}
