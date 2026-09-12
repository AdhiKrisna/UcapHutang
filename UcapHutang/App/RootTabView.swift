import SwiftUI
import Combine

struct IdentifiableUUID: Identifiable, Equatable {
    let id: UUID
    init(_ id: UUID) { self.id = id }
}

enum AppTab: Hashable {
    case draft
    case capture
    case ledger
}

struct RootTabView: View {
    @EnvironmentObject private var container: AppContainer
    @State private var selectedTab: AppTab = .draft
    @State private var reviewDraftItem: IdentifiableUUID?
    @State private var selectedCaptureFlow: CaptureFlow?

    var body: some View {
        TabView(selection: $selectedTab) {
            DraftListView(repository: container.repository) { draftID in
                reviewDraftItem = IdentifiableUUID(draftID)
            }
            .tabItem {
                Label("Draft", systemImage: "exclamationmark.triangle")
            }
            .tag(AppTab.draft)

            CatatFlowChooserView { flow in
                selectedCaptureFlow = flow
            }
            .tabItem {
                Label("Catat", systemImage: "mic.fill")
            }
            .tag(AppTab.capture)

            LedgerListView(repository: container.repository)
                .tabItem {
                    Label("Riwayat", systemImage: "book.closed")
                }
                .tag(AppTab.ledger)
        }
        .sheet(item: $reviewDraftItem) { item in
            NavigationStack {
                ReviewDraftView(draftID: item.id, repository: container.repository)
            }
        }
        .sheet(item: $selectedCaptureFlow) { flow in
            CatatView(flow: flow, container: container)
        }
    }
}
