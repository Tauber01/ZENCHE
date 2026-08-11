import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../", import.meta.url);
const source = (path) => readFile(new URL(path, root), "utf8");

test("all five native libraries expose an explicit local-download action", async () => {
  const [ios, android, harmony, macos, windows] = await Promise.all([
    source("native/ios/NikonLink/Views/RootView.swift"),
    source("native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java"),
    source("native/harmony/entry/src/main/ets/pages/Index.ets"),
    source("native/macos/Sources/NikonLink/main.swift"),
    source("native/windows/MainWindow.xaml"),
  ]);

  for (const contents of [ios, android, harmony, macos, windows]) {
    assert.match(contents, /下载到本地/);
  }
});

test("Android image and video previews expose the same local-download action", async () => {
  const android = await source(
    "native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java",
  );

  assert.match(
    android,
    /private void showLargePhoto\(File file\)[\s\S]{0,4200}?Button download = nativeButton\("下载到本地", true\);[\s\S]{0,300}?downloadPhotoToLocal\(file\)/,
  );
  assert.match(
    android,
    /private void showLargeLocalVideo\(File file\)[\s\S]{0,2500}?Button download = nativeButton\("下载到本地", true\);[\s\S]{0,300}?downloadPhotoToLocal\(file\)/,
  );
});

test("Harmony preview actions bind to the selected path, not a reused filename", async () => {
  const harmony = await source(
    "native/harmony/entry/src/main/ets/pages/Index.ets",
  );

  assert.match(harmony, /@State private largePreviewPath: string = '';/);
  assert.match(
    harmony,
    /private LargePhotoOverlay\(\)[\s\S]{0,4200}?candidate\.path === this\.largePreviewPath/,
  );
  assert.doesNotMatch(
    harmony,
    /private LargePhotoOverlay\(\)[\s\S]{0,4200}?candidate\.name === this\.largePreviewName/,
  );
  assert.match(
    harmony,
    /private async openLargePhoto\(item: PhotoItem\)[\s\S]{0,1800}?this\.largePreviewPath = item\.path/,
  );
  assert.match(
    harmony,
    /private closeLargePhoto\(\): void[\s\S]{0,300}?this\.largePreviewPath = ''/,
  );
});

test("all five native libraries keep supported RAW and AVI outputs visible", async () => {
  const libraries = await Promise.all([
    source("native/ios/NikonLink/Models/AppModel.swift"),
    source("native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java"),
    source("native/harmony/entry/src/main/ets/storage/PhotoLibrary.ets"),
    source("native/macos/Sources/NikonLink/main.swift"),
    source("native/windows/Services/PhotoLibrary.cs"),
  ]);

  for (const contents of libraries) {
    assert.match(contents, /nrw/i);
    assert.match(contents, /arw/i);
    assert.match(contents, /cr2/i);
    assert.match(contents, /cr3/i);
    assert.match(contents, /avi/i);
  }
});

test("camera, AI, and editor outputs all enter the downloadable ZENCHE library", async () => {
  const [iosModel, iosView, android, harmony, macos, windows] = await Promise.all([
    source("native/ios/NikonLink/Models/AppModel.swift"),
    source("native/ios/NikonLink/Views/RootView.swift"),
    source("native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java"),
    source("native/harmony/entry/src/main/ets/pages/Index.ets"),
    source("native/macos/Sources/NikonLink/main.swift"),
    source("native/windows/MainWindow.xaml.cs"),
  ]);

  assert.match(iosModel, /func saveCapture\(/);
  assert.match(iosModel, /func saveEditedImage\(/);
  assert.match(iosView, /private func saveAiResult\(\)/);

  assert.match(android, /private File savePhoto\(/);
  assert.match(android, /private void saveAiResult/);
  assert.match(android, /private void saveRenderedEditorCopy/);

  assert.match(harmony, /private async saveAiResult\(/);
  assert.match(harmony, /private async saveEditedPhoto\(/);
  assert.match(harmony, /library\.saveReceived/);

  assert.match(macos, /captureWorkflow = CaptureWorkflow\(rootDirectory: photoDirectory\)/);
  assert.match(macos, /func saveEditedPhoto\(/);
  assert.match(macos, /private func saveAiResult\(\)/);

  assert.match(windows, /_workflow\.StoreAsync/);
  assert.match(windows, /private void AiSave_Click/);
  assert.match(windows, /private void SaveEditedPhoto_Click/);
});

test("AI and professional-editor results have direct local-download paths", async () => {
  const [ios, android, harmony, macos, windowsXaml, windows] =
    await Promise.all([
      source("native/ios/NikonLink/Views/RootView.swift"),
      source("native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java"),
      source("native/harmony/entry/src/main/ets/pages/Index.ets"),
      source("native/macos/Sources/NikonLink/main.swift"),
      source("native/windows/MainWindow.xaml"),
      source("native/windows/MainWindow.xaml.cs"),
    ]);

  assert.match(ios, /private func saveAiResultToLocal\(\)/);
  assert.match(ios, /private func saveCopyToLocal\(\)/);
  assert.match(
    ios,
    /private func saveAiResultToLocal\(\)[\s\S]{0,900}?saveEditedImage\([\s\S]{0,500}?LocalFileExportRequest/,
  );

  assert.match(android, /private void saveAiResultToLocal\(/);
  assert.match(
    android,
    /private void saveAiResultToLocal\([\s\S]{0,3200}?downloadPhotoToLocal\(destination\)/,
  );
  assert.match(
    android,
    /saveRenderedEditorCopy\([\s\S]{0,180}?false,[\s\S]{0,80}?true\)/,
  );

  assert.match(harmony, /this\.saveAiResult\(false, true\)/);
  assert.match(harmony, /this\.saveEditedPhoto\(false, true\)/);
  assert.match(
    harmony,
    /private async saveAiResult\([\s\S]{0,1800}?taskpool\.execute\(\s*copyAiResultToLibrary[\s\S]{0,900}?downloadPhotoToLocal/,
  );

  assert.match(macos, /private func saveAiResultToLocal\(\)/);
  assert.match(macos, /private func saveCopyToLocal\(\)/);
  assert.match(
    macos,
    /private func saveAiResult\(downloadToLocal: Bool\)[\s\S]{0,1100}?saveEditedPhoto\([\s\S]{0,700}?downloadPhotoToLocal/,
  );

  assert.match(windowsXaml, /Click="AiDownload_Click"/);
  assert.match(windowsXaml, /Click="DownloadEditedPhoto_Click"/);
  assert.match(windows, /private async void AiDownload_Click/);
  assert.match(windows, /private async void DownloadEditedPhoto_Click/);
});

test("Harmony prepares AI library copies in a bounded taskpool worker", async () => {
  const harmony = await source(
    "native/harmony/entry/src/main/ets/pages/Index.ets",
  );
  const workerStart = harmony.indexOf(
    "@Concurrent\nfunction copyAiResultToLibrary(",
  );
  const workerEnd = harmony.indexOf(
    "\n}\n\n@Concurrent\nfunction copyLocalExportFile(",
    workerStart,
  );
  assert.notEqual(workerStart, -1);
  assert.notEqual(workerEnd, -1);
  const worker = harmony.slice(workerStart, workerEnd);
  assert.match(worker, /outputStem !== 'ai_edited'/);
  assert.match(worker, /outputStem !== 'ai_generated'/);
  assert.match(worker, /const outputName: string = `\$\{outputStem\}\.jpg`/);
  assert.doesNotMatch(worker, /\$\{outputStem\}_edited/);
  assert.doesNotMatch(worker, /\bthis\.|@State/);
  assert.match(worker, /libraryDirectory}[\s\S]{0,120}?\.part/);
  assert.match(worker, /fs\.copyFileSync\(source\.fd, target\.fd\)/);
  assert.match(worker, /fs\.fsyncSync\(target\.fd\)/);
  assert.match(worker, /copiedBytes !== expectedBytes/);
  assert.match(worker, /fs\.renameSync\(temporaryPath, destinationPath\)/);
  assert.match(
    worker,
    /!committed[\s\S]{0,160}?fs\.unlinkSync\(temporaryPath\)/,
  );

  const saveStart = harmony.indexOf("  private async saveAiResult(");
  const saveEnd = harmony.indexOf(
    "\n  private checkAiActivated(): boolean",
    saveStart,
  );
  assert.notEqual(saveStart, -1);
  assert.notEqual(saveEnd, -1);
  const saveAiResult = harmony.slice(saveStart, saveEnd);
  assert.match(
    saveAiResult,
    /await taskpool\.execute\(\s*copyAiResultToLibrary/,
  );
  assert.match(saveAiResult, /library\.directoryPath/);
  assert.doesNotMatch(saveAiResult, /new ArrayBuffer|fs\.readSync/);
  assert.doesNotMatch(saveAiResult, /library\.saveEditedCopy/);
});

test("mobile downloads use system destination pickers and report success only after flushing", async () => {
  const [ios, android, androidLocalization, harmony] = await Promise.all([
    source("native/ios/NikonLink/Views/RootView.swift"),
    source("native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java"),
    source("native/android/app/src/main/java/com/tauber/nikonlink/Localization.java"),
    source("native/harmony/entry/src/main/ets/pages/Index.ets"),
  ]);

  assert.match(ios, /UIDocumentPickerViewController\(\s*forExporting:/);
  assert.match(ios, /asCopy: true/);
  assert.match(ios, /documentPickerWasCancelled/);
  assert.match(ios, /destinationSize == sourceSize/);

  assert.match(android, /Intent\.ACTION_CREATE_DOCUMENT/);
  assert.match(android, /pendingLocalExportFile/);
  assert.match(android, /private boolean localExportBusy/);
  assert.match(
    android,
    /if \(localExportBusy \|\| pendingLocalExportFile != null\)/,
  );
  assert.match(android, /openFileDescriptor\(\s*destination,\s*"rw"\)/);
  assert.match(android, /ParcelFileDescriptor/);
  assert.match(android, /Os\.fstat\(input\.getFD\(\)\)/);
  assert.match(android, /sourceStat\.st_dev == destinationStat\.st_dev/);
  assert.match(android, /Os\.ftruncate\(descriptor\.getFileDescriptor\(\), 0\)/);
  assert.match(android, /getFD\(\)\.sync\(\)/);
  assert.match(
    android,
    /destinationBytes = Os\.fstat\([\s\S]{0,100}?\.st_size;[\s\S]{0,120}?destinationBytes != expectedBytes/,
  );
  assert.match(android, /protected void onSaveInstanceState\(Bundle outState\)/);
  assert.match(android, /outState\.putString\(STATE_PENDING_LOCAL_EXPORT/);
  assert.match(android, /restorePendingLocalExport\(state\)/);
  assert.match(android, /pendingLocalExportRelativePath\(restored\)/);
  assert.match(
    android,
    /if \(source == null\)[\s\S]{0,220}?cleanupIncompleteLocalExport/,
  );
  assert.match(android, /DocumentsContract\.deleteDocument/);
  assert.match(
    android,
    /finally \{[\s\S]{0,180}?mainHandler\.post\(\(\) -> localExportBusy = false\)/,
  );
  for (const message of [
    "系统未返回保存位置",
    "源文件状态已失效，请重试",
    "保存位置不能与源文件相同",
    "准备 AI 本地副本失败：",
  ]) {
    assert.match(androidLocalization, new RegExp(message));
  }

  assert.match(harmony, /new picker\.DocumentSaveOptions\(\)/);
  assert.match(harmony, /documentPicker\.save\(options\)/);
  assert.match(harmony, /@Concurrent[\s\S]{0,120}?copyLocalExportFile/);
  assert.match(harmony, /taskpool\.execute\(\s*copyLocalExportFile/);
  assert.match(
    harmony,
    /openSync\(sourcePath,[\s\S]{0,180}?statSync\(source\.fd\)[\s\S]{0,220}?openSync\(\s*destinationUri/,
  );
  assert.match(
    harmony,
    /sourceStat\.ino === destinationStat\.ino[\s\S]{0,120}?return -1/,
  );
  assert.match(
    harmony,
    /fs\.truncateSync\(target\.fd, 0\)[\s\S]{0,120}?fs\.copyFileSync/,
  );
  assert.doesNotMatch(
    harmony,
    /destinationUri,[\s\S]{0,80}?fs\.OpenMode\.READ_WRITE\s*\|\s*fs\.OpenMode\.TRUNC/,
  );
  assert.match(
    harmony,
    /if \(copiedBytes < 0\)[\s\S]{0,260}?destinationUri = ''[\s\S]{0,260}?该文件已位于所选位置/,
  );
  assert.match(harmony, /fs\.fsyncSync\(target\.fd\)/);
  assert.match(harmony, /businessError\.code === 13900012/);
});

test("iOS coordinates provider verification and exposes export results accessibly", async () => {
  const ios = await source("native/ios/NikonLink/Views/RootView.swift");

  assert.match(
    ios,
    /private func localExportMatchesSource\([\s\S]{0,180}?\) async -> Bool/,
  );
  assert.match(
    ios,
    /Task\.detached\(priority: \.utility\)[\s\S]{0,900}?NSFileCoordinator\(filePresenter: nil\)[\s\S]{0,400}?coordinate\(/,
  );
  assert.match(
    ios,
    /private struct LibraryPage: View[\s\S]{0,12500}?@State private var localExportResult: String\?[\s\S]{0,12500}?model\.statusMessage = result[\s\S]{0,1200}?\.alert\(/,
  );
  assert.match(
    ios,
    /private struct LibraryLargePhotoView: View[\s\S]{0,6500}?ViewThatFits\(in: \.horizontal\)[\s\S]{0,6500}?localExportResult = result[\s\S]{0,1200}?\.alert\(/,
  );
  for (const label of ["关闭", "编辑", "下载到本地", "分享到社交平台"]) {
    assert.match(ios, new RegExp(`accessibilityLabel\\(\"${label}\"\\)`));
  }
});

test("desktop downloads guard the source and publish copies atomically", async () => {
  const [macos, windows] = await Promise.all([
    source("native/macos/Sources/NikonLink/main.swift"),
    source("native/windows/MainWindow.xaml.cs"),
  ]);

  assert.match(macos, /NSSavePanel\(\)/);
  assert.match(macos, /canonicalDownloadDestination\(/);
  assert.match(macos, /\.zenche-download-/);
  assert.match(macos, /replaceItemAt\(/);

  assert.match(windows, /new SaveFileDialog/);
  assert.match(windows, /Path\.GetFullPath\(sourcePath\)/);
  assert.match(windows, /\.zenche-download-/);
  assert.match(windows, /Flush\(flushToDisk: true\)/);
  assert.match(windows, /File\.Replace\(temporaryPath, destinationFullPath, null\)/);
  assert.match(windows, /File\.Move\(temporaryPath, destinationFullPath\)/);
});

test("macOS local downloads resolve file identity and copy off the main thread", async () => {
  const macos = await source("native/macos/Sources/NikonLink/main.swift");

  assert.match(macos, /@Published private\(set\) var localDownloadBusy = false/);
  assert.match(macos, /guard !localDownloadBusy else \{ return \}/);
  assert.match(macos, /fileResourceIdentifierKey/);
  assert.match(macos, /fileResourceIdentifiersMatch\(/);
  assert.match(macos, /URL\(\s*resolvingAliasFileAt:/);
  assert.match(
    macos,
    /let resolvedParent = resolvedFileURL\([\s\S]{0,500}?appendingPathComponent\(filename, isDirectory: false\)/,
  );
  assert.equal(
    (macos.match(/try ensureDownloadDestinationIsDistinct\(/g) ?? []).length,
    2,
    "macOS must compare source/destination identity before copying and again before publish",
  );
  assert.match(
    macos,
    /localDownloadBusy = true[\s\S]{0,300}?guard response == \.OK,[\s\S]{0,180}?localDownloadBusy = false[\s\S]{0,80}?return/,
  );
  assert.match(
    macos,
    /localDownloadQueue\.async \{[\s\S]{0,320}?Self\.copyPhotoToLocal\(/,
  );
  assert.match(
    macos,
    /DispatchQueue\.main\.async \{ \[weak self\] in[\s\S]{0,180}?localDownloadBusy = false/,
  );
  assert.match(macos, /\.disabled\(model\.localDownloadBusy\)/);
});

test("Windows local downloads use stable file identity and leave the UI responsive", async () => {
  const windows = await source("native/windows/MainWindow.xaml.cs");

  assert.match(windows, /private bool _localDownloadBusy/);
  assert.match(
    windows,
    /private async Task<bool> DownloadFileToLocalAsync\(/,
  );
  assert.match(
    windows,
    /if \(_localDownloadBusy\)[\s\S]{0,100}?return false/,
  );
  assert.match(
    windows,
    /_localDownloadBusy = true;[\s\S]{0,120}?dialog\.ShowDialog\(dialogOwner \?\? this\)/,
  );
  assert.match(
    windows,
    /ShowLargePhoto\([\s\S]{0,4200}?DownloadPhotoToLocalAsync\(item, viewer\)/,
  );
  assert.match(
    windows,
    /ShowLargeVideo\([\s\S]{0,2800}?DownloadPhotoToLocalAsync\(item, viewer\)/,
  );
  assert.match(
    windows,
    /await Task\.Run\(\(\) => CopyFileToLocalAtomically\(/,
  );

  assert.match(windows, /GetFileInformationByHandle\(/);
  assert.match(windows, /source\.SafeFileHandle/);
  assert.match(windows, /destination\.SafeFileHandle/);
  assert.match(windows, /sourceIdentity == destinationIdentity/);
  assert.match(
    windows,
    /EnsureDestinationIsNotSource\([\s\S]{0,180}?File\.Replace\(/,
  );

  assert.match(
    windows,
    /using var source = new FileStream\([\s\S]{0,500}?var sourceLength = source\.Length;[\s\S]{0,120}?if \(sourceLength == 0\)/,
  );
});

test("Windows direct AI and editor downloads prepare full-resolution copies off the UI thread", async () => {
  const windows = await source("native/windows/MainWindow.xaml.cs");

  assert.match(windows, /private bool _localDownloadPreparationBusy/);
  assert.match(
    windows,
    /if \(_localDownloadPreparationBusy && !preparationOwner\)/,
  );
  assert.match(
    windows,
    /private async void AiDownload_Click[\s\S]{0,2400}?var sourcePath = _aiResultPath;[\s\S]{0,700}?_localDownloadPreparationBusy = true;[\s\S]{0,500}?await Task\.Run\(\(\) => SaveAiResultCopyCore\([\s\S]{0,900}?preparationOwner: true\)[\s\S]{0,700}?_localDownloadPreparationBusy = false/,
  );
  assert.match(
    windows,
    /private async void DownloadEditedPhoto_Click[\s\S]{0,2800}?var sourcePath = _editorSelectedPath;[\s\S]{0,300}?var adjustments = _editorAdjustments\.Copy\(\);[\s\S]{0,300}?var nikonCloudPreset = _selectedNikonCloudPreset;[\s\S]{0,500}?_localDownloadPreparationBusy = true;[\s\S]{0,500}?await Task\.Run\(\(\) => SaveEditedPhotoCopyCore\([\s\S]{0,1000}?preparationOwner: true\)[\s\S]{0,800}?_localDownloadPreparationBusy = false/,
  );
  assert.match(
    windows,
    /private static void SaveAiResultCopyCore\([\s\S]{0,900}?BitmapDecoder\.Create\([\s\S]{0,400}?SaveBitmapAtomically\(/,
  );
  assert.match(
    windows,
    /private static void SaveEditedPhotoCopyCore\([\s\S]{0,600}?RenderEditedBitmap\([\s\S]{0,300}?SaveBitmapAtomically\(/,
  );
  assert.match(
    windows,
    /private void AiSave_Click[\s\S]{0,300}?if \(_localDownloadPreparationBusy \|\| _localDownloadBusy\)[\s\S]{0,180}?SaveAiResultCopy\(\)/,
  );
  assert.match(
    windows,
    /private string\? SaveAiResultCopy\(\)[\s\S]{0,220}?if \(_localDownloadPreparationBusy \|\| _localDownloadBusy\)/,
  );
  assert.match(
    windows,
    /_localDownloadPreparationBusy = true;[\s\S]{0,180}?AiSaveBtn\.IsEnabled = false;[\s\S]{0,120}?AiDownloadBtn\.IsEnabled = false;[\s\S]{0,1800}?AiSaveBtn\.IsEnabled = canSave;[\s\S]{0,120}?AiDownloadBtn\.IsEnabled = canSave/,
  );
  assert.match(
    windows,
    /private void SaveEditedPhoto_Click[\s\S]{0,320}?if \(_localDownloadPreparationBusy \|\| _localDownloadBusy\)[\s\S]{0,180}?SaveEditedPhotoCopy\(\)/,
  );
  assert.match(
    windows,
    /private string\? SaveEditedPhotoCopy\(\)[\s\S]{0,220}?if \(_localDownloadPreparationBusy \|\| _localDownloadBusy\)/,
  );
  assert.match(
    windows,
    /_localDownloadPreparationBusy = true;[\s\S]{0,180}?SaveEditedPhotoButton\.IsEnabled = false;[\s\S]{0,140}?DownloadEditedPhotoButton\.IsEnabled = false;[\s\S]{0,2100}?SaveEditedPhotoButton\.IsEnabled = canSave;[\s\S]{0,140}?DownloadEditedPhotoButton\.IsEnabled = canSave/,
  );
});
