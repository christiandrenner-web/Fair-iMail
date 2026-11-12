// Probe.swift
//
// End-to-End-Test gegen einen echten IMAP-Server mit derselben
// SwiftMail-Revision, die die App verwendet (1.16.0).
//
// Geprüft wird, was die App tatsächlich tut:
//   • Verbindung, TLS und Anmeldung
//   • Ordnerliste, Rollenerkennung über MailFolder.swift (echter App-Code)
//   • Nachrichten laden wie MailSyncEngine.fetchMessages
//   • Ordner anlegen, umbenennen (verschachtelt), löschen
//   • APPEND, MOVE in den Papierkorb, UID EXPUNGE
//
// Zugangsdaten kommen aus einer Datei oder aus der Umgebung — nie aus
// Argumenten, damit sie nicht in der Prozessliste stehen:
//
//   IMAP_HOST / IMAP_PORT / IMAP_USER / IMAP_PASSWORD
//   oder --env <pfad> mit KEY=VALUE-Zeilen
//
// Aufruf:
//   swift run IMAPProbe            # nur lesen
//   swift run IMAPProbe --write    # zusätzlich Schreibtest
//
// Der Schreibtest legt ausschließlich Ordner mit dem Präfix "iMail-Test-" an,
// schreibt eine eigene Testnachricht und räumt beides wieder ab. Vorhandene
// Ordner und Nachrichten werden nicht angefasst.

import Foundation
import SwiftMail

// MARK: – Ausgabe

private func say(_ text: String = "") {
    print(text)
}

private func head(_ text: String) {
    say("")
    say("── \(text) " + String(repeating: "─", count: max(0, 60 - text.count)))
}

private var failures: [String] = []

private func check(_ condition: Bool, _ label: String, detail: String = "") {
    if condition {
        say("  ✅ \(label)")
    } else {
        say("  ❌ \(label)\(detail.isEmpty ? "" : " — \(detail)")")
        failures.append(label)
    }
}

private func statusCount(_ server: IMAPServer, _ mailbox: String) async -> Int {
    ((try? await server.mailboxStatus(mailbox))?.messageCount) ?? -1
}

private func normalizeCapability(_ value: String) -> String {
    value.uppercased().filter { $0.isLetter || $0.isNumber }
}

private func capabilities(of server: IMAPServer) async throws -> Set<String> {
    Set(try await server.fetchCapabilities().map { normalizeCapability($0.name) })
}

// MARK: – Zugangsdaten

struct Credentials {
    let host: String
    let port: Int
    let user: String
    let password: String

    static func load() throws -> Credentials {
        var values: [String: String] = [:]

        let arguments = CommandLine.arguments
        var envPath = NSHomeDirectory() + "/.config/imailsecure/imap-test.env"
        if let idx = arguments.firstIndex(of: "--env"), idx + 1 < arguments.count {
            envPath = (arguments[idx + 1] as NSString).expandingTildeInPath
        }

        if let contents = try? String(contentsOfFile: envPath, encoding: .utf8) {
            for rawLine in contents.split(separator: "\n") {
                let line = rawLine.trimmingCharacters(in: .whitespaces)
                guard !line.isEmpty, !line.hasPrefix("#"),
                      let separator = line.firstIndex(of: "=") else { continue }
                let key = String(line[line.startIndex..<separator])
                    .trimmingCharacters(in: .whitespaces)
                var value = String(line[line.index(after: separator)...])
                    .trimmingCharacters(in: .whitespaces)
                if value.count >= 2, value.hasPrefix("\""), value.hasSuffix("\"") {
                    value = String(value.dropFirst().dropLast())
                }
                values[key] = value
            }
        }

        func value(_ key: String) -> String? {
            let fromEnvironment = ProcessInfo.processInfo.environment[key]
            if let fromEnvironment, !fromEnvironment.isEmpty { return fromEnvironment }
            return values[key]
        }

        guard let user = value("IMAP_USER"), !user.isEmpty else {
            throw ProbeError.missingCredentials(envPath)
        }
        guard let password = value("IMAP_PASSWORD"), !password.isEmpty else {
            throw ProbeError.missingCredentials(envPath)
        }

        return Credentials(
            host: value("IMAP_HOST") ?? "imap.gmx.net",
            port: Int(value("IMAP_PORT") ?? "993") ?? 993,
            user: user,
            password: password
        )
    }
}

private enum ProbeError: LocalizedError {
    case missingCredentials(String)
    case unexpected(String)

    var errorDescription: String? {
        switch self {
        case .missingCredentials(let path):
            return "Zugangsdaten fehlen. Erwartet IMAP_USER und IMAP_PASSWORD in \(path) "
                + "oder als Umgebungsvariablen."
        case .unexpected(let text):
            return text
        }
    }
}

// MARK: – Testnachricht

private let sampleMessageID = "<probe-\(UUID().uuidString)@imailsecure.invalid>"

private func sampleMessage(user: String) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"

    return [
        "From: iMail Secure Test <\(user)>",
        "To: iMail Secure Test <\(user)>",
        "Subject: iMail Secure Ordnertest",
        "Date: \(formatter.string(from: Date()))",
        "Message-ID: \(sampleMessageID)",
        "MIME-Version: 1.0",
        "Content-Type: text/plain; charset=utf-8",
        "",
        "Diese Nachricht wurde vom Ordnertest erzeugt und danach wieder entfernt.",
        ""
    ].joined(separator: "\r\n")
}

// MARK: – Ablauf

@main
struct IMAPProbe {
    static func main() async {
        do {
            try await run()
        } catch {
            say("")
            say("ABBRUCH: \(error.localizedDescription)")
            if !failures.isEmpty {
                say("Fehlgeschlagene Prüfungen: \(failures.joined(separator: ", "))")
            }
            exit(1)
        }

        say("")
        if failures.isEmpty {
            say("ERGEBNIS: alle Prüfungen bestanden")
            exit(0)
        } else {
            say("ERGEBNIS: \(failures.count) Prüfung(en) fehlgeschlagen:")
            for failure in failures { say("  • \(failure)") }
            exit(1)
        }
    }

    static func run() async throws {
        let credentials = try Credentials.load()
        let writeTest = CommandLine.arguments.contains("--write")

        say("iMail Secure — IMAP-End-to-End-Test")
        say("Server: \(credentials.host):\(credentials.port)")
        say("Konto:  \(credentials.user)")
        say("Modus:  \(writeTest ? "lesen + schreiben (nur Testordner)" : "nur lesen")")

        let server = IMAPServer(
            host: credentials.host,
            port: credentials.port,
            transportSecurity: credentials.port == 143 ? .startTLS : .implicitTLS
        )

        // MARK: Verbindung
        head("Verbindung und Anmeldung")
        try await server.connect()
        say("  ✅ TLS-Verbindung aufgebaut")

        try await server.login(username: credentials.user, password: credentials.password)
        say("  ✅ Anmeldung akzeptiert")

        let caps = try await capabilities(of: server)
        say("  Fähigkeiten: \(caps.sorted().joined(separator: " "))")
        check(caps.contains("MOVE"), "MOVE vorhanden (Löschen per MOVE)")
        check(caps.contains("UIDPLUS"), "UIDPLUS vorhanden (UID EXPUNGE)")
        check(caps.contains("SPECIALUSE") || caps.contains("LISTEXTENDED"),
              "Special-Use oder LIST-EXTENDED vorhanden")

        // MARK: Ordner
        head("Ordnerliste vom Server")
        let rawFolders = try await server.listMailboxes(wildcard: "*")
        say("  \(rawFolders.count) Einträge")

        let folders = rawFolders.map { MailFolder(info: $0) }
        let specialUseNames = Set(((try? await server.listSpecialUseMailboxes()) ?? []).map(\.name))

        say("")
        say("  Rolle       Servername                          Trenner  Special-Use")
        for folder in folders.sorted(by: { $0.name < $1.name }) {
            let role = folder.role.rawValue.padding(toLength: 11, withPad: " ", startingAt: 0)
            let rawName = folder.name.count > 34
                ? String(folder.name.prefix(31)) + "..."
                : folder.name
            let name = rawName.padding(toLength: 35, withPad: " ", startingAt: 0)
            let delimiter = (folder.delimiter ?? "—")
                .padding(toLength: 8, withPad: " ", startingAt: 0)
            let flagged = specialUseNames.contains(folder.name) ? "ja" : ""
            say("  \(role) \(name) \(delimiter) \(flagged)")
        }

        let visible = MailFolder.sorted(folders)
        say("")
        say("  Sichtbar in der App: \(visible.count) Ordner")
        for folder in visible {
            say("    • \(folder.displayName)  [\(folder.role.rawValue), "
                + "\(folder.requiresPro ? "Pro" : "frei")]")
        }

        // MARK: Rollen
        head("Rollenerkennung")
        let inbox = folders.filter { $0.role == .inbox }
        let sent = folders.filter { $0.role == .sent }
        let drafts = folders.filter { $0.role == .drafts }
        let trash = folders.filter { $0.role == .trash }
        let junk = folders.filter { $0.role == .junk }

        check(inbox.count == 1, "genau ein Posteingang",
              detail: inbox.map(\.name).joined(separator: ", "))
        check(!sent.isEmpty, "Gesendet erkannt")
        check(!drafts.isEmpty, "Entwürfe erkannt")
        check(!trash.isEmpty, "Papierkorb erkannt")
        check(!junk.isEmpty, "Spam erkannt")

        let systemCount = folders.filter(\.role.isSystem).count
        say("  Systemordner: \(systemCount) von \(folders.count) (bleiben kostenlos)")

        // MARK: Lesen
        head("Posteingang lesen (wie MailSyncEngine.fetchMessages)")
        let inboxName = inbox.first?.name ?? "INBOX"
        _ = try await server.selectMailbox(inboxName)
        let selection = try await server.selectMailbox(inboxName)
        say("  Nachrichten: \(selection.messageCount), "
            + "UIDVALIDITY: \(selection.uidValidity)")

        if selection.messageCount > 0, let set = selection.latest(min(selection.messageCount, 3)) {
            var fetched: [Message] = []
            for try await message in server.fetchMessages(using: set) {
                fetched.append(message)
            }
            check(!fetched.isEmpty, "Nachrichten geladen")
            let withSubject = fetched.filter { ($0.subject ?? "").isEmpty == false }.count
            let withSender = fetched.filter { $0.from != nil }.count
            let withDate = fetched.filter { $0.date != nil }.count
            check(withSubject == fetched.count, "Betreff geparst",
                  detail: "\(withSubject)/\(fetched.count)")
            check(withSender == fetched.count, "Absender geparst",
                  detail: "\(withSender)/\(fetched.count)")
            check(withDate == fetched.count, "Datum geparst",
                  detail: "\(withDate)/\(fetched.count)")
            say("  (Inhalte werden nicht ausgegeben — nur Zähler)")
        } else {
            say("  (Posteingang leer — Nachrichtenprüfung übersprungen)")
        }

        if writeTest {
            try await writeTests(server: server, credentials: credentials, folders: folders)
        } else {
            head("Schreibtest")
            say("  übersprungen (ohne --write)")
        }

        // MARK: Ende
        head("Abmelden")
        try? await server.logout()
        say("  ✅ Verbindung geschlossen")

        if CommandLine.arguments.contains("--smtp") {
            await smtpTests(credentials: credentials)
        }
    }

    // MARK: – SMTP-Versand

    /// Prüft den Versandpfad mit denselben Zugangsdaten. Sendet eine
    /// Testnachricht an das eigene Konto (Gmail: 587 STARTTLS, 465 implizit).
    static func smtpTests(credentials: Credentials) async {
        head("SMTP-Versand")

        let host = ProcessInfo.processInfo.environment["SMTP_HOST"] ?? "smtp.gmail.com"
        let port = Int(ProcessInfo.processInfo.environment["SMTP_PORT"] ?? "587") ?? 587
        let transport: MailTransportSecurity = port == 465 ? .implicitTLS : .startTLS

        let sender = EmailAddress(name: "iMail Secure Test", address: credentials.user)
        let email = Email(
            sender: sender,
            recipients: [sender],
            subject: "iMail Secure SMTP-Test \(Int(Date().timeIntervalSince1970))",
            textBody: "Automatischer Test des Versandpfads. Diese Nachricht kann gelöscht werden."
        )

        let server = SMTPServer(host: host, port: port, transportSecurity: transport)
        do {
            try await server.connect()
            say("  ✅ Verbindung aufgebaut (\(host):\(port), "
                + "\(port == 465 ? "implizites TLS" : "STARTTLS"))")
            try await server.login(username: credentials.user, password: credentials.password)
            say("  ✅ Anmeldung akzeptiert")
            _ = try await server.sendEmail(email)
            say("  ✅ Testnachricht an \(credentials.user) übergeben")
            try? await server.disconnect()
            check(true, "SMTP-Versand erfolgreich")
        } catch {
            check(false, "SMTP-Versand fehlgeschlagen", detail: String(describing: error))
        }
    }

    // MARK: – Schreibtest

    static func writeTests(
        server: IMAPServer,
        credentials: Credentials,
        folders: [MailFolder]
    ) async throws {
        head("Schreibtest mit Testordnern")

        let stamp = Int(Date().timeIntervalSince1970)
        // Bewusst ein Umlaut im Namen: Damit läuft der Test durch dieselbe
        // Kodierung, die die App für Nutzereingaben verwendet.
        let readableParent = "iMail-Test-\(stamp)-Prüfung"
        let parentName = ModifiedUTF7.encode(readableParent)
        let delimiter = folders.compactMap(\.delimiter).first ?? "."
        let childName = parentName + delimiter + "Unterordner"

        var created: [String] = []

        do {
            try await server.createMailbox(parentName)
            created.append(parentName)
            let afterParent = Set(try await server.listMailboxes(wildcard: "*").map(\.name))
            check(afterParent.contains(parentName), "Ordner mit Umlaut anlegen")
            check(ModifiedUTF7.decode(parentName) == readableParent,
                  "Name kommt lesbar zurück", detail: ModifiedUTF7.decode(parentName))

            try await server.createMailbox(childName)
            created.append(childName)
            let afterChild = Set(try await server.listMailboxes(wildcard: "*").map(\.name))
            check(afterChild.contains(childName),
                  "verschachtelten Ordner anlegen (Trennzeichen „\(delimiter)“)")

            // Umbenennen: nur letztes Segment, Elternpfad bleibt
            guard let childInfo = try await server.listMailboxes(wildcard: "*")
                .first(where: { $0.name == childName }) else {
                throw ProbeError.unexpected("Unterordner nach dem Anlegen nicht gefunden")
            }
            let childFolder = MailFolder(info: childInfo)
            let renamed = try childFolder.renamedPath(to: "Umbenannt")
            try await server.renameMailbox(childName, to: renamed)
            created.removeAll { $0 == childName }
            created.append(renamed)

            let afterRename = Set(try await server.listMailboxes(wildcard: "*").map(\.name))
            check(afterRename.contains(renamed), "Ordner umbenennen", detail: "erwartet \(renamed)")
            check(!afterRename.contains(childName), "alter Name ist verschwunden")
            check(renamed.hasPrefix(parentName + delimiter),
                  "Elternpfad bleibt erhalten", detail: renamed)

            // Testnachricht anlegen
            let appendResult = try await server.append(
                rawMessage: sampleMessage(user: credentials.user),
                to: renamed,
                flags: [],
                internalDate: Date()
            )
            check(appendResult.firstUID != nil, "Testnachricht per APPEND angelegt")

            let inFolder = await statusCount(server, renamed)
            check(inFolder == 1, "Testordner enthält genau eine Nachricht",
                  detail: "gezählt: \(inFolder)")

            // MOVE in den Papierkorb
            guard let trashFolder = MailFolder.preferred(role: .trash, in: folders) else {
                throw ProbeError.unexpected("Kein Papierkorb erkannt — MOVE-Test nicht möglich")
            }
            say("  Papierkorb laut Rollenerkennung: \(trashFolder.readableName) "
                + "(Special-Use: \(trashFolder.hasSpecialUse ? "ja" : "nein"))")
            let trashBefore = await statusCount(server, trashFolder.name)

            var movedUID: UID?
            if let uid = appendResult.firstUID {
                _ = try await server.selectMailbox(renamed)
                let copyUID = try await server.move(
                    messages: MessageIdentifierSet<UID>(uid),
                    to: trashFolder.name
                )
                movedUID = copyUID?.mapping.first?.destination
            }

            let sourceAfter = await statusCount(server, renamed)
            let trashAfter = await statusCount(server, trashFolder.name)
            check(sourceAfter == 0, "MOVE entfernt die Nachricht aus dem Quellordner",
                  detail: "noch \(sourceAfter)")
            check(trashAfter == trashBefore + 1,
                  "Nachricht liegt im Papierkorb „\(trashFolder.readableName)“",
                  detail: "vorher \(trashBefore), nachher \(trashAfter)")
            check(movedUID != nil, "Server meldet die neue UID im Papierkorb (COPYUID)")

            // Nur die eigene Testnachricht endgültig entfernen
            if let uid = movedUID {
                _ = try await server.selectMailbox(trashFolder.name)
                try await server.store(
                    flags: [.deleted],
                    on: MessageIdentifierSet<UID>(uid),
                    operation: .add
                )
                if try await capabilities(of: server).contains("UIDPLUS") {
                    try await server.expunge(messages: MessageIdentifierSet<UID>(uid))
                    let trashClean = await statusCount(server, trashFolder.name)
                    check(trashClean == trashBefore, "Testnachricht endgültig entfernt",
                          detail: "Papierkorb: \(trashClean)")
                } else {
                    say("  ⚠️ kein UIDPLUS — Testnachricht bleibt als \\Deleted im Papierkorb")
                }
                movedUID = nil
            } else {
                say("  ⚠️ Keine COPYUID — Testnachricht bleibt im Papierkorb")
            }

            // Aufräumen: erst das Blatt, dann den Elternordner
            try await server.deleteMailbox(renamed)
            created.removeAll { $0 == renamed }
            let afterLeafDelete = Set(try await server.listMailboxes(wildcard: "*").map(\.name))
            check(!afterLeafDelete.contains(renamed), "eigenen Ordner löschen")

            try await server.deleteMailbox(parentName)
            created.removeAll { $0 == parentName }
            let finalNames = Set(try await server.listMailboxes(wildcard: "*").map(\.name))
            check(!finalNames.contains(parentName), "Elternordner löschen")
            check(!finalNames.contains(where: { $0.hasPrefix(parentName) }),
                  "keine Testordner zurückgelassen")
        } catch {
            try await cleanup(server: server, names: created, extras: [])
            throw error
        }

        try await cleanup(server: server, names: created, extras: [])
    }

    static func cleanup(server: IMAPServer, names: [String], extras: [String]) async throws {
        guard !names.isEmpty else { return }
        say("  Aufräumen nach Fehler:")
        for name in names.reversed() {
            do {
                try await server.deleteMailbox(name)
                say("    entfernt: \(name)")
            } catch {
                say("    ⚠️ konnte nicht entfernt werden: \(name) — \(error.localizedDescription)")
            }
        }
    }
}
