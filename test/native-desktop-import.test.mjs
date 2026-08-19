import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../", import.meta.url);

const requiredExtensions = [
  "jpg",
  "jpeg",
  "png",
  "heic",
  "heif",
  "tif",
  "tiff",
  "nef",
  "nrw",
  "arw",
  "cr2",
  "cr3",
  "mov",
  "mp4",
  "m4v",
  "avi",
];

async function readSource(path) {
  return readFile(new URL(path, root), "utf8");
}

function sliceFunction(source, signature, nextSignature) {
  const start = source.indexOf(signature);
  assert.notEqual(start, -1, `missing function ${signature}`);
  const end = source.indexOf(nextSignature, start + signature.length);
  return end === -1
    ? source.slice(start)
    : source.slice(start, end);
}

test("macOS import path streams files and never loads the whole source into memory", async () => {
  const macos = await readSource("native/macos/Sources/NikonLink/CaptureWorkflow.swift");
  assert.match(macos, /func importFile\(/);
  const body = sliceFunction(
    macos,
    "func importFile(",
    "func importFileAsync("
  );
  assert.doesNotMatch(
    body,
    /Data\(contentsOf:/,
    "importFile must not load the entire file into memory"
  );
  assert.match(body, /FileHandle\(forReadingFrom:/);
  assert.match(body, /FileHandle\(forWritingTo:/);
  assert.match(body, /synchronize\(\)/);
  assert.match(body, /shouldCancel/);
  assert.match(body, /moveItem\(at: temp, to: destination\)/);
  assert.match(body, /\.zenche-import-/);
  assert.match(body, /\.part/);
});

test("Windows import path streams files and never loads the whole source into memory", async () => {
  const windows = await readSource("native/windows/Services/CaptureWorkflow.cs");
  assert.match(windows, /public async Task<string> ImportAsync\(/);
  const body = sliceFunction(
    windows,
    "public async Task<string> ImportAsync(",
    "public async Task<BatchImportResult> BatchImportAsync("
  );
  assert.doesNotMatch(
    body,
    /ReadAllBytesAsync/,
    "ImportAsync must not load the entire file into memory"
  );
  assert.match(body, /new FileStream\(/);
  assert.match(body, /CopyToAsync\(/);
  assert.match(body, /FlushAsync\(/);
  assert.match(body, /Flush\(flushToDisk: true\)/);
  assert.match(body, /File\.Move\(tempPath, destination\)/);
  assert.match(body, /\.zenche-import-/);
  assert.match(body, /\.part/);
});

test("both backends expose the required import extensions and reject unsupported files", async () => {
  const macos = await readSource("native/macos/Sources/NikonLink/CaptureWorkflow.swift");
  const windows = await readSource("native/windows/Services/CaptureWorkflow.cs");

  for (const ext of requiredExtensions) {
    assert.ok(
      macos.includes(`"${ext}"`),
      `macOS is missing supported extension ${ext}`
    );
    assert.ok(
      windows.includes(`".${ext}"`) || windows.includes(`".${ext.toUpperCase()}"`),
      `Windows is missing supported extension .${ext}`
    );
  }

  assert.match(macos, /unsupportedExtension/);
  assert.match(windows, /IsSupportedImportExtension/);
  assert.match(windows, /不支持的文件格式/);
});

test("import validates byte count before atomic publish", async () => {
  const macos = await readSource("native/macos/Sources/NikonLink/CaptureWorkflow.swift");
  const windows = await readSource("native/windows/Services/CaptureWorkflow.cs");

  assert.match(macos, /tempSize == sourceSize/);
  assert.match(windows, /tempInfo\.Length != sourceInfo\.Length/);
});

test("import cancellation interrupts active work and published failures roll back", async () => {
  const macos = await readSource("native/macos/Sources/NikonLink/CaptureWorkflow.swift");
  const windows = await readSource("native/windows/Services/CaptureWorkflow.cs");

  assert.match(macos, /withTaskCancellationHandler/);
  assert.match(macos, /ImportCancellationSignal/);
  assert.match(macos, /guard !shouldCancel\(\)/);
  assert.match(macos, /if published \{[\s\S]*?removeImportArtifact\([\s\S]*?at: destination/);
  assert.match(macos, /expectedParent: primaryDirectory/);
  assert.match(macos, /rollbackError\.rollbackErrors \+ cleanupErrors/);
  assert.doesNotMatch(
    sliceFunction(macos, "private func importFileInBatch(", "func importFileAsync("),
    /try\? fileManager\.removeItem/
  );
  assert.match(macos, /transactionalImport: true/);
  assert.match(macos, /restoreImportMetadata\(snapshot\)/);
  assert.match(windows, /CopyToAsync\([\s\S]*?cancellationToken\)/);
  assert.match(windows, /if \(published\)[\s\S]*?DeleteImportArtifactAsync\(destination, PrimaryDirectory\)/);
  assert.match(windows, /new List<Exception> \{ failure \}/);
  assert.match(windows, /failures\.AddRange\(cleanupFailures\)/);
  assert.doesNotMatch(
    sliceFunction(windows, "private async Task<string> ImportCoreAsync(", "public sealed record BatchImportResult("),
    /TryDelete\(/
  );
  assert.match(windows, /transactionalImport: true/);
  assert.match(windows, /RestoreImportMetadataAsync\(snapshot\)/);
  const windowsCleanup = sliceFunction(
    windows,
    "private async Task DeleteImportArtifactAsync(",
    "private static string ResolvePathForContainment("
  );
  assert.match(windowsCleanup, /Path\.GetFullPath\(Path\.GetDirectoryName\(destination\)!\)/);
  assert.match(windowsCleanup, /DeleteRollbackFileAsync\(destination\)/);
  assert.doesNotMatch(windowsCleanup, /catch/);
  assert.doesNotMatch(windowsCleanup, /\.xmp|BackupDirectory/);
});

test("macOS finalize hashes and backs up large imports without whole-file reads", async () => {
  const macos = await readSource("native/macos/Sources/NikonLink/CaptureWorkflow.swift");
  const finalize = sliceFunction(
    macos,
    "private func finalize(",
    "private func replaceChecksumEntry("
  );
  assert.doesNotMatch(finalize, /Data\(contentsOf: primary\)/);
  assert.match(finalize, /sha256Hex\(/);
  assert.match(finalize, /copyFileAtomically\(/);
});

test("import never overwrites an existing destination", async () => {
  const macos = await readSource("native/macos/Sources/NikonLink/CaptureWorkflow.swift");
  const windows = await readSource("native/windows/Services/CaptureWorkflow.cs");

  assert.match(macos, /uniqueURL\(\s*in: primaryDirectory,/);
  assert.match(windows, /UniquePath\(PrimaryDirectory, baseName, extension\)/);
});

test("desktop UI exposes a primary import entry and routes cloud guide to the same picker", async () => {
  const macosXaml = await readSource("native/macos/Sources/NikonLink/main.swift");
  const windowsXaml = await readSource("native/windows/MainWindow.xaml");
  const windowsCode = await readSource("native/windows/MainWindow.xaml.cs");

  assert.match(macosXaml, /RuntimeLocalization\.text\("导入照片与视频"/);
  assert.match(macosXaml, /Button \{\s*openMediaImporter\(\)/);
  assert.match(macosXaml, /MacCloudDriveGuide \{[\s\S]*?openMediaImporter\(\)/);
  assert.match(macosXaml, /NSOpenPanel/);

  assert.match(windowsXaml, /Content="导入照片与视频"/);
  assert.match(windowsCode, /ImportMedia_Click/);
  assert.match(windowsCode, /OpenMediaFilePicker\(/);
  assert.match(
    windowsCode,
    /choose\.Click \+= async \(_, _\) =>\s*\{\s*guide\.Close\(\);\s*await OpenMediaFilePicker/
  );
});

test("desktop pickers advertise the same extension set", async () => {
  const macos = await readSource("native/macos/Sources/NikonLink/main.swift");
  const windows = await readSource("native/windows/MainWindow.xaml.cs");
  const macosPicker = sliceFunction(
    macos,
    "private func openMediaImporter()",
    "@ViewBuilder"
  );

  for (const ext of requiredExtensions) {
    assert.ok(macosPicker.includes(`"${ext}"`), `macOS picker should cover ${ext}`);
    assert.ok(
      windows.includes(`*.${ext}`) || windows.includes(`*.${ext.toUpperCase()}`),
      `Windows picker filter should cover *.${ext}`
    );
  }
});

test("batch import deduplicates inputs, pairs complementary RAW+JPEG in the same folder, reports progress, and supports cancel", async () => {
  const macos = await readSource("native/macos/Sources/NikonLink/main.swift");
  const windows = await readSource("native/windows/Services/CaptureWorkflow.cs");

  assert.match(macos, /var seen = Set<URL>\(\)/);
  assert.match(
    macos,
    /urls\.filter \{[\s\S]*?seen\.insert\([\s\S]*?resolvingSymlinksInPath\(\)[\s\S]*?\.inserted/
  );
  assert.match(macos, /var jpegPairBases: \[String: String\] = \[:\]/);
  assert.match(macos, /var rawPairBases: \[String: String\] = \[:\]/);
  assert.match(macos, /deletingLastPathComponent\(\)\.path[\s\S]*?deletingPathExtension\(\)\.lastPathComponent/);
  assert.match(
    macos,
    /deletingLastPathComponent\(\)\.path\s*\+ "\\u\{0\}"/,
    "macOS must preserve parent-path case on case-sensitive volumes"
  );
  assert.match(macos, /case "jpg", "jpeg":/);
  assert.match(macos, /case "nef", "nrw", "arw", "cr2", "cr3":/);
  assert.match(macos, /jpegPairBases\[pairKey\] == nil/);
  assert.match(macos, /rawPairBases\[pairKey\] == nil/);
  assert.match(macos, /Task\.isCancelled/);
  assert.match(macos, /importProgress/);

  assert.match(windows, /new HashSet<string>\(StringComparer\.OrdinalIgnoreCase\)/);
  assert.match(windows, /if \(seen\.Add\(full\)\)/);
  assert.match(windows, /new Dictionary<string, ImportPairReservation>\(/);
  assert.match(windows, /Path\.GetDirectoryName\(canonicalSource\)/);
  assert.match(windows, /ImportPairKind\.Jpeg/);
  assert.match(windows, /ImportPairKind\.Raw/);
  assert.match(windows, /pair\.HasRaw && !pair\.HasJpeg/);
  assert.match(windows, /pair\.HasJpeg && !pair\.HasRaw/);
  assert.match(windows, /IProgress<\(int Processed, int Total\)>\? progress/);
  assert.match(windows, /if \(cancellationToken\.IsCancellationRequested\)/);
  assert.match(windows, /cancelled = total - index/);
});

test("desktop import locks session state for the whole batch and keeps Windows file I/O off the UI thread", async () => {
  const macos = await readSource("native/macos/Sources/NikonLink/main.swift");
  const macosWorkflow = await readSource("native/macos/Sources/NikonLink/CaptureWorkflow.swift");
  const windows = await readSource("native/windows/Services/CaptureWorkflow.cs");
  const windowsUi = await readSource("native/windows/MainWindow.xaml.cs");

  assert.match(macos, /importToken = try captureWorkflow\.beginImportBatch\(\)/);
  assert.match(macos, /defer \{[\s\S]*?captureWorkflow\.endImportBatch\(importToken\)/);
  assert.match(macosWorkflow, /guard importOperationToken == nil,[\s\S]*?nonImportOperationToken == nil/);
  assert.match(macosWorkflow, /func beginNonImportOperation\(\) throws -> UUID/);
  assert.match(macosWorkflow, /if nonImportOperationToken == token[\s\S]*?nonImportOperationToken = nil/);
  assert.match(macosWorkflow, /operationToken: UUID\? = nil/);
  assert.match(macos, /operationToken = try captureWorkflow\.beginNonImportOperation\(\)/);
  assert.match(macos, /operationToken: operationToken/);
  assert.match(macos, /libraryOperationToken = try captureWorkflow\.beginNonImportOperation\(\)/);
  assert.match(macos, /operationToken: libraryOperationToken/);
  assert.match(macos, /ExternalRecordingOperation[\s\S]*?let token: UUID[\s\S]*?let target: URL/);
  assert.match(macos, /externalRecordingLifecycleLock\.lock\(\)/);
  assert.match(macos, /finishExternalRecordingOperation\(\)/);
  assert.match(macos, /guard let operation = externalRecordingOperation/);
  assert.match(macos, /externalRecordingOperation = nil[\s\S]*?stopIfRecording\(\)/);
  const externalFinish = sliceFunction(
    macos,
    "private func finishExternalRecordingOperation()",
    "func toggleMovieRecording()"
  );
  const completedRecording = externalFinish.indexOf(
    "guard result.url.standardizedFileURL"
  );
  assert.notEqual(completedRecording, -1);
  const stopAttempt = externalFinish.indexOf("stopIfRecording()");
  assert.notEqual(stopAttempt, -1);
  assert.doesNotMatch(
    externalFinish.slice(stopAttempt),
    /removeItem\(at: operation\.target\)|removeItem\(at: result\.url\)/,
    "stop failures may still leave a recoverable AVI and must not delete it"
  );
  assert.doesNotMatch(
    externalFinish.slice(completedRecording),
    /removeItem\(at: operation\.target\)|removeItem\(at: result\.url\)|externalVideoRecorder\.abort\(\)/,
    "a completed AVI must survive metadata finalization failures"
  );
  assert.match(externalFinish, /throw ExternalRecordingStopError\(/);
  assert.match(externalFinish, /throw ExternalRecordingFinalizeError\(/);
  assert.match(macos, /外录文件已保留 · 入库元数据失败/);
  assert.match(windows, /EnterImportOperation\(\);[\s\S]*?finally[\s\S]*?ExitImportOperation\(\);/);
  assert.match(windows, /ThrowIfImportOperationActive\(\)/);
  assert.match(windowsUi, /await Task\.Run\([\s\S]*?_workflow\.BatchImportAsync\(/);
});

test("desktop import publishes sidecars, backups, and checksum manifests atomically", async () => {
  const macos = await readSource("native/macos/Sources/NikonLink/CaptureWorkflow.swift");
  const windows = await readSource("native/windows/Services/CaptureWorkflow.cs");

  assert.match(macos, /private let finalizeLock = NSLock\(\)/);
  assert.match(macos, /finalizeLock\.lock\(\)/);
  assert.match(macos, /appendChecksumAtomically\(/);
  assert.match(macos, /\.zenche-manifest-/);
  assert.match(macos, /replaceItemAt\(manifest, withItemAt: temporary\)/);
  assert.match(macos, /copyFileAtomically\([\s\S]*?from: sidecar,[\s\S]*?to: backupSidecar/);
  assert.match(macos, /fileManager\.fileExists\(atPath: manifest\.path\)[\s\S]*?try String\(contentsOf: manifest/);
  assert.match(macos, /sidecarData = fileManager\.fileExists/);
  assert.match(macos, /backupSidecarData/);
  assert.match(macos, /var failures: \[Error\] = \[\]/);
  assert.match(macos, /attempt \{ try removeRollbackFile\(at: backup\) \}/);
  assert.match(macos, /rollbackErrors: rollbackError\.failures/);
  assert.match(macos, /originalError: originalError/);

  assert.match(windows, /private readonly SemaphoreSlim _finalizeGate/);
  assert.match(windows, /await _finalizeGate\.WaitAsync\(/);
  assert.match(windows, /WriteTextAtomicallyAsync\([\s\S]*?manifest/);
  assert.match(windows, /CopyFileAtomicallyAsync\([\s\S]*?Path\.GetFileName\(sidecar\)/);
  assert.match(windows, /File\.Move\(temporary, destination, overwrite: true\)/);
  assert.match(windows, /CaptureImportMetadataSnapshotAsync\(/);
  assert.match(windows, /BackupSidecarData/);
  assert.match(windows, /var failures = new List<Exception>\(\)/);
  assert.match(windows, /await AttemptAsync\([\s\S]*?DeleteRollbackFileAsync\(snapshot\.Backup\)/);
  assert.match(windows, /await AttemptAsync\([\s\S]*?snapshot\.BackupSidecar/);
  assert.match(windows, /await AttemptAsync\([\s\S]*?snapshot\.Sidecar/);
  assert.match(windows, /new AggregateException\(failure, rollbackFailure\)/);
});

test("Windows import UI uses valid WPF selection and window APIs", async () => {
  const windows = await readSource("native/windows/MainWindow.xaml.cs");
  assert.match(windows, /progressWindow\.Show\(\);/);
  assert.doesNotMatch(windows, /progressWindow\.Show\(this\)/);
  assert.match(windows, /CaptureWorkflow\.BatchImportResult\?/);
  assert.doesNotMatch(windows, /PhotoTree\.SelectedItem\s*=/);
  assert.match(windows, /container\.IsSelected = true/);
});

test("batch import continues per-file on failure and preserves committed files", async () => {
  const windows = await readSource("native/windows/Services/CaptureWorkflow.cs");
  const macos = await readSource("native/macos/Sources/NikonLink/main.swift");

  assert.match(windows, /catch\s*\{\s*failed\+\+;\s*\}/);
  assert.match(windows, /catch \(OperationCanceledException\)/);

  assert.match(macos, /failed \+= 1/);
  assert.match(macos, /cancelled = total - index/);
});

test("macOS security-scoped access is started and stopped for every selected URL", async () => {
  const macos = await readSource("native/macos/Sources/NikonLink/CaptureWorkflow.swift");
  const body = sliceFunction(
    macos,
    "func importFile(",
    "func importFileAsync("
  );
  assert.match(body, /startAccessingSecurityScopedResource\(\)/);
  assert.match(body, /stopAccessingSecurityScopedResource\(\)/);
  assert.match(body, /defer/);
});

test("legacy import helpers are not used by the desktop import flow", async () => {
  const windowsCode = await readSource("native/windows/MainWindow.xaml.cs");
  const windowsLibrary = await readSource("native/windows/Services/PhotoLibrary.cs");

  assert.doesNotMatch(
    windowsCode,
    /_library\.ImportFiles/,
    "MainWindow must not call PhotoLibrary.ImportFiles"
  );
  assert.doesNotMatch(
    windowsCode,
    /LibraryFileManager/,
    "MainWindow must not reference the historical LibraryFileManager"
  );

  assert.match(windowsLibrary, /public IReadOnlyList<string> ImportFiles/);
  assert.doesNotMatch(
    await readSource("native/windows/Services/CaptureWorkflow.cs"),
    /_library\.ImportFiles|PhotoLibrary\.ImportFiles/
  );
});

test("native rollback harnesses target the product toolchain", async () => {
  const windowsHarness = await readSource(
    "test/fixtures/windows-import-rollback/ImportRollbackHarness.csproj"
  );
  assert.match(windowsHarness, /<TargetFramework>net8\.0<\/TargetFramework>/);
});
