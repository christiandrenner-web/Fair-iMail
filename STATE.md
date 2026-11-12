# STATE — iMail Secure
Stand: 2026-11-12 · Branch: `main` · Letzter Code-Commit: `240bf3d` · Build: **SUCCEEDED**

## Ziel
App-Store-fähige Version: echte IMAP-Ordner, Datenschutz nach D2, Free/Pro ohne
beschnittene Schutzfunktionen. Keine offenen Code-Fehler bekannt.

## Offen (max. 5, nach Schwere)
| # | Datei:Zeile | Symptom | Soll | Status |
|---|---|---|---|---|
| 1 | — | Kein echter IMAP-End-to-End-Test mit realem Konto | Ordnerliste, Ordnerwechsel, Anlegen/Umbenennen/Löschen, MOVE in Papierkorb, Gmail-Labels prüfen | offen |
| 2 | `imailsecure-site/terms.html` | Nutzungsbedingungen sind Entwurf, nicht anwaltlich geprüft | juristisch prüfen lassen, dann Badge + Hinweiskasten entfernen | Entwurf veröffentlicht |
| 3 | App Store Connect | Produkte, Abo-Gruppe, 7-Tage-Offer und eigene EULA fehlen | mit Apple-Developer-Account anlegen | offen |
| 4 | `~/.config/opencode/opencode.jsonc` | OpenRouter-Guthaben 0 (Key-Limit 100 ist kein Guthaben) | aufladen oder DeepSeek-Ausfall akzeptieren | offen |

## Offene Entscheidungen
- S5 OAuth 2.0 · S6 Entwürfe speichern · C1 PGP/S-MIME
- L1 Lizenz: entschieden (PolyForm Noncommercial 1.0.0), juristische Prüfung steht aus

## Zuletzt erledigt
- 2026-11-12 `terms.html` entworfen und veröffentlicht (AGB, Abo, Widerruf, Lizenz);
  Entwurf gekennzeichnet, anwaltliche Prüfung offen
- 2026-11-12 GitHub veröffentlicht: `Fair-iMail` + `imailsecure-site`, Pages live,
  Kontaktadresse `chr.renner@mein.gmx` eingesetzt (`cd00da4`, `240bf3d`)
- 2026-11-11 `2db25c1` SwiftMail 1.16.0, Ordner umbenennen/löschen (109 Tests)
- 2026-11-11 `c41fa69` `defaultRequestMDN` wirkt jetzt in `ComposeViewModel` (103 Tests)
- 2026-11-03 `68e246b` IMAP-Ordner, Papierkorb, gemeinsamer Posteingang
- 2026-11-02 `52f2d99` Free/Pro (StoreKit 2), Apple-Trial, Multi-Account-Fix

## Nächster Schritt
1. Echten IMAP-Test mit einem Testkonto durchführen (Gmail und ein lokalisierter Server).
2. `terms.html` juristisch prüfen lassen und die Entwurfs-Kennzeichnung entfernen.
3. App-Store-Produkte, Introductory Offer und EULA in App Store Connect anlegen.
