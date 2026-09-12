import XCTest
@testable import UcapHutang

final class CoreFlowTests: XCTestCase {
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
        let service = QwenDraftExtractionService()
        let transcript = "catat ini dulu"
        let result = try await service.extract(flow: .personal, transcript: transcript, referenceDate: Date())
        let draft = DraftMapper.makeDraft(flow: .personal, transcript: transcript, result: result, createdAt: Date())
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
        try await repository.saveDraft(draft)
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
        try await repository.saveDraft(draft)
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
