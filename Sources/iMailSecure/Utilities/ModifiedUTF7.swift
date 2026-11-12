// ModifiedUTF7.swift
//
// IMAP überträgt Ordnernamen nicht als UTF-8, sondern als „modified UTF-7"
// (RFC 3501, Abschnitt 5.1.3). Ein Server wie GMX liefert deshalb
//
//     Entw&APw-rfe      statt   Entwürfe
//     Gel&APY-scht      statt   Gelöscht
//
// SwiftMail reicht die Bytes unverändert durch. Ohne diese Übersetzung steht
// in der Oberfläche der Rohname, und ein vom Nutzer eingegebener Name mit
// Umlauten wird als UTF-8 gesendet — was der Server nicht versteht.
//
// Regeln:
//   • druckbares ASCII (außer „&") steht direkt,
//   • „&-" ist das Zeichen „&",
//   • „&…-" ist Base64 über UTF-16BE, wobei „/" als „," geschrieben wird
//     und die Auffüllzeichen „=" entfallen.

import Foundation

enum ModifiedUTF7 {
    // MARK: – Dekodieren

    /// Wandelt einen Servernamen in lesbaren Text. Unbekannte Sequenzen bleiben
    /// unverändert, damit ein kaputter Name nicht die ganze Liste unbrauchbar macht.
    static func decode(_ raw: String) -> String {
        guard raw.contains("&") else { return raw }

        var result = ""
        var index = raw.startIndex

        while index < raw.endIndex {
            let character = raw[index]
            guard character == "&" else {
                result.append(character)
                index = raw.index(after: index)
                continue
            }

            guard let dash = raw[index...].firstIndex(of: "-") else {
                // Kein Abschluss: Rest unverändert übernehmen.
                result.append(contentsOf: raw[index...])
                break
            }

            let encoded = String(raw[raw.index(after: index)..<dash])
            if encoded.isEmpty {
                result.append("&")
            } else if let decoded = decodeBase64UTF16(encoded) {
                result.append(decoded)
            } else {
                result.append("&")
                result.append(encoded)
                result.append("-")
            }
            index = raw.index(after: dash)
        }

        return result
    }

    private static func decodeBase64UTF16(_ encoded: String) -> String? {
        var base64 = encoded.replacingOccurrences(of: ",", with: "/")
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        guard let data = Data(base64Encoded: base64), data.count % 2 == 0 else {
            return nil
        }
        let units = stride(from: 0, to: data.count, by: 2).map { offset in
            UInt16(data[offset]) << 8 | UInt16(data[offset + 1])
        }
        return String(decoding: units, as: UTF16.self)
    }

    // MARK: – Kodieren

    /// Wandelt einen eingegebenen Namen in die Form, die der Server erwartet.
    /// Namen ohne Sonderzeichen bleiben unverändert.
    static func encode(_ raw: String) -> String {
        var result = ""
        var pending: [UInt16] = []

        func flush() {
            guard !pending.isEmpty else { return }
            var bytes: [UInt8] = []
            bytes.reserveCapacity(pending.count * 2)
            for unit in pending {
                bytes.append(UInt8(unit >> 8))
                bytes.append(UInt8(unit & 0xFF))
            }
            let base64 = Data(bytes).base64EncodedString()
                .replacingOccurrences(of: "/", with: ",")
                .replacingOccurrences(of: "=", with: "")
            result += "&" + base64 + "-"
            pending.removeAll(keepingCapacity: true)
        }

        for scalar in raw.unicodeScalars {
            if scalar.value == 0x26 {          // „&"
                flush()
                result += "&-"
            } else if scalar.value >= 0x20, scalar.value <= 0x7E {
                flush()
                result.unicodeScalars.append(scalar)
            } else {
                pending.append(contentsOf: Array(String(scalar).utf16))
            }
        }
        flush()

        return result
    }
}
