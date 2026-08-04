// S4 regression (#33/#37): USB transport rebuild must release the old
// interface/connection before reopening, on both Android and HarmonyOS.
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const android = "native/android/app/src/main/java/com/tauber/nikonlink/PtpCamera.java";
const harmony = "native/harmony/entry/src/main/ets/camera/PtpCamera.ets";

test("Android recovery closes the old transport before reopening", async () => {
  const source = await readFile(android, "utf8");
  assert.match(
    source,
    /recoverUsbTransport\(int failedAttempt\)[\s\S]{0,400}closeConnectionOnly\(\)/,
    "recovery must release the old transport before reopening",
  );
});

test("Android release order: interface first, then connection close", async () => {
  const source = await readFile(android, "utf8");
  assert.match(
    source,
    /connection\.releaseInterface\(cameraInterface\)[\s\S]{0,200}connection\.close\(\)/,
    "interface must be released before the connection is closed",
  );
});

test("Android openFreshTransport defensively closes any prior transport first", async () => {
  const source = await readFile(android, "utf8");
  assert.match(
    source,
    /openFreshTransport\(UsbDevice device\)[\s\S]{0,150}closeConnectionOnly\(\);/,
    "fresh open must start from a clean connection state",
  );
});

test("Android disconnect path closes the PTP session then the transport", async () => {
  const source = await readFile(android, "utf8");
  assert.match(source, /synchronized void disconnect\(\)[\s\S]{0,600}closeTransport\(\)/);
});

test("HarmonyOS releases the interface before closing the pipe", async () => {
  const source = await readFile(harmony, "utf8");
  assert.match(
    source,
    /usbManager\.releaseInterface\(this\.pipe, this\.cameraInterface\)[\s\S]{0,120}usbManager\.closePipe\(this\.pipe\)/,
    "interface must be released before the pipe is closed",
  );
});
