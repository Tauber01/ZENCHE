# ZENCHE Server-Side Automatic Updates

## 简体中文

`server.mjs` 提供只读更新元数据接口，默认从 GitHub Releases 获取最新版本并
继续提供原有静态 Web/PWA 文件服务。生产环境推荐把站点反向代理到
`https://zenche.top/api/update`；客户端也可使用兼容别名 `/api/updates`。

### 自托管清单模式（UPDATE_RELEASE_MANIFEST）

设置 `UPDATE_RELEASE_MANIFEST=<path release.json>` 后，`/api/update` 完全走
本地清单，**零 GitHub 请求**（落实「软件更新全都更新到服务器」）；未设置则
保持原 GitHub 模式（向后兼容）。

**清单形状**：

```json
{
  "version": "1.6.0",
  "title": "v1.6.0",
  "body": "发布说明",
  "published_at": "2026-08-07T00:00:00Z",
  "release_url": "https://zenche.top/releases/v1.6.0",
  "minimum_supported_version": "1.3.0",
  "assets": {
    "windows/x64": { "file": "ZENCHE-1.6.0-Windows-x64.zip", "sha256": "…64hex…" },
    "windows": { "file": "ZENCHE-1.6.0-Windows-x64-Setup.exe", "sha256": "…" },
    "macos": { "file": "ZENCHE-1.6.0-macOS-arm64.dmg", "sha256": "…" }
  }
}
```

- **匹配顺序**：`platform/arch` 精确 → `platform` 兜底；无匹配时 `url=null`
  且 `update_available` 仅按版本比较给出（前端自行处理无包情形）。
- **url** = `UPDATE_ASSET_BASE_URL + '/' + file`；清单模式下
  `UPDATE_ASSET_BASE_URL` 缺失 → **503 fail-closed**。
- **热加载**：清单按 mtime 感知，改文件即生效（无需重启进程）。
- **错误口径**：清单缺失/JSON 损坏 → **503** 且不外泄内部详情。
- `channel` 任意值均回同一清单（自托管只有 stable）。

**发布流程**：上传新包到下载目录 → 更新 `release.json`（版本/条目/sha256）
→ 无需重启（mtime 热加载）→ 客户端下次检查即见新版本。

### API

```text
GET /api/update?platform=windows&architecture=x64&channel=stable&current_version=1.4.1
GET /api/updates?...                         # 兼容别名
GET /healthz                                 # {"status":"ok"}
```

响应是 JSON（`schema_version: 1`）：

| 字段 | 说明 |
| --- | --- |
| `product` | 固定为 `ZENCHE` |
| `channel` | `stable`、`beta`、`preview` 或 `nightly` |
| `platform` / `architecture` | 规范化的平台和架构，例如 `windows` / `x64` |
| `version` | GitHub release 的版本号（去除前缀 `v`） |
| `url` | 匹配平台/架构的完整安装包；找不到时为 Release 页面 |
| `sha256` | GitHub asset 的 digest 或同名 `.sha256` 附件（可能为 `null`） |
| `release_url` | GitHub Release 页面 |
| `announcement` | `version`、`title`、`body`、`published_at` |
| `minimum_supported_version` | 由 `UPDATE_MINIMUM_SUPPORTED_VERSION` 配置 |
| `update_available` | 根据 `current_version` 进行语义版本比较 |
| `generated_at` / `stale` | 元数据生成时间及是否使用过期缓存 |

为兼容旧客户端，响应同时包含 `downloadUrl`、`releaseUrl`、`updateAvailable` 和
`minimumVersion` 别名。服务只返回下载 URL，不会代替原生平台覆盖应用或执行安装。

### 配置与部署

```sh
PORT=4173 HOST=127.0.0.1 npm start
```

可选环境变量：

- `HOST`：监听地址；容器或反向代理场景可设为 `0.0.0.0`。
- `PORT`：监听端口，默认 `4173`。
- `UPDATE_REPOSITORY`：GitHub 仓库，默认 `Tauber01/ZENCHE`。
- `UPDATE_RELEASE_API_URL`：自定义 release API（测试或 GitHub Enterprise）。
- `UPDATE_CACHE_TTL_MS`：GitHub 元数据缓存时长，默认 5 分钟。
- `UPDATE_CORS_ORIGIN`：CORS 来源，生产环境应设置为实际站点来源，而非 `*`。
- `UPDATE_ASSET_BASE_URL`：可选的自有静态下载目录，例如
  `https://zenche.top/downloads`。设置后，`url` 指向服务器上的同名安装包，
  而 `release_url` 仍保留 GitHub Release 页面。
- `UPDATE_MINIMUM_SUPPORTED_VERSION`：客户端最低支持版本，例如 `1.3.0`。
- `UPDATE_ANNOUNCEMENT_JSON`：覆盖公告的 JSON，例如
  `{"title":"重要更新","body":"请升级后再连接相机。"}`。

服务在缓存有效期内不会重复请求 GitHub；GitHub 暂时不可用时返回最近一次缓存并
标记 `stale: true`。没有任何缓存时返回 HTTP 503，响应不包含上游错误详情。生产
部署应使用 HTTPS 反向代理、限制管理面板（本服务没有写入 API），并监控 `/healthz`
和 5xx 比例。GitHub API 请求使用固定仓库、HTTPS、`Accept` 和 `User-Agent`，避免
把任意 URL 代理给客户端。

### 当前生产部署

更新服务已部署在 `ubuntu@101.34.255.115`：systemd 单元为
`zenche-update.service`，监听 `127.0.0.1:4174`；1Panel OpenResty 将 `/api/update`、
`/api/updates` 和 `/healthz` 反代到该服务，并从
`/opt/1panel/www/sites/zenche-top/index/downloads/` 提供 `/downloads/`。
`UPDATE_ASSET_BASE_URL` 已设置为 `https://zenche.top/downloads`。截至
2026-08-20，`1.5.14 / build 41` 自托管清单已在生产生效；公网健康检查、
两个 API 的五端更新响应与六个公开包的流式 SHA-256 均已通过。旧版资产继续保留，
生产备份位于 `/opt/zenche-update-backups/20260819T200402Z-v1514`。

## English

`server.mjs` exposes read-only update metadata, fetching the latest GitHub Release while
continuing to serve the existing static Web/PWA files. In production, proxy
`https://zenche.top/api/update`; `/api/updates` remains an alias for older clients.

### API

```text
GET /api/update?platform=windows&architecture=x64&channel=stable&current_version=1.4.1
GET /api/updates?...                         # compatibility alias
GET /healthz                                 # {"status":"ok"}
```

The JSON response uses `schema_version: 1` and includes `product`, normalized
`channel`/`platform`/`architecture`, `version`, an installer `url` (or the release page),
`sha256`, `release_url`, an `announcement` object, `minimum_supported_version`,
`update_available`, `generated_at`, and `stale`. Compatibility aliases
`downloadUrl`, `releaseUrl`, `updateAvailable`, and `minimumVersion` are also returned.
The service only describes downloads; native clients own installation and never overwrite
application files through this endpoint.

### Configuration and deployment

```sh
PORT=4173 HOST=127.0.0.1 npm start
```

Optional variables are `HOST`, `PORT`, `UPDATE_REPOSITORY` (default
`Tauber01/ZENCHE`), `UPDATE_RELEASE_API_URL`, `UPDATE_CACHE_TTL_MS` (default five
minutes), `UPDATE_CORS_ORIGIN`, `UPDATE_ASSET_BASE_URL` (for example
`https://zenche.top/downloads`), `UPDATE_MINIMUM_SUPPORTED_VERSION`, and
`UPDATE_ANNOUNCEMENT_JSON` (a JSON object with `title` and `body`). When an asset base URL
is set, `url` points to the same-named file on that server while `release_url` remains the
GitHub page. Metadata is cached per
channel, stale cache is served during GitHub outages, and a cache miss returns HTTP 503
without leaking upstream details. Put the service behind HTTPS, set a specific CORS origin,
monitor `/healthz` and 5xx rates, and do not expose a write/admin surface. GitHub requests
are restricted to the configured HTTPS repository API.

The production instance runs as `zenche-update.service` on `101.34.255.115` at
`127.0.0.1:4174`. 1Panel OpenResty proxies the API routes and serves `/downloads/` from
`/opt/1panel/www/sites/zenche-top/index/downloads/`. As of 2026-08-20, the
1.5.14 / build 41 self-hosted manifest is active in production. The public health endpoint,
both update routes for all five platforms, and streaming SHA-256 checks of all six public
packages passed. Older versioned assets remain available for rollback; the production backup
is stored at `/opt/zenche-update-backups/20260819T200402Z-v1514`.

## 日本語

`server.mjs` は読み取り専用の更新メタデータ API を提供し、GitHub Releases から
最新版を取得しながら既存の静的 Web/PWA ファイルも配信します。本番では
`https://zenche.top/api/update` をリバースプロキシし、旧クライアント向けに
`/api/updates` エイリアスも利用できます。

### API

```text
GET /api/update?platform=windows&architecture=x64&channel=stable&current_version=1.4.1
GET /api/updates?...                         # 互換エイリアス
GET /healthz                                 # {"status":"ok"}
```

JSON（`schema_version: 1`）には、`product`、正規化された channel/platform/
architecture、`version`、インストーラー `url`（なければリリースページ）、
`sha256`、`release_url`、`announcement`、`minimum_supported_version`、
`update_available`、`generated_at`、`stale` を含みます。旧クライアント向けに
`downloadUrl`、`releaseUrl`、`updateAvailable`、`minimumVersion` も返します。
この API はダウンロード情報だけを返し、インストールやアプリの上書きは各ネイティブ
クライアントが行います。

### 設定と配備

```sh
PORT=4173 HOST=127.0.0.1 npm start
```

任意の環境変数は `HOST`、`PORT`、`UPDATE_REPOSITORY`（既定値
`Tauber01/ZENCHE`）、`UPDATE_RELEASE_API_URL`、`UPDATE_CACHE_TTL_MS`（既定 5 分）、
`UPDATE_CORS_ORIGIN`、`UPDATE_MINIMUM_SUPPORTED_VERSION`、および公告用の
`UPDATE_ASSET_BASE_URL`（例：`https://zenche.top/downloads`）、
`UPDATE_ANNOUNCEMENT_JSON`（`title` と `body` を含む JSON）です。
`UPDATE_ASSET_BASE_URL` を設定すると、`url` はサーバー上の同名ファイルを指し、
`release_url` は GitHub ページのままです。メタデータは
channel ごとにキャッシュされ、GitHub が一時停止しても古いキャッシュを
`stale: true` で返します。キャッシュがない場合は上流の詳細を漏らさず HTTP 503 を
返します。HTTPS リバースプロキシを使用し、CORS を実際のサイトに限定し、`/healthz`
と 5xx 率を監視してください。GitHub へのアクセス先は設定された HTTPS リポジトリ
API に限定され、任意 URL のプロキシにはなりません。

本番インスタンスは `101.34.255.115` の `zenche-update.service` として稼働し、
`127.0.0.1:4174` を待ち受けます。1Panel OpenResty は API ルートをリバースプロキシし、
`/opt/1panel/www/sites/zenche-top/index/downloads/` から `/downloads/` を配信します。
2026-08-20 時点で、1.5.14 / build 41 の自社サーバー上のマニフェストが本番環境で有効です。
公開ヘルスチェック、2 つの更新ルートに対する 5 プラットフォームの応答、および公開中の
6 パッケージすべてのストリーミング SHA-256 を確認済みです。旧版アセットはロールバック用に保持し、
本番バックアップは `/opt/zenche-update-backups/20260819T200402Z-v1514` に保存しています。
