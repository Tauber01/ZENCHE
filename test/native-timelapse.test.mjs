import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const root = new URL('../', import.meta.url);
const read = async (path) => readFile(new URL(path, root), 'utf8');

// E6 1.5.9 契约锚点：延时合成视频五端同构——
// 序列帧（JPEG/PNG/HEIC/TIFF）→ 逐帧解码 → 统一画布（aspect-fit 黑底）→
// 平台原生编码器 → H.264 MP4；帧率 24/25/30（clamp 1-60）；损坏帧跳过并计数
// （不整批失败）；进度回调 + 取消检查；产出走 CaptureWorkflow 同会话目录
// + reserveBaseName 命名 + finalize 全套（XMP sidecar/双备份/SHA-256 清单）。
// Apple 双端 AVAssetWriter（可选 ProRes 422）；Android MediaCodec；
// Windows MediaComposition；Harmony 因 API 21 移除 ArkTS 低级编解码 API，
// 改走 native C++（libtimelapse.so，OH_VideoEncoder + OH_AVMuxer）。
// 无实机，全部标 TBC-awaiting-hardware（纪律：不得写成已实机验证）。

// ── macOS ──────────────────────────────────────────────────────────────

test('macOS: TimelapseComposer AVAssetWriter + H.264/ProRes + skip/cancel/progress', async () => {
  const composer = await read(
    'native/macos/Sources/NikonLink/TimelapseComposer.swift');
  assert.match(composer, /struct TimelapseComposer/);
  assert.match(composer, /enum Codec: String, CaseIterable, Identifiable/);
  assert.match(composer, /case h264 = "H\.264"/);
  assert.match(composer, /case proRes = "ProRes 422"/);
  assert.match(composer, /AVAssetWriter\(outputURL:/);
  assert.match(composer, /AVVideoCodecKey/);
  assert.match(composer, /let fps = max\(1, min\(60, options\.frameRate\)\)/);
  assert.match(composer, /struct Result/);
  assert.match(composer, /let framesWritten: Int/);
  assert.match(composer, /let skippedFrames: Int/);
  // 损坏帧跳过计数 + 取消 + 进度（逐帧循环内检查）。
  assert.match(composer, /skipped \+= 1/);
  assert.match(composer, /if isCancelled\(\)/);
  assert.match(composer, /onProgress\(index \+ 1, frames\.count\)/);
  assert.match(composer, /TBC-awaiting-hardware/);
});

test('macOS: 产出复用 CaptureWorkflow 会话目录 + reserveBaseName + finalize', async () => {
  const workflow = await read(
    'native/macos/Sources/NikonLink/CaptureWorkflow.swift');
  assert.match(workflow, /func storeTimelapseVideo\(/);
  assert.match(workflow, /reserveBaseName\(cameraName:/);
  assert.match(workflow, /extension: "mp4"/);
  assert.match(workflow, /moveItem\(at: sourceURL, to: destination\)/);
  assert.match(workflow, /try finalize\(destination, location: nil, pairedWithFilename: nil\)/);
});

// ── iOS ────────────────────────────────────────────────────────────────

test('iOS: TimelapseComposer 移植镜像 macOS 契约', async () => {
  const composer = await read(
    'native/ios/NikonLink/Models/TimelapseComposer.swift');
  assert.match(composer, /struct TimelapseComposer/);
  assert.match(composer, /case proRes = "ProRes 422"/);
  assert.match(composer, /AVAssetWriter\(outputURL:/);
  assert.match(composer, /let fps = max\(1, min\(60, options\.frameRate\)\)/);
  assert.match(composer, /let framesWritten: Int/);
  assert.match(composer, /let skippedFrames: Int/);
  assert.match(composer, /skipped \+= 1/);
  assert.match(composer, /if isCancelled\(\)/);
  assert.match(composer, /TBC-awaiting-hardware/);
  const workflow = await read(
    'native/ios/NikonLink/Models/CaptureWorkflow.swift');
  assert.match(workflow, /func storeTimelapseVideo\(/);
  assert.match(workflow, /reserveBaseName\(cameraName:/);
});

// ── Windows ────────────────────────────────────────────────────────────

test('Windows: TimelapseComposer MediaComposition + ComposeAsync 契约', async () => {
  const composer = await read(
    'native/windows/Services/TimelapseComposer.cs');
  assert.match(composer, /public sealed class TimelapseComposer/);
  assert.match(composer, /record Options\(\s*int FrameRate = 24\)/);
  assert.match(composer, /record Result\(/);
  assert.match(composer, /int FramesWritten/);
  assert.match(composer, /int SkippedFrames/);
  assert.match(composer, /ComposeAsync\(/);
  assert.match(composer, /MediaComposition/);
  assert.match(composer, /Math\.Clamp\(options\.FrameRate, 1, 60\)/);
  assert.match(composer, /TBC-awaiting-hardware/);
  const workflow = await read(
    'native/windows/Services/CaptureWorkflow.cs');
  assert.match(workflow, /StoreTimelapseVideoAsync\(/);
  assert.match(workflow, /ReserveBaseName\(cameraName\)/);
  const main = await read('native/windows/MainWindow.xaml.cs');
  assert.match(main, /await composer\.ComposeAsync\(/);
  assert.match(main, /_workflow\.StoreTimelapseVideoAsync\(/);
  assert.match(main, /composeResult\.FramesWritten/);
});

// ── Android ────────────────────────────────────────────────────────────

test('Android: TimelapseComposer MediaCodec + 显式 bitrate 公式 + compose 契约', async () => {
  const composer = await read(
    'native/android/app/src/main/java/com/tauber/nikonlink/TimelapseComposer.java');
  assert.match(composer, /final class TimelapseComposer/);
  assert.match(composer, /Result compose\(/);
  assert.match(composer, /MediaCodec\.createEncoderByType\(/);
  assert.match(composer, /MediaMuxer/);
  // 参数对齐：fps clamp 1-60 + bitrate = clamp(w*h*fps*0.07, 1M, 20M) + I 帧间隔 1。
  assert.match(composer, /int fps = Math\.max\(1, Math\.min\(60, options\.frameRate\)\)/);
  assert.match(composer, /Math\.min\(20_000_000, \(int\) \(width \* height \* fps \* 0\.07\)\)/);
  assert.match(composer, /KEY_I_FRAME_INTERVAL, 1/);
  assert.match(composer, /final int framesWritten/);
  assert.match(composer, /final int skippedFrames/);
  assert.match(composer, /TBC-awaiting-hardware/);
  const workflow = await read(
    'native/android/app/src/main/java/com/tauber/nikonlink/CaptureWorkflow.java');
  assert.match(workflow, /File storeTimelapseVideo\(/);
  assert.match(workflow, /reserveBaseName\(cameraName\)/);
  const main = await read(
    'native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java');
  assert.match(main, /TimelapseComposer\.Result composed = composer\.compose\(/);
  assert.match(main, /storeTimelapseVideo\(/);
});

// ── Harmony ────────────────────────────────────────────────────────────

test('Harmony: TimelapseComposer native C++ 桥接（API 21 无 ArkTS 低级编解码）', async () => {
  const composer = await read(
    'native/harmony/entry/src/main/ets/storage/TimelapseComposer.ets');
  assert.match(composer, /export class TimelapseComposer/);
  assert.match(composer, /import timelapse from 'libtimelapse\.so'/);
  assert.match(composer, /async compose\(/);
  assert.match(composer, /frames: Array<string>/);
  assert.match(composer, /Math\.max\(1, Math\.min\(60, Math\.round\(frameRate\)\)\)/);
  // 码率公式与 Android 对齐（E6 参数契约）。
  assert.match(composer, /Math\.min\(20_000_000, Math\.floor\(width \* height \* fps \* 0\.07\)\)/);
  assert.match(composer, /timelapse\.createEncoder\(/);
  assert.match(composer, /timelapse\.feedFrame\(/);
  assert.match(composer, /timelapse\.finishEncoder\(/);
  assert.match(composer, /timelapse\.destroyEncoder\(/);
  assert.match(composer, /class TimelapseComposerResult/);
  assert.match(composer, /readonly framesWritten: number/);
  assert.match(composer, /readonly skippedFrames: number/);
  assert.match(composer, /TBC-awaiting-hardware/);
});

test('Harmony: native 模块声明 + NAPI 导出 + 入口面板 + workflow 入库', async () => {
  const dts = await read(
    'native/harmony/entry/src/main/cpp/types/libtimelapse/index.d.ts');
  assert.match(dts, /createEncoder/);
  assert.match(dts, /feedFrame/);
  assert.match(dts, /finishEncoder/);
  assert.match(dts, /destroyEncoder/);
  const cpp = await read(
    'native/harmony/entry/src/main/cpp/timelapse_encoder.cpp');
  assert.match(cpp, /OH_VideoEncoder_CreateByMime\(OH_AVCODEC_MIMETYPE_VIDEO_AVC\)/);
  assert.match(cpp, /OH_AVMuxer_Create\(session->outputFd, AV_OUTPUT_FORMAT_MPEG_4\)/);
  assert.match(cpp, /OH_MD_KEY_BITRATE/);
  assert.match(cpp, /AV_PIXEL_FORMAT_NV12/);
  assert.match(cpp, /AVC_PROFILE_MAIN/);
  assert.match(cpp, /OH_MD_KEY_I_FRAME_INTERVAL, 1/);
  assert.match(cpp, /napi_module_register/);
  const cmake = await read(
    'native/harmony/entry/src/main/cpp/CMakeLists.txt');
  assert.match(cmake, /add_library\(timelapse SHARED timelapse_encoder\.cpp\)/);
  assert.match(cmake, /libnative_media_venc\.so/);
  assert.match(cmake, /libnative_media_avmuxer\.so/);
  const index = await read(
    'native/harmony/entry/src/main/ets/pages/Index.ets');
  assert.match(index, /@State private timelapseComposerVisible: boolean = false/);
  assert.match(index, /@State private timelapseFrameRate: number = 24/);
  assert.match(index, /private TimelapseComposerOverlay\(\)/);
  assert.match(index, /this\.tr\('合成延时视频'\)/);
  assert.match(index, /private async startTimelapseCompose\(\)/);
  assert.match(index, /composer\.compose\(/);
  assert.match(index, /workflow\.storeTimelapseVideo\(/);
  const workflow = await read(
    'native/harmony/entry/src/main/ets/workflow/CaptureWorkflow.ets');
  assert.match(workflow, /async storeTimelapseVideo\(/);
  assert.match(workflow, /this\.reserveBaseName\(cameraName\)/);
  assert.match(workflow, /this\.finalize\(destination, undefined, undefined\)/);
});

// ── 五端同构一致性 ─────────────────────────────────────────────────────

test('E6: 五端 TimelapseComposer 全部标 TBC-awaiting-hardware 且支持损坏帧跳过', async () => {
  const files = [
    'native/macos/Sources/NikonLink/TimelapseComposer.swift',
    'native/ios/NikonLink/Models/TimelapseComposer.swift',
    'native/windows/Services/TimelapseComposer.cs',
    'native/android/app/src/main/java/com/tauber/nikonlink/TimelapseComposer.java',
    'native/harmony/entry/src/main/ets/storage/TimelapseComposer.ets'
  ];
  for (const file of files) {
    const source = await read(file);
    assert.match(source, /TBC-awaiting-hardware/, `${file} 必须标 TBC-awaiting-hardware`);
    assert.match(source, /skipped/, `${file} 必须支持损坏帧跳过计数`);
  }
});
