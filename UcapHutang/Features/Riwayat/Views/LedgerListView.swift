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
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        // Title
                        Text("Ringkasan Saldo")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(Color.primary)
                            .padding(.horizontal, 20)
                            .padding(.top, 8)

                        // 2 Metric Summary Cards
                        HStack(spacing: 12) {
                            // Piutang
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.down.left")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Color.green)
                                    Text("Piutang")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(Color.green)
                                }

                                Text(viewModel.totalReceivable.rupiahFormatted)
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(Color.green)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)

                                Text("\(viewModel.receivableCount) orang berutang")
                                    .font(.caption)
                                    .foregroundStyle(Color.secondary)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.green.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                            // Utang
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.up.right")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Color.red)
                                    Text("Utang")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(Color.red)
                                }

                                Text(viewModel.totalDebt.rupiahFormatted)
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(Color.red)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)

                                Text("\(viewModel.debtCount) tanggungan aktif")
                                    .font(.caption)
                                    .foregroundStyle(Color.secondary)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .padding(.horizontal, 20)

                        // Filter Pills
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

                        // Person Card List
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
                    .padding(.bottom, 80)
                }

                // Bottom Search Bar Floating
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color.secondary)

                    TextField("Cari nama orang", text: $viewModel.searchQuery)
                        .font(.body)

                    Image(systemName: "mic")
                        .foregroundStyle(Color.secondary)
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 48)
                .background(Color(.systemBackground))
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(Color(.separator), lineWidth: 1)
                )
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: PersonLedgerSummary.self) { person in
                PersonLedgerDetailView(person: person, entries: viewModel.entries(for: person), repository: repository, contacts: contacts)
            }
            .task { await viewModel.load() }
            .refreshable { await viewModel.load() }
            .onReceive(NotificationCenter.default.publisher(for: .transactionRepositoryDidChange)) { _ in
                Task { await viewModel.load() }
            }
        }
    }
}
