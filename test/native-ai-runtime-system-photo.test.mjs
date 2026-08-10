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

test("mobile editors expose system-photo import and save-new-copy actions in both manual and AI workflows", async () => {
  const [android, ios, harmony] = await Promise.all([
    read("native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java"),
    read("native/ios/NikonLink/Views/RootView.swift"),
    read("native/harmony/entry/src/main/ets/pages/Index.ets"),
  ]);

  assert.match(android, /buildEditorSourceCard\(List<File> photos\)/);
  assert.match(android, /buildEditorSourceCard\(photos\)[\s\S]*?文件库中没有可编辑照片/);
  assert.match(android, /从系统相册导入/);
  assert.match(android, /saveRenderedEditorCopy\([^)]*true\)/);
  assert.match(android, /saveAiResultToSystemAlbum/);
  assert.match(android, /File dest = source != null\s*\? uniqueEditedFile\(source\)/);

  assert.match(ios, /private var editorSourcePicker: some View/);
  assert.match(ios, /showingEditorSystemPhotos = true/);
  assert.match(ios, /editorSystemPhotoPickerSheet/);
  assert.match(ios, /saveCopyToSystemPhotos\(\)/);
  assert.match(ios, /saveAiResultToSystemPhotos\(\)/);
  assert.match(ios, /private func saveAiResult\(\)[\s\S]*?saveEditedImage\(/);
  assert.doesNotMatch(ios, /private func saveAiResult\(\)[\s\S]{0,800}?replaceEditedImage\(/);

  assert.match(harmony, /private EditorPhotoPicker\(\)[\s\S]*?从系统相册导入[\s\S]*?openSystemPhotoForEditing\(\)/);
  assert.match(harmony, /private async saveEditedPhoto\(exportToSystemAlbum: boolean = false\)/);
  assert.match(harmony, /saveEditedPhoto\(true\)/);
  assert.match(harmony, /private async saveAiResult\(exportToSystemAlbum: boolean = false\)/);
  assert.match(harmony, /saveAiResult\(true\)/);
  assert.match(harmony, /private async saveAiResult[\s\S]*?library\.saveEditedCopy\(/);
  assert.doesNotMatch(harmony, /private async saveAiResult[\s\S]{0,1600}?library\.replaceFile\(/);

  for (const source of [android, ios, harmony]) {
    assert.match(source, /保存(?:新副本)?到系统相册/);
    assert.match(source, /原片保持不变|原文件保持不变/);
  }
});

test("mobile system-photo and AI result states use exact runtime localization paths", async () => {
  const [android, androidLocalization, ios, iosEn, iosJa, harmony, harmonyLocalization] =
    await Promise.all([
      read("native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java"),
      read("native/android/app/src/main/java/com/tauber/nikonlink/Localization.java"),
      read("native/ios/NikonLink/Views/RootView.swift"),
      read("native/ios/NikonLink/en.lproj/Localizable.strings"),
      read("native/ios/NikonLink/ja.lproj/Localizable.strings"),
      read("native/harmony/entry/src/main/ets/pages/Index.ets"),
      read("native/harmony/entry/src/main/ets/localization/Localization.ets"),
    ]);

  assert.match(android, /private TextView text[\s\S]*?text\.setText\(tr\(value\)\)/);
  assert.match(android, /private Button nativeButton[\s\S]*?button\.setText\(tr\(label\)\)/);
  assert.match(android, /setContentDescription\(\s*tr\("从系统相册选择照片并创建可编辑副本"\)\s*\)/);
  assert.match(android, /setContentDescription\(\s*tr\("将当前 AI 结果作为新照片保存到系统相册"\)\s*\)/);
  assert.match(android, /setContentDescription\(\s*tr\("渲染当前调整并在系统相册创建新照片"\)\s*\)/);
  assert.match(android, /tr\("可编辑照片"\) \+ " · " \+ photos\.size\(\)/);
  assert.match(android, /setTitle\(tr\("需要照片写入权限"\)\)/);
  assert.match(android, /setMessage\(tr\(editorSystemPhotoStatus\)\)/);
  assert.match(android, /setNegativeButton\(tr\("取消"\), null\)/);
  assert.match(android, /tr\("打开系统设置"\)/);
  for (const prefix of ["无法打开系统相册：", "系统照片导入失败：", "系统相册保存失败："]) {
    assert.match(androidLocalization, new RegExp(`add\\("${prefix}"`));
  }

  assert.match(ios, /description: Text\(\s*RuntimeLocalization\.text\(\s*editorSystemPhotoStatus,\s*locale: locale/);
  assert.match(ios, /RuntimeLocalization\.format\(\s*"显示已允许访问的 %lld 张照片"/);
  assert.match(ios, /RuntimeLocalization\.format\(\s*"最近 %lld 张照片"/);
  assert.match(ios, /RuntimeLocalization\.format\(\s*"导入 %@"/);
  for (const table of [iosEn, iosJa]) {
    assert.match(table, /"显示已允许访问的 %lld 张照片" = ".+%lld.+";/);
    assert.match(table, /"最近 %lld 张照片" = ".+%lld.+";/);
    assert.match(table, /"导入 %@" = "[^"\n]*%@[^"\n]*";/);
  }

  assert.match(harmony, /Text\(`\$\{this\.tr\('可编辑照片'\)\} · \$\{this\.editablePhotos\(\)\.length\}`\)/);
  assert.match(harmony, /Button\(this\.tr\(this\.editorSaving \? '正在保存…' : '保存到文件库'\)/);
  assert.match(harmony, /this\.tr\(this\.editorSaving \? '正在保存…' : '保存新副本到系统相册'\)/);
  assert.match(harmony, /Text\(this\.tr\(this\.aiGenerating \? '正在调用 AI 模型…' : this\.aiStatus\)\)/);
  assert.match(harmonyLocalization, /new TranslationEntry\('可编辑照片', 'Editable Photos', '編集可能な写真'\)/);
  assert.match(harmonyLocalization, /new TranslationEntry\('保存到文件库', 'Save to Library', 'ライブラリに保存'\)/);
  assert.match(harmonyLocalization, /new TranslationEntry\('保存 AI 结果失败', 'Unable to save the AI result', 'AI 結果を保存できません'\)/);
  assert.match(harmonyLocalization, /new TranslationEntry\('已保存 AI 结果', 'AI result saved', 'AI 結果を保存しました'\)/);
  assert.match(harmony, /Button\(`\$\{this\.aiMode === 0 \? '●' : '○'\} \$\{this\.tr\('AI 修图'\)\}`/);
  assert.match(harmony, /placeholder: this\.tr\(this\.aiMode === 0 \? '输入修图描述…（可补充）' : '输入生图描述…（可补充）'\)/);
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
