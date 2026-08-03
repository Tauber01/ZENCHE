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
import java.util.Arrays;
import java.util.Comparator;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.Semaphore;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicReference;

/**
 * Camera2-backed source for the phone/tablet camera. Frames are exposed as
 * JPEG bytes so the existing ZENCHE preview, monitor and storage pipeline can
 * consume them without introducing a second rendering stack.
 */
final class LocalCameraController implements AutoCloseable {
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
    private String cameraName = "本机摄像头";
    private int preferredAfMode = CaptureRequest.CONTROL_AF_MODE_OFF;
    private boolean liveView;

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
        Size previewSize = choosePreviewSize(jpegSizes);
        Size captureSize = chooseCaptureSize(jpegSizes);
        previewReader = ImageReader.newInstance(
                previewSize.getWidth(),
                previewSize.getHeight(),
                ImageFormat.JPEG,
                3);
        captureReader = ImageReader.newInstance(
                captureSize.getWidth(),
                captureSize.getHeight(),
                ImageFormat.JPEG,
                2);
        previewReader.setOnImageAvailableListener(this::onPreviewImage, cameraHandler);
        captureReader.setOnImageAvailableListener(this::onCaptureImage, cameraHandler);

        CountDownLatch opened = new CountDownLatch(1);
        AtomicReference<Exception> openError = new AtomicReference<>();
        manager.openCamera(cameraId, new CameraDevice.StateCallback() {
            @Override public void onOpened(CameraDevice camera) {
                synchronized (stateLock) { device = camera; }
                opened.countDown();
            }

            @Override public void onDisconnected(CameraDevice camera) {
                openError.set(new CameraAccessException(
                        CameraAccessException.CAMERA_DISCONNECTED,
                        "本机摄像头已断开"));
                camera.close();
                opened.countDown();
            }

            @Override public void onError(CameraDevice camera, int error) {
                openError.set(new CameraAccessException(
                        CameraAccessException.CAMERA_ERROR,
                        "无法打开本机摄像头（错误 " + error + "）"));
                camera.close();
                opened.countDown();
            }
        }, cameraHandler);
        if (!opened.await(10, TimeUnit.SECONDS)) {
            close();
            throw new CameraAccessException(
                    CameraAccessException.CAMERA_ERROR,
                    "打开本机摄像头超时");
        }
        if (openError.get() != null) {
            close();
            throw openError.get();
        }

        CountDownLatch configured = new CountDownLatch(1);
        AtomicReference<Exception> sessionError = new AtomicReference<>();
        CameraDevice activeDevice;
        synchronized (stateLock) { activeDevice = device; }
        if (activeDevice == null) throw new IllegalStateException("本机摄像头未打开");
        activeDevice.createCaptureSession(
                Arrays.asList(previewReader.getSurface(), captureReader.getSurface()),
                new CameraCaptureSession.StateCallback() {
                    @Override public void onConfigured(CameraCaptureSession value) {
                        synchronized (stateLock) { session = value; }
                        configured.countDown();
                    }

                    @Override public void onConfigureFailed(CameraCaptureSession value) {
                        sessionError.set(new IllegalStateException("无法创建本机摄像头采集会话"));
                        configured.countDown();
                    }
                },
                cameraHandler);
        if (!configured.await(10, TimeUnit.SECONDS)) {
            close();
            throw new IllegalStateException("创建本机摄像头采集会话超时");
        }
        if (sessionError.get() != null) {
            close();
            throw sessionError.get();
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
        synchronized (stateLock) {
            activeDevice = device;
            activeSession = session;
            activeReader = captureReader;
        }
        if (activeDevice == null || activeSession == null || activeReader == null) {
            throw new IllegalStateException("请先连接本机摄像头");
        }
        CompletableFuture<byte[]> future = new CompletableFuture<>();
        synchronized (stateLock) { pendingCapture = future; }
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
                if (pendingCapture == future) pendingCapture = null;
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

    private static byte[] readJpeg(Image image) {
        ByteBuffer buffer = image.getPlanes()[0].getBuffer();
        byte[] bytes = new byte[buffer.remaining()];
        buffer.get(bytes);
        return bytes;
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

    private static Size choosePreviewSize(Size[] sizes) {
        return Arrays.stream(sizes)
                .filter(size -> size.getWidth() <= 1920 && size.getHeight() <= 1080)
                .max(Comparator.comparingLong(LocalCameraController::area))
                .orElseGet(() -> Arrays.stream(sizes)
                        .min(Comparator.comparingLong(LocalCameraController::area))
                        .orElse(sizes[0]));
    }

    private static Size chooseCaptureSize(Size[] sizes) {
        return Arrays.stream(sizes)
                .filter(size -> area(size) <= 12_000_000L)
                .max(Comparator.comparingLong(LocalCameraController::area))
                .orElseGet(() -> Arrays.stream(sizes)
                        .max(Comparator.comparingLong(LocalCameraController::area))
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
        }
        if (activeSession != null) activeSession.close();
        if (activeDevice != null) activeDevice.close();
        if (previewReader != null) previewReader.close();
        if (captureReader != null) captureReader.close();
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
