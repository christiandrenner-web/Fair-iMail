// HTMLSanitizer.swift
//
// D2 – zweite Verteidigungslinie vor dem Rendern fremden HTML.
//
// Die erste Linie ist WebKit selbst: JavaScript aus, nicht-persistenter
// Datenspeicher, Content-Rule-Liste, die jede http(s)-Anfrage blockiert.
// Dieser Sanitizer räumt zusätzlich alles weg, was schon ohne Netzwerk
// Schaden anrichten kann (Skripte, Formulare, Meta-Refresh, Event-Handler)
// und entfernt Ressourcen-Verweise, die überhaupt einen Request auslösen
// würden.
//
// Bewusst ohne DOM/WebKit, damit die Logik unit-testbar ist.

import Foundation

enum HTMLSanitizer {

    // MARK: – Öffentliche API

    /// Bereinigt ein HTML-Fragment für die Anzeige in einer WKWebView.
    ///
    /// Das Ergebnis enthält **niemals** ausführbaren Code. Mit
    /// `allowRemoteResources: false` (Standard) enthält es außerdem keinen
    /// Verweis auf eine Remote-Ressource.
    ///
    /// `allowRemoteResources: true` ist die dritte Stufe von D2: Der Nutzer
    /// hat für genau diese Mail oder diesen Absender zugestimmt, dass Bilder
    /// und Stylesheets geladen werden dürfen. Alles andere — Skripte,
    /// Formulare, Meta-Refresh, Event-Handler, `javascript:` — bleibt auch
    /// dann entfernt.
    static func sanitize(_ html: String, allowRemoteResources: Bool = false) -> String {
        var s = html

        // 1. Elemente entfernen, deren Inhalt oder Semantik gefährlich ist.
        for tag in dangerousBlocks {
            s = removeBlock(tag: tag, from: s)
        }

        // 2. Meta-Refresh (Weiterleitung ohne JavaScript).
        s = replacing(#"<meta[^>]*http-equiv\s*=\s*["']?refresh["']?[^>]*>"#, in: s, with: " ")

        // 3. Event-Handler (onclick, onerror, onload …).
        s = replacing(#"\son[a-zA-Z]+\s*=\s*(?:"[^"]*"|'[^']*'|[^\s>]+)"#, in: s, with: "")

        // 4. javascript:/vbscript:-URLs und HTML-Daten-URLs.
        s = replacing(
            #"(href|src|action|formaction|xlink:href)\s*=\s*("[^"]*"|'[^']*'|[^\s>]+)"#,
            in: s,
            using: { match in
                let value = unquote(match.groups[2])
                let lower = value.lowercased()
                if lower.hasPrefix("javascript:") || lower.hasPrefix("vbscript:")
                    || lower.hasPrefix("data:text/html")
                    || lower.hasPrefix("data:image/svg") {
                    return "\(match.groups[1])=\"\""
                }
                return match.full
            })

        // 5. <a ping> löst beim Klick einen POST aus und trägt nichts zur
        //    Darstellung bei — auch bei freigegebenen externen Inhalten weg.
        s = replacing(#"\s+ping\s*=\s*(?:"[^"]*"|'[^']*'|[^\s>]+)"#, in: s, with: "")

        if allowRemoteResources {
            // Stufe 3: Remote-Ressourcen bleiben. `srcset` ist dann sinnvoll,
            // aber nur mit demselben Vertrauensvorschuss wie `src`.
            return wrap(s)
        }

        // 6. Ressourcen, die einen Netzwerk-Request auslösen würden.
        s = stripRemoteResources(s)

        // 7. CSS: @import und url(...) entfernen (auch im style-Attribut).
        s = replacing(#"@import[^;]*;?"#, in: s, with: "")
        s = replacing(#"url\s*\(\s*[^)]*\)"#, in: s, with: "none")

        return wrap(s)
    }

    // MARK: – Regelwerk

    /// Elemente, die samt Inhalt verschwinden.
    private static let dangerousBlocks = [
        "script", "iframe", "object", "embed", "applet",
        "form", "noscript", "template", "svg", "math",
        // Void-Elemente: haben keinen Inhalt, werden als Tag entfernt.
        "base", "link", "meta"
    ]

    /// Attribute, die eine externe Ressource referenzieren können.
    private static let resourceAttributes = ["src", "background", "poster"]

    // MARK: – Schritte

    private static func removeBlock(tag: String, from input: String) -> String {
        var s = input
        // Paar mit Inhalt
        s = replacing("<\(tag)\\b[^>]*>[\\s\\S]*?</\(tag)\\s*>", in: s, with: " ")
        // Selbstschließend und einzelne Tags
        s = replacing("</?\(tag)\\b[^>]*>", in: s, with: " ")
        return s
    }

    private static func stripRemoteResources(_ input: String) -> String {
        // srcset immer entfernen: enthält mehrere Kandidaten-URLs und ist
        // in E-Mails praktisch nie nötig.
        var s = replacing(#"\s+srcset\s*=\s*(?:"[^"]*"|'[^']*'|[^\s>]+)"#, in: input, with: "")

        // <a ping> löst beim Klick einen POST an die genannten URLs aus.
        s = replacing(#"\s+ping\s*=\s*(?:"[^"]*"|'[^']*'|[^\s>]+)"#, in: s, with: "")

        let attributes = resourceAttributes.joined(separator: "|")
        s = replacing(
            "(\\s+(?:\(attributes)))\\s*=\\s*(\"[^\"]*\"|'[^']*'|[^\\s>]+)",
            in: s,
            using: { match in
                let value = unquote(match.groups[2])
                return isLocalResource(value) ? match.full : ""
            })
        return s
    }

    /// Nur Bilder, die in der Mail selbst stecken (cid:) oder als
    /// data:-Rasterbild eingebettet sind, dürfen bleiben.
    private static func isLocalResource(_ value: String) -> Bool {
        let lower = value.lowercased()
        if lower.hasPrefix("cid:") { return true }
        guard lower.hasPrefix("data:image/") else { return false }
        let raster = ["data:image/png", "data:image/jpeg", "data:image/jpg",
                      "data:image/gif", "data:image/webp", "data:image/bmp"]
        return raster.contains { lower.hasPrefix($0) }
    }

    /// Rahmen um das Fragment: Grundtypografie, kein horizontaler Overflow.
    private static func wrap(_ body: String) -> String {
        """
        <!doctype html>
        <html><head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
          :root { color-scheme: light dark; }
          html, body { margin: 0; padding: 0; }
          body {
            font-family: -apple-system, system-ui, sans-serif;
            font-size: 17px; line-height: 1.45;
            overflow-wrap: anywhere; word-break: break-word;
            -webkit-text-size-adjust: 100%;
          }
          img { max-width: 100% !important; height: auto !important; }
          table { max-width: 100% !important; }
          a { color: #0a7aff; }
        </style>
        </head><body>\(body)</body></html>
        """
    }

    // MARK: – Regex-Helfer

    private struct Match {
        let full: String
        let groups: [String]
    }

    private static func unquote(_ raw: String) -> String {
        var v = raw.trimmingCharacters(in: .whitespaces)
        if v.count >= 2,
           (v.hasPrefix("\"") && v.hasSuffix("\"")) || (v.hasPrefix("'") && v.hasSuffix("'")) {
            v = String(v.dropFirst().dropLast())
        }
        return v
    }

    private static func replacing(_ pattern: String, in input: String, with template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return input
        }
        let range = NSRange(input.startIndex..., in: input)
        return regex.stringByReplacingMatches(in: input, range: range, withTemplate: template)
    }

    private static func replacing(_ pattern: String, in input: String,
                                  using transform: (Match) -> String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return input
        }
        let ns = input as NSString
        let matches = regex.matches(in: input, range: NSRange(location: 0, length: ns.length))

        var result = input
        for match in matches.reversed() {
            var groups: [String] = []
            for index in 0..<match.numberOfRanges {
                let r = match.range(at: index)
                groups.append(r.location == NSNotFound ? "" : ns.substring(with: r))
            }
            let replacement = transform(Match(full: ns.substring(with: match.range), groups: groups))
            if let range = Range(match.range, in: result) {
                result.replaceSubrange(range, with: replacement)
            }
        }
        return result
    }
}
