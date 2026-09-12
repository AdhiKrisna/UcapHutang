import Foundation

/// Stage 3: structured output → a `needsReview` draft. Pure and deterministic.
enum DraftMapper {
    static func makeDraft(flow: CaptureFlow, transcript: String, result: ExtractionResult, createdAt: Date) -> TransactionDraft {
        switch result.output {
        case .personal(let personal):
            let type: TransactionType
            switch personal.direction {
            case .hutang: type = .hutang
            case .piutang: type = .piutang
            case .unknown: type = .unknown
            }
            let amount = personal.amount ?? 0
            return TransactionDraft(
                status: .needsReview,
                flow: .personal,
                type: type,
                transactionDate: result.resolvedDate,
                title: personal.title ?? "",
                totalAmount: amount,
                splitMethod: nil,
                includesUser: true,
                participants: [
                    TransactionParticipant(name: personal.person ?? "", contactIdentifier: nil, shareAmount: amount)
                ],
                notes: personal.notes,
                rawTranscript: transcript,
                rawModelResponse: result.rawModelResponse,
                reviewWarnings: result.warnings,
                createdAt: createdAt
            )

        case .split(let split):
            let method: SplitMethod = split.basis == .custom ? .custom : .equal
            var participants = split.receivables.map { receivable in
                TransactionParticipant(
                    name: receivable.person,
                    contactIdentifier: nil,
                    shareAmount: receivable.amount ?? 0,
                    itemTitle: receivable.item
                )
            }
            var totalAmount = split.totalAmount ?? 0

            switch method {
            case .equal:
                let shares = SplitCalculationEngine.shares(
                    total: totalAmount,
                    friendCount: participants.count,
                    includesUser: true
                )
                for (index, share) in shares.enumerated() {
                    participants[index].shareAmount = share
                }
            case .custom:
                let everyAmountPresent = !split.receivables.isEmpty
                    && split.receivables.allSatisfy { ($0.amount ?? 0) > 0 }
                if everyAmountPresent,
                   let sum = SplitCalculationEngine.customTotal(participants.map(\.shareAmount)) {
                    totalAmount = sum
                }
            }

            return TransactionDraft(
                status: .needsReview,
                flow: .splitBill,
                type: .splitBill,
                transactionDate: result.resolvedDate,
                title: split.title ?? "",
                totalAmount: totalAmount,
                splitMethod: method,
                includesUser: true,
                participants: participants,
                notes: split.notes,
                rawTranscript: transcript,
                rawModelResponse: result.rawModelResponse,
                reviewWarnings: result.warnings,
                createdAt: createdAt
            )
        }
    }
}
