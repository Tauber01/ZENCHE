// ZENCHE AI server — in-repo, secret-free module (1.5.2 S5).
// Ported from the verified testability skeleton (RESEARCH/ZENCHE_AI_SERVER_TESTABILITY.md),
// which was derived read-only from production /opt/ai-server/server.js
// (SHA-256 746589b7275936982ec140e0672f81cfd81aad6cda5c6ae27afda1ccf3832631).
//
// Scope: createApp factory, all-injectable config, loopback-only default,
// strict yyyyMMdd expiry semantics, corrupt-DB fail-loud, durable consumption,
// and an opt-in device-rebind route. NO production API key, signing key,
// production data, or deployment material is embedded. RSA keys and the
// internal redeem signer are injected; tests generate their keys at runtime.
import http from "node:http";
import https from "node:https";
import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";

export function resolveMigrationTail(devices, deviceId) {
  let current = deviceId;
  const seen = new Set();
  while (devices[current] && devices[current].migrated_to && !seen.has(current)) {
    seen.add(current);
    current = devices[current].migrated_to;
  }
  return current;
}

// Strict yyyyMMdd validity: rejects impossible dates (20260231) that JS Date
// would silently normalize (rollover), and treats the expiry day as valid for
// the whole day (expired only when strictly before today's start).
function isValidExpiryDate(expiry) {
  if (!/^\d{8}$/.test(String(expiry))) return false;
  const expYear = Number(expiry.slice(0, 4));
  const expMonth = Number(expiry.slice(4, 6));
  const expDay = Number(expiry.slice(6, 8));
  if (!expYear || !expMonth || !expDay) return false;
  const date = new Date(expYear, expMonth - 1, expDay);
  if (date.getFullYear() !== expYear || date.getMonth() !== expMonth - 1 || date.getDate() !== expDay) return false;
  return true;
}

function startOfToday() {
  const d = new Date();
  d.setHours(0, 0, 0, 0);
  return d;
}

// ===== zero-dependency upstream chain =====
// Ported from the audited production copy (/opt/ai-server/server.js, SHA-256
// 746589b7...): HTTP request, size→aspect-ratio mapping, reference-image
// validation, async result polling, image download→base64. All configuration
// (endpoint/model/replyType) is injected per-instance; the production public
// key and any real API key are NOT embedded here.

function httpRequestJson(protocol, hostname, port, path, method, headers, body, timeoutMs, maxBytes = Infinity) {
  return new Promise((resolve, reject) => {
    // Transport is chosen by the URL scheme, never by the port number — a
    // TLS endpoint on a non-443 port must still use https (R5.3).
    const transport = protocol === "https:" ? https : http;
    const req = transport.request(
      { hostname, port, path, method, headers, timeout: timeoutMs },
      (res) => {
        // Bounded outbound responses (R5.3): honor Content-Length up front and
        // cap streamed bytes. An over-limit response is destroyed immediately
        // so memory cannot keep growing; the caller gets a clear internal error.
        const declared = Number(res.headers["content-length"]);
        if (Number.isFinite(declared) && declared > maxBytes) {
          res.destroy();
          reject(new Error(`上游响应超过 ${maxBytes} 字节上限`));
          return;
        }
        const chunks = [];
        let total = 0;
        res.on("data", (c) => {
          total += c.length;
          if (total > maxBytes) {
            res.destroy();
            reject(new Error(`上游响应超过 ${maxBytes} 字节上限`));
            return;
          }
          chunks.push(c);
        });
        res.on("end", () => {
          resolve({ status: res.statusCode, headers: res.headers, body: Buffer.concat(chunks) });
        });
      }
    );
    req.on("timeout", () => { req.destroy(); reject(new Error("上游请求超时")); });
    req.on("error", reject);
    if (body) req.write(body);
    req.end();
  });
}

async function fetchImageAsBase64(imageUrl, timeoutMs = 60_000, maxBytes = 64 * 1024 * 1024) {
  const u = new URL(imageUrl);
  const resp = await httpRequestJson(
    u.protocol,
    u.hostname,
    Number(u.port) || (u.protocol === "https:" ? 443 : 80),
    u.pathname + u.search,
    "GET",
    {},
    null,
    timeoutMs,
    maxBytes
  );
  if (resp.status < 200 || resp.status >= 300) {
    throw new Error(`图片下载失败: HTTP ${resp.status}`);
  }
  return resp.body.toString("base64");
}

// The client historically sends pixel dimensions, while Grsai expects a small
// allow-list of aspect-ratio strings — the same five choices as the editors.
function imageOptions(size) {
  const knownRatios = {
    "1024x1024": "1:1",
    "1792x1024": "16:9",
    "1024x1792": "9:16",
    "1365x1024": "4:3",
    "1536x1024": "3:2",
  };
  return { aspectRatio: knownRatios[String(size || "1024x1024")] || "1:1", imageSize: "1K" };
}

function parseImageData(image) {
  if (!image) return null;
  if (typeof image !== "string") throw new Error("参考图格式无效");
  const value = image.trim();
  if (!value) throw new Error("参考图为空");
  if (/^data:image\/[a-z0-9.+-]+;base64,[a-z0-9+/=]+$/i.test(value)) return value;
  if (/^https?:\/\/\S+$/i.test(value)) return value;
  throw new Error("参考图格式无效");
}

function parseUpstreamObjects(text) {
  const value = text.trim();
  const lines = value.startsWith("data:")
    ? value.split("\n").filter((line) => line.startsWith("data:")).map((line) => line.slice(5).trim())
    : [value];
  return lines.filter((line) => line && line !== "[DONE]").map((line) => JSON.parse(line));
}

async function pollImageResult(apiKey, endpoint, id, maxBytes = 2 * 1024 * 1024) {
  const resultUrl = new URL("/v1/api/result", endpoint);
  resultUrl.searchParams.set("id", id);
  const deadline = Date.now() + 120_000;
  while (Date.now() < deadline) {
    const resp = await httpRequestJson(
      resultUrl.protocol,
      resultUrl.hostname,
      Number(resultUrl.port) || (resultUrl.protocol === "https:" ? 443 : 80),
      resultUrl.pathname + resultUrl.search,
      "GET",
      { Authorization: `Bearer ${apiKey}`, Accept: "application/json" },
      null,
      30_000,
      maxBytes
    );
    if (resp.status < 200 || resp.status >= 300) {
      throw new Error(`上游结果查询 HTTP ${resp.status}`);
    }
    const obj = parseUpstreamObjects(resp.body.toString("utf8"))[0] || {};
    if (obj.status === "succeeded") return obj;
    if (obj.status === "failed" || obj.code < 0) {
      throw new Error(obj.error || obj.msg || "AI 生成失败");
    }
    await new Promise((resolve) => setTimeout(resolve, 2_000));
  }
  throw new Error("上游生成超时");
}

function makeUpstreamDraw({ endpoint, model, replyType, maxUpstreamJsonBytes = 2 * 1024 * 1024, maxImageBytes = 64 * 1024 * 1024 }) {
  return async function upstreamDraw(apiKey, prompt, size, image) {
    const options = imageOptions(size);
    const reference = parseImageData(image);
    const body = {
      model,
      prompt,
      images: reference ? [reference] : [],
      ...options,
      replyType,
    };
    const url = new URL(endpoint);
    const resp = await httpRequestJson(
      url.protocol,
      url.hostname,
      Number(url.port) || (url.protocol === "https:" ? 443 : 80),
      url.pathname + url.search,
      "POST",
      {
        "Content-Type": "application/json",
        Authorization: `Bearer ${apiKey}`,
        Accept: "application/json",
      },
      JSON.stringify(body),
      30_000,
      maxUpstreamJsonBytes
    );
    if (resp.status < 200 || resp.status >= 300) {
      throw new Error(`上游 HTTP ${resp.status}: ${resp.body.toString("utf8").slice(0, 240)}`);
    }
    const text = resp.body.toString("utf8").trim();
    let lastUrl = null;
    const objects = parseUpstreamObjects(text);
    for (let obj of objects) {
      if (obj.status === "running" && obj.id) {
        obj = await pollImageResult(apiKey, endpoint, obj.id, maxUpstreamJsonBytes);
      }
      if (obj.results && Array.isArray(obj.results) && obj.results.length > 0) {
        const first = obj.results[0];
        if (first && first.url) lastUrl = first.url;
      }
      if (obj.status === "failed" || obj.code < 0) {
        throw new Error(obj.error || obj.msg || "AI 生成失败");
      }
    }
    if (!lastUrl) {
      throw new Error("AI 未返回图片 URL");
    }
    return fetchImageAsBase64(lastUrl, 60_000, maxImageBytes);
  };
}

function makeRedeemSigner({ endpoint, secret, timeoutMs = 5_000, maxBytes = 16 * 1024 }) {
  return async function signNewCode(newDeviceId, expiry) {
    const url = new URL(endpoint);
    const body = JSON.stringify({ newDeviceId, expiry });
    try {
      const resp = await httpRequestJson(
        url.protocol,
        url.hostname,
        Number(url.port) || (url.protocol === "https:" ? 443 : 80),
        url.pathname + url.search,
        "POST",
        {
          "Content-Type": "application/json",
          "Content-Length": Buffer.byteLength(body),
          Authorization: `Bearer ${secret}`,
          Accept: "application/json",
        },
        body,
        timeoutMs,
        maxBytes,
      );
      if (resp.status < 200 || resp.status >= 300) return { ok: false };
      const parsed = JSON.parse(resp.body.toString("utf8"));
      return typeof parsed.code === "string" && parsed.code
        ? { ok: true, code: parsed.code }
        : { ok: false };
    } catch {
      return { ok: false };
    }
  };
}

export function createApp(opts = {}) {
  const {
    dbDir = null,
    port = 0, // 0 => random port assigned by OS
    host = "127.0.0.1", // tests default to loopback only; production CLI overrides
    apiKey = "test-only-key",
    endpoint = "http://127.0.0.1:1/v1/api/generate", // unreachable default upstream
    model = "nano-banana-fast",
    replyType = "async",
    maxUsage = 100,
    maxBodyBytes = 64 * 1024 * 1024, // 64 MiB: large enough for base64 of high-res JPEGs
    maxUpstreamJsonBytes = 2 * 1024 * 1024, // 2 MiB: bounded upstream JSON responses (R5.3)
    maxImageBytes = 64 * 1024 * 1024, // 64 MiB: bounded image downloads (R5.3)
    publicKeyPem = null, // required; tests inject a runtime-generated test key
    verifyActivationImpl = null, // optional override for unit tests
    drawImageImpl = null, // optional injectable upstream; defaults to the real zero-dep chain
    enableRebind = false, // production must opt in only after HTTPS and port-closure gates pass
    signNewCodeImpl = null, // tests inject a signer; production calls the loopback redeem service
    redeemEndpoint = "http://127.0.0.1:8899/issue-migrated",
    rebindSecret = "",
    rebindTimeoutMs = 5_000,
    rebindWindowMs = 60_000,
    rebindIpLimit = 10,
    rebindActivationLimit = 3,
    rebindLimiterMaxKeys = 10_000,
    adminSecret = "", // loopback-only /v1/admin/stats bearer secret (constant-time compare)
    auditLogImpl = (line) => console.log(line),
    fsAdapter = null, // injectable fs adapter (R6 fault injection; tests only)
    onUnrecoverableStorage = null, // injectable fail-stop policy; CLI supplies the exit strategy
  } = opts;

  if (!publicKeyPem) throw new Error("createApp requires publicKeyPem (test key or production key)");
  if (enableRebind && !signNewCodeImpl && !rebindSecret) {
    throw new Error("rebind requires signNewCodeImpl or ZENCHE_REBIND_SECRET");
  }

  // All storage access goes through the injectable adapter so R6 can fault
  // every step (open/write/fsync/close/rename) deterministically in tests.
  const F = fsAdapter || fs;

  const DB_DIR = dbDir || path.join(process.cwd(), "data");
  const DB_FILE = path.join(DB_DIR, "devices.json");
  F.mkdirSync(DB_DIR, { recursive: true });

  let devices = {};
  let storageUnhealthy = false;
  const inflight = new Map();
  const rebinding = new Set();
  const rebindIpAttempts = new Map();
  const rebindActivationAttempts = new Map();
  if (F.existsSync(DB_FILE)) {
    // Fail-loud: a corrupt devices.json must NOT be silently reset to {} —
    // that would zero every device's count without warning (production P1).
    try { devices = JSON.parse(F.readFileSync(DB_FILE, "utf8")); }
    catch (err) { throw new Error(`corrupt devices.json at ${DB_FILE}: ${err.message}`); }
  }

  // ===== R6: shared durable write (spec §1.4.1) =====
  // commitState 三态：pre-rename | renamed-unconfirmed | durable。任何持久化
  // 错误必须携带 commitState/reason，绝不外泄无状态错误（无 commitState 的
  // 错误一律按编程错误 fail-stop）。

  function tag(err, meta) {
    if (err && typeof err === "object") Object.assign(err, meta);
    return err;
  }

  // 独立关闭：close 自身失败只记日志返回 false，不覆盖已标记的主错误；
  // 通过 storageSuspect 挂到主错误上，使恢复路径倾向 fail-stop。
  function closeSafely(fd) {
    try { F.closeSync(fd); return true; }
    catch (err) { console.error("[ZENCHE-AI][STORAGE] fd close 失败", err); return false; }
  }

  // 唯一耐久写入函数：同目录 tmp（0600，残留文件也 fchmod 强制）→ 文件
  // fsync → 文件 close → 原子 rename → 目录 open → 目录 fsync → 目录 close。
  // consume 的 used+1 与上游失败 used-1 共用此路径。
  function persistDurably(data) {
    const tmp = DB_FILE + ".tmp";

    // —— 阶段 A：tmp 写入 + 文件 fsync + 文件 close（commitState = pre-rename）——
    let fd;
    try {
      fd = F.openSync(tmp, "w", 0o600);            // A1 tmp open（0600）
      F.fchmodSync(fd, 0o600);                     // 残留 tmp 也实际强制 0600（open mode 仅创建时生效）
    } catch (err) {
      if (fd !== undefined) closeSafely(fd);       // 尽力关闭，不覆盖主错误
      throw tag(err, { commitState: "pre-rename", reason: "tmp-open" });
    }
    let closeFailed = false;
    try {
      F.writeFileSync(fd, data);                   // A2 写入
      F.fsyncSync(fd);                             // A2 文件 fsync：数据落盘
    } catch (err) {
      if (!closeSafely(fd)) closeFailed = true;    // 尽力关闭，不覆盖主错误
      throw tag(err, { commitState: "pre-rename", reason: "write-or-fsync", storageSuspect: closeFailed });
    }
    try {
      F.closeSync(fd);                             // A3 文件 close（rename 前）
    } catch (err) {
      // fd 状态无法确认 → 不得继续 rename；按 pre-rename 回滚但倾向 fail-stop
      throw tag(err, { commitState: "pre-rename", reason: "file-close", storageSuspect: true });
    }

    // —— 阶段 B：原子 rename（commitState = pre-rename；失败则磁盘仍旧）——
    try {
      F.renameSync(tmp, DB_FILE);                  // B rename（旧→新原子替换）
    } catch (err) {
      throw tag(err, { commitState: "pre-rename", reason: "rename" });
    }

    // —— 阶段 C：目录 open + 目录 fsync + 目录 close（rename 后）——
    let dfd;
    try {
      dfd = F.openSync(DB_DIR, "r");               // C1 目录 open
    } catch (err) {
      throw tag(err, { commitState: "renamed-unconfirmed", reason: "dir-open" });
    }
    closeFailed = false;
    try {
      F.fsyncSync(dfd);                            // C2 目录 fsync：目录项落盘
    } catch (err) {
      if (!closeSafely(dfd)) closeFailed = true;   // 尽力关闭，不覆盖主错误
      throw tag(err, { commitState: "renamed-unconfirmed", reason: "dir-fsync", storageSuspect: closeFailed });
    }
    try {
      F.closeSync(dfd);                            // C3 目录 close
    } catch (err) {
      // 目录 fsync 已成功 → 已提交（durable）。不得回滚成旧状态！
      throw tag(err, { commitState: "durable", reason: "dir-close" });
    }
    return { commitState: "durable" };             // 全部成功
  }

  // 进入 fail-stop：原子设置全局 storageUnhealthy（此后所有 consume/写入口在
  // 任何读写前返回 503，绝不继续写）。内存尝试从磁盘完整 JSON 重载（rename
  // 原子性保证磁盘是旧或新完整 JSON 之一）；磁盘不可读/无法确认时调用可注入
  // 终止策略（CLI 退出；测试注入回调，进程不退出）。
  function enterStorageUnhealthy() {
    storageUnhealthy = true;
    try {
      devices = JSON.parse(F.readFileSync(DB_FILE, "utf8"));
    } catch (err) {
      if (onUnrecoverableStorage) {
        try { onUnrecoverableStorage(err); } catch { /* 策略本身抛错不得影响 fail-stop */ }
      }
    }
    return { status: 503, body: { error: "存储异常，服务暂不可用" } };
  }

  // 共享恢复函数（consume 与上游回滚调用同一实现，保证两路径语义一致）。
  // snapshot = 本持久化点之前捕获的整表 JSON。
  function recoverPersistFailure(snapshot, err) {
    const cs = err && err.commitState;             // 持久化错误必须携带 commitState
    if (!cs) return enterStorageUnhealthy();       // 无状态错误外泄 = 编程错误 → fail-stop
    if (cs === "pre-rename") {                     // 磁盘仍是旧文件
      devices = JSON.parse(snapshot);              // 内存回滚，与磁盘一致
      if (err.storageSuspect) return enterStorageUnhealthy();  // 文件 close 失败：fd 状态不明 → 503
      return { status: 500, body: { error: "服务器内部错误" } };
    }
    if (cs === "renamed-unconfirmed") {            // 磁盘已新、目录项未确认
      try {
        persistDurably(snapshot);                  // 完整耐久回滚旧快照
        devices = JSON.parse(snapshot);            // 磁盘内存均回旧，无分叉
        if (err.storageSuspect) return enterStorageUnhealthy();  // close 失败残留怀疑 → 保守 503
        return { status: 500, body: { error: "服务器内部错误" } };
      } catch (rollbackErr) {
        return enterStorageUnhealthy();            // 回滚失败 → fail-stop
      }
    }
    // cs === 'durable'：数据已提交。不得回滚；进入 fail-stop，内存以磁盘新态为准
    return enterStorageUnhealthy();
  }

  // 统一写入口：变更前取整表快照 → persistDurably → 失败走 recoverPersistFailure。
  // storageUnhealthy 门禁在任何消费/写盘之前原子生效。
  function durableWrite(mutator) {
    if (storageUnhealthy) return { status: 503, body: { error: "存储异常，服务暂不可用" } };
    const snapshot = JSON.stringify(devices);
    mutator();
    try {
      persistDurably(JSON.stringify(devices));
      return null;                                 // 成功
    } catch (err) {
      return recoverPersistFailure(snapshot, err);
    }
  }

  function consume(deviceId, activation, expiry) {
    if (storageUnhealthy) return { status: 503, body: { error: "存储异常，服务暂不可用" } };
    const dev = devices[deviceId];
    // Admin 吊销门禁：revoked 后 consume 必须 403（verifyActivation 是纯密码学不查库，
    // 吊销检查在此层）。
    if (dev && dev.revoked) {
      return { status: 403, body: { error: "该激活码已吊销" } };
    }
    if (dev && dev.migrated_to) {
      return { status: 409, body: { error: "该激活码已迁移，请使用新设备激活码" } };
    }
    if (!dev || dev.activation !== activation) {
      const failure = durableWrite(() => {
        devices[deviceId] = {
          activation, expiry, used: 1, last_seen: Date.now(),
          created_at: Date.now(),
        };
      });
      if (failure) return failure;
      return { allowed: true, used: 1, remaining: maxUsage - 1 };
    }
    if (dev.used >= maxUsage) return { allowed: false, used: dev.used, remaining: 0 };
    const failure = durableWrite(() => {
      dev.used += 1;
      dev.last_seen = Date.now();
    });
    if (failure) return failure;
    return { allowed: true, used: dev.used, remaining: maxUsage - dev.used };
  }

  function verifyActivation(code, deviceId) {
    if (!code || !deviceId) return { ok: false, reason: "参数缺失" };
    const parts = String(code).trim().split("-");
    if (parts.length < 4 || parts[0] !== "ZENCHE" || parts[1] !== "AI") {
      return { ok: false, reason: "激活码格式错误" };
    }
    const expiry = parts[parts.length - 1];
    if (!isValidExpiryDate(expiry)) return { ok: false, reason: "激活码无效" };
    const expDate = new Date(Number(expiry.slice(0, 4)), Number(expiry.slice(4, 6)) - 1, Number(expiry.slice(6, 8)));
    if (expDate < startOfToday()) return { ok: false, reason: "激活码已过期" };
    const sigPart = parts.slice(2, parts.length - 1).join("-");
    const payload = `${deviceId}:${expiry}:a1b2c3d4e5f6`;
    try {
      const verifier = crypto.createVerify("RSA-SHA256");
      verifier.update(payload, "utf8");
      return verifier.verify(publicKeyPem, sigPart, "base64")
        ? { ok: true, expiry }
        : { ok: false, reason: "激活码与设备不匹配" };
    } catch { return { ok: false, reason: "激活码无效" }; }
  }

  function fingerprint(value) {
    return crypto.createHash("sha256").update(String(value || ""), "utf8").digest("hex").slice(0, 12);
  }

  // Constant-time bearer compare (same pattern as redeem-rebind.mjs): both
  // sides are hashed first so timingSafeEqual sees equal-length buffers and
  // the digest leaks nothing usable about the secret.
  function constantTimeEqual(a, b) {
    const ha = crypto.createHash("sha256").update(String(a || ""), "utf8").digest();
    const hb = crypto.createHash("sha256").update(String(b || ""), "utf8").digest();
    return crypto.timingSafeEqual(ha, hb);
  }

  function bearerToken(req) {
    const header = req.headers.authorization;
    if (typeof header !== "string") return null;
    const match = /^Bearer\s+(\S+)$/i.exec(header);
    return match ? match[1] : null;
  }

  // Loopback-only guard: the stats route is meant for the operator on the
  // same host (systemd / nohup supervisor), never for the public surface.
  function isLoopback(req) {
    const remote = req.socket.remoteAddress || "";
    return remote === "127.0.0.1" || remote === "::1" || remote === "::ffff:127.0.0.1";
  }

  // Aggregate usage statistics over the migration-merged device registry.
  // resolveMigrationTail collapses a migrated chain to its final device so a
  // migrated activation is never double-counted. "活跃" (active) is measured
  // by last_seen within the window on the merged tail device.
  function adminStats(now = Date.now()) {
    const dayMs = 24 * 60 * 60 * 1000;
    const tailSeen = new Map(); // tail -> newest last_seen
    const remaining = new Map(); // tail -> remaining (min across merged records)
    const tails = new Set();
    const tailRecord = new Map(); // tail -> latest tail record (revoked/expiry)
    for (const [deviceId, record] of Object.entries(devices)) {
      if (!record || typeof record !== "object") continue;
      const tail = resolveMigrationTail(devices, deviceId);
      tails.add(tail);
      const seen = Number(record.last_seen) || 0;
      if (seen > (tailSeen.get(tail) || 0)) tailSeen.set(tail, seen);
      const rem = Math.max(0, maxUsage - (Number(record.used) || 0));
      const current = remaining.get(tail);
      if (current === undefined || rem < current) remaining.set(tail, rem);
      if (deviceId === tail) tailRecord.set(tail, record);
    }
    const active24h = [...tailSeen.values()].filter((ts) => now - ts <= dayMs).length;
    const active7d = [...tailSeen.values()].filter((ts) => now - ts <= 7 * dayMs).length;
    const buckets = {
      zero: 0,
      low1to10: 0,
      mid11to50: 0,
      high51to99: 0,
      full100: 0,
    };
    let expiring7d = 0;
    let exhausted = 0;
    let revoked = 0;
    const startOfToday = startOfTodayMs();
    for (const rem of remaining.values()) {
      if (rem <= 0) buckets.zero += 1;
      else if (rem <= 10) buckets.low1to10 += 1;
      else if (rem <= 50) buckets.mid11to50 += 1;
      else if (rem < maxUsage) buckets.high51to99 += 1;
      else buckets.full100 += 1;
    }
    for (const [tail, record] of tailRecord.entries()) {
      if (record.revoked) {
        revoked += 1;
        continue;
      }
      const rem = remaining.get(tail) ?? 0;
      if (rem <= 0) exhausted += 1;
      if (isExpiringWithinDays(record.expiry, 7, startOfToday)) expiring7d += 1;
    }
    return {
      totalDevices: tails.size,
      active24h,
      active7d,
      expiring7d,
      exhausted,
      revoked,
      remainingDistribution: buckets,
      generated_at: new Date(now).toISOString(),
    };
  }

  // 本地时区当日零点（与过期判定同一口径）。
  function startOfTodayMs() {
    const d = new Date();
    return new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
  }

  // 到期日在 [today, today+days) 区间（未过期但临近）返回 true。
  function isExpiringWithinDays(expiry, days, startOfToday) {
    if (!isValidExpiryDate(expiry)) return false;
    const exp = new Date(
      Number(expiry.slice(0, 4)),
      Number(expiry.slice(4, 6)) - 1,
      Number(expiry.slice(6, 8))
    ).getTime();
    const horizon = startOfToday + days * 24 * 60 * 60 * 1000;
    return exp >= startOfToday && exp < horizon;
  }

  function auditRebind(oldDeviceId, newDeviceId, activation, ip, result) {
    try {
      auditLogImpl(
        `[ZENCHE-AI][REBIND] from=${fingerprint(oldDeviceId)} to=${fingerprint(newDeviceId)} ` +
        `activation=${fingerprint(activation)} ip=${fingerprint(ip)} result=${result} ts=${new Date().toISOString()}`,
      );
    } catch (err) {
      console.error("[ZENCHE-AI][REBIND] 审计日志写入失败", err);
    }
  }

  function rateLimited(bucket, key, limit, now = Date.now()) {
    const recent = (bucket.get(key) || []).filter((ts) => now - ts < rebindWindowMs);
    if (recent.length >= limit) {
      bucket.set(key, recent);
      return true;
    }
    if (!bucket.has(key) && bucket.size >= rebindLimiterMaxKeys) {
      for (const [candidate, timestamps] of bucket) {
        if (timestamps.every((ts) => now - ts >= rebindWindowMs)) bucket.delete(candidate);
      }
      if (bucket.size >= rebindLimiterMaxKeys) return true;
    }
    recent.push(now);
    bucket.set(key, recent);
    return false;
  }

  function clientIp(req) {
    const remote = req.socket.remoteAddress || "unknown";
    const fromLoopback = remote === "127.0.0.1" || remote === "::1" || remote === "::ffff:127.0.0.1";
    const forwarded = req.headers["x-forwarded-for"];
    if (fromLoopback && typeof forwarded === "string" && forwarded.trim()) {
      return forwarded.split(",", 1)[0].trim().slice(0, 128);
    }
    return remote;
  }

  // ── Admin 审计日志（JSONL 追加 + fsync；完整激活码不入日志）──

  function adminAudit(op, params = {}, result) {
    try {
      const line = JSON.stringify({
        ts: new Date().toISOString(),
        op,
        device_id_fp: params.device_id ? fingerprint(params.device_id) : undefined,
        params: params.note ? { note_len: String(params.note).length } : (params.expiry ? { expiry: params.expiry } : {}),
        result,
      });
      const dir = DB_DIR;
      F.mkdirSync(dir, { recursive: true });
      const file = path.join(dir, "admin-audit.jsonl");
      const fd = F.openSync(file, "a", 0o600);
      try {
        F.writeSync(fd, line + "\n");
        F.fsyncSync(fd);
      } finally {
        F.closeSync(fd);
      }
    } catch (err) {
      console.error("[ai-server][admin] 审计日志写入失败", err.message);
    }
  }

  // ── Admin 设备视图 ──

  function deviceStatus(record) {
    if (record.revoked) return "revoked";
    const expiry = record.expiry;
    if (isValidExpiryDate(expiry)) {
      const exp = new Date(
        Number(expiry.slice(0, 4)),
        Number(expiry.slice(4, 6)) - 1,
        Number(expiry.slice(6, 8))
      );
      if (exp < startOfTodayMs()) return "expired";
    }
    if ((Number(record.used) || 0) >= maxUsage) return "exhausted";
    return "active";
  }

  function deviceView(deviceId, record) {
    return {
      device_id: deviceId,
      activation: record.activation,
      expiry: record.expiry,
      used: Number(record.used) || 0,
      remaining: Math.max(0, maxUsage - (Number(record.used) || 0)),
      last_seen: record.last_seen,
      created_at: record.created_at,
      revoked: !!record.revoked,
      note: record.note || "",
      migrated_to: record.migrated_to,
      migrated_from: record.migrated_from,
      status: deviceStatus(record),
    };
  }

  // 迁移链双向展开（沿 migrated_to/from 收集节点，含当前设备）。
  function migrationChain(deviceId) {
    const chain = [];
    // 向后（源头方向）：从当前设备的 migrated_from 链收集前驱（不含自身）。
    const backward = [];
    let origin = deviceId;
    while (devices[origin] && devices[origin].migrated_from) {
      origin = devices[origin].migrated_from;
      if (!devices[origin]) break;
      backward.push(origin);
    }
    for (let i = backward.length - 1; i >= 0; i--) {
      chain.push(deviceView(backward[i], devices[backward[i]]));
    }
    // 主链（deviceId → tail）。
    let node = deviceId;
    const seen = new Set();
    while (node && !seen.has(node) && devices[node]) {
      seen.add(node);
      chain.push(deviceView(node, devices[node]));
      node = devices[node].migrated_to;
    }
    return chain;
  }

  // ── Admin 设备列表（过滤 + 分页 + 查询） ──

  function deviceMatchesFilter(record, tail, filter, now) {
    const dayMs = 24 * 60 * 60 * 1000;
    const status = deviceStatus(record);
    switch (filter) {
      case "active24h":
        return status === "active" && (Number(record.last_seen) || 0) >= now - dayMs;
      case "active7d":
        return status === "active" && (Number(record.last_seen) || 0) >= now - 7 * dayMs;
      case "expired":
        return status === "expired";
      case "expiring7d":
        return status === "active"
          && isExpiringWithinDays(record.expiry, 7, startOfTodayMs());
      case "exhausted":
        return status === "exhausted";
      case "revoked":
        return status === "revoked";
      default:
        return true;
    }
  }

  function adminListDevices(query, filter, cursor, limit, now = Date.now()) {
    const all = Object.keys(devices).sort();
    const q = (query || "").trim().toLowerCase();
    const items = [];
    let total = 0;
    let collecting = !cursor;
    for (const deviceId of all) {
      if (cursor && deviceId <= cursor) continue;
      const record = devices[deviceId];
      if (!record || typeof record !== "object") continue;
      if (!deviceMatchesFilter(record, deviceId, filter, now)) continue;
      if (q && !deviceId.toLowerCase().includes(q)
          && !String(record.activation || "").toLowerCase().includes(q)) {
        continue;
      }
      // 到达 cursor 后的第一条起收集（cursor 语义：上一页末 device_id，下一页从其后开始）。
      total += 1;
      collecting = true;
      items.push(deviceView(deviceId, record));
      if (items.length >= limit) break;
    }
    const nextCursor = items.length === limit && items.length > 0
      ? items[items.length - 1].device_id
      : null;
    return { items, next_cursor: nextCursor, total };
  }

  // ── Admin 静态服务（ai-server/admin/ 目录，无 token，loopback 天然受限） ──

  const ADMIN_WEB_DIR = path.join(path.dirname(DB_DIR), "admin");

  function adminStatic(req, res, pathname) {
    let decoded;
    try {
      decoded = decodeURIComponent(pathname);
    } catch {
      res.writeHead(400, { "Content-Type": "text/plain; charset=utf-8" });
      res.end("Bad request");
      return;
    }
    const safePath = path.normalize(decoded).replace(/^(\.\.[/\\])+/, "");
    let filePath = path.join(ADMIN_WEB_DIR, safePath === "/" ? "index.html" : safePath);
    if (!filePath.startsWith(ADMIN_WEB_DIR) || !F.existsSync(filePath)) {
      res.writeHead(404, { "Content-Type": "text/plain; charset=utf-8" });
      res.end("Not found");
      return;
    }
    if (F.statSync(filePath).isDirectory()) filePath = path.join(filePath, "index.html");
    const contentTypes = {
      ".html": "text/html; charset=utf-8",
      ".js": "application/javascript; charset=utf-8",
      ".css": "text/css; charset=utf-8",
      ".json": "application/json; charset=utf-8",
      ".svg": "image/svg+xml",
      ".png": "image/png",
    };
    res.writeHead(200, {
      "Content-Type": contentTypes[path.extname(filePath)] || "application/octet-stream",
      "Cache-Control": "no-cache",
    });
    res.end(F.readFileSync(filePath));
  }

  // ── 趋势快照（每日一行 JSONL；写失败仅 console.error 不 fail-stop） ──

  function snapshotToday() {
    const d = new Date();
    const key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
    return { date: key, ...adminStats() };
  }

  function ensureSnapshotFile() {
    try {
      const file = path.join(DB_DIR, "admin-stats-snapshots.jsonl");
      F.mkdirSync(DB_DIR, { recursive: true });
      const today = snapshotToday();
      let line = today.date;
      let needsAppend = false;
      if (F.existsSync(file)) {
        const content = F.readFileSync(file, "utf8");
        needsAppend = !content.split("\n").some((l) => l.startsWith(`{"date":"${today.date}"`));
      } else {
        needsAppend = true;
      }
      if (needsAppend) {
        const fd = F.openSync(file, "a", 0o600);
        try {
          F.writeSync(fd, JSON.stringify(today) + "\n");
          F.fsyncSync(fd);
        } finally {
          F.closeSync(fd);
        }
      }
      return today;
    } catch (err) {
      // 非关键路径：快照写失败不触发 fail-stop。
      console.error("[ai-server][admin] 快照写入失败", err.message);
      return null;
    }
  }

  function readSnapshotHistory(days) {
    try {
      const file = path.join(DB_DIR, "admin-stats-snapshots.jsonl");
      if (!F.existsSync(file)) return [];
      const lines = F.readFileSync(file, "utf8").split("\n").filter(Boolean);
      const tail = lines.slice(-Math.max(1, Math.min(365, days || 30)));
      return tail.map((l) => {
        try { return JSON.parse(l); } catch { return null; }
      }).filter(Boolean);
    } catch {
      return [];
    }
  }

  function beginInflight(deviceId) {
    inflight.set(deviceId, (inflight.get(deviceId) || 0) + 1);
  }

  function endInflight(deviceId) {
    const next = (inflight.get(deviceId) || 1) - 1;
    if (next <= 0) inflight.delete(deviceId);
    else inflight.set(deviceId, next);
  }

  function currentRebindState(oldDeviceId, newDeviceId) {
    const dev = devices[newDeviceId];
    const used = Number(dev && dev.used) || 0;
    return {
      ok: true,
      oldDeviceId,
      newDeviceId,
      used,
      remaining: Math.max(0, maxUsage - used),
      newCode: dev && dev.activation,
    };
  }

  const signNewCode = signNewCodeImpl || makeRedeemSigner({
    endpoint: redeemEndpoint,
    secret: rebindSecret,
    timeoutMs: rebindTimeoutMs,
  });

  async function rebind(activationCode, oldDeviceId, newDeviceId, ip) {
    const activation = String(activationCode).trim();
    const verifier = verifyActivationImpl || verifyActivation;
    const check = verifier(activation, oldDeviceId);
    if (!check.ok) {
      auditRebind(oldDeviceId, newDeviceId, activation, ip, "invalid-activation");
      return { status: 401, body: { error: check.reason } };
    }

    const old = devices[oldDeviceId];
    if (!old || old.activation !== activation) {
      auditRebind(oldDeviceId, newDeviceId, activation, ip, "binding-not-found");
      return { status: 403, body: { error: "设备码与激活码未绑定，无法迁移" } };
    }
    // Admin 吊销门禁：revoked 后 rebind 必须 403。
    if (old.revoked) {
      auditRebind(oldDeviceId, newDeviceId, activation, ip, "revoked");
      return { status: 403, body: { error: "该激活码已吊销" } };
    }
    if (oldDeviceId === newDeviceId) {
      auditRebind(oldDeviceId, newDeviceId, activation, ip, "idempotent-same-device");
      return { status: 200, body: currentRebindState(oldDeviceId, newDeviceId) };
    }
    if (old.migrated_to) {
      if (old.migrated_to === newDeviceId && devices[newDeviceId]) {
        auditRebind(oldDeviceId, newDeviceId, activation, ip, "idempotent-replay");
        return { status: 200, body: currentRebindState(oldDeviceId, newDeviceId) };
      }
      auditRebind(oldDeviceId, newDeviceId, activation, ip, "already-migrated");
      return { status: 409, body: { error: "该激活码已迁移至其他设备" } };
    }
    if (devices[newDeviceId]) {
      auditRebind(oldDeviceId, newDeviceId, activation, ip, "target-occupied");
      return { status: 409, body: { error: "新设备码已有激活记录" } };
    }
    if ((inflight.get(oldDeviceId) || 0) > 0 || (inflight.get(newDeviceId) || 0) > 0) {
      auditRebind(oldDeviceId, newDeviceId, activation, ip, "request-inflight");
      return { status: 409, body: { error: "设备有进行中的 AI 请求，请稍后重试" } };
    }
    if (rebinding.has(oldDeviceId) || rebinding.has(newDeviceId)) {
      auditRebind(oldDeviceId, newDeviceId, activation, ip, "rebind-inflight");
      return { status: 409, body: { error: "设备正在换绑，请稍后重试" } };
    }

    rebinding.add(oldDeviceId);
    rebinding.add(newDeviceId);
    try {
      let signed;
      try { signed = await signNewCode(newDeviceId, check.expiry); }
      catch { signed = { ok: false }; }
      if (!signed || !signed.ok || !signed.code) {
        auditRebind(oldDeviceId, newDeviceId, activation, ip, "signer-failed");
        return { status: 502, body: { error: "签发失败请重试" } };
      }
      const signedCheck = verifyActivation(signed.code, newDeviceId);
      if (!signedCheck.ok || signedCheck.expiry !== check.expiry) {
        auditRebind(oldDeviceId, newDeviceId, activation, ip, "signed-code-invalid");
        return { status: 502, body: { error: "签发失败请重试" } };
      }

      const used = Number(old.used) || 0;
      const now = Date.now();
      const failure = durableWrite(() => {
        devices[oldDeviceId].migrated_to = newDeviceId;
        devices[oldDeviceId].migrated_at = now;
        devices[newDeviceId] = {
          activation: signed.code,
          expiry: check.expiry,
          used,
          last_seen: now,
          migrated_from: oldDeviceId,
        };
      });
      if (failure) {
        auditRebind(oldDeviceId, newDeviceId, activation, ip, `persist-${failure.status}`);
        return failure;
      }
      auditRebind(oldDeviceId, newDeviceId, activation, ip, "ok");
      return { status: 200, body: currentRebindState(oldDeviceId, newDeviceId) };
    } finally {
      rebinding.delete(oldDeviceId);
      rebinding.delete(newDeviceId);
    }
  }

  function reply(res, status, obj, headers = {}) {
    res.writeHead(status, { "Content-Type": "application/json; charset=utf-8", ...headers });
    res.end(JSON.stringify(obj));
  }

  const draw = drawImageImpl || makeUpstreamDraw({ endpoint, model, replyType, maxUpstreamJsonBytes, maxImageBytes });

  // ── Admin API 路由分发（认证已在 handle 前置门禁完成） ──

  function readJsonBody(req) {
    return new Promise((resolve) => {
      const chunks = [];
      let total = 0;
      let tooLarge = false;
      req.on("data", (chunk) => {
        total += chunk.length;
        if (total > 64 * 1024) {
          tooLarge = true;
          req.destroy();
          return;
        }
        chunks.push(chunk);
      });
      req.on("end", () => {
        if (tooLarge) { resolve({ error: "请求体过大" }); return; }
        const raw = Buffer.concat(chunks).toString("utf8");
        if (!raw.trim()) { resolve({}); return; }
        try { resolve(JSON.parse(raw)); }
        catch { resolve({ error: "无效的 JSON" }); }
      });
      req.on("error", () => resolve({ error: "请求体读取失败" }));
    });
  }

  async function handleAdmin(req, res, route) {
    // 1. GET /v1/admin/stats（扩展）
    if (route === "/v1/admin/stats" && req.method === "GET") {
      return reply(res, 200, adminStats());
    }
    // 2. GET /v1/admin/stats/history?days=30
    if (route === "/v1/admin/stats/history" && req.method === "GET") {
      const days = Math.max(1, Math.min(365, Number(new URL(req.url, "http://x").searchParams.get("days") || 30) || 30));
      const history = readSnapshotHistory(days);
      if (history.length === 0) {
        // 无历史行时先补当日快照，保证至少一行。
        ensureSnapshotFile();
      }
      return reply(res, 200, {
        days,
        snapshots: history.length === 0 ? [snapshotToday()] : history,
      });
    }
    // 3. GET /v1/admin/devices?query=&filter=&cursor=&limit=
    if (route === "/v1/admin/devices" && req.method === "GET") {
      const params = new URL(req.url, "http://x").searchParams;
      const limit = Math.max(1, Math.min(200, Number(params.get("limit") || 50) || 50));
      const filter = params.get("filter") || "all";
      const items = adminListDevices(
        params.get("query") || "",
        filter,
        params.get("cursor") || "",
        limit
      );
      return reply(res, 200, items);
    }
    // 4. GET /v1/admin/devices/{deviceId}
    const deviceMatch = route.match(/^\/v1\/admin\/devices\/([^/]+)$/);
    if (deviceMatch && req.method === "GET") {
      const deviceId = decodeURIComponent(deviceMatch[1]);
      const record = devices[deviceId];
      if (!record) return reply(res, 404, { error: "设备不存在" });
      return reply(res, 200, {
        device: deviceView(deviceId, record),
        chain: migrationChain(deviceId),
      });
    }
    // 5-8. 设备操作（POST）：reset-usage / extend-expiry / revoke / unrevoke / note
    const opMatch = route.match(/^\/v1\/admin\/devices\/([^/]+)\/(reset-usage|extend-expiry|revoke|unrevoke|note)$/);
    if (opMatch && req.method === "POST") {
      const deviceId = decodeURIComponent(opMatch[1]);
      const op = opMatch[2];
      const record = devices[deviceId];
      if (!record) return reply(res, 404, { error: "设备不存在" });
      const body = await readJsonBody(req);
      if (body.error) return reply(res, 400, { error: body.error });

      if (op === "reset-usage") {
        // 迁移链只作用 tail 当前记录。
        const failure = durableWrite(() => { record.used = 0; });
        if (failure) return reply(res, failure.status, failure.body);
        adminAudit("reset-usage", { device_id: deviceId }, "ok");
        return reply(res, 200, deviceView(deviceId, record));
      }
      if (op === "extend-expiry") {
        const expiry = String(body.expiry || "").trim();
        if (!isValidExpiryDate(expiry)) {
          return reply(res, 400, { error: "expiry 必须是有效 YYYYMMDD" });
        }
        if (!signNewCode) {
          return reply(res, 503, { error: "签发服务未配置" });
        }
        try {
          const signed = await signNewCode(deviceId, expiry);
          if (!signed || !signed.code) {
            return reply(res, 503, { error: "签发服务未配置" });
          }
          const failure = durableWrite(() => {
            record.activation = signed.code;
            record.expiry = expiry;
          });
          if (failure) return reply(res, failure.status, failure.body);
          adminAudit("extend-expiry", { device_id: deviceId, expiry }, "ok");
          return reply(res, 200, { ...deviceView(deviceId, record), new_code: signed.code });
        } catch (err) {
          adminAudit("extend-expiry", { device_id: deviceId, expiry }, "signer-error");
          return reply(res, 503, { error: "签发服务不可用" });
        }
      }
      if (op === "revoke" || op === "unrevoke") {
        const revoked = op === "revoke";
        const failure = durableWrite(() => {
          record.revoked = revoked;
          if (revoked) record.revoked_at = Date.now();
          else delete record.revoked_at;
        });
        if (failure) return reply(res, failure.status, failure.body);
        adminAudit(op, { device_id: deviceId }, revoked ? "revoked" : "unrevoked");
        return reply(res, 200, deviceView(deviceId, record));
      }
      if (op === "note") {
        const note = String(body.note || "").slice(0, 500);
        const failure = durableWrite(() => { record.note = note; });
        if (failure) return reply(res, failure.status, failure.body);
        adminAudit("note", { device_id: deviceId, note }, "ok");
        return reply(res, 200, deviceView(deviceId, record));
      }
    }
    // 9. POST /v1/admin/codes/issue
    if (route === "/v1/admin/codes/issue" && req.method === "POST") {
      const body = await readJsonBody(req);
      if (body.error) return reply(res, 400, { error: body.error });
      const deviceId = String(body.device_id || "").trim();
      const expiry = String(body.expiry || "").trim();
      if (!deviceId || !isValidExpiryDate(expiry)) {
        return reply(res, 400, { error: "device_id 与有效 expiry(YYYYMMDD) 必填" });
      }
      if (devices[deviceId]) {
        return reply(res, 409, { error: "设备已存在" });
      }
      if (!signNewCode) {
        return reply(res, 503, { error: "签发服务未配置" });
      }
      try {
        const signed = await signNewCode(deviceId, expiry);
        if (!signed || !signed.code) {
          return reply(res, 503, { error: "签发服务未配置" });
        }
        const failure = durableWrite(() => {
          devices[deviceId] = {
            activation: signed.code,
            expiry,
            used: 0,
            last_seen: Date.now(),
            created_at: Date.now(),
          };
        });
        if (failure) return reply(res, failure.status, failure.body);
        adminAudit("issue", { device_id: deviceId, expiry }, "ok");
        return reply(res, 200, { code: signed.code, device_id: deviceId, expiry });
      } catch (err) {
        adminAudit("issue", { device_id: deviceId, expiry }, "signer-error");
        return reply(res, 503, { error: "签发服务不可用" });
      }
    }
    return reply(res, 404, { error: "Not found" });
  }

  function handle(req, res) {
    const doHandle = async () => {
      // R6 fail-stop gate: once storage is unhealthy every request returns 503
      // before any read/write — the service never resumes normal writes.
      if (storageUnhealthy) {
        return reply(res, 503, { error: "存储异常，服务暂不可用" });
      }
      const route = req.url.split("?")[0];
      const isAi = route === "/v1/ai";
      const isRebind = enableRebind && route === "/v1/ai/rebind";
      const isAdmin = route.startsWith("/v1/admin/");
      const isAdminStatic = route.startsWith("/admin/") || route === "/admin";
      // Admin API：全部 /v1/admin/* 仅当配置 adminSecret 时存在（fail-closed），
      // 仅 loopback + Bearer 常量时间比较；非 GET 变更一律写审计日志。
      if (isAdmin) {
        if (!adminSecret) {
          return reply(res, 404, { error: "Not found" });
        }
        if (!isLoopback(req)) {
          return reply(res, 403, { error: "Forbidden" });
        }
        const token = bearerToken(req);
        if (!token || !constantTimeEqual(token, adminSecret)) {
          return reply(res, 401, { error: "未授权" }, { "WWW-Authenticate": "Bearer" });
        }
        return handleAdmin(req, res, route);
      }
      // Admin 静态 SPA（ai-server/admin/）：纯静态无秘密，仅 loopback 绑定天然受限。
      if (isAdminStatic) {
        if (!isLoopback(req)) {
          return reply(res, 403, { error: "Forbidden" });
        }
        if (req.method !== "GET" && req.method !== "HEAD") {
          return reply(res, 405, { error: "method_not_allowed" });
        }
        adminStatic(req, res, route === "/admin" ? "/" : route.slice("/admin".length));
        return;
      }
      if (req.method !== "POST" || (!isAi && !isRebind)) {
        return reply(res, 404, { error: "Not found" });
      }
      // Bounded body: stream-accumulate Buffers up to maxBodyBytes, then stop
      // reading and reject with 413 so an oversized request cannot grow memory
      // without bound (matches the "resource usage" goal of this release).
      // Buffers are accumulated, never concatenated as strings (R5.2): raw
      // string concatenation would corrupt multi-byte UTF-8 split across
      // chunk boundaries. Decode exactly once, after the full body is in hand.
      const chunks = [];
      let totalBytes = 0;
      let tooLarge = false;
      for await (const chunk of req) {
        totalBytes += chunk.length;
        if (totalBytes > maxBodyBytes) {
          tooLarge = true;
          break; // stop reading the oversized body
        }
        chunks.push(chunk);
      }
      if (tooLarge) {
        res.writeHead(413, { "Content-Type": "application/json; charset=utf-8", "Connection": "close" });
        res.end(JSON.stringify({ error: `请求体过大（超过 ${maxBodyBytes} 字节上限）` }));
        return;
      }
      const raw = Buffer.concat(chunks).toString("utf8");
      let body;
      try { body = JSON.parse(raw); } catch { return reply(res, 400, { error: "无效的 JSON" }); }

      if (isRebind) {
        const { activationCode, oldDeviceId, newDeviceId } = body || {};
        if (!activationCode || !oldDeviceId || !newDeviceId) {
          return reply(res, 400, { error: "缺少 activationCode / oldDeviceId / newDeviceId" });
        }
        if ([activationCode, oldDeviceId, newDeviceId].some((value) => typeof value !== "string" || !value.trim() || value.length > 4096)) {
          return reply(res, 400, { error: "activationCode / oldDeviceId / newDeviceId 格式无效" });
        }
        const activation = activationCode.trim();
        const ip = clientIp(req);
        const now = Date.now();
        const ipBlocked = rateLimited(rebindIpAttempts, fingerprint(ip), rebindIpLimit, now);
        const activationBlocked = rateLimited(rebindActivationAttempts, fingerprint(activation), rebindActivationLimit, now);
        if (ipBlocked || activationBlocked) {
          auditRebind(oldDeviceId.trim(), newDeviceId.trim(), activation, ip, "rate-limited");
          return reply(res, 429, { error: "请求过于频繁" }, { "Retry-After": String(Math.ceil(rebindWindowMs / 1000)) });
        }
        const result = await rebind(activation, oldDeviceId.trim(), newDeviceId.trim(), ip);
        return reply(res, result.status, result.body);
      }

      const { activationCode, deviceId, prompt, size = "1024x1024", image } = body || {};
      if (!activationCode || !deviceId || !prompt) {
        return reply(res, 400, { error: "缺少 activationCode / deviceId / prompt" });
      }
      // R5.4: validate the reference image BEFORE consume. A malformed
      // reference is a client error (400) and must not create a device record
      // nor touch the disk — validate first, consume only after.
      let reference = null;
      if (image != null) {
        try { reference = parseImageData(image); }
        catch (err) { return reply(res, 400, { error: err.message }); }
      }
      const check = (verifyActivationImpl || verifyActivation)(activationCode, deviceId);
      if (!check.ok) return reply(res, 403, { error: check.reason });

      if (rebinding.has(deviceId)) {
        return reply(res, 409, { error: "设备正在换绑，请稍后重试" });
      }

      const use = consume(deviceId, String(activationCode).trim(), check.expiry);
      if (use.status) return reply(res, use.status, use.body);  // R6: persist failure response (500/503)
      if (!use.allowed) return reply(res, 403, { error: "该激活码次数已用完", used: use.used, remaining: 0 });

      beginInflight(deviceId);
      try {
        const imageBase64 = await draw(apiKey, prompt, size, reference);
        res.writeHead(200, { "Content-Type": "application/json; charset=utf-8", "X-ZENCHE-Remaining": String(use.remaining) });
        res.end(JSON.stringify({ data: [{ b64_json: imageBase64 }] }));
      } catch (err) {
        // Mirror production rollback: consumed count refunded on upstream failure.
        // used-1 takes its own full snapshot and goes through the same
        // persistDurably + recoverPersistFailure path as the consume commit (R6).
        console.error("[ai-server] 上游转发失败:", err.message);
        const rollbackDeviceId = resolveMigrationTail(devices, deviceId);
        if (devices[rollbackDeviceId]) {
          const failure = durableWrite(() => { devices[rollbackDeviceId].used -= 1; });
          if (failure) return reply(res, failure.status, failure.body);
        }
        reply(res, 502, { error: "AI 服务暂时不可用，请稍后重试" });
      } finally {
        endInflight(deviceId);
      }
    };
    doHandle().catch((err) => {
      console.error("[ai-server] unhandled:", err.message);
      if (!res.headersSent) reply(res, 500, { error: "服务器内部错误" });
      else res.end();
    });
  }

  const server = http.createServer(handle);

  // Admin 启用时：进程内每日快照定时器（UTC 日切点对齐；写失败仅 console.error
  // 不触发 fail-stop）。启动时若当日缺行即补。
  if (adminSecret) {
    ensureSnapshotFile();
    const snapshotTimer = setInterval(() => {
      ensureSnapshotFile();
    }, 6 * 60 * 60 * 1000); // 每 6h 检查一次（覆盖 UTC 日边界，幂等补行）
    if (snapshotTimer.unref) snapshotTimer.unref();
  }

  // Test helpers (not part of production surface)
  const snapshot = () => ({ devices: JSON.parse(JSON.stringify(devices)), dbFile: DB_FILE });

  return new Promise((resolve) => {
    server.listen(port, host, () => resolve({
      server,
      port: server.address().port,
      host: server.address().address,
      dbFile: DB_FILE,
      snapshot,
      persistDurably,
      recoverPersistFailure,
      isStorageUnhealthy: () => storageUnhealthy,
      concurrencySnapshot: () => ({ inflight: new Map(inflight), rebinding: new Set(rebinding) }),
      handle,
    }));
  });
}

// Run as main: production behavior remains secret-free. Rebind is opt-in and
// calls the loopback redeem signer; no private key enters this process.
if (import.meta.url === `file://${process.argv[1]}`) {
  const apiKey = process.env.ZENCHE_AI_API_KEY || "";
  if (!apiKey) {
    console.error("[ai-server] 错误：未设置 ZENCHE_AI_API_KEY 环境变量。");
    process.exit(1);
  }
  const pem = process.env.ZENCHE_AI_PUBLIC_KEY_FILE
    ? fs.readFileSync(process.env.ZENCHE_AI_PUBLIC_KEY_FILE, "utf8")
    : null;
  if (!pem) { console.error("[ai-server] set ZENCHE_AI_PUBLIC_KEY_FILE (module embeds no key)"); process.exit(1); }
  const { server } = await createApp({
    port: Number(process.env.ZENCHE_AI_PORT || 8787),
    host: process.env.ZENCHE_AI_HOST || "127.0.0.1", // loopback by default; public bind requires an explicit ZENCHE_AI_HOST (R5.5)
    apiKey,
    endpoint: process.env.ZENCHE_AI_ENDPOINT || "https://grsai.dakka.com.cn/v1/api/generate",
    maxUsage: Number(process.env.ZENCHE_AI_MAX_USAGE || 100),
    publicKeyPem: pem,
    dbDir: process.env.ZENCHE_AI_DB_DIR,
    enableRebind: process.env.ZENCHE_AI_ENABLE_REBIND === "1",
    redeemEndpoint: process.env.ZENCHE_REDEEM_ENDPOINT || "http://127.0.0.1:8899/issue-migrated",
    rebindSecret: process.env.ZENCHE_REBIND_SECRET || "",
    adminSecret: process.env.ZENCHE_AI_ADMIN_SECRET || "", // enables loopback-only /v1/admin/stats
    // R6 fail-stop policy: on unrecoverable storage, shut the service down so
    // the supervisor (nohup wrapper / systemd) restarts it for operator review.
    onUnrecoverableStorage: (err) => {
      console.error("[ai-server] 存储不可恢复，终止服务:", err.message);
      try { server.close(); } catch { /* already closed */ }
      process.exit(1);
    },
  });
  server.on("error", (e) => { console.error("[ai-server] server error:", e.message); process.exit(1); });
  console.log(`[ai-server] listening on ${server.address().address}:${server.address().port}`);
}
