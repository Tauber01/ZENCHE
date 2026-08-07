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
