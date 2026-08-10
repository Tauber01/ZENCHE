import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../", import.meta.url);
const read = async (path) => readFile(new URL(path, root), "utf8");

test("five native AI clients use the production HTTPS proxy and migrate only the legacy default", async () => {
  const [ios, android, harmony, macos, windows] = await Promise.all([
    read("native/ios/NikonLink/Views/RootView.swift"),
    read("native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java"),
    read("native/harmony/entry/src/main/ets/pages/Index.ets"),
    read("native/macos/Sources/NikonLink/main.swift"),
    read("native/windows/MainWindow.xaml.cs"),
  ]);

  for (const source of [ios, android, harmony, macos, windows]) {
    assert.match(source, /https:\/\/zenche\.top\/api/);
    assert.match(source, /http:\/\/101\.34\.255\.115:8787/);
    assert.match(source, /\/v1\/ai/);
    assert.match(source, /Bearer/);
  }
  assert.match(android, /AI_SERVER_LEGACY\.equals\(normalized\)/);
  assert.match(harmony, /normalized === AI_SERVER_LEGACY/);
  assert.match(ios, /normalized == legacyServer/);
  assert.match(macos, /normalized == legacyServer/);
  assert.match(windows, /string\.Equals\(value, AiServerLegacy/);

  assert.match(android, /body\.put\("image", "data:"[\s\S]*?base64/);
  assert.match(android, /first\.optString\("b64_json"/);
  assert.match(harmony, /body\['image'\] = `data:\$\{this\.imageMimeType/);
  assert.match(harmony, /first\['b64_json'\]/);

  const staleCopy = "基于 nano-banana-2 模型的 AI 修图与生图；需在设置中配置 API Key。";
  assert.ok(!android.includes(staleCopy));
  assert.ok(!harmony.includes(staleCopy));
});

test("Android system photo editing bounds and cleans Uri copies, then exports a new MediaStore asset", async () => {
  const [activity, bridge, workflow, manifest] = await Promise.all([
    read("native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java"),
    read("native/android/app/src/main/java/com/tauber/nikonlink/SystemPhotoEditBridge.java"),
    read("native/android/app/src/main/java/com/tauber/nikonlink/CaptureWorkflow.java"),
    read("native/android/app/src/main/AndroidManifest.xml"),
  ]);

  assert.match(bridge, /MediaStore\.ACTION_PICK_IMAGES/);
  assert.match(bridge, /Intent\.ACTION_OPEN_DOCUMENT/);
  assert.match(bridge, /resolver\.openInputStream\(sourceUri\)/);
  assert.match(bridge, /OpenableColumns\.SIZE/);
  assert.match(bridge, /MAX_IMPORT_BYTES = 64L \* 1024L \* 1024L/);
  assert.match(bridge, /new SizeLimitedInputStream\(input, MAX_IMPORT_BYTES\)/);
  assert.match(bridge, /workflow\.importFile\(/);
  assert.doesNotMatch(bridge, /new File\(sourceUri/);
  assert.match(bridge, /resolver\.insert\(\s*MediaStore\.Images\.Media\.EXTERNAL_CONTENT_URI/);
  assert.match(bridge, /MediaStore\.Images\.Media\.IS_PENDING/);
  assert.match(bridge, /resolver\.update\(destination, ready/);
  assert.match(bridge, /resolver\.delete\(destination/);
  assert.match(bridge, /Settings\.ACTION_APPLICATION_DETAILS_SETTINGS/);
  assert.match(manifest, /WRITE_EXTERNAL_STORAGE"\s*android:maxSdkVersion="28"/);
  assert.match(activity, /editorSelectedPath = copy\.getAbsolutePath\(\)/);
  assert.match(activity, /requestCode == REQUEST_EDITOR_SYSTEM_PHOTO[\s\S]*?editorSystemPhotoStatus = ""/);
  assert.match(activity, /saveEditedCopyToSystemAlbum\(File editedFile\)/);
  assert.match(workflow, /System\.nanoTime\(\) \+ "\.importing"/);
  assert.match(workflow, /finally \{[\s\S]*?deleteImportArtifacts\(staging, destination\)/);
  assert.match(workflow, /staging\.delete\(\)[\s\S]*?destination\.delete\(\)/);
});

test("iOS system photo editing imports an app-owned working copy and exports a new Photos asset", async () => {
  const model = await read("native/ios/NikonLink/Models/AppModel.swift");

  assert.match(model, /func importSystemPhotoForEditing\(/);
  assert.match(model, /options\.isNetworkAccessAllowed = true/);
  assert.match(model, /self\.importPhotoData\(/);
  assert.match(model, /UIApplication\.openSettingsURLString/);
  assert.match(model, /requestAuthorization\(for: \.addOnly\)/);
  assert.match(model, /PHAssetCreationRequest\.forAsset\(\)/);
  assert.match(model, /request\.addResource\(with: resourceType, fileURL: url/);
  assert.doesNotMatch(model, /performChanges[\s\S]{0,300}changeRequest\(for: asset\)/);
});

test("HarmonyOS system photo editing imports a picker Uri copy and saves through the system consent dialog", async () => {
  const source = await read("native/harmony/entry/src/main/ets/pages/Index.ets");

  assert.match(source, /private async openSystemPhotoForEditing\(\)/);
  assert.match(source, /options\.maxSelectNumber = 1/);
  assert.match(source, /workflow\.importFromUri\(\s*result\.photoUris\[0\]/);
  assert.match(source, /this\.editorSelectedPath = importedPath/);
  assert.match(source, /private async saveEditedCopyToSystemAlbum\(path: string\)/);
  assert.match(source, /showAssetsCreationDialog\(\s*\[`file:\/\/\$\{path\}`\]/);
  assert.match(source, /photoAccessHelper\.PhotoType\.IMAGE/);
  assert.match(source, /photoAccessHelper\.PhotoSubtype\.DEFAULT/);
});

test("Android editor normalizes all eight JPEG EXIF orientations before preview, analysis, and export", async () => {
  const [decoder, activity] = await Promise.all([
    read("native/android/app/src/main/java/com/tauber/nikonlink/EditorBitmapDecoder.java"),
    read("native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java"),
  ]);

  assert.match(decoder, /ORIENTATION_TAG = 0x0112/);
  for (let orientation = 2; orientation <= 8; orientation++) {
    assert.match(decoder, new RegExp(`case ${orientation}:`));
  }
  assert.match(decoder, /payload\[tiff\] == 'I'[\s\S]*?payload\[tiff\] == 'M'/);
  assert.match(decoder, /int orientation = parseExifOrientation\(payload\);[\s\S]*?if \(orientation >= 1 && orientation <= 8\) return orientation/);
  assert.match(decoder, /Bitmap\.createBitmap\([\s\S]*?matrix/);
  assert.match(activity, /renderEditorAnalysisBitmap\([\s\S]*?return EditorBitmapDecoder\.decode\(file, maximumDimension\)/);
  assert.match(activity, /renderEditedBitmap\([\s\S]*?Bitmap source = EditorBitmapDecoder\.decode\(file, maximumDimension\)/);
  assert.match(activity, /decodeEditorThumbnail\([\s\S]*?EditorBitmapDecoder\.decode\(/);
});
