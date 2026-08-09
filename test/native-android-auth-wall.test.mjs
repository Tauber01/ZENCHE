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
const ANDROID_LOCALIZATION =
    'native/android/app/src/main/java/com/tauber/nikonlink/Localization.java';

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

test('android auth: 账号认证仅走官网 HTTPS，安全存储失败不得放行登录墙', async () => {
  const source = await read(AUTH_MANAGER);

  assert.match(source, /AUTH_SERVER_URL = "https:\/\/zenche\.top\/api"/);
  assert.doesNotMatch(source, /AUTH_SERVER_URL\s*=\s*"http:\/\//);
  assert.match(source, /"https"\.equalsIgnoreCase\(endpoint\.getProtocol\(\)\)/);
  assert.match(source, /public boolean saveSession\(String token, String email\)/);
  assert.match(source, /if \(!saved\) \{/);
  assert.match(source, /"无法安全保存登录状态"/);
  assert.match(source, /if \(!"GET"\.equals\(method\) && !"HEAD"\.equals\(method\)\)/);
  assert.match(source, /setInstanceFollowRedirects\(false\)/);
  assert.match(source, /MAX_RESPONSE_BYTES = 64 \* 1024/);
  assert.match(source, /protocolError/);
  assert.match(source, /contentType\.toLowerCase\(Locale\.ROOT\)\.contains\("application\/json"\)/);
  assert.match(source, /AuthResult\.protocolFailure\(\)/);
  assert.match(source, /localCleanupFailed/);
  assert.match(source, /for \(int attempt = 0; attempt < 2; attempt\+\+\)/);
  assert.match(source, /return clearSession\(\) \? result : result\.withLocalCleanupFailure\(\)/);
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
  assert.match(source, /boolean invalid = result\.protocolError/);
  assert.match(source, /result\.status != 0/);
  assert.match(source, /result\.status < 500/);
  assert.match(source, /authManager\.clearSession\(\);/);
  assert.match(source, /authChecking = true;\n\s*showSection\("capture"\);\n\s*showAuthCheckingWall\(\);/);
  assert.match(source, /if \(authChecking\) \{\n\s*showAuthCheckingWall\(\);/);
  assert.match(source, /scroll\.addView\(formHost/);
  assert.match(source, /dismissConnectionDialog\(\);/);
  assert.match(source, /boolean cleanupFailed = invalid && !authManager\.clearSession\(\)/);
  // 离线容忍只允许真实网络失败和 JSON 服务端 5xx；协议错误失败关闭
  assert.match(source, /仅 200 \/ 真实网络失败 status=0 \/ JSON 服务端 5xx 离线容忍/);
});

test('android auth: 登出标记优先于残留 token，保存失败回滚进程内缓存', async () => {
  const source = await read(AUTH_MANAGER);
  assert.match(source, /SIGNED_OUT_MARKER = "auth-signed-out"/);
  assert.match(source, /if \(signedOutMarker\(\)\.exists\(\)\) return null/);
  assert.match(source, /boolean marked = writeSignedOutMarker\(\)/);
  assert.match(source, /output\.getFD\(\)\.sync\(\)/);
  assert.match(source, /if \(!saved \|\| !clearSignedOutMarker\(\)\)/);
  assert.match(source, /remove\(PREFS_TOKEN\)\.remove\(PREFS_EMAIL\)\.commit\(\)/);
});

test('android auth: 登录墙双态——验证码框 60s 倒计时 + SMTP 未配 503 免码注册', async () => {
  const source = await read(ANDROID_MAIN);
  const authManager = await read(AUTH_MANAGER);
  const localization = await read(ANDROID_LOCALIZATION);

  assert.match(source, /private void showLoginWall\(\)/);
  assert.match(source, /private void hideLoginWall\(\)/);
  // 严态：注册且 authCodeRequired 才显示验证码行
  assert.match(source, /boolean visible = "register"\.equals\(authMode\) && authCodeRequired/);
  // 60s 倒计时
  assert.match(source, /authCountdown = 60;/);
  assert.match(source, /tr\("重新获取"\) \+ " \(" \+ authCountdown \+ "s\)"/);
  assert.match(source, /mainHandler\.postDelayed\(this, 1000\)/);
  // 过渡态：email-code 503 → 隐藏验证码框免码注册
  assert.match(source, /result\.status == 503/);
  assert.match(source, /authCodeRequired = false;/);
  assert.match(source, /邮件服务暂未配置，将免验证码注册/);
  assert.match(source, /inputMethod\.restartInput\(authPasswordInput\)/);
  assert.match(source, /actionId == EditorInfo\.IME_ACTION_NEXT[\s\S]{0,240}submitAuthForm\(\)/);
  assert.match(source, /authErrorText\.setText\(tr\(result\.message\)\)/);
  assert.match(localization, /add\("邮箱或密码错误", "Incorrect email or password", "メールアドレスまたはパスワードが正しくありません"\)/);
  assert.match(source, /tr\("正在发送…"\)/);
  assert.match(localization, /add\("正在发送…", "Sending…", "送信中…"\)/);
  for (const key of ['请求参数有误', '接口不存在', 'API 服务返回错误']) {
    assert.match(authManager, new RegExp(key));
    assert.match(localization, new RegExp(`add\\("${key}",`));
  }
  assert.doesNotMatch(authManager, /生产已上线/);
  assert.match(localization, /add\("已退出，但本机登录信息未完全清除。请重新登录后再退出一次。",[\s\S]{0,260}"ログアウトしましたが/);
  assert.match(source, /登录后使用拍摄、编辑与 AI 功能/);
  assert.match(source, /还没有账号？切换到「注册」即可创建/);
});

test('android auth: 表单校验与防重复提交', async () => {
  const source = await read(ANDROID_MAIN);

  assert.match(source, /private String validateAuthForm\(/);
  assert.match(source, /邮箱格式不正确/);
  assert.match(source, /密码至少 8 位/);
  assert.match(source, /code == null \|\| !code\.trim\(\)\.matches\("\\\\d\{6\}"\)/);
  assert.match(source, /请输入 6 位验证码/);
  // 提交时禁用按钮 + 文案切换（加载态禁重复提交）
  assert.match(source, /authSubmitButton\.setEnabled\(false\);/);
  assert.match(source, /"正在登录…"/);
  assert.match(source, /"正在注册…"/);
  assert.match(source, /currentAuthViewportWidthPx\(\)/);
  assert.doesNotMatch(source, /int availableWidth[\s\S]{0,120}widthPixels/);
  assert.match(source, /marginParams\(-1, dp\(52\), 0, 0, 0, 20\)/);
});

test('android auth: 设置页账号区（邮箱 + 退出登录）', async () => {
  const source = await read(ANDROID_MAIN);

  assert.match(source, /LinearLayout accountPanel = panel\(\);/);
  assert.match(source, /accountPanel\.addView\(text\("账号"/);
  assert.match(source, /authManager\.getEmail\(\)/);
  assert.match(source, /nativeButton\("退出登录", false\)/);
  assert.match(source, /private void performLogout\(final Button logoutButton\)/);
  assert.match(source, /authManager\.logout\(\);/);
  // 登出、会话失效和无会话都经 showLoginWall 进入同一幂等清理链。
  assert.match(source, /private void showLoginWall\(\) \{\n\s*closeAuthSensitiveState\(\);/);
  assert.match(source, /private void closeAuthSensitiveState\(\)/);
  for (const boundary of [
    'wirelessServer.stop()',
    'setBluetoothRemoteEnabled(false)',
    'setLocationTaggingEnabled(false)',
    'unregisterWifiNetworkCallback()',
    'finishExternalRecordingForDisconnect()',
    'wifiCamera.close()',
    'localCamera.close()',
    'camera.disconnect()'
  ]) {
    assert.ok(source.includes(boundary), `登录墙清理链缺少 ${boundary}`);
  }
  assert.match(source, /private void hideLoginWall\(\) \{\n\s*authSensitiveStateClosed = false;/);
});

test('android auth: AI 激活仅在 HTTPS 请求带 Bearer（服务端三元组）', async () => {
  const source = await read(ANDROID_MAIN);

  assert.match(source, /String authToken = authManager == null \? null : authManager\.getToken\(\);/);
  assert.match(source, /"https"\.equalsIgnoreCase\(endpoint\.getProtocol\(\)\)/);
  assert.match(source, /setRequestProperty\("Authorization", "Bearer " \+ authToken\)/);
});
