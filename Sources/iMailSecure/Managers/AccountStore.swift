// AccountStore.swift
// Kontodaten (ohne Passwort) werden in einer Datei gespeichert mit:
//   .completeFileProtection  → verschlüsselt wenn Gerät gesperrt
//   isExcludedFromBackup = true → nie in iCloud/iTunes-Backup
// Passwörter liegen weiterhin ausschließlich im Keychain.
import Foundation
import Combine

final class AccountStore: ObservableObject {
    @Published var accounts: [EmailAccount] = []

    // MARK: – Dateipfad

    private var storeURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("accounts.json")
    }

    init() { load() }

    // MARK: – Öffentliche Mutationen

    func add(_ account: EmailAccount) {
        accounts.append(account)
        save()
    }

    func update(_ account: EmailAccount) {
        if let idx = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[idx] = account
            save()
        }
    }

    func delete(_ account: EmailAccount) {
        KeychainManager.shared.deletePassword(forAccount: account.id.uuidString)
        accounts.removeAll { $0.id == account.id }
        save()
    }

    // MARK: – Persistenz

    private func save() {
        do {
            let data = try JSONEncoder().encode(accounts)
            let url  = storeURL

            // Verzeichnis anlegen falls nicht vorhanden
            let dir = url.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: dir.path) {
                try FileManager.default.createDirectory(at: dir,
                    withIntermediateDirectories: true)
            }

            // Atomar schreiben mit .completeFileProtection
            try data.write(to: url, options: [.atomic, .completeFileProtection])

            // Backup-Ausschluss setzen
            var rv = URLResourceValues()
            rv.isExcludedFromBackup = true
            var mutableURL = url
            try mutableURL.setResourceValues(rv)

        } catch {
            // Fehler loggen aber nicht abstürzen – Accounts bleiben im RAM
            print("[AccountStore] Speichern fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    private func load() {
        let url = storeURL

        // Migration: falls alte UserDefaults-Daten vorhanden, einmalig migrieren
        migrateFromUserDefaultsIfNeeded()

        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([EmailAccount].self, from: data)
        else { return }
        accounts = decoded
    }

    // MARK: – Migration von UserDefaults (einmalig)

    private func migrateFromUserDefaultsIfNeeded() {
        let legacyKey = "imailsecure.accounts"
        guard let legacyData = UserDefaults.standard.data(forKey: legacyKey),
              let decoded = try? JSONDecoder().decode([EmailAccount].self, from: legacyData)
        else { return }

        // Daten in geschützte Datei schreiben
        accounts = decoded
        save()

        // Aus UserDefaults entfernen
        UserDefaults.standard.removeObject(forKey: legacyKey)
        print("[AccountStore] Migration von UserDefaults abgeschlossen.")
    }
}
