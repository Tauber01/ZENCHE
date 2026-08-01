package com.tauber.nikonlink;

import android.Manifest;
import android.app.Activity;
import android.app.AlertDialog;
import android.app.Dialog;
import android.app.PendingIntent;
import android.content.ClipData;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.PackageManager;
import android.content.res.Configuration;
import android.database.Cursor;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.ColorMatrix;
import android.graphics.ColorMatrixColorFilter;
import android.graphics.Matrix;
import android.graphics.Paint;
import android.graphics.Typeface;
import android.media.MediaMetadataRetriever;
import android.graphics.drawable.Drawable;
import android.graphics.drawable.GradientDrawable;
import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;
import android.hardware.usb.UsbDevice;
import android.hardware.usb.UsbManager;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Environment;
import android.os.Handler;
import android.os.Looper;
import android.provider.MediaStore;
import android.provider.OpenableColumns;
import android.content.ContentUris;
import android.text.InputType;
import android.util.Base64;
import android.util.Size;
import android.view.Gravity;
import android.view.DragEvent;
import android.view.GestureDetector;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewGroup;
import android.view.animation.DecelerateInterpolator;
import android.util.TypedValue;
import android.view.Window;
import android.view.WindowInsets;
import android.widget.ArrayAdapter;
import android.widget.AdapterView;
import android.widget.Button;
import android.widget.CheckBox;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.HorizontalScrollView;
import android.widget.ImageView;
import android.widget.ImageButton;
import android.widget.LinearLayout;
import android.widget.MediaController;
import android.widget.ScrollView;
import android.widget.SeekBar;
import android.widget.Spinner;
import android.widget.Switch;
import android.widget.TextView;
import android.widget.Toast;
import android.widget.VideoView;

import androidx.core.content.FileProvider;

import org.json.JSONArray;
import org.json.JSONObject;

import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyProperties;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.security.KeyStore;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.Date;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicReference;
import java.util.function.IntConsumer;

import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;

public final class MainActivity extends Activity {
    private static final String USB_PERMISSION_ACTION = "com.tauber.nikonlink.USB_PERMISSION";
    private static final int REQUEST_IMPORT_LUT = 4102;
    private static final int REQUEST_OWNER_PHOTO = 4103;
    private static final int REQUEST_CLOUD_PHOTOS = 4104;
    private static final int REQUEST_MEDIA_LIBRARY = 4105;
    private static final int PAPER = Color.rgb(246, 248, 252);
    private static final int PAPER_2 = Color.rgb(239, 243, 248);
    private static final int SURFACE = Color.WHITE;
    private static final int INK = Color.rgb(20, 24, 32);
    private static final int MUTED = Color.rgb(91, 102, 119);
    private static final int COBALT = Color.rgb(5, 90, 210);
    private static final int COBALT_SOFT = Color.rgb(225, 237, 255);
    private static final int VIDEO = Color.rgb(202, 31, 42);
    private static final int VIDEO_SOFT = Color.rgb(255, 230, 232);
    private static final int GRAPHITE = Color.rgb(12, 15, 21);
    private static final int RULE = Color.rgb(220, 225, 234);
    private static final int RULE_STRONG = Color.rgb(174, 184, 199);
    private static final String LATEST_RELEASE_API =
            "https://api.github.com/repos/Tauber01/ZENCHE/releases/latest";
    private static final String RELEASES_URL =
            "https://github.com/Tauber01/ZENCHE/releases";
    private static final String MIRROR_CHYAN_RESOURCE_ID = "ZENCHE";
    private static final String MIRROR_CHYAN_API =
            "https://mirrorchyan.com/api/resources/"
                    + MIRROR_CHYAN_RESOURCE_ID
                    + "/latest";
    private static final String MIRROR_CHYAN_CDK_KEY = "mirrorChyanCdk";
    private static final String MIRROR_CHYAN_KEY_ALIAS =
            "NikonLink.MirrorChyanCDK";
    private static final String AFDIAN_URL =
            "https://www.ifdian.net/a/Tauber";
    private static final String AUTOMATIC_UPDATE_KEY = "automaticallyCheckForUpdates";
    private static final String DISMISSED_ANNOUNCEMENT_VERSION_KEY =
            "dismissedLaunchAnnouncementVersion";
    private static final String LIBRARY_BRANCHES_KEY = "libraryUserBranches";
    private static final String LIBRARY_FILE_ASSIGNMENTS_KEY =
            "libraryFileBranchAssignments";

    private static final class EditorAdjustments {
        int exposure;
        int contrast;
        int highlights;
        int shadows;
        int whites;
        int blacks;
        int temperature;
        int tint;
        int vibrance;
        int saturation;
        int texture;
        int clarity;
        int sharpening;
        int noiseReduction;
        int dehaze;
        int vignette;
        int rotation;
        boolean flipHorizontal;
        boolean flipVertical;
        boolean showingOriginal;
        String cropRatio = "original";

        void reset() {
            exposure = 0;
            contrast = 0;
            highlights = 0;
            shadows = 0;
            whites = 0;
            blacks = 0;
            temperature = 0;
            tint = 0;
            vibrance = 0;
            saturation = 0;
            texture = 0;
            clarity = 0;
            sharpening = 0;
            noiseReduction = 0;
            dehaze = 0;
            vignette = 0;
            rotation = 0;
            flipHorizontal = false;
            flipVertical = false;
            showingOriginal = false;
            cropRatio = "original";
        }

        void resetTone() {
            int savedRotation = rotation;
            boolean savedFlipHorizontal = flipHorizontal;
            boolean savedFlipVertical = flipVertical;
            String savedCropRatio = cropRatio;
            reset();
            rotation = savedRotation;
            flipHorizontal = savedFlipHorizontal;
            flipVertical = savedFlipVertical;
            cropRatio = savedCropRatio;
        }

        EditorAdjustments copy() {
            EditorAdjustments copy = new EditorAdjustments();
            copy.exposure = exposure;
            copy.contrast = contrast;
            copy.highlights = highlights;
            copy.shadows = shadows;
            copy.whites = whites;
            copy.blacks = blacks;
            copy.temperature = temperature;
            copy.tint = tint;
            copy.vibrance = vibrance;
            copy.saturation = saturation;
            copy.texture = texture;
            copy.clarity = clarity;
            copy.sharpening = sharpening;
            copy.noiseReduction = noiseReduction;
            copy.dehaze = dehaze;
            copy.vignette = vignette;
            copy.rotation = rotation;
            copy.flipHorizontal = flipHorizontal;
            copy.flipVertical = flipVertical;
            copy.showingOriginal = showingOriginal;
            copy.cropRatio = cropRatio;
            return copy;
        }
    }

    private final ExecutorService cameraExecutor = Executors.newSingleThreadExecutor();
    private final ExecutorService previewExecutor = Executors.newSingleThreadExecutor();
    private final ExecutorService updateExecutor = Executors.newSingleThreadExecutor();
    private final ExecutorService editorExecutor = Executors.newSingleThreadExecutor();
    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private final AtomicReference<PreviewPacket> pendingPreview = new AtomicReference<>();
    private final AtomicBoolean previewWorkerRunning = new AtomicBoolean();
    private final List<View> cameraControls = new ArrayList<>();
    private final List<Button> navigationButtons = new ArrayList<>();
    private final Map<String, View> parameterControls = new HashMap<>();
    private final Map<String, TextView> parameterLabels = new HashMap<>();
    private final Map<String, Boolean> disclosureStates = new HashMap<>();
    private final List<LibraryBranch> userLibraryBranches = new ArrayList<>();
    private final Map<String, String> libraryFileAssignments = new HashMap<>();

    private PtpCamera camera;
    private DiagnosticLogger diagnostics;
    private FrameLayout contentHost;
    private TextView statusText;
    private TextView countText;
    private Button connectButton;
    private ImageView previewImage;
    private ImageView zebraImage;
    private TextView previewPlaceholder;
    private Button shutterButton;
    private Button liveViewButton;
    private Button wirelessButton;
    private TextView wirelessStatusText;
    private TextView wirelessAddressText;
    private TextView lutStatusText;
    private TextView updateStatusText;
    private TextView redHistogramText;
    private TextView greenHistogramText;
    private TextView blueHistogramText;
    private TextView waveformText;
    private TextView vectorscopeText;
    private TextView peakingCoverageText;
    private Button checkUpdateButton;
    private Button openUpdateButton;
    private Switch lutSwitch;
    private SeekBar zebraThresholdControl;
    private Bitmap latestFrame;
    private Bitmap latestSourceFrame;
    private Bitmap latestZebraMask;
    private ImageView immersivePreviewImage;
    private ImageView immersiveZebraImage;
    private Dialog immersiveDialog;
    private FrameLayout immersiveChrome;
    private Button immersiveRecordButton;
    private TextView immersiveExposureText;
    private SensorManager immersiveSensorManager;
    private Sensor immersiveRotationSensor;
    private boolean immersiveLandscape;
    private boolean immersiveParametersExpanded = true;
    private boolean immersiveMoreParametersExpanded;
    private volatile boolean immersiveMonitoring;
    private File photoDirectory;
    private CaptureWorkflow captureWorkflow;
    private WirelessTransferServer wirelessServer;

    private volatile boolean connected;
    private volatile boolean connecting;
    private volatile boolean liveViewEnabled;
    private volatile boolean capturing;
    private volatile boolean videoRecording;
    private volatile boolean wirelessRequested;
    private volatile String wirelessStatus = "无线收件箱未开启";
    private volatile int previewGeneration;
    private volatile int previewFailureCount;
    private volatile int previewAnalysisSequence;
    private volatile String connectedCameraName = "Nikon 相机";
    private volatile String exposureMode = "manual";
    private volatile boolean zebraEnabled;
    private volatile int zebraThreshold = 95;
    private volatile boolean lutEnabled;
    private volatile CubeLut previewLut;
    private volatile boolean focusPeakingEnabled;
    private volatile boolean falseColorEnabled;
    private volatile String redHistogram = "—";
    private volatile String greenHistogram = "—";
    private volatile String blueHistogram = "—";
    private volatile String waveform = "—";
    private volatile String vectorscope = "—";
    private volatile int peakingCoverage;
    private volatile String monitorVideoProfile = "source";
    private volatile int monitorFrameRate = 30;
    private volatile double monitorShutterAngle = 180;
    private volatile double currentShutterSeconds = 0.008;
    private volatile double currentAperture = 4.0;
    private volatile int currentIso = 400;
    private volatile double currentCompensation;
    private volatile String currentFocusMode = "single-shot";
    private volatile String currentWhiteBalance = "continuous";
    private volatile String currentPictureControl = "standard";
    private volatile String shootingTaskKind = "interval";
    private volatile int shootingTaskCount = 5;
    private volatile int shootingTaskInterval = 3;
    private volatile int shootingTaskStep = 1;
    private volatile boolean shootingTaskRunning;
    private volatile int shootingTaskGeneration;
    private volatile String shootingTaskStatus = "尚未开始拍摄任务";
    private volatile boolean checkingUpdate;
    private volatile String availableUpdateUrl;
    private volatile String availableVersion;
    private volatile String updateStatus = "尚未检查更新";
    private volatile String currentSection = "capture";
    private String editorSelectedPath;
    private final EditorAdjustments editorAdjustments =
            new EditorAdjustments();
    private String aiPrompt = "";
    private int aiMode = 0; // 0=edit, 1=generate
    private int aiRatioIndex = 0;
    private int aiResolutionIndex = 0;
    private android.graphics.Bitmap aiResultBitmap;
    private boolean aiIsGenerating = false;
    private EditorState editorState = EditorState.PRO;

    private enum EditorState {
        PRO, AI
    }

    private static boolean aiActivated = false;
    private static int aiUsageCount = 0;
    private static final int AI_MAX_USAGE = 100;

    private boolean isAiActivated() {
        if (!aiActivated) {
            aiActivated = getSharedPreferences("nikon-link", MODE_PRIVATE)
                    .getBoolean("ai_activated", false);
        }
        return aiActivated;
    }

    private int getRemainingUsage() {
        return Math.max(0, AI_MAX_USAGE - aiUsageCount);
    }

    private void recordAiUsage() {
        aiUsageCount++;
        getSharedPreferences("nikon-link", MODE_PRIVATE)
                .edit().putInt("ai_usage_count", aiUsageCount).apply();
        if (aiUsageCount >= AI_MAX_USAGE) {
            aiActivated = false;
            getSharedPreferences("nikon-link", MODE_PRIVATE)
                    .edit().putBoolean("ai_activated", false).apply();
        }
    }

    private String aiDeviceId() {
        String existing = getSharedPreferences("nikon-link", MODE_PRIVATE)
                .getString("ai_device_id", "");
        if (existing != null && !existing.isEmpty()) return existing;
        String id = android.provider.Settings.Secure.getString(
                getContentResolver(),
                android.provider.Settings.Secure.ANDROID_ID);
        if (id == null) id = java.util.UUID.randomUUID().toString();
        getSharedPreferences("nikon-link", MODE_PRIVATE)
                .edit().putString("ai_device_id", id).apply();
        return id;
    }

    private String loadActivationCode() {
        return getSharedPreferences("nikon-link", MODE_PRIVATE)
                .getString("ai_activated_code", "");
    }

    private String aiServerUrl() {
        return getSharedPreferences("nikon-link", MODE_PRIVATE)
                .getString("aiServerURL", "http://101.34.255.115:8787");
    }

    private static final String AI_PUBLIC_KEY =
            "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAngqgOi5fjajCPusMNsfB" +
            "FdMmWywGAwrL5bA+JK/uW+Mf/YDs5hQopYcxoDiSY2yQnGmGSo8XJ4apYLVH1bDt" +
            "PFGGj+TxfFNLGicPJzGkRKY7UVQHvlYPNiCBRPWgFw0gCNArqoHDXoTLj4q8C5MZ" +
            "9kZPv9qWeMZ5A5m5q8n2KjYfN8vLz5XH2LdPm9QaW7RzVYfJbGvKRhJzL3NxP8" +
            "+ZzVjQmzHjKlK2Qw9MkPvN7J2GXYxHdVfRjQ8GvKzL5XgP3XjH9mQz5YzQdGhN" +
            "VbKzYxHV9fHjGkJzX8DfNzVbYzGdRmNkQzNxGkPvMkHjKjYzJ2L5NxP8iQzvQ" +
            "MjQzRwIDAQAB";

    private boolean verifyActivationCode(String code) {
        if (code == null) return false;
        String trimmed = code.trim();
        if (trimmed.isEmpty()) return false;
        try {
            String[] parts = trimmed.split("-");
            if (parts.length < 4 || !"ZENCHE".equals(parts[0])
                    || !"AI".equals(parts[1])) {
                return false;
            }
            String expiryPart = parts[parts.length - 1];
            java.text.SimpleDateFormat sdf =
                    new java.text.SimpleDateFormat("yyyyMMdd", java.util.Locale.US);
            java.util.Date expiry = sdf.parse(expiryPart);
            if (expiry != null && expiry.before(new java.util.Date())) {
                return false;
            }
            StringBuilder sigBuilder = new StringBuilder();
            for (int i = 2; i < parts.length - 1; i++) {
                if (sigBuilder.length() > 0) sigBuilder.append("-");
                sigBuilder.append(parts[i]);
            }
            byte[] sigBytes = android.util.Base64.decode(
                    sigBuilder.toString(), android.util.Base64.DEFAULT);
            String deviceId = aiDeviceId();
            String payload = deviceId + ":" + expiryPart + ":a1b2c3d4e5f6";
            byte[] payloadBytes = payload.getBytes("UTF-8");

            java.security.spec.X509EncodedKeySpec keySpec =
                    new java.security.spec.X509EncodedKeySpec(
                            android.util.Base64.decode(AI_PUBLIC_KEY,
                                    android.util.Base64.DEFAULT));
            java.security.KeyFactory keyFactory =
                    java.security.KeyFactory.getInstance("RSA");
            java.security.PublicKey publicKey = keyFactory.generatePublic(keySpec);
            java.security.Signature signature =
                    java.security.Signature.getInstance("SHA256withRSA");
            signature.initVerify(publicKey);
            signature.update(payloadBytes);
            boolean valid = signature.verify(sigBytes);
            if (valid) {
                getSharedPreferences("nikon-link", MODE_PRIVATE)
                        .edit()
                        .putBoolean("ai_activated", true)
                        .putString("ai_activated_code", trimmed)
                        .putInt("ai_usage_count", 0)
                        .putString("ai_device_id", deviceId)
                        .apply();
                aiActivated = true;
                aiUsageCount = 0;
            }
            return valid;
        } catch (Exception ignored) {
            return false;
        }
    }
    private static final String[][] AI_RATIOS = {
            {"1:1", "1024x1024"},
            {"16:9", "1792x1024"},
            {"9:16", "1024x1792"},
            {"4:3", "1365x1024"},
            {"3:2", "1536x1024"},
    };

    private static final String[] AI_RESOLUTIONS = {"1K", "2K", "4K"};
    private static final String[][] AI_EDIT_PRESETS = {
            {"一键美颜", "对照片中的人物进行自然美颜：柔化皮肤、去除瑕疵、提亮肤色、轻微瘦脸，保持自然真实质感，不过度处理。"},
            {"自然增强", "增强照片的自然色彩与光影：提升饱和度与对比度，保留真实细节，使画面更通透清晰。"},
            {"胶片质感", "为照片添加复古胶片质感：轻微颗粒、柔和对比、温暖色调，类似柯达 Portra 胶片的色彩风格。"},
            {"日系清新", "调整为日系清新风格：低对比度、偏亮高调、冷色调、干净通透，画面清新柔和。"},
            {"黑白大片", "转换为高反差黑白摄影风格：增强明暗对比、保留细节纹理，营造经典黑白大片质感。"},
            {"复古暖调", "添加复古暖调风格：整体偏暖黄色调、轻微褪色、柔和光线，怀旧氛围。"},
            {"天空增强", "增强画面中的天空：让蓝天更通透湛蓝、云朵更立体，同时保持地面细节自然。"},
            {"美食诱人", "增强美食照片的诱人质感：提升色彩饱和度、增强光泽细节，让食物看起来更美味。"},
    };
    private static final String[][] AI_GEN_PRESETS = {
            {"人像写真", "professional portrait photography, studio lighting, sharp focus, shallow depth of field, high detail"},
            {"风光大片", "breathtaking landscape photography, golden hour, dramatic sky, high dynamic range, ultra detailed"},
            {"城市夜景", "city night photography, neon lights, long exposure, reflections, vibrant urban atmosphere"},
            {"产品展示", "professional product photography, clean studio background, soft lighting, high detail"},
    };
    private static final String[] AI_PROVIDERS = {
            "aimlapi.com",
            "fal.ai",
            "crazyrouter.com"
    };
    private static final String[] AI_ENDPOINTS = {
            "https://api.aimlapi.com/v1/images/generations",
            "https://fal.run/fal-ai/nano-banana-2",
            "https://cn.crazyrouter.com/v1/images/generations"
    };
    private static final String[] AI_WEBSITES = {
            "https://aimlapi.com",
            "https://fal.ai",
            "https://crazyrouter.com"
    };
    private String appLanguage = Localization.SIMPLIFIED_CHINESE;
    private final float[] immersiveRotationMatrix = new float[9];
    private final float[] immersiveOrientation = new float[3];
    private final SensorEventListener immersiveOrientationListener =
            new SensorEventListener() {
                @Override
                public void onSensorChanged(SensorEvent event) {
                    SensorManager.getRotationMatrixFromVector(
                            immersiveRotationMatrix,
                            event.values);
                    SensorManager.getOrientation(
                            immersiveRotationMatrix,
                            immersiveOrientation);
                    float roll = Math.abs(immersiveOrientation[2]);
                    boolean nextLandscape = immersiveLandscape
                            ? roll > Math.toRadians(30)
                            : roll > Math.toRadians(50);
                    if (nextLandscape == immersiveLandscape) return;
                    mainHandler.post(() -> {
                        if (immersiveDialog == null
                                || !immersiveDialog.isShowing()) return;
                        immersiveLandscape = nextLandscape;
                        buildImmersiveChrome(immersiveDialog);
                    });
                }

                @Override
                public void onAccuracyChanged(Sensor sensor, int accuracy) {
                }
            };

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        diagnostics = new DiagnosticLogger(this);
        diagnostics.startSession();
        appLanguage = Localization.normalize(
                getSharedPreferences("nikon-link", MODE_PRIVATE)
                        .getString(
                                Localization.PREFERENCE_KEY,
                                Localization.SIMPLIFIED_CHINESE));
        loadLibraryBranches();
        Window window = getWindow();
        window.setStatusBarColor(PAPER);
        window.setNavigationBarColor(GRAPHITE);
        window.getDecorView().setSystemUiVisibility(
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                        | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                        | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                        | View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR);

        camera = new PtpCamera(this, diagnostics);
        monitorVideoProfile = getSharedPreferences("nikon-link", MODE_PRIVATE)
                .getString("monitorVideoProfile", "source");
        monitorFrameRate = getSharedPreferences("nikon-link", MODE_PRIVATE)
                .getInt("monitorFrameRate", 30);
        monitorShutterAngle = Double.longBitsToDouble(
                getSharedPreferences("nikon-link", MODE_PRIVATE)
                        .getLong(
                                "monitorShutterAngle",
                                Double.doubleToRawLongBits(180)));
        File base = getExternalFilesDir(Environment.DIRECTORY_PICTURES);
        if (base == null) base = getFilesDir();
        photoDirectory = new File(base, "ZENCHE");
        File legacyPhotoDirectory = new File(base, "Nikon" + " Link");
        if (!photoDirectory.exists() && legacyPhotoDirectory.exists()) {
            legacyPhotoDirectory.renameTo(photoDirectory);
        }
        if (!photoDirectory.exists()) photoDirectory.mkdirs();
        captureWorkflow = new CaptureWorkflow(this, photoDirectory);
        wirelessServer = new WirelessTransferServer(
                photoDirectory,
                new WirelessTransferServer.Listener() {
                    @Override
                    public void onStatus(String status) {
                        diagnostics.info("wireless", status);
                        mainHandler.post(() -> {
                            wirelessStatus = status;
                            updateWirelessUi();
                        });
                    }

                    @Override
                    public void onFileReceived(File file) {
                        diagnostics.info(
                                "wireless",
                                "已接收文件；名称=" + file.getName()
                                        + "；大小=" + file.length());
                        mainHandler.post(() -> {
                            wirelessStatus = "已接收 " + file.getName();
                            updateWirelessUi();
                            updateFileCount();
                            showToast("无线图片已保存：" + file.getName());
                        });
                    }

                    @Override
                    public void onError(String message) {
                        diagnostics.error("wireless", message);
                        mainHandler.post(() -> {
                            wirelessRequested = false;
                            wirelessStatus = message;
                            updateWirelessUi();
                            showError(message);
                        });
                    }
                });

        setContentView(buildApplication());
        showSplash();
        showSection("capture");
        updateConnectionUi();
        showLaunchAnnouncementIfNeeded();
        if (getSharedPreferences("nikon-link", MODE_PRIVATE)
                .getBoolean(AUTOMATIC_UPDATE_KEY, true)) {
            checkForUpdates(true);
        }
        diagnostics.info("app", "Android 原生界面已就绪");
    }

    @Override
    public void onConfigurationChanged(Configuration configuration) {
        super.onConfigurationChanged(configuration);
        if (immersiveDialog == null || !immersiveDialog.isShowing()) return;
        immersiveLandscape =
                configuration.orientation == Configuration.ORIENTATION_LANDSCAPE;
        buildImmersiveChrome(immersiveDialog);
    }

    private void chooseLutFile() {
        Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
        intent.addCategory(Intent.CATEGORY_OPENABLE);
        intent.setType("*/*");
        intent.putExtra(
                Intent.EXTRA_MIME_TYPES,
                new String[]{"text/plain", "application/octet-stream", "application/x-cube"});
        startActivityForResult(intent, REQUEST_IMPORT_LUT);
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (resultCode != RESULT_OK || data == null) {
            return;
        }
        if (requestCode == REQUEST_OWNER_PHOTO
                || requestCode == REQUEST_CLOUD_PHOTOS) {
            List<Uri> uris = selectedUris(data);
            if (!uris.isEmpty()) {
                importSelectedPhotos(uris, requestCode == REQUEST_OWNER_PHOTO);
            }
            return;
        }
        if (requestCode != REQUEST_IMPORT_LUT || data.getData() == null) return;
        Uri uri = data.getData();
        try {
            if ((data.getFlags() & Intent.FLAG_GRANT_READ_URI_PERMISSION) != 0) {
                getContentResolver().takePersistableUriPermission(
                        uri,
                        Intent.FLAG_GRANT_READ_URI_PERMISSION);
            }
        } catch (RuntimeException ignored) {
        }
        String fallbackName = uri.getLastPathSegment();
        if (lutStatusText != null) lutStatusText.setText(tr("正在读取 LUT…"));
        previewExecutor.submit(() -> {
            try (InputStream stream = getContentResolver().openInputStream(uri)) {
                CubeLut lut = CubeLut.parse(stream, fallbackName);
                previewLut = lut;
                lutEnabled = true;
                Bitmap source = latestSourceFrame;
                ProcessedPreview output = source == null ? null : processPreview(source);
                mainHandler.post(() -> {
                    if (output != null) showProcessedPreview(source, output);
                    if (lutSwitch != null) {
                        lutSwitch.setEnabled(true);
                        lutSwitch.setChecked(true);
                    }
                    if (lutStatusText != null) {
                        lutStatusText.setText(tr("已载入 · ") + lut.getTitle());
                    }
                });
            } catch (Exception error) {
                mainHandler.post(() -> {
                    if (lutStatusText != null) {
                        lutStatusText.setText(
                                tr("导入失败；请选择有效的 3D .cube 文件。"));
                    }
                    showError("LUT 导入失败：" + error.getMessage());
                });
            }
        });
    }

    @Override
    public void onRequestPermissionsResult(
            int requestCode,
            String[] permissions,
            int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode != REQUEST_MEDIA_LIBRARY) return;
        if (hasAlbumAccess()) {
            showSection("library");
        } else {
            showToast("未获得系统相册权限；文件页仍可使用 帧澈 ZENCHE 本地文件库。");
        }
    }

    private void openOwnerAlbum() {
        if (!hasAlbumAccess()) {
            requestAlbumAccess();
            return;
        }
        if ("library".equals(currentSection)) {
            showSection("library");
        }
    }

    private void openCloudDrive() {
        showCloudDriveGuide();
    }

    private void openCloudDrivePicker() {
        Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
        intent.addCategory(Intent.CATEGORY_OPENABLE);
        intent.setType("*/*");
        intent.putExtra(
                Intent.EXTRA_MIME_TYPES,
                new String[]{"image/*", "video/*", "application/octet-stream"});
        intent.putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true);
        intent.addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION
                        | Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION);
        try {
            startActivityForResult(
                    Intent.createChooser(intent, "从网盘选择照片"),
                    REQUEST_CLOUD_PHOTOS);
        } catch (RuntimeException error) {
            showError("无法打开系统文件提供器：" + error.getMessage());
        }
    }

    private boolean hasAlbumAccess() {
        if (Build.VERSION.SDK_INT >= 33) {
            boolean images = checkSelfPermission(Manifest.permission.READ_MEDIA_IMAGES)
                    == PackageManager.PERMISSION_GRANTED;
            boolean videos = checkSelfPermission(Manifest.permission.READ_MEDIA_VIDEO)
                    == PackageManager.PERMISSION_GRANTED;
            if (Build.VERSION.SDK_INT >= 34) {
                boolean selected = checkSelfPermission(
                        Manifest.permission.READ_MEDIA_VISUAL_USER_SELECTED)
                        == PackageManager.PERMISSION_GRANTED;
                return images || videos || selected;
            }
            return images || videos;
        }
        return checkSelfPermission(Manifest.permission.READ_EXTERNAL_STORAGE)
                == PackageManager.PERMISSION_GRANTED;
    }

    private void requestAlbumAccess() {
        if (Build.VERSION.SDK_INT >= 34) {
            requestPermissions(
                    new String[]{
                            Manifest.permission.READ_MEDIA_IMAGES,
                            Manifest.permission.READ_MEDIA_VIDEO,
                            Manifest.permission.READ_MEDIA_VISUAL_USER_SELECTED
                    },
                    REQUEST_MEDIA_LIBRARY);
        } else if (Build.VERSION.SDK_INT >= 33) {
            requestPermissions(
                    new String[]{
                            Manifest.permission.READ_MEDIA_IMAGES,
                            Manifest.permission.READ_MEDIA_VIDEO
                    },
                    REQUEST_MEDIA_LIBRARY);
        } else {
            requestPermissions(
                    new String[]{Manifest.permission.READ_EXTERNAL_STORAGE},
                    REQUEST_MEDIA_LIBRARY);
        }
    }

    private void showCloudDriveGuide() {
        Dialog dialog = new Dialog(this);
        dialog.requestWindowFeature(Window.FEATURE_NO_TITLE);
        ScrollView scroll = new ScrollView(this);
        LinearLayout content = verticalContainer();
        content.setPadding(dp(24), dp(22), dp(24), dp(24));
        content.addView(text("链接网盘", 24, Typeface.BOLD, INK));
        content.addView(
                text(
                        "帧澈 ZENCHE 不代管网盘账号或密码。先在对应客户端登录，再通过系统文件选择器安全读取照片和视频。",
                        13,
                        Typeface.NORMAL,
                        MUTED),
                marginParams(-1, -2, 0, 6, 0, 18));

        addCloudProvider(
                content,
                "百度网盘",
                "安装客户端后，从系统文件选择器或“下载”目录选择。",
                "https://pan.baidu.com/");
        addCloudProvider(
                content,
                "阿里云盘",
                "把照片下载到设备或桌面同步目录后选择。",
                "https://www.alipan.com/");
        addCloudProvider(
                content,
                "腾讯微云",
                "从微云导出到本机，再回到 帧澈 ZENCHE 选择。",
                "https://www.weiyun.com/");
        addCloudProvider(
                content,
                "夸克网盘",
                "安装夸克网盘客户端并把媒体下载到设备。",
                "https://pan.quark.cn/");
        addCloudProvider(
                content,
                "迅雷云盘",
                "通过迅雷客户端下载到设备，再从系统选择器加入。",
                "https://pan.xunlei.com/");
        addCloudProvider(
                content,
                "115",
                "在“存储”中下载文件，再从 帧澈 ZENCHE 选择。",
                "https://115.com/");

        TextView steps = text(
                "1  安装并登录网盘客户端\n"
                        + "2  下载媒体或启用系统文件提供器\n"
                        + "3  点击“选择文件并加入”，可一次选择多项",
                13,
                Typeface.NORMAL,
                INK);
        steps.setLineSpacing(0, 1.35f);
        steps.setPadding(dp(12), dp(12), dp(12), dp(12));
        steps.setBackground(rounded(COBALT_SOFT, 10, 0));
        content.addView(steps, marginParams(-1, -2, 0, 10, 0, 14));

        LinearLayout actions = new LinearLayout(this);
        actions.setOrientation(LinearLayout.HORIZONTAL);
        Button close = nativeButton("关闭", false);
        close.setOnClickListener(view -> dialog.dismiss());
        actions.addView(close, new LinearLayout.LayoutParams(0, dp(48), 1f));
        Button choose = nativeButton("选择文件并加入", true);
        choose.setOnClickListener(view -> {
            dialog.dismiss();
            openCloudDrivePicker();
        });
        LinearLayout.LayoutParams chooseParams =
                new LinearLayout.LayoutParams(0, dp(48), 1.35f);
        chooseParams.setMargins(dp(10), 0, 0, 0);
        actions.addView(choose, chooseParams);
        content.addView(actions);
        scroll.addView(content);
        dialog.setContentView(scroll);
        Window window = dialog.getWindow();
        if (window != null) {
            window.setBackgroundDrawable(rounded(PAPER, 18, 0));
            window.setLayout(
                    Math.min(getResources().getDisplayMetrics().widthPixels - dp(28), dp(620)),
                    ViewGroup.LayoutParams.MATCH_PARENT);
        }
        dialog.setOnShowListener(ignored -> {
            Window shown = dialog.getWindow();
            if (shown != null) {
                shown.setLayout(
                        Math.min(
                                getResources().getDisplayMetrics().widthPixels - dp(28),
                                dp(620)),
                        (int) (getResources().getDisplayMetrics().heightPixels * 0.9f));
            }
        });
        dialog.show();
    }

    private void addCloudProvider(
            LinearLayout parent,
            String name,
            String note,
            String url) {
        Button provider = nativeButton(name + "\n" + note + "  ↗", false);
        provider.setAllCaps(false);
        provider.setGravity(Gravity.START | Gravity.CENTER_VERTICAL);
        provider.setTextSize(13);
        provider.setOnClickListener(view -> openExternalUrl(url));
        parent.addView(
                provider,
                marginParams(-1, dp(64), 0, 0, 0, 8));
    }

    private void openExternalUrl(String url) {
        try {
            startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse(url)));
        } catch (RuntimeException error) {
            showError("无法打开页面：" + error.getMessage());
        }
    }

    private List<Uri> selectedUris(Intent data) {
        List<Uri> uris = new ArrayList<>();
        ClipData clipData = data.getClipData();
        if (clipData != null) {
            for (int index = 0; index < clipData.getItemCount(); index++) {
                Uri uri = clipData.getItemAt(index).getUri();
                if (uri != null) uris.add(uri);
            }
        } else if (data.getData() != null) {
            uris.add(data.getData());
        }
        return uris;
    }

    private void importSelectedPhotos(List<Uri> uris, boolean ownerAlbum) {
        cameraExecutor.submit(() -> {
            int imported = 0;
            String lastName = null;
            Map<String, String> pairNames = new HashMap<>();
            for (Uri uri : uris) {
                try {
                    if (!ownerAlbum) {
                        try {
                            getContentResolver().takePersistableUriPermission(
                                    uri,
                                    Intent.FLAG_GRANT_READ_URI_PERMISSION);
                        } catch (RuntimeException ignored) {
                        }
                    }
                    String displayName = displayName(uri);
                    String requestedName =
                            displayName == null ? "导入照片.jpg" : displayName;
                    int dot = requestedName.lastIndexOf('.');
                    String pairKey = (dot > 0
                            ? requestedName.substring(0, dot)
                            : requestedName).toLowerCase(Locale.ROOT);
                    String reservedBase = pairNames.get(pairKey);
                    if (reservedBase == null) {
                        reservedBase = captureWorkflow.reserveBaseName(
                                ownerAlbum ? "System Album" : "Imported");
                        pairNames.put(pairKey, reservedBase);
                    }
                    File destination;
                    try (InputStream input = getContentResolver().openInputStream(uri)) {
                        if (input == null) throw new IllegalStateException("无法读取所选照片");
                        destination = captureWorkflow.importFile(
                                input,
                                requestedName,
                                ownerAlbum ? "System Album" : "Imported",
                                reservedBase);
                    }
                    imported++;
                    lastName = destination.getName();
                } catch (Exception error) {
                    diagnostics.error(
                            "library",
                            "导入照片失败；URI=" + uri + "；错误=" + error.getMessage());
                }
            }
            int finalImported = imported;
            String finalLastName = lastName;
            mainHandler.post(() -> {
                showSection("library");
                updateFileCount();
                if (finalImported > 0) {
                    showToast(
                            "已从" + (ownerAlbum ? "机主相册" : "网盘")
                                    + "加入 " + finalImported + " 张照片");
                    if (finalLastName != null) {
                        statusText.setText(tr("已加入 ") + finalLastName);
                    }
                } else {
                    showError("没有可加入文件库的照片。");
                }
            });
        });
    }

    private String displayName(Uri uri) {
        try (Cursor cursor = getContentResolver().query(
                uri,
                new String[]{OpenableColumns.DISPLAY_NAME},
                null,
                null,
                null)) {
            if (cursor != null && cursor.moveToFirst()) {
                int column = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME);
                if (column >= 0) return cursor.getString(column);
            }
        } catch (RuntimeException ignored) {
        }
        return uri.getLastPathSegment();
    }

    private File uniquePhotoDestination(String requestedName) {
        String safeName = requestedName == null
                ? "导入照片.jpg"
                : requestedName
                        .replace('\\', '_')
                        .replace('/', '_')
                        .replaceAll("[<>:\"|?*]", "_");
        if (safeName.isEmpty()) safeName = "导入照片.jpg";
        File initial = new File(photoDirectory, safeName);
        if (!initial.exists()) return initial;
        int dot = safeName.lastIndexOf('.');
        String stem = dot > 0 ? safeName.substring(0, dot) : safeName;
        String extension = dot > 0 ? safeName.substring(dot) : ".jpg";
        return new File(
                photoDirectory,
                stem + "-" + System.currentTimeMillis() + extension);
    }

    private void sharePhoto(File file) {
        try {
            Uri uri = FileProvider.getUriForFile(
                    this,
                    getPackageName() + ".files",
                    file);
            Intent share = new Intent(Intent.ACTION_SEND);
            share.setType(isVideoFile(file) ? "video/*" : "image/*");
            share.putExtra(Intent.EXTRA_STREAM, uri);
            share.setClipData(ClipData.newRawUri(file.getName(), uri));
            share.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
            startActivity(Intent.createChooser(share, "分享到社交平台"));
        } catch (RuntimeException error) {
            diagnostics.error("share", "分享照片失败：" + error.getMessage());
            showError("无法打开系统分享面板：" + error.getMessage());
        }
    }

    private void showLargePhoto(File file) {
        if (isVideoFile(file)) {
            showLargeLocalVideo(file);
            return;
        }
        BitmapFactory.Options bounds = new BitmapFactory.Options();
        bounds.inJustDecodeBounds = true;
        BitmapFactory.decodeFile(file.getAbsolutePath(), bounds);
        int sample = 1;
        while (Math.max(bounds.outWidth / sample, bounds.outHeight / sample) > 4096) {
            sample *= 2;
        }
        BitmapFactory.Options options = new BitmapFactory.Options();
        options.inSampleSize = sample;
        Bitmap bitmap = BitmapFactory.decodeFile(file.getAbsolutePath(), options);
        if (bitmap == null) {
            showError("当前格式已安全保存，但系统无法显示这张照片的大图。");
            return;
        }

        Dialog dialog = new Dialog(
                this,
                android.R.style.Theme_Black_NoTitleBar_Fullscreen);
        FrameLayout root = new FrameLayout(this);
        root.setBackgroundColor(Color.BLACK);
        ImageView imageView = new ImageView(this);
        imageView.setScaleType(ImageView.ScaleType.FIT_CENTER);
        imageView.setImageBitmap(bitmap);
        root.addView(
                imageView,
                new FrameLayout.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT,
                        ViewGroup.LayoutParams.MATCH_PARENT));

        Button close = nativeButton("关闭", false);
        close.setOnClickListener(view -> dialog.dismiss());
        FrameLayout.LayoutParams closeParams =
                new FrameLayout.LayoutParams(dp(88), dp(48), Gravity.TOP | Gravity.START);
        closeParams.setMargins(dp(16), dp(28), 0, 0);
        root.addView(close, closeParams);

        Button share = nativeButton("分享", true);
        share.setOnClickListener(view -> sharePhoto(file));
        FrameLayout.LayoutParams shareParams =
                new FrameLayout.LayoutParams(dp(96), dp(48), Gravity.TOP | Gravity.END);
        shareParams.setMargins(0, dp(28), dp(16), 0);
        root.addView(share, shareParams);
        dialog.setContentView(root);
        dialog.setOnDismissListener(ignored -> {
            if (!bitmap.isRecycled()) bitmap.recycle();
        });
        dialog.show();
    }

    private void showLargeLocalVideo(File file) {
        Dialog dialog = new Dialog(
                this,
                android.R.style.Theme_Black_NoTitleBar_Fullscreen);
        FrameLayout root = new FrameLayout(this);
        root.setBackgroundColor(Color.BLACK);
        VideoView video = new VideoView(this);
        MediaController controls = new MediaController(this);
        controls.setAnchorView(video);
        video.setMediaController(controls);
        video.setVideoURI(Uri.fromFile(file));
        video.setOnPreparedListener(player -> video.start());
        root.addView(video, new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT));
        Button close = nativeButton("关闭", false);
        close.setOnClickListener(view -> dialog.dismiss());
        FrameLayout.LayoutParams closeParams =
                new FrameLayout.LayoutParams(
                        dp(88),
                        dp(48),
                        Gravity.TOP | Gravity.START);
        closeParams.setMargins(dp(16), dp(28), 0, 0);
        root.addView(close, closeParams);
        Button share = nativeButton("分享", true);
        share.setOnClickListener(view -> sharePhoto(file));
        FrameLayout.LayoutParams shareParams =
                new FrameLayout.LayoutParams(
                        dp(96),
                        dp(48),
                        Gravity.TOP | Gravity.END);
        shareParams.setMargins(0, dp(28), dp(16), 0);
        root.addView(share, shareParams);
        dialog.setContentView(root);
        dialog.show();
    }

    private static boolean isVideoFile(File file) {
        String lower = file.getName().toLowerCase(Locale.ROOT);
        return lower.endsWith(".mp4")
                || lower.endsWith(".mov")
                || lower.endsWith(".m4v");
    }

    private void showLargeSystemMedia(MediaEntry entry) {
        Dialog dialog = new Dialog(
                this,
                android.R.style.Theme_Black_NoTitleBar_Fullscreen);
        FrameLayout root = new FrameLayout(this);
        root.setBackgroundColor(Color.BLACK);
        if (entry.video) {
            VideoView video = new VideoView(this);
            MediaController controls = new MediaController(this);
            controls.setAnchorView(video);
            video.setMediaController(controls);
            video.setVideoURI(entry.uri);
            video.setOnPreparedListener(player -> {
                player.setLooping(false);
                video.start();
            });
            root.addView(video, new FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT));
        } else {
            ImageView imageView = new ImageView(this);
            imageView.setScaleType(ImageView.ScaleType.FIT_CENTER);
            try (InputStream input =
                         getContentResolver().openInputStream(entry.uri)) {
                imageView.setImageBitmap(BitmapFactory.decodeStream(input));
            } catch (Exception error) {
                showError("无法读取系统相册照片：" + error.getMessage());
                return;
            }
            root.addView(imageView, new FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT));
        }

        Button close = nativeButton("关闭", false);
        close.setOnClickListener(view -> dialog.dismiss());
        FrameLayout.LayoutParams closeParams =
                new FrameLayout.LayoutParams(
                        dp(88),
                        dp(48),
                        Gravity.TOP | Gravity.START);
        closeParams.setMargins(dp(16), dp(28), 0, 0);
        root.addView(close, closeParams);
        Button share = nativeButton("分享", true);
        share.setOnClickListener(view -> shareMediaUri(entry));
        FrameLayout.LayoutParams shareParams =
                new FrameLayout.LayoutParams(
                        dp(96),
                        dp(48),
                        Gravity.TOP | Gravity.END);
        shareParams.setMargins(0, dp(28), dp(16), 0);
        root.addView(share, shareParams);
        dialog.setContentView(root);
        dialog.show();
    }

    private void shareMediaUri(MediaEntry entry) {
        try {
            Intent share = new Intent(Intent.ACTION_SEND);
            share.setType(entry.video ? "video/*" : "image/*");
            share.putExtra(Intent.EXTRA_STREAM, entry.uri);
            share.setClipData(ClipData.newRawUri(entry.name, entry.uri));
            share.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
            startActivity(Intent.createChooser(share, "分享到社交平台"));
        } catch (RuntimeException error) {
            showError("无法分享系统相册文件：" + error.getMessage());
        }
    }

    private static String formatDuration(long durationMillis) {
        long seconds = Math.max(0, durationMillis / 1000L);
        return String.format(
                Locale.CHINA,
                "%d:%02d",
                seconds / 60,
                seconds % 60);
    }


    private void showSplash() {
        FrameLayout splashOverlay = new FrameLayout(this);
        splashOverlay.setBackgroundColor(PAPER);
        splashOverlay.setLayoutParams(new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT));

        LinearLayout splashContent = new LinearLayout(this);
        splashContent.setOrientation(LinearLayout.VERTICAL);
        splashContent.setGravity(Gravity.CENTER);
        splashContent.setLayoutParams(new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT));

        FrameLayout markBox = new FrameLayout(this);
        markBox.setBackground(rounded(GRAPHITE, 24, 0));
        int size = dp(80);
        FrameLayout.LayoutParams markParams = new FrameLayout.LayoutParams(size, size);
        markParams.gravity = Gravity.CENTER;
        markBox.setLayoutParams(markParams);
        markBox.setAlpha(0f);
        markBox.setScaleX(0.01f);
        markBox.setScaleY(0.01f);

        TextView markText = new TextView(this);
        markText.setText("Z");
        markText.setTextSize(TypedValue.COMPLEX_UNIT_SP, 40);
        markText.setTypeface(Typeface.DEFAULT_BOLD);
        markText.setTextColor(Color.WHITE);
        markText.setGravity(Gravity.CENTER);
        markText.setLayoutParams(new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT));
        markText.setAlpha(0f);
        markText.setScaleX(0.01f);
        markText.setScaleY(0.01f);
        markBox.addView(markText);

        LinearLayout brandTexts = new LinearLayout(this);
        brandTexts.setOrientation(LinearLayout.VERTICAL);
        brandTexts.setGravity(Gravity.CENTER);
        brandTexts.setAlpha(0f);
        LinearLayout.LayoutParams brandParams = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT);
        brandParams.topMargin = dp(28);
        brandTexts.setLayoutParams(brandParams);

        TextView brandTitle = new TextView(this);
        brandTitle.setText("帧澈 ZENCHE");
        brandTitle.setTextSize(TypedValue.COMPLEX_UNIT_SP, 26);
        brandTitle.setTypeface(Typeface.DEFAULT_BOLD);
        brandTitle.setTextColor(INK);
        brandTitle.setGravity(Gravity.CENTER);

        TextView brandSub = new TextView(this);
        brandSub.setText("Capture · Connect · Flow");
        brandSub.setTextSize(TypedValue.COMPLEX_UNIT_SP, 14);
        brandSub.setTextColor(MUTED);
        brandSub.setGravity(Gravity.CENTER);
        LinearLayout.LayoutParams subParams = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT);
        subParams.topMargin = dp(6);
        brandSub.setLayoutParams(subParams);

        brandTexts.addView(brandTitle);
        brandTexts.addView(brandSub);
        splashContent.addView(markBox);
        splashContent.addView(brandTexts);
        splashOverlay.addView(splashContent);

        ViewGroup root = findViewById(android.R.id.content);
        root.addView(splashOverlay);

        // Mark animation
        markBox.animate().scaleX(1f).scaleY(1f).alpha(1f)
                .setDuration(600)
                .setInterpolator(new DecelerateInterpolator(1.5f))
                .start();
        markText.animate().scaleX(1f).scaleY(1f).alpha(1f)
                .setDuration(600)
                .setInterpolator(new DecelerateInterpolator(1.5f))
                .start();

        // Brand text fade in
        brandTexts.animate().alpha(1f).setDuration(400).setStartDelay(500).start();

        // Fade out and remove
        splashOverlay.postDelayed(() -> {
            splashOverlay.animate().alpha(0f).setDuration(500).withEndAction(() -> {
                root.removeView(splashOverlay);
            }).start();
        }, 2200);
    }


    private View buildApplication() {
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(PAPER);

        View topBar = buildTopBar();
        root.addView(topBar, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(72)));

        contentHost = new FrameLayout(this);
        root.addView(contentHost, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                0,
                1f));

        root.addView(buildBottomNavigation(), new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(70)));
        View statusBar = buildStatusBar();
        root.addView(statusBar, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(30)));
        applySystemBarInsets(root, topBar, statusBar);
        return root;
    }

    private void applySystemBarInsets(
            LinearLayout root,
            View topBar,
            View statusBar) {
        int rootPaddingLeft = root.getPaddingLeft();
        int rootPaddingRight = root.getPaddingRight();
        int topPaddingLeft = topBar.getPaddingLeft();
        int topPaddingTop = topBar.getPaddingTop();
        int topPaddingRight = topBar.getPaddingRight();
        int topPaddingBottom = topBar.getPaddingBottom();
        int statusPaddingLeft = statusBar.getPaddingLeft();
        int statusPaddingTop = statusBar.getPaddingTop();
        int statusPaddingRight = statusBar.getPaddingRight();
        int statusPaddingBottom = statusBar.getPaddingBottom();
        int topBarHeight = dp(72);
        int statusBarHeight = dp(30);

        root.setOnApplyWindowInsetsListener((view, windowInsets) -> {
            int left;
            int top;
            int right;
            int bottom;
            left = windowInsets.getSystemWindowInsetLeft();
            top = windowInsets.getSystemWindowInsetTop();
            right = windowInsets.getSystemWindowInsetRight();
            bottom = windowInsets.getSystemWindowInsetBottom();
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P
                    && windowInsets.getDisplayCutout() != null) {
                left = Math.max(left, windowInsets.getDisplayCutout().getSafeInsetLeft());
                top = Math.max(top, windowInsets.getDisplayCutout().getSafeInsetTop());
                right = Math.max(right, windowInsets.getDisplayCutout().getSafeInsetRight());
                bottom = Math.max(bottom, windowInsets.getDisplayCutout().getSafeInsetBottom());
            }

            root.setPadding(
                    rootPaddingLeft + left,
                    root.getPaddingTop(),
                    rootPaddingRight + right,
                    root.getPaddingBottom());
            topBar.setPadding(
                    topPaddingLeft,
                    topPaddingTop + top,
                    topPaddingRight,
                    topPaddingBottom);
            statusBar.setPadding(
                    statusPaddingLeft,
                    statusPaddingTop,
                    statusPaddingRight,
                    statusPaddingBottom + bottom);

            ViewGroup.LayoutParams topParams = topBar.getLayoutParams();
            topParams.height = topBarHeight + top;
            topBar.setLayoutParams(topParams);
            ViewGroup.LayoutParams statusParams = statusBar.getLayoutParams();
            statusParams.height = statusBarHeight + bottom;
            statusBar.setLayoutParams(statusParams);
            return windowInsets;
        });
        root.requestApplyInsets();
    }

    private View buildTopBar() {
        LinearLayout top = new LinearLayout(this);
        top.setOrientation(LinearLayout.HORIZONTAL);
        top.setGravity(Gravity.CENTER_VERTICAL);
        top.setPadding(dp(12), dp(8), dp(12), dp(8));
        top.setBackgroundColor(SURFACE);
        top.setElevation(dp(6));

        TextView logo = text("Z", 20, Typeface.BOLD, Color.WHITE);
        logo.setGravity(Gravity.CENTER);
        logo.setBackground(rounded(GRAPHITE, 13, 0));
        logo.setElevation(dp(5));
        top.addView(logo, new LinearLayout.LayoutParams(dp(40), dp(40)));

        LinearLayout brand = new LinearLayout(this);
        brand.setOrientation(LinearLayout.VERTICAL);
        brand.setPadding(dp(8), 0, 0, 0);
        brand.addView(text("帧澈 ZENCHE", 15, Typeface.BOLD, INK));
        brand.addView(text("Capture · Connect · Flow", 10, Typeface.NORMAL, MUTED));
        top.addView(brand, new LinearLayout.LayoutParams(dp(142), dp(44)));

        connectButton = nativeButton("连接相机", true);
        connectButton.setOnClickListener(view -> {
            if (connected) disconnectCamera();
            else showConnectionDialog();
        });
        top.addView(connectButton, new LinearLayout.LayoutParams(0, dp(46), 1f));

        ImageButton settingsButton = new ImageButton(this);
        settingsButton.setImageResource(R.drawable.ic_settings_gear);
        settingsButton.setColorFilter(INK);
        settingsButton.setScaleType(ImageView.ScaleType.CENTER);
        settingsButton.setPadding(dp(11), dp(11), dp(11), dp(11));
        settingsButton.setBackground(rounded(SURFACE, 12, RULE_STRONG));
        settingsButton.setStateListAnimator(null);
        settingsButton.setContentDescription(tr("打开设置"));
        settingsButton.setOnClickListener(view -> showSection("settings"));
        LinearLayout.LayoutParams settingsParams = new LinearLayout.LayoutParams(
                dp(48),
                dp(44));
        settingsParams.setMargins(dp(6), 0, 0, 0);
        top.addView(settingsButton, settingsParams);
        return top;
    }

    private View buildBottomNavigation() {
        LinearLayout navigation = new LinearLayout(this);
        navigation.setOrientation(LinearLayout.HORIZONTAL);
        navigation.setGravity(Gravity.CENTER);
        navigation.setPadding(dp(8), dp(7), dp(8), dp(7));
        navigation.setBackgroundColor(PAPER_2);
        navigation.setElevation(dp(8));
        navigation.addView(navButton("照片", "capture"));
        navigation.addView(navButton("视频", "monitor"));
        navigation.addView(navButton("编辑", "editor"));
        navigation.addView(navButton("分支", "library"));
        return navigation;
    }

    private View navButton(String label, String section) {
        Button button = nativeButton(label, false);
        button.setTag(section);
        button.setTextSize(11);
        button.setIncludeFontPadding(false);
        button.setCompoundDrawablePadding(dp(4));
        button.setPadding(dp(8), dp(6), dp(8), dp(5));
        int iconResource;
        switch (section) {
            case "monitor":
                iconResource = R.drawable.ic_nav_video;
                break;
            case "library":
                iconResource = R.drawable.ic_nav_library;
                break;
            case "editor":
                iconResource = R.drawable.ic_nav_library;
                break;
            default:
                iconResource = R.drawable.ic_nav_camera;
                break;
        }
        Drawable icon = getDrawable(iconResource);
        icon.setTint(MUTED);
        icon.setBounds(0, 0, dp(20), dp(20));
        button.setCompoundDrawables(null, icon, null, null);
        button.setOnClickListener(view -> {
            if ("editor".equals(section)) {
                if (editorState == EditorState.PRO) {
                    editorState = EditorState.AI;
                } else {
                    editorState = EditorState.PRO;
                }
                aiResultBitmap = null;
            }
            showSection(section);
        });
        navigationButtons.add(button);
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(0, dp(54), 1f);
        params.setMargins(dp(4), 0, dp(4), 0);
        button.setLayoutParams(params);
        return button;
    }

    private View buildStatusBar() {
        LinearLayout bar = new LinearLayout(this);
        bar.setOrientation(LinearLayout.HORIZONTAL);
        bar.setGravity(Gravity.CENTER_VERTICAL);
        bar.setPadding(dp(14), 0, dp(14), 0);
        bar.setBackgroundColor(GRAPHITE);
        statusText = text("未连接", 11, Typeface.NORMAL, Color.rgb(185, 193, 208));
        countText = text("0 张", 11, Typeface.BOLD, Color.rgb(185, 193, 208));
        bar.addView(statusText, new LinearLayout.LayoutParams(0, dp(30), 1f));
        bar.addView(countText);
        return bar;
    }

    private void showSection(String section) {
        currentSection = section;
        cameraControls.clear();
        parameterControls.clear();
        parameterLabels.clear();
        zebraThresholdControl = null;
        lutStatusText = null;
        lutSwitch = null;
        contentHost.removeAllViews();
        View content;
        switch (section) {
            case "monitor":
                content = buildMonitorView();
                break;
            case "library":
                content = buildLibraryView();
                break;
            case "editor":
                content = buildImageEditorView();
                break;
            case "settings":
                content = buildSettingsView();
                break;
            default:
                content = buildCaptureView();
                break;
        }
        contentHost.addView(content, new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT));
        for (Button button : navigationButtons) {
            boolean active = section.equals(button.getTag());
            boolean videoSection = "monitor".equals(section);
            int activeColor = videoSection ? VIDEO : COBALT;
            int activeBackground = videoSection ? VIDEO_SOFT : COBALT_SOFT;
            button.setTextColor(active ? activeColor : MUTED);
            button.setBackground(rounded(active ? activeBackground : SURFACE, 14, 0));
            Drawable icon = button.getCompoundDrawables()[1];
            if (icon != null) icon.mutate().setTint(active ? activeColor : MUTED);
            button.setElevation(active ? dp(2) : 0);
        }
        updateCameraControls();
    }

    private View buildCaptureView() {
        ScrollView scroll = new ScrollView(this);
        LinearLayout content = verticalContainer();
        content.setPadding(dp(20), dp(22), dp(20), dp(28));
        content.addView(sectionHeader(
                "照片拍摄",
                "快门、曝光、对焦、白平衡与拍摄模式集中在当前页面",
                COBALT));
        content.addView(buildPreviewStage(false));

        LinearLayout actions = new LinearLayout(this);
        actions.setOrientation(LinearLayout.HORIZONTAL);
        actions.setGravity(Gravity.CENTER_VERTICAL);
        actions.setPadding(0, dp(16), 0, dp(8));
        liveViewButton = nativeButton("实时取景", false);
        liveViewButton.setOnClickListener(view -> toggleLiveView());
        shutterButton = nativeButton("拍摄", true);
        shutterButton.setOnClickListener(view -> capturePhoto());
        cameraControls.add(liveViewButton);
        cameraControls.add(shutterButton);
        actions.addView(liveViewButton, new LinearLayout.LayoutParams(0, dp(48), 1f));
        LinearLayout.LayoutParams shutterParams = new LinearLayout.LayoutParams(0, dp(48), 1f);
        shutterParams.setMargins(dp(12), 0, 0, 0);
        actions.addView(shutterButton, shutterParams);
        content.addView(actions);

        content.addView(buildProfessionalControls());
        content.addView(buildShootingTaskPanel());
        scroll.addView(content);
        return scroll;
    }

    private View buildShootingTaskPanel() {
        LinearLayout panel = panel();
        panel.addView(text("拍摄任务", 18, Typeface.BOLD, INK));
        String[] kinds = new String[]{"interval", "exposure", "focus", "bulb"};
        Spinner kind = monitorSpinner(new String[]{
                "间隔拍摄",
                "曝光包围",
                "焦点包围",
                "B 门计时"});
        kind.setSelection(Math.max(0, Arrays.asList(kinds).indexOf(shootingTaskKind)));
        panel.addView(kind, marginParams(-1, dp(48), 0, 10, 0, 8));

        LinearLayout values = new LinearLayout(this);
        values.setOrientation(LinearLayout.HORIZONTAL);
        EditText count = taskNumberField(
                "张数",
                shootingTaskCount,
                values,
                0);
        EditText interval = taskNumberField(
                "间隔/曝光秒数",
                shootingTaskInterval,
                values,
                8);
        EditText step = taskNumberField(
                "包围步长",
                shootingTaskStep,
                values,
                8);
        panel.addView(values);

        panel.addView(
                text(shootingTaskStatus, 12, Typeface.NORMAL, MUTED),
                marginParams(-1, -2, 0, 10, 0, 8));
        Button action = nativeButton(
                shootingTaskRunning ? "取消任务" : "开始任务",
                true);
        action.setOnClickListener(view -> {
            if (shootingTaskRunning) {
                cancelShootingTask();
                showSection(currentSection);
                return;
            }
            shootingTaskKind = kinds[kind.getSelectedItemPosition()];
            shootingTaskCount = boundedInteger(count, 1, 999, 5);
            shootingTaskInterval = boundedInteger(interval, 1, 3600, 3);
            shootingTaskStep = boundedInteger(step, 1, 3, 1);
            startShootingTask();
        });
        panel.addView(action, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(48)));
        return panel;
    }

    private EditText taskNumberField(
            String hint,
            int value,
            LinearLayout parent,
            int leftMargin) {
        EditText input = new EditText(this);
        input.setHint(tr(hint));
        input.setText(String.valueOf(value));
        input.setSingleLine(true);
        input.setInputType(InputType.TYPE_CLASS_NUMBER);
        input.setTextColor(INK);
        input.setHintTextColor(MUTED);
        input.setBackground(rounded(Color.rgb(241, 244, 249), 9, RULE));
        input.setPadding(dp(10), 0, dp(8), 0);
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(
                0,
                dp(48),
                1f);
        params.setMargins(dp(leftMargin), 0, 0, 0);
        parent.addView(input, params);
        return input;
    }

    private int boundedInteger(
            EditText input,
            int minimum,
            int maximum,
            int fallback) {
        try {
            return Math.max(
                    minimum,
                    Math.min(maximum, Integer.parseInt(input.getText().toString())));
        } catch (Exception ignored) {
            return fallback;
        }
    }

    private View buildMonitorView() {
        ScrollView scroll = new ScrollView(this);
        LinearLayout content = verticalContainer();
        content.setPadding(dp(20), dp(22), dp(20), dp(24));
        content.addView(sectionHeader(
                "视频监看",
                connected
                        ? connectedCameraName + " · 视频取景与本地监看处理"
                        : "EXPEED 6 / 7 · " + PtpCamera.SUPPORTED_CAMERA_SUMMARY,
                VIDEO));
        content.addView(buildPreviewStage(true), new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(300)));
        LinearLayout actions = new LinearLayout(this);
        actions.setOrientation(LinearLayout.HORIZONTAL);
        liveViewButton = nativeButton(
                liveViewEnabled ? "停止实时取景" : "开启实时取景",
                false);
        liveViewButton.setOnClickListener(view -> toggleLiveView());
        shutterButton = nativeButton(
                videoRecording ? "停止录制" : "开始录制",
                true);
        shutterButton.setBackground(rounded(VIDEO, 9, 0));
        shutterButton.setOnClickListener(view -> toggleVideoRecording());
        cameraControls.add(liveViewButton);
        cameraControls.add(shutterButton);
        LinearLayout.LayoutParams buttonParams = new LinearLayout.LayoutParams(
                0,
                dp(50),
                1f);
        buttonParams.setMargins(0, dp(16), 0, 0);
        actions.addView(liveViewButton, buttonParams);
        LinearLayout.LayoutParams recordParams = new LinearLayout.LayoutParams(
                0,
                dp(50),
                1f);
        recordParams.setMargins(dp(10), dp(16), 0, 0);
        actions.addView(shutterButton, recordParams);
        content.addView(actions);
        content.addView(buildMonitorParameterControls());
        content.addView(buildMonitorOutputControls());
        scroll.addView(content);
        return scroll;
    }

    private View buildPreviewStage(boolean monitoring) {
        FrameLayout stage = new FrameLayout(this);
        stage.setBackground(rounded(GRAPHITE, 14, 0));

        previewImage = new ImageView(this);
        previewImage.setScaleType(ImageView.ScaleType.FIT_CENTER);
        previewImage.setBackgroundColor(GRAPHITE);
        Bitmap previewFrame = monitoring ? latestFrame : latestSourceFrame;
        if (previewFrame != null) previewImage.setImageBitmap(previewFrame);
        stage.addView(previewImage, new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT));

        zebraImage = new ImageView(this);
        zebraImage.setScaleType(ImageView.ScaleType.FIT_CENTER);
        zebraImage.setImageBitmap(
                monitoring && zebraEnabled ? latestZebraMask : null);
        zebraImage.setVisibility(monitoring ? View.VISIBLE : View.GONE);
        zebraImage.setContentDescription("本地条纹图案加亮显示");
        stage.addView(zebraImage, new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT));

        previewPlaceholder = text(
                connected ? "等待实时取景画面" : "连接支持的 Nikon 相机后开启实时取景",
                15,
                Typeface.NORMAL,
                Color.rgb(132, 140, 153));
        previewPlaceholder.setGravity(Gravity.CENTER);
        previewPlaceholder.setVisibility(latestFrame == null ? View.VISIBLE : View.GONE);
        stage.addView(previewPlaceholder, new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT));

        TextView badge = text(
                liveViewEnabled ? "● LIVE" : "● NO SOURCE",
                11,
                Typeface.BOLD,
                liveViewEnabled ? Color.RED : Color.rgb(140, 148, 160));
        FrameLayout.LayoutParams badgeParams = new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                dp(32),
                Gravity.TOP | Gravity.START);
        badgeParams.setMargins(dp(14), dp(10), 0, 0);
        stage.addView(badge, badgeParams);

        Button fullscreen = nativeButton("全屏", false);
        fullscreen.setContentDescription(
                monitoring ? "打开视频全屏取景" : "打开照片全屏取景");
        fullscreen.setOnClickListener(view -> showImmersivePreview(monitoring));
        FrameLayout.LayoutParams fullscreenParams = new FrameLayout.LayoutParams(
                dp(82),
                dp(44),
                Gravity.TOP | Gravity.END);
        fullscreenParams.setMargins(0, dp(10), dp(14), 0);
        stage.addView(fullscreen, fullscreenParams);

        TextView outputBadge = text(
                monitoring
                        ? "JPEG实时取景 · " + monitorProfileLabel()
                        : "照片实时取景 · JPEG",
                11,
                Typeface.BOLD,
                Color.rgb(194, 200, 211));
        outputBadge.setContentDescription(
                monitoring
                        ? "实时取景格式 JPEG，监看显示尺寸 " + monitorProfileLabel()
                        : "照片实时取景格式 JPEG");
        FrameLayout.LayoutParams outputBadgeParams = new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                dp(32),
                Gravity.BOTTOM | Gravity.END);
        outputBadgeParams.setMargins(0, 0, dp(14), dp(10));
        stage.addView(outputBadge, outputBadgeParams);

        if (!monitoring) {
            stage.setLayoutParams(new LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    dp(380)));
        }
        return stage;
    }

    private void showImmersivePreview(boolean monitoring) {
        if (immersiveDialog != null && immersiveDialog.isShowing()) return;
        immersiveMonitoring = monitoring;
        immersiveLandscape =
                getResources().getConfiguration().orientation
                        == Configuration.ORIENTATION_LANDSCAPE;
        Dialog dialog = new Dialog(
                this,
                android.R.style.Theme_Black_NoTitleBar_Fullscreen);
        immersiveDialog = dialog;
        FrameLayout root = new FrameLayout(this);
        root.setBackgroundColor(Color.BLACK);

        immersivePreviewImage = new ImageView(this);
        immersivePreviewImage.setScaleType(ImageView.ScaleType.FIT_CENTER);
        immersivePreviewImage.setBackgroundColor(Color.BLACK);
        Bitmap frame = monitoring ? latestFrame : latestSourceFrame;
        if (frame != null) immersivePreviewImage.setImageBitmap(frame);
        root.addView(immersivePreviewImage, new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT));

        immersiveZebraImage = new ImageView(this);
        immersiveZebraImage.setScaleType(ImageView.ScaleType.FIT_CENTER);
        immersiveZebraImage.setImageBitmap(
                monitoring && zebraEnabled ? latestZebraMask : null);
        root.addView(immersiveZebraImage, new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT));

        root.addView(
                immersiveFocusReticle(),
                new FrameLayout.LayoutParams(dp(84), dp(84), Gravity.CENTER));

        immersiveChrome = new FrameLayout(this);
        root.addView(immersiveChrome, new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT));
        buildImmersiveChrome(dialog);

        dialog.setContentView(root);
        dialog.setOnDismissListener(ignored -> {
            stopImmersiveOrientationTracking();
            if (immersiveDialog == dialog) {
                immersiveDialog = null;
                immersiveChrome = null;
                immersivePreviewImage = null;
                immersiveZebraImage = null;
                immersiveRecordButton = null;
                immersiveExposureText = null;
            }
        });
        dialog.setOnShowListener(ignored -> {
            Window window = dialog.getWindow();
            if (window != null) {
                window.getDecorView().setSystemUiVisibility(
                        View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                                | View.SYSTEM_UI_FLAG_FULLSCREEN
                                | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                                | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                                | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                                | View.SYSTEM_UI_FLAG_LAYOUT_STABLE);
            }
        });
        dialog.show();
        startImmersiveOrientationTracking();
    }

    private void buildImmersiveChrome(Dialog dialog) {
        FrameLayout chrome = immersiveChrome;
        if (chrome == null) return;
        chrome.removeAllViews();
        immersiveRecordButton = null;
        immersiveExposureText = null;

        Button close = nativeButton("⌂", false);
        close.setTextSize(22);
        close.setTextColor(Color.WHITE);
        close.setContentDescription(tr("退出全屏"));
        close.setBackground(rounded(Color.argb(175, 0, 0, 0), 12, 0));
        close.setOnClickListener(view -> closeImmersivePreview(dialog));
        FrameLayout.LayoutParams closeParams = new FrameLayout.LayoutParams(
                dp(52),
                dp(52),
                Gravity.TOP | Gravity.START);
        closeParams.setMargins(dp(16), dp(18), 0, 0);
        chrome.addView(close, closeParams);

        TextView device = text(
                (liveViewEnabled ? "● LIVE · " : "● NO SOURCE · ")
                        + connectedCameraName,
                11,
                Typeface.BOLD,
                Color.WHITE);
        device.setGravity(Gravity.CENTER);
        device.setMaxLines(1);
        device.setBackground(rounded(Color.argb(155, 0, 0, 0), 22, 0));
        FrameLayout.LayoutParams deviceParams = new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                dp(44),
                Gravity.TOP | Gravity.CENTER_HORIZONTAL);
        deviceParams.setMargins(0, dp(22), 0, 0);
        chrome.addView(device, deviceParams);

        TextView transport = text(
                "USB/PTP · "
                        + (immersiveMonitoring ? monitorFrameRate + "P" : "JPEG"),
                11,
                Typeface.BOLD,
                Color.WHITE);
        transport.setGravity(Gravity.CENTER);
        transport.setBackground(rounded(Color.argb(155, 0, 0, 0), 22, 0));
        FrameLayout.LayoutParams transportParams = new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                dp(44),
                Gravity.TOP | Gravity.END);
        transportParams.setMargins(0, dp(22), dp(16), 0);
        chrome.addView(transport, transportParams);

        if (immersiveLandscape) {
            addLandscapeImmersiveControls(chrome);
        } else {
            addPortraitImmersiveControls(chrome);
        }
    }

    private void addLandscapeImmersiveControls(FrameLayout chrome) {
        LinearLayout leftRail = immersiveToolRail();
        FrameLayout.LayoutParams leftParams = new FrameLayout.LayoutParams(
                dp(76),
                ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.START | Gravity.CENTER_VERTICAL);
        leftParams.setMargins(dp(16), dp(36), 0, dp(36));
        chrome.addView(leftRail, leftParams);

        LinearLayout rightRail = immersiveCaptureRail(true);
        FrameLayout.LayoutParams rightParams = new FrameLayout.LayoutParams(
                dp(112),
                ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.END | Gravity.CENTER_VERTICAL);
        rightParams.setMargins(0, dp(36), dp(16), dp(36));
        chrome.addView(rightRail, rightParams);

        addImmersiveReadoutAndParameters(chrome, dp(74), dp(138), dp(22));
    }

    private void addPortraitImmersiveControls(FrameLayout chrome) {
        LinearLayout leftRail = immersiveToolRail();
        FrameLayout.LayoutParams leftParams = new FrameLayout.LayoutParams(
                dp(72),
                ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.START | Gravity.CENTER_VERTICAL);
        leftParams.setMargins(dp(14), dp(64), 0, dp(176));
        chrome.addView(leftRail, leftParams);

        LinearLayout bottomControls = immersiveCaptureRail(false);
        FrameLayout.LayoutParams bottomParams = new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                dp(104),
                Gravity.BOTTOM | Gravity.CENTER_HORIZONTAL);
        bottomParams.setMargins(dp(14), 0, dp(14), dp(12));
        chrome.addView(bottomControls, bottomParams);

        addImmersiveReadoutAndParameters(chrome, dp(176), dp(240), dp(122));
    }

    private LinearLayout immersiveToolRail() {
        LinearLayout rail = new LinearLayout(this);
        rail.setOrientation(LinearLayout.VERTICAL);
        rail.setGravity(Gravity.CENTER);
        rail.addView(
                immersiveReadout(
                        immersiveMonitoring
                                ? monitorFrameRate + "P"
                                : exposureMode.toUpperCase(Locale.ROOT),
                        64,
                        56));

        Button live = nativeButton(liveViewEnabled ? "LIVE" : "取景", false);
        live.setTextColor(Color.WHITE);
        live.setBackground(rounded(
                liveViewEnabled
                        ? Color.argb(185, 150, 16, 28)
                        : Color.argb(175, 0, 0, 0),
                12,
                0));
        live.setOnClickListener(view -> toggleLiveView());
        LinearLayout.LayoutParams liveParams =
                new LinearLayout.LayoutParams(dp(64), dp(52));
        liveParams.setMargins(0, dp(10), 0, 0);
        rail.addView(live, liveParams);

        if (immersiveMonitoring) {
            Button peaking = nativeButton("峰值", false);
            peaking.setTextColor(Color.WHITE);
            peaking.setBackground(rounded(
                    focusPeakingEnabled
                            ? Color.argb(200, 5, 90, 210)
                            : Color.argb(175, 0, 0, 0),
                    12,
                    0));
            peaking.setOnClickListener(view -> {
                focusPeakingEnabled = !focusPeakingEnabled;
                buildImmersiveChrome(immersiveDialog);
            });
            LinearLayout.LayoutParams peakingParams =
                    new LinearLayout.LayoutParams(dp(64), dp(52));
            peakingParams.setMargins(0, dp(10), 0, 0);
            rail.addView(peaking, peakingParams);
        }
        return rail;
    }

    private LinearLayout immersiveCaptureRail(boolean vertical) {
        LinearLayout rail = new LinearLayout(this);
        rail.setOrientation(vertical ? LinearLayout.VERTICAL : LinearLayout.HORIZONTAL);
        rail.setGravity(Gravity.CENTER);
        TextView section = text(
                immersiveMonitoring ? "视频" : "照片",
                17,
                Typeface.BOLD,
                immersiveMonitoring
                        ? Color.rgb(245, 52, 65)
                        : Color.rgb(85, 155, 255));
        section.setGravity(Gravity.CENTER);
        rail.addView(section, new LinearLayout.LayoutParams(
                vertical ? dp(104) : dp(72),
                vertical ? dp(42) : dp(72)));

        Button capture = nativeButton(
                immersiveMonitoring
                        ? (videoRecording ? "■" : "●")
                        : "●",
                true);
        capture.setTextSize(videoRecording ? 26 : 34);
        capture.setTextColor(Color.WHITE);
        capture.setContentDescription(tr(
                immersiveMonitoring
                        ? (videoRecording ? "停止录制" : "开始录制")
                        : "拍摄"));
        capture.setBackground(rounded(
                immersiveMonitoring ? VIDEO : COBALT,
                48,
                0));
        capture.setEnabled(connected && !capturing);
        capture.setOnClickListener(view -> {
            if (immersiveMonitoring) {
                toggleVideoRecording();
            } else {
                capturePhoto();
            }
        });
        if (immersiveMonitoring) immersiveRecordButton = capture;
        LinearLayout.LayoutParams captureParams =
                new LinearLayout.LayoutParams(dp(96), dp(96));
        if (vertical) {
            captureParams.setMargins(0, dp(6), 0, 0);
        } else {
            captureParams.setMargins(dp(10), 0, dp(10), 0);
        }
        rail.addView(capture, captureParams);

        TextView state = text(
                immersiveMonitoring
                        ? (videoRecording ? "REC" : "待机")
                        : "JPEG",
                12,
                Typeface.BOLD,
                Color.WHITE);
        state.setGravity(Gravity.CENTER);
        state.setBackground(rounded(Color.argb(175, 0, 0, 0), 10, 0));
        rail.addView(state, new LinearLayout.LayoutParams(
                vertical ? dp(76) : dp(64),
                vertical ? dp(44) : dp(64)));
        return rail;
    }

    private void addImmersiveReadoutAndParameters(
            FrameLayout chrome,
            int parameterBottom,
            int toggleBottom,
            int readoutBottom) {
        TextView exposure = text("", 13, Typeface.BOLD, Color.WHITE);
        exposure.setGravity(Gravity.CENTER);
        exposure.setBackground(rounded(Color.argb(175, 0, 0, 0), 22, 0));
        FrameLayout.LayoutParams exposureParams = new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                dp(44),
                Gravity.BOTTOM | Gravity.CENTER_HORIZONTAL);
        exposureParams.setMargins(0, 0, 0, readoutBottom);
        chrome.addView(exposure, exposureParams);
        immersiveExposureText = exposure;
        updateImmersiveExposureText();

        String[] primaryParameters = immersiveMonitoring
                ? new String[]{"角度", "光圈", "ISO", "补偿"}
                : new String[]{"快门", "光圈", "ISO", "补偿"};
        String[] moreParameters = immersiveMonitoring
                ? new String[]{"帧率", "对焦", "白平衡", "优化"}
                : new String[]{"模式", "对焦", "白平衡", "优化"};
        HorizontalScrollView primaryScroller =
                immersiveParameterScroller(primaryParameters);
        HorizontalScrollView moreScroller =
                immersiveParameterScroller(moreParameters);
        moreScroller.setVisibility(
                immersiveMoreParametersExpanded
                        ? View.VISIBLE
                        : View.GONE);

        LinearLayout tray = new LinearLayout(this);
        tray.setOrientation(LinearLayout.VERTICAL);
        tray.setGravity(Gravity.CENTER);
        LinearLayout actions = new LinearLayout(this);
        actions.setOrientation(LinearLayout.HORIZONTAL);
        actions.setGravity(Gravity.CENTER);

        Button toggle = nativeButton(
                immersiveParametersExpanded ? "收起参数" : "展开参数",
                false);
        toggle.setTextColor(Color.WHITE);
        toggle.setBackground(rounded(Color.argb(175, 0, 0, 0), 10, 0));
        toggle.setOnClickListener(view -> {
            immersiveParametersExpanded = !immersiveParametersExpanded;
            primaryScroller.setVisibility(
                    immersiveParametersExpanded
                            ? View.VISIBLE
                            : View.GONE);
            moreScroller.setVisibility(
                    immersiveParametersExpanded
                            && immersiveMoreParametersExpanded
                            ? View.VISIBLE
                            : View.GONE);
            toggle.setText(tr(
                    immersiveParametersExpanded
                            ? "收起参数"
                            : "展开参数"));
        });
        actions.addView(
                toggle,
                new LinearLayout.LayoutParams(dp(96), dp(44)));

        Button more = nativeButton(
                immersiveMoreParametersExpanded ? "收起更多" : "更多参数",
                false);
        more.setTextColor(Color.WHITE);
        more.setBackground(rounded(
                immersiveMoreParametersExpanded
                        ? Color.argb(205, 5, 90, 210)
                        : Color.argb(175, 0, 0, 0),
                10,
                0));
        more.setOnClickListener(view -> {
            immersiveMoreParametersExpanded =
                    !immersiveMoreParametersExpanded;
            moreScroller.setVisibility(
                    immersiveParametersExpanded
                            && immersiveMoreParametersExpanded
                            ? View.VISIBLE
                            : View.GONE);
            more.setText(tr(
                    immersiveMoreParametersExpanded
                            ? "收起更多"
                            : "更多参数"));
            more.setBackground(rounded(
                    immersiveMoreParametersExpanded
                            ? Color.argb(205, 5, 90, 210)
                            : Color.argb(175, 0, 0, 0),
                    10,
                    0));
        });
        LinearLayout.LayoutParams moreParams =
                new LinearLayout.LayoutParams(dp(96), dp(44));
        moreParams.setMargins(dp(8), 0, 0, 0);
        actions.addView(more, moreParams);
        tray.addView(actions);
        tray.addView(primaryScroller);
        tray.addView(moreScroller);
        primaryScroller.setVisibility(
                immersiveParametersExpanded
                        ? View.VISIBLE
                        : View.GONE);

        FrameLayout.LayoutParams parameterParams = new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.BOTTOM);
        parameterParams.setMargins(0, 0, 0, parameterBottom);
        chrome.addView(tray, parameterParams);
    }

    private HorizontalScrollView immersiveParameterScroller(
            String[] parameters) {
        LinearLayout parameterBar = new LinearLayout(this);
        parameterBar.setOrientation(LinearLayout.HORIZONTAL);
        parameterBar.setGravity(Gravity.CENTER);
        for (String parameter : parameters) {
            parameterBar.addView(immersiveParameterStepper(parameter));
        }
        HorizontalScrollView scroller = new HorizontalScrollView(this);
        scroller.setHorizontalScrollBarEnabled(false);
        scroller.setFillViewport(true);
        scroller.setPadding(
                immersiveLandscape ? dp(104) : dp(12),
                dp(4),
                immersiveLandscape ? dp(104) : dp(12),
                0);
        scroller.addView(parameterBar);
        return scroller;
    }

    private TextView immersiveReadout(String value, int width, int height) {
        TextView readout = text(value, 18, Typeface.BOLD, Color.WHITE);
        readout.setGravity(Gravity.CENTER);
        readout.setBackground(rounded(Color.argb(175, 0, 0, 0), 12, 0));
        readout.setLayoutParams(
                new LinearLayout.LayoutParams(dp(width), dp(height)));
        return readout;
    }

    private View immersiveFocusReticle() {
        Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
        paint.setColor(Color.argb(205, 255, 214, 70));
        paint.setStrokeWidth(dp(2));
        paint.setStyle(Paint.Style.STROKE);
        return new View(this) {
            @Override
            protected void onDraw(Canvas canvas) {
                super.onDraw(canvas);
                float inset = dp(4);
                float arm = dp(18);
                float right = getWidth() - inset;
                float bottom = getHeight() - inset;
                canvas.drawLine(inset, inset, inset + arm, inset, paint);
                canvas.drawLine(inset, inset, inset, inset + arm, paint);
                canvas.drawLine(right, inset, right - arm, inset, paint);
                canvas.drawLine(right, inset, right, inset + arm, paint);
                canvas.drawLine(inset, bottom, inset + arm, bottom, paint);
                canvas.drawLine(inset, bottom, inset, bottom - arm, paint);
                canvas.drawLine(right, bottom, right - arm, bottom, paint);
                canvas.drawLine(right, bottom, right, bottom - arm, paint);
            }
        };
    }

    private void startImmersiveOrientationTracking() {
        immersiveSensorManager =
                (SensorManager) getSystemService(Context.SENSOR_SERVICE);
        if (immersiveSensorManager == null) return;
        immersiveRotationSensor =
                immersiveSensorManager.getDefaultSensor(
                        Sensor.TYPE_ROTATION_VECTOR);
        if (immersiveRotationSensor != null) {
            immersiveSensorManager.registerListener(
                    immersiveOrientationListener,
                    immersiveRotationSensor,
                    SensorManager.SENSOR_DELAY_UI);
        }
    }

    private void stopImmersiveOrientationTracking() {
        if (immersiveSensorManager != null) {
            immersiveSensorManager.unregisterListener(
                    immersiveOrientationListener);
        }
        immersiveSensorManager = null;
        immersiveRotationSensor = null;
    }

    private void showImmersivePreviewLegacy(boolean monitoring) {
        if (immersiveDialog != null && immersiveDialog.isShowing()) return;
        immersiveMonitoring = monitoring;
        Dialog dialog = new Dialog(
                this,
                android.R.style.Theme_Black_NoTitleBar_Fullscreen);
        immersiveDialog = dialog;
        FrameLayout root = new FrameLayout(this);
        root.setBackgroundColor(Color.BLACK);

        immersivePreviewImage = new ImageView(this);
        immersivePreviewImage.setScaleType(ImageView.ScaleType.FIT_CENTER);
        immersivePreviewImage.setBackgroundColor(Color.BLACK);
        Bitmap frame = monitoring ? latestFrame : latestSourceFrame;
        if (frame != null) immersivePreviewImage.setImageBitmap(frame);
        root.addView(immersivePreviewImage, new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT));

        immersiveZebraImage = new ImageView(this);
        immersiveZebraImage.setScaleType(ImageView.ScaleType.FIT_CENTER);
        immersiveZebraImage.setImageBitmap(
                monitoring && zebraEnabled ? latestZebraMask : null);
        root.addView(immersiveZebraImage, new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT));

        Button close = nativeButton("⌄ 退出全屏", false);
        close.setTextColor(Color.WHITE);
        close.setBackground(rounded(Color.argb(165, 0, 0, 0), 12, 0));
        close.setOnClickListener(view -> closeImmersivePreview(dialog));
        FrameLayout.LayoutParams closeParams =
                new FrameLayout.LayoutParams(
                        dp(126),
                        dp(48),
                        Gravity.TOP | Gravity.START);
        closeParams.setMargins(dp(18), dp(24), 0, 0);
        root.addView(close, closeParams);

        TextView device = text(
                (liveViewEnabled ? "● LIVE · " : "● NO SOURCE · ")
                        + connectedCameraName,
                11,
                Typeface.BOLD,
                Color.WHITE);
        device.setGravity(Gravity.CENTER);
        device.setBackground(rounded(Color.argb(150, 0, 0, 0), 22, 0));
        FrameLayout.LayoutParams deviceParams =
                new FrameLayout.LayoutParams(
                        ViewGroup.LayoutParams.WRAP_CONTENT,
                        dp(44),
                        Gravity.TOP | Gravity.CENTER_HORIZONTAL);
        deviceParams.setMargins(0, dp(26), 0, 0);
        root.addView(device, deviceParams);

        LinearLayout leftRail = new LinearLayout(this);
        leftRail.setOrientation(LinearLayout.VERTICAL);
        leftRail.setGravity(Gravity.CENTER);
        TextView mode = text(
                monitoring ? monitorFrameRate + "P" : exposureMode.toUpperCase(Locale.ROOT),
                18,
                Typeface.BOLD,
                Color.WHITE);
        mode.setGravity(Gravity.CENTER);
        mode.setBackground(rounded(Color.argb(155, 0, 0, 0), 12, 0));
        leftRail.addView(mode, new LinearLayout.LayoutParams(dp(64), dp(56)));
        TextView protocol = text("USB\nPTP", 11, Typeface.BOLD, Color.WHITE);
        protocol.setGravity(Gravity.CENTER);
        protocol.setBackground(rounded(Color.argb(155, 0, 0, 0), 12, 0));
        LinearLayout.LayoutParams protocolParams =
                new LinearLayout.LayoutParams(dp(64), dp(56));
        protocolParams.setMargins(0, dp(12), 0, 0);
        leftRail.addView(protocol, protocolParams);
        FrameLayout.LayoutParams leftParams =
                new FrameLayout.LayoutParams(
                        dp(72),
                        ViewGroup.LayoutParams.WRAP_CONTENT,
                        Gravity.START | Gravity.CENTER_VERTICAL);
        leftParams.setMargins(dp(18), 0, 0, 0);
        root.addView(leftRail, leftParams);

        LinearLayout rightRail = new LinearLayout(this);
        rightRail.setOrientation(LinearLayout.VERTICAL);
        rightRail.setGravity(Gravity.CENTER);
        TextView section = text(
                monitoring ? "视频" : "照片",
                17,
                Typeface.BOLD,
                monitoring ? Color.rgb(235, 40, 55) : Color.rgb(72, 145, 255));
        section.setGravity(Gravity.CENTER);
        rightRail.addView(section, new LinearLayout.LayoutParams(dp(92), dp(44)));
        Button capture = nativeButton(
                monitoring
                        ? (videoRecording ? "■\n停止" : "●\n录制")
                        : "●\n拍摄",
                true);
        capture.setTextSize(15);
        capture.setTextColor(Color.WHITE);
        capture.setBackground(rounded(
                monitoring ? VIDEO : COBALT,
                48,
                0));
        capture.setOnClickListener(view -> {
            if (monitoring) {
                toggleVideoRecording();
            } else {
                capturePhoto();
            }
        });
        if (monitoring) {
            immersiveRecordButton = capture;
        }
        LinearLayout.LayoutParams captureParams =
                new LinearLayout.LayoutParams(dp(96), dp(96));
        captureParams.setMargins(0, dp(8), 0, 0);
        rightRail.addView(capture, captureParams);
        FrameLayout.LayoutParams rightParams =
                new FrameLayout.LayoutParams(
                        dp(104),
                        ViewGroup.LayoutParams.WRAP_CONTENT,
                        Gravity.END | Gravity.CENTER_VERTICAL);
        rightParams.setMargins(0, 0, dp(18), 0);
        root.addView(rightRail, rightParams);

        TextView exposure = text(
                monitoring
                        ? String.format(
                                Locale.CHINA,
                                "%.1f°   %d fps   JPEG",
                                monitorShutterAngle,
                                monitorFrameRate)
                        : "M   JPEG   帧澈 ZENCHE",
                13,
                Typeface.BOLD,
                Color.WHITE);
        exposure.setGravity(Gravity.CENTER);
        exposure.setBackground(rounded(Color.argb(160, 0, 0, 0), 22, 0));
        FrameLayout.LayoutParams exposureParams =
                new FrameLayout.LayoutParams(
                        ViewGroup.LayoutParams.WRAP_CONTENT,
                        dp(44),
                        Gravity.BOTTOM | Gravity.CENTER_HORIZONTAL);
        exposureParams.setMargins(0, 0, 0, dp(24));
        root.addView(exposure, exposureParams);
        immersiveExposureText = exposure;

        LinearLayout parameterBar = new LinearLayout(this);
        parameterBar.setOrientation(LinearLayout.HORIZONTAL);
        parameterBar.setGravity(Gravity.CENTER);
        if (monitoring) {
            parameterBar.addView(immersiveParameterStepper("角度"));
            parameterBar.addView(immersiveParameterStepper("帧率"));
            parameterBar.addView(immersiveParameterStepper("光圈"));
            parameterBar.addView(immersiveParameterStepper("ISO"));
            parameterBar.addView(immersiveParameterStepper("白平衡"));
            parameterBar.addView(immersiveParameterStepper("优化"));
        } else {
            parameterBar.addView(immersiveParameterStepper("模式"));
            parameterBar.addView(immersiveParameterStepper("快门"));
            parameterBar.addView(immersiveParameterStepper("光圈"));
            parameterBar.addView(immersiveParameterStepper("ISO"));
            parameterBar.addView(immersiveParameterStepper("补偿"));
            parameterBar.addView(immersiveParameterStepper("对焦"));
            parameterBar.addView(immersiveParameterStepper("白平衡"));
            parameterBar.addView(immersiveParameterStepper("优化"));
        }
        HorizontalScrollView parameterScroller = new HorizontalScrollView(this);
        parameterScroller.setHorizontalScrollBarEnabled(false);
        parameterScroller.setFillViewport(true);
        parameterScroller.setPadding(dp(104), 0, dp(104), 0);
        parameterScroller.addView(parameterBar);
        FrameLayout.LayoutParams parameterParams =
                new FrameLayout.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT,
                        dp(64),
                        Gravity.BOTTOM);
        parameterParams.setMargins(0, 0, 0, dp(76));
        root.addView(parameterScroller, parameterParams);
        Button parameterToggle = nativeButton("参数⌄", false);
        parameterToggle.setTextColor(Color.WHITE);
        parameterToggle.setBackground(rounded(Color.argb(165, 0, 0, 0), 10, 0));
        parameterToggle.setOnClickListener(view -> {
            boolean show = parameterScroller.getVisibility() != View.VISIBLE;
            parameterScroller.setVisibility(show ? View.VISIBLE : View.GONE);
            parameterToggle.setText(tr(show ? "参数⌄" : "参数⌃"));
        });
        FrameLayout.LayoutParams toggleParams =
                new FrameLayout.LayoutParams(
                        dp(96),
                        dp(44),
                        Gravity.BOTTOM | Gravity.CENTER_HORIZONTAL);
        toggleParams.setMargins(0, 0, 0, dp(144));
        root.addView(parameterToggle, toggleParams);

        dialog.setContentView(root);
        dialog.setOnDismissListener(ignored -> {
            if (immersiveDialog == dialog) {
                immersiveDialog = null;
                immersivePreviewImage = null;
                immersiveZebraImage = null;
                immersiveRecordButton = null;
                immersiveExposureText = null;
            }
        });
        dialog.setOnShowListener(ignored -> {
            Window window = dialog.getWindow();
            if (window != null) {
                window.getDecorView().setSystemUiVisibility(
                        View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                                | View.SYSTEM_UI_FLAG_FULLSCREEN
                                | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                                | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                                | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                                | View.SYSTEM_UI_FLAG_LAYOUT_STABLE);
            }
        });
        dialog.show();
    }

    private void closeImmersivePreview(Dialog dialog) {
        if (immersiveDialog != dialog) return;
        stopImmersiveOrientationTracking();
        immersiveDialog = null;
        immersiveChrome = null;
        immersivePreviewImage = null;
        immersiveZebraImage = null;
        immersiveRecordButton = null;
        immersiveExposureText = null;
        dialog.dismiss();
    }

    private View immersiveParameterStepper(String parameter) {
        LinearLayout group = new LinearLayout(this);
        group.setOrientation(LinearLayout.HORIZONTAL);
        group.setGravity(Gravity.CENTER);
        group.setPadding(dp(4), dp(4), dp(4), dp(4));
        group.setBackground(rounded(Color.argb(165, 0, 0, 0), 10, 0));
        Button minus = nativeButton("−", false);
        TextView value = text(
                immersiveParameterValue(parameter),
                10,
                Typeface.BOLD,
                Color.WHITE);
        value.setGravity(Gravity.CENTER);
        Button plus = nativeButton("+", false);
        String cameraParameter = immersiveCameraParameter(parameter);
        boolean adjustable = connected
                && (cameraParameter == null || camera.isParameterWritable(cameraParameter));
        minus.setEnabled(adjustable);
        plus.setEnabled(adjustable);
        group.setAlpha(adjustable ? 1f : 0.48f);
        if (!adjustable && cameraParameter != null) {
            String reason = camera.parameterLockReason(cameraParameter);
            group.setContentDescription(
                    parameter + "不可调整" + (reason == null ? "" : "：" + reason));
        }
        minus.setOnClickListener(view -> {
            adjustImmersiveParameter(parameter, -1);
            value.setText(immersiveParameterValue(parameter));
        });
        plus.setOnClickListener(view -> {
            adjustImmersiveParameter(parameter, 1);
            value.setText(immersiveParameterValue(parameter));
        });
        group.addView(minus, new LinearLayout.LayoutParams(dp(44), dp(44)));
        group.addView(value, new LinearLayout.LayoutParams(dp(60), dp(44)));
        group.addView(plus, new LinearLayout.LayoutParams(dp(44), dp(44)));
        LinearLayout.LayoutParams params =
                new LinearLayout.LayoutParams(dp(152), dp(52));
        params.setMargins(dp(3), 0, dp(3), 0);
        group.setLayoutParams(params);
        return group;
    }

    private String immersiveParameterValue(String parameter) {
        switch (parameter) {
            case "角度":
                return String.format(Locale.CHINA, "角度\n%.1f°", monitorShutterAngle);
            case "帧率":
                return "帧率\n" + monitorFrameRate + "p";
            case "快门":
                return currentShutterSeconds < 1
                        ? "快门\n1/" + Math.round(1 / currentShutterSeconds)
                        : String.format(Locale.CHINA, "快门\n%.1fs", currentShutterSeconds);
            case "光圈":
                return String.format(Locale.CHINA, "光圈\nF%.1f", currentAperture);
            case "模式":
                return "模式\n" + exposureMode.toUpperCase(Locale.ROOT);
            case "补偿":
                return String.format(
                        Locale.CHINA,
                        "补偿\n%+.1f EV",
                        currentCompensation);
            case "对焦":
                return "对焦\n"
                        + ("continuous".equals(currentFocusMode)
                        ? "AF-C"
                        : "AF-S");
            case "白平衡":
                return "白平衡\n"
                        + ("continuous".equals(currentWhiteBalance)
                        ? "自动"
                        : "保留");
            case "优化":
                return "优化\n"
                        + ("neutral".equals(currentPictureControl)
                        ? "自然"
                        : "标准");
            default:
                return "ISO\n" + currentIso;
        }
    }

    private void adjustImmersiveParameter(String parameter, int direction) {
        if (!connected || capturing) return;
        if ("角度".equals(parameter)) {
            double[] values = new double[]{
                    45, 60, 72, 90, 108, 120, 144, 150, 172.8, 180,
                    216, 240, 270, 300, 324, 360
            };
            monitorShutterAngle = adjacentValue(values, monitorShutterAngle, direction);
            applyVideoShutterAngle();
        } else if ("帧率".equals(parameter)) {
            int[] values = new int[]{24, 25, 30, 50, 60};
            monitorFrameRate = adjacentValue(values, monitorFrameRate, direction);
            applyVideoShutterAngle();
        } else if ("快门".equals(parameter)) {
            double[] values = fineShutterValues();
            currentShutterSeconds =
                    adjacentValue(values, currentShutterSeconds, direction);
            applyParameter("exposureTime", currentShutterSeconds, "快门速度");
        } else if ("光圈".equals(parameter)) {
            double[] values = fineApertureValues();
            currentAperture = adjacentValue(values, currentAperture, direction);
            applyParameter("aperture", currentAperture, "光圈");
        } else if ("模式".equals(parameter)) {
            String[] values = new String[]{
                    "program", "shutterPriority", "aperturePriority", "manual", "bulb"
            };
            int index = adjacentIndex(values, exposureMode, direction);
            exposureMode = values[index];
            applyParameter("exposureMode", values[index], "拍摄模式");
        } else if ("补偿".equals(parameter)) {
            currentCompensation = Math.max(
                    -5,
                    Math.min(5, currentCompensation + direction / 3.0));
            applyParameter(
                    "exposureCompensation",
                    currentCompensation,
                    "曝光补偿");
        } else if ("对焦".equals(parameter)) {
            currentFocusMode =
                    direction < 0 ? "single-shot" : "continuous";
            applyParameter(
                    "focusMode",
                    currentFocusMode,
                    "对焦模式");
        } else if ("白平衡".equals(parameter)) {
            currentWhiteBalance =
                    direction < 0 ? "continuous" : "preserve";
            applyParameter(
                    "whiteBalanceMode",
                    currentWhiteBalance,
                    "白平衡");
        } else if ("优化".equals(parameter)) {
            currentPictureControl =
                    direction < 0 ? "neutral" : "standard";
            applyParameter(
                    "pictureControl",
                    currentPictureControl,
                    "优化校准");
        } else {
            Object[] supported = isoValues();
            if (supported.length == 0) return;
            int index = 0;
            for (int candidate = 1; candidate < supported.length; candidate++) {
                if (Math.abs(((Number) supported[candidate]).intValue() - currentIso)
                        < Math.abs(((Number) supported[index]).intValue() - currentIso)) {
                    index = candidate;
                }
            }
            index = Math.max(0, Math.min(supported.length - 1, index + direction));
            currentIso = ((Number) supported[index]).intValue();
            applyParameter("iso", currentIso, "ISO 感光度");
        }
        updateImmersiveExposureText();
    }

    private String immersiveCameraParameter(String parameter) {
        switch (parameter) {
            case "角度":
            case "帧率": return "videoExposureTime";
            case "快门": return "exposureTime";
            case "光圈": return "aperture";
            case "ISO": return "iso";
            case "模式": return "exposureMode";
            case "补偿": return "exposureCompensation";
            case "对焦": return "focusMode";
            case "白平衡": return "whiteBalanceMode";
            case "优化": return "pictureControl";
            default: return null;
        }
    }

    private int adjacentIndex(String[] values, String current, int direction) {
        int index = 0;
        for (int candidate = 0; candidate < values.length; candidate++) {
            if (values[candidate].equals(current)) {
                index = candidate;
                break;
            }
        }
        return Math.max(0, Math.min(values.length - 1, index + direction));
    }

    private double[] fineShutterValues() {
        return new double[]{
                1.0 / 8000, 1.0 / 6400, 1.0 / 5000, 1.0 / 4000,
                1.0 / 3200, 1.0 / 2500, 1.0 / 2000, 1.0 / 1600,
                1.0 / 1250, 1.0 / 1000, 1.0 / 800, 1.0 / 640,
                1.0 / 500, 1.0 / 400, 1.0 / 320, 1.0 / 250,
                1.0 / 200, 1.0 / 160, 1.0 / 125, 1.0 / 100,
                1.0 / 80, 1.0 / 60, 1.0 / 50, 1.0 / 40,
                1.0 / 30, 1.0 / 25, 1.0 / 20, 1.0 / 15,
                1.0 / 13, 1.0 / 10, 1.0 / 8, 1.0 / 6,
                1.0 / 5, 1.0 / 4, 1.0 / 3, 1.0 / 2,
                1, 1.3, 1.6, 2, 2.5, 3.2, 4, 5, 6, 8,
                10, 13, 15, 20, 25, 30
        };
    }

    private double[] fineApertureValues() {
        return new double[]{
                1.2, 1.4, 1.6, 1.8, 2, 2.2, 2.5, 2.8, 3.2, 3.5,
                4, 4.5, 5, 5.6, 6.3, 7.1, 8, 9, 10, 11, 13, 14,
                16, 18, 20, 22
        };
    }

    private double adjacentValue(double[] values, double current, int direction) {
        int index = 0;
        for (int candidate = 1; candidate < values.length; candidate++) {
            if (Math.abs(values[candidate] - current)
                    < Math.abs(values[index] - current)) {
                index = candidate;
            }
        }
        return values[Math.max(0, Math.min(values.length - 1, index + direction))];
    }

    private int adjacentValue(int[] values, int current, int direction) {
        int index = 0;
        for (int candidate = 1; candidate < values.length; candidate++) {
            if (Math.abs(values[candidate] - current)
                    < Math.abs(values[index] - current)) {
                index = candidate;
            }
        }
        return values[Math.max(0, Math.min(values.length - 1, index + direction))];
    }

    private void updateImmersiveExposureText() {
        if (immersiveExposureText == null) return;
        immersiveExposureText.setText(
                immersiveMonitoring
                        ? String.format(
                                Locale.CHINA,
                                "%.1f°   %d fps   ISO %d",
                                monitorShutterAngle,
                                monitorFrameRate,
                                currentIso)
                        : String.format(
                                Locale.CHINA,
                                "%s   F%.1f   ISO %d",
                                exposureMode.toUpperCase(Locale.ROOT),
                                currentAperture,
                                currentIso));
    }

    private View buildMonitorParameterControls() {
        LinearLayout panel = panel();
        panel.addView(text("参数调节", 18, Typeface.BOLD, INK));
        panel.addView(text(
                connected
                        ? "曝光三要素通过 USB/PTP 写入 " + connectedCameraName
                        : "连接 Nikon 相机后启用参数控制",
                13,
                Typeface.NORMAL,
                MUTED),
                marginParams(-1, -2, 0, 3, 0, 14));

        addVideoFrameRateControl(panel);
        addShutterAngleControl(panel);
        addSpinnerControl(
                panel,
                "光圈",
                new String[]{"F1.4", "F2.0", "F2.8", "F4.0", "F5.6", "F8", "F11", "F16", "F22"},
                new Object[]{1.4, 2.0, 2.8, 4.0, 5.6, 8.0, 11.0, 16.0, 22.0},
                3,
                "aperture");
        addSpinnerControl(
                panel,
                "ISO 感光度",
                isoLabels(),
                isoValues(),
                defaultIsoIndex(),
                "iso");
        addSpinnerControl(
                panel,
                "白平衡",
                new String[]{"自动", "手动预设"},
                new Object[]{"continuous", "manual"},
                0,
                "whiteBalanceMode");

        TextView compensationLabel = text("曝光补偿 · 0.0 EV", 13, Typeface.BOLD, MUTED);
        compensationLabel.setTag("曝光补偿");
        panel.addView(compensationLabel, marginParams(-1, -2, 0, 12, 0, 2));
        SeekBar compensation = new SeekBar(this);
        compensation.setMax(30);
        compensation.setProgress(15);
        compensation.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
            @Override
            public void onProgressChanged(SeekBar seekBar, int progress, boolean fromUser) {
                double value = (progress - 15) / 3.0;
                compensationLabel.setText(tr(String.format(
                        Locale.CHINA,
                        "曝光补偿 · %+.1f EV",
                        value)));
            }

            @Override public void onStartTrackingTouch(SeekBar seekBar) {}

            @Override
            public void onStopTrackingTouch(SeekBar seekBar) {
                double value = (seekBar.getProgress() - 15) / 3.0;
                applyParameter("exposureCompensation", value, "曝光补偿");
            }
        });
        cameraControls.add(compensation);
        parameterControls.put("exposureCompensation", compensation);
        parameterLabels.put("exposureCompensation", compensationLabel);
        panel.addView(compensation);
        return panel;
    }

    private View buildMonitorOutputControls() {
        LinearLayout panel = panel();
        panel.addView(text("监看输出", 18, Typeface.BOLD, INK));
        panel.addView(text(
                "本地显示处理不改变相机的视频录制设定。",
                13,
                Typeface.NORMAL,
                MUTED),
                marginParams(-1, -2, 0, 3, 0, 12));

        panel.addView(
                text("实时取景格式", 13, Typeface.BOLD, MUTED),
                marginParams(-1, -2, 0, 12, 0, 4));
        Spinner codec = monitorSpinner(new String[]{"JPEG（相机输出）"});
        codec.setEnabled(false);
        codec.setAlpha(0.56f);
        panel.addView(codec, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(48)));

        panel.addView(
                text("监看显示尺寸", 13, Typeface.BOLD, MUTED),
                marginParams(-1, -2, 0, 12, 0, 4));
        String[] profileValues = new String[]{"source", "hd720", "hd1080"};
        Spinner profile = monitorSpinner(new String[]{
                "实时取景原始尺寸",
                "1280 × 720",
                "1920 × 1080"});
        profile.setSelection(Math.max(0, Arrays.asList(profileValues).indexOf(
                monitorVideoProfile)), false);
        profile.setOnItemSelectedListener(new android.widget.AdapterView.OnItemSelectedListener() {
            private boolean initialized;

            @Override
            public void onItemSelected(
                    android.widget.AdapterView<?> parent,
                    View view,
                    int position,
                    long id) {
                if (!initialized) {
                    initialized = true;
                    return;
                }
                monitorVideoProfile = profileValues[position];
                getSharedPreferences("nikon-link", MODE_PRIVATE)
                        .edit()
                        .putString("monitorVideoProfile", monitorVideoProfile)
                        .apply();
                refreshPreviewProcessing();
                statusText.setText(
                        tr("监看显示尺寸 · ") + tr(monitorProfileLabel()));
            }

            @Override public void onNothingSelected(android.widget.AdapterView<?> parent) {}
        });
        panel.addView(profile, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(48)));

        panel.addView(text(
                "Nikon PTP 返回 JPEG 实时取景帧。显示尺寸仅处理监看画面，不等同于机身的“视频文件类型”或“画面尺寸/帧频”。",
                12,
                Typeface.NORMAL,
                MUTED),
                marginParams(-1, -2, 0, 10, 0, 0));
        addProfessionalMonitorControls(panel);
        addZebraControls(panel);
        addLutControls(panel);
        return panel;
    }

    private void addProfessionalMonitorControls(LinearLayout panel) {
        Switch peaking = new Switch(this);
        peaking.setText(tr("峰值对焦"));
        peaking.setChecked(focusPeakingEnabled);
        peaking.setOnCheckedChangeListener((button, enabled) -> {
            focusPeakingEnabled = enabled;
            refreshPreviewProcessing();
        });
        panel.addView(peaking, marginParams(-1, -2, 0, 12, 0, 0));

        Switch falseColor = new Switch(this);
        falseColor.setText(tr("假色曝光"));
        falseColor.setChecked(falseColorEnabled);
        falseColor.setOnCheckedChangeListener((button, enabled) -> {
            falseColorEnabled = enabled;
            refreshPreviewProcessing();
        });
        panel.addView(falseColor);

        LinearLayout scopes = verticalContainer();
        scopes.setPadding(dp(10), dp(10), dp(10), dp(10));
        scopes.setBackground(rounded(Color.rgb(241, 244, 249), 9, RULE));
        redHistogramText = scopeText("R", redHistogram, Color.rgb(210, 45, 52));
        greenHistogramText = scopeText("G", greenHistogram, Color.rgb(25, 145, 82));
        blueHistogramText = scopeText("B", blueHistogram, COBALT);
        waveformText = scopeText("波形", waveform, INK);
        vectorscopeText = scopeText("矢量", vectorscope, INK);
        peakingCoverageText = text(
                "峰值覆盖 · " + peakingCoverage + "%",
                11,
                Typeface.NORMAL,
                MUTED);
        scopes.addView(redHistogramText);
        scopes.addView(greenHistogramText);
        scopes.addView(blueHistogramText);
        scopes.addView(waveformText);
        scopes.addView(vectorscopeText);
        scopes.addView(peakingCoverageText);
        panel.addView(scopes, marginParams(-1, -2, 0, 10, 0, 0));
    }

    private TextView scopeText(String label, String value, int color) {
        TextView output = text(label + "  " + value, 11, Typeface.NORMAL, color);
        output.setTypeface(Typeface.MONOSPACE);
        output.setSingleLine(true);
        return output;
    }

    private View buildCaptureSessionPanel() {
        LinearLayout panel = panel();
        panel.addView(text("拍摄会话", 18, Typeface.BOLD, INK));
        panel.addView(
                text(captureWorkflow.status(), 12, Typeface.NORMAL, MUTED),
                marginParams(-1, -2, 0, 5, 0, 8));
        panel.addView(text(
                "项目文件夹 · 命名模板 · RAW + JPEG 配对 · XMP 评级 · 双目标备份 · SHA-256",
                12,
                Typeface.NORMAL,
                MUTED));
        Button action = nativeButton(
                captureWorkflow.isActive() ? "结束会话" : "配置并开始",
                true);
        action.setOnClickListener(view -> {
            if (captureWorkflow.isActive()) {
                captureWorkflow.end();
                showSection(currentSection);
            } else {
                showCaptureSessionDialog();
            }
        });
        panel.addView(action, marginParams(-1, dp(48), 0, 12, 0, 0));
        return panel;
    }

    private void showCaptureSessionDialog() {
        CaptureWorkflow.Configuration saved = captureWorkflow.configuration();
        LinearLayout form = verticalContainer();
        form.setPadding(dp(18), dp(8), dp(18), 0);
        EditText name = sessionTextField("项目名称", saved.name);
        EditText template = sessionTextField("命名模板", saved.namingTemplate);
        EditText creator = sessionTextField("创作者", saved.creator);
        EditText rights = sessionTextField("版权", saved.rights);
        EditText rating = sessionTextField("默认评级（0–5）", String.valueOf(saved.rating));
        rating.setInputType(InputType.TYPE_CLASS_NUMBER);
        CheckBox backup = new CheckBox(this);
        backup.setText(tr("双目标备份"));
        backup.setChecked(saved.dualBackupEnabled);
        form.addView(name);
        form.addView(template);
        form.addView(creator);
        form.addView(rights);
        form.addView(rating);
        form.addView(backup);
        form.addView(text(
                "支持 {session}、{date}、{counter}、{camera}",
                11,
                Typeface.NORMAL,
                MUTED));

        new AlertDialog.Builder(this)
                .setTitle(tr("拍摄会话"))
                .setView(form)
                .setNegativeButton(tr("取消"), null)
                .setPositiveButton(tr("开始会话"), (dialog, which) -> {
                    CaptureWorkflow.Configuration requested =
                            new CaptureWorkflow.Configuration();
                    requested.name = name.getText().toString();
                    requested.namingTemplate = template.getText().toString();
                    requested.creator = creator.getText().toString();
                    requested.rights = rights.getText().toString();
                    requested.rating = boundedInteger(rating, 0, 5, 0);
                    requested.dualBackupEnabled = backup.isChecked();
                    try {
                        captureWorkflow.begin(requested);
                        showSection(currentSection);
                    } catch (Exception error) {
                        showError(error.getMessage());
                    }
                })
                .show();
    }

    private EditText sessionTextField(String hint, String value) {
        EditText input = new EditText(this);
        input.setHint(tr(hint));
        input.setText(value);
        input.setSingleLine(true);
        input.setTextColor(INK);
        input.setHintTextColor(MUTED);
        input.setBackground(rounded(Color.rgb(241, 244, 249), 9, RULE));
        input.setPadding(dp(10), 0, dp(8), 0);
        input.setLayoutParams(marginParams(-1, dp(48), 0, 0, 0, 8));
        return input;
    }

    private Spinner monitorSpinner(String[] labels) {
        Spinner spinner = new Spinner(this);
        ArrayAdapter<String> adapter = new ArrayAdapter<>(
                this,
                android.R.layout.simple_spinner_item,
                Localization.translate(appLanguage, labels));
        adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
        spinner.setAdapter(adapter);
        spinner.setBackground(rounded(Color.rgb(241, 244, 249), 9, RULE));
        spinner.setPadding(dp(10), 0, dp(8), 0);
        return spinner;
    }

    private String monitorProfileLabel() {
        if ("hd720".equals(monitorVideoProfile)) return "1280×720";
        if ("hd1080".equals(monitorVideoProfile)) return "1920×1080";
        return "实时取景原始尺寸";
    }

    private void addVideoFrameRateControl(LinearLayout parent) {
        parent.addView(
                text("视频帧率基准", 13, Typeface.BOLD, MUTED),
                marginParams(-1, -2, 0, 12, 0, 4));
        Integer[] rates = new Integer[]{24, 25, 30, 50, 60};
        String[] labels = new String[]{"24p", "25p", "30p", "50p", "60p"};
        Spinner spinner = monitorSpinner(labels);
        spinner.setSelection(Math.max(0, Arrays.asList(rates).indexOf(monitorFrameRate)), false);
        spinner.setOnItemSelectedListener(new android.widget.AdapterView.OnItemSelectedListener() {
            private boolean initialized;

            @Override
            public void onItemSelected(
                    android.widget.AdapterView<?> parent,
                    View view,
                    int position,
                    long id) {
                if (!initialized) {
                    initialized = true;
                    return;
                }
                monitorFrameRate = rates[position];
                getSharedPreferences("nikon-link", MODE_PRIVATE)
                        .edit()
                        .putInt("monitorFrameRate", monitorFrameRate)
                        .apply();
                applyVideoShutterAngle();
            }

            @Override public void onNothingSelected(android.widget.AdapterView<?> parent) {}
        });
        parent.addView(spinner, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(48)));
    }

    private void addShutterAngleControl(LinearLayout parent) {
        TextView label = text(
                "快门角度 · 按 " + monitorFrameRate + "p 换算曝光时间",
                13,
                Typeface.BOLD,
                MUTED);
        label.setTag("快门角度");
        parent.addView(label, marginParams(-1, -2, 0, 12, 0, 4));
        Double[] angles = new Double[]{45.0, 90.0, 144.0, 172.8, 180.0, 270.0, 360.0};
        String[] labels = new String[]{"45°", "90°", "144°", "172.8°", "180°", "270°", "360°"};
        Spinner spinner = monitorSpinner(labels);
        int selection = 4;
        for (int index = 0; index < angles.length; index++) {
            if (Math.abs(angles[index] - monitorShutterAngle) < 0.01) {
                selection = index;
                break;
            }
        }
        spinner.setSelection(selection, false);
        spinner.setOnItemSelectedListener(new android.widget.AdapterView.OnItemSelectedListener() {
            private boolean initialized;

            @Override
            public void onItemSelected(
                    android.widget.AdapterView<?> parent,
                    View view,
                    int position,
                    long id) {
                if (!initialized) {
                    initialized = true;
                    return;
                }
                monitorShutterAngle = angles[position];
                getSharedPreferences("nikon-link", MODE_PRIVATE)
                        .edit()
                        .putLong(
                                "monitorShutterAngle",
                                Double.doubleToRawLongBits(monitorShutterAngle))
                        .apply();
                applyVideoShutterAngle();
            }

            @Override public void onNothingSelected(android.widget.AdapterView<?> parent) {}
        });
        cameraControls.add(spinner);
        parameterControls.put("videoExposureTime", spinner);
        parameterLabels.put("videoExposureTime", label);
        parent.addView(spinner, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(48)));
    }

    private void applyVideoShutterAngle() {
        double exposureSeconds = monitorShutterAngle / (360.0 * monitorFrameRate);
        applyParameter(
                "videoExposureTime",
                exposureSeconds,
                String.format(
                        Locale.CHINA,
                        "快门角度 %.1f°（%dp）",
                        monitorShutterAngle,
                        monitorFrameRate));
    }

    private View buildProfessionalControls() {
        LinearLayout panel = panel();
        panel.addView(text("相机参数", 18, Typeface.BOLD, INK));
        panel.addView(text(
                connected
                        ? "参数通过 USB/PTP 写入 " + connectedCameraName
                        : "连接相机后启用原生参数控制",
                13,
                Typeface.NORMAL,
                MUTED),
                marginParams(-1, -2, 0, 3, 0, 14));

        addSpinnerControl(
                panel,
                "快门速度",
                shutterLabels(),
                boxedValues(fineShutterValues()),
                nearestIndex(fineShutterValues(), currentShutterSeconds),
                "exposureTime");
        addSpinnerControl(
                panel,
                "光圈",
                apertureLabels(),
                boxedValues(fineApertureValues()),
                nearestIndex(fineApertureValues(), currentAperture),
                "aperture");
        addSpinnerControl(
                panel,
                "ISO感光度",
                isoLabels(),
                isoValues(),
                defaultIsoIndex(),
                "iso");
        addSpinnerControl(
                panel,
                "对焦模式",
                new String[]{"AF-S 单次AF", "AF-C 连续AF", "MF 手动对焦"},
                new Object[]{"single-shot", "continuous", "manual"},
                0,
                "focusMode");
        addSpinnerControl(
                panel,
                "拍摄模式",
                new String[]{
                        "P 程序自动",
                        "S 快门优先自动",
                        "A 光圈优先自动",
                        "M 手动",
                        "M · B门"},
                new Object[]{
                        "program",
                        "shutterPriority",
                        "aperturePriority",
                        "manual",
                        "bulb"},
                exposureModeIndex(),
                "exposureMode");
        addSpinnerControl(
                panel,
                "B门曝光时长（由应用控制）",
                new String[]{"1 秒", "2 秒", "5 秒", "10 秒", "30 秒", "60 秒"},
                new Object[]{1, 2, 5, 10, 30, 60},
                2,
                "bulbDuration");
        addSpinnerControl(
                panel,
                "设定优化校准",
                new String[]{"自动", "标准", "自然", "鲜艳", "单色", "人像", "风景", "平面"},
                new Object[]{
                        "auto",
                        "standard",
                        "neutral",
                        "vivid",
                        "monochrome",
                        "portrait",
                        "landscape",
                        "flat"},
                1,
                "pictureControl");

        TextView compensationLabel = text("曝光补偿 · 0.0 EV", 13, Typeface.BOLD, MUTED);
        compensationLabel.setTag("曝光补偿");
        LinearLayout.LayoutParams labelParams = marginParams(-1, -2, 0, 12, 0, 2);
        panel.addView(compensationLabel, labelParams);
        SeekBar compensation = new SeekBar(this);
        compensation.setMax(30);
        compensation.setProgress(15);
        compensation.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
            @Override
            public void onProgressChanged(SeekBar seekBar, int progress, boolean fromUser) {
                double value = (progress - 15) / 3.0;
                compensationLabel.setText(
                        tr(String.format(
                                Locale.CHINA,
                                "曝光补偿 · %+.1f EV",
                                value)));
            }

            @Override public void onStartTrackingTouch(SeekBar seekBar) {}

            @Override
            public void onStopTrackingTouch(SeekBar seekBar) {
                double value = (seekBar.getProgress() - 15) / 3.0;
                applyParameter("exposureCompensation", value, "曝光补偿");
            }
        });
        cameraControls.add(compensation);
        parameterControls.put("exposureCompensation", compensation);
        parameterLabels.put("exposureCompensation", compensationLabel);
        panel.addView(compensation);

        updateCameraControls();
        return panel;
    }

    private String[] isoLabels() {
        Object[] values = isoValues();
        String[] labels = new String[values.length];
        for (int index = 0; index < values.length; index++) {
            labels[index] = String.valueOf(values[index]);
        }
        return labels;
    }

    private Object[] isoValues() {
        int minimum = camera.getMinimumIso();
        int maximum = camera.getMaximumIso();
        Integer[] candidates = new Integer[]{
                64, 80, 100, 125, 160, 200, 250, 320, 400, 500, 640,
                800, 1000, 1250, 1600, 2000, 2500, 3200, 4000, 5000,
                6400, 8000, 10000, 12800, 16000, 20000, 25600, 32000,
                40000, 51200, 64000, 80000, 102400
        };
        List<Object> supported = new ArrayList<>();
        for (int candidate : candidates) {
            if (candidate >= minimum && candidate <= maximum) {
                supported.add(candidate);
            }
        }
        return supported.toArray();
    }

    private Object[] boxedValues(double[] values) {
        Object[] boxed = new Object[values.length];
        for (int index = 0; index < values.length; index++) {
            boxed[index] = values[index];
        }
        return boxed;
    }

    private int nearestIndex(double[] values, double current) {
        int index = 0;
        for (int candidate = 1; candidate < values.length; candidate++) {
            if (Math.abs(values[candidate] - current)
                    < Math.abs(values[index] - current)) {
                index = candidate;
            }
        }
        return index;
    }

    private String[] shutterLabels() {
        double[] values = fineShutterValues();
        String[] labels = new String[values.length];
        for (int index = 0; index < values.length; index++) {
            double value = values[index];
            labels[index] = value < 1
                    ? "1/" + Math.round(1 / value)
                    : String.format(Locale.CHINA, "%.1f 秒", value);
        }
        return labels;
    }

    private String[] apertureLabels() {
        double[] values = fineApertureValues();
        String[] labels = new String[values.length];
        for (int index = 0; index < values.length; index++) {
            labels[index] = String.format(Locale.CHINA, "F%.1f", values[index]);
        }
        return labels;
    }

    private int defaultIsoIndex() {
        Object[] values = isoValues();
        for (int index = 0; index < values.length; index++) {
            if (((Number) values[index]).intValue() == 400) return index;
        }
        return 0;
    }

    private void addSpinnerControl(
            LinearLayout parent,
            String label,
            String[] labels,
            Object[] values,
            int selected,
            String parameter) {
        TextView labelView = text(label, 13, Typeface.BOLD, MUTED);
        labelView.setTag(label);
        parent.addView(labelView, marginParams(-1, -2, 0, 12, 0, 4));
        Spinner spinner = new Spinner(this);
        ArrayAdapter<String> adapter = new ArrayAdapter<>(
                this,
                android.R.layout.simple_spinner_item,
                Localization.translate(appLanguage, labels));
        adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
        spinner.setAdapter(adapter);
        spinner.setSelection(selected, false);
        spinner.setBackground(rounded(Color.rgb(241, 244, 249), 9, RULE));
        spinner.setPadding(dp(10), 0, dp(8), 0);
        spinner.setOnItemSelectedListener(new android.widget.AdapterView.OnItemSelectedListener() {
            private boolean initialized;

            @Override
            public void onItemSelected(
                    android.widget.AdapterView<?> parent,
                    View view,
                    int position,
                    long id) {
                if (!initialized) {
                    initialized = true;
                    return;
                }
                if ("exposureTime".equals(parameter)
                        && values[position] instanceof Number) {
                    currentShutterSeconds = ((Number) values[position]).doubleValue();
                } else if ("aperture".equals(parameter)
                        && values[position] instanceof Number) {
                    currentAperture = ((Number) values[position]).doubleValue();
                } else if ("iso".equals(parameter)
                        && values[position] instanceof Number) {
                    currentIso = ((Number) values[position]).intValue();
                }
                applyParameter(parameter, values[position], label);
            }

            @Override public void onNothingSelected(android.widget.AdapterView<?> parent) {}
        });
        cameraControls.add(spinner);
        parameterControls.put(parameter, spinner);
        parameterLabels.put(parameter, labelView);
        parent.addView(spinner, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(48)));
    }

    private void addZebraControls(LinearLayout parent) {
        TextView title = text("条纹图案（本地）", 13, Typeface.BOLD, MUTED);
        parent.addView(title, marginParams(-1, -2, 0, 12, 0, 4));

        Switch enabled = new Switch(this);
        enabled.setText(tr("加亮显示"));
        enabled.setTextColor(INK);
        enabled.setChecked(zebraEnabled);
        enabled.setOnCheckedChangeListener((button, checked) -> {
            zebraEnabled = checked;
            if (zebraThresholdControl != null) zebraThresholdControl.setEnabled(checked);
            if (!checked) {
                latestZebraMask = null;
                if (zebraImage != null) zebraImage.setImageDrawable(null);
            }
            refreshPreviewProcessing();
        });
        parent.addView(enabled);

        TextView thresholdLabel = text(
                "加亮显示阈值 · " + zebraThreshold + " IRE",
                12,
                Typeface.NORMAL,
                MUTED);
        parent.addView(thresholdLabel, marginParams(-1, -2, 0, 5, 0, 0));
        zebraThresholdControl = new SeekBar(this);
        zebraThresholdControl.setMax(30);
        zebraThresholdControl.setProgress(zebraThreshold - 70);
        zebraThresholdControl.setEnabled(zebraEnabled);
        zebraThresholdControl.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
            @Override
            public void onProgressChanged(SeekBar seekBar, int progress, boolean fromUser) {
                zebraThreshold = 70 + progress;
                thresholdLabel.setText(
                        tr("加亮显示阈值 · ") + zebraThreshold + " IRE");
            }

            @Override public void onStartTrackingTouch(SeekBar seekBar) {}

            @Override
            public void onStopTrackingTouch(SeekBar seekBar) {
                if (zebraEnabled) refreshPreviewProcessing();
            }
        });
        parent.addView(zebraThresholdControl);
    }

    private void addLutControls(LinearLayout parent) {
        parent.addView(
                text("监看 LUT（本地）", 13, Typeface.BOLD, MUTED),
                marginParams(-1, -2, 0, 12, 0, 4));

        lutSwitch = new Switch(this);
        lutSwitch.setText(tr("应用到实时取景"));
        lutSwitch.setTextColor(INK);
        lutSwitch.setChecked(lutEnabled && previewLut != null);
        lutSwitch.setEnabled(previewLut != null);
        lutSwitch.setOnCheckedChangeListener((button, checked) -> {
            lutEnabled = checked && previewLut != null;
            refreshPreviewProcessing();
        });
        parent.addView(lutSwitch);

        LinearLayout actions = new LinearLayout(this);
        actions.setOrientation(LinearLayout.HORIZONTAL);
        Button importButton = nativeButton("导入 .cube", false);
        importButton.setOnClickListener(view -> chooseLutFile());
        actions.addView(importButton, new LinearLayout.LayoutParams(0, dp(44), 1f));
        Button clearButton = nativeButton("移除", false);
        clearButton.setOnClickListener(view -> {
            previewLut = null;
            lutEnabled = false;
            if (lutSwitch != null) {
                lutSwitch.setChecked(false);
                lutSwitch.setEnabled(false);
            }
            if (lutStatusText != null) {
                lutStatusText.setText(
                        tr("尚未导入；LUT 只影响监看，不写入原片。"));
            }
            refreshPreviewProcessing();
        });
        LinearLayout.LayoutParams clearParams = new LinearLayout.LayoutParams(0, dp(44), 1f);
        clearParams.setMargins(dp(8), 0, 0, 0);
        actions.addView(clearButton, clearParams);
        parent.addView(actions, marginParams(-1, dp(44), 0, 6, 0, 0));

        lutStatusText = text(
                previewLut == null
                        ? "尚未导入；LUT 只影响监看，不写入原片。"
                        : "已载入 · " + previewLut.getTitle(),
                12,
                Typeface.NORMAL,
                MUTED);
        lutStatusText.setMaxLines(2);
        parent.addView(lutStatusText, marginParams(-1, -2, 0, 5, 0, 2));
    }

    private View buildLibraryView() {
        ScrollView scroll = new ScrollView(this);
        LinearLayout content = verticalContainer();
        content.setPadding(dp(20), dp(22), dp(20), dp(28));
        List<File> files = photoFiles();
        List<MediaEntry> systemMedia =
                hasAlbumAccess() ? systemAlbumEntries() : Collections.emptyList();
        content.addView(sectionHeader(
                "分支文件库",
                files.size() + " 个 帧澈 ZENCHE 文件 · "
                        + systemMedia.size() + " 个系统相册项目",
                COBALT));
        LinearLayout branchHero = verticalContainer();
        branchHero.setPadding(dp(16), dp(14), dp(16), dp(14));
        branchHero.setBackground(rounded(COBALT_SOFT, 16, COBALT));
        branchHero.addView(text(
                "分支工作台",
                20,
                Typeface.BOLD,
                INK));
        branchHero.addView(text(
                "长按文件并拖到任意分支；拖回“未分类”即可移出分支。",
                13,
                Typeface.NORMAL,
                MUTED),
                marginParams(-1, -2, 0, 4, 0, 0));
        content.addView(
                branchHero,
                marginParams(-1, -2, 0, 0, 0, 12));
        content.addView(
                isPhoneLayout()
                        ? buildMobileBranchDrawer(files)
                        : buildBranchWorkspace(files));

        LinearLayout sourceActions = new LinearLayout(this);
        sourceActions.setOrientation(LinearLayout.HORIZONTAL);
        Button albumButton = nativeButton(
                hasAlbumAccess() ? "刷新系统相册" : "允许相册访问",
                false);
        albumButton.setOnClickListener(view -> openOwnerAlbum());
        sourceActions.addView(
                albumButton,
                new LinearLayout.LayoutParams(0, dp(48), 1f));
        Button cloudButton = nativeButton("链接网盘", false);
        cloudButton.setOnClickListener(view -> openCloudDrive());
        LinearLayout.LayoutParams cloudParams =
                new LinearLayout.LayoutParams(0, dp(48), 1f);
        cloudParams.setMargins(dp(8), 0, 0, 0);
        sourceActions.addView(cloudButton, cloudParams);
        content.addView(
                sourceActions,
                marginParams(-1, dp(48), 0, 0, 0, 12));
        content.addView(
                text(
                        "系统相册中的照片与视频直接显示在本页；网盘文件通过独立指引页和系统文件选择器安全加入。",
                        12,
                        Typeface.NORMAL,
                        MUTED),
                marginParams(-1, -2, 0, 0, 0, 16));
        content.addView(buildCaptureSessionPanel());

        LinearLayout systemBody = verticalContainer();
        if (!hasAlbumAccess()) {
            TextView permission = text(
                    "允许照片和视频访问后，最近媒体会在这里直接显示，无需先导入。",
                    14,
                    Typeface.NORMAL,
                    MUTED);
            permission.setGravity(Gravity.CENTER);
            permission.setOnClickListener(view -> requestAlbumAccess());
            systemBody.addView(permission, new LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    dp(120)));
        } else if (systemMedia.isEmpty()) {
            TextView emptyAlbum = text(
                    "系统相册暂无可显示的照片或视频。",
                    14,
                    Typeface.NORMAL,
                    MUTED);
            emptyAlbum.setGravity(Gravity.CENTER);
            systemBody.addView(emptyAlbum, new LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    dp(120)));
        } else {
            systemBody.addView(systemMediaTypeGroup(
                    "system-photos",
                    "照片",
                    systemMedia,
                    false));
            systemBody.addView(systemMediaTypeGroup(
                    "system-videos",
                    "视频",
                    systemMedia,
                    true));
        }
        content.addView(collapsibleGroup(
                "system-album",
                "系统相册",
                systemMedia.size() + " 个项目",
                systemBody,
                true));

        content.addView(collapsibleGroup(
                "wireless-transfer",
                "无线传输",
                wirelessRequested ? wirelessStatus : "FTP · HTTP · WebDAV",
                buildWirelessTransferPanel(),
                false));
        scroll.addView(content);
        return scroll;
    }

    private boolean isPhoneLayout() {
        return getResources().getConfiguration().screenWidthDp < 600;
    }

    private View buildMobileBranchDrawer(List<File> files) {
        LinearLayout drawer = panel();
        drawer.setPadding(dp(10), dp(10), dp(10), dp(10));
        View body = buildBranchWorkspace(files);
        boolean expanded = Boolean.TRUE.equals(
                disclosureStates.get("mobile-branch-drawer"));
        body.setVisibility(expanded ? View.VISIBLE : View.GONE);
        Button header = nativeButton("", false);
        header.setGravity(Gravity.START | Gravity.CENTER_VERTICAL);
        Runnable updateLabel = () -> header.setText(
                (body.getVisibility() == View.VISIBLE ? "⌄  " : "›  ")
                        + tr("分支抽屉")
                        + " · "
                        + userLibraryBranches.size()
                        + " "
                        + tr("个根分支"));
        updateLabel.run();
        header.setOnClickListener(view -> {
            boolean next = body.getVisibility() != View.VISIBLE;
            disclosureStates.put("mobile-branch-drawer", next);
            body.setVisibility(next ? View.VISIBLE : View.GONE);
            updateLabel.run();
        });
        drawer.addView(header, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(56)));
        drawer.addView(body);
        drawer.setLayoutParams(marginParams(-1, -2, 0, 0, 0, 16));
        return drawer;
    }

    private View buildImageEditorView() {
        ScrollView scroll = new ScrollView(this);
        LinearLayout content = verticalContainer();
        content.setPadding(dp(20), dp(22), dp(20), dp(28));
        content.addView(sectionHeader(
                editorState == EditorState.AI ? "AI 工具" : "专业显影",
                editorState == EditorState.AI
                        ? "基于 nano-banana-2 模型的 AI 修图与生图；需在设置中配置 API Key。"
                        : "分组调整光线、色彩、细节、效果与几何；始终保留原文件。",
                COBALT));

        if (editorState == EditorState.AI) {
            return buildAiToolsView(scroll, content);
        }
        return buildProEditorView(scroll, content);
    }

    private View buildProEditorView(ScrollView scroll, LinearLayout content) {
        List<File> photos = new ArrayList<>();
        for (File file : photoFiles()) {
            if (isEditableImageFile(file)) {
                photos.add(file);
            }
        }
        if (photos.isEmpty()) {
            TextView empty = text(
                    "文件库中没有可编辑照片\n视频与暂不支持解码的 RAW 文件不会进入编辑列表。",
                    14,
                    Typeface.NORMAL,
                    MUTED);
            empty.setGravity(Gravity.CENTER);
            content.addView(empty, new LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    dp(240)));
            scroll.addView(content);
            return scroll;
        }

        if (editorSelectedPath == null ||
                photos.stream().noneMatch(
                        file -> file.getAbsolutePath().equals(
                                editorSelectedPath))) {
            editorSelectedPath = photos.get(0).getAbsolutePath();
        }

        Spinner picker = new Spinner(this);
        List<String> names = new ArrayList<>();
        for (File file : photos) {
            names.add(file.getName());
        }
        picker.setAdapter(new ArrayAdapter<>(
                this,
                android.R.layout.simple_spinner_dropdown_item,
                names));
        for (int index = 0; index < photos.size(); index++) {
            if (photos.get(index).getAbsolutePath().equals(
                    editorSelectedPath)) {
                picker.setSelection(index);
                break;
            }
        }
        content.addView(
                picker,
                marginParams(-1, dp(48), 0, 0, 0, 12));

        HorizontalScrollView presetScroll = new HorizontalScrollView(this);
        presetScroll.setHorizontalScrollBarEnabled(false);
        LinearLayout presets = new LinearLayout(this);
        presets.setOrientation(LinearLayout.HORIZONTAL);
        presets.setGravity(Gravity.CENTER_VERTICAL);
        addEditorPresetButton(presets, "原始", "original");
        addEditorPresetButton(presets, "自然增强", "natural");
        addEditorPresetButton(presets, "人像柔和", "portrait");
        addEditorPresetButton(presets, "风光通透", "landscape");
        addEditorPresetButton(presets, "高反差黑白", "monochrome");
        presetScroll.addView(presets);
        content.addView(
                presetScroll,
                marginParams(-1, dp(48), 0, 0, 0, 12));

        ImageView preview = new ImageView(this);
        preview.setScaleType(ImageView.ScaleType.FIT_CENTER);
        preview.setBackgroundColor(GRAPHITE);
        content.addView(
                preview,
                marginParams(-1, dp(360), 0, 0, 0, 14));

        TextView status = text(
                "调整不会覆盖原文件",
                11,
                Typeface.NORMAL,
                MUTED);
        Runnable refreshPreview = () -> {
            File selected = new File(editorSelectedPath);
            Bitmap rendered = renderEditedBitmap(
                    selected,
                    editorAdjustments,
                    1600);
            if (rendered == null) {
                preview.setImageDrawable(null);
                status.setText(tr("无法解码当前照片"));
            } else {
                preview.setImageBitmap(rendered);
                status.setText(tr(
                        editorAdjustments.showingOriginal
                                ? "正在查看原图"
                                : "调整不会覆盖原文件"));
            }
        };

        picker.setOnItemSelectedListener(
                new AdapterView.OnItemSelectedListener() {
                    @Override
                    public void onItemSelected(
                            AdapterView<?> parent,
                            View view,
                            int position,
                            long id) {
                        String selectedPath =
                                photos.get(position).getAbsolutePath();
                        if (!selectedPath.equals(editorSelectedPath)) {
                            editorAdjustments.reset();
                        }
                        editorSelectedPath = selectedPath;
                        refreshPreview.run();
                    }

                    @Override
                    public void onNothingSelected(AdapterView<?> parent) {
                    }
                });

        LinearLayout light = editorAdjustmentGroup();
        addEditorAdjustment(
                light,
                "曝光",
                editorAdjustments.exposure,
                -200,
                200,
                true,
                value -> editorAdjustments.exposure = value,
                refreshPreview);
        addEditorAdjustment(
                light,
                "对比度",
                editorAdjustments.contrast,
                -100,
                100,
                false,
                value -> editorAdjustments.contrast = value,
                refreshPreview);
        addEditorAdjustment(
                light,
                "高光",
                editorAdjustments.highlights,
                -100,
                100,
                false,
                value -> editorAdjustments.highlights = value,
                refreshPreview);
        addEditorAdjustment(
                light,
                "阴影",
                editorAdjustments.shadows,
                -100,
                100,
                false,
                value -> editorAdjustments.shadows = value,
                refreshPreview);
        addEditorAdjustment(
                light,
                "白色色阶",
                editorAdjustments.whites,
                -100,
                100,
                false,
                value -> editorAdjustments.whites = value,
                refreshPreview);
        addEditorAdjustment(
                light,
                "黑色色阶",
                editorAdjustments.blacks,
                -100,
                100,
                false,
                value -> editorAdjustments.blacks = value,
                refreshPreview);
        content.addView(collapsibleGroup(
                "editor-light",
                "光线",
                "6 项",
                light,
                true));

        LinearLayout color = editorAdjustmentGroup();
        addEditorAdjustment(
                color,
                "色温",
                editorAdjustments.temperature,
                -100,
                100,
                false,
                value -> editorAdjustments.temperature = value,
                refreshPreview);
        addEditorAdjustment(
                color,
                "色调",
                editorAdjustments.tint,
                -100,
                100,
                false,
                value -> editorAdjustments.tint = value,
                refreshPreview);
        addEditorAdjustment(
                color,
                "自然饱和度",
                editorAdjustments.vibrance,
                -100,
                100,
                false,
                value -> editorAdjustments.vibrance = value,
                refreshPreview);
        addEditorAdjustment(
                color,
                "饱和度",
                editorAdjustments.saturation,
                -100,
                100,
                false,
                value -> editorAdjustments.saturation = value,
                refreshPreview);
        content.addView(collapsibleGroup(
                "editor-color",
                "色彩",
                "4 项",
                color,
                false));

        LinearLayout detail = editorAdjustmentGroup();
        addEditorAdjustment(
                detail,
                "纹理",
                editorAdjustments.texture,
                -100,
                100,
                false,
                value -> editorAdjustments.texture = value,
                refreshPreview);
        addEditorAdjustment(
                detail,
                "清晰度",
                editorAdjustments.clarity,
                -100,
                100,
                false,
                value -> editorAdjustments.clarity = value,
                refreshPreview);
        addEditorAdjustment(
                detail,
                "锐化",
                editorAdjustments.sharpening,
                0,
                100,
                false,
                value -> editorAdjustments.sharpening = value,
                refreshPreview);
        addEditorAdjustment(
                detail,
                "降噪",
                editorAdjustments.noiseReduction,
                0,
                100,
                false,
                value -> editorAdjustments.noiseReduction = value,
                refreshPreview);
        content.addView(collapsibleGroup(
                "editor-detail",
                "细节",
                "4 项",
                detail,
                false));

        LinearLayout effects = editorAdjustmentGroup();
        addEditorAdjustment(
                effects,
                "去雾",
                editorAdjustments.dehaze,
                -100,
                100,
                false,
                value -> editorAdjustments.dehaze = value,
                refreshPreview);
        addEditorAdjustment(
                effects,
                "暗角",
                editorAdjustments.vignette,
                -100,
                100,
                false,
                value -> editorAdjustments.vignette = value,
                refreshPreview);
        content.addView(collapsibleGroup(
                "editor-effects",
                "效果",
                "2 项",
                effects,
                false));

        content.addView(collapsibleGroup(
                "editor-geometry",
                "几何",
                "裁切与翻转",
                buildEditorGeometryControls(refreshPreview),
                false));

        LinearLayout actions = new LinearLayout(this);
        actions.setOrientation(LinearLayout.HORIZONTAL);
        Button compare = nativeButton("查看原图", false);
        compare.setOnClickListener(view -> {
            editorAdjustments.showingOriginal =
                    !editorAdjustments.showingOriginal;
            compare.setText(tr(
                    editorAdjustments.showingOriginal
                            ? "返回调整"
                            : "查看原图"));
            refreshPreview.run();
        });
        actions.addView(
                compare,
                new LinearLayout.LayoutParams(0, dp(48), 1f));
        Button reset = nativeButton("全部重置", false);
        reset.setOnClickListener(view -> {
            editorAdjustments.reset();
            showSection("editor");
        });
        LinearLayout.LayoutParams resetParams =
                new LinearLayout.LayoutParams(0, dp(48), 1f);
        resetParams.setMargins(dp(8), 0, 0, 0);
        actions.addView(reset, resetParams);
        Button save = nativeButton("保存高质量副本", true);
        save.setOnClickListener(view -> {
            File source = new File(editorSelectedPath);
            save.setEnabled(false);
            status.setText(tr("正在保存编辑副本…"));
            EditorAdjustments savedAdjustments =
                    editorAdjustments.copy();
            savedAdjustments.showingOriginal = false;
            editorExecutor.execute(() -> {
                Bitmap output = renderEditedBitmap(
                        source,
                        savedAdjustments,
                        4096);
                File destination = uniqueEditedFile(source);
                boolean success = false;
                if (output != null) {
                    try (FileOutputStream stream =
                                 new FileOutputStream(destination)) {
                        success = output.compress(
                                Bitmap.CompressFormat.JPEG,
                                95,
                                stream);
                    } catch (Exception error) {
                        diagnostics.error(
                                "editor",
                                "保存编辑副本失败：" + error.getMessage());
                    }
                    output.recycle();
                }
                boolean saved = success;
                mainHandler.post(() -> {
                    save.setEnabled(true);
                    if (saved) {
                        editorSelectedPath =
                                destination.getAbsolutePath();
                        editorAdjustments.reset();
                        showToast("已保存编辑副本：" + destination.getName());
                        updateFileCount();
                        showSection("editor");
                    } else {
                        status.setText(tr("保存编辑副本失败"));
                    }
                });
            });
        });
        LinearLayout.LayoutParams saveParams =
                new LinearLayout.LayoutParams(0, dp(48), 1f);
        saveParams.setMargins(dp(8), 0, 0, 0);
        actions.addView(save, saveParams);
        content.addView(actions);
        content.addView(
                status,
                marginParams(-1, -2, 0, 8, 0, 0));
        scroll.addView(content);
        refreshPreview.run();
        return scroll;
    }

    private View buildAiToolsView(ScrollView scroll, LinearLayout content) {
        List<File> photos = new ArrayList<>();
        for (File file : photoFiles()) {
            if (isEditableImageFile(file)) {
                photos.add(file);
            }
        }
        if (aiMode == 0 && photos.isEmpty()) {
            aiMode = 1;
        }

        Spinner picker = null;
        if (aiMode == 0) {
            picker = new Spinner(this);
            List<String> names = new ArrayList<>();
            for (File file : photos) {
                names.add(file.getName());
            }
            picker.setAdapter(new ArrayAdapter<>(
                    this, android.R.layout.simple_spinner_dropdown_item, names));
            if (editorSelectedPath == null || photos.stream().noneMatch(
                    f -> f.getAbsolutePath().equals(editorSelectedPath))) {
                editorSelectedPath = photos.isEmpty()
                        ? null
                        : photos.get(0).getAbsolutePath();
            }
            for (int i = 0; i < photos.size(); i++) {
                if (photos.get(i).getAbsolutePath().equals(editorSelectedPath)) {
                    picker.setSelection(i);
                    break;
                }
            }
            content.addView(picker, marginParams(-1, dp(48), 0, 0, 0, 10));
        }

        LinearLayout modeRow = new LinearLayout(this);
        modeRow.setOrientation(LinearLayout.HORIZONTAL);
        Button editBtn = nativeButton(aiMode == 0 ? "● AI 修图" : "○ AI 修图", aiMode == 0);
        editBtn.setOnClickListener(v -> {
            aiMode = 0;
            aiResultBitmap = null;
            showSection("editor");
        });
        modeRow.addView(editBtn, new LinearLayout.LayoutParams(0, dp(44), 1f));
        Button genBtn = nativeButton(aiMode == 1 ? "● AI 生图" : "○ AI 生图", aiMode == 1);
        genBtn.setOnClickListener(v -> {
            aiMode = 1;
            aiResultBitmap = null;
            showSection("editor");
        });
        LinearLayout.LayoutParams genParams = new LinearLayout.LayoutParams(0, dp(44), 1f);
        genParams.setMargins(dp(8), 0, 0, 0);
        modeRow.addView(genBtn, genParams);
        content.addView(modeRow, marginParams(-1, -2, 0, 0, 0, 10));

        EditText promptInput = new EditText(this);
        promptInput.setHint(aiMode == 0 ? tr("输入修图描述…") : tr("输入生图描述…"));
        promptInput.setText(aiPrompt);
        promptInput.setMinLines(2);
        promptInput.setMaxLines(4);
        promptInput.setBackgroundColor(SURFACE);
        promptInput.setPadding(dp(12), dp(10), dp(12), dp(10));

        TextView aiStatus = text("请输入提示词", 11, Typeface.NORMAL, MUTED);
        content.addView(buildAiPresetRow(promptInput, aiStatus),
                marginParams(-1, -2, 0, 0, 0, 10));
        content.addView(promptInput, marginParams(-1, -2, 0, 0, 0, 10));

        LinearLayout paramRow = new LinearLayout(this);
        paramRow.setOrientation(LinearLayout.HORIZONTAL);
        Spinner ratioSpinner = new Spinner(this);
        String[] ratioLabels = new String[AI_RATIOS.length];
        for (int i = 0; i < AI_RATIOS.length; i++) {
            ratioLabels[i] = AI_RATIOS[i][0];
        }
        ratioSpinner.setAdapter(new ArrayAdapter<>(
                this, android.R.layout.simple_spinner_dropdown_item, ratioLabels));
        ratioSpinner.setSelection(aiRatioIndex);
        ratioSpinner.setOnItemSelectedListener(new AdapterView.OnItemSelectedListener() {
            @Override
            public void onItemSelected(AdapterView<?> p, View v, int pos, long id) {
                aiRatioIndex = pos;
            }
            @Override
            public void onNothingSelected(AdapterView<?> p) {}
        });
        paramRow.addView(ratioSpinner, new LinearLayout.LayoutParams(0, dp(44), 1f));

        Spinner resSpinner = new Spinner(this);
        resSpinner.setAdapter(new ArrayAdapter<>(
                this, android.R.layout.simple_spinner_dropdown_item, AI_RESOLUTIONS));
        resSpinner.setSelection(aiResolutionIndex);
        resSpinner.setOnItemSelectedListener(new AdapterView.OnItemSelectedListener() {
            @Override
            public void onItemSelected(AdapterView<?> p, View v, int pos, long id) {
                aiResolutionIndex = pos;
            }
            @Override
            public void onNothingSelected(AdapterView<?> p) {}
        });
        LinearLayout.LayoutParams resParams = new LinearLayout.LayoutParams(0, dp(44), 1f);
        resParams.setMargins(dp(8), 0, 0, 0);
        paramRow.addView(resSpinner, resParams);
        content.addView(paramRow, marginParams(-1, -2, 0, 0, 0, 10));

        Button generateBtn = nativeButton("生成", true);
        generateBtn.setOnClickListener(v -> {
            aiPrompt = promptInput.getText().toString().trim();
            if (aiPrompt.isEmpty()) {
                aiStatus.setText(tr("请输入提示词"));
                return;
            }
            if (!isAiActivated()) {
                aiStatus.setText(tr("请先在设置中输入激活码解锁 AI 功能"));
                return;
            }
            if (aiMode == 0 && (photos.isEmpty() || editorSelectedPath == null)) {
                aiStatus.setText(tr("请先选择一张照片用于 AI 修图"));
                return;
            }
            aiIsGenerating = true;
            generateBtn.setEnabled(false);
            generateBtn.setText(tr("正在生成…"));
            aiStatus.setText(tr("正在调用 AI 模型…"));
            String size = AI_RATIOS[aiRatioIndex][1];
            boolean isEditMode = aiMode == 0;
            String sourcePath = isEditMode ? editorSelectedPath : null;
            editorExecutor.execute(() -> {
                boolean ok = false;
                try {
                    byte[] result = callAiImageApi(
                            loadActivationCode(), aiDeviceId(),
                            aiPrompt, sourcePath, size);
                    if (result != null) {
                        aiResultBitmap = BitmapFactory.decodeByteArray(
                                result, 0, result.length);
                        ok = aiResultBitmap != null;
                    }
                } catch (Exception e) {
                    diagnostics.error("ai", "AI 调用失败：" + e.getMessage());
                }
                boolean success = ok;
                mainHandler.post(() -> {
                    aiIsGenerating = false;
                    generateBtn.setEnabled(true);
                    generateBtn.setText(tr("生成"));
                    if (success) {
                        aiStatus.setText(tr("生成完成"));
                        showSection("editor");
                    } else {
                        aiStatus.setText(tr("AI 生成失败"));
                    }
                });
            });
        });
        content.addView(generateBtn, marginParams(-1, dp(48), 0, 8, 0, 8));
        content.addView(aiStatus, marginParams(-1, -2, 0, 8, 0, 0));

        if (aiResultBitmap != null) {
            ImageView aiPreview = new ImageView(this);
            aiPreview.setScaleType(ImageView.ScaleType.FIT_CENTER);
            aiPreview.setImageBitmap(aiResultBitmap);
            aiPreview.setBackgroundColor(GRAPHITE);
            content.addView(aiPreview, marginParams(-1, dp(360), 0, 0, 0, 12));

            Button saveBtn = nativeButton("保存到文件库", true);
            saveBtn.setOnClickListener(v -> {
                saveBtn.setEnabled(false);
                Bitmap bmp = aiResultBitmap;
                editorExecutor.execute(() -> {
                    String stem = aiMode == 0 ? "edited" : "generated";
                    File dest = new File(
                            photoDirectory,
                            "ai_" + stem + "_" + new java.text.SimpleDateFormat(
                                    "yyyyMMdd_HHmmss", java.util.Locale.US)
                                    .format(new Date()) + ".jpg");
                    boolean ok = false;
                    try (FileOutputStream stream = new FileOutputStream(dest)) {
                        ok = bmp.compress(Bitmap.CompressFormat.JPEG, 95, stream);
                    } catch (Exception e) {
                        diagnostics.error("ai", "保存失败：" + e.getMessage());
                    }
                    boolean saved = ok;
                    mainHandler.post(() -> {
                        saveBtn.setEnabled(true);
                        if (saved) {
                            editorSelectedPath = dest.getAbsolutePath();
                            showToast("已保存 AI 结果：" + dest.getName());
                            updateFileCount();
                        } else {
                            aiStatus.setText(tr("保存 AI 结果失败"));
                        }
                    });
                });
            });
            content.addView(saveBtn, marginParams(-1, dp(48), 0, 0, 0, 0));
        }
        content.addView(aiStatus, marginParams(-1, -2, 0, 8, 0, 0));
        scroll.addView(content);
        return scroll;
    }

    private LinearLayout buildAiPresetRow(EditText promptInput, TextView aiStatus) {
        LinearLayout container = new LinearLayout(this);
        container.setOrientation(LinearLayout.VERTICAL);
        container.addView(text("快捷预设", 11, Typeface.BOLD, MUTED),
                marginParams(-1, -2, 0, 8, 0, 2));
        String[][] presets = aiMode == 0 ? AI_EDIT_PRESETS : AI_GEN_PRESETS;
        LinearLayout current = null;
        for (int i = 0; i < presets.length; i++) {
            if (i % 4 == 0) {
                current = new LinearLayout(this);
                current.setOrientation(LinearLayout.HORIZONTAL);
                container.addView(current, marginParams(-1, -2, 0, 0, 0, 4));
            }
            String[] preset = presets[i];
            Button chip = nativeButton(preset[0], false);
            chip.setOnClickListener(v -> {
                promptInput.setText(preset[1]);
                aiStatus.setText("已应用预设 · " + preset[0]);
            });
            LinearLayout.LayoutParams chipParams = new LinearLayout.LayoutParams(0, dp(36), 1f);
            if (i % 4 != 0) {
                chipParams.setMargins(dp(8), 0, 0, 0);
            }
            current.addView(chip, chipParams);
        }
        return container;
    }

    private byte[] callAiImageApi(
            String activationCode,
            String deviceId,
            String prompt,
            String sourcePath,
            String size) throws Exception {
        String url = aiServerUrl() + "/v1/ai";

        java.net.URL endpoint = new java.net.URL(url);
        java.net.HttpURLConnection conn =
                (java.net.HttpURLConnection) endpoint.openConnection();
        conn.setRequestMethod("POST");
        conn.setRequestProperty("Content-Type", "application/json");
        conn.setConnectTimeout(15_000);
        conn.setReadTimeout(45_000);
        conn.setDoOutput(true);

        org.json.JSONObject body = new org.json.JSONObject();
        try {
            body.put("activationCode", activationCode);
            body.put("deviceId", deviceId);
            body.put("prompt", prompt);
            body.put("size", size);
            if (sourcePath != null) {
                byte[] srcBytes = java.nio.file.Files.readAllBytes(
                        new File(sourcePath).toPath());
                String b64 = android.util.Base64.encodeToString(
                        srcBytes, android.util.Base64.NO_WRAP);
                body.put("image", "data:image/jpeg;base64," + b64);
            }
        } catch (Exception ignored) {}

        java.io.OutputStream os = conn.getOutputStream();
        os.write(body.toString().getBytes("UTF-8"));
        os.close();

        int code = conn.getResponseCode();
        if (code != 200) {
            if (code == 403) {
                throw new Exception("激活码无效或次数用完");
            }
            if (code == 502) {
                throw new Exception("AI 服务暂时不可用");
            }
            throw new Exception("API 服务返回错误 " + code);
        }

        java.io.InputStream is = conn.getInputStream();
        byte[] respBytes = readAllBytes(is);
        is.close();
        conn.disconnect();

        org.json.JSONObject json = new org.json.JSONObject(
                new String(respBytes, "UTF-8"));
        org.json.JSONArray dataArr = json.getJSONArray("data");
        if (dataArr.length() == 0) {
            throw new Exception("AI 未返回有效图片");
        }
        org.json.JSONObject first = dataArr.getJSONObject(0);
        String b64Json = first.optString("b64_json", null);
        if (b64Json != null && !b64Json.isEmpty()) {
            return android.util.Base64.decode(b64Json, android.util.Base64.DEFAULT);
        }
        String imageUrl = first.optString("url", null);
        if (imageUrl != null && !imageUrl.isEmpty()) {
            java.net.URL imgUrl = new java.net.URL(imageUrl);
            java.net.HttpURLConnection imgConn =
                    (java.net.HttpURLConnection) imgUrl.openConnection();
            imgConn.setConnectTimeout(15_000);
            imgConn.setReadTimeout(30_000);
            java.io.InputStream imgIs = imgConn.getInputStream();
            byte[] data = readAllBytes(imgIs);
            imgIs.close();
            imgConn.disconnect();
            return data;
        }
        throw new Exception("AI 未返回有效图片");
    }

    private String loadAiApiKey() {
        try {
            java.security.KeyStore keyStore = java.security.KeyStore.getInstance(
                    "AndroidKeyStore");
            keyStore.load(null);
            java.security.KeyStore.SecretKeyEntry entry =
                    (java.security.KeyStore.SecretKeyEntry) keyStore.getEntry(
                            "_zenche_ai_key_", null);
            if (entry != null) {
                javax.crypto.Cipher cipher = javax.crypto.Cipher.getInstance(
                        "AES/GCM/NoPadding");
                cipher.init(javax.crypto.Cipher.DECRYPT_MODE,
                        entry.getSecretKey());
                byte[] encrypted = android.util.Base64.decode(
                        getSharedPreferences("nikon-link", MODE_PRIVATE)
                                .getString("aiApiKeyEnc", ""),
                        android.util.Base64.DEFAULT);
                if (encrypted.length > 0) {
                    byte[] decrypted = cipher.doFinal(encrypted);
                    return new String(decrypted, "UTF-8");
                }
            }
        } catch (Exception ignored) {}
        return "";
    }

    private static byte[] readAllBytes(java.io.InputStream input) throws Exception {
        java.io.ByteArrayOutputStream buffer = new java.io.ByteArrayOutputStream();
        byte[] chunk = new byte[8192];
        int read;
        while ((read = input.read(chunk)) != -1) {
            buffer.write(chunk, 0, read);
        }
        return buffer.toByteArray();
    }

    private void saveAiApiKey(String key) {
        try {
            java.security.KeyStore keyStore = java.security.KeyStore.getInstance(
                    "AndroidKeyStore");
            keyStore.load(null);
            if (!keyStore.containsAlias("_zenche_ai_key_")) {
                javax.crypto.KeyGenerator keyGen = javax.crypto.KeyGenerator.getInstance(
                        "AES", "AndroidKeyStore");
                keyGen.init(new android.security.keystore.KeyGenParameterSpec.Builder(
                        "_zenche_ai_key_",
                        android.security.keystore.KeyProperties.PURPOSE_ENCRYPT
                                | android.security.keystore.KeyProperties.PURPOSE_DECRYPT)
                        .setBlockModes(
                                android.security.keystore.KeyProperties.BLOCK_MODE_GCM)
                        .setEncryptionPaddings(
                                android.security.keystore.KeyProperties.ENCRYPTION_PADDING_NONE)
                        .build());
                keyGen.generateKey();
            }
            java.security.KeyStore.SecretKeyEntry entry =
                    (java.security.KeyStore.SecretKeyEntry) keyStore.getEntry(
                            "_zenche_ai_key_", null);
            javax.crypto.Cipher cipher = javax.crypto.Cipher.getInstance(
                    "AES/GCM/NoPadding");
            cipher.init(javax.crypto.Cipher.ENCRYPT_MODE,
                    entry.getSecretKey());
            byte[] encrypted = cipher.doFinal(key.getBytes("UTF-8"));
            getSharedPreferences("nikon-link", MODE_PRIVATE)
                    .edit()
                    .putString(
                            "aiApiKeyEnc",
                            android.util.Base64.encodeToString(
                                    encrypted, android.util.Base64.DEFAULT))
                    .apply();
        } catch (Exception e) {
            diagnostics.error("ai", "保存 API Key 失败：" + e.getMessage());
        }
    }

    private LinearLayout editorAdjustmentGroup() {
        LinearLayout group = verticalContainer();
        group.setPadding(dp(12), dp(4), dp(12), dp(10));
        return group;
    }

    private void addEditorPresetButton(
            LinearLayout parent,
            String label,
            String preset) {
        Button button = nativeButton(label, false);
        button.setOnClickListener(view -> {
            applyEditorPreset(preset);
            showSection("editor");
        });
        LinearLayout.LayoutParams params =
                new LinearLayout.LayoutParams(dp(128), dp(44));
        params.setMargins(0, 0, dp(8), 0);
        parent.addView(button, params);
    }

    private void applyEditorPreset(String preset) {
        editorAdjustments.resetTone();
        switch (preset) {
            case "natural":
                editorAdjustments.contrast = 8;
                editorAdjustments.highlights = -18;
                editorAdjustments.shadows = 16;
                editorAdjustments.whites = 8;
                editorAdjustments.blacks = -8;
                editorAdjustments.vibrance = 14;
                editorAdjustments.texture = 8;
                editorAdjustments.clarity = 6;
                editorAdjustments.sharpening = 24;
                editorAdjustments.noiseReduction = 8;
                break;
            case "portrait":
                editorAdjustments.contrast = -4;
                editorAdjustments.highlights = -24;
                editorAdjustments.shadows = 18;
                editorAdjustments.temperature = 7;
                editorAdjustments.tint = 4;
                editorAdjustments.vibrance = 10;
                editorAdjustments.texture = -12;
                editorAdjustments.clarity = -6;
                editorAdjustments.sharpening = 16;
                editorAdjustments.noiseReduction = 22;
                editorAdjustments.vignette = -8;
                break;
            case "landscape":
                editorAdjustments.contrast = 12;
                editorAdjustments.highlights = -28;
                editorAdjustments.shadows = 14;
                editorAdjustments.whites = 12;
                editorAdjustments.blacks = -14;
                editorAdjustments.vibrance = 24;
                editorAdjustments.saturation = 5;
                editorAdjustments.texture = 16;
                editorAdjustments.clarity = 18;
                editorAdjustments.sharpening = 30;
                editorAdjustments.dehaze = 12;
                editorAdjustments.vignette = -10;
                break;
            case "monochrome":
                editorAdjustments.contrast = 22;
                editorAdjustments.highlights = -18;
                editorAdjustments.shadows = 12;
                editorAdjustments.whites = 10;
                editorAdjustments.blacks = -22;
                editorAdjustments.saturation = -100;
                editorAdjustments.texture = 12;
                editorAdjustments.clarity = 24;
                editorAdjustments.sharpening = 28;
                editorAdjustments.vignette = -14;
                break;
            default:
                break;
        }
    }

    private SeekBar addEditorAdjustment(
            LinearLayout parent,
            String title,
            int currentValue,
            int minimum,
            int maximum,
            boolean exposure,
            IntConsumer setter,
            Runnable refreshPreview) {
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(Gravity.CENTER_VERTICAL);
        TextView label = text(title, 13, Typeface.BOLD, INK);
        row.addView(label, new LinearLayout.LayoutParams(dp(86), dp(48)));
        SeekBar slider = new SeekBar(this);
        slider.setMax(maximum - minimum);
        slider.setProgress(currentValue - minimum);
        TextView value = text(
                editorAdjustmentValue(currentValue, exposure),
                11,
                Typeface.NORMAL,
                MUTED);
        value.setGravity(Gravity.END | Gravity.CENTER_VERTICAL);
        slider.setOnSeekBarChangeListener(
                new SeekBar.OnSeekBarChangeListener() {
                    @Override
                    public void onProgressChanged(
                            SeekBar seekBar,
                            int progress,
                            boolean fromUser) {
                        int adjusted = progress + minimum;
                        setter.accept(adjusted);
                        value.setText(
                                editorAdjustmentValue(
                                        adjusted,
                                        exposure));
                        if (fromUser) refreshPreview.run();
                    }

                    @Override
                    public void onStartTrackingTouch(SeekBar seekBar) {
                    }

                    @Override
                    public void onStopTrackingTouch(SeekBar seekBar) {
                    }
                });
        row.addView(slider, new LinearLayout.LayoutParams(0, dp(48), 1f));
        row.addView(value, new LinearLayout.LayoutParams(dp(44), dp(48)));
        parent.addView(row);
        return slider;
    }

    private String editorAdjustmentValue(
            int value,
            boolean exposure) {
        if (exposure) {
            return String.format(
                    Locale.ROOT,
                    "%+.2f EV",
                    value / 100.0);
        }
        return String.format(Locale.ROOT, "%+d", value);
    }

    private View buildEditorGeometryControls(Runnable refreshPreview) {
        LinearLayout group = editorAdjustmentGroup();
        group.addView(
                text("裁切比例", 12, Typeface.BOLD, MUTED),
                marginParams(-1, dp(24), 0, 0, 0, 4));
        Spinner crop = monitorSpinner(new String[]{
                "原始比例",
                "1:1",
                "4:3",
                "3:2",
                "16:9"
        });
        String[] cropValues = new String[]{
                "original", "1:1", "4:3", "3:2", "16:9"
        };
        int selected = Arrays.asList(cropValues)
                .indexOf(editorAdjustments.cropRatio);
        crop.setSelection(Math.max(0, selected));
        crop.setOnItemSelectedListener(
                new AdapterView.OnItemSelectedListener() {
                    @Override
                    public void onItemSelected(
                            AdapterView<?> parent,
                            View view,
                            int position,
                            long id) {
                        editorAdjustments.cropRatio =
                                cropValues[position];
                        refreshPreview.run();
                    }

                    @Override
                    public void onNothingSelected(AdapterView<?> parent) {
                    }
                });
        group.addView(
                crop,
                marginParams(-1, dp(48), 0, 6, 0, 10));

        LinearLayout actions = new LinearLayout(this);
        actions.setOrientation(LinearLayout.HORIZONTAL);
        Button rotate = nativeButton("旋转 90°", false);
        rotate.setOnClickListener(view -> {
            editorAdjustments.rotation =
                    (editorAdjustments.rotation + 90) % 360;
            refreshPreview.run();
        });
        actions.addView(
                rotate,
                new LinearLayout.LayoutParams(0, dp(48), 1f));
        Button horizontal = nativeButton("水平翻转", false);
        horizontal.setOnClickListener(view -> {
            editorAdjustments.flipHorizontal =
                    !editorAdjustments.flipHorizontal;
            refreshPreview.run();
        });
        LinearLayout.LayoutParams horizontalParams =
                new LinearLayout.LayoutParams(0, dp(48), 1f);
        horizontalParams.setMargins(dp(8), 0, 0, 0);
        actions.addView(horizontal, horizontalParams);
        Button vertical = nativeButton("垂直翻转", false);
        vertical.setOnClickListener(view -> {
            editorAdjustments.flipVertical =
                    !editorAdjustments.flipVertical;
            refreshPreview.run();
        });
        LinearLayout.LayoutParams verticalParams =
                new LinearLayout.LayoutParams(0, dp(48), 1f);
        verticalParams.setMargins(dp(8), 0, 0, 0);
        actions.addView(vertical, verticalParams);
        group.addView(actions);
        return group;
    }

    private static boolean isEditableImageFile(File file) {
        String lower = file.getName().toLowerCase(Locale.ROOT);
        return lower.endsWith(".jpg")
                || lower.endsWith(".jpeg")
                || lower.endsWith(".png")
                || lower.endsWith(".heic")
                || lower.endsWith(".heif")
                || lower.endsWith(".tif")
                || lower.endsWith(".tiff");
    }

    private Bitmap renderEditedBitmap(
            File file,
            EditorAdjustments settings,
            int maximumDimension) {
        BitmapFactory.Options bounds = new BitmapFactory.Options();
        bounds.inJustDecodeBounds = true;
        BitmapFactory.decodeFile(file.getAbsolutePath(), bounds);
        int sampleSize = 1;
        while (Math.max(
                bounds.outWidth / sampleSize,
                bounds.outHeight / sampleSize) > maximumDimension) {
            sampleSize *= 2;
        }
        BitmapFactory.Options options = new BitmapFactory.Options();
        options.inSampleSize = sampleSize;
        options.inPreferredConfig = Bitmap.Config.ARGB_8888;
        Bitmap source = BitmapFactory.decodeFile(
                file.getAbsolutePath(),
                options);
        if (source == null) return null;
        if (settings.showingOriginal) {
            return source;
        }

        int width = source.getWidth();
        int height = source.getHeight();
        int[] pixels = new int[width * height];
        source.getPixels(pixels, 0, width, 0, 0, width, height);
        source.recycle();

        double exposure = Math.pow(2, settings.exposure / 100.0);
        double contrast =
                1
                        + settings.contrast / 125.0
                        + settings.dehaze / 210.0;
        double baseSaturation =
                1
                        + settings.saturation / 100.0
                        + settings.dehaze / 520.0;
        double temperature = settings.temperature / 100.0;
        double tint = settings.tint / 100.0;
        for (int index = 0; index < pixels.length; index++) {
            int color = pixels[index];
            double red = Color.red(color) / 255.0 * exposure;
            double green = Color.green(color) / 255.0 * exposure;
            double blue = Color.blue(color) / 255.0 * exposure;

            red += temperature * 0.12 + tint * 0.045;
            green -= tint * 0.08;
            blue -= temperature * 0.12 - tint * 0.045;

            double luma =
                    red * 0.2126 + green * 0.7152 + blue * 0.0722;
            double toneShift =
                    settings.shadows / 100.0
                            * Math.pow(1 - clampUnit(luma), 2)
                            * 0.38
                    + settings.highlights / 100.0
                            * Math.pow(clampUnit(luma), 2)
                            * 0.30
                    + settings.whites / 100.0
                            * smoothStep(0.55, 1, luma)
                            * 0.24
                    + settings.blacks / 100.0
                            * (1 - smoothStep(0, 0.45, luma))
                            * 0.20;
            red += toneShift;
            green += toneShift;
            blue += toneShift;

            double clarityMask =
                    1 - Math.abs(clampUnit(luma) * 2 - 1);
            double localContrast =
                    1 + settings.clarity / 100.0
                            * clarityMask * 0.38;
            red = (red - 0.5) * contrast * localContrast + 0.5;
            green = (green - 0.5) * contrast * localContrast + 0.5;
            blue = (blue - 0.5) * contrast * localContrast + 0.5;

            luma = red * 0.2126 + green * 0.7152 + blue * 0.0722;
            double colorfulness =
                    Math.max(red, Math.max(green, blue))
                            - Math.min(red, Math.min(green, blue));
            double saturation =
                    Math.max(
                            0,
                            baseSaturation
                                    + settings.vibrance / 100.0
                                    * (1 - clampUnit(colorfulness))
                                    * 0.82);
            red = luma + (red - luma) * saturation;
            green = luma + (green - luma) * saturation;
            blue = luma + (blue - luma) * saturation;

            int x = index % width;
            int y = index / width;
            double normalizedX =
                    (x - width / 2.0) / Math.max(1, width / 2.0);
            double normalizedY =
                    (y - height / 2.0) / Math.max(1, height / 2.0);
            double edge = Math.min(
                    1,
                    Math.sqrt(
                            normalizedX * normalizedX
                                    + normalizedY * normalizedY));
            double vignette =
                    1 + settings.vignette / 100.0
                            * edge * edge * 0.72;
            red *= vignette;
            green *= vignette;
            blue *= vignette;

            pixels[index] = Color.argb(
                    Color.alpha(color),
                    editorChannel(red * 255),
                    editorChannel(green * 255),
                    editorChannel(blue * 255));
        }

        applyEditorDetail(
                pixels,
                width,
                height,
                settings);
        Bitmap adjusted = Bitmap.createBitmap(
                pixels,
                width,
                height,
                Bitmap.Config.ARGB_8888);
        return applyEditorGeometry(adjusted, settings);
    }

    private void applyEditorDetail(
            int[] pixels,
            int width,
            int height,
            EditorAdjustments settings) {
        double smoothing =
                settings.noiseReduction / 100.0 * 0.58
                        + Math.max(0, -settings.texture) / 100.0 * 0.24;
        double sharpening =
                settings.sharpening / 100.0 * 1.15
                        + Math.max(0, settings.texture) / 100.0 * 0.48
                        + Math.max(0, settings.clarity) / 100.0 * 0.25;
        if (smoothing == 0 && sharpening == 0) {
            return;
        }
        int[] source = pixels.clone();
        for (int y = 1; y < height - 1; y++) {
            for (int x = 1; x < width - 1; x++) {
                int index = y * width + x;
                int center = source[index];
                int left = source[index - 1];
                int right = source[index + 1];
                int top = source[index - width];
                int bottom = source[index + width];
                int averageRed =
                        (Color.red(center) + Color.red(left)
                                + Color.red(right) + Color.red(top)
                                + Color.red(bottom)) / 5;
                int averageGreen =
                        (Color.green(center) + Color.green(left)
                                + Color.green(right) + Color.green(top)
                                + Color.green(bottom)) / 5;
                int averageBlue =
                        (Color.blue(center) + Color.blue(left)
                                + Color.blue(right) + Color.blue(top)
                                + Color.blue(bottom)) / 5;
                pixels[index] = Color.argb(
                        Color.alpha(center),
                        editorDetailChannel(
                                Color.red(center),
                                averageRed,
                                smoothing,
                                sharpening),
                        editorDetailChannel(
                                Color.green(center),
                                averageGreen,
                                smoothing,
                                sharpening),
                        editorDetailChannel(
                                Color.blue(center),
                                averageBlue,
                                smoothing,
                                sharpening));
            }
        }
    }

    private int editorDetailChannel(
            int center,
            int average,
            double smoothing,
            double sharpening) {
        double smoothed = center * (1 - smoothing) + average * smoothing;
        return editorChannel(
                smoothed + (center - average) * sharpening);
    }

    private Bitmap applyEditorGeometry(
            Bitmap bitmap,
            EditorAdjustments settings) {
        Bitmap transformed = bitmap;
        if (settings.rotation != 0
                || settings.flipHorizontal
                || settings.flipVertical) {
            Matrix matrix = new Matrix();
            matrix.postScale(
                    settings.flipHorizontal ? -1 : 1,
                    settings.flipVertical ? -1 : 1);
            matrix.postRotate(settings.rotation);
            transformed = Bitmap.createBitmap(
                    bitmap,
                    0,
                    0,
                    bitmap.getWidth(),
                    bitmap.getHeight(),
                    matrix,
                    true);
            if (transformed != bitmap) bitmap.recycle();
        }
        double ratio = editorCropRatio(settings.cropRatio);
        if (ratio <= 0) {
            return transformed;
        }
        int width = transformed.getWidth();
        int height = transformed.getHeight();
        int cropWidth = width;
        int cropHeight = (int)Math.round(width / ratio);
        if (cropHeight > height) {
            cropHeight = height;
            cropWidth = (int)Math.round(height * ratio);
        }
        Bitmap cropped = Bitmap.createBitmap(
                transformed,
                Math.max(0, (width - cropWidth) / 2),
                Math.max(0, (height - cropHeight) / 2),
                Math.max(1, cropWidth),
                Math.max(1, cropHeight));
        if (cropped != transformed) transformed.recycle();
        return cropped;
    }

    private double editorCropRatio(String cropRatio) {
        switch (cropRatio) {
            case "1:1":
                return 1;
            case "4:3":
                return 4.0 / 3;
            case "3:2":
                return 3.0 / 2;
            case "16:9":
                return 16.0 / 9;
            default:
                return 0;
        }
    }

    private static double smoothStep(
            double edge0,
            double edge1,
            double value) {
        double scaled = clampUnit((value - edge0) / (edge1 - edge0));
        return scaled * scaled * (3 - 2 * scaled);
    }

    private static double clampUnit(double value) {
        return Math.max(0, Math.min(1, value));
    }

    private static int editorChannel(double value) {
        return (int)Math.max(0, Math.min(255, Math.round(value)));
    }

    private File uniqueEditedFile(File source) {
        String filename = source.getName();
        int dot = filename.lastIndexOf('.');
        String stem = dot > 0 ? filename.substring(0, dot) : filename;
        File destination = new File(
                photoDirectory,
                stem + "_edited.jpg");
        if (!destination.exists()) return destination;
        return new File(
                photoDirectory,
                stem + "_edited_" + System.currentTimeMillis() + ".jpg");
    }

    private View buildBranchWorkspace(List<File> files) {
        LinearLayout workspace = panel();
        workspace.setPadding(dp(14), dp(14), dp(14), dp(14));
        workspace.addView(buildUserBranchTree(files));

        List<File> unclassified = new ArrayList<>();
        for (File file : files) {
            if (!libraryFileAssignments.containsKey(file.getAbsolutePath())) {
                unclassified.add(file);
            }
        }
        LinearLayout uncategorizedBody = verticalContainer();
        if (unclassified.isEmpty()) {
            TextView empty = text(
                    "未分类已清空\n拍摄、导入或无线接收的新文件会先显示在这里。",
                    14,
                    Typeface.NORMAL,
                    MUTED);
            empty.setGravity(Gravity.CENTER);
            uncategorizedBody.addView(empty, new LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    dp(120)));
        } else {
            uncategorizedBody.addView(localFileTypeGroup(
                    "local-photos",
                    "照片",
                    unclassified,
                    false));
            uncategorizedBody.addView(localFileTypeGroup(
                    "local-videos",
                    "视频",
                    unclassified,
                    true));
        }
        View unclassifiedGroup = collapsibleGroup(
                "local-unclassified",
                "未分类",
                unclassified.size() + " 个文件",
                uncategorizedBody,
                true);
        configureLibraryDropTarget(
                unclassifiedGroup,
                null,
                SURFACE,
                18);
        workspace.addView(unclassifiedGroup);
        workspace.setLayoutParams(marginParams(-1, -2, 0, 0, 0, 16));
        return workspace;
    }

    private View collapsibleGroup(
            String key,
            String title,
            String subtitle,
            View body,
            boolean initiallyExpanded) {
        LinearLayout group = panel();
        boolean expanded = disclosureStates.containsKey(key)
                ? Boolean.TRUE.equals(disclosureStates.get(key))
                : initiallyExpanded;
        disclosureStates.put(key, expanded);
        Button header = nativeButton("", false);
        header.setGravity(Gravity.START | Gravity.CENTER_VERTICAL);
        header.setText(
                (expanded ? "⌄  " : "›  ")
                        + tr(title)
                        + " · "
                        + tr(subtitle));
        body.setVisibility(expanded ? View.VISIBLE : View.GONE);
        header.setOnClickListener(view -> {
            boolean next = body.getVisibility() != View.VISIBLE;
            disclosureStates.put(key, next);
            body.setVisibility(next ? View.VISIBLE : View.GONE);
            header.setText(
                    (next ? "⌄  " : "›  ")
                            + tr(title)
                            + " · "
                            + tr(subtitle));
        });
        group.addView(header, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(48)));
        group.addView(body);
        group.setLayoutParams(marginParams(-1, -2, 0, 0, 0, 12));
        return group;
    }

    private View buildUserBranchTree(List<File> files) {
        LinearLayout tree = verticalContainer();
        LinearLayout heading = new LinearLayout(this);
        heading.setOrientation(LinearLayout.HORIZONTAL);
        heading.setGravity(Gravity.CENTER_VERTICAL);
        heading.addView(
                text("用户分支", 15, Typeface.BOLD, INK),
                new LinearLayout.LayoutParams(0, dp(48), 1f));
        Button add = nativeButton("＋ 新建分支", false);
        add.setOnClickListener(view -> showCreateLibraryBranchDialog(null));
        heading.addView(add, new LinearLayout.LayoutParams(dp(132), dp(44)));
        tree.addView(heading);

        if (userLibraryBranches.isEmpty()) {
            tree.addView(
                    text(
                            "可建立项目、客户或拍摄日等分支；媒体仍保留在原始存储位置。",
                            12,
                            Typeface.NORMAL,
                            MUTED),
                    marginParams(-1, -2, 0, 4, 0, 10));
        } else {
            for (LibraryBranch branch : userLibraryBranches) {
                tree.addView(buildLibraryBranchView(branch, 0, files));
            }
        }
        return tree;
    }

    private View buildLibraryBranchView(
            LibraryBranch branch,
            int depth,
            List<File> files) {
        LinearLayout group = verticalContainer();
        String disclosureKey = "library-branch-" + branch.id;
        boolean expanded = disclosureStates.containsKey(disclosureKey)
                ? Boolean.TRUE.equals(disclosureStates.get(disclosureKey))
                : true;
        disclosureStates.put(disclosureKey, expanded);

        LinearLayout header = new LinearLayout(this);
        header.setOrientation(LinearLayout.HORIZONTAL);
        header.setGravity(Gravity.CENTER_VERTICAL);
        header.setPadding(dp(8 + depth * 14), 0, dp(4), 0);
        header.setBackground(rounded(
                depth == 0 ? PAPER_2 : Color.rgb(247, 249, 252),
                10,
                RULE));
        Button toggle = nativeButton(expanded ? "⌄" : "›", false);
        TextView name = text(
                "▱  " + branch.name,
                14,
                Typeface.BOLD,
                INK);
        List<File> assignedFiles = filesAssignedToBranch(branch.id, files);
        TextView count = text(
                assignedFiles.size() + " 文件",
                11,
                Typeface.NORMAL,
                MUTED);
        count.setGravity(Gravity.CENTER);
        Button add = nativeButton("＋", false);
        add.setContentDescription(tr("在 " + branch.name + " 下新建分支"));
        add.setOnClickListener(
                view -> showCreateLibraryBranchDialog(branch.id));
        Button delete = nativeButton("删", false);
        delete.setTextColor(VIDEO);
        delete.setContentDescription(tr("删除分支 " + branch.name));
        delete.setOnClickListener(
                view -> showDeleteLibraryBranchDialog(branch));

        LinearLayout body = verticalContainer();
        for (File file : assignedFiles) {
            body.addView(photoRow(file));
        }
        if (assignedFiles.isEmpty() && branch.children.isEmpty()) {
            TextView empty = text(
                    "拖动文件到这里",
                    12,
                    Typeface.NORMAL,
                    MUTED);
            empty.setPadding(dp(54 + (depth + 1) * 14), 0, 0, 0);
            body.addView(empty, new LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    dp(36)));
        }
        for (LibraryBranch child : branch.children) {
            body.addView(buildLibraryBranchView(
                    child,
                    depth + 1,
                    files));
        }
        body.setVisibility(expanded ? View.VISIBLE : View.GONE);
        View.OnClickListener toggleListener = view -> {
            boolean next = body.getVisibility() != View.VISIBLE;
            disclosureStates.put(disclosureKey, next);
            body.setVisibility(next ? View.VISIBLE : View.GONE);
            toggle.setText(next ? "⌄" : "›");
        };
        toggle.setOnClickListener(toggleListener);
        name.setOnClickListener(toggleListener);
        count.setOnClickListener(toggleListener);

        header.addView(toggle, new LinearLayout.LayoutParams(dp(52), dp(52)));
        header.addView(name, new LinearLayout.LayoutParams(0, dp(52), 1f));
        header.addView(count, new LinearLayout.LayoutParams(dp(64), dp(52)));
        header.addView(add, new LinearLayout.LayoutParams(dp(44), dp(44)));
        header.addView(delete, new LinearLayout.LayoutParams(dp(44), dp(44)));
        configureLibraryDropTarget(
                header,
                branch.id,
                depth == 0 ? PAPER_2 : Color.rgb(247, 249, 252),
                10);
        group.addView(
                header,
                marginParams(-1, dp(52), 0, 0, 0, 4));
        group.addView(body);
        return group;
    }

    private void showCreateLibraryBranchDialog(String parentId) {
        EditText input = new EditText(this);
        input.setSingleLine(true);
        input.setHint(tr("分支名称"));
        input.setPadding(dp(16), dp(8), dp(16), dp(8));
        LibraryBranch parent = findLibraryBranch(parentId);
        new AlertDialog.Builder(this)
                .setTitle(tr("新建分支"))
                .setMessage(tr(
                        "将在“"
                                + (parent == null
                                ? "帧澈 ZENCHE 文件库"
                                : parent.name)
                                + "”下创建可继续展开的节点。"))
                .setView(input)
                .setNegativeButton(tr("取消"), null)
                .setPositiveButton(tr("创建"), (dialog, which) -> {
                    String name = input.getText().toString().trim();
                    if (name.isEmpty()) {
                        showToast("请输入分支名称。");
                        return;
                    }
                    LibraryBranch branch = new LibraryBranch(
                            UUID.randomUUID().toString(),
                            name);
                    if (parent == null) {
                        userLibraryBranches.add(branch);
                    } else {
                        parent.children.add(branch);
                        disclosureStates.put(
                                "library-branch-" + parent.id,
                                true);
                    }
                    saveLibraryBranches();
                    showSection("library");
                })
                .show();
    }

    private void showDeleteLibraryBranchDialog(LibraryBranch branch) {
        new AlertDialog.Builder(this)
                .setTitle(tr("删除分支？"))
                .setMessage(tr(
                        "将同时删除“"
                                + branch.name
                                + "”下的子分支；其中的文件会回到“未分类”，原文件不受影响。"))
                .setNegativeButton(tr("取消"), null)
                .setPositiveButton(tr("删除分支"), (dialog, which) -> {
                    deleteLibraryBranch(branch.id);
                    showSection("library");
                })
                .show();
    }

    private void deleteLibraryBranch(String id) {
        LibraryBranch branch = findLibraryBranch(id);
        if (branch == null) return;
        Set<String> removedIds = new HashSet<>();
        branch.collectIds(removedIds);
        if (!removeLibraryBranch(userLibraryBranches, id)) return;
        for (String removedId : removedIds) {
            disclosureStates.remove("library-branch-" + removedId);
        }
        java.util.Iterator<Map.Entry<String, String>> assignments =
                libraryFileAssignments.entrySet().iterator();
        while (assignments.hasNext()) {
            if (removedIds.contains(assignments.next().getValue())) {
                assignments.remove();
            }
        }
        saveLibraryBranches();
        saveLibraryFileAssignments();
        showToast("分支已删除，文件已回到未分类");
    }

    private boolean removeLibraryBranch(
            List<LibraryBranch> branches,
            String id) {
        for (int index = 0; index < branches.size(); index++) {
            LibraryBranch branch = branches.get(index);
            if (branch.id.equals(id)) {
                branches.remove(index);
                return true;
            }
            if (removeLibraryBranch(branch.children, id)) {
                return true;
            }
        }
        return false;
    }

    private LibraryBranch findLibraryBranch(String id) {
        if (id == null) return null;
        for (LibraryBranch branch : userLibraryBranches) {
            LibraryBranch found = branch.find(id);
            if (found != null) return found;
        }
        return null;
    }

    private void loadLibraryBranches() {
        userLibraryBranches.clear();
        libraryFileAssignments.clear();
        android.content.SharedPreferences preferences =
                getSharedPreferences("nikon-link", MODE_PRIVATE);
        String serialized = preferences.getString(LIBRARY_BRANCHES_KEY, "[]");
        try {
            JSONArray array = new JSONArray(serialized);
            for (int index = 0; index < array.length(); index++) {
                userLibraryBranches.add(
                        LibraryBranch.fromJson(array.getJSONObject(index)));
            }
        } catch (Exception ignored) {
            userLibraryBranches.clear();
        }
        try {
            JSONObject assignments = new JSONObject(
                    preferences.getString(
                            LIBRARY_FILE_ASSIGNMENTS_KEY,
                            "{}"));
            java.util.Iterator<String> keys = assignments.keys();
            while (keys.hasNext()) {
                String path = keys.next();
                libraryFileAssignments.put(
                        path,
                        assignments.optString(path, ""));
            }
        } catch (Exception ignored) {
            libraryFileAssignments.clear();
        }
    }

    private void saveLibraryBranches() {
        JSONArray array = new JSONArray();
        for (LibraryBranch branch : userLibraryBranches) {
            array.put(branch.toJson());
        }
        getSharedPreferences("nikon-link", MODE_PRIVATE)
                .edit()
                .putString(LIBRARY_BRANCHES_KEY, array.toString())
                .apply();
    }

    private void saveLibraryFileAssignments() {
        JSONObject assignments = new JSONObject();
        try {
            for (Map.Entry<String, String> entry
                    : libraryFileAssignments.entrySet()) {
                assignments.put(entry.getKey(), entry.getValue());
            }
        } catch (Exception ignored) {
        }
        getSharedPreferences("nikon-link", MODE_PRIVATE)
                .edit()
                .putString(
                        LIBRARY_FILE_ASSIGNMENTS_KEY,
                        assignments.toString())
                .apply();
    }

    private List<File> filesAssignedToBranch(
            String branchId,
            List<File> files) {
        List<File> assigned = new ArrayList<>();
        for (File file : files) {
            if (branchId.equals(
                    libraryFileAssignments.get(file.getAbsolutePath()))) {
                assigned.add(file);
            }
        }
        return assigned;
    }

    private void configureLibraryDropTarget(
            View target,
            String branchId,
            int normalColor,
            int radius) {
        target.setOnDragListener((view, event) -> {
            switch (event.getAction()) {
                case DragEvent.ACTION_DRAG_STARTED:
                    return event.getLocalState() instanceof File;
                case DragEvent.ACTION_DRAG_ENTERED:
                    view.setBackground(rounded(COBALT_SOFT, radius, COBALT));
                    return true;
                case DragEvent.ACTION_DRAG_EXITED:
                case DragEvent.ACTION_DRAG_ENDED:
                    view.setBackground(rounded(normalColor, radius, RULE));
                    return true;
                case DragEvent.ACTION_DROP:
                    if (!(event.getLocalState() instanceof File)) return false;
                    File file = (File) event.getLocalState();
                    if (branchId == null) {
                        libraryFileAssignments.remove(file.getAbsolutePath());
                    } else {
                        libraryFileAssignments.put(
                                file.getAbsolutePath(),
                                branchId);
                        disclosureStates.put(
                                "library-branch-" + branchId,
                                true);
                    }
                    saveLibraryFileAssignments();
                    showToast(
                            branchId == null
                                    ? "已移到未分类"
                                    : "已移到分支");
                    showSection("library");
                    return true;
                default:
                    return true;
            }
        });
    }

    private View systemMediaTypeGroup(
            String key,
            String title,
            List<MediaEntry> entries,
            boolean video) {
        LinearLayout body = verticalContainer();
        int count = 0;
        for (MediaEntry entry : entries) {
            if (entry.video != video) continue;
            count++;
            body.addView(systemMediaRow(entry));
        }
        if (count == 0) {
            body.addView(text(
                    "暂无" + title,
                    13,
                    Typeface.NORMAL,
                    MUTED));
        }
        return collapsibleGroup(key, title, count + " 个", body, true);
    }

    private View localFileTypeGroup(
            String key,
            String title,
            List<File> files,
            boolean video) {
        LinearLayout body = verticalContainer();
        int count = 0;
        for (File file : files) {
            if (isVideoFile(file) != video) continue;
            count++;
            body.addView(photoRow(file));
        }
        if (count == 0) {
            body.addView(text(
                    "暂无" + title,
                    13,
                    Typeface.NORMAL,
                    MUTED));
        }
        return collapsibleGroup(key, title, count + " 个", body, true);
    }

    private List<MediaEntry> systemAlbumEntries() {
        List<MediaEntry> result = new ArrayList<>();
        Uri collection = MediaStore.Files.getContentUri("external");
        String[] projection = new String[]{
                MediaStore.Files.FileColumns._ID,
                MediaStore.Files.FileColumns.DISPLAY_NAME,
                MediaStore.Files.FileColumns.MEDIA_TYPE,
                MediaStore.Files.FileColumns.DATE_ADDED,
                MediaStore.Files.FileColumns.SIZE,
                MediaStore.Video.VideoColumns.DURATION
        };
        String selection =
                MediaStore.Files.FileColumns.MEDIA_TYPE + "=? OR "
                        + MediaStore.Files.FileColumns.MEDIA_TYPE + "=?";
        String[] args = new String[]{
                String.valueOf(MediaStore.Files.FileColumns.MEDIA_TYPE_IMAGE),
                String.valueOf(MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO)
        };
        try (Cursor cursor = getContentResolver().query(
                collection,
                projection,
                selection,
                args,
                MediaStore.Files.FileColumns.DATE_ADDED + " DESC")) {
            if (cursor == null) return result;
            int idIndex = cursor.getColumnIndexOrThrow(
                    MediaStore.Files.FileColumns._ID);
            int nameIndex = cursor.getColumnIndexOrThrow(
                    MediaStore.Files.FileColumns.DISPLAY_NAME);
            int typeIndex = cursor.getColumnIndexOrThrow(
                    MediaStore.Files.FileColumns.MEDIA_TYPE);
            int dateIndex = cursor.getColumnIndexOrThrow(
                    MediaStore.Files.FileColumns.DATE_ADDED);
            int sizeIndex = cursor.getColumnIndexOrThrow(
                    MediaStore.Files.FileColumns.SIZE);
            int durationIndex = cursor.getColumnIndex(
                    MediaStore.Video.VideoColumns.DURATION);
            while (cursor.moveToNext() && result.size() < 60) {
                long id = cursor.getLong(idIndex);
                boolean video = cursor.getInt(typeIndex)
                        == MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO;
                result.add(new MediaEntry(
                        ContentUris.withAppendedId(collection, id),
                        cursor.getString(nameIndex),
                        video,
                        Math.max(0, cursor.getLong(dateIndex) * 1000L),
                        Math.max(0, cursor.getLong(sizeIndex)),
                        durationIndex >= 0
                                ? Math.max(0, cursor.getLong(durationIndex))
                                : 0));
            }
        } catch (RuntimeException error) {
            diagnostics.warning(
                    "library",
                    "读取系统相册失败：" + error.getMessage());
        }
        return result;
    }

    private View systemMediaRow(MediaEntry entry) {
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(Gravity.CENTER_VERTICAL);
        row.setPadding(dp(10), dp(10), dp(10), dp(10));
        row.setBackground(rounded(SURFACE, 12, RULE));
        row.setContentDescription(
                "系统相册，双击" + (entry.video ? "播放 " : "查看 ") + entry.name);
        GestureDetector doubleTap = new GestureDetector(
                this,
                new GestureDetector.SimpleOnGestureListener() {
                    @Override public boolean onDown(MotionEvent event) { return true; }
                    @Override
                    public boolean onDoubleTap(MotionEvent event) {
                        showLargeSystemMedia(entry);
                        return true;
                    }
                });
        row.setOnTouchListener((view, event) -> doubleTap.onTouchEvent(event));

        ImageView thumbnail = new ImageView(this);
        thumbnail.setScaleType(ImageView.ScaleType.CENTER_CROP);
        thumbnail.setBackgroundColor(GRAPHITE);
        try {
            Bitmap bitmap;
            if (Build.VERSION.SDK_INT >= 29) {
                bitmap = getContentResolver().loadThumbnail(
                        entry.uri,
                        new Size(dp(216), dp(152)),
                        null);
            } else {
                try (InputStream input =
                             getContentResolver().openInputStream(entry.uri)) {
                    bitmap = BitmapFactory.decodeStream(input);
                }
            }
            thumbnail.setImageBitmap(bitmap);
        } catch (Exception ignored) {
            thumbnail.setImageResource(
                    entry.video
                            ? android.R.drawable.ic_media_play
                            : android.R.drawable.ic_menu_gallery);
        }
        row.addView(thumbnail, new LinearLayout.LayoutParams(dp(108), dp(76)));

        LinearLayout details = new LinearLayout(this);
        details.setOrientation(LinearLayout.VERTICAL);
        details.setPadding(dp(12), 0, dp(8), 0);
        details.addView(text(entry.name, 13, Typeface.BOLD, INK));
        String duration = entry.video
                ? " · " + formatDuration(entry.durationMillis)
                : "";
        details.addView(text(
                "系统相册 · " + humanSize(entry.size) + duration + " · "
                        + new SimpleDateFormat(
                                "MM-dd HH:mm",
                                Locale.CHINA).format(new Date(entry.dateMillis)),
                11,
                Typeface.NORMAL,
                MUTED));
        details.addView(text(
                entry.video ? "双击播放视频" : "双击查看大图",
                11,
                Typeface.NORMAL,
                COBALT));
        row.addView(details, new LinearLayout.LayoutParams(0, dp(76), 1f));

        Button share = nativeButton("分享", false);
        share.setOnClickListener(view -> shareMediaUri(entry));
        row.addView(share, new LinearLayout.LayoutParams(dp(78), dp(44)));
        return row;
    }

    private View photoRow(File file) {
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(Gravity.CENTER_VERTICAL);
        row.setPadding(dp(10), dp(10), dp(10), dp(10));
        row.setBackground(rounded(SURFACE, 12, RULE));
        LinearLayout.LayoutParams rowParams = marginParams(-1, dp(96), 0, 0, 0, 10);
        row.setLayoutParams(rowParams);
        row.setContentDescription("双击查看 " + file.getName() + " 大图");
        GestureDetector doubleTap = new GestureDetector(
                this,
                new GestureDetector.SimpleOnGestureListener() {
                    @Override
                    public boolean onDown(MotionEvent event) {
                        return true;
                    }

                    @Override
                    public boolean onDoubleTap(MotionEvent event) {
                        showLargePhoto(file);
                        return true;
                    }

                    @Override
                    public void onLongPress(MotionEvent event) {
                        startLibraryFileDrag(row, file);
                    }
                });
        row.setOnTouchListener((view, event) -> doubleTap.onTouchEvent(event));

        BitmapFactory.Options options = new BitmapFactory.Options();
        options.inSampleSize = 4;
        ImageView thumbnail = new ImageView(this);
        thumbnail.setScaleType(ImageView.ScaleType.CENTER_CROP);
        if (isVideoFile(file)) {
            thumbnail.setImageResource(android.R.drawable.ic_media_play);
        } else {
            thumbnail.setImageBitmap(
                    BitmapFactory.decodeFile(file.getAbsolutePath(), options));
        }
        thumbnail.setBackgroundColor(GRAPHITE);
        row.addView(thumbnail, new LinearLayout.LayoutParams(dp(108), dp(76)));

        LinearLayout details = new LinearLayout(this);
        details.setOrientation(LinearLayout.VERTICAL);
        details.setPadding(dp(12), 0, dp(8), 0);
        details.addView(text(file.getName(), 13, Typeface.BOLD, INK));
        details.addView(text(
                humanSize(file.length()) + " · " + new SimpleDateFormat(
                        "MM-dd HH:mm",
                        Locale.CHINA).format(new Date(file.lastModified())),
                11,
                Typeface.NORMAL,
                MUTED));
        details.addView(text(
                isVideoFile(file) ? "双击播放视频" : "双击查看大图",
                11,
                Typeface.NORMAL,
                COBALT));
        row.addView(details, new LinearLayout.LayoutParams(0, dp(76), 1f));

        LinearLayout actions = new LinearLayout(this);
        actions.setOrientation(LinearLayout.VERTICAL);
        Button share = nativeButton("分享", false);
        share.setOnClickListener(view -> sharePhoto(file));
        actions.addView(share, new LinearLayout.LayoutParams(dp(72), dp(36)));
        Button delete = nativeButton("删除", false);
        delete.setOnClickListener(view -> new AlertDialog.Builder(this)
                .setTitle(tr("删除照片？"))
                .setMessage(file.getName())
                .setNegativeButton(tr("取消"), null)
                .setPositiveButton(tr("删除"), (dialog, which) -> {
                    if (!file.delete()) {
                        showToast("无法删除文件。");
                    } else {
                        libraryFileAssignments.remove(file.getAbsolutePath());
                        saveLibraryFileAssignments();
                    }
                    showSection("library");
                    updateFileCount();
                })
                .show());
        LinearLayout.LayoutParams deleteParams =
                new LinearLayout.LayoutParams(dp(72), dp(36));
        deleteParams.setMargins(0, dp(4), 0, 0);
        actions.addView(delete, deleteParams);
        row.addView(actions, new LinearLayout.LayoutParams(dp(72), dp(76)));
        return row;
    }

    private void startLibraryFileDrag(View source, File file) {
        ClipData data = ClipData.newPlainText(
                "zenche-library-file",
                file.getAbsolutePath());
        View.DragShadowBuilder shadow = new View.DragShadowBuilder(source);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            source.startDragAndDrop(data, shadow, file, 0);
        } else {
            source.startDrag(data, shadow, file, 0);
        }
    }

    private View buildWirelessTransferPanel() {
        LinearLayout settings = panel();
        settings.addView(text("多协议无线图片收件箱", 18, Typeface.BOLD, INK));
        settings.addView(text(
                wirelessStatus,
                13,
                Typeface.NORMAL,
                MUTED),
                marginParams(-1, -2, 0, 3, 0, 12));

        wirelessAddressText = text(
                wirelessSettingsText(),
                13,
                Typeface.NORMAL,
                INK);
        wirelessAddressText.setTextIsSelectable(true);
        settings.addView(wirelessAddressText);

        wirelessButton = nativeButton(
                wirelessRequested ? "停止接收" : "开启无线接收",
                !wirelessRequested);
        wirelessButton.setOnClickListener(view -> {
            if (wirelessRequested) {
                wirelessRequested = false;
                wirelessServer.stop();
            } else {
                wirelessRequested = true;
                wirelessStatus = "正在开启无线收件箱…";
                wirelessServer.start();
            }
            updateWirelessUi();
        });
        settings.addView(
                wirelessButton,
                marginParams(-1, dp(48), 0, 16, 0, 0));
        wirelessStatusText = text(
                "相机可使用 FTP/PASV；手机、电脑和自动化工具可使用 HTTP 上传或 WebDAV PUT。接收完成后照片会直接进入文件库。",
                12,
                Typeface.NORMAL,
                MUTED);
        settings.addView(
                wirelessStatusText,
                marginParams(-1, -2, 0, 10, 0, 0));
        return settings;
    }

    private View buildSettingsView() {
        ScrollView scroll = new ScrollView(this);
        LinearLayout content = verticalContainer();
        content.setPadding(dp(20), dp(22), dp(20), dp(24));
        content.addView(sectionHeader(
                "设置",
                "更新、诊断与支持。",
                COBALT));

        LinearLayout languagePanel = panel();
        languagePanel.addView(text("语言", 18, Typeface.BOLD, INK));
        languagePanel.addView(text(
                "语言更改会立即应用，并在下次启动时保留。",
                12,
                Typeface.NORMAL,
                MUTED),
                marginParams(-1, -2, 0, 5, 0, 10));
        Spinner languageSpinner = new Spinner(this);
        String[] languageNames = new String[]{"简体中文", "English", "日本語"};
        String[] languageCodes = new String[]{
                Localization.SIMPLIFIED_CHINESE,
                Localization.ENGLISH,
                Localization.JAPANESE};
        ArrayAdapter<String> languageAdapter = new ArrayAdapter<>(
                this,
                android.R.layout.simple_spinner_item,
                languageNames);
        languageAdapter.setDropDownViewResource(
                android.R.layout.simple_spinner_dropdown_item);
        languageSpinner.setAdapter(languageAdapter);
        languageSpinner.setSelection(
                Math.max(0, Arrays.asList(languageCodes).indexOf(appLanguage)),
                false);
        languageSpinner.setBackground(rounded(
                Color.rgb(241, 244, 249),
                9,
                RULE));
        languageSpinner.setPadding(dp(10), 0, dp(8), 0);
        languageSpinner.setOnItemSelectedListener(
                new android.widget.AdapterView.OnItemSelectedListener() {
                    @Override
                    public void onItemSelected(
                            android.widget.AdapterView<?> parent,
                            View view,
                            int position,
                            long id) {
                        changeLanguage(languageCodes[position]);
                    }

                    @Override
                    public void onNothingSelected(
                            android.widget.AdapterView<?> parent) {}
                });
        languagePanel.addView(languageSpinner, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(48)));
        content.addView(
                languagePanel,
                marginParams(-1, -2, 0, 18, 0, 0));

        LinearLayout aiPanel = panel();
        aiPanel.addView(text("AI 服务", 18, Typeface.BOLD, INK));
        aiPanel.addView(text(
                "AI 修图与生图通过代理服务器调用；服务器负责计数与扣减次数。",
                12,
                Typeface.NORMAL,
                MUTED),
                marginParams(-1, -2, 0, 5, 0, 10));
        EditText aiServerUrlInput = new EditText(this);
        aiServerUrlInput.setHint(tr("AI 服务器地址"));
        aiServerUrlInput.setInputType(InputType.TYPE_CLASS_TEXT
                | InputType.TYPE_TEXT_VARIATION_URI);
        aiServerUrlInput.setSingleLine(true);
        aiServerUrlInput.setText(aiServerUrl());
        aiServerUrlInput.setBackground(rounded(PAPER_2, 8, RULE));
        aiServerUrlInput.setPadding(dp(12), 0, dp(12), 0);
        aiPanel.addView(
                aiServerUrlInput,
                marginParams(-1, dp(44), 0, 0, 0, 6));
        aiPanel.addView(text(
                "留空使用默认地址 " + "http://101.34.255.115:8787。",
                11,
                Typeface.NORMAL,
                MUTED),
                marginParams(-1, -2, 0, 0, 0, 8));
        Button saveAiServerUrl = nativeButton("保存服务器地址", false);
        saveAiServerUrl.setOnClickListener(view -> {
            String value = aiServerUrlInput.getText().toString().trim();
            getSharedPreferences("nikon-link", MODE_PRIVATE)
                    .edit()
                    .putString("aiServerURL", value)
                    .apply();
            showToast(value.isEmpty() ? "AI 服务器地址已重置" : "AI 服务器地址已保存");
        });
        aiPanel.addView(
                saveAiServerUrl,
                marginParams(-1, dp(44), 0, 0, 0, 0));
        content.addView(
                aiPanel,
                marginParams(-1, -2, 0, 18, 0, 0));

        LinearLayout updatePanel = panel();
        updatePanel.addView(text("软件更新", 18, Typeface.BOLD, INK));
        updatePanel.addView(text(
                "当前版本 " + currentVersion()
                        + " · 优先通过 Mirror酱检查更新，无可用 CDN 下载地址时自动回退 GitHub Releases。",
                12,
                Typeface.NORMAL,
                MUTED),
                marginParams(-1, -2, 0, 5, 0, 10));
        Switch automaticUpdates = new Switch(this);
        automaticUpdates.setText(tr("启动时自动检查更新"));
        automaticUpdates.setTextColor(INK);
        automaticUpdates.setChecked(
                getSharedPreferences("nikon-link", MODE_PRIVATE)
                        .getBoolean(AUTOMATIC_UPDATE_KEY, true));
        automaticUpdates.setOnCheckedChangeListener((button, enabled) -> {
            getSharedPreferences("nikon-link", MODE_PRIVATE)
                    .edit()
                    .putBoolean(AUTOMATIC_UPDATE_KEY, enabled)
                    .apply();
            if (enabled) checkForUpdates(true);
        });
        updatePanel.addView(
                automaticUpdates,
                marginParams(-1, -2, 0, 0, 0, 10));
        EditText mirrorChyanCdk = new EditText(this);
        mirrorChyanCdk.setHint(tr("Mirror酱 CDK（可选）"));
        mirrorChyanCdk.setInputType(
                InputType.TYPE_CLASS_TEXT
                        | InputType.TYPE_TEXT_VARIATION_PASSWORD);
        mirrorChyanCdk.setSingleLine(true);
        mirrorChyanCdk.setText(loadMirrorChyanCdk());
        mirrorChyanCdk.setBackground(rounded(PAPER_2, 8, RULE));
        mirrorChyanCdk.setPadding(dp(12), 0, dp(12), 0);
        updatePanel.addView(
                mirrorChyanCdk,
                marginParams(-1, dp(44), 0, 0, 0, 6));
        updatePanel.addView(text(
                "CDK 使用 Android Keystore 加密保存，不会写入诊断日志。",
                11,
                Typeface.NORMAL,
                MUTED),
                marginParams(-1, -2, 0, 0, 0, 8));
        LinearLayout mirrorActions = new LinearLayout(this);
        mirrorActions.setOrientation(LinearLayout.HORIZONTAL);
        Button saveMirrorChyanCdk = nativeButton("保存 CDK", false);
        saveMirrorChyanCdk.setOnClickListener(view -> {
            if (saveMirrorChyanCdk(mirrorChyanCdk.getText().toString())) {
                showToast(
                        mirrorChyanCdk.getText().toString().trim().isEmpty()
                                ? "Mirror酱 CDK 已清除"
                                : "Mirror酱 CDK 已安全保存");
            } else {
                showToast("Mirror酱 CDK 保存失败");
            }
        });
        mirrorActions.addView(
                saveMirrorChyanCdk,
                new LinearLayout.LayoutParams(0, dp(44), 1f));
        Button openMirrorChyan = nativeButton("打开 Mirror酱", false);
        openMirrorChyan.setOnClickListener(
                view -> openExternalUrl(mirrorChyanWebsiteUrl()));
        LinearLayout.LayoutParams openMirrorParams =
                new LinearLayout.LayoutParams(0, dp(44), 1f);
        openMirrorParams.setMargins(dp(8), 0, 0, 0);
        mirrorActions.addView(openMirrorChyan, openMirrorParams);
        updatePanel.addView(
                mirrorActions,
                marginParams(-1, -2, 0, 0, 0, 10));
        updateStatusText = text(updateStatus, 12, Typeface.NORMAL, MUTED);
        updatePanel.addView(
                updateStatusText,
                marginParams(-1, -2, 0, 0, 0, 10));
        LinearLayout updateActions = new LinearLayout(this);
        updateActions.setOrientation(LinearLayout.HORIZONTAL);
        checkUpdateButton = nativeButton("检查更新", false);
        checkUpdateButton.setOnClickListener(view -> checkForUpdates(false));
        updateActions.addView(
                checkUpdateButton,
                new LinearLayout.LayoutParams(0, dp(48), 1f));
        openUpdateButton = nativeButton("获取更新", true);
        openUpdateButton.setOnClickListener(view -> openUpdatePage());
        LinearLayout.LayoutParams openUpdateParams =
                new LinearLayout.LayoutParams(0, dp(48), 1f);
        openUpdateParams.setMargins(dp(8), 0, 0, 0);
        updateActions.addView(openUpdateButton, openUpdateParams);
        updatePanel.addView(updateActions);
        content.addView(
                updatePanel,
                marginParams(-1, -2, 0, 18, 0, 0));
        refreshUpdateUi();

        LinearLayout diagnosticsPanel = panel();
        diagnosticsPanel.addView(text("诊断日志", 18, Typeface.BOLD, INK));
        TextView logPath = text(
                "日志按日保存、单个文件达到 5 MB 后滚动，保留 14 天。\n"
                        + diagnostics.getDirectory().getAbsolutePath(),
                12,
                Typeface.NORMAL,
                MUTED);
        logPath.setTextIsSelectable(true);
        diagnosticsPanel.addView(
                logPath,
                marginParams(-1, -2, 0, 5, 0, 12));
        LinearLayout logActions = new LinearLayout(this);
        logActions.setOrientation(LinearLayout.HORIZONTAL);
        Button viewLogs = nativeButton("查询最近日志", false);
        viewLogs.setOnClickListener(view -> showRecentLogs());
        logActions.addView(viewLogs, new LinearLayout.LayoutParams(0, dp(48), 1f));
        Button reportIssue = nativeButton("上传脱敏日志", true);
        reportIssue.setOnClickListener(view -> openGithubIssue());
        LinearLayout.LayoutParams uploadParams = new LinearLayout.LayoutParams(0, dp(48), 1f);
        uploadParams.setMargins(dp(8), 0, 0, 0);
        logActions.addView(reportIssue, uploadParams);
        diagnosticsPanel.addView(logActions);
        diagnosticsPanel.addView(text(
                "将打开含最近脱敏日志的预填页面；在 GitHub 确认后才会提交。",
                11,
                Typeface.NORMAL,
                MUTED),
                marginParams(-1, -2, 0, 8, 0, 0));
        diagnosticsPanel.addView(
                fastFeedbackCard(),
                marginParams(-1, -2, 0, 12, 0, 0));
        content.addView(
                diagnosticsPanel,
                marginParams(-1, -2, 0, 18, 0, 0));

        LinearLayout supportPanel = panel();
        supportPanel.addView(text("喜欢 帧澈 ZENCHE？", 18, Typeface.BOLD, INK));
        supportPanel.addView(text(
                "请作者喝杯奶茶，支持后续维护与新机型适配。",
                13,
                Typeface.NORMAL,
                MUTED),
                marginParams(-1, -2, 0, 4, 0, 12));
        Button donate = nativeButton("请作者喝奶茶", true);
        donate.setOnClickListener(view -> showDonation());
        supportPanel.addView(donate, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(48)));
        content.addView(supportPanel);

        TextView path = text(
                "保存位置\n" + photoDirectory.getAbsolutePath(),
                12,
                Typeface.NORMAL,
                MUTED);
        path.setTextIsSelectable(true);
        content.addView(path, marginParams(-1, -2, 0, 18, 0, 0));
        scroll.addView(content);
        return scroll;
    }

    private String wirelessSettingsText() {
        String host = wirelessServer.getLocalAddress();
        return "FTP/PASV：" + host + ":" + WirelessTransferServer.FTP_PORT
                + "\nHTTP 上传：http://" + host + ":"
                + WirelessTransferServer.HTTP_PORT + "/upload/文件名"
                + "\nWebDAV：http://" + host + ":"
                + WirelessTransferServer.HTTP_PORT + "/"
                + "\n用户名：" + WirelessTransferServer.USERNAME
                + "\n密码：" + WirelessTransferServer.PASSWORD;
    }

    private void updateWirelessUi() {
        if (wirelessButton != null) {
            wirelessButton.setText(
                    tr(wirelessRequested ? "停止接收" : "开启无线接收"));
            wirelessButton.setTextColor(wirelessRequested ? INK : Color.WHITE);
            wirelessButton.setBackground(rounded(
                    wirelessRequested ? SURFACE : COBALT,
                    9,
                    wirelessRequested ? RULE : 0));
        }
        if (wirelessAddressText != null) {
            wirelessAddressText.setText(tr(wirelessSettingsText()));
        }
        if (wirelessStatusText != null) {
            wirelessStatusText.setText(tr(
                    (wirelessRequested ? wirelessStatus + "\n" : "")
                            + "相机端选择 FTP 并开启 PASV；HTTP/WebDAV 使用 Basic Auth，PUT/POST 请求需提供 Content-Length。"));
        }
    }

    private View infoCard(String title, String value) {
        LinearLayout card = panel();
        card.addView(text(title, 16, Typeface.BOLD, INK));
        card.addView(text(value, 13, Typeface.NORMAL, COBALT));
        card.setLayoutParams(marginParams(-1, -2, 0, 0, 0, 12));
        return card;
    }

    private void showConnectionDialog() {
        LinearLayout content = panel();
        content.setPadding(dp(20), dp(18), dp(20), dp(18));

        LinearLayout card = verticalContainer();
        card.setPadding(dp(18), dp(16), dp(18), dp(16));
        card.setBackground(rounded(COBALT_SOFT, 14, 0));
        card.addView(text("Nikon Z 系列原生 USB", 18, Typeface.BOLD, INK));
        card.addView(text(
                PtpCamera.SUPPORTED_CAMERA_SUMMARY.replace("、", " · "),
                12,
                Typeface.BOLD,
                COBALT),
                marginParams(-1, -2, 0, 4, 0, 4));
        card.addView(text(
                "照片拍摄、视频监看、参数控制和文件管理",
                13,
                Typeface.NORMAL,
                MUTED));
        content.addView(card);

        content.addView(text(
                "请打开相机，使用支持数据传输的 USB 线连接，并授权 帧澈 ZENCHE 访问 USB 设备。",
                13,
                Typeface.NORMAL,
                MUTED),
                marginParams(-1, -2, 0, 12, 0, 16));

        new AlertDialog.Builder(this)
                .setTitle(tr("连接相机"))
                .setView(content)
                .setNegativeButton(tr("取消"), null)
                .setPositiveButton(
                        tr("连接 Nikon 相机"),
                        (dialog, which) -> connectCamera())
                .show();
    }

    private void connectCamera() {
        if (connecting || connected) return;
        diagnostics.info("camera", "用户请求连接相机");
        connecting = true;
        updateConnectionUi();
        cameraExecutor.submit(() -> {
            try {
                camera.connect();
                String detectedCameraName = camera.getConnectedCameraName();
                diagnostics.info("camera", "已连接 " + detectedCameraName);
                mainHandler.post(() -> {
                    connectedCameraName = detectedCameraName;
                    connected = true;
                    connecting = false;
                    liveViewEnabled = false;
                    previewFailureCount = 0;
                    showSection(currentSection);
                    updateConnectionUi();
                    statusText.setText(tr(
                            connectedCameraName + " 已连接 · 机身快门可用"));
                    showToast(
                            connectedCameraName
                                    + " 已连接；实时取景仅在你主动开启后接管相机。");
                });
            } catch (Exception error) {
                diagnostics.error("camera", "连接失败：" + error.getMessage());
                mainHandler.post(() -> {
                    connected = false;
                    connecting = false;
                    liveViewEnabled = false;
                    updateConnectionUi();
                    showError(error.getMessage());
                });
            }
        });
    }

    private void disconnectCamera() {
        diagnostics.info("camera", "用户请求断开相机");
        previewGeneration++;
        pendingPreview.set(null);
        connected = false;
        liveViewEnabled = false;
        videoRecording = false;
        cameraExecutor.submit(camera::disconnect);
        connectedCameraName = "Nikon 相机";
        latestFrame = null;
        latestSourceFrame = null;
        latestZebraMask = null;
        updateConnectionUi();
        showSection(currentSection);
    }

    private void toggleLiveView() {
        if (!connected) {
            showConnectionDialog();
            return;
        }
        if (liveViewEnabled) {
            previewGeneration++;
            pendingPreview.set(null);
            liveViewEnabled = false;
            cameraExecutor.submit(camera::stopLiveView);
            updateConnectionUi();
            if (liveViewButton != null) {
                liveViewButton.setText(tr("开启实时取景"));
            }
        } else {
            cameraExecutor.submit(() -> {
                try {
                    camera.startLiveView();
                    mainHandler.post(() -> {
                        liveViewEnabled = true;
                        updateConnectionUi();
                        startPreviewLoop();
                    });
                } catch (Exception error) {
                    diagnostics.error(
                            "liveview",
                            "开启实时取景失败：" + error.getMessage());
                    mainHandler.post(() -> showError(error.getMessage()));
                }
            });
        }
    }

    private void startPreviewLoop() {
        previewFailureCount = 0;
        previewAnalysisSequence = 0;
        pendingPreview.set(null);
        int generation = ++previewGeneration;
        pullPreview(generation);
    }

    private void pullPreview(int generation) {
        if (!connected || !liveViewEnabled || generation != previewGeneration) return;
        cameraExecutor.submit(() -> {
            try {
                if (generation != previewGeneration
                        || !connected
                        || !liveViewEnabled) {
                    return;
                }
                byte[] jpeg = camera.getLiveViewFrame();
                if (generation != previewGeneration) return;
                previewFailureCount = 0;
                enqueuePreviewFrame(
                        new PreviewPacket(
                                generation,
                                jpeg,
                                "monitor".equals(currentSection)
                                        || immersiveMonitoring));
                mainHandler.post(() -> {
                    if (generation == previewGeneration) pullPreview(generation);
                });

                mainHandler.post(() -> {
                    if (generation != previewGeneration) return;
                    statusText.setText(
                            connectedCameraName + " LIVE · USB/PTP");
                    // next pull triggered immediately after enqueue
                });
            } catch (Exception error) {
                int failures = ++previewFailureCount;
                diagnostics.warning(
                        "liveview",
                        "获取实时取景帧失败（"
                                + failures
                                + "/3）："
                                + error.getMessage());
                mainHandler.post(() -> {
                    if (generation != previewGeneration) return;
                    if (failures >= 3) {
                        previewGeneration++;
                        liveViewEnabled = false;
                        previewFailureCount = 0;
                        cameraExecutor.submit(camera::stopLiveView);
                        updateConnectionUi();
                        statusText.setText(
                                tr("实时取景已安全停止 · 机身控制已释放"));
                        showError(
                                "连续 3 次未收到实时取景画面，帧澈 ZENCHE 已停止重试并释放相机。"
                                        + "请检查 USB 线与相机实时取景状态后再开启。");
                    } else {
                        statusText.setText(
                                tr("实时取景正在重试 · ") + failures + "/3");
                        mainHandler.postDelayed(
                                () -> pullPreview(generation),
                                1200);
                    }
                });
            }
        });
    }

    private void enqueuePreviewFrame(PreviewPacket packet) {
        pendingPreview.set(packet);
        startPreviewWorker();
    }

    private void startPreviewWorker() {
        if (!previewWorkerRunning.compareAndSet(false, true)) return;
        previewExecutor.submit(() -> {
            try {
                PreviewPacket packet = pendingPreview.getAndSet(null);
                if (packet == null
                        || packet.generation != previewGeneration
                        || !connected
                        || !liveViewEnabled) {
                    return;
                }
                BitmapFactory.Options decodeOpts = new BitmapFactory.Options();
                if (packet.monitoring) {
                    decodeOpts.inSampleSize = 2;
                }
                Bitmap source = BitmapFactory.decodeByteArray(
                        packet.jpeg,
                        0,
                        packet.jpeg.length,
                        decodeOpts);
                if (source == null) {
                    diagnostics.warning(
                            "liveview",
                            "收到实时取景数据，但 JPEG 解码失败。");
                    return;
                }
                boolean visualProcessing =
                        lutEnabled
                                || focusPeakingEnabled
                                || falseColorEnabled
                                || zebraEnabled;
                boolean analyzeFrame =
                        visualProcessing
                                || previewAnalysisSequence++ % (videoRecording ? 6 : 3) == 0;
                ProcessedPreview output =
                        packet.monitoring && analyzeFrame
                                ? processPreview(source)
                                : new ProcessedPreview(
                                        packet.monitoring
                                                ? resampleMonitorPreview(source)
                                                : source,
                                        null);
                mainHandler.post(() -> {
                    if (packet.generation != previewGeneration
                            || !connected
                            || !liveViewEnabled) {
                        return;
                    }
                    showProcessedPreview(source, output);
                });
            } catch (RuntimeException error) {
                diagnostics.warning(
                        "liveview",
                        "实时取景帧处理失败：" + error.getMessage());
            } finally {
                previewWorkerRunning.set(false);
                if (pendingPreview.get() != null) {
                    startPreviewWorker();
                }
            }
        });
    }

    private void capturePhoto() {
        if (!connected) {
            showConnectionDialog();
            return;
        }
        if (capturing) return;
        capturing = true;
        if (shutterButton != null) shutterButton.setText(tr("拍摄中…"));
        cameraExecutor.submit(() -> {
            try {
                byte[] jpeg = camera.capture();
                boolean liveViewRestored = camera.isLiveView();
                File file = savePhoto(jpeg);
                diagnostics.info(
                        "capture",
                        "拍摄完成；文件=" + file.getName()
                                + "；大小=" + file.length());
                mainHandler.post(() -> {
                    capturing = false;
                    if (liveViewEnabled && !liveViewRestored) {
                        previewGeneration++;
                        liveViewEnabled = false;
                        updateConnectionUi();
                    }
                    if (shutterButton != null) shutterButton.setText(tr("拍摄"));
                    updateFileCount();
                    statusText.setText(tr("已保存 ") + file.getName());
                    showToast("拍摄完成，已保存到本地照片库。");
                });
                previewExecutor.submit(() -> {
                    Bitmap source = BitmapFactory.decodeByteArray(
                            jpeg,
                            0,
                            jpeg.length);
                    if (source == null) return;
                    ProcessedPreview output = processPreview(source);
                    mainHandler.post(() -> showProcessedPreview(source, output));
                });
            } catch (Exception error) {
                diagnostics.error("capture", "拍摄失败：" + error.getMessage());
                mainHandler.post(() -> {
                    capturing = false;
                    if (shutterButton != null) shutterButton.setText(tr("拍摄"));
                    showError(error.getMessage());
                });
            }
        });
    }

    private void startShootingTask() {
        if (!connected) {
            showConnectionDialog();
            return;
        }
        if (shootingTaskRunning || capturing) return;
        int generation = ++shootingTaskGeneration;
        String kind = shootingTaskKind;
        int count = Math.max(1, Math.min(999, shootingTaskCount));
        int interval = Math.max(1, Math.min(3600, shootingTaskInterval));
        int step = Math.max(1, Math.min(3, shootingTaskStep));
        double originalCompensation = currentCompensation;
        String originalMode = exposureMode;
        shootingTaskRunning = true;
        shootingTaskStatus = tr(taskLabel(kind)) + tr("准备中");
        showSection(currentSection);
        cameraExecutor.submit(() -> {
            try {
                int total = "bulb".equals(kind) ? 1 : count;
                if ("exposure".equals(kind) && total % 2 == 0) total++;
                if ("focus".equals(kind) && !camera.isLiveView()) {
                    camera.startLiveView();
                    liveViewEnabled = true;
                }
                if ("bulb".equals(kind)) {
                    camera.setParameter("exposureMode", "bulb");
                    camera.setParameter("bulbDuration", interval);
                }
                for (int index = 0; index < total; index++) {
                    if (generation != shootingTaskGeneration) {
                        throw new InterruptedException("拍摄任务已取消");
                    }
                    if ("exposure".equals(kind)) {
                        int center = total / 2;
                        double offset = (index - center) * step;
                        camera.setParameter(
                                "exposureCompensation",
                                originalCompensation + offset);
                    }
                    if ("focus".equals(kind) && index > 0) {
                        camera.moveFocus(step);
                    }
                    byte[] jpeg = camera.capture();
                    File file = captureWorkflow.store(
                            jpeg,
                            "capture.jpg",
                            connectedCameraName,
                            null);
                    int completed = index + 1;
                    int finalTotal = total;
                    Bitmap source = BitmapFactory.decodeByteArray(
                            jpeg,
                            0,
                            jpeg.length);
                    ProcessedPreview output = processPreview(source);
                    mainHandler.post(() -> {
                        showProcessedPreview(source, output);
                        shootingTaskStatus =
                                tr(taskLabel(kind))
                                        + " · "
                                        + completed
                                        + "/"
                                        + finalTotal
                                        + " · "
                                        + file.getName();
                        if (statusText != null) {
                            statusText.setText(shootingTaskStatus);
                        }
                        updateFileCount();
                    });
                    if ("interval".equals(kind) && index + 1 < total) {
                        for (int tick = 0; tick < interval * 10; tick++) {
                            if (generation != shootingTaskGeneration) {
                                throw new InterruptedException("拍摄任务已取消");
                            }
                            Thread.sleep(100);
                        }
                    }
                }
                if ("exposure".equals(kind)) {
                    camera.setParameter(
                            "exposureCompensation",
                            originalCompensation);
                }
                if ("bulb".equals(kind) && !"bulb".equals(originalMode)) {
                    camera.setParameter("exposureMode", originalMode);
                }
                mainHandler.post(() -> {
                    shootingTaskRunning = false;
                    shootingTaskStatus = tr(taskLabel(kind)) + tr("已完成");
                    showSection(currentSection);
                    statusText.setText(shootingTaskStatus);
                });
            } catch (InterruptedException cancelled) {
                restoreTaskCameraState(kind, originalCompensation, originalMode);
                mainHandler.post(() -> {
                    shootingTaskRunning = false;
                    shootingTaskStatus = tr("拍摄任务已取消");
                    showSection(currentSection);
                });
            } catch (Exception error) {
                restoreTaskCameraState(kind, originalCompensation, originalMode);
                diagnostics.error(
                        "capture-task",
                        taskLabel(kind) + "失败：" + error.getMessage());
                mainHandler.post(() -> {
                    shootingTaskRunning = false;
                    shootingTaskStatus = tr("拍摄任务失败");
                    showSection(currentSection);
                    showError(error.getMessage());
                });
            }
        });
    }

    private void cancelShootingTask() {
        shootingTaskGeneration++;
        shootingTaskStatus = tr("正在取消拍摄任务…");
    }

    private void restoreTaskCameraState(
            String kind,
            double originalCompensation,
            String originalMode) {
        try {
            if ("exposure".equals(kind)) {
                camera.setParameter(
                        "exposureCompensation",
                        originalCompensation);
            }
            if ("bulb".equals(kind) && !"bulb".equals(originalMode)) {
                camera.setParameter("exposureMode", originalMode);
            }
        } catch (Exception ignored) {
        }
    }

    private static String taskLabel(String kind) {
        switch (kind) {
            case "exposure": return "曝光包围";
            case "focus": return "焦点包围";
            case "bulb": return "B 门计时";
            default: return "间隔拍摄";
        }
    }

    private void toggleVideoRecording() {
        if (!connected) {
            showConnectionDialog();
            return;
        }
        if (capturing) return;
        capturing = true;
        updateRecordingButtons();
        cameraExecutor.submit(() -> {
            try {
                if (videoRecording) {
                    camera.stopMovieRecording();
                } else {
                    camera.startMovieRecording();
                }
                boolean nowRecording = camera.isMovieRecording();
                diagnostics.info(
                        "recording",
                        nowRecording
                                ? "机身视频录制已开始"
                                : "机身视频录制已停止");
                mainHandler.post(() -> {
                    videoRecording = nowRecording;
                    capturing = false;
                    updateRecordingButtons();
                    statusText.setText(tr(
                            nowRecording
                                    ? "● REC · 视频正在录制到相机存储卡"
                                    : "录制已停止 · 视频保存在相机存储卡"));
                });
            } catch (Exception error) {
                diagnostics.error(
                        "recording",
                        "切换视频录制失败：" + error.getMessage());
                mainHandler.post(() -> {
                    videoRecording = camera.isMovieRecording();
                    capturing = false;
                    updateRecordingButtons();
                    showError("视频录制失败：" + error.getMessage());
                });
            }
        });
    }

    private void updateRecordingButtons() {
        if (shutterButton != null && "monitor".equals(currentSection)) {
            shutterButton.setText(tr(
                    capturing
                            ? "处理中…"
                            : videoRecording ? "停止录制" : "开始录制"));
            shutterButton.setBackground(rounded(VIDEO, 9, 0));
            shutterButton.setEnabled(connected && !capturing);
        }
        if (immersiveRecordButton != null) {
            immersiveRecordButton.setText(tr(
                    capturing
                            ? "…"
                            : videoRecording ? "■\n停止" : "●\n录制"));
            immersiveRecordButton.setEnabled(connected && !capturing);
        }
    }

    private ProcessedPreview processPreview(Bitmap source) {
        CubeLut lut = previewLut;
        Bitmap graded = lutEnabled && lut != null ? lut.apply(source) : source;
        ProfessionalMonitor.Result monitor = ProfessionalMonitor.process(
                graded,
                focusPeakingEnabled,
                falseColorEnabled);
        redHistogram = monitor.redHistogram;
        greenHistogram = monitor.greenHistogram;
        blueHistogram = monitor.blueHistogram;
        waveform = monitor.waveform;
        vectorscope = monitor.vectorscope;
        peakingCoverage = monitor.peakingCoverage;
        Bitmap display = resampleMonitorPreview(monitor.image);
        Bitmap zebra = zebraEnabled ? createZebraMask(source, zebraThreshold) : null;
        return new ProcessedPreview(display, zebra);
    }

    private Bitmap resampleMonitorPreview(Bitmap source) {
        int boundWidth;
        int boundHeight;
        if ("hd720".equals(monitorVideoProfile)) {
            boundWidth = 1280;
            boundHeight = 720;
        } else if ("hd1080".equals(monitorVideoProfile)) {
            boundWidth = 1920;
            boundHeight = 1080;
        } else {
            boundWidth = source.getWidth();
            boundHeight = source.getHeight();
        }

        double fit = Math.min(
                boundWidth / (double) source.getWidth(),
                boundHeight / (double) source.getHeight());
        int targetWidth = Math.max(1, (int) Math.round(source.getWidth() * fit));
        int targetHeight = Math.max(1, (int) Math.round(source.getHeight() * fit));
        if (targetWidth == source.getWidth() && targetHeight == source.getHeight()) return source;
        return Bitmap.createScaledBitmap(source, targetWidth, targetHeight, true);
    }

    private void showProcessedPreview(Bitmap source, ProcessedPreview output) {
        latestSourceFrame = source;
        latestFrame = output.display;
        latestZebraMask = output.zebra;
        boolean monitoring = "monitor".equals(currentSection);
        if (previewImage != null) {
            previewImage.setImageBitmap(monitoring ? output.display : source);
        }
        if (zebraImage != null) {
            zebraImage.setImageBitmap(
                    monitoring && zebraEnabled ? output.zebra : null);
        }
        if (immersivePreviewImage != null) {
            immersivePreviewImage.setImageBitmap(
                    immersiveMonitoring ? output.display : source);
        }
        if (immersiveZebraImage != null) {
            immersiveZebraImage.setImageBitmap(
                    immersiveMonitoring && zebraEnabled ? output.zebra : null);
        }
        if (redHistogramText != null) {
            redHistogramText.setText("R  " + redHistogram);
            greenHistogramText.setText("G  " + greenHistogram);
            blueHistogramText.setText("B  " + blueHistogram);
            waveformText.setText(tr("波形") + "  " + waveform);
            vectorscopeText.setText(tr("矢量") + "  " + vectorscope);
            peakingCoverageText.setText(
                    tr("峰值覆盖") + " · " + peakingCoverage + "%");
        }
        if (previewPlaceholder != null) previewPlaceholder.setVisibility(View.GONE);
    }

    private void refreshPreviewProcessing() {
        Bitmap source = latestSourceFrame;
        if (source == null) return;
        previewExecutor.submit(() -> {
            ProcessedPreview output = processPreview(source);
            mainHandler.post(() -> {
                if (source == latestSourceFrame) {
                    showProcessedPreview(source, output);
                }
            });
        });
    }

    private Bitmap createZebraMask(Bitmap source, int threshold) {
        int sourceWidth = source.getWidth();
        int sourceHeight = source.getHeight();
        double scale = Math.min(1.0, 384.0 / Math.max(sourceWidth, sourceHeight));
        int width = Math.max(1, (int) Math.round(sourceWidth * scale));
        int height = Math.max(1, (int) Math.round(sourceHeight * scale));
        Bitmap working = scale < 1.0
                ? Bitmap.createScaledBitmap(source, width, height, false)
                : source;
        int[] pixels = new int[width * height];
        int[] overlay = new int[width * height];
        working.getPixels(pixels, 0, width, 0, 0, width, height);
        int limit = Math.max(0, Math.min(255, Math.round(threshold * 2.55f)));
        int zebraColor = Color.argb(190, 255, 205, 36);
        for (int y = 0; y < height; y++) {
            int row = y * width;
            for (int x = 0; x < width; x++) {
                int color = pixels[row + x];
                int luminance = (
                        54 * Color.red(color)
                                + 183 * Color.green(color)
                                + 19 * Color.blue(color)) >> 8;
                if (luminance >= limit && ((x + y) / 5) % 2 == 0) {
                    overlay[row + x] = zebraColor;
                }
            }
        }
        Bitmap result = Bitmap.createBitmap(overlay, width, height, Bitmap.Config.ARGB_8888);
        if (working != source) working.recycle();
        return result;
    }

    private File savePhoto(byte[] jpeg) throws Exception {
        return captureWorkflow.store(
                jpeg,
                "capture.jpg",
                connectedCameraName,
                null);
    }

    private void applyParameter(String name, Object value, String label) {
        if (!connected) {
            showToast("连接支持的 Nikon 相机后才能调整参数。");
            return;
        }
        if (!camera.isParameterWritable(name)) {
            String reason = camera.parameterLockReason(name);
            showToast(
                    label
                            + "不可调整"
                            + (reason == null ? "。" : "：" + reason));
            return;
        }
        cameraExecutor.submit(() -> {
            try {
                camera.setParameter(name, value);
                diagnostics.info(
                        "camera",
                        "已设置参数；名称=" + name + "；值=" + value);
                mainHandler.post(() -> {
                    if ("exposureMode".equals(name)) {
                        exposureMode = String.valueOf(value);
                        updateCameraControls();
                    }
                    if ("exposureCompensation".equals(name)
                            && value instanceof Number) {
                        currentCompensation =
                                ((Number) value).doubleValue();
                    }
                    statusText.setText(tr(label) + tr("已应用"));
                });
            } catch (Exception error) {
                diagnostics.error(
                        "camera",
                        "设置参数失败；名称=" + name + "；错误=" + error.getMessage());
                mainHandler.post(() -> {
                    updateCameraControls();
                    showError(error.getMessage());
                });
            }
        });
    }

    private void updateConnectionUi() {
        if (connectButton != null) {
            connectButton.setText(tr(
                    connecting
                            ? "正在连接…"
                            : connected
                                    ? "断开 "
                                            + connectedCameraName.replace("Nikon ", "")
                                    : "连接相机"));
            connectButton.setEnabled(!connecting);
        }
        if (statusText != null) {
            statusText.setText(tr(connecting
                    ? "正在检测 Nikon 相机"
                    : connected
                            ? connectedCameraName + " · USB/PTP"
                            : "未连接"));
        }
        if (liveViewButton != null) {
            liveViewButton.setText(
                    tr(liveViewEnabled ? "停止实时取景" : "开启实时取景"));
        }
        updateCameraControls();
        updateRecordingButtons();
        updateFileCount();
    }

    private void updateCameraControls() {
        for (View control : cameraControls) control.setEnabled(connected);
        for (Map.Entry<String, View> entry : parameterControls.entrySet()) {
            boolean enabled = connected && camera.isParameterWritable(entry.getKey());
            entry.getValue().setEnabled(enabled);
            entry.getValue().setAlpha(enabled ? 1f : 0.48f);
        }
        for (Map.Entry<String, TextView> entry : parameterLabels.entrySet()) {
            Object tag = entry.getValue().getTag();
            String base = tag == null ? entry.getValue().getText().toString() : String.valueOf(tag);
            String reason = connected
                    ? camera.parameterLockReason(entry.getKey())
                    : "连接相机后可调整";
            entry.getValue().setText(
                    reason == null
                            ? tr(base)
                            : tr(base) + " · " + tr(reason));
            entry.getValue().setAlpha(reason == null ? 1f : 0.62f);
        }
    }

    private boolean canAdjustExposureParameter(String name) {
        return camera.isParameterWritable(name);
    }

    private int exposureModeIndex() {
        switch (exposureMode) {
            case "program": return 0;
            case "shutterPriority": return 1;
            case "aperturePriority": return 2;
            case "bulb": return 4;
            default: return 3;
        }
    }

    private String exposureLockReason(String name) {
        if (canAdjustExposureParameter(name)) return null;
        String mode;
        switch (exposureMode) {
            case "program": mode = "P"; break;
            case "aperturePriority": mode = "A"; break;
            case "shutterPriority": mode = "S"; break;
            case "bulb": mode = "M（B门）"; break;
            default: mode = "M"; break;
        }
        return mode + " 拍摄模式下由相机控制";
    }

    private void updateFileCount() {
        if (countText != null) {
            countText.setText(
                    photoFiles().size()
                            + (Localization.ENGLISH.equals(appLanguage)
                                    ? " items"
                                    : Localization.JAPANESE.equals(appLanguage)
                                            ? " 件"
                                            : " 张"));
        }
    }

    private List<File> photoFiles() {
        List<File> result = new ArrayList<>();
        collectMediaFiles(photoDirectory, result);
        result.sort((left, right) -> Long.compare(right.lastModified(), left.lastModified()));
        return result;
    }

    private void collectMediaFiles(File directory, List<File> result) {
        if (directory == null || "Backup".equals(directory.getName())) return;
        File[] files = directory.listFiles();
        if (files == null) return;
        for (File file : files) {
            if (file.isDirectory()) {
                collectMediaFiles(file, result);
                continue;
            }
            String name = file.getName();
            String lower = name.toLowerCase(Locale.ROOT);
            boolean supported = lower.endsWith(".jpg")
                    || lower.endsWith(".jpeg")
                    || lower.endsWith(".png")
                    || lower.endsWith(".nef")
                    || lower.endsWith(".heif")
                    || lower.endsWith(".heic")
                    || lower.endsWith(".tif")
                    || lower.endsWith(".tiff")
                    || lower.endsWith(".mp4")
                    || lower.endsWith(".mov")
                    || lower.endsWith(".m4v");
            if (supported) result.add(file);
        }
    }

    boolean ensureUsbPermission(UsbManager manager, UsbDevice device) throws Exception {
        if (manager.hasPermission(device)) return true;
        String permissionAction =
                USB_PERMISSION_ACTION
                        + "."
                        + device.getDeviceId()
                        + "."
                        + UUID.randomUUID();
        CountDownLatch latch = new CountDownLatch(1);
        AtomicBoolean granted = new AtomicBoolean(false);
        AtomicBoolean registered = new AtomicBoolean(false);
        AtomicReference<RuntimeException> requestError = new AtomicReference<>();
        BroadcastReceiver receiver = new BroadcastReceiver() {
            @Override
            public void onReceive(Context context, Intent intent) {
                if (!permissionAction.equals(intent.getAction())) return;
                // UsbManager is the source of truth. This also avoids depending on
                // OEM-specific handling of PendingIntent fill-in extras.
                granted.set(manager.hasPermission(device));
                latch.countDown();
            }
        };

        runOnUiThread(() -> {
            try {
                IntentFilter filter = new IntentFilter(permissionAction);
                if (Build.VERSION.SDK_INT >= 33) {
                    // The result can be dispatched by a privileged USB permission
                    // component rather than the app process itself.
                    registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED);
                } else {
                    registerReceiver(receiver, filter);
                }
                registered.set(true);
                PendingIntent permissionIntent = PendingIntent.getBroadcast(
                        this,
                        device.getDeviceId(),
                        new Intent(permissionAction).setPackage(getPackageName()),
                        PendingIntent.FLAG_CANCEL_CURRENT | PendingIntent.FLAG_IMMUTABLE);
                manager.requestPermission(device, permissionIntent);
            } catch (RuntimeException error) {
                requestError.set(error);
                latch.countDown();
            }
        });

        boolean finished = false;
        long deadline = System.currentTimeMillis() + 35_000;
        while (!finished && System.currentTimeMillis() < deadline) {
            if (manager.hasPermission(device)) {
                granted.set(true);
                break;
            }
            long remaining = deadline - System.currentTimeMillis();
            finished = latch.await(Math.min(250, Math.max(1, remaining)), TimeUnit.MILLISECONDS);
        }
        if (manager.hasPermission(device)) granted.set(true);
        runOnUiThread(() -> {
            if (!registered.get()) return;
            try {
                unregisterReceiver(receiver);
            } catch (IllegalArgumentException ignored) {
            }
        });
        if (requestError.get() != null) {
            throw new Exception("无法请求 USB 访问权限：" + requestError.get().getMessage());
        }
        return granted.get();
    }

    private LinearLayout verticalContainer() {
        LinearLayout container = new LinearLayout(this);
        container.setOrientation(LinearLayout.VERTICAL);
        return container;
    }

    private LinearLayout panel() {
        LinearLayout panel = verticalContainer();
        panel.setPadding(dp(18), dp(18), dp(18), dp(18));
        panel.setBackground(rounded(SURFACE, 16, RULE));
        panel.setElevation(dp(2));
        LinearLayout.LayoutParams params = marginParams(-1, -2, 0, 12, 0, 0);
        panel.setLayoutParams(params);
        return panel;
    }

    private View sectionHeader(String title, String subtitle, int accent) {
        LinearLayout header = new LinearLayout(this);
        header.setOrientation(LinearLayout.HORIZONTAL);
        header.setGravity(Gravity.TOP);

        View rail = new View(this);
        rail.setBackground(rounded(accent, 2, 0));
        LinearLayout.LayoutParams railParams = new LinearLayout.LayoutParams(dp(4), dp(44));
        railParams.setMargins(0, dp(2), dp(12), 0);
        header.addView(rail, railParams);

        LinearLayout copy = verticalContainer();
        copy.addView(text(title, 30, Typeface.BOLD, INK));
        copy.addView(
                text(subtitle, 14, Typeface.NORMAL, MUTED),
                marginParams(-1, -2, 0, 3, 0, 0));
        header.addView(copy, new LinearLayout.LayoutParams(
                0,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                1f));
        header.setLayoutParams(marginParams(-1, -2, 0, 0, 0, 20));
        return header;
    }

    private String tr(String value) {
        return Localization.translate(appLanguage, value);
    }

    private void changeLanguage(String language) {
        String normalized = Localization.normalize(language);
        if (normalized.equals(appLanguage)) {
            return;
        }
        appLanguage = normalized;
        getSharedPreferences("nikon-link", MODE_PRIVATE)
                .edit()
                .putString(Localization.PREFERENCE_KEY, appLanguage)
                .apply();
        String destination = currentSection;
        navigationButtons.clear();
        setContentView(buildApplication());
        showSection(destination);
        updateConnectionUi();
        updateWirelessUi();
        refreshUpdateUi();
        updateFileCount();
        if (latestSourceFrame != null) {
            refreshPreviewProcessing();
        }
    }

    private TextView text(String value, int sp, int style, int color) {
        TextView text = new TextView(this);
        text.setText(tr(value));
        text.setTextSize(sp);
        text.setTextColor(color);
        text.setTypeface(Typeface.create("sans", style));
        text.setGravity(Gravity.CENTER_VERTICAL);
        return text;
    }

    private Button nativeButton(String label, boolean primary) {
        Button button = new Button(this);
        button.setText(tr(label));
        button.setTextSize(13);
        button.setTypeface(Typeface.create("sans", Typeface.BOLD));
        button.setTextColor(primary ? Color.WHITE : INK);
        button.setAllCaps(false);
        button.setLetterSpacing(0.01f);
        button.setGravity(Gravity.CENTER);
        button.setPadding(dp(10), 0, dp(10), 0);
        button.setMinHeight(dp(44));
        button.setBackground(
                rounded(primary ? COBALT : SURFACE, 12, primary ? 0 : RULE_STRONG));
        button.setElevation(primary ? dp(2) : 0);
        button.setStateListAnimator(null);
        return button;
    }

    private LinearLayout fastFeedbackCard() {
        LinearLayout card = verticalContainer();
        card.setPadding(dp(14), dp(14), dp(14), dp(14));
        card.setBackground(rounded(COBALT_SOFT, 12, Color.rgb(182, 207, 245)));
        card.addView(text(
                "⚡  " + tr("快速问题反馈"),
                15,
                Typeface.BOLD,
                INK));
        card.addView(
                text(
                        "公开问题可继续在 GitHub 免费提交；在爱发电赞助后，可获取快速问题反馈渠道。",
                        12,
                        Typeface.NORMAL,
                        MUTED),
                marginParams(-1, -2, 0, 5, 0, 10));
        card.addView(
                text(
                        "官方 QQ 群：165315727",
                        13,
                        Typeface.BOLD,
                        COBALT),
                marginParams(-1, -2, 0, 0, 0, 10));
        Button openAfdian = nativeButton("打开爱发电", false);
        openAfdian.setOnClickListener(view -> openExternalUrl(AFDIAN_URL));
        card.addView(openAfdian, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(44)));
        return card;
    }

    private GradientDrawable rounded(int color, int radiusDp, int strokeColor) {
        GradientDrawable drawable = new GradientDrawable();
        drawable.setColor(color);
        drawable.setCornerRadius(dp(radiusDp));
        if (strokeColor != 0) drawable.setStroke(dp(1), strokeColor);
        return drawable;
    }

    private LinearLayout.LayoutParams marginParams(
            int width,
            int height,
            int left,
            int top,
            int right,
            int bottom) {
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(
                width < 0 ? ViewGroup.LayoutParams.MATCH_PARENT : width,
                height < 0 ? ViewGroup.LayoutParams.WRAP_CONTENT : height);
        params.setMargins(dp(left), dp(top), dp(right), dp(bottom));
        return params;
    }

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }

    private String humanSize(long bytes) {
        if (bytes < 1024) return bytes + " B";
        if (bytes < 1024 * 1024) return String.format(Locale.CHINA, "%.1f KB", bytes / 1024.0);
        return String.format(Locale.CHINA, "%.1f MB", bytes / (1024.0 * 1024.0));
    }

    private void showToast(String message) {
        Toast.makeText(this, tr(message), Toast.LENGTH_SHORT).show();
    }

    private void showError(String message) {
        diagnostics.error("ui", message);
        new AlertDialog.Builder(this)
                .setTitle("帧澈 ZENCHE")
                .setMessage(tr(message == null ? "原生相机操作失败。" : message))
                .setPositiveButton(tr("好"), null)
                .show();
    }

    private void openGithubIssue() {
        diagnostics.info("diagnostics", "用户打开 GitHub Issue 提交页");
        Intent intent = new Intent(Intent.ACTION_VIEW, diagnostics.githubIssueUri());
        try {
            startActivity(intent);
        } catch (RuntimeException error) {
            diagnostics.error(
                    "diagnostics",
                    "无法打开 GitHub Issue 提交页：" + error.getMessage());
            showToast("无法打开浏览器，请访问 github.com/Tauber01/ZENCHE/issues");
        }
    }

    private void checkForUpdates(boolean silent) {
        if (checkingUpdate) return;
        checkingUpdate = true;
        if (!silent) updateStatus = "正在检查更新…";
        refreshUpdateUi();
        updateExecutor.submit(() -> {
            try {
                UpdateCandidate candidate;
                try {
                    candidate = checkMirrorChyan();
                    if (isNewerVersion(
                            candidate.version,
                            currentVersion())
                            && candidate.url == null) {
                        UpdateCandidate github = checkGitHub();
                        candidate = new UpdateCandidate(
                                candidate.version,
                                github.url,
                                candidate.notice);
                    }
                } catch (MirrorChyanException error) {
                    diagnostics.warning(
                            "update",
                            "Mirror酱检查失败，准备回退 GitHub；code="
                                    + error.code);
                    UpdateCandidate github = checkGitHub();
                    candidate = new UpdateCandidate(
                            github.version,
                            github.url,
                            mirrorFallbackStatus(error.code));
                } catch (Exception error) {
                    diagnostics.warning(
                            "update",
                            "Mirror酱检查失败，准备回退 GitHub："
                                    + error.getMessage());
                    UpdateCandidate github = checkGitHub();
                    candidate = new UpdateCandidate(
                            github.version,
                            github.url,
                            "Mirror酱暂不可用，已回退 GitHub");
                }
                boolean newer = isNewerVersion(
                        candidate.version,
                        currentVersion());
                UpdateCandidate resolvedCandidate = candidate;
                mainHandler.post(() -> {
                    checkingUpdate = false;
                    if (newer) {
                        availableVersion = resolvedCandidate.version;
                        availableUpdateUrl = resolvedCandidate.url;
                        updateStatus =
                                "发现新版本 " + resolvedCandidate.version;
                    } else {
                        availableVersion = null;
                        availableUpdateUrl = null;
                        updateStatus = "已是最新版本";
                    }
                    if (resolvedCandidate.notice != null) {
                        updateStatus += " · " + resolvedCandidate.notice;
                    }
                    refreshUpdateUi();
                });
            } catch (Exception error) {
                diagnostics.error("update", "检查更新失败：" + error.getMessage());
                mainHandler.post(() -> {
                    checkingUpdate = false;
                    if (!silent) updateStatus = "检查失败，请确认网络后重试";
                    refreshUpdateUi();
                });
            }
        });
    }

    private UpdateCandidate checkMirrorChyan() throws Exception {
        Uri.Builder builder = Uri.parse(MIRROR_CHYAN_API)
                .buildUpon()
                .appendQueryParameter(
                        "current_version",
                        "v" + currentVersion())
                .appendQueryParameter(
                        "user_agent",
                        "ZENCHE_Android")
                .appendQueryParameter("os", "android")
                .appendQueryParameter(
                        "arch",
                        mirrorChyanArchitecture())
                .appendQueryParameter("channel", "stable");
        String cdk = loadMirrorChyanCdk();
        if (!cdk.isEmpty()) {
            builder.appendQueryParameter("cdk", cdk);
        }
        JSONObject root = requestJson(
                builder.build().toString(),
                "ZENCHE-Android/" + currentVersion());
        int code = root.optInt("code", -1);
        if (code != 0) {
            throw new MirrorChyanException(code);
        }
        JSONObject data = root.optJSONObject("data");
        if (data == null) {
            throw new MirrorChyanException(-1);
        }
        String version = normalizeVersion(
                data.optString("version_name", currentVersion()));
        String updateType = data.optString("update_type");
        String url = data.optString("url");
        String notice = null;
        if ("incremental".equalsIgnoreCase(updateType)) {
            url = "";
            notice =
                    "Mirror酱未返回可直接安装的完整包，已回退 GitHub";
        }
        return new UpdateCandidate(
                version,
                url.isEmpty() ? null : url,
                notice);
    }

    private UpdateCandidate checkGitHub() throws Exception {
        JSONObject release = requestJson(
                LATEST_RELEASE_API,
                "ZENCHE-Android/" + currentVersion());
        String version = normalizeVersion(
                release.getString("tag_name"));
        String targetUrl = release.getString("html_url");
        JSONArray assets = release.optJSONArray("assets");
        if (assets != null) {
            for (int index = 0; index < assets.length(); index++) {
                JSONObject asset = assets.getJSONObject(index);
                String name = asset.optString("name");
                if (name.endsWith("-android.apk")) {
                    targetUrl = asset.optString(
                            "browser_download_url",
                            targetUrl);
                    break;
                }
            }
        }
        return new UpdateCandidate(version, targetUrl, null);
    }

    private JSONObject requestJson(
            String endpoint,
            String userAgent) throws Exception {
        HttpURLConnection connection = null;
        try {
            connection = (HttpURLConnection) new URL(endpoint).openConnection();
            connection.setConnectTimeout(20_000);
            connection.setReadTimeout(20_000);
            connection.setRequestProperty("Accept", "application/json");
            connection.setRequestProperty("User-Agent", userAgent);
            int responseCode = connection.getResponseCode();
            InputStream stream = responseCode >= 200 && responseCode < 300
                    ? connection.getInputStream()
                    : connection.getErrorStream();
            if (stream == null) {
                throw new IllegalStateException(
                        "HTTP " + responseCode);
            }
            StringBuilder body = new StringBuilder();
            try (BufferedReader reader = new BufferedReader(
                    new InputStreamReader(
                            stream,
                            StandardCharsets.UTF_8))) {
                String line;
                while ((line = reader.readLine()) != null) {
                    body.append(line);
                }
            }
            return new JSONObject(body.toString());
        } finally {
            if (connection != null) connection.disconnect();
        }
    }

    private String loadMirrorChyanCdk() {
        String encrypted = getSharedPreferences(
                "nikon-link",
                MODE_PRIVATE).getString(MIRROR_CHYAN_CDK_KEY, "");
        if (encrypted == null || encrypted.isEmpty()) {
            return "";
        }
        try {
            String[] parts = encrypted.split(":", 2);
            if (parts.length != 2) return "";
            Cipher cipher = Cipher.getInstance(
                    "AES/GCM/NoPadding");
            cipher.init(
                    Cipher.DECRYPT_MODE,
                    mirrorChyanSecretKey(),
                    new GCMParameterSpec(
                            128,
                            Base64.decode(parts[0], Base64.NO_WRAP)));
            byte[] clear = cipher.doFinal(
                    Base64.decode(parts[1], Base64.NO_WRAP));
            return new String(clear, StandardCharsets.UTF_8);
        } catch (Exception error) {
            diagnostics.warning(
                    "update",
                    "无法读取 Mirror酱 CDK：" + error.getClass().getSimpleName());
            return "";
        }
    }

    private boolean saveMirrorChyanCdk(String value) {
        String cdk = value.trim();
        if (cdk.isEmpty()) {
            getSharedPreferences("nikon-link", MODE_PRIVATE)
                    .edit()
                    .remove(MIRROR_CHYAN_CDK_KEY)
                    .apply();
            return true;
        }
        try {
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(
                    Cipher.ENCRYPT_MODE,
                    mirrorChyanSecretKey());
            String encrypted =
                    Base64.encodeToString(
                            cipher.getIV(),
                            Base64.NO_WRAP)
                            + ":"
                            + Base64.encodeToString(
                                    cipher.doFinal(
                                            cdk.getBytes(
                                                    StandardCharsets.UTF_8)),
                                    Base64.NO_WRAP);
            getSharedPreferences("nikon-link", MODE_PRIVATE)
                    .edit()
                    .putString(MIRROR_CHYAN_CDK_KEY, encrypted)
                    .apply();
            return true;
        } catch (Exception error) {
            diagnostics.error(
                    "update",
                    "无法保存 Mirror酱 CDK："
                            + error.getClass().getSimpleName());
            return false;
        }
    }

    private SecretKey mirrorChyanSecretKey() throws Exception {
        KeyStore keyStore = KeyStore.getInstance("AndroidKeyStore");
        keyStore.load(null);
        KeyStore.Entry entry = keyStore.getEntry(
                MIRROR_CHYAN_KEY_ALIAS,
                null);
        if (entry instanceof KeyStore.SecretKeyEntry) {
            return ((KeyStore.SecretKeyEntry) entry).getSecretKey();
        }
        KeyGenerator generator = KeyGenerator.getInstance(
                KeyProperties.KEY_ALGORITHM_AES,
                "AndroidKeyStore");
        generator.init(new KeyGenParameterSpec.Builder(
                MIRROR_CHYAN_KEY_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT
                        | KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(
                        KeyProperties.ENCRYPTION_PADDING_NONE)
                .build());
        return generator.generateKey();
    }

    private static String mirrorChyanArchitecture() {
        String abi = Build.SUPPORTED_ABIS.length == 0
                ? ""
                : Build.SUPPORTED_ABIS[0];
        if (abi.contains("arm64")) return "arm64";
        if (abi.contains("x86_64")) return "x64";
        if (abi.contains("armeabi")) return "arm";
        return "x86";
    }

    private static String mirrorFallbackStatus(int code) {
        switch (code) {
            case 7001:
                return "Mirror酱 CDK 已过期，已回退 GitHub";
            case 7002:
                return "Mirror酱 CDK 无效，已回退 GitHub";
            case 7003:
                return "Mirror酱今日下载额度已用完，已回退 GitHub";
            case 7004:
                return "Mirror酱 CDK 与资源不匹配，已回退 GitHub";
            case 7005:
                return "Mirror酱 CDK 已被停用，已回退 GitHub";
            case 8001:
                return "Mirror酱资源尚未配置，已回退 GitHub";
            default:
                return "Mirror酱暂不可用，已回退 GitHub";
        }
    }

    private static String mirrorChyanWebsiteUrl() {
        return Uri.parse("https://mirrorchyan.com/zh/projects")
                .buildUpon()
                .appendQueryParameter(
                        "rid",
                        MIRROR_CHYAN_RESOURCE_ID)
                .appendQueryParameter(
                        "source",
                        "zenche_android_settings")
                .build()
                .toString();
    }

    private void refreshUpdateUi() {
        if (updateStatusText != null) {
            updateStatusText.setText(tr(updateStatus));
        }
        if (checkUpdateButton != null) {
            checkUpdateButton.setEnabled(!checkingUpdate);
            checkUpdateButton.setText(
                    tr(checkingUpdate ? "正在检查…" : "检查更新"));
        }
        if (openUpdateButton != null) {
            openUpdateButton.setVisibility(
                    availableVersion == null ? View.GONE : View.VISIBLE);
            openUpdateButton.setText(tr(
                    availableVersion == null
                            ? "获取更新"
                            : "获取 " + availableVersion));
        }
    }

    private void openUpdatePage() {
        String target = availableUpdateUrl == null ? RELEASES_URL : availableUpdateUrl;
        try {
            startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse(target)));
        } catch (RuntimeException error) {
            diagnostics.error("update", "无法打开更新页：" + error.getMessage());
            showToast("无法打开浏览器，请访问 github.com/Tauber01/ZENCHE/releases");
        }
    }

    private static String normalizeVersion(String value) {
        if (value.startsWith("v") || value.startsWith("V")) {
            return value.substring(1);
        }
        return value;
    }

    private String currentVersion() {
        try {
            String version = getPackageManager()
                    .getPackageInfo(getPackageName(), 0)
                    .versionName;
            return version == null || version.isEmpty() ? "1.3.0" : version;
        } catch (Exception error) {
            return "1.3.0";
        }
    }

    private static boolean isNewerVersion(String candidate, String current) {
        String[] left = candidate.split("[.-]");
        String[] right = current.split("[.-]");
        int count = Math.max(left.length, right.length);
        for (int index = 0; index < count; index++) {
            int candidatePart = versionPart(left, index);
            int currentPart = versionPart(right, index);
            if (candidatePart != currentPart) return candidatePart > currentPart;
        }
        return false;
    }

    private static int versionPart(String[] parts, int index) {
        if (index >= parts.length) return 0;
        try {
            return Integer.parseInt(parts[index].replaceAll("[^0-9].*$", ""));
        } catch (NumberFormatException ignored) {
            return 0;
        }
    }

    private static final class UpdateCandidate {
        final String version;
        final String url;
        final String notice;

        UpdateCandidate(
                String version,
                String url,
                String notice) {
            this.version = version;
            this.url = url;
            this.notice = notice;
        }
    }

    private static final class MirrorChyanException extends Exception {
        final int code;

        MirrorChyanException(int code) {
            super("MirrorChyan " + code);
            this.code = code;
        }
    }

    private void showRecentLogs() {
        LinearLayout wrapper = verticalContainer();
        wrapper.setPadding(dp(18), dp(14), dp(18), dp(14));
        wrapper.addView(text(
                "显示近期脱敏日志；刷新可读取最新记录。",
                12,
                Typeface.NORMAL,
                MUTED),
                marginParams(-1, -2, 0, 0, 0, 12));
        TextView logView = text(
                diagnostics.recentText(12_000),
                11,
                Typeface.NORMAL,
                Color.rgb(222, 228, 237));
        logView.setTypeface(Typeface.MONOSPACE);
        logView.setTextIsSelectable(true);
        logView.setPadding(dp(14), dp(12), dp(14), dp(12));
        logView.setBackground(rounded(
                Color.rgb(12, 15, 21), 10, RULE));
        ScrollView logScroll = new ScrollView(this);
        logScroll.addView(logView);
        wrapper.addView(logScroll,
                new LinearLayout.LayoutParams(-1, 0, 1f));
        new AlertDialog.Builder(this)
                .setTitle(tr("最近诊断日志"))
                .setView(wrapper)
                .setNegativeButton(tr("关闭"), null)
                .setPositiveButton(
                        tr("刷新"),
                        (dialog, which) -> showRecentLogs())
                .show();
    }

    private void showDonation() {
        try (InputStream stream = getAssets().open("wechat-donation.png")) {
            LinearLayout content = verticalContainer();
            content.setPadding(dp(18), dp(14), dp(18), dp(16));
            content.addView(text(
                    "扫描二维码，或打开爱发电主页支持项目。",
                    13,
                    Typeface.NORMAL,
                    MUTED),
                    marginParams(-1, -2, 0, 0, 0, 12));
            content.addView(
                    fastFeedbackCard(),
                    marginParams(-1, -2, 0, 0, 0, 14));
            ImageView image = new ImageView(this);
            image.setImageBitmap(BitmapFactory.decodeStream(stream));
            image.setAdjustViewBounds(true);
            image.setBackground(rounded(SURFACE, 16, RULE));
            image.setPadding(dp(12), dp(12), dp(12), dp(12));
            content.addView(image);
            content.addView(text(
                    "软件功能永久免费，赞助为自愿行为。\n"
                            + "赞助不会解锁软件功能，也不影响公开 Issue 的处理。",
                    11,
                    Typeface.NORMAL,
                    MUTED),
                    marginParams(-1, -2, 0, 12, 0, 0));
            ScrollView scroll = new ScrollView(this);
            scroll.addView(content);
            AlertDialog dialog = new AlertDialog.Builder(this)
                    .setTitle(tr("爱发电赞助"))
                    .setView(scroll)
                    .setPositiveButton(tr("完成"), null)
                    .create();
            dialog.setOnShowListener(ignored -> {
                Window window = dialog.getWindow();
                if (window != null) {
                    window.setLayout(
                            Math.min(
                                    getResources().getDisplayMetrics().widthPixels - dp(28),
                                    dp(560)),
                            (int) (getResources().getDisplayMetrics().heightPixels * 0.9f));
                }
            });
            dialog.show();
        } catch (Exception error) {
            diagnostics.error("support", "无法载入赞赏二维码：" + error.getMessage());
            showToast("二维码暂不可用，请稍后再试。");
        }
    }

    private void showLaunchAnnouncementIfNeeded() {
        String version = currentVersion();
        String dismissedVersion = getSharedPreferences(
                "nikon-link",
                MODE_PRIVATE)
                .getString(DISMISSED_ANNOUNCEMENT_VERSION_KEY, "");
        if (version.equals(dismissedVersion)) {
            return;
        }

        LinearLayout content = verticalContainer();
        content.setPadding(dp(22), dp(12), dp(22), dp(8));

        content.addView(text("本次更新", 19, Typeface.BOLD, INK));
        content.addView(
                text(
                        "• 新增 AI 修图与生图工具，内置一键美颜等快捷预设，激活码解锁后即可使用。\n"
                                + "• 新增树状分支文件库，支持嵌套分支、拖拽归类与持久化组织。\n"
                                + "• 新增专业非破坏性修图工具，提供光影 / 色彩 / 细节 / 效果 / 几何五组参数与透明预设。\n"
                                + "• 新增可展开的全屏二级相机参数面板，移动端保持紧凑触控区域。\n"
                                + "• USB/PTP 连接可靠性大幅提升：瞬时错误自动重试、HONOR 设备同步降级传输。\n"
                                + "• 新增对 Nikon D500、D7500、D850（EXPEED 5）的 USB/PTP 控制支持。\n• 视频录制监看延迟优化：子采样解码、管道重叠取帧、智能跳帧分析。",
                        14,
                        Typeface.NORMAL,
                        INK),
                marginParams(-1, -2, 0, 8, 0, 18));

        LinearLayout warning = verticalContainer();
        warning.setPadding(dp(16), dp(14), dp(16), dp(14));
        warning.setBackground(rounded(
                Color.rgb(255, 238, 238),
                12,
                Color.rgb(244, 185, 185)));
        warning.addView(text("谨防诈骗", 17, Typeface.BOLD, Color.rgb(178, 25, 35)));
        warning.addView(
                text(
                        "帧澈 ZENCHE 是开源免费项目。任何声称“进群领取软件”"
                                + "或要求付费购买软件的人都是骗子，请勿转账。",
                        14,
                        Typeface.BOLD,
                        Color.rgb(117, 20, 28)),
                marginParams(-1, -2, 0, 6, 0, 0));
        content.addView(
                warning,
                marginParams(-1, -2, 0, 0, 0, 18));

        LinearLayout sponsor = verticalContainer();
        sponsor.setPadding(dp(16), dp(16), dp(16), dp(16));
        sponsor.setBackground(rounded(SURFACE, 14, RULE));
        sponsor.addView(text("爱发电赞助", 17, Typeface.BOLD, INK));
        sponsor.addView(
                text(
                        "如果本项目对你有帮助，欢迎自愿打赏；软件功能永久免费。",
                        13,
                        Typeface.NORMAL,
                        MUTED),
                marginParams(-1, -2, 0, 4, 0, 10));
        sponsor.addView(
                fastFeedbackCard(),
                marginParams(-1, -2, 0, 0, 0, 12));
        try (InputStream stream = getAssets().open("wechat-donation.png")) {
            ImageView image = new ImageView(this);
            image.setImageBitmap(BitmapFactory.decodeStream(stream));
            image.setAdjustViewBounds(true);
            image.setMaxHeight(dp(460));
            image.setBackground(rounded(SURFACE, 12, RULE));
            sponsor.addView(
                    image,
                    marginParams(-1, -2, 0, 0, 0, 12));
        } catch (Exception error) {
            diagnostics.warning(
                    "announcement",
                    "无法载入公告赞助图片：" + error.getMessage());
        }
        content.addView(
                sponsor,
                marginParams(-1, -2, 0, 0, 0, 18));

        CheckBox doNotRemind = new CheckBox(this);
        doNotRemind.setText(tr("不再提醒（软件更新后仍会显示）"));
        doNotRemind.setTextSize(14);
        doNotRemind.setTextColor(INK);
        content.addView(
                doNotRemind,
                marginParams(-1, dp(48), 0, 0, 0, 0));

        ScrollView scroll = new ScrollView(this);
        scroll.addView(content);
        AlertDialog dialog = new AlertDialog.Builder(this)
                .setTitle(tr("更新公告") + " · " + version)
                .setView(scroll)
                .setPositiveButton(tr("关闭公告"), null)
                .create();
        dialog.setOnDismissListener(ignored -> {
            if (doNotRemind.isChecked()) {
                getSharedPreferences("nikon-link", MODE_PRIVATE)
                        .edit()
                        .putString(
                                DISMISSED_ANNOUNCEMENT_VERSION_KEY,
                                version)
                        .apply();
            }
        });
        dialog.setOnShowListener(ignored -> {
            Window window = dialog.getWindow();
            if (window != null) {
                window.setLayout(
                        Math.min(
                                getResources().getDisplayMetrics().widthPixels - dp(28),
                                dp(660)),
                        (int) (getResources().getDisplayMetrics().heightPixels * 0.92f));
            }
        });
        dialog.show();
    }

    private static final class ProcessedPreview {
        final Bitmap display;
        final Bitmap zebra;

        ProcessedPreview(Bitmap display, Bitmap zebra) {
            this.display = display;
            this.zebra = zebra;
        }
    }

    private static final class PreviewPacket {
        final int generation;
        final byte[] jpeg;
        final boolean monitoring;

        PreviewPacket(int generation, byte[] jpeg, boolean monitoring) {
            this.generation = generation;
            this.jpeg = jpeg;
            this.monitoring = monitoring;
        }
    }

    private static final class LibraryBranch {
        final String id;
        final String name;
        final List<LibraryBranch> children = new ArrayList<>();

        LibraryBranch(String id, String name) {
            this.id = id;
            this.name = name;
        }

        LibraryBranch find(String requestedId) {
            if (id.equals(requestedId)) return this;
            for (LibraryBranch child : children) {
                LibraryBranch found = child.find(requestedId);
                if (found != null) return found;
            }
            return null;
        }

        void collectIds(Set<String> ids) {
            ids.add(id);
            for (LibraryBranch child : children) {
                child.collectIds(ids);
            }
        }

        JSONObject toJson() {
            JSONObject object = new JSONObject();
            JSONArray childArray = new JSONArray();
            try {
                object.put("id", id);
                object.put("name", name);
                for (LibraryBranch child : children) {
                    childArray.put(child.toJson());
                }
                object.put("children", childArray);
            } catch (Exception ignored) {
            }
            return object;
        }

        static LibraryBranch fromJson(JSONObject object) throws Exception {
            LibraryBranch branch = new LibraryBranch(
                    object.optString("id", UUID.randomUUID().toString()),
                    object.optString("name", "未命名分支"));
            JSONArray childArray = object.optJSONArray("children");
            if (childArray != null) {
                for (int index = 0; index < childArray.length(); index++) {
                    branch.children.add(
                            fromJson(childArray.getJSONObject(index)));
                }
            }
            return branch;
        }
    }

    private static final class MediaEntry {
        final Uri uri;
        final String name;
        final boolean video;
        final long dateMillis;
        final long size;
        final long durationMillis;

        MediaEntry(
                Uri uri,
                String name,
                boolean video,
                long dateMillis,
                long size,
                long durationMillis) {
            this.uri = uri;
            this.name = name == null || name.isEmpty()
                    ? (video ? "系统视频" : "系统照片")
                    : name;
            this.video = video;
            this.dateMillis = dateMillis;
            this.size = size;
            this.durationMillis = durationMillis;
        }
    }

    @Override
    protected void onDestroy() {
        diagnostics.endSession();
        previewGeneration++;
        pendingPreview.set(null);
        if (immersiveDialog != null) {
            closeImmersivePreview(immersiveDialog);
        }
        wirelessRequested = false;
        wirelessServer.stop();
        cameraExecutor.submit(camera::disconnect);
        cameraExecutor.shutdown();
        previewExecutor.shutdownNow();
        updateExecutor.shutdownNow();
        editorExecutor.shutdownNow();
        super.onDestroy();
    }
}
