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
    private static let bars = Array("▁▂▃▄▅▆▇█")

    static func process(
        _ pixelBuffer: CVPixelBuffer,
        focusPeaking: Bool,
        falseColor: Bool
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
        var red = [Int](repeating: 0, count: 16)
        var green = [Int](repeating: 0, count: 16)
        var blue = [Int](repeating: 0, count: 16)
        var waveformSum = [Int](repeating: 0, count: 24)
        var waveformCount = [Int](repeating: 0, count: 24)
        var hueSum = [Int](repeating: 0, count: 24)
        var hueCount = [Int](repeating: 0, count: 24)

        for y in 0..<height {
            let sourceY = min(sourceHeight - 1, y * sourceHeight / height)
            for x in 0..<width {
                let sourceX = min(sourceWidth - 1, x * sourceWidth / width)
                let sourceOffset = sourceY * sourceBytesPerRow + sourceX * 4
                let pixel = y * width + x
                let outputOffset = pixel * 4
                let b = Int(sourcePixels[sourceOffset])
                let g = Int(sourcePixels[sourceOffset + 1])
                let r = Int(sourcePixels[sourceOffset + 2])
                let luma = (54 * r + 183 * g + 19 * b) >> 8
                luminance[pixel] = luma
                red[min(15, r >> 4)] += 1
                green[min(15, g >> 4)] += 1
                blue[min(15, b >> 4)] += 1
                let column = min(23, x * 24 / max(1, width))
                waveformSum[column] += luma
                waveformCount[column] += 1
                let maximum = max(r, max(g, b))
                let minimum = min(r, min(g, b))
                let saturation = maximum - minimum
                if saturation > 8 {
                    let hue = hueIndex(
                        r: r,
                        g: g,
                        b: b,
                        maximum: maximum,
                        delta: saturation
                    )
                    hueSum[hue] += saturation
                    hueCount[hue] += 1
                }
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

        let waveform = zip(waveformSum, waveformCount).map {
            $0.1 == 0 ? 0 : $0.0 / $0.1
        }
        let vectorscope = zip(hueSum, hueCount).map {
            $0.1 == 0 ? 0 : $0.0 / $0.1
        }
        return ProfessionalMonitorResult(
            overlay: focusPeaking || falseColor
                ? makeImage(pixels: pixels, width: width, height: height)
                : nil,
            redHistogram: sparkline(red),
            greenHistogram: sparkline(green),
            blueHistogram: sparkline(blue),
            waveform: sparkline(waveform),
            vectorscope: sparkline(vectorscope),
            peakingCoverage: Int(
                (Double(peakingPixels) / Double(max(1, width * height)) * 100)
                    .rounded()
            )
        )
    }

    private static func hueIndex(
        r: Int,
        g: Int,
        b: Int,
        maximum: Int,
        delta: Int
    ) -> Int {
        let hue: Double
        if maximum == r {
            hue = Double(g - b) / Double(delta)
        } else if maximum == g {
            hue = 2 + Double(b - r) / Double(delta)
        } else {
            hue = 4 + Double(r - g) / Double(delta)
        }
        let normalized = (hue * 60).truncatingRemainder(dividingBy: 360)
        return min(23, Int((normalized < 0 ? normalized + 360 : normalized) / 15))
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

    private static func sparkline(_ values: [Int]) -> String {
        let maximum = max(1, values.max() ?? 1)
        return String(values.map {
            bars[min(bars.count - 1, $0 * (bars.count - 1) / maximum)]
        })
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
