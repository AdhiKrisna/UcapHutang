import SwiftUI

struct ReviewCardView: View {
    let item: ReviewItemUIModel

    @ScaledMetric(relativeTo: .caption) private var avatarSize: CGFloat = 20

    init(item: ReviewItemUIModel) {
        self.item = item
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Baris 1: Badge Tipe & Waktu Relatif + Chevron
            HStack(alignment: .center) {
                typeBadge

                Spacer(minLength: 8)

                HStack(spacing: 4) {
                    Text(formatCardDate(item.relativeTime))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
            }

            // Baris 2: Subjek (ke Arif / ke 3 Orang) & Nominal (Rp. 15.000)
            HStack(alignment: .center, spacing: 6) {
                if !item.avatarInitials.isEmpty {
                    stackedAvatarsView
                        .accessibilityHidden(true)
                }

                if !item.prefix.isEmpty {
                    Text(item.prefix)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                Text(item.personName)
                    .font(.body.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 8)

                Text(formatRupiahWithDot(item.amount))
                    .font(.body.weight(.bold))
                    .foregroundStyle(.primary)
            }

            // Baris 3: Deskripsi
            if !item.description.isEmpty {
                Text(item.description)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, AppSpacing.large)
        .padding(.vertical, AppSpacing.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.background)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                .stroke(AppColors.border, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
        .accessibilityElement(children: .combine)
    }

    private var typeLabel: String {
        switch item.type {
        case .piutang:
            return "Piutang"
        case .hutang, .unknown:
            return "Utang"
        case .splitBill:
            return "Splitbill"
        }
    }

    /// Direction is never carried by color alone: an icon and this text always accompany `typeColor`.
    private var typeIcon: String {
        switch item.type {
        case .piutang:
            return "arrow.down.left"
        case .hutang, .unknown:
            return "arrow.up.right"
        case .splitBill:
            return "person.3.fill"
        }
    }

    private var typeColor: Color {
        switch item.type {
        case .piutang:
            return AppColors.receivable
        case .hutang, .unknown:
            return AppColors.debt
        case .splitBill:
            return AppColors.accent
        }
    }

    private var typeBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: typeIcon)
                .font(.caption2.weight(.bold))
                .accessibilityHidden(true)
            Text(typeLabel)
                .font(.caption.weight(.bold))
        }
        .foregroundStyle(typeColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(typeColor.opacity(0.18), in: Capsule())
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
                            .foregroundStyle(AppColors.textPrimary)
                    )
                    .overlay(
                        Circle()
                            .stroke(AppColors.background, lineWidth: 1.5)
                    )
                    .zIndex(Double(item.avatarInitials.count - index))
            }
        }
        .padding(.trailing, 2)
    }

    private func formatCardDate(_ timeString: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "id_ID")
        formatter.dateFormat = "EEEE, d MMM HH:mm"
        return formatter.string(from: item.date)
    }

    private func formatRupiahWithDot(_ amount: Int64) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        let formatted = formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
        return "Rp. \(formatted)"
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
