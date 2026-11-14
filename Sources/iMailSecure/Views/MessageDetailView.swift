// MessageDetailView.swift
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct MessageDetailView: View {
    @EnvironmentObject var mailStore: MailStore
    @EnvironmentObject var accountStore: AccountStore
    @Environment(\.dismiss) private var dismiss

    let message: EmailMessage

    @State private var showReply          = false
    @State private var showForward        = false

    // MDN-Dialog
    @State private var showMDNDialog      = false
    @State private var mdnSentConfirmed   = false

    // Anhang-Dialog
    @State private var selectedAttachment: EmailAttachment? = nil
    @State private var showAttachmentSheet = false
    @State private var showShareSheet      = false
    @State private var shareItems: [Any]   = []
    @State private var pendingTmpDir: URL? = nil   // wird nach Share-Sheet-Dismiss gelöscht

    // D2 – HTML-Anzeige (Stufe 1: Text, Stufe 2: HTML auf Knopfdruck,
    // Stufe 3: externe Inhalte pro Mail/Absender freigegeben)
    @State private var showHTML            = false
    @State private var htmlContentHeight: CGFloat = 320
    @State private var htmlRenderFailed    = false
    @State private var pendingExternalURL: URL? = nil
    @State private var remoteAllowedForMessage = false
    @State private var showRemoteContentDialog = false
    @ObservedObject private var remotePolicy = RemoteContentPolicy.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                headerSection

                Divider()

                // Lesebestätigungs-Banner (empfangen)
                if message.receiptReceived {
                    MDNBannerView(message: message)
                }

                // MDN-Anfrage-Banner (jemand will von uns eine Bestätigung)
                if message.mdnRequested && !mdnSentConfirmed {
                    mdnRequestBanner
                }

                // Nachrichtentext – Stufe 1: reiner Text
                messageBodySection

                // Anhänge
                if !message.attachments.isEmpty {
                    attachmentsSection
                }
            }
            .padding()
        }
        // Stabiler Anker für die Oberflächentests: Erscheint nur, wenn die
        // Detailansicht wirklich offen ist — unabhängig von der Sprache und
        // davon, ob die Mail eine HTML-Fassung hat.
        .accessibilityIdentifier("detail.root")
        .navigationTitle(message.subject)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarItems }
        .onAppear {
            mailStore.markAsRead(message)
            // MDN-Dialog nach kurzer Verzögerung zeigen
            if message.mdnRequested && !mdnSentConfirmed {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    showMDNDialog = true
                }
            }
        }
        // MDN-Bestätigungs-Dialog
        .confirmationDialog(
            "Lesebestätigung senden?",
            isPresented: $showMDNDialog,
            titleVisibility: .visible
        ) {
            Button("Lesebestätigung senden") {
                sendMDN()
            }
            Button("Ablehnen", role: .destructive) {
                mdnSentConfirmed = true
            }
            Button("Später entscheiden", role: .cancel) { }
        } message: {
            Text("\(message.from.formatted) hat eine Lesebestätigung angefordert.")
        }
        // Anhang-Aktions-Dialog
        .confirmationDialog(
            selectedAttachment.map {
                String(
                    format: String(localized: "detail.attachmentTitle",
                                   defaultValue: "Anhang: %@"),
                    $0.filename
                )
            } ?? String(localized: "detail.attachment",
                        defaultValue: "Anhang"),
            isPresented: $showAttachmentSheet,
            titleVisibility: .visible
        ) {
            if let att = selectedAttachment {
                Button("Ansehen") {
                    viewAttachment(att)
                }
                Button("Herunterladen / Teilen") {
                    shareAttachment(att)
                }
                Button("Ignorieren", role: .cancel) {
                    selectedAttachment = nil
                }
            }
        } message: {
            if let att = selectedAttachment {
                Text("\(att.mimeType) · \(ByteCountFormatter.string(fromByteCount: Int64(att.size), countStyle: .file))")
            }
        }
        // Share Sheet für Anhang-Download
        .sheet(isPresented: $showShareSheet, onDismiss: cleanupTmpDir) {
            ShareSheet(items: shareItems)
        }
        // Antwort-Sheet
        .sheet(isPresented: $showReply) {
            replySheet
        }
        // D2 – externe Links nur nach Bestätigung öffnen
        .confirmationDialog(
            "Link öffnen?",
            isPresented: Binding(
                get: { pendingExternalURL != nil },
                set: { if !$0 { pendingExternalURL = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingExternalURL
        ) { url in
            Button("Im Browser öffnen") {
                UIApplication.shared.open(url.trackingStripped)
                pendingExternalURL = nil
            }
            Button("Abbrechen", role: .cancel) { pendingExternalURL = nil }
        } message: { url in
            Text("\(url.trackingStripped.absoluteString)\n\nDamit verlässt du iMail Secure. Die Zielseite kann deine IP-Adresse und den Zeitpunkt sehen.")
        }
        // D2 Stufe 3 – externe Inhalte nur nach ausdrücklicher Entscheidung
        .confirmationDialog(
            "Externe Inhalte laden?",
            isPresented: $showRemoteContentDialog,
            titleVisibility: .visible
        ) {
            Button("Nur für diese Mail") {
                remoteAllowedForMessage = true
            }
            Button("Immer für \(senderAddress)") {
                remotePolicy.allowAlways(sender: senderAddress)
                remoteAllowedForMessage = true
            }
            Button("Abbrechen", role: .cancel) { }
        } message: {
            Text("Bilder und Stylesheets werden dann von Servern des Absenders geladen. Dabei überträgst du deine IP-Adresse, und der Absender kann erkennen, dass du die Mail geöffnet hast (Tracking-Pixel).")
        }
        .onChange(of: message.id) {
            showHTML = false
            htmlRenderFailed = false
            htmlContentHeight = 320
            remoteAllowedForMessage = false
        }
    }

    // MARK: – Nachrichtentext (D2)

    private var senderAddress: String { message.from.address }

    private var senderIsTrusted: Bool {
        remotePolicy.isTrusted(sender: senderAddress)
    }

    /// Wahr, sobald externe Inhalte für diese Mail **oder** diesen Absender
    /// freigegeben sind.
    private var remoteContentAllowed: Bool {
        remoteAllowedForMessage || senderIsTrusted
    }

    @ViewBuilder
    private var messageBodySection: some View {
        if showHTML, let html = message.htmlBody, !htmlRenderFailed {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: remoteContentAllowed
                          ? "exclamationmark.shield.fill" : "shield.lefthalf.filled")
                        .foregroundStyle(remoteContentAllowed ? .orange : .green)
                    Text(remoteContentAllowed
                         ? String(localized: "detail.html.remoteLoaded",
                                  defaultValue: "HTML-Ansicht · externe Inhalte geladen")
                         : String(localized: "detail.html.remoteBlocked",
                                  defaultValue: "HTML-Ansicht · externe Inhalte blockiert"))
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Nur Text") { showHTML = false }
                        .font(.caption.bold())
                }

                HTMLMessageView(
                    html: html,
                    allowRemote: remoteContentAllowed,
                    contentHeight: $htmlContentHeight,
                    failed: $htmlRenderFailed,
                    onExternalLink: { url in pendingExternalURL = url }
                )
                // Wechsel zwischen blockiert/freigegeben erzeugt eine neue
                // WKWebView — sonst bliebe die alte Content-Rule-Liste aktiv.
                .id(remoteContentAllowed)
                .frame(height: max(160, min(htmlContentHeight, 20_000)))
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                if remoteContentAllowed {
                    if senderIsTrusted {
                        Button {
                            remotePolicy.revoke(sender: senderAddress)
                            remoteAllowedForMessage = false
                        } label: {
                            Label("Freigabe für \(senderAddress) widerrufen",
                                  systemImage: "shield.slash")
                                .font(.caption.bold())
                        }
                        .buttonStyle(.bordered)

                        Text("Dieser Absender ist dauerhaft freigegeben. Widerruf wirkt sofort und für alle künftigen Mails.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Button {
                            remoteAllowedForMessage = false
                        } label: {
                            Label("Externe Inhalte blockieren", systemImage: "shield.slash")
                                .font(.caption.bold())
                        }
                        .buttonStyle(.bordered)

                        Text("Freigabe gilt nur für diese Mail und endet beim Schließen.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Button {
                        showRemoteContentDialog = true
                    } label: {
                        Label("Externe Inhalte laden", systemImage: "arrow.down.circle")
                            .font(.caption.bold())
                    }
                    .buttonStyle(.bordered)

                    Text("Bilder und Stylesheets sind blockiert. Beim Laden erfährt der Absender deine IP-Adresse und dass du die Mail geöffnet hast.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                if htmlRenderFailed {
                    Label("HTML konnte nicht sicher gerendert werden.", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                if message.body.isEmpty {
                    Text("Keine Textfassung vorhanden.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                } else {
                    Text(message.body)
                        .font(.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let html = message.htmlBody, !html.isEmpty {
                    Button {
                        showHTML = true
                    } label: {
                        Label("HTML anzeigen", systemImage: "chevron.left.forwardslash.chevron.right")
                            .font(.subheadline.bold())
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("detail.showHTML")

                    Text("HTML wird erst auf Knopfdruck gerendert – ohne Netzwerkzugriff, ohne JavaScript.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: – MDN-Anfrage-Banner

    private var mdnRequestBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "envelope.badge.clock")
                .foregroundStyle(.orange)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text("Lesebestätigung angefordert")
                    .font(.subheadline.bold())
                Text("Absender möchte wissen, ob du diese Mail gelesen hast.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                showMDNDialog = true
            } label: {
                Text("Entscheiden")
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.orange.opacity(0.15), in: Capsule())
            }
        }
        .padding(12)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange.opacity(0.25), lineWidth: 1))
    }

    // MARK: – Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(message.subject)
                .font(.title3.bold())

            HStack {
                Image(systemName: "person.circle.fill")
                    .foregroundStyle(.secondary)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(message.from.name ?? message.from.address)
                        .font(.subheadline.bold())
                    Text(message.from.address)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(message.date.mailFormatted)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // D5 – Absender-Authentizitätsprüfung
            if let warning = senderWarning {
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
            }

            if !message.to.isEmpty {
                Label(message.to.map(\.formatted).joined(separator: ", "), systemImage: "arrow.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            if !message.cc.isEmpty {
                Label(String(localized: "compose.cc") + ": " + message.cc.map(\.formatted).joined(separator: ", "), systemImage: "arrow.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    // MARK: – Absender-Prüfung (D5)

    /// Gibt eine Warnung zurück wenn Anzeigename eine Domain enthält,
    /// die nicht zur Absender-Domain passt (Spoofing-Indiz).
    private var senderWarning: String? {
        guard let displayName = message.from.name, !displayName.isEmpty else { return nil }
        let lowerName = displayName.lowercased()
        // Warnen wenn Anzeigename eine Domain-ähnliche Zeichenfolge enthält
        guard lowerName.contains(".") && !lowerName.contains(" ") else { return nil }
        // Absender-Domain extrahieren
        guard let senderDomain = message.from.address.emailDomain?.lowercased() else { return nil }
        // Zweite-Ebene-Domain (eTLD) vergleichen
        func etld(_ h: String) -> String {
            let parts = h.components(separatedBy: ".")
            return parts.count >= 2 ? parts.suffix(2).joined(separator: ".") : h
        }
        let nameDomain    = etld(lowerName.components(separatedBy: "/").first ?? lowerName)
        let addressDomain = etld(senderDomain)
        if nameDomain != addressDomain {
            return String(
                format: String(localized: "detail.warning.spoofed",
                               defaultValue: "Anzeigename („%@“) passt nicht zur Absender-Domain (%@)."),
                displayName,
                senderDomain
            )
        }
        return nil
    }

    // MARK: – Anhänge

    private var attachmentsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Anhänge (\(message.attachments.count))", systemImage: "paperclip")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            ForEach(message.attachments) { att in
                Button {
                    selectedAttachment = att
                    showAttachmentSheet = true
                } label: {
                    HStack {
                        Image(systemName: mimeIcon(att.mimeType))
                            .foregroundStyle(Color.accentColor)                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(att.filename)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                            Text("\(att.mimeType) · \(ByteCountFormatter.string(fromByteCount: Int64(att.size), countStyle: .file))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    // MARK: – Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button { showReply = true } label: {
                Image(systemName: "arrowshape.turn.up.left")
            }
            Button { showForward = true } label: {
                Image(systemName: "arrowshape.turn.up.right")
            }
            Button(role: .destructive) {
                mailStore.delete(message)
                dismiss()
            } label: {
                Image(systemName: "trash")
            }
        }
    }

    // MARK: – Antwort-Sheet

    @ViewBuilder
    private var replySheet: some View {
        if let account = accountStore.accounts.first(where: { $0.id == message.accountID })
            ?? accountStore.accounts.first {
            let vm: ComposeViewModel = {
                let v = ComposeViewModel(account: account)
                v.prepareReply(to: message)
                v.onSent = { draft in
                    mailStore.saveSentMessage(draft: draft, account: account)
                }
                return v
            }()
            ComposeView(viewModel: vm)
        }
    }

    // MARK: – Aktionen

    private func sendMDN() {
        guard let engine = accountStore.accounts
            .first(where: { $0.id == message.accountID })
            .map({ EmailAccount?.some($0) }) ?? nil,
              let mdnAddress = message.from.address.isEmpty ? nil : message.from.address
        else { return }

        let syncEngine = MailSyncEngine(account: engine, mailStore: mailStore)
        Task { await syncEngine.sendMDN(for: message, to: mdnAddress) }
        mdnSentConfirmed = true
    }

    private func viewAttachment(_ att: EmailAttachment) {
        // Quick Look via Share Sheet
        shareAttachment(att)
    }

    /// Erstellt einen UUID-Unterordner im Temp-Verzeichnis,
    /// schreibt den Anhang mit .completeFileProtection hinein
    /// und öffnet das Share Sheet. Der Ordner wird nach Dismiss
    /// automatisch gelöscht (cleanupTmpDir).
    private func shareAttachment(_ att: EmailAttachment) {
        // 1. Dateiname sanitizen: nur letztes Pfad-Komponent,
        //    nur erlaubte Zeichen (alphanumerisch + . - _)
        let rawName  = URL(fileURLWithPath: att.filename).lastPathComponent
        let safeName = rawName
            .components(separatedBy:
                CharacterSet.alphanumerics
                    .union(CharacterSet(charactersIn: ".-_"))
                    .inverted)
            .joined(separator: "_")
        let fileName = safeName.isEmpty
            ? String(localized: "detail.attachment", defaultValue: "Anhang")
            : safeName

        // 2. Eigener UUID-Unterordner verhindert Pfad-Kollisionen
        let tmpBase = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let tmpURL  = tmpBase.appendingPathComponent(fileName)

        do {
            try FileManager.default.createDirectory(
                at: tmpBase, withIntermediateDirectories: true)
            // .completeFileProtection: verschlüsselt wenn Gerät gesperrt
            try att.data.write(to: tmpURL,
                options: [.atomic, .completeFileProtection])
            pendingTmpDir = tmpBase
            shareItems    = [tmpURL]
            showShareSheet = true
        } catch {
            // Fallback: rohe Daten teilen (kein Dateipfad)
            shareItems    = [att.data]
            showShareSheet = true
        }
    }

    /// Temp-Ordner nach Schließen des Share Sheets aufräumen
    private func cleanupTmpDir() {
        guard let dir = pendingTmpDir else { return }
        try? FileManager.default.removeItem(at: dir)
        pendingTmpDir = nil
    }

    private func mimeIcon(_ mime: String) -> String {
        if mime.hasPrefix("image")   { return "photo" }
        if mime.hasPrefix("video")   { return "film" }
        if mime.contains("pdf")      { return "doc.richtext" }
        if mime.contains("zip") || mime.contains("compressed") { return "archivebox" }
        if mime.contains("word") || mime.contains("document")  { return "doc.text" }
        if mime.contains("sheet") || mime.contains("excel")    { return "tablecells" }
        return "doc"
    }
}

// MARK: – Share Sheet (UIActivityViewController)

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}
