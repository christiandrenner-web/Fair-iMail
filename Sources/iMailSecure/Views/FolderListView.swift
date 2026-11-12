// FolderListView.swift
//
// Die Ordnerauswahl ist der Ort, an dem Pro sichtbar wird: Systemordner
// bleiben frei, eigene Ordner und der gemeinsame Posteingang brauchen Pro.
// Gesperrte Zeilen öffnen die Paywall statt tot zu wirken.

import SwiftUI

struct FolderListView: View {
    @EnvironmentObject var mailStore: MailStore
    @EnvironmentObject var accountStore: AccountStore
    @EnvironmentObject var subscription: SubscriptionManager
    @Environment(\.dismiss) private var dismiss

    @State private var showPaywall = false
    @State private var showCreateFolder = false
    @State private var folderToRename: FolderTarget?
    @State private var folderToDelete: FolderTarget?
    @State private var actionError: String?

    private var activeAccounts: [EmailAccount] {
        accountStore.accounts.filter(\.isActive)
    }

    private var preselectedAccountID: UUID? {
        if case .folder(let id, _) = mailStore.selection { return id }
        return activeAccounts.first?.id
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    unifiedInboxRow
                } footer: {
                    if !subscription.canUse(.unifiedInbox) {
                        Text("Der gemeinsame Posteingang bündelt alle Konten und ist Teil von Pro.")
                    }
                }

                ForEach(activeAccounts) { account in
                    Section {
                        let folders = mailStore.folders(for: account.id)
                        if folders.isEmpty {
                            Text("Ordner werden beim nächsten Abgleich geladen.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(folders) { folder in
                                folderRow(folder, account: account, all: folders)
                            }
                        }
                    } header: {
                        Text(account.email)
                    }
                }

                Section {
                    Button {
                        if subscription.canUse(.folderManagement) {
                            showCreateFolder = true
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        Label(
                            subscription.canUse(.folderManagement)
                                ? String(localized: "folder.create", defaultValue: "Ordner anlegen")
                                : String(localized: "folder.create.pro", defaultValue: "Ordner anlegen (Pro)"),
                            systemImage: subscription.canUse(.folderManagement)
                                ? "folder.badge.plus"
                                : "lock.circle.fill"
                        )
                    }
                    .disabled(activeAccounts.isEmpty)
                }
            }
            .navigationTitle("Ordner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .task { await mailStore.refreshFolders() }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .sheet(isPresented: $showCreateFolder) {
                CreateFolderView(
                    accounts: activeAccounts,
                    preselectedAccountID: preselectedAccountID
                )
            }
            .sheet(item: $folderToRename) { target in
                RenameFolderView(account: target.account, folder: target.folder)
            }
            .confirmationDialog(
                "Ordner löschen?",
                isPresented: Binding(
                    get: { folderToDelete != nil },
                    set: { if !$0 { folderToDelete = nil } }
                ),
                titleVisibility: .visible,
                presenting: folderToDelete
            ) { target in
                Button("„\(target.folder.displayName)“ löschen", role: .destructive) {
                    Task { await delete(target) }
                }
                Button("Abbrechen", role: .cancel) {}
            } message: { _ in
                Text("Der Ordner und alle enthaltenen Nachrichten werden auf dem Server gelöscht. Das lässt sich nicht rückgängig machen.")
            }
            .alert(
                "Aktion fehlgeschlagen",
                isPresented: Binding(
                    get: { actionError != nil },
                    set: { if !$0 { actionError = nil } }
                ),
                presenting: actionError
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { message in
                Text(message)
            }
        }
    }

    // MARK: – Zeilen

    private var unifiedInboxRow: some View {
        Button {
            guard subscription.canUse(.unifiedInbox) else {
                showPaywall = true
                return
            }
            mailStore.select(.unifiedInbox)
            dismiss()
        } label: {
            HStack {
                Label("Gemeinsamer Posteingang", systemImage: "tray.2.fill")
                Spacer()
                if !subscription.canUse(.unifiedInbox) {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.secondary)
                } else if mailStore.selection == .unifiedInbox {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
        }
        .foregroundStyle(
            subscription.canUse(.unifiedInbox) ? .primary : .secondary
        )
    }

    /// GMX und andere Server führen alte und neue Systemordner parallel
    /// („Trash" und „Gelöscht"). Ohne Zusatz stünden zwei Zeilen „Papierkorb"
    /// untereinander; der Server-Name macht sichtbar, welche gemeint ist.
    private func label(for folder: MailFolder, all: [MailFolder]) -> String {
        guard folder.role.isSystem else { return folder.displayName }
        let sameRole = all.filter { $0.role == folder.role }
        guard sameRole.count > 1 else { return folder.displayName }
        let leaf = folder.readableLeafName
        guard leaf.caseInsensitiveCompare(folder.displayName) != .orderedSame else {
            return folder.displayName
        }
        return "\(folder.displayName) (\(leaf))"
    }

    private func folderRow(
        _ folder: MailFolder,
        account: EmailAccount,
        all: [MailFolder]
    ) -> some View {
        let locked = folder.requiresPro && !subscription.canUse(.folderManagement)
        let selected = mailStore.selection == .folder(accountID: account.id, folder: folder)

        return Button {
            guard !locked else {
                showPaywall = true
                return
            }
            mailStore.select(.folder(accountID: account.id, folder: folder))
            dismiss()
        } label: {
            HStack {
                Label(label(for: folder, all: all), systemImage: icon(for: folder.role))
                Spacer()
                if locked {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.secondary)
                } else if selected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
        }
        .foregroundStyle(locked ? .secondary : .primary)
        .contextMenu {
            if folder.role == .custom {
                Button {
                    guard subscription.canUse(.folderManagement) else {
                        showPaywall = true
                        return
                    }
                    folderToRename = FolderTarget(account: account, folder: folder)
                } label: {
                    Label("Umbenennen", systemImage: "pencil")
                }

                Button(role: .destructive) {
                    guard subscription.canUse(.folderManagement) else {
                        showPaywall = true
                        return
                    }
                    folderToDelete = FolderTarget(account: account, folder: folder)
                } label: {
                    Label("Löschen", systemImage: "trash")
                }
            }
        }
    }

    private func delete(_ target: FolderTarget) async {
        do {
            try await mailStore.deleteFolder(
                named: target.folder.name,
                for: target.account.id
            )
        } catch {
            actionError = error.localizedDescription
        }
    }

    private func icon(for role: MailFolderRole) -> String {
        switch role {
        case .inbox:   return "tray.fill"
        case .flagged: return "flag.fill"
        case .important: return "exclamationmark.circle.fill"
        case .drafts:  return "doc.text.fill"
        case .sent:    return "paperplane.fill"
        case .archive: return "archivebox.fill"
        case .all:     return "tray.full.fill"
        case .junk:    return "exclamationmark.bubble.fill"
        case .trash:   return "trash.fill"
        case .custom:  return "folder.fill"
        }
    }
}

// MARK: – Ordner anlegen

struct CreateFolderView: View {
    let accounts: [EmailAccount]

    @EnvironmentObject var mailStore: MailStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedAccountID: UUID
    @State private var name = ""
    @State private var errorMessage: String?
    @State private var isSaving = false

    init(accounts: [EmailAccount], preselectedAccountID: UUID?) {
        self.accounts = accounts
        _selectedAccountID = State(initialValue: preselectedAccountID ?? accounts.first?.id ?? UUID())
    }

    private var selectedAccount: EmailAccount? {
        accounts.first { $0.id == selectedAccountID }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                if accounts.count > 1 {
                    Section {
                        Picker("Konto", selection: $selectedAccountID) {
                            ForEach(accounts) { account in
                                Text(account.email).tag(account.id)
                            }
                        }
                    }
                }

                Section {
                    TextField("Ordnername", text: $name)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } footer: {
                    if let selectedAccount {
                        Text("Der Ordner wird auf dem Server von \(selectedAccount.email) angelegt.")
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Ordner anlegen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Anlegen") {
                        Task { await save() }
                    }
                    .disabled(trimmedName.isEmpty || selectedAccount == nil || isSaving)
                }
            }
        }
    }

    private func save() async {
        guard let account = selectedAccount else { return }
        isSaving = true
        defer { isSaving = false }

        do {
            try await mailStore.createFolder(named: name, for: account.id)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: – Ordner umbenennen

struct RenameFolderView: View {
    let account: EmailAccount
    let folder: MailFolder

    @EnvironmentObject var mailStore: MailStore
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var errorMessage: String?
    @State private var isSaving = false

    init(account: EmailAccount, folder: MailFolder) {
        self.account = account
        self.folder = folder
        // Nur das letzte Segment bearbeiten: Ein verschachtelter Ordner
        // bleibt im selben Elternordner, statt nach oben zu wandern.
        _name = State(initialValue: folder.readableLeafName)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Ordnername", text: $name)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } footer: {
                    Text("Der Ordner wird auf dem Server von \(account.email) umbenannt. Nachrichten bleiben erhalten.")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Ordner umbenennen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Umbenennen") {
                        Task { await save() }
                    }
                    .disabled(trimmedName.isEmpty || isSaving)
                }
            }
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        do {
            try await mailStore.renameFolder(
                named: folder.name,
                toLeaf: name,
                for: account.id
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: – Ziel für Kontextmenü und Sheets

private struct FolderTarget: Identifiable {
    let account: EmailAccount
    let folder: MailFolder

    var id: String { "\(account.id.uuidString)|\(folder.name)" }
}
