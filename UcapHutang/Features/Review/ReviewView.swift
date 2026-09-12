import SwiftUI
import Combine

struct ReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ReviewViewModel
    @State private var confirmsDeletion = false
    @State private var contactPickerIndex: Int?

    init(draftID: UUID, repository: any TransactionRepository) {
        _viewModel = StateObject(wrappedValue: ReviewViewModel(draftID: draftID, repository: repository))
    }

    var body: some View {
        VStack(spacing: 0) {
            reviewHeader
            Group {
                if let draft = viewModel.draft {
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        autosaveNotice
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
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await viewModel.load() }
        .onDisappear {
            Task { await viewModel.flushPendingEdits() }
        }
        .onChange(of: viewModel.didFinish) { _, finished in
            if finished { dismiss() }
        }
        .sheet(item: $contactPickerIndex) { index in
            if let participant = viewModel.draft?.participants[safe: index] {
                ContactPickerSheet(
                    targetName: participant.name,
                    onSelect: { candidate in
                        viewModel.updateParticipantContact(index: index, candidate: candidate)
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

    private var reviewHeader: some View {
        HStack {
            Button {
                Task {
                    await viewModel.flushPendingEdits()
                    dismiss()
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .background(Color(.systemGray6))
                    .clipShape(Circle())
            }
            .foregroundStyle(AppColors.textPrimary)

            Spacer()
            Text("Review Catatan")
                .font(.headline.weight(.bold))
                .foregroundStyle(AppColors.textPrimary)
            Spacer()

            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 18)
        .background(AppColors.background)
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
            editableDate(draft.transactionDate)
            editableAmount(draft.totalAmount)
            editableTitle(draft.title)
            if draft.flow == .personal {
                Text("Jenis").font(.body).foregroundStyle(AppColors.textPrimary)
                Picker("Jenis", selection: Binding(
                    get: { viewModel.draft?.type ?? .unknown },
                    set: { viewModel.updateType($0) }
                )) {
                    Text("Hutang").tag(TransactionType.hutang)
                    Text("Piutang").tag(TransactionType.piutang)
                }
                .pickerStyle(.segmented)
                .padding(2)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(draft.type == .unknown ? AppColors.warning.opacity(0.12) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(draft.type == .unknown ? AppColors.warning : Color.clear)
                )
            }
        }
    }

    private func reviewValue(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.body).foregroundStyle(AppColors.textPrimary)
            Text(value).font(.body.weight(.bold)).foregroundStyle(AppColors.textPrimary)
        }
    }

    private func editableDate(_ date: Date) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Waktu").font(.body).foregroundStyle(AppColors.textPrimary)
            DatePicker(
                "Waktu",
                selection: Binding(
                    get: { viewModel.draft?.transactionDate ?? date },
                    set: { viewModel.updateTransactionDate($0) }
                ),
                displayedComponents: [.date, .hourAndMinute]
            )
            .labelsHidden()
            .tint(AppColors.accent)
        }
    }

    private func editableAmount(_ amount: Int64) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Nominal").font(.body).foregroundStyle(AppColors.textPrimary)
            HStack(spacing: 4) {
                Text("Rp.").font(.body.weight(.bold))
                TextField("0", value: Binding(
                    get: { viewModel.draft?.totalAmount ?? amount },
                    set: { viewModel.updateTotalAmount($0) }
                ), format: .number)
                .font(.body.weight(.bold))
                .keyboardType(.numberPad)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(fieldBackground(isInvalid: amount <= 0))
        }
    }

    private func editableTitle(_ title: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Deskripsi").font(.body).foregroundStyle(AppColors.textPrimary)
            TextField("Deskripsi transaksi", text: Binding(
                get: { viewModel.draft?.title ?? title },
                set: { viewModel.updateTitle($0) }
            ))
            .font(.body.weight(.bold))
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(fieldBackground(isInvalid: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
        }
    }

    private func fieldBackground(isInvalid: Bool) -> some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(isInvalid ? AppColors.warning.opacity(0.12) : AppColors.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isInvalid ? AppColors.warning : AppColors.border)
            )
    }

    private func reviewDate(_ date: Date) -> String {
        let dateValue = Calendar.current.isDateInToday(date)
            ? "Hari Ini"
            : date.formatted(date: .abbreviated, time: .omitted)
        return "\(dateValue), \(date.formatted(date: .omitted, time: .shortened))"
    }

    private func personSection(_ draft: TransactionDraft) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(draft.flow == .personal ? "Orang" : "Peserta")
                .font(.body).foregroundStyle(AppColors.textPrimary)
            ForEach(Array(draft.participants.enumerated()), id: \.element.id) { index, participant in
                let isLinked = participant.contactIdentifier.map {
                    !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                } ?? false
                let isIncluded = draft.flow != .splitBill || participant.shareAmount > 0
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(participant.name).font(.body.weight(.bold))
                        Text(isIncluded ? (isLinked ? "Sudah Terverifikasi" : "Belum Terverifikasi") : "Tidak ikut pembagian")
                            .font(.subheadline)
                            .foregroundStyle(isIncluded ? (isLinked ? Color.green : AppColors.destructive) : AppColors.textSecondary)
                    }
                    Spacer()
                    if isIncluded {
                        Button(isLinked ? "Bukan dia?" : "Hubungkan") {
                            contactPickerIndex = index
                        }
                        .underline()
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textPrimary)
                    }
                }
                .padding(14)
                .background(isIncluded ? (isLinked ? Color.green.opacity(0.08) : AppColors.destructive.opacity(0.08)) : AppColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isIncluded ? (isLinked ? Color.green.opacity(0.65) : AppColors.destructive) : AppColors.border)
                )
            }
            if draft.flow == .splitBill {
                HStack(spacing: AppSpacing.small) {
                    TextField("Nama orang baru", text: $viewModel.newParticipantName)
                        .textFieldStyle(.plain)
                    Button("Tambah") { viewModel.addParticipant() }
                        .font(.subheadline.weight(.semibold))
                        .disabled(viewModel.newParticipantName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 52)
                .background(AppColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                        .foregroundStyle(AppColors.textSecondary)
                )
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Catatan Opsional")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.textSecondary)
                TextField("Tambahkan catatan jika diperlukan", text: Binding(
                    get: { viewModel.draft?.notes ?? "" },
                    set: { viewModel.updateNotes($0) }
                ), axis: .vertical)
                .lineLimit(1...3)
                .textFieldStyle(.plain)
                .font(.subheadline)
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }

    private func splitParticipantsSection(_ draft: TransactionDraft) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Pembagian Nominal")
                .font(.body.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)

            Picker("Metode Pembagian", selection: Binding(
                get: { viewModel.draft?.splitMethod ?? .equal },
                set: { viewModel.updateSplitMethod($0) }
            )) {
                Text("Sama Rata").tag(SplitMethod.equal)
                Text("Custom Nominal").tag(SplitMethod.custom)
            }
            .pickerStyle(.segmented)

            Text(draft.splitMethod == .custom
                ? "Atur nominal setiap orang. Isi 0 jika tidak ikut."
                : "Pilih siapa saja yang ikut dalam pembagian sama rata.")
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)

            splitUserRow(draft)

            ForEach(Array(draft.participants.enumerated()), id: \.element.id) { index, participant in
                splitFriendRow(index: index, participant: participant, method: draft.splitMethod ?? .equal)
            }

            Divider().overlay(AppColors.border)

            HStack {
                Text("Total Pembagian")
                    .fontWeight(.semibold)
                Spacer()
                Text(viewModel.splitAllocatedAmount.rupiahFormatted)
                    .fontWeight(.bold)
                    .foregroundStyle(viewModel.splitRemainingAmount == 0 ? Color.green : AppColors.destructive)
            }

            if viewModel.splitRemainingAmount == 0 {
                Label("Sudah sesuai dengan total transaksi", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
            } else {
                let difference = abs(viewModel.splitRemainingAmount)
                Label(
                    viewModel.splitRemainingAmount > 0
                        ? "Masih ada \(difference.rupiahFormatted) yang belum dibagi"
                        : "Pembagian melebihi total sebesar \(difference.rupiahFormatted)",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.destructive)
            }

            HStack {
                Text("Total Transaksi")
                Spacer()
                Text(draft.totalAmount.rupiahFormatted).fontWeight(.bold)
            }
        }
        .padding(16)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func splitUserRow(_ draft: TransactionDraft) -> some View {
        let method = draft.splitMethod ?? .equal
        let isIncluded = viewModel.userShareAmount > 0
        return HStack(spacing: AppSpacing.medium) {
            if method == .equal {
                Button { viewModel.toggleUserIncluded() } label: {
                    Image(systemName: isIncluded ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isIncluded ? AppColors.accent : AppColors.textSecondary)
                }
                .buttonStyle(.plain)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Kamu").font(.body.weight(.bold))
                    Text("PEMBAYAR")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppColors.accent)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(AppColors.accent.opacity(0.12))
                        .clipShape(Capsule())
                }
                Text(isIncluded ? "Ikut pembagian" : "Tidak ikut pembagian")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
            Spacer()
            splitAmountEditor(
                amount: viewModel.userShareAmount,
                isEditable: method == .custom,
                onChange: viewModel.updateUserShare
            )
        }
        .padding(12)
        .background(AppColors.accent.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.accent.opacity(0.35)))
    }

    private func splitFriendRow(index: Int, participant: TransactionParticipant, method: SplitMethod) -> some View {
        let isIncluded = participant.shareAmount > 0
        return HStack(spacing: AppSpacing.medium) {
            if method == .equal {
                Button { viewModel.toggleParticipantIncluded(index: index) } label: {
                    Image(systemName: isIncluded ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isIncluded ? AppColors.accent : AppColors.textSecondary)
                }
                .buttonStyle(.plain)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(participant.name).font(.body.weight(.semibold))
                Text(isIncluded ? "Ikut pembagian" : "Tidak ikut pembagian")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
            Spacer()
            splitAmountEditor(
                amount: participant.shareAmount,
                isEditable: method == .custom,
                onChange: { viewModel.updateParticipantShare(index: index, amount: $0) }
            )
        }
        .padding(.vertical, 8)
        .opacity(isIncluded || method == .custom ? 1 : 0.55)
    }

    @ViewBuilder
    private func splitAmountEditor(amount: Int64, isEditable: Bool, onChange: @escaping (Int64) -> Void) -> some View {
        if isEditable {
            HStack(spacing: 3) {
                Text("Rp.").font(.caption.weight(.semibold))
                TextField("0", value: Binding(get: { amount }, set: onChange), format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 92)
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 8)
            .frame(minHeight: 36)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            Text(amount.rupiahFormatted)
                .font(.subheadline.weight(.semibold))
        }
    }

    private var actionSection: some View {
        VStack(spacing: 10) {
            Button("Simpan ke Riwayat") {
                if viewModel.isValid { Task { await viewModel.save() } } else { viewModel.showValidationMessage() }
            }
            .buttonStyle(AppPrimaryButtonStyle())
            .disabled(viewModel.isSaving)
            Button("Hapus Draf Review", role: .destructive) { confirmsDeletion = true }
        }
        .frame(maxWidth: .infinity)
    }

    private var autosaveNotice: some View {
        HStack(alignment: .top, spacing: AppSpacing.small) {
            Image(systemName: viewModel.autosaveErrorMessage == nil ? "checkmark.icloud.fill" : "exclamationmark.icloud.fill")
                .foregroundStyle(viewModel.autosaveErrorMessage == nil ? Color.green : AppColors.destructive)
            VStack(alignment: .leading, spacing: 3) {
                Text(viewModel.isAutosaving ? "Menyimpan perubahan..." : "Tersimpan otomatis sebagai draf")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(viewModel.autosaveErrorMessage == nil ? AppColors.textPrimary : AppColors.destructive)
                Text(viewModel.autosaveErrorMessage
                    ?? "Kamu bisa menutup aplikasi dan melanjutkan review ini nanti dari halaman Draf.")
                    .font(.caption)
                    .foregroundStyle(viewModel.autosaveErrorMessage == nil ? AppColors.textSecondary : AppColors.destructive)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            (viewModel.autosaveErrorMessage == nil ? Color.green : AppColors.destructive)
                .opacity(0.08)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
