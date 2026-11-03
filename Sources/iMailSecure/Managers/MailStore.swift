// MailStore.swift
import Foundation
import Combine

@MainActor
final class MailStore: ObservableObject {
    @Published var messages: [EmailMessage] = []
    @Published var isSyncing: Bool = false
    @Published var lastSyncError: String?

    /// Ordner je Konto. Quelle ist die IMAP-LIST-Antwort des Servers.
    @Published private(set) var foldersByAccount: [UUID: [MailFolder]] = [:]

    /// Was die Nachrichtenliste zeigt. `nil` bis der erste Sync die
    /// Ordner geliefert hat — dann wird der Posteingang des ersten Kontos
    /// ausgewählt. Free-Nutzer landen dadurch nie im Pro-Postfach.
    @Published var selection: MailboxSelection?

    private var syncEngines: [UUID: MailSyncEngine] = [:]
    /// Konto-Stand, mit dem die jeweilige Engine gebaut wurde. Ändert sich
    /// das Konto (Host, Port, Aktivierung), wird die Engine neu erzeugt.
    private var engineAccounts: [UUID: EmailAccount] = [:]
    /// Zählt laufende Syncs. Ein boolesches Flag würde den Spinner zu früh
    /// ausblenden, wenn z. B. ein Kontowechsel und ein Refresh parallel laufen.
    private var activeSyncs = 0

    /// Gleicht die Sync-Engines mit den gespeicherten Konten ab.
    /// Idempotent: kann nach jedem Hinzufügen/Löschen/Deaktivieren erneut
    /// aufgerufen werden, ohne bestehende Engines zu verlieren.
    func loadAccounts(from store: AccountStore) {
        let activeAccounts = store.accounts.filter(\.isActive)
        let activeIDs = Set(activeAccounts.map(\.id))

        // Engines und Ordner für gelöschte oder deaktivierte Konten entfernen.
        syncEngines = syncEngines.filter { activeIDs.contains($0.key) }
        engineAccounts = engineAccounts.filter { activeIDs.contains($0.key) }
        for id in Set(foldersByAccount.keys).subtracting(activeIDs) {
            foldersByAccount[id] = nil
        }
        if case .folder(let id, _) = selection, !activeIDs.contains(id) {
            selection = nil
        }

        for account in activeAccounts where engineAccounts[account.id] != account {
            syncEngines[account.id] = MailSyncEngine(account: account, mailStore: self)
            engineAccounts[account.id] = account
        }
    }

    // MARK: – Synchronisieren

    /// Vollständiger Abgleich aller Konten: Ordnerliste + Posteingang.
    func syncAll() async {
        beginSync()
        defer { endSync() }

        let engines = Array(syncEngines.values)
        await withTaskGroup(of: Void.self) { group in
            for engine in engines {
                group.addTask { await engine.initialSync() }
            }
        }
    }

    /// Nur die Ordnerlisten neu laden (z. B. nach dem Anlegen eines Ordners).
    func refreshFolders() async {
        let engines = Array(syncEngines.values)
        await withTaskGroup(of: Void.self) { group in
            for engine in engines {
                group.addTask { await engine.refreshFolders() }
            }
        }
    }

    /// Die aktuelle Auswahl aktualisieren. Ohne Auswahl wird alles geladen.
    func sync(_ selection: MailboxSelection?) async {
        guard let selection else {
            await syncAll()
            return
        }

        beginSync()
        defer { endSync() }

        switch selection {
        case .unifiedInbox:
            let engines = Array(syncEngines.values)
            await withTaskGroup(of: Void.self) { group in
                for engine in engines {
                    group.addTask { await engine.syncInbox() }
                }
            }
        case .folder(let accountID, let folder):
            await syncEngines[accountID]?.sync(folderNamed: folder.name)
        }
    }

    private func beginSync() {
        activeSyncs += 1
        isSyncing = true
    }

    private func endSync() {
        activeSyncs = max(0, activeSyncs - 1)
        isSyncing = activeSyncs > 0
    }

    /// Ordner auswählen und im Hintergrund laden.
    func select(_ newSelection: MailboxSelection) {
        selection = newSelection
        Task { await sync(newSelection) }
    }

    /// Nach dem Ende eines Abos: Pro-Auswahl auf einen freien Systemordner
    /// zurückfallen lassen. Es wird nichts gelöscht — nur der Komfort endet.
    func fallBackToFreeSelection() {
        guard let selection else { return }
        switch selection {
        case .unifiedInbox:
            self.selection = firstInboxSelection()
        case .folder(let accountID, let folder) where folder.requiresPro:
            self.selection = defaultSelection(for: accountID, in: folders(for: accountID))
        case .folder:
            break
        }
    }

    private func firstInboxSelection() -> MailboxSelection? {
        for (accountID, folders) in foldersByAccount {
            if let inbox = folders.first(where: { $0.role == .inbox }) {
                return .folder(accountID: accountID, folder: inbox)
            }
        }
        return nil
    }

    // MARK: – Ordner

    /// Übernimmt die Ordnerliste eines Kontos und wählt beim ersten Mal
    /// dessen Posteingang aus. Verschwindet der ausgewählte Ordner auf dem
    /// Server, fällt die Auswahl auf den Posteingang zurück.
    func setFolders(_ folders: [MailFolder], for accountID: UUID) {
        let cleaned = MailFolder.sorted(folders)
        foldersByAccount[accountID] = cleaned

        switch selection {
        case .none:
            selection = defaultSelection(for: accountID, in: cleaned)
        case .some(.folder(let id, let folder)):
            if id == accountID, !cleaned.contains(where: { $0.name == folder.name }) {
                selection = defaultSelection(for: accountID, in: cleaned)
            }
        case .some(.unifiedInbox):
            break
        }
    }

    private func defaultSelection(
        for accountID: UUID,
        in folders: [MailFolder]
    ) -> MailboxSelection? {
        guard let inbox = folders.first(where: { $0.role == .inbox }) else { return nil }
        return .folder(accountID: accountID, folder: inbox)
    }

    func folders(for accountID: UUID) -> [MailFolder] {
        foldersByAccount[accountID] ?? []
    }

    func folder(for accountID: UUID, role: MailFolderRole) -> MailFolder? {
        foldersByAccount[accountID]?.first { $0.role == role }
    }

    func folder(for accountID: UUID, name: String) -> MailFolder? {
        foldersByAccount[accountID]?.first { $0.name == name }
    }

    func folderDelimiter(for accountID: UUID) -> String? {
        foldersByAccount[accountID]?.compactMap(\.delimiter).first
    }

    func createFolder(named name: String, for accountID: UUID) async throws {
        guard let engine = syncEngines[accountID] else {
            throw MailFolderError.noAccount
        }
        try await engine.createFolder(named: name)
    }

    // MARK: – Nachrichten

    /// Nachrichten für die aktuelle Auswahl, neueste zuerst.
    func messages(for selection: MailboxSelection) -> [EmailMessage] {
        let filtered: [EmailMessage]
        switch selection {
        case .unifiedInbox:
            filtered = messages.filter(isInbox)
        case .folder(let accountID, let folder):
            filtered = messages.filter {
                $0.accountID == accountID && $0.folder == folder.name
            }
        }
        return filtered.sorted { $0.date > $1.date }
    }

    /// Rolle statt Namensvergleich: Ein Konto kann seinen Posteingang anders
    /// nennen, und ein eigener Ordner darf nicht versehentlich als Inbox gelten.
    private func isInbox(_ message: EmailMessage) -> Bool {
        if let folder = folder(for: message.accountID, name: message.folder) {
            return folder.role == .inbox
        }
        return message.folder.uppercased() == "INBOX"
    }

    /// Ungelesene im gemeinsamen Posteingang — Grundlage für das Tab-Badge.
    var unreadInboxCount: Int {
        messages(for: .unifiedInbox).filter { !$0.isRead }.count
    }

    func markAsRead(_ message: EmailMessage) {
        if let idx = messages.firstIndex(where: { $0.listID == message.listID }) {
            messages[idx].isRead = true
        }
    }

    // Lokal in den Papierkorb verschieben + auf dem Server dorthin bewegen.
    func delete(_ message: EmailMessage) {
        let trashName = folder(for: message.accountID, role: .trash)?.name

        if let idx = messages.firstIndex(where: { $0.listID == message.listID }) {
            messages[idx].folder = trashName ?? "Papierkorb"
            messages[idx].isMarkedDeleted = true
        }

        // Nur wenn die UID gültig ist (> 0): verhindert den Absturz
        // "arithmetic overflow" in der NIOIMAP-Library.
        if message.uid > 0, let engine = syncEngines[message.accountID] {
            Task { await engine.moveToTrash(message, trashFolder: trashName) }
        }
    }

    func permanentlyDelete(_ message: EmailMessage) {
        messages.removeAll { $0.listID == message.listID }
    }

    // Gesendete Mail im Gesendet-Ordner des Kontos ablegen
    func saveSentMessage(draft: EmailDraft, account: EmailAccount) {
        let folderName = folder(for: account.id, role: .sent)?.name ?? "Gesendet"

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
            folder: folderName
        )
        messages.append(sent)
    }

    // MDN-Benachrichtigungen verarbeiten
    func merge(incoming: [EmailMessage]) {
        var seen = Set(messages.map(\.listID))
        let new = incoming.filter { seen.insert($0.listID).inserted }
        messages.append(contentsOf: new)
        for msg in new {
            if let mdn = MDNProcessor.processMDN(message: msg) {
                applyMDN(mdn)
            }
        }
    }

    private func applyMDN(_ mdn: MDNNotification) {
        // Eine MDN gilt für die Message-ID, also für alle Ordner-Kopien.
        for idx in messages.indices where messages[idx].id == mdn.originalMessageID {
            messages[idx].receiptReceived = true
            messages[idx].receiptDate = mdn.receivedAt
        }
    }
}
