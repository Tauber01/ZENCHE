import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const root = new URL('../', import.meta.url);
const read = async (path) => readFile(new URL(path, root), 'utf8');

// v1.5.6 口径同步（Tauber 指令，iPad 已先行）：拍照页监看画面移至顶部——
// 监看 = 拍照页第一内容区，位于功能顶栏之后、状态行（ControlStatusRow）之前。
// Windows 侧将监看 Border（PreviewImage/PreviewEmpty/LiveBadge/全屏钮）从
// CapturePanel Row2 上移至 Row0，并同步 RowDefinitions（监看行保持 * 填充）。

test('Windows: 拍照页监看画面为 CapturePanel 第一内容区（状态行之前）', async () => {
  const xaml = await read('native/windows/MainWindow.xaml');
  const panel = xaml.slice(
    xaml.indexOf('<Grid x:Name="CapturePanel">'),
    xaml.indexOf('<Grid x:Name="DevicesPanel"')
  );
  // 监看块（PreviewImage）必须位于 ControlStatusRow 之前。
  const previewPos = panel.indexOf('x:Name="PreviewImage"');
  const statusRowPos = panel.indexOf('x:Name="ControlStatusRow"');
  assert.ok(previewPos > 0, 'CapturePanel 应含监看画面 PreviewImage');
  assert.ok(statusRowPos > 0, 'CapturePanel 应含状态行 ControlStatusRow');
  assert.ok(
    previewPos < statusRowPos,
    '监看画面（PreviewImage）应位于状态行（ControlStatusRow）之前（拍照页第一内容区）'
  );
  // 完整新顺序：监看 → 状态行 → 状态卡 → 参数 → 拍摄坞。
  const statusGridPos = panel.indexOf('x:Name="ControlStatusGrid"');
  const paramPos = panel.indexOf('x:Name="ControlParameterGrid"');
  const dockPos = panel.indexOf('x:Name="ControlCaptureDock"');
  assert.ok(
    statusRowPos < statusGridPos && statusGridPos < paramPos && paramPos < dockPos,
    '状态行 → 状态卡 → 参数 → 拍摄坞顺序应保持不变'
  );
  // 监看块挂在 Grid.Row="0"，且块内元素原样保留（空态/LiveBadge/全屏钮）。
  assert.match(panel, /<!-- v1\.5\.6[^>]*-->\s*<Border Grid\.Row="0"/);
  const monitor = panel.slice(panel.indexOf('<Border Grid.Row="0"'), statusRowPos);
  assert.match(monitor, /x:Name="PreviewEmpty"/);
  assert.match(monitor, /x:Name="LiveBadge"/);
  assert.match(monitor, /Click="FullscreenPreviewButton_Click"/);
});

test('Windows: CapturePanel 行定义随监看置顶调整（Row0 为 * 填充）', async () => {
  const xaml = await read('native/windows/MainWindow.xaml');
  const panel = xaml.slice(
    xaml.indexOf('<Grid x:Name="CapturePanel">'),
    xaml.indexOf('<Grid x:Name="DevicesPanel"')
  );
  const rowDefs = panel.slice(
    panel.indexOf('<Grid.RowDefinitions>'),
    panel.indexOf('</Grid.RowDefinitions>')
  );
  // 监看行（Row0）必须保持 * 高度填充，视觉效果与移动前一致；其余行 Auto。
  assert.match(rowDefs, /<RowDefinition Height="\*" \/>/);
  assert.equal(
    rowDefs.indexOf('<RowDefinition Height="*" />') <
      rowDefs.indexOf('<RowDefinition Height="Auto" />'),
    true,
    '* 行定义应在首个 Auto 之前（Row0 = 监看行）'
  );
  // 状态行/状态卡不再占用 Row0。
  assert.doesNotMatch(panel, /x:Name="ControlStatusRow"\s+Grid\.Row="0"/);
  assert.match(panel, /x:Name="ControlStatusRow"\s+Grid\.Row="1"/);
  assert.match(panel, /x:Name="ControlStatusGrid" Grid\.Row="2"/);
});
