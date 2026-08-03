@preconcurrency import AVFoundation
import AppKit
import Combine
import CoreImage
import Foundation

final class LocalCameraService: NSObject, ObservableObject,
    AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published private(set) var isConnected = false
    @Published private(set) var isLiveView = false
    @Published private(set) var deviceName = "本机摄像头"

    var onFrame: ((NSImage) -> Void)?
    var onJpegFrame: ((Data) -> Void)?
    var onMessage: ((String) -> Void)?

    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(
        label: "com.tauber.nikonlink.local-camera",
        qos: .userInitiated
    )
    private let frameQueue = DispatchQueue(
        label: "com.tauber.nikonlink.local-camera.frames",
        qos: .userInteractive
    )
    private let ciContext = CIContext(options: [.cacheIntermediates: false])
    private var currentDevice: AVCaptureDevice?
    private var photoDelegates: [Int64: LocalPhotoDelegate] = [:]
    private var lastFrameTime = Date.distantPast

    func connect(completion: @escaping (Result<String, Error>) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configure(completion: completion)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self else { return }
                if granted {
                    self.configure(completion: completion)
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(LocalCameraError.permissionDenied))
                    }
                }
            }
        default:
            DispatchQueue.main.async {
                completion(.failure(LocalCameraError.permissionDenied))
            }
        }
    }

    func disconnect() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning { self.session.stopRunning() }
            self.session.beginConfiguration()
            self.session.inputs.forEach(self.session.removeInput)
            self.session.outputs.forEach(self.session.removeOutput)
            self.session.commitConfiguration()
            self.currentDevice = nil
            DispatchQueue.main.async {
                self.isConnected = false
                self.isLiveView = false
                self.deviceName = "本机摄像头"
                self.onMessage?("本机摄像头已断开")
            }
        }
    }

    func startLiveView(completion: @escaping (Result<Void, Error>) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self, self.currentDevice != nil else {
                DispatchQueue.main.async {
                    completion(.failure(LocalCameraError.notConnected))
                }
                return
            }
            if !self.session.isRunning { self.session.startRunning() }
            DispatchQueue.main.async {
                self.isLiveView = self.session.isRunning
                if self.isLiveView {
                    completion(.success(()))
                } else {
                    completion(.failure(LocalCameraError.startFailed))
                }
            }
        }
    }

    func stopLiveView() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning { self.session.stopRunning() }
            DispatchQueue.main.async { self.isLiveView = false }
        }
    }

    func capture(completion: @escaping (Result<Data, Error>) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self, self.currentDevice != nil else {
                DispatchQueue.main.async {
                    completion(.failure(LocalCameraError.notConnected))
                }
                return
            }
            if !self.session.isRunning { self.session.startRunning() }
            let settings = AVCapturePhotoSettings()
            let id = settings.uniqueID
            let delegate = LocalPhotoDelegate { [weak self] result in
                DispatchQueue.main.async {
                    self?.photoDelegates[id] = nil
                    completion(result)
                }
            }
            DispatchQueue.main.sync { self.photoDelegates[id] = delegate }
            self.photoOutput.capturePhoto(with: settings, delegate: delegate)
        }
    }

    private func configure(
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            do {
                guard let device = Self.discoverDevices().first else {
                    throw LocalCameraError.noDevice
                }
                let input = try AVCaptureDeviceInput(device: device)
                self.session.beginConfiguration()
                defer { self.session.commitConfiguration() }
                self.session.inputs.forEach(self.session.removeInput)
                self.session.outputs.forEach(self.session.removeOutput)
                self.session.sessionPreset = .high
                guard self.session.canAddInput(input) else {
                    throw LocalCameraError.configurationFailed
                }
                self.session.addInput(input)
                self.videoOutput.alwaysDiscardsLateVideoFrames = true
                self.videoOutput.videoSettings = [
                    kCVPixelBufferPixelFormatTypeKey as String:
                        kCVPixelFormatType_32BGRA
                ]
                self.videoOutput.setSampleBufferDelegate(
                    self,
                    queue: self.frameQueue
                )
                guard self.session.canAddOutput(self.videoOutput),
                      self.session.canAddOutput(self.photoOutput) else {
                    throw LocalCameraError.configurationFailed
                }
                self.session.addOutput(self.videoOutput)
                self.session.addOutput(self.photoOutput)
                self.currentDevice = device
                DispatchQueue.main.async {
                    self.deviceName = device.localizedName
                    self.isConnected = true
                    self.isLiveView = false
                    self.onMessage?("\(device.localizedName) 已连接")
                    completion(.success(device.localizedName))
                }
            } catch {
                DispatchQueue.main.async {
                    self.isConnected = false
                    completion(.failure(error))
                }
            }
        }
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let now = Date()
        guard now.timeIntervalSince(lastFrameTime) >= 1.0 / 15.0,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        lastFrameTime = now
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = ciContext.createCGImage(image, from: image.extent) else {
            return
        }
        let nsImage = NSImage(
            cgImage: cgImage,
            size: NSSize(width: cgImage.width, height: cgImage.height)
        )
        if let jpeg = NSBitmapImageRep(cgImage: cgImage).representation(
            using: .jpeg,
            properties: [.compressionFactor: 0.9]
        ) {
            onJpegFrame?(jpeg)
        }
        DispatchQueue.main.async { [weak self] in self?.onFrame?(nsImage) }
    }

    private static func discoverDevices() -> [AVCaptureDevice] {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: [.external, .builtInWideAngleCamera],
            mediaType: .video,
            position: .unspecified
        ).devices.sorted { lhs, rhs in
            let lhsBuiltIn = lhs.position != .unspecified
            let rhsBuiltIn = rhs.position != .unspecified
            if lhsBuiltIn != rhsBuiltIn { return lhsBuiltIn }
            return lhs.localizedName.localizedStandardCompare(rhs.localizedName)
                == .orderedAscending
        }
    }
}

private final class LocalPhotoDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (Result<Data, Error>) -> Void

    init(completion: @escaping (Result<Data, Error>) -> Void) {
        self.completion = completion
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error {
            completion(.failure(error))
        } else if let data = photo.fileDataRepresentation() {
            completion(.success(data))
        } else {
            completion(.failure(LocalCameraError.noPhotoData))
        }
    }
}

private enum LocalCameraError: LocalizedError {
    case permissionDenied
    case noDevice
    case notConnected
    case configurationFailed
    case startFailed
    case noPhotoData

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "未获得相机权限；请在系统设置 → 隐私与安全性 → 相机中允许 帧澈 ZENCHE"
        case .noDevice: return "没有检测到可用的本机摄像头"
        case .notConnected: return "请先连接本机摄像头"
        case .configurationFailed: return "无法配置本机摄像头采集会话"
        case .startFailed: return "本机摄像头未能开始取景"
        case .noPhotoData: return "本机摄像头没有返回照片数据"
        }
    }
}
