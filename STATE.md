# STATE — iMail Secure
Stand: 2026-11-03 · Branch: `main` · Letzter Commit: `68e246b` · Build: **SUCCEEDED**

## Ziel
Grundgerüst steht. Leere Schalter und fehlerhafte Xcode-Abfragen korrigieren.

## Offen (max. 5, nach Schwere)
| # | Datei:Zeile | Symptom | Soll | Status |
|---|---|---|---|---|
| 1 | `Sources/iMailSecure/Views/SettingsView.swift:111` | Toggle `defaultRequestMDN` schreibt nur `@AppStorage`; kein Leser im Code → Schalter wirkungslos | `ComposeViewModel` initialisiert `draft.requestMDN` aus `UserDefaults` | offen |
| 2 | `AUDIT_NOTES.md:288` | L1 „offen", `AGENTS.md` („Offene Architekturentscheidungen") sagt „entschieden (Option B)" | eine Quelle festlegen, andere nachziehen | offen |
| 3 | `AUDIT_NOTES.md:26` | `SettingsView` als „Schalter ohne Wirkung" geführt | nach Fix #1 Zeile aktualisieren | offen |

## Offene Entscheidungen
- S5 OAuth 2.0 · S6 Entwürfe speichern · C1 PGP/S-MIME · L1 Lizenz/App Store (`LICENSING.md`)

## Zuletzt erledigt
- 2026-11-03 `68e246b` IMAP-Ordner, Papierkorb, gemeinsamer Posteingang
- 2026-11-02 `52f2d99` Free/Pro (StoreKit 2), Apple-Trial, Multi-Account-Fix
- 2026-11-02 `d6f66d2` Build-Validierungs-Hook in `CLAUDE.md`

## Nächster Schritt
1. #1 fixen (Konsument für `defaultRequestMDN`).
2. Build + Test laut Hook; Ergebnis hier und in `AUDIT_NOTES.md` eintragen.
