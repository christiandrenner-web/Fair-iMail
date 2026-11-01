// InboxView.swift
import SwiftUI

struct InboxView: View {
    @EnvironmentObject var mailStore: MailStore
    @EnvironmentObject var accountStore: AccountStore
    @StateObject private var vm = InboxViewModel()

    var body: some View {
        NavigationStack {
            List {
                ForEach(vm.filteredMessages(from: mailStore)) { message in
                    NavigationLink {
                        MessageDetailView(message: message)
                    } label: {
                        MessageRowView(message: message)
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            mailStore.markAsRead(message)
                        } label: {
                            Label("Gelesen", systemImage: "envelope.open")
                        }
                        .tint(.blue)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            mailStore.delete(message)
                        } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle(vm.selectedFolder)
            .searchable(text: $vm.searchText, prompt: "E-Mails durchsuchen")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    folderMenu
                }
                ToolbarItem(placement: .topBarTrailing) {
                    refreshButton
                }
            }
            .overlay {
                if mailStore.messages.isEmpty && !mailStore.isSyncing {
                    emptyStateView
                }
                if mailStore.isSyncing {
                    ProgressView("Synchronisiere…")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .task { await mailStore.syncAll() }
    }

    private var folderMenu: some View {
        Menu {
            ForEach(vm.folders, id: \.self) { folder in
                Button(folder) { vm.selectedFolder = folder }
            }
        } label: {
            Label(vm.selectedFolder, systemImage: "folder")
        }
    }

    private var refreshButton: some View {
        Button {
            Task { await mailStore.syncAll() }
        } label: {
            Image(systemName: "arrow.clockwise")
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView(
            "Keine E-Mails",
            systemImage: "tray",
            description: Text("Dein Posteingang ist leer.")
        )
    }
}
