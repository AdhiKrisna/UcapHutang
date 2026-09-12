import SwiftUI

struct SmartContactCardView: View {
    let name: String
    let state: ContactCardState
    let showsRequiredMarker: Bool
    let onLink: () -> Void
    let onConfirmSuggestion: () -> Void
    let onChooseOther: () -> Void
    let onChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch state {
            case .unlinked:
                HStack(alignment: .center, spacing: 12) {
                    labels(title: displayName, subtitle: "Belum terhubung")
                    Spacer(minLength: 8)
                    cardButton("Hubungkan", accessibilityLabel: "Hubungkan \(displayName) ke kontak", action: onLink)
                }

            case .suggestion(let contact):
                labels(title: displayName, subtitle: "Mirip kontak “\(contact.displayName)”")
                HStack(spacing: 8) {
                    cardButton("Ya, hubungkan", accessibilityLabel: "Hubungkan ke \(contact.displayName)", action: onConfirmSuggestion)
                    cardButton("Bukan, pilih lain", accessibilityLabel: "Pilih kontak lain untuk \(displayName)", action: onChooseOther)
                }

            case .linked(let contact):
                HStack(alignment: .center, spacing: 12) {
                    labels(title: contact.displayName, subtitle: "Terhubung ke kontak")
                    Spacer(minLength: 8)
                    cardButton("Ganti", accessibilityLabel: "Ganti kontak \(contact.displayName)", action: onChange)
                }
            }

            if showsRequiredMarker {
                Label("Wajib dihubungkan", systemImage: "exclamationmark.circle")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.orange)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 12))
    }

    private var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Belum ada nama" : trimmed
    }

    private func labels(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private func cardButton(_ title: String, accessibilityLabel: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(minHeight: 44)
        }
        .buttonStyle(.bordered)
        .tint(.primary)
        .accessibilityLabel(accessibilityLabel)
    }
}

#Preview("3 States") {
    VStack(spacing: 16) {
        SmartContactCardView(name: "Dito", state: .unlinked, showsRequiredMarker: true, onLink: {}, onConfirmSuggestion: {}, onChooseOther: {}, onChange: {})
        SmartContactCardView(
            name: "Dito",
            state: .suggestion(ContactRef(identifier: "1", displayName: "Andito Rizkika", phoneNumber: nil)),
            showsRequiredMarker: false,
            onLink: {}, onConfirmSuggestion: {}, onChooseOther: {}, onChange: {}
        )
        SmartContactCardView(
            name: "Andito Rizkika",
            state: .linked(ContactRef(identifier: "1", displayName: "Andito Rizkika", phoneNumber: nil)),
            showsRequiredMarker: false,
            onLink: {}, onConfirmSuggestion: {}, onChooseOther: {}, onChange: {}
        )
    }
    .padding()
}
