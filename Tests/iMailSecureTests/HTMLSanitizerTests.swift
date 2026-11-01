// HTMLSanitizerTests.swift
//
// D2 – Tests für die zweite Verteidigungslinie. Die erste Linie
// (Content-Rule-Liste, JS aus, non-persistent) sitzt in WebKit und ist
// hier nur über ihre Konfiguration prüfbar.

import XCTest
@testable import iMailSecure

final class HTMLSanitizerTests: XCTestCase {

    private func sanitize(_ html: String) -> String {
        HTMLSanitizer.sanitize(html)
    }

    func testScriptBlockIsRemoved() {
        let out = sanitize("<p>Hallo</p><script>alert('x')</script><p>Welt</p>")
        XCTAssertFalse(out.lowercased().contains("<script"))
        XCTAssertFalse(out.contains("alert"))
        XCTAssertTrue(out.contains("Hallo"))
        XCTAssertTrue(out.contains("Welt"))
    }

    func testEventHandlersAreRemoved() {
        let out = sanitize(#"<img src="cid:logo" onerror="fetch('https://evil.example')">"#)
        XCTAssertFalse(out.lowercased().contains("onerror"))
        XCTAssertFalse(out.contains("evil.example"))
    }

    func testBaseTagIsRemoved() {
        let out = sanitize(#"<base href="https://evil.example/"><a href="x">Link</a>"#)
        XCTAssertFalse(out.lowercased().contains("<base"))
        XCTAssertFalse(out.contains("evil.example"))
    }

    func testRemoteImageSourceIsDropped() {
        let out = sanitize(#"<img src="https://tracker.example/pixel.gif" width="1" height="1">"#)
        XCTAssertFalse(out.contains("tracker.example"))
        XCTAssertFalse(out.lowercased().contains("src="))
    }

    func testLocalImageSourcesSurvive() {
        let cid = sanitize(#"<img src="cid:logo@example">"#)
        XCTAssertTrue(cid.contains("src=\"cid:logo@example\""))

        let data = sanitize(#"<img src="data:image/png;base64,iVBORw0KGgo=">"#)
        XCTAssertTrue(data.contains("data:image/png"))
    }

    func testSvgDataURLIsNotTreatedAsImage() {
        let out = sanitize(#"<img src="data:image/svg+xml;base64,PHN2Zz4=">"#)
        XCTAssertFalse(out.contains("data:image/svg"))
    }

    func testIframeAndFormAreRemoved() {
        let out = sanitize(#"<iframe src="https://evil.example"></iframe><form action="https://evil.example"><input name="x"></form>"#)
        XCTAssertFalse(out.lowercased().contains("<iframe"))
        XCTAssertFalse(out.lowercased().contains("<form"))
        XCTAssertFalse(out.contains("evil.example"))
    }

    func testJavaScriptHrefIsNeutralised() {
        let out = sanitize(#"<a href="javascript:alert(1)">klick</a>"#)
        XCTAssertFalse(out.lowercased().contains("javascript:"))
    }

    func testMetaRefreshIsRemoved() {
        let out = sanitize(#"<meta http-equiv="refresh" content="0;url=https://evil.example">"#)
        XCTAssertFalse(out.lowercased().contains("http-equiv"))
        XCTAssertFalse(out.contains("evil.example"))
    }

    func testCssUrlAndImportAreRemoved() {
        let out = sanitize(#"<style>@import url("https://evil.example/a.css"); body { background: url(https://tracker.example/p.gif); }</style>"#)
        XCTAssertFalse(out.contains("evil.example"))
        XCTAssertFalse(out.contains("tracker.example"))
        XCTAssertFalse(out.lowercased().contains("@import"))
    }

    func testDocumentWrapperIsAdded() {
        let out = sanitize("<p>Text</p>")
        XCTAssertTrue(out.hasPrefix("<!doctype html>"))
        XCTAssertTrue(out.contains("<meta charset=\"utf-8\">"))
        XCTAssertTrue(out.contains("<p>Text</p>"))
    }

    func testContentBlockerBlocksAllHTTP() {
        let json = HTMLMessageView.contentBlockerJSON
        XCTAssertTrue(json.contains("^https?://"))
        XCTAssertTrue(json.contains("\"type\": \"block\""))
    }

    func testRealisticMailLeavesNoResourceLoader() {
        let html = """
        <html><head><base href="https://evil.example/">
        <link rel="stylesheet" href="https://evil.example/a.css">
        <meta http-equiv="refresh" content="0;url=https://evil.example"></head>
        <body background="https://evil.example/bg.png">
        <table background='https://evil.example/t.png'><tr><td>
        <a href="https://shop.example/item?utm_source=mail" ping="https://tracker.example/p">Angebot</a>
        <img src=https://tracker.example/open.gif width=1 height=1>
        <img srcset="https://tracker.example/2x.png 2x" src="cid:logo">
        <video poster="https://tracker.example/poster.jpg"><source src="https://tracker.example/v.mp4"></video>
        </td></tr></table></body></html>
        """

        let out = sanitize(html)
        for tracker in ["tracker.example", "evil.example", "srcset", "ping=", "background=", "poster="] {
            XCTAssertFalse(out.lowercased().contains(tracker), "Reste gefunden: \(tracker)")
        }
        // Der sichtbare Link bleibt erhalten (Ziel wird erst beim Klick bestätigt).
        XCTAssertTrue(out.contains("shop.example"))
    }
}
