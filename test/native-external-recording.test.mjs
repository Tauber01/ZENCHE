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

test('version 1.5.13 launch announcements describe local-copy exports and candidate boundaries', async () => {
  const announcements = await Promise.all([
    read('native/ios/NikonLink/Views/RootView.swift'),
    read('native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java'),
    read('native/harmony/entry/src/main/ets/pages/Index.ets'),
    read('native/macos/Sources/NikonLink/SettingsSheet.swift'),
    read('native/windows/MainWindow.xaml.cs'),
  ]);

  for (const announcement of announcements) {
    assert.match(announcement, /新增“下载到本地”/);
    assert.match(announcement, /联机拍摄、相机卡下载、AI 修图\/生图与专业编辑结果/);
    assert.match(announcement, /“保存到系统相册”继续作为独立操作保留/);
    assert.match(announcement, /不移动或删除 ZENCHE 文件库中的源文件/);
    assert.match(announcement, /macOS 与 Windows 的 AI 修图也改为始终生成新文件/);
    assert.match(announcement, /同步落盘且大小校验通过后才显示成功/);
    assert.match(announcement, /尽力删除未完成的目标/);
    assert.match(announcement, /1\.5\.13 是尚未推送、发布或切换官网更新的本地候选/);
    assert.match(announcement, /真机上继续验证系统保存器、权限、同名文件、大文件与存储空间不足/);
  }

  assert.match(announcements[1], /tr\("• 新增“下载到本地”/);

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
    assert.match(announcement, /Added “Save a Local Copy”/);
    assert.match(announcement, /Export creates a copy and never moves or deletes the source/);
    assert.match(announcement, /make a best effort to delete an incomplete destination/);
    assert.match(announcement, /Version 1\.5\.13 is a local candidate that has not been pushed, released, or added to the website update feed/);
  }
  for (const announcement of japaneseAnnouncements) {
    assert.match(announcement, /「ローカルコピーを保存」を追加しました/);
    assert.match(announcement, /元ファイルを移動・削除しません/);
    assert.match(announcement, /未完了の保存先も可能な範囲で取り除きます/);
    assert.match(announcement, /1\.5\.13 はローカル候補版/);
  }
});
