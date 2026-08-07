import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// E7 焦点包围合成：把不同对焦距离的序列帧合成一张全清晰 JPEG。
/// 算法（五端同构，纯 CPU 逐像素）：
///   1. 全局亮度归一——以首帧平均亮度为基准，每帧 scale = clamp(mean0/mean_i, 0.5, 2.0)
///      （手持微抖/曝光微差的包围帧亮度归一；亚像素位移对齐工程量过大，列入 backlog）。
///   2. 清晰度测度——3×3 拉普拉斯核（全 8 邻域中心 8）作用于归一亮度，取绝对响应。
///   3. 逐像素融合——取 |lap| 最大帧的 RGB（×scale 归一），边界 1px 取首帧。
/// 内存优化：两遍式逐帧融合，峰值仅 2 帧 RGBA + 全局 best 数组（不保留全部帧）。
/// 损坏帧跳过并计数，不整批失败；进度回调 + 取消检查。
/// TBC-awaiting-hardware（合成结果依赖真实包围序列，需实机验证）。
struct FocusStackComposer {

    struct Result {
        let url: URL
        /// 参与融合的成功帧数（≥2 才输出）。
        let sourcesUsed: Int
        let skippedFrames: Int
    }

    /// 逐帧合成。`isCancelled` 返回 true 时中止并抛 CancellationError；
    /// `onProgress` 报告 (已处理帧数, 总帧数)。
    func compose(
        frames: [URL],
        to outputURL: URL,
        isCancelled: @escaping () -> Bool,
        onProgress: @escaping (Int, Int) -> Void
    ) async throws -> Result {
        guard let first = frames.first else {
            throw FocusStackError.emptySelection
        }
        // 首帧尺寸作为统一画布（包围帧同尺寸；异尺寸按 aspect-fit 黑底绘制）。
        let canvas = try decodeSize(of: first)
        let width = Int(canvas.width)
        let height = Int(canvas.height)

        var skipped = 0
        var bestRGB = [UInt8](repeating: 0, count: width * height * 3)
        var bestLap = [Float](repeating: -1, count: width * height)
        var sourcesUsed = 0
        var referenceMean: Float = 0

        for (index, frameURL) in frames.enumerated() {
            if isCancelled() {
                throw CancellationError()
            }
            guard let rgba = decodeFrameToRGBA(frameURL, width: width, height: height) else {
                skipped += 1
                onProgress(index + 1, frames.count)
                continue
            }
            // 亮度（BT.601 全范围整数近似）+ 平均亮度。
            var luminance = [Float](repeating: 0, count: width * height)
            var sum: Float = 0
            for pixel in 0..<(width * height) {
                let offset = pixel * 4
                let r = Float(rgba[offset])
                let g = Float(rgba[offset + 1])
                let b = Float(rgba[offset + 2])
                let y = (77 * r + 150 * g + 29 * b) / 255.0
                luminance[pixel] = y
                sum += y
            }
            let mean = sum / Float(width * height)

            if sourcesUsed == 0 {
                // 首帧：作为融合基准（scale=1），平均亮度作为归一基准。
                referenceMean = mean
                for pixel in 0..<(width * height) {
                    let offset = pixel * 4
                    bestRGB[pixel * 3] = rgba[offset]
                    bestRGB[pixel * 3 + 1] = rgba[offset + 1]
                    bestRGB[pixel * 3 + 2] = rgba[offset + 2]
                }
                // 内圈 3×3 拉普拉斯响应；边界保持 -1（融合阶段取首帧）。
                for y in 1..<(height - 1) {
                    for x in 1..<(width - 1) {
                        let p = y * width + x
                        let lap = abs(
                            8 * luminance[p]
                            - luminance[p - width] - luminance[p + width]
                            - luminance[p - 1] - luminance[p + 1]
                            - luminance[p - width - 1] - luminance[p - width + 1]
                            - luminance[p + width - 1] - luminance[p + width + 1]
                        )
                        bestLap[p] = lap
                    }
                }
            } else {
                // 亮度归一（手持微抖/曝光微差）。
                let scale = min(2.0, max(0.5, mean == 0 ? 1.0 : (referenceMean / mean)))
                var normalized = [Float](repeating: 0, count: width * height)
                for pixel in 0..<(width * height) {
                    normalized[pixel] = luminance[pixel] * scale
                }
                // 逐像素取清晰度最高帧；边界像素不更新（保留首帧）。
                for y in 1..<(height - 1) {
                    for x in 1..<(width - 1) {
                        let p = y * width + x
                        let lap = abs(
                            8 * normalized[p]
                            - normalized[p - width] - normalized[p + width]
                            - normalized[p - 1] - normalized[p + 1]
                            - normalized[p - width - 1] - normalized[p - width + 1]
                            - normalized[p + width - 1] - normalized[p + width + 1]
                        )
                        if lap > bestLap[p] {
                            bestLap[p] = lap
                            let offset = p * 4
                            bestRGB[p * 3] = clampByte(Float(rgba[offset]) * scale)
                            bestRGB[p * 3 + 1] = clampByte(Float(rgba[offset + 1]) * scale)
                            bestRGB[p * 3 + 2] = clampByte(Float(rgba[offset + 2]) * scale)
                        }
                    }
                }
            }
            sourcesUsed += 1
            onProgress(index + 1, frames.count)
        }

        guard sourcesUsed >= 2 else {
            throw FocusStackError.notEnoughFrames(sourcesUsed)
        }

        // 合成图 → JPEG 写出。
        guard let image = makeJPEG(rgb: bestRGB, width: width, height: height) else {
            throw FocusStackError.encodeFailed
        }
        try image.write(to: outputURL, options: .atomic)
        return Result(url: outputURL, sourcesUsed: sourcesUsed, skippedFrames: skipped)
    }

    // MARK: - 帧解码

    private func decodeSize(of url: URL) throws -> CGSize {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(
                  source, 0, nil
              ) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0 else {
            throw FocusStackError.undecodableFrame(url.lastPathComponent)
        }
        return CGSize(width: width, height: height)
    }

    /// 解码单帧并绘制到统一画布（aspect-fit 黑底），返回 RGBA8888。失败返回 nil。
    private func decodeFrameToRGBA(
        _ url: URL,
        width: Int,
        height: Int
    ) -> [UInt8]? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &rgba,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue |
                CGBitmapInfo.byteOrder32Big.rawValue
        ) else {
            return nil
        }
        context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        // aspect-fit：等比缩放并居中。
        let scale = min(CGFloat(width) / CGFloat(image.width),
                        CGFloat(height) / CGFloat(image.height))
        let fitted = CGSize(width: CGFloat(image.width) * scale,
                            height: CGFloat(image.height) * scale)
        context.draw(
            image,
            in: CGRect(
                x: (CGFloat(width) - fitted.width) / 2,
                y: (CGFloat(height) - fitted.height) / 2,
                width: fitted.width,
                height: fitted.height
            )
        )
        return rgba
    }

    // MARK: - JPEG 写出

    private func makeJPEG(rgb: [UInt8], width: Int, height: Int) -> Data? {
        guard let provider = CGDataProvider(
            data: Data(rgb) as CFData
        ) else {
            return nil
        }
        guard let image = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 24,
            bytesPerRow: width * 3,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        ) else {
            return nil
        }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data, UTType.jpeg.identifier as CFString, 1, nil
        ) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, [
            kCGImageDestinationLossyCompressionQuality: 0.92
        ] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        return data as Data
    }

    private func clampByte(_ value: Float) -> UInt8 {
        UInt8(max(0, min(255, value.rounded())))
    }
}

enum FocusStackError: LocalizedError {
    case emptySelection
    case undecodableFrame(String)
    case notEnoughFrames(Int)
    case encodeFailed

    var errorDescription: String? {
        switch self {
        case .emptySelection:
            return "请至少选择一帧。"
        case .undecodableFrame(let name):
            return "无法解码帧 \\(name)，已跳过。"
        case .notEnoughFrames(let used):
            return "可合成帧不足（成功解码 \\(used) 帧，焦点合成需要至少 2 帧）。"
        case .encodeFailed:
            return "合成图编码失败。"
        }
    }
}
