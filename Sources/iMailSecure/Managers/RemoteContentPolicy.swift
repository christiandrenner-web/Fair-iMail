// RemoteContentPolicy.swift
//
// D2, Stufe 3: Merkt sich, für welche Absender externe Inhalte ausdrücklich
// freigegeben wurden.
//
// Grundsatz: blockiert ist der Standard. Eine Freigabe gilt entweder
//   • nur für eine einzelne Mail (nicht persistiert, nur im Speicher), oder
//   • dauerhaft für einen Absender (UserDefaults, widerrufbar).
//
// Bewusst keine Freigabe „pro Domain": eine Domain kann viele Absender
// umfassen, und ein kompromittierter Absender würde damit alle anderen
// mitfreischalten.

import Foundation
import Combine

@MainActor
final class RemoteContentPolicy: ObservableObject {

    static let shared = RemoteContentPolicy()

    static let defaultsKey = "imailsecure.trustedRemoteSenders"

    /// Absender-Adressen (normalisiert), für die dauerhaft freigegeben wurde.
    @Published private(set) var trustedSenders: Set<String>

    /// Einmalige Freigaben für einzelne Mails. Nicht persistiert.
    private var allowedMessageIDs: Set<String> = []

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.stringArray(forKey: Self.defaultsKey) ?? []
        self.trustedSenders = Set(stored.map(Self.normalize))
    }

    static func normalize(_ sender: String) -> String {
        sender.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    // MARK: – Abfragen

    func isTrusted(sender: String) -> Bool {
        trustedSenders.contains(Self.normalize(sender))
    }

    func isAllowed(messageID: String, sender: String) -> Bool {
        allowedMessageIDs.contains(messageID) || isTrusted(sender: sender)
    }

    var sortedTrustedSenders: [String] {
        trustedSenders.sorted()
    }

    // MARK: – Freigeben

    func allowOnce(messageID: String) {
        allowedMessageIDs.insert(messageID)
    }

    func allowAlways(sender: String) {
        let key = Self.normalize(sender)
        guard !key.isEmpty else { return }
        trustedSenders.insert(key)
        persist()
    }

    // MARK: – Widerrufen

    func revoke(sender: String) {
        trustedSenders.remove(Self.normalize(sender))
        persist()
    }

    func revokeAll() {
        trustedSenders.removeAll()
        allowedMessageIDs.removeAll()
        persist()
    }

    private func persist() {
        defaults.set(sortedTrustedSenders, forKey: Self.defaultsKey)
    }
}
