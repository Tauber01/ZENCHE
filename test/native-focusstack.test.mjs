import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const root = new URL('../', import.meta.url);
const read = async (path) => readFile(new URL(path, root), 'utf8');

// E7 1.5.9 契约锚点：焦点包围合成五端同构——
// 序列帧（不同对焦距离）→ 逐帧解码 → 统一画布（aspect-fit 黑底）→
// 全局亮度归一（clamp(mean0/mean_i, 0.5, 2.0)）→ 3×3 拉普拉斯清晰度测度 →
// 逐像素取最清晰帧融合 → JPEG 输出（非破坏性副本纪律）。
// 产出走 CaptureWorkflow 同会话目录 + reserveBaseName + finalize 全套
// （XMP sidecar/双备份/SHA-256 清单），XMP 写 focus-stack 合成标记 + 源帧数。
// 进度回调 + 可取消 + 单帧损坏跳过计数（不整批失败）。
// 亚像素位移对齐工程量过大，列入 backlog（仅全局亮度归一）。
// 无实机，全部标 TBC-awaiting-hardware（纪律：不得写成已实机验证）。

// ── macOS ──────────────────────────────────────────────────────────────

test('macOS: FocusStackComposer 拉普拉斯融合 + 亮度归一 + skip/cancel/progress', async () => {
  const composer = await read(
    'native/macos/Sources/NikonLink/FocusStackComposer.swift');
  assert.match(composer, /struct FocusStackComposer/);
  assert.match(composer, /func compose\(/);
  assert.match(composer, /frames: \[URL\]/);
  // 亮度归一：clamp(mean0/mean_i, 0.5, 2.0)。
  assert.match(composer, /min\(2\.0, max\(0\.5, mean == 0 \? 1\.0 : \(referenceMean \/ mean\)\)\)/);
  // 3×3 拉普拉斯核（全 8 邻域中心 8）作用于归一亮度。
  assert.match(composer, /8 \* luminance\[p\]/);
  assert.match(composer, /- luminance\[p - width\] - luminance\[p \+ width\]/);
  assert.match(composer, /- luminance\[p - 1\] - luminance\[p \+ 1\]/);
  // 逐像素取清晰度最高帧 + 边界 1px 保留首帧。
  assert.match(composer, /if lap > bestLap\[p\]/);
  assert.match(composer, /bestRGB\[p \* 3\] = clampByte\(Float\(rgba\[offset\]\) \* scale\)/);
  // Result：sourcesUsed + skippedFrames。
  assert.match(composer, /struct Result/);
  assert.match(composer, /let sourcesUsed: Int/);
  assert.match(composer, /let skippedFrames: Int/);
  // 跳过/取消/进度。
  assert.match(composer, /skipped \+= 1/);
  assert.match(composer, /if isCancelled\(\)/);
  assert.match(composer, /onProgress\(index \+ 1, frames\.count\)/);
  assert.match(composer, /sourcesUsed >= 2/);
  assert.match(composer, /TBC-awaiting-hardware/);
});

test('macOS: 产出复用 CaptureWorkflow + focus-stack XMP 标记', async () => {
  const workflow = await read(
    'native/macos/Sources/NikonLink/CaptureWorkflow.swift');
  assert.match(workflow, /func storeFocusStack\(/);
  assert.match(workflow, /stackSourceCount: Int/);
  assert.match(workflow, /extension: "jpg"/);
  assert.match(workflow, /stackSourceCount: stackSourceCount/);
  // XMP：focus-stack 标记 + 源帧数。
  assert.match(workflow, /xmp:Label=\\"focus-stack\\"/);
  assert.match(workflow, /xmp:FocusStackSources=/);
});

// ── iOS ────────────────────────────────────────────────────────────────

test('iOS: FocusStackComposer 移植镜像 macOS 契约', async () => {
  const composer = await read(
    'native/ios/NikonLink/Models/FocusStackComposer.swift');
  assert.match(composer, /struct FocusStackComposer/);
  assert.match(composer, /min\(2\.0, max\(0\.5, mean == 0 \? 1\.0 : \(referenceMean \/ mean\)\)\)/);
  assert.match(composer, /8 \* luminance\[p\]/);
  assert.match(composer, /if lap > bestLap\[p\]/);
  assert.match(composer, /let sourcesUsed: Int/);
  assert.match(composer, /skipped \+= 1/);
  assert.match(composer, /if isCancelled\(\)/);
  assert.match(composer, /sourcesUsed >= 2/);
  assert.match(composer, /TBC-awaiting-hardware/);
  const workflow = await read(
    'native/ios/NikonLink/Models/CaptureWorkflow.swift');
  assert.match(workflow, /func storeFocusStack\(/);
  assert.match(workflow, /xmp:FocusStackSources=\\"/);
  // 工程注册。
  const pbx = await read('native/ios/NikonLink.xcodeproj/project.pbxproj');
  assert.match(pbx, /FocusStackComposer\.swift in Sources/);
});

// ── Windows ────────────────────────────────────────────────────────────

test('Windows: FocusStackComposer ComposeAsync + WinRT 图像栈 + 会话入库', async () => {
  const composer = await read(
    'native/windows/Services/FocusStackComposer.cs');
  assert.match(composer, /public sealed class FocusStackComposer/);
  assert.match(composer, /record Result\(/);
  assert.match(composer, /int SourcesUsed/);
  assert.match(composer, /int SkippedFrames/);
  assert.match(composer, /ComposeAsync\(/);
  assert.match(composer, /BitmapDecoder\.CreateAsync/);
  assert.match(composer, /BitmapEncoder\.JpegEncoderId/);
  assert.match(composer, /Math\.Clamp\(/);
  assert.match(composer, /8 \* luminance\[p\]/);
  assert.match(composer, /if \(lap > bestLap\[p\]\)/);
  assert.match(composer, /sourcesUsed < 2/);
  assert.match(composer, /TBC-awaiting-hardware/);
  const workflow = await read(
    'native/windows/Services/CaptureWorkflow.cs');
  assert.match(workflow, /StoreFocusStackAsync\(/);
  assert.match(workflow, /xmp:Label=\\"focus-stack\\"/);
  assert.match(workflow, /xmp:FocusStackSources=\\"/);
  const main = await read('native/windows/MainWindow.xaml.cs');
  assert.match(main, /ComposeFocusStack_Click/);
  assert.match(main, /new FocusStackComposer\(\)/);
  assert.match(main, /_workflow\.StoreFocusStackAsync\(/);
  const xaml = await read('native/windows/MainWindow.xaml');
  assert.match(xaml, /Content="焦点合成"/);
});

// ── Android ────────────────────────────────────────────────────────────

test('Android: FocusStackComposer compose + 同构算法 + 入口', async () => {
  const composer = await read(
    'native/android/app/src/main/java/com/tauber/nikonlink/FocusStackComposer.java');
  assert.match(composer, /final class FocusStackComposer/);
  assert.match(composer, /Result compose\(/);
  assert.match(composer, /BitmapFactory\.decodeFile/);
  assert.match(composer, /Math\.max\(\s*0\.5, Math\.min\(2\.0, mean == 0 \? 1\.0 : referenceMean \/ mean\)\)/);
  assert.match(composer, /8 \* luminance\[p\]/);
  assert.match(composer, /if \(lap > bestLap\[p\]\)/);
  assert.match(composer, /final int sourcesUsed/);
  assert.match(composer, /sourcesUsed < 2/);
  assert.match(composer, /Bitmap\.CompressFormat\.JPEG, 92/);
  assert.match(composer, /TBC-awaiting-hardware/);
  const workflow = await read(
    'native/android/app/src/main/java/com/tauber/nikonlink/CaptureWorkflow.java');
  assert.match(workflow, /File storeFocusStack\(/);
  assert.match(workflow, /xmp:Label=\\"focus-stack\\"/);
  assert.match(workflow, /xmp:FocusStackSources=\\"/);
  const main = await read(
    'native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java');
  assert.match(main, /showComposeFocusStackDialog/);
  assert.match(main, /new FocusStackComposer\(\)/);
  assert.match(main, /storeFocusStack\(/);
});

// ── Harmony ────────────────────────────────────────────────────────────

test('Harmony: FocusStackComposer 纯 ArkTS 图像栈 + 入口面板 + workflow', async () => {
  const composer = await read(
    'native/harmony/entry/src/main/ets/storage/FocusStackComposer.ets');
  assert.match(composer, /export class FocusStackComposer/);
  assert.match(composer, /async compose\(/);
  assert.match(composer, /frames: Array<string>/);
  assert.match(composer, /Math\.max\(\s*\n\s*0\.5,\s*\n\s*Math\.min\(2\.0, mean === 0 \? 1\.0 : referenceMean \/ mean\)\n\s*\)/);
  assert.match(composer, /8 \* luminance\[p\]/);
  assert.match(composer, /if \(lap > bestLap\[p\]\)/);
  assert.match(composer, /class FocusStackComposerResult/);
  assert.match(composer, /readonly sourcesUsed: number/);
  assert.match(composer, /sourcesUsed < 2/);
  assert.match(composer, /image\.createPixelMap\(/);
  assert.match(composer, /image\/jpeg/);
  assert.match(composer, /TBC-awaiting-hardware/);
  const index = await read(
    'native/harmony/entry/src/main/ets/pages/Index.ets');
  assert.match(index, /@State private focusStackVisible: boolean = false/);
  assert.match(index, /private FocusStackComposerOverlay\(\)/);
  assert.match(index, /this\.tr\('焦点合成'\)/);
  assert.match(index, /private async startFocusStackCompose\(\)/);
  assert.match(index, /new FocusStackComposer\(\)/);
  assert.match(index, /workflow\.storeFocusStack\(/);
  const workflow = await read(
    'native/harmony/entry/src/main/ets/workflow/CaptureWorkflow.ets');
  assert.match(workflow, /async storeFocusStack\(/);
  assert.match(workflow, /xmp:Label="focus-stack"/);
  assert.match(workflow, /xmp:FocusStackSources="\$\{stackSourceCount\}"/);
  const localization = await read(
    'native/harmony/entry/src/main/ets/localization/Localization.ets');
  assert.match(localization, /'焦点合成', 'Focus Stack'/);
});

// ── 五端同构一致性 ─────────────────────────────────────────────────────

test('E7: 五端 FocusStackComposer 全部标 TBC-awaiting-hardware 且支持损坏帧跳过', async () => {
  const files = [
    'native/macos/Sources/NikonLink/FocusStackComposer.swift',
    'native/ios/NikonLink/Models/FocusStackComposer.swift',
    'native/windows/Services/FocusStackComposer.cs',
    'native/android/app/src/main/java/com/tauber/nikonlink/FocusStackComposer.java',
    'native/harmony/entry/src/main/ets/storage/FocusStackComposer.ets'
  ];
  for (const file of files) {
    const source = await read(file);
    assert.match(source, /TBC-awaiting-hardware/, `${file} 必须标 TBC-awaiting-hardware`);
    assert.match(source, /skipped/, `${file} 必须支持损坏帧跳过计数`);
  }
});
