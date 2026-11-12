// ComposeViewModel.swift
import SwiftUI
import Combine

@MainActor
final class ComposeViewModel: ObservableObject {
    @Published var draft: EmailDraft
    @Published var isLoading     = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var isSent        = false

    private let account: EmailAccount
    private let smtpManager: SMTPManager
    private let defaults: UserDefaults
    var onSent: ((EmailDraft) -> Void)?   // Callback → MailStore.saveSentMessage

    init(account: EmailAccount, defaults: UserDefaults = .standard) {
        self.account     = account
        self.smtpManager = SMTPManager(account: account)
        self.defaults    = defaults
        self.draft       = Self.makeDraft(defaults: defaults)
    }

    /// Neuer Entwurf mit den Voreinstellungen aus den Einstellungen.
    /// Gilt beim Öffnen und nach dem Senden — sonst würde der Schalter
    /// „Lesebestätigung standardmäßig anfordern" nur beim ersten Mal wirken.
    static func makeDraft(defaults: UserDefaults = .standard) -> EmailDraft {
        var draft = EmailDraft()
        draft.requestMDN = defaults.bool(
            forKey: AppConstants.UserDefaultsKeys.defaultRequestMDN
        )
        return draft
    }

    func prepareReply(to message: EmailMessage) {
        draft.toText  = message.from.formatted
        draft.subject = message.subject.hasPrefix("Re:") ? message.subject : "Re: \(message.subject)"
        let quoteHeader = String(
            format: String(localized: "compose.reply.quote",
                           defaultValue: "Am %1$@ schrieb %2$@:"),
            message.date.formatted(),
            message.from.formatted
        )
        draft.body    = "\n\n---\n\(quoteHeader)\n\(message.body)"
    }

    func sendDraft() {
        guard !draft.to.isEmpty else {
            errorMessage = String(localized: "compose.error.recipient",
                                 defaultValue: "Bitte mindestens einen Empfänger angeben.")
            return
        }
        guard !draft.subject.isEmpty else {
            errorMessage = String(localized: "compose.error.subject",
                                 defaultValue: "Bitte einen Betreff angeben.")
            return
        }

        isLoading    = true
        errorMessage = nil

        Task {
            do {
                try await smtpManager.sendEmail(draft: draft)
                let sentDraft = draft
                isLoading      = false
                successMessage = String(localized: "compose.success.sent",
                                        defaultValue: "E-Mail erfolgreich versendet!")
                isSent         = true
                onSent?(sentDraft)   // → in Gesendet speichern
                draft          = Self.makeDraft(defaults: defaults)
            } catch {
                isLoading    = false
                errorMessage = error.localizedDescription
            }
        }
    }

    func saveDraft() {
        draft.lastModified = Date()
        successMessage = String(localized: "compose.success.draft",
                                defaultValue: "Entwurf gespeichert")
    }
}
