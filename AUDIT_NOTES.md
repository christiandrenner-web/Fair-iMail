# AUDIT_NOTES.md — iMail Secure
**Erstellt:** 2026-10-31  
**Auditor:** Claude (Anthropic) – pedantischer IT-Security-Auditor, Orientierung an FairEmail (Marcel Bockhorst)  
**Projektpfad:** `/Users/christianrenner/XCODE/Fair-iMail/iMailSecure.xcodeproj`  
**Graph:** 312 Knoten, 574 Kanten, 15 Communities (graphify-out/graph.json)

---

## Gelesene Dateien

| Datei | Inhalt |
|---|---|
| `MailSyncEngine.swift` | IMAP-Sync, MDN-Versand, Demo-Nachrichten |
| `SMTPManager.swift` | E-Mail-Versand via SwiftMail |
| `KeychainManager.swift` | Passwort-Speicherung (Keychain) |
| `CoreDataService.swift` | Core-Data-Container (kein Aufrufer im Graph) |
| `EmailAccount.swift` | Kontomodell, Passwort-Proxy |
| `AccountStore.swift` | Persistenz in UserDefaults als JSON |
| `MailStore.swift` | In-Memory-Mailspeicher |
| `EmailHeaderBuilder.swift` | RFC-2822-Header-Bau |
| `MDNProcessor.swift` | MDN-Erkennung und -Parsing |
| `ComposeViewModel.swift` | Senden + Reply-Vorbereitung |
| `MessageDetailView.swift` | Mail-Anzeige, Anhang-Handling |
| `AccountSetupView.swift` | Konto anlegen |
| `AccountDetailView.swift` | Konto bearbeiten |
| `SettingsView.swift` | Datenschutz-Schalter (wirksam, u. a. `defaultRequestMDN`) |
| `Extensions.swift` | strippedHTML, Color, View-Modifiers |
| `EmailMessage.swift` | Nachrichtenmodell |
| `Constants.swift` | Bundle-ID, Keychain-Keys, Notifications |
| `Info.plist` | ATS, Berechtigungen, UIBackgroundModes |
| `iMailSecure.entitlements` | background-fetch |
| `PrivacyInfo.xcprivacy` | NSPrivacyTracking = false |
| `Package.swift` | SwiftMail + swift-log |

**Unverifiziert (außerhalb freigegebener Pfade):**  
SwiftMail-Quellcode → TLS-Voreinstellungen unbekannt.

---

## Gesamtbewertung

Konzept gut, Umsetzung unvollständig. Viele Schutzfunktionen existieren als UI-Schalter ohne Wirkung. Die Mail-Anzeige ist nur deshalb sicher, weil sie fast nichts rendert (`Text(message.body)`). Keine Telemetrie gefunden — echter Pluspunkt.

**Schweregrade:** K = kritisch · H = hoch · M = mittel · N = niedrig

---

## Kategorie 1 — Netzwerksicherheit & Verbindungen

### N1 (K) TLS wird nicht erzwungen [unverifiziert]
- `IMAPServer(host:port:)` und `SMTPServer(host:port:)` ohne Verschlüsselungsmodus aufgerufen.
- `imapUseTLS` / `smtpUseTLS` im Modell werden nirgends gelesen → Schalter wirkungslos.
- Port frei wählbar (1–65535); STARTTLS-Downgrade nicht verhindert.
- **Fix:** Expliziter Modus pro Konto (implizites TLS oder erzwungenes STARTTLS), Klartext nie erlauben, Verbindungsabbruch bei fehlgeschlagenem Upgrade.
- **Betroffene Dateien:** `MailSyncEngine.swift`, `SMTPManager.swift`, `EmailAccount.swift`, `AccountDetailView.swift`

### N2 (H) Keine Zertifikatsprüfung, kein Pinning
- Kein Code für Zertifikatsprüfung, keine TLS-Mindestversion (≥ 1.2), keine Fingerabdruck-Anzeige.
- FairEmail: SHA-256-Fingerabdruck-Vertrauen pro Server (Trust on First Use + Warnung bei Änderung).
- **Fix:** Standardprüfung hart erzwingen; Ausnahmen nur per bestätigtem Fingerabdruck; ablaufende Zertifikate anzeigen.
- **Betroffene Dateien:** `MailSyncEngine.swift`, `SMTPManager.swift`, `EmailAccount.swift`

### N3 (H) Abhängigkeit nicht reproduzierbar gepinnt
- `Package.swift`: `revision = "29a1df6"` (gut).
- `project.pbxproj`: `kind = branch; branch = main` → Xcode baut gegen beweglichen Stand.
- **Fix:** `project.pbxproj` auf dieselbe Revision setzen, `Package.resolved` einchecken.
- **Betroffene Dateien:** `iMailSecure.xcodeproj/project.pbxproj`, `Package.resolved`

### N4 (M) Logging enthält sensitive Inhalte
- `logger.info("Sende '\(draft.subject)' via \(account.smtpHost):\(account.smtpPort)")` → Betreff + Host in Konsole.
- `logger.info("MDN gesendet für: \(message.subject)")` → Betreff in Konsole.
- `logger.info("INBOX: \(total) Nachrichten")` → unkritisch, aber Pattern setzt sich fort.
- **Fix:** In Release-Builds (`#if DEBUG`) nur Ereignisse ohne Inhalte loggen; Betreff, Adressen, Hostnamen heraushalten.
- **Betroffene Dateien:** `MailSyncEngine.swift`, `SMTPManager.swift`

### N5 (M) Ungenutzte / falsche Netzwerk-Berechtigungen
- `UIBackgroundModes: remote-notification` ohne Push-Entitlement → widersprüchlich.
- `NSContactsUsageDescription`, `NSFaceIDUsageDescription` ohne Funktion.
- `UIRequiredDeviceCapabilities = armv7` → veraltet (kein 32-Bit-iOS mehr).
- **Fix:** Alles entfernen, was nicht genutzt wird; Push erst aktivieren wenn vollständig implementiert.
- **Betroffene Dateien:** `Info.plist`, `iMailSecure.entitlements`

### N6 (N) Demo-Nachricht bei Verbindungsfehler irreführend
- Bei Sync-Fehler wird eine Fake-Nachricht von `hello@fairimail.io` eingefügt.
- **Fix:** Nur Fehler-UI anzeigen, keine inhaltliche Fake-Mail.
- **Betroffene Dateien:** `MailSyncEngine.swift`

---

## Kategorie 2 — Datenschutz bei der E-Mail-Anzeige

### D1 (H) Keine echte HTML-Bereinigung
- `strippedHTML` entfernt Tags per Regex `<[^>]+>`.
- Inhalt von `<style>`, `<script>` bleibt als Text; HTML-Entities nicht dekodiert; `>` in Attributen bricht Filter.
- `isHTML`-Flag in `EmailMessage` wird nirgends ausgewertet.
- Heute kein direktes Tracking-Risiko (es wird nichts geladen). Sobald HTML-Rendering kommt, Positivliste für Tags/Attribute und CSS-Stripping nötig.
- **Fix:** Positivlisten-Sanitizer (z. B. eigene Implementierung oder `WKWebView` mit Content-Rules); `<base>`-Tags immer entfernen; `data:`-URIs blockieren.
- **Betroffene Dateien:** `Extensions.swift`, `MessageDetailView.swift`

### D2 (H) Externe Inhalte: Schalter ohne Wirkung
- `loadRemoteImages` und `confirmExternalLinks` in `SettingsView` → kein Konsument im Code.
- **Fix:** Standard = blockiert; `WKWebView` mit nicht-persistentem Datenspeicher + Content-Rule-Liste (block `http(s)://` in `<img>`, `<link>`, `srcset`, CSS); pro Mail-Button „Externe Inhalte laden"; Absender-Freigabeliste.
- **Betroffene Dateien:** `SettingsView.swift`, `MessageDetailView.swift` (neuer WebView-Wrapper)
- **Status 2026-11-01:** Stufe 1+2 umgesetzt — Text ist Standard, „HTML anzeigen" rendert in
  `HTMLMessageView` mit deaktiviertem JavaScript, nicht-persistentem Datenspeicher und einer
  Content-Rule-Liste, die jede `http(s)`-Anfrage blockiert (fail-closed bei Kompilierfehler).
  `HTMLSanitizer` entfernt Skripte, `on*`-Handler, `<base>`, Formulare, Meta-Refresh und
  Remote-Ressourcen. Links werden abgefangen und erst nach Bestätigung extern geöffnet.
  Die beiden wirkungslosen Schalter wurden entfernt (Leitsatz 10).
- **Status 2026-11-01, Stufe 3:** `RemoteContentPolicy` merkt sich Freigaben —
  entweder nur für eine Message-ID (nicht persistiert) oder dauerhaft für eine
  **Absender-Adresse** (`UserDefaults`, normalisiert). Bewusst nicht pro Domain: ein
  kompromittierter Absender würde sonst die ganze Domain freischalten. Freigabe erfolgt
  über einen Dialog in der Mail („Nur für diese Mail" / „Immer für <Adresse>"), Widerruf
  einzeln oder komplett in den Einstellungen. In Stufe 3 entfällt nur die
  Content-Rule-Liste; JavaScript bleibt aus, Skripte/Formulare/Event-Handler/`ping`
  bleiben entfernt. Der Wechsel blockiert↔freigegeben erzeugt über `.id(...)` eine neue
  `WKWebView`, damit keine alte Regel-Liste aktiv bleibt.

### D3 (H) Keine Link-Behandlung
- Keine Tracking-Parameter-Entfernung (`utm_*`, `fbclid`, `gclid`, `mc_eid`, `yclid`, `ref`, …).
- Keine Redirect-Wrapper-Auflösung.
- Keine IDN/Punycode-Warnung.
- Kein Bestätigungsdialog mit Klartext-Ziel.
- `confirmExternalLinks`-Schalter ohne Wirkung (siehe D2).
- **Fix:** URL-Reiniger vor dem Öffnen; Dialog mit vollem Ziel-URL; `UIApplication.open` mit `referrerURL: nil`.
- **Betroffene Dateien:** `MessageDetailView.swift`, `Extensions.swift`

### D4 (H) Anhänge: Pfad-Injektion + ungesicherte Temp-Dateien
- `shareAttachment` schreibt nach `temporaryDirectory.appendingPathComponent(att.filename)`.
- Dateiname kommt vom Absender → `../` oder absolute Pfade möglich.
- Dateien werden nicht gelöscht, ohne Dateischutz abgelegt.
- Im Sync: `att.data ?? Data()` lädt alle Anhänge sofort komplett in den RAM.
- **Fix:**
  - Dateinamen sanitizen: nur letztes Pfadkomponent behalten, Whitelist für Zeichensatz.
  - Eigenen UUID-Unterordner anlegen mit `.completeFileProtection`.
  - Nach Nutzung löschen (`defer { try? FileManager.default.removeItem(at:) }`).
  - Warnung bei gefährlichen MIME-Typen (`.dmg`, `.ipa`, `.sh`, …).
  - Lazy-Loading: Anhänge erst bei Antippen nachladen.
- **Betroffene Dateien:** `MessageDetailView.swift`, `MailSyncEngine.swift`

### D5 (M) Keine Absender-Authentizitäts-Anzeige
- Anzeigename wird ungefiltert aus dem From-Header übernommen.
- `Authentication-Results` (SPF, DKIM, DMARC) werden nicht angezeigt.
- **Fix:** Warnung wenn Anzeigename eine Domain enthält, die nicht zur Absender-Domain passt; `Authentication-Results`-Header parsen und als Badge anzeigen.
- **Betroffene Dateien:** `MessageDetailView.swift`, `MailSyncEngine.swift` (convert)

### D6 (M) MDN-Erkennung fälschbar
- `MDNProcessor` erkennt MDN schon bei `read:` / `gelesen:` im Betreff.
- Message-ID als Zuordnungsschlüssel ist vom Absender fälschbar.
- `merge` dedupliziert nur nach Message-ID → Unterdrücken echter Mails möglich.
- **Fix:**
  - Content-Type `multipart/report; report-type=disposition-notification` prüfen.
  - Absender gegen eigene Adresse des Originalkontos abgleichen.
  - Deduplizierung um Konto-ID + Ordner + UID erweitern.
- **Positiv:** MDN-Versand nur nach expliziter Nutzerentscheidung — korrekt.
- **Betroffene Dateien:** `MDNProcessor.swift`, `MailStore.swift`

---

## Kategorie 3 — Lokale Datensicherheit

### S1 (M) Keychain-Schutzklasse nicht maximal
- Aktuell: `kSecAttrAccessibleWhenUnlocked` → erlaubt iCloud-Backup + Gerätemigration.
- Atomar nicht sicher: delete → add; besser `SecItemUpdate`.
- `AccountDetailView.save()`: `try? account.savePassword(newPassword)` → Fehler verschluckt.
- **Fix:**
  - `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` für Hintergrund-Sync.
  - `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` für maximalen Schutz (kein Hintergrund-Sync).
  - `kSecAttrSynchronizable = kCFBooleanFalse` explizit setzen.
  - Optional: `SecAccessControl` mit `.biometryCurrentSet` für kritische Konten.
  - Update statt delete+add (atomar).
  - Fehler in `AccountDetailView` nicht verschlucken.
- **Betroffene Dateien:** `KeychainManager.swift`, `AccountDetailView.swift`

### S2 (H) Kontodaten im Klartext in UserDefaults
- Name, E-Mail, Server, Ports, Benutzername → JSON in `UserDefaults` → in Backups enthalten.
- **Fix:** In Datei mit `FileProtectionType.complete` + Backup-Ausschluss (`URLResourceValues.isExcludedFromBackup = true`) oder komplett in den Keychain verlagern (als `kSecClassGenericPassword` pro Konto, JSON-kodiert).
- **Betroffene Dateien:** `AccountStore.swift`

### S3 (H) Core-Data-Cache ungenutzt + wenn aktiviert: unverschlüsselt
- Laut Graph hat `CoreDataService` keinen Aufrufer → `MailStore` hält alles im RAM → kein Offline-Speicher trotz README-Versprechen.
- **Fix (wenn Core Data aktiviert wird):**
  - `NSPersistentStoreFileProtectionKey: FileProtectionType.complete` als Store-Option.
  - `isExcludedFromBackup = true` auf der Store-Datei.
  - Feldinhalte (Body, Betreff) mit CryptoKit AES-GCM verschlüsseln, Schlüssel im Keychain.
  - `shouldMigrateStoreAutomatically` **vor** `loadPersistentStores` setzen (aktuell wirkungslos).
  - `fatalError` durch saubere Fehlerbehandlung ersetzen.
- **Betroffene Dateien:** `CoreDataService.swift`

### S4 (M) Kein App-Schutz / Sichtschutz
- Keine Sperre per Face ID / Passcode, obwohl `NSFaceIDUsageDescription` deklariert.
- Kein Sichtschutz beim App-Wechsel (Inhalt im App-Umschalter sichtbar).
- Keine Reaktion auf Bildschirmaufnahme.
- **Fix:**
  - `LocalAuthentication` (`LAContext.evaluatePolicy`) beim App-Start und nach Inaktivität.
  - `.privacySensitive()` auf Mail-Content oder Unschärfefolie beim Hintergrundwechsel (`UIApplication.willResignActive`).
  - Einstellung: Sperr-Timeout (sofort / 1 min / 5 min).
- **Betroffene Dateien:** `iMailSecureApp.swift`, neues `AppLockManager.swift`

### S5 (H) Keine OAuth-Unterstützung
- Gmail + Outlook in Anbieter-Quicklist, aber nur Passwort-Login implementiert.
- Beide Anbieter erzwingen teils OAuth 2.0 (Google: nach Mai 2022 kein Plain-Auth mehr ohne App-Passwort).
- **Fix:** OAuth 2.0 mit PKCE via `ASWebAuthenticationSession`; XOAUTH2 / OAUTHBEARER in IMAP/SMTP (SwiftMail-Unterstützung prüfen); Token im Keychain `ThisDeviceOnly`; Refresh-Logik; Hinweis auf App-Passwörter als Fallback.
- **Betroffene Dateien:** `AccountSetupView.swift`, `EmailAccount.swift`, neues `OAuthManager.swift`

### S6 (N) Entwürfe nicht gespeichert
- `saveDraft` zeigt nur Meldung, schreibt nichts.
- Wenn Entwürfe später gespeichert werden: gleiche Verschlüsselungsanforderungen wie S3.
- **Betroffene Dateien:** `ComposeViewModel.swift`

---

## Kategorie 4 — Krypto-Features (Ende-zu-Ende)

### C1 (H) Kein PGP / S/MIME
- Kein `multipart/signed`, kein `multipart/encrypted`, keine Schlüsselverwaltung, keine Signaturanzeige.
- **Entscheidungsbedarf (an Christian):**
  - Drittbibliothek akzeptabel? Kandidaten: ObjectivePGP, GopenPGP (CGo-frei), für S/MIME: eigene CMS-Implementierung via CryptoKit (nur EC, kein RSA).
  - Secure Enclave: nur P-256 — für moderne PGP-Schlüssel (Ed25519/Curve25519) nicht geeignet; Schlüssel dann als `ThisDeviceOnly` im Keychain.
- **Implementierungsplan wenn freigegeben:**
  1. Schlüssel-Import per Dateien-App / Pasteboard.
  2. Keychain-Speicherung (privat: `ThisDeviceOnly`, öffentlich: normal).
  3. Signieren beim Senden (opt-in pro Konto), Verschlüsseln wenn Empfänger-Schlüssel vorhanden.
  4. Signaturprüfung + Badge beim Lesen.
  5. Autocrypt-Header senden/lesen (einfachster Schlüsseltausch).
  6. Keine automatischen Keyserver-Abfragen (Netzwerk-Leck); WKS/Web Key Directory nur auf explizite Anfrage.
  7. `ITSAppUsesNonExemptEncryption` bei Aktivierung auf `true` setzen + Exportkonformität prüfen.
- **Betroffene Dateien:** `SMTPManager.swift`, `MailSyncEngine.swift`, `MessageDetailView.swift`, neues `CryptoManager.swift`

---

## Vorgeschlagene Umsetzungsreihenfolge

| Priorität | Nr. | Thema | Aufwand |
|---|---|---|---|
| 1 – sofort, ohne Fremdbibliothek | N3 | Package-Pin reparieren | 5 min |
| 1 | N4 | Logs bereinigen | 15 min |
| 1 | N5 | Info.plist aufräumen | 10 min |
| 1 | N6 | Demo-Mail entfernen | 5 min |
| 1 | S1 | Keychain-Klasse + atomar | 30 min |
| 1 | S4 | Sichtschutz beim App-Wechsel | 20 min |
| 1 | D4 | Anhang-Pfad sanitizen + Schutz | 45 min |
| 1 | D6 | MDN-Erkennung härten | 30 min |
| 2 – mittel | S2 | Kontodaten verschlüsseln | 1–2 h |
| 2 | D3 | Link-Reiniger + Bestätigung | 1 h |
| 2 | D5 | Absender-Badge | 1 h |
| 3 – aufwändig | N1/N2 | TLS-Modus + Zertifikate | abhängig von SwiftMail-API |
| 3 | D1/D2 | HTML-Sanitizer + WKWebView | 3–5 h |
| 3 | S3 | Core-Data verschlüsselt | 2–4 h |
| 3 | S4 | LocalAuthentication-Sperre | 2 h |
| 4 – Entscheid nötig | S5 | OAuth 2.0 | 5–10 h |
| 4 | C1 | PGP / S/MIME | 10–20 h |

---

## Offene Entscheidungen (für Christian)

1. **TLS (N1/N2):** Welche SwiftMail-API steht für Verschlüsselungsmodus und Custom-TrustEvaluation zur Verfügung? → Bitte Zugriff auf `~/.build/checkouts/SwiftMail/Sources/` gewähren oder im Repo nachsehen.
2. **Konten (S2):** Weiterhin UserDefaults oder in Keychain / geschützte Datei?
3. **HTML-Rendering (D1–D3):** `WKWebView` mit strenger Content-Security-Policy akzeptabel? Alternative: reines Text-Rendering mit RTF-Unterstützung.
4. **OAuth (S5):** Scope Google + Outlook zunächst, oder nur Hinweis auf App-Passwörter?
5. **E2E-Krypto (C1):** Fremdbibliothek ja/nein? Wenn ja: PGP, S/MIME oder beides?

---

## Status offener Punkte

| Nr. | Status | Notiz |
|---|---|---|
| N1 | ✅ erledigt | `useTLS: true` in IMAPServer – Port 993 → implicitTLS, Port 143 → STARTTLS required (fail-closed). **2026-11-11:** explizite `transportSecurity`-Policy aus `imapSecurity`/`smtpSecurity` statt Port-Heuristik; SMTP-STARTTLS ist jetzt erzwungen (`.startTLS`) und bricht bei fehlendem Angebot ab |
| N2 | ✅ erledigt | CertificatePinner.swift (TOFU): SHA-256 Leaf-Fingerabdruck, Keychain ThisDeviceOnly; Ports 993/465; STARTTLS-Ports durch BoringSSL fullVerification. **2026-11-01:** Pinning auch im SMTP-Versandpfad (`SMTPManager.sendEmail`) vor `connect()`; `resetPin` über echten Button in `AccountDetailView` erreichbar |
| N3 | ✅ erledigt | pbxproj auf Revision 29a1df6c gepinnt |
| N4 | ✅ erledigt | Betreff + Host nur noch in #if DEBUG; Release-Logs ohne Inhalte |
| N5 | ✅ erledigt | armv7→arm64, remote-notification entfernt, NSContactsUsageDescription auskommentiert |
| N6 | ✅ erledigt | demoMessages() und Aufruf entfernt |
| D1 | ✅ erledigt | Robuster Sanitizer: script/style-Block-Entfernung, Entity-Dekodierung, Block-Zeilenumbrüche |
| D2 | ✅ vollständig | Text ist Standard, HTML nur auf Knopfdruck. `HTMLMessageView` (WKWebView): JS aus, non-persistenter Store, Content-Rule-Liste blockt jede http(s)-Anfrage, jede Navigation außer der initialen wird abgebrochen, Links nur nach Bestätigung. `HTMLSanitizer` als zweite Schicht. Inerte Toggles `loadRemoteImages`/`confirmExternalLinks` entfernt. **Stufe 3:** `RemoteContentPolicy`, Freigabe pro Mail oder Absender, Widerruf in den Einstellungen |
| D3 | ✅ erledigt | URL.trackingStripped mit 15 Tracking-Parametern; URL.domainMismatch für Link-Prüfung |
| D4 | ✅ erledigt | Pfad-Sanitizer, UUID-Unterordner, .completeFileProtection, Cleanup nach Share-Sheet-Dismiss |
| D5 | ✅ erledigt | Absender-Badge: Warnung wenn Anzeigename-Domain ≠ Absender-Domain |
| D6 | ✅ erledigt | Subject-Heuristik entfernt; nur noch Content-Type-Marker im Body akzeptiert. **2026-11-01:** Test korrigiert + Regressionstest „Betreff allein löst keine MDN aus" ergänzt |
| S1 | ✅ erledigt | AfterFirstUnlockThisDeviceOnly, kSecAttrSynchronizable=false, atomares Update-oder-Anlegen |
| S2 | ✅ erledigt | Datei mit .completeFileProtection + isExcludedFromBackup; Migration von UserDefaults |
| S3 | ✅ erledigt | shouldMigrate VOR loadPersistentStores; kein fatalError; .completeFileProtection auf Store |
| S4 | ✅ erledigt | Blur-Overlay bei willResignActive; Schloss-Icon im App-Umschalter |
| S5 | 🔴 offen | OAuth 2.0 – Entscheid ausstehend |
| S6 | 🔴 offen | Entwürfe werden nicht gespeichert |
| C1 | 🔴 offen | PGP/S/MIME – Entscheid Krypto-Bibliothek ausstehend |
| L1 | ✅ entschieden | PolyForm Noncommercial 1.0.0 (`LICENSE`), keine GPL-Reste; juristische Prüfung von `LICENSE`, `CLA.md` und AGB steht aus |

---

## Änderungen 2026-11-01 (OpenCode)

- **Git-Repo angelegt** (`main`, erster Commit des Ist-Stands). Vorher gab es keine Versionshistorie.
- **N2:** Zertifikat-Pinning greift jetzt auch beim SMTP-Versand (`SMTPManager.sendEmail`),
  nicht nur beim IMAP-Sync. Der zuvor ungepinnte Versandpfad war eine offene Lücke.
- **`resetPin` an die UI gebunden:** `AccountDetailView` zeigt gespeicherte Fingerabdrücke
  (IMAP/SMTP) und bietet „Zertifikat zurücksetzen" mit Bestätigungsdialog. Vorher war die
  Funktion toter Code — nach einer Zertifikatserneuerung wäre das Konto nicht mehr nutzbar.
- **`project.yml`:** SwiftMail auf dieselbe Revision wie `Package.swift` gepinnt
  (`29a1df6c…`); ein `xcodegen generate` hebt den Pin nicht mehr auf.
- **Deployment-Target auf iOS 18.0 gesenkt** (`project.yml`, `Package.swift`), Build und Tests
  grün auf dem iOS-Simulator.
- **Tests:** `testValidMDN` war veraltet (prüfte noch die entfernte Subject-Heuristik) und
  schlug fehl. Fixture korrigiert, Regressionstest für D6 ergänzt — 11 Tests, 0 Fehler.
- **Doku:** `AGENTS.md` (verbindliche Leitsätze), `CLAUDE.md`, `LICENSING.md`; README
  aktualisiert (Setup, Struktur, App-Store-Checkliste).
- **Offen und blockierend:** `fairimail.io` ist nicht registriert (RDAP 404, kein DNS) —
  Privacy-URL und Support-Adresse sind tot. Vor App-Store-Einreichung zwingend zu klären.

### Nachtrag 2026-11-01 (OpenCode) — D2 und Lizenz

- **D2 Stufe 1+2 umgesetzt:** `EmailMessage.htmlBody` hält die HTML-Fassung, angezeigt wird
  aber weiterhin `body` (Text). Neuer `HTMLSanitizer` (regexbasiert, ohne WebKit, unit-getestet)
  und `HTMLMessageView` (WKWebView: JS aus, `.nonPersistent()`, Content-Rule-Liste blockt
  `^https?://`, Navigation nach dem initialen Load abgebrochen, `target="_blank"` nie erlaubt).
  Schlägt die Regel-Liste fehl, wird **nicht** gerendert (fail-closed, sichtbarer Hinweis).
- **Tote Schalter entfernt:** `loadRemoteImages` und `confirmExternalLinks` waren ohne
  Konsument. Sie sind aus `SettingsView` und `Constants.UserDefaultsKeys` verschwunden;
  stattdessen zeigt die Einstellungsseite den tatsächlichen Zustand. Links werden immer
  bestätigt (Leitsatz 7).
- **Tests:** 12 neue Tests in `HTMLSanitizerTests.swift` (Skripte, Event-Handler, `<base>`,
  Remote-Bilder, `cid:`/`data:`-Ausnahmen, `<iframe>`/`<form>`, `javascript:`, Meta-Refresh,
  CSS-`@import`/`url()`, Doku-Wrapper, Content-Rule-JSON). Gesamt **23 Tests, 0 Fehler**.
- **Privacy-Manifest korrigiert:** `NSPrivacyCollectedDataTypes` enthielt `EmailAddress`.
  Nach Apples Definition („Daten verlassen das Gerät und sind für den Entwickler zugänglich")
  ist das falsch — die App spricht nur mit dem selbst konfigurierten Mailserver. Eintrag
  entfernt, Datenschutzlabel ist damit „Keine Daten erfasst". **Fachlich gegenprüfen.**
- **README:** „Offline-fähig (Core Data)" entfernt — `CoreDataService` hat keinen Aufrufer,
  die Aussage war falsch.
- **L1 entschieden (Option B: source-available, nicht-kommerziell):** GPLv3 + App-Store-Ausnahme
  (Option A) wieder verworfen, weil sie bei jeder Weitergabe eine Veröffentlichung erzwungen
  und kommerzielle Forks erlaubt hätte. `LICENSE` ist jetzt **PolyForm Noncommercial 1.0.0**;
  `LICENSE-EXCEPTION` gelöscht; `CLA.md` neu gefasst (erlaubt kommerzielle Verwertung und
  Relizenzierung durch den Rechteinhaber). `LICENSING.md`, `README.md`, `AGENTS.md`,
  `APP_STORE_GUIDE.md` und die Lizenzangabe in `SettingsView` angepasst.
  **Wichtig:** Das ist kein Open Source; die Bezeichnung darf nicht verwendet werden. Im
  App Store ist eine eigene EULA nötig, sonst gilt Apples Standard-EULA.
  `APP_STORE_GUIDE.md` enthielt außerdem „Crashlytics/Sentry einbinden" — das widerspricht
  Leitsatz 1 und wurde entfernt.
- **D2 Stufe 3 umgesetzt (2026-11-01):** `RemoteContentPolicy` (Freigabe pro Message-ID
  oder pro Absender-Adresse, persistiert in `UserDefaults`, widerrufbar). `HTMLSanitizer
  .sanitize(_:allowRemoteResources:)` behält bei Freigabe Remote-Ressourcen, entfernt aber
  weiterhin Skripte, Event-Handler, Formulare, Meta-Refresh, `javascript:` und `ping`.
  `HTMLMessageView` erhält `allowRemote` und installiert dann keine Content-Rule-Liste;
  `.id(remoteContentAllowed)` erzwingt eine neue WebView beim Umschalten. In
  `MessageDetailView` Dialog „Nur für diese Mail“ / „Immer für <Adresse>“ und ein
  Blockieren-Knopf; in `SettingsView` eine Widerrufsliste (Swipe + „Alle widerrufen“).
  **43 Tests, 0 Fehler** (19 neue: 10 `RemoteContentPolicyTests`, 9 Sanitizer-Stufe-3).
- **Website:** separates, öffentliches Repo `~/XCODE/imailsecure-site` (index, privacy,
  support, lokales CSS, `.nojekyll`). Keine externen Ressourcen, keine Cookies, keine
  Analytics; GitHub-Pages-Hosting ist in der Datenschutzerklärung offengelegt.
  Veröffentlicht wird erst nach Einsetzen der markierten Platzhalter.
- **M1 Monetarisierung (2026-11-02):** Free-Tier + Pro-Abo, Trial als Apples
  Introductory Offer (kein eigener Timer). `Entitlement.swift` (Tier, Produkt-IDs,
  Feature-Tabelle, reine Ableitungsfunktionen), `SubscriptionManager.swift`
  (StoreKit 2, kein Backend, Keychain-Cache), `PaywallView.swift`. Gates:
  „Konto hinzufügen" in `SettingsView` und zweite Sicherung in
  `AccountSetupView.saveAccount()`. `iMailSecure.storekit` für lokale Tests im
  Schema hinterlegt. **Leitsatz 11 ergänzt:** Datenschutz ist nie kostenpflichtig.
  Details in `MONETIZATION.md`.
- **Bugfix Multi-Account:** `MailStore.loadAccounts` war nur beim App-Start
  aufgerufen — ein neu hinzugefügtes Konto wurde bis zum Neustart nicht
  synchronisiert. `iMailSecureApp` hört jetzt auf `accountStore.$accounts`;
  `loadAccounts` ist idempotent und erzeugt Engines bei Konto-Änderungen neu.
  `MainTabView` fragt bei mehreren Konten, von welchem gesendet wird.
  **57 Tests, 0 Fehler** (14 neue `EntitlementTests`).
- **M2 IMAP-Ordner und gemeinsamer Posteingang (2026-11-03):** `MailFolder` mit
  Rollenerkennung (Special-Use-Attribute, Namens-Fallback für Deutsch/Englisch),
  Anzeigenamen, Validierung neuer Ordnernamen und Free/Pro-Grenze
  (`requiresPro` nur für eigene Ordner). `MailSyncEngine` bündelt Verbindung,
  TLS-Pinning und Logout in `withServer`, listet Ordner per `LIST`, lädt pro
  Ordner die neuesten 50 Nachrichten und legt Ordner per `CREATE` an.
  `MailStore` hält `foldersByAccount`, repariert die Auswahl wenn ein Ordner
  verschwindet und filtert Rollen statt Namen. Löschen verschiebt per `MOVE`
  in den Papierkorb des Kontos, statt sofort zu expungieren. `FolderListView`
  zeigt gesperrte Pro-Ordner und öffnet die Paywall; der gemeinsame
  Posteingang ist Pro, Systemordner bleiben frei.
  **Nachrichtenidentität:** `EmailMessage.listID` ist Konto + Ordner +
  Message-ID. Dieselbe Mail kann in mehreren Ordnern liegen (Gmail-Labels),
  ohne dass `merge` eine Kopie verschluckt.
  **99 Tests, 0 Fehler** (42 neue: 22 `MailFolderTests`, 19 `MailStoreTests`,
  1 `EntitlementTests`). Umbenennen/Löschen folgte am 2026-11-11 mit SwiftMail
  1.16.0 (siehe unten); die damalige Revision konnte beides nicht. Nach einem
  Abo-Ende fällt die Auswahl
  automatisch auf einen Systemordner zurück, ohne Nachrichten zu löschen.
  Ein neu angelegtes Konto wird sofort synchronisiert, statt bis zum
  nächsten manuellen Refresh zu warten. `isSyncing` zählt laufende Syncs,
  damit parallele Aktualisierungen den Spinner nicht zu früh ausblenden.

---

## Änderungen 2026-11-11 (OpenCode)

- **`defaultRequestMDN` wirkt jetzt (STATE #1):** Der Schalter „Lesebestätigung
  standardmäßig anfordern" schrieb bisher nur `@AppStorage`; kein Codepfad las den Wert.
  `ComposeViewModel` übernimmt die Vorgabe beim Öffnen **und** nach dem Senden eines
  Entwurfs über `makeDraft(defaults:)`. Der Schlüssel kommt ausschließlich aus
  `AppConstants.UserDefaultsKeys.defaultRequestMDN`, auch in `SettingsView`.
  `UserDefaults` ist injizierbar, damit Tests die echten Einstellungen nicht verändern.
- **STATE #2 und #3 geschlossen:** `AUDIT_NOTES` führt `SettingsView` nicht mehr als
  „Schalter ohne Wirkung"; die L1-Zeile nennt jetzt PolyForm Noncommercial 1.0.0 statt
  der veralteten GPL-Option.
- **103 Tests, 0 Fehler** (4 neue `ComposeViewModelTests`: Vorgabe an/aus, Änderung nach
  dem Senden, kein Übernehmen von Empfänger/Betreff in den frischen Entwurf).

---

## Änderungen 2026-11-11 (OpenCode, SwiftMail 1.16.0)

- **Dependency-Pin angehoben:** `29a1df6` (24. März 2026) → `88c45cbd`
  (Release **1.16.0**, 9. Oktober 2026) in `Package.swift` und `project.yml`.
  Anlass: Upstream bietet seit PR #247 (in 1.14.0) `renameMailbox(_:to:)` und
  `deleteMailbox(_:)`. Der alte Pin konnte Ordner nur anlegen.
- **Datenschutzprüfung 1.16.0:** keine `URLSession`-Aufrufe in der Bibliothek, keine
  Analytics-/Telemetrie-/Crash-SDKs, kein `UserDefaults`, keine neuen Zielhosts.
  Lizenz bleibt BSD-3-Clause; Plattform-Floor iOS 18 wie die App. Neue transitive
  Pakete (SwiftCross, swift-crypto, swift-certificates, swift-nio-imap-Revision)
  sind Build-Abhängigkeiten ohne Netzwerkziele; `swift-testing`/ArgumentParser
  landen nicht im App-Bundle. `PrivacyInfo.xcprivacy` bleibt unverändert gültig.
- **TLS explizit statt Port-Heuristik:** `ConnectionSecurity+SwiftMail` übersetzt
  `implicit` → `.implicitTLS`, `startTLS` → `.startTLS` (erzwungen). Für SMTP war
  `.automatic` auf Port 587 nur „STARTTLS, falls angeboten"; jetzt bricht der
  Versand ab, wenn der Server STARTTLS nicht anbietet. TLS-Mindestversion bleibt
  1.2, Zertifikatsprüfung `.fullVerification`, TOFU-Pinning unverändert.
- **Ordner umbenennen/löschen:** `MailSyncEngine.renameFolder(_:toLeaf:)` und
  `deleteFolder(_:)`; `MailStore` aktualisiert Nachrichten und Auswahl. Die UI
  bietet beides im Kontextmenü eigener Ordner, Löschen mit Bestätigungsdialog.
  Systemordner sind gesperrt (`MailFolderError.systemFolder`), weil ihre Rolle
  Posteingang, Papierkorb-Ziel und Free/Pro-Fallback bestimmt. Verschachtelte
  Ordner behalten beim Umbenennen den Elternpfad (`leafName`/`renamedPath`).
- **109 Tests, 0 Fehler** (6 neue: `leafName`/`renamedPath`, Systemordner-Schutz,
  unbekannter Ordner).
- **Weiterhin nicht vorhanden:** `subscribe`/`unsubscribe` fehlen auch in 1.16.0;
  die App nutzt sie nicht.

---

*Letzte Aktualisierung: 2026-11-11 (OpenCode) — siehe Änderungsprotokoll oben*
