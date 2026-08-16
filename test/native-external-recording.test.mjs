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

test('version 1.5.14 launch announcements describe recoverable PTP/IP connections and candidate boundaries', async () => {
  const announcements = await Promise.all([
    read('native/ios/NikonLink/Views/RootView.swift'),
    read('native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java'),
    read('native/harmony/entry/src/main/ets/pages/Index.ets'),
    read('native/macos/Sources/NikonLink/SettingsSheet.swift'),
    read('native/windows/MainWindow.xaml.cs'),
  ]);

  for (const announcement of announcements) {
    assert.match(announcement, /加固 Wi‑Fi\/PTP‑IP 连接/);
    assert.match(announcement, /连接与自动重连现在会实时显示状态/);
    assert.match(announcement, /取消连接或停止重连/);
    assert.match(announcement, /断线恢复使用会话代际隔离/);
    assert.match(announcement, /Android 与 HarmonyOS 补齐网络状态权限/);
    assert.match(announcement, /Windows 单轮重连使用有限超时/);
    assert.match(announcement, /1\.5\.14 是本地候选版本，尚未发布/);
    assert.match(announcement, /不能替代真实相机、移动设备和 Windows 主机验收/);
    assert.doesNotMatch(announcement, /GitHub Release 提供 1\.5\.13 五端安装包/);
  }

  assert.match(announcements[1], /tr\("• 加固 Wi‑Fi\/PTP‑IP 连接/);

  const englishAnnouncements = await Promise.all([
    read('native/ios/NikonLink/en.lproj/Localizable.strings'),
    read('native/android/app/src/main/java/com/tauber/nikonlink/Localization.java'),
    read('native/harmony/entry/src/main/ets/localization/Localization.ets'),
    read('native/windows/Localization.cs'),
  ]);
  const japaneseAnnouncements = await Promise.all([
    read('native/ios/NikonLink/ja.lproj/Localizable.strings'),
    read('native/android/app/src/main/java/com/tauber/nikonlink/Localization.java'),
    read('native/harmony/entry/src/main/ets/localization/Localization.ets'),
    read('native/windows/Localization.cs'),
  ]);

  for (const announcement of englishAnnouncements) {
    assert.match(announcement, /Strengthened Wi‑Fi\/PTP‑IP connections/);
    assert.match(announcement, /cancel a connection or stop reconnecting/);
    assert.match(announcement, /Session-generation isolation/);
    assert.match(announcement, /1\.5\.14 is a local candidate and has not been released/);
    assert.match(announcement, /real cameras, mobile devices, and Windows hosts/);
  }
  for (const announcement of japaneseAnnouncements) {
    assert.match(announcement, /Wi‑Fi／PTP-IP 接続を強化しました/);
    assert.match(announcement, /接続のキャンセルや再接続の停止/);
    assert.match(announcement, /セッション世代の分離/);
    assert.match(announcement, /1\.5\.14 は未公開のローカル候補/);
    assert.match(announcement, /実機カメラ、モバイル端末、Windows ホスト/);
  }
});
