// SubscriptionManager.swift
//
// StoreKit 2 – kein eigener Server, keine Drittanbieter-SDKs.
//
// Warum kein Backend:
//   • Apple signiert jede Transaktion; die Prüfung passiert auf dem Gerät.
//   • Es gibt damit keine Nutzerdaten bei uns — das Datenschutzlabel bleibt
//     „Keine Daten erfasst".
//   • Ein Server wäre zusätzliche Infrastruktur, zusätzliche Ausfälle und ein
//     weiterer Ort, an dem Daten liegen.
//
// Die 7-Tage-Testphase ist **kein** Code hier: Sie ist ein Introductory Offer
// in App Store Connect. Die App sieht nur „aktiv" oder „nicht aktiv".
//
// Fallback-Verhalten: Ist StoreKit nicht erreichbar (Flugmodus, frisch
// installiert), bleibt der zuletzt bekannte Zustand aus dem Keychain gültig.
// Ohne gespeicherten Zustand gilt .free — fail-closed, aber ohne Datenverlust:
// Zusatzkonten werden nie gelöscht, nur schreibgeschützt.

import Foundation
import StoreKit
import Combine

@MainActor
final class SubscriptionManager: ObservableObject {

    // MARK: – Zustand

    @Published private(set) var tier: Tier = .free
    @Published private(set) var products: [Product] = []
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var isPurchasing = false
    @Published var message: String?

    private var updatesTask: Task<Void, Never>?
    private let keychain = KeychainManager.shared
    private static let cachedTierKey = "subscription.tier"

    // MARK: – Lebenszyklus

    init(startImmediately: Bool = true) {
        if let cached = keychain.getPassword(forAccount: Self.cachedTierKey),
           let tier = Tier(rawValue: cached) {
            self.tier = tier
        }
        if startImmediately { start() }
    }

    /// Nur für Tests und SwiftUI-Previews: setzt die Stufe ohne StoreKit.
    init(previewTier tier: Tier) {
        self.tier = tier
    }

    deinit {
        updatesTask?.cancel()
    }

    /// Startet Transaktions-Listener und Erstprüfung. Idempotent.
    func start() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = update {
                    await transaction.finish()
                }
                await self.refreshEntitlements()
            }
        }
        // Nur die Berechtigung prüfen. Produkte werden erst geladen, wenn die
        // Paywall geöffnet wird — kein unnötiger Netzwerkaufruf beim Start.
        Task { await refreshEntitlements() }
    }

    // MARK: – Abfragen

    var isPro: Bool { tier == .pro }

    var accountLimit: Int? { Entitlement.accountLimit(for: tier) }

    func canUse(_ feature: Feature) -> Bool {
        feature.isAvailable(in: tier)
    }

    func canAddAccount(currentCount: Int) -> Bool {
        guard let limit = accountLimit else { return true }
        return currentCount < limit
    }

    // MARK: – Produkte

    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let loaded = try await Product.products(for: Array(SubscriptionProduct.allIDs))
            // Günstigstes zuerst (Monatsabo als Einstieg).
            products = loaded.sorted { $0.price < $1.price }
        } catch {
            products = []
            message = "Preise konnten nicht geladen werden."
        }
    }

    // MARK: – Kaufen / Wiederherstellen

    func purchase(_ product: Product) async {
        guard !isPurchasing else { return }
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                }
                await refreshEntitlements()
            case .pending, .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            message = "Kauf fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            message = isPro ? "Kauf wiederhergestellt." : "Kein aktives Abo gefunden."
        } catch {
            message = "Wiederherstellen fehlgeschlagen."
        }
    }

    // MARK: – Berechtigungen prüfen

    /// Liest die von Apple signierten, aktuell gültigen Transaktionen.
    /// Abgelaufene und widerrufene Käufe erscheinen hier nicht.
    func refreshEntitlements() async {
        var active: Set<String> = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.revocationDate == nil else { continue }
            active.insert(transaction.productID)
        }
        apply(productIDs: active)
    }

    /// Setzt die Stufe und merkt sie für den Offline-Start.
    func apply(productIDs: Set<String>) {
        let newTier = Entitlement.tier(forActiveProductIDs: productIDs)
        guard newTier != tier else { return }
        tier = newTier
        try? keychain.savePassword(newTier.rawValue, forAccount: Self.cachedTierKey)
    }
}
