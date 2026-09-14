import SwiftUI

struct PersonCardRow: View {
    let person: PersonLedgerSummary

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(person.displayName)
                    .font(.body.weight(.bold))
                    .foregroundStyle(.primary)

                Text("\(person.entryCount) Catatan")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !person.isLinked {
                    Label("Belum terhubung ke kontak", systemImage: "person.crop.circle.badge.exclamationmark")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                if person.balance == 0 {
                    Text("Lunas")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                } else {
                    // Direction is shown by the arrow (with a VoiceOver label), not by color alone.
                    Image(systemName: person.balance > 0 ? "arrow.down.left" : "arrow.up.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(person.balance > 0 ? AppColors.receivable : AppColors.debt)
                        .accessibilityLabel(person.balance > 0 ? "Piutang" : "Utang")

                    Text(abs(person.balance).rupiahFormatted)
                        .font(.body.weight(.bold))
                        .foregroundStyle(.primary)
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(AppColors.background, in: .rect(cornerRadius: AppRadius.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                .stroke(AppColors.border, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}
