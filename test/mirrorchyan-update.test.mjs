import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../", import.meta.url);
const source = (path) => readFile(new URL(path, root), "utf8");

test("all native targets prefer MirrorChyan and retain GitHub fallback", async () => {
  const targets = await Promise.all([
    source("native/ios/NikonLink/Models/UpdateController.swift"),
    source("native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java"),
    source("native/harmony/entry/src/main/ets/pages/Index.ets"),
    source("native/macos/Sources/NikonLink/UpdateController.swift"),
    source("native/windows/Services/UpdateService.cs"),
  ]);

  for (const contents of targets) {
    assert.match(contents, /mirrorchyan\.com\/api\/resources/);
    assert.match(contents, /current_version/);
    assert.match(contents, /user_agent/);
    assert.match(contents, /cdk/i);
    assert.match(contents, /api\.github\.com\/repos\/Tauber01\/ZENCHE\/releases\/latest/);
    assert.match(contents, /incremental/);
  }
});

test("native CDK storage avoids diagnostic-log plaintext", async () => {
  const [ios, android, harmony, macos, windows] = await Promise.all([
    source("native/ios/NikonLink/Models/UpdateController.swift"),
    source("native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java"),
    source("native/harmony/entry/src/main/ets/pages/Index.ets"),
    source("native/macos/Sources/NikonLink/UpdateController.swift"),
    source("native/windows/Services/UpdateService.cs"),
  ]);

  assert.match(ios, /kSecClassGenericPassword/);
  assert.match(macos, /kSecClassGenericPassword/);
  assert.match(android, /AndroidKeyStore/);
  assert.match(windows, /ProtectedData\.Protect/);
  assert.match(harmony, /MIRROR_CHYAN_CDK_KEY/);

  for (const contents of [ios, android, harmony, macos, windows]) {
    assert.doesNotMatch(
      contents,
      /(?:error|warning|info)\([\s\S]{0,200}(?:\+\s*cdk|\$\{cdk\}|\\\(cdk\))/i,
    );
  }
});

test("all native settings expose optional MirrorChyan CDK controls", async () => {
  const settings = await Promise.all([
    source("native/ios/NikonLink/Views/RootView.swift"),
    source("native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java"),
    source("native/harmony/entry/src/main/ets/pages/Index.ets"),
    source("native/macos/Sources/NikonLink/SettingsSheet.swift"),
    source("native/windows/MainWindow.xaml"),
  ]);

  for (const contents of settings) {
    assert.match(contents, /Mirror酱 CDK（可选）/);
    assert.match(contents, /打开 Mirror酱/);
  }
});
