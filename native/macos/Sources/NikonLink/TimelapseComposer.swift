import AVFoundation
import CoreGraphics
import CoreVideo
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// E6 延时合成：把序列帧（JPEG/PNG/HEIC/TIFF）按帧率编码为 H.264 MP4
/// （Apple 双端可选 ProRes 422）。逐帧解码 → 统一画布 → 原生编码器写帧。
/// 损坏帧跳过并计数，不整批失败；进度回调 + 取消检查。
/// TBC-awaiting-hardware（编码器行为依赖系统，需实机验证）。
struct TimelapseComposer {

    enum Codec: String, CaseIterable, Identifiable {
        case h264 = "H.264"
        case proRes = "ProRes 422"

        var id: String { rawValue }

        var fileType: AVFileType {
            self == .h264 ? .mp4 : .mov
        }

        var outputExtension: String {
            self == .h264 ? "mp4" : "mov"
        }

        fileprivate var avCodec: AVVideoCodecType {
            self == .h264 ? .h264 : .proRes422
        }
    }

    struct Options {
        var frameRate: Int = 24 // 24/25/30
        var codec: Codec = .h264
    }

    struct Result {
        let url: URL
        let framesWritten: Int
        let skippedFrames: Int
    }

    /// 逐帧合成。`isCancelled` 返回 true 时中止并抛 CancellationError；
    /// `onProgress` 报告 (已处理帧数, 总帧数)。
    func compose(
        frames: [URL],
        to outputURL: URL,
        options: Options,
        isCancelled: @escaping () -> Bool,
        onProgress: @escaping (Int, Int) -> Void
    ) async throws -> Result {
        guard let first = frames.first else {
            throw TimelapseError.emptySelection
        }
        let fps = max(1, min(60, options.frameRate))
        // 首帧尺寸作为统一画布（延时连拍帧同尺寸；异尺寸按 aspect-fit 黑底绘制）。
        let canvas = try decodeSize(of: first)
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: options.codec.fileType)
        let settings: [String: Any] = [
            AVVideoCodecKey: options.codec.avCodec,
            AVVideoWidthKey: canvas.width,
            AVVideoHeightKey: canvas.height
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String:
                    kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey as String: canvas.width,
                kCVPixelBufferHeightKey as String: canvas.height
            ]
        )
        guard writer.canAdd(input) else {
            throw TimelapseError.encoderUnavailable
        }
        writer.add(input)
        guard writer.startWriting() else {
            throw TimelapseError.encoderUnavailable
        }
        writer.startSession(atSourceTime: .zero)

        var written = 0
        var skipped = 0
        let timescale = CMTimeScale(fps)
        for (index, frameURL) in frames.enumerated() {
            if isCancelled() {
                input.markAsFinished()
                await writer.finishWriting()
                try? FileManager.default.removeItem(at: outputURL)
                throw CancellationError()
            }
            // 编码器背压：忙等至可继续写（上限 20s），期间响应取消。
            if !input.isReadyForMoreMediaData {
                var waited = 0
                while !input.isReadyForMoreMediaData && !isCancelled() {
                    try? await Task.sleep(nanoseconds: 10_000_000)
                    waited += 1
                    if waited > 2000 { // 20s 上限
                        break
                    }
                }
                if isCancelled() {
                    input.markAsFinished()
                    await writer.finishWriting()
                    try? FileManager.default.removeItem(at: outputURL)
                    throw CancellationError()
                }
            }
            if let pixelBuffer = decodeFrame(frameURL, canvas: canvas) {
                let presentationTime = CMTime(
                    value: CMTimeValue(written),
                    timescale: timescale
                )
                if adaptor.append(pixelBuffer, withPresentationTime: presentationTime) {
                    written += 1
                } else {
                    skipped += 1
                }
            } else {
                skipped += 1
            }
            onProgress(index + 1, frames.count)
        }
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else {
            throw TimelapseError.encodingFailed(writer.error?.localizedDescription ?? "unknown")
        }
        return Result(url: outputURL, framesWritten: written, skippedFrames: skipped)
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
            throw TimelapseError.undecodableFrame(url.lastPathComponent)
        }
        return CGSize(width: width, height: height)
    }

    /// 解码单帧并绘制到统一画布（aspect-fit 黑底）。失败返回 nil（跳过计数）。
    private func decodeFrame(_ url: URL, canvas: CGSize) -> CVPixelBuffer? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }
        var pixelBuffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ]
        guard CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(canvas.width),
            Int(canvas.height),
            kCVPixelFormatType_32ARGB,
            attributes as CFDictionary,
            &pixelBuffer
        ) == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: Int(canvas.width),
            height: Int(canvas.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue |
                CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            return nil
        }
        context.setFillColor(
            CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1)
        )
        context.fill(CGRect(x: 0, y: 0, width: canvas.width, height: canvas.height))
        // aspect-fit：等比缩放并居中。
        let scale = min(canvas.width / CGFloat(image.width),
                        canvas.height / CGFloat(image.height))
        let fitted = CGSize(width: CGFloat(image.width) * scale,
                            height: CGFloat(image.height) * scale)
        context.draw(
            image,
            in: CGRect(
                x: (canvas.width - fitted.width) / 2,
                y: (canvas.height - fitted.height) / 2,
                width: fitted.width,
                height: fitted.height
            )
        )
        return buffer
    }
}

enum TimelapseError: LocalizedError {
    case emptySelection
    case undecodableFrame(String)
    case encoderUnavailable
    case encodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .emptySelection:
            return "请至少选择一帧。"
        case .undecodableFrame(let name):
            return "无法解码帧 \(name)，已跳过。"
        case .encoderUnavailable:
            return "系统编码器不可用。"
        case .encodingFailed(let detail):
            return "视频编码失败：\(detail)"
        }
    }
}
