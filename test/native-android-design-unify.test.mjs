import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

// v1.5.6 U1（Android）：统一各端 UI 设计语言——残留漂移收口契约。
// ① 白色 alpha 八档对齐 iOS IPalette whiteHi…whiteWash（alpha = round(opacity × 255)）；
// ② 示波器画布 #050A0F 归档 SCOPE_BG（五端基准 SCOPE 通道第五色）；
// ③ 监看页 LIVE 红/蓝归档 VIDEO_LIVE/PHOTO_LIVE（与 VIDEO/COBALT 不同值，不强行合并）；
// ④ 页面标题档 PAGE_FS_HEADING / PAGE_FS_HEADING_COMPACT 收口为五端基准 heading=26；
// ⑤ colors.xml 双轨说明注释（实际生效令牌在 MainActivity.java token 块）。

const root = new URL('../', import.meta.url);
const read = async (path) => readFile(new URL(path, root), 'utf8');

const ANDROID_MAIN =
    'native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java';

test('android U1: white alpha eight steps align to iOS IPalette', async () => {
  const source = await read(ANDROID_MAIN);

  assert.match(source, /WHITE_HI = Color\.argb\(240, 255, 255, 255\)/);    // .94
  assert.match(source, /WHITE_MID = Color\.argb\(224, 255, 255, 255\)/);   // .88
  assert.match(source, /WHITE_LO = Color\.argb\(191, 255, 255, 255\)/);    // .75
  assert.match(source, /WHITE_DIM = Color\.argb\(153, 255, 255, 255\)/);   // .60
  assert.match(source, /WHITE_FAINT = Color\.argb\(143, 255, 255, 255\)/); // .56
  assert.match(source, /WHITE_GHOST = Color\.argb\(115, 255, 255, 255\)/); // .45
  assert.match(source, /WHITE_MIST = Color\.argb\(77, 255, 255, 255\)/);   // .30
  assert.match(source, /WHITE_WASH = Color\.argb\(15, 255, 255, 255\)/);   // .06

  // 散装白色 alpha 内联点已全部收编（144→FAINT、240→HI、224→MID、190→LO、80→MIST）。
  assert.doesNotMatch(source, /Color\.argb\(144, 255, 255, 255\)/);
  assert.doesNotMatch(source, /Color\.argb\(190, 255, 255, 255\)/);
  assert.doesNotMatch(source, /Color\.argb\(80, 255, 255, 255\)/);
});

test('android U1: scope canvas and live indicator colors are tokenized', async () => {
  const source = await read(ANDROID_MAIN);

  assert.match(source, /SCOPE_BG = Color\.rgb\(5, 10, 15\)/);
  assert.match(source, /VIDEO_LIVE = Color\.rgb\(235, 40, 55\)/);
  assert.match(source, /PHOTO_LIVE = Color\.rgb\(72, 145, 255\)/);
  assert.match(source, /monitoring \? VIDEO_LIVE : PHOTO_LIVE/);
});

test('android U1: page heading font sizes unified to five-platform baseline 26', async () => {
  const source = await read(ANDROID_MAIN);

  assert.match(source, /PAGE_FS_HEADING = 26;/);
  assert.match(source, /PAGE_FS_HEADING_COMPACT = 26;/);
  assert.doesNotMatch(source, /PAGE_FS_HEADING = 30;/);
  assert.doesNotMatch(source, /PAGE_FS_HEADING_COMPACT = 25;/);
});

test('android U1: colors.xml files carry dual-track guidance comment', async () => {
  const [light, dark] = await Promise.all([
    read('native/android/app/src/main/res/values/colors.xml'),
    read('native/android/app/src/main/res/values-night/colors.xml'),
  ]);

  for (const xml of [light, dark]) {
    assert.match(xml, /双轨说明/);
    assert.match(xml, /MainActivity\.java/);
    assert.match(xml, /新增 token 勿加这里/);
    // 窗口 chrome 主题引用的 token 保留，不删文件。
    assert.match(xml, /<color name="workbench">/);
    assert.match(xml, /<color name="graphite">/);
  }
});

test('U2 R3 web: styles.css border-radius 无 rem/px 尺寸字面量（仅 var 令牌 + 0 + 装饰百分比）', async () => {
  const css = await read('styles.css');
  // 令牌声明存在（tokens.css 数值未动）。
  assert.match(css, /var\(--radius-(xs|sm|md|lg|round)\)/);
  // 核心门：border-radius 禁止 rem/px 尺寸字面量（单转义 \d）。
  const remPx = css.match(/border-radius:\s*\d+(\.\d+)?(rem|px)\b/g) ?? [];
  assert.equal(remPx.length, 0, `styles.css 不应残留 border-radius 尺寸字面量（残留 ${remPx.length}: ${remPx.join(' | ')}）`);
  // 全部 border-radius 声明必须 ∈ {var(--radius-*), 0, 百分比}。
  const decls = css.match(/border-radius:\s*[^;]+/g) ?? [];
  for (const d of decls) {
    const allowed = /var\(--radius-[\w-]+\)|\b0\b|\b\d+(\.\d+)?%/.test(d);
    assert.ok(allowed, `非法 border-radius 声明: ${d}`);
  }
});

test('U2 R3 android: drawable corners radius 落在设计坡道档（24→20 收敛）', async () => {
  const [light, night] = await Promise.all([
    read('native/android/app/src/main/res/drawable/dialog_surface.xml'),
    read('native/android/app/src/main/res/drawable-night/dialog_surface.xml'),
  ]);
  for (const xml of [light, night]) {
    assert.match(xml, /<corners android:radius="20dp" \/>/);
    assert.doesNotMatch(xml, /24dp/);
  }
});
