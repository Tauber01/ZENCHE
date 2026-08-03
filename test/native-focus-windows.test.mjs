import assert from "node:assert/strict";
import fs from "node:fs";
import test from "node:test";

const root = new URL("../", import.meta.url).pathname;
const read = (path) => fs.readFileSync(`${root}${path}`, "utf8");

test("Windows Nikon manual focus serializes live view and retries busy PTP", () => {
  const source = read("native/windows/Services/PtpCamera.cs");

  assert.match(source, /ManualFocusDriveOperation = 0x9204/);
  assert.match(source, /StopLiveViewCoreAsync\(cancellationToken\)/);
  assert.match(source, /StartLiveViewForManualFocusAsync\(cancellationToken\)/);
  assert.match(source, /SendManualFocusDriveWithRetryAsync\(/);
  assert.match(source, /responseCode == 0x2019/);
  assert.match(source, /for \(var attempt = 1; attempt <= 5; attempt\+\+\)/);
  assert.match(source, /1 => 128u/);
  assert.match(source, /2 => 512u/);
  assert.match(source, /_ => 1024u/);
  assert.match(source, /\[direction, amount\]/);
});
