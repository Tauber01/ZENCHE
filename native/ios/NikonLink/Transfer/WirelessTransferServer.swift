import Combine
import Darwin
import Foundation

final class WirelessTransferServer: ObservableObject {
    static let port: UInt16 = 2121
    static let httpPort: UInt16 = 8080
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
    private let httpAcceptQueue = DispatchQueue(
        label: "com.tauber.nikonlink.wireless.http",
        qos: .userInitiated
    )
    private let socketLock = NSLock()
    private var listenerFD: Int32 = -1
    private var httpListenerFD: Int32 = -1
    private var controlConnections: Set<Int32> = []

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
        guard listenerFD == -1, httpListenerFD == -1 else {
            socketLock.unlock()
            return
        }
        listenerFD = -2
        httpListenerFD = -2
        socketLock.unlock()

        acceptQueue.async { [weak self] in
            self?.runServer()
        }
        httpAcceptQueue.async { [weak self] in
            self?.runHTTPServer()
        }
    }

    func stop() {
        socketLock.lock()
        let descriptor = listenerFD
        let httpDescriptor = httpListenerFD
        listenerFD = -1
        httpListenerFD = -1
        let clients = controlConnections
        controlConnections.removeAll()
        socketLock.unlock()
        if descriptor >= 0 {
            Darwin.shutdown(descriptor, SHUT_RDWR)
            Darwin.close(descriptor)
        }
        if httpDescriptor >= 0 {
            Darwin.shutdown(httpDescriptor, SHUT_RDWR)
            Darwin.close(httpDescriptor)
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
    }

    private func runHTTPServer() {
        let descriptor = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard descriptor >= 0 else {
            publishFailure("无法创建 HTTP / WebDAV 无线传输服务。")
            return
        }
        configureSocket(descriptor)

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = Self.httpPort.bigEndian
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
            publishFailure(
                "端口 \(Self.httpPort) 已被占用，无法开启 HTTP / WebDAV 收件箱。"
            )
            return
        }

        socketLock.lock()
        guard httpListenerFD == -2 else {
            socketLock.unlock()
            Darwin.close(descriptor)
            return
        }
        httpListenerFD = descriptor
        socketLock.unlock()

        DispatchQueue.main.async {
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
                self?.handleHTTPConnection(client)
            }
        }

        socketLock.lock()
        if httpListenerFD == descriptor { httpListenerFD = -1 }
        socketLock.unlock()
    }

    private func handleHTTPConnection(_ descriptor: Int32) {
        defer {
            socketLock.lock()
            let shouldClose = controlConnections.remove(descriptor) != nil
            socketLock.unlock()
            if shouldClose { Darwin.close(descriptor) }
        }
        guard let request = readHTTPRequest(from: descriptor) else { return }
        guard request.headers["authorization"] == Self.basicAuthorization else {
            sendHTTPResponse(
                status: 401,
                reason: "Unauthorized",
                body: "需要使用 帧澈 ZENCHE 无线收件箱账号。",
                headers: ["WWW-Authenticate": "Basic realm=\"ZENCHE\""],
                to: descriptor
            )
            return
        }

        switch request.method {
        case "OPTIONS":
            sendHTTPResponse(
                status: 200,
                reason: "OK",
                headers: [
                    "Allow": "OPTIONS, GET, PUT, POST, MKCOL, PROPFIND",
                    "DAV": "1"
                ],
                to: descriptor
            )
        case "GET":
            sendHTTPResponse(
                status: 200,
                reason: "OK",
                body: "{\"service\":\"ZENCHE\",\"upload\":\"ready\"}",
                headers: ["Content-Type": "application/json; charset=utf-8"],
                to: descriptor
            )
        case "MKCOL":
            sendHTTPResponse(
                status: 201,
                reason: "Created",
                headers: ["DAV": "1"],
                to: descriptor
            )
        case "PROPFIND":
            let xml = """
            <?xml version="1.0" encoding="utf-8"?>
            <d:multistatus xmlns:d="DAV:"><d:response><d:href>/</d:href>\
            <d:propstat><d:prop><d:resourcetype><d:collection/></d:resourcetype>\
            <d:displayname>ZENCHE</d:displayname></d:prop>\
            <d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>\
            </d:multistatus>
            """
            sendHTTPResponse(
                status: 207,
                reason: "Multi-Status",
                body: xml,
                headers: [
                    "Content-Type": "application/xml; charset=utf-8",
                    "DAV": "1"
                ],
                to: descriptor
            )
        case "PUT", "POST":
            receiveHTTPUpload(request, from: descriptor)
        default:
            sendHTTPResponse(
                status: 405,
                reason: "Method Not Allowed",
                body: "此无线入口仅支持图片上传。",
                headers: [
                    "Allow": "OPTIONS, GET, PUT, POST, MKCOL, PROPFIND"
                ],
                to: descriptor
            )
        }
    }

    private func receiveHTTPUpload(
        _ request: HTTPRequest,
        from descriptor: Int32
    ) {
        guard let lengthText = request.headers["content-length"],
              let length = Int64(lengthText) else {
            sendHTTPResponse(
                status: 411,
                reason: "Length Required",
                body: "请提供有效的 Content-Length。",
                to: descriptor
            )
            return
        }
        guard length > 0, length <= 16 * 1024 * 1024 * 1024 else {
            sendHTTPResponse(
                status: 413,
                reason: "Content Too Large",
                body: "图片大小必须在 1 字节到 16 GB 之间。",
                to: descriptor
            )
            return
        }
        guard let filename = requestedFilename(for: request), !filename.isEmpty else {
            sendHTTPResponse(
                status: 400,
                reason: "Bad Request",
                body: "请使用 /upload/文件名，或提供 X-Filename 请求头。",
                to: descriptor
            )
            return
        }

        DispatchQueue.main.async {
            self.status = "正在通过 HTTP / WebDAV 接收 \(filename)"
        }
        guard let destination = receiveFile(
            named: filename,
            from: descriptor,
            contentLength: length
        ) else {
            sendHTTPResponse(
                status: 500,
                reason: "Internal Server Error",
                body: "无线图片保存失败。",
                to: descriptor
            )
            return
        }
        let escaped = destination.lastPathComponent
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        sendHTTPResponse(
            status: 201,
            reason: "Created",
            body: "{\"saved\":\"\(escaped)\"}",
            headers: [
                "Content-Type": "application/json; charset=utf-8",
                "Location": "/\(destination.lastPathComponent)"
            ],
            to: descriptor
        )
    }

    private func receiveFile(
        named remoteName: String,
        from descriptor: Int32,
        contentLength: Int64
    ) -> URL? {
        let destination = uniqueDestination(for: Self.safeFilename(remoteName))
        let temporary = directory.appendingPathComponent(".\(UUID().uuidString).part")
        FileManager.default.createFile(atPath: temporary.path, contents: nil)
        guard let output = try? FileHandle(forWritingTo: temporary) else { return nil }
        defer { try? output.close() }

        var remaining = contentLength
        var buffer = [UInt8](repeating: 0, count: 256 * 1024)
        while remaining > 0 {
            let count = Darwin.recv(
                descriptor,
                &buffer,
                min(buffer.count, Int(remaining)),
                0
            )
            if count <= 0 {
                try? FileManager.default.removeItem(at: temporary)
                return nil
            }
            output.write(Data(buffer[0..<count]))
            remaining -= Int64(count)
        }
        try? output.synchronize()
        do {
            try FileManager.default.moveItem(at: temporary, to: destination)
            DispatchQueue.main.async {
                self.receivedCount += 1
                self.status = "已接收 \(destination.lastPathComponent)"
                self.onReceive(destination)
            }
            return destination
        } catch {
            try? FileManager.default.removeItem(at: temporary)
            return nil
        }
    }

    private func readHTTPRequest(from descriptor: Int32) -> HTTPRequest? {
        var bytes: [UInt8] = []
        var matched = 0
        var byte: UInt8 = 0
        while bytes.count < 32 * 1024 {
            let count = Darwin.recv(descriptor, &byte, 1, 0)
            if count <= 0 { return nil }
            bytes.append(byte)
            if (matched == 0 || matched == 2), byte == 13 {
                matched += 1
            } else if (matched == 1 || matched == 3), byte == 10 {
                matched += 1
                if matched == 4 { break }
            } else {
                matched = byte == 13 ? 1 : 0
            }
        }
        guard matched == 4 else { return nil }
        let text = String(decoding: bytes.dropLast(4), as: UTF8.self)
        let lines = text.components(separatedBy: "\r\n")
        guard let first = lines.first else { return nil }
        let requestLine = first.split(separator: " ", maxSplits: 2)
        guard requestLine.count >= 2 else { return nil }
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let separator = line.firstIndex(of: ":") else { continue }
            let key = line[..<separator]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            let value = line[line.index(after: separator)...]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            headers[key] = value
        }
        return HTTPRequest(
            method: requestLine[0].uppercased(),
            target: String(requestLine[1]),
            headers: headers
        )
    }

    private func requestedFilename(for request: HTTPRequest) -> String? {
        if let explicit = request.headers["x-filename"], !explicit.isEmpty {
            return explicit
        }
        guard let components = URLComponents(string: request.target) else {
            return nil
        }
        let path = components.percentEncodedPath.removingPercentEncoding
            ?? components.percentEncodedPath
        if path != "/", path != "/upload", path != "/upload/" {
            return (path as NSString).lastPathComponent
        }
        return components.queryItems?
            .first(where: { $0.name.lowercased() == "filename" })?
            .value
    }

    private func sendHTTPResponse(
        status: Int,
        reason: String,
        body: String = "",
        headers: [String: String] = [:],
        to descriptor: Int32
    ) {
        let content = Data(body.utf8)
        var response = "HTTP/1.1 \(status) \(reason)\r\n"
        response += "Connection: close\r\n"
        response += "Content-Length: \(content.count)\r\n"
        for (name, value) in headers {
            response += "\(name): \(value)\r\n"
        }
        response += "\r\n"
        sendRaw(response, to: descriptor)
        content.withUnsafeBytes { raw in
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
        stop()
        DispatchQueue.main.async {
            self.isRunning = false
            self.status = message
        }
    }

    private static var basicAuthorization: String {
        let credentials = Data("\(username):\(password)".utf8).base64EncodedString()
        return "Basic \(credentials)"
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

private struct HTTPRequest {
    let method: String
    let target: String
    let headers: [String: String]
}
