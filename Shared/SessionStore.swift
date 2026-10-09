import Foundation
import Security

struct Session: Codable {
    let client: String
    let subject: String
    let email: String
    let accessToken: String
    let refreshToken: String?
    let expires: Date
}

enum Failure: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let value) = self { return value }; return nil }
}

enum SessionStore {
    static let group = "group.com.kryukov.plustranslate"
    static let service = "PlusTranslate.ChatGPT"
    static func query() throws -> [String: Any] {
        // Discover the actual signing prefix, without baking a team ID into public code.
        var probe: [String:Any] = [kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service + ".prefix",kSecAttrAccount as String:"marker",kSecReturnAttributes as String:true]
        var result: CFTypeRef?
        var status=SecItemCopyMatching(probe as CFDictionary,&result)
        if status==errSecItemNotFound {
            probe[kSecValueData as String]=Data("not-a-secret".utf8)
            probe[kSecAttrAccessible as String]=kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            status=SecItemAdd(probe as CFDictionary,&result)
        }
        guard status==errSecSuccess,let attributes=result as? [String:Any],let ownGroup=attributes[kSecAttrAccessGroup as String] as? String,let prefix=ownGroup.split(separator:".").first else{throw Failure.message("Не удалось проверить группу подписи (\(status)).")}
        return [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service, kSecAttrAccount as String: "session",
         kSecAttrAccessGroup as String: String(prefix)+".com.kryukov.plustranslate.shared"]
    }
    static func load() throws -> Session? {
        var q = try query(); q[kSecReturnData as String] = true; q[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw Failure.message("Нет доступа к защищённой сессии. Проверь подпись приложения и расширения (\(status)).")
        }
        return try JSONDecoder().decode(Session.self, from: data)
    }
    static func save(_ session: Session) throws {
        let data = try JSONEncoder().encode(session)
        let status = SecItemUpdate(try query() as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var q = try query(); q[kSecValueData as String] = data
            q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let added = SecItemAdd(q as CFDictionary, nil)
            guard added == errSecSuccess else { throw Failure.message("Не удалось сохранить сессию (\(added)).") }
        } else if status != errSecSuccess { throw Failure.message("Не удалось обновить сессию (\(status)).") }
    }
    static func clear() throws {
        let status = SecItemDelete(try query() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw Failure.message("Ошибка удаления сессии (\(status)).") }
    }
    static func defaults() throws -> UserDefaults {
        guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) != nil,
              let defaults = UserDefaults(suiteName: group) else {
            throw Failure.message("Подпись не разрешает общую группу приложения и Safari. Нужен профиль с App Groups.")
        }
        return defaults
    }
    static func host() throws -> String {
        let d = try defaults()
        if let host = d.string(forKey: "host") { return host }
        let host = "urn:uuid:" + UUID().uuidString.lowercased(); d.set(host, forKey: "host"); return host
    }
}
