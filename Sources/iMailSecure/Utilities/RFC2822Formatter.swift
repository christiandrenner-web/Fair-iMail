// RFC2822Formatter.swift
import Foundation

/// Formatiert Datumswerte nach RFC 2822 (für E-Mail-Header)
/// Beispiel: "Sat, 29 Mar 2025 14:30:00 +0100"
struct RFC2822Formatter {

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale   = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return f
    }()

    static func string(from date: Date) -> String {
        formatter.string(from: date)
    }

    static func date(from string: String) -> Date? {
        formatter.date(from: string)
    }
}

// MARK: – Relative Zeitformatierung für die UI
extension Date {
    /// "Gerade eben", "Vor 5 Minuten", "Gestern", etc.
    var relativeFormatted: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: Date())
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(self)
    }

    /// Kurze Anzeige: heute → Uhrzeit, gestern → "Gestern", älter → Datum
    var mailFormatted: String {
        if isToday {
            return formatted(date: .omitted, time: .shortened)
        } else if isYesterday {
            return String(localized: "date.yesterday", defaultValue: "Gestern")
        } else {
            return formatted(date: .abbreviated, time: .omitted)
        }
    }
}
