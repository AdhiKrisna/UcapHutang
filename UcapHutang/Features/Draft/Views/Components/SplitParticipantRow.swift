import SwiftUI

struct SplitParticipantRow: View {
    let contact: SelectedContactUIModel
    var onEditAmount: ((Int64) -> Void)?

    @State private var isEditing: Bool = false
    @State private var inputAmountText: String = ""

    init(contact: SelectedContactUIModel, onEditAmount: ((Int64) -> Void)? = nil) {
        self.contact = contact
        self.onEditAmount = onEditAmount
    }

    public var body: some View {
        HStack {
            Text(contact.name)
                .font(.body.weight(.medium))
                .foregroundStyle(AppColors.textPrimary)

            Spacer()

            if isEditing {
                HStack(spacing: 4) {
                    Text("Rp")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)

                    TextField("0", text: $inputAmountText)
                        .keyboardType(.numberPad)
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)

                    Button("OK") {
                        if let parsed = Int64(inputAmountText.filter(\.isNumber)) {
                            onEditAmount?(parsed)
                        }
                        isEditing = false
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColors.accent)
                }
            } else {
                Button {
                    inputAmountText = "\(contact.amount)"
                    isEditing = true
                } label: {
                    HStack(spacing: 4) {
                        Text(contact.amount.rupiahFormatted)
                            .font(.body.weight(.medium))
                            .foregroundStyle(AppColors.textPrimary)

                        Image(systemName: "pencil")
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}
