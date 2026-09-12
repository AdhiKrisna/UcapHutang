import SwiftUI
import Combine

enum DraftFilter: String, CaseIterable, Identifiable {
    case all = "Semua"
    case hutang = "Utang"
    case piutang = "Piutang"
    case splitBill = "Split"

    var id: String { rawValue }
}

@MainActor
final class DraftListViewModel: ObservableObject {
    @Published private(set) var drafts: [TransactionDraft] = []
    @Published var filter: DraftFilter = .all
    @Published var errorMessage: String?

    private let repository: any TransactionRepository

    init(repository: any TransactionRepository) { self.repository = repository }

    var filteredDrafts: [TransactionDraft] {
        drafts.filter { draft in
            switch filter {
            case .all: true
            case .hutang: draft.type == .hutang || draft.type == .unknown
            case .piutang: draft.type == .piutang
            case .splitBill: draft.type == .splitBill
            }
        }
    }

    func load() async {
        do { drafts = try await repository.draftsNeedingReview() }
        catch { errorMessage = error.localizedDescription }
    }
}

struct DraftListView: View {
    @StateObject private var viewModel: DraftListViewModel
    let onSelect: (UUID) -> Void

    init(repository: any TransactionRepository, onSelect: @escaping (UUID) -> Void) {
        _viewModel = StateObject(wrappedValue: DraftListViewModel(repository: repository))
        self.onSelect = onSelect
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                Text("Catatan hasil rekaman perlu dicek sebelum masuk buku")
                    .font(.largeTitle.weight(.semibold))
                    .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.small) {
                        ForEach(DraftFilter.allCases) { filter in
                            AppFilterChip(title: filter.rawValue, isSelected: viewModel.filter == filter) {
                                viewModel.filter = filter
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                if viewModel.filteredDrafts.isEmpty {
                    AppEmptyState(
                        icon: "checkmark.circle",
                        title: "Belum ada yang perlu ditinjau",
                        message: "Hasil pencatatan suara yang belum dikonfirmasi akan muncul di sini."
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(viewModel.filteredDrafts) { draft in
                        Button { onSelect(draft.id) } label: {
                            DraftRow(draft: draft)
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Draft")
            .navigationBarTitleDisplayMode(.inline)
            .task { await viewModel.load() }
            .refreshable { await viewModel.load() }
            .onReceive(NotificationCenter.default.publisher(for: .transactionRepositoryDidChange)) { _ in
                Task { await viewModel.load() }
            }
            .alert("Gagal Memuat Draft", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) { Button("OK", role: .cancel) {} } message: {
                Text(viewModel.errorMessage ?? "Terjadi kesalahan.")
            }
        }
    }
}

private struct DraftRow: View {
    let draft: TransactionDraft

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            HStack {
                Text(draft.type.title).font(.caption.weight(.bold))
                Spacer()
                Text(draft.createdAt, style: .relative).font(.caption).foregroundStyle(AppColors.textSecondary)
            }
            HStack {
                Text(draft.participants.map(\.name).joined(separator: ", ")).lineLimit(1)
                Spacer()
                Text(draft.totalAmount.rupiahFormatted).fontWeight(.bold)
            }
            Text(draft.title).font(.subheadline).foregroundStyle(AppColors.textSecondary)
        }
        .padding(.vertical, AppSpacing.small)
        .accessibilityElement(children: .combine)
    }
}
