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
        let sds = try context.fetch(descriptor)
        return sds.map(Self.toDomain)
    }

    func draft(id: UUID) async throws -> TransactionDraft? {
        let descriptor = FetchDescriptor<SDTransactionDraft>(
            predicate: #Predicate { $0.id == id }
        )
        guard let sd = try context.fetch(descriptor).first else { return nil }
        return Self.toDomain(sd)
    }

    func saveDraft(_ draft: TransactionDraft) async throws {
        let descriptor = FetchDescriptor<SDTransactionDraft>(predicate: #Predicate { $0.id == draft.id })
        if let existing = try context.fetch(descriptor).first {
            update(existing, from: draft)
        } else {
            let sd = SDTransactionDraft(
                id: draft.id,
                statusRaw: draft.status.rawValue,
                flowRaw: draft.flow.rawValue,
                typeRaw: draft.type.rawValue,
                transactionDate: draft.transactionDate,
                title: draft.title,
                totalAmount: draft.totalAmount,
                splitMethodRaw: draft.splitMethod?.rawValue,
                userShareAmount: draft.userShareAmount,
                notes: draft.notes,
                rawTranscript: draft.rawTranscript,
                rawModelResponse: draft.rawModelResponse,
                reviewWarningsRaw: draft.reviewWarnings,
                createdAt: draft.createdAt,
                participants: draft.participants.map { SDTransactionParticipant(id: $0.id, name: $0.name, contactIdentifier: $0.contactIdentifier, shareAmount: $0.shareAmount, itemTitle: $0.itemTitle, notes: $0.notes) }
            )
            context.insert(sd)
        }
        try context.save()
        notifyChange()
    }

    func discardDraft(id: UUID) async throws {
        let descriptor = FetchDescriptor<SDTransactionDraft>(predicate: #Predicate { $0.id == id })
        if let existing = try context.fetch(descriptor).first {
            existing.statusRaw = DraftStatus.discarded.rawValue
            try context.save()
            notifyChange()
        }
    }

    func confirmDraft(_ input: TransactionDraft) async throws {
        try DraftValidator.validateForConfirmation(input)
        let inputID = input.id

        // 1. Cek apakah draft sudah berstatus confirmed
        let draftDescriptor = FetchDescriptor<SDTransactionDraft>(predicate: #Predicate { $0.id == inputID })
        let existingDraft = try context.fetch(draftDescriptor).first
        if let existingDraft, existingDraft.statusRaw == DraftStatus.confirmed.rawValue {
            return
        }

        // 2. Cek apakah sudah ada ledger entry yang tercipta dari sourceDraftID ini
        let ledgerDescriptor = FetchDescriptor<SDLedgerEntry>(predicate: #Predicate { $0.sourceDraftID == inputID })
        let existingLedgers = try context.fetch(ledgerDescriptor)
        guard existingLedgers.isEmpty else {
            // Sudah ada ledger untuk draft ini, tandai draft confirmed jika belum
            if let existingDraft {
                existingDraft.statusRaw = DraftStatus.confirmed.rawValue
                try context.save()
            }
            return
        }

        var draft = input
        draft.status = .confirmed

        // Mutasi atau insert draft tanpa commit save() terpisah
        if let existing = existingDraft {
            update(existing, from: draft)
        } else {
            let sd = SDTransactionDraft(
                id: draft.id,
                statusRaw: draft.status.rawValue,
                flowRaw: draft.flow.rawValue,
                typeRaw: draft.type.rawValue,
                transactionDate: draft.transactionDate,
                title: draft.title,
                totalAmount: draft.totalAmount,
                splitMethodRaw: draft.splitMethod?.rawValue,
                userShareAmount: draft.userShareAmount,
                notes: draft.notes,
                rawTranscript: draft.rawTranscript,
                rawModelResponse: draft.rawModelResponse,
                reviewWarningsRaw: draft.reviewWarnings,
                createdAt: draft.createdAt,
                participants: draft.participants.map { SDTransactionParticipant(id: $0.id, name: $0.name, contactIdentifier: $0.contactIdentifier, shareAmount: $0.shareAmount, itemTitle: $0.itemTitle, notes: $0.notes) }
            )
            context.insert(sd)
        }

        // Buat ledger entries
        switch draft.type {
        case .unknown:
            throw RepositoryError.invalidAmount
        case .hutang, .piutang:
            guard let participant = draft.participants.first else { break }
            let magnitude = draft.totalAmount
            let delta = draft.type == .piutang ? magnitude : -magnitude
            let entry = makeCharge(draft: draft, participant: participant, delta: delta)
            context.insert(entry)
        case .splitBill:
            for participant in draft.participants where participant.shareAmount > 0 {
                let entry = makeCharge(draft: draft, participant: participant, delta: participant.shareAmount)
                context.insert(entry)
            }
        }

        // Atomic commit untuk draft status + ledger entries
        try context.save()
        notifyChange()
    }

    func ledgerEntries() async throws -> [LedgerEntry] {
        let descriptor = FetchDescriptor<SDLedgerEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        let sds = try context.fetch(descriptor)
        return sds.map(Self.toDomain)
    }

    func recordPayment(for person: PersonLedgerSummary, amount: Int64, date: Date, notes: String?) async throws {
        guard amount > 0 else { throw RepositoryError.invalidAmount }
        let personID = person.id
        let balanceDescriptor = FetchDescriptor<SDLedgerEntry>(predicate: #Predicate { $0.personID == personID })
        let latestBalance = try context.fetch(balanceDescriptor).reduce(Int64(0)) { $0 + $1.balanceDelta }
        guard latestBalance != 0 else { throw RepositoryError.noOutstandingBalance }
        guard amount <= abs(latestBalance) else { throw RepositoryError.paymentExceedsBalance }
        let delta = latestBalance > 0 ? -amount : amount
        let entry = SDLedgerEntry(
            id: UUID(),
            personID: person.id,
            personName: person.displayName,
            kindRaw: LedgerEntryKind.payment.rawValue,
            balanceDelta: delta,
            date: date,
            title: "Bayar",
            notes: notes
        )
        context.insert(entry)
        try context.save()
        notifyChange()
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
            sourceDraftID: draft.id
        )
    }

    private func update(_ existing: SDTransactionDraft, from draft: TransactionDraft) {
        existing.statusRaw = draft.status.rawValue
        existing.flowRaw = draft.flow.rawValue
        existing.typeRaw = draft.type.rawValue
        existing.transactionDate = draft.transactionDate
        existing.title = draft.title
        existing.totalAmount = draft.totalAmount
        existing.splitMethodRaw = draft.splitMethod?.rawValue
        existing.userShareAmount = draft.userShareAmount
        existing.notes = draft.notes
        existing.rawTranscript = draft.rawTranscript
        existing.rawModelResponse = draft.rawModelResponse
        existing.reviewWarningsRaw = draft.reviewWarnings

        let currentByID = Dictionary(uniqueKeysWithValues: existing.participants.map { ($0.id, $0) })
        let incomingIDs = Set(draft.participants.map(\.id))
        let removed = existing.participants.filter { !incomingIDs.contains($0.id) }

        existing.participants = draft.participants.map { participant in
            let stored = currentByID[participant.id] ?? SDTransactionParticipant(
                id: participant.id,
                name: participant.name
            )
            stored.name = participant.name
            stored.contactIdentifier = participant.contactIdentifier
            stored.shareAmount = participant.shareAmount
            stored.itemTitle = participant.itemTitle
            stored.notes = participant.notes
            return stored
        }

        for participant in removed {
            context.delete(participant)
        }
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
            participants: sd.participants.map { TransactionParticipant(id: $0.id, name: $0.name, contactIdentifier: $0.contactIdentifier, shareAmount: $0.shareAmount, itemTitle: $0.itemTitle, notes: $0.notes) },
            userShareAmount: sd.userShareAmount,
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
            sourceDraftID: sd.sourceDraftID
        )
    }
}
