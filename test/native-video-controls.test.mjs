import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const root = new URL('../', import.meta.url);
const read = async (path) => readFile(new URL(path, root), 'utf8');

test('all native camera workspaces expose AF-ON and video exposure controls', async () => {
  const sources = await Promise.all([
    read('native/ios/NikonLink/Views/RootView.swift'),
    read('native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java'),
    read('native/harmony/entry/src/main/ets/pages/Index.ets'),
    read('native/macos/Sources/NikonLink/main.swift'),
    read('native/windows/MainWindow.xaml'),
  ]);

  for (const source of sources) {
    assert.match(source, /AF-ON/);
    assert.match(source, /视频曝光模式|拍摄模式/);
    assert.match(source, /视频快门表示/);
    assert.match(source, /快门角度/);
    assert.match(source, /快门速度/);
    assert.match(source, /视频编码|视频录制规格/);
    assert.match(source, /N-Log|Log \/ Picture Profile|VideoLog/);
  }
});

test('native video codec selectors include delivery and raw formats', async () => {
  const sources = await Promise.all([
    read('native/ios/NikonLink/Camera/CameraService.swift'),
    read('native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java'),
    read('native/harmony/entry/src/main/ets/pages/Index.ets'),
    read('native/macos/Sources/NikonLink/main.swift'),
    read('native/windows/MainWindow.xaml.cs'),
  ]);

  for (const source of sources) {
    assert.match(source, /H\.264/);
    assert.match(source, /H\.265|HEVC/);
    assert.match(source, /ProRes 422 HQ/);
    assert.match(source, /ProRes RAW/);
    assert.match(source, /N-RAW/);
  }
});

test('PTP transports select Nikon codec-specific writable tone properties', async () => {
  const directSources = await Promise.all([
    read('native/android/app/src/main/java/com/tauber/nikonlink/PtpCamera.java'),
    read('native/harmony/entry/src/main/ets/camera/PtpCamera.ets'),
    read('native/windows/Services/PtpCamera.cs'),
  ]);
  const macHelper = await read(
    'native/macos/Sources/NikonLink/NikonPTPControl.cpp',
  );
  const sources = [...directSources, macHelper];

  for (const source of sources) {
    assert.match(source, /d0af/i);
    assert.match(source, /1d000/i);
    assert.match(source, /1d001/i);
    assert.match(source, /1d028/i);
    assert.match(source, /1d029/i);
    assert.match(source, /00010a00/i);
    assert.match(source, /00020c02/i);
  }

  assert.doesNotMatch(macHelper, /d0bb|d0bf/i);
  assert.match(await read('scripts/build-macos.sh'), /zenche-nikon-ptp/);
});

test('Sony and Canon video specifications and log profiles stay aligned', async () => {
  const sources = await Promise.all([
    read('native/ios/NikonLink/Camera/CameraService.swift'),
    read('native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java'),
    read('native/harmony/entry/src/main/ets/pages/Index.ets'),
    read('native/macos/Sources/NikonLink/main.swift'),
    read('native/windows/MainWindow.xaml.cs'),
  ]);

  for (const source of sources) {
    assert.match(source, /XAVC HS 4K/);
    assert.match(source, /XAVC S-I 4K/);
    assert.match(source, /S-Log3/);
    assert.match(source, /HLG/);
    assert.match(source, /XF-HEVC S/);
    assert.match(source, /XF-AVC S/);
    assert.match(source, /Canon Log 2/);
    assert.match(source, /Canon Log 3/);
  }
});

test('direct PTP transports use confirmed Sony and Canon log properties', async () => {
  const sources = await Promise.all([
    read('native/android/app/src/main/java/com/tauber/nikonlink/PtpCamera.java'),
    read('native/harmony/entry/src/main/ets/camera/PtpCamera.ets'),
    read('native/windows/Services/PtpCamera.cs'),
  ]);

  for (const source of sources) {
    assert.match(source, /d23f/i);
    assert.match(source, /d241/i);
    assert.match(source, /9110/i);
    assert.match(source, /d176/i);
    assert.match(source, /videoLog/);
  }
});
