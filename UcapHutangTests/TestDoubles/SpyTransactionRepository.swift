import Foundation
@testable import UcapHutang

/// Wraps an in-memory repository and counts the write calls a ViewModel makes.
/// Seed data through `base` so seeding is not counted.
@MainActor
final class SpyTransactionRepository: TransactionRepository {
    let base: InMemoryTransactionRepository
    private(set) var saveDraftCallCount = 0
    private(set) var confirmDraftCallCount = 0
    private(set) var deleteDraftCallCount = 0

    init(base: InMemoryTransactionRepository = InMemoryTransactionRepository()) {
        self.base = base
    }

    func draftsNeedingReview() async throws -> [TransactionDraft] { try await base.draftsNeedingReview() }
    func pendingDraftCount() async throws -> Int { try await base.pendingDraftCount() }
    func draft(id: UUID) async throws -> TransactionDraft? { try await base.draft(id: id) }

    func saveDraft(_ draft: TransactionDraft) async throws {
        saveDraftCallCount += 1
        try await base.saveDraft(draft)
    }

    func deleteDraft(id: UUID) async throws {
        deleteDraftCallCount += 1
        try await base.deleteDraft(id: id)
    }

    func confirmDraft(_ draft: TransactionDraft) async throws {
        confirmDraftCallCount += 1
        try await base.confirmDraft(draft)
    }

    func ledgerEntries() async throws -> [LedgerEntry] { try await base.ledgerEntries() }
    func linkedContactIdentifiers() async throws -> [String] { try await base.linkedContactIdentifiers() }
    func linkPerson(personID: String, to contact: ContactRef) async throws { try await base.linkPerson(personID: personID, to: contact) }

    func recordPayment(for person: PersonLedgerSummary, amount: Int64, date: Date, notes: String?) async throws {
        try await base.recordPayment(for: person, amount: amount, date: date, notes: notes)
    }
}
