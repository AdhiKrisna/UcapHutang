import XCTest
import SwiftData
@testable import UcapHutang

@MainActor
final class SwiftDataDraftAutosaveTests: XCTestCase {
    func testRepeatedSavesUpdateParticipantsInPlace() async throws {
        let schema = Schema(versionedSchema: SchemaV2.self)
        let container = try SwiftData.ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
        let repository = SwiftDataTransactionRepository(modelContainer: container)
        var draft = TransactionDraft(
            flow: .splitBill,
            type: .splitBill,
            title: "Makan malam",
            totalAmount: 90_000,
            splitMethod: .equal,
            participants: [
                TransactionParticipant(name: "Satria", contactIdentifier: "contact-satria", shareAmount: 30_000),
                TransactionParticipant(name: "Ari", shareAmount: 30_000)
            ],
            rawTranscript: "makan malam"
        )
        try await repository.saveDraft(draft)
        let firstRows = try container.mainContext.fetch(FetchDescriptor<SDTransactionParticipant>())
        let satriaRowID = firstRows.first { $0.name == "Satria" }?.persistentModelID
        XCTAssertNotNil(satriaRowID)

        draft.title = "Makan siang"
        try await repository.saveDraft(draft)
        draft.participants[0].shareAmount = 45_000
        draft.participants.remove(at: 1)
        try await repository.saveDraft(draft)

        let stored = try await repository.draft(id: draft.id)
        XCTAssertEqual(stored?.title, "Makan siang")
        XCTAssertEqual(stored?.participants.map(\.id), [draft.participants[0].id])
        XCTAssertEqual(stored?.participants.first?.shareAmount, 45_000)
        let rows = try container.mainContext.fetch(FetchDescriptor<SDTransactionParticipant>())
        XCTAssertEqual(rows.count, 1, "Removed participants must be deleted")
        XCTAssertEqual(rows.first?.persistentModelID, satriaRowID, "Existing participant rows are updated, not re-created")
    }
}
