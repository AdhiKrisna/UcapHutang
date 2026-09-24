import XCTest
import SwiftData
@testable import UcapHutang

@MainActor
final class RepositoryLinkAndDeleteTests: XCTestCase {
    func testDeletingLedgerEntryOnlyRemovesRequestedEntry() async throws {
        let retained = LedgerEntry(personID: "budi", personName: "Budi", kind: .charge, balanceDelta: 5_000, date: .now, title: "Retained")
        let removed = LedgerEntry(personID: "budi", personName: "Budi", kind: .payment, balanceDelta: -2_000, date: .now, title: "Removed")
        let repository = InMemoryTransactionRepository(seedEntries: [retained, removed])

        try await repository.deleteLedgerEntry(id: removed.id)

        let entries = await repository.ledgerEntries()
        XCTAssertEqual(entries.map(\.id), [retained.id])
    }
    private struct Subject {
        let label: String
        let repository: any TransactionRepository
        let container: SwiftData.ModelContainer?
    }

    /// Returns the in-memory actor repository and a SwiftData repository (in-memory store), both seeded with `entries`.
    private func makeSubjects(seedEntries entries: [LedgerEntry] = []) throws -> [Subject] {
        let inMemory = InMemoryTransactionRepository(seedEntries: entries)

        let schema = Schema(versionedSchema: SchemaV2.self)
        let container = try SwiftData.ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
        for entry in entries {
            container.mainContext.insert(SDLedgerEntry(
                id: entry.id,
                personID: entry.personID,
                personName: entry.personName,
                kindRaw: entry.kind.rawValue,
                balanceDelta: entry.balanceDelta,
                date: entry.date,
                title: entry.title,
                notes: entry.notes,
                sourceDraftID: entry.sourceDraftID,
                contactIdentifier: entry.contactIdentifier
            ))
        }
        try container.mainContext.save()
        let swiftData = SwiftDataTransactionRepository(modelContainer: container)

        return [
            Subject(label: "InMemory", repository: inMemory, container: nil),
            Subject(label: "SwiftData", repository: swiftData, container: container)
        ]
    }

    private func linkedPersonalDraft(name: String = "Satria", contact: String = "contact-satria") -> TransactionDraft {
        TransactionDraft(
            flow: .personal,
            type: .piutang,
            title: "Kopi",
            totalAmount: 20_000,
            participants: [TransactionParticipant(name: name, contactIdentifier: contact, shareAmount: 20_000)],
            rawTranscript: "\(name) ngutang 20 ribu beli kopi"
        )
    }

    private func legacyEntry(_ personID: String, _ name: String, _ delta: Int64, kind: LedgerEntryKind = .charge, contact: String? = nil) -> LedgerEntry {
        LedgerEntry(personID: personID, personName: name, kind: kind, balanceDelta: delta, date: .now, title: "Pulsa", contactIdentifier: contact)
    }

    func testPendingDraftCountCountsOnlyDraftsNeedingReview() async throws {
        for subject in try makeSubjects() {
            let pending = linkedPersonalDraft(name: "Ari", contact: "contact-ari")
            let confirmed = linkedPersonalDraft()
            try await subject.repository.saveDraft(pending)
            try await subject.repository.saveDraft(confirmed)
            try await subject.repository.confirmDraft(confirmed)

            let count = try await subject.repository.pendingDraftCount()
            XCTAssertEqual(count, 1, subject.label)
        }
    }

    func testDeleteDraftRemovesDraftPermanently() async throws {
        for subject in try makeSubjects() {
            let draft = linkedPersonalDraft()
            try await subject.repository.saveDraft(draft)

            try await subject.repository.deleteDraft(id: draft.id)

            let stored = try await subject.repository.draft(id: draft.id)
            XCTAssertNil(stored, subject.label)
            let count = try await subject.repository.pendingDraftCount()
            XCTAssertEqual(count, 0, subject.label)
            if let container = subject.container {
                let participants = try container.mainContext.fetch(FetchDescriptor<SDTransactionParticipant>())
                XCTAssertTrue(participants.isEmpty, "\(subject.label): participants must be deleted with the draft")
            }
        }
    }

    func testConfirmStoresContactIdentifierOnEveryCharge() async throws {
        for subject in try makeSubjects() {
            let draft = TransactionDraft(
                flow: .splitBill,
                type: .splitBill,
                title: "Makan malam",
                totalAmount: 90_000,
                splitMethod: .equal,
                participants: [
                    TransactionParticipant(name: "Satria", contactIdentifier: "contact-satria", shareAmount: 30_000),
                    TransactionParticipant(name: "Ari", contactIdentifier: "contact-ari", shareAmount: 30_000)
                ],
                rawTranscript: "Aku bayarin makan malam 90 ribu sama Satria dan Ari"
            )
            try await subject.repository.saveDraft(draft)
            try await subject.repository.confirmDraft(draft)

            let entries = try await subject.repository.ledgerEntries()
            XCTAssertEqual(entries.count, 2, subject.label)
            XCTAssertTrue(entries.allSatisfy { $0.contactIdentifier == $0.personID }, subject.label)
        }
    }

    func testLinkedContactIdentifiersAreDistinctAndSorted() async throws {
        let seed = [
            legacyEntry("contact-b", "Bima", 10_000, contact: "contact-b"),
            legacyEntry("contact-b", "Bima", -2_000, kind: .payment, contact: "contact-b"),
            legacyEntry("contact-a", "Ari", 5_000, contact: "contact-a"),
            legacyEntry("budi", "Budi", -10_000)
        ]
        for subject in try makeSubjects(seedEntries: seed) {
            let identifiers = try await subject.repository.linkedContactIdentifiers()
            XCTAssertEqual(identifiers, ["contact-a", "contact-b"], subject.label)
        }
    }

    func testLinkPersonMovesLegacyEntriesToTheContact() async throws {
        let seed = [
            legacyEntry("budi", "Budi", -10_000),
            legacyEntry("budi", "Budi", 4_000, kind: .payment)
        ]
        for subject in try makeSubjects(seedEntries: seed) {
            let contact = ContactRef(identifier: "contact-budi", displayName: "Budi Santoso", phoneNumber: nil)
            try await subject.repository.linkPerson(personID: "budi", to: contact)

            let entries = try await subject.repository.ledgerEntries()
            XCTAssertEqual(entries.count, 2, subject.label)
            XCTAssertTrue(entries.allSatisfy { $0.personID == "contact-budi" }, subject.label)
            XCTAssertTrue(entries.allSatisfy { $0.personName == "Budi Santoso" }, subject.label)
            XCTAssertTrue(entries.allSatisfy { $0.contactIdentifier == "contact-budi" }, subject.label)
        }
    }

    func testLinkPersonMergesIntoExistingContactHistoryAndUnifiesName() async throws {
        let seed = [
            legacyEntry("budi", "Budi", -10_000),
            legacyEntry("contact-budi", "Budi S", 25_000, contact: "contact-budi")
        ]
        for subject in try makeSubjects(seedEntries: seed) {
            let contact = ContactRef(identifier: "contact-budi", displayName: "Budi Santoso", phoneNumber: nil)
            try await subject.repository.linkPerson(personID: "budi", to: contact)

            let entries = try await subject.repository.ledgerEntries()
            XCTAssertEqual(entries.count, 2, subject.label)
            XCTAssertTrue(entries.allSatisfy { $0.personID == "contact-budi" && $0.personName == "Budi Santoso" }, subject.label)
            XCTAssertEqual(entries.reduce(Int64(0)) { $0 + $1.balanceDelta }, 15_000, subject.label)
        }
    }

    func testLinkPersonWithUnknownPersonThrowsPersonNotFound() async throws {
        for subject in try makeSubjects(seedEntries: [legacyEntry("budi", "Budi", -10_000)]) {
            let contact = ContactRef(identifier: "contact-x", displayName: "X", phoneNumber: nil)
            do {
                try await subject.repository.linkPerson(personID: "nobody", to: contact)
                XCTFail("\(subject.label): expected personNotFound")
            } catch RepositoryError.personNotFound {
                // Expected.
            } catch {
                XCTFail("\(subject.label): unexpected error \(error)")
            }
        }
    }

    func testRecordPaymentOnUnlinkedPersonThrowsPersonNotLinked() async throws {
        for subject in try makeSubjects(seedEntries: [legacyEntry("budi", "Budi", -10_000)]) {
            let summary = PersonLedgerSummary(id: "budi", displayName: "Budi", balance: -10_000, entryCount: 1, lastActivity: .now)
            do {
                try await subject.repository.recordPayment(for: summary, amount: 5_000, date: .now, notes: nil)
                XCTFail("\(subject.label): expected personNotLinked")
            } catch RepositoryError.personNotLinked {
                // Expected.
            } catch {
                XCTFail("\(subject.label): unexpected error \(error)")
            }
            let entries = try await subject.repository.ledgerEntries()
            XCTAssertEqual(entries.count, 1, subject.label)
        }
    }

    func testLedgerSummariesCarryContactIdentifier() async throws {
        let repository = InMemoryTransactionRepository(seedEntries: [
            legacyEntry("budi", "Budi", -10_000),
            legacyEntry("contact-ari", "Ari", 5_000, contact: "contact-ari")
        ])
        let viewModel = LedgerListViewModel(repository: repository)

        await viewModel.load()

        let byID = Dictionary(uniqueKeysWithValues: viewModel.summaries.map { ($0.id, $0) })
        XCTAssertEqual(byID["contact-ari"]?.isLinked, true)
        XCTAssertEqual(byID["budi"]?.isLinked, false)
    }
}
