# MONETIZATION.md — Free, Pro und Abo

**Stand:** 2026-11-03 · **Status:** umgesetzt

*Keine Rechtsberatung. Preise, AGB und EULA vor dem Livegang prüfen lassen.*

---

## Kurzfassung

| Frage | Antwort |
|---|---|
| Modell | Freemium: dauerhaft nutzbare Gratisversion + Pro-Abo |
| Testphase | **7 Tage gratis über Apples Introductory Offer** — kein eigener Trial-Code |
| Preis | 2,99 €/Monat, 24,99 €/Jahr, **39,99 € Lifetime** (Apple-Kleinstunternehmer: 15 % Provision) |
| Pro-Inhalt | Mehrere Konten, alle Server-Ordner, eigene Ordner anlegen/umbenennen/löschen, gemeinsamer Posteingang |
| Nie Pro | Datenschutzfunktionen (siehe Leitsatz 11 in `AGENTS.md`) |
| Technik | StoreKit 2, Prüfung auf dem Gerät, **kein Backend**, keine Drittanbieter-SDKs |
| Datenweitergabe | keine an den Entwickler; Zahlungsdaten verarbeitet ausschließlich Apple |

---

## 1. Warum kein selbstgebauter 7-Tage-Timer

Apple kennt eine „Gratis-Testphase" nur als **Introductory Offer** am Abo. Ein eigener Timer
in der App wäre:

- **umgehbar** (App löschen, neu installieren),
- **doppelte Logik** (Trial, Free-Tier und Abo müssen konsistent bleiben),
- **erklärungsbedürftig im Review**, weil es wie eine nachträgliche Paywall aussieht.

Mit dem Introductory Offer steht im Kaufdialog „7 Tage gratis", Apple beendet die Testphase
selbst, und die App kennt nur zwei Zustände: `free` oder `pro`. Der Code enthält deshalb
**keine** Trial-Logik.

Einzustellen in App Store Connect → Abonnements → Produkt → **Einführungsangebot**:
Typ „Kostenlose Testphase", Dauer 1 Woche, für alle Neukunden.

**Lifetime (neu):** Non-Consumable `io.imailsecure.pro.lifetime` 39,99 € anlegen.
**Family Sharing:** In App Store Connect → Abonnement-Gruppe → „Familienfreigabe" aktivieren.

---

## 2. Free vs. Pro

| Kostenlos, dauerhaft | Pro / Lifetime |
|---|---|
| 1 Konto | beliebig viele Konten |
| Posteingang und Systemordner (Gesendet, Entwürfe, Papierkorb, Spam, Archiv) | alle Server-Ordner einschließlich eigener |
| Lesen, Senden, Antworten, Weiterleiten | eigene Ordner anlegen, umbenennen, löschen |
| Text- und HTML-Anzeige auf Knopfdruck | gemeinsamer Posteingang |
| externe Inhalte blockiert, Freigabe pro Mail/Absender | später: Signaturen, kontenübergreifende Suche |
| Tracking-Parameter entfernen, Links bestätigen | |
| TLS + Zertifikat-Pinning, Keychain | |
| Anhänge, Suche im Posteingang, MDN | |
| **Familienfreigabe** | ✅ (bis 5 Familienmitglieder) |

**Ordnergrenze:** Systemordner bleiben frei, damit ein Konto auch ohne Abo vollständig
nutzbar ist. Nur eigene Ordner und der gemeinsame Posteingang verlangen Pro. Eigene Ordner
lassen sich anlegen, umbenennen und löschen. Systemordner sind bewusst gesperrt: Ihre Rolle
bestimmt Posteingang, Papierkorb-Ziel und den Free/Pro-Fallback — ein umbenannter
Posteingang würde diese Logik brechen.

**Regel:** Pro ist Bequemlichkeit, nicht Sicherheit. Eine Privacy-App, die ihre
Schutzfunktionen hinter ein Abo legt, wäre unglaubwürdig — und würde das einzige Argument
entwerten, das sie von anderen Mail-Apps unterscheidet.

Die Tabelle im Code ist `Feature` in `Sources/iMailSecure/Models/Entitlement.swift`. Neue
Pro-Funktionen werden **dort** ergänzt; Gates fragen `subscription.canUse(_:)`, nie ein
verstreutes `if isPro`. Solange eine Funktion nicht gebaut ist, gehört sie nicht in die
Liste — die Paywall darf nichts bewerben, was es nicht gibt.

---

## 3. Technik

```
SubscriptionManager   StoreKit 2: Produkte, Kauf, Wiederherstellen, Transaktions-Listener
Entitlement           reine Funktionen: Produkt-IDs → Tier, Kontolimit, Feature-Tabelle
PaywallView           erscheint nur am Ort des Bedarfs
```

- **Kein Backend.** Apple signiert jede Transaktion; `Transaction.currentEntitlements`
  prüft sie auf dem Gerät. Es gibt keine Nutzerdaten beim Entwickler, das Datenschutzlabel
  bleibt „Keine Daten erfasst".
- **Offline:** Der zuletzt bekannte Zustand liegt im Keychain. Ohne gespeicherten Zustand
  gilt `free` (fail-closed).
- **Produkte werden erst geladen, wenn die Paywall geöffnet wird** — kein Netzwerkaufruf
  beim App-Start.
- **Produkt-IDs:** `io.imailsecure.pro.monthly`, `io.imailsecure.pro.yearly`
  (eine Subscription Group, damit Jahres-/Monatsabo sich gegenseitig ablösen).
- **Lifetime:** `io.imailsecure.pro.lifetime` (Non-Consumable, eigene Produkt-ID,
  **nicht** in der Abo-Gruppe — einmalig kaufen, dauerhaft Pro).
- **Testen ohne Developer-Account:** `iMailSecure.storekit` ist im Schema hinterlegt.
  Produkte, Kauf, Kündigung und Rückerstattung lassen sich im Simulator durchspielen.

### Gates im Code

| Datei | Wirkung |
|---|---|
| `SettingsView` | „Konto hinzufügen" öffnet bei erreichtem Limit die Paywall |
| `AccountSetupView.saveAccount()` | zweite Sicherung, falls das Sheet offen bleibt |
| `SubscriptionManager.canAddAccount(currentCount:)` | einzige Entscheidung über das Kontolimit |
| `FolderListView` | gemeinsamer Posteingang und eigene Ordner öffnen bei Free die Paywall |
| `InboxView` / `MailStore.selection` | die Nachrichtenliste folgt der Ordnerauswahl |
| `MainTabView` | fragt bei mehreren Konten, von welchem gesendet wird |

### Verhalten beim Downgrade / Lifetime

Läuft das Abo aus, wird **nichts gelöscht**. Zusatzkonten bleiben gespeichert und lesbar,
aber sie werden nicht mehr synchronisiert. Ordner und Nachrichten bleiben erhalten. Ein
Abo-Ende darf nie Datenvernichtung bedeuten — das wäre ein Support-Alptraum und ein
Review-Risiko.

**Lifetime-Kauf** = dauerhaft `pro` Tier. Kein Ablauf, keine Wiederherstellung nötig
(Non-Consumable bleibt in `Transaction.currentEntitlements`).

---

## 4. Pflichten im App Store

1. **Produkte in App Store Connect** anlegen:
   - Abo-Gruppe „iMail Secure Pro": `monthly` 2,99 €, `yearly` 24,99 €
   - Introductory Offer 1 Woche hinterlegen
   - **Non-Consumable**: `io.imailsecure.pro.lifetime` 39,99 €
   - **Familienfreigabe** für die Abo-Gruppe aktivieren
2. **Nutzungsbedingungen** (EULA) hinterlegen — sonst gilt Apples Standard-EULA und die
   Nicht-kommerziell-Klausel der PolyForm-Lizenz greift gegenüber App-Store-Nutzern nicht
   (siehe `LICENSING.md`, Abschnitt 3.1).
3. **`terms.html` auf der Website** veröffentlichen. StoreKit-Abos verlangen laut
   Guideline 3.1.2 einen funktionierenden Link auf die Nutzungsbedingungen — **in der App und
   in den Metadaten**. Veröffentlicht am 2026-11-12 als **Entwurf**; die anwaltliche Prüfung
   steht noch aus (siehe `terms.html`, Badge „Entwurf").
4. **„Käufe wiederherstellen"** ist Pflicht und in den Einstellungen und in der Paywall
   vorhanden.
5. **Preis, Laufzeit, Auto-Verlängerung** müssen im App Store und in der Paywall sichtbar
   sein (die Paywall liest sie aus StoreKit).
6. **Apple-Kleinstunternehmerprogramm** beantragen: 15 % statt 30 % bei unter 1 Mio. USD
   Jahresumsatz.
7. **Datenschutzerklärung** um den Hinweis ergänzen, dass Abos über Apple laufen und
   Zahlungsdaten nicht beim Entwickler anfallen.

---

## 5. Offen

- [x] Preise angehoben: 2,99 € / 24,99 € + Lifetime 39,99 €
- [ ] Produkte + Introductory Offer + Lifetime in App Store Connect anlegen
- [ ] Familienfreigabe in App Store Connect aktivieren
- [x] `terms.html` entworfen und veröffentlicht (Entwurf, juristische Prüfung offen)
- [ ] EULA in App Store Connect hinterlegen
- [ ] Steuer- und Bankdaten in App Store Connect hinterlegen (Voraussetzung für Auszahlung)
