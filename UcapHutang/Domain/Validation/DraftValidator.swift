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
        guard !draft.participants.isEmpty else {
            throw DraftValidationError.invalid("Nama orang yang terkait belum diisi.")
        }
        let names = draft.participants.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard names.allSatisfy({ !$0.isEmpty }) else {
            throw DraftValidationError.invalid("Ada nama orang yang masih kosong.")
        }
        let everyParticipantIsLinked = draft.participants.allSatisfy { participant in
            let identifier = participant.contactIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return !identifier.isEmpty
        }
        guard everyParticipantIsLinked else {
            throw DraftValidationError.invalid("Hubungkan setiap orang ke kontak sebelum menyimpan.")
        }
        guard Set(names.map { $0.lowercased() }).count == names.count else {
            throw DraftValidationError.invalid("Ada nama orang yang sama dalam satu transaksi.")
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
            guard draft.participants.allSatisfy({ $0.shareAmount > 0 }) else {
                throw DraftValidationError.invalid("Nominal bagian setiap teman harus lebih dari Rp0.")
            }
            let allocated = draft.participants.reduce(Int64(0)) { partial, participant in
                let (sum, overflow) = partial.addingReportingOverflow(participant.shareAmount)
                return overflow ? Int64.max : sum
            }
            guard allocated <= draft.totalAmount else {
                throw DraftValidationError.invalid("Total bagian teman melebihi nominal transaksi.")
            }
        }
    }
}
