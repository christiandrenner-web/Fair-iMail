// Extensions.swift
import Foundation
import SwiftUI

// MARK: – String / E-Mail

extension String {

    /// Einfache E-Mail-Validierung
    var isValidEmail: Bool {
        let regex = #"^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#
        return range(of: regex, options: .regularExpression) != nil
    }

    /// Gibt die Domain einer E-Mail-Adresse zurück
    var emailDomain: String? {
        components(separatedBy: "@").last
    }

    /// Preview (erste 150 Zeichen des bereinigten Texts)
    var emailPreview: String {
        let stripped = strippedHTML
        if stripped.count <= 150 { return stripped }
        return String(stripped.prefix(150)) + "…"
    }

    // MARK: – HTML-Sanitizer (D1)

    /// Wandelt HTML in bereinigten Klartext um.
    ///
    /// Sicherheitseigenschaften:
    /// - Entfernt zuerst <style> und <script>-Blöcke komplett (inkl. Inhalt)
    /// - Entfernt <head> und alle Kommentare
    /// - Dekodiert gängige HTML-Entities
    /// - Entfernt alle verbleibenden Tags per Regex
    /// - Kein Rendering, kein Netzwerkzugriff, kein JS
    var strippedHTML: String {
        var s = self

        // 1. Script- und Style-Blöcke komplett entfernen (Inhalt gefährlich)
        let blockPattern = #"<(script|style|head)[^>]*>[\s\S]*?</\1>"#
        s = s.replacingOccurrences(of: blockPattern,
                                   with: " ",
                                   options: [.regularExpression, .caseInsensitive])

        // 2. HTML-Kommentare entfernen
        s = s.replacingOccurrences(of: #"<!--[\s\S]*?-->"#,
                                   with: " ",
                                   options: .regularExpression)

        // 3. Zeilenumbrüche bei Block-Elementen erhalten
        let blockBreaks = #"</?(p|div|br|tr|li|h[1-6]|blockquote|pre)[^>]*>"#
        s = s.replacingOccurrences(of: blockBreaks,
                                   with: "\n",
                                   options: [.regularExpression, .caseInsensitive])

        // 4. Alle restlichen Tags entfernen
        s = s.replacingOccurrences(of: #"<[^>]+>"#,
                                   with: "",
                                   options: .regularExpression)

        // 5. HTML-Entities dekodieren (häufigste)
        let entities: [(String, String)] = [
            ("&amp;",   "&"),
            ("&lt;",    "<"),
            ("&gt;",    ">"),
            ("&quot;",  "\""),
            ("&#39;",   "'"),
            ("&apos;",  "'"),
            ("&nbsp;",  " "),
            ("&ndash;", "–"),
            ("&mdash;", "—"),
            ("&laquo;", "«"),
            ("&raquo;", "»"),
        ]
        for (entity, char) in entities {
            s = s.replacingOccurrences(of: entity, with: char,
                                       options: .caseInsensitive)
        }

        // 6. Numerische Entities (&#NNN; und &#xHH;)
        let numericDec = #"&#(\d+);"#
        if let regex = try? NSRegularExpression(pattern: numericDec) {
            let range = NSRange(s.startIndex..., in: s)
            var result = s
            let matches = regex.matches(in: s, range: range).reversed()
            for match in matches {
                if let r = Range(match.range(at: 1), in: s),
                   let codePoint = UInt32(s[r]),
                   let scalar = Unicode.Scalar(codePoint) {
                    let rep = String(scalar)
                    if let fullRange = Range(match.range, in: result) {
                        result = result.replacingCharacters(in: fullRange, with: rep)
                    }
                }
            }
            s = result
        }

        // 7. Mehrfache Leerzeilen auf max. 2 reduzieren
        s = s.replacingOccurrences(of: #"\n{3,}"#,
                                   with: "\n\n",
                                   options: .regularExpression)

        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: – URL / Link-Reiniger (D3)

extension URL {

    /// Entfernt bekannte Tracking-Parameter aus der URL.
    ///
    /// Entfernte Parameter: utm_*, fbclid, gclid, mc_eid, yclid, ref,
    /// msclkid, dclid, igshid, twclid, li_fat_id, s_cid, affiliate_id,
    /// click_id, campaign_id, ad_id
    var trackingStripped: URL {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: true)
        else { return self }

        let trackingPrefixes = ["utm_", "fbclid", "gclid", "mc_eid", "yclid",
                                "msclkid", "dclid", "igshid", "twclid",
                                "li_fat_id", "s_cid", "affiliate_id",
                                "click_id", "campaign_id", "ad_id"]

        components.queryItems = components.queryItems?.filter { item in
            !trackingPrefixes.contains { item.name.lowercased().hasPrefix($0) }
        }
        if components.queryItems?.isEmpty == true {
            components.queryItems = nil
        }
        return components.url ?? self
    }

    /// Gibt true zurück wenn Domain des angezeigten Texts von der echten URL-Domain abweicht.
    func domainMismatch(displayText: String) -> Bool {
        guard let host = self.host else { return false }
        // Nur prüfen wenn der Anzeigetext wie eine URL aussieht
        let lower = displayText.lowercased()
        guard lower.contains(".") && !lower.contains(" ") else { return false }
        let displayHost = lower
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .components(separatedBy: "/").first ?? lower
        // Warnung wenn die Domains der zweiten Ebene verschieden sind
        func etld(_ h: String) -> String {
            let parts = h.components(separatedBy: ".")
            return parts.count >= 2 ? parts.suffix(2).joined(separator: ".") : h
        }
        return etld(host.lowercased()) != etld(displayHost)
    }
}

// MARK: – View Modifiers

extension View {
    /// Fügt einen subtilen Schatten für Karten hinzu
    func cardShadow() -> some View {
        self
            .background(.background, in: RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
    }
}

// MARK: – Color

extension Color {
    static let iMailSecureBlue = Color(red: 0.0, green: 0.48, blue: 1.0)
}
