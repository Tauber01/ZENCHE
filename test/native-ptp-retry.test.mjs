// S3 verification: transient PTP busy handling exists on all platforms.
// Android/Harmony auto-retry parameter writes (maxRetries=5, 200ms·n);
// macOS retries gphoto busy output; Windows retries focus drives. This file
// locks the EXISTING capability (per lead review 6dae9d37) so it cannot
// silently regress. Windows parameter writes intentionally have no auto
// retry — the difference is reported, not asserted as a feature.
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const android = "native/android/app/src/main/java/com/tauber/nikonlink/PtpCamera.java";
const harmony = "native/harmony/entry/src/main/ets/camera/PtpCamera.ets";
const macos = "native/macos/Sources/NikonLink/main.swift";
const windows = "native/windows/Services/PtpCamera.cs";

test("Android auto-retries transient parameter writes with linear backoff", async () => {
  const source = await readFile(android, "utf8");
  assert.match(
    source,
    /int maxRetries = 5;[\s\S]{0,200}setParameterCore\(name, rawValue\)/,
    "setParameter must retry up to 5 times",
  );
  assert.match(source, /Thread\.sleep\(200L \* \(attempt \+ 1\)\)/, "backoff must be 200ms·(attempt+1)");
  assert.match(source, /isTransientPtpError\(error\)/, "transient PTP errors must be recognized");
});

test("HarmonyOS auto-retries transient parameter writes with linear backoff", async () => {
  const source = await readFile(harmony, "utf8");
  assert.match(source, /const maxRetries: number = 5;/, "maxRetries must be 5");
  assert.match(source, /resolve, 200 \* \(attempt \+ 1\)\)/, "backoff must be 200ms·(attempt+1)");
  assert.match(source, /0x200F'\) \|\| message\.includes\('0x201C'\)/, "transient codes must be recognized");
});

test("macOS retries busy gphoto output up to 3 times", async () => {
  const source = await readFile(macos, "utf8");
  assert.match(source, /private func retryBusy/, "busy retry helper must exist");
  assert.match(source, /for busyAttempt in 1\.\.\.3/, "busy retry must attempt up to 3 times");
  assert.match(source, /private func isBusyFailure/, "busy detection must exist");
});

test("Windows retries focus drives (AF-ON / manual) up to 5 times", async () => {
  const source = await readFile(windows, "utf8");
  assert.match(source, /SendManualFocusDriveWithRetryAsync/, "manual focus retry must exist");
  assert.match(source, /SendAutoFocusDriveWithRetryAsync/, "AF-ON retry must exist");
  assert.match(source, /for \(var attempt = 1; attempt <= 5; attempt\+\+\)/, "focus retry must attempt up to 5 times");
  assert.match(source, /await Task\.Delay\(180 \* attempt, cancellationToken\)/, "focus backoff must be 180ms·attempt");
  assert.match(source, /IsDeviceBusyResponse\(error\.ResponseCode\)/, "busy response code must be recognized");
});
