import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const root = new URL('../', import.meta.url);
const read = async (path) => readFile(new URL(path, root), 'utf8');

const IOS_REMOTE = 'native/ios/NikonLink/Connectivity/RemoteCaptureServices.swift';
const IOS_MODEL = 'native/ios/NikonLink/Models/AppModel.swift';
const IOS_ROOT = 'native/ios/NikonLink/Views/RootView.swift';
const MAC_HTTP = 'native/macos/Sources/NikonLink/WirelessHTTPServer.swift';
const MAC_TRANSFER = 'native/macos/Sources/NikonLink/WirelessTransferServer.swift';
const MAC_MAIN = 'native/macos/Sources/NikonLink/main.swift';
const ANDROID = 'native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java';
const HARMONY = 'native/harmony/entry/src/main/ets/pages/Index.ets';
const WINDOWS_XAML = 'native/windows/MainWindow.xaml';
const WINDOWS_CODE = 'native/windows/MainWindow.xaml.cs';

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

test('W14 iOS bridge is local-network-only and does not persist its session code', async () => {
  const source = await read(IOS_REMOTE);
  assert.match(source, /URLSessionConfiguration\.ephemeral/);
  assert.match(source, /Self\.isPrivateLANHost\(host\)/);
  for (const range of ['10.', '192.168.', '169.254.', '172']) {
    assert.ok(source.includes(range), `LAN allow-list should include ${range}`);
  }
  assert.match(source, /value == "localhost" \|\| value\.hasSuffix\("\.local"\)/);
  assert.match(source, /pairingCode[\s\S]{0,120}count == 12/);
  assert.match(source, /forHTTPHeaderField: "X-Zenche-Bridge-Token"/);
  assert.doesNotMatch(source, /UserDefaults[^\n]*pairingCode/);
});

test('W14 macOS bridge requires both Basic Auth and the per-launch session token', async () => {
  const http = await read(MAC_HTTP);
  const transfer = await read(MAC_TRANSFER);
  assert.match(http, /request\.headers\["authorization"\] == Self\.authorization/);
  assert.match(http, /request\.headers\["x-zenche-bridge-token"\] == bridgeToken/);
  assert.match(transfer, /UUID\(\)\.uuidString[\s\S]{0,120}prefix\(12\)/);
  assert.doesNotMatch(transfer, /UserDefaults[\s\S]{0,80}bridgeToken/);
});

test('W14 bridge exposes status, JPEG, capture and monitor routes with bounded client reads', async () => {
  const http = await read(MAC_HTTP);
  const remote = await read(IOS_REMOTE);
  for (const route of ['status', 'live.jpg', 'capture', 'monitor']) {
    assert.ok(http.includes(`/sdk-bridge/${route}`), `macOS bridge route missing: ${route}`);
    assert.ok(remote.includes(route), `iOS bridge client route missing: ${route}`);
  }
  assert.match(http, /"Content-Type": "image\/jpeg"/);
  assert.match(remote, /limit: 12 \* 1024 \* 1024/);
  assert.match(remote, /limit: 1024 \* 1024/);
  assert.match(remote, /hasPrefix\(expectedContentType\)/);
});

test('W14 vendor truth: only Sony is marked official; Nikon remains explicitly PTP-compatible', async () => {
  const mac = await read(MAC_MAIN);
  const ios = await read(IOS_REMOTE);
  const project = await read('native/ios/NikonLink.xcodeproj/project.pbxproj');
  assert.match(mac, /backend = "sony-camera-remote-sdk"\s*\n\s*official = true/);
  assert.match(mac, /\? "nikon-ptp-compatible"\s*\n\s*: "usb-ptp-compatible"/);
  assert.match(ios, /status\.officialSDK, status\.backend == "sony-camera-remote-sdk"/);
  assert.match(ios, /status\.backend == "nikon-ptp-compatible"/);
  assert.doesNotMatch(project, /Cr_Core|CameraRemote_SDK|NkPTPDriver|Royalmile/);
});

test('W14 iOS bridge joins capture and logout cleanup without replacing local capture', async () => {
  const model = await read(IOS_MODEL);
  assert.match(model, /if sdkBridge\.isConnected \{[\s\S]{0,220}sdkBridge\.capture\(\)/);
  assert.match(model, /else if camera\.state == \.ready[\s\S]{0,180}camera\.capturePhoto\(\)/);
  assert.match(model, /func disconnectAllCameras\(\)[\s\S]{0,220}sdkBridge\.disconnect\(\)/);
  assert.match(model, /func setLiveMonitoringEnabled\(_ enabled: Bool\)[\s\S]{0,450}sdkBridge\.setMonitoring\(enabled\)/);
});

test('W14 all five capture surfaces include an accessible live-monitoring switch', async () => {
  const [ios, mac, android, harmony, xaml, windows] = await Promise.all([
    read(IOS_ROOT), read(MAC_MAIN), read(ANDROID), read(HARMONY),
    read(WINDOWS_XAML), read(WINDOWS_CODE)
  ]);
  assert.match(ios, /ControlLiveMonitoringToggle\(\)/);
  assert.match(ios, /\.accessibilityLabel\(Text\("实时监看"\)\)/);
  assert.match(mac, /MacLiveMonitoringToggle\(model: model\)/);
  assert.match(mac, /\.accessibilityLabel\("实时监看"\)/);
  assert.match(android, /buildLiveMonitoringSwitch\(\)/);
  assert.match(android, /setContentDescription\(tr\("实时监看"\)\)/);
  assert.match(harmony, /this\.LiveMonitoringToggle\(\)/);
  assert.match(harmony, /\.accessibilityText\(this\.tr\('实时监看'\)\)/);
  assert.match(xaml, /x:Name="LiveMonitoringToggle"[\s\S]{0,240}MinHeight="44"/);
  assert.match(windows, /AutomationProperties\.SetName\([\s\S]{0,100}LiveMonitoringToggle/);
});

test('W14 monitoring switch stops live view but keeps capture connection paths intact', async () => {
  const [ios, mac, android, harmony, windows] = await Promise.all([
    read(IOS_MODEL), read(MAC_MAIN), read(ANDROID), read(HARMONY), read(WINDOWS_CODE)
  ]);
  assert.match(ios, /func setLiveMonitoringEnabled[\s\S]{0,520}stopLiveViewIfNeeded\(\)/);
  assert.match(mac, /func setLiveMonitoringEnabled[\s\S]{0,800}toggleLiveView\(\)/);
  assert.match(
    blockStartingAt(android, 'private void toggleLiveView()'),
    /stopLiveViewForSource\(operationSource\)/,
  );
  assert.match(
    blockStartingAt(harmony, 'private async toggleLiveView()'),
    /stopLiveView\(\)/,
  );
  assert.match(windows, /LiveViewButton_Click[\s\S]{0,2200}StopLiveViewAsync/);
  for (const source of [ios, mac, android, harmony, windows]) {
    assert.match(source, /capture|Capture|快门/, 'camera capture path must remain present');
  }
});

test('W14 Android, HarmonyOS and Windows clear stale preview frames when monitoring stops', async () => {
  const [android, harmony, windows] = await Promise.all([
    read(ANDROID), read(HARMONY), read(WINDOWS_CODE)
  ]);
  assert.match(
    android,
    /if \(liveViewEnabled\)[\s\S]{0,520}latestFrame = null;[\s\S]{0,180}previewImage\.setImageDrawable\(null\)/
  );
  assert.match(android, /boolean showPreviewPlaceholder = !liveViewEnabled \|\| previewFrame == null/);
  assert.match(
    blockStartingAt(harmony, 'private async toggleLiveView()'),
    /if \(this\.liveView\)[\s\S]*this\.preview\.release\(\);[\s\S]*this\.preview = undefined;/,
  );
  assert.match(harmony, /if \(this\.liveView && this\.preview !== undefined\)/);
  assert.match(
    windows,
    /if \(!live\)[\s\S]{0,260}PreviewImage\.Source = null;[\s\S]{0,260}PreviewEmpty\.Visibility = Visibility\.Visible;/
  );
  assert.match(windows, /live && MonitorPreviewImage\.Source is not null/);
});

test('W14 macOS ignores cached frames and gates bridge JPEG when monitoring stops', async () => {
  const [mac, remote] = await Promise.all([read(MAC_MAIN), read(IOS_REMOTE)]);
  assert.match(
    mac,
    /func toggleLiveView\(\)[\s\S]{0,520}liveViewEnabled = false[\s\S]{0,120}clearLiveMonitoringFrames\(\)/
  );
  assert.match(
    mac,
    /private func clearLiveMonitoringFrames\(\)[\s\S]{0,160}frame = nil[\s\S]{0,100}sourceFrame = nil[\s\S]{0,100}zebraMask = nil/
  );
  assert.match(
    mac,
    /private func cameraBridgeLiveViewJPEG\(\) -> Data\? \{\s*guard onMainThread\(\{ isLiveMonitoringActive \}\) else \{ return nil \}/
  );
  const compactPreview = mac.slice(
    mac.indexOf('private struct CaptureCompactPreview: View'),
    mac.indexOf('private struct ShootingTaskPanel')
  );
  assert.match(compactPreview, /if !model\.isLiveMonitoringActive \{/);
  assert.ok(
    compactPreview.indexOf('if !model.isLiveMonitoringActive')
      < compactPreview.indexOf('wifiCamera.liveViewFrame'),
    'macOS off state must take precedence over cached Wi-Fi and local frames'
  );
  assert.match(
    remote,
    /func stopLiveViewIfNeeded\(ifOwnedBy explicitAttempt: UInt64\? = nil\)[\s\S]{0,180}liveViewTask = nil[\s\S]{0,80}liveViewFrame = nil/
  );
});

test('W14 live-monitoring label and off state are localized on all five targets', async () => {
  const applePaths = [
    'native/ios/NikonLink/zh-Hans.lproj/Localizable.strings',
    'native/ios/NikonLink/en.lproj/Localizable.strings',
    'native/ios/NikonLink/ja.lproj/Localizable.strings'
  ];
  const runtimeTablePaths = [
    'native/android/app/src/main/java/com/tauber/nikonlink/Localization.java',
    'native/harmony/entry/src/main/ets/localization/Localization.ets',
    'native/windows/Localization.cs'
  ];
  for (const path of [...applePaths, ...runtimeTablePaths]) {
    const source = await read(path);
    assert.ok(source.includes('实时监看'), `${path} missing live-monitoring label`);
    assert.ok(source.includes('实时监看已关闭'), `${path} missing off state`);
  }
  for (const path of applePaths) {
    const source = await read(path);
    assert.ok(source.includes('等待 Mac 桥接画面…'), `${path} missing bridge wait state`);
    assert.ok(source.includes('桥接返回 HTTP'), `${path} missing bridge HTTP error`);
    assert.ok(source.includes('Mac 相机桥接还需要上方本次配对码'), `${path} missing bridge pairing help`);
    for (const status of [
      'Sony 官方 SDK 已连接',
      '相机桥接已连接',
      '已收到蓝牙快门 · 正在通过 Mac 桥接触发…',
      '正在通过 Mac 桥接触发快门…',
      'Wi‑Fi 实时监看已开启',
      '连接相机后可开启实时监看',
      '桥接不可用',
      '请先在 Mac 端连接相机'
    ]) {
      assert.ok(source.includes(status), `${path} missing runtime status: ${status}`);
    }
  }
  const appleEnglish = await read(applePaths[1]);
  const appleJapanese = await read(applePaths[2]);
  const android = await read(ANDROID);
  assert.match(appleEnglish, /Live Monitoring|Live monitoring/);
  assert.match(appleJapanese, /ライブモニター/);
  assert.match(android, /!liveViewEnabled\s*\? tr\("实时监看已关闭"\)/);
  for (const path of runtimeTablePaths) {
    const source = await read(path);
    assert.match(source, /Live Monitoring|Live monitoring/);
    assert.match(source, /ライブモニター/);
    assert.ok(source.includes('打开开关即可恢复实时画面'));
  }
});

test('W14 packaging reuses validated prepared vendor runtimes when archives are absent', async () => {
  const [mac, windows] = await Promise.all([
    read('scripts/build-macos.sh'),
    read('scripts/build-windows.ps1')
  ]);
  assert.match(mac, /Nikon SDK archives and prepared runtime are both unavailable/);
  assert.match(mac, /Sony SDK archive and prepared runtime are both unavailable/);
  assert.match(mac, /CameraRemote_SDK\.h/);
  assert.match(mac, /libCr_Core\.dylib/);
  assert.match(windows, /Nikon SDK archives and prepared Windows runtime are both unavailable/);
  assert.match(windows, /Sony SDK archive and prepared Windows runtime are both unavailable/);
  assert.match(windows, /NkImgSDK\.dll/);
  assert.match(windows, /Cr_Core\.dll/);
});

test('W14 guide and delivery docs keep the iOS vendor boundary explicit', async () => {
  const [guide, outline, approach, progress] = await Promise.all([
    read('docs/LIVE_MONITOR_AND_IOS_CAMERA_BRIDGE.md'),
    read('docs/PROJECT_OUTLINE.md'),
    read('docs/TECHNICAL_APPROACH.md'),
    read('docs/TASK_PROGRESS.md')
  ]);
  for (const source of [guide, outline, approach, progress]) {
    assert.match(source, /Sony Camera Remote SDK/);
    assert.match(source, /Nikon[^\n]{0,120}PTP/);
    assert.match(source, /iOS[^\n]{0,160}(没有|未提供|不提供|未公开|不包含)[^\n]{0,80}(SDK|Remote SDK)/);
  }
  assert.match(guide, /12 位/);
  assert.match(guide, /同一(可信)?局域网/);
  assert.match(guide, /关闭[^\n]{0,80}(不会断开|不影响拍照)/);
});
