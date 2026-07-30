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
    private static let bars = Array("▁▂▃▄▅▆▇█")

    static func process(
        _ image: NSImage,
        focusPeaking: Bool,
        falseColor: Bool
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

        var red = [Int](repeating: 0, count: 16)
        var green = [Int](repeating: 0, count: 16)
        var blue = [Int](repeating: 0, count: 16)
        var waveformSum = [Int](repeating: 0, count: 24)
        var waveformCount = [Int](repeating: 0, count: 24)
        var hueSum = [Int](repeating: 0, count: 24)
        var hueCount = [Int](repeating: 0, count: 24)
        var luminance = [Int](repeating: 0, count: width * height)

        for y in 0..<height {
            for x in 0..<width {
                let pixel = y * width + x
                let offset = pixel * 4
                let r = Int(pixels[offset])
                let g = Int(pixels[offset + 1])
                let b = Int(pixels[offset + 2])
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
                    let hue = hueIndex(r: r, g: g, b: b, maximum: maximum, delta: saturation)
                    hueSum[hue] += saturation
                    hueCount[hue] += 1
                }
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
        let waveform = zip(waveformSum, waveformCount).map {
            $0.1 == 0 ? 0 : $0.0 / $0.1
        }
        let vectorscope = zip(hueSum, hueCount).map {
            $0.1 == 0 ? 0 : $0.0 / $0.1
        }
        return ProfessionalMonitorResult(
            image: output,
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
        let positive = normalized < 0 ? normalized + 360 : normalized
        return min(23, Int(positive / 15))
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
