// ZENCHE auth — 邮箱账号系统（W13-a）。零依赖模块：scrypt 口令散列、
// 30 天滚动 Bearer session、6 位邮箱验证码（10min TTL、5 次尝试锁码）、
// 每邮箱/每 IP 限流、管理台账号控制、以及手写 minimal SMTP 客户端
// （465 隐式 TLS / 587 STARTTLS，AUTH LOGIN）。
//
// 存储：accounts.json / sessions.json / email_codes.json 落 data 目录，
// 沿用 devices.json 同款原子耐久写（tmp 0600 + fchmod + fsync + rename +
// 目录 fsync）。本模块不内嵌任何秘密：SMTP 凭据只来自配置，邮件服务
// 未配置时 fail-closed（email-code 503、register 无码一律 400），绝不
// fail-open 免验证。
import crypto from "node:crypto";
import net from "node:net";
import tls from "node:tls";
import fs from "node:fs";
import path from "node:path";

// ---------- scrypt ----------
// 存储格式：scrypt$N$r$p$keylen$saltHex$hashHex —— 参数随记录保存，参数
// 演进不破坏老记录；验证时按记录自身参数重算（Node scryptSync 支持任意 N）。
export const SCRYPT_DEFAULTS = { N: 16384, r: 8, p: 1, keylen: 32 };

export function scryptRaw(password, saltBytes, keylen = SCRYPT_DEFAULTS.keylen,
  N = SCRYPT_DEFAULTS.N, r = SCRYPT_DEFAULTS.r, p = SCRYPT_DEFAULTS.p) {
  return crypto.scryptSync(String(password), saltBytes, keylen, { N, r, p });
}

export function hashPassword(password) {
  const salt = crypto.randomBytes(16);
  const hash = scryptRaw(password, salt, SCRYPT_DEFAULTS.keylen,
    SCRYPT_DEFAULTS.N, SCRYPT_DEFAULTS.r, SCRYPT_DEFAULTS.p);
  return `scrypt$${SCRYPT_DEFAULTS.N}$${SCRYPT_DEFAULTS.r}$${SCRYPT_DEFAULTS.p}`
    + `$${SCRYPT_DEFAULTS.keylen}$${salt.toString("hex")}$${hash.toString("hex")}`;
}

export function verifyPassword(password, stored) {
  if (typeof stored !== "string") return false;
  const parts = stored.split("$");
  if (parts.length !== 7 || parts[0] !== "scrypt") return false;
  const [, nStr, rStr, pStr, keylenStr, saltHex, hashHex] = parts;
  const N = Number(nStr), r = Number(rStr), p = Number(pStr), keylen = Number(keylenStr);
  if (![N, r, p, keylen].every(Number.isInteger) || N < 2 || r < 1 || p < 1 || keylen < 1) return false;
  if (!/^[0-9a-f]+$/.test(saltHex) || !/^[0-9a-f]+$/.test(hashHex)) return false;
  const salt = Buffer.from(saltHex, "hex");
  const expected = Buffer.from(hashHex, "hex");
  if (expected.length !== keylen) return false;
  let actual;
  try { actual = scryptRaw(password, salt, keylen, N, r, p); } catch { return false; }
  return crypto.timingSafeEqual(actual, expected);
}

// ---------- 原子耐久写（devices.json 同款三态写法） ----------

function tag(err, meta) {
  if (err && typeof err === "object") Object.assign(err, meta);
  return err;
}

export function makeDurableFile(F, file) {
  const dir = path.dirname(file);

  function read() {
    if (!F.existsSync(file)) return null;
    const raw = F.readFileSync(file, "utf8");
    try { return JSON.parse(raw); }
    catch (err) { throw new Error(`corrupt ${path.basename(file)}: ${err.message}`); }
  }

  function write(data) {
    F.mkdirSync(dir, { recursive: true });
    const tmp = file + ".tmp";
    let fd;
    try {
      fd = F.openSync(tmp, "w", 0o600);
      F.fchmodSync(fd, 0o600);
    } catch (err) {
      if (fd !== undefined) { try { F.closeSync(fd); } catch { /* 尽力 */ } }
      throw tag(err, { commitState: "pre-rename", reason: "tmp-open" });
    }
    try {
      F.writeFileSync(fd, data);
      F.fsyncSync(fd);
    } catch (err) {
      try { F.closeSync(fd); } catch { /* 尽力 */ }
      throw tag(err, { commitState: "pre-rename", reason: "write-or-fsync" });
    }
    try {
      F.closeSync(fd);
    } catch (err) {
      throw tag(err, { commitState: "pre-rename", reason: "file-close" });
    }
    try {
      F.renameSync(tmp, file);
    } catch (err) {
      throw tag(err, { commitState: "pre-rename", reason: "rename" });
    }
    let dfd;
    try {
      dfd = F.openSync(dir, "r");
    } catch (err) {
      throw tag(err, { commitState: "renamed-unconfirmed", reason: "dir-open" });
    }
    try {
      F.fsyncSync(dfd);
    } catch (err) {
      try { F.closeSync(dfd); } catch { /* 尽力 */ }
      throw tag(err, { commitState: "renamed-unconfirmed", reason: "dir-fsync" });
    }
    try {
      F.closeSync(dfd);
    } catch (err) {
      throw tag(err, { commitState: "durable", reason: "dir-close" });
    }
    return { commitState: "durable" };
  }

  return { read, write, file };
}

// ---------- minimal SMTP 客户端（465 隐式 TLS / 587 STARTTLS + AUTH LOGIN） ----------

class SmtpSession {
  constructor(socket, timeoutMs) {
    this.socket = socket;
    this.timeoutMs = timeoutMs;
    this.buffer = "";
  }

  // 解析缓冲中的完整 SMTP 响应（多行以 "250-..." 开头，终止行 "250 ..."）。
  // 未完整返回 null；畸形行抛错（协议损坏，无修复意义）。
  tryParse() {
    const parts = this.buffer.split("\r\n");
    const tail = parts.pop();
    const lines = [];
    let code = null;
    for (const line of parts) {
      const m = /^(\d{3})([ -])(.*)$/.exec(line);
      if (!m) throw new Error("SMTP 响应格式无效");
      lines.push(line);
      code = Number(m[1]);
      if (m[2] === " ") {
        this.buffer = "";
        return { code, lines };
      }
    }
    void tail;
    return null;
  }

  readResponse() {
    return new Promise((resolve, reject) => {
      const onData = (chunk) => {
        this.buffer += chunk.toString("utf8");
        let parsed;
        try { parsed = this.tryParse(); } catch (err) { cleanup(); reject(err); return; }
        if (parsed) { cleanup(); resolve(parsed); }
      };
      const onError = (err) => { cleanup(); reject(err); };
      const onTimeout = () => { cleanup(); this.socket.destroy(); reject(new Error("SMTP 超时")); };
      const cleanup = () => {
        this.socket.off("data", onData);
        this.socket.off("error", onError);
        this.socket.off("timeout", onTimeout);
        this.socket.setTimeout(0);
      };
      this.socket.on("data", onData);
      this.socket.on("error", onError);
      this.socket.on("timeout", onTimeout);
      this.socket.setTimeout(this.timeoutMs);
      let parsed;
      try { parsed = this.tryParse(); } catch (err) { cleanup(); reject(err); return; }
      if (parsed) { cleanup(); resolve(parsed); }
    });
  }

  async sendCommand(cmd) {
    this.socket.write(cmd + "\r\n");
    return this.readResponse();
  }
}

function connectSocket(host, port, implicitTls, timeoutMs) {
  return new Promise((resolve, reject) => {
    const socket = implicitTls
      ? tls.connect({ host, port, rejectUnauthorized: true })
      : net.connect({ host, port });
    let done = false;
    const timer = setTimeout(() => {
      if (!done) { done = true; socket.destroy(); reject(new Error("SMTP 连接超时")); }
    }, timeoutMs);
    socket.once(implicitTls ? "secureConnect" : "connect", () => {
      if (done) return; done = true; clearTimeout(timer); resolve(socket);
    });
    socket.once("error", (err) => {
      if (done) return; done = true; clearTimeout(timer); reject(err);
    });
  });
}

function upgradeStartTls(socket, host, timeoutMs) {
  return new Promise((resolve, reject) => {
    const upgraded = tls.connect({ socket, host, rejectUnauthorized: true });
    let done = false;
    const timer = setTimeout(() => {
      if (!done) { done = true; upgraded.destroy(); reject(new Error("STARTTLS 升级超时")); }
    }, timeoutMs);
    upgraded.once("secureConnect", () => { if (done) return; done = true; clearTimeout(timer); resolve(upgraded); });
    upgraded.once("error", (err) => { if (done) return; done = true; clearTimeout(timer); reject(err); });
  });
}

// SMTP 正文逐行 dot-stuffing（行首 "." 前补 "."，防止被当作 DATA 结束符）。
function dotStuff(text) {
  return String(text).replace(/^\./gm, "..");
}

function encodeHeader(value) {
  return /^[\x00-\x7F]*$/.test(value) ? value : `=?UTF-8?B?${Buffer.from(value, "utf8").toString("base64")}?=`;
}

export function buildVerificationMail(code, minutes = 10) {
  const subject = "【帧澈 ZENCHE】注册验证码";
  const text = [
    "帧澈 ZENCHE 账号注册验证码",
    "",
    "您好：",
    "",
    `您正在注册帧澈 ZENCHE 账号，本次验证码为：${code}`,
    "",
    `验证码 ${minutes} 分钟内有效，请勿泄露给他人。如非本人操作，请忽略此邮件。`,
    "",
    "—— 帧澈 ZENCHE 团队",
  ].join("\n");
  const html = `<!DOCTYPE html><html><body style="margin:0;padding:24px;background:#f5f5f7;font-family:-apple-system,'Segoe UI',Roboto,sans-serif">
<div style="max-width:480px;margin:0 auto;background:#ffffff;border-radius:12px;padding:32px;border:1px solid #e5e5e7">
<div style="font-size:18px;font-weight:600;color:#1c1c1e">帧澈 ZENCHE</div>
<p style="color:#48484a;margin:20px 0 8px">您好，您正在注册帧澈 ZENCHE 账号，本次验证码为：</p>
<div style="font-size:32px;font-weight:700;letter-spacing:8px;color:#0a5cff;margin:16px 0;text-align:center">${code}</div>
<p style="color:#86868b;font-size:13px;line-height:1.6">验证码 ${minutes} 分钟内有效，请勿泄露给他人。如非本人操作，请忽略此邮件。</p>
<p style="color:#86868b;font-size:12px;margin-top:24px">—— 帧澈 ZENCHE 团队</p>
</div></body></html>`;
  return { subject, text, html };
}

export function createSmtpClient(config = {}) {
  const host = String(config.host || "").trim();
  const port = Number(config.port) || 465;
  const user = String(config.user || "");
  const password = String(config.password || "");
  const from = String(config.from || "").trim();
  const timeoutMs = Number(config.timeoutMs) || 10_000;
  const isConfigured = !!(host && user && password && from);

  async function sendMail({ to, subject, text, html }) {
    if (!isConfigured) throw new Error("SMTP 未配置");
    const implicitTls = port === 465;
    let socket = await connectSocket(host, port, implicitTls, timeoutMs);
    try {
      const session = new SmtpSession(socket, timeoutMs);
      const greeting = await session.readResponse();
      if (greeting.code !== 220) throw new Error(`SMTP 服务器拒绝连接: ${greeting.code}`);
      let ehlo = await session.sendCommand(`EHLO localhost`);
      if (ehlo.code !== 250) throw new Error(`EHLO 失败: ${ehlo.code}`);
      if (!implicitTls) {
        const caps = ehlo.lines.join("\n").toUpperCase();
        if (!caps.includes("STARTTLS")) throw new Error("SMTP 服务器不支持 STARTTLS");
        const st = await session.sendCommand("STARTTLS");
        if (st.code !== 220) throw new Error(`STARTTLS 失败: ${st.code}`);
        socket = await upgradeStartTls(socket, host, timeoutMs);
        session.socket = socket;
        session.buffer = "";
        ehlo = await session.sendCommand(`EHLO localhost`);
        if (ehlo.code !== 250) throw new Error(`EHLO(加密后) 失败: ${ehlo.code}`);
      }
      const auth = await session.sendCommand("AUTH LOGIN");
      if (auth.code !== 334) throw new Error(`AUTH LOGIN 不被支持: ${auth.code}`);
      const u = await session.sendCommand(Buffer.from(user, "utf8").toString("base64"));
      if (u.code !== 334) throw new Error("AUTH LOGIN 用户名被拒");
      const p = await session.sendCommand(Buffer.from(password, "utf8").toString("base64"));
      if (p.code !== 235) throw new Error("AUTH LOGIN 认证失败");

      const rcp = await session.sendCommand(`MAIL FROM:<${from}>`);
      if (rcp.code !== 250) throw new Error(`MAIL FROM 被拒: ${rcp.code}`);
      const rct = await session.sendCommand(`RCPT TO:<${to}>`);
      if (rct.code !== 250 && rct.code !== 251) throw new Error(`RCPT TO 被拒: ${rct.code}`);
      const data = await session.sendCommand("DATA");
      if (data.code !== 354) throw new Error(`DATA 被拒: ${data.code}`);
      const boundary = "zenche-mail-boundary";
      const textB64 = Buffer.from(text, "utf8").toString("base64");
      const htmlB64 = Buffer.from(html, "utf8").toString("base64");
      const payload = [
        `From: ${from}`,
        `To: <${to}>`,
        `Subject: ${encodeHeader(subject)}`,
        "MIME-Version: 1.0",
        `Content-Type: multipart/alternative; boundary="${boundary}"`,
        "",
        `--${boundary}`,
        "Content-Type: text/plain; charset=utf-8",
        "Content-Transfer-Encoding: base64",
        "",
        textB64,
        `--${boundary}`,
        "Content-Type: text/html; charset=utf-8",
        "Content-Transfer-Encoding: base64",
        "",
        htmlB64,
        `--${boundary}--`,
      ].join("\r\n");
      session.socket.write(dotStuff(payload) + "\r\n.\r\n");
      const done = await session.readResponse();
      if (done.code !== 250) throw new Error(`邮件被拒: ${done.code}`);
      try { await session.sendCommand("QUIT"); } catch { /* 退出失败不致命 */ }
      return { ok: true };
    } finally {
      socket.destroy();
    }
  }

  return { sendMail, isConfigured };
}

// ---------- 认证系统工厂 ----------

const SESSION_TTL_MS = 30 * 24 * 60 * 60 * 1000;   // 30 天滚动过期
const CODE_TTL_MS = 10 * 60 * 1000;                // 验证码 10min
const CODE_MAX_ATTEMPTS = 5;                       // 验证码 5 次尝试锁码
const LOGIN_FAIL_LIMIT = 5;                        // 同邮箱 5 次失败
const LOGIN_LOCK_MS = 15 * 60 * 1000;              // 锁 15min
const EMAIL_CODE_MIN_MS = 60 * 1000;               // 同邮箱 1/min
const IP_CODE_HOUR_LIMIT = 10;                     // 同 IP 10/hour（发码）
const IP_AUTH_HOUR_LIMIT = 20;                     // 同 IP 20/hour（注册/登录）
const LIMITER_MAX_KEYS = 10_000;
const MAX_PASSWORD_LEN = 128;

function normalizeEmail(raw) {
  if (typeof raw !== "string") return null;
  const email = raw.trim().toLowerCase();
  if (!email || email.length > 254) return null;
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(email)) return null;
  return email;
}

export function createAuthSystem({
  dbDir,
  F = fs,
  clock = () => Date.now(),
  smtpSendImpl = null,       // async ({to,subject,text,html}) => void；null = 邮件服务未配置
  adminAudit = () => {},     // (op, params, result) 与 ai-server adminAudit 同风格
  requireEmailCode = true,   // 目标态 1：注册必须验证码（无码 400，禁 fail-open）；
                             // 过渡期显式 0：免码注册、verified=false（email-code 仍 503）
  log = console,
}) {
  const accountsFile = path.join(dbDir, "accounts.json");
  const sessionsFile = path.join(dbDir, "sessions.json");
  const codesFile = path.join(dbDir, "email_codes.json");
  const accountsDf = makeDurableFile(F, accountsFile);
  const sessionsDf = makeDurableFile(F, sessionsFile);
  const codesDf = makeDurableFile(F, codesFile);

  function load(dfile) {
    try { return dfile.read() || {}; }
    catch (err) { throw new Error(`${err.message}`); }
  }

  let accounts = load(accountsDf);  // email -> {email, passwordHash, createdAt, status, verified, bindings}
  let sessions = load(sessionsDf);  // token -> {accountEmail, createdAt, expiresAt}
  let codes = load(codesDf);        // email -> {code, purpose, createdAt, expiresAt, attempts}

  // 限流桶（内存态；键上限防膨胀，语义与 ai-server rateLimited 同款）
  const emailCodeMin = new Map();   // email -> [ts]
  const ipCodeHour = new Map();     // ip -> [ts]
  const ipAuthHour = new Map();     // ip -> [ts]
  const loginFailures = new Map();  // email -> {count, lockedUntil}

  function allow(bucket, key, limit, windowMs, now) {
    let list = bucket.get(key) || [];
    list = list.filter((ts) => now - ts < windowMs);
    if (list.length >= limit) { bucket.set(key, list); return false; }
    if (!bucket.has(key) && bucket.size >= LIMITER_MAX_KEYS) {
      for (const [k, v] of bucket) {
        if (v.every((ts) => now - ts >= windowMs)) bucket.delete(k);
      }
      if (bucket.size >= LIMITER_MAX_KEYS) return false;
    }
    list.push(now);
    bucket.set(key, list);
    return true;
  }

  // 写失败回滚到磁盘态（Node 单线程：变更与写盘之间无 await，磁盘即旧态）
  function rollbackAll() {
    accounts = load(accountsDf);
    sessions = load(sessionsDf);
    codes = load(codesDf);
  }

  function commitOne(map, dfile) {
    try {
      dfile.write(JSON.stringify(map));
      return null;
    } catch (err) {
      log.error("[auth] 持久化失败:", err.message);
      rollbackAll();
      return { status: 500, body: { error: "服务器内部错误" } };
    }
  }
  const commitAccounts = () => commitOne(accounts, accountsDf);
  const commitSessions = () => commitOne(sessions, sessionsDf);
  const commitCodes = () => commitOne(codes, codesDf);

  // 懒清理过期 session/验证码（维护性写盘，失败仅记日志不 fail）
  function pruneExpired(now) {
    let sChanged = false;
    let cChanged = false;
    for (const [token, s] of Object.entries(sessions)) {
      if (Number(s.expiresAt) <= now) { delete sessions[token]; sChanged = true; }
    }
    for (const [email, c] of Object.entries(codes)) {
      if (Number(c.expiresAt) <= now) { delete codes[email]; cChanged = true; }
    }
    if (sChanged) { try { sessionsDf.write(JSON.stringify(sessions)); } catch (err) { log.error("[auth] session 清理写盘失败:", err.message); } }
    if (cChanged) { try { codesDf.write(JSON.stringify(codes)); } catch (err) { log.error("[auth] 验证码清理写盘失败:", err.message); } }
  }

  function issueSession(email, now) {
    const token = crypto.randomBytes(32).toString("hex");
    sessions[token] = { accountEmail: email, createdAt: now, expiresAt: now + SESSION_TTL_MS };
    const fail = commitSessions();
    if (fail) return null;
    return token;
  }

  function findSession(token, now) {
    if (typeof token !== "string" || !token) return null;
    pruneExpired(now);
    const s = sessions[token];
    if (!s) return null;
    const acct = accounts[s.accountEmail];
    if (!acct) { delete sessions[token]; commitSessions(); return null; }
    return { session: s, account: acct };
  }

  function publicAccount(acct) {
    return {
      email: acct.email,
      createdAt: acct.createdAt,
      status: acct.status,
      verified: !!acct.verified,
    };
  }

  function bindingsList(acct) {
    return Object.values(acct.bindings || {});
  }

  // ── 路由操作 ──

  async function emailCode({ email, purpose, ip }) {
    if (!smtpSendImpl) {
      return { status: 503, body: { error: "邮件服务未配置" } };
    }
    if (purpose !== "register") {
      return { status: 400, body: { error: "不支持的用途" } };
    }
    const normalized = normalizeEmail(email);
    if (!normalized) return { status: 400, body: { error: "邮箱格式无效" } };
    const now = clock();
    pruneExpired(now);
    if (!allow(emailCodeMin, normalized, 1, EMAIL_CODE_MIN_MS, now)) {
      return { status: 429, body: { error: "请求过于频繁，请稍后再试" }, headers: { "Retry-After": "60" } };
    }
    if (!allow(ipCodeHour, ip, IP_CODE_HOUR_LIMIT, 60 * 60 * 1000, now)) {
      return { status: 429, body: { error: "请求过于频繁，请稍后再试" }, headers: { "Retry-After": String(Math.ceil((60 * 60 * 1000) / 1000)) } };
    }
    const code = String(crypto.randomInt(0, 1_000_000)).padStart(6, "0");
    codes[normalized] = { code, purpose, createdAt: now, expiresAt: now + CODE_TTL_MS, attempts: 0 };
    const fail = commitCodes();
    if (fail) return fail;
    const mail = buildVerificationMail(code);
    try {
      await smtpSendImpl({ to: normalized, subject: mail.subject, text: mail.text, html: mail.html });
    } catch (err) {
      delete codes[normalized];
      commitCodes();
      log.error("[auth] 验证码邮件发送失败:", err.message);
      return { status: 502, body: { error: "邮件发送失败，请稍后重试" } };
    }
    return { status: 200, body: { message: "验证码已发送" } };
  }

  function register({ email, password, code, ip }) {
    const normalized = normalizeEmail(email);
    if (!normalized) return { status: 400, body: { error: "邮箱格式无效" } };
    if (typeof password !== "string" || password.length < 8) {
      return { status: 400, body: { error: "密码长度至少 8 位" } };
    }
    if (password.length > MAX_PASSWORD_LEN) {
      return { status: 400, body: { error: "密码长度过长" } };
    }
    if (requireEmailCode && (typeof code !== "string" || !/^\d{6}$/.test(code))) {
      return { status: 400, body: { error: "请先获取验证码" } };
    }
    const now = clock();
    if (!allow(ipAuthHour, ip, IP_AUTH_HOUR_LIMIT, 60 * 60 * 1000, now)) {
      return { status: 429, body: { error: "请求过于频繁，请稍后再试" }, headers: { "Retry-After": String(Math.ceil((60 * 60 * 1000) / 1000)) } };
    }
    // 已注册 409 先于码校验：重复注册的邮箱（其验证码可能已消费）应得到
    // 「已注册」而非误导性的「请先获取验证码」（契约：已注册 409）。
    if (accounts[normalized]) {
      return { status: 409, body: { error: "该邮箱已注册" } };
    }
    if (requireEmailCode) {
      // 先查码再 prune：过期码必须明确报「已过期」（prune 先行会把码删掉，
      // 无法区分「没获取过」与「已过期」，且用户拿旧码重试得不到准确提示）。
      const rec = codes[normalized];
      if (rec && Number(rec.expiresAt) <= now) {
        delete codes[normalized];
        commitCodes();
        return { status: 400, body: { error: "验证码已过期，请重新获取" } };
      }
      pruneExpired(now);
      if (!rec || rec.purpose !== "register") {
        return { status: 400, body: { error: "请先获取验证码" } };
      }
      if (rec.code !== code) {
        rec.attempts += 1;
        const locked = rec.attempts >= CODE_MAX_ATTEMPTS;
        if (locked) delete codes[normalized];
        commitCodes();
        return {
          status: 400,
          body: { error: locked ? "验证码错误次数过多，请重新获取" : "验证码错误" },
        };
      }
    } else {
      pruneExpired(now);
    }
    // requireEmailCode=false（过渡期）：免码注册，账号 verified=false，后台可识别。
    accounts[normalized] = {
      email: normalized,
      passwordHash: hashPassword(password),
      createdAt: now,
      status: "active",
      verified: requireEmailCode,
      bindings: {},
    };
    if (codes[normalized]) delete codes[normalized];
    const fail = commitAccounts();
    if (fail) return fail;
    const token = issueSession(normalized, now);
    if (!token) return { status: 500, body: { error: "服务器内部错误" } };
    return { status: 200, body: { token, account: publicAccount(accounts[normalized]) } };
  }

  function login({ email, password, ip }) {
    const normalized = normalizeEmail(email);
    if (!normalized) return { status: 401, body: { error: "邮箱或密码错误" } };
    const now = clock();
    pruneExpired(now);
    if (!allow(ipAuthHour, ip, IP_AUTH_HOUR_LIMIT, 60 * 60 * 1000, now)) {
      return { status: 429, body: { error: "请求过于频繁，请稍后再试" }, headers: { "Retry-After": String(Math.ceil((60 * 60 * 1000) / 1000)) } };
    }
    const lock = loginFailures.get(normalized);
    if (lock && lock.lockedUntil > now) {
      return {
        status: 429,
        body: { error: "尝试次数过多，请稍后再试" },
        headers: { "Retry-After": String(Math.ceil((lock.lockedUntil - now) / 1000)) },
      };
    }
    const acct = accounts[normalized];
    const ok = !!acct && verifyPassword(password, acct.passwordHash);
    if (!ok) {
      const cur = loginFailures.get(normalized) || { count: 0, lockedUntil: 0 };
      cur.count += 1;
      if (cur.count >= LOGIN_FAIL_LIMIT) {
        cur.lockedUntil = now + LOGIN_LOCK_MS;
        cur.count = 0;
      }
      loginFailures.set(normalized, cur);
      if (loginFailures.size > LIMITER_MAX_KEYS) {
        for (const [k, v] of loginFailures) {
          if (v.lockedUntil <= now && v.count === 0) loginFailures.delete(k);
        }
      }
      return { status: 401, body: { error: "邮箱或密码错误" } };
    }
    if (acct.status === "disabled") {
      return { status: 403, body: { error: "账号已禁用" } };
    }
    loginFailures.delete(normalized);
    const token = issueSession(normalized, now);
    if (!token) return { status: 500, body: { error: "服务器内部错误" } };
    return { status: 200, body: { token, account: publicAccount(acct) } };
  }

  function logout(token) {
    if (typeof token !== "string" || !token) {
      return { status: 401, body: { error: "未登录" } };
    }
    // 幂等吊销：token 存在即删（过期/未知 token 也返回 200，客户端本地必清）。
    if (sessions[token]) {
      delete sessions[token];
      const fail = commitSessions();
      if (fail) return fail;
    }
    return { status: 200, body: { message: "已退出登录" } };
  }

  function me(token) {
    if (typeof token !== "string" || !token) {
      return { status: 401, body: { error: "未登录" } };
    }
    const now = clock();
    const found = findSession(token, now);
    if (!found) return { status: 401, body: { error: "登录已过期，请重新登录" } };
    if (found.account.status === "disabled") {
      delete sessions[token];
      commitSessions();
      return { status: 403, body: { error: "账号已禁用" } };
    }
    // 30 天滚动续期：每次有效访问刷新过期时间。
    found.session.expiresAt = now + SESSION_TTL_MS;
    const fail = commitSessions();
    if (fail) return fail;
    return {
      status: 200,
      body: {
        account: publicAccount(found.account),
        devices: bindingsList(found.account),
        activated: bindingsList(found.account).length > 0,
      },
    };
  }

  // ── 管理台账号操作（由 app.mjs 的 handleAdmin 守卫链保护） ──

  function adminListAccounts({ query = "", cursor = "", limit = 50 }) {
    const q = String(query).trim().toLowerCase();
    const all = Object.keys(accounts).sort();
    const matched = all.filter((email) => !q || email.includes(q));
    const total = matched.length;
    const startIndex = cursor ? matched.findIndex((email) => email > cursor) : 0;
    const from = startIndex < 0 ? matched.length : startIndex;
    const page = matched.slice(from, from + limit);
    const items = page.map((email) => {
      const a = accounts[email];
      return {
        email: a.email,
        createdAt: a.createdAt,
        status: a.status,
        verified: !!a.verified,
        deviceCount: Object.keys(a.bindings || {}).length,
      };
    });
    // page 的元素是 email 字符串本身（items 才是对象数组）
    const nextCursor = items.length === limit && page.length > 0
      ? page[page.length - 1]
      : null;
    return { items, next_cursor: nextCursor, total };
  }

  function adminDisableAccount(email) {
    const acct = accounts[email];
    if (!acct) return { status: 404, body: { error: "账号不存在" } };
    if (acct.status === "disabled") return { status: 200, body: { email, status: "disabled" } };
    acct.status = "disabled";
    for (const [token, s] of Object.entries(sessions)) {
      if (s.accountEmail === email) delete sessions[token];
    }
    const fail = commitAccounts();
    if (fail) return fail;
    const fail2 = commitSessions();
    if (fail2) return fail2;
    adminAudit("account-disable", { account: email }, "ok");
    return { status: 200, body: { email, status: "disabled" } };
  }

  function adminEnableAccount(email) {
    const acct = accounts[email];
    if (!acct) return { status: 404, body: { error: "账号不存在" } };
    if (acct.status === "active") return { status: 200, body: { email, status: "active" } };
    acct.status = "active";
    const fail = commitAccounts();
    if (fail) return fail;
    adminAudit("account-enable", { account: email }, "ok");
    return { status: 200, body: { email, status: "active" } };
  }

  function adminForceLogout(email) {
    const acct = accounts[email];
    if (!acct) return { status: 404, body: { error: "账号不存在" } };
    let removed = 0;
    for (const [token, s] of Object.entries(sessions)) {
      if (s.accountEmail === email) { delete sessions[token]; removed += 1; }
    }
    if (removed > 0) {
      const fail = commitSessions();
      if (fail) return fail;
    }
    adminAudit("account-force-logout", { account: email }, removed > 0 ? "ok" : "noop");
    return { status: 200, body: { email, sessions_revoked: removed } };
  }

  // ── /v1/ai 激活三元组绑定（无有效 token 不破坏存量设备） ──

  function linkActivation(token, deviceId, activation) {
    if (typeof token !== "string" || !token || !deviceId || !activation) return false;
    const now = clock();
    const found = findSession(token, now);
    if (!found || found.account.status === "disabled") return false;
    const bindings = found.account.bindings || (found.account.bindings = {});
    const prev = bindings[deviceId];
    if (prev && prev.activation === activation) return true; // 幂等：已绑定同码不重复写盘
    bindings[deviceId] = { deviceId, activation, linkedAt: now };
    const fail = commitAccounts();
    if (fail) {
      log.error("[auth] 激活绑定写盘失败:", (fail.body && fail.body.error) || "unknown");
      return false;
    }
    return true;
  }

  // 测试观察口（与 ai-server snapshot() 同风格：深拷贝，不改活状态）
  function snapshot() {
    return {
      accounts: JSON.parse(JSON.stringify(accounts)),
      sessions: JSON.parse(JSON.stringify(sessions)),
      codes: JSON.parse(JSON.stringify(codes)),
      loginFailures: new Map(loginFailures),
    };
  }

  return {
    emailCode,
    register,
    login,
    logout,
    me,
    adminListAccounts,
    adminDisableAccount,
    adminEnableAccount,
    adminForceLogout,
    linkActivation,
    snapshot,
  };
}
