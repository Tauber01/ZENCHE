import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const root = new URL('../', import.meta.url);
const read = async (path) => readFile(new URL(path, root), 'utf8');

test('native monitor surfaces use framed scope plots instead of text sparklines', async () => {
  const [ios, android, harmony, macos, windowsXaml, windowsScope] =
    await Promise.all([
      read('native/ios/NikonLink/Views/RootView.swift'),
      read('native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java'),
      read('native/harmony/entry/src/main/ets/pages/Index.ets'),
      read('native/macos/Sources/NikonLink/main.swift'),
      read('native/windows/MainWindow.xaml'),
      read('native/windows/Controls/WaveformScope.cs'),
    ]);

  assert.match(ios, /ProfessionalScopeBoard/);
  assert.match(ios, /AudioScopePlot/);
  assert.doesNotMatch(ios, /struct MonitorSparkline/);

  assert.match(android, /class WaveformScopeView extends View/);
  assert.match(android, /RGB_PARADE/);
  assert.doesNotMatch(android, /PROFESSIONAL/);

  assert.match(harmony, /professionalScopeContext/);
  assert.match(harmony, /drawProfessionalScope/);
  assert.match(harmony, /drawAudioScope/);

  assert.match(macos, /MacProfessionalScopeBoard/);
  assert.match(macos, /MacAudioScopePlot/);

  assert.match(windowsXaml, /local:WaveformScope/);
  assert.doesNotMatch(windowsXaml, /Mode="Professional"/);
  assert.match(windowsScope, /sealed class WaveformScope/);
  assert.match(windowsScope, /RgbParade/);
});

test('scope design standard requires RGB overlay and forbids watermarks', async () => {
  const design = await read('DESIGN.md');

  assert.match(design, /## Waveform scopes/);
  assert.match(design, /RGB overlay/);
  assert.match(design, /no decorative signature, watermark/);
});

test('native scopes render dense signal clouds with footer labels', async () => {
  const [ios, android, harmony, macos, windows] = await Promise.all([
    read('native/ios/NikonLink/Views/RootView.swift'),
    read('native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java'),
    read('native/harmony/entry/src/main/ets/pages/Index.ets'),
    read('native/macos/Sources/NikonLink/main.swift'),
    read('native/windows/Controls/WaveformScope.cs'),
  ]);

  assert.match(ios, /scopeNoise/);
  assert.match(ios, /\.plusLighter/);
  assert.match(android, /scopeNoise/);
  assert.match(android, /haze\.addCircle/);
  assert.doesNotMatch(android, /canvas\.drawText\(\s*tr\("无音频源"\)/);
  assert.match(harmony, /scopeNoise/);
  assert.match(harmony, /context\.fillRect\(pointX \+ jitterX/);
  assert.doesNotMatch(harmony, /fillText\(this\.tr\('无音频源'\)/);
  assert.match(macos, /scopeNoise/);
  assert.match(macos, /\.plusLighter/);
  assert.match(windows, /ScopeNoise/);
  assert.match(windows, /AddParticle/);
  assert.doesNotMatch(windows, /Formatted\("无音频源"/);
});

test('all native analyzers produce spatial 64 by 48 density scopes', async () => {
  const [ios, android, harmony, macos, windows] = await Promise.all([
    read('native/ios/NikonLink/Camera/ProfessionalMonitor.swift'),
    read('native/android/app/src/main/java/com/tauber/nikonlink/ProfessionalMonitor.java'),
    read('native/harmony/entry/src/main/ets/monitor/ProfessionalMonitor.ets'),
    read('native/macos/Sources/NikonLink/ProfessionalMonitor.swift'),
    read('native/windows/Services/ProfessionalMonitor.cs'),
  ]);

  for (const source of [ios, android, harmony, macos, windows]) {
    assert.match(source, /64/);
    assert.match(source, /48/);
    assert.match(source, /column/iu);
    assert.match(source, /densityMap/iu);
    assert.match(source, /128.*-\s*29.*-\s*99.*128/s);
    assert.match(source, /128.*128.*-\s*116.*-\s*12/s);
  }
});

test('all native scope renderers parse real density payloads and render RGB overlay', async () => {
  const [ios, android, harmony, macos, windows] = await Promise.all([
    read('native/ios/NikonLink/Views/RootView.swift'),
    read('native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java'),
    read('native/harmony/entry/src/main/ets/pages/Index.ets'),
    read('native/macos/Sources/NikonLink/main.swift'),
    read('native/windows/Controls/WaveformScope.cs'),
  ]);

  assert.match(ios, /ScopeLevels\.density/);
  assert.match(android, /parseDensity/);
  assert.match(harmony, /parseScopeDensity/);
  assert.match(macos, /MacScopeLevels\.density/);
  assert.match(windows, /ParseDensity/);
  for (const source of [ios, android, harmony, macos, windows]) {
    assert.match(source, /parade:\s*false|SCOPE_R/u);
    assert.match(source, /RGB/);
  }
});
