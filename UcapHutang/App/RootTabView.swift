import SwiftUI

struct IdentifiableUUID: Identifiable, Equatable {
    let id: UUID
    init(_ id: UUID) { self.id = id }
}

enum AppTab: Hashable {
    case review
    case capture
    case ledger
}

struct RootTabView: View {
    @Environment(AppContainer.self) private var container
    @State private var selectedTab: AppTab = .review
    @State private var reviewDraftItem: IdentifiableUUID?
    @State private var selectedCaptureFlow: CaptureFlow?

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Review", systemImage: "doc.badge.clock", value: AppTab.review) {
                ReviewListView(repository: container.repository) { draftID in
                    reviewDraftItem = IdentifiableUUID(draftID)
                }
            }

            Tab("Catat", systemImage: "mic.fill", value: AppTab.capture) {
                CatatFlowChooserView { flow in
                    selectedCaptureFlow = flow
                }
            }

            Tab("Riwayat", systemImage: "book.closed", value: AppTab.ledger) {
                LedgerListView(repository: container.repository)
            }
        }
        .sheet(item: $reviewDraftItem) { item in
            NavigationStack {
                ReviewDetailView(draftID: item.id, repository: container.repository)
            }
        }
        .sheet(item: $selectedCaptureFlow) { flow in
            CatatView(flow: flow, container: container)
        }
    }
}
