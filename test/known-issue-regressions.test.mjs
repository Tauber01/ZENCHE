import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";
import test from "node:test";

const activationPublicKey =
  "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAngqgOi5fjajCPusMNsfB" +
  "FdMmWyzAGArL5bA+JK/uW+Md/YDtGvXjgSodev7VOQ9SPWqHUYA+XTpdyeCA+weL" +
  "32JhFf+8+a28DjIp7RMv962m1qXJLtcdFbiBjWGDWF+itDJGUgR5OQbxV8xDd/kj" +
  "c1ZT5ft7r2KwECUvwjKr9SAOWGJPK9oNmo9u2kW/6PbjpSEIhDH88FYloNWxpmdW" +
  "XoQ2YYAfd5sKc0CNcBFdu2oEFGFHeUufbhgkZWtDPCS299W4TuWyTDfWPx4+Raap" +
  "bcVF9RfFPa1uI7MpyrOqrGgSnuSC7HxY/B+NXm5rt4p3ZRaOzyKBiZEQ8Sg0XpKI" +
  "3wIDAQAB";

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

test("direct camera capture waits for readiness and retries busy downloads", async () => {
  const [android, harmony, macos, windows, androidActivity] = await Promise.all([
    source("android"),
    source("harmony"),
    source("macos"),
    source("windows"),
    readFile(
      "native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java",
      "utf8",
    ),
  ]);

  assert.match(android, /waitUntilDeviceReady\(6_000\)/);
  assert.match(android, /message\.contains\("0x2009"\)/);
  assert.match(android, /for \(int attempt = 0; attempt < 4; attempt\+\+\)/);
  assert.doesNotMatch(
    androidActivity,
    /if \(packet\.monitoring\) \{\s*decodeOpts\.inSampleSize = 2;/,
  );

  assert.match(harmony, /waitUntilDeviceReady\(6000\)/);
  assert.match(harmony, /candidate\.message\.includes\('0x2009'\)/);
  assert.match(harmony, /for \(let attempt: number = 0; attempt < 4; attempt\+\+\)/);

  assert.match(macos, /private func retryBusy/);
  assert.match(macos, /private func isBusyFailure/);
  assert.match(macos, /private func waitUntilDeviceReady/);
  assert.match(windows, /WaitUntilDeviceReadyAsync\(8_000, cancellationToken\)/);
});

test("strict PTP hosts use transaction zero for OpenSession", async () => {
  const [android, harmony, windows] = await Promise.all([
    source("android"),
    source("harmony"),
    source("windows"),
  ]);
  assert.match(android, /operation == OPEN_SESSION[\s\S]*current = 0/);
  assert.match(harmony, /operation === OPEN_SESSION[\s\S]*\? 0/);
  assert.match(windows, /operation == OpenSession \? 0 : \+\+_transaction/);
  for (const text of [harmony, windows]) {
    assert.match(text, /SESSION_ALREADY_OPEN|SessionAlreadyOpen/);
  }
});

test("Windows activation rejects codes that fail local RSA verification", async () => {
  const windows = await readFile("native/windows/MainWindow.xaml.cs", "utf8");

  assert.match(windows, /private const string AiActivationPublicKey/);
  assert.match(windows, /private static bool VerifyActivationCode/);
  assert.match(windows, /rsa\.VerifyData/);
  assert.match(
    windows,
    /if \(!VerifyActivationCode\(code, GetDeviceId\(\)\)\)[\s\S]{0,180}return;/,
  );
});

test("all native activation verifiers trust the production redemption key", async () => {
  const paths = [
    "native/ios/NikonLink/Views/RootView.swift",
    "native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java",
    "native/harmony/entry/src/main/ets/pages/Index.ets",
    "native/macos/Sources/NikonLink/main.swift",
    "native/windows/MainWindow.xaml.cs",
  ];
  const sources = await Promise.all(paths.map((path) => readFile(path, "utf8")));

  for (const [index, text] of sources.entries()) {
    const keyStart = text.indexOf(activationPublicKey.slice(0, 64));
    assert.notEqual(keyStart, -1, `${paths[index]} is missing the activation key`);
    const candidate = [...text.slice(Math.max(0, keyStart - 1), keyStart + 1200).matchAll(/["']([A-Za-z0-9+/=]{8,})["']/g)]
      .map((match) => match[1])
      .join("");
    assert.ok(
      candidate.includes(activationPublicKey),
      `${paths[index]} has a different activation public key`,
    );
  }

  assert.equal(
    createHash("sha256")
      .update(Buffer.from(activationPublicKey, "base64"))
      .digest("hex"),
    "cd9a1aa5590abb0677216fe56d8420f7a3ddcf9635002a5736a3177b054c356c",
  );
  assert.match(sources[2], /createVerify\('RSA2048\|PKCS1\|SHA256'\)/);
  assert.match(sources[2], /verifySync\(payloadBlob, signatureBlob\)/);
});

test("native device IDs remain stable across app version upgrades", async () => {
  const [ios, android, harmony, macos, windows] = await Promise.all([
    readFile("native/ios/NikonLink/Views/RootView.swift", "utf8"),
    readFile(
      "native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java",
      "utf8",
    ),
    readFile("native/harmony/entry/src/main/ets/pages/Index.ets", "utf8"),
    readFile("native/macos/Sources/NikonLink/main.swift", "utf8"),
    readFile("native/windows/MainWindow.xaml.cs", "utf8"),
  ]);

  assert.match(ios, /stableDeviceId:[\s\S]{0,1400}loadDeviceIdFromKeychain/);
  assert.match(ios, /string\(forKey: dk\)[\s\S]{0,300}saveDeviceIdToKeychain/);
  assert.match(android, /getString\("ai_device_id", ""\)[\s\S]{0,500}ANDROID_ID/);
  assert.match(android, /putString\("ai_device_id", id\)\.commit\(\)/);
  assert.match(harmony, /getSync\('ai_device_id', ''\)[\s\S]{0,700}generateRandomUUID/);
  assert.match(harmony, /putSync\('ai_device_id', id\)[\s\S]{0,100}prefs\.flush\(\)/);
  assert.doesNotMatch(harmony, /deviceInfo\.(?:udid|serial)/);
  assert.match(macos, /stableDeviceId:[\s\S]{0,1800}loadDeviceIdFromKeychain/);
  assert.match(macos, /string\(forKey: deviceIdKey\)[\s\S]{0,300}saveDeviceIdToKeychain/);
  assert.match(windows, /ai-device-id\.txt[\s\S]{0,500}WindowsIdentity\.GetCurrent/);

  for (const source of [ios, android, harmony, macos, windows]) {
    const marker = source.search(/stableDeviceId|aiDeviceId\(|getDeviceId\(|GetDeviceId\(/);
    const deviceIdImplementation = source.slice(marker, marker + 2200);
    assert.doesNotMatch(
      deviceIdImplementation,
      /CURRENT_VERSION|MARKETING_VERSION|versionName|DisplayVersion/,
    );
  }
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
