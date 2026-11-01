// iMailSecureTests.swift
import XCTest
@testable import iMailSecure

final class EmailHeaderBuilderTests: XCTestCase {

    var testAccount: EmailAccount!

    override func setUp() {
        super.setUp()
        testAccount = EmailAccount(
            displayName: "Test User",
            email: "test@example.com",
            imapHost: "imap.example.com",
            imapPort: 993,
            smtpHost: "smtp.example.com",
            smtpPort: 587,
            username: "test@example.com"
        )
    }

    func testStandardHeaders() {
        let draft = EmailDraft()
        let headers = EmailHeaderBuilder.buildHeaders(from: testAccount, draft: draft)

        XCTAssertNotNil(headers["From"])
        XCTAssertNotNil(headers["Date"])
        XCTAssertNotNil(headers["Message-ID"])
        XCTAssertEqual(headers["MIME-Version"], "1.0")
        XCTAssertEqual(headers["User-Agent"], "iMailSecure/1.0 (iOS)")
    }

    func testMDNHeadersPresent() {
        var draft = EmailDraft()
        draft.requestMDN = true
        let headers = EmailHeaderBuilder.buildHeaders(from: testAccount, draft: draft)

        XCTAssertEqual(headers["Disposition-Notification-To"], testAccount.email)
        XCTAssertNotNil(headers["Disposition-Notification-Options"])
    }

    func testMDNHeadersAbsent() {
        var draft = EmailDraft()
        draft.requestMDN = false
        let headers = EmailHeaderBuilder.buildHeaders(from: testAccount, draft: draft)

        XCTAssertNil(headers["Disposition-Notification-To"])
    }

    func testReceiptHeader() {
        var draft = EmailDraft()
        draft.requestReceipt = true
        let headers = EmailHeaderBuilder.buildHeaders(from: testAccount, draft: draft)

        XCTAssertEqual(headers["Return-Receipt-To"], testAccount.email)
    }

    func testReceiptHeaderAbsent() {
        var draft = EmailDraft()
        draft.requestReceipt = false
        let headers = EmailHeaderBuilder.buildHeaders(from: testAccount, draft: draft)

        XCTAssertNil(headers["Return-Receipt-To"])
    }

    func testMessageIDFormat() {
        let draft = EmailDraft()
        let headers = EmailHeaderBuilder.buildHeaders(from: testAccount, draft: draft)
        let messageID = headers["Message-ID"] ?? ""

        XCTAssertTrue(messageID.hasPrefix("<"))
        XCTAssertTrue(messageID.hasSuffix(">"))
        XCTAssertTrue(messageID.contains("@example.com"))
    }
}

final class MDNProcessorTests: XCTestCase {

    func testValidMDN() {
        let msg = EmailMessage(
            id: "<mdn-001@test.local>",
            uid: 99,
            accountID: UUID(),
            from: EmailAddress(address: "recipient@example.com"),
            to: [EmailAddress(address: "sender@example.com")],
            subject: "Read: My Subject",
            date: Date(),
            body: """
            Original-Message-ID: <original-001@example.com>
            Disposition: automatic-action/MDN-sent-automatically; displayed
            """
        )

        let result = MDNProcessor.processMDN(message: msg)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.dispositionAction, "displayed")
        XCTAssertEqual(result?.originalMessageID, "<original-001@example.com>")
    }

    func testNonMDNMessage() {
        let msg = EmailMessage(
            id: "<regular-001@test.local>",
            uid: 1,
            accountID: UUID(),
            from: EmailAddress(address: "bob@example.com"),
            to: [EmailAddress(address: "alice@example.com")],
            subject: "Hallo!",
            date: Date(),
            body: "Eine normale E-Mail ohne MDN."
        )

        let result = MDNProcessor.processMDN(message: msg)
        XCTAssertNil(result)
    }
}

final class EmailDraftTests: XCTestCase {

    func testAddressParsing() {
        var draft = EmailDraft()
        draft.toText = "alice@example.com, bob@example.com"
        XCTAssertEqual(draft.to.count, 2)
        XCTAssertEqual(draft.to[0].address, "alice@example.com")
        XCTAssertEqual(draft.to[1].address, "bob@example.com")
    }

    func testEmptyAddressParsing() {
        let draft = EmailDraft()
        XCTAssertEqual(draft.to.count, 0)
        XCTAssertEqual(draft.cc.count, 0)
        XCTAssertEqual(draft.bcc.count, 0)
    }
}
