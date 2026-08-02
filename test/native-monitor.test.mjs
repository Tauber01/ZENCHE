import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const root = new URL('..', import.meta.url).pathname;
const read = (path) => fs.readFileSync(`${root}${path}`, 'utf8');

test('native monitor surfaces use RGB and audio waveform cards', () => {
  const sources = [
    read('native/ios/NikonLink/Views/RootView.swift'),
    read('native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java'),
    read('native/harmony/entry/src/main/ets/pages/Index.ets'),
    read('native/macos/Sources/NikonLink/main.swift'),
    read('native/windows/MainWindow.xaml')
  ];
  for (const source of sources) {
    assert.match(source, /RGB 波形/);
    assert.match(source, /音频波形/);
  }
});

test('monitor lens readout and exposure tool are removed while parameters remain adjustable', () => {
  const android = read('native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java');
  const harmony = read('native/harmony/entry/src/main/ets/pages/Index.ets');
  const macos = read('native/macos/Sources/NikonLink/main.swift');
  const windows = read('native/windows/MainWindow.xaml');
  assert.doesNotMatch(android.slice(android.indexOf('private View buildMonitorView'), android.indexOf('private View buildMonitorStorageCard')), /"镜头"/);
  assert.doesNotMatch(harmony.slice(harmony.indexOf('private CameraWorkspace'), harmony.indexOf('private MonitorStorageCard')), /MonitorReadout\('镜头'/);
  assert.doesNotMatch(macos.slice(macos.indexOf('private struct MonitorView'), macos.indexOf('private struct MonitorControlDeck')), /title: "曝光"/);
  assert.doesNotMatch(windows.slice(windows.indexOf('x:Name="MonitorDashboard"'), windows.indexOf('x:Name="CapturePanel"')), /Text="镜头"/);
  assert.match(android, /monitorFrameRate/);
  assert.match(android, /monitorShutterAngle/);
  assert.match(harmony, /ImmersiveParameterControl\('帧率'/);
  assert.match(macos, /MonitorMacStepper\(title: "快门"/);
  assert.match(windows, /VideoFrameRateBox/);
});

test('native monitor previews wire tap-to-focus affordances', () => {
  assert.match(read('native/ios/NikonLink/Views/RootView.swift'), /focusHandler:/);
  assert.match(read('native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java'), /requestMonitorFocusAt/);
  assert.match(read('native/harmony/entry/src/main/ets/pages/Index.ets'), /focusAtMonitorPoint/);
  assert.match(read('native/macos/Sources/NikonLink/main.swift'), /SpatialTapGesture/);
  assert.match(read('native/windows/MainWindow.xaml'), /MonitorPreviewImage_MouseLeftButtonUp/);
});
