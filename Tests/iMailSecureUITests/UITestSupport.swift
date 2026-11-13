// UITestSupport.swift
//
// Gemeinsame Helfer für die Oberflächentests. Die Tests laufen gegen die
// echte App im Simulator, mit einem echten IMAP-Konto und der
// StoreKit-Testkonfiguration `iMailSecure.storekit`.
//
// Zugangsdaten kommen aus der Umgebung und stehen nie im Repository:
//
//   TEST_RUNNER_IMAIL_TEST_USER=… TEST_RUNNER_IMAIL_TEST_PASS=… \
//     xcodebuild test -scheme iMailSecure …
//
// Ohne Zugangsdaten werden die Tests übersprungen, nicht rot.

import XCTest

enum TestEnv {
    static let user = ProcessInfo.processInfo.environment["IMAIL_TEST_USER"] ?? ""
    static let password = ProcessInfo.processInfo.environment["IMAIL_TEST_PASS"] ?? ""
    static var hasCredentials: Bool { !user.isEmpty && !password.isEmpty }
}

extension XCTestCase {

    /// Startet die App in der gewünschten Sprache. Die Sprache wird nur der
    /// App mitgegeben, nicht dem Testprozess.
    func launchApp(language: String = "de",
                   extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages", "(\(language))",
            "-AppleLocale", language
        ] + extraArguments
        app.launch()
        return app
    }

    /// Legt das Testkonto an, falls die App ohne Konto startet. Ist bereits
    /// eines vorhanden (Keychain überlebt eine Neuinstallation), wird es
    /// weiterverwendet.
    @discardableResult
    func ensureAccount(in app: XCUIApplication) -> Bool {
        let welcome = app.buttons["welcome.addAccount"]
        // iPadOS 26 zeigt die Tab-Leiste als schwebende Pille, die nicht
        // zuverlässig als `tabBars` erscheint. Der Ordner-Knopf ist der
        // verlässliche Marker für die Hauptansicht.
        let mainView = app.buttons["inbox.folders"]

        let deadline = Date().addingTimeInterval(90)
        while Date() < deadline {
            if welcome.exists { break }
            if mainView.exists { return true }
            _ = welcome.waitForExistence(timeout: 1)
        }

        guard welcome.exists else {
            XCTFail("Weder Willkommensseite noch Hauptansicht erschienen")
            return false
        }
        guard TestEnv.hasCredentials else {
            XCTFail("IMAIL_TEST_USER/IMAIL_TEST_PASS fehlen")
            return false
        }

        welcome.tap()

        let displayName = app.textFields["account.displayName"]
        XCTAssertTrue(displayName.waitForExistence(timeout: 15), "Kontoformular fehlt")
        app.buttons["Gmail"].tap()

        displayName.tap()
        displayName.typeText("iMail Test")

        let email = app.textFields["account.email"]
        email.tap()
        email.typeText(TestEnv.user)

        let password = app.secureTextFields["account.password"]
        password.tap()
        password.typeText(TestEnv.password)

        app.buttons["account.save"].tap()

        if !mainView.waitForExistence(timeout: 90) {
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "konto-speichern-fehlgeschlagen"
            screenshot.lifetime = .keepAlways
            add(screenshot)
            print("=== UI-HIERARCHIE ===\n\(app.debugDescription)\n=== ENDE ===")
            XCTFail("Hauptansicht nach dem Speichern nicht erschienen")
            return false
        }
        return true
    }

    /// Öffnet die Ordnerliste und wartet, bis der Server sie geliefert hat.
    func openFolderList(in app: XCUIApplication, timeout: TimeInterval = 90) {
        app.buttons["inbox.folders"].tap()
        XCTAssertTrue(
            app.buttons["folder.row.INBOX"].waitForExistence(timeout: timeout),
            "Ordner wurden nicht geladen"
        )
        scrollTo(app.buttons["folders.create"], in: app)
    }

    /// Öffnet die oberste Nachricht der Liste und wartet, bis die Detailansicht
    /// steht. `app.cells` ist unter iPadOS 26 nicht verlässlich, deshalb der
    /// Weg über den Identifier der Zeile.
    @discardableResult
    func openNewestMessage(in app: XCUIApplication, timeout: TimeInterval = 120) -> Bool {
        let row = app.descendants(matching: .any)
            .matching(identifier: "message.row")
            .firstMatch
        guard row.waitForExistence(timeout: timeout) else {
            dumpUI(app, "liste-ohne-nachrichten")
            return false
        }
        row.tap()

        let detail = app.buttons["detail.showHTML"]
        let back = app.navigationBars.firstMatch
        let deadline = Date().addingTimeInterval(20)
        while Date() < deadline {
            if detail.exists || back.exists { return true }
            usleep(300_000)
        }
        dumpUI(app, "detailansicht-fehlt")
        return false
    }

    /// Scrollt die sichtbare Liste, bis das Element aufgebaut ist. SwiftUI
    /// baut Zeilen einer `List` erst beim Scrollen auf.
    func scrollTo(_ element: XCUIElement, in app: XCUIApplication, attempts: Int = 8) {
        var remaining = attempts
        while !element.exists && remaining > 0 {
            let list = app.collectionViews.firstMatch
            if list.exists { list.swipeUp() } else { app.swipeUp() }
            remaining -= 1
        }
    }

    /// Wechselt in die Einstellungen. Die Tab-Leiste von iPadOS 26 zeigt die
    /// Einträge als Buttons, deren Identifier der SF-Symbol-Name ist — der
    /// bleibt in allen Sprachen gleich. Die Beschriftung nicht.
    func openSettings(in app: XCUIApplication) {
        let symbol = app.buttons["gearshape.fill"].firstMatch
        if symbol.waitForExistence(timeout: 10) {
            symbol.tap()
            return
        }
        let tab = app.tabBars.buttons.element(boundBy: 1)
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "Einstellungen-Tab fehlt")
        tab.tap()
    }

    /// Tippt einen Button, sobald er existiert.
    func tap(_ element: XCUIElement, timeout: TimeInterval = 15, _ message: String = "") {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), message)
        element.tap()
    }

    /// Hängt einen Screenshot an den Testbericht und gibt die sichtbare
    /// Elementhierarchie aus. Nur für Fehlerfälle gedacht.
    func dumpUI(_ app: XCUIApplication, _ name: String) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
        print("=== HIERARCHIE \(name) ===\n\(app.debugDescription)\n=== ENDE \(name) ===")
    }

    /// Wartet, bis ein Element verschwunden ist.
    func waitUntilGone(_ element: XCUIElement, timeout: TimeInterval = 30) {
        let gone = expectation(for: NSPredicate(format: "exists == false"),
                               evaluatedWith: element)
        wait(for: [gone], timeout: timeout)
    }
}
