import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../", import.meta.url);
const read = async (path) => readFile(new URL(path, root), "utf8");

test("release version is consistent across packages and build scripts", async () => {
  const packageMetadata = JSON.parse(await read("package.json"));
  const version = packageMetadata.version;
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

test("native package build numbers stay aligned", async () => {
  const [android, harmony, ios, macos] = await Promise.all([
    read("native/android/app/build.gradle"),
    read("native/harmony/AppScope/app.json5"),
    read("native/ios/NikonLink.xcodeproj/project.pbxproj"),
    read("native/macos/Info.plist"),
  ]);
  const buildNumber = android.match(/versionCode (\d+)/)?.[1];

  assert.equal(buildNumber, "38");
  assert.match(harmony, new RegExp(`versionCode: ${buildNumber}`));
  assert.match(ios, new RegExp(`CURRENT_PROJECT_VERSION = ${buildNumber};`, "g"));
  assert.match(
    macos,
    new RegExp(`<key>CFBundleVersion</key>\\s*<string>${buildNumber}</string>`),
  );
});
