# IMAPProbe — echter End-to-End-Test

Kleines Kommandozeilenwerkzeug für einen Test gegen ein **echtes** IMAP-Konto.
Es benutzt dieselbe SwiftMail-Revision wie die App und bindet zwei Dateien aus
dem App-Code per Symlink ein:

| Datei | Zweck |
|---|---|
| `Sources/iMailSecure/Models/MailFolder.swift` | Rollenerkennung, Anzeigenamen, Umbenennen |
| `Sources/iMailSecure/Utilities/ModifiedUTF7.swift` | Kodierung der Ordnernamen |

Damit prüft der Test den ausgelieferten Code, keine Nachbildung. Das Werkzeug
ist **nicht** Teil des App-Targets und landet nicht im Bundle.

## Einrichten

Zugangsdaten liegen außerhalb beider Repositories:

```bash
mkdir -p ~/.config/imailsecure
cat > ~/.config/imailsecure/imap-test.env <<'EOF'
IMAP_HOST=imap.gmx.net
IMAP_PORT=993
IMAP_USER=dein-konto@gmx.de
IMAP_PASSWORD=app-passwort
EOF
chmod 600 ~/.config/imailsecure/imap-test.env
```

Bei GMX mit Zwei-Faktor-Anmeldung ist ein **App-Passwort** nötig
(GMX → Einstellungen → Sicherheit → App-Passwörter), nicht das Kontopasswort.
Das App-Passwort lässt sich nach dem Test widerrufen.

Alternativ Umgebungsvariablen `IMAP_HOST`, `IMAP_PORT`, `IMAP_USER`,
`IMAP_PASSWORD` setzen. Ein anderer Dateipfad geht per `--env <pfad>`.

## Ausführen

```bash
cd Tools/IMAPProbe
swift run IMAPProbe            # nur lesen
swift run IMAPProbe --write    # zusätzlich Schreibtest
swift run IMAPProbe --smtp     # zusätzlich SMTP-Versand (Testmail an das eigene Konto)
```

## Was geprüft wird

**Lesen**

- TLS-Verbindung, Anmeldung, Fähigkeiten (MOVE, UIDPLUS, SPECIAL-USE)
- Ordnerliste inklusive Special-Use-Attributen
- Rollenerkennung über `MailFolder.detect` mit echten Servernamen
- Nachrichten laden wie `MailSyncEngine.fetchMessages` (Betreff, Absender, Datum)

**Schreiben (`--write`)**

- Ordner mit Umlaut anlegen (durchläuft `ModifiedUTF7.encode`)
- verschachtelten Ordner anlegen, umbenennen, Elternpfad prüfen
- Testnachricht per APPEND schreiben
- MOVE in den Papierkorb, neue UID über COPYUID prüfen
- Testnachricht per `STORE \Deleted` + `UID EXPUNGE` entfernen

**Versand (`--smtp`)**

- Verbindung zum SMTP-Server (587 STARTTLS bzw. 465 implizites TLS,
  überschreibbar per `SMTP_HOST`/`SMTP_PORT`)
- Anmeldung mit denselben Zugangsdaten
- Testnachricht an das eigene Konto senden
- Testordner löschen und Vollständigkeit prüfen

Der Schreibtest fasst ausschließlich Ordner mit dem Präfix `iMail-Test-` an.
Vorhandene Ordner und Nachrichten bleiben unberührt. Bei einem Fehler räumt
das Werkzeug die angelegten Ordner auf.

## Befunde vom 12. November 2026 (GMX)

Erster Lauf gegen `imap.gmx.net` mit einem echten Konto:

1. **Ordnernamen kamen als modified UTF-7** — `Entw&APw-rfe` statt `Entwürfe`.
   Behoben durch `ModifiedUTF7` (Dekodieren für die Anzeige, Kodieren vor
   `CREATE`/`RENAME`).
2. **GMX führt alte und neue Systemordner parallel** — `Drafts` und
   `Entw&APw-rfe`, `Sent` und `Gesendet`, `Trash` und `Gel&APY-scht`.
   Die Rollen sind doppelt belegt. `MailFolder.preferred` bevorzugt jetzt den
   Ordner mit Special-Use-Attribut; die Liste hängt bei Duplikaten den
   Servernamen an.
3. **Der Papierkorb enthält die Mail.** Bei GMX trägt `Gel&APY-scht` das
   `\Trash`-Attribut (3 Nachrichten), `Trash` ist leer. Ohne die
   Bevorzugung hätte „Löschen" je nach Reihenfolge im leeren Ordner geendet.
4. **MOVE und UIDPLUS funktionieren** — Löschen per MOVE in den Papierkorb und
   endgültiges Entfernen per `UID EXPUNGE` wie implementiert.

Nicht abgedeckt: Gmail-Labels (anderer Server), SMTP-Versand, iOS-spezifische
Keychain- und StoreKit-Pfade.
