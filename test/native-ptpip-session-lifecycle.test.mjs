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

test('Windows queued PTP/IP writers remain bound to the captured session', async () => {
  const source = await read('native/windows/Services/PtpIpCamera.cs');

  assert.match(source, /long _sessionGeneration/);
  assert.match(source, /object _sessionSync = new\(\)/);
  for (const marker of [
    'private async Task<ushort> SendCommandAsync(',
    'private async Task<byte[]> SendCommandWithDataAsync(',
    'private async Task<ushort> SendCommandWithDataOutAsync(',
  ]) {
    const method = blockStartingAt(source, marker);
    assert.ok(
      method.indexOf('var stream = _commandStream') <
        method.indexOf('await _commandGate.WaitAsync'),
      `${marker} must capture the stream before waiting`,
    );
    assert.ok(
      method.indexOf('var sessionGeneration = Volatile.Read') <
        method.indexOf('await _commandGate.WaitAsync'),
      `${marker} must capture the generation before waiting`,
    );
    assert.match(method, /EnsureCommandSession\(stream, sessionGeneration\)/);
  }

  const eventWriter = blockStartingAt(
    source,
    'private async Task SendEventPacketAsync(\n        uint type,\n        byte[] payload,\n        NetworkStream expectedStream,',
  );
  assert.match(eventWriter, /await _eventWriteGate\.WaitAsync/);
  assert.match(eventWriter, /ReferenceEquals\(_eventStream, expectedStream\)/);
  assert.match(eventWriter, /_sessionGeneration\) != expectedGeneration/);

  assert.match(source, /sealed class PtpResponseException/);
  assert.match(
    source,
    /throw new PtpResponseException\([\s\S]*相机拒绝了 PTP\/IP 操作/,
  );
  assert.doesNotMatch(
    source,
    /throw new IOException\(\$"相机拒绝了 PTP\/IP 操作/,
    'normal PTP response codes must not poison the command transport',
  );

  const disconnect = blockStartingAt(
    source,
    'private async Task DisconnectSessionAsync(long expectedGeneration)',
  );
  assert.ok(
    disconnect.indexOf('Interlocked.Increment(ref _sessionGeneration)') <
      disconnect.indexOf('_commandStream = null'),
    'disconnect must invalidate the generation before detaching streams',
  );

  const connect = blockStartingAt(
    source,
    'public async Task<ConnectionResult> ConnectWithOwnershipAsync(',
  );
  assert.match(source, /long _connectionAttemptGeneration/);
  assert.ok(
    connect.indexOf('ClaimConnectionAttempt()') <
      connect.indexOf('await DisconnectSessionAsync('),
    'a new connection must supersede older attempts before the first await',
  );
  assert.match(
    connect,
    /DisconnectSessionAsync\(\s*connectionAttempt\.SessionGeneration\)/,
    'a superseded connect must not detach a session claimed by a newer attempt',
  );
  assert.match(
    connect,
    /CaptureSessionGeneration\(\s*connectionAttemptGeneration\)/,
  );
  assert.ok(
    (connect.match(/EnsureConnectionCurrent\(/g) ?? []).length >= 8,
    'each handshake suspension boundary must retain attempt ownership',
  );
  assert.match(
    connect,
    /DisconnectSessionAsync\(sessionGeneration\)/,
    'failed attempts may only retire their own session generation',
  );

  const claim = blockStartingAt(
    source,
    'private (long Generation, long SessionGeneration) ClaimConnectionAttempt()',
  );
  assert.match(
    claim,
    /Interlocked\.Increment\(\s*ref _connectionAttemptGeneration\)/,
  );
  assert.match(claim, /Volatile\.Read\(ref _sessionGeneration\)/);

  const publicDisconnect = blockStartingAt(
    source,
    'public async Task DisconnectAsync()',
  );
  assert.ok(
    publicDisconnect.indexOf('ClaimConnectionAttempt()') <
      publicDisconnect.indexOf('await DisconnectSessionAsync('),
    'manual disconnect must invalidate in-flight connection attempts first',
  );
  assert.match(
    publicDisconnect,
    /DisconnectSessionAsync\(\s*disconnectAttempt\.SessionGeneration\)/,
  );
  assert.doesNotMatch(publicDisconnect, /DisconnectSessionAsync\(null\)/);
  const ownedDisconnect = blockStartingAt(
    source,
    'public async Task DisconnectIfOwnedAsync(long expectedGeneration)',
  );
  assert.match(
    ownedDisconnect,
    /DisconnectSessionAsync\(expectedGeneration\)/,
  );
  assert.doesNotMatch(source, /DisconnectSessionAsync\(null\)/);
});

test('Windows manual disconnect cancels restoration and reconnect starts clean', async () => {
  const source = await read('native/windows/MainWindow.xaml.cs');
  const enter = blockStartingAt(
    source,
    'private async Task EnterWifiReconnectingAsync(',
  );
  assert.ok(
    enter.indexOf('StopWifiPreviewLoop()') <
      enter.indexOf('await WaitForWifiPreviewLoopAsync()'),
  );
  assert.ok(
    enter.indexOf('await WaitForWifiPreviewLoopAsync()') <
      enter.indexOf('await _wifiCamera.DisconnectIfOwnedAsync('),
    'the reconnect transition must recheck ownership after preview shutdown',
  );
  assert.ok(
    enter.indexOf('await _wifiCamera.DisconnectIfOwnedAsync(') <
      enter.indexOf('ScheduleWifiReconnect()'),
  );
  assert.match(enter, /transitionGeneration = BeginWifiConnectionAttempt\(\)/);
  assert.ok(
    (enter.match(/IsWifiConnectionAttemptCurrent\(/g) ?? []).length >= 2,
    'the reconnect transition must retain ownership around its disconnect await',
  );
  assert.doesNotMatch(enter, /_wifiCamera\.DisconnectAsync\(\)/);

  const heartbeat = blockStartingAt(
    source,
    'private async void WifiHeartbeatTimer_Tick(',
  );
  assert.ok(
    heartbeat.indexOf('ref _wifiConnectionGeneration') <
      heartbeat.indexOf('await _wifiCamera.ProbeAsync()') &&
      heartbeat.indexOf('ref _wifiOwnedSessionGeneration') <
      heartbeat.indexOf('await _wifiCamera.ProbeAsync()'),
    'heartbeat must capture UI and transport ownership before probing',
  );
  assert.ok(
    (heartbeat.match(/IsPublishedWifiSessionCurrent\(/g) ?? []).length >= 2,
    'heartbeat results must be discarded when either ownership generation changes',
  );
  assert.match(
    heartbeat,
    /EnterWifiReconnectingAsync\(\s*connectionGeneration,\s*sessionGeneration\)/,
  );

  const attempt = blockStartingAt(
    source,
    'private async Task AttemptWifiReconnectAsync(',
  );
  assert.ok(
    (attempt.match(/EnsureWifiConnectionAttemptCurrent\(/g) ?? []).length >= 5,
    'every restoration boundary must retain the scheduled attempt generation',
  );
  assert.match(
    attempt,
    /ConnectWithOwnershipAsync\(\s*_wifiHost,\s*_wifiPort,\s*attemptToken\)/,
  );
  assert.match(attempt, /ownedSessionGeneration = connection\.SessionGeneration/);
  assert.doesNotMatch(
    attempt,
    /_wifiCamera\.DisconnectAsync\(\)/,
    'a stale reconnect task must never unconditionally disconnect a newer session',
  );
  assert.ok(
    attempt.indexOf('_wifiReconnecting = false') >
      attempt.indexOf('RefreshWifiParametersAsync(attemptToken)'),
  );

  const schedule = blockStartingAt(
    source,
    'private void ScheduleWifiReconnect()',
  );
  assert.match(schedule, /connectionGeneration = BeginWifiConnectionAttempt\(\)/);
  assert.match(
    schedule,
    /ReconnectAfterDelayAsync\(\s*delay,\s*cts\.Token,\s*connectionGeneration\)/,
  );

  const cleanup = blockStartingAt(
    source,
    'private async Task CleanupFailedWifiConnectionAsync(',
  );
  assert.match(cleanup, /DisconnectIfOwnedAsync\(ownedGeneration\)/);
  assert.doesNotMatch(cleanup, /_wifiCamera\.DisconnectAsync\(\)/);

  assert.match(
    source,
    /InvalidateWifiConnectionAttempts\(\);\s*ClearWifiSessionOwnership\(\);\s*_wifiManualDisconnect = true;\s*_wifiReconnecting = false;\s*StopWifiMonitoring\(\);\s*StopWifiPreviewLoop\(\);\s*await _wifiCamera\.DisconnectAsync\(\)/,
  );
});

test('Windows Wi-Fi live-view stop drains the in-flight frame before EndLiveView', async () => {
  const source = await read('native/windows/MainWindow.xaml.cs');
  const stop = blockStartingAt(
    source,
    'private async Task StopWifiLiveViewAsync(',
  );
  assert.ok(
    stop.indexOf('StopWifiPreviewLoopGracefully()') <
      stop.indexOf('await WaitForWifiPreviewLoopAsync()') &&
      stop.indexOf('await WaitForWifiPreviewLoopAsync()') <
      stop.indexOf('await _wifiCamera.StopLiveViewAsync(cancellationToken)'),
    'queued frame reads must finish before EndLiveView is sent',
  );
  assert.doesNotMatch(stop, /StopWifiPreviewLoop\(\)/);
  assert.ok(
    (source.match(/await StopWifiLiveViewAsync\(token\)/g) ?? []).length >= 2,
    'both Wi-Fi live-view stop controls must use the draining path',
  );

  const loop = blockStartingAt(
    source,
    'private async Task WifiPreviewLoopAsync(',
  );
  assert.match(loop, /long generation/);
  assert.match(
    loop,
    /generation == Volatile\.Read\(ref _wifiPreviewGeneration\)/,
  );
  assert.ok(
    loop.indexOf('await _wifiCamera.GetLiveViewFrameAsync(') <
      loop.indexOf(
        'generation != Volatile.Read(ref _wifiPreviewGeneration)',
      ),
    'the loop must observe graceful retirement after its active frame returns',
  );
});

test('Android command-only failures poison probes and streamed lengths are checked', async () => {
  const source = await read(
    'native/android/app/src/main/java/com/tauber/nikonlink/PtpIpCamera.java',
  );
  const probe = blockStartingAt(source, 'synchronized void probe()');
  const dataIn = blockStartingAt(source, 'private byte[] commandWithData(');

  assert.match(probe, /commandChannelFailure != null/);
  assert.match(source, /writeCommandPacket\(/);
  assert.match(source, /readCommandPacket\(\)/);
  assert.match(source, /commandChannelFailed\(IOException error\)/);

  assert.match(
    dataIn,
    /u32\(first\.data, 12\) != 0xffff_ffffL[\s\S]*u32\(first\.data, 16\) != 0xffff_ffffL/,
  );
  assert.match(dataIn, /hasDeclaredLength && data\.size\(\) > totalLength/);
  assert.match(dataIn, /hasDeclaredLength && data\.size\(\) != totalLength/);
  assert.match(source, /length > 64 \* 1024 \* 1024L/);
});

test('Android event reader owns one socket generation and rejects partial-packet timeouts', async () => {
  const source = await read(
    'native/android/app/src/main/java/com/tauber/nikonlink/PtpIpCamera.java',
  );
  const connect = blockStartingAt(source, 'synchronized String connect(');
  const reader = blockStartingAt(source, 'private void runEventReader(');
  const current = blockStartingAt(source, 'private boolean isCurrentEventReaderLocked(');
  const packet = blockStartingAt(source, 'private static Packet readPacket(');
  const exact = blockStartingAt(source, 'private static byte[] readExactly(');

  assert.match(
    connect,
    /startEventReader\([\s\S]*pendingCommandSocket,[\s\S]*pendingEventSocket,[\s\S]*generation/,
  );
  assert.match(current, /transportGeneration == generation/);
  assert.match(current, /commandSocket == expectedCommandSocket/);
  assert.match(current, /eventSocket == expectedEventSocket/);
  assert.match(reader, /closeQuietly\(expectedCommandSocket\)/);
  assert.doesNotMatch(reader, /closeQuietly\(commandSocket\)/);
  assert.match(reader, /isCurrentEventReaderLocked\(/);

  assert.match(packet, /readExactly\(input, 8, true\)/);
  assert.match(packet, /readExactly\(input, \(int\) length - 8, false\)/);
  assert.match(exact, /catch \(SocketTimeoutException timeout\)/);
  assert.match(exact, /allowIdleTimeout && offset == 0/);
  assert.match(exact, /PTP\/IP 数据包在读取中途超时/);
});

test('Android delayed camera actions stay bound to their source session', async () => {
  const source = await read(
    'native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java',
  );
  const sourceGuard = blockStartingAt(
    source,
    'private boolean cameraSourceSessionActive(',
  );
  const liveView = blockStartingAt(source, 'private void toggleLiveView()');
  const capture = blockStartingAt(source, 'private void capturePhoto()');
  const recording = blockStartingAt(source, 'private void toggleVideoRecording()');

  assert.match(sourceGuard, /generation == usbCameraConnectionGeneration/);
  assert.match(sourceGuard, /generation == localCameraConnectionGeneration/);
  assert.match(sourceGuard, /wifiSessionActive\(generation\)/);
  for (const [label, action] of [
    ['live view', liveView],
    ['capture', capture],
    ['recording', recording],
  ]) {
    assert.match(action, /operationSource = activeCameraSource\(\)/, label);
    assert.match(
      action,
      /operationGeneration = cameraSourceGeneration\(operationSource\)/,
      label,
    );
    assert.ok(
      (action.match(/cameraSourceSessionActive\(/g) ?? []).length >= 3,
      `${label} must re-check ownership across worker and UI boundaries`,
    );
  }
  assert.doesNotMatch(liveView, /if \(wifiSourceActive\(\)\) wifiCamera/);
  assert.doesNotMatch(recording, /if \(wifiSourceActive\(\)\)/);
});

test('Android handshake sockets are abortable and fatal session responses block publish', async () => {
  const camera = await read(
    'native/android/app/src/main/java/com/tauber/nikonlink/PtpIpCamera.java',
  );
  const activity = await read(
    'native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java',
  );
  const connect = blockStartingAt(camera, 'synchronized String connect(');
  const abort = blockStartingAt(camera, 'void abortTransport()');
  const detect = blockStartingAt(camera, 'synchronized CameraVendor detectVendor()');
  const rejected = blockStartingAt(
    camera,
    'private PtpResponseException rejected(int response)',
  );
  const initial = blockStartingAt(
    activity,
    'private void connectWifiCamera(String host, int port, String connectionMode)',
  );
  const reconnect = blockStartingAt(
    activity,
    'private final Runnable wifiReconnectRunnable',
  );

  assert.match(camera, /volatile Socket connectingCommandSocket/);
  assert.match(camera, /volatile Socket connectingEventSocket/);
  assert.match(camera, /long transportGeneration/);
  assert.ok(
    connect.indexOf('final long generation = beginTransportAttempt()') <
      connect.indexOf('host.trim(), port, generation, true'),
  );
  assert.match(connect, /host\.trim\(\), port, generation, true/);
  assert.match(connect, /host\.trim\(\), port, generation, false/);
  assert.ok(
    (connect.match(/ensureTransportGeneration\(generation\)/g) ?? []).length >= 5,
    'every blocking handshake boundary must reject an aborted generation',
  );
  assert.ok(
    abort.indexOf('transportGeneration++') <
      abort.indexOf('pendingCommand = connectingCommandSocket'),
  );
  assert.match(abort, /closeQuietly\(pendingCommand\)/);
  assert.match(abort, /closeQuietly\(pendingEvent\)/);
  assert.match(abort, /closeQuietly\(activeCommand\)/);
  assert.match(abort, /closeQuietly\(activeEvent\)/);

  assert.match(detect, /catch \(PtpResponseException responseError\)/);
  assert.match(detect, /isVendorDiscoveryFallback\(responseError\.responseCode\)/);
  assert.match(rejected, /isSessionFatalResponse\(response\)/);
  assert.match(rejected, /commandChannelFailed\(error\)/);
  assert.match(
    camera,
    /isVendorDiscoveryFallback[\s\S]*0x2005[\s\S]*0x200a[\s\S]*0x2019/
  );
  assert.match(
    camera,
    /response == 0x2003[\s\S]*response == 0x2004[\s\S]*response == 0x201e/
  );
  for (const attempt of [initial, reconnect]) {
    assert.ok(
      attempt.indexOf('wifiCamera.assertHealthy()') <
        attempt.indexOf('wifiConnected = true'),
      'both command and event channels must be healthy before publishing success',
    );
  }
});

test('Android cancelled Wi-Fi connects cannot republish stale sessions', async () => {
  const source = await read(
    'native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java',
  );
  const connect = blockStartingAt(
    source,
    'private void connectWifiCamera(String host, int port, String connectionMode)',
  );
  const disconnect = blockStartingAt(
    source,
    'private void disconnectWifiCamera()',
  );
  const reconnect = blockStartingAt(
    source,
    'private final Runnable wifiReconnectRunnable',
  );

  assert.match(source, /volatile long wifiConnectionGeneration/);
  assert.match(connect, /connectionGeneration = \+\+wifiConnectionGeneration/);
  assert.ok(
    (connect.match(/wifiConnectAttemptActive\(connectionGeneration, false\)/g)
      ?? []).length >= 5,
    'initial connect must validate its generation at I/O and UI boundaries',
  );
  assert.ok(
    connect.indexOf('wifiConnectAttemptActive(connectionGeneration, false)') <
      connect.indexOf('wifiConnected = true'),
    'stale callback check must precede publishing the connection',
  );
  assert.match(connect, /PtpIpCamera\.CameraVendor detectedVendor/);
  assert.match(reconnect, /connectionGeneration = \+\+wifiConnectionGeneration/);
  assert.ok(
    (reconnect.match(/wifiConnectAttemptActive\(connectionGeneration, true\)/g)
      ?? []).length >= 5,
    'reconnect must validate its generation at I/O and UI boundaries',
  );

  assert.ok(
    disconnect.indexOf('wifiConnectionGeneration++') <
      disconnect.indexOf('wifiManualDisconnect = true'),
    'manual disconnect must invalidate pending callbacks first',
  );
  assert.match(
    disconnect,
    /cameraExecutor\.submit\(wifiCamera::close\)/,
    'monitor-taking cleanup must run off the Android UI thread',
  );
  assert.ok(
    disconnect.indexOf('wifiCamera.abortTransport()') <
      disconnect.indexOf('cameraExecutor.submit'),
    'manual disconnect must abort blocking socket I/O before queued cleanup',
  );
  assert.match(
    source,
    /if \(wifiConnected \|\| wifiConnecting \|\| wifiReconnecting\) \{\s*disconnectWifiCamera\(\);/,
  );
});

test('Android auth cleanup invalidates in-flight Wi-Fi and local-camera connects', async () => {
  const source = await read(
    'native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java',
  );
  const closeAuth = blockStartingAt(source, 'private void closeAuthSensitiveState()');
  const localConnect = blockStartingAt(source, 'private void connectLocalCamera()');

  assert.match(closeAuth, /wifiManualDisconnect = true;\s*wifiConnectionGeneration\+\+/);
  assert.match(closeAuth, /usbCameraConnectionGeneration\+\+/);
  assert.match(closeAuth, /localCameraConnectionGeneration\+\+/);
  assert.match(localConnect, /connectionGeneration = \+\+localCameraConnectionGeneration/);
  assert.ok(
    (localConnect.match(/connectionGeneration != localCameraConnectionGeneration/g)
      ?? []).length >= 3,
    'local-camera worker and callbacks must reject an invalidated generation',
  );
});

test('Harmony denied local-camera permission preserves the active Wi-Fi source generation', async () => {
  const source = await read(
    'native/harmony/entry/src/main/ets/pages/Index.ets',
  );
  const selectLocal = blockStartingAt(source, 'private async selectLocalCamera()');
  const permissionAwait = selectLocal.indexOf('await this.requestFeaturePermissions');
  const denied = selectLocal.indexOf('if (!granted)');
  const claim = selectLocal.indexOf(
    'const sourceGeneration: number = ++this.sourceSwitchGeneration',
  );

  assert.match(
    selectLocal,
    /const observedSourceGeneration: number = this\.sourceSwitchGeneration/,
  );
  assert.ok(permissionAwait >= 0 && denied > permissionAwait);
  assert.ok(
    claim > denied,
    'the source generation may only be claimed after permission is granted',
  );
  assert.doesNotMatch(
    selectLocal.slice(0, denied),
    /\+\+this\.sourceSwitchGeneration/,
  );
  assert.doesNotMatch(
    blockStartingAt(selectLocal, 'if (!granted)'),
    /wifiAttemptGeneration|wifiConnecting|wifiReconnecting|wifiConnected/,
  );
});

test('Harmony Wi-Fi controls keep async continuations on their captured attempt', async () => {
  const source = await read(
    'native/harmony/entry/src/main/ets/pages/Index.ets',
  );
  const active = blockStartingAt(source, 'private isCurrentWifiOperation(');
  assert.match(active, /this\.isCurrentWifiAttempt\(attempt, camera\)/);
  assert.match(active, /this\.wifiConnected/);
  assert.match(active, /!this\.wifiReconnecting/);
  assert.match(active, /!this\.wifiManualDisconnect/);

  for (const [marker, property] of [
    ['private async stepWifiIso(', '0x500f'],
    ['private async stepWifiAperture(', '0x5007'],
    ['private async stepWifiShutter(', '0x500d'],
  ]) {
    const step = blockStartingAt(source, marker);
    assert.ok(
      step.indexOf('const camera: PtpIpCamera = this.wifiCamera') <
        step.indexOf(`await camera.writeProperty(${property}, payload)`),
    );
    assert.ok(
      step.indexOf('const attempt: number = this.wifiAttemptGeneration') <
        step.indexOf(`await camera.writeProperty(${property}, payload)`),
    );
    assert.match(step, /await this\.refreshWifiParametersFor\(camera, attempt\)/);
    assert.ok((step.match(/isCurrentWifiOperation/g) ?? []).length >= 2);
    assert.doesNotMatch(step, /this\.wifiCamera\.writeProperty/);
    assert.doesNotMatch(step, /refreshWifiParameters\(\)/);
  }

  const liveView = blockStartingAt(source, 'private async toggleLiveView()');
  assert.match(liveView, /const wifiCamera: PtpIpCamera = this\.wifiCamera/);
  assert.match(liveView, /const wifiAttempt: number = this\.wifiAttemptGeneration/);
  assert.match(liveView, /await wifiCamera\.stopLiveView\(\)/);
  assert.match(liveView, /await wifiCamera\.startLiveView\(\)/);
  assert.ok((liveView.match(/isCurrentWifiOperation/g) ?? []).length >= 6);
  assert.doesNotMatch(
    liveView,
    /this\.wifiCamera\.(?:startLiveView|stopLiveView)/,
  );

  const capture = blockStartingAt(source, 'private async capturePhoto()');
  assert.match(capture, /const camera: PtpIpCamera = this\.wifiCamera/);
  assert.match(capture, /await camera\.capture\(\)/);
  assert.ok((capture.match(/isCurrentWifiOperation/g) ?? []).length >= 2);
  assert.doesNotMatch(capture, /this\.wifiCamera\.capture\(\)/);

  const recording = blockStartingAt(
    source,
    'private async toggleVideoRecording()',
  );
  assert.match(recording, /const camera: PtpIpCamera = this\.wifiCamera/);
  assert.match(recording, /await camera\.stopMovieRecording\(\)/);
  assert.match(recording, /await camera\.startMovieRecording\(\)/);
  assert.match(recording, /this\.wifiMovieRecording = camera\.isMovieRecording/);
  assert.ok((recording.match(/isCurrentWifiOperation/g) ?? []).length >= 4);
  assert.doesNotMatch(
    recording,
    /this\.wifiCamera\.(?:startMovieRecording|stopMovieRecording|isMovieRecording)/,
  );
});

test('Harmony Wi-Fi preview drops decoded frames after its attempt loses ownership', async () => {
  const source = await read(
    'native/harmony/entry/src/main/ets/pages/Index.ets',
  );
  const preview = blockStartingAt(source, 'private async startPreviewLoop()');
  const display = blockStartingAt(source, 'private async displayJpeg(');

  assert.match(preview, /const wifiCamera: PtpIpCamera = this\.wifiCamera/);
  assert.match(preview, /const wifiAttempt: number = this\.wifiAttemptGeneration/);
  assert.match(preview, /await wifiCamera\.getLiveViewFrame\(\)/);
  assert.match(preview, /await wifiCamera\.stopLiveView\(\)/);
  assert.ok((preview.match(/isCurrentWifiOperation/g) ?? []).length >= 4);
  assert.match(
    preview,
    /await this\.displayJpeg\(jpeg,[\s\S]*generation === this\.previewGeneration[\s\S]*isCurrentWifiOperation\(wifiAttempt, wifiCamera\)/,
  );
  assert.doesNotMatch(
    preview,
    /this\.wifiCamera\.(?:getLiveViewFrame|stopLiveView)/,
  );
  assert.match(display, /ownerIsCurrent\?: \(\) => boolean/);
  assert.ok(
    (display.match(/ownerIsCurrent\(\)/g) ?? []).length >= 2,
    'decode and monitor-processing awaits must both re-check ownership',
  );
  assert.match(display, /result\.pixelMap\.release\(\)/);
  assert.match(display, /sourceMap\.release\(\)/);
});

test('Android USB connects use generations and every source switch cancels pending peers', async () => {
  const source = await read(
    'native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java',
  );
  const usbConnect = blockStartingAt(source, 'private void connectCamera()');
  const usbDisconnect = blockStartingAt(source, 'private void disconnectCamera()');
  const wifiConnect = blockStartingAt(
    source,
    'private void connectWifiCamera(String host, int port, String connectionMode)',
  );
  const localConnect = blockStartingAt(source, 'private void connectLocalCamera()');

  assert.match(source, /volatile long usbCameraConnectionGeneration/);
  assert.match(usbConnect, /connectionGeneration = \+\+usbCameraConnectionGeneration/);
  assert.ok(
    (usbConnect.match(/connectionGeneration != usbCameraConnectionGeneration/g)
      ?? []).length >= 4,
    'USB worker and UI callbacks must reject an invalidated generation',
  );
  assert.match(usbDisconnect, /usbCameraConnectionGeneration\+\+/);
  assert.match(usbDisconnect, /connecting = false/);
  assert.match(
    usbConnect,
    /wifiConnected \|\| wifiConnecting \|\| wifiReconnecting[\s\S]*disconnectWifiCamera\(\)/,
  );
  assert.match(
    usbConnect,
    /localCameraConnected \|\| localCameraConnecting[\s\S]*disconnectLocalCamera\(\)/,
  );
  assert.match(
    wifiConnect,
    /connected \|\| connecting[\s\S]*disconnectCamera\(\)/,
  );
  assert.match(
    wifiConnect,
    /localCameraConnected \|\| localCameraConnecting[\s\S]*disconnectLocalCamera\(\)/,
  );
  assert.match(localConnect, /connected \|\| connecting[\s\S]*disconnectCamera\(\)/);
  assert.match(
    localConnect,
    /wifiConnected \|\| wifiConnecting \|\| wifiReconnecting[\s\S]*disconnectWifiCamera\(\)/,
  );
});

test('Android activity destruction aborts Wi-Fi I/O without waiting on its monitor', async () => {
  const activity = await read(
    'native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java',
  );
  const camera = await read(
    'native/android/app/src/main/java/com/tauber/nikonlink/PtpIpCamera.java',
  );
  const destroy = blockStartingAt(activity, 'protected void onDestroy()');
  const abort = blockStartingAt(camera, 'void abortTransport()');

  assert.doesNotMatch(camera, /synchronized void abortTransport\(\)/);
  assert.match(abort, /pendingCommand = connectingCommandSocket/);
  assert.match(abort, /pendingEvent = connectingEventSocket/);
  assert.match(abort, /activeCommand = commandSocket/);
  assert.match(abort, /activeEvent = eventSocket/);
  assert.ok(
    destroy.indexOf('previewExecutor.shutdownNow()') <
      destroy.indexOf('wifiCamera.abortTransport()'),
    'preview submission must stop before the transport abort',
  );
  assert.ok(
    destroy.indexOf('wifiCamera.abortTransport()') <
      destroy.indexOf('cameraExecutor.submit'),
    'the UI thread must only perform the non-blocking socket abort',
  );
  assert.ok(
    destroy.indexOf('cameraExecutor.submit') <
      destroy.indexOf('wifiCamera.close()'),
    'monitor-taking cleanup must stay inside the camera executor task',
  );
});

test('protocol docs disclose the current large-packet and probe-policy boundaries', async () => {
  const protocol = await read('docs/PTPIP_PROTOCOL.md');
  assert.match(protocol, /UINT64_MAX/);
  assert.match(protocol, /单个 PTP\/IP 包限制为 \*\*64 MiB\*\*/);
  assert.match(protocol, /5s 周期 \/ 3s 超时是 ZENCHE[\s\S]*策略性偏离/);
});
