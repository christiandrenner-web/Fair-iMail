// MailStoreTests.swift
//
// Ordner-Auswahl und Nachrichtenfilter ohne IMAP. Der Store ist @MainActor,
// die Tests laufen deshalb auf dem Main Actor.

import XCTest
@testable import iMailSecure

final class MailStoreTests: XCTestCase {

    // MARK: – Standardauswahl

    @MainActor
    func testFirstFolderListSelectsInbox() {
        let store = MailStore()
        let account = UUID()
        let inbox = MailFolder(name: "INBOX", role: .inbox)
        let sent = MailFolder(name: "Gesendet", role: .sent)

        store.setFolders([sent, inbox], for: account)

        XCTAssertEqual(store.selection, .folder(accountID: account, folder: inbox))
    }

    @MainActor
    func testSelectionStaysNilWithoutInbox() {
        let store = MailStore()
        store.setFolders([MailFolder(name: "Projekte", role: .custom)], for: UUID())
        XCTAssertNil(store.selection)
    }

    @MainActor
    func testSecondAccountDoesNotStealSelection() {
        let store = MailStore()
        let first = UUID()
        let second = UUID()
        let firstInbox = MailFolder(name: "INBOX", role: .inbox)
        let secondInbox = MailFolder(name: "INBOX", role: .inbox)

        store.setFolders([firstInbox], for: first)
        store.setFolders([secondInbox], for: second)

        XCTAssertEqual(store.selection, .folder(accountID: first, folder: firstInbox))
    }

    // MARK: – Nachrichten filtern

    @MainActor
    func testUnifiedInboxAggregatesOnlyInboxes() {
        let store = MailStore()
        let first = UUID()
        let second = UUID()
        store.setFolders([
            MailFolder(name: "INBOX", role: .inbox),
            MailFolder(name: "Gesendet", role: .sent)
        ], for: first)
        store.setFolders([
            MailFolder(name: "INBOX", role: .inbox),
            MailFolder(name: "Archiv", role: .archive)
        ], for: second)

        store.messages = [
            message(id: "first-inbox", account: first, folder: "INBOX", date: 200),
            message(id: "first-sent", account: first, folder: "Gesendet", date: 200),
            message(id: "second-inbox", account: second, folder: "INBOX", date: 100),
            message(id: "second-archive", account: second, folder: "Archiv", date: 200)
        ]

        XCTAssertEqual(
            store.messages(for: .unifiedInbox).map(\.id),
            ["first-inbox", "second-inbox"]
        )
    }

    @MainActor
    func testUnifiedInboxFallsBackToNameWithoutFolderList() {
        let store = MailStore()
        let account = UUID()
        store.messages = [
            message(id: "inbox", account: account, folder: "INBOX"),
            message(id: "custom", account: account, folder: "Rechnungen")
        ]

        XCTAssertEqual(store.messages(for: .unifiedInbox).map(\.id), ["inbox"])
    }

    @MainActor
    func testFolderSelectionIsBoundToAccountAndName() {
        let store = MailStore()
        let first = UUID()
        let second = UUID()
        let sent = MailFolder(name: "Gesendet", role: .sent)
        store.setFolders([MailFolder(name: "INBOX", role: .inbox), sent], for: first)

        store.messages = [
            message(id: "first-sent", account: first, folder: "Gesendet"),
            message(id: "second-sent", account: second, folder: "Gesendet")
        ]

        XCTAssertEqual(
            store.messages(for: .folder(accountID: first, folder: sent)).map(\.id),
            ["first-sent"]
        )
    }

    @MainActor
    func testMessagesAreSortedNewestFirst() {
        let store = MailStore()
        let account = UUID()
        let inbox = MailFolder(name: "INBOX", role: .inbox)
        store.setFolders([inbox], for: account)
        store.messages = [
            message(id: "old", account: account, folder: "INBOX", date: 100),
            message(id: "new", account: account, folder: "INBOX", date: 300),
            message(id: "middle", account: account, folder: "INBOX", date: 200)
        ]

        XCTAssertEqual(
            store.messages(for: .folder(accountID: account, folder: inbox)).map(\.id),
            ["new", "middle", "old"]
        )
    }

    @MainActor
    func testSameMessageIDCanLiveInTwoFolders() {
        let store = MailStore()
        let account = UUID()
        let inbox = MailFolder(name: "INBOX", role: .inbox)
        let archive = MailFolder(name: "Archiv", role: .archive)
        store.setFolders([inbox, archive], for: account)

        let inInbox = message(id: "same@example.com", account: account, folder: "INBOX")
        let inArchive = message(id: "same@example.com", account: account, folder: "Archiv")

        store.merge(incoming: [inInbox, inArchive])

        XCTAssertEqual(store.messages.count, 2)
        XCTAssertEqual(
            store.messages(for: .folder(accountID: account, folder: inbox)).count, 1)
        XCTAssertEqual(
            store.messages(for: .folder(accountID: account, folder: archive)).count, 1)
    }

    @MainActor
    func testMarkAsReadOnlyAffectsSelectedFolderCopy() {
        let store = MailStore()
        let account = UUID()
        let inbox = MailFolder(name: "INBOX", role: .inbox)
        let archive = MailFolder(name: "Archiv", role: .archive)
        store.setFolders([inbox, archive], for: account)

        let inInbox = message(id: "same@example.com", account: account, folder: "INBOX")
        let inArchive = message(id: "same@example.com", account: account, folder: "Archiv")
        store.merge(incoming: [inInbox, inArchive])

        store.markAsRead(inInbox)

        XCTAssertEqual(
            store.messages(for: .folder(accountID: account, folder: inbox)).first?.isRead,
            true)
        XCTAssertEqual(
            store.messages(for: .folder(accountID: account, folder: archive)).first?.isRead,
            false)
    }

    // MARK: – Auswahl reparieren

    @MainActor
    func testSelectionFallsBackWhenFolderDisappears() {
        let store = MailStore()
        let account = UUID()
        let inbox = MailFolder(name: "INBOX", role: .inbox)
        let custom = MailFolder(name: "Projekte", role: .custom)

        store.setFolders([inbox, custom], for: account)
        store.selection = .folder(accountID: account, folder: custom)

        store.setFolders([inbox], for: account)

        XCTAssertEqual(store.selection, .folder(accountID: account, folder: inbox))
    }

    @MainActor
    func testUnifiedSelectionSurvivesFolderRefresh() {
        let store = MailStore()
        let account = UUID()
        store.setFolders([MailFolder(name: "INBOX", role: .inbox)], for: account)
        store.selection = .unifiedInbox

        store.setFolders([MailFolder(name: "INBOX", role: .inbox)], for: account)

        XCTAssertEqual(store.selection, .unifiedInbox)
    }

    @MainActor
    func testFreeFallbackReplacesUnifiedInbox() {
        let store = MailStore()
        let account = UUID()
        let inbox = MailFolder(name: "INBOX", role: .inbox)
        store.setFolders([inbox], for: account)
        store.selection = .unifiedInbox

        store.fallBackToFreeSelection()

        XCTAssertEqual(store.selection, .folder(accountID: account, folder: inbox))
    }

    @MainActor
    func testFreeFallbackReplacesCustomFolder() {
        let store = MailStore()
        let account = UUID()
        let inbox = MailFolder(name: "INBOX", role: .inbox)
        let custom = MailFolder(name: "Projekte", role: .custom)
        store.setFolders([inbox, custom], for: account)
        store.selection = .folder(accountID: account, folder: custom)

        store.fallBackToFreeSelection()

        XCTAssertEqual(store.selection, .folder(accountID: account, folder: inbox))
    }

    @MainActor
    func testFreeFallbackKeepsSystemFolder() {
        let store = MailStore()
        let account = UUID()
        let sent = MailFolder(name: "Gesendet", role: .sent)
        store.setFolders([MailFolder(name: "INBOX", role: .inbox), sent], for: account)
        store.selection = .folder(accountID: account, folder: sent)

        store.fallBackToFreeSelection()

        XCTAssertEqual(store.selection, .folder(accountID: account, folder: sent))
    }

    // MARK: – Ordner umbenennen/löschen

    @MainActor
    func testRenamingSystemFolderIsRefused() async {
        let store = MailStore()
        let account = UUID()
        store.setFolders([MailFolder(name: "INBOX", role: .inbox)], for: account)

        do {
            try await store.renameFolder(named: "INBOX", toLeaf: "Posteingang", for: account)
            XCTFail("Systemordner darf nicht umbenannt werden")
        } catch {
            XCTAssertEqual(error as? MailFolderError, .systemFolder)
        }
    }

    @MainActor
    func testDeletingSystemFolderIsRefused() async {
        let store = MailStore()
        let account = UUID()
        store.setFolders([MailFolder(name: "Trash", role: .trash)], for: account)

        do {
            try await store.deleteFolder(named: "Trash", for: account)
            XCTFail("Systemordner darf nicht gelöscht werden")
        } catch {
            XCTAssertEqual(error as? MailFolderError, .systemFolder)
        }
    }

    @MainActor
    func testRenamingUnknownFolderFails() async {
        let store = MailStore()
        let account = UUID()
        store.setFolders([MailFolder(name: "INBOX", role: .inbox)], for: account)

        do {
            try await store.renameFolder(named: "Fehlt", toLeaf: "Neu", for: account)
            XCTFail("Unbekannter Ordner darf nicht umbenannt werden")
        } catch {
            XCTAssertEqual(error as? MailFolderError, .folderNotFound)
        }
    }

    // MARK: – Ordner-Abfragen

    @MainActor
    func testFolderLookupByRoleAndName() {
        let store = MailStore()
        let account = UUID()
        let trash = MailFolder(name: "Trash", role: .trash, delimiter: "/")
        store.setFolders([MailFolder(name: "INBOX", role: .inbox), trash], for: account)

        XCTAssertEqual(store.folder(for: account, role: .trash), trash)
        XCTAssertEqual(store.folder(for: account, name: "Trash"), trash)
        XCTAssertNil(store.folder(for: account, role: .archive))
        XCTAssertEqual(store.folderDelimiter(for: account), "/")
    }

    // MARK: – Löschen

    @MainActor
    func testDeleteMovesLocallyIntoServerTrashFolder() {
        let store = MailStore()
        let account = UUID()
        store.setFolders([
            MailFolder(name: "INBOX", role: .inbox),
            MailFolder(name: "Trash", role: .trash)
        ], for: account)

        let original = message(id: "m1", account: account, folder: "INBOX", uid: 42)
        store.messages = [original]

        store.delete(original)

        XCTAssertEqual(store.messages.first?.folder, "Trash")
        XCTAssertTrue(store.messages.first?.isMarkedDeleted == true)
    }

    @MainActor
    func testDeleteWithoutKnownTrashUsesLocalFallback() {
        let store = MailStore()
        let account = UUID()
        store.setFolders([MailFolder(name: "INBOX", role: .inbox)], for: account)

        let original = message(id: "m1", account: account, folder: "INBOX", uid: 0)
        store.messages = [original]

        store.delete(original)

        XCTAssertEqual(store.messages.first?.folder, "Papierkorb")
    }

    // MARK: – Gesendet

    @MainActor
    func testSentMessageUsesServerSentFolder() {
        let store = MailStore()
        let account = EmailAccount(
            displayName: "Test",
            email: "test@example.com",
            imapHost: "imap.example.com",
            imapPort: 993,
            smtpHost: "smtp.example.com",
            smtpPort: 587,
            username: "test@example.com"
        )
        store.setFolders([
            MailFolder(name: "INBOX", role: .inbox),
            MailFolder(name: "Sent", role: .sent)
        ], for: account.id)

        store.saveSentMessage(draft: EmailDraft(), account: account)

        XCTAssertEqual(store.messages.first?.folder, "Sent")
    }

    // MARK: – Badge

    @MainActor
    func testUnreadInboxCountIgnoresOtherFolders() {
        let store = MailStore()
        let account = UUID()
        store.setFolders([
            MailFolder(name: "INBOX", role: .inbox),
            MailFolder(name: "Gesendet", role: .sent)
        ], for: account)

        var read = message(id: "read", account: account, folder: "INBOX")
        read.isRead = true
        store.messages = [
            message(id: "unread", account: account, folder: "INBOX"),
            read,
            message(id: "sent-unread", account: account, folder: "Gesendet")
        ]

        XCTAssertEqual(store.unreadInboxCount, 1)
    }

    // MARK: – Helfer

    private func message(
        id: String,
        account: UUID,
        folder: String,
        date: TimeInterval = 0,
        uid: UInt32 = 1
    ) -> EmailMessage {
        EmailMessage(
            id: id,
            uid: uid,
            accountID: account,
            from: EmailAddress(name: nil, address: "sender@example.com"),
            to: [],
            subject: "Betreff",
            date: Date(timeIntervalSince1970: date),
            body: "Text",
            folder: folder
        )
    }
}
