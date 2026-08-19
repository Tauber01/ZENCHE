import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const root = new URL('../', import.meta.url);
const read = async (path) => readFile(new URL(path, root), 'utf8');

// E5 1.5.9 契约锚点：live 图（路线 B）五端同构——
// 取景帧内存环形缓冲（LivePhotoClipRecorder）+ 快门切片写 AVI（captureSlice，
// 复用 ExternalVideoRecorder 且绕过节流）+ 照片与切片同 base 配对入库
// （storeLivePhotoClip + XMP xmp:Label="live-photo" / dc:relation 双向指向）。
// Wi‑Fi PTP 遥控快门不生成切片（原片在相机卡，避免孤儿 AVI）。
// 无实机，全部标 TBC-awaiting-hardware（纪律：不得写成已实机验证）。

// ── macOS ──────────────────────────────────────────────────────────────

test('macOS: LivePhotoClipRecorder keeps a memory ring and slices to AVI', async () => {
  const recorder = await read(
    'native/macos/Sources/NikonLink/LivePhotoClipRecorder.swift');
  assert.match(recorder, /final class LivePhotoClipRecorder/);
  assert.match(recorder, /private var ring: \[RingFrame\] = \[\]/);
  assert.match(recorder, /var isArmed: Bool/);
  assert.match(recorder, /func arm\(frameRate: Int, maxSeconds: Double\)/);
  assert.match(recorder, /func disarm\(\)/);
  assert.match(recorder, /func append\(jpeg: Data\)/);
  assert.match(recorder, /func captureSlice\(to url: URL\)/);
  // 切片回放必须绕过节流（E5 缺陷修复 d087b25：否则 AVI 只剩第一帧）。
  assert.match(recorder, /bypassThrottle: true/);
  assert.match(recorder, /TBC-awaiting-hardware/);
});

test('macOS: capture path pairs photo and clip under one base + XMP', async () => {
  const workflow = await read(
    'native/macos/Sources/NikonLink/CaptureWorkflow.swift');
  const main = await read('native/macos/Sources/NikonLink/main.swift');
  assert.match(workflow, /func reserveBaseName\(cameraName: String/);
  assert.match(workflow, /func storeLivePhotoClip\(/);
  assert.match(workflow, /xmp:Label=\\"live-photo\\"/);
  assert.match(workflow, /dc:relation=\\"/);
  // 本机/USB 快门：reserveBaseName → 切片 → store 配对（同 base 双文件）。
  assert.match(main, /reserveBaseName\(\s*cameraName:/);
  assert.match(main, /captureSlice\(\s*to:/);
  assert.match(main, /storeLivePhotoClip\(/);
  // Wi‑Fi PTP 遥控快门：不切片（原片在相机卡，避免孤儿 AVI）。
  assert.match(main, /Wi‑Fi 拍照原片保存在相机存储卡/);
});

test('macOS: ExternalVideoRecorder append gained bypassThrottle default false', async () => {
  const recorder = await read(
    'native/macos/Sources/NikonLink/ExternalVideoRecorder.swift');
  assert.match(recorder, /func append\(jpeg: Data, bypassThrottle: Bool = false\)/);
});

// ── iOS ────────────────────────────────────────────────────────────────

test('iOS: LivePhotoClipRecorder port mirrors macOS ring + slice', async () => {
  const recorder = await read(
    'native/ios/NikonLink/Models/LivePhotoClipRecorder.swift');
  assert.match(recorder, /final class LivePhotoClipRecorder/);
  assert.match(recorder, /private var ring: \[RingFrame\] = \[\]/);
  assert.match(recorder, /func captureSlice\(to url: URL\)/);
  assert.match(recorder, /bypassThrottle: true/);
  assert.match(recorder, /TBC-awaiting-hardware/);
});

test('iOS: remote frame feed and local capture both append to ring; pairing in workflow', async () => {
  const appModel = await read('native/ios/NikonLink/Models/AppModel.swift');
  const workflow = await read(
    'native/ios/NikonLink/Models/CaptureWorkflow.swift');
  assert.match(appModel, /@Published var livePhotoEnabled = false/);
  assert.match(appModel, /livePhotoClipRecorder\.append\(jpeg: jpeg\)/);
  assert.match(appModel, /storeLivePhotoClip\(/);
  assert.match(workflow, /xmp:Label=\\"live-photo\\"/);
  assert.match(workflow, /dc:relation=\\"/);
});

// ── Windows ────────────────────────────────────────────────────────────

test('Windows: LivePhotoClipRecorder ring + CaptureSlice; StepWifiShutterAsync E3 bug fixed', async () => {
  const recorder = await read(
    'native/windows/Services/LivePhotoClipRecorder.cs');
  assert.match(recorder, /public sealed class LivePhotoClipRecorder/);
  assert.match(recorder, /public bool IsArmed/);
  assert.match(recorder, /public void Arm\(int frameRate, double maxSeconds\)/);
  assert.match(recorder, /public void Append\(byte\[\] jpeg\)/);
  assert.match(recorder, /public ExternalVideoRecorder\.RecordingResult\? CaptureSlice\(string path\)/);
  const main = await read('native/windows/MainWindow.xaml.cs');
  // E3 遗留缺陷修复锚点（pro 裁定属实）：升序秒值阶梯 + FirstAtLeast
  // 定位当前档，取代旧降序分母 + FindIndex(1.0/d <= s) 恒命中首档。
  assert.match(main, /E3 遗留缺陷修复/);
  assert.match(main, /1\.0 \/ 8000, 1\.0 \/ 4000/);
  assert.match(main, /FirstAtLeast\(ladder, _wifiShutterSeconds - 0\.00001\)/);
  assert.match(main, /private static int FirstAtLeast\(IReadOnlyList<double> ladder, double value\)/);
  // Wi‑Fi PTP 拍照不生成 live 图切片（孤儿 AVI 规避）。
  assert.match(main, /Wi‑Fi PTP 拍照不生成 live 图切片/);
  // 本机/USB 快门：arm 时取景帧 append + CaptureSlice + storeLivePhotoClip。
  assert.match(main, /_livePhotoClipRecorder\.Arm\(/);
  assert.match(main, /_livePhotoClipRecorder\.Append\(jpeg\)/);
  assert.match(main, /_livePhotoClipRecorder\.CaptureSlice\(/);
});

test('Windows: CaptureWorkflow XMP live-photo pairing', async () => {
  const workflow = await read(
    'native/windows/Services/CaptureWorkflow.cs');
  assert.match(workflow, /StoreLivePhotoClipAsync\(/);
  assert.match(workflow, /xmp:Label=\\"live-photo\\"/);
  assert.match(workflow, /dc:relation=\\"/);
});

// ── Android ────────────────────────────────────────────────────────────

test('Android: LivePhotoClipRecorder ring + slice; syncLivePhotoRing lazy arm', async () => {
  const recorder = await read(
    'native/android/app/src/main/java/com/tauber/nikonlink/LivePhotoClipRecorder.java');
  assert.match(recorder, /final class LivePhotoClipRecorder/);
  assert.match(recorder, /boolean isArmed\(\)/);
  assert.match(recorder, /void arm\(int frameRate, double maxSeconds\)/);
  assert.match(recorder, /void append\(byte\[\] jpeg\)/);
  assert.match(recorder, /ExternalVideoRecorder\.Result captureSlice\(File target\)/);
  assert.match(recorder, /TBC-awaiting-hardware/);
  const main = await read(
    'native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java');
  // 每帧惰性幂等 arm/disarm（取景停点分散，不用显式 stop 钩子）。
  assert.match(main, /private void syncLivePhotoRing\(\)/);
  assert.match(main, /livePhotoClipRecorder\.arm\(/);
  assert.match(main, /livePhotoClipRecorder\.append\(jpeg\)/);
  assert.match(main, /livePhotoClipRecorder\.captureSlice\(/);
  // 开关默认关 + 时长默认 3s（SharedPreferences 持久化）。
  assert.match(main, /livePhotoEnabled", false/);
  assert.match(main, /livePhotoSeconds", 3\.0f/);
  // Wi‑Fi PTP 拍照不生成 live 图切片。
  assert.match(main, /Wi‑Fi PTP 拍照不生成 live 图切片/);
});

test('Android: CaptureWorkflow XMP live-photo pairing', async () => {
  const workflow = await read(
    'native/android/app/src/main/java/com/tauber/nikonlink/CaptureWorkflow.java');
  assert.match(workflow, /File storeLivePhotoClip\(/);
  assert.match(workflow, /xmp:Label=\\"live-photo\\"/);
  assert.match(workflow, /dc:relation=\\"/);
});

// ── Harmony ────────────────────────────────────────────────────────────

test('Harmony: LivePhotoClipRecorder ring + slice; throttle override in recorder', async () => {
  const recorder = await read(
    'native/harmony/entry/src/main/ets/storage/LivePhotoClipRecorder.ets');
  assert.match(recorder, /export class LivePhotoClipRecorder/);
  assert.match(recorder, /get isArmed\(\): boolean/);
  assert.match(recorder, /arm\(frameRate: number, maxSeconds: number\)/);
  assert.match(recorder, /append\(jpeg: Uint8Array\)/);
  assert.match(recorder, /captureSlice\(target: string\)/);
  assert.match(recorder, /appendJpeg\(frame, false\)/);
  assert.match(recorder, /TBC-awaiting-hardware/);
  const external = await read(
    'native/harmony/entry/src/main/ets/storage/ExternalVideoRecorder.ets');
  assert.match(external, /appendJpeg\(jpeg: Uint8Array, throttle: boolean = true\)/);
});

test('Harmony: Index.ets ring sync, capture pairing, settings toggle; workflow XMP', async () => {
  const index = await read('native/harmony/entry/src/main/ets/pages/Index.ets');
  const workflow = await read(
    'native/harmony/entry/src/main/ets/workflow/CaptureWorkflow.ets');
  assert.match(index, /@State private livePhotoEnabled: boolean = false/);
  assert.match(index, /@State private livePhotoSeconds: number = 3\.0/);
  assert.match(index, /private syncLivePhotoRing\(\)/);
  assert.match(index, /this\.livePhotoClipRecorder\.append\(jpeg\)/);
  assert.match(index, /private captureLivePhotoSlice\(\)/);
  assert.match(index, /storeLivePhotoClip\(/);
  // 设置面板：Live 图 Toggle + 时长 Select（1/3/5/10/15s）。
  assert.match(index, /this\.tr\('Live 图'\)/);
  assert.match(index, /'15 秒'/);
  // Wi‑Fi PTP 拍照不生成 live 图切片（孤儿 AVI 规避）。
  assert.match(index, /Wi‑Fi PTP 拍照不生成 live 图切片/);
  assert.match(workflow, /async storeLivePhotoClip\(/);
  assert.match(workflow, /xmp:Label="live-photo"/);
  assert.match(workflow, /dc:relation="\$\{xml\(pairedWithFilename\)\}"/);
});

// ── 五端同构一致性 ─────────────────────────────────────────────────────

test('E5: 五端 live 图切片全部标 TBC-awaiting-hardware 且 Wi‑Fi 路径跳过', async () => {
  const files = [
    'native/macos/Sources/NikonLink/LivePhotoClipRecorder.swift',
    'native/ios/NikonLink/Models/LivePhotoClipRecorder.swift',
    'native/windows/Services/LivePhotoClipRecorder.cs',
    'native/android/app/src/main/java/com/tauber/nikonlink/LivePhotoClipRecorder.java',
    'native/harmony/entry/src/main/ets/storage/LivePhotoClipRecorder.ets'
  ];
  for (const file of files) {
    const source = await read(file);
    assert.match(source, /TBC-awaiting-hardware/, `${file} 必须标 TBC-awaiting-hardware`);
  }
});
