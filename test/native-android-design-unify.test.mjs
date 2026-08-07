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
