import assert from "node:assert/strict";
import test from "node:test";
import { createApp, createUpdateService, selectReleaseAsset } from "../server.mjs";

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
