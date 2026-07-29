package com.tauber.nikonlink;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.ServerSocket;
import java.net.Socket;
import java.net.URI;
import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.Collections;
import java.util.HashMap;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

final class WirelessHttpServer {
    static final int PORT = 8080;
    private static final long MAXIMUM_FILE_SIZE = 16L * 1024L * 1024L * 1024L;
    private static final int MAXIMUM_HEADER_SIZE = 32 * 1024;

    interface Listener {
        void onStatus(String status);
        void onFileReceived(File file);
        void onError(String message);
    }

    private final File directory;
    private final Listener listener;
    private final ExecutorService clients = Executors.newCachedThreadPool(task -> {
        Thread thread = new Thread(task, "ZENCHE-HTTP-Client");
        thread.setDaemon(true);
        return thread;
    });
    private final Set<Socket> activeClients =
            Collections.newSetFromMap(new ConcurrentHashMap<>());
    private volatile ServerSocket serverSocket;
    private volatile boolean running;

    WirelessHttpServer(File directory, Listener listener) {
        this.directory = directory;
        this.listener = listener;
    }

    synchronized void start() {
        if (running) return;
        running = true;
        Thread thread = new Thread(this::runServer, "ZENCHE-HTTP");
        thread.setDaemon(true);
        thread.start();
    }

    synchronized void stop() {
        running = false;
        ServerSocket server = serverSocket;
        serverSocket = null;
        if (server != null) {
            try {
                server.close();
            } catch (Exception ignored) {
            }
        }
        for (Socket client : activeClients) {
            try {
                client.close();
            } catch (Exception ignored) {
            }
        }
        activeClients.clear();
    }

    private void runServer() {
        ServerSocket server = null;
        try {
            if (!directory.exists() && !directory.mkdirs()) {
                throw new Exception("无法创建无线图片保存目录。");
            }
            server = new ServerSocket();
            serverSocket = server;
            server.setReuseAddress(true);
            server.bind(new InetSocketAddress(InetAddress.getByName("0.0.0.0"), PORT));
            while (running && serverSocket == server) {
                try {
                    Socket client = server.accept();
                    activeClients.add(client);
                    clients.submit(() -> handleClient(client));
                } catch (Exception error) {
                    if (running && serverSocket == server) throw error;
                }
            }
        } catch (Exception error) {
            if (running && serverSocket == server) {
                listener.onError(
                        error.getMessage() == null
                                ? "无法开启 HTTP / WebDAV 图片接收。"
                                : error.getMessage());
            }
        } finally {
            if (serverSocket == server) serverSocket = null;
            if (server != null) {
                try {
                    server.close();
                } catch (Exception ignored) {
                }
            }
        }
    }

    private void handleClient(Socket socket) {
        try (Socket client = socket;
             InputStream input = client.getInputStream();
             OutputStream output = client.getOutputStream()) {
            client.setSoTimeout(120_000);
            Request request = readRequest(input);
            if (request == null) return;

            if (!isAuthenticated(request.headers)) {
                respond(
                        output,
                        401,
                        "Unauthorized",
                        "需要使用 帧澈 ZENCHE 无线收件箱账号。",
                        "WWW-Authenticate: Basic realm=\"ZENCHE\"\r\n");
                return;
            }

            switch (request.method) {
                case "OPTIONS":
                    respond(
                            output,
                            200,
                            "OK",
                            "",
                            "Allow: OPTIONS, GET, PUT, POST, MKCOL, PROPFIND\r\n"
                                    + "DAV: 1\r\n");
                    return;
                case "GET":
                    respond(
                            output,
                            200,
                            "OK",
                            "{\"service\":\"ZENCHE\",\"upload\":\"ready\"}",
                            "Content-Type: application/json; charset=utf-8\r\n");
                    return;
                case "MKCOL":
                    respond(output, 201, "Created", "", "DAV: 1\r\n");
                    return;
                case "PROPFIND":
                    String xml = "<?xml version=\"1.0\" encoding=\"utf-8\"?>"
                            + "<d:multistatus xmlns:d=\"DAV:\">"
                            + "<d:response><d:href>/</d:href><d:propstat><d:prop>"
                            + "<d:resourcetype><d:collection/></d:resourcetype>"
                            + "<d:displayname>ZENCHE</d:displayname>"
                            + "</d:prop><d:status>HTTP/1.1 200 OK</d:status>"
                            + "</d:propstat></d:response></d:multistatus>";
                    respond(
                            output,
                            207,
                            "Multi-Status",
                            xml,
                            "Content-Type: application/xml; charset=utf-8\r\n"
                                    + "DAV: 1\r\n");
                    return;
                case "PUT":
                case "POST":
                    receiveUpload(request, input, output);
                    return;
                default:
                    respond(
                            output,
                            405,
                            "Method Not Allowed",
                            "此无线入口仅支持图片上传。",
                            "Allow: OPTIONS, GET, PUT, POST, MKCOL, PROPFIND\r\n");
            }
        } catch (Exception ignored) {
        } finally {
            activeClients.remove(socket);
        }
    }

    private void receiveUpload(
            Request request,
            InputStream input,
            OutputStream output) throws Exception {
        String lengthText = request.headers.get("content-length");
        if (lengthText == null) {
            respond(output, 411, "Length Required", "请提供 Content-Length。", "");
            return;
        }
        long length;
        try {
            length = Long.parseLong(lengthText);
        } catch (NumberFormatException error) {
            respond(output, 400, "Bad Request", "Content-Length 无效。", "");
            return;
        }
        if (length <= 0 || length > MAXIMUM_FILE_SIZE) {
            respond(output, 413, "Content Too Large", "图片大小必须在 1 字节到 16 GB 之间。", "");
            return;
        }

        String filename = requestedFilename(request);
        if (filename == null || filename.isEmpty()) {
            respond(
                    output,
                    400,
                    "Bad Request",
                    "请使用 /upload/文件名，或提供 X-Filename 请求头。",
                    "");
            return;
        }

        listener.onStatus("正在通过 HTTP / WebDAV 接收 " + filename);
        File destination = uniqueDestination(safeFilename(filename));
        File temporary = new File(directory, "." + UUID.randomUUID() + ".part");
        boolean completed = false;
        try (FileOutputStream file = new FileOutputStream(temporary)) {
            byte[] buffer = new byte[256 * 1024];
            long remaining = length;
            while (remaining > 0) {
                int count = input.read(
                        buffer,
                        0,
                        (int) Math.min(buffer.length, remaining));
                if (count < 0) throw new Exception("图片上传提前中断。");
                if (count == 0) continue;
                file.write(buffer, 0, count);
                remaining -= count;
            }
            file.getFD().sync();
            completed = temporary.renameTo(destination);
            if (!completed) throw new Exception("无法保存无线图片。");
        } finally {
            if (!completed) temporary.delete();
        }

        listener.onFileReceived(destination);
        respond(
                output,
                201,
                "Created",
                "{\"saved\":\"" + jsonEscape(destination.getName()) + "\"}",
                "Content-Type: application/json; charset=utf-8\r\n"
                        + "Location: /" + destination.getName() + "\r\n");
    }

    private Request readRequest(InputStream input) throws Exception {
        ByteArrayOutputStream headerBytes = new ByteArrayOutputStream();
        int matched = 0;
        while (headerBytes.size() < MAXIMUM_HEADER_SIZE) {
            int value = input.read();
            if (value < 0) return null;
            headerBytes.write(value);
            if ((matched == 0 || matched == 2) && value == '\r') {
                matched++;
            } else if ((matched == 1 || matched == 3) && value == '\n') {
                matched++;
                if (matched == 4) break;
            } else {
                matched = value == '\r' ? 1 : 0;
            }
        }
        if (matched != 4) throw new Exception("HTTP 请求头过大。");

        String text = headerBytes.toString(StandardCharsets.ISO_8859_1.name());
        String[] lines = text.substring(0, text.length() - 4).split("\\r\\n");
        if (lines.length == 0) throw new Exception("HTTP 请求无效。");
        String[] first = lines[0].split(" ", 3);
        if (first.length < 2) throw new Exception("HTTP 请求行无效。");
        Map<String, String> headers = new HashMap<>();
        for (int index = 1; index < lines.length; index++) {
            int separator = lines[index].indexOf(':');
            if (separator <= 0) continue;
            headers.put(
                    lines[index].substring(0, separator).trim().toLowerCase(Locale.ROOT),
                    lines[index].substring(separator + 1).trim());
        }
        return new Request(first[0].toUpperCase(Locale.ROOT), first[1], headers);
    }

    private boolean isAuthenticated(Map<String, String> headers) {
        String authorization = headers.get("authorization");
        String expected = "Basic " + Base64.getEncoder().encodeToString(
                (WirelessFtpServer.USERNAME + ":" + WirelessFtpServer.PASSWORD)
                        .getBytes(StandardCharsets.UTF_8));
        return expected.equals(authorization);
    }

    private String requestedFilename(Request request) {
        String explicit = request.headers.get("x-filename");
        if (explicit != null && !explicit.trim().isEmpty()) return explicit.trim();
        try {
            URI uri = URI.create(request.target);
            String path = URLDecoder.decode(
                    uri.getRawPath() == null ? "" : uri.getRawPath(),
                    StandardCharsets.UTF_8.name());
            if (!path.equals("/") && !path.equals("/upload") && !path.equals("/upload/")) {
                return path.substring(path.lastIndexOf('/') + 1);
            }
            String query = uri.getRawQuery();
            if (query != null) {
                for (String part : query.split("&")) {
                    String[] pair = part.split("=", 2);
                    if (pair.length == 2 && pair[0].equalsIgnoreCase("filename")) {
                        return URLDecoder.decode(pair[1], StandardCharsets.UTF_8.name());
                    }
                }
            }
        } catch (Exception ignored) {
        }
        return null;
    }

    private File uniqueDestination(String filename) {
        File initial = new File(directory, filename);
        if (!initial.exists()) return initial;
        int dot = filename.lastIndexOf('.');
        String stem = dot > 0 ? filename.substring(0, dot) : filename;
        String extension = dot > 0 ? filename.substring(dot) : "";
        return new File(directory, stem + "_" + System.currentTimeMillis() + extension);
    }

    private static String safeFilename(String remoteName) {
        String normalized = remoteName.replace('\\', '/').replace('\0', '_');
        String source = normalized.substring(normalized.lastIndexOf('/') + 1).trim();
        String cleaned = source.replaceAll("[<>:\"|?*]", "_");
        return cleaned.isEmpty() || cleaned.equals(".") || cleaned.equals("..")
                ? "NIKON_" + System.currentTimeMillis() + ".JPG"
                : cleaned;
    }

    private static void respond(
            OutputStream output,
            int status,
            String reason,
            String body,
            String extraHeaders) throws Exception {
        byte[] content = body.getBytes(StandardCharsets.UTF_8);
        String headers = "HTTP/1.1 " + status + " " + reason + "\r\n"
                + "Connection: close\r\n"
                + "Content-Length: " + content.length + "\r\n"
                + extraHeaders
                + "\r\n";
        output.write(headers.getBytes(StandardCharsets.ISO_8859_1));
        output.write(content);
        output.flush();
    }

    private static String jsonEscape(String value) {
        return value.replace("\\", "\\\\").replace("\"", "\\\"");
    }

    private static final class Request {
        final String method;
        final String target;
        final Map<String, String> headers;

        Request(String method, String target, Map<String, String> headers) {
            this.method = method;
            this.target = target;
            this.headers = headers;
        }
    }
}
