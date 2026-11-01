// InboxViewModel.swift
import SwiftUI
import Combine

@MainActor
final class InboxViewModel: ObservableObject {
    @Published var searchText   = ""
    @Published var selectedFolder = "INBOX"

    var folders = ["INBOX", "Gesendet", "Entwürfe", "Papierkorb", "Spam"]

    func filteredMessages(from store: MailStore) -> [EmailMessage] {
        let msgs = store.messages(for: selectedFolder)
        guard !searchText.isEmpty else { return msgs }
        return msgs.filter {
            $0.subject.localizedCaseInsensitiveContains(searchText) ||
            $0.from.address.localizedCaseInsensitiveContains(searchText) ||
            $0.body.localizedCaseInsensitiveContains(searchText)
        }
    }

    func unreadCount(from store: MailStore) -> Int {
        store.messages(for: selectedFolder).filter { !$0.isRead }.count
    }
}
