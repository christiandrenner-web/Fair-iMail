// AccountDetailView.swift
import SwiftUI

struct AccountDetailView: View {
    @EnvironmentObject var accountStore: AccountStore
    @Environment(\.dismiss) private var dismiss
    @State var account: EmailAccount
    @State private var newPassword  = ""
    @State private var saveMessage: String?
    @State private var saveError:   String?

    var body: some View {
        Form {
            Section("Benutzerdaten") {
                TextField("Anzeigename", text: $account.displayName)
                LabeledContent("E-Mail", value: account.email)
                SecureField("Neues Passwort (leer = unverändert)", text: $newPassword)
            }

            // IMAP
            Section {
                TextField("Server", text: $account.imapHost)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                Picker("Sicherheit", selection: $account.imapSecurity) {
                    ForEach(ConnectionSecurity.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .onChange(of: account.imapSecurity) { _, new in
                    account.imapPort = new.defaultIMAPPort
                }

                Stepper("Port: \(account.imapPort)", value: $account.imapPort, in: 1...65535)

                if let warning = account.imapPortWarning {
                    Label(warning, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            } header: {
                Text("IMAP (Empfang)")
            } footer: {
                Text("Klartext-Verbindungen werden niemals erlaubt.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // SMTP
            Section {
                TextField("Server", text: $account.smtpHost)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                Picker("Sicherheit", selection: $account.smtpSecurity) {
                    ForEach(ConnectionSecurity.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .onChange(of: account.smtpSecurity) { _, new in
                    account.smtpPort = new.defaultSMTPPort
                }

                Stepper("Port: \(account.smtpPort)", value: $account.smtpPort, in: 1...65535)

                if let warning = account.smtpPortWarning {
                    Label(warning, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            } header: {
                Text("SMTP (Versand)")
            } footer: {
                Text("Klartext-Verbindungen werden niemals erlaubt.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Feedback
            if let msg = saveMessage {
                Section { Label(msg, systemImage: "checkmark.circle.fill").foregroundStyle(.green) }
            }
            if let err = saveError {
                Section { Label(err, systemImage: "xmark.circle.fill").foregroundStyle(.red) }
            }

            // Konto löschen
            Section {
                Button(role: .destructive) {
                    accountStore.delete(account)
                    dismiss()
                } label: {
                    Label("Konto entfernen", systemImage: "trash")
                }
            }
        }
        .navigationTitle(account.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Speichern") { save() }
            }
        }
    }

    private func save() {
        saveMessage = nil
        saveError   = nil

        // Passwort nur ändern wenn ein neues eingegeben wurde
        if !newPassword.isEmpty {
            do {
                try account.savePassword(newPassword)
            } catch {
                saveError = "Keychain-Fehler: \(error.localizedDescription)"
                return
            }
        }
        accountStore.update(account)
        saveMessage = "Gespeichert ✓"
    }
}
