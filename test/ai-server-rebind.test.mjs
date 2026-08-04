import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import crypto from "node:crypto";
import http from "node:http";
import { createApp, resolveMigrationTail } from "../ai-server/app.mjs";

const { publicKey, privateKey } = crypto.generateKeyPairSync("rsa", { modulusLength: 2048 });
const TEST_PUBLIC_KEY = publicKey.export({ type: "pkcs1", format: "pem" });

function dateStr(offsetDays = 0) {
  const d = new Date();
  d.setDate(d.getDate() + offsetDays);
  return `${d.getFullYear()}${String(d.getMonth() + 1).padStart(2, "0")}${String(d.getDate()).padStart(2, "0")}`;
}

function makeCode(deviceId, expiry = dateStr(120)) {
  const signer = crypto.createSign("RSA-SHA256");
  signer.update(`${deviceId}:${expiry}:a1b2c3d4e5f6`, "utf8");
  return `ZENCHE-AI-${signer.sign(privateKey, "base64")}-${expiry}`;
}

function tmpDir() {
  return fs.mkdtempSync(path.join(os.tmpdir(), "zenche-ai-rebind-"));
}

function record(activation, expiry, used = 0) {
  return { activation, expiry, used, last_seen: Date.now() };
}

async function startRebind({ devices = {}, ...opts } = {}) {
  const cleanupDir = tmpDir();
  const dbDir = path.join(cleanupDir, "data");
  fs.mkdirSync(dbDir, { recursive: true });
  if (Object.keys(devices).length > 0) {
    fs.writeFileSync(path.join(dbDir, "devices.json"), JSON.stringify(devices));
  }
  const app = await createApp({
    publicKeyPem: TEST_PUBLIC_KEY,
    dbDir,
    enableRebind: true,
    signNewCodeImpl: async (newDeviceId, expiry) => ({ ok: true, code: makeCode(newDeviceId, expiry) }),
    drawImageImpl: async () => "TEST_MOCK",
    rebindIpLimit: 100,
    rebindActivationLimit: 100,
    auditLogImpl: () => {},
    ...opts,
  });
  return { ...app, cleanupDir };
}

async function request(port, route, body, method = "POST", headers = {}) {
  const res = await fetch(`http://127.0.0.1:${port}${route}`, {
    method,
    headers: { "Content-Type": "application/json", ...headers },
    body: method === "POST" ? JSON.stringify(body) : undefined,
  });
  return {
    status: res.status,
    json: await res.json(),
    remaining: res.headers.get("X-ZENCHE-Remaining"),
    retryAfter: res.headers.get("Retry-After"),
  };
}

function postRebind(port, activationCode, oldDeviceId, newDeviceId) {
  return request(port, "/v1/ai/rebind", { activationCode, oldDeviceId, newDeviceId });
}

function postAi(port, activationCode, deviceId, prompt = "test") {
  return request(port, "/v1/ai", { activationCode, deviceId, prompt });
}

async function closeApp(app) {
  app.server.closeAllConnections?.();
  await new Promise((resolve) => app.server.close(resolve));
  fs.rmSync(app.cleanupDir, { recursive: true, force: true });
}

function deferred() {
  let resolve;
  let reject;
  const promise = new Promise((res, rej) => { resolve = res; reject = rej; });
  return { promise, resolve, reject };
}

async function waitUntil(predicate) {
  for (let i = 0; i < 100; i += 1) {
    if (predicate()) return;
    await new Promise((resolve) => setTimeout(resolve, 5));
  }
  throw new Error("condition was not reached");
}

test("rebind route is disabled by default", async (t) => {
  const cleanupDir = tmpDir();
  const app = await createApp({
    publicKeyPem: TEST_PUBLIC_KEY,
    dbDir: path.join(cleanupDir, "data"),
    drawImageImpl: async () => "TEST_MOCK",
  });
  t.after(async () => {
    app.server.closeAllConnections?.();
    await new Promise((resolve) => app.server.close(resolve));
    fs.rmSync(cleanupDir, { recursive: true, force: true });
  });
  const res = await request(app.port, "/v1/ai/rebind", {});
  assert.equal(res.status, 404);
});

test("enabled production rebind requires a signer secret or injected signer", async () => {
  const cleanupDir = tmpDir();
  assert.throws(
    () => createApp({ publicKeyPem: TEST_PUBLIC_KEY, dbDir: path.join(cleanupDir, "data"), enableRebind: true }),
    /rebind requires/,
  );
  fs.rmSync(cleanupDir, { recursive: true, force: true });
});

test("T1/T17/T28: migration preserves usage, signs for the new device, and continues counting", async (t) => {
  const expiry = dateStr(120);
  const oldCode = makeCode("old-1", expiry);
  const app = await startRebind({ devices: { "old-1": record(oldCode, expiry, 37) } });
  t.after(() => closeApp(app));

  const migrated = await postRebind(app.port, oldCode, "old-1", "new-1");
  assert.equal(migrated.status, 200);
  assert.equal(migrated.json.used, 37);
  assert.equal(migrated.json.remaining, 63);
  assert.notEqual(migrated.json.newCode, oldCode);
  const snapshot = app.snapshot().devices;
  assert.equal(snapshot["old-1"].migrated_to, "new-1");
  assert.equal(snapshot["new-1"].activation, migrated.json.newCode);
  assert.equal(snapshot["new-1"].used, 37);

  const ai = await postAi(app.port, migrated.json.newCode, "new-1");
  assert.equal(ai.status, 200);
  assert.equal(ai.remaining, "62");
  assert.equal(app.snapshot().devices["new-1"].used, 38);
});

test("T2: same-device request is idempotent and does not call the signer or write", async (t) => {
  const expiry = dateStr(120);
  const code = makeCode("same", expiry);
  let signerCalls = 0;
  const app = await startRebind({
    devices: { same: record(code, expiry, 4) },
    signNewCodeImpl: async () => { signerCalls += 1; throw new Error("must not sign"); },
  });
  t.after(() => closeApp(app));
  const before = fs.readFileSync(app.dbFile, "utf8");
  const res = await postRebind(app.port, code, "same", "same");
  assert.equal(res.status, 200);
  assert.equal(res.json.newCode, code);
  assert.equal(signerCalls, 0);
  assert.equal(fs.readFileSync(app.dbFile, "utf8"), before);
});

test("T3: malformed activation is rejected with 401", async (t) => {
  const app = await startRebind();
  t.after(() => closeApp(app));
  const res = await postRebind(app.port, "not-a-code", "old", "new");
  assert.equal(res.status, 401);
  assert.match(res.json.error, /格式/);
});

test("T4: activation signed for another device is rejected with 401", async (t) => {
  const code = makeCode("someone-else");
  const app = await startRebind({ devices: { old: record(code, dateStr(120), 1) } });
  t.after(() => closeApp(app));
  const res = await postRebind(app.port, code, "old", "new");
  assert.equal(res.status, 401);
  assert.match(res.json.error, /不匹配/);
});

test("T5: expired activation is rejected with 401", async (t) => {
  const expiry = dateStr(-1);
  const code = makeCode("expired", expiry);
  const app = await startRebind({ devices: { expired: record(code, expiry, 1) } });
  t.after(() => closeApp(app));
  const res = await postRebind(app.port, code, "expired", "new");
  assert.equal(res.status, 401);
  assert.match(res.json.error, /过期/);
});

test("T6: a valid code without an existing binding record cannot migrate", async (t) => {
  const app = await startRebind();
  t.after(() => closeApp(app));
  const res = await postRebind(app.port, makeCode("unused"), "unused", "new");
  assert.equal(res.status, 403);
  assert.match(res.json.error, /未绑定/);
});

test("T7/T20: replay to the same target returns the same code without signing twice", async (t) => {
  const expiry = dateStr(120);
  const code = makeCode("replay-old", expiry);
  let signerCalls = 0;
  const app = await startRebind({
    devices: { "replay-old": record(code, expiry, 8) },
    signNewCodeImpl: async (newDeviceId, exp) => {
      signerCalls += 1;
      return { ok: true, code: makeCode(newDeviceId, exp) };
    },
  });
  t.after(() => closeApp(app));
  const first = await postRebind(app.port, code, "replay-old", "replay-new");
  const second = await postRebind(app.port, code, "replay-old", "replay-new");
  assert.equal(first.status, 200);
  assert.equal(second.status, 200);
  assert.equal(second.json.newCode, first.json.newCode);
  assert.equal(signerCalls, 1);
});

test("T8: a frozen activation cannot be copied to another target", async (t) => {
  const expiry = dateStr(120);
  const code = makeCode("freeze-old", expiry);
  const app = await startRebind({ devices: { "freeze-old": record(code, expiry, 2) } });
  t.after(() => closeApp(app));
  assert.equal((await postRebind(app.port, code, "freeze-old", "first-target")).status, 200);
  const res = await postRebind(app.port, code, "freeze-old", "second-target");
  assert.equal(res.status, 409);
  assert.match(res.json.error, /其他设备/);
});

test("T9: chained migration requires the current binding and preserves usage", async (t) => {
  const expiry = dateStr(120);
  const codeA = makeCode("chain-a", expiry);
  const app = await startRebind({ devices: { "chain-a": record(codeA, expiry, 12) } });
  t.after(() => closeApp(app));
  const toB = await postRebind(app.port, codeA, "chain-a", "chain-b");
  const toC = await postRebind(app.port, toB.json.newCode, "chain-b", "chain-c");
  assert.equal(toC.status, 200);
  assert.equal(toC.json.used, 12);
  const snapshot = app.snapshot().devices;
  assert.equal(snapshot["chain-a"].migrated_to, "chain-b");
  assert.equal(snapshot["chain-b"].migrated_to, "chain-c");
  assert.equal(snapshot["chain-c"].migrated_from, "chain-b");
});

test("T10: an occupied target is never overwritten", async (t) => {
  const expiry = dateStr(120);
  const oldCode = makeCode("occupied-old", expiry);
  const targetCode = makeCode("occupied-target", expiry);
  const app = await startRebind({
    devices: {
      "occupied-old": record(oldCode, expiry, 2),
      "occupied-target": record(targetCode, expiry, 9),
    },
  });
  t.after(() => closeApp(app));
  const res = await postRebind(app.port, oldCode, "occupied-old", "occupied-target");
  assert.equal(res.status, 409);
  assert.match(res.json.error, /已有激活记录/);
  assert.equal(app.snapshot().devices["occupied-target"].activation, targetCode);
});

test("T19/T27: signer failure leaves memory and disk unchanged", async (t) => {
  const expiry = dateStr(120);
  const code = makeCode("sign-old", expiry);
  const app = await startRebind({
    devices: { "sign-old": record(code, expiry, 6) },
    signNewCodeImpl: async () => { throw new Error("signer unavailable"); },
  });
  t.after(() => closeApp(app));
  const before = fs.readFileSync(app.dbFile, "utf8");
  const res = await postRebind(app.port, code, "sign-old", "sign-new");
  assert.equal(res.status, 502);
  assert.match(res.json.error, /签发失败/);
  assert.equal(fs.readFileSync(app.dbFile, "utf8"), before);
  assert.equal(app.snapshot().devices["sign-new"], undefined);
  assert.equal(app.snapshot().devices["sign-old"].migrated_to, undefined);
});

test("T27: a tampered signed code is rejected before migration", async (t) => {
  const expiry = dateStr(120);
  const code = makeCode("tamper-old", expiry);
  const app = await startRebind({
    devices: { "tamper-old": record(code, expiry, 3) },
    signNewCodeImpl: async () => ({ ok: true, code: makeCode("wrong-target", expiry) }),
  });
  t.after(() => closeApp(app));
  const res = await postRebind(app.port, code, "tamper-old", "tamper-new");
  assert.equal(res.status, 502);
  assert.equal(app.snapshot().devices["tamper-new"], undefined);
});

test("T14/T18/T29: old activation cannot consume on either side after migration", async (t) => {
  const expiry = dateStr(120);
  const code = makeCode("old-code-device", expiry);
  const app = await startRebind({ devices: { "old-code-device": record(code, expiry, 5) } });
  t.after(() => closeApp(app));
  const migrated = await postRebind(app.port, code, "old-code-device", "new-code-device");
  assert.equal(migrated.status, 200);
  const onOld = await postAi(app.port, code, "old-code-device");
  const onNew = await postAi(app.port, code, "new-code-device");
  assert.equal(onOld.status, 409);
  assert.equal(onNew.status, 403);
  assert.equal(app.snapshot().devices["new-code-device"].used, 5);
});

test("T15: activation fingerprint rate limit returns 429 and Retry-After", async (t) => {
  const expiry = dateStr(120);
  const code = makeCode("rate-old", expiry);
  const app = await startRebind({
    devices: { "rate-old": record(code, expiry, 1) },
    rebindActivationLimit: 2,
  });
  t.after(() => closeApp(app));
  assert.equal((await postRebind(app.port, code, "rate-old", "rate-new")).status, 200);
  assert.equal((await postRebind(app.port, code, "rate-old", "rate-new")).status, 200);
  const limited = await postRebind(app.port, code, "rate-old", "rate-new");
  assert.equal(limited.status, 429);
  assert.equal(limited.retryAfter, "60");
});

test("IP rate limiting trusts X-Forwarded-For only from the loopback proxy", async (t) => {
  const expiry = dateStr(120);
  const codeA = makeCode("proxy-a", expiry);
  const codeB = makeCode("proxy-b", expiry);
  const app = await startRebind({
    devices: {
      "proxy-a": record(codeA, expiry, 1),
      "proxy-b": record(codeB, expiry, 1),
    },
    rebindIpLimit: 1,
  });
  t.after(() => closeApp(app));
  const first = await request(app.port, "/v1/ai/rebind", {
    activationCode: codeA, oldDeviceId: "proxy-a", newDeviceId: "proxy-a-new",
  }, "POST", { "X-Forwarded-For": "198.51.100.10" });
  const second = await request(app.port, "/v1/ai/rebind", {
    activationCode: codeB, oldDeviceId: "proxy-b", newDeviceId: "proxy-b-new",
  }, "POST", { "X-Forwarded-For": "198.51.100.11" });
  assert.equal(first.status, 200);
  assert.equal(second.status, 200);
});

test("T16: non-POST and unknown rebind paths return 404", async (t) => {
  const app = await startRebind();
  t.after(() => closeApp(app));
  assert.equal((await request(app.port, "/v1/ai/rebind", null, "GET")).status, 404);
  assert.equal((await request(app.port, "/v1/ai/rebind-extra", {})).status, 404);
});

test("T23: an in-flight AI request blocks migration", async (t) => {
  const expiry = dateStr(120);
  const code = makeCode("slow-ai", expiry);
  const gate = deferred();
  let started = false;
  const app = await startRebind({
    devices: { "slow-ai": record(code, expiry, 3) },
    drawImageImpl: async () => { started = true; return gate.promise; },
  });
  t.after(() => closeApp(app));
  const aiPromise = postAi(app.port, code, "slow-ai");
  await waitUntil(() => started);
  const blocked = await postRebind(app.port, code, "slow-ai", "slow-ai-new");
  assert.equal(blocked.status, 409);
  assert.match(blocked.json.error, /进行中的 AI 请求/);
  gate.resolve("OK");
  assert.equal((await aiPromise).status, 200);
});

test("T24: migration remains blocked until both concurrent AI requests finish", async (t) => {
  const expiry = dateStr(120);
  const code = makeCode("two-ai", expiry);
  const gates = [deferred(), deferred()];
  let calls = 0;
  const app = await startRebind({
    devices: { "two-ai": record(code, expiry, 0) },
    drawImageImpl: async () => gates[calls++].promise,
  });
  t.after(() => closeApp(app));
  const first = postAi(app.port, code, "two-ai", "first");
  const second = postAi(app.port, code, "two-ai", "second");
  await waitUntil(() => calls === 2);
  gates[0].resolve("FIRST");
  assert.equal((await first).status, 200);
  const blocked = await postRebind(app.port, code, "two-ai", "two-ai-new");
  assert.equal(blocked.status, 409);
  gates[1].resolve("SECOND");
  assert.equal((await second).status, 200);
  assert.equal((await postRebind(app.port, code, "two-ai", "two-ai-new")).status, 200);
});

test("T25: failed in-flight work refunds once and migration-tail resolution reaches the live binding", async (t) => {
  const expiry = dateStr(120);
  const code = makeCode("rollback-old", expiry);
  const gate = deferred();
  let started = false;
  const app = await startRebind({
    devices: { "rollback-old": record(code, expiry, 9) },
    drawImageImpl: async () => {
      started = true;
      return gate.promise;
    },
  });
  t.after(() => closeApp(app));

  const aiPromise = postAi(app.port, code, "rollback-old");
  await waitUntil(() => started);
  assert.equal(app.snapshot().devices["rollback-old"].used, 10);
  assert.equal(
    (await postRebind(app.port, code, "rollback-old", "rollback-new")).status,
    409,
  );
  gate.reject(new Error("injected upstream failure"));
  assert.equal((await aiPromise).status, 502);
  assert.equal(app.snapshot().devices["rollback-old"].used, 9);
  assert.equal(app.snapshot().devices["rollback-old"].migrated_to, undefined);

  const chain = {
    "rollback-old": { migrated_to: "rollback-mid" },
    "rollback-mid": { migrated_to: "rollback-new" },
    "rollback-new": { used: 9 },
  };
  assert.equal(resolveMigrationTail(chain, "rollback-old"), "rollback-new");
});

test("T30: the rebind write lock blocks new AI consumption during slow signing", async (t) => {
  const expiry = dateStr(120);
  const code = makeCode("slow-sign", expiry);
  const gate = deferred();
  let signerStarted = false;
  const app = await startRebind({
    devices: { "slow-sign": record(code, expiry, 4) },
    signNewCodeImpl: async (newDeviceId, exp) => {
      signerStarted = true;
      await gate.promise;
      return { ok: true, code: makeCode(newDeviceId, exp) };
    },
  });
  t.after(() => closeApp(app));
  const migration = postRebind(app.port, code, "slow-sign", "slow-sign-new");
  await waitUntil(() => signerStarted);
  const blocked = await postAi(app.port, code, "slow-sign");
  assert.equal(blocked.status, 409);
  assert.match(blocked.json.error, /正在换绑/);
  gate.resolve();
  assert.equal((await migration).status, 200);
});

test("T26: pre-rename persistence failure rolls migration back in memory and on disk", async (t) => {
  const expiry = dateStr(120);
  const code = makeCode("disk-old", expiry);
  let failRename = true;
  const fsAdapter = {
    ...fs,
    renameSync: (from, to) => {
      if (failRename) {
        failRename = false;
        throw new Error("injected rename failure");
      }
      return fs.renameSync(from, to);
    },
  };
  const app = await startRebind({
    devices: { "disk-old": record(code, expiry, 7) },
    fsAdapter,
  });
  t.after(() => closeApp(app));
  const before = fs.readFileSync(app.dbFile, "utf8");
  const res = await postRebind(app.port, code, "disk-old", "disk-new");
  assert.equal(res.status, 500);
  assert.equal(fs.readFileSync(app.dbFile, "utf8"), before);
  assert.equal(app.snapshot().devices["disk-old"].migrated_to, undefined);
  assert.equal(app.snapshot().devices["disk-new"], undefined);
});

test("production signer client authenticates to the loopback redeem endpoint", async (t) => {
  const expiry = dateStr(120);
  const oldCode = makeCode("redeem-old", expiry);
  let authorization = null;
  let received = null;
  const redeem = http.createServer((req, res) => {
    authorization = req.headers.authorization;
    const chunks = [];
    req.on("data", (chunk) => chunks.push(chunk));
    req.on("end", () => {
      received = JSON.parse(Buffer.concat(chunks).toString("utf8"));
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ code: makeCode(received.newDeviceId, received.expiry) }));
    });
  });
  await new Promise((resolve) => redeem.listen(0, "127.0.0.1", resolve));
  t.after(async () => {
    redeem.closeAllConnections?.();
    await new Promise((resolve) => redeem.close(resolve));
  });
  const app = await startRebind({
    devices: { "redeem-old": record(oldCode, expiry, 11) },
    signNewCodeImpl: null,
    rebindSecret: "runtime-test-secret",
    redeemEndpoint: `http://127.0.0.1:${redeem.address().port}/issue-migrated`,
  });
  t.after(() => closeApp(app));
  const res = await postRebind(app.port, oldCode, "redeem-old", "redeem-new");
  assert.equal(res.status, 200);
  assert.equal(authorization, "Bearer runtime-test-secret");
  assert.deepEqual(received, { newDeviceId: "redeem-new", expiry });
});

test("rebind audit logs contain fingerprints, never raw credentials", async (t) => {
  const expiry = dateStr(120);
  const code = makeCode("audit-old-device", expiry);
  const logs = [];
  const app = await startRebind({
    devices: { "audit-old-device": record(code, expiry, 2) },
    auditLogImpl: (line) => logs.push(line),
  });
  t.after(() => closeApp(app));
  assert.equal((await postRebind(app.port, code, "audit-old-device", "audit-new-device")).status, 200);
  assert.equal(logs.length, 1);
  assert.match(logs[0], /\[ZENCHE-AI\]\[REBIND\]/);
  assert.doesNotMatch(logs[0], /audit-old-device|audit-new-device/);
  assert.equal(logs[0].includes(code), false);
});

test("an audit sink failure cannot break a successful migration", async (t) => {
  const expiry = dateStr(120);
  const code = makeCode("audit-failure-old", expiry);
  const app = await startRebind({
    devices: { "audit-failure-old": record(code, expiry, 2) },
    auditLogImpl: () => { throw new Error("audit sink unavailable"); },
  });
  t.after(() => closeApp(app));
  const res = await postRebind(app.port, code, "audit-failure-old", "audit-failure-new");
  assert.equal(res.status, 200);
  assert.equal(app.snapshot().devices["audit-failure-new"].used, 2);
});
