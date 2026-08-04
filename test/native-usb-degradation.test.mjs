// S1 regression: Android UsbRequest→bulkTransfer degradation must be STICKY
// within a USB session. A successful synchronous fallback must switch the
// session to synchronous mode so later requests do not wait out the async
// timeout (10–12s) again — the recurring pattern in #33/#37/#39/#40.
// Async probing resumes only when a new transport is established; a failed
// fallback must NOT latch synchronous mode.
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const android = "native/android/app/src/main/java/com/tauber/nikonlink/PtpCamera.java";
const harmony = "native/harmony/entry/src/main/ets/camera/PtpCamera.ets";

test("Android holds a per-session sticky sync-transport flag", async () => {
  const source = await readFile(android, "utf8");
  assert.match(source, /private boolean syncTransport;/, "missing sticky flag field");
});

test("Android routes directly to bulkTransfer when the session is sticky", async () => {
  const source = await readFile(android, "utf8");
  const stickyBranch = /if \(syncTransport\)[\s\S]{0,400}transferViaBulkTransfer/;
  assert.match(source, stickyBranch, "sticky session must skip the async probe");
  assert.doesNotMatch(
    source,
    /if \(syncTransport\)[\s\S]{0,200}transferViaUsbRequest/,
    "sticky session must not re-enter the async probe",
  );
  assert.doesNotMatch(
    source,
    /if \(syncTransport\)[\s\S]{0,200}clearEndpointHalt/,
    "sticky fast path must not clear the endpoint halt on every request (no extra control transfers)",
  );
});

test("Android latches sticky only after a successful bulk fallback", async () => {
  const source = await readFile(android, "utf8");
  assert.equal(
    (source.match(/syncTransport = true/g) || []).length,
    1,
    "sticky must be set in exactly one place",
  );
  assert.match(
    source,
    /transferViaBulkTransfer\([\s\S]{0,650}syncTransport = true/,
    "sticky must be set after a successful bulk fallback",
  );
  assert.doesNotMatch(
    source,
    /catch \(Exception syncError\)[\s\S]{0,150}syncTransport = true/,
    "a failed bulk fallback must NOT latch sticky mode",
  );
  assert.match(
    source,
    /catch \(Exception syncError\)[\s\S]{0,650}throw asyncError/,
    "fallback failure must still surface the original async error",
  );
});

test("Android keeps clear-halt on the fallback path, not on the sticky fast path", async () => {
  const source = await readFile(android, "utf8");
  assert.match(
    source,
    /catch \(Exception asyncError\)[\s\S]{0,400}clearEndpointHalt\(endpoint\)[\s\S]{0,300}transferViaBulkTransfer/,
    "the first fallback must still clear the endpoint halt before bulk transfer",
  );
});

test("Android degrades only on the four known async failures, via one helper", async () => {
  const source = await readFile(android, "utf8");
  assert.match(
    source,
    /private boolean isAsyncDegradable\(Exception error\)/,
    "the degradable-condition helper must exist",
  );
  assert.match(
    source,
    /if \(!isAsyncDegradable\(asyncError\)\) throw asyncError/,
    "the transfer gate must route through the helper",
  );
  // Exactly the four messages observed in #21/#40 — nothing broader.
  assert.match(source, /contains\("超时"\)/, "helper must recognize timeouts");
  assert.match(
    source,
    /contains\("未返回有效的完成结果"\)/,
    "helper must recognize the missing async completion (#21) and enter fallback",
  );
  assert.match(
    source,
    /contains\("无法初始化异步 USB 请求"\)/,
    "helper must recognize async request initialize failure (#40 logs)",
  );
  assert.match(
    source,
    /contains\("无法提交异步 USB 请求"\)/,
    "helper must recognize async request submit failure (#40 logs)",
  );
  assert.doesNotMatch(
    source,
    /isTimeout = asyncError\.getMessage/,
    "the old narrow single-condition gate must be gone",
  );
});

test("Android rejects arbitrary device/parameter errors from degradation", async () => {
  // R5.1: degradation stays message-precise. Any async error whose message is
  // NOT one of the four allowed strings must surface to the caller unchanged —
  // no exception-type matching, no generic "设备"/"参数"/"错误" wildcards.
  const source = await readFile(android, "utf8");
  const helper = source.match(/private boolean isAsyncDegradable\(Exception error\) \{[\s\S]*?\n    \}/);
  assert.ok(helper, "helper body must be extractable");
  assert.doesNotMatch(
    helper[0],
    /instanceof|getClass\(\)|getSimpleName/,
    "degradation must not key off exception type",
  );
  assert.doesNotMatch(
    helper[0],
    /contains\("设备"\)|contains\("参数"\)|contains\("错误码"\)|contains\("同步"\)/,
    "device/parameter/generic-error messages must NOT degrade",
  );
  const containsCalls = [...helper[0].matchAll(/contains\("([^"]*)"\)/g)].map((m) => m[1]);
  assert.deepEqual(
    containsCalls,
    ["超时", "未返回有效的完成结果", "无法初始化异步 USB 请求", "无法提交异步 USB 请求"],
    "helper must allow exactly the four known messages and nothing else",
  );
});

test("Android resets sticky on new transport and on close", async () => {
  const source = await readFile(android, "utf8");
  assert.match(
    source,
    /openFreshTransport\(UsbDevice device\)[\s\S]{0,600}syncTransport = false/,
    "a freshly opened transport must resume async probing",
  );
  assert.match(
    source,
    /closeConnectionOnly\(\)[\s\S]{0,300}syncTransport = false/,
    "closing the connection must clear sticky state",
  );
});

test("Harmony stays synchronous-only and needs no fallback", async () => {
  // HarmonyOS uses usbManager.bulkTransfer exclusively (aggregate < 200KB),
  // so there is no async request to degrade from.
  const source = await readFile(harmony, "utf8");
  assert.match(source, /usbManager\.bulkTransfer/);
  assert.doesNotMatch(source, /UsbRequest/, "Harmony must not use async UsbRequest");
});
