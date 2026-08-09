import Combine
import Foundation
import Security

// MARK: - Keychain 会话令牌存取
//
// W13-c：邮箱账号登录墙。令牌只存 Keychain，kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
// 保证设备首次解锁后才可读、且不随 iCloud 备份迁移。账号邮箱另存 UserDefaults 一份，
// 供离线放行时设置页仍能显示当前账号。macOS 非沙盒，generic password 无需额外 entitlement。
enum AuthTokenStore {
    private static let service = "com.tauber.nikonlink.auth-session"
    private static let tokenAccount = "session_token"
    private static let emailDefaultsKey = "auth_account_email"

    static func readToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let token = String(data: data, encoding: .utf8),
              !token.isEmpty else {
            return nil
        }
        return token
    }

    static func writeToken(_ token: String?) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenAccount
        ]
        guard let token, !token.isEmpty else {
            SecItemDelete(query as CFDictionary)
            return
        }
        let data = Data(token.utf8)
        let attributes: [String: Any] = [kSecValueData as String: data]
        if SecItemUpdate(query as CFDictionary, attributes as CFDictionary) == errSecItemNotFound {
            var newItem = query
            newItem[kSecValueData as String] = data
            newItem[kSecAttrAccessible as String] =
                kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            SecItemAdd(newItem as CFDictionary, nil)
        }
    }

    static func readEmail() -> String? {
        UserDefaults.standard.string(forKey: emailDefaultsKey)
    }

    static func writeEmail(_ email: String?) {
        if let email, !email.isEmpty {
            UserDefaults.standard.set(email, forKey: emailDefaultsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: emailDefaultsKey)
        }
    }
}

// MARK: - 账号与错误模型

struct AuthAccount: Codable, Equatable {
    let email: String
    let createdAt: String?
    let verified: Bool?

    enum CodingKeys: String, CodingKey {
        case email
        case createdAt = "createdAt"
        case verified
    }
}

// 自定义 decoder 放 extension：主体声明自定义 init 会吞掉成员初始化器，
// AuthAccount(email:createdAt:verified:) 多处依赖它构造离线态账号。
extension AuthAccount {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        email = (try? container.decode(String.self, forKey: .email)) ?? ""
        createdAt = try? container.decode(String.self, forKey: .createdAt)
        verified = try? container.decode(Bool.self, forKey: .verified)
    }
}

enum AuthError: LocalizedError, Equatable {
    case invalidEmail
    case weakPassword
    case invalidCode
    case emailCodeUnavailable   // 503：SMTP 未配置 → 客户端应切免码注册
    case invalidCredentials     // 401：统一「邮箱或密码错误」
    case emailRegistered        // 409
    case accountDisabled        // 403：账号已禁用
    case sessionInvalid         // /me 401/403：令牌失效
    case server(Int, String)    // 其他 4xx/5xx，携带服务端 message
    case network                // 网络层失败

    var errorDescription: String? {
        switch self {
        case .invalidEmail: return "请输入有效的邮箱地址"
        case .weakPassword: return "密码至少需要 8 位"
        case .invalidCode: return "请输入 6 位验证码"
        case .emailCodeUnavailable: return "邮件服务暂未配置，可直接注册"
        case .invalidCredentials: return "邮箱或密码错误"
        case .emailRegistered: return "该邮箱已注册，请直接登录"
        case .accountDisabled: return "账号已禁用，请联系开发者"
        case .sessionInvalid: return "登录已失效，请重新登录"
        case .server(_, let message): return message.isEmpty ? "服务暂不可用，请稍后重试" : message
        case .network: return "网络连接失败，请检查网络后重试"
        }
    }
}

// MARK: - AuthService
//
// 状态机：checking（启动校验中）→ signedOut（登录墙）→ signedIn（主界面）。
// 路由守卫只认 state：signedOut 时任何功能都不可达。
// 说明：macOS 侧 CameraModel 非 @MainActor，本类保持非隔离，所有 @Published
// 变更统一包在 MainActor.run 中，保证 SwiftUI 在主线程收到通知。
final class AuthService: ObservableObject {
    enum State: Equatable {
        case checking
        case signedOut
        case signedIn
    }

    /// 验证码框两态：
    /// - required：严态（服务端强制邮箱验证码），显示验证码字段，注册必须带码
    /// - notRequired：过渡态（发码 503 / SMTP 未配置），隐藏验证码字段，免码注册
    /// - unknown：尚未探测，注册时按无码发送、由服务端裁决
    enum EmailCodeMode: Equatable {
        case unknown
        case required
        case notRequired
    }

    @Published private(set) var state: State = .checking
    @Published private(set) var account: AuthAccount?
    @Published private(set) var emailCodeMode: EmailCodeMode = .unknown

    private static var serverURL: String {
        UserDefaults.standard.string(forKey: "aiServerURL")
            ?? "http://101.34.255.115:8787"
    }

    var token: String? { AuthTokenStore.readToken() }

    // MARK: - 启动路由守卫

    /// 无令牌 → 登录墙；有令牌 → 调 /me 校验；401/403 清令牌回登录墙；
    /// 网络失败放行本地缓存态（离线容忍），上线后下次启动再验。
    func bootstrap() async {
        guard let token = AuthTokenStore.readToken() else {
            await MainActor.run { state = .signedOut }
            return
        }
        do {
            let me = try await request(
                path: "/v1/auth/me",
                method: "GET",
                token: token,
                body: nil
            )
            let account = decodeAccount(me)
            await MainActor.run {
                self.account = account
                AuthTokenStore.writeEmail(account.email)
                state = .signedIn
            }
        } catch let error as AuthError {
            switch error {
            case .sessionInvalid:
                await MainActor.run {
                    AuthTokenStore.writeToken(nil)
                    AuthTokenStore.writeEmail(nil)
                    account = nil
                    state = .signedOut
                }
            default:
                // 服务端异常（5xx）按离线容忍放行，保住本地登录态。
                await MainActor.run {
                    state = .signedIn
                    if let email = AuthTokenStore.readEmail(), !email.isEmpty {
                        account = AuthAccount(email: email, createdAt: nil, verified: nil)
                    }
                }
            }
        } catch {
            await MainActor.run {
                state = .signedIn
                if let email = AuthTokenStore.readEmail(), !email.isEmpty {
                    account = AuthAccount(email: email, createdAt: nil, verified: nil)
                }
            }
        }
    }

    // MARK: - 认证动作

    func sendEmailCode(email: String) async throws {
        let body: [String: Any] = ["email": email, "purpose": "register"]
        do {
            _ = try await request(path: "/v1/auth/email-code", method: "POST", token: nil, body: body)
            await MainActor.run { emailCodeMode = .required }
        } catch let error as AuthError {
            if error == .emailCodeUnavailable {
                await MainActor.run { emailCodeMode = .notRequired }
            }
            throw error
        }
    }

    func register(email: String, password: String, code: String?) async throws {
        var body: [String: Any] = ["email": email, "password": password]
        if let code, !code.isEmpty {
            body["code"] = code
        }
        let json = try await request(path: "/v1/auth/register", method: "POST", token: nil, body: body)
        try await applySession(json)
    }

    func login(email: String, password: String) async throws {
        let body: [String: Any] = ["email": email, "password": password]
        let json = try await request(path: "/v1/auth/login", method: "POST", token: nil, body: body)
        try await applySession(json)
    }

    func logout() async {
        if let token = AuthTokenStore.readToken() {
            // 尽力而为：服务端吊销失败不阻塞本地登出。
            _ = try? await request(path: "/v1/auth/logout", method: "POST", token: token, body: nil)
        }
        await MainActor.run {
            AuthTokenStore.writeToken(nil)
            AuthTokenStore.writeEmail(nil)
            account = nil
            state = .signedOut
        }
    }

    // MARK: - 会话持久化

    private func applySession(_ json: [String: Any]) async throws {
        guard let token = json["token"] as? String, !token.isEmpty else {
            throw AuthError.server(200, "服务端未返回会话令牌")
        }
        let account = decodeAccount(json)
        await MainActor.run {
            AuthTokenStore.writeToken(token)
            AuthTokenStore.writeEmail(account.email)
            self.account = account
            state = .signedIn
        }
    }

    private func decodeAccount(_ json: [String: Any]) -> AuthAccount {
        if let account = json["account"] as? [String: Any],
           let email = account["email"] as? String, !email.isEmpty {
            return AuthAccount(
                email: email,
                createdAt: account["createdAt"] as? String,
                verified: account["verified"] as? Bool
            )
        }
        if let email = json["email"] as? String, !email.isEmpty {
            return AuthAccount(email: email, createdAt: nil, verified: nil)
        }
        return AuthAccount(email: "", createdAt: nil, verified: nil)
    }

    // MARK: - 网络

    private func request(
        path: String,
        method: String,
        token: String?,
        body: [String: Any]?
    ) async throws -> [String: Any] {
        let base = Self.serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: base + path) else {
            throw AuthError.network
        }
        var r = URLRequest(url: url)
        r.httpMethod = method
        r.timeoutInterval = 15
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token {
            r.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            r.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: r)
        } catch {
            throw AuthError.network
        }
        guard let http = response as? HTTPURLResponse else {
            throw AuthError.network
        }
        let object = (try? JSONSerialization.jsonObject(with: data))
            .flatMap { $0 as? [String: Any] }
        let message = object?["error"] as? String ?? object?["message"] as? String ?? ""
        switch http.statusCode {
        case 200..<300:
            return object ?? [:]
        case 401:
            throw path == "/v1/auth/me" ? AuthError.sessionInvalid : AuthError.invalidCredentials
        case 403:
            throw AuthError.accountDisabled
        case 404, 500..<600:
            throw AuthError.server(http.statusCode, message)
        case 409:
            throw AuthError.emailRegistered
        case 503 where path == "/v1/auth/email-code":
            throw AuthError.emailCodeUnavailable
        default:
            throw AuthError.server(http.statusCode, message)
        }
    }
}
