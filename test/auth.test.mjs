// W13-a 邮箱账号系统契约测试：scrypt 向量、注册/登录/登出/me 全路径、
// 验证码 TTL/尝试上限、409/400/401/403 各分支、防枚举统一 401、限流触发、
// 禁用后 session 全失效、激活三元组绑定、SMTP 未配 503、审计写入、
// 并发注册同邮箱仅一成、ZENCHE_AUTH_REQUIRE_EMAIL_CODE 开关两态。
// SMTP 一律注入 fake transport（禁真实发信）。
import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import os from "node:os";
import crypto from "node:crypto";
import { createApp } from "../ai-server/app.mjs";
import {
  scryptRaw,
  hashPassword,
  verifyPassword,
  buildVerificationMail,
} from "../ai-server/auth.mjs";

const { publicKey, privateKey } = crypto.generateKeyPairSync("rsa", { modulusLength: 2048 });
const TEST_PUBLIC_KEY = publicKey.export({ type: "pkcs1", format: "pem" });

function makeCode(deviceId, expiry = "20261231") {
  const payload = `${deviceId}:${expiry}:a1b2c3d4e5f6`;
  const signer = crypto.createSign("RSA-SHA256");
  signer.update(payload, "utf8");
  return `ZENCHE-AI-${signer.sign(privateKey, "base64")}-${expiry}`;
}

function tmpDir() { return fs.mkdtempSync(path.join(os.tmpdir(), "zenche-auth-")); }

function fakeSmtp() {
  const sent = [];
  return {
    sent,
    impl: async (mail) => { sent.push(mail); },
  };
}

async function start(opts = {}) {
  const dir = tmpDir();
  const smtp = fakeSmtp();
  const app = await createApp({
    publicKeyPem: TEST_PUBLIC_KEY,
    dbDir: path.join(dir, "data"),
    drawImageImpl: async () => "TEST_MOCK",
    adminSecret: "test-admin-secret",
    smtpSendImpl: smtp.impl,
    ...opts,
  });
  return { ...app, cleanupDir: dir, smtp };
}

async function close(app) {
  app.server.closeAllConnections?.();
  await new Promise((resolve) => app.server.close(resolve));
  fs.rmSync(app.cleanupDir, { recursive: true, force: true });
}

// 通用请求：POST 自动 JSON body；可带 Bearer
async function req(app, route, { method = "GET", body, token } = {}) {
  const headers = { "Content-Type": "application/json" };
  if (token) headers.Authorization = `Bearer ${token}`;
  const res = await fetch(`http://127.0.0.1:${app.port}${route}`, {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  let json = null;
  try { json = await res.json(); } catch { /* 非 JSON 响应 */ }
  return { status: res.status, json, headers: res.headers };
}

const adminReq = (app, route, method, body) =>
  req(app, route, { method, body, token: "test-admin-secret" });

// ---------- scrypt 向量（RFC 7914 附录 B，独立于自实现） ----------

test("scrypt: RFC 7914 vectors", () => {
  const v1 = scryptRaw("", Buffer.alloc(0), 64, 16, 1, 1).toString("hex");
  assert.equal(v1, "77d6576238657b203b19ca42c18a0497f16b4844e3074ae8dfdffa3fede21442fcd0069ded0948f8326a753a0fc81f17e8d3e0fb2e0d3628cf35e20c38d18906");
  const v2 = scryptRaw("password", Buffer.from("NaCl", "utf8"), 64, 1024, 8, 16).toString("hex");
  assert.equal(v2, "fdbabe1c9d3472007856e7190d01e9fe7c6ad7cbc8237830e77376634b3731622eaf30d92e22a3886ff109279d9830dac727afb94a83ee6d8360cbdfa2cc0640");
});

test("scrypt: hash format, verify ok/bad/tampered", () => {
  const h = hashPassword("correct horse battery");
  assert.match(h, /^scrypt\$16384\$8\$1\$32\$[0-9a-f]{32}\$[0-9a-f]{64}$/);
  assert.ok(verifyPassword("correct horse battery", h));
  assert.ok(!verifyPassword("wrong", h));
  assert.ok(!verifyPassword("correct horse battery", h.slice(0, -2) + "00"), "tampered hash rejected");
  assert.ok(!verifyPassword("x", "garbage"), "malformed stored value rejected");
});

// ---------- 注册 / 登录 / 登出 / me 全路径 ----------

test("auth: register with email code full path", async (t) => {
  const app = await start();
  t.after(() => close(app));
  // 发码
  let r = await req(app, "/v1/auth/email-code", { method: "POST", body: { email: "user@example.com", purpose: "register" } });
  assert.equal(r.status, 200);
  assert.equal(app.smtp.sent.length, 1, "one mail sent");
  const mail = app.smtp.sent[0];
  assert.equal(mail.to, "user@example.com");
  const codeMatch = /验证码为：(\d{6})/.exec(mail.text);
  assert.ok(codeMatch, "code present in plain text");
  const code = codeMatch[1];
  assert.match(mail.html, new RegExp(code), "code present in html");
  assert.match(mail.subject, /帧澈 ZENCHE/);
  // 注册
  r = await req(app, "/v1/auth/register", { method: "POST", body: { email: "User@Example.com", password: "password123", code } });
  assert.equal(r.status, 200);
  assert.ok(r.json.token, "token returned");
  assert.equal(r.json.account.email, "user@example.com", "email lowercased");
  assert.equal(r.json.account.verified, true);
  // 重复注册 409
  r = await req(app, "/v1/auth/register", { method: "POST", body: { email: "user@example.com", password: "password123", code } });
  assert.equal(r.status, 409);
  // 密码 <8 位 400
  r = await req(app, "/v1/auth/register", { method: "POST", body: { email: "x@y.com", password: "short", code: "123456" } });
  assert.equal(r.status, 400);
  assert.match(r.json.error, /至少 8 位/);
  // 邮箱格式无效 400
  r = await req(app, "/v1/auth/register", { method: "POST", body: { email: "not-an-email", password: "password123", code: "123456" } });
  assert.equal(r.status, 400);
});

test("auth: login / me / logout full path", async (t) => {
  const app = await start({ authRequireEmailCode: false });
  t.after(() => close(app));
  await req(app, "/v1/auth/register", { method: "POST", body: { email: "a@b.com", password: "password123" } });
  // login 成功
  let r = await req(app, "/v1/auth/login", { method: "POST", body: { email: "a@b.com", password: "password123" } });
  assert.equal(r.status, 200);
  assert.ok(r.json.token);
  assert.equal(r.json.account.email, "a@b.com");
  const token = r.json.token;
  // me：账号 + 设备 + 激活状态
  r = await req(app, "/v1/auth/me", { token });
  assert.equal(r.status, 200);
  assert.equal(r.json.account.email, "a@b.com");
  assert.ok(Array.isArray(r.json.devices));
  assert.equal(r.json.activated, false);
  // logout
  r = await req(app, "/v1/auth/logout", { method: "POST", token });
  assert.equal(r.status, 200);
  // logout 后 me 401
  r = await req(app, "/v1/auth/me", { token });
  assert.equal(r.status, 401);
  // logout 幂等（二次 200）
  r = await req(app, "/v1/auth/logout", { method: "POST", token });
  assert.equal(r.status, 200);
  // 无 token me 401 / 未知 token 401
  r = await req(app, "/v1/auth/me");
  assert.equal(r.status, 401);
  r = await req(app, "/v1/auth/me", { token: "deadbeef" });
  assert.equal(r.status, 401);
});

test("auth: 防枚举——邮箱不存在与密码错误统一 401 同文案", async (t) => {
  const app = await start({ authRequireEmailCode: false });
  t.after(() => close(app));
  await req(app, "/v1/auth/register", { method: "POST", body: { email: "enum@test.com", password: "password123" } });
  const missing = await req(app, "/v1/auth/login", { method: "POST", body: { email: "nobody@test.com", password: "password123" } });
  const wrongPw = await req(app, "/v1/auth/login", { method: "POST", body: { email: "enum@test.com", password: "wrong-password" } });
  assert.equal(missing.status, 401);
  assert.equal(wrongPw.status, 401);
  assert.equal(missing.json.error, wrongPw.json.error, "identical error message");
  assert.equal(missing.json.error, "邮箱或密码错误");
});

// ---------- 验证码 TTL / 尝试上限 ----------

test("auth: email code wrong attempts lock after 5 (code deleted)", async (t) => {
  const app = await start();
  t.after(() => close(app));
  await req(app, "/v1/auth/email-code", { method: "POST", body: { email: "lock@test.com", purpose: "register" } });
  const code = /验证码为：(\d{6})/.exec(app.smtp.sent[0].text)[1];
  const wrong = code === "000000" ? "000001" : "000000";
  let last;
  for (let i = 0; i < 5; i++) {
    last = await req(app, "/v1/auth/register", { method: "POST", body: { email: "lock@test.com", password: "password123", code: wrong } });
    assert.equal(last.status, 400);
  }
  assert.match(last.json.error, /次数过多/);
  // 码已被删除：带正确码也 400「请先获取验证码」
  const after = await req(app, "/v1/auth/register", { method: "POST", body: { email: "lock@test.com", password: "password123", code } });
  assert.equal(after.status, 400);
  assert.match(after.json.error, /请先获取验证码/);
});

test("auth: email code TTL expires after 10min", async (t) => {
  let now = 1_000_000_000_000;
  const app = await start({ authClock: () => now });
  t.after(() => close(app));
  await req(app, "/v1/auth/email-code", { method: "POST", body: { email: "ttl@test.com", purpose: "register" } });
  const code = /验证码为：(\d{6})/.exec(app.smtp.sent[0].text)[1];
  // 推进 10min+1s：码过期
  now += 10 * 60 * 1000 + 1000;
  const r = await req(app, "/v1/auth/register", { method: "POST", body: { email: "ttl@test.com", password: "password123", code } });
  assert.equal(r.status, 400);
  assert.match(r.json.error, /过期/);
});

// ---------- SMTP 未配置 fail-closed / 修订开关两态 ----------

test("auth: SMTP 未配置 email-code 503；register 无码 400（禁 fail-open）", async (t) => {
  const app = await start({ smtpSendImpl: null });
  t.after(() => close(app));
  const code = await req(app, "/v1/auth/email-code", { method: "POST", body: { email: "x@y.com", purpose: "register" } });
  assert.equal(code.status, 503);
  assert.match(code.json.error, /未配置/);
  const reg = await req(app, "/v1/auth/register", { method: "POST", body: { email: "x@y.com", password: "password123" } });
  assert.equal(reg.status, 400, "no silent fail-open");
  // 有 smtpSendImpl 但缺码：同样 400
  const app2 = await start();
  t.after(() => close(app2));
  const reg2 = await req(app2, "/v1/auth/register", { method: "POST", body: { email: "x@y.com", password: "password123" } });
  assert.equal(reg2.status, 400);
});

test("auth: 开关=0（免码过渡期）注册成功且 verified=false；email-code 仍 503", async (t) => {
  const app = await start({ authRequireEmailCode: false, smtpSendImpl: null });
  t.after(() => close(app));
  const reg = await req(app, "/v1/auth/register", { method: "POST", body: { email: "free@test.com", password: "password123" } });
  assert.equal(reg.status, 200, "免码注册成功");
  assert.equal(reg.json.account.verified, false, "verified=false 后台可识别");
  // email-code 仍 503（SMTP 未配）
  const code = await req(app, "/v1/auth/email-code", { method: "POST", body: { email: "free@test.com", purpose: "register" } });
  assert.equal(code.status, 503);
  // login 照常
  const login = await req(app, "/v1/auth/login", { method: "POST", body: { email: "free@test.com", password: "password123" } });
  assert.equal(login.status, 200);
  // 管理台列表 verified 暴露
  const list = await adminReq(app, "/v1/admin/accounts", "GET");
  assert.equal(list.status, 200);
  assert.equal(list.json.items[0].verified, false);
});

// ---------- 限流 ----------

test("auth: 发码同邮箱 1/min 限流", async (t) => {
  const app = await start();
  t.after(() => close(app));
  const first = await req(app, "/v1/auth/email-code", { method: "POST", body: { email: "rl@test.com", purpose: "register" } });
  assert.equal(first.status, 200);
  const second = await req(app, "/v1/auth/email-code", { method: "POST", body: { email: "rl@test.com", purpose: "register" } });
  assert.equal(second.status, 429);
  assert.equal(second.headers.get("retry-after"), "60");
});

test("auth: 发码同 IP 10/hour 限流", async (t) => {
  const app = await start();
  t.after(() => close(app));
  for (let i = 0; i < 10; i++) {
    const r = await req(app, "/v1/auth/email-code", { method: "POST", body: { email: `ip${i}@test.com`, purpose: "register" } });
    assert.equal(r.status, 200, `email ${i} allowed`);
  }
  const blocked = await req(app, "/v1/auth/email-code", { method: "POST", body: { email: "ip11@test.com", purpose: "register" } });
  assert.equal(blocked.status, 429);
});

test("auth: 注册/登录同 IP 20/hour 限流", async (t) => {
  const app = await start({ authRequireEmailCode: false });
  t.after(() => close(app));
  for (let i = 0; i < 20; i++) {
    const r = await req(app, "/v1/auth/register", { method: "POST", body: { email: `auth${i}@test.com`, password: "password123" } });
    assert.equal(r.status, 200, `register ${i} allowed`);
  }
  const blocked = await req(app, "/v1/auth/register", { method: "POST", body: { email: "auth21@test.com", password: "password123" } });
  assert.equal(blocked.status, 429);
});

test("auth: 同邮箱登录失败 5 次锁 15min，解锁后恢复计数", async (t) => {
  let now = 2_000_000_000_000;
  const app = await start({ authRequireEmailCode: false, authClock: () => now });
  t.after(() => close(app));
  await req(app, "/v1/auth/register", { method: "POST", body: { email: "lock@test.com", password: "password123" } });
  for (let i = 0; i < 5; i++) {
    const r = await req(app, "/v1/auth/login", { method: "POST", body: { email: "lock@test.com", password: "wrong" } });
    assert.equal(r.status, 401, `attempt ${i + 1} -> 401`);
  }
  // 第 6 次：锁内 → 429（防爆破）
  const locked = await req(app, "/v1/auth/login", { method: "POST", body: { email: "lock@test.com", password: "password123" } });
  assert.equal(locked.status, 429);
  assert.ok(Number(locked.headers.get("retry-after")) > 0);
  // 15min 后解锁：正确密码可登录
  now += 15 * 60 * 1000 + 1000;
  const ok = await req(app, "/v1/auth/login", { method: "POST", body: { email: "lock@test.com", password: "password123" } });
  assert.equal(ok.status, 200);
});

// ---------- 管理台账号 API + 审计 ----------

test("admin accounts: 列表/禁用/启用/强制下线 + 审计写入", async (t) => {
  const app = await start({ authRequireEmailCode: false });
  t.after(() => close(app));
  await req(app, "/v1/auth/register", { method: "POST", body: { email: "a@test.com", password: "password123" } });
  await req(app, "/v1/auth/register", { method: "POST", body: { email: "b@test.com", password: "password123" } });
  // 列表
  let r = await adminReq(app, "/v1/admin/accounts", "GET");
  assert.equal(r.status, 200);
  assert.equal(r.json.total, 2);
  assert.ok(r.json.items.every((i) => "email" in i && "createdAt" in i && "deviceCount" in i && "status" in i && "verified" in i));
  // query + 分页
  r = await adminReq(app, "/v1/admin/accounts?query=b@", "GET");
  assert.equal(r.json.total, 1);
  assert.equal(r.json.items[0].email, "b@test.com");
  r = await adminReq(app, "/v1/admin/accounts?limit=1", "GET");
  assert.equal(r.json.items.length, 1);
  assert.ok(r.json.next_cursor, "cursor present");
  // disable → 登录 403「账号已禁用」；已发 session 全失效（401）
  const t1 = (await req(app, "/v1/auth/login", { method: "POST", body: { email: "a@test.com", password: "password123" } })).json.token;
  r = await adminReq(app, "/v1/admin/accounts/a@test.com/disable", "POST");
  assert.equal(r.status, 200);
  assert.equal(r.json.status, "disabled");
  r = await req(app, "/v1/auth/me", { token: t1 });
  assert.equal(r.status, 401, "session revoked on disable");
  r = await req(app, "/v1/auth/login", { method: "POST", body: { email: "a@test.com", password: "password123" } });
  assert.equal(r.status, 403);
  assert.match(r.json.error, /已禁用/);
  // 不存在账号 404
  r = await adminReq(app, "/v1/admin/accounts/nobody@test.com/disable", "POST");
  assert.equal(r.status, 404);
  // enable → 登录恢复
  r = await adminReq(app, "/v1/admin/accounts/a@test.com/enable", "POST");
  assert.equal(r.status, 200);
  r = await req(app, "/v1/auth/login", { method: "POST", body: { email: "a@test.com", password: "password123" } });
  assert.equal(r.status, 200);
  // force-logout → 全部 session 吊销
  const t2 = (await req(app, "/v1/auth/login", { method: "POST", body: { email: "a@test.com", password: "password123" } })).json.token;
  r = await adminReq(app, "/v1/admin/accounts/a@test.com/force-logout", "POST");
  assert.equal(r.status, 200);
  assert.ok(r.json.sessions_revoked >= 1);
  r = await req(app, "/v1/auth/me", { token: t2 });
  assert.equal(r.status, 401);
  // 审计 JSONL 落盘（disable/enable/force-logout 均记录，含 account 邮箱）
  const auditFile = path.join(app.cleanupDir, "data", "admin-audit.jsonl");
  assert.ok(fs.existsSync(auditFile), "audit file exists");
  const lines = fs.readFileSync(auditFile, "utf8").split("\n").filter(Boolean);
  const ops = lines.map((l) => JSON.parse(l)).filter((l) => l.op && l.op.startsWith("account-"));
  assert.ok(ops.some((l) => l.op === "account-disable" && l.params.account === "a@test.com"), "disable audited");
  assert.ok(ops.some((l) => l.op === "account-enable" && l.params.account === "a@test.com"), "enable audited");
  assert.ok(ops.some((l) => l.op === "account-force-logout" && l.params.account === "a@test.com"), "force-logout audited");
});

test("admin accounts: 管理台门禁（无 secret 404 / 错 token 401 / 非 loopback 403）", async (t) => {
  const app = await start({ adminSecret: "" });
  t.after(() => close(app));
  const r = await req(app, "/v1/admin/accounts", { method: "GET" });
  assert.equal(r.status, 404, "fail-closed without adminSecret");
  const app2 = await start();
  t.after(() => close(app2));
  const wrong = await req(app2, "/v1/admin/accounts", { method: "GET", token: "nope" });
  assert.equal(wrong.status, 401);
});

// ---------- 激活三元组绑定（/v1/ai + Bearer） ----------

test("auth: /v1/ai 激活成功带 Bearer 记录 account↔device↔激活码 三元组", async (t) => {
  const app = await start({ authRequireEmailCode: false });
  t.after(() => close(app));
  await req(app, "/v1/auth/register", { method: "POST", body: { email: "bind@test.com", password: "password123" } });
  const login = await req(app, "/v1/auth/login", { method: "POST", body: { email: "bind@test.com", password: "password123" } });
  const token = login.json.token;
  const code = makeCode("dev-bind");
  // 带 Bearer 激活
  let r = await req(app, "/v1/ai", { method: "POST", token, body: { activationCode: code, deviceId: "dev-bind", prompt: "hi" } });
  assert.equal(r.status, 200);
  const snap = app.authSnapshot().accounts["bind@test.com"];
  assert.ok(snap.bindings["dev-bind"], "binding recorded");
  assert.equal(snap.bindings["dev-bind"].activation, code);
  // me 里 devices + activated 反映绑定
  r = await req(app, "/v1/auth/me", { token });
  assert.equal(r.json.devices.length, 1);
  assert.equal(r.json.devices[0].deviceId, "dev-bind");
  assert.equal(r.json.activated, true);
  // 幂等：同码重复激活不重复写（bindings 仍 1 条）
  await req(app, "/v1/ai", { method: "POST", token, body: { activationCode: code, deviceId: "dev-bind", prompt: "hi" } });
  assert.equal(Object.keys(app.authSnapshot().accounts["bind@test.com"].bindings).length, 1);
});

test("auth: 无 token / 无效 token 激活不破坏存量设备，不产生绑定", async (t) => {
  const app = await start({ authRequireEmailCode: false });
  t.after(() => close(app));
  const code = makeCode("dev-legacy");
  // 存量无 token 设备照常工作
  let r = await req(app, "/v1/ai", { method: "POST", body: { activationCode: code, deviceId: "dev-legacy", prompt: "hi" } });
  assert.equal(r.status, 200);
  // 无效 token 激活：成功但无绑定
  r = await req(app, "/v1/ai", { method: "POST", token: "invalid-token", body: { activationCode: code, deviceId: "dev-legacy", prompt: "hi" } });
  assert.equal(r.status, 200, "invalid token does not break activation");
  assert.equal(Object.keys(app.authSnapshot().accounts).length, 0, "no account created");
});

// ---------- 并发注册同邮箱仅一成 ----------

test("auth: 并发注册同邮箱仅一个成功", async (t) => {
  const app = await start({ authRequireEmailCode: false });
  t.after(() => close(app));
  const attempt = () => req(app, "/v1/auth/register", { method: "POST", body: { email: "race@test.com", password: "password123" } });
  const [a, b] = await Promise.all([attempt(), attempt()]);
  const statuses = [a.status, b.status].sort();
  assert.deepEqual(statuses, [200, 409], "exactly one succeeds");
  const accts = Object.keys(app.authSnapshot().accounts);
  assert.deepEqual(accts, ["race@test.com"], "single account record");
});

// ---------- session 30 天滚动过期 ----------

test("auth: session 30 天滚动过期，过期自动失效并清理", async (t) => {
  let now = 3_000_000_000_000;
  const app = await start({ authRequireEmailCode: false, authClock: () => now });
  t.after(() => close(app));
  await req(app, "/v1/auth/register", { method: "POST", body: { email: "roll@test.com", password: "password123" } });
  const token = (await req(app, "/v1/auth/login", { method: "POST", body: { email: "roll@test.com", password: "password123" } })).json.token;
  // 29 天后访问 → 滚动续期（有效）
  now += 29 * 24 * 60 * 60 * 1000;
  let r = await req(app, "/v1/auth/me", { token });
  assert.equal(r.status, 200, "rolling renewal within 30d");
  // 31 天不访问 → 过期 401
  now += 31 * 24 * 60 * 60 * 1000;
  r = await req(app, "/v1/auth/me", { token });
  assert.equal(r.status, 401);
  assert.ok(!app.authSnapshot().sessions[token], "expired session pruned");
});

// ---------- 邮件模板单元 ----------

test("auth: 验证码邮件模板（中文品牌、双格式、纯数字 6 位）", () => {
  const mail = buildVerificationMail("123456");
  assert.match(mail.subject, /帧澈 ZENCHE/);
  assert.match(mail.subject, /验证码/);
  assert.match(mail.text, /123456/);
  assert.match(mail.text, /10 分钟内有效/);
  assert.match(mail.html, /123456/);
  assert.match(mail.html, /帧澈 ZENCHE/);
});
