import Foundation

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

    func pendingDraftCount() -> Int {
        drafts.values.filter { $0.status == .needsReview }.count
    }

    func draft(id: UUID) -> TransactionDraft? { drafts[id] }

    func saveDraft(_ draft: TransactionDraft) {
        drafts[draft.id] = draft
        notifyChange()
    }

    func deleteDraft(id: UUID) {
        guard drafts.removeValue(forKey: id) != nil else { return }
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

    func deleteLedgerEntry(id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries.remove(at: index)
        notifyChange()
    }

    func linkedContactIdentifiers() -> [String] {
        Array(Set(entries.compactMap(\.contactIdentifier))).sorted()
    }

    func linkPerson(personID: String, to contact: ContactRef) throws {
        guard entries.contains(where: { $0.personID == personID }) else {
            throw RepositoryError.personNotFound
        }
        for index in entries.indices
        where entries[index].personID == personID || entries[index].personID == contact.identifier {
            entries[index].personID = contact.identifier
            entries[index].personName = contact.displayName
            entries[index].contactIdentifier = contact.identifier
        }
        notifyChange()
    }

    func recordPayment(for person: PersonLedgerSummary, amount: Int64, date: Date, notes: String?) throws {
        guard amount > 0 else { throw RepositoryError.invalidAmount }
        let personEntries = entries.filter { $0.personID == person.id }
        let contactIdentifier = personEntries.lazy.compactMap(\.contactIdentifier).first
        guard personEntries.isEmpty || contactIdentifier != nil else {
            throw RepositoryError.personNotLinked
        }
        let latestBalance = personEntries.reduce(Int64(0)) { $0 + $1.balanceDelta }
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
            notes: notes,
            contactIdentifier: contactIdentifier
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
            sourceDraftID: draft.id,
            contactIdentifier: participant.contactIdentifier
        )
    }
}
