import Combine
import CoreBluetooth
import CoreGraphics
import CoreLocation
import Foundation
import ImageIO
import Network

struct CaptureLocation: Codable, Equatable {
    let latitude: Double
    let longitude: Double
    let altitude: Double
    let horizontalAccuracy: Double
    let capturedAt: Date

    init(_ location: CLLocation) {
        latitude = location.coordinate.latitude
        longitude = location.coordinate.longitude
        altitude = location.altitude
        horizontalAccuracy = location.horizontalAccuracy
        capturedAt = location.timestamp
    }
}

final class LocationTaggingService: NSObject, ObservableObject,
    CLLocationManagerDelegate {
    @Published private(set) var enabled = UserDefaults.standard.bool(
        forKey: "captureLocationEnabled"
    )
    @Published private(set) var status = "定位未开启"
    @Published private(set) var latestLocation: CaptureLocation?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5
        if enabled {
            start()
        }
    }

    func setEnabled(_ value: Bool) {
        enabled = value
        UserDefaults.standard.set(value, forKey: "captureLocationEnabled")
        value ? start() : stop()
    }

    func refresh() {
        guard enabled else { return }
        manager.requestLocation()
    }

    func snapshot(maximumAge: TimeInterval = 120) -> CaptureLocation? {
        guard enabled, let latestLocation,
              Date().timeIntervalSince(latestLocation.capturedAt) <= maximumAge
        else { return nil }
        return latestLocation
    }

    private func start() {
        switch manager.authorizationStatus {
        case .notDetermined:
            status = "等待定位授权"
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            status = "正在获取位置…"
            manager.requestLocation()
        case .denied, .restricted:
            status = "定位权限不可用"
        @unknown default:
            status = "无法确认定位权限"
        }
    }

    private func stop() {
        manager.stopUpdatingLocation()
        latestLocation = nil
        status = "定位未开启"
    }

    nonisolated func locationManagerDidChangeAuthorization(
        _ manager: CLLocationManager
    ) {
        Task { @MainActor [weak self] in
            guard let self, self.enabled else { return }
            switch manager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                self.status = "正在获取位置…"
                manager.requestLocation()
            case .denied, .restricted:
                self.status = "定位权限不可用"
            case .notDetermined:
                self.status = "等待定位授权"
            @unknown default:
                self.status = "无法确认定位权限"
            }
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let location = locations.last,
              location.horizontalAccuracy >= 0 else { return }
        Task { @MainActor [weak self] in
            self?.latestLocation = CaptureLocation(location)
            self?.status = String(
                format: "定位就绪 · ±%.0f m",
                location.horizontalAccuracy
            )
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        Task { @MainActor [weak self] in
            self?.status = "定位失败：\(error.localizedDescription)"
        }
    }
}

final class BluetoothRemoteService: NSObject, ObservableObject,
    CBCentralManagerDelegate, CBPeripheralDelegate {
    static let serviceUUID = CBUUID(
        string: "7A5E0001-5E4E-4348-452D-52454D4F5445"
    )
    static let shutterUUID = CBUUID(
        string: "7A5E0002-5E4E-4348-452D-52454D4F5445"
    )

    @Published private(set) var enabled = UserDefaults.standard.bool(
        forKey: "bluetoothRemoteEnabled"
    )
    @Published private(set) var connected = false
    @Published private(set) var status = "蓝牙遥控未开启"
    @Published private(set) var remoteName = "—"

    var onShutter: (() -> Void)?

    private var central: CBCentralManager?
    private var peripheral: CBPeripheral?

    override init() {
        super.init()
        if enabled {
            central = CBCentralManager(delegate: self, queue: .main)
        }
    }

    func setEnabled(_ value: Bool) {
        enabled = value
        UserDefaults.standard.set(value, forKey: "bluetoothRemoteEnabled")
        if value {
            status = "正在准备蓝牙…"
            if central == nil {
                central = CBCentralManager(delegate: self, queue: .main)
            } else {
                beginScanningIfPossible()
            }
        } else {
            stop()
        }
    }

    func stop() {
        central?.stopScan()
        if let peripheral {
            central?.cancelPeripheralConnection(peripheral)
        }
        peripheral = nil
        connected = false
        remoteName = "—"
        status = "蓝牙遥控未开启"
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard enabled else { return }
        switch central.state {
        case .poweredOn:
            beginScanningIfPossible()
        case .unauthorized:
            status = "蓝牙权限不可用"
        case .poweredOff:
            status = "请开启系统蓝牙"
        case .unsupported:
            status = "此设备不支持蓝牙遥控"
        default:
            status = "正在准备蓝牙…"
        }
    }

    private func beginScanningIfPossible() {
        guard enabled, central?.state == .poweredOn, peripheral == nil else {
            return
        }
        status = "正在搜索 ZENCHE 蓝牙遥控器…"
        central?.scanForPeripherals(
            withServices: [Self.serviceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        self.peripheral = peripheral
        remoteName = peripheral.name
            ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String
            ?? "ZENCHE Remote"
        status = "正在连接 \(remoteName)…"
        central.stopScan()
        peripheral.delegate = self
        central.connect(peripheral)
    }

    func centralManager(
        _ central: CBCentralManager,
        didConnect peripheral: CBPeripheral
    ) {
        connected = true
        status = "蓝牙遥控已连接 · \(remoteName)"
        peripheral.discoverServices([Self.serviceUUID])
    }

    func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        self.peripheral = nil
        connected = false
        status = "蓝牙遥控连接失败"
        beginScanningIfPossible()
    }

    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        self.peripheral = nil
        connected = false
        remoteName = "—"
        status = enabled ? "蓝牙遥控已断开，正在重连…" : "蓝牙遥控未开启"
        beginScanningIfPossible()
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverServices error: Error?
    ) {
        guard error == nil else {
            status = "遥控器服务不可用"
            return
        }
        peripheral.services?.forEach {
            peripheral.discoverCharacteristics([Self.shutterUUID], for: $0)
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        guard error == nil,
              let characteristic = service.characteristics?.first(where: {
                  $0.uuid == Self.shutterUUID
              }) else {
            status = "遥控器快门通道不可用"
            return
        }
        peripheral.setNotifyValue(true, for: characteristic)
        status = "蓝牙遥控已就绪 · \(remoteName)"
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard error == nil,
              characteristic.uuid == Self.shutterUUID,
              let value = characteristic.value,
              Self.isShutterEvent(value) else { return }
        status = "已收到蓝牙快门"
        onShutter?()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self, self.connected else { return }
            self.status = "蓝牙遥控已就绪 · \(self.remoteName)"
        }
    }

    private static func isShutterEvent(_ data: Data) -> Bool {
        if data.contains(where: { $0 != 0 }) { return true }
        let text = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return text == "capture" || text == "shutter"
    }
}

enum PTPIPError: LocalizedError {
    case invalidEndpoint
    case connectionFailed(String)
    case invalidPacket
    case rejected(UInt16)
    case notConnected

    /// DeviceInfo 能力探测可安全降级为名称启发式的响应码。
    /// 其他 rejected（特别是会话/事务号失配）必须向上传播。
    static func allowsVendorDetectionFallback(_ code: UInt16) -> Bool {
        switch code {
        case 0x2005, // OperationNotSupported
             0x200A, // DevicePropNotSupported
             0x2019: // DeviceBusy：保留已有连接期间的兼容降级
            return true
        default:
            return false
        }
    }

    /// 这些响应表示本地会话/事务序列已与相机分叉，
    /// 继续复用当前 socket 不再可靠。
    static func isSessionFatalResponse(_ code: UInt16) -> Bool {
        switch code {
        case 0x2003, // SessionNotOpen
             0x2004, // InvalidTransactionID
             0x201E: // SessionAlreadyOpen
            return true
        default:
            return false
        }
    }

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint: return "Wi‑Fi 相机地址或端口无效"
        case .connectionFailed(let message): return "Wi‑Fi 连接失败：\(message)"
        case .invalidPacket: return "相机返回了无效的 PTP/IP 数据"
        case .rejected(let code):
            return String(format: "相机拒绝了 PTP/IP 操作（0x%04X）", code)
        case .notConnected: return "请先连接 Wi‑Fi 相机"
        }
    }
}

private final class PTPIPContinuationGate: @unchecked Sendable {
    private let lock = NSLock()
    private var available = true

    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard available else { return false }
        available = false
        return true
    }
}

/// 将 UI 发起的一次连接生命周期一路带进 PTPIPSession actor。actor 除了
/// 校验自己的 socket generation，还会校验这个 attempt，防止旧任务在新会话
/// 建立后才进入 actor、误把新会话当成自己的会话操作。
private enum PTPIPSessionOwnership {
    @TaskLocal static var attempt: UInt64?
}

private struct PTPIPGateWaiter {
    let epoch: UInt64
    let continuation: CheckedContinuation<Bool, Never>
}

/// start/send 的续体容器。取消可能先于 continuation 安装发生，因此需要保存
/// pending error；否则恰好在安装窗口取消时会永远挂起。
private final class PTPIPVoidContinuationBox: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Error>?
    private var pendingError: Error?
    private var finished = false

    func install(_ continuation: CheckedContinuation<Void, Error>) {
        lock.lock()
        if finished {
            let error = pendingError
            lock.unlock()
            continuation.resume(
                throwing: error ?? PTPIPError.connectionFailed("操作已取消")
            )
            return
        }
        self.continuation = continuation
        lock.unlock()
    }

    func resume() {
        lock.lock()
        guard !finished else {
            lock.unlock()
            return
        }
        finished = true
        let continuation = self.continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume()
    }

    func resume(throwing error: Error) {
        lock.lock()
        guard !finished else {
            lock.unlock()
            return
        }
        finished = true
        let continuation = self.continuation
        self.continuation = nil
        if continuation == nil {
            pendingError = error
        }
        lock.unlock()
        continuation?.resume(throwing: error)
    }
}

/// 单次续体容器：保证 receive 回调与 onCancel 竞速时只恢复一次，
/// 且 onCancel（Task 取消路径）也能拿到 continuation 主动恢复。
private final class PTPIPReceiveBox: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Data, Error>?
    private var pendingError: Error?
    private var finished = false

    func install(_ continuation: CheckedContinuation<Data, Error>) {
        lock.lock()
        if finished {
            let error = pendingError
            lock.unlock()
            continuation.resume(
                throwing: error ?? PTPIPError.connectionFailed("操作已取消")
            )
            return
        }
        self.continuation = continuation
        lock.unlock()
    }

    func resume(returning value: Data) {
        lock.lock()
        guard !finished else {
            lock.unlock()
            return
        }
        finished = true
        let continuation = self.continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume(returning: value)
    }

    func resume(throwing error: Error) {
        lock.lock()
        guard !finished else {
            lock.unlock()
            return
        }
        finished = true
        let continuation = self.continuation
        self.continuation = nil
        if continuation == nil {
            pendingError = error
        }
        lock.unlock()
        continuation?.resume(throwing: error)
    }
}

/// C3：PTP/IP 能力扩展所用厂商扩展/标准属性常量。
/// 尼康实时取景/录像走厂商扩展 0x9201/0x9202/0x9203/0x920a/0x920b；
/// 佳能 EOS 走 0x9110 EOS_SetDevicePropValueEx 写 EVF 属性序列（与 C2
/// 三端口径一致，TBC-awaiting-hardware）；参数读写走标准 PTP 属性。
private enum PTPIPVendorOps {
    // 尼康厂商扩展
    static let startLiveView: UInt16 = 0x9201
    static let endLiveView: UInt16 = 0x9202
    static let getLiveViewImage: UInt16 = 0x9203
    static let startMovieRecording: UInt16 = 0x920a
    static let endMovieRecording: UInt16 = 0x920b

    // 标准 PTP 属性访问
    static let getDevicePropDesc: UInt16 = 0x1014
    static let getDevicePropValue: UInt16 = 0x1015
    static let setDevicePropValue: UInt16 = 0x1016

    // 佳能 EOS 扩展（与 C2 分支选用的序列一致）
    static let canonEOSSetDevicePropValueEx: UInt16 = 0x9110
    static let canonGetViewFinderData: UInt16 = 0x9153
    static let canonEVFRecordStatus: UInt32 = 0xd1b8
    static let canonEVFMode: UInt32 = 0xd1b1
    static let canonEVFOutputDevice: UInt32 = 0xd1b0

    // 常用参数属性码（与 Android PtpCamera 口径一致：ISO 0x500f / 光圈 0x5007 / 快门 0x500d）
    static let propISO: UInt16 = 0x500f
    static let propFNumber: UInt16 = 0x5007
    static let propExposureTime: UInt16 = 0x500d
}

/// 已连 PTP/IP 相机的厂商分类，用于实时取景/录像的 vendor 分发。
enum PTPIPCameraVendor: Equatable {
    case unknown
    case nikon
    case canon
    case sony
}

@MainActor
final class VendorSDKBridgeService: ObservableObject {
    private enum BridgeError: LocalizedError {
        case invalidEndpoint
        case responseTooLarge
        case http(Int)
        case invalidContent

        var errorDescription: String? {
            switch self {
            case .invalidEndpoint:
                return "Mac 相机桥接地址或端口无效"
            case .responseTooLarge:
                return "桥接响应超过安全上限"
            case .http(let code):
                return "桥接返回 HTTP \(code)"
            case .invalidContent:
                return "桥接返回了无效内容"
            }
        }
    }

    enum State: Equatable {
        case disconnected
        case connecting
        case ready
        case failed(String)
    }

    private struct BridgeStatus: Decodable {
        let connected: Bool
        let camera: String
        let backend: String
        let officialSDK: Bool
        let nikonRuntimeDetected: Bool
        let monitoring: Bool
    }

    @Published private(set) var state: State = .disconnected
    @Published private(set) var status = "Mac 相机桥接未连接"
    @Published private(set) var cameraName = "—"
    @Published private(set) var backend = "—"
    @Published private(set) var officialSDK = false
    @Published private(set) var nikonRuntimeDetected = false
    @Published private(set) var liveViewFrame: CGImage?
    @Published var host: String {
        didSet { UserDefaults.standard.set(host, forKey: "vendorSDKBridgeHost") }
    }
    @Published var portText: String {
        didSet { UserDefaults.standard.set(portText, forKey: "vendorSDKBridgePort") }
    }
    @Published var pairingCode = ""

    private let session: URLSession
    private var liveViewTask: Task<Void, Never>?

    init() {
        host = UserDefaults.standard.string(forKey: "vendorSDKBridgeHost")
            ?? "192.168.1.2"
        portText = UserDefaults.standard.string(forKey: "vendorSDKBridgePort")
            ?? "8080"
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 5
        configuration.timeoutIntervalForResource = 8
        configuration.waitsForConnectivity = false
        session = URLSession(configuration: configuration)
    }

    var isConnected: Bool { state == .ready }

    func connect(monitoringEnabled: Bool) {
        guard state != .connecting else { return }
        guard Self.isPrivateLANHost(host), endpointURL(path: "status") != nil else {
            state = .failed("仅支持可信局域网地址")
            status = "请输入 Mac 的局域网 IP 或 .local 地址"
            return
        }
        guard pairingCode.trimmingCharacters(in: .whitespacesAndNewlines).count == 12 else {
            state = .failed("配对码无效")
            status = "请输入 Mac 端显示的 12 位本次配对码"
            return
        }
        state = .connecting
        status = "正在连接 Mac 相机桥接…"
        liveViewTask?.cancel()
        Task { [weak self] in
            guard let self else { return }
            do {
                let bridge: BridgeStatus = try await self.requestJSON(
                    path: "status",
                    method: "GET"
                )
                self.apply(bridge)
                self.state = .ready
                self.status = bridge.connected
                    ? self.backendDescription(bridge)
                    : "桥接已连接 · 请先在 Mac 端连接相机"
                await self.setMonitoring(monitoringEnabled)
            } catch {
                self.state = .failed(error.localizedDescription)
                self.status = error.localizedDescription
            }
        }
    }

    func disconnect() {
        liveViewTask?.cancel()
        liveViewTask = nil
        liveViewFrame = nil
        state = .disconnected
        cameraName = "—"
        backend = "—"
        officialSDK = false
        nikonRuntimeDetected = false
        status = "Mac 相机桥接未连接"
    }

    func setMonitoring(_ enabled: Bool) async {
        guard isConnected else { return }
        do {
            let _: [String: Bool] = try await requestJSON(
                path: "monitor?enabled=\(enabled ? 1 : 0)",
                method: "POST"
            )
            if enabled {
                startLiveViewLoop()
            } else {
                liveViewTask?.cancel()
                liveViewTask = nil
                liveViewFrame = nil
                status = "桥接已连接 · 实时监看已关闭"
            }
        } catch {
            status = error.localizedDescription
        }
    }

    func capture() {
        guard isConnected else {
            status = "请先连接 Mac 相机桥接"
            return
        }
        Task { [weak self] in
            guard let self else { return }
            do {
                let response: [String: JSONValue] = try await self.requestJSON(
                    path: "capture",
                    method: "POST"
                )
                self.status = response["message"]?.stringValue
                    ?? "快门请求已提交"
            } catch {
                self.status = error.localizedDescription
            }
        }
    }

    private func startLiveViewLoop() {
        liveViewTask?.cancel()
        liveViewTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled, self.isConnected {
                do {
                    let data = try await self.requestData(
                        path: "live.jpg",
                        method: "GET",
                        expectedContentType: "image/jpeg",
                        limit: 12 * 1024 * 1024
                    )
                    if let source = CGImageSourceCreateWithData(data as CFData, nil),
                       let image = CGImageSourceCreateImageAtIndex(source, 0, nil) {
                        self.liveViewFrame = image
                        self.status = self.officialSDK
                            ? "Sony Camera Remote SDK · 实时监看中"
                            : "PTP 兼容桥接 · 实时监看中"
                    }
                    try? await Task.sleep(nanoseconds: 100_000_000)
                } catch {
                    if Task.isCancelled { return }
                    try? await Task.sleep(nanoseconds: 350_000_000)
                }
            }
        }
    }

    private func apply(_ status: BridgeStatus) {
        cameraName = status.camera
        backend = status.backend
        officialSDK = status.officialSDK
        nikonRuntimeDetected = status.nikonRuntimeDetected
    }

    private func backendDescription(_ status: BridgeStatus) -> String {
        if status.officialSDK, status.backend == "sony-camera-remote-sdk" {
            return "已连接 \(status.camera) · Sony Camera Remote SDK"
        }
        if status.backend == "nikon-ptp-compatible" {
            return "已连接 \(status.camera) · Nikon PTP 兼容桥接"
        }
        return "已连接 \(status.camera) · \(status.backend)"
    }

    private func requestJSON<T: Decodable>(
        path: String,
        method: String
    ) async throws -> T {
        let data = try await requestData(
            path: path,
            method: method,
            expectedContentType: "application/json",
            limit: 1024 * 1024
        )
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func requestData(
        path: String,
        method: String,
        expectedContentType: String,
        limit: Int
    ) async throws -> Data {
        guard let url = endpointURL(path: path) else {
            throw BridgeError.invalidEndpoint
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(Self.authorization, forHTTPHeaderField: "Authorization")
        request.setValue(
            pairingCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
            forHTTPHeaderField: "X-Zenche-Bridge-Token"
        )
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        let (data, response) = try await session.data(for: request)
        guard data.count <= limit else {
            throw BridgeError.responseTooLarge
        }
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw BridgeError.http(code)
        }
        guard http.value(forHTTPHeaderField: "Content-Type")?
            .lowercased().hasPrefix(expectedContentType) == true else {
            throw BridgeError.invalidContent
        }
        return data
    }

    private func endpointURL(path: String) -> URL? {
        guard let port = UInt16(portText) else { return nil }
        var components = URLComponents()
        components.scheme = "http"
        components.host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        components.port = Int(port)
        components.path = "/sdk-bridge/" + path.components(separatedBy: "?")[0]
        if let query = path.firstIndex(of: "?") {
            components.percentEncodedQuery = String(path[path.index(after: query)...])
        }
        return components.url
    }

    private static var authorization: String {
        let encoded = Data("nikonlink:nikonlink".utf8).base64EncodedString()
        return "Basic \(encoded)"
    }

    private static func isPrivateLANHost(_ input: String) -> Bool {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if value == "localhost" || value.hasSuffix(".local") { return true }
        if value.hasPrefix("10.") || value.hasPrefix("192.168.") ||
            value.hasPrefix("169.254.") { return true }
        let pieces = value.split(separator: ".")
        if pieces.count == 4, pieces[0] == "172",
           let second = Int(pieces[1]), (16...31).contains(second) {
            return true
        }
        return false
    }
}

private enum JSONValue: Decodable {
    case string(String)
    case bool(Bool)
    case number(Double)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else { self = .number(try container.decode(Double.self)) }
    }

    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }
}

private actor PTPIPSession {
    private var command: NWConnection?
    private var event: NWConnection?
    private var connectingCommand: NWConnection?
    private var connectingEvent: NWConnection?
    private var sessionGeneration: UInt64 = 0
    private var sessionOwnerAttempt: UInt64?
    private var highestOwnerAttempt: UInt64 = 0
    private var handshakeTimeoutGeneration: UInt64?
    private var eventReaderTask: Task<Void, Never>?
    private var eventGeneration: UInt64 = 0
    private var probeResponseSequence: UInt64 = 0
    private var probeInProgress = false
    private var commandChannelFailure: String?
    private var commandDeadlineToken: UInt64 = 0
    private var activeCommandDeadlineToken: UInt64?
    private var eventDeadlineToken: UInt64 = 0
    private var activeEventDeadlineToken: UInt64?
    private var commandGateHeld = false
    private var commandGateEpoch: UInt64 = 0
    private var commandGateWaiters: [PTPIPGateWaiter] = []
    private var eventWriteGateHeld = false
    private var eventWriteGateEpoch: UInt64 = 0
    private var eventWriteGateWaiters: [PTPIPGateWaiter] = []
    private var transactionID: UInt32 = 1
    // C3 状态：厂商识别结果与取景/录像标记（断连时清零）。
    private var detectedVendor: PTPIPCameraVendor = .unknown
    private var liveViewActive = false
    private var movieRecording = false

    func connect(host: String, port: UInt16) async throws -> String {
        try Task.checkCancellation()
        guard let ownerAttempt = PTPIPSessionOwnership.attempt else {
            throw PTPIPError.connectionFailed("PTP/IP 连接缺少会话所有权")
        }
        guard ownerAttempt > highestOwnerAttempt else {
            throw PTPIPError.connectionFailed("PTP/IP 连接尝试已过期")
        }
        highestOwnerAttempt = ownerAttempt
        let generation = invalidateSession()
        sessionOwnerAttempt = ownerAttempt
        guard let endpointPort = NWEndpoint.Port(rawValue: port),
              !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { throw PTPIPError.invalidEndpoint }

        let command = NWConnection(
            host: NWEndpoint.Host(host),
            port: endpointPort,
            using: .tcp
        )
        var event: NWConnection?
        connectingCommand = command
        let handshakeDeadlineTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 12_000_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await self?.expireConnectionAttempt(
                generation: generation,
                ownerAttempt: ownerAttempt
            )
        }
        defer { handshakeDeadlineTask.cancel() }

        do {
            try await start(command)
            try validateConnectionAttempt(
                command: command,
                event: nil,
                generation: generation
            )

            var payload = Data()
            payload.append(contentsOf: withUnsafeBytes(of: UUID().uuid) {
                Array($0)
            })
            appendUTF16("ZENCHE", to: &payload)
            appendLE(UInt32(0x0001_0000), to: &payload)
            try await send(packet(type: 1, payload: payload), on: command)
            try validateConnectionAttempt(
                command: command,
                event: nil,
                generation: generation
            )
            let acknowledgment = try await receivePacket(on: command)
            try validateConnectionAttempt(
                command: command,
                event: nil,
                generation: generation
            )
            guard acknowledgment.type == 2,
                  let initAcknowledgment = parseInitCommandAcknowledgment(
                    acknowledgment.data
                  ) else {
                throw PTPIPError.invalidPacket
            }
            let connectionNumber = initAcknowledgment.connectionNumber
            let cameraName = initAcknowledgment.cameraName

            let eventConnection = NWConnection(
                host: NWEndpoint.Host(host),
                port: endpointPort,
                using: .tcp
            )
            event = eventConnection
            connectingEvent = eventConnection
            try await start(eventConnection)
            try validateConnectionAttempt(
                command: command,
                event: eventConnection,
                generation: generation
            )
            var eventPayload = Data()
            appendLE(connectionNumber, to: &eventPayload)
            try await send(
                packet(type: 3, payload: eventPayload),
                on: eventConnection
            )
            try validateConnectionAttempt(
                command: command,
                event: eventConnection,
                generation: generation
            )
            let eventAcknowledgment = try await receivePacket(
                on: eventConnection
            )
            try validateConnectionAttempt(
                command: command,
                event: eventConnection,
                generation: generation
            )
            guard eventAcknowledgment.type == 4 else {
                throw PTPIPError.invalidPacket
            }

            // InitEventAck 后先用局部握手通道启动 reader，确保 OpenSession 等待期间
            // 收到的 Probe Request(type 13) 也能应答；OpenSession 成功前不得把半成品
            // 通道发布成可供业务事务使用的活动会话。
            transactionID = 1
            startEventReader(
                on: eventConnection,
                command: command,
                sessionGeneration: generation
            )

            let response = try await openSession(
                on: command,
                event: eventConnection,
                generation: generation
            )
            try validateConnectionAttempt(
                command: command,
                event: eventConnection,
                generation: generation
            )
            guard response == 0x2001 else {
                throw PTPIPError.rejected(response)
            }

            self.command = command
            self.event = eventConnection
            connectingCommand = nil
            connectingEvent = nil
            return cameraName.isEmpty ? "PTP/IP Camera" : cameraName
        } catch {
            let didReachHandshakeDeadline =
                handshakeTimeoutGeneration == generation
            cleanupConnectionAttempt(
                command: command,
                event: event,
                generation: generation
            )
            if didReachHandshakeDeadline {
                throw PTPIPError.connectionFailed("PTP/IP 握手超时（12 秒）")
            }
            throw error
        }
    }

    func capture() async throws {
        try validateSessionOwner()
        guard command != nil else { throw PTPIPError.notConnected }
        let response = try await commandRequest(
            operation: 0x100E,
            parameters: [0, 0]
        )
        guard response == 0x2001 else {
            throw PTPIPError.rejected(response)
        }
    }

    func listStorage() async throws -> CameraStorageSnapshot {
        var volumes: [CameraStorageVolume] = []
        var items: [CameraStorageItem] = []
        let storageIDs = CameraStorageParser.storageIDs(
            try await dataRequest(operation: 0x1004, parameters: [])
        )
        for storageID in storageIDs {
            volumes.append(CameraStorageParser.storageInfo(
                id: storageID,
                data: try await dataRequest(
                    operation: 0x1005,
                    parameters: [storageID]
                )
            ))
            var pendingHandles = CameraStorageParser.storageIDs(
                try await dataRequest(
                    operation: 0x1007,
                    parameters: [storageID, 0, UInt32.max]
                )
            )
            var visitedHandles = Set<UInt32>()
            var pendingIndex = 0
            while pendingIndex < pendingHandles.count {
                let handle = pendingHandles[pendingIndex]
                pendingIndex += 1
                guard visitedHandles.insert(handle).inserted else { continue }
                let objectInfo = try await dataRequest(
                    operation: 0x1008,
                    parameters: [handle]
                )
                if CameraStorageParser.isAssociation(objectInfo) {
                    let children = CameraStorageParser.storageIDs(
                        try await dataRequest(
                            operation: 0x1007,
                            parameters: [storageID, 0, handle]
                        )
                    )
                    pendingHandles.append(contentsOf: children.filter {
                        !visitedHandles.contains($0)
                    })
                } else if let item = CameraStorageParser.objectInfo(
                    handle: handle,
                    data: objectInfo
                ) {
                    items.append(item)
                }
            }
        }
        items.sort {
            $0.capturedAt == $1.capturedAt
                ? $0.filename.localizedCaseInsensitiveCompare($1.filename)
                    == .orderedDescending
                : $0.capturedAt > $1.capturedAt
        }
        return CameraStorageSnapshot(volumes: volumes, items: items)
    }

    func storageThumbnail(handle: UInt32) async throws -> Data {
        try await dataRequest(operation: 0x100A, parameters: [handle])
    }

    func storageObject(handle: UInt32) async throws -> Data {
        try await dataRequest(
            operation: 0x1009,
            parameters: [handle],
            timeoutMilliseconds: 180_000
        )
    }

    func deleteStorageObject(handle: UInt32) async throws {
        let response = try await commandRequest(
            operation: 0x100B,
            parameters: [handle, 0]
        )
        guard response == 0x2001 else {
            throw PTPIPError.rejected(response)
        }
    }

    // MARK: - C3 能力扩展：厂商识别 / 实时取景 / 录像 / 参数读写

    /// 识别已连机型厂商：优先解析 GetDeviceInfo(0x1001) 数据段中的
    /// Manufacturer 字段；部分机型对 0x1001 直接回响应（无数据段），
    /// 此时退回连接握手返回的相机名启发式。结果按会话缓存。
    /// （E2 1.5.9：0x1002→0x1001——ISO 15740 中 GetDeviceInfo 为 0x1001，
    /// 0x1002 实为 OpenSession；pro 复审观察项收口。）
    func detectVendor(using cameraName: String) async throws
        -> PTPIPCameraVendor {
        // ISO 15740 GetDeviceInfo 的 operation code 为 0x1001。
        let ownerAttempt = PTPIPSessionOwnership.attempt
        guard sessionBelongs(to: ownerAttempt) else {
            throw PTPIPError.connectionFailed("PTP/IP 操作所属会话已失效")
        }
        if detectedVendor != .unknown { return detectedVendor }
        let nameBased = Self.vendor(forName: cameraName)
        var resolved = nameBased
        do {
            let info = try await dataRequest(
                operation: 0x1001,
                parameters: []
            )
            if let manufacturer = deviceInfoManufacturer(info) {
                resolved = Self.vendor(
                    forManufacturer: manufacturer,
                    fallback: nameBased
                )
            }
        } catch PTPIPError.rejected(let code)
            where PTPIPError.allowsVendorDetectionFallback(code) {
            // 仅明确的能力缺失/忙状态可回退到名称识别；
            // SessionNotOpen / InvalidTransactionID 等会话错误继续抛出。
        }
        guard sessionBelongs(to: ownerAttempt) else {
            throw PTPIPError.connectionFailed("PTP/IP 操作所属会话已失效")
        }
        detectedVendor = resolved
        return resolved
    }

    /// 实时取景开始。佳能侧按 C2 序列写 EVFMode/EVFOutputDevice（Busy 容忍，
    /// TBC-awaiting-hardware），数据帧走 GetViewFinderData(0x9153)；
    /// 其余厂商走尼康 0x9201。
    func startLiveView(vendor: PTPIPCameraVendor) async throws {
        try validateSessionOwner()
        guard command != nil else { throw PTPIPError.notConnected }
        if liveViewActive { return }
        if vendor == .canon {
            try? await canonWriteEosProp(PTPIPVendorOps.canonEVFMode, 1)
            try? await canonWriteEosProp(PTPIPVendorOps.canonEVFOutputDevice, 2)
        } else {
            let response = try await commandRequest(
                operation: PTPIPVendorOps.startLiveView,
                parameters: []
            )
            guard response == 0x2001 else {
                throw PTPIPError.rejected(response)
            }
        }
        try validateSessionOwner()
        liveViewActive = true
    }

    /// 实时取景结束（尽力而为，不抛错）。
    func endLiveView(
        vendor: PTPIPCameraVendor,
        ifOwnedBy ownerAttempt: UInt64? = nil
    ) async {
        let expectedOwner = ownerAttempt ?? PTPIPSessionOwnership.attempt
        guard sessionBelongs(to: expectedOwner), command != nil else { return }
        if vendor == .canon {
            try? await canonWriteEosProp(PTPIPVendorOps.canonEVFOutputDevice, 0)
            try? await canonWriteEosProp(PTPIPVendorOps.canonEVFMode, 0)
        } else {
            _ = try? await commandRequest(
                operation: PTPIPVendorOps.endLiveView,
                parameters: []
            )
        }
        guard sessionBelongs(to: expectedOwner) else { return }
        liveViewActive = false
    }

    /// 取一帧实时取景 JPEG。尼康 0x9203 / 佳能 0x9153（TBC-awaiting-hardware）。
    func getLiveViewFrame(vendor: PTPIPCameraVendor) async throws -> Data {
        try validateSessionOwner()
        guard command != nil else { throw PTPIPError.notConnected }
        if vendor == .canon {
            return try await dataRequest(
                operation: PTPIPVendorOps.canonGetViewFinderData,
                parameters: [0, 0]
            )
        }
        return try await dataRequest(
            operation: PTPIPVendorOps.getLiveViewImage,
            parameters: []
        )
    }

    /// 开始录像。尼康 0x920a（未处取景态先开取景）；佳能走 EVFRecordStatus=1
    /// （TBC-awaiting-hardware，与 C2 序列一致）。
    func startMovieRecording(vendor: PTPIPCameraVendor) async throws {
        try validateSessionOwner()
        guard command != nil else { throw PTPIPError.notConnected }
        if movieRecording { return }
        if vendor == .canon {
            try await startLiveView(vendor: .canon)
            try await canonWriteEosProp(PTPIPVendorOps.canonEVFRecordStatus, 1)
        } else {
            if !liveViewActive {
                try await startLiveView(vendor: vendor)
            }
            let response = try await commandRequest(
                operation: PTPIPVendorOps.startMovieRecording,
                parameters: []
            )
            guard response == 0x2001 else {
                throw PTPIPError.rejected(response)
            }
        }
        try validateSessionOwner()
        movieRecording = true
    }

    /// 停止录像。尼康 0x920b；佳能 EVFRecordStatus=0（TBC-awaiting-hardware）。
    func stopMovieRecording(
        vendor: PTPIPCameraVendor,
        ifOwnedBy ownerAttempt: UInt64? = nil
    ) async throws {
        let expectedOwner = ownerAttempt ?? PTPIPSessionOwnership.attempt
        guard sessionBelongs(to: expectedOwner) else {
            throw PTPIPError.connectionFailed("PTP/IP 操作所属会话已失效")
        }
        guard command != nil else { throw PTPIPError.notConnected }
        if vendor == .canon {
            try await canonWriteEosProp(PTPIPVendorOps.canonEVFRecordStatus, 0)
        } else {
            let response = try await commandRequest(
                operation: PTPIPVendorOps.endMovieRecording,
                parameters: []
            )
            guard response == 0x2001 else {
                throw PTPIPError.rejected(response)
            }
        }
        guard sessionBelongs(to: expectedOwner) else {
            throw PTPIPError.connectionFailed("PTP/IP 操作所属会话已失效")
        }
        movieRecording = false
    }

    /// 读取设备属性原始值（GetDevicePropValue 0x1015）。
    func readProperty(_ property: UInt16) async throws -> Data {
        try validateSessionOwner()
        guard command != nil else { throw PTPIPError.notConnected }
        return try await dataRequest(
            operation: PTPIPVendorOps.getDevicePropValue,
            parameters: [UInt32(property)]
        )
    }

    /// 读取设备属性描述符（GetDevicePropDesc 0x1014），用于校验可写性。
    func readPropertyDescriptor(_ property: UInt16) async throws -> Data {
        try validateSessionOwner()
        guard command != nil else { throw PTPIPError.notConnected }
        return try await dataRequest(
            operation: PTPIPVendorOps.getDevicePropDesc,
            parameters: [UInt32(property)]
        )
    }

    /// 写入设备属性（SetDevicePropValue 0x1016，数据段携带属性值）。
    func writeProperty(_ property: UInt16, value: Data) async throws {
        try validateSessionOwner()
        guard command != nil else { throw PTPIPError.notConnected }
        let response = try await dataOutRequest(
            operation: PTPIPVendorOps.setDevicePropValue,
            parameters: [UInt32(property)],
            data: value
        )
        guard response == 0x2001 else { throw PTPIPError.rejected(response) }
    }

    /// 佳能 EOS 扩展属性写入：EOS_SetDevicePropValueEx(0x9110) 携带
    /// 12 字节 LE 载荷 [长度(4) 属性码(4) 值(4)]，与 C2 三端口径一致，
    /// TBC-awaiting-hardware。
    private func canonWriteEosProp(
        _ propCode: UInt32,
        _ value: UInt32
    ) async throws {
        guard command != nil else { throw PTPIPError.notConnected }
        var payload = Data()
        appendLE(UInt32(12), to: &payload)
        appendLE(propCode, to: &payload)
        appendLE(value, to: &payload)
        let response = try await dataOutRequest(
            operation: PTPIPVendorOps.canonEOSSetDevicePropValueEx,
            parameters: [],
            data: payload
        )
        guard response == 0x2001 else { throw PTPIPError.rejected(response) }
    }

    /// 数据输出请求（DataPhaseInfo=2）：请求 → StartData(9) → EndData(12) → 响应。
    /// 用于 SetDevicePropValue 与佳能 0x9110 等携带数据段的写入操作。
    private func dataOutRequest(
        operation: UInt16,
        parameters: [UInt32],
        data: Data
    ) async throws -> UInt16 {
        guard let expectedCommand = command else {
            throw PTPIPError.notConnected
        }
        let expectedGeneration = sessionGeneration
        let gateLease = try await acquireCommandGate()
        defer { releaseCommandGate(gateLease) }
        var transactionStarted = false
        do {
            try validateCommandSession(
                command: expectedCommand,
                generation: expectedGeneration
            )
            let deadline = startCommandDeadline(
                command: expectedCommand,
                generation: expectedGeneration,
                timeoutMilliseconds: 12_000
            )
            defer { finishCommandDeadline(deadline) }
            let current = nextTransactionID()
            var payload = Data()
            appendLE(UInt32(2), to: &payload)
            appendLE(operation, to: &payload)
            appendLE(current, to: &payload)
            parameters.forEach { appendLE($0, to: &payload) }
            transactionStarted = true
            try await send(
                packet(type: 6, payload: payload),
                on: expectedCommand
            )
            try validateCommandSession(
                command: expectedCommand,
                generation: expectedGeneration
            )

            var startPayload = Data()
            appendLE(current, to: &startPayload)
            appendLE(UInt64(data.count), to: &startPayload)
            try await send(
                packet(type: 9, payload: startPayload),
                on: expectedCommand
            )
            try validateCommandSession(
                command: expectedCommand,
                generation: expectedGeneration
            )

            var endPayload = Data()
            appendLE(current, to: &endPayload)
            endPayload.append(data)
            try await send(
                packet(type: 12, payload: endPayload),
                on: expectedCommand
            )
            try validateCommandSession(
                command: expectedCommand,
                generation: expectedGeneration
            )

            let response = try await receivePacket(on: expectedCommand)
            try validateCommandSession(
                command: expectedCommand,
                generation: expectedGeneration
            )
            guard response.type == 7,
                  response.data.count >= 14,
                  readUInt32(response.data, at: 10) == current else {
                throw PTPIPError.invalidPacket
            }
            let responseCode = readUInt16(response.data, at: 8)
            if PTPIPError.isSessionFatalResponse(responseCode) {
                throw PTPIPError.rejected(responseCode)
            }
            return responseCode
        } catch {
            recordCommandChannelFailure(
                error,
                command: expectedCommand,
                generation: expectedGeneration,
                transactionStarted: transactionStarted
            )
            throw error
        }
    }

    // MARK: - C3 厂商识别解析

    /// 从 GetDeviceInfo 数据段解析厂商名（Manufacturer，PTP STR）。
    /// 布局：StandardVersion(2)+VendorExtensionID(4)+VendorExtensionVersion(2)+
    /// VendorExtensionDesc(PTP STR)+FunctionalMode(2)+五个 AUINT16 数组+
    /// Manufacturer(PTP STR)+Model(PTP STR)+DeviceVersion(PTP STR)+SerialNumber(PTP STR)。
    private func deviceInfoManufacturer(_ data: Data) -> String? {
        guard data.count >= 8 else { return nil }
        var offset = 8
        guard Self.readPTPString(data, &offset) != nil else { return nil }
        guard offset + 2 <= data.count else { return nil }
        offset += 2  // FunctionalMode
        for _ in 0..<5 {
            guard offset + 4 <= data.count else { return nil }
            let count = Int(readUInt32(data, at: offset))
            offset += 4
            guard count <= (data.count - offset) / 2 else { return nil }
            offset += count * 2
        }
        return Self.readPTPString(data, &offset)
    }

    private static func readPTPString(
        _ data: Data,
        _ offset: inout Int
    ) -> String? {
        guard offset < data.count else { return nil }
        let characterCount = Int(data[offset])
        offset += 1
        if characterCount == 0 { return "" }
        let byteCount = characterCount * 2
        guard byteCount <= data.count - offset,
              data[offset + byteCount - 2] == 0,
              data[offset + byteCount - 1] == 0 else { return nil }
        let textEnd = offset + byteCount - 2
        let text = String(
            data: data[offset..<textEnd],
            encoding: .utf16LittleEndian
        )
        offset += byteCount
        return text
    }

    private static func vendor(
        forManufacturer manufacturer: String?,
        fallback: PTPIPCameraVendor
    ) -> PTPIPCameraVendor {
        let text = (manufacturer ?? "").lowercased()
        if text.contains("nikon") { return .nikon }
        if text.contains("canon") { return .canon }
        if text.contains("sony") { return .sony }
        return fallback
    }

    private static func vendor(forName name: String) -> PTPIPCameraVendor {
        let text = name.lowercased()
        if text.contains("nikon") { return .nikon }
        if text.contains("canon") { return .canon }
        if text.contains("sony") || text.contains("ilce") || text.contains("alpha") {
            return .sony
        }
        return .unknown
    }

    private func validateConnectionAttempt(
        command expectedCommand: NWConnection,
        event expectedEvent: NWConnection?,
        generation expectedGeneration: UInt64
    ) throws {
        try Task.checkCancellation()
        try validateSessionOwner()
        guard expectedGeneration == sessionGeneration,
              let currentCommand = connectingCommand,
              currentCommand === expectedCommand else {
            throw PTPIPError.connectionFailed("PTP/IP 连接会话已失效")
        }
        if let expectedEvent {
            guard let currentEvent = connectingEvent,
                  currentEvent === expectedEvent else {
                throw PTPIPError.connectionFailed("PTP/IP 连接会话已失效")
            }
        }
    }

    /// 12 秒 deadline 不是只让一个 timer 抛错，而是直接终止当前 generation
    /// 的 NWConnection，使 start/send/receive 的 continuation 都能实际恢复。
    /// generation + owner 双重校验保证旧 watchdog 不能取消随后建立的新会话。
    private func expireConnectionAttempt(
        generation: UInt64,
        ownerAttempt: UInt64?
    ) {
        guard generation == sessionGeneration,
              sessionOwnerAttempt == ownerAttempt,
              connectingCommand != nil else { return }
        handshakeTimeoutGeneration = generation
        connectingCommand?.cancel()
        connectingEvent?.cancel()
    }

    private func cleanupConnectionAttempt(
        command: NWConnection,
        event: NWConnection?,
        generation: UInt64
    ) {
        command.cancel()
        event?.cancel()
        guard generation == sessionGeneration else { return }
        _ = invalidateSession()
    }

    @discardableResult
    private func invalidateSession() -> UInt64 {
        sessionGeneration &+= 1
        eventGeneration &+= 1
        invalidateCommandGate()
        invalidateEventWriteGate()
        eventReaderTask?.cancel()
        eventReaderTask = nil
        connectingCommand?.cancel()
        connectingEvent?.cancel()
        command?.cancel()
        event?.cancel()
        connectingCommand = nil
        connectingEvent = nil
        command = nil
        event = nil
        sessionOwnerAttempt = nil
        handshakeTimeoutGeneration = nil
        commandDeadlineToken &+= 1
        activeCommandDeadlineToken = nil
        eventDeadlineToken &+= 1
        activeEventDeadlineToken = nil
        commandChannelFailure = nil
        transactionID = 1
        // C3 会话状态复位（取景/录像/厂商识别随连接一起清空）。
        liveViewActive = false
        movieRecording = false
        detectedVendor = .unknown
        return sessionGeneration
    }

    /// 只允许拥有当前 actor 会话的 UI attempt 清理它。旧 attempt 的迟到
    /// cleanup 会在 actor 内原子地变成 no-op，不能误断开新会话。
    func disconnect(ifOwnedBy attempt: UInt64) async {
        guard sessionOwnerAttempt == attempt else { return }
        _ = invalidateSession()
    }

    /// PTP/IP event 通道保活：发 Probe Request(type 13)，等待 reader 收到
    /// Probe Response(type 14)。命令通道保持空闲，不会与在途 PTP 事务争抢响应。
    func probe(timeoutMilliseconds: UInt64 = 3000) async throws {
        try validateSessionOwner()
        if let commandChannelFailure {
            throw PTPIPError.connectionFailed(commandChannelFailure)
        }
        let context = try beginProbe()
        defer { probeInProgress = false }

        do {
            let writeDeadline = startEventDeadline(
                command: context.command,
                event: context.event,
                generation: context.generation,
                timeoutMilliseconds: timeoutMilliseconds
            )
            defer { finishEventDeadline(writeDeadline) }
            try await writeEventPacket(
                type: 13,
                on: context.event,
                generation: context.generation
            )
        }
        // 写入 watchdog 到此结束；ProbeResponse 超时独立计为
        // heartbeat miss，单次无响应不会先拆除会话。
        let responseDeadlineNanoseconds = DispatchTime.now().uptimeNanoseconds
            &+ timeoutMilliseconds &* 1_000_000
        while probeResponseSequence == context.baseline {
            try Task.checkCancellation()
            guard context.generation == sessionGeneration,
                  let currentEvent = self.event,
                  currentEvent === context.event,
                  let currentCommand = command,
                  currentCommand === context.command,
                  commandChannelFailure == nil else {
                throw PTPIPError.connectionFailed("PTP/IP 事件通道已断开")
            }
            let now = DispatchTime.now().uptimeNanoseconds
            guard now < responseDeadlineNanoseconds else {
                throw PTPIPError.connectionFailed("心跳探测超时")
            }
            try await Task.sleep(
                nanoseconds: min(
                    UInt64(25_000_000),
                    responseDeadlineNanoseconds - now
                )
            )
        }
        try validateEventSession(
            event: context.event,
            generation: context.generation
        )
    }

    /// 发布 UI ready 前的双通道健康屏障：厂商识别已经完成了一次 command
    /// 事务，这里再校验该命令会话仍属于当前 generation，并要求 event 通道
    /// 完成一次 Probe 往返。Probe 结束后再次校验 command，防止探测期间命令
    /// 通道被 reader/超时处理退休却仍发布为已连接。
    func assertHealthy(timeoutMilliseconds: UInt64 = 3000) async throws {
        try validateSessionOwner()
        guard let expectedCommand = command else {
            throw PTPIPError.notConnected
        }
        let expectedGeneration = sessionGeneration
        try validateCommandSession(
            command: expectedCommand,
            generation: expectedGeneration
        )
        try await probe(timeoutMilliseconds: timeoutMilliseconds)
        try validateCommandSession(
            command: expectedCommand,
            generation: expectedGeneration
        )
    }

    private func beginProbe() throws -> (
        command: NWConnection,
        event: NWConnection,
        generation: UInt64,
        baseline: UInt64
    ) {
        guard let command, let event else { throw PTPIPError.notConnected }
        guard !probeInProgress else {
            throw PTPIPError.connectionFailed("已有心跳探测正在进行")
        }
        probeInProgress = true
        return (command, event, sessionGeneration, probeResponseSequence)
    }

    private func commandRequest(
        operation: UInt16,
        parameters: [UInt32],
        transaction explicitTransaction: UInt32? = nil
    ) async throws -> UInt16 {
        guard let expectedCommand = command else {
            throw PTPIPError.notConnected
        }
        let expectedGeneration = sessionGeneration
        let gateLease = try await acquireCommandGate()
        defer { releaseCommandGate(gateLease) }
        var transactionStarted = false
        do {
            try validateCommandSession(
                command: expectedCommand,
                generation: expectedGeneration
            )
            let deadline = startCommandDeadline(
                command: expectedCommand,
                generation: expectedGeneration,
                timeoutMilliseconds: 12_000
            )
            defer { finishCommandDeadline(deadline) }
            let transaction = explicitTransaction ?? nextTransactionID()
            var payload = Data()
            appendLE(UInt32(1), to: &payload)
            appendLE(operation, to: &payload)
            appendLE(transaction, to: &payload)
            parameters.forEach { appendLE($0, to: &payload) }
            transactionStarted = true
            try await send(
                packet(type: 6, payload: payload),
                on: expectedCommand
            )
            try validateCommandSession(
                command: expectedCommand,
                generation: expectedGeneration
            )
            let response = try await receivePacket(on: expectedCommand)
            try validateCommandSession(
                command: expectedCommand,
                generation: expectedGeneration
            )
            guard response.type == 7,
                  response.data.count >= 14,
                  readUInt32(response.data, at: 10) == transaction else {
                throw PTPIPError.invalidPacket
            }
            let responseCode = readUInt16(response.data, at: 8)
            if PTPIPError.isSessionFatalResponse(responseCode) {
                throw PTPIPError.rejected(responseCode)
            }
            return responseCode
        } catch {
            recordCommandChannelFailure(
                error,
                command: expectedCommand,
                generation: expectedGeneration,
                transactionStarted: transactionStarted
            )
            throw error
        }
    }

    private func dataRequest(
        operation: UInt16,
        parameters: [UInt32],
        timeoutMilliseconds: UInt64 = 12_000
    ) async throws -> Data {
        guard let expectedCommand = command else {
            throw PTPIPError.notConnected
        }
        let expectedGeneration = sessionGeneration
        let gateLease = try await acquireCommandGate()
        defer { releaseCommandGate(gateLease) }
        var transactionStarted = false
        do {
            try validateCommandSession(
                command: expectedCommand,
                generation: expectedGeneration
            )
            let deadline = startCommandDeadline(
                command: expectedCommand,
                generation: expectedGeneration,
                timeoutMilliseconds: timeoutMilliseconds
            )
            defer { finishCommandDeadline(deadline) }
            let current = nextTransactionID()
            var payload = Data()
            // PTP/IP value 1 is used for data-in and no-data operations.
            appendLE(UInt32(1), to: &payload)
            appendLE(operation, to: &payload)
            appendLE(current, to: &payload)
            parameters.forEach { appendLE($0, to: &payload) }
            transactionStarted = true
            try await send(
                packet(type: 6, payload: payload),
                on: expectedCommand
            )
            try validateCommandSession(
                command: expectedCommand,
                generation: expectedGeneration
            )

            let first = try await receivePacket(on: expectedCommand)
            try validateCommandSession(
                command: expectedCommand,
                generation: expectedGeneration
            )
            if first.type == 7 {
                guard first.data.count >= 14,
                      readUInt32(first.data, at: 10) == current else {
                    throw PTPIPError.invalidPacket
                }
                let response = readUInt16(first.data, at: 8)
                throw PTPIPError.rejected(response)
            }
            guard first.type == 9,
                  first.data.count >= 20,
                  readUInt32(first.data, at: 8) == current else {
                throw PTPIPError.invalidPacket
            }
            let announcedLength = readUInt64(first.data, at: 12)
            let lengthIsKnown = announcedLength != UInt64.max
            let maximumObjectBytes = UInt64(512 * 1024 * 1024)
            guard !lengthIsKnown || announcedLength <= maximumObjectBytes else {
                throw PTPIPError.connectionFailed(
                    "机内文件超过当前 512 MB 单文件传输上限"
                )
            }
            var data = Data()
            let initialCapacity = lengthIsKnown
                ? min(announcedLength, 8 * 1024 * 1024)
                : 8 * 1024 * 1024
            data.reserveCapacity(Int(initialCapacity))
            while true {
                let packet = try await receivePacket(on: expectedCommand)
                try validateCommandSession(
                    command: expectedCommand,
                    generation: expectedGeneration
                )
                guard (packet.type == 10 || packet.type == 12),
                      packet.data.count >= 12,
                      readUInt32(packet.data, at: 8) == current else {
                    throw PTPIPError.invalidPacket
                }
                data.append(packet.data.subdata(in: 12..<packet.data.count))
                guard data.count <= Int(maximumObjectBytes) else {
                    throw PTPIPError.connectionFailed(
                        "机内文件超过当前 512 MB 单文件传输上限"
                    )
                }
                if packet.type == 12 { break }
            }
            guard !lengthIsKnown || UInt64(data.count) == announcedLength else {
                throw PTPIPError.invalidPacket
            }
            let response = try await receivePacket(on: expectedCommand)
            try validateCommandSession(
                command: expectedCommand,
                generation: expectedGeneration
            )
            guard response.type == 7,
                  response.data.count >= 14,
                  readUInt32(response.data, at: 10) == current else {
                throw PTPIPError.invalidPacket
            }
            let code = readUInt16(response.data, at: 8)
            guard code == 0x2001 else { throw PTPIPError.rejected(code) }
            return data
        } catch {
            recordCommandChannelFailure(
                error,
                command: expectedCommand,
                generation: expectedGeneration,
                transactionStarted: transactionStarted
            )
            throw error
        }
    }

    private func openSession(
        on expectedCommand: NWConnection,
        event expectedEvent: NWConnection,
        generation expectedGeneration: UInt64
    ) async throws -> UInt16 {
        let gateLease = try await acquireCommandGate()
        defer { releaseCommandGate(gateLease) }
        try validateConnectionAttempt(
            command: expectedCommand,
            event: expectedEvent,
            generation: expectedGeneration
        )

        let transaction: UInt32 = 0
        var payload = Data()
        appendLE(UInt32(1), to: &payload)
        appendLE(UInt16(0x1002), to: &payload)
        appendLE(transaction, to: &payload)
        appendLE(UInt32(1), to: &payload)
        try await send(
            packet(type: 6, payload: payload),
            on: expectedCommand
        )
        try validateConnectionAttempt(
            command: expectedCommand,
            event: expectedEvent,
            generation: expectedGeneration
        )
        let response = try await receivePacket(on: expectedCommand)
        try validateConnectionAttempt(
            command: expectedCommand,
            event: expectedEvent,
            generation: expectedGeneration
        )
        guard response.type == 7,
              response.data.count >= 14,
              readUInt32(response.data, at: 10) == transaction else {
            throw PTPIPError.invalidPacket
        }
        return readUInt16(response.data, at: 8)
    }

    private func validateCommandSession(
        command expectedCommand: NWConnection,
        generation expectedGeneration: UInt64
    ) throws {
        try Task.checkCancellation()
        try validateSessionOwner()
        guard expectedGeneration == sessionGeneration,
              let currentCommand = command,
              currentCommand === expectedCommand else {
            throw PTPIPError.connectionFailed("PTP/IP 命令会话已失效")
        }
        if let commandChannelFailure {
            throw PTPIPError.connectionFailed(
                "PTP/IP 命令通道已失败：\(commandChannelFailure)"
            )
        }
    }

    private func recordCommandChannelFailure(
        _ error: Error,
        command expectedCommand: NWConnection,
        generation expectedGeneration: UInt64,
        transactionStarted: Bool
    ) {
        guard expectedGeneration == sessionGeneration,
              let currentCommand = command,
              currentCommand === expectedCommand,
              commandChannelFailure == nil else { return }
        guard let ptpipError = error as? PTPIPError else {
            if transactionStarted {
                commandChannelFailure = error.localizedDescription
            }
            return
        }
        switch ptpipError {
        case .connectionFailed(let message):
            commandChannelFailure = message
        case .invalidPacket:
            commandChannelFailure = "命令通道返回无效 PTP/IP 帧"
        case .rejected(let code):
            if PTPIPError.isSessionFatalResponse(code) {
                commandChannelFailure = String(
                    format: "PTP/IP 会话已失效（0x%04X）",
                    code
                )
            }
        case .invalidEndpoint, .notConnected:
            break
        }
    }

    /// 每个完整 PTP 命令事务都有 deadline。到期时必须退役该 generation 的
    /// command socket；继续复用带有迟到响应的字节流会污染下一事务。
    private func startCommandDeadline(
        command expectedCommand: NWConnection,
        generation expectedGeneration: UInt64,
        timeoutMilliseconds: UInt64
    ) -> (token: UInt64, task: Task<Void, Never>) {
        commandDeadlineToken &+= 1
        let token = commandDeadlineToken
        activeCommandDeadlineToken = token
        let task = Task { [weak self] in
            do {
                try await Task.sleep(
                    nanoseconds: timeoutMilliseconds * 1_000_000
                )
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await self?.expireCommandTransaction(
                command: expectedCommand,
                generation: expectedGeneration,
                token: token,
                timeoutMilliseconds: timeoutMilliseconds
            )
        }
        return (token, task)
    }

    private func finishCommandDeadline(
        _ deadline: (token: UInt64, task: Task<Void, Never>)
    ) {
        if activeCommandDeadlineToken == deadline.token {
            activeCommandDeadlineToken = nil
        }
        deadline.task.cancel()
    }

    private func expireCommandTransaction(
        command expectedCommand: NWConnection,
        generation expectedGeneration: UInt64,
        token expectedToken: UInt64,
        timeoutMilliseconds: UInt64
    ) {
        guard expectedGeneration == sessionGeneration,
              activeCommandDeadlineToken == expectedToken,
              let currentCommand = command,
              currentCommand === expectedCommand else { return }
        activeCommandDeadlineToken = nil
        commandChannelFailure =
            "命令事务超时（\(timeoutMilliseconds) 毫秒）"
        expectedCommand.cancel()
    }

    private func acquireCommandGate() async throws -> UInt64 {
        try Task.checkCancellation()
        let epoch = commandGateEpoch
        if !commandGateHeld {
            commandGateHeld = true
            return epoch
        }
        let acquired = await withCheckedContinuation {
            (continuation: CheckedContinuation<Bool, Never>) in
            commandGateWaiters.append(PTPIPGateWaiter(
                epoch: epoch,
                continuation: continuation
            ))
        }
        guard acquired, epoch == commandGateEpoch else {
            throw PTPIPError.connectionFailed("PTP/IP 命令等待已失效")
        }
        do {
            try Task.checkCancellation()
        } catch {
            // waiter 被授予 lease 的同时也可能已经取消；先把 lease 交给下一位，
            // 再传播取消，避免 gate 永久保持 held。
            releaseCommandGate(epoch)
            throw error
        }
        return epoch
    }

    private func releaseCommandGate(_ lease: UInt64) {
        guard lease == commandGateEpoch else { return }
        while !commandGateWaiters.isEmpty {
            let waiter = commandGateWaiters.removeFirst()
            if waiter.epoch == commandGateEpoch {
                waiter.continuation.resume(returning: true)
                return
            }
            waiter.continuation.resume(returning: false)
        }
        commandGateHeld = false
    }

    private func invalidateCommandGate() {
        commandGateEpoch &+= 1
        commandGateHeld = false
        let waiters = commandGateWaiters
        commandGateWaiters.removeAll()
        waiters.forEach { $0.continuation.resume(returning: false) }
    }

    private func writeEventPacket(
        type: UInt32,
        on expectedEvent: NWConnection,
        command expectedCommand: NWConnection? = nil,
        generation expectedGeneration: UInt64
    ) async throws {
        let gateLease = try await acquireEventWriteGate()
        defer { releaseEventWriteGate(gateLease) }
        if let expectedCommand {
            try validateEventReaderSession(
                command: expectedCommand,
                event: expectedEvent,
                generation: expectedGeneration
            )
        } else {
            try validateEventSession(
                event: expectedEvent,
                generation: expectedGeneration
            )
        }
        try await send(
            packet(type: type, payload: Data()),
            on: expectedEvent
        )
        if let expectedCommand {
            try validateEventReaderSession(
                command: expectedCommand,
                event: expectedEvent,
                generation: expectedGeneration
            )
        } else {
            try validateEventSession(
                event: expectedEvent,
                generation: expectedGeneration
            )
        }
    }

    private func validateEventSession(
        event expectedEvent: NWConnection,
        generation expectedGeneration: UInt64
    ) throws {
        try Task.checkCancellation()
        try validateSessionOwner()
        guard expectedGeneration == sessionGeneration,
              let currentEvent = event,
              currentEvent === expectedEvent,
              command != nil,
              commandChannelFailure == nil else {
            throw PTPIPError.connectionFailed("PTP/IP 事件会话已失效")
        }
    }

    /// event reader 在 OpenSession 完成前绑定 connecting 双通道，完成后无缝切换为
    /// 已发布双通道；任一旧 generation/旧连接都不能向新会话写 ProbeResponse。
    private func validateEventReaderSession(
        command expectedCommand: NWConnection,
        event expectedEvent: NWConnection,
        generation expectedGeneration: UInt64
    ) throws {
        try Task.checkCancellation()
        try validateSessionOwner()
        guard expectedGeneration == sessionGeneration,
              commandChannelFailure == nil else {
            throw PTPIPError.connectionFailed("PTP/IP 事件 reader 会话已失效")
        }
        let isConnecting = connectingCommand === expectedCommand
            && connectingEvent === expectedEvent
        let isPublished = command === expectedCommand && event === expectedEvent
        guard isConnecting || isPublished else {
            throw PTPIPError.connectionFailed("PTP/IP 事件 reader 通道已失效")
        }
    }

    private func validateSessionOwner() throws {
        guard let expectedOwner = PTPIPSessionOwnership.attempt else {
            throw PTPIPError.connectionFailed("PTP/IP 操作缺少会话所有权")
        }
        guard sessionBelongs(to: expectedOwner) else {
            throw PTPIPError.connectionFailed("PTP/IP 操作所属会话已失效")
        }
    }

    private func sessionBelongs(to expectedOwner: UInt64?) -> Bool {
        guard let expectedOwner else { return false }
        return sessionOwnerAttempt == expectedOwner
    }

    private func acquireEventWriteGate() async throws -> UInt64 {
        try Task.checkCancellation()
        let epoch = eventWriteGateEpoch
        if !eventWriteGateHeld {
            eventWriteGateHeld = true
            return epoch
        }
        let acquired = await withCheckedContinuation {
            (continuation: CheckedContinuation<Bool, Never>) in
            eventWriteGateWaiters.append(PTPIPGateWaiter(
                epoch: epoch,
                continuation: continuation
            ))
        }
        guard acquired, epoch == eventWriteGateEpoch else {
            throw PTPIPError.connectionFailed("PTP/IP 事件写入等待已失效")
        }
        do {
            try Task.checkCancellation()
        } catch {
            releaseEventWriteGate(epoch)
            throw error
        }
        return epoch
    }

    private func releaseEventWriteGate(_ lease: UInt64) {
        guard lease == eventWriteGateEpoch else { return }
        while !eventWriteGateWaiters.isEmpty {
            let waiter = eventWriteGateWaiters.removeFirst()
            if waiter.epoch == eventWriteGateEpoch {
                waiter.continuation.resume(returning: true)
                return
            }
            waiter.continuation.resume(returning: false)
        }
        eventWriteGateHeld = false
    }

    private func invalidateEventWriteGate() {
        eventWriteGateEpoch &+= 1
        eventWriteGateHeld = false
        let waiters = eventWriteGateWaiters
        eventWriteGateWaiters.removeAll()
        waiters.forEach { $0.continuation.resume(returning: false) }
    }

    private func startEventDeadline(
        command expectedCommand: NWConnection,
        event expectedEvent: NWConnection,
        generation expectedGeneration: UInt64,
        timeoutMilliseconds: UInt64
    ) -> (token: UInt64, task: Task<Void, Never>) {
        eventDeadlineToken &+= 1
        let token = eventDeadlineToken
        activeEventDeadlineToken = token
        let task = Task { [weak self] in
            do {
                try await Task.sleep(
                    nanoseconds: timeoutMilliseconds * 1_000_000
                )
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await self?.expireEventOperation(
                command: expectedCommand,
                event: expectedEvent,
                generation: expectedGeneration,
                token: token
            )
        }
        return (token, task)
    }

    private func finishEventDeadline(
        _ deadline: (token: UInt64, task: Task<Void, Never>)
    ) {
        if activeEventDeadlineToken == deadline.token {
            activeEventDeadlineToken = nil
        }
        deadline.task.cancel()
    }

    private func expireEventOperation(
        command expectedCommand: NWConnection,
        event expectedEvent: NWConnection,
        generation expectedGeneration: UInt64,
        token expectedToken: UInt64
    ) {
        guard expectedGeneration == sessionGeneration,
              activeEventDeadlineToken == expectedToken,
              command === expectedCommand,
              event === expectedEvent else { return }
        // PTP/IP 的双通道属于同一会话。event 写入或 Probe 挂死后不能只复用
        // command 半边，否则迟到帧会让 UI 继续显示一个实际不可恢复的连接。
        _ = invalidateSession()
    }

    private func nextTransactionID() -> UInt32 {
        let current = transactionID
        transactionID = current >= 0xffff_fffe ? 1 : current + 1
        return current
    }

    private func startEventReader(
        on connection: NWConnection,
        command commandConnection: NWConnection,
        sessionGeneration: UInt64
    ) {
        eventReaderTask?.cancel()
        eventGeneration &+= 1
        let readerGeneration = eventGeneration
        eventReaderTask = Task { [weak self] in
            guard let self else { return }
            await self.runEventReader(
                on: connection,
                command: commandConnection,
                sessionGeneration: sessionGeneration,
                readerGeneration: readerGeneration
            )
        }
    }

    private func runEventReader(
        on connection: NWConnection,
        command commandConnection: NWConnection,
        sessionGeneration expectedSessionGeneration: UInt64,
        readerGeneration: UInt64
    ) async {
        while !Task.isCancelled {
            do {
                let eventPacket = try await receivePacket(on: connection)
                try validateEventReaderSession(
                    command: commandConnection,
                    event: connection,
                    generation: expectedSessionGeneration
                )
                guard readerGeneration == eventGeneration else { return }
                switch eventPacket.type {
                case 13:
                    let expectedEvent = connection
                    let expectedCommand = commandConnection
                    let expectedGeneration = expectedSessionGeneration
                    try await writeEventPacket(
                        type: 14,
                        on: expectedEvent,
                        command: expectedCommand,
                        generation: expectedGeneration
                    )
                case 14:
                    probeResponseSequence &+= 1
                case 8:
                    // 事件已从 TCP 流中完整取走；业务层事件接入时可在此分发。
                    continue
                default:
                    continue
                }
            } catch {
                guard readerGeneration == eventGeneration,
                      expectedSessionGeneration == sessionGeneration else {
                    return
                }
                let ownsConnecting = connectingCommand === commandConnection
                    && connectingEvent === connection
                let ownsPublished = command === commandConnection
                    && event === connection
                guard ownsConnecting || ownsPublished else { return }
                connection.cancel()
                commandConnection.cancel()
                if ownsConnecting {
                    connectingEvent = nil
                    connectingCommand = nil
                }
                if ownsPublished {
                    event = nil
                    command = nil
                }
                return
            }
        }
    }

    private func start(_ connection: NWConnection) async throws {
        let box = PTPIPVoidContinuationBox()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<Void, Error>) in
                box.install(continuation)
                connection.stateUpdateHandler = { state in
                    switch state {
                    case .ready:
                        box.resume()
                    case .failed(let error), .waiting(let error):
                        box.resume(
                            throwing: PTPIPError.connectionFailed(
                                error.localizedDescription
                            )
                        )
                    case .cancelled:
                        box.resume(
                            throwing: PTPIPError.connectionFailed("连接已取消")
                        )
                    default:
                        break
                    }
                }
                connection.start(queue: DispatchQueue(
                    label: "com.tauber.nikonlink.ptpip.socket"
                ))
            }
        } onCancel: {
            box.resume(
                throwing: PTPIPError.connectionFailed("连接操作已取消")
            )
            connection.cancel()
        }
    }

    private func send(_ data: Data, on connection: NWConnection) async throws {
        let box = PTPIPVoidContinuationBox()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<Void, Error>) in
                box.install(continuation)
                connection.send(content: data, completion: .contentProcessed {
                    error in
                    if let error {
                        box.resume(
                            throwing: PTPIPError.connectionFailed(
                                error.localizedDescription
                            )
                        )
                    } else {
                        box.resume()
                    }
                })
            }
        } onCancel: {
            box.resume(
                throwing: PTPIPError.connectionFailed("发送操作已取消")
            )
            connection.cancel()
        }
    }

    private func receivePacket(
        on connection: NWConnection
    ) async throws -> (type: UInt32, data: Data) {
        let header = try await receiveExactly(8, on: connection)
        let length = Int(readUInt32(header, at: 0))
        guard length >= 8, length <= 64 * 1024 * 1024 else {
            throw PTPIPError.invalidPacket
        }
        let remainder = try await receiveExactly(length - 8, on: connection)
        var data = header
        data.append(remainder)
        return (readUInt32(header, at: 4), data)
    }

    private func receiveExactly(
        _ count: Int,
        on connection: NWConnection
    ) async throws -> Data {
        if count == 0 { return Data() }
        let box = PTPIPReceiveBox()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<Data, Error>) in
                box.install(continuation)
                var accumulated = Data()
                func pull() {
                    connection.receive(
                        minimumIncompleteLength: 1,
                        maximumLength: count - accumulated.count
                    ) { content, _, isComplete, error in
                        if let content {
                            accumulated.append(content)
                        }
                        if accumulated.count == count {
                            box.resume(returning: accumulated)
                        } else if let error {
                            box.resume(
                                throwing: PTPIPError.connectionFailed(
                                    error.localizedDescription
                                )
                            )
                        } else if isComplete {
                            box.resume(
                                throwing: PTPIPError.connectionFailed(
                                    "相机提前关闭了连接"
                                )
                            )
                        } else {
                            pull()
                        }
                    }
                }
                pull()
            }
        } onCancel: {
            // 竞速超时路径：让挂起的 receive 以超时错误结束。
            box.resume(
                throwing: PTPIPError.connectionFailed("心跳探测超时")
            )
            connection.cancel()
        }
    }

    private func packet(type: UInt32, payload: Data) -> Data {
        var data = Data()
        appendLE(UInt32(payload.count + 8), to: &data)
        appendLE(type, to: &data)
        data.append(payload)
        return data
    }

    private func appendUTF16(_ value: String, to data: inout Data) {
        value.utf16.forEach { appendLE($0, to: &data) }
        appendLE(UInt16(0), to: &data)
    }

    private func parseInitCommandAcknowledgment(
        _ data: Data
    ) -> (connectionNumber: UInt32, cameraName: String)? {
        // Header(8) + connection(4) + responder GUID(16) + UTF-16 NUL(2)
        // + protocol version(4).
        guard data.count >= 34 else { return nil }
        var terminatorOffset: Int?
        var offset = 28
        while offset + 1 < data.count {
            if readUInt16(data, at: offset) == 0 {
                terminatorOffset = offset
                break
            }
            offset += 2
        }
        guard let terminatorOffset,
              terminatorOffset + 6 == data.count,
              readUInt32(data, at: terminatorOffset + 2) == 0x0001_0000,
              let cameraName = String(
                data: data.subdata(in: 28..<terminatorOffset),
                encoding: .utf16LittleEndian
              ) else { return nil }
        return (
            connectionNumber: readUInt32(data, at: 8),
            cameraName: cameraName
        )
    }

    private func appendLE<T: FixedWidthInteger>(
        _ value: T,
        to data: inout Data
    ) {
        var little = value.littleEndian
        withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
    }

    private func readUInt16(_ data: Data, at offset: Int) -> UInt16 {
        UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    }

    private func readUInt32(_ data: Data, at offset: Int) -> UInt32 {
        UInt32(data[offset])
            | (UInt32(data[offset + 1]) << 8)
            | (UInt32(data[offset + 2]) << 16)
            | (UInt32(data[offset + 3]) << 24)
    }

    private func readUInt64(_ data: Data, at offset: Int) -> UInt64 {
        UInt64(readUInt32(data, at: offset))
            | (UInt64(readUInt32(data, at: offset + 4)) << 32)
    }
}

enum WifiConnectionMode: String, CaseIterable, Identifiable {
    case ap
    case sta

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ap: return "AP 直连"
        case .sta: return "STA 局域网"
        }
    }

    var guidance: String {
        switch self {
        case .ap:
            return "AP 模式：让本机加入相机热点；相机地址通常为 192.168.1.1。"
        case .sta:
            return "STA 模式：让相机与本机加入同一局域网，并输入路由器分配给相机的 IP 地址。"
        }
    }
}

@MainActor
final class WifiCameraService: ObservableObject {
    enum State: Equatable {
        case disconnected
        case connecting
        case ready
        case reconnecting(attempt: Int)
        case failed(String)

        var isReconnecting: Bool {
            if case .reconnecting = self { return true }
            return false
        }
    }

    @Published private(set) var state: State = .disconnected
    @Published private(set) var status = "Wi‑Fi 相机未连接"
    @Published private(set) var cameraName = "—"
    @Published var connectionMode: WifiConnectionMode {
        didSet {
            UserDefaults.standard.set(
                connectionMode.rawValue,
                forKey: "wifiCameraConnectionMode"
            )
        }
    }
    @Published var host: String {
        didSet { UserDefaults.standard.set(host, forKey: "wifiCameraHost") }
    }
    @Published var portText: String {
        didSet { UserDefaults.standard.set(portText, forKey: "wifiCameraPort") }
    }

    // MARK: - C3 能力扩展状态（实时取景 / 录像 / 参数）
    @Published private(set) var vendor: PTPIPCameraVendor = .unknown
    @Published private(set) var supportsMovieRecording = false
    @Published private(set) var isRecording = false
    @Published private(set) var liveViewFrame: CGImage?
    @Published private(set) var liveViewStatus = ""
    @Published private(set) var isoValue = 0
    @Published private(set) var apertureValue: Float = 0
    /// 快门速度（秒）。0 表示未知/未读取。
    @Published private(set) var shutterSpeedValue: Double = 0

    /// E3 1.5.9：连接/重连成功后是否自动开实时取景并拉帧（约 10fps）。
    /// iOS 默认 true（监看页常驻）；macOS 由 UI 显式控制（MonitorView
    /// onAppear/onDisappear 调 start/stopLiveViewIfNeeded），连接时不白拉帧。
    var autoStartLiveViewOnConnect = true

    var onShutterTriggered: (() -> Void)?

    /// E5 1.5.9：live 图（路线 B）——Wi‑Fi PTP 取景帧的 JPEG 喂帧回调，
    /// 由宿主端（iOS/macOS）注入 LivePhotoClipRecorder 的环形缓冲。
    /// TBC-awaiting-hardware。
    var livePhotoFrameSink: ((Data) -> Void)?

    private let session = PTPIPSession()
    private var connectionTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var liveViewTask: Task<Void, Never>?
    private var pathMonitor: NWPathMonitor?
    private var pathMonitorGeneration: UInt64 = 0
    private var lastPathSatisfied: Bool?
    private var expediteNextReconnect = false
    private var manualDisconnect = false
    private var missedHeartbeats = 0
    private var reconnectAttempt = 0
    /// UI 连接生命周期代际，同时也是 PTPIPSession 的所有权 token。每次初连、
    /// 重连调度或手动断开都先递增；旧 Task 的迟到清理只能关闭自己拥有的会话。
    private var connectionGeneration: UInt64 = 0
    private var activeSessionAttempt: UInt64?
    private var liveViewGeneration: UInt64 = 0

    // B2 保活参数（契约测试锚点，勿改数值）：
    // 心跳间隔 5s / 单次探测超时 3s / 连续 3 次判离线 /
    // 退避 1/2/4/8/16 封顶 30s。
    static let heartbeatIntervalSeconds: UInt64 = 5
    static let probeTimeoutMilliseconds: UInt64 = 3000
    static let offlineThreshold = 3
    static let reconnectMaxDelaySeconds: UInt64 = 30

    init() {
        connectionMode = WifiConnectionMode(
            rawValue: UserDefaults.standard.string(
                forKey: "wifiCameraConnectionMode"
            ) ?? ""
        ) ?? .ap
        host = UserDefaults.standard.string(forKey: "wifiCameraHost")
            ?? "192.168.1.1"
        portText = UserDefaults.standard.string(forKey: "wifiCameraPort")
            ?? "15740"
    }

    var isConnected: Bool { state == .ready }
    var isLiveViewActive: Bool { liveViewTask != nil }

    @discardableResult
    private func beginSessionAttempt() -> UInt64 {
        connectionGeneration &+= 1
        activeSessionAttempt = connectionGeneration
        return connectionGeneration
    }

    private func isCurrentSessionAttempt(_ attempt: UInt64) -> Bool {
        connectionGeneration == attempt && activeSessionAttempt == attempt
    }

    private func withSessionOwnership<T>(
        _ attempt: UInt64,
        operation: () async throws -> T
    ) async rethrows -> T {
        try await PTPIPSessionOwnership.$attempt.withValue(attempt) {
            try await operation()
        }
    }

    func connect() {
        guard state != .connecting else { return }
        guard let port = UInt16(portText) else {
            state = .failed("端口无效")
            status = PTPIPError.invalidEndpoint.localizedDescription
            return
        }
        manualDisconnect = false
        let previousOwner = activeSessionAttempt
        connectionTask?.cancel()
        reconnectTask?.cancel()
        heartbeatTask?.cancel()
        stopPathMonitor()
        stopLiveViewIfNeeded(ifOwnedBy: previousOwner)
        missedHeartbeats = 0
        reconnectAttempt = 0
        expediteNextReconnect = false
        vendor = .unknown
        supportsMovieRecording = false
        isRecording = false
        liveViewFrame = nil
        liveViewStatus = ""
        isoValue = 0
        apertureValue = 0
        shutterSpeedValue = 0
        state = .connecting
        status = "正在连接 Wi‑Fi 相机…"
        let attempt = beginSessionAttempt()
        let endpointHost = host.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        connectionTask = Task { [weak self] in
            guard let self else { return }
            await self.withSessionOwnership(attempt) {
                guard !Task.isCancelled,
                      self.isCurrentSessionAttempt(attempt),
                      !self.manualDisconnect else { return }
                do {
                    let name = try await self.session.connect(
                        host: endpointHost,
                        port: port
                    )
                    guard !Task.isCancelled,
                          self.isCurrentSessionAttempt(attempt),
                          !self.manualDisconnect else {
                        await self.session.disconnect(ifOwnedBy: attempt)
                        return
                    }
                    let vendor = try await self.session.detectVendor(using: name)
                    guard !Task.isCancelled,
                          self.isCurrentSessionAttempt(attempt),
                          !self.manualDisconnect else {
                        await self.session.disconnect(ifOwnedBy: attempt)
                        return
                    }
                    try await self.session.assertHealthy(
                        timeoutMilliseconds: Self.probeTimeoutMilliseconds
                    )
                    guard !Task.isCancelled,
                          self.isCurrentSessionAttempt(attempt),
                          !self.manualDisconnect else {
                        await self.session.disconnect(ifOwnedBy: attempt)
                        return
                    }
                    self.cameraName = name
                    self.vendor = vendor
                    self.supportsMovieRecording =
                        vendor == .nikon || vendor == .canon
                    self.state = .ready
                    self.status = "Wi‑Fi 已连接 · \(name)"
                    self.startHeartbeat()
                    self.startPathMonitor()
                    if vendor != .unknown {
                        if self.autoStartLiveViewOnConnect {
                            self.startLiveViewIfNeeded()
                        }
                        self.refreshParameters()
                    }
                } catch {
                    let failure = error.localizedDescription
                    // connect 已可能发布了完整双通道；厂商识别失败
                    // 也必须先按 attempt 收回会话，不留下幽灵 socket。
                    await self.session.disconnect(ifOwnedBy: attempt)
                    guard !Task.isCancelled,
                          self.isCurrentSessionAttempt(attempt),
                          !self.manualDisconnect else { return }
                    self.activeSessionAttempt = nil
                    self.cameraName = "—"
                    self.state = .failed(failure)
                    self.status = failure
                }
            }
        }
    }

    func disconnect() {
        connectionGeneration &+= 1
        let ownedAttempt = activeSessionAttempt
        activeSessionAttempt = nil
        manualDisconnect = true
        connectionTask?.cancel()
        connectionTask = nil
        heartbeatTask?.cancel()
        heartbeatTask = nil
        reconnectTask?.cancel()
        reconnectTask = nil
        expediteNextReconnect = false
        stopPathMonitor()
        // 手动断连只启动一个 owned cleanup：先让在途取帧事务自然
        // 结束，再依次尝试停录像、停取景，最后拆除双通道。
        liveViewGeneration &+= 1
        let liveViewTaskToFinish = liveViewTask
        liveViewTask = nil
        liveViewFrame = nil
        let recordingVendor = self.vendor
        Task { [session] in
            guard let ownedAttempt else { return }
            await liveViewTaskToFinish?.value
            await PTPIPSessionOwnership.$attempt.withValue(ownedAttempt) {
                if recordingVendor == .nikon || recordingVendor == .canon {
                    try? await session.stopMovieRecording(
                        vendor: recordingVendor,
                        ifOwnedBy: ownedAttempt
                    )
                }
                await session.endLiveView(
                    vendor: recordingVendor,
                    ifOwnedBy: ownedAttempt
                )
                await session.disconnect(ifOwnedBy: ownedAttempt)
            }
        }
        vendor = .unknown
        supportsMovieRecording = false
        isRecording = false
        liveViewFrame = nil
        liveViewStatus = ""
        isoValue = 0
        apertureValue = 0
        shutterSpeedValue = 0
        state = .disconnected
        cameraName = "—"
        status = "Wi‑Fi 相机未连接"
    }

    // MARK: - B2 链路保活 + 自动重连

    /// 心跳循环：就绪态下每 5s 探测一次（串行于 PTPIPSession actor），
    /// 连续 3 次无响应判离线，进入退避重连。
    private func startHeartbeat() {
        heartbeatTask?.cancel()
        guard let sessionAttempt = activeSessionAttempt else { return }
        heartbeatTask = Task { [weak self] in
            guard let self else { return }
            await self.withSessionOwnership(sessionAttempt) {
                while !Task.isCancelled {
                    try? await Task.sleep(
                        nanoseconds: Self.heartbeatIntervalSeconds
                            * 1_000_000_000
                    )
                    guard !Task.isCancelled else { return }
                    guard self.state == .ready,
                          self.isCurrentSessionAttempt(sessionAttempt) else {
                        return
                    }
                    do {
                        try await self.session.probe(
                            timeoutMilliseconds: Self.probeTimeoutMilliseconds
                        )
                        guard self.isCurrentSessionAttempt(sessionAttempt) else {
                            return
                        }
                        self.missedHeartbeats = 0
                    } catch {
                        guard !Task.isCancelled,
                              self.isCurrentSessionAttempt(sessionAttempt) else {
                            return
                        }
                        self.missedHeartbeats += 1
                        if self.missedHeartbeats >= Self.offlineThreshold {
                            self.missedHeartbeats = 0
                            self.enterReconnecting()
                            return
                        }
                    }
                }
            }
        }
    }

    /// 判离线后进入 reconnecting：立即尝试一次重连，失败则指数退避。
    private func enterReconnecting() {
        guard case .ready = state else { return }
        // E2 1.5.9（pro 复审观察项④收口）：链路断开进入重连前先停实时取景，
        // 避免拉帧循环在已失效会话上继续空转。
        stopLiveViewIfNeeded()
        state = .reconnecting(attempt: reconnectAttempt)
        status = "Wi‑Fi 链路已断开，正在自动重连…"
        scheduleReconnect()
    }

    private func scheduleReconnect() {
        reconnectTask?.cancel()
        let retryNumber = reconnectAttempt + 1
        reconnectAttempt = retryNumber
        let delay = expediteNextReconnect
            ? 0
            : Self.backoffDelay(forAttempt: retryNumber)
        expediteNextReconnect = false
        let previousOwner = activeSessionAttempt
        let sessionAttempt = beginSessionAttempt()
        let endpointHost = host.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        reconnectTask = Task { [weak self] in
            guard let self else { return }
            if let previousOwner {
                await self.session.disconnect(ifOwnedBy: previousOwner)
            }
            await self.withSessionOwnership(sessionAttempt) {
                guard !Task.isCancelled,
                      self.isCurrentSessionAttempt(sessionAttempt),
                      !self.manualDisconnect else { return }
                do {
                    try await Task.sleep(nanoseconds: delay * 1_000_000_000)
                    guard !Task.isCancelled,
                          self.isCurrentSessionAttempt(sessionAttempt),
                          !self.manualDisconnect else { return }
                    self.state = .reconnecting(attempt: retryNumber)
                    self.status = "正在重连 Wi‑Fi 相机（第 \(retryNumber) 次）…"
                    let port = UInt16(self.portText)
                    guard let port else {
                        self.activeSessionAttempt = nil
                        self.state = .failed("端口无效")
                        return
                    }
                    let name = try await self.session.connect(
                        host: endpointHost,
                        port: port
                    )
                    guard !Task.isCancelled,
                          self.isCurrentSessionAttempt(sessionAttempt),
                          !self.manualDisconnect else {
                        await self.session.disconnect(ifOwnedBy: sessionAttempt)
                        return
                    }
                    let vendor = try await self.session.detectVendor(using: name)
                    guard !Task.isCancelled,
                          self.isCurrentSessionAttempt(sessionAttempt),
                          !self.manualDisconnect else {
                        await self.session.disconnect(ifOwnedBy: sessionAttempt)
                        return
                    }
                    try await self.session.assertHealthy(
                        timeoutMilliseconds: Self.probeTimeoutMilliseconds
                    )
                    guard !Task.isCancelled,
                          self.isCurrentSessionAttempt(sessionAttempt),
                          !self.manualDisconnect else {
                        await self.session.disconnect(ifOwnedBy: sessionAttempt)
                        return
                    }
                    self.reconnectAttempt = 0
                    self.cameraName = name
                    self.vendor = vendor
                    self.supportsMovieRecording =
                        vendor == .nikon || vendor == .canon
                    self.state = .ready
                    self.status = "Wi‑Fi 已重连 · \(name)"
                    self.startHeartbeat()
                    self.startPathMonitor()
                    if vendor != .unknown {
                        if self.autoStartLiveViewOnConnect {
                            self.startLiveViewIfNeeded()
                        }
                        self.refreshParameters()
                    }
                } catch {
                    guard !Task.isCancelled,
                          self.isCurrentSessionAttempt(sessionAttempt),
                          !self.manualDisconnect else {
                        await self.session.disconnect(ifOwnedBy: sessionAttempt)
                        return
                    }
                    self.state = .reconnecting(attempt: retryNumber)
                    self.status = "Wi‑Fi 重连失败：\(error.localizedDescription)"
                    self.scheduleReconnect()
                }
            }
        }
    }

    /// 指数退避（纯函数，契约测试锚点）：1/2/4/8/16 封顶 30s。
    static func backoffDelay(forAttempt attempt: Int) -> UInt64 {
        let exponent = UInt64(max(0, attempt - 1))
        let doubled: UInt64
        if exponent >= 30 {
            doubled = UInt64.max
        } else {
            doubled = 1 << exponent
        }
        return min(doubled, reconnectMaxDelaySeconds)
    }

    // MARK: - B2 网络层监听

    /// iOS 只监听 Wi-Fi 路径，避免蜂窝网络仍可用时掩盖相机热点断开；
    /// macOS 保留默认路径以兼容经以太网访问相机。回调同时绑定会话 attempt。
    private func startPathMonitor() {
        stopPathMonitor()
        guard let monitoredAttempt = activeSessionAttempt else { return }
        let monitorGeneration = pathMonitorGeneration
#if os(iOS)
        let monitor = NWPathMonitor(requiredInterfaceType: .wifi)
#else
        let monitor = NWPathMonitor()
#endif
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                guard let self,
                      !self.manualDisconnect,
                      self.pathMonitorGeneration == monitorGeneration,
                      self.isCurrentSessionAttempt(monitoredAttempt) else {
                    return
                }
                let wasSatisfied = self.lastPathSatisfied
                let isSatisfied = path.status == .satisfied
                self.lastPathSatisfied = isSatisfied
                if path.status != .satisfied {
                    self.missedHeartbeats = 0
                    self.enterReconnecting()
                } else if wasSatisfied == false,
                          self.state.isReconnecting {
                    // 网络已恢复时不继续空等原先的指数退避。
                    self.expediteNextReconnect = true
                    self.scheduleReconnect()
                }
            }
        }
        monitor.start(queue: DispatchQueue(
            label: "com.tauber.nikonlink.wifi.path"
        ))
        pathMonitor = monitor
    }

    private func stopPathMonitor() {
        pathMonitorGeneration &+= 1
        lastPathSatisfied = nil
        pathMonitor?.cancel()
        pathMonitor = nil
    }

    func capture() {
        guard isConnected, let sessionAttempt = activeSessionAttempt else {
            status = "请先连接 Wi‑Fi 相机"
            return
        }
        status = "正在通过 Wi‑Fi 触发快门…"
        Task { [weak self] in
            guard let self else { return }
            await self.withSessionOwnership(sessionAttempt) {
                do {
                    try await self.session.capture()
                    guard self.isCurrentSessionAttempt(sessionAttempt) else {
                        return
                    }
                    self.status = "Wi‑Fi 快门已触发 · 原图保存在相机卡内"
                    self.onShutterTriggered?()
                } catch {
                    guard self.isCurrentSessionAttempt(sessionAttempt) else {
                        return
                    }
                    self.status = error.localizedDescription
                    if case PTPIPError.rejected(let code) = error {
                        guard PTPIPError.isSessionFatalResponse(code) else {
                            return
                        }
                    }
                    self.enterReconnecting()
                }
            }
        }
    }

    // MARK: - C3 实时取景

    /// 连接就绪后自动开实时取景：约 10fps 拉帧，单帧失败退避 300ms 重试。
    /// 佳能路径 TBC-awaiting-hardware（与 C2 序列一致）。
    func startLiveViewIfNeeded() {
        guard isConnected,
              vendor != .unknown,
              liveViewTask == nil,
              let sessionAttempt = activeSessionAttempt else { return }
        liveViewGeneration &+= 1
        let viewGeneration = liveViewGeneration
        liveViewTask = Task { [weak self] in
            guard let self else { return }
            let vendor = self.vendor
            await self.withSessionOwnership(sessionAttempt) {
                do {
                    try await self.session.startLiveView(vendor: vendor)
                } catch {
                    guard self.isCurrentSessionAttempt(sessionAttempt),
                          self.liveViewGeneration == viewGeneration else { return }
                    self.liveViewStatus = error.localizedDescription
                    self.liveViewTask = nil
                    return
                }
                guard self.isCurrentSessionAttempt(sessionAttempt),
                      self.liveViewGeneration == viewGeneration else { return }
                self.liveViewStatus = ""
                while !Task.isCancelled {
                    guard self.isCurrentSessionAttempt(sessionAttempt),
                          self.liveViewGeneration == viewGeneration else {
                        return
                    }
                    do {
                        let jpeg = try await self.session.getLiveViewFrame(
                            vendor: vendor
                        )
                        guard self.isCurrentSessionAttempt(sessionAttempt),
                              self.liveViewGeneration == viewGeneration else {
                            return
                        }
                        // E5 1.5.9：live 图环形缓冲喂帧（宿主端注入，仅当开关开启）。
                        self.livePhotoFrameSink?(jpeg)
                        if let frame = Self.decodeLiveViewJPEG(jpeg) {
                            self.liveViewFrame = frame
                        }
                        try await Task.sleep(nanoseconds: 100_000_000)
                    } catch {
                        guard !Task.isCancelled,
                              self.isCurrentSessionAttempt(sessionAttempt),
                              self.liveViewGeneration == viewGeneration else {
                            return
                        }
                        try? await Task.sleep(nanoseconds: 300_000_000)
                    }
                }
            }
        }
    }

    func stopLiveViewIfNeeded(ifOwnedBy explicitAttempt: UInt64? = nil) {
        liveViewGeneration &+= 1
        let stoppingGeneration = liveViewGeneration
        let taskToFinish = liveViewTask
        liveViewTask = nil
        liveViewFrame = nil
        let vendor = self.vendor
        let ownedAttempt = explicitAttempt ?? activeSessionAttempt
        Task { [weak self] in
            guard let self, let ownedAttempt else { return }
            // 不取消正在读取共用 command stream 的取帧 Task；让有 deadline 的
            // 当前事务自然结束，避免取消处理直接关闭健康 socket。若期间又启动
            // 了新取景，旧 stop 也不得迟到关闭它。
            await taskToFinish?.value
            guard self.liveViewGeneration == stoppingGeneration else { return }
            await self.withSessionOwnership(ownedAttempt) {
                await self.session.endLiveView(
                    vendor: vendor,
                    ifOwnedBy: ownedAttempt
                )
            }
        }
    }

    /// 解码实时取景 JPEG 帧为可显示位图。
    private static func decodeLiveViewJPEG(_ data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil)
        else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    // MARK: - C3 录像启停

    /// Wi‑Fi 录像开关：尼康 0x920a/0x920b，佳能 EVFRecordStatus
    /// （TBC-awaiting-hardware）。文件保存在相机卡内，不走外录。
    func toggleVideoRecording() {
        guard isConnected, let sessionAttempt = activeSessionAttempt else { return }
        if isRecording {
            let recordingVendor = self.vendor
            Task { [weak self] in
                guard let self else { return }
                await self.withSessionOwnership(sessionAttempt) {
                    do {
                        try await self.session.stopMovieRecording(
                            vendor: recordingVendor,
                            ifOwnedBy: sessionAttempt
                        )
                        guard self.isCurrentSessionAttempt(sessionAttempt) else {
                            return
                        }
                        self.isRecording = false
                        self.status = "Wi‑Fi 录像已停止"
                    } catch {
                        guard self.isCurrentSessionAttempt(sessionAttempt) else {
                            return
                        }
                        self.status = error.localizedDescription
                    }
                }
            }
        } else {
            guard supportsMovieRecording else {
                status = "已连相机暂不支持 PTP/IP 远程录像"
                return
            }
            Task { [weak self] in
                guard let self else { return }
                let recordingVendor = self.vendor
                await self.withSessionOwnership(sessionAttempt) {
                    do {
                        try await self.session.startMovieRecording(
                            vendor: recordingVendor
                        )
                        guard self.isCurrentSessionAttempt(sessionAttempt) else {
                            return
                        }
                        self.isRecording = true
                        self.status = "Wi‑Fi 录像中 · 文件保存在相机卡内"
                    } catch {
                        guard self.isCurrentSessionAttempt(sessionAttempt) else {
                            return
                        }
                        self.status = error.localizedDescription
                    }
                }
            }
        }
    }

    // MARK: - C3 参数读写（ISO / 光圈 / 快门）

    /// 从相机读取常用参数（GetDevicePropValue 0x1015）。单属性失败不阻断
    /// 其余属性（部分机型不暴露个别属性）。
    func refreshParameters() {
        guard isConnected, let sessionAttempt = activeSessionAttempt else { return }
        Task { [weak self] in
            guard let self else { return }
            await self.withSessionOwnership(sessionAttempt) {
                if let iso = try? await self.session.readProperty(
                    PTPIPVendorOps.propISO
                ), let value = Self.leUInt16(iso), value > 0,
                   self.isCurrentSessionAttempt(sessionAttempt) {
                    self.isoValue = Int(value)
                }
                if let fNumber = try? await self.session.readProperty(
                    PTPIPVendorOps.propFNumber
                ), let value = Self.leUInt16(fNumber), value > 0,
                   self.isCurrentSessionAttempt(sessionAttempt) {
                    self.apertureValue = Float(value) / 100
                }
                if let exposure = try? await self.session.readProperty(
                    PTPIPVendorOps.propExposureTime
                ), let value = Self.leUInt32(exposure), value > 0,
                   self.isCurrentSessionAttempt(sessionAttempt) {
                    self.shutterSpeedValue = Double(value) / 10000
                }
            }
        }
    }

    func stepISO(_ direction: Int) {
        let values = [64, 80, 100, 125, 160, 200, 250, 320, 400, 500, 640,
                      800, 1000, 1250, 1600, 2000, 2500, 3200, 4000, 5000,
                      6400, 8000, 10000, 12800, 16000, 20000, 25600, 32000,
                      40000, 51200, 64000, 102400]
        let current = values.enumerated().min {
            abs($0.element - isoValue) < abs($1.element - isoValue)
        }?.offset ?? 0
        let next = min(max(current + direction, 0), values.count - 1)
        let payload = Self.le16(UInt16(values[next]))
        writeParameter(PTPIPVendorOps.propISO, payload: payload, label: "ISO")
    }

    func stepAperture(_ direction: Int) {
        let values: [Float] = [1.4, 1.6, 1.8, 2, 2.2, 2.5, 2.8, 3.2, 3.5, 4,
                               4.5, 5, 5.6, 6.3, 7.1, 8, 9, 10, 11, 13, 14,
                               16, 18, 20, 22]
        let current = values.enumerated().min {
            abs($0.element - apertureValue) < abs($1.element - apertureValue)
        }?.offset ?? 0
        let next = min(max(current + direction, 0), values.count - 1)
        let payload = Self.le16(UInt16((values[next] * 100).rounded()))
        writeParameter(PTPIPVendorOps.propFNumber, payload: payload, label: "光圈")
    }

    func stepShutterSpeed(_ direction: Int) {
        let denominators: [Double] = [8000, 4000, 2000, 1000, 500, 250, 125,
                                      60, 30, 15, 8, 4, 2, 1]
        let current = denominators.enumerated().min {
            abs(1.0 / $0.element - shutterSpeedValue)
                < abs(1.0 / $1.element - shutterSpeedValue)
        }?.offset ?? 6
        let next = min(max(current + direction, 0), denominators.count - 1)
        let seconds = 1.0 / denominators[next]
        let payload = Self.le32(UInt32((seconds * 10000).rounded()))
        writeParameter(
            PTPIPVendorOps.propExposureTime,
            payload: payload,
            label: "快门"
        )
    }

    private func writeParameter(
        _ property: UInt16,
        payload: Data,
        label: String
    ) {
        guard isConnected, let sessionAttempt = activeSessionAttempt else { return }
        Task { [weak self] in
            guard let self else { return }
            await self.withSessionOwnership(sessionAttempt) {
                do {
                    try await self.session.writeProperty(property, value: payload)
                    guard self.isCurrentSessionAttempt(sessionAttempt) else {
                        return
                    }
                    self.status = "Wi‑Fi \(label)已写入 · 相机已更新"
                    self.refreshParameters()
                } catch {
                    guard self.isCurrentSessionAttempt(sessionAttempt) else {
                        return
                    }
                    self.status =
                        "Wi‑Fi \(label)写入失败：\(error.localizedDescription)"
                }
            }
        }
    }

    private static func le16(_ value: UInt16) -> Data {
        var data = Data()
        data.append(UInt8(value & 0xFF))
        data.append(UInt8((value >> 8) & 0xFF))
        return data
    }

    private static func le32(_ value: UInt32) -> Data {
        var data = Data()
        data.append(UInt8(value & 0xFF))
        data.append(UInt8((value >> 8) & 0xFF))
        data.append(UInt8((value >> 16) & 0xFF))
        data.append(UInt8((value >> 24) & 0xFF))
        return data
    }

    private static func leUInt16(_ data: Data) -> UInt16? {
        guard data.count >= 2 else { return nil }
        return UInt16(data[0]) | (UInt16(data[1]) << 8)
    }

    private static func leUInt32(_ data: Data) -> UInt32? {
        guard data.count >= 4 else { return nil }
        return UInt32(data[0])
            | (UInt32(data[1]) << 8)
            | (UInt32(data[2]) << 16)
            | (UInt32(data[3]) << 24)
    }

    func listStorage() async throws -> CameraStorageSnapshot {
        guard isConnected, let sessionAttempt = activeSessionAttempt else {
            throw PTPIPError.notConnected
        }
        return try await withSessionOwnership(sessionAttempt) {
            try await session.listStorage()
        }
    }

    func storageThumbnail(handle: UInt32) async throws -> Data {
        guard isConnected, let sessionAttempt = activeSessionAttempt else {
            throw PTPIPError.notConnected
        }
        return try await withSessionOwnership(sessionAttempt) {
            try await session.storageThumbnail(handle: handle)
        }
    }

    func storageObject(handle: UInt32) async throws -> Data {
        guard isConnected, let sessionAttempt = activeSessionAttempt else {
            throw PTPIPError.notConnected
        }
        return try await withSessionOwnership(sessionAttempt) {
            try await session.storageObject(handle: handle)
        }
    }

    func deleteStorageObject(handle: UInt32) async throws {
        guard isConnected, let sessionAttempt = activeSessionAttempt else {
            throw PTPIPError.notConnected
        }
        try await withSessionOwnership(sessionAttempt) {
            try await session.deleteStorageObject(handle: handle)
        }
    }
}
