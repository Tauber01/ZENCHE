import AppKit
import CoreImage
import Foundation

struct ColorCubeLUT {
    enum LUTError: LocalizedError {
        case unreadable
        case unsupported1D
        case invalidSize
        case invalidDomain
        case invalidSample
        case invalidSampleCount(expected: Int, actual: Int)

        var errorDescription: String? {
            switch self {
            case .unreadable:
                return "无法读取这个 LUT；请确认它是 UTF-8 文本格式的 .cube 文件。"
            case .unsupported1D:
                return "当前只支持 3D .cube LUT。"
            case .invalidSize:
                return "LUT_3D_SIZE 必须在 2 到 64 之间。"
            case .invalidDomain:
                return "LUT 的 DOMAIN_MIN / DOMAIN_MAX 设置无效。"
            case .invalidSample:
                return "LUT 包含无法使用的颜色数值。"
            case .invalidSampleCount(let expected, let actual):
                return "LUT 数据不完整：需要 \(expected) 组颜色，实际读取到 \(actual) 组。"
            }
        }
    }

    let title: String
    let dimension: Int
    private let domainMin: SIMD3<Float>
    private let domainMax: SIMD3<Float>
    private let cubeData: Data

    init(contentsOf url: URL) throws {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            throw LUTError.unreadable
        }

        var parsedTitle = url.deletingPathExtension().lastPathComponent
        var parsedDimension: Int?
        var parsedDomainMin = SIMD3<Float>(repeating: 0)
        var parsedDomainMax = SIMD3<Float>(repeating: 1)
        var samples: [Float] = []

        for rawLine in text.split(whereSeparator: \.isNewline) {
            let line = rawLine
                .split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)[0]
                .trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }

            let fields = line.split(whereSeparator: \.isWhitespace)
            guard let command = fields.first else { continue }
            switch command.uppercased() {
            case "TITLE":
                let value = line.dropFirst(command.count).trimmingCharacters(in: .whitespaces)
                parsedTitle = value.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            case "LUT_1D_SIZE":
                throw LUTError.unsupported1D
            case "LUT_3D_SIZE":
                guard fields.count == 2,
                      let size = Int(fields[1]),
                      (2...64).contains(size)
                else {
                    throw LUTError.invalidSize
                }
                parsedDimension = size
                samples.reserveCapacity(size * size * size * 4)
            case "DOMAIN_MIN":
                guard let domain = Self.parseVector(fields) else {
                    throw LUTError.invalidDomain
                }
                parsedDomainMin = domain
            case "DOMAIN_MAX":
                guard let domain = Self.parseVector(fields) else {
                    throw LUTError.invalidDomain
                }
                parsedDomainMax = domain
            default:
                guard fields.count == 3,
                      let red = Float(fields[0]),
                      let green = Float(fields[1]),
                      let blue = Float(fields[2])
                else {
                    continue
                }
                samples.append(red)
                samples.append(green)
                samples.append(blue)
                samples.append(1)
            }
        }

        guard let dimension = parsedDimension else {
            throw LUTError.invalidSize
        }
        let expected = dimension * dimension * dimension
        let actual = samples.count / 4
        guard actual == expected else {
            throw LUTError.invalidSampleCount(expected: expected, actual: actual)
        }
        guard samples.allSatisfy(\.isFinite) else {
            throw LUTError.invalidSample
        }
        guard parsedDomainMax.x > parsedDomainMin.x,
              parsedDomainMax.y > parsedDomainMin.y,
              parsedDomainMax.z > parsedDomainMin.z,
              parsedDomainMin.x.isFinite,
              parsedDomainMin.y.isFinite,
              parsedDomainMin.z.isFinite,
              parsedDomainMax.x.isFinite,
              parsedDomainMax.y.isFinite,
              parsedDomainMax.z.isFinite
        else {
            throw LUTError.invalidDomain
        }

        title = parsedTitle.isEmpty ? url.deletingPathExtension().lastPathComponent : parsedTitle
        self.dimension = dimension
        domainMin = parsedDomainMin
        domainMax = parsedDomainMax
        cubeData = samples.withUnsafeBytes { Data($0) }
    }

    func applying(to image: NSImage) -> NSImage? {
        guard let inputImage = CIImage(data: image.tiffRepresentation ?? Data()) else {
            return nil
        }

        let range = domainMax - domainMin
        let scale = SIMD3<Float>(1 / range.x, 1 / range.y, 1 / range.z)
        let bias = -domainMin * scale

        let normalized = inputImage.applyingFilter(
            "CIColorMatrix",
            parameters: [
                "inputRVector": CIVector(x: CGFloat(scale.x), y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: CGFloat(scale.y), z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: CGFloat(scale.z), w: 0),
                "inputBiasVector": CIVector(
                    x: CGFloat(bias.x),
                    y: CGFloat(bias.y),
                    z: CGFloat(bias.z),
                    w: 0
                )
            ]
        )
        let output = normalized.applyingFilter(
            "CIColorCubeWithColorSpace",
            parameters: [
                "inputCubeDimension": dimension,
                "inputCubeData": cubeData,
                "inputColorSpace": CGColorSpace(name: CGColorSpace.sRGB) as Any
            ]
        )
        guard let cgImage = PreviewProcessor.context.createCGImage(output, from: output.extent) else {
            return nil
        }
        return NSImage(cgImage: cgImage, size: image.size)
    }

    private static func parseVector(_ fields: [Substring]) -> SIMD3<Float>? {
        guard fields.count == 4,
              let first = Float(fields[1]),
              let second = Float(fields[2]),
              let third = Float(fields[3])
        else {
            return nil
        }
        return SIMD3<Float>(first, second, third)
    }
}

enum PreviewProcessor {
    static let context = CIContext(options: [.cacheIntermediates: false])

    static func resampledImage(
        _ image: NSImage,
        fitting targetSize: NSSize,
        supersampling: Bool
    ) -> NSImage? {
        guard targetSize.width > 0,
              targetSize.height > 0,
              let input = CIImage(data: image.tiffRepresentation ?? Data()),
              input.extent.width > 0,
              input.extent.height > 0
        else {
            return nil
        }

        let fitScale = min(
            targetSize.width / input.extent.width,
            targetSize.height / input.extent.height
        )
        let firstScale = fitScale * (supersampling ? 2 : 1)
        let firstPass = input.applyingFilter(
            "CILanczosScaleTransform",
            parameters: [
                kCIInputScaleKey: firstScale,
                kCIInputAspectRatioKey: 1
            ]
        )
        let output = supersampling
            ? firstPass.applyingFilter(
                "CILanczosScaleTransform",
                parameters: [
                    kCIInputScaleKey: 0.5,
                    kCIInputAspectRatioKey: 1
                ]
            )
            : firstPass
        guard let rendered = context.createCGImage(output, from: output.extent) else {
            return nil
        }
        return NSImage(
            cgImage: rendered,
            size: NSSize(width: rendered.width, height: rendered.height)
        )
    }

    static func zebraMask(for image: NSImage, threshold: Double) -> NSImage? {
        guard image.size.width > 0, image.size.height > 0 else { return nil }
        let width = min(384, max(1, Int(image.size.width.rounded())))
        let height = max(1, Int((Double(width) * image.size.height / image.size.width).rounded()))
        var proposedRect = NSRect(origin: .zero, size: image.size)
        guard let sourceImage = image.cgImage(
            forProposedRect: &proposedRect,
            context: nil,
            hints: nil
        )
        else {
            return nil
        }
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        else {
            return nil
        }
        context.interpolationQuality = .low
        context.draw(sourceImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let limit = UInt8(max(0, min(255, Int((threshold * 2.55).rounded()))))
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                let red = Int(pixels[offset])
                let green = Int(pixels[offset + 1])
                let blue = Int(pixels[offset + 2])
                let luminance = UInt8((54 * red + 183 * green + 19 * blue) >> 8)
                let stripe = ((x + y) / 5).isMultiple(of: 2)
                if luminance >= limit && stripe {
                    pixels[offset] = 190
                    pixels[offset + 1] = 153
                    pixels[offset + 2] = 27
                    pixels[offset + 3] = 190
                } else {
                    pixels[offset] = 0
                    pixels[offset + 1] = 0
                    pixels[offset + 2] = 0
                    pixels[offset + 3] = 0
                }
            }
        }

        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let overlay = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              )
        else {
            return nil
        }
        return NSImage(cgImage: overlay, size: image.size)
    }
}
