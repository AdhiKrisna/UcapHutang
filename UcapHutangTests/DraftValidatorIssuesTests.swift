import XCTest
@testable import UcapHutang

final class DraftValidatorIssuesTests: XCTestCase {
    private func linkedPersonalDraft() -> TransactionDraft {
        TransactionDraft(
            flow: .personal,
            type: .piutang,
            title: "Kopi",
            totalAmount: 20_000,
            participants: [TransactionParticipant(name: "Satria", contactIdentifier: "contact-satria", shareAmount: 20_000)],
            rawTranscript: "Satria ngutang 20 ribu beli kopi"
        )
    }

    private func linkedSplitDraft() -> TransactionDraft {
        TransactionDraft(
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
    }

    func testValidPersonalDraftHasNoIssues() {
        let draft = linkedPersonalDraft()
        XCTAssertEqual(DraftValidator.issues(for: draft), [])
        XCTAssertNoThrow(try DraftValidator.validateForConfirmation(draft))
    }

    func testValidSplitDraftHasNoIssues() {
        let draft = linkedSplitDraft()
        XCTAssertEqual(DraftValidator.issues(for: draft), [])
        XCTAssertNoThrow(try DraftValidator.validateForConfirmation(draft))
    }

    func testAmountNotPositive() {
        var draft = linkedPersonalDraft()
        draft.totalAmount = 0
        XCTAssertEqual(DraftValidator.issues(for: draft), [.amountNotPositive])
        XCTAssertEqual(DraftValidationIssue.amountNotPositive.message, "Isi nominal transaksi dengan angka lebih dari Rp0.")
    }

    func testTitleMissing() {
        var draft = linkedPersonalDraft()
        draft.title = "   "
        XCTAssertEqual(DraftValidator.issues(for: draft), [.titleMissing])
        XCTAssertEqual(DraftValidationIssue.titleMissing.message, "Isi deskripsi transaksi, misalnya “Kopi” atau “Makan malam”.")
    }

    func testDirectionMissingForPersonal() {
        var draft = linkedPersonalDraft()
        draft.type = .unknown
        XCTAssertEqual(DraftValidator.issues(for: draft), [.directionMissing])
        XCTAssertEqual(DraftValidationIssue.directionMissing.message, "Pilih siapa yang berutang: kamu atau orang tersebut.")
    }

    func testParticipantsMissingUsesFlowSpecificMessage() {
        var personal = linkedPersonalDraft()
        personal.participants = []
        XCTAssertEqual(DraftValidator.issues(for: personal), [.participantsMissing(flow: .personal)])
        XCTAssertEqual(DraftValidationIssue.participantsMissing(flow: .personal).message, "Pilih orang yang terkait dengan transaksi ini.")

        var split = linkedSplitDraft()
        split.participants = []
        XCTAssertEqual(DraftValidator.issues(for: split), [.participantsMissing(flow: .splitBill)])
        XCTAssertEqual(DraftValidationIssue.participantsMissing(flow: .splitBill).message, "Tambahkan minimal satu teman yang ikut split bill.")
    }

    func testParticipantNameMissing() {
        var draft = linkedPersonalDraft()
        draft.participants[0].name = "  "
        let id = draft.participants[0].id
        XCTAssertEqual(DraftValidator.issues(for: draft), [.participantNameMissing(participantID: id)])
        XCTAssertEqual(DraftValidationIssue.participantNameMissing(participantID: id).message, "Ada nama orang yang masih kosong.")
    }

    func testEveryUnlinkedParticipantIsReported() {
        var draft = linkedSplitDraft()
        draft.participants[0].contactIdentifier = nil
        draft.participants[1].contactIdentifier = nil
        XCTAssertEqual(
            DraftValidator.issues(for: draft),
            [
                .participantNotLinked(participantID: draft.participants[0].id),
                .participantNotLinked(participantID: draft.participants[1].id)
            ]
        )
        XCTAssertEqual(
            DraftValidationIssue.participantNotLinked(participantID: draft.participants[0].id).message,
            "Hubungkan setiap orang ke kontak sebelum menyimpan."
        )
    }

    func testDuplicateDetectionUsesContactIdentifier() {
        var draft = linkedSplitDraft()
        draft.participants[1].name = "Satria K"
        draft.participants[1].contactIdentifier = "contact-satria"
        XCTAssertEqual(DraftValidator.issues(for: draft), [.duplicateParticipant])
        XCTAssertEqual(DraftValidationIssue.duplicateParticipant.message, "Ada orang yang sama dalam satu transaksi. Hapus atau ganti salah satunya.")
    }

    func testPersonalRequiresExactlyOnePerson() {
        var draft = linkedPersonalDraft()
        draft.participants.append(TransactionParticipant(name: "Ari", contactIdentifier: "contact-ari", shareAmount: 0))
        XCTAssertEqual(DraftValidator.issues(for: draft), [.personalRequiresExactlyOne])
        XCTAssertEqual(DraftValidationIssue.personalRequiresExactlyOne.message, "Utang atau piutang pribadi hanya boleh melibatkan satu orang.")
    }

    func testSplitTypeInvalid() {
        var draft = linkedSplitDraft()
        draft.type = .piutang
        XCTAssertEqual(DraftValidator.issues(for: draft), [.splitTypeInvalid])
        XCTAssertEqual(DraftValidationIssue.splitTypeInvalid.message, "Jenis transaksi split bill tidak valid.")
    }

    func testShareNotPositiveNamesTheParticipant() {
        var draft = linkedSplitDraft()
        draft.participants[1].shareAmount = 0
        let id = draft.participants[1].id
        XCTAssertEqual(DraftValidator.issues(for: draft), [.shareNotPositive(participantID: id, name: "Ari")])
        XCTAssertEqual(DraftValidationIssue.shareNotPositive(participantID: id, name: "Ari").message, "Isi nominal bagian untuk Ari.")
    }

    func testSharesExceedTotal() {
        var draft = linkedSplitDraft()
        draft.participants[0].shareAmount = 60_000
        draft.participants[1].shareAmount = 60_000
        XCTAssertEqual(DraftValidator.issues(for: draft), [.sharesExceedTotal])
        XCTAssertEqual(DraftValidationIssue.sharesExceedTotal.message, "Total bagian teman melebihi nominal transaksi.")
    }

    func testValidateForConfirmationThrowsTheFirstIssue() {
        var draft = linkedPersonalDraft()
        draft.totalAmount = 0
        draft.participants[0].contactIdentifier = nil
        XCTAssertThrowsError(try DraftValidator.validateForConfirmation(draft)) { error in
            XCTAssertEqual(error as? DraftValidationError, .invalid("Isi nominal transaksi dengan angka lebih dari Rp0."))
        }
    }

    func testSharesDoNotMatchTotalMessage() {
        XCTAssertEqual(DraftValidationIssue.sharesDoNotMatchTotal.message, "Pembagian nominal belum sesuai dengan total transaksi.")
    }
}
