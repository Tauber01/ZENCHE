import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const root = new URL('../', import.meta.url);
const read = async (path) => readFile(new URL(path, root), 'utf8');

const nativeSources = async () => {
  const [ios, android, harmony, macos, windowsXaml, windows] =
    await Promise.all([
      read('native/ios/NikonLink/Views/RootView.swift'),
      read('native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java'),
      read('native/harmony/entry/src/main/ets/pages/Index.ets'),
      read('native/macos/Sources/NikonLink/main.swift'),
      read('native/windows/MainWindow.xaml'),
      read('native/windows/MainWindow.xaml.cs'),
    ]);
  return { ios, android, harmony, macos, windows: `${windowsXaml}\n${windows}` };
};

test('1.5.3 immersive monitor uses a telemetry HUD, tool rail, scopes, and parameter tray on all native targets', async () => {
  const sources = await nativeSources();
  const contracts = [
    [sources.ios, /immersiveTelemetryHUD/, /immersiveScopeDock/, /immersiveToolRail/, /parameterBar/],
    [sources.android, /immersiveTelemetryHud/, /immersiveScopeDock/, /immersiveToolRail/, /immersiveParameterScroller/],
    [sources.harmony, /ImmersiveTelemetryHud/, /ImmersiveScopeDock/, /ImmersiveToolRail/, /ImmersiveParameterTray/],
    [sources.macos, /immersiveTelemetryHUD/, /immersiveScopeDock/, /immersiveToolRail/, /immersiveParameterBar/],
    [sources.windows, /ImmersiveTelemetryHud/, /ImmersiveScopeDock/, /ImmersiveToolRail/, /ImmersiveParameterTray/],
  ];
  for (const [source, ...patterns] of contracts) {
    for (const pattern of patterns) assert.match(source, pattern);
  }
});

test('1.5.3 capture controls use device summaries, adaptive parameter cards, and a persistent capture dock', async () => {
  const sources = await nativeSources();
  const contracts = [
    [sources.ios, /CaptureDeviceSummary/, /CaptureParameterCardGrid/, /CaptureDock/],
    [sources.android, /buildControlStatusRow/, /buildStatusCardGrid/, /buildControlParameterGrid/, /buildControlCaptureDock/],
    [sources.harmony, /CaptureDeviceSummary/, /CaptureParameterCardGrid/, /CaptureDock/],
    [sources.macos, /CaptureDeviceSummary/, /ParameterCardGrid/, /CaptureDock/],
    [sources.windows, /CaptureDeviceSummary/, /ParameterCardDeck/, /CaptureDock/],
  ];
  for (const [source, ...patterns] of contracts) {
    for (const pattern of patterns) assert.match(source, pattern);
  }
});

test('1.5.3 editors expose a Resolve-inspired native workbench without dropping editing or AI tools', async () => {
  const sources = await nativeSources();
  const contracts = [
    [sources.ios, /ResolveEditorWorkbench/, /EditorMediaRail/, /EditorToolRail/, /EditorScopeDock/],
    [sources.android, /buildResolveEditorWorkbench/, /buildEditorMediaRail/, /buildEditorToolRail/, /buildEditorScopeDock/],
    [sources.harmony, /ResolveEditorWorkbench/, /EditorMediaRail/, /EditorToolRail/, /EditorScopeDock/],
    [sources.macos, /ResolveEditorWorkbench/, /EditorMediaRail/, /EditorToolRail/, /EditorScopeDock/],
    [sources.windows, /EditorResolveWorkbench/, /EditorMediaRail/, /EditorToolRail/, /EditorScopeDock/],
  ];
  for (const [source, ...patterns] of contracts) {
    for (const pattern of patterns) assert.match(source, pattern);
    for (const preserved of [
      /专业显影/,
      /AI 工具/,
      /色轮|ColorWheel|EditorWheel/,
      /曲线|Curve/,
      /蒙版|Mask/,
      /保存高质量副本|保存编辑副本/,
    ]) assert.match(source, preserved);
  }
});

test('1.5.3 visual tokens preserve ZENCHE blue and reserve warm gold and red for parameter focus and recording', async () => {
  const [ios, android, harmony, macos, colors] = await Promise.all([
    read('native/ios/NikonLink/Views/RootView.swift'),
    read('native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java'),
    read('native/harmony/entry/src/main/ets/pages/Index.ets'),
    read('native/macos/Sources/NikonLink/main.swift'),
    read('native/windows/Themes/Colors.xaml'),
  ]);
  for (const source of [ios, android, harmony, macos, colors]) {
    assert.match(source, /studioGold|STUDIO_GOLD|StudioGold/);
    assert.match(source, /studioPanel|STUDIO_PANEL|StudioPanel/);
    assert.match(source, /cobalt|COBALT|AccentBrush|app\.color\.accent/);
    assert.match(source, /video|VIDEO|Video|RecordBrush/);
  }
});

test('1.5.3 telemetry degrades to —/OFFLINE without a live source on Android and HarmonyOS', async () => {
  const [android, harmony] = await Promise.all([
    read('native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java'),
    read('native/harmony/entry/src/main/ets/pages/Index.ets'),
  ]);
  // Android immersive HUD cells must be gated by live telemetry, never default values.
  assert.match(android, /liveTelemetry \? shutterDisplayValue\(\) : "—"/);
  assert.match(android, /liveTelemetry\s*\n\s*\? String\.format\(Locale\.CHINA, "F%\.1f", currentAperture\)\s*\n\s*: "—"/);
  assert.match(android, /liveTelemetry \? String\.valueOf\(currentIso\) : "—"/);
  // Android fig1 capture transport capsule must be gated (set only when a camera is live).
  assert.match(android, /controlStatusRate\.setText\(connected\s*\n\s*\? "USB\/PTP"/);
  // Android fullscreen bottom exposure readout and parameter steppers must be gated.
  assert.match(android, /boolean live = connected \|\| localCameraConnected;/);
  assert.match(android, /if \(!\(connected \|\| localCameraConnected\)\) \{\s*\n\s*return "—";/);
  assert.match(android, /\(connected \|\| localCameraConnected\)\s*\n\s*\? \(immersiveMonitoring\s*\n\s*\? monitorFrameRate \+ "P"/);
  // HarmonyOS immersive HUD FORMAT and exposure cells must be gated.
  assert.match(harmony, /'FORMAT',\s*\n\s*\(this\.connected \|\| this\.localCameraSelected\)\s*\n\s*\?/);
  assert.match(harmony, /'SHUTTER',\s*\n\s*\(this\.connected \|\| this\.localCameraSelected\) \? this\.shutterDisplay\(\) : '—'/);
  assert.match(harmony, /'ISO',\s*\n\s*\(this\.connected \|\| this\.localCameraSelected\) \? `\$\{this\.currentIso\}` : '—'/);
  // HarmonyOS capture device summary OUTPUT and bottom readout must be gated.
  assert.match(harmony, /'OUTPUT',\s*\n\s*\(this\.connected \|\| this\.localCameraSelected\)\s*\n\s*\?/);
  assert.match(harmony, /\(this\.connected \|\| this\.localCameraSelected\)\s*\n\s*\? \(this\.immersiveMonitoring\s*\n\s*\? `\$\{this\.videoShutterAngle\.toFixed\(1\)\}°   `/);
  // HarmonyOS parameter tray values must degrade too.
  assert.match(harmony, /'快门角度' : '快门',\s*\n\s*\(this\.connected \|\| this\.localCameraSelected\)\s*\n\s*\?/);
});

test('1.5.3 editor tool rail shortcuts reach real controls instead of fake toasts on Android', async () => {
  const android = await read('native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java');
  // No fake "expanded" toast: the rail must expand and scroll to the target group.
  assert.doesNotMatch(android, /showToast\("已展开"/);
  assert.match(android, /pendingEditorScrollKey = key;/);
  assert.match(android, /private void scrollEditorGroupIntoView\(String key\)/);
  assert.match(android, /group\.setTag\(key\)/);
  assert.match(android, /contentHost\.findViewWithTag\(key\)/);
  // AI shortcut must still switch into the real AI editor state.
  assert.match(android, /editorState = EditorState\.AI;/);
});

test('1.5.3 new user-visible strings have trilingual keys on Android and HarmonyOS', async () => {
  const [androidLocalization, harmonyLocalization] = await Promise.all([
    read('native/android/app/src/main/java/com/tauber/nikonlink/Localization.java'),
    read('native/harmony/entry/src/main/ets/localization/Localization.ets'),
  ]);
  for (const source of [androidLocalization, harmonyLocalization]) {
    assert.match(source, /个文件/);
    assert.match(source, /未选择照片/);
    assert.match(source, /工具轨/);
    assert.match(source, /编辑示波器/);
  }
});

test('1.5.3 capture session entry, five-platform offline telemetry degradation, and Windows editor breakpoints stay wired', async () => {
  const [ios, android, harmony, macos, windowsXaml, windows] = await Promise.all([
    read('native/ios/NikonLink/Views/RootView.swift'),
    read('native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java'),
    read('native/harmony/entry/src/main/ets/pages/Index.ets'),
    read('native/macos/Sources/NikonLink/main.swift'),
    read('native/windows/MainWindow.xaml'),
    read('native/windows/MainWindow.xaml.cs'),
  ]);

  // 1) iOS CapturePage must actually render the capture session card, not just define it.
  const iosCapturePage = ios.slice(
    ios.indexOf('private struct CapturePage'),
    ios.indexOf('private struct CaptureDeviceSummary')
  );
  assert.match(iosCapturePage, /CaptureSessionCard\(\)/);

  // 2) No default/stale telemetry without a live source: HUD cells, bottom exposure
  //    readouts, and capture OUTPUT must degrade to "—"/OFFLINE on all five platforms.
  // iOS immersive HUD + exposure readout + device summary OUTPUT.
  assert.match(ios, /connected \? String\(format: "%.1f°", model\.camera\.shutterAngle\) : "—"/);
  assert.match(ios, /connected && model\.camera\.lensAperture > 0\s*\n\s*\? String\(format: "F%\.1f", model\.camera\.lensAperture\)\s*\n\s*: "—"/);
  assert.match(ios, /connected \? "\\\(Int\(model\.camera\.exposureISO\.rounded\(\)\)\)" : "—"/);
  assert.match(ios, /model\.camera\.state == \.ready\s*\n\s*\? model\.camera\.activeVideoSpecLabel\s*\n\s*: "—"/);
  assert.doesNotMatch(ios, /String\.localizedStringWithFormat/);
  assert.match(ios, /RuntimeLocalization\.format\(\s*"%lld 个文件",\s*locale: locale,/);
  // macOS immersive HUD SHUTTER + capture OUTPUT.
  assert.match(macos, /telemetryCell\("SHUTTER", model\.connected \? shutterLabel : "—"\)/);
  assert.match(macos, /model\.hasAnyCameraConnection \? "\\\(Int\(model\.videoFrameRate\)\)P · JPEG" : "—"/);
  // Windows immersive HUD SOURCE/SHUTTER + capture OUTPUT readout.
  assert.match(windows, /AddCell\("SOURCE", connected \? "USB\/PTP" : "OFFLINE"\)/);
  assert.match(windows, /AddCell\("SHUTTER", connected \? SelectedContent\(ShutterBox, "—"\) : "—"\)/);
  assert.match(windows, /CaptureOutputText\.Text = _camera\.IsConnected \|\|[\s\S]*?: "—";/);
  assert.match(windows, /Text = ImmersiveParameterLabel\(source\)/);
  assert.match(windows, /private string ImmersiveParameterLabel\(ComboBox source\)[\s\S]*?_camera\.IsConnected[\s\S]*?: "—";/);
  // Android + HarmonyOS (kept in lockstep with the platform fixes).
  assert.match(android, /liveTelemetry \? shutterDisplayValue\(\) : "—"/);
  assert.match(harmony, /'SHUTTER',\s*\n\s*\(this\.connected \|\| this\.localCameraSelected\) \? this\.shutterDisplay\(\) : '—'/);

  // 3) Windows editor workbench narrow-window breakpoint and responsive layout columns.
  assert.match(windowsXaml, /x:Name="EditorMediaColumn"/);
  assert.match(windowsXaml, /x:Name="EditorToolsColumn"/);
  assert.match(windows, /private void ApplyResponsiveEditorLayout\(\)/);
});
