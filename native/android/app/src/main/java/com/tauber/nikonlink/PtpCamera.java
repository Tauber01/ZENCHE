package com.tauber.nikonlink;

import android.hardware.usb.UsbConstants;
import android.hardware.usb.UsbDevice;
import android.hardware.usb.UsbDeviceConnection;
import android.hardware.usb.UsbEndpoint;
import android.hardware.usb.UsbInterface;
import android.hardware.usb.UsbManager;

import java.io.ByteArrayOutputStream;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.Arrays;
import java.util.HashMap;
import java.util.Map;

final class PtpCamera {
    static final int NIKON_VENDOR_ID = 0x04b0;
    static final String SUPPORTED_CAMERA_SUMMARY =
            "Z7、Z6、Z50、D780、D6、Z5、Z7II、Z6II、Z fc、Z9、Z8、Z30、"
                    + "Z f、Z6III、Z50II、Z5II、ZR";
    private static final CameraProfile[] SUPPORTED_CAMERAS = new CameraProfile[]{
            new CameraProfile("Nikon Z7", 0x0442, 64, 25600),
            new CameraProfile("Nikon Z6", 0x0443, 100, 51200),
            new CameraProfile("Nikon Z50", 0x0444, 100, 51200),
            new CameraProfile("Nikon D780", 0x0446, 100, 51200),
            new CameraProfile("Nikon D6", 0x0447, 100, 102400),
            new CameraProfile("Nikon Z5", 0x0448, 100, 51200),
            new CameraProfile("Nikon Z7II", 0x044b, 64, 25600),
            new CameraProfile("Nikon Z6II", 0x044c, 100, 51200),
            new CameraProfile("Nikon Z fc", 0x044f, 100, 51200),
            new CameraProfile("Nikon Z9", 0x0450, 64, 25600),
            new CameraProfile("Nikon Z8", 0x0451, 64, 25600),
            new CameraProfile("Nikon Z30", 0x0452, 100, 51200),
            new CameraProfile("Nikon Z f", 0x0453, 100, 64000),
            new CameraProfile("Nikon Z6III", 0x0454, 100, 64000),
            new CameraProfile("Nikon Z50II", 0x0455, 100, 51200),
            new CameraProfile("Nikon Z5II", 0x0456, 100, 64000),
            new CameraProfile("Nikon ZR", 0x0457, 100, 51200)
    };

    private static final int TYPE_COMMAND = 1;
    private static final int TYPE_DATA = 2;
    private static final int TYPE_RESPONSE = 3;
    private static final int RESPONSE_OK = 0x2001;
    private static final int OPEN_SESSION = 0x1002;
    private static final int CLOSE_SESSION = 0x1003;
    private static final int GET_OBJECT = 0x1009;
    private static final int SET_DEVICE_PROP = 0x1016;
    private static final int CHANGE_CAMERA_MODE = 0x90c2;
    private static final int DEVICE_READY = 0x90c8;
    private static final int GET_EVENT = 0x90c7;
    private static final int START_LIVE_VIEW = 0x9201;
    private static final int END_LIVE_VIEW = 0x9202;
    private static final int GET_LIVE_VIEW_IMAGE = 0x9203;
    private static final int CAPTURE_TO_SDRAM = 0x9207;
    private static final int TERMINATE_CAPTURE = 0x920c;
    private static final int OBJECT_ADDED_IN_SDRAM = 0xc101;

    private final MainActivity activity;
    private UsbDeviceConnection connection;
    private UsbInterface cameraInterface;
    private UsbEndpoint bulkIn;
    private UsbEndpoint bulkOut;
    private int transaction = 0;
    private boolean liveView;
    private String exposureMode = "manual";
    private int bulbDurationSeconds = 5;
    private CameraProfile profile;

    PtpCamera(MainActivity activity) {
        this.activity = activity;
    }

    synchronized Map<String, Object> connect() throws Exception {
        disconnect();
        UsbManager manager = (UsbManager) activity.getSystemService(MainActivity.USB_SERVICE);
        UsbDevice device = null;
        UsbDevice unsupportedNikon = null;
        for (UsbDevice candidate : manager.getDeviceList().values()) {
            if (candidate.getVendorId() != NIKON_VENDOR_ID) continue;
            CameraProfile candidateProfile = profileFor(candidate);
            if (candidateProfile != null) {
                device = candidate;
                profile = candidateProfile;
                break;
            }
            unsupportedNikon = candidate;
        }
        if (device == null) {
            if (unsupportedNikon != null) {
                throw new Exception(String.format(
                        "检测到未支持的 Nikon USB 设备 04b0:%04x。当前支持 %s。",
                        unsupportedNikon.getProductId(),
                        SUPPORTED_CAMERA_SUMMARY));
            }
            throw new Exception(
                    "没有检测到支持的 Nikon 相机。请连接 "
                            + SUPPORTED_CAMERA_SUMMARY
                            + "。");
        }
        if (!activity.ensureUsbPermission(manager, device)) {
            throw new Exception("未获得 " + cameraName() + " 的 USB 访问权限。");
        }
        for (int index = 0; index < device.getInterfaceCount(); index++) {
            UsbInterface candidate = device.getInterface(index);
            if (candidate.getInterfaceClass() != UsbConstants.USB_CLASS_STILL_IMAGE) continue;
            UsbEndpoint input = null;
            UsbEndpoint output = null;
            for (int endpointIndex = 0; endpointIndex < candidate.getEndpointCount(); endpointIndex++) {
                UsbEndpoint endpoint = candidate.getEndpoint(endpointIndex);
                if (endpoint.getType() != UsbConstants.USB_ENDPOINT_XFER_BULK) continue;
                if (endpoint.getDirection() == UsbConstants.USB_DIR_IN) input = endpoint;
                if (endpoint.getDirection() == UsbConstants.USB_DIR_OUT) output = endpoint;
            }
            if (input != null && output != null) {
                cameraInterface = candidate;
                bulkIn = input;
                bulkOut = output;
                break;
            }
        }
        if (cameraInterface == null) {
            throw new Exception(cameraName() + " 没有提供可用的 PTP USB 接口。");
        }

        connection = manager.openDevice(device);
        if (connection == null || !connection.claimInterface(cameraInterface, true)) {
            String failedCamera = cameraName();
            disconnect();
            throw new Exception("无法打开 " + failedCamera + "。请关闭 NX MobileAir 等占用相机的应用。");
        }
        transaction = 0;
        transact(OPEN_SESSION, new long[]{1}, null, 10_000);

        Map<String, Object> result = new HashMap<>();
        result.put("device", mapOf(
                "id", String.format("%04x:%04x", device.getVendorId(), device.getProductId()),
                "label", cameraName(),
                "transport", "USB/PTP"));
        result.put("capabilities", capabilities(profile));
        result.put("settings", defaultSettings());
        return result;
    }

    synchronized void startLiveView() throws Exception {
        ensureConnected();
        if (!liveView) {
            transact(START_LIVE_VIEW, null, null, 10_000);
            liveView = true;
        }
    }

    synchronized void stopLiveView() {
        if (!liveView || connection == null) return;
        try {
            transact(END_LIVE_VIEW, null, null, 5_000);
        } catch (Exception ignored) {
        }
        liveView = false;
    }

    synchronized byte[] getLiveViewFrame() throws Exception {
        ensureConnected();
        if (!liveView) throw new Exception("实时取景尚未开启。");
        return extractJpeg(transact(GET_LIVE_VIEW_IMAGE, null, null, 12_000));
    }

    synchronized byte[] capture() throws Exception {
        ensureConnected();
        boolean resumeLiveView = liveView;
        if (resumeLiveView) stopLiveView();
        try {
            if ("bulb".equals(exposureMode)) {
                transact(CHANGE_CAMERA_MODE, new long[]{1}, null, 10_000);
                transact(
                        SET_DEVICE_PROP,
                        new long[]{0x500e},
                        littleEndian16(1),
                        10_000);
                transact(
                        SET_DEVICE_PROP,
                        new long[]{0x500d},
                        littleEndian32(0xffffffffL),
                        10_000);
                transact(CAPTURE_TO_SDRAM, new long[]{0xffffffffL, 1}, null, 60_000);
                Thread.sleep(Math.max(1, Math.min(bulbDurationSeconds, 900)) * 1000L);
                transact(TERMINATE_CAPTURE, new long[]{0, 0}, null, 15_000);
            } else {
                transact(CAPTURE_TO_SDRAM, new long[]{0xffffffffL, 1}, null, 60_000);
            }
            long handle = 0xffff0001L;
            long deadline = System.currentTimeMillis() + 30_000;
            while (System.currentTimeMillis() < deadline) {
                try {
                    transact(DEVICE_READY, null, null, 3_000);
                    byte[] events = transact(GET_EVENT, null, null, 3_000);
                    long eventHandle = findSdramObject(events);
                    if (eventHandle != 0) {
                        handle = eventHandle;
                        break;
                    }
                } catch (Exception ignored) {
                }
                Thread.sleep(180);
            }
            return extractJpeg(transact(GET_OBJECT, new long[]{handle}, null, 60_000));
        } finally {
            if (resumeLiveView) {
                try {
                    startLiveView();
                } catch (Exception ignored) {
                }
            }
        }
    }

    synchronized Object setParameter(String name, Object rawValue) throws Exception {
        ensureConnected();
        if ("bulbDuration".equals(name)) {
            if (!"bulb".equals(exposureMode)) {
                throw new Exception("B门曝光时长仅能在 M 拍摄模式的 B门快门速度下调整。");
            }
            bulbDurationSeconds = Math.max(
                    1,
                    Math.min(900, ((Number) rawValue).intValue()));
            return bulbDurationSeconds;
        }
        if (!canAdjustExposureParameter(name)) {
            throw new Exception("当前拍摄模式下此参数由相机控制。");
        }
        if ("focusMode".equals(name)) {
            String mode = String.valueOf(rawValue);
            int stillFocusMode = "manual".equals(mode)
                    ? 0x0001
                    : "continuous".equals(mode) ? 0x8011 : 0x8010;
            try {
                transact(
                        SET_DEVICE_PROP,
                        new long[]{0x500a},
                        littleEndian16(stillFocusMode),
                        10_000);
            } catch (Exception stillFocusError) {
                int liveViewFocusMode = "manual".equals(mode)
                        ? 4
                        : "continuous".equals(mode) ? 1 : 0;
                transact(
                        SET_DEVICE_PROP,
                        new long[]{0xd061},
                        new byte[]{(byte) liveViewFocusMode},
                        10_000);
            }
            return rawValue;
        }
        int property;
        byte[] value;
        double number = rawValue instanceof Number ? ((Number) rawValue).doubleValue() : 0;
        switch (name) {
            case "exposureTime":
                property = 0x500d;
                value = littleEndian32(Math.round(number * 10_000));
                break;
            case "aperture":
                property = 0x5007;
                value = littleEndian16((int) Math.round(number * 100));
                break;
            case "iso":
                property = 0x500f;
                value = littleEndian16((int) Math.round(number));
                break;
            case "exposureCompensation":
                property = 0x5010;
                value = littleEndian16((int) Math.round(number * 1000));
                break;
            case "whiteBalanceMode":
                property = 0x5005;
                value = littleEndian16("continuous".equals(rawValue) ? 0x0002 : 0x8013);
                break;
            case "pictureControl":
                property = 0xd200;
                String pictureControl = String.valueOf(rawValue);
                int control;
                if ("neutral".equals(pictureControl)) control = 2;
                else if ("vivid".equals(pictureControl)) control = 3;
                else if ("monochrome".equals(pictureControl)) control = 4;
                else if ("portrait".equals(pictureControl)) control = 5;
                else if ("landscape".equals(pictureControl)) control = 6;
                else if ("flat".equals(pictureControl)) control = 7;
                else if ("auto".equals(pictureControl)) control = 8;
                else control = 1;
                value = littleEndian16(control);
                break;
            case "exposureMode":
                exposureMode = String.valueOf(rawValue);
                property = 0x500e;
                if ("bulb".equals(exposureMode)) {
                    transact(CHANGE_CAMERA_MODE, new long[]{1}, null, 10_000);
                    transact(
                            SET_DEVICE_PROP,
                            new long[]{property},
                            littleEndian16(1),
                            10_000);
                    transact(
                            SET_DEVICE_PROP,
                            new long[]{0x500d},
                            littleEndian32(0xffffffffL),
                            10_000);
                    return rawValue;
                }
                int program;
                if ("manual".equals(exposureMode)) program = 1;
                else if ("aperturePriority".equals(exposureMode)) program = 3;
                else if ("shutterPriority".equals(exposureMode)) program = 4;
                else program = 2;
                value = littleEndian16(program);
                break;
            default:
                throw new Exception(cameraName() + " 不支持此参数：" + name);
        }
        transact(SET_DEVICE_PROP, new long[]{property}, value, 10_000);
        return rawValue;
    }

    private boolean canAdjustExposureParameter(String name) {
        switch (name) {
            case "exposureTime":
                return "manual".equals(exposureMode) || "shutterPriority".equals(exposureMode);
            case "aperture":
                return "manual".equals(exposureMode)
                        || "aperturePriority".equals(exposureMode)
                        || "bulb".equals(exposureMode);
            case "iso":
                return true;
            case "exposureCompensation":
                return "program".equals(exposureMode)
                        || "aperturePriority".equals(exposureMode)
                        || "shutterPriority".equals(exposureMode);
            default:
                return true;
        }
    }

    synchronized void disconnect() {
        stopLiveView();
        if (connection != null) {
            try {
                transact(CLOSE_SESSION, null, null, 2_000);
            } catch (Exception ignored) {
            }
            if (cameraInterface != null) connection.releaseInterface(cameraInterface);
            connection.close();
        }
        connection = null;
        cameraInterface = null;
        bulkIn = null;
        bulkOut = null;
        profile = null;
    }

    private byte[] transact(int operation, long[] params, byte[] outgoingData, int timeout) throws Exception {
        ensureConnectedForOperation(operation);
        int current = ++transaction;
        sendContainer(TYPE_COMMAND, operation, current, parameterBytes(params), timeout);
        if (outgoingData != null) sendContainer(TYPE_DATA, operation, current, outgoingData, timeout);

        Container first = receiveContainer(timeout);
        byte[] data = new byte[0];
        Container response = first;
        if (first.type == TYPE_DATA) {
            data = first.payload;
            response = receiveContainer(timeout);
        }
        if (response.type != TYPE_RESPONSE) {
            throw new Exception(cameraName() + " 返回了无效的 PTP 数据。");
        }
        if (response.code != RESPONSE_OK) {
            throw new Exception(String.format(
                    "%s PTP 错误 0x%04X（操作 0x%04X）",
                    cameraName(),
                    response.code,
                    operation));
        }
        return data;
    }

    private void sendContainer(int type, int code, int current, byte[] payload, int timeout) throws Exception {
        int size = 12 + payload.length;
        ByteBuffer packet = ByteBuffer.allocate(size).order(ByteOrder.LITTLE_ENDIAN);
        packet.putInt(size);
        packet.putShort((short) type);
        packet.putShort((short) code);
        packet.putInt(current);
        packet.put(payload);
        byte[] bytes = packet.array();
        int offset = 0;
        while (offset < bytes.length) {
            int sent = connection.bulkTransfer(bulkOut, bytes, offset, bytes.length - offset, timeout);
            if (sent <= 0) throw new Exception("向 " + cameraName() + " 发送 USB 数据失败。");
            offset += sent;
        }
    }

    private Container receiveContainer(int timeout) throws Exception {
        byte[] first = new byte[1024 * 1024];
        int received = connection.bulkTransfer(bulkIn, first, first.length, timeout);
        if (received < 12) throw new Exception("读取 " + cameraName() + " USB 数据失败。");
        ByteBuffer header = ByteBuffer.wrap(first, 0, received).order(ByteOrder.LITTLE_ENDIAN);
        int total = header.getInt();
        int type = header.getShort() & 0xffff;
        int code = header.getShort() & 0xffff;
        header.getInt();
        if (total < 12 || total > 256 * 1024 * 1024) {
            throw new Exception(cameraName() + " 返回的数据长度无效。");
        }
        ByteArrayOutputStream all = new ByteArrayOutputStream(total);
        all.write(first, 0, received);
        while (all.size() < total) {
            int remaining = total - all.size();
            byte[] chunk = new byte[Math.min(1024 * 1024, remaining)];
            int count = connection.bulkTransfer(bulkIn, chunk, chunk.length, timeout);
            if (count <= 0) throw new Exception(cameraName() + " 图像传输中断。");
            all.write(chunk, 0, count);
        }
        byte[] container = all.toByteArray();
        return new Container(type, code, Arrays.copyOfRange(container, 12, total));
    }

    private static long findSdramObject(byte[] events) {
        if (events.length < 2) return 0;
        ByteBuffer buffer = ByteBuffer.wrap(events).order(ByteOrder.LITTLE_ENDIAN);
        int count = buffer.getShort() & 0xffff;
        for (int index = 0; index < count && buffer.remaining() >= 6; index++) {
            int code = buffer.getShort() & 0xffff;
            long handle = buffer.getInt() & 0xffffffffL;
            if (code == OBJECT_ADDED_IN_SDRAM) return handle;
        }
        return 0;
    }

    private byte[] extractJpeg(byte[] source) throws Exception {
        int start = -1;
        int end = -1;
        for (int index = 0; index < source.length - 1; index++) {
            if (start < 0 && (source[index] & 0xff) == 0xff && (source[index + 1] & 0xff) == 0xd8) {
                start = index;
            }
            if (start >= 0 && (source[index] & 0xff) == 0xff && (source[index + 1] & 0xff) == 0xd9) {
                end = index + 2;
            }
        }
        if (start < 0 || end <= start) {
            throw new Exception(cameraName() + " 返回的数据中没有 JPEG 图像。");
        }
        return Arrays.copyOfRange(source, start, end);
    }

    private static byte[] parameterBytes(long[] params) {
        if (params == null || params.length == 0) return new byte[0];
        ByteBuffer buffer = ByteBuffer.allocate(params.length * 4).order(ByteOrder.LITTLE_ENDIAN);
        for (long value : params) buffer.putInt((int) value);
        return buffer.array();
    }

    private static byte[] littleEndian16(int value) {
        return ByteBuffer.allocate(2).order(ByteOrder.LITTLE_ENDIAN).putShort((short) value).array();
    }

    private static byte[] littleEndian32(long value) {
        return ByteBuffer.allocate(4).order(ByteOrder.LITTLE_ENDIAN).putInt((int) value).array();
    }

    private static Map<String, Object> defaultSettings() {
        return mapOf(
                "width", 1024,
                "height", 680,
                "frameRate", 3,
                "exposureTime", 0.008,
                "aperture", 4.0,
                "iso", 400,
                "exposureCompensation", 0.0,
                "focusMode", "single-shot",
                "whiteBalanceMode", "continuous",
                "exposureMode", "manual",
                "pictureControl", "standard");
    }

    private static Map<String, Object> capabilities(CameraProfile profile) {
        return mapOf(
                "exposureTime", mapOf("min", 0.000125, "max", 30.0),
                "aperture", mapOf("min", 1.2, "max", 22.0),
                "iso", mapOf("min", profile.minIso, "max", profile.maxIso),
                "exposureCompensation", mapOf("min", -5.0, "max", 5.0),
                "focusMode", new String[]{"single-shot", "continuous", "manual"},
                "whiteBalanceMode", new String[]{"continuous", "manual"},
                "pictureControl", new String[]{
                        "auto",
                        "standard",
                        "neutral",
                        "vivid",
                        "monochrome",
                        "portrait",
                        "landscape",
                        "flat"},
                "exposureMode", new String[]{
                        "program",
                        "manual",
                        "aperturePriority",
                        "shutterPriority",
                        "bulb"});
    }

    static Map<String, Object> mapOf(Object... values) {
        Map<String, Object> map = new HashMap<>();
        for (int index = 0; index < values.length; index += 2) {
            map.put(String.valueOf(values[index]), values[index + 1]);
        }
        return map;
    }

    private void ensureConnected() throws Exception {
        if (connection == null) throw new Exception("请先连接支持的 Nikon 相机。");
    }

    private void ensureConnectedForOperation(int operation) throws Exception {
        if (operation != OPEN_SESSION) ensureConnected();
        else if (connection == null) throw new Exception("无法打开 Nikon USB 连接。");
    }

    synchronized String getConnectedCameraName() {
        return cameraName();
    }

    synchronized int getMinimumIso() {
        return profile == null ? 100 : profile.minIso;
    }

    synchronized int getMaximumIso() {
        return profile == null ? 64000 : profile.maxIso;
    }

    private String cameraName() {
        return profile == null ? "Nikon 相机" : profile.name;
    }

    private static CameraProfile profileFor(int productId) {
        for (CameraProfile candidate : SUPPORTED_CAMERAS) {
            if (candidate.productId == productId) return candidate;
        }
        return null;
    }

    private static CameraProfile profileFor(UsbDevice device) {
        CameraProfile byProductId = profileFor(device.getProductId());
        if (byProductId != null) return byProductId;
        String descriptor = device.getProductName();
        if (descriptor == null) return null;
        String normalized = descriptor
                .toLowerCase()
                .replace("_", "")
                .replace("-", "")
                .replace(" ", "");
        String generationAlias = normalized
                .replace("iii", "3")
                .replace("ii", "2");
        CameraProfile bestMatch = null;
        int bestMatchLength = 0;
        for (CameraProfile candidate : SUPPORTED_CAMERAS) {
            String candidateName = candidate.name
                    .toLowerCase()
                    .replace("nikon", "")
                    .replace(" ", "");
            String candidateAlias = candidateName
                    .replace("iii", "3")
                    .replace("ii", "2");
            if ((normalized.contains(candidateName)
                    || generationAlias.contains(candidateAlias))
                    && candidateAlias.length() > bestMatchLength) {
                bestMatch = candidate;
                bestMatchLength = candidateAlias.length();
            }
        }
        return bestMatch;
    }

    private static final class CameraProfile {
        final String name;
        final int productId;
        final int minIso;
        final int maxIso;

        CameraProfile(String name, int productId, int minIso, int maxIso) {
            this.name = name;
            this.productId = productId;
            this.minIso = minIso;
            this.maxIso = maxIso;
        }
    }

    private static final class Container {
        final int type;
        final int code;
        final byte[] payload;

        Container(int type, int code, byte[] payload) {
            this.type = type;
            this.code = code;
            this.payload = payload;
        }
    }
}
