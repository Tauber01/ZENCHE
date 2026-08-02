@preconcurrency import AVFoundation
import Foundation

enum CameraConnectionState: Equatable {
    case disconnected
    case connecting
    case ready
    case failed(String)

    var title: String {
        switch self {
        case .disconnected: return "未连接"
        case .connecting: return "正在连接"
        case .ready: return "已连接"
        case .failed: return "连接异常"
        }
    }
}

struct CameraDeviceOption: Identifiable, Equatable {
    let id: String
    let name: String
    let position: AVCaptureDevice.Position
    let isExternal: Bool

    var detail: String {
        if isExternal { return "外接视频设备" }
        switch position {
        case .front: return "前置镜头"
        case .back: return "后置镜头"
        default: return "本机镜头"
        }
    }
}

enum MonitorVideoCodec: String, CaseIterable, Identifiable {
    case automatic
    case h264
    case hevc

    var id: String { rawValue }

    var label: String {
        switch self {
        case .automatic: return "自动（输出目标）"
        case .h264: return "H.264 / AVC"
        case .hevc: return "H.265 / HEVC"
        }
    }
}

enum MonitorVideoSpec: String, CaseIterable, Identifiable {
    case automatic
    case hd720p60
    case hd1080p30
    case hd1080p60
    case uhd2160p30

    var id: String { rawValue }

    var label: String {
        switch self {
        case .automatic: return "自动 · 设备最佳"
        case .hd720p60: return "1280 × 720 · 60p"
        case .hd1080p30: return "1920 × 1080 · 30p"
        case .hd1080p60: return "1920 × 1080 · 60p"
        case .uhd2160p30: return "3840 × 2160 · 30p"
        }
    }

    var dimensions: CMVideoDimensions? {
        switch self {
        case .automatic: return nil
        case .hd720p60: return CMVideoDimensions(width: 1280, height: 720)
        case .hd1080p30, .hd1080p60:
            return CMVideoDimensions(width: 1920, height: 1080)
        case .uhd2160p30: return CMVideoDimensions(width: 3840, height: 2160)
        }
    }

    var frameRate: Double? {
        switch self {
        case .automatic: return nil
        case .hd720p60, .hd1080p60: return 60
        case .hd1080p30, .uhd2160p30: return 30
        }
    }
}

final class CameraService: NSObject, ObservableObject, AVCaptureFileOutputRecordingDelegate,
    AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published private(set) var state: CameraConnectionState = .disconnected
    @Published private(set) var deviceName = "未选择相机"
    @Published private(set) var availableDevices: [CameraDeviceOption] = []
    @Published private(set) var selectedDeviceID: String?
    @Published private(set) var isExternalCamera = false
    @Published private(set) var supportsFocusPoint = false
    @Published private(set) var supportsExposureBias = false
    @Published private(set) var supportsCustomExposure = false
    @Published private(set) var exposureModeIsCustom = false
    @Published private(set) var minExposureBias: Float = -2
    @Published private(set) var maxExposureBias: Float = 2
    @Published private(set) var minISO: Float = 100
    @Published private(set) var maxISO: Float = 800
    @Published private(set) var lensAperture: Float = 0
    @Published private(set) var activeFrameRate: Double = 30
    @Published private(set) var maxZoomFactor: CGFloat = 1
    @Published private(set) var activeVideoSpecLabel = "—"
    @Published private(set) var supportsMovieRecording = false
    @Published private(set) var isRecording = false
    @Published var exposureBias: Float = 0
    @Published var exposureISO: Float = 100
    @Published var shutterAngle: Double = 180
    @Published var zoomFactor: CGFloat = 1
    @Published private(set) var monitorOverlay: CGImage?
    @Published private(set) var redHistogram = "—"
    @Published private(set) var greenHistogram = "—"
    @Published private(set) var blueHistogram = "—"
    @Published private(set) var waveform = "—"
    @Published private(set) var vectorscope = "—"
    @Published private(set) var peakingCoverage = 0
    @Published private(set) var focusPeakingEnabled = false
    @Published private(set) var falseColorEnabled = false

    let session = AVCaptureSession()
    var onPhotoCaptured: ((Data, String) -> Void)?
    var onVideoRecorded: ((URL) -> Void)?
    var onMessage: ((String) -> Void)?

    private let sessionQueue = DispatchQueue(label: "com.tauber.nikonlink.camera")
    private let photoOutput = AVCapturePhotoOutput()
    private let movieOutput = AVCaptureMovieFileOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let monitorQueue = DispatchQueue(
        label: "com.tauber.nikonlink.professional-monitor",
        qos: .userInitiated
    )
    private var currentDevice: AVCaptureDevice?
    private var captureDelegates: [Int64: PhotoCaptureDelegate] = [:]
    private var shouldResumeSession = false
    private var lastMonitorFrameTime = CFAbsoluteTimeGetCurrent()
    private var lastExposureReadoutTime = CFAbsoluteTimeGetCurrent()

    override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(deviceDisconnected(_:)),
            name: AVCaptureDevice.wasDisconnectedNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(deviceConnected(_:)),
            name: AVCaptureDevice.wasConnectedNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionInterrupted(_:)),
            name: AVCaptureSession.wasInterruptedNotification,
            object: session
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionInterruptionEnded(_:)),
            name: AVCaptureSession.interruptionEndedNotification,
            object: session
        )
        refreshDevices()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func refreshDevices() {
        let options = Self.discoverDevices().map(Self.option(for:))
        DispatchQueue.main.async { [weak self] in
            self?.availableDevices = options
        }
    }

    func connect(deviceID: String? = nil) {
        updateState(.connecting, message: "正在请求相机权限…")

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureSession(deviceID: deviceID)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self else { return }
                if granted {
                    self.configureSession(deviceID: deviceID)
                } else {
                    self.updateState(.failed("相机权限被拒绝"), message: "请在系统设置中允许相机访问")
                }
            }
        case .denied, .restricted:
            updateState(.failed("相机权限不可用"), message: "请在系统设置中允许相机访问")
        @unknown default:
            updateState(.failed("未知权限状态"), message: "无法确认相机权限")
        }
    }

    func disconnect() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
            self.session.beginConfiguration()
            self.session.inputs.forEach(self.session.removeInput)
            self.session.outputs.forEach(self.session.removeOutput)
            self.session.commitConfiguration()
            self.currentDevice = nil
            self.shouldResumeSession = false
            DispatchQueue.main.async {
                self.deviceName = "未选择相机"
                self.selectedDeviceID = nil
                self.isExternalCamera = false
                self.supportsFocusPoint = false
                self.supportsExposureBias = false
                self.supportsCustomExposure = false
                self.exposureModeIsCustom = false
                self.supportsMovieRecording = false
                self.isRecording = false
                self.state = .disconnected
                self.onMessage?("相机已断开")
            }
        }
    }

    func suspend() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.shouldResumeSession = self.currentDevice != nil
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    func resume() {
        sessionQueue.async { [weak self] in
            guard let self,
                  self.shouldResumeSession,
                  self.currentDevice != nil,
                  !self.session.isRunning else {
                return
            }
            self.session.startRunning()
            self.shouldResumeSession = false
            self.updateState(.ready, message: "相机预览已恢复")
        }
    }

    func capturePhoto() {
        sessionQueue.async { [weak self] in
            guard let self, self.currentDevice != nil, self.session.isRunning else {
                self?.onMessage?("请先连接可用相机")
                return
            }

            let settings: AVCapturePhotoSettings
            let fileExtension: String
            if self.photoOutput.availablePhotoCodecTypes.contains(.jpeg) {
                settings = AVCapturePhotoSettings(
                    format: [AVVideoCodecKey: AVVideoCodecType.jpeg]
                )
                fileExtension = "jpg"
            } else {
                settings = AVCapturePhotoSettings()
                fileExtension = "heic"
            }
            settings.photoQualityPrioritization = .quality

            let uniqueID = settings.uniqueID
            let delegate = PhotoCaptureDelegate(fileExtension: fileExtension) { [weak self] result in
                guard let self else { return }
                self.sessionQueue.async {
                    self.captureDelegates[uniqueID] = nil
                }
                switch result {
                case .success(let payload):
                    self.onPhotoCaptured?(payload.data, payload.fileExtension)
                case .failure(let error):
                    self.onMessage?("拍摄失败：\(error.localizedDescription)")
                }
            }
            self.captureDelegates[uniqueID] = delegate
            self.photoOutput.capturePhoto(with: settings, delegate: delegate)
            self.onMessage?("正在拍摄…")
        }
    }

    func toggleVideoRecording() {
        isRecording ? stopVideoRecording() : startVideoRecording()
    }

    func startVideoRecording() {
        sessionQueue.async { [weak self] in
            guard let self,
                  self.currentDevice != nil,
                  self.session.isRunning,
                  self.session.outputs.contains(where: { $0 === self.movieOutput })
            else {
                self?.onMessage?("当前视频设备不支持录制")
                return
            }
            guard !self.movieOutput.isRecording else { return }

            let folder = FileManager.default.temporaryDirectory
                .appendingPathComponent("NikonLinkRecording", isDirectory: true)
            do {
                try FileManager.default.createDirectory(
                    at: folder,
                    withIntermediateDirectories: true
                )
                let target = folder
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("mov")
                try? FileManager.default.removeItem(at: target)
                self.movieOutput.startRecording(
                    to: target,
                    recordingDelegate: self
                )
                DispatchQueue.main.async {
                    self.isRecording = true
                    self.onMessage?("视频录制中 · 再按一次停止")
                }
            } catch {
                self.onMessage?("开始录制失败：\(error.localizedDescription)")
            }
        }
    }

    func stopVideoRecording() {
        sessionQueue.async { [weak self] in
            guard let self, self.movieOutput.isRecording else { return }
            self.movieOutput.stopRecording()
            self.onMessage?("正在停止并保存视频…")
        }
    }

    func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isRecording = false
            if let error {
                try? FileManager.default.removeItem(at: outputFileURL)
                self.onMessage?("视频录制失败：\(error.localizedDescription)")
                return
            }
            self.onVideoRecorded?(outputFileURL)
        }
    }

    func setExposureBias(_ value: Float) {
        sessionQueue.async { [weak self] in
            guard let self, let device = self.currentDevice else { return }
            let clamped = min(max(value, device.minExposureTargetBias), device.maxExposureTargetBias)
            do {
                try device.lockForConfiguration()
                device.setExposureTargetBias(clamped, completionHandler: nil)
                device.unlockForConfiguration()
                DispatchQueue.main.async {
                    self.exposureBias = clamped
                }
            } catch {
                self.onMessage?("曝光补偿设置失败：\(error.localizedDescription)")
            }
        }
    }

    func setVideoShutterAngle(_ value: Double) {
        applyVideoExposure(shutterAngle: value, iso: exposureISO)
    }

    func setVideoISO(_ value: Float) {
        applyVideoExposure(shutterAngle: shutterAngle, iso: value)
    }

    func setTimedExposure(seconds: Double) {
        sessionQueue.async { [weak self] in
            guard let self, let device = self.currentDevice else { return }
            guard device.isExposureModeSupported(.custom) else {
                self.onMessage?("当前视频设备不支持计时曝光")
                return
            }
            let minimum = CMTimeGetSeconds(
                device.activeFormat.minExposureDuration
            )
            let maximum = CMTimeGetSeconds(
                device.activeFormat.maxExposureDuration
            )
            let applied = min(max(seconds, minimum), maximum)
            do {
                try device.lockForConfiguration()
                device.setExposureModeCustom(
                    duration: CMTimeMakeWithSeconds(
                        applied,
                        preferredTimescale: 1_000_000_000
                    ),
                    iso: min(
                        max(device.iso, device.activeFormat.minISO),
                        device.activeFormat.maxISO
                    ),
                    completionHandler: nil
                )
                device.unlockForConfiguration()
                self.onMessage?(
                    String(format: "计时曝光已设置 · %.2f 秒", applied)
                )
            } catch {
                self.onMessage?("计时曝光设置失败：\(error.localizedDescription)")
            }
        }
    }

    private func applyVideoExposure(shutterAngle: Double, iso: Float) {
        sessionQueue.async { [weak self] in
            guard let self, let device = self.currentDevice else { return }
            guard device.isExposureModeSupported(.custom) else {
                self.onMessage?("当前视频设备不支持手动快门与 ISO")
                return
            }

            let frameRate = max(Self.activeFrameRate(for: device), 1)
            let requestedSeconds = shutterAngle / (360 * frameRate)
            let minimumSeconds = CMTimeGetSeconds(device.activeFormat.minExposureDuration)
            let maximumSeconds = CMTimeGetSeconds(device.activeFormat.maxExposureDuration)
            let clampedSeconds = min(
                max(requestedSeconds, minimumSeconds),
                maximumSeconds
            )
            let clampedISO = min(max(iso, device.activeFormat.minISO), device.activeFormat.maxISO)
            let duration = CMTimeMakeWithSeconds(
                clampedSeconds,
                preferredTimescale: 1_000_000_000
            )

            do {
                try device.lockForConfiguration()
                device.setExposureModeCustom(
                    duration: duration,
                    iso: clampedISO,
                    completionHandler: nil
                )
                device.unlockForConfiguration()
                let appliedAngle = clampedSeconds * frameRate * 360
                DispatchQueue.main.async {
                    self.activeFrameRate = frameRate
                    self.shutterAngle = appliedAngle
                    self.exposureISO = clampedISO
                    self.exposureModeIsCustom = true
                    self.onMessage?(
                        String(
                            format: "视频曝光已应用 · %.1f° · ISO %.0f",
                            appliedAngle,
                            clampedISO
                        )
                    )
                }
            } catch {
                self.onMessage?("视频曝光设置失败：\(error.localizedDescription)")
            }
        }
    }

    func setZoomFactor(_ value: CGFloat) {
        sessionQueue.async { [weak self] in
            guard let self, let device = self.currentDevice else { return }
            let clamped = min(max(value, 1), min(device.activeFormat.videoMaxZoomFactor, 8))
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = clamped
                device.unlockForConfiguration()
                DispatchQueue.main.async {
                    self.zoomFactor = clamped
                }
            } catch {
                self.onMessage?("变焦设置失败：\(error.localizedDescription)")
            }
        }
    }

    func setMonitorVideoSpec(_ spec: MonitorVideoSpec) {
        sessionQueue.async { [weak self] in
            guard let self, let device = self.currentDevice else {
                self?.onMessage?("连接视频设备后才能应用采集画面尺寸/帧频")
                return
            }

            if spec == .automatic {
                let label = Self.videoSpecLabel(for: device.activeFormat)
                let frameRate = Self.activeFrameRate(for: device)
                DispatchQueue.main.async {
                    self.activeVideoSpecLabel = label
                    self.activeFrameRate = frameRate
                    self.onMessage?("采集画面尺寸/帧频由设备自动管理")
                }
                return
            }

            let requestedDimensions = spec.dimensions ?? CMVideoDimensions(
                width: 1920,
                height: 1080
            )
            let requestedWidth = Int(requestedDimensions.width)
            let requestedHeight = Int(requestedDimensions.height)
            let requestedFrameRate = spec.frameRate ?? 30

            let formats = device.formats.filter { format in
                format.videoSupportedFrameRateRanges.contains {
                    $0.maxFrameRate + 0.01 >= requestedFrameRate
                }
            }
            let candidates = formats.isEmpty ? device.formats : formats
            guard let selected = candidates.min(by: { lhs, rhs in
                Self.formatDistance(
                    lhs,
                    width: requestedWidth,
                    height: requestedHeight
                ) < Self.formatDistance(
                    rhs,
                    width: requestedWidth,
                    height: requestedHeight
                )
            }) else {
                self.onMessage?("当前设备没有可用的采集画面尺寸/帧频")
                return
            }

            do {
                if self.session.canSetSessionPreset(.inputPriority) {
                    self.session.beginConfiguration()
                    self.session.sessionPreset = .inputPriority
                    self.session.commitConfiguration()
                }
                try device.lockForConfiguration()
                device.activeFormat = selected
                if let range = selected.videoSupportedFrameRateRanges.first {
                    let appliedFrameRate = min(requestedFrameRate, range.maxFrameRate)
                    let duration = CMTimeMakeWithSeconds(
                        1 / max(appliedFrameRate, 1),
                        preferredTimescale: 600
                    )
                    device.activeVideoMinFrameDuration = duration
                    device.activeVideoMaxFrameDuration = duration
                }
                device.unlockForConfiguration()

                let label = Self.videoSpecLabel(for: selected)
                let frameRate = Self.activeFrameRate(for: device)
                DispatchQueue.main.async {
                    self.activeVideoSpecLabel = label
                    self.activeFrameRate = frameRate
                    self.onMessage?("采集画面尺寸/帧频已应用 · \(label)")
                }
            } catch {
                self.onMessage?("采集画面尺寸/帧频设置失败：\(error.localizedDescription)")
            }
        }
    }

    func focus(at point: CGPoint) {
        sessionQueue.async { [weak self] in
            guard let self, let device = self.currentDevice, device.isFocusPointOfInterestSupported else {
                self?.onMessage?("当前设备不支持点按对焦")
                return
            }
            do {
                try device.lockForConfiguration()
                device.focusPointOfInterest = CGPoint(
                    x: min(max(point.x, 0), 1),
                    y: min(max(point.y, 0), 1)
                )
                if device.isFocusModeSupported(.autoFocus) {
                    device.focusMode = .autoFocus
                }
                device.unlockForConfiguration()
                self.onMessage?("已设置对焦点")
            } catch {
                self.onMessage?("对焦失败：\(error.localizedDescription)")
            }
        }
    }

    func moveFocus(_ signedStep: Int) {
        sessionQueue.async { [weak self] in
            guard let self, let device = self.currentDevice else { return }
            guard device.isLockingFocusWithCustomLensPositionSupported else {
                self.onMessage?("当前视频设备不支持焦点步进")
                return
            }
            let normalized = max(-3, min(3, signedStep))
            guard normalized != 0 else { return }
            let increment = Float(normalized) * 0.025
            let target = min(max(device.lensPosition + increment, 0), 1)
            do {
                try device.lockForConfiguration()
                device.setFocusModeLocked(lensPosition: target)
                device.unlockForConfiguration()
                self.onMessage?(
                    String(format: "焦点位置 %.0f%%", target * 100)
                )
            } catch {
                self.onMessage?("焦点步进失败：\(error.localizedDescription)")
            }
        }
    }

    func setFocusPeakingEnabled(_ enabled: Bool) {
        focusPeakingEnabled = enabled
        if !enabled, !falseColorEnabled {
            monitorOverlay = nil
        }
    }

    func setFalseColorEnabled(_ enabled: Bool) {
        falseColorEnabled = enabled
        if !enabled, !focusPeakingEnabled {
            monitorOverlay = nil
        }
    }

    private func configureSession(deviceID: String?) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            let devices = Self.discoverDevices()
            let requestedDevice = deviceID.flatMap { requestedID in
                devices.first { $0.uniqueID == requestedID }
            }
            guard let device =
                requestedDevice
                ?? devices.first(where: { $0.deviceType == .external })
                ?? devices.first(where: { $0.position == .back })
                ?? devices.first
            else {
                self.updateState(.failed("未找到视频设备"), message: "未发现系统可用的相机")
                return
            }

            do {
                let input = try AVCaptureDeviceInput(device: device)
                self.session.beginConfiguration()
                self.session.sessionPreset = .high
                self.session.inputs.forEach(self.session.removeInput)
                self.session.outputs.forEach(self.session.removeOutput)

                guard self.session.canAddInput(input), self.session.canAddOutput(self.photoOutput) else {
                    self.session.commitConfiguration()
                    self.updateState(.failed("设备无法加入拍摄会话"), message: "当前相机不提供可用视频流")
                    return
                }
                self.session.addInput(input)
                self.session.addOutput(self.photoOutput)
                self.photoOutput.maxPhotoQualityPrioritization = .quality
                let canRecordMovie = self.session.canAddOutput(self.movieOutput)
                if canRecordMovie {
                    self.session.addOutput(self.movieOutput)
                }
                if self.session.canAddOutput(self.videoOutput) {
                    self.videoOutput.alwaysDiscardsLateVideoFrames = true
                    self.videoOutput.videoSettings = [
                        kCVPixelBufferPixelFormatTypeKey as String:
                            kCVPixelFormatType_32BGRA
                    ]
                    self.videoOutput.setSampleBufferDelegate(
                        self,
                        queue: self.monitorQueue
                    )
                    self.session.addOutput(self.videoOutput)
                }
                self.session.commitConfiguration()
                self.currentDevice = device
                self.session.startRunning()

                DispatchQueue.main.async {
                    self.deviceName = device.localizedName
                    self.selectedDeviceID = device.uniqueID
                    self.isExternalCamera = device.deviceType == .external
                    self.supportsFocusPoint = device.isFocusPointOfInterestSupported
                    self.supportsExposureBias =
                        device.minExposureTargetBias < device.maxExposureTargetBias
                    self.supportsCustomExposure = device.isExposureModeSupported(.custom)
                    self.exposureModeIsCustom = device.exposureMode == .custom
                    self.supportsMovieRecording = canRecordMovie
                    self.minExposureBias = device.minExposureTargetBias
                    self.maxExposureBias = device.maxExposureTargetBias
                    self.minISO = device.activeFormat.minISO
                    self.maxISO = device.activeFormat.maxISO
                    self.exposureISO = device.iso
                    self.lensAperture = device.lensAperture
                    let frameRate = Self.activeFrameRate(for: device)
                    self.activeFrameRate = frameRate
                    self.shutterAngle = CMTimeGetSeconds(device.exposureDuration)
                        * frameRate * 360
                    self.maxZoomFactor = min(device.activeFormat.videoMaxZoomFactor, 8)
                    self.exposureBias = device.exposureTargetBias
                    self.zoomFactor = device.videoZoomFactor
                    self.activeVideoSpecLabel = Self.videoSpecLabel(for: device.activeFormat)
                    self.state = .ready
                    self.availableDevices = devices.map(Self.option(for:))
                    self.onMessage?(
                        self.isExternalCamera
                        ? "外接视频设备已连接"
                        : "本机相机已连接"
                    )
                }
            } catch {
                self.updateState(
                    .failed(error.localizedDescription),
                    message: "相机连接失败：\(error.localizedDescription)"
                )
            }
        }
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastMonitorFrameTime >= 1.0 / 15.0,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        else {
            return
        }
        lastMonitorFrameTime = now
        if now - lastExposureReadoutTime >= 0.5, let device = currentDevice {
            lastExposureReadoutTime = now
            let frameRate = Self.activeFrameRate(for: device)
            let angle = CMTimeGetSeconds(device.exposureDuration) * frameRate * 360
            let iso = device.iso
            let aperture = device.lensAperture
            let bias = device.exposureTargetBias
            let customExposure = device.exposureMode == .custom
            DispatchQueue.main.async { [weak self] in
                self?.activeFrameRate = frameRate
                self?.shutterAngle = angle
                self?.exposureISO = iso
                self?.lensAperture = aperture
                self?.exposureBias = bias
                self?.exposureModeIsCustom = customExposure
            }
        }
        let result = ProfessionalMonitor.process(
            pixelBuffer,
            focusPeaking: focusPeakingEnabled,
            falseColor: falseColorEnabled
        )
        DispatchQueue.main.async { [weak self] in
            self?.monitorOverlay = result.overlay
            self?.redHistogram = result.redHistogram
            self?.greenHistogram = result.greenHistogram
            self?.blueHistogram = result.blueHistogram
            self?.waveform = result.waveform
            self?.vectorscope = result.vectorscope
            self?.peakingCoverage = result.peakingCoverage
        }
    }

    private static func discoverDevices() -> [AVCaptureDevice] {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: [.external, .builtInWideAngleCamera],
            mediaType: .video,
            position: .unspecified
        ).devices.sorted { lhs, rhs in
            if (lhs.deviceType == .external) != (rhs.deviceType == .external) {
                return lhs.deviceType == .external
            }
            if lhs.position != rhs.position {
                return lhs.position == .back
            }
            return lhs.localizedName.localizedStandardCompare(rhs.localizedName) == .orderedAscending
        }
    }

    private static func option(for device: AVCaptureDevice) -> CameraDeviceOption {
        CameraDeviceOption(
            id: device.uniqueID,
            name: device.localizedName,
            position: device.position,
            isExternal: device.deviceType == .external
        )
    }

    private static func formatDistance(
        _ format: AVCaptureDevice.Format,
        width: Int,
        height: Int
    ) -> Int {
        let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
        return abs(Int(dimensions.width) - width) + abs(Int(dimensions.height) - height)
    }

    private static func videoSpecLabel(for format: AVCaptureDevice.Format) -> String {
        let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
        let frameRate = format.videoSupportedFrameRateRanges.first?.maxFrameRate ?? 0
        return frameRate > 0
            ? "\(dimensions.width) × \(dimensions.height) · \(Int(frameRate.rounded()))p"
            : "\(dimensions.width) × \(dimensions.height)"
    }

    private static func activeFrameRate(for device: AVCaptureDevice) -> Double {
        let duration = device.activeVideoMinFrameDuration
        if duration.isValid, duration.seconds > 0 {
            return 1 / duration.seconds
        }
        return device.activeFormat.videoSupportedFrameRateRanges.first?.maxFrameRate ?? 30
    }

    private func updateState(_ newState: CameraConnectionState, message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.state = newState
            self?.onMessage?(message)
        }
    }

    @objc private func deviceDisconnected(_ notification: Notification) {
        refreshDevices()
        guard let disconnected = notification.object as? AVCaptureDevice,
              disconnected.uniqueID == currentDevice?.uniqueID else {
            return
        }
        disconnect()
    }

    @objc private func deviceConnected(_ notification: Notification) {
        refreshDevices()
    }

    @objc private func sessionInterrupted(_ notification: Notification) {
        updateState(.failed("拍摄会话已中断"), message: "视频设备被其他应用占用或已断开")
    }

    @objc private func sessionInterruptionEnded(_ notification: Notification) {
        sessionQueue.async { [weak self] in
            guard let self, self.currentDevice != nil else { return }
            if !self.session.isRunning {
                self.session.startRunning()
            }
            self.updateState(.ready, message: "相机预览已恢复")
        }
    }
}

private struct CapturedPayload {
    let data: Data
    let fileExtension: String
}

private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let fileExtension: String
    private let completion: (Result<CapturedPayload, Error>) -> Void

    init(
        fileExtension: String,
        completion: @escaping (Result<CapturedPayload, Error>) -> Void
    ) {
        self.fileExtension = fileExtension
        self.completion = completion
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error {
            completion(.failure(error))
            return
        }
        guard let data = photo.fileDataRepresentation() else {
            completion(.failure(CameraCaptureError.noPhotoData))
            return
        }
        completion(.success(CapturedPayload(data: data, fileExtension: fileExtension)))
    }
}

private enum CameraCaptureError: LocalizedError {
    case noPhotoData

    var errorDescription: String? {
        "相机没有返回照片数据"
    }
}
