import SwiftUI

struct IdentifiableUUID: Identifiable, Equatable {
    let id: UUID
    init(_ id: UUID) { self.id = id }
}

struct RootTabView: View {
    @Environment(AppContainer.self) private var container
    @State private var reviewDraftItem: IdentifiableUUID?
    @State private var selectedCaptureFlow: CaptureFlow?
    @State private var pendingReviewCount = 0

    var body: some View {
        @Bindable var router = container.router

        TabView(selection: $router.selectedTab) {
            Tab("Review", systemImage: "doc.badge.clock", value: AppTab.review) {
                ReviewListView(repository: container.repository) { draftID in
                    reviewDraftItem = IdentifiableUUID(draftID)
                }
            }
            .badge(pendingReviewCount)

            Tab("Catat", systemImage: "mic.fill", value: AppTab.capture) {
                CatatFlowChooserView(router: container.router) { flow in
                    selectedCaptureFlow = flow
                }
            }

            Tab("Riwayat", systemImage: "book.closed", value: AppTab.ledger) {
                LedgerListView(repository: container.repository)
            }
        }
        .sensoryFeedback(.success, trigger: container.router.savedBannerID) { _, newValue in
            newValue != nil
        }
        .task { await refreshPendingReviewCount() }
        .onReceive(NotificationCenter.default.publisher(for: .transactionRepositoryDidChange)) { _ in
            Task { await refreshPendingReviewCount() }
        }
        .sheet(item: $reviewDraftItem) { item in
            NavigationStack {
                ReviewDetailView(draftID: item.id, repository: container.repository, contacts: container.contacts)
            }
        }
        .sheet(item: $selectedCaptureFlow) { flow in
            CatatView(flow: flow, container: container)
        }
    }

    private func refreshPendingReviewCount() async {
        pendingReviewCount = (try? await container.repository.pendingDraftCount()) ?? 0
    }
}
