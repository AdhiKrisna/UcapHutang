import SwiftUI

struct PersonLedgerDetailView: View {
    @State private var viewModel: PersonLedgerDetailViewModel
    @Environment(\.openURL) private var openURL
    private let repository: any TransactionRepository
    private let contacts: any ContactsProviding

    private let blockedActionHint = "Hubungkan orang ini ke kontak terlebih dahulu."

    init(
        person: PersonLedgerSummary,
        entries: [LedgerEntry],
        repository: any TransactionRepository,
        contacts: any ContactsProviding
    ) {
        self.repository = repository
        self.contacts = contacts
        _viewModel = State(initialValue: PersonLedgerDetailViewModel(
            person: person,
            entries: entries,
            repository: repository,
            contacts: contacts
        ))
    }

    private var isReceivable: Bool {
        viewModel.person.balance >= 0
    }

    private var statusTint: Color {
        isReceivable ? AppColors.receivable : AppColors.debt
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if !viewModel.person.isLinked {
                    linkCard
                        .padding(.horizontal, 20)
                }

                // Hero Saldo Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(statusTint)
                            .frame(width: 8, height: 8)
                            .accessibilityHidden(true)

                        Text(isReceivable ? "Dia berutang padamu" : "Kamu berutang padanya")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(statusTint)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(statusTint.opacity(0.12), in: Capsule())

                    Text(abs(viewModel.person.balance).rupiahFormatted)
                        .font(.largeTitle.bold())
                        .foregroundStyle(.primary)

                    Button {
                        if let url = viewModel.reminderMessageURL {
                            openURL(url)
                        }
                    } label: {
                        Label("Ingatkan lewat Pesan", systemImage: "message.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .background(AppColors.reminderButtonBackground, in: .rect(cornerRadius: AppRadius.small, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(!viewModel.canRecordPaymentOrRemind)
                    .accessibilityHint(viewModel.canRecordPaymentOrRemind ? "" : blockedActionHint)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.background, in: .rect(cornerRadius: AppRadius.medium, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                        .stroke(AppColors.border, lineWidth: 1)
                )
                .padding(.horizontal, 20)

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

                Text("Riwayat Catatan")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.horizontal, 20)
                    .padding(.top, 4)

                LazyVStack(spacing: 10) {
                    ForEach(viewModel.filteredEntries) { entry in
                        DetailEntryCardRow(entry: entry)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .background(AppColors.background)
        .navigationTitle(viewModel.person.displayName)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Catat Bayar") {
                    viewModel.showingPayment = true
                }
                .disabled(!viewModel.canRecordPaymentOrRemind)
                .accessibilityHint(viewModel.canRecordPaymentOrRemind ? "" : blockedActionHint)
            }
        }
        .sheet(isPresented: $viewModel.showingPayment) {
            PaymentView(person: viewModel.person, repository: repository) {
                viewModel.showingPayment = false
                Task { await viewModel.reload() }
            }
        }
        .sheet(isPresented: $viewModel.isShowingContactPicker) {
            ReviewContactPickerSheet(
                allowsMultipleSelection: false,
                initialQuery: viewModel.person.displayName,
                contacts: contacts,
                repository: repository
            ) { picked in
                guard let contact = picked.first else { return }
                Task { await viewModel.handlePicked(contact) }
            }
        }
        .confirmationDialog(
            "Gabungkan riwayat?",
            isPresented: $viewModel.isConfirmingMerge,
            titleVisibility: .visible,
            presenting: viewModel.pendingMerge
        ) { _ in
            Button("Gabungkan") {
                Task { await viewModel.confirmMerge() }
            }
            Button("Batal", role: .cancel) {
                viewModel.cancelMerge()
            }
        } message: { contact in
            Text("Riwayat “\(viewModel.person.displayName)” akan digabung dengan “\(contact.displayName)”. Saldo akan dijumlahkan.")
        }
        .alert(
            viewModel.alert?.title ?? "",
            isPresented: Binding(
                get: { viewModel.alert != nil },
                set: { if !$0 { viewModel.alert = nil } }
            ),
            presenting: viewModel.alert
        ) { alert in
            switch alert {
            case .contactsAccessRequired:
                Button("Buka Pengaturan") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
                Button("Nanti", role: .cancel) {}
            case .linkFailed:
                Button("OK", role: .cancel) {}
            }
        } message: { alert in
            Text(alert.message)
        }
        .task { await viewModel.reload() }
        .onReceive(NotificationCenter.default.publisher(for: .transactionRepositoryDidChange)) { _ in
            Task { await viewModel.reload() }
        }
    }

    private var linkCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text("Hubungkan orang ini ke kontak untuk mencatat pembayaran atau mengirim pengingat.")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            } icon: {
                Image(systemName: "person.crop.circle.badge.exclamationmark")
                    .foregroundStyle(AppColors.warning)
            }

            Button {
                Task { await viewModel.requestLink() }
            } label: {
                Text("Hubungkan ke Kontak")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .tint(.primary)
        }
        .padding(AppSpacing.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.surface, in: .rect(cornerRadius: AppRadius.medium))
    }
}
