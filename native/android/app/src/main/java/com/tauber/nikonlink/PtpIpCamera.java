package com.tauber.nikonlink;

import java.io.BufferedInputStream;
import java.io.BufferedOutputStream;
import java.io.ByteArrayOutputStream;
import java.io.Closeable;
import java.io.EOFException;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;

final class PtpIpCamera implements Closeable {
    private static final int PACKET_INIT_COMMAND_REQUEST = 1;
    private static final int PACKET_INIT_COMMAND_ACK = 2;
    private static final int PACKET_INIT_EVENT_REQUEST = 3;
    private static final int PACKET_INIT_EVENT_ACK = 4;
    private static final int PACKET_COMMAND_REQUEST = 6;
    private static final int PACKET_COMMAND_RESPONSE = 7;
    private static final int PACKET_START_DATA = 9;
    private static final int PACKET_DATA = 10;
    private static final int PACKET_END_DATA = 12;
    private static final int RESPONSE_OK = 0x2001;

    private Socket commandSocket;
    private Socket eventSocket;
    private InputStream commandInput;
    private OutputStream commandOutput;
    private int transactionId = 1;
    private String cameraName = "PTP/IP Camera";

    synchronized String connect(String host, int port) throws Exception {
        close();
        if (host == null || host.trim().isEmpty() || port < 1 || port > 65535) {
            throw new IOException("Wi‑Fi 相机地址或端口无效");
        }
        try {
            commandSocket = open(host.trim(), port);
            commandInput = new BufferedInputStream(commandSocket.getInputStream());
            commandOutput = new BufferedOutputStream(commandSocket.getOutputStream());

            ByteWriter initialization = new ByteWriter();
            byte[] guid = new byte[16];
            new SecureRandom().nextBytes(guid);
            initialization.bytes(guid);
            initialization.utf16("ZENCHE Android");
            initialization.u32(0x00010000L);
            writePacket(commandOutput, PACKET_INIT_COMMAND_REQUEST, initialization.data());
            Packet commandAck = readPacket(commandInput);
            if (commandAck.type != PACKET_INIT_COMMAND_ACK || commandAck.data.length < 28) {
                throw new IOException("相机返回了无效的 PTP/IP 握手数据");
            }
            long connectionNumber = u32(commandAck.data, 8);
            String announcedName = utf16(commandAck.data, 28);
            if (!announcedName.isEmpty()) cameraName = announcedName;

            eventSocket = open(host.trim(), port);
            ByteWriter eventInitialization = new ByteWriter();
            eventInitialization.u32(connectionNumber);
            writePacket(
                    eventSocket.getOutputStream(),
                    PACKET_INIT_EVENT_REQUEST,
                    eventInitialization.data());
            Packet eventAck = readPacket(eventSocket.getInputStream());
            if (eventAck.type != PACKET_INIT_EVENT_ACK) {
                throw new IOException("相机未确认 PTP/IP 事件通道");
            }

            int response = command(0x1002, 0, new long[]{1});
            if (response != RESPONSE_OK) throw rejected(response);
            transactionId = 1;
            return cameraName;
        } catch (Exception error) {
            close();
            throw error;
        }
    }

    synchronized void capture() throws Exception {
        ensureConnected();
        int response = command(
                0x100E,
                transactionId++,
                new long[]{0, 0});
        if (response != RESPONSE_OK) throw rejected(response);
    }

    synchronized CameraStorage.Snapshot listStorage() throws Exception {
        ensureConnected();
        java.util.List<CameraStorage.Volume> volumes = new java.util.ArrayList<>();
        java.util.List<CameraStorage.Item> items = new java.util.ArrayList<>();
        byte[] storageIds = commandWithData(0x1004, transactionId++, new long[0]);
        for (long storageId : CameraStorage.parseStorageIds(storageIds)) {
            volumes.add(CameraStorage.parseStorageInfo(
                    storageId,
                    commandWithData(0x1005, transactionId++, new long[]{storageId})));
            appendStorageItems(storageId, items);
        }
        items.sort((left, right) -> {
            int byDate = right.capturedAt.compareTo(left.capturedAt);
            return byDate != 0 ? byDate : right.filename.compareToIgnoreCase(left.filename);
        });
        return new CameraStorage.Snapshot(volumes, items);
    }

    private void appendStorageItems(
            long storageId,
            java.util.List<CameraStorage.Item> items) throws Exception {
        java.util.ArrayDeque<Long> pending = new java.util.ArrayDeque<>(
                CameraStorage.parseObjectHandles(commandWithData(
                        0x1007,
                        transactionId++,
                        new long[]{storageId, 0, 0xffff_ffffL})));
        java.util.Set<Long> visited = new java.util.HashSet<>();
        while (!pending.isEmpty()) {
            long handle = pending.removeFirst();
            if (!visited.add(handle)) continue;
            byte[] objectInfo = commandWithData(
                    0x1008,
                    transactionId++,
                    new long[]{handle});
            if (CameraStorage.isAssociation(objectInfo)) {
                for (long child : CameraStorage.parseObjectHandles(commandWithData(
                        0x1007,
                        transactionId++,
                        new long[]{storageId, 0, handle}))) {
                    if (!visited.contains(child)) pending.addLast(child);
                }
                continue;
            }
            CameraStorage.Item item = CameraStorage.parseObjectInfo(handle, objectInfo);
            if (item != null) items.add(item);
        }
    }

    synchronized byte[] getStorageThumbnail(long handle) throws Exception {
        return commandWithData(0x100a, transactionId++, new long[]{handle});
    }

    synchronized byte[] downloadStorageObject(long handle) throws Exception {
        return commandWithData(0x1009, transactionId++, new long[]{handle});
    }

    synchronized void deleteStorageObject(long handle) throws Exception {
        int response = command(0x100b, transactionId++, new long[]{handle, 0});
        if (response != RESPONSE_OK) throw rejected(response);
    }

    synchronized boolean isConnected() {
        return commandSocket != null && commandSocket.isConnected()
                && !commandSocket.isClosed();
    }

    synchronized String getCameraName() {
        return cameraName;
    }

    private int command(int operation, int transaction, long[] parameters)
            throws Exception {
        ensureConnected();
        ByteWriter request = new ByteWriter();
        request.u32(1);
        request.u16(operation);
        request.u32(transaction);
        for (long parameter : parameters) request.u32(parameter);
        writePacket(commandOutput, PACKET_COMMAND_REQUEST, request.data());
        Packet response = readPacket(commandInput);
        if (response.type != PACKET_COMMAND_RESPONSE || response.data.length < 14) {
            throw new IOException("相机返回了无效的 PTP/IP 响应");
        }
        return u16(response.data, 8);
    }

    private byte[] commandWithData(int operation, int transaction, long[] parameters)
            throws Exception {
        ensureConnected();
        ByteWriter request = new ByteWriter();
        // PTP/IP value 1 is used for data-in and no-data operations; value 2 is data-out.
        request.u32(1);
        request.u16(operation);
        request.u32(transaction);
        for (long parameter : parameters) request.u32(parameter);
        writePacket(commandOutput, PACKET_COMMAND_REQUEST, request.data());

        Packet first = readPacket(commandInput);
        if (first.type == PACKET_COMMAND_RESPONSE) {
            int response = first.data.length >= 10 ? u16(first.data, 8) : 0x2002;
            throw rejected(response);
        }
        if (first.type != PACKET_START_DATA || first.data.length < 20
                || u32(first.data, 8) != (transaction & 0xffff_ffffL)) {
            throw new IOException("相机返回了无效的 PTP/IP 数据阶段");
        }
        long totalLength = u64(first.data, 12);
        if (totalLength > 512L * 1024 * 1024) {
            throw new IOException("机内文件超过当前 512 MB 单文件传输上限");
        }
        ByteArrayOutputStream data = new ByteArrayOutputStream(
                (int) Math.min(totalLength, 8L * 1024 * 1024));
        while (true) {
            Packet packet = readPacket(commandInput);
            if ((packet.type != PACKET_DATA && packet.type != PACKET_END_DATA)
                    || packet.data.length < 12
                    || u32(packet.data, 8) != (transaction & 0xffff_ffffL)) {
                throw new IOException("相机返回了无效的 PTP/IP 文件数据包");
            }
            data.write(packet.data, 12, packet.data.length - 12);
            if (data.size() > 512 * 1024 * 1024) {
                throw new IOException("机内文件超过当前 512 MB 单文件传输上限");
            }
            if (packet.type == PACKET_END_DATA) break;
        }
        Packet response = readPacket(commandInput);
        if (response.type != PACKET_COMMAND_RESPONSE || response.data.length < 14) {
            throw new IOException("相机没有完成 PTP/IP 文件事务");
        }
        int code = u16(response.data, 8);
        if (code != RESPONSE_OK) throw rejected(code);
        return data.toByteArray();
    }

    private void ensureConnected() throws IOException {
        if (!isConnected() || commandInput == null || commandOutput == null) {
            throw new IOException("请先连接 Wi‑Fi 相机");
        }
    }

    private static Socket open(String host, int port) throws IOException {
        Socket socket = new Socket();
        socket.connect(new InetSocketAddress(host, port), 8000);
        socket.setSoTimeout(12000);
        socket.setTcpNoDelay(true);
        return socket;
    }

    private static void writePacket(OutputStream output, int type, byte[] payload)
            throws IOException {
        ByteWriter packet = new ByteWriter();
        packet.u32(payload.length + 8L);
        packet.u32(type);
        packet.bytes(payload);
        output.write(packet.data());
        output.flush();
    }

    private static Packet readPacket(InputStream input) throws IOException {
        byte[] header = readExactly(input, 8);
        long length = u32(header, 0);
        if (length < 8 || length > 64 * 1024 * 1024L) {
            throw new IOException("PTP/IP 数据包长度无效");
        }
        byte[] payload = readExactly(input, (int) length - 8);
        byte[] data = new byte[(int) length];
        System.arraycopy(header, 0, data, 0, 8);
        System.arraycopy(payload, 0, data, 8, payload.length);
        return new Packet((int) u32(header, 4), data);
    }

    private static byte[] readExactly(InputStream input, int count) throws IOException {
        byte[] data = new byte[count];
        int offset = 0;
        while (offset < count) {
            int read = input.read(data, offset, count - offset);
            if (read < 0) throw new EOFException("相机提前关闭了连接");
            offset += read;
        }
        return data;
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

    private static long u64(byte[] data, int offset) {
        long low = u32(data, offset);
        long high = u32(data, offset + 4);
        if (high > 0x7fff_ffffL) return Long.MAX_VALUE;
        long value = (high << 32) | low;
        return value < 0 ? Long.MAX_VALUE : value;
    }

    private static String utf16(byte[] data, int offset) {
        int end = offset;
        while (end + 1 < data.length && (data[end] != 0 || data[end + 1] != 0)) {
            end += 2;
        }
        if (end <= offset) return "";
        return new String(data, offset, end - offset, StandardCharsets.UTF_16LE);
    }

    private static IOException rejected(int response) {
        return new IOException(String.format(
                "相机拒绝了 PTP/IP 操作（0x%04X）",
                response));
    }

    @Override
    public synchronized void close() {
        closeQuietly(commandSocket);
        closeQuietly(eventSocket);
        commandSocket = null;
        eventSocket = null;
        commandInput = null;
        commandOutput = null;
        transactionId = 1;
        cameraName = "PTP/IP Camera";
    }

    private static void closeQuietly(Closeable closeable) {
        if (closeable == null) return;
        try {
            closeable.close();
        } catch (IOException ignored) {
        }
    }

    private static final class Packet {
        final int type;
        final byte[] data;

        Packet(int type, byte[] data) {
            this.type = type;
            this.data = data;
        }
    }

    private static final class ByteWriter {
        private byte[] data = new byte[64];
        private int size;

        void u16(long value) {
            ensure(2);
            data[size++] = (byte) value;
            data[size++] = (byte) (value >> 8);
        }

        void u32(long value) {
            ensure(4);
            data[size++] = (byte) value;
            data[size++] = (byte) (value >> 8);
            data[size++] = (byte) (value >> 16);
            data[size++] = (byte) (value >> 24);
        }

        void utf16(String value) {
            bytes(value.getBytes(StandardCharsets.UTF_16LE));
            u16(0);
        }

        void bytes(byte[] value) {
            ensure(value.length);
            System.arraycopy(value, 0, data, size, value.length);
            size += value.length;
        }

        byte[] data() {
            byte[] result = new byte[size];
            System.arraycopy(data, 0, result, 0, size);
            return result;
        }

        private void ensure(int count) {
            if (size + count <= data.length) return;
            byte[] replacement = new byte[Math.max(data.length * 2, size + count)];
            System.arraycopy(data, 0, replacement, 0, size);
            data = replacement;
        }
    }
}
