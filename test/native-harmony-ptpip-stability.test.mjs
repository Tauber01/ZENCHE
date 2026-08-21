import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

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

// HarmonyOS 相机 Wi-Fi 稳定性收口（1.5.15）：发布前真实 Probe 健康屏障、
// NetHandle 绑定与回调过滤、事件 reader 超时容忍、前台恢复即时心跳。

test('Harmony: assertHealthy 以真实 Probe 往返作为发布前健康屏障', async () => {
  const camera = await read(
    'native/harmony/entry/src/main/ets/camera/PtpIpCamera.ets');
  const health = blockStartingAt(camera, 'async assertHealthy(): Promise<void>');

  // 同步字段检查保持为快速失败前置（本地常量捕获后抛出，规避
  // arkts-limited-throw 对 Error|undefined 字段的限制），随后必须等待
  // 真实 Probe(type 13/14) 往返。
  assert.match(health, /this\.command === undefined/);
  assert.match(
    health,
    /const failure: Error \| undefined = this\.commandChannelFailure;[\s\S]*throw failure;/
  );
  assert.match(health, /await this\.probe\(3000\)/);
  assert.ok(
    health.indexOf('= this.commandChannelFailure') <
      health.indexOf('await this.probe(3000)'),
    '字段快速失败必须先于 Probe 往返'
  );
  // 心跳在飞时复用而不是并发第二次 Probe（probe 自身拒绝并发探测）。
  assert.match(health, /if \(!this\.probeInProgress\)/);
  // Probe 之后再次校验命令通道，防止探测期间通道死亡仍发布已连接。
  assert.match(
    health,
    /const postProbeFailure: Error \| undefined = this\.commandChannelFailure;[\s\S]*throw postProbeFailure;/
  );
  assert.ok(
    health.lastIndexOf('= this.commandChannelFailure') >
      health.indexOf('await this.probe(3000)'),
    'Probe 往返后必须再次校验命令通道'
  );
});

test('Harmony: 初次连接与重连的发布门都 await assertHealthy', async () => {
  const index = await read(
    'native/harmony/entry/src/main/ets/pages/Index.ets');
  const initial = blockStartingAt(index, 'private async connectWifiCamera()');
  const reconnect = blockStartingAt(index, 'private async attemptWifiReconnect(');

  for (const [name, gate] of [['初次连接', initial], ['重连', reconnect]]) {
    const barrier = gate.indexOf('await camera.assertHealthy()');
    assert.notEqual(barrier, -1, `${name}发布门必须 await camera.assertHealthy()`);
    assert.ok(
      barrier < gate.indexOf('this.wifiConnected = true'),
      `${name}：健康屏障必须先于 wifiConnected = true 发布`
    );
  }
  // 参数刷新路径里的第三处调用同样需要 await（异步签名）。
  const refresh = blockStartingAt(
    index,
    'private async refreshWifiParametersFor(',
  );
  assert.match(refresh, /await camera\.assertHealthy\(\);/);
});

test('Harmony: 提供 NetHandle 时 bindSocket 先于 tcp.connect', async () => {
  const camera = await read(
    'native/harmony/entry/src/main/ets/camera/PtpIpCamera.ets');
  const channel = blockStartingAt(camera, 'class PtpIpChannel');
  const channelConnect = blockStartingAt(channel, 'async connect(');
  const connect = blockStartingAt(
    camera,
    'netHandle?: connection.NetHandle\n  ): Promise<string>',
  );

  // bindSocket 是 NetHandle 的方法（入参 TCPSocket），仅在提供 handle 时调用。
  assert.match(
    channelConnect,
    /if \(netHandle !== undefined\) \{[\s\S]*await netHandle\.bindSocket\(this\.tcp\);[\s\S]*\}[\s\S]*await this\.tcp\.connect\(/,
    'bindSocket 必须在 tcp.connect 之前且仅在提供 handle 时调用'
  );
  // PtpIpCamera.connect 把可选 handle 串到双通道，并暴露实际使用的 handle。
  assert.match(connect, /netHandle\?: connection\.NetHandle/);
  assert.match(
    connect,
    /await command\.connect\(host\.trim\(\), port, netHandle\)/
  );
  assert.match(
    connect,
    /await event\.connect\(host\.trim\(\), port, netHandle\)/
  );
  assert.match(connect, /this\.boundNetHandle = netHandle/);
  assert.match(
    camera,
    /get netHandle\(\): connection\.NetHandle \| undefined/
  );
});

test('Harmony: netLost/netAvailable 按相机网络 netId 过滤', async () => {
  const index = await read(
    'native/harmony/entry/src/main/ets/pages/Index.ets');
  const register = blockStartingAt(
    index,
    'private registerWifiNetConnection()',
  );

  // netLost 接收 NetHandle 并在进入重连前比对相机网络。
  assert.match(
    register,
    /netConnection\.on\('netLost', \(netHandle: connection\.NetHandle\)/
  );
  const lostMatch = register.indexOf('this.matchesCameraNetHandle(netHandle)');
  assert.notEqual(lostMatch, -1, 'netLost 必须比对相机网络 handle');
  assert.ok(
    lostMatch < register.indexOf('this.enterWifiReconnecting()'),
    'netId 匹配必须先于 enterWifiReconnecting'
  );
  // netAvailable 同理：仅相机网络恢复（或未解析到 handle）才提前唤醒退避。
  const available = register.slice(register.indexOf("'netAvailable'"));
  assert.match(available, /this\.matchesCameraNetHandle\(netHandle\)/);
  assert.ok(
    available.indexOf('this.matchesCameraNetHandle(netHandle)') <
      available.indexOf('this.wakeWifiReconnect()'),
    'netId 匹配必须先于 wakeWifiReconnect'
  );

  // 匹配规则：已解析相机网络按 netId 比较；未知 handle 退回旧行为（不过滤）。
  const matcher = blockStartingAt(index, 'private matchesCameraNetHandle(');
  assert.match(matcher, /this\.wifiCameraNetId === 0/);
  assert.match(matcher, /netHandle\.netId === this\.wifiCameraNetId/);

  // 相机网络解析：遍历全部网络，bearer 类型看 NetCapabilities，子网匹配
  // 看 ConnectionProperties.linkAddresses（SDK 12 上 linkAddresses 不在
  // NetCapabilities 上）。
  const resolver = blockStartingAt(
    index,
    'private resolveWifiCameraNetHandle(',
  );
  assert.match(resolver, /connection\.getAllNetsSync\(\)/);
  assert.match(resolver, /connection\.getNetCapabilitiesSync\(handle\)/);
  assert.match(resolver, /connection\.getConnectionPropertiesSync\(handle\)/);
  assert.match(resolver, /connection\.NetBearType\.BEARER_WIFI/);
  assert.match(resolver, /properties\.linkAddresses/);
  // 子网判不出来时退回“唯一 Wi-Fi handle”规则。
  assert.match(resolver, /wifiHandleCount === 1 \? soleWifiHandle : undefined/);

  // 初次连接与重连都在 connect 前解析并把 handle 传入。
  const initial = blockStartingAt(index, 'private async connectWifiCamera()');
  const reconnect = blockStartingAt(index, 'private async attemptWifiReconnect(');
  for (const gate of [initial, reconnect]) {
    assert.ok(
      gate.indexOf('this.resolveWifiCameraNetHandle(this.wifiHost.trim())') <
        gate.indexOf('await camera.connect('),
      'connect 前必须解析相机 NetHandle'
    );
    assert.match(gate, /this\.cacheWifiCameraNetHandle\(camera\)/);
  }
});

test('Harmony: 事件 reader 的接收超时继续循环而不是断开会话', async () => {
  const camera = await read(
    'native/harmony/entry/src/main/ets/camera/PtpIpCamera.ets');
  const reader = blockStartingAt(
    camera,
    'private async runEventReader(',
  );

  // receive 的空转超时抛出专用错误类型，reader 捕获后 continue；
  // 存活裁决仍归心跳 probe，真正的关闭/错误才 disconnect。
  assert.match(
    camera,
    /throw new PtpIpReceiveTimeoutError\('相机未在限定时间内返回 PTP\/IP 响应'\)/
  );
  const timeoutContinue = reader.indexOf(
    'if (error instanceof PtpIpReceiveTimeoutError)'
  );
  assert.notEqual(timeoutContinue, -1, 'reader 必须识别接收超时错误');
  assert.match(
    reader.slice(timeoutContinue),
    /\{\s*continue;\s*\}/
  );
  assert.ok(
    timeoutContinue < reader.indexOf('await this.disconnect()'),
    '超时 continue 必须先于真正的断开路径'
  );
});

test('Harmony: 前台恢复通过 AppStorage 钩子立刻补一次心跳 tick', async () => {
  const ability = await read(
    'native/harmony/entry/src/main/ets/entryability/EntryAbility.ets');
  const index = await read(
    'native/harmony/entry/src/main/ets/pages/Index.ets');

  // EntryAbility.onForeground 写入前台时间戳。
  const foreground = blockStartingAt(ability, 'onForeground(): void');
  assert.match(
    foreground,
    /AppStorage\.setOrCreate\('zencheForegroundAt', Date\.now\(\)\)/
  );

  // Index 以 @StorageLink + @Watch 订阅，复用现有心跳 tick（不复制逻辑）。
  assert.match(index, /@StorageLink\('zencheForegroundAt'\)/);
  assert.match(index, /@Watch\('onForegroundReturn'\)/);
  const handler = blockStartingAt(index, 'private onForegroundReturn()');
  assert.match(handler, /!this\.wifiConnected \|\| this\.wifiManualDisconnect/);
  assert.match(
    handler,
    /this\.wifiHeartbeatTick\(this\.wifiAttemptGeneration, this\.wifiCamera\)/
  );
});
