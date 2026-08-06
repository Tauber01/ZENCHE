import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const root = new URL('../', import.meta.url);
const read = async (path) => readFile(new URL(path, root), 'utf8');

test('all five native targets expose a local camera capture path', async () => {
  const [
    iosService,
    iosView,
    androidManifest,
    androidService,
    androidView,
    harmonyManifest,
    harmonyService,
    harmonyView,
    macosInfo,
    macosService,
    macosView,
    windowsService,
    windowsView,
  ] = await Promise.all([
    read('native/ios/NikonLink/Camera/CameraService.swift'),
    read('native/ios/NikonLink/Views/RootView.swift'),
    read('native/android/app/src/main/AndroidManifest.xml'),
    read('native/android/app/src/main/java/com/tauber/nikonlink/LocalCameraController.java'),
    read('native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java'),
    read('native/harmony/entry/src/main/module.json5'),
    read('native/harmony/entry/src/main/ets/camera/LocalCameraController.ets'),
    read('native/harmony/entry/src/main/ets/pages/Index.ets'),
    read('native/macos/Info.plist'),
    read('native/macos/Sources/NikonLink/LocalCameraService.swift'),
    read('native/macos/Sources/NikonLink/main.swift'),
    read('native/windows/Services/LocalCameraService.cs'),
    read('native/windows/MainWindow.xaml.cs'),
  ]);

  assert.match(iosService, /AVCaptureSession/);
  assert.match(iosService, /builtInWideAngleCamera/);
  assert.match(iosView, /本机摄像头与 UVC/);

  assert.match(androidManifest, /android\.permission\.CAMERA/);
  assert.match(androidService, /CameraManager/);
  assert.match(androidService, /TEMPLATE_STILL_CAPTURE/);
  assert.match(androidView, /本机摄像头/);
  assert.match(androidView, /localCamera\.capture\(\)/);

  assert.match(harmonyManifest, /ohos\.permission\.CAMERA/);
  assert.match(harmonyService, /cameraPicker\.pick/);
  assert.match(harmonyView, /localCamera\.capture\(context\)/);
  assert.match(harmonyView, /HarmonyOS 系统相机接管取景/);

  assert.match(macosInfo, /NSCameraUsageDescription/);
  assert.match(macosService, /AVCapturePhotoOutput/);
  assert.match(macosService, /AVCaptureVideoDataOutput/);
  assert.match(macosView, /connectLocalCamera/);

  assert.match(windowsService, /MediaCapture/);
  assert.match(windowsService, /CapturePhotoToStreamAsync/);
  assert.match(windowsView, /ToggleLocalCameraConnectionAsync/);
  assert.match(windowsView, /本机拍摄已保存/);
});

test('local camera photos use the existing native capture workflows', async () => {
  const [android, harmony, macos, windows] = await Promise.all([
    read('native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java'),
    read('native/harmony/entry/src/main/ets/pages/Index.ets'),
    read('native/macos/Sources/NikonLink/main.swift'),
    read('native/windows/MainWindow.xaml.cs'),
  ]);

  assert.match(android, /File file = savePhoto\(jpeg, baseName, liveClip\)/);
  // E5 1.5.9：本机拍照入口接入 live 图配对后，单参重载仍保留（兼容路径）。
  assert.match(android, /private File savePhoto\(byte\[\] jpeg\)/);
  assert.match(harmony, /workflow\.store\([\s\S]*local-camera\.jpg/);
  assert.match(macos, /ZENCHE_LOCAL_/);
  assert.match(macos, /captureWorkflow\.store\(/);
  assert.match(windows, /_workflow\.StoreAsync\([\s\S]*local-camera\.jpg/);
});
