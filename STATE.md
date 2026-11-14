# STATE — iMail Secure
Stand: 2026-11-14 · Branch: `main` · Letzter Code-Commit: `e870002` · Build: **SUCCEEDED** · Tests: **130 Unit-Tests (4 übersprungen) + 3 UI-Tests grün**

## Ziel
App-Store-fähige Version: echte IMAP-Ordner, Datenschutz nach D2, Free/Pro ohne
beschnittene Schutzfunktionen. Keine offenen Code-Fehler bekannt.

## Offen (max. 5, nach Schwere)
| # | Datei:Zeile | Symptom | Soll | Status |
|---|---|---|---|---|
| 1 | `Tests/iMailSecureTests/StoreKitPurchaseTests.swift` | Kaufpfad im Simulator nicht automatisch prüfbar: `xcodebuild` übergibt die StoreKit-Testkonfiguration nicht, `storekitd` fragt die Produktions-API | einmal in Xcode (Run mit `iMailSecure.storekit`) oder im Sandbox-Konto kaufen; Tests sind bis dahin per `IMAIL_STOREKIT_TESTS=1` opt-in | blockiert (Umgebung) |
| 2 | `imailsecure-site/terms.html` | Nutzungsbedingungen sind Entwurf, nicht anwaltlich geprüft; eigener EULA-Text für App Store Connect fehlt | juristisch prüfen, EULA erstellen, in Connect hinterlegen | Entwurf veröffentlicht |
| 3 | App Store Connect | Produkte, Abo-Gruppe, 7-Tage-Offer und eigene EULA fehlen | mit Apple-Developer-Account anlegen | offen |
| 4 | `imailsecure-site/*.html` | Website-Rechtstexte nur auf Deutsch | ES/FR/RU/TR ergänzen, wenn die Store-Einträge live gehen | offen |
| 5 | App Store Connect | Screenshots liegen in `fastlane/screenshots/` (6 Sprachen × 2 Geräte × 4 Motive) | mit `fastlane deliver` hochladen, sobald der Account steht | fertig |

## Offene Entscheidungen
- S5 OAuth 2.0 · S6 Entwürfe speichern · C1 PGP/S-MIME
- L1 Lizenz: entschieden (PolyForm Noncommercial 1.0.0), juristische Prüfung steht aus

## Zuletzt erledigt
- 2026-11-14 Gesamtlauf grün: 130 Unit-Tests (4 StoreKit-Tests opt-in, übersprungen)
  und 3 UI-Tests (`FolderManagementUITests` ×2, `ScreenshotUITests`) auf dem
  iPad-Simulator. Vorher fielen drei Unit-Tests auf Türkisch um, weil der
  Screenshot-Lauf die Systemsprache des Simulators umstellt — die Test-Action
  pinnt jetzt `de`/`DE` (`project.yml`), unabhängig von der Gerätesprache.
  Ein UI-Lauf direkt nach dem Sprachwechsel scheiterte einmal mit „Ordner
  wurden nicht geladen“/leerem Posteingang; die beiden Läufe danach waren grün.
  Beobachten, ob das wieder auftritt (verdächtig: Zustand direkt nach
  Simulator-Neustart, nicht der Code)
- 2026-11-14 Screenshot-Satz geprüft: In `es-ES` und `tr` war das iPhone-Motiv
  „Nachricht“ pixelgleich mit dem Posteingang — der Tipp auf die Zeile hatte
  nicht navigiert, der Test fotografierte stillschweigend weiter. Behoben:
  Detailansicht hat den Anker `detail.root`, `openNewestMessage` tippt bei
  Bedarf erneut, und der Screenshot-Test schlägt fehl, statt eine Dublette
  abzulegen. Beide Sprachen neu aufgenommen, alle 48 Bilder unterscheiden
  sich jetzt paarweise (geprüft über Helligkeit und Pixelvergleich)
- 2026-11-13 Screenshots für sechs Sprachen und zwei Geräteklassen erzeugt
  (`fastlane screenshots`, 48 Bilder). Demo-Postfach und eigene Ordner werden
  je Sprache neu angelegt; Systemsprache der Simulatoren wird mitgesetzt,
  damit das iPad-Datum zur Sprache passt
- 2026-11-13 Schreib-Knopf erscheint nur noch im Posteingang — in den
  Einstellungen verdeckte er Formulare und Fußnoten
- 2026-11-13 Simulator-Durchklick: `FolderManagementUITests` bestehen —
  Ordner anlegen, umbenennen, löschen (serverseitig geprüft) und Free-Gate
  öffnet die Paywall. Neues UI-Test-Target `iMailSecureUITests`
- 2026-11-13 Screenshot-Pipeline: `fastlane snapshot` (Snapfile: 6 Sprachen ×
  iPhone 17 Pro Max / iPad Pro 13"), vier Motive je Sprache und Gerät,
  Demo-Mails im Testkonto, Pro über `-imaailTier pro` (nur `#if DEBUG`)
- 2026-11-13 Erkenntnis dokumentiert: `xcodebuild` schreibt
  `StoreKitConfigurationFileReference` nicht in die Test-Action/den
  `xctestrun`; `SKTestSession` liefert im iOS-26-Simulator `notEntitled`.
  `StoreKitPurchaseTests` sind deshalb opt-in (`IMAIL_STOREKIT_TESTS=1`)
- 2026-11-13 Lifetime-Produkt repariert: `isPro` und Kontolimit gelten jetzt auch für
  `Tier.lifetime` (`isEffectivelyPro`) — vorher blieb die Paywall offen und Pro war
  gesperrt. Tests für Lifetime ergänzt, 126 grün
- 2026-11-13 Paywall: „pro Monat/Jahr" erscheint nicht mehr beim Einmalkauf,
  Abo-Hinweis nur bei Abo-Produkten, eigener Lifetime-Hinweis; türkische
  Übersetzung `period.lifetime` war verstümmelt (Devanagari) und ist korrigiert
- 2026-11-13 Preise an den neuen Stand angeglichen (2,99 €/Monat, 24,99 €/Jahr,
  39,99 € Lifetime) in Store-Beschreibungen, App-Store-Guide, Audit-Notizen
- 2026-11-13 StoreKit-Konfiguration: Lifetime familienfreigabefähig, Produktnamen
  und -beschreibungen für alle sechs Sprachen
- 2026-11-12 Gmail-End-to-End bestanden (`mailprivacy.imail@gmail.com`, App-Passwort):
  TLS 1.2, Login, 9 Ordner, 5 Nachrichten, Anlegen/Umbenennen/Löschen mit Umlaut,
  APPEND, MOVE in `[Gmail]/Papierkorb`, UID EXPUNGE, keine Testordner zurück
- 2026-11-12 SMTP-Versand real bestätigt (`Tools/IMAPProbe --smtp`, 587 STARTTLS)
- 2026-11-12 Fehler gefunden und behoben: `[Gmail]/Wichtig` (\Important) wurde als
  „Markiert" erkannt; neue Rolle `.important` („Wichtig") statt Namens-Fallback
  auf `flagged`, 121 Tests grün
- 2026-11-12 Oberfläche in sechs Sprachen: `Localizable.xcstrings` (233 Einträge,
  Quellsprache Deutsch) und `InfoPlist.xcstrings` (Face-ID-Text, Anzeigename).
  Alle Modell- und Fehlertexte laufen über `String(localized:)`; Build enthält
  `de/en/es/fr/ru/tr.lproj`, 121 Tests grün
- 2026-11-12 `fastlane/metadata/` für de-DE, en-US, es-ES, fr-FR, ru, tr angelegt
  (Name, Untertitel, Keywords, Beschreibung, Promotional Text, Release Notes, URLs)
  plus `review_information/notes.txt`; Längenlimits geprüft
- 2026-11-12 GitHub-Repo `Fair-iMail` → `iMailSecure` umbenannt (alte URL leitet
  per 301 weiter), Quellcode-Link in App und Website angepasst
- 2026-11-12 Echter IMAP-Test gegen `imap.gmx.net` bestanden (Tools/IMAPProbe):
  Ordner, Rollen, Umbenennen, MOVE, UID EXPUNGE. Dabei zwei Fehler gefunden und
  behoben: modified UTF-7 in Ordnernamen und doppelte Systemordner bei GMX
- 2026-11-12 `terms.html` entworfen und veröffentlicht (AGB, Abo, Widerruf, Lizenz);
  Entwurf gekennzeichnet, anwaltliche Prüfung offen
- 2026-11-12 GitHub veröffentlicht: `iMailSecure` + `imailsecure-site`, Pages live,
  Kontaktadresse `chr.renner@mein.gmx` eingesetzt (`cd00da4`, `240bf3d`)
- 2026-11-11 `2db25c1` SwiftMail 1.16.0, Ordner umbenennen/löschen (109 Tests)
- 2026-11-11 `c41fa69` `defaultRequestMDN` wirkt jetzt in `ComposeViewModel` (103 Tests)
- 2026-11-03 `68e246b` IMAP-Ordner, Papierkorb, gemeinsamer Posteingang
- 2026-11-02 `52f2d99` Free/Pro (StoreKit 2), Apple-Trial, Multi-Account-Fix

## Nächster Schritt
1. Screenshots in App Store Connect hochladen (`fastlane deliver`), sobald der
   Developer-Account steht — die 48 Bilder sind fertig und geprüft.
2. Kaufpfad einmal in Xcode mit `iMailSecure.storekit` durchklicken (Pro, Lifetime,
   Wiederherstellen) und das Ergebnis hier notieren; alternativ im Sandbox-Konto.
3. `terms.html` juristisch prüfen lassen und die Entwurfs-Kennzeichnung entfernen;
   EULA-Text für App Store Connect erstellen lassen.
4. App-Store-Produkte, Introductory Offer und EULA in App Store Connect anlegen;
   danach die sechs lokalisierten Store-Einträge aus `fastlane/metadata/` übernehmen.
5. Website-Rechtstexte ES/FR/RU/TR ergänzen (`imailsecure-site/*.html`).
