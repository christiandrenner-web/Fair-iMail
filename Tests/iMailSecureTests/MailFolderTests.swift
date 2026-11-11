// MailFolderTests.swift
//
// Ordnerlogik ohne Server: Rollenerkennung, Anzeigenamen, Validierung und
// die Free/Pro-Grenze sind reine Funktionen und damit direkt prüfbar.

import XCTest
import SwiftMail
@testable import iMailSecure

final class MailFolderTests: XCTestCase {

    // MARK: – Rollenerkennung über Special-Use

    func testSpecialUseAttributes() {
        let cases: [(Mailbox.Info.Attributes, MailFolderRole)] = [
            (.inbox, .inbox),
            (.sent, .sent),
            (.drafts, .drafts),
            (.trash, .trash),
            (.junk, .junk),
            (.archive, .archive),
            (.flagged, .flagged)
        ]

        for (attributes, expected) in cases {
            XCTAssertEqual(
                MailFolderRole.detect(name: "Beliebig", attributes: attributes, delimiter: nil),
                expected,
                "Attribut \(attributes) wurde nicht erkannt"
            )
        }
    }

    func testAttributesWinOverName() {
        // Ein Server darf einen Ordner „Archiv" nennen und ihn als Sent
        // markieren — das Attribut ist die verlässlichere Quelle.
        XCTAssertEqual(
            MailFolderRole.detect(name: "Archiv", attributes: [.sent], delimiter: nil),
            .sent
        )
    }

    // MARK: – Namens-Fallback

    func testGermanNamesWithoutAttributes() {
        XCTAssertEqual(role(for: "Posteingang"), .inbox)
        XCTAssertEqual(role(for: "Gesendet"), .sent)
        XCTAssertEqual(role(for: "Gesendete Elemente"), .sent)
        XCTAssertEqual(role(for: "Entwürfe"), .drafts)
        XCTAssertEqual(role(for: "Papierkorb"), .trash)
        XCTAssertEqual(role(for: "Gelöschte Elemente"), .trash)
        XCTAssertEqual(role(for: "Spam"), .junk)
        XCTAssertEqual(role(for: "Archiv"), .archive)
        XCTAssertEqual(role(for: "Markiert"), .flagged)
    }

    func testEnglishNamesAreCaseInsensitive() {
        XCTAssertEqual(role(for: "INBOX"), .inbox)
        XCTAssertEqual(role(for: "sent items"), .sent)
        XCTAssertEqual(role(for: "Drafts"), .drafts)
        XCTAssertEqual(role(for: "Deleted Messages"), .trash)
        XCTAssertEqual(role(for: "Junk E-Mail"), .junk)
    }

    func testNestedNameUsesLastSegment() {
        XCTAssertEqual(
            role(for: "INBOX.Trash", delimiter: "."),
            .trash
        )
        XCTAssertEqual(
            role(for: "Persönlich/Gesendet", delimiter: "/"),
            .sent
        )
    }

    func testUnknownNameIsCustom() {
        XCTAssertEqual(role(for: "Rechnungen 2026"), .custom)
        XCTAssertEqual(role(for: "Projekte.Alt", delimiter: "."), .custom)
    }

    // MARK: – Anzeigename

    func testSystemFoldersUseGermanDisplayName() {
        XCTAssertEqual(MailFolder(name: "INBOX", role: .inbox).displayName, "Posteingang")
        XCTAssertEqual(MailFolder(name: "Trash", role: .trash).displayName, "Papierkorb")
    }

    func testCustomFolderKeepsName() {
        XCTAssertEqual(
            MailFolder(name: "Rechnungen", role: .custom).displayName,
            "Rechnungen"
        )
    }

    func testCustomNestedFolderShowsPath() {
        XCTAssertEqual(
            MailFolder(name: "Projekte/2026", role: .custom, delimiter: "/").displayName,
            "Projekte › 2026"
        )
    }

    // MARK: – Auswahl und Sortierung

    func testSortedPutsSystemFoldersBeforeCustom() {
        let folders = MailFolder.sorted([
            MailFolder(name: "Projekte", role: .custom),
            MailFolder(name: "Trash", role: .trash),
            MailFolder(name: "INBOX", role: .inbox),
            MailFolder(name: "Gesendet", role: .sent)
        ])

        XCTAssertEqual(folders.map(\.role), [.inbox, .sent, .trash, .custom])
    }

    func testSortedDropsNonSelectableAndDuplicates() {
        let folders = MailFolder.sorted([
            MailFolder(name: "[Gmail]", role: .custom, isSelectable: false),
            MailFolder(name: "INBOX", role: .inbox),
            MailFolder(name: "INBOX", role: .inbox)
        ])

        XCTAssertEqual(folders.map(\.name), ["INBOX"])
    }

    func testNonSelectableMailboxIsNotSelectable() {
        let info = Mailbox.Info(
            name: "[Gmail]",
            attributes: [.noSelect, .hasChildren],
            hierarchyDelimiter: "/"
        )
        XCTAssertFalse(MailFolder(info: info).isSelectable)
    }

    func testMailFolderFromInfo() {
        let info = Mailbox.Info(
            name: "Gesendet",
            attributes: [],
            hierarchyDelimiter: "/"
        )
        let folder = MailFolder(info: info)

        XCTAssertEqual(folder.name, "Gesendet")
        XCTAssertEqual(folder.role, .sent)
        XCTAssertEqual(folder.delimiter, "/")
    }

    func testSystemFoldersAreFreeCustomFoldersRequirePro() {
        XCTAssertFalse(MailFolder(name: "INBOX", role: .inbox).requiresPro)
        XCTAssertFalse(MailFolder(name: "Gesendet", role: .sent).requiresPro)
        XCTAssertTrue(MailFolder(name: "Projekte", role: .custom).requiresPro)
    }

    func testSelectionTitle() {
        let folder = MailFolder(name: "INBOX", role: .inbox)
        XCTAssertEqual(
            MailboxSelection.folder(accountID: UUID(), folder: folder).title,
            "Posteingang"
        )
        XCTAssertEqual(MailboxSelection.unifiedInbox.title, "Gemeinsamer Posteingang")
    }

    // MARK: – Umbenennen

    func testLeafNameForRootAndNestedFolders() {
        XCTAssertEqual(
            MailFolder(name: "Rechnungen", role: .custom).leafName(),
            "Rechnungen"
        )
        XCTAssertEqual(
            MailFolder(name: "Projekte/2026", role: .custom, delimiter: "/").leafName(),
            "2026"
        )
    }

    func testRenamedPathKeepsParentAndValidatesLeaf() throws {
        let folder = MailFolder(name: "Projekte/2026", role: .custom, delimiter: "/")

        XCTAssertEqual(try folder.renamedPath(to: "2027"), "Projekte/2027")
        XCTAssertThrowsError(try folder.renamedPath(to: "   "))
        XCTAssertThrowsError(try folder.renamedPath(to: "a/b"))
    }

    func testOnlyCustomFoldersAreRenameable() {
        XCTAssertTrue(MailFolder(name: "INBOX", role: .inbox).role.isSystem)
        XCTAssertTrue(MailFolder(name: "Trash", role: .trash).role.isSystem)
        XCTAssertFalse(MailFolder(name: "Projekte", role: .custom).role.isSystem)
    }

    // MARK: – Namensvalidierung

    func testValidNameIsTrimmed() throws {
        XCTAssertEqual(
            try MailFolder.validatedName("  Rechnungen 2026  "),
            "Rechnungen 2026"
        )
        // Zeilenumbrüche am Rand verschwinden beim Trimmen; eingebettete
        // Steuerzeichen werden unten abgelehnt.
        XCTAssertEqual(
            try MailFolder.validatedName("Rechnung\r\n"),
            "Rechnung"
        )
    }

    func testEmptyNameIsRejected() {
        XCTAssertThrowsError(try MailFolder.validatedName("")) { error in
            XCTAssertEqual(error as? MailFolderError, .emptyName)
        }
        XCTAssertThrowsError(try MailFolder.validatedName("   \n "))
    }

    func testForbiddenCharactersAreRejected() {
        let invalid = ["Rech\nnung", "Pro{jekt}", "100%", "a*b", "sag\"hallo", "back\\slash"]
        for name in invalid {
            XCTAssertThrowsError(
                try MailFolder.validatedName(name),
                "Name wurde akzeptiert: \(name)"
            )
        }
    }

    func testDotNamesAreRejected() {
        XCTAssertThrowsError(try MailFolder.validatedName("."))
        XCTAssertThrowsError(try MailFolder.validatedName(".."))
    }

    func testDelimiterIsRejected() {
        XCTAssertThrowsError(
            try MailFolder.validatedName("Projekte/2026", delimiter: "/")
        ) { error in
            XCTAssertEqual(error as? MailFolderError, .usesDelimiter("/"))
        }
        // Ohne bekannten Delimiter ist der Schrägstrich erlaubt.
        XCTAssertEqual(
            try MailFolder.validatedName("Projekte/2026"),
            "Projekte/2026"
        )
    }

    func testLengthLimit() {
        let allowed = String(repeating: "a", count: 255)
        XCTAssertEqual(try MailFolder.validatedName(allowed), allowed)

        let tooLong = String(repeating: "a", count: 256)
        XCTAssertThrowsError(try MailFolder.validatedName(tooLong)) { error in
            XCTAssertEqual(error as? MailFolderError, .nameTooLong)
        }
    }

    func testUmlautsAndSpacesAreAllowed() {
        XCTAssertEqual(
            try MailFolder.validatedName("Prüfungen & Unterlagen"),
            "Prüfungen & Unterlagen"
        )
    }

    // MARK: – Helfer

    private func role(for name: String, delimiter: String? = nil) -> MailFolderRole {
        MailFolderRole.detect(name: name, attributes: [], delimiter: delimiter)
    }
}
