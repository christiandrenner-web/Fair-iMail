# AGENTS.md — iMail Secure

Verbindliche Regeln für **jeden** Assistenten (OpenCode, Claude Code/Desktop, …), der in
diesem Repository arbeitet. Diese Datei ist die Quelle der Wahrheit für Arbeitsweise und
Datenschutz-Leitsätze. `CLAUDE.md` verweist nur hierher.

## Projekt

Datenschutzfreundlicher E-Mail-Client für iOS (SwiftUI, IMAP/SMTP über SwiftMail).
Vorbild und Messlatte: **FairEmail** von Marcel Bokhorst.
Ziel ist keine „E-Mail-App mit Privacy-Feature", sondern **Privacy als Architektur**.

- Pfad: `~/XCODE/Fair-iMail`
- App-Target: `iMailSecure` (iOS, Bundle-ID `io.imailsecure.app`)
- Projektdatei: `project.yml` ist die **Quelle der Wahrheit** (XcodeGen).
  `iMailSecure.xcodeproj` ist generiert — nicht von Hand editieren, außer es geht nicht anders,
  und dann `project.yml` nachziehen.

## Datenschutz-Leitsätze (nicht verhandelbar)

1. **Keine Telemetrie.** Keine Analytics-, Crash-Reporting- oder Werbe-SDKs. Neue
   Dependencies nur nach ausdrücklicher Rücksprache — aktuell erlaubt: `SwiftMail` (BSD),
   `swift-log` (Apache-2.0).
2. **Kein Klartext, kein Downgrade.** Jede Verbindung TLS ≥ 1.2, Modus pro Konto explizit
   (implicit TLS oder erzwungenes STARTTLS). Schlägt das Upgrade fehl → Abbruch (fail-closed).
3. **Remote-Inhalte standardmäßig blockiert.** Bilder, Styles, Fonts, Tracker aus Mails
   werden nicht geladen, solange der Nutzer sie nicht für diese Mail oder diesen Absender
   freigibt.
4. **Keine Inhalte in Logs.** Kein Betreff, keine Adresse, kein Host, kein Body — auch nicht
   in Debug-Builds. Nur Ereignisse und Zähler.
5. **Secrets nur in den Keychain**, `…ThisDeviceOnly`, `kSecAttrSynchronizable = false`.
   Kontodaten: Dateischutz `complete` + `isExcludedFromBackup`.
6. **Keine Daten an Dritte.** Keine Cloud, keine Keyserver-Abfragen, kein Push über
   Fremdinfrastruktur — außer der Nutzer löst es explizit aus.
7. **Links:** Tracking-Parameter entfernen, Ziel im Klartext bestätigen, extern nur nach
   Zustimmung öffnen.
8. **Anhänge:** Dateinamen sanitisieren, eigener UUID-Ordner, `.completeFileProtection`,
   nach Gebrauch löschen. Kein ungeprüftes Öffnen gefährlicher Typen.
9. **Fehler nicht verschlucken.** Keychain-, Crypto- und Netzwerkfehler müssen sichtbar
   behandelt werden. `try?` ist nur zulässig, wenn der Fehler bewusst und dokumentiert
   folgenlos ist.
10. **Schalter müssen wirken.** Ein UI-Toggle ohne Konsument im Code ist ein Bug, kein
    Feature. Jede Datenschutz-Funktion braucht entweder einen Test oder eine dokumentierte
    Begründung, warum nicht.
11. **Datenschutz ist nie kostenpflichtig.** Die Bezahlversion verkauft Bequemlichkeit
    (mehrere Konten, mehr Ordner, gemeinsamer Posteingang), niemals Sicherheit. HTML-Blocker,
    Tracking-Schutz, Zertifikat-Pinning und „keine Telemetrie" bleiben in der kostenlosen
    Version. Details: `MONETIZATION.md`.

## Kontext & Antworten (Token sparen)

- **Git:** nie den vollen Verlauf lesen. Nur `git status`, `git diff`, `git log -5 --oneline`.
  `git diff HEAD~1` ist verboten — bricht bei Erstcommit, Merge, Rebase und Detached HEAD.
- **Antwortformat:** Patch/Code + maximal 3 Bullets (Ursache → Änderung → Verifikation).
  Keine Prosa, keine Wiederholung des Auftrags.
- **Ein Fehler pro Antwort.** Mehrere Befunde → nach Schwere (K/H/M/N) trennen.
- **Nach jedem Fix:** Build/Test laut Hook ausführen, Ergebnis in `STATE.md` eintragen.
  „Behoben" ohne Build-Log ist unzulässig.
- **Kaltstart:** bei > 60 % Kontext oder nach 3 erledigten Punkten `STATE.md` aktualisieren
  und Kaltstart anfordern. `STATE.md` max. 40 Zeilen; erledigte Zeilen nach
  „Zuletzt erledigt" (max. 3), ältere löschen.
- **Nicht raten:** fehlt Datei/Zeile/Log, gezielt nachfragen statt Code erfinden.

## Arbeitsweise

```bash
# Vor dem Anfangen
git status                      # muss clean sein, sonst erst committen

# Bauen
xcodebuild -scheme iMailSecure \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build

# Testen
xcodebuild -scheme iMailSecure \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' test

# Projektdatei neu erzeugen (nach Änderungen an project.yml)
xcodegen generate
```

- **Kleine, benannte Commits.** Eine Änderung = ein Commit = eine nachvollziehbare Aussage.
  Beispiel: `fix(smtp): Zertifikat-Pinning auch beim Versand`.
- **Vor und nach jedem größeren Eingriff committen.** Das Repo ist die Rückversicherung,
  nicht der Chat.
- **`STATE.md` pflegen:** nach jedem abgeschlossenen Fix Stand, offene Punkte und nächsten
  Schritt aktualisieren (max. 40 Zeilen).
- **`AUDIT_NOTES.md` pflegen:** Wird ein Befund (N1…C1) erledigt, Statuszeile aktualisieren —
  mit Datum und wer es gemacht hat.
- **Keine Dateien löschen oder umbenennen**, ohne vorher zu prüfen, wer sie benutzt
  (`grep`/Graph).
- Nach dem Bauen: **Build-Warnungen ernst nehmen**, nicht „später".

## Verboten

- `sudo`-Aufrufe, die das Projekt oder Toolchains verändern.
- Secrets, Zertifikate, `.p12`, `.mobileprovision`, `.env` committen.
- Neue Netzwerk-Endpunkte ohne TLS und ohne Dokumentation im Code.
- „Nur mal schnell" `project.yml` und `pbxproj` auseinanderlaufen lassen.

## Offene Architekturentscheidungen

| ID | Thema | Status |
|---|---|---|
| D2 | HTML-Anzeige: Text als Standard, HTML erst auf Knopfdruck in gesperrter WKWebView | ✅ Stufe 1+2 erledigt (2026-11-01) |
| D2b | Externe Inhalte pro Mail/Absender freigeben (Stufe 3) | ✅ erledigt (2026-11-01) |
| S5 | OAuth 2.0 (Google/Outlook) vs. nur App-Passwörter | offen |
| S6 | Entwürfe lokal speichern (verschlüsselt) | offen |
| C1 | PGP/S/MIME: Drittbibliothek ja/nein | offen |
| L1 | Lizenz: source-available, nicht-kommerziell | ✅ entschieden (Option B, 2026-11-01) |
| M1 | Monetarisierung: Free-Tier + Pro-Abo (StoreKit 2, Trial über Apple) | ✅ entschieden (2026-11-02) |

## Lizenz

**PolyForm Noncommercial 1.0.0** (`LICENSE`): Quellcode einsehbar, keine
kommerzielle Nutzung durch Dritte. Das ist **kein Open Source** — weder in der
Doku noch in der App so nennen. Beiträge nur mit `CLA.md` mergen. Der
Rechteinhaber (Christian Renner) darf selbst kommerziell vertreiben.

Pflichten daraus:

- Bei Veröffentlichung des Codes die Lizenz mitliefern (PolyForm § Notices).
- In App Store Connect eine eigene EULA hinterlegen, sonst gilt Apples
  Standard-EULA und die Nicht-kommerziell-Klausel greift nicht.
- Fremden Code ohne CLA nicht übernehmen — er wäre nicht kommerziell
  verwertbar.
