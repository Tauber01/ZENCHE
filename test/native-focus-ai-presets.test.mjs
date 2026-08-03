import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const root = new URL('../', import.meta.url);
const read = async (path) => readFile(new URL(path, root), 'utf8');

test('native AI workspaces expose composable preset modules and clear actions', async () => {
  const sources = await Promise.all([
    read('native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java'),
    read('native/harmony/entry/src/main/ets/pages/Index.ets'),
    read('native/ios/NikonLink/Views/RootView.swift'),
    read('native/macos/Sources/NikonLink/main.swift'),
    read('native/windows/MainWindow.xaml.cs'),
  ]);
  for (const source of sources) {
    assert.match(source, /主体/);
    assert.match(source, /光线/);
    assert.match(source, /composeAiPrompt|ComposeAiPrompt/);
    assert.match(source, /清空/);
  }
});

test('uniform previews map taps through the displayed image rectangle', async () => {
  const [android, harmony, macos, windows] = await Promise.all([
    read('native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java'),
    read('native/harmony/entry/src/main/ets/pages/Index.ets'),
    read('native/macos/Sources/NikonLink/main.swift'),
    read('native/windows/MainWindow.xaml.cs'),
  ]);
  assert.match(android, /normalizePreviewPoint/);
  assert.match(android, /previewImageRect/);
  assert.match(harmony, /normalizeMonitorPoint/);
  assert.match(harmony, /onAreaChange/);
  assert.match(macos, /focusNormalized/);
  assert.match(macos, /monitorImageRect/);
  assert.match(windows, /GetUniformImageRect/);
  assert.match(windows, /rect\.Contains/);
});

test('PTP focus feedback distinguishes a focus step from native 2D point focus', async () => {
  const sources = await Promise.all([
    read('native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java'),
    read('native/harmony/entry/src/main/ets/pages/Index.ets'),
    read('native/macos/Sources/NikonLink/main.swift'),
    read('native/windows/MainWindow.xaml.cs'),
  ]);
  for (const source of sources) {
    assert.match(source, /不支持二维对焦点/);
  }
});

test('macOS gphoto focus drive treats Nikon busy I/O as transient and uses signed steps', async () => {
  const macos = await read('native/macos/Sources/NikonLink/main.swift');
  assert.match(macos, /i\/o in progress/);
  assert.match(macos, /error \(-110/);
  assert.match(macos, /case 1: amount = 128/);
  assert.match(macos, /case 2: amount = 512/);
  assert.match(macos, /amount = 1024/);
  assert.match(macos, /viewfinder=1/);
  assert.match(macos, /isManualFocusDriveCommand/);
  assert.match(macos, /waitUntilDeviceReady\(timeout: 8\)/);
  assert.match(macos, /manualfocusdrive=\\\(manualFocusDriveValue\(for: normalized\)\)/);
});

test('native editors expose the branch library hierarchy with photo thumbnails', async () => {
  const sources = await Promise.all([
    read('native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java'),
    read('native/harmony/entry/src/main/ets/pages/Index.ets'),
    read('native/ios/NikonLink/Views/RootView.swift'),
    read('native/macos/Sources/NikonLink/main.swift'),
    read('native/windows/MainWindow.xaml.cs'),
  ]);
  assert.match(sources[0], /showEditorPhotoPickerDialog|buildEditorPickerFileRow/);
  assert.match(sources[0], /decodeEditorThumbnail/);
  assert.match(sources[1], /EditorPhotoPicker|editablePhotosForBranch/);
  assert.match(sources[1], /Image\(`file:\/\//);
  assert.match(sources[2], /LibraryBranchStore|editorBranchMenu/);
  assert.match(sources[2], /UIImage\(contentsOfFile/);
  assert.match(sources[3], /MacLibraryBranchStore|editorBranchMenu/);
  assert.match(sources[3], /NSImage\(contentsOf/);
  assert.match(sources[4], /EditorPhotoTree|BuildEditorPhotoTree/);
  assert.match(sources[4], /CreateLibraryThumbnail/);
});

test('macOS editor menu uses a physically bounded ImageIO thumbnail', async () => {
  const macos = await read('native/macos/Sources/NikonLink/main.swift');
  assert.match(macos, /import ImageIO/);
  assert.match(macos, /CGImageSourceCreateThumbnailAtIndex/);
  assert.match(macos, /kCGImageSourceThumbnailMaxPixelSize: 96/);
  const menuStart = macos.indexOf('private func editorPhotoMenuItem');
  const menuEnd = macos.indexOf('private func editorBranchMenu', menuStart);
  assert.ok(menuStart >= 0 && menuEnd > menuStart);
  const menu = macos.slice(menuStart, menuEnd);
  assert.match(menu, /editorMenuThumbnail\(for: photo\)/);
  assert.doesNotMatch(menu, /NSImage\(contentsOf: photo\.url\)/);
});
