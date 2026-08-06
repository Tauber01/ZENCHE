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

/// 单次续体容器：保证 receive 回调与 onCancel 竞速时只恢复一次，
/// 且 onCancel（Task 取消路径）也能拿到 continuation 主动恢复。
private final class PTPIPReceiveBox: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Data, Error>?
    private var finished = false

    func install(_ continuation: CheckedContinuation<Data, Error>) {
        lock.lock()
        defer { lock.unlock() }
        self.continuation = continuation
    }

    func resume(returning value: Data) {
        lock.lock()
        defer { lock.unlock() }
        guard !finished, let continuation else { return }
        finished = true
        self.continuation = nil
        continuation.resume(returning: value)
    }

    func resume(throwing error: Error) {
        lock.lock()
        defer { lock.unlock() }
        guard !finished, let continuation else { return }
        finished = true
        self.continuation = nil
        continuation.resume(throwing: error)
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

private actor PTPIPSession {
    private var command: NWConnection?
    private var event: NWConnection?
    private var transactionID: UInt32 = 1
    // C3 状态：厂商识别结果与取景/录像标记（断连时清零）。
    private var detectedVendor: PTPIPCameraVendor = .unknown
    private var liveViewActive = false
    private var movieRecording = false

    func connect(host: String, port: UInt16) async throws -> String {
        await disconnect()
        guard let endpointPort = NWEndpoint.Port(rawValue: port),
              !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { throw PTPIPError.invalidEndpoint }

        let command = NWConnection(
            host: NWEndpoint.Host(host),
            port: endpointPort,
            using: .tcp
        )
        try await start(command)
        self.command = command

        var payload = Data()
        payload.append(contentsOf: withUnsafeBytes(of: UUID().uuid) {
            Array($0)
        })
        appendUTF16("ZENCHE", to: &payload)
        appendLE(UInt32(0x0001_0000), to: &payload)
        try await send(packet(type: 1, payload: payload), on: command)
        let acknowledgment = try await receivePacket(on: command)
        guard acknowledgment.type == 2,
              acknowledgment.data.count >= 28 else {
            throw PTPIPError.invalidPacket
        }
        let connectionNumber = readUInt32(acknowledgment.data, at: 8)
        let cameraName = readUTF16(acknowledgment.data, from: 28)

        let event = NWConnection(
            host: NWEndpoint.Host(host),
            port: endpointPort,
            using: .tcp
        )
        try await start(event)
        var eventPayload = Data()
        appendLE(connectionNumber, to: &eventPayload)
        try await send(packet(type: 3, payload: eventPayload), on: event)
        let eventAcknowledgment = try await receivePacket(on: event)
        guard eventAcknowledgment.type == 4 else {
            throw PTPIPError.invalidPacket
        }
        self.event = event

        let response = try await commandRequest(
            operation: 0x1002,
            transaction: 0,
            parameters: [1]
        )
        guard response == 0x2001 else {
            throw PTPIPError.rejected(response)
        }
        transactionID = 1
        return cameraName.isEmpty ? "PTP/IP Camera" : cameraName
    }

    func capture() async throws {
        guard command != nil else { throw PTPIPError.notConnected }
        let current = transactionID
        transactionID &+= 1
        let response = try await commandRequest(
            operation: 0x100E,
            transaction: current,
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
        try await dataRequest(operation: 0x1009, parameters: [handle])
    }

    func deleteStorageObject(handle: UInt32) async throws {
        let current = transactionID
        transactionID &+= 1
        let response = try await commandRequest(
            operation: 0x100B,
            transaction: current,
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
    func detectVendor(using cameraName: String) async -> PTPIPCameraVendor {
        if detectedVendor != .unknown { return detectedVendor }
        let nameBased = Self.vendor(forName: cameraName)
        var resolved = nameBased
        if let info = try? await dataRequest(
            operation: 0x1001,
            parameters: [1]
        ), let manufacturer = deviceInfoManufacturer(info) {
            resolved = Self.vendor(
                forManufacturer: manufacturer,
                fallback: nameBased
            )
        }
        detectedVendor = resolved
        return resolved
    }

    /// 实时取景开始。佳能侧按 C2 序列写 EVFMode/EVFOutputDevice（Busy 容忍，
    /// TBC-awaiting-hardware），数据帧走 GetViewFinderData(0x9153)；
    /// 其余厂商走尼康 0x9201。
    func startLiveView(vendor: PTPIPCameraVendor) async throws {
        guard command != nil else { throw PTPIPError.notConnected }
        if liveViewActive { return }
        if vendor == .canon {
            try? await canonWriteEosProp(PTPIPVendorOps.canonEVFMode, 1)
            try? await canonWriteEosProp(PTPIPVendorOps.canonEVFOutputDevice, 2)
        } else {
            let current = transactionID
            transactionID &+= 1
            let response = try await commandRequest(
                operation: PTPIPVendorOps.startLiveView,
                transaction: current,
                parameters: []
            )
            guard response == 0x2001 else {
                throw PTPIPError.rejected(response)
            }
        }
        liveViewActive = true
    }

    /// 实时取景结束（尽力而为，不抛错）。
    func endLiveView(vendor: PTPIPCameraVendor) async {
        guard command != nil else { return }
        defer { liveViewActive = false }
        if vendor == .canon {
            try? await canonWriteEosProp(PTPIPVendorOps.canonEVFOutputDevice, 0)
            try? await canonWriteEosProp(PTPIPVendorOps.canonEVFMode, 0)
        } else {
            let current = transactionID
            transactionID &+= 1
            _ = try? await commandRequest(
                operation: PTPIPVendorOps.endLiveView,
                transaction: current,
                parameters: []
            )
        }
    }

    /// 取一帧实时取景 JPEG。尼康 0x9203 / 佳能 0x9153（TBC-awaiting-hardware）。
    func getLiveViewFrame(vendor: PTPIPCameraVendor) async throws -> Data {
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
        guard command != nil else { throw PTPIPError.notConnected }
        if movieRecording { return }
        if vendor == .canon {
            try await startLiveView(vendor: .canon)
            try await canonWriteEosProp(PTPIPVendorOps.canonEVFRecordStatus, 1)
        } else {
            if !liveViewActive {
                try await startLiveView(vendor: vendor)
            }
            let current = transactionID
            transactionID &+= 1
            let response = try await commandRequest(
                operation: PTPIPVendorOps.startMovieRecording,
                transaction: current,
                parameters: []
            )
            guard response == 0x2001 else {
                throw PTPIPError.rejected(response)
            }
        }
        movieRecording = true
    }

    /// 停止录像。尼康 0x920b；佳能 EVFRecordStatus=0（TBC-awaiting-hardware）。
    func stopMovieRecording(vendor: PTPIPCameraVendor) async throws {
        guard command != nil else { throw PTPIPError.notConnected }
        defer { movieRecording = false }
        if vendor == .canon {
            try await canonWriteEosProp(PTPIPVendorOps.canonEVFRecordStatus, 0)
        } else {
            let current = transactionID
            transactionID &+= 1
            let response = try await commandRequest(
                operation: PTPIPVendorOps.endMovieRecording,
                transaction: current,
                parameters: []
            )
            guard response == 0x2001 else {
                throw PTPIPError.rejected(response)
            }
        }
    }

    /// 读取设备属性原始值（GetDevicePropValue 0x1015）。
    func readProperty(_ property: UInt16) async throws -> Data {
        guard command != nil else { throw PTPIPError.notConnected }
        return try await dataRequest(
            operation: PTPIPVendorOps.getDevicePropValue,
            parameters: [UInt32(property)]
        )
    }

    /// 读取设备属性描述符（GetDevicePropDesc 0x1014），用于校验可写性。
    func readPropertyDescriptor(_ property: UInt16) async throws -> Data {
        guard command != nil else { throw PTPIPError.notConnected }
        return try await dataRequest(
            operation: PTPIPVendorOps.getDevicePropDesc,
            parameters: [UInt32(property)]
        )
    }

    /// 写入设备属性（SetDevicePropValue 0x1016，数据段携带属性值）。
    func writeProperty(_ property: UInt16, value: Data) async throws {
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
        guard let command else { throw PTPIPError.notConnected }
        let current = transactionID
        transactionID &+= 1
        var payload = Data()
        appendLE(UInt32(2), to: &payload)
        appendLE(operation, to: &payload)
        appendLE(current, to: &payload)
        parameters.forEach { appendLE($0, to: &payload) }
        try await send(packet(type: 6, payload: payload), on: command)

        var startPayload = Data()
        appendLE(UInt32(0), to: &startPayload)
        appendLE(current, to: &startPayload)
        appendLE(UInt64(data.count), to: &startPayload)
        startPayload.append(data)
        try await send(packet(type: 9, payload: startPayload), on: command)

        var endPayload = Data()
        appendLE(UInt32(0), to: &endPayload)
        appendLE(current, to: &endPayload)
        try await send(packet(type: 12, payload: endPayload), on: command)

        let response = try await receivePacket(on: command)
        guard response.type == 7, response.data.count >= 14 else {
            throw PTPIPError.invalidPacket
        }
        return readUInt16(response.data, at: 8)
    }

    // MARK: - C3 厂商识别解析

    /// 从 GetDeviceInfo 数据段解析厂商名（Manufacturer，UTF-8）。
    /// 布局：StandardVersion(2)+VendorExtensionID(4)+VendorExtensionVersion(2)+
    /// VendorExtensionDesc(UTF8)+FunctionalMode(2)+五个数组(各 2 字节长度+条目)+
    /// Manufacturer(UTF8)+Model(UTF8)+DeviceVersion(UTF8)+SerialNumber(UTF8)。
    private func deviceInfoManufacturer(_ data: Data) -> String? {
        guard data.count >= 8 else { return nil }
        var offset = 8
        guard Self.readUTF8(data, &offset) != nil else { return nil }  // VendorExtensionDesc
        guard offset + 2 <= data.count else { return nil }
        offset += 2  // FunctionalMode
        for _ in 0..<4 {  // Operations/Events/DeviceProperties/CaptureFormats
            guard offset + 2 <= data.count else { return nil }
            let count = Int(readUInt16(data, at: offset))
            offset += 2
            guard offset + count * 2 <= data.count else { return nil }
            offset += count * 2
        }
        guard offset + 2 <= data.count else { return nil }
        let imageCount = Int(readUInt16(data, at: offset))  // ImageFormats
        offset += 2
        guard offset + imageCount * 2 <= data.count else { return nil }
        offset += imageCount * 2
        return Self.readUTF8(data, &offset)
    }

    private static func readUTF8(_ data: Data, _ offset: inout Int) -> String? {
        guard offset < data.count else { return nil }
        var end = offset
        while end < data.count, data[end] != 0 { end += 1 }
        guard end < data.count else { return nil }
        let text = String(data: data[offset..<end], encoding: .utf8)
        offset = end + 1
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

    func disconnect() async {
        command?.cancel()
        event?.cancel()
        command = nil
        event = nil
        transactionID = 1
        // C3 会话状态复位（取景/录像/厂商识别随连接一起清空）。
        liveViewActive = false
        movieRecording = false
        detectedVendor = .unknown
    }

    /// 无副作用链路探测：GetDeviceInfo（0x1002）并等待 OK，用于心跳保活。
    /// 超时通过竞速实现：NWConnection 的 receive 无超时参数，故用 Task 竞速。
    func probe(timeoutMilliseconds: UInt64 = 3000) async throws {
        guard command != nil else { throw PTPIPError.notConnected }
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                let response = try await self.commandRequest(
                    operation: 0x1002,
                    transaction: 0,
                    parameters: [1]
                )
                guard response == 0x2001 else {
                    throw PTPIPError.rejected(response)
                }
            }
            group.addTask {
                try await Task.sleep(
                    nanoseconds: timeoutMilliseconds * 1_000_000
                )
                throw PTPIPError.connectionFailed("心跳探测超时")
            }
            _ = try await group.next()
            group.cancelAll()
        }
    }

    private func commandRequest(
        operation: UInt16,
        transaction: UInt32,
        parameters: [UInt32]
    ) async throws -> UInt16 {
        guard let command else { throw PTPIPError.notConnected }
        var payload = Data()
        appendLE(UInt32(1), to: &payload)
        appendLE(operation, to: &payload)
        appendLE(transaction, to: &payload)
        parameters.forEach { appendLE($0, to: &payload) }
        try await send(packet(type: 6, payload: payload), on: command)
        let response = try await receivePacket(on: command)
        guard response.type == 7, response.data.count >= 14 else {
            throw PTPIPError.invalidPacket
        }
        return readUInt16(response.data, at: 8)
    }

    private func dataRequest(
        operation: UInt16,
        parameters: [UInt32]
    ) async throws -> Data {
        guard let command else { throw PTPIPError.notConnected }
        let current = transactionID
        transactionID &+= 1
        var payload = Data()
        // PTP/IP value 1 is used for data-in and no-data operations.
        appendLE(UInt32(1), to: &payload)
        appendLE(operation, to: &payload)
        appendLE(current, to: &payload)
        parameters.forEach { appendLE($0, to: &payload) }
        try await send(packet(type: 6, payload: payload), on: command)

        let first = try await receivePacket(on: command)
        if first.type == 7 {
            let response = first.data.count >= 10
                ? readUInt16(first.data, at: 8)
                : UInt16(0x2002)
            throw PTPIPError.rejected(response)
        }
        guard first.type == 9,
              first.data.count >= 20,
              readUInt32(first.data, at: 8) == current else {
            throw PTPIPError.invalidPacket
        }
        let announcedLength = readUInt64(first.data, at: 12)
        let maximumObjectBytes = UInt64(512 * 1024 * 1024)
        guard announcedLength <= maximumObjectBytes else {
            throw PTPIPError.connectionFailed(
                "机内文件超过当前 512 MB 单文件传输上限"
            )
        }
        var data = Data()
        data.reserveCapacity(Int(min(announcedLength, 8 * 1024 * 1024)))
        while true {
            let packet = try await receivePacket(on: command)
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
        let response = try await receivePacket(on: command)
        guard response.type == 7, response.data.count >= 14 else {
            throw PTPIPError.invalidPacket
        }
        let code = readUInt16(response.data, at: 8)
        guard code == 0x2001 else { throw PTPIPError.rejected(code) }
        return data
    }

    private func start(_ connection: NWConnection) async throws {
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in
            let gate = PTPIPContinuationGate()
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    guard gate.claim() else { return }
                    continuation.resume()
                case .failed(let error), .waiting(let error):
                    guard gate.claim() else { return }
                    continuation.resume(
                        throwing: PTPIPError.connectionFailed(
                            error.localizedDescription
                        )
                    )
                case .cancelled:
                    guard gate.claim() else { return }
                    continuation.resume(
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
    }

    private func send(_ data: Data, on connection: NWConnection) async throws {
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed {
                error in
                if let error {
                    continuation.resume(
                        throwing: PTPIPError.connectionFailed(
                            error.localizedDescription
                        )
                    )
                } else {
                    continuation.resume()
                }
            })
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

    private func readUTF16(_ data: Data, from offset: Int) -> String {
        guard data.count > offset else { return "" }
        var values: [UInt16] = []
        var index = offset
        while index + 1 < data.count {
            let value = readUInt16(data, at: index)
            if value == 0 { break }
            values.append(value)
            index += 2
        }
        return String(decoding: values, as: UTF16.self)
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

    var onShutterTriggered: (() -> Void)?

    private let session = PTPIPSession()
    private var connectionTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var liveViewTask: Task<Void, Never>?
    private var pathMonitor: NWPathMonitor?
    private var manualDisconnect = false
    private var missedHeartbeats = 0
    private var reconnectAttempt = 0

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

    func connect() {
        guard state != .connecting else { return }
        guard let port = UInt16(portText) else {
            state = .failed("端口无效")
            status = PTPIPError.invalidEndpoint.localizedDescription
            return
        }
        manualDisconnect = false
        connectionTask?.cancel()
        reconnectTask?.cancel()
        heartbeatTask?.cancel()
        stopLiveViewIfNeeded()
        missedHeartbeats = 0
        reconnectAttempt = 0
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
        connectionTask = Task { [weak self] in
            guard let self else { return }
            do {
                let name = try await self.session.connect(
                    host: self.host.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ),
                    port: port
                )
                let vendor = await self.session.detectVendor(using: name)
                guard !Task.isCancelled else { return }
                self.cameraName = name
                self.vendor = vendor
                self.supportsMovieRecording = vendor == .nikon || vendor == .canon
                self.state = .ready
                self.status = "Wi‑Fi 已连接 · \(name)"
                self.startHeartbeat()
                self.startPathMonitor()
                if vendor != .unknown {
                    self.startLiveViewIfNeeded()
                    self.refreshParameters()
                }
            } catch {
                guard !Task.isCancelled else { return }
                self.cameraName = "—"
                self.state = .failed(error.localizedDescription)
                self.status = error.localizedDescription
            }
        }
    }

    func disconnect() {
        manualDisconnect = true
        connectionTask?.cancel()
        connectionTask = nil
        heartbeatTask?.cancel()
        heartbeatTask = nil
        reconnectTask?.cancel()
        reconnectTask = nil
        stopPathMonitor()
        stopLiveViewIfNeeded()
        let recordingVendor = self.vendor
        Task { [weak self] in
            guard let self else { return }
            if self.isRecording {
                try? await self.session.stopMovieRecording(vendor: recordingVendor)
            }
            await self.session.disconnect()
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
        heartbeatTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(
                    nanoseconds: Self.heartbeatIntervalSeconds * 1_000_000_000
                )
                guard !Task.isCancelled else { return }
                guard self.state == .ready else { return }
                do {
                    try await self.session.probe(
                        timeoutMilliseconds: Self.probeTimeoutMilliseconds
                    )
                    self.missedHeartbeats = 0
                } catch {
                    guard !Task.isCancelled else { return }
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
        let attempt = reconnectAttempt + 1
        reconnectAttempt = attempt
        let delay = Self.backoffDelay(forAttempt: attempt)
        reconnectTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(nanoseconds: delay * 1_000_000_000)
                guard !Task.isCancelled, !self.manualDisconnect else { return }
                self.state = .reconnecting(attempt: attempt)
                self.status = "正在重连 Wi‑Fi 相机（第 \(attempt) 次）…"
                let port = UInt16(self.portText)
                guard let port else {
                    self.state = .failed("端口无效")
                    return
                }
                do {
                    let name = try await self.session.connect(
                        host: self.host.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ),
                        port: port
                    )
                    let vendor = await self.session.detectVendor(using: name)
                    guard !Task.isCancelled else { return }
                    self.reconnectAttempt = 0
                    self.cameraName = name
                    self.vendor = vendor
                    self.supportsMovieRecording =
                        vendor == .nikon || vendor == .canon
                    self.state = .ready
                    self.status = "Wi‑Fi 已重连 · \(name)"
                    self.startHeartbeat()
                    if vendor != .unknown {
                        self.startLiveViewIfNeeded()
                        self.refreshParameters()
                    }
                } catch {
                    guard !Task.isCancelled, !self.manualDisconnect else { return }
                    self.state = .reconnecting(attempt: attempt)
                    self.status = "Wi‑Fi 重连失败：\(error.localizedDescription)"
                    self.scheduleReconnect()
                }
            } catch {
                // Task.sleep 被取消：重连调度已被新调度或断开取代。
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

    /// NWPathMonitor：Wi-Fi 断开即判链路不可用（不等心跳超时）。
    private func startPathMonitor() {
        stopPathMonitor()
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                guard let self, !self.manualDisconnect else { return }
                if path.status != .satisfied {
                    self.missedHeartbeats = 0
                    self.enterReconnecting()
                }
            }
        }
        monitor.start(queue: DispatchQueue(
            label: "com.tauber.nikonlink.wifi.path"
        ))
        pathMonitor = monitor
    }

    private func stopPathMonitor() {
        pathMonitor?.cancel()
        pathMonitor = nil
    }

    func capture() {
        guard isConnected else {
            status = "请先连接 Wi‑Fi 相机"
            return
        }
        status = "正在通过 Wi‑Fi 触发快门…"
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.session.capture()
                self.status = "Wi‑Fi 快门已触发 · 原图保存在相机卡内"
                self.onShutterTriggered?()
            } catch {
                self.status = error.localizedDescription
                self.state = .failed(error.localizedDescription)
            }
        }
    }

    // MARK: - C3 实时取景

    /// 连接就绪后自动开实时取景：约 10fps 拉帧，单帧失败退避 300ms 重试。
    /// 佳能路径 TBC-awaiting-hardware（与 C2 序列一致）。
    func startLiveViewIfNeeded() {
        guard isConnected, vendor != .unknown, liveViewTask == nil else { return }
        liveViewTask = Task { [weak self] in
            guard let self else { return }
            let vendor = self.vendor
            do {
                try await self.session.startLiveView(vendor: vendor)
            } catch {
                self.liveViewStatus = error.localizedDescription
                self.liveViewTask = nil
                return
            }
            self.liveViewStatus = ""
            while !Task.isCancelled {
                do {
                    let jpeg = try await self.session.getLiveViewFrame(
                        vendor: vendor
                    )
                    if let frame = Self.decodeLiveViewJPEG(jpeg) {
                        self.liveViewFrame = frame
                    }
                    try await Task.sleep(nanoseconds: 100_000_000)
                } catch {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                }
            }
        }
    }

    func stopLiveViewIfNeeded() {
        liveViewTask?.cancel()
        liveViewTask = nil
        let vendor = self.vendor
        Task { [weak self] in
            guard let self else { return }
            await self.session.endLiveView(vendor: vendor)
            self.liveViewFrame = nil
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
        guard isConnected else { return }
        if isRecording {
            Task { [weak self] in
                guard let self else { return }
                do {
                    try await self.session.stopMovieRecording(
                        vendor: self.vendor
                    )
                    self.isRecording = false
                    self.status = "Wi‑Fi 录像已停止"
                } catch {
                    self.status = error.localizedDescription
                }
            }
        } else {
            guard supportsMovieRecording else {
                status = "已连相机暂不支持 PTP/IP 远程录像"
                return
            }
            Task { [weak self] in
                guard let self else { return }
                do {
                    try await self.session.startMovieRecording(
                        vendor: self.vendor
                    )
                    self.isRecording = true
                    self.status = "Wi‑Fi 录像中 · 文件保存在相机卡内"
                } catch {
                    self.status = error.localizedDescription
                }
            }
        }
    }

    // MARK: - C3 参数读写（ISO / 光圈 / 快门）

    /// 从相机读取常用参数（GetDevicePropValue 0x1015）。单属性失败不阻断
    /// 其余属性（部分机型不暴露个别属性）。
    func refreshParameters() {
        guard isConnected else { return }
        Task { [weak self] in
            guard let self else { return }
            if let iso = try? await self.session.readProperty(
                PTPIPVendorOps.propISO
            ), let value = Self.leUInt16(iso), value > 0 {
                self.isoValue = Int(value)
            }
            if let fNumber = try? await self.session.readProperty(
                PTPIPVendorOps.propFNumber
            ), let value = Self.leUInt16(fNumber), value > 0 {
                self.apertureValue = Float(value) / 100
            }
            if let exposure = try? await self.session.readProperty(
                PTPIPVendorOps.propExposureTime
            ), let value = Self.leUInt32(exposure), value > 0 {
                self.shutterSpeedValue = Double(value) / 10000
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
        guard isConnected else { return }
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.session.writeProperty(property, value: payload)
                self.status = "Wi‑Fi \(label)已写入 · 相机已更新"
                self.refreshParameters()
            } catch {
                self.status = "Wi‑Fi \(label)写入失败：\(error.localizedDescription)"
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
        guard isConnected else { throw PTPIPError.notConnected }
        return try await session.listStorage()
    }

    func storageThumbnail(handle: UInt32) async throws -> Data {
        guard isConnected else { throw PTPIPError.notConnected }
        return try await session.storageThumbnail(handle: handle)
    }

    func storageObject(handle: UInt32) async throws -> Data {
        guard isConnected else { throw PTPIPError.notConnected }
        return try await session.storageObject(handle: handle)
    }

    func deleteStorageObject(handle: UInt32) async throws {
        guard isConnected else { throw PTPIPError.notConnected }
        try await session.deleteStorageObject(handle: handle)
    }
}
