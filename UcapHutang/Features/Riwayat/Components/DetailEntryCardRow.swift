import SwiftUI

struct DetailEntryCardRow: View {
    let entry: LedgerEntry

    var body: some View {
        HStack(spacing: 12) {
            // Icon Bubble
            ZStack {
                Circle()
                    .fill(bubbleColor.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: bubbleIcon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(bubbleColor)
            }

            // Title & Date
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(.body.weight(.bold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)

                Text(formatDate(entry.date))
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }

            Spacer()

            // Amount
            Text(abs(entry.balanceDelta).rupiahFormatted)
                .font(.body.weight(.bold))
                .foregroundStyle(bubbleColor)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(.separator), lineWidth: 1)
        )
    }

    private var isPayment: Bool {
        entry.kind == .payment
    }

    private var bubbleColor: Color {
        if isPayment {
            return Color.blue
        } else if entry.balanceDelta >= 0 {
            return Color.green
        } else {
            return Color.red
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

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "id_ID")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: date)
    }
}
