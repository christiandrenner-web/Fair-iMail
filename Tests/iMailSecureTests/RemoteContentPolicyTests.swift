// RemoteContentPolicyTests.swift
//
// D2, Stufe 3 – Tests für die Freigabe externer Inhalte.
//
// Geprüft wird: blockiert ist der Standard, einmalige Freigaben gelten nur
// für eine Message-ID, dauerhafte Freigaben werden persistiert und lassen
// sich widerrufen.

import XCTest
@testable import iMailSecure

@MainActor
final class RemoteContentPolicyTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "imailsecure.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    private func makePolicy() -> RemoteContentPolicy {
        RemoteContentPolicy(defaults: defaults)
    }

    // MARK: – Grundzustand

    func testNothingIsAllowedByDefault() {
        let policy = makePolicy()
        XCTAssertFalse(policy.isTrusted(sender: "news@example.com"))
        XCTAssertFalse(policy.isAllowed(messageID: "<1@example.com>", sender: "news@example.com"))
        XCTAssertTrue(policy.sortedTrustedSenders.isEmpty)
    }

    // MARK: – Einmalige Freigabe

    func testAllowOnceAppliesOnlyToThatMessage() {
        let policy = makePolicy()
        policy.allowOnce(messageID: "<1@example.com>")

        XCTAssertTrue(policy.isAllowed(messageID: "<1@example.com>", sender: "news@example.com"))
        XCTAssertFalse(policy.isAllowed(messageID: "<2@example.com>", sender: "news@example.com"))
        XCTAssertFalse(policy.isTrusted(sender: "news@example.com"))
    }

    func testAllowOnceIsNotPersisted() {
        let policy = makePolicy()
        policy.allowOnce(messageID: "<1@example.com>")

        let fresh = makePolicy()
        XCTAssertFalse(fresh.isAllowed(messageID: "<1@example.com>", sender: "news@example.com"))
    }

    // MARK: – Dauerhafte Freigabe

    func testAllowAlwaysMatchesNormalisedSender() {
        let policy = makePolicy()
        policy.allowAlways(sender: "  News@Example.COM ")

        XCTAssertTrue(policy.isTrusted(sender: "news@example.com"))
        XCTAssertTrue(policy.isAllowed(messageID: "<irgendwas>", sender: "NEWS@example.com"))
        XCTAssertEqual(policy.sortedTrustedSenders, ["news@example.com"])
    }

    func testAllowAlwaysIsPersisted() {
        let policy = makePolicy()
        policy.allowAlways(sender: "news@example.com")

        let fresh = makePolicy()
        XCTAssertTrue(fresh.isTrusted(sender: "news@example.com"))
        XCTAssertEqual(defaults.stringArray(forKey: RemoteContentPolicy.defaultsKey),
                       ["news@example.com"])
    }

    func testEmptySenderIsIgnored() {
        let policy = makePolicy()
        policy.allowAlways(sender: "   ")

        XCTAssertTrue(policy.sortedTrustedSenders.isEmpty)
        XCTAssertNil(defaults.stringArray(forKey: RemoteContentPolicy.defaultsKey))
    }

    func testDuplicateAllowAlwaysStoresOneEntry() {
        let policy = makePolicy()
        policy.allowAlways(sender: "news@example.com")
        policy.allowAlways(sender: "NEWS@example.com")

        XCTAssertEqual(policy.sortedTrustedSenders, ["news@example.com"])
    }

    // MARK: – Widerruf

    func testRevokeRemovesSenderAndPersists() {
        let policy = makePolicy()
        policy.allowAlways(sender: "a@example.com")
        policy.allowAlways(sender: "b@example.com")
        policy.revoke(sender: "A@example.com")

        XCTAssertFalse(policy.isTrusted(sender: "a@example.com"))
        XCTAssertTrue(policy.isTrusted(sender: "b@example.com"))
        XCTAssertEqual(makePolicy().sortedTrustedSenders, ["b@example.com"])
    }

    func testRevokeAllClearsSendersAndSessionAllows() {
        let policy = makePolicy()
        policy.allowAlways(sender: "a@example.com")
        policy.allowOnce(messageID: "<1@example.com>")

        policy.revokeAll()

        XCTAssertTrue(policy.sortedTrustedSenders.isEmpty)
        XCTAssertFalse(policy.isAllowed(messageID: "<1@example.com>", sender: "a@example.com"))
        XCTAssertTrue(makePolicy().sortedTrustedSenders.isEmpty)
    }

    // MARK: – Freigabe pro Absender, nicht pro Domain

    func testTrustIsPerAddressNotPerDomain() {
        let policy = makePolicy()
        policy.allowAlways(sender: "news@example.com")

        XCTAssertTrue(policy.isTrusted(sender: "news@example.com"))
        XCTAssertFalse(policy.isTrusted(sender: "info@example.com"))
        XCTAssertFalse(policy.isTrusted(sender: "evil@sub.example.com"))
    }
}
