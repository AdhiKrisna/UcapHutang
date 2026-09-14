import XCTest
@testable import UcapHutang

final class DraftValidatorShareRulesTests: XCTestCase {
    private func splitDraft(method: SplitMethod, includesUser: Bool, total: Int64, shares: [Int64]) -> TransactionDraft {
        TransactionDraft(
            flow: .splitBill,
            type: .splitBill,
            title: "Makan malam",
            totalAmount: total,
            splitMethod: method,
            includesUser: includesUser,
            participants: shares.enumerated().map { index, share in
                TransactionParticipant(name: "Satria \(index + 1)", contactIdentifier: "contact-\(index + 1)", shareAmount: share)
            },
            rawTranscript: "makan malam"
        )
    }

    func testCustomSharesBelowTotalAreRejected() {
        let draft = splitDraft(method: .custom, includesUser: true, total: 90_000, shares: [30_000, 30_000])
        XCTAssertEqual(DraftValidator.issues(for: draft), [.sharesDoNotMatchTotal])
    }

    func testCustomSharesEqualToTotalAreAccepted() {
        let draft = splitDraft(method: .custom, includesUser: true, total: 90_000, shares: [40_000, 50_000])
        XCTAssertEqual(DraftValidator.issues(for: draft), [])
    }

    func testEqualSharesMustMatchTheEngineWhenUserIsExcluded() {
        let draft = splitDraft(method: .equal, includesUser: false, total: 90_000, shares: [30_000, 30_000])
        XCTAssertEqual(DraftValidator.issues(for: draft), [.sharesDoNotMatchTotal])
    }

    func testEqualSharesMatchingTheEngineAreAccepted() {
        let draft = splitDraft(method: .equal, includesUser: false, total: 90_000, shares: [45_000, 45_000])
        XCTAssertEqual(DraftValidator.issues(for: draft), [])
    }
}
