import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const read = (path) => readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');

const sources = {
  ios: read('native/ios/NikonLink/Views/RootView.swift'),
  android: read('native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java'),
  harmony: read('native/harmony/entry/src/main/ets/pages/Index.ets'),
  macos: read('native/macos/Sources/NikonLink/main.swift')
    + read('native/macos/Sources/NikonLink/SettingsSheet.swift'),
  windows: read('native/windows/MainWindow.xaml.cs')
    + read('native/windows/MainWindow.xaml'),
};

const endpoint = 'https://zenche.top/api/v1/ai/rebind';

test('all five native clients use the fixed HTTPS rebind endpoint', () => {
  for (const [platform, source] of Object.entries(sources)) {
    assert.ok(source.includes(endpoint), `${platform} is missing the fixed HTTPS endpoint`);
    assert.ok(source.includes('恢复设备码'), `${platform} is missing the recovery UI`);
    assert.ok(source.includes('旧设备 ID'), `${platform} is missing the previous device ID input`);
    assert.ok(source.includes('旧激活码'), `${platform} is missing the previous activation key input`);
  }
});

test('clients verify the old proof before networking and the new code before storage', () => {
  const flows = {
    ios: sources.ios.slice(sources.ios.indexOf('private func restoreDeviceBinding()')),
    android: sources.android.slice(sources.android.indexOf('rebindAiBtn.setOnClickListener')),
    harmony: sources.harmony.slice(sources.harmony.indexOf('private async rebindAiActivation()')),
    macos: sources.macos.slice(sources.macos.indexOf('private func restoreDeviceBinding()')),
    windows: sources.windows.slice(sources.windows.indexOf('private async void AiRebind_Click')),
  };

  const expectations = {
    ios: ['ActivationManager.verify(code: oldCode', 'AiRebindService.rebind(',
      'ActivationManager.verify(\n                code: result.newCode',
      'ActivationManager.storeVerifiedActivation('],
    android: ['verifyActivationCodeForDevice(oldCode, oldDeviceId)', 'callAiRebind(',
      'verifyActivationCodeForDevice(\n                            response.newCode',
      'saveVerifiedActivation('],
    harmony: ['verifyActivationCodeForDevice(oldCode, oldDeviceId)', 'request.request(',
      'verifyActivationCodeForDevice(newCode, currentDeviceId)',
      'saveVerifiedActivation(newCode, remaining)'],
    macos: ['ActivationManager.verify(code: oldCode', 'AiRebindService.rebind(',
      'ActivationManager.verify(\n                code: result.newCode',
      'ActivationManager.storeVerifiedActivation('],
    windows: ['VerifyActivationCode(oldCode, oldDeviceId)', 'client.SendAsync(',
      'VerifyActivationCode(newCode, currentDeviceId)',
      'SaveReboundActivation(newCode, remaining)'],
  };

  for (const [platform, flow] of Object.entries(flows)) {
    let cursor = -1;
    for (const marker of expectations[platform]) {
      const next = flow.indexOf(marker, cursor + 1);
      assert.ok(next > cursor, `${platform} recovery ordering is missing ${marker}`);
      cursor = next;
    }
  }
});

test('rebind responses are bounded and secrets are not logged', () => {
  for (const [platform, source] of Object.entries(sources)) {
    assert.match(source, /64\s*\*\s*1024|64 \* 1024|64\s*KiB|65536/,
      `${platform} is missing a 64 KiB response bound`);
  }
  for (const source of Object.values(sources)) {
    assert.doesNotMatch(source, /(?:print|log|diagnostic)[^\n]*(?:oldCode|oldActivationCode|activationCode)/i);
  }
});

test('recovery strings are translated for all native localization paths', () => {
  const localizationSources = [
    read('native/android/app/src/main/java/com/tauber/nikonlink/Localization.java'),
    read('native/harmony/entry/src/main/ets/localization/Localization.ets'),
    read('native/windows/Localization.cs'),
    read('native/ios/NikonLink/en.lproj/Localizable.strings'),
    read('native/ios/NikonLink/ja.lproj/Localizable.strings'),
    read('native/ios/NikonLink/zh-Hans.lproj/Localizable.strings'),
  ];
  const keys = [
    '恢复设备码',
    '旧设备 ID',
    '旧激活码',
    '恢复到当前设备',
    '正在迁移…',
    '服务器返回的新激活码验证失败，未修改本机数据',
  ];
  for (const [index, source] of localizationSources.entries()) {
    for (const key of keys) {
      assert.ok(source.includes(key), `localization source ${index} is missing ${key}`);
    }
  }
});
