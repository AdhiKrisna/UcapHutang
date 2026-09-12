import SwiftUI

struct LedgerListView: View {
    @State private var viewModel: LedgerListViewModel
    private let repository: any TransactionRepository
    private let contacts: any ContactsProviding

    init(repository: any TransactionRepository, contacts: any ContactsProviding) {
        self.repository = repository
        self.contacts = contacts
        _viewModel = State(initialValue: LedgerListViewModel(repository: repository))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Ringkasan Saldo")
                        .font(.title.bold())
                        .foregroundStyle(.primary)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    // Side by side when they fit; stacked at large Dynamic Type sizes.
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 12) {
                            receivableCard
                            debtCard
                        }
                        VStack(spacing: 12) {
                            receivableCard
                            debtCard
                        }
                    }
                    .padding(.horizontal, 20)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(LedgerFilter.allCases) { filter in
                                LedgerFilterPill(
                                    filter: filter,
                                    isSelected: viewModel.filter == filter
                                ) {
                                    viewModel.filter = filter
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    if viewModel.filteredSummaries.isEmpty {
                        AppEmptyState(
                            icon: "book.closed",
                            title: "Belum ada riwayat",
                            message: "Data yang sudah dikonfirmasi akan dikelompokkan per orang."
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.top, 30)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.filteredSummaries) { person in
                                NavigationLink(value: person) {
                                    PersonCardRow(person: person)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.bottom, 24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $viewModel.searchQuery,
                placement: .navigationBarDrawer(displayMode: .automatic),
                prompt: "Cari nama orang"
            )
            .navigationDestination(for: PersonLedgerSummary.self) { person in
                PersonLedgerDetailView(
                    person: person,
                    entries: viewModel.entries(for: person),
                    repository: repository,
                    contacts: contacts
                )
            }
            .task { await viewModel.load() }
            .refreshable { await viewModel.load() }
            .onReceive(NotificationCenter.default.publisher(for: .transactionRepositoryDidChange)) { _ in
                Task { await viewModel.load() }
            }
        }
    }

    private var receivableCard: some View {
        summaryCard(
            title: "Piutang",
            systemImage: "arrow.down.left",
            amount: viewModel.totalReceivable,
            caption: "\(viewModel.receivableCount) orang berutang",
            tint: AppColors.receivable
        )
    }

    private var debtCard: some View {
        summaryCard(
            title: "Utang",
            systemImage: "arrow.up.right",
            amount: viewModel.totalDebt,
            caption: "\(viewModel.debtCount) tanggungan aktif",
            tint: AppColors.debt
        )
    }

    private func summaryCard(title: String, systemImage: String, amount: Int64, caption: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(tint)

            Text(amount.rupiahFormatted)
                .font(.headline.weight(.bold))
                .foregroundStyle(.primary)

            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.08), in: .rect(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
