import CryptoKit
import Foundation
import Security

struct ClipCrypto {
    private static let service = "com.shreyravi.clipstasher"
    private static let account = "db-content-key"
    static let encPrefix = "enc:"

    static func loadOrCreateKey() throws -> SymmetricKey {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecSuccess, let data = item as? Data {
            return SymmetricKey(data: data)
        }

        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { Data($0) }
        let add: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecValueData: keyData,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let addStatus = SecItemAdd(add as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw ClipCryptoError.keychainWrite(addStatus)
        }
        return key
    }

    static func encrypt(_ plaintext: String, key: SymmetricKey) throws -> String {
        let data = Data(plaintext.utf8)
        let sealed = try AES.GCM.seal(data, using: key)
        return encPrefix + (sealed.combined?.base64EncodedString() ?? "")
    }

    /// Returns stored string decrypted if `enc:`-prefixed; passes through plaintext unchanged.
    static func decrypt(_ stored: String, key: SymmetricKey) -> String {
        guard stored.hasPrefix(encPrefix) else { return stored }
        guard
            let data = Data(base64Encoded: String(stored.dropFirst(encPrefix.count))),
            let box = try? AES.GCM.SealedBox(combined: data),
            let plain = try? AES.GCM.open(box, using: key),
            let str = String(data: plain, encoding: .utf8)
        else { return stored }
        return str
    }
}

enum ClipCryptoError: Error {
    case keychainWrite(OSStatus)
}
