import Foundation

extension Notification.Name {
    static let transactionRepositoryDidChange = Notification.Name("transactionRepositoryDidChange")
}

protocol TransactionRepository: Sendable {
    func draftsNeedingReview() async throws -> [TransactionDraft]
    func draft(id: UUID) async throws -> TransactionDraft?
    func saveDraft(_ draft: TransactionDraft) async throws
    func discardDraft(id: UUID) async throws
    func confirmDraft(_ draft: TransactionDraft) async throws
    func ledgerEntries() async throws -> [LedgerEntry]
    func recordPayment(for person: PersonLedgerSummary, amount: Int64, date: Date, notes: String?) async throws
}

enum RepositoryError: LocalizedError {
    case invalidAmount
    case paymentExceedsBalance
    case noOutstandingBalance

    var errorDescription: String? {
        switch self {
        case .invalidAmount: "Nominal harus lebih dari nol."
        case .paymentExceedsBalance: "Pembayaran tidak boleh melewati saldo saat ini."
        case .noOutstandingBalance: "Saldo orang ini sudah lunas atau tidak lagi tersedia. Muat ulang Riwayat."
        }
    }
}

actor InMemoryTransactionRepository: TransactionRepository {
    private var drafts: [UUID: TransactionDraft]
    private var entries: [LedgerEntry]

    init(seedDrafts: [TransactionDraft] = [], seedEntries: [LedgerEntry] = []) {
        drafts = Dictionary(uniqueKeysWithValues: seedDrafts.map { ($0.id, $0) })
        entries = seedEntries
    }

    func draftsNeedingReview() -> [TransactionDraft] {
        drafts.values
            .filter { $0.status == .needsReview }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func draft(id: UUID) -> TransactionDraft? { drafts[id] }

    func saveDraft(_ draft: TransactionDraft) {
        drafts[draft.id] = draft
        notifyChange()
    }

    func discardDraft(id: UUID) {
        guard var draft = drafts[id] else { return }
        draft.status = .discarded
        drafts[id] = draft
        notifyChange()
    }

    func confirmDraft(_ input: TransactionDraft) throws {
        try DraftValidator.validateForConfirmation(input)
        if drafts[input.id]?.status == .confirmed { return }
        if entries.contains(where: { $0.sourceDraftID == input.id }) {
            drafts[input.id]?.status = .confirmed
            return
        }
        var draft = input
        draft.status = .confirmed
        drafts[draft.id] = draft

        switch draft.type {
        case .unknown:
            throw RepositoryError.invalidAmount
        case .hutang, .piutang:
            guard let participant = draft.participants.first else { return }
            let magnitude = draft.totalAmount
            let delta = draft.type == .piutang ? magnitude : -magnitude
            entries.append(makeCharge(draft: draft, participant: participant, delta: delta))
        case .splitBill:
            for participant in draft.participants {
                entries.append(makeCharge(draft: draft, participant: participant, delta: participant.shareAmount))
            }
        }
        notifyChange()
    }

    func ledgerEntries() -> [LedgerEntry] { entries.sorted { $0.date > $1.date } }

    func recordPayment(for person: PersonLedgerSummary, amount: Int64, date: Date, notes: String?) throws {
        guard amount > 0 else { throw RepositoryError.invalidAmount }
        let latestBalance = entries.filter { $0.personID == person.id }.reduce(Int64(0)) { $0 + $1.balanceDelta }
        guard latestBalance != 0 else { throw RepositoryError.noOutstandingBalance }
        guard amount <= abs(latestBalance) else { throw RepositoryError.paymentExceedsBalance }
        let delta = latestBalance > 0 ? -amount : amount
        entries.append(LedgerEntry(
            personID: person.id,
            personName: person.displayName,
            kind: .payment,
            balanceDelta: delta,
            date: date,
            title: "Bayar",
            notes: notes
        ))
        notifyChange()
    }

    private func notifyChange() {
        Task { @MainActor in
            NotificationCenter.default.post(name: .transactionRepositoryDidChange, object: nil)
        }
    }

    private func makeCharge(draft: TransactionDraft, participant: TransactionParticipant, delta: Int64) -> LedgerEntry {
        LedgerEntry(
            personID: participant.contactIdentifier ?? participant.name.lowercased(),
            personName: participant.name,
            kind: .charge,
            balanceDelta: delta,
            date: draft.transactionDate,
            title: draft.title,
            notes: draft.notes,
            sourceDraftID: draft.id
        )
    }
}
