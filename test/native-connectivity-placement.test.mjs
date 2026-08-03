import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const root = new URL('../', import.meta.url);
const read = async (path) => readFile(new URL(path, root), 'utf8');

const region = (source, start, end) => {
  const startIndex = source.indexOf(start);
  const endIndex = source.indexOf(end, startIndex + start.length);
  assert.notEqual(startIndex, -1, `missing region start: ${start}`);
  assert.notEqual(endIndex, -1, `missing region end: ${end}`);
  return source.slice(startIndex, endIndex);
};

test('Wi-Fi camera controls live under wireless transfer on all native targets', async () => {
  const [ios, android, harmony, macos, windowsXaml, windowsCode] =
    await Promise.all([
      read('native/ios/NikonLink/Views/RootView.swift'),
      read('native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java'),
      read('native/harmony/entry/src/main/ets/pages/Index.ets'),
      read('native/macos/Sources/NikonLink/main.swift'),
      read('native/windows/MainWindow.xaml'),
      read('native/windows/MainWindow.xaml.cs'),
    ]);

  assert.match(ios, /private struct WirelessTransferCard[\s\S]*WifiCameraTransferCard\(\)/);
  assert.match(android, /buildWirelessTransferPanel\(\)[\s\S]*buildWifiCameraPanel\(\)/);
  assert.match(harmony, /private WirelessTransferCard\(\)[\s\S]*this\.WifiCameraTransferSection\(\)/);
  assert.match(
    region(macos, 'private struct TransferView', 'private struct SplashView'),
    /@ObservedObject private var wifiCamera[\s\S]*Wi‑Fi 相机 · PTP\/IP/
  );
  assert.match(windowsXaml, /WifiCameraTransferHost/);
  assert.match(windowsCode, /WifiCameraTransferHost\.Content = BuildWifiCameraTransferPanel\(\)/);
});

test('Bluetooth and location switches live in Settings, not camera connection dialogs', async () => {
  const [ios, android, harmony, macos, macSettings, windowsXaml, windowsCode] =
    await Promise.all([
      read('native/ios/NikonLink/Views/RootView.swift'),
      read('native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java'),
      read('native/harmony/entry/src/main/ets/pages/Index.ets'),
      read('native/macos/Sources/NikonLink/main.swift'),
      read('native/macos/Sources/NikonLink/SettingsSheet.swift'),
      read('native/windows/MainWindow.xaml'),
      read('native/windows/MainWindow.xaml.cs'),
    ]);

  assert.match(
    region(ios, 'private struct AppSettingsSheet', 'private struct ConnectionSheet'),
    /拍摄辅助[\s\S]*model\.bluetoothRemote[\s\S]*model\.locationTagging/
  );
  assert.doesNotMatch(
    region(ios, 'private struct ConnectionSheet', 'private struct ConnectionOption'),
    /wifiCamera|bluetoothRemote|locationTagging/
  );

  assert.match(android, /buildSettingsView\(\)[\s\S]*buildCaptureAssistantsPanel\(\)/);
  assert.doesNotMatch(
    region(android, 'private void showConnectionDialog()', 'private void connectWifiCamera('),
    /wifiCamera|bluetoothRemote|locationTagging/
  );

  assert.match(harmony, /private SettingsWorkspace\(\)[\s\S]*this\.CaptureAssistSettingsCard\(\)/);
  assert.match(macSettings, /bluetoothRemote: BluetoothRemoteService[\s\S]*locationTagging: LocationTaggingService/);
  assert.doesNotMatch(
    region(macos, 'private struct ConnectionSheet', 'private struct RootView'),
    /wifiCamera|bluetoothRemote|locationTagging/
  );

  assert.match(windowsXaml, /CaptureAssistSettingsHost/);
  assert.match(windowsCode, /CaptureAssistSettingsHost\.Content = BuildCaptureAssistSettingsPanel\(\)/);
  assert.doesNotMatch(
    region(windowsCode, 'private void ShowConnectionDialog()', 'private async Task RefreshNikonOfficialSdkAsync'),
    /_wifiCamera|_bluetoothRemote|_locationTagging/
  );
});
