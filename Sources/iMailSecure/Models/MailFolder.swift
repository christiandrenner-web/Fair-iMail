// MailFolder.swift
//
// Ordner sind auf dem Server Wahrheit, nicht in der App. Dieses Modell
// übersetzt die IMAP-Metadaten (LIST) in etwas, das die UI versteht:
//
//   • Rolle (Posteingang, Gesendet, …) aus den Special-Use-Attributen,
//     mit Namens-Fallback für Server, die keine Attribute liefern.
//   • Anzeigename auf Deutsch, ohne den Server-Namen zu verlieren.
//   • Validierung für neu angelegte Ordner, bevor etwas an den Server geht.
//
// Wichtig: Die Rolle entscheidet über Free/Pro. Systemordner bleiben in der
// kostenlosen Version nutzbar; nur eigene Ordner verlangen Pro.

import Foundation
import SwiftMail

// MARK: – Rolle

enum MailFolderRole: String, CaseIterable, Codable, Sendable {
    case inbox
    case flagged
    case drafts
    case sent
    case archive
    /// „Alle Nachrichten" (Gmail: All Mail, RFC 6154 \All). Enthält jede
    /// Nachricht des Kontos zusätzlich zum eigentlichen Ordner.
    case all
    case junk
    case trash
    case custom

    var displayName: String {
        switch self {
        case .inbox:
            return String(localized: "folder.inbox", defaultValue: "Posteingang")
        case .flagged:
            return String(localized: "folder.flagged", defaultValue: "Markiert")
        case .drafts:
            return String(localized: "folder.drafts", defaultValue: "Entwürfe")
        case .sent:
            return String(localized: "folder.sent", defaultValue: "Gesendet")
        case .archive:
            return String(localized: "folder.archive", defaultValue: "Archiv")
        case .all:
            return String(localized: "folder.all", defaultValue: "Alle Nachrichten")
        case .junk:
            return String(localized: "folder.junk", defaultValue: "Spam")
        case .trash:
            return String(localized: "folder.trash", defaultValue: "Papierkorb")
        case .custom:
            return String(localized: "folder.custom", defaultValue: "Ordner")
        }
    }

    /// Systemordner zuerst, eigene Ordner zuletzt.
    var sortOrder: Int {
        switch self {
        case .inbox:   return 0
        case .flagged: return 1
        case .drafts:  return 2
        case .sent:    return 3
        case .archive: return 4
        case .all:     return 5
        case .junk:    return 6
        case .trash:   return 7
        case .custom:  return 8
        }
    }

    var isSystem: Bool { self != .custom }

    // MARK: Erkennung

    /// Special-Use-Attribute haben Vorrang. Der Namens-Fallback greift nur,
    /// wenn der Server keine Attribute liefert (z. B. ältere Dovecot-Setups).
    static func detect(
        name: String,
        attributes: Mailbox.Info.Attributes,
        delimiter: String?
    ) -> MailFolderRole {
        // Servernamen sind modified UTF-7: „Entw&APw-rfe" ist „Entwürfe".
        // Der Namens-Fallback muss deshalb den lesbaren Namen vergleichen.
        let name = ModifiedUTF7.decode(name)
        if attributes.contains(.inbox)   { return .inbox }
        if attributes.contains(.sent)    { return .sent }
        if attributes.contains(.drafts)  { return .drafts }
        if attributes.contains(.trash)   { return .trash }
        if attributes.contains(.junk)    { return .junk }
        if attributes.contains(.archive) { return .archive }
        if attributes.contains(.all)     { return .all }
        if attributes.contains(.flagged) { return .flagged }

        let candidates = nameCandidates(name: name, delimiter: delimiter)
        if candidates.contains(where: inboxNames.contains)   { return .inbox }
        if candidates.contains(where: sentNames.contains)    { return .sent }
        if candidates.contains(where: draftsNames.contains)  { return .drafts }
        if candidates.contains(where: trashNames.contains)   { return .trash }
        if candidates.contains(where: junkNames.contains)    { return .junk }
        if candidates.contains(where: archiveNames.contains) { return .archive }
        if candidates.contains(where: allNames.contains)     { return .all }
        if candidates.contains(where: flaggedNames.contains) { return .flagged }
        return .custom
    }

    /// Vergleicht sowohl den vollen Namen als auch das letzte Segment.
    /// Damit wird z. B. „INBOX.Trash" bei Delimiter „." erkannt.
    private static func nameCandidates(name: String, delimiter: String?) -> [String] {
        let full = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var result = [full]
        if let delimiter, !delimiter.isEmpty {
            let parts = full.components(separatedBy: delimiter).filter { !$0.isEmpty }
            if let leaf = parts.last, leaf != full {
                result.append(leaf)
            }
        }
        return result
    }

    private static let inboxNames: Set<String> = [
        "inbox", "posteingang", "postfach"
    ]

    private static let sentNames: Set<String> = [
        "sent", "sent items", "sent messages", "sent mail",
        "gesendet", "gesendete objekte", "gesendete elemente", "ausgang"
    ]

    private static let draftsNames: Set<String> = [
        "drafts", "draft", "entwurf", "entwürfe", "konzepte"
    ]

    private static let trashNames: Set<String> = [
        "trash", "trash bin", "deleted", "deleted items", "deleted messages",
        "papierkorb", "gelöscht", "gelöschte objekte", "gelöschte elemente"
    ]

    private static let junkNames: Set<String> = [
        "junk", "junk e-mail", "junk email", "spam", "bulk mail",
        "unerwünscht", "unerwünschte post", "spamverdacht"
    ]

    private static let archiveNames: Set<String> = [
        "archive", "archiv"
    ]

    private static let flaggedNames: Set<String> = [
        "flagged", "starred", "markiert", "wichtig"
    ]

    private static let allNames: Set<String> = [
        "all", "all mail", "alle nachrichten", "alle mails"
    ]
}

// MARK: – Ordner

struct MailFolder: Identifiable, Hashable, Sendable {
    /// Name auf dem Server. Wird beim SELECT/MOVE unverändert verwendet.
    let name: String
    let role: MailFolderRole
    let delimiter: String?
    let isSelectable: Bool
    /// Ob die Rolle aus einem Special-Use-Attribut des Servers stammt.
    /// GMX führt alte und neue Systemordner parallel („Trash" und
    /// „Gelöscht"); bei Gleichstand gewinnt die markierte Fassung.
    let hasSpecialUse: Bool

    var id: String { name }

    /// Eigene Ordner sind Pro. Systemordner bleiben kostenlos.
    var requiresPro: Bool { role == .custom }

    var displayName: String {
        guard role == .custom else { return role.displayName }
        guard let delimiter, !delimiter.isEmpty else { return readableName }
        return readableName.replacingOccurrences(of: delimiter, with: " › ")
    }

    /// Servername als lesbarer Text. Der rohe `name` bleibt unverändert,
    /// weil jede IMAP-Aktion exakt die Bytes des Servers braucht.
    var readableName: String { ModifiedUTF7.decode(name) }

    /// Letztes Segment als lesbarer Text — für Umbenennen und Duplikate.
    var readableLeafName: String { ModifiedUTF7.decode(leafName()) }

    /// Letztes Segment des Servernamens. Wird beim Umbenennen angezeigt,
    /// damit der Nutzer nicht den kompletten Pfad bearbeiten muss.
    /// Rohes letztes Pfadsegment — so, wie der Server es erwartet.
    func leafName(delimiter: String? = nil) -> String {
        let delimiter = delimiter ?? self.delimiter
        guard let delimiter, !delimiter.isEmpty else { return name }
        return name.components(separatedBy: delimiter).last ?? name
    }

    /// Neuer Servername im selben Elternordner. Der Ordnername selbst wird
    /// validiert; der bestehende Pfad davor bleibt unverändert.
    func renamedPath(to leaf: String, delimiter: String? = nil) throws -> String {
        let delimiter = delimiter ?? self.delimiter
        let validatedLeaf = try MailFolder.validatedName(leaf, delimiter: delimiter)
        // Der Server erwartet modified UTF-7; der Nutzer tippt Klartext.
        let encodedLeaf = ModifiedUTF7.encode(validatedLeaf)
        guard let delimiter, !delimiter.isEmpty else { return encodedLeaf }

        var components = name.components(separatedBy: delimiter)
        guard !components.isEmpty else { return encodedLeaf }
        components[components.count - 1] = encodedLeaf
        return components.joined(separator: delimiter)
    }

    init(
        name: String,
        role: MailFolderRole,
        delimiter: String? = nil,
        isSelectable: Bool = true,
        hasSpecialUse: Bool = false
    ) {
        self.name = name
        self.role = role
        self.delimiter = delimiter
        self.isSelectable = isSelectable
        self.hasSpecialUse = hasSpecialUse
    }

    init(info: Mailbox.Info) {
        self.name = info.name
        self.role = MailFolderRole.detect(
            name: info.name,
            attributes: info.attributes,
            delimiter: info.hierarchyDelimiter
        )
        self.delimiter = info.hierarchyDelimiter
        self.isSelectable = info.isSelectable
        self.hasSpecialUse = MailFolder.specialUseAttributes
            .intersection(info.attributes)
            .isEmpty == false
    }

    /// Die Attribute, die einen Systemordner auszeichnen (RFC 6154).
    static let specialUseAttributes: Mailbox.Info.Attributes = [
        .inbox, .sent, .drafts, .trash, .junk, .archive, .flagged, .all
    ]

    /// Wählt unter mehreren Ordnern derselben Rolle den vom Server
    /// ausgezeichneten. Ohne Attribut bleibt die erste Fundstelle.
    static func preferred(
        role: MailFolderRole,
        in folders: [MailFolder]
    ) -> MailFolder? {
        let matches = folders.filter { $0.role == role }
        return matches.first(where: \.hasSpecialUse) ?? matches.first
    }

    // MARK: Sortierung

    /// Entfernt Duplikate und nicht auswählbare Container (z. B. „[Gmail]"),
    /// sortiert Systemordner nach Rolle und eigene Ordner alphabetisch.
    static func sorted(_ folders: [MailFolder]) -> [MailFolder] {
        var seen = Set<String>()
        return folders
            .filter(\.isSelectable)
            .filter { seen.insert($0.name).inserted }
            .sorted {
                if $0.role.sortOrder != $1.role.sortOrder {
                    return $0.role.sortOrder < $1.role.sortOrder
                }
                return $0.displayName.localizedCaseInsensitiveCompare($1.displayName)
                    == .orderedAscending
            }
    }

    // MARK: Namen validieren

    /// Prüft einen vom Nutzer eingegebenen Ordnernamen, bevor er an den
    /// Server geht. Der Server würde dieselben Zeichen ablehnen — nur später,
    /// mit einer unverständlichen IMAP-Fehlermeldung.
    static func validatedName(_ raw: String, delimiter: String? = nil) throws -> String {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !name.isEmpty else {
            throw MailFolderError.emptyName
        }
        guard name.count <= 255 else {
            throw MailFolderError.nameTooLong
        }
        if let delimiter, !delimiter.isEmpty, name.contains(delimiter) {
            throw MailFolderError.usesDelimiter(delimiter)
        }

        // RFC 3501 verbietet diese Zeichen in Mailbox-Namen; Steuerzeichen
        // (inkl. CR/LF) würden außerdem das IMAP-Kommando zerlegen.
        let forbidden = CharacterSet(charactersIn: "\"\\{}%*")
            .union(.controlCharacters)
        guard name.rangeOfCharacter(from: forbidden) == nil else {
            throw MailFolderError.invalidCharacters
        }
        guard name != ".", name != ".." else {
            throw MailFolderError.invalidCharacters
        }

        return name
    }
}

// MARK: – Fehler

enum MailFolderError: LocalizedError, Equatable {
    case emptyName
    case nameTooLong
    case invalidCharacters
    case usesDelimiter(String)
    case alreadyExists
    case noAccount
    case systemFolder
    case folderNotFound

    var errorDescription: String? {
        switch self {
        case .emptyName:
            return String(localized: "folder.error.empty",
                          defaultValue: "Bitte einen Ordnernamen eingeben.")
        case .nameTooLong:
            return String(localized: "folder.error.tooLong",
                          defaultValue: "Der Name ist zu lang (höchstens 255 Zeichen).")
        case .invalidCharacters:
            return String(localized: "folder.error.invalid",
                          defaultValue: "Der Name enthält Zeichen, die der Mailserver nicht erlaubt.")
        case .usesDelimiter(let delimiter):
            return String(
                format: String(localized: "folder.error.delimiter",
                               defaultValue: "Der Name darf das Trennzeichen „%@“ nicht enthalten."),
                delimiter
            )
        case .alreadyExists:
            return String(localized: "folder.error.exists",
                          defaultValue: "Ein Ordner mit diesem Namen existiert bereits.")
        case .noAccount:
            return String(localized: "folder.error.noAccount",
                          defaultValue: "Für dieses Konto besteht gerade keine Verbindung.")
        case .systemFolder:
            return String(localized: "folder.error.system",
                          defaultValue: "Systemordner lassen sich nicht umbenennen oder löschen.")
        case .folderNotFound:
            return String(localized: "folder.error.notFound",
                          defaultValue: "Der Ordner existiert nicht mehr.")
        }
    }
}

// MARK: – Auswahl in der Oberfläche

/// Was die Nachrichtenliste gerade zeigt. Der gemeinsame Posteingang
/// aggregiert alle Konten; `.folder` bleibt kontogebunden, weil IMAP-UIDs
/// nur innerhalb eines Postfachs gültig sind.
enum MailboxSelection: Hashable, Sendable {
    case unifiedInbox
    case folder(accountID: UUID, folder: MailFolder)

    var title: String {
        switch self {
        case .unifiedInbox:
            return String(localized: "folder.unified",
                          defaultValue: "Gemeinsamer Posteingang")
        case .folder(_, let folder):
            return folder.displayName
        }
    }
}
