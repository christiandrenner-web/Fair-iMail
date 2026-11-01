# LICENSING.md — Lizenz, App Store und Monetarisierung

**Stand:** 2026-11-01 · **Status:** entschieden — **Option A** (GPLv3 + App-Store-Ausnahme + CLA)
*Keine Rechtsberatung — das ist eine technische und organisatorische Einschätzung.
Vor einer kommerziellen Veröffentlichung sollte ein Anwalt für IT-Recht drüberschauen.*

---

## Kurzfassung

| Frage | Antwort |
|---|---|
| Verbietet Apple Open Source? | **Nein.** Die App Review Guidelines kennen keine Lizenzbedingung. |
| Ist GPLv3 mit dem App Store vereinbar? | **Nur eingeschränkt.** Die Apple-ToS kollidieren mit GPLv3 §3 (DRM) und §10 (keine Zusatzbeschränkungen). |
| Prüft Apple die Lizenz beim Upload? | **Nein.** Entfernt wird auf Beschwerde — nicht automatisch. |
| Darf man mit GPL Geld verdienen? | **Ja.** GPL verbietet keine Preise. FairEmail ist GPLv3 und kostet im Play Store Geld. |
| Bist du betroffen? | **Nur, wenn fremder Code im Projekt landet.** Als alleiniger Urheber darfst du dein eigenes Werk unter beiden Bedingungen anbieten. |

---

## 1. Wo genau der Konflikt liegt

Nicht in „offener Code ist unsicher", sondern in zwei konkreten Klauseln:

**GPLv3 §3 (Anti-Tivoization / DRM)**
Wer das Werk verbreitet, darf niemandem das Recht nehmen, technische Schutzmaßnahmen zu
umgehen. Apple liefert jede App mit FairPlay-DRM aus und verbietet das Umgehen.

**GPLv3 §10 (keine zusätzlichen Beschränkungen)**
„You may not impose any further restrictions on the recipients' exercise of the rights
granted herein." Apples Nutzungsbedingungen beschränken u. a. auf autorisierte Geräte und
verlangen die Zustimmung zu Apples ToS — beides Zusatzbeschränkungen.

Dazu kommt: Der Nutzer kann eine App-Store-App nicht durch eine selbst kompilierte Version
ersetzen. Genau davor schützt GPLv3 §6 (Installationsinformationen) — auf iOS nicht erfüllbar.

**Präzedenzfälle**
- 2010: GNU Go aus dem App Store entfernt (FSF-Beschwerde).
- 2011: VLC entfernt, nachdem ein **Mitentwickler** Beschwerde eingelegt hatte. VideoLAN
  löste es durch Relizenzierung von libVLC unter LGPLv2.1+.

In beiden Fällen war nicht Apple der Auslöser, sondern ein Rechteinhaber.

---

## 2. Warum dein Fall anders liegt

Du bist (Stand heute) **alleiniger Urheber** — das Repo ist lokal, es gibt keine
veröffentlichte Version, keine Fremdbeiträge. Ein Urheber darf sein eigenes Werk
gleichzeitig:

1. der Allgemeinheit unter **GPLv3** anbieten (Quellcode auf GitHub o. ä.), und
2. selbst als **App-Store-Binary unter Apples Bedingungen** verbreiten.

Das ist keine Doppellizenzierung, sondern schlicht das Urheberrecht an der eigenen Arbeit.
Es gibt niemanden, der sich beschweren könnte — außer dir selbst.

**Die Bedingung:** Das gilt nur, solange **alle** Rechteinhaber zustimmen. Sobald ein
fremder Pull Request ohne Rechteübertragung gemergt wird, hat dieser Beitragende seinen Code
unter GPLv3 beigesteuert. Dann wäre die App-Store-Distribution dieses Codes eine
GPL-Verletzung — und er könnte die Entfernung verlangen (wie bei VLC).

**Konsequenz:** Wenn das Projekt offen für Beiträge werden soll → **CLA** (Contributor
License Agreement) oder zumindest eine ausdrückliche Erklärung pro PR, dass der Beitrag
auch unter Apples Bedingungen lizenziert werden darf.

---

## 3. Optionen im Vergleich

### A) GPLv3 + App-Store-Ausnahme (§7) + CLA — **Empfehlung**
GPLv3 erlaubt in §7 „additional permissions". Du ergänzt eine Erlaubnis, das Werk auch unter
den Bedingungen des Apple App Store zu verbreiten. Quellcode bleibt offen, App Store bleibt
möglich, Copyleft bleibt erhalten.

- Aufwand: eine Textdatei (`LICENSE-EXCEPTION`), ein CLA für Beitragende
- Risiko: gering; die Formulierung sollte juristisch geprüft werden
- Vorteil: passt zu einem Datenschutz-Projekt — nachvollziehbar und offen

### B) Doppellizenz (GPLv3 + kommerzielle Lizenz)
Du vergibst die App-Store-Version unter einer eigenen/proprietären Lizenz und den Quellcode
unter GPL. Funktioniert nur mit vollständigen Rechten (CLA).

- Vorteil: maximale Freiheit bei der Monetarisierung
- Nachteil: mehr Verwaltung; „Open Core"-Modelle werden von der Community oft kritisch gesehen

### C) Permissive Lizenz (MIT / Apache-2.0)
Keine Copyleft-Pflichten, App Store völlig unproblematisch.

- Vorteil: einfachste Variante, keine Rechtsprüfung nötig
- Nachteil: jeder darf deine App klonen und kommerziell verwerten, ohne etwas zurückzugeben
- Für ein Datenschutz-Projekt mit Anspruch „nachprüfbar" schwächer als GPL

### D) GPLv3 bleiben, aber nicht in den App Store
Verteilung über EU-Sideloading (AltStore, Setapp), TestFlight oder eigene Website.
TestFlight unterliegt allerdings ebenfalls Apples Bedingungen — also auch nicht sauber.

---

## 4. Monetarisierung

- **GPL verbietet keine Preise.** Du darfst Geld verlangen; du musst nur den Quellcode
  mitliefern bzw. zugänglich machen.
- **FairEmail als Beweis:** GPLv3, kostenlos auf GitHub/F-Droid, Bezahlversion im Play Store.
  Funktioniert, weil Google Play kein DRM wie FairPlay erzwingt.
- **App Store:** Bezahl-Apps und In-App-Käufe sind möglich (Apple: 15 % bzw. 30 %).
  Bei Option A oder B ist das kein Lizenzproblem.
- **Nicht möglich:** „Open Source als Werbung, aber Code geheim halten". Wenn du den Code
  nicht veröffentlichen willst, ist es schlicht keine GPL-App — dann Option C oder komplett
  geschlossen.

---

## 5. Abhängigkeiten (geprüft)

| Bibliothek | Lizenz | App-Store-tauglich |
|---|---|---|
| SwiftMail (Cocoanetics) | BSD-3-Clause | ✅ |
| swift-log (Apple) | Apache-2.0 | ✅ |

Es gibt **keine** Copyleft-Abhängigkeit, die dich zu GPL zwingt. Die Lizenzwahl ist frei.

---

## 6. Umsetzung (entschieden: Option A)

1. ✅ `LICENSE` — GPL-3.0-Volltext liegt im Repo.
2. ✅ Entscheidung L1: **Option A**.
3. ✅ `LICENSE-EXCEPTION` — Zusatzgenehmigung nach §7 für den Apple App Store.
4. ✅ `CLA.md` — Beitragende räumen die App-Store-Verbreitung mit ein.
5. ✅ `README.md` und `AGENTS.md` an die Entscheidung angepasst.

### Was das praktisch bedeutet

- Der Quellcode bleibt **GPLv3**. Wer die App weiterverbreitet, muss die Quellen
  zugänglich machen — auch für eine App-Store-Version.
- Die Zusatzgenehmigung erlaubt **nur** den zusätzlichen Vertriebsweg, sie macht
  aus der GPL keine permissive Lizenz.
- Fremde Beiträge nur mit CLA mergen. Ohne CLA ist der Beitrag GPL-only und
  blockiert die App-Store-Verbreitung.
- Vor der ersten Veröffentlichung: `LICENSE-EXCEPTION` und `CLA.md` anwaltlich
  prüfen lassen und in beiden Dateien den **bürgerlichen Namen** des
  Rechteinhabers eintragen (aktuell steht dort „NuCo").

### Offener Punkt, der leicht übersehen wird

Die GPL verlangt bei Weitergabe **Quellcode-Zugang**. Eine App-Store-Version
ohne öffentlich erreichbare Quellen wäre also auch mit dieser Ausnahme nicht
sauber. Das App-Repo kann bis zur Veröffentlichung privat bleiben; spätestens
zur Einreichung muss der Quellcode zugänglich sein (öffentliches Repo oder
Release-Archiv).
