# LICENSING.md — Lizenz, App Store und Monetarisierung

**Stand:** 2026-11-01 · **Status:** entschieden — **Option B: source-available,
nicht-kommerziell** (PolyForm Noncommercial 1.0.0)

*Keine Rechtsberatung — das ist eine technische und organisatorische Einschätzung.
Vor einer kommerziellen Veröffentlichung sollte ein Anwalt für IT-Recht drüberschauen.*

---

## Kurzfassung

| Frage | Antwort |
|---|---|
| Welche Lizenz? | **PolyForm Noncommercial 1.0.0** (`LICENSE`) |
| Ist das „Open Source"? | **Nein.** Nicht OSI-zertifiziert — die Bezeichnung darf nicht verwendet werden. |
| Ist der Quellcode einsehbar? | Ja, sobald veröffentlicht. Einsehbar ≠ freie Verwertung. |
| Dürfen andere die App kommerziell nutzen oder verkaufen? | **Nein.** |
| Darfst du selbst Geld damit verdienen? | **Ja** — als Rechteinhaber bindet dich deine eigene Lizenz nicht. |
| Ist das App-Store-tauglich? | **Ja**, ohne Zusatzgenehmigung. Der GPL-Konflikt entfällt komplett. |
| Fremde Beiträge? | Nur mit `CLA.md`, sonst nicht mergebar. |

---

## 1. Was die Lizenz erlaubt und verbietet

**Erlaubt** (für Privatpersonen, nicht-kommerziell):

- die App benutzen,
- den Quellcode lesen und prüfen — das ist der Zweck der Übung,
- ihn verändern und eigene Versionen bauen,
- Kopien weitergeben, solange Lizenztext und Copyright-Hinweis mitkommen.

**Verboten:**

- jede kommerzielle Nutzung durch Lizenznehmer, also Verkauf, Bezahl-Angebote,
  Werbe-Finanzierung oder Einsatz in einem Unternehmen zu Geschäftszwecken,
- Weiterverbreitung ohne Lizenztext.

**Nicht betroffen:** Du als Rechteinhaber. Du kannst die App im App Store
verkaufen, Spenden annehmen oder In-App-Käufe anbieten. Du lizenzierst, du
nimmst die Lizenz nicht in Anspruch.

---

## 2. Warum nicht GPL

Die vorherige Entscheidung war GPLv3 + App-Store-Ausnahme. Sie ist verworfen,
weil sie genau das erzwungen hätte, was vermieden werden soll:

| Punkt | GPLv3 |
|---|---|
| Quellcode bei jeder Weitergabe | **Pflicht** — beim App-Store-Vertrieb also öffentlich |
| Kommerzielle Forks durch Dritte | **erlaubt** (müssen GPL bleiben) |
| Konflikt mit Apples DRM/ToS | vorhanden, braucht §7-Zusatzgenehmigung |
| Aussage „Code bleibt geschlossen" | nicht möglich |

Kurz: GPL und „Code geheim halten" schließen sich aus. Wer die GPL wählt,
wählt die Veröffentlichung. Wenn das nicht gewollt ist, muss die Lizenz
wechseln — nicht die Formulierung.

---

## 3. Zwei Haken, die man kennen muss

### 3.1 App Store: eigene EULA hinterlegen

Apple wendet ohne eigenes EULA den **Apple Standard End User License
Agreement** an. Der erlaubt Nutzung auf Apple-Geräten ohne die
„nicht-kommerziell"-Beschränkung. Damit deine Lizenz im App Store tatsächlich
gilt, muss in **App Store Connect → App-Informationen → Lizenzvereinbarung**
eine eigene EULA hinterlegt werden (Lizenztext einfügen oder auf `LICENSE`
verlinken).

Ohne diesen Schritt ist die Lizenz gegenüber App-Store-Nutzern faktisch
wirkungslos — der Code bleibt trotzdem dein Eigentum, aber die
Nutzungsbeschränkung greift nicht.

### 3.2 Geschäftliche Nutzung ist mitverboten

PolyForm Noncommercial verbietet „commercial purposes". Ein Angestellter, der
damit Arbeits-E-Mails liest, nutzt die App kommerziell — und dürfte das nach
dieser Lizenz nicht.

Zwei saubere Wege:

- **So lassen und daraus ein Geschäftsmodell machen:** privat kostenlos oder
  günstig, Firmen brauchen eine kostenpflichtige Lizenz (Dual Licensing). Für
  einen E-Mail-Client ist das ein legitimer Weg.
- **Weichere Lizenz:** PolyForm Small Business 1.0.0 erlaubt Nutzung in
  Unternehmen unter 100 Mitarbeitenden und unter 1 Mio. USD Umsatz. Dann ist
  der Alltag der meisten Nutzer abgedeckt, Großkonzerne brauchen weiterhin eine
  Lizenz.

Die Entscheidung ist ein Dateitausch (`LICENSE`) plus Anpassung von CLA und
Doku — jederzeit möglich, solange niemand eine Kopie erhalten hat.

---

## 4. Was das für die Außendarstellung bedeutet

„Open Source" und „quelloffen" sind **belegt** und dürfen hier nicht stehen.
Zulässig und ehrlich:

- „Der Quellcode ist einsehbar und nachprüfbar."
- „Source-available, nicht-kommerziell."
- „Kein Open Source, aber überprüfbar."

Das ist für eine Datenschutz-App immer noch ein starkes Argument: Nutzer und
Sicherheitsforscher können nachlesen, dass keine Telemetrie existiert — sie
dürfen den Code nur nicht kommerziell verwerten.

---

## 5. Abhängigkeiten (geprüft)

| Bibliothek | Lizenz | Kompatibel |
|---|---|---|
| SwiftMail (Cocoanetics) | BSD-3-Clause | ✅ erlaubt kommerzielle Nutzung |
| swift-log (Apple) | Apache-2.0 | ✅ erlaubt kommerzielle Nutzung |

Beide sind permissiv und verlangen nur die Beibehaltung der Copyright- und
Lizenzhinweise. Es gibt keine Copyleft-Abhängigkeit, die eine
Veröffentlichung erzwingt.

---

## 6. Entfernt / ersetzt am 2026-11-01

- `LICENSE` — GPL-3.0-Volltext ersetzt durch PolyForm Noncommercial 1.0.0.
- `LICENSE-EXCEPTION` — **gelöscht**. Die §7-Zusatzgenehmigung war nur für den
  GPL-Konflikt nötig; der existiert nicht mehr.
- `CLA.md` — neu gefasst: Beitragende räumen auch kommerzielle Verwertung und
  Relizenzierung ein (Voraussetzung für Dual Licensing).
- `README.md`, `AGENTS.md`, `SettingsView.swift` — Lizenzangaben angepasst.

## 7. Offen

1. **Kontaktadresse** für Impressum und Support (Freemailer-Postfach).
2. **Eigene EULA** in App Store Connect hinterlegen (siehe 3.1).
3. **Entscheidung Small Business vs. Noncommercial** (siehe 3.2).
4. **Marke „iMail Secure"** — der wirksamste Schutz gegen Klone ist nicht der
   Quellcode, sondern die Marke. Eine DPMA-Anmeldung für eine Klasse kostet
   rund 290 €. GPL hin oder her: Wer den Namen nutzt, verletzt Markenrecht.
