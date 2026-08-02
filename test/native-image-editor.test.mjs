import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../", import.meta.url);
const read = async (path) => readFile(new URL(path, root), "utf8");

test("all native targets expose image editing in primary navigation", async () => {
  const [iosModel, iosView, android, harmony, macos, windowsXaml, windows] =
    await Promise.all([
      read("native/ios/NikonLink/Models/AppModel.swift"),
      read("native/ios/NikonLink/Views/RootView.swift"),
      read("native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java"),
      read("native/harmony/entry/src/main/ets/pages/Index.ets"),
      read("native/macos/Sources/NikonLink/main.swift"),
      read("native/windows/MainWindow.xaml"),
      read("native/windows/MainWindow.xaml.cs"),
    ]);

  assert.match(iosModel, /case editor = "编辑"/);
  assert.match(iosView, /case \.editor:[\s\S]*ImageEditorPage/);
  assert.match(android, /navButton\("编辑", "editor"\)/);
  assert.match(android, /case "editor":[\s\S]*buildImageEditorView/);
  assert.match(harmony, /NavButton\('图像编辑', 'editor'\)/);
  assert.match(harmony, /this\.ImageEditorWorkspace\(\)/);
  assert.match(macos, /case editor = "编辑"/);
  assert.match(macos, /case \.editor:[\s\S]*ImageEditorView/);
  assert.match(windowsXaml, /x:Name="EditorNav"/);
  assert.match(windowsXaml, /x:Name="EditorPanel"/);
  assert.match(windows, /destination == "editor"/);
});

test("all native editors provide professional grouped adjustments", async () => {
  const [
    iosModel,
    iosView,
    android,
    harmony,
    harmonyLibrary,
    macos,
    windowsXaml,
    windows,
  ] = await Promise.all([
    read("native/ios/NikonLink/Models/AppModel.swift"),
    read("native/ios/NikonLink/Views/RootView.swift"),
    read("native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java"),
    read("native/harmony/entry/src/main/ets/pages/Index.ets"),
    read("native/harmony/entry/src/main/ets/storage/PhotoLibrary.ets"),
    read("native/macos/Sources/NikonLink/main.swift"),
    read("native/windows/MainWindow.xaml"),
    read("native/windows/MainWindow.xaml.cs"),
  ]);

  const editorSources = [
    iosView,
    android,
    harmony,
    macos,
    `${windowsXaml}\n${windows}`,
  ];
  const sections = ["光线", "色彩", "细节", "效果", "几何"];
  const adjustments = [
    "曝光",
    "对比度",
    "高光",
    "阴影",
    "白色色阶",
    "黑色色阶",
    "色温",
    "色调",
    "自然饱和度",
    "饱和度",
    "纹理",
    "清晰度",
    "锐化",
    "降噪",
    "去雾",
    "暗角",
    "裁切比例",
    "水平翻转",
    "垂直翻转",
  ];

  for (const source of editorSources) {
    assert.match(source, /专业显影/);
    assert.match(source, /分组调整光线、色彩、细节、效果与几何；始终保留原文件。/);
    assert.match(source, /AI 智能修图/);
    for (const section of sections) {
      assert.match(source, new RegExp(section));
    }
    for (const adjustment of adjustments) {
      assert.match(source, new RegExp(adjustment));
    }
    assert.match(source, /旋转 90°/);
    assert.match(source, /原始比例/);
    assert.match(source, /自然增强/);
    assert.match(source, /人像柔和/);
    assert.match(source, /风光通透/);
    assert.match(source, /高反差黑白/);
    assert.match(source, /查看原图/);
    assert.match(source, /返回调整/);
    assert.match(source, /全部重置/);
    assert.match(source, /保存高质量副本/);
  }

  // Keep the original develop workflow visible while AI remains additive.
  assert.match(android, /private TextView statusText/);
  assert.match(android, /private TextView countText/);
  assert.match(android, /private View buildStatusBar\(\)/);
  assert.match(android, /private void updateFileCount\(\)/);
  assert.match(android, /statusText\.setText/);
  assert.match(android, /updateFileCount\(\)/);

  assert.match(iosView, /ProfessionalEditSettings/);
  assert.match(iosView, /CIExposureAdjust/);
  assert.match(iosView, /CITemperatureAndTint/);
  assert.match(iosView, /CIHighlightShadowAdjust/);
  assert.match(iosView, /CIVibrance/);
  assert.match(iosView, /CIColorControls/);
  assert.match(iosView, /CIUnsharpMask/);
  assert.match(iosView, /CINoiseReduction/);
  assert.match(iosView, /CIVignette/);
  assert.match(iosView, /jpegData\(compressionQuality: 0\.95\)/);
  assert.match(iosModel, /saveEditedImage/);

  assert.match(android, /class EditorAdjustments/);
  assert.match(android, /renderEditedBitmap/);
  assert.match(android, /applyEditorDetail/);
  assert.match(android, /applyEditorGeometry/);
  assert.match(android, /smoothStep/);
  assert.match(android, /Bitmap\.CompressFormat\.JPEG/);
  assert.match(
    android,
    /output\.compress\([\s\S]*?Bitmap\.CompressFormat\.JPEG,\s*95,/,
  );

  assert.match(harmony, /PixelMapFormat\.RGBA_8888/);
  assert.match(harmony, /processEditorPixels/);
  assert.match(harmony, /processEditorDetailPixels/);
  assert.match(harmony, /writeBufferToPixels/);
  assert.match(harmony, /pixelMap\.flip/);
  assert.match(harmony, /pixelMap\.crop/);
  assert.match(harmony, /format: 'image\/jpeg'/);
  assert.match(harmony, /quality: 95/);
  assert.match(harmonyLibrary, /saveEditedCopy/);

  assert.match(macos, /ProfessionalEditSettings/);
  assert.match(macos, /CIExposureAdjust/);
  assert.match(macos, /CITemperatureAndTint/);
  assert.match(macos, /CIHighlightShadowAdjust/);
  assert.match(macos, /CIVibrance/);
  assert.match(macos, /CIColorControls/);
  assert.match(macos, /CIUnsharpMask/);
  assert.match(macos, /CINoiseReduction/);
  assert.match(macos, /CIVignette/);
  assert.match(macos, /NSBitmapImageRep/);
  assert.match(macos, /compressionFactor: 0\.95/);

  assert.match(windowsXaml, /EditorAdjustmentHost/);
  assert.match(windows, /class EditorAdjustments/);
  assert.match(windows, /RenderEditedBitmap/);
  assert.match(windows, /ApplyEditorDetail/);
  assert.match(windows, /CroppedBitmap/);
  assert.match(windows, /JpegBitmapEncoder/);
  assert.match(windows, /QualityLevel = 95/);
});

test("all native editors provide on-device AI enhancement with visible controls", async () => {
  const [ios, android, harmony, macos, windowsXaml, windows] =
    await Promise.all([
      read("native/ios/NikonLink/Views/RootView.swift"),
      read("native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java"),
      read("native/harmony/entry/src/main/ets/pages/Index.ets"),
      read("native/macos/Sources/NikonLink/main.swift"),
      read("native/windows/MainWindow.xaml"),
      read("native/windows/MainWindow.xaml.cs"),
    ]);

  for (const source of [ios, android, harmony, macos, `${windowsXaml}\n${windows}`]) {
    assert.match(source, /智能优化/);
    assert.match(source, /AI 强度/);
    assert.match(source, /撤销 AI/);
    assert.match(source, /设备端/);
    assert.match(source, /照片不会上传/);
    assert.match(source, /shadowRatio|ShadowRatio/);
    assert.match(source, /highlightRatio|HighlightRatio/);
    assert.match(source, /saturation|Saturation/);
    assert.match(source, /detail|Detail/);
    assert.match(source, /分析画面|AnalyzeEditorAI_Click|analyzeAI|analyzeEditorPhoto/);
    assert.match(source, /复制 AI|CopyEditorAI_Click|editorAICopiedSettings|editorAICopiedTone/);
    assert.match(source, /粘贴 AI|PasteEditorAI_Click|copiedAISettings|editorAICopiedTone/);
    assert.match(source, /动态范围|Dynamic range/);
  }

  assert.match(ios, /analyzeForAI/);
  assert.match(android, /analyzeEditorPhoto/);
  assert.match(harmony, /analyzeEditorPhoto/);
  assert.match(macos, /analyzeForAI/);
  assert.match(windows, /AnalyzeEditorPhoto/);
});

test("all native AI workspaces keep creation controls and make authorization state visible", async () => {
  const [ios, android, harmony, macos, windowsXaml, windows] =
    await Promise.all([
      read("native/ios/NikonLink/Views/RootView.swift"),
      read("native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java"),
      read("native/harmony/entry/src/main/ets/pages/Index.ets"),
      read("native/macos/Sources/NikonLink/main.swift"),
      read("native/windows/MainWindow.xaml"),
      read("native/windows/MainWindow.xaml.cs"),
    ]);

  assert.match(ios, /AI 创作/);
  assert.match(ios, /需要激活|已解锁/);
  assert.match(ios, /输入修图描述|输入生图描述/);
  assert.match(ios, /宽高比/);
  assert.match(ios, /分辨率/);
  assert.match(ios, /保存到文件库/);

  assert.match(android, /AI 创作/);
  assert.match(android, /剩余.*次|需要激活/);
  assert.match(android, /输出参数/);
  assert.match(android, /AI_RATIOS/);
  assert.match(android, /AI_RESOLUTIONS/);
  assert.doesNotMatch(android, /content\.addView\(aiStatus[\s\S]*content\.addView\(aiStatus/);

  assert.match(harmony, /AI 创作/);
  assert.match(harmony, /需要激活|已解锁/);
  assert.match(harmony, /输出参数/);
  assert.match(harmony, /aiRatioIndex/);
  assert.match(harmony, /aiResolutionIndex/);
  assert.match(harmony, /保存到文件库/);

  assert.match(macos, /AI 创作/);
  assert.match(macos, /需要激活|已解锁/);
  assert.match(macos, /输出参数|宽高比/);
  assert.match(macos, /保存到文件库/);

  assert.match(windowsXaml, /AiUnlockStatus/);
  assert.match(windowsXaml, /AiRatioBox/);
  assert.match(windowsXaml, /AiResolutionBox/);
  assert.match(windows, /AiRatioBox_SelectionChanged/);
  assert.match(windows, /AiResolutionBox_SelectionChanged/);
});

test("AI server address is no longer editable in native Settings while legacy readers remain", async () => {
  const [ios, android, harmony, macosSettings, macosMain, windowsXaml, windows] =
    await Promise.all([
      read("native/ios/NikonLink/Views/RootView.swift"),
      read("native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java"),
      read("native/harmony/entry/src/main/ets/pages/Index.ets"),
      read("native/macos/Sources/NikonLink/SettingsSheet.swift"),
      read("native/macos/Sources/NikonLink/main.swift"),
      read("native/windows/MainWindow.xaml"),
      read("native/windows/MainWindow.xaml.cs"),
    ]);

  assert.doesNotMatch(ios, /@AppStorage\("aiServerURL"\)[\s\S]{0,120}TextField\("AI 服务地址"/);
  assert.doesNotMatch(ios, /TextField\("AI 服务地址"/);
  assert.match(ios, /UserDefaults\.standard\.string\(forKey: "aiServerURL"\)/);

  assert.doesNotMatch(android, /aiServerUrlInput|saveAiServerUrl|保存服务器地址/);
  assert.match(android, /\.getString\("aiServerURL", "http:\/\/101\.34\.255\.115:8787"\)/);

  assert.doesNotMatch(harmony, /aiServerInput|服务器地址（默认 http:\/\/101\.34\.255\.115:8787）/);
  assert.match(harmony, /prefs\.getSync\('ai_server_url', 'http:\/\/101\.34\.255\.115:8787'\)/);

  assert.doesNotMatch(macosSettings, /serverURL|AI 服务器|服务器地址（如/);
  assert.match(macosMain, /UserDefaults\.standard\.string\(forKey: "aiServerURL"\)/);

  assert.doesNotMatch(windowsXaml, /AiServerUrlBox/);
  assert.doesNotMatch(windows, /SaveAiServerUrl|AiServerUrlBox|保存服务器地址/);
  assert.match(windows, /Path\.Combine\(AiDataDir, "ai-server-url\.txt"\)/);
});

test("mobile editor navigation opens professional develop and exposes an explicit AI mode switch", async () => {
  const [android, harmony] = await Promise.all([
    read("native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java"),
    read("native/harmony/entry/src/main/ets/pages/Index.ets"),
  ]);

  assert.match(android, /if \("editor"\.equals\(section\)\) \{[\s\S]*?editorState = EditorState\.PRO;[\s\S]*?showSection\(section\);/);
  assert.match(android, /● 专业显影/);
  assert.match(android, /● AI 工具/);
  assert.match(android, /private View buildImageEditorView\(\)[\s\S]*?modeRow/);

  assert.match(harmony, /if \(target === 'editor'\) \{[\s\S]*?this\.editorTabMode = 'pro';[\s\S]*?this\.section = target;/);
  assert.match(harmony, /private EditorModeSwitcher\(\)/);
  assert.match(harmony, /● 专业显影/);
  assert.match(harmony, /● AI 工具/);
});

test("all native AI activation settings expose the bound device ID and copy action", async () => {
  const [ios, android, harmony, macosSettings, macosMain, windowsXaml, windows] =
    await Promise.all([
      read("native/ios/NikonLink/Views/RootView.swift"),
      read("native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java"),
      read("native/harmony/entry/src/main/ets/pages/Index.ets"),
      read("native/macos/Sources/NikonLink/SettingsSheet.swift"),
      read("native/macos/Sources/NikonLink/main.swift"),
      read("native/windows/MainWindow.xaml"),
      read("native/windows/MainWindow.xaml.cs"),
    ]);

  assert.match(ios, /我的设备 ID/);
  assert.match(ios, /UIPasteboard\.general\.string = ActivationManager\.deviceId/);
  assert.match(ios, /Text\(ActivationManager\.deviceId\)/);
  assert.match(ios, /SecureField\("输入激活码"/);

  assert.match(android, /我的设备 ID/);
  assert.match(android, /ClipData\.newPlainText\([\s\S]*aiDeviceId\(\)/);
  assert.match(android, /aiActivationCodeInput/);
  assert.match(android, /verifyActivationCode\(code\)/);

  assert.match(harmony, /pasteboard/);
  assert.match(harmony, /copyDeviceIdToClipboard/);
  assert.match(harmony, /Text\('我的设备 ID'\)/);
  assert.match(harmony, /this\.getDeviceId\(\)/);

  assert.match(macosSettings, /我的设备 ID/);
  assert.match(macosSettings, /NSPasteboard\.general[\s\S]*ActivationManager\.deviceId/);
  assert.match(macosMain, /static var deviceId: String/);

  assert.match(windowsXaml, /AiDeviceIdText/);
  assert.match(windowsXaml, /AiCopyDeviceId_Click/);
  assert.match(windows, /GetDeviceId\(\)/);
  assert.match(windows, /Clipboard\.SetText\(GetDeviceId\(\)\)/);
});

test("all native AI activation settings link to official redemption and show Afdian QR purchase guidance", async () => {
  const [ios, iosProject, android, harmony, macosSettings, macosBuild, windowsXaml, windows] =
    await Promise.all([
      read("native/ios/NikonLink/Views/RootView.swift"),
      read("native/ios/NikonLink.xcodeproj/project.pbxproj"),
      read("native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java"),
      read("native/harmony/entry/src/main/ets/pages/Index.ets"),
      read("native/macos/Sources/NikonLink/SettingsSheet.swift"),
      read("scripts/build-macos.sh"),
      read("native/windows/MainWindow.xaml"),
      read("native/windows/MainWindow.xaml.cs"),
    ]);

  for (const text of [ios, android, harmony, macosSettings, windowsXaml]) {
    assert.match(text, /前往官网兑换密钥/);
    assert.match(text, /在爱发电购买兑换码/);
  }
  for (const text of [ios, android, harmony, macosSettings, windows]) {
    assert.match(text, /https:\/\/zenche\.top/);
  }

  assert.match(ios, /UIImage\(named: "wechat-donation"\)/);
  assert.match(iosProject, /wechat-donation\.png in Resources/);
  assert.match(android, /getAssets\(\)\.open\("wechat-donation\.png"\)/);
  assert.match(harmony, /app\.media\.afdian_donation/);
  assert.match(macosSettings, /forResource: "wechat-donation"/);
  assert.match(macosBuild, /wechat-donation\.png/);
  assert.match(windowsXaml, /Assets\/wechat-donation\.png/);
  assert.match(windows, /AiOfficialWebsite_Click/);
});

test("phone branch workspaces default to collapsible drawers", async () => {
  const [ios, android, harmony, design] = await Promise.all([
    read("native/ios/NikonLink/Views/RootView.swift"),
    read("native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java"),
    read("native/harmony/entry/src/main/ets/pages/Index.ets"),
    read("design.md"),
  ]);

  assert.match(ios, /mobileBranchDrawerExpanded = false/);
  assert.match(ios, /horizontalSizeClass == \.compact/);
  assert.match(ios, /Text\("分支抽屉"\)/);

  assert.match(android, /buildMobileBranchDrawer/);
  assert.match(android, /screenWidthDp < 600/);
  assert.match(android, /disclosureStates\.get\("mobile-branch-drawer"\)/);

  assert.match(harmony, /mobileBranchDrawerExpanded: boolean = false/);
  assert.match(harmony, /if \(this\.isCompact\(\)\)/);
  assert.match(harmony, /分支抽屉/);

  assert.match(design, /default-collapsed Branch[\s\S]*Drawer/);
  assert.match(design, /Tablet, foldable-expanded, and desktop layouts keep the branch tree visible/);
});
