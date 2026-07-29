import Combine
import Darwin
import Foundation

final class WirelessTransferServer: ObservableObject {
    static let port: UInt16 = 2121
    static let httpPort: UInt16 = WirelessHTTPServer.port
    static let username = "nikonlink"
    static let password = "nikonlink"

    @Published private(set) var isRunning = false
    @Published private(set) var status = "无线收件箱未开启"
    @Published private(set) var hostAddress = "未检测到 Wi-Fi 地址"
    @Published private(set) var receivedCount = 0

    private let directory: URL
    private let onReceive: (URL) -> Void
    private let acceptQueue = DispatchQueue(
        label: "com.tauber.nikonlink.wireless.ftp",
        qos: .userInitiated
    )
    private let socketLock = NSLock()
    private var listenerFD: Int32 = -1
    private var controlConnections: Set<Int32> = []
    private lazy var httpServer = WirelessHTTPServer(
        directory: directory,
        onStatus: { [weak self] status in
            guard let self, self.isRunning else { return }
            self.status = status
        },
        onReceive: { [weak self] url in
            guard let self else { return }
            self.receivedCount += 1
            self.status = "已接收 \(url.lastPathComponent)"
            self.onReceive(url)
        }
    )

    init(directory: URL, onReceive: @escaping (URL) -> Void) {
        self.directory = directory
        self.onReceive = onReceive
        refreshAddress()
    }

    func refreshAddress() {
        let address = Self.primaryIPv4Address() ?? "未检测到 Wi-Fi 地址"
        DispatchQueue.main.async {
            self.hostAddress = address
        }
    }

    func start() {
        socketLock.lock()
        guard listenerFD == -1 else {
            socketLock.unlock()
            return
        }
        listenerFD = -2
        socketLock.unlock()

        httpServer.start()
        acceptQueue.async { [weak self] in
            self?.runServer()
        }
    }

    func stop() {
        httpServer.stop()
        socketLock.lock()
        let descriptor = listenerFD
        listenerFD = -1
        let clients = controlConnections
        controlConnections.removeAll()
        socketLock.unlock()
        if descriptor >= 0 {
            Darwin.shutdown(descriptor, SHUT_RDWR)
            Darwin.close(descriptor)
        }
        for client in clients {
            Darwin.shutdown(client, SHUT_RDWR)
            Darwin.close(client)
        }
        DispatchQueue.main.async {
            self.isRunning = false
            self.status = "无线收件箱未开启"
        }
    }

    private func runServer() {
        let descriptor = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard descriptor >= 0 else {
            publishFailure("无法创建无线传输服务。")
            return
        }
        configureSocket(descriptor)

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = Self.port.bigEndian
        address.sin_addr = in_addr(s_addr: INADDR_ANY)
        let bindResult = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(
                    descriptor,
                    $0,
                    socklen_t(MemoryLayout<sockaddr_in>.size)
                )
            }
        }
        guard bindResult == 0, Darwin.listen(descriptor, 4) == 0 else {
            Darwin.close(descriptor)
            publishFailure("端口 \(Self.port) 已被占用，无法开启无线收件箱。")
            return
        }

        socketLock.lock()
        guard listenerFD == -2 else {
            socketLock.unlock()
            Darwin.close(descriptor)
            return
        }
        listenerFD = descriptor
        socketLock.unlock()

        let addressText = Self.primaryIPv4Address() ?? "未检测到 Wi-Fi 地址"
        DispatchQueue.main.async {
            self.hostAddress = addressText
            self.isRunning = true
            self.status = "等待 FTP / HTTP / WebDAV 图片"
        }

        while true {
            var peer = sockaddr_storage()
            var length = socklen_t(MemoryLayout<sockaddr_storage>.size)
            let client = withUnsafeMutablePointer(to: &peer) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    Darwin.accept(descriptor, $0, &length)
                }
            }
            if client < 0 { break }
            configureSocket(client)
            socketLock.lock()
            controlConnections.insert(client)
            socketLock.unlock()
            DispatchQueue.global(qos: .utility).async { [weak self] in
                self?.handleControlConnection(client)
            }
        }

        socketLock.lock()
        if listenerFD == descriptor { listenerFD = -1 }
        socketLock.unlock()
        DispatchQueue.main.async {
            self.isRunning = false
            self.status = "无线收件箱已停止"
        }
    }

    private func handleControlConnection(_ descriptor: Int32) {
        defer {
            socketLock.lock()
            let shouldClose = controlConnections.remove(descriptor) != nil
            socketLock.unlock()
            if shouldClose { Darwin.close(descriptor) }
        }
        var authenticated = false
        var acceptedUser = false
        var passiveListener: Int32 = -1

        sendLine("220 ZENCHE Wireless Inbox ready", to: descriptor)
        DispatchQueue.main.async {
            self.status = "相机已连接，等待图片"
        }

        while let line = readLine(from: descriptor) {
            let pieces = line.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            let command = pieces.first?.uppercased() ?? ""
            let argument = pieces.count > 1 ? String(pieces[1]) : ""

            switch command {
            case "USER":
                acceptedUser = argument.lowercased() == Self.username
                sendLine(acceptedUser ? "331 Password required" : "530 Invalid user", to: descriptor)
            case "PASS":
                authenticated = acceptedUser && argument == Self.password
                sendLine(authenticated ? "230 Login successful" : "530 Login incorrect", to: descriptor)
            case "QUIT":
                sendLine("221 Goodbye", to: descriptor)
                if passiveListener >= 0 { Darwin.close(passiveListener) }
                return
            case "NOOP":
                sendLine("200 OK", to: descriptor)
            case "SYST":
                sendLine("215 UNIX Type: L8", to: descriptor)
            case "FEAT":
                sendRaw(
                    "211-Features\r\n EPSV\r\n PASV\r\n SIZE\r\n UTF8\r\n211 End\r\n",
                    to: descriptor
                )
            case "OPTS", "CLNT":
                sendLine("200 OK", to: descriptor)
            default:
                guard authenticated else {
                    sendLine("530 Please login", to: descriptor)
                    continue
                }
                switch command {
                case "PWD", "XPWD":
                    sendLine("257 \"/\" is current directory", to: descriptor)
                case "CWD", "CDUP", "MKD", "XMKD":
                    sendLine(command.contains("MKD") ? "257 Directory ready" : "250 Directory changed", to: descriptor)
                case "TYPE", "MODE", "STRU":
                    sendLine("200 Transfer mode set", to: descriptor)
                case "PASV", "EPSV":
                    if passiveListener >= 0 { Darwin.close(passiveListener) }
                    guard let passive = openPassiveSocket(for: descriptor) else {
                        passiveListener = -1
                        sendLine("425 Cannot open passive connection", to: descriptor)
                        continue
                    }
                    passiveListener = passive.descriptor
                    if command == "EPSV" {
                        sendLine("229 Entering Extended Passive Mode (|||\(passive.port)|)", to: descriptor)
                    } else {
                        let host = passive.host.replacingOccurrences(of: ".", with: ",")
                        let high = Int(passive.port) / 256
                        let low = Int(passive.port) % 256
                        sendLine("227 Entering Passive Mode (\(host),\(high),\(low))", to: descriptor)
                    }
                case "STOR", "APPE":
                    guard passiveListener >= 0 else {
                        sendLine("425 Use PASV first", to: descriptor)
                        continue
                    }
                    sendLine("150 Opening binary connection", to: descriptor)
                    let success = receiveFile(
                        named: argument,
                        from: passiveListener
                    )
                    Darwin.close(passiveListener)
                    passiveListener = -1
                    sendLine(
                        success ? "226 Transfer complete" : "451 Transfer failed",
                        to: descriptor
                    )
                case "LIST", "NLST":
                    guard passiveListener >= 0 else {
                        sendLine("425 Use PASV first", to: descriptor)
                        continue
                    }
                    sendLine("150 Opening data connection", to: descriptor)
                    let dataClient = Darwin.accept(passiveListener, nil, nil)
                    if dataClient >= 0 { Darwin.close(dataClient) }
                    Darwin.close(passiveListener)
                    passiveListener = -1
                    sendLine("226 Directory send OK", to: descriptor)
                case "SIZE", "MDTM":
                    sendLine("550 File unavailable", to: descriptor)
                case "REST":
                    sendLine("350 Restart position accepted", to: descriptor)
                case "PORT", "EPRT":
                    sendLine("502 请在相机中开启 PASV 模式", to: descriptor)
                default:
                    sendLine("502 Command not implemented", to: descriptor)
                }
            }
        }
        if passiveListener >= 0 { Darwin.close(passiveListener) }
        DispatchQueue.main.async {
            if self.isRunning { self.status = "等待 FTP / HTTP / WebDAV 图片" }
        }
    }

    private func openPassiveSocket(
        for controlDescriptor: Int32
    ) -> (descriptor: Int32, host: String, port: UInt16)? {
        let descriptor = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard descriptor >= 0 else { return nil }
        configureSocket(descriptor)
        var timeout = timeval(tv_sec: 30, tv_usec: 0)
        setsockopt(
            descriptor,
            SOL_SOCKET,
            SO_RCVTIMEO,
            &timeout,
            socklen_t(MemoryLayout<timeval>.size)
        )

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = 0
        address.sin_addr = in_addr(s_addr: INADDR_ANY)
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(
                    descriptor,
                    $0,
                    socklen_t(MemoryLayout<sockaddr_in>.size)
                )
            }
        }
        guard bound == 0, Darwin.listen(descriptor, 1) == 0 else {
            Darwin.close(descriptor)
            return nil
        }

        var passiveAddress = sockaddr_in()
        var passiveLength = socklen_t(MemoryLayout<sockaddr_in>.size)
        let nameResult = withUnsafeMutablePointer(to: &passiveAddress) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getsockname(descriptor, $0, &passiveLength)
            }
        }
        guard nameResult == 0 else {
            Darwin.close(descriptor)
            return nil
        }
        let host = localAddress(of: controlDescriptor)
            ?? Self.primaryIPv4Address()
            ?? "127.0.0.1"
        return (descriptor, host, UInt16(bigEndian: passiveAddress.sin_port))
    }

    private func receiveFile(named remoteName: String, from passiveListener: Int32) -> Bool {
        let dataClient = Darwin.accept(passiveListener, nil, nil)
        guard dataClient >= 0 else { return false }
        defer { Darwin.close(dataClient) }
        configureSocket(dataClient)

        let cleanName = Self.safeFilename(remoteName)
        let destination = uniqueDestination(for: cleanName)
        let temporary = directory.appendingPathComponent(".\(UUID().uuidString).part")
        FileManager.default.createFile(atPath: temporary.path, contents: nil)
        guard let output = try? FileHandle(forWritingTo: temporary) else { return false }
        defer { try? output.close() }

        var total: Int64 = 0
        var buffer = [UInt8](repeating: 0, count: 256 * 1024)
        while true {
            let count = Darwin.recv(dataClient, &buffer, buffer.count, 0)
            if count == 0 { break }
            if count < 0 {
                try? FileManager.default.removeItem(at: temporary)
                return false
            }
            total += Int64(count)
            if total > 16 * 1024 * 1024 * 1024 {
                try? FileManager.default.removeItem(at: temporary)
                return false
            }
            output.write(Data(buffer[0..<count]))
        }
        try? output.synchronize()
        guard total > 0 else {
            try? FileManager.default.removeItem(at: temporary)
            return false
        }
        do {
            try FileManager.default.moveItem(at: temporary, to: destination)
            DispatchQueue.main.async {
                self.receivedCount += 1
                self.status = "已接收 \(destination.lastPathComponent)"
                self.onReceive(destination)
            }
            return true
        } catch {
            try? FileManager.default.removeItem(at: temporary)
            return false
        }
    }

    private func uniqueDestination(for filename: String) -> URL {
        let initial = directory.appendingPathComponent(filename)
        guard FileManager.default.fileExists(atPath: initial.path) else { return initial }
        let source = filename as NSString
        let stem = source.deletingPathExtension
        let ext = source.pathExtension
        let stamp = Int(Date().timeIntervalSince1970)
        let candidate = ext.isEmpty
            ? "\(stem)_\(stamp)"
            : "\(stem)_\(stamp).\(ext)"
        return directory.appendingPathComponent(candidate)
    }

    private func localAddress(of descriptor: Int32) -> String? {
        var address = sockaddr_in()
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let result = withUnsafeMutablePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getsockname(descriptor, $0, &length)
            }
        }
        guard result == 0 else { return nil }
        var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let lookup = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getnameinfo(
                    $0,
                    length,
                    &host,
                    socklen_t(host.count),
                    nil,
                    0,
                    NI_NUMERICHOST
                )
            }
        }
        return lookup == 0 ? String(cString: host) : nil
    }

    private func readLine(from descriptor: Int32) -> String? {
        var bytes: [UInt8] = []
        var byte: UInt8 = 0
        while bytes.count < 8192 {
            let count = Darwin.recv(descriptor, &byte, 1, 0)
            if count <= 0 { return bytes.isEmpty ? nil : String(decoding: bytes, as: UTF8.self) }
            if byte == 10 { break }
            if byte != 13 { bytes.append(byte) }
        }
        return String(decoding: bytes, as: UTF8.self)
    }

    private func sendLine(_ line: String, to descriptor: Int32) {
        sendRaw(line + "\r\n", to: descriptor)
    }

    private func sendRaw(_ text: String, to descriptor: Int32) {
        let data = Array(text.utf8)
        data.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return }
            var offset = 0
            while offset < raw.count {
                let sent = Darwin.send(
                    descriptor,
                    base.advanced(by: offset),
                    raw.count - offset,
                    0
                )
                if sent <= 0 { break }
                offset += sent
            }
        }
    }

    private func configureSocket(_ descriptor: Int32) {
        var enabled: Int32 = 1
        setsockopt(
            descriptor,
            SOL_SOCKET,
            SO_REUSEADDR,
            &enabled,
            socklen_t(MemoryLayout<Int32>.size)
        )
        setsockopt(
            descriptor,
            SOL_SOCKET,
            SO_NOSIGPIPE,
            &enabled,
            socklen_t(MemoryLayout<Int32>.size)
        )
    }

    private func publishFailure(_ message: String) {
        socketLock.lock()
        listenerFD = -1
        socketLock.unlock()
        DispatchQueue.main.async {
            self.isRunning = false
            self.status = message
        }
    }

    private static func safeFilename(_ remoteName: String) -> String {
        let decoded = remoteName.removingPercentEncoding ?? remoteName
        let component = (decoded as NSString).lastPathComponent
            .replacingOccurrences(of: "\0", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return component.isEmpty || component == "." || component == ".."
            ? "NIKON_\(Int(Date().timeIntervalSince1970)).JPG"
            : component
    }

    private static func primaryIPv4Address() -> String? {
        var pointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&pointer) == 0, let first = pointer else { return nil }
        defer { freeifaddrs(pointer) }

        var fallback: String?
        for item in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let interface = item.pointee
            guard let address = interface.ifa_addr,
                  address.pointee.sa_family == UInt8(AF_INET) else {
                continue
            }
            let flags = Int32(interface.ifa_flags)
            guard flags & IFF_UP != 0, flags & IFF_LOOPBACK == 0 else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(
                address,
                socklen_t(address.pointee.sa_len),
                &host,
                socklen_t(host.count),
                nil,
                0,
                NI_NUMERICHOST
            ) == 0 else {
                continue
            }
            let value = String(cString: host)
            let name = String(cString: interface.ifa_name)
            if name == "en0" || name == "en1" { return value }
            if fallback == nil { fallback = value }
        }
        return fallback
    }
}
