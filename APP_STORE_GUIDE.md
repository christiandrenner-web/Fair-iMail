# App Store Einreichung – iMail secure
## Schritt-für-Schritt-Checkliste

---

## 1. Apple Developer Account
- [ ] Apple Developer Program beitreten ($99/Jahr): https://developer.apple.com/programs/
- [ ] Bundle ID registrieren: `io.imailsecure.app` (App IDs → Register)
- [ ] Push-Zertifikat erstellen (für Phase 3 – Benachrichtigungen)

---

## 2. Projekt in Xcode einrichten

```bash
brew install xcodegen
xcodegen generate --spec project.yml
open iMailSecure.xcodeproj
```

Danach in Xcode:
- [ ] **Signing & Capabilities** → Team auswählen
- [ ] **Bundle Identifier**: `io.imailsecure.app`
- [ ] **Deployment Target**: iOS 18.0
- [ ] Entitlements verknüpft: `Sources/iMailSecure/Resources/iMailSecure.entitlements`
- [ ] CoreData-Modell im Projekt referenziert

---

## 3. App-Icon erstellen

Benötigt wird eine einzige Quelldatei: **1024 × 1024 px PNG, keine Transparenz**.  
Alle anderen Größen werden automatisch exportiert.

Tools:
- [AppIconGenerator.com](https://appicongenerator.com/) (kostenlos)
- Sketch / Figma mit iOS-Icon-Template
- SF Symbol `envelope.shield.fill` als Basis

Alle generierten PNG-Dateien in:
```
Sources/iMailSecure/Resources/Assets.xcassets/AppIcon.appiconset/
```

---

## 4. Screenshots anfertigen

App Store Connect benötigt Screenshots für:
| Gerät                  | Größe          |
|------------------------|----------------|
| iPhone 6.9" (Pro Max)  | 1320 × 2868 px |
| iPhone 6.7" (Plus)     | 1290 × 2796 px |
| iPhone 6.5"            | 1242 × 2688 px |
| iPad Pro 13"           | 2064 × 2752 px |
| iPad Pro 11"           | 1668 × 2388 px |

Empfohlen: Simulator-Screenshots + [Previewed.app](https://previewed.app) für schöne Rahmengrafiken.

---

## 5. App Store Connect

1. Neuen App-Eintrag anlegen: https://appstoreconnect.apple.com
2. Name: **iMail secure**
3. Primary Language: **German**
4. Bundle ID: `io.imailsecure.app`
5. SKU: `imailsecure-ios-1`

### Metadaten (DE)
```
Name:           iMail secure
Untertitel:     Datenschutz-E-Mail-Client
Kategorie:      Produktivität

Beschreibung:
iMail secure ist ein datenschutzfreundlicher E-Mail-Client für iOS, 
der vollständige IMAP/SMTP-Unterstützung mit Lesebestätigungen 
nach RFC 8098 (MDN) bietet – ohne Tracking, ohne Werbung, 
ohne Datenweitergabe an Dritte.

Funktionen:
• IMAP/SMTP-Unterstützung für alle Anbieter
• Lesebestätigungen (MDN/RFC 8098)
• Empfangsbestätigungen
• Passwörter ausschließlich im iOS-Keychain
• Kein Tracking, keine Werbung
• Open Source (GPL-3.0)

Keywords: E-Mail, Mail, Datenschutz, IMAP, SMTP, MDN, Lesebestätigung, 
          Open Source, sicher, privat

Support-URL:    https://fairimail.io/support
Marketing-URL:  https://fairimail.io
Datenschutz:    https://fairimail.io/privacy
```

---

## 6. Build archivieren & hochladen

```bash
# In Xcode:
# Product → Archive → Distribute App → App Store Connect → Upload
```

Oder per CLI:
```bash
xcodebuild archive \
  -scheme "iMailSecure" \
  -configuration Release \
  -archivePath ./build/iMailSecure.xcarchive

xcodebuild -exportArchive \
  -archivePath ./build/iMailSecure.xcarchive \
  -exportPath ./build/export \
  -exportOptionsPlist ExportOptions.plist
```

---

## 7. TestFlight Beta-Test

- [ ] Build in App Store Connect → TestFlight hochladen
- [ ] Interne Tester hinzufügen (bis 100 Personen)
- [ ] Externe Tester (bis 10.000) nach Apple-Review
- [ ] Mindestens 1 Woche Beta-Test empfohlen

---

## 8. App Store Review

Apple prüft die App in der Regel innerhalb von 24–48 Stunden.

### Häufige Ablehnungsgründe vermeiden:
- [ ] `ITSAppUsesNonExemptEncryption = false` in Info.plist ✅ (bereits gesetzt)
- [ ] Datenschutzerklärung erreichbar unter der angegebenen URL
- [ ] Alle Berechtigungen in Info.plist begründet
- [ ] PrivacyInfo.xcprivacy vollständig ✅
- [ ] Keine Abstürze im Simulator (cmd+U → alle Tests grün)
- [ ] App funktioniert auf iPhone und iPad

---

## 9. Nach der Veröffentlichung

- [ ] GitHub-Repository öffentlich schalten (GPL-3.0 verpflichtet dazu)
- [ ] `CHANGELOG.md` pflegen
- [ ] Crashlytics / Sentry (datenschutzkonform) optional einbinden
- [ ] Regelmäßige Updates: Apple erwartet aktive Wartung
