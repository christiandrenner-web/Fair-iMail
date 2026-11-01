// MDNProcessor.swift
import Foundation

struct MDNProcessor {

    /// Prüft, ob eine eingehende Nachricht eine MDN-Benachrichtigung ist,
    /// und gibt ein strukturiertes Objekt zurück.
    static func processMDN(message: EmailMessage) -> MDNNotification? {
        // Nur verarbeiten wenn der Body den MDN-Content-Type-Marker enthält.
        // Betreff-Heuristiken ("read:", "gelesen:") werden NICHT genutzt –
        // sie sind leicht fälschbar und erzeugen False Positives.
        guard message.body.contains("message/disposition-notification") else {
            return nil
        }

        let parsed = parseMDNBody(message.body)

        return MDNNotification(
            originalMessageID: parsed.originalMessageID,
            dispositionAction: parsed.action,
            dispositionModifier: parsed.modifier,
            receivedAt: message.date
        )
    }

    // MARK: – Private Parser

    private static func parseMDNBody(_ body: String) -> (
        originalMessageID: String,
        action: String,
        modifier: String?
    ) {
        var originalMessageID = ""
        var action = "displayed"
        var modifier: String? = nil

        let lines = body.components(separatedBy: .newlines)
        for line in lines {
            let lower = line.lowercased()

            if lower.hasPrefix("original-message-id:") {
                originalMessageID = line
                    .components(separatedBy: ":").dropFirst().joined(separator: ":")
                    .trimmingCharacters(in: .whitespaces)
            }

            if lower.hasPrefix("disposition:") {
                // Format: Disposition: automatic-action/MDN-sent-automatically; displayed
                let value = line.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
                let parts = value.components(separatedBy: ";")
                if parts.count >= 2 {
                    action   = parts[1].trimmingCharacters(in: .whitespaces)
                }
                if parts.count >= 3 {
                    modifier = parts[2].trimmingCharacters(in: .whitespaces)
                }
            }
        }

        return (originalMessageID, action, modifier)
    }
}
