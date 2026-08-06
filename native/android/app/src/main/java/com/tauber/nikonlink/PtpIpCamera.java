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
import java.util.Arrays;
import java.util.Locale;

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
    /** B2 保活参数（契约测试锚点）：单次探测超时 3s。 */
    static final int PROBE_TIMEOUT_MS = 3000;
    // ── E4 1.5.9：PTP/IP 能力扩展 opcode（镜像 iOS RemoteCaptureServices +
    //    Windows PtpIpCamera.cs；协议见 docs/PTPIP_PROTOCOL.md，全部 TBC-awaiting-hardware）──
    private static final int NIKON_START_LIVE_VIEW = 0x9201;
    private static final int NIKON_END_LIVE_VIEW = 0x9202;
    private static final int NIKON_GET_LIVE_VIEW_IMAGE = 0x9203;
    private static final int NIKON_START_MOVIE_RECORDING = 0x920a;
    private static final int NIKON_END_MOVIE_RECORDING = 0x920b;
    private static final int GET_DEVICE_PROP_DESC = 0x1014;
    private static final int GET_DEVICE_PROP_VALUE = 0x1015;
    private static final int SET_DEVICE_PROP_VALUE = 0x1016;
    private static final int CANON_EOS_SET_DEVICE_PROP_VALUE_EX = 0x9110;
    private static final int CANON_EOS_GET_VIEW_FINDER_DATA = 0x9153;
    private static final int CANON_EVF_RECORD_STATUS = 0xd1b8;
    private static final int CANON_EVF_MODE = 0xd1b1;
    private static final int CANON_EVF_OUTPUT_DEVICE = 0xd1b0;
    // 常用参数属性码（与 Android PtpCamera USB 口径一致：ISO 0x500f / 光圈 0x5007 / 快门 0x500d）
    private static final int PROP_ISO = 0x500f;
    private static final int PROP_F_NUMBER = 0x5007;
    private static final int PROP_EXPOSURE_TIME = 0x500d;

    /** 已连 PTP/IP 相机的厂商分类（detectVendor 结果，断连清零）。 */
    enum CameraVendor {
        UNKNOWN,
        NIKON,
        CANON,
        SONY
    }

    private Socket commandSocket;
    private Socket eventSocket;
    private InputStream commandInput;
    private OutputStream commandOutput;
    private int transactionId = 1;
    private String cameraName = "PTP/IP Camera";
    private CameraVendor vendor = CameraVendor.UNKNOWN;
    private boolean liveView;
    private boolean movieRecording;

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

    /**
     * 无副作用链路探测：GetDeviceInfo（0x1002），用于心跳保活。
     * synchronized 与在途会话命令串行；单次超时 3s（临时收紧 soTimeout）。
     */
    synchronized void probe() throws Exception {
        ensureConnected();
        int previous = commandSocket.getSoTimeout();
        try {
            commandSocket.setSoTimeout(PROBE_TIMEOUT_MS);
            int response = command(0x1002, 0, new long[]{1});
            if (response != RESPONSE_OK) throw rejected(response);
        } finally {
            commandSocket.setSoTimeout(previous);
        }
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

    // ── E4 1.5.9：能力扩展——厂商识别 / 实时取景 / 录像 / 参数读写 ──
    // 镜像 iOS RemoteCaptureServices.swift + Windows PtpIpCamera.cs（9097944），
    // 字节级口径见 docs/PTPIP_PROTOCOL.md；全部 TBC-awaiting-hardware。

    synchronized CameraVendor getVendor() {
        return vendor;
    }

    synchronized boolean isLiveView() {
        return liveView;
    }

    synchronized boolean isMovieRecording() {
        return movieRecording;
    }

    /**
     * 识别已连机型厂商：优先解析 GetDeviceInfo(0x1001) 数据段 Manufacturer
     * （ISO 15740；0x1002 实为 OpenSession，勿混），退回握手相机名启发式。
     * 结果按会话缓存（detectVendor 在 connect 后调用），断连清零。
     */
    synchronized CameraVendor detectVendor() throws Exception {
        if (vendor != CameraVendor.UNKNOWN) return vendor;
        CameraVendor nameBased = vendorForName(cameraName);
        CameraVendor resolved = nameBased;
        try {
            byte[] info = commandWithData(0x1001, transactionId++, new long[]{1});
            String manufacturer = deviceInfoManufacturer(info);
            if (manufacturer != null && !manufacturer.trim().isEmpty()) {
                resolved = vendorForManufacturer(manufacturer, nameBased);
            }
        } catch (Exception ignored) {
            // 部分机型对 0x1001 直接回响应（无数据段），退回名称启发式。
        }
        vendor = resolved;
        return resolved;
    }

    /** 开始实时取景（Nikon 0x9201 / Canon EOS 序列，TBC-awaiting-hardware）。 */
    synchronized void startLiveView() throws Exception {
        ensureConnected();
        if (liveView) return;
        if (vendor == CameraVendor.CANON) {
            if (!canonOpenLiveView()) {
                throw new Exception(
                        cameraName + " 未能确认进入佳能实时取景（机身未确认取景输出）。");
            }
            return;
        }
        int response = command(
                NIKON_START_LIVE_VIEW,
                transactionId++,
                new long[0]);
        if (response != RESPONSE_OK) throw rejected(response);
        liveView = true;
    }

    /** 停止实时取景（尽力而为）。 */
    synchronized void stopLiveView() {
        if (!liveView || commandInput == null) {
            liveView = false;
            return;
        }
        if (vendor == CameraVendor.CANON) {
            try {
                // E4：佳能先关 PC 输出再关取景模式（TBC-awaiting-hardware）。
                canonWriteEosProp(CANON_EVF_OUTPUT_DEVICE, 0);
                canonWriteEosProp(CANON_EVF_MODE, 0);
            } catch (Exception ignored) {
            }
            liveView = false;
            return;
        }
        try {
            int response = command(
                    NIKON_END_LIVE_VIEW,
                    transactionId++,
                    new long[0]);
            if (response != RESPONSE_OK) throw rejected(response);
        } catch (Exception ignored) {
        }
        liveView = false;
    }

    /** 取一帧实时取景 JPEG（Nikon 0x9203 / Canon 0x9153 EOS dataset，TBC）。 */
    synchronized byte[] getLiveViewFrame() throws Exception {
        ensureConnected();
        if (!liveView) throw new Exception("实时取景尚未开启。");
        if (vendor == CameraVendor.CANON) {
            byte[] raw = commandWithData(
                    CANON_EOS_GET_VIEW_FINDER_DATA,
                    transactionId++,
                    new long[]{0x00200000L, 0L, 0L});
            return extractEosJpeg(raw);
        }
        return extractJpeg(commandWithData(
                NIKON_GET_LIVE_VIEW_IMAGE,
                transactionId++,
                new long[0]));
    }

    /** 开始录像（Nikon 0x920a / Canon EVFRecordStatus，TBC-awaiting-hardware）。 */
    synchronized void startMovieRecording() throws Exception {
        ensureConnected();
        if (movieRecording) return;
        if (vendor == CameraVendor.CANON) {
            startLiveView();
            canonWriteEosProp(CANON_EVF_RECORD_STATUS, 1);
            movieRecording = true;
            return;
        }
        if (!liveView) startLiveView();
        int response = command(
                NIKON_START_MOVIE_RECORDING,
                transactionId++,
                new long[0]);
        if (response != RESPONSE_OK) throw rejected(response);
        movieRecording = true;
    }

    /** 停止录像（Nikon 0x920b / Canon EVFRecordStatus=0，TBC-awaiting-hardware）。 */
    synchronized void stopMovieRecording() throws Exception {
        ensureConnected();
        try {
            if (vendor == CameraVendor.CANON) {
                canonWriteEosProp(CANON_EVF_RECORD_STATUS, 0);
            } else {
                int response = command(
                        NIKON_END_MOVIE_RECORDING,
                        transactionId++,
                        new long[0]);
                if (response != RESPONSE_OK) throw rejected(response);
            }
        } finally {
            movieRecording = false;
        }
    }

    /** 读取设备属性原始值（GetDevicePropValue 0x1015，data-in）。 */
    synchronized byte[] readProperty(int property) throws Exception {
        return commandWithData(
                GET_DEVICE_PROP_VALUE,
                transactionId++,
                new long[]{property});
    }

    /** 读取设备属性描述符（GetDevicePropDesc 0x1014），校验可写性。 */
    synchronized byte[] readPropertyDescriptor(int property) throws Exception {
        return commandWithData(
                GET_DEVICE_PROP_DESC,
                transactionId++,
                new long[]{property});
    }

    /** 写入设备属性（SetDevicePropValue 0x1016，data-out 相位）。 */
    synchronized void writeProperty(int property, byte[] value) throws Exception {
        int response = sendCommandWithDataOut(
                SET_DEVICE_PROP_VALUE,
                transactionId++,
                new long[]{property},
                value);
        if (response != RESPONSE_OK) throw rejected(response);
    }

    /**
     * data-out 请求（DataPhaseInfo=2）：请求(type 6) → StartData(type 9,
     * 载荷 [前导 0][TransactionID][TotalLength u64][数据]，对齐 iOS/Windows
     * 事实标准，TBC-awaiting-hardware) → EndData(type 12) → 响应(type 7)。
     * 用于 SetDevicePropValue(0x1016) 与 Canon EOS_SetDevicePropValueEx(0x9110)。
     */
    private int sendCommandWithDataOut(
            int operation,
            int transaction,
            long[] parameters,
            byte[] data) throws Exception {
        ensureConnected();
        ByteWriter request = new ByteWriter();
        request.u32(2); // DataPhaseInfo=2（数据出）
        request.u16(operation);
        request.u32(transaction);
        for (long parameter : parameters) request.u32(parameter);
        writePacket(commandOutput, PACKET_COMMAND_REQUEST, request.data());

        ByteWriter startData = new ByteWriter();
        startData.u32(0);
        startData.u32(transaction);
        startData.u64(data.length);
        startData.bytes(data);
        writePacket(commandOutput, PACKET_START_DATA, startData.data());

        ByteWriter endData = new ByteWriter();
        endData.u32(0);
        endData.u32(transaction);
        writePacket(commandOutput, PACKET_END_DATA, endData.data());

        Packet response = readPacket(commandInput);
        if (response.type != PACKET_COMMAND_RESPONSE || response.data.length < 14) {
            throw new IOException("相机返回了无效的 PTP/IP 响应");
        }
        return u16(response.data, 8);
    }

    /** 佳能 EOS 扩展属性写入（0x9110，12 字节 LE 载荷，TBC-awaiting-hardware）。 */
    private void canonWriteEosProp(int propCode, int value) throws Exception {
        ByteWriter payload = new ByteWriter();
        payload.u32(12);
        payload.u32(propCode);
        payload.u32(value);
        int response = sendCommandWithDataOut(
                CANON_EOS_SET_DEVICE_PROP_VALUE_EX,
                transactionId++,
                new long[0],
                payload.data());
        if (response != RESPONSE_OK) throw rejected(response);
    }

    /**
     * 佳能 EOS 取景开启（对齐 libgphoto2 canon.c，TBC-awaiting-hardware）：
     * EVFMode 读当前值非 1 才写（Movie 模式 Busy 容忍）；EVFOutputDevice
     * 仅 (cur & ~1)==0 时写 2=PC（读失败回退无条件写）。返回是否确认进入取景态。
     */
    private boolean canonOpenLiveView() throws Exception {
        boolean confirmed = false;
        try {
            int mode = readEosPropValue(CANON_EVF_MODE);
            if (mode != 1) {
                try {
                    canonWriteEosProp(CANON_EVF_MODE, 1);
                } catch (Exception busy) {
                    // Movie 模式 Busy 容忍。
                }
            }
            confirmed = true;
        } catch (Exception ignored) {
            // 读取失败容忍。
        }
        try {
            int current;
            try {
                current = readEosPropValue(CANON_EVF_OUTPUT_DEVICE);
            } catch (Exception readError) {
                current = -1; // 读失败回退无条件写
            }
            if (current < 0 || (current & ~1) == 0) {
                try {
                    canonWriteEosProp(CANON_EVF_OUTPUT_DEVICE, 2);
                } catch (Exception busy) {
                    // 容忍。
                }
            }
            confirmed = true;
        } catch (Exception ignored) {
        }
        liveView = confirmed;
        return confirmed;
    }

    /**
     * EOS 属性读取：标准 GetDevicePropValue(0x1015)（gphoto2 对 EOS 属性读
     * 同样走标准通道；0x9114 实为 SetRemoteMode 非属性读）。UINT16 回 2B / UINT32 回 4B。
     */
    private int readEosPropValue(int propCode) throws Exception {
        byte[] data = commandWithData(
                GET_DEVICE_PROP_VALUE,
                transactionId++,
                new long[]{propCode});
        if (data.length < 2) {
            throw new Exception("佳能属性读取返回长度不足。");
        }
        return data.length >= 4 ? (int) u32(data, 0) : u16(data, 0);
    }

    /**
     * EOS dataset → 内嵌 JPEG 提取（对齐 libgphoto2
     * ptp_canon_eos_get_viewfinder_image）：多个 blob 依 [u32 len][u32 type][payload]
     * 排列；type 1=常规 JPEG、9=Movie 模式 JPEG、11=JPEG；其余 type 跳过 len 字节。
     */
    private byte[] extractEosJpeg(byte[] source) throws Exception {
        int offset = 0;
        while (offset + 8 <= source.length) {
            int len = (source[offset] & 0xff)
                    | ((source[offset + 1] & 0xff) << 8)
                    | ((source[offset + 2] & 0xff) << 16)
                    | ((source[offset + 3] & 0xff) << 24);
            int type = (source[offset + 4] & 0xff)
                    | ((source[offset + 5] & 0xff) << 8)
                    | ((source[offset + 6] & 0xff) << 16)
                    | ((source[offset + 7] & 0xff) << 24);
            if (len < 8 || offset + len > source.length) break;
            if (type == 1 || type == 9 || type == 11) {
                // 载荷为 JPEG；再经标记扫描兜底（部分机身载荷带前导头）。
                return extractJpeg(
                        Arrays.copyOfRange(source, offset + 8, offset + len));
            }
            offset += len;
        }
        throw new Exception(
                cameraName + " 返回的佳能取景数据中没有 JPEG 图像。");
    }

    /** JPEG 标记扫描（FFD8/FFD9）。 */
    private byte[] extractJpeg(byte[] source) throws Exception {
        int start = -1;
        int end = -1;
        for (int index = 0; index < source.length - 1; index++) {
            if (start < 0 && (source[index] & 0xff) == 0xff
                    && (source[index + 1] & 0xff) == 0xd8) {
                start = index;
            }
            if (start >= 0 && (source[index] & 0xff) == 0xff
                    && (source[index + 1] & 0xff) == 0xd9) {
                end = index + 2;
            }
        }
        if (start < 0 || end <= start) {
            throw new Exception(cameraName + " 返回的数据中没有 JPEG 图像。");
        }
        return Arrays.copyOfRange(source, start, end);
    }

    /**
     * GetDeviceInfo 数据段 Manufacturer 解析（UTF-8，布局见 PTPIP_PROTOCOL.md §4）：
     * StandardVersion(2)+VendorExtensionID(4)+VendorExtensionVersion(2)+
     * VendorExtensionDesc(UTF8)+FunctionalMode(2)+四个数组(各 2 字节长度+条目)+
     * ImageFormats(同上)+Manufacturer(UTF8)。
     */
    private static String deviceInfoManufacturer(byte[] data) {
        if (data.length < 8) return null;
        int[] offset = new int[]{8};
        if (readUtf8(data, offset) == null) return null; // VendorExtensionDesc
        if (offset[0] + 2 > data.length) return null;
        offset[0] += 2; // FunctionalMode
        for (int index = 0; index < 4; index++) { // Operations/Events/DeviceProperties/CaptureFormats
            if (offset[0] + 2 > data.length) return null;
            int count = u16(data, offset[0]);
            offset[0] += 2;
            if (offset[0] + count * 2 > data.length) return null;
            offset[0] += count * 2;
        }
        if (offset[0] + 2 > data.length) return null;
        int imageCount = u16(data, offset[0]); // ImageFormats
        offset[0] += 2;
        if (offset[0] + imageCount * 2 > data.length) return null;
        offset[0] += imageCount * 2;
        return readUtf8(data, offset);
    }

    private static String readUtf8(byte[] data, int[] offsetRef) {
        int offset = offsetRef[0];
        if (offset >= data.length) return null;
        int end = offset;
        while (end < data.length && data[end] != 0) end++;
        if (end >= data.length) return null;
        String text = new String(
                data,
                offset,
                end - offset,
                StandardCharsets.UTF_8);
        offsetRef[0] = end + 1;
        return text;
    }

    private static CameraVendor vendorForManufacturer(
            String manufacturer,
            CameraVendor fallback) {
        String text = manufacturer.toLowerCase(Locale.ROOT);
        if (text.contains("nikon")) return CameraVendor.NIKON;
        if (text.contains("canon")) return CameraVendor.CANON;
        if (text.contains("sony")) return CameraVendor.SONY;
        return fallback;
    }

    private static CameraVendor vendorForName(String name) {
        String text = name.toLowerCase(Locale.ROOT);
        if (text.contains("nikon")) return CameraVendor.NIKON;
        if (text.contains("canon")) return CameraVendor.CANON;
        if (text.contains("sony") || text.contains("ilce") || text.contains("alpha")) {
            return CameraVendor.SONY;
        }
        return CameraVendor.UNKNOWN;
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
        vendor = CameraVendor.UNKNOWN;
        liveView = false;
        movieRecording = false;
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

        void u64(long value) {
            u32(value & 0xffff_ffffL);
            u32((value >>> 32) & 0xffff_ffffL);
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
