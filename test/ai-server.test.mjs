// S5: in-repo secret-free AI service module tests (ported from the verified
// 16/16 skeleton, RESEARCH/ZENCHE_AI_SERVER_TESTABILITY.md). The RSA test
// keypair is generated at runtime — no key material is committed. Scope:
// createApp factory, loopback-only default, strict yyyyMMdd, expiry valid
// for the whole expiry day, corrupt DB fail-loud, consume persistence and
// upstream rollback. NO rebind endpoint, NO production keys, NO deploy.
import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import { readFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import crypto from "node:crypto";
import http from "node:http";
import { createApp } from "../ai-server/app.mjs";

const { publicKey, privateKey } = crypto.generateKeyPairSync("rsa", { modulusLength: 2048 });
const TEST_PUBLIC_KEY = publicKey.export({ type: "pkcs1", format: "pem" });

function makeCode(deviceId, expiry = "20261231") {
  const payload = `${deviceId}:${expiry}:a1b2c3d4e5f6`;
  const signer = crypto.createSign("RSA-SHA256");
  signer.update(payload, "utf8");
  return `ZENCHE-AI-${signer.sign(privateKey, "base64")}-${expiry}`;
}

function tmpDir() { return fs.mkdtempSync(path.join(os.tmpdir(), "zenche-ai-server-")); }

async function start(opts = {}) {
  const dir = tmpDir();
  const app = await createApp({
    publicKeyPem: TEST_PUBLIC_KEY,
    dbDir: path.join(dir, "data"),
    // Explicit mock upstream: tests exercising expiry/counting must not depend
    // on the real (unreachable-by-default) chain. Tests that need the real
    // zero-dependency chain call createApp directly WITHOUT drawImageImpl.
    drawImageImpl: async () => "TEST_MOCK",
    ...opts,
  });
  return { ...app, cleanupDir: dir };
}

async function post(port, body) {
  const res = await fetch(`http://127.0.0.1:${port}/v1/ai`, {
    method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body),
  });
  return { status: res.status, json: await res.json(), remaining: res.headers.get("X-ZENCHE-Remaining") };
}

// fetch() keeps keep-alive sockets open, which would block server.close().
// Force-close all connections so servers always shut down promptly in tests.
async function closeServer(server) {
  server.closeAllConnections?.();
  await new Promise((resolve) => server.close(resolve));
}

function dateStr(offsetDays = 0) {
  const d = new Date();
  d.setDate(d.getDate() + offsetDays);
  return `${d.getFullYear()}${String(d.getMonth() + 1).padStart(2, "0")}${String(d.getDate()).padStart(2, "0")}`;
}

// ---------- isolation, routing, input validation ----------

test("starts on random port with temp DB, no production files touched", async (t) => {
  const app = await start();
  t.after(async () => { await closeServer(app.server); fs.rmSync(app.cleanupDir, { recursive: true, force: true }); });
  assert.ok(app.port > 0);
  assert.ok(app.dbFile.endsWith(path.join("data", "devices.json")));
  assert.ok(app.snapshot().devices, "empty devices map");
});
test("binds only 127.0.0.1 by default", async (t) => {
  const app = await start();
  t.after(async () => { await closeServer(app.server); fs.rmSync(app.cleanupDir, { recursive: true, force: true }); });
  assert.equal(app.host, "127.0.0.1");
});

test("404 for non-POST /v1/ai", async (t) => {
  const app = await start();
  t.after(async () => { await closeServer(app.server); fs.rmSync(app.cleanupDir, { recursive: true, force: true }); });
  const res = await fetch(`http://127.0.0.1:${app.port}/v1/ai`, { method: "GET" });
  assert.equal(res.status, 404);
});

test("400 when required fields missing", async (t) => {
  const app = await start();
  t.after(async () => { await closeServer(app.server); fs.rmSync(app.cleanupDir, { recursive: true, force: true }); });
  const res = await post(app.port, { activationCode: "x", deviceId: "d" }); // no prompt
  assert.equal(res.status, 400);
  assert.match(res.json.error, /缺少/);
});

test("403 for malformed activation code", async (t) => {
  const app = await start();
  t.after(async () => { await closeServer(app.server); fs.rmSync(app.cleanupDir, { recursive: true, force: true }); });
  const res = await post(app.port, { activationCode: "NOT-A-CODE", deviceId: "dev-1", prompt: "hi" });
  assert.equal(res.status, 403);
  assert.match(res.json.error, /格式错误/);
});

// ---------- expiry semantics ----------

test("code expiring today is valid for the whole day", async (t) => {
  const app = await start();
  t.after(async () => { await closeServer(app.server); fs.rmSync(app.cleanupDir, { recursive: true, force: true }); });
  const res = await post(app.port, { activationCode: makeCode("dev-today", dateStr(0)), deviceId: "dev-today", prompt: "hi" });
  assert.equal(res.status, 200);
});

test("yesterday-expired code is rejected", async (t) => {
  const app = await start();
  t.after(async () => { await closeServer(app.server); fs.rmSync(app.cleanupDir, { recursive: true, force: true }); });
  const res = await post(app.port, { activationCode: makeCode("dev-yest", dateStr(-1)), deviceId: "dev-yest", prompt: "hi" });
  assert.equal(res.status, 403);
  assert.match(res.json.error, /过期/);
});

test("impossible date 20260231 is rejected (no JS Date rollover)", async (t) => {
  const app = await start();
  t.after(async () => { await closeServer(app.server); fs.rmSync(app.cleanupDir, { recursive: true, force: true }); });
  const res = await post(app.port, { activationCode: makeCode("dev-bad", "20260231"), deviceId: "dev-bad", prompt: "hi" });
  assert.equal(res.status, 403);
  assert.match(res.json.error, /无效/);
});

test("expired code rejected", async (t) => {
  const app = await start();
  t.after(async () => { await closeServer(app.server); fs.rmSync(app.cleanupDir, { recursive: true, force: true }); });
  const res = await post(app.port, { activationCode: makeCode("dev-3", "20200101"), deviceId: "dev-3", prompt: "hi" });
  assert.equal(res.status, 403);
  assert.match(res.json.error, /过期/);
});

// ---------- signature binding ----------

test("403 when code signed for a different device", async (t) => {
  const app = await start();
  t.after(async () => { await closeServer(app.server); fs.rmSync(app.cleanupDir, { recursive: true, force: true }); });
  const code = makeCode("dev-A");
  const res = await post(app.port, { activationCode: code, deviceId: "dev-B", prompt: "hi" });
  assert.equal(res.status, 403);
  assert.match(res.json.error, /不匹配/);
});

// ---------- counting baseline (consume + persistence + rollback) ----------

test("valid code consumes count, persists to temp DB, second request increments", async (t) => {
  const app = await start();
  t.after(async () => { await closeServer(app.server); fs.rmSync(app.cleanupDir, { recursive: true, force: true }); });
  const code = makeCode("dev-1");
  const r1 = await post(app.port, { activationCode: code, deviceId: "dev-1", prompt: "hello" });
  assert.equal(r1.status, 200);
  assert.equal(r1.remaining, "99");
  const onDisk = JSON.parse(fs.readFileSync(app.dbFile, "utf8"));
  assert.equal(onDisk["dev-1"].used, 1);
  const r2 = await post(app.port, { activationCode: code, deviceId: "dev-1", prompt: "again" });
  assert.equal(r2.remaining, "98");
  assert.equal(app.snapshot().devices["dev-1"].used, 2);
});

test("max usage enforcement (MAX_USAGE=2)", async (t) => {
  const app = await start({ maxUsage: 2 });
  t.after(async () => { await closeServer(app.server); fs.rmSync(app.cleanupDir, { recursive: true, force: true }); });
  const code = makeCode("dev-2");
  assert.equal((await post(app.port, { activationCode: code, deviceId: "dev-2", prompt: "a" })).status, 200);
  assert.equal((await post(app.port, { activationCode: code, deviceId: "dev-2", prompt: "b" })).status, 200);
  const r3 = await post(app.port, { activationCode: code, deviceId: "dev-2", prompt: "c" });
  assert.equal(r3.status, 403);
  assert.match(r3.json.error, /次数已用完/);
});

test("upstream success returns image and keeps the consumed count", async (t) => {
  const app = await start({ drawImageImpl: async () => "BASE64_OK" });
  t.after(async () => { await closeServer(app.server); fs.rmSync(app.cleanupDir, { recursive: true, force: true }); });
  const res = await post(app.port, { activationCode: makeCode("dev-ok"), deviceId: "dev-ok", prompt: "hi" });
  assert.equal(res.status, 200);
  assert.equal(res.json.data[0].b64_json, "BASE64_OK");
  assert.equal(res.remaining, "99");
  assert.equal(app.snapshot().devices["dev-ok"].used, 1);
});

test("upstream failure rolls back the consumed count", async (t) => {
  const app = await start({ drawImageImpl: async () => { throw new Error("upstream down"); } });
  t.after(async () => { await closeServer(app.server); fs.rmSync(app.cleanupDir, { recursive: true, force: true }); });
  const res = await post(app.port, { activationCode: makeCode("dev-fail"), deviceId: "dev-fail", prompt: "hi" });
  assert.equal(res.status, 502);
  assert.match(res.json.error, /暂时不可用/);
  assert.equal(app.snapshot().devices["dev-fail"].used, 0, "count refunded after upstream failure");
});

test("concurrent one-success one-failure: final count equals successes only", async (t) => {
  let calls = 0;
  const app = await start({
    maxUsage: 5,
    drawImageImpl: async () => {
      calls += 1;
      if (calls === 1) throw new Error("upstream down");
      return "BASE64_OK";
    },
  });
  t.after(async () => { await closeServer(app.server); fs.rmSync(app.cleanupDir, { recursive: true, force: true }); });
  const code = makeCode("dev-conc");
  const [r1, r2] = await Promise.all([
    post(app.port, { activationCode: code, deviceId: "dev-conc", prompt: "a" }),
    post(app.port, { activationCode: code, deviceId: "dev-conc", prompt: "b" }),
  ]);
  assert.deepEqual([r1.status, r2.status].sort(), [200, 502]);
  assert.equal(app.snapshot().devices["dev-conc"].used, 1, "failed request refunded, success kept");
});

test("corrupt devices.json fails loudly instead of silently resetting", async (t) => {
  const dir = tmpDir();
  const dbDir = path.join(dir, "data");
  fs.mkdirSync(dbDir, { recursive: true });
  fs.writeFileSync(path.join(dbDir, "devices.json"), "{not json");
  assert.throws(
    () => createApp({ publicKeyPem: TEST_PUBLIC_KEY, dbDir }),
    /corrupt devices\.json/
  );
  fs.rmSync(dir, { recursive: true, force: true });
});

// ---------- bounded request body (R4) ----------

test("oversized body is rejected with 413 and consumes nothing", async (t) => {
  const app = await start({ maxBodyBytes: 1024 });
  t.after(async () => { await closeServer(app.server); fs.rmSync(app.cleanupDir, { recursive: true, force: true }); });
  const res = await post(app.port, {
    activationCode: makeCode("dev-big"),
    deviceId: "dev-big",
    prompt: "x".repeat(4096),
  });
  assert.equal(res.status, 413);
  assert.match(res.json.error, /过大/);
  assert.equal(app.snapshot().devices["dev-big"], undefined, "413 must not consume the activation");
});

// ---------- real zero-dependency upstream chain (R3) ----------

test("real upstream chain: generate → async poll → download base64 (no mock)", async (t) => {
  const png = Buffer.from("fake-png-bytes-1234");
  let pollCount = 0;
  let seenBody = null;
  const upstream = http.createServer((req, res) => {
    if (req.method === "POST" && req.url.startsWith("/v1/api/generate")) {
      let raw = "";
      req.on("data", (c) => (raw += c));
      req.on("end", () => {
        seenBody = JSON.parse(raw);
        res.writeHead(200, { "Content-Type": "application/json" });
        res.end(`data: ${JSON.stringify({ id: "job-1", status: "running" })}\n`);
      });
      return;
    }
    if (req.method === "GET" && req.url.startsWith("/v1/api/result")) {
      pollCount += 1;
      res.writeHead(200, { "Content-Type": "application/json" });
      if (pollCount === 1) {
        res.end(JSON.stringify({ id: "job-1", status: "running" }));
      } else {
        res.end(JSON.stringify({
          id: "job-1",
          status: "succeeded",
          results: [{ url: `http://127.0.0.1:${upstream.address().port}/img.png` }],
        }));
      }
      return;
    }
    if (req.method === "GET" && req.url.startsWith("/img.png")) {
      res.writeHead(200, { "Content-Type": "image/png" });
      res.end(png);
      return;
    }
    res.writeHead(404);
    res.end();
  });
  await new Promise((r) => upstream.listen(0, "127.0.0.1", r));
  t.after(async () => { await closeServer(upstream); });

  const dir = tmpDir();
  const app = await createApp({
    publicKeyPem: TEST_PUBLIC_KEY,
    dbDir: path.join(dir, "data"),
    endpoint: `http://127.0.0.1:${upstream.address().port}/v1/api/generate`,
    model: "nano-banana-fast",
    replyType: "async",
  });
  t.after(async () => { await closeServer(app.server); fs.rmSync(dir, { recursive: true, force: true }); });

  const res = await post(app.port, {
    activationCode: makeCode("dev-real"),
    deviceId: "dev-real",
    prompt: "hi",
    size: "1792x1024",
  });
  assert.equal(res.status, 200);
  assert.equal(res.json.data[0].b64_json, png.toString("base64"));
  assert.equal(res.remaining, "99");
  assert.equal(app.snapshot().devices["dev-real"].used, 1);
  assert.equal(seenBody.model, "nano-banana-fast");
  assert.equal(seenBody.replyType, "async");
  assert.equal(seenBody.aspectRatio, "16:9", "1792x1024 must map to the 16:9 aspect ratio");
  assert.deepEqual(seenBody.images, [], "no reference image → empty images array");
  assert.ok(pollCount >= 2, "async reply must be polled until succeeded");
});

test("invalid reference image is rejected 400 BEFORE consume (no device record, no disk write)", async (t) => {
  const dir = tmpDir();
  const app = await createApp({
    publicKeyPem: TEST_PUBLIC_KEY,
    dbDir: path.join(dir, "data"),
  });
  t.after(async () => { await closeServer(app.server); fs.rmSync(dir, { recursive: true, force: true }); });
  const res = await post(app.port, {
    activationCode: makeCode("dev-badimg"),
    deviceId: "dev-badimg",
    prompt: "hi",
    image: "not-a-valid-reference",
  });
  assert.equal(res.status, 400);
  assert.match(res.json.error, /参考图/);
  // R5.4: client error must not create a device record nor touch the disk.
  assert.equal(app.snapshot().devices["dev-badimg"], undefined, "no device record may be created");
  assert.equal(fs.existsSync(app.dbFile), false, "no disk write may happen for a 400");
});

test("valid data-URL reference image passes validation and is forwarded to the upstream draw", async (t) => {
  let seenImage = null;
  const app = await start({ drawImageImpl: async (apiKey, prompt, size, image) => { seenImage = { prompt, size, image }; return "BASE64_OK"; } });
  t.after(async () => { await closeServer(app.server); fs.rmSync(app.cleanupDir, { recursive: true, force: true }); });
  const dataUrl = "data:image/jpeg;base64,/9j/4AAQSkZJRg==";
  const res = await post(app.port, {
    activationCode: makeCode("dev-refok"),
    deviceId: "dev-refok",
    prompt: "hi",
    size: "1024x1024",
    image: dataUrl,
  });
  assert.equal(res.status, 200);
  assert.equal(seenImage.prompt, "hi");
  assert.equal(seenImage.size, "1024x1024");
  assert.equal(seenImage.image, dataUrl, "validated reference must reach the draw layer");
  assert.equal(app.snapshot().devices["dev-refok"].used, 1);
});

// ---------- R5.2: UTF-8 body accumulation must be Buffer-based ----------

test("multibyte UTF-8 body split across writes is reassembled intact (no raw += chunk)", async (t) => {
  let seenPrompt = null;
  const app = await start({ drawImageImpl: async (apiKey, prompt) => { seenPrompt = prompt; return "BASE64_OK"; } });
  t.after(async () => { await closeServer(app.server); fs.rmSync(app.cleanupDir, { recursive: true, force: true }); });
  const prompt = "中文提示词 猫 🐝 测试";
  const body = JSON.stringify({ activationCode: makeCode("dev-utf"), deviceId: "dev-utf", prompt });
  const buf = Buffer.from(body, "utf8");
  // Split INSIDE the 3-byte UTF-8 encoding of 猫: 1 byte into the char.
  const byteBefore = Buffer.byteLength(body.slice(0, body.indexOf("猫")));
  const splitAt = byteBefore + 1;
  assert.ok(splitAt > 0 && splitAt < buf.length);
  const res = await new Promise((resolve, reject) => {
    const req = http.request(
      { host: "127.0.0.1", port: app.port, path: "/v1/ai", method: "POST", headers: { "Content-Type": "application/json", "Content-Length": buf.length } },
      (r) => {
        let data = "";
        r.on("data", (c) => (data += c));
        r.on("end", () => resolve({ status: r.statusCode, json: JSON.parse(data) }));
      },
    );
    req.on("error", reject);
    req.on("socket", (s) => s.setNoDelay(true));
    req.write(buf.subarray(0, splitAt));
    setTimeout(() => { req.write(buf.subarray(splitAt)); req.end(); }, 60);
  });
  assert.equal(res.status, 200);
  assert.equal(seenPrompt, prompt, "prompt must be decoded exactly once from the accumulated Buffer");
  assert.equal(app.snapshot().devices["dev-utf"].used, 1);
});

test("body accumulation is Buffer-based and decodes UTF-8 exactly once", async () => {
  const source = await readFile("ai-server/app.mjs", "utf8");
  assert.doesNotMatch(source, /raw \+= chunk/, "raw string concatenation must be gone (R5.2)");
  assert.match(source, /Buffer\.concat\(chunks\)\.toString\("utf8"\)/, "one Buffer concat + one UTF-8 decode");
});

// ---------- R5.3: bounded outbound responses ----------

function startUpstreamStub({ generate, result, image, onAbort }) {
  const server = http.createServer((req, res) => {
    // The client may destroy a bounded response mid-stream (R5.3); the stub
    // must not crash on the resulting EPIPE/socket error.
    res.on("error", () => {});
    if (req.method === "POST" && req.url.startsWith("/v1/api/generate")) {
      req.resume();
      req.on("end", () => generate(res));
      return;
    }
    if (req.method === "GET" && req.url.startsWith("/v1/api/result")) {
      result(res);
      return;
    }
    if (req.method === "GET" && req.url.startsWith("/img")) {
      image(res);
      return;
    }
    res.writeHead(404); res.end();
  });
  server.on("clientError", (_err, socket) => { socket.destroy(); });
  return new Promise((resolve) => server.listen(0, "127.0.0.1", () => resolve(server)));
}

test("oversized upstream generate JSON → 502, count refunded (used=0)", async (t) => {
  const stub = await startUpstreamStub({
    generate: (res) => {
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ id: "x", status: "running", pad: "y".repeat(4096) }));
    },
    result: (res) => { res.writeHead(200, { "Content-Type": "application/json" }); res.end(JSON.stringify({ id: "x", status: "succeeded" })); },
    image: (res) => { res.writeHead(200); res.end("png"); },
  });
  t.after(async () => { await closeServer(stub); });
  const dir = tmpDir();
  const app = await createApp({
    publicKeyPem: TEST_PUBLIC_KEY,
    dbDir: path.join(dir, "data"),
    endpoint: `http://127.0.0.1:${stub.address().port}/v1/api/generate`,
    maxUpstreamJsonBytes: 1024, // tiny injectable limit
  });
  t.after(async () => { await closeServer(app.server); fs.rmSync(dir, { recursive: true, force: true }); });
  const res = await post(app.port, { activationCode: makeCode("dev-over1"), deviceId: "dev-over1", prompt: "hi" });
  assert.equal(res.status, 502);
  assert.equal(app.snapshot().devices["dev-over1"].used, 0, "consumed count must be rolled back");
});

test("oversized upstream result JSON (poll) → 502, count refunded (used=0)", async (t) => {
  const stub = await startUpstreamStub({
    generate: (res) => { res.writeHead(200, { "Content-Type": "application/json" }); res.end(`data: ${JSON.stringify({ id: "job1", status: "running" })}\n`); },
    result: (res) => { res.writeHead(200, { "Content-Type": "application/json" }); res.end(JSON.stringify({ id: "job1", status: "succeeded", pad: "z".repeat(8192) })); },
    image: (res) => { res.writeHead(200); res.end("png"); },
  });
  t.after(async () => { await closeServer(stub); });
  const dir = tmpDir();
  const app = await createApp({
    publicKeyPem: TEST_PUBLIC_KEY,
    dbDir: path.join(dir, "data"),
    endpoint: `http://127.0.0.1:${stub.address().port}/v1/api/generate`,
    maxUpstreamJsonBytes: 1024,
  });
  t.after(async () => { await closeServer(app.server); fs.rmSync(dir, { recursive: true, force: true }); });
  const res = await post(app.port, { activationCode: makeCode("dev-over2"), deviceId: "dev-over2", prompt: "hi" });
  assert.equal(res.status, 502);
  assert.equal(app.snapshot().devices["dev-over2"].used, 0, "consumed count must be rolled back");
});

test("oversized image download → 502, count refunded (used=0)", async (t) => {
  const stub = await startUpstreamStub({
    generate: (res) => { res.writeHead(200, { "Content-Type": "application/json" }); res.end(`data: ${JSON.stringify({ id: "job2", status: "running" })}\n`); },
    result: (res) => { res.writeHead(200, { "Content-Type": "application/json" }); res.end(JSON.stringify({ id: "job2", status: "succeeded", results: [{ url: `http://127.0.0.1:${stub.address().port}/img` }] })); },
    image: (res) => { res.writeHead(200, { "Content-Type": "image/png" }); res.end("p".repeat(4096)); },
  });
  t.after(async () => { await closeServer(stub); });
  const dir = tmpDir();
  const app = await createApp({
    publicKeyPem: TEST_PUBLIC_KEY,
    dbDir: path.join(dir, "data"),
    endpoint: `http://127.0.0.1:${stub.address().port}/v1/api/generate`,
    maxImageBytes: 1024, // tiny injectable image limit
  });
  t.after(async () => { await closeServer(app.server); fs.rmSync(dir, { recursive: true, force: true }); });
  const res = await post(app.port, { activationCode: makeCode("dev-over3"), deviceId: "dev-over3", prompt: "hi" });
  assert.equal(res.status, 502);
  assert.equal(app.snapshot().devices["dev-over3"].used, 0, "consumed count must be rolled back");
});

test("chunked upstream response without Content-Length is stream-bounded → 502, count refunded", async (t) => {
  // R5.3 streamed cap: the stub sends NO Content-Length (Transfer-Encoding:
  // chunked) and streams well past maxUpstreamJsonBytes. The client must stop
  // at the accumulated cap, destroy the response, and roll the count back.
  const stub = await startUpstreamStub({
    generate: (res) => {
      res.writeHead(200, { "Content-Type": "application/json", "Transfer-Encoding": "chunked" });
      res.write(`data: ${JSON.stringify({ id: "jobC", status: "running" })}\n`);
      const big = "y".repeat(2048);
      res.write(big);
      res.write(big);
      res.end();
    },
    result: (res) => { res.writeHead(200); res.end("{}"); },
    image: (res) => { res.writeHead(200); res.end("png"); },
  });
  t.after(async () => { await closeServer(stub); });
  const dir = tmpDir();
  const app = await createApp({
    publicKeyPem: TEST_PUBLIC_KEY,
    dbDir: path.join(dir, "data"),
    endpoint: `http://127.0.0.1:${stub.address().port}/v1/api/generate`,
    maxUpstreamJsonBytes: 1024, // chunked stream crosses this with NO Content-Length
  });
  t.after(async () => { await closeServer(app.server); fs.rmSync(dir, { recursive: true, force: true }); });
  const res = await post(app.port, { activationCode: makeCode("dev-chunked"), deviceId: "dev-chunked", prompt: "hi" });
  assert.equal(res.status, 502, "streamed over-limit without Content-Length must still fail closed");
  assert.equal(app.snapshot().devices["dev-chunked"].used, 0, "consumed count must be rolled back after chunked over-limit");
});

test("outbound transport selection uses URL protocol, not port===443", async () => {
  const source = await readFile("ai-server/app.mjs", "utf8");
  assert.doesNotMatch(source, /port === 443 \? https : http/, "transport must not key off port===443");
  assert.match(source, /protocol === "https:" \? https : http/, "transport must key off URL protocol");
});

test("https:// endpoint (non-443 port) selects TLS transport → 502 on plain-HTTP stub", async (t) => {
  // Old code would pick http for any port!==443 and succeed; protocol-based
  // selection must attempt TLS against this plain HTTP stub and fail.
  const stub = await startUpstreamStub({
    generate: (res) => { res.writeHead(200, { "Content-Type": "application/json" }); res.end(JSON.stringify({ id: "x", status: "succeeded", results: [{ url: "http://x/img" }] })); },
    result: (res) => { res.writeHead(200); res.end("{}"); },
    image: (res) => { res.writeHead(200); res.end("png"); },
  });
  t.after(async () => { await closeServer(stub); });
  const dir = tmpDir();
  const app = await createApp({
    publicKeyPem: TEST_PUBLIC_KEY,
    dbDir: path.join(dir, "data"),
    endpoint: `https://127.0.0.1:${stub.address().port}/v1/api/generate`, // https scheme, non-443 port
  });
  t.after(async () => { await closeServer(app.server); fs.rmSync(dir, { recursive: true, force: true }); });
  const res = await post(app.port, { activationCode: makeCode("dev-tls"), deviceId: "dev-tls", prompt: "hi" });
  assert.equal(res.status, 502, "TLS handshake against a plain HTTP server must fail closed");
  assert.equal(app.snapshot().devices["dev-tls"].used, 0, "count must be refunded after transport failure");
});

// ---------- R5.5: CLI default loopback ----------

test("CLI binds loopback by default; public bind requires explicit ZENCHE_AI_HOST", async () => {
  const source = await readFile("ai-server/app.mjs", "utf8");
  assert.match(source, /ZENCHE_AI_HOST \|\| "127\.0\.0\.1"/, "CLI must default to loopback");
  assert.doesNotMatch(source, /ZENCHE_AI_HOST \|\| "0\.0\.0\.0"/, "0.0.0.0 must never be the implicit default");
});

// ---------- R6: shared durable write (persistDurably + recoverPersistFailure) ----------
// Spec: PLANS/ZENCHE_DEVICE_REBIND_DESIGN.md §1.4.1 (fifth round). Fault
// injection via an fs adapter: T33-T41 assert commitState/reason tagging, the
// pre-rename / renamed-unconfirmed / durable recovery matrix, and that
// storage-unhealthy never releases to a writable state.

function faultAdapter(dbDir, dbFile, hooks = {}) {
  const real = fs;
  const state = { fileFd: null, dirFd: null, writes: 0, hits: new Map() };
  const once = (name) => {
    const n = (state.hits.get(name) || 0) + 1;
    state.hits.set(name, n);
    return n === 1; // throw only on the FIRST occurrence (rollback path succeeds)
  };
  const adapter = {
    ...real,
    openSync: (p, flags, mode) => {
      // Fault hooks must fire BEFORE the real open so a tmp-open/dir-open
      // fault is genuine (no fd is leaked by pretending a successful open failed).
      if (hooks.onOpen && hooks.onOpen(p, flags, mode, null, state, once)) throw hooks.error("open", p);
      const fd = real.openSync(p, flags, mode);
      if (p === dbFile + ".tmp") state.fileFd = fd;
      if (p === dbDir) state.dirFd = fd;
      return fd;
    },
    fchmodSync: (fd, mode) => {
      if (hooks.onFchmod && hooks.onFchmod(fd, mode, state, once)) throw hooks.error("fchmod", fd);
      return real.fchmodSync(fd, mode);
    },
    writeFileSync: (fd, data) => {
      state.writes += 1;
      if (hooks.onWrite && hooks.onWrite(fd, data, state, once)) throw hooks.error("write", fd);
      return real.writeFileSync(fd, data);
    },
    fsyncSync: (fd) => {
      if (hooks.onFsync && hooks.onFsync(fd, state, once)) throw hooks.error("fsync", fd);
      return real.fsyncSync(fd);
    },
    closeSync: (fd) => {
      if (hooks.onClose && hooks.onClose(fd, state, once)) throw hooks.error("close", fd);
      const r = real.closeSync(fd);
      // Clear tracked fd slots on close: macOS/Linux reuse fd numbers, so a
      // later tmp fd may numerically equal the old dir fd and would otherwise
      // trip fd-matched hooks (e.g. a rollback's file-fsync seen as dir-fsync).
      if (fd === state.fileFd) state.fileFd = null;
      if (fd === state.dirFd) state.dirFd = null;
      return r;
    },
    renameSync: (a, b) => {
      state.writes += 1;
      if (hooks.onRename && hooks.onRename(a, b, state, once)) throw hooks.error("rename", a);
      return real.renameSync(a, b);
    },
  };
  return { adapter, state };
}

async function startFaulty({ hooks, onUnrecoverableStorage, opts = {} }) {
  const dir = tmpDir();
  const dbDir = path.join(dir, "data");
  fs.mkdirSync(dbDir, { recursive: true });
  const dbFile = path.join(dbDir, "devices.json");
  const { adapter, state } = faultAdapter(dbDir, dbFile, hooks);
  const app = await createApp({
    publicKeyPem: TEST_PUBLIC_KEY,
    dbDir,
    fsAdapter: adapter,
    // Fault-injection instances exercise the durable-write state machine only;
    // the upstream chain must not participate (default endpoint is unreachable).
    drawImageImpl: async () => "TEST_MOCK",
    onUnrecoverableStorage: onUnrecoverableStorage || (() => {}),
    ...opts,
  });
  return { ...app, state, cleanupDir: dir };
}

test("R6-T38: tmp open failure → pre-rename/tmp-open, 500, memory restored, disk untouched", async (t) => {
  const app = await startFaulty({
    hooks: { onOpen: (p) => p.endsWith(".tmp"), error: () => new Error("tmp open denied") },
  });
  t.after(async () => { await closeServer(app.server); fs.rmSync(app.cleanupDir, { recursive: true, force: true }); });
  const res = await post(app.port, { activationCode: makeCode("dev-t38"), deviceId: "dev-t38", prompt: "hi" });
  assert.equal(res.status, 500);
  assert.equal(app.snapshot().devices["dev-t38"], undefined, "memory must be rolled back");
  assert.equal(fs.existsSync(app.dbFile), false, "disk must be untouched (old state)");
});

test("R6-T33: file fsync failure → pre-rename/write-or-fsync, 500, memory restored", async (t) => {
  const app = await startFaulty({
    hooks: { onFsync: (fd, state) => fd === state.fileFd, error: () => new Error("disk fsync failed") },
  });
  t.after(async () => { await closeServer(app.server); fs.rmSync(app.cleanupDir, { recursive: true, force: true }); });
  const res = await post(app.port, { activationCode: makeCode("dev-t33"), deviceId: "dev-t33", prompt: "hi" });
  assert.equal(res.status, 500);
  assert.equal(app.snapshot().devices["dev-t33"], undefined, "memory must be rolled back");
  assert.equal(fs.existsSync(app.dbFile), false, "disk must keep the old state");
});

test("R6-T34: rename failure → pre-rename/rename, 500, memory restored, tmp leftover harmless", async (t) => {
  const app = await startFaulty({
    // Fail only the FIRST rename so the retry after the fault clears can
    // succeed over the leftover tmp file (which must be harmlessly overwritten).
    hooks: { onRename: (a, b, state, once) => once("rename"), error: () => new Error("rename denied") },
  });
  t.after(async () => { await closeServer(app.server); fs.rmSync(app.cleanupDir, { recursive: true, force: true }); });
  const res = await post(app.port, { activationCode: makeCode("dev-t34"), deviceId: "dev-t34", prompt: "hi" });
  assert.equal(res.status, 500);
  assert.equal(app.snapshot().devices["dev-t34"], undefined, "memory must be rolled back");
  assert.equal(fs.existsSync(app.dbFile), false, "rename failed → devices.json must not exist");
  // Retry after the fault clears must succeed (tmp leftover gets overwritten).
  const retry = await post(app.port, { activationCode: makeCode("dev-t34"), deviceId: "dev-t34", prompt: "hi" });
  assert.equal(retry.status, 200);
  assert.equal(app.snapshot().devices["dev-t34"].used, 1);
});

test("R6-T39: dir open failure after rename → renamed-unconfirmed/dir-open, durable rollback restores old JSON", async (t) => {
  // Seed a committed record so "old complete JSON" is well-defined.
  const app = await startFaulty({ hooks: {}, opts: { maxUsage: 10 } });
  const seed = await post(app.port, { activationCode: makeCode("dev-seed"), deviceId: "dev-seed", prompt: "hi" });
  assert.equal(seed.status, 200);
  const oldDisk = JSON.parse(fs.readFileSync(app.dbFile, "utf8"));
  assert.equal(oldDisk["dev-seed"].used, 1);
  await closeServer(app.server);
  fs.rmSync(app.cleanupDir, { recursive: true, force: true });

  // New instance with a dir-open fault (after rename) — same seeded DB.
  const dir = tmpDir();
  const dbDir = path.join(dir, "data");
  fs.mkdirSync(dbDir, { recursive: true });
  const dbFile = path.join(dbDir, "devices.json");
  fs.writeFileSync(dbFile, JSON.stringify(oldDisk));
  const { adapter, state } = faultAdapter(dbDir, dbFile, {
    // Fail only the FIRST dir open (the durable rollback's dir open must
    // succeed so the old complete JSON is restored and the request is 500).
    onOpen: (p, flags, mode, fd, s, once) => p === dbDir && once("dir-open"),
    error: () => new Error("dir open denied"),
  });
  const app2 = await createApp({ publicKeyPem: TEST_PUBLIC_KEY, dbDir, fsAdapter: adapter, drawImageImpl: async () => "TEST_MOCK", onUnrecoverableStorage: () => {} });
  t.after(async () => { await closeServer(app2.server); fs.rmSync(dir, { recursive: true, force: true }); });
  const res = await post(app2.port, { activationCode: makeCode("dev-t39"), deviceId: "dev-t39", prompt: "hi" });
  assert.equal(res.status, 500);
  const diskAfter = JSON.parse(fs.readFileSync(dbFile, "utf8"));
  assert.deepEqual(Object.keys(diskAfter), ["dev-seed"], "durable rollback must restore the old complete JSON");
  assert.deepEqual(Object.keys(app2.snapshot().devices), ["dev-seed"], "memory must match disk (no divergence)");
});

test("R6-T35: dir fsync failure (once) → renamed-unconfirmed/dir-fsync, rollback succeeds → old JSON, retry safe", async (t) => {
  // Seed on a HEALTHY instance first (a fault adapter present during seed would
  // fail the seed itself, which is not what this case exercises), then open the
  // fault instance against the same DB.
  const dir = tmpDir();
  const dbDir = path.join(dir, "data");
  const seedApp = await createApp({
    publicKeyPem: TEST_PUBLIC_KEY,
    dbDir,
    drawImageImpl: async () => "TEST_MOCK",
    maxUsage: 10,
  });
  const seed = await post(seedApp.port, { activationCode: makeCode("dev-seed"), deviceId: "dev-seed", prompt: "hi" });
  assert.equal(seed.status, 200);
  await closeServer(seedApp.server);

  const dbFile = path.join(dbDir, "devices.json");
  const { adapter, state } = faultAdapter(dbDir, dbFile, {
    onFsync: (fd, s, once) => fd === s.dirFd && once("dir-fsync"), // fail first dir fsync only
    error: () => new Error("dir fsync denied"),
  });
  const app = await createApp({
    publicKeyPem: TEST_PUBLIC_KEY,
    dbDir,
    fsAdapter: adapter,
    drawImageImpl: async () => "TEST_MOCK",
    maxUsage: 10,
    onUnrecoverableStorage: () => {},
  });
  t.after(async () => { await closeServer(app.server); fs.rmSync(dir, { recursive: true, force: true }); });
  const res = await post(app.port, { activationCode: makeCode("dev-t35"), deviceId: "dev-t35", prompt: "hi" });
  assert.equal(res.status, 500, "rename already happened, rollback restores old state → 500 retryable");
  const disk = JSON.parse(fs.readFileSync(dbFile, "utf8"));
  assert.deepEqual(Object.keys(disk), ["dev-seed"], "final disk must be the old complete JSON (no divergence)");
  assert.deepEqual(Object.keys(app.snapshot().devices), ["dev-seed"], "memory must match disk");
  const retry = await post(app.port, { activationCode: makeCode("dev-t35"), deviceId: "dev-t35", prompt: "hi" });
  assert.equal(retry.status, 200);
  assert.equal(app.snapshot().devices["dev-t35"].used, 1);
});

test("R6-T40: file close failure → pre-rename/file-close, storage-unhealthy 503, no further writes", async (t) => {
  const app = await startFaulty({
    hooks: { onClose: (fd, state) => fd === state.fileFd, error: () => new Error("file close failed") },
  });
  t.after(async () => { await closeServer(app.server); fs.rmSync(app.cleanupDir, { recursive: true, force: true }); });
  const res = await post(app.port, { activationCode: makeCode("dev-t40"), deviceId: "dev-t40", prompt: "hi" });
  assert.equal(res.status, 503, "fd state unconfirmable → storage-unhealthy, never rename");
  assert.equal(fs.existsSync(app.dbFile), false, "file close failed before rename → old state on disk");
  const writesBefore = app.state.writes;
  const again = await post(app.port, { activationCode: makeCode("dev-t40"), deviceId: "dev-t40", prompt: "hi" });
  assert.equal(again.status, 503, "all consume/write entries return 503 while unhealthy");
  assert.equal(app.state.writes, writesBefore, "no further writes may happen after storage-unhealthy");
});

test("R6-T41: dir close failure after committed fsync → durable/dir-close, fail-stop 503, disk keeps NEW json, no rollback", async (t) => {
  const app = await startFaulty({
    hooks: { onClose: (fd, state) => fd === state.dirFd, error: () => new Error("dir close failed") },
  });
  t.after(async () => { await closeServer(app.server); fs.rmSync(app.cleanupDir, { recursive: true, force: true }); });
  const res = await post(app.port, { activationCode: makeCode("dev-t41"), deviceId: "dev-t41", prompt: "hi" });
  assert.equal(res.status, 503, "data is committed → fail-stop, must NOT roll back");
  const disk = JSON.parse(fs.readFileSync(app.dbFile, "utf8"));
  assert.equal(disk["dev-t41"].used, 1, "disk must keep the committed NEW json (no rollback)");
  assert.equal(app.snapshot().devices["dev-t41"].used, 1, "memory reloaded from disk keeps the new committed state");
});

test("R6-T37: durable rollback fails again → storage-unhealthy fail-stop, memory/disk converge, no writes after", async (t) => {
  // Seed on a HEALTHY instance, close it, then open the fault instance (whose
  // every dir-fsync fails) against the same DB.
  const dir = tmpDir();
  const dbDir = path.join(dir, "data");
  const seedApp = await createApp({
    publicKeyPem: TEST_PUBLIC_KEY,
    dbDir,
    drawImageImpl: async () => "TEST_MOCK",
    maxUsage: 10,
  });
  const seed = await post(seedApp.port, { activationCode: makeCode("dev-seed"), deviceId: "dev-seed", prompt: "hi" });
  assert.equal(seed.status, 200, "seed without fault must succeed");
  await closeServer(seedApp.server);

  const dbFile = path.join(dbDir, "devices.json");
  const { adapter, state } = faultAdapter(dbDir, dbFile, {
    onFsync: (fd, s) => fd === s.dirFd, // fail EVERY dir fsync (original + rollback)
    error: () => new Error("dir fsync always denied"),
  });
  const app = await createApp({
    publicKeyPem: TEST_PUBLIC_KEY,
    dbDir,
    fsAdapter: adapter,
    drawImageImpl: async () => "TEST_MOCK",
    maxUsage: 10,
    onUnrecoverableStorage: () => {},
  });
  t.after(async () => { await closeServer(app.server); fs.rmSync(dir, { recursive: true, force: true }); });
  const res = await post(app.port, { activationCode: makeCode("dev-t37"), deviceId: "dev-t37", prompt: "hi" });
  assert.equal(res.status, 503, "rollback failure → fail-stop 503");
  // Snapshot the write counter AFTER fail-stop: the original persist + rollback
  // writes have legitimately happened; nothing more may be written from here on.
  const writesBefore = state.writes;
  const disk = JSON.parse(fs.readFileSync(dbFile, "utf8"));
  assert.deepEqual(Object.keys(disk), ["dev-seed"], "disk must be a complete json (old), never diverging");
  assert.deepEqual(Object.keys(app.snapshot().devices), ["dev-seed"], "memory reloaded from disk must converge");
  const again = await post(app.port, { activationCode: makeCode("dev-t37"), deviceId: "dev-t37", prompt: "hi" });
  assert.equal(again.status, 503);
  assert.equal(state.writes, writesBefore, "no writes after storage-unhealthy");
});

test("R6: unreadable disk during fail-stop invokes onUnrecoverableStorage (tests never exit)", async (t) => {
  const dir = tmpDir();
  const dbDir = path.join(dir, "data");
  fs.mkdirSync(dbDir, { recursive: true });
  const dbFile = path.join(dbDir, "devices.json");
  const real = fs;
  const policyCalls = [];
  const { adapter, state } = faultAdapter(dbDir, dbFile, {
    onClose: (fd, s) => fd === s.dirFd, error: () => new Error("dir close failed"),
  });
  // After the dir-close failure, enterStorageUnhealthy tries a reload; make the
  // disk unreadable so the injectable termination policy must fire instead of exiting.
  adapter.readFileSync = () => { throw new Error("disk unreadable"); };
  const app = await createApp({
    publicKeyPem: TEST_PUBLIC_KEY,
    dbDir,
    fsAdapter: adapter,
    onUnrecoverableStorage: (err) => { policyCalls.push(err.message); },
  });
  t.after(async () => { await closeServer(app.server); fs.rmSync(dir, { recursive: true, force: true }); });
  const res = await post(app.port, { activationCode: makeCode("dev-unread"), deviceId: "dev-unread", prompt: "hi" });
  assert.equal(res.status, 503);
  assert.equal(policyCalls.length, 1, "onUnrecoverableStorage must be invoked exactly once (no process exit)");
  assert.equal(app.isStorageUnhealthy(), true);
});

test("R6: persistDurably tags every injected error with commitState/reason (no commitState leakage)", async () => {
  const dir = tmpDir();
  const dbDir = path.join(dir, "data");
  fs.mkdirSync(dbDir, { recursive: true });
  const dbFile = path.join(dbDir, "devices.json");
  const cases = [
    { hook: (h) => { h.onOpen = (p) => p.endsWith(".tmp"); }, cs: "pre-rename", reason: "tmp-open" },
    { hook: (h) => { h.onFsync = (fd, s) => fd === s.fileFd; }, cs: "pre-rename", reason: "write-or-fsync" },
    { hook: (h) => { h.onRename = () => true; }, cs: "pre-rename", reason: "rename" },
    { hook: (h) => { h.onClose = (fd, s) => fd === s.fileFd; }, cs: "pre-rename", reason: "file-close" },
    { hook: (h) => { h.onOpen = (p) => p === dbDir; }, cs: "renamed-unconfirmed", reason: "dir-open" },
    { hook: (h) => { h.onFsync = (fd, s) => fd === s.dirFd; }, cs: "renamed-unconfirmed", reason: "dir-fsync" },
    { hook: (h) => { h.onClose = (fd, s) => fd === s.dirFd; }, cs: "durable", reason: "dir-close" },
  ];
  for (const c of cases) {
    const hooks = { error: () => new Error("injected") };
    c.hook(hooks);
    const { adapter } = faultAdapter(dbDir, dbFile, hooks);
    const app = await createApp({ publicKeyPem: TEST_PUBLIC_KEY, dbDir, fsAdapter: adapter, onUnrecoverableStorage: () => {} });
    await closeServer(app.server);
    try {
      app.persistDurably(JSON.stringify({ x: 1 }));
      assert.fail(`expected injected error at ${c.reason}`);
    } catch (err) {
      assert.equal(err.commitState, c.cs, `${c.reason} must tag commitState=${c.cs}`);
      assert.equal(err.reason, c.reason, `${c.reason} must tag its reason`);
      assert.equal(typeof err.commitState, "string", "no stateless persist error may escape");
    }
  }
  fs.rmSync(dir, { recursive: true, force: true });
});

test("R6: stateless persist error → recoverPersistFailure fail-stop (503), never writable again", async (t) => {
  const app = await startFaulty({ hooks: {} });
  t.after(async () => { await closeServer(app.server); fs.rmSync(app.cleanupDir, { recursive: true, force: true }); });
  const outcome = app.recoverPersistFailure(JSON.stringify({}), new Error("programming bug: no commitState"));
  assert.equal(outcome.status, 503);
  assert.equal(app.isStorageUnhealthy(), true);
  const writesBefore = app.state.writes;
  const res = await post(app.port, { activationCode: makeCode("dev-noleak"), deviceId: "dev-noleak", prompt: "hi" });
  assert.equal(res.status, 503, "all consume entries return 503 while unhealthy");
  assert.equal(app.state.writes, writesBefore, "no further writes after fail-stop");
});

test("R6: consume and upstream rollback share the same durable-write path (source)", async () => {
  const source = await readFile("ai-server/app.mjs", "utf8");
  assert.doesNotMatch(source, /function persist\(\)/, "legacy persist() must be gone");
  assert.ok((source.match(/persistDurably\(/g) || []).length >= 3, "persistDurably used by consume + rollback + shared path");
  assert.ok((source.match(/recoverPersistFailure\(/g) || []).length >= 2, "recoverPersistFailure used by consume + rollback");
  assert.match(source, /storageUnhealthy/, "storage-unhealthy gate must exist");
  assert.match(source, /enterStorageUnhealthy/, "enterStorageUnhealthy must exist");
});

// ---------- L0: loopback-only /v1/admin/stats ----------

async function startStats(opts = {}) {
  return start({ adminSecret: "test-admin-secret", ...opts });
}

test("L0: /v1/admin/stats returns merged totals and remaining buckets", async (t) => {
  const app = await startStats({
    enableRebind: true,
    signNewCodeImpl: async (newDeviceId, expiry) => ({ ok: true, code: makeCode(newDeviceId, expiry) }),
    rebindIpLimit: 100,
    rebindActivationLimit: 100,
    auditLogImpl: () => {},
  });
  t.after(async () => { await closeServer(app.server); fs.rmSync(app.cleanupDir, { recursive: true, force: true }); });
  // 三个激活：dev-A、dev-B 独立；dev-C 走真实 rebind 迁移到 dev-C2。
  const codeA = makeCode("dev-A");
  const codeB = makeCode("dev-B");
  const codeC = makeCode("dev-C");
  await post(app.port, { activationCode: codeA, deviceId: "dev-A", prompt: "a" });
  await post(app.port, { activationCode: codeB, deviceId: "dev-B", prompt: "b" });
  await post(app.port, { activationCode: codeC, deviceId: "dev-C", prompt: "c" });
  const rebindRes = await fetch(`http://127.0.0.1:${app.port}/v1/ai/rebind`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ activationCode: codeC, oldDeviceId: "dev-C", newDeviceId: "dev-C2" }),
  });
  assert.equal(rebindRes.status, 200, "rebind must succeed");

  const res = await fetch(`http://127.0.0.1:${app.port}/v1/admin/stats`, {
    headers: { Authorization: "Bearer test-admin-secret" },
  });
  assert.equal(res.status, 200);
  const stats = await res.json();
  // 迁移链 dev-C→dev-C2 归并为一台：A + B + (C→C2) = 3 台
  assert.equal(stats.totalDevices, 3);
  assert.equal(stats.active24h, 3);
  assert.equal(stats.active7d, 3);
  // remaining = 100 - used = 99 → high51to99 桶
  assert.equal(stats.remainingDistribution.high51to99, 3);
});

test("L0: resolveMigrationTail collapses migrated chains for stats (source)", async () => {
  // 迁移归并口径由 resolveMigrationTail 保证；此处锚定 adminStats 调用它。
  const source = await readFile("ai-server/app.mjs", "utf8");
  assert.match(source, /resolveMigrationTail\(devices, deviceId\)/, "stats must merge via migration tail");
  assert.match(source, /function adminStats/, "adminStats must exist");
});

test("L0: /v1/admin/stats requires loopback + bearer secret (fail-closed)", async (t) => {
  const app = await start({}); // no adminSecret -> route hidden
  t.after(async () => { await closeServer(app.server); fs.rmSync(app.cleanupDir, { recursive: true, force: true }); });
  const noSecret = await fetch(`http://127.0.0.1:${app.port}/v1/admin/stats`);
  assert.equal(noSecret.status, 404, "no adminSecret -> route must not exist");
});

test("L0: /v1/admin/stats rejects wrong token and non-GET", async (t) => {
  const app = await startStats();
  t.after(async () => { await closeServer(app.server); fs.rmSync(app.cleanupDir, { recursive: true, force: true }); });
  const wrong = await fetch(`http://127.0.0.1:${app.port}/v1/admin/stats`, {
    headers: { Authorization: "Bearer nope" },
  });
  assert.equal(wrong.status, 401);
  const postReq = await fetch(`http://127.0.0.1:${app.port}/v1/admin/stats`, {
    method: "POST", headers: { Authorization: "Bearer test-admin-secret" },
  });
  assert.equal(postReq.status, 404, "non-GET on stats -> 404");
});
