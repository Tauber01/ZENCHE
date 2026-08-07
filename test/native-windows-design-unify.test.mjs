import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const root = new URL('../', import.meta.url);
const read = async (path) => readFile(new URL(path, root), 'utf8');

// v1.5.6 U1 设计统一（Tauber 指令「统一各端 UI 设计语言」，Windows 端收口）：
// ① MainWindow.xaml 的 FontFamily="Segoe UI Symbol" 逃逸字面量收编为
//    Colors.xaml 的 IconFont 令牌（⚙/◉ 图标字体确需符号字体）；
// ② WaveformScope.cs 的 RGB/音频/背景通道色补为 ColorScopeR/G/B/Audio/Bg
//    令牌（值与 iOS/macOS SCOPE_* 相同），.cs 经资源查找引用、同值回退。

test('Windows U1: Colors.xaml 含 SCOPE 通道令牌（值同 iOS/macOS SCOPE_*）', async () => {
  const colors = await read('native/windows/Themes/Colors.xaml');
  const expected = {
    ColorScopeR: '#FF302A',
    ColorScopeG: '#28FF69',
    ColorScopeB: '#2240FF',
    ColorScopeAudio: '#4CC7E8',
    ColorScopeBg: '#050A0F'
  };
  for (const [key, hex] of Object.entries(expected)) {
    assert.ok(
      colors.includes(`<Color x:Key="${key}">${hex}</Color>`),
      `Colors.xaml 应含 ${key}=${hex}（与 iOS/macOS SCOPE_* 同值）`
    );
  }
  for (const brush of ['ScopeRBrush', 'ScopeGBrush', 'ScopeBBrush', 'ScopeAudioBrush', 'ScopeBgBrush']) {
    const colorKey = `Color${brush.replace('Brush', '')}`;
    assert.ok(
      colors.includes(`<SolidColorBrush x:Key="${brush}" Color="{DynamicResource ${colorKey}}" />`),
      `Colors.xaml 应含 ${brush} 画刷令牌`
    );
  }
});

test('Windows U1: Colors.xaml 含 IconFont 令牌（Segoe UI Symbol）', async () => {
  const colors = await read('native/windows/Themes/Colors.xaml');
  assert.ok(
    colors.includes('<FontFamily x:Key="IconFont">Segoe UI Symbol</FontFamily>'),
    'Colors.xaml 应含 IconFont 字体令牌'
  );
});

test('Windows U1: MainWindow.xaml 不再有 Segoe UI Symbol 逃逸字面量', async () => {
  const xaml = await read('native/windows/MainWindow.xaml');
  assert.ok(
    !xaml.includes('FontFamily="Segoe UI Symbol"'),
    'MainWindow.xaml 不应再硬编码 FontFamily="Segoe UI Symbol"'
  );
  const refs = xaml.match(/FontFamily="\{DynamicResource IconFont\}"/g) ?? [];
  assert.equal(refs.length, 2, '⚙ 设置钮与 ◉ 空态图标应引用 IconFont 令牌（共 2 处）');
});

test('Windows U1: WaveformScope.cs 经资源查找引用 ColorScope* 令牌', async () => {
  const scope = await read('native/windows/Controls/WaveformScope.cs');
  for (const key of ['ColorScopeR', 'ColorScopeG', 'ColorScopeB', 'ColorScopeAudio', 'ColorScopeBg']) {
    assert.ok(
      scope.includes(`ScopeColor("${key}"`),
      `WaveformScope.cs 应引用 ${key} 资源键`
    );
  }
  // 同值回退保留（资源缺失时观感不变）。
  assert.match(scope, /TryFindResource\(key\) is Color color \? color : Color\.FromRgb/);
});
