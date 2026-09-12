import XCTest
import SwiftData
@testable import UcapHutang

@MainActor
final class SchemaMigrationV2Tests: XCTestCase {
    func testMigratingUnversionedV1StorePurgesDiscardedDraftsAndBackfillsContactIdentifiers() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("UcapHutangMigration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("default.store")

        let keptDraftID = UUID()
        let discardedDraftID = UUID()

        // 1. Create a store exactly like the pre-versioning app did: a plain Schema of the V1 models.
        do {
            let v1Schema = Schema([
                SchemaV1.SDTransactionParticipant.self,
                SchemaV1.SDTransactionDraft.self,
                SchemaV1.SDLedgerEntry.self
            ])
            let v1Container = try SwiftData.ModelContainer(
                for: v1Schema,
                configurations: ModelConfiguration(schema: v1Schema, url: storeURL)
            )
            let context = ModelContext(v1Container)

            context.insert(SchemaV1.SDTransactionDraft(
                id: keptDraftID,
                statusRaw: "confirmed",
                flowRaw: "personal",
                typeRaw: "piutang",
                title: "Kopi",
                totalAmount: 20_000,
                rawTranscript: "Satria ngutang 20 ribu beli kopi",
                participants: [SchemaV1.SDTransactionParticipant(name: "Satria", contactIdentifier: "contact-satria", shareAmount: 20_000)]
            ))
            context.insert(SchemaV1.SDTransactionDraft(
                id: discardedDraftID,
                statusRaw: "discarded",
                flowRaw: "personal",
                typeRaw: "hutang",
                title: "Bensin",
                totalAmount: 50_000,
                rawTranscript: "transkrip yang sudah dihapus user",
                participants: [SchemaV1.SDTransactionParticipant(name: "Dito", shareAmount: 50_000)]
            ))
            context.insert(SchemaV1.SDLedgerEntry(personID: "contact-satria", personName: "Satria", kindRaw: "charge", balanceDelta: 20_000, title: "Kopi", sourceDraftID: keptDraftID))
            context.insert(SchemaV1.SDLedgerEntry(personID: "contact-satria", personName: "Satria", kindRaw: "payment", balanceDelta: -5_000, title: "Bayar"))
            context.insert(SchemaV1.SDLedgerEntry(personID: "budi", personName: "Budi", kindRaw: "charge", balanceDelta: -10_000, title: "Pulsa"))
            try context.save()
        }

        // 2. Reopen the same file with the versioned schema and the migration plan.
        let v2Schema = Schema(versionedSchema: SchemaV2.self)
        let v2Container = try SwiftData.ModelContainer(
            for: v2Schema,
            migrationPlan: UcapHutangMigrationPlan.self,
            configurations: ModelConfiguration(schema: v2Schema, url: storeURL)
        )
        let context = ModelContext(v2Container)

        let drafts = try context.fetch(FetchDescriptor<SchemaV2.SDTransactionDraft>())
        XCTAssertEqual(drafts.map(\.id), [keptDraftID], "Discarded drafts must be purged")
        XCTAssertEqual(drafts.first?.includesUser, true)

        let participants = try context.fetch(FetchDescriptor<SchemaV2.SDTransactionParticipant>())
        XCTAssertEqual(participants.map(\.name), ["Satria"], "Participants of purged drafts must be gone")

        let entries = try context.fetch(FetchDescriptor<SchemaV2.SDLedgerEntry>())
        let satriaEntries = entries.filter { $0.personID == "contact-satria" }
        XCTAssertEqual(satriaEntries.count, 2)
        XCTAssertTrue(satriaEntries.allSatisfy { $0.contactIdentifier == "contact-satria" }, "Charges and payments of a linked person get backfilled")
        let budi = entries.first { $0.personID == "budi" }
        XCTAssertNotNil(budi)
        XCTAssertNil(budi?.contactIdentifier, "Legacy unlinked people stay unlinked")
    }
}
