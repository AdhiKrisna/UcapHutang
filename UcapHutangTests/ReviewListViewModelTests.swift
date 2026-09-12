import XCTest
@testable import UcapHutang

final class ReviewListViewModelTests: XCTestCase {
    func testPersonalDraftWithBlankNameShowsApprovedPlaceholder() {
        let draft = TransactionDraft(
            flow: .personal,
            type: .hutang,
            title: "Bensin",
            totalAmount: 50_000,
            participants: [TransactionParticipant(name: "  ", shareAmount: 50_000)],
            rawTranscript: "pinjam 50 ribu buat bensin"
        )

        let item = ReviewListViewModel.makeItem(from: draft, now: draft.createdAt)

        XCTAssertEqual(item.personName, "Belum ada nama")
        XCTAssertEqual(item.prefix, "dari")
        XCTAssertEqual(item.avatarInitials, [])
    }

    func testSplitDraftUsesRealCountAndInitialsFromRealNamesOnly() {
        let draft = TransactionDraft(
            flow: .splitBill,
            type: .splitBill,
            title: "Makan",
            totalAmount: 90_000,
            splitMethod: .equal,
            participants: [
                TransactionParticipant(name: "satria", shareAmount: 30_000),
                TransactionParticipant(name: "", shareAmount: 30_000)
            ],
            rawTranscript: "makan"
        )

        let item = ReviewListViewModel.makeItem(from: draft, now: draft.createdAt)

        XCTAssertEqual(item.personName, "2 Orang")
        XCTAssertEqual(item.avatarInitials, ["S"])
        XCTAssertEqual(item.prefix, "ke")
    }

    func testSplitDraftWithoutParticipantsShowsZeroAndNoInitials() {
        let draft = TransactionDraft(
            flow: .splitBill,
            type: .splitBill,
            title: "Makan",
            totalAmount: 90_000,
            splitMethod: .equal,
            participants: [],
            rawTranscript: "makan"
        )

        let item = ReviewListViewModel.makeItem(from: draft, now: draft.createdAt)

        XCTAssertEqual(item.personName, "0 Orang")
        XCTAssertEqual(item.avatarInitials, [])
    }
}
