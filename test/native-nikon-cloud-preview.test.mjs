import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../", import.meta.url);
const read = async (path) => readFile(new URL(path, root), "utf8");

test("Nikon cloud preview catalog preserves the supplied NP3 library", async () => {
  const catalog = JSON.parse(
    await read("native/macos/Resources/nikon-cloud-presets.json"),
  );
  assert.equal(catalog.schemaVersion, 1);
  assert.equal(catalog.accuracy, "approximate-sdr-preview");
  assert.equal(catalog.presetCount, 107);
  assert.equal(catalog.presets.length, 107);
  assert.equal(new Set(catalog.presets.map((preset) => preset.id)).size, 107);
  assert.ok(catalog.presets.every((preset) => preset.filename.endsWith(".NP3")));
  assert.ok(catalog.presets.every((preset) => preset.mixer.length === 8));
  assert.equal(
    catalog.presets.filter((preset) => preset.hasCustomToneCurve).length,
    31,
  );
  assert.ok(
    catalog.presets.some((preset) => preset.name === "MSLT-Portra400-V1"),
  );
});

test("all five native editors expose and render Nikon cloud previews", async () => {
  const [ios, swiftModel, android, androidModel, harmony, harmonyModel,
    macos, windowsXaml, windows, windowsModel] = await Promise.all([
    read("native/ios/NikonLink/Views/RootView.swift"),
    read("native/shared/NikonCloudPreview.swift"),
    read("native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java"),
    read("native/android/app/src/main/java/com/tauber/nikonlink/NikonCloudPreview.java"),
    read("native/harmony/entry/src/main/ets/pages/Index.ets"),
    read("native/harmony/entry/src/main/ets/presets/NikonCloudPreview.ets"),
    read("native/macos/Sources/NikonLink/main.swift"),
    read("native/windows/MainWindow.xaml"),
    read("native/windows/MainWindow.xaml.cs"),
    read("native/windows/Models/NikonCloudPreview.cs"),
  ]);

  for (const source of [ios, android, harmony, macos, windowsXaml]) {
    assert.match(source, /尼康云创/);
    assert.match(source, /SDR 近似预览/);
    assert.match(source, /NX Studio/);
  }
  assert.match(swiftModel, /applyingColorMixer/);
  assert.match(androidModel, /applyColorMixer/);
  assert.match(harmony, /applyNikonCloudColorMixer/);
  assert.match(harmonyModel, /NIKON_CLOUD_PRESETS/);
  assert.match(windowsModel, /ApplyColorMixer/);
  assert.match(windows, /NikonCloudPresetBox_SelectionChanged/);
});

test("all five native monitor pipelines apply Nikon cloud effects to photo and video previews", async () => {
  const [iosView, iosModel, iosCamera, iosMonitor, swiftModel,
    android, androidMonitor, harmony, harmonyMonitor, harmonyRenderer,
    macos, macosMonitor, windowsXaml, windows, windowsMonitor] =
    await Promise.all([
      read("native/ios/NikonLink/Views/RootView.swift"),
      read("native/ios/NikonLink/Models/AppModel.swift"),
      read("native/ios/NikonLink/Camera/CameraService.swift"),
      read("native/ios/NikonLink/Camera/ProfessionalMonitor.swift"),
      read("native/shared/NikonCloudPreview.swift"),
      read("native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java"),
      read("native/android/app/src/main/java/com/tauber/nikonlink/ProfessionalMonitor.java"),
      read("native/harmony/entry/src/main/ets/pages/Index.ets"),
      read("native/harmony/entry/src/main/ets/monitor/ProfessionalMonitor.ets"),
      read("native/harmony/entry/src/main/ets/presets/NikonCloudPreviewRenderer.ets"),
      read("native/macos/Sources/NikonLink/main.swift"),
      read("native/macos/Sources/NikonLink/ProfessionalMonitor.swift"),
      read("native/windows/MainWindow.xaml"),
      read("native/windows/MainWindow.xaml.cs"),
      read("native/windows/Services/ProfessionalMonitor.cs"),
    ]);

  assert.match(iosView, /NikonCloudMonitorBar/);
  assert.match(iosView, /照片与视频实时生效 · SDR 近似 · 不写入原片/);
  assert.match(iosModel, /monitorNikonCloudPresetID/);
  assert.match(iosCamera, /setMonitorNikonCloudPreset/);
  assert.match(iosMonitor, /applyingPreviewEffect/);
  assert.match(swiftModel, /applyingPreviewEffect/);

  assert.match(android, /buildNikonCloudMonitorPanel/);
  assert.match(android, /monitorNikonCloudPreset/);
  assert.match(androidMonitor, /applyPreviewEffect/);

  assert.match(harmony, /NikonCloudMonitorPicker/);
  assert.match(harmony, /monitorNikonCloudPresetId/);
  assert.match(harmonyMonitor, /applyNikonCloudPreviewEffect/);
  assert.match(harmonyRenderer, /applyNikonCloudPreviewEffect/);

  assert.match(macos, /NikonCloudMacMonitorPicker/);
  assert.match(macos, /monitorNikonCloudPresetID/);
  assert.match(macosMonitor, /applyingPreviewEffect/);

  assert.match(windowsXaml, /CaptureNikonCloudPresetBox/);
  assert.match(windowsXaml, /MonitorNikonCloudPresetBox/);
  assert.match(windows, /_monitorNikonCloudPreset/);
  assert.match(windowsMonitor, /ApplyPreviewEffect/);

  for (const source of [iosView, android, harmony, macos, windowsXaml]) {
    assert.match(source, /不写入原片/);
  }
});

test("Nikon cloud monitor controls use semantic color, responsive hierarchy, and stable native pickers", async () => {
  const [ios, android, harmony, macos, windowsXaml, windows] =
    await Promise.all([
      read("native/ios/NikonLink/Views/RootView.swift"),
      read("native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java"),
      read("native/harmony/entry/src/main/ets/pages/Index.ets"),
      read("native/macos/Sources/NikonLink/main.swift"),
      read("native/windows/MainWindow.xaml"),
      read("native/windows/MainWindow.xaml.cs"),
    ]);

  assert.match(ios, /NikonCloudMonitorPresetSheet/);
  assert.match(ios, /\.sheet\(isPresented: \$showingPresetPicker\)/);
  assert.match(ios, /\.searchable\(text: \$searchText/);
  assert.match(ios, /IPalette\.cobaltSoft/);

  assert.match(android, /nikonCloudPresetDialog\.isShowing\(\)/);
  assert.match(android, /setSingleChoiceItems/);
  assert.match(android, /setOnDismissListener/);
  assert.match(android, /COBALT_SOFT/);

  assert.match(harmony, /this\.tr\('选择预设'\)/);
  assert.match(harmony, /app\.color\.accent_soft/);
  assert.match(harmony, /radius: 14/);

  assert.match(macos, /NikonCloudMacMonitorPresetSheet/);
  assert.match(macos, /\.sheet\(isPresented: \$showingPresetPicker\)/);
  assert.match(macos, /\.searchable\(text: \$searchText/);
  assert.match(macos, /Palette\.cobaltSoft/);

  assert.match(windowsXaml, /MaxDropDownHeight="360"/);
  assert.match(windowsXaml, /IsTextSearchEnabled="True"/);
  assert.match(windowsXaml, /AccentSoftBrush/);
  assert.match(windows, /IsDropDownOpen = false/);
});

test("native packages include the shared Nikon cloud catalog", async () => {
  const [iosProject, androidGradle, macBuild, windowsProject] =
    await Promise.all([
      read("native/ios/NikonLink.xcodeproj/project.pbxproj"),
      read("native/android/app/build.gradle"),
      read("scripts/build-macos.sh"),
      read("native/windows/NikonLink.Windows.csproj"),
    ]);
  assert.match(iosProject, /nikon-cloud-presets\.json in Resources/);
  assert.match(androidGradle, /macos\/Resources/);
  assert.match(macBuild, /nikon-cloud-presets\.json/);
  assert.match(windowsProject, /nikon-cloud-presets\.json/);
});
