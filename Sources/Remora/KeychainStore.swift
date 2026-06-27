import Security
import Foundation

struct KeychainKey: Sendable, Hashable {
    let host: String
    let shareName: String
    var account: String { "\(host)/\(shareName)" }
    static let service = "Remora"
}

enum KeychainStore {
    static func setPassword(_ password: String, for key: KeychainKey) throws {
        guard let data = password.data(using: .utf8) else { return }

        let query: [CFString: Any] = [
            kSecClass: kSecClassInternetPassword,
            kSecAttrService: KeychainKey.service,
            kSecAttrAccount: key.account,
            kSecAttrServer: key.host,
        ]

        let attributes: [CFString: Any] = [
            kSecValueData: data
        ]

        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData] = data
            status = SecItemAdd(addQuery as CFDictionary, nil)
        }

        guard status == errSecSuccess else {
            throw RemoraError.keychainWriteFailed(status)
        }
    }

    static func password(for key: KeychainKey) throws -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassInternetPassword,
            kSecAttrService: KeychainKey.service,
            kSecAttrAccount: key.account,
            kSecAttrServer: key.host,
            kSecReturnData: kCFBooleanTrue as Any,
            kSecMatchLimit: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw RemoraError.keychainReadFailed(status)
        }
        guard let data = result as? Data,
              let password = String(data: data, encoding: .utf8) else {
            return nil
        }
        return password
    }

    static func deletePassword(for key: KeychainKey) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassInternetPassword,
            kSecAttrService: KeychainKey.service,
            kSecAttrAccount: key.account,
            kSecAttrServer: key.host,
        ]

        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            throw RemoraError.keychainWriteFailed(status)
        }
    }
}
