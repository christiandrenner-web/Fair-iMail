// HTMLMessageView.swift
//
// D2, Stufe 2+3: HTML-Anzeige in einer WKWebView.
//
// Sicherheitsmodell (Stufe 2, `allowRemote == false`):
//   • JavaScript ist deaktiviert.
//   • Nicht-persistenter Datenspeicher (nichts bleibt zwischen Mails/Starts).
//   • Content-Rule-Liste blockiert jede http(s)-Anfrage (Bilder, CSS, Fonts …).
//   • Jede Navigation außer dem initialen loadHTMLString wird abgebrochen.
//   • Link-Klicks werden an SwiftUI gemeldet und erst nach Bestätigung
//     extern geöffnet.
//   • Das HTML wurde vorher durch HTMLSanitizer geschickt.
//
// Stufe 3 (`allowRemote == true`) fällt nur die Content-Rule-Liste weg; alles
// andere bleibt. Der Nutzer hat dem Laden externer Inhalte für diese Mail oder
// diesen Absender ausdrücklich zugestimmt (siehe RemoteContentPolicy).
//
// Schlägt das Kompilieren der Regel-Liste fehl, wird bewusst *nicht*
// gerendert (fail-closed) und `failed` auf true gesetzt.

import SwiftUI
import WebKit

struct HTMLMessageView: UIViewRepresentable {

    let html: String
    /// Stufe 3: externe Inhalte für diese Mail/Absender freigegeben.
    var allowRemote: Bool = false
    @Binding var contentHeight: CGFloat
    @Binding var failed: Bool
    let onExternalLink: (URL) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(contentHeight: $contentHeight, failed: $failed,
                    allowRemote: allowRemote, onExternalLink: onExternalLink)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        configuration.suppressesIncrementalRendering = true
        configuration.allowsInlineMediaPlayback = false
        configuration.mediaTypesRequiringUserActionForPlayback = .all

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never

        context.coordinator.attach(to: webView)
        context.coordinator.load(HTMLSanitizer.sanitize(html, allowRemoteResources: allowRemote))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        coordinator.detach()
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
    }

    // MARK: – Content-Rule-Liste

    /// Blockiert jede ausgehende http(s)-Anfrage. Absichtlich ohne
    /// Ausnahmen: Bilder aus der Mail selbst kommen über cid: und werden
    /// nicht vom Netzwerk geladen.
    ///
    /// Wird nur in Stufe 2 installiert. In Stufe 3 (`allowRemote`) verzichtet
    /// die App bewusst auf die Regel-Liste.
    static let contentBlockerJSON = """
    [{
      "trigger": {
        "url-filter": "^https?://",
        "resource-type": ["document", "image", "style-sheet", "script",
                          "font", "media", "raw", "svg-document", "popup"]
      },
      "action": { "type": "block" }
    }]
    """

    static let contentBlockerIdentifier = "io.imailsecure.block-remote"

    // MARK: – Coordinator

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        private let contentHeight: Binding<CGFloat>
        private let failed: Binding<Bool>
        private let allowRemote: Bool
        private let onExternalLink: (URL) -> Void

        private weak var webView: WKWebView?
        private var heightObservation: NSKeyValueObservation?
        private var isInstallingRules = false
        private var didAllowInitialLoad = false

        init(contentHeight: Binding<CGFloat>, failed: Binding<Bool>,
             allowRemote: Bool, onExternalLink: @escaping (URL) -> Void) {
            self.contentHeight = contentHeight
            self.failed = failed
            self.allowRemote = allowRemote
            self.onExternalLink = onExternalLink
        }

        func attach(to webView: WKWebView) {
            self.webView = webView
            heightObservation = webView.scrollView.observe(\.contentSize, options: [.new]) {
                [weak self] scrollView, _ in
                let height = scrollView.contentSize.height
                guard height > 0, let self else { return }
                DispatchQueue.main.async {
                    if abs(self.contentHeight.wrappedValue - height) > 1 {
                        self.contentHeight.wrappedValue = height
                    }
                }
            }
        }

        func detach() {
            heightObservation?.invalidate()
            heightObservation = nil
            webView = nil
        }

        /// Kompiliert zuerst die Regel-Liste und lädt erst danach das HTML.
        /// In Stufe 3 entfällt die Regel-Liste — der Nutzer hat zugestimmt.
        func load(_ html: String) {
            guard !isInstallingRules, let webView else { return }
            isInstallingRules = true

            guard !allowRemote else {
                webView.loadHTMLString(html, baseURL: nil)
                return
            }

            WKContentRuleListStore.default().compileContentRuleList(
                forIdentifier: HTMLMessageView.contentBlockerIdentifier,
                encodedContentRuleList: HTMLMessageView.contentBlockerJSON
            ) { [weak self, weak webView] list, _ in
                DispatchQueue.main.async {
                    guard let self, let webView else { return }
                    guard let list else {
                        // Fail-closed: lieber kein HTML als ungeprüftes HTML.
                        self.failed.wrappedValue = true
                        return
                    }
                    webView.configuration.userContentController.add(list)
                    webView.loadHTMLString(html, baseURL: nil)
                }
            }
        }

        // MARK: Navigation

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Erste Navigation ist das loadHTMLString aus load(_:).
            if !didAllowInitialLoad {
                didAllowInitialLoad = true
                decisionHandler(.allow)
                return
            }

            decisionHandler(.cancel)

            guard navigationAction.navigationType == .linkActivated,
                  let url = navigationAction.request.url else { return }
            onExternalLink(url)
        }

        /// target="_blank" und window.open: nie ein neues WebView.
        func webView(_ webView: WKWebView,
                     createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let url = navigationAction.request.url {
                onExternalLink(url)
            }
            return nil
        }

        /// Keine JS-Dialoge (JS ist aus, aber defense in depth).
        func webView(_ webView: WKWebView,
                     runJavaScriptAlertPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo,
                     completionHandler: @escaping () -> Void) {
            completionHandler()
        }

        func webView(_ webView: WKWebView,
                     runJavaScriptConfirmPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo,
                     completionHandler: @escaping (Bool) -> Void) {
            completionHandler(false)
        }
    }
}
