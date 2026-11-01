// MessageDetailView.swift
import SwiftUI
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

                // Nachrichtentext
                Text(message.body)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Anhänge
                if !message.attachments.isEmpty {
                    attachmentsSection
                }
            }
            .padding()
        }
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
            selectedAttachment.map { "Anhang: \($0.filename)" } ?? "Anhang",
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
                Label("CC: " + message.cc.map(\.formatted).joined(separator: ", "), systemImage: "arrow.right")
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
            return "Anzeigename („\(displayName)“) passt nicht zur Absender-Domain (\(senderDomain))."
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
        let fileName = safeName.isEmpty ? "Anhang" : safeName

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
