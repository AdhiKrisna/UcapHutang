import XCTest
@testable import UcapHutang

final class DraftMapperTests: XCTestCase {
    private let createdAt = Date(timeIntervalSince1970: 1_800_000_000)
    private let resolvedDate = Date(timeIntervalSince1970: 1_799_990_000)

    func testPersonalOutputMapsEveryField() {
        let result = ExtractionResult(
            output: .personal(PersonalCaptureOutput(
                direction: .piutang,
                person: "Satria",
                amount: 20_000,
                title: "kopi",
                notes: "bayar besok",
                transactionTime: nil
            )),
            resolvedDate: resolvedDate,
            rawModelResponse: "{\"direction\":\"piutang\"}",
            warnings: ["peringatan"]
        )

        let draft = DraftMapper.makeDraft(flow: .personal, transcript: "Satria ngutang 20 ribu", result: result, createdAt: createdAt)

        XCTAssertEqual(draft.status, .needsReview)
        XCTAssertEqual(draft.flow, .personal)
        XCTAssertEqual(draft.type, .piutang)
        XCTAssertEqual(draft.title, "kopi")
        XCTAssertEqual(draft.totalAmount, 20_000)
        XCTAssertNil(draft.splitMethod)
        XCTAssertTrue(draft.includesUser)
        XCTAssertEqual(draft.participants.map(\.name), ["Satria"])
        XCTAssertEqual(draft.participants.map(\.shareAmount), [20_000])
        XCTAssertNil(draft.participants.first?.contactIdentifier)
        XCTAssertEqual(draft.notes, "bayar besok")
        XCTAssertEqual(draft.rawTranscript, "Satria ngutang 20 ribu")
        XCTAssertEqual(draft.rawModelResponse, "{\"direction\":\"piutang\"}")
        XCTAssertEqual(draft.reviewWarnings, ["peringatan"])
        XCTAssertEqual(draft.transactionDate, resolvedDate)
        XCTAssertEqual(draft.createdAt, createdAt)
    }

    func testPersonalMissingFieldsStayEmptyAndUnknown() {
        let result = ExtractionResult(
            output: .personal(PersonalCaptureOutput(direction: .unknown, person: nil, amount: nil, title: nil, notes: nil, transactionTime: nil)),
            resolvedDate: resolvedDate,
            rawModelResponse: nil,
            warnings: []
        )

        let draft = DraftMapper.makeDraft(flow: .personal, transcript: "catat ini dulu", result: result, createdAt: createdAt)

        XCTAssertEqual(draft.type, .unknown)
        XCTAssertEqual(draft.title, "")
        XCTAssertEqual(draft.totalAmount, 0)
        XCTAssertEqual(draft.participants.map(\.name), [""])
        XCTAssertEqual(draft.participants.map(\.shareAmount), [0])
    }

    func testEqualSplitIncludesUserAndIgnoresModelSplitCount() {
        let result = ExtractionResult(
            output: .split(SplitCaptureOutput(
                basis: .equal,
                title: "tiket konser",
                totalAmount: 800_000,
                splitCount: 5,
                includesUser: true,
                receivables: [
                    SplitReceivable(person: "Satria", item: nil, amount: nil),
                    SplitReceivable(person: "Arif", item: nil, amount: nil),
                    SplitReceivable(person: "Ros", item: nil, amount: nil)
                ],
                notes: nil,
                transactionTime: nil
            )),
            resolvedDate: resolvedDate,
            rawModelResponse: nil,
            warnings: []
        )

        let draft = DraftMapper.makeDraft(flow: .splitBill, transcript: "tiket konser", result: result, createdAt: createdAt)

        XCTAssertEqual(draft.type, .splitBill)
        XCTAssertEqual(draft.splitMethod, .equal)
        XCTAssertTrue(draft.includesUser)
        XCTAssertEqual(draft.totalAmount, 800_000)
        XCTAssertEqual(draft.participants.map(\.shareAmount), [200_000, 200_000, 200_000])
        XCTAssertTrue(draft.participants.allSatisfy { $0.contactIdentifier == nil })
    }

    func testCustomSplitTotalIsTheSumWhenEveryAmountIsPresent() {
        let result = ExtractionResult(
            output: .split(SplitCaptureOutput(
                basis: .custom,
                title: "makan",
                totalAmount: 100_000,
                splitCount: 3,
                includesUser: true,
                receivables: [
                    SplitReceivable(person: "Satria", item: "nasi", amount: 30_000),
                    SplitReceivable(person: "Ari", item: "sate", amount: 50_000)
                ],
                notes: nil,
                transactionTime: nil
            )),
            resolvedDate: resolvedDate,
            rawModelResponse: nil,
            warnings: []
        )

        let draft = DraftMapper.makeDraft(flow: .splitBill, transcript: "makan", result: result, createdAt: createdAt)

        XCTAssertEqual(draft.splitMethod, .custom)
        XCTAssertEqual(draft.totalAmount, 80_000)
        XCTAssertEqual(draft.participants.map(\.shareAmount), [30_000, 50_000])
        XCTAssertEqual(draft.participants.map(\.itemTitle), ["nasi", "sate"])
    }

    func testCustomSplitKeepsModelTotalWhenAnAmountIsMissing() {
        let result = ExtractionResult(
            output: .split(SplitCaptureOutput(
                basis: .custom,
                title: "makan",
                totalAmount: 100_000,
                splitCount: 3,
                includesUser: true,
                receivables: [
                    SplitReceivable(person: "Satria", item: nil, amount: 30_000),
                    SplitReceivable(person: "Ari", item: nil, amount: nil)
                ],
                notes: nil,
                transactionTime: nil
            )),
            resolvedDate: resolvedDate,
            rawModelResponse: nil,
            warnings: []
        )

        let draft = DraftMapper.makeDraft(flow: .splitBill, transcript: "makan", result: result, createdAt: createdAt)

        XCTAssertEqual(draft.totalAmount, 100_000)
        XCTAssertEqual(draft.participants.map(\.shareAmount), [30_000, 0])
    }
}
