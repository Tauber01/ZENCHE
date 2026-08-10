import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const root = new URL('../', import.meta.url);
const read = async (path) => readFile(new URL(path, root), 'utf8');

test('macOS 保存窗口位置并把越界窗口恢复到可见屏幕', async () => {
  const [layout, main] = await Promise.all([
    read('native/macos/Sources/NikonLink/DesktopWorkspaceLayout.swift'),
    read('native/macos/Sources/NikonLink/main.swift')
  ]);
  assert.match(layout, /setFrameUsingName\(autosaveName\)/);
  assert.match(layout, /setFrameAutosaveName\(autosaveName\)/);
  assert.match(layout, /constrainToVisibleScreen/);
  assert.match(layout, /NSScreen\.screens/);
  assert.match(main, /DesktopWindowFrame\.restoreOrCenter\(window\)/);
});

test('macOS 工作区分隔条支持持久化、键盘调整、预设与重置', async () => {
  const [layout, main, settings] = await Promise.all([
    read('native/macos/Sources/NikonLink/DesktopWorkspaceLayout.swift'),
    read('native/macos/Sources/NikonLink/main.swift'),
    read('native/macos/Sources/NikonLink/SettingsSheet.swift')
  ]);
  for (const key of [
    'sidebarWidth',
    'inspectorWidth',
    'editorMediaWidth',
    'editorToolsWidth',
    'editorBottomHeight'
  ]) {
    assert.match(layout, new RegExp(`@Published var ${key}`));
    assert.match(main, new RegExp(`desktopLayout\\.${key}`));
  }
  assert.match(layout, /DragGesture\(minimumDistance: 0\)/);
  assert.match(layout, /reversesHorizontalDirection/);
  assert.ok(
    (main.match(/reversesHorizontalDirection: true/g) ?? []).length >= 2,
    '右侧面板分隔条必须按屏幕方向反向映射宽度变化'
  );
  assert.match(layout, /\.onMoveCommand/);
  assert.match(layout, /RuntimeLocalization\.text\(label, locale: locale\)/);
  assert.match(layout, /拖动或使用方向键调整/);
  assert.match(settings, /ForEach\(DesktopWorkspacePreset\.allCases\)/);
  assert.match(settings, /desktopLayout\.reset\(\)/);
});

test('Windows 保存 RestoreBounds 与最大化状态，并夹紧到虚拟桌面', async () => {
  const code = await read('native/windows/MainWindow.xaml.cs');
  assert.match(code, /desktop-workspace-layout-v1\.json/);
  assert.match(code, /RestoreBounds/);
  assert.match(code, /WindowState == WindowState\.Maximized/);
  assert.match(code, /SystemParameters\.VirtualScreenLeft/);
  assert.match(code, /Math\.Clamp\(left, workArea\.Left, workArea\.Right - width\)/);
  assert.match(code, /LoadWorkspaceLayout\(\)/);
  assert.match(code, /SaveWorkspaceLayout\(\)/);
});

test('Windows 原生 GridSplitter 可调主导航、拍摄参数与编辑区', async () => {
  const [xaml, code, localization] = await Promise.all([
    read('native/windows/MainWindow.xaml'),
    read('native/windows/MainWindow.xaml.cs'),
    read('native/windows/Localization.cs')
  ]);
  assert.ok((xaml.match(/<GridSplitter/g) ?? []).length >= 5);
  assert.ok(
    (xaml.match(/ResizeBehavior="CurrentAndNext"/g) ?? []).length >= 5,
    '覆盖在当前栏边缘的分隔条必须调整当前栏与下一栏'
  );
  assert.doesNotMatch(xaml, /ResizeBehavior="PreviousAndNext"/);
  for (const label of [
    '调整主导航宽度',
    '调整拍摄参数面板宽度',
    '调整编辑媒体池宽度',
    '调整编辑工具面板宽度',
    '调整编辑底部工具区高度'
  ]) {
    assert.match(xaml, new RegExp(`AutomationProperties\\.Name="${label}"`));
    assert.match(localization, new RegExp(`\\["${label}"\\]`));
  }
  assert.match(localization, /AutomationProperties\.SetName\(accessibleElement, T\(source\)\)/);
  assert.match(code, /WorkspaceSplitter_DragCompleted/);
  assert.match(code, /ApplyWorkspacePreset/);
  assert.match(code, /SaveWorkspaceLayout\(capturePanelSizes: false\)/);
  assert.match(code, /if \(capturePanelSizes\)/);
  assert.match(code, /ResetWorkspaceLayout_Click/);
  assert.match(code, /ParameterColumn\.MinWidth = cameraWorkspace \? 260 : 0/);
  assert.doesNotMatch(
    code,
    /ParameterColumn\.Width\s*=\s*cameraWorkspace\s*\?\s*new GridLength\(320\)/
  );
});

test('登录墙继续位于工作区分隔条之上', async () => {
  const xaml = await read('native/windows/MainWindow.xaml');
  assert.match(xaml, /x:Name="AuthWall"[\s\S]*Panel\.ZIndex="100"/);
  assert.match(xaml, /GridSplitter[\s\S]{0,360}Panel\.ZIndex="20"/);
});
