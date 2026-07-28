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
import android.os.Build;
import android.os.Bundle;
import android.os.Environment;
import android.os.Handler;
import android.os.Looper;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;
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
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.Date;
import java.util.List;
import java.util.Locale;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;

public final class MainActivity extends Activity {
    private static final String USB_PERMISSION_ACTION = "com.tauber.nikonlink.USB_PERMISSION";
    private static final int PAPER = Color.rgb(246, 248, 252);
    private static final int SURFACE = Color.WHITE;
    private static final int INK = Color.rgb(20, 24, 32);
    private static final int MUTED = Color.rgb(91, 102, 119);
    private static final int COBALT = Color.rgb(5, 90, 210);
    private static final int COBALT_SOFT = Color.rgb(225, 237, 255);
    private static final int GRAPHITE = Color.rgb(12, 15, 21);
    private static final int RULE = Color.rgb(220, 225, 234);

    private final ExecutorService cameraExecutor = Executors.newSingleThreadExecutor();
    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private final List<View> cameraControls = new ArrayList<>();
    private final List<Button> navigationButtons = new ArrayList<>();

    private PtpCamera camera;
    private FrameLayout contentHost;
    private TextView statusText;
    private TextView countText;
    private Button connectButton;
    private Button simpleModeButton;
    private Button professionalModeButton;
    private ImageView previewImage;
    private TextView previewPlaceholder;
    private Button shutterButton;
    private Button liveViewButton;
    private Button wirelessButton;
    private TextView wirelessStatusText;
    private TextView wirelessAddressText;
    private Bitmap latestFrame;
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
    private boolean professionalMode;
    private String currentSection = "capture";

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        Window window = getWindow();
        window.setStatusBarColor(PAPER);
        window.setNavigationBarColor(GRAPHITE);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            window.getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR);
        }

        camera = new PtpCamera(this);
        File base = getExternalFilesDir(Environment.DIRECTORY_PICTURES);
        if (base == null) base = getFilesDir();
        photoDirectory = new File(base, "Nikon Link");
        if (!photoDirectory.exists()) photoDirectory.mkdirs();
        wirelessServer = new WirelessFtpServer(
                photoDirectory,
                new WirelessFtpServer.Listener() {
                    @Override
                    public void onStatus(String status) {
                        mainHandler.post(() -> {
                            wirelessStatus = status;
                            updateWirelessUi();
                        });
                    }

                    @Override
                    public void onFileReceived(File file) {
                        mainHandler.post(() -> {
                            wirelessStatus = "已接收 " + file.getName();
                            updateWirelessUi();
                            updateFileCount();
                            showToast("无线图片已保存：" + file.getName());
                        });
                    }

                    @Override
                    public void onError(String message) {
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
        System.out.println("Nikon Link native Android UI ready");
    }

    private View buildApplication() {
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(PAPER);

        root.addView(buildTopBar(), new LinearLayout.LayoutParams(
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
        root.addView(buildStatusBar(), new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(30)));
        return root;
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
        navigation.addView(navButton("拍摄", "capture"));
        navigation.addView(navButton("监看", "monitor"));
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
            button.setTextColor(active ? COBALT : MUTED);
            button.setBackground(rounded(active ? COBALT_SOFT : SURFACE, 10, 0));
        }
        updateCameraControls();
    }

    private View buildCaptureView() {
        ScrollView scroll = new ScrollView(this);
        LinearLayout content = verticalContainer();
        content.setPadding(dp(20), dp(22), dp(20), dp(28));
        content.addView(text("联机拍摄", 30, Typeface.BOLD, INK));
        content.addView(text(
                professionalMode
                        ? "原生 USB/PTP 控制台 · 曝光、对焦与实时取景"
                        : "只保留常用控制，连接相机即可拍摄",
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
        LinearLayout content = verticalContainer();
        content.setPadding(dp(20), dp(22), dp(20), dp(24));
        content.addView(text("实时监看", 30, Typeface.BOLD, INK));
        content.addView(text(
                connected
                        ? connectedCameraName + " · 原生 JPEG 实时取景"
                        : "支持 Z8 · Z f · Z6III · Z5II",
                14,
                Typeface.NORMAL,
                MUTED),
                marginParams(-1, -2, 0, 3, 0, 18));
        content.addView(buildPreviewStage(true), new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                0,
                1f));
        liveViewButton = nativeButton(liveViewEnabled ? "停止监看" : "开始监看", true);
        liveViewButton.setOnClickListener(view -> toggleLiveView());
        cameraControls.add(liveViewButton);
        LinearLayout.LayoutParams buttonParams = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(50));
        buttonParams.setMargins(0, dp(16), 0, 0);
        content.addView(liveViewButton, buttonParams);
        return content;
    }

    private View buildPreviewStage(boolean fillHeight) {
        FrameLayout stage = new FrameLayout(this);
        stage.setBackground(rounded(GRAPHITE, 14, 0));

        previewImage = new ImageView(this);
        previewImage.setScaleType(ImageView.ScaleType.FIT_CENTER);
        previewImage.setBackgroundColor(GRAPHITE);
        if (latestFrame != null) previewImage.setImageBitmap(latestFrame);
        stage.addView(previewImage, new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT));

        previewPlaceholder = text(
                connected ? "等待实时取景画面" : "连接支持的 Nikon 相机开始监看",
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

        if (!fillHeight) {
            stage.setLayoutParams(new LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    dp(380)));
        }
        return stage;
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
        autofocus.setText("自动对焦 AF-S");
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
        boolean z8IsoRange = "Nikon Z8".equals(connectedCameraName);
        addSpinnerControl(
                panel,
                "ISO",
                z8IsoRange
                        ? new String[]{"64", "100", "200", "400", "800", "1600", "3200", "6400", "12800", "25600"}
                        : new String[]{"100", "200", "400", "800", "1600", "3200", "6400", "12800", "25600", "51200", "64000"},
                z8IsoRange
                        ? new Object[]{64, 100, 200, 400, 800, 1600, 3200, 6400, 12800, 25600}
                        : new Object[]{100, 200, 400, 800, 1600, 3200, 6400, 12800, 25600, 51200, 64000},
                z8IsoRange ? 3 : 2,
                "iso");
        addSpinnerControl(
                panel,
                "对焦模式",
                new String[]{"AF-S", "AF-C", "MF"},
                new Object[]{"single-shot", "continuous", "manual"},
                0,
                "focusMode");
        addSpinnerControl(
                panel,
                "曝光模式",
                new String[]{"P", "M", "A", "S", "B"},
                new Object[]{
                        "program",
                        "manual",
                        "aperturePriority",
                        "shutterPriority",
                        "bulb"},
                1,
                "exposureMode");
        addSpinnerControl(
                panel,
                "B 门时长（仅 B 模式）",
                new String[]{"1 秒", "2 秒", "5 秒", "10 秒", "30 秒", "60 秒"},
                new Object[]{1, 2, 5, 10, 30, 60},
                2,
                "bulbDuration");

        TextView compensationLabel = text("曝光补偿 · 0.0 EV", 13, Typeface.BOLD, MUTED);
        LinearLayout.LayoutParams labelParams = marginParams(-1, -2, 0, 12, 0, 2);
        panel.addView(compensationLabel, labelParams);
        SeekBar compensation = new SeekBar(this);
        compensation.setMax(100);
        compensation.setProgress(50);
        compensation.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
            @Override
            public void onProgressChanged(SeekBar seekBar, int progress, boolean fromUser) {
                double value = (progress - 50) / 10.0;
                compensationLabel.setText(String.format(Locale.CHINA, "曝光补偿 · %+.1f EV", value));
            }

            @Override public void onStartTrackingTouch(SeekBar seekBar) {}

            @Override
            public void onStopTrackingTouch(SeekBar seekBar) {
                double value = (seekBar.getProgress() - 50) / 10.0;
                applyParameter("exposureCompensation", value, "曝光补偿");
            }
        });
        cameraControls.add(compensation);
        panel.addView(compensation);
        return panel;
    }

    private void addSpinnerControl(
            LinearLayout parent,
            String label,
            String[] labels,
            Object[] values,
            int selected,
            String parameter) {
        parent.addView(
                text(label, 13, Typeface.BOLD, MUTED),
                marginParams(-1, -2, 0, 12, 0, 4));
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
                applyParameter(parameter, values[position], label);
            }

            @Override public void onNothingSelected(android.widget.AdapterView<?> parent) {}
        });
        cameraControls.add(spinner);
        parent.addView(spinner, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(48)));
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
                "Z8 · Z f · Z6III · Z5II",
                12,
                Typeface.BOLD,
                COBALT),
                marginParams(-1, -2, 0, 4, 0, 4));
        content.addView(text(
                "联机拍摄、参数控制、实时监看和文件管理",
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
        connecting = true;
        updateConnectionUi();
        cameraExecutor.submit(() -> {
            try {
                camera.connect();
                String detectedCameraName = camera.getConnectedCameraName();
                boolean liveViewStarted;
                try {
                    camera.startLiveView();
                    liveViewStarted = true;
                } catch (Exception ignored) {
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
        previewGeneration++;
        connected = false;
        liveViewEnabled = false;
        cameraExecutor.submit(camera::disconnect);
        connectedCameraName = "Nikon 相机";
        latestFrame = null;
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
            if (liveViewButton != null) liveViewButton.setText("开始监看");
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
                Bitmap bitmap = BitmapFactory.decodeByteArray(jpeg, 0, jpeg.length);
                mainHandler.post(() -> {
                    if (generation != previewGeneration) return;
                    latestFrame = bitmap;
                    if (previewImage != null) previewImage.setImageBitmap(bitmap);
                    if (previewPlaceholder != null) previewPlaceholder.setVisibility(View.GONE);
                    statusText.setText(connectedCameraName + " LIVE · USB/PTP");
                    mainHandler.postDelayed(() -> pullPreview(generation), 220);
                });
            } catch (Exception error) {
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
                Bitmap bitmap = BitmapFactory.decodeByteArray(jpeg, 0, jpeg.length);
                mainHandler.post(() -> {
                    capturing = false;
                    latestFrame = bitmap;
                    if (previewImage != null) previewImage.setImageBitmap(bitmap);
                    if (previewPlaceholder != null) previewPlaceholder.setVisibility(View.GONE);
                    if (shutterButton != null) shutterButton.setText("拍摄");
                    updateFileCount();
                    statusText.setText("已保存 " + file.getName());
                    showToast("拍摄完成，已保存到本地照片库。");
                });
            } catch (Exception error) {
                mainHandler.post(() -> {
                    capturing = false;
                    if (shutterButton != null) shutterButton.setText("拍摄");
                    showError(error.getMessage());
                });
            }
        });
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
        cameraExecutor.submit(() -> {
            try {
                camera.setParameter(name, value);
                mainHandler.post(() -> statusText.setText(label + "已应用"));
            } catch (Exception error) {
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
        new AlertDialog.Builder(this)
                .setTitle("Nikon Link")
                .setMessage(message == null ? "原生相机操作失败。" : message)
                .setPositiveButton("好", null)
                .show();
    }

    @Override
    protected void onDestroy() {
        previewGeneration++;
        wirelessRequested = false;
        wirelessServer.stop();
        cameraExecutor.submit(camera::disconnect);
        cameraExecutor.shutdown();
        super.onDestroy();
    }
}
