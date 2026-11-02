// EntitlementTests.swift
//
// Free/Pro-Trennung ohne StoreKit: Die Entscheidung ist eine reine Funktion,
// damit sie ohne Netzwerk, Sandbox-Konto oder Simulator-Zustand prüfbar ist.

import XCTest
@testable import iMailSecure

final class EntitlementTests: XCTestCase {

    // MARK: – Ableitung aus Produkten

    func testNoProductsMeansFree() {
        XCTAssertEqual(Entitlement.tier(forActiveProductIDs: []), .free)
    }

    func testMonthlySubscriptionMeansPro() {
        XCTAssertEqual(Entitlement.tier(forActiveProductIDs: [SubscriptionProduct.monthly]), .pro)
    }

    func testYearlySubscriptionMeansPro() {
        XCTAssertEqual(Entitlement.tier(forActiveProductIDs: [SubscriptionProduct.yearly]), .pro)
    }

    func testBothSubscriptionsMeanPro() {
        XCTAssertEqual(
            Entitlement.tier(forActiveProductIDs: SubscriptionProduct.allIDs),
            .pro)
    }

    /// Ein fremdes oder unbekanntes Produkt darf nichts freischalten.
    func testUnknownProductDoesNotUnlockPro() {
        XCTAssertEqual(
            Entitlement.tier(forActiveProductIDs: ["com.example.other.pro"]),
            .free)
    }

    func testKnownProductAlongsideUnknownStillUnlocks() {
        XCTAssertEqual(
            Entitlement.tier(forActiveProductIDs: ["com.example.other.pro",
                                                    SubscriptionProduct.monthly]),
            .pro)
    }

    // MARK: – Kontolimit

    func testFreeTierAllowsOneAccount() {
        XCTAssertEqual(Entitlement.accountLimit(for: .free), 1)
    }

    func testProTierHasNoAccountLimit() {
        XCTAssertNil(Entitlement.accountLimit(for: .pro))
    }

    // MARK: – Feature-Tabelle

    func testMultipleAccountsRequiresPro() {
        XCTAssertEqual(Feature.multipleAccounts.requiredTier, .pro)
        XCTAssertFalse(Feature.multipleAccounts.isAvailable(in: .free))
        XCTAssertTrue(Feature.multipleAccounts.isAvailable(in: .pro))
    }

    func testEveryFeatureHasTitleAndDetail() {
        for feature in Feature.allCases {
            XCTAssertFalse(feature.title.isEmpty, "Titel fehlt: \(feature.rawValue)")
            XCTAssertFalse(feature.detail.isEmpty, "Beschreibung fehlt: \(feature.rawValue)")
            XCTAssertFalse(feature.icon.isEmpty, "Icon fehlt: \(feature.rawValue)")
        }
    }

    func testTierOrdering() {
        XCTAssertTrue(Tier.free < Tier.pro)
        XCTAssertFalse(Tier.pro < Tier.free)
        XCTAssertTrue(Tier.pro <= Tier.pro)
    }

    // MARK: – Manager-Abfragen

    @MainActor
    func testFreeManagerCannotAddSecondAccount() {
        let manager = SubscriptionManager(previewTier: .free)

        XCTAssertFalse(manager.isPro)
        XCTAssertEqual(manager.accountLimit, 1)
        XCTAssertTrue(manager.canAddAccount(currentCount: 0))
        XCTAssertFalse(manager.canAddAccount(currentCount: 1))
        XCTAssertFalse(manager.canUse(.multipleAccounts))
    }

    @MainActor
    func testProManagerCanAddAccounts() {
        let manager = SubscriptionManager(previewTier: .pro)

        XCTAssertTrue(manager.isPro)
        XCTAssertNil(manager.accountLimit)
        XCTAssertTrue(manager.canAddAccount(currentCount: 1))
        XCTAssertTrue(manager.canAddAccount(currentCount: 12))
        XCTAssertTrue(manager.canUse(.multipleAccounts))
    }

    // MARK: – Produktnamen

    func testPeriodLabels() {
        XCTAssertEqual(SubscriptionProduct.periodLabel(for: SubscriptionProduct.monthly), "Monat")
        XCTAssertEqual(SubscriptionProduct.periodLabel(for: SubscriptionProduct.yearly), "Jahr")
        XCTAssertEqual(SubscriptionProduct.periodLabel(for: "unbekannt"), "")
    }
}
