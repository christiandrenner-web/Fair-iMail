// SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var accountStore: AccountStore
    @State private var showAddAccount = false
    @AppStorage("loadRemoteImages") private var loadRemoteImages = false
    @AppStorage("confirmExternalLinks") private var confirmExternalLinks = true
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
                    Toggle("Externe Bilder laden", isOn: $loadRemoteImages)
                    Toggle("Links vor dem Öffnen bestätigen", isOn: $confirmExternalLinks)
                } header: {
                    Text("Datenschutz")
                } footer: {
                    Text("iMail secure überträgt keine Daten an Dritte und enthält kein Tracking.")
                }

                // Nachrichtenoptionen
                Section("Nachrichtenoptionen") {
                    Toggle("Lesebestätigung standardmäßig anfordern", isOn: $defaultRequestMDN)
                }

                // Info
                Section("Über iMail secure") {
                    LabeledContent("Version", value: "1.0.0")
                    LabeledContent("Lizenz", value: "GPL-3.0")
                    Link("Quellcode auf GitHub",
                         destination: URL(string: "https://github.com/yourusername/Fair-iMail")!)
                    Link("Datenschutzerklärung",
                         destination: URL(string: "https://fairimail.io/privacy")!)
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
