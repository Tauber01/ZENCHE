import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

// W13-d（Android）：邮箱账号系统登录墙契约测试——启动路由守卫 / token
// Keystore 加密存取 / 登录注册双态（验证码 60s 倒计时 + SMTP 未配 503 免码）/
// 表单校验与防重复提交 / 设置页账号区 / AI 激活带 Bearer。
// 风格沿用 native-android-* 系列：静态正则扫描 + 断言关键实现与契约分支。

const root = new URL('../', import.meta.url);
const read = async (path) => readFile(new URL(path, root), 'utf8');

const AUTH_MANAGER =
    'native/android/app/src/main/java/com/tauber/nikonlink/AuthManager.java';
const ANDROID_MAIN =
    'native/android/app/src/main/java/com/tauber/nikonlink/MainActivity.java';

test('android auth: AuthManager 存在且实现 5 个认证 API', async () => {
  const source = await read(AUTH_MANAGER);

  assert.match(source, /public final class AuthManager/);
  assert.match(source, /public AuthResult requestEmailCode\(String email\)/);
  assert.match(source, /public AuthResult register\(String email, String password, String code\)/);
  assert.match(source, /public AuthResult login\(String email, String password\)/);
  assert.match(source, /public AuthResult logout\(\)/);
  assert.match(source, /public AuthResult me\(\)/);
  // 邮箱验证码请求必须带 purpose:"register"
  assert.match(source, /body\.put\("purpose", "register"\)/);
});

test('android auth: token 用 AndroidKeyStore AES-GCM 加密（零新增依赖）', async () => {
  const source = await read(AUTH_MANAGER);

  assert.match(source, /"zenche_auth_token_key"/);
  assert.match(source, /KEYSTORE_PROVIDER = "AndroidKeyStore"/);
  assert.match(source, /KeyStore\.getInstance\(KEYSTORE_PROVIDER\)/);
  assert.match(source, /KeyGenParameterSpec\.Builder/);
  assert.match(source, /KeyProperties\.BLOCK_MODE_GCM/);
  assert.match(source, /KeyProperties\.ENCRYPTION_PADDING_NONE/);
  assert.match(source, /setKeySize\(256\)/);
  assert.match(source, /"AES\/GCM\/NoPadding"/);
  // 密文格式 base64(iv || ciphertext)
  assert.match(source, /Base64\.encodeToString\(out\.toByteArray\(\), Base64\.NO_WRAP\)/);
  // saveSession 必须经 encrypt 落盘；clearSession 移除 token 与邮箱
  assert.match(source, /String encoded = encrypt\(token\);/);
  assert.match(source, /\.remove\(PREFS_TOKEN\)\.remove\(PREFS_EMAIL\)/);
});

test('android auth: 认证网络层带 Bearer 且错误消息直达服务端 message', async () => {
  const source = await read(AUTH_MANAGER);

  assert.match(source, /setRequestProperty\("Authorization", "Bearer " \+ token\)/);
  assert.match(source, /extractError/);
  assert.match(source, /optString\("error", null\)/);
  // 防枚举：login/register 401 兜底「邮箱或密码错误」（服务端统一文案）
  assert.match(source, /request\("POST", "\/v1\/auth\/login", body, null,\n\s*"邮箱或密码错误"\)/);
  assert.match(source, /request\("POST", "\/v1\/auth\/register", body, null,\n\s*"邮箱或密码错误"\)/);
  // 401/403 兜底文案直达：fallbackMessage 按状态映射（401=防枚举统一文案，403=账号禁用）
  assert.match(source, /case 401: return fallback401 == null \? "未登录或登录已过期" : fallback401;/);
  assert.match(source, /case 403: return "账号已禁用";/);
});

test('android auth: 启动路由守卫——无 token 登录墙，有 token 后台校验', async () => {
  const source = await read(ANDROID_MAIN);

  assert.match(source, /if \(authManager\.hasSession\(\)\) \{/);
  assert.match(source, /showLoginWall\(\);/);
  assert.match(source, /private void validateSessionAsync\(\)/);
  assert.match(source, /boolean invalid = result\.status == 401 \|\| result\.status == 403/);
  assert.match(source, /authManager\.clearSession\(\);/);
  // 离线容忍：非 401/403 不清 token
  assert.match(source, /保留本地缓存态（离线容忍）/);
});

test('android auth: 登录墙双态——验证码框 60s 倒计时 + SMTP 未配 503 免码注册', async () => {
  const source = await read(ANDROID_MAIN);

  assert.match(source, /private void showLoginWall\(\)/);
  assert.match(source, /private void hideLoginWall\(\)/);
  // 严态：注册且 authCodeRequired 才显示验证码行
  assert.match(source, /boolean visible = "register"\.equals\(authMode\) && authCodeRequired/);
  // 60s 倒计时
  assert.match(source, /authCountdown = 60;/);
  assert.match(source, /"重新发送 \(" \+ authCountdown \+ "s\)"/);
  assert.match(source, /mainHandler\.postDelayed\(this, 1000\)/);
  // 过渡态：email-code 503 → 隐藏验证码框免码注册
  assert.match(source, /result\.status == 503/);
  assert.match(source, /authCodeRequired = false;/);
  assert.match(source, /邮件服务暂未配置，将免验证码注册/);
});

test('android auth: 表单校验与防重复提交', async () => {
  const source = await read(ANDROID_MAIN);

  assert.match(source, /private String validateAuthForm\(/);
  assert.match(source, /邮箱格式不正确/);
  assert.match(source, /密码至少 8 位/);
  assert.match(source, /请先获取验证码/);
  // 提交时禁用按钮 + 文案切换（加载态禁重复提交）
  assert.match(source, /authSubmitButton\.setEnabled\(false\);/);
  assert.match(source, /"正在登录…"/);
  assert.match(source, /"正在注册…"/);
});

test('android auth: 设置页账号区（邮箱 + 退出登录）', async () => {
  const source = await read(ANDROID_MAIN);

  assert.match(source, /LinearLayout accountPanel = panel\(\);/);
  assert.match(source, /accountPanel\.addView\(text\("账号"/);
  assert.match(source, /authManager\.getEmail\(\)/);
  assert.match(source, /nativeButton\("退出登录", false\)/);
  assert.match(source, /private void performLogout\(final Button logoutButton\)/);
  assert.match(source, /authManager\.logout\(\);/);
});

test('android auth: AI 激活请求带 Bearer（服务端三元组）', async () => {
  const source = await read(ANDROID_MAIN);

  assert.match(source, /String authToken = authManager == null \? null : authManager\.getToken\(\);/);
  assert.match(source, /setRequestProperty\("Authorization", "Bearer " \+ authToken\)/);
});
