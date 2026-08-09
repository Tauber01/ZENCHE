import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

// W13-d（Harmony）：邮箱账号系统登录墙契约测试——HUKS 加密 token 存取 /
// 启动路由守卫 / 登录注册双态（验证码 60s 倒计时 + SMTP 未配 503 免码）/
// 设置页账号区 / AI 激活带 Bearer。风格沿用 native-harmony-* 系列。

const root = new URL('../', import.meta.url);
const read = async (path) => readFile(new URL(path, root), 'utf8');

const AUTH_MANAGER =
    'native/harmony/entry/src/main/ets/auth/AuthManager.ets';
const INDEX =
    'native/harmony/entry/src/main/ets/pages/Index.ets';
const HARMONY_LOCALIZATION =
    'native/harmony/entry/src/main/ets/localization/Localization.ets';

test('harmony auth: AuthManager 存在且实现 5 个认证 API', async () => {
  const source = await read(AUTH_MANAGER);

  assert.match(source, /export class AuthManager/);
  assert.match(source, /async requestEmailCode\(email: string\): Promise<AuthResult>/);
  assert.match(source, /async register\(email: string, password: string, code: string\): Promise<AuthResult>/);
  assert.match(source, /async login\(email: string, password: string\): Promise<AuthResult>/);
  assert.match(source, /async logout\(\): Promise<AuthResult>/);
  assert.match(source, /async me\(\): Promise<AuthResult>/);
  // 邮箱验证码请求必须带 purpose:"register"
  assert.match(source, /'purpose': 'register'/);
});

test('harmony auth: token 用 HUKS AES-256-GCM 加密后落 preferences', async () => {
  const source = await read(AUTH_MANAGER);

  assert.match(source, /import \{ huks \} from '@kit\.UniversalKeystoreKit';/);
  assert.match(source, /huks\.generateKeyItem\(AuthManager\.KEY_ALIAS/);
  assert.match(source, /huks\.initSession\(/);
  assert.match(source, /huks\.updateSession\(/);
  assert.match(source, /huks\.finishSession\(/);
  assert.match(source, /HUKS_ALG_AES/);
  assert.match(source, /HUKS_MODE_GCM/);
  assert.match(source, /HUKS_AES_KEY_SIZE_256/);
  assert.match(source, /HUKS_PADDING_NONE/);
  assert.match(source, /HUKS_TAG_AE_TAG/);
  assert.match(source, /'zenche_auth_token_key'/);
  // 密文格式 base64(iv || ciphertext || tag)
  assert.match(source, /new Uint8Array\(iv\.length \+ cipherBytes\.length \+ tag\.length\)/);
  // 持久化键
  assert.match(source, /'auth_token_enc'/);
  assert.match(source, /store\.putSync\(AuthManager\.PREFS_TOKEN, encoded\);/);
  assert.match(source, /store\.deleteSync\(AuthManager\.PREFS_TOKEN\);/);
  assert.match(source, /await store\.flush\(\);/);
});

test('harmony auth: 账号认证仅走官网 HTTPS，安全存储失败不得放行登录墙', async () => {
  const source = await read(AUTH_MANAGER);

  assert.match(source, /AUTH_SERVER_URL: string = 'https:\/\/zenche\.top\/api'/);
  assert.doesNotMatch(source, /AUTH_SERVER_URL[^\n]*http:\/\//);
  assert.match(source, /endpoint\.toLowerCase\(\)\.startsWith\('https:\/\/'\)/);
  assert.match(source, /async saveSession\(token: string, email: string\): Promise<boolean>/);
  assert.match(source, /const saved: boolean = await this\.saveSession/);
  assert.match(source, /result\.message = '无法安全保存登录状态'/);
  assert.match(source, /import \{ rcp \} from '@kit\.RemoteCommunicationKit'/);
  assert.match(source, /autoRedirect: false/);
  assert.match(source, /MAX_RESPONSE_BYTES: number = 64 \* 1024/);
  assert.match(source, /response\.headers\['content-type'\]/);
  assert.match(source, /protocolError: boolean = false/);
  assert.match(source, /localCleanupFailed: boolean = false/);
  assert.match(source, /for \(let attempt: number = 0; attempt < 2; attempt\+\+\)/);
  assert.match(source, /if \(!\(await this\.clearSession\(\)\)\) \{/);
});

test('harmony auth: 认证网络层带 Bearer 且错误消息直达服务端 message', async () => {
  const source = await read(AUTH_MANAGER);

  assert.match(source, /header\['Authorization'\] = `Bearer \$\{token\}`/);
  assert.match(source, /json\['error'\]/);
  // 防枚举：login/register 401 兜底「邮箱或密码错误」（服务端统一文案）
  assert.match(source, /'\/v1\/auth\/login', body, '', '邮箱或密码错误'\);/);
  assert.match(source, /'\/v1\/auth\/register', body, '', '邮箱或密码错误'\);/);
});

test('harmony auth: 启动路由守卫——无 token 登录墙，有 token 后台校验', async () => {
  const source = await read(INDEX);

  assert.match(source, /import \{ AuthManager, AuthResult \} from '\.\.\/auth\/AuthManager';/);
  assert.match(source, /@State private loginWallVisible: boolean = false;/);
  assert.match(source, /@State private authChecking: boolean = true;/);
  assert.match(source, /private async bootstrapAuthGuard\(\): Promise<void>/);
  assert.match(source, /const invalid: boolean = result\.protocolError/);
  assert.match(source, /result\.status !== 0/);
  assert.match(source, /result\.status < 500/);
  assert.match(source, /const cleared: boolean = await manager\.clearSession\(\);/);
  // 缓存会话校验期间先以整屏 checking wall 阻断；完成后才允许登录墙或主工作区。
  assert.match(source, /if \(this\.authChecking && !this\.showSplash\) \{\n        this\.AuthCheckingWall\(\)/);
  assert.match(source, /if \(!this\.authChecking && this\.loginWallVisible\) \{\n        this\.LoginWall\(\)/);
  assert.match(source, /finally \{\n      this\.authChecking = false;/);
  assert.match(source, /this\.connectionPanelVisible = false;/);
  assert.ok(
    source.indexOf('this.LoginWall()') < source.indexOf('this.SplashOverlay()'),
    'Splash 必须在登录墙之后绘制，避免冷启动品牌页被覆盖'
  );
});

test('harmony auth: forced-signed-out 两阶段提交优先拦截残留 token', async () => {
  const source = await read(AUTH_MANAGER);
  assert.match(source, /PREFS_FORCED_SIGNED_OUT: string = 'auth_forced_signed_out'/);
  assert.match(source, /if \(forcedSignedOut\) return ''/);
  assert.match(source, /store\.putSync\(AuthManager\.PREFS_FORCED_SIGNED_OUT, true\)/);
  assert.match(source, /async clearSession\(\): Promise<boolean>/);
  assert.match(source, /store\.putSync\(AuthManager\.PREFS_FORCED_SIGNED_OUT, false\)/);
  assert.match(source, /await store\.flush\(\)/);
});

test('harmony auth: 登录墙双态——验证码 60s 倒计时 + SMTP 未配 503 免码注册', async () => {
  const source = await read(INDEX);
  const authManager = await read(AUTH_MANAGER);
  const localization = await read(HARMONY_LOCALIZATION);

  assert.match(source, /private LoginWall\(\)/);
  assert.match(source, /if \(this\.authMode === 'register' && this\.authCodeRequired\)/);
  // 60s 倒计时
  assert.match(source, /this\.authCodeCountdown = 60;/);
  assert.match(source, /setInterval\(/);
  assert.match(source, /this\.tr\('重新获取'\) \+ ' \(' \+ this\.authCodeCountdown\.toString\(\) \+ 's\)'/);
  // 过渡态：503 → 隐藏验证码框免码注册
  assert.match(source, /result\.status === 503/);
  assert.match(source, /this\.authCodeRequired = false;/);
  assert.match(source, /邮件服务暂未配置，将免验证码注册/);
  assert.match(source, /\.height\(52\)\n\s*\.padding\(SPACE_4\)/);
  assert.match(source, /this\.authError = this\.tr\(result\.message\)/);
  assert.match(localization, /new TranslationEntry\('邮箱或密码错误', 'Incorrect email or password', 'メールアドレスまたはパスワードが正しくありません'\)/);
  for (const key of ['请求参数有误', '接口不存在', 'API 服务返回错误']) {
    assert.match(authManager, new RegExp(key));
    assert.match(localization, new RegExp(`new TranslationEntry\\('${key}',`));
  }
  assert.doesNotMatch(authManager, /生产已上线/);
  assert.match(localization, /new TranslationEntry\('已退出，但本机登录信息未完全清除。请重新登录后再退出一次。',[^\n]*'ログアウトしましたが/);
  assert.match(source, /this\.tr\('登录后使用拍摄、编辑与 AI 功能'\)/);
  assert.match(source, /this\.tr\('还没有账号？切换到「注册」即可创建'\)/);
});

test('harmony auth: 表单校验与防重复提交', async () => {
  const source = await read(INDEX);

  assert.match(source, /private isValidEmail\(email: string\): boolean/);
  assert.match(source, /密码至少 8 位/);
  assert.match(source, /!\/\^\\d\{6\}\$\/\.test\(code\)/);
  assert.match(source, /请输入 6 位验证码/);
  assert.match(source, /this\.authSubmitting = true;/);
  assert.match(source, /正在登录…/);
  assert.match(source, /正在注册…/);
});

test('harmony auth: 设置页账号区（邮箱 + 退出登录）', async () => {
  const source = await read(INDEX);

  assert.match(source, /this\.tr\('账号'\)/);
  assert.match(source, /this\.accountEmail\.length > 0 \? this\.accountEmail : this\.tr\('未登录'\)/);
  assert.match(source, /this\.tr\('退出登录'\)/);
  assert.match(source, /private async performLogout\(\): Promise<void>/);
  assert.match(source, /await manager\.logout\(\);/);
  assert.match(source, /cleanupFailed = result\.localCleanupFailed/);
  assert.match(source, /await this\.closeAuthSensitiveState\(\);/);
  assert.match(source, /private async closeAuthSensitiveState\(\): Promise<void>/);
  for (const boundary of [
    'await this.finishExternalRecordingForDisconnect()',
    'await this.camera.disconnect()',
    'this.unregisterWifiNetConnection()',
    'await this.wifiCamera.disconnect()',
    'this.bluetoothRemote?.stop()',
    'this.locationTagging?.setEnabled(false)',
    'await this.wireless.stop()'
  ]) {
    assert.ok(source.includes(boundary), `登录墙清理链缺少 ${boundary}`);
  }
  assert.match(source, /this\.authSensitiveStateClosed = false;[\s\S]{0,180}this\.loginWallVisible = false/);
});

test('harmony auth: AI 激活仅在 HTTPS 请求带 Bearer（服务端三元组）', async () => {
  const source = await read(INDEX);

  assert.match(source, /endpoint\.toLowerCase\(\)\.startsWith\('https:\/\/'\) && authToken\.length > 0/);
  assert.match(source, /aiAuthHeader\['Authorization'\] = `Bearer \$\{authToken\}`/);
});
