// StoreKitPurchaseTests.swift
//
// Kaufpfad ohne App-Store-Verbindung: `SKTestSession` lädt die
// Testkonfiguration `iMailSecure.storekit`, kauft ein Produkt und die App
// muss daraus Pro ableiten.
//
// Warum hier und nicht in einem UI-Test: `xcodebuild` übergibt die
// StoreKit-Testkonfiguration im iOS-26-Simulator nicht an die App unter dem
// UI-Test (Produkte bleiben leer). Im App-Prozess funktioniert sie.
//
// Diese Tests sind opt-in. Im iOS-26-Simulator antwortet `storekitd` trotz
// `SKTestSession` über die Produktions-API (`amp-api.sandbox.apple.com`) und
// liefert weder Produkte noch Käufe (`notEntitled`). Das ist ein Fehler der
// Laufzeitumgebung, kein Fehler der App — eine rote Suite würde davon
// ablenken. Auf einem echten Gerät oder in Xcode mit aktiver Konfiguration:
//
//   IMAIL_STOREKIT_TESTS=1 xcodebuild test …

import XCTest
import StoreKit
import StoreKitTest
@testable import iMailSecure

@MainActor
final class StoreKitPurchaseTests: XCTestCase {

    private var session: SKTestSession!

    /// Der Teststore ist im iOS-26-Simulator unbrauchbar. Ohne ausdrückliche
    /// Freigabe werden die Tests übersprungen, nicht rot.
    private static var storeKitEnabled: Bool {
        ProcessInfo.processInfo.environment["IMAIL_STOREKIT_TESTS"] == "1"
    }

    override func setUpWithError() throws {
        try XCTSkipUnless(Self.storeKitEnabled,
                          "IMAIL_STOREKIT_TESTS=1 nicht gesetzt")

        session = try SKTestSession(configurationFileNamed: "iMailSecure")
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
    }

    override func tearDown() {
        session?.clearTransactions()
        session = nil
    }

    func testProductsLoadFromConfiguration() async throws {
        let products = try await Product.products(for: Array(SubscriptionProduct.allIDs))

        XCTAssertEqual(Set(products.map(\.id)), SubscriptionProduct.allIDs)
        XCTAssertEqual(products.count, 3)

        let monthly = try XCTUnwrap(products.first { $0.id == SubscriptionProduct.monthly })
        XCTAssertNotNil(monthly.subscription?.introductoryOffer,
                        "7-Tage-Testphase fehlt in der Konfiguration")
    }

    func testMonthlyPurchaseUnlocksPro() async throws {
        _ = try await session.buyProduct(identifier: SubscriptionProduct.monthly)

        let manager = SubscriptionManager(startImmediately: false)
        await manager.refreshEntitlements()

        XCTAssertEqual(manager.tier, .pro)
        XCTAssertTrue(manager.isPro)
        XCTAssertNil(manager.accountLimit)
        XCTAssertTrue(manager.canUse(.folderManagement))
    }

    func testLifetimePurchaseUnlocksProForGood() async throws {
        _ = try await session.buyProduct(identifier: SubscriptionProduct.lifetime)

        let manager = SubscriptionManager(startImmediately: false)
        await manager.refreshEntitlements()

        XCTAssertEqual(manager.tier, .lifetime)
        XCTAssertTrue(manager.isPro)
        XCTAssertTrue(manager.canUse(.multipleAccounts))
    }

    func testLifetimeWinsOverRunningSubscription() async throws {
        _ = try await session.buyProduct(identifier: SubscriptionProduct.monthly)
        _ = try await session.buyProduct(identifier: SubscriptionProduct.lifetime)

        let manager = SubscriptionManager(startImmediately: false)
        await manager.refreshEntitlements()

        XCTAssertEqual(manager.tier, .lifetime)
    }
}
