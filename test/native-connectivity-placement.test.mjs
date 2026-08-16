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

test('camera connection dialogs surface Wi-Fi while Bluetooth and location stay in Settings', async () => {
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
  assert.match(
    region(ios, 'private struct ConnectionSheet', 'private struct ConnectionOption'),
    /WifiCameraTransferCard\(\)/
  );
  assert.doesNotMatch(
    region(ios, 'private struct ConnectionSheet', 'private struct ConnectionOption'),
    /bluetoothRemote|locationTagging/
  );

  assert.match(android, /buildSettingsView\(\)[\s\S]*buildCaptureAssistantsPanel\(\)/);
  assert.match(
    region(android, 'private void showConnectionDialog()', 'private void connectWifiCamera('),
    /Wi‑Fi 相机 · PTP\/IP[\s\S]*wifiDialogActionButton/
  );
  assert.doesNotMatch(
    region(android, 'private void showConnectionDialog()', 'private void connectWifiCamera('),
    /bluetoothRemote|locationTagging/
  );

  assert.match(harmony, /private SettingsWorkspace\(\)[\s\S]*this\.CaptureAssistSettingsCard\(\)/);
  assert.match(
    region(harmony, 'private ConnectionPanelOverlay()', 'private LargePhotoOverlay()'),
    /Wi‑Fi 相机 · PTP\/IP[\s\S]*wifiConnectionBridgeActionLabel/
  );
  assert.doesNotMatch(
    region(harmony, 'private ConnectionPanelOverlay()', 'private LargePhotoOverlay()'),
    /bluetoothRemote|locationTagging/
  );
  assert.match(macSettings, /bluetoothRemote: BluetoothRemoteService[\s\S]*locationTagging: LocationTaggingService/);
  assert.match(
    region(macos, 'private struct ConnectionSheet', 'private struct RootView'),
    /Wi‑Fi 相机 · PTP\/IP/
  );
  assert.match(
    region(macos, 'private struct ConnectionSheet', 'private struct RootView'),
    /wifiActionTitle/
  );
  assert.doesNotMatch(
    region(macos, 'private struct ConnectionSheet', 'private struct RootView'),
    /bluetoothRemote|locationTagging/
  );

  assert.match(windowsXaml, /CaptureAssistSettingsHost/);
  assert.match(windowsCode, /CaptureAssistSettingsHost\.Content = BuildCaptureAssistSettingsPanel\(\)/);
  assert.match(
    region(windowsCode, 'private void ShowConnectionDialog()', 'private async Task RefreshNikonOfficialSdkAsync'),
    /Wi‑Fi 相机 · PTP\/IP[\s\S]*_wifiDialogActionButton/
  );
  assert.doesNotMatch(
    region(windowsCode, 'private void ShowConnectionDialog()', 'private async Task RefreshNikonOfficialSdkAsync'),
    /_bluetoothRemote|_locationTagging/
  );
});
