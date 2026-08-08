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

test('U2 R2 windows radius: CornerRadius 数字字面量归零，全部走 StaticResource/FindResource 坡道令牌', async () => {
  const colors = await read('native/windows/Themes/Colors.xaml');
  const main = await read('native/windows/MainWindow.xaml');
  const controls = await read('native/windows/Themes/Controls.xaml');
  const cs = await read('native/windows/MainWindow.xaml.cs');
  const appcs = await read('native/windows/App.xaml.cs');
  // 白名单 = Colors.xaml 令牌定义（design.md 圆角坡道：0 / 5-8 / 10-12 / 14 / 16-20 / capsule 999）。
  assert.match(colors, /<CornerRadius x:Key="CornerRadius0">0<\/CornerRadius>/);
  for (const step of [5, 6, 7, 8, 10, 11, 12, 14, 16, 17, 18, 19, 20]) {
    assert.match(colors, new RegExp(`<CornerRadius x:Key="CornerRadius${step}">${step}</CornerRadius>`),
      `CornerRadius${step} 令牌须定义（坡道档）`);
  }
  assert.match(colors, /<CornerRadius x:Key="CornerRadiusCapsule">999<\/CornerRadius>/);
  const tokenKey = '(?:0|5|6|7|8|10|11|12|14|16|17|18|19|20|Capsule)';
  // 枚举数断言（防扫描器失明）：XAML 属性引用 >=43、Setter 1 处、C# 引用 >=16。
  const xaml = main + '\n' + controls;
  const attrRefs = xaml.match(/CornerRadius="\{StaticResource CornerRadius[A-Za-z0-9]+\}"/g) ?? [];
  assert.ok(attrRefs.length >= 43, `XAML CornerRadius 引用枚举数异常（${attrRefs.length} < 43）`);
  assert.match(controls, /<Setter Property="CornerRadius" Value="\{StaticResource CornerRadius14\}" \/>/);
  const csAll = cs + '\n' + appcs;
  const csRefs = csAll.match(/\(CornerRadius\)FindResource\("CornerRadius[A-Za-z0-9]+"\)/g) ?? [];
  assert.ok(csRefs.length >= 16, `C# CornerRadius 引用枚举数异常（${csRefs.length} < 16）`);
  // 逐 token 校验：每个引用键必须在坡道档集合内（不允许新造坡道外数值）。
  for (const r of attrRefs) {
    assert.match(r, new RegExp(`CornerRadius="\\{StaticResource CornerRadius${tokenKey}\\}"`),
      `非法 CornerRadius 引用: ${r}`);
  }
  for (const r of csRefs) {
    assert.match(r, new RegExp(`CornerRadius${tokenKey}"`), `非法 C# CornerRadius 引用: ${r}`);
  }
  // 数字字面量零残留（属性 + Setter + C# 构造）。
  assert.doesNotMatch(xaml, /CornerRadius="\d+"/, 'XAML 不应残留 CornerRadius 数字字面量');
  assert.doesNotMatch(controls, /Property="CornerRadius" Value="\d+"/, 'Setter 不应残留数字 Value');
  assert.doesNotMatch(csAll, /new CornerRadius\(\d+\)/, 'C# 不应残留 new CornerRadius(数字)');
});
