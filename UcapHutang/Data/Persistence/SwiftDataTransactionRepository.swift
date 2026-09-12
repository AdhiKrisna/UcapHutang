import Foundation
import SwiftData

@MainActor
final class SwiftDataTransactionRepository: TransactionRepository {
    private let modelContainer: ModelContainer
    private var context: ModelContext { modelContainer.mainContext }

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    private func notifyChange() {
        NotificationCenter.default.post(name: .transactionRepositoryDidChange, object: nil)
    }

    func draftsNeedingReview() async throws -> [TransactionDraft] {
        let statusNeedsReview = DraftStatus.needsReview.rawValue
        let descriptor = FetchDescriptor<SDTransactionDraft>(
            predicate: #Predicate { $0.statusRaw == statusNeedsReview },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor).map(Self.toDomain)
    }

    func pendingDraftCount() async throws -> Int {
        let statusNeedsReview = DraftStatus.needsReview.rawValue
        let descriptor = FetchDescriptor<SDTransactionDraft>(
            predicate: #Predicate { $0.statusRaw == statusNeedsReview }
        )
        return try context.fetchCount(descriptor)
    }

    func draft(id: UUID) async throws -> TransactionDraft? {
        try fetchDraftEntity(id: id).map(Self.toDomain)
    }

    func saveDraft(_ draft: TransactionDraft) async throws {
        if let existing = try fetchDraftEntity(id: draft.id) {
            apply(draft, to: existing)
        } else {
            context.insert(makeDraftEntity(from: draft))
        }
        try context.save()
        notifyChange()
    }

    func deleteDraft(id: UUID) async throws {
        guard let existing = try fetchDraftEntity(id: id) else { return }
        for participant in existing.participants {
            context.delete(participant)
        }
        context.delete(existing)
        try context.save()
        notifyChange()
    }

    func confirmDraft(_ input: TransactionDraft) async throws {
        try DraftValidator.validateForConfirmation(input)
        let inputID = input.id

        // 1. Already confirmed → idempotent no-op.
        let existingDraft = try fetchDraftEntity(id: inputID)
        if let existingDraft, existingDraft.statusRaw == DraftStatus.confirmed.rawValue {
            return
        }

        // 2. Ledger already written for this draft → only fix the status.
        let ledgerDescriptor = FetchDescriptor<SDLedgerEntry>(predicate: #Predicate { $0.sourceDraftID == inputID })
        guard try context.fetch(ledgerDescriptor).isEmpty else {
            if let existingDraft {
                existingDraft.statusRaw = DraftStatus.confirmed.rawValue
                try context.save()
            }
            return
        }

        var draft = input
        draft.status = .confirmed
        if let existingDraft {
            apply(draft, to: existingDraft)
        } else {
            context.insert(makeDraftEntity(from: draft))
        }

        switch draft.type {
        case .unknown:
            throw RepositoryError.invalidAmount
        case .hutang, .piutang:
            guard let participant = draft.participants.first else { break }
            let magnitude = draft.totalAmount
            let delta = draft.type == .piutang ? magnitude : -magnitude
            context.insert(makeCharge(draft: draft, participant: participant, delta: delta))
        case .splitBill:
            for participant in draft.participants {
                context.insert(makeCharge(draft: draft, participant: participant, delta: participant.shareAmount))
            }
        }

        // Atomic commit for draft status + ledger entries.
        try context.save()
        notifyChange()
    }

    func ledgerEntries() async throws -> [LedgerEntry] {
        let descriptor = FetchDescriptor<SDLedgerEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        return try context.fetch(descriptor).map(Self.toDomain)
    }

    func linkedContactIdentifiers() async throws -> [String] {
        let entries = try context.fetch(FetchDescriptor<SDLedgerEntry>())
        return Array(Set(entries.compactMap(\.contactIdentifier))).sorted()
    }

    func linkPerson(personID: String, to contact: ContactRef) async throws {
        let oldID = personID
        let newID = contact.identifier
        let descriptor = FetchDescriptor<SDLedgerEntry>(
            predicate: #Predicate { $0.personID == oldID || $0.personID == newID }
        )
        let affected = try context.fetch(descriptor)
        guard affected.contains(where: { $0.personID == oldID }) else {
            throw RepositoryError.personNotFound
        }
        for entry in affected {
            entry.personID = newID
            entry.personName = contact.displayName
            entry.contactIdentifier = newID
        }
        try context.save()
        notifyChange()
    }

    func recordPayment(for person: PersonLedgerSummary, amount: Int64, date: Date, notes: String?) async throws {
        guard amount > 0 else { throw RepositoryError.invalidAmount }
        let personID = person.id
        let personEntries = try context.fetch(
            FetchDescriptor<SDLedgerEntry>(predicate: #Predicate { $0.personID == personID })
        )
        let contactIdentifier = personEntries.lazy.compactMap(\.contactIdentifier).first
        guard personEntries.isEmpty || contactIdentifier != nil else {
            throw RepositoryError.personNotLinked
        }
        let latestBalance = personEntries.reduce(Int64(0)) { $0 + $1.balanceDelta }
        guard latestBalance != 0 else { throw RepositoryError.noOutstandingBalance }
        guard amount <= abs(latestBalance) else { throw RepositoryError.paymentExceedsBalance }
        let delta = latestBalance > 0 ? -amount : amount
        context.insert(SDLedgerEntry(
            id: UUID(),
            personID: person.id,
            personName: person.displayName,
            kindRaw: LedgerEntryKind.payment.rawValue,
            balanceDelta: delta,
            date: date,
            title: "Bayar",
            notes: notes,
            contactIdentifier: contactIdentifier
        ))
        try context.save()
        notifyChange()
    }

    // MARK: - Mapping helpers

    private func fetchDraftEntity(id: UUID) throws -> SDTransactionDraft? {
        let draftID = id
        let descriptor = FetchDescriptor<SDTransactionDraft>(predicate: #Predicate { $0.id == draftID })
        return try context.fetch(descriptor).first
    }

    private func apply(_ draft: TransactionDraft, to entity: SDTransactionDraft) {
        entity.statusRaw = draft.status.rawValue
        entity.flowRaw = draft.flow.rawValue
        entity.typeRaw = draft.type.rawValue
        entity.transactionDate = draft.transactionDate
        entity.title = draft.title
        entity.totalAmount = draft.totalAmount
        entity.splitMethodRaw = draft.splitMethod?.rawValue
        entity.includesUser = draft.includesUser
        entity.notes = draft.notes
        entity.rawTranscript = draft.rawTranscript
        entity.rawModelResponse = draft.rawModelResponse
        entity.reviewWarningsRaw = draft.reviewWarnings
        for participant in entity.participants {
            context.delete(participant)
        }
        entity.participants = makeParticipantEntities(from: draft)
    }

    private func makeDraftEntity(from draft: TransactionDraft) -> SDTransactionDraft {
        SDTransactionDraft(
            id: draft.id,
            statusRaw: draft.status.rawValue,
            flowRaw: draft.flow.rawValue,
            typeRaw: draft.type.rawValue,
            transactionDate: draft.transactionDate,
            title: draft.title,
            totalAmount: draft.totalAmount,
            splitMethodRaw: draft.splitMethod?.rawValue,
            includesUser: draft.includesUser,
            notes: draft.notes,
            rawTranscript: draft.rawTranscript,
            rawModelResponse: draft.rawModelResponse,
            reviewWarningsRaw: draft.reviewWarnings,
            createdAt: draft.createdAt,
            participants: makeParticipantEntities(from: draft)
        )
    }

    private func makeParticipantEntities(from draft: TransactionDraft) -> [SDTransactionParticipant] {
        draft.participants.map {
            SDTransactionParticipant(
                id: $0.id,
                name: $0.name,
                contactIdentifier: $0.contactIdentifier,
                shareAmount: $0.shareAmount,
                itemTitle: $0.itemTitle,
                notes: $0.notes
            )
        }
    }

    private func makeCharge(draft: TransactionDraft, participant: TransactionParticipant, delta: Int64) -> SDLedgerEntry {
        SDLedgerEntry(
            id: UUID(),
            personID: participant.contactIdentifier ?? participant.name.lowercased(),
            personName: participant.name,
            kindRaw: LedgerEntryKind.charge.rawValue,
            balanceDelta: delta,
            date: draft.transactionDate,
            title: draft.title,
            notes: draft.notes,
            sourceDraftID: draft.id,
            contactIdentifier: participant.contactIdentifier
        )
    }

    private static func toDomain(_ sd: SDTransactionDraft) -> TransactionDraft {
        TransactionDraft(
            id: sd.id,
            status: DraftStatus(rawValue: sd.statusRaw) ?? .needsReview,
            flow: CaptureFlow(rawValue: sd.flowRaw) ?? .personal,
            type: TransactionType(rawValue: sd.typeRaw) ?? .hutang,
            transactionDate: sd.transactionDate,
            title: sd.title,
            totalAmount: sd.totalAmount,
            splitMethod: sd.splitMethodRaw.flatMap(SplitMethod.init(rawValue:)),
            includesUser: sd.includesUser,
            participants: sd.participants.map {
                TransactionParticipant(
                    id: $0.id,
                    name: $0.name,
                    contactIdentifier: $0.contactIdentifier,
                    shareAmount: $0.shareAmount,
                    itemTitle: $0.itemTitle,
                    notes: $0.notes
                )
            },
            notes: sd.notes,
            rawTranscript: sd.rawTranscript,
            rawModelResponse: sd.rawModelResponse,
            reviewWarnings: sd.reviewWarningsRaw,
            createdAt: sd.createdAt
        )
    }

    private static func toDomain(_ sd: SDLedgerEntry) -> LedgerEntry {
        LedgerEntry(
            id: sd.id,
            personID: sd.personID,
            personName: sd.personName,
            kind: LedgerEntryKind(rawValue: sd.kindRaw) ?? .charge,
            balanceDelta: sd.balanceDelta,
            date: sd.date,
            title: sd.title,
            notes: sd.notes,
            sourceDraftID: sd.sourceDraftID,
            contactIdentifier: sd.contactIdentifier
        )
    }
}
