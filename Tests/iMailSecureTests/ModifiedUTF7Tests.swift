// ModifiedUTF7Tests.swift
//
// Die Testfälle stammen aus echten Antworten von imap.gmx.net. GMX liefert
// Ordnernamen in modified UTF-7; ohne Übersetzung stand in der Oberfläche
// „Entw&APw-rfe" statt „Entwürfe".

import XCTest
@testable import iMailSecure

final class ModifiedUTF7Tests: XCTestCase {

    // MARK: – Dekodieren

    func testDecodesRealGmxFolderNames() {
        XCTAssertEqual(ModifiedUTF7.decode("Entw&APw-rfe"), "Entwürfe")
        XCTAssertEqual(ModifiedUTF7.decode("Gel&APY-scht"), "Gelöscht")
        XCTAssertEqual(
            ModifiedUTF7.decode("iMail-Test-MUTF7-1794446596-Pr&APw-fung"),
            "iMail-Test-MUTF7-1794446596-Prüfung"
        )
        XCTAssertEqual(ModifiedUTF7.decode("Spamverdacht"), "Spamverdacht")
        XCTAssertEqual(ModifiedUTF7.decode("INBOX"), "INBOX")
    }

    func testAmpersandEscapes() {
        XCTAssertEqual(ModifiedUTF7.decode("A&-B"), "A&B")
        XCTAssertEqual(ModifiedUTF7.decode("&-"), "&")
        XCTAssertEqual(ModifiedUTF7.encode("A&B"), "A&-B")
    }

    func testDecodeKeepsBrokenInputReadable() {
        // Kein Abschlussstrich und ungültiges Base64 dürfen nichts verlieren.
        XCTAssertEqual(ModifiedUTF7.decode("Kaputt&"), "Kaputt&")
        XCTAssertEqual(ModifiedUTF7.decode("Kaputt&ZZ-"), "Kaputt&ZZ-")
    }

    // MARK: – Kodieren

    func testEncodesGermanUmlauts() {
        XCTAssertEqual(ModifiedUTF7.encode("Entwürfe"), "Entw&APw-rfe")
        XCTAssertEqual(ModifiedUTF7.encode("Gelöscht"), "Gel&APY-scht")
        XCTAssertEqual(ModifiedUTF7.encode("Prüfung"), "Pr&APw-fung")
    }

    func testRoundTrip() {
        let names = [
            "Rechnungen",
            "Prüfungen 2026",
            "Änderungen & Notizen",
            "Ümlaute/verschachtelt",
            "Test 😀 Emoji"
        ]
        for name in names {
            XCTAssertEqual(
                ModifiedUTF7.decode(ModifiedUTF7.encode(name)),
                name,
                "Round-Trip fehlgeschlagen für \(name)"
            )
        }
    }

    func testPlainAsciiIsUnchanged() {
        XCTAssertEqual(ModifiedUTF7.encode("Projekte/2026"), "Projekte/2026")
        XCTAssertEqual(ModifiedUTF7.decode("Projekte/2026"), "Projekte/2026")
    }
}
