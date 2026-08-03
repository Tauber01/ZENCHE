import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const root = new URL('../', import.meta.url);
const read = async (path) => readFile(new URL(path, root), 'utf8');

test('all five native targets expose AP and STA PTP/IP connection modes', async () => {
  const [
    appleService,
    iosView,
    android,
    harmony,
    macos,
    windows,
  ] = await Promise.all([
    read('native/ios/NikonLink/Connectivity/RemoteCaptureServices.swift'),
    read('native/ios/NikonLink/Views/RootView.swift'),
    read('native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java'),
    read('native/harmony/entry/src/main/ets/pages/Index.ets'),
    read('native/macos/Sources/NikonLink/main.swift'),
    read('native/windows/MainWindow.xaml.cs'),
  ]);

  assert.match(appleService, /enum WifiConnectionMode[\s\S]*case ap[\s\S]*case sta/);
  assert.match(appleService, /wifiCameraConnectionMode/);
  assert.match(iosView, /ForEach\(WifiConnectionMode\.allCases\)/);
  assert.match(macos, /Picker\("连接模式", selection: \$wifiCamera\.connectionMode\)/);

  assert.match(android, /wifiCameraConnectionMode/);
  assert.match(android, /String\[\] wifiModeLabels = \{tr\("AP 直连"\), tr\("STA 局域网"\)\}/);
  assert.match(android, /connectWifiCamera\(targetHost, targetPort, targetMode\)/);

  assert.match(harmony, /wifiConnectionMode: string = 'ap'/);
  assert.match(harmony, /this\.tr\('AP 直连'\)/);
  assert.match(harmony, /this\.tr\('STA 局域网'\)/);
  assert.match(harmony, /persistWifiConnectionSettings/);

  assert.match(windows, /WifiConnectionModeStatePath/);
  assert.match(windows, /Content = AppLocalization\.T\("AP 直连"\)/);
  assert.match(windows, /Content = AppLocalization\.T\("STA 局域网"\)/);
});

test('AP and STA guidance is localized in Chinese, English, and Japanese', async () => {
  const [chinese, english, japanese, android, harmony, windows] =
    await Promise.all([
      read('native/ios/NikonLink/zh-Hans.lproj/Localizable.strings'),
      read('native/ios/NikonLink/en.lproj/Localizable.strings'),
      read('native/ios/NikonLink/ja.lproj/Localizable.strings'),
      read('native/android/app/src/main/java/com/tauber/nikonlink/Localization.java'),
      read('native/harmony/entry/src/main/ets/localization/Localization.ets'),
      read('native/windows/Localization.cs'),
    ]);

  for (const contents of [chinese, english, japanese, android, harmony, windows]) {
    assert.match(contents, /AP 直连/);
    assert.match(contents, /STA 局域网/);
    assert.match(contents, /192\.168\.1\.1/);
  }
});

test('README documents equivalent AP and STA workflows in all three languages', async () => {
  const readme = await read('README.md');

  assert.match(readme, /Wi-Fi 相机控制（PTP\/IP）[\s\S]*AP 直连[\s\S]*STA 局域网/);
  assert.match(readme, /Wi-Fi camera control \(PTP\/IP\)[\s\S]*AP Direct[\s\S]*STA LAN/);
  assert.match(readme, /Wi-Fi カメラ制御（PTP\/IP）[\s\S]*AP ダイレクト[\s\S]*STA LAN/);
});
