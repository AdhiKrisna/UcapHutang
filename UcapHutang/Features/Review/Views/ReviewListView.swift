import SwiftUI

struct ReviewListView: View {
    @State private var viewModel: ReviewListViewModel
    let onSelect: (UUID) -> Void

    init(repository: any TransactionRepository, onSelect: @escaping (UUID) -> Void) {
        _viewModel = State(initialValue: ReviewListViewModel(repository: repository))
        self.onSelect = onSelect
    }

    var body: some View {
        NavigationStack {
            FilteredCardListView(
                title: "Catatan hasil rekaman perlu dicek sebelum masuk buku",
                items: viewModel.filteredDrafts,
                selectedFilter: viewModel.selectedFilter,
                onSelectFilter: { viewModel.selectFilter($0) },
                onSelectItem: { onSelect($0) },
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
            .navigationBarTitleDisplayMode(.inline)
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
        ])
    ) { _ in }
}
