import Foundation

final class VoiceCapturePipeline: VoiceCapturing {
    private let extraction: any DraftExtracting
    private let repository: any TransactionRepository
    private let now: () -> Date

    init(
        extraction: any DraftExtracting,
        repository: any TransactionRepository,
        now: @escaping () -> Date = Date.init
    ) {
        self.extraction = extraction
        self.repository = repository
        self.now = now
    }

    func process(flow: CaptureFlow, transcript: String) async throws -> UUID {
        let cleanTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        let referenceDate = now()
        // Stage 2: transcript → structured output.
        let result = try await extraction.extract(flow: flow, transcript: cleanTranscript, referenceDate: referenceDate)
        // Stage 3: structured output → draft → SwiftData.
        let draft = DraftMapper.makeDraft(flow: flow, transcript: cleanTranscript, result: result, createdAt: referenceDate)
        try await repository.saveDraft(draft)
        return draft.id
    }
}
