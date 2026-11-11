// ConnectionSecurity+SwiftMail.swift
//
// Übersetzt die App-Einstellung in die Transport-Policy von SwiftMail.
// `.startTLS` ist die erzwungene Variante: fehlt das STARTTLS-Angebot,
// bricht der Verbindungsaufbau ab, statt Klartext zu sprechen.

import SwiftMail

extension ConnectionSecurity {
    var mailTransportSecurity: MailTransportSecurity {
        switch self {
        case .implicit: return .implicitTLS
        case .startTLS: return .startTLS
        }
    }
}
