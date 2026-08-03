import { createHash } from "node:crypto";
import { createReadStream, existsSync, statSync } from "node:fs";
import { createServer as createHttpServer } from "node:http";
import { extname, isAbsolute, join, normalize, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL(".", import.meta.url));
const defaultRepository = "Tauber01/ZENCHE";
const defaultReleaseApi = `https://api.github.com/repos/${defaultRepository}/releases/latest`;
const defaultPort = 4173;
const defaultCacheTtlMs = 5 * 60 * 1000;

const contentTypes = new Map([
  [".html", "text/html; charset=utf-8"],
  [".css", "text/css; charset=utf-8"],
  [".js", "text/javascript; charset=utf-8"],
  [".mjs", "text/javascript; charset=utf-8"],
  [".json", "application/json; charset=utf-8"],
  [".webmanifest", "application/manifest+json; charset=utf-8"],
  [".svg", "image/svg+xml"],
  [".png", "image/png"],
]);

const platformAliases = new Map([
  ["ios", "ios"],
  ["ipados", "ios"],
  ["iphone", "ios"],
  ["ipad", "ios"],
  ["android", "android"],
  ["harmony", "harmonyos"],
  ["harmonyos", "harmonyos"],
  ["mac", "macos"],
  ["macos", "macos"],
  ["osx", "macos"],
  ["windows", "windows"],
  ["win", "windows"],
]);

const architectureAliases = new Map([
  ["x64", "x64"],
  ["amd64", "x64"],
  ["x86_64", "x64"],
  ["x86-64", "x64"],
  ["arm64", "arm64"],
  ["aarch64", "arm64"],
  ["arm", "arm64"],
  ["x86", "x86"],
  ["i386", "x86"],
]);

const channelNames = new Set(["stable", "beta", "preview", "nightly"]);

export function normalizeVersion(value) {
  const match = String(value ?? "").trim().replace(/^v/i, "").match(/\d+(?:\.\d+){0,3}(?:[-+][0-9A-Za-z.-]+)?/);
  return match ? match[0] : "0.0.0";
}

export function compareVersions(left, right) {
  const parse = (value) => {
    const [core, pre = ""] = normalizeVersion(value).split("-");
    const numbers = core.split(".").map((part) => Number(part) || 0);
    while (numbers.length < 4) numbers.push(0);
    return { numbers, pre };
  };
  const a = parse(left);
  const b = parse(right);
  for (let index = 0; index < a.numbers.length; index += 1) {
    if (a.numbers[index] !== b.numbers[index]) return a.numbers[index] > b.numbers[index] ? 1 : -1;
  }
  if (!a.pre && b.pre) return 1;
  if (a.pre && !b.pre) return -1;
  if (a.pre === b.pre) return 0;
  return a.pre.localeCompare(b.pre, undefined, { numeric: true });
}

function normalizePlatform(value) {
  const key = String(value ?? "").trim().toLowerCase();
  return platformAliases.get(key) || key || "unknown";
}

function normalizeArchitecture(value) {
  const key = String(value ?? "").trim().toLowerCase();
  return architectureAliases.get(key) || key || "unknown";
}

function safeRegex(value) {
  return String(value).replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

/** Select the best full installer asset for a normalized platform/architecture. */
export function selectReleaseAsset(assets, platform, architecture) {
  const normalizedPlatform = normalizePlatform(platform);
  const normalizedArchitecture = normalizeArchitecture(architecture);
  const candidates = (Array.isArray(assets) ? assets : []).filter(
    (asset) => asset && typeof asset.name === "string" && typeof asset.browser_download_url === "string",
  );
  const platformPattern = {
    ios: /(?:^|[-_.])ios(?:[-_.]|$)/i,
    android: /android/i,
    harmonyos: /harmony(?:os)?/i,
    macos: /macos|darwin|osx/i,
    windows: /windows|win32/i,
  }[normalizedPlatform];
  if (!platformPattern) return null;
  const platformCandidates = candidates.filter((asset) => platformPattern.test(asset.name));
  if (!platformCandidates.length) return null;
  if (normalizedArchitecture !== "unknown") {
    const architecturePattern = new RegExp(`(?:^|[-_.])${safeRegex(normalizedArchitecture)}(?:[-_.]|$)`, "i");
    const exact = platformCandidates.find((asset) => architecturePattern.test(asset.name));
    if (exact) return exact;

    // Never hand an arm64/x64-specific package to another architecture. A
    // package without an architecture marker is safe to use as a fallback.
    const markedArchitecture = /(?:^|[-_.])(?:x64|amd64|x86_64|x86-64|arm64|aarch64|x86|i386)(?:[-_.]|$)/i;
    const generic = platformCandidates.find((asset) => !markedArchitecture.test(asset.name));
    if (!generic) return null;
  }
  // Prefer installers over archives and checksum sidecars.
  return platformCandidates
    .filter((asset) => !/\.sha256(?:\.txt)?$/i.test(asset.name))
    .sort((a, b) => {
      const score = (name) => (/setup|installer|\.dmg$|\.apk$|\.hap$|\.ipa$/i.test(name) ? 0 : 1);
      return score(a.name) - score(b.name) || a.name.localeCompare(b.name);
    })[0] || null;
}

function releaseAnnouncement(release, configured) {
  const body = typeof release.body === "string" ? release.body.trim() : "";
  const firstHeading = body.match(/^#{1,3}\s+(.+)$/m)?.[1]?.trim();
  const announcement = configured && typeof configured === "object" ? configured : {};
  return {
    version: normalizeVersion(announcement.version || release.tag_name),
    title: String(announcement.title || release.name || firstHeading || `帧澈 ZENCHE ${normalizeVersion(release.tag_name)}`),
    body: String(announcement.body ?? body),
    published_at: announcement.published_at || release.published_at || release.created_at || null,
  };
}

function parseConfiguredAnnouncement(value) {
  if (!value) return null;
  try {
    const parsed = JSON.parse(value);
    return parsed && typeof parsed === "object" ? parsed : null;
  } catch {
    return null;
  }
}

function releaseUrlFor(repository, release) {
  if (typeof release.html_url === "string" && /^https:\/\//i.test(release.html_url)) return release.html_url;
  return `https://github.com/${repository}/releases`;
}

function assetUrlFor(asset, configuredBaseUrl) {
  if (!asset || typeof asset.browser_download_url !== "string") return null;
  const baseUrl = String(configuredBaseUrl || "").trim().replace(/\/+$/, "");
  if (!baseUrl) return asset.browser_download_url;
  try {
    return new URL(encodeURIComponent(asset.name), `${baseUrl}/`).toString();
  } catch {
    return asset.browser_download_url;
  }
}

function releaseApiFor(repository, channel, configured) {
  if (configured) return configured;
  if (channel === "stable") return `https://api.github.com/repos/${repository}/releases/latest`;
  return `https://api.github.com/repos/${repository}/releases?per_page=30`;
}

function selectChannelRelease(payload, channel) {
  if (!Array.isArray(payload)) return payload;
  if (channel === "stable") {
    return payload.find((release) => release && !release.draft && !release.prerelease) || payload.find((release) => release && !release.draft) || null;
  }
  return payload.find((release) => {
    if (!release || release.draft) return false;
    const prerelease = Boolean(release.prerelease);
    return channel === "nightly" ? prerelease : prerelease;
  }) || payload.find((release) => release && !release.draft) || null;
}

function normalizeQuery(query = {}) {
  const channelValue = String(query.channel || "stable").trim().toLowerCase();
  return {
    platform: normalizePlatform(query.platform),
    architecture: normalizeArchitecture(query.architecture || query.arch || query.architecture_name),
    channel: channelNames.has(channelValue) ? channelValue : "stable",
    currentVersion: query.current_version || query.currentVersion || query.version || "",
  };
}

export function createUpdateService(options = {}) {
  const fetchImpl = options.fetchImpl || globalThis.fetch;
  if (typeof fetchImpl !== "function") throw new Error("fetch is required for update service");
  const repository = options.repository || process.env.UPDATE_REPOSITORY || defaultRepository;
  const configuredApi = options.releaseApi || process.env.UPDATE_RELEASE_API_URL || "";
  const cacheTtlMs = Number(options.cacheTtlMs ?? process.env.UPDATE_CACHE_TTL_MS ?? defaultCacheTtlMs);
  const now = options.now || (() => Date.now());
  const configuredAnnouncement = options.announcement || parseConfiguredAnnouncement(process.env.UPDATE_ANNOUNCEMENT_JSON);
  const minimumVersion = options.minimumVersion ?? process.env.UPDATE_MINIMUM_SUPPORTED_VERSION ?? null;
  const assetBaseUrl = options.assetBaseUrl ?? process.env.UPDATE_ASSET_BASE_URL ?? "";
  const cache = new Map();
  const inFlight = new Map();

  async function fetchRelease(channel) {
    const url = releaseApiFor(repository, channel, configuredApi);
    const response = await fetchImpl(url, {
      headers: {
        Accept: "application/vnd.github+json",
        "User-Agent": `ZENCHE-update-service/${normalizeVersion(process.env.npm_package_version || "1.5.0")}`,
      },
    });
    if (!response || !response.ok) throw new Error(`GitHub release request failed (${response?.status || "unknown"})`);
    const payload = await response.json();
    const release = selectChannelRelease(payload, channel);
    if (!release || typeof release.tag_name !== "string") throw new Error("GitHub returned no usable release");
    return release;
  }

  async function getUpdate(query = {}) {
    const normalized = normalizeQuery(query);
    const key = normalized.channel;
    const timestamp = now();
    const previous = cache.get(key);
    if (previous && timestamp - previous.fetchedAt < cacheTtlMs) {
      return buildResponse(previous.release, normalized, previous.generatedAt, false);
    }
    try {
      let request = inFlight.get(normalized.channel);
      if (!request) {
        request = fetchRelease(normalized.channel).finally(() => inFlight.delete(normalized.channel));
        inFlight.set(normalized.channel, request);
      }
      const release = await request;
      const generatedAt = new Date(now()).toISOString();
      cache.set(key, { release, fetchedAt: now(), generatedAt });
      return buildResponse(release, normalized, generatedAt, false);
    } catch (error) {
      if (previous) return buildResponse(previous.release, normalized, previous.generatedAt, true);
      throw error;
    }
  }

  function buildResponse(release, normalized, generatedAt, stale) {
    const version = normalizeVersion(release.tag_name);
    const selectedAsset = selectReleaseAsset(release.assets, normalized.platform, normalized.architecture);
    const url = assetUrlFor(selectedAsset, assetBaseUrl) || releaseUrlFor(repository, release);
    const checksumAsset = selectedAsset && Array.isArray(release.assets)
      ? release.assets.find((asset) => new RegExp(`^${safeRegex(selectedAsset.name)}\\.sha256(?:\\.txt)?$`, "i").test(asset?.name || ""))
      : null;
    const sha256Source = selectedAsset?.sha256 || selectedAsset?.digest || checksumAsset?.sha256 || checksumAsset?.digest;
    const sha256 = typeof sha256Source === "string"
      ? sha256Source.replace(/^sha256:/i, "").toLowerCase()
      : null;
    const announcement = releaseAnnouncement(release, configuredAnnouncement);
    const updateAvailable = normalized.currentVersion ? compareVersions(version, normalized.currentVersion) > 0 : true;
    const response = {
      schema_version: 1,
      product: "ZENCHE",
      channel: normalized.channel,
      platform: normalized.platform,
      architecture: normalized.architecture,
      version,
      url,
      sha256,
      release_url: releaseUrlFor(repository, release),
      update_type: release.prerelease ? "preview" : "full",
      announcement,
      minimum_supported_version: minimumVersion ? normalizeVersion(minimumVersion) : null,
      generated_at: generatedAt,
      update_available: updateAvailable,
      stale,
      // Compatibility aliases for native clients and older integrations.
      downloadUrl: url,
      releaseUrl: releaseUrlFor(repository, release),
      updateAvailable,
      minimumVersion: minimumVersion ? normalizeVersion(minimumVersion) : null,
      asset: selectedAsset ? { name: selectedAsset.name, size: selectedAsset.size ?? null } : null,
    };
    return response;
  }

  return { getUpdate, clearCache: () => cache.clear(), get cache() { return cache; } };
}

function setSecurityHeaders(response, origin) {
  response.setHeader("Permissions-Policy", "camera=(self), microphone=(), geolocation=()");
  response.setHeader("Referrer-Policy", "no-referrer");
  response.setHeader("X-Content-Type-Options", "nosniff");
  response.setHeader("X-Frame-Options", "DENY");
  response.setHeader("Content-Security-Policy", "default-src 'self'; script-src 'self'; style-src 'self' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com; img-src 'self' blob: data:; media-src 'self' blob:; connect-src 'self'");
  response.setHeader("Access-Control-Allow-Origin", origin || "*");
  response.setHeader("Access-Control-Allow-Methods", "GET, HEAD, OPTIONS");
  response.setHeader("Access-Control-Allow-Headers", "Accept, Content-Type, User-Agent");
  response.setHeader("Vary", "Origin");
}

function json(response, status, value, requestMethod = "GET") {
  const body = JSON.stringify(value);
  response.statusCode = status;
  response.setHeader("Content-Type", "application/json; charset=utf-8");
  response.setHeader("Cache-Control", status === 200 ? "public, max-age=60, stale-while-revalidate=300" : "no-store");
  response.setHeader("ETag", `\"${createHash("sha256").update(body).digest("hex").slice(0, 24)}\"`);
  if (requestMethod !== "HEAD") response.end(body);
  else response.end();
}

export function createApp(options = {}) {
  const updateService = options.updateService || createUpdateService(options);
  const corsOrigin = options.corsOrigin || process.env.UPDATE_CORS_ORIGIN || "*";
  return createHttpServer(async (request, response) => {
    setSecurityHeaders(response, corsOrigin);
    let requestUrl;
    try {
      requestUrl = new URL(request.url || "/", `http://${request.headers.host || "localhost"}`);
    } catch {
      json(response, 400, { error: "invalid_url" }, request.method);
      return;
    }
    const pathname = requestUrl.pathname;
    if (request.method === "OPTIONS") {
      response.statusCode = 204;
      response.end();
      return;
    }
    if (pathname === "/healthz") {
      json(response, 200, { status: "ok", service: "zenche-update", generated_at: new Date().toISOString() }, request.method);
      return;
    }
    if (pathname === "/api/update" || pathname === "/api/updates") {
      if (request.method !== "GET" && request.method !== "HEAD") {
        json(response, 405, { error: "method_not_allowed" }, request.method);
        return;
      }
      try {
        const result = await updateService.getUpdate(Object.fromEntries(requestUrl.searchParams.entries()));
        const etag = `\"${createHash("sha256").update(JSON.stringify(result)).digest("hex").slice(0, 24)}\"`;
        response.setHeader("ETag", etag);
        if (request.headers["if-none-match"] === etag) {
          response.statusCode = 304;
          response.end();
          return;
        }
        json(response, 200, result, request.method);
      } catch (error) {
        json(response, 503, { error: "update_unavailable", message: "Update metadata is temporarily unavailable" }, request.method);
      }
      return;
    }
    if (request.method !== "GET" && request.method !== "HEAD") {
      response.statusCode = 405;
      response.setHeader("Allow", "GET, HEAD, OPTIONS");
      response.end("Method not allowed");
      return;
    }
    let pathnameDecoded;
    try {
      pathnameDecoded = decodeURIComponent(pathname);
    } catch {
      response.statusCode = 400;
      response.end("Bad request");
      return;
    }
    const safePath = normalize(pathnameDecoded).replace(/^(\.\.[/\\])+/, "");
    let filePath = join(root, safePath === "/" ? "index.html" : safePath);
    if (!filePath.startsWith(root) || !existsSync(filePath)) {
      response.statusCode = 404;
      response.setHeader("Content-Type", "text/plain; charset=utf-8");
      response.end("Not found");
      return;
    }
    if (statSync(filePath).isDirectory()) filePath = join(filePath, "index.html");
    response.setHeader("Content-Type", contentTypes.get(extname(filePath)) || "application/octet-stream");
    response.setHeader("Cache-Control", "no-cache");
    if (request.method === "HEAD") {
      response.statusCode = 200;
      response.end();
      return;
    }
    createReadStream(filePath)
      .on("error", () => {
        if (!response.headersSent) response.writeHead(500);
        response.end("Server error");
      })
      .pipe(response);
  });
}

export function startServer(options = {}) {
  const host = options.host || process.env.HOST || "127.0.0.1";
  const port = Number(options.port ?? process.env.PORT ?? defaultPort);
  const server = createApp(options);
  server.listen(port, host, () => {
    const displayHost = host === "0.0.0.0" ? "localhost" : host;
    console.log(`帧澈 ZENCHE is running at http://${displayHost}:${port}`);
  });
  return server;
}

const invokedPath = process.argv[1] ? resolve(process.argv[1]) : "";
if (invokedPath && isAbsolute(invokedPath) && invokedPath === resolve(fileURLToPath(import.meta.url))) {
  startServer();
}
