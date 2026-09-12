import XCTest
import SwiftData
@testable import UcapHutang

final class CoreFlowTests: XCTestCase {
    func testWidgetDeepLinkRoutesOnlyToCatatChooser() {
        XCTAssertEqual(AppDeepLink(url: URL(string: "ucaphutang://catat")!), .catatChooser)
        XCTAssertNil(AppDeepLink(url: URL(string: "ucaphutang://unknown")!))
        XCTAssertNil(AppDeepLink(url: URL(string: "https://example.com/catat")!))
    }

    @MainActor
    func testEqualSplitCanExcludeUserAndConservesTotal() async {
        let draft = TransactionDraft(
            flow: .splitBill,
            type: .splitBill,
            title: "Makan malam",
            totalAmount: 100_000,
            splitMethod: .equal,
            participants: [
                TransactionParticipant(name: "A", contactIdentifier: "a", shareAmount: 33_333),
                TransactionParticipant(name: "B", contactIdentifier: "b", shareAmount: 33_333)
            ],
            userShareAmount: 33_334,
            rawTranscript: "Split bill seratus ribu dengan A dan B"
        )
        let repository = InMemoryTransactionRepository(seedDrafts: [draft])
        let viewModel = ReviewViewModel(draftID: draft.id, repository: repository)
        await viewModel.load()

        viewModel.toggleUserIncluded()

        XCTAssertEqual(viewModel.userShareAmount, 0)
        XCTAssertEqual(viewModel.draft?.participants.map(\.shareAmount), [50_000, 50_000])
        XCTAssertEqual(viewModel.splitAllocatedAmount, 100_000)
        XCTAssertTrue(viewModel.isValid)
    }

    @MainActor
    func testCustomSplitRequiresExactTotalIncludingUser() async {
        let draft = TransactionDraft(
            flow: .splitBill,
            type: .splitBill,
            title: "Makan malam",
            totalAmount: 100_000,
            splitMethod: .custom,
            participants: [
                TransactionParticipant(name: "A", contactIdentifier: "a", shareAmount: 60_000)
            ],
            userShareAmount: 30_000,
            rawTranscript: "Split bill seratus ribu dengan A"
        )
        let repository = InMemoryTransactionRepository(seedDrafts: [draft])
        let viewModel = ReviewViewModel(draftID: draft.id, repository: repository)
        await viewModel.load()

        XCTAssertFalse(viewModel.isValid)
        viewModel.updateUserShare(40_000)
        XCTAssertTrue(viewModel.isValid)
    }

    @MainActor
    func testSplitSelectionPersistsAndExcludedFriendCreatesNoLedgerEntry() async throws {
        let schema = Schema([
            SDTransactionParticipant.self,
            SDTransactionDraft.self,
            SDLedgerEntry.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let repository = SwiftDataTransactionRepository(modelContainer: container)
        let draft = TransactionDraft(
            flow: .splitBill,
            type: .splitBill,
            title: "Makan malam",
            totalAmount: 100_000,
            splitMethod: .custom,
            participants: [
                TransactionParticipant(name: "A", contactIdentifier: "a", shareAmount: 60_000),
                TransactionParticipant(name: "B", shareAmount: 0)
            ],
            userShareAmount: 40_000,
            rawTranscript: "Split bill seratus ribu dengan A dan B"
        )

        try await repository.saveDraft(draft)
        let persisted = try await repository.draft(id: draft.id)
        XCTAssertEqual(persisted?.userShareAmount, 40_000)
        XCTAssertEqual(persisted?.participants.first(where: { $0.name == "B" })?.shareAmount, 0)

        try await repository.confirmDraft(draft)
        let entries = try await repository.ledgerEntries()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.personID, "a")
        XCTAssertEqual(entries.first?.balanceDelta, 60_000)
    }

    @MainActor
    func testSwiftDataDraftSupportsRepeatedTypeAutosaves() async throws {
        let schema = Schema([
            SDTransactionParticipant.self,
            SDTransactionDraft.self,
            SDLedgerEntry.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let repository = SwiftDataTransactionRepository(modelContainer: container)
        var draft = TransactionDraft(
            flow: .personal,
            type: .piutang,
            title: "Kopi",
            totalAmount: 20_000,
            participants: [TransactionParticipant(name: "Satria", shareAmount: 20_000)],
            rawTranscript: "Satria ngutang 20 ribu beli kopi"
        )

        try await repository.saveDraft(draft)
        draft.type = .hutang
        try await repository.saveDraft(draft)
        draft.type = .piutang
        try await repository.saveDraft(draft)

        let saved = try await repository.draft(id: draft.id)
        XCTAssertEqual(saved?.type, .piutang)
        XCTAssertEqual(saved?.participants.first?.id, draft.participants.first?.id)
    }

    @MainActor
    func testAutosaveFailureDoesNotPresentSaveAlert() async {
        let draft = TransactionDraft(
            flow: .personal,
            type: .piutang,
            title: "Kopi",
            totalAmount: 20_000,
            participants: [TransactionParticipant(name: "Satria", shareAmount: 20_000)],
            rawTranscript: "Satria ngutang 20 ribu beli kopi"
        )
        let repository = AutosaveFailingRepository(draft: draft, draftID: draft.id)
        let viewModel = ReviewViewModel(draftID: draft.id, repository: repository)
        await viewModel.load()

        viewModel.updateTitle("Bensin")
        await viewModel.flushPendingEdits()

        XCTAssertNil(viewModel.errorMessage)
        XCTAssertNotNil(viewModel.autosaveErrorMessage)
    }

    @MainActor
    func testReviewEditsSynchronizeWithoutConfirmingDraft() async throws {
        let repository = InMemoryTransactionRepository()
        let originalDate = Date(timeIntervalSince1970: 1_700_000_000)
        let updatedDate = originalDate.addingTimeInterval(3_600)
        let draft = TransactionDraft(
            flow: .personal,
            type: .piutang,
            transactionDate: originalDate,
            title: "Kopi",
            totalAmount: 20_000,
            participants: [TransactionParticipant(name: "Satria", shareAmount: 20_000)],
            rawTranscript: "Satria ngutang 20 ribu beli kopi"
        )
        await repository.saveDraft(draft)

        let viewModel = ReviewViewModel(draftID: draft.id, repository: repository)
        await viewModel.load()
        viewModel.updateTotalAmount(35_000)
        viewModel.updateTitle("Bensin")
        viewModel.updateTransactionDate(updatedDate)
        viewModel.updateParticipantContact(
            index: 0,
            candidate: ContactMatchCandidate(id: "contact-satria", fullName: "Satria Pratama")
        )
        await viewModel.flushPendingEdits()

        let saved = await repository.draft(id: draft.id)
        XCTAssertEqual(saved?.totalAmount, 35_000)
        XCTAssertEqual(saved?.title, "Bensin")
        XCTAssertEqual(saved?.transactionDate, updatedDate)
        XCTAssertEqual(saved?.participants.first?.name, "Satria Pratama")
        XCTAssertEqual(saved?.participants.first?.contactIdentifier, "contact-satria")
        XCTAssertEqual(saved?.status, .needsReview)
        let entries = await repository.ledgerEntries()
        XCTAssertTrue(entries.isEmpty)
    }

    @MainActor
    func testReviewSaveKeepsUnlinkedParticipantInDraft() async throws {
        let repository = InMemoryTransactionRepository()
        let draft = TransactionDraft(
            flow: .personal,
            type: .piutang,
            title: "Kopi",
            totalAmount: 20_000,
            participants: [TransactionParticipant(name: "Satria", shareAmount: 20_000)],
            rawTranscript: "Satria ngutang 20 ribu beli kopi"
        )
        await repository.saveDraft(draft)

        let viewModel = ReviewViewModel(draftID: draft.id, repository: repository)
        await viewModel.load()
        await viewModel.save()

        let saved = await repository.draft(id: draft.id)
        let entries = await repository.ledgerEntries()
        XCTAssertEqual(saved?.status, .needsReview)
        XCTAssertTrue(entries.isEmpty)
        XCTAssertFalse(viewModel.didFinish)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testUnlinkedParticipantCannotBeConfirmedOrEnterHistory() async throws {
        let repository = InMemoryTransactionRepository()
        let draft = TransactionDraft(
            flow: .personal,
            type: .piutang,
            title: "Kopi",
            totalAmount: 20_000,
            participants: [TransactionParticipant(name: "Satria", shareAmount: 20_000)],
            rawTranscript: "Satria ngutang 20 ribu beli kopi"
        )

        await repository.saveDraft(draft)

        do {
            try await repository.confirmDraft(draft)
            XCTFail("Participant tanpa kontak tidak boleh dikonfirmasi")
        } catch {
            // Expected.
        }

        let entries = await repository.ledgerEntries()
        let savedDraft = await repository.draft(id: draft.id)
        XCTAssertTrue(entries.isEmpty)
        XCTAssertEqual(savedDraft?.status, .needsReview)
    }

    func testUnknownPersonalDirectionCannotBeConfirmed() {
        let draft = TransactionDraft(
            flow: .personal,
            type: .unknown,
            title: "Kopi",
            totalAmount: 20_000,
            participants: [TransactionParticipant(name: "Satria", shareAmount: 20_000)],
            rawTranscript: "Satria ngutang 20 ribu beli kopi"
        )
        XCTAssertThrowsError(try DraftValidator.validateForConfirmation(draft))
    }

    func testEqualSplitConservesEveryRupiah() {
        let shares = SplitCalculationEngine.calculateEqualShares(totalAmount: 100_000, participantCount: 3)
        XCTAssertEqual(shares, [33_334, 33_333, 33_333])
        XCTAssertEqual(shares.reduce(0, +), 100_000)
    }

    func testMissingSemanticFieldsStayEmpty() async throws {
        let service = HybridQwenExtractionService()
        let draft = try await service.extract(
            DraftExtractionRequest(flow: .personal, transcript: "catat ini dulu")
        )
        XCTAssertEqual(draft.type, .unknown)
        XCTAssertEqual(draft.title, "")
        XCTAssertEqual(draft.participants.first?.name, "")
    }

    func testRepeatedConfirmationCreatesOneLedgerCharge() async throws {
        let repository = InMemoryTransactionRepository()
        let draft = TransactionDraft(
            flow: .personal,
            type: .piutang,
            title: "Kopi",
            totalAmount: 20_000,
            participants: [TransactionParticipant(name: "Satria", contactIdentifier: "contact-satria", shareAmount: 20_000)],
            rawTranscript: "Satria ngutang 20 ribu beli kopi"
        )
        await repository.saveDraft(draft)
        try await repository.confirmDraft(draft)
        try await repository.confirmDraft(draft)
        let entries = await repository.ledgerEntries()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.balanceDelta, 20_000)
    }

    func testPaymentUsesLatestBalanceInsteadOfStaleSummary() async throws {
        let repository = InMemoryTransactionRepository()
        let draft = TransactionDraft(
            flow: .personal,
            type: .piutang,
            title: "Kopi",
            totalAmount: 20_000,
            participants: [TransactionParticipant(name: "Satria", contactIdentifier: "contact-satria", shareAmount: 20_000)],
            rawTranscript: "Satria ngutang 20 ribu beli kopi"
        )
        await repository.saveDraft(draft)
        try await repository.confirmDraft(draft)
        let stale = PersonLedgerSummary(id: "contact-satria", displayName: "Satria", balance: 100_000, entryCount: 1, lastActivity: .now)
        do {
            try await repository.recordPayment(for: stale, amount: 30_000, date: .now, notes: nil)
            XCTFail("Payment above latest balance should fail")
        } catch RepositoryError.paymentExceedsBalance {
            // Expected.
        }
    }
}

private actor AutosaveFailingRepository: TransactionRepository {
    enum Failure: Error { case unavailable }

    private let storedDraft: TransactionDraft
    private let storedDraftID: UUID

    init(draft: TransactionDraft, draftID: UUID) {
        storedDraft = draft
        storedDraftID = draftID
    }

    func draftsNeedingReview() -> [TransactionDraft] { [storedDraft] }
    func draft(id: UUID) -> TransactionDraft? { id == storedDraftID ? storedDraft : nil }
    func saveDraft(_ draft: TransactionDraft) throws { throw Failure.unavailable }
    func discardDraft(id: UUID) {}
    func confirmDraft(_ draft: TransactionDraft) {}
    func ledgerEntries() -> [LedgerEntry] { [] }
    func recordPayment(for person: PersonLedgerSummary, amount: Int64, date: Date, notes: String?) {}
}
