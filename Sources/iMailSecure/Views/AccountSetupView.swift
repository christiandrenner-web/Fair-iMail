// AccountSetupView.swift
// iOS 26 – Konto anlegen mit Passwort-Dialog und Keychain-Speicherung

import SwiftUI

struct AccountSetupView: View {
    @EnvironmentObject var accountStore: AccountStore
    @EnvironmentObject var mailStore: MailStore
    @EnvironmentObject var subscription: SubscriptionManager
    @Environment(\.dismiss) private var dismiss

    @State private var displayName  = ""
    @State private var email        = ""
    @State private var password     = ""
    @State private var imapHost     = ""
    @State private var imapPort     = "993"
    @State private var imapSecurity: ConnectionSecurity = .implicit
    @State private var smtpHost     = ""
    @State private var smtpPort     = "587"
    @State private var smtpSecurity: ConnectionSecurity = .startTLS
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var isSaving     = false
    @State private var showPassword = false
    @FocusState private var focusedField: Field?

    enum Field { case displayName, email, password, imapHost, smtpHost }

    // Bekannte Anbieter
    private let providers: [(String, String, String, String, String)] = [
        ("web.de",    "imap.web.de",              "993", "smtp.web.de",              "587"),
        ("GMX",       "imap.gmx.net",             "993", "mail.gmx.net",             "587"),
        ("Gmail",     "imap.gmail.com",            "993", "smtp.gmail.com",           "587"),
        ("iCloud",    "imap.mail.me.com",          "993", "smtp.mail.me.com",         "587"),
        ("Outlook",   "imap-mail.outlook.com",     "993", "smtp-mail.outlook.com",    "587"),
        ("T-Online",  "secureimap.t-online.de",    "993", "securesmtp.t-online.de",   "465"),
    ]

    var body: some View {
        NavigationStack {
            Form {
                // Anbieter-Schnellauswahl
                Section("Anbieter") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(providers, id: \.0) { p in
                                Button(p.0) { applyProvider(p) }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    .tint(imapHost == p.1 ? .accentColor : .secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                // Benutzerdaten
                Section("Benutzerdaten") {
                    TextField("Anzeigename", text: $displayName)
                        .focused($focusedField, equals: .displayName)
                        .accessibilityIdentifier("account.displayName")
                        .submitLabel(.next)
                        .onSubmit { focusedField = .email }

                    TextField("E-Mail-Adresse", text: $email)
                        .focused($focusedField, equals: .email)
                        .accessibilityIdentifier("account.email")
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .password }
                }

                // Passwort – eigener Bereich mit Keychain-Hinweis
                Section {
                    HStack {
                        Group {
                            if showPassword {
                                TextField("Passwort", text: $password)
                            } else {
                                SecureField("Passwort", text: $password)
                            }
                        }
                        .focused($focusedField, equals: .password)
                        .accessibilityIdentifier("account.password")
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .imapHost }

                        Button {
                            showPassword.toggle()
                        } label: {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Passwort")
                } footer: {
                    Label("Wird verschlüsselt im iOS-Schlüsselbund gespeichert.", systemImage: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // IMAP
                Section("IMAP (Empfang)") {
                    TextField("Server (z.B. imap.web.de)", text: $imapHost)
                        .focused($focusedField, equals: .imapHost)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .smtpHost }
                    HStack {
                        Text("Port")
                        Spacer()
                        TextField("993", text: $imapPort)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                            .frame(width: 80)
                    }
                    Picker("Sicherheit", selection: $imapSecurity) {
                        ForEach(ConnectionSecurity.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                }

                // SMTP
                Section("SMTP (Versand)") {
                    TextField("Server (z.B. smtp.web.de)", text: $smtpHost)
                        .focused($focusedField, equals: .smtpHost)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    HStack {
                        Text("Port")
                        Spacer()
                        TextField("587", text: $smtpPort)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                            .frame(width: 80)
                    }
                    Picker("Sicherheit", selection: $smtpSecurity) {
                        ForEach(ConnectionSecurity.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                }

                // Feedback
                if let error = errorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
                if let success = successMessage {
                    Section {
                        Label(success, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
            }
            .navigationTitle("Konto hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        saveAccount()
                    } label: {
                        if isSaving {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("Speichern")
                        }
                    }
                    .disabled(isSaving || !isValid)
                    .accessibilityIdentifier("account.save")
                }
            }
            .onAppear {
                // Cursor direkt ins erste Feld
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    focusedField = .displayName
                }
            }
        }
    }

    private var isValid: Bool {
        !displayName.isEmpty && email.contains("@") && !password.isEmpty &&
        !imapHost.isEmpty && !smtpHost.isEmpty
    }

    private func applyProvider(_ p: (String, String, String, String, String)) {
        imapHost = p.1; imapPort = p.2; smtpHost = p.3; smtpPort = p.4
    }

    private func saveAccount() {
        // Zweite Sicherung: Die Einstellungen zeigen bei Erreichen des
        // Limits direkt die Paywall. Falls das Sheet trotzdem offen ist,
        // wird hier abgebrochen — kein Konto ohne Berechtigung.
        guard subscription.canAddAccount(currentCount: accountStore.accounts.count) else {
            errorMessage = String(
                localized: "account.error.limit",
                defaultValue: "Die kostenlose Version unterstützt ein Konto. iMail Secure Pro hebt die Beschränkung auf."
            )
            return
        }

        isSaving      = true
        errorMessage  = nil
        successMessage = nil

        let account = EmailAccount(
            displayName: displayName,
            email: email,
            imapHost: imapHost,
            imapPort: Int(imapPort) ?? imapSecurity.defaultIMAPPort,
            imapSecurity: imapSecurity,
            smtpHost: smtpHost,
            smtpPort: Int(smtpPort) ?? smtpSecurity.defaultSMTPPort,
            smtpSecurity: smtpSecurity,
            username: email
        )

        do {
            // Passwort sicher im Keychain ablegen
            try account.savePassword(password)
            accountStore.add(account)
            successMessage = String(localized: "account.success.saved",
                                   defaultValue: "Konto gespeichert ✓ Passwort im Schlüsselbund.")
            // Neues Konto sofort abgleichen, damit Ordner und Posteingang
            // ohne manuelles Aktualisieren erscheinen.
            Task {
                mailStore.loadAccounts(from: accountStore)
                await mailStore.syncAll()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { dismiss() }
        } catch {
            errorMessage = String(
                format: String(localized: "account.error.keychain",
                               defaultValue: "Keychain-Fehler: %@"),
                error.localizedDescription
            )
        }
        isSaving = false
    }
}
