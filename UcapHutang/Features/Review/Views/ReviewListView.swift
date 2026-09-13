import SwiftUI

struct ReviewListView: View {
    @State private var viewModel: ReviewListViewModel
    @State private var selectedDraftID: UUID?
    private let repository: any TransactionRepository
    private let contacts: any ContactsProviding
    let onOpenSettings: () -> Void

    init(
        repository: any TransactionRepository,
        contacts: any ContactsProviding,
        onOpenSettings: @escaping () -> Void
    ) {
        self.repository = repository
        self.contacts = contacts
        self.onOpenSettings = onOpenSettings
        _viewModel = State(initialValue: ReviewListViewModel(repository: repository))
    }

    var body: some View {
        NavigationStack {
            FilteredCardListView(
                title: "Catatan hasil rekaman perlu dicek sebelum masuk buku",
                items: viewModel.filteredDrafts,
                selectedFilter: viewModel.selectedFilter,
                onSelectFilter: { viewModel.selectFilter($0) },
                onSelectItem: { id in selectedDraftID = id },
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: onOpenSettings) {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Pengaturan")
                }
            }
            .task { await viewModel.loadDrafts() }
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
}

#Preview {
    ReviewListView(
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
