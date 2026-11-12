// EmailAccount.swift
import Foundation

// MARK: – Verbindungssicherheit

/// Erlaubte TLS-Modi für IMAP und SMTP.
/// Klartext ist bewusst ausgeschlossen – iMail Secure erlaubt niemals
/// unverschlüsselte Verbindungen.
enum ConnectionSecurity: String, Codable, CaseIterable {
    /// Implizites TLS (IMAP 993, SMTP 465) – Verbindung ist sofort verschlüsselt.
    case implicit   = "implicit_tls"
    /// STARTTLS erzwungen (IMAP 143, SMTP 587) – Upgrade wird vor Login verlangt.
    /// Schlägt das Upgrade fehl, wird die Verbindung abgebrochen.
    case startTLS   = "starttls"

    // Klartext absichtlich nicht vorhanden.

    var displayName: String {
        switch self {
        case .implicit:
            return String(localized: "security.implicit",
                          defaultValue: "SSL/TLS (empfohlen)")
        case .startTLS:
            return String(localized: "security.starttls",
                          defaultValue: "STARTTLS (erzwungen)")
        }
    }

    /// Standardport für IMAP
    var defaultIMAPPort: Int {
        switch self {
        case .implicit:  return 993
        case .startTLS:  return 143
        }
    }

    /// Standardport für SMTP
    var defaultSMTPPort: Int {
        switch self {
        case .implicit:  return 465
        case .startTLS:  return 587
        }
    }
}

// MARK: – Modell

struct EmailAccount: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var displayName: String
    var email: String

    // IMAP
    var imapHost: String
    var imapPort: Int
    var imapSecurity: ConnectionSecurity = .implicit

    // SMTP
    var smtpHost: String
    var smtpPort: Int
    var smtpSecurity: ConnectionSecurity = .implicit

    var username: String
    var isActive: Bool = true

    // MARK: – Rückwärtskompatibilität (alte Bool-Felder)
    // CodingKeys damit imapUseTLS/smtpUseTLS beim Laden ignoriert werden
    private enum CodingKeys: String, CodingKey {
        case id, displayName, email
        case imapHost, imapPort, imapSecurity
        case smtpHost, smtpPort, smtpSecurity
        case username, isActive
    }

    // MARK: – Port-Validierung

    /// Gibt einen Fehlertext zurück wenn Port und Sicherheitsmodus nicht passen.
    var imapPortWarning: String? {
        switch imapSecurity {
        case .implicit  where imapPort != 993:
            return String(localized: "security.imap.port.implicit",
                          defaultValue: "SSL/TLS verwendet üblicherweise Port 993.")
        case .startTLS  where imapPort != 143:
            return String(localized: "security.imap.port.starttls",
                          defaultValue: "STARTTLS verwendet üblicherweise Port 143.")
        default:
            return nil
        }
    }

    var smtpPortWarning: String? {
        switch smtpSecurity {
        case .implicit  where smtpPort != 465:
            return String(localized: "security.smtp.port.implicit",
                          defaultValue: "SSL/TLS verwendet üblicherweise Port 465.")
        case .startTLS  where smtpPort != 587 && smtpPort != 25:
            return String(localized: "security.smtp.port.starttls",
                          defaultValue: "STARTTLS verwendet üblicherweise Port 587.")
        default:
            return nil
        }
    }

    // MARK: – Passwort (Keychain)

    /// Passwort aus dem Keychain lesen
    var password: String? {
        KeychainManager.shared.getPassword(forAccount: id.uuidString)
    }

    /// Passwort sicher im Keychain ablegen
    func savePassword(_ pwd: String) throws {
        try KeychainManager.shared.savePassword(pwd, forAccount: id.uuidString)
    }
}
