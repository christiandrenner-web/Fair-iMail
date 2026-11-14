// ScreenshotUITests.swift
//
// Erzeugt die App-Store-Screenshots über fastlane snapshot. Pro Sprache und
// Geräteklasse (iPhone 6.9", iPad 13") entstehen vier Bilder:
//
//   01_Posteingang · 02_Nachricht · 03_Ordner · 04_Einstellungen
//
// Der Pro-Zustand kommt aus dem Debug-Startargument `-imaailTier pro`, damit
// die Ordnerverwaltung sichtbar ist. Screenshots zeigen keine echten Daten:
// Das Testkonto enthält ausschließlich Demo-Nachrichten, die
// `Tools/seed-demo-mail.py` vor jedem Sprachlauf in der jeweiligen Sprache
// anlegt.
//
// Alle Schritte arbeiten mit Accessibility-Identifiern, nie mit
// Beschriftungen — die wechseln mit der Sprache.

import XCTest

@MainActor
final class ScreenshotUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        guard TestEnv.hasCredentials else {
            throw XCTSkip("IMAIL_TEST_USER/IMAIL_TEST_PASS fehlen")
        }
    }

    func testScreenshots() throws {
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launchArguments += ["-imaailTier", "pro"]
        app.launch()

        XCTAssertTrue(ensureAccount(in: app))

        // Posteingang: warten, bis der erste Abgleich durch ist.
        XCTAssertTrue(
            app.descendants(matching: .any)
                .matching(identifier: "message.row")
                .firstMatch
                .waitForExistence(timeout: 120),
            "Posteingang blieb leer"
        )
        snapshot("01_Posteingang")

        // Nachricht: HTML-Ansicht mit blockierten externen Inhalten.
        XCTAssertTrue(
            openNewestMessage(in: app),
            "Nachricht ließ sich nicht öffnen — Screenshot 02 wäre sonst eine Dublette des Posteingangs"
        )
        if app.buttons["detail.showHTML"].waitForExistence(timeout: 10) {
            app.buttons["detail.showHTML"].tap()
            sleep(2)
        }
        snapshot("02_Nachricht")
        let back = app.navigationBars.buttons.element(boundBy: 0)
        if back.exists { back.tap() }

        // Ordner: Systemordner und die eigenen Ordner (Pro).
        openFolderList(in: app)
        let folderList = app.collectionViews.firstMatch
        if folderList.exists { folderList.swipeUp() }
        sleep(1)
        snapshot("03_Ordner")
        app.buttons["folders.done"].tap()

        // Einstellungen: Datenschutzfunktionen, Lizenz, Quellcode-Link.
        openSettings(in: app)
        sleep(2)
        snapshot("04_Einstellungen")
    }
}
