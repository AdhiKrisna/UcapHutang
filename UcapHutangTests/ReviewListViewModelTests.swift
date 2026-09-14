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

    func testPersonalDraftWithRealNameShowsEmptyAvatarInitials() {
        let draft = TransactionDraft(
            flow: .personal,
            type: .piutang,
            title: "Makan siang",
            totalAmount: 15_000,
            participants: [TransactionParticipant(name: "dito", shareAmount: 15_000)],
            rawTranscript: "Dito pinjam 15 ribu buat makan siang"
        )

        let item = ReviewListViewModel.makeItem(from: draft, now: draft.createdAt)

        XCTAssertEqual(item.personName, "dito")
        XCTAssertEqual(item.avatarInitials, [])
    }

    func testMissingTitleAndNotesProducesEmptyDescriptionInsteadOfEmptyQuotes() {
        let draft = TransactionDraft(
            flow: .personal,
            type: .hutang,
            title: "   ",
            totalAmount: 200_000,
            participants: [TransactionParticipant(name: "Vito", shareAmount: 200_000)],
            rawTranscript: ""
        )

        let item = ReviewListViewModel.makeItem(from: draft, now: draft.createdAt)

        XCTAssertEqual(item.description, "")
    }

    func testNotesTakePriorityOverTitleInDescription() {
        let draft = TransactionDraft(
            flow: .personal,
            type: .hutang,
            title: "Nasi Padang",
            totalAmount: 50_000,
            participants: [TransactionParticipant(name: "Satria", shareAmount: 50_000)],
            notes: "Bayar minggu depan",
            rawTranscript: ""
        )

        let item = ReviewListViewModel.makeItem(from: draft, now: draft.createdAt)

        XCTAssertEqual(item.description, "Bayar minggu depan")
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
