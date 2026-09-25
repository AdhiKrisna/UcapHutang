import SwiftUI

enum AppColors {
    static let background = Color(.systemBackground)
    static let surface = Color(.secondarySystemBackground)
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let accent = Color.blue
    static let debt = Color.red
    static let receivable = Color.green
    static let split = Color.orange
    static let warning = Color.orange
    static let destructive = Color.red
    static let border = Color.secondary.opacity(0.22)
    /// Asset color: Light #FFF5E0, Dark #3A3222.
    static let reminderButtonBackground = Color("ReminderButtonBackground")
}

enum AppSpacing {
    static let xSmall: CGFloat = 4
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
    static let xLarge: CGFloat = 24
    static let xxLarge: CGFloat = 32
}

enum AppRadius {
    static let small: CGFloat = 10
    static let medium: CGFloat = 16
    static let large: CGFloat = 24
}

struct AppSectionCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(AppSpacing.large)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
    }
}

struct AppEmptyState: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        ContentUnavailableView(title, systemImage: icon, description: Text(message))
    }
}

struct AppStoreNavigationTitle: ToolbarContent {
    let title: String

    var body: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Text(title)
                .font(.title2.weight(.bold))
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .accessibilityAddTraits(.isHeader)
        }
    }
}

struct AppFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isSelected ? AppColors.textPrimary : AppColors.textSecondary)
            .padding(.horizontal, AppSpacing.large)
            .frame(minHeight: 44)
            .background(isSelected ? AppColors.surface : Color.clear)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(AppColors.border))
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
