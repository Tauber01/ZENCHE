import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const root = new URL('../', import.meta.url);
const read = async (path) => readFile(new URL(path, root), 'utf8');

test('U1 iOS design-unify: page title font sizes converge on TypeScale heading 26', async () => {
  const ios = await read('native/ios/NikonLink/Views/RootView.swift');
  // F5 ruling: device page heading and library page titles all land on the
  // cross-platform 26pt heading tier (constants kept, values aligned).
  assert.match(ios, /enum DeviceFontSize \{\s*static let heading: CGFloat = 26\b/);
  assert.match(ios, /static let titleCompact: CGFloat = 26\b/);
  assert.match(ios, /static let titleRegular: CGFloat = 26\b/);
  // TypeScale five tiers stay 11/12/15/18/24.
  assert.match(ios, /static let caption: CGFloat = 11\b/);
  assert.match(ios, /static let body: CGFloat = 12\b/);
  assert.match(ios, /static let emphasis: CGFloat = 15\b/);
  assert.match(ios, /static let title: CGFloat = 18\b/);
  assert.match(ios, /static let display: CGFloat = 24\b/);
});

test('U1 iOS design-unify: dead STUDIO_* retention comment is removed', async () => {
  const ios = await read('native/ios/NikonLink/Views/RootView.swift');
  assert.doesNotMatch(ios, /studioGold|STUDIO_GOLD|StudioGold/);
  assert.doesNotMatch(ios, /studioPanel|STUDIO_PANEL|StudioPanel/);
});

test('U1 iOS design-unify: positive green stays on the cross-platform baseline', async () => {
  const ios = await read('native/ios/NikonLink/Views/RootView.swift');
  assert.match(ios, /static let positive = dynamic\(light: 0x1FA869, dark: 0x35C97B\)/);
});

test('U1 iOS design-unify: AccentColor asset matches the cobalt brand blue #1673E6', async () => {
  const accent = await read(
    'native/ios/NikonLink/Assets.xcassets/AccentColor.colorset/Contents.json'
  );
  const parsed = JSON.parse(accent);
  const components = parsed.colors[0].color.components;
  // #1673E6 in 0-1 sRGB components (0.086/0.451/0.902).
  assert.equal(Number(components.red), 0.086);
  assert.equal(Number(components.green), 0.451);
  assert.equal(Number(components.blue), 0.902);
  assert.equal(components.alpha, '1.000');
});

test('U2 R1 iOS radius: all cornerRadius literals land on the design.md ramp', async () => {
  const ios = await read('native/ios/NikonLink/Views/RootView.swift');
  // RadiusToken definition block is the whitelist (ramp steps 0 / 5–8 / 10–12 / 14 / 16–20).
  assert.match(ios, /enum RadiusToken \{/);
  for (const step of [0, 5, 6, 7, 8, 10, 11, 12, 14, 16, 17, 18, 19, 20]) {
    assert.match(ios, new RegExp(`static let ${step === 0 ? 'zero' : 'r' + step}: CGFloat = ${step}\\b`),
      `RadiusToken must define ramp step ${step}`);
  }
  // Every remaining cornerRadius usage must reference the token — no raw numbers.
  const literals = ios.match(/cornerRadius: \d+(\.\d+)?|cornerRadius\(\d+(\.\d+)?\)|\.cornerRadius\(\d+(\.\d+)?\)/g) ?? [];
  assert.equal(literals.length, 0, `iOS 不应残留 cornerRadius 数字字面量（残留 ${literals.length}）`);
  // Ramp step values outside allowed set must not appear as literals anywhere else.
  const banned = ios.match(/(?<!r)\\b(?:1|2|3|4|9|13|15|21|22|23)\\b(?![0-9])/);
  // note: allowed ramp literals live only inside the RadiusToken block; a light
  // sanity check that banned step values are absent from cornerRadius usage.
  assert.doesNotMatch(ios, /cornerRadius[:(]\s*(?:1|2|3|4|9|13|15|21|22|23)\b/);
});

test('U2 S iOS spacing: padding/spacing literals land on the 4pt ramp via SpaceToken', async () => {
  const ios = await read('native/ios/NikonLink/Views/RootView.swift');
  // SpaceToken definition block is the whitelist (4pt grid: 0/4/8/12/16/20/24/32/40).
  assert.match(ios, /enum SpaceToken \{/);
  for (const step of [0, 4, 8, 12, 16, 20, 24, 32, 40]) {
    assert.match(ios, new RegExp(`static let s${step}: CGFloat = ${step}\\b`),
      `SpaceToken must define ramp step ${step}`);
  }
  // 枚举数下限防扫描器失明（派工实测 413 处；令牌引用含表达式多令牌，取 380+）。
  const refs = ios.match(/SpaceToken\.s\d+/g) ?? [];
  assert.ok(refs.length >= 380, `SpaceToken 引用枚举数异常（${refs.length} < 380）`);
  // 允许字面量集合：坡道档 + 豁免（1/2 细线分隔偏移、44 触控下限、沉浸大留白、动态比例）。
  const allowed = new Set(['0','4','8','12','16','20','24','32','40','44','1','2','52','96','108','174','184','208','0.075']);
  // 逐 token 校验所有 padding/spacing 上下文里的裸数字（表达式内的数字也算）。
  const ctx = ios.match(/\.padding\([^)]*\)|spacing:\s*[^,\)\s]+/g) ?? [];
  assert.ok(ctx.length >= 400, `padding/spacing 上下文枚举数异常（${ctx.length} < 400）`);
  for (const c of ctx) {
    for (const num of c.match(/-?\d+(?:\.\d+)?/g) ?? []) {
      assert.ok(allowed.has(num), `iOS 非法间距字面量 ${num}（上下文: ${c.slice(0, 70)}）`);
    }
  }
  // 禁用值不得以裸数字出现（3/5/6/7/9/10/13/14/15/17/18/22/26/28/30/36/42 已收敛）。
  assert.doesNotMatch(ios, /\.padding\(\s*(?:3|5|6|7|9|10|13|14|15|17|18|22|26|28|30|36|42)\b/);
  assert.doesNotMatch(ios, /spacing:\s*(?:3|5|6|7|9|10|13|14|15|17|18|22|26|28|30|36|42)\b/);
});
