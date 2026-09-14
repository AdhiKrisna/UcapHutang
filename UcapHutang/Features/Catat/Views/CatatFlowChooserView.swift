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
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.large) {
                    Text("Pilih jenis pencatatan")
                        .font(.largeTitle.weight(.semibold))
                        .padding(.top, AppSpacing.small)

                    ForEach(CaptureFlow.allCases) { flow in
                        Button {
                            selectedFlow = flow
                        } label: {
                            FlowTile(flow: flow)
                        }
                        .buttonStyle(.plain)
                        .disabled(readiness != .ready)
                    }
                }
                .padding(AppSpacing.xLarge)
            }
            .navigationDestination(item: $selectedFlow) { flow in
                CatatView(flow: flow, container: container)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
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

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.medium) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(flow.accentColor.opacity(0.16))
                Image(systemName: flow.icon)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(flow.accentColor)
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(flow.title)
                    .font(.headline)
                    .foregroundStyle(AppColors.textPrimary)
                Text("“\(flow.exampleUcapan)”")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .italic()
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(AppSpacing.large)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .background(
            LinearGradient(
                colors: [flow.accentColor.opacity(0.10), flow.accentColor.opacity(0.02)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                .stroke(flow.accentColor.opacity(0.18), lineWidth: 1)
        )
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
