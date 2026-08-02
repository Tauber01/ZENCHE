namespace NikonLink.Windows.Models;

public sealed record CameraProfile(
    string Name,
    string VendorName,
    ushort VendorId,
    ushort ProductId,
    int MinimumIso,
    int MaximumIso)
{
    public static readonly IReadOnlySet<ushort> SupportedVendorIds =
        new HashSet<ushort> { 0x04b0, 0x054c, 0x04a9 };

    public static readonly IReadOnlyList<CameraProfile> Supported =
    [
        // ── Nikon EXPEED 5 ──
        new("Nikon D500", "Nikon", 0x04b0, 0x043a, 100, 51200),
        new("Nikon D7500", "Nikon", 0x04b0, 0x0445, 100, 51200),
        new("Nikon D850", "Nikon", 0x04b0, 0x044a, 64, 25600),
        // ── Nikon EXPEED 6 ──
        new("Nikon Z7", "Nikon", 0x04b0, 0x0442, 64, 25600),
        new("Nikon Z6", "Nikon", 0x04b0, 0x0443, 100, 51200),
        new("Nikon Z50", "Nikon", 0x04b0, 0x0444, 100, 51200),
        new("Nikon D780", "Nikon", 0x04b0, 0x0446, 100, 51200),
        new("Nikon D6", "Nikon", 0x04b0, 0x0447, 100, 102400),
        new("Nikon Z5", "Nikon", 0x04b0, 0x0448, 100, 51200),
        new("Nikon Z7II", "Nikon", 0x04b0, 0x044b, 64, 25600),
        new("Nikon Z6II", "Nikon", 0x04b0, 0x044c, 100, 51200),
        new("Nikon Z fc", "Nikon", 0x04b0, 0x044f, 100, 51200),
        new("Nikon Z30", "Nikon", 0x04b0, 0x0452, 100, 51200),
        // ── Nikon EXPEED 7 ──
        new("Nikon Z9", "Nikon", 0x04b0, 0x0450, 64, 25600),
        new("Nikon Z8", "Nikon", 0x04b0, 0x0451, 64, 25600),
        new("Nikon Z f", "Nikon", 0x04b0, 0x0453, 100, 64000),
        new("Nikon Z6III", "Nikon", 0x04b0, 0x0454, 100, 64000),
        new("Nikon Z50II", "Nikon", 0x04b0, 0x0455, 100, 51200),
        new("Nikon Z5II", "Nikon", 0x04b0, 0x0456, 100, 64000),
        new("Nikon ZR", "Nikon", 0x04b0, 0x0457, 100, 51200),
        // ── Sony α ── (Product IDs: TODO — confirm with gphoto2 --auto-detect)
        // Full-frame E-mount
        new("Sony A1", "Sony", 0x054c, 0x0000, 100, 32000),
        new("Sony A1 II", "Sony", 0x054c, 0x0000, 100, 32000),
        new("Sony A9 III", "Sony", 0x054c, 0x0000, 100, 51200),
        new("Sony A7R V", "Sony", 0x054c, 0x0000, 100, 32000),
        new("Sony A7 IV", "Sony", 0x054c, 0x0000, 100, 51200),
        new("Sony A7S III", "Sony", 0x054c, 0x0000, 80, 102400),
        new("Sony A7C II", "Sony", 0x054c, 0x0000, 100, 51200),
        new("Sony A7C R", "Sony", 0x054c, 0x0000, 100, 32000),
        new("Sony ZV-E1", "Sony", 0x054c, 0x0000, 80, 102400),
        // APS-C E-mount
        new("Sony A6700", "Sony", 0x054c, 0x0000, 100, 32000),
        new("Sony FX30", "Sony", 0x054c, 0x0000, 100, 32000),
        new("Sony ZV-E10 II", "Sony", 0x054c, 0x0000, 100, 32000),
        // ── Canon EOS R ── (Product IDs: TODO — confirm with gphoto2 --auto-detect)
        new("Canon EOS R1", "Canon", 0x04a9, 0x0000, 100, 102400),
        new("Canon EOS R3", "Canon", 0x04a9, 0x0000, 100, 102400),
        new("Canon EOS R5", "Canon", 0x04a9, 0x0000, 100, 51200),
        new("Canon EOS R5 Mark II", "Canon", 0x04a9, 0x0000, 100, 51200),
        new("Canon EOS R6 Mark II", "Canon", 0x04a9, 0x0000, 100, 102400),
        new("Canon EOS R7", "Canon", 0x04a9, 0x0000, 100, 12800),
        new("Canon EOS R8", "Canon", 0x04a9, 0x0000, 100, 102400),
        new("Canon EOS R10", "Canon", 0x04a9, 0x0000, 100, 12800),
        new("Canon EOS R50", "Canon", 0x04a9, 0x0000, 100, 12800),
        new("Canon EOS R100", "Canon", 0x04a9, 0x0000, 100, 12800),
    ];

    public static string Summary =>
        string.Join("、", Supported
            .Select(camera => camera.Name)
            .Distinct());

    public static CameraProfile? Find(ushort vendorId, ushort productId) =>
        Supported.FirstOrDefault(
            camera => camera.VendorId == vendorId && camera.ProductId == productId);
}
