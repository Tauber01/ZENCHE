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

test('version 1.5.15 launch announcements describe durable Wi-Fi stability facts', async () => {
  const announcements = await Promise.all([
    read('native/ios/NikonLink/Views/RootView.swift'),
    read('native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java'),
    read('native/harmony/entry/src/main/ets/pages/Index.ets'),
    read('native/macos/Sources/NikonLink/SettingsSheet.swift'),
    read('native/windows/MainWindow.xaml.cs'),
  ]);

  for (const announcement of announcements) {
    assert.match(announcement, /绑定到实际相机 Wi‑Fi 网络/);
    assert.match(announcement, /Wi‑Fi 重关联期间的 waiting/);
    assert.match(announcement, /回到前台时立即补一次 Probe/);
    assert.match(announcement, /真实 Probe 作为连接就绪屏障/);
    assert.match(announcement, /接口地址变化即时探测/);
    assert.match(announcement, /伪相机故障注入回归/);
    assert.match(announcement, /1\.5\.15 安装包签名状态与实机验证边界/);
    assert.doesNotMatch(announcement, /1\.5\.14 已通过 GitHub 与官网发布/);
  }

  assert.match(announcements[1], /tr\("• Android 与 HarmonyOS 将 PTP\/IP/);

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
    assert.match(announcement, /bind PTP\/IP command and event channels to the actual camera Wi-Fi network/);
    assert.match(announcement, /waiting during Wi-Fi reassociation/);
    assert.match(announcement, /probes immediately after returning to the foreground/);
    assert.match(announcement, /real Probe as the ready barrier/);
    assert.match(announcement, /interface-address changes/);
    assert.match(announcement, /fake-camera fault-injection regressions/);
    assert.match(announcement, /1\.5\.15 release notes for package signing/);
    assert.doesNotMatch(announcement, /1\.5\.14 is published through GitHub and the official website/);
  }
  for (const announcement of japaneseAnnouncements) {
    assert.match(announcement, /実際のカメラ Wi‑Fi ネットワークへバインド/);
    assert.match(announcement, /Wi‑Fi 再接続中の waiting/);
    assert.match(announcement, /フォアグラウンド復帰直後に Probe/);
    assert.match(announcement, /実際の Probe を接続準備完了の境界/);
    assert.match(announcement, /インターフェースのアドレス変化後の即時 Probe/);
    assert.match(announcement, /偽カメラの障害注入回帰/);
    assert.match(announcement, /1\.5\.15 パッケージの署名状態/);
    assert.doesNotMatch(announcement, /1\.5\.14 は GitHub と公式サイトで公開済みです/);
  }
});
