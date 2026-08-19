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
        // ── Sony α ── (Product ID 0 means vendor wildcard)
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
        new("Sony A6100", "Sony", 0x054c, 0x0000, 100, 32000),
        new("Sony A6400", "Sony", 0x054c, 0x0000, 100, 32000),
        new("Sony A6600", "Sony", 0x054c, 0x0000, 100, 32000),
        new("Sony A6700", "Sony", 0x054c, 0x0000, 100, 32000),
        new("Sony FX30", "Sony", 0x054c, 0x0000, 100, 32000),
        new("Sony ZV-E10", "Sony", 0x054c, 0x0000, 100, 32000),
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
        // ── Canon DIGIC X (2025 补齐) ──
        new("Canon EOS R6 Mark III", "Canon", 0x04a9, 0x0000, 100, 64000),
        new("Canon EOS R6", "Canon", 0x04a9, 0x0000, 100, 102400),
        new("Canon EOS R5 C", "Canon", 0x04a9, 0x0000, 100, 51200),
        new("Canon EOS R50 V", "Canon", 0x04a9, 0x0000, 100, 32000),
    ];

    public static string Summary =>
        string.Join("、", Supported
            .Select(camera => camera.Name)
            .Distinct());

    /// <summary>
    /// Sony model aliases used by the Camera Remote SDK matching. Keys are
    /// lowercase, separator-stripped model strings reported by the SDK or the
    /// USB descriptor; values are the canonical profile name. Explicit aliases
    /// (A6100A/A6400A, ILCE-1M2, ZV-E10M2, ...) keep a newer generation from
    /// falling back to its base model during longest-match resolution.
    /// </summary>
    public static readonly IReadOnlyDictionary<string, string> SonyModelAliases =
        new Dictionary<string, string>(StringComparer.Ordinal)
        {
            // A1 / A1 II
            ["a1"] = "Sony A1",
            ["ilcea1"] = "Sony A1",
            ["a1m2"] = "Sony A1 II",
            ["a1ii"] = "Sony A1 II",
            ["a1mk2"] = "Sony A1 II",
            ["ilcea1m2"] = "Sony A1 II",
            // A9 III
            ["a9m3"] = "Sony A9 III",
            ["a9iii"] = "Sony A9 III",
            ["ilcea9m3"] = "Sony A9 III",
            // A7R V
            ["a7rm5"] = "Sony A7R V",
            ["a7rv"] = "Sony A7R V",
            ["ilcea7rm5"] = "Sony A7R V",
            // A7 IV
            ["a7m4"] = "Sony A7 IV",
            ["a7iv"] = "Sony A7 IV",
            ["ilcea7m4"] = "Sony A7 IV",
            // A7S III
            ["a7sm3"] = "Sony A7S III",
            ["a7siii"] = "Sony A7S III",
            ["ilcea7sm3"] = "Sony A7S III",
            // A7C II
            ["a7cm2"] = "Sony A7C II",
            ["a7cii"] = "Sony A7C II",
            ["ilcea7cm2"] = "Sony A7C II",
            // A7C R
            ["a7cr"] = "Sony A7C R",
            ["ilcea7cr"] = "Sony A7C R",
            // ZV-E1
            ["zve1"] = "Sony ZV-E1",
            ["ilcezve1"] = "Sony ZV-E1",
            // APS-C: A6100 / A6100A
            ["a6100"] = "Sony A6100",
            ["a6100a"] = "Sony A6100",
            ["ilcea6100"] = "Sony A6100",
            ["ilcea6100a"] = "Sony A6100",
            // APS-C: A6400 / A6400A
            ["a6400"] = "Sony A6400",
            ["a6400a"] = "Sony A6400",
            ["ilcea6400"] = "Sony A6400",
            ["ilcea6400a"] = "Sony A6400",
            // APS-C: A6600
            ["a6600"] = "Sony A6600",
            ["ilcea6600"] = "Sony A6600",
            // APS-C: A6700
            ["a6700"] = "Sony A6700",
            ["ilcea6700"] = "Sony A6700",
            // FX30
            ["fx30"] = "Sony FX30",
            ["ilmefx30"] = "Sony FX30",
            // ZV-E10 / ZV-E10 II
            ["zve10"] = "Sony ZV-E10",
            ["ilcezve10"] = "Sony ZV-E10",
            ["zve10m2"] = "Sony ZV-E10 II",
            ["zve10ii"] = "Sony ZV-E10 II",
            ["zve102"] = "Sony ZV-E10 II",
            ["ilcezve10m2"] = "Sony ZV-E10 II",
        };

    /// <summary>
    /// Matches a Sony model string reported by the Camera Remote SDK or a USB
    /// descriptor to the most specific known profile. Both sides are
    /// normalized identically (lowercase, ILCE-/ILME- prefix folded, and all
    /// separators/whitespace stripped), then the longest alias contained in
    /// the normalized model wins, so ZV-E10M2 resolves to ZV-E10 II and
    /// ILCE-1M2 resolves to A1 II instead of their base models.
    /// </summary>
    public static CameraProfile? MatchSonyModel(string model)
    {
        var normalized = NormalizeSonyModel(model);
        if (normalized.Length == 0)
        {
            return null;
        }
        string? bestName = null;
        var bestLength = -1;
        foreach (var pair in SonyModelAliases)
        {
            if (normalized.Contains(pair.Key, StringComparison.Ordinal) &&
                pair.Key.Length > bestLength)
            {
                bestLength = pair.Key.Length;
                bestName = pair.Value;
            }
        }
        if (bestName is null)
        {
            return null;
        }
        return Supported.FirstOrDefault(candidate =>
            candidate.VendorId == 0x054c &&
            string.Equals(candidate.Name, bestName, StringComparison.Ordinal));
    }

    private static string NormalizeSonyModel(string model)
    {
        var value = model
            .Replace("ILCE-", "A", StringComparison.OrdinalIgnoreCase)
            .Replace("ILME-", "", StringComparison.OrdinalIgnoreCase)
            .ToLowerInvariant();
        var builder = new System.Text.StringBuilder(value.Length);
        foreach (var character in value)
        {
            if (character is '-' or '_' or ' ' or '\u00a0')
            {
                continue;
            }
            builder.Append(character);
        }
        return builder.ToString();
    }

    public static CameraProfile? Find(ushort vendorId, ushort productId)
    {
        var exact = Supported.FirstOrDefault(
            camera => camera.VendorId == vendorId
                && camera.ProductId != 0
                && camera.ProductId == productId);
        if (exact is not null)
        {
            return exact;
        }

        // Keep the fallback generic when libusb cannot expose a model
        // descriptor, rather than guessing a specific camera.
        return vendorId switch
        {
            0x054c => new("Sony " + "α USB/PTP", "Sony", vendorId, 0, 100, 102400),
            0x04a9 => new("Canon " + "EOS USB/PTP", "Canon", vendorId, 0, 100, 102400),
            _ => null,
        };
    }
}
