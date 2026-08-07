import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

// U1 设计统一收口（macOS）：positive 五端同值 #1FA869/#35C97B、
// SettingsPalette 去重转发主 Palette、studio 五死 token 删除、
// 尼康云创卡 cloudBg/cloudStroke 保留。
const root = new URL('../', import.meta.url);
const read = async (path) => readFile(new URL(path, root), 'utf8');

test('macOS Palette.positive is the exact five-platform #1FA869/#35C97B', async () => {
  const main = await read('native/macos/Sources/NikonLink/main.swift');
  assert.match(
    main,
    /static let positive = dynamic\(\s*light: \(31\.0 \/ 255\.0, 168\.0 \/ 255\.0, 105\.0 \/ 255\.0\),\s*dark: \(53\.0 \/ 255\.0, 201\.0 \/ 255\.0, 123\.0 \/ 255\.0\)\)/
  );
  // 旧的近似值与漂移值不得残留。
  assert.doesNotMatch(main, /0\.121, 0\.663, 0\.408/);
});

test('macOS studio dead tokens are removed, cloud tokens stay', async () => {
  const main = await read('native/macos/Sources/NikonLink/main.swift');
  for (const token of ['studioCanvas', 'studioPanel', 'studioRaised', 'studioRule', 'studioGold']) {
    assert.doesNotMatch(main, new RegExp(`static let ${token}\\b`), `${token} definition must be gone`);
  }
  // 尼康云创深色卡仍在使用，token 必须保留。
  assert.match(main, /static let cloudBg\b/);
  assert.match(main, /static let cloudStroke\b/);
});

test('macOS SettingsPalette forwards duplicated tokens to the main Palette', async () => {
  const settings = await read('native/macos/Sources/NikonLink/SettingsSheet.swift');
  // 与主 Palette 重复的 token 一律转发，不再本地重定义。
  for (const token of ['ink', 'muted', 'cobalt', 'positive', 'cobaltSoft', 'rule', 'base']) {
    assert.doesNotMatch(
      settings,
      new RegExp(`static let ${token} =`),
      `SettingsPalette.${token} must not be redefined locally`
    );
  }
  // positive 必须与主 Palette 同值（旧漂移值 #0A7E54 不得残留）。
  assert.match(settings, /static var positive: Color \{ Palette\.positive \}/);
  assert.doesNotMatch(settings, /0\.039, 0\.494, 0\.329/);
  // 设置面板独有 token 仍在本地。
  assert.match(settings, /static let support =/);
  assert.match(settings, /static let supportSoft =/);
  assert.match(settings, /static let card =/);
});

test('U2 R1 macOS radius: all cornerRadius literals land on the design.md ramp', async () => {
  const main = await read('native/macos/Sources/NikonLink/main.swift');
  const settings = await read('native/macos/Sources/NikonLink/SettingsSheet.swift');
  // RadiusToken definition block is the whitelist (ramp steps 0 / 5–8 / 10–12 / 14 / 16–20).
  assert.match(main, /enum RadiusToken \{/);
  for (const step of [0, 5, 6, 7, 8, 10, 11, 12, 14, 16, 17, 18, 19, 20]) {
    assert.match(main, new RegExp(`static let ${step === 0 ? 'zero' : 'r' + step}: CGFloat = ${step}\\b`),
      `RadiusToken must define ramp step ${step}`);
  }
  // main.swift + SettingsSheet.swift both use the shared module-level RadiusToken.
  for (const source of [main, settings]) {
    const literals = source.match(/cornerRadius: \d+(\\.\d+)?|cornerRadius\\(\d+(\\.\d+)?\\)|\\.cornerRadius\\(\d+(\\.\d+)?\\)/g) ?? [];
    assert.equal(literals.length, 0, `macOS 不应残留 cornerRadius 数字字面量（残留 ${literals.length}）`);
    assert.doesNotMatch(source, /cornerRadius[:(]\s*(?:1|2|3|4|9|13|15|21|22|23)\b/);
  }
});
