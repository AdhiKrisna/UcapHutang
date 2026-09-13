import SwiftUI

struct ReviewCardView: View {
    let item: ReviewItemUIModel

    @ScaledMetric(relativeTo: .caption) private var avatarSize: CGFloat = 20

    init(item: ReviewItemUIModel) {
        self.item = item
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small + 2) {
            // Baris 1: Tipe (berwarna + ikon) & Waktu Relatif
            HStack(alignment: .firstTextBaseline) {
                typeBadge

                Spacer(minLength: 8)

                Text(item.relativeTime)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }

            // Baris 2: Subjek / Nama Orang (Lebar Penuh)
            HStack(alignment: .center, spacing: 8) {
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
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            // Baris 3: Deskripsi & Nominal (Nominal di kanan bawah yang menonjol)
            HStack(alignment: .bottom, spacing: 12) {
                Group {
                    if item.description.isEmpty {
                        Text("Tidak ada deskripsi")
                            .foregroundStyle(.tertiary)
                            .italic()
                    } else {
                        Text(item.description)
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.subheadline)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(item.amount.rupiahFormatted)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.trailing)
                    .layoutPriority(1)
            }
        }
        .padding(.horizontal, AppSpacing.large)
        .padding(.vertical, AppSpacing.medium + 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
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
            return AppColors.split
        }
    }

    private var typeBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: typeIcon)
                .font(.caption.weight(.bold))
                .accessibilityHidden(true)
            Text(typeLabel)
                .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(typeColor)
        .padding(.horizontal, AppSpacing.small)
        .padding(.vertical, 4)
        .background(typeColor.opacity(0.14), in: Capsule())
    }

    private var stackedAvatarsView: some View {
        HStack(spacing: -6) {
            ForEach(Array(item.avatarInitials.enumerated()), id: \.offset) { index, initial in
                Circle()
                    .fill(typeColor.opacity(0.16))
                    .frame(width: avatarSize, height: avatarSize)
                    .overlay(
                        Text(initial)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(typeColor)
                    )
                    .overlay(
                        Circle()
                            .stroke(AppColors.surface, lineWidth: 1.5)
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
