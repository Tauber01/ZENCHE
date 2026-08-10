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
  assert.match(layout, /transaction\.disablesAnimations = true/);
  assert.match(layout, /NSCursor\.resizeLeftRight/);
  assert.match(layout, /NSCursor\.resizeUpDown/);
  assert.match(layout, /reversesHorizontalDirection/);
  assert.ok(
    (main.match(/reversesHorizontalDirection: true/g) ?? []).length >= 2,
    '右侧面板分隔条必须按屏幕方向反向映射宽度变化'
  );
  assert.match(layout, /\.onMoveCommand/);
  assert.match(layout, /RuntimeLocalization\.text\(label, locale: locale\)/);
  assert.match(layout, /拖动或使用方向键调整/);
  assert.match(layout, /editor\.bottom\.height\.v2/);
  assert.match(layout, /editorBottomRange\([\s\S]*forAvailableHeight/);
  assert.match(layout, /editorToolsRange\([\s\S]*forAvailableWidth/);
  assert.match(layout, /minimumCaptureWorkspaceWidth[\s\S]*minimumWorkspaceWidth/);
  assert.match(layout, /sidebarRange\([\s\S]*forAvailableWidth/);
  assert.match(main, /GeometryReader \{ geometry in[\s\S]*sidebarRange[\s\S]*sidebarWidth/);
  assert.match(main, /minWidth: DesktopWorkspaceLayout\.minimumWorkspaceWidth/);
  assert.match(main, /current\.width < minimum\.width[\s\S]*setVisibleContentSize/);
  assert.match(main, /minimumCaptureCanvasWidth/);
  assert.match(main, /minimumEditorCanvasWidth/);
  assert.match(settings, /ForEach\(DesktopWorkspacePreset\.allCases\)/);
  assert.match(settings, /desktopLayout\.reset\(\)/);
});

test('macOS AI 工具区去除重复导航与重复底栏，默认保留可操作空间', async () => {
  const [layout, main] = await Promise.all([
    read('native/macos/Sources/NikonLink/DesktopWorkspaceLayout.swift'),
    read('native/macos/Sources/NikonLink/main.swift')
  ]);
  const aiPanel = main.slice(
    main.indexOf('private var aiToolsPanel'),
    main.indexOf('private var aiModules')
  );
  const colorPanel = main.slice(
    main.indexOf('private var editorColorPanel'),
    main.indexOf('private var editorToolStrip')
  );
  assert.doesNotMatch(aiPanel, /sectionSelector/);
  assert.match(colorPanel, /if selectedSection == \.aiTools \{[\s\S]*aiToolsPanel[\s\S]*\} else \{[\s\S]*editorStatusRow[\s\S]*editorActionRow/);
  assert.match(layout, /return \(104, 360, 280, 440, 480,/);
  assert.match(layout, /editorBottomRange: ClosedRange<CGFloat> = 220\.\.\.720/);
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
  assert.ok((xaml.match(/<GridSplitter/g) ?? []).length >= 6);
  assert.ok(
    (xaml.match(/ResizeBehavior="CurrentAndNext"/g) ?? []).length >= 6,
    '覆盖在当前栏边缘的分隔条必须调整当前栏与下一栏'
  );
  assert.ok(
    (xaml.match(/ShowsPreview="False"/g) ?? []).length >= 6,
    '桌面分隔条拖动时必须实时连续重排内容'
  );
  assert.doesNotMatch(xaml, /ShowsPreview="True"/);
  assert.doesNotMatch(xaml, /ResizeBehavior="PreviousAndNext"/);
  for (const label of [
    '调整主导航宽度',
    '调整拍摄参数面板宽度',
    '调整编辑媒体池宽度',
    '调整编辑工具面板宽度',
    '调整编辑底部工具区高度',
    '调整 AI 工具面板宽度'
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
  assert.match(code, /ParameterColumn\.MinWidth = cameraWorkspace \? 240 : 0/);
  assert.match(code, /EditorAiToolsWidth/);
  assert.match(code, /EditorAiToolsColumn\.ActualWidth/);
  assert.match(code, /maximumSidebarWidth = Math\.Clamp\([\s\S]*availableWidth - minimumWorkspaceWidth/);
  assert.match(code, /compact \? 708d : 828d/);
  assert.match(code, /ParameterColumn\.MaxWidth = cameraWorkspace/);
  assert.match(code, /EditorAiPreviewColumn\.Width = compact[\s\S]*new GridLength\(0\)/);
  assert.match(code, /AiPreviewPanel\.Visibility = compact[\s\S]*Visibility\.Collapsed/);
  assert.match(code, /EditorAiToolsSplitter\.Visibility = compact[\s\S]*Visibility\.Collapsed/);
  assert.match(code, /EditorAiToolsColumn\.Width = compact[\s\S]*GridUnitType\.Star/);
  assert.match(xaml, /x:Name="EditorAiPreviewColumn"[\s\S]{0,160}MinWidth="360"/);
  assert.match(xaml, /x:Name="AiPreviewPanel"/);
  assert.match(xaml, /x:Name="EditorAiToolsColumn"[\s\S]{0,180}MaxWidth="720"/);
  assert.match(xaml, /<UniformGrid Margin="0,8,0,10" Columns="2">/);
  assert.match(xaml, /<StackPanel x:Name="AiPresetPanel"/);
  assert.match(code, /var choices = new WrapPanel/);
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
