import XCTest
import SwiftData
@testable import UcapHutang

@MainActor
final class ConfirmDraftContactLinkRegressionTests: XCTestCase {
    private let unlinkedMessage = "Hubungkan setiap orang ke kontak sebelum menyimpan."

    private func makeUnlinkedPersonalDraft() -> TransactionDraft {
        TransactionDraft(
            flow: .personal,
            type: .piutang,
            title: "Kopi",
            totalAmount: 20_000,
            participants: [TransactionParticipant(name: "Satria", shareAmount: 20_000)],
            rawTranscript: "Satria ngutang 20 ribu beli kopi"
        )
    }

    private func makeSwiftDataRepository() throws -> SwiftDataTransactionRepository {
        let schema = Schema([
            SDTransactionParticipant.self,
            SDTransactionDraft.self,
            SDLedgerEntry.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try SwiftData.ModelContainer(for: schema, configurations: configuration)
        return SwiftDataTransactionRepository(modelContainer: container)
    }

    func testInMemoryRepositoryRejectsUnlinkedDraftAndWritesNothing() async throws {
        let repository = InMemoryTransactionRepository()
        let draft = makeUnlinkedPersonalDraft()
        try await repository.saveDraft(draft)

        do {
            try await repository.confirmDraft(draft)
            XCTFail("Confirming a draft with an unlinked person must throw")
        } catch let error as DraftValidationError {
            XCTAssertEqual(error, .invalid(unlinkedMessage))
        }

        let entries = await repository.ledgerEntries()
        XCTAssertTrue(entries.isEmpty, "No ledger entry may be written for an unlinked person")
        let stored = await repository.draft(id: draft.id)
        XCTAssertEqual(stored?.status, .needsReview, "The draft must stay in Draft")
    }

    func testSwiftDataRepositoryRejectsUnlinkedDraftAndWritesNothing() async throws {
        let repository = try makeSwiftDataRepository()
        let draft = makeUnlinkedPersonalDraft()
        try await repository.saveDraft(draft)

        do {
            try await repository.confirmDraft(draft)
            XCTFail("Confirming a draft with an unlinked person must throw")
        } catch let error as DraftValidationError {
            XCTAssertEqual(error, .invalid(unlinkedMessage))
        }

        let entries = try await repository.ledgerEntries()
        XCTAssertTrue(entries.isEmpty, "No ledger entry may be written for an unlinked person")
        let stored = try await repository.draft(id: draft.id)
        XCTAssertEqual(stored?.status, .needsReview, "The draft must stay in Draft")
        let pending = try await repository.draftsNeedingReview()
        XCTAssertEqual(pending.map(\.id), [draft.id])
    }

    func testSwiftDataRepositoryUsesContactIdentifierAsPersonIDForLinkedDraft() async throws {
        let repository = try makeSwiftDataRepository()
        var draft = makeUnlinkedPersonalDraft()
        draft.participants[0].name = "Satria Kans"
        draft.participants[0].contactIdentifier = "contact-satria"
        try await repository.saveDraft(draft)

        try await repository.confirmDraft(draft)

        let entries = try await repository.ledgerEntries()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.personID, "contact-satria")
        XCTAssertEqual(entries.first?.personName, "Satria Kans")
        XCTAssertEqual(entries.first?.balanceDelta, 20_000)
        let stored = try await repository.draft(id: draft.id)
        XCTAssertEqual(stored?.status, .confirmed)
    }
}
