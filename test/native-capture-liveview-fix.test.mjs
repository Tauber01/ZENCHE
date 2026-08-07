import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const root = new URL('../', import.meta.url);
const read = async (path) => readFile(new URL(path, root), 'utf8');

// v1.5.9 实测修复（Tauber iPad 实测发现，事件 4f43d621）：
// fig1 批次（dc047d5/4926490/2e86da7/65728d6）把拍照页监看画面删除、品牌顶栏
// 改为仅非拍照页显示——拍照页黑屏 + 非拍照页冒出多余 logo。本批恢复：
//   ① 拍照页监看画面恢复（iOS CameraStage / macOS CaptureCompactPreview）
//   ② 非拍照页多余 logo 摘除（iOS AppHeader brand / Android fillStandardTopBar
//      logo+brand / Harmony TopBar Z 标+品牌文案，保留连接状态行）
// Windows 无此问题不动。

// ── iOS ────────────────────────────────────────────────────────────────

test('iOS: CapturePage 恢复 CameraStage 监看画面', async () => {
  const view = await read('native/ios/NikonLink/Views/RootView.swift');
  // 拍照页视图树（CapturePage）内含 CameraStage（对齐 Android/Harmony
  // dock→波形→参数格→预览 顺序：ControlParameterGrid 之后）。
  assert.match(view, /private struct CapturePage: View/);
  const capturePage = view.slice(
    view.indexOf('private struct CapturePage: View'),
    view.indexOf('private struct ImmersiveCameraView')
  );
  assert.match(capturePage, /ControlParameterGrid\(\)/);
  assert.match(capturePage, /CameraStage \{\s*showingFullscreen = true\s*\}/);
  // 全屏通道保留。
  assert.match(capturePage, /fullScreenCover\(isPresented: \$showingFullscreen\)/);
});

test('iOS: AppHeader 摘除 brand 块（保留连接胶囊 + 设置钮）', async () => {
  const view = await read('native/ios/NikonLink/Views/RootView.swift');
  const header = view.slice(
    view.indexOf('private struct AppHeader: View'),
    view.indexOf('private struct SideNavigation: View')
  );
  // 品牌块（Z 标 + 帧澈 ZENCHE 文案）已移除。
  assert.ok(!/private var brand/.test(header), 'AppHeader 不应再有 brand 属性');
  assert.ok(!header.includes('帧澈 ZENCHE'), 'AppHeader 不应含品牌文案');
  assert.ok(!/Text\("Z"\)/.test(header), 'AppHeader 不应含 Z 标');
  // 连接胶囊 + 设置钮保留。
  assert.match(header, /connectionButton/);
  assert.match(header, /settingsButton/);
});

// ── macOS ──────────────────────────────────────────────────────────────

test('macOS: CaptureView 恢复紧凑预览区（CaptureCompactPreview）', async () => {
  const main = await read('native/macos/Sources/NikonLink/main.swift');
  // 拍照页视图树：ControlCaptureDock 之后插入 CaptureCompactPreview。
  const captureView = main.slice(
    main.indexOf('ControlCaptureDock('),
    main.indexOf('private struct ShootingTaskPanel')
  );
  assert.match(captureView, /ControlCaptureDock\(/);
  assert.match(captureView, /CaptureCompactPreview\(model: model\)/);
  // 新组件：帧渲染逻辑与 MonitorView 共享（wifiFrame / model.frame 分支）。
  const preview = main.slice(
    main.indexOf('private struct CaptureCompactPreview: View'),
    main.indexOf('private struct ShootingTaskPanel')
  );
  assert.match(preview, /wifiCamera\.liveViewFrame/);
  assert.match(preview, /Image\(nsImage: frame\)/);
  assert.match(preview, /等待实时取景画面/);
  // 不复活旧 PreviewStage 整体（fig1 删除后无独立 PreviewStage struct）。
  assert.ok(!/private struct PreviewStage/.test(main), '不应复活旧 PreviewStage');
});

// ── Android ────────────────────────────────────────────────────────────

test('Android: fillStandardTopBar 摘除 logo/brand（保留连接/设置）', async () => {
  const main = await read(
    'native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java');
  const bar = main.slice(
    main.indexOf('private void fillStandardTopBar'),
    main.indexOf('private void fillControlTopBar')
  );
  // logo「Z」视图与品牌文案视图已移除。
  assert.ok(!/TextView logo = text\("Z"/.test(bar), 'fillStandardTopBar 不应有 Z logo');
  assert.ok(!bar.includes('帧澈 ZENCHE'), 'fillStandardTopBar 不应含品牌文案');
  assert.ok(!/LinearLayout brand =/.test(bar), 'fillStandardTopBar 不应有 brand 布局');
  // 连接胶囊 + 状态点 + 设置钮保留。
  assert.match(bar, /connectionDot/);
  assert.match(bar, /connectButton = nativeButton/);
  assert.match(bar, /settingsButton/);
  // brandGradient 仍有其他调用点（拍照页 markBox），方法保留。
  assert.match(main, /brandGradient\(24\)/);
});

// ── Harmony ────────────────────────────────────────────────────────────

test('Harmony: TopBar 摘除 Z 标 + 品牌文案（保留连接状态行）', async () => {
  const index = await read('native/harmony/entry/src/main/ets/pages/Index.ets');
  const topBar = index.slice(
    index.indexOf('private TopBar()'),
    index.indexOf('private NavigationRail()')
  );
  assert.ok(!/Text\('Z'\)/.test(topBar), 'TopBar 不应含 Z 标');
  assert.ok(!topBar.includes('帧澈 ZENCHE'), 'TopBar 不应含品牌文案');
  assert.ok(!/Capture · Connect · Flow/.test(topBar), 'TopBar 不应含品牌标语');
  // 连接状态行（相机连接信息，非纯品牌）保留。
  assert.match(topBar, /本机摄像头/);
  assert.match(topBar, /WI‑FI\/PTP‑IP/);
  // 连接/设置钮保留。
  assert.match(topBar, /this\.tr\('连接管理'\)/);
});

// ── 跨端一致性 ─────────────────────────────────────────────────────────

test('v1.5.9: 四端顶栏品牌摘除口径一致，Windows 不受影响', async () => {
  const [ios, android, harmony, windows] = await Promise.all([
    read('native/ios/NikonLink/Views/RootView.swift'),
    read('native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java'),
    read('native/harmony/entry/src/main/ets/pages/Index.ets'),
    read('native/windows/MainWindow.xaml'),
  ]);
  // 三移动端顶栏均无品牌块（iOS brand 属性 / Android fillStandardTopBar / Harmony TopBar）。
  assert.ok(!/private var brand/.test(ios));
  assert.ok(!/TextView logo = text\("Z"/.test(android));
  const topBar = harmony.slice(harmony.indexOf('private TopBar()'),
    harmony.indexOf('private SplashOverlay'));
  assert.ok(!/Text\('Z'\)/.test(topBar), 'Harmony TopBar 不应含 Z 标（Splash 启动标保留）');
  assert.ok(/SplashOverlay/.test(harmony) && /Text\('Z'\)/.test(harmony), 'Splash 启动标保留');
  // Windows 桌面端品牌顶栏保持（恒显，无弹出问题）——断言其仍含品牌文本。
  assert.match(windows, /帧澈 ZENCHE/);
});
