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

test('version 1.5.14 launch announcements describe the durable published release', async () => {
  const announcements = await Promise.all([
    read('native/ios/NikonLink/Views/RootView.swift'),
    read('native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java'),
    read('native/harmony/entry/src/main/ets/pages/Index.ets'),
    read('native/macos/Sources/NikonLink/SettingsSheet.swift'),
    read('native/windows/MainWindow.xaml.cs'),
  ]);

  for (const announcement of announcements) {
    assert.match(announcement, /修复 Wi‑Fi\/PTP‑IP 与桌面 USB 连接不上、连接中断/);
    assert.match(announcement, /Sony ZV‑E10/);
    assert.match(announcement, /一键导入照片和视频/);
    assert.match(announcement, /五端文件库改为“所有文件”优先/);
    assert.match(announcement, /系统废纸篓\/回收站/);
    assert.match(announcement, /1\.5\.14 已通过 GitHub 与官网发布/);
    assert.match(announcement, /安装包签名和实机验证边界请查看发布说明/);
    assert.doesNotMatch(announcement, /本地候选版本，尚未发布/);
  }

  assert.match(announcements[1], /tr\("• 修复 Wi‑Fi\/PTP‑IP 与桌面 USB/);

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
    assert.match(announcement, /Fixed Wi‑Fi\/PTP-IP and desktop USB connection failures and interruptions/);
    assert.match(announcement, /Sony ZV-E10/);
    assert.match(announcement, /one-click multi-file photo\/video import/);
    assert.match(announcement, /All five libraries now lead with All Files/);
    assert.match(announcement, /OS Trash\/Recycle Bin/);
    assert.match(announcement, /1\.5\.14 is published through GitHub and the official website/);
    assert.doesNotMatch(announcement, /local candidate and has not been released/);
  }
  for (const announcement of japaneseAnnouncements) {
    assert.match(announcement, /Wi‑Fi／PTP-IP とデスクトップ USB の接続失敗・切断を修正しました/);
    assert.match(announcement, /Sony ZV-E10/);
    assert.match(announcement, /写真・動画のワンクリック複数読み込み/);
    assert.match(announcement, /5 プラットフォームのファイル画面は「すべてのファイル」を先頭/);
    assert.match(announcement, /OS のゴミ箱/);
    assert.match(announcement, /1\.5\.14 は GitHub と公式サイトで公開済みです/);
    assert.doesNotMatch(announcement, /未公開のローカル候補/);
  }
});
