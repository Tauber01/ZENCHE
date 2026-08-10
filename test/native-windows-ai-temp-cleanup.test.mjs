import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const root = new URL('../', import.meta.url);
const read = async (path) => readFile(new URL(path, root), 'utf8');

// W15 P2（AI审查 P2-1，GPT5.6 指派）：Windows AI 临时结果 zenche_ai_*.jpg
// 生命周期集中清理——新结果替换、切换 AI 模式/照片、离开编辑器、窗口关闭
// 一律经 ClearAiResultFile() 释放；TryDeleteAiTempFile 仅删除系统临时目录内
// 本应用命名（zenche_ai_*.jpg）的文件，绝不触碰用户保存的正式副本。

test('Windows AI temp: ClearAiResultFile 是唯一置空 _aiResultPath 的路径', async () => {
  const source = await read('native/windows/MainWindow.xaml.cs');
  const nullAssignments = source.match(/_aiResultPath = null;/g) ?? [];
  assert.equal(nullAssignments.length, 1);
  assert.match(source, /private void ClearAiResultFile\(\)\s*\{\s*var path = _aiResultPath;\s*_aiResultPath = null;\s*TryDeleteAiTempFile\(path\);/);
});

test('Windows AI temp: TryDeleteAiTempFile 守卫临时目录与本应用命名，容错不抛出', async () => {
  const source = await read('native/windows/MainWindow.xaml.cs');
  const helper = source.match(
    /private static void TryDeleteAiTempFile\(string\? path\)([\s\S]*?)\n\n    private static string ImageMimeType/
  )?.[1];
  assert.ok(helper, 'TryDeleteAiTempFile 应位于 ImageMimeType 之前');
  // 只清理系统临时目录内文件：目录必须等于 Path.GetTempPath()（忽略大小写与尾分隔符）
  assert.match(helper, /Path\.GetTempPath\(\)\.TrimEnd\(\s*Path\.DirectorySeparatorChar,\s*Path\.AltDirectorySeparatorChar\)/);
  assert.match(helper, /Path\.GetDirectoryName\(path\)/);
  assert.match(helper, /StringComparison\.OrdinalIgnoreCase/);
  // 只清理本应用命名：zenche_ai_ 前缀（Ordinal）+ .jpg 后缀
  assert.match(helper, /fileName\.StartsWith\(\s*"zenche_ai_",\s*StringComparison\.Ordinal\)/);
  assert.match(helper, /fileName\.EndsWith\(\s*"\.jpg",\s*StringComparison\.OrdinalIgnoreCase\)/);
  // 容错：File.Exists 判定后才删除，且整体被 try/catch 包裹
  assert.match(helper, /if \(File\.Exists\(path\)\)\s*\{\s*File\.Delete\(path\);\s*\}/);
  assert.match(helper, /try\s*\{[\s\S]*File\.Delete\(path\);\s*\}[\s\S]*catch\s*\{/);
});

test('Windows AI temp: 新结果替换前释放旧临时文件', async () => {
  const source = await read('native/windows/MainWindow.xaml.cs');
  assert.match(source, /await File\.WriteAllBytesAsync\(tempPath, imageBytes\);\s*ClearAiResultFile\(\);\s*_aiResultPath = tempPath;/);
});

test('Windows AI temp: 切换 AI 模式（编辑/生成）均释放临时结果', async () => {
  const source = await read('native/windows/MainWindow.xaml.cs');
  assert.match(source, /private void AiEditMode_Click[\s\S]*?_aiMode = 0;\s*ClearAiResultFile\(\);/);
  assert.match(source, /private void AiGenMode_Click[\s\S]*?_aiMode = 1;\s*ClearAiResultFile\(\);/);
});

test('Windows AI temp: 切换照片释放临时结果', async () => {
  const source = await read('native/windows/MainWindow.xaml.cs');
  assert.match(source, /_editorSelectedPath = item\.Path;\s*ClearAiResultFile\(\);\s*var choice = EditorPhotoBox\.Items/);
});

test('Windows AI temp: 离开编辑器与窗口关闭均释放临时结果', async () => {
  const source = await read('native/windows/MainWindow.xaml.cs');
  // 离开编辑器（ShowDestination else 分支，紧随示波器清空）
  assert.match(source, /AiPreviewImage\.Source = null;\s*ClearAiResultFile\(\);\s*EditorScopeWaveform\.SetData\("—", "—", "—"\);/);
  // 窗口关闭（Window_Closing，紧随预览清空与 WiFi 停止）
  assert.match(source, /AiPreviewImage\.Source = null;\s*ClearAiResultFile\(\);\s*StopWifiMonitoring\(\);/);
});

test('Windows AI temp: 临时结果预览立即解码释放文件句柄，原图预览行为不变', async () => {
  const source = await read('native/windows/MainWindow.xaml.cs');
  assert.match(source, /var image = new BitmapImage\(\);\s*image\.BeginInit\(\);\s*if \(_aiResultPath != null\)\s*\{\s*\/\/ 临时结果需在生命周期切换时删除：立即解码并释放文件句柄。\s*image\.CacheOption = BitmapCacheOption\.OnLoad;\s*\}/);
});

test('Windows AI temp: 保存路径不删除临时文件且仍读取 _aiResultPath（正式副本不受影响）', async () => {
  const source = await read('native/windows/MainWindow.xaml.cs');
  const saveBody = source.match(/private void AiSave_Click\([\s\S]*?\n    public string UniqueDestination/)?.[0];
  assert.ok(saveBody, '应能找到 AiSave_Click 方法体');
  assert.match(saveBody, /File\.OpenRead\(_aiResultPath\)/);
  assert.doesNotMatch(saveBody, /ClearAiResultFile|File\.Delete/);
});
