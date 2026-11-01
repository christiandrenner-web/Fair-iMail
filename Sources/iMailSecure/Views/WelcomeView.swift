// WelcomeView.swift
import SwiftUI

struct WelcomeView: View {
    @Binding var showAccountSetup: Bool

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Logo
            Image(systemName: "envelope.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue)
                .symbolEffect(.pulse)

            VStack(spacing: 8) {
                Text("iMail secure")
                    .font(.largeTitle.bold())
                Text("Datenschutzfreundlicher E-Mail-Client")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Features
            VStack(alignment: .leading, spacing: 16) {
                featureRow("Kein Tracking, keine Werbung", icon: "hand.raised.fill", color: .green)
                featureRow("Lesebestätigungen (MDN/RFC 8098)", icon: "checkmark.seal.fill", color: .blue)
                featureRow("Passwörter im Keychain gespeichert", icon: "lock.fill", color: .orange)
                featureRow("Open Source (GPL-3.0)", icon: "chevron.left.forwardslash.chevron.right", color: .purple)
            }
            .padding(.horizontal)

            Spacer()

            Button {
                showAccountSetup = true
            } label: {
                Label("E-Mail-Konto hinzufügen", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
    }

    private func featureRow(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 28)
            Text(title)
                .font(.subheadline)
        }
    }
}
