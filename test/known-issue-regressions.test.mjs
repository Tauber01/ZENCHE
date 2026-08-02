import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const sources = {
  android: "native/android/app/src/main/java/com/tauber/nikonlink/PtpCamera.java",
  harmony: "native/harmony/entry/src/main/ets/camera/PtpCamera.ets",
  macos: "native/macos/Sources/NikonLink/main.swift",
  windows: "native/windows/Services/PtpCamera.cs",
  "windows-ptp": "native/windows/Services/PtpCamera.cs",
  "windows-vendor-ops": "native/windows/Services/PtpVendorOps.cs",
};

async function source(name) {
  return readFile(sources[name], "utf8");
}

test("native Nikon transports fall back to photo and movie shutter properties", async () => {
  const [android, harmony, windowsPtp, windowsOps] = await Promise.all([
    source("android"),
    source("harmony"),
    source("windows-ptp"),
    source("windows-vendor-ops"),
  ]);

  for (const text of [android, harmony, windowsOps]) {
    assert.match(text, /0xd100/i, "missing Nikon photo shutter property (0xd100)");
    assert.match(text, /0xd1a8/i, "missing Nikon movie shutter property (0xd1a8)");
    assert.match(text, /videoExposureTime/, "missing video shutter routing");
  }
  assert.ok(
    !android.includes(
      "Boolean.FALSE.equals(writableProperties.get(property))",
    ),
    "Android must still try state-sensitive Nikon properties",
  );
  assert.doesNotMatch(
    windowsPtp,
    /TryGetValue\\(property, out var writable\\)[\\s\\S]{0,120}continue;/,
    "Windows must still try state-sensitive Nikon properties",
  );
});

test("Bulb capture releases Nikon remote mode on direct PTP platforms", async () => {
  const [android, harmony, windows] = await Promise.all([
    source("android"),
    source("harmony"),
    source("windows"),
  ]);

  assert.match(android, /CHANGE_CAMERA_MODE,\s*new long\[\]\{0\}/);
  assert.match(harmony, /CHANGE_CAMERA_MODE,\s*\[0\]/);
  assert.match(windows, /ChangeCameraMode,\s*\[0\]/);
  for (const text of [android, harmony, windows]) {
    assert.match(
      text,
      /Keep Bulb|Bulb is an app capture state/,
      "Bulb selection must remain local until capture",
    );
  }
});

test("macOS selects writable Nikon shutter keys and drains live-view stderr", async () => {
  const macos = await source("macos");

  assert.match(macos, /movieshutterspeed/);
  assert.match(macos, /shutterspeed2/);
  assert.match(macos, /appendAvailableLiveViewErrors\(\)/);
  assert.match(macos, /liveViewErrorBuffer/);
});

test("release workflow is idempotent and requires detailed release notes", async () => {
  const workflow = await readFile(".github/workflows/release.yml", "utf8");

  assert.match(workflow, /docs\/releases\/\$GITHUB_REF_NAME\.md/);
  assert.match(workflow, /gh release view/);
  assert.match(workflow, /\[\[ -f "\$asset" \]\]/);
  assert.match(
    workflow,
    /gh release upload "\$GITHUB_REF_NAME" "\$\{assets\[@\]\}" --clobber/,
  );
  assert.doesNotMatch(workflow, /--generate-notes/);
});
