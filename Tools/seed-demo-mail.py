#!/usr/bin/env python3
"""Füllt das Testpostfach mit Demo-Nachrichten in der gewünschten Sprache.

Die App-Store-Screenshots zeigen echte Nachrichten aus einem echten
IMAP-Postfach. Damit in jeder Sprache auch der Inhalt stimmt, leert dieses
Skript den Posteingang und legt danach sechs kurze Nachrichten plus einen
HTML-Newsletter an — alles mit `example`-Absendern, also ohne echte Daten.

    python3 Tools/seed-demo-mail.py tr

Zugangsdaten kommen aus ~/.config/imailsecure/gmail-test.env
(IMAP_USER, IMAP_PASSWORD, IMAP_HOST) und stehen nie im Repository.
"""

from __future__ import annotations

import base64
import email.utils
import imaplib
import pathlib
import re
import sys
import time
from email.message import EmailMessage
from html import unescape

ENV_FILE = pathlib.Path.home() / ".config/imailsecure/gmail-test.env"

# (Anzeigename, Adresse, Betreff, Text, gelesen)
DEMO: dict[str, list[tuple[str, str, str, str, bool]]] = {
    "de-DE": [
        ("iMail Secure", "team@imailsecure.example", "Willkommen bei iMail Secure",
         "Schön, dass du da bist.\n\nDiese App zeigt Mails zuerst als reinen Text. "
         "HTML und externe Bilder lädst du nur bewusst nach – pro Mail oder pro Absender.\n\n"
         "Viel Spaß\nDein iMail-Secure-Team", False),
        ("Reisebüro Weber", "info@reise-weber.example", "Ihre Buchung: Lissabon, 12.–19. Juni",
         "Guten Tag,\n\nanbei die Bestätigung für Ihre Reise nach Lissabon.\n"
         "Flug: 12. Juni, 09:40 ab München\nHotel: 7 Nächte, Zimmer mit Frühstück\n\n"
         "Bitte prüfen Sie die Angaben und melden Sie sich bei Fragen.\n\nReisebüro Weber", False),
        ("Anna Weber", "anna@example.example", "Fotos vom Wochenende",
         "Hallo,\n\nhier kommen die Bilder vom Ausflug an den See. "
         "Das Wetter war besser als gemeldet.\n\nLiebe Grüße\nAnna", True),
        ("Stadtwerke München", "rechnung@swm.example", "Ihre Rechnung 2026-0417",
         "Sehr geehrte Damen und Herren,\n\nim Anhang finden Sie Ihre Jahresabrechnung.\n"
         "Der Betrag wird zum 30. November abgebucht.\n\nMit freundlichen Grüßen\nStadtwerke München", True),
        ("Paketdienst", "sendung@paket.example", "Ihr Paket ist unterwegs",
         "Ihre Sendung kommt voraussichtlich morgen zwischen 10 und 12 Uhr an.\n"
         "Sie können den Zustellort bis heute 18 Uhr ändern.", True),
        ("Kanzlei Berger", "post@kanzlei-berger.example", "Terminbestätigung Donnerstag",
         "Guten Tag,\n\nwir bestätigen Ihren Termin am Donnerstag um 14:30 Uhr.\n"
         "Bitte bringen Sie die Unterlagen mit.\n\nFreundliche Grüße", True),
    ],
    "en-US": [
        ("iMail Secure", "team@imailsecure.example", "Welcome to iMail Secure",
         "Good to have you here.\n\nThis app shows mail as plain text first. "
         "HTML and remote images are only loaded when you ask for them — per message "
         "or per sender.\n\nEnjoy\nYour iMail Secure team", False),
        ("Weber Travel", "info@reise-weber.example", "Your booking: Lisbon, June 12–19",
         "Hello,\n\nattached is the confirmation for your trip to Lisbon.\n"
         "Flight: June 12, 09:40 from Munich\nHotel: 7 nights, room with breakfast\n\n"
         "Please check the details and get in touch with any questions.\n\nWeber Travel", False),
        ("Anna Weber", "anna@example.example", "Photos from the weekend",
         "Hi,\n\nhere are the pictures from the lake trip. "
         "The weather was better than forecast.\n\nBest\nAnna", True),
        ("City Utilities", "rechnung@swm.example", "Your invoice 2026-0417",
         "Dear customer,\n\nthe annual statement is attached.\n"
         "The amount will be charged on 30 November.\n\nKind regards\nCity Utilities", True),
        ("Parcel Service", "sendung@paket.example", "Your parcel is on its way",
         "Your delivery should arrive tomorrow between 10 and 12.\n"
         "You can change the drop-off point until 18:00 today.", True),
        ("Berger Law", "post@kanzlei-berger.example", "Appointment confirmed for Thursday",
         "Hello,\n\nwe confirm your appointment on Thursday at 14:30.\n"
         "Please bring the documents with you.\n\nKind regards", True),
    ],
    "es-ES": [
        ("iMail Secure", "team@imailsecure.example", "Bienvenido a iMail Secure",
         "Nos alegra tenerte aquí.\n\nEsta app muestra el correo primero como texto plano. "
         "El HTML y las imágenes externas solo se cargan cuando lo pides — por mensaje "
         "o por remitente.\n\nDisfrútalo\nTu equipo de iMail Secure", False),
        ("Agencia Weber", "info@reise-weber.example", "Tu reserva: Lisboa, 12–19 de junio",
         "Hola,\n\nadjuntamos la confirmación de tu viaje a Lisboa.\n"
         "Vuelo: 12 de junio, 09:40 desde Múnich\nHotel: 7 noches, habitación con desayuno\n\n"
         "Revisa los datos y escríbenos si tienes dudas.\n\nAgencia Weber", False),
        ("Anna Weber", "anna@example.example", "Fotos del fin de semana",
         "Hola,\n\naquí van las fotos de la excursión al lago. "
         "El tiempo fue mejor de lo previsto.\n\nUn abrazo\nAnna", True),
        ("Servicios Municipales", "rechnung@swm.example", "Tu factura 2026-0417",
         "Estimado cliente:\n\nadjuntamos la liquidación anual.\n"
         "El importe se cobrará el 30 de noviembre.\n\nAtentamente\nServicios Municipales", True),
        ("Paquetería", "sendung@paket.example", "Tu paquete está en camino",
         "La entrega llegará previsiblemente mañana entre las 10 y las 12.\n"
         "Puedes cambiar el punto de entrega hasta hoy a las 18:00.", True),
        ("Bufete Berger", "post@kanzlei-berger.example", "Cita confirmada para el jueves",
         "Hola:\n\nconfirmamos tu cita del jueves a las 14:30.\n"
         "Trae los documentos, por favor.\n\nSaludos cordiales", True),
    ],
    "fr-FR": [
        ("iMail Secure", "team@imailsecure.example", "Bienvenue dans iMail Secure",
         "Ravi de vous accueillir.\n\nCette app affiche d'abord vos e-mails en texte brut. "
         "Le HTML et les images externes ne se chargent que sur demande — par message "
         "ou par expéditeur.\n\nBonne lecture\nVotre équipe iMail Secure", False),
        ("Agence Weber", "info@reise-weber.example", "Votre réservation : Lisbonne, 12–19 juin",
         "Bonjour,\n\nveuillez trouver la confirmation de votre voyage à Lisbonne.\n"
         "Vol : 12 juin, 09h40 au départ de Munich\nHôtel : 7 nuits, chambre avec petit-déjeuner\n\n"
         "Merci de vérifier ces informations et de nous écrire en cas de question.\n\nAgence Weber", False),
        ("Anna Weber", "anna@example.example", "Photos du week-end",
         "Salut,\n\nvoici les photos de la sortie au lac. "
         "Le temps était meilleur que prévu.\n\nBises\nAnna", True),
        ("Services municipaux", "rechnung@swm.example", "Votre facture 2026-0417",
         "Madame, Monsieur,\n\nvous trouverez ci-joint votre décompte annuel.\n"
         "Le montant sera prélevé le 30 novembre.\n\nCordialement\nServices municipaux", True),
        ("Transporteur", "sendung@paket.example", "Votre colis est en route",
         "Votre livraison arrivera demain entre 10 h et 12 h.\n"
         "Vous pouvez modifier le point de livraison jusqu'à 18 h aujourd'hui.", True),
        ("Cabinet Berger", "post@kanzlei-berger.example", "Rendez-vous confirmé jeudi",
         "Bonjour,\n\nnous confirmons votre rendez-vous jeudi à 14h30.\n"
         "Merci d'apporter les documents.\n\nBien cordialement", True),
    ],
    "ru": [
        ("iMail Secure", "team@imailsecure.example", "Добро пожаловать в iMail Secure",
         "Рады видеть вас.\n\nПриложение сначала показывает письма как обычный текст. "
         "HTML и внешние изображения загружаются только по запросу — для письма "
         "или отправителя.\n\nПриятного чтения\nКоманда iMail Secure", False),
        ("Турагентство Вебер", "info@reise-weber.example", "Ваша поездка: Лиссабон, 12–19 июня",
         "Здравствуйте!\n\nВо вложении подтверждение вашей поездки в Лиссабон.\n"
         "Рейс: 12 июня, 09:40 из Мюнхена\nОтель: 7 ночей, номер с завтраком\n\n"
         "Проверьте данные и напишите нам, если появятся вопросы.\n\nТурагентство Вебер", False),
        ("Анна Вебер", "anna@example.example", "Фотографии с выходных",
         "Привет!\n\nВот фотографии с поездки на озеро. "
         "Погода была лучше, чем обещали.\n\nОбнимаю\nАнна", True),
        ("Городские службы", "rechnung@swm.example", "Ваш счёт 2026-0417",
         "Уважаемый клиент!\n\nВо вложении годовой расчёт.\n"
         "Сумма будет списана 30 ноября.\n\nС уважением\nГородские службы", True),
        ("Служба доставки", "sendung@paket.example", "Ваша посылка в пути",
         "Доставка ожидается завтра с 10 до 12 часов.\n"
         "Изменить место доставки можно до 18:00 сегодня.", True),
        ("Юридическая фирма Бергер", "post@kanzlei-berger.example", "Встреча подтверждена на четверг",
         "Здравствуйте!\n\nПодтверждаем вашу встречу в четверг в 14:30.\n"
         "Пожалуйста, возьмите с собой документы.\n\nС уважением", True),
    ],
    "tr": [
        ("iMail Secure", "team@imailsecure.example", "iMail Secure'a hoş geldiniz",
         "Burada olmanıza sevindik.\n\nBu uygulama e-postaları önce düz metin olarak gösterir. "
         "HTML ve harici görseller yalnızca istediğinizde yüklenir — ileti başına "
         "veya gönderen başına.\n\nİyi okumalar\niMail Secure ekibi", False),
        ("Weber Seyahat", "info@reise-weber.example", "Rezervasyonunuz: Lizbon, 12–19 Haziran",
         "Merhaba,\n\nLizbon seyahatinizin onayı ekte.\n"
         "Uçuş: 12 Haziran, 09:40 Münih kalkışlı\nOtel: 7 gece, kahvaltılı oda\n\n"
         "Lütfen bilgileri kontrol edin ve sorularınız için bize yazın.\n\nWeber Seyahat", False),
        ("Anna Weber", "anna@example.example", "Hafta sonu fotoğrafları",
         "Merhaba,\n\ngöl gezisinden fotoğraflar burada. "
         "Hava tahmin edilenden daha iyiydi.\n\nSevgiler\nAnna", True),
        ("Şehir Hizmetleri", "rechnung@swm.example", "Faturanız 2026-0417",
         "Sayın müşterimiz,\n\nyıllık hesap ekte.\n"
         "Tutar 30 Kasım'da tahsil edilecek.\n\nSaygılarımızla\nŞehir Hizmetleri", True),
        ("Kargo Servisi", "sendung@paket.example", "Kargonuz yolda",
         "Teslimatınız yarın 10 ile 12 arasında gelecek.\n"
         "Teslim noktasını bugün 18:00'e kadar değiştirebilirsiniz.", True),
        ("Berger Hukuk Bürosu", "post@kanzlei-berger.example", "Perşembe randevusu onaylandı",
         "Merhaba,\n\nperşembe 14:30'daki randevunuzu onaylıyoruz.\n"
         "Lütfen belgeleri yanınızda getirin.\n\nSaygılarımızla", True),
    ],
}

NEWSLETTER: dict[str, tuple[str, str, str, str]] = {
    # (Absendername, Adresse, Betreff, HTML)
    "de-DE": ("Bergzeit Magazin", "magazin@bergzeit.example", "Fünf Tipps für längere Akkus",
              "<h1 style=\"font-size:24px;margin:0 0 12px\">Fünf Tipps für längere Akkus</h1>"
              "<p style=\"font-size:16px;line-height:1.5;color:#3a3a3c\">Ein Akku hält länger, "
              "wenn er nicht ständig zwischen 0 und 100 Prozent pendelt. Diese fünf Regeln "
              "helfen im Alltag – ohne Zubehör.</p>"
              "<ol style=\"font-size:16px;line-height:1.6\">"
              "<li>Lade zwischen 20 und 80 Prozent.</li>"
              "<li>Vermeide Wärme beim Laden.</li>"
              "<li>Schalte Hintergrundaktualisierungen ab.</li></ol>"
              "<p style=\"font-size:12px;color:#8e8e93\">Sie erhalten diesen Newsletter, "
              "weil Sie sich dafür angemeldet haben.</p>"),
    "en-US": ("Bergzeit Magazine", "magazin@bergzeit.example", "Five tips for a longer battery life",
              "<h1 style=\"font-size:24px;margin:0 0 12px\">Five tips for a longer battery life</h1>"
              "<p style=\"font-size:16px;line-height:1.5;color:#3a3a3c\">A battery lasts longer "
              "when it does not swing between 0 and 100 percent all day. These five rules help "
              "in everyday use — no accessories needed.</p>"
              "<ol style=\"font-size:16px;line-height:1.6\">"
              "<li>Charge between 20 and 80 percent.</li>"
              "<li>Keep it cool while charging.</li>"
              "<li>Turn off background refresh.</li></ol>"
              "<p style=\"font-size:12px;color:#8e8e93\">You receive this newsletter because "
              "you signed up for it.</p>"),
    "es-ES": ("Revista Bergzeit", "magazin@bergzeit.example", "Cinco consejos para más batería",
              "<h1 style=\"font-size:24px;margin:0 0 12px\">Cinco consejos para más batería</h1>"
              "<p style=\"font-size:16px;line-height:1.5;color:#3a3a3c\">La batería dura más "
              "cuando no oscila todo el día entre el 0 y el 100 por ciento. Estas cinco reglas "
              "ayudan en el día a día, sin accesorios.</p>"
              "<ol style=\"font-size:16px;line-height:1.6\">"
              "<li>Carga entre el 20 y el 80 por ciento.</li>"
              "<li>Evita el calor al cargar.</li>"
              "<li>Desactiva la actualización en segundo plano.</li></ol>"
              "<p style=\"font-size:12px;color:#8e8e93\">Recibes este boletín porque te "
              "suscribiste a él.</p>"),
    "fr-FR": ("Magazine Bergzeit", "magazin@bergzeit.example", "Cinq conseils pour une batterie durable",
              "<h1 style=\"font-size:24px;margin:0 0 12px\">Cinq conseils pour une batterie durable</h1>"
              "<p style=\"font-size:16px;line-height:1.5;color:#3a3a3c\">Une batterie dure plus "
              "longtemps si elle n'oscille pas toute la journée entre 0 et 100 %. Ces cinq règles "
              "aident au quotidien, sans accessoire.</p>"
              "<ol style=\"font-size:16px;line-height:1.6\">"
              "<li>Chargez entre 20 et 80 %.</li>"
              "<li>Évitez la chaleur pendant la charge.</li>"
              "<li>Désactivez l'actualisation en arrière-plan.</li></ol>"
              "<p style=\"font-size:12px;color:#8e8e93\">Vous recevez cette lettre parce que "
              "vous y êtes abonné.</p>"),
    "ru": ("Журнал Bergzeit", "magazin@bergzeit.example", "Пять советов для долгой работы батареи",
           "<h1 style=\"font-size:24px;margin:0 0 12px\">Пять советов для долгой работы батареи</h1>"
           "<p style=\"font-size:16px;line-height:1.5;color:#3a3a3c\">Батарея служит дольше, "
           "если не метаться весь день между 0 и 100 процентами. Эти пять правил помогают "
           "в повседневной жизни — без аксессуаров.</p>"
           "<ol style=\"font-size:16px;line-height:1.6\">"
           "<li>Заряжайте от 20 до 80 процентов.</li>"
           "<li>Не допускайте нагрева при зарядке.</li>"
           "<li>Отключите фоновое обновление.</li></ol>"
           "<p style=\"font-size:12px;color:#8e8e93\">Вы получаете эту рассылку, потому что "
           "подписались на неё.</p>"),
    "tr": ("Bergzeit Dergisi", "magazin@bergzeit.example", "Daha uzun pil ömrü için beş ipucu",
           "<h1 style=\"font-size:24px;margin:0 0 12px\">Daha uzun pil ömrü için beş ipucu</h1>"
           "<p style=\"font-size:16px;line-height:1.5;color:#3a3a3c\">Pil, gün boyu yüzde 0 ile "
           "100 arasında gidip gelmediğinde daha uzun dayanır. Bu beş kural günlük hayatta "
           "yardımcı olur — aksesuar gerekmez.</p>"
           "<ol style=\"font-size:16px;line-height:1.6\">"
           "<li>Yüzde 20 ile 80 arasında şarj edin.</li>"
           "<li>Şarj sırasında ısınmadan kaçının.</li>"
           "<li>Arka plan yenilemeyi kapatın.</li></ol>"
           "<p style=\"font-size:12px;color:#8e8e93\">Bu bülteni abone olduğunuz için "
           "alıyorsunuz.</p>"),
}

# Eigene Ordner (Pro-Funktion). Die Namen gehören zur Sprache, damit die
# Ordnerliste im Screenshot nicht deutsch unter türkischer Oberfläche steht.
FOLDERS: dict[str, list[str]] = {
    "de-DE": ["Rechnungen", "Reisen"],
    "en-US": ["Invoices", "Travel"],
    "es-ES": ["Facturas", "Viajes"],
    "fr-FR": ["Factures", "Voyages"],
    "ru": ["Счета", "Поездки"],
    "tr": ["Faturalar", "Seyahat"],
}

# Alle je angelegten Demo-Ordner, damit vor dem Wechsel der Sprache die
# alten verschwinden und die Liste nicht mit sechs Varianten volläuft.
ALL_FOLDERS = sorted({name for names in FOLDERS.values() for name in names})


def load_env() -> dict[str, str]:
    values: dict[str, str] = {}
    for line in ENV_FILE.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip()
    return values


def imap_utf7(name: str) -> bytes:
    """Kodiert einen Ordnernamen als modified UTF-7 (RFC 3501, 5.1.3).

    `imaplib` verlangt ASCII; ohne diese Kodierung scheitern Ordnernamen mit
    Umlauten oder kyrillischen Buchstaben.
    """
    result: list[str] = []
    pending: list[str] = []

    def flush() -> None:
        if not pending:
            return
        encoded = base64.b64encode("".join(pending).encode("utf-16-be"))
        result.append("&" + encoded.decode("ascii").rstrip("=").replace("/", ",") + "-")
        pending.clear()

    for char in name:
        if 0x20 <= ord(char) <= 0x7E:
            flush()
            result.append("&-" if char == "&" else char)
        else:
            pending.append(char)
    flush()
    return "".join(result).encode("ascii")


def html_to_text(html: str) -> str:
    """Grober Klartext aus dem Newsletter-HTML für den Text-Teil.

    Ohne diesen Schritt landet rohes HTML im Text-Teil — und damit in der
    Vorschau der Nachrichtenliste, weil die App bewusst dem Text-Teil folgt.
    """
    text = re.sub(r"<li[^>]*>", "– ", html)
    text = re.sub(r"</(p|h[1-6]|li|ol|ul|div|br)>", "\n", text)
    text = re.sub(r"<[^>]+>", "", text)
    text = unescape(text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def build_message(sender: str, address: str, subject: str, body: str,
                  recipient: str, *, html: str | None = None) -> EmailMessage:
    message = EmailMessage()
    message["From"] = email.utils.formataddr((sender, address))
    message["To"] = recipient
    message["Subject"] = subject
    message["Date"] = email.utils.formatdate(localtime=True)
    message.set_content(body)
    if html is not None:
        page = ("<html><body style=\"margin:0;padding:18px;"
                "font-family:-apple-system,Helvetica,sans-serif;color:#1c1c1e\">"
                f"{html}</body></html>")
        message.add_alternative(page, subtype="html")
    return message


def main() -> int:
    language = sys.argv[1] if len(sys.argv) > 1 else "de-DE"
    if language not in DEMO:
        print(f"Unbekannte Sprache: {language}. Erlaubt: {', '.join(DEMO)}", file=sys.stderr)
        return 2

    config = load_env()
    user = config["IMAP_USER"]
    password = config["IMAP_PASSWORD"]
    host = config.get("IMAP_HOST", "imap.gmail.com")
    port = int(config.get("IMAP_PORT", "993"))

    server = imaplib.IMAP4_SSL(host, port)
    server.login(user, password)
    server.select("INBOX")

    status, data = server.search(None, "ALL")
    ids = data[0].split() if status == "OK" else []
    if ids:
        server.store(b",".join(ids).decode(), "+FLAGS", "\\Deleted")
        server.expunge()

    for sender, address, subject, body, seen in DEMO[language]:
        message = build_message(sender, address, subject, body, user)
        flags = "(\\Seen)" if seen else ""
        server.append("INBOX", flags, imaplib.Time2Internaldate(time.time()),
                      message.as_bytes())

    # Der Newsletter ist die neueste Nachricht und damit das Motiv für die
    # HTML-Ansicht im Screenshot.
    name, address, subject, html = NEWSLETTER[language]
    newsletter = build_message(name, address, subject, html_to_text(html), user, html=html)
    server.append("INBOX", "", imaplib.Time2Internaldate(time.time()),
                  newsletter.as_bytes())

    wanted = set(FOLDERS[language])
    for folder in ALL_FOLDERS:
        if folder in wanted:
            continue
        try:
            server.delete(imap_utf7(folder))
        except imaplib.IMAP4.error:
            pass  # Ordner existiert nicht (mehr)

    for folder in FOLDERS[language]:
        try:
            server.create(imap_utf7(folder))
        except imaplib.IMAP4.error:
            pass  # Ordner existiert bereits

    server.logout()
    print(f"{language}: Posteingang mit {len(DEMO[language]) + 1} Demo-Nachrichten gefüllt")
    return 0


if __name__ == "__main__":
    sys.exit(main())
