// MailSyncEngine.swift
// N1/N2 GELÖST (2026-10-31):
//   IMAPServer(host:, port:, useTLS: true)
//   • Port 993 → implicitTLS   (BoringSSL, TLS ≥ 1.2, .fullVerification gegen System-Roots)
//   • Port 143 → startTLSIfAvailable(requireTLS: true)
//     Falls der Server STARTTLS nicht anbietet: IMAPError.connectionFailed → kein Fallback auf Klartext
//
// SMTP ist bereits sicher:
//   • Port 587 → STARTTLS erzwungen, bei Fehler: SMTPError.tlsFailed (fail-closed)
//   • Port 465 → SMTPS implizit (BoringSSL)
//   Kein useTLS-Parameter nötig – SwiftMail entscheidet per Port.
//
// Was bleibt (Audit N2 offen):
//   Fingerabdruck-Pinning (Trust On First Use) ist in der aktuellen SwiftMail-API nicht exponiert.
//   CertificateVerification ist in swift-nio-ssl vorhanden, aber IMAPServer/SMTPServer
//   nehmen keine TLSConfiguration entgegen. → SwiftMail-Feature-Request / eigener PR nötig.
import Foundation
import Logging
import SwiftMail

enum MailSyncError: LocalizedError {
    case missingPassword

    var errorDescription: String? {
        switch self {
        case .missingPassword: return "Kein Passwort gespeichert."
        }
    }
}

final class MailSyncEngine {
    let account: EmailAccount
    weak var mailStore: MailStore?
    private let logger = Logger(label: "io.imailsecure.sync")

    /// Wie viele Nachrichten pro Ordner beim Öffnen geladen werden.
    /// Bewusst klein: ein Ordner mit 10.000 Mails soll die App nicht
    /// minutenlang blockieren. Der Rest kommt über die Suche.
    private let pageSize = 50

    init(account: EmailAccount, mailStore: MailStore) {
        self.account   = account
        self.mailStore = mailStore
    }

    // MARK: – Sync

    /// Vollständiger Abgleich: Ordnerliste holen und den Posteingang laden.
    /// Wird beim App-Start und bei „Alle aktualisieren" aufgerufen.
    func initialSync() async {
        let folders: [MailFolder]
        do {
            folders = try await fetchFolders()
        } catch {
            await report(error)
            return
        }

        await MainActor.run {
            mailStore?.setFolders(folders, for: account.id)
            mailStore?.lastSyncError = nil
        }

        // Fallback „INBOX" nur für Server, die den Posteingang nicht als
        // auswählbaren Ordner melden. Das ist selten, aber billig abzufangen.
        let inbox = folders.first { $0.role == .inbox }?.name ?? "INBOX"
        await sync(folderNamed: inbox)
    }

    /// Nur die Ordnerliste neu laden. Wird nach dem Anlegen eines Ordners
    /// und beim Öffnen der Ordnerauswahl verwendet.
    func refreshFolders() async {
        do {
            let folders = try await fetchFolders()
            await MainActor.run {
                mailStore?.setFolders(folders, for: account.id)
                mailStore?.lastSyncError = nil
            }
        } catch {
            await report(error)
        }
    }

    /// Posteingang dieses Kontos laden, ohne die Ordnerliste erneut zu holen.
    func syncInbox() async {
        let name = await MainActor.run {
            mailStore?.folder(for: account.id, role: .inbox)?.name
        } ?? "INBOX"
        await sync(folderNamed: name)
    }

    /// Einen bestimmten Ordner laden.
    func sync(folderNamed name: String) async {
        do {
            let converted = try await withServer { server in
                try await fetchMessages(from: server, folder: name)
            }
            await MainActor.run {
                mailStore?.merge(incoming: converted)
                mailStore?.lastSyncError = nil
            }
        } catch {
            await report(error)
        }
    }

    // MARK: – Ordner anlegen, umbenennen, löschen

    /// Legt einen Ordner auf dem Server an und aktualisiert die lokale Liste.
    @discardableResult
    func createFolder(named rawName: String) async throws -> MailFolder? {
        let delimiter = await MainActor.run {
            mailStore?.folderDelimiter(for: account.id)
        }
        let name = try MailFolder.validatedName(rawName, delimiter: delimiter)

        let existing = await MainActor.run {
            mailStore?.folders(for: account.id) ?? []
        }
        guard !existing.contains(where: {
            $0.name.caseInsensitiveCompare(name) == .orderedSame
        }) else {
            throw MailFolderError.alreadyExists
        }

        let folders = try await withServer { server -> [MailFolder] in
            try await server.createMailbox(name)
            return try await listFolders(from: server)
        }

        await MainActor.run {
            mailStore?.setFolders(folders, for: account.id)
            mailStore?.lastSyncError = nil
        }
        return folders.first { $0.name == name }
    }

    /// Benennt einen eigenen Ordner auf dem Server um. Der neue Name gilt nur
    /// für das letzte Pfadsegment; der Elternordner bleibt erhalten, damit ein
    /// verschachtelter Ordner nicht versehentlich nach oben wandert.
    @discardableResult
    func renameFolder(_ folder: MailFolder, toLeaf leaf: String) async throws -> MailFolder? {
        let delimiter: String?
        if let known = folder.delimiter {
            delimiter = known
        } else {
            delimiter = await MainActor.run {
                mailStore?.folderDelimiter(for: account.id)
            }
        }
        let newName = try folder.renamedPath(to: leaf, delimiter: delimiter)
        guard newName != folder.name else { return folder }

        let existing = await MainActor.run {
            mailStore?.folders(for: account.id) ?? []
        }
        guard !existing.contains(where: {
            $0.name.caseInsensitiveCompare(newName) == .orderedSame
        }) else {
            throw MailFolderError.alreadyExists
        }

        let folders = try await withServer { server -> [MailFolder] in
            try await server.renameMailbox(folder.name, to: newName)
            return try await listFolders(from: server)
        }

        await MainActor.run {
            mailStore?.setFolders(folders, for: account.id)
            mailStore?.lastSyncError = nil
        }
        return folders.first { $0.name == newName }
    }

    /// Löscht einen eigenen Ordner samt Inhalt auf dem Server.
    func deleteFolder(_ folder: MailFolder) async throws {
        let folders = try await withServer { server -> [MailFolder] in
            try await server.deleteMailbox(folder.name)
            return try await listFolders(from: server)
        }

        await MainActor.run {
            mailStore?.setFolders(folders, for: account.id)
            mailStore?.lastSyncError = nil
        }
    }

    // MARK: – Löschen / Verschieben

    /// Verschiebt eine Nachricht in den Papierkorb des Kontos. Kennt die App
    /// den Papierkorb (noch) nicht, wird wie bisher endgültig gelöscht.
    func moveToTrash(_ message: EmailMessage, trashFolder: String?) async {
        guard message.uid > 0 else { return }

        do {
            try await withServer { server in
                try await server.selectMailbox(message.folder)
                let uid = UID(message.uid)

                if let trashFolder, trashFolder != message.folder {
                    try await server.move(message: uid, to: trashFolder)
                } else {
                    // Schon im Papierkorb oder kein Papierkorb bekannt:
                    // endgültig löschen (bisheriges Verhalten).
                    let uidSet = UIDSet(uid)
                    try await server.store(flags: [.deleted], on: uidSet, operation: .add)
                    try await server.expunge()
                }
            }
            await MainActor.run { mailStore?.lastSyncError = nil }
        } catch {
            await report(error)
        }
    }

    // MARK: – MDN-Bestätigung senden

    func sendMDN(for message: EmailMessage, to address: String) async {
        let smtpManager = SMTPManager(account: account)
        var draft = EmailDraft()
        draft.toText  = address
        draft.subject = "Read: \(message.subject)"
        draft.body    = """
        This is a Message Disposition Notification (MDN) receipt.
        The message was displayed on \(Date().formatted()).
        Original-Message-ID: \(message.id)
        Disposition: automatic-action/MDN-sent-automatically; displayed
        """
        do {
            try await smtpManager.sendEmail(draft: draft)
            logger.info("MDN erfolgreich gesendet")
        } catch {
            logger.error("MDN-Versand fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    // MARK: – Verbindung

    /// Eine Verbindung pro Operation. Konto-Passwort, TLS-Pinning und
    /// Abmelden liegen an genau einer Stelle — kein Pfad kann sie vergessen.
    private func withServer<T>(_ operation: (IMAPServer) async throws -> T) async throws -> T {
        guard let password = account.password else {
            throw MailSyncError.missingPassword
        }

        // N2: TOFU-Fingerabdruck-Pinning vor Verbindungsaufbau
        // (nur Port 993/465 – Implicit TLS; STARTTLS-Ports durch BoringSSL fullVerification)
        try await CertificatePinner.shared.verifyAndPin(
            host: account.imapHost, port: account.imapPort)

        // useTLS: true erzwingt TLS auf allen Ports (N1/N2).
        // Port 993 → implicitTLS | Port 143 → STARTTLS required
        // Explizite Policy statt Port-Heuristik: STARTTLS bleibt erzwungen,
        // auch wenn der Nutzer einen abweichenden Port einträgt.
        let server = IMAPServer(
            host:   account.imapHost,
            port:   account.imapPort,
            transportSecurity: account.imapSecurity.mailTransportSecurity
        )
        try await server.connect()

        do {
            try await server.login(username: account.username, password: password)
            let result = try await operation(server)
            try? await server.logout()
            return result
        } catch {
            // Abbruch darf nicht am Logout scheitern.
            try? await server.logout()
            throw error
        }
    }

    private func listFolders(from server: IMAPServer) async throws -> [MailFolder] {
        // `listSpecialUseMailboxes()` ruft intern bereits die vollständige
        // Liste ab und ergänzt die RFC-6154-Attribute. Damit werden auch
        // lokalisierte Systemordner erkannt, deren Namen wir nicht kennen.
        let infos: [Mailbox.Info]
        if let special = try? await server.listSpecialUseMailboxes() {
            let attributesByName = Dictionary(
                special.map { ($0.name, $0.attributes) },
                uniquingKeysWith: { $0.union($1) }
            )
            infos = await server.mailboxes.map { info in
                guard let extra = attributesByName[info.name] else { return info }
                return Mailbox.Info(
                    name: info.name,
                    attributes: info.attributes.union(extra),
                    hierarchyDelimiter: info.hierarchyDelimiter
                )
            }
        } else {
            infos = try await server.listMailboxes()
        }
        return MailFolder.sorted(infos.map(MailFolder.init(info:)))
    }

    private func fetchFolders() async throws -> [MailFolder] {
        try await withServer { server in
            try await listFolders(from: server)
        }
    }

    private func fetchMessages(from server: IMAPServer, folder: String) async throws -> [EmailMessage] {
        let mailboxInfo = try await server.selectMailbox(folder)
        let total = mailboxInfo.messageCount
        #if DEBUG
        logger.debug("\(folder): \(total) Nachrichten")
        #endif

        guard total > 0, let set = mailboxInfo.latest(min(total, pageSize)) else {
            return []
        }

        var fetched: [Message] = []
        for try await message in server.fetchMessages(using: set) {
            fetched.append(message)
        }
        return fetched.compactMap { convert($0, folder: folder) }
    }

    private func report(_ error: Error) async {
        logger.error("Sync-Fehler: \(error.localizedDescription)")
        await MainActor.run {
            mailStore?.lastSyncError = error.localizedDescription
        }
    }

    // MARK: – Message → EmailMessage

    func convert(_ msg: Message, folder: String = "INBOX") -> EmailMessage? {
        let senderAddress = msg.from ?? "unknown@unknown"
        let toRecipients  = msg.to.map  { EmailAddress(name: nil, address: $0) }
        let ccRecipients  = msg.cc.map  { EmailAddress(name: nil, address: $0) }
        let uidValue      = msg.uid.map { UInt32("\($0)") ?? 0 } ?? 0
        let msgID         = msg.header.messageId.map { "\($0)" } ?? UUID().uuidString
        let isRead        = msg.flags.contains(.seen)

        let mdnRequested  = msg.header.additionalFields?["disposition-notification-to"] != nil
        // Klartext bleibt die Standardansicht. Die HTML-Fassung wird
        // mitgeführt, aber erst nach Knopfdruck gerendert (D2).
        let htmlBody      = msg.htmlBody?.isEmpty == false ? msg.htmlBody : nil
        let body          = msg.textBody ?? htmlBody?.strippedHTML ?? ""

        let attachments: [EmailAttachment] = msg.attachments.map { att in
            EmailAttachment(
                filename: att.filename ?? "Anhang",
                mimeType: att.contentType,
                data: att.data ?? Data()
            )
        }

        return EmailMessage(
            id: msgID,
            uid: uidValue,
            accountID: account.id,
            from: EmailAddress(name: nil, address: senderAddress),
            to: toRecipients,
            cc: ccRecipients,
            subject: msg.subject ?? "(kein Betreff)",
            date: msg.date ?? Date(),
            body: body,
            htmlBody: htmlBody,
            isHTML: htmlBody != nil,
            isRead: isRead,
            attachments: attachments,
            mdnRequested: mdnRequested,
            folder: folder
        )
    }
}
