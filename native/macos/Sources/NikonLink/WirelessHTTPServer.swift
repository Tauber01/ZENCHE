import Darwin
import Foundation

final class WirelessHTTPServer {
    static let port: UInt16 = 8080

    private struct Request {
        let method: String
        let target: String
        let headers: [String: String]
    }

    private let directory: URL
    private let onStatus: (String) -> Void
    private let onReceive: (URL) -> Void
    private let queue = DispatchQueue(
        label: "com.tauber.nikonlink.wireless.http",
        qos: .userInitiated
    )
    private let lock = NSLock()
    private var listenerFD: Int32 = -1
    private var connections: Set<Int32> = []

    init(
        directory: URL,
        onStatus: @escaping (String) -> Void,
        onReceive: @escaping (URL) -> Void
    ) {
        self.directory = directory
        self.onStatus = onStatus
        self.onReceive = onReceive
    }

    func start() {
        lock.lock()
        guard listenerFD == -1 else {
            lock.unlock()
            return
        }
        listenerFD = -2
        lock.unlock()
        queue.async { [weak self] in
            self?.run()
        }
    }

    func stop() {
        lock.lock()
        let listener = listenerFD
        listenerFD = -1
        let clients = connections
        connections.removeAll()
        lock.unlock()
        if listener >= 0 {
            Darwin.shutdown(listener, SHUT_RDWR)
            Darwin.close(listener)
        }
        for client in clients {
            Darwin.shutdown(client, SHUT_RDWR)
            Darwin.close(client)
        }
    }

    private func run() {
        let descriptor = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard descriptor >= 0 else {
            publish("无法创建 HTTP / WebDAV 无线传输服务。")
            return
        }
        configure(descriptor)
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = Self.port.bigEndian
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
        guard bound == 0, Darwin.listen(descriptor, 8) == 0 else {
            Darwin.close(descriptor)
            lock.lock()
            listenerFD = -1
            lock.unlock()
            publish("端口 \(Self.port) 已被占用，HTTP / WebDAV 接收未开启。")
            return
        }

        lock.lock()
        guard listenerFD == -2 else {
            lock.unlock()
            Darwin.close(descriptor)
            return
        }
        listenerFD = descriptor
        lock.unlock()

        while true {
            let client = Darwin.accept(descriptor, nil, nil)
            if client < 0 { break }
            configure(client)
            lock.lock()
            connections.insert(client)
            lock.unlock()
            DispatchQueue.global(qos: .utility).async { [weak self] in
                self?.handle(client)
            }
        }
        lock.lock()
        if listenerFD == descriptor { listenerFD = -1 }
        lock.unlock()
    }

    private func handle(_ descriptor: Int32) {
        defer {
            lock.lock()
            let shouldClose = connections.remove(descriptor) != nil
            lock.unlock()
            if shouldClose { Darwin.close(descriptor) }
        }
        guard let request = readRequest(from: descriptor) else { return }
        guard request.headers["authorization"] == Self.authorization else {
            respond(
                401,
                "Unauthorized",
                body: "需要使用 帧澈 ZENCHE 无线收件箱账号。",
                headers: ["WWW-Authenticate": "Basic realm=\"ZENCHE\""],
                to: descriptor
            )
            return
        }

        switch request.method {
        case "OPTIONS":
            respond(
                200,
                "OK",
                headers: [
                    "Allow": "OPTIONS, GET, PUT, POST, MKCOL, PROPFIND",
                    "DAV": "1"
                ],
                to: descriptor
            )
        case "GET":
            respond(
                200,
                "OK",
                body: "{\"service\":\"ZENCHE\",\"upload\":\"ready\"}",
                headers: ["Content-Type": "application/json; charset=utf-8"],
                to: descriptor
            )
        case "MKCOL":
            respond(201, "Created", headers: ["DAV": "1"], to: descriptor)
        case "PROPFIND":
            let xml = """
            <?xml version="1.0" encoding="utf-8"?>
            <d:multistatus xmlns:d="DAV:"><d:response><d:href>/</d:href>\
            <d:propstat><d:prop><d:resourcetype><d:collection/></d:resourcetype>\
            <d:displayname>ZENCHE</d:displayname></d:prop>\
            <d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>\
            </d:multistatus>
            """
            respond(
                207,
                "Multi-Status",
                body: xml,
                headers: [
                    "Content-Type": "application/xml; charset=utf-8",
                    "DAV": "1"
                ],
                to: descriptor
            )
        case "PUT", "POST":
            receive(request, from: descriptor)
        default:
            respond(
                405,
                "Method Not Allowed",
                body: "此无线入口仅支持图片上传。",
                headers: [
                    "Allow": "OPTIONS, GET, PUT, POST, MKCOL, PROPFIND"
                ],
                to: descriptor
            )
        }
    }

    private func receive(_ request: Request, from descriptor: Int32) {
        guard let lengthText = request.headers["content-length"],
              let length = Int64(lengthText) else {
            respond(
                411,
                "Length Required",
                body: "请提供有效的 Content-Length。",
                to: descriptor
            )
            return
        }
        guard length > 0, length <= 16 * 1024 * 1024 * 1024 else {
            respond(
                413,
                "Content Too Large",
                body: "图片大小必须在 1 字节到 16 GB 之间。",
                to: descriptor
            )
            return
        }
        guard let filename = requestedFilename(request), !filename.isEmpty else {
            respond(
                400,
                "Bad Request",
                body: "请使用 /upload/文件名，或提供 X-Filename 请求头。",
                to: descriptor
            )
            return
        }

        publish("正在通过 HTTP / WebDAV 接收 \(filename)")
        let destination = uniqueDestination(Self.safeFilename(filename))
        let temporary = directory.appendingPathComponent(".\(UUID().uuidString).part")
        FileManager.default.createFile(atPath: temporary.path, contents: nil)
        guard let output = try? FileHandle(forWritingTo: temporary) else {
            respond(500, "Internal Server Error", body: "无法创建文件。", to: descriptor)
            return
        }
        defer { try? output.close() }

        var remaining = length
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
                return
            }
            output.write(Data(buffer[0..<count]))
            remaining -= Int64(count)
        }
        try? output.synchronize()
        do {
            try FileManager.default.moveItem(at: temporary, to: destination)
        } catch {
            try? FileManager.default.removeItem(at: temporary)
            respond(
                500,
                "Internal Server Error",
                body: "无线图片保存失败。",
                to: descriptor
            )
            return
        }

        let escaped = destination.lastPathComponent
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        respond(
            201,
            "Created",
            body: "{\"saved\":\"\(escaped)\"}",
            headers: [
                "Content-Type": "application/json; charset=utf-8",
                "Location": "/\(destination.lastPathComponent)"
            ],
            to: descriptor
        )
        DispatchQueue.main.async {
            self.onReceive(destination)
        }
    }

    private func readRequest(from descriptor: Int32) -> Request? {
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
        let lines = String(decoding: bytes.dropLast(4), as: UTF8.self)
            .components(separatedBy: "\r\n")
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
        return Request(
            method: requestLine[0].uppercased(),
            target: String(requestLine[1]),
            headers: headers
        )
    }

    private func requestedFilename(_ request: Request) -> String? {
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

    private func respond(
        _ status: Int,
        _ reason: String,
        body: String = "",
        headers: [String: String] = [:],
        to descriptor: Int32
    ) {
        let content = Data(body.utf8)
        var head = "HTTP/1.1 \(status) \(reason)\r\n"
        head += "Connection: close\r\n"
        head += "Content-Length: \(content.count)\r\n"
        for (name, value) in headers {
            head += "\(name): \(value)\r\n"
        }
        head += "\r\n"
        send(Data(head.utf8), to: descriptor)
        send(content, to: descriptor)
    }

    private func send(_ data: Data, to descriptor: Int32) {
        data.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return }
            var offset = 0
            while offset < raw.count {
                let count = Darwin.send(
                    descriptor,
                    base.advanced(by: offset),
                    raw.count - offset,
                    0
                )
                if count <= 0 { break }
                offset += count
            }
        }
    }

    private func uniqueDestination(_ filename: String) -> URL {
        let initial = directory.appendingPathComponent(filename)
        guard FileManager.default.fileExists(atPath: initial.path) else {
            return initial
        }
        let source = filename as NSString
        let stem = source.deletingPathExtension
        let ext = source.pathExtension
        let stamp = Int(Date().timeIntervalSince1970)
        return directory.appendingPathComponent(
            ext.isEmpty ? "\(stem)_\(stamp)" : "\(stem)_\(stamp).\(ext)"
        )
    }

    private func publish(_ status: String) {
        DispatchQueue.main.async {
            self.onStatus(status)
        }
    }

    private func configure(_ descriptor: Int32) {
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

    private static var authorization: String {
        let credentials = Data("nikonlink:nikonlink".utf8).base64EncodedString()
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
}
