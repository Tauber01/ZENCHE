import CoreGraphics
import CoreVideo
import Foundation

struct ProfessionalMonitorResult {
    let overlay: CGImage?
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
        _ pixelBuffer: CVPixelBuffer,
        focusPeaking: Bool,
        falseColor: Bool,
        nikonCloudPreset: NikonCloudPreset? = nil
    ) -> ProfessionalMonitorResult {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        guard CVPixelBufferGetPixelFormatType(pixelBuffer) == kCVPixelFormatType_32BGRA,
              let source = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return empty()
        }

        let sourceWidth = CVPixelBufferGetWidth(pixelBuffer)
        let sourceHeight = CVPixelBufferGetHeight(pixelBuffer)
        let sourceBytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let width = min(320, sourceWidth)
        let height = max(1, width * sourceHeight / max(1, sourceWidth))
        let sourcePixels = source.assumingMemoryBound(to: UInt8.self)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        var luminance = [Int](repeating: 0, count: width * height)
        var red = scopeBuffer()
        var green = scopeBuffer()
        var blue = scopeBuffer()
        var lumaScope = scopeBuffer()
        var cbScope = scopeBuffer()
        var crScope = scopeBuffer()

        for y in 0..<height {
            let sourceY = min(sourceHeight - 1, y * sourceHeight / height)
            for x in 0..<width {
                let sourceX = min(sourceWidth - 1, x * sourceWidth / width)
                let sourceOffset = sourceY * sourceBytesPerRow + sourceX * 4
                let pixel = y * width + x
                let outputOffset = pixel * 4
                var b = Int(sourcePixels[sourceOffset])
                var g = Int(sourcePixels[sourceOffset + 1])
                var r = Int(sourcePixels[sourceOffset + 2])
                if let nikonCloudPreset {
                    let preview = nikonCloudPreset.applyingPreviewEffect(
                        red: Double(r) / 255,
                        green: Double(g) / 255,
                        blue: Double(b) / 255
                    )
                    r = clamp8(Int((preview.red * 255).rounded()))
                    g = clamp8(Int((preview.green * 255).rounded()))
                    b = clamp8(Int((preview.blue * 255).rounded()))
                    pixels[outputOffset] = UInt8(r)
                    pixels[outputOffset + 1] = UInt8(g)
                    pixels[outputOffset + 2] = UInt8(b)
                    pixels[outputOffset + 3] = 255
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
                    pixels[outputOffset] = color.0
                    pixels[outputOffset + 1] = color.1
                    pixels[outputOffset + 2] = color.2
                    pixels[outputOffset + 3] = 255
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

        return ProfessionalMonitorResult(
            overlay: focusPeaking || falseColor || nikonCloudPreset != nil
                ? makeImage(pixels: pixels, width: width, height: height)
                : nil,
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

    private static func makeImage(
        pixels: [UInt8],
        width: Int,
        height: Int
    ) -> CGImage? {
        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else {
            return nil
        }
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(
                rawValue: CGImageAlphaInfo.premultipliedLast.rawValue
            ),
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    }

    private static func empty() -> ProfessionalMonitorResult {
        ProfessionalMonitorResult(
            overlay: nil,
            redHistogram: "—",
            greenHistogram: "—",
            blueHistogram: "—",
            waveform: "—",
            vectorscope: "—",
            peakingCoverage: 0
        )
    }
}
