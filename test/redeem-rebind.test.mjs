import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import crypto from "node:crypto";
import { createRedeemServer } from "../ai-server/redeem-rebind.mjs";

// Runtime-generated key pair: the repository must never contain a real key.
const { publicKey, privateKey } = crypto.generateKeyPairSync("rsa", { modulusLength: 2048 });
const PRIVATE_KEY_PEM = privateKey.export({ type: "pkcs1", format: "pem" });
const PUBLIC_KEY_PEM = publicKey.export({ type: "pkcs1", format: "pem" });

function dateStr(offsetDays = 0) {
  const d = new Date();
  d.setDate(d.getDate() + offsetDays);
  return `${d.getFullYear()}${String(d.getMonth() + 1).padStart(2, "0")}${String(d.getDate()).padStart(2, "0")}`;
}

function verifyCode(code, deviceId, expiry) {
  const parts = String(code).trim().split("-");
  if (parts.length < 4 || parts[0] !== "ZENCHE" || parts[1] !== "AI" || parts[parts.length - 1] !== expiry) return false;
  const sigPart = parts.slice(2, parts.length - 1).join("-");
  const payload = `${deviceId}:${expiry}:a1b2c3d4e5f6`;
  try {
    const verifier = crypto.createVerify("RSA-SHA256");
    verifier.update(payload, "utf8");
    return verifier.verify(PUBLIC_KEY_PEM, sigPart, "base64");
  } catch {
    return false;
  }
}

async function startServer(opts = {}) {
  const app = await createRedeemServer({
    secret: "test-shared-secret",
    privateKeyPem: PRIVATE_KEY_PEM,
    logImpl: () => {},
    ...opts,
  });
  return app;
}

async function stopServer(app) {
  app.server.closeAllConnections?.();
  await new Promise((resolve) => app.server.close(resolve));
}

function post(port, route, body, { method = "POST", authorization = "Bearer test-shared-secret", headers = {} } = {}) {
  return fetch(`http://127.0.0.1:${port}${route}`, {
    method,
    headers: {
      "Content-Type": "application/json",
      ...(authorization === null ? {} : { Authorization: authorization }),
      ...headers,
    },
    body: method === "POST" ? (typeof body === "string" ? body : JSON.stringify(body)) : undefined,
  });
}

test("successful issuance signs a code that verifies with the public key", async (t) => {
  const app = await startServer();
  t.after(() => stopServer(app));
  const expiry = dateStr(120);
  const res = await post(app.port, "/issue-migrated", { newDeviceId: "new-device-0001", expiry });
  assert.equal(res.status, 200);
  assert.ok(Number(res.headers.get("content-length")) > 0);
  const body = await res.json();
  assert.equal(typeof body.code, "string");
  assert.match(body.code, /^ZENCHE-AI-[A-Za-z0-9+/=]+-\d{8}$/);
  assert.ok(body.code.endsWith(`-${expiry}`));
  assert.equal(verifyCode(body.code, "new-device-0001", expiry), true);
  // The code must NOT verify for a different device or a different expiry.
  assert.equal(verifyCode(body.code, "other-device", expiry), false);
  assert.equal(verifyCode(body.code, "new-device-0001", dateStr(121)), false);
});

test("device id is trimmed before signing but expiry is kept exact", async (t) => {
  const app = await startServer();
  t.after(() => stopServer(app));
  const expiry = dateStr(30);
  const res = await post(app.port, "/issue-migrated", { newDeviceId: "  padded-device  ", expiry });
  assert.equal(res.status, 200);
  const body = await res.json();
  assert.equal(verifyCode(body.code, "padded-device", expiry), true);
  assert.equal(verifyCode(body.code, "  padded-device  ", expiry), false);
});

test("missing or forged Authorization is rejected with 401 and no code", async (t) => {
  const app = await startServer();
  t.after(() => stopServer(app));
  const body = { newDeviceId: "device-401", expiry: dateStr(60) };

  const missing = await post(app.port, "/issue-migrated", body, { authorization: null });
  assert.equal(missing.status, 401);
  const missingJson = await missing.json();
  assert.equal(missingJson.code, undefined);

  const forged = await post(app.port, "/issue-migrated", body, { authorization: "Bearer wrong-secret" });
  assert.equal(forged.status, 401);
  assert.equal((await forged.json()).code, undefined);

  const empty = await post(app.port, "/issue-migrated", body, { authorization: "Bearer " });
  assert.equal(empty.status, 401);

  const basic = await post(app.port, "/issue-migrated", body, { authorization: "Basic dXNlcjpwYXNz" });
  assert.equal(basic.status, 401);
});

test("invalid JSON, missing fields, and malformed fields return 400", async (t) => {
  const app = await startServer();
  t.after(() => stopServer(app));
  const expiry = dateStr(60);

  const badJson = await post(app.port, "/issue-migrated", "{not-json", {});
  assert.equal(badJson.status, 400);

  const emptyBody = await post(app.port, "/issue-migrated", "   ");
  assert.equal(emptyBody.status, 400);

  for (const bad of [
    {},
    { newDeviceId: "" },
    { newDeviceId: "   " },
    { newDeviceId: 12345 },
    { newDeviceId: null },
    { expiry },
    { newDeviceId: "dev", expiry: undefined },
  ]) {
    const res = await post(app.port, "/issue-migrated", bad);
    assert.equal(res.status, 400, JSON.stringify(bad));
  }

  // Device id hardening: separator/control characters are rejected.
  for (const badId of ["a:b:c", "dev\u0000ice", "dev\u0007", "x\n y"]) {
    const res = await post(app.port, "/issue-migrated", { newDeviceId: badId, expiry });
    assert.equal(res.status, 400, JSON.stringify(badId));
  }
});

test("invalid or expired yyyyMMdd expiry returns 400", async (t) => {
  const app = await startServer();
  t.after(() => stopServer(app));

  for (const badDate of [
    "",
    "2026-08-04",
    "2026080",
    "20260231", // impossible date must NOT roll over
    "20261301",
    "00000000",
    "2026084",
    dateStr(-1), // yesterday: expired
  ]) {
    const res = await post(app.port, "/issue-migrated", { newDeviceId: "date-device", expiry: badDate });
    assert.equal(res.status, 400, JSON.stringify(badDate));
  }

  // Today is still valid for the whole day.
  const today = await post(app.port, "/issue-migrated", { newDeviceId: "date-device", expiry: dateStr(0) });
  assert.equal(today.status, 200);
});

test("an oversized request body is rejected with 413", async (t) => {
  const app = await startServer();
  t.after(() => stopServer(app));
  const big = { newDeviceId: "big-" + "x".repeat(20 * 1024), expiry: dateStr(60) };
  const res = await post(app.port, "/issue-migrated", big);
  assert.equal(res.status, 413);
  assert.equal((await res.json()).code, undefined);
});

test("non-POST methods and unknown paths return 404", async (t) => {
  const app = await startServer();
  t.after(() => stopServer(app));
  assert.equal((await post(app.port, "/issue-migrated", {}, { method: "GET" })).status, 404);
  assert.equal((await post(app.port, "/issue-migrated", {}, { method: "PUT" })).status, 404);
  assert.equal((await post(app.port, "/unknown", { newDeviceId: "x", expiry: dateStr(60) })).status, 404);
  assert.equal((await post(app.port, "/issue-migrated-extra", { newDeviceId: "x", expiry: dateStr(60) })).status, 404);
});

test("missing secret or private key fails closed before listening", async (t) => {
  assert.throws(() => createRedeemServer({ secret: "", privateKeyPem: PRIVATE_KEY_PEM }), /ZENCHE_REBIND_SECRET/);
  assert.throws(() => createRedeemServer({ secret: "s", privateKeyPem: null }), /private key/);
  assert.throws(() => createRedeemServer({ secret: "s", privateKeyPem: "not-a-key" }), /invalid or unusable/);
  const missingFile = path.join(os.tmpdir(), `zenche-redeem-missing-${Date.now()}.pem`);
  assert.throws(() => createRedeemServer({ secret: "s", privateKeyFile: missingFile }), (err) => err.code === "ENOENT");
});

test("the private key is read from an environment file path", async (t) => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "zenche-redeem-key-"));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const keyFile = path.join(dir, "zenche_ai_private.pem");
  fs.writeFileSync(keyFile, PRIVATE_KEY_PEM, { mode: 0o600 });
  const app = await startServer({ privateKeyPem: null, privateKeyFile: keyFile });
  t.after(() => stopServer(app));
  const expiry = dateStr(90);
  const res = await post(app.port, "/issue-migrated", { newDeviceId: "file-key-device", expiry });
  assert.equal(res.status, 200);
  assert.equal(verifyCode((await res.json()).code, "file-key-device", expiry), true);
});

test("the default host is loopback-only", async (t) => {
  const app = await startServer({ port: 0 }); // no host override => factory default
  t.after(() => stopServer(app));
  assert.ok(app.host === "127.0.0.1" || app.host === "::1", `loopback expected, got ${app.host}`);
});

test("a listen failure rejects instead of leaving startup pending", async (t) => {
  const first = await startServer();
  t.after(() => stopServer(first));
  await assert.rejects(
    createRedeemServer({
      secret: "test-shared-secret",
      privateKeyPem: PRIVATE_KEY_PEM,
      host: first.host,
      port: first.port,
      logImpl: () => {},
    }),
    (error) => error?.code === "EADDRINUSE",
  );
});

test("audit logs carry fingerprints only, never secrets", async (t) => {
  const logs = [];
  const app = await startServer({ logImpl: (line) => logs.push(line) });
  t.after(() => stopServer(app));
  const expiry = dateStr(45);
  await post(app.port, "/issue-migrated", { newDeviceId: "log-device-0001", expiry });
  await post(app.port, "/issue-migrated", { newDeviceId: "log-device-0001", expiry }, { authorization: "Bearer nope" });
  await post(app.port, "/issue-migrated", { newDeviceId: "log-device-0001", expiry: dateStr(-1) });

  assert.ok(logs.length >= 3);
  for (const line of logs) {
    assert.match(line, /^\[ZENCHE-REDEEM\] device=/);
    assert.equal(line.includes("test-shared-secret"), false, "secret leaked into logs");
    assert.equal(line.includes(PRIVATE_KEY_PEM), false, "private key leaked into logs");
    assert.equal(line.includes("log-device-0001"), false, "raw device id leaked into logs");
    assert.equal(line.includes(expiry), false, "expiry leaked into logs");
    assert.equal(line.includes("ZENCHE-AI-"), false, "issued code leaked into logs");
  }
  // Success and failure outcomes are both observable.
  assert.ok(logs.some((line) => /result=ok/.test(line)), "expected an ok audit line");
  assert.ok(logs.some((line) => /result=unauthorized/.test(line)), "expected an unauthorized audit line");
});

test("integration: an ai-server style signer client can consume this endpoint", async (t) => {
  const app = await startServer();
  t.after(() => stopServer(app));
  const expiry = dateStr(75);
  const body = JSON.stringify({ newDeviceId: "client-consumer-device", expiry });
  const res = await fetch(`http://127.0.0.1:${app.port}/issue-migrated`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Content-Length": Buffer.byteLength(body),
      Authorization: "Bearer test-shared-secret",
      Accept: "application/json",
    },
    body,
  });
  assert.equal(res.status, 200);
  const json = await res.json();
  assert.equal(verifyCode(json.code, "client-consumer-device", expiry), true);
});
