import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../", import.meta.url);
const read = async (path) => readFile(new URL(path, root), "utf8");

test("release version is consistent across packages and build scripts", async () => {
  const packageMetadata = JSON.parse(await read("package.json"));
  const version = packageMetadata.version;
  assert.equal(version, "1.5.14");
  const sources = await Promise.all([
    read("scripts/build-android.sh"),
    read("scripts/build-harmony.sh"),
    read("scripts/build-ios.sh"),
    read("scripts/build-macos.sh"),
    read("scripts/build-windows.ps1"),
    read("native/android/app/build.gradle"),
    read("native/harmony/AppScope/app.json5"),
    read("native/harmony/entry/oh-package.json5"),
    read("native/ios/NikonLink.xcodeproj/project.pbxproj"),
    read("native/macos/Info.plist"),
    read("native/windows/NikonLink.Windows.csproj"),
  ]);

  for (const source of sources) {
    assert.ok(source.includes(version), `missing release version ${version}`);
  }
});

test("runtime version fallbacks and diagnostics match the release version", async () => {
  const version = JSON.parse(await read("package.json")).version;
  const sources = await Promise.all([
    read("native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java"),
    read("native/harmony/entry/src/main/ets/pages/Index.ets"),
    read("native/harmony/entry/src/main/ets/diagnostics/DiagnosticLogger.ets"),
    read("native/ios/NikonLink/Models/UpdateController.swift"),
    read("native/ios/NikonLink/Views/RootView.swift"),
    read("native/macos/Sources/NikonLink/UpdateController.swift"),
    read("native/macos/Sources/NikonLink/main.swift"),
    read("native/windows/Services/AuthService.cs"),
    read("native/windows/Services/UpdateService.cs"),
  ]);

  for (const source of sources) {
    assert.ok(source.includes(version), `missing runtime release version ${version}`);
  }

  const buildAll = await read("scripts/build-all.sh");
  assert.doesNotMatch(buildAll, /echo\s+["']1\.5\.3["']/);
});

test("native package build numbers stay aligned", async () => {
  const [android, harmony, ios, macos, windows, windowsBuild] = await Promise.all([
    read("native/android/app/build.gradle"),
    read("native/harmony/AppScope/app.json5"),
    read("native/ios/NikonLink.xcodeproj/project.pbxproj"),
    read("native/macos/Info.plist"),
    read("native/windows/NikonLink.Windows.csproj"),
    read("scripts/build-windows.ps1"),
  ]);
  const buildNumber = android.match(/versionCode (\d+)/)?.[1];

  assert.equal(buildNumber, "41");
  assert.match(harmony, new RegExp(`versionCode: ${buildNumber}`));
  assert.match(ios, new RegExp(`CURRENT_PROJECT_VERSION = ${buildNumber};`, "g"));
  assert.match(
    macos,
    new RegExp(`<key>CFBundleVersion</key>\\s*<string>${buildNumber}</string>`),
  );
  assert.match(
    windows,
    new RegExp(`<AssemblyVersion>1\\.5\\.14\\.${buildNumber}</AssemblyVersion>`),
  );
  assert.match(
    windows,
    new RegExp(`<FileVersion>1\\.5\\.14\\.${buildNumber}</FileVersion>`),
  );
  assert.match(windowsBuild, new RegExp(`\\$BuildNumber = ${buildNumber}`));
});
