// Constants.swift
import Foundation

enum AppConstants {
    static let appName          = "iMail Secure"
    static let bundleID         = "io.imailsecure.app"
    static let appVersion       = "1.0.0"
    static let appBuild         = "1"
    // Website: https://christiandrenner-web.github.io/imailsecure-site/
    // TODO: Kontaktadresse festlegen — support@imailsecure.de erst nach
    // Domain-Registrierung nutzbar. Vor App-Store-Einreichung ersetzen.
    static let supportEmail     = "support@imailsecure.de"
    static let privacyPolicyURL = "https://christiandrenner-web.github.io/imailsecure-site/privacy.html"
    static let termsOfUseURL    = "https://christiandrenner-web.github.io/imailsecure-site/terms.html"
    static let sourceCodeURL    = "https://github.com/christiandrenner-web/Fair-iMail"

    enum Keychain {
        static let service = "io.imailsecure.keychain"
        static let accessGroup = "io.imailsecure.shared"
    }

    enum IMAP {
        static let defaultPort    = 993
        static let defaultPortAlt = 143
        static let fetchLimit     = 50
        static let idleTimeout    = 1740 // 29 Minuten
    }

    enum SMTP {
        static let defaultPort    = 587
        static let defaultPortSSL = 465
        static let timeout        = 30
    }

    enum CoreData {
        static let modelName = "iMailSecure"
    }

    enum UserDefaultsKeys {
        static let accounts             = "imailsecure.accounts"
        static let defaultRequestMDN    = "defaultRequestMDN"
        static let lastSyncDate         = "imailsecure.lastSync"
    }

    enum Notifications {
        static let newMailReceived = Notification.Name("io.imailsecure.newMail")
        static let mdnReceived     = Notification.Name("io.imailsecure.mdnReceived")
        static let syncCompleted   = Notification.Name("io.imailsecure.syncCompleted")
    }
}
