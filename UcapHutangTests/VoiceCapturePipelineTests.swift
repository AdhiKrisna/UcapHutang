import XCTest
@testable import UcapHutang

private struct StubDraftExtractor: DraftExtracting {
    let result: ExtractionResult

    func extract(flow: CaptureFlow, transcript: String, referenceDate: Date) async throws -> ExtractionResult {
        result
    }
}

private struct FailingDraftExtractor: DraftExtracting {
    func extract(flow: CaptureFlow, transcript: String, referenceDate: Date) async throws -> ExtractionResult {
        throw DraftExtractionError.extractionFailed("Transkrip kosong.")
    }
}

@MainActor
final class VoiceCapturePipelineTests: XCTestCase {
    func testProcessSavesTheMappedDraftAndReturnsItsID() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let repository = InMemoryTransactionRepository()
        let extractor = StubDraftExtractor(result: ExtractionResult(
            output: .personal(PersonalCaptureOutput(direction: .piutang, person: "Satria", amount: 20_000, title: "kopi", notes: nil, transactionTime: nil)),
            resolvedDate: now,
            rawModelResponse: nil,
            warnings: []
        ))
        let pipeline = VoiceCapturePipeline(extraction: extractor, repository: repository, now: { now })

        let draftID = try await pipeline.process(flow: .personal, transcript: "  Satria ngutang 20 ribu  ")

        let stored = await repository.draft(id: draftID)
        XCTAssertEqual(stored?.status, .needsReview)
        XCTAssertEqual(stored?.rawTranscript, "Satria ngutang 20 ribu")
        XCTAssertEqual(stored?.participants.first?.name, "Satria")
        XCTAssertEqual(stored?.createdAt, now)
    }

    func testExtractionFailureSavesNothing() async throws {
        let repository = InMemoryTransactionRepository()
        let pipeline = VoiceCapturePipeline(extraction: FailingDraftExtractor(), repository: repository)

        do {
            _ = try await pipeline.process(flow: .personal, transcript: "")
            XCTFail("Expected the extraction error to propagate")
        } catch {
            XCTAssertEqual(error.localizedDescription, "Ekstraksi gagal: Transkrip kosong.")
        }

        let count = await repository.pendingDraftCount()
        XCTAssertEqual(count, 0)
    }
}
