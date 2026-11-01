// ComposeViewModel.swift
import SwiftUI
import Combine

@MainActor
final class ComposeViewModel: ObservableObject {
    @Published var draft         = EmailDraft()
    @Published var isLoading     = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var isSent        = false

    private let account: EmailAccount
    private let smtpManager: SMTPManager
    var onSent: ((EmailDraft) -> Void)?   // Callback → MailStore.saveSentMessage

    init(account: EmailAccount) {
        self.account     = account
        self.smtpManager = SMTPManager(account: account)
    }

    func prepareReply(to message: EmailMessage) {
        draft.toText  = message.from.formatted
        draft.subject = message.subject.hasPrefix("Re:") ? message.subject : "Re: \(message.subject)"
        draft.body    = "\n\n---\nAm \(message.date.formatted()) schrieb \(message.from.formatted):\n\(message.body)"
    }

    func sendDraft() {
        guard !draft.to.isEmpty else { errorMessage = "Bitte mindestens einen Empfänger angeben."; return }
        guard !draft.subject.isEmpty else { errorMessage = "Bitte einen Betreff angeben."; return }

        isLoading    = true
        errorMessage = nil

        Task {
            do {
                try await smtpManager.sendEmail(draft: draft)
                let sentDraft = draft
                isLoading      = false
                successMessage = "E-Mail erfolgreich versendet!"
                isSent         = true
                onSent?(sentDraft)   // → in Gesendet speichern
                draft          = EmailDraft()
            } catch {
                isLoading    = false
                errorMessage = error.localizedDescription
            }
        }
    }

    func saveDraft() {
        draft.lastModified = Date()
        successMessage = "Entwurf gespeichert"
    }
}
