import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const root = new URL('../', import.meta.url);
const read = async (path) => readFile(new URL(path, root), 'utf8');

test('E8: macOS AI batch applies copied settings per-photo locally (0 server cost)', async () => {
  const main = await read('native/macos/Sources/NikonLink/main.swift');
  // 渲染管线参数化（批量按照片复用同一 settings）。
  assert.match(main, /func applyTonePipeline\(to source: CIImage, using settings: ProfessionalEditSettings\)/);
  assert.match(main, /func applyGeometry\(to source: CIImage, using settings: ProfessionalEditSettings\)/);
  assert.match(main, /func applyingEditorMask\(\n        to base: CIImage,\n        using settings: ProfessionalEditSettings/);
  // 批量入口：复制方案 → 逐张渲染 → 保存副本。
  assert.match(main, /func renderPhoto\(\n        from url: URL,\n        settings: ProfessionalEditSettings/);
  assert.match(main, /func applyAIBatch\(\)/);
  assert.match(main, /let targets = photos/);
  assert.match(main, /saveEditedPhoto\(/);
  // 进度 / 取消 / 跳过（不整批失败）。
  assert.match(main, /_batchProgress\.wrappedValue = index \+ 1/);
  assert.match(main, /batchCancelled/);
  assert.match(main, /skipped \+= 1/);
  // 本地处理零消耗声明。
  assert.match(main, /批量应用 AI 调整 · 本地处理零消耗/);
});

test('E8: iOS AI batch mirrors macOS contract', async () => {
  const view = await read('native/ios/NikonLink/Views/RootView.swift');
  assert.match(view, /func applyTonePipeline\(to source: CIImage, using settings: ProfessionalEditSettings\)/);
  assert.match(view, /func renderPhoto\(\n        from url: URL,\n        settings: ProfessionalEditSettings/);
  assert.match(view, /func applyAIBatch\(\)/);
  assert.match(view, /let targets = photos/);
  assert.match(view, /saveEditedImage\(/);
  assert.match(view, /_batchProgress\.wrappedValue = index \+ 1/);
  assert.match(view, /批量应用 AI 调整 · 本地处理零消耗/);
});

test('E8: Android AI batch runs on background executor with progress/cancel/skip', async () => {
  const main = await read('native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java');
  assert.match(main, /private void applyAIBatch\(\)/);
  assert.match(main, /editorExecutor\.execute\(/);
  assert.match(main, /renderEditedBitmap\(source, saved, 4096\)/);
  assert.match(main, /Bitmap\.CompressFormat\.JPEG,\s*95/);
  assert.match(main, /uniqueEditedFile\(source\)/);
  assert.match(main, /aiBatchCancelled/);
  assert.match(main, /aiBatchSkipped/);
  assert.match(main, /批量应用 AI 调整 · 本地处理零消耗/);
});

test('E8: Harmony AI batch reuses tone copy/restore and local pixel pipeline', async () => {
  const index = await read('native/harmony/entry/src/main/ets/pages/Index.ets');
  assert.match(index, /private async applyAIBatch\(\): Promise<void>/);
  assert.match(index, /captureEditorTone\(\)/);
  assert.match(index, /restoreEditorTone\(this\.editorAICopiedTone\)/);
  assert.match(index, /renderSingleEditedPhoto\(item\)/);
  assert.match(index, /saveEditedCopy\(item\.name, bytes\)/);
  assert.match(index, /aiBatchCancelled/);
  assert.match(index, /批量应用 AI 调整 · 本地处理零消耗/);
});

test('E8: Windows AI batch runs off the UI thread with progress/cancel/skip', async () => {
  const [window, xaml] = await Promise.all([
    read('native/windows/MainWindow.xaml.cs'),
    read('native/windows/MainWindow.xaml'),
  ]);
  assert.match(window, /private void BatchEditorAI_Click/);
  assert.match(window, /Task\.Run\(async \(\) =>/);
  assert.match(window, /RenderEditedBitmap\(item\.Path, saved, null\)/);
  assert.match(window, /JpegBitmapEncoder \{ QualityLevel = 95 \}/);
  assert.match(window, /_aiBatchCancelled/);
  assert.match(window, /_aiBatchSkipped/);
  assert.match(window, /批量应用 AI 调整 · 本地处理零消耗/);
  assert.match(xaml, /BatchEditorAIButton/);
  assert.match(xaml, /BatchEditorAIProgress/);
});

test('E8: 五端批量均标注本地零消耗，不触 AI 服务器', async () => {
  const sources = await Promise.all([
    read('native/macos/Sources/NikonLink/main.swift'),
    read('native/ios/NikonLink/Views/RootView.swift'),
    read('native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java'),
    read('native/harmony/entry/src/main/ets/pages/Index.ets'),
    read('native/windows/MainWindow.xaml.cs'),
  ]);
  for (const source of sources) {
    assert.match(source, /本地处理零消耗|本地渲染|不触服务器/);
  }
});
