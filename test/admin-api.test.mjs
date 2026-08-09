// Admin API 契约测试：认证门禁 / loopback / 列表过滤分页 / 各操作路径 /
// revoked 后 consume/rebind 403 / 审计 JSONL 落盘 / 快照追加。
import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import os from "node:os";
import crypto from "node:crypto";
import { createApp } from "../ai-server/app.mjs";

const { publicKey, privateKey } = crypto.generateKeyPairSync("rsa", { modulusLength: 2048 });
const TEST_PUBLIC_KEY = publicKey.export({ type: "pkcs1", format: "pem" });

function makeCode(deviceId, expiry = "20261231") {
  const payload = `${deviceId}:${expiry}:a1b2c3d4e5f6`;
  const signer = crypto.createSign("RSA-SHA256");
  signer.update(payload, "utf8");
  return `ZENCHE-AI-${signer.sign(privateKey, "base64")}-${expiry}`;
}

function tmpDir() { return fs.mkdtempSync(path.join(os.tmpdir(), "zenche-admin-")); }

async function start(opts = {}) {
  const dir = tmpDir();
  const app = await createApp({
    publicKeyPem: TEST_PUBLIC_KEY,
    dbDir: path.join(dir, "data"),
    drawImageImpl: async () => "TEST_MOCK",
    adminSecret: "test-admin-secret",
    enableRebind: true,
    signNewCodeImpl: async (newDeviceId, expiry) => ({ ok: true, code: makeCode(newDeviceId, expiry) }),
    rebindIpLimit: 100,
    rebindActivationLimit: 100,
    auditLogImpl: () => {},
    ...opts,
  });
  return { ...app, cleanupDir: dir };
}

async function close(app) {
  app.server.closeAllConnections?.();
  await new Promise((resolve) => app.server.close(resolve));
  fs.rmSync(app.cleanupDir, { recursive: true, force: true });
}

const adminGet = (base, p, token = "test-admin-secret") =>
  fetch(`${base}${p}`, { headers: { Authorization: `Bearer ${token}` } });
const adminPost = (base, p, body, token = "test-admin-secret") =>
  fetch(`${base}${p}`, {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
    body: JSON.stringify(body),
  });

// 建一个真实激活设备
async function activate(app, deviceId, prompt = "hi") {
  const code = makeCode(deviceId);
  const r = await fetch(`http://127.0.0.1:${app.port}/v1/ai`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ activationCode: code, deviceId, prompt }),
  });
  assert.equal(r.status, 200);
  return code;
}

test("admin: fail-closed (no secret -> 404) and auth gates", async (t) => {
  const app = await start({ adminSecret: "" });
  t.after(() => close(app));
  const noSecret = await fetch(`http://127.0.0.1:${app.port}/v1/admin/stats`);
  assert.equal(noSecret.status, 404, "no adminSecret -> route hidden");
});

test("admin: stats requires valid bearer, rejects wrong token", async (t) => {
  const app = await start();
  t.after(() => close(app));
  const base = `http://127.0.0.1:${app.port}`;
  const wrong = await fetch(`${base}/v1/admin/stats`, {
    headers: { Authorization: "Bearer nope" },
  });
  assert.equal(wrong.status, 401);
  const ok = await adminGet(base, "/v1/admin/stats");
  assert.equal(ok.status, 200);
  const body = await ok.json();
  assert.equal(body.totalAccounts, 0, "empty account registry -> zero users");
  assert.ok("totalDevices" in body);
  assert.ok("expiring7d" in body, "expiring7d added");
  assert.ok("exhausted" in body, "exhausted added");
  assert.ok("revoked" in body, "revoked added");
});

test("admin: stats counts every registered account, not only activated devices", async (t) => {
  const app = await start({ authRequireEmailCode: false });
  t.after(() => close(app));
  const base = `http://127.0.0.1:${app.port}`;
  for (const email of ["active-no-device@test.com", "disabled-no-device@test.com"]) {
    const registered = await fetch(`${base}/v1/auth/register`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email, password: "password123" }),
    });
    assert.equal(registered.status, 200);
  }
  const disabled = await adminPost(base, "/v1/admin/accounts/disabled-no-device%40test.com/disable");
  assert.equal(disabled.status, 200);

  const stats = await (await adminGet(base, "/v1/admin/stats")).json();
  assert.equal(stats.totalAccounts, 2, "active + disabled, unverified accounts are all users");
  assert.equal(stats.totalDevices, 0, "user count must not fall back to activated device count");
});

test("admin UI overview labels the all-account metric as total users", () => {
  const source = fs.readFileSync(new URL("../ai-server/admin/app.js", import.meta.url), "utf8");
  assert.match(source, /label:\s*"总用户",\s*value:\s*s\.totalAccounts/);
  assert.match(source, /sub:\s*"含未验证、已禁用、未绑定设备账号"/);
  assert.doesNotMatch(source, /label:\s*"总设备",\s*value:\s*s\.totalDevices/);
});

test("admin: stats counts revoked/exhausted", async (t) => {
  const app = await start({ maxUsage: 2 });
  t.after(() => close(app));
  const base = `http://127.0.0.1:${app.port}`;
  await activate(app, "dev-exhaust");
  // 用满次数
  const code = makeCode("dev-exhaust");
  for (let i = 0; i < 2; i++) {
    await fetch(`${base}/v1/ai`, {
      method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ activationCode: code, deviceId: "dev-exhaust", prompt: "x" }),
    });
  }
  await activate(app, "dev-revoked");
  await adminPost(base, "/v1/admin/devices/dev-revoked/revoke");
  const stats = await (await adminGet(base, "/v1/admin/stats")).json();
  assert.equal(stats.exhausted, 1);
  assert.equal(stats.revoked, 1);
});

test("admin: devices list filters, query, pagination", async (t) => {
  const app = await start();
  t.after(() => close(app));
  const base = `http://127.0.0.1:${app.port}`;
  await activate(app, "dev-aaa");
  await activate(app, "dev-bbb");
  await activate(app, "dev-ccc");
  // revoked 一个
  await adminPost(base, "/v1/admin/devices/dev-bbb/revoke");
  // all
  const all = await (await adminGet(base, "/v1/admin/devices")).json();
  assert.equal(all.total, 3);
  assert.equal(all.items.length, 3);
  // revoked filter
  const revoked = await (await adminGet(base, "/v1/admin/devices?filter=revoked")).json();
  assert.equal(revoked.total, 1);
  assert.equal(revoked.items[0].device_id, "dev-bbb");
  assert.equal(revoked.items[0].status, "revoked");
  // query
  const q = await (await adminGet(base, "/v1/admin/devices?query=bbb")).json();
  assert.equal(q.total, 1);
  assert.equal(q.items[0].device_id, "dev-bbb");
  // pagination (limit=1, cursor)
  const p1 = await (await adminGet(base, "/v1/admin/devices?limit=1")).json();
  assert.equal(p1.items.length, 1);
  assert.equal(p1.next_cursor, "dev-aaa");
  const p2 = await (await adminGet(base, `/v1/admin/devices?limit=1&cursor=${p1.next_cursor}`)).json();
  assert.equal(p2.items.length, 1);
  assert.equal(p2.items[0].device_id, "dev-bbb");
  assert.equal(p2.next_cursor, "dev-bbb");
});

test("admin: device detail includes migration chain", async (t) => {
  const app = await start();
  t.after(() => close(app));
  const base = `http://127.0.0.1:${app.port}`;
  await activate(app, "dev-old");
  // rebind 迁移
  const code = makeCode("dev-old");
  const rb = await fetch(`${base}/v1/ai/rebind`, {
    method: "POST", headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ activationCode: code, oldDeviceId: "dev-old", newDeviceId: "dev-new" }),
  });
  assert.equal(rb.status, 200);
  const detail = await (await adminGet(base, "/v1/admin/devices/dev-new")).json();
  assert.equal(detail.device.device_id, "dev-new");
  assert.equal(detail.chain.length, 2, "chain includes old + new");
  assert.equal(detail.chain[0].device_id, "dev-old");
  assert.equal(detail.chain[1].device_id, "dev-new");
});

test("admin: reset-usage / note / extend-expiry / issue", async (t) => {
  const app = await start({ maxUsage: 2 });
  t.after(() => close(app));
  const base = `http://127.0.0.1:${app.port}`;
  const code = makeCode("dev-r");
  // 消耗 1 次
  await fetch(`${base}/v1/ai`, {
    method: "POST", headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ activationCode: code, deviceId: "dev-r", prompt: "x" }),
  });
  // reset-usage
  const reset = await (await adminPost(base, "/v1/admin/devices/dev-r/reset-usage")).json();
  assert.equal(reset.used, 0);
  assert.equal(reset.remaining, 2);
  // note
  const note = await (await adminPost(base, "/v1/admin/devices/dev-r/note", { note: "测试备注" })).json();
  assert.equal(note.note, "测试备注");
  // extend-expiry
  const ext = await (await adminPost(base, "/v1/admin/devices/dev-r/extend-expiry", { expiry: "20301231" })).json();
  assert.equal(ext.expiry, "20301231");
  assert.ok(ext.new_code, "new_code returned");
  // issue new device
  const issue = await (await adminPost(base, "/v1/admin/codes/issue", { device_id: "dev-new2", expiry: "20271231" })).json();
  assert.equal(issue.device_id, "dev-new2");
  assert.ok(issue.code);
  // issue duplicate -> 409
  const dup = await adminPost(base, "/v1/admin/codes/issue", { device_id: "dev-new2", expiry: "20271231" });
  assert.equal(dup.status, 409);
  // signer 未配置 -> 503
  const noSigner = await start({ enableRebind: false, signNewCodeImpl: null, rebindSecret: "" });
  t.after(() => close(noSigner));
  const nb = `http://127.0.0.1:${noSigner.port}`;
  await activate(noSigner, "dev-x");
  const ext503 = await adminPost(nb, "/v1/admin/devices/dev-x/extend-expiry", { expiry: "20301231" });
  assert.equal(ext503.status, 503, "extend without signer -> 503");
});

test("admin: revoked device rejects consume and rebind with 403", async (t) => {
  const app = await start();
  t.after(() => close(app));
  const base = `http://127.0.0.1:${app.port}`;
  const code = await activate(app, "dev-rv");
  await adminPost(base, "/v1/admin/devices/dev-rv/revoke");
  // consume -> 403
  const consume = await fetch(`${base}/v1/ai`, {
    method: "POST", headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ activationCode: code, deviceId: "dev-rv", prompt: "x" }),
  });
  assert.equal(consume.status, 403, "revoked consume -> 403");
  assert.match((await consume.json()).error, /已吊销/);
  // rebind -> 403
  const rebind = await fetch(`${base}/v1/ai/rebind`, {
    method: "POST", headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ activationCode: code, oldDeviceId: "dev-rv", newDeviceId: "dev-rv2" }),
  });
  assert.equal(rebind.status, 403, "revoked rebind -> 403");
  // unrevoke 后恢复
  await adminPost(base, "/v1/admin/devices/dev-rv/unrevoke");
  const ok = await fetch(`${base}/v1/ai`, {
    method: "POST", headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ activationCode: code, deviceId: "dev-rv", prompt: "x" }),
  });
  assert.equal(ok.status, 200, "unrevoked consume works again");
});

test("admin: audit JSONL appended with fsync, no full activation in log", async (t) => {
  const app = await start();
  t.after(() => close(app));
  const base = `http://127.0.0.1:${app.port}`;
  await activate(app, "dev-audit");
  const noteText = "审计测试备注内容";
  await adminPost(base, "/v1/admin/devices/dev-audit/note", { note: noteText });
  await adminPost(base, "/v1/admin/devices/dev-audit/revoke");
  const auditFile = path.join(app.cleanupDir, "data", "admin-audit.jsonl");
  assert.ok(fs.existsSync(auditFile), "audit file exists");
  const lines = fs.readFileSync(auditFile, "utf8").split("\n").filter(Boolean);
  assert.ok(lines.length >= 2);
  const noteLine = lines.find((l) => l.includes('"op":"note"'));
  assert.ok(noteLine, "note op logged");
  assert.ok(noteLine.includes('"note_len"'), "note length logged (not content)");
  assert.ok(!noteLine.includes(noteText), "full note text NOT in log");
  // 完整激活码不入日志
  const devRecord = app.snapshot().devices["dev-audit"];
  for (const line of lines) {
    assert.ok(!line.includes(devRecord.activation), "full activation never in audit log");
  }
  // 设备指纹（12 位截断）应存在
  assert.ok(noteLine.includes('"device_id_fp"'), "device fingerprint present");
});

test("admin: snapshot appended daily, history readable", async (t) => {
  const app = await start();
  t.after(() => close(app));
  const base = `http://127.0.0.1:${app.port}`;
  await activate(app, "dev-snap");
  const hist = await (await adminGet(base, "/v1/admin/stats/history?days=30")).json();
  assert.ok(Array.isArray(hist.snapshots));
  assert.ok(hist.snapshots.length >= 1, "at least today snapshot");
  assert.ok(hist.snapshots[0].date, "snapshot has date");
  assert.ok("totalDevices" in hist.snapshots[0], "snapshot has stats");
  assert.ok("totalAccounts" in hist.snapshots[0], "snapshot has all-account total");
  // 快照文件落盘
  const snapFile = path.join(app.cleanupDir, "data", "admin-stats-snapshots.jsonl");
  assert.ok(fs.existsSync(snapFile), "snapshot file exists");
});

test("admin: pagination total is matched count, not page count", async (t) => {
  const app = await start();
  t.after(() => close(app));
  const base = `http://127.0.0.1:${app.port}`;
  for (const d of ["dev-01", "dev-02", "dev-03", "dev-04", "dev-05"]) {
    await activate(app, d);
  }
  // limit=2 每页：total 恒为 5（匹配总数），next_cursor 推进。
  const p1 = await (await adminGet(base, "/v1/admin/devices?limit=2")).json();
  assert.equal(p1.total, 5, "page 1 total = matched count");
  assert.equal(p1.items.length, 2);
  const p2 = await (await adminGet(base, `/v1/admin/devices?limit=2&cursor=${p1.next_cursor}`)).json();
  assert.equal(p2.total, 5, "page 2 total = matched count");
  assert.equal(p2.items.length, 2);
  const p3 = await (await adminGet(base, `/v1/admin/devices?limit=2&cursor=${p2.next_cursor}`)).json();
  assert.equal(p3.total, 5, "page 3 total = matched count");
  assert.equal(p3.items.length, 1, "last page has remainder");
  assert.equal(p3.next_cursor, null, "no more pages");
});

test("admin: migration chain guards against cycles in migrated_from", { timeout: 10_000 }, async (t) => {
  const app = await start();
  t.after(() => close(app));
  const base = `http://127.0.0.1:${app.port}`;
  await activate(app, "dev-cyc-a");
  await activate(app, "dev-cyc-b");
  // 经 test-only mutator 在服务端活状态上真实构环（migrated_from 环）。
  // 不得用 app.snapshot()：它是 JSON 深拷贝（app.mjs Test helpers），改副本到不了
  // 活状态，GET 在无环状态下 200 属平凡通过——那正是本测试此前空转的根因。
  assert.equal(app.mutateDevice("dev-cyc-a", { migrated_from: "dev-cyc-b" }), true);
  assert.equal(app.mutateDevice("dev-cyc-b", { migrated_from: "dev-cyc-a" }), true);
  // 通过真实接口触发 migrationChain（前向 migrated_to 无环、后向 migrated_from 成环）；
  // 无守卫时后向 while 同步死循环，事件循环被阻塞，请求永不返回（挂起判红）。
  const r = await adminGet(base, "/v1/admin/devices/dev-cyc-a");
  assert.equal(r.status, 200, "cycle must not hang the handler");
  const body = await r.json();
  assert.ok(Array.isArray(body.chain), "chain still returned");
});

test("admin: reset-usage and revoke on migrated middle node act on tail", async (t) => {
  const app = await start({ maxUsage: 2 });
  t.after(() => close(app));
  const base = `http://127.0.0.1:${app.port}`;
  const code = makeCode("dev-old2");
  await fetch(`${base}/v1/ai`, {
    method: "POST", headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ activationCode: code, deviceId: "dev-old2", prompt: "x" }),
  });
  // 迁移到 dev-new2（dev-old2 成为链中间节点）
  const rb = await fetch(`${base}/v1/ai/rebind`, {
    method: "POST", headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ activationCode: code, oldDeviceId: "dev-old2", newDeviceId: "dev-new2" }),
  });
  assert.equal(rb.status, 200);
  // 对中间节点 dev-old2 reset-usage → 作用于 tail dev-new2
  const reset = await (await adminPost(base, "/v1/admin/devices/dev-old2/reset-usage")).json();
  assert.equal(reset.device_id, "dev-new2", "reset acts on tail");
  assert.equal(reset.used, 0);
  // 对中间节点 dev-old2 revoke → 作用于 tail dev-new2（consume 403 验证）
  const rev = await (await adminPost(base, "/v1/admin/devices/dev-old2/revoke")).json();
  assert.equal(rev.device_id, "dev-new2", "revoke acts on tail");
  assert.equal(rev.status, "revoked");
  const consume = await fetch(`${base}/v1/ai`, {
    method: "POST", headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ activationCode: code, deviceId: "dev-new2", prompt: "x" }),
  });
  assert.equal(consume.status, 403, "revoked tail rejects consume");
});
