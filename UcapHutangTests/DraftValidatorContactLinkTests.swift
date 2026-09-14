import XCTest
@testable import UcapHutang

final class DraftValidatorContactLinkTests: XCTestCase {
    private let unlinkedMessage = "Hubungkan setiap orang ke kontak sebelum menyimpan."

    func testPersonalDraftWithUnlinkedPersonIsRejected() {
        let draft = TransactionDraft(
            flow: .personal,
            type: .piutang,
            title: "Kopi",
            totalAmount: 20_000,
            participants: [TransactionParticipant(name: "Satria", shareAmount: 20_000)],
            rawTranscript: "Satria ngutang 20 ribu beli kopi"
        )

        XCTAssertThrowsError(try DraftValidator.validateForConfirmation(draft)) { error in
            XCTAssertEqual(error as? DraftValidationError, .invalid(unlinkedMessage))
        }
    }

    func testSplitBillDraftWithOneUnlinkedParticipantIsRejected() {
        let draft = TransactionDraft(
            flow: .splitBill,
            type: .splitBill,
            title: "Makan malam",
            totalAmount: 90_000,
            splitMethod: .equal,
            participants: [
                TransactionParticipant(name: "Satria", contactIdentifier: "contact-satria", shareAmount: 30_000),
                TransactionParticipant(name: "Ari", shareAmount: 30_000)
            ],
            rawTranscript: "Aku bayarin makan malam 90 ribu sama Satria dan Ari"
        )

        XCTAssertThrowsError(try DraftValidator.validateForConfirmation(draft)) { error in
            XCTAssertEqual(error as? DraftValidationError, .invalid(unlinkedMessage))
        }
    }

    func testBlankContactIdentifierIsTreatedAsUnlinked() {
        let draft = TransactionDraft(
            flow: .personal,
            type: .hutang,
            title: "Bensin",
            totalAmount: 50_000,
            participants: [TransactionParticipant(name: "Dito", contactIdentifier: "   ", shareAmount: 50_000)],
            rawTranscript: "Aku pinjam 50 ribu ke Dito buat bensin"
        )

        XCTAssertThrowsError(try DraftValidator.validateForConfirmation(draft)) { error in
            XCTAssertEqual(error as? DraftValidationError, .invalid(unlinkedMessage))
        }
    }

    func testLinkedPersonalDraftPassesValidation() {
        let draft = TransactionDraft(
            flow: .personal,
            type: .piutang,
            title: "Kopi",
            totalAmount: 20_000,
            participants: [TransactionParticipant(name: "Satria", contactIdentifier: "contact-satria", shareAmount: 20_000)],
            rawTranscript: "Satria ngutang 20 ribu beli kopi"
        )

        XCTAssertNoThrow(try DraftValidator.validateForConfirmation(draft))
    }
}
