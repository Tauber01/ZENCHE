import Combine
import CoreBluetooth
import CoreLocation
import Foundation
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

private actor PTPIPSession {
    private var command: NWConnection?
    private var event: NWConnection?
    private var transactionID: UInt32 = 1

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

    func disconnect() async {
        command?.cancel()
        event?.cancel()
        command = nil
        event = nil
        transactionID = 1
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
        return try await withCheckedThrowingContinuation { continuation in
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
                        continuation.resume(returning: accumulated)
                    } else if let error {
                        continuation.resume(
                            throwing: PTPIPError.connectionFailed(
                                error.localizedDescription
                            )
                        )
                    } else if isComplete {
                        continuation.resume(
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
        case failed(String)
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

    var onShutterTriggered: (() -> Void)?

    private let session = PTPIPSession()
    private var connectionTask: Task<Void, Never>?

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
        connectionTask?.cancel()
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
                guard !Task.isCancelled else { return }
                self.cameraName = name
                self.state = .ready
                self.status = "Wi‑Fi 已连接 · \(name)"
            } catch {
                guard !Task.isCancelled else { return }
                self.cameraName = "—"
                self.state = .failed(error.localizedDescription)
                self.status = error.localizedDescription
            }
        }
    }

    func disconnect() {
        connectionTask?.cancel()
        connectionTask = nil
        Task { await session.disconnect() }
        state = .disconnected
        cameraName = "—"
        status = "Wi‑Fi 相机未连接"
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
