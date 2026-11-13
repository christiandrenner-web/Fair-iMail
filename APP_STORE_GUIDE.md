# App Store Einreichung – iMail Secure
## Schritt-für-Schritt-Checkliste

---

## 1. Apple Developer Account
- [ ] Apple Developer Program beitreten ($99/Jahr): https://developer.apple.com/programs/
- [ ] Bundle ID registrieren: `io.imailsecure.app` (App IDs → Register)
- [ ] Kein Push-Zertifikat nötig: Benachrichtigungen sind nicht implementiert und derzeit nicht geplant

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
2. Name: **iMail Secure**
3. Primary Language: **German**
4. Bundle ID: `io.imailsecure.app`
5. SKU: `imailsecure-ios-1`
6. **Lizenzvereinbarung (EULA):** eigene EULA hinterlegen — sonst gilt Apples
   Standard-EULA und die Nicht-kommerziell-Klausel der PolyForm-Lizenz greift
   gegenüber App-Store-Nutzern nicht (siehe `LICENSING.md`, Abschnitt 3.1)

### Abos (StoreKit)

Details und Begründung: `MONETIZATION.md`.

- [ ] Abo-Gruppe **„iMail Secure Pro"** anlegen
- [ ] Produkt `io.imailsecure.pro.monthly` — 2,99 €, Laufzeit 1 Monat
- [ ] Produkt `io.imailsecure.pro.yearly` — 24,99 €, Laufzeit 1 Jahr
- [ ] Non-Consumable `io.imailsecure.pro.lifetime` — 39,99 €, einmalig
- [ ] Familienfreigabe für Abo-Gruppe und Lifetime aktivieren
- [ ] Einführungsangebot je Produkt: **kostenlose Testphase, 1 Woche**
      (Apple macht den Trial — die App enthält bewusst keine Trial-Logik)
- [ ] Beide Produkte zum Review einreichen, Screenshot der Paywall beilegen
- [x] **Nutzungsbedingungen** unter einer öffentlichen URL veröffentlicht
      (https://christiandrenner-web.github.io/imailsecure-site/terms.html,
      geprüft 2026-11-12); in App Store Connect noch zu hinterlegen — dort
      zählt die EULA, nicht die Website
- [ ] „Käufe wiederherstellen" prüfen (in Einstellungen und Paywall vorhanden)
- [ ] Apple-Kleinstunternehmerprogramm beantragen (15 % statt 30 %)
- [ ] Steuer- und Bankdaten hinterlegen, sonst keine Auszahlung

Testen ohne Developer-Account: `iMailSecure.storekit` ist im Scheme hinterlegt
(Xcode → Product → Scheme → Edit Scheme → Run → Options).

### Metadaten (DE)
```
Name:           iMail Secure
Untertitel:     Datenschutz-E-Mail-Client
Kategorie:      Produktivität

Beschreibung:
iMail Secure ist ein datenschutzfreundlicher E-Mail-Client für iOS, 
der vollständige IMAP/SMTP-Unterstützung mit Lesebestätigungen 
nach RFC 8098 (MDN) bietet – ohne Tracking, ohne Werbung, 
ohne Datenweitergabe an Dritte.

Funktionen:
• IMAP/SMTP-Unterstützung für alle Anbieter
• Alle IMAP-Ordner, auch eigene (Pro)
• Mehrere Konten und gemeinsamer Posteingang (Pro)
• Lesebestätigungen (MDN/RFC 8098)
• Empfangsbestätigungen
• Passwörter ausschließlich im iOS-Keychain
• HTML nur auf Knopfdruck, externe Inhalte blockiert
• Kein Tracking, keine Werbung, keine Telemetrie
• Quellcode einsehbar (PolyForm Noncommercial 1.0.0)

Keywords: E-Mail, Mail, Datenschutz, IMAP, SMTP, MDN, Lesebestätigung,
          sicher, privat, Tracking-Schutz

Support-URL:    https://christiandrenner-web.github.io/imailsecure-site/support.html
Marketing-URL:  https://christiandrenner-web.github.io/imailsecure-site/
Datenschutz:    https://christiandrenner-web.github.io/imailsecure-site/privacy.html
Nutzungsbed.:   https://christiandrenner-web.github.io/imailsecure-site/terms.html
```

### Lokalisierte Store-Einträge (6 Sprachen)

Die App-Oberfläche ist auf Deutsch, Englisch, Spanisch, Französisch, Russisch und
Türkisch lokalisiert (`Localizable.xcstrings`, `InfoPlist.xcstrings`). Die
Store-Texte liegen fertig in `fastlane/metadata/`:

| Ordner   | Sprache   | Untertitel                          |
|----------|-----------|-------------------------------------|
| `de-DE`  | Deutsch   | Datenschutz-E-Mail-Client           |
| `en-US`  | Englisch  | Privacy-first email client          |
| `es-ES`  | Spanisch  | Cliente de correo privado           |
| `fr-FR`  | Französisch | Client e-mail confidentiel        |
| `ru`     | Russisch  | Почта без слежки и трекинга         |
| `tr`     | Türkisch  | Gizlilik odaklı e-posta             |

Je Sprache: `name.txt`, `subtitle.txt`, `keywords.txt`, `description.txt`,
`promotional_text.txt`, `release_notes.txt`, `support_url.txt`,
`marketing_url.txt`, `privacy_url.txt`. Upload mit fastlane (einmalig `brew install fastlane`):

```bash
fastlane run deliver --skip_binary_upload --skip_screenshots
```

Ohne fastlane: Inhalte in App Store Connect → App-Informationen →
„Sprache hinzufügen" je Sprache einkopieren. Screenshots müssen pro Sprache
und Geräteklasse separat hochgeladen werden (mindestens Deutsch und Englisch
sind Pflicht, die übrigen Sprachen erhöhen die Sichtbarkeit in den Märkten).

`fastlane/metadata/review_information/notes.txt` erklärt der Review, dass ein
echtes IMAP-Konto nötig ist. **Vor der Einreichung** dort ein Testkonto
eintragen (`demo_user.txt`, `demo_password.txt`, `email_address.txt`) — sonst
kann Apple den Login nicht prüfen.

Der Anzeigename bleibt in allen Sprachen „iMail Secure". Die Rechtstexte
(`privacy.html`, `terms.html`) sind derzeit nur auf Deutsch; für die übrigen
Märkte sollten sie vor dem Livegang übersetzt werden.

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
- [x] Datenschutzerklärung erreichbar unter der angegebenen URL
      (https://christiandrenner-web.github.io/imailsecure-site/privacy.html, geprüft 2026-11-12)
- [x] Nutzungsbedingungen erreichbar (`terms.html`, Pflicht bei Abos) — Entwurf
- [ ] Alle Berechtigungen in Info.plist begründet
- [ ] PrivacyInfo.xcprivacy vollständig ✅
- [ ] Keine Abstürze im Simulator (cmd+U → alle Tests grün)
- [ ] App funktioniert auf iPhone und iPad

---

## 9. Nach der Veröffentlichung

- [x] Quellcode veröffentlicht: <https://github.com/christiandrenner-web/iMailSecure>
      (die PolyForm-Lizenz verpflichtet **nicht** dazu; ohne Veröffentlichung
      wäre die Aussage „nachprüfbar" aber unbelegt)
- [ ] `CHANGELOG.md` pflegen
- [ ] **Kein** Crash-Reporting-SDK einbinden (Crashlytics/Sentry verstoßen
      gegen Leitsatz 1 in `AGENTS.md`)
- [ ] Regelmäßige Updates: Apple erwartet aktive Wartung
