package com.tauber.nikonlink;

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStreamWriter;
import java.net.Inet4Address;
import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.NetworkInterface;
import java.net.ServerSocket;
import java.net.Socket;
import java.nio.charset.StandardCharsets;
import java.util.Collections;
import java.util.Enumeration;
import java.util.Locale;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

final class WirelessFtpServer {
    static final int PORT = 2121;
    static final String USERNAME = "nikonlink";
    static final String PASSWORD = "nikonlink";

    interface Listener {
        void onStatus(String status);
        void onFileReceived(File file);
        void onError(String message);
    }

    private final File directory;
    private final Listener listener;
    private final ExecutorService clients = Executors.newCachedThreadPool(task -> {
        Thread thread = new Thread(task, "ZENCHE-FTP-Client");
        thread.setDaemon(true);
        return thread;
    });
    private final Set<Socket> activeClients =
            Collections.newSetFromMap(new ConcurrentHashMap<>());
    private volatile ServerSocket controlServer;
    private volatile boolean running;

    WirelessFtpServer(File directory, Listener listener) {
        this.directory = directory;
        this.listener = listener;
    }

    synchronized void start() {
        if (running) return;
        running = true;
        Thread acceptThread = new Thread(this::runServer, "ZENCHE-FTP");
        acceptThread.setDaemon(true);
        acceptThread.start();
    }

    synchronized void stop() {
        running = false;
        ServerSocket server = controlServer;
        controlServer = null;
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
        listener.onStatus("无线收件箱未开启");
    }

    boolean isRunning() {
        return running && controlServer != null && !controlServer.isClosed();
    }

    String getLocalAddress() {
        try {
            String fallback = null;
            Enumeration<NetworkInterface> interfaces = NetworkInterface.getNetworkInterfaces();
            for (NetworkInterface network : Collections.list(interfaces)) {
                if (!network.isUp() || network.isLoopback()) continue;
                for (InetAddress address : Collections.list(network.getInetAddresses())) {
                    if (!(address instanceof Inet4Address) || address.isLoopbackAddress()) continue;
                    String value = address.getHostAddress();
                    String name = network.getName().toLowerCase(Locale.ROOT);
                    if (name.startsWith("wlan") || name.startsWith("wifi")) return value;
                    if (fallback == null && address.isSiteLocalAddress()) fallback = value;
                }
            }
            return fallback == null ? "未检测到 Wi-Fi 地址" : fallback;
        } catch (Exception ignored) {
            return "未检测到 Wi-Fi 地址";
        }
    }

    private void runServer() {
        ServerSocket server = null;
        try {
            if (!directory.exists() && !directory.mkdirs()) {
                throw new Exception("无法创建无线图片保存目录。");
            }
            server = new ServerSocket();
            controlServer = server;
            server.setReuseAddress(true);
            server.bind(new InetSocketAddress(InetAddress.getByName("0.0.0.0"), PORT));
            listener.onStatus("等待相机无线传输");
            while (running && controlServer == server) {
                try {
                    Socket client = server.accept();
                    activeClients.add(client);
                    clients.submit(() -> handleClient(client));
                } catch (Exception error) {
                    if (running && controlServer == server) throw error;
                }
            }
        } catch (Exception error) {
            if (running && controlServer == server) listener.onError(
                    error.getMessage() == null
                            ? "无法开启无线图片接收。"
                            : error.getMessage());
        } finally {
            if (controlServer == server) {
                running = false;
                controlServer = null;
            }
            if (server != null) {
                try {
                    server.close();
                } catch (Exception ignored) {
                }
            }
        }
    }

    private void handleClient(Socket control) {
        ServerSocket passive = null;
        try (Socket client = control;
             BufferedReader input = new BufferedReader(new InputStreamReader(
                     client.getInputStream(),
                     StandardCharsets.UTF_8));
             BufferedWriter output = new BufferedWriter(new OutputStreamWriter(
                     client.getOutputStream(),
                     StandardCharsets.UTF_8))) {
            client.setSoTimeout(120_000);
            reply(output, "220 ZENCHE Wireless Inbox ready");
            listener.onStatus("相机已连接，等待图片");
            boolean acceptedUser = false;
            boolean authenticated = false;
            String line;
            while ((line = input.readLine()) != null) {
                String trimmed = line.trim();
                int separator = trimmed.indexOf(' ');
                String command = (separator < 0 ? trimmed : trimmed.substring(0, separator))
                        .toUpperCase(Locale.ROOT);
                String argument = separator < 0 ? "" : trimmed.substring(separator + 1).trim();

                if ("USER".equals(command)) {
                    acceptedUser = USERNAME.equalsIgnoreCase(argument);
                    reply(output, acceptedUser ? "331 Password required" : "530 Invalid user");
                    continue;
                }
                if ("PASS".equals(command)) {
                    authenticated = acceptedUser && PASSWORD.equals(argument);
                    reply(output, authenticated ? "230 Login successful" : "530 Login incorrect");
                    continue;
                }
                if ("QUIT".equals(command)) {
                    reply(output, "221 Goodbye");
                    break;
                }
                if ("NOOP".equals(command)) {
                    reply(output, "200 OK");
                    continue;
                }
                if ("SYST".equals(command)) {
                    reply(output, "215 UNIX Type: L8");
                    continue;
                }
                if ("FEAT".equals(command)) {
                    output.write("211-Features\r\n EPSV\r\n PASV\r\n SIZE\r\n UTF8\r\n211 End\r\n");
                    output.flush();
                    continue;
                }
                if ("OPTS".equals(command) || "CLNT".equals(command)) {
                    reply(output, "200 OK");
                    continue;
                }
                if (!authenticated) {
                    reply(output, "530 Please login");
                    continue;
                }

                switch (command) {
                    case "PWD":
                    case "XPWD":
                        reply(output, "257 \"/\" is current directory");
                        break;
                    case "CWD":
                    case "CDUP":
                        reply(output, "250 Directory changed");
                        break;
                    case "MKD":
                    case "XMKD":
                        reply(output, "257 Directory ready");
                        break;
                    case "TYPE":
                    case "MODE":
                    case "STRU":
                        reply(output, "200 Transfer mode set");
                        break;
                    case "PASV":
                    case "EPSV":
                        closeQuietly(passive);
                        passive = new ServerSocket();
                        passive.setReuseAddress(true);
                        passive.bind(new InetSocketAddress(client.getLocalAddress(), 0));
                        passive.setSoTimeout(30_000);
                        int port = passive.getLocalPort();
                        if ("EPSV".equals(command)) {
                            reply(output, "229 Entering Extended Passive Mode (|||" + port + "|)");
                        } else {
                            byte[] address = client.getLocalAddress().getAddress();
                            if (address.length != 4) {
                                reply(output, "425 IPv4 connection required");
                                closeQuietly(passive);
                                passive = null;
                                break;
                            }
                            String host = String.format(
                                    Locale.ROOT,
                                    "%d,%d,%d,%d",
                                    address[0] & 0xff,
                                    address[1] & 0xff,
                                    address[2] & 0xff,
                                    address[3] & 0xff);
                            reply(
                                    output,
                                    "227 Entering Passive Mode ("
                                            + host + "," + (port / 256) + "," + (port % 256) + ")");
                        }
                        break;
                    case "STOR":
                    case "APPE":
                        if (passive == null) {
                            reply(output, "425 Use PASV first");
                            break;
                        }
                        reply(output, "150 Opening binary connection");
                        File received = receiveFile(passive, argument);
                        closeQuietly(passive);
                        passive = null;
                        if (received == null) {
                            reply(output, "451 Transfer failed");
                        } else {
                            reply(output, "226 Transfer complete");
                            listener.onFileReceived(received);
                        }
                        break;
                    case "LIST":
                    case "NLST":
                        if (passive == null) {
                            reply(output, "425 Use PASV first");
                            break;
                        }
                        reply(output, "150 Opening data connection");
                        try (Socket data = passive.accept()) {
                            data.getOutputStream().flush();
                        }
                        closeQuietly(passive);
                        passive = null;
                        reply(output, "226 Directory send OK");
                        break;
                    case "SIZE":
                    case "MDTM":
                        reply(output, "550 File unavailable");
                        break;
                    case "REST":
                        reply(output, "350 Restart position accepted");
                        break;
                    case "PORT":
                    case "EPRT":
                        reply(output, "502 Enable PASV mode on camera");
                        break;
                    default:
                        reply(output, "502 Command not implemented");
                        break;
                }
            }
        } catch (Exception error) {
            if (running) listener.onStatus("无线连接已断开，等待相机重连");
        } finally {
            closeQuietly(passive);
            activeClients.remove(control);
            if (running) listener.onStatus("等待相机无线传输");
        }
    }

    private File receiveFile(ServerSocket passive, String remoteName) {
        File temporary = new File(directory, "." + System.nanoTime() + ".part");
        long total = 0;
        try (Socket data = passive.accept();
             InputStream input = data.getInputStream();
             FileOutputStream output = new FileOutputStream(temporary)) {
            data.setSoTimeout(120_000);
            byte[] buffer = new byte[256 * 1024];
            int count;
            while ((count = input.read(buffer)) >= 0) {
                if (count == 0) continue;
                total += count;
                if (total > 16L * 1024 * 1024 * 1024) {
                    throw new Exception("文件过大。");
                }
                output.write(buffer, 0, count);
            }
            output.getFD().sync();
        } catch (Exception error) {
            temporary.delete();
            return null;
        }
        if (total == 0) {
            temporary.delete();
            return null;
        }
        String name = safeFilename(remoteName);
        File destination = uniqueDestination(name);
        if (!temporary.renameTo(destination)) {
            temporary.delete();
            return null;
        }
        return destination;
    }

    private File uniqueDestination(String name) {
        File initial = new File(directory, name);
        if (!initial.exists()) return initial;
        int dot = name.lastIndexOf('.');
        String stem = dot > 0 ? name.substring(0, dot) : name;
        String extension = dot > 0 ? name.substring(dot) : "";
        return new File(directory, stem + "_" + System.currentTimeMillis() + extension);
    }

    private static String safeFilename(String remoteName) {
        String normalized = remoteName.replace('\\', '/').replace("\0", "");
        String name = new File(normalized).getName().trim();
        return name.isEmpty() || ".".equals(name) || "..".equals(name)
                ? "NIKON_" + System.currentTimeMillis() + ".JPG"
                : name;
    }

    private static void reply(BufferedWriter output, String line) throws Exception {
        output.write(line);
        output.write("\r\n");
        output.flush();
    }

    private static void closeQuietly(ServerSocket socket) {
        if (socket == null) return;
        try {
            socket.close();
        } catch (Exception ignored) {
        }
    }
}
