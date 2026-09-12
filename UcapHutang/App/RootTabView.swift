import SwiftUI

struct IdentifiableUUID: Identifiable, Equatable {
    let id: UUID
    init(_ id: UUID) { self.id = id }
}

struct RootTabView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.scenePhase) private var scenePhase
    @State private var reviewDraftItem: IdentifiableUUID?
    @State private var selectedCaptureFlow: CaptureFlow?
    @State private var pendingReviewCount = 0
    @State private var isShowingSettings = false
    @State private var isShowingNotificationPrimer = false

    var body: some View {
        @Bindable var router = container.router

        TabView(selection: $router.selectedTab) {
            Tab("Review", systemImage: "doc.badge.clock", value: AppTab.review) {
                ReviewListView(
                    repository: container.repository,
                    onSelect: { draftID in reviewDraftItem = IdentifiableUUID(draftID) },
                    onOpenSettings: { isShowingSettings = true }
                )
            }
            .badge(pendingReviewCount)

            Tab("Catat", systemImage: "mic.fill", value: AppTab.capture) {
                CatatFlowChooserView(router: container.router) { flow in
                    selectedCaptureFlow = flow
                }
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
        .sheet(item: $reviewDraftItem) { item in
            NavigationStack {
                ReviewDetailView(draftID: item.id, repository: container.repository, contacts: container.contacts)
            }
        }
        .sheet(item: $selectedCaptureFlow) { flow in
            CatatView(flow: flow, container: container)
        }
        .sheet(isPresented: $isShowingSettings) {
            PengaturanView(scheduler: container.reminderScheduler, settingsStore: container.reminderSettings)
        }
        .fullScreenCover(isPresented: $isShowingNotificationPrimer) {
            NotificationPrimerView(scheduler: container.reminderScheduler, settingsStore: container.reminderSettings)
        }
    }

    private func refreshPendingReviewCount() async {
        pendingReviewCount = (try? await container.repository.pendingDraftCount()) ?? 0
    }
}
