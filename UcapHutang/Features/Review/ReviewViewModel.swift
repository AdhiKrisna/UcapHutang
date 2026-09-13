import Foundation
import Combine

@MainActor
final class ReviewViewModel: ObservableObject {
    @Published var draft: TransactionDraft?
    @Published var errorMessage: String?
    @Published private(set) var didFinish = false
    @Published private(set) var isSaving = false
    @Published private(set) var isAutosaving = false
    @Published private(set) var autosaveErrorMessage: String?
    @Published var newParticipantName = ""

    private let draftID: UUID
    private let repository: any TransactionRepository
    private var autosaveTask: Task<Void, Never>?

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
            if draft.flow == .splitBill && participant.shareAmount == 0 { continue }
            let name = participant.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if name.isEmpty || genericNames.contains(where: { name.caseInsensitiveCompare($0) == .orderedSame }) {
                let label = draft.flow == .personal ? "orang terkait" : "peserta ke-\(index + 1)"
                messages.append("Ganti nama \(label) dengan nama yang bisa kamu kenali.")
            }
            if participant.contactIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
                messages.append("Hubungkan \(name.isEmpty ? "peserta ke-\(index + 1)" : name) ke Kontak.")
            }

        }

        let normalizedNames = (draft.flow == .splitBill
            ? draft.participants.filter { $0.shareAmount > 0 }
            : draft.participants)
            .map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        if Set(normalizedNames).count != normalizedNames.count {
            messages.append("Ada nama peserta yang sama. Hapus atau ubah salah satunya.")
        }

        if draft.flow == .splitBill {
            let includedFriends = draft.participants.filter { $0.shareAmount > 0 }
            if includedFriends.isEmpty {
                messages.append("Pilih minimal satu teman yang ikut Split Bill.")
            }
            let allocated = includedFriends.reduce(max(0, draft.userShareAmount ?? 0)) { $0 + $1.shareAmount }
            if allocated != draft.totalAmount {
                messages.append("Jumlah pembagian harus sama dengan total transaksi.")
            }
        }
        return messages
    }

    var isValid: Bool { validationMessages.isEmpty }

    var friendsAllocatedAmount: Int64 {
        draft?.participants.reduce(Int64(0)) { $0 + max(0, $1.shareAmount) } ?? 0
    }

    var userShareAmount: Int64 {
        max(0, draft?.userShareAmount ?? 0)
    }

    var splitAllocatedAmount: Int64 { friendsAllocatedAmount + userShareAmount }
    var splitRemainingAmount: Int64 { (draft?.totalAmount ?? 0) - splitAllocatedAmount }

    var saveExplanation: String {
        guard let draft else { return "" }
        let relevantParticipants = draft.flow == .splitBill
            ? draft.participants.filter { $0.shareAmount > 0 }
            : draft.participants
        let linkedCount = relevantParticipants.filter { participant in
            guard let identifier = participant.contactIdentifier else { return false }
            return !identifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }.count
        return linkedCount == relevantParticipants.count && linkedCount > 0
            ? "Semua orang sudah terhubung. Catatan siap disimpan ke Riwayat."
            : "Hubungkan setiap orang ke Kontak agar catatan dapat disimpan ke Riwayat."
    }

    func load() async {
        do {
            if let loaded = try await repository.draft(id: draftID) {
                var normalized = loaded
                if normalized.flow == .splitBill, normalized.userShareAmount == nil {
                    normalized.userShareAmount = max(
                        0,
                        normalized.totalAmount - normalized.participants.reduce(0) { $0 + max(0, $1.shareAmount) }
                    )
                }
                draft = normalized
                if loaded.userShareAmount == nil, loaded.flow == .splitBill {
                    scheduleAutosave()
                }
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
        let initialShare: Int64 = draft.splitMethod == .custom ? 0 : 1
        draft.participants.append(TransactionParticipant(name: clean, shareAmount: initialShare))
        newParticipantName = ""
        recalculateSplits(in: &draft)
        self.draft = draft
        scheduleAutosave()
    }

    func removeParticipant(at offsets: IndexSet) {
        guard var draft else { return }
        for index in offsets.sorted(by: >) {
            draft.participants.remove(at: index)
        }
        recalculateSplits(in: &draft)
        self.draft = draft
        scheduleAutosave()
    }

    func recalculateSplits(in draft: inout TransactionDraft) {
        guard draft.flow == .splitBill, draft.totalAmount > 0 else { return }
        if draft.splitMethod == .equal || draft.splitMethod == nil {
            let activeIndices = draft.participants.indices.filter { draft.participants[$0].shareAmount > 0 }
            let userIsIncluded = (draft.userShareAmount ?? 1) > 0
            let memberCount = activeIndices.count + (userIsIncluded ? 1 : 0)
            guard memberCount > 0 else {
                draft.userShareAmount = 0
                return
            }
            let shares = SplitCalculationEngine.calculateEqualShares(
                totalAmount: draft.totalAmount,
                participantCount: memberCount
            )
            var shareIndex = 0
            if userIsIncluded {
                draft.userShareAmount = shares[shareIndex]
                shareIndex += 1
            } else {
                draft.userShareAmount = 0
            }
            for index in draft.participants.indices {
                if activeIndices.contains(index) {
                    draft.participants[index].shareAmount = shares[shareIndex]
                    shareIndex += 1
                } else {
                    draft.participants[index].shareAmount = 0
                }
            }
        }
    }

    func updateSplitMethod(_ method: SplitMethod) {
        guard var draft else { return }
        draft.splitMethod = method
        if method == .equal { recalculateSplits(in: &draft) }
        self.draft = draft
        scheduleAutosave()
    }

    func toggleUserIncluded() {
        guard var draft, draft.flow == .splitBill, draft.splitMethod != .custom else { return }
        draft.userShareAmount = userShareAmount > 0 ? 0 : 1
        recalculateSplits(in: &draft)
        self.draft = draft
        scheduleAutosave()
    }

    func toggleParticipantIncluded(index: Int) {
        guard var draft,
              draft.flow == .splitBill,
              draft.splitMethod != .custom,
              draft.participants.indices.contains(index) else { return }
        draft.participants[index].shareAmount = draft.participants[index].shareAmount > 0 ? 0 : 1
        recalculateSplits(in: &draft)
        self.draft = draft
        scheduleAutosave()
    }

    func updateUserShare(_ amount: Int64) {
        draft?.userShareAmount = max(0, amount)
        scheduleAutosave()
    }

    func updateParticipantName(index: Int, name: String) {
        guard var draft, draft.participants.indices.contains(index) else { return }
        draft.participants[index].name = name
        draft.participants[index].contactIdentifier = nil
        self.draft = draft
        scheduleAutosave()
    }

    func updateParticipantShare(index: Int, amount: Int64) {
        guard var draft, draft.participants.indices.contains(index) else { return }
        draft.participants[index].shareAmount = max(0, amount)
        self.draft = draft
        scheduleAutosave()
    }

    func updateParticipantNotes(index: Int, notes: String) {
        guard var draft, draft.participants.indices.contains(index) else { return }
        let cleaned = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.participants[index].notes = cleaned.isEmpty ? nil : cleaned
        self.draft = draft
        scheduleAutosave()
    }

    func updateParticipantContact(index: Int, candidate: ContactMatchCandidate) {
        guard var draft, draft.participants.indices.contains(index) else { return }
        draft.participants[index].name = candidate.fullName
        draft.participants[index].contactIdentifier = candidate.id
        self.draft = draft
        scheduleAutosave()
    }

    func updateTransactionDate(_ date: Date) {
        draft?.transactionDate = date
        scheduleAutosave()
    }

    func updateTotalAmount(_ amount: Int64) {
        guard var draft else { return }
        draft.totalAmount = amount
        recalculateSplits(in: &draft)
        self.draft = draft
        scheduleAutosave()
    }

    func updateTitle(_ title: String) {
        draft?.title = title
        scheduleAutosave()
    }

    func updateType(_ type: TransactionType) {
        draft?.type = type
        scheduleAutosave()
    }

    func updateNotes(_ notes: String) {
        draft?.notes = notes.isEmpty ? nil : notes
        scheduleAutosave()
    }

    func flushPendingEdits() async {
        let pendingSave = autosaveTask
        autosaveTask = nil
        await pendingSave?.value
        await persistCurrentDraft()
    }

    private func persistCurrentDraft() async {
        guard !didFinish else { return }
        guard var draft else { return }
        draft.status = .needsReview
        isAutosaving = true
        autosaveErrorMessage = nil
        defer { isAutosaving = false }
        do {
            try await repository.saveDraft(draft)
        } catch {
            autosaveErrorMessage = "Perubahan belum berhasil disimpan otomatis. Coba ubah kembali atau buka ulang halaman ini."
        }
    }

    private func scheduleAutosave() {
        let previousSave = autosaveTask
        autosaveTask = Task { [weak self] in
            await previousSave?.value
            guard let self else { return }
            await self.persistCurrentDraft()
        }
    }

    func showValidationMessage() {
        guard !validationMessages.isEmpty else { return }
        errorMessage = "Lengkapi data berikut sebelum menyimpan:\n\n• " + validationMessages.joined(separator: "\n• ")
    }

    func save() async {
        guard !isSaving else { return }
        await flushPendingEdits()
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
        let pendingSave = autosaveTask
        autosaveTask = nil
        await pendingSave?.value
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
