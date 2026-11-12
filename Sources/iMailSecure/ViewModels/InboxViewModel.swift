// InboxViewModel.swift
import SwiftUI
import Combine

@MainActor
final class InboxViewModel: ObservableObject {
    @Published var searchText = ""

    func filteredMessages(from store: MailStore) -> [EmailMessage] {
        guard let selection = store.selection else { return [] }
        let msgs = store.messages(for: selection)
        guard !searchText.isEmpty else { return msgs }
        return msgs.filter {
            $0.subject.localizedCaseInsensitiveContains(searchText) ||
            $0.from.address.localizedCaseInsensitiveContains(searchText) ||
            $0.body.localizedCaseInsensitiveContains(searchText)
        }
    }

    func unreadCount(from store: MailStore) -> Int {
        guard let selection = store.selection else { return 0 }
        return store.messages(for: selection).filter { !$0.isRead }.count
    }

    func title(for store: MailStore) -> String {
        store.selection?.title
            ?? String(localized: "folder.inbox", defaultValue: "Posteingang")
    }
}
