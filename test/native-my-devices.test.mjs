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
