// MessageRowView.swift
import SwiftUI

struct MessageRowView: View {
    let message: EmailMessage

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Ungelesen-Indikator
            Circle()
                .fill(message.isRead ? Color.clear : Color.accentColor)
                .frame(width: 10, height: 10)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(message.from.name ?? message.from.address)
                        .font(.subheadline.bold())
                        .foregroundStyle(message.isRead ? .secondary : .primary)
                        .lineLimit(1)

                    Spacer()

                    Text(message.date.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(message.subject)
                    .font(.subheadline)
                    .foregroundStyle(message.isRead ? .secondary : .primary)
                    .lineLimit(1)

                Text(message.body)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                // Badges
                HStack(spacing: 6) {
                    if message.mdnRequested {
                        Label("MDN", systemImage: "envelope.badge.clock")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }
                    if message.receiptReceived {
                        Label("Gelesen", systemImage: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                    if !message.attachments.isEmpty {
                        Label("\(message.attachments.count)", systemImage: "paperclip")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        // Stabiler Anker für die UI-Tests; die Beschriftung ist sprachabhängig.
        .accessibilityIdentifier("message.row")
    }
}
