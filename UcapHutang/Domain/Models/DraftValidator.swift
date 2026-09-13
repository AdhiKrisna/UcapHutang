import Foundation

enum DraftValidationError: LocalizedError, Equatable {
    case invalid(String)

    var errorDescription: String? {
        switch self {
        case .invalid(let message): message
        }
    }
}

enum DraftValidator {
    static func validateForConfirmation(_ draft: TransactionDraft) throws {
        guard draft.totalAmount > 0 else {
            throw DraftValidationError.invalid("Nominal transaksi harus lebih dari Rp0.")
        }
        guard !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DraftValidationError.invalid("Judul transaksi belum diisi.")
        }
        let relevantParticipants = draft.flow == .splitBill
            ? draft.participants.filter { $0.shareAmount > 0 }
            : draft.participants
        guard !relevantParticipants.isEmpty else {
            throw DraftValidationError.invalid("Nama orang yang terkait belum diisi.")
        }
        let names = relevantParticipants.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard names.allSatisfy({ !$0.isEmpty }) else {
            throw DraftValidationError.invalid("Ada nama orang yang masih kosong.")
        }
        guard Set(names.map { $0.lowercased() }).count == names.count else {
            throw DraftValidationError.invalid("Ada nama orang yang sama dalam satu transaksi.")
        }
        guard relevantParticipants.allSatisfy({
            guard let identifier = $0.contactIdentifier else { return false }
            return !identifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }) else {
            throw DraftValidationError.invalid("Hubungkan setiap orang ke Kontak sebelum menyimpan.")
        }

        switch draft.flow {
        case .personal:
            guard draft.type == .hutang || draft.type == .piutang else {
                throw DraftValidationError.invalid("Pilih siapa yang berutang sebelum menyimpan.")
            }
            guard draft.participants.count == 1 else {
                throw DraftValidationError.invalid("Utang atau piutang pribadi hanya boleh melibatkan satu orang.")
            }
        case .splitBill:
            guard draft.type == .splitBill else {
                throw DraftValidationError.invalid("Jenis transaksi split bill tidak valid.")
            }
            let allocated = relevantParticipants.reduce(max(0, draft.userShareAmount ?? 0)) { partial, participant in
                let (sum, overflow) = partial.addingReportingOverflow(participant.shareAmount)
                return overflow ? Int64.max : sum
            }
            guard allocated == draft.totalAmount else {
                throw DraftValidationError.invalid("Jumlah pembagian harus sama dengan total transaksi.")
            }
        }
    }
}
