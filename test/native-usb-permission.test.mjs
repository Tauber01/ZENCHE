// S2 regression (#10): Android USB permission flow must stay idempotent —
// hasPermission short-circuits, one unique action per device, API 33+
// exported receiver, bounded wait with UsbManager as source of truth, and a
// guaranteed unregister. Guards against regressions that re-prompt or leak
// receivers.
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const main = "native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java";

test("Android permission check short-circuits when already granted", async () => {
  const source = await readFile(main, "utf8");
  assert.match(
    source,
    /ensureUsbPermission\(UsbManager manager, UsbDevice device\)[\s\S]{0,120}if \(manager\.hasPermission\(device\)\) return true;/,
    "already-granted permission must not re-trigger a dialog",
  );
});

test("Android uses a per-device unique action and cannot re-fire the same PendingIntent", async () => {
  const source = await readFile(main, "utf8");
  assert.match(
    source,
    /USB_PERMISSION_ACTION\s*\+\s*"\."\s*\+\s*device\.getDeviceId\(\)\s*\+\s*"\."\s*\+\s*UUID\.randomUUID\(\)/,
    "permission action must be unique per device and request",
  );
  assert.match(
    source,
    /PendingIntent\.FLAG_CANCEL_CURRENT \| PendingIntent\.FLAG_IMMUTABLE/,
    "re-issuing a request must cancel the previous pending intent",
  );
});

test("Android registers the permission receiver with RECEIVER_EXPORTED on API 33+", async () => {
  const source = await readFile(main, "utf8");
  assert.match(
    source,
    /Build\.VERSION\.SDK_INT >= 33[\s\S]{0,300}Context\.RECEIVER_EXPORTED/,
    "API 33+ must use an exported receiver for the privileged USB component",
  );
});

test("Android waits on a bounded deadline and trusts UsbManager as source of truth", async () => {
  const source = await readFile(main, "utf8");
  assert.match(source, /35_000/, "permission wait must be bounded");
  assert.match(
    source,
    /if \(manager\.hasPermission\(device\)\) \{\s*granted\.set\(true\);/,
    "result must be derived from UsbManager state, not OEM extras",
  );
});

test("Android always unregisters the permission receiver after the wait", async () => {
  const source = await readFile(main, "utf8");
  assert.match(source, /unregisterReceiver\(receiver\)/, "receiver must be unregistered");
  assert.match(
    source,
    /catch \(IllegalArgumentException ignored\)/,
    "unregister must tolerate already-unregistered receivers",
  );
});
