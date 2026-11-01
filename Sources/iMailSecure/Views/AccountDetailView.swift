// AccountDetailView.swift
import SwiftUI

struct AccountDetailView: View {
    @EnvironmentObject var accountStore: AccountStore
    @Environment(\.dismiss) private var dismiss
    @State var account: EmailAccount
    @State private var newPassword  = ""
    @State private var saveMessage: String?
    @State private var saveError:   String?
    @State private var pinNotice:   String?
    @State private var pinToReset:  PinResetTarget?

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

            // Zertifikat-Pinning (TOFU)
            Section {
                pinRow(label: "IMAP", host: account.imapHost, port: account.imapPort)
                pinRow(label: "SMTP", host: account.smtpHost, port: account.smtpPort)
            } header: {
                Text("Zertifikate")
            } footer: {
                Text("Beim ersten Verbinden wird der SHA-256-Fingerabdruck des Server-Zertifikats gespeichert. Ändert er sich, bricht die App die Verbindung ab. Zurücksetzen nur, wenn du das neue Zertifikat geprüft hast.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let notice = pinNotice {
                Section { Label(notice, systemImage: "lock.open").foregroundStyle(.blue) }
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
        .confirmationDialog(
            "Zertifikat zurücksetzen?",
            isPresented: Binding(
                get: { pinToReset != nil },
                set: { if !$0 { pinToReset = nil } }
            ),
            presenting: pinToReset
        ) { target in
            Button("Pin für \(target.label) löschen", role: .destructive) {
                CertificatePinner.shared.resetPin(host: target.host, port: target.port)
                pinNotice = "Pin für \(target.label) gelöscht. Beim nächsten Verbinden wird der aktuelle Fingerabdruck ohne Vergleich übernommen."
                pinToReset = nil
            }
            Button("Abbrechen", role: .cancel) { pinToReset = nil }
        } message: { target in
            Text("Der gespeicherte Fingerabdruck für \(target.host):\(target.port) wird gelöscht. Danach wäre ein Man-in-the-Middle nicht mehr erkennbar — nur tun, wenn du das neue Zertifikat geprüft hast.")
        }
    }

    // MARK: – Zertifikat-Pinning

    @ViewBuilder
    private func pinRow(label: String, host: String, port: Int) -> some View {
        let fingerprint = CertificatePinner.shared.storedFingerprint(host: host, port: port)
        VStack(alignment: .leading, spacing: 4) {
            Text("\(label): \(host):\(port)")
                .font(.subheadline)
            if let fingerprint {
                Text(fingerprint.prefix(29) + "…")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                Button("Zertifikat zurücksetzen", role: .destructive) {
                    pinToReset = PinResetTarget(label: label, host: host, port: port)
                }
                .font(.caption)
            } else {
                Text("Noch kein Pin — wird beim ersten Verbinden gesetzt.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

// MARK: – Hilfstyp

private struct PinResetTarget: Identifiable {
    let id = UUID()
    let label: String
    let host: String
    let port: Int
}
