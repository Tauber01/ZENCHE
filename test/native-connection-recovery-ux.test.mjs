import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const root = new URL('../', import.meta.url);
const read = async (path) => readFile(new URL(path, root), 'utf8');

test('all five native targets expose recoverable Wi-Fi connection actions and guidance', async () => {
  const sources = await Promise.all([
    read('native/ios/NikonLink/Views/RootView.swift'),
    read('native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java'),
    read('native/harmony/entry/src/main/ets/pages/Index.ets'),
    read('native/macos/Sources/NikonLink/main.swift'),
    read('native/windows/MainWindow.xaml.cs'),
  ]);

  for (const source of sources) {
    assert.match(source, /取消连接/);
    assert.match(source, /停止重连/);
    assert.match(source, /重试连接/);
    assert.match(source, /正在建立 PTP\/IP 通道，可随时取消/);
    assert.match(source, /正在自动恢复连接；停止后可修改 Wi‑Fi、IP 地址或端口/);
    assert.match(source, /确认相机已开启 PTP\/IP，并检查当前 Wi‑Fi、IP 地址和端口后重试/);
  }
});

test('connection cards show progress, lock endpoints, and keep cancellation reachable', async () => {
  const [ios, android, harmony, macos, windows] = await Promise.all([
    read('native/ios/NikonLink/Views/RootView.swift'),
    read('native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java'),
    read('native/harmony/entry/src/main/ets/pages/Index.ets'),
    read('native/macos/Sources/NikonLink/main.swift'),
    read('native/windows/MainWindow.xaml.cs'),
  ]);

  assert.match(ios, /if connectionActive \{[\s\S]{0,100}ProgressView\(\)/);
  assert.match(ios, /disabled\(model\.wifiCamera\.isConnected \|\| connectionActive\)/);
  assert.match(
    ios,
    /if model\.wifiCamera\.isConnected \|\| connectionActive \{[\s\S]{0,100}model\.wifiCamera\.disconnect\(\)/,
  );

  assert.match(android, /wifiConnectionProgress = new ProgressBar/);
  assert.match(android, /wifiHostInput\.setEnabled\(!controlsLocked\)/);
  assert.match(
    android,
    /if \(wifiConnected \|\| wifiConnecting \|\| wifiReconnecting\) \{[\s\S]{0,100}disconnectWifiCamera\(\)/,
  );

  assert.match(harmony, /if \(this\.wifiConnectionActive\(\)\) \{[\s\S]{0,100}LoadingProgress\(\)/);
  assert.match(harmony, /enabled\(!this\.wifiConnected && !this\.wifiConnectionActive\(\)\)/);
  assert.match(
    harmony,
    /if \(this\.wifiConnected \|\| this\.wifiConnectionActive\(\)\) \{[\s\S]{0,100}this\.disconnectWifiCamera\(\)/,
  );

  assert.match(macos, /if wifiConnectionActive \{[\s\S]{0,100}ProgressView\(\)/);
  assert.match(macos, /disabled\(wifiCamera\.isConnected \|\| wifiConnectionActive\)/);
  assert.match(
    macos,
    /if wifiCamera\.isConnected \|\| wifiConnectionActive \{[\s\S]{0,100}wifiCamera\.disconnect\(\)/,
  );

  assert.match(windows, /_wifiConnectionProgress = new ProgressBar/);
  assert.match(windows, /var inputsEnabled = !active && !_wifiCamera\.IsConnected/);
  assert.match(windows, /if \(_wifiConnecting\)[\s\S]{0,100}CancelWifiConnectionAttempt\(\)/);
  assert.match(windows, /else if \(_wifiReconnecting\)[\s\S]{0,100}StopWifiReconnectAsync\(\)/);
  assert.match(
    windows,
    /IsWifiCameraReady\(\)[\s\S]{0,180}!_wifiConnecting[\s\S]{0,100}!_wifiReconnecting[\s\S]{0,100}!_wifiCancellationPending/,
  );
  assert.match(
    windows,
    /var live = _camera\.IsLiveView \|\| _localCamera\.IsLiveView \|\|[\s\S]{0,100}IsWifiCameraReady\(\)/,
  );
  const windowsReconnectEntry = windows.slice(
    windows.indexOf('private async Task EnterWifiReconnectingAsync('),
    windows.indexOf('private void ScheduleWifiReconnect()'),
  );
  assert.match(
    windowsReconnectEntry,
    /_wifiReconnecting = true[\s\S]{0,500}UpdateEnabledState\(\)[\s\S]{0,100}UpdateLiveViewState\(\)/,
  );
  assert.match(
    windows,
    /var liveViewReady = \(_camera\.IsConnected \|\| _localCamera\.IsConnected \|\|\s*wifiReady\)/,
  );
});

test('Wi-Fi failure presentation is source-specific on Android, HarmonyOS, and Windows', async () => {
  const [android, harmony, windows] = await Promise.all([
    read('native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java'),
    read('native/harmony/entry/src/main/ets/pages/Index.ets'),
    read('native/windows/MainWindow.xaml.cs'),
  ]);

  assert.match(android, /private String wifiLastConnectionError/);
  assert.match(android, /wifiConnectionFailed\(\)[\s\S]{0,180}wifiLastConnectionError/);
  assert.match(harmony, /@State private wifiLastConnectionError: string/);
  assert.match(harmony, /wifiConnectionFailed\(\)[\s\S]{0,180}wifiLastConnectionError/);
  assert.match(windows, /private string\? _wifiLastConnectionError/);
  assert.match(windows, /var failed = !connected && !active &&[\s\S]{0,100}_wifiLastConnectionError/);
});

test('new connection UX labels are localized in English and Japanese', async () => {
  const [appleEnglish, appleJapanese, android, harmony, windows] =
    await Promise.all([
      read('native/ios/NikonLink/en.lproj/Localizable.strings'),
      read('native/ios/NikonLink/ja.lproj/Localizable.strings'),
      read('native/android/app/src/main/java/com/tauber/nikonlink/Localization.java'),
      read('native/harmony/entry/src/main/ets/localization/Localization.ets'),
      read('native/windows/Localization.cs'),
    ]);

  for (const source of [appleEnglish, android, harmony, windows]) {
    assert.match(source, /Cancel Connection/);
    assert.match(source, /Stop Reconnecting/);
    assert.match(source, /Retry Connection/);
    assert.match(source, /Configure and Connect/);
  }
  assert.match(windows, /Unable to establish the Wi‑Fi\/PTP‑IP connection/);
  assert.match(windows, /Unable to restore the Wi‑Fi\/PTP‑IP connection/);
  assert.match(windows, /Unable to stop Wi‑Fi\/PTP‑IP reconnection/);
  assert.match(windows, /Unable to disconnect the Wi‑Fi\/PTP‑IP connection/);
  for (const source of [appleJapanese, android, harmony, windows]) {
    assert.match(source, /接続をキャンセル/);
    assert.match(source, /再接続を停止/);
    assert.match(source, /接続を再試行/);
    assert.match(source, /設定して接続/);
  }

  const [iosView, macosView] = await Promise.all([
    read('native/ios/NikonLink/Views/RootView.swift'),
    read('native/macos/Sources/NikonLink/main.swift'),
  ]);
  assert.match(
    iosView,
    /Label \{\s*RuntimeLocalizedText\(actionTitle\)/,
    'iOS dynamic action labels must use runtime localization',
  );
  assert.ok(
    (macosView.match(/RuntimeLocalizedText\(wifiActionTitle\)/g) ?? []).length >= 2,
    'macOS dynamic action labels must use runtime localization in both entry points',
  );
});

test('authentication cleanup clears stale Wi-Fi failure presentation', async () => {
  const [android, harmony] = await Promise.all([
    read('native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java'),
    read('native/harmony/entry/src/main/ets/pages/Index.ets'),
  ]);

  const androidCleanup = android.slice(
    android.indexOf('private void closeAuthSensitiveState()'),
    android.indexOf('private void updateAuthCodeRowVisibility()'),
  );
  assert.match(androidCleanup, /wifiLastConnectionError = null/);
  assert.match(androidCleanup, /lastConnectionError = null/);

  const harmonyCleanup = harmony.slice(
    harmony.indexOf('private async closeAuthSensitiveState()'),
    harmony.indexOf('private async initializeServices()'),
  );
  assert.match(harmonyCleanup, /this\.wifiLastConnectionError = ''/);
  assert.match(harmonyCleanup, /this\.lastConnectionError = ''/);
});

test('HarmonyOS connection overlay keeps actions reachable on small viewports', async () => {
  const harmony = await read('native/harmony/entry/src/main/ets/pages/Index.ets');
  const overlay = harmony.slice(
    harmony.indexOf('private ConnectionPanelOverlay()'),
    harmony.indexOf('private LargePhotoOverlay()'),
  );

  assert.match(overlay, /Scroll\(\)/);
  assert.match(overlay, /\.layoutWeight\(1\)/);
  assert.match(overlay, /\.scrollBar\(BarState\.Auto\)/);
  assert.match(overlay, /\.height\(this\.isCompact\(\) \? '94%' : '88%'\)/);
});
