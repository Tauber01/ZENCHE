import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../", import.meta.url);
const read = async (path) => readFile(new URL(path, root), "utf8");

function sliceBetween(source, startMarker, endMarker) {
  const start = source.indexOf(startMarker);
  assert.notEqual(start, -1, `missing ${startMarker}`);
  const end = source.indexOf(endMarker, start + startMarker.length);
  assert.notEqual(end, -1, `missing ${endMarker}`);
  return source.slice(start, end);
}

test("desktop libraries lead with all files, one primary import action, and progressive disclosure", async () => {
  const [macos, windowsXaml] = await Promise.all([
    read("native/macos/Sources/NikonLink/main.swift"),
    read("native/windows/MainWindow.xaml"),
  ]);

  const macosLibrary = sliceBetween(
    macos,
    "private struct LibraryView: View",
    "private struct EditorToolIconShape: Shape",
  );
  const macosToolbar = sliceBetween(
    macosLibrary,
    "private var allFilesToolbar: some View",
    "private var allFilesGrid: some View",
  );
  assert.match(macosLibrary, /allFilesToolbar[\s\S]*allFilesGrid/);
  assert.match(macosToolbar, /NativeButtonStyle\(primary: true\)/);
  assert.equal(
    (macosToolbar.match(/NativeButtonStyle\(primary: true\)/g) ?? []).length,
    1,
    "the simplified macOS library should expose only import as a primary action",
  );
  assert.match(macosLibrary, /DisclosureGroup\([\s\S]*显示来源与工具/);
  assert.match(macosLibrary, /showSourcesAndTools = false/);

  const windowsLibrary = sliceBetween(
    windowsXaml,
    '<Grid x:Name="LibraryPanel"',
    '<Grid x:Name="EditorPanel"',
  );
  const windowsToolbar = sliceBetween(
    windowsLibrary,
    '<Border Grid.Row="0"',
    '<Grid Grid.Row="1"',
  );
  assert.match(windowsToolbar, /Text="所有文件"/);
  assert.equal(
    (windowsToolbar.match(/Style="\{DynamicResource PrimaryButton\}"/g) ?? []).length,
    1,
    "the simplified Windows library should expose only import as a primary action",
  );
  assert.match(windowsLibrary, /x:Name="SourcesAndToolsExpander"/);
  assert.match(windowsLibrary, /IsExpanded="False"/);
});

test("desktop all-files views filter and sort cached metadata without rescanning on each keystroke", async () => {
  const [macos, windowsCode, windowsXaml] = await Promise.all([
    read("native/macos/Sources/NikonLink/main.swift"),
    read("native/windows/MainWindow.xaml.cs"),
    read("native/windows/MainWindow.xaml"),
  ]);

  assert.match(macos, /private var filteredPhotos: \[PhotoRecord\]/);
  assert.match(macos, /name\.lowercased\(\)\.contains\(query\)/);
  assert.match(macos, /localizedStandardCompare/);
  assert.match(macos, /private var visibleSelectedPhoto: PhotoRecord\?/);

  const refresh = sliceBetween(
    windowsCode,
    "private void RefreshAllFilesList()",
    "private async void AllFilesThumbnail_Loaded(",
  );
  assert.match(refresh, /_allFilesSourceItems/);
  assert.doesNotMatch(refresh, /_library\.List\(/);
  assert.match(refresh, /LastWriteTimeUtc/);
  assert.match(windowsXaml, /ComboBoxItem Content="全部" Tag="all"/);
  assert.match(windowsXaml, /ComboBoxItem Content="最近" Tag="recent"/);
});

test("desktop thumbnails are bounded, lazy, and virtualized", async () => {
  const [macos, windowsCode, windowsXaml, windowsCache] = await Promise.all([
    read("native/macos/Sources/NikonLink/main.swift"),
    read("native/windows/MainWindow.xaml.cs"),
    read("native/windows/MainWindow.xaml"),
    read("native/windows/Services/ThumbnailCache.cs"),
  ]);

  assert.match(macos, /NSCache<NSString, NSImage>/);
  assert.match(macos, /countLimit = 128/);
  assert.match(macos, /CGImageSourceCreateThumbnailAtIndex/);
  assert.match(macos, /LazyVGrid/);

  assert.match(windowsXaml, /VirtualizingPanel\.IsVirtualizing="True"/);
  assert.match(windowsXaml, /VirtualizationMode="Recycling"/);
  assert.match(windowsXaml, /Loaded="AllFilesThumbnail_Loaded"/);
  assert.match(windowsCode, /_thumbnailCache\.GetAsync\(listItem\.Item\.Path\)/);
  assert.match(windowsCache, /private const int Capacity = 128/);
  assert.match(windowsCache, /DecodePixelWidth = 240/);
  assert.match(windowsCache, /bitmap\.Freeze\(\)/);
});

test("desktop delete uses the operating-system trash and reconciles the exact historical session", async () => {
  const [macos, windows] = await Promise.all([
    read("native/macos/Sources/NikonLink/CaptureWorkflow.swift"),
    read("native/windows/Services/CaptureWorkflow.cs"),
  ]);

  const macosDelete = sliceBetween(
    macos,
    "func deleteLibraryFile(",
    "private let libraryMediaExtensions",
  );
  assert.match(macosDelete, /fileManager\.trashItem\(/);
  assert.doesNotMatch(macosDelete, /fileManager\.removeItem\(/);
  assert.match(macosDelete, /sessionRootOwning\(normalizedPrimary\)/);
  assert.match(macosDelete, /hasSameStemMediaSibling/);
  assert.doesNotMatch(macosDelete, /backupDirectory/);

  const windowsDelete = sliceBetween(
    windows,
    "public async Task RecycleLibraryFileAsync(",
    "private static bool IsDescendantPath(",
  );
  assert.match(windowsDelete, /RecycleOption\.SendToRecycleBin/);
  assert.doesNotMatch(windowsDelete, /File\.Delete\(/);
  assert.match(windowsDelete, /SessionRootOwning\(normalizedPrimary\)/);
  assert.match(windowsDelete, /HasSameStemMediaSibling/);
  assert.doesNotMatch(windowsDelete, /BackupDirectory/);
});

test("project assignment stays metadata-only and is cleared only after a successful trash operation", async () => {
  const [macos, windows] = await Promise.all([
    read("native/macos/Sources/NikonLink/main.swift"),
    read("native/windows/MainWindow.xaml.cs"),
  ]);

  assert.match(
    macos,
    /if let path = model\.selectedPhoto\?\.url\.path,[\s\S]*model\.deleteSelectedPhoto\(\)[\s\S]*branchStore\.assign\(path, to: nil\)/,
  );
  assert.match(
    windows,
    /await _workflow\.RecycleLibraryFileAsync\(item\.Path\)[\s\S]*_libraryFileAssignments\.Remove\(item\.Path\)/,
  );
  assert.match(macos, /文件位置保持不变/);
  assert.match(windows, /文件位置保持不变/);
});
