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

final class MailSyncEngine {
    let account: EmailAccount
    weak var mailStore: MailStore?
    private let logger = Logger(label: "io.imailsecure.sync")

    init(account: EmailAccount, mailStore: MailStore) {
        self.account   = account
        self.mailStore = mailStore
    }

    // MARK: – Sync

    func sync() async {
        guard let password = account.password else {
            await MainActor.run { mailStore?.lastSyncError = "Kein Passwort gespeichert." }
            return
        }

        do {
            // N2: TOFU-Fingerabdruck-Pinning vor Verbindungsaufbau
            // (nur Port 993/465 – Implicit TLS; STARTTLS-Ports durch BoringSSL fullVerification)
            try await CertificatePinner.shared.verifyAndPin(
                host: account.imapHost, port: account.imapPort)

            // useTLS: true erzwingt TLS auf allen Ports (N1/N2).
            // Port 993 → implicitTLS | Port 143 → STARTTLS required
            let server = IMAPServer(
                host:   account.imapHost,
                port:   account.imapPort,
                useTLS: true
            )
            try await server.connect()
            try await server.login(username: account.username, password: password)
            let mailboxInfo = try await server.selectMailbox("INBOX")
            let total = mailboxInfo.messageCount
            #if DEBUG
            logger.debug("INBOX: \(total) Nachrichten")
            #endif
            if total > 0, let set = mailboxInfo.latest(min(total, 50)) {
                var fetched: [Message] = []
                for try await message in server.fetchMessages(using: set) {
                    fetched.append(message)
                }
                let converted = fetched.compactMap { convert($0) }
                #if DEBUG
                logger.debug("Sync OK: \(converted.count) konvertiert")
                #endif
                await MainActor.run { mailStore?.merge(incoming: converted) }
            }
            try await server.logout()
            await MainActor.run { mailStore?.lastSyncError = nil }
        } catch {
            logger.error("Sync-Fehler: \(error.localizedDescription)")
            await MainActor.run {
                mailStore?.lastSyncError = error.localizedDescription
            }
        }
    }

    // MARK: – Löschen auf dem Server

    func deleteOnServer(uid: UInt32) async {
        guard let password = account.password else { return }
        do {
            try await CertificatePinner.shared.verifyAndPin(
                host: account.imapHost, port: account.imapPort)
            let server = IMAPServer(
                host:   account.imapHost,
                port:   account.imapPort,
                useTLS: true   // N1/N2: TLS erzwungen
            )
            try await server.connect()
            try await server.login(username: account.username, password: password)
            try await server.selectMailbox("INBOX")

            let nioUID = UID(uid)
            let uidSet: UIDSet = UIDSet(nioUID)
            try await server.store(flags: [.deleted], on: uidSet, operation: .add)
            try await server.expunge()
            try await server.logout()
            logger.info("UID auf Server gelöscht")
        } catch {
            logger.error("Server-Löschen fehlgeschlagen: \(error.localizedDescription)")
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

    // MARK: – Message → EmailMessage

    func convert(_ msg: Message) -> EmailMessage? {
        let senderAddress = msg.from ?? "unknown@unknown"
        let toRecipients  = msg.to.map  { EmailAddress(name: nil, address: $0) }
        let ccRecipients  = msg.cc.map  { EmailAddress(name: nil, address: $0) }
        let uidValue      = msg.uid.map { UInt32("\($0)") ?? 0 } ?? 0
        let msgID         = msg.header.messageId.map { "\($0)" } ?? UUID().uuidString
        let isRead        = msg.flags.contains(.seen)

        let mdnRequested  = msg.header.additionalFields?["disposition-notification-to"] != nil
        let body          = msg.textBody ?? msg.htmlBody?.strippedHTML ?? ""

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
            isRead: isRead,
            attachments: attachments,
            mdnRequested: mdnRequested,
            folder: "INBOX"
        )
    }
}
