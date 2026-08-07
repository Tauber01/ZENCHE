import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const root = new URL('../', import.meta.url);
const read = async (path) => readFile(new URL(path, root), 'utf8');

// Tauber 指令（iPad 拍照页监看画面置顶口径同步到五端）：
// macOS 拍照页监看画面 = 第一内容区，位于功能顶栏（ControlPageHeader）之后、
// 状态行（ControlStatusRow）之前，与 iOS CapturePage 的 CameraStage 口径一致。

test('macOS: CaptureCompactPreview 位于 ControlPageHeader 与 ControlStatusRow 之间（顶部）', async () => {
  const main = await read('native/macos/Sources/NikonLink/main.swift');
  // 拍照页视图树（CaptureView）。
  const captureView = main.slice(
    main.indexOf('private struct CaptureView: View'),
    main.indexOf('private struct CaptureCompactPreview: View')
  );
  assert.match(captureView, /ControlPageHeader\(/);
  assert.match(captureView, /CaptureCompactPreview\(model: model\)/);
  assert.match(captureView, /ControlStatusRow\(model: model\)/);
  const headerPos = captureView.indexOf('ControlPageHeader(');
  const previewPos = captureView.indexOf('CaptureCompactPreview(model: model)');
  const statusPos = captureView.indexOf('ControlStatusRow(model: model)');
  assert.ok(
    previewPos > headerPos && previewPos < statusPos,
    'CaptureCompactPreview 应位于 ControlPageHeader 与 ControlStatusRow 之间（顶部）'
  );
  // 其余内容区顺序不变：状态行 → 状态卡 → 参数 → 拍摄坞。
  const cardPos = captureView.indexOf('ControlStatusCardGrid(model: model)');
  const paramPos = captureView.indexOf('ControlParameterGrid(model: model)');
  const dockPos = captureView.indexOf('ControlCaptureDock(');
  assert.ok(
    statusPos < cardPos && cardPos < paramPos && paramPos < dockPos,
    '状态行/状态卡/参数/拍摄坞顺序应保持不变'
  );
});
