import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../", import.meta.url);
const source = (path) => readFile(new URL(path, root), "utf8");

test("all five native targets expose an in-camera storage workspace", async () => {
  const [ios, android, harmony, macos, windows] = await Promise.all([
    source("native/ios/NikonLink/Views/RootView.swift"),
    source("native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java"),
    source("native/harmony/entry/src/main/ets/pages/Index.ets"),
    source("native/macos/Sources/NikonLink/main.swift"),
    source("native/windows/MainWindow.xaml"),
  ]);

  for (const contents of [ios, android, harmony, macos, windows]) {
    assert.match(contents, /相机机内存储/);
    assert.match(contents, /从相机删除/);
    assert.match(contents, /全选/);
  }
});

test("native camera backends implement standard PTP storage operations", async () => {
  const [apple, androidUsb, androidIp, harmonyUsb, harmonyIp, windowsUsb, windowsIp] =
    await Promise.all([
      source("native/ios/NikonLink/Connectivity/RemoteCaptureServices.swift"),
      source("native/android/app/src/main/java/com/tauber/nikonlink/PtpCamera.java"),
      source("native/android/app/src/main/java/com/tauber/nikonlink/PtpIpCamera.java"),
      source("native/harmony/entry/src/main/ets/camera/PtpCamera.ets"),
      source("native/harmony/entry/src/main/ets/camera/PtpIpCamera.ets"),
      source("native/windows/Services/PtpCamera.cs"),
      source("native/windows/Services/PtpIpCamera.cs"),
    ]);

  for (const contents of [apple, androidUsb, androidIp, harmonyUsb, harmonyIp, windowsUsb, windowsIp]) {
    assert.match(contents, /0x1004/i, "GetStorageIDs must be present");
    assert.match(contents, /0x1005/i, "GetStorageInfo must be present");
    assert.match(contents, /0x1007/i, "GetObjectHandles must be present");
    assert.match(contents, /0x1008/i, "GetObjectInfo must be present");
    assert.match(contents, /0x1009/i, "GetObject must be present");
    assert.match(contents, /0x100a/i, "GetThumb must be present");
    assert.match(contents, /0x100b/i, "DeleteObject must be present");
  }
});

test("PTP storage readers enter the root association and recurse through camera folders", async () => {
  const [apple, androidUsb, androidIp, harmonyUsb, harmonyIp, windowsUsb, windowsIp] =
    await Promise.all([
      source("native/ios/NikonLink/Connectivity/RemoteCaptureServices.swift"),
      source("native/android/app/src/main/java/com/tauber/nikonlink/PtpCamera.java"),
      source("native/android/app/src/main/java/com/tauber/nikonlink/PtpIpCamera.java"),
      source("native/harmony/entry/src/main/ets/camera/PtpCamera.ets"),
      source("native/harmony/entry/src/main/ets/camera/PtpIpCamera.ets"),
      source("native/windows/Services/PtpCamera.cs"),
      source("native/windows/Services/PtpIpCamera.cs"),
    ]);

  for (const contents of [apple, androidUsb, androidIp, harmonyUsb, harmonyIp, windowsUsb, windowsIp]) {
    assert.match(
      contents,
      /(?:0xffff_ffff|0xffffffff|UInt32\.max|uint\.MaxValue)/,
      "the root association must use the PTP all/root marker",
    );
    assert.match(
      contents,
      /(?:isAssociation|isObjectAssociation|IsAssociation)/,
      "directory objects must be detected instead of silently discarded",
    );
    assert.match(
      contents,
      /(?:visitedHandles|visited)/,
      "recursive directory traversal must guard against duplicate or cyclic handles",
    );
  }
});

test("storage deletion is protected by native destructive confirmation", async () => {
  const [ios, android, harmony, macos, windows] = await Promise.all([
    source("native/ios/NikonLink/Views/RootView.swift"),
    source("native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java"),
    source("native/harmony/entry/src/main/ets/pages/Index.ets"),
    source("native/macos/Sources/NikonLink/main.swift"),
    source("native/windows/MainWindow.xaml.cs"),
  ]);

  for (const contents of [ios, android, harmony, macos, windows]) {
    assert.match(contents, /从相机永久删除/);
    assert.match(contents, /永久删除/);
  }
  assert.match(ios, /role: \.destructive/);
  assert.match(android, /AlertDialog\.Builder/);
  assert.match(harmony, /showDialog/);
  assert.match(macos, /role: \.destructive/);
  assert.match(windows, /MessageBoxImage\.Warning/);
});

test("camera-storage downloads enter the native ZENCHE capture workflow", async () => {
  const [ios, android, harmony, macos, windows] = await Promise.all([
    source("native/ios/NikonLink/Models/AppModel.swift"),
    source("native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java"),
    source("native/harmony/entry/src/main/ets/pages/Index.ets"),
    source("native/macos/Sources/NikonLink/main.swift"),
    source("native/windows/MainWindow.xaml.cs"),
  ]);

  assert.match(ios, /saveCameraStorageObject/);
  assert.match(android, /captureWorkflow\.store/);
  assert.match(harmony, /library\.saveReceived/);
  assert.match(macos, /storeCameraStorageObject/);
  assert.match(windows, /_workflow\.StoreAsync/);
});

test("macOS keeps detailed gphoto listings so file indexes remain parseable", async () => {
  const macos = await source("native/macos/Sources/NikonLink/main.swift");
  assert.match(
    macos,
    /arguments\.contains\("--list-files"\) \? \[\] : \["--quiet"\]/,
  );
  assert.match(macos, /已解析相机文件列表/);
  assert.match(macos, /if reportedFiles && items\.isEmpty/);
  assert.doesNotMatch(macos, /if !output\.isEmpty && items\.isEmpty/);
  assert.match(macos, /相机返回了文件列表，但当前版本无法识别其格式/);
});
