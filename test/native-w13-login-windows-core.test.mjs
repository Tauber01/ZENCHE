import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

// W13-e（Windows）：邮箱账号系统登录墙「非前端核心」契约测试——认证地址固定
// HTTPS、DPAPI CurrentUser 单一会话包 + 原子替换、五接口 + JSON message 直达、
// /me 401/403 会话失效与网络/5xx 离线容忍、email-code 503 免码过渡态、超时/
// 取消/响应体上限/GET 无 body/Bearer、禁止重定向降级。
// 风格沿用 native-windows-* 系列：静态正则扫描 + 断言关键实现与契约分支。
// 可见 UI（MainWindow.xaml 等）不在本文件范围内（GPT5.6 独占接线）。

const root = new URL('../', import.meta.url);
const read = async (path) => readFile(new URL(path, root), 'utf8');

const AUTH_SERVICE = 'native/windows/Services/AuthService.cs';

test('windows auth: AuthService 存在且实现 5 个认证 API（纯服务层）', async () => {
  const source = await read(AUTH_SERVICE);

  assert.match(source, /public sealed class AuthService/);
  assert.match(source, /public Task<AuthResult> RequestEmailCodeAsync\(/);
  assert.match(source, /public async Task<AuthResult> RegisterAsync\(/);
  assert.match(source, /public async Task<AuthResult> LoginAsync\(/);
  assert.match(source, /public async Task<AuthResult> LogoutAsync\(/);
  assert.match(source, /public async Task<AuthResult> MeAsync\(/);
  // 会话存取 API 对 UI 接线可见
  assert.match(source, /public string\? GetToken\(\)/);
  assert.match(source, /public string GetEmail\(\)/);
  assert.match(source, /public bool HasSession\(\)/);
  assert.match(source, /public bool SaveSession\(string token, string email\)/);
  assert.match(source, /public bool ClearSession\(\)/);
  // 邮箱验证码请求必须带 purpose:"register"
  assert.match(source, /purpose\s*=\s*"register"/);
});

test('windows auth: 认证地址固定 HTTPS，构造后再校验，不继承历史 AI 地址', async () => {
  const source = await read(AUTH_SERVICE);

  assert.match(source, /public const string AuthServerUrl = "https:\/\/zenche\.top\/api";/);
  // 不出现任何明文 http 常量
  assert.doesNotMatch(source, /"http:\/\//);
  // 不继承历史 AI 地址/环境变量/设置覆盖（认证地址必须固定）
  assert.doesNotMatch(source, /(ai_server_url|AiServerUrl|AIServerUrl|aiApiUrl|AiApiUrl)/);
  assert.doesNotMatch(source, /Environment\.GetEnvironmentVariable/);
  // 构造 endpoint 后校验 HTTPS 才发送
  assert.match(source, /new Uri\(AuthServerUrl \+ path, UriKind\.Absolute\)/);
  assert.match(source, /Uri\.UriSchemeHttps/);
});

test('windows auth: token 用 DPAPI CurrentUser，token+email 合成单一会话包', async () => {
  const source = await read(AUTH_SERVICE);

  assert.match(source, /ProtectedData\.Protect\(/);
  assert.match(source, /ProtectedData\.Unprotect\(/);
  assert.match(source, /DataProtectionScope\.CurrentUser/);
  // 单一会话包：JSON v1 内同时含 token 与 email
  assert.match(source, /v = 1,\n\s*token,\n\s*email/);
  // 读取时解析同一包并校验 token 非空
  assert.match(source, /TryGetProperty\("token", out var token\)/);
  assert.match(source, /TryGetProperty\("email", out var emailNode\)/);
});

test('windows auth: 临时文件→原子替换，写入失败无半态且阻断登录墙', async () => {
  const source = await read(AUTH_SERVICE);

  // 先写临时文件，再同卷原子替换
  assert.match(source, /SessionPath \+ "\.tmp"/);
  assert.match(source, /File\.WriteAllBytes\(temporary, blob\)/);
  assert.match(source, /File\.Move\(temporary, SessionPath, overwrite: true\)/);
  // SaveSession 失败返回 false
  assert.match(source, /catch \(Exception error\)\n\s*\{\n\s*DiagnosticLogger\.Shared\.Warning\(\n\s*"auth", \$?"保存登录会话失败/);
  assert.match(source, /return false;/);
  // 登录/注册成功但落盘失败 → 500，不得放行登录墙
  assert.match(source, /"无法安全保存登录状态"/);
  // 服务器未返回 token → 500
  assert.match(source, /"服务器未返回登录态"/);
});

test('windows auth: 清理失败可观测（返回 false + 日志），退出登录残留态可提示', async () => {
  const source = await read(AUTH_SERVICE);

  // ClearSession 删除失败返回 false 并记日志
  assert.match(source, /if \(File\.Exists\(SessionPath\)\) File\.Delete\(SessionPath\);/);
  assert.match(source, /catch \(Exception error\)\n\s*\{\n\s*DiagnosticLogger\.Shared\.Warning\(\n\s*"auth", \$?"清除登录会话失败/);
  assert.match(source, /return false;/);
  // LogoutAsync 清理失败 → LocalCleanupFailed 标记 + 可观测文案
  assert.match(source, /LocalCleanupFailed = true/);
  assert.match(source, /"本地登录状态清理失败，请重试"/);
});

test('windows auth: 认证网络层——超时/取消/响应体上限/GET 无 body/Bearer/禁重定向', async () => {
  const source = await read(AUTH_SERVICE);

  // HttpClient 固定超时 + 连接超时
  assert.match(source, /Timeout = TimeSpan\.FromMilliseconds\(RequestTimeoutMs\)/);
  assert.match(source, /ConnectTimeout = TimeSpan\.FromMilliseconds\(ConnectTimeoutMs\)/);
  // 全链路 CancellationToken
  assert.match(source, /SendAsync\(\n\s*request,\n\s*HttpCompletionOption\.ResponseHeadersRead,\n\s*cancellationToken\)/);
  // 响应体上限
  assert.match(source, /MaxResponseBytes = 1_000_000/);
  assert.match(source, /if \(total > MaxResponseBytes\)/);
  // GET 不写 body：仅非 GET 且有载荷才附加
  assert.match(source, /if \(method != HttpMethod\.Get && bodyJson is not null\)/);
  // logout/me Bearer
  assert.match(source, /new AuthenticationHeaderValue\("Bearer", token\)/);
  // 禁止跟随重定向（防 HTTPS→HTTP 降级）
  assert.match(source, /AllowAutoRedirect = false/);
});

test('windows auth: 错误映射——message 直达、401/403 会话失效、网络/5xx 离线容忍', async () => {
  const source = await read(AUTH_SERVICE);

  // 服务端 error 直达
  assert.match(source, /TryGetProperty\("error", out var error\)/);
  // 401/403 标会话失效（路由守卫据此清 token 回登录墙）
  assert.match(source, /IsSessionInvalid => Status == 401 \|\| Status == 403/);
  // 网络失败(0)/5xx 离线容忍（不清会话）；协议失败明确排除
  assert.match(source, /IsOfflineTolerable =>\n\s*!IsProtocolError && \(Status == 0 \|\| Status >= 500\)/);
  // fallback 映射不互相吞掉
  assert.match(source, /401 => fallback401,/);
  assert.match(source, /403 => "账号已禁用",/);
  assert.match(source, /409 => "该邮箱已注册",/);
  assert.match(source, /429 => "请求过于频繁，请稍后再试",/);
  // me() 无 token → 401 未登录；401 兜底文案「登录已过期，请重新登录」
  assert.match(source, /new AuthResult\(401, "未登录", null, null, null\)/);
  assert.match(source, /"登录已过期，请重新登录"/);
});

test('windows auth: email-code 503 保留为免码过渡态专用结果', async () => {
  const source = await read(AUTH_SERVICE);

  // 503 不并入通用 5xx 兜底，专有文案直达
  assert.match(source, /503 => "邮件服务未配置",/);
  assert.match(source, /503 原样保留为「免码过渡态」专用结果/);
});

test('windows auth: register/login 防枚举 401 统一文案，注册免码过渡态省略 code', async () => {
  const source = await read(AUTH_SERVICE);

  // login/register 401 兜底统一「邮箱或密码错误」（服务端文案，防枚举）
  const login401 = (source.match(/"\/v1\/auth\/login",\n\s*body,\n\s*null,\n\s*"邮箱或密码错误"/g) ?? []).length;
  const register401 = (source.match(/"\/v1\/auth\/register",\n\s*body,\n\s*null,\n\s*"邮箱或密码错误"/g) ?? []).length;
  assert.equal(login401, 1, 'login 401 兜底应为「邮箱或密码错误」');
  assert.equal(register401, 1, 'register 401 兜底应为「邮箱或密码错误」');
  // 过渡态：code 为空时省略字段
  assert.match(source, /if \(!string\.IsNullOrWhiteSpace\(code\)\) payload\["code"\] = code\.Trim\(\);/);
  // 邮箱归一化：trim + lowercase
  assert.match(source, /email\.Trim\(\)\.ToLowerInvariant\(\)/);
});

test('windows auth: logout 无论服务端成败都清本地态；me() 200 刷新本地邮箱', async () => {
  const source = await read(AUTH_SERVICE);

  // logout：无 token 也返回 200 本地成功；有 token 带 Bearer POST
  assert.match(source, /new AuthResult\(200, "", null, null, null\)/);
  assert.match(source, /"\/v1\/auth\/logout",\n\s*"\{\}",\n\s*token,/);
  // 无论服务端成败都清本地登录态
  assert.match(source, /var cleared = ClearSession\(\);/);
  // me() 200 刷新本地邮箱（不触碰 token）
  assert.match(source, /if \(result\.IsSuccess && !string\.IsNullOrEmpty\(result\.Email\)\)\n\s*\{\n\s*SaveSession\(token, result\.Email!\);/);
});

test('windows auth: 协议失败关闭——HTML/畸形 JSON/缺字段不算成功也不算离线容忍', async () => {
  const source = await read(AUTH_SERVICE);

  // IsProtocolError 语义：既不算成功，也不算离线容忍
  assert.match(source, /public bool IsProtocolError \{ get; init; \}/);
  assert.match(source, /IsSuccess => !IsProtocolError && Status is >= 200 and < 300/);
  assert.match(source, /IsOfflineTolerable =>\n\s*!IsProtocolError && \(Status == 0 \|\| Status >= 500\)/);
  // Protocol 构造
  assert.match(source, /public static AuthResult Protocol\(string message, int status\)/);
  assert.match(source, /IsProtocolError = true/);
  // 现网反代 200 HTML 场景：Content-Type 校验
  assert.match(source, /response\.Content\.Headers\.ContentType\?\.MediaType/);
  assert.match(source, /"application\/json"/);
  assert.match(source, /服务器响应格式异常（非 JSON）/);
  assert.match(source, /服务器响应 JSON 格式异常/);
  assert.match(source, /服务器响应为空/);
  // 非 JSON 错误体（如网关 HTML 502）→ 协议失败，不能当真实 5xx 容忍
  assert.match(source, /服务器返回了非 JSON 错误响应/);
  // 响应体超限 → 协议失败
  assert.match(source, /服务器响应体过大/);
  assert.match(source, /\(string Text, bool Truncated\)/);
  assert.match(source, /return \("", true\);/);
});

test('windows auth: 2xx 必填业务字段校验（login/register=token+email，me=email）', async () => {
  const source = await read(AUTH_SERVICE);

  assert.match(source, /private enum RequiredShape/);
  assert.match(source, /TokenAndEmail,/);
  assert.match(source, /RequiredShape\.TokenAndEmail/);
  assert.match(source, /RequiredShape\.Email/);
  assert.match(source, /RequiredShape\.None/);
  // login/register：缺 token 或缺 account.email 判协议失败（不能建立会话）
  assert.match(source, /服务器响应缺少登录态字段/);
  // /me：缺 account.email 判协议失败（避免 UI 误判有效会话）
  assert.match(source, /服务器响应缺少账号信息/);
  // 解析出 email 的路径
  assert.match(source, /TryGetProperty\("email", out var emailNode\)/);
});

test('windows auth: forced-signed-out tombstone——登出先写标记，读取标记优先，新会话清标记后解除', async () => {
  const source = await read(AUTH_SERVICE);

  // 标记文件路径
  assert.match(source, /SignedOutMarkerFileName = "auth-signed-out\.dat"/);
  assert.match(source, /SignedOutMarkerPath/);
  // 读取时标记优先返回无会话（即使旧 DPAPI 文件残留也不复活）
  assert.match(source, /forced-signed-out 标记优先：登出后即使旧会话文件残留也不复活/);
  assert.match(source, /if \(File\.Exists\(SignedOutMarkerPath\)\) return null;/);
  // 登出：先原子写标记，再删会话文件
  assert.match(source, /var markerTemporary = SignedOutMarkerPath \+ "\.tmp";/);
  assert.match(source, /File\.WriteAllText\(\n\s*markerTemporary,/);
  assert.match(source, /File\.Move\(markerTemporary, SignedOutMarkerPath, overwrite: true\);/);
  const markerIndex = source.indexOf('File.Move(markerTemporary, SignedOutMarkerPath, overwrite: true);');
  const deleteIndex = source.indexOf('if (File.Exists(SessionPath)) File.Delete(SessionPath);');
  assert.ok(markerIndex !== -1 && deleteIndex !== -1 && markerIndex < deleteIndex,
    '登出必须先写标记再删会话文件');
  // 新会话：完整原子写入成功且标记清除成功后才解除
  assert.match(source, /if \(File\.Exists\(SignedOutMarkerPath\)\)\n\s*\{\n\s*File\.Delete\(SignedOutMarkerPath\);/);
});
