# iMail Secure

Datenschutzfreundlicher E-Mail-Client für iOS 18+  
Lizenz: PolyForm Noncommercial 1.0.0 — Quellcode einsehbar, keine kommerzielle Nutzung durch Dritte (siehe [LICENSING.md](LICENSING.md))

---

## Features

- Vollständige IMAP/SMTP-Unterstützung (SwiftMail), ausschließlich TLS ≥ 1.2
- TOFU-Zertifikat-Pinning (SHA-256) für IMAP und SMTP
- Lesebestätigungen nach RFC 8098 (MDN)
- Empfangsbestätigungen (Return-Receipt-To)
- Passwörter ausschließlich im iOS-Keychain (`ThisDeviceOnly`)
- Tracking-Parameter-Entfernung in Links, Bestätigung vor externem Öffnen
- Kein Tracking, keine Werbung, keine Drittanbieter-SDKs, keine Telemetrie
- HTML nur auf Knopfdruck: Text ist Standard, HTML wird ohne Netzwerkzugriff gerendert
- Externe Inhalte blockiert — Freigabe nur pro Mail oder pro Absender-Adresse, jederzeit widerrufbar
- iOS 18+, SwiftUI

---

## Projektstruktur

```
Fair-iMail/
├── AGENTS.md                 Datenschutz-Leitsätze + Arbeitsregeln (verbindlich)
├── CLAUDE.md                 Claude-spezifische Hinweise (verweist auf AGENTS.md)
├── AUDIT_NOTES.md            Security-Audit N1…C1 mit Status
├── LICENSING.md              Lizenz-/App-Store-Analyse
├── MONETIZATION.md           Free/Pro, Abo und StoreKit 2
├── LICENSE                   PolyForm Noncommercial 1.0.0 (Volltext)
├── CLA.md                    Contributor License Agreement
├── Sources/iMailSecure/
│   ├── App/                  iMailSecureApp.swift, ContentView.swift
│   ├── Models/               EmailAccount, EmailMessage, EmailDraft, MDNNotification
│   ├── Managers/             AccountStore, MailStore, MailSyncEngine, SMTPManager,
│   │                         KeychainManager, CertificatePinner, RemoteContentPolicy,
│   │                         SubscriptionManager
│   ├── Services/             EmailHeaderBuilder, MDNProcessor, CoreDataService
│   └── Views/                InboxView, MessageDetailView, ComposeView, SettingsView, …
├── Tests/iMailSecureTests/   Unit Tests
├── project.yml               XcodeGen-Quelle (verbindlich)
└── Package.swift             SwiftPM-Definition (gleiche Pins wie project.yml)
```

---

## Setup

### Voraussetzungen

- macOS mit Xcode 16 oder neuer (getestet mit Xcode 27.1, Swift 6.4)
- iOS 18 SDK
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

### Projekt öffnen

```bash
cd ~/XCODE/Fair-iMail
xcodegen generate
open iMailSecure.xcodeproj
```

`iMailSecure.xcodeproj` ist **generiert**. Änderungen an Targets, Dateien oder Paketen
gehören in `project.yml`, danach `xcodegen generate` erneut ausführen.

### Bauen und testen

```bash
xcodebuild -scheme iMailSecure \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build

xcodebuild -scheme iMailSecure \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' test
```

---

## Datenschutz-Leitsätze

Verbindlich dokumentiert in [AGENTS.md](AGENTS.md). Kurzfassung:

1. Keine Telemetrie, keine Analytics-, Crash- oder Werbe-SDKs
2. Kein Klartext, kein TLS-Downgrade — fail-closed
3. Remote-Inhalte standardmäßig blockiert
4. Keine Mail-Inhalte in Logs
5. Secrets nur im Keychain (`ThisDeviceOnly`), Kontodaten mit Dateischutz
6. Keine Daten an Dritte, keine Keyserver-Abfragen ohne Nutzeraktion
7. Tracking-Parameter entfernen, Ziele im Klartext bestätigen
8. Anhänge: Pfad-Sanitizing, eigener UUID-Ordner, FileProtection, Cleanup
9. Fehler nicht verschlucken
10. Schalter müssen wirken — UI-Toggle ohne Konsument ist ein Bug

---

## App Store Checklist

- [x] Datenschutz-Manifest (`PrivacyInfo.xcprivacy`, `NSPrivacyTracking = false`)
- [x] Passwörter nur im Keychain (kein UserDefaults, kein NSLog)
- [x] Keine externen Tracker
- [x] `NSAllowsArbitraryLoads = false` (ATS aktiv)
- [ ] **Datenschutzerklärung erreichbar** — `fairimail.io` ist derzeit nicht registriert
      bzw. ohne DNS. Ohne erreichbare Privacy-URL keine Freigabe.
- [ ] Support-Adresse funktionsfähig (`support@fairimail.io`)
- [ ] Code Signing: Apple Developer Account
- [ ] Provisioning Profile und Bundle ID: `io.imailsecure.app`
- [ ] Icons in Assets.xcassets (1024×1024)
- [ ] Screenshots für alle unterstützten Geräte
- [ ] TestFlight-Beta vor Einreichung
- [x] Lizenzentscheidung L1 getroffen: PolyForm Noncommercial 1.0.0
- [ ] Eigene EULA in App Store Connect hinterlegen (sonst gilt Apples Standard-EULA)

---

## Lizenz

## Lizenz

**PolyForm Noncommercial 1.0.0** (entschieden am 2026-11-01, Option B):

- Der Quellcode ist **einsehbar und nachprüfbar**, aber **keine kommerzielle
  Nutzung durch Dritte** — weder Verkauf noch Bezahl-Angebote noch
  geschäftlicher Einsatz durch Lizenznehmer.
- Das ist **kein Open Source** und darf auch nicht so genannt werden.
- Der Rechteinhaber selbst darf die App kommerziell vertreiben; die eigene
  Lizenz bindet ihn nicht.
- Beiträge werden nur unter der [CLA](CLA.md) angenommen, damit die
  kommerzielle Verwertung nicht durch einzelne Beitragende blockiert wird.

Warum nicht GPL, was das im App Store bedeutet (eigene EULA!) und welche
Alternative es gibt, steht in [LICENSING.md](LICENSING.md).
