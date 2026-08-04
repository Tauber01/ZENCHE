import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../", import.meta.url);

async function source(path) {
  return readFile(new URL(path, root), "utf8");
}

test("all native settings entries use a gear icon", async () => {
  const [ios, android, androidGear, harmony, macos, windows] = await Promise.all([
    source("native/ios/NikonLink/Views/RootView.swift"),
    source("native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java"),
    source("native/android/app/src/main/res/drawable/ic_settings_gear.xml"),
    source("native/harmony/entry/src/main/ets/pages/Index.ets"),
    source("native/macos/Sources/NikonLink/main.swift"),
    source("native/windows/MainWindow.xaml"),
  ]);

  assert.match(ios, /Image\(systemName: "gearshape"\)/);
  assert.match(android, /setImageResource\(R\.drawable\.ic_settings_gear\)/);
  assert.match(androidGear, /<vector/);
  assert.match(harmony, /Button\('⚙'/);
  assert.match(macos, /Image\(systemName: "gearshape"\)/);
  assert.match(windows, /Content="⚙"/);
});

test("all native targets expose persisted Chinese, English, and Japanese choices", async () => {
  const files = await Promise.all([
    source("native/ios/NikonLink/Models/AppModel.swift"),
    source("native/android/app/src/main/java/com/tauber/nikonlink/Localization.java"),
    source("native/harmony/entry/src/main/ets/localization/Localization.ets"),
    source("native/macos/Sources/NikonLink/SettingsSheet.swift"),
    source("native/windows/Localization.cs"),
  ]);

  for (const contents of files) {
    assert.match(contents, /zh-Hans/);
    assert.match(contents, /en/);
    assert.match(contents, /ja/);
  }
});

test("Apple and HarmonyOS packages include Chinese, English, and Japanese resources", async () => {
  const [chinese, english, japanese, harmonyEnglish, harmonyJapanese] =
    await Promise.all([
      source("native/ios/NikonLink/zh-Hans.lproj/Localizable.strings"),
      source("native/ios/NikonLink/en.lproj/Localizable.strings"),
      source("native/ios/NikonLink/ja.lproj/Localizable.strings"),
      source("native/harmony/entry/src/main/resources/en_US/element/string.json"),
      source("native/harmony/entry/src/main/resources/ja_JP/element/string.json"),
    ]);

  assert.match(chinese, /"设置" = "设置"/);
  assert.match(english, /"设置" = "Settings"/);
  assert.match(japanese, /"设置" = "設定"/);
  assert.match(harmonyEnglish, /Cross-platform camera control/);
  assert.match(harmonyJapanese, /クロスプラットフォーム/);
});

test("Apple Chinese localization is explicit and never falls through to English or Japanese", async () => {
  const [chinese, english, project, macosBuild] = await Promise.all([
    source("native/ios/NikonLink/zh-Hans.lproj/Localizable.strings"),
    source("native/ios/NikonLink/en.lproj/Localizable.strings"),
    source("native/ios/NikonLink.xcodeproj/project.pbxproj"),
    source("scripts/build-macos.sh"),
  ]);
  const sourceKeys = [...english.matchAll(/^("(?:\\.|[^"])+")\s*=/gm)]
    .map((match) => match[1]);

  for (const key of sourceKeys) {
    assert.ok(
      chinese.includes(`${key} = ${key};`),
      `Simplified Chinese is missing an identity mapping for ${key}`,
    );
  }
  assert.match(project, /zh-Hans\.lproj\/Localizable\.strings/);
  assert.match(macosBuild, /for localization in zh-Hans en ja/);
});

test("dynamic native status text goes through runtime localization", async () => {
  const [ios, android, harmony, macos, windows] = await Promise.all([
    source("native/ios/NikonLink/Views/RootView.swift"),
    source("native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java"),
    source("native/harmony/entry/src/main/ets/pages/Index.ets"),
    source("native/macos/Sources/NikonLink/main.swift"),
    source("native/windows/MainWindow.xaml.cs"),
  ]);

  assert.match(ios, /RuntimeLocalizedText\(model\.shootingTaskStatus\)/);
  assert.match(android, /lutStatusText\.setText\(tr\("已载入 · "\)/);
  assert.match(harmony, /Text\(this\.tr\(this\.shootingTaskStatus\)\)/);
  assert.match(
    macos,
    /RuntimeLocalizedText\(model\.(?:status|connectionTitle)\)/,
  );
  assert.match(windows, /OperationStatusText\.Text = AppLocalization\.T\(/);
});

test("mobile navigation respects safe areas without duplicating phone status chrome", async () => {
  const [ios, android, harmony] = await Promise.all([
    source("native/ios/NikonLink/Views/RootView.swift"),
    source("native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java"),
    source("native/harmony/entry/src/main/ets/pages/Index.ets"),
  ]);

  assert.doesNotMatch(ios, /private struct StatusBar/);
  assert.match(ios, /GlobalStatusBar\([\s\S]{0,160}safeAreaInsets\.bottom/);
  assert.match(android, /buildStatusBar|statusText|countText/);
  assert.match(
    android,
    /applySystemBarInsets\(root, topBar, bottomNavigation, statusBar\)/,
  );
  assert.match(android, /statusParams\.height = statusBarHeight \+ bottom/);
  assert.match(android, /root\.addView\(statusBar/);
  assert.doesNotMatch(harmony, /private StatusBar\(\)/);
  assert.match(harmony, /this\.CompactBottomNavigation\(\)/);
  assert.match(harmony, /this\.GlobalStatusBar\(\)/);
});

test("fragment translators prefer longer phrases before short labels", async () => {
  const [android, harmony, windows] = await Promise.all([
    source("native/android/app/src/main/java/com/tauber/nikonlink/Localization.java"),
    source("native/harmony/entry/src/main/ets/localization/Localization.ets"),
    source("native/windows/Localization.cs"),
  ]);

  assert.match(android, /right\.length\(\),\s*left\.length\(\)/);
  assert.match(harmony, /right\.chinese\.length - left\.chinese\.length/);
  assert.match(windows, /OrderByDescending\(\s*item => item\.Key\.Length\)/);
});

test("language packs cover the main capture screen and dynamic connection state", async () => {
  const [english, japanese] = await Promise.all([
    source("native/ios/NikonLink/en.lproj/Localizable.strings"),
    source("native/ios/NikonLink/ja.lproj/Localizable.strings"),
  ]);
  const requiredKeys = [
    "未连接",
    "快门、曝光、对焦、白平衡与拍摄模式集中在当前页面。",
    "等待实时取景画面",
    "ISO感光度",
    "设定优化校准",
    "拍摄模式下由相机控制",
  ];

  for (const key of requiredKeys) {
    assert.ok(english.includes(`"${key}" =`), `English is missing ${key}`);
    assert.ok(japanese.includes(`"${key}" =`), `Japanese is missing ${key}`);
  }
});
