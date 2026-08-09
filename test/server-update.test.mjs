import assert from "node:assert/strict";
import test from "node:test";
import fs from "node:fs";
import path from "node:path";
import os from "node:os";
import { readFile } from "node:fs/promises";
import { createApp, createUpdateService, selectReleaseAsset, createUsageStore } from "../server.mjs";

const release = {
  tag_name: "v1.5.0",
  name: "帧澈 ZENCHE 1.5.0",
  body: "## 更新\n\n修复稳定性问题。",
  html_url: "https://github.com/Tauber01/ZENCHE/releases/tag/v1.5.0",
  published_at: "2026-08-02T00:00:00Z",
  assets: [
    {
      name: "ZENCHE-1.5.0-Windows-x64-Setup.exe",
      browser_download_url: "https://github.com/Tauber01/ZENCHE/releases/download/v1.5.0/ZENCHE-1.5.0-Windows-x64-Setup.exe",
      digest: "sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
      size: 123,
    },
    {
      name: "ZENCHE-1.5.0-Windows-x64-Setup.exe.sha256",
      browser_download_url: "https://github.com/Tauber01/ZENCHE/releases/download/v1.5.0/ZENCHE-1.5.0-Windows-x64-Setup.exe.sha256",
    },
    {
      name: "ZENCHE-1.5.0-macOS-arm64.dmg",
      browser_download_url: "https://github.com/Tauber01/ZENCHE/releases/download/v1.5.0/ZENCHE-1.5.0-macOS-arm64.dmg",
      size: 456,
    },
  ],
};

test("selectReleaseAsset prefers exact platform and architecture installers", () => {
  assert.equal(selectReleaseAsset(release.assets, "windows", "amd64")?.name, "ZENCHE-1.5.0-Windows-x64-Setup.exe");
  assert.equal(selectReleaseAsset(release.assets, "macOS", "aarch64")?.name, "ZENCHE-1.5.0-macOS-arm64.dmg");
  assert.equal(selectReleaseAsset(release.assets, "android", "arm64"), null);
});

test("update service normalizes versions, exposes schema aliases, and caches GitHub", async () => {
  let requests = 0;
  const service = createUpdateService({
    cacheTtlMs: 60_000,
    minimumVersion: "1.3.0",
    announcement: { title: "重要更新", body: "请升级后再连接相机。" },
    fetchImpl: async () => {
      requests += 1;
      return { ok: true, status: 200, json: async () => release };
    },
  });

  const first = await service.getUpdate({ platform: "windows", architecture: "x64", current_version: "1.4.1" });
  const second = await service.getUpdate({ platform: "windows", architecture: "x64", current_version: "1.5.0" });
  assert.equal(requests, 1);
  assert.equal(first.schema_version, 1);
  assert.equal(first.product, "ZENCHE");
  assert.equal(first.version, "1.5.0");
  assert.equal(first.update_available, true);
  assert.equal(first.updateAvailable, true);
  assert.equal(first.minimum_supported_version, "1.3.0");
  assert.equal(first.minimumVersion, "1.3.0");
  assert.match(first.url, /Windows-x64-Setup\.exe$/);
  assert.equal(first.downloadUrl, first.url);
  assert.equal(first.sha256, "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef");
  assert.equal(first.announcement.title, "重要更新");
  assert.equal(second.update_available, false);
});

test("update service can point selected assets at a self-hosted download base", async () => {
  const service = createUpdateService({
    assetBaseUrl: "https://zenche.top/downloads/",
    fetchImpl: async () => ({ ok: true, status: 200, json: async () => release }),
  });
  const result = await service.getUpdate({ platform: "windows", architecture: "x64" });
  assert.equal(result.url, "https://zenche.top/downloads/ZENCHE-1.5.0-Windows-x64-Setup.exe");
  assert.equal(result.release_url, release.html_url);
});

test("update service serves stale cache when GitHub is unavailable", async () => {
  let fail = false;
  const service = createUpdateService({
    cacheTtlMs: 0,
    now: () => 1_000,
    fetchImpl: async () => {
      if (fail) throw new Error("offline");
      return { ok: true, status: 200, json: async () => release };
    },
  });
  const fresh = await service.getUpdate({ platform: "macos", architecture: "arm64" });
  fail = true;
  const stale = await service.getUpdate({ platform: "macos", architecture: "arm64" });
  assert.equal(fresh.stale, false);
  assert.equal(stale.stale, true);
  assert.equal(stale.version, fresh.version);
});

async function withServer(options, fn) {
  const server = createApp(options);
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  const address = server.address();
  try {
    return await fn(`http://127.0.0.1:${address.port}`);
  } finally {
    await new Promise((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
  }
}

test("HTTP API supports canonical and compatibility routes with CORS and health checks", async () => {
  const updateService = createUpdateService({
    fetchImpl: async () => ({ ok: true, status: 200, json: async () => release }),
  });
  await withServer({ updateService, corsOrigin: "https://zenche.top" }, async (base) => {
    const update = await fetch(`${base}/api/update?platform=windows&architecture=x64&current_version=1.4.1`, {
      headers: { Origin: "https://zenche.top" },
    });
    assert.equal(update.status, 200);
    assert.equal(update.headers.get("access-control-allow-origin"), "https://zenche.top");
    assert.equal((await update.json()).version, "1.5.0");

    const alias = await fetch(`${base}/api/updates?platform=windows&architecture=x64`);
    assert.equal(alias.status, 200);
    assert.equal((await alias.json()).product, "ZENCHE");

    const health = await fetch(`${base}/healthz`);
    assert.equal(health.status, 200);
    assert.equal((await health.json()).status, "ok");

    const method = await fetch(`${base}/api/update`, { method: "POST" });
    assert.equal(method.status, 405);
  });
});

test("static server behavior remains available", async () => {
  await withServer({ updateService: createUpdateService({ fetchImpl: async () => ({ ok: true, json: async () => release }) }) }, async (base) => {
    const response = await fetch(`${base}/`);
    assert.equal(response.status, 200);
    assert.match(await response.text(), /帧澈 ZENCHE/);
  });
});

// ---------- L1: anonymous usage recording + /api/stats ----------

test("L1: /api/update records anonymous usage and /api/stats aggregates DAU/WAU", async () => {
  // 内存 usage store（注入空 fs 触发内存模式）——不改磁盘。
  const memoryFs = {};
  const usageStore = createUsageStore({ dataDir: "/tmp/zenche-usage-mem", fs: memoryFs });
  const release = { tag_name: "v1.5.9", assets: [] };
  await withServer(
    {
      updateService: createUpdateService({ fetchImpl: async () => ({ ok: true, json: async () => release }) }),
      usageStore,
      adminSecret: "test-stats-secret",
    },
    async (base) => {
      // 同一 installId 两次、另一 installId 一次 → 累计安装 2，DAU 2
      const u1 = "00000000-0000-4000-8000-000000000001";
      const u2 = "00000000-0000-4000-8000-000000000002";
      const url = (id) => `${base}/api/update?platform=windows&architecture=x64&current_version=1.5.8&installId=${id}`;
      for (let i = 0; i < 2; i++) {
        const r = await fetch(url(u1));
        assert.equal(r.status, 200);
      }
      await fetch(url(u2));

      const stats = await fetch(`${base}/api/stats`, { headers: { Authorization: "Bearer test-stats-secret" } });
      assert.equal(stats.status, 200);
      const body = await stats.json();
      assert.equal(body.totalInstallations, 2);
      assert.equal(body.dau, 2);
      assert.equal(body.wau, 2);
      assert.equal(body.byPlatform.windows, 2);
      assert.equal(body.byVersion["1.5.8"], 2);

      // 未授权（非回环视角）→ 403/401
      const forbidden = await fetch(`${base}/api/stats`);
      assert.ok(forbidden.status === 401 || forbidden.status === 403);
    },
  );
});

test("L1: usage recording never blocks update response on store failure", async () => {
  // fs 注入抛错 → record 静默 false，更新仍 200。
  const failingFs = {
    mkdirSync() { throw new Error("disk full"); },
  };
  const usageStore = createUsageStore({ dataDir: "/tmp/zenche-usage-fail", fs: failingFs });
  const release = { tag_name: "v1.5.9", assets: [] };
  await withServer(
    {
      updateService: createUpdateService({ fetchImpl: async () => ({ ok: true, json: async () => release }) }),
      usageStore,
    },
    async (base) => {
      const r = await fetch(`${base}/api/update?platform=macos&current_version=1.5.8&installId=whatever`);
      assert.equal(r.status, 200, "update must succeed even if usage record fails");
    },
  );
});

test("L1: usage files are per-day with tmp→rename durability (source)", async () => {
  const source = await readFile(new URL("../server.mjs", import.meta.url), "utf8");
  assert.match(source, /usage-\$\{dayKey\(ts\)\}\.json/, "per-day usage file naming");
  assert.match(source, /fsyncSync/, "durable write path must fsync");
  assert.match(source, /renameSync/, "durable write path must rename");
  assert.match(source, /sha256/, "fingerprint must be hashed");
});

// ---------- E1 安全修复：静态服务拒绝 /data/ 前缀（AI审查 门禁阻塞项） ----------

test("E1 security: static server rejects /data/ prefix (403) without auth", async () => {
  // 真实 data 目录落盘，验证 /data/usage-*.json 无鉴权不可达。
  const dataDir = path.join(os.tmpdir(), "zenche-usage-blocked");
  await withServer(
    {
      updateService: createUpdateService({ fetchImpl: async () => ({ ok: true, json: async () => release }) }),
      dataDir,
      adminSecret: "test-stats-secret",
    },
    async (base) => {
      // 造一个真实 usage 文件（无鉴权暴露即漏洞）。
      const usageStore = createUsageStore({ dataDir, fs: null });
      usageStore.record("windows", "1.5.9", "install-abc", Date.now());
      const usageFile = path.join(dataDir, `usage-${new Date().toISOString().slice(0, 10)}.json`);
      assert.equal(fs.existsSync(usageFile), true, "usage file must exist for the test");

      // /data/usage-*.json 无鉴权 → 403（不得放行）。
      const leaked = await fetch(`${base}/data/${path.basename(usageFile)}`);
      assert.equal(leaked.status, 403, "unauthenticated /data/ file must be forbidden");

      // /data 目录本身 → 403。
      const dir = await fetch(`${base}/data`);
      assert.equal(dir.status, 403);

      // /api/update 正常端点不受影响。
      const update = await fetch(`${base}/api/update?platform=windows&architecture=x64&current_version=1.5.8`);
      assert.equal(update.status, 200, "public /api/update must stay reachable");
    },
  );
});

test("E1 security: uppercase /DATA/ variant forbidden (case-insensitive FS)", async () => {
  const dataDir = path.join(os.tmpdir(), "zenche-usage-upper");
  await withServer(
    {
      updateService: createUpdateService({ fetchImpl: async () => ({ ok: true, json: async () => release }) }),
      dataDir,
      adminSecret: "test-stats-secret",
    },
    async (base) => {
      const usageStore = createUsageStore({ dataDir, fs: null });
      usageStore.record("windows", "1.5.9", "install-upper", Date.now());
      const usageFile = path.join(dataDir, `usage-${new Date().toISOString().slice(0, 10)}.json`);
      assert.equal(fs.existsSync(usageFile), true);

      // APFS 等大小写不敏感 FS 上 /DATA/ 变体此前可绕过 403——统一小写后封死。
      const upper = await fetch(`${base}/DATA/${path.basename(usageFile)}`);
      assert.equal(upper.status, 403, "uppercase /DATA/ variant must be forbidden");

      // 混合大小写同样封死。
      const mixed = await fetch(`${base}/DaTa/${path.basename(usageFile)}`);
      assert.equal(mixed.status, 403, "mixed-case /DaTa/ variant must be forbidden");
    },
  );
});

test("E1 security: normal static files outside /data still served", async () => {
  await withServer(
    {
      updateService: createUpdateService({ fetchImpl: async () => ({ ok: true, json: async () => release }) }),
    },
    async (base) => {
      const rootPage = await fetch(`${base}/`);
      assert.equal(rootPage.status, 200, "root static page must stay reachable");
      assert.match(await rootPage.text(), /帧澈 ZENCHE/);
    },
  );
});

// ---------- 自托管清单模式（UPDATE_RELEASE_MANIFEST，Tauber「更新全到服务器」） ----------

const sampleManifest = {
  version: "1.6.0",
  title: "v1.6.0",
  body: "自托管清单版本",
  published_at: "2026-08-07T00:00:00Z",
  release_url: "https://zenche.top/releases/v1.6.0",
  minimum_supported_version: "1.3.0",
  assets: {
    "windows/x64": { file: "ZENCHE-1.6.0-Windows-x64.zip", sha256: "a".repeat(64) },
    "windows": { file: "ZENCHE-1.6.0-Windows-x64-Setup.exe", sha256: "b".repeat(64) },
    "macos": { file: "ZENCHE-1.6.0-macOS-arm64.dmg", sha256: "c".repeat(64) },
  },
};

test("selfhost: v1.5.10 production manifest resolves all five native clients", async () => {
  const manifestPath = path.resolve("docs/releases/v1.5.10.json");
  const service = createUpdateService({
    fetchImpl: async () => { throw new Error("must not call GitHub"); },
    manifestPath,
    assetBaseUrl: "https://zenche.top/downloads",
  });
  const expected = [
    ["android", "arm64", "ZENCHE-1.5.10-android.apk", "dbc10522b49fe760b8b5e377b89a8060808942533944e22b97a59a13f2a4b96a"],
    ["ios", "arm64", "ZENCHE-1.5.10-ios-unsigned.ipa", "6fc610976147ae6cd38f5b92f97605dbcc7a090ff4b2d04d09ef649b6370679c"],
    ["harmony", "arm64", "ZENCHE-1.5.10-HarmonyOS.hap", "0bde3fbe6ab07be6247532f076774e65d2d41f1c9c4bf9ff38ac7182808f4989"],
    ["macos", "arm64", "ZENCHE-1.5.10-macOS-arm64.dmg", "01c68884754f5c9ac87415bb4387ec0d1f1c936bb46ee52565f0865c755b9d56"],
    ["windows", "x64", "ZENCHE-1.5.10-Windows-x64-Setup.exe", "6466b22519476425a0769a3b543cce27c6766be2c282008be1d0b466ad2c6f43"],
  ];

  for (const [platform, architecture, file, sha256] of expected) {
    const response = await service.getUpdate({
      platform,
      architecture,
      current_version: "1.5.9",
    });
    assert.equal(response.version, "1.5.10");
    assert.equal(response.url, `https://zenche.top/downloads/${file}`);
    assert.equal(response.sha256, sha256);
    assert.equal(response.update_available, true);
    assert.equal(response.stale, false);
  }
});

test("selfhost: manifest mode serves local manifest with zero GitHub requests", async () => {
  let githubCalls = 0;
  const manifestFile = path.join(os.tmpdir(), "zenche-release.json");
  fs.writeFileSync(manifestFile, JSON.stringify(sampleManifest));
  // fetchImpl 计数：manifest 模式不应被调用。
  const fetchImpl = async () => { githubCalls++; throw new Error("must not call GitHub"); };
  await withServer(
    {
      updateService: createUpdateService({
        fetchImpl,
        manifestPath: manifestFile,
        assetBaseUrl: "https://zenche.top/downloads",
      }),
    },
    async (base) => {
      // windows/x64 精确匹配
      const win = await (await fetch(`${base}/api/update?platform=windows&architecture=x64&current_version=1.5.9`)).json();
      assert.equal(win.version, "1.6.0");
      assert.equal(win.url, "https://zenche.top/downloads/ZENCHE-1.6.0-Windows-x64.zip");
      assert.equal(win.sha256, "a".repeat(64));
      assert.equal(win.update_available, true);
      // 门禁必修 1：清单 version/title 必须映射进 announcement（不得静默退回 0.0.0）。
      assert.equal(win.announcement.version, "1.6.0");
      assert.equal(win.announcement.title, "v1.6.0");
      assert.equal(win.announcement.body, "自托管清单版本");
      // 门禁必修 2：清单 minimum_supported_version 必须生效（强制升级闸门）。
      assert.equal(win.minimum_supported_version, "1.3.0");
      assert.equal(win.minimumVersion, "1.3.0");
      // windows 兜底（无 arch）
      const winFallback = await (await fetch(`${base}/api/update?platform=windows&current_version=1.5.9`)).json();
      assert.equal(winFallback.url, "https://zenche.top/downloads/ZENCHE-1.6.0-Windows-x64-Setup.exe");
      // macos 兜底
      const mac = await (await fetch(`${base}/api/update?platform=macos&current_version=1.5.9`)).json();
      assert.equal(mac.url, "https://zenche.top/downloads/ZENCHE-1.6.0-macOS-arm64.dmg");
      // 版本比较
      const noUpdate = await (await fetch(`${base}/api/update?platform=windows&current_version=1.6.0`)).json();
      assert.equal(noUpdate.update_available, false);
      // 无匹配平台 → url null 但版本仍给
      const linux = await (await fetch(`${base}/api/update?platform=linux&current_version=1.5.9`)).json();
      assert.equal(linux.url, null);
      assert.equal(linux.version, "1.6.0");
      // channel 任意值均回同一清单
      const beta = await (await fetch(`${base}/api/update?platform=windows&channel=beta`)).json();
      assert.equal(beta.version, "1.6.0");
    },
  );
  assert.equal(githubCalls, 0, "manifest mode must make zero GitHub requests");
  fs.rmSync(manifestFile, { force: true });
});

test("selfhost: manifest missing or corrupt -> 503 with no detail leak", async () => {
  const missingPath = path.join(os.tmpdir(), "zenche-missing-release.json");
  await withServer(
    {
      updateService: createUpdateService({
        fetchImpl: async () => { throw new Error("must not call GitHub"); },
        manifestPath: missingPath,
        assetBaseUrl: "https://zenche.top/downloads",
      }),
    },
    async (base) => {
      const r = await fetch(`${base}/api/update?platform=windows&current_version=1.5.9`);
      assert.equal(r.status, 503, "missing manifest -> 503");
      const body = await r.text();
      assert.ok(!body.includes("ENOENT"), "no internal detail leak");
    },
  );
  // 损坏 JSON
  const corruptPath = path.join(os.tmpdir(), "zenche-corrupt-release.json");
  fs.writeFileSync(corruptPath, "{ not json !!");
  await withServer(
    {
      updateService: createUpdateService({
        fetchImpl: async () => { throw new Error("must not call GitHub"); },
        manifestPath: corruptPath,
        assetBaseUrl: "https://zenche.top/downloads",
      }),
    },
    async (base) => {
      const r = await fetch(`${base}/api/update?platform=windows&current_version=1.5.9`);
      assert.equal(r.status, 503, "corrupt manifest -> 503");
    },
  );
  fs.rmSync(corruptPath, { force: true });
});

test("selfhost: manifest mode without asset base url -> 503 fail-closed", async () => {
  const manifestFile = path.join(os.tmpdir(), "zenche-release-nobase.json");
  fs.writeFileSync(manifestFile, JSON.stringify(sampleManifest));
  await withServer(
    {
      updateService: createUpdateService({
        fetchImpl: async () => { throw new Error("must not call GitHub"); },
        manifestPath: manifestFile,
        assetBaseUrl: "",
      }),
    },
    async (base) => {
      const r = await fetch(`${base}/api/update?platform=windows&current_version=1.5.9`);
      assert.equal(r.status, 503, "missing asset base url -> 503");
    },
  );
  fs.rmSync(manifestFile, { force: true });
});

test("selfhost: manifest hot-reloads on mtime change without restart", async () => {
  const manifestFile = path.join(os.tmpdir(), "zenche-release-hot.json");
  fs.writeFileSync(manifestFile, JSON.stringify({ ...sampleManifest, version: "1.6.0" }));
  await withServer(
    {
      updateService: createUpdateService({
        fetchImpl: async () => { throw new Error("must not call GitHub"); },
        manifestPath: manifestFile,
        assetBaseUrl: "https://zenche.top/downloads",
      }),
    },
    async (base) => {
      const v1 = await (await fetch(`${base}/api/update?platform=windows&current_version=1.0.0`)).json();
      assert.equal(v1.version, "1.6.0");
      // 改写清单（mtime 变化）→ 热加载新版本
      fs.writeFileSync(manifestFile, JSON.stringify({ ...sampleManifest, version: "1.7.0" }));
      // 确保 mtime 变化被感知（部分 FS 秒级粒度，强制 set）
      const now = new Date();
      fs.utimesSync(manifestFile, now, new Date(now.getTime() + 2000));
      const v2 = await (await fetch(`${base}/api/update?platform=windows&current_version=1.0.0`)).json();
      assert.equal(v2.version, "1.7.0", "hot reload picks up new manifest");
    },
  );
  fs.rmSync(manifestFile, { force: true });
});

test("selfhost: manifest without minimum_supported_version falls back to env/options", async () => {
  const manifestFile = path.join(os.tmpdir(), "zenche-release-nomin.json");
  const { minimum_supported_version: _omitted, ...manifestNoMin } = sampleManifest;
  fs.writeFileSync(manifestFile, JSON.stringify(manifestNoMin));
  await withServer(
    {
      updateService: createUpdateService({
        fetchImpl: async () => { throw new Error("must not call GitHub"); },
        manifestPath: manifestFile,
        assetBaseUrl: "https://zenche.top/downloads",
        minimumVersion: "1.4.0",
      }),
    },
    async (base) => {
      const r = await (await fetch(`${base}/api/update?platform=windows&current_version=1.5.9`)).json();
      assert.equal(r.minimum_supported_version, "1.4.0", "env/options minimum applies when manifest omits it");
      assert.equal(r.minimumVersion, "1.4.0");
    },
  );
  fs.rmSync(manifestFile, { force: true });
});
