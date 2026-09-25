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
                    HStack(alignment: .top, spacing: 10) {
                        receivableCard
                        debtCard
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
            .navigationTitle("Riwayat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                AppStoreNavigationTitle(title: "Riwayat")
            }
            .searchable(
                text: $viewModel.searchQuery,
                placement: .navigationBarDrawer(displayMode: .always),
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
            caption: "\(viewModel.receivableCount) orang perlu membayarmu",
            tint: AppColors.receivable
        )
    }

    private var debtCard: some View {
        summaryCard(
            title: "Utang",
            systemImage: "arrow.up.right",
            amount: viewModel.totalDebt,
            caption: "Kamu perlu membayar \(viewModel.debtCount) orang",
            tint: AppColors.debt
        )
    }

    private func summaryCard(title: String, systemImage: String, amount: Int64, caption: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.bold))
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(tint)

            Text(amount.rupiahFormatted)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.75)
                .lineLimit(1)

            Text(caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .background(tint.opacity(0.08), in: .rect(cornerRadius: AppRadius.medium, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
