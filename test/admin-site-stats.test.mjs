// 官网访问统计 API 契约测试（ZENCHE_ADMIN_MONITOR_PLAN「官网访问统计」二期）：
// combined 日志解析聚合——页面 vs 资源剔除、/downloads/ 单列、bot UA 剔除、
// 八类来源分类、多日分桶 UV 按日独立 IP、mtime+size 缓存、文件缺失 503、空文件零值。
// 样例日志一律经 fsAdapter（内存注入），绝不触碰真实 /var/log。
import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import os from "node:os";
import crypto from "node:crypto";
import { createApp } from "../ai-server/app.mjs";

const { publicKey, privateKey } = crypto.generateKeyPairSync("rsa", { modulusLength: 2048 });
const TEST_PUBLIC_KEY = publicKey.export({ type: "pkcs1", format: "pem" });

const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

// 本地日期 YYYY-MM-DD（offset 天相对今天）；日志 tag 与窗口组帧同用本地日期。
function dayStr(offset = 0) {
  const d = new Date();
  d.setDate(d.getDate() + offset);
  const p2 = (n) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${p2(d.getMonth() + 1)}-${p2(d.getDate())}`;
}

// "2026-10-10" → combined 时间标签 "[10/Oct/2026:13:55:36 +0800]"
function tag(dateStr, time = "13:55:36") {
  const [y, m, d] = dateStr.split("-");
  return `${d}/${MONTHS[+m - 1]}/${y}:${time} +0800`;
}

// 组装一行 combined 日志
function logLine({
  ip, date, time = "13:55:36", method = "GET", path, status = 200,
  size = 512, referer = "-", ua = "Mozilla/5.0 (X11; Linux x86_64)",
}) {
  return `${ip} - - [${tag(date, time)}] "${method} ${path} HTTP/1.1" ${status} ${size} "${referer}" "${ua}"`;
}

// 内存 fsAdapter：把 siteLogPath 的 stat/read 映射到可变的样例内容（真实 fs 之外零落盘）。
// state.hugeSize 设置后模拟 >50MB 大文件：statSync 报 hugeSize，readSync 走截尾路径，
// content 视为"文件尾部 50MB 内容"（position 偏移按 hugeSize - contentLen 换算）。
const LOG_FD = 999;
function memSiteLog(initial = "") {
  const state = { content: initial, mtimeMs: 1_700_000_000_000, exists: true, hugeSize: null };
  const isLog = (p) => state.exists && String(p).endsWith("access.log");
  const adapter = {
    ...fs,
    statSync: (p) => {
      if (isLog(p)) {
        return {
          mtimeMs: state.mtimeMs,
          size: state.hugeSize ?? Buffer.byteLength(state.content, "utf8"),
          isFile: () => true, isDirectory: () => false, isSymbolicLink: () => false,
        };
      }
      if (String(p).endsWith("access.log")) {
        const err = new Error(`ENOENT: no such file or directory, stat '${p}'`);
        err.code = "ENOENT";
        throw err;
      }
      return fs.statSync(p);
    },
    openSync: (p, flags) => (isLog(p) ? LOG_FD : fs.openSync(p, flags)),
    closeSync: (fd) => { if (fd !== LOG_FD) fs.closeSync(fd); },
    readSync: (fd, buffer, offset, length, position) => {
      if (fd === LOG_FD) {
        const contentBuf = Buffer.from(state.content, "utf8");
        // content 起点在"文件"中的偏移 = hugeSize - contentLen；position 换算为 content 内下标
        const start = position - (state.hugeSize - contentBuf.length);
        const from = Math.max(0, start);
        const slice = contentBuf.subarray(from, from + length);
        slice.copy(buffer, offset);
        return slice.length;
      }
      return fs.readSync(fd, buffer, offset, length, position);
    },
    readFileSync: (p, enc) => {
      if (isLog(p)) return state.content;
      return fs.readFileSync(p, enc);
    },
  };
  return { adapter, state };
}

async function start(opts = {}) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "zenche-site-"));
  const { adapter, state } = memSiteLog(opts.siteLogContent || "");
  const app = await createApp({
    publicKeyPem: TEST_PUBLIC_KEY,
    dbDir: path.join(dir, "data"),
    drawImageImpl: async () => "TEST_MOCK",
    adminSecret: "test-admin-secret",
    siteLogPath: "/var/lib/zenche-test/zenche-top.access.log",
    fsAdapter: adapter,
    ...opts,
  });
  return { ...app, cleanupDir: dir, logState: state };
}

async function close(app) {
  app.server.closeAllConnections?.();
  await new Promise((resolve) => app.server.close(resolve));
  fs.rmSync(app.cleanupDir, { recursive: true, force: true });
}

const siteGet = (app, days) =>
  fetch(`http://127.0.0.1:${app.port}/v1/admin/site/stats${days ? `?days=${days}` : ""}`, {
    headers: { Authorization: "Bearer test-admin-secret" },
  });

test("site stats: fail-closed without adminSecret (404)", async (t) => {
  const app = await start({ adminSecret: "" });
  t.after(() => close(app));
  const r = await fetch(`http://127.0.0.1:${app.port}/v1/admin/site/stats`);
  assert.equal(r.status, 404, "no adminSecret -> route hidden");
});

test("site stats: page vs resource, /downloads/ separate, bot UA, method/status filter", async (t) => {
  const today = dayStr(0);
  const content = [
    logLine({ ip: "1.0.0.1", date: today, path: "/" }),                       // 页面 pv
    logLine({ ip: "1.0.0.2", date: today, path: "/index.html", referer: "https://www.baidu.com/s?wd=zenche" }), // 页面 .html
    logLine({ ip: "1.0.0.3", date: today, path: "/about" }),                  // 无扩展名页面
    logLine({ ip: "1.0.0.4", date: today, path: "/about?utm_source=x" }),     // query 剥离 → /about
    logLine({ ip: "1.0.0.5", date: today, path: "/style.css" }),              // 资源剔除
    logLine({ ip: "1.0.0.6", date: today, path: "/img/logo.png" }),           // 资源剔除
    logLine({ ip: "1.0.0.7", date: today, path: "/favicon.ico" }),            // 资源剔除（.ico 在列表）
    logLine({ ip: "1.0.0.8", date: today, path: "/downloads/zenche.dmg" }),   // downloads 单列
    logLine({ ip: "1.0.0.9", date: today, path: "/downloads/setup.exe", status: 304 }), // 304 也计 downloads
    logLine({ ip: "1.0.0.1", date: today, path: "/", ua: "Googlebot/2.1 (+http://www.google.com/bot.html)" }), // botPv
    logLine({ ip: "1.0.0.10", date: today, path: "/", method: "POST" }),      // 非 GET/HEAD 剔除
    logLine({ ip: "1.0.0.11", date: today, path: "/", status: 404 }),         // 非 200/304 剔除
    logLine({ ip: "1.0.0.3", date: today, path: "/about", ua: "curl/8.0" }),  // botPv
    logLine({ ip: "1.0.0.12", date: today, path: "/", method: "HEAD" }),      // HEAD 计页面
  ].join("\n") + "\n";
  const app = await start({ siteLogContent: content });
  t.after(() => close(app));
  const r = await siteGet(app, 7);
  assert.equal(r.status, 200);
  const body = await r.json();
  // today：pv=5（/ x2 + /index.html + /about x2），uv=5（1.0.0.1/2/3/4/12），downloads=2，botPv=2
  assert.equal(body.today.date, today);
  assert.equal(body.today.pv, 5, "pv counts pages only");
  assert.equal(body.today.uv, 5, "uv = distinct IPs today");
  assert.equal(body.today.downloads, 2, "/downloads/* counted separately");
  assert.equal(body.today.botPv, 2, "bot UA counted separately");
  // 窗口：days=7 → 7 项，range 覆盖 [today-6, today]
  assert.equal(body.days.length, 7);
  assert.equal(body.range.to, today);
  assert.equal(body.range.from, dayStr(-6));
  const todayRec = body.days[6];
  assert.equal(todayRec.pv, 5);
  assert.equal(todayRec.uv, 5);
  assert.equal(todayRec.downloads, 2);
  // 来源：direct（-/ 等）4，baidu 1
  assert.equal(body.sources.direct, 4);
  assert.equal(body.sources.baidu, 1);
  // topPages：/ =2、/about =2、/index.html =1（共 3 项）
  const pages = Object.fromEntries(body.topPages.map((x) => [x.path, x.pv]));
  assert.deepEqual(pages, { "/": 2, "/about": 2, "/index.html": 1 });
  // topReferers：仅 baidu 外部来源
  assert.deepEqual(body.topReferers, [{ host: "www.baidu.com", pv: 1 }]);
  // topIps：5 个页面 IP，各 1 次
  assert.equal(body.topIps.length, 5);
  assert.ok(body.logBytes > 0, "logBytes reflects parsed bytes");
  assert.ok(typeof body.generated_at === "string" && body.generated_at.endsWith("Z"));
});

test("site stats: eight source classifications over full window", async (t) => {
  const today = dayStr(0);
  const yest = dayStr(-1);
  const content = [
    logLine({ ip: "2.0.0.1", date: today, path: "/", referer: "-" }),                          // direct
    logLine({ ip: "2.0.0.2", date: today, path: "/", referer: "https://zenche.top/about" }),    // direct（本站）
    logLine({ ip: "2.0.0.3", date: yest, path: "/", referer: "https://www.baidu.com/s?wd=zenche" }),   // baidu
    logLine({ ip: "2.0.0.4", date: today, path: "/", referer: "https://www.sogou.com/web?query=x" }),  // sogou
    logLine({ ip: "2.0.0.5", date: today, path: "/", referer: "https://www.so.com/s?q=zenche" }),      // so360
    logLine({ ip: "2.0.0.6", date: today, path: "/", referer: "https://cn.bing.com/search?q=zenche" }), // bing
    logLine({ ip: "2.0.0.7", date: today, path: "/", referer: "https://www.google.com.hk/search?q=zenche" }), // google（*.google.*）
    logLine({ ip: "2.0.0.8", date: today, path: "/", referer: "https://weixin.qq.com/cgi-bin/readtemplate" }), // tencent（weixin.qq.com）
    logLine({ ip: "2.0.0.9", date: today, path: "/", referer: "https://news.qq.com/zt2026/zenche" }),   // tencent（*.qq.com）
    logLine({ ip: "2.0.0.10", date: today, path: "/", referer: "https://example.com/ref" }),     // otherExternal
  ].join("\n") + "\n";
  const app = await start({ siteLogContent: content });
  t.after(() => close(app));
  const body = await (await siteGet(app, 7)).json();
  assert.deepEqual(body.sources, {
    direct: 2, baidu: 1, sogou: 1, so360: 1, bing: 1, google: 1, tencent: 2, otherExternal: 1,
  });
  // 全周期聚合：baidu 行在昨天仍计入 sources 与 topReferers（8 个外部来源 host）
  assert.deepEqual(body.topReferers, [
    { host: "www.baidu.com", pv: 1 }, { host: "www.sogou.com", pv: 1 },
    { host: "www.so.com", pv: 1 }, { host: "cn.bing.com", pv: 1 },
    { host: "www.google.com.hk", pv: 1 }, { host: "weixin.qq.com", pv: 1 },
    { host: "news.qq.com", pv: 1 }, { host: "example.com", pv: 1 },
  ]);
  assert.equal(body.today.pv, 9, "yesterday's baidu row is outside today");
  assert.equal(body.days[5].pv, 1, "yesterday bucket has the baidu page view");
});

test("site stats: multi-day bucketing, UV per-day independent IPs", async (t) => {
  const today = dayStr(0);
  const y1 = dayStr(-1);
  const y2 = dayStr(-2);
  const content = [
    logLine({ ip: "3.0.0.1", date: y2, path: "/" }),
    logLine({ ip: "3.0.0.1", date: y1, path: "/" }),
    logLine({ ip: "3.0.0.2", date: y1, path: "/about" }),
    logLine({ ip: "3.0.0.1", date: today, path: "/" }),
    logLine({ ip: "3.0.0.3", date: today, path: "/" }),
  ].join("\n") + "\n";
  const app = await start({ siteLogContent: content });
  t.after(() => close(app));
  const body = await (await siteGet(app, 7)).json();
  const byDate = Object.fromEntries(body.days.map((d) => [d.date, d]));
  assert.equal(byDate[y2].pv, 1); assert.equal(byDate[y2].uv, 1);
  assert.equal(byDate[y1].pv, 2); assert.equal(byDate[y1].uv, 2, "same IP twice on one day -> UV counts once");
  assert.equal(byDate[today].pv, 2); assert.equal(byDate[today].uv, 2);
  assert.equal(body.today.uv, 2);
  // 同 IP 跨日独立计 UV（3.0.0.1 三天各计一次）
  assert.equal(body.today.pv, 2);
  assert.equal(body.days[4].uv, 1);
});

test("site stats: empty file yields zero values, not error", async (t) => {
  const app = await start({ siteLogContent: "" });
  t.after(() => close(app));
  const body = await (await siteGet(app, 7)).json();
  assert.equal(body.today.pv, 0);
  assert.equal(body.today.uv, 0);
  assert.equal(body.today.downloads, 0);
  assert.equal(body.today.botPv, 0);
  assert.equal(body.days.length, 7);
  assert.ok(body.days.every((d) => d.pv === 0 && d.uv === 0 && d.downloads === 0));
  assert.deepEqual(body.sources, { direct: 0, baidu: 0, sogou: 0, so360: 0, bing: 0, google: 0, tencent: 0, otherExternal: 0 });
  assert.deepEqual(body.topReferers, []);
  assert.deepEqual(body.topIps, []);
  assert.deepEqual(body.topPages, []);
  assert.equal(body.logBytes, 0);
});

test("site stats: missing log file -> 503 站点日志不可读", async (t) => {
  const app = await start();
  app.logState.exists = false; // stat/read 对日志路径抛 ENOENT
  t.after(() => close(app));
  const r = await siteGet(app);
  assert.equal(r.status, 503);
  const body = await r.json();
  assert.equal(body.error, "站点日志不可读");
});

test("site stats: mtime+size cache re-parses only on change", async (t) => {
  const today = dayStr(0);
  const app = await start({ siteLogContent: logLine({ ip: "4.0.0.1", date: today, path: "/" }) + "\n" });
  t.after(() => close(app));
  const b1 = await (await siteGet(app, 7)).json();
  assert.equal(b1.today.pv, 1);
  // 内容 + mtime 变化 → 缓存失效重析
  app.logState.content = [
    logLine({ ip: "4.0.0.1", date: today, path: "/" }),
    logLine({ ip: "4.0.0.2", date: today, path: "/" }),
  ].join("\n") + "\n";
  app.logState.mtimeMs += 1000;
  const b2 = await (await siteGet(app, 7)).json();
  assert.equal(b2.today.pv, 2, "cache invalidated on mtime+size change");
  assert.equal(b2.today.uv, 2);
});

test("site stats: top lists capped at 10/20/10 and sorted desc", async (t) => {
  const today = dayStr(0);
  const rows = [];
  const hostOf = (i) => `https://ref${i}.example.com/`;
  const pathOf = (i) => `/page-${i}`;
  // ip-a 3 次（host-a/page-a 各 3）；其余 21 个 ip 各 1 次，host/page 轮换 1..21
  for (let k = 0; k < 3; k++) {
    rows.push(logLine({ ip: "9.0.0.1", date: today, path: "/page-a", referer: "https://ref-a.example.com/" }));
  }
  for (let i = 1; i <= 21; i++) {
    rows.push(logLine({
      ip: `9.0.0.${i + 1}`, date: today,
      path: pathOf(i), referer: hostOf(i),
    }));
  }
  const app = await start({ siteLogContent: rows.join("\n") + "\n" });
  t.after(() => close(app));
  const body = await (await siteGet(app, 7)).json();
  assert.equal(body.topReferers.length, 10, "topReferers capped at 10");
  assert.equal(body.topReferers[0].host, "ref-a.example.com");
  assert.equal(body.topReferers[0].pv, 3);
  assert.equal(body.topIps.length, 20, "topIps capped at 20");
  assert.deepEqual(body.topIps[0], { ip: "9.0.0.1", pv: 3, lastSeen: body.topIps[0].lastSeen });
  assert.equal(body.topPages.length, 10, "topPages capped at 10");
  assert.deepEqual(body.topPages[0], { path: "/page-a", pv: 3 });
  // 总 PV = 3 + 21
  assert.equal(body.today.pv, 24);
  assert.equal(body.today.uv, 22, "uv = 22 distinct IPs");
});

test("site stats: >50MB tail cut discards the leading partial line (no ghost records)", async (t) => {
  const today = dayStr(0);
  // 构造 >50MB 大文件：content 视为尾部 50MB，第一行是被切割点截断的半行
  // （切割点落在 IP 字段内：完整行 "111.222.333.444 - - ..." 被切成 "111." + 其余），
  // 半行后缀 222.333.444 恰好满足行正则，若无丢弃逻辑会被解析成幽灵记录。
  const ghostLine = `222.333.444 - - [${tag(today)}] "GET /phantom HTTP/1.1" 200 512 "-" "Mozilla/5.0"`;
  const fullLine = logLine({ ip: "5.0.0.1", date: today, path: "/" });
  const content = ghostLine + "\n" + fullLine + "\n";
  const app = await start({ siteLogContent: content });
  app.logState.hugeSize = 55 * 1024 * 1024; // >50MB 触发截尾路径
  t.after(() => close(app));
  const body = await (await siteGet(app, 7)).json();
  // 半行必须被整体丢弃：无幽灵 IP/PV/页面
  assert.equal(body.today.pv, 1, "only the complete line counts");
  assert.equal(body.today.uv, 1);
  assert.ok(!body.topIps.some((x) => x.ip === "222.333.444"), "no ghost IP from partial line");
  assert.ok(!body.topPages.some((x) => x.path === "/phantom"), "no ghost page from partial line");
  assert.deepEqual(body.topIps[0], { ip: "5.0.0.1", pv: 1, lastSeen: body.topIps[0].lastSeen });
  assert.deepEqual(body.topPages, [{ path: "/", pv: 1 }]);
});

test("site stats: P3 — .html case-insensitive, google subdomain exact, protocol-less referer", async (t) => {
  const today = dayStr(0);
  const content = [
    logLine({ ip: "6.0.0.1", date: today, path: "/INDEX.HTML" }),                        // .HTML 大写 → 页面
    logLine({ ip: "6.0.0.2", date: today, path: "/data.JSON" }),                         // 资源扩展大小写不敏感剔除
    logLine({ ip: "6.0.0.3", date: today, path: "/", referer: "https://www.google.com.hk/search?q=zenche" }), // google
    logLine({ ip: "6.0.0.4", date: today, path: "/", referer: "https://notgoogle.com/x" }),   // 非 google（P3 防误伤）
    logLine({ ip: "6.0.0.5", date: today, path: "/", referer: "www.baidu.com/s?wd=zenche" }), // 无协议 referrer → baidu
  ].join("\n") + "\n";
  const app = await start({ siteLogContent: content });
  t.after(() => close(app));
  const body = await (await siteGet(app, 7)).json();
  assert.equal(body.today.pv, 4, "/INDEX.HTML + 3 page views (google/notgoogle/baidu)");
  assert.equal(body.sources.google, 1, "www.google.com.hk -> google");
  assert.equal(body.sources.otherExternal, 1, "notgoogle.com -> otherExternal (no false google)");
  assert.equal(body.sources.baidu, 1, "protocol-less www.baidu.com -> baidu");
  assert.equal(body.sources.direct, 1, "/INDEX.HTML has '-' referer -> direct");
  assert.ok(body.topPages.some((x) => x.path === "/INDEX.HTML"), "case-insensitive .html counted as page");
});
