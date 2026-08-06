namespace NikonLink.Windows.Services;

/// <summary>
/// Vendor-specific PTP operation codes and property encodings.
/// Each camera vendor (Nikon, Sony, Canon) uses different proprietary
/// extension opcodes on top of the standard PTP/MTP protocol.
/// </summary>
public interface IPtpVendorOps
{
    // ── Live view / capture operations ──
    ushort StartLiveView { get; }
    ushort EndLiveView { get; }
    ushort GetLiveViewImage { get; }
    ushort CaptureToSdram { get; }
    ushort StartMovieRecording { get; }
    ushort EndMovieRecording { get; }
    ushort TerminateCapture { get; }
    ushort ManualFocusDrive { get; }
    ushort ChangeCameraMode { get; }
    ushort DeviceReady { get; }
    ushort GetEvent { get; }
    ushort ObjectAddedInSdram { get; }

    // ── Shutter property codes (ordered by preference) ──
    ushort[] ShutterProperties { get; }
    ushort[] VideoShutterProperties { get; }

    // ── Vendor-specific property IDs ──
    ushort? PictureControlProperty { get; }
    ushort? LiveViewAfProperty { get; }

    // ── Property encoding ──
    byte[] EncodeShutterValue(double seconds);

    // ── Property-code-to-app-name mapping ──
    IReadOnlyDictionary<ushort, string> PropertyCodeToName { get; }
}

// ═══════════════════════════════════════════════════════════════════
//  Nikon vendor ops (production — validated on 20 EXPEED 5/6/7 bodies)
// ═══════════════════════════════════════════════════════════════════

public sealed class NikonVendorOps : IPtpVendorOps
{
    public ushort StartLiveView => 0x9201;
    public ushort EndLiveView => 0x9202;
    public ushort GetLiveViewImage => 0x9203;
    public ushort CaptureToSdram => 0x9207;
    public ushort StartMovieRecording => 0x920a;
    public ushort EndMovieRecording => 0x920b;
    public ushort TerminateCapture => 0x920c;
    public ushort ManualFocusDrive => 0x9204;
    public ushort ChangeCameraMode => 0x90c2;
    public ushort DeviceReady => 0x90c8;
    public ushort GetEvent => 0x90c7;
    public ushort ObjectAddedInSdram => 0xc101;

    public ushort[] ShutterProperties => [0xd100, 0x500d];
    public ushort[] VideoShutterProperties => [0xd1a8, 0x500d, 0xd100];

    public ushort? PictureControlProperty => 0xd200;
    public ushort? LiveViewAfProperty => 0xd061;

    public byte[] EncodeShutterValue(double seconds) =>
        NikonShutterValue(seconds);

    public IReadOnlyDictionary<ushort, string> PropertyCodeToName =>
        new Dictionary<ushort, string>
        {
            [0x500d] = "exposureTime",
            [0xd100] = "exposureTime",
            [0xd1a8] = "videoExposureTime",
            [0x5007] = "aperture",
            [0x500f] = "iso",
            [0x5010] = "exposureCompensation",
            [0x5005] = "whiteBalanceMode",
            [0x500a] = "focusMode",
            [0xd061] = "focusMode",
            [0x500e] = "exposureMode",
            [0xd200] = "pictureControl",
        };

    /// <summary>
    /// Nikon proprietary shutter encoding: packed numerator/denominator format.
    /// For fractions less than 1s: (1 &lt;&lt; 16) | denominator.
    /// For whole seconds: (seconds &lt;&lt; 16) | 1.
    /// </summary>
    internal static byte[] NikonShutterValue(double seconds)
    {
        if (seconds <= 0)
        {
            return BitConverter.GetBytes((uint)0x00010000);
        }

        if (seconds < 1.0)
        {
            int denominator = (int)Math.Round(1.0 / seconds);
            denominator = Math.Max(1, denominator);
            return BitConverter.GetBytes((uint)((1u << 16) | (uint)denominator));
        }

        if (Math.Abs(seconds - Math.Round(seconds)) < 0.001)
        {
            int wholeSeconds = (int)Math.Round(seconds);
            return BitConverter.GetBytes((uint)(((uint)wholeSeconds << 16) | 1u));
        }

        int num = (int)Math.Round(seconds * 1000);
        int denom = 1000;
        int gcd = Gcd(num, denom);
        num /= gcd;
        denom /= gcd;
        return BitConverter.GetBytes((uint)(((uint)num << 16) | (uint)denom));
    }

    private static int Gcd(int a, int b)
    {
        while (b != 0) { int t = b; b = a % b; a = t; }
        return a;
    }
}

// ═══════════════════════════════════════════════════════════════════
//  Sony vendor ops — EXPERIMENTAL (opcodes from libgphoto2 camlibs/ptp2)
//  ⚠️ NOT validated on physical Sony hardware.
// ═══════════════════════════════════════════════════════════════════

public sealed class SonyVendorOps : IPtpVendorOps
{
    // Sony PTP vendor extension operation codes.
    // Reference: libgphoto2 camlibs/ptp2/library.c Sony-specific section.
    // These are best-effort mappings; real-hardware validation is required
    // before removing the experimental label.
    public ushort StartLiveView => 0x9201;       // TBC: may differ on Sony
    public ushort EndLiveView => 0x9202;         // TBC
    public ushort GetLiveViewImage => 0x9203;     // TBC: Sony live-view format may differ
    public ushort CaptureToSdram => 0x9207;       // TBC: Sony may use standard InitiateCapture
    public ushort StartMovieRecording => 0x920a;  // TBC
    public ushort EndMovieRecording => 0x920b;    // TBC
    public ushort TerminateCapture => 0x920c;     // Standard PTP
    public ushort ManualFocusDrive => 0x9204;     // TBC
    public ushort ChangeCameraMode => 0x90c2;     // TBC: Sony may use a different mechanism
    public ushort DeviceReady => 0x90c8;          // Standard
    public ushort GetEvent => 0x90c7;             // Standard
    public ushort ObjectAddedInSdram => 0xc101;   // Standard

    // Sony appears to use standard PTP exposure properties exclusively.
    public ushort[] ShutterProperties => [0x500d];
    public ushort[] VideoShutterProperties => [0x500d];

    public ushort? PictureControlProperty => null;  // Sony uses Creative Style via different mechanism
    public ushort? LiveViewAfProperty => null;       // Standard 0x500a only

    public byte[] EncodeShutterValue(double seconds) =>
        StandardShutterValue(seconds);

    public IReadOnlyDictionary<ushort, string> PropertyCodeToName =>
        new Dictionary<ushort, string>
        {
            [0x500d] = "exposureTime",
            [0x5007] = "aperture",
            [0x500f] = "iso",
            [0x5010] = "exposureCompensation",
            [0x5005] = "whiteBalanceMode",
            [0x500a] = "focusMode",
            [0x500e] = "exposureMode",
        };

    /// <summary>
    /// Standard PTP exposure time encoding (uint32 LE, seconds × 10000).
    /// </summary>
    internal static byte[] StandardShutterValue(double seconds)
    {
        uint value = seconds <= 0
            ? 1u
            : (uint)Math.Clamp((long)(seconds * 10000), 1, uint.MaxValue);
        return BitConverter.GetBytes(value);
    }
}

// ═══════════════════════════════════════════════════════════════════
//  Canon vendor ops — EXPERIMENTAL (opcodes from libgphoto2 camlibs/ptp2)
//  ⚠️ NOT validated on physical Canon EOS R hardware.
// ═══════════════════════════════════════════════════════════════════

public sealed class CanonVendorOps : IPtpVendorOps
{
    // Canon EOS PTP vendor extension operation codes.
    // Reference: libgphoto2 camlibs/ptp2/library.c Canon-specific section,
    // Canon EOS Utility USB captures.
    // These are best-effort mappings; real-hardware validation is required
    // before removing the experimental label.
    public ushort StartLiveView => 0x9201;       // TBC: Canon uses proprietary LiveView
    public ushort EndLiveView => 0x9202;         // TBC
    public ushort GetLiveViewImage => 0x9203;     // TBC
    public ushort CaptureToSdram => 0x9207;       // TBC: Canon may use standard InitiateCapture (0x100E)
    // Canon EOS 录像不走单一 opcode：PtpCamera 对 0x04a9 走
    // EOS_SetDevicePropValueEx(0x9110) 写 EVFRecordStatus(0xD1b8) 序列
    // （1=开始 0=停止，digiCamControl/qDslrDashboard 社区方案，TBC-awaiting-hardware）。
    public ushort StartMovieRecording => 0x920a;  // TBC: unused for Canon — see CanonStartMovieRecordingAsync
    public ushort EndMovieRecording => 0x920b;    // TBC: unused for Canon — see CanonStopMovieRecordingAsync
    public ushort TerminateCapture => 0x920c;     // Standard PTP
    public ushort ManualFocusDrive => 0x9204;     // TBC
    public ushort ChangeCameraMode => 0x90c2;     // TBC: Canon "remote shooting" mode entry
    public ushort DeviceReady => 0x90c8;          // Standard
    public ushort GetEvent => 0x90c7;             // Standard
    public ushort ObjectAddedInSdram => 0xc101;   // Standard

    public ushort[] ShutterProperties => [0x500d];
    public ushort[] VideoShutterProperties => [0x500d];

    public ushort? PictureControlProperty => null;  // Canon Picture Style: 0xd108 (TBC)
    public ushort? LiveViewAfProperty => null;       // Standard 0x500a

    public byte[] EncodeShutterValue(double seconds) =>
        SonyVendorOps.StandardShutterValue(seconds);

    public IReadOnlyDictionary<ushort, string> PropertyCodeToName =>
        new Dictionary<ushort, string>
        {
            [0x500d] = "exposureTime",
            [0x5007] = "aperture",
            [0x500f] = "iso",
            [0x5010] = "exposureCompensation",
            [0x5005] = "whiteBalanceMode",
            [0x500a] = "focusMode",
            [0x500e] = "exposureMode",
        };
}

/// <summary>
/// Selects the correct vendor ops implementation for a given USB vendor ID.
/// </summary>
public static class PtpVendorOps
{
    public static IPtpVendorOps ForVendor(ushort vendorId) =>
        vendorId switch
        {
            0x04b0 => new NikonVendorOps(),
            0x054c => new SonyVendorOps(),
            0x04a9 => new CanonVendorOps(),
            _ => throw new ArgumentException(
                $"不支持的相机厂商 USB ID：{vendorId:x4}"),
        };
}
