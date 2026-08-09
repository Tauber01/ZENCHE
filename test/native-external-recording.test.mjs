import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const root = new URL('../', import.meta.url);
const read = async (path) => readFile(new URL(path, root), 'utf8');

test('all five native monitor surfaces expose smart-device external recording', async () => {
  const sources = await Promise.all([
    read('native/ios/NikonLink/Views/RootView.swift'),
    read('native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java'),
    read('native/harmony/entry/src/main/ets/pages/Index.ets'),
    read('native/macos/Sources/NikonLink/main.swift'),
    read('native/windows/MainWindow.xaml'),
  ]);

  for (const source of sources) {
    assert.match(source, /外录到当前智能设备/);
    assert.match(source, /ZENCHE 文件库/);
  }
});

test('PTP native targets stream JPEG live view into finalized Motion-JPEG AVI', async () => {
  const recorders = await Promise.all([
    read('native/android/app/src/main/java/com/tauber/nikonlink/ExternalVideoRecorder.java'),
    read('native/harmony/entry/src/main/ets/storage/ExternalVideoRecorder.ets'),
    read('native/macos/Sources/NikonLink/ExternalVideoRecorder.swift'),
    read('native/windows/Services/ExternalVideoRecorder.cs'),
  ]);

  for (const recorder of recorders) {
    assert.match(recorder, /RIFF/);
    assert.match(recorder, /AVI /);
    assert.match(recorder, /MJPG/);
    assert.match(recorder, /idx1/);
    assert.match(recorder, /movi/);
  }

  const integrations = await Promise.all([
    read('native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java'),
    read('native/harmony/entry/src/main/ets/pages/Index.ets'),
    read('native/macos/Sources/NikonLink/main.swift'),
    read('native/windows/MainWindow.xaml.cs'),
  ]);
  for (const integration of integrations) {
    assert.match(integration, /appendJpeg|append\(jpeg:|AppendJpeg/);
    assert.match(integration, /stopIfRecording|StopIfRecording/);
  }
});

test('external video participates in native session naming and integrity workflows', async () => {
  const workflows = await Promise.all([
    read('native/android/app/src/main/java/com/tauber/nikonlink/CaptureWorkflow.java'),
    read('native/harmony/entry/src/main/ets/workflow/CaptureWorkflow.ets'),
    read('native/macos/Sources/NikonLink/CaptureWorkflow.swift'),
    read('native/windows/Services/CaptureWorkflow.cs'),
  ]);

  for (const workflow of workflows) {
    assert.match(workflow, /reserveExternalRecording|ReserveExternalRecording/);
    assert.match(workflow, /completeExternalRecording|CompleteExternalRecording/);
    assert.match(workflow, /sha256|SHA256/);
  }

  const iosWorkflow = await read(
    'native/ios/NikonLink/Models/CaptureWorkflow.swift',
  );
  const iosModel = await read('native/ios/NikonLink/Models/AppModel.swift');
  assert.match(iosWorkflow, /adoptTemporaryRecording/);
  assert.match(iosWorkflow, /read\(upToCount: 1024 \* 1024\)/);
  assert.match(iosModel, /adoptTemporaryRecording/);
});

test('every Motion-JPEG target indexes AVI files as videos in its local library', async () => {
  const libraries = await Promise.all([
    read('native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java'),
    read('native/harmony/entry/src/main/ets/storage/PhotoLibrary.ets'),
    read('native/macos/Sources/NikonLink/main.swift'),
    read('native/windows/Services/PhotoLibrary.cs'),
    read('native/windows/Models/PhotoItem.cs'),
  ]);

  for (const library of libraries) {
    assert.match(library, /\.avi|"avi"/i);
  }
});

test('version 1.5.10 launch announcements describe W14 on every target', async () => {
  const announcements = await Promise.all([
    read('native/ios/NikonLink/Views/RootView.swift'),
    read('native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java'),
    read('native/harmony/entry/src/main/ets/pages/Index.ets'),
    read('native/macos/Sources/NikonLink/SettingsSheet.swift'),
    read('native/windows/MainWindow.xaml.cs'),
  ]);

  for (const announcement of announcements) {
    assert.match(announcement, /Sony 官方 Camera Remote SDK 在 macOS 桥接端运行/);
    assert.match(announcement, /五端拍照页新增“实时监看”开关/);
    assert.match(announcement, /关闭监看后立即清除缓存画面并显示明确空态/);
    assert.match(announcement, /系统相机、UVC、USB\/PTP 与 Wi‑Fi PTP\/IP/);
    assert.match(announcement, /官网自动更新升级到 1\.5\.10/);
  }

  assert.match(announcements[1], /tr\("• iOS \/ iPadOS 新增可信局域网相机桥接/);
});
