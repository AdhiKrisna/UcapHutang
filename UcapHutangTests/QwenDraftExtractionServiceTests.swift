import XCTest
@testable import UcapHutang

final class QwenDraftExtractionServiceTests: XCTestCase {
    func testBlankTranscriptThrows() async {
        let service = QwenDraftExtractionService()
        do {
            _ = try await service.extract(flow: .personal, transcript: "   ", referenceDate: Date())
            XCTFail("A blank transcript must throw")
        } catch {
            XCTAssertEqual(error.localizedDescription, "Ekstraksi gagal: Transkrip kosong.")
        }
    }
}
