import { preferences } from '@kit.ArkData';
import { util } from '@kit.ArkTS';
import { common } from '@kit.AbilityKit';
import { rcp } from '@kit.RemoteCommunicationKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { huks } from '@kit.UniversalKeystoreKit';

/** W13-d 认证操作结果：status 为 HTTP 状态码（0 = 网络失败）；message 为用户可读消息。 */
export class AuthResult {
  status: number = 0;
  message: string = '';
  token: string = '';
  email: string = '';
  protocolError: boolean = false;
  localCleanupFailed: boolean = false;
}

/**
 * W13-d 邮箱账号系统客户端认证（Harmony）。
 *
 * token 加密：HUKS（@kit.UniversalKeystoreKit——Android Keystore 的 Harmony
 * 对等物）AES-256-GCM 加解密，密钥不出系统安全存储；密文
 * base64(iv || ciphertext || tag) 落 preferences。零新增依赖。
 *
 * 服务端契约（W13-a，生产已上线，账号请求固定走官网 HTTPS 反代）：
 *   POST /v1/auth/email-code {email, purpose:"register"} → 200 / 503(邮件服务未配置)
 *   POST /v1/auth/register  {email, password, code?}     → 200 {token, account} / 400 / 409
 *   POST /v1/auth/login     {email, password}            → 200 {token, account} / 401 / 403
 *   POST /v1/auth/logout    (Bearer)                     → 200 / 401
 *   GET  /v1/auth/me        (Bearer)                     → 200 {account, devices, activated} / 401 / 403
 */
export class AuthManager {
  private context: common.UIAbilityContext;

  private static readonly PREFS_NAME: string = 'zenche_ai_settings';
  private static readonly PREFS_TOKEN: string = 'auth_token_enc';
  private static readonly PREFS_EMAIL: string = 'auth_email';
  private static readonly PREFS_FORCED_SIGNED_OUT: string = 'auth_forced_signed_out';
  private static readonly KEY_ALIAS: string = 'zenche_auth_token_key';
  private static readonly IV_BYTES: number = 12;
  private static readonly TAG_BYTES: number = 16;
  private static readonly AUTH_SERVER_URL: string = 'https://zenche.top/api';
  private static readonly CONNECT_TIMEOUT_MS: number = 15000;
  private static readonly READ_TIMEOUT_MS: number = 30000;
  private static readonly MAX_RESPONSE_BYTES: number = 64 * 1024;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  private prefs(): preferences.Preferences {
    return preferences.getPreferencesSync(this.context,
      { name: AuthManager.PREFS_NAME });
  }

  private serverUrl(): string {
    return AuthManager.AUTH_SERVER_URL;
  }

  // ── HUKS AES-256-GCM 加解密 ────────────────────────────────────────────

  private async ensureKey(): Promise<void> {
    try {
      await huks.generateKeyItem(AuthManager.KEY_ALIAS, {
        properties: [
          { tag: huks.HuksTag.HUKS_TAG_ALGORITHM, value: huks.HuksKeyAlg.HUKS_ALG_AES },
          { tag: huks.HuksTag.HUKS_TAG_KEY_SIZE, value: huks.HuksKeySize.HUKS_AES_KEY_SIZE_256 },
          {
            tag: huks.HuksTag.HUKS_TAG_PURPOSE,
            value: huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_ENCRYPT
              | huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_DECRYPT
          },
          { tag: huks.HuksTag.HUKS_TAG_BLOCK_MODE, value: huks.HuksCipherMode.HUKS_MODE_GCM },
          { tag: huks.HuksTag.HUKS_TAG_PADDING, value: huks.HuksKeyPadding.HUKS_PADDING_NONE }
        ]
      });
    } catch (_) {
      // 密钥已存在（HUKS_ERR_CODE_ALIAS_EXISTS）或瞬时失败：读取/解密时再验证。
    }
  }

  private gcmInitOptions(purpose: number, iv: Uint8Array): huks.HuksOptions {
    return {
      properties: [
        { tag: huks.HuksTag.HUKS_TAG_ALGORITHM, value: huks.HuksKeyAlg.HUKS_ALG_AES },
        { tag: huks.HuksTag.HUKS_TAG_KEY_SIZE, value: huks.HuksKeySize.HUKS_AES_KEY_SIZE_256 },
        { tag: huks.HuksTag.HUKS_TAG_PURPOSE, value: purpose },
        { tag: huks.HuksTag.HUKS_TAG_BLOCK_MODE, value: huks.HuksCipherMode.HUKS_MODE_GCM },
        { tag: huks.HuksTag.HUKS_TAG_PADDING, value: huks.HuksKeyPadding.HUKS_PADDING_NONE },
        { tag: huks.HuksTag.HUKS_TAG_IV, value: iv }
      ]
    };
  }

  /** AES-256-GCM 加密；输出 base64(iv || ciphertext || tag)。 */
  async encrypt(plain: string): Promise<string> {
    await this.ensureKey();
    const random: cryptoFramework.Random = cryptoFramework.createRandom();
    const ivBlob: cryptoFramework.DataBlob =
      await random.generateRandom(AuthManager.IV_BYTES);
    const iv: Uint8Array = ivBlob.data;
    const handle: huks.HuksSessionHandle = await huks.initSession(
      AuthManager.KEY_ALIAS, this.gcmInitOptions(huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_ENCRYPT, iv));
    const plainBytes: Uint8Array = new util.TextEncoder().encodeInto(plain);
    const updateResult: huks.HuksReturnResult = await huks.updateSession(
      handle.handle, {}, plainBytes);
    const finishResult: huks.HuksReturnResult = await huks.finishSession(
      handle.handle, {});
    const cipherBytes: Uint8Array = updateResult.outData || new Uint8Array();
    const tag: Uint8Array = finishResult.outData || new Uint8Array();
    const blob = new Uint8Array(iv.length + cipherBytes.length + tag.length);
    blob.set(iv, 0);
    blob.set(cipherBytes, iv.length);
    blob.set(tag, iv.length + cipherBytes.length);
    return new util.Base64Helper().encodeToStringSync(blob);
  }

  /** 解密 encrypt() 输出。 */
  async decrypt(encoded: string): Promise<string> {
    const blob: Uint8Array = new util.Base64Helper().decodeSync(encoded);
    if (blob.length <= AuthManager.IV_BYTES + AuthManager.TAG_BYTES) {
      throw new Error('密文格式无效');
    }
    const iv: Uint8Array = blob.subarray(0, AuthManager.IV_BYTES);
    const tag: Uint8Array = blob.subarray(blob.length - AuthManager.TAG_BYTES);
    const cipherBytes: Uint8Array =
      blob.subarray(AuthManager.IV_BYTES, blob.length - AuthManager.TAG_BYTES);
    const handle: huks.HuksSessionHandle = await huks.initSession(
      AuthManager.KEY_ALIAS, this.gcmInitOptions(huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_DECRYPT, iv));
    await huks.updateSession(handle.handle, {}, cipherBytes);
    const finishResult: huks.HuksReturnResult = await huks.finishSession(handle.handle, {
      properties: [
        { tag: huks.HuksTag.HUKS_TAG_AE_TAG, value: tag }
      ]
    });
    const plainBytes: Uint8Array = finishResult.outData || new Uint8Array();
    return new util.TextDecoder().decodeToString(plainBytes);
  }

  // ── token 持久化 ───────────────────────────────────────────────────────

  /** 读取当前 session token；无 token 或解密失败返回空串（不抛错）。 */
  async getToken(): Promise<string> {
    try {
      const forcedSignedOut: boolean =
        (this.prefs().getSync(AuthManager.PREFS_FORCED_SIGNED_OUT, false) as boolean) || false;
      if (forcedSignedOut) return '';
      const encoded: string = (this.prefs().getSync(AuthManager.PREFS_TOKEN, '') as string) || '';
      if (encoded.length === 0) return '';
      return await this.decrypt(encoded);
    } catch (_) {
      return '';
    }
  }

  getEmail(): string {
    try {
      return (this.prefs().getSync(AuthManager.PREFS_EMAIL, '') as string) || '';
    } catch (_) {
      return '';
    }
  }

  async hasSession(): Promise<boolean> {
    const token: string = await this.getToken();
    return token.length > 0;
  }

  /** 保存登录态：token HUKS 加密存储，邮箱明文（仅用于设置页展示与离线态）。 */
  async saveSession(token: string, email: string): Promise<boolean> {
    if (!token) return false;
    try {
      const encoded: string = await this.encrypt(token);
      const store = this.prefs();
      store.putSync(AuthManager.PREFS_TOKEN, encoded);
      store.putSync(AuthManager.PREFS_EMAIL, email || '');
      store.putSync(AuthManager.PREFS_FORCED_SIGNED_OUT, false);
      await store.flush();
      return true;
    } catch (_) {
      // putSync 已改进程内缓存但 flush 可能失败；回滚并强制登出，禁止假登录。
      try {
        const store = this.prefs();
        store.putSync(AuthManager.PREFS_FORCED_SIGNED_OUT, true);
        store.deleteSync(AuthManager.PREFS_TOKEN);
        store.deleteSync(AuthManager.PREFS_EMAIL);
        await store.flush();
      } catch (_) {
      }
      return false;
    }
  }

  async clearSession(): Promise<boolean> {
    for (let attempt: number = 0; attempt < 2; attempt++) {
      try {
        const store = this.prefs();
        // 两阶段提交：先持久化登出标记，再删除旧 token。第二阶段失败时旧 token
        // 即使残留也会被 getToken() 的标记拦截。
        store.putSync(AuthManager.PREFS_FORCED_SIGNED_OUT, true);
        await store.flush();
        store.deleteSync(AuthManager.PREFS_TOKEN);
        store.deleteSync(AuthManager.PREFS_EMAIL);
        await store.flush();
        return true;
      } catch (_) {
      }
    }
    return false;
  }

  // ── 认证网络层（全 async，UI 线程可直接 await） ─────────────────────────

  private normalizeEmail(email: string): string {
    return email.trim().toLowerCase();
  }

  private fallbackMessage(status: number, fallback401: string): string {
    if (status === 400) return '请求参数有误';
    if (status === 401) return fallback401.length > 0 ? fallback401 : '未登录或登录已过期';
    if (status === 403) return '账号已禁用';
    if (status === 404) return '接口不存在';
    if (status === 409) return '该邮箱已注册';
    if (status === 429) return '请求过于频繁，请稍后再试';
    if (status === 503) return '邮件服务未配置';
    return `API 服务返回错误 ${status}`;
  }

  private async request(
    method: rcp.HttpMethod,
    path: string,
    body: Record<string, Object>,
    token: string,
    fallback401: string
  ): Promise<AuthResult> {
    let session: rcp.Session | undefined = undefined;
    try {
      const endpoint: string = `${this.serverUrl()}${path}`;
      if (!endpoint.toLowerCase().startsWith('https://')) {
        const unsafeResult = new AuthResult();
        unsafeResult.status = 0;
        unsafeResult.message = '账号服务需要安全连接';
        return unsafeResult;
      }
      const header: Record<string, string> = {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      };
      if (token.length > 0) {
        header['Authorization'] = `Bearer ${token}`;
      }
      const request = new rcp.Request(endpoint);
      request.method = method;
      request.headers = header;
      if (method !== 'GET' && method !== 'HEAD') {
        request.content = JSON.stringify(body);
      }
      request.configuration = {
        transfer: {
          autoRedirect: false,
          timeout: {
            connectMs: AuthManager.CONNECT_TIMEOUT_MS,
            transferMs: AuthManager.READ_TIMEOUT_MS,
            inactivityMs: AuthManager.READ_TIMEOUT_MS
          }
        }
      };
      session = rcp.createSession();
      const response: rcp.Response = await session.fetch(request);
      const effectiveUrl: string = response.effectiveUrl?.toString() || endpoint;
      if (effectiveUrl !== endpoint) {
        return this.protocolFailure();
      }
      const bodyBytes: Uint8Array = response.body
        ? new Uint8Array(response.body) : new Uint8Array();
      if (bodyBytes.length > AuthManager.MAX_RESPONSE_BYTES) {
        return this.protocolFailure();
      }
      const text: string = bodyBytes.length > 0
        ? new util.TextDecoder().decodeToString(bodyBytes) : '';
      const contentTypeValue: string | string[] | undefined =
        response.headers['content-type'];
      const contentType: string = Array.isArray(contentTypeValue)
        ? contentTypeValue.join(';') : (contentTypeValue || '');
      const isJson: boolean = contentType.toLowerCase().includes('application/json');
      const status: number = response.statusCode;
      let json: Record<string, Object> | undefined = undefined;
      if (isJson && text.length > 0) {
        try {
          json = JSON.parse(text) as Record<string, Object>;
        } catch (_) {
        }
      }
      if (status >= 200 && status < 300) {
        if (!isJson || !json) return this.protocolFailure();
        const result = new AuthResult();
        result.status = status;
        result.token = (json['token'] as string) || '';
        const account = json['account'] as Record<string, Object> | undefined;
        if (account) {
          result.email = (account['email'] as string) || '';
        }
        return result;
      }
      // 非 JSON 网关错误不属于真实服务端 5xx，禁止进入离线容忍。
      if (!isJson || (text.length > 0 && !json)) {
        return this.protocolFailure();
      }
      let message: string = json ? ((json['error'] as string) || '') : '';
      if (message.length === 0) {
        message = this.fallbackMessage(status, fallback401);
      }
      const result = new AuthResult();
      result.status = status;
      result.message = message;
      return result;
    } catch (_) {
      const result = new AuthResult();
      result.status = 0;
      result.message = '网络连接失败，请检查网络后重试';
      return result;
    } finally {
      session?.close();
    }
  }

  private protocolFailure(): AuthResult {
    const result = new AuthResult();
    result.status = 502;
    result.message = '账号服务响应格式错误';
    result.protocolError = true;
    return result;
  }

  /** POST /v1/auth/email-code {email, purpose:"register"}；503 = SMTP 未配置。 */
  async requestEmailCode(email: string): Promise<AuthResult> {
    return this.request('POST', '/v1/auth/email-code',
      { 'email': this.normalizeEmail(email), 'purpose': 'register' },
      '', '请先登录');
  }

  /** POST /v1/auth/register；code 为空时省略字段（过渡态免码注册）。 */
  async register(email: string, password: string, code: string): Promise<AuthResult> {
    const body: Record<string, Object> = {
      'email': this.normalizeEmail(email),
      'password': password
    };
    if (code.length > 0) {
      body['code'] = code;
    }
    const result: AuthResult = await this.request(
      'POST', '/v1/auth/register', body, '', '邮箱或密码错误');
    if (result.status === 200) {
      if (result.token.length === 0 || result.email.length === 0) {
        return this.protocolFailure();
      }
      const saved: boolean = await this.saveSession(result.token, result.email);
      if (!saved) {
        result.status = 500;
        result.message = '无法安全保存登录状态';
        result.token = '';
        result.email = '';
      }
    }
    return result;
  }

  /** POST /v1/auth/login；401 统一「邮箱或密码错误」（防枚举，服务端文案）。 */
  async login(email: string, password: string): Promise<AuthResult> {
    const body: Record<string, Object> = {
      'email': this.normalizeEmail(email),
      'password': password
    };
    const result: AuthResult = await this.request(
      'POST', '/v1/auth/login', body, '', '邮箱或密码错误');
    if (result.status === 200) {
      if (result.token.length === 0 || result.email.length === 0) {
        return this.protocolFailure();
      }
      const saved: boolean = await this.saveSession(result.token, result.email);
      if (!saved) {
        result.status = 500;
        result.message = '无法安全保存登录状态';
        result.token = '';
        result.email = '';
      }
    }
    return result;
  }

  /** POST /v1/auth/logout（Bearer）；无论服务端成败都清除本地登录态。 */
  async logout(): Promise<AuthResult> {
    const token: string = await this.getToken();
    const result: AuthResult = token.length > 0
      ? await this.request('POST', '/v1/auth/logout', {}, token, '未登录')
      : new AuthResult();
    if (token.length === 0) {
      result.status = 200;
    }
    if (!(await this.clearSession())) {
      result.localCleanupFailed = true;
      result.message = '已退出，但本地登录信息未能完全清理。请重试登录后再次退出。';
    }
    return result;
  }

  /**
   * GET /v1/auth/me（Bearer）。200 = 有效并刷新本地邮箱；401/403 = 会话失效
   * （路由守卫据此清 token 回登录墙）；网络失败 status=0（离线容忍，放行）。
   */
  async me(): Promise<AuthResult> {
    const token: string = await this.getToken();
    if (token.length === 0) {
      const result = new AuthResult();
      result.status = 401;
      result.message = '未登录';
      return result;
    }
    const result: AuthResult = await this.request(
      'GET', '/v1/auth/me', {}, token, '登录已过期，请重新登录');
    if (result.status === 200) {
      if (result.email.length === 0) return this.protocolFailure();
      try {
        const store = this.prefs();
        store.putSync(AuthManager.PREFS_EMAIL, result.email);
        await store.flush();
      } catch (_) {
      }
    }
    return result;
  }
}
