// KeychainManager.swift
// Sicherheitsstufe: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
//   – kein iCloud-Backup, kein Geräte-Transfer
//   – Hintergrund-Sync möglich (nach erstem Unlock)
//   – kSecAttrSynchronizable explizit deaktiviert
import Security
import Foundation

final class KeychainManager {
    static let shared = KeychainManager()
    private init() {}

    private let service = "io.imailsecure.passwords"

    // MARK: – Speichern (atomares Update-oder-Anlegen)

    func savePassword(_ password: String, forAccount accountID: String) throws {
        guard let data = password.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        let baseQuery: [String: Any] = [
            kSecClass as String:              kSecClassGenericPassword,
            kSecAttrService as String:        service,
            kSecAttrAccount as String:        accountID,
            // Nie mit iCloud synchronisieren
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any
        ]

        let attributes: [String: Any] = [
            kSecValueData as String:          data,
            // Zugänglich nach erstem Entsperren, nur dieses Gerät
            kSecAttrAccessible as String:     kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        // Versuche atomares Update
        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)

        if updateStatus == errSecItemNotFound {
            // Eintrag existiert noch nicht → anlegen
            var addQuery = baseQuery
            addQuery.merge(attributes) { _, new in new }
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.saveFailed(addStatus)
            }
        } else if updateStatus != errSecSuccess {
            throw KeychainError.saveFailed(updateStatus)
        }
    }

    // MARK: – Lesen

    func getPassword(forAccount accountID: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String:              kSecClassGenericPassword,
            kSecAttrService as String:        service,
            kSecAttrAccount as String:        accountID,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any,
            kSecReturnData as String:         true,
            kSecMatchLimit as String:         kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let password = String(data: data, encoding: .utf8)
        else { return nil }
        return password
    }

    // MARK: – Löschen

    func deletePassword(forAccount accountID: String) {
        let query: [String: Any] = [
            kSecClass as String:              kSecClassGenericPassword,
            kSecAttrService as String:        service,
            kSecAttrAccount as String:        accountID,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: – Fehlertypen

enum KeychainError: LocalizedError {
    case encodingFailed
    case saveFailed(OSStatus)
    case retrieveFailed

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return String(localized: "error.keychain.encoding",
                          defaultValue: "Passwort konnte nicht kodiert werden.")
        case .saveFailed(let s):
            return String(
                format: String(localized: "error.keychain.save",
                               defaultValue: "Keychain-Fehler beim Speichern (Status %d)."),
                Int(s)
            )
        case .retrieveFailed:
            return String(localized: "error.keychain.retrieve",
                          defaultValue: "Passwort konnte nicht abgerufen werden.")
        }
    }
}
