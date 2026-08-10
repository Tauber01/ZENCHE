package com.tauber.nikonlink;

import android.Manifest;
import android.content.Context;
import android.content.pm.PackageManager;
import android.graphics.ImageFormat;
import android.hardware.camera2.CameraAccessException;
import android.hardware.camera2.CameraCaptureSession;
import android.hardware.camera2.CameraCharacteristics;
import android.hardware.camera2.CameraDevice;
import android.hardware.camera2.CameraManager;
import android.hardware.camera2.CaptureRequest;
import android.hardware.camera2.TotalCaptureResult;
import android.hardware.camera2.params.StreamConfigurationMap;
import android.media.Image;
import android.media.ImageReader;
import android.os.Handler;
import android.os.HandlerThread;
import android.util.Size;
import android.view.Surface;

import java.nio.ByteBuffer;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.Semaphore;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicReference;

/**
 * Camera2-backed source for the phone/tablet camera. Frames are exposed as
 * JPEG bytes so the existing ZENCHE preview, monitor and storage pipeline can
 * consume them without introducing a second rendering stack.
 */
final class LocalCameraController implements AutoCloseable {
    private static final long OPEN_TIMEOUT_SECONDS = 10;
    private static final long SESSION_TIMEOUT_SECONDS = 6;

    private final Context context;
    private final CameraManager manager;
    private final Object stateLock = new Object();
    private final AtomicReference<byte[]> latestPreview = new AtomicReference<>();
    private final Semaphore previewAvailable = new Semaphore(0);

    private HandlerThread cameraThread;
    private Handler cameraHandler;
    private CameraDevice device;
    private CameraCaptureSession session;
    private ImageReader previewReader;
    private ImageReader captureReader;
    private CaptureRequest previewRequest;
    private CompletableFuture<byte[]> pendingCapture;
    private long pendingCaptureTimestampNanos = Long.MAX_VALUE;
    private String cameraName = "本机摄像头";
    private int preferredAfMode = CaptureRequest.CONTROL_AF_MODE_OFF;
    private boolean sharedReaderMode;
    private boolean liveView;

    private static final class StreamCandidate {
        final Size previewSize;
        final Size captureSize;
        final boolean sharedReader;

        StreamCandidate(Size previewSize, Size captureSize, boolean sharedReader) {
            this.previewSize = previewSize;
            this.captureSize = captureSize;
            this.sharedReader = sharedReader;
        }

        String key() {
            return previewSize.getWidth() + "x" + previewSize.getHeight()
                    + "/" + captureSize.getWidth() + "x" + captureSize.getHeight()
                    + "/" + sharedReader;
        }
    }

    private static final class OpenedCamera {
        final CountDownLatch opened = new CountDownLatch(1);
        final CountDownLatch closed = new CountDownLatch(1);
        final AtomicBoolean abandoned = new AtomicBoolean(false);
        final AtomicReference<Exception> lifecycleError = new AtomicReference<>();
        final AtomicReference<CountDownLatch> configuring = new AtomicReference<>();
        CameraDevice device;
    }

    private static final class ConfiguredCamera {
        final CameraCaptureSession session;
        final ImageReader previewReader;
        final ImageReader captureReader;
        final boolean sharedReader;

        ConfiguredCamera(
                CameraCaptureSession session,
                ImageReader previewReader,
                ImageReader captureReader,
                boolean sharedReader) {
            this.session = session;
            this.previewReader = previewReader;
            this.captureReader = captureReader;
            this.sharedReader = sharedReader;
        }
    }

    LocalCameraController(Context context) {
        this.context = context.getApplicationContext();
        manager = (CameraManager) context.getSystemService(Context.CAMERA_SERVICE);
    }

    boolean isConnected() {
        synchronized (stateLock) {
            return device != null && session != null;
        }
    }

    boolean isLiveView() {
        synchronized (stateLock) {
            return liveView;
        }
    }

    String getCameraName() {
        synchronized (stateLock) {
            return cameraName;
        }
    }

    void connect() throws Exception {
        if (context.checkSelfPermission(Manifest.permission.CAMERA)
                != PackageManager.PERMISSION_GRANTED) {
            throw new SecurityException("需要相机权限才能使用本机摄像头");
        }
        close();
        startThread();
        String cameraId = chooseCameraId();
        CameraCharacteristics characteristics = manager.getCameraCharacteristics(cameraId);
        StreamConfigurationMap map = characteristics.get(
                CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP);
        if (map == null) throw new CameraAccessException(
                CameraAccessException.CAMERA_ERROR,
                "本机摄像头未报告可用的 JPEG 输出规格");
        Size[] jpegSizes = map.getOutputSizes(ImageFormat.JPEG);
        if (jpegSizes == null || jpegSizes.length == 0) {
            throw new CameraAccessException(
                    CameraAccessException.CAMERA_ERROR,
                    "本机摄像头不支持 JPEG 输出");
        }
        ConfiguredCamera configuredCamera = null;
        Exception lastSessionError = null;
        for (StreamCandidate candidate : buildStreamCandidates(jpegSizes)) {
            OpenedCamera openedCamera = openCamera(cameraId);
            try {
                configuredCamera = configureSession(openedCamera, candidate);
                synchronized (stateLock) {
                    device = openedCamera.device;
                    session = configuredCamera.session;
                    previewReader = configuredCamera.previewReader;
                    captureReader = configuredCamera.captureReader;
                    sharedReaderMode = configuredCamera.sharedReader;
                }
                break;
            } catch (Exception error) {
                lastSessionError = error;
                closeAttempt(openedCamera);
            }
        }
        if (configuredCamera == null) {
            close();
            throw new IllegalStateException(
                    "无法创建本机摄像头采集会话",
                    lastSessionError);
        }
        Integer facing = characteristics.get(CameraCharacteristics.LENS_FACING);
        int[] afModes = characteristics.get(
                CameraCharacteristics.CONTROL_AF_AVAILABLE_MODES);
        if (afModes != null) {
            for (int mode : afModes) {
                if (mode == CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE) {
                    preferredAfMode = mode;
                    break;
                }
            }
        }
        String facingLabel = facing != null
                && facing == CameraCharacteristics.LENS_FACING_FRONT
                ? "前置摄像头"
                : "后置摄像头";
        synchronized (stateLock) {
            cameraName = "本机" + facingLabel;
        }
    }

    void startLiveView() throws CameraAccessException {
        CameraDevice activeDevice;
        CameraCaptureSession activeSession;
        ImageReader activeReader;
        synchronized (stateLock) {
            activeDevice = device;
            activeSession = session;
            activeReader = previewReader;
        }
        if (activeDevice == null || activeSession == null || activeReader == null) {
            throw new IllegalStateException("请先连接本机摄像头");
        }
        CaptureRequest.Builder builder = activeDevice.createCaptureRequest(
                CameraDevice.TEMPLATE_PREVIEW);
        builder.addTarget(activeReader.getSurface());
        builder.set(
                CaptureRequest.CONTROL_AF_MODE,
                preferredAfMode);
        CaptureRequest request = builder.build();
        activeSession.setRepeatingRequest(request, null, cameraHandler);
        synchronized (stateLock) {
            previewRequest = request;
            liveView = true;
        }
    }

    void stopLiveView() {
        CameraCaptureSession activeSession;
        synchronized (stateLock) {
            activeSession = session;
            liveView = false;
        }
        if (activeSession == null) return;
        try {
            activeSession.stopRepeating();
            activeSession.abortCaptures();
        } catch (CameraAccessException | IllegalStateException ignored) {
        }
    }

    byte[] getLiveViewFrame() throws Exception {
        if (!isLiveView()) throw new IllegalStateException("本机摄像头取景未开启");
        byte[] immediate = latestPreview.getAndSet(null);
        if (immediate != null) {
            previewAvailable.drainPermits();
            return immediate;
        }
        previewAvailable.drainPermits();
        if (!previewAvailable.tryAcquire(2, TimeUnit.SECONDS)) {
            throw new IllegalStateException("本机摄像头暂未返回取景画面");
        }
        byte[] frame = latestPreview.getAndSet(null);
        if (frame == null) throw new IllegalStateException("本机摄像头返回了空画面");
        return frame;
    }

    byte[] capture() throws Exception {
        CameraDevice activeDevice;
        CameraCaptureSession activeSession;
        ImageReader activeReader;
        boolean sharedReader;
        synchronized (stateLock) {
            activeDevice = device;
            activeSession = session;
            activeReader = captureReader;
            sharedReader = sharedReaderMode;
        }
        if (activeDevice == null || activeSession == null || activeReader == null) {
            throw new IllegalStateException("请先连接本机摄像头");
        }
        if (sharedReader) {
            activeSession.stopRepeating();
            drainImages(activeReader);
            latestPreview.set(null);
            previewAvailable.drainPermits();
        }
        CompletableFuture<byte[]> future = new CompletableFuture<>();
        synchronized (stateLock) {
            pendingCapture = future;
            pendingCaptureTimestampNanos = Long.MAX_VALUE;
        }
        CaptureRequest.Builder builder = activeDevice.createCaptureRequest(
                CameraDevice.TEMPLATE_STILL_CAPTURE);
        builder.addTarget(activeReader.getSurface());
        builder.set(
                CaptureRequest.CONTROL_AF_MODE,
                preferredAfMode);
        builder.set(
                CaptureRequest.CONTROL_AE_MODE,
                CaptureRequest.CONTROL_AE_MODE_ON);
        activeSession.capture(builder.build(), new CameraCaptureSession.CaptureCallback() {
            @Override public void onCaptureStarted(
                    CameraCaptureSession captureSession,
                    CaptureRequest request,
                    long timestamp,
                    long frameNumber) {
                synchronized (stateLock) {
                    if (pendingCapture == future) {
                        pendingCaptureTimestampNanos = timestamp;
                    }
                }
            }

            @Override public void onCaptureFailed(
                    CameraCaptureSession captureSession,
                    CaptureRequest request,
                    android.hardware.camera2.CaptureFailure failure) {
                future.completeExceptionally(
                        new IllegalStateException("本机摄像头拍摄失败"));
            }

            @Override public void onCaptureCompleted(
                    CameraCaptureSession captureSession,
                    CaptureRequest request,
                    TotalCaptureResult result) {
                // JPEG delivery is completed by the ImageReader callback.
            }
        }, cameraHandler);
        try {
            return future.get(12, TimeUnit.SECONDS);
        } finally {
            synchronized (stateLock) {
                if (pendingCapture == future) {
                    pendingCapture = null;
                    pendingCaptureTimestampNanos = Long.MAX_VALUE;
                }
            }
            if (isLiveView() && previewRequest != null) {
                try {
                    activeSession.setRepeatingRequest(previewRequest, null, cameraHandler);
                } catch (CameraAccessException | IllegalStateException ignored) {
                }
            }
        }
    }

    private void onPreviewImage(ImageReader reader) {
        try (Image image = reader.acquireLatestImage()) {
            if (image == null) return;
            latestPreview.set(readJpeg(image));
            previewAvailable.drainPermits();
            previewAvailable.release();
        }
    }

    private void onCaptureImage(ImageReader reader) {
        try (Image image = reader.acquireNextImage()) {
            if (image == null) return;
            CompletableFuture<byte[]> future;
            synchronized (stateLock) { future = pendingCapture; }
            if (future != null) future.complete(readJpeg(image));
        }
    }

    private void onSharedImage(ImageReader reader) {
        try (Image image = reader.acquireLatestImage()) {
            if (image == null) return;
            byte[] jpeg = readJpeg(image);
            CompletableFuture<byte[]> future;
            long captureTimestamp;
            synchronized (stateLock) {
                future = pendingCapture;
                captureTimestamp = pendingCaptureTimestampNanos;
            }
            if (future != null
                    && captureTimestamp != Long.MAX_VALUE
                    && image.getTimestamp() >= captureTimestamp) {
                future.complete(jpeg);
                return;
            }
            latestPreview.set(jpeg);
            previewAvailable.drainPermits();
            previewAvailable.release();
        }
    }

    private static void drainImages(ImageReader reader) {
        while (true) {
            Image image;
            try {
                image = reader.acquireNextImage();
            } catch (IllegalStateException error) {
                return;
            }
            if (image == null) return;
            image.close();
        }
    }

    private static byte[] readJpeg(Image image) {
        ByteBuffer buffer = image.getPlanes()[0].getBuffer();
        byte[] bytes = new byte[buffer.remaining()];
        buffer.get(bytes);
        return bytes;
    }

    private OpenedCamera openCamera(String cameraId) throws Exception {
        OpenedCamera openedCamera = new OpenedCamera();
        manager.openCamera(cameraId, new CameraDevice.StateCallback() {
            @Override public void onOpened(CameraDevice camera) {
                openedCamera.device = camera;
                if (openedCamera.abandoned.get()) camera.close();
                openedCamera.opened.countDown();
            }

            @Override public void onDisconnected(CameraDevice camera) {
                Exception error = new CameraAccessException(
                        CameraAccessException.CAMERA_DISCONNECTED,
                        "本机摄像头已断开");
                openedCamera.lifecycleError.compareAndSet(null, error);
                signalCameraFailure(openedCamera);
                handleDeviceTermination(camera, error);
                camera.close();
            }

            @Override public void onError(CameraDevice camera, int errorCode) {
                Exception error = cameraOpenError(errorCode);
                openedCamera.lifecycleError.compareAndSet(null, error);
                signalCameraFailure(openedCamera);
                handleDeviceTermination(camera, error);
                camera.close();
            }

            @Override public void onClosed(CameraDevice camera) {
                openedCamera.closed.countDown();
            }
        }, cameraHandler);
        if (!openedCamera.opened.await(OPEN_TIMEOUT_SECONDS, TimeUnit.SECONDS)) {
            closeAttempt(openedCamera);
            throw new CameraAccessException(
                    CameraAccessException.CAMERA_ERROR,
                    "打开本机摄像头超时");
        }
        Exception error = openedCamera.lifecycleError.get();
        if (error != null) {
            closeAttempt(openedCamera);
            throw error;
        }
        if (openedCamera.device == null) {
            closeAttempt(openedCamera);
            throw new IllegalStateException("本机摄像头未打开");
        }
        return openedCamera;
    }

    private ConfiguredCamera configureSession(
            OpenedCamera openedCamera,
            StreamCandidate candidate) throws Exception {
        ImageReader candidatePreview = ImageReader.newInstance(
                candidate.previewSize.getWidth(),
                candidate.previewSize.getHeight(),
                ImageFormat.JPEG,
                3);
        ImageReader candidateCapture = candidate.sharedReader
                ? candidatePreview
                : ImageReader.newInstance(
                        candidate.captureSize.getWidth(),
                        candidate.captureSize.getHeight(),
                        ImageFormat.JPEG,
                        2);
        if (candidate.sharedReader) {
            candidatePreview.setOnImageAvailableListener(this::onSharedImage, cameraHandler);
        } else {
            candidatePreview.setOnImageAvailableListener(this::onPreviewImage, cameraHandler);
            candidateCapture.setOnImageAvailableListener(this::onCaptureImage, cameraHandler);
        }

        List<Surface> surfaces = candidate.sharedReader
                ? Arrays.asList(candidatePreview.getSurface())
                : Arrays.asList(candidatePreview.getSurface(), candidateCapture.getSurface());
        CountDownLatch configured = new CountDownLatch(1);
        AtomicBoolean abandoned = new AtomicBoolean(false);
        AtomicReference<CameraCaptureSession> configuredSession = new AtomicReference<>();
        AtomicReference<Exception> sessionError = new AtomicReference<>();
        openedCamera.configuring.set(configured);
        try {
            openedCamera.device.createCaptureSession(
                    surfaces,
                    new CameraCaptureSession.StateCallback() {
                        @Override public void onConfigured(CameraCaptureSession value) {
                            if (abandoned.get()) {
                                value.close();
                            } else {
                                configuredSession.set(value);
                            }
                            configured.countDown();
                        }

                        @Override public void onConfigureFailed(CameraCaptureSession value) {
                            value.close();
                            sessionError.set(new IllegalStateException(
                                    "无法创建本机摄像头采集会话"));
                            configured.countDown();
                        }
                    },
                    cameraHandler);
        } catch (Exception error) {
            abandoned.set(true);
            openedCamera.configuring.compareAndSet(configured, null);
            closeReaders(candidatePreview, candidateCapture);
            throw error;
        }
        if (!configured.await(SESSION_TIMEOUT_SECONDS, TimeUnit.SECONDS)) {
            abandoned.set(true);
            openedCamera.configuring.compareAndSet(configured, null);
            CameraCaptureSession lateSession = configuredSession.getAndSet(null);
            if (lateSession != null) lateSession.close();
            closeReaders(candidatePreview, candidateCapture);
            throw new IllegalStateException("创建本机摄像头采集会话超时");
        }
        openedCamera.configuring.compareAndSet(configured, null);
        Exception lifecycleError = openedCamera.lifecycleError.get();
        Exception configureError = sessionError.get();
        CameraCaptureSession value = configuredSession.get();
        if (lifecycleError != null || configureError != null || value == null) {
            abandoned.set(true);
            if (value != null) value.close();
            closeReaders(candidatePreview, candidateCapture);
            if (lifecycleError != null) throw lifecycleError;
            if (configureError != null) throw configureError;
            throw new IllegalStateException("无法创建本机摄像头采集会话");
        }
        return new ConfiguredCamera(
                value,
                candidatePreview,
                candidateCapture,
                candidate.sharedReader);
    }

    private static void signalCameraFailure(OpenedCamera openedCamera) {
        openedCamera.opened.countDown();
        CountDownLatch configuring = openedCamera.configuring.get();
        if (configuring != null) configuring.countDown();
    }

    private void handleDeviceTermination(CameraDevice camera, Exception error) {
        CameraCaptureSession failedSession = null;
        CompletableFuture<byte[]> failedCapture = null;
        synchronized (stateLock) {
            if (device == camera) {
                failedSession = session;
                session = null;
                device = null;
                liveView = false;
                failedCapture = pendingCapture;
                pendingCapture = null;
                pendingCaptureTimestampNanos = Long.MAX_VALUE;
            }
        }
        if (failedSession != null) failedSession.close();
        if (failedCapture != null) failedCapture.completeExceptionally(error);
    }

    private static Exception cameraOpenError(int error) {
        String message;
        int reason;
        switch (error) {
            case CameraDevice.StateCallback.ERROR_CAMERA_IN_USE:
                message = "本机摄像头正被其他应用占用，请先关闭占用相机的应用";
                reason = CameraAccessException.CAMERA_IN_USE;
                break;
            case CameraDevice.StateCallback.ERROR_MAX_CAMERAS_IN_USE:
                message = "本机摄像头已达同时使用上限，请先关闭其他相机应用";
                reason = CameraAccessException.MAX_CAMERAS_IN_USE;
                break;
            case CameraDevice.StateCallback.ERROR_CAMERA_DISABLED:
                message = "本机摄像头已被系统禁用，请在系统设置中检查相机权限";
                reason = CameraAccessException.CAMERA_DISABLED;
                break;
            default:
                message = "无法打开本机摄像头（错误 " + error + "）";
                reason = CameraAccessException.CAMERA_ERROR;
        }
        return new CameraAccessException(reason, message);
    }

    private static void closeReaders(ImageReader first, ImageReader second) {
        first.close();
        if (second != first) second.close();
    }

    private static void closeAttempt(OpenedCamera openedCamera) {
        openedCamera.abandoned.set(true);
        CameraDevice candidateDevice = openedCamera.device;
        if (candidateDevice == null) return;
        candidateDevice.close();
        try {
            openedCamera.closed.await(2, TimeUnit.SECONDS);
        } catch (InterruptedException error) {
            Thread.currentThread().interrupt();
        }
    }

    private String chooseCameraId() throws CameraAccessException {
        String fallback = null;
        for (String id : manager.getCameraIdList()) {
            CameraCharacteristics characteristics = manager.getCameraCharacteristics(id);
            Integer facing = characteristics.get(CameraCharacteristics.LENS_FACING);
            if (facing != null && facing == CameraCharacteristics.LENS_FACING_BACK) {
                return id;
            }
            if (fallback == null) fallback = id;
        }
        if (fallback == null) {
            throw new CameraAccessException(
                    CameraAccessException.CAMERA_ERROR,
                    "设备没有可用的本机摄像头");
        }
        return fallback;
    }

    private static List<StreamCandidate> buildStreamCandidates(Size[] sizes) {
        Map<String, StreamCandidate> candidates = new LinkedHashMap<>();
        Size preferredPreview = choosePreviewSize(sizes, 1920, 1080);
        Size preferredCapture = chooseCaptureSize(sizes, 12_000_000L);
        Size reducedPreview = choosePreviewSize(sizes, 1280, 720);
        Size reducedCapture = chooseCaptureSize(sizes, 4_000_000L);
        Size smallest = Arrays.stream(sizes)
                .min(Comparator.comparingLong(LocalCameraController::area))
                .orElse(sizes[0]);

        addStreamCandidate(candidates, preferredPreview, preferredCapture, false);
        addStreamCandidate(candidates, reducedPreview, reducedCapture, false);
        addStreamCandidate(candidates, preferredPreview, preferredPreview, true);
        addStreamCandidate(candidates, reducedPreview, reducedPreview, true);
        addStreamCandidate(candidates, smallest, smallest, true);
        return new ArrayList<>(candidates.values());
    }

    private static void addStreamCandidate(
            Map<String, StreamCandidate> candidates,
            Size previewSize,
            Size captureSize,
            boolean sharedReader) {
        StreamCandidate candidate = new StreamCandidate(
                previewSize,
                captureSize,
                sharedReader);
        candidates.putIfAbsent(candidate.key(), candidate);
    }

    private static Size choosePreviewSize(Size[] sizes, int maxLongEdge, int maxShortEdge) {
        return Arrays.stream(sizes)
                .filter(size -> Math.max(size.getWidth(), size.getHeight()) <= maxLongEdge
                        && Math.min(size.getWidth(), size.getHeight()) <= maxShortEdge)
                .max(Comparator.comparingLong(LocalCameraController::area))
                .orElseGet(() -> Arrays.stream(sizes)
                        .min(Comparator.comparingLong(LocalCameraController::area))
                        .orElse(sizes[0]));
    }

    private static Size chooseCaptureSize(Size[] sizes, long maxPixels) {
        return Arrays.stream(sizes)
                .filter(size -> area(size) <= maxPixels)
                .max(Comparator.comparingLong(LocalCameraController::area))
                .orElseGet(() -> Arrays.stream(sizes)
                        .min(Comparator.comparingLong(LocalCameraController::area))
                        .orElse(sizes[0]));
    }

    private static long area(Size size) {
        return (long) size.getWidth() * size.getHeight();
    }

    private void startThread() {
        cameraThread = new HandlerThread("ZENCHE Local Camera");
        cameraThread.start();
        cameraHandler = new Handler(cameraThread.getLooper());
    }

    @Override
    public void close() {
        CompletableFuture<byte[]> future;
        synchronized (stateLock) {
            liveView = false;
            future = pendingCapture;
            pendingCapture = null;
            pendingCaptureTimestampNanos = Long.MAX_VALUE;
        }
        if (future != null) future.completeExceptionally(
                new IllegalStateException("本机摄像头已断开"));
        CameraCaptureSession activeSession;
        CameraDevice activeDevice;
        synchronized (stateLock) {
            activeSession = session;
            activeDevice = device;
            session = null;
            device = null;
            previewRequest = null;
            preferredAfMode = CaptureRequest.CONTROL_AF_MODE_OFF;
            sharedReaderMode = false;
        }
        if (activeSession != null) activeSession.close();
        if (activeDevice != null) activeDevice.close();
        ImageReader activePreviewReader = previewReader;
        ImageReader activeCaptureReader = captureReader;
        if (activePreviewReader != null) activePreviewReader.close();
        if (activeCaptureReader != null && activeCaptureReader != activePreviewReader) {
            activeCaptureReader.close();
        }
        previewReader = null;
        captureReader = null;
        latestPreview.set(null);
        previewAvailable.drainPermits();
        HandlerThread thread = cameraThread;
        cameraThread = null;
        cameraHandler = null;
        if (thread != null) thread.quitSafely();
    }
}
