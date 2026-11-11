// ComposeViewModelTests.swift
//
// Der Schalter „Lesebestätigung standardmäßig anfordern" muss beim Öffnen
// eines neuen Entwurfs wirken — und nach dem Senden erneut, nicht nur beim
// ersten Mal. Beides läuft über `ComposeViewModel.makeDraft(defaults:)`.

import XCTest
@testable import iMailSecure

final class ComposeViewModelTests: XCTestCase {

    private var defaults: UserDefaults!
    private let suiteName = "io.imailsecure.tests.compose"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    @MainActor
    func testDraftPicksUpEnabledDefault() {
        defaults.set(true, forKey: AppConstants.UserDefaultsKeys.defaultRequestMDN)

        let vm = ComposeViewModel(account: account(), defaults: defaults)

        XCTAssertTrue(vm.draft.requestMDN)
    }

    @MainActor
    func testDraftDefaultsToOffWhenUnset() {
        let vm = ComposeViewModel(account: account(), defaults: defaults)

        XCTAssertFalse(vm.draft.requestMDN)
    }

    @MainActor
    func testDraftFollowsChangedSetting() {
        defaults.set(true, forKey: AppConstants.UserDefaultsKeys.defaultRequestMDN)
        let vm = ComposeViewModel(account: account(), defaults: defaults)
        XCTAssertTrue(vm.draft.requestMDN)

        // Einstellung ändern, dann neuen Entwurf erzeugen (z. B. nach dem Senden).
        defaults.set(false, forKey: AppConstants.UserDefaultsKeys.defaultRequestMDN)
        let next = ComposeViewModel.makeDraft(defaults: defaults)

        XCTAssertFalse(next.requestMDN)
        XCTAssertEqual(next.toText, "")
        XCTAssertEqual(next.subject, "")
    }

    @MainActor
    func testDraftDoesNotLeakUserInput() {
        defaults.set(true, forKey: AppConstants.UserDefaultsKeys.defaultRequestMDN)
        let vm = ComposeViewModel(account: account(), defaults: defaults)
        vm.draft.toText = "empfaenger@example.com"
        vm.draft.subject = "Betreff"

        let fresh = ComposeViewModel.makeDraft(defaults: defaults)

        XCTAssertTrue(fresh.requestMDN)
        XCTAssertTrue(fresh.toText.isEmpty)
        XCTAssertTrue(fresh.subject.isEmpty)
    }

    // MARK: – Helfer

    private func account() -> EmailAccount {
        EmailAccount(
            displayName: "Test",
            email: "test@example.com",
            imapHost: "imap.example.com",
            imapPort: 993,
            smtpHost: "smtp.example.com",
            smtpPort: 465,
            username: "test@example.com"
        )
    }
}
