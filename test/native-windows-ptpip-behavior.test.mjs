import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import test from 'node:test';

// Windows PTP/IP 传输层行为测试（非正则锚点）：把生产代码
// native/windows/Services/PtpIpCamera.cs 与进程内伪相机（TcpListener）
// 编译成独立 console harness，逐场景验证真实行为：
//   a) 完整 connect + OpenSession + probe 成功
//   b) 相机忽略探测 → ProbeAsync 在 ≈ProbeTimeoutMilliseconds(3s) 内超时
//   c) 事件通道半关闭 → 下一次探测暴露 reader 失败（IOException，非静默）
//   d) 握手无应答 → 传输层无内置握手超时（12s 预算在 UI 层），调用方
//      CancellationToken 仍能终止并完成清理
//   e) 错误代际 DisconnectIfOwnedAsync 不得拆除存活会话
// 需要 dotnet SDK（开发机约 10.0.x）；不可用时整体 skip。
// 构建产物落在 os.tmpdir() 下的唯一临时目录，不污染仓库。

const projectPath = fileURLToPath(new URL(
  'test/fixtures/windows-ptpip-harness/windows-ptpip-harness.csproj',
  new URL('../', import.meta.url),
));

const dotnetProbe = spawnSync('dotnet', ['--version'], { encoding: 'utf8' });
const dotnetAvailable = dotnetProbe.status === 0;
const skipReason = dotnetAvailable
  ? false
  : 'dotnet SDK unavailable on this machine';

const outputDir = dotnetAvailable
  ? mkdtempSync(join(tmpdir(), 'zenche-windows-ptpip-harness-'))
  : null;
let buildError = null;
let harnessDll = null;
if (dotnetAvailable) {
  const build = spawnSync(
    'dotnet',
    [
      'build',
      projectPath,
      '-c',
      'Release',
      '-o',
      join(outputDir, 'bin'),
      `-p:BaseIntermediateOutputPath=${join(outputDir, 'obj')}/`,
    ],
    { encoding: 'utf8', timeout: 180000 },
  );
  if (build.status !== 0 || build.error) {
    buildError = `${build.stdout ?? ''}${build.stderr ?? ''}`.slice(-4000) ||
      String(build.error);
  } else {
    harnessDll = join(outputDir, 'bin', 'windows-ptpip-harness.dll');
  }
}

const runScenario = (name, timeoutMs = 45000) => {
  assert.equal(buildError, null, `harness build failed: ${buildError}`);
  const run = spawnSync('dotnet', [harnessDll, name], {
    encoding: 'utf8',
    timeout: timeoutMs,
  });
  const output = `${run.stdout ?? ''}${run.stderr ?? ''}`;
  assert.ifError(run.error);
  assert.equal(run.status, 0, output.slice(-2000));
  assert.match(
    output,
    new RegExp(`RESULT ${name} PASS`),
    output.slice(-2000),
  );
  return output;
};

test('windows ptpip harness builds against production sources', {
  skip: skipReason,
}, () => {
  assert.equal(buildError, null, buildError ?? undefined);
});

test('scenario a: full connect + OpenSession + probe succeeds', {
  skip: skipReason,
}, () => {
  const output = runScenario('a');
  assert.match(output, /camera=ZENCHE FakeCam/);
});

test('scenario b: ignored probes time out near ProbeTimeoutMilliseconds', {
  skip: skipReason,
}, () => {
  const output = runScenario('b');
  const elapsed = Number(/elapsed_ms=(\d+)/.exec(output)?.[1]);
  assert.match(output, /probe_timeout_ms=3000/);
  assert.ok(
    elapsed >= 2500 && elapsed <= 9000,
    `probe timeout should surface near 3s, got ${elapsed}ms`,
  );
});

test('scenario c: event-channel half-close surfaces as IOException on probe', {
  skip: skipReason,
}, () => {
  const output = runScenario('c');
  assert.match(output, /detail=IOException/);
});

test('scenario d: silent handshake has no transport timeout; caller token cancels', {
  skip: skipReason,
}, () => {
  const output = runScenario('d');
  assert.match(output, /no-transport-handshake-timeout/);
  const elapsed = Number(/elapsed_ms=(\d+)/.exec(output)?.[1]);
  assert.ok(
    elapsed >= 3000 && elapsed <= 15000,
    `caller-driven cancellation should land near the 4s caller CTS, got ${elapsed}ms`,
  );
});

test('scenario e: stale-generation disconnect leaves the live session intact', {
  skip: skipReason,
}, () => {
  runScenario('e');
});
