import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const root = new URL('../', import.meta.url);
const read = async (path) => readFile(new URL(path, root), 'utf8');

const iOS_AUTH = 'native/ios/NikonLink/Models/AuthService.swift';
const iOS_ROOT = 'native/ios/NikonLink/Views/RootView.swift';
const iOS_MODEL = 'native/ios/NikonLink/Models/AppModel.swift';
const iOS_PBX = 'native/ios/NikonLink.xcodeproj/project.pbxproj';
const MAC_AUTH = 'native/macos/Sources/NikonLink/AuthService.swift';
const MAC_MAIN = 'native/macos/Sources/NikonLink/main.swift';
const MAC_SETTINGS = 'native/macos/Sources/NikonLink/SettingsSheet.swift';

// ─────────────────────────────────────────────────────────────────────────────
// W13-c 契约：iOS + macOS 登录墙（邮箱账号系统客户端）
// 服务端契约：POST /v1/auth/register|email-code|login|logout、GET /v1/auth/me
// 3A：启动即登录墙，不登录任何功能不可用；2A：AI 激活带 Bearer，无 token 不破坏存量。
// ─────────────────────────────────────────────────────────────────────────────

// ---------- Keychain 令牌存取（两端同款，kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly） ----------

test('W13-c Keychain: iOS AuthTokenStore 走 generic password + AfterFirstUnlockThisDeviceOnly', async () => {
  const s = await read(iOS_AUTH);
  assert.match(s, /enum AuthTokenStore \{/);
  assert.match(s, /kSecClassGenericPassword/);
  assert.match(s, /kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly/);
  for (const api of ['SecItemCopyMatching', 'SecItemAdd', 'SecItemUpdate', 'SecItemDelete']) {
    assert.ok(s.includes(api), `iOS AuthTokenStore 应使用 ${api}`);
  }
  assert.match(s, /com\.tauber\.nikonlink\.auth-session/);
  // 邮箱另存 UserDefaults 一份，供离线放行时设置页显示账号
  assert.match(s, /UserDefaults\.standard\.string\(forKey:/);
});

test('W13-c Keychain: macOS AuthTokenStore 同款 Security API', async () => {
  const s = await read(MAC_AUTH);
  assert.match(s, /enum AuthTokenStore \{/);
  assert.match(s, /kSecClassGenericPassword/);
  assert.match(s, /kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly/);
  for (const api of ['SecItemCopyMatching', 'SecItemAdd', 'SecItemUpdate', 'SecItemDelete']) {
    assert.ok(s.includes(api), `macOS AuthTokenStore 应使用 ${api}`);
  }
  assert.match(s, /com\.tauber\.nikonlink\.auth-session/);
});

test('W13-c 安全边界: 账号认证固定走官网 HTTPS，Keychain 写入失败不得进入已登录态', async () => {
  for (const s of [await read(iOS_AUTH), await read(MAC_AUTH)]) {
    assert.match(s, /private static let serverURL = "https:\/\/zenche\.top\/api"/);
    assert.doesNotMatch(s, /serverURL[\s\S]{0,160}http:\/\//);
    assert.match(s, /url\.scheme\?\.lowercased\(\) == "https"/);
    assert.match(s, /guard AuthTokenStore\.writeToken\(token\) else/);
    assert.match(s, /throw AuthError\.secureStorage/);
    assert.match(s, /forcedSignedOutMarkerURL/);
    assert.match(s, /writeForcedSignedOutMarker\(\)/);
    assert.match(s, /Data\("signed-out"\.utf8\)\.write\(to: url, options: \.atomic\)/);
    assert.match(s, /return marked && deleted/);
    assert.match(s, /localCleanupMessage/);
    assert.match(s, /if !clearSession\(\)/);
  }
});

test('W13-c 网络失败关闭: 禁重定向、限响应体、只接受官网 JSON 对象与有效账号', async () => {
  for (const s of [await read(iOS_AUTH), await read(MAC_AUTH)]) {
    assert.match(s, /final class AuthRedirectBlocker/);
    assert.match(s, /completionHandler\(nil\)/);
    assert.match(s, /maximumResponseBytes = 64 \* 1024/);
    assert.match(s, /http\.url\?\.host\?\.lowercased\(\) == "zenche\.top"/);
    assert.match(s, /case protocolFailure/);
    assert.match(s, /throw AuthError\.protocolFailure/);
    assert.match(s, /contentType\.contains\("application\/json"\)/);
    assert.match(s, /账号服务响应格式错误/);
    assert.match(s, /账号服务响应缺少有效账号/);
    assert.doesNotMatch(s, /case 200\.\.<300:\s*return object \?\? \[:\]/);
  }
});

// ---------- 状态机与验证码两态 ----------

test('W13-c 状态机: 两端 AuthService 均含 checking/signedOut/signedIn 且初态 checking', async () => {
  for (const s of [await read(iOS_AUTH), await read(MAC_AUTH)]) {
    assert.match(s, /case checking/);
    assert.match(s, /case signedOut/);
    assert.match(s, /case signedIn/);
    assert.match(s, /@Published private\(set\) var state: State = \.checking/);
  }
});

test('W13-c 验证码两态: emailCodeMode 三态枚举 + 503→notRequired / 发码成功→required', async () => {
  const ios = await read(iOS_AUTH);
  const mac = await read(MAC_AUTH);
  for (const s of [ios, mac]) {
    assert.match(s, /enum EmailCodeMode: Equatable \{/);
    assert.match(s, /case unknown/);
    assert.match(s, /case required/);
    assert.match(s, /case notRequired/);
    // 发码成功 → required（严态）；503 → notRequired（过渡态免码注册）
    assert.match(s, /emailCodeMode = \.required/);
    assert.match(s, /emailCodeMode = \.notRequired/);
    // 503 映射为 emailCodeUnavailable（禁 fail-open，由服务端裁决）
    assert.match(s, /case 503 where path == "\/v1\/auth\/email-code"/);
    assert.match(s, /emailCodeUnavailable/);
    assert.ok(
      s.indexOf('case 503 where path == "/v1/auth/email-code"')
        < s.indexOf('case 404, 500..<600'),
      '503 发码服务不可用必须先于通用 5xx 映射'
    );
  }
});

// ---------- 启动路由守卫 ----------

test('W13-c 路由守卫: iOS body 按 auth.state 三路分发 + .task bootstrap', async () => {
  const r = await read(iOS_ROOT);
  assert.match(r, /switch model\.auth\.state \{/);
  assert.match(r, /case \.signedOut:/);
  assert.match(r, /LoginView\(\)/);
  assert.match(r, /case \.checking:\s*Color\.clear/);
  assert.match(r, /case \.signedIn:\s*mainWorkspace/);
  assert.match(r, /mainWorkspace/);
  assert.match(r, /await model\.auth\.bootstrap\(\)/);
});

test('W13-c 路由守卫: macOS body 按 auth.state 三路分发 + .task bootstrap', async () => {
  const m = await read(MAC_MAIN);
  assert.match(m, /switch model\.auth\.state \{/);
  assert.match(m, /case \.signedOut:/);
  assert.match(m, /LoginView\(auth: model\.auth\)/);
  assert.match(m, /case \.checking:\s*Color\.clear/);
  assert.match(m, /case \.signedIn:\s*mainWorkspace/);
  assert.match(m, /mainWorkspace/);
  assert.match(m, /await model\.auth\.bootstrap\(\)/);
});

test('W13-c bootstrap: 无令牌→signedOut；/me 401/403→清令牌回登录墙；网络失败→放行本地态（离线容忍）', async () => {
  for (const s of [await read(iOS_AUTH), await read(MAC_AUTH)]) {
    // 无令牌直接登录墙
    assert.match(s, /guard let token = AuthTokenStore\.readToken\(\) else/);
    assert.match(s, /state = \.signedOut/);
    // /me 校验
    assert.match(s, /"\/v1\/auth\/me"/);
    // 401/403 → 清令牌 + 回登录墙
    assert.match(s, /case \.sessionInvalid:/);
    assert.match(s, /case 403:\s*throw path == "\/v1\/auth\/me" \? AuthError\.sessionInvalid : AuthError\.accountDisabled/);
    assert.match(s, /AuthTokenStore\.writeToken\(nil\)/);
    assert.match(s, /state = \.signedOut/);
    // 网络失败 → signedIn 离线容忍
    assert.match(s, /case \.network/);
    assert.match(s, /state = \.signedIn/);
    assert.match(s, /case \.server\(let status, _\) where status >= 500/);
    assert.match(s, /default:[\s\S]{0,220}state = \.signedOut/);
  }
});

test('W13-c 未鉴权隔离: checking 不挂载工作区，登出关闭功能浮层并停止后台服务', async () => {
  const ios = await read(iOS_ROOT);
  const mac = await read(MAC_MAIN);
  assert.match(ios, /case \.checking:\s*Color\.clear/);
  assert.match(ios, /guard state == \.signedIn else \{/);
  assert.match(ios, /model\.showingConnection = false/);
  assert.match(ios, /model\.showingSettings = false/);
  assert.match(ios, /model\.camera\.suspend\(\)/);
  assert.match(ios, /model\.wireless\.stop\(\)/);
  assert.match(mac, /case \.checking:\s*Color\.clear/);
  assert.match(mac, /showConnection = false/);
  assert.match(mac, /showSettings = false/);
  assert.match(mac, /showLaunchAnnouncement = false/);
  assert.match(ios, /\.frame\(minHeight: 44\)/);
  assert.match(mac, /\.frame\(minHeight: 44\)/);
});

test('W13-c 认证动作: 两端均实现 register/login/logout/sendEmailCode + 服务端路径', async () => {
  for (const s of [await read(iOS_AUTH), await read(MAC_AUTH)]) {
    assert.match(s, /func sendEmailCode\(email: String\) async throws/);
    assert.match(s, /func register\(email: String, password: String, code: String\?\) async throws/);
    assert.match(s, /func login\(email: String, password: String\) async throws/);
    assert.match(s, /func logout\(\) async/);
    assert.match(s, /"\/v1\/auth\/email-code"/);
    assert.match(s, /"\/v1\/auth\/register"/);
    assert.match(s, /"\/v1\/auth\/login"/);
    assert.match(s, /"\/v1\/auth\/logout"/);
    // 401 统一「邮箱或密码错误」；/me 401 视为会话失效
    assert.match(s, /invalidCredentials/);
    assert.match(s, /sessionInvalid/);
    assert.match(s, /accountDisabled/);
  }
});

// ---------- 并发模型 ----------

test('W13-c 并发模型: iOS @MainActor 直标；macOS 非隔离 + MainActor.run 包裹 @Published 变更', async () => {
  const ios = await read(iOS_AUTH);
  const mac = await read(MAC_AUTH);
  assert.match(ios, /@MainActor\s*\nfinal class AuthService: ObservableObject/);
  assert.match(mac, /final class AuthService: ObservableObject/);
  assert.ok(!mac.includes('@MainActor\nfinal class AuthService'), 'macOS AuthService 不应标 @MainActor');
  assert.ok(mac.includes('MainActor.run'), 'macOS 应使用 MainActor.run 包裹状态变更');
});

// ---------- LoginView 表单与两态显示 ----------

test('W13-c LoginView: iOS 品牌头/登录注册切换/邮箱密码验证码/60s 倒计时/加载态禁重复提交', async () => {
  const r = await read(iOS_ROOT);
  assert.match(r, /private struct LoginView: View \{/);
  assert.match(r, /帧澈 ZENCHE/);
  assert.match(r, /登录后使用拍摄、编辑与 AI 功能/);
  assert.match(r, /emailCodeMode == \.required/);   // 严态显示验证码框
  assert.match(r, /emailCodeMode == \.notRequired/); // 过渡态隐藏验证码框
  assert.match(r, /countdown = 60/);                 // 60s 倒计时
  assert.match(r, /isWorking/);                      // 加载态
  assert.match(r, /weakPassword|密码至少需要 8 位/); // 表单校验
});

test('W13-c LoginView: macOS 同款两态 + 倒计时 + 加载态', async () => {
  const m = await read(MAC_MAIN);
  assert.match(m, /private struct LoginView: View \{/);
  assert.match(m, /auth\.emailCodeMode == \.required/);
  assert.match(m, /auth\.emailCodeMode == \.notRequired/);
  assert.match(m, /countdown = 60/);
  assert.match(m, /isWorking/);
});

// ---------- 设置页账号区 ----------

test('W13-c 设置页: iOS 账号区（当前账号邮箱 + 退出登录）', async () => {
  const r = await read(iOS_ROOT);
  assert.match(r, /W13-c：账号区/);
  assert.match(r, /"当前账号"/);
  assert.match(r, /model\.auth\.account\?\.email/);
  assert.match(r, /"退出登录"/);
  assert.match(r, /await model\.auth\.logout\(\)/);
});

test('W13-c 设置页: macOS SettingsSheet 收 auth 参数 + 账号卡（邮箱 + 退出登录）', async () => {
  const s = await read(MAC_SETTINGS);
  assert.match(s, /let auth: AuthService/);
  assert.match(s, /W13-c：账号区/);
  assert.match(s, /auth\.account\?\.email/);
  assert.match(s, /"退出登录"/);
  assert.match(s, /await auth\.logout\(\)/);
  // 调用点已接 auth（main.swift 中 SettingsSheet 构造传参）
  const m = await read(MAC_MAIN);
  assert.match(m, /SettingsSheet\(\s*updater: updater,\s*auth: model\.auth,/);
});

// ---------- AI 激活 Bearer（2A：三元组） ----------

test('W13-c AI Bearer: iOS 仅在 HTTPS endpoint 且有 token 时附加 Authorization', async () => {
  const r = await read(iOS_ROOT);
  assert.match(r, /if url\.scheme\?\.lowercased\(\) == "https",\s*let token = AuthTokenStore\.readToken\(\) \{/);
  assert.match(r, /"Bearer \\\(token\)"/);
  assert.match(r, /账号↔设备↔激活码 三元组/);
});

test('W13-c AI Bearer: macOS 同款 HTTPS 限制与 Bearer 头', async () => {
  const m = await read(MAC_MAIN);
  assert.match(m, /if url\.scheme\?\.lowercased\(\) == "https",\s*let token = AuthTokenStore\.readToken\(\) \{/);
  assert.match(m, /"Bearer \\\(token\)"/);
  assert.match(m, /账号↔设备↔激活码 三元组/);
});

// ---------- pbxproj 注册（iOS 手工 ID 模式） ----------

test('W13-c pbxproj: AuthService.swift 四处注册（BuildFile/FileRef/Models group/Sources phase）', async () => {
  const p = await read(iOS_PBX);
  assert.match(p, /A10000000000000000000030 \/\* AuthService\.swift in Sources \*\/ = \{isa = PBXBuildFile; fileRef = B10000000000000000000030/);
  assert.match(p, /B10000000000000000000030 \/\* AuthService\.swift \*\/ = \{isa = PBXFileReference; lastKnownFileType = sourcecode\.swift; path = AuthService\.swift/);
  assert.match(p, /B10000000000000000000030 \/\* AuthService\.swift \*\/,\s*\);\s*path = Models;/);
  assert.match(p, /A10000000000000000000030 \/\* AuthService\.swift in Sources \*\/,/);
});

// ---------- 本地化（三语 + en→zh 恒等映射硬约束） ----------

test('W13-c 本地化: 三语 .strings 均含登录墙新键，en 有真翻译（非恒等）', async () => {
  const zh = await read('native/ios/NikonLink/zh-Hans.lproj/Localizable.strings');
  const en = await read('native/ios/NikonLink/en.lproj/Localizable.strings');
  const ja = await read('native/ios/NikonLink/ja.lproj/Localizable.strings');
  for (const key of ['登录', '注册', '邮箱', '账号', '当前账号', '退出登录', '获取验证码', '邮箱或密码错误']) {
    assert.match(zh, new RegExp(`"${key}" = "`));
    assert.match(en, new RegExp(`"${key}" = "`));
    assert.match(ja, new RegExp(`"${key}" = "`));
  }
  // en 恒等映射硬约束：zh 源串不得直接等于 en 值（必须有真翻译）
  assert.match(en, /"登录" = "Log In";/);
  assert.match(en, /"退出登录" = "Log Out";/);
  // macOS 构建时复用 iOS 的 Localizable.strings（build-macos.sh 拷贝），键位即两端生效
  const build = await read('scripts/build-macos.sh');
  assert.match(build, /Localizable\.strings/);
});
