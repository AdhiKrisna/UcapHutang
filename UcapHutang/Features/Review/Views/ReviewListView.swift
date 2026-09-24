import SwiftUI

struct ReviewListView: View {
    @State private var viewModel: ReviewListViewModel
    @State private var selectedDraftID: UUID?
    private let repository: any TransactionRepository
    private let contacts: any ContactsProviding
    private let router: AppRouter
    let onOpenSettings: () -> Void

    init(
        router: AppRouter,
        repository: any TransactionRepository,
        contacts: any ContactsProviding,
        onOpenSettings: @escaping () -> Void
    ) {
        self.router = router
        self.repository = repository
        self.contacts = contacts
        self.onOpenSettings = onOpenSettings
        _viewModel = State(initialValue: ReviewListViewModel(repository: repository))
    }

    var body: some View {
        NavigationStack {
            FilteredCardListView(
                title: "",
                subtitle: nil,
                showsHeader: false,
                items: viewModel.filteredDrafts,
                selectedFilter: viewModel.selectedFilter,
                onSelectFilter: { viewModel.selectFilter($0) },
                onSelectItem: { id in selectedDraftID = id },
                onDeleteItem: { id in
                    Task { await viewModel.deleteDraft(id: id) }
                },
                emptyState: {
                    AppEmptyState(
                        icon: "checkmark.circle",
                        title: "Belum ada yang perlu ditinjau",
                        message: "Hasil pencatatan suara yang belum dikonfirmasi akan muncul di sini."
                    )
                },
                cardContent: { item in
                    ReviewCardView(item: item)
                }
            )
            .navigationDestination(item: $selectedDraftID) { draftID in
                ReviewDetailView(draftID: draftID, repository: repository, contacts: contacts)
            }
            .navigationTitle("Review Draft")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                AppStoreNavigationTitle(title: "Review Draft")
                ToolbarItem(placement: .primaryAction) {
                    Button(action: onOpenSettings) {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Pengaturan")
                }
            }
            .task { await viewModel.loadDrafts() }
            .onAppear { openPendingDraftIfNeeded() }
            .onChange(of: router.pendingReviewDraftID) { _, _ in
                openPendingDraftIfNeeded()
            }
            .refreshable { await viewModel.loadDrafts() }
            .onReceive(NotificationCenter.default.publisher(for: .transactionRepositoryDidChange)) { _ in
                Task { await viewModel.loadDrafts() }
            }
            .alert("Gagal Memuat Draft", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "Terjadi kesalahan.")
            }
        }
    }

    private func openPendingDraftIfNeeded() {
        if let draftID = router.consumePendingReviewDraft() {
            selectedDraftID = draftID
        }
    }
}

#Preview {
    ReviewListView(
        router: AppRouter(),
        repository: InMemoryTransactionRepository(seedDrafts: [
            TransactionDraft(
                flow: .personal,
                type: .piutang,
                title: "Makan siang",
                totalAmount: 15_000,
                participants: [TransactionParticipant(name: "Dito", shareAmount: 15_000)],
                rawTranscript: "Dito pinjam 15 ribu buat makan siang"
            )
        ]),
        contacts: SystemContactsProvider(),
        onOpenSettings: {}
    )
}
