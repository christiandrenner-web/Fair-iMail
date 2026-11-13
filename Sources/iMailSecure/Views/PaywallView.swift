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

            ForEach(Self.freeFeatures, id: \.self) { item in
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

            // Lifetime-Hinweis, falls bereits Lifetime gekauft
            if subscription.tier == .lifetime {
                HStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                        .foregroundStyle(.yellow)
                    Text(String(localized: "paywall.lifetime.active",
                               defaultValue: "Du hast Lifetime-Zugang — einmalig gezahlt, dauerhaft Pro."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .background(Color.yellow.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private func planButton(_ product: Product) -> some View {
        let isLifetime = SubscriptionProduct.isLifetime(product.id)
        let isActiveLifetime = subscription.tier == .lifetime

        return Button {
            if isLifetime && isActiveLifetime { return }
            Task { await subscription.purchase(product) }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(product.displayName)
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                        if isLifetime {
                            Image(systemName: "crown.fill")
                                .font(.caption)
                                .foregroundStyle(.yellow)
                        }
                    }
                    if isLifetime && isActiveLifetime {
                        Text(String(localized: "paywall.lifetime.owned",
                                   defaultValue: "Bereits gekauft"))
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else if let trial = trialLabel(for: product) {
                        Text(trial)
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else if isLifetime {
                        Text(String(localized: "paywall.lifetime.onetime",
                                   defaultValue: "Einmalig zahlen, dauerhaft nutzen"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
                    // „pro Monat" ergibt beim Einmalkauf keinen Sinn.
                    if !isLifetime {
                        Text("pro \(SubscriptionProduct.periodLabel(for: product.id))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(14)
            .background(Color(uiColor: .secondarySystemBackground),
                        in: RoundedRectangle(cornerRadius: 12))
            .opacity(isLifetime && isActiveLifetime ? 0.6 : 1.0)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("paywall.plan.\(product.id)")
        .disabled(subscription.isPurchasing || (isLifetime && isActiveLifetime))
    }

    /// „7 Tage gratis" nur, wenn Apple wirklich ein Introductory Offer liefert.
    private func trialLabel(for product: Product) -> String? {
        guard let offer = product.subscription?.introductoryOffer else { return nil }
        let period = offer.period

        let components: DateComponents
        let unit: NSCalendar.Unit
        switch period.unit {
        case .day:   components = DateComponents(day: period.value);        unit = .day
        case .week:  components = DateComponents(weekOfMonth: period.value); unit = .weekOfMonth
        case .month: components = DateComponents(month: period.value);      unit = .month
        case .year:  components = DateComponents(year: period.value);       unit = .year
        @unknown default:
            return String(localized: "paywall.trialFallback",
                          defaultValue: "Testphase gratis")
        }

        // DateComponentsFormatter bildet die Mehrzahl in jeder Sprache richtig
        // („1 Tag", „7 Tage", „7 дней", „7 gün").
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.allowedUnits = unit
        formatter.maximumUnitCount = 1
        guard let amount = formatter.string(from: components) else {
            return String(localized: "paywall.trialFallback",
                          defaultValue: "Testphase gratis")
        }
        return String(
            format: String(localized: "paywall.trial",
                           defaultValue: "%@ gratis, danach automatisch"),
            amount
        )
    }

    /// Was in der Gratisversion bleibt. Bewusst als Eigenschaft, damit die
    /// Texte über `String(localized:)` übersetzt werden — ein Array aus
    /// String-Literalen würde SwiftUI unübersetzt anzeigen.
    private static let freeFeatures: [String] = [
        String(localized: "paywall.free.html",
               defaultValue: "Text- und HTML-Anzeige mit Blockierung externer Inhalte"),
        String(localized: "paywall.free.links",
               defaultValue: "Tracking-Parameter entfernen, Links nur nach Bestätigung"),
        String(localized: "paywall.free.tls",
               defaultValue: "TLS mit Zertifikat-Pinning, Passwörter im Keychain"),
        String(localized: "paywall.free.noTracking",
               defaultValue: "Kein Tracking, keine Telemetrie, keine Werbung")
    ]

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

    /// Ohne geladene Produkte wird der Abo-Hinweis gezeigt — er ist die
    /// konservative Annahme, weil das Standardangebot ein Abo ist.
    private var showsSubscriptionDisclosure: Bool {
        subscription.products.isEmpty
            || subscription.products.contains { $0.subscription != nil }
    }

    private var showsLifetimeDisclosure: Bool {
        subscription.tier == .lifetime
            || subscription.products.contains { SubscriptionProduct.isLifetime($0.id) }
    }

    private var legalSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            if showsSubscriptionDisclosure {
                Text("Das Abo verlängert sich automatisch, bis du es in den App-Store-Einstellungen kündigst. Die Testphase endet automatisch mit dem Abschluss des Abos, wenn du nicht vorher kündigst.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if showsLifetimeDisclosure {
                Text(String(localized: "paywall.legal.lifetime",
                           defaultValue: "Lifetime ist ein Einmalkauf: keine Verlängerung, keine wiederkehrenden Kosten."))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

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
