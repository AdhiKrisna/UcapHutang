import SwiftUI

struct CatatFlowChooserView: View {
    let router: AppRouter
    let container: AppContainer
    @State private var selectedFlow: CaptureFlow?
    private let readiness = MLXQwenClient.readiness()

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(router: AppRouter, container: AppContainer) {
        self.router = router
        self.container = container
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: AppSpacing.medium) {
                        ForEach(CaptureFlow.allCases) { flow in
                            Button {
                                selectedFlow = flow
                            } label: {
                                FlowTile(
                                    flow: flow,
                                    minimumHeight: max(190, (proxy.size.height - AppSpacing.medium - AppSpacing.xLarge * 2) / 2)
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(readiness != .ready)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .top)
                    .padding(.horizontal, AppSpacing.xLarge)
                    .padding(.vertical, AppSpacing.large)
                }
            }
            .navigationDestination(item: $selectedFlow) { flow in
                CatatView(flow: flow, container: container)
            }
            .navigationTitle("Pilih Alur Pencatatan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                AppStoreNavigationTitle(title: "Pilih Alur Pencatatan")
            }
            .safeAreaInset(edge: .top) {
                if let bannerID = router.savedBannerID {
                    SavedToReviewBanner(
                        bannerID: bannerID,
                        onOpen: { router.openReviewFromBanner() },
                        onTimeout: { router.dismissSavedBanner() }
                    )
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
            }
            .animation(reduceMotion ? nil : .default, value: router.savedBannerID)
        }
    }
}

/// One large tappable tile for a capture flow: icon, title, and a baked-in example
/// of how to phrase the recording. No readiness text is ever shown here — a disabled
/// tile (model not ready yet) looks and behaves like any other disabled control,
/// with no explanation. See §4 of the Catat UI/UX design spec.
private struct FlowTile: View {
    let flow: CaptureFlow
    let minimumHeight: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            HStack(alignment: .top) {
                Image(systemName: flow.icon)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(flow.accentColor)
                    .frame(width: 52, height: 52)
                    .background(flow.accentColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(flow.accentColor)
                    .frame(width: 34, height: 34)
                    .background(AppColors.background.opacity(0.75), in: Circle())
            }

            VStack(alignment: .leading, spacing: AppSpacing.small) {
                Text(flow.title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppColors.textPrimary)
                Text(flow.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 4) {
                Text("CONTOH")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(flow.accentColor)
                Text("“\(flow.exampleUcapan)”")
                    .font(.footnote)
                    .foregroundStyle(AppColors.textSecondary)
                    .italic()
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(AppSpacing.large)
        .frame(maxWidth: .infinity, minHeight: minimumHeight, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [flow.accentColor.opacity(0.20), flow.accentColor.opacity(0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                .stroke(flow.accentColor.opacity(0.38), lineWidth: 1.25)
        )
        .shadow(color: flow.accentColor.opacity(0.10), radius: 14, y: 7)
    }
}

#Preview("Catat Flow Chooser") {
    let repo = InMemoryTransactionRepository()
    let contacts = SystemContactsProvider()
    let extraction = QwenDraftExtractionService()
    let reminderSettings = UserDefaultsReminderSettingsStore()
    let scheduler = ReviewReminderScheduler(center: SystemNotificationCenterClient(), settingsStore: reminderSettings, repository: repo)
    let container = AppContainer(
        repository: repo,
        extraction: extraction,
        contacts: contacts,
        reminderSettings: reminderSettings,
        reminderScheduler: scheduler
    )
    CatatFlowChooserView(router: container.router, container: container)
}
