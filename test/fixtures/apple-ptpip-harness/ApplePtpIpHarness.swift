import Foundation
import Network

// 本地伪 PTP/IP 相机 + 真协议栈行为测试。
// 与被测的 RemoteCaptureServices.swift / CameraStorage.swift 一起编译，
// 通过 WifiCameraService 的公开入口驱动完整连接/心跳/重连路径。
// 用法: harness <connect|probe-drop|event-fin|handshake-silent>

// 注意：Data.removeFirst 后 startIndex 不归零，下标访问必须基于 startIndex。
private func readLE16(_ data: Data, at offset: Int) -> UInt16 {
    let i = data.index(data.startIndex, offsetBy: offset)
    return UInt16(data[i]) | UInt16(data[i + 1]) << 8
}

private func readLE32(_ data: Data, at offset: Int) -> UInt32 {
    let i = data.index(data.startIndex, offsetBy: offset)
    return UInt32(data[i]) | UInt32(data[i + 1]) << 8
        | UInt32(data[i + 2]) << 16 | UInt32(data[i + 3]) << 24
}

private func appendLE<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
    var le = value.littleEndian
    withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
}

private func packet(type: UInt32, payload: Data) -> Data {
    var data = Data()
    appendLE(UInt32(8 + payload.count), to: &data)
    appendLE(type, to: &data)
    data.append(payload)
    return data
}

private final class FakePTPIPCamera {
    enum Mode {
        case normal
        case dropProbe
        case silentHandshake
    }

    private let queue = DispatchQueue(label: "fake-ptpip-camera")
    private var listener: NWListener?
    private var mode: Mode
    private var commandConn: NWConnection?
    private var eventConn: NWConnection?
    private var commandBuffer = Data()
    private var eventBuffer = Data()
    private(set) var port: UInt16 = 0

    init(mode: Mode) {
        self.mode = mode
    }

    func start() throws {
        let listener = try NWListener(using: .tcp, on: .any)
        listener.newConnectionHandler = { [weak self] connection in
            self?.queue.async { self?.accept(connection) }
        }
        let ready = DispatchSemaphore(value: 0)
        listener.stateUpdateHandler = { state in
            if case .ready = state { ready.signal() }
        }
        listener.start(queue: queue)
        ready.wait()
        guard let boundPort = listener.port?.rawValue else {
            throw NSError(domain: "FakePTPIPCamera", code: 1)
        }
        port = boundPort
        self.listener = listener
    }

    func setMode(_ newMode: Mode) {
        queue.async { self.mode = newMode }
    }

    func closeEventChannel() {
        queue.async {
            self.eventConn?.cancel()
            self.eventConn = nil
            self.eventBuffer = Data()
        }
    }

    private func accept(_ connection: NWConnection) {
        if commandConn == nil {
            commandConn = connection
        } else if eventConn == nil {
            eventConn = connection
        } else {
            connection.cancel()
            return
        }
        connection.start(queue: queue)
        receiveLoop(connection, isCommand: connection === commandConn)
    }

    private func receiveLoop(_ connection: NWConnection, isCommand: Bool) {
        connection.receive(
            minimumIncompleteLength: 1,
            maximumLength: 1 << 20
        ) { [weak self] content, _, isComplete, error in
            guard let self else { return }
            if let content {
                if isCommand {
                    self.commandBuffer.append(content)
                    self.drainCommand(connection)
                } else {
                    self.eventBuffer.append(content)
                    self.drainEvent(connection)
                }
            }
            if isComplete || error != nil { return }
            self.receiveLoop(connection, isCommand: isCommand)
        }
    }

    private func drainCommand(_ connection: NWConnection) {
        while commandBuffer.count >= 8 {
            let length = Int(readLE32(commandBuffer, at: 0))
            guard length >= 8, commandBuffer.count >= length else { return }
            let type = readLE32(commandBuffer, at: 4)
            // 先解析后移除：CommandRequestContainer 布局为
            // header(8) + dataPhase(4) + op(2) + transaction(4)。
            let operation = length >= 18 ? readLE16(commandBuffer, at: 12) : 0
            let transaction =
                length >= 18 ? readLE32(commandBuffer, at: 14) : 0
            commandBuffer.removeFirst(length)
            switch type {
            case 1: // InitCommandRequest
                if mode == .silentHandshake { continue }
                var payload = Data()
                appendLE(UInt32(1), to: &payload) // connectionNumber
                payload.append(Data(count: 16)) // responder GUID
                let name = "FakeCam"
                for scalar in name.utf16 {
                    appendLE(scalar, to: &payload)
                }
                appendLE(UInt16(0), to: &payload)
                appendLE(UInt32(0x0001_0000), to: &payload)
                send(packet(type: 2, payload: payload), on: connection)
            case 6: // CommandRequestContainer
                guard length >= 18 else { continue }
                // OpenSession 及常规命令放行；GetDeviceInfo 以
                // OperationNotSupported 拒绝，走客户端的名称回退识别。
                let code: UInt16 = operation == 0x1001 ? 0x2005 : 0x2001
                var payload = Data()
                appendLE(code, to: &payload)
                appendLE(transaction, to: &payload)
                send(packet(type: 7, payload: payload), on: connection)
            default:
                continue
            }
        }
    }

    private func drainEvent(_ connection: NWConnection) {
        while eventBuffer.count >= 8 {
            let length = Int(readLE32(eventBuffer, at: 0))
            guard length >= 8, eventBuffer.count >= length else { return }
            let type = readLE32(eventBuffer, at: 4)
            eventBuffer.removeFirst(length)
            switch type {
            case 3: // InitEventRequest
                send(packet(type: 4, payload: Data()), on: connection)
            case 13: // ProbeRequest
                if mode == .dropProbe { continue }
                send(packet(type: 14, payload: Data()), on: connection)
            default:
                continue
            }
        }
    }

    private func send(_ data: Data, on connection: NWConnection) {
        connection.send(content: data, completion: .contentProcessed { _ in })
    }
}

@main
struct ApplePtpIpHarness {
    static func main() async {
        let arguments = CommandLine.arguments
        guard arguments.count == 2 else {
            print("FAIL usage: harness <scenario>")
            exit(2)
        }
        let scenario = arguments[1]
        let initialMode: FakePTPIPCamera.Mode =
            scenario == "handshake-silent" ? .silentHandshake : .normal
        let fake = FakePTPIPCamera(mode: initialMode)
        do {
            try fake.start()
        } catch {
            print("FAIL fake camera start: \(error)")
            exit(1)
        }

        let service = await MainActor.run { () -> WifiCameraService in
            let service = WifiCameraService()
            service.host = "127.0.0.1"
            service.portText = String(fake.port)
            return service
        }

        switch scenario {
        case "connect":
            await runConnectScenario(service: service)
        case "probe-drop":
            await runProbeDropScenario(service: service, fake: fake)
        case "event-fin":
            await runEventFinScenario(service: service, fake: fake)
        case "handshake-silent":
            await runSilentHandshakeScenario(service: service)
        default:
            print("FAIL unknown scenario \(scenario)")
            exit(2)
        }
    }

    private static func stateMatches(
        _ service: WifiCameraService,
        _ predicate: @MainActor (WifiCameraService.State) -> Bool
    ) async -> Bool {
        await MainActor.run { predicate(service.state) }
    }

    private static func waitFor(
        _ seconds: Double,
        service: WifiCameraService,
        predicate: @MainActor (WifiCameraService.State) -> Bool
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if await stateMatches(service, predicate) { return true }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        return await stateMatches(service, predicate)
    }

    private static func connectUntilReady(
        service: WifiCameraService
    ) async -> Bool {
        await MainActor.run { service.connect() }
        let ready = await waitFor(15, service: service) {
            if case .ready = $0 { return true }
            return false
        }
        if !ready {
            let status = await MainActor.run { service.status }
            print("FAIL connect did not reach ready: \(status)")
        }
        return ready
    }

    private static func runConnectScenario(
        service: WifiCameraService
    ) async {
        guard await connectUntilReady(service: service) else { exit(1) }
        let name = await MainActor.run { service.cameraName }
        guard name == "FakeCam" else {
            print("FAIL unexpected camera name \(name)")
            exit(1)
        }
        await MainActor.run { service.capture() }
        let deadline = Date().addingTimeInterval(8)
        var captured = false
        while Date() < deadline {
            let status = await MainActor.run { service.status }
            if status.contains("快门已触发") { captured = true; break }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        guard captured else {
            let status = await MainActor.run { service.status }
            print("FAIL capture status \(status)")
            exit(1)
        }
        await MainActor.run { service.disconnect() }
        print("PASS connect: ready + capture round-trip")
        exit(0)
    }

    private static func runProbeDropScenario(
        service: WifiCameraService,
        fake: FakePTPIPCamera
    ) async {
        guard await connectUntilReady(service: service) else { exit(1) }
        fake.setMode(.dropProbe)
        // 心跳 5s + 单次探测 3s，连续 3 次失败判离线：最坏 ~24s。
        let reconnecting = await waitFor(45, service: service) {
            $0.isReconnecting
        }
        guard reconnecting else {
            let status = await MainActor.run { service.status }
            print("FAIL probe-drop did not trigger reconnect: \(status)")
            exit(1)
        }
        await MainActor.run { service.disconnect() }
        print("PASS probe-drop: dead probe detected, auto reconnect entered")
        exit(0)
    }

    private static func runEventFinScenario(
        service: WifiCameraService,
        fake: FakePTPIPCamera
    ) async {
        guard await connectUntilReady(service: service) else { exit(1) }
        fake.closeEventChannel()
        let reconnecting = await waitFor(45, service: service) {
            $0.isReconnecting
        }
        guard reconnecting else {
            let status = await MainActor.run { service.status }
            print("FAIL event-fin did not trigger reconnect: \(status)")
            exit(1)
        }
        await MainActor.run { service.disconnect() }
        print("PASS event-fin: half-open event channel detected")
        exit(0)
    }

    private static func runSilentHandshakeScenario(
        service: WifiCameraService
    ) async {
        await MainActor.run { service.connect() }
        // 12 秒握手 deadline 必须兜住永不应答的假相机。
        let failed = await waitFor(25, service: service) {
            if case .failed = $0 { return true }
            return false
        }
        guard failed else {
            let status = await MainActor.run { service.status }
            print("FAIL silent handshake not bounded by deadline: \(status)")
            exit(1)
        }
        let status = await MainActor.run { service.status }
        guard status.contains("握手超时") else {
            print("FAIL unexpected failure message: \(status)")
            exit(1)
        }
        print("PASS handshake-silent: bounded by 12s handshake deadline")
        exit(0)
    }
}
