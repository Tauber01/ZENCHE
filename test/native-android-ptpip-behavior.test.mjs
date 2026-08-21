import assert from 'node:assert/strict';
import { execFile, execFileSync } from 'node:child_process';
import { existsSync, mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';

// Android PTP/IP 行为测试：javac 编译真实 PtpIpCamera.java + 进程内假相机
// 夹具（test/fixtures/android-ptpip-harness），覆盖连接往返、探测超时、
// event 通道半开、SocketFactory 注入四类场景。

const root = new URL('../', import.meta.url);
const pathOf = (url) => decodeURIComponent(url.pathname);

const JBR_HOME = '/Applications/DevEco-Studio.app/Contents/jbr/Contents/Home';
const javac = join(JBR_HOME, 'bin', 'javac');
const java = join(JBR_HOME, 'bin', 'java');

const skipReason =
  existsSync(javac) && existsSync(java)
    ? false
    : 'javac/java unavailable on this host (expected under DevEco Studio JBR)';

let classesDir = null;

const buildHarness = () => {
  if (classesDir) return classesDir;
  const output = mkdtempSync(join(tmpdir(), 'android-ptpip-harness-'));
  execFileSync(
    javac,
    [
      '-d',
      output,
      pathOf(
        new URL(
          'native/android/app/src/main/java/com/tauber/nikonlink/PtpIpCamera.java',
          root,
        ),
      ),
      pathOf(
        new URL(
          'native/android/app/src/main/java/com/tauber/nikonlink/CameraStorage.java',
          root,
        ),
      ),
      pathOf(
        new URL(
          'fixtures/android-ptpip-harness/com/tauber/nikonlink/Main.java',
          new URL('test/', root),
        ),
      ),
    ],
    { stdio: 'pipe', timeout: 120_000 },
  );
  classesDir = output;
  return output;
};

const runScenario = (scenario, timeoutMs) =>
  new Promise((resolve, reject) => {
    execFile(
      java,
      ['-cp', buildHarness(), 'com.tauber.nikonlink.Main', scenario],
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
        assert.match(stdout, new RegExp(`SCENARIO=${scenario} RESULT=PASS`));
        resolve(stdout.trim());
      },
    );
  });

test('android ptpip behavior: connect + opensession + probe round-trip', { skip: skipReason }, async () => {
  await runScenario('roundtrip', 30_000);
});

test('android ptpip behavior: dropped probes time out within PROBE_TIMEOUT_MS', { skip: skipReason }, async () => {
  await runScenario('probe-timeout', 30_000);
});

test('android ptpip behavior: half-closed event channel is detected', { skip: skipReason }, async () => {
  await runScenario('event-fin', 30_000);
});

test('android ptpip behavior: injected socket factory creates both sockets', { skip: skipReason }, async () => {
  await runScenario('factory', 30_000);
});
