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
  assert.match(source, /private async bootstrapAuthGuard\(\): Promise<void>/);
  assert.match(source, /if \(result\.status === 401 \|\| result\.status === 403\)/);
  assert.match(source, /manager\.clearSession\(\);/);
  // 登录墙整屏覆盖（Stack 顶层 overlay）
  assert.match(source, /if \(this\.loginWallVisible\) \{\n        this\.LoginWall\(\)/);
});

test('harmony auth: 登录墙双态——验证码 60s 倒计时 + SMTP 未配 503 免码注册', async () => {
  const source = await read(INDEX);

  assert.match(source, /private LoginWall\(\)/);
  assert.match(source, /if \(this\.authMode === 'register' && this\.authCodeRequired\)/);
  // 60s 倒计时
  assert.match(source, /this\.authCodeCountdown = 60;/);
  assert.match(source, /setInterval\(/);
  assert.match(source, /'重新发送 \(' \+ this\.authCodeCountdown\.toString\(\) \+ 's\)'/);
  // 过渡态：503 → 隐藏验证码框免码注册
  assert.match(source, /result\.status === 503/);
  assert.match(source, /this\.authCodeRequired = false;/);
  assert.match(source, /邮件服务暂未配置，将免验证码注册/);
});

test('harmony auth: 表单校验与防重复提交', async () => {
  const source = await read(INDEX);

  assert.match(source, /private isValidEmail\(email: string\): boolean/);
  assert.match(source, /密码至少 8 位/);
  assert.match(source, /请先获取验证码/);
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
});

test('harmony auth: AI 激活请求带 Bearer（服务端三元组）', async () => {
  const source = await read(INDEX);

  assert.match(source, /aiAuthHeader\['Authorization'\] = `Bearer \$\{authToken\}`/);
});
