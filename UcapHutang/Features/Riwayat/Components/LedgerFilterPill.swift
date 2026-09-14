import SwiftUI

struct LedgerFilterPill: View {
    let filter: LedgerFilter
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        FilterPillLabel(title: filter.rawValue, dotColor: dotColor, isSelected: isSelected, action: action)
    }

    private var dotColor: Color? {
        switch filter {
        case .all: return nil
        case .receivable: return AppColors.receivable
        case .debt: return AppColors.debt
        }
    }
}

struct DetailFilterPill: View {
    let filter: DetailFilter
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        FilterPillLabel(title: filter.rawValue, dotColor: dotColor, isSelected: isSelected, action: action)
    }

    private var dotColor: Color? {
        switch filter {
        case .all: return nil
        case .piutang: return AppColors.receivable
        case .utang: return AppColors.debt
        case .bayar: return AppColors.accent
        }
    }
}

private struct FilterPillLabel: View {
    let title: String
    let dotColor: Color?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: 6) {
                if let dotColor {
                    Circle()
                        .fill(dotColor)
                        .frame(width: 8, height: 8)
                        .accessibilityHidden(true)
                }

                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(isSelected ? AppColors.surface : Color.clear, in: .rect(cornerRadius: AppRadius.small, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                    .stroke(AppColors.border, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
