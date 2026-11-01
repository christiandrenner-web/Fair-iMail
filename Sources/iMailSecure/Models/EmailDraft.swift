// EmailDraft.swift
import Foundation

struct EmailDraft: Identifiable {
    var id: UUID = UUID()
    var toText: String  = ""
    var ccText: String  = ""
    var bccText: String = ""
    var subject: String = ""
    var body: String    = ""

    var requestMDN:     Bool = false
    var requestReceipt: Bool = false
    var attachments: [EmailAttachment] = []
    var lastModified: Date = Date()

    // Parsed address arrays
    var to: [EmailAddress] {
        toText.split(separator: ",").compactMap { parseAddress(String($0)) }
    }
    var cc: [EmailAddress] {
        ccText.split(separator: ",").compactMap { parseAddress(String($0)) }
    }
    var bcc: [EmailAddress] {
        bccText.split(separator: ",").compactMap { parseAddress(String($0)) }
    }

    private func parseAddress(_ raw: String) -> EmailAddress? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        return EmailAddress(address: trimmed)
    }
}

// MDNNotification.swift
struct MDNNotification: Identifiable {
    var id: UUID = UUID()
    var originalMessageID: String
    var dispositionAction: String   // "displayed", "deleted", "processed"
    var dispositionModifier: String?
    var receivedAt: Date
}
