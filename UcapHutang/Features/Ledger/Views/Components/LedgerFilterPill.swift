import SwiftUI

struct LedgerFilterPill: View {
    let filter: LedgerFilter
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if filter == .receivable {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                } else if filter == .debt {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                }

                Text(filter.rawValue)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.primary)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 36)
            .background(isSelected ? Color(.systemGray5) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(.separator), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct DetailFilterPill: View {
    let filter: DetailFilter
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if filter == .piutang {
                    Circle().fill(Color.green).frame(width: 8, height: 8)
                } else if filter == .utang {
                    Circle().fill(Color.red).frame(width: 8, height: 8)
                } else if filter == .bayar {
                    Circle().fill(Color.blue).frame(width: 8, height: 8)
                }

                Text(filter.rawValue)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.primary)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 36)
            .background(isSelected ? Color(.systemGray5) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(.separator), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
