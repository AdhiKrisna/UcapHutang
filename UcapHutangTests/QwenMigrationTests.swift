import Foundation
import XCTest
@testable import UcapHutang

private struct StubLLMClient: LLMClientProtocol {
    let output: String

    func generate(prompt: String) async throws -> String { output }
}

final class QwenMigrationTests: XCTestCase {
    func testPOCFixturesContainBothComplete150CaseSuites() throws {
        let personal = try loadFixture(named: "personal_150_cases")
        let splitBill = try loadFixture(named: "splitbill_150_cases")
        XCTAssertEqual(personal.count, 150)
        XCTAssertEqual(splitBill.count, 150)
        XCTAssertTrue(personal.allSatisfy { $0["input"] is String && $0["type"] is String })
        XCTAssertTrue(splitBill.allSatisfy { $0["input"] is String && $0["members"] is [Any] })
    }

    func testPromptUsesModeSpecificFinalQwenContracts() {
        let personal = QwenPromptBuilder.prompt(for: DraftExtractionRequest(flow: .personal, transcript: "Aku ngutang 20 ribu ke Budi"))
        XCTAssertTrue(personal.contains("Indonesian informal personal debt"))
        XCTAssertTrue(personal.contains("\"direction\":\"hutang|piutang|unknown\""))
        XCTAssertTrue(personal.contains("Pak Joko pinjam 2 juta"))

        let split = QwenPromptBuilder.prompt(for: DraftExtractionRequest(flow: .splitBill, transcript: "Aku bayarin makan bareng Budi"))
        XCTAssertTrue(split.contains("user-paid split bill"))
        XCTAssertTrue(split.contains("receivables"))
        XCTAssertTrue(split.contains("Beli McD rame-rame 180k"))
    }

    func testPersonalDecoderRejectsBooleanAmount() {
        XCTAssertThrowsError(
            try QwenOutputDecoder.decodePersonal("{\"direction\":\"hutang\",\"person\":\"Budi\",\"amount\":true,\"title\":\"kopi\"}")
        )
    }

    func testPersonalDecoderKeepsModelTemporalComponents() throws {
        let output = try QwenOutputDecoder.decodePersonal(
            "{\"direction\":\"piutang\",\"person\":\"Pak Joko\",\"amount\":2000000,\"title\":\"modal usaha\",\"notes\":null,\"transaction_time\":{\"day\":15,\"month\":7,\"year\":2025,\"hour\":null,\"minute\":null}}"
        )
        XCTAssertEqual(output.direction, .piutang)
        XCTAssertEqual(output.person, "Pak Joko")
        XCTAssertEqual(output.transactionTime?.day, 15)
        XCTAssertEqual(output.transactionTime?.month, 7)
        XCTAssertEqual(output.transactionTime?.year, 2025)
    }

    func testPersonalFallbackDoesNotFabricatePersonOrTitle() throws {
        let output = try QwenOutputDecoder.decodePersonal("{}", transcript: "catat ini dulu")
        XCTAssertEqual(output.direction, .unknown)
        XCTAssertNil(output.person)
        XCTAssertNil(output.title)
        XCTAssertNil(output.amount)
    }

    func testPersonalDeterministicRefinementsFromFinalQwen() throws {
        let output = try QwenOutputDecoder.decodePersonal(
            "{}",
            transcript: "Gua talangin Adit 18k untuk bayar kopi susu"
        )
        XCTAssertEqual(output.direction, .piutang)
        XCTAssertEqual(output.person, "Adit")
        XCTAssertEqual(output.amount, 18_000)
        XCTAssertEqual(output.title?.lowercased(), "kopi susu")
    }

    func testSplitDecoderRejectsUnexpectedKeys() {
        XCTAssertThrowsError(
            try QwenOutputDecoder.decodeSplit("{\"payer\":\"user\",\"total_amount\":800000,\"members\":[\"Satria\"]}")
        )
    }

    func testSplitDecoderExtractsAdjacentNamesAndEqualShares() async throws {
        let service = HybridQwenExtractionService(
            llmClient: StubLLMClient(output: "{\"basis\":\"equal\",\"title\":\"tiket konser\",\"total_amount\":800000,\"split_count\":4,\"includes_user\":true,\"receivables\":[{\"person\":\"Satria\",\"item\":null,\"amount\":null},{\"person\":\"Arif\",\"item\":null,\"amount\":null},{\"person\":\"Ros\",\"item\":null,\"amount\":null}],\"notes\":null,\"transaction_time\":{\"day\":null,\"month\":null,\"year\":null,\"hour\":null,\"minute\":null}}")
        )
        let draft = try await service.extract(
            DraftExtractionRequest(
                flow: .splitBill,
                transcript: "Gua beli tiket konser nalangin Satria Arif dan Ros totalnya 800.000"
            )
        )
        XCTAssertEqual(draft.type, .splitBill)
        XCTAssertEqual(draft.totalAmount, 800_000)
        XCTAssertEqual(draft.participants.map(\.name), ["Satria", "Arif", "Ros"])
        XCTAssertEqual(draft.participants.map(\.shareAmount), [200_000, 200_000, 200_000])
    }

    func testInvalidModelOutputFallsBackToModePreservingDraftWithWarning() async throws {
        let service = HybridQwenExtractionService(llmClient: StubLLMClient(output: "not json"))
        let draft = try await service.extract(
            DraftExtractionRequest(flow: .personal, transcript: "catat ini dulu")
        )
        XCTAssertEqual(draft.flow, .personal)
        XCTAssertEqual(draft.type, .unknown)
        XCTAssertEqual(draft.participants.first?.name, "")
        XCTAssertFalse(draft.reviewWarnings.isEmpty)
    }

    private func loadFixture(named name: String) throws -> [[String: Any]] {
        let bundle = Bundle(for: QwenMigrationTests.self)
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            XCTFail("Fixture tidak ditemukan: \(name).json")
            return []
        }
        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data)
        guard let cases = json as? [[String: Any]] else {
            XCTFail("Fixture bukan array object: \(name).json")
            return []
        }
        return cases
    }
}
