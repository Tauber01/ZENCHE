import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const root = new URL('../', import.meta.url);
const read = async (path) => readFile(new URL(path, root), 'utf8');

// v1.5.6 监看画面置顶（Tauber 指令，同步 iPad 口径到五端）：
// 拍照页监看画面 = 第一内容区，位于功能顶栏之后、状态行（ControlStatusRow）之前。
// Android：buildCaptureView() 内 content.addView(buildPreviewStage(false))
// 从 buildControlParameterGrid() 之后移至 buildControlStatusRow() 之前；
// 其余内容顺序不动，错误条（controlStatusError）保持在状态行之后。

test('Android: 拍照页监看画面为 buildCaptureView 第一内容区（状态行之前）', async () => {
  const main = await read(
    'native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java');
  const capture = main.slice(
    main.indexOf('private View buildCaptureView()'),
    main.indexOf('private View buildControlStatusRow()')
  );
  const previewPos = capture.indexOf('content.addView(buildPreviewStage(false))');
  const statusRowPos = capture.indexOf('content.addView(buildControlStatusRow())');
  const errorPos = capture.indexOf('content.addView(controlStatusError');
  assert.ok(previewPos > 0, 'buildCaptureView 应包含监看画面 buildPreviewStage(false)');
  assert.ok(statusRowPos > 0, 'buildCaptureView 应包含状态行 buildControlStatusRow()');
  assert.ok(
    previewPos < statusRowPos,
    '监看画面应在状态行（buildControlStatusRow）之前——拍照页第一内容区'
  );
  // 错误条保持在状态行之后。
  assert.ok(errorPos > statusRowPos, 'controlStatusError 错误条应在状态行之后');
});

test('Android: 拍照页其余内容顺序不变（状态行→错误条→卡片网格→dock→波形→参数网格）', async () => {
  const main = await read(
    'native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java');
  const capture = main.slice(
    main.indexOf('private View buildCaptureView()'),
    main.indexOf('private View buildControlStatusRow()')
  );
  const order = [
    'content.addView(buildControlStatusRow())',
    'content.addView(controlStatusError',
    'content.addView(buildStatusCardGrid())',
    'content.addView(buildControlCaptureDock())',
    'content.addView(captureScopeView',
    'content.addView(buildControlParameterGrid())',
  ];
  let cursor = -1;
  for (const marker of order) {
    const pos = capture.indexOf(marker);
    assert.ok(pos > cursor, `${marker} 缺失或顺序错误`);
    cursor = pos;
  }
  // buildPreviewStage 在 buildCaptureView 内只调用一次（拍照页单监看区）。
  assert.equal(
    capture.split('buildPreviewStage(false)').length - 1,
    1,
    'buildCaptureView 内 buildPreviewStage(false) 应只调用一次'
  );
});
