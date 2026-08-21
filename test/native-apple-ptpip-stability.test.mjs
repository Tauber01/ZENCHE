import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

// 1.5.15 Wi-Fi 稳定性批（Apple 共享 Swift）契约锚点：
// 1) NWConnection .waiting 不再按 .failed 立即判失败（Wi-Fi 重关联可恢复，
//    终局由 12s 握手 deadline 与取消裁决）；
// 2) 前台恢复立即探测（probeIfIdle + resumeAfterForeground + RootView 钩子）。

const root = new URL('../', import.meta.url);
const read = async (path) => readFile(new URL(path, root), 'utf8');

const blockStartingAt = (source, marker) => {
  const start = source.indexOf(marker);
  assert.notEqual(start, -1, `missing marker: ${marker}`);
  const openingBrace = source.indexOf('{', start);
  assert.notEqual(openingBrace, -1, `missing body: ${marker}`);
  let depth = 0;
  for (let index = openingBrace; index < source.length; index++) {
    if (source[index] === '{') depth++;
    if (source[index] === '}') depth--;
    if (depth === 0) return source.slice(start, index + 1);
  }
  assert.fail(`unterminated body: ${marker}`);
};

test('NWConnection .waiting is recoverable, not an immediate failure', async () => {
  const source = await read(
    'native/ios/NikonLink/Connectivity/RemoteCaptureServices.swift',
  );
  const start = blockStartingAt(
    source,
    'private func start(_ connection: NWConnection) async throws',
  );
  // .waiting 与 .failed 不得再共用同一个抛出分支。
  assert.doesNotMatch(start, /\.failed\(let error\), \.waiting/);
  assert.match(start, /case \.waiting:\s*break/);
  assert.match(start, /case \.failed\(let error\):/);
  // deadline 兜底仍然存在：握手超时仍由 expireConnectionAttempt 裁决。
  assert.match(source, /expireConnectionAttempt\(/);
  assert.match(source, /握手超时（12 秒）/);
});

test('foreground resume performs an immediate probe via the idle-safe path', async () => {
  const source = await read(
    'native/ios/NikonLink/Connectivity/RemoteCaptureServices.swift',
  );
  const probeIfIdle = blockStartingAt(
    source,
    'func probeIfIdle(timeoutMilliseconds:',
  );
  assert.match(probeIfIdle, /if probeInProgress \{ return false \}/);
  assert.match(probeIfIdle, /try await probe\(timeoutMilliseconds:/);

  const resume = blockStartingAt(source, 'func resumeAfterForeground()');
  // 手动断开语义：manualDisconnect 时不得触发任何探测/重连。
  assert.match(resume, /!manualDisconnect/);
  assert.match(resume, /probeIfIdle\(/);
  // 探测失败走既有离线重连，而非自造状态机。
  assert.match(resume, /enterReconnecting\(\)/);

  const rootView = await read('native/ios/NikonLink/Views/RootView.swift');
  assert.match(
    rootView,
    /phase == \.active[\s\S]*model\.wifiCamera\.resumeAfterForeground\(\)/,
  );
});
