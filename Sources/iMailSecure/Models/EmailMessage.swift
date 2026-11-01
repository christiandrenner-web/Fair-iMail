// EmailMessage.swift
import Foundation

struct EmailMessage: Identifiable, Equatable {
    var id: String          // Message-ID Header
    var uid: UInt32         // IMAP UID
    var accountID: UUID

    var from: EmailAddress
    var to: [EmailAddress]
    var cc: [EmailAddress]  = []
    var bcc: [EmailAddress] = []
    var subject: String
    var date: Date
    var body: String
    /// Original-HTML, falls die Mail eine HTML-Fassung hat.
    /// Wird erst nach ausdrücklicher Nutzeraktion gerendert (D2).
    var htmlBody: String?   = nil
    var isHTML: Bool        = false

    var isRead: Bool        = false
    var isFlagged: Bool     = false
    var isMarkedDeleted: Bool     = false

    var attachments: [EmailAttachment] = []

    // MDN-Status
    var mdnRequested: Bool          = false
    var mdnSent: Bool               = false
    var receiptReceived: Bool       = false
    var receiptDate: Date?          = nil

    var folder: String              = "INBOX"
}

struct EmailAddress: Identifiable, Equatable, Codable {
    var id: UUID = UUID()
    var name: String?
    var address: String

    var formatted: String {
        if let name = name, !name.isEmpty {
            return "\"\(name)\" <\(address)>"
        }
        return address
    }
}

struct EmailAttachment: Identifiable, Equatable {
    var id: UUID = UUID()
    var filename: String
    var mimeType: String
    var data: Data
    var size: Int { data.count }
}
