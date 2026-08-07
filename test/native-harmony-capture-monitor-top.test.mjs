import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const root = new URL('../', import.meta.url);
const read = async (path) => readFile(new URL(path, root), 'utf8');

// v1.5.6 拍照页监看置顶（Tauber iPad 口径同步五端，HarmonyOS 端）：
// iOS 新口径（CapturePage）：监看画面 = 拍照页第一内容区，位于功能顶栏之后、
// 状态行（ControlStatusRow）之前。Harmony 端此前监看 Stack 在整列最底部
// （ControlParameterGrid 之后），本批把监看块抽为 MonitorStage Builder，
// 拍照页上移至 ControlStatusRow 之前；监看/本地预览页保持原位置不变。

test('Harmony: 拍照页监看画面（MonitorStage）位于 ControlStatusRow 之前', async () => {
  const index = await read('native/harmony/entry/src/main/ets/pages/Index.ets');
  const workspace = index.slice(
    index.indexOf('private CameraWorkspace()'),
    index.indexOf('private controlAnyCamera()')
  );
  // 拍照页第一内容区：MonitorStage 首次调用必须在 ControlStatusRow 之前。
  const stagePos = workspace.indexOf('this.MonitorStage()');
  const statusRowPos = workspace.indexOf('this.ControlStatusRow()');
  assert.ok(stagePos >= 0, 'CameraWorkspace 应调用 this.MonitorStage()');
  assert.ok(statusRowPos >= 0, 'CameraWorkspace 应调用 this.ControlStatusRow()');
  assert.ok(
    stagePos < statusRowPos,
    '监看画面（MonitorStage）应在状态行（ControlStatusRow）之前（拍照页顶部）'
  );
  // 拍照页其余内容顺序不变：状态行 → 状态卡 → 快门 dock → 参数网格。
  assert.ok(statusRowPos < workspace.indexOf('this.ControlStatusGrid()'));
  assert.ok(
    workspace.indexOf('this.ControlStatusGrid()') <
      workspace.indexOf('this.ControlCaptureDock()')
  );
  assert.ok(
    workspace.indexOf('this.ControlCaptureDock()') <
      workspace.indexOf('this.ControlParameterGrid()')
  );
});

test('Harmony: 监看/本地预览页监看画面保持原位置（时间码之后）', async () => {
  const index = await read('native/harmony/entry/src/main/ets/pages/Index.ets');
  const workspace = index.slice(
    index.indexOf('private CameraWorkspace()'),
    index.indexOf('private controlAnyCamera()')
  );
  // 非拍照页分支：时间码 Text 之后、NikonCloudMonitorPicker 之前渲染监看画面。
  assert.match(
    workspace,
    /if \(this\.section !== 'capture'\) \{\s*\n\s*\/\/ 监看\/本地预览页：监看画面保持原位置（时间码之后）。\s*\n\s*this\.MonitorStage\(\)\s*\n\s*\}/,
    '非拍照页应由 section !== capture 分支在原位置渲染 MonitorStage'
  );
  const timecodePos = workspace.indexOf("Text('00:00:00:00')");
  const pickerPos = workspace.indexOf('this.NikonCloudMonitorPicker()');
  const nonCaptureStagePos = workspace.lastIndexOf('this.MonitorStage()');
  assert.ok(timecodePos >= 0 && pickerPos >= 0);
  assert.ok(
    nonCaptureStagePos > timecodePos && nonCaptureStagePos < pickerPos,
    '监看/本地预览页监看画面应保持在时间码之后、云监看选择器之前'
  );
});

test('Harmony: MonitorStage Builder 保留全屏按钮与弹性占满修饰符', async () => {
  const index = await read('native/harmony/entry/src/main/ets/pages/Index.ets');
  const builder = index.slice(
    index.indexOf('private MonitorStage()'),
    index.indexOf('private CameraWorkspace()')
  );
  // 监看块本体：预览图 / 空态 / LIVE 状态字 / 对焦框与全屏按钮随块一起移动。
  assert.match(builder, /Stack\(\{ alignContent: Alignment\.TopStart \}\)/);
  assert.match(builder, /Image\(this\.preview\)/);
  assert.match(builder, /LIVE VIEW ON/);
  assert.match(builder, /this\.tr\('全屏'\)/);
  assert.match(builder, /this\.openImmersivePreview\(false\)/);
  // 弹性占满剩余空间与最小高度约束保留（整列高度分配不变）。
  assert.match(builder, /\.layoutWeight\(1\)/);
  assert.match(builder, /\.constraintSize\(\{ minHeight: 320 \}\)/);
  // 监看点按对焦与舞台尺寸追踪保留。
  assert.match(builder, /this\.focusAtMonitorPoint/);
  assert.match(builder, /this\.monitorStageWidth = Math\.max/);
});
