package com.tauber.nikonlink;

import java.io.EOFException;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.InetAddress;
import java.net.ServerSocket;
import java.net.Socket;
import java.net.SocketTimeoutException;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.atomic.AtomicInteger;
import javax.net.SocketFactory;

/**
 * Android PTP/IP 行为测试夹具：进程内假相机（ServerSocket 双通道）+
 * 真实 PtpIpCamera 客户端，按 argv 场景驱动并输出机器可校验结果。
 *
 * 场景：
 *   roundtrip      连接握手 + OpenSession + probe 往返成功
 *   probe-timeout  假相机不应答 Probe Request → probe() 在 PROBE_TIMEOUT_MS 附近超时
 *   event-fin      假相机半关闭 event 通道 → 客户端探测失败而非静默绿色
 *   factory        计数 SocketFactory 证明 open() 双通道都走注入的工厂
 */
public final class Main {
    private static final int PACKET_INIT_COMMAND_REQUEST = 1;
    private static final int PACKET_INIT_COMMAND_ACK = 2;
    private static final int PACKET_INIT_EVENT_REQUEST = 3;
    private static final int PACKET_INIT_EVENT_ACK = 4;
    private static final int PACKET_COMMAND_REQUEST = 6;
    private static final int PACKET_COMMAND_RESPONSE = 7;
    private static final int PACKET_PROBE_REQUEST = 13;
    private static final int PACKET_PROBE_RESPONSE = 14;
    private static final int OP_OPEN_SESSION = 0x1002;
    private static final int RESPONSE_OK = 0x2001;
    private static final long CONNECTION_NUMBER = 7;

    public static void main(String[] args) {
        String scenario = args.length > 0 ? args[0] : "";
        boolean pass = false;
        String detail = "";
        try {
            switch (scenario) {
                case "roundtrip":
                    pass = runRoundtrip();
                    break;
                case "probe-timeout":
                    pass = runProbeTimeout();
                    break;
                case "event-fin":
                    pass = runEventFin();
                    break;
                case "factory":
                    pass = runFactory();
                    break;
                default:
                    detail = "unknown-scenario=" + scenario;
            }
        } catch (Throwable error) {
            detail = "unexpected=" + error;
        }
        System.out.println(
                "SCENARIO=" + scenario
                        + " RESULT=" + (pass ? "PASS" : "FAIL")
                        + (detail.isEmpty() ? "" : " " + detail));
        System.exit(pass ? 0 : 1);
    }

    /** 完整握手 + OpenSession + probe 往返。 */
    private static boolean runRoundtrip() throws Exception {
        FakeCamera camera = new FakeCamera(false, false);
        camera.start();
        PtpIpCamera client = new PtpIpCamera();
        try {
            String name = client.connect("127.0.0.1", camera.port());
            client.probe();
            System.out.println("roundtrip name=" + name);
            return name.contains("FakeCam");
        } finally {
            client.close();
            camera.close();
        }
    }

    /** 假相机丢弃 Probe Response → probe() 抛出 SocketTimeoutException。 */
    private static boolean runProbeTimeout() throws Exception {
        FakeCamera camera = new FakeCamera(true, false);
        camera.start();
        PtpIpCamera client = new PtpIpCamera();
        try {
            client.connect("127.0.0.1", camera.port());
            long start = System.nanoTime();
            try {
                client.probe();
                System.out.println("probe-timeout probe unexpectedly succeeded");
                return false;
            } catch (SocketTimeoutException timeout) {
                long elapsedMs = (System.nanoTime() - start) / 1_000_000L;
                System.out.println(
                        "probe-timeout elapsedMs=" + elapsedMs
                                + " error=" + timeout.getMessage());
                // 单次探测超时 3s：允许调度抖动，但必须有界。
                return elapsedMs >= 2500 && elapsedMs <= 9000;
            }
        } finally {
            client.close();
            camera.close();
        }
    }

    /** event 通道被服务端半关闭（FIN）→ probe() 必须报错而非静默成功。 */
    private static boolean runEventFin() throws Exception {
        FakeCamera camera = new FakeCamera(false, true);
        camera.start();
        PtpIpCamera client = new PtpIpCamera();
        try {
            client.connect("127.0.0.1", camera.port());
            // 等客户端 event reader 消费 FIN 并标记通道故障。
            Thread.sleep(500);
            long start = System.nanoTime();
            try {
                client.probe();
                System.out.println("event-fin probe unexpectedly succeeded");
                return false;
            } catch (Exception error) {
                long elapsedMs = (System.nanoTime() - start) / 1_000_000L;
                System.out.println(
                        "event-fin elapsedMs=" + elapsedMs
                                + " error=" + error.getMessage());
                return elapsedMs <= 9000;
            }
        } finally {
            client.close();
            camera.close();
        }
    }

    /** 计数工厂：connect() 的 command/event 双 socket 都必须由注入工厂创建。 */
    private static boolean runFactory() throws Exception {
        FakeCamera camera = new FakeCamera(false, false);
        camera.start();
        AtomicInteger created = new AtomicInteger();
        SocketFactory counting = new SocketFactory() {
            @Override public Socket createSocket() {
                created.incrementAndGet();
                return new Socket();
            }

            @Override public Socket createSocket(String host, int port) {
                throw new UnsupportedOperationException();
            }

            @Override public Socket createSocket(
                    String host, int port, InetAddress local, int localPort) {
                throw new UnsupportedOperationException();
            }

            @Override public Socket createSocket(InetAddress host, int port) {
                throw new UnsupportedOperationException();
            }

            @Override public Socket createSocket(
                    InetAddress host, int port, InetAddress local, int localPort) {
                throw new UnsupportedOperationException();
            }
        };
        PtpIpCamera client = new PtpIpCamera();
        try {
            client.setSocketFactory(counting);
            client.connect("127.0.0.1", camera.port());
            System.out.println("factory createdSockets=" + created.get());
            return created.get() == 2;
        } finally {
            client.close();
            camera.close();
        }
    }

    // ── 进程内假 PTP/IP 相机 ──

    private static final class FakeCamera {
        private final ServerSocket server;
        private final boolean dropProbes;
        private final boolean closeEventAfterSession;
        private volatile String failure;

        FakeCamera(boolean dropProbes, boolean closeEventAfterSession)
                throws IOException {
            this.server = new ServerSocket(0, 2, InetAddress.getByName("127.0.0.1"));
            this.dropProbes = dropProbes;
            this.closeEventAfterSession = closeEventAfterSession;
        }

        int port() {
            return server.getLocalPort();
        }

        void start() {
            Thread thread = new Thread(this::serve, "fake-ptpip-camera");
            thread.setDaemon(true);
            thread.start();
        }

        void close() {
            try {
                server.close();
            } catch (IOException ignored) {
            }
        }

        private void serve() {
            try {
                Socket command = server.accept();
                command.setSoTimeout(15000);
                InputStream commandIn = command.getInputStream();
                OutputStream commandOut = command.getOutputStream();

                // InitCommandRequest → InitCommandAck（connectionNumber + 相机名）
                Packet init = readPacket(commandIn);
                if (init.type != PACKET_INIT_COMMAND_REQUEST) {
                    throw new IOException("unexpected init packet type " + init.type);
                }
                writePacket(commandOut, PACKET_INIT_COMMAND_ACK, initAckPayload());

                // InitEventRequest → InitEventAck
                Socket event = server.accept();
                event.setSoTimeout(15000);
                InputStream eventIn = event.getInputStream();
                OutputStream eventOut = event.getOutputStream();
                Packet eventInit = readPacket(eventIn);
                if (eventInit.type != PACKET_INIT_EVENT_REQUEST) {
                    throw new IOException(
                            "unexpected event init packet type " + eventInit.type);
                }
                writePacket(eventOut, PACKET_INIT_EVENT_ACK, new byte[0]);

                Thread eventLoop = new Thread(
                        () -> serveEventChannel(eventIn, eventOut),
                        "fake-ptpip-events");
                eventLoop.setDaemon(true);
                eventLoop.start();

                // 指令循环：仅应答 OpenSession，其余指令回 OK 也够握手用。
                while (true) {
                    Packet request = readPacket(commandIn);
                    if (request.type != PACKET_COMMAND_REQUEST
                            || request.payload.length < 10) {
                        throw new IOException(
                                "unexpected command packet type " + request.type);
                    }
                    int operation = u16(request.payload, 4);
                    long transaction = u32(request.payload, 6);
                    writePacket(
                            commandOut,
                            PACKET_COMMAND_RESPONSE,
                            commandResponsePayload(RESPONSE_OK, transaction));
                    if (operation == OP_OPEN_SESSION && closeEventAfterSession) {
                        // 半关闭 event 通道（FIN），模拟链路静默恶化。
                        Thread.sleep(100);
                        event.close();
                        return;
                    }
                }
            } catch (Exception error) {
                failure = error.toString();
            }
        }

        private void serveEventChannel(InputStream eventIn, OutputStream eventOut) {
            try {
                while (true) {
                    Packet packet = readPacket(eventIn);
                    if (packet.type == PACKET_PROBE_REQUEST && !dropProbes) {
                        writePacket(eventOut, PACKET_PROBE_RESPONSE, new byte[0]);
                    }
                }
            } catch (Exception ignored) {
                // 通道关闭或超时即退出。
            }
        }
    }

    // ── PTP/IP 小端封包工具 ──

    private static final class Packet {
        final int type;
        final byte[] payload;

        Packet(int type, byte[] payload) {
            this.type = type;
            this.payload = payload;
        }
    }

    private static void writePacket(OutputStream output, int type, byte[] payload)
            throws IOException {
        byte[] packet = new byte[payload.length + 8];
        putU32(packet, 0, payload.length + 8L);
        putU32(packet, 4, type);
        System.arraycopy(payload, 0, packet, 8, payload.length);
        output.write(packet);
        output.flush();
    }

    private static Packet readPacket(InputStream input) throws IOException {
        byte[] header = readExactly(input, 8);
        long length = u32(header, 0);
        if (length < 8 || length > 64 * 1024 * 1024L) {
            throw new IOException("invalid packet length " + length);
        }
        return new Packet(
                (int) u32(header, 4),
                readExactly(input, (int) length - 8));
    }

    private static byte[] readExactly(InputStream input, int count)
            throws IOException {
        byte[] data = new byte[count];
        int offset = 0;
        while (offset < count) {
            int read = input.read(data, offset, count - offset);
            if (read < 0) throw new EOFException("peer closed connection");
            offset += read;
        }
        return data;
    }

    /** InitCommandAck payload：connectionNumber + 16B GUID + UTF-16LE 名称。 */
    private static byte[] initAckPayload() {
        byte[] name = "ZENCHE FakeCam".getBytes(StandardCharsets.UTF_16LE);
        byte[] payload = new byte[4 + 16 + name.length + 2 + 4];
        putU32(payload, 0, CONNECTION_NUMBER);
        System.arraycopy(name, 0, payload, 20, name.length);
        // 名称后 2 字节 NUL 终止符；末尾 4 字节协议版本保持 0 即可。
        return payload;
    }

    /** CommandResponse payload：u16 响应码 + u32 事务号。 */
    private static byte[] commandResponsePayload(int code, long transaction) {
        byte[] payload = new byte[6];
        payload[0] = (byte) code;
        payload[1] = (byte) (code >> 8);
        putU32(payload, 2, transaction);
        return payload;
    }

    private static int u16(byte[] data, int offset) {
        return (data[offset] & 0xff) | ((data[offset + 1] & 0xff) << 8);
    }

    private static long u32(byte[] data, int offset) {
        return (data[offset] & 0xffL)
                | ((data[offset + 1] & 0xffL) << 8)
                | ((data[offset + 2] & 0xffL) << 16)
                | ((data[offset + 3] & 0xffL) << 24);
    }

    private static void putU32(byte[] data, int offset, long value) {
        data[offset] = (byte) value;
        data[offset + 1] = (byte) (value >> 8);
        data[offset + 2] = (byte) (value >> 16);
        data[offset + 3] = (byte) (value >> 24);
    }

    private Main() {
    }
}
