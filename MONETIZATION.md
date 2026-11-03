# MONETIZATION.md — Free, Pro und Abo

**Stand:** 2026-11-03 · **Status:** umgesetzt

*Keine Rechtsberatung. Preise, AGB und EULA vor dem Livegang prüfen lassen.*

---

## Kurzfassung

| Frage | Antwort |
|---|---|
| Modell | Freemium: dauerhaft nutzbare Gratisversion + Pro-Abo |
| Testphase | **7 Tage gratis über Apples Introductory Offer** — kein eigener Trial-Code |
| Preis | 1,99 €/Monat, 17,99 €/Jahr (Apple-Kleinstunternehmerprogramm: 15 % Provision) |
| Pro-Inhalt | Mehrere Konten, alle Server-Ordner, eigene Ordner anlegen, gemeinsamer Posteingang |
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

---

## 2. Free vs. Pro

| Kostenlos, dauerhaft | Pro |
|---|---|
| 1 Konto | beliebig viele Konten |
| Posteingang und Systemordner (Gesendet, Entwürfe, Papierkorb, Spam, Archiv) | alle Server-Ordner einschließlich eigener |
| Lesen, Senden, Antworten, Weiterleiten | eigene Ordner anlegen |
| Text- und HTML-Anzeige auf Knopfdruck | gemeinsamer Posteingang |
| externe Inhalte blockiert, Freigabe pro Mail/Absender | später: Signaturen, kontenübergreifende Suche |
| Tracking-Parameter entfernen, Links bestätigen | |
| TLS + Zertifikat-Pinning, Keychain | |
| Anhänge, Suche im Posteingang, MDN | |

**Ordnergrenze:** Systemordner bleiben frei, damit ein Konto auch ohne Abo vollständig
nutzbar ist. Nur eigene Ordner und der gemeinsame Posteingang verlangen Pro. Umbenennen
und Löschen von Ordnern fehlt bewusst: Die gepinnte SwiftMail-Revision bietet dafür keine
API; ein Knopf ohne Wirkung wäre schlechter als keiner.

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

### Verhalten beim Downgrade

Läuft das Abo aus, wird **nichts gelöscht**. Zusatzkonten bleiben gespeichert und lesbar,
aber sie werden nicht mehr synchronisiert. Ordner und Nachrichten bleiben erhalten. Ein
Abo-Ende darf nie Datenvernichtung bedeuten — das wäre ein Support-Alptraum und ein
Review-Risiko.

---

## 4. Pflichten im App Store

1. **Produkte in App Store Connect** anlegen (Abo-Gruppe „iMail Secure Pro", zwei Laufzeiten),
   Introductory Offer 1 Woche hinterlegen.
2. **Nutzungsbedingungen** (EULA) hinterlegen — sonst gilt Apples Standard-EULA und die
   Nicht-kommerziell-Klausel der PolyForm-Lizenz greift gegenüber App-Store-Nutzern nicht
   (siehe `LICENSING.md`, Abschnitt 3.1).
3. **`terms.html` auf der Website** veröffentlichen. StoreKit-Abos verlangen laut
   Guideline 3.1.2 einen funktionierenden Link auf die Nutzungsbedingungen — **im App und in
   den Metadaten**. Die Seite existiert noch nicht.
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

- [ ] Produkte + Introductory Offer in App Store Connect anlegen (braucht Developer-Account)
- [ ] `terms.html` schreiben und veröffentlichen
- [ ] EULA in App Store Connect hinterlegen
- [ ] Preise gegen den Markt prüfen (Wettbewerb: 1,99–4,99 €/Monat)
- [ ] Entscheiden, ob Familienfreigabe für das Abo aktiviert wird
- [ ] Prüfen, ob ein Lifetime-Kauf angeboten werden soll (deckt laufende Kosten nicht)
- [ ] Ordner umbenennen/löschen, sobald SwiftMail es anbietet oder ein eigener
      IMAP-Befehl ergänzt wird
- [ ] Steuer- und Bankdaten in App Store Connect hinterlegen (Voraussetzung für Auszahlung)
