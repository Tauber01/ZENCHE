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
  // v1.5.7 F6（Tauber 拍板）：Android 底栏提回编辑为一级 tab；五端统一短词。
  assert.match(android, /navButton\("拍照", "capture"\)/);
  assert.match(android, /navButton\("编辑", "editor"\)/);
  assert.match(android, /navButton\("分支", "library"\)/);
  assert.match(android, /case "editor":[\s\S]*buildImageEditorView/);
  assert.match(harmony, /NavButton\('编辑', 'editor'\)/);
  assert.match(harmony, /this\.ImageEditorWorkspace\(\)/);
  assert.match(macos, /case editor = "编辑"/);
  assert.match(macos, /case \.editor:[\s\S]*ImageEditorView/);
  assert.match(windowsXaml, /x:Name="EditorNav"/);
  assert.match(windowsXaml, /x:Name="EditorPanel"/);
  assert.match(windows, /destination == "editor"/);
});

test("macOS editor isolates the workspace and bounds its preview", async () => {
  const macos = await read("native/macos/Sources/NikonLink/main.swift");

  assert.match(macos, /private var currentWorkspace: some View/);
  assert.match(macos, /currentWorkspace\s*\.id\(model\.section\)/);
  assert.match(
    macos,
    /GeometryReader \{ geometry in[\s\S]*?ResolveEditorWorkbench[\s\S]*?preview[\s\S]*?frame\(\s*width: geometry\.size\.width,\s*height: geometry\.size\.height/,
  );
  assert.match(macos, /\.clipped\(\)\s*\.contentShape\(Rectangle\(\)\)/);
  assert.match(
    macos,
    /Keep the Menu label text-only[\s\S]*?Image\(systemName: "photo\.on\.rectangle"\)/,
  );
  assert.doesNotMatch(macos, /Group \{\s*switch model\.section/);
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

test("native AI generation stays reachable and mask brushes support lifecycle operations", async () => {
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
    assert.match(source, /生成图像/);
    assert.match(source, /创建蒙版/);
    assert.match(source, /删除蒙版/);
    assert.match(source, /添加蒙版（画笔）/);
    assert.match(source, /减去蒙版（画笔）/);
    assert.match(source, /画笔大小/);
  }

  assert.match(ios, /EditorMaskStroke/);
  assert.match(ios, /CIBlendWithMask/);
  assert.match(android, /EditorMaskImageView/);
  assert.match(android, /buildEditorMask/);
  assert.match(harmony, /handleEditorMaskTouch/);
  assert.match(harmony, /buildEditorMask/);
  assert.match(macos, /activeMaskStrokeID/);
  assert.match(macos, /CIBlendWithMask/);
  assert.match(
    macos,
    /private var aiToolsPanel[\s\S]*ScrollView \{[\s\S]*Divider\(\)[\s\S]*生成图像/,
  );
  assert.match(windowsXaml, /EditorMaskCanvas/);
  assert.match(
    windowsXaml,
    /EditorAiGrid[\s\S]*ScrollViewer[\s\S]*AiGenerateBtn[\s\S]*Content="生成图像"/,
  );
  assert.match(windows, /BuildEditorMask/);
});

test("native mask systems align brush coordinates, subtract coverage, invert, and local adjustments", async () => {
  const [ios, android, harmony, macos, windows] = await Promise.all([
    read("native/ios/NikonLink/Views/RootView.swift"),
    read("native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java"),
    read("native/harmony/entry/src/main/ets/pages/Index.ets"),
    read("native/macos/Sources/NikonLink/main.swift"),
    read("native/windows/MainWindow.xaml.cs"),
  ]);

  const nativeEditors = [ios, android, harmony, macos, windows];
  const smartTypes = [
    "智能主体",
    "智能天空",
    "智能背景",
    "智能人物",
    "智能亮部",
    "智能暗部",
  ];
  const localAdjustments = [
    "MaskExposure",
    "MaskContrast",
    "MaskHighlights",
    "MaskShadows",
    "MaskTemperature",
    "MaskTint",
    "MaskSaturation",
    "MaskClarity",
  ];

  for (const source of nativeEditors) {
    for (const type of smartTypes) assert.match(source, new RegExp(type));
    assert.match(source, /蒙版内调整/);
    assert.match(source, /反向蒙版|反相蒙版/);
    for (const adjustment of localAdjustments) {
      assert.match(source, new RegExp(adjustment, "i"));
    }
  }

  // Apple gestures and output masks share the fitted, transformed preview rect.
  for (const source of [ios, macos]) {
    assert.match(source, /coordinateSpace: \.named\("editorPreview"\)/);
    assert.match(source, /recordMaskPoint\([\s\S]*imageRect: imageRect/);
    assert.match(source, /CIMaximumCompositing/);
    assert.match(source, /CIMultiplyCompositing/);
    assert.match(source, /inputRVector.*-1[\s\S]*inputBiasVector.*1/);
  }

  // Android, HarmonyOS, and Windows normalize through the visible image rect,
  // not the padded preview container, so brush strokes land at the cursor.
  assert.match(android, /displayedImageRect\(\)/);
  assert.match(android, /\(event\.getX\(\) - rect\.left\).*rect\.width\(\)/s);
  assert.match(harmony, /private editorImageRect\(\): EditorPreviewRect/);
  assert.match(harmony, /\(touch\.x - rect\.left\).*rect\.width/s);
  assert.match(windows, /GetUniformImageRect\(EditorMaskCanvas, bitmap\)/);
  assert.match(windows, /\(point\.X - rect\.Left\).*rect\.Width/s);

  // Subtract must remove existing coverage; min(current, 255 - value) made
  // light strokes ineffective whenever current coverage was already lower.
  assert.match(android, /stroke\.subtract\s*\? Math\.max\(0, current - value\)/);
  assert.match(harmony, /stroke\.subtract\s*\? Math\.max\(0, mask\[offset\] - value\)/);
  assert.match(windows, /stroke\.Subtract\s*\? \(byte\)Math\.Max\(0, mask\[offset\] - value\)/);

  // Inversion happens before intensity is applied, preserving the selected
  // region/complement relationship at every mask strength.
  assert.match(android, /layer\.amount \/ 100\.0/);
  assert.match(android, /\(layer\.invert \? 1 - coverage : coverage\)\s*\* intensity/);
  assert.match(harmony, /\(\s*layer\.invert \? 1 - coverage : coverage\s*\) \* intensity/);
  assert.match(windows, /\(layer\.Invert \? 1 - coverage : coverage\)\s*\* intensity/);
});

test("native mask systems provide switching lists and independent visibility", async () => {
  const [ios, android, harmony, macos, windows] = await Promise.all([
    read("native/ios/NikonLink/Views/RootView.swift"),
    read("native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java"),
    read("native/harmony/entry/src/main/ets/pages/Index.ets"),
    read("native/macos/Sources/NikonLink/main.swift"),
    read("native/windows/MainWindow.xaml.cs"),
  ]);

  for (const source of [ios, android, harmony, macos, windows]) {
    assert.match(source, /蒙版列表/);
    assert.match(source, /暂无蒙版/);
    assert.match(source, /MaskLayer/);
    assert.match(source, /[Vv]isible/);
    assert.match(source, /[Ss]elect(?:Editor)?MaskLayer/);
    assert.match(source, /[Ee]ffective(?:Editor)?MaskLayers/);
  }

  assert.match(ios, /Toggle\("", isOn: Binding/);
  assert.match(macos, /Toggle\("", isOn: Binding/);
  assert.match(android, /Switch visibility = new Switch/);
  assert.match(harmony, /type: ToggleType\.Switch,[\s\S]*isOn: layer\.visible/);
  assert.match(windows, /IsChecked = layer\.IsVisible/);
});

test("AI retouch previews its selected original and masks render real blue alpha overlays", async () => {
  const [ios, android, harmony, macos, windowsXaml, windows] =
    await Promise.all([
      read("native/ios/NikonLink/Views/RootView.swift"),
      read("native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java"),
      read("native/harmony/entry/src/main/ets/pages/Index.ets"),
      read("native/macos/Sources/NikonLink/main.swift"),
      read("native/windows/MainWindow.xaml"),
      read("native/windows/MainWindow.xaml.cs"),
    ]);

  for (const source of [ios, android, harmony, macos, windows]) {
    assert.match(source, /蓝色显示当前蒙版覆盖；橡皮会擦除蓝色区域。/);
    assert.match(source, /deleteActive(?:Editor)?MaskLayer|DeleteActiveMaskLayer/);
  }

  assert.match(
    ios,
    /aiResultImage \?\? \(aiMode == \.edit \? selectedOriginalImage : nil\)/,
  );
  assert.match(ios, /activeMaskOverlayImage[\s\S]*CIBlendWithMask/);
  assert.match(
    ios,
    /onChange\(of: selectedItemID\)[\s\S]*aiResultImage = nil/,
  );
  assert.match(
    macos,
    /aiResultImage \?\? \(aiMode == \.edit \? selectedOriginalImage : nil\)/,
  );
  assert.match(macos, /activeMaskOverlayImage[\s\S]*CIBlendWithMask/);
  assert.match(
    macos,
    /onChange\(of: selectedPhotoURL\)[\s\S]*aiResultImage = nil/,
  );

  assert.match(android, /已选择原图/);
  assert.match(
    android,
    /editorSelectedPath = file\.getAbsolutePath\(\);\s*aiResultBitmap = null;/s,
  );
  assert.match(
    android,
    /protected void onDraw\(Canvas canvas\)[\s\S]*buildEditorMask\([\s\S]*150 \* effective/,
  );
  assert.match(harmony, /Image\(`file:\/\/\$\{this\.editorSelectedPath\}`\)/);
  assert.match(
    harmony,
    /this\.editorSelectedPath = item\.path;\s*this\.aiResultPath = '';/s,
  );
  assert.match(harmony, /createEditorMaskOverlay[\s\S]*AlphaType\.UNPREMUL/);

  // v1.5.6: AiPhotoPickerPopup/AiPhotoTree 镜像弹窗按审计删冗余计划删除，
  // AI 区「选择照片」与编辑区共用 EditorPhotoPickerPopup/EditorPhotoTree。
  assert.match(windowsXaml, /EditorPhotoPickerPopup/);
  assert.match(windowsXaml, /EditorPhotoTree/);
  assert.match(
    windowsXaml,
    /x:Name="AiPhotoPickerButton"[\s\S]*?Click="EditorPhotoPickerButton_Click"/,
  );
  assert.match(
    windows,
    /var previewPath = _aiResultPath \?\?[\s\S]*_editorSelectedPath/,
  );
  assert.match(
    windows,
    /_editorSelectedPath = item\.Path;\s*ClearAiResultFile\(\);/s,
  );
  assert.match(windows, /RedrawEditorMaskOverlay[\s\S]*PixelFormats\.Pbgra32/);
});

test("Windows AI uses server quota and overwrites the selected source for retouch", async () => {
  const windows = await read("native/windows/MainWindow.xaml.cs");

  assert.match(windows, /X-ZENCHE-Remaining/);
  assert.match(windows, /ReadServerRemainingUsage\(response\)/);
  assert.match(windows, /if \(serverRemaining is null\)[\s\S]*RecordAiUsage\(\)/);
  assert.match(windows, /_aiServerRemainingUsage = remaining/);
  assert.match(
    windows,
    /if \(_aiMode == 0[\s\S]*SaveBitmapAtomically\(originalPath, frame\)/,
  );
  assert.match(windows, /File\.Replace\(temporary, destination, null\)/);
  assert.match(windows, /ai_generated_/);
});

test("all native AI clients consume server quota and replace retouched originals", async () => {
  const [ios, android, harmony, macos, windows] = await Promise.all([
    read("native/ios/NikonLink/Views/RootView.swift"),
    read("native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java"),
    read("native/harmony/entry/src/main/ets/pages/Index.ets"),
    read("native/macos/Sources/NikonLink/main.swift"),
    read("native/windows/MainWindow.xaml.cs"),
  ]);

  assert.match(ios, /X-ZENCHE-Remaining/);
  assert.match(ios, /ActivationManager\.updateServerRemaining/);
  assert.match(ios, /ActivationManager\.recordUsageFallback/);
  assert.match(ios, /replaceEditedImage/);

  assert.match(android, /parseAiRemaining\(conn\.getHeaderField\("X-ZENCHE-Remaining"\)\)/);
  assert.match(android, /setAiRemainingUsage\(result\.remaining\)/);
  assert.match(android, /recordAiUsage\(\)/);
  assert.match(android, /StandardCopyOption\.ATOMIC_MOVE/);

  assert.match(harmony, /parseAiRemaining\(/);
  assert.match(harmony, /setAiRemainingUsage\(/);
  assert.match(harmony, /recordAiUsage\(\)/);
  assert.match(harmony, /library\.replaceFile\(/);

  assert.match(macos, /X-ZENCHE-Remaining/);
  assert.match(macos, /ActivationManager\.updateServerRemaining/);
  assert.match(macos, /ActivationManager\.recordUsageFallback/);
  assert.match(macos, /replaceEditedPhoto/);

  assert.match(windows, /X-ZENCHE-Remaining/);
  assert.match(windows, /ReadServerRemainingUsage\(response\)/);
  assert.match(windows, /if \(serverRemaining is null\)[\s\S]*RecordAiUsage\(\)/);
  assert.match(windows, /SaveBitmapAtomically\(originalPath, frame\)/);
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
  assert.match(android, /AI_SERVER_DEFAULT = "https:\/\/zenche\.top\/api"/);
  assert.match(android, /AI_SERVER_LEGACY = "http:\/\/101\.34\.255\.115:8787"/);

  assert.doesNotMatch(harmony, /aiServerInput|服务器地址（默认 http:\/\/101\.34\.255\.115:8787）/);
  assert.match(harmony, /AI_SERVER_DEFAULT: string = 'https:\/\/zenche\.top\/api'/);
  assert.match(harmony, /AI_SERVER_LEGACY: string = 'http:\/\/101\.34\.255\.115:8787'/);

  assert.doesNotMatch(macosSettings, /serverURL|AI 服务器|服务器地址（如/);
  assert.match(macosMain, /UserDefaults\.standard\.string\(forKey: "aiServerURL"\)/);

  assert.doesNotMatch(windowsXaml, /AiServerUrlBox/);
  assert.doesNotMatch(windows, /SaveAiServerUrl|AiServerUrlBox|保存服务器地址/);
  assert.match(windows, /Path\.Combine\(AiDataDir, "ai-server-url\.txt"\)/);
});

test("Apple packages allow the legacy HTTP AI proxy through ATS", async () => {
  const [iosInfo, macosInfo] = await Promise.all([
    read("native/ios/NikonLink/Info.plist"),
    read("native/macos/Info.plist"),
  ]);

  for (const info of [iosInfo, macosInfo]) {
    assert.match(
      info,
      /<key>NSAppTransportSecurity<\/key>\s*<dict>\s*<key>NSAllowsArbitraryLoads<\/key>\s*<true\/>\s*<\/dict>/,
    );
  }
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
