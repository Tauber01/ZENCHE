import AppKit
import Foundation

struct ProfessionalMonitorResult {
    let image: NSImage
    let redHistogram: String
    let greenHistogram: String
    let blueHistogram: String
    let waveform: String
    let vectorscope: String
    let peakingCoverage: Int
}

enum ProfessionalMonitor {
    private static let scopeColumns = 64
    private static let scopeRows = 48

    static func process(
        _ image: NSImage,
        focusPeaking: Bool,
        falseColor: Bool,
        nikonCloudPreset: NikonCloudPreset? = nil
    ) -> ProfessionalMonitorResult {
        guard image.size.width > 0, image.size.height > 0 else {
            return empty(image)
        }
        let width = min(320, max(1, Int(image.size.width.rounded())))
        let height = max(
            1,
            Int((Double(width) * image.size.height / image.size.width).rounded())
        )
        var proposedRect = NSRect(origin: .zero, size: image.size)
        guard let source = image.cgImage(
            forProposedRect: &proposedRect,
            context: nil,
            hints: nil
        ) else {
            return empty(image)
        }
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return empty(image)
        }
        context.interpolationQuality = .low
        context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))

        var red = scopeBuffer()
        var green = scopeBuffer()
        var blue = scopeBuffer()
        var lumaScope = scopeBuffer()
        var cbScope = scopeBuffer()
        var crScope = scopeBuffer()
        var luminance = [Int](repeating: 0, count: width * height)

        for y in 0..<height {
            for x in 0..<width {
                let pixel = y * width + x
                let offset = pixel * 4
                var r = Int(pixels[offset])
                var g = Int(pixels[offset + 1])
                var b = Int(pixels[offset + 2])
                if let nikonCloudPreset {
                    let preview = nikonCloudPreset.applyingPreviewEffect(
                        red: Double(r) / 255,
                        green: Double(g) / 255,
                        blue: Double(b) / 255
                    )
                    r = clamp8(Int((preview.red * 255).rounded()))
                    g = clamp8(Int((preview.green * 255).rounded()))
                    b = clamp8(Int((preview.blue * 255).rounded()))
                    pixels[offset] = UInt8(r)
                    pixels[offset + 1] = UInt8(g)
                    pixels[offset + 2] = UInt8(b)
                    pixels[offset + 3] = 255
                }
                let luma = (54 * r + 183 * g + 19 * b) >> 8
                luminance[pixel] = luma
                let column = min(scopeColumns - 1, x * scopeColumns / max(1, width))
                accumulate(&red, column: column, value: r)
                accumulate(&green, column: column, value: g)
                accumulate(&blue, column: column, value: b)
                accumulate(&lumaScope, column: column, value: luma)
                let cb = clamp8(128 + ((-29 * r - 99 * g + 128 * b) >> 8))
                let cr = clamp8(128 + ((128 * r - 116 * g - 12 * b) >> 8))
                accumulate(&cbScope, column: column, value: cb)
                accumulate(&crScope, column: column, value: cr)
                if falseColor {
                    let color = falseColorRGB(luma)
                    pixels[offset] = color.0
                    pixels[offset + 1] = color.1
                    pixels[offset + 2] = color.2
                }
            }
        }

        var peakingPixels = 0
        if focusPeaking, width > 2, height > 2 {
            for y in 1..<(height - 1) {
                for x in 1..<(width - 1) {
                    let pixel = y * width + x
                    let horizontal = abs(
                        luminance[pixel - 1] - luminance[pixel + 1]
                    )
                    let vertical = abs(
                        luminance[pixel - width] - luminance[pixel + width]
                    )
                    if horizontal + vertical > 72 {
                        let offset = pixel * 4
                        pixels[offset] = 255
                        pixels[offset + 1] = 38
                        pixels[offset + 2] = 205
                        pixels[offset + 3] = 255
                        peakingPixels += 1
                    }
                }
            }
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let rendered = CGImage(
                  width: width,
                  height: height,
                  bitsPerComponent: 8,
                  bitsPerPixel: 32,
                  bytesPerRow: width * 4,
                  space: colorSpace,
                  bitmapInfo: CGBitmapInfo(
                      rawValue: CGImageAlphaInfo.premultipliedLast.rawValue
                  ),
                  provider: provider,
                  decode: nil,
                  shouldInterpolate: true,
                  intent: .defaultIntent
              ) else {
            return empty(image)
        }
        let output = NSImage(cgImage: rendered, size: image.size)
        return ProfessionalMonitorResult(
            image: output,
            redHistogram: densityMap(red),
            greenHistogram: densityMap(green),
            blueHistogram: densityMap(blue),
            waveform: densityMap(lumaScope),
            vectorscope: densityMap(cbScope) + "|" + densityMap(crScope),
            peakingCoverage: Int(
                (Double(peakingPixels) / Double(max(1, width * height)) * 100)
                    .rounded()
            )
        )
    }

    private static func scopeBuffer() -> [Int] {
        [Int](repeating: 0, count: scopeColumns * scopeRows)
    }

    private static func accumulate(_ buffer: inout [Int], column: Int, value: Int) {
        let row = scopeRows - 1 - clamp8(value) * (scopeRows - 1) / 255
        buffer[row * scopeColumns + column] += 1
    }

    private static func clamp8(_ value: Int) -> Int {
        min(255, max(0, value))
    }

    private static func densityMap(_ values: [Int]) -> String {
        let digits = Array("0123456789ABCDEF")
        let maximum = max(1, values.max() ?? 1)
        let divisor = log1p(Double(maximum))
        let payload = values.map { value -> Character in
            let level = Int((log1p(Double(value)) / divisor * 15).rounded())
            return digits[min(15, max(0, level))]
        }
        return "S\(scopeColumns)x\(scopeRows):" + String(payload)
    }

    private static func falseColorRGB(_ luma: Int) -> (UInt8, UInt8, UInt8) {
        switch luma {
        case ..<32: return (18, 24, 150)
        case ..<64: return (0, 150, 255)
        case ..<112: return (32, 205, 120)
        case ..<160: return (126, 126, 126)
        case ..<208: return (255, 205, 20)
        case ..<240: return (255, 92, 32)
        default: return (255, 32, 56)
        }
    }

    private static func empty(_ image: NSImage) -> ProfessionalMonitorResult {
        ProfessionalMonitorResult(
            image: image,
            redHistogram: "—",
            greenHistogram: "—",
            blueHistogram: "—",
            waveform: "—",
            vectorscope: "—",
            peakingCoverage: 0
        )
    }
}
