import SwiftUI
import Combine

struct ReviewDraftView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ReviewDraftViewModel
    @State private var confirmsDeletion = false
    @State private var contactPickerIndex: Int?

    init(draftID: UUID, repository: any TransactionRepository) {
        _viewModel = StateObject(wrappedValue: ReviewDraftViewModel(draftID: draftID, repository: repository))
    }

    var body: some View {
        Group {
            if let draft = viewModel.draft {
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        transcriptCard(draft.rawTranscript)
                        if !draft.reviewWarnings.isEmpty {
                            warningsSection(warnings: draft.reviewWarnings)
                        }
                        qwenResultSection(draft)
                        personSection(draft)
                        if draft.flow == .splitBill {
                            splitParticipantsSection(draft)
                        }
                        actionSection
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 18)
                    .padding(.bottom, 28)
                }
                .scrollContentBackground(.hidden)
                .background(AppColors.background)
            } else {
                ProgressView("Memuat data...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppColors.background)
            }
        }
        .navigationTitle("Review Catatan")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .onChange(of: viewModel.didFinish) { _, finished in
            if finished { dismiss() }
        }
        .sheet(item: $contactPickerIndex) { index in
            if let participant = viewModel.draft?.participants[safe: index] {
                ContactPickerSheet(
                    targetName: participant.name,
                    onSelect: { candidate in
                        viewModel.draft?.participants[index].name = candidate.fullName
                        viewModel.draft?.participants[index].contactIdentifier = candidate.id
                    },
                    onKeepRaw: {
                        viewModel.draft?.participants[index].contactIdentifier = nil
                    }
                )
            }
        }
        .confirmationDialog("Hapus draft ini?", isPresented: $confirmsDeletion, titleVisibility: .visible) {
            Button("Hapus", role: .destructive) { Task { await viewModel.discard() } }
            Button("Batal", role: .cancel) {}
        } message: {
            Text("Draft ini akan dipindahkan dari daftar yang perlu ditinjau. Riwayat yang sudah dikonfirmasi tidak ikut berubah.")
        }
        .alert("Data Belum Bisa Disimpan", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("Periksa Lagi", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "Periksa kembali data transaksi.")
        }
    }

    private func transcriptCard(_ transcript: String) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Ucapan Asli Rekaman")
                .font(.headline.weight(.bold))
                .foregroundStyle(AppColors.textSecondary)
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: "quote.bubble.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(AppColors.accent)
                Text(transcript.isEmpty ? "Tidak ada ucapan yang tersimpan." : transcript)
                    .font(.body)
                    .foregroundStyle(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Divider().overlay(AppColors.border)
            Text("Gunakan ucapan ini untuk mengecek hasil pengisian otomatis di bawah.")
                .font(.subheadline)
                .foregroundStyle(AppColors.textSecondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func qwenResultSection(_ draft: TransactionDraft) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            reviewValue(label: "Waktu", value: draft.transactionDate.formatted(date: .abbreviated, time: .shortened))
            reviewValue(label: "Nominal", value: draft.totalAmount.rupiahFormatted)
            reviewValue(label: "Deskripsi", value: draft.title)
            if draft.flow == .personal {
                Text("Jenis").font(.body).foregroundStyle(AppColors.textPrimary)
                Picker("Jenis", selection: Binding(
                    get: { viewModel.draft?.type ?? .unknown },
                    set: { viewModel.draft?.type = $0 }
                )) {
                    Text("Utang").tag(TransactionType.hutang)
                    Text("Piutang").tag(TransactionType.piutang)
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private func reviewValue(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.body).foregroundStyle(AppColors.textPrimary)
            Text(value).font(.body.weight(.bold)).foregroundStyle(AppColors.textPrimary)
        }
    }

    private func personSection(_ draft: TransactionDraft) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(draft.flow == .personal ? "Orang" : "Peserta")
                .font(.body).foregroundStyle(AppColors.textPrimary)
            ForEach(Array(draft.participants.enumerated()), id: \.element.id) { index, participant in
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(participant.name).font(.body.weight(.bold))
                        Text(participant.contactIdentifier == nil ? "Nama belum terhubung" : "Terhubung otomatis ke kontak")
                            .font(.subheadline).foregroundStyle(AppColors.textSecondary)
                    }
                    Spacer()
                    Button(participant.contactIdentifier == nil ? "Hubungkan" : "Bukan dia?") {
                        contactPickerIndex = index
                    }
                    .underline()
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textPrimary)
                }
                .padding(14)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppColors.border))
            }
            if draft.flow == .splitBill {
                Button("+ Tambah orang") { viewModel.newParticipantName = "" }
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(AppColors.surface)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(style: StrokeStyle(lineWidth: 1, dash: [6, 4])).foregroundStyle(AppColors.textSecondary))
                    .foregroundStyle(AppColors.textPrimary)
            }
        }
    }

    private func splitParticipantsSection(_ draft: TransactionDraft) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(draft.participants) { participant in
                HStack {
                    Text(participant.name)
                    Spacer()
                    Text(participant.shareAmount.rupiahFormatted).fontWeight(.semibold)
                }
            }
            Divider()
            HStack { Text("Total").fontWeight(.bold); Spacer(); Text(draft.totalAmount.rupiahFormatted).fontWeight(.bold) }
        }
        .padding(16)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var actionSection: some View {
        VStack(spacing: 10) {
            Button("Simpan Catatan") {
                if viewModel.isValid { Task { await viewModel.save() } } else { viewModel.showValidationMessage() }
            }
            .buttonStyle(AppPrimaryButtonStyle())
            .disabled(viewModel.isSaving)
            Button("Hapus catatan ini", role: .destructive) { confirmsDeletion = true }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func transcriptSection(transcript: String) -> some View {
        if !transcript.isEmpty {
            Section("Ucapan Asli Rekaman") {
                Label {
                    Text(transcript)
                        .foregroundStyle(AppColors.textPrimary)
                } icon: {
                    Image(systemName: "quote.bubble.fill")
                        .foregroundStyle(AppColors.accent)
                }
                Text("Gunakan ucapan ini untuk mengecek hasil pengisian otomatis di bawah.")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
    }

    @ViewBuilder
    private func warningsSection(warnings: [String]) -> some View {
        if !warnings.isEmpty {
            Section("Perlu Diperiksa") {
                ForEach(warnings, id: \.self) { warning in
                    Label(warning, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private var timeSection: some View {
        Section("Waktu & Tanggal") {
            DatePicker("Waktu", selection: Binding(
                get: { viewModel.draft?.transactionDate ?? Date() },
                set: { viewModel.draft?.transactionDate = $0 }
            ))
        }
    }

    private var amountSection: some View {
        Section("Nominal & Judul") {
            HStack {
                Text("Rp").font(.headline).foregroundStyle(AppColors.textSecondary)
                TextField("Nominal", value: Binding(
                    get: { viewModel.draft?.totalAmount ?? 0 },
                    set: {
                        viewModel.draft?.totalAmount = $0
                        if var draft = viewModel.draft {
                            viewModel.recalculateSplits(in: &draft)
                            viewModel.draft = draft
                        }
                    }
                ), format: .number)
                .font(.title3.weight(.bold))
                .keyboardType(.numberPad)
            }
            TextField("Judul/Deskripsi Transaksi", text: Binding(
                get: { viewModel.draft?.title ?? "" },
                set: { viewModel.draft?.title = $0 }
            ))
        }
    }

    private func typeSection(isPersonal: Bool) -> some View {
        Section("Jenis Pencatatan") {
            if isPersonal {
                Picker("Jenis", selection: Binding(
                    get: { viewModel.draft?.type ?? .unknown },
                    set: { viewModel.draft?.type = $0 }
                )) {
                    Text("Pilih").tag(TransactionType.unknown)
                    Text("Utang (Saya Berutang)").tag(TransactionType.hutang)
                    Text("Piutang (Dia Berutang)").tag(TransactionType.piutang)
                }
                .pickerStyle(.segmented)
            } else {
                Text("Split Bill (Dibayar oleh Saya)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.split)
                Picker("Metode Bagi", selection: Binding(
                    get: { viewModel.draft?.splitMethod ?? .equal },
                    set: {
                        viewModel.draft?.splitMethod = $0
                        if var draft = viewModel.draft {
                            viewModel.recalculateSplits(in: &draft)
                            viewModel.draft = draft
                        }
                    }
                )) {
                    ForEach(SplitMethod.allCases, id: \.self) { method in
                        Text(method.title).tag(method)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private func participantsSection(draft: TransactionDraft) -> some View {
        let title = draft.flow == .personal ? "Orang Terkait" : "Peserta Split Bill"
        return Section(title) {
            ForEach(0..<draft.participants.count, id: \.self) { index in
                participantCell(index: index, draft: draft)
            }
            .onDelete(perform: draft.flow == .splitBill ? { viewModel.removeParticipant(at: $0) } : nil)
            if draft.flow == .splitBill {
                addParticipantRow
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Bagian teman")
                        Spacer()
                        Text(viewModel.friendsAllocatedAmount.rupiahFormatted).fontWeight(.semibold)
                    }
                    HStack {
                        Text("Bagian kamu")
                        Spacer()
                        Text(viewModel.userShareAmount.rupiahFormatted).fontWeight(.semibold)
                    }
                    Text("Total transaksi: \(draft.totalAmount.rupiahFormatted)")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
                .font(.subheadline)
            }
        }
    }

    private func participantCell(index: Int, draft: TransactionDraft) -> some View {
        let participant = draft.participants[index]
        return VStack(alignment: .leading, spacing: 10) {
            TextField("Nama orang", text: Binding(
                get: { viewModel.draft?.participants[safe: index]?.name ?? "" },
                set: { viewModel.updateParticipantName(index: index, name: $0) }
            ))
            .font(.headline)

            HStack {
                Label(
                    participant.contactIdentifier == nil ? "Nama biasa — tetap bisa disimpan" : "Terhubung ke Kontak",
                    systemImage: participant.contactIdentifier == nil ? "person.crop.circle.badge.questionmark" : "checkmark.circle.fill"
                )
                .font(.caption2)
                .foregroundStyle(participant.contactIdentifier == nil ? Color.secondary : Color.green)
                Spacer()
                Button(participant.contactIdentifier == nil ? "Hubungkan" : "Ganti") {
                    contactPickerIndex = index
                }
                .font(.caption.weight(.bold))
                .buttonStyle(.borderless)
            }

            if draft.flow == .splitBill {
                splitShareRow(index: index, participant: participant, isCustom: draft.splitMethod == .custom)
            }
        }
        .padding(.vertical, 4)
    }

    private func splitShareRow(index: Int, participant: TransactionParticipant, isCustom: Bool) -> some View {
        HStack {
            Text("Nominal bagian:").font(.caption).foregroundStyle(AppColors.textSecondary)
            Spacer()
            if isCustom {
                TextField("Nominal", value: Binding<Int64>(
                    get: { viewModel.draft?.participants[safe: index]?.shareAmount ?? 0 },
                    set: { viewModel.updateParticipantShare(index: index, amount: $0) }
                ), format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .font(.subheadline.weight(.semibold))
            } else {
                Text(participant.shareAmount.rupiahFormatted).font(.subheadline.weight(.semibold))
            }
        }
    }

    private var addParticipantRow: some View {
        HStack {
            TextField("Nama orang baru", text: $viewModel.newParticipantName)
            Button("Tambah") { viewModel.addParticipant() }
                .disabled(viewModel.newParticipantName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var notesSection: some View {
        Section("Catatan Tambahan (Opsional)") {
            TextField("Catatan...", text: Binding(
                get: { viewModel.draft?.notes ?? "" },
                set: { viewModel.draft?.notes = $0.isEmpty ? nil : $0 }
            ))
        }
    }

    private var saveGuidanceSection: some View {
        Section("Setelah Disimpan") {
            Label(viewModel.saveExplanation, systemImage: "book.closed.fill")
                .font(.footnote)
                .foregroundStyle(AppColors.textSecondary)
            if !viewModel.validationMessages.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Masih ada yang perlu dilengkapi", systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.orange)
                    ForEach(viewModel.validationMessages, id: \.self) { message in
                        Text("• \(message)").font(.caption).foregroundStyle(AppColors.textSecondary)
                    }
                }
            }
        }
    }

    private var actionsSection: some View {
        Section {
            Button("Simpan Data") {
                if viewModel.isValid {
                    Task { await viewModel.save() }
                } else {
                    viewModel.showValidationMessage()
                }
            }
            .buttonStyle(AppPrimaryButtonStyle())
            .disabled(viewModel.isSaving)
            Button("Hapus Catatan Ini", role: .destructive) { confirmsDeletion = true }
                .frame(maxWidth: .infinity)
        }
    }
}

extension Int: @retroactive Identifiable {
    public var id: Int { self }
}

extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
