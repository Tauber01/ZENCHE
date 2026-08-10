import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const root = new URL('../', import.meta.url);
const read = async (path) => readFile(new URL(path, root), 'utf8');

test('五端登录模式标签与提交动作不再使用相同文案', async () => {
  const [ios, macos, android, harmony, windowsXaml, windowsCode] =
    await Promise.all([
      read('native/ios/NikonLink/Views/RootView.swift'),
      read('native/macos/Sources/NikonLink/main.swift'),
      read('native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java'),
      read('native/harmony/entry/src/main/ets/pages/Index.ets'),
      read('native/windows/MainWindow.xaml'),
      read('native/windows/MainWindow.xaml.cs')
    ]);

  for (const apple of [ios, macos]) {
    assert.match(apple, /case \.login: return "已有账号"/);
    assert.match(apple, /case \.register: return "创建账号"/);
    assert.match(apple, /RuntimeLocalizedText\(mode\.modeTitle\)\.tag\(mode\)/);
    assert.match(apple, /正在登录…/);
    assert.match(apple, /正在注册…/);
  }
  assert.match(android, /"login"\.equals\(mode\) \? "已有账号" : "创建账号"/);
  assert.match(harmony, /mode === 'login' \? '已有账号' : '创建账号'/);
  assert.match(windowsXaml, /x:Name="AuthLoginModeButton"[\s\S]{0,240}Content="已有账号"/);
  assert.match(windowsXaml, /x:Name="AuthRegisterModeButton"[\s\S]{0,240}Content="创建账号"/);
  assert.match(windowsCode, /AuthLoginModeButton\.Content = AppLocalization\.T\("已有账号"\)/);
  assert.match(windowsCode, /AuthRegisterModeButton\.Content = AppLocalization\.T\("创建账号"\)/);
});

test('Apple 登录提交后保留动作文字并给出进行中反馈', async () => {
  for (const source of [
    await read('native/ios/NikonLink/Views/RootView.swift'),
    await read('native/macos/Sources/NikonLink/main.swift')
  ]) {
    assert.match(source, /if isWorking \{[\s\S]{0,180}ProgressView\(\)/);
    assert.match(source, /isWorking[\s\S]{0,200}"正在登录…"/);
    assert.match(source, /\.disabled\(isWorking\)/);
  }
});

test('新增登录模式标签具备五端三语资源', async () => {
  const sources = await Promise.all([
    read('native/ios/NikonLink/zh-Hans.lproj/Localizable.strings'),
    read('native/ios/NikonLink/en.lproj/Localizable.strings'),
    read('native/ios/NikonLink/ja.lproj/Localizable.strings'),
    read('native/android/app/src/main/java/com/tauber/nikonlink/Localization.java'),
    read('native/harmony/entry/src/main/ets/localization/Localization.ets'),
    read('native/windows/Localization.cs')
  ]);
  for (const source of sources) {
    assert.match(source, /已有账号/);
    assert.match(source, /创建账号/);
  }
});
