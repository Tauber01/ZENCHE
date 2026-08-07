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
