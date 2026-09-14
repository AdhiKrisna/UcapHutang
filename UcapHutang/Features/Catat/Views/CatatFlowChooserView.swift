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
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                Text("Pilih jenis pencatatan")
                    .font(.largeTitle.weight(.semibold))

                ForEach(CaptureFlow.allCases) { flow in
                    Button { selectedFlow = flow } label: {
                        HStack {
                            Image(systemName: flow == .personal ? "person.fill" : "person.3.fill")
                                .frame(width: 32)
                            Text(flow.title).font(.headline)
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .foregroundStyle(AppColors.textPrimary)
                        .padding(AppSpacing.large)
                        .frame(maxWidth: .infinity, minHeight: 64)
                        .background(AppColors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(readiness != .ready)
                }
                Spacer()
            }
            .padding()
            .navigationDestination(item: $selectedFlow) { flow in
                CatatView(flow: flow, container: container)
            }
            .navigationTitle("Catat")
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
