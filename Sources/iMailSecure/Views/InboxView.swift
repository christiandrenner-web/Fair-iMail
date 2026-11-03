// InboxView.swift
import SwiftUI

struct InboxView: View {
    @EnvironmentObject var mailStore: MailStore
    @EnvironmentObject var subscription: SubscriptionManager
    @StateObject private var vm = InboxViewModel()
    @State private var showFolders = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(vm.filteredMessages(from: mailStore), id: \.listID) { message in
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
            .navigationTitle(vm.title(for: mailStore))
            .searchable(text: $vm.searchText, prompt: "E-Mails durchsuchen")
            .refreshable {
                await mailStore.sync(mailStore.selection)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showFolders = true
                    } label: {
                        Label("Ordner", systemImage: "folder")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    refreshButton
                }
            }
            .overlay {
                if vm.filteredMessages(from: mailStore).isEmpty && !mailStore.isSyncing {
                    emptyStateView
                }
                if mailStore.isSyncing {
                    ProgressView("Synchronisiere…")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .sheet(isPresented: $showFolders) {
                FolderListView()
            }
        }
        .task {
            if !subscription.isPro {
                mailStore.fallBackToFreeSelection()
            }
            if mailStore.selection == nil {
                await mailStore.syncAll()
            } else {
                await mailStore.sync(mailStore.selection)
            }
        }
        .onChange(of: subscription.isPro) { _, isPro in
            if !isPro {
                mailStore.fallBackToFreeSelection()
            }
        }
    }

    private var refreshButton: some View {
        Button {
            Task { await mailStore.sync(mailStore.selection) }
        } label: {
            Image(systemName: "arrow.clockwise")
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView(
            "Keine E-Mails",
            systemImage: "tray",
            description: Text(
                vm.searchText.isEmpty
                    ? "In diesem Ordner liegen keine E-Mails."
                    : "Keine Treffer für „\(vm.searchText)“."
            )
        )
    }
}
