import SwiftUI

struct ReviewCardView: View {
    let item: ReviewItemUIModel

    init(item: ReviewItemUIModel) {
        self.item = item
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Baris 1: Tipe & Waktu Relatif
            HStack {
                Text(typeLabel)
                    .font(.body.weight(.regular))
                    .foregroundStyle(Color.primary)

                Spacer()

                Text(item.relativeTime)
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
            }

            // Baris 2: Subjek & Nominal
            HStack(alignment: .center, spacing: 6) {
                if !item.avatarInitials.isEmpty {
                    stackedAvatarsView
                }

                if !item.prefix.isEmpty {
                    Text(item.prefix)
                        .font(.body)
                        .foregroundStyle(Color.primary)
                }

                Text(item.personName)
                    .font(.body.weight(.bold))
                    .foregroundStyle(Color.primary)

                Spacer()

                Text(item.amount.rupiahFormatted)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.primary)
            }

            // Baris 3: Deskripsi / Quotes
            Text(item.description)
                .font(.body)
                .foregroundStyle(Color.primary)
                .lineLimit(2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.separator), lineWidth: 1)
        )
    }

    private var typeLabel: String {
        switch item.type {
        case .piutang:
            return "Piutang"
        case .hutang, .unknown:
            return "Utang"
        case .splitBill:
            return "Split"
        }
    }

    private var stackedAvatarsView: some View {
        HStack(spacing: -6) {
            ForEach(Array(item.avatarInitials.enumerated()), id: \.offset) { index, initial in
                Circle()
                    .fill(Color(.systemGray4))
                    .frame(width: 20, height: 20)
                    .overlay(
                        Text(initial)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color(.systemGray))
                    )
                    .overlay(
                        Circle()
                            .stroke(Color(.systemBackground), lineWidth: 1.5)
                    )
                    .zIndex(Double(item.avatarInitials.count - index))
            }
        }
        .padding(.trailing, 2)
    }
}

#Preview {
    VStack(spacing: 12) {
        ReviewCardView(item: ReviewItemUIModel(
            type: .piutang,
            prefix: "ke",
            personName: "Dito",
            description: "“pinjam buat makan siang”",
            relativeTime: "5 menit yang lalu",
            amount: 15_000
        ))
        ReviewCardView(item: ReviewItemUIModel(
            type: .splitBill,
            prefix: "ke",
            personName: "3 Orang",
            avatarInitials: ["S", "A", "R"],
            description: "“makan malam”",
            relativeTime: "1 jam yang lalu",
            amount: 300_000
        ))
    }
    .padding()
}
