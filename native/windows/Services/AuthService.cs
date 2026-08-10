using System.IO;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace NikonLink.Windows.Services;

/// <summary>
/// W13-e 认证操作结果：Status 为 HTTP 状态码（0 = 网络失败/未发出请求）；
/// Message 为用户可读消息（服务端 error 直达，无 error 时按状态兜底）。
/// </summary>
public sealed record AuthResult(
    int Status,
    string Message,
    string? Token,
    string? Email,
    string? JsonText)
{
    /// <summary>
    /// 协议失败：2xx 但 Content-Type 非 JSON、畸形 JSON、缺必填字段、响应体超限，
    /// 或非 2xx 却返回非 JSON 错误体（如反代 HTML）。失败关闭，绝不能当作成功，
    /// 也绝不能进入离线容忍。
    /// </summary>
    public bool IsProtocolError { get; init; }

    /// <summary>
    /// 服务器响应成功但本地安全存储失败。此类结果必须与协议失败一样阻断登录墙，
    /// 且不得被 5xx/网络失败的离线容忍分支吞掉。
    /// </summary>
    public bool LocalPersistenceFailed { get; init; }

    public bool IsSuccess =>
        !IsProtocolError && !LocalPersistenceFailed && Status is >= 200 and < 300;

    public bool IsNetworkFailure => Status == 0 && !IsProtocolError;

    /// <summary>/me 401/403 = 会话失效（路由守卫据此清 token 回登录墙）。</summary>
    public bool IsSessionInvalid => Status == 401 || Status == 403;

    /// <summary>
    /// /me 场景离线容忍：仅真实网络失败(0)或真实服务端 5xx（JSON 错误体）不清会话。
    /// 协议失败（HTML/畸形 JSON/缺字段/超限）明确排除：不能当作离线放行。
    /// 注意：email-code 的 503 是「免码过渡态」专用结果，不属此列。
    /// </summary>
    public bool IsOfflineTolerable =>
        !IsProtocolError && !LocalPersistenceFailed && (Status == 0 || Status >= 500);

    /// <summary>退出登录时本地会话文件清理失败（需 UI 提示重试，避免假登录态残留）。</summary>
    public bool LocalCleanupFailed { get; init; }

    public static AuthResult Network(string message) =>
        new(0, message, null, null, null);

    public static AuthResult Protocol(string message, int status) =>
        new(status, message, null, null, null) { IsProtocolError = true };
}

/// <summary>
/// W13-e 邮箱账号系统客户端认证核心（Windows，纯服务层，无任何 UI 依赖）。
///
/// 候选服务端契约（W13-a；官网 HTTPS 反代仍待生产验收）：
///   POST /v1/auth/email-code {email, purpose:"register"} → 200 / 503(邮件服务未配置)
///   POST /v1/auth/register  {email, password, code?}     → 200 {token, account} / 400 / 409
///   POST /v1/auth/login     {email, password}            → 200 {token, account} / 401 / 403
///   POST /v1/auth/logout    (Bearer)                     → 200 / 401
///   GET  /v1/auth/me        (Bearer)                     → 200 {account, devices, activated} / 401 / 403
/// 错误响应体统一 {"error": "用户可读消息"}，Message 直达该文案。
///
/// 安全语义：
///  - 认证地址固定 https://zenche.top/api（const），构造 endpoint 后再校验 HTTPS，
///    不继承任何历史 AI 服务器地址、不接受环境变量/设置覆盖；
///  - token+email 经 Windows DPAPI（CurrentUser）加密为单一会话包（JSON v1），
///    临时文件 → 同卷原子替换落盘；写入失败不产生可读半态，且返回 false
///    阻断登录墙放行；登出走 forced-signed-out 标记（标记优先判定无会话），
///    即使旧会话文件删除失败残留也不能复活；清理失败可观测
///    （返回 false + DiagnosticLogger.Warning）；
///  - 协议失败关闭：2xx 必须 Content-Type: application/json 且满足必填业务字段
///    （login/register 需 token+account.email，/me 需 account.email），
///    HTML/畸形 JSON/缺字段/响应体超限/非 JSON 错误体一律判 IsProtocolError，
///    既不算成功也不算离线容忍；仅真实网络失败与真实服务端 5xx 才可离线容忍；
///  - HttpClient 固定超时、全链路 CancellationToken、响应体上限、GET 不写 body、
///    禁止跟随任何重定向（AllowAutoRedirect=false，防 HTTPS→HTTP 降级），
///    凭据（Bearer/密码）只发给 HTTPS。
/// </summary>
public sealed class AuthService
{
    public const string AuthServerUrl = "https://zenche.top/api";
    public const string ProtocolFailureMessage = "账号服务响应异常，请稍后重试";
    public const string LocalCleanupFailureMessage =
        "已退出，但本机登录信息未完全清除。请重新登录后再退出一次。";

    private const string SessionFileName = "auth-session.dat";
    private const string SignedOutMarkerFileName = "auth-signed-out.dat";
    private static readonly string SessionPath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "NikonLink",
        SessionFileName);

    /// <summary>
    /// forced-signed-out tombstone：登出先写此标记再删会话文件；读取时标记优先
    /// 返回无会话；新会话完整原子写入成功且标记清除成功后才解除。即使旧 DPAPI
    /// 文件删除失败残留，也不能复活登录态。
    /// </summary>
    private static readonly string SignedOutMarkerPath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "NikonLink",
        SignedOutMarkerFileName);

    private const int ConnectTimeoutMs = 15_000;
    private const int RequestTimeoutMs = 30_000;
    private const int MaxResponseBytes = 1_000_000;

    private static readonly HttpClient Client = CreateClient();

    // ── 本地会话存储：DPAPI CurrentUser 单一会话包 + 原子替换 ───────────────

    /// <summary>读取当前 session token；无会话或解密失败返回 null（不崩溃）。</summary>
    public string? GetToken()
    {
        var session = LoadSession();
        return session?.Token;
    }

    public string GetEmail()
    {
        var session = LoadSession();
        return session?.Email ?? "";
    }

    public bool HasSession()
    {
        var token = GetToken();
        return !string.IsNullOrEmpty(token);
    }

    /// <summary>
    /// 保存登录态：token+email 加密成单一会话包，临时文件→原子替换。
    /// 会话文件完整原子写入成功，且 forced-signed-out 标记清除成功后，
    /// 登录态才算解除（返回 true）。任何失败返回 false（调用方必须以
    /// 500「无法安全保存登录状态」拦截，不得放行登录墙）；任何失败都不留下可读半态。
    /// </summary>
    public bool SaveSession(string token, string email)
    {
        if (string.IsNullOrEmpty(token)) return false;
        try
        {
            var directory = Path.GetDirectoryName(SessionPath);
            if (directory is not null) Directory.CreateDirectory(directory);

            var temporary = SessionPath + ".tmp";
            var blob = ProtectSession(token, email ?? "");
            File.WriteAllBytes(temporary, blob);          // 先落临时文件
            File.Move(temporary, SessionPath, overwrite: true); // 同卷原子替换
            // 标记清除成功后才解除强制登出；清除失败则读取仍判定无会话（保守）。
            if (File.Exists(SignedOutMarkerPath))
            {
                File.Delete(SignedOutMarkerPath);
            }
            return true;
        }
        catch (Exception error)
        {
            DiagnosticLogger.Shared.Warning(
                "auth", $"保存登录会话失败：{error.Message}");
            TryDeleteTemporary();
            return false;
        }
    }

    /// <summary>
    /// 清除本地登录态（登出）：先持久化 forced-signed-out 标记，再删会话文件。
    /// 标记写入成功即保证后续读取判定无会话——即使会话文件删除失败残留旧 token，
    /// 也不能复活。任一步失败返回 false 并记日志（可观测，UI 可提示重试）。
    /// </summary>
    public bool ClearSession()
    {
        try
        {
            var directory = Path.GetDirectoryName(SessionPath);
            if (directory is not null) Directory.CreateDirectory(directory);

            // 1) 标记原子写入（tmp→move）：登出的先决条件
            var markerTemporary = SignedOutMarkerPath + ".tmp";
            File.WriteAllText(
                markerTemporary,
                "v1\n" + DateTimeOffset.UtcNow.ToUnixTimeSeconds() + "\n");
            File.Move(markerTemporary, SignedOutMarkerPath, overwrite: true);

            // 2) 再删会话文件；删除失败有标记兜底且可观测
            if (File.Exists(SessionPath)) File.Delete(SessionPath);
            TryDeleteTemporary();
            return true;
        }
        catch (Exception error)
        {
            DiagnosticLogger.Shared.Warning(
                "auth", $"清除登录会话失败：{error.Message}");
            TryDeleteTemporary();
            return false;
        }
    }

    private static void TryDeleteTemporary()
    {
        foreach (var temporary in new[] { SessionPath + ".tmp", SignedOutMarkerPath + ".tmp" })
        {
            try
            {
                if (File.Exists(temporary)) File.Delete(temporary);
            }
            catch (Exception error)
            {
                DiagnosticLogger.Shared.Warning(
                    "auth", $"清理会话临时文件失败：{error.Message}");
            }
        }
    }

    /// <summary>token+email 合成单一明文包（JSON v1）后整体 DPAPI 加密。</summary>
    private static byte[] ProtectSession(string token, string email)
    {
        var plaintext = JsonSerializer.SerializeToUtf8Bytes(new
        {
            v = 1,
            token,
            email
        });
        return ProtectedData.Protect(
            plaintext,
            null,
            DataProtectionScope.CurrentUser);
    }

    private static (string Token, string Email)? LoadSession()
    {
        try
        {
            // forced-signed-out 标记优先：登出后即使旧会话文件残留也不复活。
            if (File.Exists(SignedOutMarkerPath)) return null;
            if (!File.Exists(SessionPath)) return null;
            var blob = File.ReadAllBytes(SessionPath);
            var clear = ProtectedData.Unprotect(
                blob,
                null,
                DataProtectionScope.CurrentUser);
            using var document = JsonDocument.Parse(clear);
            var root = document.RootElement;
            if (!root.TryGetProperty("token", out var token) ||
                token.ValueKind != JsonValueKind.String ||
                string.IsNullOrEmpty(token.GetString()))
            {
                return null;
            }
            var email = root.TryGetProperty("email", out var emailNode) &&
                        emailNode.ValueKind == JsonValueKind.String
                ? emailNode.GetString() ?? ""
                : "";
            return (token.GetString()!, email);
        }
        catch (Exception error)
        {
            DiagnosticLogger.Shared.Warning(
                "auth", $"读取登录会话失败：{error.Message}");
            return null;
        }
    }

    // ── 认证网络层（异步，可 CancellationToken 取消） ───────────────────────

    /// <summary>POST /v1/auth/email-code {email, purpose:"register"}。</summary>
    /// <remarks>503 原样保留为「免码过渡态」专用结果（SMTP 未配置），不并入通用 5xx。</remarks>
    public Task<AuthResult> RequestEmailCodeAsync(
        string email,
        CancellationToken cancellationToken = default)
    {
        var body = JsonSerializer.Serialize(new
        {
            email = NormalizeEmail(email),
            purpose = "register"
        });
        return RequestAsync(
            HttpMethod.Post,
            "/v1/auth/email-code",
            body,
            null,
            "请先登录",
            RequiredShape.None,
            cancellationToken);
    }

    /// <summary>POST /v1/auth/register；code 为空时省略字段（过渡态免码注册）。</summary>
    public async Task<AuthResult> RegisterAsync(
        string email,
        string password,
        string? code,
        CancellationToken cancellationToken = default)
    {
        var payload = new Dictionary<string, string>
        {
            ["email"] = NormalizeEmail(email),
            ["password"] = password ?? ""
        };
        // code 为空时省略字段（过渡态免码注册），与 W13-a 契约一致。
        if (!string.IsNullOrWhiteSpace(code)) payload["code"] = code.Trim();
        var body = JsonSerializer.Serialize(payload);
        var result = await RequestAsync(
            HttpMethod.Post,
            "/v1/auth/register",
            body,
            null,
            "邮箱或密码错误",
            RequiredShape.TokenAndEmail,
            cancellationToken);
        return result.IsSuccess ? SaveAndReturn(result, email) : result;
    }

    /// <summary>POST /v1/auth/login；401 统一「邮箱或密码错误」（防枚举，服务端文案）。</summary>
    public async Task<AuthResult> LoginAsync(
        string email,
        string password,
        CancellationToken cancellationToken = default)
    {
        var body = JsonSerializer.Serialize(new
        {
            email = NormalizeEmail(email),
            password = password ?? ""
        });
        var result = await RequestAsync(
            HttpMethod.Post,
            "/v1/auth/login",
            body,
            null,
            "邮箱或密码错误",
            RequiredShape.TokenAndEmail,
            cancellationToken);
        return result.IsSuccess ? SaveAndReturn(result, email) : result;
    }

    /// <summary>POST /v1/auth/logout（Bearer）；无论服务端成败都清除本地登录态。</summary>
    public async Task<AuthResult> LogoutAsync(
        CancellationToken cancellationToken = default)
    {
        var token = GetToken();
        var result = token is null
            ? new AuthResult(200, "", null, null, null)
            : await RequestAsync(
                HttpMethod.Post,
                "/v1/auth/logout",
                "{}",
                token,
                "未登录",
                RequiredShape.None,
                cancellationToken);

        var cleared = ClearSession();
        if (!cleared)
        {
            DiagnosticLogger.Shared.Warning(
                "auth", "退出登录后本地会话清理失败（可能残留假登录态）");
            return result with
            {
                LocalCleanupFailed = true,
                Message = LocalCleanupFailureMessage
            };
        }
        return result;
    }

    /// <summary>
    /// GET /v1/auth/me（Bearer）。200 = 有效并刷新本地邮箱；
    /// 401/403 = 会话失效（IsSessionInvalid，交由路由守卫清 token 回登录墙）；
    /// 网络失败/5xx = IsOfflineTolerable（离线容忍，不清会话）。
    /// </summary>
    public async Task<AuthResult> MeAsync(
        CancellationToken cancellationToken = default)
    {
        var token = GetToken();
        if (token is null)
        {
            return new AuthResult(401, "未登录", null, null, null);
        }
        var result = await RequestAsync(
            HttpMethod.Get,
            "/v1/auth/me",
            null,
            token,
            "登录已过期，请重新登录",
            RequiredShape.Email,
            cancellationToken);
        if (result.IsSuccess && !string.IsNullOrEmpty(result.Email))
        {
            if (!SaveSession(token, result.Email!))
            {
                return result with
                {
                    LocalPersistenceFailed = true,
                    Message = "无法安全保存登录状态"
                };
            }
        }
        return result;
    }

    /// <summary>登录/注册成功后的收尾：必须落盘成功才放行登录墙。</summary>
    private AuthResult SaveAndReturn(AuthResult result, string fallbackEmail)
    {
        var token = result.Token;
        if (string.IsNullOrEmpty(token))
        {
            return AuthResult.Protocol(ProtocolFailureMessage, result.Status);
        }
        var email = string.IsNullOrEmpty(result.Email)
            ? NormalizeEmail(fallbackEmail)
            : result.Email!;
        if (!SaveSession(token, email))
        {
            return new AuthResult(500, "无法安全保存登录状态", null, null, null);
        }
        return result;
    }

    /// <summary>2xx 响应的必填业务字段形状；缺字段一律判协议失败（失败关闭）。</summary>
    private enum RequiredShape
    {
        /// <summary>仅需合法 JSON（email-code 200、logout 200）。</summary>
        None,

        /// <summary>login/register 200：必须同时含非空 token 与 account.email。</summary>
        TokenAndEmail,

        /// <summary>/me 200：必须含非空 account.email。</summary>
        Email
    }

    private async Task<AuthResult> RequestAsync(
        HttpMethod method,
        string path,
        string? bodyJson,
        string? token,
        string fallback401,
        RequiredShape shape,
        CancellationToken cancellationToken)
    {
        // 地址固定 + 构造后再校验 HTTPS：杜绝重定向降级或向非 HTTPS 发凭据。
        var endpoint = new Uri(AuthServerUrl + path, UriKind.Absolute);
        if (!string.Equals(
                endpoint.Scheme,
                Uri.UriSchemeHttps,
                StringComparison.OrdinalIgnoreCase))
        {
            return AuthResult.Network("账号服务需要安全连接");
        }

        try
        {
            using var request = new HttpRequestMessage(method, endpoint);
            request.Headers.Accept.ParseAdd("application/json");
            if (!string.IsNullOrEmpty(token))
            {
                request.Headers.Authorization =
                    new AuthenticationHeaderValue("Bearer", token);
            }
            // GET 不写 body；仅非 GET/HEAD 且存在载荷时才附加。
            if (method != HttpMethod.Get && bodyJson is not null)
            {
                request.Content =
                    new StringContent(bodyJson, Encoding.UTF8, "application/json");
            }

            using var response = await Client.SendAsync(
                request,
                HttpCompletionOption.ResponseHeadersRead,
                cancellationToken);
            var status = (int)response.StatusCode;
            var (text, truncated) = await ReadBodyAsync(response, cancellationToken);
            if (truncated)
            {
                // 超限响应（无论 2xx/5xx）都是协议异常：失败关闭，不进离线容忍。
                return AuthResult.Protocol(ProtocolFailureMessage, status);
            }

            // 服务端契约：成功与错误响应体统一 JSON（{"error": ...}）。
            // 现网反代对未知路径会以 200 返回官网 HTML，必须按 Content-Type 拒绝。
            var mediaType = response.Content.Headers.ContentType?.MediaType;
            var isJson = string.Equals(
                mediaType,
                "application/json",
                StringComparison.OrdinalIgnoreCase);

            if (status is >= 200 and < 300)
            {
                return ParseSuccess(status, text, isJson, shape);
            }
            if (!isJson)
            {
                // 非 JSON 错误体（如网关/反代 HTML）：非真实服务端错误，判协议失败。
                return AuthResult.Protocol(ProtocolFailureMessage, status);
            }
            return new AuthResult(
                status,
                ExtractError(text) ?? FallbackMessage(status, fallback401),
                null,
                null,
                null);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            return AuthResult.Network("请求已取消");
        }
        catch (Exception error)
        {
            DiagnosticLogger.Shared.Warning(
                "auth", $"认证请求失败（{method} {path}）：{error.Message}");
            return AuthResult.Network("网络连接失败，请检查网络后重试");
        }
    }

    /// <summary>
    /// 2xx 校验并解析：Content-Type 必须为 JSON、正文必须可解析，
    /// 且按业务形状满足必填字段。HTML、畸形 JSON、缺字段一律协议失败。
    /// </summary>
    private static AuthResult ParseSuccess(
        int status,
        string text,
        bool isJson,
        RequiredShape shape)
    {
        if (!isJson)
        {
            return AuthResult.Protocol(ProtocolFailureMessage, status);
        }
        if (string.IsNullOrEmpty(text))
        {
            return AuthResult.Protocol(ProtocolFailureMessage, status);
        }

        JsonDocument document;
        try
        {
            document = JsonDocument.Parse(text);
        }
        catch (JsonException)
        {
            return AuthResult.Protocol(ProtocolFailureMessage, status);
        }
        using (document)
        {
            var root = document.RootElement;
            string? token = null;
            string? email = null;
            if (root.TryGetProperty("token", out var tokenNode) &&
                tokenNode.ValueKind == JsonValueKind.String)
            {
                token = tokenNode.GetString();
            }
            if (root.TryGetProperty("account", out var account) &&
                account.ValueKind == JsonValueKind.Object &&
                account.TryGetProperty("email", out var emailNode) &&
                emailNode.ValueKind == JsonValueKind.String)
            {
                email = emailNode.GetString();
            }

            switch (shape)
            {
                case RequiredShape.TokenAndEmail:
                    // login/register：缺 token 或缺 account.email 都不能建立会话。
                    if (string.IsNullOrEmpty(token) || string.IsNullOrEmpty(email))
                    {
                        return AuthResult.Protocol(ProtocolFailureMessage, status);
                    }
                    break;
                case RequiredShape.Email:
                    // /me：缺 account.email 不能确认有效会话（避免 UI 误判）。
                    if (string.IsNullOrEmpty(email))
                    {
                        return AuthResult.Protocol(ProtocolFailureMessage, status);
                    }
                    break;
                case RequiredShape.None:
                    break;
            }
            return new AuthResult(status, "", token, email, text);
        }
    }

    private static string? ExtractError(string text)
    {
        if (string.IsNullOrEmpty(text)) return null;
        try
        {
            using var document = JsonDocument.Parse(text);
            if (document.RootElement.TryGetProperty("error", out var error) &&
                error.ValueKind == JsonValueKind.String)
            {
                var message = error.GetString();
                return string.IsNullOrEmpty(message) ? null : message;
            }
        }
        catch (JsonException)
        {
        }
        return null;
    }

    private static string FallbackMessage(int status, string fallback401) =>
        status switch
        {
            400 => "请求参数有误",
            401 => fallback401,
            403 => "账号已禁用",
            404 => "接口不存在",
            409 => "该邮箱已注册",
            429 => "请求过于频繁，请稍后再试",
            503 => "邮件服务未配置",
            _ => $"API 服务返回错误 {status}"
        };

    /// <summary>
    /// 响应体上限读取：防意外大响应撑爆内存；超限丢弃正文并返回 Truncated=true
    /// （由调用方判协议失败，失败关闭）。
    /// </summary>
    private static async Task<(string Text, bool Truncated)> ReadBodyAsync(
        HttpResponseMessage response,
        CancellationToken cancellationToken)
    {
        await using var stream = await response.Content.ReadAsStreamAsync(
            cancellationToken);
        using var buffer = new MemoryStream();
        var chunk = new byte[8192];
        var total = 0;
        int read;
        while ((read = await stream.ReadAsync(chunk, cancellationToken)) > 0)
        {
            total += read;
            if (total > MaxResponseBytes)
            {
                return ("", true);
            }
            buffer.Write(chunk, 0, read);
        }
        return (Encoding.UTF8.GetString(buffer.ToArray()), false);
    }

    private static string NormalizeEmail(string email)
    {
        if (string.IsNullOrWhiteSpace(email)) return "";
        return email.Trim().ToLowerInvariant();
    }

    private static HttpClient CreateClient()
    {
        var handler = new SocketsHttpHandler
        {
            // 禁止跟随任何重定向（防 HTTPS→HTTP 降级）；凭据只发向固定 HTTPS。
            AllowAutoRedirect = false,
            ConnectTimeout = TimeSpan.FromMilliseconds(ConnectTimeoutMs),
            PooledConnectionLifetime = TimeSpan.FromMinutes(10)
        };
        var client = new HttpClient(handler)
        {
            Timeout = TimeSpan.FromMilliseconds(RequestTimeoutMs)
        };
        client.DefaultRequestHeaders.Accept.ParseAdd("application/json");
        client.DefaultRequestHeaders.UserAgent.ParseAdd("ZENCHE-Windows/1.5.11");
        return client;
    }
}
