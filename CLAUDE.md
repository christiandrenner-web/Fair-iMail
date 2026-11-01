# CLAUDE.md — iMail secure

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
