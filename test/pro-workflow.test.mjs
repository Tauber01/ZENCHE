import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../", import.meta.url);
const read = async (path) => readFile(new URL(path, root), "utf8");

test("all native targets expose automated shooting tasks", async () => {
  const sources = await Promise.all([
    read("native/macos/Sources/NikonLink/main.swift"),
    read("native/ios/NikonLink/Models/AppModel.swift"),
    read("native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java"),
    read("native/harmony/entry/src/main/ets/pages/Index.ets"),
    read("native/windows/MainWindow.xaml.cs"),
  ]);

  for (const source of sources) {
    for (const capability of ["interval", "exposure", "focus", "bulb"]) {
      assert.ok(source.includes(capability), `missing ${capability} task`);
    }
  }
});

test("all native targets persist verified capture sessions", async () => {
  const sources = await Promise.all([
    read("native/macos/Sources/NikonLink/CaptureWorkflow.swift"),
    read("native/ios/NikonLink/Models/CaptureWorkflow.swift"),
    read("native/android/app/src/main/java/com/tauber/nikonlink/CaptureWorkflow.java"),
    read("native/harmony/entry/src/main/ets/workflow/CaptureWorkflow.ets"),
    read("native/windows/Services/CaptureWorkflow.cs"),
  ]);

  for (const source of sources) {
    assert.match(source, /SHA-?256|SHA256/i);
    assert.match(source, /xmp/i);
    assert.match(source, /Backup/);
    assert.match(source, /namingTemplate/);
  }
});

test("all native targets provide professional monitoring scopes", async () => {
  const sources = await Promise.all([
    read("native/macos/Sources/NikonLink/ProfessionalMonitor.swift"),
    read("native/ios/NikonLink/Camera/ProfessionalMonitor.swift"),
    read("native/android/app/src/main/java/com/tauber/nikonlink/ProfessionalMonitor.java"),
    read("native/harmony/entry/src/main/ets/monitor/ProfessionalMonitor.ets"),
    read("native/windows/Services/ProfessionalMonitor.cs"),
  ]);

  for (const source of sources) {
    assert.match(source, /Histogram/i);
    assert.match(source, /waveform/i);
    assert.match(source, /vectorscope/i);
    assert.match(source, /focusPeaking/i);
    assert.match(source, /falseColor/i);
  }
});

test("immersive camera UI adapts to phone orientation and desktop aspect ratio", async () => {
  const [ios, android, harmony, macos, windows] = await Promise.all([
    read("native/ios/NikonLink/Views/RootView.swift"),
    read("native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java"),
    read("native/harmony/entry/src/main/ets/pages/Index.ets"),
    read("native/macos/Sources/NikonLink/main.swift"),
    read("native/windows/MainWindow.xaml.cs"),
  ]);

  assert.match(ios, /orientationDidChangeNotification/);
  assert.match(ios, /ImmersiveFocusReticle/);
  assert.match(android, /TYPE_ROTATION_VECTOR/);
  assert.match(android, /immersiveFocusReticle/);
  assert.match(harmony, /SensorId\.ORIENTATION/);
  assert.match(harmony, /ImmersivePortraitControls/);
  assert.match(macos, /AnyLayout\(HStackLayout\(\)\)/);
  assert.match(macos, /ImmersiveMacFocusReticle/);
  assert.match(windows, /ApplyImmersiveLayout/);
  assert.match(windows, /viewer\.SizeChanged/);
});
