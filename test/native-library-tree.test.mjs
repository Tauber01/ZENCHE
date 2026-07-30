import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../", import.meta.url);
const read = async (path) => readFile(new URL(path, root), "utf8");

test("all native targets expose expandable secondary immersive parameters", async () => {
  const [ios, android, harmony, macos, windows] = await Promise.all([
    read("native/ios/NikonLink/Views/RootView.swift"),
    read("native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java"),
    read("native/harmony/entry/src/main/ets/pages/Index.ets"),
    read("native/macos/Sources/NikonLink/main.swift"),
    read("native/windows/MainWindow.xaml.cs"),
  ]);

  assert.match(ios, /showsMoreParameters/);
  assert.match(android, /immersiveMoreParametersExpanded/);
  assert.match(harmony, /immersiveMoreParametersExpanded/);
  assert.match(macos, /showsMoreParameters/);
  assert.match(windows, /moreParameterTray/);

  for (const source of [ios, android, harmony, macos, windows]) {
    assert.match(source, /更多参数/);
    assert.match(source, /对焦/);
  }
  assert.match(ios, /尺寸\/帧率/);
  for (const source of [android, harmony, macos, windows]) {
    assert.match(source, /白平衡/);
  }
});

test("mobile immersive parameter chrome stays compact with accessible hit targets", async () => {
  const [ios, android, harmony] = await Promise.all([
    read("native/ios/NikonLink/Views/RootView.swift"),
    read("native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java"),
    read("native/harmony/entry/src/main/ets/pages/Index.ets"),
  ]);

  assert.match(ios, /\.frame\(width: 58\)/);
  assert.match(ios, /\.frame\(width: 44, height: 44\)/);
  assert.match(android, /dp\(60\)/);
  assert.match(android, /dp\(44\), dp\(44\)/);
  assert.match(harmony, /\.width\(52\)/);
  assert.match(harmony, /\.width\(44\)[\s\S]*?\.height\(44\)/);
});

test("all native file managers persist nested user-created branches", async () => {
  const [ios, android, harmony, macos, windows, windowsXaml] =
    await Promise.all([
      read("native/ios/NikonLink/Views/RootView.swift"),
      read("native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java"),
      read("native/harmony/entry/src/main/ets/pages/Index.ets"),
      read("native/macos/Sources/NikonLink/main.swift"),
      read("native/windows/MainWindow.xaml.cs"),
      read("native/windows/MainWindow.xaml"),
    ]);

  for (const source of [ios, android, harmony, macos, windows]) {
    assert.match(source, /LibraryBranch/);
    assert.match(source, /children/i);
    assert.match(source, /新建分支/);
    assert.match(source, /未分类/);
  }

  assert.match(ios, /UserDefaults/);
  assert.match(android, /LIBRARY_BRANCHES_KEY/);
  assert.match(harmony, /LIBRARY_BRANCHES_KEY/);
  assert.match(macos, /UserDefaults/);
  assert.match(windows, /library-branches\.json/);
  assert.match(windowsXaml, /<TreeView/);
});

test("branch library is prominent and supports persistent file drag moves", async () => {
  const [ios, android, harmony, macos, windows, windowsXaml] =
    await Promise.all([
      read("native/ios/NikonLink/Views/RootView.swift"),
      read("native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java"),
      read("native/harmony/entry/src/main/ets/pages/Index.ets"),
      read("native/macos/Sources/NikonLink/main.swift"),
      read("native/windows/MainWindow.xaml.cs"),
      read("native/windows/MainWindow.xaml"),
    ]);

  for (const source of [ios, android, harmony, macos, windowsXaml]) {
    assert.match(source, /分支文件库/);
    assert.match(source, /分支工作台|拖动本地文件到任意分支/);
  }

  assert.match(ios, /file-branch-assignments/);
  assert.match(ios, /\.draggable\(/);
  assert.match(ios, /\.dropDestination\(/);

  assert.match(android, /LIBRARY_FILE_ASSIGNMENTS_KEY/);
  assert.match(android, /startDragAndDrop/);
  assert.match(android, /setOnDragListener/);

  assert.match(harmony, /LIBRARY_FILE_ASSIGNMENTS_KEY/);
  assert.match(harmony, /\.onDragStart\(/);
  assert.match(harmony, /\.onDrop\(/);

  assert.match(macos, /file-branch-assignments/);
  assert.match(macos, /\.draggable\(/);
  assert.match(macos, /\.dropDestination\(/);

  assert.match(windows, /library-file-assignments\.json/);
  assert.match(windows, /DragDrop\.DoDragDrop/);
  assert.match(windowsXaml, /AllowDrop="True"/);
});

test("branch deletion safely restores files and keeps thumbnails visible", async () => {
  const [ios, android, harmony, macos, windows, windowsXaml] =
    await Promise.all([
      read("native/ios/NikonLink/Views/RootView.swift"),
      read("native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java"),
      read("native/harmony/entry/src/main/ets/pages/Index.ets"),
      read("native/macos/Sources/NikonLink/main.swift"),
      read("native/windows/MainWindow.xaml.cs"),
      read("native/windows/MainWindow.xaml"),
    ]);

  for (const source of [ios, android, harmony, macos, windows]) {
    assert.match(source, /删除分支/);
    assert.match(source, /原文件不受影响/);
  }

  assert.match(ios, /func deleteBranch/);
  assert.match(ios, /\.contentShape\(Rectangle\(\)\)/);
  assert.match(ios, /UIImage\(contentsOfFile:/);

  assert.match(android, /showDeleteLibraryBranchDialog/);
  assert.match(android, /name\.setOnClickListener\(toggleListener\)/);
  assert.match(android, /BitmapFactory\.decodeFile/);

  assert.match(harmony, /private deleteLibraryBranch/);
  assert.match(harmony, /this\.toggleLibraryBranch\(branch\.id\)/);
  assert.match(harmony, /Image\(`file:\/\/\$\{item\.path\}`\)/);

  assert.match(macos, /func deleteBranch/);
  assert.match(macos, /\.contentShape\(Rectangle\(\)\)/);
  assert.match(macos, /NSImage\(contentsOf:/);

  assert.match(windows, /CreateLibraryThumbnail/);
  assert.match(windows, /RemoveLibraryBranch/);
  assert.match(windowsXaml, /DeleteBranchButton/);
  assert.match(windowsXaml, /PreviewMouseLeftButtonUp/);
});
