package com.tauber.nikonlink;

import android.content.Context;
import android.content.SharedPreferences;
import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyProperties;
import android.util.Base64;

import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.security.KeyStore;
import java.util.Locale;

import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;

/**
 * W13-d 邮箱账号系统客户端认证（Android）。
 *
 * 零依赖原则：不引入 androidx.security:security-crypto，改为手写
 * AndroidKeyStore AES-256-GCM 加密 session token 后落 SharedPreferences——
 * 满足派工「Keystore 加密的 EncryptedSharedPreferences」的实质（token 由
 * 系统 Keystore 密钥加密，密钥不出安全硬件/系统级存储），且 minSdk 26 原生
 * 支持，不动 build.gradle 依赖面。
 *
 * 候选服务端契约（W13-a；官网 HTTPS 反代仍待生产验收）：
 *   POST /v1/auth/email-code {email, purpose:"register"}  → 200 / 503(邮件服务未配置)
 *   POST /v1/auth/register  {email, password, code?}      → 200 {token, account} / 400 / 409
 *   POST /v1/auth/login     {email, password}             → 200 {token, account} / 401 / 403
 *   POST /v1/auth/logout    (Bearer)                      → 200 / 401
 *   GET  /v1/auth/me        (Bearer)                      → 200 {account, devices, activated} / 401 / 403
 * 错误响应体统一 {"error": "用户可读消息"}。
 */
public final class AuthManager {
    private static final String PREFS_NAME = "nikon-link";
    private static final String PREFS_TOKEN = "auth_token_enc";
    private static final String PREFS_EMAIL = "auth_email";
    private static final String KEY_ALIAS = "zenche_auth_token_key";
    private static final String KEYSTORE_PROVIDER = "AndroidKeyStore";
    private static final String AES_GCM = "AES/GCM/NoPadding";
    private static final int GCM_TAG_BITS = 128;
    private static final int GCM_IV_BYTES = 12;
    private static final int CONNECT_TIMEOUT_MS = 15_000;
    private static final int READ_TIMEOUT_MS = 30_000;
    private static final int MAX_RESPONSE_BYTES = 64 * 1024;
    private static final String AUTH_SERVER_URL = "https://zenche.top/api";
    private static final String SIGNED_OUT_MARKER = "auth-signed-out";

    /** 认证操作结果：status 为 HTTP 状态码（0 = 网络失败）；message 为用户可读消息。 */
    public static final class AuthResult {
        public final int status;
        public final String message;
        public final String token;
        public final String email;
        public final JSONObject json;
        public final boolean protocolError;
        public final boolean localCleanupFailed;

        public AuthResult(
                int status,
                String message,
                String token,
                String email,
                JSONObject json) {
            this(status, message, token, email, json, false, false);
        }

        private AuthResult(
                int status,
                String message,
                String token,
                String email,
                JSONObject json,
                boolean protocolError,
                boolean localCleanupFailed) {
            this.status = status;
            this.message = message;
            this.token = token;
            this.email = email;
            this.json = json;
            this.protocolError = protocolError;
            this.localCleanupFailed = localCleanupFailed;
        }

        static AuthResult protocolFailure() {
            return new AuthResult(
                    502, "账号服务响应格式错误", null, null, null, true, false);
        }

        AuthResult withLocalCleanupFailure() {
            return new AuthResult(
                    status,
                    "已退出，但本机登录信息未完全清除。请重新登录后再退出一次。",
                    token,
                    email,
                    json,
                    protocolError,
                    true);
        }
    }

    private final Context context;

    public AuthManager(Context context) {
        this.context = context.getApplicationContext();
    }

    private SharedPreferences prefs() {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
    }

    private String serverUrl() {
        return AUTH_SERVER_URL;
    }

    private static String normalizeEmail(String email) {
        if (email == null) return "";
        return email.trim().toLowerCase(Locale.ROOT);
    }

    // ── Keystore 加密 token 存取 ────────────────────────────────────────────

    private SecretKey getOrCreateKey() throws Exception {
        KeyStore keyStore = KeyStore.getInstance(KEYSTORE_PROVIDER);
        keyStore.load(null);
        KeyStore.Entry entry = keyStore.getEntry(KEY_ALIAS, null);
        if (entry instanceof KeyStore.SecretKeyEntry) {
            return ((KeyStore.SecretKeyEntry) entry).getSecretKey();
        }
        KeyGenerator generator = KeyGenerator.getInstance(
                KeyProperties.KEY_ALGORITHM_AES, KEYSTORE_PROVIDER);
        generator.init(new KeyGenParameterSpec.Builder(
                KEY_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT | KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .build());
        return generator.generateKey();
    }

    /** AES-256-GCM 加密；输出 base64(iv || ciphertext)。 */
    public String encrypt(String plaintext) throws Exception {
        Cipher cipher = Cipher.getInstance(AES_GCM);
        cipher.init(Cipher.ENCRYPT_MODE, getOrCreateKey());
        byte[] ciphertext = cipher.doFinal(
                plaintext.getBytes(StandardCharsets.UTF_8));
        byte[] iv = cipher.getIV();
        ByteArrayOutputStream out = new ByteArrayOutputStream(
                iv.length + ciphertext.length);
        out.write(iv);
        out.write(ciphertext);
        return Base64.encodeToString(out.toByteArray(), Base64.NO_WRAP);
    }

    /** 解密 encrypt() 的输出；GCM 默认 12 字节 IV（AndroidKeyStore 固定）。 */
    public String decrypt(String encoded) throws Exception {
        byte[] blob = Base64.decode(encoded, Base64.NO_WRAP);
        if (blob.length <= GCM_IV_BYTES) throw new IllegalArgumentException("密文格式无效");
        byte[] iv = java.util.Arrays.copyOfRange(blob, 0, GCM_IV_BYTES);
        byte[] ciphertext = java.util.Arrays.copyOfRange(
                blob, GCM_IV_BYTES, blob.length);
        Cipher cipher = Cipher.getInstance(AES_GCM);
        cipher.init(Cipher.DECRYPT_MODE, getOrCreateKey(),
                new GCMParameterSpec(GCM_TAG_BITS, iv));
        return new String(cipher.doFinal(ciphertext), StandardCharsets.UTF_8);
    }

    /** 读取当前 session token；无 token 或解密失败返回 null（不崩溃）。 */
    public String getToken() {
        if (signedOutMarker().exists()) return null;
        String encoded = prefs().getString(PREFS_TOKEN, "");
        if (encoded == null || encoded.isEmpty()) return null;
        try {
            String token = decrypt(encoded);
            return token == null || token.isEmpty() ? null : token;
        } catch (Exception error) {
            return null;
        }
    }

    public String getEmail() {
        return prefs().getString(PREFS_EMAIL, "");
    }

    public boolean hasSession() {
        String token = getToken();
        return token != null && !token.isEmpty();
    }

    /** 保存登录态：token Keystore 加密存储，邮箱明文（仅用于设置页展示与离线态）。 */
    public boolean saveSession(String token, String email) {
        if (token == null || token.isEmpty()) return false;
        try {
            String encoded = encrypt(token);
            boolean saved = prefs().edit()
                    .putString(PREFS_TOKEN, encoded)
                    .putString(PREFS_EMAIL, email == null ? "" : email)
                    .commit();
            if (!saved || !clearSignedOutMarker()) {
                writeSignedOutMarker();
                prefs().edit().remove(PREFS_TOKEN).remove(PREFS_EMAIL).commit();
                return false;
            }
            return true;
        } catch (Exception error) {
            // 提交失败后 SharedPreferences 进程内缓存也可能已变更；先写持久
            // 登出标记再主动回滚，旧 token 即使残留也不能在下次启动复活。
            writeSignedOutMarker();
            prefs().edit().remove(PREFS_TOKEN).remove(PREFS_EMAIL).commit();
            return false;
        }
    }

    public boolean clearSession() {
        for (int attempt = 0; attempt < 2; attempt++) {
            boolean marked = writeSignedOutMarker();
            boolean removed = prefs().edit()
                    .remove(PREFS_TOKEN).remove(PREFS_EMAIL).commit();
            if (marked && removed) return true;
        }
        return false;
    }

    private File signedOutMarker() {
        return new File(context.getNoBackupFilesDir(), SIGNED_OUT_MARKER);
    }

    private boolean writeSignedOutMarker() {
        File marker = signedOutMarker();
        try (FileOutputStream output = new FileOutputStream(marker, false)) {
            output.write(1);
            output.getFD().sync();
            return true;
        } catch (Exception ignored) {
            return false;
        }
    }

    private boolean clearSignedOutMarker() {
        File marker = signedOutMarker();
        return !marker.exists() || marker.delete();
    }

    // ── 认证网络层（同步调用，须在后台线程执行） ────────────────────────────

    private static String extractError(String text) {
        if (text == null || text.isEmpty()) return null;
        try {
            JSONObject json = new JSONObject(text);
            String error = json.optString("error", null);
            return error == null || error.isEmpty() ? null : error;
        } catch (Exception ignored) {
            return null;
        }
    }

    /** 统一错误兜底：服务端无 message 时按状态给用户可读文案。 */
    private static String fallbackMessage(int status, String fallback401) {
        switch (status) {
            case 400: return "请求参数有误";
            case 401: return fallback401 == null ? "未登录或登录已过期" : fallback401;
            case 403: return "账号已禁用";
            case 404: return "接口不存在";
            case 409: return "该邮箱已注册";
            case 429: return "请求过于频繁，请稍后再试";
            case 503: return "邮件服务未配置";
            default: return "API 服务返回错误 " + status;
        }
    }

    private AuthResult networkFailure() {
        return new AuthResult(
                0, "网络连接失败，请检查网络后重试", null, null, null);
    }

    private AuthResult request(
            String method,
            String path,
            JSONObject body,
            String token,
            String fallback401) {
        HttpURLConnection conn = null;
        try {
            URL endpoint = new URL(serverUrl() + path);
            if (!"https".equalsIgnoreCase(endpoint.getProtocol())) {
                return new AuthResult(
                        0, "账号服务需要安全连接", null, null, null);
            }
            conn = (HttpURLConnection) endpoint.openConnection();
            conn.setInstanceFollowRedirects(false);
            conn.setRequestMethod(method);
            conn.setRequestProperty("Content-Type", "application/json");
            conn.setRequestProperty("Accept", "application/json");
            if (token != null && !token.isEmpty()) {
                conn.setRequestProperty("Authorization", "Bearer " + token);
            }
            conn.setConnectTimeout(CONNECT_TIMEOUT_MS);
            conn.setReadTimeout(READ_TIMEOUT_MS);
            if (!"GET".equals(method) && !"HEAD".equals(method)) {
                conn.setDoOutput(true);
                try (OutputStream output = conn.getOutputStream()) {
                    JSONObject payload = body == null ? new JSONObject() : body;
                    output.write(payload.toString().getBytes(StandardCharsets.UTF_8));
                }
            }
            int status = conn.getResponseCode();
            InputStream stream = status >= 200 && status < 300
                    ? conn.getInputStream()
                    : conn.getErrorStream();
            String text = stream == null ? "" : readAll(stream);
            if (stream != null) stream.close();
            String contentType = conn.getContentType();
            boolean isJson = contentType != null
                    && contentType.toLowerCase(Locale.ROOT).contains("application/json");
            JSONObject json = null;
            if (isJson && text != null && !text.isEmpty()) {
                try {
                    json = new JSONObject(text);
                } catch (Exception ignored) {
                }
            }
            if (status >= 200 && status < 300) {
                if (!isJson || json == null) return AuthResult.protocolFailure();
                return new AuthResult(status, "", null, null, json);
            }
            // 网关 HTML 等非 JSON 错误不能伪装成可离线容忍的真实服务端 5xx。
            if (!isJson || (text != null && !text.isEmpty() && json == null)) {
                return AuthResult.protocolFailure();
            }
            String message = json == null ? null : json.optString("error", null);
            return new AuthResult(
                    status,
                    message == null ? fallbackMessage(status, fallback401) : message,
                    null,
                    null,
                    null);
        } catch (AuthProtocolException error) {
            return AuthResult.protocolFailure();
        } catch (java.io.IOException error) {
            return networkFailure();
        } catch (Exception error) {
            return networkFailure();
        } finally {
            if (conn != null) conn.disconnect();
        }
    }

    private static final class AuthProtocolException extends IOException {}

    private static String readAll(InputStream stream) throws java.io.IOException {
        java.io.ByteArrayOutputStream buffer = new java.io.ByteArrayOutputStream();
        byte[] chunk = new byte[4096];
        int read;
        while ((read = stream.read(chunk)) != -1) {
            if (buffer.size() + read > MAX_RESPONSE_BYTES) {
                throw new AuthProtocolException();
            }
            buffer.write(chunk, 0, read);
        }
        return new String(buffer.toByteArray(), StandardCharsets.UTF_8);
    }

    private static String tokenFrom(JSONObject json) {
        if (json == null) return null;
        return json.optString("token", null);
    }

    private static String emailFrom(JSONObject json) {
        if (json == null) return null;
        JSONObject account = json.optJSONObject("account");
        if (account == null) return null;
        return account.optString("email", null);
    }

    /** POST /v1/auth/email-code {email, purpose:"register"}；503 = SMTP 未配置。 */
    public AuthResult requestEmailCode(String email) {
        JSONObject body = new JSONObject();
        try {
            body.put("email", normalizeEmail(email));
            body.put("purpose", "register");
        } catch (Exception ignored) {
        }
        return request("POST", "/v1/auth/email-code", body, null,
                "请先登录");
    }

    /** POST /v1/auth/register；code 为空时省略字段（过渡态免码注册）。 */
    public AuthResult register(String email, String password, String code) {
        JSONObject body = new JSONObject();
        try {
            body.put("email", normalizeEmail(email));
            body.put("password", password == null ? "" : password);
            if (code != null && !code.trim().isEmpty()) {
                body.put("code", code.trim());
            }
        } catch (Exception ignored) {
        }
        AuthResult result = request("POST", "/v1/auth/register", body, null,
                "邮箱或密码错误");
        if (result.status == 200) {
            String token = tokenFrom(result.json);
            String accountEmail = emailFrom(result.json);
            if (token != null && !token.isEmpty()
                    && accountEmail != null && !accountEmail.isEmpty()) {
                boolean saved = saveSession(
                        token,
                        accountEmail);
                if (!saved) {
                    return new AuthResult(
                            500, "无法安全保存登录状态", null, null, null);
                }
                return new AuthResult(200, "", token, accountEmail, result.json);
            }
            return AuthResult.protocolFailure();
        }
        return result;
    }

    /** POST /v1/auth/login；401 统一「邮箱或密码错误」（防枚举，服务端文案）。 */
    public AuthResult login(String email, String password) {
        JSONObject body = new JSONObject();
        try {
            body.put("email", normalizeEmail(email));
            body.put("password", password == null ? "" : password);
        } catch (Exception ignored) {
        }
        AuthResult result = request("POST", "/v1/auth/login", body, null,
                "邮箱或密码错误");
        if (result.status == 200) {
            String token = tokenFrom(result.json);
            String accountEmail = emailFrom(result.json);
            if (token != null && !token.isEmpty()
                    && accountEmail != null && !accountEmail.isEmpty()) {
                boolean saved = saveSession(
                        token,
                        accountEmail);
                if (!saved) {
                    return new AuthResult(
                            500, "无法安全保存登录状态", null, null, null);
                }
                return new AuthResult(200, "", token, accountEmail, result.json);
            }
            return AuthResult.protocolFailure();
        }
        return result;
    }

    /** POST /v1/auth/logout（Bearer）；无论服务端成败都清除本地登录态。 */
    public AuthResult logout() {
        String token = getToken();
        AuthResult result = token == null
                ? new AuthResult(200, "", null, null, null)
                : request("POST", "/v1/auth/logout", new JSONObject(), token,
                        "未登录");
        return clearSession() ? result : result.withLocalCleanupFailure();
    }

    /**
     * GET /v1/auth/me（Bearer）。200 = 有效并刷新本地邮箱；401/403 = 会话失效
     * （路由守卫据此清 token 回登录墙）；网络失败 status=0（离线容忍，放行）。
     */
    public AuthResult me() {
        String token = getToken();
        if (token == null) {
            return new AuthResult(401, "未登录", null, null, null);
        }
        AuthResult result = request("GET", "/v1/auth/me", null,
                token, "登录已过期，请重新登录");
        if (result.status == 200 && result.json != null) {
            String accountEmail = emailFrom(result.json);
            if (accountEmail != null && !accountEmail.isEmpty()) {
                prefs().edit().putString(PREFS_EMAIL, accountEmail).commit();
                return new AuthResult(200, "", token, accountEmail, result.json);
            }
            return AuthResult.protocolFailure();
        }
        return result;
    }
}
