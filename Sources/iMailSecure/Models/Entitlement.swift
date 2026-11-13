// Entitlement.swift
//
// Free/Pro-Trennung als eine einzige Wahrheit.
//
// Alle Gates fragen diese Tabelle, nicht einzelne Booleans. Damit gibt es
// genau eine Stelle, an der entschieden wird, was Pro ist — und Tests können
// die Entscheidung ohne StoreKit prüfen.
//
// Leitsatz: Datenschutzfunktionen sind **nie** Pro. Pro ist Bequemlichkeit
// (mehrere Konten, mehr Ordner, gemeinsamer Posteingang).

import Foundation

// MARK: – Stufe

enum Tier: String, Codable, CaseIterable, Comparable {
    case free
    case pro
    case lifetime

    private var rank: Int {
        switch self {
        case .free:     return 0
        case .pro:      return 1
        case .lifetime: return 2
        }
    }

    static func < (lhs: Tier, rhs: Tier) -> Bool { lhs.rank < rhs.rank }

    /// Für UI: Lifetime optisch wie Pro, aber unterscheidbar.
    var isEffectivelyPro: Bool { self >= .pro }
}

// MARK: – Produkte

enum SubscriptionProduct {
    static let monthly   = "io.imailsecure.pro.monthly"
    static let yearly    = "io.imailsecure.pro.yearly"
    static let lifetime  = "io.imailsecure.pro.lifetime"

    static let subscriptionIDs: Set<String> = [monthly, yearly]
    static let allIDs: Set<String> = [monthly, yearly, lifetime]

    static func isKnown(_ productID: String) -> Bool {
        allIDs.contains(productID)
    }

    static func isSubscription(_ productID: String) -> Bool {
        subscriptionIDs.contains(productID)
    }

    static func isLifetime(_ productID: String) -> Bool {
        productID == lifetime
    }

    /// Anzeigename, unabhängig davon, ob StoreKit gerade Produkte liefert.
    static func periodLabel(for productID: String) -> String {
        switch productID {
        case monthly:
            return String(localized: "period.month", defaultValue: "Monat")
        case yearly:
            return String(localized: "period.year", defaultValue: "Jahr")
        case lifetime:
            return String(localized: "period.lifetime", defaultValue: "Einmalig")
        default:
            return ""
        }
    }
}

// MARK: – Features

/// Ein Feature, das eine bestimmte Stufe verlangt.
///
/// Neue Pro-Funktionen werden **hier** ergänzt, nicht als `if isPro` in Views.
/// Solange ein Feature noch nicht gebaut ist, gehört es nicht in diese Liste —
/// die Paywall darf nichts bewerben, was es nicht gibt.
enum Feature: String, CaseIterable, Identifiable {
    case multipleAccounts
    case folderManagement
    case unifiedInbox

    var id: String { rawValue }

    var requiredTier: Tier {
        switch self {
        case .multipleAccounts, .folderManagement, .unifiedInbox:
            return .pro
        }
    }

    var title: String {
        switch self {
        case .multipleAccounts:
            return String(localized: "feature.accounts.title",
                          defaultValue: "Mehrere E-Mail-Konten")
        case .folderManagement:
            return String(localized: "feature.folders.title",
                          defaultValue: "Alle Ordner und Mailboxen")
        case .unifiedInbox:
            return String(localized: "feature.unified.title",
                          defaultValue: "Gemeinsamer Posteingang")
        }
    }

    var detail: String {
        switch self {
        case .multipleAccounts:
            return String(localized: "feature.accounts.detail",
                          defaultValue: "Privat- und Arbeitsadresse parallel, ohne ständiges Ab- und Anmelden.")
        case .folderManagement:
            return String(localized: "feature.folders.detail",
                          defaultValue: "Jeden Server-Ordner öffnen und eigene Ordner anlegen — nicht nur den Posteingang.")
        case .unifiedInbox:
            return String(localized: "feature.unified.detail",
                          defaultValue: "Alle Konten in einer Liste, ohne zwischen Postfächern zu wechseln.")
        }
    }

    var icon: String {
        switch self {
        case .multipleAccounts: return "person.2.fill"
        case .folderManagement: return "folder.badge.gearshape"
        case .unifiedInbox:     return "tray.2.fill"
        }
    }

    func isAvailable(in tier: Tier) -> Bool {
        requiredTier <= tier
    }
}

// MARK: – Ableitung

enum Entitlement {

    /// Anzahl der Konten in der kostenlosen Version. `nil` = unbegrenzt.
    static let freeAccountCount = 1

    static func accountLimit(for tier: Tier) -> Int? {
        tier == .pro ? nil : freeAccountCount
    }

    /// Welche Stufe ergibt sich aus den aktiven, nicht widerrufenen
    /// StoreKit-Produkten?
    ///
    /// Unbekannte Produkt-IDs werden ignoriert — ein fremdes Abo darf keine
    /// Pro-Freischaltung bewirken.
    /// Lifetime (Non-Consumable) hat Vorrang vor Abo.
    static func tier(forActiveProductIDs productIDs: Set<String>) -> Tier {
        if productIDs.contains(where: SubscriptionProduct.isLifetime) { return .lifetime }
        if productIDs.contains(where: SubscriptionProduct.isSubscription) { return .pro }
        return .free
    }
}
