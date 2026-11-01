// SMTPManager.swift
import Foundation
import Logging
import SwiftMail

enum SMTPError: LocalizedError {
    case noPassword
    var errorDescription: String? { "Kein Passwort gespeichert. Bitte Konto bearbeiten." }
}

final class SMTPManager {
    private let account: EmailAccount
    private let logger = Logger(label: "io.imailsecure.smtp")

    init(account: EmailAccount) { self.account = account }

    func sendEmail(draft: EmailDraft) async throws {
        guard let password = account.password else { throw SMTPError.noPassword }
        #if DEBUG
        logger.debug("Sende Mail via \(account.smtpHost)")
        #endif

        let sender = SwiftMail.EmailAddress(name: account.displayName, address: account.email)
        let to = draft.to.map { SwiftMail.EmailAddress(name: $0.name ?? "", address: $0.address) }
        let cc = draft.cc.map { SwiftMail.EmailAddress(name: $0.name ?? "", address: $0.address) }

        // Anhänge als SwiftMail.Attachment Array aufbauen
        let attachments: [SwiftMail.Attachment] = draft.attachments.map { att in
            SwiftMail.Attachment(
                filename: att.filename,
                mimeType: att.mimeType,
                data: att.data
            )
        }

        // Email mit allen Parametern auf einmal erstellen
        var email = Email(
            sender: sender,
            recipients: to,
            subject: draft.subject,
            textBody: draft.body,
            attachments: attachments
        )

        // CC
        if !cc.isEmpty { email.ccRecipients = cc }

        // MDN-Header
        var extraHeaders: [String: String] = [:]
        if draft.requestMDN {
            extraHeaders["Disposition-Notification-To"] = account.email
            extraHeaders["Disposition-Notification-Options"] =
                "X-MDNSent-Type=displayed; x-unsupported-parameter=true"
        }
        if draft.requestReceipt {
            extraHeaders["Return-Receipt-To"] = account.email
        }
        if !extraHeaders.isEmpty { email.additionalHeaders = extraHeaders }

        let server = SMTPServer(host: account.smtpHost, port: account.smtpPort)

        // N2: TOFU-Fingerabdruck-Pinning auch für den Versandpfad.
        // Greift bei implicit TLS (Port 465); bei STARTTLS (587/25) übernimmt die
        // Zertifikatsprüfung der TLS-Schicht in SwiftMail (fail-closed).
        // Muss VOR dem Verbindungsaufbau laufen, sonst ist der Handshake bereits durch.
        try await CertificatePinner.shared.verifyAndPin(
            host: account.smtpHost,
            port: account.smtpPort
        )

        // N1/N2 – TLS-Modus vorbereitet.
        // Sobald SwiftMail eine TLSConfiguration-Übergabe anbietet:
        //   var tlsConfig = TLSConfiguration.makeClientConfiguration()
        //   tlsConfig.minimumTLSVersion = .tlsv12
        //   let server = SMTPServer(
        //       host: account.smtpHost, port: account.smtpPort,
        //       connectionSecurity: account.smtpSecurity == .implicit ? .implicit : .startTLS,
        //       tlsConfiguration: tlsConfig)
        try await server.connect()
        try await server.login(username: account.username, password: password)
        try await server.sendEmail(email)
        try await server.disconnect()

        logger.info("Mail versendet (\(draft.attachments.count) Anhänge)")
    }
}
