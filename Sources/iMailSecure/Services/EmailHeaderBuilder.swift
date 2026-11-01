// EmailHeaderBuilder.swift
import Foundation

struct EmailHeaderBuilder {

    static func buildHeaders(from account: EmailAccount, draft: EmailDraft) -> [String: String] {
        var headers: [String: String] = [:]

        headers["From"]         = account.email.isEmpty ? account.email : "\"\(account.displayName)\" <\(account.email)>"
        headers["To"]           = draft.to.map(\.formatted).joined(separator: ", ")
        headers["Subject"]      = draft.subject
        headers["Date"]         = rfc2822Date(from: Date())
        headers["Message-ID"]   = generateMessageID(domain: domainFrom(email: account.email))
        headers["MIME-Version"] = "1.0"
        headers["Content-Type"] = "text/plain; charset=UTF-8"
        headers["User-Agent"]   = "iMailSecure/1.0 (iOS)"

        if !draft.cc.isEmpty {
            headers["Cc"] = draft.cc.map(\.formatted).joined(separator: ", ")
        }

        // MDN – RFC 8098
        if draft.requestMDN {
            headers["Disposition-Notification-To"]      = account.email
            headers["Disposition-Notification-Options"] = "X-MDNSent-Type=displayed; x-unsupported-parameter=true"
        }

        // Empfangsbestätigung
        if draft.requestReceipt {
            headers["Return-Receipt-To"] = account.email
        }

        return headers
    }

    // MARK: – Helpers

    private static func generateMessageID(domain: String) -> String {
        let ts   = Int(Date().timeIntervalSince1970)
        let uuid = UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(16)
        return "<\(ts).\(uuid)@\(domain)>"
    }

    private static func domainFrom(email: String) -> String {
        email.components(separatedBy: "@").last ?? "imailsecure.local"
    }

    private static func rfc2822Date(from date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale   = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return fmt.string(from: date)
    }
}
