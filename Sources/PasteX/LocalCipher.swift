import CryptoKit
import Foundation
import LocalAuthentication
import Security

enum LocalCipher {
    private static let service = "com.pastex.app.history-key"
    private static let account = "default"

    static func seal(_ data: Data) throws -> Data { try AES.GCM.seal(data, using: try key()).combined! }
    static func open(_ data: Data) throws -> Data { try AES.GCM.open(try AES.GCM.SealedBox(combined: data), using: try key()) }

    private static func key() throws -> SymmetricKey {
        if let data = readKey() { return SymmetricKey(data: data) }
        let data = Data((0..<32).map { _ in UInt8.random(in: .min ... .max) })
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account, kSecValueData as String: data, kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        guard SecItemAdd(query as CFDictionary, nil) == errSecSuccess else { throw CocoaError(.fileWriteUnknown) }
        return SymmetricKey(data: data)
    }

    private static func readKey() -> Data? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }
}

enum PrivacyAuthenticator {
    static func authenticate(completion: @escaping @MainActor @Sendable (Bool) -> Void) {
        let context = LAContext(); var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { Task { @MainActor in completion(false) }; return }
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Reveal sensitive clipboard content") { success, _ in DispatchQueue.main.async { completion(success) } }
    }
}
