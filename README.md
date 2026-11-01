# iMail secure

Datenschutzfreundlicher E-Mail-Client für iOS 18+  
Lizenz: GPL-3.0

---

## Features

- Vollständige IMAP/SMTP-Unterstützung (SwiftMail)
- Lesebestätigungen nach RFC 8098 (MDN)
- Empfangsbestätigungen (Return-Receipt-To)
- Passwörter ausschließlich im iOS-Keychain
- Kein Tracking, keine Werbung, keine Drittanbieter
- Offline-fähig (Core Data)
- iOS 18+, SwiftUI

---

## Projektstruktur

```
Fair-iMail/
├── Sources/iMailSecure/
│   ├── App/                  iMailSecureApp.swift, ContentView.swift
│   ├── Models/               EmailAccount, EmailMessage, EmailDraft, MDNNotification
│   ├── Managers/             AccountStore, MailStore, MailSyncEngine, SMTPManager, KeychainManager
│   ├── Services/             EmailHeaderBuilder, MDNProcessor, CoreDataService
│   └── Views/                InboxView, MessageDetailView, ComposeView, SettingsView, …
├── Tests/iMailSecureTests/   Unit Tests
├── iMailSecure.xcodeproj
└── Package.swift
```

---

## Setup

### Voraussetzungen

- Xcode 16+
- iOS 18 SDK
- Swift 5.9+

### Projekt öffnen

```bash
git clone https://github.com/yourusername/iMailSecure.git
cd iMailSecure
open Package.swift
```

Xcode löst die SwiftMail- und swift-log-Dependencies automatisch auf.

---

## SwiftMail-Integration

Die `MailSyncEngine` und der `SMTPManager` enthalten Platzhalter-Blöcke,  
die aktiviert werden, sobald SwiftMail 1.0 final verfügbar ist.  
Suche nach `// ── SwiftMail-Integration ──` in den Dateien und ersetze  
den Demo-Block durch die echten SwiftMail-Aufrufe.

---

## App Store Checklist

- [x] Datenschutzerklärung (Privacy Policy URL in AccountSetupView hinterlegt)
- [x] Passwörter nur im Keychain (kein UserDefaults, kein NSLog)
- [x] Keine externen Tracker
- [x] `NSFaceIDUsageDescription` in Info.plist eintragen (falls Biometrie später)
- [ ] `NSAppTransportSecurity` in Info.plist konfigurieren (IMAP/SMTP benötigt TLS)
- [ ] Code Signing: Apple Developer Account ($99/Jahr)
- [ ] Provisioning Profile und Bundle ID setzen: `io.imailsecure.app`
- [ ] Icons in Assets.xcassets hinterlegen (1024×1024 für App Store)
- [ ] Screenshots für alle unterstützten Geräte anfertigen
- [ ] TestFlight Beta-Test vor Einreichung

---

## Lizenz

GPL-3.0 – Quellcode muss bei Weitergabe offengelegt werden.
