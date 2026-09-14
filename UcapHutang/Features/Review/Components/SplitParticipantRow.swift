import SwiftUI

/// Shows one friend's share. Editable only in custom split mode.
struct SplitParticipantRow: View {
    let amount: Int64
    let isEditable: Bool
    let onAmountChange: (Int64) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("Nominal bagian")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            if isEditable {
                TextField(
                    "Nominal bagian",
                    value: Binding(get: { amount }, set: { onAmountChange($0) }),
                    format: .number
                )
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .font(.body.weight(.semibold))
                .frame(minHeight: 44)
            } else {
                Text(amount.rupiahFormatted)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
            }
        }
        .accessibilityElement(children: isEditable ? .contain : .combine)
    }
}
