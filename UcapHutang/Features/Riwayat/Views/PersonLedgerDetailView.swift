import SwiftUI

struct PersonLedgerDetailView: View {
    @State private var viewModel: PersonLedgerDetailViewModel
    @Environment(\.openURL) private var openURL
    private let repository: any TransactionRepository
    private let contacts: any ContactsProviding


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

    private var statusTint: Color {
        if viewModel.person.balance > 0 { return AppColors.receivable }
        if viewModel.person.balance < 0 { return AppColors.debt }
        return AppColors.textSecondary
    }

    var body: some View {
        List {
            Section {
                if !viewModel.person.isLinked {
                    linkCard
                }

                // Hero Saldo Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(statusTint)
                            .frame(width: 8, height: 8)
                            .accessibilityHidden(true)

                        Text(viewModel.balanceStatusTitle)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(statusTint)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(statusTint.opacity(0.12), in: Capsule())

                    Text(abs(viewModel.person.balance).rupiahFormatted)
                        .font(.largeTitle.bold())
                        .foregroundStyle(.primary)

                    Text(viewModel.balanceStatusDetail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

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
                    .disabled(!viewModel.canRemind)
                    .opacity(viewModel.canRemind ? 1 : 0.45)
                    .accessibilityHint(viewModel.canRemind ? "Pesan ditujukan ke nomor kontak yang terhubung." : "Tidak ada saldo aktif atau nomor kontak belum tersedia.")
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.background, in: .rect(cornerRadius: AppRadius.medium, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                        .stroke(AppColors.border, lineWidth: 1)
                )
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

            Section {
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
                }
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 0))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

            Section("Riwayat Catatan") {
                ForEach(viewModel.filteredEntries) { entry in
                    DetailEntryCardRow(entry: entry)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task { await viewModel.deleteEntry(id: entry.id) }
                            } label: {
                                Label("Hapus", systemImage: "trash")
                            }
                        }
                    }
            }
            .listRowInsets(EdgeInsets(top: 5, leading: 20, bottom: 5, trailing: 20))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .navigationTitle(viewModel.person.displayName)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Catat Bayar") {
                    viewModel.showingPayment = true
                }
                .disabled(!viewModel.canRecordPayment)
                .accessibilityHint(viewModel.canRecordPayment ? viewModel.paymentDirectionDetail : "Tidak ada saldo aktif yang perlu dibayar.")
            }
        }
        .sheet(isPresented: $viewModel.showingPayment) {
            PaymentView(
                person: viewModel.person,
                directionDetail: viewModel.paymentDirectionDetail,
                repository: repository
            ) {
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
            case .linkFailed, .deleteFailed:
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
