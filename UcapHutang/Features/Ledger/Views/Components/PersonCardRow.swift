import SwiftUI

struct PersonCardRow: View {
    let person: PersonLedgerSummary

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(person.displayName)
                    .font(.body.weight(.bold))
                    .foregroundStyle(Color.primary)

                Text("\(person.entryCount) Catatan")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }

            Spacer()

            HStack(spacing: 6) {
                if person.balance == 0 {
                    Text("Lunas")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.secondary)
                } else if person.balance > 0 {
                    Text(formatRupiah(person.balance))
                        .font(.body.weight(.bold))
                        .foregroundStyle(Color.green)
                } else {
                    Text(formatRupiah(abs(person.balance)))
                        .font(.body.weight(.bold))
                        .foregroundStyle(Color.red)
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.secondary.opacity(0.6))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.separator), lineWidth: 1)
        )
    }

    private func formatRupiah(_ amount: Int64) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        let numStr = formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
        return "Rp. \(numStr)"
    }
}
