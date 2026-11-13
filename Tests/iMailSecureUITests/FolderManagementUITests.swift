// FolderManagementUITests.swift
//
// Durchklick-Test der Ordnerverwaltung im Simulator:
//
//   1. Testkonto über die Oberfläche anlegen
//   2. Ordnerliste öffnen
//   3. eigenen Ordner anlegen, umbenennen und löschen
//
// Der Pro-Zustand kommt aus dem Debug-Startargument `-imaailTier pro`, weil
// `xcodebuild` die StoreKit-Testkonfiguration im iOS-26-Simulator nicht an
// die App übergibt (bekannter Fehler; in Xcode selbst funktioniert sie).
// Der Kaufpfad selbst wird in `PurchaseFlowTests` (Unit-Tests mit
// SKTestSession) geprüft.

import XCTest

final class FolderManagementUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        guard TestEnv.hasCredentials else {
            throw XCTSkip("IMAIL_TEST_USER/IMAIL_TEST_PASS fehlen")
        }
    }

    func testCreateRenameAndDeleteFolder() throws {
        let app = launchApp(extraArguments: ["-imaailTier", "pro"])
        XCTAssertTrue(ensureAccount(in: app))

        openFolderList(in: app)

        let create = app.buttons["folders.create"]
        XCTAssertEqual(create.label, "Ordner anlegen",
                       "Pro-Stufe wurde nicht übernommen")

        let stamp = Int(Date().timeIntervalSince1970)
        let name = "UI-Test-\(stamp)"
        let renamed = "\(name)-neu"

        create.tap()
        let nameField = app.textFields["folder.nameField"]
        tap(nameField, timeout: 15, "Formular »Ordner anlegen« fehlt")
        nameField.typeText(name)
        app.buttons["folder.create.confirm"].tap()

        let row = app.buttons["folder.row.\(name)"]
        XCTAssertTrue(row.waitForExistence(timeout: 60),
                      "Angelegter Ordner erscheint nicht in der Liste")

        // Umbenennen über das Kontextmenü.
        row.press(forDuration: 1.5)
        tap(app.buttons["Umbenennen"], timeout: 10, "Kontextmenü ohne »Umbenennen«")

        let renameField = app.textFields["folder.renameField"]
        tap(renameField, timeout: 10, "Formular »Ordner umbenennen« fehlt")
        renameField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue,
                                    count: name.count + 5))
        renameField.typeText(renamed)
        app.buttons["folder.rename.confirm"].tap()

        let renamedRow = app.buttons["folder.row.\(renamed)"]
        XCTAssertTrue(renamedRow.waitForExistence(timeout: 60),
                      "Umbenannter Ordner erscheint nicht")

        // Löschen samt Bestätigung.
        renamedRow.press(forDuration: 1.5)
        tap(app.buttons["Löschen"], timeout: 10, "Kontextmenü ohne »Löschen«")

        let confirm = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH %@", "„"))
            .firstMatch
        tap(confirm, timeout: 10, "Löschbestätigung fehlt")

        waitUntilGone(renamedRow, timeout: 60)
    }

    func testFreeTierShowsProGate() throws {
        let app = launchApp(extraArguments: ["-imaailTier", "free"])
        XCTAssertTrue(ensureAccount(in: app))

        openFolderList(in: app)

        let create = app.buttons["folders.create"]
        XCTAssertEqual(create.label, "Ordner anlegen (Pro)")
        create.tap()

        XCTAssertTrue(
            app.navigationBars["iMail Secure Pro"].waitForExistence(timeout: 20),
            "Paywall wurde nicht geöffnet"
        )
    }
}
