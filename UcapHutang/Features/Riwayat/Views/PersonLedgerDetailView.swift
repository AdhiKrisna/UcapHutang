import SwiftUI

struct PersonLedgerDetailView: View {
    @State private var viewModel: PersonLedgerDetailViewModel
    @Environment(\.openURL) private var openURL
    private let repository: any TransactionRepository

    init(person: PersonLedgerSummary, entries: [LedgerEntry], repository: any TransactionRepository) {
        self.repository = repository
        _viewModel = State(initialValue: PersonLedgerDetailViewModel(
            person: person,
            entries: entries,
            repository: repository
        ))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Hero Saldo Card
                VStack(alignment: .leading, spacing: 12) {
                    // Status Tag
                    HStack(spacing: 6) {
                        Circle()
                            .fill(viewModel.person.balance >= 0 ? Color.green : Color.red)
                            .frame(width: 8, height: 8)

                        Text(viewModel.person.balance >= 0 ? "Dia berutang padamu" : "Kamu berutang padanya")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(viewModel.person.balance >= 0 ? Color.green : Color.red)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background((viewModel.person.balance >= 0 ? Color.green : Color.red).opacity(0.12))
                    .clipShape(Capsule())

                    // Big Balance Text
                    Text(abs(viewModel.person.balance).rupiahFormatted)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(Color.primary)

                    // Ingatkan Action Button
                    Button {
                        if let url = viewModel.reminderMessageURL {
                            openURL(url)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "message.fill")
                                .font(.subheadline)
                            Text("Ingatkan lewat iMessage")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(Color.primary)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(Color(red: 1.0, green: 0.96, blue: 0.88))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(.separator), lineWidth: 1)
                )
                .padding(.horizontal, 20)

                // Detail Filter Pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(DetailFilter.allCases) { filter in
                            DetailFilterPill(
                                filter: filter,
                                isSelected: viewModel.selectedFilter == filter
                            ) {
                                viewModel.selectedFilter = filter
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }

                // Section Title: Riwayat Catatan
                Text("Riwayat Catatan")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.primary)
                    .padding(.horizontal, 20)
                    .padding(.top, 4)

                // History Entries List
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.filteredEntries) { entry in
                        DetailEntryCardRow(entry: entry)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(viewModel.person.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Catat Bayar") {
                    viewModel.showingPayment = true
                }
                .font(.subheadline.weight(.medium))
            }
        }
        .sheet(isPresented: $viewModel.showingPayment) {
            PaymentView(person: viewModel.person, repository: repository) {
                viewModel.showingPayment = false
                Task { await viewModel.reload() }
            }
        }
        .task { await viewModel.reload() }
        .onReceive(NotificationCenter.default.publisher(for: .transactionRepositoryDidChange)) { _ in
            Task { await viewModel.reload() }
        }
    }
}
