// SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var accountStore: AccountStore
    @State private var showAddAccount = false
    @AppStorage("defaultRequestMDN") private var defaultRequestMDN = false

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
                        showAddAccount = true
                    } label: {
                        Label("Konto hinzufügen", systemImage: "plus.circle.fill")
                    }
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
                    Text("iMail Secure überträgt keine Daten an Dritte und enthält kein Tracking. Das Laden externer Bilder ist bewusst nicht abschaltbar – es findet nicht statt.")
                }

                // Nachrichtenoptionen
                Section("Nachrichtenoptionen") {
                    Toggle("Lesebestätigung standardmäßig anfordern", isOn: $defaultRequestMDN)
                }

                // Info
                Section("Über iMail Secure") {
                    LabeledContent("Version", value: AppConstants.appVersion)
                    LabeledContent("Lizenz", value: "GPL-3.0 mit App-Store-Ausnahme")
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
