// PaywallView.swift
//
// Die Paywall erscheint nur am Ort des Bedarfs (z. B. „zweites Konto") und
// bewirbt ausschließlich Funktionen, die es wirklich gibt.
//
// Bewusst enthalten: was kostenlos bleibt. Eine Privacy-App, die ihre
// Datenschutzfunktionen hinter ein Abo legt, wäre unglaubwürdig.

import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject var subscription: SubscriptionManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    featureSection
                    freeSection
                    plansSection
                    restoreSection
                    legalSection
                }
                .padding()
            }
            .navigationTitle("iMail Secure Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Schließen") { dismiss() }
                }
            }
            .task { await subscription.loadProducts() }
            .onChange(of: subscription.isPro) { _, isPro in
                if isPro { dismiss() }
            }
        }
    }

    // MARK: – Kopf

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 40))
                .foregroundStyle(.green)

            Text("Mehr Komfort — gleicher Datenschutz")
                .font(.title2.bold())

            Text("Pro schaltet Bequemlichkeit frei. Alles, was deine Daten schützt, bleibt in der kostenlosen Version.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: – Pro-Funktionen

    private var featureSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Feature.allCases) { feature in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: feature.icon)
                        .font(.title3)
                        .foregroundStyle(.blue)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(feature.title).font(.subheadline.bold())
                        Text(feature.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: – Bleibt kostenlos

    private var freeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Bleibt kostenlos")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            ForEach(["Text- und HTML-Anzeige mit Blockierung externer Inhalte",
                     "Tracking-Parameter entfernen, Links nur nach Bestätigung",
                     "TLS mit Zertifikat-Pinning, Passwörter im Keychain",
                     "Kein Tracking, keine Telemetrie, keine Werbung"], id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                    Text(item).font(.caption)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: – Abos

    @ViewBuilder
    private var plansSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if subscription.isLoadingProducts && subscription.products.isEmpty {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Preise werden geladen …")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if subscription.products.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Die Abos sind derzeit nicht verfügbar.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Erneut laden") {
                        Task { await subscription.loadProducts() }
                    }
                    .font(.caption.bold())
                }
            } else {
                ForEach(subscription.products, id: \.id) { product in
                    planButton(product)
                }
            }

            if let message = subscription.message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func planButton(_ product: Product) -> some View {
        Button {
            Task { await subscription.purchase(product) }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(product.displayName)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    if let trial = trialLabel(for: product) {
                        Text(trial)
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else {
                        Text("Jederzeit kündbar")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(product.displayPrice)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("pro \(SubscriptionProduct.periodLabel(for: product.id))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .background(Color(uiColor: .secondarySystemBackground),
                        in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(subscription.isPurchasing)
    }

    /// „7 Tage gratis" nur, wenn Apple wirklich ein Introductory Offer liefert.
    private func trialLabel(for product: Product) -> String? {
        guard let offer = product.subscription?.introductoryOffer else { return nil }
        let period = offer.period
        let unit: String
        switch period.unit {
        case .day:   unit = period.value == 1 ? "Tag"   : "Tage"
        case .week:  unit = period.value == 1 ? "Woche" : "Wochen"
        case .month: unit = period.value == 1 ? "Monat" : "Monate"
        case .year:  unit = period.value == 1 ? "Jahr"  : "Jahre"
        @unknown default: return "Testphase gratis"
        }
        return "\(period.value) \(unit) gratis, danach automatisch"
    }

    // MARK: – Wiederherstellen

    private var restoreSection: some View {
        Button {
            Task { await subscription.restore() }
        } label: {
            Text("Käufe wiederherstellen")
                .font(.caption.bold())
        }
        .disabled(subscription.isPurchasing)
    }

    // MARK: – Rechtliches

    private var legalSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Das Abo verlängert sich automatisch, bis du es in den App-Store-Einstellungen kündigst. Die Testphase endet automatisch mit dem Abschluss des Abos, wenn du nicht vorher kündigst.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                if let privacy = URL(string: AppConstants.privacyPolicyURL) {
                    Link("Datenschutz", destination: privacy)
                }
                if let terms = URL(string: AppConstants.termsOfUseURL) {
                    Link("Nutzungsbedingungen", destination: terms)
                }
            }
            .font(.caption2)
        }
    }
}
