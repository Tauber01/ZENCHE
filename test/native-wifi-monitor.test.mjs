import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const root = new URL('../', import.meta.url);
const read = async (path) => readFile(new URL(path, root), 'utf8');

// 五端共通的 B2 保活参数（契约锚点，与实现同步）。
const HEARTBEAT_INTERVAL_SECONDS = 5;
const PROBE_TIMEOUT_MS = 3000;
const OFFLINE_THRESHOLD = 3;
// 指数退避：1/2/4/8/16 封顶 30s。
const backoffSequenceMs = [1000, 2000, 4000, 8000, 16000, 30000];

const backoffDelayMs = (attempt) =>
  backoffSequenceMs[Math.min(Math.max(attempt, 1), backoffSequenceMs.length) - 1];

test('backoff schedule is 1/2/4/8/16 capped at 30s (reference implementation)', () => {
  const expected = [1000, 2000, 4000, 8000, 16000, 30000, 30000, 30000];
  for (let attempt = 1; attempt <= 8; attempt++) {
    assert.equal(backoffDelayMs(attempt), expected[attempt - 1], `attempt ${attempt}`);
  }
});

test('iOS/macOS shared service exposes heartbeat, probe, backoff and reconnecting state', async () => {
  const service = await read(
    'native/ios/NikonLink/Connectivity/RemoteCaptureServices.swift');

  // 心跳参数
  assert.match(service, /heartbeatIntervalSeconds: UInt64 = 5/);
  assert.match(service, /probeTimeoutMilliseconds: UInt64 = 3000/);
  assert.match(service, /offlineThreshold = 3/);
  assert.match(service, /reconnectMaxDelaySeconds: UInt64 = 30/);

  // PTP/IP event 通道 Probe Request/Response（type 13/14）与竞速超时
  assert.match(service, /func probe\(timeoutMilliseconds: UInt64 = 3000\)/);
  assert.match(service, /writeEventPacket\([\s\S]{0,80}type: 13/);

  // 指数退避纯函数 + 状态机
  assert.match(service, /static func backoffDelay\(forAttempt attempt: Int\)/);
  assert.match(service, /case reconnecting\(attempt: Int\)/);
  assert.match(service, /private var manualDisconnect = false/);
  assert.match(service, /private var missedHeartbeats = 0/);
  assert.match(service, /private var reconnectAttempt = 0/);

  // iOS 监听 Wi-Fi 专用路径；macOS 仍保留默认路径，并绑定会话 attempt。
  assert.match(service, /NWPathMonitor\(requiredInterfaceType: \.wifi\)/);
  assert.match(service, /NWPathMonitor\(\)/);
  assert.match(service, /let monitoredAttempt = activeSessionAttempt/);
  assert.match(service, /isCurrentSessionAttempt\(monitoredAttempt\)/);
  assert.match(service, /path\.status != \.satisfied/);

  // UI 呈现：重连中
  const rootView = await read('native/ios/NikonLink/Views/RootView.swift');
  assert.match(rootView, /state\.isReconnecting[\s\S]{0,120}停止重连/);
  assert.match(
    rootView,
    /if model\.wifiCamera\.isConnected \|\| connectionActive \{[\s\S]{0,100}model\.wifiCamera\.disconnect\(\)/,
  );
});

test('Android exposes probe, heartbeat, backoff and NetworkCallback', async () => {
  const transport = await read(
    'native/android/app/src/main/java/com/tauber/nikonlink/PtpIpCamera.java');
  const activity = await read(
    'native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java');

  // 传输层探测：event 通道 type 13/14 + 3s 超时
  assert.match(transport, /void probe\(\)/);
  assert.match(transport, /PROBE_TIMEOUT_MS = 3000/);
  assert.match(transport, /PACKET_PROBE_REQUEST/);
  assert.match(transport, /PACKET_PROBE_RESPONSE/);

  // 心跳参数
  assert.match(activity, /WIFI_HEARTBEAT_INTERVAL_MS = 5000/);
  assert.match(activity, /WIFI_OFFLINE_THRESHOLD = 3/);
  assert.match(activity, /WIFI_RECONNECT_BACKOFF_MS =/);
  assert.match(activity, /\{1000, 2000, 4000, 8000, 16000, 30000\}/);

  // 退避纯函数 + 重连状态 + 手动断连标志
  assert.match(activity, /static long wifiBackoffDelayMs\(int attempt\)/);
  assert.match(activity, /wifiReconnecting/);
  assert.match(activity, /wifiManualDisconnect/);

  // NetworkCallback 网络监听（NetworkRequest 覆盖无互联网的相机 Wi‑Fi）
  assert.match(activity, /ConnectivityManager\.NetworkCallback/);
  assert.match(activity, /registerNetworkCallback/);
  assert.match(activity, /addTransportType\(NetworkCapabilities\.TRANSPORT_WIFI\)/);
  assert.match(activity, /callbackGeneration = wifiConnectionGeneration/);
  // 不再读取系统默认网络来决定是否监听（非默认相机 Wi‑Fi 也必须覆盖）
  assert.doesNotMatch(activity, /getActiveNetwork\(\)/);
  // onAvailable 缓存相机候选网络；连接时注入其 SocketFactory 绑定 socket
  assert.match(activity, /onAvailable\(Network network\)/);
  assert.match(activity, /cameraWifiNetwork = network/);
  assert.match(activity, /sessionNetwork\.getSocketFactory\(\)/);
  assert.match(activity, /wifiCamera\.setSocketFactory\(/);
  // onLost 只响应当前会话实际绑定的网络丢失
  assert.match(activity, /onLost\(Network network\)/);
  assert.match(
    activity,
    /Network boundNetwork = wifiSessionNetwork[\s\S]{0,400}if \(boundNetwork == null \|\| !boundNetwork\.equals\(network\)\) return;/,
  );
  assert.match(activity, /wifiNetworkCallback == this/);
  assert.match(activity, /heartbeatGeneration != wifiConnectionGeneration/);
  assert.match(
    activity,
    /enterWifiReconnecting\(\)[\s\S]{0,300}wifiConnected = false[\s\S]{0,180}unregisterWifiNetworkCallback\(\)/,
  );

  // 传输层 socket 工厂注入（默认工厂 + open() 双通道都走工厂）
  assert.match(transport, /import javax\.net\.SocketFactory;/);
  assert.match(transport, /void setSocketFactory\(SocketFactory factory\)/);
  assert.match(transport, /Socket socket = socketFactory\.createSocket\(\)/);

  // UI 呈现：重连中
  assert.match(activity, /正在自动重连|正在重连 Wi‑Fi 相机/);
  assert.match(
    activity,
    /boolean loading = connecting[\s\S]{0,120}wifiReconnecting/,
  );
  assert.match(
    activity,
    /connectButton\.setEnabled\([\s\S]{0,100}!connecting && !localCameraConnecting/,
  );
});

test('Harmony exposes probe, heartbeat, backoff and NetConnection', async () => {
  const transport = await read(
    'native/harmony/entry/src/main/ets/camera/PtpIpCamera.ets');
  const index = await read(
    'native/harmony/entry/src/main/ets/pages/Index.ets');

  assert.match(transport, /async probe\(timeoutMilliseconds: number = 3000\)/);
  assert.match(
    transport,
    /sendEventPacket\([\s\S]*13,[\s\S]*new Uint8Array\(0\)/,
  );

  assert.match(index, /WIFI_HEARTBEAT_INTERVAL_MS: number = 5000/);
  assert.match(index, /WIFI_OFFLINE_THRESHOLD: number = 3/);
  assert.match(index, /\[1000, 2000, 4000, 8000, 16000, 30000\]/);
  assert.match(index, /wifiReconnecting/);
  assert.match(index, /wifiManualDisconnect/);

  // NetConnection 网络监听
  assert.match(index, /connection\.createNetConnection\(specifier\)/);
  assert.match(index, /bearerTypes: \[connection\.NetBearType\.BEARER_WIFI\]/);
  assert.match(index, /netLost/);
  assert.match(index, /netAvailable/);
  assert.match(index, /this\.wifiNetConnection === netConnection/);
  assert.match(
    index,
    /netAvailable[\s\S]*this\.wifiSourceGeneration === sourceGeneration[\s\S]*this\.sourceSwitchGeneration === sourceGeneration[\s\S]*this\.wakeWifiReconnect\(\)/,
  );
  assert.match(
    index,
    /private wakeWifiReconnect\(\)[\s\S]*this\.stopWifiReconnect\(\)[\s\S]*this\.attemptWifiReconnect\(scheduledGeneration\)/,
  );

  // UI 呈现：重连中
  assert.match(index, /正在自动重连|正在重连…/);
  assert.match(
    index,
    /if \(this\.wifiConnected \|\| this\.wifiConnectionActive\(\)\) \{[\s\S]{0,100}this\.disconnectWifiCamera\(\)/,
  );
});

test('Windows exposes probe, heartbeat, backoff and NetworkAvailabilityChanged', async () => {
  const transport = await read('native/windows/Services/PtpIpCamera.cs');
  const window = await read('native/windows/MainWindow.xaml.cs');

  assert.match(transport, /public async Task ProbeAsync/);
  assert.match(transport, /ProbeTimeoutMilliseconds = 3000/);
  assert.match(transport, /SendEventPacketAsync\(13/);

  assert.match(window, /_wifiHeartbeatTimer = new\(\)/);
  assert.match(window, /Interval = TimeSpan\.FromMilliseconds\(5000\)/);
  assert.match(window, /WifiReconnectBackoffMs =/);
  assert.match(window, /\{ 1000, 2000, 4000, 8000, 16000, 30000 \}/);
  assert.match(window, /static int WifiBackoffDelayMs\(int attempt\)/);
  assert.match(window, /_wifiReconnecting/);
  assert.match(window, /_wifiManualDisconnect/);

  // NetworkAvailabilityChanged 网络监听
  assert.match(window, /NetworkChange\s*\n?\s*\.NetworkAvailabilityChanged/);
  assert.match(window, /NetworkAvailabilityEventArgs/);

  // UI 呈现：重连中
  assert.match(window, /正在重连|重连中/);
  assert.match(window, /private void CancelWifiConnectionAttempt\(\)/);
  assert.match(window, /private async Task StopWifiReconnectAsync\(\)/);
  assert.match(
    window,
    /ReconnectAfterDelayAsync\([\s\S]{0,160}CancellationTokenSource cancellation[\s\S]{0,900}cancellation\.Dispose\(\)/,
  );
  assert.match(
    window,
    /CleanupFailedWifiConnectionAsync\([\s\S]{0,260}if \(!IsWifiConnectionAttemptCurrent\(/,
  );
});

test('all five targets avoid reconnect when the user disconnected manually', async () => {
  const [apple, android, harmony, windows] = await Promise.all([
    read('native/ios/NikonLink/Connectivity/RemoteCaptureServices.swift'),
    read('native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java'),
    read('native/harmony/entry/src/main/ets/pages/Index.ets'),
    read('native/windows/MainWindow.xaml.cs'),
  ]);

  // 手动断连标志在各端驱动逻辑中都被检查
  assert.match(apple, /manualDisconnect/);
  assert.match(android, /wifiManualDisconnect/);
  assert.match(harmony, /wifiManualDisconnect/);
  assert.match(windows, /_wifiManualDisconnect/);
});
