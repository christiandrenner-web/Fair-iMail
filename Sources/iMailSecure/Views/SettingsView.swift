// SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var accountStore: AccountStore
    @EnvironmentObject var subscription: SubscriptionManager
    @State private var showAddAccount = false
    @State private var showPaywall = false
    @State private var showRevokeAllConfirmation = false
    @AppStorage(AppConstants.UserDefaultsKeys.defaultRequestMDN) private var defaultRequestMDN = false
    @ObservedObject private var remotePolicy = RemoteContentPolicy.shared

    private var canAddAccount: Bool {
        subscription.canAddAccount(currentCount: accountStore.accounts.count)
    }

    var body: some View {
        NavigationStack {
            Form {
                // Konten
                Section("E-Mail-Konten") {
                    ForEach(accountStore.accounts) { account in
                        NavigationLink {
                            AccountDetailView(account: account)
                        } label: {
                            accountRow(account)
                        }
                    }
                    Button {
                        if canAddAccount {
                            showAddAccount = true
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        Label(
                            canAddAccount
                                ? String(localized: "account.add", defaultValue: "Konto hinzufügen")
                                : String(localized: "account.add.pro", defaultValue: "Weiteres Konto (Pro)"),
                            systemImage: canAddAccount ? "plus.circle.fill" : "lock.circle.fill"
                        )
                    }
                }

                // Abo
                Section {
                    if subscription.isPro {
                        Label("Pro aktiv", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button {
                            showPaywall = true
                        } label: {
                            Label("iMail Secure Pro", systemImage: "lock.shield.fill")
                        }
                    }
                    Button("Käufe wiederherstellen") {
                        Task { await subscription.restore() }
                    }
                    .font(.callout)
                } header: {
                    Text("Abo")
                } footer: {
                    Text(subscription.isPro
                         ? String(localized: "settings.pro.activeFooter",
                                  defaultValue: "Alle Pro-Funktionen sind freigeschaltet. Kündigung jederzeit in den App-Store-Einstellungen.")
                         : String(localized: "settings.free.footer",
                                  defaultValue: "Die kostenlose Version unterstützt ein Konto. Alle Datenschutzfunktionen sind darin enthalten."))
                }

                // Datenschutz
                Section {
                    Label("Mails werden als Text angezeigt", systemImage: "doc.plaintext")
                    Label("HTML nur auf Knopfdruck", systemImage: "chevron.left.forwardslash.chevron.right")
                    Label("Externe Inhalte blockiert", systemImage: "shield.lefthalf.filled")
                    Label("Links nur nach Bestätigung", systemImage: "hand.raised.fill")
                } header: {
                    Text("Datenschutz")
                } footer: {
                    Text("iMail Secure überträgt keine Daten an Dritte und enthält kein Tracking. Externe Bilder und Stylesheets werden blockiert, bis du sie für eine Mail oder einen Absender ausdrücklich freigibst.")
                }

                // D2 Stufe 3 – Freigaben widerrufen
                Section {
                    if remotePolicy.sortedTrustedSenders.isEmpty {
                        Text("Keine Absender freigegeben.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(remotePolicy.sortedTrustedSenders, id: \.self) { sender in
                            HStack {
                                Image(systemName: "photo")
                                    .foregroundStyle(.orange)
                                Text(sender)
                                    .font(.subheadline)
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                remotePolicy.revoke(sender: remotePolicy.sortedTrustedSenders[index])
                            }
                        }

                        Button(role: .destructive) {
                            showRevokeAllConfirmation = true
                        } label: {
                            Label("Alle Freigaben widerrufen", systemImage: "shield.slash")
                        }
                    }
                } header: {
                    Text("Externe Inhalte")
                } footer: {
                    Text("Absender, für die Bilder und Stylesheets dauerhaft geladen werden. Wische einen Eintrag nach links, um die Freigabe zu widerrufen.")
                }

                // Nachrichtenoptionen
                Section("Nachrichtenoptionen") {
                    Toggle("Lesebestätigung standardmäßig anfordern", isOn: $defaultRequestMDN)
                }

                // Info
                Section("Über iMail Secure") {
                    LabeledContent("Version", value: AppConstants.appVersion)
                    LabeledContent("Lizenz", value: "PolyForm Noncommercial 1.0.0")
                    Text("Quellcode einsehbar, keine kommerzielle Nutzung durch Dritte.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let source = URL(string: AppConstants.sourceCodeURL) {
                        Link("Quellcode", destination: source)
                    }
                    if let privacy = URL(string: AppConstants.privacyPolicyURL) {
                        Link("Datenschutzerklärung", destination: privacy)
                    }
                }
            }
            .navigationTitle("Einstellungen")
            .sheet(isPresented: $showAddAccount) {
                AccountSetupView()
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .confirmationDialog(
                "Alle Freigaben widerrufen?",
                isPresented: $showRevokeAllConfirmation,
                titleVisibility: .visible
            ) {
                Button("Alle widerrufen", role: .destructive) {
                    remotePolicy.revokeAll()
                }
                Button("Abbrechen", role: .cancel) { }
            } message: {
                Text("Externe Bilder und Stylesheets werden danach wieder für alle Absender blockiert.")
            }
        }
    }

    private func accountRow(_ account: EmailAccount) -> some View {
        HStack {
            Image(systemName: "envelope.circle.fill")
                .foregroundStyle(.blue)
                .font(.title2)
            VStack(alignment: .leading) {
                Text(account.displayName).font(.subheadline.bold())
                Text(account.email).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
