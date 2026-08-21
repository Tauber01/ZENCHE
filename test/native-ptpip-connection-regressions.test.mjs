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

test('PTP/IP heartbeat uses event-channel Probe Request/Response on all targets', async () => {
  const [apple, android, harmony, windows] = await Promise.all([
    read('native/ios/NikonLink/Connectivity/RemoteCaptureServices.swift'),
    read('native/android/app/src/main/java/com/tauber/nikonlink/PtpIpCamera.java'),
    read('native/harmony/entry/src/main/ets/camera/PtpIpCamera.ets'),
    read('native/windows/Services/PtpIpCamera.cs'),
  ]);
  const probes = [
    blockStartingAt(apple, 'func probe(timeoutMilliseconds:'),
    blockStartingAt(android, 'synchronized void probe()'),
    blockStartingAt(harmony, 'async probe(timeoutMilliseconds:'),
    blockStartingAt(windows, 'public async Task ProbeAsync('),
  ];

  for (const probe of probes) {
    assert.doesNotMatch(probe, /0x1001|0x1002/);
  }
  assert.match(probes[0], /writeEventPacket\([\s\S]*type: 13[\s\S]*probeResponseSequence/);
  assert.match(probes[1], /PACKET_PROBE_REQUEST[\s\S]*probeResponseSequence/);
  assert.match(
    probes[2],
    /sendEventPacket\([\s\S]*13,[\s\S]*new Uint8Array\(0\)[\s\S]*probeResponseSequence/,
  );
  assert.match(probes[3], /SendEventPacketAsync\(13[\s\S]*_probeResponseSequence/);
});

test('event readers answer camera probes and drain PTP/IP events', async () => {
  const [apple, android, harmony, windows] = await Promise.all([
    read('native/ios/NikonLink/Connectivity/RemoteCaptureServices.swift'),
    read('native/android/app/src/main/java/com/tauber/nikonlink/PtpIpCamera.java'),
    read('native/harmony/entry/src/main/ets/camera/PtpIpCamera.ets'),
    read('native/windows/Services/PtpIpCamera.cs'),
  ]);
  for (const source of [apple, android, harmony, windows]) {
    assert.match(source, /(?:type|Type)\s*==?=?\s*13|case 13/);
    assert.match(source, /(?:type|Type)\s*==?=?\s*14|case 14/);
  }
  assert.match(apple, /startEventReader[\s\S]*runEventReader/);
  assert.match(android, /startEventReader[\s\S]*runEventReader/);
  assert.match(harmony, /startEventReader[\s\S]*runEventReader/);
  assert.match(windows, /StartEventReader[\s\S]*RunEventReaderAsync/);
});

test('GetDeviceInfo requests have no parameters and parse the PIMA dataset layout', async () => {
  const [apple, android, harmony, windows] = await Promise.all([
    read('native/ios/NikonLink/Connectivity/RemoteCaptureServices.swift'),
    read('native/android/app/src/main/java/com/tauber/nikonlink/PtpIpCamera.java'),
    read('native/harmony/entry/src/main/ets/camera/PtpIpCamera.ets'),
    read('native/windows/Services/PtpIpCamera.cs'),
  ]);

  assert.match(
    blockStartingAt(apple, 'func detectVendor(using cameraName:'),
    /operation: 0x1001,[\s\S]*parameters: \[\]/,
  );
  assert.match(
    blockStartingAt(android, 'synchronized CameraVendor detectVendor()'),
    /commandWithData\(0x1001, transactionId\+\+, new long\[0\]\)/,
  );
  assert.match(
    blockStartingAt(harmony, 'async detectVendor()'),
    /0x1001,[\s\S]*this\.transaction\+\+,[\s\S]*\[\]/,
  );
  assert.match(
    blockStartingAt(windows, 'public async Task<CameraVendor> DetectVendorAsync('),
    /0x1001,[\s\S]*_transactionId\+\+,[\s\S]*\[\]/,
  );

  assert.match(apple, /readPTPString[\s\S]*readUInt32/);
  assert.match(apple, /utf16LittleEndian/);
  assert.match(android, /readPtpString[\s\S]*u32/);
  assert.match(android, /StandardCharsets\.UTF_16LE/);
  assert.match(harmony, /readPtpString[\s\S]*readU32/);
  assert.match(harmony, /String\.fromCharCode\(readU16/);
  assert.match(windows, /ReadPtpString[\s\S]*ReadUInt32/);
  assert.match(windows, /Encoding\.Unicode/);
});

test('PTP/IP data-out framing follows StartData(tx,length) then EndData(tx,data)', async () => {
  const [apple, android, harmony, windows] = await Promise.all([
    read('native/ios/NikonLink/Connectivity/RemoteCaptureServices.swift'),
    read('native/android/app/src/main/java/com/tauber/nikonlink/PtpIpCamera.java'),
    read('native/harmony/entry/src/main/ets/camera/PtpIpCamera.ets'),
    read('native/windows/Services/PtpIpCamera.cs'),
  ]);
  const methods = [
    blockStartingAt(apple, 'private func dataOutRequest('),
    blockStartingAt(android, 'private int sendCommandWithDataOut('),
    blockStartingAt(harmony, 'private async sendCommandWithDataOut('),
    blockStartingAt(windows, 'private async Task<ushort> SendCommandWithDataOutAsync('),
  ];

  for (const method of methods) {
    assert.doesNotMatch(method, /start(?:Payload|Data)[\s\S]{0,120}(?:UInt32\(0\)|u32\(0\)|appendU32\([^\n]*, 0\)|WriteUInt32\([^\n]*, 0\))/i);
    assert.doesNotMatch(method, /end(?:Payload|Data)[\s\S]{0,120}(?:UInt32\(0\)|u32\(0\)|appendU32\([^\n]*, 0\)|WriteUInt32\([^\n]*, 0\))/i);
  }
  assert.match(methods[0], /startPayload[\s\S]*appendLE\(current[\s\S]*appendLE\(UInt64\(data\.count\)[\s\S]*endPayload[\s\S]*appendLE\(current[\s\S]*endPayload\.append\(data\)/);
  assert.match(methods[1], /startData\.u32\(transaction\)[\s\S]*startData\.u64\(data\.length\)[\s\S]*endData\.u32\(transaction\)[\s\S]*endData\.bytes\(data\)/);
  assert.match(methods[2], /appendU32\(startData, transaction\)[\s\S]*appendU64\(startData, data\.length\)[\s\S]*appendU32\(endData, transaction\)[\s\S]*endData\.push\(data\[index\]\)/);
  assert.match(methods[3], /WriteUInt32\(startPayload, transaction\)[\s\S]*WriteUInt64\(startPayload, \(ulong\)data\.Length\)[\s\S]*WriteUInt32\(endPayload, transaction\)[\s\S]*endPayload\.Write\(data\)/);
});

test('shared PTP/IP command streams serialize complete transactions', async () => {
  const [apple, harmony, windows] = await Promise.all([
    read('native/ios/NikonLink/Connectivity/RemoteCaptureServices.swift'),
    read('native/harmony/entry/src/main/ets/camera/PtpIpCamera.ets'),
    read('native/windows/Services/PtpIpCamera.cs'),
  ]);

  assert.match(apple, /acquireCommandGate\(\) async throws -> UInt64/);
  assert.match(apple, /releaseCommandGate\(_ lease: UInt64\)/);
  for (const marker of ['private func commandRequest(', 'private func dataRequest(', 'private func dataOutRequest(']) {
    const method = blockStartingAt(apple, marker);
    assert.match(method, /let gateLease = try await acquireCommandGate\(\)/);
    assert.match(method, /defer \{ releaseCommandGate\(gateLease\) \}/);
  }

  assert.match(harmony, /class PtpIpCommandGate/);
  for (const marker of [
    'private async sendCommandWithTimeout(',
    'private async commandWithData(',
    'private async sendCommandWithDataOut(',
  ]) {
    const method = blockStartingAt(harmony, marker);
    assert.match(method, /await this\.commandGate\.acquire\(\)/);
    assert.match(method, /this\.commandGate\.release\(\)/);
  }

  assert.match(windows, /SemaphoreSlim _commandGate = new\(1, 1\)/);
  for (const marker of [
    'private async Task<ushort> SendCommandAsync(',
    'private async Task<byte[]> SendCommandWithDataAsync(',
    'private async Task<ushort> SendCommandWithDataOutAsync(',
  ]) {
    const method = blockStartingAt(windows, marker);
    assert.match(method, /await _commandGate\.WaitAsync\(token\)/);
    assert.match(method, /_commandGate\.Release\(\)/);
  }
});

test('Apple connect generations invalidate stale handshakes and clean local channels', async () => {
  const apple = await read(
    'native/ios/NikonLink/Connectivity/RemoteCaptureServices.swift');
  const connect = blockStartingAt(apple, 'func connect(host: String, port: UInt16)');
  const cleanup = blockStartingAt(apple, 'private func cleanupConnectionAttempt(');
  const invalidate = blockStartingAt(apple, 'private func invalidateSession()');

  assert.ok(
    connect.indexOf('let generation = invalidateSession()') <
      connect.indexOf('try await start(command)'),
    'connect must invalidate and capture its generation before the first await',
  );
  assert.match(connect, /let command = NWConnection/);
  assert.match(connect, /var event: NWConnection\?/);
  assert.match(connect, /connectingCommand = command/);
  assert.ok(
    (connect.match(/validateConnectionAttempt\(/g) ?? []).length >= 7,
    'every awaited handshake boundary must reject a stale generation',
  );
  assert.match(
    connect,
    /catch \{[\s\S]*cleanupConnectionAttempt\([\s\S]*command: command,[\s\S]*event: event,[\s\S]*generation: generation/,
  );
  assert.ok(
    connect.indexOf('let response = try await openSession(') <
      connect.indexOf('self.command = command'),
    'partially initialized channels must not be published before OpenSession',
  );
  assert.match(cleanup, /command\.cancel\(\)[\s\S]*event\?\.cancel\(\)/);
  assert.match(cleanup, /guard generation == sessionGeneration/);
  assert.match(cleanup, /invalidateSession\(\)/);
  assert.match(
    invalidate,
    /sessionGeneration &\+= 1[\s\S]*connectingCommand\?\.cancel\(\)[\s\S]*connectingEvent\?\.cancel\(\)/,
  );
});

test('Apple queued command waiters stay bound to their session generation', async () => {
  const apple = await read(
    'native/ios/NikonLink/Connectivity/RemoteCaptureServices.swift');
  for (const marker of [
    'private func commandRequest(',
    'private func dataRequest(',
    'private func dataOutRequest(',
  ]) {
    const method = blockStartingAt(apple, marker);
    const commandCapture = method.indexOf('guard let expectedCommand = command');
    const generationCapture = method.indexOf(
      'let expectedGeneration = sessionGeneration');
    const gate = method.indexOf('await acquireCommandGate()');
    assert.ok(commandCapture !== -1 && commandCapture < gate,
      `${marker} must capture its command before waiting`);
    assert.ok(generationCapture !== -1 && generationCapture < gate,
      `${marker} must capture its generation before waiting`);
    assert.match(
      method,
      /validateCommandSession\([\s\S]*command: expectedCommand,[\s\S]*generation: expectedGeneration/,
    );
    assert.match(method, /on: expectedCommand/);
    assert.doesNotMatch(
      method.slice(gate),
      /(?:send|receivePacket)\([^\n]*on: command\)/,
      `${marker} must never switch to the current session after waiting`,
    );
  }
});

test('Apple serializes event writes and poisons probes after command-channel failure', async () => {
  const apple = await read(
    'native/ios/NikonLink/Connectivity/RemoteCaptureServices.swift');
  const probe = blockStartingAt(apple, 'func probe(timeoutMilliseconds:');
  const reader = blockStartingAt(apple, 'private func runEventReader(');
  const writer = blockStartingAt(apple, 'private func writeEventPacket(');
  const recorder = blockStartingAt(
    apple,
    'private func recordCommandChannelFailure(',
  );
  const invalidate = blockStartingAt(apple, 'private func invalidateSession()');

  assert.ok(
    probe.indexOf('let expectedEvent = event') <
      probe.indexOf('writeEventPacket('),
    'probe must capture its event channel before waiting for the write gate',
  );
  assert.ok(
    probe.indexOf('let expectedGeneration = sessionGeneration') <
      probe.indexOf('writeEventPacket('),
    'probe must capture its generation before waiting for the write gate',
  );
  assert.match(
    reader,
    /let expectedEvent = connection[\s\S]*let expectedCommand = commandConnection[\s\S]*let expectedGeneration = expectedSessionGeneration[\s\S]*writeEventPacket\([\s\S]*command: expectedCommand/,
  );
  assert.doesNotMatch(probe, /await send\(/);
  assert.doesNotMatch(reader, /await send\(/);
  assert.match(writer, /await acquireEventWriteGate\(\)/);
  assert.match(writer, /if let expectedCommand[\s\S]*validateEventReaderSession\(/);
  assert.match(writer, /validateEventSession\(/);
  assert.match(writer, /on: expectedEvent/);
  assert.match(probe, /if let commandChannelFailure/);
  assert.match(recorder, /case \.connectionFailed[\s\S]*case \.invalidPacket/);
  assert.match(recorder, /case \.invalidEndpoint, \.notConnected:[\s\S]*break/);
  assert.match(
    recorder,
    /case \.rejected\(let code\):[\s\S]*isSessionFatalResponse\(code\)/,
  );
  assert.doesNotMatch(recorder, /512 MB 单文件传输上限/);
  assert.match(
    recorder,
    /if transactionStarted \{[\s\S]*commandChannelFailure = error\.localizedDescription/,
  );
  assert.match(invalidate, /commandChannelFailure = nil/);
  for (const marker of [
    'private func commandRequest(',
    'private func dataRequest(',
    'private func dataOutRequest(',
  ]) {
    assert.match(
      blockStartingAt(apple, marker),
      /recordCommandChannelFailure\(/,
    );
  }
});

test('Apple data-in accepts unknown StartData length and verifies known totals', async () => {
  const apple = await read(
    'native/ios/NikonLink/Connectivity/RemoteCaptureServices.swift');
  const dataIn = blockStartingAt(apple, 'private func dataRequest(');

  assert.match(dataIn, /let lengthIsKnown = announcedLength != UInt64\.max/);
  assert.match(dataIn, /!lengthIsKnown \|\| announcedLength <= maximumObjectBytes/);
  assert.match(dataIn, /data\.count <= Int\(maximumObjectBytes\)/);
  assert.match(
    dataIn,
    /!lengthIsKnown \|\| UInt64\(data\.count\) == announcedLength/,
  );
});

test('Apple binds initial and reconnect cleanup to the owning attempt', async () => {
  const apple = await read(
    'native/ios/NikonLink/Connectivity/RemoteCaptureServices.swift');
  const actorConnect = blockStartingAt(
    apple,
    'func connect(host: String, port: UInt16)',
  );
  const ownership = blockStartingAt(
    apple,
    'private func withSessionOwnership<T>(',
  );
  const initial = blockStartingAt(apple, 'func connect()');
  const reconnect = blockStartingAt(apple, 'private func scheduleReconnect()');

  assert.match(
    ownership,
    /PTPIPSessionOwnership\.\$attempt\.withValue\(attempt\)/,
  );
  assert.match(
    actorConnect,
    /guard let ownerAttempt = PTPIPSessionOwnership\.attempt/,
  );
  assert.match(actorConnect, /guard ownerAttempt > highestOwnerAttempt/);
  assert.ok(
    actorConnect.indexOf('highestOwnerAttempt = ownerAttempt') <
      actorConnect.indexOf('let generation = invalidateSession()'),
    'a stale attempt must be rejected before it can invalidate the active session',
  );

  assert.match(initial, /let attempt = beginSessionAttempt\(\)/);
  assert.match(initial, /await self\.withSessionOwnership\(attempt\)/);
  assert.ok(
    (initial.match(/self\.isCurrentSessionAttempt\(attempt\)/g) ?? []).length >= 4,
    'initial connection must re-check ownership after every suspension boundary',
  );
  assert.match(
    initial,
    /let name = try await self\.session\.connect\([\s\S]*disconnect\(ifOwnedBy: attempt\)[\s\S]*let vendor = try await self\.session\.detectVendor\(using: name\)[\s\S]*disconnect\(ifOwnedBy: attempt\)/,
  );
  assert.ok(
    reconnect.indexOf('await self.session.disconnect(ifOwnedBy: previousOwner)') <
      reconnect.indexOf('try await Task.sleep('),
    'reconnecting must close only the previously owned session before backoff',
  );
  assert.match(reconnect, /let sessionAttempt = beginSessionAttempt\(\)/);
  assert.match(
    reconnect,
    /await self\.withSessionOwnership\(sessionAttempt\)/,
  );
  assert.ok(
    (reconnect.match(/self\.isCurrentSessionAttempt\(sessionAttempt\)/g) ?? [])
      .length >= 5,
    'reconnect must re-check ownership after every suspension boundary',
  );
  assert.match(
    reconnect,
    /let name = try await self\.session\.connect\([\s\S]*disconnect\(ifOwnedBy: sessionAttempt\)[\s\S]*let vendor = try await self\.session\.detectVendor\(using: name\)[\s\S]*disconnect\(ifOwnedBy: sessionAttempt\)/,
  );
});

test('Apple publishes ready only after command/event health and attempt recheck', async () => {
  const apple = await read(
    'native/ios/NikonLink/Connectivity/RemoteCaptureServices.swift');
  const health = blockStartingAt(
    apple,
    'func assertHealthy(timeoutMilliseconds:',
  );
  const service = blockStartingAt(apple, 'final class WifiCameraService');
  const initial = blockStartingAt(service, 'func connect()');
  const reconnect = blockStartingAt(service, 'private func scheduleReconnect()');

  assert.equal(
    (health.match(/validateCommandSession\(/g) ?? []).length,
    2,
    'health barrier must validate the command channel before and after probing',
  );
  assert.match(health, /try await probe\(timeoutMilliseconds: timeoutMilliseconds\)/);

  for (const [label, flow] of [
    ['initial', initial],
    ['reconnect', reconnect],
  ]) {
    const detect = flow.indexOf('session.detectVendor(using: name)');
    const barrier = flow.indexOf('session.assertHealthy(');
    const ready = flow.indexOf('self.state = .ready');
    assert.ok(
      detect !== -1 && detect < barrier && barrier < ready,
      `${label} must pass the dual-channel barrier before publishing ready`,
    );
    assert.match(
      flow.slice(barrier, ready),
      /isCurrentSessionAttempt\((?:attempt|sessionAttempt)\)/,
      `${label} must re-check attempt ownership after the health await`,
    );
  }
});

test('Apple iOS path monitor is Wi-Fi scoped and bound to its session attempt', async () => {
  const apple = await read(
    'native/ios/NikonLink/Connectivity/RemoteCaptureServices.swift');
  const monitor = blockStartingAt(apple, 'private func startPathMonitor()');

  assert.match(
    monitor,
    /#if os\(iOS\)[\s\S]*NWPathMonitor\(requiredInterfaceType: \.wifi\)[\s\S]*#else[\s\S]*NWPathMonitor\(\)/,
  );
  assert.ok(
    monitor.indexOf('let monitoredAttempt = activeSessionAttempt') <
      monitor.indexOf('monitor.pathUpdateHandler'),
    'path callback must capture the session attempt before registration',
  );
  assert.match(monitor, /isCurrentSessionAttempt\(monitoredAttempt\)/);
});

test('Apple deadlines retire exact sessions and owned cleanup stays ordered', async () => {
  const apple = await read(
    'native/ios/NikonLink/Connectivity/RemoteCaptureServices.swift');
  const service = blockStartingAt(apple, 'final class WifiCameraService');
  const initial = blockStartingAt(service, 'func connect()');
  const disconnect = blockStartingAt(service, 'func disconnect()');
  const capture = blockStartingAt(service, 'func capture()');
  const probe = blockStartingAt(apple, 'func probe(timeoutMilliseconds:');
  const acquire = blockStartingAt(apple, 'private func acquireCommandGate()');
  const expire = blockStartingAt(
    apple,
    'private func expireCommandTransaction(',
  );
  const parseAck = blockStartingAt(
    apple,
    'private func parseInitCommandAcknowledgment(',
  );

  assert.match(apple, /activeCommandDeadlineToken/);
  assert.match(expire, /activeCommandDeadlineToken == expectedToken/);
  assert.match(expire, /currentCommand === expectedCommand/);
  assert.match(expire, /expectedCommand\.cancel\(\)/);
  assert.match(acquire, /catch \{[\s\S]*releaseCommandGate\(epoch\)[\s\S]*throw error/);

  assert.ok(
    probe.indexOf('startEventDeadline(') <
      probe.indexOf('try await writeEventPacket('),
  );
  assert.ok(
    probe.indexOf('finishEventDeadline(writeDeadline)') <
      probe.indexOf('responseDeadlineNanoseconds'),
    'event-write watchdog must finish before response misses are counted',
  );

  assert.ok(
    initial.indexOf('await self.session.disconnect(ifOwnedBy: attempt)') <
      initial.indexOf('self.activeSessionAttempt = nil'),
    'initial vendor/transport failure must close its published session first',
  );
  const frameDone = disconnect.indexOf('await liveViewTaskToFinish?.value');
  const stopMovie = disconnect.indexOf('session.stopMovieRecording(');
  const endLiveView = disconnect.indexOf('session.endLiveView(');
  const closeSession = disconnect.indexOf('session.disconnect(ifOwnedBy: ownedAttempt)');
  assert.ok(
    frameDone < stopMovie && stopMovie < endLiveView && endLiveView < closeSession,
    'manual disconnect must wait for frames, stop movie/live view, then close',
  );
  assert.match(capture, /isSessionFatalResponse\(code\)[\s\S]*enterReconnecting\(\)/);

  assert.match(parseAck, /data\.count >= 34/);
  assert.match(parseAck, /terminatorOffset \+ 6 == data\.count/);
  assert.match(parseAck, /0x0001_0000/);
  assert.match(parseAck, /encoding: \.utf16LittleEndian/);
});

test('Apple only downgrades compatible discovery responses', async () => {
  const apple = await read(
    'native/ios/NikonLink/Connectivity/RemoteCaptureServices.swift');
  const detect = blockStartingAt(apple, 'func detectVendor(using cameraName:');
  const failure = blockStartingAt(
    apple,
    'private func recordCommandChannelFailure(',
  );

  assert.match(detect, /allowsVendorDetectionFallback\(code\)/);
  assert.match(apple, /case 0x2005,[\s\S]*0x200A,[\s\S]*0x2019/);
  assert.match(apple, /case 0x2003,[\s\S]*0x2004,[\s\S]*0x201E/);
  assert.match(
    failure,
    /case \.rejected\(let code\):[\s\S]*isSessionFatalResponse\(code\)[\s\S]*commandChannelFailure/,
  );
});

test('Harmony connect generations invalidate stale handshakes and close local channels', async () => {
  const harmony = await read(
    'native/harmony/entry/src/main/ets/camera/PtpIpCamera.ets');
  const connect = blockStartingAt(
    harmony,
    'netHandle?: connection.NetHandle\n  ): Promise<string>',
  );
  const disconnect = blockStartingAt(harmony, 'async disconnect(): Promise<void>');
  const cleanup = blockStartingAt(harmony, 'private async cleanupConnectAttempt(');

  assert.ok(
    connect.indexOf('const generation: number = ++this.connectionGeneration') <
      connect.indexOf('await this.closePublishedConnection()'),
    'connect must claim a generation before awaiting old-session cleanup',
  );
  assert.ok(
    (connect.match(/ensureConnectionGeneration\(generation\)/g) ?? []).length >= 7,
    'each awaited handshake boundary must reject a stale generation',
  );
  assert.match(connect, /let event: PtpIpChannel \| undefined/);
  assert.match(
    connect,
    /catch \(error\)[\s\S]*await this\.cleanupConnectAttempt\(generation, command, event\)/,
  );
  assert.ok(
    disconnect.indexOf('this.connectionGeneration++') <
      disconnect.indexOf('await this.closePublishedConnection()'),
    'disconnect must invalidate in-flight handshakes before closing channels',
  );
  assert.match(
    cleanup,
    /try \{[\s\S]*await command\.close\(\)[\s\S]*finally \{[\s\S]*await event\.close\(\)/,
  );
});

test('Harmony disconnect aborts pending handshakes and remote command closure poisons only its owner', async () => {
  const harmony = await read(
    'native/harmony/entry/src/main/ets/camera/PtpIpCamera.ets');
  const channel = blockStartingAt(harmony, 'class PtpIpChannel');
  const connect = blockStartingAt(
    harmony,
    'netHandle?: connection.NetHandle\n  ): Promise<string>',
  );
  const close = blockStartingAt(harmony, 'private async closePublishedConnection(');
  const markFailed = blockStartingAt(
    harmony,
    'private markCommandChannelFailed(',
  );

  assert.match(channel, /tcp\.on\('close'[\s\S]*this\.fail\(/);
  assert.match(channel, /tcp\.on\('error'[\s\S]*this\.fail\(/);
  assert.match(channel, /this\.closed = true[\s\S]*handler\(error\)/);
  assert.match(
    connect,
    /command\.setFailureHandler\([\s\S]*this\.markCommandChannelFailed\(command, generation, error\)/,
  );
  assert.ok(
    connect.indexOf('this.pendingCommand = command') <
      connect.indexOf('await command.connect'),
    'command socket must be published as pending before the first connect await',
  );
  assert.ok(
    connect.indexOf('this.pendingEvent = event') <
      connect.indexOf('await event.connect'),
    'event socket must be published as pending before its connect await',
  );
  assert.match(close, /const pendingCommand:[\s\S]*this\.pendingCommand = undefined/);
  assert.match(close, /const pendingEvent:[\s\S]*this\.pendingEvent = undefined/);
  assert.match(close, /pendingCommand\.close\(\)/);
  assert.match(close, /pendingEvent\.close\(\)/);
  assert.match(markFailed, /this\.command === expectedCommand/);
  assert.match(markFailed, /this\.connectionGeneration === expectedGeneration/);
});

test('Harmony Canon live-view fallback swallows only explicit DeviceBusy', async () => {
  const harmony = await read(
    'native/harmony/entry/src/main/ets/camera/PtpIpCamera.ets');
  const canon = blockStartingAt(harmony, 'private async canonOpenLiveView()');
  const busy = blockStartingAt(harmony, 'private static isDeviceBusyError(');

  assert.match(busy, /error instanceof PtpIpResponseError/);
  assert.match(busy, /RESPONSE_DEVICE_BUSY/);
  assert.ok(
    (canon.match(/isDeviceBusyError/g) ?? []).length >= 4,
    'every Canon read/write fallback must classify DeviceBusy explicitly',
  );
  assert.ok(
    (canon.match(/throw error instanceof Error|throw readError instanceof Error|throw busy instanceof Error/g)
      ?? []).length >= 4,
    'transport, fatal-session, and unsupported errors must escape',
  );
  assert.doesNotMatch(canon, /catch \([^)]*\) \{\s*\/\/[^}]*\}/);
});

test('Harmony queued command waiters stay bound to their channel generation', async () => {
  const harmony = await read(
    'native/harmony/entry/src/main/ets/camera/PtpIpCamera.ets');
  for (const marker of [
    'private async sendCommandWithTimeout(',
    'private async commandWithData(',
    'private async sendCommandWithDataOut(',
  ]) {
    const method = blockStartingAt(harmony, marker);
    assert.ok(
      method.indexOf('const expectedGeneration: number = this.connectionGeneration') <
        method.indexOf('await this.commandGate.acquire()'),
      `${marker} must capture the generation before waiting`,
    );
    assert.match(
      method,
      /this\.ensureCommandSession\(expectedCommand, expectedGeneration\)/,
    );
  }

  const ensureSession = blockStartingAt(
    harmony,
    'private ensureCommandSession(',
  );
  assert.match(ensureSession, /this\.command !== expectedCommand/);
  assert.match(
    ensureSession,
    /this\.connectionGeneration !== expectedGeneration/,
  );
});

test('Harmony serializes all post-handshake event-channel writes', async () => {
  const harmony = await read(
    'native/harmony/entry/src/main/ets/camera/PtpIpCamera.ets');
  const probe = blockStartingAt(harmony, 'async probe(timeoutMilliseconds:');
  const reader = blockStartingAt(harmony, 'private async runEventReader(');
  const writer = blockStartingAt(harmony, 'private async sendEventPacket(');

  assert.match(probe, /await this\.sendEventPacket\([\s\S]*13/);
  assert.match(reader, /await this\.sendEventPacket\([\s\S]*14/);
  assert.doesNotMatch(probe, /event\.send\(/);
  assert.doesNotMatch(reader, /event\.send\(/);
  assert.match(writer, /await this\.eventWriterGate\.acquire\(\)/);
  assert.match(writer, /await event\.send\(type, payload\)/);
  assert.match(writer, /this\.eventWriterGate\.release\(\)/);
});

test('Harmony accepts unknown StartData lengths but enforces cumulative and known lengths', async () => {
  const harmony = await read(
    'native/harmony/entry/src/main/ets/camera/PtpIpCamera.ets');
  const dataIn = blockStartingAt(harmony, 'private async commandWithData(');

  assert.match(
    dataIn,
    /totalLengthLow === 0xffffffff[\s\S]*totalLengthHigh === 0xffffffff/,
  );
  assert.match(dataIn, /if \(!unknownLength && totalLength > 512 \* 1024 \* 1024\)/);
  assert.match(dataIn, /if \(received > 512 \* 1024 \* 1024\)/);
  assert.match(dataIn, /if \(!unknownLength && received > totalLength\)/);
  assert.match(dataIn, /if \(!unknownLength && received !== totalLength\)/);
  assert.match(harmony, /length > 64 \* 1024 \* 1024/);
});

test('Harmony command transport failures poison probes without treating PTP rejection as link loss', async () => {
  const harmony = await read(
    'native/harmony/entry/src/main/ets/camera/PtpIpCamera.ets');
  const probe = blockStartingAt(harmony, 'async probe(timeoutMilliseconds:');
  const close = blockStartingAt(harmony, 'private async closePublishedConnection(');
  const cleanup = blockStartingAt(harmony, 'private async cleanupConnectAttempt(');

  assert.match(probe, /this\.commandChannelFailure !== undefined/);
  assert.match(close, /this\.commandChannelFailure = undefined/);
  assert.match(cleanup, /this\.commandChannelFailure = undefined/);
  for (const marker of [
    'private async sendCommandWithTimeout(',
    'private async commandWithData(',
    'private async sendCommandWithDataOut(',
  ]) {
    const method = blockStartingAt(harmony, marker);
    assert.match(
      method,
      /if \(error instanceof PtpIpResponseError\) \{[\s\S]*throw error;[\s\S]*\}[\s\S]*this\.markCommandChannelFailed/,
    );
    assert.match(
      method,
      /this\.markCommandChannelFailed\([\s\S]*expectedCommand,[\s\S]*expectedGeneration/,
    );
  }
  assert.match(
    harmony,
    /function rejected\(response: number\): Error \{[\s\S]*return new PtpIpResponseError\(response\)/,
  );
});

test('Harmony cancelled initial and reconnect attempts close returned sessions', async () => {
  const index = await read(
    'native/harmony/entry/src/main/ets/pages/Index.ets');
  const initial = blockStartingAt(index, 'private async connectWifiCamera()');
  const reconnect = blockStartingAt(index, 'private async attemptWifiReconnect(');
  const cleanup = blockStartingAt(
    index,
    'private async discardCancelledWifiConnection(',
  );
  const authCleanup = blockStartingAt(
    index,
    'private async closeAuthSensitiveState()',
  );

  assert.match(
    initial,
    /await camera\.connect\([\s\S]*this\.wifiManualDisconnect \|\| !this\.wifiConnecting \|\|[\s\S]*this\.wifiReconnecting[\s\S]*await this\.discardCancelledWifiConnection\(camera, attempt\)/,
  );
  assert.match(
    reconnect,
    /await camera\.connect\([\s\S]*!this\.wifiReconnecting \|\| this\.wifiManualDisconnect \|\|[\s\S]*!this\.wifiConnecting[\s\S]*await this\.discardCancelledWifiConnection\(camera, attempt\)/,
  );
  assert.match(
    initial,
    /await this\.refreshWifiParametersFor\(camera, attempt\);[\s\S]*camera\.assertHealthy\(\);[\s\S]*this\.wifiManualDisconnect \|\| !this\.wifiConnecting \|\|[\s\S]*this\.wifiReconnecting[\s\S]*await this\.discardCancelledWifiConnection\(camera, attempt\)[\s\S]*this\.wifiConnected = true/,
  );
  assert.match(
    reconnect,
    /await this\.refreshWifiParametersFor\(camera, attempt\);[\s\S]*camera\.assertHealthy\(\);[\s\S]*!this\.wifiReconnecting \|\| this\.wifiManualDisconnect \|\|[\s\S]*!this\.wifiConnecting[\s\S]*await this\.discardCancelledWifiConnection\(camera, attempt\)[\s\S]*this\.wifiReconnecting = false[\s\S]*this\.wifiConnected = true/,
  );
  assert.match(cleanup, /await camera\.disconnect\(\)/);
  assert.match(cleanup, /finally \{[\s\S]*this\.wifiConnecting = false/);
  const authCancellationBoundary = authCleanup.indexOf(
    'this.stopWifiHeartbeat()',
  );
  const authWifiDisconnect = authCleanup.indexOf(
    'await this.wifiCamera.disconnect()',
  );
  assert.notEqual(authCancellationBoundary, -1);
  assert.notEqual(authWifiDisconnect, -1);
  for (const cancellation of [
    'this.wifiManualDisconnect = true',
    'this.wifiReconnecting = false',
    'this.wifiConnecting = false',
  ]) {
    const cancellationIndex = authCleanup.indexOf(cancellation);
    assert.notEqual(cancellationIndex, -1, `missing ${cancellation}`);
    assert.ok(
      cancellationIndex < authCancellationBoundary &&
        cancellationIndex < authWifiDisconnect,
      `${cancellation} must precede auth cleanup timers and Wi-Fi disconnect`,
    );
  }
});

test('operation responses are matched to their transaction IDs', async () => {
  const [apple, android, harmony, windows] = await Promise.all([
    read('native/ios/NikonLink/Connectivity/RemoteCaptureServices.swift'),
    read('native/android/app/src/main/java/com/tauber/nikonlink/PtpIpCamera.java'),
    read('native/harmony/entry/src/main/ets/camera/PtpIpCamera.ets'),
    read('native/windows/Services/PtpIpCamera.cs'),
  ]);
  assert.ok(
    (apple.match(/readUInt32\(response\.data, at: 10\)/g) ?? []).length >= 3,
  );
  assert.ok((android.match(/u32\(response\.data, 10\)/g) ?? []).length >= 3);
  assert.ok(
    (harmony.match(/readU32\(response\.data, 10\)/g) ?? []).length >= 3,
  );
  assert.ok(
    (windows.match(/ReadUInt32\(response\.Data, 10\)/g) ?? []).length >= 3,
  );
});

test('Harmony SetDevicePropValue carries the property code', async () => {
  const harmony = await read(
    'native/harmony/entry/src/main/ets/camera/PtpIpCamera.ets');
  const writeProperty = blockStartingAt(harmony, 'async writeProperty(');
  assert.match(
    writeProperty,
    /SET_DEVICE_PROP_VALUE,[\s\S]*this\.transaction\+\+,[\s\S]*\[property\]/,
  );
});

test('Android and Harmony declare permissions required by network-loss monitors', async () => {
  const [androidManifest, harmonyModule] = await Promise.all([
    read('native/android/app/src/main/AndroidManifest.xml'),
    read('native/harmony/entry/src/main/module.json5'),
  ]);
  assert.match(androidManifest, /android\.permission\.ACCESS_NETWORK_STATE/);
  assert.match(harmonyModule, /ohos\.permission\.GET_NETWORK_INFO/);
});

test('Windows reconnect attempts are bounded and stay reconnecting until restoration succeeds', async () => {
  const window = await read('native/windows/MainWindow.xaml.cs');
  const reconnect = blockStartingAt(window, 'private async Task AttemptWifiReconnectAsync(');
  assert.match(reconnect, /CreateLinkedTokenSource\(token\)/);
  assert.match(reconnect, /CancelAfter\(TimeSpan\.FromSeconds\(12\)\)/);
  assert.match(
    reconnect,
    /ConnectWithOwnershipAsync\(\s*_wifiHost,\s*_wifiPort,\s*attemptToken\)/,
  );
  assert.match(reconnect, /ownedSessionGeneration = connection\.SessionGeneration/);
  assert.match(reconnect, /DetectVendorAsync\(attemptToken\)/);
  assert.match(reconnect, /RefreshWifiParametersAsync\(attemptToken\)/);
  assert.ok(
    (reconnect.match(/EnsureWifiConnectionAttemptCurrent\(/g) ?? []).length >= 5,
    'every restore boundary must reject a superseded reconnect attempt',
  );
  assert.doesNotMatch(
    reconnect,
    /_wifiCamera\.DisconnectAsync\(\)/,
    'stale reconnect cleanup must not tear down an unowned session',
  );
  assert.ok(
    reconnect.indexOf('_wifiReconnecting = false') >
      reconnect.indexOf('RefreshWifiParametersAsync(attemptToken)'),
    'reconnecting must remain true until session restoration completes',
  );

  const heartbeat = blockStartingAt(
    window,
    'private async void WifiHeartbeatTimer_Tick(',
  );
  assert.match(heartbeat, /ref _wifiConnectionGeneration/);
  assert.match(heartbeat, /ref _wifiOwnedSessionGeneration/);
  assert.ok(
    heartbeat.lastIndexOf('IsPublishedWifiSessionCurrent(') >
      heartbeat.indexOf('await _wifiCamera.ProbeAsync()'),
    'a stale heartbeat result must not mutate the replacement session',
  );

  const transition = blockStartingAt(
    window,
    'private async Task EnterWifiReconnectingAsync(',
  );
  assert.match(transition, /transitionGeneration = BeginWifiConnectionAttempt\(\)/);
  assert.match(
    transition,
    /DisconnectIfOwnedAsync\(\s*ownedSessionGeneration\)/,
  );
  assert.doesNotMatch(transition, /_wifiCamera\.DisconnectAsync\(\)/);
});

test('iOS auto live view stays vendor-gated: Sony keeps the connection without Nikon 0x9201', async () => {
  const apple = await read(
    'native/ios/NikonLink/Connectivity/RemoteCaptureServices.swift');
  const start = blockStartingAt(apple, 'func startLiveViewIfNeeded()');
  const initial = blockStartingAt(apple, 'func connect()');
  const reconnect = blockStartingAt(apple, 'private func scheduleReconnect()');

  // 门控：仅已实现的 Nikon/Canon 自动启动/恢复取景；Sony 永不进入 Nikon
  // 0x9201 取景路径，保持连接但取景关闭并给出诚实状态。
  assert.match(
    start,
    /guard vendor == \.nikon \|\| vendor == \.canon else \{[\s\S]*if vendor == \.sony \{[\s\S]*liveViewStatus = "已连相机暂不支持 PTP\/IP 实时取景"[\s\S]*return/,
    'startLiveViewIfNeeded must gate on Nikon/Canon and report Sony honestly',
  );
  assert.ok(
    (start.match(/session\.startLiveView\(vendor: vendor\)/g) ?? []).length === 1,
    'the live-view task body must remain the single vendor-gated entry',
  );
  assert.doesNotMatch(start, /startLiveView\(vendor: \.sony\)/);

  // 连接/重连成功路径仍调用同一门控入口：Nikon/Canon 行为保留。
  for (const flow of [initial, reconnect]) {
    assert.match(
      flow,
      /supportsMovieRecording =\s*vendor == \.nikon \|\| vendor == \.canon/,
    );
    assert.match(flow, /startLiveViewIfNeeded\(\)/);
    assert.match(flow, /if vendor != \.unknown \{/);
    assert.match(flow, /self\.refreshParameters\(\)/);
  }
});

test('Windows command transactions use a 12s idle timeout reset on every I/O', async () => {
  const windows = await read('native/windows/Services/PtpIpCamera.cs');
  const create = blockStartingAt(
    windows,
    'private static CancellationTokenSource CreateCommandDeadline(',
  );
  const reset = blockStartingAt(
    windows,
    'private static void ResetCommandDeadline(CancellationTokenSource deadline)',
  );

  // 单一常量 + 单一帮助函数：三处命令入口共用，避免语义漂移。
  assert.match(
    windows,
    /public const int CommandTransactionTimeoutMilliseconds = 12000/,
  );
  assert.match(
    create,
    /CancellationTokenSource\.CreateLinkedTokenSource\(\s*cancellationToken\)/,
  );
  assert.match(create, /ResetCommandDeadline\(deadline\)/);
  assert.match(
    reset,
    /deadline\.CancelAfter\([\s\S]*CommandTransactionTimeoutMilliseconds\)/,
  );

  // 空闲超时语义（与 Android setSoTimeout(12000) 一致）：每个成功收/发后
  // 重置计时，持续传输（如 DownloadStorageObject 大视频）不受总时长限制。
  const ioSites = {
    'private async Task<ushort> SendCommandAsync(': 2,
    'private async Task<byte[]> SendCommandWithDataAsync(': 4,
    'private async Task<ushort> SendCommandWithDataOutAsync(': 4,
  };
  for (const [marker, expected] of Object.entries(ioSites)) {
    const method = blockStartingAt(windows, marker);
    assert.match(method, /using var deadline = CreateCommandDeadline\(cancellationToken\)/);
    assert.match(method, /await _commandGate\.WaitAsync\(token\)/);
    const resets = (method.match(/ResetCommandDeadline\(deadline\)/g) ?? []).length;
    assert.equal(
      resets,
      expected,
      `${marker} must reset the idle timer after every successful I/O`,
    );
    // 大对象数据包循环：每包成功接收都重置，卡死读才会在最后进展后 12s 退休。
    if (marker.includes('SendCommandWithDataAsync')) {
      assert.match(
        method,
        /var packet = await ReceivePacketAsync\(stream, token\);[\s\S]*ResetCommandDeadline\(deadline\)/,
        'the data-in loop must refresh the idle timer per packet',
      );
    }
  }

  // 到期退休 exact captured session 并置 command-channel failure；用户取消
  // 保留 OperationCanceled 语义（不吞取消）；旧事务不能关闭新 generation。
  for (const marker of [
    'private async Task<ushort> SendCommandAsync(',
    'private async Task<byte[]> SendCommandWithDataAsync(',
    'private async Task<ushort> SendCommandWithDataOutAsync(',
  ]) {
    const method = blockStartingAt(windows, marker);
    assert.match(
      method,
      /catch \(OperationCanceledException error\) when \(transactionStarted\)[\s\S]*if \(cancellationToken\.IsCancellationRequested\)[\s\S]*RetireCommandSession\(stream, sessionGeneration, error\)[\s\S]*throw;[\s\S]*var timeout = new TimeoutException\([\s\S]*RetireCommandSession\(stream, sessionGeneration, timeout\)[\s\S]*throw timeout/,
      `${marker} must retire the exact captured session on idle timeout and preserve user cancellation`,
    );
    assert.match(
      method,
      /catch \(OperationCanceledException error\)[\s\S]*when \(!cancellationToken\.IsCancellationRequested\)[\s\S]*throw new TimeoutException\("PTP\/IP 命令事务超时", error\)/,
      `${marker} must surface pre-transaction deadline expiry without retiring`,
    );
  }

  // 退休本身只作用于 exact captured stream + generation（新会话不受影响）。
  assert.match(
    blockStartingAt(windows, 'private void RetireCommandSession('),
    /if \(!ReferenceEquals\(_commandStream, expectedStream\) \|\|[\s\S]*Volatile\.Read\(ref _sessionGeneration\) != expectedGeneration\)[\s\S]*return;/,
  );
  assert.match(
    blockStartingAt(windows, 'private void RetireCommandSession('),
    /_commandChannelFailure \?\?= error/,
  );
});
