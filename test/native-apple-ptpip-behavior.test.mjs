import assert from 'node:assert/strict';
import { execFile, execFileSync } from 'node:child_process';
import { mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';

// Apple 端（iOS/macOS 共享 RemoteCaptureServices.swift）PTP/IP 行为测试：
// 本地伪相机（NWListener）+ 真实协议栈全栈驱动，覆盖连接握手、指令往返、
// 心跳探测失效、event 通道半开、握手 deadline 五类场景。

const root = new URL('../', import.meta.url);
const pathOf = (url) => decodeURIComponent(url.pathname);

const hasSwiftc = () => {
  try {
    execFileSync('xcrun', ['--find', 'swiftc'], { stdio: 'pipe' });
    return true;
  } catch {
    return false;
  }
};

const skipReason = hasSwiftc()
  ? false
  : 'xcrun/swiftc unavailable on this host';

let harnessBinary = null;

const buildHarness = () => {
  if (harnessBinary) return harnessBinary;
  const buildDir = mkdtempSync(join(tmpdir(), 'apple-ptpip-harness-'));
  const output = join(buildDir, 'apple-ptpip-harness');
  execFileSync(
    'xcrun',
    [
      'swiftc',
      '-swift-version',
      '5',
      '-framework',
      'Combine',
      '-framework',
      'CoreBluetooth',
      '-framework',
      'CoreGraphics',
      '-framework',
      'CoreLocation',
      '-framework',
      'Foundation',
      '-framework',
      'ImageIO',
      '-framework',
      'Network',
      pathOf(new URL('native/ios/NikonLink/Models/CameraStorage.swift', root)),
      pathOf(
        new URL(
          'native/ios/NikonLink/Connectivity/RemoteCaptureServices.swift',
          root,
        ),
      ),
      pathOf(
        new URL(
          'fixtures/apple-ptpip-harness/ApplePtpIpHarness.swift',
          new URL('test/', root),
        ),
      ),
      '-o',
      output,
    ],
    { stdio: 'pipe', timeout: 300_000 },
  );
  harnessBinary = output;
  return output;
};

const runScenario = (scenario, timeoutMs) =>
  new Promise((resolve, reject) => {
    execFile(
      buildHarness(),
      [scenario],
      { timeout: timeoutMs },
      (error, stdout, stderr) => {
        if (error) {
          reject(
            new Error(
              `scenario ${scenario} failed: ${error.message}\n${stdout}\n${stderr}`,
            ),
          );
          return;
        }
        assert.match(stdout, /PASS/);
        resolve(stdout.trim());
      },
    );
  });

test('apple ptpip behavior: connect + capture round-trip', { skip: skipReason }, async () => {
  await runScenario('connect', 60_000);
});

test('apple ptpip behavior: dropped probes trigger auto reconnect', { skip: skipReason }, async () => {
  await runScenario('probe-drop', 90_000);
});

test('apple ptpip behavior: half-open event channel detected', { skip: skipReason }, async () => {
  await runScenario('event-fin', 90_000);
});

test('apple ptpip behavior: silent camera bounded by handshake deadline', { skip: skipReason }, async () => {
  await runScenario('handshake-silent', 60_000);
});
