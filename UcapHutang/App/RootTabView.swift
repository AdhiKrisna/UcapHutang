import SwiftUI

struct IdentifiableUUID: Identifiable, Equatable {
    let id: UUID
    init(_ id: UUID) { self.id = id }
}

struct RootTabView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(WidgetPrompt.hasAskedKey) private var hasAskedAboutCatatWidget = false
    @State private var pendingReviewCount = 0
    @State private var isShowingSettings = false
    @State private var isShowingNotificationPrimer = false
    @State private var isShowingWidgetPrompt = false
    @State private var isShowingWidgetInstructions = false

    var body: some View {
        @Bindable var router = container.router

        TabView(selection: $router.selectedTab) {
            Tab("Review", systemImage: "doc.badge.clock", value: AppTab.review) {
                ReviewListView(
                    router: container.router,
                    repository: container.repository,
                    contacts: container.contacts,
                    onOpenSettings: { isShowingSettings = true }
                )
            }
            .badge(pendingReviewCount)

            Tab("Catat", systemImage: "mic.fill", value: AppTab.capture) {
                CatatFlowChooserView(router: container.router, container: container)
            }

            Tab("Riwayat", systemImage: "book.closed", value: AppTab.ledger) {
                LedgerListView(repository: container.repository, contacts: container.contacts)
            }
        }
        .sensoryFeedback(.success, trigger: container.router.savedBannerID) { _, newValue in
            newValue != nil
        }
        .task {
            await refreshPendingReviewCount()
            isShowingNotificationPrimer = await NotificationPrimerViewModel.shouldShow(
                scheduler: container.reminderScheduler,
                settingsStore: container.reminderSettings
            )
            presentWidgetPromptIfNeeded()
            await container.reminderScheduler.sync()
        }
        .onReceive(NotificationCenter.default.publisher(for: .transactionRepositoryDidChange)) { _ in
            Task {
                await refreshPendingReviewCount()
                await container.reminderScheduler.sync()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await container.reminderScheduler.sync() }
            }
        }
        .onOpenURL { url in
            guard let link = AppDeepLink(url: url) else { return }
            // Close anything covering the tabs so the Catat chooser is actually visible.
            isShowingSettings = false
            container.router.open(link)
        }
        .sheet(isPresented: $isShowingSettings) {
            PengaturanView(scheduler: container.reminderScheduler, settingsStore: container.reminderSettings)
        }
        .sheet(isPresented: $isShowingWidgetInstructions) {
            WidgetSetupInstructionsView()
        }
        .fullScreenCover(isPresented: $isShowingNotificationPrimer, onDismiss: presentWidgetPromptIfNeeded) {
            NotificationPrimerView(scheduler: container.reminderScheduler, settingsStore: container.reminderSettings)
        }
        .alert("Catat lebih cepat dengan Widget?", isPresented: $isShowingWidgetPrompt) {
            Button("Ya, Mau") {
                hasAskedAboutCatatWidget = true
                isShowingWidgetInstructions = true
            }
            Button("Nanti Saja", role: .cancel) {
                hasAskedAboutCatatWidget = true
            }
        } message: {
            Text("Apakah kamu mau memakai widget untuk mencatat utang, piutang, atau Split Bill secara instan dari Home Screen?")
        }
    }

    private func refreshPendingReviewCount() async {
        pendingReviewCount = (try? await container.repository.pendingDraftCount()) ?? 0
    }

    /// Called at launch and again when the notification primer closes.
    private func presentWidgetPromptIfNeeded() {
        isShowingWidgetPrompt = WidgetPrompt.shouldPresent(
            hasAsked: hasAskedAboutCatatWidget,
            isShowingNotificationPrimer: isShowingNotificationPrimer
        )
    }
}
