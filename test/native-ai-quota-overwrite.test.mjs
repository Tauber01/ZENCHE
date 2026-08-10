import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../", import.meta.url);
const read = async (path) => readFile(new URL(path, root), "utf8");

test("Android AI calls apply the server quota and save retouches as new copies", async () => {
  const source = await read(
    "native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java",
  );
  assert.match(source, /X-ZENCHE-Remaining/);
  assert.match(source, /parseAiRemaining/);
  assert.match(source, /setAiRemainingUsage/);
  assert.match(source, /recordAiUsage\(\)/);
  assert.match(source, /aiMode == 0 && editorSelectedPath != null/);
  assert.match(source, /File dest = source != null\s*\? uniqueEditedFile\(source\)/);
});

test("HarmonyOS AI calls apply the server quota and save retouches as new copies", async () => {
  const [page, library] = await Promise.all([
    read("native/harmony/entry/src/main/ets/pages/Index.ets"),
    read("native/harmony/entry/src/main/ets/storage/PhotoLibrary.ets"),
  ]);
  assert.match(page, /X-ZENCHE-Remaining/);
  assert.match(page, /parseAiRemaining/);
  assert.match(page, /setAiRemainingUsage/);
  assert.match(page, /recordAiUsage\(\)/);
  assert.match(page, /private async saveAiResult[\s\S]*?library\.saveEditedCopy\(/);
  assert.match(library, /replaceFile\(path: string, bytes: Uint8Array\)/);
  assert.match(library, /saveEditedCopy\(originalName: string, bytes: Uint8Array\)/);
});

test("all native AI retouch requests carry the selected source as a typed data URL", async () => {
  const [ios, macos, android, harmony, windows] = await Promise.all([
    read("native/ios/NikonLink/Views/RootView.swift"),
    read("native/macos/Sources/NikonLink/main.swift"),
    read("native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java"),
    read("native/harmony/entry/src/main/ets/pages/Index.ets"),
    read("native/windows/MainWindow.xaml.cs"),
  ]);
  assert.match(ios, /body\["image"\] = "data:/);
  assert.match(ios, /base64,\\\(s\.base64EncodedString\(\)\)/);
  assert.match(macos, /req\.image = "data:/);
  assert.match(macos, /base64,\\\(src\.base64EncodedString\(\)\)/);
  assert.match(android, /body\.put\("image", "data:" \+ imageMimeType/);
  assert.match(harmony, /body\['image'\] = `data:\$\{this\.imageMimeType/);
  assert.match(harmony, /extraData: JSON\.stringify\(body\)/);
  assert.match(windows, /body\["image"\] = \$"data:\{ImageMimeType/);
  assert.match(windows, /sourceBytes\.Length == 0/);
  for (const source of [ios, macos, android, harmony]) {
    assert.match(source, /无法读取原图，未发送 AI 修图请求|原图为空，未发送 AI 修图请求/);
  }
});
