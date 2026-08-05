import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const root = new URL('../', import.meta.url);
const read = async (path) => readFile(new URL(path, root), 'utf8');

test('mobile shells keep global operation status visible above system insets', async () => {
  const [ios, android, harmony] = await Promise.all([
    read('native/ios/NikonLink/Views/RootView.swift'),
    read('native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java'),
    read('native/harmony/entry/src/main/ets/pages/Index.ets'),
  ]);

  assert.match(ios, /GlobalStatusBar\([\s\S]{0,160}bottomInset: proxy\.safeAreaInsets\.bottom/);
  assert.doesNotMatch(
    ios,
    /GlobalStatusBar\(bottomInset: 0\)/,
    'wide iPad layouts must protect the home indicator too',
  );
  assert.match(ios, /RuntimeLocalizedText\(model\.statusMessage\)[\s\S]{0,180}lineLimit\(1\)/);
  assert.match(ios, /private struct GlobalStatusBar[\s\S]{0,1800}accessibilityElement\(children: \.combine\)/);
  assert.doesNotMatch(
    ios,
    /private struct GlobalStatusBar[\s\S]{0,1800}accessibilityLabel\(Text\("当前状态/,
    'a fixed Chinese accessibility label must not override localized child text',
  );
  assert.match(
    ios,
    /private struct GlobalStatusBar[\s\S]{0,1500}\.background\(IPalette\.surface\)/,
    'the iOS status safe area must keep the home indicator visible in light mode',
  );

  assert.match(android, /root\.addView\(statusBar,[\s\S]{0,140}dp\(30\)/);
  assert.match(android, /statusText\.setSingleLine\(true\)/);
  assert.match(android, /statusText\.setEllipsize\(TextUtils\.TruncateAt\.END\)/);
  assert.doesNotMatch(android, /statusText\.setContentDescription\(tr\("当前状态"\)\)/);
  assert.match(android, /statusParams\.height = statusBarHeight \+ bottom/);

  assert.match(harmony, /this\.GlobalStatusBar\(\)/);
  assert.match(harmony, /private GlobalStatusBar\(\)[\s\S]{0,1000}Text\(this\.tr\(this\.status\)\)/);
  assert.match(harmony, /private GlobalStatusBar\(\)[\s\S]{0,1200}\.maxLines\(1\)[\s\S]{0,200}TextOverflow\.Ellipsis/);
  assert.match(harmony, /this\.tr\('文件库 · %lld 个文件'\)[\s\S]{0,120}\.replace\('%lld', this\.photos\.length\.toString\(\)\)/);
});

test('desktop status bars truncate long operations instead of colliding with counts', async () => {
  const [macos, windows] = await Promise.all([
    read('native/macos/Sources/NikonLink/main.swift'),
    read('native/windows/MainWindow.xaml'),
  ]);

  assert.match(macos, /RuntimeLocalizedText\(model\.connectionDetail\)[\s\S]{0,160}lineLimit\(1\)/);
  assert.match(macos, /Text\("文件库 · /);
  assert.match(macos, /model\.photos\.count[\s\S]{0,200}fixedSize\(horizontal: true/);

  assert.match(windows, /OperationStatusText[\s\S]{0,700}TextTrimming="CharacterEllipsis"/);
  assert.match(windows, /PhotoCountText[\s\S]{0,160}Grid\.Column="1"/);
});

test('global file counts use honest library semantics with exact three-language formats', async () => {
  const [zh, en, ja] = await Promise.all([
    read('native/ios/NikonLink/zh-Hans.lproj/Localizable.strings'),
    read('native/ios/NikonLink/en.lproj/Localizable.strings'),
    read('native/ios/NikonLink/ja.lproj/Localizable.strings'),
  ]);

  const key = /"文件库 · %lld 个文件"/;
  assert.match(zh, key);
  assert.match(en, /"文件库 · %lld 个文件" = "Library · %lld files"/);
  assert.match(ja, /"文件库 · %lld 个文件" = "ライブラリ · %lld 件"/);

  const [android, harmony] = await Promise.all([
    read('native/android/app/src/main/java/com/tauber/nikonlink/Localization.java'),
    read('native/harmony/entry/src/main/ets/localization/Localization.ets'),
  ]);
  assert.match(android, /add\("文件库 · %lld 个文件", "Library · %lld files", "ライブラリ · %lld 件"\)/);
  assert.match(harmony, /'文件库 · %lld 个文件',[\s\S]{0,80}'Library · %lld files',[\s\S]{0,80}'ライブラリ · %lld 件'/);
});

test('the iOS shell follows the in-app locale for navigation and monitor state', async () => {
  const ios = await read('native/ios/NikonLink/Views/RootView.swift');

  assert.match(ios, /private struct SideNavigation[\s\S]{0,2400}RuntimeLocalizedText\(section\.rawValue\)/);
  // v1.5.7 F6（Tauber 拍板）：五端一级导航统一 拍照/视频/编辑/我的设备/分支；
  // 紧凑底栏提回编辑与视频为一级 tab。
  assert.match(ios, /private struct BottomNavigation[\s\S]*?RuntimeLocalizedText\(title\)/);
  assert.match(ios, /navTab\(\.capture, title: "拍照"\)/);
  assert.match(ios, /navTab\(\.library, title: "分支"\)/);
  assert.doesNotMatch(ios, /section == \.library\s*\?\s*"分支"/);
  assert.match(
    ios,
    /private struct NikonCloudMonitorBar[\s\S]{0,1200}RuntimeLocalizedText\([\s\S]{0,100}model\.monitorNikonCloudPreset\?\.name \?\? "已关闭"/,
  );
  assert.doesNotMatch(
    ios,
    /model\.monitorNikonCloudPreset\?\.name[\s\S]{0,100}String\(localized: "已关闭"\)/,
  );
});

test('the iOS cloud monitor uses a localized compact preset label on phones', async () => {
  const ios = await read('native/ios/NikonLink/Views/RootView.swift');

  assert.match(
    ios,
    /private struct NikonCloudMonitorBar[\s\S]{0,2600}horizontalSizeClass == \.compact[\s\S]{0,120}\? "预设"[\s\S]{0,80}: "选择预设"/,
  );
  assert.match(
    ios,
    /private struct NikonCloudMonitorBar[\s\S]{0,2600}RuntimeLocalizedText\([\s\S]{0,160}horizontalSizeClass == \.compact/,
  );
});
