import assert from 'node:assert/strict';
import { access, readFile } from 'node:fs/promises';
import test from 'node:test';

const root = new URL('../', import.meta.url);
const read = async (path) => readFile(new URL(path, root), 'utf8');

test('all native targets expose a persistent My Devices workspace', async () => {
  const [iosModel, iosView, android, harmony, macos, windowsXaml, windowsCode] =
    await Promise.all([
      read('native/ios/NikonLink/Models/AppModel.swift'),
      read('native/ios/NikonLink/Views/RootView.swift'),
      read('native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java'),
      read('native/harmony/entry/src/main/ets/pages/Index.ets'),
      read('native/macos/Sources/NikonLink/main.swift'),
      read('native/windows/MainWindow.xaml'),
      read('native/windows/MainWindow.xaml.cs'),
    ]);

  for (const source of [
    iosView,
    android,
    harmony,
    macos,
    `${windowsXaml}\n${windowsCode}`,
  ]) {
    assert.match(source, /我的设备/);
    assert.match(source, /快速连接/);
    assert.match(source, /忘记设备/);
    assert.match(source, /尚未连接过设备/);
  }

  assert.match(iosModel, /rememberedCameraDevices\.v1/);
  assert.match(iosModel, /isExternalCamera/);
  assert.match(android, /REMEMBERED_DEVICES_KEY/);
  assert.match(harmony, /rememberedCameraDevices\.v1/);
  assert.match(macos, /rememberedCameraDevices\.v1/);
  assert.match(windowsCode, /remembered-camera-devices\.json/);
});

test('all native packages include Nikon, Sony, and Canon camera photos', async () => {
  const paths = [
    'native/android/app/src/main/res/drawable/camera_nikon.jpg',
    'native/android/app/src/main/res/drawable/camera_sony.jpg',
    'native/android/app/src/main/res/drawable/camera_canon.jpg',
    'native/harmony/entry/src/main/resources/base/media/camera_nikon.jpg',
    'native/harmony/entry/src/main/resources/base/media/camera_sony.jpg',
    'native/harmony/entry/src/main/resources/base/media/camera_canon.jpg',
    'native/ios/NikonLink/Assets.xcassets/camera_nikon.imageset/camera_nikon.jpg',
    'native/ios/NikonLink/Assets.xcassets/camera_sony.imageset/camera_sony.jpg',
    'native/ios/NikonLink/Assets.xcassets/camera_canon.imageset/camera_canon.jpg',
    'native/macos/Resources/camera-nikon.jpg',
    'native/macos/Resources/camera-sony.jpg',
    'native/macos/Resources/camera-canon.jpg',
  ];

  await Promise.all(paths.map((path) => access(new URL(path, root))));

  const windowsProject = await read('native/windows/NikonLink.Windows.csproj');
  assert.match(windowsProject, /camera-nikon\.jpg/);
  assert.match(windowsProject, /camera-sony\.jpg/);
  assert.match(windowsProject, /camera-canon\.jpg/);
});

test('Canon movie recording uses EOS EVFRecordStatus path on Android/Harmony/Windows (C2)', async () => {
  const [android, harmony, windows, windowsOps] = await Promise.all([
    read('native/android/app/src/main/java/com/tauber/nikonlink/PtpCamera.java'),
    read('native/harmony/entry/src/main/ets/camera/PtpCamera.ets'),
    read('native/windows/Services/PtpCamera.cs'),
    read('native/windows/Services/PtpVendorOps.cs'),
  ]);

  for (const source of [android, harmony, windows]) {
    // 佳能（VID 0x04a9）录像必须走 EOS 属性写路径：0x9110 + EVFRecordStatus 0xD1b8。
    assert.match(source, /0x9110/);
    assert.match(source, /0xd1b8|0xD1b8/);
    // 佳能分支必须存在（vendor 判定 + 录像启停走 EVFRecordStatus）。
    assert.match(source, /0x04a9/);
    assert.match(source, /EVF_RECORD_STATUS|CanonEvfRecordStatus/);
  }

  // 尼康/索尼路径保持尼康 opcode（0x920a/0x920b），不被佳能分支吞掉。
  assert.match(android, /START_MOVIE_RECORDING/);
  assert.match(harmony, /START_MOVIE_RECORDING/);
  assert.match(windows, /_vendorOps\.StartMovieRecording/);
  assert.match(windowsOps, /0x920a/);
});

test('E2 1.5.9: 佳能实时取景走 EOS_GetViewFinderData(0x9153)，尼康取景 0x9203 保留', async () => {
  const [android, harmony, windows] = await Promise.all([
    read('native/android/app/src/main/java/com/tauber/nikonlink/PtpCamera.java'),
    read('native/harmony/entry/src/main/ets/camera/PtpCamera.ets'),
    read('native/windows/Services/PtpCamera.cs'),
  ]);

  for (const source of [android, harmony, windows]) {
    // 佳能取帧 opcode：0x9153 EOS_GetViewFinderData（vendor 分发进入）。
    assert.match(source, /0x9153/);
    assert.match(source, /CANON_EOS_GET_VIEW_FINDER_DATA|CanonEosGetViewFinderData/);
    // EOS dataset → 内嵌 JPEG 提取：type 1/9/11（libgphoto2 对齐）。
    assert.match(source, /type == 1 \|\| type == 9 \|\| type == 11|type === 1 \|\| type === 9 \|\| type === 11/);
    // 确认置位（不再乐观置位）：取景开启返回是否确认。
    assert.match(source, /canonOpenLiveView|CanonOpenLiveViewAsync/);
    // EVFOutputDevice 条件写：(cur & ~1) == 0。
    assert.match(source, /& ~1|& ~1u|& 0xffffffff/);
  }
  // 尼康取景 0x9203 保留（非佳能路径不变）。
  assert.match(android, /GET_LIVE_VIEW_IMAGE, null, null/);
  assert.match(harmony, /GET_LIVE_VIEW_IMAGE,\n\s*\[\],\n\s*undefined/);
  assert.match(windows, /GetLiveViewImage,/);
});
