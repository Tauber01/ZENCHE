package com.tauber.nikonlink;

import android.app.Activity;
import android.app.AlertDialog;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.hardware.usb.UsbDevice;
import android.hardware.usb.UsbManager;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Environment;
import android.os.Handler;
import android.os.Looper;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;
import android.view.WindowInsets;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.SeekBar;
import android.widget.Spinner;
import android.widget.Switch;
import android.widget.TextView;
import android.widget.Toast;

import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.Date;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;

public final class MainActivity extends Activity {
    private static final String USB_PERMISSION_ACTION = "com.tauber.nikonlink.USB_PERMISSION";
    private static final int REQUEST_IMPORT_LUT = 4102;
    private static final int PAPER = Color.rgb(246, 248, 252);
    private static final int SURFACE = Color.WHITE;
    private static final int INK = Color.rgb(20, 24, 32);
    private static final int MUTED = Color.rgb(91, 102, 119);
    private static final int COBALT = Color.rgb(5, 90, 210);
    private static final int COBALT_SOFT = Color.rgb(225, 237, 255);
    private static final int VIDEO = Color.rgb(202, 31, 42);
    private static final int VIDEO_SOFT = Color.rgb(255, 230, 232);
    private static final int GRAPHITE = Color.rgb(12, 15, 21);
    private static final int RULE = Color.rgb(220, 225, 234);

    private final ExecutorService cameraExecutor = Executors.newSingleThreadExecutor();
    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private final List<View> cameraControls = new ArrayList<>();
    private final List<Button> navigationButtons = new ArrayList<>();
    private final Map<String, View> parameterControls = new HashMap<>();
    private final Map<String, TextView> parameterLabels = new HashMap<>();

    private PtpCamera camera;
    private DiagnosticLogger diagnostics;
    private FrameLayout contentHost;
    private TextView statusText;
    private TextView countText;
    private Button connectButton;
    private Button simpleModeButton;
    private Button professionalModeButton;
    private ImageView previewImage;
    private ImageView zebraImage;
    private TextView previewPlaceholder;
    private Button shutterButton;
    private Button liveViewButton;
    private Button wirelessButton;
    private TextView wirelessStatusText;
    private TextView wirelessAddressText;
    private TextView lutStatusText;
    private Switch lutSwitch;
    private SeekBar zebraThresholdControl;
    private Bitmap latestFrame;
    private Bitmap latestSourceFrame;
    private Bitmap latestZebraMask;
    private File photoDirectory;
    private WirelessFtpServer wirelessServer;

    private volatile boolean connected;
    private volatile boolean connecting;
    private volatile boolean liveViewEnabled;
    private volatile boolean capturing;
    private volatile boolean wirelessRequested;
    private volatile String wirelessStatus = "无线收件箱未开启";
    private volatile int previewGeneration;
    private volatile String connectedCameraName = "Nikon 相机";
    private volatile String exposureMode = "manual";
    private volatile boolean zebraEnabled;
    private volatile int zebraThreshold = 95;
    private volatile boolean lutEnabled;
    private volatile CubeLut previewLut;
    private volatile boolean monitorSupersampling;
    private volatile String monitorVideoProfile = "source";
    private boolean professionalMode;
    private String currentSection = "capture";

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        diagnostics = new DiagnosticLogger(this);
        diagnostics.startSession();
        Window window = getWindow();
        window.setStatusBarColor(PAPER);
        window.setNavigationBarColor(GRAPHITE);
        window.getDecorView().setSystemUiVisibility(
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                        | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                        | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                        | View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR);

        camera = new PtpCamera(this);
        monitorSupersampling = getSharedPreferences("nikon-link", MODE_PRIVATE)
                .getBoolean("monitorSupersampling", false);
        monitorVideoProfile = getSharedPreferences("nikon-link", MODE_PRIVATE)
                .getString("monitorVideoProfile", "source");
        File base = getExternalFilesDir(Environment.DIRECTORY_PICTURES);
        if (base == null) base = getFilesDir();
        photoDirectory = new File(base, "Nikon Link");
        if (!photoDirectory.exists()) photoDirectory.mkdirs();
        wirelessServer = new WirelessFtpServer(
                photoDirectory,
                new WirelessFtpServer.Listener() {
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
        showSection("capture");
        updateConnectionUi();
        diagnostics.info("app", "Android 原生界面已就绪");
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
        if (requestCode != REQUEST_IMPORT_LUT
                || resultCode != RESULT_OK
                || data == null
                || data.getData() == null) {
            return;
        }
        Uri uri = data.getData();
        try {
            getContentResolver().takePersistableUriPermission(
                    uri,
                    data.getFlags() & Intent.FLAG_GRANT_READ_URI_PERMISSION);
        } catch (RuntimeException ignored) {
        }
        String fallbackName = uri.getLastPathSegment();
        if (lutStatusText != null) lutStatusText.setText("正在读取 LUT…");
        cameraExecutor.submit(() -> {
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
                        lutStatusText.setText("已载入 · " + lut.getTitle());
                    }
                });
            } catch (Exception error) {
                mainHandler.post(() -> {
                    if (lutStatusText != null) {
                        lutStatusText.setText("导入失败；请选择有效的 3D .cube 文件。");
                    }
                    showError("LUT 导入失败：" + error.getMessage());
                });
            }
        });
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

        TextView logo = text("N", 20, Typeface.BOLD, Color.WHITE);
        logo.setGravity(Gravity.CENTER);
        logo.setBackground(rounded(GRAPHITE, 10, 0));
        top.addView(logo, new LinearLayout.LayoutParams(dp(40), dp(40)));

        LinearLayout brand = new LinearLayout(this);
        brand.setOrientation(LinearLayout.VERTICAL);
        brand.setPadding(dp(8), 0, 0, 0);
        brand.addView(text("Nikon Link", 15, Typeface.BOLD, INK));
        brand.addView(text("Android 原生版", 11, Typeface.NORMAL, MUTED));
        top.addView(brand, new LinearLayout.LayoutParams(dp(96), dp(44)));

        connectButton = nativeButton("连接相机", false);
        connectButton.setOnClickListener(view -> {
            if (connected) disconnectCamera();
            else showConnectionDialog();
        });
        top.addView(connectButton, new LinearLayout.LayoutParams(0, dp(46), 1f));

        LinearLayout modeSwitch = new LinearLayout(this);
        modeSwitch.setOrientation(LinearLayout.HORIZONTAL);
        modeSwitch.setPadding(dp(6), 0, 0, 0);
        simpleModeButton = nativeButton("普通", false);
        professionalModeButton = nativeButton("专业", false);
        simpleModeButton.setOnClickListener(view -> setProfessionalMode(false));
        professionalModeButton.setOnClickListener(view -> setProfessionalMode(true));
        modeSwitch.addView(simpleModeButton, new LinearLayout.LayoutParams(dp(50), dp(42)));
        modeSwitch.addView(professionalModeButton, new LinearLayout.LayoutParams(dp(50), dp(42)));
        top.addView(modeSwitch);
        updateModeButtons();
        return top;
    }

    private View buildBottomNavigation() {
        LinearLayout navigation = new LinearLayout(this);
        navigation.setOrientation(LinearLayout.HORIZONTAL);
        navigation.setGravity(Gravity.CENTER);
        navigation.setPadding(dp(8), dp(7), dp(8), dp(7));
        navigation.setBackgroundColor(SURFACE);
        navigation.addView(navButton("照片", "capture"));
        navigation.addView(navButton("视频", "monitor"));
        navigation.addView(navButton("文件", "library"));
        navigation.addView(navButton("传输", "transfer"));
        return navigation;
    }

    private View navButton(String label, String section) {
        Button button = nativeButton(label, false);
        button.setTag(section);
        button.setOnClickListener(view -> showSection(section));
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
            case "transfer":
                content = buildTransferView();
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
            button.setBackground(rounded(active ? activeBackground : SURFACE, 10, 0));
        }
        updateCameraControls();
    }

    private View buildCaptureView() {
        ScrollView scroll = new ScrollView(this);
        LinearLayout content = verticalContainer();
        content.setPadding(dp(20), dp(22), dp(20), dp(28));
        content.addView(text("照片拍摄", 30, Typeface.BOLD, INK));
        content.addView(text(
                professionalMode
                        ? "照片控制台 · 曝光、对焦、白平衡与快门"
                        : "连接相机、确认构图，然后完成照片拍摄",
                14,
                Typeface.NORMAL,
                MUTED),
                marginParams(-1, -2, 0, 3, 0, 18));
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

        if (professionalMode) content.addView(buildProfessionalControls());
        else content.addView(buildSimpleControls());
        scroll.addView(content);
        return scroll;
    }

    private View buildMonitorView() {
        ScrollView scroll = new ScrollView(this);
        LinearLayout content = verticalContainer();
        content.setPadding(dp(20), dp(22), dp(20), dp(24));
        content.addView(text("视频监看", 30, Typeface.BOLD, INK));
        content.addView(text(
                connected
                        ? connectedCameraName + " · 视频取景与本地监看处理"
                        : "EXPEED 7 · " + PtpCamera.SUPPORTED_CAMERA_SUMMARY,
                14,
                Typeface.NORMAL,
                MUTED),
                marginParams(-1, -2, 0, 3, 0, 18));
        content.addView(buildPreviewStage(true), new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(300)));
        liveViewButton = nativeButton(
                liveViewEnabled ? "停止实时取景" : "开启实时取景",
                true);
        liveViewButton.setOnClickListener(view -> toggleLiveView());
        cameraControls.add(liveViewButton);
        LinearLayout.LayoutParams buttonParams = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(50));
        buttonParams.setMargins(0, dp(16), 0, 0);
        content.addView(liveViewButton, buttonParams);
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

    private View buildMonitorParameterControls() {
        LinearLayout panel = panel();
        panel.addView(text("参数调节", 18, Typeface.BOLD, INK));
        panel.addView(text(
                connected
                        ? "高频参数通过 USB/PTP 写入 " + connectedCameraName
                        : "连接 Nikon 相机后启用参数控制",
                13,
                Typeface.NORMAL,
                MUTED),
                marginParams(-1, -2, 0, 3, 0, 14));

        addSpinnerControl(
                panel,
                "ISO感光度",
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
                compensationLabel.setText(String.format(
                        Locale.CHINA,
                        "曝光补偿 · %+.1f EV",
                        value));
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

        Switch supersampling = new Switch(this);
        supersampling.setText("本地 2× 超采样");
        supersampling.setTextColor(INK);
        supersampling.setChecked(monitorSupersampling);
        supersampling.setOnCheckedChangeListener((button, checked) -> {
            monitorSupersampling = checked;
            getSharedPreferences("nikon-link", MODE_PRIVATE)
                    .edit()
                    .putBoolean("monitorSupersampling", checked)
                    .apply();
            refreshPreviewProcessing();
            statusText.setText(checked
                    ? "本地 2× 超采样已开启"
                    : "本地 2× 超采样已关闭");
        });
        panel.addView(supersampling);

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
                statusText.setText("监看显示尺寸 · " + monitorProfileLabel());
            }

            @Override public void onNothingSelected(android.widget.AdapterView<?> parent) {}
        });
        panel.addView(profile, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(48)));

        panel.addView(text(
                "Nikon PTP 返回 JPEG 实时取景帧。显示尺寸和本地 2× 超采样仅处理监看画面，不等同于机身的“视频文件类型”“画面尺寸/帧频”或“扩展过采样”。",
                12,
                Typeface.NORMAL,
                MUTED),
                marginParams(-1, -2, 0, 10, 0, 0));
        addZebraControls(panel);
        addLutControls(panel);
        return panel;
    }

    private Spinner monitorSpinner(String[] labels) {
        Spinner spinner = new Spinner(this);
        ArrayAdapter<String> adapter = new ArrayAdapter<>(
                this,
                android.R.layout.simple_spinner_item,
                labels);
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

    private View buildSimpleControls() {
        LinearLayout panel = panel();
        panel.addView(text("普通模式", 18, Typeface.BOLD, INK));
        panel.addView(text(
                "自动曝光与常用对焦控制",
                13,
                Typeface.NORMAL,
                MUTED),
                marginParams(-1, -2, 0, 3, 0, 14));
        Switch autofocus = new Switch(this);
        autofocus.setText("AF-S 单次AF（关闭为MF手动对焦）");
        autofocus.setTextColor(INK);
        autofocus.setChecked(true);
        autofocus.setOnCheckedChangeListener((button, enabled) ->
                applyParameter(
                        "focusMode",
                        enabled ? "single-shot" : "manual",
                        "对焦模式"));
        cameraControls.add(autofocus);
        panel.addView(autofocus);
        return panel;
    }

    private View buildProfessionalControls() {
        LinearLayout panel = panel();
        panel.addView(text("专业参数", 18, Typeface.BOLD, INK));
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
                new String[]{"1/8000", "1/1000", "1/250", "1/125", "1/60", "1/15", "1 秒"},
                new Object[]{0.000125, 0.001, 0.004, 0.008, 0.0167, 0.0667, 1.0},
                3,
                "exposureTime");
        addSpinnerControl(
                panel,
                "光圈",
                new String[]{"F1.4", "F2.0", "F2.8", "F4.0", "F5.6", "F8", "F11", "F16", "F22"},
                new Object[]{1.4, 2.0, 2.8, 4.0, 5.6, 8.0, 11.0, 16.0, 22.0},
                3,
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
                compensationLabel.setText(String.format(Locale.CHINA, "曝光补偿 · %+.1f EV", value));
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
        if ("Nikon Z9".equals(connectedCameraName)
                || "Nikon Z8".equals(connectedCameraName)) {
            return new Object[]{
                    64, 100, 200, 400, 800, 1600, 3200, 6400, 12800, 25600
            };
        }
        if ("Nikon Z50II".equals(connectedCameraName)
                || "Nikon ZR".equals(connectedCameraName)) {
            return new Object[]{
                    100, 200, 400, 800, 1600, 3200, 6400, 12800, 25600, 51200
            };
        }
        return new Object[]{
                100, 200, 400, 800, 1600, 3200, 6400, 12800, 25600, 51200,
                64000
        };
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
                labels);
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
                if ("exposureMode".equals(parameter)) {
                    exposureMode = String.valueOf(values[position]);
                    updateCameraControls();
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
        enabled.setText("加亮显示");
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
                thresholdLabel.setText("加亮显示阈值 · " + zebraThreshold + " IRE");
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
        lutSwitch.setText("应用到实时取景");
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
                lutStatusText.setText("尚未导入；LUT 只影响监看，不写入原片。");
            }
            refreshPreviewProcessing();
        });
        LinearLayout.LayoutParams clearParams = new LinearLayout.LayoutParams(0, dp(44), 1f);
        clearParams.setMargins(dp(8), 0, 0, 0);
        actions.addView(clearButton, clearParams);
        parent.addView(actions, marginParams(-1, 44, 0, 6, 0, 0));

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
        content.addView(text("文件管理", 30, Typeface.BOLD, INK));
        content.addView(text(
                files.size() + " 个本地图像文件",
                14,
                Typeface.NORMAL,
                MUTED),
                marginParams(-1, -2, 0, 3, 0, 18));
        if (files.isEmpty()) {
            TextView empty = text(
                    "还没有联机拍摄文件\n照片将保存在 Nikon Link 本地照片库。",
                    15,
                    Typeface.NORMAL,
                    MUTED);
            empty.setGravity(Gravity.CENTER);
            content.addView(empty, new LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    dp(300)));
        } else {
            for (File file : files) content.addView(photoRow(file));
        }
        scroll.addView(content);
        return scroll;
    }

    private View photoRow(File file) {
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(Gravity.CENTER_VERTICAL);
        row.setPadding(dp(10), dp(10), dp(10), dp(10));
        row.setBackground(rounded(SURFACE, 12, RULE));
        LinearLayout.LayoutParams rowParams = marginParams(-1, dp(96), 0, 0, 0, 10);
        row.setLayoutParams(rowParams);

        BitmapFactory.Options options = new BitmapFactory.Options();
        options.inSampleSize = 4;
        ImageView thumbnail = new ImageView(this);
        thumbnail.setScaleType(ImageView.ScaleType.CENTER_CROP);
        thumbnail.setImageBitmap(BitmapFactory.decodeFile(file.getAbsolutePath(), options));
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
        row.addView(details, new LinearLayout.LayoutParams(0, dp(76), 1f));

        Button delete = nativeButton("删除", false);
        delete.setOnClickListener(view -> new AlertDialog.Builder(this)
                .setTitle("删除照片？")
                .setMessage(file.getName())
                .setNegativeButton("取消", null)
                .setPositiveButton("删除", (dialog, which) -> {
                    if (!file.delete()) {
                        showToast("无法删除文件。");
                    }
                    showSection("library");
                    updateFileCount();
                })
                .show());
        row.addView(delete, new LinearLayout.LayoutParams(dp(72), dp(42)));
        return row;
    }

    private View buildTransferView() {
        ScrollView scroll = new ScrollView(this);
        LinearLayout content = verticalContainer();
        content.setPadding(dp(20), dp(22), dp(20), dp(24));
        content.addView(text("无线传输", 30, Typeface.BOLD, INK));
        content.addView(text(
                "通过相机内置 Wi-Fi，把 JPEG、NEF 或 HEIF 直接发送到 Nikon Link。",
                14,
                Typeface.NORMAL,
                MUTED),
                marginParams(-1, -2, 0, 3, 0, 20));
        content.addView(infoCard(
                "本地照片库",
                photoFiles().size() + " 个文件"));
        content.addView(infoCard(
                "无线收件箱",
                wirelessStatus));

        LinearLayout settings = panel();
        settings.addView(text("相机 FTP 设置", 18, Typeface.BOLD, INK));
        settings.addView(text(
                "适用于相机直连热点或同一局域网",
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
        content.addView(settings);

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
        Button reportIssue = nativeButton("提交 GitHub Issue", true);
        reportIssue.setOnClickListener(view -> openGithubIssue());
        diagnosticsPanel.addView(
                reportIssue,
                marginParams(-1, dp(48), 0, 8, 0, 0));
        diagnosticsPanel.addView(text(
                "将打开含最近脱敏日志的预填页面；在 GitHub 确认后才会提交。",
                11,
                Typeface.NORMAL,
                MUTED),
                marginParams(-1, -2, 0, 8, 0, 0));
        content.addView(
                diagnosticsPanel,
                marginParams(-1, -2, 0, 18, 0, 0));

        wirelessStatusText = text(
                "相机设置：网络菜单 → 连接到 FTP 服务器；服务器类型选择 FTP，PASV 模式选择开启，然后选择照片上传或开启自动上传。",
                12,
                Typeface.NORMAL,
                MUTED);
        content.addView(
                wirelessStatusText,
                marginParams(-1, -2, 0, 4, 0, 14));
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
        return "服务器类型：FTP"
                + "\n服务器地址：" + wirelessServer.getLocalAddress()
                + "\n端口：" + WirelessFtpServer.PORT
                + "\n用户名：" + WirelessFtpServer.USERNAME
                + "\n密码：" + WirelessFtpServer.PASSWORD
                + "\nPASV 模式：开启";
    }

    private void updateWirelessUi() {
        if (wirelessButton != null) {
            wirelessButton.setText(wirelessRequested ? "停止接收" : "开启无线接收");
            wirelessButton.setTextColor(wirelessRequested ? INK : Color.WHITE);
            wirelessButton.setBackground(rounded(
                    wirelessRequested ? SURFACE : COBALT,
                    9,
                    wirelessRequested ? RULE : 0));
        }
        if (wirelessAddressText != null) {
            wirelessAddressText.setText(wirelessSettingsText());
        }
        if (wirelessStatusText != null) {
            wirelessStatusText.setText(
                    (wirelessRequested ? wirelessStatus + "\n" : "")
                            + "相机设置：网络菜单 → 连接到 FTP 服务器；服务器类型选择 FTP，PASV 模式选择开启。");
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
        content.setPadding(dp(18), dp(16), dp(18), dp(16));
        content.addView(text("Nikon Z 系列原生 USB", 18, Typeface.BOLD, INK));
        content.addView(text(
                PtpCamera.SUPPORTED_CAMERA_SUMMARY.replace("、", " · "),
                12,
                Typeface.BOLD,
                COBALT),
                marginParams(-1, -2, 0, 4, 0, 4));
        content.addView(text(
                "照片拍摄、视频监看、参数控制和文件管理",
                13,
                Typeface.NORMAL,
                MUTED),
                marginParams(-1, -2, 0, 4, 0, 14));
        content.addView(text(
                "请打开相机，使用支持数据传输的 USB 线连接，并授权 Nikon Link 访问 USB 设备。",
                13,
                Typeface.NORMAL,
                MUTED));
        new AlertDialog.Builder(this)
                .setTitle("连接相机")
                .setView(content)
                .setNegativeButton("取消", null)
                .setPositiveButton("连接 Nikon 相机", (dialog, which) -> connectCamera())
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
                boolean liveViewStarted;
                try {
                    camera.startLiveView();
                    liveViewStarted = true;
                } catch (Exception ignored) {
                    diagnostics.warning(
                            "liveview",
                            "连接后自动开启实时取景失败：" + ignored.getMessage());
                    liveViewStarted = false;
                }
                boolean initialLiveView = liveViewStarted;
                mainHandler.post(() -> {
                    connectedCameraName = detectedCameraName;
                    connected = true;
                    connecting = false;
                    liveViewEnabled = initialLiveView;
                    showSection(currentSection);
                    updateConnectionUi();
                    if (initialLiveView) {
                        startPreviewLoop();
                        showToast(connectedCameraName + " 已通过原生 USB/PTP 连接。");
                    } else {
                        statusText.setText(connectedCameraName + " 已连接 · 实时取景需实机确认");
                        showToast(connectedCameraName + " 已连接，可拍摄和调整参数。");
                    }
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
        connected = false;
        liveViewEnabled = false;
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
            liveViewEnabled = false;
            cameraExecutor.submit(camera::stopLiveView);
            updateConnectionUi();
            if (liveViewButton != null) liveViewButton.setText("开启实时取景");
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
        int generation = ++previewGeneration;
        pullPreview(generation);
    }

    private void pullPreview(int generation) {
        if (!connected || !liveViewEnabled || generation != previewGeneration) return;
        cameraExecutor.submit(() -> {
            try {
                byte[] jpeg = camera.getLiveViewFrame();
                Bitmap source = BitmapFactory.decodeByteArray(jpeg, 0, jpeg.length);
                ProcessedPreview output = processPreview(source);
                mainHandler.post(() -> {
                    if (generation != previewGeneration) return;
                    showProcessedPreview(source, output);
                    statusText.setText(connectedCameraName + " LIVE · USB/PTP");
                    mainHandler.postDelayed(() -> pullPreview(generation), 220);
                });
            } catch (Exception error) {
                diagnostics.warning(
                        "liveview",
                        "获取实时取景帧失败，将重试：" + error.getMessage());
                mainHandler.post(() -> {
                    if (generation != previewGeneration) return;
                    statusText.setText("实时取景正在重试");
                    mainHandler.postDelayed(() -> pullPreview(generation), 1200);
                });
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
        if (shutterButton != null) shutterButton.setText("拍摄中…");
        cameraExecutor.submit(() -> {
            try {
                byte[] jpeg = camera.capture();
                File file = savePhoto(jpeg);
                diagnostics.info(
                        "capture",
                        "拍摄完成；文件=" + file.getName()
                                + "；大小=" + file.length());
                Bitmap source = BitmapFactory.decodeByteArray(jpeg, 0, jpeg.length);
                ProcessedPreview output = processPreview(source);
                mainHandler.post(() -> {
                    capturing = false;
                    showProcessedPreview(source, output);
                    if (shutterButton != null) shutterButton.setText("拍摄");
                    updateFileCount();
                    statusText.setText("已保存 " + file.getName());
                    showToast("拍摄完成，已保存到本地照片库。");
                });
            } catch (Exception error) {
                diagnostics.error("capture", "拍摄失败：" + error.getMessage());
                mainHandler.post(() -> {
                    capturing = false;
                    if (shutterButton != null) shutterButton.setText("拍摄");
                    showError(error.getMessage());
                });
            }
        });
    }

    private ProcessedPreview processPreview(Bitmap source) {
        CubeLut lut = previewLut;
        Bitmap graded = lutEnabled && lut != null ? lut.apply(source) : source;
        Bitmap display = resampleMonitorPreview(graded);
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
        if (!monitorSupersampling) {
            if (targetWidth == source.getWidth() && targetHeight == source.getHeight()) return source;
            return Bitmap.createScaledBitmap(source, targetWidth, targetHeight, true);
        }

        int supersampledWidth = Math.min(4096, targetWidth * 2);
        int supersampledHeight = Math.max(
                1,
                (int) Math.round(
                        supersampledWidth * (source.getHeight() / (double) source.getWidth())));
        Bitmap intermediate = Bitmap.createScaledBitmap(
                source,
                supersampledWidth,
                supersampledHeight,
                true);
        Bitmap output = Bitmap.createScaledBitmap(
                intermediate,
                targetWidth,
                targetHeight,
                true);
        if (intermediate != source && intermediate != output) intermediate.recycle();
        return output;
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
        if (previewPlaceholder != null) previewPlaceholder.setVisibility(View.GONE);
    }

    private void refreshPreviewProcessing() {
        Bitmap source = latestSourceFrame;
        if (source == null) return;
        cameraExecutor.submit(() -> {
            ProcessedPreview output = processPreview(source);
            mainHandler.post(() -> showProcessedPreview(source, output));
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
        if (!photoDirectory.exists() && !photoDirectory.mkdirs()) {
            throw new Exception("无法创建 Nikon Link 照片目录。");
        }
        String stamp = new SimpleDateFormat("yyyyMMdd_HHmmss", Locale.CHINA).format(new Date());
        File file = new File(photoDirectory, "NIKON_" + stamp + ".JPG");
        try (FileOutputStream output = new FileOutputStream(file)) {
            output.write(jpeg);
        }
        return file;
    }

    private void applyParameter(String name, Object value, String label) {
        if (!connected) {
            showToast("连接支持的 Nikon 相机后才能调整参数。");
            return;
        }
        if (!canAdjustExposureParameter(name)) {
            showToast(label + "在当前拍摄模式下由相机控制。");
            return;
        }
        cameraExecutor.submit(() -> {
            try {
                camera.setParameter(name, value);
                diagnostics.info(
                        "camera",
                        "已设置参数；名称=" + name + "；值=" + value);
                mainHandler.post(() -> statusText.setText(label + "已应用"));
            } catch (Exception error) {
                diagnostics.error(
                        "camera",
                        "设置参数失败；名称=" + name + "；错误=" + error.getMessage());
                mainHandler.post(() -> showError(error.getMessage()));
            }
        });
    }

    private void setProfessionalMode(boolean professional) {
        if (professionalMode == professional) return;
        professionalMode = professional;
        updateModeButtons();
        if ("capture".equals(currentSection)) showSection("capture");
    }

    private void updateModeButtons() {
        if (simpleModeButton == null || professionalModeButton == null) return;
        simpleModeButton.setTextColor(professionalMode ? MUTED : COBALT);
        professionalModeButton.setTextColor(professionalMode ? COBALT : MUTED);
        simpleModeButton.setBackground(rounded(professionalMode ? SURFACE : COBALT_SOFT, 9, 0));
        professionalModeButton.setBackground(rounded(professionalMode ? COBALT_SOFT : SURFACE, 9, 0));
    }

    private void updateConnectionUi() {
        if (connectButton != null) {
            connectButton.setText(
                    connecting
                            ? "正在连接…"
                            : connected ? "断开 " + connectedCameraName.replace("Nikon ", "") : "连接相机");
            connectButton.setEnabled(!connecting);
        }
        if (statusText != null) {
            statusText.setText(connecting
                    ? "正在检测 Nikon 相机"
                    : connected ? connectedCameraName + " · USB/PTP" : "未连接");
        }
        if (liveViewButton != null) {
            liveViewButton.setText(liveViewEnabled ? "停止实时取景" : "开启实时取景");
        }
        updateCameraControls();
        updateFileCount();
    }

    private void updateCameraControls() {
        for (View control : cameraControls) control.setEnabled(connected);
        for (Map.Entry<String, View> entry : parameterControls.entrySet()) {
            boolean enabled = connected && canAdjustExposureParameter(entry.getKey());
            entry.getValue().setEnabled(enabled);
            entry.getValue().setAlpha(enabled ? 1f : 0.48f);
        }
        for (Map.Entry<String, TextView> entry : parameterLabels.entrySet()) {
            Object tag = entry.getValue().getTag();
            String base = tag == null ? entry.getValue().getText().toString() : String.valueOf(tag);
            String reason = exposureLockReason(entry.getKey());
            entry.getValue().setText(reason == null ? base : base + " · " + reason);
            entry.getValue().setAlpha(reason == null ? 1f : 0.62f);
        }
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
            case "bulbDuration":
                return "bulb".equals(exposureMode);
            default:
                return true;
        }
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
        if (countText != null) countText.setText(photoFiles().size() + " 张");
    }

    private List<File> photoFiles() {
        File[] files = photoDirectory.listFiles((dir, name) -> {
            String lower = name.toLowerCase(Locale.ROOT);
            return lower.endsWith(".jpg")
                    || lower.endsWith(".jpeg")
                    || lower.endsWith(".png")
                    || lower.endsWith(".nef")
                    || lower.endsWith(".heif")
                    || lower.endsWith(".heic")
                    || lower.endsWith(".tif")
                    || lower.endsWith(".tiff");
        });
        if (files == null) return Collections.emptyList();
        List<File> result = new ArrayList<>(Arrays.asList(files));
        result.sort((left, right) -> Long.compare(right.lastModified(), left.lastModified()));
        return result;
    }

    boolean ensureUsbPermission(UsbManager manager, UsbDevice device) throws InterruptedException {
        if (manager.hasPermission(device)) return true;
        CountDownLatch latch = new CountDownLatch(1);
        AtomicBoolean granted = new AtomicBoolean(false);
        BroadcastReceiver receiver = new BroadcastReceiver() {
            @Override
            public void onReceive(Context context, Intent intent) {
                if (!USB_PERMISSION_ACTION.equals(intent.getAction())) return;
                UsbDevice returned = intent.getParcelableExtra(UsbManager.EXTRA_DEVICE);
                if (returned != null && returned.getDeviceId() == device.getDeviceId()) {
                    granted.set(intent.getBooleanExtra(
                            UsbManager.EXTRA_PERMISSION_GRANTED,
                            false));
                    latch.countDown();
                }
            }
        };

        runOnUiThread(() -> {
            IntentFilter filter = new IntentFilter(USB_PERMISSION_ACTION);
            if (Build.VERSION.SDK_INT >= 33) {
                registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED);
            } else {
                registerReceiver(receiver, filter);
            }
            PendingIntent permissionIntent = PendingIntent.getBroadcast(
                    this,
                    device.getDeviceId(),
                    new Intent(USB_PERMISSION_ACTION).setPackage(getPackageName()),
                    PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_MUTABLE);
            manager.requestPermission(device, permissionIntent);
        });

        boolean finished = latch.await(35, TimeUnit.SECONDS);
        runOnUiThread(() -> {
            try {
                unregisterReceiver(receiver);
            } catch (IllegalArgumentException ignored) {
            }
        });
        return finished && granted.get();
    }

    private LinearLayout verticalContainer() {
        LinearLayout container = new LinearLayout(this);
        container.setOrientation(LinearLayout.VERTICAL);
        return container;
    }

    private LinearLayout panel() {
        LinearLayout panel = verticalContainer();
        panel.setPadding(dp(16), dp(16), dp(16), dp(16));
        panel.setBackground(rounded(SURFACE, 12, RULE));
        LinearLayout.LayoutParams params = marginParams(-1, -2, 0, 12, 0, 0);
        panel.setLayoutParams(params);
        return panel;
    }

    private TextView text(String value, int sp, int style, int color) {
        TextView text = new TextView(this);
        text.setText(value);
        text.setTextSize(sp);
        text.setTextColor(color);
        text.setTypeface(Typeface.create("sans", style));
        text.setGravity(Gravity.CENTER_VERTICAL);
        return text;
    }

    private Button nativeButton(String label, boolean primary) {
        Button button = new Button(this);
        button.setText(label);
        button.setTextSize(13);
        button.setTypeface(Typeface.create("sans", Typeface.BOLD));
        button.setTextColor(primary ? Color.WHITE : INK);
        button.setAllCaps(false);
        button.setGravity(Gravity.CENTER);
        button.setPadding(dp(10), 0, dp(10), 0);
        button.setBackground(rounded(primary ? COBALT : SURFACE, 9, primary ? 0 : RULE));
        button.setStateListAnimator(null);
        return button;
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
        Toast.makeText(this, message, Toast.LENGTH_SHORT).show();
    }

    private void showError(String message) {
        diagnostics.error("ui", message);
        new AlertDialog.Builder(this)
                .setTitle("Nikon Link")
                .setMessage(message == null ? "原生相机操作失败。" : message)
                .setPositiveButton("好", null)
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
            showToast("无法打开浏览器，请访问 github.com/Tauber01/NikonLink/issues");
        }
    }

    private static final class ProcessedPreview {
        final Bitmap display;
        final Bitmap zebra;

        ProcessedPreview(Bitmap display, Bitmap zebra) {
            this.display = display;
            this.zebra = zebra;
        }
    }

    @Override
    protected void onDestroy() {
        diagnostics.endSession();
        previewGeneration++;
        wirelessRequested = false;
        wirelessServer.stop();
        cameraExecutor.submit(camera::disconnect);
        cameraExecutor.shutdown();
        super.onDestroy();
    }
}
