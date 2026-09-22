import SwiftUI

struct ReviewDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var viewModel: ReviewDetailViewModel
    private let repository: any TransactionRepository
    private let contacts: any ContactsProviding

    init(draftID: UUID, repository: any TransactionRepository, contacts: any ContactsProviding) {
        self.repository = repository
        self.contacts = contacts
        _viewModel = State(initialValue: ReviewDetailViewModel(
            draftID: draftID,
            repository: repository,
            contacts: contacts
        ))
    }

    var body: some View {
        content
            .navigationTitle("Review Catatan")
            .navigationBarTitleDisplayMode(.large)
            .task { await viewModel.load() }
            .onDisappear {
                Task { await viewModel.flushPendingEdits() }
            }
            .onChange(of: viewModel.didFinish) { _, finished in
                if finished { dismiss() }
            }
            .sensoryFeedback(.success, trigger: viewModel.didSave)
            .sheet(item: $viewModel.pickerRequest) { request in
                ReviewContactPickerSheet(request: request, contacts: contacts, repository: repository) { picked in
                    viewModel.handlePicked(picked, for: request)
                }
            }
            .confirmationDialog("Hapus catatan ini?", isPresented: $viewModel.isConfirmingDelete, titleVisibility: .visible) {
                Button("Hapus", role: .destructive) {
                    Task { await viewModel.delete() }
                }
                Button("Batal", role: .cancel) {}
            } message: {
                Text("Catatan dan transkripnya akan dihapus permanen.")
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
                case .incomplete:
                    Button("Periksa Lagi", role: .cancel) {}
                case .contactsAccessRequired:
                    Button("Buka Pengaturan") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    }
                    Button("Nanti", role: .cancel) {}
                case .duplicateContact, .saveFailed, .deleteFailed:
                    Button("OK", role: .cancel) {}
                }
            } message: { alert in
                if let message = alert.message {
                    Text(message)
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.loadState {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .notFound:
            ContentUnavailableView("Catatan ini tidak ditemukan.", systemImage: "doc.questionmark")
        case .loaded:
            if let draft = viewModel.draft {
                form(draft)
            }
        }
    }

    private func form(_ draft: TransactionDraft) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                autosaveStatus

                VStack(alignment: .leading, spacing: AppSpacing.medium) {
                    field("Waktu Transaksi") {
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundStyle(AppColors.accent)
                                .font(.body.weight(.medium))

                            DatePicker(
                                "Waktu",
                                selection: Binding(
                                    get: { viewModel.draft?.transactionDate ?? Date() },
                                    set: { viewModel.setTransactionDate($0) }
                                ),
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .labelsHidden()
                            .environment(\.locale, Locale(identifier: "id_ID"))
                        }
                        .padding(.horizontal, AppSpacing.medium)
                        .frame(minHeight: 48)
                        .background(AppColors.surface, in: .rect(cornerRadius: AppRadius.small))
                    }

                    field("Nominal") {
                        if viewModel.isCustomSplit {
                            HStack {
                                Text("Rp")
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(.secondary)
                                Text(draft.totalAmount.rupiahFormatted.replacingOccurrences(of: "Rp", with: "").trimmingCharacters(in: .whitespaces))
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(AppColors.textPrimary)
                            }
                            .padding(.horizontal, AppSpacing.large)
                            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                            .background(AppColors.surface, in: .rect(cornerRadius: AppRadius.small))
                        } else {
                            HStack {
                                Text("Rp")
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(.secondary)
                                TextField(
                                    "0",
                                    value: Binding(
                                        get: { viewModel.draft?.totalAmount ?? 0 },
                                        set: { viewModel.setTotalAmount($0) }
                                    ),
                                    format: .number
                                )
                                .keyboardType(.numberPad)
                                .font(.title3.weight(.bold))
                                .frame(minHeight: 52)
                            }
                            .padding(.horizontal, AppSpacing.large)
                            .background(AppColors.surface, in: .rect(cornerRadius: AppRadius.small))
                        }
                    }

                    field("Deskripsi") {
                        TextField(
                            "Deskripsi transaksi",
                            text: Binding(
                                get: { viewModel.draft?.title ?? "" },
                                set: { viewModel.setTitle($0) }
                            )
                        )
                        .font(.body.weight(.medium))
                        .padding(.horizontal, AppSpacing.large)
                        .frame(minHeight: 48)
                        .background(AppColors.surface, in: .rect(cornerRadius: AppRadius.small))
                    }

                    if draft.flow == .personal {
                        field("Jenis Transaksi") {
                            VStack(alignment: .leading, spacing: AppSpacing.small) {
                                Picker("Jenis", selection: Binding(
                                    get: { viewModel.draft?.type ?? .unknown },
                                    set: { viewModel.setType($0) }
                                )) {
                                    Text("Utang").tag(TransactionType.hutang)
                                    Text("Piutang").tag(TransactionType.piutang)
                                }
                                .pickerStyle(.segmented)

                                Label(
                                    draft.type == .hutang
                                        ? "Utang: kamu yang perlu membayar orang ini."
                                        : "Piutang: kamu meminjamkan uang dan orang ini perlu membayarmu.",
                                    systemImage: "info.circle"
                                )
                                .font(.footnote)
                                .foregroundStyle(draft.type == .hutang ? AppColors.debt : AppColors.receivable)
                            }
                        }
                    } else {
                        field("Metode Bagi") {
                            Picker("Metode bagi", selection: Binding(
                                get: { viewModel.draft?.splitMethod ?? .equal },
                                set: { viewModel.setSplitMethod($0) }
                            )) {
                                Text("Bagi Rata").tag(SplitMethod.equal)
                                Text("Custom").tag(SplitMethod.custom)
                            }
                            .pickerStyle(.segmented)
                        }
                        if !viewModel.isCustomSplit {
                            Toggle("Saya ikut dihitung", isOn: Binding(
                                get: { viewModel.draft?.includesUser ?? true },
                                set: { viewModel.setIncludesUser($0) }
                            ))
                            .font(.body.weight(.medium))
                            .padding(.horizontal, AppSpacing.large)
                            .frame(minHeight: 48)
                            .background(AppColors.surface, in: .rect(cornerRadius: AppRadius.small))
                        }
                    }
                }

                peopleSection(draft)

                field("Catatan Tambahan (Opsional)") {
                    TextField(
                        "Tambahkan catatan jika diperlukan",
                        text: Binding(
                            get: { viewModel.draft?.notes ?? "" },
                            set: { viewModel.setNotes($0) }
                        ),
                        axis: .vertical
                    )
                    .font(.body)
                    .lineLimit(1...3)
                    .padding(AppSpacing.medium)
                    .frame(minHeight: 48)
                    .background(AppColors.surface, in: .rect(cornerRadius: AppRadius.small))
                }

                if draft.flow == .splitBill {
                    splitSummary(draft)
                }

                actions
            }
            .padding(.horizontal, AppSpacing.xLarge)
            .padding(.vertical, AppSpacing.large)
        }
        .background(AppColors.background)
        .scrollDismissesKeyboard(.interactively)
    }

    private var autosaveStatus: some View {
        HStack(alignment: .top, spacing: 10) {
            Group {
                if viewModel.isAutosaving {
                    ProgressView()
                } else if viewModel.autosaveErrorMessage != nil {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(AppColors.destructive)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppColors.receivable)
                }
            }
            .accessibilityHidden(true)

            if viewModel.isAutosaving {
                Text("Menyimpan perubahan…")
                    .font(.subheadline.weight(.semibold))
            } else if let errorMessage = viewModel.autosaveErrorMessage {
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.destructive)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tersimpan otomatis sebagai draft")
                        .font(.subheadline.weight(.semibold))
                    Text("Kamu bisa menutup halaman ini dan melanjutkan nanti dari tab Review.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppColors.surface, in: .rect(cornerRadius: AppRadius.small))
        .accessibilityElement(children: .combine)
    }

    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Text(label)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            content()
        }
    }

    private func peopleSection(_ draft: TransactionDraft) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Orang")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ForEach(draft.participants) { participant in
                if draft.flow == .splitBill {
                    participantBlock(participant, in: draft)
                        .contextMenu {
                            Button("Hapus dari catatan", role: .destructive) {
                                viewModel.removeParticipant(id: participant.id)
                            }
                        }
                        .accessibilityAction(named: "Hapus dari catatan") {
                            viewModel.removeParticipant(id: participant.id)
                        }
                } else {
                    participantBlock(participant, in: draft)
                }
            }

            if draft.flow == .splitBill {
                addByNameRow

                Button {
                    Task { await viewModel.requestPicker(.addParticipants) }
                } label: {
                    Text("+ Pilih dari kontak")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .tint(.secondary)
            }
        }
    }

    private var addByNameRow: some View {
        HStack(spacing: 8) {
            TextField("Nama orang baru", text: $viewModel.newParticipantName)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .onSubmit {
                    Task { await viewModel.addParticipantFromName() }
                }
                .frame(minHeight: 44)

            Button("Tambah") {
                Task { await viewModel.addParticipantFromName() }
            }
            .font(.subheadline.weight(.semibold))
            .frame(minHeight: 44)
            .disabled(viewModel.newParticipantName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 14)
        .background(AppColors.surface, in: .rect(cornerRadius: AppRadius.small))
    }

    private func participantBlock(_ participant: TransactionParticipant, in draft: TransactionDraft) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SmartContactCardView(
                name: participant.name,
                state: viewModel.cardState(for: participant),
                showsRequiredMarker: viewModel.showsRequiredMarker(for: participant.id),
                onLink: { openPicker(for: participant) },
                onConfirmSuggestion: { viewModel.confirmSuggestion(participantID: participant.id) },
                onChooseOther: { openPicker(for: participant) },
                onChange: { openPicker(for: participant) }
            )
            if draft.flow == .splitBill {
                SplitParticipantRow(
                    amount: participant.shareAmount,
                    isEditable: viewModel.isCustomSplit,
                    onAmountChange: { viewModel.setShare(participantID: participant.id, amount: $0) }
                )
                .padding(.horizontal, 14)
            }
        }
    }

    private func openPicker(for participant: TransactionParticipant) {
        Task {
            await viewModel.requestPicker(.link(participantID: participant.id, prefill: participant.name))
        }
    }

    private func splitSummary(_ draft: TransactionDraft) -> some View {
        VStack(spacing: 8) {
            summaryRow("Bagian teman", viewModel.friendsTotal)
            if !viewModel.isCustomSplit && draft.includesUser {
                summaryRow("Bagian kamu", viewModel.userShare)
            }
            Divider()
            summaryRow("Total transaksi", draft.totalAmount)
                .font(.body.weight(.semibold))
        }
        .padding(14)
        .background(AppColors.surface, in: .rect(cornerRadius: AppRadius.small))
    }

    private func summaryRow(_ label: String, _ amount: Int64) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(amount.rupiahFormatted)
        }
        .font(.body)
        .accessibilityElement(children: .combine)
    }

    private var actions: some View {
        VStack(spacing: 12) {
            Text(viewModel.saveStatusMessage)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                Task { await viewModel.save() }
            } label: {
                Group {
                    if viewModel.isSaving {
                        ProgressView()
                            .tint(AppColors.background)
                    } else {
                        Label("Simpan ke Riwayat", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                    }
                }
                .foregroundStyle(AppColors.background)
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.primary)
            .disabled(viewModel.isSaving)

            Button(role: .destructive) {
                viewModel.isConfirmingDelete = true
            } label: {
                Label("Hapus Draft", systemImage: "trash")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .tint(AppColors.destructive)
        }
        .padding(.top, 12)
    }
}

#if DEBUG
private final class PreviewContactsProvider: ContactsProviding {
    func access() async -> ContactsAccess { .authorized }
    func requestAccess() async -> ContactsAccess { .authorized }
    func search(name: String) async -> [ContactRef] {
        [ContactRef(identifier: "preview-dito", displayName: "Andito Rizkika", phoneNumber: "+62 812")]
    }
    func contacts(withIdentifiers ids: [String]) async -> [ContactRef] { [] }
}

#Preview("Review Personal") {
    let draft = TransactionDraft(
        flow: .personal,
        type: .hutang,
        title: "Pinjam buat makan siang",
        totalAmount: 150_000,
        participants: [TransactionParticipant(name: "Dito", shareAmount: 150_000)],
        rawTranscript: "Pinjam 150 ribu ke Dito buat makan siang"
    )
    return NavigationStack {
        ReviewDetailView(
            draftID: draft.id,
            repository: InMemoryTransactionRepository(seedDrafts: [draft]),
            contacts: PreviewContactsProvider()
        )
    }
}
#endif
