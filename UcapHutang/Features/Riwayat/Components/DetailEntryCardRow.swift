import SwiftUI

struct DetailEntryCardRow: View {
    let entry: LedgerEntry

    @ScaledMetric(relativeTo: .body) private var bubbleSize: CGFloat = 40

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(bubbleColor.opacity(0.15))
                    .frame(width: bubbleSize, height: bubbleSize)

                Image(systemName: bubbleIcon)
                    .font(.body.weight(.bold))
                    .foregroundStyle(bubbleColor)
            }
            .accessibilityElement()
            .accessibilityLabel(kindLabel)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(.body.weight(.bold))
                    .foregroundStyle(.primary)

                Text(formatDate(entry.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Text(abs(entry.balanceDelta).rupiahFormatted)
                .font(.body.weight(.bold))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground), in: .rect(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(.separator), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    private var isPayment: Bool {
        entry.kind == .payment
    }

    private var bubbleColor: Color {
        if isPayment {
            return AppColors.accent
        } else if entry.balanceDelta >= 0 {
            return AppColors.receivable
        } else {
            return AppColors.debt
        }
    }

    private var bubbleIcon: String {
        if isPayment {
            return "creditcard.fill"
        } else if entry.balanceDelta >= 0 {
            return "arrow.down.left"
        } else {
            return "arrow.up.right"
        }
    }

    private var kindLabel: String {
        if isPayment {
            return "Bayar"
        } else if entry.balanceDelta >= 0 {
            return "Piutang"
        } else {
            return "Utang"
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "id_ID")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: date)
    }
}
