package com.tauber.nikonlink;

import android.hardware.usb.UsbConstants;
import android.hardware.usb.UsbDevice;
import android.hardware.usb.UsbDeviceConnection;
import android.hardware.usb.UsbEndpoint;
import android.hardware.usb.UsbInterface;
import android.hardware.usb.UsbManager;
import android.hardware.usb.UsbRequest;
import android.os.Build;

import java.io.ByteArrayOutputStream;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.Arrays;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.TimeoutException;

final class PtpCamera {
    static final Set<Integer> SUPPORTED_VENDOR_IDS = new HashSet<>(Arrays.asList(
            0x04b0, 0x054c, 0x04a9
    ));
    static final String SUPPORTED_CAMERA_SUMMARY =
            "Nikon D500、Z7、Z6、Z50、D7500、D780、D6、Z5、D850、Z7II、Z6II、Z fc、Z9、Z8、Z30、"
                    + "Z f、Z6III、Z50II、Z5II、ZR"
                    + "、Sony A1、A7R V、A7 IV、A7S III、A7C II"
                    + "、Canon EOS R5、R6 Mark II、R3、R7、R8、R6 Mark III、R6、R5 C、R50 V";
    private static final CameraProfile[] SUPPORTED_CAMERAS = new CameraProfile[]{
            // ── Nikon EXPEED 5 ──
            new CameraProfile("Nikon D500", "Nikon", 0x04b0, 0x043a, 100, 51200),
            new CameraProfile("Nikon D7500", "Nikon", 0x04b0, 0x0445, 100, 51200),
            new CameraProfile("Nikon D850", "Nikon", 0x04b0, 0x044a, 64, 25600),
            // ── Nikon EXPEED 6 ──
            new CameraProfile("Nikon Z7", "Nikon", 0x04b0, 0x0442, 64, 25600),
            new CameraProfile("Nikon Z6", "Nikon", 0x04b0, 0x0443, 100, 51200),
            new CameraProfile("Nikon Z50", "Nikon", 0x04b0, 0x0444, 100, 51200),
            new CameraProfile("Nikon D780", "Nikon", 0x04b0, 0x0446, 100, 51200),
            new CameraProfile("Nikon D6", "Nikon", 0x04b0, 0x0447, 100, 102400),
            new CameraProfile("Nikon Z5", "Nikon", 0x04b0, 0x0448, 100, 51200),
            new CameraProfile("Nikon Z7II", "Nikon", 0x04b0, 0x044b, 64, 25600),
            new CameraProfile("Nikon Z6II", "Nikon", 0x04b0, 0x044c, 100, 51200),
            new CameraProfile("Nikon Z fc", "Nikon", 0x04b0, 0x044f, 100, 51200),
            new CameraProfile("Nikon Z30", "Nikon", 0x04b0, 0x0452, 100, 51200),
            // ── Nikon EXPEED 7 ──
            new CameraProfile("Nikon Z9", "Nikon", 0x04b0, 0x0450, 64, 25600),
            new CameraProfile("Nikon Z8", "Nikon", 0x04b0, 0x0451, 64, 25600),
            new CameraProfile("Nikon Z f", "Nikon", 0x04b0, 0x0453, 100, 64000),
            new CameraProfile("Nikon Z6III", "Nikon", 0x04b0, 0x0454, 100, 64000),
            new CameraProfile("Nikon Z50II", "Nikon", 0x04b0, 0x0455, 100, 51200),
            new CameraProfile("Nikon Z5II", "Nikon", 0x04b0, 0x0456, 100, 64000),
            new CameraProfile("Nikon ZR", "Nikon", 0x04b0, 0x0457, 100, 51200),
            // ── Sony α ── (Product ID 0 means vendor wildcard)
            // Full-frame E-mount
            new CameraProfile("Sony A1", "Sony", 0x054c, 0x0000, 100, 32000),
            new CameraProfile("Sony A1 II", "Sony", 0x054c, 0x0000, 100, 32000),
            new CameraProfile("Sony A9 III", "Sony", 0x054c, 0x0000, 100, 51200),
            new CameraProfile("Sony A7R V", "Sony", 0x054c, 0x0000, 100, 32000),
            new CameraProfile("Sony A7 IV", "Sony", 0x054c, 0x0000, 100, 51200),
            new CameraProfile("Sony A7S III", "Sony", 0x054c, 0x0000, 80, 102400),
            new CameraProfile("Sony A7C II", "Sony", 0x054c, 0x0000, 100, 51200),
            new CameraProfile("Sony A7C R", "Sony", 0x054c, 0x0000, 100, 32000),
            new CameraProfile("Sony ZV-E1", "Sony", 0x054c, 0x0000, 80, 102400),
            // APS-C E-mount
            new CameraProfile("Sony A6700", "Sony", 0x054c, 0x0000, 100, 32000),
            new CameraProfile("Sony FX30", "Sony", 0x054c, 0x0000, 100, 32000),
            new CameraProfile("Sony ZV-E10 II", "Sony", 0x054c, 0x0000, 100, 32000),
            // ── Canon EOS R ── (Product IDs: TODO — confirm with gphoto2 --auto-detect)
            new CameraProfile("Canon EOS R1", "Canon", 0x04a9, 0x0000, 100, 102400),
            new CameraProfile("Canon EOS R3", "Canon", 0x04a9, 0x0000, 100, 102400),
            new CameraProfile("Canon EOS R5", "Canon", 0x04a9, 0x0000, 100, 51200),
            new CameraProfile("Canon EOS R5 Mark II", "Canon", 0x04a9, 0x0000, 100, 51200),
            new CameraProfile("Canon EOS R6 Mark II", "Canon", 0x04a9, 0x0000, 100, 102400),
            new CameraProfile("Canon EOS R7", "Canon", 0x04a9, 0x0000, 100, 12800),
            new CameraProfile("Canon EOS R8", "Canon", 0x04a9, 0x0000, 100, 102400),
            new CameraProfile("Canon EOS R10", "Canon", 0x04a9, 0x0000, 100, 12800),
            new CameraProfile("Canon EOS R50", "Canon", 0x04a9, 0x0000, 100, 12800),
            new CameraProfile("Canon EOS R100", "Canon", 0x04a9, 0x0000, 100, 12800),
            // ── Canon DIGIC X (2025 补齐) ──
            new CameraProfile("Canon EOS R6 Mark III", "Canon", 0x04a9, 0x0000, 100, 64000),
            new CameraProfile("Canon EOS R6", "Canon", 0x04a9, 0x0000, 100, 102400),
            new CameraProfile("Canon EOS R5 C", "Canon", 0x04a9, 0x0000, 100, 51200),
            new CameraProfile("Canon EOS R50 V", "Canon", 0x04a9, 0x0000, 100, 32000),
    };

    private static final int TYPE_COMMAND = 1;
    private static final int TYPE_DATA = 2;
    private static final int TYPE_RESPONSE = 3;
    private static final int RESPONSE_OK = 0x2001;
    private static final int RESPONSE_SESSION_ALREADY_OPEN = 0x201e;
    private static final int OPEN_SESSION = 0x1002;
    private static final int CLOSE_SESSION = 0x1003;
    private static final int GET_STORAGE_IDS = 0x1004;
    private static final int GET_STORAGE_INFO = 0x1005;
    private static final int GET_OBJECT_HANDLES = 0x1007;
    private static final int GET_OBJECT_INFO = 0x1008;
    private static final int GET_OBJECT = 0x1009;
    private static final int GET_THUMB = 0x100a;
    private static final int DELETE_OBJECT = 0x100b;
    private static final int GET_DEVICE_PROP_DESC = 0x1014;
    private static final int GET_DEVICE_PROP_VALUE = 0x1015;
    private static final int SET_DEVICE_PROP = 0x1016;
    private static final int CHANGE_CAMERA_MODE = 0x90c2;
    private static final int DEVICE_READY = 0x90c8;
    private static final int GET_EVENT = 0x90c7;
    private static final int START_LIVE_VIEW = 0x9201;
    private static final int END_LIVE_VIEW = 0x9202;
    private static final int GET_LIVE_VIEW_IMAGE = 0x9203;
    private static final int MANUAL_FOCUS_DRIVE = 0x9204;
    private static final int AUTO_FOCUS_DRIVE = 0x90c1;
    private static final int CAPTURE_TO_SDRAM = 0x9207;
    private static final int START_MOVIE_RECORDING = 0x920a;
    private static final int END_MOVIE_RECORDING = 0x920b;
    private static final int TERMINATE_CAPTURE = 0x920c;
    private static final int OBJECT_ADDED_IN_SDRAM = 0xc101;
    private static final int USB_REQUEST_CLEAR_FEATURE = 0x01;
    private static final int USB_FEATURE_ENDPOINT_HALT = 0x00;
    private static final int USB_RECIPIENT_INTERFACE = 0x01;
    private static final int USB_RECIPIENT_ENDPOINT = 0x02;
    private static final int PTP_USB_REQUEST_RESET = 0x66;
    private static final int CONNECT_ATTEMPTS = 3;
    private static final int EXPOSURE_TIME = 0x500d;
    private static final int NIKON_EXPOSURE_TIME = 0xd100;
    private static final int NIKON_MOVIE_EXPOSURE_TIME = 0xd1a8;
    private static final int NIKON_MOVIE_FILE_TYPE = 0xd0af;
    private static final int NIKON_MOVIE_PRORES_TONE_MODE = 0x0001d000;
    private static final int NIKON_MOVIE_H265_TONE_MODE = 0x0001d001;
    private static final int NIKON_MOVIE_NRAW_TONE_MODE = 0x0001d028;
    private static final int NIKON_MOVIE_PRORES_RAW_TONE_MODE = 0x0001d029;
    private static final int NIKON_H264_8_BIT = 0x00000801;
    private static final int NIKON_H265_10_BIT = 0x00010a00;
    private static final int NIKON_NRAW_12_BIT = 0x00020c02;
    private static final int NIKON_PRORES_422_10_BIT = 0x00100a00;
    private static final int NIKON_PRORES_RAW_12_BIT = 0x00110c00;
    private static final int SONY_PICTURE_PROFILE = 0xd23f;
    private static final int SONY_MOVIE_FILE_FORMAT = 0xd241;
    private static final int CANON_EOS_SET_DEVICE_PROP_VALUE_EX = 0x9110;
    private static final int CANON_LOG_GAMMA = 0xd176;
    // Canon EOS 录像/取景扩展（libgphoto2 camlibs/ptp2/ptp.h 常量）：
    // - EVFRecordStatus(0xD1b8)：0=停止录像 1=开始录像（digiCamControl/qDslrDashboard 社区方案）
    // - EVFMode(0xD1b1)：UINT16，0=off 1=on（gphoto2 canon.c 序列）
    // - EVFOutputDevice(0xD1b0)：UINT32 mask，bit0=TFT bit1=PC，2=PC（gphoto2 canon.c 序列）
    private static final int CANON_EVF_RECORD_STATUS = 0xd1b8;
    private static final int CANON_EVF_MODE = 0xd1b1;
    private static final int CANON_EVF_OUTPUT_DEVICE = 0xd1b0;
    private static final int USB_BULK_CHUNK_BYTES =
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.P
                    ? 64 * 1024
                    : 16 * 1024;

    private final MainActivity activity;
    private final DiagnosticLogger diagnostics;
    private UsbManager usbManager;
    private int connectedProductId = -1;
    private UsbDeviceConnection connection;
    private UsbInterface cameraInterface;
    private UsbEndpoint bulkIn;
    private UsbEndpoint bulkOut;
    // Sticky synchronous mode: after one successful UsbRequest→bulkTransfer
    // fallback, every later request in this session goes straight to
    // bulkTransfer so a flaky device never waits out the async timeout again
    // (the recurring pattern in #33/#37/#39/#40). Cleared whenever a fresh
    // transport is opened or the connection closes.
    private boolean syncTransport;
    private int transaction = 0;
    private boolean liveView;
    private boolean movieRecording;
    private String exposureMode = "manual";
    private int bulbDurationSeconds = 5;
    private CameraProfile profile;
    private final Map<Integer, Boolean> writableProperties = new HashMap<>();
    private final Set<String> deniedParameters = new HashSet<>();

    PtpCamera(MainActivity activity, DiagnosticLogger diagnostics) {
        this.activity = activity;
        this.diagnostics = diagnostics;
    }

    synchronized Map<String, Object> connect() throws Exception {
        disconnect();
        UsbManager manager = (UsbManager) activity.getSystemService(MainActivity.USB_SERVICE);
        UsbDevice device = null;
        UsbDevice unsupportedDevice = null;
        for (UsbDevice candidate : manager.getDeviceList().values()) {
            if (!SUPPORTED_VENDOR_IDS.contains(candidate.getVendorId())) continue;
            CameraProfile candidateProfile = profileFor(candidate);
            if (candidateProfile != null) {
                device = candidate;
                profile = candidateProfile;
                break;
            }
            if (unsupportedDevice == null) {
                unsupportedDevice = candidate;
            }
        }
        if (device == null) {
            if (unsupportedDevice != null) {
                String vendorHex = String.format("%04x", unsupportedDevice.getVendorId());
                String productHex = String.format("%04x", unsupportedDevice.getProductId());
                throw new Exception(String.format(
                        "检测到未支持的 USB 相机设备 %s:%s。当前支持 %s。",
                        vendorHex, productHex,
                        SUPPORTED_CAMERA_SUMMARY));
            }
            throw new Exception(
                    "没有检测到支持的相机。请连接 "
                            + SUPPORTED_CAMERA_SUMMARY
                            + "。");
        }
        if (!activity.ensureUsbPermission(manager, device)) {
            throw new Exception("未获得 " + cameraName() + " 的 USB 访问权限。");
        }
        usbManager = manager;
        connectedProductId = device.getProductId();
        try {
            openFreshTransport(device);
            openSessionWithRecovery();
            refreshParameterCapabilities();
        } catch (Exception error) {
            closeTransport();
            throw error;
        }

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

    synchronized void startMovieRecording() throws Exception {
        ensureConnected();
        if (movieRecording) return;
        if (isCanon()) {
            canonStartMovieRecording();
            return;
        }
        if (!liveView) startLiveView();
        transact(START_MOVIE_RECORDING, null, null, 15_000);
        movieRecording = true;
    }

    synchronized void stopMovieRecording() throws Exception {
        ensureConnected();
        if (!movieRecording) return;
        if (isCanon()) {
            try {
                canonStopMovieRecording();
            } finally {
                movieRecording = false;
            }
            return;
        }
        try {
            transact(END_MOVIE_RECORDING, null, null, 15_000);
        } finally {
            movieRecording = false;
        }
    }

    private boolean isCanon() {
        return profile != null && profile.vendorId == 0x04a9;
    }

    /**
     * 佳能 EOS 录像启停：经 EOS_SetDevicePropValueEx(0x9110) 写
     * EVFRecordStatus(0xD1b8)，0=停止录像、1=开始录像。
     * 参照 libgphoto2 常量与 digiCamControl/qDslrDashboard 社区方案实现，
     * 未在佳能实机验证（TBC-awaiting-hardware）。
     */
    private void canonWriteEosProp(int propCode, int value) throws Exception {
        byte[] payload = new byte[12];
        ByteBuffer buffer = ByteBuffer.wrap(payload).order(ByteOrder.LITTLE_ENDIAN);
        buffer.putInt(12);
        buffer.putInt(propCode);
        buffer.putInt(value);
        transact(CANON_EOS_SET_DEVICE_PROP_VALUE_EX, null, payload, 10_000);
    }

    private void canonStartMovieRecording() throws Exception {
        // 未处于取景态时，先按 gphoto2 canon.c 序列开启实时取景：
        // EVFMode=1（on）+ EVFOutputDevice 置 PC 位（2）。部分机型在 Movie
        // 模式下对 EVFMode 返回 Busy，容忍失败不阻断录像。
        if (!liveView) {
            try {
                canonWriteEosProp(CANON_EVF_MODE, 1); // TBC-awaiting-hardware
            } catch (Exception ignored) {
            }
            try {
                canonWriteEosProp(CANON_EVF_OUTPUT_DEVICE, 2); // TBC-awaiting-hardware
            } catch (Exception ignored) {
            }
            liveView = true;
        }
        // TBC-awaiting-hardware：EOS 相机开始/停止录像均写 EVFRecordStatus。
        canonWriteEosProp(CANON_EVF_RECORD_STATUS, 1);
        movieRecording = true;
    }

    private void canonStopMovieRecording() throws Exception {
        // TBC-awaiting-hardware：0=停止录像。
        canonWriteEosProp(CANON_EVF_RECORD_STATUS, 0);
    }

    synchronized boolean isMovieRecording() {
        return movieRecording;
    }

    synchronized boolean isLiveView() {
        return liveView;
    }

    synchronized boolean isConnected() {
        return connection != null;
    }

    synchronized CameraStorage.Snapshot listStorage() throws Exception {
        ensureConnected();
        boolean resumeLiveView = liveView;
        if (resumeLiveView) stopLiveView();
        try {
            java.util.List<CameraStorage.Volume> volumes = new java.util.ArrayList<>();
            java.util.List<CameraStorage.Item> items = new java.util.ArrayList<>();
            byte[] storageIds = transact(GET_STORAGE_IDS, null, null, 15_000);
            for (long storageId : CameraStorage.parseStorageIds(storageIds)) {
                byte[] storageInfo = transact(
                        GET_STORAGE_INFO,
                        new long[]{storageId},
                        null,
                        15_000);
                volumes.add(CameraStorage.parseStorageInfo(storageId, storageInfo));
                appendStorageItems(storageId, items);
            }
            items.sort((left, right) -> {
                int byDate = right.capturedAt.compareTo(left.capturedAt);
                return byDate != 0
                        ? byDate
                        : right.filename.compareToIgnoreCase(left.filename);
            });
            diagnostics.info(
                    "camera-storage",
                    cameraName() + " 已读取 " + volumes.size() + " 个存储卷、"
                            + items.size() + " 个文件");
            return new CameraStorage.Snapshot(volumes, items);
        } finally {
            if (resumeLiveView && connection != null) {
                resumeLiveViewAfterExclusiveOperation();
            }
        }
    }

    private void appendStorageItems(
            long storageId,
            java.util.List<CameraStorage.Item> items) throws Exception {
        java.util.ArrayDeque<Long> pending = new java.util.ArrayDeque<>(
                CameraStorage.parseObjectHandles(transact(
                        GET_OBJECT_HANDLES,
                        new long[]{storageId, 0, 0xffff_ffffL},
                        null,
                        30_000)));
        java.util.Set<Long> visited = new java.util.HashSet<>();
        while (!pending.isEmpty()) {
            long handle = pending.removeFirst();
            if (!visited.add(handle)) continue;
            byte[] objectInfo = transact(
                    GET_OBJECT_INFO,
                    new long[]{handle},
                    null,
                    15_000);
            if (CameraStorage.isAssociation(objectInfo)) {
                for (long child : CameraStorage.parseObjectHandles(transact(
                        GET_OBJECT_HANDLES,
                        new long[]{storageId, 0, handle},
                        null,
                        30_000))) {
                    if (!visited.contains(child)) pending.addLast(child);
                }
                continue;
            }
            CameraStorage.Item item = CameraStorage.parseObjectInfo(handle, objectInfo);
            if (item != null) items.add(item);
        }
    }

    synchronized byte[] getStorageThumbnail(long handle) throws Exception {
        ensureConnected();
        return transact(GET_THUMB, new long[]{handle}, null, 30_000);
    }

    synchronized byte[] downloadStorageObject(long handle) throws Exception {
        ensureConnected();
        boolean resumeLiveView = liveView;
        if (resumeLiveView) stopLiveView();
        try {
            return transact(GET_OBJECT, new long[]{handle}, null, 180_000);
        } finally {
            if (resumeLiveView && connection != null) {
                resumeLiveViewAfterExclusiveOperation();
            }
        }
    }

    synchronized void deleteStorageObject(long handle) throws Exception {
        ensureConnected();
        boolean resumeLiveView = liveView;
        if (resumeLiveView) stopLiveView();
        try {
            transact(DELETE_OBJECT, new long[]{handle, 0}, null, 30_000);
            diagnostics.info(
                    "camera-storage",
                    cameraName() + " 已删除机内对象 " + Long.toUnsignedString(handle));
        } finally {
            if (resumeLiveView && connection != null) {
                resumeLiveViewAfterExclusiveOperation();
            }
        }
    }

    synchronized byte[] capture() throws Exception {
        ensureConnected();
        boolean resumeLiveView = liveView;
        boolean releaseRemoteMode = false;
        try {
            if (resumeLiveView) {
                stopLiveView();
                waitUntilDeviceReady(6_000);
            }
            waitUntilDeviceReady(6_000);
            if ("bulb".equals(exposureMode)) {
                transact(CHANGE_CAMERA_MODE, new long[]{1}, null, 10_000);
                releaseRemoteMode = true;
                transact(
                        SET_DEVICE_PROP,
                        new long[]{0x500e},
                        littleEndian16(1),
                        10_000);
                setShutterValue(false, 0xffffffffL);
                transact(CAPTURE_TO_SDRAM, new long[]{0xffffffffL, 1}, null, 60_000);
                Thread.sleep(Math.max(1, Math.min(bulbDurationSeconds, 900)) * 1000L);
                transact(TERMINATE_CAPTURE, new long[]{0, 0}, null, 15_000);
            } else {
                transact(CAPTURE_TO_SDRAM, new long[]{0xffffffffL, 1}, null, 60_000);
            }
            long handle = 0;
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
            if (handle == 0) {
                waitUntilDeviceReady(8_000);
                handle = 0xffff0001L;
            }
            byte[] objectData = null;
            Exception objectError = null;
            for (int attempt = 0; attempt < 4; attempt++) {
                try {
                    objectData = transact(
                            GET_OBJECT,
                            new long[]{handle},
                            null,
                            60_000);
                    break;
                } catch (Exception error) {
                    objectError = error;
                    String message = error.getMessage();
                    if (message == null || !message.contains("0x2009")) {
                        throw error;
                    }
                    diagnostics.warning(
                            "capture",
                            cameraName()
                                    + " 读取照片时相机忙，第 "
                                    + (attempt + 1)
                                    + " 次重试："
                                    + message);
                    waitUntilDeviceReady(3_000);
                }
            }
            if (objectData == null && objectError != null) {
                throw objectError;
            }
            byte[] jpeg = extractJpeg(objectData);
            waitUntilDeviceReady(8_000);
            return jpeg;
        } finally {
            if (releaseRemoteMode && connection != null) {
                try {
                    waitUntilDeviceReady(8_000);
                } catch (Exception error) {
                    diagnostics.warning(
                            "capture",
                            "B 门拍摄后等待相机就绪失败，将直接尝试释放控制："
                                    + error.getMessage());
                }
                try {
                    transact(CHANGE_CAMERA_MODE, new long[]{0}, null, 10_000);
                    diagnostics.info("capture", "B 门拍摄结束，已释放机身快门控制");
                } catch (Exception error) {
                    diagnostics.warning(
                            "capture",
                            "B 门拍摄后释放机身控制失败：" + error.getMessage());
                }
            }
            if (resumeLiveView) {
                resumeLiveViewAfterExclusiveOperation();
            }
        }
    }

    synchronized Object setParameter(String name, Object rawValue) throws Exception {
        if (!isParameterWritable(name)) {
            throw new Exception(parameterLockReason(name));
        }
        // Nikon exposes the live-view AF property while viewfinder streaming is
        // active. Do not tear down/restart the stream just to switch AF mode;
        // doing so races the next preview request and can leave MANUAL_FOCUS_DRIVE
        // rejected as an in-progress I/O operation.
        boolean preserveLiveViewForFocus = "focusMode".equals(name) && liveView;
        boolean resumeLiveView = liveView && !preserveLiveViewForFocus;
        if (resumeLiveView) stopLiveView();
        try {
            Exception lastError = null;
            int maxRetries = 5;
            for (int attempt = 0; attempt < maxRetries; attempt++) {
                try {
                    return setParameterCore(name, rawValue);
                } catch (Exception error) {
                    lastError = error;
                    boolean focusTransient = "focusMode".equals(name)
                            && isTransientFocusError(error);
                    if ((!isTransientPtpError(error) && !focusTransient)
                            || attempt >= maxRetries - 1) {
                        if (focusTransient) throw enhanceFocusError(error);
                        throw enhanceTransientError(error, name);
                    }
                    diagnostics.warning(
                            "camera",
                            cameraName() + " PTP 瞬时繁忙，第 "
                                    + (attempt + 1) + " 次重试 "
                                    + parameterDisplayName(name)
                                    + "：" + error.getMessage());
                    try {
                        Thread.sleep(200L * (attempt + 1));
                    } catch (InterruptedException ignored) {
                        Thread.currentThread().interrupt();
                        throw lastError;
                    }
                }
            }
            throw lastError != null ? lastError
                    : new Exception(cameraName() + " 参数写入失败。");
        } finally {
            if (resumeLiveView) {
                resumeLiveViewAfterExclusiveOperation();
            }
        }
    }

    synchronized void moveFocus(int signedStep) throws Exception {
        ensureConnected();
        if (!liveView) {
            throw new Exception("焦点步进仅能在实时取景开启时使用。");
        }
        int normalized = Math.max(-3, Math.min(3, signedStep));
        if (normalized == 0) return;
        long direction = normalized < 0 ? 0x1 : 0x2;
        long amount = Math.abs(normalized) == 1
                ? 128
                : Math.abs(normalized) == 2 ? 512 : 1024;
        Exception lastError = null;
        for (int attempt = 0; attempt < 3; attempt++) {
            try {
                transact(
                        MANUAL_FOCUS_DRIVE,
                        new long[]{direction, amount},
                        null,
                        10_000);
            } catch (Exception error) {
                lastError = error;
                if (!isTransientFocusError(error) || attempt >= 2) {
                    throw enhanceFocusError(error);
                }
                try {
                    Thread.sleep(180L * (attempt + 1));
                } catch (InterruptedException interrupted) {
                    Thread.currentThread().interrupt();
                    throw error;
                }
                continue;
            }
            try {
                waitUntilDeviceReady(4_000);
                return;
            } catch (Exception readyError) {
                // The drive response means the lens already moved. Retry
                // readiness only so a slow body does not get two focus moves.
                if (!isTransientFocusError(readyError)) throw readyError;
                try {
                    waitUntilDeviceReady(4_000);
                    return;
                } catch (Exception finalReadyError) {
                    throw enhanceFocusError(finalReadyError);
                }
            }
        }
        throw lastError != null ? lastError : new Exception(cameraName() + " 对焦请求失败。");
    }

    synchronized void triggerAutoFocus() throws Exception {
        ensureConnected();
        if (!liveView) {
            throw new Exception("AF-ON 仅能在实时取景开启时使用。");
        }
        setParameter("focusMode", "single-shot");
        Exception lastError = null;
        for (int attempt = 0; attempt < 3; attempt++) {
            try {
                transact(AUTO_FOCUS_DRIVE, null, null, 10_000);
                waitUntilDeviceReady(4_000);
                return;
            } catch (Exception error) {
                lastError = error;
                if (!isTransientFocusError(error) || attempt >= 2) {
                    throw enhanceFocusError(error);
                }
                try {
                    Thread.sleep(180L * (attempt + 1));
                } catch (InterruptedException interrupted) {
                    Thread.currentThread().interrupt();
                    throw error;
                }
            }
        }
        throw lastError != null ? lastError : new Exception("AF-ON 请求失败。");
    }

    private Object setParameterCore(String name, Object rawValue) throws Exception {
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
            int liveViewFocusMode = "manual".equals(mode)
                    ? 4
                    : "continuous".equals(mode) ? 1 : 0;
            if (liveView) {
                try {
                    transact(
                            SET_DEVICE_PROP,
                            new long[]{0xd061},
                            new byte[]{(byte) liveViewFocusMode},
                            10_000);
                } catch (Exception liveViewFocusError) {
                    transact(
                            SET_DEVICE_PROP,
                            new long[]{0x500a},
                            littleEndian16(stillFocusMode),
                            10_000);
                }
            } else {
                try {
                    transact(
                            SET_DEVICE_PROP,
                            new long[]{0x500a},
                            littleEndian16(stillFocusMode),
                            10_000);
                } catch (Exception stillFocusError) {
                    transact(
                            SET_DEVICE_PROP,
                            new long[]{0xd061},
                            new byte[]{(byte) liveViewFocusMode},
                            10_000);
                }
            }
            return rawValue;
        }
        if ("videoCodec".equals(name)) {
            setVideoCodec(String.valueOf(rawValue));
            return rawValue;
        }
        if ("videoLog".equals(name)) {
            setVideoLog(String.valueOf(rawValue));
            return rawValue;
        }
        if ("nLog".equals(name)) {
            setVideoLog(Boolean.parseBoolean(String.valueOf(rawValue)) ? "nlog" : "off");
            return rawValue;
        }
        int property;
        byte[] value;
        double number = rawValue instanceof Number ? ((Number) rawValue).doubleValue() : 0;
        switch (name) {
            case "exposureTime":
            case "videoExposureTime":
                setShutterSeconds(
                        number,
                        "videoExposureTime".equals(name));
                return rawValue;
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
                String requestedExposureMode = String.valueOf(rawValue);
                property = 0x500e;
                if ("bulb".equals(requestedExposureMode)) {
                    // Bulb is an app capture state. Do not enter Nikon remote
                    // mode until the shutter is actually triggered, otherwise
                    // the physical shutter button remains unavailable.
                    exposureMode = requestedExposureMode;
                    return rawValue;
                }
                int program;
                if ("manual".equals(requestedExposureMode)) program = 1;
                else if ("aperturePriority".equals(requestedExposureMode)) program = 3;
                else if ("shutterPriority".equals(requestedExposureMode)) program = 4;
                else program = 2;
                value = littleEndian16(program);
                break;
            default:
                throw new Exception(cameraName() + " 不支持此参数：" + name);
        }
        transact(SET_DEVICE_PROP, new long[]{property}, value, 10_000);
        if ("exposureMode".equals(name)) {
            exposureMode = String.valueOf(rawValue);
            refreshParameterCapabilities();
        }
        return rawValue;
    }

    private void setVideoCodec(String codec) throws Exception {
        if (profile == null) throw new Exception("请先连接支持的相机。");
        if (profile.vendorId == 0x054c) {
            int rawValue;
            if ("sonyXavcHs8k".equals(codec)) rawValue = 10;
            else if ("sonyXavcHs4k".equals(codec)) rawValue = 11;
            else if ("sonyXavcS4k".equals(codec)) rawValue = 8;
            else if ("sonyXavcSHd".equals(codec)) rawValue = 9;
            else if ("sonyXavcSi4k".equals(codec)) rawValue = 14;
            else if ("sonyXavcSiHd".equals(codec)) rawValue = 15;
            else throw new Exception("Sony 不支持所选视频录制规格。");
            transact(
                    SET_DEVICE_PROP,
                    new long[]{SONY_MOVIE_FILE_FORMAT},
                    new byte[]{(byte) rawValue},
                    10_000);
            return;
        }
        if (profile.vendorId == 0x04a9) {
            throw new Exception(
                    profile.name
                            + " 未报告可写的佳能录制格式属性；规格已展示，请在机身中选择 RAW、XF-HEVC S 或 XF-AVC S。");
        }
        if (profile.vendorId != 0x04b0) {
            throw new Exception("当前相机不支持远程切换视频录制规格。");
        }
        if (("nraw".equals(codec) || "proresRaw".equals(codec)
                || "prores422hq".equals(codec))
                && !supportsAdvancedNikonVideo(profile.name)) {
            throw new Exception(profile.name + " 不支持所选 RAW/ProRes 视频编码。");
        }
        String normalized = codec.toLowerCase(Locale.ROOT);
        int rawValue;
        if ("h265".equals(normalized)) rawValue = NIKON_H265_10_BIT;
        else if ("prores422hq".equals(normalized)) rawValue = NIKON_PRORES_422_10_BIT;
        else if ("proresraw".equals(normalized)) rawValue = NIKON_PRORES_RAW_12_BIT;
        else if ("nraw".equals(normalized)) rawValue = NIKON_NRAW_12_BIT;
        else rawValue = NIKON_H264_8_BIT;
        transact(
                SET_DEVICE_PROP,
                new long[]{NIKON_MOVIE_FILE_TYPE},
                littleEndian32(rawValue),
                10_000);
    }

    private void setVideoLog(String logProfile) throws Exception {
        if (profile == null) throw new Exception("请先连接支持的相机。");
        if (profile.vendorId == 0x054c) {
            int pictureProfile;
            if ("off".equals(logProfile)) pictureProfile = 0;
            else if ("sonySLog2".equals(logProfile)) pictureProfile = 7;
            else if ("sonySLog3Cine".equals(logProfile)) pictureProfile = 8;
            else if ("sonySLog3".equals(logProfile)) pictureProfile = 9;
            else if ("sonyHlg".equals(logProfile)) pictureProfile = 10;
            else throw new Exception("Sony 不支持所选 Log / Picture Profile。");
            transact(
                    SET_DEVICE_PROP,
                    new long[]{SONY_PICTURE_PROFILE},
                    new byte[]{(byte) pictureProfile},
                    10_000);
            return;
        }
        if (profile.vendorId == 0x04a9) {
            int value;
            if ("off".equals(logProfile)) value = 0;
            else if ("canonLog".equals(logProfile)) value = 1;
            else if ("canonLog2".equals(logProfile)) value = 2;
            else if ("canonLog3".equals(logProfile)) value = 3;
            else throw new Exception("Canon 不支持所选 Canon Log 曲线。");
            byte[] payload = new byte[12];
            ByteBuffer buffer = ByteBuffer.wrap(payload).order(ByteOrder.LITTLE_ENDIAN);
            buffer.putInt(12);
            buffer.putInt(CANON_LOG_GAMMA);
            buffer.putInt(value);
            transact(CANON_EOS_SET_DEVICE_PROP_VALUE_EX, null, payload, 10_000);
            return;
        }
        if (profile.vendorId != 0x04b0) {
            throw new Exception("当前相机不支持远程切换 Log 曲线。");
        }
        boolean enabled = !"off".equals(logProfile);
        if (enabled && !"nlog".equals(logProfile)) {
            throw new Exception("Nikon 机身仅支持 N-Log。");
        }
        byte[] fileTypeData = transact(
                GET_DEVICE_PROP_VALUE,
                new long[]{NIKON_MOVIE_FILE_TYPE},
                null,
                10_000);
        if (fileTypeData.length < 4) {
            throw new Exception("相机未返回有效的视频编码值。");
        }
        int fileType = ByteBuffer.wrap(fileTypeData)
                .order(ByteOrder.LITTLE_ENDIAN)
                .getInt();
        int toneProperty = nikonToneProperty(fileType, enabled);
        if (toneProperty == 0) return;
        transact(
                SET_DEVICE_PROP,
                new long[]{toneProperty},
                new byte[]{(byte) (enabled ? 1 : 0)},
                10_000);
    }

    private static int nikonToneProperty(int fileType, boolean enabled) throws Exception {
        if (fileType == NIKON_H265_10_BIT) return NIKON_MOVIE_H265_TONE_MODE;
        if (fileType == NIKON_NRAW_12_BIT) return NIKON_MOVIE_NRAW_TONE_MODE;
        if (fileType == NIKON_PRORES_422_10_BIT) return NIKON_MOVIE_PRORES_TONE_MODE;
        if (fileType == NIKON_PRORES_RAW_12_BIT) return NIKON_MOVIE_PRORES_RAW_TONE_MODE;
        if (!enabled) return 0;
        throw new Exception(
                "当前编码不支持 N-Log；请选择 H.265 10-bit、N-RAW、ProRes 422 HQ 或 ProRes RAW。");
    }

    private static boolean supportsAdvancedNikonVideo(String name) {
        return name.contains("Z9")
                || name.contains("Z8")
                || name.contains("Z6III")
                || name.contains("ZR");
    }

    private void setShutterSeconds(double seconds, boolean video) throws Exception {
        if (!Double.isFinite(seconds) || seconds <= 0) {
            throw new Exception("快门速度必须大于 0 秒。");
        }
        Exception finalError = null;
        for (int property : shutterProperties(video)) {
            byte[] encoded = property == EXPOSURE_TIME
                    ? littleEndian32(Math.round(seconds * 10_000))
                    : nikonShutterValue(seconds);
            try {
                transact(
                        SET_DEVICE_PROP,
                        new long[]{property},
                        encoded,
                        10_000);
                diagnostics.info(
                        "camera",
                        String.format(
                                Locale.US,
                                "快门属性写入成功；property=0x%04X；video=%s",
                                property,
                                video));
                return;
            } catch (Exception error) {
                if (!isPropertyCompatibilityError(error)) throw error;
                finalError = error;
            }
        }
        throw new Exception(
                cameraName()
                        + " 当前没有可写的"
                        + (video ? "视频" : "照片")
                        + "快门属性。请确认相机处于 M/S 模式，且未在机身菜单中锁定曝光参数。",
                finalError);
    }

    private void setShutterValue(boolean video, long rawValue) throws Exception {
        Exception finalError = null;
        for (int property : shutterProperties(video)) {
            try {
                transact(
                        SET_DEVICE_PROP,
                        new long[]{property},
                        littleEndian32(rawValue),
                        10_000);
                return;
            } catch (Exception error) {
                if (!isPropertyCompatibilityError(error)) throw error;
                finalError = error;
            }
        }
        throw new Exception(
                cameraName() + " 当前不支持通过 USB/PTP 设置 B 门快门。",
                finalError);
    }

    private int[] shutterProperties(boolean video) {
        return video
                ? new int[]{
                        NIKON_MOVIE_EXPOSURE_TIME,
                        EXPOSURE_TIME,
                        NIKON_EXPOSURE_TIME
                }
                : new int[]{NIKON_EXPOSURE_TIME, EXPOSURE_TIME};
    }

    private boolean hasWritableShutterProperty(boolean video) {
        boolean hasUnknownProperty = false;
        for (int property : shutterProperties(video)) {
            Boolean writable = writableProperties.get(property);
            if (Boolean.TRUE.equals(writable)) return true;
            if (writable == null) hasUnknownProperty = true;
        }
        return hasUnknownProperty;
    }

    private byte[] nikonShutterValue(double seconds) {
        long numerator;
        long denominator;
        if (seconds < 1) {
            numerator = 1;
            denominator = Math.max(1, Math.round(1 / seconds));
        } else if (Math.abs(seconds - Math.rint(seconds)) < 0.000001) {
            numerator = Math.round(seconds);
            denominator = 1;
        } else {
            denominator = 1_000;
            numerator = Math.round(seconds * denominator);
            long divisor = greatestCommonDivisor(numerator, denominator);
            numerator /= divisor;
            denominator /= divisor;
        }
        numerator = Math.max(1, Math.min(0xffff, numerator));
        denominator = Math.max(1, Math.min(0xffff, denominator));
        return littleEndian32((numerator << 16) | denominator);
    }

    private long greatestCommonDivisor(long left, long right) {
        while (right != 0) {
            long remainder = left % right;
            left = right;
            right = remainder;
        }
        return Math.max(1, left);
    }

    private boolean isPropertyCompatibilityError(Exception error) {
        String message = error.getMessage();
        if (message == null) return false;
        return message.contains("0x2005")
                || message.contains("0x200A")
                || message.contains("0x200F")
                || message.contains("0x201C")
                || message.contains("0x201D");
    }

    private boolean isTransientPtpError(Exception error) {
        String message = error.getMessage();
        if (message == null) return false;
        return message.contains("0x200F") || message.contains("0x201C");
    }

    private boolean isTransientFocusError(Exception error) {
        String message = error.getMessage();
        if (message == null) return false;
        String normalized = message.toLowerCase(Locale.US);
        return message.contains("0x2019")
                || normalized.contains("busy")
                || normalized.contains("in progress")
                || normalized.contains("i/o")
                || normalized.contains("timeout")
                || normalized.contains("error code=-110")
                || normalized.contains("错误码=-110")
                || normalized.contains("-110")
                || normalized.contains("超时")
                || normalized.contains("传输失败");
    }

    private Exception enhanceFocusError(Exception error) {
        if (!isTransientFocusError(error)) return error;
        return new Exception(
                cameraName()
                        + " 当前正在传输实时取景画面，暂时无法执行焦点步进。"
                        + "请稍候片刻后重试。",
                error);
    }

    private Exception enhanceTransientError(Exception error, String name) {
        String message = error.getMessage();
        if (message == null) return error;
        if (message.contains("0x200F") || message.contains("0x201C")) {
            diagnostics.warning(
                    "camera",
                    cameraName()
                            + " 当前状态暂时拒绝写入"
                            + parameterDisplayName(name)
                            + "；控件保持可用，允许切换机身模式后重试");
            return new Exception(
                    cameraName()
                            + " 当前状态暂时拒绝写入“"
                            + parameterDisplayName(name)
                            + "”。请确认机身处于允许调整的曝光模式后重试。",
                    error);
        }
        return error;
    }

    private void waitUntilDeviceReady(long timeoutMillis) throws Exception {
        Exception finalError = null;
        long deadline = System.currentTimeMillis() + timeoutMillis;
        do {
            try {
                transact(DEVICE_READY, null, null, 3_000);
                return;
            } catch (Exception error) {
                finalError = error;
                Thread.sleep(180);
            }
        } while (System.currentTimeMillis() < deadline);
        throw new Exception(
                cameraName() + " 在独占操作后未恢复就绪状态。",
                finalError);
    }

    private void resumeLiveViewAfterExclusiveOperation() {
        Exception finalError = null;
        for (int attempt = 1; attempt <= 3 && connection != null; attempt++) {
            try {
                waitUntilDeviceReady(4_000);
                startLiveView();
                return;
            } catch (Exception error) {
                finalError = error;
                liveView = false;
                try {
                    Thread.sleep(250L * attempt);
                } catch (InterruptedException interrupted) {
                    Thread.currentThread().interrupt();
                    break;
                }
            }
        }
        diagnostics.warning(
                "liveview",
                "独占相机操作后未能恢复实时取景："
                        + (finalError == null ? "未知错误" : finalError.getMessage()));
    }

    synchronized boolean isParameterWritable(String name) {
        if ("videoCodec".equals(name)
                && profile != null
                && profile.vendorId == 0x04a9) {
            return false;
        }
        if (deniedParameters.contains(name) || !canAdjustExposureParameter(name)) {
            return false;
        }
        return true;
    }

    synchronized String parameterLockReason(String name) {
        if ("videoCodec".equals(name)
                && profile != null
                && profile.vendorId == 0x04a9) {
            return "该 Canon 机身未报告通用可写的录制格式属性，请在机身菜单中选择规格";
        }
        if (deniedParameters.contains(name)) {
            return parameterDisplayName(name) + "已被相机拒绝，重新连接后再检测";
        }
        if (!canAdjustExposureParameter(name)) {
            return "当前拍摄模式下由相机控制";
        }
        return null;
    }

    private boolean canAdjustExposureParameter(String name) {
        switch (name) {
            case "exposureTime":
            case "videoExposureTime":
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
            case "bulbDuration":
                return "bulb".equals(exposureMode);
            default:
                return true;
        }
    }

    private void refreshParameterCapabilities() {
        writableProperties.clear();
        deniedParameters.clear();
        int[] properties = new int[]{
                0x5005, 0x5007, 0x500a, EXPOSURE_TIME, 0x500e, 0x500f,
                0x5010, NIKON_EXPOSURE_TIME, NIKON_MOVIE_EXPOSURE_TIME, 0xd200,
                NIKON_MOVIE_FILE_TYPE, NIKON_MOVIE_PRORES_TONE_MODE,
                NIKON_MOVIE_H265_TONE_MODE, NIKON_MOVIE_NRAW_TONE_MODE,
                NIKON_MOVIE_PRORES_RAW_TONE_MODE, SONY_MOVIE_FILE_FORMAT,
                SONY_PICTURE_PROFILE
        };
        for (int property : properties) {
            try {
                byte[] descriptor = transact(
                        GET_DEVICE_PROP_DESC,
                        new long[]{property},
                        null,
                        5_000);
                if (descriptor.length >= 5) {
                    writableProperties.put(property, descriptor[4] != 0);
                }
            } catch (Exception ignored) {
                // Older Nikon bodies do not expose every descriptor. In that
                // case mode-based gating remains the safe fallback.
            }
        }
        diagnostics.info(
                "camera",
                "已读取 PTP 参数描述符；可写标志仅用于诊断，"
                        + "实际写入会在暂停实时取景后重新尝试");
    }

    private int propertyCode(String name) {
        switch (name) {
            case "whiteBalanceMode": return 0x5005;
            case "aperture": return 0x5007;
            case "focusMode": return 0x500a;
            case "exposureTime": return EXPOSURE_TIME;
            case "videoExposureTime": return NIKON_MOVIE_EXPOSURE_TIME;
            case "exposureMode": return 0x500e;
            case "iso": return 0x500f;
            case "exposureCompensation": return 0x5010;
            case "pictureControl": return 0xd200;
            case "videoCodec":
                return profile != null && profile.vendorId == 0x054c
                        ? SONY_MOVIE_FILE_FORMAT
                        : NIKON_MOVIE_FILE_TYPE;
            case "videoLog":
            case "nLog":
                if (profile != null && profile.vendorId == 0x054c) {
                    return SONY_PICTURE_PROFILE;
                }
                if (profile != null && profile.vendorId == 0x04a9) {
                    return CANON_LOG_GAMMA;
                }
                return NIKON_MOVIE_H265_TONE_MODE;
            default: return -1;
        }
    }

    private String parameterDisplayName(String name) {
        switch (name) {
            case "exposureTime":
            case "videoExposureTime": return "快门速度";
            case "aperture": return "光圈";
            case "iso": return "ISO";
            case "exposureCompensation": return "曝光补偿";
            case "focusMode": return "对焦模式";
            case "whiteBalanceMode": return "白平衡";
            case "pictureControl": return "优化校准";
            case "exposureMode": return "拍摄模式";
            case "videoCodec": return "视频录制规格";
            case "videoLog": return "Log / Picture Profile";
            case "nLog": return "N-Log";
            default: return "参数";
        }
    }

    synchronized void disconnect() {
        if (movieRecording && connection != null) {
            try {
                stopMovieRecording();
            } catch (Exception ignored) {
                movieRecording = false;
            }
        }
        stopLiveView();
        if (connection != null) {
            try {
                transact(CLOSE_SESSION, null, null, 2_000);
            } catch (Exception ignored) {
            }
        }
        closeTransport();
        movieRecording = false;
        writableProperties.clear();
        deniedParameters.clear();
    }

    private void openSessionWithRecovery() throws Exception {
        Exception lastError = null;
        for (int attempt = 1; attempt <= CONNECT_ATTEMPTS; attempt++) {
            transaction = 0;
            try {
                if (attempt == 1) {
                    resetPtpDevice();
                    Thread.sleep(150);
                }
                diagnostics.info(
                        "usb",
                        "正在初始化 " + cameraName()
                                + " PTP 会话；第 " + attempt
                                + "/" + CONNECT_ATTEMPTS + " 次");
                transact(OPEN_SESSION, new long[]{1}, null, 10_000);
                diagnostics.info("usb", cameraName() + " PTP 会话初始化成功");
                return;
            } catch (Exception error) {
                lastError = error;
                diagnostics.warning(
                        "usb",
                        cameraName() + " PTP 会话初始化失败；第 "
                                + attempt + " 次；" + error.getMessage());
                if (attempt == CONNECT_ATTEMPTS) break;
                recoverUsbTransport(attempt);
            }
        }
        throw new Exception(
                cameraName()
                        + " USB/PTP 会话初始化失败（已重试 "
                        + CONNECT_ATTEMPTS
                        + " 次）："
                        + (lastError == null ? "未知错误" : lastError.getMessage()),
                lastError);
    }

    private void closeTransport() {
        closeConnectionOnly();
        usbManager = null;
        connectedProductId = -1;
        cameraInterface = null;
        bulkIn = null;
        bulkOut = null;
        profile = null;
    }

    private void closeConnectionOnly() {
        syncTransport = false;
        if (connection != null) {
            if (cameraInterface != null) {
                try {
                    connection.releaseInterface(cameraInterface);
                } catch (RuntimeException ignored) {
                }
            }
            try {
                connection.close();
            } catch (RuntimeException ignored) {
            }
        }
        connection = null;
        cameraInterface = null;
        bulkIn = null;
        bulkOut = null;
    }

    private void openFreshTransport(UsbDevice device) throws Exception {
        closeConnectionOnly();
        syncTransport = false;
        if (usbManager == null
                || (!usbManager.hasPermission(device)
                && !activity.ensureUsbPermission(usbManager, device))) {
            throw new Exception("未获得 " + cameraName() + " 的 USB 访问权限。");
        }
        UsbInterface selectedInterface = null;
        UsbEndpoint selectedInput = null;
        UsbEndpoint selectedOutput = null;
        for (int index = 0; index < device.getInterfaceCount(); index++) {
            UsbInterface candidate = device.getInterface(index);
            if (candidate.getInterfaceClass() != UsbConstants.USB_CLASS_STILL_IMAGE) {
                continue;
            }
            UsbEndpoint input = null;
            UsbEndpoint output = null;
            for (int endpointIndex = 0;
                 endpointIndex < candidate.getEndpointCount();
                 endpointIndex++) {
                UsbEndpoint endpoint = candidate.getEndpoint(endpointIndex);
                if (endpoint.getType() != UsbConstants.USB_ENDPOINT_XFER_BULK) {
                    continue;
                }
                if (endpoint.getDirection() == UsbConstants.USB_DIR_IN) {
                    input = endpoint;
                } else if (endpoint.getDirection() == UsbConstants.USB_DIR_OUT) {
                    output = endpoint;
                }
            }
            if (input != null && output != null) {
                selectedInterface = candidate;
                selectedInput = input;
                selectedOutput = output;
                break;
            }
        }
        if (selectedInterface == null) {
            throw new Exception(cameraName() + " 没有提供可用的 PTP USB 接口。");
        }

        UsbDeviceConnection opened = usbManager == null
                ? null
                : usbManager.openDevice(device);
        if (opened == null || !opened.claimInterface(selectedInterface, true)) {
            if (opened != null) opened.close();
            throw new Exception(
                    "无法打开 " + cameraName()
                            + "。请关闭 NX MobileAir 等占用相机的应用。");
        }
        if (selectedInterface.getAlternateSetting() != 0
                && !opened.setInterface(selectedInterface)) {
            opened.releaseInterface(selectedInterface);
            opened.close();
            throw new Exception(cameraName() + " 无法切换到 PTP USB 接口。");
        }

        connection = opened;
        cameraInterface = selectedInterface;
        bulkIn = selectedInput;
        bulkOut = selectedOutput;
        clearEndpointHalt(bulkIn);
        clearEndpointHalt(bulkOut);
        diagnostics.info(
                "usb",
                String.format(
                        Locale.US,
                        "PTP 传输已打开；interface=%d alt=%d"
                                + "；bulkIn=0x%02X/%d"
                                + "；bulkOut=0x%02X/%d"
                                + "；transport=UsbRequest/%d",
                        cameraInterface.getId(),
                        cameraInterface.getAlternateSetting(),
                        bulkIn.getAddress(),
                        bulkIn.getMaxPacketSize(),
                        bulkOut.getAddress(),
                        bulkOut.getMaxPacketSize(),
                        USB_BULK_CHUNK_BYTES));
    }

    private void recoverUsbTransport(int failedAttempt) throws Exception {
        boolean reset = resetPtpDevice();
        diagnostics.info(
                "usb",
                "正在重建 USB 传输；设备复位="
                        + (reset ? "成功" : "未确认")
                        + "；失败轮次=" + failedAttempt);
        closeConnectionOnly();
        Thread.sleep(350L * failedAttempt);

        UsbDevice device = waitForCurrentCamera(3_000);
        if (device == null) {
            throw new Exception(
                    cameraName() + " 在 USB 恢复期间断开，请重新连接数据线。");
        }
        Exception openError = null;
        long deadline = System.currentTimeMillis() + 3_000;
        do {
            try {
                openFreshTransport(device);
                openError = null;
                break;
            } catch (Exception error) {
                openError = error;
                Thread.sleep(200);
                UsbDevice refreshed = waitForCurrentCamera(400);
                if (refreshed != null) device = refreshed;
            }
        } while (System.currentTimeMillis() < deadline);
        if (openError != null) {
            throw new Exception(
                    cameraName() + " USB 传输重建失败：" + openError.getMessage(),
                    openError);
        }
        Thread.sleep(150);
    }

    private UsbDevice waitForCurrentCamera(long timeoutMillis)
            throws InterruptedException {
        if (usbManager == null) return null;
        long deadline = System.currentTimeMillis() + timeoutMillis;
        do {
            for (UsbDevice candidate : usbManager.getDeviceList().values()) {
                if (SUPPORTED_VENDOR_IDS.contains(candidate.getVendorId())
                        && candidate.getProductId() == connectedProductId) {
                    return candidate;
                }
            }
            Thread.sleep(100);
        } while (System.currentTimeMillis() < deadline);
        return null;
    }

    private byte[] transact(int operation, long[] params, byte[] outgoingData, int timeout) throws Exception {
        ensureConnectedForOperation(operation);
        // ISO 15740 requires OpenSession to use transaction ID 0. The first
        // operation inside the newly opened session then starts at ID 1.
        int current;
        if (operation == OPEN_SESSION) {
            transaction = 0;
            current = 0;
        } else {
            current = ++transaction;
        }
        sendContainer(TYPE_COMMAND, operation, current, parameterBytes(params), timeout);
        if (outgoingData != null) sendContainer(TYPE_DATA, operation, current, outgoingData, timeout);

        Container first = receiveContainer(timeout);
        byte[] data = new byte[0];
        Container response = first;
        if (first.type == TYPE_DATA) {
            data = first.payload;
            response = receiveContainer(timeout);
        }
        if (first.transaction != current || response.transaction != current) {
            throw new Exception(String.format(
                    "%s 返回了不匹配的 PTP 事务编号（期望 %d，收到 %d/%d）。",
                    cameraName(),
                    current,
                    first.transaction,
                    response.transaction));
        }
        if (response.type != TYPE_RESPONSE) {
            throw new Exception(cameraName() + " 返回了无效的 PTP 数据。");
        }
        if (response.code != RESPONSE_OK
                && !(operation == OPEN_SESSION
                && response.code == RESPONSE_SESSION_ALREADY_OPEN)) {
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
        boolean recovered = false;
        while (offset < bytes.length) {
            int requested = Math.min(
                    USB_BULK_CHUNK_BYTES,
                    bytes.length - offset);
            int sent;
            try {
                sent = transferWithUsbRequest(
                        bulkOut,
                        bytes,
                        offset,
                        requested,
                        timeout);
            } catch (Exception error) {
                if (!recovered && clearEndpointHalt(bulkOut)) {
                    recovered = true;
                    continue;
                }
                throw new Exception(
                        String.format(
                                Locale.US,
                                "向 %s 发送 USB 数据失败"
                                        + "（端点 0x%02X，UsbRequest）：%s",
                                cameraName(),
                                bulkOut.getAddress(),
                                error.getMessage()),
                        error);
            }
            if (sent <= 0) {
                if (!recovered && clearEndpointHalt(bulkOut)) {
                    recovered = true;
                    continue;
                }
                throw new Exception(
                        String.format(
                                Locale.US,
                                "向 %s 发送 USB 数据失败（端点 0x%02X，返回 %d）。",
                                cameraName(),
                                bulkOut.getAddress(),
                                sent));
            }
            offset += sent;
        }
    }

    private Container receiveContainer(int timeout) throws Exception {
        byte[] first = new byte[USB_BULK_CHUNK_BYTES];
        int received = 0;
        boolean recovered = false;
        while (received < 12) {
            int requested = first.length - received;
            int count;
            try {
                count = transferWithUsbRequest(
                        bulkIn,
                        first,
                        received,
                        requested,
                        timeout);
            } catch (Exception error) {
                if (!recovered && clearEndpointHalt(bulkIn)) {
                    recovered = true;
                    continue;
                }
                throw new Exception(
                        String.format(
                                Locale.US,
                                "读取 %s USB 数据失败"
                                        + "（端点 0x%02X，请求 %d 字节，UsbRequest）：%s",
                                cameraName(),
                                bulkIn.getAddress(),
                                requested,
                                error.getMessage()),
                        error);
            }
            if (count <= 0) {
                if (!recovered && clearEndpointHalt(bulkIn)) {
                    recovered = true;
                    continue;
                }
                throw new Exception(
                        String.format(
                                Locale.US,
                                "读取 %s USB 数据失败"
                                        + "（端点 0x%02X，请求 %d 字节，返回 %d）。",
                                cameraName(),
                                bulkIn.getAddress(),
                                requested,
                                count));
            }
            received += count;
        }
        ByteBuffer header = ByteBuffer.wrap(first, 0, received).order(ByteOrder.LITTLE_ENDIAN);
        int total = header.getInt();
        int type = header.getShort() & 0xffff;
        int code = header.getShort() & 0xffff;
        int returnedTransaction = header.getInt();
        if (total < 12 || total > 256 * 1024 * 1024) {
            throw new Exception(cameraName() + " 返回的数据长度无效。");
        }
        ByteArrayOutputStream all = new ByteArrayOutputStream(total);
        all.write(first, 0, Math.min(received, total));
        while (all.size() < total) {
            int remaining = total - all.size();
            byte[] chunk = new byte[Math.min(
                    USB_BULK_CHUNK_BYTES,
                    remaining)];
            int count;
            try {
                count = transferWithUsbRequest(
                        bulkIn,
                        chunk,
                        0,
                        chunk.length,
                        timeout);
            } catch (Exception error) {
                if (!recovered && clearEndpointHalt(bulkIn)) {
                    recovered = true;
                    continue;
                }
                throw new Exception(
                        String.format(
                                Locale.US,
                                "%s 图像传输中断"
                                        + "（端点 0x%02X，请求 %d 字节，UsbRequest）：%s",
                                cameraName(),
                                bulkIn.getAddress(),
                                chunk.length,
                                error.getMessage()),
                        error);
            }
            if (count <= 0) {
                if (!recovered && clearEndpointHalt(bulkIn)) {
                    recovered = true;
                    continue;
                }
                throw new Exception(
                        String.format(
                                Locale.US,
                                "%s 图像传输中断"
                                        + "（端点 0x%02X，请求 %d 字节，返回 %d）。",
                                cameraName(),
                                bulkIn.getAddress(),
                                chunk.length,
                                count));
            }
            all.write(chunk, 0, Math.min(count, remaining));
        }
        byte[] container = all.toByteArray();
        return new Container(
                type,
                code,
                returnedTransaction,
                Arrays.copyOfRange(container, 12, total));
    }

    private int transferWithUsbRequest(
            UsbEndpoint endpoint,
            byte[] bytes,
            int offset,
            int length,
            int timeout) throws Exception {
        UsbDeviceConnection activeConnection = connection;
        if (activeConnection == null || endpoint == null) {
            throw new Exception("USB 传输尚未打开。");
        }

        boolean input = endpoint.getDirection() == UsbConstants.USB_DIR_IN;
        if (syncTransport) {
            // This session already latched synchronous mode after a successful
            // UsbRequest→bulkTransfer fallback; skip the async probe entirely.
            // No halt-clear on this path: that would add a USB control
            // transfer on every request. A real stall is handled by the
            // existing error-recovery path.
            return transferViaBulkTransfer(
                    activeConnection, endpoint, bytes,
                    offset, length, timeout, input);
        }
        try {
            return transferViaUsbRequest(
                    activeConnection, endpoint, bytes,
                    offset, length, timeout, input);
        } catch (Exception asyncError) {
            if (!isAsyncDegradable(asyncError)) throw asyncError;
            diagnostics.warning(
                    "usb",
                    "UsbRequest 超时/未返回完成结果/无法初始化或提交异步请求，降级为同步 bulkTransfer；"
                            + "端点=0x"
                            + Integer.toHexString(endpoint.getAddress()));
            try {
                clearEndpointHalt(endpoint);
                int result = transferViaBulkTransfer(
                        activeConnection, endpoint, bytes,
                        offset, length, timeout, input);
                diagnostics.info(
                        "usb",
                        "bulkTransfer 降级成功；端点=0x"
                                + Integer.toHexString(endpoint.getAddress())
                                + "；传输=" + result + " 字节");
                // Sticky: a working synchronous fallback must not pay the
                // async timeout again on the next request in this session.
                syncTransport = true;
                return result;
            } catch (Exception syncError) {
                // The fallback itself failed: do NOT latch sticky mode so a
                // future attempt may still probe async or rebuild the session.
                throw asyncError;
            }
        }
    }

    /**
     * Whether an async UsbRequest failure is safe to retry as a synchronous
     * bulkTransfer. Only four known conditions qualify: the request timed out
     * (per-transfer async timeout, 10-12s), the completion was never returned
     * (#21's "未返回有效的完成结果" — the device dropped the completion), or
     * the async request could not be initialized / submitted (#40's "无法初始
     * 化异步 USB 请求" / "无法提交异步 USB 请求"). Any other async failure
     * (device error, parameter error, arbitrary message) must surface to the
     * caller unchanged instead of being swallowed into bulk mode.
     */
    private boolean isAsyncDegradable(Exception error) {
        if (error == null || error.getMessage() == null) return false;
        String message = error.getMessage();
        return message.contains("超时")
                || message.contains("未返回有效的完成结果")
                || message.contains("无法初始化异步 USB 请求")
                || message.contains("无法提交异步 USB 请求");
    }

    private int transferViaUsbRequest(
            UsbDeviceConnection activeConnection,
            UsbEndpoint endpoint,
            byte[] bytes,
            int offset,
            int length,
            int timeout,
            boolean input) throws Exception {
        ByteBuffer buffer = ByteBuffer.allocateDirect(length);
        if (!input) {
            buffer.put(bytes, offset, length);
            buffer.flip();
        }

        UsbRequest request = new UsbRequest();
        boolean queued = false;
        boolean completed = false;
        try {
            if (!request.initialize(activeConnection, endpoint)) {
                throw new Exception("无法初始化异步 USB 请求。");
            }
            if (!request.queue(buffer)) {
                throw new Exception("无法提交异步 USB 请求。");
            }
            queued = true;

            UsbRequest finished;
            try {
                finished = activeConnection.requestWait(timeout);
            } catch (TimeoutException error) {
                throw new Exception(
                        "等待异步 USB 请求 " + timeout + " 毫秒后超时。",
                        error);
            }
            if (finished != request) {
                throw new Exception("异步 USB 请求未返回有效的完成结果。");
            }
            completed = true;

            int transferred = buffer.position();
            if (input && transferred > 0) {
                buffer.flip();
                buffer.get(bytes, offset, transferred);
            }
            return transferred;
        } finally {
            if (queued && !completed) {
                try {
                    request.cancel();
                    UsbRequest cancelled = activeConnection.requestWait(750);
                    completed = cancelled == request;
                } catch (RuntimeException ignored) {
                } catch (TimeoutException ignored) {
                }
            }
            request.close();
        }
    }

    private int transferViaBulkTransfer(
            UsbDeviceConnection activeConnection,
            UsbEndpoint endpoint,
            byte[] bytes,
            int offset,
            int length,
            int timeout,
            boolean input) {
        if (input) {
            byte[] buffer = new byte[length];
            int transferred = activeConnection.bulkTransfer(
                    endpoint, buffer, length, timeout);
            if (transferred < 0) {
                throw new RuntimeException(
                        "同步 bulkTransfer 读取失败，错误码=" + transferred);
            }
            System.arraycopy(buffer, 0, bytes, offset, transferred);
            return transferred;
        } else {
            byte[] chunk = new byte[length];
            System.arraycopy(bytes, offset, chunk, 0, length);
            int transferred = activeConnection.bulkTransfer(
                    endpoint, chunk, length, timeout);
            if (transferred < 0) {
                throw new RuntimeException(
                        "同步 bulkTransfer 写入失败，错误码=" + transferred);
            }
            return transferred;
        }
    }
    private boolean clearEndpointHalt(UsbEndpoint endpoint) {
        if (connection == null || endpoint == null) return false;
        int requestType =
                UsbConstants.USB_DIR_OUT
                        | UsbConstants.USB_TYPE_STANDARD
                        | USB_RECIPIENT_ENDPOINT;
        return connection.controlTransfer(
                requestType,
                USB_REQUEST_CLEAR_FEATURE,
                USB_FEATURE_ENDPOINT_HALT,
                endpoint.getAddress(),
                null,
                0,
                1_000) >= 0;
    }

    private boolean resetPtpDevice() {
        if (connection == null || cameraInterface == null) return false;
        int requestType =
                UsbConstants.USB_DIR_OUT
                        | UsbConstants.USB_TYPE_CLASS
                        | USB_RECIPIENT_INTERFACE;
        return connection.controlTransfer(
                requestType,
                PTP_USB_REQUEST_RESET,
                0,
                cameraInterface.getId(),
                null,
                0,
                2_000) >= 0;
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
        if (connection == null) throw new Exception("请先连接支持的相机。");
    }

    private void ensureConnectedForOperation(int operation) throws Exception {
        if (operation != OPEN_SESSION) ensureConnected();
        else if (connection == null) throw new Exception("无法打开 USB 相机连接。");
    }

    synchronized String getConnectedCameraName() {
        return cameraName();
    }

    synchronized String getConnectedCameraVendor() {
        return profile == null ? "" : profile.vendorName;
    }

    synchronized String getConnectedDeviceId() {
        if (profile == null) return cameraName();
        return String.format(
                Locale.ROOT,
                "%04x:%04x:%s",
                profile.vendorId,
                connectedProductId,
                cameraName());
    }

    synchronized int getMinimumIso() {
        return profile == null ? 100 : profile.minIso;
    }

    synchronized int getMaximumIso() {
        return profile == null ? 64000 : profile.maxIso;
    }

    private String cameraName() {
        return profile == null ? "相机" : profile.name;
    }

    private static CameraProfile profileFor(int vendorId, int productId) {
        for (CameraProfile candidate : SUPPORTED_CAMERAS) {
            if (candidate.vendorId == vendorId
                    && candidate.productId != 0
                    && candidate.productId == productId) {
                return candidate;
            }
        }
        return null;
    }

    private static CameraProfile profileFor(UsbDevice device) {
        CameraProfile byProductId = profileFor(device.getVendorId(), device.getProductId());
        if (byProductId != null) return byProductId;
        String descriptor = device.getProductName();
        CameraProfile bestMatch = null;
        int bestMatchLength = 0;
        if (descriptor != null) {
            String normalized = descriptor
                    .toLowerCase(Locale.ROOT)
                    .replace("_", "")
                    .replace("-", "")
                    .replace(" ", "");
            String generationAlias = normalized
                    .replace("iii", "3")
                    .replace("ii", "2");
            for (CameraProfile candidate : SUPPORTED_CAMERAS) {
                String candidateName = candidate.name
                        .toLowerCase(Locale.ROOT)
                        .replace(candidate.vendorName.toLowerCase(Locale.ROOT), "")
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
        }
        if (bestMatch != null) return bestMatch;
        // Sony and Canon may expose model-specific Product IDs that are not
        // stable across firmware generations. Keep the fallback generic when
        // Android cannot expose a product descriptor, rather than guessing a
        // specific model.
        return vendorFallbackProfile(device.getVendorId());
    }

    private static CameraProfile vendorFallbackProfile(int vendorId) {
        if (vendorId == 0x054c) {
            return new CameraProfile(
                    "Sony " + "α USB/PTP", "Sony", vendorId, 0, 100, 102400);
        }
        if (vendorId == 0x04a9) {
            return new CameraProfile(
                    "Canon " + "EOS USB/PTP", "Canon", vendorId, 0, 100, 102400);
        }
        return null;
    }

    private static final class CameraProfile {
        final String name;
        final String vendorName;
        final int vendorId;
        final int productId;
        final int minIso;
        final int maxIso;

        CameraProfile(String name, String vendorName, int vendorId, int productId, int minIso, int maxIso) {
            this.name = name;
            this.vendorName = vendorName;
            this.vendorId = vendorId;
            this.productId = productId;
            this.minIso = minIso;
            this.maxIso = maxIso;
        }
    }

    private static final class Container {
        final int type;
        final int code;
        final int transaction;
        final byte[] payload;

        Container(int type, int code, int transaction, byte[] payload) {
            this.type = type;
            this.code = code;
            this.transaction = transaction;
            this.payload = payload;
        }
    }
}
