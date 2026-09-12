import SwiftUI
import Combine

@MainActor
final class ReviewDraftViewModel: ObservableObject {
    @Published var draft: TransactionDraft?
    @Published var errorMessage: String?
    @Published private(set) var didFinish = false
    @Published private(set) var isSaving = false
    @Published var newParticipantName = ""

    private let draftID: UUID
    private let repository: any TransactionRepository

    init(draftID: UUID, repository: any TransactionRepository) {
        self.draftID = draftID
        self.repository = repository
    }

    var validationMessages: [String] {
        guard let draft else { return ["Data transaksi belum selesai dimuat."] }
        var messages: [String] = []
        let cleanTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)

        if draft.totalAmount <= 0 {
            messages.append("Isi nominal transaksi dengan angka lebih dari Rp0.")
        }
        if draft.flow == .personal && draft.type == .unknown {
            messages.append("Pilih siapa yang berutang: kamu atau orang tersebut.")
        }
        if cleanTitle.isEmpty || cleanTitle.caseInsensitiveCompare("Transaksi") == .orderedSame {
            messages.append("Isi judul transaksi, misalnya “Kopi” atau “Makan malam”.")
        }
        if draft.participants.isEmpty {
            messages.append(draft.flow == .personal
                ? "Isi nama orang yang terkait dengan transaksi ini."
                : "Tambahkan minimal satu teman yang ikut split bill.")
        }

        let genericNames = ["teman", "teman 1", "teman 2", "orang", "orang a", "orang b"]
        for (index, participant) in draft.participants.enumerated() {
            let name = participant.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if name.isEmpty || genericNames.contains(where: { name.caseInsensitiveCompare($0) == .orderedSame }) {
                let label = draft.flow == .personal ? "orang terkait" : "peserta ke-\(index + 1)"
                messages.append("Ganti nama \(label) dengan nama yang bisa kamu kenali.")
            }
            if draft.flow == .splitBill && participant.shareAmount <= 0 {
                messages.append("Isi nominal bagian untuk \(name.isEmpty ? "peserta ke-\(index + 1)" : name).")
            }
        }

        let normalizedNames = draft.participants
            .map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        if Set(normalizedNames).count != normalizedNames.count {
            messages.append("Ada nama peserta yang sama. Hapus atau ubah salah satunya.")
        }

        if draft.flow == .splitBill {
            let allocated = draft.participants.reduce(Int64(0)) { $0 + max(0, $1.shareAmount) }
            if allocated > draft.totalAmount {
                messages.append("Total bagian teman melebihi nominal transaksi.")
            }
        }
        return messages
    }

    var isValid: Bool { validationMessages.isEmpty }

    var friendsAllocatedAmount: Int64 {
        draft?.participants.reduce(Int64(0)) { $0 + max(0, $1.shareAmount) } ?? 0
    }

    var userShareAmount: Int64 {
        max(0, (draft?.totalAmount ?? 0) - friendsAllocatedAmount)
    }

    var saveExplanation: String {
        guard let draft else { return "" }
        let linkedCount = draft.participants.filter { $0.contactIdentifier != nil }.count
        let usernameCount = draft.participants.count - linkedCount
        if linkedCount > 0 && usernameCount > 0 {
            return "Saat disimpan, transaksi akan masuk ke Riwayat berdasarkan \(linkedCount) kontak yang terhubung dan \(usernameCount) nama biasa."
        }
        if linkedCount == draft.participants.count, linkedCount > 0 {
            return "Saat disimpan, transaksi akan masuk ke Riwayat setiap kontak yang sudah terhubung."
        }
        return "Kontak bersifat opsional. Saat disimpan, nama biasa tetap dibuat sebagai orang baru di Riwayat utang/piutang."
    }

    func load() async {
        do {
            if let loaded = try await repository.draft(id: draftID) {
                draft = loaded
            } else {
                errorMessage = "Draft ini tidak ditemukan. Kembali ke daftar Draft lalu coba lagi."
            }
        } catch {
            errorMessage = friendlyMessage(for: error)
        }
    }

    func addParticipant() {
        guard var draft else { return }
        let clean = newParticipantName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        guard !draft.participants.contains(where: { $0.name.caseInsensitiveCompare(clean) == .orderedSame }) else {
            errorMessage = "Nama \(clean) sudah ada di daftar peserta."
            return
        }
        draft.participants.append(TransactionParticipant(name: clean, shareAmount: 0))
        newParticipantName = ""
        recalculateSplits(in: &draft)
        self.draft = draft
    }

    func removeParticipant(at offsets: IndexSet) {
        guard var draft else { return }
        draft.participants.remove(atOffsets: offsets)
        recalculateSplits(in: &draft)
        self.draft = draft
    }

    func recalculateSplits(in draft: inout TransactionDraft) {
        guard draft.flow == .splitBill, draft.totalAmount > 0, !draft.participants.isEmpty else { return }
        if draft.splitMethod == .equal || draft.splitMethod == nil {
            let shares = SplitCalculationEngine.calculateEqualShares(
                totalAmount: draft.totalAmount,
                participantCount: draft.participants.count + 1
            )
            for (index, share) in shares.prefix(draft.participants.count).enumerated() {
                draft.participants[index].shareAmount = share
            }
        }
    }

    func updateParticipantName(index: Int, name: String) {
        guard var draft, draft.participants.indices.contains(index) else { return }
        draft.participants[index].name = name
        draft.participants[index].contactIdentifier = nil
        self.draft = draft
    }

    func updateParticipantShare(index: Int, amount: Int64) {
        guard var draft, draft.participants.indices.contains(index) else { return }
        draft.participants[index].shareAmount = amount
        self.draft = draft
    }

    func showValidationMessage() {
        guard !validationMessages.isEmpty else { return }
        errorMessage = "Lengkapi data berikut sebelum menyimpan:\n\n• " + validationMessages.joined(separator: "\n• ")
    }

    func save() async {
        guard !isSaving else { return }
        guard var draft else {
            errorMessage = "Data transaksi belum selesai dimuat."
            return
        }
        guard isValid else {
            showValidationMessage()
            return
        }

        if draft.flow == .personal, !draft.participants.isEmpty {
            draft.participants[0].shareAmount = draft.totalAmount
        }
        isSaving = true
        defer { isSaving = false }
        do {
            draft.status = .confirmed
            try await repository.confirmDraft(draft)
            didFinish = true
        } catch {
            errorMessage = friendlyMessage(for: error)
        }
    }

    func discard() async {
        do {
            try await repository.discardDraft(id: draftID)
            didFinish = true
        } catch {
            errorMessage = friendlyMessage(for: error)
        }
    }

    private func friendlyMessage(for error: Error) -> String {
        if let localized = error as? LocalizedError, let description = localized.errorDescription {
            return description
        }
        return "Data belum berhasil disimpan. Periksa kembali nama orang, nominal, dan judul transaksi, lalu coba lagi."
    }
}

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
                Form {
                    transcriptSection(transcript: draft.rawTranscript)
                    warningsSection(warnings: draft.reviewWarnings)
                    timeSection
                    amountSection
                    typeSection(isPersonal: draft.flow == .personal)
                    participantsSection(draft: draft)
                    notesSection
                    saveGuidanceSection
                    actionsSection
                }
            } else {
                ProgressView("Memuat data...")
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
