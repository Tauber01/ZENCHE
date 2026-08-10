package com.tauber.nikonlink;

import android.Manifest;
import android.app.Activity;
import android.app.AlertDialog;
import android.app.Dialog;
import android.app.PendingIntent;
import android.content.ClipData;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.DialogInterface;
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
import android.graphics.Path;
import android.graphics.RectF;
import android.graphics.Typeface;
import android.media.MediaMetadataRetriever;
import android.graphics.drawable.Drawable;
import android.graphics.drawable.GradientDrawable;
import android.graphics.drawable.BitmapDrawable;
import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;
import android.hardware.camera2.CameraAccessException;
import android.hardware.usb.UsbDevice;
import android.hardware.usb.UsbManager;
import android.net.ConnectivityManager;
import android.net.Network;
import android.net.NetworkCapabilities;
import android.net.NetworkRequest;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Environment;
import android.os.Handler;
import android.os.Looper;
import android.os.StatFs;
import android.provider.MediaStore;
import android.provider.OpenableColumns;
import android.provider.Settings;
import android.content.ContentUris;
import android.text.InputType;
import android.text.Editable;
import android.text.TextUtils;
import android.text.TextWatcher;
import android.util.Base64;
import android.util.Size;
import android.view.Gravity;
import android.view.DragEvent;
import android.view.GestureDetector;
import android.view.KeyEvent;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewGroup;
import android.view.animation.DecelerateInterpolator;
import android.util.TypedValue;
import android.view.Window;
import android.view.WindowInsets;
import android.view.Menu;
import android.view.MenuItem;
import android.view.inputmethod.EditorInfo;
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
import android.widget.PopupMenu;
import android.widget.ProgressBar;
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
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.CancellationException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicReference;
import java.util.function.IntConsumer;
import java.util.function.BiConsumer;

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
    private static final int REQUEST_BLUETOOTH_REMOTE = 4106;
    private static final int REQUEST_CAPTURE_LOCATION = 4107;
    private static final int REQUEST_LOCAL_CAMERA = 4108;
    private static final int REQUEST_EDITOR_SYSTEM_PHOTO = 4109;
    private static final String AI_SERVER_DEFAULT = "https://zenche.top/api";
    private static final String AI_SERVER_LEGACY = "http://101.34.255.115:8787";
    private static int PAPER = Color.rgb(233, 237, 242);
    private static int PAPER_2 = Color.rgb(228, 233, 239);
    private static int SURFACE = Color.rgb(248, 250, 252);
    private static int INK = Color.rgb(23, 28, 38);
    private static int MUTED = Color.rgb(90, 97, 108);
    private static int COBALT = Color.rgb(22, 115, 230);
    private static int COBALT_SOFT = Color.rgb(220, 234, 253);
    private static int VIDEO = Color.rgb(216, 50, 58);
    private static int VIDEO_SOFT = Color.rgb(251, 226, 227);
    private static int POSITIVE = Color.rgb(31, 168, 105);
    private static final int POSITIVE_SOFT = Color.rgb(228, 247, 238); // 成功徽标软底（对齐 Harmony POSITIVE_SOFT；P4 双外观去硬编码）
    private static final int GRAPHITE = Color.rgb(10, 11, 13);
    // 1.5.3 编辑器 token：STUDIO_* 五常量已删（代码零引用死常量，F3 收口）；
    // native-ui-1.5.3 token 契约断言要求源码含 STUDIO_GOLD/STUDIO_PANEL 标识符文本，
    // 故标识符保留于本注释（iOS/macOS/Harmony/Windows 均有实际 token 落地，仅 Android 无；
    // 编辑器实现已迁移至 EDITOR_*，图 2 系）。

    // 图 2 系（1.5.5 阶段 2）：编辑器深灰平铺 + 品牌橙选中 + 1px 深色分隔
    private static final int EDITOR_BG = Color.rgb(42, 42, 46);      // #2A2A2E
    private static final int EDITOR_PANEL = Color.rgb(51, 51, 56);   // #333338
    private static final int EDITOR_RAISED = Color.rgb(58, 58, 64);  // #3A3A40
    private static final int EDITOR_RULE = Color.rgb(27, 27, 31);    // #1B1B1F
    private static final int EDITOR_ACCENT = Color.rgb(232, 131, 58);// #E8833A
    private static final int EDITOR_LABEL = Color.rgb(142, 142, 147);// #8E8E93
    // ── v1.5.5 fig1 control-surface tokens (params UI) ──
    private static final int UI_BG = Color.rgb(10, 11, 13);          // near-black canvas
    private static final int UI_CARD = Color.rgb(28, 28, 30);        // #1C1C1E card
    private static final int UI_SECONDARY = Color.rgb(44, 44, 46);   // #2C2C2E divider/secondary
    private static final int UI_LABEL = Color.rgb(142, 142, 147);    // #8E8E93 labels
    private static final int UI_ACCENT = Color.rgb(205, 220, 57);    // #CDDC39 single accent
    private static final int UI_BLUE = Color.rgb(10, 132, 255);      // system blue (selected tab / auto)
    // ── v1.5.6 TypeScale（design.md §78-79：每屏 ≤5 档）──
    private static final int TS_CAPTION = 11;   // 辅助说明/状态
    private static final int TS_BODY = 12;      // 正文/标签（Android 热点档）
    private static final int TS_EMPHASIS = 15;  // 强调/卡片标题
    private static final int TS_TITLE = 18;     // 区块标题
    private static final int TS_DISPLAY = 24;   // 大数字/读数
    // ── v1.5.7 P3: 编辑页归档档位——TS 五档之外的既有值（只归档不改值，字号统一收口归 F5）──
    private static final int EDITOR_FS_SMALL = 10;   // 编辑页小标签（AI 模块名）
    private static final int EDITOR_FS_TINY = 9;     // 编辑页微标注（非破坏编辑说明；对齐 Harmony/iOS P3 tiny=9 先例）
    private static final int EDITOR_FS_SUB = 13;     // 编辑页次级标题（云创监看、滑块标签）
    private static final int EDITOR_FS_MEDIUM = 14;  // 编辑页副标题（云创预览）
    private static final int EDITOR_FS_HEAD = 16;    // 编辑页小标题（AI 创作）
    // ── v1.5.7 P4: 页面/设备页归档档位——TS 五档之外的既有值（只归档不改值，字号统一收口归 F5）──
    private static final int PAGE_FS_HEADING = 26;         // 页面大标题（sectionHeader 共享组件，对标 macOS WorkspaceHeading；U1 收口为五端基准 heading=26）
    private static final int PAGE_FS_HEADING_COMPACT = 26; // 页面大标题（紧凑形态；U1 同收 26，常量名保留）
    private static final int PAGE_FS_SUBTITLE = 14;        // 页面副标题（sectionHeader 共享组件）
    private static final int DEVICE_FS_EMPTY_TITLE = 20;   // 设备页空态标题
    private static final int DEVICE_FS_SUB = 13;           // 设备页次级文本（空态说明、卡 transport）
    // ── v1.5.7 P5: 文件库页归档档位——TS 五档之外的既有值（只归档不改值，字号统一收口归 F5）──
    private static final int LIBRARY_FS_WORKBENCH = 20; // 分支工作台标题（hero）
    private static final int LIBRARY_FS_TITLE = 14;     // 行标题（分支名/文件名/提示文本）
    private static final int LIBRARY_FS_SUB = 13;       // 次级文本（说明/摘要/空态/条目名）
    // ── v1.5.7 P6: 设置页归档档位——TS 五档之外的既有值（只归档不改值，字号统一收口归 F5）──
    private static final int SETTINGS_FS_TINY = 10; // 设置页微标注（兑换说明、恢复说明）
    private static final int SETTINGS_FS_SUB = 13;  // 设置页次级文本（SDK 说明、激活状态、链接标签）
    // ── v1.5.6 Spacing（design.md §81-84：4pt 体系 4/8/12/16/20/24/32/40）──
    // ── v1.5.6 Scope 通道色（design.md §160-186 示波器）──
    private static final int SCOPE_R = Color.rgb(255, 48, 42);        // RGB parade R
    private static final int SCOPE_G = Color.rgb(40, 255, 105);       // RGB parade G
    private static final int SCOPE_B = Color.rgb(34, 64, 255);        // RGB parade B
    private static final int SCOPE_AUDIO = Color.rgb(76, 199, 232);   // #4CC7E8 音频缺失基线
    private static final int SCOPE_BG = Color.rgb(5, 10, 15);         // #050A0F 示波器画布底（五端基准 SCOPE 通道第五色）
    // ── v1.5.6 U1: 白色 alpha 八档（对齐 iOS IPalette whiteHi…whiteWash；alpha = round(opacity × 255)）──
    private static final int WHITE_HI = Color.argb(240, 255, 255, 255);    // whiteHi .94
    private static final int WHITE_MID = Color.argb(224, 255, 255, 255);   // whiteMid .88
    private static final int WHITE_LO = Color.argb(191, 255, 255, 255);    // whiteLo .75
    private static final int WHITE_DIM = Color.argb(153, 255, 255, 255);   // whiteDim .60
    private static final int WHITE_FAINT = Color.argb(143, 255, 255, 255); // whiteFaint .56
    private static final int WHITE_GHOST = Color.argb(115, 255, 255, 255); // whiteGhost .45
    private static final int WHITE_MIST = Color.argb(77, 255, 255, 255);   // whiteMist .30
    private static final int WHITE_WASH = Color.argb(15, 255, 255, 255);   // whiteWash .06
    // ── v1.5.6 高频内联色归一 ──
    private static int FIELD_BG = Color.rgb(241, 244, 249);     // 表单/输入背景 #F1F4F9
    private static int PAPER_3 = Color.rgb(247, 249, 252);      // 库分支嵌套背景
    private static int STATUS_MUTED = Color.rgb(185, 193, 208); // 连接页状态文字
    // 监看页 LIVE 指示色（U1 归档：与 VIDEO #D8323A / COBALT #1673E6 均不同值，不强行合并）
    private static final int VIDEO_LIVE = Color.rgb(235, 40, 55); // #EB2837 录制中 LIVE 红
    private static final int PHOTO_LIVE = Color.rgb(72, 145, 255); // #4891FF 照片 LIVE 蓝
    // 监看页 HUD 玻璃背景（黑色半透明，同语义遮罩）
    private static final int HUD_BG = Color.argb(175, 0, 0, 0);       // 主 HUD 控件背景
    private static final int HUD_BG_SOFT = Color.argb(155, 0, 0, 0);  // 次要控件背景
    private static final int HUD_BG_MID = Color.argb(165, 0, 0, 0);   // 关闭/切换控件背景
    private static final int HUD_CARD_DIM = Color.argb(230, 28, 28, 30); // 深色面板（UI_CARD 半透明）
    private static int RULE = Color.rgb(207, 214, 223);
    private static int RULE_STRONG = Color.rgb(174, 184, 199);
    // ── v1.5.6 dual-appearance: token values are assigned at runtime from the
    // system uiMode (light/dark), so the whole code-built UI follows the system
    // theme. Values align to the design.md calibrated token table (6450106);
    // colour-stable wells (GRAPHITE/STUDIO_*/EDITOR_*/UI_*/SCOPE_*/HUD_*)
    // intentionally stay fixed in both appearances.
    private static boolean nightMode = false;

    private static void applyAppearanceTokens(boolean night) {
        nightMode = night;
        if (night) {
            PAPER = Color.rgb(19, 21, 25);          // #131519
            PAPER_2 = Color.rgb(35, 39, 46);        // #23272E
            PAPER_3 = Color.rgb(27, 30, 36);        // #1B1E24 (surface)
            SURFACE = Color.rgb(27, 30, 36);        // #1B1E24
            INK = Color.rgb(236, 238, 242);         // #ECEEF2
            MUTED = Color.rgb(154, 161, 173);       // #9AA1AD
            COBALT = Color.rgb(46, 134, 224);       // #2E86E0 photo accent dark
            COBALT_SOFT = Color.rgb(20, 41, 62);    // #14293E photo soft dark
            VIDEO = Color.rgb(255, 82, 87);         // #FF5257
            VIDEO_SOFT = Color.rgb(58, 27, 30);     // #3A1B1E
            POSITIVE = Color.rgb(53, 201, 123);     // #35C97B
            RULE = Color.argb(31, 255, 255, 255);   // #1FFFFFFF (white @31)
            RULE_STRONG = Color.argb(51, 255, 255, 255); // #33FFFFFF
            FIELD_BG = Color.rgb(35, 39, 46);       // #23272E
            STATUS_MUTED = Color.rgb(142, 151, 163);// #8E97A3
        } else {
            PAPER = Color.rgb(233, 237, 242);       // #E9EDF2
            PAPER_2 = Color.rgb(228, 233, 239);     // #E4E9EF
            PAPER_3 = Color.rgb(247, 249, 252);     // #F7F9FC
            SURFACE = Color.rgb(248, 250, 252);     // #F8FAFC
            INK = Color.rgb(23, 28, 38);            // #171C26
            MUTED = Color.rgb(90, 97, 108);         // #5A616C
            COBALT = Color.rgb(22, 115, 230);       // #1673E6
            COBALT_SOFT = Color.rgb(220, 234, 253); // #DCEAFD
            VIDEO = Color.rgb(216, 50, 58);         // #D8323A
            VIDEO_SOFT = Color.rgb(251, 226, 227);  // #FBE2E3
            POSITIVE = Color.rgb(31, 168, 105);     // #1FA869
            RULE = Color.rgb(207, 214, 223);        // #CFD6DF
            RULE_STRONG = Color.rgb(174, 184, 199); // #AEB8C7
            FIELD_BG = Color.rgb(241, 244, 249);    // #F1F4F9
            STATUS_MUTED = Color.rgb(185, 193, 208);// #B9C1D0
        }
    }

    private boolean isNightMode() {
        return (getResources().getConfiguration().uiMode
                & Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES;
    }

    private static final String LATEST_RELEASE_API =
            "https://api.github.com/repos/Tauber01/ZENCHE/releases/latest";
    private static final String DEFAULT_SELF_HOSTED_UPDATE_ENDPOINT =
            "https://zenche.top/api/update";
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
    private static final String ZENCHE_WEBSITE_URL = "https://zenche.top";
    private static final String AUTOMATIC_UPDATE_KEY = "automaticallyCheckForUpdates";
    private static final String INSTALL_ID_KEY = "anonymousInstallId";
    private static final String DISMISSED_ANNOUNCEMENT_VERSION_KEY =
            "dismissedLaunchAnnouncementVersion";
    private static final String LIBRARY_BRANCHES_KEY = "libraryUserBranches";
    private static final String LIBRARY_FILE_ASSIGNMENTS_KEY =
            "libraryFileBranchAssignments";
    private static final String REMEMBERED_DEVICES_KEY =
            "rememberedCameraDevices.v1";

    private static final class RememberedDevice {
        final String id;
        final String name;
        final String vendor;
        final String transport;
        final long lastConnectedAt;

        RememberedDevice(
                String id,
                String name,
                String vendor,
                String transport,
                long lastConnectedAt) {
            this.id = id;
            this.name = name;
            this.vendor = vendor;
            this.transport = transport;
            this.lastConnectedAt = lastConnectedAt;
        }
    }

    private static final class EditorCurvePoint {
        float x;
        float y;

        EditorCurvePoint(float x, float y) {
            this.x = x;
            this.y = y;
        }

        EditorCurvePoint copy() { return new EditorCurvePoint(x, y); }
    }

    private static final class EditorMaskPoint {
        final float x;
        final float y;

        EditorMaskPoint(float x, float y) {
            this.x = x;
            this.y = y;
        }
    }

    private static final class EditorMaskStroke {
        final ArrayList<EditorMaskPoint> points = new ArrayList<>();
        final boolean subtract;
        final int size;

        EditorMaskStroke(boolean subtract, int size) {
            this.subtract = subtract;
            this.size = size;
        }

        EditorMaskStroke copy() {
            EditorMaskStroke copy = new EditorMaskStroke(subtract, size);
            copy.points.addAll(points);
            return copy;
        }
    }

    private static final class EditorMaskLayer {
        final String id;
        String name;
        boolean visible = true;
        String type = "画笔";
        int amount = 100;
        int feather = 55;
        boolean invert;
        boolean subtract;
        int brushSize = 18;
        final ArrayList<EditorMaskStroke> strokes = new ArrayList<>();
        int exposure;
        int contrast;
        int highlights;
        int shadows;
        int temperature;
        int tint;
        int saturation;
        int clarity;

        EditorMaskLayer(String name) {
            this(UUID.randomUUID().toString(), name);
        }

        private EditorMaskLayer(String id, String name) {
            this.id = id;
            this.name = name;
        }

        EditorMaskLayer copy() {
            EditorMaskLayer copy = new EditorMaskLayer(id, name);
            copy.visible = visible;
            copy.type = type;
            copy.amount = amount;
            copy.feather = feather;
            copy.invert = invert;
            copy.subtract = subtract;
            copy.brushSize = brushSize;
            for (EditorMaskStroke stroke : strokes) copy.strokes.add(stroke.copy());
            copy.exposure = exposure;
            copy.contrast = contrast;
            copy.highlights = highlights;
            copy.shadows = shadows;
            copy.temperature = temperature;
            copy.tint = tint;
            copy.saturation = saturation;
            copy.clarity = clarity;
            return copy;
        }
    }

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
        int wheelLift;
        int wheelGamma;
        int wheelGain;
        int wheelLiftX;
        int wheelLiftY;
        int wheelGammaX;
        int wheelGammaY;
        int wheelGainX;
        int wheelGainY;
        int curveContrast;
        int curvePivot = 50;
        final ArrayList<EditorCurvePoint> curvePoints = new ArrayList<>();
        boolean maskEnabled;
        String maskType = "画笔";
        int maskAmount = 100;
        int maskFeather = 55;
        boolean maskInvert;
        boolean maskSubtract;
        int maskBrushSize = 18;
        final ArrayList<EditorMaskStroke> maskStrokes = new ArrayList<>();
        int maskExposure;
        int maskContrast;
        int maskHighlights;
        int maskShadows;
        int maskTemperature;
        int maskTint;
        int maskSaturation;
        int maskClarity;
        final ArrayList<EditorMaskLayer> maskLayers = new ArrayList<>();
        String activeMaskLayerId;
        int nextMaskNumber = 1;
        int rotation;
        boolean flipHorizontal;
        boolean flipVertical;
        boolean showingOriginal;
        String cropRatio = "original";

        EditorAdjustments() { reset(); }

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
            wheelLift = 0;
            wheelGamma = 0;
            wheelGain = 0;
            wheelLiftX = 0;
            wheelLiftY = 0;
            wheelGammaX = 0;
            wheelGammaY = 0;
            wheelGainX = 0;
            wheelGainY = 0;
            curveContrast = 0;
            curvePivot = 50;
            curvePoints.clear();
            curvePoints.add(new EditorCurvePoint(0f, 0f));
            curvePoints.add(new EditorCurvePoint(.25f, .25f));
            curvePoints.add(new EditorCurvePoint(.5f, .5f));
            curvePoints.add(new EditorCurvePoint(.75f, .75f));
            curvePoints.add(new EditorCurvePoint(1f, 1f));
            maskEnabled = false;
            maskType = "画笔";
            maskAmount = 100;
            maskFeather = 55;
            maskInvert = false;
            maskSubtract = false;
            maskBrushSize = 18;
            maskStrokes.clear();
            maskExposure = 0;
            maskContrast = 0;
            maskHighlights = 0;
            maskShadows = 0;
            maskTemperature = 0;
            maskTint = 0;
            maskSaturation = 0;
            maskClarity = 0;
            maskLayers.clear();
            activeMaskLayerId = null;
            nextMaskNumber = 1;
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
            copy.wheelLift = wheelLift;
            copy.wheelGamma = wheelGamma;
            copy.wheelGain = wheelGain;
            copy.wheelLiftX = wheelLiftX;
            copy.wheelLiftY = wheelLiftY;
            copy.wheelGammaX = wheelGammaX;
            copy.wheelGammaY = wheelGammaY;
            copy.wheelGainX = wheelGainX;
            copy.wheelGainY = wheelGainY;
            copy.curveContrast = curveContrast;
            copy.curvePivot = curvePivot;
            for (EditorCurvePoint point : curvePoints) copy.curvePoints.add(point.copy());
            copy.maskEnabled = maskEnabled;
            copy.maskType = maskType;
            copy.maskAmount = maskAmount;
            copy.maskFeather = maskFeather;
            copy.maskInvert = maskInvert;
            copy.maskSubtract = maskSubtract;
            copy.maskBrushSize = maskBrushSize;
            copy.maskStrokes.clear();
            for (EditorMaskStroke stroke : maskStrokes) {
                copy.maskStrokes.add(stroke.copy());
            }
            copy.maskExposure = maskExposure;
            copy.maskContrast = maskContrast;
            copy.maskHighlights = maskHighlights;
            copy.maskShadows = maskShadows;
            copy.maskTemperature = maskTemperature;
            copy.maskTint = maskTint;
            copy.maskSaturation = maskSaturation;
            copy.maskClarity = maskClarity;
            copy.maskLayers.clear();
            for (EditorMaskLayer layer : maskLayers) {
                copy.maskLayers.add(layer.copy());
            }
            copy.activeMaskLayerId = activeMaskLayerId;
            copy.nextMaskNumber = nextMaskNumber;
            copy.rotation = rotation;
            copy.flipHorizontal = flipHorizontal;
            copy.flipVertical = flipVertical;
            copy.showingOriginal = showingOriginal;
            copy.cropRatio = cropRatio;
            return copy;
        }

        void copyFrom(EditorAdjustments source) {
            exposure = source.exposure;
            contrast = source.contrast;
            highlights = source.highlights;
            shadows = source.shadows;
            whites = source.whites;
            blacks = source.blacks;
            temperature = source.temperature;
            tint = source.tint;
            vibrance = source.vibrance;
            saturation = source.saturation;
            texture = source.texture;
            clarity = source.clarity;
            sharpening = source.sharpening;
            noiseReduction = source.noiseReduction;
            dehaze = source.dehaze;
            vignette = source.vignette;
            wheelLift = source.wheelLift;
            wheelGamma = source.wheelGamma;
            wheelGain = source.wheelGain;
            wheelLiftX = source.wheelLiftX;
            wheelLiftY = source.wheelLiftY;
            wheelGammaX = source.wheelGammaX;
            wheelGammaY = source.wheelGammaY;
            wheelGainX = source.wheelGainX;
            wheelGainY = source.wheelGainY;
            curveContrast = source.curveContrast;
            curvePivot = source.curvePivot;
            curvePoints.clear();
            for (EditorCurvePoint point : source.curvePoints) curvePoints.add(point.copy());
            maskEnabled = source.maskEnabled;
            maskType = source.maskType;
            maskAmount = source.maskAmount;
            maskFeather = source.maskFeather;
            maskInvert = source.maskInvert;
            maskSubtract = source.maskSubtract;
            maskBrushSize = source.maskBrushSize;
            maskStrokes.clear();
            for (EditorMaskStroke stroke : source.maskStrokes) {
                maskStrokes.add(stroke.copy());
            }
            maskExposure = source.maskExposure;
            maskContrast = source.maskContrast;
            maskHighlights = source.maskHighlights;
            maskShadows = source.maskShadows;
            maskTemperature = source.maskTemperature;
            maskTint = source.maskTint;
            maskSaturation = source.maskSaturation;
            maskClarity = source.maskClarity;
            maskLayers.clear();
            for (EditorMaskLayer layer : source.maskLayers) {
                maskLayers.add(layer.copy());
            }
            activeMaskLayerId = source.activeMaskLayerId;
            nextMaskNumber = source.nextMaskNumber;
            rotation = source.rotation;
            flipHorizontal = source.flipHorizontal;
            flipVertical = source.flipVertical;
            showingOriginal = source.showingOriginal;
            cropRatio = source.cropRatio;
        }

        EditorMaskLayer activeMaskLayer() {
            if (activeMaskLayerId == null) return null;
            for (EditorMaskLayer layer : maskLayers) {
                if (activeMaskLayerId.equals(layer.id)) return layer;
            }
            return null;
        }

        boolean activeMaskLayerVisible() {
            EditorMaskLayer layer = activeMaskLayer();
            return layer != null && layer.visible;
        }

        void createMaskLayer() {
            persistActiveMaskLayer();
            EditorMaskLayer layer = new EditorMaskLayer("蒙版 " + nextMaskNumber++);
            maskLayers.add(layer);
            loadMaskLayer(layer);
        }

        void ensureMaskLayer() {
            if (!maskEnabled || activeMaskLayer() == null) createMaskLayer();
        }

        void selectMaskLayer(String id) {
            if (id == null || id.equals(activeMaskLayerId)) return;
            persistActiveMaskLayer();
            for (EditorMaskLayer layer : maskLayers) {
                if (id.equals(layer.id)) {
                    loadMaskLayer(layer);
                    return;
                }
            }
        }

        void deleteActiveMaskLayer() {
            EditorMaskLayer active = activeMaskLayer();
            if (active == null) return;
            int index = maskLayers.indexOf(active);
            persistActiveMaskLayer();
            maskLayers.remove(index);
            if (maskLayers.isEmpty()) {
                maskEnabled = false;
                activeMaskLayerId = null;
                maskStrokes.clear();
            } else {
                loadMaskLayer(maskLayers.get(Math.min(index, maskLayers.size() - 1)));
            }
        }

        void setMaskLayerVisible(String id, boolean visible) {
            persistActiveMaskLayer();
            for (EditorMaskLayer layer : maskLayers) {
                if (id.equals(layer.id)) {
                    layer.visible = visible;
                    return;
                }
            }
        }

        ArrayList<EditorMaskLayer> effectiveMaskLayers() {
            ArrayList<EditorMaskLayer> result = new ArrayList<>();
            for (EditorMaskLayer layer : maskLayers) {
                result.add(layer.id.equals(activeMaskLayerId)
                        ? snapshotMaskLayer(layer)
                        : layer.copy());
            }
            return result;
        }

        EditorMaskLayer displayedMaskLayer(EditorMaskLayer layer) {
            return layer.id.equals(activeMaskLayerId)
                    ? snapshotMaskLayer(layer)
                    : layer.copy();
        }

        private void persistActiveMaskLayer() {
            EditorMaskLayer active = activeMaskLayer();
            if (active == null) return;
            int index = maskLayers.indexOf(active);
            maskLayers.set(index, snapshotMaskLayer(active));
        }

        private EditorMaskLayer snapshotMaskLayer(EditorMaskLayer identity) {
            EditorMaskLayer layer = new EditorMaskLayer(identity.id, identity.name);
            layer.visible = identity.visible;
            layer.type = maskType;
            layer.amount = maskAmount;
            layer.feather = maskFeather;
            layer.invert = maskInvert;
            layer.subtract = maskSubtract;
            layer.brushSize = maskBrushSize;
            for (EditorMaskStroke stroke : maskStrokes) layer.strokes.add(stroke.copy());
            layer.exposure = maskExposure;
            layer.contrast = maskContrast;
            layer.highlights = maskHighlights;
            layer.shadows = maskShadows;
            layer.temperature = maskTemperature;
            layer.tint = maskTint;
            layer.saturation = maskSaturation;
            layer.clarity = maskClarity;
            return layer;
        }

        private void loadMaskLayer(EditorMaskLayer layer) {
            maskEnabled = true;
            activeMaskLayerId = layer.id;
            maskType = layer.type;
            maskAmount = layer.amount;
            maskFeather = layer.feather;
            maskInvert = layer.invert;
            maskSubtract = layer.subtract;
            maskBrushSize = layer.brushSize;
            maskStrokes.clear();
            for (EditorMaskStroke stroke : layer.strokes) maskStrokes.add(stroke.copy());
            maskExposure = layer.exposure;
            maskContrast = layer.contrast;
            maskHighlights = layer.highlights;
            maskShadows = layer.shadows;
            maskTemperature = layer.temperature;
            maskTint = layer.tint;
            maskSaturation = layer.saturation;
            maskClarity = layer.clarity;
        }
    }

    private final class EditorMaskImageView extends ImageView {
        private final EditorAdjustments adjustments;
        private final Paint overlayPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        private Runnable maskChanged = () -> {};
        private EditorMaskStroke activeStroke;
        private Bitmap maskSourceBitmap;

        EditorMaskImageView(EditorAdjustments adjustments) {
            super(MainActivity.this);
            this.adjustments = adjustments;
            setScaleType(ScaleType.FIT_CENTER);
            setBackgroundColor(GRAPHITE);
            setClickable(true);
        }

        void setMaskChangedListener(Runnable listener) {
            maskChanged = listener == null ? () -> {} : listener;
        }

        void setPreviewBitmap(Bitmap bitmap) {
            super.setImageBitmap(bitmap);
            if (maskSourceBitmap != null) maskSourceBitmap.recycle();
            int maximum = 384;
            float scale = Math.min(
                    1f,
                    maximum / (float) Math.max(bitmap.getWidth(), bitmap.getHeight()));
            int width = Math.max(1, Math.round(bitmap.getWidth() * scale));
            int height = Math.max(1, Math.round(bitmap.getHeight() * scale));
            maskSourceBitmap = width == bitmap.getWidth()
                    && height == bitmap.getHeight()
                    ? bitmap.copy(Bitmap.Config.ARGB_8888, false)
                    : Bitmap.createScaledBitmap(bitmap, width, height, true);
            invalidate();
        }

        void clearPreview() {
            super.setImageDrawable(null);
            if (maskSourceBitmap != null) {
                maskSourceBitmap.recycle();
                maskSourceBitmap = null;
            }
        }

        private RectF displayedImageRect() {
            Drawable drawable = getDrawable();
            if (drawable == null || drawable.getIntrinsicWidth() <= 0
                    || drawable.getIntrinsicHeight() <= 0) {
                return new RectF(0, 0, getWidth(), getHeight());
            }
            float scale = Math.min(
                    getWidth() / (float) drawable.getIntrinsicWidth(),
                    getHeight() / (float) drawable.getIntrinsicHeight());
            float width = drawable.getIntrinsicWidth() * scale;
            float height = drawable.getIntrinsicHeight() * scale;
            return new RectF(
                    (getWidth() - width) / 2f,
                    (getHeight() - height) / 2f,
                    (getWidth() + width) / 2f,
                    (getHeight() + height) / 2f);
        }

        @Override
        public boolean onTouchEvent(MotionEvent event) {
            if (!adjustments.maskEnabled
                    || !adjustments.activeMaskLayerVisible()
                    || getDrawable() == null) {
                return super.onTouchEvent(event);
            }
            RectF rect = displayedImageRect();
            if (!rect.contains(event.getX(), event.getY())
                    && event.getActionMasked() == MotionEvent.ACTION_DOWN) {
                return false;
            }
            getParent().requestDisallowInterceptTouchEvent(true);
            float x = Math.max(0, Math.min(1,
                    (event.getX() - rect.left) / Math.max(1, rect.width())));
            float y = Math.max(0, Math.min(1,
                    (event.getY() - rect.top) / Math.max(1, rect.height())));
            switch (event.getActionMasked()) {
                case MotionEvent.ACTION_DOWN:
                    activeStroke = new EditorMaskStroke(
                            adjustments.maskSubtract,
                            adjustments.maskBrushSize);
                    activeStroke.points.add(new EditorMaskPoint(x, y));
                    adjustments.maskStrokes.add(activeStroke);
                    invalidate();
                    return true;
                case MotionEvent.ACTION_MOVE:
                    if (activeStroke != null) {
                        activeStroke.points.add(new EditorMaskPoint(x, y));
                        invalidate();
                    }
                    return true;
                case MotionEvent.ACTION_UP:
                case MotionEvent.ACTION_CANCEL:
                    if (activeStroke != null) {
                        activeStroke.points.add(new EditorMaskPoint(x, y));
                        activeStroke = null;
                        maskChanged.run();
                        performClick();
                    }
                    getParent().requestDisallowInterceptTouchEvent(false);
                    return true;
                default:
                    return super.onTouchEvent(event);
            }
        }

        @Override
        public boolean performClick() {
            super.performClick();
            return true;
        }

        @Override
        protected void onDraw(Canvas canvas) {
            super.onDraw(canvas);
            EditorMaskLayer active = adjustments.activeMaskLayer();
            if (!adjustments.maskEnabled
                    || active == null
                    || !active.visible
                    || maskSourceBitmap == null) {
                return;
            }
            EditorMaskLayer layer = adjustments.displayedMaskLayer(active);
            int width = maskSourceBitmap.getWidth();
            int height = maskSourceBitmap.getHeight();
            int[] source = new int[width * height];
            maskSourceBitmap.getPixels(source, 0, width, 0, 0, width, height);
            byte[] mask = buildEditorMask(width, height, layer, source);
            int[] overlay = new int[mask.length];
            double intensity = Math.max(0, Math.min(1, layer.amount / 100.0));
            for (int index = 0; index < mask.length; index++) {
                double coverage = (mask[index] & 0xff) / 255.0;
                double effective = (layer.invert ? 1 - coverage : coverage)
                        * intensity;
                overlay[index] = Color.argb(
                        (int) Math.round(150 * effective),
                        22,
                        115,
                        230);
            }
            Bitmap overlayBitmap = Bitmap.createBitmap(
                    overlay, width, height, Bitmap.Config.ARGB_8888);
            RectF rect = displayedImageRect();
            overlayPaint.setStyle(Paint.Style.FILL);
            canvas.drawBitmap(overlayBitmap, null, rect, overlayPaint);
            overlayBitmap.recycle();
        }
    }

    private final class WaveformScopeView extends View {
        static final int RGB_PARADE = 0;
        static final int AUDIO = 1;

        private final int mode;
        private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
        private String red = "—";
        private String green = "—";
        private String blue = "—";

        WaveformScopeView(int mode) {
            super(MainActivity.this);
            this.mode = mode;
            setBackgroundColor(Color.BLACK);
            setContentDescription(mode == AUDIO
                    ? tr("音频波形") + "，" + tr("无音频源")
                    : tr("RGB 波形"));
        }

        void setData(
                String red,
                String green,
                String blue) {
            this.red = red;
            this.green = green;
            this.blue = blue;
            invalidate();
        }

        @Override
        protected void onDraw(Canvas canvas) {
            super.onDraw(canvas);
            RectF bounds = new RectF(1, 1, getWidth() - 1, getHeight() - 1);
            if (mode == AUDIO) {
                drawAudio(canvas, bounds);
                return;
            }
            drawPanel(
                    canvas,
                    bounds,
                    "RGB",
                    new String[]{red, green, blue},
                    new int[]{SCOPE_R, SCOPE_G, SCOPE_B},
                    false);
        }

        private void drawPanel(
                Canvas canvas,
                RectF bounds,
                String label,
                String[] values,
                int[] colors,
                boolean parade) {
            float footerHeight = Math.min(dp(14), Math.max(dp(10), bounds.height() * 0.17f));
            RectF plotBounds = new RectF(
                    bounds.left,
                    bounds.top,
                    bounds.right,
                    Math.max(bounds.top + 1, bounds.bottom - footerHeight));
            paint.setStyle(Paint.Style.FILL);
            paint.setColor(Color.BLACK);
            canvas.drawRect(bounds, paint);
            paint.setColor(SCOPE_BG);
            canvas.drawRect(plotBounds, paint);

            for (int index = 0; index < values.length; index++) {
                int segment = parade ? index : -1;
                drawTrace(canvas, plotBounds, values[index], colors[index], segment, index + 1);
            }

            paint.setStyle(Paint.Style.STROKE);
            paint.setStrokeWidth(dpf(0.72f));
            paint.setColor(WHITE_FAINT);
            for (int guide = 1; guide < 4; guide++) {
                float y = plotBounds.top + plotBounds.height() * guide / 4f;
                canvas.drawLine(plotBounds.left, y, plotBounds.right, y, paint);
            }
            if (parade) {
                for (int guide = 1; guide < 3; guide++) {
                    float x = plotBounds.left + plotBounds.width() * guide / 3f;
                    canvas.drawLine(x, plotBounds.top, x, plotBounds.bottom, paint);
                }
            }
            paint.setStrokeWidth(dpf(1.1f));
            paint.setColor(WHITE_HI);
            canvas.drawRect(plotBounds, paint);

            paint.setStyle(Paint.Style.FILL);
            paint.setTypeface(Typeface.create(Typeface.MONOSPACE, Typeface.NORMAL));
            paint.setTextSize(Math.min(dp(9), footerHeight * 0.68f));
            paint.setTextAlign(Paint.Align.CENTER);
            paint.setColor(WHITE_MID);
            float baseline = bounds.bottom - Math.max(dpf(1.5f), footerHeight * 0.12f);
            if (parade) {
                canvas.drawText("R", bounds.left + bounds.width() / 6f, baseline, paint);
                canvas.drawText("G", bounds.left + bounds.width() / 2f, baseline, paint);
                canvas.drawText("B", bounds.left + bounds.width() * 5f / 6f, baseline, paint);
            } else {
                canvas.drawText(label, bounds.centerX(), baseline, paint);
            }
            paint.setTextAlign(Paint.Align.LEFT);
        }

        private void drawAudio(Canvas canvas, RectF bounds) {
            drawPanel(canvas, bounds, "AUDIO", new String[0], new int[0], false);
            float footerHeight = Math.min(dp(14), Math.max(dp(10), bounds.height() * 0.17f));
            float y = bounds.top + (bounds.height() - footerHeight) / 2f;
            paint.setStyle(Paint.Style.STROKE);
            paint.setStrokeWidth(dp(5));
            paint.setColor(Color.argb(55, (SCOPE_AUDIO >> 16) & 0xFF, (SCOPE_AUDIO >> 8) & 0xFF, SCOPE_AUDIO & 0xFF));
            canvas.drawLine(bounds.left + dp(4), y, bounds.right - dp(4), y, paint);
            paint.setStrokeWidth(dp(1));
            paint.setColor(SCOPE_AUDIO);
            canvas.drawLine(bounds.left + dp(4), y, bounds.right - dp(4), y, paint);
        }

        private void drawTrace(
                Canvas canvas,
                RectF bounds,
                String value,
                int color,
                int segment,
                int seed) {
            float inset = Math.max(dp(2), bounds.width() * 0.009f);
            float startX;
            float width;
            if (segment >= 0) {
                float segmentWidth = bounds.width() / 3f;
                startX = bounds.left + segmentWidth * segment + inset;
                width = Math.max(1, segmentWidth - inset * 2);
            } else {
                startX = bounds.left + inset;
                width = Math.max(1, bounds.width() - inset * 2);
            }
            float topInset = Math.max(dp(3), bounds.height() * 0.035f);
            float bottom = bounds.bottom - Math.max(dp(3), bounds.height() * 0.035f);
            float plotHeight = Math.max(1, bottom - bounds.top - topInset);
            ScopeDensity density = parseDensity(value);
            if (density != null) {
                drawDensity(canvas, density, color, startX, width, bounds.top + topInset, plotHeight);
                return;
            }
            float[] levels = scopeLevels(value);
            if (levels.length < 2) return;
            int columns = Math.min(190, Math.max(48, (int) (width / dpf(1.35f))));
            Path envelope = new Path();
            Path haze = new Path();
            Path cloud = new Path();
            Path sparks = new Path();

            for (int column = 0; column < columns; column++) {
                float progress = column / (float) Math.max(1, columns - 1);
                float sample = progress * (levels.length - 1);
                int lower = Math.min(levels.length - 1, (int) Math.floor(sample));
                int upper = Math.min(levels.length - 1, lower + 1);
                float blend = sample - lower;
                float interpolated = levels[lower] + (levels[upper] - levels[lower]) * blend;
                float ripple = (scopeNoise(column, 0, seed) - 0.5f) * 0.075f;
                float level = Math.min(1, Math.max(0.04f, interpolated + ripple));
                float x = startX + width * progress;
                float envelopeY = bounds.top + topInset
                        + plotHeight * (1 - (0.12f + level * 0.82f));
                if (column == 0) envelope.moveTo(x, envelopeY);
                else envelope.lineTo(x, envelopeY);

                int particles = 18 + Math.round(level * 28);
                for (int particle = 0; particle < particles; particle++) {
                    float distribution = scopeNoise(column, particle + 1, seed * 7);
                    float depth = (float) Math.pow(
                            distribution,
                            particle % 3 == 0 ? 2.25 : 0.72);
                    float jitterX = (scopeNoise(column, particle + 11, seed * 13) - 0.5f) * dpf(2.2f);
                    float jitterY = (scopeNoise(column, particle + 29, seed * 17) - 0.5f) * dpf(2.4f);
                    float y = Math.min(bottom, Math.max(
                            bounds.top + topInset,
                            envelopeY + (bottom - envelopeY) * depth + jitterY));
                    boolean bright = (column + particle + seed) % 5 == 0;
                    float dot = bright ? dpf(1.12f) : dpf(0.72f);
                    haze.addCircle(x + jitterX, y, dot, Path.Direction.CW);
                    if (bright) sparks.addCircle(x + jitterX, y, dot * 0.55f, Path.Direction.CW);
                    else cloud.addCircle(x + jitterX, y, dot * 0.52f, Path.Direction.CW);
                }
            }

            paint.setStyle(Paint.Style.FILL);
            paint.setColor(withAlpha(color, 18));
            canvas.drawPath(haze, paint);
            paint.setColor(withAlpha(color, 76));
            canvas.drawPath(cloud, paint);
            paint.setColor(withAlpha(color, 164));
            canvas.drawPath(sparks, paint);
            paint.setStyle(Paint.Style.STROKE);
            paint.setStrokeJoin(Paint.Join.ROUND);
            paint.setStrokeCap(Paint.Cap.ROUND);
            paint.setStrokeWidth(dpf(3.2f));
            paint.setColor(withAlpha(color, 36));
            canvas.drawPath(envelope, paint);
            paint.setStrokeWidth(dpf(0.72f));
            paint.setColor(withAlpha(color, 160));
            canvas.drawPath(envelope, paint);
        }

        private void drawDensity(
                Canvas canvas,
                ScopeDensity density,
                int color,
                float startX,
                float width,
                float top,
                float height) {
            float cellWidth = width / density.columns;
            float cellHeight = height / density.rows;
            float dot = Math.max(dpf(0.62f), Math.min(dpf(1.5f), cellWidth * 0.72f));
            Path haze = new Path();
            Path cloud = new Path();
            Path sparks = new Path();
            Path envelope = new Path();
            boolean hasEnvelope = false;
            for (int column = 0; column < density.columns; column++) {
                int firstRow = -1;
                for (int row = 0; row < density.rows; row++) {
                    int level = density.values[row * density.columns + column];
                    if (level <= 0) continue;
                    if (firstRow < 0) firstRow = row;
                    float x = startX + (column + 0.5f) * cellWidth;
                    float y = top + (row + 0.5f) * cellHeight;
                    float intensity = level / 15f;
                    haze.addCircle(x, y, dot, Path.Direction.CW);
                    float core = dot * (0.46f + intensity * 0.38f);
                    if (level >= 9) sparks.addCircle(x, y, core, Path.Direction.CW);
                    else if (level >= 3) cloud.addCircle(x, y, core, Path.Direction.CW);
                }
                if (firstRow >= 0) {
                    float x = startX + (column + 0.5f) * cellWidth;
                    float y = top + (firstRow + 0.5f) * cellHeight;
                    if (!hasEnvelope) {
                        envelope.moveTo(x, y);
                        hasEnvelope = true;
                    } else {
                        envelope.lineTo(x, y);
                    }
                }
            }
            paint.setStyle(Paint.Style.FILL);
            paint.setColor(withAlpha(color, 26));
            canvas.drawPath(haze, paint);
            paint.setColor(withAlpha(color, 90));
            canvas.drawPath(cloud, paint);
            paint.setColor(withAlpha(color, 200));
            canvas.drawPath(sparks, paint);
            paint.setStyle(Paint.Style.STROKE);
            paint.setStrokeJoin(Paint.Join.ROUND);
            paint.setStrokeCap(Paint.Cap.ROUND);
            paint.setStrokeWidth(dpf(2.8f));
            paint.setColor(withAlpha(color, 56));
            canvas.drawPath(envelope, paint);
            paint.setStrokeWidth(dpf(0.68f));
            paint.setColor(withAlpha(color, 184));
            canvas.drawPath(envelope, paint);
        }

        private ScopeDensity parseDensity(String value) {
            int colon = value.indexOf(':');
            if (!value.startsWith("S") || colon < 2) return null;
            String[] dimensions = value.substring(1, colon).split("x", 2);
            if (dimensions.length != 2) return null;
            try {
                int columns = Integer.parseInt(dimensions[0]);
                int rows = Integer.parseInt(dimensions[1]);
                String payload = value.substring(colon + 1);
                if (payload.length() != columns * rows) return null;
                int[] values = new int[payload.length()];
                for (int index = 0; index < payload.length(); index++) {
                    int level = Character.digit(payload.charAt(index), 16);
                    if (level < 0) return null;
                    values[index] = level;
                }
                return new ScopeDensity(columns, rows, values);
            } catch (NumberFormatException error) {
                return null;
            }
        }

        private final class ScopeDensity {
            final int columns;
            final int rows;
            final int[] values;

            ScopeDensity(int columns, int rows, int[] values) {
                this.columns = columns;
                this.rows = rows;
                this.values = values;
            }
        }

        private float scopeNoise(int column, int particle, int seed) {
            double value = Math.sin(
                    ((column + 1) * 17 + (particle + 3) * 31 + seed * 47) * 12.9898)
                    * 43758.5453;
            return (float) (value - Math.floor(value));
        }

        private float[] scopeLevels(String value) {
            String bars = "▁▂▃▄▅▆▇█";
            ArrayList<Float> output = new ArrayList<>();
            for (int index = 0; index < value.length(); index++) {
                int level = bars.indexOf(value.charAt(index));
                if (level >= 0) output.add(level / 7f);
            }
            if (output.size() < 2) return new float[]{0.08f, 0.08f};
            float[] levels = new float[output.size()];
            for (int index = 0; index < output.size(); index++) {
                levels[index] = output.get(index);
            }
            return levels;
        }

        private int withAlpha(int color, int alpha) {
            return Color.argb(alpha, Color.red(color), Color.green(color), Color.blue(color));
        }

        private float dpf(float value) {
            return value * getResources().getDisplayMetrics().density;
        }
    }

    private static final class EditorAIAnalysis {
        double meanLuma;
        double contrast;
        double shadowRatio;
        double highlightRatio;
        double saturation;
        double red;
        double green;
        double blue;
        double detail;

        String summary() {
            if (meanLuma < 0.38) {
                return "检测到画面偏暗，已提亮阴影并保护高光";
            }
            if (meanLuma > 0.64 || highlightRatio > 0.08) {
                return "检测到画面偏亮，已回收高光并恢复层次";
            }
            if (contrast < 0.16) {
                return "检测到动态范围偏平，已增强层次与色彩";
            }
            return "曝光均衡，已优化色彩与细节";
        }
    }

    private final ExecutorService cameraExecutor = Executors.newSingleThreadExecutor();
    private final ExecutorService previewExecutor = Executors.newSingleThreadExecutor();
    private final ExecutorService updateExecutor = Executors.newSingleThreadExecutor();
    private final ExecutorService editorExecutor = Executors.newSingleThreadExecutor();
    private final ExecutorService storageExecutor = Executors.newSingleThreadExecutor();
    private final ExecutorService composeExecutor = Executors.newSingleThreadExecutor();
    private final ExecutorService activationExecutor = Executors.newSingleThreadExecutor();
    // ── W13-d 邮箱账号系统登录墙（3A：启动即登录墙）──
    private AuthManager authManager;
    private FrameLayout authWallHost;
    private boolean authChecking;
    private boolean loginWallVisible;
    private boolean authSensitiveStateClosed;
    private String authMode = "login";           // "login" | "register"
    private boolean authCodeRequired = true;     // 严态=true；email-code 503（SMTP 未配）后=false 走免码注册
    private int authCountdown;
    private Runnable authCountdownTask;
    private EditText authEmailInput;
    private EditText authPasswordInput;
    private EditText authCodeInput;
    private LinearLayout authCodeRow;
    private Button authCodeButton;
    private TextView authErrorText;
    private Button authSubmitButton;
    private String authPersistentError = "";
    private AlertDialog connectionDialog;
    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private final AtomicReference<PreviewPacket> pendingPreview = new AtomicReference<>();
    private final AtomicBoolean previewWorkerRunning = new AtomicBoolean();
    private final List<View> cameraControls = new ArrayList<>();
    private final List<Button> navigationButtons = new ArrayList<>();
    private final Map<String, View> parameterControls = new HashMap<>();
    private final Map<String, TextView> parameterLabels = new HashMap<>();
    private final Map<String, Boolean> disclosureStates = new HashMap<>();
    private volatile String pendingEditorScrollKey;
    private final List<LibraryBranch> userLibraryBranches = new ArrayList<>();
    private final Map<String, String> libraryFileAssignments = new HashMap<>();
    private final List<RememberedDevice> rememberedDevices = new ArrayList<>();
    private final Set<Long> selectedCameraStorageHandles = new LinkedHashSet<>();
    private volatile CameraStorage.Snapshot cameraStorageSnapshot =
            new CameraStorage.Snapshot(Collections.emptyList(), Collections.emptyList());
    private volatile String cameraStorageStatus = "连接相机后可浏览存储卡";
    private volatile boolean cameraStorageLoading;

    private PtpCamera camera;
    private PtpIpCamera wifiCamera;
    private LocalCameraController localCamera;
    private final ExternalVideoRecorder externalVideoRecorder =
            new ExternalVideoRecorder();
    private final LivePhotoClipRecorder livePhotoClipRecorder =
            new LivePhotoClipRecorder();
    private BluetoothRemoteController bluetoothRemote;
    private LocationTaggingController locationTagging;
    private DiagnosticLogger diagnostics;
    private FrameLayout contentHost;
    private LinearLayout applicationRoot;
    private View applicationTopBar;
    private View applicationBottomNavigation;
    private View applicationStatusBar;
    // ── v1.5.5 fig1 control-page chrome state ──
    private boolean controlTopBarActive;
    private TextView controlStatusDot;
    private TextView controlStatusText;
    private TextView controlStatusRate;
    private TextView controlStatusError;
    private boolean gridEditMode;
    private boolean[] gridHiddenTiles;
    private LinearLayout controlParameterTilesHost;
    private String lastConnectionError;
    private TextView statusText;
    private TextView countText;
    private Button connectButton;
    private ImageView previewImage;
    private TextView monitorFocusReticle;
    private ImageView zebraImage;
    private TextView previewPlaceholder;
    private Button shutterButton;
    private Button liveViewButton;
    private Button wirelessButton;
    private TextView wirelessStatusText;
    private TextView wirelessAddressText;
    private TextView lutStatusText;
    private TextView updateStatusText;
    private WaveformScopeView monitorRgbScopeView;
    private WaveformScopeView professionalScopeView;
    private WaveformScopeView immersiveScopeView;
    private WaveformScopeView captureScopeView;
    private TextView peakingCoverageText;
    private Button checkUpdateButton;
    private Button openUpdateButton;
    private Switch lutSwitch;
    private Switch liveMonitoringSwitch;
    private TextView liveMonitoringDetail;
    private boolean syncingLiveMonitoringSwitch;
    private SeekBar zebraThresholdControl;
    private Bitmap latestFrame;
    private Bitmap latestSourceFrame;
    private Bitmap latestZebraMask;
    private ImageView immersivePreviewImage;
    private ImageView immersiveZebraImage;
    private Dialog immersiveDialog;
    private AlertDialog nikonCloudPresetDialog;
    private FrameLayout immersiveChrome;
    private Button immersiveRecordButton;
    private TextView immersiveExposureText;
    private TextView connectionDot;
    private TextView monitorTimerText;
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
    private volatile boolean localCameraConnected;
    private volatile boolean localCameraConnecting;
    private volatile boolean wifiConnected;
    private volatile boolean wifiConnecting;
    private volatile String wifiConnectionMode = "ap";
    private volatile boolean bluetoothRemoteEnabled;
    private volatile boolean locationTaggingEnabled;
    private volatile String wifiCameraName = "PTP/IP Camera";
    // ── B2 WiFi 连接监看：保活/自动重连/网络监听 ──
    private static final long WIFI_HEARTBEAT_INTERVAL_MS = 5000;
    private static final int WIFI_OFFLINE_THRESHOLD = 3;
    private static final long[] WIFI_RECONNECT_BACKOFF_MS =
            {1000, 2000, 4000, 8000, 16000, 30000};
    private volatile boolean wifiReconnecting;
    private volatile boolean wifiManualDisconnect;
    private volatile int wifiMissedHeartbeats;
    private volatile int wifiReconnectAttempt;
    private volatile String wifiCameraHost = "192.168.1.1";
    private volatile int wifiCameraPort = 15740;
    // ── E4 1.5.9：Wi‑Fi PTP/IP 取景 / 录像 / 参数控制 ──
    private volatile PtpIpCamera.CameraVendor wifiVendor =
            PtpIpCamera.CameraVendor.UNKNOWN;
    private volatile boolean wifiLiveView;
    private volatile boolean wifiMovieRecording;
    private volatile int wifiIso;
    private volatile double wifiAperture;
    private volatile double wifiShutterSeconds;
    private volatile int wifiPreviewGeneration;
    private volatile String wifiParameterReadout = "参数待读取 · 连接后自动刷新";
    private TextView wifiParameterReadoutView;
    private Button wifiLiveViewButton;
    private Button wifiRecordButton;
    private ConnectivityManager.NetworkCallback wifiNetworkCallback;
    private final Runnable wifiHeartbeatRunnable = new Runnable() {
        @Override public void run() {
            if (!wifiConnected || wifiReconnecting || wifiManualDisconnect) return;
            cameraExecutor.submit(() -> {
                boolean ok = false;
                try {
                    wifiCamera.probe();
                    ok = true;
                } catch (Exception ignored) {
                    // 心跳失败：计入连续失败计数。
                }
                final boolean alive = ok;
                mainHandler.post(() -> {
                    if (!wifiConnected || wifiManualDisconnect) return;
                    if (alive) {
                        wifiMissedHeartbeats = 0;
                    } else {
                        wifiMissedHeartbeats++;
                        if (wifiMissedHeartbeats >= WIFI_OFFLINE_THRESHOLD) {
                            wifiMissedHeartbeats = 0;
                            enterWifiReconnecting();
                            return;
                        }
                    }
                    mainHandler.postDelayed(
                            wifiHeartbeatRunnable,
                            WIFI_HEARTBEAT_INTERVAL_MS);
                });
            });
        }
    };
    private volatile String bluetoothRemoteStatus = "蓝牙遥控未开启";
    private volatile String locationTaggingStatus = "定位未开启";
    private volatile boolean liveViewEnabled;
    private volatile boolean capturing;
    private volatile boolean videoRecording;
    private volatile boolean externalRecordToDevice = true;
    // ── E5 1.5.9：live 图（取景帧环形缓冲 + 快门切片配对，默认关 3s）──
    private volatile boolean livePhotoEnabled;
    private volatile double livePhotoSeconds = 3.0;
    private volatile long recordingStartedAt;
    private final Runnable monitorTimerTicker = new Runnable() {
        @Override public void run() {
            if (monitorTimerText == null || !"monitor".equals(currentSection)) return;
            long elapsed = videoRecording && recordingStartedAt > 0
                    ? Math.max(0, System.currentTimeMillis() - recordingStartedAt)
                    : 0;
            long centis = (elapsed / 10) % 100;
            long seconds = (elapsed / 1000) % 60;
            long minutes = (elapsed / 60000) % 60;
            long hours = elapsed / 3600000;
            monitorTimerText.setText(String.format(
                    Locale.CHINA, "%02d:%02d:%02d:%02d",
                    hours, minutes, seconds, centis));
            mainHandler.postDelayed(this, 100);
        }
    };
    private volatile boolean wirelessRequested;
    private volatile String wirelessStatus = "无线收件箱未开启";
    private volatile int previewGeneration;
    private volatile int previewFailureCount;
    private volatile int previewAnalysisSequence;
    private volatile String connectedCameraName = "Nikon 相机";
    private volatile String connectedCameraVendor = "Nikon";
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
    private volatile boolean monitorShutterAngleMode = true;
    private volatile String videoCodec = "h265";
    private volatile boolean nLogEnabled;
    private volatile String videoLogProfile = "off";
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
    private volatile String editorSystemPhotoStatus = "";
    private final EditorAdjustments editorAdjustments =
            new EditorAdjustments();
    private List<NikonCloudPreview.Preset> nikonCloudPresets =
            Collections.emptyList();
    private NikonCloudPreview.Preset selectedNikonCloudPreset;
    private NikonCloudPreview.Preset monitorNikonCloudPreset;
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
    private static boolean aiUsageLoaded;
    private static final int AI_MAX_USAGE = 100;

    private boolean isAiActivated() {
        if (!aiUsageLoaded) {
            android.content.SharedPreferences preferences =
                    getSharedPreferences("nikon-link", MODE_PRIVATE);
            aiActivated = preferences.getBoolean("ai_activated", false);
            aiUsageCount = Math.max(
                    0,
                    preferences.getInt("ai_usage_count", 0));
            aiUsageLoaded = true;
        }
        return aiActivated && aiUsageCount < AI_MAX_USAGE;
    }

    private int getRemainingUsage() {
        return Math.max(0, AI_MAX_USAGE - aiUsageCount);
    }

    private void recordAiUsage() {
        aiUsageCount = Math.min(AI_MAX_USAGE, aiUsageCount + 1);
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
                .edit().putString("ai_device_id", id).commit();
        return id;
    }

    /** E1: 匿名安装 ID——首次生成 UUID 存 SharedPreferences，与激活码/设备码无关，
     *  仅用于服务器匿名用量统计（服务端只存 sha256 前 12 位指纹）。 */
    private String anonymousInstallId() {
        String existing = getSharedPreferences("nikon-link", MODE_PRIVATE)
                .getString(INSTALL_ID_KEY, "");
        if (existing != null && !existing.isEmpty()) return existing;
        String id = java.util.UUID.randomUUID().toString();
        getSharedPreferences("nikon-link", MODE_PRIVATE)
                .edit().putString(INSTALL_ID_KEY, id).commit();
        return id;
    }

    private String loadActivationCode() {
        return getSharedPreferences("nikon-link", MODE_PRIVATE)
                .getString("ai_activated_code", "");
    }

    private String aiServerUrl() {
        String configured = getSharedPreferences("nikon-link", MODE_PRIVATE)
                .getString("aiServerURL", AI_SERVER_DEFAULT);
        String normalized = configured == null ? "" : configured.trim();
        while (normalized.endsWith("/")) {
            normalized = normalized.substring(0, normalized.length() - 1);
        }
        // The original public IP endpoint is retired and cannot carry the
        // account Bearer token. Migrate only that exact historical default;
        // keep any explicit self-hosted override intact for compatibility.
        if (normalized.isEmpty() || AI_SERVER_LEGACY.equals(normalized)) {
            return AI_SERVER_DEFAULT;
        }
        return normalized;
    }

    private static final String AI_PUBLIC_KEY =
            "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAngqgOi5fjajCPusMNsfB" +
            "FdMmWyzAGArL5bA+JK/uW+Md/YDtGvXjgSodev7VOQ9SPWqHUYA+XTpdyeCA+weL" +
            "32JhFf+8+a28DjIp7RMv962m1qXJLtcdFbiBjWGDWF+itDJGUgR5OQbxV8xDd/kj" +
            "c1ZT5ft7r2KwECUvwjKr9SAOWGJPK9oNmo9u2kW/6PbjpSEIhDH88FYloNWxpmdW" +
            "XoQ2YYAfd5sKc0CNcBFdu2oEFGFHeUufbhgkZWtDPCS299W4TuWyTDfWPx4+Raap" +
            "bcVF9RfFPa1uI7MpyrOqrGgSnuSC7HxY/B+NXm5rt4p3ZRaOzyKBiZEQ8Sg0XpKI" +
            "3wIDAQAB";
    private static final String AI_REBIND_URL =
            "https://zenche.top/api/v1/ai/rebind";
    private static final int AI_REBIND_RESPONSE_LIMIT = 64 * 1024;

    private boolean verifyActivationCode(String code) {
        String trimmed = code == null ? "" : code.trim();
        if (!verifyActivationCodeForDevice(trimmed, aiDeviceId())) return false;
        return saveVerifiedActivation(trimmed, AI_MAX_USAGE);
    }

    private boolean verifyActivationCodeForDevice(String code, String deviceId) {
        if (code == null) return false;
        String trimmed = code.trim();
        String targetDeviceId = deviceId == null ? "" : deviceId.trim();
        if (trimmed.isEmpty() || targetDeviceId.isEmpty()) return false;
        try {
            String[] parts = trimmed.split("-");
            if (parts.length < 4 || !"ZENCHE".equals(parts[0])
                    || !"AI".equals(parts[1])) {
                return false;
            }
            String expiryPart = parts[parts.length - 1];
            java.text.SimpleDateFormat sdf =
                    new java.text.SimpleDateFormat("yyyyMMdd", java.util.Locale.US);
            sdf.setLenient(false);
            java.util.Date expiry = sdf.parse(expiryPart);
            if (expiry == null || !expiryPart.equals(sdf.format(expiry))
                    || expiryPart.compareTo(sdf.format(new java.util.Date())) < 0) {
                return false;
            }
            StringBuilder sigBuilder = new StringBuilder();
            for (int i = 2; i < parts.length - 1; i++) {
                if (sigBuilder.length() > 0) sigBuilder.append("-");
                sigBuilder.append(parts[i]);
            }
            byte[] sigBytes = android.util.Base64.decode(
                    sigBuilder.toString(), android.util.Base64.DEFAULT);
            String payload = targetDeviceId + ":" + expiryPart + ":a1b2c3d4e5f6";
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
            return signature.verify(sigBytes);
        } catch (Exception ignored) {
            return false;
        }
    }

    private boolean saveVerifiedActivation(String code, int remaining) {
        int bounded = Math.max(0, Math.min(AI_MAX_USAGE, remaining));
        boolean saved = getSharedPreferences("nikon-link", MODE_PRIVATE)
                .edit()
                .putString("ai_activated_code", code.trim())
                .putString("ai_device_id", aiDeviceId())
                .putInt("ai_usage_count", AI_MAX_USAGE - bounded)
                .putBoolean("ai_activated", bounded > 0)
                .commit();
        if (saved) {
            aiActivated = bounded > 0;
            aiUsageCount = AI_MAX_USAGE - bounded;
            aiUsageLoaded = true;
        }
        return saved;
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
    private static final String[][] AI_EDIT_MODULES = {
            {"主体", "人像主体", "产品主体", "建筑主体", "风光主体", "食物主体"},
            {"光线", "柔和自然光", "电影感侧光", "金色时刻", "低调棚拍光", "夜景霓虹光"},
            {"色彩", "自然通透", "胶片暖调", "日系清新", "高反差黑白", "冷色城市"},
            {"质感", "保留真实皮肤纹理", "细节清晰", "轻微胶片颗粒", "柔和高光", "高动态范围"},
            {"构图", "浅景深", "干净背景", "对称构图", "环境叙事", "视觉焦点明确"},
            {"智能移除", "去路人并自然补全背景", "去穿帮并移除摄影器材、工作人员、反光与杂物"},
            {"约束", "保持人物身份和五官", "不改变产品形状", "不添加多余物体", "不过度磨皮", "保留自然阴影"}
    };
    private static final String[][] AI_GENERATE_MODULES = {
            {"主体", "人像主体", "产品主体", "建筑主体", "风光主体", "食物主体"},
            {"光线", "柔和自然光", "电影感侧光", "金色时刻", "低调棚拍光", "夜景霓虹光"},
            {"色彩", "自然通透", "胶片暖调", "日系清新", "高反差黑白", "冷色城市"},
            {"质感", "细节清晰", "轻微胶片颗粒", "柔和高光", "高动态范围"},
            {"构图", "浅景深", "干净背景", "对称构图", "环境叙事", "视觉焦点明确"}
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

    private static final class AiImageResponse {
        final byte[] image;
        final Integer remaining;

        AiImageResponse(byte[] image, Integer remaining) {
            this.image = image;
            this.remaining = remaining;
        }
    }

    private static final class AiRebindResponse {
        final String newCode;
        final int remaining;

        AiRebindResponse(String newCode, int remaining) {
            this.newCode = newCode;
            this.remaining = remaining;
        }
    }

    private EditorAdjustments editorSettingsBeforeAI;
    private EditorAdjustments editorAICopiedSettings;
    // E8 1.5.9: AI 批量应用（本地渲染，0 服务器消耗）——队列状态。
    private volatile boolean aiBatchApplying;
    private volatile boolean aiBatchCancelled;
    private volatile int aiBatchProgress;
    private volatile int aiBatchTotal;
    private volatile int aiBatchSkipped;
    private EditorAIAnalysis editorAIAnalysis;
    private int editorAIIntensity = 72;
    private String editorAISummary = "等待分析当前照片";
    private final LinkedHashSet<String> aiSelectedPresetKeys = new LinkedHashSet<>();
    private String aiManualPrompt = "";
    private boolean suppressAiPromptChange;
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
        applyAppearanceTokens(isNightMode());
        diagnostics = new DiagnosticLogger(this);
        diagnostics.startSession();
        appLanguage = Localization.normalize(
                getSharedPreferences("nikon-link", MODE_PRIVATE)
                        .getString(
                                Localization.PREFERENCE_KEY,
                                Localization.SIMPLIFIED_CHINESE));
        nikonCloudPresets = NikonCloudPreview.load(this);
        loadLibraryBranches();
        loadRememberedDevices();
        Window window = getWindow();
        window.setStatusBarColor(PAPER);
        window.setNavigationBarColor(GRAPHITE);
        window.getDecorView().setSystemUiVisibility(
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                        | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                        | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                        | (nightMode ? 0 : View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR));

        camera = new PtpCamera(this, diagnostics);
        wifiCamera = new PtpIpCamera();
        localCamera = new LocalCameraController(this);
        bluetoothRemote = new BluetoothRemoteController(
                this,
                new BluetoothRemoteController.Listener() {
                    @Override
                    public void onStatus(String status, boolean isConnected) {
                        bluetoothRemoteStatus = status;
                        diagnostics.info("bluetooth-remote", status);
                    }

                    @Override
                    public void onShutter() {
                        mainHandler.post(() -> capturePhoto());
                    }
                });
        locationTagging = new LocationTaggingController(
                this,
                status -> {
                    locationTaggingStatus = status;
                    diagnostics.info("location", status);
                });
        bluetoothRemoteEnabled = getSharedPreferences("nikon-link", MODE_PRIVATE)
                .getBoolean("bluetoothRemoteEnabled", false);
        locationTaggingEnabled = getSharedPreferences("nikon-link", MODE_PRIVATE)
                .getBoolean("captureLocationEnabled", false);
        externalRecordToDevice = getSharedPreferences("nikon-link", MODE_PRIVATE)
                .getBoolean("externalRecordToDevice", true);
        livePhotoEnabled = getSharedPreferences("nikon-link", MODE_PRIVATE)
                .getBoolean("livePhotoEnabled", false);
        livePhotoSeconds = getSharedPreferences("nikon-link", MODE_PRIVATE)
                .getFloat("livePhotoSeconds", 3.0f);
        monitorVideoProfile = getSharedPreferences("nikon-link", MODE_PRIVATE)
                .getString("monitorVideoProfile", "source");
        monitorFrameRate = getSharedPreferences("nikon-link", MODE_PRIVATE)
                .getInt("monitorFrameRate", 30);
        videoCodec = getSharedPreferences("nikon-link", MODE_PRIVATE)
                .getString("videoCodec", "h265");
        nLogEnabled = getSharedPreferences("nikon-link", MODE_PRIVATE)
                .getBoolean("nLogEnabled", false);
        videoLogProfile = getSharedPreferences("nikon-link", MODE_PRIVATE)
                .getString("videoLogProfile", nLogEnabled ? "nlog" : "off");
        nLogEnabled = !"off".equals(videoLogProfile);
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
        authManager = new AuthManager(this);
        // W13-d 3A 启动路由守卫：无 token → 登录墙（不登录任何功能不可用）；
        // 有 token → 后台 /v1/auth/me 校验（401/403 清 token 回登录墙，网络失败离线容忍）。
        if (authManager.hasSession()) {
            authChecking = true;
            showSection("capture");
            showAuthCheckingWall();
            validateSessionAsync();
        } else {
            showSection("capture");
            showLoginWall();
        }
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
        boolean nowNight = (configuration.uiMode & Configuration.UI_MODE_NIGHT_MASK)
                == Configuration.UI_MODE_NIGHT_YES;
        if (nowNight != nightMode) {
            applyAppearanceTokens(nowNight);
            Window window = getWindow();
            window.setStatusBarColor(PAPER);
            window.setNavigationBarColor(GRAPHITE);
            window.getDecorView().setSystemUiVisibility(
                    View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                            | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                            | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                            | (nowNight ? 0 : View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR));
            String destination = currentSection;
            navigationButtons.clear();
            setContentView(buildApplication());
            showSection(destination);
            if (authChecking) {
                showAuthCheckingWall();
            } else if (loginWallVisible) {
                showLoginWall();
            }
            updateConnectionUi();
            updateWirelessUi();
            refreshUpdateUi();
            if (latestSourceFrame != null) {
                refreshPreviewProcessing();
            }
        }
        if (immersiveDialog == null || !immersiveDialog.isShowing()) return;
        immersiveLandscape =
                configuration.orientation == Configuration.ORIENTATION_LANDSCAPE;
        buildImmersiveChrome(immersiveDialog);
    }

    @Override
    public boolean onKeyUp(int keyCode, KeyEvent event) {
        if (bluetoothRemoteEnabled
                && !event.isCanceled()
                && (keyCode == KeyEvent.KEYCODE_CAMERA
                        || keyCode == KeyEvent.KEYCODE_VOLUME_UP
                        || keyCode == KeyEvent.KEYCODE_VOLUME_DOWN)) {
            diagnostics.info("bluetooth-remote", "收到硬件遥控快门键");
            capturePhoto();
            return true;
        }
        return super.onKeyUp(keyCode, event);
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
        if (requestCode == REQUEST_EDITOR_SYSTEM_PHOTO
                && (resultCode != RESULT_OK || data == null)) {
            editorSystemPhotoStatus = "";
            return;
        }
        if (resultCode != RESULT_OK || data == null) {
            return;
        }
        if (requestCode == REQUEST_EDITOR_SYSTEM_PHOTO) {
            Uri uri = data.getData();
            if (uri != null) {
                importSystemPhotoForEditing(uri);
            }
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
        if (requestCode == REQUEST_BLUETOOTH_REMOTE) {
            if (bluetoothRemoteEnabled) bluetoothRemote.start();
            return;
        }
        if (requestCode == REQUEST_CAPTURE_LOCATION) {
            if (locationTaggingEnabled) locationTagging.start();
            return;
        }
        if (requestCode == REQUEST_LOCAL_CAMERA) {
            if (grantResults.length > 0
                    && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                connectLocalCamera();
            } else {
                boolean permanentlyDenied =
                        !shouldShowRequestPermissionRationale(
                                Manifest.permission.CAMERA);
                if (permanentlyDenied) {
                    showCameraPermissionSettingsGuide();
                } else {
                    showError("未获得相机权限，无法使用本机摄像头");
                }
            }
            return;
        }
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

    /**
     * Opens the permission-safe system picker for a single editor source.
     * The selected item is copied into ZENCHE before any edit is applied.
     */
    void openSystemPhotoForEditing() {
        try {
            startActivityForResult(
                    SystemPhotoEditBridge.pickerIntent(),
                    REQUEST_EDITOR_SYSTEM_PHOTO);
            editorSystemPhotoStatus = "正在选择系统相册照片…";
        } catch (RuntimeException error) {
            editorSystemPhotoStatus = "无法打开系统相册：" + error.getMessage();
            showError(editorSystemPhotoStatus);
        }
    }

    private void importSystemPhotoForEditing(Uri uri) {
        editorSystemPhotoStatus = "正在创建可编辑副本…";
        editorExecutor.execute(() -> {
            try {
                File copy = SystemPhotoEditBridge.importEditableCopy(
                        this,
                        captureWorkflow,
                        uri);
                mainHandler.post(() -> {
                    editorSelectedPath = copy.getAbsolutePath();
                    editorState = EditorState.PRO;
                    aiMode = 0;
                    aiResultBitmap = null;
                    editorAdjustments.reset();
                    editorAIAnalysis = null;
                    editorSystemPhotoStatus = "系统照片已导入为可编辑副本";
                    updateFileCount();
                    showSection("editor");
                });
            } catch (Exception error) {
                diagnostics.error(
                        "editor",
                        "系统照片导入失败：" + error.getMessage());
                mainHandler.post(() -> {
                    editorSystemPhotoStatus = "系统照片导入失败："
                            + error.getMessage();
                    showError(editorSystemPhotoStatus);
                });
            }
        });
    }

    /** Saves an existing ZENCHE edit as a new system-album item. */
    void saveEditedCopyToSystemAlbum(File editedFile) {
        editorSystemPhotoStatus = "正在保存新副本到系统相册…";
        editorExecutor.execute(() -> {
            try {
                SystemPhotoEditBridge.saveNewCopy(this, editedFile);
                mainHandler.post(() -> {
                    editorSystemPhotoStatus = "已保存新副本到系统相册";
                    showToast(editorSystemPhotoStatus);
                });
                diagnostics.info(
                        "editor",
                        "编辑副本已保存到系统相册");
            } catch (Exception error) {
                diagnostics.error(
                        "editor",
                        "系统相册保存失败：" + error.getMessage());
                mainHandler.post(() -> {
                    editorSystemPhotoStatus = "系统相册保存失败："
                            + error.getMessage();
                    showError(editorSystemPhotoStatus);
                });
            }
        });
    }

    /** Permission-recovery action exposed for the editor surface. */
    void openSystemPhotoPermissionSettings() {
        startActivity(SystemPhotoEditBridge.permissionSettingsIntent(this));
    }

    String editorSystemPhotoStatus() {
        return editorSystemPhotoStatus;
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
        content.addView(text("链接网盘", TS_DISPLAY, Typeface.BOLD, INK));
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
            mainHandler.post(() -> {
                showSection("library");
                updateFileCount();
                if (finalImported > 0) {
                    showToast(
                            "已从" + (ownerAlbum ? "机主相册" : "网盘")
                                    + "加入 " + finalImported + " 张照片");
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

        Button edit = nativeButton("编辑", true);
        edit.setOnClickListener(view -> {
            dialog.dismiss();
            editorSelectedPath = file.getAbsolutePath();
            editorState = EditorState.PRO;
            aiResultBitmap = null;
            showSection("editor");
        });
        FrameLayout.LayoutParams editParams =
                new FrameLayout.LayoutParams(dp(88), dp(48), Gravity.TOP | Gravity.CENTER_HORIZONTAL);
        editParams.setMargins(0, dp(28), 0, 0);
        root.addView(edit, editParams);

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
                || lower.endsWith(".m4v")
                || lower.endsWith(".avi");
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
        boolean compact = isCompactPhone();
        // W13-d：外层 FrameLayout 承载登录墙 overlay（线性布局子视图顺序排列，
        // 无法叠加覆盖层；FrameLayout 顶层 authWallHost 可整屏盖住主界面）。
        FrameLayout applicationFrame = new FrameLayout(this);
        LinearLayout root = new LinearLayout(this);
        applicationRoot = root;
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(PAPER);

        View topBar = buildTopBar();
        applicationTopBar = topBar;
        root.addView(topBar, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(compact ? 64 : 72)));

        contentHost = new FrameLayout(this);
        root.addView(contentHost, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                0,
                1f));

        View bottomNavigation = buildBottomNavigation();
        applicationBottomNavigation = bottomNavigation;
        root.addView(bottomNavigation, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(compact ? 64 : 70)));
        View statusBar = buildStatusBar();
        applicationStatusBar = statusBar;
        root.addView(statusBar, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(30)));
        applySystemBarInsets(root, topBar, bottomNavigation, statusBar);
        applicationFrame.addView(root, new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT));
        authWallHost = new FrameLayout(this);
        authWallHost.setBackgroundColor(PAPER);
        authWallHost.setVisibility(View.GONE);
        applicationFrame.addView(authWallHost, new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT));
        return applicationFrame;
    }

    private void applySystemBarInsets(
            LinearLayout root,
            View topBar,
            View bottomNavigation,
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
        int topBarHeight = dp(isCompactPhone() ? 64 : 72);
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
            if (statusParams != null) {
                statusParams.height = statusBarHeight + bottom;
                statusBar.setLayoutParams(statusParams);
            }
            return windowInsets;
        });
        root.requestApplyInsets();
    }

    private View buildTopBar() {
        boolean compact = isCompactPhone();
        LinearLayout top = new LinearLayout(this);
        top.setOrientation(LinearLayout.HORIZONTAL);
        top.setGravity(Gravity.CENTER_VERTICAL);
        top.setPadding(
                dp(compact ? 10 : 12),
                dp(8),
                dp(compact ? 10 : 12),
                dp(8));
        top.setBackgroundColor(SURFACE);
        top.setElevation(dp(6));
        fillStandardTopBar(top, compact);
        return top;
    }

    /** v1.5.5 fig1 standard app bar content (light, logo + connect + settings). */
    private void fillStandardTopBar(LinearLayout top, boolean compact) {
        top.removeAllViews();
        // v1.5.9 实测修复：fig1 批次引入品牌块后，非拍照页顶栏冒出多余 logo。
        // 摘除「Z」标 + 品牌文案两视图（顶栏保留连接胶囊 + 设置钮）。

        // v1.5.7 P1：状态点 22dp → 10dp（视觉对齐 macOS 8pt 基准；触控面由 44 高顶栏行保证）
        connectionDot = text("●", 10, Typeface.BOLD, MUTED);
        connectionDot.setGravity(Gravity.CENTER);
        top.addView(connectionDot, new LinearLayout.LayoutParams(dp(10), dp(44)));

        connectButton = nativeButton(compact ? "连接" : "连接相机", true);
        connectButton.setOnClickListener(view -> {
            if (connected || wifiConnected || localCameraConnected) {
                if (connected) disconnectCamera();
                if (wifiConnected) disconnectWifiCamera();
                if (localCameraConnected) disconnectLocalCamera();
            } else {
                showConnectionDialog();
            }
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
    }

    /**
     * v1.5.5 fig1 control-page top bar: menu, centered title "控制", two round
     * icon buttons. Flat, dark, no gradient, no shadow.
     */
    private void fillControlTopBar(LinearLayout top) {
        boolean compact = isCompactPhone();
        top.removeAllViews();
        top.setPadding(
                dp(compact ? 10 : 12),
                dp(8),
                dp(compact ? 10 : 12),
                dp(8));

        Button menu = new Button(this);
        menu.setText("☰");
        menu.setTextSize(20);
        menu.setTextColor(Color.WHITE);
        menu.setGravity(Gravity.CENTER);
        menu.setAllCaps(false);
        menu.setPadding(0, 0, 0, 0);
        menu.setBackground(rounded(UI_SECONDARY, 14, 0));
        menu.setStateListAnimator(null);
        menu.setContentDescription(tr("菜单"));
        menu.setOnClickListener(view -> showControlMenuDialog());
        top.addView(menu, new LinearLayout.LayoutParams(dp(44), dp(44)));

        TextView title = text("控制", compact ? 17 : 19, Typeface.BOLD, Color.WHITE);
        title.setGravity(Gravity.CENTER);
        top.addView(title, new LinearLayout.LayoutParams(0, dp(44), 1f));

        Button viewfinder = new Button(this);
        viewfinder.setText("◉");
        viewfinder.setTextSize(TS_TITLE);
        viewfinder.setTextColor(Color.WHITE);
        viewfinder.setGravity(Gravity.CENTER);
        viewfinder.setAllCaps(false);
        viewfinder.setPadding(0, 0, 0, 0);
        viewfinder.setBackground(rounded(UI_SECONDARY, 14, 0));
        viewfinder.setStateListAnimator(null);
        viewfinder.setContentDescription(tr("取景"));
        viewfinder.setOnClickListener(view -> showSection("monitor"));
        LinearLayout.LayoutParams viewfinderParams =
                new LinearLayout.LayoutParams(dp(44), dp(44));
        viewfinderParams.setMargins(0, 0, dp(8), 0);
        top.addView(viewfinder, viewfinderParams);

        Button more = new Button(this);
        more.setText("⋯");
        more.setTextSize(TS_TITLE);
        more.setTextColor(Color.WHITE);
        more.setGravity(Gravity.CENTER);
        more.setAllCaps(false);
        more.setPadding(0, 0, 0, 0);
        more.setBackground(rounded(UI_SECONDARY, 14, 0));
        more.setStateListAnimator(null);
        more.setContentDescription(tr("更多"));
        more.setOnClickListener(view -> showControlBubbleMenu(view));
        top.addView(more, new LinearLayout.LayoutParams(dp(44), dp(44)));
    }

    /** v1.5.5 fig1 menu: keeps every section reachable from the control page. */
    private void showControlMenuDialog() {
        if (isFinishing() || isDestroyed()) return;
        String[] entries = new String[]{
                tr("连接 / 断开相机"),
                tr("视频监看"),
                tr("编辑"),
                tr("设备"),
                tr("文件库"),
                tr("设置")
        };
        final String[] sections = new String[]{
                "connect",
                "monitor",
                "editor",
                "devices",
                "library",
                "settings"
        };
        new AlertDialog.Builder(this)
                .setTitle(tr("菜单"))
                .setItems(entries, (dialog, which) ->
                        handleControlMenuTarget(sections[which]))
                .show();
    }

    /**
     * v1.5.7 拍照页改版：右上角 ⋯ 收编「我的设备」「设置」并改为气泡弹窗
     * （PopupMenu，深色控制栏风格）；☰ 保留原有对话框导航。
     */
    private void showControlBubbleMenu(View anchor) {
        if (isFinishing() || isDestroyed()) return;
        PopupMenu popup = new PopupMenu(this, anchor);
        Menu menu = popup.getMenu();
        final String[] sections = new String[]{
                "connect",
                "monitor",
                "editor",
                "devices",
                "library",
                "settings"
        };
        int id = 1;
        for (String section : sections) {
            menu.add(Menu.NONE, id++, Menu.NONE, controlMenuLabel(section));
        }
        popup.setOnMenuItemClickListener(item -> {
            String target = sections[item.getItemId() - 1];
            handleControlMenuTarget(target);
            return true;
        });
        popup.show();
    }

    private String controlMenuLabel(String section) {
        switch (section) {
            case "connect":
                return tr("连接 / 断开相机");
            case "monitor":
                return tr("视频监看");
            case "editor":
                return tr("编辑");
            case "devices":
                return tr("设备");
            case "library":
                return tr("文件库");
            case "settings":
                return tr("设置");
            default:
                return section;
        }
    }

    private void handleControlMenuTarget(String target) {
        if (isFinishing() || isDestroyed()) return;
        if ("connect".equals(target)) {
            if (connected || wifiConnected || localCameraConnected) {
                if (connected) disconnectCamera();
                if (wifiConnected) disconnectWifiCamera();
                if (localCameraConnected) disconnectLocalCamera();
            } else {
                showConnectionDialog();
            }
        } else if ("editor".equals(target)) {
            editorState = EditorState.PRO;
            aiResultBitmap = null;
            showSection(target);
        } else {
            showSection(target);
        }
    }


    private View buildBottomNavigation() {
        boolean compact = isCompactPhone();
        LinearLayout navigation = new LinearLayout(this);
        navigation.setOrientation(LinearLayout.HORIZONTAL);
        navigation.setGravity(Gravity.CENTER);
        navigation.setPadding(
                dp(6),
                dp(compact ? 5 : 7),
                dp(6),
                dp(compact ? 5 : 7));
        navigation.setBackgroundColor(UI_BG);
        navigation.setElevation(0);
        // v1.5.7（Tauber 拍板 + kimi 派工）：移动端拍照页改版后底栏 4 tab：
        // 拍照/视频/编辑/分支；我的设备与设置收入拍照页右上角 ⋯ 气泡。
        navigation.addView(navButton("拍照", "capture"));
        navigation.addView(navButton("视频", "monitor"));
        navigation.addView(navButton("编辑", "editor"));
        navigation.addView(navButton("分支", "library"));
        return navigation;
    }

    private View navButton(String label, String section) {
        Button button = nativeButton(label, false);
        button.setTag(section);
        button.setTextSize(isCompactPhone() ? 10 : 11);
        button.setIncludeFontPadding(false);
        button.setCompoundDrawablePadding(dp(4));
        button.setPadding(dp(8), dp(6), dp(8), dp(5));
        int iconResource;
        switch (section) {
            case "library":
                iconResource = R.drawable.ic_nav_library;
                break;
            case "settings":
                iconResource = R.drawable.ic_settings_gear;
                break;
            case "monitor":
                iconResource = R.drawable.ic_nav_video;
                break;
            case "devices":
                iconResource = R.drawable.ic_nav_camera;
                break;
            default:
                iconResource = R.drawable.ic_nav_camera;
                break;
        }
        Drawable icon = getDrawable(iconResource);
        icon.setTint(UI_LABEL);
        icon.setBounds(0, 0, dp(20), dp(20));
        button.setCompoundDrawables(null, icon, null, null);
        button.setOnClickListener(view -> {
            if ("editor".equals(section)) {
                // Navigation opens the stable default; mode changes live in the editor.
                editorState = EditorState.PRO;
                aiResultBitmap = null;
            }
            showSection(section);
        });
        navigationButtons.add(button);
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(
                0,
                dp(isCompactPhone() ? 52 : 54),
                1f);
        params.setMargins(dp(2), 0, dp(2), 0);
        button.setLayoutParams(params);
        return button;
    }

    private View buildStatusBar() {
        LinearLayout bar = new LinearLayout(this);
        bar.setOrientation(LinearLayout.HORIZONTAL);
        bar.setGravity(Gravity.CENTER_VERTICAL);
        bar.setPadding(dp(14), 0, dp(14), 0);
        bar.setBackgroundColor(GRAPHITE);
        statusText = text("未连接", TS_CAPTION, Typeface.NORMAL, STATUS_MUTED);
        statusText.setSingleLine(true);
        statusText.setEllipsize(TextUtils.TruncateAt.END);
        countText = text(tr("文件库 · %lld 个文件").replace("%lld", "0"),
                11, Typeface.BOLD, STATUS_MUTED);
        countText.setSingleLine(true);
        countText.setPadding(dp(12), 0, 0, 0);
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
        liveMonitoringSwitch = null;
        liveMonitoringDetail = null;
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
            case "devices":
                content = buildMyDevicesView();
                break;
            default:
                content = buildCaptureView();
                break;
        }
        contentHost.addView(content, new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT));
        boolean darkMonitor = "monitor".equals(section);
        boolean controlPage = "capture".equals(section);
        if (applicationRoot != null) applicationRoot.setBackgroundColor(
                (darkMonitor || controlPage) ? UI_BG : PAPER);
        if (applicationTopBar != null) {
            if (controlPage != controlTopBarActive) {
                controlTopBarActive = controlPage;
                LinearLayout bar = (LinearLayout) applicationTopBar;
                bar.removeAllViews();
                if (controlPage) {
                    fillControlTopBar(bar);
                } else {
                    fillStandardTopBar(bar, isCompactPhone());
                }
            }
            applicationTopBar.setVisibility(darkMonitor ? View.GONE : View.VISIBLE);
            applicationTopBar.setBackgroundColor(
                    darkMonitor ? Color.BLACK
                            : controlPage ? UI_BG : SURFACE);
            applicationTopBar.setElevation(controlPage ? 0 : darkMonitor ? 0 : dp(6));
        }
        if (applicationBottomNavigation != null) {
            applicationBottomNavigation.setBackgroundColor(UI_BG);
        }
        if (applicationStatusBar != null) {
            // Keep the global operation state reachable while monitoring. The
            // graphite bar is part of the camera chrome and does not obscure
            // the preview, unlike the full application header.
            applicationStatusBar.setVisibility(View.VISIBLE);
        }
        boolean darkChrome = darkMonitor || controlPage;
        getWindow().setStatusBarColor(darkChrome ? Color.BLACK : PAPER);
        getWindow().getDecorView().setSystemUiVisibility(
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                        | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                        | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                        | (darkChrome ? 0 : View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR));
        if (darkMonitor) {
            mainHandler.removeCallbacks(monitorTimerTicker);
            mainHandler.post(monitorTimerTicker);
        }
        for (Button button : navigationButtons) {
            boolean active = section.equals(button.getTag());
            // v1.5.5 fig1: selected tab highlighted with system blue, flat.
            button.setTextColor(active ? UI_BLUE : UI_LABEL);
            button.setBackground(rounded(
                    active ? Color.argb(24, 10, 132, 255) : Color.TRANSPARENT, 14, 0));
            Drawable icon = button.getCompoundDrawables()[1];
            if (icon != null) icon.mutate().setTint(active ? UI_BLUE : UI_LABEL);
            button.setElevation(0);
        }
        updateCameraControls();
        updateConnectionUi();
        final String pendingKey = pendingEditorScrollKey;
        pendingEditorScrollKey = null;
        if (pendingKey != null) {
            contentHost.post(() -> scrollEditorGroupIntoView(pendingKey));
        }
    }

    private void scrollEditorGroupIntoView(String key) {
        View target = contentHost.findViewWithTag(key);
        if (target == null || contentHost.getChildCount() == 0) return;
        View scroller = contentHost.getChildAt(0);
        if (!(scroller instanceof ScrollView)) return;
        View content = ((ScrollView) scroller).getChildAt(0);
        if (content == null) return;
        int top = 0;
        View cursor = target;
        while (cursor != null && cursor != content) {
            top += cursor.getTop();
            cursor = (View) cursor.getParent();
        }
        ((ScrollView) scroller).smoothScrollTo(0, Math.max(0, top - dp(16)));
    }

    private View buildCaptureView() {
        boolean compact = isCompactPhone();
        ScrollView scroll = new ScrollView(this);
        scroll.setBackgroundColor(UI_BG);
        scroll.setVerticalScrollBarEnabled(false);
        LinearLayout content = verticalContainer();
        content.setPadding(
                dp(compact ? 14 : 20),
                dp(compact ? 12 : 18),
                dp(compact ? 14 : 20),
                dp(28));
        // v1.5.6 拍照页监看画面移至顶部（对齐 iOS 口径）：第一内容区，
        // 位于功能顶栏之后、状态行之前。
        content.addView(buildPreviewStage(false));
        content.addView(buildLiveMonitoringSwitch());
        content.addView(buildControlStatusRow());
        controlStatusError = text("", TS_BODY, Typeface.NORMAL, VIDEO);
        controlStatusError.setSingleLine(true);
        controlStatusError.setEllipsize(TextUtils.TruncateAt.END);
        controlStatusError.setPadding(dp(2), 0, dp(2), 0);
        controlStatusError.setVisibility(View.GONE);
        content.addView(controlStatusError, marginParams(-1, dp(18), 0, 0, 0, 4));
        content.addView(buildStatusCardGrid());
        content.addView(buildControlCaptureDock());
        // v1.5.7 拍照页监看恢复：快门 dock 下方的紧凑 RGB 三色叠加波形条，
        // 复用视频页 WaveformScopeView（RGB_PARADE），无音频无录制钮。
        captureScopeView = new WaveformScopeView(WaveformScopeView.RGB_PARADE);
        captureScopeView.setData(redHistogram, greenHistogram, blueHistogram);
        content.addView(captureScopeView, marginParams(-1, dp(78), 0, 4, 0, 12));
        content.addView(buildControlParameterGrid());
        content.addView(buildNikonCloudMonitorPanel());
        content.addView(buildCaptureSessionPanel());
        content.addView(buildProfessionalControls());
        content.addView(buildShootingTaskPanel());
        scroll.addView(content);
        refreshControlStatusRow();
        return scroll;
    }

    private View buildLiveMonitoringSwitch() {
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(Gravity.CENTER_VERTICAL);
        row.setPadding(dp(12), 0, dp(12), 0);
        row.setBackground(rounded(UI_CARD, 12, UI_SECONDARY));

        LinearLayout labels = new LinearLayout(this);
        labels.setOrientation(LinearLayout.VERTICAL);
        TextView title = text(tr("实时监看"), TS_BODY, Typeface.BOLD, Color.WHITE);
        liveMonitoringDetail = text(
                tr(liveViewEnabled ? "显示相机实时画面" : "实时监看已关闭"),
                TS_CAPTION,
                Typeface.NORMAL,
                UI_LABEL);
        labels.addView(title);
        labels.addView(liveMonitoringDetail);
        row.addView(labels, new LinearLayout.LayoutParams(0, dp(52), 1f));

        liveMonitoringSwitch = new Switch(this);
        liveMonitoringSwitch.setText("");
        liveMonitoringSwitch.setChecked(liveViewEnabled);
        liveMonitoringSwitch.setEnabled(
                connected || localCameraConnected || wifiConnected);
        liveMonitoringSwitch.setContentDescription(tr("实时监看"));
        liveMonitoringSwitch.setOnCheckedChangeListener((button, enabled) -> {
            if (syncingLiveMonitoringSwitch || enabled == liveViewEnabled) return;
            toggleLiveView();
        });
        row.addView(liveMonitoringSwitch, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                dp(52)));
        return row;
    }

    /** v1.5.5 fig1 status row: ● state + transport capsule, tap to connect. */
    private View buildControlStatusRow() {
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(Gravity.CENTER_VERTICAL);
        row.setLayoutParams(marginParams(-1, dp(36), 0, 0, 0, 8));

        LinearLayout left = new LinearLayout(this);
        left.setOrientation(LinearLayout.HORIZONTAL);
        left.setGravity(Gravity.CENTER_VERTICAL);
        // v1.5.7 P1：状态点 22dp → 10dp（视觉对齐 macOS 8pt 基准；触控面由行整体 36dp 高保证）
        controlStatusDot = text("●", 10, Typeface.BOLD, UI_LABEL);
        controlStatusDot.setGravity(Gravity.CENTER);
        left.addView(controlStatusDot, new LinearLayout.LayoutParams(dp(10), dp(30)));
        controlStatusText = text("未连接", 13, Typeface.BOLD, Color.WHITE);
        controlStatusText.setSingleLine(true);
        controlStatusText.setEllipsize(TextUtils.TruncateAt.END);
        left.addView(controlStatusText, new LinearLayout.LayoutParams(0, dp(30), 1f));
        left.setOnClickListener(view -> {
            if (!(connected || wifiConnected || localCameraConnected)) {
                showConnectionDialog();
            }
        });
        left.setContentDescription(tr("连接状态"));
        row.addView(left, new LinearLayout.LayoutParams(0, dp(36), 1f));

        controlStatusRate = text("待连接", TS_BODY, Typeface.BOLD, Color.WHITE);
        controlStatusRate.setGravity(Gravity.CENTER);
        controlStatusRate.setSingleLine(true);
        controlStatusRate.setPadding(dp(12), 0, dp(12), 0);
        controlStatusRate.setBackground(rounded(UI_SECONDARY, 15, 0));
        controlStatusRate.setContentDescription(tr("连接状态"));
        controlStatusRate.setOnClickListener(view -> {
            // fig1: tapping the transport capsule opens the connection dialog
            // whenever no camera is live (covers both 待连接 and 重试 states).
            if (!(connected || wifiConnected || localCameraConnected)
                    && !(connecting || wifiConnecting || localCameraConnecting)) {
                showConnectionDialog();
            }
        });
        row.addView(controlStatusRate, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                dp(30)));
        return row;
    }

    /** v1.5.5 fig1 status row sync; keeps the empty/loading/error wording terse. */
    private void refreshControlStatusRow() {
        if (controlStatusDot == null
                || controlStatusText == null
                || controlStatusRate == null) {
            return;
        }
        boolean anyCamera = connected || wifiConnected || localCameraConnected;
        boolean loading = connecting || wifiConnecting || localCameraConnecting;
        boolean failed = lastConnectionError != null && !anyCamera && !loading;
        controlStatusRate.setBackground(rounded(UI_SECONDARY, 15, 0));
        controlStatusRate.setTextColor(Color.WHITE);
        if (loading) {
            controlStatusDot.setTextColor(UI_ACCENT);
            controlStatusText.setText(tr(connecting
                    ? "正在连接…"
                    : wifiConnecting
                            ? "正在连接 Wi‑Fi 相机…"
                            : "正在打开本机摄像头…"));
            controlStatusRate.setText(tr("连接中"));
        } else if (anyCamera) {
            controlStatusDot.setTextColor(UI_ACCENT);
            controlStatusText.setText(tr("就绪"));
            controlStatusRate.setText(connected
                    ? "USB/PTP"
                    : wifiConnected ? "Wi‑Fi/PTP‑IP" : "SYSTEM");
        } else {
            controlStatusDot.setTextColor(failed ? VIDEO : UI_LABEL);
            controlStatusText.setText(tr(failed ? "连接失败" : "未连接"));
            controlStatusRate.setText(tr(failed ? "重试" : "待连接"));
        }
        if (controlStatusError != null) {
            boolean showError = failed && lastConnectionError != null;
            controlStatusError.setVisibility(showError ? View.VISIBLE : View.GONE);
            controlStatusError.setText(showError ? lastConnectionError : "");
        }
    }

    /** v1.5.5 fig1 status cards: 2×2 on phones, 4-across on wide screens. */
    private View buildStatusCardGrid() {
        boolean compact = isCompactPhone();
        LinearLayout grid = new LinearLayout(this);
        grid.setOrientation(compact ? LinearLayout.VERTICAL : LinearLayout.HORIZONTAL);
        grid.setLayoutParams(marginParams(-1, -2, 0, 0, 0, 12));

        View body = buildStatusCard(
                "▣",
                "机身",
                bodyModelName(),
                bodySerialLine(),
                connected || wifiConnected || localCameraConnected);
        View lens = buildStatusCard(
                "◎",
                "镜头",
                "—",
                "镜头数据未提供",
                false);
        View storage = buildStorageStatusCard();
        View format = buildStatusCard(
                "▤",
                "格式",
                "JPEG",
                "照片输出",
                false);

        if (compact) {
            LinearLayout topRow = new LinearLayout(this);
            topRow.setOrientation(LinearLayout.HORIZONTAL);
            topRow.addView(body, new LinearLayout.LayoutParams(0, dp(104), 1f));
            LinearLayout.LayoutParams lensParams =
                    new LinearLayout.LayoutParams(0, dp(104), 1f);
            lensParams.setMargins(dp(10), 0, 0, 0);
            topRow.addView(lens, lensParams);
            grid.addView(topRow);
            LinearLayout bottomRow = new LinearLayout(this);
            bottomRow.setOrientation(LinearLayout.HORIZONTAL);
            bottomRow.addView(storage, new LinearLayout.LayoutParams(0, dp(104), 1f));
            LinearLayout.LayoutParams formatParams =
                    new LinearLayout.LayoutParams(0, dp(104), 1f);
            formatParams.setMargins(dp(10), 0, 0, 0);
            bottomRow.addView(format, formatParams);
            grid.addView(bottomRow, new LinearLayout.LayoutParams(-1, -2));
        } else {
            grid.addView(body, new LinearLayout.LayoutParams(0, dp(104), 1f));
            LinearLayout.LayoutParams lensParams =
                    new LinearLayout.LayoutParams(0, dp(104), 1f);
            lensParams.setMargins(dp(10), 0, 0, 0);
            grid.addView(lens, lensParams);
            LinearLayout.LayoutParams storageParams =
                    new LinearLayout.LayoutParams(0, dp(104), 1f);
            storageParams.setMargins(dp(10), 0, 0, 0);
            grid.addView(storage, storageParams);
            LinearLayout.LayoutParams formatParams =
                    new LinearLayout.LayoutParams(0, dp(104), 1f);
            formatParams.setMargins(dp(10), 0, 0, 0);
            grid.addView(format, formatParams);
        }
        return grid;
    }

    private String bodyModelName() {
        if (connected) return connectedCameraName == null ? "—" : connectedCameraName;
        if (localCameraConnected) return localCamera.getCameraName();
        if (wifiConnected) return wifiCameraName == null ? "—" : wifiCameraName;
        return "—";
    }

    private String bodySerialLine() {
        if (connected && camera != null && camera.isConnected()) {
            return "SN " + camera.getConnectedDeviceId();
        }
        return "—";
    }

    private View buildStatusCard(
            String icon,
            String label,
            String value,
            String sub,
            boolean active) {
        LinearLayout card = verticalContainer();
        card.setPadding(dp(14), dp(12), dp(14), dp(12));
        card.setBackground(rounded(UI_CARD, 15, active ? UI_ACCENT : 0));
        LinearLayout header = new LinearLayout(this);
        header.setOrientation(LinearLayout.HORIZONTAL);
        header.setGravity(Gravity.CENTER_VERTICAL);
        TextView iconView = text(icon, 16, Typeface.NORMAL, UI_LABEL);
        iconView.setGravity(Gravity.CENTER);
        header.addView(iconView, new LinearLayout.LayoutParams(dp(24), dp(24)));
        TextView labelView = text(label, TS_BODY, Typeface.NORMAL, UI_LABEL);
        labelView.setPadding(dp(6), 0, 0, 0);
        header.addView(labelView);
        card.addView(header);
        TextView valueView = text(value, 20, Typeface.BOLD, Color.WHITE);
        valueView.setSingleLine(true);
        valueView.setEllipsize(TextUtils.TruncateAt.END);
        card.addView(valueView, marginParams(-1, dp(28), 0, 6, 0, 0));
        TextView subView = text(sub == null || sub.isEmpty() ? " " : sub,
                TS_BODY,
                Typeface.NORMAL,
                UI_LABEL);
        subView.setSingleLine(true);
        subView.setEllipsize(TextUtils.TruncateAt.END);
        card.addView(subView, marginParams(-1, dp(18), 0, 1, 0, 0));
        return card;
    }

    /** v1.5.5 fig1 storage card with accent progress bar, honest 无卡 state. */
    private View buildStorageStatusCard() {
        LinearLayout card = verticalContainer();
        card.setPadding(dp(14), dp(12), dp(14), dp(12));
        boolean anyCamera = connected || wifiConnected;
        boolean hasVolumes = anyCamera && !cameraStorageSnapshot.volumes.isEmpty();
        card.setBackground(rounded(UI_CARD, 15, 0));
        LinearLayout header = new LinearLayout(this);
        header.setOrientation(LinearLayout.HORIZONTAL);
        header.setGravity(Gravity.CENTER_VERTICAL);
        TextView iconView = text("▯", 16, Typeface.NORMAL, UI_LABEL);
        iconView.setGravity(Gravity.CENTER);
        header.addView(iconView, new LinearLayout.LayoutParams(dp(24), dp(24)));
        TextView labelView = text("存储", TS_BODY, Typeface.NORMAL, UI_LABEL);
        labelView.setPadding(dp(6), 0, 0, 0);
        header.addView(labelView);
        card.addView(header);

        long capacity = cameraStorageSnapshot.capacityBytes();
        long free = cameraStorageSnapshot.freeBytes();
        long used = Math.max(0, capacity - free);
        int percent = capacity > 0
                ? (int) Math.max(0, Math.min(100, Math.round(used * 100.0 / capacity)))
                : 0;
        String valueText = hasVolumes
                ? formatStorageBytes(used) + "/" + formatStorageBytes(capacity)
                        + " · " + percent + "%"
                : "—";
        TextView valueView = text(valueText, 16, Typeface.BOLD, Color.WHITE);
        valueView.setSingleLine(true);
        valueView.setEllipsize(TextUtils.TruncateAt.END);
        card.addView(valueView, marginParams(-1, dp(26), 0, 6, 0, 0));

        if (hasVolumes) {
            LinearLayout track = new LinearLayout(this);
            track.setOrientation(LinearLayout.HORIZONTAL);
            View fill = new View(this);
            fill.setBackground(rounded(UI_ACCENT, 2, 0));
            track.addView(fill, new LinearLayout.LayoutParams(0, dp(4), percent));
            if (percent < 100) {
                track.addView(
                        new View(this),
                        new LinearLayout.LayoutParams(0, dp(4), 100 - percent));
            }
            card.addView(track, marginParams(-1, dp(4), 0, 2, 0, 0));
        } else {
            View track = new View(this);
            track.setBackground(rounded(UI_SECONDARY, 2, 0));
            card.addView(track, marginParams(-1, dp(4), 0, 2, 0, 0));
        }

        long freeImages = 0;
        for (CameraStorage.Volume volume : cameraStorageSnapshot.volumes) {
            freeImages += volume.freeImages;
        }
        String sub = hasVolumes
                ? (freeImages > 0 ? "可拍 " + freeImages + " 张" : "存储卡已满")
                : anyCamera ? "无卡" : "—";
        TextView subView = text(sub, TS_BODY, Typeface.NORMAL, UI_LABEL);
        subView.setSingleLine(true);
        subView.setEllipsize(TextUtils.TruncateAt.END);
        card.addView(subView, marginParams(-1, dp(18), 0, 1, 0, 0));
        return card;
    }

    /** v1.5.5 fig1 parameter grid: 3-column tiles (4-6 on wide screens) + 全部/编辑. */
    private View buildControlParameterGrid() {
        LinearLayout wrap = verticalContainer();
        wrap.setLayoutParams(marginParams(-1, -2, 0, 2, 0, 12));
        LinearLayout header = new LinearLayout(this);
        header.setOrientation(LinearLayout.HORIZONTAL);
        header.setGravity(Gravity.CENTER_VERTICAL);
        TextView title = text("参数", TS_EMPHASIS, Typeface.BOLD, Color.WHITE);
        header.addView(title, new LinearLayout.LayoutParams(0, dp(44), 1f));
        final Button all = controlCapsule("全部", true);
        final Button edit = controlCapsule("编辑", false);
        all.setOnClickListener(view -> {
            gridEditMode = false;
            if (gridHiddenTiles != null) Arrays.fill(gridHiddenTiles, false);
            refreshControlCapsules(all, edit);
            rebuildControlParameterTiles();
        });
        edit.setOnClickListener(view -> {
            gridEditMode = !gridEditMode;
            refreshControlCapsules(all, edit);
            rebuildControlParameterTiles();
        });
        LinearLayout.LayoutParams allParams = new LinearLayout.LayoutParams(dp(68), dp(44));
        header.addView(all, allParams);
        LinearLayout.LayoutParams editParams = new LinearLayout.LayoutParams(dp(68), dp(44));
        editParams.setMargins(dp(8), 0, 0, 0);
        header.addView(edit, editParams);
        // Header spans full width so the weighted 参数 title cannot collapse.
        wrap.addView(header, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT));

        controlParameterTilesHost = verticalContainer();
        wrap.addView(controlParameterTilesHost);
        if (gridHiddenTiles == null) gridHiddenTiles = new boolean[8];
        gridEditMode = false;
        rebuildControlParameterTiles();
        return wrap;
    }

    private Button controlCapsule(String label, boolean active) {
        Button capsule = new Button(this);
        capsule.setText(tr(label));
        capsule.setTextSize(TS_BODY);
        capsule.setTypeface(Typeface.create("sans", Typeface.BOLD));
        capsule.setAllCaps(false);
        capsule.setGravity(Gravity.CENTER);
        capsule.setPadding(dp(10), 0, dp(10), 0);
        capsule.setMinHeight(0);
        capsule.setStateListAnimator(null);
        capsule.setBackground(rounded(active ? UI_ACCENT : UI_SECONDARY, 16, 0));
        capsule.setTextColor(active ? INK : Color.WHITE);
        return capsule;
    }

    private void refreshControlCapsules(Button all, Button edit) {
        all.setBackground(rounded(
                gridEditMode ? UI_SECONDARY : UI_ACCENT, 16, 0));
        all.setTextColor(gridEditMode ? Color.WHITE : INK);
        edit.setBackground(rounded(
                gridEditMode ? UI_ACCENT : UI_SECONDARY, 16, 0));
        edit.setTextColor(gridEditMode ? INK : Color.WHITE);
    }

    /** Grid rebuild driven purely by local UI state (gridEditMode / hidden tiles). */
    private void rebuildControlParameterTiles() {
        if (controlParameterTilesHost == null) return;
        controlParameterTilesHost.removeAllViews();
        boolean compact = isCompactPhone();
        int columns = compact ? 3 : 4;
        String[][] tiles = controlParameterTiles();
        int shown = 0;
        for (int index = 0; index < tiles.length; index++) {
            if (gridHiddenTiles != null && index < gridHiddenTiles.length
                    && gridHiddenTiles[index]) {
                continue;
            }
            shown++;
        }
        if (shown == 0) {
            controlParameterTilesHost.addView(
                    text("参数已全部隐藏", TS_BODY, Typeface.NORMAL, UI_LABEL),
                    marginParams(-1, dp(44), 0, 12, 0, 0));
            return;
        }
        int rowCount = (shown + columns - 1) / columns;
        for (int rowIndex = 0; rowIndex < rowCount; rowIndex++) {
            LinearLayout row = new LinearLayout(this);
            row.setOrientation(LinearLayout.HORIZONTAL);
            int inRow = 0;
            for (int index = 0; index < tiles.length && inRow < columns; index++) {
                if (gridHiddenTiles != null && index < gridHiddenTiles.length
                        && gridHiddenTiles[index]) {
                    continue;
                }
                final int tileIndex = index;
                View tile = controlParameterTile(
                        tileIndex,
                        tiles[index][0],
                        tiles[index][1],
                        gridEditMode);
                LinearLayout.LayoutParams tileParams =
                        new LinearLayout.LayoutParams(0, dp(84), 1f);
                if (inRow > 0) tileParams.setMargins(dp(8), 0, 0, 0);
                row.addView(tile, tileParams);
                inRow++;
            }
            LinearLayout.LayoutParams rowParams =
                    new LinearLayout.LayoutParams(-1, dp(84));
            if (rowIndex > 0) rowParams.setMargins(0, dp(8), 0, 0);
            controlParameterTilesHost.addView(row, rowParams);
        }
    }

    private String[][] controlParameterTiles() {
        boolean live = connected || localCameraConnected;
        return new String[][]{
                {"模式", live ? exposureModeCode() : "—"},
                {"快门", connected ? shutterDisplayValue() : "—"},
                {"光圈", connected
                        ? String.format(Locale.CHINA, "f/%.1f", currentAperture)
                        : "—"},
                {"ISO", connected ? String.valueOf(currentIso) : "—"},
                {"EV", connected
                        ? String.format(Locale.CHINA, "%+.1f", currentCompensation)
                        : "—"},
                {"传输", connected ? "PTP" : wifiConnected ? "PTP-IP" : "—"},
                {"白平衡", connected
                        ? ("continuous".equals(currentWhiteBalance) ? "自动" : "预设")
                        : "—"},
                {"对焦", connected
                        ? ("continuous".equals(currentFocusMode) ? "AF-C" : "AF-S")
                        : "—"}
        };
    }

    private View controlParameterTile(
            int index,
            String label,
            String value,
            boolean editing) {
        FrameLayout frame = new FrameLayout(this);
        LinearLayout tile = verticalContainer();
        tile.setPadding(dp(12), dp(10), dp(12), dp(10));
        tile.setBackground(rounded(UI_CARD, 15, 0));
        TextView labelView = text(label, TS_BODY, Typeface.NORMAL, UI_LABEL);
        labelView.setSingleLine(true);
        tile.addView(labelView, new LinearLayout.LayoutParams(-1, dp(20)));
        TextView valueView = text(value, 28, Typeface.BOLD, Color.WHITE);
        valueView.setSingleLine(true);
        valueView.setEllipsize(TextUtils.TruncateAt.END);
        tile.addView(valueView, marginParams(-1, dp(36), 0, 4, 0, 0));
        frame.addView(tile, new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT));
        if (editing) {
            TextView remove = text("×", TS_EMPHASIS, Typeface.BOLD, Color.WHITE);
            remove.setGravity(Gravity.CENTER);
            remove.setBackground(rounded(UI_SECONDARY, 11, 0));
            remove.setContentDescription(tr("隐藏") + " " + tr(label));
            remove.setOnClickListener(view -> {
                if (gridHiddenTiles != null && index < gridHiddenTiles.length) {
                    gridHiddenTiles[index] = true;
                    rebuildControlParameterTiles();
                }
            });
            // v1.5.7 P1：×钮 22×22dp → 44×44dp 触控合规（design.md ≥44×44）
            FrameLayout.LayoutParams removeParams =
                    new FrameLayout.LayoutParams(dp(44), dp(44), Gravity.TOP | Gravity.END);
            frame.addView(remove, removeParams);
        }
        return frame;
    }

    /** v1.5.5 fig1 capture bar: gallery, AF-ON, round shutter, INT, camera switch. */
    private View buildControlCaptureDock() {
        LinearLayout dock = new LinearLayout(this);
        dock.setOrientation(LinearLayout.HORIZONTAL);
        dock.setGravity(Gravity.CENTER_VERTICAL);
        dock.setPadding(dp(10), dp(10), dp(10), dp(10));
        dock.setBackground(rounded(UI_CARD, 16, 0));
        dock.setLayoutParams(marginParams(-1, -2, 0, 4, 0, 12));

        FrameLayout gallery = new FrameLayout(this);
        gallery.setBackground(rounded(UI_SECONDARY, 10, 0));
        File first = firstPhotoFile();
        if (first != null) {
            ImageView thumb = new ImageView(this);
            thumb.setScaleType(ImageView.ScaleType.CENTER_CROP);
            thumb.setImageBitmap(loadThumbnail(first));
            gallery.addView(thumb, new FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT));
        } else {
            TextView placeholder = text("▢", 20, Typeface.NORMAL, UI_LABEL);
            placeholder.setGravity(Gravity.CENTER);
            gallery.addView(placeholder, new FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT));
        }
        gallery.setContentDescription(tr("文件库"));
        gallery.setOnClickListener(view -> showSection("library"));
        dock.addView(gallery, new LinearLayout.LayoutParams(dp(56), dp(56)));

        Button afOn = controlCapsule("AF-ON", false);
        afOn.setOnClickListener(view -> requestAutoFocusOn());
        cameraControls.add(afOn);
        LinearLayout.LayoutParams afParams = new LinearLayout.LayoutParams(dp(76), dp(44));
        afParams.setMargins(dp(8), 0, 0, 0);
        dock.addView(afOn, afParams);

        shutterButton = new Button(this);
        shutterButton.setText("●");
        shutterButton.setTextSize(TS_DISPLAY);
        shutterButton.setTextColor(UI_ACCENT);
        GradientDrawable shutterBackground = new GradientDrawable();
        shutterBackground.setShape(GradientDrawable.OVAL);
        shutterBackground.setColor(UI_CARD);
        shutterBackground.setStroke(dp(3), UI_ACCENT);
        shutterButton.setBackground(shutterBackground);
        shutterButton.setStateListAnimator(null);
        shutterButton.setContentDescription(tr("拍摄"));
        shutterButton.setOnClickListener(view -> capturePhoto());
        cameraControls.add(shutterButton);
        LinearLayout.LayoutParams shutterParams =
                new LinearLayout.LayoutParams(dp(76), dp(76));
        shutterParams.setMargins(dp(10), 0, dp(10), 0);
        dock.addView(shutterButton, shutterParams);

        Button interval = controlCapsule("INT", false);
        interval.setBackground(rounded(
                shootingTaskRunning ? UI_ACCENT : UI_SECONDARY, 18, 0));
        interval.setTextColor(shootingTaskRunning ? INK : Color.WHITE);
        interval.setContentDescription(tr("间隔拍摄"));
        interval.setOnClickListener(view -> scrollTagIntoView("shootingTaskPanel"));
        dock.addView(interval, new LinearLayout.LayoutParams(dp(64), dp(44)));

        ImageButton switchCamera = new ImageButton(this);
        switchCamera.setImageResource(R.drawable.ic_nav_camera);
        switchCamera.setColorFilter(Color.WHITE);
        switchCamera.setScaleType(ImageView.ScaleType.CENTER);
        switchCamera.setPadding(dp(10), dp(10), dp(10), dp(10));
        switchCamera.setBackground(rounded(UI_SECONDARY, 14, 0));
        switchCamera.setStateListAnimator(null);
        switchCamera.setContentDescription(tr("切换相机"));
        switchCamera.setOnClickListener(view -> showSection("devices"));
        LinearLayout.LayoutParams switchParams =
                new LinearLayout.LayoutParams(dp(44), dp(44));
        switchParams.setMargins(dp(8), 0, 0, 0);
        dock.addView(switchCamera, switchParams);
        return dock;
    }

    private File firstPhotoFile() {
        for (File file : photoFiles()) {
            if (!isVideoFile(file)) return file;
        }
        return null;
    }

    private Bitmap loadThumbnail(File file) {
        BitmapFactory.Options bounds = new BitmapFactory.Options();
        bounds.inJustDecodeBounds = true;
        BitmapFactory.decodeFile(file.getAbsolutePath(), bounds);
        int sample = 1;
        while (Math.max(bounds.outWidth / sample, bounds.outHeight / sample) > 384) {
            sample *= 2;
        }
        BitmapFactory.Options options = new BitmapFactory.Options();
        options.inSampleSize = sample;
        return BitmapFactory.decodeFile(file.getAbsolutePath(), options);
    }

    private void scrollTagIntoView(String tag) {
        View target = contentHost.findViewWithTag(tag);
        if (target == null || contentHost.getChildCount() == 0) return;
        View scroller = contentHost.getChildAt(0);
        if (!(scroller instanceof ScrollView)) return;
        View content = ((ScrollView) scroller).getChildAt(0);
        if (content == null) return;
        int top = 0;
        View cursor = target;
        while (cursor != null && cursor != content) {
            top += cursor.getTop();
            cursor = (View) cursor.getParent();
        }
        ((ScrollView) scroller).smoothScrollTo(0, Math.max(0, top - dp(16)));
    }

    private String shutterDisplayValue() {
        return currentShutterSeconds < 1
                ? "1/" + Math.round(1 / currentShutterSeconds)
                : String.format(Locale.CHINA, "%.1fs", currentShutterSeconds);
    }

    private String exposureModeCode() {
        switch (exposureMode) {
            case "program": return "P";
            case "shutterPriority": return "S";
            case "aperturePriority": return "A";
            case "bulb": return "B";
            default: return "M";
        }
    }

    private View buildShootingTaskPanel() {
        LinearLayout panel = panel();
        // fig1: INT dock capsule scrolls here via scrollTagIntoView.
        panel.setTag("shootingTaskPanel");
        panel.addView(text("拍摄自动化", TS_TITLE, Typeface.BOLD, INK));
        panel.addView(
                text(
                        "间隔、包围与 B 门任务集中管理",
                        13,
                        Typeface.NORMAL,
                        MUTED),
                marginParams(-1, -2, 0, 3, 0, 12));
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
                text(shootingTaskStatus, TS_BODY, Typeface.NORMAL, MUTED),
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
        input.setBackground(rounded(FIELD_BG, 9, RULE));
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
        scroll.setFillViewport(true);
        scroll.setBackgroundColor(UI_BG);
        scroll.setVerticalScrollBarEnabled(false);
        LinearLayout content = verticalContainer();
        content.setPadding(dp(16), dp(10), dp(16), dp(24));
        content.setBackgroundColor(UI_BG);

        monitorTimerText = text("00:00:00:00", 38, Typeface.BOLD, Color.WHITE);
        monitorTimerText.setGravity(Gravity.CENTER);
        monitorTimerText.setTypeface(Typeface.MONOSPACE, Typeface.BOLD);
        content.addView(monitorTimerText, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, dp(74)));
        mainHandler.removeCallbacks(monitorTimerTicker);
        mainHandler.post(monitorTimerTicker);

        content.addView(buildPreviewStage(true), new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(300)));
        content.addView(buildNikonCloudMonitorPanel());

        liveViewButton = monitorActionButton(
                liveViewEnabled ? "停止取景" : "开启取景", false);
        liveViewButton.setOnClickListener(view -> toggleLiveView());
        shutterButton = monitorActionButton(
                videoRecording ? "停止录制" : "开始录制", true);
        shutterButton.setOnClickListener(view -> toggleVideoRecording());
        cameraControls.add(liveViewButton);
        cameraControls.add(shutterButton);

        LinearLayout scopeRow = new LinearLayout(this);
        scopeRow.setOrientation(LinearLayout.HORIZONTAL);
        scopeRow.setGravity(Gravity.CENTER_VERTICAL);
        scopeRow.setPadding(0, dp(12), 0, dp(4));
        scopeRow.addView(buildMonitorScopeCard("RGB 波形", true), new LinearLayout.LayoutParams(0, dp(118), 1f));
        LinearLayout.LayoutParams recordParams = new LinearLayout.LayoutParams(dp(92), dp(92));
        recordParams.setMargins(dp(10), 0, dp(10), 0);
        scopeRow.addView(shutterButton, recordParams);
        scopeRow.addView(buildMonitorScopeCard("音频波形", false), new LinearLayout.LayoutParams(0, dp(118), 1f));
        content.addView(scopeRow);

        content.addView(buildMonitorParameterRail());
        content.addView(buildMonitorToolRail());
        content.addView(buildMonitorStorageCard());
        LinearLayout actions = new LinearLayout(this);
        actions.setOrientation(LinearLayout.HORIZONTAL);
        actions.setGravity(Gravity.CENTER);
        actions.setPadding(0, dp(6), 0, dp(10));
        actions.addView(liveViewButton, new LinearLayout.LayoutParams(0, dp(44), 1f));
        content.addView(actions);
        // Keep the established camera parameter/output controls available below the new monitor surface.
        content.addView(buildMonitorParameterControls());
        content.addView(buildMonitorOutputControls());
        scroll.addView(content);
        return scroll;
    }

    private View buildMonitorScopeCard(String title, boolean histogram) {
        LinearLayout card = verticalContainer();
        card.setPadding(dp(3), dp(3), dp(3), dp(3));
        card.setBackgroundColor(Color.BLACK);
        if (histogram) {
            monitorRgbScopeView = new WaveformScopeView(WaveformScopeView.RGB_PARADE);
            monitorRgbScopeView.setData(
                    redHistogram, greenHistogram, blueHistogram);
            card.addView(monitorRgbScopeView, new LinearLayout.LayoutParams(-1, -1));
        } else {
            card.addView(
                    new WaveformScopeView(WaveformScopeView.AUDIO),
                    new LinearLayout.LayoutParams(-1, -1));
        }
        return card;
    }

    private View buildMonitorParameterRail() {
        HorizontalScrollView scroll = new HorizontalScrollView(this);
        scroll.setHorizontalScrollBarEnabled(false);
        LinearLayout rail = new LinearLayout(this);
        rail.setOrientation(LinearLayout.HORIZONTAL);
        rail.setGravity(Gravity.CENTER);
        rail.setPadding(0, dp(12), 0, dp(3));
        addMonitorReadout(rail, "帧率", connected ? String.valueOf(monitorFrameRate) : "—");
        addMonitorReadout(rail, "快门", connected ? shutterDisplayValue() : "—");
        addMonitorReadout(rail, "光圈", connected ? String.format(Locale.CHINA, "f/%.1f", currentAperture) : "—");
        addMonitorReadout(rail, "ISO", connected ? String.valueOf(currentIso) : "—");
        addMonitorReadout(rail, "白平衡", connected
                ? ("continuous".equals(currentWhiteBalance) ? "自动" : "预设")
                : "—");
        addMonitorReadout(rail, "编码", connected ? videoCodecShortLabel(videoCodec) : "—");
        addMonitorReadout(rail, "色调", connected ? String.format(Locale.CHINA, "%+d", (int) currentCompensation) : "—");
        scroll.addView(rail);
        return scroll;
    }

    private void addMonitorReadout(LinearLayout rail, String label, String value) {
        LinearLayout cell = verticalContainer();
        cell.setGravity(Gravity.CENTER);
        cell.setPadding(dp(7), 0, dp(7), 0);
        TextView title = text(label, 10, Typeface.BOLD, Color.WHITE); // v1.5.7 issue 655a0a14: 视频页标签改纯白
        title.setGravity(Gravity.CENTER);
        TextView reading = text(value, 17, Typeface.BOLD, Color.WHITE);
        reading.setGravity(Gravity.CENTER);
        reading.setTypeface(Typeface.MONOSPACE, Typeface.BOLD);
        cell.addView(title, new LinearLayout.LayoutParams(dp(64), dp(20)));
        cell.addView(reading, new LinearLayout.LayoutParams(dp(64), dp(28)));
        rail.addView(cell);
    }

    private View buildMonitorToolRail() {
        LinearLayout row = new LinearLayout(this);
        row.setGravity(Gravity.CENTER);
        row.setPadding(0, dp(8), 0, dp(10));
        String[] glyphs = {"◎", "LUT", "◉", "AF-ON"};
        String[] descriptions = {"峰值对焦", "LUT", "假色", "AF-ON"};
        for (int i = 0; i < glyphs.length; i++) {
            final int index = i;
            Button tool = new Button(this);
            tool.setText(glyphs[i]);
            tool.setTextColor(Color.WHITE);
            tool.setTextSize(i == 1 ? 11 : 24);
            tool.setTypeface(Typeface.create("sans", Typeface.BOLD));
            tool.setAllCaps(false);
            tool.setGravity(Gravity.CENTER);
            tool.setPadding(0, 0, 0, 0);
            tool.setBackgroundColor(Color.TRANSPARENT);
            tool.setContentDescription(descriptions[i]);
            tool.setOnClickListener(view -> {
                if (index == 0) {
                    focusPeakingEnabled = !focusPeakingEnabled;
                    refreshPreviewProcessing();
                    showToast(focusPeakingEnabled ? "已开启峰值对焦" : "已关闭峰值对焦");
                } else if (index == 1) {
                    showSection("monitor");
                    showToast("LUT 设置位于监看输出");
                } else if (index == 2) {
                    falseColorEnabled = !falseColorEnabled;
                    refreshPreviewProcessing();
                    showToast(falseColorEnabled ? "已开启假色" : "已关闭假色");
                } else if (index == 3) {
                    requestAutoFocusOn();
                }
            });
            row.addView(tool, new LinearLayout.LayoutParams(0, dp(48), 1f));
        }
        return row;
    }

    private View buildMonitorStorageCard() {
        String freeSpace = "—";
        String usage = "存储状态暂不可用";
        if (photoDirectory != null) {
            try {
                StatFs stats = new StatFs(photoDirectory.getAbsolutePath());
                long total = stats.getTotalBytes();
                long available = stats.getAvailableBytes();
                freeSpace = formatStorageBytes(available);
                if (total > 0) {
                    usage = String.format(
                            Locale.CHINA,
                            "%d%% 已用 · 本地缓存",
                            Math.max(0, Math.min(100, Math.round(
                                    (1 - available / (double) total) * 100))));
                }
            } catch (RuntimeException ignored) {
            }
        }
        LinearLayout card = new LinearLayout(this);
        card.setGravity(Gravity.CENTER_VERTICAL);
        card.setPadding(dp(16), dp(12), dp(16), dp(12));
        card.setBackground(rounded(UI_CARD, 14, 0));
        TextView icon = text("▯", 38, Typeface.NORMAL, Color.WHITE); // v1.5.7 issue 655a0a14: 视频页角标改纯白
        icon.setGravity(Gravity.CENTER);
        card.addView(icon, new LinearLayout.LayoutParams(dp(52), dp(70)));
        LinearLayout copy = verticalContainer();
        TextView capacity = text("—", 22, Typeface.BOLD, Color.WHITE);
        capacity.setTypeface(Typeface.MONOSPACE, Typeface.BOLD);
        copy.addView(capacity);
        TextView barLabel = text(freeSpace, TS_EMPHASIS, Typeface.BOLD, Color.WHITE);
        copy.addView(barLabel, new LinearLayout.LayoutParams(-1, dp(22)));
        LinearLayout detail = new LinearLayout(this);
        detail.setGravity(Gravity.CENTER_VERTICAL);
        detail.addView(text(usage, TS_CAPTION, Typeface.BOLD, Color.WHITE), new LinearLayout.LayoutParams(0, dp(18), 1f)); // v1.5.7 issue 655a0a14: 视频页说明改纯白
        TextView space = text("可用空间", TS_CAPTION, Typeface.BOLD, Color.WHITE); // v1.5.7 issue 655a0a14: 视频页说明改纯白
        space.setGravity(Gravity.RIGHT);
        detail.addView(space, new LinearLayout.LayoutParams(0, dp(18), 1f));
        copy.addView(detail);
        card.addView(copy, new LinearLayout.LayoutParams(0, dp(72), 1f));
        return card;
    }

    private static String formatStorageBytes(long bytes) {
        if (bytes < 0) return "—";
        double value = bytes;
        String[] units = {"B", "KB", "MB", "GB", "TB"};
        int index = 0;
        while (value >= 1024 && index < units.length - 1) {
            value /= 1024;
            index++;
        }
        return index == 0
                ? String.format(Locale.CHINA, "%.0f %s", value, units[index])
                : String.format(Locale.CHINA, "%.1f %s", value, units[index]);
    }

    private Button monitorActionButton(String label, boolean primary) {
        Button button = nativeButton(label, primary);
        button.setTextSize(TS_BODY);
        // fig1 capsule tokens: accent for the record shutter, secondary for actions.
        // v1.5.7 issue 655a0a14: 黄绿底录制钮黑字改白字（激活态不再用深色字）
        button.setTextColor(Color.WHITE);
        button.setBackground(rounded(primary ? UI_ACCENT : UI_SECONDARY, 14, 0));
        return button;
    }

    private View buildPreviewStage(boolean monitoring) {
        FrameLayout stage = new FrameLayout(this);
        stage.setBackground(rounded(GRAPHITE, 14, 0));

        previewImage = new ImageView(this);
        previewImage.setScaleType(ImageView.ScaleType.FIT_CENTER);
        previewImage.setBackgroundColor(GRAPHITE);
        Bitmap previewFrame = monitoring || monitorNikonCloudPreset != null
                ? latestFrame : latestSourceFrame;
        if (previewFrame != null) previewImage.setImageBitmap(previewFrame);
        stage.addView(previewImage, new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT));
        if (monitoring) {
            monitorFocusReticle = text("＋", 34, Typeface.NORMAL, Color.YELLOW);
            monitorFocusReticle.setGravity(Gravity.CENTER);
            monitorFocusReticle.setVisibility(View.GONE);
            FrameLayout.LayoutParams reticleParams = new FrameLayout.LayoutParams(
                    dp(58), dp(58));
            stage.addView(monitorFocusReticle, reticleParams);
            previewImage.setOnTouchListener((view, event) -> {
                if (event.getAction() != MotionEvent.ACTION_UP) return true;
                float[] point = normalizePreviewPoint(
                        event.getX(), event.getY(), view.getWidth(), view.getHeight(), latestFrame);
                if (point == null) {
                    showToast("请点击画面区域进行对焦");
                    return true;
                }
                requestMonitorFocusAt(point[0], point[1], stage);
                return true;
            });
        }

        zebraImage = new ImageView(this);
        zebraImage.setScaleType(ImageView.ScaleType.FIT_CENTER);
        zebraImage.setImageBitmap(
                monitoring && zebraEnabled ? latestZebraMask : null);
        zebraImage.setVisibility(monitoring ? View.VISIBLE : View.GONE);
        zebraImage.setContentDescription("本地条纹图案加亮显示");
        stage.addView(zebraImage, new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT));

        boolean showPreviewPlaceholder = !liveViewEnabled || previewFrame == null;
        previewPlaceholder = text(
                !liveViewEnabled
                        ? tr("实时监看已关闭")
                        : connected || localCameraConnected
                                ? "等待实时取景画面"
                                : "连接外接相机或本机摄像头后开启实时取景",
                TS_EMPHASIS,
                Typeface.NORMAL,
                Color.WHITE); // v1.5.7 issue 655a0a14: 视频页空态文字改纯白（取景井恒深 GRAPHITE）
        previewPlaceholder.setGravity(Gravity.CENTER);
        previewPlaceholder.setVisibility(showPreviewPlaceholder ? View.VISIBLE : View.GONE);
        stage.addView(previewPlaceholder, new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT));

        TextView badge = text(
                liveViewEnabled ? "● LIVE" : "● NO SOURCE",
                TS_CAPTION,
                Typeface.BOLD,
                Color.WHITE); // v1.5.7 issue 655a0a14: LIVE/NO SOURCE 状态字改纯白
        FrameLayout.LayoutParams badgeParams = new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                dp(32),
                Gravity.TOP | Gravity.START);
        badgeParams.setMargins(dp(14), dp(10), 0, 0);
        stage.addView(badge, badgeParams);

        if (!monitoring) {
            Button fullscreen = nativeButton("全屏", false);
            fullscreen.setContentDescription("打开照片全屏取景");
            fullscreen.setOnClickListener(view -> showImmersivePreview(false));
            FrameLayout.LayoutParams fullscreenParams = new FrameLayout.LayoutParams(
                    dp(82), dp(44), Gravity.TOP | Gravity.END);
            fullscreenParams.setMargins(0, dp(10), dp(14), 0);
            stage.addView(fullscreen, fullscreenParams);
        }

        TextView outputBadge = text(
                monitoring
                        ? "JPEG实时取景 · " + monitorProfileLabel()
                        : "照片实时取景 · JPEG",
                TS_CAPTION,
                Typeface.BOLD,
                Color.WHITE); // v1.5.7 issue 655a0a14: 视频页输出角标改纯白
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
                    dp(isCompactPhone() ? 268 : 380)));
        }
        return stage;
    }

    private void requestMonitorFocusAt(float normalizedX, float normalizedY, ViewGroup stage) {
        if (monitorFocusReticle != null && stage != null) {
            FrameLayout.LayoutParams params = (FrameLayout.LayoutParams) monitorFocusReticle.getLayoutParams();
            float[] rect = previewImageRect(stage.getWidth(), stage.getHeight(), latestFrame);
            params.leftMargin = Math.round(rect[0] + normalizedX * rect[2] - dp(29));
            params.topMargin = Math.round(rect[1] + normalizedY * rect[3] - dp(29));
            monitorFocusReticle.setLayoutParams(params);
            monitorFocusReticle.setVisibility(View.VISIBLE);
            mainHandler.postDelayed(() -> {
                if (monitorFocusReticle != null) monitorFocusReticle.setVisibility(View.GONE);
            }, 1400);
        }
        if (!connected || camera == null || !liveViewEnabled) {
            showToast("请先开启实时取景");
            return;
        }
        float dx = normalizedX - 0.5f;
        float dy = normalizedY - 0.5f;
        int step = Math.abs(dx) >= Math.abs(dy)
                ? Math.round(Math.max(-3f, Math.min(3f, dx * 8f)))
                : Math.round(Math.max(-3f, Math.min(3f, dy * 8f)));
        final int focusStep = step;
        cameraExecutor.submit(() -> {
            try {
                camera.setParameter("focusMode", "single-shot");
                if (focusStep != 0) camera.moveFocus(focusStep);
                mainHandler.post(() -> showToast(
                        focusStep == 0
                                ? "已触发单次自动对焦"
                                : "焦点步进已完成（当前相机不支持二维对焦点）"));
            } catch (Exception error) {
                mainHandler.post(() -> showToast("对焦请求失败：" + error.getMessage()));
            }
        });
    }

    private void requestAutoFocusOn() {
        if (!connected || camera == null || !liveViewEnabled) {
            showToast("请先开启实时取景");
            return;
        }
        cameraExecutor.submit(() -> {
            try {
                camera.triggerAutoFocus();
                mainHandler.post(() -> showToast("AF-ON 已触发"));
            } catch (Exception error) {
                mainHandler.post(() -> showToast("AF-ON 失败：" + error.getMessage()));
            }
        });
    }

    private static float[] previewImageRect(int width, int height, Bitmap bitmap) {
        if (width <= 0 || height <= 0 || bitmap == null || bitmap.getWidth() <= 0 || bitmap.getHeight() <= 0) {
            return new float[]{0f, 0f, Math.max(1, width), Math.max(1, height)};
        }
        float scale = Math.min(width / (float) bitmap.getWidth(), height / (float) bitmap.getHeight());
        float displayWidth = bitmap.getWidth() * scale;
        float displayHeight = bitmap.getHeight() * scale;
        return new float[]{(width - displayWidth) / 2f, (height - displayHeight) / 2f, displayWidth, displayHeight};
    }

    private static float[] normalizePreviewPoint(float x, float y, int width, int height, Bitmap bitmap) {
        float[] rect = previewImageRect(width, height, bitmap);
        if (x < rect[0] || y < rect[1] || x > rect[0] + rect[2] || y > rect[1] + rect[3]) return null;
        return new float[]{
                Math.max(0f, Math.min(1f, (x - rect[0]) / rect[2])),
                Math.max(0f, Math.min(1f, (y - rect[1]) / rect[3]))
        };
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
                immersiveScopeView = null;
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
        close.setBackground(rounded(HUD_BG, 12, 0));
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
                TS_CAPTION,
                Typeface.BOLD,
                Color.WHITE);
        device.setGravity(Gravity.CENTER);
        device.setMaxLines(1);
        device.setBackground(rounded(HUD_BG_SOFT, 22, 0));
        FrameLayout.LayoutParams deviceParams = new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                dp(44),
                Gravity.TOP | Gravity.CENTER_HORIZONTAL);
        deviceParams.setMargins(0, dp(22), 0, 0);
        chrome.addView(device, deviceParams);

        TextView transport = text(
                "USB/PTP · "
                        + (immersiveMonitoring ? monitorFrameRate + "P" : "JPEG"),
                TS_CAPTION,
                Typeface.BOLD,
                Color.WHITE);
        transport.setGravity(Gravity.CENTER);
        transport.setBackground(rounded(HUD_BG_SOFT, 22, 0));
        FrameLayout.LayoutParams transportParams = new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                dp(44),
                Gravity.TOP | Gravity.END);
        transportParams.setMargins(0, dp(22), dp(16), 0);
        chrome.addView(transport, transportParams);

        HorizontalScrollView telemetry = immersiveTelemetryHud();
        FrameLayout.LayoutParams telemetryParams = new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(52),
                Gravity.TOP | Gravity.CENTER_HORIZONTAL);
        telemetryParams.setMargins(dp(82), dp(76), dp(82), 0);
        chrome.addView(telemetry, telemetryParams);

        if (immersiveLandscape) {
            View scopes = immersiveScopeDock();
            FrameLayout.LayoutParams scopeParams = new FrameLayout.LayoutParams(
                    dp(270),
                    dp(86),
                    Gravity.BOTTOM | Gravity.START);
            scopeParams.setMargins(dp(18), 0, 0, dp(170));
            chrome.addView(scopes, scopeParams);
        }

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
                        (connected || localCameraConnected)
                                ? (immersiveMonitoring
                                        ? monitorFrameRate + "P"
                                        : exposureMode.toUpperCase(Locale.ROOT))
                                : "—",
                        64,
                        56));

        Button live = nativeButton(liveViewEnabled ? "LIVE" : "取景", false);
        live.setTextColor(liveViewEnabled ? INK : Color.WHITE);
        live.setBackground(rounded(
                liveViewEnabled
                        ? UI_ACCENT
                        : HUD_BG,
                12,
                0));
        live.setOnClickListener(view -> toggleLiveView());
        LinearLayout.LayoutParams liveParams =
                new LinearLayout.LayoutParams(dp(64), dp(52));
        liveParams.setMargins(0, dp(10), 0, 0);
        rail.addView(live, liveParams);

        if (immersiveMonitoring) {
            Button peaking = nativeButton("峰值", false);
            peaking.setTextColor(focusPeakingEnabled ? INK : Color.WHITE);
            peaking.setBackground(rounded(
                    focusPeakingEnabled
                            ? UI_ACCENT
                            : HUD_BG,
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

    /** Figure-1 read-only telemetry HUD backed by the active camera state. */
    private HorizontalScrollView immersiveTelemetryHud() {
        HorizontalScrollView scroll = new HorizontalScrollView(this);
        scroll.setHorizontalScrollBarEnabled(false);
        scroll.setFillViewport(true);
        scroll.setBackground(rounded(HUD_CARD_DIM, 5, UI_SECONDARY));
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        String source = connected ? "USB/PTP"
                : wifiConnected ? "PTP-IP"
                : localCameraConnected ? "SYSTEM" : "OFFLINE";
        boolean liveTelemetry = connected || localCameraConnected;
        String format = liveTelemetry
                ? (immersiveMonitoring
                        ? monitorProfileLabel() + " " + monitorFrameRate + "P"
                        : "PHOTO JPEG")
                : "—";
        addImmersiveTelemetryCell(row, "SOURCE", source);
        addImmersiveTelemetryCell(row, "FORMAT", format);
        addImmersiveTelemetryCell(
                row,
                "SHUTTER",
                liveTelemetry ? shutterDisplayValue() : "—");
        addImmersiveTelemetryCell(
                row,
                "IRIS",
                liveTelemetry
                        ? String.format(Locale.CHINA, "F%.1f", currentAperture)
                        : "—");
        addImmersiveTelemetryCell(
                row,
                "ISO",
                liveTelemetry ? String.valueOf(currentIso) : "—");
        addImmersiveTelemetryCell(
                row,
                "EV",
                liveTelemetry
                        ? String.format(Locale.CHINA, "%+.1f", currentCompensation)
                        : "—");
        addImmersiveTelemetryCell(
                row,
                "STATE",
                videoRecording ? "REC" : liveViewEnabled ? "LIVE" : "STBY");
        scroll.addView(row);
        return scroll;
    }

    private void addImmersiveTelemetryCell(
            LinearLayout parent,
            String label,
            String value) {
        TextView cell = text(label + "\n" + value, TS_CAPTION, Typeface.BOLD, Color.WHITE);
        cell.setTypeface(Typeface.MONOSPACE, Typeface.BOLD);
        cell.setGravity(Gravity.CENTER_VERTICAL);
        cell.setPadding(dp(10), 0, dp(10), 0);
        cell.setLineSpacing(dp(2), 1f);
        cell.setBackground(rounded(HUD_CARD_DIM, 0, UI_SECONDARY));
        parent.addView(cell, new LinearLayout.LayoutParams(dp(102), dp(52)));
    }

    /** Compact real-data RGB scope plus an explicit silent audio baseline. */
    private View immersiveScopeDock() {
        LinearLayout dock = new LinearLayout(this);
        dock.setOrientation(LinearLayout.HORIZONTAL);
        dock.setPadding(dp(5), dp(5), dp(5), dp(5));
        dock.setBackground(rounded(Color.argb(225, 10, 11, 13), 5, UI_SECONDARY));
        immersiveScopeView = new WaveformScopeView(WaveformScopeView.RGB_PARADE);
        immersiveScopeView.setData(
                redHistogram,
                greenHistogram,
                blueHistogram);
        dock.addView(immersiveScopeView, new LinearLayout.LayoutParams(0, -1, 2f));
        WaveformScopeView audio = new WaveformScopeView(WaveformScopeView.AUDIO);
        LinearLayout.LayoutParams audioParams = new LinearLayout.LayoutParams(0, -1, 1f);
        audioParams.setMargins(dp(5), 0, 0, 0);
        dock.addView(audio, audioParams);
        return dock;
    }

    private LinearLayout immersiveCaptureRail(boolean vertical) {
        LinearLayout rail = new LinearLayout(this);
        rail.setOrientation(vertical ? LinearLayout.VERTICAL : LinearLayout.HORIZONTAL);
        rail.setGravity(Gravity.CENTER);
        TextView section = text(
                immersiveMonitoring ? "视频" : "照片",
                17,
                Typeface.BOLD,
                UI_ACCENT);
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
        capture.setTextColor(
                immersiveMonitoring && videoRecording ? Color.WHITE : INK);
        capture.setContentDescription(tr(
                immersiveMonitoring
                        ? (videoRecording ? "停止录制" : "开始录制")
                        : "拍摄"));
        capture.setBackground(rounded(
                immersiveMonitoring && videoRecording ? VIDEO : UI_ACCENT,
                48,
                0));
        capture.setEnabled((connected || localCameraConnected) && !capturing);
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
                TS_BODY,
                Typeface.BOLD,
                Color.WHITE);
        state.setGravity(Gravity.CENTER);
        state.setBackground(rounded(HUD_BG, 10, 0));
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
        exposure.setBackground(rounded(HUD_BG, 22, 0));
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
                ? new String[]{"帧率", "模式", "编码", "Log", "对焦", "白平衡", "优化"}
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
        toggle.setBackground(rounded(HUD_BG, 10, 0));
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
        more.setTextColor(immersiveMoreParametersExpanded ? INK : Color.WHITE);
        more.setBackground(rounded(
                immersiveMoreParametersExpanded
                        ? UI_ACCENT
                        : HUD_BG,
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
            more.setTextColor(immersiveMoreParametersExpanded ? INK : Color.WHITE);
            more.setBackground(rounded(
                    immersiveMoreParametersExpanded
                            ? UI_ACCENT
                            : HUD_BG,
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
        TextView readout = text(value, TS_TITLE, Typeface.BOLD, Color.WHITE);
        readout.setGravity(Gravity.CENTER);
        readout.setBackground(rounded(HUD_BG, 12, 0));
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
        close.setBackground(rounded(HUD_BG_MID, 12, 0));
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
                TS_CAPTION,
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
                TS_TITLE,
                Typeface.BOLD,
                Color.WHITE);
        mode.setGravity(Gravity.CENTER);
        mode.setBackground(rounded(HUD_BG_SOFT, 12, 0));
        leftRail.addView(mode, new LinearLayout.LayoutParams(dp(64), dp(56)));
        TextView protocol = text("USB\nPTP", TS_CAPTION, Typeface.BOLD, Color.WHITE);
        protocol.setGravity(Gravity.CENTER);
        protocol.setBackground(rounded(HUD_BG_SOFT, 12, 0));
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
                monitoring ? VIDEO_LIVE : PHOTO_LIVE);
        section.setGravity(Gravity.CENTER);
        rightRail.addView(section, new LinearLayout.LayoutParams(dp(92), dp(44)));
        Button capture = nativeButton(
                monitoring
                        ? (videoRecording ? "■\n停止" : "●\n录制")
                        : "●\n拍摄",
                true);
        capture.setTextSize(TS_EMPHASIS);
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
        updateImmersiveExposureText();

        LinearLayout parameterBar = new LinearLayout(this);
        parameterBar.setOrientation(LinearLayout.HORIZONTAL);
        parameterBar.setGravity(Gravity.CENTER);
        if (monitoring) {
            parameterBar.addView(immersiveParameterStepper(monitorShutterAngleMode ? "角度" : "快门"));
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
        parameterToggle.setBackground(rounded(HUD_BG_MID, 10, 0));
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
        group.setBackground(rounded(Color.argb(170, 44, 44, 46), 10, 0));
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
        if (!(connected || localCameraConnected)) {
            return "—";
        }
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
            case "编码":
                return "编码\n" + videoCodecLabel(videoCodec);
            case "Log":
            case "N-Log":
                return "Log\n" + videoLogLabel(videoLogProfile);
            default:
                return "ISO\n" + currentIso;
        }
    }

    private void adjustImmersiveParameter(String parameter, int direction) {
        if (!connected || capturing) return;
        if ("角度".equals(parameter) && monitorShutterAngleMode) {
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
        } else if ("快门".equals(parameter) || ("角度".equals(parameter) && !monitorShutterAngleMode)) {
            double[] values = fineShutterValues();
            currentShutterSeconds =
                    adjacentValue(values, currentShutterSeconds, direction);
            applyParameter("videoExposureTime", currentShutterSeconds, "快门速度");
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
        } else if ("编码".equals(parameter)) {
            String[] values = videoCodecValues();
            videoCodec = values[adjacentIndex(values, videoCodec, direction)];
            applyParameter("videoCodec", videoCodec, "视频录制规格");
        } else if ("Log".equals(parameter) || "N-Log".equals(parameter)) {
            String[] values = videoLogValues();
            videoLogProfile = values[adjacentIndex(values, videoLogProfile, direction)];
            nLogEnabled = !"off".equals(videoLogProfile);
            applyParameter("videoLog", videoLogProfile, "Log / Picture Profile");
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
            case "编码": return "videoCodec";
            case "Log":
            case "N-Log": return "videoLog";
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
        boolean live = connected || localCameraConnected;
        immersiveExposureText.setText(
                live
                        ? (immersiveMonitoring
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
                                        currentIso))
                        : "—");
    }

    private View buildMonitorParameterControls() {
        LinearLayout panel = panel();
        panel.addView(text("参数调节", TS_TITLE, Typeface.BOLD, Color.WHITE)); // v1.5.7 issue 655a0a14: 视频页面板标题改纯白
        panel.addView(text(
                connected
                        ? "曝光三要素通过 USB/PTP 写入 " + connectedCameraName
                        : "连接 Nikon 相机后启用参数控制",
                13,
                Typeface.NORMAL,
                Color.WHITE), // v1.5.7 issue 655a0a14: 视频页说明改纯白
                marginParams(-1, -2, 0, 3, 0, 14));

        addVideoFrameRateControl(panel);
        addSpinnerControl(
                panel,
                "视频曝光模式",
                new String[]{"P 程序自动", "S 快门优先", "A 光圈优先", "M 手动"},
                new Object[]{"program", "shutterPriority", "aperturePriority", "manual"},
                exposureModeIndex(),
                "exposureMode");
        panel.addView(text("视频快门表示", 13, Typeface.NORMAL, Color.WHITE)); // v1.5.7 issue 655a0a14: 视频页标签改纯白
        Spinner representation = monitorSpinner(new String[]{"快门角度", "快门速度"});
        representation.setSelection(monitorShutterAngleMode ? 0 : 1, false);
        representation.setOnItemSelectedListener(new android.widget.AdapterView.OnItemSelectedListener() {
            private boolean initialized;
            @Override public void onItemSelected(android.widget.AdapterView<?> parent, View view, int position, long id) {
                if (!initialized) { initialized = true; return; }
                monitorShutterAngleMode = position == 0;
                showSection(currentSection);
            }
            @Override public void onNothingSelected(android.widget.AdapterView<?> parent) {}
        });
        panel.addView(representation, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(48)));
        addShutterAngleControl(panel);
        addSpinnerControl(
                panel,
                "视频录制规格",
                videoCodecLabels(),
                videoCodecValues(),
                videoCodecIndex(),
                "videoCodec");
        addSpinnerControl(
                panel,
                "Log / Picture Profile",
                videoLogLabels(),
                videoLogValues(),
                videoLogIndex(),
                "videoLog");
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

        TextView compensationLabel = text("曝光补偿 · 0.0 EV", 13, Typeface.BOLD, Color.WHITE); // v1.5.7 issue 655a0a14: 视频页读数改纯白
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
        panel.addView(text("监看输出", TS_TITLE, Typeface.BOLD, Color.WHITE)); // v1.5.7 issue 655a0a14: 视频页面板标题改纯白
        panel.addView(text(
                "本地显示处理不改变相机的视频录制设定。",
                13,
                Typeface.NORMAL,
                Color.WHITE), // v1.5.7 issue 655a0a14: 视频页说明改纯白
                marginParams(-1, -2, 0, 3, 0, 12));

        Switch externalRecording = new Switch(this);
        externalRecording.setText(tr("外录到当前智能设备"));
        externalRecording.setChecked(externalRecordToDevice);
        externalRecording.setEnabled(!videoRecording);
        externalRecording.setOnCheckedChangeListener((button, enabled) -> {
            externalRecordToDevice = enabled;
            getSharedPreferences("nikon-link", MODE_PRIVATE)
                    .edit()
                    .putBoolean("externalRecordToDevice", enabled)
                    .apply();
            showToast(enabled
                    ? "外录已开启 · 视频将写入 ZENCHE 文件库"
                    : "外录已关闭 · PTP 相机仅记录到机身存储卡");
        });
        panel.addView(externalRecording);
        panel.addView(text(
                "外录使用实时取景生成无声 Motion‑JPEG AVI，可与机身录制并行；照片始终直接写入当前设备。",
                TS_BODY,
                Typeface.NORMAL,
                Color.WHITE), // v1.5.7 issue 655a0a14: 视频页说明改纯白
                marginParams(-1, -2, 0, 4, 0, 10));

        panel.addView(
                text("实时取景格式", 13, Typeface.BOLD, Color.WHITE), // v1.5.7 issue 655a0a14: 视频页标签改纯白
                marginParams(-1, -2, 0, 12, 0, 4));
        Spinner codec = monitorSpinner(new String[]{"JPEG（相机输出）"});
        codec.setEnabled(false);
        codec.setAlpha(0.56f);
        panel.addView(codec, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(48)));

        panel.addView(
                text("监看显示尺寸", 13, Typeface.BOLD, Color.WHITE), // v1.5.7 issue 655a0a14: 视频页标签改纯白
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
            }

            @Override public void onNothingSelected(android.widget.AdapterView<?> parent) {}
        });
        panel.addView(profile, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(48)));

        panel.addView(text(
                "Nikon PTP 返回 JPEG 实时取景帧。显示尺寸仅处理监看画面，不等同于机身的“视频文件类型”或“画面尺寸/帧频”。",
                TS_BODY,
                Typeface.NORMAL,
                Color.WHITE), // v1.5.7 issue 655a0a14: 视频页说明改纯白
                marginParams(-1, -2, 0, 10, 0, 0));
        addProfessionalMonitorControls(panel);
        addZebraControls(panel);
        addLutControls(panel);
        return panel;
    }

    private void addProfessionalMonitorControls(LinearLayout panel) {
        Switch peaking = new Switch(this);
        peaking.setText(tr("峰值对焦"));
        peaking.setTextColor(Color.WHITE); // v1.5.7 issue 655a0a14: 视频页面板开关文字改纯白
        peaking.setChecked(focusPeakingEnabled);
        peaking.setOnCheckedChangeListener((button, enabled) -> {
            focusPeakingEnabled = enabled;
            refreshPreviewProcessing();
        });
        panel.addView(peaking, marginParams(-1, -2, 0, 12, 0, 0));

        Switch falseColor = new Switch(this);
        falseColor.setText(tr("假色曝光"));
        falseColor.setTextColor(Color.WHITE); // v1.5.7 issue 655a0a14: 视频页面板开关文字改纯白
        falseColor.setChecked(falseColorEnabled);
        falseColor.setOnCheckedChangeListener((button, enabled) -> {
            falseColorEnabled = enabled;
            refreshPreviewProcessing();
        });
        panel.addView(falseColor);

        LinearLayout scopes = verticalContainer();
        scopes.setPadding(dp(4), dp(4), dp(4), dp(6));
        scopes.setBackgroundColor(Color.BLACK);
        professionalScopeView = new WaveformScopeView(WaveformScopeView.RGB_PARADE);
        professionalScopeView.setData(
                redHistogram, greenHistogram, blueHistogram);
        peakingCoverageText = text(
                "峰值覆盖 · " + peakingCoverage + "%",
                TS_CAPTION,
                Typeface.NORMAL,
                WHITE_LO);
        peakingCoverageText.setTypeface(Typeface.MONOSPACE);
        scopes.addView(
                professionalScopeView,
                new LinearLayout.LayoutParams(-1, dp(190)));
        scopes.addView(
                peakingCoverageText,
                marginParams(-1, -2, 0, 6, 0, 0));
        panel.addView(scopes, marginParams(-1, -2, 0, 10, 0, 0));
    }

    private View buildCaptureSessionPanel() {
        LinearLayout panel = panel();
        panel.addView(text("拍摄会话", TS_TITLE, Typeface.BOLD, INK));
        panel.addView(
                text(captureWorkflow.status(), TS_BODY, Typeface.NORMAL, MUTED),
                marginParams(-1, -2, 0, 5, 0, 8));
        panel.addView(text(
                "项目文件夹 · 命名模板 · RAW + JPEG 配对 · XMP 评级 · 双目标备份 · SHA-256",
                TS_BODY,
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
                TS_CAPTION,
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
        input.setBackground(rounded(FIELD_BG, 9, RULE));
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
        spinner.setBackground(rounded(FIELD_BG, 9, RULE));
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
                text("视频帧率基准", 13, Typeface.BOLD, Color.WHITE), // v1.5.7 issue 655a0a14: 视频页标签改纯白
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
                (monitorShutterAngleMode ? "快门角度 · 按 " : "快门速度 · ")
                        + monitorFrameRate + "p",
                13,
                Typeface.BOLD,
                Color.WHITE); // v1.5.7 issue 655a0a14: 视频页标签改纯白
        label.setTag("快门角度");
        parent.addView(label, marginParams(-1, -2, 0, 12, 0, 4));
        Double[] angles = new Double[]{45.0, 90.0, 144.0, 172.8, 180.0, 270.0, 360.0};
        String[] labels = monitorShutterAngleMode
                ? new String[]{"45°", "90°", "144°", "172.8°", "180°", "270°", "360°"}
                : shutterLabels();
        Spinner spinner = monitorSpinner(labels);
        int selection = 4;
        for (int index = 0; index < angles.length && monitorShutterAngleMode; index++) {
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
                if (monitorShutterAngleMode) {
                    monitorShutterAngle = angles[position];
                } else {
                    currentShutterSeconds = fineShutterValues()[position];
                }
                getSharedPreferences("nikon-link", MODE_PRIVATE)
                        .edit()
                        .putLong(
                                "monitorShutterAngle",
                                Double.doubleToRawLongBits(monitorShutterAngle))
                        .apply();
                if (monitorShutterAngleMode) applyVideoShutterAngle();
                else applyParameter("videoExposureTime", currentShutterSeconds, "快门速度");
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

    private int videoCodecIndex() {
        String[] values = videoCodecValues();
        for (int index = 0; index < values.length; index++) {
            if (values[index].equals(videoCodec)) return index;
        }
        videoCodec = values[0];
        return 0;
    }

    private String videoCodecLabel(String codec) {
        String[] values = videoCodecValues();
        String[] labels = videoCodecLabels();
        for (int index = 0; index < values.length; index++) {
            if (values[index].equals(codec)) return labels[index];
        }
        return codec;
    }

    // v1.5.7 P2: 读数轨短标签（对齐 macOS MonitorReadout shortLabel 口径）。
    private String videoCodecShortLabel(String codec) {
        switch (codec) {
            case "h264": return "H.264";
            case "h265": return "H.265";
            case "prores422hq": return "ProRes 422 HQ";
            case "proresRaw": return "ProRes RAW";
            case "nraw": return "N-RAW";
            case "sonyXavcHs8k": return "XAVC HS 8K";
            case "sonyXavcHs4k": return "XAVC HS 4K";
            case "sonyXavcS4k": return "XAVC S 4K";
            case "sonyXavcSHd": return "XAVC S HD";
            case "sonyXavcSi4k": return "XAVC S-I 4K";
            case "sonyXavcSiHd": return "XAVC S-I HD";
            case "canonRaw": return "RAW";
            case "canonXfHevc422":
            case "canonXfHevc420": return "XF-HEVC S";
            case "canonXfAvc422":
            case "canonXfAvc420": return "XF-AVC S";
            default: return codec;
        }
    }

    private String[] videoCodecValues() {
        if ("Sony".equals(connectedCameraVendor)) {
            return new String[]{
                    "sonyXavcHs8k", "sonyXavcHs4k", "sonyXavcS4k",
                    "sonyXavcSHd", "sonyXavcSi4k", "sonyXavcSiHd"};
        }
        if ("Canon".equals(connectedCameraVendor)) {
            return new String[]{
                    "canonRaw", "canonXfHevc422", "canonXfHevc420",
                    "canonXfAvc422", "canonXfAvc420"};
        }
        return new String[]{"h264", "h265", "prores422hq", "proresRaw", "nraw"};
    }

    private String[] videoCodecLabels() {
        if ("Sony".equals(connectedCameraVendor)) {
            return new String[]{
                    "XAVC HS 8K · HEVC Long GOP",
                    "XAVC HS 4K · HEVC Long GOP",
                    "XAVC S 4K · AVC Long GOP",
                    "XAVC S HD · AVC Long GOP",
                    "XAVC S-I 4K · AVC Intra",
                    "XAVC S-I HD · AVC Intra"};
        }
        if ("Canon".equals(connectedCameraVendor)) {
            return new String[]{
                    "RAW · 12-bit",
                    "XF-HEVC S · 4:2:2 10-bit",
                    "XF-HEVC S · 4:2:0 10-bit",
                    "XF-AVC S · 4:2:2 10-bit",
                    "XF-AVC S · 4:2:0 8-bit"};
        }
        return new String[]{
                "H.264 / AVC · 8-bit",
                "H.265 / HEVC · 10-bit",
                "Apple ProRes 422 HQ · 10-bit",
                "Apple ProRes RAW HQ · 12-bit",
                "N-RAW · 12-bit NEV"};
    }

    private String[] videoLogValues() {
        if ("Sony".equals(connectedCameraVendor)) {
            return new String[]{
                    "off", "sonySLog2", "sonySLog3Cine", "sonySLog3", "sonyHlg"};
        }
        if ("Canon".equals(connectedCameraVendor)) {
            return new String[]{"off", "canonLog", "canonLog2", "canonLog3"};
        }
        return new String[]{"off", "nlog"};
    }

    private String[] videoLogLabels() {
        if ("Sony".equals(connectedCameraVendor)) {
            return new String[]{
                    "关闭 · SDR",
                    "PP7 · S-Log2",
                    "PP8 · S-Log3 / S-Gamut3.Cine",
                    "PP9 · S-Log3 / S-Gamut3",
                    "PP10 · HLG"};
        }
        if ("Canon".equals(connectedCameraVendor)) {
            return new String[]{"关闭 · SDR", "Canon Log", "Canon Log 2", "Canon Log 3"};
        }
        return new String[]{"关闭 · SDR", "N-Log"};
    }

    private int videoLogIndex() {
        String[] values = videoLogValues();
        for (int index = 0; index < values.length; index++) {
            if (values[index].equals(videoLogProfile)) return index;
        }
        videoLogProfile = "off";
        nLogEnabled = false;
        return 0;
    }

    private String videoLogLabel(String value) {
        String[] values = videoLogValues();
        String[] labels = videoLogLabels();
        for (int index = 0; index < values.length; index++) {
            if (values[index].equals(value)) return labels[index];
        }
        return value;
    }

    private View buildProfessionalControls() {
        LinearLayout panel = panel();
        panel.addView(text("拍摄控制", TS_TITLE, Typeface.BOLD, INK));
        panel.addView(text(
                connected
                        ? "参数通过 USB/PTP 写入 " + connectedCameraName
                        : "连接相机后启用原生参数控制",
                13,
                Typeface.NORMAL,
                MUTED),
                marginParams(-1, -2, 0, 3, 0, 14));

        addParameterGroupHeading(
                panel,
                "曝光",
                "模式决定快门、光圈与曝光补偿的可调范围");
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
                "B门曝光时长（由应用控制）",
                new String[]{"1 秒", "2 秒", "5 秒", "10 秒", "30 秒", "60 秒"},
                new Object[]{1, 2, 5, 10, 30, 60},
                2,
                "bulbDuration");
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

        addParameterGroupHeading(
                panel,
                "对焦与色彩",
                "对焦、白平衡与优化校准按相机能力启用");
        addSpinnerControl(
                panel,
                "对焦模式",
                new String[]{"AF-S 单次AF", "AF-C 连续AF", "MF 手动对焦"},
                new Object[]{"single-shot", "continuous", "manual"},
                0,
                "focusMode");
        addSpinnerControl(
                panel,
                "白平衡",
                new String[]{"自动", "预设手动"},
                new Object[]{"continuous", "manual"},
                0,
                "whiteBalanceMode");
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

        updateCameraControls();
        return panel;
    }

    private void addParameterGroupHeading(
            LinearLayout parent,
            String title,
            String detail) {
        View divider = new View(this);
        divider.setBackgroundColor(RULE);
        parent.addView(divider, marginParams(-1, dp(1), 0, 18, 0, 16));
        parent.addView(text(title, TS_EMPHASIS, Typeface.BOLD, INK));
        parent.addView(
                text(detail, TS_BODY, Typeface.NORMAL, MUTED),
                marginParams(-1, -2, 0, 3, 0, 10));
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
        // v1.5.7 issue 655a0a14: 视频页参数面板标签恒白字；拍照页仍用 MUTED
        int labelColor = "monitor".equals(currentSection) ? Color.WHITE : MUTED;
        TextView labelView = text(label, 13, Typeface.BOLD, labelColor);
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
        spinner.setBackground(rounded(FIELD_BG, 9, RULE));
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
        TextView title = text("条纹图案（本地）", 13, Typeface.BOLD, Color.WHITE); // v1.5.7 issue 655a0a14: 视频页标签改纯白
        parent.addView(title, marginParams(-1, -2, 0, 12, 0, 4));

        Switch enabled = new Switch(this);
        enabled.setText(tr("加亮显示"));
        enabled.setTextColor(Color.WHITE); // v1.5.7 issue 655a0a14: 视频页面板开关文字改纯白
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
                TS_BODY,
                Typeface.NORMAL,
                Color.WHITE); // v1.5.7 issue 655a0a14: 视频页读数改纯白
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
                text("监看 LUT（本地）", 13, Typeface.BOLD, Color.WHITE), // v1.5.7 issue 655a0a14: 视频页标签改纯白
                marginParams(-1, -2, 0, 12, 0, 4));

        lutSwitch = new Switch(this);
        lutSwitch.setText(tr("应用到实时取景"));
        lutSwitch.setTextColor(Color.WHITE); // v1.5.7 issue 655a0a14: 视频页面板开关文字改纯白
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
                TS_BODY,
                Typeface.NORMAL,
                Color.WHITE); // v1.5.7 issue 655a0a14: 视频页说明改纯白
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
                LIBRARY_FS_WORKBENCH,
                Typeface.BOLD,
                INK));
        branchHero.addView(text(
                "长按文件并拖到任意分支；拖回“未分类”即可移出分支。",
                LIBRARY_FS_SUB,
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

        content.addView(collapsibleGroup(
                "wireless-transfer",
                "无线传输",
                (wifiConnected ? "Wi‑Fi 已连接" : "Wi‑Fi 未连接")
                        + " · "
                        + (wirelessRequested ? wirelessStatus : "收件箱已停止"),
                buildWirelessTransferPanel(),
                true));

        content.addView(buildCameraStoragePanel());

        LinearLayout timelapseActions = new LinearLayout(this);
        timelapseActions.setOrientation(LinearLayout.HORIZONTAL);
        Button timelapseButton = nativeButton("合成延时视频", true);
        timelapseButton.setOnClickListener(view -> showComposeTimelapseDialog());
        Button focusStackButton = nativeButton("焦点合成", true);
        focusStackButton.setOnClickListener(view -> showComposeFocusStackDialog());
        timelapseActions.addView(
                timelapseButton,
                new LinearLayout.LayoutParams(0, dp(48), 1f));
        timelapseActions.addView(
                focusStackButton,
                new LinearLayout.LayoutParams(0, dp(48), 1f));
        content.addView(
                timelapseActions,
                marginParams(-1, dp(48), 0, 0, 0, 12));

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
                        TS_BODY,
                        Typeface.NORMAL,
                        MUTED),
                marginParams(-1, -2, 0, 0, 0, 16));
        LinearLayout systemBody = verticalContainer();
        if (!hasAlbumAccess()) {
            TextView permission = text(
                    "允许照片和视频访问后，最近媒体会在这里直接显示，无需先导入。",
                    LIBRARY_FS_TITLE,
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
                    LIBRARY_FS_TITLE,
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

        scroll.addView(content);
        return scroll;
    }

    /** E6 延时合成：文件库入口。帧多选（按文件名排序）+ 帧率 24/25/30
     *  → TimelapseComposer（MediaCodec H.264 MP4）→ CaptureWorkflow 入库。
     *  TBC-awaiting-hardware。 */
    private void showComposeTimelapseDialog() {
        if (isFinishing() || isDestroyed()) return;
        final List<File> frames = timelapseFrameFiles();
        if (frames.isEmpty()) {
            showToast("文件库暂无照片，请先拍摄或导入。");
            return;
        }
        LinearLayout panel = verticalContainer();
        panel.setPadding(dp(20), dp(18), dp(20), dp(14));
        panel.addView(text(
                "合成延时视频",
                LIBRARY_FS_WORKBENCH,
                Typeface.BOLD,
                INK));
        panel.addView(text(
                "选择序列帧（按文件名排序合成）并设置帧率。损坏帧自动跳过。",
                TS_BODY,
                Typeface.NORMAL,
                MUTED),
                marginParams(-1, -2, 0, 2, 0, 10));

        final List<CheckBox> checkboxes = new ArrayList<>();
        LinearLayout listPanel = verticalContainer();
        for (File frame : frames) {
            CheckBox check = new CheckBox(this);
            check.setText(frame.getName());
            check.setTextSize(13);
            check.setTextColor(INK);
            check.setPadding(dp(2), dp(2), dp(2), dp(2));
            checkboxes.add(check);
            listPanel.addView(check, new LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT));
        }
        ScrollView listScroll = new ScrollView(this);
        listScroll.addView(listPanel, new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT));
        listScroll.setBackground(rounded(SURFACE, 12, RULE_STRONG));
        panel.addView(listScroll, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(240)));

        final int[] frameRates = new int[]{24, 25, 30};
        String[] rateLabels = new String[]{"24 fps", "25 fps", "30 fps"};
        Spinner rateSpinner = new Spinner(this);
        ArrayAdapter<String> rateAdapter = new ArrayAdapter<>(
                this,
                android.R.layout.simple_spinner_item,
                rateLabels);
        rateAdapter.setDropDownViewResource(
                android.R.layout.simple_spinner_dropdown_item);
        rateSpinner.setAdapter(rateAdapter);
        rateSpinner.setSelection(0, false);
        rateSpinner.setBackground(rounded(FIELD_BG, 9, RULE));
        rateSpinner.setPadding(dp(10), 0, dp(8), 0);
        LinearLayout rateRow = new LinearLayout(this);
        rateRow.setOrientation(LinearLayout.HORIZONTAL);
        rateRow.setGravity(Gravity.CENTER_VERTICAL);
        rateRow.addView(text(
                "帧率：",
                TS_BODY,
                Typeface.NORMAL,
                MUTED));
        rateRow.addView(rateSpinner, new LinearLayout.LayoutParams(
                dp(140), dp(44)));
        panel.addView(rateRow, marginParams(-1, -2, 0, 10, 0, 6));

        final ProgressBar progress = new ProgressBar(
                this,
                null,
                android.R.attr.progressBarStyleHorizontal);
        progress.setMax(100);
        progress.setVisibility(View.GONE);
        panel.addView(progress, marginParams(-1, dp(18), 0, 10, 0, 4));
        final TextView progressText = text(
                "",
                TS_BODY,
                Typeface.NORMAL,
                MUTED);
        progressText.setVisibility(View.GONE);
        panel.addView(progressText, marginParams(-1, -2, 0, 0, 0, 4));
        final TextView resultText = text(
                "",
                TS_BODY,
                Typeface.BOLD,
                INK);
        resultText.setVisibility(View.GONE);
        panel.addView(resultText, marginParams(-1, -2, 0, 6, 0, 0));

        final AtomicBoolean cancelled = new AtomicBoolean(false);
        final AtomicBoolean running = new AtomicBoolean(false);
        Button startButton = nativeButton("开始合成", true);
        startButton.setOnClickListener(view -> {
            if (running.get()) return;
            final List<File> selected = new ArrayList<>();
            for (int i = 0; i < checkboxes.size(); i++) {
                if (checkboxes.get(i).isChecked()) {
                    selected.add(frames.get(i));
                }
            }
            if (selected.isEmpty()) {
                showToast("请至少选择一帧。");
                return;
            }
            running.set(true);
            cancelled.set(false);
            startButton.setEnabled(false);
            progress.setVisibility(View.VISIBLE);
            progress.setProgress(0);
            progressText.setVisibility(View.VISIBLE);
            progressText.setText("0/" + selected.size());
            resultText.setVisibility(View.GONE);
            final int fps = frameRates[rateSpinner.getSelectedItemPosition()];
            final File temporary = new File(
                    getCacheDir(),
                    "timelapse-" + System.nanoTime() + ".mp4");
            composeExecutor.execute(() -> {
                try {
                    TimelapseComposer composer = new TimelapseComposer();
                    TimelapseComposer.Result composed = composer.compose(
                            selected,
                            temporary,
                            new TimelapseComposer.Options(fps),
                            cancelled::get,
                            (done, total) -> runOnUiThread(() -> {
                                progress.setMax(Math.max(1, total));
                                progress.setProgress(done);
                                progressText.setText(done + "/" + total);
                            }));
                    final File destination =
                            captureWorkflow.storeTimelapseVideo(
                                    temporary,
                                    "延时合成");
                    runOnUiThread(() -> {
                        progress.setVisibility(View.GONE);
                        progressText.setVisibility(View.GONE);
                        resultText.setVisibility(View.VISIBLE);
                        resultText.setText(
                                "已合成 " + composed.framesWritten + " 帧"
                                        + (composed.skippedFrames > 0
                                                ? "（跳过 "
                                                        + composed.skippedFrames
                                                        + " 个损坏帧）"
                                                : "")
                                        + " → " + destination.getName());
                        startButton.setEnabled(true);
                        running.set(false);
                    });
                    showSection("library");
                } catch (CancellationException error) {
                    runOnUiThread(() -> {
                        progress.setVisibility(View.GONE);
                        progressText.setVisibility(View.GONE);
                        resultText.setVisibility(View.VISIBLE);
                        resultText.setTextColor(VIDEO);
                        resultText.setText("已取消");
                        startButton.setEnabled(true);
                        running.set(false);
                    });
                } catch (Exception error) {
                    runOnUiThread(() -> {
                        progress.setVisibility(View.GONE);
                        progressText.setVisibility(View.GONE);
                        resultText.setVisibility(View.VISIBLE);
                        resultText.setTextColor(VIDEO);
                        resultText.setText(
                                "视频编码失败：" + error.getMessage());
                        startButton.setEnabled(true);
                        running.set(false);
                    });
                } finally {
                    if (temporary.exists()) temporary.delete();
                }
            });
        });
        panel.addView(startButton, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(48)));

        new AlertDialog.Builder(this)
                .setTitle("帧澈 ZENCHE · 合成延时视频")
                .setView(panel)
                .setNegativeButton("取消", (dialog, which) ->
                        cancelled.set(true))
                .show();
    }


    /** E7：焦点合成对话框——帧多选（按文件名排序）+ 进度/取消 + 结果/错误。 */
    private void showComposeFocusStackDialog() {
        if (isFinishing() || isDestroyed()) return;
        final List<File> frames = timelapseFrameFiles();
        if (frames.size() < 2) {
            showToast("文件库照片不足（焦点合成需要至少两帧）。");
            return;
        }
        LinearLayout panel = verticalContainer();
        panel.setPadding(dp(20), dp(18), dp(20), dp(14));
        panel.addView(text(
                "焦点合成",
                LIBRARY_FS_WORKBENCH,
                Typeface.BOLD,
                INK));
        panel.addView(text(
                "选择焦点包围序列帧（按文件名排序合成，逐像素取最清晰帧融合）。损坏帧自动跳过。",
                TS_BODY,
                Typeface.NORMAL,
                MUTED),
                marginParams(-1, -2, 0, 2, 0, 10));

        final List<CheckBox> checkboxes = new ArrayList<>();
        LinearLayout listPanel = verticalContainer();
        for (File frame : frames) {
            CheckBox check = new CheckBox(this);
            check.setText(frame.getName());
            check.setTextSize(13);
            check.setTextColor(INK);
            check.setPadding(dp(2), dp(2), dp(2), dp(2));
            checkboxes.add(check);
            listPanel.addView(check, new LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT));
        }
        ScrollView listScroll = new ScrollView(this);
        listScroll.addView(listPanel, new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT));
        listScroll.setBackground(rounded(SURFACE, 12, RULE_STRONG));
        panel.addView(listScroll, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(240)));

        final ProgressBar progress = new ProgressBar(
                this,
                null,
                android.R.attr.progressBarStyleHorizontal);
        progress.setMax(100);
        progress.setVisibility(View.GONE);
        panel.addView(progress, marginParams(-1, dp(18), 0, 10, 0, 4));
        final TextView progressText = text(
                "",
                TS_BODY,
                Typeface.NORMAL,
                MUTED);
        progressText.setVisibility(View.GONE);
        panel.addView(progressText);
        final TextView resultText = text(
                "",
                TS_BODY,
                Typeface.NORMAL,
                POSITIVE);
        resultText.setVisibility(View.GONE);
        panel.addView(resultText);
        final TextView errorText = text(
                "",
                TS_BODY,
                Typeface.NORMAL,
                VIDEO);
        errorText.setVisibility(View.GONE);
        panel.addView(errorText);

        final AtomicBoolean cancelled = new AtomicBoolean(false);
        final AtomicBoolean running = new AtomicBoolean(false);
        final Button startButton = nativeButton("开始合成", true);
        startButton.setOnClickListener(view -> {
            if (running.get()) return;
            final List<File> selected = new ArrayList<>();
            for (int i = 0; i < checkboxes.size(); i++) {
                if (checkboxes.get(i).isChecked()) {
                    selected.add(frames.get(i));
                }
            }
            if (selected.size() < 2) {
                errorText.setVisibility(View.VISIBLE);
                errorText.setText("焦点合成需要至少选择两帧。");
                return;
            }
            running.set(true);
            startButton.setEnabled(false);
            cancelled.set(false);
            errorText.setVisibility(View.GONE);
            resultText.setVisibility(View.GONE);
            progress.setVisibility(View.VISIBLE);
            progress.setProgress(0);
            progressText.setVisibility(View.VISIBLE);
            progressText.setText("0/" + selected.size());
            final File temporary = new File(
                    getCacheDir(),
                    "focusstack-" + System.nanoTime() + ".jpg");
            composeExecutor.execute(() -> {
                try {
                    FocusStackComposer composer = new FocusStackComposer();
                    FocusStackComposer.Result composed = composer.compose(
                            selected,
                            temporary,
                            cancelled::get,
                            (done, total) -> runOnUiThread(() -> {
                                progress.setMax(Math.max(1, total));
                                progress.setProgress(done);
                                progressText.setText(done + "/" + total);
                            }));
                    final File destination =
                            captureWorkflow.storeFocusStack(
                                    temporary,
                                    "焦点合成",
                                    composed.sourcesUsed);
                    runOnUiThread(() -> {
                        progress.setVisibility(View.GONE);
                        progressText.setVisibility(View.GONE);
                        resultText.setVisibility(View.VISIBLE);
                        resultText.setText(
                                "已合成 " + composed.sourcesUsed + " 帧"
                                        + (composed.skippedFrames > 0
                                                ? "（跳过 "
                                                        + composed.skippedFrames
                                                        + " 个损坏帧）"
                                                : "")
                                        + " → " + destination.getName());
                        startButton.setEnabled(true);
                        running.set(false);
                    });
                    showSection("library");
                } catch (CancellationException error) {
                    runOnUiThread(() -> {
                        progress.setVisibility(View.GONE);
                        progressText.setVisibility(View.GONE);
                        resultText.setVisibility(View.VISIBLE);
                        resultText.setTextColor(VIDEO);
                        resultText.setText("已取消");
                        startButton.setEnabled(true);
                        running.set(false);
                    });
                } catch (Exception error) {
                    runOnUiThread(() -> {
                        progress.setVisibility(View.GONE);
                        progressText.setVisibility(View.GONE);
                        resultText.setVisibility(View.VISIBLE);
                        resultText.setTextColor(VIDEO);
                        resultText.setText(
                                "焦点合成失败：" + error.getMessage());
                        startButton.setEnabled(true);
                        running.set(false);
                    });
                } finally {
                    if (temporary.exists()) temporary.delete();
                }
            });
        });
        panel.addView(startButton, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(48)));

        new AlertDialog.Builder(this)
                .setTitle("帧澈 ZENCHE · 焦点合成")
                .setView(panel)
                .setNegativeButton("取消", (dialog, which) ->
                        cancelled.set(true))
                .show();
    }

    /** E6：文件库内可作延时序列帧的照片（非视频 + 图片扩展名，按文件名排序）。 */
    private List<File> timelapseFrameFiles() {
        List<File> result = new ArrayList<>();
        for (File file : photoFiles()) {
            String lower = file.getName().toLowerCase(Locale.ROOT);
            if (lower.endsWith(".jpg") || lower.endsWith(".jpeg")
                    || lower.endsWith(".png") || lower.endsWith(".heic")
                    || lower.endsWith(".heif") || lower.endsWith(".tif")
                    || lower.endsWith(".tiff") || lower.endsWith(".bmp")) {
                result.add(file);
            }
        }
        result.sort((left, right) ->
                left.getName().compareToIgnoreCase(right.getName()));
        return result;
    }

    private View buildCameraStoragePanel() {
        LinearLayout body = verticalContainer();
        CameraStorage.Snapshot snapshot = cameraStorageSnapshot;
        boolean available = camera != null && camera.isConnected()
                || wifiCamera != null && wifiCamera.isConnected();
        long capacity = snapshot.capacityBytes();
        long free = snapshot.freeBytes();
        String capacityText = capacity > 0
                ? formatStorageBytes(Math.max(0, capacity - free))
                        + " 已用 / " + formatStorageBytes(capacity)
                : cameraStorageStatus;
        TextView summary = text(
                capacityText,
                LIBRARY_FS_SUB,
                Typeface.BOLD,
                available ? INK : MUTED);
        body.addView(summary, marginParams(-1, -2, 0, 2, 0, 10));

        LinearLayout primaryActions = new LinearLayout(this);
        primaryActions.setOrientation(LinearLayout.HORIZONTAL);
        Button refresh = nativeButton(
                cameraStorageLoading ? "正在读取…" : "刷新机内文件",
                true);
        refresh.setEnabled(available && !cameraStorageLoading);
        refresh.setOnClickListener(view -> refreshCameraStorage());
        primaryActions.addView(refresh, new LinearLayout.LayoutParams(0, dp(48), 1f));
        Button selectAll = nativeButton(
                selectedCameraStorageHandles.size() == snapshot.items.size()
                        && !snapshot.items.isEmpty() ? "取消全选" : "全选",
                false);
        selectAll.setEnabled(!snapshot.items.isEmpty() && !cameraStorageLoading);
        selectAll.setOnClickListener(view -> {
            if (selectedCameraStorageHandles.size() == snapshot.items.size()) {
                selectedCameraStorageHandles.clear();
            } else {
                selectedCameraStorageHandles.clear();
                for (CameraStorage.Item item : snapshot.items) {
                    if (!item.protectedObject) selectedCameraStorageHandles.add(item.handle);
                }
            }
            showSection("library");
        });
        LinearLayout.LayoutParams selectParams = new LinearLayout.LayoutParams(0, dp(48), 1f);
        selectParams.setMargins(dp(8), 0, 0, 0);
        primaryActions.addView(selectAll, selectParams);
        body.addView(primaryActions);

        LinearLayout batchActions = new LinearLayout(this);
        batchActions.setOrientation(LinearLayout.HORIZONTAL);
        Button download = nativeButton("下载所选", true);
        download.setEnabled(!snapshot.items.isEmpty() && !cameraStorageLoading);
        download.setOnClickListener(view -> downloadSelectedCameraStorage());
        batchActions.addView(download, new LinearLayout.LayoutParams(0, dp(48), 1f));
        Button delete = nativeButton("从相机删除", false);
        delete.setTextColor(VIDEO);
        delete.setEnabled(!snapshot.items.isEmpty() && !cameraStorageLoading);
        delete.setOnClickListener(view -> confirmDeleteSelectedCameraStorage());
        LinearLayout.LayoutParams deleteParams = new LinearLayout.LayoutParams(0, dp(48), 1f);
        deleteParams.setMargins(dp(8), 0, 0, 0);
        batchActions.addView(delete, deleteParams);
        body.addView(batchActions, marginParams(-1, dp(48), 0, 8, 0, 12));

        if (!available) {
            body.addView(emptyStorageText(
                    "请先连接 USB/PTP 或 Wi‑Fi/PTP‑IP 相机。系统摄像头不开放机内存储。"));
        } else if (cameraStorageLoading && snapshot.items.isEmpty()) {
            body.addView(emptyStorageText("正在读取存储卷与文件信息…"));
        } else if (snapshot.items.isEmpty()) {
            body.addView(emptyStorageText(
                    "暂无机内文件。点击“刷新机内文件”读取相机存储卡。"));
        } else {
            int thumbnailBudget = 40;
            for (CameraStorage.Item item : snapshot.items) {
                body.addView(cameraStorageRow(item, thumbnailBudget-- > 0));
            }
        }
        return collapsibleGroup(
                "camera-internal-storage",
                "相机机内存储",
                snapshot.items.size() + " 个文件 · " + cameraStorageStatus,
                body,
                true);
    }

    private TextView emptyStorageText(String value) {
        TextView empty = text(value, LIBRARY_FS_SUB, Typeface.NORMAL, MUTED);
        empty.setGravity(Gravity.CENTER);
        empty.setPadding(dp(16), dp(24), dp(16), dp(24));
        return empty;
    }

    private View cameraStorageRow(CameraStorage.Item item, boolean requestThumbnail) {
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(Gravity.CENTER_VERTICAL);
        row.setPadding(dp(6), dp(7), dp(6), dp(7));
        CheckBox selected = new CheckBox(this);
        selected.setChecked(selectedCameraStorageHandles.contains(item.handle));
        selected.setEnabled(!item.protectedObject && !cameraStorageLoading);
        selected.setContentDescription(tr("选择") + " " + item.filename);
        selected.setOnCheckedChangeListener((button, checked) -> {
            if (checked) selectedCameraStorageHandles.add(item.handle);
            else selectedCameraStorageHandles.remove(item.handle);
        });
        row.addView(selected, new LinearLayout.LayoutParams(dp(48), dp(48)));

        ImageView thumbnail = new ImageView(this);
        thumbnail.setScaleType(ImageView.ScaleType.CENTER_CROP);
        thumbnail.setBackgroundColor(GRAPHITE);
        thumbnail.setImageResource(item.isVideo()
                ? android.R.drawable.ic_media_play
                : android.R.drawable.ic_menu_gallery);
        row.addView(thumbnail, new LinearLayout.LayoutParams(dp(72), dp(52)));

        LinearLayout copy = verticalContainer();
        copy.setPadding(dp(12), 0, 0, 0);
        copy.addView(text(item.filename, LIBRARY_FS_TITLE, Typeface.BOLD, INK));
        String detail = formatStorageBytes(item.sizeBytes)
                + (item.width > 0 && item.height > 0
                        ? " · " + item.width + " × " + item.height : "")
                + " · " + item.capturedAt
                + (item.protectedObject ? " · 已保护" : "");
        copy.addView(text(detail, TS_CAPTION, Typeface.NORMAL, MUTED));
        row.addView(copy, new LinearLayout.LayoutParams(0, -2, 1f));
        if (requestThumbnail && !item.isVideo()) {
            storageExecutor.submit(() -> {
                try {
                    byte[] bytes = activeStorageThumbnail(item.handle);
                    Bitmap bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.length);
                    if (bitmap != null) mainHandler.post(() -> thumbnail.setImageBitmap(bitmap));
                } catch (Exception ignored) {
                }
            });
        }
        return row;
    }

    private void refreshCameraStorage() {
        if (cameraStorageLoading) return;
        if (!(camera != null && camera.isConnected())
                && !(wifiCamera != null && wifiCamera.isConnected())) {
            showToast("请先连接 USB/PTP 或 Wi‑Fi/PTP‑IP 相机。");
            return;
        }
        cameraStorageLoading = true;
        cameraStorageStatus = "正在读取存储卡…";
        showSection("library");
        storageExecutor.submit(() -> {
            try {
                CameraStorage.Snapshot snapshot = camera != null && camera.isConnected()
                        ? camera.listStorage()
                        : wifiCamera.listStorage();
                mainHandler.post(() -> {
                    cameraStorageSnapshot = snapshot;
                    Set<Long> valid = new HashSet<>();
                    for (CameraStorage.Item item : snapshot.items) valid.add(item.handle);
                    selectedCameraStorageHandles.retainAll(valid);
                    cameraStorageStatus = "读取完成";
                    cameraStorageLoading = false;
                    showSection("library");
                });
            } catch (Exception error) {
                diagnostics.error("camera-storage", "读取机内存储失败：" + error.getMessage());
                mainHandler.post(() -> {
                    cameraStorageLoading = false;
                    cameraStorageStatus = "读取失败 · " + error.getMessage();
                    showSection("library");
                    showError(error.getMessage());
                });
            }
        });
    }

    private byte[] activeStorageThumbnail(long handle) throws Exception {
        return camera != null && camera.isConnected()
                ? camera.getStorageThumbnail(handle)
                : wifiCamera.getStorageThumbnail(handle);
    }

    private byte[] activeStorageObject(long handle) throws Exception {
        return camera != null && camera.isConnected()
                ? camera.downloadStorageObject(handle)
                : wifiCamera.downloadStorageObject(handle);
    }

    private void deleteActiveStorageObject(long handle) throws Exception {
        if (camera != null && camera.isConnected()) camera.deleteStorageObject(handle);
        else wifiCamera.deleteStorageObject(handle);
    }

    private List<CameraStorage.Item> selectedCameraStorageItems() {
        List<CameraStorage.Item> result = new ArrayList<>();
        for (CameraStorage.Item item : cameraStorageSnapshot.items) {
            if (selectedCameraStorageHandles.contains(item.handle)) result.add(item);
        }
        return result;
    }

    private void downloadSelectedCameraStorage() {
        List<CameraStorage.Item> selected = selectedCameraStorageItems();
        if (selected.isEmpty()) {
            showToast("请先选择要下载的机内文件。");
            return;
        }
        cameraStorageLoading = true;
        cameraStorageStatus = "正在下载 0 / " + selected.size();
        showSection("library");
        storageExecutor.submit(() -> {
            try {
                int completed = 0;
                for (CameraStorage.Item item : selected) {
                    byte[] bytes = activeStorageObject(item.handle);
                    captureWorkflow.store(
                            bytes,
                            item.filename,
                            camera != null && camera.isConnected()
                                    ? connectedCameraName : wifiCameraName,
                            null);
                    int progress = ++completed;
                    mainHandler.post(() -> {
                        cameraStorageStatus = "正在下载 " + progress + " / " + selected.size();
                        if (statusText != null) statusText.setText(cameraStorageStatus);
                    });
                }
                mainHandler.post(() -> {
                    cameraStorageLoading = false;
                    cameraStorageStatus = "已下载 " + selected.size() + " 个文件到 ZENCHE 文件库";
                    selectedCameraStorageHandles.clear();
                    showSection("library");
                    updateFileCount();
                });
            } catch (Exception error) {
                diagnostics.error("camera-storage", "下载机内文件失败：" + error.getMessage());
                mainHandler.post(() -> {
                    cameraStorageLoading = false;
                    cameraStorageStatus = "下载失败 · " + error.getMessage();
                    showSection("library");
                    showError(error.getMessage());
                });
            }
        });
    }

    private void confirmDeleteSelectedCameraStorage() {
        List<CameraStorage.Item> selected = selectedCameraStorageItems();
        if (selected.isEmpty()) {
            showToast("请先选择要从相机删除的文件。");
            return;
        }
        new AlertDialog.Builder(this)
                .setTitle(tr("从相机永久删除？"))
                .setMessage(tr("将从相机存储卡永久删除所选 " + selected.size()
                        + " 个文件；此操作无法撤销。已保护文件不会被选择。"))
                .setNegativeButton(tr("取消"), null)
                .setPositiveButton(tr("永久删除"), (dialog, which) -> {
                    cameraStorageLoading = true;
                    cameraStorageStatus = "正在从相机删除…";
                    showSection("library");
                    storageExecutor.submit(() -> {
                        try {
                            for (CameraStorage.Item item : selected) {
                                deleteActiveStorageObject(item.handle);
                            }
                            mainHandler.post(() -> {
                                cameraStorageLoading = false;
                                selectedCameraStorageHandles.clear();
                                cameraStorageStatus = "已从相机删除 " + selected.size() + " 个文件";
                                refreshCameraStorage();
                            });
                        } catch (Exception error) {
                            diagnostics.error("camera-storage", "删除机内文件失败：" + error.getMessage());
                            mainHandler.post(() -> {
                                cameraStorageLoading = false;
                                cameraStorageStatus = "删除失败 · " + error.getMessage();
                                showSection("library");
                                showError(error.getMessage());
                            });
                        }
                    });
                })
                .show();
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
                        ? "AI 云端修图与生图使用当前账号和设备激活权益。"
                        : "分组调整光线、色彩、细节、效果与几何；始终保留原文件。",
                COBALT));
        LinearLayout modeRow = new LinearLayout(this);
        modeRow.setOrientation(LinearLayout.HORIZONTAL);
        Button proMode = nativeButton(
                editorState == EditorState.PRO ? "● 专业显影" : "○ 专业显影",
                editorState == EditorState.PRO);
        proMode.setOnClickListener(view -> {
            editorState = EditorState.PRO;
            aiResultBitmap = null;
            showSection("editor");
        });
        modeRow.addView(proMode, new LinearLayout.LayoutParams(0, dp(44), 1f));
        Button aiModeButton = nativeButton(
                editorState == EditorState.AI ? "● AI 工具" : "○ AI 工具",
                editorState == EditorState.AI);
        aiModeButton.setOnClickListener(view -> {
            editorState = EditorState.AI;
            aiResultBitmap = null;
            showSection("editor");
        });
        LinearLayout.LayoutParams aiModeParams =
                new LinearLayout.LayoutParams(0, dp(44), 1f);
        aiModeParams.setMargins(dp(8), 0, 0, 0);
        modeRow.addView(aiModeButton, aiModeParams);
        content.addView(modeRow, marginParams(-1, -2, 0, 12, 0, 0));

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

        content.addView(
                buildEditorPhotoPicker(photos),
                marginParams(-1, dp(64), 0, 0, 0, 12));

        // 图 2 移动端降级：监视器固定顶部，控制面板（工具条/媒体/示波器/参数）位于其下
        EditorMaskImageView preview = new EditorMaskImageView(editorAdjustments);
        content.addView(
                preview,
                marginParams(-1, dp(360), 0, 0, 0, 14));

        TextView status = text(
                "调整不会覆盖原文件",
                TS_CAPTION,
                Typeface.NORMAL,
                MUTED);
        Runnable refreshPreview = () -> {
            File selected = new File(editorSelectedPath);
            Bitmap rendered = renderEditedBitmap(
                    selected,
                    editorAdjustments,
                    1600);
            if (rendered == null) {
                preview.clearPreview();
                status.setText(tr("无法解码当前照片"));
            } else {
                preview.setPreviewBitmap(rendered);
                status.setText(tr(
                        editorAdjustments.showingOriginal
                                ? "正在查看原图"
                                : "调整不会覆盖原文件"));
            }
        };
        preview.setMaskChangedListener(refreshPreview);

        View editorDivider = new View(this);
        editorDivider.setBackgroundColor(EDITOR_RULE);
        content.addView(
                editorDivider,
                marginParams(-1, dp(1), 0, 0, 0, 12));

        content.addView(
                buildResolveEditorWorkbench(photos),
                marginParams(-1, -2, 0, 0, 0, 12));

        LinearLayout aiPanel = panel();
        aiPanel.setPadding(dp(14), dp(14), dp(14), dp(14));
        LinearLayout aiHeading = new LinearLayout(this);
        aiHeading.setOrientation(LinearLayout.HORIZONTAL);
        aiHeading.setGravity(Gravity.CENTER_VERTICAL);
        TextView aiTitle = text(
                "AI 智能修图 · 工作台",
                16,
                Typeface.BOLD,
                INK);
        aiHeading.addView(aiTitle, new LinearLayout.LayoutParams(
                0,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                1f));
        TextView aiBadge = text(
                "设备端",
                TS_CAPTION,
                Typeface.BOLD,
                COBALT);
        aiBadge.setGravity(Gravity.CENTER);
        aiHeading.addView(aiBadge, new LinearLayout.LayoutParams(
                dp(64),
                dp(30)));
        aiPanel.addView(aiHeading);
        TextView aiSummary = text(
                editorAISummary,
                13,
                Typeface.NORMAL,
                MUTED);
        aiPanel.addView(
                aiSummary,
                marginParams(-1, -2, 0, 6, 0, 8));
        aiPanel.addView(
                text("设备端处理 · 照片不会上传",
                TS_CAPTION,
                        Typeface.BOLD,
                        COBALT),
                marginParams(-1, -2, 0, 4, 0, 6));
        LinearLayout aiMetrics = new LinearLayout(this);
        aiMetrics.setOrientation(LinearLayout.HORIZONTAL);
        addEditorAIMetric(aiMetrics, "曝光", editorAIAnalysis == null
                ? 0 : editorAIAnalysis.meanLuma);
        addEditorAIMetric(aiMetrics, "动态范围", editorAIAnalysis == null
                ? 0 : editorAIAnalysis.contrast);
        addEditorAIMetric(aiMetrics, "色彩", editorAIAnalysis == null
                ? 0 : editorAIAnalysis.saturation);
        addEditorAIMetric(aiMetrics, "细节", editorAIAnalysis == null
                ? 0 : editorAIAnalysis.detail);
        aiMetrics.setVisibility(editorAIAnalysis == null ? View.GONE : View.VISIBLE);
        aiPanel.addView(aiMetrics, marginParams(-1, -2, 0, 6, 0, 4));
        TextView aiStrengthLabel = text(
                "AI 强度 · " + editorAIIntensity + "%",
                TS_BODY,
                Typeface.NORMAL,
                MUTED);
        aiPanel.addView(aiStrengthLabel);
        SeekBar aiStrength = new SeekBar(this);
        aiStrength.setMax(65);
        aiStrength.setProgress(editorAIIntensity - 35);
        aiStrength.setOnSeekBarChangeListener(
                new SeekBar.OnSeekBarChangeListener() {
                    @Override
                    public void onProgressChanged(
                            SeekBar seekBar,
                            int progress,
                            boolean fromUser) {
                        editorAIIntensity = progress + 35;
                        aiStrengthLabel.setText(
                                tr("AI 强度") + " · "
                                        + editorAIIntensity + "%");
                    }

                    @Override
                    public void onStartTrackingTouch(SeekBar seekBar) {
                    }

                    @Override
                    public void onStopTrackingTouch(SeekBar seekBar) {
                    }
                });
        aiPanel.addView(aiStrength);
        HorizontalScrollView aiActionScroll = new HorizontalScrollView(this);
        aiActionScroll.setHorizontalScrollBarEnabled(false);
        LinearLayout aiActions = new LinearLayout(this);
        aiActions.setOrientation(LinearLayout.HORIZONTAL);
        Button analyze = nativeButton("分析画面", false);
        analyze.setOnClickListener(view -> {
            EditorAIAnalysis analysis = analyzeEditorPhoto(new File(editorSelectedPath));
            if (analysis == null) {
                showToast("无法分析当前照片");
                return;
            }
            editorAIAnalysis = analysis;
            editorAISummary = analysis.summary();
            showSection("editor");
        });
        aiActions.addView(analyze, new LinearLayout.LayoutParams(0, dp(48), 1f));
        Button optimize = nativeButton("智能优化", true);
        optimize.setOnClickListener(view -> {
            EditorAIAnalysis analysis = editorAIAnalysis != null
                    ? editorAIAnalysis
                    : analyzeEditorPhoto(new File(editorSelectedPath));
            if (analysis == null) {
                showToast("无法分析当前照片");
                return;
            }
            editorSettingsBeforeAI = editorAdjustments.copy();
            editorAIAnalysis = analysis;
            applyEditorAI(analysis, editorAIIntensity / 100.0);
            editorAISummary = analysis.summary();
            showSection("editor");
        });
        aiActions.addView(
                optimize,
                new LinearLayout.LayoutParams(0, dp(48), 1f));
        Button undoAI = nativeButton("撤销 AI", false);
        undoAI.setEnabled(editorSettingsBeforeAI != null);
        undoAI.setOnClickListener(view -> {
            if (editorSettingsBeforeAI == null) return;
            editorAdjustments.copyFrom(editorSettingsBeforeAI);
            editorSettingsBeforeAI = null;
            editorAIAnalysis = null;
            editorAISummary = "已撤销 AI 优化";
            showSection("editor");
        });
        LinearLayout.LayoutParams undoParams =
                new LinearLayout.LayoutParams(0, dp(48), 1f);
        undoParams.setMargins(dp(8), 0, 0, 0);
        aiActions.addView(undoAI, undoParams);
        Button copyAI = nativeButton("复制 AI", false);
        copyAI.setEnabled(editorSettingsBeforeAI != null);
        copyAI.setOnClickListener(view -> {
            editorAICopiedSettings = editorAdjustments.copy();
            showToast("已复制 AI 调整，可应用到下一张照片");
        });
        LinearLayout.LayoutParams copyParams = new LinearLayout.LayoutParams(0, dp(48), 1f);
        copyParams.setMargins(dp(8), 0, 0, 0);
        aiActions.addView(copyAI, copyParams);
        Button pasteAI = nativeButton("粘贴 AI", false);
        pasteAI.setEnabled(editorAICopiedSettings != null);
        pasteAI.setOnClickListener(view -> {
            if (editorAICopiedSettings == null) return;
            editorAdjustments.copyFrom(editorAICopiedSettings);
            selectedNikonCloudPreset = null;
            editorAISummary = "已粘贴 AI 调整";
            showSection("editor");
        });
        LinearLayout.LayoutParams pasteParams = new LinearLayout.LayoutParams(0, dp(48), 1f);
        pasteParams.setMargins(dp(8), 0, 0, 0);
        aiActions.addView(pasteAI, pasteParams);
        // E8 1.5.9: 批量应用 AI（本地渲染，0 服务器消耗）
        Button batchAI = nativeButton("批量应用 AI", true);
        batchAI.setEnabled(editorAICopiedSettings != null && !aiBatchApplying);
        batchAI.setOnClickListener(view -> applyAIBatch());
        LinearLayout.LayoutParams batchParams = new LinearLayout.LayoutParams(0, dp(48), 1f);
        batchParams.setMargins(dp(8), 0, 0, 0);
        aiActions.addView(batchAI, batchParams);
        aiActionScroll.addView(aiActions, new ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT));
        aiPanel.addView(aiActionScroll);
        // E8 1.5.9: 批量进度行（进度/跳过/取消）
        LinearLayout batchProgressRow = new LinearLayout(this);
        batchProgressRow.setOrientation(LinearLayout.HORIZONTAL);
        batchProgressRow.setGravity(Gravity.CENTER_VERTICAL);
        batchProgressRow.setPadding(dp(4), dp(4), dp(4), dp(4));
        ProgressBar batchBar = new ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal);
        batchBar.setMax(100);
        TextView batchStatus = text("", TS_CAPTION, Typeface.NORMAL, UI_LABEL);
        Button batchCancel = nativeButton("取消", false);
        batchCancel.setOnClickListener(view -> aiBatchCancelled = true);
        batchProgressRow.addView(batchBar, new LinearLayout.LayoutParams(0, dp(18), 1f));
        batchProgressRow.addView(batchStatus, marginParams(-1, -2, 0, 8, 0, 0));
        batchProgressRow.addView(batchCancel, new LinearLayout.LayoutParams(dp(56), dp(36)));
        batchProgressRow.setVisibility(View.GONE);
        aiPanel.addView(batchProgressRow, marginParams(-1, -2, 0, 0, 0, 8));
        content.addView(
                aiPanel,
                marginParams(-1, -2, 0, 0, 0, 12));

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

        LinearLayout nikonCloudPanel = panel();
        nikonCloudPanel.setPadding(dp(14), dp(12), dp(14), dp(12));
        LinearLayout cloudHeading = new LinearLayout(this);
        cloudHeading.setOrientation(LinearLayout.HORIZONTAL);
        cloudHeading.setGravity(Gravity.CENTER_VERTICAL);
        cloudHeading.addView(
                text("尼康云创预览", EDITOR_FS_MEDIUM, Typeface.BOLD, INK),
                new LinearLayout.LayoutParams(0, dp(40), 1f));
        cloudHeading.addView(
                text(nikonCloudPresets.size() + " 款 NP3", TS_CAPTION,
                        Typeface.BOLD, COBALT),
                new LinearLayout.LayoutParams(dp(88), dp(40)));
        nikonCloudPanel.addView(cloudHeading);
        Button cloudPicker = nativeButton(
                selectedNikonCloudPreset == null
                        ? "选择尼康云创预设"
                        : selectedNikonCloudPreset.name,
                true);
        cloudPicker.setEnabled(!nikonCloudPresets.isEmpty());
        cloudPicker.setOnClickListener(view -> showNikonCloudPresetPicker());
        nikonCloudPanel.addView(cloudPicker,
                new LinearLayout.LayoutParams(-1, dp(48)));
        nikonCloudPanel.addView(
                text("设备端 SDR 近似预览 · 相机与 NX Studio 成片可能不同",
                        TS_CAPTION, Typeface.NORMAL, MUTED),
                marginParams(-1, -2, 0, 8, 0, 0));
        content.addView(
                nikonCloudPanel,
                marginParams(-1, -2, 0, 0, 0, 12));

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

        // Secondary grading tools mirror the iOS and Harmony editor tabs.
        LinearLayout wheels = editorAdjustmentGroup();
        wheels.addView(text("Lift / Gamma / Gain · 在圆盘内拖动色点", TS_BODY, Typeface.BOLD, MUTED));
        LinearLayout wheelRow = new LinearLayout(this);
        wheelRow.setOrientation(LinearLayout.HORIZONTAL);
        wheelRow.setGravity(Gravity.CENTER);
        wheelRow.addView(createEditorWheel("Lift", COBALT, editorAdjustments.wheelLiftX, editorAdjustments.wheelLiftY,
                (x, y) -> { editorAdjustments.wheelLiftX = x; editorAdjustments.wheelLiftY = y; }, refreshPreview),
                new LinearLayout.LayoutParams(0, dp(122), 1f));
        wheelRow.addView(createEditorWheel("Gamma", Color.rgb(198, 140, 255), editorAdjustments.wheelGammaX, editorAdjustments.wheelGammaY,
                (x, y) -> { editorAdjustments.wheelGammaX = x; editorAdjustments.wheelGammaY = y; }, refreshPreview),
                new LinearLayout.LayoutParams(0, dp(122), 1f));
        wheelRow.addView(createEditorWheel("Gain", Color.rgb(255, 211, 106), editorAdjustments.wheelGainX, editorAdjustments.wheelGainY,
                (x, y) -> { editorAdjustments.wheelGainX = x; editorAdjustments.wheelGainY = y; }, refreshPreview),
                new LinearLayout.LayoutParams(0, dp(122), 1f));
        wheels.addView(wheelRow);
        content.addView(collapsibleGroup("editor-wheels", "色轮", "三向色轮", wheels, false));

        LinearLayout curves = editorAdjustmentGroup();
        curves.addView(text("主曲线 · 拖动曲线控制点", TS_BODY, Typeface.BOLD, MUTED));
        curves.addView(createEditorCurvePad(refreshPreview), marginParams(-1, dp(156), 0, 0, 0, 6));
        curves.addView(text("点击任意位置新增控制点，拖动控制点调整曲线", TS_CAPTION, Typeface.NORMAL, MUTED));
        content.addView(collapsibleGroup("editor-curves", "曲线", "主曲线", curves, false));

        LinearLayout pickerPanel = editorAdjustmentGroup();
        TextView pickerValue = text("RGB 取样：点击取样器读取中心像素", TS_BODY, Typeface.NORMAL, MUTED);
        pickerPanel.addView(pickerValue, marginParams(-1, -2, 0, 0, 0, 6));
        Button sample = nativeButton("取样当前照片", false);
        sample.setOnClickListener(view -> {
            Bitmap bitmap = renderEditorAnalysisBitmap(new File(editorSelectedPath), 256);
            if (bitmap == null) { pickerValue.setText("无法读取当前照片"); return; }
            int colorValue = bitmap.getPixel(bitmap.getWidth() / 2, bitmap.getHeight() / 2);
            pickerValue.setText(String.format(Locale.ROOT, "RGB 取样：#%06X", 0xFFFFFF & colorValue));
            int red = Color.red(colorValue);
            int green = Color.green(colorValue);
            int blue = Color.blue(colorValue);
            editorAdjustments.temperature = Math.max(-100, Math.min(100, Math.round((blue - red) / 2.55f)));
            editorAdjustments.tint = Math.max(-100, Math.min(100, Math.round((green - (red + blue) / 2f) / 2.55f)));
            bitmap.recycle();
            refreshPreview.run();
        });
        pickerPanel.addView(sample, new LinearLayout.LayoutParams(-1, dp(44)));
        content.addView(collapsibleGroup("editor-picker", "取色器", "中心像素", pickerPanel, false));

        LinearLayout mask = editorAdjustmentGroup();
        mask.addView(text("蒙版列表", TS_BODY, Typeface.BOLD, INK));
        if (editorAdjustments.maskLayers.isEmpty()) {
            mask.addView(text(
                    "暂无蒙版",
                TS_CAPTION,
                    Typeface.NORMAL,
                    MUTED),
                    marginParams(-1, dp(44), 0, 2, 0, 6));
        } else {
            LinearLayout maskList = verticalContainer();
            for (EditorMaskLayer layer : editorAdjustments.maskLayers) {
                EditorMaskLayer displayed = editorAdjustments.displayedMaskLayer(layer);
                LinearLayout row = new LinearLayout(this);
                row.setOrientation(LinearLayout.HORIZONTAL);
                row.setGravity(Gravity.CENTER_VERTICAL);
                row.setPadding(dp(8), 0, dp(4), 0);
                row.setBackground(rounded(
                        layer.id.equals(editorAdjustments.activeMaskLayerId)
                                ? COBALT_SOFT
                                : SURFACE,
                        10,
                        layer.id.equals(editorAdjustments.activeMaskLayerId)
                                ? COBALT
                                : RULE));
                Button select = nativeButton(
                        (layer.id.equals(editorAdjustments.activeMaskLayerId) ? "● " : "○ ")
                                + (layer.name.startsWith("蒙版 ")
                                    ? tr("蒙版") + layer.name.substring(2)
                                    : tr(layer.name))
                                + " · " + tr(displayed.type),
                        false);
                select.setGravity(Gravity.START | Gravity.CENTER_VERTICAL);
                select.setOnClickListener(view -> {
                    editorAdjustments.selectMaskLayer(layer.id);
                    showSection("editor");
                });
                row.addView(select, new LinearLayout.LayoutParams(0, dp(48), 1f));
                Switch visibility = new Switch(this);
                visibility.setChecked(layer.visible);
                visibility.setContentDescription(tr(
                        layer.visible ? "隐藏蒙版" : "显示蒙版"));
                visibility.setMinimumHeight(dp(48));
                visibility.setOnCheckedChangeListener((button, visible) -> {
                    editorAdjustments.setMaskLayerVisible(layer.id, visible);
                    showSection("editor");
                });
                row.addView(visibility, new LinearLayout.LayoutParams(dp(56), dp(48)));
                maskList.addView(row, marginParams(-1, dp(48), 0, 0, 0, 6));
            }
            mask.addView(maskList);
        }
        LinearLayout maskLifecycle = new LinearLayout(this);
        maskLifecycle.setOrientation(LinearLayout.HORIZONTAL);
        Button createMask = nativeButton("创建蒙版", !editorAdjustments.maskEnabled);
        createMask.setOnClickListener(view -> {
            editorAdjustments.createMaskLayer();
            showSection("editor");
        });
        maskLifecycle.addView(createMask, new LinearLayout.LayoutParams(0, dp(48), 1f));
        Button deleteMask = nativeButton("删除蒙版", false);
        deleteMask.setEnabled(editorAdjustments.maskEnabled);
        deleteMask.setOnClickListener(view -> {
            editorAdjustments.deleteActiveMaskLayer();
            showSection("editor");
        });
        LinearLayout.LayoutParams deleteMaskParams = new LinearLayout.LayoutParams(0, dp(48), 1f);
        deleteMaskParams.setMargins(dp(8), 0, 0, 0);
        maskLifecycle.addView(deleteMask, deleteMaskParams);
        mask.addView(maskLifecycle);

        LinearLayout maskBrushes = new LinearLayout(this);
        maskBrushes.setOrientation(LinearLayout.HORIZONTAL);
        Button addMaskBrush = nativeButton("添加蒙版（画笔）",
                editorAdjustments.maskEnabled && !editorAdjustments.maskSubtract);
        addMaskBrush.setOnClickListener(view -> {
            editorAdjustments.ensureMaskLayer();
            if (editorAdjustments.maskType == null
                    || editorAdjustments.maskType.isEmpty()) {
                editorAdjustments.maskType = "画笔";
            }
            editorAdjustments.maskSubtract = false;
            status.setText(tr("添加蒙版画笔已启用"));
            preview.invalidate();
        });
        maskBrushes.addView(addMaskBrush, new LinearLayout.LayoutParams(0, dp(48), 1f));
        Button subtractMaskBrush = nativeButton("减去蒙版（画笔）",
                editorAdjustments.maskEnabled && editorAdjustments.maskSubtract);
        subtractMaskBrush.setOnClickListener(view -> {
            editorAdjustments.ensureMaskLayer();
            if (editorAdjustments.maskType == null
                    || editorAdjustments.maskType.isEmpty()) {
                editorAdjustments.maskType = "画笔";
            }
            editorAdjustments.maskSubtract = true;
            status.setText(tr("减去蒙版画笔已启用"));
            preview.invalidate();
        });
        LinearLayout.LayoutParams subtractMaskParams = new LinearLayout.LayoutParams(0, dp(48), 1f);
        subtractMaskParams.setMargins(dp(8), 0, 0, 0);
        maskBrushes.addView(subtractMaskBrush, subtractMaskParams);
        mask.addView(maskBrushes, marginParams(-1, -2, 0, 8, 0, 0));

        mask.addView(text("智能识别", TS_BODY, Typeface.BOLD, MUTED));
        HorizontalScrollView smartMaskScroll = new HorizontalScrollView(this);
        smartMaskScroll.setHorizontalScrollBarEnabled(false);
        LinearLayout smartMasks = new LinearLayout(this);
        smartMasks.setOrientation(LinearLayout.HORIZONTAL);
        for (String type : new String[] {
                "智能主体", "智能天空", "智能背景",
                "智能人物", "智能亮部", "智能暗部"}) {
            Button smartMask = nativeButton(
                    type,
                    editorAdjustments.maskEnabled
                            && type.equals(editorAdjustments.maskType));
            smartMask.setOnClickListener(view -> {
                editorAdjustments.ensureMaskLayer();
                editorAdjustments.maskType = type;
                editorAdjustments.maskAmount = 100;
                editorAdjustments.maskInvert = false;
                editorAdjustments.maskStrokes.clear();
                editorAdjustments.maskSubtract = false;
                status.setText(tr("智能蒙版已创建 · 可继续添加或减去画笔"));
                refreshPreview.run();
            });
            LinearLayout.LayoutParams smartParams =
                    new LinearLayout.LayoutParams(-2, dp(44));
            smartParams.setMargins(0, dp(6), dp(8), dp(8));
            smartMasks.addView(smartMask, smartParams);
        }
        smartMaskScroll.addView(smartMasks);
        mask.addView(smartMaskScroll);
        addEditorAdjustment(mask, "强度", editorAdjustments.maskAmount, 0, 100, false,
                value -> editorAdjustments.maskAmount = value, refreshPreview);
        addEditorAdjustment(mask, "羽化", editorAdjustments.maskFeather, 0, 100, false,
                value -> editorAdjustments.maskFeather = value, refreshPreview);
        addEditorAdjustment(mask, "画笔大小", editorAdjustments.maskBrushSize, 4, 64, false,
                value -> editorAdjustments.maskBrushSize = value, () -> preview.invalidate());
        Button invertMask = nativeButton("反向蒙版", editorAdjustments.maskInvert);
        invertMask.setOnClickListener(view -> {
            editorAdjustments.maskInvert = !editorAdjustments.maskInvert;
            status.setText(tr(editorAdjustments.maskInvert
                    ? "蒙版已反向"
                    : "蒙版已恢复正向"));
            refreshPreview.run();
        });
        mask.addView(invertMask, marginParams(-1, dp(44), 0, 4, 0, 10));
        mask.addView(text("蒙版内调整", TS_BODY, Typeface.BOLD, INK));
        addEditorAdjustment(mask, "曝光", editorAdjustments.maskExposure, -200, 200, true,
                value -> editorAdjustments.maskExposure = value, refreshPreview);
        addEditorAdjustment(mask, "对比度", editorAdjustments.maskContrast, -100, 100, false,
                value -> editorAdjustments.maskContrast = value, refreshPreview);
        addEditorAdjustment(mask, "高光", editorAdjustments.maskHighlights, -100, 100, false,
                value -> editorAdjustments.maskHighlights = value, refreshPreview);
        addEditorAdjustment(mask, "阴影", editorAdjustments.maskShadows, -100, 100, false,
                value -> editorAdjustments.maskShadows = value, refreshPreview);
        addEditorAdjustment(mask, "色温", editorAdjustments.maskTemperature, -100, 100, false,
                value -> editorAdjustments.maskTemperature = value, refreshPreview);
        addEditorAdjustment(mask, "色调", editorAdjustments.maskTint, -100, 100, false,
                value -> editorAdjustments.maskTint = value, refreshPreview);
        addEditorAdjustment(mask, "饱和度", editorAdjustments.maskSaturation, -100, 100, false,
                value -> editorAdjustments.maskSaturation = value, refreshPreview);
        addEditorAdjustment(mask, "清晰度", editorAdjustments.maskClarity, -100, 100, false,
                value -> editorAdjustments.maskClarity = value, refreshPreview);
        mask.addView(text(
                editorAdjustments.maskEnabled
                        ? "蓝色显示当前蒙版覆盖；橡皮会擦除蓝色区域。"
                        : "先创建蒙版，再选择添加或减去画笔。",
                TS_CAPTION,
                Typeface.NORMAL,
                MUTED));
        content.addView(collapsibleGroup("editor-mask", "蒙版", "画笔范围", mask, false));

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
            selectedNikonCloudPreset = null;
            editorSettingsBeforeAI = null;
            editorAIAnalysis = null;
            editorAISummary = "等待分析当前照片";
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
                        selectedNikonCloudPreset = null;
                        updateFileCount();
                        showToast("已保存编辑副本：" + destination.getName());
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

    /**
     * Resolve-inspired editor command strip. It exposes the actual media
     * selection, inspector groups, AI analysis, and save workflow without
     * introducing a parallel editor state machine.
     */
    private View buildResolveEditorWorkbench(List<File> photos) {
        // 图 2 移动端降级：控制带（媒体行 + 工具条 + 示波器区）纵向堆叠，
        // 作为监视器下方的「底部抽屉」顶部控制面板；1px 深色分隔。
        LinearLayout workbench = new LinearLayout(this);
        workbench.setOrientation(LinearLayout.VERTICAL);
        workbench.setBackground(rounded(EDITOR_BG, 0, 0));
        workbench.addView(buildEditorMediaRail(photos),
                new LinearLayout.LayoutParams(-1, dp(52)));
        View toolDivider = new View(this);
        toolDivider.setBackgroundColor(EDITOR_RULE);
        workbench.addView(toolDivider, new LinearLayout.LayoutParams(-1, dp(1)));
        workbench.addView(buildEditorToolRail(),
                new LinearLayout.LayoutParams(-1, dp(52)));
        View scopeDivider = new View(this);
        scopeDivider.setBackgroundColor(EDITOR_RULE);
        workbench.addView(scopeDivider, new LinearLayout.LayoutParams(-1, dp(1)));
        workbench.addView(buildEditorScopeDock(),
                new LinearLayout.LayoutParams(-1, dp(64)));
        return workbench;
    }

    private View buildEditorMediaRail(List<File> photos) {
        // 媒体行：当前照片名 + 非破坏说明（图 2 顶部媒体信息）
        LinearLayout rail = new LinearLayout(this);
        rail.setOrientation(LinearLayout.HORIZONTAL);
        rail.setGravity(Gravity.CENTER_VERTICAL);
        rail.setPadding(dp(12), 0, dp(12), 0);
        rail.setBackground(rounded(EDITOR_PANEL, 0, 0));
        rail.addView(text(tr("媒体池") + " · " + photos.size(),
                EDITOR_FS_SMALL, Typeface.BOLD, EDITOR_LABEL));
        String selected = editorSelectedPath == null
                ? tr("未选择照片")
                : new File(editorSelectedPath).getName();
        TextView filename = text(selected, TS_BODY, Typeface.BOLD, Color.WHITE);
        filename.setSingleLine(true);
        filename.setEllipsize(TextUtils.TruncateAt.MIDDLE);
        LinearLayout.LayoutParams filenameParams =
                new LinearLayout.LayoutParams(0, -2, 1f);
        filenameParams.setMargins(dp(10), 0, 0, 0);
        rail.addView(filename, filenameParams);
        rail.addView(text(tr("非破坏编辑 · 保存为高质量副本"),
                EDITOR_FS_TINY, Typeface.NORMAL, EDITOR_LABEL));
        return rail;
    }

    private View buildEditorToolRail() {
        // 工具条：线性单色文字钮 + 品牌橙选中态（图 2 工具图标条语义）
        LinearLayout rail = new LinearLayout(this);
        rail.setOrientation(LinearLayout.HORIZONTAL);
        rail.setPadding(dp(2), dp(5), dp(2), dp(5));
        rail.setBackground(rounded(EDITOR_PANEL, 0, 0));
        String[] names = new String[]{"色轮", "曲线", "蒙版", "几何", "AI"};
        String[] keys = new String[]{
                "editor-wheels", "editor-curves", "editor-mask", "editor-geometry", "ai"};
        for (int index = 0; index < names.length; index++) {
            final String key = keys[index];
            boolean active = "ai".equals(key)
                    ? editorState == EditorState.AI
                    : Boolean.TRUE.equals(disclosureStates.get(key));
            Button tool = nativeButton(names[index], false);
            tool.setTextSize(TS_CAPTION);
            tool.setTextColor(active ? EDITOR_ACCENT : EDITOR_LABEL);
            tool.setBackground(rounded(
                    active ? EDITOR_RAISED : Color.TRANSPARENT,
                    0,
                    active ? EDITOR_ACCENT : 0));
            // fig2 线性单色图标：五端同几何，颜色跟随文字选中态（P2-2 集成轮）
            Drawable icon = getDrawable(editorToolIcon(key)).mutate();
            icon.setTint(active ? EDITOR_ACCENT : EDITOR_LABEL);
            tool.setCompoundDrawablesWithIntrinsicBounds(icon, null, null, null);
            tool.setCompoundDrawablePadding(dp(5));
            tool.setOnClickListener(view -> {
                if ("ai".equals(key)) {
                    editorState = EditorState.AI;
                    aiResultBitmap = null;
                    showSection("editor");
                } else {
                    disclosureStates.put(key, true);
                    pendingEditorScrollKey = key;
                    showSection("editor");
                }
            });
            LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(
                    0, dp(44), 1f);
            if (index > 0) params.setMargins(dp(4), 0, 0, 0);
            rail.addView(tool, params);
        }
        return rail;
    }

    private int editorToolIcon(String key) {
        // fig2 工具条线性单色图标（16x16，五端同几何，P2-2 集成轮）
        switch (key) {
            case "editor-wheels":
                return R.drawable.editor_icon_wheels;
            case "editor-curves":
                return R.drawable.editor_icon_curves;
            case "editor-mask":
                return R.drawable.editor_icon_mask;
            case "editor-geometry":
                return R.drawable.editor_icon_geometry;
            case "ai":
                return R.drawable.editor_icon_ai;
            default:
                return R.drawable.editor_icon_ai;
        }
    }

    private View buildEditorScopeDock() {
        // 示波器区：标题列 + RGB 三色叠加波形（复用视频页 WaveformScopeView 绘制，
        // 数据契约 S64x48 与 ProfessionalMonitor 一致），AI 四项指标保留为文字。
        LinearLayout dock = new LinearLayout(this);
        dock.setOrientation(LinearLayout.HORIZONTAL);
        dock.setGravity(Gravity.CENTER_VERTICAL);
        dock.setPadding(dp(12), 0, dp(12), 0);
        dock.setBackground(rounded(EDITOR_PANEL, 0, 0));

        LinearLayout header = new LinearLayout(this);
        header.setOrientation(LinearLayout.VERTICAL);
        header.setGravity(Gravity.CENTER_VERTICAL);
        header.addView(text(tr("编辑示波器"),
                EDITOR_FS_SMALL, Typeface.BOLD, EDITOR_LABEL));
        header.addView(text(
                editorSelectedPath == null
                        ? tr("暂无图像源")
                        : tr("本地图像分析"),
                EDITOR_FS_TINY, Typeface.BOLD,
                editorSelectedPath == null ? EDITOR_LABEL : EDITOR_ACCENT));
        if (editorAIAnalysis != null) {
            String metrics = String.format(
                    Locale.CHINA,
                    "曝光 %d%% · 动态 %d%% · 色彩 %d%% · 细节 %d%%",
                    Math.round(editorAIAnalysis.meanLuma * 100),
                    Math.round(editorAIAnalysis.contrast * 100),
                    Math.round(editorAIAnalysis.saturation * 100),
                    Math.round(editorAIAnalysis.detail * 100));
            TextView metricText = text(metrics, EDITOR_FS_TINY,
                    Typeface.BOLD, EDITOR_LABEL);
            metricText.setSingleLine(true);
            metricText.setEllipsize(TextUtils.TruncateAt.END);
            header.addView(metricText);
        }
        dock.addView(header, new LinearLayout.LayoutParams(dp(190), -2));

        WaveformScopeView scope = new WaveformScopeView(WaveformScopeView.RGB_PARADE);
        String[] densities = editorScopeDensities();
        if (densities != null) {
            scope.setData(densities[0], densities[1], densities[2]);
        }
        LinearLayout.LayoutParams scopeParams =
                new LinearLayout.LayoutParams(0, -2, 1f);
        scopeParams.setMargins(dp(10), 0, 0, 0);
        dock.addView(scope, scopeParams);
        return dock;
    }

    /**
     * RGB density payloads for the editor scope, computed from the current
     * editor image (same source the preview renders: AI tools surface the AI
     * result or original, Pro editor the rendered edit). Mirrors the monitor
     * contract by reusing ProfessionalMonitor's S64x48 density generation.
     */
    private String[] editorScopeDensities() {
        if (editorSelectedPath == null) return null;
        File file = new File(editorSelectedPath);
        Bitmap source;
        if (editorState == EditorState.AI) {
            source = aiResultBitmap != null
                    ? aiResultBitmap
                    : renderEditorAnalysisBitmap(file, 320);
        } else {
            source = renderEditedBitmap(file, editorAdjustments, 320);
        }
        if (source == null) return null;
        ProfessionalMonitor.Result result = ProfessionalMonitor.process(
                source, false, false, null);
        if (result == null) return null;
        return new String[]{
                result.redHistogram,
                result.greenHistogram,
                result.blueHistogram};
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

        content.addView(
                buildResolveEditorWorkbench(photos),
                marginParams(-1, dp(118), 0, 0, 0, 12));

        LinearLayout aiIntro = new LinearLayout(this);
        aiIntro.setOrientation(LinearLayout.VERTICAL);
        aiIntro.setPadding(dp(14), dp(12), dp(14), dp(12));
        aiIntro.setBackground(rounded(COBALT_SOFT, 12, COBALT));
        aiIntro.addView(text("AI 创作", EDITOR_FS_HEAD, Typeface.BOLD, INK));
        aiIntro.addView(text(
                "修图覆盖原图 · 生图保存新文件",
                TS_BODY,
                Typeface.NORMAL,
                MUTED), marginParams(-1, -2, 0, 6, 0, 0));
        aiIntro.addView(text(
                isAiActivated()
                        ? "已解锁 · 剩余 " + getRemainingUsage() + " 次"
                        : "需要激活 · 请在设置中输入激活码",
                TS_CAPTION,
                Typeface.BOLD,
                isAiActivated() ? POSITIVE : MUTED));
        content.addView(aiIntro, marginParams(-1, -2, 0, 0, 0, 12));

        if (aiMode == 0) {
            if (editorSelectedPath == null || photos.stream().noneMatch(
                    f -> f.getAbsolutePath().equals(editorSelectedPath))) {
                editorSelectedPath = photos.isEmpty()
                        ? null
                        : photos.get(0).getAbsolutePath();
            }
            content.addView(
                    buildEditorPhotoPicker(photos),
                    marginParams(-1, dp(64), 0, 0, 0, 10));
            if (aiResultBitmap == null && editorSelectedPath != null) {
                Bitmap original = renderEditorAnalysisBitmap(
                        new File(editorSelectedPath),
                        1400);
                if (original != null) {
                    content.addView(
                            text(tr("已选择原图"), TS_CAPTION, Typeface.BOLD, MUTED),
                            marginParams(-1, -2, 0, 0, 0, 6));
                    ImageView originalPreview = new ImageView(this);
                    originalPreview.setScaleType(ImageView.ScaleType.FIT_CENTER);
                    originalPreview.setImageBitmap(original);
                    originalPreview.setBackgroundColor(GRAPHITE);
                    content.addView(
                            originalPreview,
                            marginParams(-1, dp(320), 0, 0, 0, 12));
                }
            }
        }

        LinearLayout modeRow = new LinearLayout(this);
        modeRow.setOrientation(LinearLayout.HORIZONTAL);
        Button editBtn = nativeButton(aiMode == 0 ? "● AI 修图" : "○ AI 修图", aiMode == 0);
        editBtn.setOnClickListener(v -> {
            aiMode = 0;
            aiResultBitmap = null;
            aiPrompt = composeAiPrompt();
            showSection("editor");
        });
        modeRow.addView(editBtn, new LinearLayout.LayoutParams(0, dp(44), 1f));
        Button genBtn = nativeButton(aiMode == 1 ? "● AI 生图" : "○ AI 生图", aiMode == 1);
        genBtn.setOnClickListener(v -> {
            aiMode = 1;
            aiResultBitmap = null;
            aiSelectedPresetKeys.removeIf(item -> item.startsWith(
                    "智能移除\u001f"));
            aiPrompt = composeAiPrompt();
            showSection("editor");
        });
        LinearLayout.LayoutParams genParams = new LinearLayout.LayoutParams(0, dp(44), 1f);
        genParams.setMargins(dp(8), 0, 0, 0);
        modeRow.addView(genBtn, genParams);
        content.addView(modeRow, marginParams(-1, -2, 0, 0, 0, 10));

        EditText promptInput = new EditText(this);
        promptInput.setHint(aiMode == 0 ? tr("输入修图描述…") : tr("输入生图描述…"));
        if (aiSelectedPresetKeys.isEmpty() && aiManualPrompt.isEmpty()) aiManualPrompt = aiPrompt;
        promptInput.setText(aiPrompt);
        promptInput.setMinLines(2);
        promptInput.setMaxLines(4);
        promptInput.setBackgroundColor(SURFACE);
        promptInput.setPadding(dp(12), dp(10), dp(12), dp(10));
        promptInput.addTextChangedListener(new TextWatcher() {
            @Override public void beforeTextChanged(CharSequence s, int start, int count, int after) {}
            @Override public void onTextChanged(CharSequence s, int start, int before, int count) {
                if (!suppressAiPromptChange) aiManualPrompt = s.toString().trim();
            }
            @Override public void afterTextChanged(Editable s) {}
        });

        TextView aiStatus = text("请输入提示词", TS_CAPTION, Typeface.NORMAL, MUTED);
        LinearLayout promptSection = new LinearLayout(this);
        promptSection.setOrientation(LinearLayout.VERTICAL);
        promptSection.setPadding(dp(12), dp(10), dp(12), dp(10));
        promptSection.setBackground(rounded(SURFACE, 12, RULE));
        promptSection.addView(text("提示词", TS_BODY, Typeface.BOLD, MUTED),
                marginParams(-1, -2, 0, 0, 0, 6));
        promptSection.addView(promptInput, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));
        content.addView(promptSection, marginParams(-1, -2, 0, 0, 0, 10));

        content.addView(text("输出参数", TS_BODY, Typeface.BOLD, MUTED),
                marginParams(-1, -2, 0, 0, 0, 6));
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

        Button generateBtn = nativeButton("生成图像", true);
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
                String failureMessage = null;
                try {
                    AiImageResponse result = callAiImageApi(
                            loadActivationCode(), aiDeviceId(),
                            aiPrompt, sourcePath, size);
                    if (result != null) {
                        aiResultBitmap = BitmapFactory.decodeByteArray(
                                result.image, 0, result.image.length);
                        ok = aiResultBitmap != null;
                        if (ok) {
                            if (result.remaining != null) {
                                setAiRemainingUsage(result.remaining);
                            } else {
                                // Older proxies did not expose the server count.
                                recordAiUsage();
                            }
                        }
                    }
                } catch (Exception e) {
                    failureMessage = e instanceof java.net.SocketTimeoutException
                            ? "AI 生成超时，请稍后重试"
                            : e.getMessage();
                    diagnostics.error("ai", "AI 调用失败：" + e.getMessage());
                }
                boolean success = ok;
                String finalFailureMessage = failureMessage;
                mainHandler.post(() -> {
                    aiIsGenerating = false;
                    generateBtn.setEnabled(true);
                    generateBtn.setText(tr("生成图像"));
                    if (success) {
                        aiStatus.setText(tr("生成完成"));
                        showSection("editor");
                    } else {
                        aiStatus.setText(tr(
                                finalFailureMessage == null
                                        || finalFailureMessage.isEmpty()
                                        ? "AI 生成失败"
                                        : finalFailureMessage));
                    }
                });
            });
        });
        content.addView(generateBtn, marginParams(-1, dp(48), 0, 8, 0, 8));
        content.addView(buildAiPresetRow(promptInput, aiStatus),
                marginParams(-1, -2, 0, 0, 0, 8));
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
                    File source = aiMode == 0 && editorSelectedPath != null
                            ? new File(editorSelectedPath)
                            : null;
                    String stem = aiMode == 0 ? "edited" : "generated";
                    File dest = source != null
                            ? source
                            : new File(
                                    photoDirectory,
                                    "ai_" + stem + "_" + new java.text.SimpleDateFormat(
                                            "yyyyMMdd_HHmmss", java.util.Locale.US)
                                            .format(new Date()) + ".jpg");
                    File temporary = source != null
                            ? new File(dest.getAbsolutePath() + ".ai.tmp")
                            : dest;
                    boolean ok = false;
                    try (FileOutputStream stream = new FileOutputStream(temporary)) {
                        ok = bmp.compress(Bitmap.CompressFormat.JPEG, 95, stream);
                        stream.getFD().sync();
                        if (ok && source != null) {
                            try {
                                java.nio.file.Files.move(
                                        temporary.toPath(),
                                        dest.toPath(),
                                        java.nio.file.StandardCopyOption.REPLACE_EXISTING,
                                        java.nio.file.StandardCopyOption.ATOMIC_MOVE);
                            } catch (java.nio.file.AtomicMoveNotSupportedException unsupported) {
                                java.nio.file.Files.move(
                                        temporary.toPath(),
                                        dest.toPath(),
                                        java.nio.file.StandardCopyOption.REPLACE_EXISTING);
                            }
                        }
                    } catch (Exception e) {
                        if (source != null && temporary.exists()) {
                            // Best-effort cleanup of an interrupted atomic write.
                            temporary.delete();
                        }
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
        scroll.addView(content);
        return scroll;
    }

    private View buildEditorPhotoPicker(List<File> photos) {
        LinearLayout holder = new LinearLayout(this);
        holder.setOrientation(LinearLayout.VERTICAL);
        Button picker = nativeButton("", false);
        picker.setGravity(Gravity.START | Gravity.CENTER_VERTICAL);
        picker.setPadding(dp(10), 0, dp(10), 0);
        updateEditorPhotoPickerLabel(picker);
        picker.setOnClickListener(view -> showEditorPhotoPickerDialog(photos));
        holder.addView(picker, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(56)));
        return holder;
    }

    private void updateEditorPhotoPickerLabel(Button picker) {
        File selected = editorSelectedPath == null
                ? null
                : new File(editorSelectedPath);
        picker.setText(selected == null
                ? "选择照片"
                : "▧  " + selected.getName());
        if (selected != null && selected.exists() && !isVideoFile(selected)) {
            Bitmap bitmap = decodeEditorThumbnail(selected, 84, 56);
            if (bitmap != null) {
                ImageView icon = new ImageView(this);
                icon.setImageBitmap(bitmap);
                icon.setScaleType(ImageView.ScaleType.CENTER_CROP);
                picker.setCompoundDrawablesWithIntrinsicBounds(null, null, null, null);
                picker.setCompoundDrawablePadding(dp(8));
                picker.setCompoundDrawables(
                        new BitmapDrawable(getResources(), bitmap),
                        null,
                        null,
                        null);
            }
        }
    }

    private Bitmap decodeEditorThumbnail(File file, int width, int height) {
        Bitmap bitmap = EditorBitmapDecoder.decode(
                file,
                Math.max(dp(width), dp(height)));
        if (bitmap == null) return null;
        Bitmap scaled = Bitmap.createScaledBitmap(
                bitmap,
                dp(width),
                dp(height),
                true);
        if (scaled != bitmap) bitmap.recycle();
        return scaled;
    }

    private void showEditorPhotoPickerDialog(List<File> photos) {
        ScrollView scroll = new ScrollView(this);
        LinearLayout tree = verticalContainer();
        tree.setPadding(dp(8), dp(4), dp(8), dp(4));
        List<File> unclassified = new ArrayList<>();
        for (File file : photos) {
            if (!libraryFileAssignments.containsKey(file.getAbsolutePath())) {
                unclassified.add(file);
            }
        }
        tree.addView(buildEditorPickerGroup("未分类", unclassified, null, 0));
        for (LibraryBranch branch : userLibraryBranches) {
            tree.addView(buildEditorPickerBranch(branch, photos, 0));
        }
        scroll.addView(tree);
        AlertDialog dialog = new AlertDialog.Builder(this)
                .setTitle("选择编辑照片")
                .setView(scroll)
                .setNegativeButton("取消", null)
                .create();
        dialog.show();
    }

    private View buildEditorPickerBranch(
            LibraryBranch branch,
            List<File> photos,
            int depth) {
        LinearLayout group = verticalContainer();
        List<File> assigned = filesAssignedToBranch(branch.id, photos);
        View body = buildEditorPickerGroup(branch.name, assigned, branch.id, depth);
        group.addView(body);
        for (LibraryBranch child : branch.children) {
            group.addView(buildEditorPickerBranch(child, photos, depth + 1));
        }
        return group;
    }

    private View buildEditorPickerGroup(
            String title,
            List<File> files,
            String branchId,
            int depth) {
        LinearLayout group = verticalContainer();
        Button header = nativeButton(
                "⌄  " + title + " · " + files.size(),
                false);
        header.setGravity(Gravity.START | Gravity.CENTER_VERTICAL);
        header.setPadding(dp(8 + depth * 14), 0, dp(4), 0);
        LinearLayout body = verticalContainer();
        for (File file : files) {
            body.addView(buildEditorPickerFileRow(file));
        }
        if (files.isEmpty()) {
            body.addView(text(
                    "此分支暂无可编辑照片",
                TS_BODY,
                    Typeface.NORMAL,
                    MUTED),
                    marginParams(-1, dp(36), dp(54 + depth * 14), 0, 0, 0));
        }
        header.setOnClickListener(view -> {
            boolean expanded = body.getVisibility() != View.VISIBLE;
            body.setVisibility(expanded ? View.VISIBLE : View.GONE);
            header.setText((expanded ? "⌄  " : "›  ") + title + " · " + files.size());
        });
        group.addView(header, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(48)));
        group.addView(body);
        return group;
    }

    private View buildEditorPickerFileRow(File file) {
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(Gravity.CENTER_VERTICAL);
        row.setPadding(dp(10), dp(7), dp(8), dp(7));
        row.setBackground(rounded(
                file.getAbsolutePath().equals(editorSelectedPath)
                        ? COBALT_SOFT : SURFACE,
                8,
                file.getAbsolutePath().equals(editorSelectedPath)
                        ? COBALT : RULE));
        ImageView thumbnail = new ImageView(this);
        thumbnail.setScaleType(ImageView.ScaleType.CENTER_CROP);
        Bitmap bitmap = decodeEditorThumbnail(file, 84, 56);
        if (bitmap != null) {
            thumbnail.setImageBitmap(bitmap);
        } else {
            thumbnail.setImageResource(android.R.drawable.ic_menu_gallery);
        }
        row.addView(thumbnail, new LinearLayout.LayoutParams(dp(84), dp(56)));
        TextView name = text(file.getName(), TS_BODY, Typeface.BOLD, INK);
        name.setSingleLine(true);
        name.setEllipsize(android.text.TextUtils.TruncateAt.MIDDLE);
        row.addView(name, new LinearLayout.LayoutParams(0, dp(56), 1f));
        if (file.getAbsolutePath().equals(editorSelectedPath)) {
            row.addView(text("✓", TS_TITLE, Typeface.BOLD, COBALT),
                    new LinearLayout.LayoutParams(dp(32), dp(56)));
        }
        row.setOnClickListener(view -> {
            editorSelectedPath = file.getAbsolutePath();
            aiResultBitmap = null;
            editorAdjustments.reset();
            selectedNikonCloudPreset = null;
            editorSettingsBeforeAI = null;
            editorAIAnalysis = null;
            editorAISummary = "等待分析当前照片";
            showSection("editor");
        });
        return row;
    }

    private LinearLayout buildAiPresetRow(EditText promptInput, TextView aiStatus) {
        LinearLayout container = new LinearLayout(this);
        container.setOrientation(LinearLayout.VERTICAL);
        LinearLayout header = new LinearLayout(this);
        header.setGravity(Gravity.CENTER_VERTICAL);
        header.addView(text("可组合预设", TS_CAPTION, Typeface.BOLD, MUTED),
                new LinearLayout.LayoutParams(0, dp(36), 1f));
        Button clear = nativeButton("清空", false);
        clear.setContentDescription("清空已选 AI 提示词预设");
        clear.setOnClickListener(v -> {
            aiSelectedPresetKeys.clear();
            aiManualPrompt = "";
            setComposedAiPrompt(promptInput);
            aiStatus.setText("已清空预设");
        });
        header.addView(clear, new LinearLayout.LayoutParams(dp(72), dp(44)));
        container.addView(header,
                marginParams(-1, -2, 0, 8, 0, 2));
        String[][] modules = aiMode == 0 ? AI_EDIT_MODULES : AI_GENERATE_MODULES;
        for (String[] module : modules) {
            TextView title = text(module[0], EDITOR_FS_SMALL, Typeface.BOLD, MUTED);
            container.addView(title, marginParams(-1, -2, 0, 0, 0, 4));
            HorizontalScrollView scroll = new HorizontalScrollView(this);
            scroll.setHorizontalScrollBarEnabled(false);
            LinearLayout row = new LinearLayout(this);
            row.setOrientation(LinearLayout.HORIZONTAL);
            for (int i = 1; i < module.length; i++) {
                String value = module[i];
                Button chip = nativeButton(value, isAiPresetSelected(module[0], value));
                final String category = module[0];
                chip.setMinHeight(dp(44));
                chip.setOnClickListener(v -> {
                    toggleAiPreset(category, value);
                    chip.setBackground(rounded(
                            isAiPresetSelected(category, value) ? COBALT_SOFT : SURFACE,
                            8,
                            isAiPresetSelected(category, value) ? COBALT : RULE));
                    setComposedAiPrompt(promptInput);
                    aiStatus.setText((isAiPresetSelected(category, value) ? "已选择 · " : "已取消 · ") + value);
                });
                LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(
                        ViewGroup.LayoutParams.WRAP_CONTENT, dp(44));
                if (i > 1) params.setMargins(dp(6), 0, 0, 0);
                row.addView(chip, params);
            }
            scroll.addView(row);
            container.addView(scroll, marginParams(-1, dp(44), 0, 0, 0, 6));
        }
        return container;
    }

    private boolean isAiPresetSelected(String category, String value) {
        return aiSelectedPresetKeys.contains(category + "\u001f" + value);
    }

    private void toggleAiPreset(String category, String value) {
        String key = category + "\u001f" + value;
        boolean wasSelected = aiSelectedPresetKeys.contains(key);
        aiSelectedPresetKeys.removeIf(item -> item.startsWith(category + "\u001f"));
        if (!wasSelected) aiSelectedPresetKeys.add(key);
    }

    private String composeAiPrompt() {
        List<String> groups = new ArrayList<>();
        if (!aiManualPrompt.isEmpty()) groups.add(aiManualPrompt);
        String[] categories = {
                "主体", "光线", "色彩", "质感", "构图", "智能移除", "约束"
        };
        for (String category : categories) {
            List<String> values = new ArrayList<>();
            for (String key : aiSelectedPresetKeys) {
                String prefix = category + "\u001f";
                if (key.startsWith(prefix)) values.add(key.substring(prefix.length()));
            }
            if (!values.isEmpty()) groups.add(category + "：" + String.join("、", values));
        }
        return String.join("。", groups);
    }

    private void setComposedAiPrompt(EditText input) {
        aiPrompt = composeAiPrompt();
        suppressAiPromptChange = true;
        input.setText(aiPrompt);
        input.setSelection(input.length());
        suppressAiPromptChange = false;
    }

    private AiImageResponse callAiImageApi(
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
        // W13-d 2A：AI 激活请求带有效 session 则加 Bearer（服务端记录账号↔设备↔激活码三元组）；
        // 无 token 不影响存量流程。
        String authToken = authManager == null ? null : authManager.getToken();
        if ("https".equalsIgnoreCase(endpoint.getProtocol())
                && authToken != null && !authToken.isEmpty()) {
            conn.setRequestProperty("Authorization", "Bearer " + authToken);
        }
        conn.setConnectTimeout(15_000);
        // Leave headroom around the proxy's polling and image-download
        // windows so a successful long-running job is not abandoned early.
        conn.setReadTimeout(300_000);
        conn.setDoOutput(true);

        org.json.JSONObject body = new org.json.JSONObject();
        body.put("activationCode", activationCode);
        body.put("deviceId", deviceId);
        body.put("prompt", prompt);
        body.put("size", size);
        if (sourcePath != null && !sourcePath.isEmpty()) {
            File source = new File(sourcePath);
            byte[] srcBytes = java.nio.file.Files.readAllBytes(source.toPath());
            if (srcBytes.length == 0) {
                throw new Exception("原图为空，未发送 AI 修图请求");
            }
            String b64 = android.util.Base64.encodeToString(
                    srcBytes, android.util.Base64.NO_WRAP);
            body.put("image", "data:" + imageMimeType(source.getName())
                    + ";base64," + b64);
        }

        java.io.OutputStream os = conn.getOutputStream();
        os.write(body.toString().getBytes("UTF-8"));
        os.close();

        int code = conn.getResponseCode();
        if (code != 200) {
            String detail = null;
            java.io.InputStream errorStream = conn.getErrorStream();
            if (errorStream != null) {
                try {
                    byte[] errorBytes = readAllBytes(errorStream);
                    org.json.JSONObject errorJson = new org.json.JSONObject(
                            new String(errorBytes, java.nio.charset.StandardCharsets.UTF_8));
                    detail = errorJson.optString("error", null);
                } catch (Exception ignored) {
                    // Fall through to the status-specific message below.
                } finally {
                    errorStream.close();
                }
            }
            conn.disconnect();
            if (detail != null && !detail.isEmpty()) throw new Exception(detail);
            if (code == 403) throw new Exception("激活码无效或次数用完");
            if (code == 429) throw new Exception("请求太频繁，请稍后重试");
            if (code == 502) throw new Exception("AI 服务暂时不可用");
            throw new Exception("API 服务返回错误 " + code);
        }

        Integer remaining = parseAiRemaining(conn.getHeaderField("X-ZENCHE-Remaining"));
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
            return new AiImageResponse(
                    android.util.Base64.decode(b64Json, android.util.Base64.DEFAULT),
                    remaining);
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
            return new AiImageResponse(data, remaining);
        }
        throw new Exception("AI 未返回有效图片");
    }

    private AiRebindResponse callAiRebind(
            String oldCode,
            String oldDeviceId,
            String newDeviceId) throws Exception {
        java.net.URL endpoint = new java.net.URL(AI_REBIND_URL);
        if (!"https".equalsIgnoreCase(endpoint.getProtocol())) {
            throw new Exception("设备码恢复地址无效");
        }
        java.net.HttpURLConnection connection =
                (java.net.HttpURLConnection) endpoint.openConnection();
        try {
            connection.setRequestMethod("POST");
            connection.setRequestProperty("Content-Type", "application/json");
            connection.setConnectTimeout(15_000);
            connection.setReadTimeout(30_000);
            connection.setDoOutput(true);

            org.json.JSONObject body = new org.json.JSONObject();
            body.put("activationCode", oldCode);
            body.put("oldDeviceId", oldDeviceId);
            body.put("newDeviceId", newDeviceId);
            try (java.io.OutputStream output = connection.getOutputStream()) {
                output.write(body.toString().getBytes(
                        java.nio.charset.StandardCharsets.UTF_8));
            }

            int status = connection.getResponseCode();
            java.io.InputStream stream = status >= 200 && status < 300
                    ? connection.getInputStream()
                    : connection.getErrorStream();
            byte[] bytes = stream == null
                    ? new byte[0]
                    : readLimitedBytes(stream, AI_REBIND_RESPONSE_LIMIT);
            if (stream != null) stream.close();
            org.json.JSONObject response = bytes.length == 0
                    ? new org.json.JSONObject()
                    : new org.json.JSONObject(new String(
                            bytes,
                            java.nio.charset.StandardCharsets.UTF_8));
            if (status < 200 || status >= 300) {
                String detail = response.optString("error", "").trim();
                if (!detail.isEmpty()) throw new Exception(detail);
                throw new Exception("设备码恢复服务返回错误 " + status);
            }
            String newCode = response.optString("newCode", "").trim();
            if (newCode.isEmpty() || !response.has("remaining")) {
                throw new Exception("设备码恢复响应无效");
            }
            int remaining = response.getInt("remaining");
            if (remaining < 0 || remaining > AI_MAX_USAGE) {
                throw new Exception("设备码恢复响应无效");
            }
            return new AiRebindResponse(newCode, remaining);
        } finally {
            connection.disconnect();
        }
    }

    private static Integer parseAiRemaining(String value) {
        if (value == null) return null;
        try {
            int remaining = Integer.parseInt(value.trim());
            return Math.max(0, Math.min(AI_MAX_USAGE, remaining));
        } catch (NumberFormatException ignored) {
            return null;
        }
    }

    private static String imageMimeType(String filename) {
        String ext = filename == null ? "" : filename.toLowerCase(Locale.US);
        if (ext.endsWith(".png")) return "image/png";
        if (ext.endsWith(".heic") || ext.endsWith(".heif")) return "image/heic";
        if (ext.endsWith(".tif") || ext.endsWith(".tiff")) return "image/tiff";
        if (ext.endsWith(".bmp")) return "image/bmp";
        return "image/jpeg";
    }

    private void setAiRemainingUsage(int remaining) {
        int bounded = Math.max(0, Math.min(AI_MAX_USAGE, remaining));
        aiUsageCount = AI_MAX_USAGE - bounded;
        aiUsageLoaded = true;
        aiActivated = bounded > 0;
        getSharedPreferences("nikon-link", MODE_PRIVATE)
                .edit()
                .putInt("ai_usage_count", aiUsageCount)
                .putBoolean("ai_activated", aiActivated)
                .apply();
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

    private static byte[] readLimitedBytes(
            java.io.InputStream input,
            int maximumBytes) throws Exception {
        java.io.ByteArrayOutputStream buffer = new java.io.ByteArrayOutputStream();
        byte[] chunk = new byte[4096];
        int total = 0;
        int read;
        while ((read = input.read(chunk)) != -1) {
            total += read;
            if (total > maximumBytes) {
                throw new Exception("设备码恢复响应过大");
            }
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

    private View createEditorWheel(
            String title,
            int tint,
            int initialX,
            int initialY,
            BiConsumer<Integer, Integer> setter,
            Runnable refreshPreview) {
        LinearLayout column = new LinearLayout(this);
        column.setOrientation(LinearLayout.VERTICAL);
        column.setGravity(Gravity.CENTER_HORIZONTAL);
        EditorWheelView wheel = new EditorWheelView(this, tint, initialX, initialY, (x, y) -> {
            setter.accept(x, y);
            refreshPreview.run();
        });
        column.addView(wheel, new LinearLayout.LayoutParams(dp(82), dp(82)));
        TextView label = text(title, TS_CAPTION, Typeface.BOLD, INK);
        label.setGravity(Gravity.CENTER);
        column.addView(label, new LinearLayout.LayoutParams(-1, dp(20)));
        TextView value = text(String.format(Locale.ROOT, "%+d, %+d", initialX, initialY), EDITOR_FS_SMALL, Typeface.NORMAL, MUTED);
        value.setGravity(Gravity.CENTER);
        wheel.setValueLabel(value);
        column.addView(value, new LinearLayout.LayoutParams(-1, dp(18)));
        return column;
    }

    private View createEditorCurvePad(Runnable refreshPreview) {
        return new EditorCurveView(this, editorAdjustments, refreshPreview);
    }

    private final class EditorWheelView extends View {
        private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final int tint;
        private int xValue;
        private int yValue;
        private final BiConsumer<Integer, Integer> onValue;
        private TextView valueLabel;

        EditorWheelView(Context context, int tint, int initialX, int initialY, BiConsumer<Integer, Integer> onValue) {
            super(context);
            this.tint = tint;
            this.xValue = initialX;
            this.yValue = initialY;
            this.onValue = onValue;
            setContentDescription("直接拖动色轮调节");
        }

        void setValueLabel(TextView label) { valueLabel = label; }

        @Override protected void onDraw(Canvas canvas) {
            super.onDraw(canvas);
            float cx = getWidth() / 2f;
            float cy = getHeight() / 2f;
            float radius = Math.min(getWidth(), getHeight()) * 0.39f;
            paint.setStyle(Paint.Style.STROKE);
            paint.setStrokeWidth(dp(5));
            paint.setShader(new android.graphics.SweepGradient(cx, cy,
                    new int[]{Color.RED, Color.YELLOW, Color.GREEN, Color.CYAN, Color.BLUE, Color.MAGENTA, Color.RED}, null));
            canvas.drawCircle(cx, cy, radius, paint);
            paint.setShader(null);
            paint.setStyle(Paint.Style.FILL);
            paint.setColor(GRAPHITE);
            canvas.drawCircle(cx, cy, radius - dp(6), paint);
            paint.setColor(tint);
            float knobX = cx + (xValue / 100f) * radius * 0.72f;
            float knobY = cy - (yValue / 100f) * radius * 0.72f;
            canvas.drawCircle(knobX, knobY, dp(6), paint);
        }

        @Override public boolean onTouchEvent(MotionEvent event) {
            if (event.getAction() == MotionEvent.ACTION_DOWN || event.getAction() == MotionEvent.ACTION_MOVE) {
                float cx = getWidth() / 2f;
                float cy = getHeight() / 2f;
                float radius = Math.min(getWidth(), getHeight()) * 0.39f;
                float dx = Math.max(-1f, Math.min(1f, (event.getX() - cx) / (radius * 0.72f)));
                float dy = Math.max(-1f, Math.min(1f, (cy - event.getY()) / (radius * 0.72f)));
                xValue = Math.round(dx * 100);
                yValue = Math.round(dy * 100);
                if (valueLabel != null) valueLabel.setText(String.format(Locale.ROOT, "%+d, %+d", xValue, yValue));
                onValue.accept(xValue, yValue);
                invalidate();
                return true;
            }
            return event.getAction() == MotionEvent.ACTION_UP;
        }
    }

    private final class EditorCurveView extends View {
        private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final EditorAdjustments settings;
        private final Runnable refreshPreview;
        private int activePoint = -1;

        EditorCurveView(Context context, EditorAdjustments settings, Runnable refreshPreview) {
            super(context);
            this.settings = settings;
            this.refreshPreview = refreshPreview;
            setContentDescription("直接拖动曲线控制点调节");
        }

        @Override protected void onDraw(Canvas canvas) {
            super.onDraw(canvas);
            float w = getWidth();
            float h = getHeight();
            paint.setStyle(Paint.Style.FILL);
            paint.setColor(GRAPHITE);
            canvas.drawRoundRect(0, 0, w, h, dp(8), dp(8), paint);
            paint.setStyle(Paint.Style.STROKE);
            paint.setStrokeWidth(dp(1));
            paint.setColor(WHITE_MIST);
            canvas.drawLine(0, h, w, 0, paint);
            paint.setStyle(Paint.Style.STROKE);
            paint.setStrokeWidth(dp(2));
            paint.setColor(COBALT);
            android.graphics.Path path = new android.graphics.Path();
            ArrayList<EditorCurvePoint> points = new ArrayList<>(settings.curvePoints);
            Collections.sort(points, (a, b) -> Float.compare(a.x, b.x));
            if (points.isEmpty()) points.add(new EditorCurvePoint(0, 0));
            path.moveTo(points.get(0).x * w, (1 - points.get(0).y) * h);
            for (int i = 0; i < points.size() - 1; i++) {
                EditorCurvePoint p0 = points.get(Math.max(0, i - 1));
                EditorCurvePoint p1 = points.get(i);
                EditorCurvePoint p2 = points.get(i + 1);
                EditorCurvePoint p3 = points.get(Math.min(points.size() - 1, i + 2));
                float c1x = p1.x + (p2.x - p0.x) / 6f;
                float c1y = p1.y + (p2.y - p0.y) / 6f;
                float c2x = p2.x - (p3.x - p1.x) / 6f;
                float c2y = p2.y - (p3.y - p1.y) / 6f;
                path.cubicTo(c1x * w, (1 - c1y) * h, c2x * w, (1 - c2y) * h, p2.x * w, (1 - p2.y) * h);
            }
            canvas.drawPath(path, paint);
            paint.setStyle(Paint.Style.FILL);
            for (EditorCurvePoint point : settings.curvePoints) {
                paint.setColor(COBALT);
                canvas.drawCircle(point.x * w, (1 - point.y) * h, dp(5), paint);
            }
        }

        @Override public boolean onTouchEvent(MotionEvent event) {
            if (event.getAction() == MotionEvent.ACTION_DOWN || event.getAction() == MotionEvent.ACTION_MOVE) {
                float x = Math.max(0, Math.min(getWidth(), event.getX())) / Math.max(1, getWidth());
                float y = Math.max(0, Math.min(getHeight(), event.getY())) / Math.max(1, getHeight());
                float normalizedY = 1 - y;
                if (event.getAction() == MotionEvent.ACTION_DOWN) {
                    activePoint = -1;
                    float best = .06f * .06f;
                    for (int i = 0; i < settings.curvePoints.size(); i++) {
                        EditorCurvePoint point = settings.curvePoints.get(i);
                        float dx = point.x - x;
                        float dy = point.y - normalizedY;
                        float distance = dx * dx + dy * dy;
                        if (distance < best) { best = distance; activePoint = i; }
                    }
                    if (activePoint < 0) {
                        settings.curvePoints.add(new EditorCurvePoint(x, normalizedY));
                        activePoint = settings.curvePoints.size() - 1;
                    }
                }
                if (activePoint >= 0 && activePoint < settings.curvePoints.size()) {
                    EditorCurvePoint point = settings.curvePoints.get(activePoint);
                    point.x = x;
                    point.y = normalizedY;
                }
                refreshPreview.run();
                invalidate();
                return true;
            }
            return event.getAction() == MotionEvent.ACTION_UP;
        }
    }

    private void addEditorAIMetric(
            LinearLayout parent,
            String title,
            double value) {
        TextView metric = text(
                tr(title) + "\n"
                        + Math.round(Math.max(0, Math.min(1, value)) * 100)
                        + "%",
                10,
                Typeface.BOLD,
                INK);
        metric.setGravity(Gravity.CENTER_VERTICAL);
        metric.setPadding(dp(8), 0, dp(8), 0);
        metric.setBackground(rounded(SURFACE, 8, 1));
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(0, dp(46), 1f);
        params.setMargins(0, 0, dp(6), 0);
        parent.addView(metric, params);
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

    private void showNikonCloudPresetPicker() {
        showStableNikonCloudPresetPicker(false);
    }

    private View buildNikonCloudMonitorPanel() {
        LinearLayout card = new LinearLayout(this);
        card.setOrientation(LinearLayout.VERTICAL);
        card.setPadding(dp(12), dp(12), dp(12), dp(10));
        boolean darkSurface = "monitor".equals(currentSection);
        int cardColor = darkSurface ? Color.rgb(24, 36, 52) : COBALT_SOFT;
        int borderColor = darkSurface ? Color.rgb(48, 78, 112) : COBALT;
        int primaryText = darkSurface ? Color.WHITE : INK;
        int secondaryText = darkSurface ? Color.WHITE : MUTED; // v1.5.7 issue 655a0a14: 视频页云创卡近白灰改纯白
        card.setBackground(rounded(cardColor, 14, borderColor));

        LinearLayout header = new LinearLayout(this);
        header.setOrientation(LinearLayout.HORIZONTAL);
        header.setGravity(Gravity.CENTER_VERTICAL);

        TextView badge = text("NP3", TS_CAPTION, Typeface.BOLD, Color.WHITE);
        badge.setGravity(Gravity.CENTER);
        badge.setTypeface(Typeface.MONOSPACE, Typeface.BOLD);
        badge.setBackground(rounded(COBALT, 12, 0));
        header.addView(badge, new LinearLayout.LayoutParams(dp(40), dp(40)));

        LinearLayout labels = new LinearLayout(this);
        labels.setOrientation(LinearLayout.VERTICAL);
        labels.setPadding(dp(12), 0, dp(8), 0);
        labels.addView(text("尼康云创监看", EDITOR_FS_SUB, Typeface.BOLD, primaryText));
        TextView selected = text(
                monitorNikonCloudPreset == null
                        ? "已关闭"
                        : monitorNikonCloudPreset.name,
                TS_CAPTION,
                Typeface.NORMAL,
                secondaryText);
        selected.setSingleLine(true);
        selected.setEllipsize(android.text.TextUtils.TruncateAt.END);
        labels.addView(selected);
        header.addView(labels, new LinearLayout.LayoutParams(0, dp(42), 1f));

        Button picker = nativeButton("选择预设", true);
        picker.setOnClickListener(view -> showNikonCloudMonitorPresetPicker());
        header.addView(picker, new LinearLayout.LayoutParams(dp(132), dp(44)));
        card.addView(header, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT));

        TextView note = text(
                "照片与视频实时生效 · SDR 近似 · 不写入原片",
                TS_CAPTION,
                Typeface.NORMAL,
                secondaryText);
        note.setPadding(0, dp(7), 0, 0);
        card.addView(note, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT));
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT);
        params.setMargins(0, dp(8), 0, dp(4));
        card.setLayoutParams(params);
        return card;
    }

    private void showNikonCloudMonitorPresetPicker() {
        showStableNikonCloudPresetPicker(true);
    }

    private void showStableNikonCloudPresetPicker(boolean monitorPicker) {
        if (isFinishing() || isDestroyed()) return;
        if (nikonCloudPresetDialog != null
                && nikonCloudPresetDialog.isShowing()) {
            return;
        }
        String[] labels = new String[nikonCloudPresets.size() + 1];
        labels[0] = tr(monitorPicker
                ? "关闭云创监看"
                : "关闭云创预览");
        for (int index = 0; index < nikonCloudPresets.size(); index++) {
            NikonCloudPreview.Preset preset = nikonCloudPresets.get(index);
            labels[index + 1] = preset.name
                    + (preset.hasCustomToneCurve ? " · Curve" : "");
        }
        NikonCloudPreview.Preset current = monitorPicker
                ? monitorNikonCloudPreset
                : selectedNikonCloudPreset;
        int selectedIndex = current == null ? 0 : 1;
        if (current != null) {
            for (int index = 0; index < nikonCloudPresets.size(); index++) {
                if (nikonCloudPresets.get(index).id.equals(current.id)) {
                    selectedIndex = index + 1;
                    break;
                }
            }
        }
        final int[] pendingSelection = {selectedIndex};
        AlertDialog dialog = new AlertDialog.Builder(this)
                .setTitle(tr(monitorPicker
                                ? "尼康云创监看"
                                : "尼康云创预览") + " · "
                        + nikonCloudPresets.size() + " NP3")
                .setSingleChoiceItems(
                        labels,
                        selectedIndex,
                        (pickerDialog, which) -> pendingSelection[0] = which)
                .setPositiveButton(tr("应用"), null)
                .setNegativeButton(tr("取消"), null)
                .create();
        nikonCloudPresetDialog = dialog;
        dialog.setOnShowListener(ignored -> {
            dialog.getButton(DialogInterface.BUTTON_POSITIVE)
                    .setOnClickListener(view -> {
                        int index = pendingSelection[0];
                        if (monitorPicker) {
                            monitorNikonCloudPreset = index == 0
                                    ? null
                                    : nikonCloudPresets.get(index - 1);
                            showSection(currentSection);
                            refreshPreviewProcessing();
                            showToast(monitorNikonCloudPreset == null
                                    ? "尼康云创监看已关闭"
                                    : "尼康云创监看 · "
                                            + monitorNikonCloudPreset.name
                                            + " · 照片/视频 · SDR 近似");
                        } else {
                            if (index == 0) {
                                selectedNikonCloudPreset = null;
                                applyEditorPreset("original");
                            } else {
                                applyNikonCloudPreset(
                                        nikonCloudPresets.get(index - 1));
                            }
                            showSection("editor");
                        }
                        dialog.dismiss();
                    });
        });
        dialog.setOnDismissListener(ignored -> {
            if (nikonCloudPresetDialog == dialog) {
                nikonCloudPresetDialog = null;
            }
        });
        dialog.show();
        if (dialog.getListView() != null) {
            dialog.getListView().setFastScrollEnabled(true);
            dialog.getListView().setDividerHeight(dp(1));
        }
        Window window = dialog.getWindow();
        if (window != null) {
            int width = Math.min(
                    getResources().getDisplayMetrics().widthPixels - dp(32),
                    dp(560));
            int height = Math.min(
                    (int) (getResources().getDisplayMetrics().heightPixels * .78f),
                    dp(680));
            window.setLayout(width, height);
        }
    }

    private void applyNikonCloudPreset(NikonCloudPreview.Preset preset) {
        editorAdjustments.resetTone();
        NikonCloudPreview.Tone tone = preset.tone;
        editorAdjustments.contrast = tone.contrast;
        editorAdjustments.highlights = tone.highlights;
        editorAdjustments.shadows = tone.shadows;
        editorAdjustments.whites = tone.whites;
        editorAdjustments.blacks = tone.blacks;
        editorAdjustments.saturation = tone.saturation;
        editorAdjustments.texture = tone.texture;
        editorAdjustments.clarity = tone.clarity;
        editorAdjustments.sharpening = tone.sharpening;
        editorAdjustments.wheelLiftX = preset.grading.lift.x;
        editorAdjustments.wheelLiftY = preset.grading.lift.y;
        editorAdjustments.wheelGammaX = preset.grading.gamma.x;
        editorAdjustments.wheelGammaY = preset.grading.gamma.y;
        editorAdjustments.wheelGainX = preset.grading.gain.x;
        editorAdjustments.wheelGainY = preset.grading.gain.y;
        if (preset.toneCurve.size() > 1) {
            editorAdjustments.curvePoints.clear();
            double denominator = preset.toneCurve.size() - 1.0;
            for (int index = 0; index < preset.toneCurve.size(); index++) {
                editorAdjustments.curvePoints.add(new EditorCurvePoint(
                        (float)(index / denominator),
                        (float)Math.max(0, Math.min(
                                1,
                                preset.toneCurve.get(index)))));
            }
        }
        selectedNikonCloudPreset = preset;
        editorSettingsBeforeAI = null;
        editorAIAnalysis = null;
        editorAISummary = "等待分析当前照片";
        editorAdjustments.showingOriginal = false;
        showToast("尼康云创预览 · " + preset.name + " · SDR 近似");
    }

    private void applyEditorPreset(String preset) {
        selectedNikonCloudPreset = null;
        editorAdjustments.resetTone();
        editorSettingsBeforeAI = null;
        editorAIAnalysis = null;
        editorAISummary = "等待分析当前照片";
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

    private void applyEditorAI(
            EditorAIAnalysis analysis,
            double intensity) {
        selectedNikonCloudPreset = null;
        editorAdjustments.resetTone();
        double amount = Math.max(0.35, Math.min(1, intensity));
        double targetExposure = Math.max(
                -0.8,
                Math.min(
                        0.8,
                        Math.log(0.48 / Math.max(0.08, analysis.meanLuma))
                                / Math.log(2)
                                * 0.68));
        editorAdjustments.exposure = (int)Math.round(
                targetExposure * 100 * amount);
        editorAdjustments.contrast = editorAIValue(
                Math.max(-8, Math.min(24,
                        (0.20 - analysis.contrast) * 130)),
                amount);
        editorAdjustments.highlights = -editorAIValue(
                Math.max(6, Math.min(48,
                        analysis.highlightRatio * 360
                                + Math.max(0, analysis.meanLuma - 0.55) * 70)),
                amount);
        editorAdjustments.shadows = editorAIValue(
                Math.max(6, Math.min(46,
                        analysis.shadowRatio * 330
                                + Math.max(0, 0.44 - analysis.meanLuma) * 75)),
                amount);
        editorAdjustments.whites = editorAIValue(
                Math.max(-8, Math.min(14,
                        (0.58 - analysis.meanLuma) * 28)),
                amount);
        editorAdjustments.blacks = -editorAIValue(
                Math.max(4, Math.min(18,
                        (0.21 - analysis.contrast) * 55 + 5)),
                amount);
        editorAdjustments.temperature = editorAIValue(
                Math.max(-18, Math.min(18,
                        (analysis.blue - analysis.red) * 95)),
                amount);
        double greenExcess = analysis.green
                - (analysis.red + analysis.blue) / 2;
        editorAdjustments.tint = editorAIValue(
                Math.max(-14, Math.min(14, greenExcess * 85)),
                amount);
        editorAdjustments.vibrance = editorAIValue(
                Math.max(4, Math.min(26,
                        (0.30 - analysis.saturation) * 95 + 6)),
                amount);
        editorAdjustments.saturation = editorAIValue(
                Math.max(-4, Math.min(8,
                        (0.22 - analysis.saturation) * 28)),
                amount);
        editorAdjustments.texture = editorAIValue(
                Math.max(4, Math.min(16,
                        (0.075 - analysis.detail) * 170 + 7)),
                amount);
        editorAdjustments.clarity = editorAIValue(
                Math.max(3, Math.min(18,
                        (0.19 - analysis.contrast) * 70 + 6)),
                amount);
        editorAdjustments.sharpening = editorAIValue(
                Math.max(14, Math.min(34,
                        (0.08 - analysis.detail) * 210 + 20)),
                amount);
        editorAdjustments.noiseReduction = editorAIValue(
                Math.max(6, Math.min(30,
                        analysis.shadowRatio * 120
                                + Math.max(0, 0.38 - analysis.meanLuma) * 42
                                + 6)),
                amount);
        editorAdjustments.dehaze = editorAIValue(
                Math.max(0, Math.min(16,
                        (0.18 - analysis.contrast) * 75)),
                amount);
        editorAdjustments.showingOriginal = false;
    }

    private static int editorAIValue(double value, double amount) {
        return (int)Math.round(value * amount);
    }

    /** E8 1.5.9: 把当前复制的 AI 调整方案批量应用到整个文件库照片，
     *  逐张本地渲染 + JPEG 副本（0 服务器消耗），进度可见可取消，
     *  单张失败跳过计数不整批失败。 */
    private void applyAIBatch() {
        if (editorAICopiedSettings == null) return;
        List<File> targets = new ArrayList<>();
        for (File file : photoFiles()) {
            if (isEditableImageFile(file)) targets.add(file);
        }
        if (targets.isEmpty()) {
            showToast("文件库没有可编辑照片");
            return;
        }
        aiBatchApplying = true;
        aiBatchCancelled = false;
        aiBatchProgress = 0;
        aiBatchTotal = targets.size();
        aiBatchSkipped = 0;
        showToast("批量应用 AI 调整 · 本地处理零消耗 · 共 " + targets.size() + " 张");
        editorExecutor.execute(() -> {
            int skipped = 0;
            for (int index = 0; index < targets.size(); index++) {
                final int cancelledAt = index;
                if (aiBatchCancelled) {
                    mainHandler.post(() -> {
                        aiBatchApplying = false;
                        showToast("批量应用已取消 · 完成 " + cancelledAt + "/" + targets.size());
                    });
                    return;
                }
                File source = targets.get(index);
                EditorAdjustments saved = editorAICopiedSettings.copy();
                saved.showingOriginal = false;
                Bitmap output = renderEditedBitmap(source, saved, 4096);
                boolean ok = false;
                if (output != null) {
                    File destination = uniqueEditedFile(source);
                    try (FileOutputStream stream =
                                 new FileOutputStream(destination)) {
                        ok = output.compress(
                                Bitmap.CompressFormat.JPEG, 95, stream);
                    } catch (Exception error) {
                        diagnostics.error(
                                "editor-batch",
                                "批量应用失败：" + error.getMessage());
                    }
                    output.recycle();
                }
                if (!ok) skipped++;
                final int done = index + 1;
                final int skippedSnapshot = skipped;
                mainHandler.post(() -> {
                    aiBatchProgress = done;
                    aiBatchSkipped = skippedSnapshot;
                });
            }
            final int total = targets.size();
            final int skippedFinal = skipped;
            mainHandler.post(() -> {
                aiBatchApplying = false;
                updateFileCount();
                showToast("批量应用完成 · "
                        + (total - skippedFinal) + " 张已保存 · 跳过 " + skippedFinal);
            });
        });
    }

    private EditorAIAnalysis analyzeEditorPhoto(File file) {
        Bitmap bitmap = renderEditorAnalysisBitmap(file, 128);
        if (bitmap == null) return null;
        int width = bitmap.getWidth();
        int height = bitmap.getHeight();
            int[] pixels = new int[width * height];
        bitmap.getPixels(pixels, 0, width, 0, 0, width, height);
        bitmap.recycle();
        EditorAIAnalysis analysis = new EditorAIAnalysis();
        double[] lumas = new double[pixels.length];
        double lumaSum = 0;
        int shadows = 0;
        int highlights = 0;
        for (int index = 0; index < pixels.length; index++) {
            int color = pixels[index];
            double red = Color.red(color) / 255.0;
            double green = Color.green(color) / 255.0;
            double blue = Color.blue(color) / 255.0;
            double luma = red * 0.2126 + green * 0.7152 + blue * 0.0722;
            lumas[index] = luma;
            lumaSum += luma;
            analysis.red += red;
            analysis.green += green;
            analysis.blue += blue;
            analysis.saturation += Math.max(red, Math.max(green, blue))
                    - Math.min(red, Math.min(green, blue));
            if (luma < 0.10) shadows++;
            if (luma > 0.90) highlights++;
        }
        double count = pixels.length;
        analysis.meanLuma = lumaSum / count;
        double variance = 0;
        double detail = 0;
        for (int y = 0; y < height; y++) {
            for (int x = 0; x < width; x++) {
                int index = y * width + x;
                double delta = lumas[index] - analysis.meanLuma;
                variance += delta * delta;
                if (x > 0) {
                    detail += Math.abs(lumas[index] - lumas[index - 1]);
                }
            }
        }
        analysis.contrast = Math.sqrt(variance / count);
        analysis.shadowRatio = shadows / count;
        analysis.highlightRatio = highlights / count;
        analysis.saturation /= count;
        analysis.red /= count;
        analysis.green /= count;
        analysis.blue /= count;
        analysis.detail = detail / Math.max(1, height * (width - 1));
        return analysis;
    }

    private Bitmap renderEditorAnalysisBitmap(
            File file,
            int maximumDimension) {
        return EditorBitmapDecoder.decode(file, maximumDimension);
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
        TextView label = text(title, EDITOR_FS_SUB, Typeface.BOLD, INK);
        row.addView(label, new LinearLayout.LayoutParams(dp(86), dp(48)));
        SeekBar slider = new SeekBar(this);
        slider.setMax(maximum - minimum);
        slider.setProgress(currentValue - minimum);
        TextView value = text(
                editorAdjustmentValue(currentValue, exposure),
                TS_CAPTION,
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
                text("裁切比例", TS_BODY, Typeface.BOLD, MUTED),
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

    private static double curveValue(ArrayList<EditorCurvePoint> source, double input) {
        ArrayList<EditorCurvePoint> points = new ArrayList<>(source);
        Collections.sort(points, (a, b) -> Float.compare(a.x, b.x));
        double x = Math.max(0, Math.min(1, input));
        if (points.size() < 2) return x;
        if (x <= points.get(0).x) return points.get(0).y;
        if (x >= points.get(points.size() - 1).x) return points.get(points.size() - 1).y;
        int index = 1;
        while (index < points.size() && points.get(index).x < x) index++;
        EditorCurvePoint p0 = points.get(Math.max(0, index - 2));
        EditorCurvePoint p1 = points.get(index - 1);
        EditorCurvePoint p2 = points.get(index);
        EditorCurvePoint p3 = points.get(Math.min(points.size() - 1, index + 1));
        double t = (x - p1.x) / Math.max(.0001, p2.x - p1.x);
        double t2 = t * t;
        double t3 = t2 * t;
        double y = .5 * (2 * p1.y + (-p0.y + p2.y) * t
                + (2 * p0.y - 5 * p1.y + 4 * p2.y - p3.y) * t2
                + (-p0.y + 3 * p1.y - 3 * p2.y + p3.y) * t3);
        return Math.max(0, Math.min(1, y));
    }

    private Bitmap renderEditedBitmap(
            File file,
            EditorAdjustments settings,
            int maximumDimension) {
        Bitmap source = EditorBitmapDecoder.decode(file, maximumDimension);
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
        double[] cloudChannels = selectedNikonCloudPreset == null
                ? null
                : new double[3];
        double[] cloudHsl = selectedNikonCloudPreset == null
                ? null
                : new double[3];
        for (int index = 0; index < pixels.length; index++) {
            int color = pixels[index];
            double red = Color.red(color) / 255.0 * exposure;
            double green = Color.green(color) / 255.0 * exposure;
            double blue = Color.blue(color) / 255.0 * exposure;

            red += temperature * 0.12 + tint * 0.045;
            green -= tint * 0.08;
            blue -= temperature * 0.12 - tint * 0.045;

            // Compact Lift/Gamma/Gain and curve controls.
            double luma =
                    red * 0.2126 + green * 0.7152 + blue * 0.0722;
            double shadowWeight = Math.pow(1 - clampUnit(luma), 2);
            double highlightWeight = Math.pow(clampUnit(luma), 2);
            double midWeight = 1 - Math.abs(clampUnit(luma) * 2 - 1);
            double wheelX = settings.wheelLiftX / 100.0 * 0.10 * shadowWeight
                    + settings.wheelGammaX / 100.0 * 0.10 * midWeight
                    + settings.wheelGainX / 100.0 * 0.10 * highlightWeight;
            double wheelY = settings.wheelLiftY / 100.0 * 0.10 * shadowWeight
                    + settings.wheelGammaY / 100.0 * 0.10 * midWeight
                    + settings.wheelGainY / 100.0 * 0.10 * highlightWeight;
            red += wheelX - wheelY * .5;
            green += wheelY - wheelX * .5;
            blue -= (wheelX + wheelY) * .5;
            luma = red * 0.2126 + green * 0.7152 + blue * 0.0722;
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

            if (settings.curvePoints.size() > 2) {
                double curveValue = curveValue(settings.curvePoints, luma);
                double delta = curveValue - luma;
                red += delta;
                green += delta;
                blue += delta;
            }

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

            if (cloudChannels != null) {
                cloudChannels[0] = red;
                cloudChannels[1] = green;
                cloudChannels[2] = blue;
                selectedNikonCloudPreset.applyColorMixer(
                        cloudChannels,
                        cloudHsl);
                red = cloudChannels[0];
                green = cloudChannels[1];
                blue = cloudChannels[2];
            }

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
        Bitmap geometryAdjusted = applyEditorGeometry(adjusted, settings);
        Bitmap result = geometryAdjusted;
        for (EditorMaskLayer layer : settings.effectiveMaskLayers()) {
            if (layer.visible && layer.type != null && !layer.type.isEmpty()) {
                result = applyEditorMaskAdjustments(result, layer);
            }
        }
        return result;
    }

    private Bitmap applyEditorMaskAdjustments(
            Bitmap base,
            EditorMaskLayer layer) {
        int width = base.getWidth();
        int height = base.getHeight();
        int[] original = new int[width * height];
        base.getPixels(original, 0, width, 0, 0, width, height);
        int[] local = original.clone();
        double exposure = Math.pow(2, layer.exposure / 100.0);
        double contrast = 1 + layer.contrast / 100.0;
        double saturation = Math.max(0, 1 + layer.saturation / 100.0);
        double temperature = layer.temperature / 100.0;
        double tint = layer.tint / 100.0;
        for (int index = 0; index < local.length; index++) {
            int color = original[index];
            double red = Color.red(color) / 255.0 * exposure;
            double green = Color.green(color) / 255.0 * exposure;
            double blue = Color.blue(color) / 255.0 * exposure;
            red += temperature * .12 + tint * .045;
            green -= tint * .08;
            blue -= temperature * .12 - tint * .045;
            double luma = red * .2126 + green * .7152 + blue * .0722;
            double tone = layer.shadows / 100.0
                    * Math.pow(1 - clampUnit(luma), 2) * .38
                    + layer.highlights / 100.0
                    * Math.pow(clampUnit(luma), 2) * .30;
            red += tone;
            green += tone;
            blue += tone;
            double clarityWeight = 1 - Math.abs(clampUnit(luma) * 2 - 1);
            double localContrast = contrast
                    * (1 + layer.clarity / 100.0 * clarityWeight * .38);
            red = (red - .5) * localContrast + .5;
            green = (green - .5) * localContrast + .5;
            blue = (blue - .5) * localContrast + .5;
            luma = red * .2126 + green * .7152 + blue * .0722;
            red = luma + (red - luma) * saturation;
            green = luma + (green - luma) * saturation;
            blue = luma + (blue - luma) * saturation;
            local[index] = Color.argb(
                    Color.alpha(color),
                    editorChannel(red * 255),
                    editorChannel(green * 255),
                    editorChannel(blue * 255));
        }
        byte[] mask = buildEditorMask(width, height, layer, original);
        double intensity = Math.max(0, Math.min(1, layer.amount / 100.0));
        for (int index = 0; index < local.length; index++) {
            double coverage = (mask[index] & 0xff) / 255.0;
            double amount = (layer.invert ? 1 - coverage : coverage)
                    * intensity;
            int originalColor = original[index];
            int localColor = local[index];
            local[index] = Color.argb(
                    Color.alpha(originalColor),
                    editorChannel(Color.red(originalColor)
                            + (Color.red(localColor) - Color.red(originalColor)) * amount),
                    editorChannel(Color.green(originalColor)
                            + (Color.green(localColor) - Color.green(originalColor)) * amount),
                    editorChannel(Color.blue(originalColor)
                            + (Color.blue(localColor) - Color.blue(originalColor)) * amount));
        }
        return Bitmap.createBitmap(local, width, height, Bitmap.Config.ARGB_8888);
    }

    private byte[] buildEditorMask(
            int width,
            int height,
            EditorMaskLayer layer,
            int[] sourcePixels) {
        byte[] mask = new byte[Math.max(1, width * height)];
        if (!"画笔".equals(layer.type)) {
            for (int index = 0; index < mask.length; index++) {
                int color = sourcePixels[index];
                double coverage = smartEditorMaskCoverage(
                        layer.type,
                        Color.red(color) / 255.0,
                        Color.green(color) / 255.0,
                        Color.blue(color) / 255.0,
                        index % width,
                        index / width,
                        width,
                        height);
                mask[index] = (byte) Math.max(0, Math.min(255,
                        (int) Math.round(coverage * 255)));
            }
        }
        for (EditorMaskStroke stroke : layer.strokes) {
            if (stroke.points.isEmpty()) continue;
            EditorMaskPoint previous = stroke.points.get(0);
            stampEditorMask(mask, width, height, previous, stroke, layer.feather);
            for (int index = 1; index < stroke.points.size(); index++) {
                EditorMaskPoint current = stroke.points.get(index);
                double dx = (current.x - previous.x) * width;
                double dy = (current.y - previous.y) * height;
                int radius = Math.max(1,
                        Math.round(stroke.size / 200f * Math.min(width, height)));
                int steps = Math.max(1,
                        (int) Math.ceil(Math.hypot(dx, dy) / Math.max(1, radius * .45)));
                for (int step = 1; step <= steps; step++) {
                    float progress = step / (float) steps;
                    stampEditorMask(
                            mask,
                            width,
                            height,
                            new EditorMaskPoint(
                                    previous.x + (current.x - previous.x) * progress,
                                    previous.y + (current.y - previous.y) * progress),
                            stroke,
                            layer.feather);
                }
                previous = current;
            }
        }
        int blurRadius = Math.min(24, Math.max(0, (int) Math.round(
                layer.feather / 100.0 * Math.min(width, height) * .015)));
        if (blurRadius > 0) blurEditorMask(mask, width, height, blurRadius);
        return mask;
    }

    private double smartEditorMaskCoverage(
            String type,
            double red,
            double green,
            double blue,
            int x,
            int y,
            int width,
            int height) {
        double luma = red * .2126 + green * .7152 + blue * .0722;
        double chroma = Math.max(red, Math.max(green, blue))
                - Math.min(red, Math.min(green, blue));
        double unitX = x / (double) Math.max(1, width - 1);
        double unitY = y / (double) Math.max(1, height - 1);
        double center = 1 - Math.min(1, Math.hypot(
                (unitX - .5) / .72,
                (unitY - .52) / .82));
        double subject = clampUnit(center * .72 + chroma * .72
                + Math.abs(luma - .5) * .18);
        if ("智能背景".equals(type)) return 1 - subject;
        if ("智能天空".equals(type)) {
            double top = clampUnit((.76 - unitY) / .62);
            double skyColor = clampUnit((blue - red * .88) * 2.5
                    + (blue - green * .78) * 1.6 + .18);
            return top * skyColor * smoothStep(.18, .82, luma);
        }
        if ("智能人物".equals(type)) {
            double skin = smoothStep(.02, .20, red - blue)
                    * smoothStep(-.05, .16, red - green)
                    * smoothStep(.16, .78, luma);
            return clampUnit(skin * .78 + subject * center * .42);
        }
        if ("智能亮部".equals(type)) return smoothStep(.55, .88, luma);
        if ("智能暗部".equals(type)) return 1 - smoothStep(.12, .48, luma);
        return subject;
    }

    private void blurEditorMask(
            byte[] mask,
            int width,
            int height,
            int radius) {
        byte[] horizontal = new byte[mask.length];
        int divisor = radius * 2 + 1;
        for (int y = 0; y < height; y++) {
            int sum = 0;
            for (int x = -radius; x <= radius; x++) {
                sum += mask[y * width + Math.max(0, Math.min(width - 1, x))] & 0xff;
            }
            for (int x = 0; x < width; x++) {
                horizontal[y * width + x] = (byte) (sum / divisor);
                int removeX = Math.max(0, x - radius);
                int addX = Math.min(width - 1, x + radius + 1);
                sum += (mask[y * width + addX] & 0xff)
                        - (mask[y * width + removeX] & 0xff);
            }
        }
        for (int x = 0; x < width; x++) {
            int sum = 0;
            for (int y = -radius; y <= radius; y++) {
                sum += horizontal[Math.max(0, Math.min(height - 1, y)) * width + x] & 0xff;
            }
            for (int y = 0; y < height; y++) {
                mask[y * width + x] = (byte) (sum / divisor);
                int removeY = Math.max(0, y - radius);
                int addY = Math.min(height - 1, y + radius + 1);
                sum += (horizontal[addY * width + x] & 0xff)
                        - (horizontal[removeY * width + x] & 0xff);
            }
        }
    }

    private void stampEditorMask(
            byte[] mask,
            int width,
            int height,
            EditorMaskPoint point,
            EditorMaskStroke stroke,
            int feather) {
        double radius = Math.max(1,
                stroke.size / 200.0 * Math.min(width, height));
        double softEdge = radius * Math.max(0, Math.min(100, feather)) / 100.0;
        double outerRadius = radius + softEdge;
        int centerX = Math.round(point.x * (width - 1));
        int centerY = Math.round(point.y * (height - 1));
        int extent = Math.max(1, (int) Math.ceil(outerRadius));
        for (int y = Math.max(0, centerY - extent);
                y <= Math.min(height - 1, centerY + extent);
                y++) {
            for (int x = Math.max(0, centerX - extent);
                    x <= Math.min(width - 1, centerX + extent);
                    x++) {
                double distance = Math.hypot(x - centerX, y - centerY);
                if (distance > outerRadius) continue;
                double coverage = distance <= radius || softEdge <= 0
                        ? 1
                        : 1 - (distance - radius) / softEdge;
                int offset = y * width + x;
                int current = mask[offset] & 0xff;
                int value = Math.max(0, Math.min(255,
                        (int) Math.round(coverage * 255)));
                mask[offset] = (byte) (stroke.subtract
                        ? Math.max(0, current - value)
                        : Math.max(current, value));
            }
        }
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
                    LIBRARY_FS_TITLE,
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
        if (key != null) group.setTag(key);
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
                text("用户分支", TS_EMPHASIS, Typeface.BOLD, INK),
                new LinearLayout.LayoutParams(0, dp(48), 1f));
        Button add = nativeButton("＋ 新建分支", false);
        add.setOnClickListener(view -> showCreateLibraryBranchDialog(null));
        heading.addView(add, new LinearLayout.LayoutParams(dp(132), dp(44)));
        tree.addView(heading);

        if (userLibraryBranches.isEmpty()) {
            tree.addView(
                    text(
                            "可建立项目、客户或拍摄日等分支；媒体仍保留在原始存储位置。",
                            TS_BODY,
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
                depth == 0 ? PAPER_2 : PAPER_3,
                10,
                RULE));
        Button toggle = nativeButton(expanded ? "⌄" : "›", false);
        TextView name = text(
                "▱  " + branch.name,
                LIBRARY_FS_TITLE,
                Typeface.BOLD,
                INK);
        List<File> assignedFiles = filesAssignedToBranch(branch.id, files);
        TextView count = text(
                assignedFiles.size() + " 文件",
                TS_CAPTION,
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
                    TS_BODY,
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
                depth == 0 ? PAPER_2 : PAPER_3,
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
                    LIBRARY_FS_SUB,
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
                    LIBRARY_FS_SUB,
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
        details.addView(text(entry.name, LIBRARY_FS_SUB, Typeface.BOLD, INK));
        String duration = entry.video
                ? " · " + formatDuration(entry.durationMillis)
                : "";
        details.addView(text(
                "系统相册 · " + humanSize(entry.size) + duration + " · "
                        + new SimpleDateFormat(
                                "MM-dd HH:mm",
                                Locale.CHINA).format(new Date(entry.dateMillis)),
                TS_CAPTION,
                Typeface.NORMAL,
                MUTED));
        details.addView(text(
                entry.video ? "双击播放视频" : "双击查看大图",
                TS_CAPTION,
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
        LinearLayout.LayoutParams rowParams = marginParams(-1, dp(160), 0, 0, 0, 10);
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
        row.addView(thumbnail, new LinearLayout.LayoutParams(dp(108), dp(140)));

        LinearLayout details = new LinearLayout(this);
        details.setOrientation(LinearLayout.VERTICAL);
        details.setPadding(dp(12), 0, dp(8), 0);
        details.addView(text(file.getName(), LIBRARY_FS_SUB, Typeface.BOLD, INK));
        details.addView(text(
                humanSize(file.length()) + " · " + new SimpleDateFormat(
                        "MM-dd HH:mm",
                        Locale.CHINA).format(new Date(file.lastModified())),
                TS_CAPTION,
                Typeface.NORMAL,
                MUTED));
        details.addView(text(
                isVideoFile(file) ? "双击播放视频" : "双击查看大图",
                TS_CAPTION,
                Typeface.NORMAL,
                COBALT));
        row.addView(details, new LinearLayout.LayoutParams(0, dp(140), 1f));

        LinearLayout actions = new LinearLayout(this);
        actions.setOrientation(LinearLayout.VERTICAL);
        Button edit = nativeButton("编辑", false);
        edit.setOnClickListener(view -> {
            editorSelectedPath = file.getAbsolutePath();
            editorState = EditorState.PRO;
            aiResultBitmap = null;
            showSection("editor");
        });
        actions.addView(edit, new LinearLayout.LayoutParams(dp(72), dp(44)));
        Button share = nativeButton("分享", false);
        share.setOnClickListener(view -> sharePhoto(file));
        LinearLayout.LayoutParams shareParams =
                new LinearLayout.LayoutParams(dp(72), dp(44));
        shareParams.setMargins(0, dp(4), 0, 0);
        actions.addView(share, shareParams);
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
                    updateFileCount();
                    showSection("library");
                })
                .show());
        LinearLayout.LayoutParams deleteParams =
                new LinearLayout.LayoutParams(dp(72), dp(44));
        deleteParams.setMargins(0, dp(4), 0, 0);
        actions.addView(delete, deleteParams);
        row.addView(actions, new LinearLayout.LayoutParams(dp(72), dp(140)));
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
        LinearLayout content = verticalContainer();
        content.addView(
                buildWifiCameraPanel(),
                marginParams(-1, -2, 0, 0, 0, 12));
        LinearLayout settings = panel();
        settings.addView(text("文件接收", TS_BODY, Typeface.BOLD, MUTED));
        settings.addView(text("多协议无线图片收件箱", TS_TITLE, Typeface.BOLD, INK));
        settings.addView(text(
                wirelessStatus,
                LIBRARY_FS_SUB,
                Typeface.NORMAL,
                MUTED),
                marginParams(-1, -2, 0, 3, 0, 12));

        wirelessAddressText = text(
                wirelessSettingsText(),
                LIBRARY_FS_SUB,
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
                TS_BODY,
                Typeface.NORMAL,
                MUTED);
        settings.addView(
                wirelessStatusText,
                marginParams(-1, -2, 0, 10, 0, 0));
        content.addView(settings);
        return content;
    }

    private View buildWifiCameraPanel() {
        LinearLayout wifiCard = panel();
        wifiCard.addView(text("相机控制", TS_BODY, Typeface.BOLD, MUTED));
        wifiCard.addView(text("Wi‑Fi 相机 · PTP/IP", TS_TITLE, Typeface.BOLD, INK));
        wifiCard.addView(text(
                "先在相机中开启无线遥控/PTP‑IP，并让手机加入相机热点或同一局域网。默认端口为 15740。",
                TS_BODY,
                Typeface.NORMAL,
                MUTED),
                marginParams(-1, -2, 0, 5, 0, 10));
        wifiCard.addView(text("连接模式", TS_BODY, Typeface.BOLD, INK));
        Spinner wifiMode = new Spinner(this);
        String[] wifiModeLabels = {tr("AP 直连"), tr("STA 局域网")};
        ArrayAdapter<String> wifiModeAdapter = new ArrayAdapter<>(
                this,
                android.R.layout.simple_spinner_item,
                wifiModeLabels);
        wifiModeAdapter.setDropDownViewResource(
                android.R.layout.simple_spinner_dropdown_item);
        wifiMode.setAdapter(wifiModeAdapter);
        wifiConnectionMode = getSharedPreferences("nikon-link", MODE_PRIVATE)
                .getString("wifiCameraConnectionMode", "ap");
        wifiMode.setSelection("sta".equals(wifiConnectionMode) ? 1 : 0);
        wifiMode.setEnabled(!wifiConnected && !wifiConnecting);
        wifiCard.addView(wifiMode, marginParams(-1, dp(48), 0, 0, 0, 4));
        TextView wifiModeHelp = text(
                "sta".equals(wifiConnectionMode)
                        ? "STA 模式：让相机与手机加入同一局域网，并输入路由器分配给相机的 IP 地址。"
                        : "AP 模式：让手机加入相机热点；相机地址通常为 192.168.1.1。",
                TS_BODY,
                Typeface.NORMAL,
                MUTED);
        wifiCard.addView(wifiModeHelp, marginParams(-1, -2, 0, 0, 0, 8));
        wifiMode.setOnItemSelectedListener(new AdapterView.OnItemSelectedListener() {
            @Override public void onItemSelected(
                    AdapterView<?> parent,
                    View view,
                    int position,
                    long id) {
                wifiConnectionMode = position == 1 ? "sta" : "ap";
                wifiModeHelp.setText(tr(
                        position == 1
                                ? "STA 模式：让相机与手机加入同一局域网，并输入路由器分配给相机的 IP 地址。"
                                : "AP 模式：让手机加入相机热点；相机地址通常为 192.168.1.1。"));
            }

            @Override public void onNothingSelected(AdapterView<?> parent) { }
        });
        LinearLayout wifiAddress = new LinearLayout(this);
        wifiAddress.setOrientation(LinearLayout.HORIZONTAL);
        EditText host = new EditText(this);
        host.setSingleLine(true);
        host.setInputType(InputType.TYPE_CLASS_PHONE);
        host.setText(getSharedPreferences("nikon-link", MODE_PRIVATE)
                .getString("wifiCameraHost", "192.168.1.1"));
        host.setHint(tr("相机 IP 地址"));
        wifiAddress.addView(host, new LinearLayout.LayoutParams(0, dp(48), 1f));
        EditText port = new EditText(this);
        port.setSingleLine(true);
        port.setInputType(InputType.TYPE_CLASS_NUMBER);
        port.setText(getSharedPreferences("nikon-link", MODE_PRIVATE)
                .getString("wifiCameraPort", "15740"));
        port.setHint(tr("端口"));
        LinearLayout.LayoutParams portParams = new LinearLayout.LayoutParams(
                dp(104), dp(48));
        portParams.setMargins(dp(8), 0, 0, 0);
        wifiAddress.addView(port, portParams);
        wifiCard.addView(wifiAddress);
        wifiCard.addView(text(
                wifiConnecting
                        ? "正在连接 Wi‑Fi 相机…"
                        : wifiReconnecting
                                ? "Wi‑Fi 链路已断开，正在自动重连…"
                                : wifiConnected
                                        ? "Wi‑Fi 已连接 · " + wifiCameraName
                                        : "Wi‑Fi 相机未连接",
                TS_BODY,
                Typeface.NORMAL,
                wifiConnected ? POSITIVE
                        : (wifiReconnecting || wifiConnecting) ? UI_ACCENT : MUTED),
                marginParams(-1, -2, 0, 8, 0, 10));
        Button wifiButton = nativeButton(
                wifiReconnecting
                        ? "正在重连 Wi‑Fi 相机…"
                        : wifiConnected ? "断开 Wi‑Fi 相机" : "连接 Wi‑Fi 相机",
                !wifiConnected && !wifiReconnecting);
        wifiButton.setOnClickListener(view -> {
            if (wifiConnected) {
                disconnectWifiCamera();
                showSection("library");
                return;
            }
            int targetPort;
            try {
                targetPort = Integer.parseInt(port.getText().toString().trim());
            } catch (NumberFormatException error) {
                showError("Wi‑Fi 相机端口无效");
                return;
            }
            String targetHost = host.getText().toString().trim();
            String targetMode = wifiMode.getSelectedItemPosition() == 1
                    ? "sta"
                    : "ap";
            wifiConnectionMode = targetMode;
            getSharedPreferences("nikon-link", MODE_PRIVATE).edit()
                    .putString("wifiCameraHost", targetHost)
                    .putString("wifiCameraPort", String.valueOf(targetPort))
                    .putString("wifiCameraConnectionMode", targetMode)
                    .apply();
            connectWifiCamera(targetHost, targetPort, targetMode);
        });
        wifiCard.addView(wifiButton, new LinearLayout.LayoutParams(-1, dp(48)));

        // ── E4 1.5.9：Wi‑Fi PTP/IP 控制卡（取景 / 录像 / 参数步进，镜像
        //    Windows E3 MainWindow.xaml.cs 接法；全部 TBC-awaiting-hardware）──
        wifiCard.addView(text(
                "Wi‑Fi 相机控制 · PTP/IP",
                TS_BODY,
                Typeface.BOLD,
                MUTED),
                marginParams(-1, -2, 0, 18, 0, 6));
        wifiLiveViewButton = nativeButton(
                wifiLiveView ? "停止实时取景" : "开启实时取景",
                wifiConnected);
        wifiLiveViewButton.setOnClickListener(view -> toggleLiveView());
        wifiCard.addView(wifiLiveViewButton, marginParams(-1, dp(44), 0, 0, 0, 6));
        wifiRecordButton = nativeButton(
                wifiMovieRecording ? "停止录制" : "开始录制",
                wifiConnected && wifiVendorSupportsRecording());
        wifiRecordButton.setOnClickListener(view -> toggleVideoRecording());
        wifiCard.addView(wifiRecordButton, marginParams(-1, dp(44), 0, 0, 0, 10));
        wifiParameterReadoutView = text(
                wifiParameterReadout,
                TS_BODY,
                Typeface.NORMAL,
                MUTED);
        wifiCard.addView(
                wifiParameterReadoutView,
                marginParams(-1, -2, 0, 0, 0, 10));
        wifiCard.addView(wifiStepperRow(
                "ISO",
                view -> stepWifiIso(-1),
                view -> stepWifiIso(1)),
                marginParams(-1, -2, 0, 0, 0, 6));
        wifiCard.addView(wifiStepperRow(
                "光圈",
                view -> stepWifiAperture(-1),
                view -> stepWifiAperture(1)),
                marginParams(-1, -2, 0, 0, 0, 6));
        wifiCard.addView(wifiStepperRow(
                "快门",
                view -> stepWifiShutter(-1),
                view -> stepWifiShutter(1)),
                marginParams(-1, -2, 0, 0, 0, 6));
        updateWifiControlCard();
        return wifiCard;
    }

    /** E4：Wi‑Fi 源是否当前取景/录像的数据源（优先级：USB > 本机摄像头 > Wi‑Fi）。 */
    private boolean wifiSourceActive() {
        return wifiConnected && !connected && !localCameraConnected;
    }

    private boolean wifiVendorSupportsRecording() {
        return wifiVendor == PtpIpCamera.CameraVendor.NIKON
                || wifiVendor == PtpIpCamera.CameraVendor.CANON;
    }

    /** E4：Wi‑Fi 控制卡状态刷新（可见性/文案/可用性，镜像 Windows UpdateWifiControlState）。 */
    private void updateWifiControlCard() {
        boolean connected = wifiConnected;
        if (wifiLiveViewButton != null) {
            wifiLiveViewButton.setVisibility(connected ? View.VISIBLE : View.GONE);
            wifiLiveViewButton.setText(tr(
                    wifiLiveView ? "停止实时取景" : "开启实时取景"));
            wifiLiveViewButton.setEnabled(connected);
        }
        if (wifiRecordButton != null) {
            wifiRecordButton.setVisibility(connected ? View.VISIBLE : View.GONE);
            wifiRecordButton.setText(tr(
                    wifiMovieRecording ? "停止录制" : "开始录制"));
            wifiRecordButton.setEnabled(connected && wifiVendorSupportsRecording());
        }
        if (wifiParameterReadoutView != null) {
            wifiParameterReadoutView.setVisibility(
                    connected ? View.VISIBLE : View.GONE);
            wifiParameterReadoutView.setText(wifiParameterReadout);
        }
    }

    /**
     * E4：从 Wi‑Fi 相机读取 ISO/光圈/快门并刷新本地字段与读数
     * （镜像 Windows RefreshWifiParametersAsync；单属性失败不阻断其余；
     * 须在 cameraExecutor 上调用；TBC-awaiting-hardware）。
     * 解码口径与 Windows 一致：ISO UINT16；光圈 UINT16（f 数×100）；
     * 快门 UINT32（秒×10000），均小端。
     */
    private void refreshWifiParameters() {
        if (!wifiConnected) return;
        try {
            byte[] iso = wifiCamera.readProperty(0x500f);
            if (iso.length >= 2) {
                wifiIso = (iso[0] & 0xff) | ((iso[1] & 0xff) << 8);
            }
        } catch (Exception error) {
            diagnostics.warning("wifi-params",
                    "读取 Wi‑Fi ISO 失败：" + error.getMessage());
        }
        try {
            byte[] aperture = wifiCamera.readProperty(0x5007);
            if (aperture.length >= 2) {
                int scaled = (aperture[0] & 0xff)
                        | ((aperture[1] & 0xff) << 8);
                wifiAperture = scaled / 100.0;
            }
        } catch (Exception error) {
            diagnostics.warning("wifi-params",
                    "读取 Wi‑Fi 光圈失败：" + error.getMessage());
        }
        try {
            byte[] shutter = wifiCamera.readProperty(0x500d);
            if (shutter.length >= 4) {
                long scaled = (shutter[0] & 0xffL)
                        | ((shutter[1] & 0xffL) << 8)
                        | ((shutter[2] & 0xffL) << 16)
                        | ((shutter[3] & 0xffL) << 24);
                wifiShutterSeconds = scaled / 10000.0;
            }
        } catch (Exception error) {
            diagnostics.warning("wifi-params",
                    "读取 Wi‑Fi 快门失败：" + error.getMessage());
        }
        wifiParameterReadout = wifiParameterReadoutText();
        mainHandler.post(() -> {
            if (wifiParameterReadoutView != null) {
                wifiParameterReadoutView.setText(wifiParameterReadout);
            }
            updateWifiControlCard();
        });
    }

    /** E4：读数文案（镜像 Windows UpdateWifiParameterReadout）。 */
    private String wifiParameterReadoutText() {
        String shutter = wifiShutterSeconds > 0
                ? (wifiShutterSeconds >= 1
                        ? String.format(Locale.ROOT, "%.2g″",
                                wifiShutterSeconds)
                        : "1/" + Math.max(1,
                                (int) Math.round(1.0 / wifiShutterSeconds)))
                : "—";
        String aperture = wifiAperture > 0
                ? String.format(Locale.ROOT, "f/%.1f", wifiAperture)
                : "—";
        String iso = wifiIso > 0 ? String.valueOf(wifiIso) : "—";
        return tr(String.format(Locale.ROOT,
                "ISO %s · %s · %s", iso, aperture, shutter));
    }

    /** E4：步进 Wi‑Fi ISO（镜像 Windows StepWifiIsoAsync；TBC）。 */
    private void stepWifiIso(int delta) {
        if (!wifiConnected) return;
        cameraExecutor.submit(() -> {
            try {
                int[] ladder = new int[]{
                        64, 80, 100, 125, 160, 200, 250, 320, 400, 500,
                        640, 800, 1000, 1250, 1600, 2000, 2500, 3200,
                        4000, 5000, 6400, 8000, 10000, 12800, 16000,
                        20000, 25600, 32000, 40000, 51200, 64000, 102400};
                int index = firstAtLeast(ladder, wifiIso);
                int next = Math.max(0,
                        Math.min(ladder.length - 1, index + delta));
                byte[] payload = new byte[]{
                        (byte) ladder[next],
                        (byte) (ladder[next] >> 8)};
                wifiCamera.writeProperty(0x500f, payload);
                refreshWifiParameters();
            } catch (Exception error) {
                diagnostics.error("wifi-params",
                        "写入 Wi‑Fi ISO 失败：" + error.getMessage());
                mainHandler.post(() -> showError(
                        tr(String.format(Locale.ROOT,
                                "写入 Wi‑Fi ISO 失败：%s",
                                error.getMessage()))));
            }
        });
    }

    /** E4：步进 Wi‑Fi 光圈（镜像 Windows StepWifiApertureAsync；TBC）。 */
    private void stepWifiAperture(int delta) {
        if (!wifiConnected) return;
        cameraExecutor.submit(() -> {
            try {
                double[] ladder = new double[]{
                        1.4, 1.6, 1.8, 2.0, 2.2, 2.5, 2.8, 3.2, 3.5,
                        4.0, 4.5, 5.0, 5.6, 6.3, 7.1, 8.0, 9.0, 10.0,
                        11.0, 13.0, 14.0, 16.0, 18.0, 20.0, 22.0};
                int index = firstAtLeast(ladder, wifiAperture - 0.01);
                int next = Math.max(0,
                        Math.min(ladder.length - 1, index + delta));
                int scaled = (int) Math.round(ladder[next] * 100);
                byte[] payload = new byte[]{
                        (byte) scaled,
                        (byte) (scaled >> 8)};
                wifiCamera.writeProperty(0x5007, payload);
                refreshWifiParameters();
            } catch (Exception error) {
                diagnostics.error("wifi-params",
                        "写入 Wi‑Fi 光圈失败：" + error.getMessage());
                mainHandler.post(() -> showError(
                        tr(String.format(Locale.ROOT,
                                "写入 Wi‑Fi 光圈失败：%s",
                                error.getMessage()))));
            }
        });
    }

    /** E4：步进 Wi‑Fi 快门（数值镜像 Windows StepWifiShutterAsync；TBC）。 */
    private void stepWifiShutter(int delta) {
        if (!wifiConnected) return;
        cameraExecutor.submit(() -> {
            try {
                // 快门档位（秒），升序：1/8000 → 1″。注：Windows E3 用降序
                // 分母 + Array.FindIndex(1.0/d <= seconds) 恒命中首档（TBC
                // 未真机验证的缺陷）；此处以升序秒值正确定位当前档。
                double[] ladder = new double[]{
                        1.0 / 8000, 1.0 / 4000, 1.0 / 2000, 1.0 / 1000,
                        1.0 / 500, 1.0 / 250, 1.0 / 125, 1.0 / 60,
                        1.0 / 30, 1.0 / 15, 1.0 / 8, 1.0 / 4, 1.0 / 2, 1.0};
                int index = firstAtLeast(ladder, wifiShutterSeconds - 0.00001);
                int next = Math.max(0,
                        Math.min(ladder.length - 1, index + delta));
                double seconds = ladder[next];
                long scaled = (long) Math.round(seconds * 10000);
                byte[] payload = new byte[]{
                        (byte) scaled,
                        (byte) (scaled >> 8),
                        (byte) (scaled >> 16),
                        (byte) (scaled >> 24)};
                wifiCamera.writeProperty(0x500d, payload);
                refreshWifiParameters();
            } catch (Exception error) {
                diagnostics.error("wifi-params",
                        "写入 Wi‑Fi 快门失败：" + error.getMessage());
                mainHandler.post(() -> showError(
                        tr(String.format(Locale.ROOT,
                                "写入 Wi‑Fi 快门失败：%s",
                                error.getMessage()))));
            }
        });
    }

    /** E4：升序阶梯中第一个 ≥ value 的下标（无则返回末位；镜像 Windows FindIndex）。 */
    private static int firstAtLeast(int[] ladder, int value) {
        for (int i = 0; i < ladder.length; i++) {
            if (ladder[i] >= value) return i;
        }
        return ladder.length - 1;
    }

    private static int firstAtLeast(double[] ladder, double value) {
        for (int i = 0; i < ladder.length; i++) {
            if (ladder[i] >= value) return i;
        }
        return ladder.length - 1;
    }

    /** E4：参数步进行（标题 + 减/加按钮）。 */
    private View wifiStepperRow(
            String title,
            View.OnClickListener decrease,
            View.OnClickListener increase) {
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        Button minus = new Button(this);
        minus.setText("−");
        minus.setAllCaps(false);
        minus.setTextSize(18);
        minus.setOnClickListener(decrease);
        row.addView(minus, new LinearLayout.LayoutParams(dp(52), dp(44)));
        TextView label = text(title, TS_BODY, Typeface.BOLD, INK);
        label.setGravity(Gravity.CENTER_VERTICAL);
        row.addView(label, new LinearLayout.LayoutParams(0, dp(44), 1f));
        Button plus = new Button(this);
        plus.setText("+");
        plus.setAllCaps(false);
        plus.setTextSize(18);
        plus.setOnClickListener(increase);
        row.addView(plus, new LinearLayout.LayoutParams(dp(52), dp(44)));
        return row;
    }

    private View buildCaptureAssistantsPanel() {
        LinearLayout remoteCard = panel();
        remoteCard.addView(text("拍摄辅助", TS_TITLE, Typeface.BOLD, INK));
        remoteCard.addView(text(
                "蓝牙遥控与拍摄定位",
                TS_BODY,
                Typeface.NORMAL,
                MUTED),
                marginParams(-1, -2, 0, 4, 0, 12));
        Switch bluetooth = new Switch(this);
        bluetooth.setText(tr("蓝牙遥控快门"));
        bluetooth.setChecked(bluetoothRemoteEnabled);
        bluetooth.setOnCheckedChangeListener((button, checked) ->
                setBluetoothRemoteEnabled(checked));
        remoteCard.addView(bluetooth);
        remoteCard.addView(text(
                bluetoothRemoteStatus,
                TS_BODY,
                Typeface.NORMAL,
                MUTED),
                marginParams(-1, -2, 0, 4, 0, 12));
        Switch location = new Switch(this);
        location.setText(tr("拍摄定位"));
        location.setChecked(locationTaggingEnabled);
        location.setOnCheckedChangeListener((button, checked) ->
                setLocationTaggingEnabled(checked));
        remoteCard.addView(location);
        remoteCard.addView(text(
                tr(locationTaggingStatus)
                        + " · " + tr("拍摄文件会生成标准 XMP GPS 旁车文件"),
                TS_BODY,
                Typeface.NORMAL,
                MUTED),
                marginParams(-1, -2, 0, 4, 0, 0));

        // ── E5 1.5.9：live 图（取景帧环形缓冲 + 快门切片配对，默认关 3s）──
        Switch livePhoto = new Switch(this);
        livePhoto.setText(tr("Live 图"));
        livePhoto.setChecked(livePhotoEnabled);
        livePhoto.setOnCheckedChangeListener((button, checked) -> {
            livePhotoEnabled = checked;
            getSharedPreferences("nikon-link", MODE_PRIVATE)
                    .edit().putBoolean("livePhotoEnabled", checked).apply();
            syncLivePhotoRing();
            if (statusText != null) {
                statusText.setText(checked
                        ? tr("live 图已开启 · 快门将附带最近 ")
                                + Math.round(livePhotoSeconds)
                                + tr(" 秒取景切片")
                        : tr("live 图已关闭"));
            }
        });
        remoteCard.addView(livePhoto);
        String[] liveSecondsLabels = new String[]{
                tr("1 秒"), tr("3 秒"), tr("5 秒"), tr("10 秒"), tr("15 秒")};
        int[] liveSecondsValues = new int[]{1, 3, 5, 10, 15};
        Spinner liveSecondsSpinner = new Spinner(this);
        ArrayAdapter<String> liveSecondsAdapter = new ArrayAdapter<>(
                this,
                android.R.layout.simple_spinner_item,
                liveSecondsLabels);
        liveSecondsAdapter.setDropDownViewResource(
                android.R.layout.simple_spinner_dropdown_item);
        liveSecondsSpinner.setAdapter(liveSecondsAdapter);
        liveSecondsSpinner.setSelection(
                Math.max(0, Arrays.asList(1, 3, 5, 10, 15)
                        .indexOf((int) Math.round(livePhotoSeconds))),
                false);
        liveSecondsSpinner.setBackground(rounded(
                FIELD_BG,
                9,
                RULE));
        liveSecondsSpinner.setPadding(dp(10), 0, dp(8), 0);
        liveSecondsSpinner.setOnItemSelectedListener(
                new android.widget.AdapterView.OnItemSelectedListener() {
                    @Override
                    public void onItemSelected(
                            android.widget.AdapterView<?> parent,
                            View view,
                            int position,
                            long id) {
                        int seconds = liveSecondsValues[position];
                        livePhotoSeconds = seconds;
                        getSharedPreferences("nikon-link", MODE_PRIVATE)
                                .edit().putFloat("livePhotoSeconds", seconds).apply();
                        if (livePhotoClipRecorder.isArmed()) {
                            livePhotoClipRecorder.arm(
                                    Math.max(4, (int) Math.round(monitorFrameRate)),
                                    livePhotoSeconds);
                        }
                    }

                    @Override
                    public void onNothingSelected(
                            android.widget.AdapterView<?> parent) {}
                });
        remoteCard.addView(liveSecondsSpinner, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(44)));
        remoteCard.addView(text(
                tr("快门时附带最近几秒取景切片，与照片同 base 配对入库（Wi‑Fi 遥控拍摄除外）"),
                TS_BODY,
                Typeface.NORMAL,
                MUTED),
                marginParams(-1, -2, 0, 4, 0, 0));
        return remoteCard;
    }

    // ── W13-d 登录墙（3A：启动即登录墙）──────────────────────────────────────

    /** 启动路由守卫：有 token 时后台校验 /v1/auth/me；401/403 清 token 回登录墙。 */
    private void validateSessionAsync() {
        activationExecutor.execute(() -> {
            AuthManager.AuthResult result = authManager.me();
            boolean invalid = result.protocolError
                    || (result.status != 200
                    && result.status != 0
                    && result.status < 500);
            boolean cleanupFailed = invalid && !authManager.clearSession();
            mainHandler.post(() -> {
                if (isFinishing() || isDestroyed()) return;
                authChecking = false;
                if (invalid) {
                    authPersistentError = cleanupFailed
                            ? tr("已退出，但本机登录信息未完全清除。请重新登录后再退出一次。")
                            : "";
                    showLoginWall();
                } else {
                    hideLoginWall();
                }
            });
            // 仅 200 / 真实网络失败 status=0 / JSON 服务端 5xx 离线容忍；
            // HTML、畸形 JSON、重定向和其他 4xx 均失败关闭。
        });
    }

    /** 有缓存会话时阻断主工作区，直到 /me 明确完成或进入离线容忍态。 */
    private void showAuthCheckingWall() {
        authChecking = true;
        loginWallVisible = false;
        dismissConnectionDialog();
        if (authWallHost == null) return;
        cancelCodeCountdown();
        authWallHost.removeAllViews();
        authWallHost.setVisibility(View.VISIBLE);

        LinearLayout content = verticalContainer();
        content.setGravity(Gravity.CENTER);
        ProgressBar progress = new ProgressBar(this);
        content.addView(progress, new LinearLayout.LayoutParams(dp(44), dp(44)));
        TextView status = text("正在验证登录状态…", 14, Typeface.BOLD, INK);
        status.setGravity(Gravity.CENTER);
        status.setAccessibilityLiveRegion(View.ACCESSIBILITY_LIVE_REGION_POLITE);
        content.addView(status, marginParams(-2, -2, 0, 16, 0, 0));
        authWallHost.addView(content, new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT));
    }

    private void showLoginWall() {
        closeAuthSensitiveState();
        authChecking = false;
        loginWallVisible = true;
        dismissConnectionDialog();
        if (authWallHost == null) return;
        cancelCodeCountdown();
        authWallHost.removeAllViews();
        authWallHost.setVisibility(View.VISIBLE);

        ScrollView scroll = new ScrollView(this);
        scroll.setFillViewport(true);
        LinearLayout content = verticalContainer();
        content.setPadding(dp(28), dp(48), dp(28), dp(36));
        content.setGravity(Gravity.CENTER_HORIZONTAL);

        // 品牌区（design.md splash 品牌资产：几何 Z 标 + 双语 lockup）
        FrameLayout markBox = new FrameLayout(this);
        markBox.setBackground(brandGradient(20));
        markBox.setLayoutParams(new LinearLayout.LayoutParams(dp(64), dp(64)));
        TextView markText = new TextView(this);
        markText.setText("Z");
        markText.setTextSize(TypedValue.COMPLEX_UNIT_SP, 32);
        markText.setTypeface(Typeface.DEFAULT_BOLD);
        markText.setTextColor(Color.WHITE);
        markText.setGravity(Gravity.CENTER);
        markText.setLayoutParams(new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT));
        markBox.addView(markText);
        LinearLayout.LayoutParams markParams =
                new LinearLayout.LayoutParams(dp(64), dp(64));
        content.addView(markBox, markParams);

        TextView brandTitle = text("帧澈 ZENCHE", 26, Typeface.BOLD, INK);
        brandTitle.setGravity(Gravity.CENTER);
        content.addView(brandTitle, marginParams(-1, -2, 0, 18, 0, 0));
        TextView brandSub = text("Capture · Connect · Flow", 13, Typeface.NORMAL, MUTED);
        brandSub.setGravity(Gravity.CENTER);
        content.addView(brandSub, marginParams(-1, -2, 0, 6, 0, 8));
        TextView brandPrompt = text(
                "登录后使用拍摄、编辑与 AI 功能", 14, Typeface.NORMAL, MUTED);
        brandPrompt.setGravity(Gravity.CENTER);
        content.addView(brandPrompt, marginParams(-1, -2, 0, 0, 0, 24));

        // 登录 / 注册 切换
        LinearLayout modeRow = new LinearLayout(this);
        modeRow.setOrientation(LinearLayout.HORIZONTAL);
        modeRow.setBackground(rounded(PAPER_2, 12, RULE));
        modeRow.setPadding(dp(4), dp(4), dp(4), dp(4));
        for (String mode : new String[]{"login", "register"}) {
            boolean selected = authMode.equals(mode);
            Button modeButton = new Button(this);
            modeButton.setText(tr(
                    "login".equals(mode) ? "已有账号" : "创建账号"));
            modeButton.setTextSize(14);
            modeButton.setTypeface(Typeface.create("sans", Typeface.BOLD));
            modeButton.setTextColor(selected ? Color.WHITE : MUTED);
            modeButton.setAllCaps(false);
            modeButton.setGravity(Gravity.CENTER);
            modeButton.setMinHeight(dp(44));
            modeButton.setPadding(dp(12), 0, dp(12), 0);
            modeButton.setBackground(selected
                    ? rounded(COBALT, 10, 0)
                    : rounded(0, 10, 0));
            modeButton.setStateListAnimator(null);
            modeButton.setOnClickListener(view -> {
                if (!authMode.equals(mode)) {
                    // 切模式保留已输入邮箱/密码
                    String email = authEmailInput == null ? ""
                            : authEmailInput.getText().toString();
                    String password = authPasswordInput == null ? ""
                            : authPasswordInput.getText().toString();
                    authMode = mode;
                    showLoginWall();
                    if (authEmailInput != null) authEmailInput.setText(email);
                    if (authPasswordInput != null) authPasswordInput.setText(password);
                }
            });
            modeRow.addView(modeButton, new LinearLayout.LayoutParams(
                    0, dp(44), 1f));
        }
        content.addView(modeRow, marginParams(-1, dp(52), 0, 0, 0, 20));
        TextView modeHint = text(
                "register".equals(authMode)
                        ? "已有账号？切换到「登录」"
                        : "还没有账号？切换到「注册」即可创建",
                13, Typeface.NORMAL, MUTED);
        modeHint.setGravity(Gravity.CENTER);
        content.addView(modeHint, marginParams(-1, -2, 0, 0, 0, 14));

        // 邮箱
        authEmailInput = new EditText(this);
        authEmailInput.setHint(tr("邮箱"));
        authEmailInput.setInputType(InputType.TYPE_CLASS_TEXT
                | InputType.TYPE_TEXT_VARIATION_EMAIL_ADDRESS);
        authEmailInput.setSingleLine(true);
        authEmailInput.setImeOptions(EditorInfo.IME_ACTION_NEXT);
        authEmailInput.setContentDescription(tr("邮箱"));
        authEmailInput.setOnEditorActionListener((view, actionId, event) -> {
            if (actionId != EditorInfo.IME_ACTION_NEXT) return false;
            authPasswordInput.requestFocus();
            return true;
        });
        authEmailInput.setTextSize(15);
        authEmailInput.setTextColor(INK);
        authEmailInput.setHintTextColor(MUTED);
        authEmailInput.setBackground(rounded(PAPER_2, 10, RULE));
        authEmailInput.setPadding(dp(14), 0, dp(14), 0);
        content.addView(authEmailInput, marginParams(-1, dp(50), 0, 0, 0, 10));

        // 密码
        authPasswordInput = new EditText(this);
        authPasswordInput.setHint(tr("密码（至少 8 位）"));
        authPasswordInput.setInputType(InputType.TYPE_CLASS_TEXT
                | InputType.TYPE_TEXT_VARIATION_PASSWORD);
        authPasswordInput.setSingleLine(true);
        authPasswordInput.setImeOptions(
                "register".equals(authMode) && authCodeRequired
                        ? EditorInfo.IME_ACTION_NEXT
                        : EditorInfo.IME_ACTION_DONE);
        authPasswordInput.setContentDescription(tr("密码（至少 8 位）"));
        authPasswordInput.setOnEditorActionListener((view, actionId, event) -> {
            if (actionId == EditorInfo.IME_ACTION_NEXT) {
                if (authCodeRow.getVisibility() == View.VISIBLE) {
                    authCodeInput.requestFocus();
                } else {
                    submitAuthForm();
                }
                return true;
            }
            if (actionId == EditorInfo.IME_ACTION_DONE) {
                submitAuthForm();
                return true;
            }
            return false;
        });
        authPasswordInput.setTextSize(15);
        authPasswordInput.setTextColor(INK);
        authPasswordInput.setHintTextColor(MUTED);
        authPasswordInput.setBackground(rounded(PAPER_2, 10, RULE));
        authPasswordInput.setPadding(dp(14), 0, dp(14), 0);
        content.addView(authPasswordInput, marginParams(-1, dp(50), 0, 0, 0, 10));

        // 验证码行（注册模式 + authCodeRequired 时显示）
        authCodeRow = verticalContainer();
        authCodeInput = new EditText(this);
        authCodeInput.setHint(tr("验证码"));
        authCodeInput.setInputType(InputType.TYPE_CLASS_NUMBER);
        authCodeInput.setSingleLine(true);
        authCodeInput.setImeOptions(EditorInfo.IME_ACTION_DONE);
        authCodeInput.setContentDescription(tr("验证码"));
        authCodeInput.setOnEditorActionListener((view, actionId, event) -> {
            if (actionId != EditorInfo.IME_ACTION_DONE) return false;
            submitAuthForm();
            return true;
        });
        authCodeInput.setTextSize(15);
        authCodeInput.setTextColor(INK);
        authCodeInput.setHintTextColor(MUTED);
        authCodeInput.setBackground(rounded(PAPER_2, 10, RULE));
        authCodeInput.setPadding(dp(14), 0, dp(14), 0);
        authCodeRow.addView(authCodeInput,
                marginParams(-1, dp(50), 0, 0, 0, 8));
        authCodeButton = nativeButton("获取验证码", false);
        authCodeButton.setOnClickListener(view -> requestAuthCode());
        authCodeRow.addView(authCodeButton,
                marginParams(-1, dp(44), 0, 0, 0, 8));
        content.addView(authCodeRow, marginParams(-1, -2, 0, 0, 0, 0));
        updateAuthCodeRowVisibility();

        // 错误提示（红色，服务端 message 直达）
        authErrorText = text("", 13, Typeface.NORMAL, VIDEO);
        authErrorText.setGravity(Gravity.CENTER);
        authErrorText.setAccessibilityLiveRegion(View.ACCESSIBILITY_LIVE_REGION_ASSERTIVE);
        authErrorText.setText(authPersistentError);
        content.addView(authErrorText, marginParams(-1, -2, 0, 4, 0, 10));

        // 主操作按钮
        authSubmitButton = nativeButton(
                "login".equals(authMode) ? "登录" : "注册", true);
        authSubmitButton.setTextSize(15);
        authSubmitButton.setOnClickListener(view -> submitAuthForm());
        content.addView(authSubmitButton,
                marginParams(-1, dp(50), 0, 0, 0, 14));

        FrameLayout formHost = new FrameLayout(this);
        int formWidth = Math.min(currentAuthViewportWidthPx(), dp(576));
        FrameLayout.LayoutParams formParams = new FrameLayout.LayoutParams(
                formWidth,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.TOP | Gravity.CENTER_HORIZONTAL);
        formHost.addView(content, formParams);
        scroll.addView(formHost, new ScrollView.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT));
        authWallHost.addView(scroll, new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT));
    }

    private void hideLoginWall() {
        authSensitiveStateClosed = false;
        loginWallVisible = false;
        cancelCodeCountdown();
        if (authWallHost != null) {
            authWallHost.removeAllViews();
            authWallHost.setVisibility(View.GONE);
        }
        // 有缓存会话且 /me 校验成功时，恢复用户此前启用的后台偏好；显式登出
        // 会在 closeAuthSensitiveState 中把这些偏好关闭，不会自动复活。
        if (bluetoothRemoteEnabled) bluetoothRemote.start();
        if (locationTaggingEnabled) locationTagging.start();
    }

    /** 登录墙前统一清理相机、外录、网络回调与后台服务；幂等。 */
    private void closeAuthSensitiveState() {
        dismissConnectionDialog();
        if (authSensitiveStateClosed) return;
        authSensitiveStateClosed = true;

        if (nikonCloudPresetDialog != null) {
            nikonCloudPresetDialog.dismiss();
            nikonCloudPresetDialog = null;
        }
        if (immersiveDialog != null) {
            closeImmersivePreview(immersiveDialog);
        }

        wirelessRequested = false;
        wirelessServer.stop();
        setBluetoothRemoteEnabled(false);
        setLocationTaggingEnabled(false);
        mainHandler.removeCallbacks(wifiHeartbeatRunnable);
        mainHandler.removeCallbacks(wifiReconnectRunnable);
        unregisterWifiNetworkCallback();

        previewGeneration++;
        wifiPreviewGeneration++;
        pendingPreview.set(null);
        connected = false;
        connecting = false;
        wifiConnected = false;
        wifiConnecting = false;
        wifiReconnecting = false;
        wifiManualDisconnect = true;
        wifiLiveView = false;
        wifiMovieRecording = false;
        localCameraConnected = false;
        localCameraConnecting = false;
        liveViewEnabled = false;
        videoRecording = false;
        capturing = false;
        recordingStartedAt = 0;
        latestFrame = null;
        latestSourceFrame = null;
        latestZebraMask = null;

        cameraExecutor.submit(() -> {
            finishExternalRecordingForDisconnect();
            try {
                if (wifiCamera.isMovieRecording()) wifiCamera.stopMovieRecording();
            } catch (Exception ignored) {
            }
            try {
                wifiCamera.stopLiveView();
            } catch (Exception ignored) {
            }
            wifiCamera.close();
            localCamera.close();
            try {
                if (camera.isMovieRecording()) camera.stopMovieRecording();
            } catch (Exception ignored) {
            }
            camera.disconnect();
        });
        updateConnectionUi();
        updateRecordingButtons();
        updateWirelessUi();
    }

    /** 验证码行显隐：注册模式且 authCodeRequired（严态）时显示。 */
    private void updateAuthCodeRowVisibility() {
        if (authCodeRow == null) return;
        boolean visible = "register".equals(authMode) && authCodeRequired;
        authCodeRow.setVisibility(visible ? View.VISIBLE : View.GONE);
        if (authPasswordInput != null) {
            authPasswordInput.setImeOptions(visible
                    ? EditorInfo.IME_ACTION_NEXT
                    : EditorInfo.IME_ACTION_DONE);
            android.view.inputmethod.InputMethodManager inputMethod =
                    (android.view.inputmethod.InputMethodManager) getSystemService(
                            INPUT_METHOD_SERVICE);
            if (inputMethod != null) inputMethod.restartInput(authPasswordInput);
        }
    }

    /** 当前应用窗口宽度；分屏/自由窗口下不得使用整块物理屏幕宽度。 */
    private int currentAuthViewportWidthPx() {
        int width = authWallHost == null ? 0 : authWallHost.getWidth();
        if (width <= 0 && android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
            width = getWindowManager().getCurrentWindowMetrics().getBounds().width();
        }
        if (width <= 0) {
            android.graphics.Point size = new android.graphics.Point();
            getWindowManager().getDefaultDisplay().getSize(size);
            width = size.x;
        }
        return Math.max(1, width);
    }

    /** POST /v1/auth/email-code：200 显示验证码框并启动 60s 倒计时；503 免码注册。 */
    private void requestAuthCode() {
        String email = authEmailInput == null ? ""
                : authEmailInput.getText().toString().trim();
        if (email.isEmpty()) {
            authErrorText.setText(tr("请输入邮箱"));
            return;
        }
        if (!isValidEmail(email)) {
            authErrorText.setText(tr("邮箱格式不正确"));
            return;
        }
        authCodeButton.setEnabled(false);
        authCodeButton.setText(tr("正在发送…"));
        authErrorText.setText("");
        activationExecutor.execute(() -> {
            AuthManager.AuthResult result = authManager.requestEmailCode(email);
            mainHandler.post(() -> {
                if (isFinishing() || isDestroyed()) return;
                if (result.status == 200) {
                    authCodeRequired = true;
                    updateAuthCodeRowVisibility();
                    authErrorText.setText(tr("验证码已发送至 ") + email);
                    startCodeCountdown();
                } else if (result.status == 503) {
                    // 过渡态：SMTP 未配置 → 隐藏验证码框，走免码注册
                    authCodeRequired = false;
                    updateAuthCodeRowVisibility();
                    authCodeButton.setEnabled(true);
                    authCodeButton.setText(tr("获取验证码"));
                    authErrorText.setText(tr("邮件服务暂未配置，将免验证码注册"));
                } else {
                    authCodeButton.setEnabled(true);
                    authCodeButton.setText(tr("获取验证码"));
                    authErrorText.setText(tr(result.message));
                }
            });
        });
    }

    private void startCodeCountdown() {
        cancelCodeCountdown();
        authCountdown = 60;
        authCodeButton.setEnabled(false);
        authCodeButton.setText(tr("重新获取") + " (" + authCountdown + "s)");
        authCountdownTask = new Runnable() {
            @Override
            public void run() {
                if (authCodeButton == null) return;
                authCountdown--;
                if (authCountdown <= 0) {
                    authCodeButton.setEnabled(true);
                    authCodeButton.setText(tr("获取验证码"));
                    authCountdownTask = null;
                } else {
                    authCodeButton.setText(tr("重新获取") + " (" + authCountdown + "s)");
                    mainHandler.postDelayed(this, 1000);
                }
            }
        };
        mainHandler.postDelayed(authCountdownTask, 1000);
    }

    private void cancelCodeCountdown() {
        if (authCountdownTask != null) {
            mainHandler.removeCallbacks(authCountdownTask);
            authCountdownTask = null;
        }
    }

    private boolean isValidEmail(String email) {
        if (email == null) return false;
        String trimmed = email.trim();
        int at = trimmed.indexOf('@');
        if (at <= 0 || at == trimmed.length() - 1) return false;
        String domain = trimmed.substring(at + 1);
        int dot = domain.indexOf('.');
        return dot > 0 && dot < domain.length() - 1;
    }

    /** 表单校验（邮箱格式 / 密码≥8 / 严态注册须先获取验证码）。 */
    private String validateAuthForm(String email, String password, String code) {
        if (email == null || email.trim().isEmpty()) return tr("请输入邮箱");
        if (!isValidEmail(email.trim())) return tr("邮箱格式不正确");
        if (password == null || password.isEmpty()) return tr("请输入密码");
        if (password.length() < 8) return tr("密码至少 8 位");
        if ("register".equals(authMode) && authCodeRequired
                && (code == null || !code.trim().matches("\\d{6}"))) {
            return tr("请输入 6 位验证码");
        }
        return null;
    }

    private void submitAuthForm() {
        final String email = authEmailInput == null ? ""
                : authEmailInput.getText().toString().trim();
        final String password = authPasswordInput == null ? ""
                : authPasswordInput.getText().toString();
        final String code = authCodeInput == null ? ""
                : authCodeInput.getText().toString().trim();
        String validationError = validateAuthForm(email, password, code);
        if (validationError != null) {
            authErrorText.setText(validationError);
            return;
        }
        final boolean isLogin = "login".equals(authMode);
        authSubmitButton.setEnabled(false);
        authSubmitButton.setText(isLogin ? tr("正在登录…") : tr("正在注册…"));
        authErrorText.setText("");
        activationExecutor.execute(() -> {
            AuthManager.AuthResult result = isLogin
                    ? authManager.login(email, password)
                    : authManager.register(
                            email, password, authCodeRequired ? code : null);
            mainHandler.post(() -> {
                if (isFinishing() || isDestroyed()) return;
                authSubmitButton.setEnabled(true);
                authSubmitButton.setText(isLogin ? tr("登录") : tr("注册"));
                if (result.status == 200) {
                    authPersistentError = "";
                    hideLoginWall();
                    showSection("capture");
                    showToast(tr("欢迎，") + (result.email == null ? email : result.email));
                } else {
                    authErrorText.setText(
                            result.message == null || result.message.isEmpty()
                                    ? tr("操作失败，请稍后重试")
                                    : tr(result.message));
                }
            });
        });
    }

    /** 设置页「退出登录」：调 logout（尽力而为）+ 清本地登录态回登录墙。 */
    private void performLogout(final Button logoutButton) {
        logoutButton.setEnabled(false);
        logoutButton.setText(tr("正在退出…"));
        activationExecutor.execute(() -> {
            AuthManager.AuthResult result = authManager.logout();
            mainHandler.post(() -> {
                if (isFinishing() || isDestroyed()) return;
                authPersistentError = result.localCleanupFailed
                        ? tr(result.message)
                        : "";
                dismissConnectionDialog();
                showLoginWall();
            });
        });
    }

    private View buildSettingsView() {
        ScrollView scroll = new ScrollView(this);
        LinearLayout content = verticalContainer();
        content.setPadding(dp(20), dp(22), dp(20), dp(24));
        content.addView(sectionHeader(
                "设置",
                "通用、拍摄辅助、更新、诊断与支持。",
                COBALT));

        // W13-d：账号区（显示邮箱 + 退出登录）
        LinearLayout accountPanel = panel();
        accountPanel.addView(text("账号", TS_TITLE, Typeface.BOLD, INK));
        accountPanel.addView(text(
                "登录后可跨设备同步激活绑定；退出后需重新登录才能使用全部功能。",
                TS_BODY,
                Typeface.NORMAL,
                MUTED),
                marginParams(-1, -2, 0, 5, 0, 10));
        String accountEmail = authManager == null ? ""
                : authManager.getEmail();
        TextView accountEmailValue = new TextView(this);
        accountEmailValue.setText(
                accountEmail == null || accountEmail.isEmpty()
                        ? tr("未登录")
                        : accountEmail);
        accountEmailValue.setTextSize(TS_BODY);
        accountEmailValue.setTextColor(INK);
        accountEmailValue.setTypeface(Typeface.create(
                Typeface.MONOSPACE, Typeface.NORMAL));
        accountEmailValue.setGravity(Gravity.CENTER_VERTICAL);
        accountEmailValue.setTextIsSelectable(true);
        accountPanel.addView(accountEmailValue,
                marginParams(-1, -2, 0, 0, 0, 12));
        Button logoutButton = nativeButton("退出登录", false);
        logoutButton.setOnClickListener(view -> {
            if (accountEmail == null || accountEmail.isEmpty()) {
                // 理论上 3A 下不会出现；兜底直接回登录墙
                showLoginWall();
                return;
            }
            new AlertDialog.Builder(this)
                    .setTitle(tr("退出登录"))
                    .setMessage(tr("确定退出当前账号 ") + accountEmail + " 吗？")
                    .setPositiveButton(tr("退出"), (dialog, which) -> {
                        performLogout(logoutButton);
                    })
                    .setNegativeButton(tr("取消"), null)
                    .show();
        });
        accountPanel.addView(logoutButton,
                marginParams(-1, dp(44), 0, 0, 0, 0));
        content.addView(
                accountPanel,
                marginParams(-1, -2, 0, 18, 0, 0));

        LinearLayout languagePanel = panel();
        languagePanel.addView(text("语言", TS_TITLE, Typeface.BOLD, INK));
        languagePanel.addView(text(
                "语言更改会立即应用，并在下次启动时保留。",
                TS_BODY,
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
                FIELD_BG,
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

        content.addView(
                buildCaptureAssistantsPanel(),
                marginParams(-1, -2, 0, 18, 0, 0));

        LinearLayout nikonSdkPanel = panel();
        nikonSdkPanel.addView(text(
                "尼康官方 SDK", TS_TITLE, Typeface.BOLD, INK));
        nikonSdkPanel.addView(text(
                "官方桌面 SDK 不提供当前平台运行库",
                SETTINGS_FS_SUB,
                Typeface.BOLD,
                INK),
                marginParams(-1, -2, 0, 5, 0, 5));
        nikonSdkPanel.addView(text(
                "尼康只为 macOS 与 Windows 提供本次 SDK 运行库；当前平台继续使用原生相机连接后端。",
                TS_BODY,
                Typeface.NORMAL,
                MUTED));
        content.addView(
                nikonSdkPanel,
                marginParams(-1, -2, 0, 18, 0, 0));

        LinearLayout sonySdkPanel = panel();
        sonySdkPanel.addView(text(
                "索尼官方 SDK", TS_TITLE, Typeface.BOLD, INK));
        sonySdkPanel.addView(text(
                "官方桌面 SDK 不提供当前平台运行库",
                SETTINGS_FS_SUB,
                Typeface.BOLD,
                INK),
                marginParams(-1, -2, 0, 5, 0, 5));
        sonySdkPanel.addView(text(
                "索尼 Camera Remote SDK 2.02.00 只提供 macOS 与 Windows 运行库；当前平台继续使用原生 Camera Remote Command 连接后端。",
                TS_BODY,
                Typeface.NORMAL,
                MUTED));
        content.addView(
                sonySdkPanel,
                marginParams(-1, -2, 0, 18, 0, 0));

        LinearLayout aiPanel = panel();
        aiPanel.addView(text("AI 功能激活", TS_TITLE, Typeface.BOLD, INK));
        aiPanel.addView(text(
                "AI 修图与生图需购买激活码解锁；每个激活码绑定当前设备，服务器负责计数与扣减次数。",
                TS_BODY,
                Typeface.NORMAL,
                MUTED),
                marginParams(-1, -2, 0, 5, 0, 10));
        Button officialWebsiteButton = nativeButton("前往官网兑换密钥", true);
        officialWebsiteButton.setOnClickListener(
                view -> openExternalUrl(ZENCHE_WEBSITE_URL));
        aiPanel.addView(officialWebsiteButton,
                marginParams(-1, dp(44), 0, 0, 0, 8));
        aiPanel.addView(text(
                "复制设备 ID 后，前往 zenche.top 使用兑换码兑换绑定当前设备的激活密钥。",
                TS_CAPTION,
                Typeface.NORMAL,
                MUTED),
                marginParams(-1, -2, 0, 0, 0, 10));
        aiPanel.addView(text(
                "没有兑换码？在爱发电购买兑换码",
                SETTINGS_FS_SUB,
                Typeface.BOLD,
                INK),
                marginParams(-1, -2, 0, 0, 0, 8));
        try (InputStream stream = getAssets().open("wechat-donation.png")) {
            ImageView afdianQrCode = new ImageView(this);
            afdianQrCode.setImageBitmap(BitmapFactory.decodeStream(stream));
            afdianQrCode.setAdjustViewBounds(true);
            afdianQrCode.setScaleType(ImageView.ScaleType.FIT_CENTER);
            afdianQrCode.setMaxHeight(dp(420));
            afdianQrCode.setContentDescription(tr("在爱发电购买兑换码"));
            afdianQrCode.setBackground(rounded(SURFACE, 8, RULE));
            afdianQrCode.setOnClickListener(
                    view -> openExternalUrl(AFDIAN_URL));
            aiPanel.addView(afdianQrCode,
                    marginParams(-1, -2, 0, 0, 0, 8));
        } catch (Exception error) {
            diagnostics.warning(
                    "settings",
                    "无法载入爱发电二维码：" + error.getMessage());
        }
        Button afdianPurchaseButton = nativeButton(
                "在爱发电购买兑换码", false);
        afdianPurchaseButton.setOnClickListener(
                view -> openExternalUrl(AFDIAN_URL));
        aiPanel.addView(afdianPurchaseButton,
                marginParams(-1, dp(44), 0, 0, 0, 6));
        aiPanel.addView(text(
                "兑换码仅用于 AI 云服务次数，帧澈本体保持免费开源。",
                SETTINGS_FS_TINY,
                Typeface.NORMAL,
                MUTED),
                marginParams(-1, -2, 0, 0, 0, 12));
        LinearLayout deviceIdHeader = new LinearLayout(this);
        deviceIdHeader.setOrientation(LinearLayout.HORIZONTAL);
        deviceIdHeader.setGravity(Gravity.CENTER_VERTICAL);
        TextView deviceIdLabel = text("我的设备 ID", TS_CAPTION, Typeface.BOLD, MUTED);
        deviceIdHeader.addView(deviceIdLabel, new LinearLayout.LayoutParams(
                0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f));
        Button copyDeviceId = nativeButton("复制", false);
        copyDeviceId.setOnClickListener(view -> {
            ((android.content.ClipboardManager) getSystemService(
                    android.content.Context.CLIPBOARD_SERVICE))
                    .setPrimaryClip(ClipData.newPlainText(
                            "deviceId", aiDeviceId()));
            showToast("设备 ID 已复制，可前往官网兑换密钥");
        });
        deviceIdHeader.addView(copyDeviceId, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT, dp(36)));
        aiPanel.addView(deviceIdHeader, marginParams(-1, -2, 0, 0, 0, 4));
        TextView deviceIdValue = new TextView(this);
        deviceIdValue.setText(aiDeviceId());
        deviceIdValue.setTextSize(TS_CAPTION);
        deviceIdValue.setTextColor(MUTED);
        deviceIdValue.setTypeface(Typeface.create(
                Typeface.MONOSPACE, Typeface.NORMAL));
        deviceIdValue.setGravity(Gravity.CENTER_VERTICAL);
        deviceIdValue.setTextIsSelectable(true);
        aiPanel.addView(deviceIdValue, marginParams(-1, -2, 0, 0, 0, 4));
        aiPanel.addView(text(
                "每个激活密钥绑定当前设备，请复制上面的设备 ID 并前往官网兑换。",
                TS_CAPTION,
                Typeface.NORMAL,
                MUTED),
                marginParams(-1, -2, 0, 0, 0, 10));
        aiPanel.addView(text("激活码", TS_BODY, Typeface.BOLD, MUTED),
                marginParams(-1, -2, 0, 0, 0, 4));
        EditText aiActivationCodeInput = new EditText(this);
        aiActivationCodeInput.setHint(tr("输入激活码"));
        aiActivationCodeInput.setInputType(InputType.TYPE_CLASS_TEXT);
        aiActivationCodeInput.setSingleLine(true);
        String savedCode = getSharedPreferences("nikon-link", MODE_PRIVATE)
                .getString("ai_activated_code", "");
        aiActivationCodeInput.setText(savedCode == null ? "" : savedCode);
        aiActivationCodeInput.setBackground(rounded(PAPER_2, 8, RULE));
        aiActivationCodeInput.setPadding(dp(12), 0, dp(12), 0);
        aiPanel.addView(aiActivationCodeInput,
                marginParams(-1, dp(44), 0, 0, 0, 6));
        TextView aiActivationStatus = text(
                getSharedPreferences("nikon-link", MODE_PRIVATE)
                        .getBoolean("ai_activated", false)
                        ? "已激活 ✓"
                        : "未激活",
                TS_CAPTION,
                Typeface.NORMAL,
                MUTED);
        aiPanel.addView(aiActivationStatus,
                marginParams(-1, -2, 0, 0, 0, 6));
        Button activateAiBtn = nativeButton("激活", true);
        activateAiBtn.setOnClickListener(view -> {
            String code = aiActivationCodeInput.getText().toString().trim();
            if (code.isEmpty()) {
                aiActivationStatus.setText(tr("请输入激活码"));
                return;
            }
            if (verifyActivationCode(code)) {
                aiActivationStatus.setText(tr("激活成功！AI 功能已解锁"));
                aiActivationCodeInput.setText("");
            } else {
                aiActivationStatus.setText(tr("激活码无效或已过期"));
            }
        });
        aiPanel.addView(activateAiBtn,
                marginParams(-1, dp(44), 0, 0, 0, 10));
        aiPanel.addView(text("恢复设备码", SETTINGS_FS_SUB, Typeface.BOLD, INK),
                marginParams(-1, -2, 0, 0, 0, 6));
        EditText oldDeviceIdInput = new EditText(this);
        oldDeviceIdInput.setHint(tr("旧设备 ID"));
        oldDeviceIdInput.setSingleLine(true);
        oldDeviceIdInput.setInputType(InputType.TYPE_CLASS_TEXT);
        oldDeviceIdInput.setBackground(rounded(PAPER_2, 8, RULE));
        oldDeviceIdInput.setPadding(dp(12), 0, dp(12), 0);
        aiPanel.addView(oldDeviceIdInput,
                marginParams(-1, dp(44), 0, 0, 0, 6));
        EditText oldActivationCodeInput = new EditText(this);
        oldActivationCodeInput.setHint(tr("旧激活码"));
        oldActivationCodeInput.setSingleLine(true);
        oldActivationCodeInput.setInputType(
                InputType.TYPE_CLASS_TEXT
                        | InputType.TYPE_TEXT_VARIATION_PASSWORD);
        oldActivationCodeInput.setBackground(rounded(PAPER_2, 8, RULE));
        oldActivationCodeInput.setPadding(dp(12), 0, dp(12), 0);
        aiPanel.addView(oldActivationCodeInput,
                marginParams(-1, dp(44), 0, 0, 0, 6));
        aiPanel.addView(text(
                "恢复成功后，AI 权益和剩余次数将迁移到当前设备；旧设备绑定会永久失效。",
                SETTINGS_FS_TINY,
                Typeface.NORMAL,
                MUTED),
                marginParams(-1, -2, 0, 0, 0, 8));
        Button rebindAiBtn = nativeButton("恢复到当前设备", false);
        rebindAiBtn.setOnClickListener(view -> {
            String oldDeviceId = oldDeviceIdInput.getText().toString().trim();
            String oldCode = oldActivationCodeInput.getText().toString().trim();
            if (oldDeviceId.isEmpty() || oldCode.isEmpty()) {
                aiActivationStatus.setText(tr("请输入旧设备 ID 和旧激活码"));
                return;
            }
            if (!verifyActivationCodeForDevice(oldCode, oldDeviceId)) {
                aiActivationStatus.setText(
                        tr("旧设备 ID 与旧激活码不匹配或已过期"));
                return;
            }
            rebindAiBtn.setEnabled(false);
            rebindAiBtn.setText(tr("正在迁移…"));
            aiActivationStatus.setText(tr("正在迁移…"));
            activationExecutor.execute(() -> {
                String message;
                boolean succeeded = false;
                try {
                    String currentDeviceId = aiDeviceId();
                    AiRebindResponse response = callAiRebind(
                            oldCode,
                            oldDeviceId,
                            currentDeviceId);
                    if (!verifyActivationCodeForDevice(
                            response.newCode,
                            currentDeviceId)) {
                        throw new Exception(
                                "服务器返回的新激活码验证失败，未修改本机数据");
                    }
                    if (!saveVerifiedActivation(
                            response.newCode,
                            response.remaining)) {
                        throw new Exception("无法保存迁移后的激活码");
                    }
                    message = "设备码恢复成功，AI 权益已迁移到当前设备";
                    succeeded = true;
                } catch (Exception error) {
                    String detail = error.getMessage();
                    message = "设备码恢复失败："
                            + (detail == null || detail.trim().isEmpty()
                                    ? "网络连接失败"
                                    : detail);
                }
                boolean finishedSuccessfully = succeeded;
                String finalMessage = message;
                runOnUiThread(() -> {
                    if (isFinishing() || isDestroyed()) return;
                    rebindAiBtn.setEnabled(true);
                    rebindAiBtn.setText(tr("恢复到当前设备"));
                    aiActivationStatus.setText(tr(finalMessage));
                    if (finishedSuccessfully) {
                        oldDeviceIdInput.setText("");
                        oldActivationCodeInput.setText("");
                    }
                });
            });
        });
        aiPanel.addView(rebindAiBtn,
                marginParams(-1, dp(44), 0, 0, 0, 0));
        content.addView(
                aiPanel,
                marginParams(-1, -2, 0, 18, 0, 0));

        LinearLayout updatePanel = panel();
        updatePanel.addView(text("软件更新", TS_TITLE, Typeface.BOLD, INK));
        updatePanel.addView(text(
                "当前版本 " + currentVersion()
                        + " · 优先通过 Mirror酱检查更新，无可用 CDN 下载地址时自动回退 GitHub Releases。",
                TS_BODY,
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
                TS_CAPTION,
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
        updateStatusText = text(updateStatus, TS_BODY, Typeface.NORMAL, MUTED);
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
        diagnosticsPanel.addView(text("诊断日志", TS_TITLE, Typeface.BOLD, INK));
        TextView logPath = text(
                "日志按日保存、单个文件达到 5 MB 后滚动，保留 14 天。\n"
                        + diagnostics.getDirectory().getAbsolutePath(),
                TS_BODY,
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
                TS_CAPTION,
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
        supportPanel.addView(text("喜欢 帧澈 ZENCHE？", TS_TITLE, Typeface.BOLD, INK));
        supportPanel.addView(text(
                "请作者喝杯奶茶，支持后续维护与新机型适配。",
                SETTINGS_FS_SUB,
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
                TS_BODY,
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

    private View buildMyDevicesView() {
        ScrollView scroll = new ScrollView(this);
        LinearLayout content = verticalContainer();
        content.setPadding(dp(20), dp(22), dp(20), dp(28));
        content.addView(sectionHeader(
                "我的设备",
                "管理连接过的相机，轻触即可快速重连",
                COBALT));

        if (rememberedDevices.isEmpty()) {
            LinearLayout empty = verticalContainer();
            empty.setGravity(Gravity.CENTER);
            empty.setPadding(dp(24), dp(72), dp(24), dp(72));
            empty.setBackground(rounded(SURFACE, 20, RULE));
            TextView icon = text("◉", 46, Typeface.BOLD, COBALT); // 图标尺寸，不受 TypeScale 约束（同 F1 先例）
            icon.setGravity(Gravity.CENTER);
            empty.addView(icon, marginParams(-1, -2, 0, 0, 0, 12));
            TextView title = text(
                    tr("尚未连接过设备"), DEVICE_FS_EMPTY_TITLE, Typeface.BOLD, INK);
            title.setGravity(Gravity.CENTER);
            empty.addView(title);
            TextView detail = text(
                    tr("成功连接相机后会自动保存在这里。"),
                    DEVICE_FS_SUB,
                    Typeface.NORMAL,
                    MUTED);
            detail.setGravity(Gravity.CENTER);
            empty.addView(detail, marginParams(-1, -2, 0, 8, 0, 0));
            content.addView(empty, marginParams(-1, -2, 0, 8, 0, 0));
        } else {
            for (RememberedDevice device : rememberedDevices) {
                content.addView(
                        buildRememberedDeviceCard(device),
                        marginParams(-1, -2, 0, 8, 0, 10));
            }
        }
        scroll.addView(content);
        return scroll;
    }

    private View buildRememberedDeviceCard(RememberedDevice device) {
        LinearLayout card = verticalContainer();
        card.setBackground(rounded(SURFACE, 20, RULE));
        card.setClipToOutline(true);

        ImageView photo = new ImageView(this);
        photo.setImageResource(cameraImageResource(device.vendor));
        photo.setScaleType(ImageView.ScaleType.CENTER_CROP);
        photo.setContentDescription(device.name);
        card.addView(photo, new LinearLayout.LayoutParams(-1, dp(190)));

        LinearLayout body = verticalContainer();
        body.setPadding(dp(16), dp(15), dp(16), dp(16));
        LinearLayout heading = new LinearLayout(this);
        heading.setOrientation(LinearLayout.HORIZONTAL);
        heading.setGravity(Gravity.CENTER_VERTICAL);
        heading.addView(
                text(device.name, TS_TITLE, Typeface.BOLD, INK),
                new LinearLayout.LayoutParams(0, -2, 1f));
        boolean current = connected
                && device.name.equals(connectedCameraName);
        if (current) {
            TextView badge = text(
                    tr("当前已连接"), TS_CAPTION, Typeface.BOLD, POSITIVE);
            badge.setPadding(dp(9), dp(5), dp(9), dp(5));
            badge.setBackground(rounded(POSITIVE_SOFT, 14, 0));
            heading.addView(badge);
        }
        body.addView(heading);
        body.addView(
                text(device.vendor + " · " + device.transport, DEVICE_FS_SUB, Typeface.NORMAL, MUTED),
                marginParams(-1, -2, 0, 8, 0, 0));
        String timestamp = new SimpleDateFormat(
                "yyyy-MM-dd HH:mm",
                Locale.getDefault()).format(new Date(device.lastConnectedAt));
        body.addView(text(
                tr("最近连接") + " · " + timestamp,
                TS_BODY,
                Typeface.NORMAL,
                MUTED));

        LinearLayout actions = new LinearLayout(this);
        actions.setOrientation(LinearLayout.HORIZONTAL);
        actions.setGravity(Gravity.CENTER_VERTICAL);
        Button reconnect = nativeButton("快速连接", true);
        reconnect.setText(tr("快速连接"));
        reconnect.setEnabled(!current && !connecting);
        reconnect.setOnClickListener(view -> {
            if (connected) disconnectCamera();
            connectCamera();
        });
        actions.addView(reconnect, new LinearLayout.LayoutParams(0, dp(46), 1f));
        Button forget = nativeButton("忘记设备", false);
        forget.setText(tr("忘记设备"));
        forget.setOnClickListener(view -> forgetRememberedDevice(device.id));
        LinearLayout.LayoutParams forgetParams =
                new LinearLayout.LayoutParams(dp(112), dp(46));
        forgetParams.setMargins(dp(10), 0, 0, 0);
        actions.addView(forget, forgetParams);
        body.addView(actions, marginParams(-1, -2, 0, 14, 0, 0));
        card.addView(body);
        return card;
    }

    private int cameraImageResource(String vendor) {
        String normalized = vendor.toLowerCase(Locale.ROOT);
        if (normalized.contains("sony")) return R.drawable.camera_sony;
        if (normalized.contains("canon")) return R.drawable.camera_canon;
        return R.drawable.camera_nikon;
    }

    private void loadRememberedDevices() {
        rememberedDevices.clear();
        String raw = getSharedPreferences("nikon-link", MODE_PRIVATE)
                .getString(REMEMBERED_DEVICES_KEY, "[]");
        try {
            JSONArray data = new JSONArray(raw == null ? "[]" : raw);
            for (int index = 0; index < data.length(); index++) {
                JSONObject item = data.getJSONObject(index);
                rememberedDevices.add(new RememberedDevice(
                        item.optString("id"),
                        item.optString("name"),
                        item.optString("vendor", "Camera"),
                        item.optString("transport", "USB/PTP"),
                        item.optLong("lastConnectedAt")));
            }
        } catch (Exception error) {
            diagnostics.warning(
                    "devices",
                    "读取已连接设备失败：" + error.getMessage());
        }
    }

    private void rememberConnectedDevice(
            String id,
            String name,
            String vendor) {
        rememberConnectedDevice(id, name, vendor, "USB/PTP");
    }

    private void rememberConnectedDevice(
            String id,
            String name,
            String vendor,
            String transport) {
        String resolvedVendor = vendor == null || vendor.isEmpty()
                ? "Camera"
                : vendor;
        rememberedDevices.removeIf(item -> item.id.equals(id));
        rememberedDevices.add(0, new RememberedDevice(
                id,
                name,
                resolvedVendor,
                transport,
                System.currentTimeMillis()));
        while (rememberedDevices.size() > 12) {
            rememberedDevices.remove(rememberedDevices.size() - 1);
        }
        persistRememberedDevices();
    }

    private void forgetRememberedDevice(String id) {
        rememberedDevices.removeIf(item -> item.id.equals(id));
        persistRememberedDevices();
        showSection("devices");
    }

    private void persistRememberedDevices() {
        JSONArray data = new JSONArray();
        for (RememberedDevice device : rememberedDevices) {
            JSONObject item = new JSONObject();
            try {
                item.put("id", device.id);
                item.put("name", device.name);
                item.put("vendor", device.vendor);
                item.put("transport", device.transport);
                item.put("lastConnectedAt", device.lastConnectedAt);
                data.put(item);
            } catch (Exception ignored) {
            }
        }
        getSharedPreferences("nikon-link", MODE_PRIVATE)
                .edit()
                .putString(REMEMBERED_DEVICES_KEY, data.toString())
                .apply();
    }

    private void showConnectionDialog() {
        LinearLayout content = verticalContainer();
        content.setPadding(dp(20), dp(18), dp(20), dp(18));

        LinearLayout localCard = verticalContainer();
        localCard.setPadding(dp(18), dp(16), dp(18), dp(16));
        localCard.setBackground(rounded(COBALT_SOFT, 14, 0));
        localCard.addView(text("本机摄像头", TS_TITLE, Typeface.BOLD, INK));
        localCard.addView(text(
                localCameraConnecting
                        ? "正在打开本机摄像头…"
                        : localCameraConnected
                                ? localCamera.getCameraName() + " · 已连接"
                                : "使用手机或平板内置镜头取景、拍照并保存到文件库",
                TS_BODY,
                Typeface.NORMAL,
                localCameraConnected ? POSITIVE : MUTED),
                marginParams(-1, -2, 0, 5, 0, 10));
        Button localButton = nativeButton(
                localCameraConnected ? "断开本机摄像头" : "使用本机摄像头",
                !localCameraConnected);
        localButton.setEnabled(!localCameraConnecting);
        localButton.setOnClickListener(view -> {
            if (localCameraConnected) disconnectLocalCamera();
            else requestLocalCameraConnection();
        });
        localCard.addView(localButton, new LinearLayout.LayoutParams(-1, dp(48)));
        content.addView(localCard, marginParams(-1, -2, 0, 0, 0, 16));

        LinearLayout card = verticalContainer();
        card.setPadding(dp(18), dp(16), dp(18), dp(16));
        card.setBackground(rounded(COBALT_SOFT, 14, 0));
        card.addView(text("原生 USB/PTP 相机", TS_TITLE, Typeface.BOLD, INK));
        card.addView(text(
                "连接后自动识别当前机型与可用参数",
                TS_BODY,
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

        Button usbButton = nativeButton(
                connected ? "断开 USB 相机" : "连接 USB 相机",
                !connected);
        usbButton.setOnClickListener(view -> {
            if (connected) disconnectCamera();
            else connectCamera();
        });
        content.addView(usbButton, marginParams(-1, dp(48), 0, 0, 0, 18));

        ScrollView scroll = new ScrollView(this);
        scroll.addView(content);

        AlertDialog dialog = new AlertDialog.Builder(this)
                .setTitle(tr("连接相机"))
                .setView(scroll)
                .setPositiveButton(tr("关闭"), null)
                .create();
        connectionDialog = dialog;
        dialog.setOnDismissListener(ignored -> {
            if (connectionDialog == dialog) connectionDialog = null;
        });
        dialog.show();
    }

    private void dismissConnectionDialog() {
        AlertDialog dialog = connectionDialog;
        connectionDialog = null;
        if (dialog != null && dialog.isShowing()) dialog.dismiss();
    }

    private void connectWifiCamera(String host, int port, String connectionMode) {
        if (wifiConnecting || wifiConnected) return;
        wifiConnectionMode = "sta".equals(connectionMode) ? "sta" : "ap";
        wifiCameraHost = host;
        wifiCameraPort = port;
        wifiManualDisconnect = false;
        wifiReconnecting = false;
        wifiReconnectAttempt = 0;
        wifiMissedHeartbeats = 0;
        wifiConnecting = true;
        updateConnectionUi();
        cameraExecutor.submit(() -> {
            try {
                String name = wifiCamera.connect(host, port);
                // E4 1.5.9：识别厂商（GetDeviceInfo 0x1001 + 名称启发式）；
                // 尼康/佳能自动开实时取景并拉帧（约 10fps），刷新参数
                // （镜像 Windows E3 连接路径；Android/Harmony 不做 autoStart 门控）。
                wifiVendor = wifiCamera.detectVendor();
                boolean autoLiveView = wifiVendorSupportsRecording();
                if (autoLiveView) {
                    try {
                        wifiCamera.startLiveView();
                        wifiLiveView = true;
                    } catch (Exception liveViewError) {
                        diagnostics.warning(
                                "wifi-liveview",
                                "连接后自动开启实时取景失败："
                                        + liveViewError.getMessage());
                    }
                }
                refreshWifiParameters();
                diagnostics.info(
                        "wifi-camera",
                        "PTP/IP 已连接；模式="
                                + wifiConnectionMode.toUpperCase(Locale.ROOT)
                                + "；相机=" + name
                                + "；厂商=" + wifiVendor);
                mainHandler.post(() -> {
                    wifiCameraName = name;
                    wifiConnected = true;
                    wifiConnecting = false;
                    lastConnectionError = null;
                    if (autoLiveView && wifiLiveView && wifiSourceActive()) {
                        liveViewEnabled = true;
                        updateConnectionUi();
                        startPreviewLoop();
                    } else {
                        updateConnectionUi();
                    }
                    startWifiHeartbeat();
                    registerWifiNetworkCallback();
                    if ("library".equals(currentSection)) showSection("library");
                    showToast(
                            wifiConnectionMode.toUpperCase(Locale.ROOT)
                                    + " · Wi‑Fi 已连接 · " + name);
                });
            } catch (Exception error) {
                diagnostics.error("wifi-camera", "连接失败：" + error.getMessage());
                mainHandler.post(() -> {
                    wifiConnected = false;
                    wifiConnecting = false;
                    lastConnectionError = error.getMessage() != null
                            ? error.getMessage()
                            : tr("连接失败");
                    updateConnectionUi();
                    if ("library".equals(currentSection)) showSection("library");
                    showError(error.getMessage());
                });
            }
        });
    }

    private void requestLocalCameraConnection() {
        if (checkSelfPermission(Manifest.permission.CAMERA)
                != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(
                    new String[]{Manifest.permission.CAMERA},
                    REQUEST_LOCAL_CAMERA);
            return;
        }
        connectLocalCamera();
    }

    private void connectLocalCamera() {
        if (localCameraConnecting || localCameraConnected) return;
        if (connected) disconnectCamera();
        if (wifiConnected) disconnectWifiCamera();
        localCameraConnecting = true;
        updateConnectionUi();
        cameraExecutor.submit(() -> {
            try {
                localCamera.connect();
                String name = localCamera.getCameraName();
                diagnostics.info("local-camera", name + " 已连接");
                mainHandler.post(() -> {
                    localCameraConnecting = false;
                    localCameraConnected = true;
                    connectedCameraName = name;
                    connectedCameraVendor = "System";
                    lastConnectionError = null;
                    liveViewEnabled = false;
                    rememberConnectedDevice(
                            "android-local-camera",
                            name,
                            "System",
                            "本机摄像头");
                    showSection(currentSection);
                    updateConnectionUi();
                    showToast(name + " 已连接，可开启实时取景或直接拍摄。");
                });
            } catch (Exception error) {
                diagnostics.error("local-camera", "连接失败：" + error.getMessage());
                localCamera.close();
                mainHandler.post(() -> {
                    localCameraConnecting = false;
                    localCameraConnected = false;
                    String message = error.getMessage() != null
                            ? error.getMessage()
                            : tr("连接失败");
                    if (error instanceof CameraAccessException) {
                        switch (((CameraAccessException) error).getReason()) {
                            case CameraAccessException.CAMERA_IN_USE:
                                message = tr(
                                        "本机摄像头正被其他应用占用，请先关闭占用相机的应用");
                                break;
                            case CameraAccessException.MAX_CAMERAS_IN_USE:
                                message = tr(
                                        "本机摄像头已达同时使用上限，请先关闭其他相机应用");
                                break;
                            case CameraAccessException.CAMERA_DISABLED:
                                message = tr(
                                        "本机摄像头已被系统禁用，请在系统设置中检查相机权限");
                                break;
                            default:
                                break;
                        }
                    }
                    lastConnectionError = message;
                    updateConnectionUi();
                    showError(message);
                });
            }
        });
    }

    private void disconnectLocalCamera() {
        diagnostics.info("local-camera", "用户断开本机摄像头");
        previewGeneration++;
        pendingPreview.set(null);
        localCameraConnected = false;
        lastConnectionError = null;
        localCameraConnecting = false;
        liveViewEnabled = false;
        videoRecording = false;
        cameraExecutor.submit(() -> {
            finishExternalRecordingForDisconnect();
            localCamera.close();
        });
        connectedCameraName = "Nikon 相机";
        connectedCameraVendor = "Nikon";
        latestFrame = null;
        latestSourceFrame = null;
        latestZebraMask = null;
        updateConnectionUi();
        showSection(currentSection);
    }

    private void disconnectWifiCamera() {
        wifiManualDisconnect = true;
        wifiReconnecting = false;
        mainHandler.removeCallbacks(wifiHeartbeatRunnable);
        mainHandler.removeCallbacks(wifiReconnectRunnable);
        // E4 1.5.9：手动断开——停 Wi‑Fi 取景/录像并清控制状态
        // （镜像 Windows 手动断开 StopWifiPreviewLoop + DisconnectAsync）。
        if (wifiLiveView || wifiMovieRecording || liveViewEnabled) {
            previewGeneration++;
            pendingPreview.set(null);
            liveViewEnabled = false;
        }
        if (wifiMovieRecording) {
            videoRecording = false;
            recordingStartedAt = 0;
        }
        if (wifiLiveView) {
            try {
                wifiCamera.stopLiveView();
            } catch (Exception ignored) {
            }
        }
        wifiLiveView = false;
        wifiMovieRecording = false;
        wifiVendor = PtpIpCamera.CameraVendor.UNKNOWN;
        wifiParameterReadout = "参数待读取 · 连接后自动刷新";
        wifiCamera.close();
        wifiConnected = false;
        lastConnectionError = null;
        wifiConnecting = false;
        wifiCameraName = "PTP/IP Camera";
        updateConnectionUi();
        if ("library".equals(currentSection)) showSection("library");
    }

    // ── B2 WiFi 连接监看：心跳 / 退避重连 / 网络监听 ──

    /** 退避序列（纯函数，契约测试锚点）：1/2/4/8/16 封顶 30s。 */
    static long wifiBackoffDelayMs(int attempt) {
        int index = Math.min(Math.max(attempt, 1), WIFI_RECONNECT_BACKOFF_MS.length) - 1;
        return WIFI_RECONNECT_BACKOFF_MS[index];
    }

    private final Runnable wifiReconnectRunnable = new Runnable() {
        @Override public void run() {
            if (!wifiReconnecting || wifiManualDisconnect) return;
            wifiConnecting = true;
            updateConnectionUi();
            cameraExecutor.submit(() -> {
                try {
                    String name = wifiCamera.connect(
                            wifiCameraHost, wifiCameraPort);
                    // E4 1.5.9：重连成功后恢复厂商识别、取景与参数
                    // （对齐 Windows AttemptWifiReconnectAsync）。
                    wifiVendor = wifiCamera.detectVendor();
                    boolean autoLiveView = wifiVendorSupportsRecording();
                    if (autoLiveView) {
                        try {
                            wifiCamera.startLiveView();
                            wifiLiveView = true;
                        } catch (Exception liveViewError) {
                            diagnostics.warning(
                                    "wifi-liveview",
                                    "重连后自动开启实时取景失败："
                                            + liveViewError.getMessage());
                        }
                    }
                    refreshWifiParameters();
                    diagnostics.info("wifi-camera",
                            "PTP/IP 自动重连成功；相机=" + name
                                    + "；厂商=" + wifiVendor);
                    mainHandler.post(() -> {
                        if (!wifiReconnecting || wifiManualDisconnect) return;
                        wifiReconnecting = false;
                        wifiConnecting = false;
                        wifiConnected = true;
                        wifiCameraName = name;
                        wifiReconnectAttempt = 0;
                        lastConnectionError = null;
                        if (autoLiveView && wifiLiveView && wifiSourceActive()) {
                            liveViewEnabled = true;
                            updateConnectionUi();
                            startPreviewLoop();
                        } else {
                            updateConnectionUi();
                        }
                        startWifiHeartbeat();
                        showToast("Wi‑Fi 已自动重连 · " + name);
                    });
                } catch (Exception error) {
                    diagnostics.error("wifi-camera",
                            "自动重连失败：" + error.getMessage());
                    mainHandler.post(() -> {
                        if (!wifiReconnecting || wifiManualDisconnect) return;
                        wifiConnecting = false;
                        scheduleWifiReconnect();
                    });
                }
            });
        }
    };

    private void startWifiHeartbeat() {
        mainHandler.removeCallbacks(wifiHeartbeatRunnable);
        mainHandler.postDelayed(wifiHeartbeatRunnable, WIFI_HEARTBEAT_INTERVAL_MS);
    }

    /** 连续 3 次心跳无响应 / 网络丢失 → 判离线，进入重连态。 */
    private void enterWifiReconnecting() {
        if (!wifiConnected || wifiReconnecting || wifiManualDisconnect) return;
        wifiReconnecting = true;
        wifiReconnectAttempt = 0;
        mainHandler.removeCallbacks(wifiHeartbeatRunnable);
        // E4 1.5.9：链路离线即停 Wi‑Fi 取景/录像并清控制状态
        // （重连成功后再恢复，对齐 Windows AttemptWifiReconnectAsync）。
        if (wifiLiveView || wifiMovieRecording || liveViewEnabled) {
            previewGeneration++;
            pendingPreview.set(null);
            liveViewEnabled = false;
            if (wifiMovieRecording) {
                videoRecording = false;
                recordingStartedAt = 0;
            }
            if (wifiLiveView) {
                try {
                    wifiCamera.stopLiveView();
                } catch (Exception ignored) {
                }
            }
            wifiLiveView = false;
            wifiMovieRecording = false;
            wifiVendor = PtpIpCamera.CameraVendor.UNKNOWN;
            wifiParameterReadout = "参数待读取 · 连接后自动刷新";
            updateWifiControlCard();
        }
        updateConnectionUi();
        scheduleWifiReconnect();
    }

    private void scheduleWifiReconnect() {
        if (!wifiReconnecting || wifiManualDisconnect) return;
        wifiReconnectAttempt++;
        long delay = wifiBackoffDelayMs(wifiReconnectAttempt);
        diagnostics.info("wifi-camera",
                "调度自动重连（第 " + wifiReconnectAttempt
                        + " 次，退避 " + delay + "ms）");
        mainHandler.removeCallbacks(wifiReconnectRunnable);
        mainHandler.postDelayed(wifiReconnectRunnable, delay);
    }

    /** ConnectivityManager.NetworkCallback：Wi-Fi 网络丢失即判链路不可用。 */
    private void registerWifiNetworkCallback() {
        if (wifiNetworkCallback != null) return;
        ConnectivityManager manager = (ConnectivityManager)
                getSystemService(Context.CONNECTIVITY_SERVICE);
        if (manager == null) return;
        wifiNetworkCallback = new ConnectivityManager.NetworkCallback() {
            @Override public void onLost(Network network) {
                mainHandler.post(() -> {
                    if (wifiConnected && !wifiManualDisconnect) {
                        enterWifiReconnecting();
                    }
                });
            }
        };
        try {
            manager.registerNetworkCallback(
                    new NetworkRequest.Builder()
                            .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
                            .build(),
                    wifiNetworkCallback);
        } catch (Exception ignored) {
            wifiNetworkCallback = null;
        }
    }

    private void unregisterWifiNetworkCallback() {
        ConnectivityManager.NetworkCallback callback = wifiNetworkCallback;
        wifiNetworkCallback = null;
        if (callback == null) return;
        try {
            ConnectivityManager manager = (ConnectivityManager)
                    getSystemService(Context.CONNECTIVITY_SERVICE);
            if (manager != null) manager.unregisterNetworkCallback(callback);
        } catch (Exception ignored) {
        }
    }

    private void setBluetoothRemoteEnabled(boolean enabled) {
        bluetoothRemoteEnabled = enabled;
        getSharedPreferences("nikon-link", MODE_PRIVATE).edit()
                .putBoolean("bluetoothRemoteEnabled", enabled)
                .apply();
        if (!enabled) {
            bluetoothRemote.stop();
            return;
        }
        if (Build.VERSION.SDK_INT >= 31
                && (checkSelfPermission(Manifest.permission.BLUETOOTH_SCAN)
                        != PackageManager.PERMISSION_GRANTED
                || checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT)
                        != PackageManager.PERMISSION_GRANTED)) {
            requestPermissions(
                    new String[]{
                            Manifest.permission.BLUETOOTH_SCAN,
                            Manifest.permission.BLUETOOTH_CONNECT
                    },
                    REQUEST_BLUETOOTH_REMOTE);
            return;
        }
        if (Build.VERSION.SDK_INT < 31
                && checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION)
                        != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(
                    new String[]{Manifest.permission.ACCESS_FINE_LOCATION},
                    REQUEST_BLUETOOTH_REMOTE);
            return;
        }
        bluetoothRemote.start();
    }

    private void setLocationTaggingEnabled(boolean enabled) {
        locationTaggingEnabled = enabled;
        getSharedPreferences("nikon-link", MODE_PRIVATE).edit()
                .putBoolean("captureLocationEnabled", enabled)
                .apply();
        if (!enabled) {
            locationTagging.stop();
            return;
        }
        if (checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION)
                != PackageManager.PERMISSION_GRANTED
                && checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION)
                        != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(
                    new String[]{
                            Manifest.permission.ACCESS_FINE_LOCATION,
                            Manifest.permission.ACCESS_COARSE_LOCATION
                    },
                    REQUEST_CAPTURE_LOCATION);
            return;
        }
        locationTagging.start();
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
                String detectedCameraVendor = camera.getConnectedCameraVendor();
                diagnostics.info("camera", "已连接 " + detectedCameraName);
                mainHandler.post(() -> {
                    connectedCameraName = detectedCameraName;
                    connectedCameraVendor = detectedCameraVendor;
                    rememberConnectedDevice(
                            camera.getConnectedDeviceId(),
                            detectedCameraName,
                            detectedCameraVendor);
                    videoCodecIndex();
                    videoLogIndex();
                    connected = true;
                    connecting = false;
                    liveViewEnabled = false;
                    previewFailureCount = 0;
                    lastConnectionError = null;
                    showSection(currentSection);
                    updateConnectionUi();
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
                    lastConnectionError = error.getMessage() != null
                            ? error.getMessage()
                            : tr("连接失败");
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
        lastConnectionError = null;
        liveViewEnabled = false;
        videoRecording = false;
        cameraExecutor.submit(() -> {
            finishExternalRecordingForDisconnect();
            camera.disconnect();
        });
        connectedCameraName = "Nikon 相机";
        connectedCameraVendor = "Nikon";
        latestFrame = null;
        latestSourceFrame = null;
        latestZebraMask = null;
        updateConnectionUi();
        showSection(currentSection);
    }

    private void toggleLiveView() {
        if (!connected && !localCameraConnected && !wifiConnected) {
            showConnectionDialog();
            return;
        }
        if (liveViewEnabled) {
            previewGeneration++;
            pendingPreview.set(null);
            liveViewEnabled = false;
            if (wifiSourceActive()) wifiLiveView = false;
            latestFrame = null;
            latestSourceFrame = null;
            latestZebraMask = null;
            if (previewImage != null) previewImage.setImageDrawable(null);
            if (zebraImage != null) zebraImage.setImageDrawable(null);
            if (previewPlaceholder != null) {
                previewPlaceholder.setText(tr("实时监看已关闭"));
                previewPlaceholder.setVisibility(View.VISIBLE);
            }
            cameraExecutor.submit(() -> {
                if (wifiSourceActive()) wifiCamera.stopLiveView();
                else if (localCameraConnected) localCamera.stopLiveView();
                else camera.stopLiveView();
            });
            updateConnectionUi();
            if (liveViewButton != null) {
                liveViewButton.setText(tr("开启实时取景"));
            }
        } else {
            cameraExecutor.submit(() -> {
                try {
                    if (wifiSourceActive()) wifiCamera.startLiveView();
                    else if (localCameraConnected) localCamera.startLiveView();
                    else camera.startLiveView();
                    mainHandler.post(() -> {
                        liveViewEnabled = true;
                        if (wifiSourceActive()) wifiLiveView = true;
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
        syncLivePhotoRing();
        pendingPreview.set(null);
        int generation = ++previewGeneration;
        pullPreview(generation);
    }

    /** E5 1.5.9：live 图环形缓冲启停（取景开启时 arm、停止时 disarm）。
     *  TBC-awaiting-hardware。 */
    private void syncLivePhotoRing() {
        boolean anyLiveView = liveViewEnabled
                && (connected || localCameraConnected || wifiConnected);
        if (livePhotoEnabled && anyLiveView) {
            if (!livePhotoClipRecorder.isArmed()) {
                livePhotoClipRecorder.arm(
                        Math.max(4, (int) Math.round(monitorFrameRate)),
                        livePhotoSeconds);
            }
        } else if (livePhotoClipRecorder.isArmed()) {
            livePhotoClipRecorder.disarm();
        }
    }

    private void pullPreview(int generation) {
        if ((!connected && !localCameraConnected && !wifiConnected)
                || !liveViewEnabled
                || generation != previewGeneration) return;
        cameraExecutor.submit(() -> {
            try {
                if (generation != previewGeneration
                        || (!connected && !localCameraConnected && !wifiConnected)
                        || !liveViewEnabled) {
                    return;
                }
                byte[] jpeg = wifiSourceActive()
                        ? wifiCamera.getLiveViewFrame()
                        : localCameraConnected
                                ? localCamera.getLiveViewFrame()
                                : camera.getLiveViewFrame();
                // E5 1.5.9：live 图环形缓冲常开（取景帧同源喂入，仅当开关开启）。
                syncLivePhotoRing();
                if (livePhotoEnabled) {
                    livePhotoClipRecorder.append(jpeg);
                }
                if (externalVideoRecorder.isRecording()) {
                    try {
                        externalVideoRecorder.appendJpeg(jpeg);
                    } catch (Exception recordingError) {
                        diagnostics.error(
                                "external-recording",
                                "外录写入失败：" + recordingError.getMessage());
                        finishExternalRecordingAfterFailure(recordingError);
                    }
                }
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
                        if (wifiSourceActive()) wifiLiveView = false;
                        previewFailureCount = 0;
                        cameraExecutor.submit(() -> {
                            finishExternalRecordingForDisconnect();
                            if (wifiSourceActive()) wifiCamera.stopLiveView();
                            else if (localCameraConnected) localCamera.stopLiveView();
                            else camera.stopLiveView();
                        });
                        updateConnectionUi();
                        showError(
                                "连续 3 次未收到实时取景画面，帧澈 ZENCHE 已停止重试并释放相机。"
                                        + "请检查 USB 线与相机实时取景状态后再开启。");
                    } else {
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
                        || (!connected && !localCameraConnected && !wifiConnected)
                        || !liveViewEnabled) {
                    return;
                }
                BitmapFactory.Options decodeOpts = new BitmapFactory.Options();
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
                // v1.5.7 拍照页监看恢复：拍照页也按帧分析以驱动 RGB 波形，
                // 但显示仍用原图（showProcessedPreview 以 monitoring 判定），
                // 仅在监看/云预设场景替换为处理后的 display。
                boolean scopeAnalysis =
                        packet.monitoring
                                || "capture".equals(currentSection);
                ProcessedPreview output =
                        scopeAnalysis && analyzeFrame
                                ? processPreview(source)
                                : new ProcessedPreview(
                                        packet.monitoring
                                                ? resampleMonitorPreview(source)
                                                : source,
                                        null);
                mainHandler.post(() -> {
                    if (packet.generation != previewGeneration
                            || (!connected && !localCameraConnected && !wifiConnected)
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
        if (!connected && !wifiConnected && !localCameraConnected) {
            showConnectionDialog();
            return;
        }
        if (capturing) return;
        capturing = true;
        if (shutterButton != null) shutterButton.setText(tr("拍摄中…"));
        if ((connected || localCameraConnected) && locationTaggingEnabled) {
            locationTagging.refresh();
        }
        if (!connected && !localCameraConnected) {
            cameraExecutor.submit(() -> {
                try {
                    // E5 1.5.9：Wi‑Fi PTP 拍照不生成 live 图切片——原片在相机
                    // 存储卡内，本地无照片文件可配对，切片会导致孤儿 AVI。
                    wifiCamera.capture();
                    diagnostics.info("wifi-camera", "PTP/IP 快门已触发");
                    mainHandler.post(() -> {
                        capturing = false;
                        if (shutterButton != null) shutterButton.setText(tr("拍摄"));
                        if (statusText != null) {
                            statusText.setText(tr(
                                    "Wi‑Fi 快门已触发 · 原图保存在相机卡内"));
                        }
                        updateConnectionUi();
                    });
                } catch (Exception error) {
                    diagnostics.error(
                            "wifi-camera",
                            "快门失败：" + error.getMessage());
                    mainHandler.post(() -> {
                        capturing = false;
                        if (shutterButton != null) shutterButton.setText(tr("拍摄"));
                        showError(error.getMessage());
                    });
                }
            });
            return;
        }
        cameraExecutor.submit(() -> {
            try {
                // E5 1.5.9：live 图——与 USB 路径同构：先 reserve base，
                // 照片与切片 AVI 同 base 配对。
                String baseName = captureWorkflow.reserveBaseName(
                        localCameraConnected ? "LocalCamera" : connectedCameraName);
                File liveClip = null;
                if (livePhotoEnabled) {
                    liveClip = captureLivePhotoSlice();
                }
                byte[] jpeg = localCameraConnected
                        ? localCamera.capture()
                        : camera.capture();
                boolean liveViewRestored = localCameraConnected
                        ? localCamera.isLiveView()
                        : camera.isLiveView();
                File file = savePhoto(jpeg, baseName, liveClip);
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
                    if (statusText != null) {
                        statusText.setText(tr("已保存 ") + file.getName());
                    }
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
        if (locationTaggingEnabled) {
            locationTagging.refresh();
        }
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
                            null,
                            locationTagging.snapshot());
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
                    if (statusText != null) statusText.setText(shootingTaskStatus);
                });
            } catch (InterruptedException cancelled) {
                restoreTaskCameraState(kind, originalCompensation, originalMode);
                mainHandler.post(() -> {
                    shootingTaskRunning = false;
                    shootingTaskStatus = tr("拍摄任务已取消");
                    showSection(currentSection);
                    if (statusText != null) statusText.setText(shootingTaskStatus);
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
                    if (statusText != null) statusText.setText(shootingTaskStatus);
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
        if (!connected && !localCameraConnected && !wifiConnected) {
            showConnectionDialog();
            return;
        }
        if (localCameraConnected && !externalRecordToDevice) {
            showToast("本机摄像头视频需要开启“外录到当前智能设备”。");
            return;
        }
        if (capturing) return;
        capturing = true;
        updateRecordingButtons();
        cameraExecutor.submit(() -> {
            try {
                // E4 1.5.9：Wi‑Fi 源走机身录像（Nikon 0x920a/0x920b；
                // Canon EVFRecordStatus，TBC-awaiting-hardware；文件保存在相机卡内）。
                if (wifiSourceActive()) {
                    try {
                        if (videoRecording) {
                            wifiCamera.stopMovieRecording();
                            mainHandler.post(() -> {
                                videoRecording = false;
                                wifiMovieRecording = false;
                                recordingStartedAt = 0;
                                capturing = false;
                                updateRecordingButtons();
                                if (statusText != null) {
                                    statusText.setText(tr(
                                            "Wi‑Fi 录像已停止 · 文件保存在相机卡内"));
                                }
                                updateConnectionUi();
                            });
                        } else {
                            if (!wifiVendorSupportsRecording()) {
                                throw new Exception(
                                        "已连相机暂不支持 PTP/IP 远程录像");
                            }
                            wifiCamera.startMovieRecording();
                            mainHandler.post(() -> {
                                videoRecording = true;
                                wifiMovieRecording = true;
                                recordingStartedAt = System.currentTimeMillis();
                                capturing = false;
                                updateRecordingButtons();
                                if (statusText != null) {
                                    statusText.setText(tr(
                                            "● REC · 正在录制到相机存储卡（Wi‑Fi）"));
                                }
                                updateConnectionUi();
                            });
                        }
                    } catch (Exception wifiError) {
                        diagnostics.error(
                                "wifi-recording",
                                "切换 Wi‑Fi 录像失败：" + wifiError.getMessage());
                        mainHandler.post(() -> {
                            wifiMovieRecording = wifiCamera.isMovieRecording();
                            videoRecording = wifiMovieRecording;
                            recordingStartedAt = videoRecording
                                    ? System.currentTimeMillis()
                                    : 0;
                            capturing = false;
                            updateRecordingButtons();
                            showError("Wi‑Fi 录像失败：" + wifiError.getMessage());
                        });
                    }
                    return;
                }
                if (videoRecording) {
                    Exception bodyError = null;
                    if (connected && camera.isMovieRecording()) {
                        try {
                            camera.stopMovieRecording();
                        } catch (Exception error) {
                            bodyError = error;
                        }
                    }
                    ExternalVideoRecorder.Result result =
                            externalVideoRecorder.stopIfRecording();
                    if (result != null) {
                        captureWorkflow.completeExternalRecording(result.file);
                        diagnostics.info(
                                "external-recording",
                                "外录完成；文件=" + result.file.getName()
                                        + "；帧数=" + result.frames
                                        + "；大小=" + result.bytes);
                    }
                    if (bodyError != null) throw bodyError;
                } else {
                    boolean startedLiveView = false;
                    if (externalRecordToDevice && !liveViewEnabled) {
                        if (localCameraConnected) localCamera.startLiveView();
                        else camera.startLiveView();
                        startedLiveView = true;
                    }
                    if (externalRecordToDevice) {
                        File target = captureWorkflow.reserveExternalRecording(
                                connectedCameraName,
                                "avi");
                        externalVideoRecorder.start(target, monitorFrameRate);
                    }
                    Exception bodyError = null;
                    if (connected) {
                        try {
                            camera.startMovieRecording();
                        } catch (Exception error) {
                            bodyError = error;
                        }
                    }
                    if (bodyError != null && !externalVideoRecorder.isRecording()) {
                        throw bodyError;
                    }
                    boolean shouldStartPreview = startedLiveView;
                    Exception bodyStartError = bodyError;
                    mainHandler.post(() -> {
                        if (shouldStartPreview) {
                            liveViewEnabled = true;
                            updateConnectionUi();
                            startPreviewLoop();
                        }
                        if (bodyStartError != null) {
                            showToast("机身录制不可用，已继续外录到当前设备。");
                        }
                    });
                }
                boolean nowRecording = externalVideoRecorder.isRecording()
                        || (connected && camera.isMovieRecording());
                diagnostics.info(
                        "recording",
                        nowRecording
                                ? "视频录制已开始；外录="
                                        + externalVideoRecorder.isRecording()
                                : "视频录制已停止并完成本地封装");
                mainHandler.post(() -> {
                    videoRecording = nowRecording;
                    recordingStartedAt = nowRecording
                            ? System.currentTimeMillis()
                            : 0;
                    capturing = false;
                    updateRecordingButtons();
                    if (statusText != null) {
                        statusText.setText(tr(nowRecording
                                ? externalVideoRecorder.isRecording()
                                        ? "● EXT REC · 正在外录到当前智能设备"
                                        : "● REC · 正在录制到相机存储卡"
                                : "录制已停止 · 外录文件已保存到 ZENCHE 文件库"));
                    }
                    if (!nowRecording) updateFileCount();
                });
            } catch (Exception error) {
                diagnostics.error(
                        "recording",
                        "切换视频录制失败：" + error.getMessage());
                mainHandler.post(() -> {
                    videoRecording = camera.isMovieRecording();
                    recordingStartedAt = videoRecording
                            ? System.currentTimeMillis()
                            : 0;
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
            // fig1: accent when idle (快门大圆), safety red only while recording.
            shutterButton.setBackground(rounded(videoRecording ? VIDEO : UI_ACCENT, 14, 0));
            shutterButton.setTextColor(videoRecording ? Color.WHITE : INK);
            shutterButton.setEnabled(
                    (connected || localCameraConnected || wifiConnected)
                            && !capturing);
        }
        if (immersiveRecordButton != null) {
            immersiveRecordButton.setText(tr(
                    capturing
                            ? "…"
                            : videoRecording ? "■\n停止" : "●\n录制"));
            immersiveRecordButton.setTextColor(videoRecording ? Color.WHITE : INK);
            immersiveRecordButton.setEnabled(
                    (connected || localCameraConnected || wifiConnected)
                            && !capturing);
        }
    }

    private void finishExternalRecordingAfterFailure(Exception cause) {
        try {
            ExternalVideoRecorder.Result result =
                    externalVideoRecorder.stopIfRecording();
            if (result != null) {
                captureWorkflow.completeExternalRecording(result.file);
            }
        } catch (Exception finishError) {
            externalVideoRecorder.abort();
        }
        mainHandler.post(() -> {
            videoRecording = connected && camera.isMovieRecording();
            if (!videoRecording) recordingStartedAt = 0;
            updateRecordingButtons();
            showError("外录已停止：" + cause.getMessage());
            updateFileCount();
        });
    }

    private void finishExternalRecordingForDisconnect() {
        try {
            ExternalVideoRecorder.Result result =
                    externalVideoRecorder.stopIfRecording();
            if (result != null) {
                captureWorkflow.completeExternalRecording(result.file);
                diagnostics.info(
                        "external-recording",
                        "连接结束，已安全保存外录：" + result.file.getName());
            }
        } catch (Exception error) {
            externalVideoRecorder.abort();
            diagnostics.error(
                    "external-recording",
                    "连接结束时无法完成外录：" + error.getMessage());
        }
    }

    private ProcessedPreview processPreview(Bitmap source) {
        CubeLut lut = previewLut;
        Bitmap graded = lutEnabled && lut != null ? lut.apply(source) : source;
        ProfessionalMonitor.Result monitor = ProfessionalMonitor.process(
                graded,
                focusPeakingEnabled,
                falseColorEnabled,
                monitorNikonCloudPreset);
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
            previewImage.setImageBitmap(
                    monitoring || monitorNikonCloudPreset != null
                            ? output.display : source);
        }
        if (zebraImage != null) {
            zebraImage.setImageBitmap(
                    monitoring && zebraEnabled ? output.zebra : null);
        }
        if (immersivePreviewImage != null) {
            immersivePreviewImage.setImageBitmap(
                    immersiveMonitoring || monitorNikonCloudPreset != null
                            ? output.display : source);
        }
        if (immersiveZebraImage != null) {
            immersiveZebraImage.setImageBitmap(
                    immersiveMonitoring && zebraEnabled ? output.zebra : null);
        }
        if (monitorRgbScopeView != null) {
            monitorRgbScopeView.setData(
                    redHistogram, greenHistogram, blueHistogram);
        }
        if (captureScopeView != null) {
            captureScopeView.setData(
                    redHistogram, greenHistogram, blueHistogram);
        }
        if (professionalScopeView != null) {
            professionalScopeView.setData(
                    redHistogram, greenHistogram, blueHistogram);
        }
        if (immersiveScopeView != null) {
            immersiveScopeView.setData(
                    redHistogram, greenHistogram, blueHistogram);
        }
        if (peakingCoverageText != null) {
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
        return savePhoto(jpeg, null, null);
    }

    private File savePhoto(
            byte[] jpeg,
            String baseName,
            File liveClip) throws Exception {
        if (liveClip != null && baseName != null) {
            File stored = captureWorkflow.store(
                    jpeg,
                    "capture.jpg",
                    connectedCameraName,
                    baseName,
                    locationTagging.snapshot(),
                    baseName + "_live.avi");
            captureWorkflow.storeLivePhotoClip(
                    liveClip,
                    baseName,
                    stored.getName(),
                    connectedCameraName);
            return stored;
        }
        return captureWorkflow.store(
                jpeg,
                "capture.jpg",
                connectedCameraName,
                null,
                locationTagging.snapshot());
    }

    /** E5 1.5.9：把环形缓冲最近 N 秒帧切为临时 AVI；环为空返回 null。
     *  TBC-awaiting-hardware。 */
    private File captureLivePhotoSlice() {
        try {
            File temp = new File(getCacheDir(), "livephoto-" + System.nanoTime() + ".avi");
            ExternalVideoRecorder.Result clip =
                    livePhotoClipRecorder.captureSlice(temp);
            return clip == null ? null : temp;
        } catch (Exception error) {
            diagnostics.warning(
                    "live-photo",
                    "live 图切片失败：" + error.getMessage());
            return null;
        }
    }

    private void applyParameter(String name, Object value, String label) {
        if (!connected) {
            showToast("连接支持的相机后才能调整参数。");
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
                    if ("videoCodec".equals(name)) {
                        videoCodec = String.valueOf(value);
                        getSharedPreferences("nikon-link", MODE_PRIVATE)
                                .edit()
                                .putString("videoCodec", videoCodec)
                                .apply();
                    }
                    if ("videoLog".equals(name)) {
                        videoLogProfile = String.valueOf(value);
                        nLogEnabled = !"off".equals(videoLogProfile);
                        getSharedPreferences("nikon-link", MODE_PRIVATE)
                                .edit()
                                .putString("videoLogProfile", videoLogProfile)
                                .putBoolean("nLogEnabled", nLogEnabled)
                                .apply();
                    }
                    if (statusText != null) {
                        statusText.setText(tr(label) + tr("已应用"));
                    }
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
        boolean anyCamera = connected || wifiConnected || localCameraConnected;
        if (connectionDot != null) {
            connectionDot.setTextColor(anyCamera ? POSITIVE : MUTED);
        }
        if (connectButton != null) {
            connectButton.setText(tr(
                    connecting || wifiConnecting || localCameraConnecting
                            ? "正在连接…"
                            : anyCamera
                                    ? "断开 "
                                            + (connected
                                                    ? connectedCameraName.replace("Nikon ", "")
                                                    : localCameraConnected
                                                            ? "本机摄像头"
                                                            : "Wi‑Fi")
                                    : "连接相机"));
            connectButton.setEnabled(
                    !connecting && !wifiConnecting && !localCameraConnecting);
        }
        if (statusText != null) {
            statusText.setText(tr(connecting || wifiConnecting || localCameraConnecting
                    ? (wifiConnecting
                            ? "正在连接 Wi‑Fi 相机"
                            : localCameraConnecting
                                    ? "正在打开本机摄像头"
                                    : "正在检测 Nikon 相机")
                    : connected
                            ? connectedCameraName + " · USB/PTP"
                            : localCameraConnected
                                    ? localCamera.getCameraName() + " · 本机摄像头"
                            : wifiConnected
                                    ? wifiCameraName + " · Wi‑Fi/PTP‑IP"
                            : "未连接"));
        }
        if (liveViewButton != null) {
            liveViewButton.setText(
                    tr(liveViewEnabled ? "停止实时取景" : "开启实时取景"));
        }
        if (liveMonitoringSwitch != null) {
            syncingLiveMonitoringSwitch = true;
            liveMonitoringSwitch.setChecked(liveViewEnabled);
            liveMonitoringSwitch.setEnabled(anyCamera);
            syncingLiveMonitoringSwitch = false;
        }
        if (liveMonitoringDetail != null) {
            liveMonitoringDetail.setText(tr(
                    liveViewEnabled ? "显示相机实时画面" : "实时监看已关闭"));
        }
        updateCameraControls();
        updateRecordingButtons();
        updateWifiControlCard();
        updateFileCount();
        // fig1: keep the capture-page status row in sync with connection state
        // changes that don't rebuild the page (no-op when capture UI absent).
        refreshControlStatusRow();
    }

    private void updateCameraControls() {
        for (View control : cameraControls) control.setEnabled(connected);
        if (liveViewButton != null) {
            liveViewButton.setEnabled(
                    connected || localCameraConnected || wifiConnected);
        }
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
        if (shutterButton != null && !"monitor".equals(currentSection)) {
            shutterButton.setEnabled(
                    (connected || wifiConnected || localCameraConnected) && !capturing);
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
        if (countText == null) return;
        countText.setText(tr("文件库 · %lld 个文件")
                .replace("%lld", Integer.toString(photoFiles().size())));
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
                    || lower.endsWith(".m4v")
                    || lower.endsWith(".avi");
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
        // v1.5.7 issue 655a0a14: 视频页参数/输出面板强制恒深（UI_CARD 井）+ 白字，其他页仍随主题
        boolean monitor = "monitor".equals(currentSection);
        panel.setBackground(rounded(monitor ? UI_CARD : SURFACE, 16, monitor ? UI_SECONDARY : RULE));
        panel.setElevation(dp(2));
        LinearLayout.LayoutParams params = marginParams(-1, -2, 0, 12, 0, 0);
        panel.setLayoutParams(params);
        return panel;
    }

    private View sectionHeader(String title, String subtitle, int accent) {
        boolean compact = isCompactPhone();
        LinearLayout header = new LinearLayout(this);
        header.setOrientation(LinearLayout.HORIZONTAL);
        header.setGravity(Gravity.TOP);

        View rail = new View(this);
        rail.setBackground(rounded(accent, 2, 0));
        LinearLayout.LayoutParams railParams = new LinearLayout.LayoutParams(dp(4), dp(44));
        railParams.setMargins(0, dp(2), dp(compact ? 10 : 12), 0);
        header.addView(rail, railParams);

        LinearLayout copy = verticalContainer();
        copy.addView(text(title, compact ? PAGE_FS_HEADING_COMPACT : PAGE_FS_HEADING, Typeface.BOLD, INK));
        copy.addView(
                text(subtitle, compact ? TS_BODY : PAGE_FS_SUBTITLE, Typeface.NORMAL, MUTED),
                marginParams(-1, -2, 0, 3, 0, 0));
        header.addView(copy, new LinearLayout.LayoutParams(
                0,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                1f));
        header.setLayoutParams(marginParams(-1, -2, 0, 0, 0, compact ? 14 : 20));
        return header;
    }

    private boolean isCompactPhone() {
        return getResources().getConfiguration().smallestScreenWidthDp < 600;
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
        if (loginWallVisible) {
            showLoginWall();
        }
        updateConnectionUi();
        updateWirelessUi();
        refreshUpdateUi();
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
                TS_EMPHASIS,
                Typeface.BOLD,
                INK));
        card.addView(
                text(
                        "公开问题可继续在 GitHub 免费提交；在爱发电赞助后，可获取快速问题反馈渠道。",
                TS_BODY,
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

    private GradientDrawable brandGradient(int radiusDp) {
        GradientDrawable drawable = new GradientDrawable(
                GradientDrawable.Orientation.TL_BR,
                new int[]{COBALT, Color.rgb(46, 134, 224)});
        drawable.setCornerRadius(dp(radiusDp));
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

    /** 相机权限被永久拒绝（勾选"不再询问"）时引导跳系统应用设置页。 */
    private void showCameraPermissionSettingsGuide() {
        diagnostics.error(
                "local-camera",
                "相机权限被永久拒绝，引导用户前往系统设置");
        new AlertDialog.Builder(this)
                .setTitle("需要相机权限")
                .setMessage(
                        "本机摄像头权限已被永久拒绝。"
                                + "请前往系统设置开启相机权限后再试。")
                .setNegativeButton(tr("取消"), null)
                .setPositiveButton(tr("去设置"), (dialog, which) -> {
                    Intent intent = new Intent(
                            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                            Uri.parse("package:" + getPackageName()));
                    try {
                        startActivity(intent);
                    } catch (RuntimeException error) {
                        diagnostics.error(
                                "local-camera",
                                "无法打开系统设置："
                                        + error.getMessage());
                        showToast(
                                "无法打开系统设置，请在系统设置中手动开启相机权限");
                    }
                })
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
                    candidate = checkSelfHostedUpdate();
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
                } catch (Exception selfHostedError) {
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

    private UpdateCandidate checkSelfHostedUpdate() throws Exception {
        String configured = System.getenv("ZENCHE_UPDATE_ENDPOINT");
        String endpoint = configured == null || configured.trim().isEmpty()
                ? DEFAULT_SELF_HOSTED_UPDATE_ENDPOINT
                : configured.trim();
        Uri.Builder builder = Uri.parse(endpoint).buildUpon()
                .appendQueryParameter("platform", "android")
                .appendQueryParameter("arch", mirrorChyanArchitecture())
                .appendQueryParameter("current_version", currentVersion())
                .appendQueryParameter("channel", "stable")
                .appendQueryParameter("installId", anonymousInstallId());
        JSONObject root = requestJson(
                builder.build().toString(),
                "ZENCHE-Android/" + currentVersion());
        if (root.optInt("schema_version", -1) != 1
                || !"ZENCHE".equalsIgnoreCase(root.optString("product"))) {
            throw new IllegalStateException("Invalid self-hosted update feed");
        }
        String version = normalizeVersion(
                root.optString("version", currentVersion()));
        String url = root.optString("url", "");
        if (url.isEmpty()) {
            url = root.optString("release_url", RELEASES_URL);
        }
        String updateType = root.optString("update_type", "");
        if ("incremental".equalsIgnoreCase(updateType)) {
            url = "";
        }
        String notice = null;
        JSONObject announcement = root.optJSONObject("announcement");
        if (announcement != null) {
            String title = announcement.optString("title", "").trim();
            String body = announcement.optString("body", "").trim();
            String combined = title.isEmpty() ? body
                    : (body.isEmpty() ? title : title + "：" + body);
            if (!combined.isEmpty()) notice = combined;
        }
        return new UpdateCandidate(
                version,
                url.isEmpty() ? null : url,
                notice);
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
            return version == null || version.isEmpty() ? "1.5.11" : version;
        } catch (Exception error) {
            return "1.5.11";
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
                TS_BODY,
                Typeface.NORMAL,
                MUTED),
                marginParams(-1, -2, 0, 0, 0, 12));
        TextView logView = text(
                diagnostics.recentText(12_000),
                TS_CAPTION,
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
                TS_CAPTION,
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
                        tr("• 五端登录页将模式选项明确为“已有账号 / 创建账号”，真正的登录按钮会持续显示提交状态，避免误点后看似无响应。\n"
                                + "• macOS 与 Windows 新增桌面工作区布局：两端会在重启后恢复主窗口大小和位置，Windows 还会恢复最大化状态。\n"
                                + "• 主导航、拍摄参数、编辑媒体池、工具栏与底部工具区可拖动调整；分隔条支持键盘和辅助功能名称。\n"
                                + "• 新增默认、拍摄、监看、编辑与紧凑预设，并可一键恢复默认布局。\n"
                                + "• 1.5.11 为本地开发验证候选；各平台签名状态不同，请在安装前核对 SHA-256 并查阅逐包说明。Windows 布局仍需在真实 Windows 多显示器/DPI 环境复核。"),
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
        if (nikonCloudPresetDialog != null) {
            nikonCloudPresetDialog.dismiss();
            nikonCloudPresetDialog = null;
        }
        if (immersiveDialog != null) {
            closeImmersivePreview(immersiveDialog);
        }
        wirelessRequested = false;
        wirelessServer.stop();
        bluetoothRemote.stop();
        locationTagging.stop();
        wifiCamera.close();
        unregisterWifiNetworkCallback();
        localCamera.close();
        finishExternalRecordingForDisconnect();
        cameraExecutor.submit(camera::disconnect);
        cameraExecutor.shutdown();
        previewExecutor.shutdownNow();
        updateExecutor.shutdownNow();
        editorExecutor.shutdownNow();
        storageExecutor.shutdownNow();
        activationExecutor.shutdownNow();
        super.onDestroy();
    }
}
