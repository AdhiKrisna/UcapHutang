import Foundation

/// Output of stage 2 (transcript → structured data).
struct ExtractionResult: Sendable {
    let output: CaptureOutput
    let resolvedDate: Date
    let rawModelResponse: String?
    let warnings: [String]
}

/// Stage 2 contract. Lives in Services/AI because `ExtractionResult` exposes the decoder's `CaptureOutput`.
protocol DraftExtracting: Sendable {
    /// Throws only for a blank transcript. Model or decoder failures fall back to an empty
    /// structure and add a warning, so the user can still complete the draft in Review.
    func extract(flow: CaptureFlow, transcript: String, referenceDate: Date) async throws -> ExtractionResult
}
