// ZENCHE redeem signer — standalone loopback service for the device-rebind
// protocol (1.5.2). Issues a fresh ZENCHE-AI code bound to a NEW device code
// using the RSA private key that the main ai-server never sees.
//
// Scope: `POST /issue-migrated`, Bearer shared-secret auth (constant-time),
// bounded request bodies (16 KiB), strict yyyyMMdd expiry semantics, and an
// RSA-SHA256 signer producing `ZENCHE-AI-<base64>-<expiry>`.
//
// Fail-closed: without a configured shared secret AND a usable private key
// the factory throws before any socket is opened. The private key is only
// ever injected (factory argument) or read from an environment file path;
// this repository contains no real key or secret. Errors never echo the
// secret, key material, file paths, or request bodies; audit logs carry
// fingerprints only.
import http from "node:http";
import crypto from "node:crypto";
import fs from "node:fs";

// Strict yyyyMMdd validity, mirroring ai-server/app.mjs semantics: rejects
// impossible dates (20260231) that JS Date would silently normalize, and
// treats the expiry day as valid for the whole day (expired only when
// strictly before today's start).
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

// Constant-time comparison of two strings: both sides are hashed first so
// timingSafeEqual always sees equal-length buffers and content length never
// leaks through comparison timing (a SHA-256 digest leaks nothing usable).
function constantTimeEqual(a, b) {
  const ha = crypto.createHash("sha256").update(String(a), "utf8").digest();
  const hb = crypto.createHash("sha256").update(String(b), "utf8").digest();
  return crypto.timingSafeEqual(ha, hb);
}

// Audit fingerprint: same style as ai-server auditRebind (sha256, 12 hex).
function fingerprint(value) {
  return crypto.createHash("sha256").update(String(value || ""), "utf8").digest("hex").slice(0, 12);
}

// A device code is platform-generated (UUID/hex-like). The signed payload is
// `${newDeviceId}:${expiry}:${SUFFIX}`, so a `:` inside the id would make the
// protocol's own separator ambiguous; control characters must never reach
// logs or HTTP framing. 4096 matches the ai-server rebind field cap.
function isValidDeviceId(value) {
  if (typeof value !== "string") return false;
  const trimmed = value.trim();
  if (!trimmed || trimmed.length > 4096) return false;
  if (/[\x00-\x1F\x7F:]/.test(trimmed)) return false;
  return true;
}

// Parse the Authorization header as `Bearer <token>`. Any other scheme or
// malformed header is treated as absent (401) — never echoed back.
function bearerToken(req) {
  const header = req.headers.authorization;
  if (typeof header !== "string") return null;
  const match = /^Bearer\s+(\S+)$/i.exec(header);
  return match ? match[1] : null;
}

export function createRedeemServer(opts = {}) {
  const {
    secret = "", // shared bearer secret; must be configured (fail-closed)
    privateKeyPem = null, // injected RSA private key (tests / operator tooling)
    privateKeyFile = null, // env-provided path to the PEM file (production)
    port = 0, // 0 => OS-assigned random port (tests); production passes 8899
    host = "127.0.0.1", // loopback-only default; public binding is a production decision
    maxBodyBytes = 16 * 1024, // 16 KiB request-body cap
    logImpl = (line) => console.log(line),
  } = opts;

  // ---- fail-closed configuration ----
  if (!secret) throw new Error("redeem signer requires a shared secret (ZENCHE_REBIND_SECRET)");
  let pem = privateKeyPem;
  if (!pem && privateKeyFile) {
    pem = fs.readFileSync(privateKeyFile, "utf8"); // throws: unreadable key file = refuse to start
  }
  if (!pem) throw new Error("redeem signer requires a private key (injected or ZENCHE_REBIND_KEY_FILE)");
  let privateKey;
  try {
    privateKey = crypto.createPrivateKey(pem);
    // Startup probe: refuse to serve if the key cannot actually sign.
    crypto.sign("RSA-SHA256", Buffer.from("redeem-startup-probe"), privateKey);
  } catch {
    throw new Error("redeem signer private key is invalid or unusable");
  }
  // Never keep the PEM text around after the key object is derived.
  pem = null;

  function signCode(newDeviceId, expiry) {
    const payload = `${newDeviceId}:${expiry}:a1b2c3d4e5f6`;
    const signature = crypto.sign("RSA-SHA256", Buffer.from(payload, "utf8"), privateKey);
    return `ZENCHE-AI-${signature.toString("base64")}-${expiry}`;
  }

  function audit(newDeviceId, ip, result) {
    try {
      logImpl(`[ZENCHE-REDEEM] device=${fingerprint(newDeviceId)} ip=${fingerprint(ip)} result=${result} ts=${new Date().toISOString()}`);
    } catch (err) {
      console.error("[ZENCHE-REDEEM] audit log write failed", err);
    }
  }

  function reply(res, status, obj, headers = {}) {
    res.writeHead(status, { "Content-Type": "application/json; charset=utf-8", ...headers });
    res.end(JSON.stringify(obj));
  }

  function handle(req, res) {
    const doHandle = async () => {
      const route = req.url.split("?")[0];
      const ip = req.socket.remoteAddress || "unknown";
      if (req.method !== "POST" || route !== "/issue-migrated") {
        audit("", ip, "not-found");
        return reply(res, 404, { error: "Not found" });
      }

      // Constant-time bearer check BEFORE reading the body: an unauthenticated
      // oversized body must not be read, and timing must not reveal the secret.
      // We respond without consuming the request, so close the connection
      // explicitly (Node would destroy it anyway once the body is unread).
      const token = bearerToken(req);
      if (!token || !constantTimeEqual(token, secret)) {
        audit("", ip, "unauthorized");
        return reply(res, 401, { error: "未授权" }, { "Connection": "close", "WWW-Authenticate": "Bearer" });
      }

      // Declared Content-Length lets us reject an oversized body immediately.
      const declared = Number(req.headers["content-length"]);
      if (Number.isFinite(declared) && declared > maxBodyBytes) {
        audit("", ip, "too-large");
        return reply(res, 413, { error: "请求体过大" }, { "Connection": "close" });
      }

      // Bounded body: accumulate Buffers (never string-concat, so multi-byte
      // UTF-8 split across chunk boundaries stays intact), stop reading and
      // reject 413 the moment the cap is exceeded.
      const chunks = [];
      let totalBytes = 0;
      let tooLarge = false;
      for await (const chunk of req) {
        totalBytes += chunk.length;
        if (totalBytes > maxBodyBytes) {
          tooLarge = true;
          break;
        }
        chunks.push(chunk);
      }
      if (tooLarge) {
        audit("", ip, "too-large");
        return reply(res, 413, { error: "请求体过大" }, { "Connection": "close" });
      }

      let body;
      try {
        body = JSON.parse(Buffer.concat(chunks).toString("utf8"));
      } catch {
        audit("", ip, "bad-request");
        return reply(res, 400, { error: "无效的 JSON" });
      }

      const { newDeviceId, expiry } = body || {};
      if (!isValidDeviceId(newDeviceId)) {
        audit("", ip, "bad-request");
        return reply(res, 400, { error: "newDeviceId 无效" });
      }
      if (typeof expiry !== "string" || !isValidExpiryDate(expiry)) {
        audit(newDeviceId, ip, "bad-request");
        return reply(res, 400, { error: "expiry 格式无效" });
      }
      const expDate = new Date(Number(expiry.slice(0, 4)), Number(expiry.slice(4, 6)) - 1, Number(expiry.slice(6, 8)));
      if (expDate < startOfToday()) {
        audit(newDeviceId, ip, "expired");
        return reply(res, 400, { error: "expiry 已过期" });
      }

      const code = signCode(newDeviceId.trim(), expiry);
      audit(newDeviceId.trim(), ip, "ok");
      return reply(res, 200, { code });
    };
    doHandle().catch((err) => {
      console.error("[ZENCHE-REDEEM] unhandled:", err.message);
      if (!res.headersSent) reply(res, 500, { error: "服务器内部错误" });
      else res.end();
    });
  }

  const server = http.createServer(handle);

  return new Promise((resolve) => {
    server.listen(port, host, () => resolve({
      server,
      port: server.address().port,
      host: server.address().address,
      signCode,
    }));
  });
}

// Run as main: production behavior reads the shared secret and the private
// key path from the environment only. Missing configuration exits non-zero
// (fail-closed); nothing is ever embedded in this file.
if (import.meta.url === `file://${process.argv[1]}`) {
  const secret = process.env.ZENCHE_REBIND_SECRET || "";
  const keyFile = process.env.ZENCHE_REBIND_KEY_FILE || "";
  if (!secret) {
    console.error("[ZENCHE-REDEEM] 错误：未设置 ZENCHE_REBIND_SECRET 环境变量。");
    process.exit(1);
  }
  if (!keyFile) {
    console.error("[ZENCHE-REDEEM] 错误：未设置 ZENCHE_REBIND_KEY_FILE 环境变量。");
    process.exit(1);
  }
  const { server } = await createRedeemServer({
    secret,
    privateKeyFile: keyFile,
    port: Number(process.env.ZENCHE_REDEEM_PORT || 8899),
    host: process.env.ZENCHE_REDEEM_HOST || "127.0.0.1", // loopback default; keep behind the TLS reverse proxy
  });
  server.on("error", (e) => { console.error("[ZENCHE-REDEEM] server error:", e.message); process.exit(1); });
  console.log(`[ZENCHE-REDEEM] listening on ${server.address().address}:${server.address().port}`);
}
