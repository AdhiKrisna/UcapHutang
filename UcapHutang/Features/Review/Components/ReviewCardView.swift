import SwiftUI

struct ReviewCardView: View {
    let item: ReviewItemUIModel

    @ScaledMetric(relativeTo: .caption) private var avatarSize: CGFloat = 20

    init(item: ReviewItemUIModel) {
        self.item = item
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Baris 1: Tipe & Waktu Relatif
            HStack(alignment: .firstTextBaseline) {
                Text(typeLabel)
                    .font(.body)
                    .foregroundStyle(.primary)

                Spacer(minLength: 8)

                Text(item.relativeTime)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }

            // Baris 2: Subjek & Nominal
            HStack(alignment: .center, spacing: 6) {
                if !item.avatarInitials.isEmpty {
                    stackedAvatarsView
                        .accessibilityHidden(true)
                }

                if !item.prefix.isEmpty {
                    Text(item.prefix)
                        .font(.body)
                        .foregroundStyle(.primary)
                }

                Text(item.personName)
                    .font(.body.weight(.bold))
                    .foregroundStyle(.primary)

                Spacer(minLength: 8)

                Text(item.amount.rupiahFormatted)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.primary)
            }

            // Baris 3: Deskripsi / Quotes
            Text(item.description)
                .font(.body)
                .foregroundStyle(.primary)
                .lineLimit(3)
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
        .accessibilityElement(children: .combine)
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
                    .frame(width: avatarSize, height: avatarSize)
                    .overlay(
                        Text(initial)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Color(.label))
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
