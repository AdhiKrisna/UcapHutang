import Foundation
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
        for index in offsets.sorted(by: >) {
            draft.participants.remove(at: index)
        }
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

    func updateParticipantNotes(index: Int, notes: String) {
        guard var draft, draft.participants.indices.contains(index) else { return }
        let cleaned = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.participants[index].notes = cleaned.isEmpty ? nil : cleaned
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
            try await repository.deleteDraft(id: draftID)
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
