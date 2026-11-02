# CLAUDE.md — iMail Secure

@AGENTS.md

Die Regeln in `AGENTS.md` gelten vollständig. Diese Datei enthält nur, was für Claude
zusätzlich relevant ist.

## Projektgedächtnis

- `AUDIT_NOTES.md` — alle Befunde N1…C1 mit Status. **Am Anfang jeder Session lesen.**
- `AGENTS.md` — verbindliche Datenschutz-Leitsätze und Arbeitsweise.
- `LICENSING.md` — Lizenz-/App-Store-Analyse (offene Entscheidung L1).
- `git log` — was zuletzt passiert ist. Bei Widersprüchen gilt das Repo, nicht der Chat.

## Git

Das Verzeichnis ist ein Git-Repo (`main`). Der Git-MCP-Server ist auf dieses Repo
beschränkt (`git_status`, `git_diff`, `git_log`, `git_commit`, …).

Pflicht:
1. Vor der Arbeit: `git_status` — unerwartete Änderungen zuerst ansprechen.
2. Nach jeder abgeschlossenen Änderung: `git_add` + `git_commit` mit sprechender Nachricht.
3. Behauptungen wie „baut durch" nur nach tatsächlichem Build — sonst als ungeprüft kennzeichnen.

## Build-Validierung (Hook)

Nach jedem nicht-trivialen Code-Edit sofort bauen und testen:

```bash
# Bauen
xcodebuild -scheme iMailSecure \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build \
  2>&1 | grep -E 'error:|Build succeeded|FAILED'

# Testen (nach Logikänderungen)
xcodebuild -scheme iMailSecure \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' test \
  2>&1 | grep -E 'Test Suite .All tests|passed|failed|FAILED' | tail -3

# Graph aktualisieren (nach Swift-Änderungen)
uvx --from graphifyy graphify . --code-only 2>&1 | tail -2
```

Ein Commit darf erst erfolgen, wenn Build und Tests grün sind.
Behauptungen wie "baut durch" nur nach tatsächlichem Build-Log.

## Was in der Vergangenheit schiefging

- Aussagen wie „Domain ist deine echte" ohne DNS-Prüfung. **Externe Fakten verifizieren,
  nicht annehmen.**
- Ein Security-Claim („Ports 993 und 465 abgedeckt"), der im Code nur für IMAP galt.
  **Claim gegen Aufrufstellen prüfen (`grep`), nicht gegen Kommentare.**
- Ein UI-Button, den es nicht gab (`resetPin` ohne Aufrufer). **Toten Code nicht als
  „vorbereitet" verkaufen.**
- `project.yml` und `pbxproj` liefen auseinander (SwiftMail-Pin).

## Kommunikation

Deutsch. Knapp, konkret, mit Dateipfaden und Zeilennummern. Unsicherheiten benennen statt
überspielen.
