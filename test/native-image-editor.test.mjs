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
