# STATE — iMail Secure
Stand: 2026-11-13 · Branch: `main` · Letzter Commit: `e42560b` · Build: **SUCCEEDED** · Tests: **126 grün**

## Ziel
App-Store-fähige Version: echte IMAP-Ordner, Datenschutz nach D2, Free/Pro ohne
beschnittene Schutzfunktionen. Keine offenen Code-Fehler bekannt.

## Offen (max. 5, nach Schwere)
| # | Datei:Zeile | Symptom | Soll | Status |
|---|---|---|---|---|
| 1 | `Views/PaywallView.swift`, `FolderListView.swift` | Kauf und Ordner-anlegen sind im Simulator noch nicht durchgeklickt | mit `iMailSecure.storekit`: Pro kaufen, Ordner anlegen/umbenennen/löschen | offen |
| 2 | `imailsecure-site/terms.html` | Nutzungsbedingungen sind Entwurf, nicht anwaltlich geprüft; eigener EULA-Text für App Store Connect fehlt | juristisch prüfen, EULA erstellen, in Connect hinterlegen | Entwurf veröffentlicht |
| 3 | App Store Connect | Produkte, Abo-Gruppe, 7-Tage-Offer und eigene EULA fehlen | mit Apple-Developer-Account anlegen | offen |
| 4 | `imailsecure-site/*.html` | Website-Rechtstexte nur auf Deutsch | ES/FR/RU/TR ergänzen, wenn die Store-Einträge live gehen | offen |
| 5 | `~/.config/opencode/opencode.jsonc` | OpenRouter-Guthaben 0 (Key-Limit 100 ist kein Guthaben) | aufladen oder DeepSeek-Ausfall akzeptieren | offen |

## Offene Entscheidungen
- S5 OAuth 2.0 · S6 Entwürfe speichern · C1 PGP/S-MIME
- L1 Lizenz: entschieden (PolyForm Noncommercial 1.0.0), juristische Prüfung steht aus

## Zuletzt erledigt
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
1. Im Simulator mit `iMailSecure.storekit` durchklicken: Pro und Lifetime kaufen,
   danach einen eigenen Ordner anlegen, umbenennen und löschen. Ergebnis hier notieren.
2. `terms.html` juristisch prüfen lassen und die Entwurfs-Kennzeichnung entfernen;
   EULA-Text für App Store Connect erstellen lassen.
3. App-Store-Produkte, Introductory Offer und EULA in App Store Connect anlegen;
   danach die sechs lokalisierten Store-Einträge aus `fastlane/metadata/` übernehmen.
4. Website-Rechtstexte ES/FR/RU/TR ergänzen (`imailsecure-site/*.html`).
5. Screenshots je Sprache und Geräteklasse erstellen.
