import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const root = new URL('../', import.meta.url);
const read = async (path) => readFile(new URL(path, root), 'utf8');

test('harmony U1: device page heading aligns to the five-platform 26pt baseline', async () => {
  const harmony = await read('native/harmony/entry/src/main/ets/pages/Index.ets');
  assert.match(harmony, /const DEVICE_FS_HEADING: number = 26;/);
  assert.doesNotMatch(harmony, /const DEVICE_FS_HEADING: number = 30;/);
});

test('harmony U1: dead design.md palette constants are removed, live ones retained', async () => {
  const harmony = await read('native/harmony/entry/src/main/ets/pages/Index.ets');
  // 零实际引用，U1 删除
  assert.doesNotMatch(harmony, /\bINK\b/);
  assert.doesNotMatch(harmony, /\bREADOUT_GLOW\b/);
  // 有实际引用，保留定义
  assert.match(harmony, /const MUTED_INK: string = '#9AA1AD';/);
  assert.match(harmony, /const RULE: string = '#FFFFFF1F';/);
  assert.match(harmony, /const PHOTO_ACCENT: string = '#2E86E0';/);
  assert.match(harmony, /const PHOTO_ACCENT_LIGHT: string = '#1673E6';/);
  assert.match(harmony, /const POSITIVE_SOFT: string = '#E4F7EE';/);
});

test('U2 R2 harmony radius: borderRadius/border{radius} 数字字面量归零，全部走 RADIUS_* 坡道令牌', async () => {
  const harmony = await read('native/harmony/entry/src/main/ets/pages/Index.ets');
  // 白名单 = 令牌定义块（design.md 圆角坡道：0 / 5-8 / 10-12 / 14 / 16-20 / capsule 999）。
  assert.match(harmony, /const RADIUS_0: number = 0;/);
  for (const step of [5, 6, 7, 8, 10, 11, 12, 14, 16, 17, 18, 19, 20]) {
    assert.match(harmony, new RegExp(`const RADIUS_${step}: number = ${step};`),
      `RADIUS_${step} 令牌须定义（坡道档）`);
  }
  assert.match(harmony, /const RADIUS_CAPSULE: number = 999;/);
  // 枚举数断言（防扫描器失明，4de5097 修法）：调用/键数低于实测下限即红。
  const brCalls = harmony.match(/\.borderRadius\([^)]*\)/g) ?? [];
  assert.ok(brCalls.length >= 104, `borderRadius 调用枚举数异常（${brCalls.length} < 104）`);
  const borderBlocks = harmony.match(/\.border\(\{(?:[^{}]*)\}\)/g) ?? [];
  assert.ok(borderBlocks.length >= 75, `border({}) 块枚举数异常（${borderBlocks.length} < 75）`);
  // 逐调用校验（不允许「任一命中即放行」）：borderRadius 参数必须是 RADIUS_* 标识符。
  for (const c of brCalls) {
    const arg = c.slice(c.indexOf('(') + 1, -1).trim();
    assert.match(arg, /^RADIUS_[A-Z0-9_]+$/, `borderRadius 参数必须是 RADIUS_* 令牌: ${c}`);
  }
  // 逐块校验：border({}) 块内 radius 键必须是 RADIUS_*，数字字面量零残留。
  let radiusKeys = 0;
  for (const b of borderBlocks) {
    assert.doesNotMatch(b, /radius:\s*\d+/, `border({}) 块内残留数字 radius 字面量: ${b.slice(0, 80)}`);
    if (/radius:\s*RADIUS_[A-Z0-9_]+/.test(b)) radiusKeys++;
  }
  assert.ok(radiusKeys >= 71, `border{{radius}} 键枚举数异常（${radiusKeys} < 71）`);
  // 坡道外数值不得以字面量形式出现在使用处。
  assert.doesNotMatch(harmony, /\.borderRadius\(\s*\d+/, '不应残留 borderRadius 数字字面量');
});
