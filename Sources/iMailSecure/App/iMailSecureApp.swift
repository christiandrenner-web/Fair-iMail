// iMailSecureApp.swift
// iMail Secure – Datenschutzfreundlicher E-Mail-Client für iOS 18+
// Lizenz: PolyForm Noncommercial 1.0.0 (source-available, nicht kommerziell)

import SwiftUI

@main
struct iMailSecureApp: App {
    @StateObject private var accountStore = AccountStore()
    @StateObject private var mailStore   = MailStore()

    /// Sichtschutz: true wenn App in den Hintergrund wechselt
    /// → verhindert dass Mail-Inhalte im App-Umschalter sichtbar sind
    @State private var isObscured = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(accountStore)
                .environmentObject(mailStore)
                .onAppear {
                    mailStore.loadAccounts(from: accountStore)
                }
                // Sichtschutz-Overlay
                .overlay(privacyOverlay)
                // Hintergrund → Inhalt verbergen
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: UIApplication.willResignActiveNotification)
                ) { _ in
                    withAnimation(.easeIn(duration: 0.15)) { isObscured = true }
                }
                // Vordergrund → Inhalt wieder zeigen
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: UIApplication.didBecomeActiveNotification)
                ) { _ in
                    withAnimation(.easeOut(duration: 0.15)) { isObscured = false }
                }
        }
    }

    // MARK: – Privacy Overlay

    @ViewBuilder
    private var privacyOverlay: some View {
        if isObscured {
            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("iMail Secure")
                        .font(.title2.bold())
                        .foregroundStyle(.secondary)
                }
            }
            .transition(.opacity)
        }
    }
}
