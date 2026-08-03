import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const read = (path) => readFile(new URL(`../${path}`, import.meta.url), 'utf8');

test('mobile AI requests allow the established proxy and outlive its polling window', async () => {
  const [manifest, securityConfig, ios, android, harmony] = await Promise.all([
    read('native/android/app/src/main/AndroidManifest.xml'),
    read('native/android/app/src/main/res/xml/network_security_config.xml'),
    read('native/ios/NikonLink/Views/RootView.swift'),
    read('native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java'),
    read('native/harmony/entry/src/main/ets/pages/Index.ets'),
  ]);

  assert.match(manifest, /android:networkSecurityConfig="@xml\/network_security_config"/);
  assert.match(manifest, /android:usesCleartextTraffic="false"/);
  assert.match(securityConfig, /base-config cleartextTrafficPermitted="false"/);
  assert.match(securityConfig, /domain-config cleartextTrafficPermitted="true"/);
  assert.match(securityConfig, />101\.34\.255\.115<\/domain>/);
  assert.match(ios, /requestTimeout: TimeInterval = 300/);
  assert.match(android, /conn\.setReadTimeout\(300_000\)/);
  assert.match(harmony, /readTimeout: 300000/);
});

test('all native AI editors expose passerby and production-artifact removal', async () => {
  const sources = await Promise.all([
    read('native/ios/NikonLink/Views/RootView.swift'),
    read('native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java'),
    read('native/harmony/entry/src/main/ets/pages/Index.ets'),
    read('native/macos/Sources/NikonLink/main.swift'),
    read('native/windows/MainWindow.xaml.cs'),
  ]);

  for (const source of sources) {
    assert.match(source, /智能移除/);
    assert.match(source, /去路人并自然补全背景/);
    assert.match(source, /去穿帮并移除摄影器材、工作人员、反光与杂物/);
  }
});

test('mobile AI failures surface proxy details instead of a generic error only', async () => {
  const [ios, android, harmony] = await Promise.all([
    read('native/ios/NikonLink/Views/RootView.swift'),
    read('native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java'),
    read('native/harmony/entry/src/main/ets/pages/Index.ets'),
  ]);

  assert.match(ios, /\["error"\] as\? String/);
  assert.match(android, /conn\.getErrorStream\(\)/);
  assert.match(android, /finalFailureMessage/);
  assert.match(harmony, /serverMessage = \(errorResult\['error'\] as string\)/);
  assert.match(harmony, /AI 生成超时，请稍后重试/);
});
