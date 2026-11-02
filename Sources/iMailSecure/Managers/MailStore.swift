// MailStore.swift
import Foundation
import Combine

@MainActor
final class MailStore: ObservableObject {    @Published var messages: [EmailMessage] = []
    @Published var isSyncing: Bool = false
    @Published var lastSyncError: String?

    private var syncEngines: [UUID: MailSyncEngine] = [:]
    /// Konto-Stand, mit dem die jeweilige Engine gebaut wurde. Ändert sich
    /// das Konto (Host, Port, Aktivierung), wird die Engine neu erzeugt.
    private var engineAccounts: [UUID: EmailAccount] = [:]

    /// Gleicht die Sync-Engines mit den gespeicherten Konten ab.
    /// Idempotent: kann nach jedem Hinzufügen/Löschen/Deaktivieren erneut
    /// aufgerufen werden, ohne bestehende Engines zu verlieren.
    func loadAccounts(from store: AccountStore) {
        let activeAccounts = store.accounts.filter(\.isActive)
        let activeIDs = Set(activeAccounts.map(\.id))

        // Engines für gelöschte oder deaktivierte Konten entfernen.
        syncEngines = syncEngines.filter { activeIDs.contains($0.key) }
        engineAccounts = engineAccounts.filter { activeIDs.contains($0.key) }

        for account in activeAccounts where engineAccounts[account.id] != account {
            syncEngines[account.id] = MailSyncEngine(account: account, mailStore: self)
            engineAccounts[account.id] = account
        }
    }

    func syncAll() async {
        await MainActor.run { isSyncing = true }
        await withTaskGroup(of: Void.self) { group in
            for engine in syncEngines.values {
                group.addTask { await engine.sync() }
            }
        }
        await MainActor.run { isSyncing = false }
    }

    func messages(for folder: String) -> [EmailMessage] {
        messages.filter { $0.folder == folder }.sorted { $0.date > $1.date }
    }

    func markAsRead(_ message: EmailMessage) {
        if let idx = messages.firstIndex(where: { $0.id == message.id }) {
            messages[idx].isRead = true
        }
    }

    // Lokal in Papierkorb verschieben + auf Server löschen
    // Lokal in Papierkorb verschieben + auf Server löschen
        func delete(_ message: EmailMessage) {
            if let idx = messages.firstIndex(where: { $0.id == message.id }) {
                messages[idx].folder = "Papierkorb"
                messages[idx].isMarkedDeleted = true
            }
            
            // Asynchron auf Server löschen - nur wenn UID gültig (> 0)
            // Das verhindert den Absturz "arithmetic overflow" in der NIOIMAP-Library
            if message.uid > 0, let engine = syncEngines[message.accountID] {
                Task { await engine.deleteOnServer(uid: message.uid) }
            }
        }
    func permanentlyDelete(_ message: EmailMessage) {
        messages.removeAll { $0.id == message.id }
    }

    // Gesendete Mail im Gesendet-Ordner ablegen
    func saveSentMessage(draft: EmailDraft, account: EmailAccount) {
        let sent = EmailMessage(
            id: "<sent-\(UUID().uuidString)@imailsecure.local>",
            uid: 0,
            accountID: account.id,
            from: EmailAddress(name: account.displayName, address: account.email),
            to: draft.to,
            cc: draft.cc,
            subject: draft.subject,
            date: Date(),
            body: draft.body,
            isRead: true,
            mdnRequested: draft.requestMDN,
            folder: "Gesendet"
        )
        messages.append(sent)
    }

    // MDN-Benachrichtigungen verarbeiten
    func merge(incoming: [EmailMessage]) {
        let existingIDs = Set(messages.map(\.id))
        let new = incoming.filter { !existingIDs.contains($0.id) }
        messages.append(contentsOf: new)
        for msg in new {
            if let mdn = MDNProcessor.processMDN(message: msg) {
                applyMDN(mdn)
            }
        }
    }

    private func applyMDN(_ mdn: MDNNotification) {
        if let idx = messages.firstIndex(where: { $0.id == mdn.originalMessageID }) {
            messages[idx].receiptReceived = true
            messages[idx].receiptDate = mdn.receivedAt
        }
    }
}
