// CertificatePinner.swift
// Trust On First Use (TOFU) Zertifikat-Pinning für iMail secure.
//
// Sicherheitsmodell:
//   Beim ersten Verbindungsaufbau zu einem Server wird der SHA-256-Fingerabdruck
//   des Leaf-Zertifikats im Keychain gespeichert (ThisDeviceOnly, kein Backup).
//   Bei jedem folgenden Verbindungsaufbau wird der aktuelle Fingerabdruck verglichen.
//   Weicht er ab → PinningError.fingerprintMismatch → Verbindungsabbruch + UI-Warnung.
//
// Geltungsbereich:
//   • Port 993 (IMAPS) und 465 (SMTPS): Implicit TLS → URLSession-Probe möglich ✓
//   • Port 143/587 (STARTTLS): TLS-Schicht erst nach Plaintext-Greeting,
//     URLSession greift nicht → BoringSSL fullVerification ist hier die Absicherung.
//     Fingerabdruck-Pinning für STARTTLS erfordert einen SwiftMail-PR
//     (TLSConfiguration-Parameter in IMAPServer/SMTPServer).
//
// Bekannte Limitierung:
//   iOS 16 depreciert SecTrustCopyCertificateChain (vorher SecTrustGetCertificateAtIndex).
//   Wir nutzen SecTrustCopyCertificateChain (iOS 15+) mit Fallback auf
//   SecTrustGetCertificateAtIndex für iOS 14.

import Foundation
import Security
import CryptoKit

// MARK: – Fehlertypen

enum PinningError: LocalizedError {
    case noCertificate
    case probeTimeout
    case fingerprintMismatch(host: String, port: Int, stored: String, received: String)

    var errorDescription: String? {
        switch self {
        case .noCertificate:
            return "Kein TLS-Zertifikat vom Server erhalten."
        case .probeTimeout:
            return "TLS-Probe zum Server hat das Zeitlimit überschritten."
        case let .fingerprintMismatch(host, port, stored, received):
            return """
            ⚠️ Zertifikat-Fingerabdruck für \(host):\(port) hat sich geändert!

            Gespeichert: \(stored.prefix(23))…
            Aktuell:     \(received.prefix(23))…

            Das kann auf einen Man-in-the-Middle-Angriff hinweisen. \
            Die Verbindung wurde abgebrochen. \
            Wenn du das Zertifikat neu vertrauen möchtest, tippe unter \
            Einstellungen → Konto → „Zertifikat zurücksetzen" auf den Server.
            """
        }
    }
}

// MARK: – CertificatePinner

final class CertificatePinner: NSObject, @unchecked Sendable {
    static let shared = CertificatePinner()
    private override init() {}

    private let keychainService = "io.imailsecure.certpin"
    /// Ports die implicit TLS sprechen und mit der URLSession-Probe erreichbar sind.
    private let implicitTLSPorts: Set<Int> = [993, 465]

    // MARK: – Öffentliche API

    /// Prüft und pinnt das TLS-Zertifikat des angegebenen Servers.
    /// - Throws: `PinningError.fingerprintMismatch` wenn der Fingerabdruck sich geändert hat.
    func verifyAndPin(host: String, port: Int) async throws {
        guard implicitTLSPorts.contains(port) else {
            // STARTTLS-Ports: Pinning nicht möglich via URLSession; BoringSSL-Verifizierung genügt.
            return
        }

        let fingerprint = try await fetchFingerprint(host: host, port: port)
        let key = pinKey(host: host, port: port)

        if let stored = loadPin(key: key) {
            guard stored == fingerprint else {
                throw PinningError.fingerprintMismatch(
                    host: host, port: port,
                    stored: stored, received: fingerprint
                )
            }
            // Fingerabdruck stimmt überein — alles OK
        } else {
            // Erster Kontakt: Fingerabdruck vertrauen und speichern (TOFU)
            savePin(fingerprint: fingerprint, key: key)
        }
    }

    /// Löscht den gespeicherten Pin für einen Server.
    /// Aufruf z.B. nach expliziter Nutzerbestätigung eines neuen Zertifikats.
    func resetPin(host: String, port: Int) {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: pinKey(host: host, port: port)
        ]
        SecItemDelete(query as CFDictionary)
    }

    /// Gibt den gespeicherten Fingerabdruck für einen Server zurück (für Anzeige in der UI).
    func storedFingerprint(host: String, port: Int) -> String? {
        loadPin(key: pinKey(host: host, port: port))
    }

    // MARK: – TLS-Probe

    private func fetchFingerprint(host: String, port: Int) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest  = 10
            config.timeoutIntervalForResource = 15

            let delegate = TLSProbeDelegate { result in
                continuation.resume(with: result)
            }
            let session = URLSession(
                configuration: config,
                delegate: delegate,
                delegateQueue: OperationQueue()
            )

            // HTTPS-Probe: Der TLS-Handshake läuft vollständig durch,
            // auch wenn der Server kein HTTP spricht. Den HTTP-Response ignorieren wir.
            guard let url = URL(string: "https://\(host):\(port)/") else {
                continuation.resume(throwing: PinningError.noCertificate)
                return
            }
            let task = session.dataTask(with: url) { _, _, _ in
                // HTTP-Antwort ignoriert — nur das Zertifikat aus dem Delegate interessiert.
            }
            task.resume()
        }
    }

    // MARK: – Keychain

    private func pinKey(host: String, port: Int) -> String { "\(host):\(port)" }

    private func savePin(fingerprint: String, key: String) {
        guard let data = fingerprint.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String:              kSecClassGenericPassword,
            kSecAttrService as String:        keychainService,
            kSecAttrAccount as String:        key,
            kSecValueData as String:          data,
            // Höchste Sicherheitsstufe: nur dieses Gerät, kein Backup
            kSecAttrAccessible as String:     kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any
        ]
        // Atomares Upsert
        let update: [String: Any] = [kSecValueData as String: data]
        if SecItemUpdate(query as CFDictionary, update as CFDictionary) == errSecItemNotFound {
            SecItemAdd(query as CFDictionary, nil)
        }
    }

    private func loadPin(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String:              kSecClassGenericPassword,
            kSecAttrService as String:        keychainService,
            kSecAttrAccount as String:        key,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any,
            kSecReturnData as String:         true,
            kSecMatchLimit as String:         kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

// MARK: – TLS-Probe Delegate (privat)

private final class TLSProbeDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    private let completion: (Result<String, Error>) -> Void
    private var hasCompleted = false

    init(completion: @escaping (Result<String, Error>) -> Void) {
        self.completion = completion
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // Immer Standard-Validierung — wir ERGÄNZEN die BoringSSL-Prüfung, ersetzen sie nicht
        defer { completionHandler(.performDefaultHandling, nil) }

        guard !hasCompleted,
              challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust
        else { return }

        // Leaf-Zertifikat extrahieren (iOS 15+ API, Fallback für iOS 14)
        let leaf: SecCertificate?
        if #available(iOS 15, *) {
            leaf = (SecTrustCopyCertificateChain(trust) as? [SecCertificate])?.first
        } else {
            leaf = SecTrustGetCertificateAtIndex(trust, 0)
        }

        guard let cert = leaf else {
            finish(with: .failure(PinningError.noCertificate))
            return
        }

        // SHA-256 des DER-kodierten Leaf-Zertifikats
        let certData    = SecCertificateCopyData(cert) as Data
        let digest      = SHA256.hash(data: certData)
        let fingerprint = digest.map { String(format: "%02x", $0) }.joined(separator: ":")

        finish(with: .success(fingerprint))
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard !hasCompleted else { return }
        // Kein Zertifikat empfangen (z.B. Verbindung vor TLS-Handshake gescheitert)
        if let error {
            let nsError = error as NSError
            // SSL-Fehler bedeuten: Zertifikat war da, wurde aber abgelehnt — das ist ein
            // anderer Fehler als "kein Zertifikat"; hier interessiert uns nur "kein Kontakt"
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorTimedOut {
                finish(with: .failure(PinningError.probeTimeout))
            } else {
                // Verbindungsfehler vor oder nach TLS-Handshake
                finish(with: .failure(error))
            }
        } else {
            finish(with: .failure(PinningError.noCertificate))
        }
    }

    private func finish(with result: Result<String, Error>) {
        guard !hasCompleted else { return }
        hasCompleted = true
        completion(result)
    }
}
