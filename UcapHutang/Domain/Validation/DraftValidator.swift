import Foundation

enum DraftValidationError: LocalizedError, Equatable {
    case invalid(String)

    var errorDescription: String? {
        switch self {
        case .invalid(let message): message
        }
    }
}

enum DraftValidationIssue: Equatable, Sendable {
    case amountNotPositive
    case titleMissing
    case directionMissing
    case participantsMissing(flow: CaptureFlow)
    case participantNameMissing(participantID: UUID)
    case participantNameGeneric(participantID: UUID, label: String)
    case participantNotLinked(participantID: UUID)
    case duplicateParticipant
    case personalRequiresExactlyOne
    case splitTypeInvalid
    case shareNotPositive(participantID: UUID, name: String)
    case sharesExceedTotal
    case sharesDoNotMatchTotal

    var message: String {
        switch self {
        case .amountNotPositive:
            "Isi nominal transaksi dengan angka lebih dari Rp0."
        case .titleMissing:
            "Isi deskripsi transaksi, misalnya “Kopi” atau “Makan malam”."
        case .directionMissing:
            "Pilih siapa yang berutang: kamu atau orang tersebut."
        case .participantsMissing(let flow):
            flow == .personal
                ? "Pilih orang yang terkait dengan transaksi ini."
                : "Tambahkan minimal satu teman yang ikut split bill."
        case .participantNameMissing:
            "Ada nama orang yang masih kosong."
        case .participantNameGeneric(_, let label):
            "Ganti nama \(label) dengan nama yang bisa kamu kenali."
        case .participantNotLinked:
            "Hubungkan setiap orang ke kontak sebelum menyimpan."
        case .duplicateParticipant:
            "Ada orang yang sama dalam satu transaksi. Hapus atau ganti salah satunya."
        case .personalRequiresExactlyOne:
            "Utang atau piutang pribadi hanya boleh melibatkan satu orang."
        case .splitTypeInvalid:
            "Jenis transaksi split bill tidak valid."
        case .shareNotPositive(_, let name):
            "Isi nominal bagian untuk \(name)."
        case .sharesExceedTotal:
            "Total bagian teman melebihi nominal transaksi."
        case .sharesDoNotMatchTotal:
            "Pembagian nominal belum sesuai dengan total transaksi."
        }
    }
}

enum DraftValidator {
    /// Throws the first issue so repositories can refuse to write invalid drafts.
    static func validateForConfirmation(_ draft: TransactionDraft) throws {
        if let firstIssue = issues(for: draft).first {
            throw DraftValidationError.invalid(firstIssue.message)
        }
    }

    /// Every problem that blocks confirmation, in display order.
    static func issues(for draft: TransactionDraft) -> [DraftValidationIssue] {
        var issues: [DraftValidationIssue] = []

        if draft.totalAmount <= 0 {
            issues.append(.amountNotPositive)
        }
        if draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.titleMissing)
        }
        if draft.participants.isEmpty {
            issues.append(.participantsMissing(flow: draft.flow))
        }
        for participant in draft.participants
        where participant.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.participantNameMissing(participantID: participant.id))
        }
        for (index, participant) in draft.participants.enumerated() where isGenericName(participant.name) {
            let label = draft.flow == .personal ? "orang terkait" : "peserta ke-\(index + 1)"
            issues.append(.participantNameGeneric(participantID: participant.id, label: label))
        }
        for participant in draft.participants where !isLinked(participant) {
            issues.append(.participantNotLinked(participantID: participant.id))
        }
        let identities = draft.participants.map(identityKey).filter { $0 != "name:" }
        if Set(identities).count != identities.count {
            issues.append(.duplicateParticipant)
        }

        switch draft.flow {
        case .personal:
            if draft.type != .hutang && draft.type != .piutang {
                issues.append(.directionMissing)
            }
            if draft.participants.count > 1 {
                issues.append(.personalRequiresExactlyOne)
            }
        case .splitBill:
            if draft.type != .splitBill {
                issues.append(.splitTypeInvalid)
            }
            var hasShareProblem = false
            for participant in draft.participants where participant.shareAmount <= 0 {
                let name = participant.name.trimmingCharacters(in: .whitespacesAndNewlines)
                issues.append(.shareNotPositive(participantID: participant.id, name: name))
                hasShareProblem = true
            }
            let shares = draft.participants.map(\.shareAmount)
            if let allocated = SplitCalculationEngine.customTotal(shares) {
                if allocated > draft.totalAmount {
                    issues.append(.sharesExceedTotal)
                    hasShareProblem = true
                }
            } else {
                issues.append(.sharesExceedTotal)
                hasShareProblem = true
            }
            if !hasShareProblem && !draft.participants.isEmpty {
                let sharesMatch: Bool
                if draft.splitMethod == .custom {
                    sharesMatch = SplitCalculationEngine.customTotal(shares) == draft.totalAmount
                } else {
                    let expected = SplitCalculationEngine.shares(
                        total: draft.totalAmount,
                        friendCount: draft.participants.count,
                        includesUser: draft.includesUser
                    )
                    sharesMatch = shares == expected
                }
                if !sharesMatch {
                    issues.append(.sharesDoNotMatchTotal)
                }
            }
        }

        return issues
    }

    /// Placeholder names that do not identify a real person (from PR #3).
    private static let genericNames: Set<String> = ["teman", "teman 1", "teman 2", "orang", "orang a", "orang b"]

    private static func isGenericName(_ name: String) -> Bool {
        genericNames.contains(name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }

    private static func isLinked(_ participant: TransactionParticipant) -> Bool {
        let identifier = participant.contactIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !identifier.isEmpty
    }

    private static func identityKey(_ participant: TransactionParticipant) -> String {
        if isLinked(participant), let identifier = participant.contactIdentifier {
            return "contact:" + identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return "name:" + participant.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
